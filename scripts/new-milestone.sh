#!/usr/bin/env bash
# Cria um milestone no GitHub, só pela API REST do repositório. Idempotente:
# se já existe um milestone com esse título (aberto ou fechado), não cria outro.
#
# Milestones nascem na etapa 2 do planejamento (/planejar M<n>), um por vez; o M0
# é criado pelo bootstrap.sh. Título igual ao do roadmap: "M<n> — <nome>".
#
# Uso: ./scripts/new-milestone.sh "M<n> — <nome>"
# Imprime: o número do milestone.
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

TITLE="${1:?Uso: $0 \"M<n> — <nome>\"}"
[[ "$TITLE" =~ ^M[0-9]+\ —\  ]] || { echo "Use o formato \"M<n> — <nome>\" (com travessão), como no roadmap." >&2; exit 1; }

REPO="$(repo_slug)"
N="$(gh api --paginate "repos/$REPO/milestones?state=all&per_page=100" \
  -q ".[] | select(.title == $(jq_str "$TITLE")) | .number" | head -n1)"
if [ -z "$N" ]; then
  N="$(gh api "repos/$REPO/milestones" -f "title=$TITLE" -q .number)"
fi
echo "$N"
