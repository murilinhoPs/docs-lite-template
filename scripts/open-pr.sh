#!/usr/bin/env bash
# Abre o PR de uma issue usando só a API REST do repositório (funciona no
# Claude Code local e nas sessões na nuvem, que não têm GraphQL).
#
# head = branch atual (já com push), base = main, título = título da issue.
# O corpo segue .github/pull_request_template.md:
#   Closes #N · Spec da issue (atualizada nesta branch ou não) · Head (40 caracteres)
#   Tipo (código / só docs, pelo diff) · O que entrou (--summary-file ou stdin)
#   AC da issue · Testes · Prints · Registro · Co-authored-by (--coauthor, última linha)
# Prints: --prints, ou a pasta pr-assets/issue-<N>/<sha7 do head>/ se existir.
# PR só de docs (scripts/docs-only.sh) dispensa prints e testes.
#
# Não faz commit depois de abrir o PR: o head do PR é o commit aprovado (o
# pr-gate confere). O número do PR vai para o roadmap no task-status.sh <N> done.
# Também remove a label status:doing da issue.
# Idempotente: se já existe PR aberto para a branch, só imprime a URL.
#
# --update <pr>: depois de um push num PR aberto, reescreve só o "**Head:**" e a
# pasta de prints do corpo (PATCH), sem mexer no resto.
#
# Uso: ./scripts/open-pr.sh <issue> [--summary-file F] (--tests-file F | --tests "n/a: <motivo>")
#                          [--prints "n/a: <motivo>"] [--coauthor "Nome <email>"]... < resumo.md
#      ./scripts/open-pr.sh --update <pr> [--prints "n/a: <motivo>"]
# Imprime: a URL do PR.
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

usage() {
  sed -n '/^# Uso:/,/^# Imprime/p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}

UPDATE=""
if [ "${1:-}" = --update ]; then
  UPDATE="${2:-}"
  UPDATE="${UPDATE#\#}"
  [[ "$UPDATE" =~ ^[0-9]+$ ]] || usage
  shift 2
else
  N="${1:-}"
  N="${N#\#}"
  [[ "$N" =~ ^[0-9]+$ ]] || usage
  shift
fi
SUMMARY_FILE="" TESTS_FILE="" TESTS="" PRINTS=""
COAUTHORS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --summary-file) SUMMARY_FILE="${2:?}"; shift 2 ;;
    --tests-file) TESTS_FILE="${2:?}"; shift 2 ;;
    --tests) TESTS="${2:?}"; shift 2 ;;
    --prints) PRINTS="${2:?}"; shift 2 ;;
    --coauthor) COAUTHORS+=("${2:?}"); shift 2 ;;
    *) usage ;;
  esac
done

REPO="$(repo_slug)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Linha de prints para o head: --prints, ou a pasta do head na pr-assets. prints_for <issue> <head>
prints_for() {
  local sha7="${2:0:7}"
  if [ -n "$PRINTS" ]; then
    echo "$PRINTS"
  elif git rev-parse -q --verify "origin/pr-assets:issue-$1/$sha7" >/dev/null; then
    echo "[pr-assets/issue-$1/$sha7/](https://github.com/$REPO/tree/pr-assets/issue-$1/$sha7)"
  fi
}

if [ -n "$UPDATE" ]; then
  PR_JSON="$(gh api "repos/$REPO/pulls/$UPDATE")"
  HEAD="$(jq -r .head.sha <<<"$PR_JSON")"
  [ "$(git rev-parse HEAD)" = "$HEAD" ] \
    || echo "aviso: o HEAD local não é o head do PR (${HEAD:0:7}); uso o do PR." >&2
  jq -r '.body // ""' <<<"$PR_JSON" | tr -d '\r' > "$TMP/body.md"
  N="$(grep -m1 -oE '^Closes #[0-9]+' "$TMP/body.md" | tr -dc '0-9' || true)"
  git fetch -q origin pr-assets 2>/dev/null || true
  NEW_PRINTS=""
  [ -z "$N" ] || NEW_PRINTS="$(prints_for "$N" "$HEAD")"
  OLD_PRINTS="$(body_prints "$(cat "$TMP/body.md")")"
  if [ -z "$NEW_PRINTS" ] && [ -n "$OLD_PRINTS" ] && [[ "$HEAD" != "$(basename "$OLD_PRINTS")"* ]]; then
    echo "aviso: $OLD_PRINTS é de outro commit e não há prints do head: teste de novo ou passe --prints \"n/a: <motivo>\" (o pr-gate vai falhar)." >&2
  fi
  awk -v head="$HEAD" -v prints="$NEW_PRINTS" '
    /^\*\*Head:\*\*/ { print "**Head:** " head; done_head = 1; next }
    /^## / { skip = 0 }
    /^## Prints/ && prints != "" { print; print ""; print prints; print ""; skip = 1; next }
    skip { next }
    { print }
    END { if (!done_head) exit 3 }
  ' "$TMP/body.md" > "$TMP/new.md" || {
    # Sem linha Head (PR aberto à mão): ela entra no topo.
    { echo "**Head:** $HEAD"; echo; cat "$TMP/body.md"; } > "$TMP/new.md"
  }
  gh api -X PATCH "repos/$REPO/pulls/$UPDATE" -F "body=@$TMP/new.md" -q .html_url
  exit 0
fi

ROOT="$(git rev-parse --show-toplevel)"
ROADMAP="$ROOT/docs/roadmap.md"
roadmap_has "$ROADMAP" "$N" || { echo "A issue #$N não está no roadmap." >&2; exit 1; }

BRANCH="$(git branch --show-current)"
[ -n "$BRANCH" ] && [ "$BRANCH" != main ] || { echo "Rode a partir da branch da task, não da main." >&2; exit 1; }
git rev-parse --verify -q '@{u}' >/dev/null || { echo "A branch não tem upstream: git push -u origin $BRANCH" >&2; exit 1; }
[ "$(git rev-list --count '@{u}..HEAD')" = 0 ] || { echo "Há commits sem push: git push" >&2; exit 1; }

PR_JSON="$(gh api "repos/$REPO/pulls?state=open&head=${REPO%%/*}:$BRANCH" -q '.[0] // empty')"

if [ -z "$PR_JSON" ]; then
  if [ -z "$SUMMARY_FILE" ]; then
    [ ! -t 0 ] || { echo "Passe o resumo via stdin ou --summary-file." >&2; exit 1; }
    SUMMARY_FILE="$TMP/summary.md"
    cat > "$SUMMARY_FILE"
  fi
  [ -s "$SUMMARY_FILE" ] || { echo "Resumo vazio." >&2; exit 1; }

  ISSUE_JSON="$(gh api "repos/$REPO/issues/$N")"
  TITLE="$(jq -r .title <<<"$ISSUE_JSON")"
  ISSUE_BODY="$(jq -r '.body // ""' <<<"$ISSUE_JSON" | tr -d '\r')"
  HEAD="$(git rev-parse HEAD)"
  SHA7="${HEAD:0:7}"
  git fetch -q origin main pr-assets 2>/dev/null || git fetch -q origin main 2>/dev/null || true
  BASE="$(git merge-base origin/main HEAD 2>/dev/null || git rev-parse origin/main 2>/dev/null || echo HEAD)"
  if docs_only "$BASE" HEAD; then
    TIPO="só docs (dispensa prints e QA)"
    [ -n "$TESTS_FILE" ] || [ -n "$TESTS" ] || TESTS="n/a: PR só de docs"
    [ -n "$PRINTS" ] || PRINTS="n/a: PR só de docs"
  else
    TIPO="código"
  fi
  [ -n "$TESTS_FILE" ] || [ -n "$TESTS" ] || { echo "Passe --tests-file <saída> ou --tests \"n/a: <motivo>\"." >&2; exit 1; }

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
  prints_for "$N" "$HEAD" > "$TMP/prints.md"
  [ -s "$TMP/prints.md" ] || { echo "Não há pr-assets/issue-$N/$SHA7/: passe --prints \"n/a: <motivo>\"." >&2; exit 1; }
  [ -n "$PRINTS" ] || tested_by="usuário + Claude"

  { echo "- Arquivos alterados: $(git diff --name-only "$BASE" HEAD | sed 's/.*/`&`/' | paste -sd ',' - | sed 's/,/, /g')"
    echo "- Testado por: $tested_by"; } > "$TMP/registro.md"

  printf '%s\n' "${COAUTHORS[@]+"${COAUTHORS[@]}"}" | sed '/^$/d; s/^/Co-authored-by: /' > "$TMP/coauthors.md"
  awk -v n="$N" -v spec="$SPEC_LINE" -v head="$HEAD" -v tipo="$TIPO" -v d="$TMP" -v sum="$SUMMARY_FILE" '
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
    /^\*\*Tipo:\*\*/ { print "**Tipo:** " tipo; next }
    /^<!-- Co-authored-by/ { next }
    { print }
  ' "$ROOT/.github/pull_request_template.md" > "$TMP/body.md"
  # Co-authored-by tem de ser a última linha, separada por uma linha em branco, para o
  # GitHub reconhecer o trailer no commit do squash.
  if [ -s "$TMP/coauthors.md" ]; then
    { printf '%s\n\n' "$(cat "$TMP/body.md")"; cat "$TMP/coauthors.md"; } > "$TMP/final.md"
    mv "$TMP/final.md" "$TMP/body.md"
  fi

  PR_JSON="$(gh api "repos/$REPO/pulls" -f "head=$BRANCH" -f base=main \
    -f "title=$TITLE" -F "body=@$TMP/body.md")"
fi

URL="$(jq -r .html_url <<<"$PR_JSON")"

gh api -X DELETE "repos/$REPO/issues/$N/labels/status:doing" >/dev/null 2>&1 || true

echo "$URL"
