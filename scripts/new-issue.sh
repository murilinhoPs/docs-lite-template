#!/usr/bin/env bash
# Cria uma issue e a linha dela no docs/roadmap.md, usando só a API REST do
# repositório (funciona no Claude Code local e nas sessões na nuvem, sem GraphQL).
#
# A linha entra com status todo, no fim da seção do milestone ou logo depois de
# --after. A coluna Spec vem do "**Spec:** docs/specs/<x>.md" do corpo.
#
# Uso:
#   ./scripts/new-issue.sh --title "[feat] ..." --body-file corpo.md --milestone "M1 MVP" \
#     --labels "type:feature,area:x" [--after <issue>]
#   ./scripts/new-issue.sh --existing <N> [--after <issue>]   # issue que já existe (ex.: bug)
# Imprime: o número da issue.
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

usage() {
  sed -n '/^# Uso:/,/^# Imprime/p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}

TITLE="" BODY_FILE="" MILESTONE="" LABELS="" AFTER="" EXISTING=""
while [ $# -gt 0 ]; do
  case "$1" in
    --title) TITLE="${2:?}"; shift 2 ;;
    --body-file) BODY_FILE="${2:?}"; shift 2 ;;
    --milestone) MILESTONE="${2:?}"; shift 2 ;;
    --labels) LABELS="${2:?}"; shift 2 ;;
    --after) AFTER="${2:?}"; shift 2 ;;
    --existing) EXISTING="${2:?}"; shift 2 ;;
    *) usage ;;
  esac
done

ROADMAP="$(git rev-parse --show-toplevel)/docs/roadmap.md"
REPO="$(repo_slug)"
AFTER="${AFTER#\#}"
if [ -n "$AFTER" ] && ! roadmap_has "$ROADMAP" "$AFTER"; then
  echo "Issue #$AFTER (--after) não está no roadmap." >&2
  exit 1
fi

if [ -n "$EXISTING" ]; then
  N="${EXISTING#\#}"
  [[ "$N" =~ ^[0-9]+$ ]] || usage
  if roadmap_has "$ROADMAP" "$N"; then
    echo "$N"
    exit 0
  fi
  ISSUE_JSON="$(gh api "repos/$REPO/issues/$N")"
  TITLE="$(jq -r .title <<<"$ISSUE_JSON")"
  BODY="$(jq -r '.body // ""' <<<"$ISSUE_JSON")"
  MS_TITLE="$(jq -r '.milestone.title // empty' <<<"$ISSUE_JSON")"
  [ -n "$MS_TITLE" ] || [ -n "$AFTER" ] || { echo "A issue #$N não tem milestone: use --after <issue>." >&2; exit 1; }
else
  [ -n "$TITLE" ] && [ -n "$BODY_FILE" ] && [ -n "$MILESTONE" ] && [ -n "$LABELS" ] || usage
  [ -f "$BODY_FILE" ] || { echo "Arquivo não encontrado: $BODY_FILE" >&2; exit 1; }
  [[ "$TITLE" =~ ^\[(feat|bug|chore|docs)\]\  ]] || { echo "O título começa com [feat], [bug], [chore] ou [docs]." >&2; exit 1; }
  BODY="$(cat "$BODY_FILE")"

  MS_JSON="$(gh api "repos/$REPO/milestones?state=all&per_page=100" -q "[.[] | $(milestone_filter "$MILESTONE")][0] // empty")"
  [ -n "$MS_JSON" ] || { echo "Milestone '$MILESTONE' não existe no repo: gh api repos/$REPO/milestones -f title=\"$MILESTONE\"" >&2; exit 1; }
  MS_TITLE="$(jq -r .title <<<"$MS_JSON")"

  args=(-f "title=$TITLE" -F "body=@$BODY_FILE" -F "milestone=$(jq -r .number <<<"$MS_JSON")")
  IFS=',' read -ra labels <<<"$LABELS"
  for l in "${labels[@]}"; do
    l="$(xargs <<<"$l")"
    [ -n "$l" ] && args+=(-f "labels[]=$l")
  done
  N="$(gh api "repos/$REPO/issues" "${args[@]}" -q .number)"
fi

SPEC="$(spec_from_body "$BODY")"
SPEC="${SPEC#docs/}"
roadmap_insert "$ROADMAP" "$N" "$TITLE" "${SPEC:-—}" "$MS_TITLE" "$AFTER"
echo "$N"
