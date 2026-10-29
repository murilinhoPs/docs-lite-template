#!/usr/bin/env bash
# Roda UMA vez, a partir desta pasta, para publicar o template no seu GitHub.
#
# Uso: ./scripts/publish-template.sh [nome-do-repo]   (padrão: docs-lite-template)
set -euo pipefail

NAME="${1:-docs-lite-template}"

[ -d .git ] || { git init -b main && git add . && git commit -m "Template inicial"; }

gh repo create "$NAME" --private --source . --push
gh repo edit "$NAME" --template
echo "Template publicado: $(gh repo view "$NAME" --json url -q .url)"
