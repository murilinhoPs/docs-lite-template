#!/usr/bin/env bash
# Espelha docs/roadmap.md no board do GitHub Projects.
#
# O roadmap é a fonte: para cada task com issue, este script garante que a issue
# está no board e copia para ela a Etapa (todo/doing/review/done) e a Ordem
# (posição da linha no roadmap). Mudanças feitas à mão no board são sobrescritas.
#
# Uso: ./scripts/sync-board.sh
# Requer: gh com escopo "project" (gh auth refresh -s project) e jq.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
CONF="$ROOT/scripts/board.conf"
ROADMAP="$ROOT/docs/roadmap.md"

[ -f "$CONF" ] || { echo "Sem scripts/board.conf: rode ./scripts/bootstrap.sh primeiro."; exit 1; }
# shellcheck source=/dev/null
source "$CONF"   # define OWNER e PROJECT_NUMBER

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

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

ordem=0
synced=0
# Linhas de task: | 001 | [Título](...) | status | #12 | #13 |
while IFS='|' read -r _ num _task status issue _rest; do
  num="$(xargs <<<"$num")"
  [[ "$num" =~ ^[0-9]{3}$ ]] || continue
  ordem=$((ordem + 1))
  status="$(xargs <<<"$status")"
  issue="$(xargs <<<"$issue" | tr -d '#')"
  [[ "$issue" =~ ^[0-9]+$ ]] || continue   # task ainda sem issue: fica fora do board

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
    echo "  aviso: status desconhecido '$status' na task $num"
  fi
  gh project item-edit --project-id "$PROJECT_ID" --id "$item" \
    --field-id "$ORDEM_ID" --number "$ordem" >/dev/null

  echo "  $num  #$issue  $status  (ordem $ordem)"
  synced=$((synced + 1))
done < "$ROADMAP"

echo "Board sincronizado: $synced task(s)."
