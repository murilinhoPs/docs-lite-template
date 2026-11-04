#!/usr/bin/env bash
# Escolhe a task do /implementar e confere se ela pode começar (só API REST).
#
# Sem argumento: a task interrompida (linha doing do roadmap), se houver; senão a
# primeira linha todo. Confere que a linha anterior a ela no roadmap tem a issue
# fechada (merge feito e /fechar rodado).
# Com <N> (o usuário escolheu, ex.: hotfix): não confere a ordem; se outra task
# está doing, avisa e sai com 2 para o /implementar pedir confirmação.
#
# Uso: ./scripts/next-task.sh [<N>]
# Imprime: o número da issue. Sai com 0 (pode começar), 1 (bloqueado) ou 2 (hotfix: confirme).
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

ROADMAP="$(git rev-parse --show-toplevel)/docs/roadmap.md"
# "<issue> <status>" de cada linha, na ordem.
ROWS="$(roadmap_rows "$ROADMAP" | awk -F'|' '{ i = $3; s = $5; gsub(/[ \t#]/, "", i); gsub(/[ \t]/, "", s); print i, s }')"

if [ -n "${1:-}" ]; then
  N="${1#\#}"
  [[ "$N" =~ ^[0-9]+$ ]] || { echo "Número de issue inválido: $1" >&2; exit 1; }
  echo "$N"
  CUR="$(awk -v n="$N" '$2 == "doing" && $1 != n { print $1; exit }' <<<"$ROWS")"
  if [ -n "$CUR" ]; then
    echo "A task #$CUR está em andamento; faço o hotfix #$N antes?" >&2
    exit 2
  fi
  exit 0
fi

N="$(awk '$2 == "doing" { print $1; exit }' <<<"$ROWS")"
[ -n "$N" ] || N="$(awk '$2 == "todo" { print $1; exit }' <<<"$ROWS")"
[ -n "$N" ] || { echo "Nenhuma linha todo ou doing no roadmap: rode /planejar." >&2; exit 1; }
echo "$N"

PREV="$(awk -v n="$N" '$1 == n { print p; exit } { p = $1 }' <<<"$ROWS")"
[ -n "$PREV" ] || exit 0
REPO="$(repo_slug)"
if [ "$(gh api "repos/$REPO/issues/$PREV" -q .state)" != closed ]; then
  echo "A task anterior (#$PREV) ainda está aberta: falta o merge ou o /fechar." >&2
  exit 1
fi
