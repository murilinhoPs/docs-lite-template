#!/usr/bin/env bash
# Diz se o PR é "só docs": todo arquivo alterado está em docs/ ou é *.md, exceto o
# CLAUDE.md, que muda o processo e conta como código. PR só de docs dispensa
# prints, "teste você também" e os testes da stack no CI.
#
# Uso: ./scripts/docs-only.sh [base] [head]   (padrão: origin/main HEAD)
# Sai com 0 se for só docs e 1 se tiver código.
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

if docs_only "${1:-origin/main}" "${2:-HEAD}"; then
  echo "só docs"
else
  rc=$?
  [ "$rc" = 1 ] && echo "código"
  exit "$rc"
fi
