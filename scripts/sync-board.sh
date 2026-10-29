#!/usr/bin/env bash
# Espelha docs/roadmap.md no board do GitHub Projects.
#
# O roadmap é a fonte: para cada linha (uma issue), este script garante que a
# issue está no board e copia para ela a Etapa (todo/doing/review/done) e a Ordem
# (coluna Ordem do roadmap). Mudanças feitas à mão no board são sobrescritas.
#
# Etapa = Status do roadmap, com dois ajustes para o que ainda não chegou à main:
#   - issue com a label status:doing → doing;
#   - senão, issue todo/doing com PR aberto ("Closes #N" no corpo) → review.
#
# Roda no GitHub Action .github/workflows/sync-board.yml (no PR e no merge) e
# localmente, pelo usuário. Não roda nas sessões do Claude Code na nuvem, que
# não têm GraphQL (gh project).
#
# Uso: ./scripts/sync-board.sh [--auto]
#   --auto: se não houver board.conf ou o gh não acessar o Projects, sai sem erro.
# Requer: gh com escopo "project" (gh auth refresh -s project) e jq.
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

ROOT="$(git rev-parse --show-toplevel)"
CONF="$ROOT/scripts/board.conf"
ROADMAP="$ROOT/docs/roadmap.md"
AUTO=0
[ "${1:-}" = --auto ] && AUTO=1

if [ ! -f "$CONF" ]; then
  [ "$AUTO" = 1 ] && { echo "Sem scripts/board.conf: sync do board pulado."; exit 0; }
  echo "Sem scripts/board.conf: rode ./scripts/bootstrap.sh primeiro."
  exit 1
fi
# shellcheck source=/dev/null
source "$CONF"   # define OWNER e PROJECT_NUMBER

if [ "$AUTO" = 1 ] && ! gh project list --owner "$OWNER" --limit 1 >/dev/null 2>&1; then
  echo "gh sem acesso ao Projects (sessão na nuvem?): o Action sincroniza o board no PR e no merge."
  exit 0
fi

REPO="$(repo_slug)"

PROJECT_ID="$(gh project view "$PROJECT_NUMBER" --owner "$OWNER" --format json -q .id)"
FIELDS="$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit 100)"
ETAPA_ID="$(jq -r '.fields[] | select(.name=="Etapa") | .id' <<<"$FIELDS")"
ORDEM_ID="$(jq -r '.fields[] | select(.name=="Ordem") | .id' <<<"$FIELDS")"
[ -n "$ETAPA_ID" ] && [ -n "$ORDEM_ID" ] || { echo "Campos Etapa/Ordem não encontrados no projeto $PROJECT_NUMBER."; exit 1; }

option_id() { jq -r --arg n "$1" '.fields[] | select(.name=="Etapa") | .options[] | select(.name==$n) | .id' <<<"$FIELDS"; }

ITEMS="$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit 1000)"
item_id() {
  jq -r --arg repo "$REPO" --argjson n "$1" \
    '.items[] | select(.content.type=="Issue" and .content.repository==$repo and .content.number==$n) | .id' <<<"$ITEMS"
}

# Rotas REST do repositório: issues com status:doing e issues fechadas por PRs abertos.
DOING="$(gh api --paginate "repos/$REPO/issues?state=open&labels=status:doing&per_page=100" -q '.[].number')"
IN_REVIEW="$(gh api --paginate "repos/$REPO/pulls?state=open&per_page=100" \
  -q '.[].body // "" | [scan("(?i)(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?) #([0-9]+)")[0]] | .[]')"
has() { grep -qx "$1" <<<"$2"; }

synced=0
# Linhas: | Ordem | Issue | Título | Status | Spec | PR |
while IFS='|' read -r _ ordem issue _title status _rest; do
  issue="$(tr -d ' \t#' <<<"$issue")"
  [[ "$issue" =~ ^[0-9]+$ ]] || continue   # cabeçalho, separador ou texto
  ordem="$(tr -d ' \t' <<<"$ordem")"
  status="$(tr -d ' \t' <<<"$status")"

  if has "$issue" "$DOING"; then
    status=doing
  elif [[ "$status" =~ ^(todo|doing)$ ]] && has "$issue" "$IN_REVIEW"; then
    status=review
  fi

  item="$(item_id "$issue")"
  if [ -z "$item" ]; then
    item="$(gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" \
      --url "https://github.com/$REPO/issues/$issue" --format json -q .id)"
  fi

  opt="$(option_id "$status")"
  if [ -n "$opt" ]; then
    gh project item-edit --project-id "$PROJECT_ID" --id "$item" \
      --field-id "$ETAPA_ID" --single-select-option-id "$opt" >/dev/null
  else
    echo "  aviso: status desconhecido '$status' na issue #$issue"
  fi
  if [[ "$ordem" =~ ^[0-9]+$ ]]; then
    gh project item-edit --project-id "$PROJECT_ID" --id "$item" \
      --field-id "$ORDEM_ID" --number "$ordem" >/dev/null
  fi

  echo "  #$issue  $status  (ordem $ordem)"
  synced=$((synced + 1))
done < "$ROADMAP"

echo "Board sincronizado: $synced issue(s)."
