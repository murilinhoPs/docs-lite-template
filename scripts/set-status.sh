#!/usr/bin/env bash
# Muda o status de uma task no frontmatter e no docs/roadmap.md.
#
# Também mantém a label status:doing na issue (só API REST do repositório):
# adiciona quando o status vira doing e remove nos outros. É ela que faz o
# board mostrar "doing" enquanto a branch da task ainda não subiu.
#
# Uso: ./scripts/set-status.sh docs/tasks/NNN-<slug>.md <todo|doing|review|done>
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

TASK="${1:?Uso: $0 docs/tasks/NNN-<slug>.md <todo|doing|review|done>}"
STATUS="${2:?Uso: $0 docs/tasks/NNN-<slug>.md <todo|doing|review|done>}"
[[ "$STATUS" =~ ^(todo|doing|review|done)$ ]] || { echo "Status inválido: $STATUS" >&2; exit 1; }
[ -f "$TASK" ] || { echo "Arquivo não encontrado: $TASK" >&2; exit 1; }
ROOT="$(git rev-parse --show-toplevel)"

ID="$(fm_get "$TASK" id)"
ISSUE="$(fm_get "$TASK" issue | tr -d '#')"

fm_set "$TASK" status "$STATUS"
roadmap_set "$ROOT/docs/roadmap.md" "$ID" status "$STATUS"
echo "$ID → $STATUS"

[[ "$ISSUE" =~ ^[0-9]+$ ]] || exit 0
REPO="$(repo_slug)"
if [ "$STATUS" = doing ]; then
  gh api "repos/$REPO/issues/$ISSUE/labels" -f "labels[]=status:doing" >/dev/null
  echo "  label status:doing adicionada em #$ISSUE"
else
  # 404 quando a issue não tem a label: não é erro.
  gh api -X DELETE "repos/$REPO/issues/$ISSUE/labels/status:doing" >/dev/null 2>&1 || true
fi
