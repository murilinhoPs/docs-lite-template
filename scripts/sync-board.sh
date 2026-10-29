#!/usr/bin/env bash
# Espelha docs/roadmap.md no board do GitHub Projects.
#
# Para cada linha do roadmap (uma issue), este script garante que a issue está no
# board e copia para ela a Etapa e a Ordem (coluna Ordem do roadmap). Mudanças
# feitas à mão no board são sobrescritas.
#
# O roadmap guarda o destino (todo, doing, done); o GitHub mostra o andamento.
# Etapa, nesta ordem:
#   1. issue fechada → done;
#   2. PR aberto que fecha a issue ("Closes #N" no corpo) → review;
#   3. roadmap diz doing ou done (ainda sem PR) → doing;
#   4. senão → todo.
# Lê o roadmap da working tree atual, então funciona de qualquer branch.
#
# Usa gh project (GraphQL): só roda onde o board é acessível, como o Claude Code
# local. Nas sessões na nuvem, use --auto: o script avisa e sai sem erro.
#
# Uso: ./scripts/sync-board.sh [--auto]
#   --auto: sem board.conf ou sem acesso ao Projects, avisa e sai sem erro.
# Requer: gh com escopo "project" (gh auth refresh -s project) e jq.
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

ROOT="$(git rev-parse --show-toplevel)"
CONF="$ROOT/scripts/board.conf"
ROADMAP="$ROOT/docs/roadmap.md"
AUTO=0
[ "${1:-}" = --auto ] && AUTO=1

SKIP="board não sincronizado; rode ./scripts/sync-board.sh localmente"
if [ ! -f "$CONF" ]; then
  [ "$AUTO" = 1 ] && { echo "Sem scripts/board.conf: $SKIP (depois do ./scripts/bootstrap.sh)."; exit 0; }
  echo "Sem scripts/board.conf: rode ./scripts/bootstrap.sh primeiro."
  exit 1
fi
# shellcheck source=/dev/null
source "$CONF"   # define OWNER e PROJECT_NUMBER

if [ "$AUTO" = 1 ] && ! gh project list --owner "$OWNER" --limit 1 >/dev/null 2>&1; then
  echo "gh sem acesso ao Projects: $SKIP."
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

# Rotas REST do repositório: issues fechadas e issues fechadas por PRs abertos.
CLOSED="$(gh api --paginate "repos/$REPO/issues?state=closed&per_page=100" -q '.[] | select(.pull_request == null) | .number')"
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

  if has "$issue" "$CLOSED"; then
    status=done
  elif has "$issue" "$IN_REVIEW"; then
    status=review
  elif [[ "$status" =~ ^(doing|done)$ ]]; then
    status=doing
  else
    status=todo
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
