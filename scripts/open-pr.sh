#!/usr/bin/env bash
# Abre o PR da task usando só a API REST do repositório (funciona no Claude
# Code local e nas sessões na nuvem, que não têm GraphQL).
#
# head = branch atual (já com push), base = main, título "NNN · <title>".
# O corpo segue .github/pull_request_template.md: Closes #N, Spec e o resumo
# (stdin ou --summary-file) em "O que entrou"; --prints-file vai em "Prints".
#
# O número do PR só existe depois de criado, então ele vai para a coluna PR do
# roadmap num commit seguinte na mesma branch ("NNN · registra PR #N"), com push.
# Também remove a label status:doing da issue.
# Idempotente: se já existe PR aberto para a branch, só registra e imprime a URL.
#
# Uso: ./scripts/open-pr.sh docs/tasks/NNN-<slug>.md [--summary-file F] [--prints-file F] < resumo.md
# Imprime: a URL do PR.
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

usage="Uso: $0 docs/tasks/NNN-<slug>.md [--summary-file F] [--prints-file F] < resumo.md"
TASK="${1:?$usage}"
shift
SUMMARY_FILE=""
PRINTS_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --summary-file) SUMMARY_FILE="${2:?$usage}"; shift 2 ;;
    --prints-file) PRINTS_FILE="${2:?$usage}"; shift 2 ;;
    *) echo "$usage" >&2; exit 1 ;;
  esac
done
[ -f "$TASK" ] || { echo "Arquivo não encontrado: $TASK" >&2; exit 1; }

ROOT="$(git rev-parse --show-toplevel)"
ROADMAP="$ROOT/docs/roadmap.md"
SPEC="$(repo_path "$TASK")"
ID="$(fm_get "$TASK" id)"
TITLE="$(fm_get "$TASK" title)"
ISSUE="$(fm_get "$TASK" issue | tr -d '#')"
[[ "$ISSUE" =~ ^[0-9]+$ ]] || { echo "A task não tem issue: rode ./scripts/create-issue.sh $TASK" >&2; exit 1; }

BRANCH="$(git branch --show-current)"
[ -n "$BRANCH" ] && [ "$BRANCH" != main ] || { echo "Rode a partir da branch da task, não da main." >&2; exit 1; }
git rev-parse --verify -q '@{u}' >/dev/null || { echo "A branch não tem upstream: git push -u origin $BRANCH" >&2; exit 1; }
[ "$(git rev-list --count '@{u}..HEAD')" = 0 ] || { echo "Há commits sem push: git push" >&2; exit 1; }
git diff --quiet -- "$ROADMAP" && git diff --cached --quiet -- "$ROADMAP" \
  || { echo "docs/roadmap.md tem mudanças sem commit." >&2; exit 1; }

REPO="$(repo_slug)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PR_JSON="$(gh api "repos/$REPO/pulls?state=open&head=${REPO%%/*}:$BRANCH" -q '.[0] // empty')"

if [ -z "$PR_JSON" ]; then
  if [ -z "$SUMMARY_FILE" ]; then
    [ ! -t 0 ] || { echo "Passe o resumo via stdin ou --summary-file." >&2; exit 1; }
    SUMMARY_FILE="$TMP/summary.md"
    cat > "$SUMMARY_FILE"
  fi
  [ -s "$SUMMARY_FILE" ] || { echo "Resumo vazio." >&2; exit 1; }

  tested=0
  [ "$(fm_get "$TASK" prints)" = true ] && tested=1
  awk -v issue="$ISSUE" -v spec="$SPEC" -v sum="$SUMMARY_FILE" -v prints="$PRINTS_FILE" -v tested="$tested" '
    function dump(f,  l) { if (f == "") return; print ""; while ((getline l < f) > 0) print l; close(f) }
    /^Closes #/ { print "Closes #" issue; next }
    /^Spec:/ { print "Spec: " spec; next }
    tested && /^- \[ \] Testado pelo Claude/ { sub(/\[ \]/, "[x]") }
    { print }
    /^## O que entrou/ { dump(sum) }
    /^## Prints/ { dump(prints) }
  ' "$ROOT/.github/pull_request_template.md" > "$TMP/body.md"

  PR_JSON="$(gh api "repos/$REPO/pulls" -f "head=$BRANCH" -f base=main \
    -f "title=$ID · $TITLE" -F "body=@$TMP/body.md")"
fi

PR="$(jq -r .number <<<"$PR_JSON")"
URL="$(jq -r .html_url <<<"$PR_JSON")"

gh api -X DELETE "repos/$REPO/issues/$ISSUE/labels/status:doing" >/dev/null 2>&1 || true

roadmap_set "$ROADMAP" "$ID" pr "#$PR"
if ! git diff --quiet -- "$ROADMAP"; then
  git commit -q -m "$ID · registra PR #$PR no roadmap" -- "$ROADMAP"
  git push -q
fi

echo "$URL"
