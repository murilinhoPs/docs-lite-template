#!/usr/bin/env bash
# Lista ou apaga o material da pasta de entrada do /preparar (padrão _import/).
#
# Uso: ./scripts/limpar-import.sh [--apagar] [pasta]
#   sem --apagar: só lista o que há na pasta, com tamanhos, e o total (não apaga nada);
#   --apagar: apaga tudo dentro da pasta, menos o .gitkeep, e imprime o que apagou.
#
# Recusa (saída 1) pasta que não existe, a raiz do repo, ., .., docs, scripts, .claude,
# .github, pasta que contém .git e caminho que resolve para fora do repo. Não segue links
# simbólicos: um link dentro da pasta é apagado como link, sem tocar no destino.
# Arquivo rastreado pelo git é removido com git rm (e o script avisa).
# Nunca pergunta nada: quem pergunta é o /preparar, antes de rodar com --apagar.
set -euo pipefail

USO="Uso: ./scripts/limpar-import.sh [--apagar] [pasta]"
APAGAR=0
DIR=""
for a in "$@"; do
  case "$a" in
    --apagar) APAGAR=1 ;;
    -h|--help) echo "$USO"; exit 0 ;;
    -*) echo "Opção desconhecida: $a" >&2; echo "$USO" >&2; exit 1 ;;
    *) [ -z "$DIR" ] || { echo "Mais de uma pasta: $DIR e $a" >&2; echo "$USO" >&2; exit 1; }; DIR="$a" ;;
  esac
done
DIR="${DIR:-_import}"

recusa() { echo "Recusado: $1" >&2; exit 1; }

ROOT="$(git rev-parse --show-toplevel)"
ROOT="$(realpath "$ROOT")"
[ -d "$DIR" ] || recusa "a pasta '$DIR' não existe."
[ -L "${DIR%/}" ] && recusa "'$DIR' é um link simbólico; passe a pasta real."
ABS="$(realpath "$DIR")"
case "$ABS/" in
  "$ROOT"/*) ;;
  *) recusa "'$DIR' resolve para fora do repositório ($ABS)." ;;
esac
REL="${ABS#"$ROOT"}"; REL="${REL#/}"
[ -n "$REL" ] || recusa "'$DIR' é a raiz do repositório."
case "$REL" in
  docs|scripts|.claude|.github|docs/*|scripts/*|.claude/*|.github/*|.git|.git/*)
    recusa "'$DIR' é uma pasta do processo ($REL), não a pasta de entrada." ;;
esac
if [ -e "$ABS/.git" ] || [ -n "$(find "$ABS" -mindepth 1 -name .git -print -quit 2>/dev/null)" ]; then
  recusa "'$DIR' contém um .git (outro repositório)."
fi

cd "$ABS"
mapfile -d '' FILES < <(find . -mindepth 1 \( -type f -o -type l \) ! -path ./.gitkeep -print0 | sort -z)
if [ "${#FILES[@]}" = 0 ]; then
  echo "Nada em $REL/ (só o .gitkeep)."
  exit 0
fi

if [ "$APAGAR" = 0 ]; then
  total=0
  for f in "${FILES[@]}"; do
    s="$(stat -c %s -- "$f" 2>/dev/null || echo 0)"
    [ -L "$f" ] && s=0
    total=$((total + s))
    printf '%10s  %s\n' "$(numfmt --to=iec "$s" 2>/dev/null || echo "$s")" "$REL/${f#./}"
  done
  echo "total: ${#FILES[@]} arquivo(s), $(numfmt --to=iec "$total" 2>/dev/null || echo "$total bytes") em $REL/ (nada apagado; use --apagar)"
  exit 0
fi

n=0
for f in "${FILES[@]}"; do
  p="$REL/${f#./}"
  if git -C "$ROOT" ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
    git -C "$ROOT" rm -q -- "$p"
    echo "apagado (git rm, era rastreado): $p"
  else
    rm -f -- "$f"
    echo "apagado: $p"
  fi
  n=$((n + 1))
done
# Pastas que ficaram vazias (o .gitkeep da raiz da pasta fica).
find . -mindepth 1 -type d -empty -delete
echo "apagados: $n arquivo(s) de $REL/ (o .gitkeep ficou)"
