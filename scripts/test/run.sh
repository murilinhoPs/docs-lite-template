#!/usr/bin/env bash
# Testes dos scripts com gh simulado (scripts/test/bin/gh).
# Cada teste roda numa cópia do repo, com origin https://github.com/acme/proj
# e um repo bare local no lugar do GitHub para o push.
#
# Uso: ./scripts/test/run.sh
set -euo pipefail

SRC="$(git rev-parse --show-toplevel)"
STUB="$SRC/scripts/test/bin"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export GH_REPO=acme/proj
unset GITHUB_REPOSITORY

pass=0
fail=0
ok() { echo "  ok    $1"; pass=$((pass + 1)); }
ko() { echo "  FALHA $1"; fail=$((fail + 1)); }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else ko "$name"; fi; }

# Cria um repo de teste em $WORK/<nome> e entra nele.
setup() {
  local dir="$WORK/$1"
  mkdir -p "$dir/repo" "$dir/state"
  git -C "$SRC" ls-files -co --exclude-standard -z | (cd "$SRC" && xargs -0 cp --parents -t "$dir/repo")
  rm -f "$dir/repo/scripts/board.conf"
  git init -q --bare "$dir/remote.git"
  cd "$dir/repo"
  git init -q -b main
  git config user.email t@t
  git config user.name t
  git config commit.gpgsign false
  git config push.negotiate false
  git remote add origin https://github.com/acme/proj.git
  git config "url.$dir/remote.git.pushInsteadOf" https://github.com/acme/proj.git
  # O fetch também vai para o bare (o get-url de origin continua mostrando o GitHub).
  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git config "url.$dir/remote.git.insteadOf" https://github.com/acme/proj.git
  git add -A && git commit -qm init && git push -q -u origin main

  export GH_STATE="$dir/state" GH_LOG="$dir/state/gh.log" GH_LOCAL=0
  : > "$GH_LOG"
  echo 0 > "$GH_STATE/counter"
  echo '[{"number":3,"title":"M0 Fundação"},{"number":4,"title":"M1 MVP"}]' > "$GH_STATE/milestones.json"
  echo '[]' > "$GH_STATE/issues.json"
  echo '[]' > "$GH_STATE/pulls.json"
  echo '{"items":[]}' > "$GH_STATE/items.json"
  cat > "$GH_STATE/fields.json" <<'JSON'
{"fields":[
  {"id":"F_ETAPA","name":"Etapa","options":[{"id":"O_todo","name":"todo"},{"id":"O_doing","name":"doing"},{"id":"O_review","name":"review"},{"id":"O_done","name":"done"}]},
  {"id":"F_ORDEM","name":"Ordem"}]}
JSON
}

PATH="$STUB:$PATH"
R=docs/roadmap.md
count() { grep -c -- "$1" "$GH_LOG" || true; }
# Linhas de issue do roadmap, sem espaços: "1|#2|[feat] A|todo|specs/a.md|" etc.
rows() { grep -E '^\|[^|]*\|[ ]*#[0-9]+' "$R" | sed -E 's/^\| *//; s/ *\| *$//; s/ *\| */|/g'; }
section() { awk -v h="## $1" '$0 == h { s = 1; next } /^## / { s = 0 } s && /\| #[0-9]/' "$R" | sed -E 's/^\| *//; s/ *\| *$//; s/ *\| */|/g'; }
# Toda chamada à API usa só rotas do repo e nenhum comando GraphQL foi usado.
only_repo_routes() {
  ! grep '^API ' "$GH_LOG" | grep -qv "^API [A-Z]* repos/acme/proj/" &&
    ! grep -qE '^gh (issue|pr|repo|label) ' "$GH_LOG"
}
no_graphql() { only_repo_routes && ! grep -q '^gh project ' "$GH_LOG"; }
body() { printf '**Spec:** docs/specs/%s.md  (F1)\n**Área:** area:x\n\n## Critérios de aceite\n- [ ] AC-F1-01: entra\n- [ ] AC-F1-02: sai\n' "$1" > "$GH_STATE/$1.md"; echo "$GH_STATE/$1.md"; }

echo "repo_slug"
(
  source "$SRC/scripts/lib.sh"
  cd "$WORK" && git init -q slug && cd slug
  for url in git@github.com:acme/proj.git https://github.com/acme/proj https://github.com/acme/proj.git/ \
    http://local_proxy@127.0.0.1:4444/git/acme/proj; do
    git remote remove origin 2>/dev/null || true
    git remote add origin "$url"
    check "$url" test "$(repo_slug)" = acme/proj
  done
  check "GITHUB_REPOSITORY tem prioridade" test "$(GITHUB_REPOSITORY=o/r repo_slug)" = o/r
  exit "$fail"
) || fail=$((fail + 1))

echo "new-issue.sh"
setup new
a="$(./scripts/new-issue.sh --title "[feat] A" --body-file "$(body a)" --milestone "M1 MVP" --labels "type:feature, area:x")"
b="$(./scripts/new-issue.sh --title "[chore] B" --body-file "$(body b)" --milestone M0 --labels type:chore)"
c="$(./scripts/new-issue.sh --title "[feat] C" --body-file "$(body c)" --milestone "M1 MVP" --labels type:feature --after "$b")"
d="$(./scripts/new-issue.sh --title "[feat] D | E" --body-file "$(body d)" --milestone "M1 MVP" --labels type:feature)"
check "imprime os números" test "$a $b $c $d" = "1 2 3 4"
check "título, milestone e labels" test "$(jq -c '.[0] | [.title, .milestone.title, [.labels[].name]]' "$GH_STATE/issues.json")" \
  = '["[feat] A","M1 MVP",["type:feature","area:x"]]'
check "corpo da issue = --body-file" test "$(jq -r '.[0].body' "$GH_STATE/issues.json")" = "$(cat "$GH_STATE/a.md")"
check "fim do milestone e --after, com Ordem renumerada" test "$(rows | paste -sd ' ')" \
  = "1|#2|[chore] B|todo|specs/b.md| 2|#3|[feat] C|todo|specs/c.md| 3|#1|[feat] A|todo|specs/a.md| 4|#4|[feat] D / E|todo|specs/d.md|"
check "--after de outro milestone entra logo depois dele (seção M0)" test "$(section 'M0 Fundação' | cut -d'|' -f2 | paste -sd ' ')" = "#2 #3"
jq '. += [{"number":9,"title":"[bug] Quebrou","body":"**Spec:** docs/specs/a.md  (F1)\r\n","milestone":{"number":4,"title":"M1 MVP"},"labels":[{"name":"type:bug"}],"state":"open"}]' \
  "$GH_STATE/issues.json" > "$GH_STATE/x" && mv "$GH_STATE/x" "$GH_STATE/issues.json"
e="$(./scripts/new-issue.sh --existing 9 --after 1)"
e2="$(./scripts/new-issue.sh --existing 9)"
check "--existing põe a issue no roadmap" test "$e:$e2:$(rows | sed -n 4p)" = "9:9:4|#9|[bug] Quebrou|todo|specs/a.md|"
check "--existing duas vezes não duplica a linha" test "$(grep -c '| #9 |' "$R")" = 1
posts="$(count 'API POST repos/acme/proj/issues$')"
check "milestone inexistente falha antes de criar" bash -c "! ./scripts/new-issue.sh --title '[feat] X' --body-file $GH_STATE/a.md --milestone M9 --labels type:feature"
check "--after inexistente falha antes de criar" bash -c "! ./scripts/new-issue.sh --title '[feat] X' --body-file $GH_STATE/a.md --milestone M1 --labels type:feature --after 77"
check "título sem [feat]/[bug]/[chore]/[docs] falha" bash -c "! ./scripts/new-issue.sh --title 'X' --body-file $GH_STATE/a.md --milestone M1 --labels type:feature"
check "nenhuma issue criada nos erros" test "$(count 'API POST repos/acme/proj/issues$')" = "$posts"
check "só rotas repos/acme/proj e nada de GraphQL" no_graphql

echo "task-status.sh"
./scripts/task-status.sh 3 doing >/dev/null
check "status doing no roadmap" test "$(rows | sed -n 2p)" = "2|#3|[feat] C|doing|specs/c.md|"
check "label status:doing na issue" test "$(jq -c '.[] | select(.number == 3) | [.labels[].name] | sort' "$GH_STATE/issues.json")" = '["status:doing","type:feature"]'
./scripts/task-status.sh 3 review >/dev/null
check "review tira a label" test "$(jq -c '.[] | select(.number == 3) | [.labels[].name]' "$GH_STATE/issues.json")" = '["type:feature"]'
check "issue fora do roadmap falha" bash -c '! ./scripts/task-status.sh 77 doing'
check "status inválido falha" bash -c '! ./scripts/task-status.sh 3 feito'
check "sem board.conf não chama o Projects" test "$(count '^gh project')" = 0
check "só rotas repos/acme/proj e nada de GraphQL" no_graphql
printf 'OWNER=acme\nPROJECT_NUMBER=7\n' > scripts/board.conf
./scripts/task-status.sh 3 doing >/dev/null
check "com board.conf mas sem acesso ao Projects (nuvem), não sincroniza" test "$(count 'project item-edit')" = 0
GH_LOCAL=1 ./scripts/task-status.sh 3 doing >/dev/null
check "com acesso ao Projects (local), sincroniza" test "$(count 'project item-edit')" -gt 0

echo "open-pr.sh"
setup pr
n="$(./scripts/new-issue.sh --title "[feat] Login" --body-file "$(body auth)" --milestone M1 --labels type:feature)"
git commit -qam "roadmap" && git push -q
git switch -qc "task/$n-login"
./scripts/task-status.sh "$n" doing >/dev/null
mkdir -p docs/specs && echo "# F1" > docs/specs/auth.md && echo app > app.txt
git add -A && git commit -qm "Login"
./scripts/task-status.sh "$n" review >/dev/null
git commit -qam "review" && git push -qu origin "task/$n-login"
HEAD_SHA="$(git rev-parse HEAD)"
echo "Tela de login." > "$GH_STATE/summary.md"
printf 'PASS login\n' > "$GH_STATE/tests.txt"
check "sem prints do head e sem --prints falha antes de criar" \
  bash -c "! ./scripts/open-pr.sh $n --summary-file $GH_STATE/summary.md --tests-file $GH_STATE/tests.txt"
check "sem --tests nem --tests-file falha" bash -c "! ./scripts/open-pr.sh $n --summary-file $GH_STATE/summary.md --prints 'n/a: x'"
check "nenhum PR criado nos erros" test "$(count 'API POST repos/acme/proj/pulls$')" = 0
# Prints do head na pr-assets.
git worktree add -q --orphan -b pr-assets "$WORK/assets" 2>/dev/null || { git switch -q --orphan pr-assets && git switch -q -; }
(cd "$WORK/assets" && mkdir -p "issue-$n/${HEAD_SHA:0:7}" && echo png > "issue-$n/${HEAD_SHA:0:7}/ac-f1-01.png" \
  && git add -A && git commit -qm prints && git push -q origin pr-assets)
url="$(./scripts/open-pr.sh "$n" --tests-file "$GH_STATE/tests.txt" < "$GH_STATE/summary.md")"
check "imprime a URL do PR" test "$url" = "https://github.com/acme/proj/pull/$((n + 1))"
check "título da issue e branches" test "$(jq -c '.[0] | [.title, .head.ref, .base.ref]' "$GH_STATE/pulls.json")" \
  = "[\"[feat] Login\",\"task/$n-login\",\"main\"]"
pr_body="$(jq -r '.[0].body' "$GH_STATE/pulls.json")"
has_line() { grep -qxF -- "$1" <<<"$pr_body"; }
check "corpo: Closes" has_line "Closes #$n"
check "corpo: spec atualizada na branch" has_line "**Spec:** docs/specs/auth.md (atualizada)"
check "corpo: Head de 40 caracteres" has_line "**Head:** $HEAD_SHA"
check "corpo: resumo" has_line "Tela de login."
check "corpo: AC da issue" test "$(grep -c '^- \[ \] AC-F1-0[12]' <<<"$pr_body")" = 2
check "corpo: saída dos testes + sha curto" test "$(has_line 'PASS login' && grep -c "git rev-parse --short HEAD\`: ${HEAD_SHA:0:7}" <<<"$pr_body")" = 1
check "corpo: pasta de prints do head" grep -qF "pr-assets/issue-$n/${HEAD_SHA:0:7}/" <<<"$pr_body"
check "corpo: Registro" test "$(has_line '- Testado por: usuário + Claude' && grep -c '^- Arquivos alterados: .*`app.txt`' <<<"$pr_body")" = 1
check "corpo: sem placeholders do template" bash -c '! grep -qE "<sha de 40|AC-\.\.\.|^pr-assets/issue-<N>|saída real" <<<"$0"' "$pr_body"
check "corpo: Tipo código" has_line "**Tipo:** código"
check "sem commit depois de abrir o PR (head = commit aprovado)" test "$(git rev-parse HEAD):$(git rev-parse '@{u}')" = "$HEAD_SHA:$HEAD_SHA"
check "coluna PR fica vazia até o done" test "$(rows)" = "1|#$n|[feat] Login|review|specs/auth.md|"
check "label status:doing removida" test "$(jq -c '.[0].labels | map(.name)' "$GH_STATE/issues.json")" = '["type:feature"]'
url2="$(./scripts/open-pr.sh "$n" </dev/null)"
check "segunda execução não abre outro PR" test "$url2:$(count 'API POST repos/acme/proj/pulls$')" = "$url:1"
check "só rotas repos/acme/proj e nada de GraphQL" no_graphql

echo "pr-gate.sh (CA-C1)"
PR=$((n + 1))
# Evento pull_request montado a partir do PR simulado.
event() { gh api "repos/acme/proj/pulls/$PR" 2>/dev/null | jq '{pull_request: (. + {base: {ref: "main"}})}' > "$GH_STATE/event.json"; }
gate() { GITHUB_EVENT_PATH="$GH_STATE/event.json" ./scripts/pr-gate.sh; }
assets() { (cd "$WORK/assets" && mkdir -p "issue-$n/$1" && printf 'commit: %s\nac-f1-01.png  1x1  %064d\n' "$2" 0 > "issue-$n/$1/print_sizes.txt" \
  && git add -A && git commit -qm "prints $1" && git push -q origin pr-assets); }
assets "${HEAD_SHA:0:7}" "$HEAD_SHA"
event
check "passa quando Head e prints batem com o head" gate
o="$(gate 2>&1 || true)"
check "imprime o que conferiu" grep -q "ok: prints de pr-assets/issue-$n/${HEAD_SHA:0:7}/ são do head" <<<"$o"
echo "mais código" >> app.txt && git commit -qam "Corrige login" && git push -q
NEW_SHA="$(git rev-parse HEAD)"
event
o="$(gate 2>&1 || true)"
check "falha com Head divergente depois de um push" grep -q "::error::Head do corpo desatualizado" <<<"$o"
check "a mensagem diz para rodar open-pr.sh --update" grep -qF "./scripts/open-pr.sh --update $PR" <<<"$o"
old_body="$(jq -r --argjson p "$PR" '.[] | select(.number == $p) | .body' "$GH_STATE/pulls.json")"
warn="$(./scripts/open-pr.sh --update "$PR" 2>&1 >/dev/null)"
new_body="$(jq -r --argjson p "$PR" '.[] | select(.number == $p) | .body' "$GH_STATE/pulls.json")"
check "--update reescreve o Head" grep -qxF "**Head:** $NEW_SHA" <<<"$new_body"
check "--update não mexe no resto do corpo" test "$(diff <(echo "$old_body") <(echo "$new_body") | grep -c '^[<>]')" = 2
check "--update avisa que os prints são de outro commit" grep -q "é de outro commit" <<<"$warn"
check "--update usa PATCH em repos/acme/proj/pulls/N" grep -q "^API PATCH repos/acme/proj/pulls/$PR$" "$GH_LOG"
event
o="$(gate 2>&1 || true)"
check "falha com prints de outro commit" grep -q "::error::A pasta de prints pr-assets/issue-$n/${HEAD_SHA:0:7}/ não é do head" <<<"$o"
assets "${NEW_SHA:0:7}" "$HEAD_SHA"
./scripts/open-pr.sh --update "$PR" >/dev/null 2>&1
event
o="$(gate 2>&1 || true)"
check "--update aponta para a pasta de prints do head novo" grep -qF "pr-assets/issue-$n/${NEW_SHA:0:7}/" <<<"$(jq -r '.pull_request.body' "$GH_STATE/event.json")"
check "falha com print_sizes.txt de outro commit" grep -q "::error::Os prints de pr-assets/issue-$n/${NEW_SHA:0:7}/ são do commit ${HEAD_SHA:0:7}" <<<"$o"
(cd "$WORK/assets" && rm -rf "issue-$n/${NEW_SHA:0:7}" && git commit -qam x && git push -q origin pr-assets)
assets "${NEW_SHA:0:7}" "$NEW_SHA"
event
check "passa de novo com prints do head novo" gate
jq '.pull_request.body |= sub("\\*\\*Head:\\*\\*[^\n]*\n"; "")' "$GH_STATE/event.json" > "$GH_STATE/x" && mv "$GH_STATE/x" "$GH_STATE/event.json"
o="$(gate 2>&1 || true)"
check "falha sem a linha Head" grep -q "::error::O corpo do PR não tem a linha \*\*Head:\*\*" <<<"$o"
check "só rotas repos/acme/proj e nada de GraphQL" no_graphql

echo "task-status.sh done"
git switch -q main
jq --argjson p "$PR" 'map(if .number == $p then .state = "closed" | .merged_at = "2026-01-01T00:00:00Z" else . end)' \
  "$GH_STATE/pulls.json" > "$GH_STATE/x" && mv "$GH_STATE/x" "$GH_STATE/pulls.json"
./scripts/task-status.sh "$n" done >/dev/null
check "done grava o PR mergeado que fecha a issue" test "$(rows)" = "1|#$n|[feat] Login|done|specs/auth.md|#$PR"
check "só rotas repos/acme/proj e nada de GraphQL" no_graphql

echo "PR só de docs (CA-C4)"
setup docs
n="$(./scripts/new-issue.sh --title "[docs] Spec" --body-file "$(body a)" --milestone M1 --labels type:docs)"
git commit -qam roadmap && git push -q
git switch -qc "task/$n-spec"
mkdir -p docs/specs && echo "# F1" > docs/specs/a.md && git add -A && git commit -qm spec
check "só docs/: só docs" ./scripts/docs-only.sh main HEAD
echo "x" >> README.md && git commit -qam readme
check "*.md fora de docs/: só docs" ./scripts/docs-only.sh main HEAD
git switch -qc claude-md
echo "x" >> CLAUDE.md && git commit -qam claude
check "CLAUDE.md conta como código" bash -c '! ./scripts/docs-only.sh main HEAD'
git switch -q "task/$n-spec" && git switch -qc script
echo "x" > scripts/novo.sh && git add -A && git commit -qm script
check "script conta como código" bash -c '! ./scripts/docs-only.sh main HEAD'
git switch -q "task/$n-spec"
git push -qu origin "task/$n-spec"
echo "Spec da F1." | ./scripts/open-pr.sh "$n" --coauthor "Ana <ana@x.dev>" --coauthor "Bia <bia@x.dev>" >/dev/null
pr_body="$(jq -r '.[0].body' "$GH_STATE/pulls.json")"
check "PR só de docs abre sem --tests nem prints" test "$(count 'API POST repos/acme/proj/pulls$')" = 1
check "corpo: Tipo só docs" has_line "**Tipo:** só docs (dispensa prints e QA)"
check "corpo: prints e testes n/a" test "$(grep -cx 'n/a: PR só de docs' <<<"$pr_body")" = 2
check "Co-authored-by são as últimas linhas, depois de uma linha em branco (C2)" \
  test "$(tail -n 3 <<<"$pr_body" | paste -sd '|')" = "|Co-authored-by: Ana <ana@x.dev>|Co-authored-by: Bia <bia@x.dev>"
check "corpo: sem o comentário de coautoria do template" bash -c '! grep -q "<!-- Co-authored-by" <<<"$0"' "$pr_body"
PR="$(jq -r '.[0].number' "$GH_STATE/pulls.json")"
event
jq '.pull_request.body += "\n\npr-assets/issue-1/0000000/"' "$GH_STATE/event.json" > "$GH_STATE/x" && mv "$GH_STATE/x" "$GH_STATE/event.json"
check "pr-gate: PR só de docs pula a checagem de prints" gate
jq --arg h "$(printf '%040d' 0)" '.pull_request.head.sha = $h' "$GH_STATE/event.json" > "$GH_STATE/x"
check "pr-gate: PR só de docs ainda confere o Head" bash -c '! GITHUB_EVENT_PATH="$0" ./scripts/pr-gate.sh' "$GH_STATE/x"

echo "ci.yml (CA-C3)"
check "ci roda em todo pull_request, sem filtro de paths" \
  test "$(yq -r '(.on // .["true"]) | (.pull_request | tostring) + "|" + (.pull_request.paths | tostring)' .github/workflows/ci.yml)" = "null|null"
check "job se chama ci" test "$(yq -r '.jobs | keys | join(",")' .github/workflows/ci.yml)" = ci
STEP="$(yq -r '.jobs.ci.steps[1].run' .github/workflows/ci.yml)"
: > "$GH_STATE/out"
BASE=main GITHUB_OUTPUT="$GH_STATE/out" bash -ec "$STEP" >/dev/null
check "PR só de docs: ci verde logo no início" grep -qx "only=true" "$GH_STATE/out"
git switch -q script
: > "$GH_STATE/out"
BASE=main GITHUB_OUTPUT="$GH_STATE/out" bash -ec "$STEP" >/dev/null
check "PR de código: segue para os testes da stack" test ! -s "$GH_STATE/out"
check "pr-gate.yml: job pr-gate em opened/reopened/synchronize/edited" \
  test "$(yq -r '.jobs | keys | join(",")' .github/workflows/pr-gate.yml):$(yq -r '(.on // .["true"]).pull_request.types | join(",")' .github/workflows/pr-gate.yml)" \
  = "pr-gate:opened,reopened,synchronize,edited"

echo "bootstrap.sh (CA-C2)"
setup boot
export GH_LOCAL=1
sed -i 's/| F1 | <nome> | Must | \[specs\/<feature>.md\](specs\/<feature>.md) | area:<x> |/| F1 | Login | Must | x | area:auth |/' docs/prd.md
./scripts/bootstrap.sh >"$GH_STATE/boot.out" 2>&1 || { ko "bootstrap terminou com erro"; sed "s/^/    /" "$GH_STATE/boot.out"; }
check "copia o projeto modelo murilinhoPs/2" grep -q '^gh project copy 2 --source-owner murilinhoPs' "$GH_LOG"
check "squash com título e corpo do PR" \
  grep -qF 'BODY PATCH repos/acme/proj {"squash_merge_commit_title":"PR_TITLE","squash_merge_commit_message":"PR_BODY"}' "$GH_LOG"
check "ruleset com ci e pr-gate obrigatórios, strict" test "$(jq -c '.[0].rules[] | select(.type == "required_status_checks") | .parameters | [.strict_required_status_checks_policy, [.required_status_checks[].context]]' "$GH_STATE/rulesets.json")" \
  = '[true,["ci","pr-gate"]]'
check "cria type:design e as area:* da tabela Features" \
  test "$(grep -c '^gh label create type:design\|^gh label create area:auth' "$GH_LOG")" = 2
check "cria a issue de setup com o AC do ci.yml" grep -q 'AC-SETUP-03: `.github/workflows/ci.yml` roda lint e testes da stack' <<<"$(jq -r '.[0].body' "$GH_STATE/issues.json")"
rm -f scripts/board.conf
./scripts/bootstrap.sh >"$GH_STATE/boot2.out" 2>&1
check "rodar de novo atualiza o ruleset (PUT), sem criar outro" \
  test "$(count '^API PUT repos/acme/proj/rulesets/51$'):$(count '^API POST repos/acme/proj/rulesets$'):$(jq length "$GH_STATE/rulesets.json")" = "1:1:1"
rm -f scripts/board.conf
GH_COPY_FAILS=1 ./scripts/bootstrap.sh >"$GH_STATE/boot3.out" 2>&1
check "sem o modelo, cria o board vazio" grep -q '^gh project create' "$GH_LOG"
check "gh api só com rotas repos/acme/proj (gh label/repo/project são locais)" \
  bash -c '! grep "^API " "$0" | grep -qv "^API [A-Z]* repos/acme/proj\(/\|$\)"' "$GH_LOG"
export GH_LOCAL=0

echo "sync-board.sh"
setup sync
printf 'OWNER=acme\nPROJECT_NUMBER=7\n' > scripts/board.conf
check "--auto sem acesso ao Projects (nuvem) sai sem erro" ./scripts/sync-board.sh --auto
rm scripts/board.conf
check "--auto sem board.conf sai sem erro" ./scripts/sync-board.sh --auto
check "sem --auto e sem board.conf falha" bash -c '! ./scripts/sync-board.sh'
printf 'OWNER=acme\nPROJECT_NUMBER=7\n' > scripts/board.conf
# #10 todo com PR aberto, #11 todo com status:doing, #12 done (já no board), #13 review com status:doing.
cat > "$R" <<'MD'
## M0 Fundação

| Ordem | Issue | Título | Status | Spec | PR |
|---|---|---|---|---|---|
| 1 | #10 | [chore] Setup | todo | — | |

## M1 MVP

| Ordem | Issue | Título | Status | Spec | PR |
|---|---|---|---|---|---|
| 2 | #11 | [feat] Dois | todo | specs/a.md | |
| 3 | #12 | [feat] Três | done | specs/a.md | #14 |
| 4 | #13 | [feat] Quatro | review | specs/a.md | |
MD
echo '[{"number":11,"labels":[{"name":"status:doing"}],"state":"open"},{"number":13,"labels":[{"name":"status:doing"}],"state":"open"}]' > "$GH_STATE/issues.json"
echo '[{"number":15,"body":"Closes #10\n\n**Spec:** —"}]' > "$GH_STATE/pulls.json"
echo '{"items":[{"id":"PVTI_12","content":{"type":"Issue","repository":"acme/proj","number":12}}]}' > "$GH_STATE/items.json"
export GH_LOCAL=1
./scripts/sync-board.sh >/dev/null
etapa() { grep -q "item-edit --project-id PVT_1 --id PVTI_$1 --field-id F_ETAPA --single-select-option-id O_$2" "$GH_LOG"; }
check "PR aberto vira review" etapa 10 review
check "status:doing vira doing" etapa 11 doing
check "status:doing vence o status do roadmap" etapa 13 doing
check "done fica done" etapa 12 done
check "Ordem vem da coluna Ordem" grep -q 'id PVTI_13 --field-id F_ORDEM --number 4' "$GH_LOG"
check "só adiciona ao board o que não está lá" test "$(count 'project item-add')" = 3
check "sem GITHUB_REPOSITORY, usa o remote; só rotas do repo" only_repo_routes
: > "$GH_LOG"
GITHUB_REPOSITORY=acme/proj ./scripts/sync-board.sh --auto >/dev/null
check "--auto com acesso ao Projects sincroniza (fluxo local)" test "$(count 'project item-edit')" = 8

echo "workflow sync-board.yml"
RUN="$(yq -r '.jobs.sync.steps[1].run' .github/workflows/sync-board.yml)"
rm scripts/board.conf
o="$(GH_TOKEN=x bash -ec "$RUN")"
check "sem board.conf: verde, com aviso" grep -q '^::warning::Sem scripts/board.conf' <<<"$o"
printf 'OWNER=acme\nPROJECT_NUMBER=7\n' > scripts/board.conf
o="$(GH_TOKEN='' bash -ec "$RUN")"
check "sem PROJECT_TOKEN: verde, com aviso" grep -q '^::warning::Secret PROJECT_TOKEN' <<<"$o"
o="$(GH_TOKEN=x bash -ec "$RUN")"
check "com os dois: roda o sync" grep -q '^Board sincronizado' <<<"$o"

echo "docs"
cd "$SRC"
REVIEW="$(awk '/^## Ao pedir "revise o PR"/ { s = 1; next } /^## / { s = 0 } s' CLAUDE.md)"
check "CLAUDE.md tem a seção revise o PR (CA-C5)" test -n "$REVIEW"
check "review: todo comando gh é gh api repos/{owner}/{repo}/..." \
  bash -c '! grep -oE "gh [a-z]+ [^ \`]+" <<<"$0" | grep -vqF "gh api repos/{owner}/{repo}/"' "$REVIEW"
check "review: posta com event=COMMENT, nunca APPROVE" \
  bash -c 'grep -q "event=COMMENT" <<<"$0" && ! grep -q "event=APPROVE" <<<"$0"' "$REVIEW"
CHECKLIST="$(awk '/^## Checklist do projeto novo/ { s = 1; next } /^## / { s = 0 } s' README.md)"
check "README: checklist cita os checks obrigatórios e o open-pr.sh --update (CA-C6)" \
  bash -c 'grep -q "ci" <<<"$0" && grep -q "pr-gate" <<<"$0" && grep -qF "open-pr.sh --update" <<<"$0"' "$CHECKLIST"
check "README: seção Merge gate" grep -q '^## Merge gate' README.md
# Padrão montado em partes para este arquivo não casar com ele mesmo.
GRAPHQL_CMDS="gh (issue|pr) (create|edit|view)|gh repo"" view"
check "nenhum comando gh de GraphQL nos docs e scripts" \
  bash -c '! grep -rnE "$0" CLAUDE.md docs/ .claude/ scripts/ --exclude=bootstrap.sh' "$GRAPHQL_CMDS"
check "nenhuma referência à pasta antiga de tasks" bash -c '! grep -rn "docs/""tasks" . --exclude-dir=.git'

echo
echo "$pass ok, $fail falha(s)"
[ "$fail" = 0 ]
