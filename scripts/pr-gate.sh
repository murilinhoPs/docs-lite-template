#!/usr/bin/env bash
# Merge gate: a aprovação vale para um head específico.
#
# Lê o evento pull_request de $GITHUB_EVENT_PATH e confere:
#   - o "**Head:**" do corpo é o head do PR;
#   - se o corpo cita uma pasta de prints (pr-assets/issue-<N>/<sha7>/), o
#     print_sizes.txt dela diz "commit: <C>", o <sha7> é prefixo de C, e C é o
#     head ou um ancestral dele com só docs mudando depois (o commit do done no
#     roadmap e o "Registra PR #M" não invalidam os prints; código novo invalida).
#     PR só de docs (scripts/docs-only.sh) pula a checagem de prints.
# Roda no job pr-gate de .github/workflows/pr-gate.yml; precisa do head e da
# base no clone (checkout com fetch-depth: 0).
#
# Uso: GITHUB_EVENT_PATH=evento.json ./scripts/pr-gate.sh
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

EVENT="${GITHUB_EVENT_PATH:?Defina GITHUB_EVENT_PATH com o JSON do evento pull_request}"
PR="$(jq -r .pull_request.number "$EVENT")"
HEAD="$(jq -r .pull_request.head.sha "$EVENT")"
BASE="origin/$(jq -r .pull_request.base.ref "$EVENT")"
BODY="$(jq -r '.pull_request.body // ""' "$EVENT" | tr -d '\r')"
UPDATE="./scripts/open-pr.sh --update $PR"

errors=0
fail() { echo "::error::$1"; errors=$((errors + 1)); }

git fetch -q origin "${BASE#origin/}" 2>/dev/null || true

BODY_HEAD="$(body_head "$BODY")"
if [ -z "$BODY_HEAD" ]; then
  fail "O corpo do PR não tem a linha **Head:** com o sha de 40 caracteres: rode \`$UPDATE\`."
elif [ "$BODY_HEAD" != "$HEAD" ]; then
  fail "Head do corpo desatualizado (${BODY_HEAD:0:7}, o PR está em ${HEAD:0:7}): rode \`$UPDATE\`. Se o push mudou código, os testes e os prints precisam ser refeitos."
else
  echo "ok: Head do corpo = head do PR (${HEAD:0:7})"
fi

if docs_only "$BASE" "$HEAD"; then
  echo "ok: PR só de docs, sem checagem de prints"
else
  DIR="$(body_prints "$BODY")"
  if [ -z "$DIR" ]; then
    echo "ok: o corpo não cita pasta de prints"
  else
    SHA7="$(basename "$DIR")"
    SIZES="${DIR#pr-assets/}print_sizes.txt"
    git fetch -q origin pr-assets 2>/dev/null || true
    if ! CONTENT="$(git show "origin/pr-assets:$SIZES" 2>/dev/null)"; then
      fail "Não achei $DIR""print_sizes.txt na branch pr-assets: gere os prints do head (docs/qa/print-rules.md) e rode \`$UPDATE\`."
    else
      COMMIT="$(sed -n 's/^commit:[[:space:]]*//p' <<<"$CONTENT" | head -n1)"
      AGAIN="teste de novo, salve em pr-assets/issue-<N>/${HEAD:0:7}/ e rode \`$UPDATE\`."
      if [[ "$COMMIT" != "$SHA7"* ]]; then
        fail "A pasta $DIR não bate com o commit ${COMMIT:0:7} do print_sizes.txt: $AGAIN"
      elif [ "$COMMIT" = "$HEAD" ]; then
        echo "ok: prints de $DIR são do head"
      elif prints_valid "$COMMIT" "$HEAD"; then
        echo "ok: prints de $DIR (${COMMIT:0:7}) valem para o head: depois deles só mudou docs"
      else
        fail "Os prints de $DIR são do commit ${COMMIT:0:7}, e o código mudou até o head ${HEAD:0:7}: $AGAIN"
      fi
    fi
  fi
fi

[ "$errors" = 0 ] || exit 1
echo "pr-gate: ok"
