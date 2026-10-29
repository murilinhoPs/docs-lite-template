#!/usr/bin/env bash
# Abre o PR de uma issue usando só a API REST do repositório (funciona no
# Claude Code local e nas sessões na nuvem, que não têm GraphQL).
#
# head = branch atual (já com push), base = main, título = título da issue.
# O corpo segue .github/pull_request_template.md:
#   Closes #N · Spec da issue (atualizada nesta branch ou não) · Head (40 caracteres)
#   O que entrou (--summary-file ou stdin) · AC da issue · Testes · Prints · Registro
# Prints: --prints, ou a pasta pr-assets/issue-<N>/<sha7 do head>/ se existir.
#
# O número do PR só existe depois de criado, então ele vai para a coluna PR do
# roadmap num commit seguinte na mesma branch ("Registra PR #M no roadmap", só
# docs/roadmap.md), com push. Também remove a label status:doing da issue.
# Idempotente: se já existe PR aberto para a branch, só registra e imprime a URL.
#
# Uso: ./scripts/open-pr.sh <issue> [--summary-file F] (--tests-file F | --tests "n/a: <motivo>")
#                          [--prints "n/a: <motivo>"] < resumo.md
# Imprime: a URL do PR.
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

usage() {
  sed -n '/^# Uso:/,/^# Imprime/p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}

N="${1:-}"
N="${N#\#}"
[[ "$N" =~ ^[0-9]+$ ]] || usage
shift
SUMMARY_FILE="" TESTS_FILE="" TESTS="" PRINTS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --summary-file) SUMMARY_FILE="${2:?}"; shift 2 ;;
    --tests-file) TESTS_FILE="${2:?}"; shift 2 ;;
    --tests) TESTS="${2:?}"; shift 2 ;;
    --prints) PRINTS="${2:?}"; shift 2 ;;
    *) usage ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel)"
ROADMAP="$ROOT/docs/roadmap.md"
roadmap_has "$ROADMAP" "$N" || { echo "A issue #$N não está no roadmap." >&2; exit 1; }

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
  [ -n "$TESTS_FILE" ] || [ -n "$TESTS" ] || { echo "Passe --tests-file <saída> ou --tests \"n/a: <motivo>\"." >&2; exit 1; }

  ISSUE_JSON="$(gh api "repos/$REPO/issues/$N")"
  TITLE="$(jq -r .title <<<"$ISSUE_JSON")"
  ISSUE_BODY="$(jq -r '.body // ""' <<<"$ISSUE_JSON" | tr -d '\r')"
  HEAD="$(git rev-parse HEAD)"
  SHA7="${HEAD:0:7}"
  git fetch -q origin main pr-assets 2>/dev/null || git fetch -q origin main 2>/dev/null || true
  BASE="$(git merge-base origin/main HEAD 2>/dev/null || git rev-parse origin/main 2>/dev/null || echo HEAD)"

  SPEC="$(spec_from_body "$ISSUE_BODY")"
  if [ -z "$SPEC" ]; then
    SPEC_LINE="— (não muda comportamento)"
  elif git diff --quiet "$BASE" HEAD -- "$SPEC"; then
    SPEC_LINE="$SPEC (não muda comportamento)"
  else
    SPEC_LINE="$SPEC (atualizada)"
  fi

  # AC: os itens da seção "Critérios de aceite" da issue.
  awk '/^## /{ s = ($0 ~ /^## Critérios de aceite/); next } s && /^- \[/' <<<"$ISSUE_BODY" > "$TMP/ac.md"
  [ -s "$TMP/ac.md" ] || echo "- [ ] n/a: a issue não lista critérios de aceite" > "$TMP/ac.md"

  if [ -n "$TESTS_FILE" ]; then
    { echo '```text'; cat "$TESTS_FILE"; echo '```'; echo; echo "\`git rev-parse --short HEAD\`: $SHA7"; } > "$TMP/tests.md"
  else
    echo "$TESTS" > "$TMP/tests.md"
  fi

  tested_by="usuário"
  if [ -n "$PRINTS" ]; then
    echo "$PRINTS" > "$TMP/prints.md"
  elif git rev-parse -q --verify "origin/pr-assets:issue-$N/$SHA7" >/dev/null; then
    echo "[pr-assets/issue-$N/$SHA7/](https://github.com/$REPO/tree/pr-assets/issue-$N/$SHA7)" > "$TMP/prints.md"
    tested_by="usuário + Claude"
  else
    echo "Não há pr-assets/issue-$N/$SHA7/: passe --prints \"n/a: <motivo>\"." >&2
    exit 1
  fi

  { echo "- Arquivos alterados: $(git diff --name-only "$BASE" HEAD | sed 's/.*/`&`/' | paste -sd ',' - | sed 's/,/, /g')"
    echo "- Testado por: $tested_by"; } > "$TMP/registro.md"

  awk -v n="$N" -v spec="$SPEC_LINE" -v head="$HEAD" -v d="$TMP" -v sum="$SUMMARY_FILE" '
    function dump(f,  l) { print ""; while ((getline l < f) > 0) print l; close(f); print "" }
    /^## / {
      skip = 0
      print
      if ($0 ~ /O que entrou/) { dump(sum); skip = 1 }
      else if ($0 ~ /Critérios de aceite/) { dump(d "/ac.md"); skip = 1 }
      else if ($0 ~ /Testes/) { dump(d "/tests.md"); skip = 1 }
      else if ($0 ~ /Prints/) { dump(d "/prints.md"); skip = 1 }
      else if ($0 ~ /Registro/) { dump(d "/registro.md"); skip = 1 }
      next
    }
    skip { next }
    /^Closes #/ { print "Closes #" n; next }
    /^\*\*Spec:\*\*/ { print "**Spec:** " spec; next }
    /^\*\*Head:\*\*/ { print "**Head:** " head; next }
    { print }
  ' "$ROOT/.github/pull_request_template.md" > "$TMP/body.md"

  PR_JSON="$(gh api "repos/$REPO/pulls" -f "head=$BRANCH" -f base=main \
    -f "title=$TITLE" -F "body=@$TMP/body.md")"
fi

PR="$(jq -r .number <<<"$PR_JSON")"
URL="$(jq -r .html_url <<<"$PR_JSON")"

gh api -X DELETE "repos/$REPO/issues/$N/labels/status:doing" >/dev/null 2>&1 || true

roadmap_set "$ROADMAP" "$N" pr "#$PR"
if ! git diff --quiet -- "$ROADMAP"; then
  git commit -q -m "Registra PR #$PR no roadmap" -- "$ROADMAP"
  git push -q
fi

echo "$URL"
