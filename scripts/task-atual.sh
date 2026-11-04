#!/usr/bin/env bash
# Descobre de que task estamos falando: a issue, a branch e o PR (só API REST do repo).
# Usado pelo /abrir-pr e pelo /revisar, para os dois terem a mesma regra.
#
# Ordem (para na primeira que decide):
#   1. argumento <N>;
#   2. a branch atual, se for task/<N>-<slug>;
#   3. a única linha doing do docs/roadmap.md;
#   4. a única branch local task/* com commits que a origin/main não tem e issue aberta.
# Nunca chuta: com mais de um candidato, lista todos e sai com 2.
#
# Uso: ./scripts/task-atual.sh [<N>]
# Imprime: issue=<N> branch=<task/N-slug|-> pr=<P|-> pr_state=<open|merged|closed|-> origem=<arg|branch|roadmap|commits>
# Sai com 0 (achou uma), 1 (a issue está fechada), 2 (ambíguo: candidatos, um por linha) ou 3 (nada).
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

ROOT="$(git rev-parse --show-toplevel)"
ROADMAP="$ROOT/docs/roadmap.md"
REPO="$(repo_slug)"
BASE=origin/main
git rev-parse -q --verify "$BASE" >/dev/null || BASE=main

# Branch da issue: local task/<N>-*, ou só em origin. branch_of <N>
branch_of() {
  local b
  b="$(git for-each-ref --format='%(refname:short)' "refs/heads/task/$1-*" | head -n1)"
  [ -n "$b" ] || b="$(git for-each-ref --format='%(refname:short)' "refs/remotes/origin/task/$1-*" | head -n1 | sed 's#^origin/##')"
  echo "${b:--}"
}

ambiguo() {
  echo "Mais de uma task possível ($1); passe o número da issue:" >&2
  printf '%s\n' "${@:2}"
  exit 2
}

N="" ORIGEM=""
if [ -n "${1:-}" ]; then
  N="${1#\#}"
  [[ "$N" =~ ^[0-9]+$ ]] || { echo "Número de issue inválido: $1" >&2; exit 1; }
  ORIGEM=arg
fi

if [ -z "$N" ]; then
  CUR="$(git branch --show-current)"
  if [[ "$CUR" =~ ^task/([0-9]+)- ]]; then
    N="${BASH_REMATCH[1]}"
    ORIGEM=branch
  fi
fi

if [ -z "$N" ]; then
  DOING="$(roadmap_rows "$ROADMAP" | awk -F'|' '{ i = $3; s = $5; gsub(/[ \t#]/, "", i); gsub(/[ \t]/, "", s) } s == "doing" { print i }')"
  case "$(grep -c . <<<"$DOING" || true)" in
    0) ;;
    1) N="$DOING"; ORIGEM=roadmap ;;
    *) mapfile -t c < <(while read -r i; do echo "issue=$i branch=$(branch_of "$i") razão=linha doing no roadmap"; done <<<"$DOING")
       ambiguo "mais de uma linha doing no roadmap" "${c[@]}" ;;
  esac
fi

if [ -z "$N" ]; then
  CANDS=()
  for b in $(git for-each-ref --format='%(refname:short)' 'refs/heads/task/*'); do
    [[ "$b" =~ ^task/([0-9]+)- ]] || continue
    i="${BASH_REMATCH[1]}"
    [ "$(git rev-list --count "$BASE..$b")" -gt 0 ] || continue
    [ "$(gh api "repos/$REPO/issues/$i" -q .state 2>/dev/null)" = open ] || continue
    CANDS+=("issue=$i branch=$b razão=commits à frente da main")
  done
  case "${#CANDS[@]}" in
    0) echo "Não achei task implementada: rode /implementar ou passe o número da issue." >&2; exit 3 ;;
    1) N="$(sed 's/^issue=\([0-9]*\) .*/\1/' <<<"${CANDS[0]}")"; ORIGEM=commits ;;
    *) ambiguo "mais de uma branch task/* à frente da main" "${CANDS[@]}" ;;
  esac
fi

if [ "$(gh api "repos/$REPO/issues/$N" -q .state)" = closed ]; then
  echo "A issue #$N está fechada: a task já foi entregue (veja o PR dela) ou foi cancelada." >&2
  exit 1
fi

BRANCH="$(branch_of "$N")"
PR=- PR_STATE=-
if [ "$BRANCH" != - ]; then
  PULLS="$(gh api "repos/$REPO/pulls?state=all&head=${REPO%%/*}:$BRANCH&per_page=100")"
  read -r PR PR_STATE < <(jq -r '
    ([.[] | select(.state == "open")][0] // [.[] | select(.merged_at != null)][0] // .[0]) as $p
    | if $p == null then "- -" else "\($p.number) \(if $p.state == "open" then "open" elif $p.merged_at != null then "merged" else "closed" end)" end' <<<"$PULLS")
fi

echo "issue=$N branch=$BRANCH pr=$PR pr_state=$PR_STATE origem=$ORIGEM"
