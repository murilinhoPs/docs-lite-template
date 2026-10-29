#!/usr/bin/env bash
# Muda o status de uma issue no docs/roadmap.md.
#
# Também mantém a label status:doing na issue (só API REST do repositório):
# adiciona no doing e remove nos outros. É ela que faz o board mostrar "doing"
# enquanto a branch da task ainda não subiu. Se o board for acessível daqui
# (Claude Code local), roda o sync-board.sh; senão o Action sincroniza.
#
# Uso: ./scripts/task-status.sh <issue> <todo|doing|review|done>
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

N="${1:?Uso: $0 <issue> <todo|doing|review|done>}"
STATUS="${2:?Uso: $0 <issue> <todo|doing|review|done>}"
N="${N#\#}"
[[ "$N" =~ ^[0-9]+$ ]] || { echo "Número de issue inválido: $1" >&2; exit 1; }
[[ "$STATUS" =~ ^(todo|doing|review|done)$ ]] || { echo "Status inválido: $STATUS" >&2; exit 1; }

ROADMAP="$(git rev-parse --show-toplevel)/docs/roadmap.md"
roadmap_set "$ROADMAP" "$N" status "$STATUS"
echo "#$N → $STATUS"

REPO="$(repo_slug)"
if [ "$STATUS" = doing ]; then
  gh api "repos/$REPO/issues/$N/labels" -f "labels[]=status:doing" >/dev/null
  echo "  label status:doing adicionada"
else
  # 404 quando a issue não tem a label: não é erro.
  gh api -X DELETE "repos/$REPO/issues/$N/labels/status:doing" >/dev/null 2>&1 || true
fi

if board_available; then
  "$(dirname "$0")/sync-board.sh"
fi
