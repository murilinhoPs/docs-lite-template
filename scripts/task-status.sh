#!/usr/bin/env bash
# Muda o status de uma issue no docs/roadmap.md: todo, doing ou done.
#
# O roadmap guarda o destino: o /abrir-pr já marca done, porque é o estado que a
# linha terá quando o PR entrar na main (a coluna PR fica para o open-pr.sh). O
# andamento real (PR aberto, issue fechada) o sync-board.sh lê do GitHub.
# Sincroniza o board quando ele é acessível daqui; senão, avisa e segue.
#
# Uso: ./scripts/task-status.sh <issue> <todo|doing|done>
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

N="${1:?Uso: $0 <issue> <todo|doing|done>}"
STATUS="${2:?Uso: $0 <issue> <todo|doing|done>}"
N="${N#\#}"
[[ "$N" =~ ^[0-9]+$ ]] || { echo "Número de issue inválido: $1" >&2; exit 1; }
[[ "$STATUS" =~ ^(todo|doing|done)$ ]] || { echo "Status inválido: $STATUS (use todo, doing ou done)" >&2; exit 1; }

ROADMAP="$(git rev-parse --show-toplevel)/docs/roadmap.md"
roadmap_set "$ROADMAP" "$N" status "$STATUS"
echo "#$N → $STATUS"

"$(dirname "$0")/sync-board.sh" --auto
