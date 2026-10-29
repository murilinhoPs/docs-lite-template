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
: > "$GH_LOG"
./scripts/task-status.sh 3 doing >/dev/null
check "status doing no roadmap" test "$(rows | sed -n 2p)" = "2|#3|[feat] C|doing|specs/c.md|"
./scripts/task-status.sh 3 done >/dev/null
check "status done no roadmap" test "$(rows | sed -n 2p)" = "2|#3|[feat] C|done|specs/c.md|"
check "review não é status do roadmap" bash -c '! ./scripts/task-status.sh 3 review'
check "issue fora do roadmap falha" bash -c '! ./scripts/task-status.sh 77 doing'
check "status inválido falha" bash -c '! ./scripts/task-status.sh 3 feito'
check "sem label nem API: task-status não chama o GitHub" test "$(count '^API'):$(count '^gh project')" = "0:0"
printf 'OWNER=acme\nPROJECT_NUMBER=7\n' > scripts/board.conf
o="$(./scripts/task-status.sh 3 doing)"
check "sem acesso ao Projects (nuvem): avisa e segue" grep -qF "board não sincronizado; rode ./scripts/sync-board.sh localmente" <<<"$o"
check "sem acesso ao Projects, não mexe no board" test "$(count 'project item-edit')" = 0
GH_LOCAL=1 ./scripts/task-status.sh 3 doing >/dev/null
check "com acesso ao Projects (local), sincroniza" test "$(count 'project item-edit')" -gt 0
rm scripts/board.conf

echo "open-pr.sh"
setup pr
n="$(./scripts/new-issue.sh --title "[feat] Login" --body-file "$(body auth)" --milestone M1 --labels type:feature)"
git commit -qam "roadmap" && git push -q
git worktree add -q --orphan -b pr-assets "$WORK/assets" 2>/dev/null || { git switch -q --orphan pr-assets && git switch -q -; }
(cd "$WORK/assets" && git commit -q --allow-empty -m pr-assets && git push -q origin pr-assets)
# Prints em pr-assets/issue-<n>/<pasta>/ com "commit: <sha>". assets <pasta> <sha>
assets() { (cd "$WORK/assets" && mkdir -p "issue-$n/$1" && printf 'commit: %s\nac-f1-01.png  1x1  %064d\n' "$2" 0 > "issue-$n/$1/print_sizes.txt" \
  && git add -A && git commit -qm "prints $1" && git push -q origin pr-assets); }
git switch -qc "task/$n-login"
./scripts/task-status.sh "$n" doing >/dev/null
mkdir -p docs/specs && echo "# F1" > docs/specs/auth.md && echo app > app.txt
git add -A && git commit -qm "Login"
CODE_SHA="$(git rev-parse HEAD)"
./scripts/task-status.sh "$n" done >/dev/null
git commit -qam "Marca #$n como done no roadmap" && git push -qu origin "task/$n-login"
DONE_SHA="$(git rev-parse HEAD)"
echo "Tela de login." > "$GH_STATE/summary.md"
printf 'PASS login\n' > "$GH_STATE/tests.txt"
check "sem prints que valham e sem --prints falha antes de criar" \
  bash -c "! ./scripts/open-pr.sh $n --summary-file $GH_STATE/summary.md --tests-file $GH_STATE/tests.txt"
check "sem --tests nem --tests-file falha" bash -c "! ./scripts/open-pr.sh $n --summary-file $GH_STATE/summary.md --prints 'n/a: x'"
check "nenhum PR criado nos erros" test "$(count 'API POST repos/acme/proj/pulls$')" = 0
# /qa tirou os prints no commit de código; o commit do done veio depois (só docs).
assets "${CODE_SHA:0:7}" "$CODE_SHA"
url="$(./scripts/open-pr.sh "$n" --tests-file "$GH_STATE/tests.txt" < "$GH_STATE/summary.md")"
PR=$((n + 1))
FINAL_SHA="$(git rev-parse HEAD)"
check "imprime a URL do PR" test "$url" = "https://github.com/acme/proj/pull/$PR"
check "título da issue e branches" test "$(jq -c '.[0] | [.title, .head.ref, .base.ref]' "$GH_STATE/pulls.json")" \
  = "[\"[feat] Login\",\"task/$n-login\",\"main\"]"
pr_body="$(jq -r '.[0].body' "$GH_STATE/pulls.json")"
has_line() { grep -qxF -- "$1" <<<"$pr_body"; }
check "corpo: Closes" has_line "Closes #$n"
check "corpo: spec atualizada na branch" has_line "**Spec:** docs/specs/auth.md (atualizada)"
check "corpo: resumo" has_line "Tela de login."
check "corpo: AC da issue" test "$(grep -c '^- \[ \] AC-F1-0[12]' <<<"$pr_body")" = 2
check "corpo: saída dos testes + sha curto" test "$(has_line 'PASS login' && grep -c "git rev-parse --short HEAD\`: ${DONE_SHA:0:7}" <<<"$pr_body")" = 1
check "corpo: prints do commit de código (só docs depois)" grep -qF "pr-assets/issue-$n/${CODE_SHA:0:7}/" <<<"$pr_body"
check "corpo: Registro" test "$(has_line '- Testado por: usuário + Claude' && grep -c '^- Arquivos alterados: .*`app.txt`' <<<"$pr_body")" = 1
check "corpo: sem placeholders do template" bash -c '! grep -qE "<sha de 40|AC-\.\.\.|^pr-assets/issue-<N>|saída real" <<<"$0"' "$pr_body"
check "corpo: Tipo código" has_line "**Tipo:** código"
check "número do PR na coluna PR, com status done" test "$(rows)" = "1|#$n|[feat] Login|done|specs/auth.md|#$PR"
check "commit 'Registra PR' só no roadmap, com push" \
  test "$(git log -1 --format=%s):$(git diff --name-only HEAD~1 HEAD):$(git rev-list --count '@{u}..HEAD')" = "Registra PR #$PR no roadmap:docs/roadmap.md:0"
check "Head do corpo = head depois do commit do PR" has_line "**Head:** $FINAL_SHA"
url2="$(./scripts/open-pr.sh "$n" </dev/null)"
check "segunda execução não abre outro PR nem faz commit" \
  test "$url2:$(count 'API POST repos/acme/proj/pulls$'):$(git rev-parse HEAD)" = "$url:1:$FINAL_SHA"
check "só rotas repos/acme/proj e nada de GraphQL" no_graphql

echo "pr-gate.sh (CA-C1)"
# Evento pull_request montado a partir do PR simulado.
event() { gh api "repos/acme/proj/pulls/$PR" 2>/dev/null | jq '{pull_request: (. + {base: {ref: "main"}})}' > "$GH_STATE/event.json"; }
gate() { GITHUB_EVENT_PATH="$GH_STATE/event.json" ./scripts/pr-gate.sh; }
event
check "passa: prints do commit de código, depois só docs (done + Registra PR)" gate
o="$(gate 2>&1 || true)"
check "diz que os prints valem porque só mudou docs" grep -q "ok: prints de pr-assets/issue-$n/${CODE_SHA:0:7}/ (${CODE_SHA:0:7}) valem para o head" <<<"$o"
echo "detalhe" >> docs/specs/auth.md && git commit -qam "Ajusta spec" && git push -q
event
o="$(gate 2>&1 || true)"
check "falha com Head divergente depois de um push" grep -q "::error::Head do corpo desatualizado" <<<"$o"
check "a mensagem diz para rodar open-pr.sh --update" grep -qF "./scripts/open-pr.sh --update $PR" <<<"$o"
old_body="$(jq -r --argjson p "$PR" '.[] | select(.number == $p) | .body' "$GH_STATE/pulls.json")"
warn="$(./scripts/open-pr.sh --update "$PR" 2>&1 >/dev/null)"
new_body="$(jq -r --argjson p "$PR" '.[] | select(.number == $p) | .body' "$GH_STATE/pulls.json")"
check "--update reescreve o Head" grep -qxF "**Head:** $(git rev-parse HEAD)" <<<"$new_body"
check "--update não mexe no resto do corpo" test "$(diff <(echo "$old_body") <(echo "$new_body") | grep -c '^[<>]')" = 2
check "--update sem aviso quando só docs mudou" test -z "$warn"
check "--update usa PATCH em repos/acme/proj/pulls/N" grep -q "^API PATCH repos/acme/proj/pulls/$PR$" "$GH_LOG"
event
check "passa depois do --update (prints valem: só docs mudou)" gate
echo "mais código" >> app.txt && git commit -qam "Corrige login" && git push -q
NEW_SHA="$(git rev-parse HEAD)"
warn="$(./scripts/open-pr.sh --update "$PR" 2>&1 >/dev/null)"
check "--update avisa que os prints não valem depois de mudar código" grep -q "não vale para o head ${NEW_SHA:0:7}" <<<"$warn"
event
o="$(gate 2>&1 || true)"
check "falha com prints de antes de uma mudança de código" \
  grep -q "::error::Os prints de pr-assets/issue-$n/${CODE_SHA:0:7}/ são do commit ${CODE_SHA:0:7}, e o código mudou" <<<"$o"
assets "${NEW_SHA:0:7}" "$NEW_SHA"
./scripts/open-pr.sh --update "$PR" >/dev/null 2>&1
event
check "--update aponta para a pasta de prints nova" grep -qF "pr-assets/issue-$n/${NEW_SHA:0:7}/" <<<"$(jq -r '.pull_request.body' "$GH_STATE/event.json")"
check "passa com prints do head novo" gate
assets "abcdef0" "$NEW_SHA"
jq '.pull_request.body |= gsub("issue-[0-9]+/[0-9a-f]{7}/"; "issue-'"$n"'/abcdef0/")' "$GH_STATE/event.json" > "$GH_STATE/x" && mv "$GH_STATE/x" "$GH_STATE/event.json"
o="$(gate 2>&1 || true)"
check "falha com pasta que não bate com o commit do print_sizes.txt" grep -q "::error::A pasta pr-assets/issue-$n/abcdef0/ não bate com o commit ${NEW_SHA:0:7}" <<<"$o"
event
jq '.pull_request.body |= sub("\\*\\*Head:\\*\\*[^\n]*\n"; "")' "$GH_STATE/event.json" > "$GH_STATE/x" && mv "$GH_STATE/x" "$GH_STATE/event.json"
o="$(gate 2>&1 || true)"
check "falha sem a linha Head" grep -q "::error::O corpo do PR não tem a linha \*\*Head:\*\*" <<<"$o"
check "só rotas repos/acme/proj e nada de GraphQL" no_graphql

echo "merge.sh (D4)"
o="$(./scripts/merge.sh "$PR" "$NEW_SHA")"
check "merge squash travado no head, por REST" \
  grep -qF "BODY PUT repos/acme/proj/pulls/$PR/merge {\"merge_method\":\"squash\",\"sha\":\"$NEW_SHA\"}" "$GH_LOG"
check "imprime o resultado" grep -q "Pull Request successfully merged" <<<"$o"
check "head mudou depois da conferência: o merge é recusado" bash -c "! ./scripts/merge.sh $PR $DONE_SHA"
check "sha curto é recusado antes de chamar a API" bash -c "! ./scripts/merge.sh $PR ${NEW_SHA:0:7}"
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

echo "sync-board.sh (D3)"
setup sync
printf 'OWNER=acme\nPROJECT_NUMBER=7\n' > scripts/board.conf
o="$(./scripts/sync-board.sh --auto)"
check "--auto sem acesso ao Projects (nuvem): avisa e sai sem erro" grep -qF "board não sincronizado; rode ./scripts/sync-board.sh localmente" <<<"$o"
rm scripts/board.conf
check "--auto sem board.conf sai sem erro" ./scripts/sync-board.sh --auto
check "sem --auto e sem board.conf falha" bash -c '! ./scripts/sync-board.sh'
printf 'OWNER=acme\nPROJECT_NUMBER=7\n' > scripts/board.conf
cat > "$R" <<'MD'
## M0 Fundação

| Ordem | Issue | Título | Status | Spec | PR |
|---|---|---|---|---|---|
| 1 | #10 | [chore] Setup | todo | — | |
| 2 | #11 | [feat] Dois | doing | specs/a.md | |

## M1 MVP

| Ordem | Issue | Título | Status | Spec | PR |
|---|---|---|---|---|---|
| 3 | #12 | [feat] Três | done | specs/a.md | #20 |
| 4 | #13 | [feat] Quatro | done | specs/a.md | |
| 5 | #14 | [feat] Cinco | todo | specs/a.md | |
| 6 | #15 | [feat] Seis | todo | specs/a.md | |
| 7 | #16 | [feat] Sete | doing | specs/a.md | |
MD
# #12 e #15 fechadas; PRs abertos fecham #10 e #16.
jq -n '[10,11,12,13,14,15,16] | map({number: ., state: (if . == 12 or . == 15 then "closed" else "open" end), labels: []})' > "$GH_STATE/issues.json"
echo '[{"number":21,"body":"Closes #10\n\n**Spec:** —"},{"number":22,"body":"fixes #16"}]' > "$GH_STATE/pulls.json"
echo '{"items":[{"id":"PVTI_12","content":{"type":"Issue","repository":"acme/proj","number":12}}]}' > "$GH_STATE/items.json"
export GH_LOCAL=1
./scripts/sync-board.sh >/dev/null
etapa() { grep -q "item-edit --project-id PVT_1 --id PVTI_$1 --field-id F_ETAPA --single-select-option-id O_$2" "$GH_LOG"; }
check "1. issue fechada → done" etapa 12 done
check "1. issue fechada vence o status do roadmap (todo)" etapa 15 done
check "2. PR aberto que fecha a issue → review" etapa 10 review
check "2. PR aberto vence o doing do roadmap" etapa 16 review
check "3. roadmap doing sem PR → doing" etapa 11 doing
check "3. roadmap done sem PR (PR ainda não aberto) → doing" etapa 13 doing
check "4. senão → todo" etapa 14 todo
check "Ordem vem da coluna Ordem" grep -q 'id PVTI_16 --field-id F_ORDEM --number 7' "$GH_LOG"
check "só adiciona ao board o que não está lá" test "$(count 'project item-add')" = 6
check "sem label: nenhuma rota de labels" bash -c '! grep -q "labels" "$0"' "$GH_LOG"
check "sem GITHUB_REPOSITORY, usa o remote; só rotas do repo" only_repo_routes
: > "$GH_LOG"
GITHUB_REPOSITORY=acme/proj ./scripts/sync-board.sh --auto >/dev/null
check "--auto com acesso ao Projects sincroniza (fluxo local, CA-8)" test "$(count 'project item-edit')" = 14
export GH_LOCAL=0

echo "docs"
cd "$SRC"
REVIEW="$(cat .claude/agents/revisor.md .claude/commands/revisar.md)"
check "review: subagente revisor e comando /revisar (CA-C5)" test -n "$REVIEW"
check "review: todo comando gh é gh api repos/{owner}/{repo}/..." \
  bash -c '! grep -oE "gh [a-z]+ [^ \`]+" <<<"$0" | grep -vqE "gh api \"?repos/\{owner\}/\{repo\}/"' "$REVIEW"
check "review: posta com -f event=COMMENT, nunca APPROVE nem REQUEST_CHANGES" \
  bash -c 'grep -q -- "-f event=COMMENT" <<<"$0" && ! grep -qE -- "-f event=(APPROVE|REQUEST_CHANGES)" <<<"$0"' "$REVIEW"
CHECKLIST="$(awk '/^## Checklist do projeto novo/ { s = 1; next } /^## / { s = 0 } s' README.md)"
check "README: checklist cita os checks obrigatórios e o open-pr.sh --update (CA-C6)" \
  bash -c 'grep -q "ci" <<<"$0" && grep -q "pr-gate" <<<"$0" && grep -qF "open-pr.sh --update" <<<"$0"' "$CHECKLIST"
check "README: seção Merge gate" grep -q '^## Merge gate' README.md
for c in preparar planejar implementar qa abrir-pr revisar corrigir fechar; do
  f=".claude/commands/$c.md"
  check "comando /$c com papel, argumentos, passos, onde parar e nunca (CA-D1)" \
    bash -c 'for h in Papel Argumentos Passos "Onde parar" Nunca; do grep -qx "## $h" "$0" || exit 1; done' "$f"
done
check "subagente revisor existe, sem Edit nem Write (CA-D2)" \
  bash -c 'tools="$(sed -n "s/^tools:[[:space:]]*//p" .claude/agents/revisor.md)"; [ -n "$tools" ] && ! grep -qE "Edit|Write" <<<"$tools"'
check "revisor proíbe --approve e --request-changes e usa event=COMMENT" \
  bash -c 'grep -q -- "--approve" .claude/agents/revisor.md && grep -q -- "--request-changes" .claude/agents/revisor.md && grep -q "event=COMMENT" .claude/agents/revisor.md'
check "/revisar delega ao subagente revisor" grep -q 'subagente `revisor`' .claude/commands/revisar.md
# Padrões montados em partes para este arquivo não casar com ele mesmo.
check "nada cita a label, o token nem o workflow de sync removidos (CA-D4)" \
  bash -c '! grep -rnE "$0" --exclude-dir=.git .' "status"":doing|PROJECT""_TOKEN|sync-board""\.yml"
check "roadmap só com todo, doing e done (CA-D4)" \
  bash -c 'grep -q "^Status: \`todo\` · \`doing\` · \`done\`" docs/roadmap.md && ! grep -qE "\| (review) \|" docs/roadmap.md'
check "AGENTS.md é link simbólico para o CLAUDE.md (CA-D6)" test "$(readlink AGENTS.md)" = CLAUDE.md
P=docs/preparo.md
check "preparo.md: frontmatter updated e fase (CA-E1)" \
  bash -c 'sed -n "1,4p" "$0" | grep -q "^updated: " && sed -n "1,4p" "$0" | grep -qE "^fase: (inventario|entrevista|pronto)"' "$P"
check "preparo.md: colunas do checklist" \
  grep -qxF '| # | Item | Nível | Status | Evidência (arquivo §seção) | Destino | Em aberto |' "$P"
check "preparo.md: 15 itens, 8 trava e 7 ajuda" \
  test "$(grep -cE '^\| [0-9]+ \|' "$P"):$(grep -cE '^\| [0-9]+ \|[^|]*\| trava \|' "$P"):$(grep -cE '^\| [0-9]+ \|[^|]*\| ajuda \|' "$P")" = "15:8:7"
check "preparo.md: seção Registro da entrevista" grep -qx '## Registro da entrevista' "$P"
C=.claude/commands/preparar.md
check "/preparar com as 4 fases (CA-E2)" \
  bash -c 'for f in "Fase 1: inventário" "Fase 2: relatório" "Fase 3: entrevista" "Fase 4: pronto"; do grep -q "^### $f" "$0" || exit 1; done' "$C"
check "/preparar para antes de organizar e entre rodadas" \
  bash -c 'grep -q "posso organizar os arquivos e começar a entrevista?" "$0" && grep -q "mais uma rodada ou paramos aqui?" "$0"' "$C"
check "/preparar: nunca inventar, criar issues, organizar antes do ok ou passar de 4 perguntas" \
  bash -c 'n="$(awk "/^## Nunca/ { s = 1; next } /^## / { s = 0 } s" "$0")"; grep -q "Inventar" <<<"$n" && grep -q "Criar issues" <<<"$n" && grep -q "antes do \"pode seguir\"" <<<"$n" && grep -q "mais de 4 perguntas" <<<"$n"' "$C"
check "/preparar é retomável: fase entrevista pula para a Fase 3 e só pergunta falta/parcial (CA-E4)" \
  bash -c 'grep -q "Se a \`fase\` for \`entrevista\`, pule para a \*\*Fase 3\*\*" "$0" && grep -q "pergunte só o que está \`falta\` ou \`parcial\`" "$0"' "$C"
check "/preparar traz o mapa material → destino e as regras de importação" \
  bash -c 'grep -q "^## Mapa: material → destino" "$0" && grep -q "^## Regras de importação" "$0"' "$C"
check "skill de importação removida, ninguém cita (CA-E3)" \
  bash -c 'test ! -e .claude/skills/importar"-docs" && ! grep -rqn "importar""-docs" --exclude-dir=.git .'
check "\"importe meus docs\" leva ao /preparar" grep -q '`/preparar \[pasta\]` | "importe meus docs"' CLAUDE.md
check "mesmo fluxo /preparar → /planejar → ciclo (CA-E5)" \
  bash -c 'for f in CLAUDE.md README.md .claude/commands/preparar.md; do grep -q "/preparar\` (até nada travar) → \`/planejar\` → ciclo" "$f" || grep -q "/preparar (até nada travar) → /planejar → ciclo" "$f" || { echo "$f"; exit 1; }; done; grep -q "/planejar M1" docs/prompts/setup-a-partir-de-docs.md && grep -q "fase: pronto" docs/prompts/setup-a-partir-de-docs.md'
check "/preparar primeiro na tabela de comandos do CLAUDE.md e do README" \
  bash -c 'for f in CLAUDE.md README.md; do grep -m1 -E "^\| .*\`/[a-z-]+" "$f" | grep -q "/preparar" || exit 1; done'
check "/planejar manda rodar /preparar antes" grep -q "sugira \`/preparar\`" .claude/commands/planejar.md
check "comandos e CLAUDE.md citam merge.sh travado no head" \
  bash -c 'grep -q "merge.sh <pr> <head>" CLAUDE.md && grep -q "merge.sh <pr> <head>" .claude/commands/abrir-pr.md && grep -q "merge.sh <pr> <head>" .claude/commands/corrigir.md'
# Padrão montado em partes para este arquivo não casar com ele mesmo.
GRAPHQL_CMDS="gh (issue|pr) (create|edit|view)|gh repo"" view"
check "nenhum comando gh de GraphQL nos docs e scripts" \
  bash -c '! grep -rnE "$0" CLAUDE.md docs/ .claude/ scripts/ --exclude=bootstrap.sh' "$GRAPHQL_CMDS"
check "nenhuma referência à pasta antiga de tasks" bash -c '! grep -rn "docs/""tasks" . --exclude-dir=.git'

echo
echo "$pass ok, $fail falha(s)"
[ "$fail" = 0 ]
