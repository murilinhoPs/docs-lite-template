#!/usr/bin/env bash
# Cria a issue de registro de uma task, usando só a API REST do repositório
# (funciona no Claude Code local e nas sessões na nuvem, que não têm GraphQL).
#
# Lê id, title, milestone e labels do frontmatter, cria a issue
# "NNN · <title>" com o corpo "Spec: <arquivo>" e grava o número no
# frontmatter (issue: "#N") e na coluna Issue do docs/roadmap.md.
# Idempotente: se a task já tem issue, ou se já existe uma issue com o mesmo
# título no repo, não cria nada.
#
# Uso: ./scripts/create-issue.sh docs/tasks/NNN-<slug>.md
# Imprime: o número da issue.
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

TASK="${1:?Uso: $0 docs/tasks/NNN-<slug>.md}"
[ -f "$TASK" ] || { echo "Arquivo não encontrado: $TASK" >&2; exit 1; }
ROOT="$(git rev-parse --show-toplevel)"
ROADMAP="$ROOT/docs/roadmap.md"
SPEC="$(repo_path "$TASK")"

ID="$(fm_get "$TASK" id)"
TITLE="$(fm_get "$TASK" title)"
MILESTONE="$(fm_get "$TASK" milestone)"
LABELS="$(fm_get "$TASK" labels)"
ISSUE="$(fm_get "$TASK" issue | tr -d '#')"
[[ "$ID" =~ ^[0-9]{3}$ ]] || { echo "id inválido no frontmatter de $TASK: '$ID'" >&2; exit 1; }
[ -n "$TITLE" ] || { echo "title vazio no frontmatter de $TASK" >&2; exit 1; }

if [[ "$ISSUE" =~ ^[0-9]+$ ]]; then
  echo "$ISSUE"
  exit 0
fi

REPO="$(repo_slug)"
FULL_TITLE="$ID · $TITLE"

# Recupera uma issue criada por uma execução anterior que não chegou a gravar o número.
ISSUE="$(gh api --paginate "repos/$REPO/issues?state=all&per_page=100" \
  -q ".[] | select(.pull_request == null and .title == $(jq_str "$FULL_TITLE")) | .number" | head -n1)"

if [ -z "$ISSUE" ]; then
  args=(-f "title=$FULL_TITLE" -f "body=Spec: $SPEC")

  # O frontmatter guarda o código (M0); o milestone no GitHub é "M0 Fundação".
  if [ -n "$MILESTONE" ]; then
    MS_NUM="$(gh api "repos/$REPO/milestones?state=all&per_page=100" \
      -q ".[] | select(.title == $(jq_str "$MILESTONE") or (.title | startswith($(jq_str "$MILESTONE ")))) | .number" | head -n1)"
    [ -n "$MS_NUM" ] || { echo "Milestone '$MILESTONE' não existe no repo. Rode ./scripts/bootstrap.sh." >&2; exit 1; }
    args+=(-F "milestone=$MS_NUM")
  fi

  # labels: [type:feature, area:ui]
  IFS=',' read -ra labels <<<"$(tr -d '[]"' <<<"$LABELS")"
  for l in "${labels[@]}"; do
    l="$(xargs <<<"$l")"
    [ -n "$l" ] && args+=(-f "labels[]=$l")
  done

  ISSUE="$(gh api "repos/$REPO/issues" "${args[@]}" -q .number)"
fi

fm_set "$TASK" issue "\"#$ISSUE\""
roadmap_set "$ROADMAP" "$ID" issue "#$ISSUE"
echo "$ISSUE"
