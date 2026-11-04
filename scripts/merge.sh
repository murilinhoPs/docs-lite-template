#!/usr/bin/env bash
# Merge (squash) de um PR travado no head conferido: se o head mudou depois da
# conferência, o GitHub recusa (o mesmo que --match-head-commit). Título e corpo
# do commit vêm do PR (configuração de squash do bootstrap.sh). Só API REST.
#
# Uso: ./scripts/merge.sh <pr> <sha do head>
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

PR="${1:?Uso: $0 <pr> <sha do head>}"
SHA="${2:?Uso: $0 <pr> <sha do head>}"
PR="${PR#\#}"
[[ "$PR" =~ ^[0-9]+$ ]] || { echo "Número de PR inválido: $1" >&2; exit 1; }
[[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || { echo "Use o sha completo (40 caracteres) do head: $2" >&2; exit 1; }

REPO="$(repo_slug)"
gh api -X PUT "repos/$REPO/pulls/$PR/merge" -f merge_method=squash -f "sha=$SHA" \
  -q '"\(.message) (\(.sha[0:7]))"'
