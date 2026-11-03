#!/usr/bin/env bash
# Traz para um projeto as mudanças do processo que vieram no template.
#
# Repos criados a partir de um template não recebem as mudanças dele. Este script
# compara com o template (remote "template") e, com --aplicar, traz os caminhos que
# podem vir inteiros, sem tocar nos arquivos que são do projeto. Não faz commit.
#
# Fluxo: branch chore/atualiza-template → este script (sem e depois com --aplicar) →
# revisar o diff e mesclar à mão o que ele listar → ./scripts/bootstrap.sh (cria só o
# que falta, como labels novas) → PR "[chore] Atualiza processo do template".
#
# Uso: ./scripts/atualiza-template.sh [--aplicar] [url-do-template]
#      (url: argumento, ou TEMPLATE_URL, ou https://github.com/murilinhoPs/docs-lite-template.git)
set -euo pipefail

APLICAR=0
URL=""
for a in "$@"; do
  case "$a" in
    --aplicar) APLICAR=1 ;;
    -*) echo "Opção desconhecida: $a" >&2; exit 1 ;;
    *) URL="$a" ;;
  esac
done
URL="${URL:-${TEMPLATE_URL:-https://github.com/murilinhoPs/docs-lite-template.git}}"

# Pode trazer inteiro (menos os protegidos que estão dentro deles).
INTEIROS=(.claude scripts .github CLAUDE.md AGENTS.md)
# Mesclar à mão, se o projeto personalizou.
MESCLAR=(docs/README.md docs/qa/print-rules.md docs/prompts docs/specs/_template.md
  docs/adr/_template.md docs/milestones/_template.md docs/adr/README.md)
# Nunca sobrescrever (os que podem vir junto com os INTEIROS).
PROTEGIDOS=(scripts/board.conf .github/workflows/ci.yml)

[ "$(git branch --show-current)" != main ] \
  || { echo "Não rode na main: git switch -c chore/atualiza-template" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] \
  || { echo "A árvore tem mudanças sem commit: faça commit ou stash antes." >&2; exit 1; }

git remote get-url template >/dev/null 2>&1 || git remote add template "$URL"
git fetch -q template main
REF=template/main

EXCLUI=()
for p in "${PROTEGIDOS[@]}"; do EXCLUI+=(":(exclude)$p"); done

if [ "$APLICAR" = 0 ]; then
  echo "== Pode trazer inteiro (git diff --stat HEAD $REF):"
  git diff --stat HEAD "$REF" -- "${INTEIROS[@]}" "${EXCLUI[@]}"
  echo "== Mesclar à mão (mudaram no template):"
  for p in "${MESCLAR[@]}"; do
    git diff --quiet HEAD "$REF" -- "$p" || echo "  $p"
  done
  echo "Nada foi alterado. Para trazer: $0 --aplicar"
  exit 0
fi

# Só os caminhos que existem no template.
TRAZER=()
for p in "${INTEIROS[@]}"; do
  [ -n "$(git ls-tree --name-only "$REF" -- "$p")" ] && TRAZER+=("$p")
done
git checkout "$REF" -- "${TRAZER[@]}"

# Os protegidos voltam ao que eram (ou saem, se vieram só do template).
for p in "${PROTEGIDOS[@]}"; do
  if git cat-file -e "HEAD:$p" 2>/dev/null; then
    git checkout HEAD -- "$p"
  elif [ -e "$p" ]; then
    git rm -q --cached -- "$p" && rm -f -- "$p"
  fi
done

echo "Trazido de $REF (sem commit): ${TRAZER[*]}"
echo "Protegidos mantidos: ${PROTEGIDOS[*]}"
echo "Revise com git diff --cached; mescle à mão o que mudou em:"
for p in "${MESCLAR[@]}"; do
  git diff --quiet HEAD "$REF" -- "$p" || echo "  $p"
done
echo "Arquivos apagados no template não são apagados aqui: confira com git diff --stat HEAD $REF."
