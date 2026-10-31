#!/usr/bin/env bash
# Testes dos scripts com gh simulado (scripts/test/bin/gh).
# Cada teste roda numa cópia do repo, com origin https://github.com/acme/proj
# e um repo bare local no lugar do GitHub para o push.
#
# Uso: ./scripts/test/run.sh
set -euo pipefail

# shellcheck source=scripts/test/helpers.sh
source "$(dirname "$0")/helpers.sh"

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
a="$(./scripts/new-issue.sh --title "[feat] A" --body-file "$(body a)" --milestone "M1 — MVP" --labels "type:feature, area:x")"
b="$(./scripts/new-issue.sh --title "[chore] B" --body-file "$(body b)" --milestone M0 --labels type:chore)"
c="$(./scripts/new-issue.sh --title "[feat] C" --body-file "$(body c)" --milestone "M1 — MVP" --labels type:feature --after "$b")"
d="$(./scripts/new-issue.sh --title "[feat] D | E" --body-file "$(body d)" --milestone "M1 — MVP" --labels type:feature)"
check "imprime os números" test "$a $b $c $d" = "1 2 3 4"
check "título, milestone e labels" test "$(jq -c '.[0] | [.title, .milestone.title, [.labels[].name]]' "$GH_STATE/issues.json")" \
  = '["[feat] A","M1 — MVP",["type:feature","area:x"]]'
check "corpo da issue = --body-file" test "$(jq -r '.[0].body' "$GH_STATE/issues.json")" = "$(cat "$GH_STATE/a.md")"
check "fim do milestone e --after, com Ordem renumerada" test "$(rows | paste -sd ' ')" \
  = "1|#2|[chore] B|todo|specs/b.md| 2|#3|[feat] C|todo|specs/c.md| 3|#1|[feat] A|todo|specs/a.md| 4|#4|[feat] D / E|todo|specs/d.md|"
check "--after de outro milestone entra logo depois dele (seção M0)" test "$(section 'M0 — Fundação e spike' | cut -d'|' -f2 | paste -sd ' ')" = "#2 #3"
jq '. += [{"number":9,"title":"[bug] Quebrou","body":"**Spec:** docs/specs/a.md  (F1)\r\n","milestone":{"number":4,"title":"M1 — MVP"},"labels":[{"name":"type:bug"}],"state":"open"}]' \
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

echo "new-milestone.sh (CA-G5)"
: > "$GH_LOG"
m1="$(./scripts/new-milestone.sh "M1 — MVP")"
m2a="$(./scripts/new-milestone.sh "M2 — Pagamentos")"
m2b="$(./scripts/new-milestone.sh "M2 — Pagamentos")"
check "milestone que já existe: só imprime o número, sem criar" test "$m1" = 4
check "milestone novo: cria e imprime o número" test "$m2a" = 5
check "idempotente: rodar de novo não cria outro" test "$m2b:$(count '^API POST repos/acme/proj/milestones$')" = "5:1"
jq 'map(if .number == 5 then .state = "closed" else . end)' "$GH_STATE/milestones.json" > "$GH_STATE/x" && mv "$GH_STATE/x" "$GH_STATE/milestones.json"
check "acha também milestone fechado (state=all)" test "$(./scripts/new-milestone.sh "M2 — Pagamentos"):$(count '^API POST repos/acme/proj/milestones$')" = "5:1"
check "título fora do formato \"M<n> — <nome>\" falha" bash -c '! ./scripts/new-milestone.sh "M3 Sem travessão"'
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

echo "bootstrap.sh (CA-C2, CA-G5)"
setup boot
export GH_LOCAL=1
echo '[]' > "$GH_STATE/milestones.json"
sed -i 's/| F1 | <nome> | Must | \[specs\/<feature>.md\](specs\/<feature>.md) | area:<x> |/| F1 | Login | Must | x | area:auth |/' docs/prd.md
./scripts/bootstrap.sh >"$GH_STATE/boot.out" 2>&1 || { ko "bootstrap terminou com erro"; sed "s/^/    /" "$GH_STATE/boot.out"; }
check "copia o projeto modelo murilinhoPs/2" grep -q '^gh project copy 2 --source-owner murilinhoPs' "$GH_LOG"
check "cria só o milestone M0 (CA-G5)" \
  test "$(grep -c '^API POST repos/acme/proj/milestones$' "$GH_LOG"):$(jq -c '[.[].title]' "$GH_STATE/milestones.json")" = '1:["M0 — Fundação e spike"]'
check "issue de setup no M0, na seção Issues por milestone (CA-G1)" \
  test "$(jq -r '.[0].milestone.title' "$GH_STATE/issues.json"):$(section 'M0 — Fundação e spike')" = "M0 — Fundação e spike:1|#1|[chore] Setup do projeto|todo|—|"
check "roadmap gerado mantém a seção Milestones intacta" \
  bash -c 'test "$(sed -n "/^## Milestones/,/^## Issues/p" "$0")" = "$(sed -n "/^## Milestones/,/^## Issues/p" "$1")"' "$R" "$SRC/docs/roadmap.md"
check "squash com título e corpo do PR" \
  grep -qF 'BODY PATCH repos/acme/proj {"squash_merge_commit_title":"PR_TITLE","squash_merge_commit_message":"PR_BODY"}' "$GH_LOG"
check "ruleset com ci e pr-gate obrigatórios, strict" test "$(jq -c '.[0].rules[] | select(.type == "required_status_checks") | .parameters | [.strict_required_status_checks_policy, [.required_status_checks[].context]]' "$GH_STATE/rulesets.json")" \
  = '[true,["ci","pr-gate"]]'
check "cria type:design e as area:* da tabela Features" \
  test "$(grep -c '^gh label create type:design\|^gh label create area:auth' "$GH_LOG")" = 2
check "cria a issue de setup com o AC do ci.yml" grep -q 'AC-SETUP-03: `.github/workflows/ci.yml` roda lint e testes da stack' <<<"$(jq -r '.[0].body' "$GH_STATE/issues.json")"
rm -f scripts/board.conf
./scripts/bootstrap.sh >"$GH_STATE/boot2.out" 2>&1
check "rodar de novo não cria outro M0 nem outra issue de setup" \
  test "$(jq length "$GH_STATE/milestones.json"):$(jq length "$GH_STATE/issues.json")" = "1:1"
check "rodar de novo atualiza o ruleset (PUT), sem criar outro" \
  test "$(count '^API PUT repos/acme/proj/rulesets/51$'):$(count '^API POST repos/acme/proj/rulesets$'):$(jq length "$GH_STATE/rulesets.json")" = "1:1:1"
rm -f scripts/board.conf
GH_COPY_FAILS=1 ./scripts/bootstrap.sh >"$GH_STATE/boot3.out" 2>&1
check "sem o modelo, cria o board vazio" grep -q '^gh project create' "$GH_LOG"
check "gh api só com rotas repos/acme/proj (gh label/repo/project são locais)" \
  bash -c '! grep "^API " "$0" | grep -qv "^API [A-Z]* repos/acme/proj\(/\|$\)"' "$GH_LOG"

echo "bootstrap.sh: campos do board copiado (CA-F1)"
# Roda o bootstrap com o modelo copiado tendo os campos de fields.json. boot_fields <json>
boot_fields() {
  rm -f scripts/board.conf
  echo "$1" > "$GH_STATE/fields.json"
  : > "$GH_LOG"
  ./scripts/bootstrap.sh >"$GH_STATE/boot.out" 2>&1 || { ko "bootstrap terminou com erro"; sed "s/^/    /" "$GH_STATE/boot.out"; }
}
ETAPA='{"id":"F_ETAPA","name":"Etapa","options":[{"id":"O_todo","name":"todo"},{"id":"O_doing","name":"doing"},{"id":"O_review","name":"review"},{"id":"O_done","name":"done"}]}'
ORDEM='{"id":"F_ORDEM","name":"Ordem"}'
boot_fields "{\"fields\":[$ETAPA,$ORDEM]}"
check "modelo completo: não cria campo nem avisa" \
  test "$(count 'project field-create'):$(grep -c 'aviso: .*\(Etapa\|Ordem\)' "$GH_STATE/boot.out")" = "0:0"
boot_fields "{\"fields\":[$ETAPA]}"
check "sem Ordem: cria Ordem (number)" grep -q '^gh project field-create 8 --owner acme --name Ordem --data-type NUMBER' "$GH_LOG"
check "sem Ordem: avisa e não mexe na Etapa" \
  test "$(grep -c 'não tinha o campo Ordem; criei' "$GH_STATE/boot.out"):$(count 'field-create 8 --owner acme --name Etapa')" = "1:0"
boot_fields "{\"fields\":[$ORDEM]}"
check "sem Etapa: cria Etapa com todo, doing, review, done" \
  grep -q '^gh project field-create 8 --owner acme --name Etapa --data-type SINGLE_SELECT --single-select-options todo,doing,review,done' "$GH_LOG"
check "sem Etapa: avisa das visões que dependem dela" grep -q 'Ajuste na interface as visões que dependem dela' "$GH_STATE/boot.out"
boot_fields '{"fields":[{"id":"F_ETAPA","name":"Etapa","options":[{"id":"a","name":"todo"},{"id":"b","name":"feito"}]},'"$ORDEM"']}'
check "Etapa com opções diferentes: só avisa quais faltam" \
  grep -q 'a Etapa do modelo não tem as opções: doing, review, done. Não alterei' "$GH_STATE/boot.out"
check "Etapa com opções diferentes: não cria nem altera campo" test "$(count 'project field-create')" = 0
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
---
updated: 2026-01-01
---

# Roadmap

## Milestones

### M0 — Fundação e spike
- **Escopo:** F1 | F2, riscos #3 e #4
- **Critério de saída:** go/no-go
| 9 | #99 | prosa com cara de linha | todo | | |

| Ordem | Issue | Título | Status | Spec | PR |
|---|---|---|---|---|---|
| 8 | #98 | tabela fora da seção de issues | doing | | |

### M1 — MVP
- **Objetivo:** F3 | F4 (#5)

## Issues por milestone

### M0 — Fundação e spike

| Ordem | Issue | Título | Status | Spec | PR |
|---|---|---|---|---|---|
| 1 | #10 | [chore] Setup | todo | — | |
| 2 | #11 | [feat] Dois | doing | specs/a.md | |

| Risco | Nota |
|---|---|
| #97 | tabela sem o cabeçalho Ordem/Issue |

### M1 — MVP

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
check "ignora a seção Milestones e tabelas sem Ordem/Issue, mesmo com | e # (CA-G1)" \
  bash -c '! grep -qE "PVTI_9[789]|issues/9[789]" "$0"' "$GH_LOG"
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
check "README: modelo acessível e o que a cópia traz e não traz (CA-F2)" \
  bash -c 'm="$(awk "/^### Projeto modelo/ { s = 1; next } /^##/ { s = 0 } s" README.md)"; grep -q "Visibility" <<<"$m" && grep -q "BOARD_TEMPLATE=<owner>/<número>" <<<"$m" && grep -q "| A cópia traz | A cópia não traz |" <<<"$m" && grep -q "link" <<<"$m" && grep -q "auto-add" <<<"$m"'
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
  bash -c 'grep -q "^Status das issues: \`todo\` · \`doing\` · \`done\`" docs/roadmap.md && ! grep -qE "\| (review) \|" docs/roadmap.md'
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
FLOW='`/preparar` → merge → `/planejar` (visão geral) → merge → `/planejar M0`'
check "mesmo fluxo /preparar → /planejar → /planejar M0 → ciclo em todos os docs (CA-E5, CA-G8)" \
  bash -c 'for f in CLAUDE.md README.md docs/README.md .claude/commands/preparar.md docs/prompts/setup-a-partir-de-docs.md; do grep -qF "$0" "$f" || { echo "$f"; exit 1; }; done; grep -q "fase: pronto" docs/prompts/setup-a-partir-de-docs.md' "$FLOW"
check "fluxo completo: /fechar com go/no-go e /planejar M1 depois (CA-G8)" \
  bash -c 'for f in CLAUDE.md README.md docs/README.md .claude/commands/preparar.md docs/prompts/setup-a-partir-de-docs.md; do tr "\n" " " < "$f" | grep -qF "\`/fechar\` (go/no-go) → \`/planejar M1\`" || { echo "$f"; exit 1; }; done'
check "/preparar primeiro na tabela de comandos do CLAUDE.md e do README" \
  bash -c 'for f in CLAUDE.md README.md; do grep -m1 -E "^\| .*\`/[a-z-]+" "$f" | grep -q "/preparar" || exit 1; done'
check "/planejar exige o preparo pronto" grep -q "\`docs/preparo.md\` com \`fase: pronto\`" .claude/commands/planejar.md
RM=docs/roadmap.md
check "roadmap: duas seções, Milestones e Issues por milestone, com o M0 (CA-G1)" \
  bash -c 'grep -qx "## Milestones" "$0" && grep -qx "## Issues por milestone" "$0" && test "$(grep -cx "### M0 — Fundação e spike" "$0")" = 2 && grep -q "^updated: " "$0"' "$RM"
check "roadmap: campos do milestone (objetivo, escopo, critério de saída, depende de, tamanho)" \
  bash -c 'for c in Objetivo Escopo "Critério de saída" "Depende de / decisões abertas" Tamanho; do grep -q "^- \*\*$c:\*\*" "$0" || exit 1; done' "$RM"
check "prd.md sem tabela de milestones, apontando para o roadmap (CA-G2)" \
  bash -c '! grep -q "^| Milestone |" docs/prd.md && grep -q "Milestones e ordem de entrega: ver \[docs/roadmap.md\]" docs/prd.md'
check "ninguém manda pôr milestone no prd.md nem no bootstrap.sh (CA-G2)" \
  bash -c '! grep -rn "$0" --exclude-dir=.git .' "tabela do ""prd\|lista do .*boot""strap"
PL=.claude/commands/planejar.md
check "/planejar com os dois modos (CA-G3)" \
  bash -c 'grep -q "^### Modo 1: \`/planejar\` → visão geral" "$0" && grep -q "^### Modo 2: \`/planejar M<n>\` → um milestone" "$0"' "$PL"
check "/planejar: o modo 1 não cria issue, milestone nem spec" grep -q "No Modo 1: criar issue, milestone no GitHub ou spec" "$PL"
check "/planejar: o modo 2 recusa milestone cujo anterior não encerrou" grep -q "só planejo o milestone que for o próximo" "$PL"
check "/planejar: os dois modos param antes de criar" test "$(grep -c "\*\*pare\*\* até o \"pode seguir\"" "$PL")" = 2
check "/planejar: issues com new-issue.sh, milestone com new-milestone.sh, termina com o sync (CA-G6)" \
  bash -c 'grep -q "./scripts/new-issue.sh --title" "$0" && grep -q "./scripts/new-milestone.sh \"M<n> — <nome>\"" "$0" && grep -q "./scripts/sync-board.sh --auto" "$0" && grep -q "Mexer no board à mão" "$0"' "$PL"
check "template do doc de milestone (CA-G4)" \
  bash -c 'f=docs/milestones/_template.md; for k in "milestone: M<n> — <nome>" "status: planejado" "updated: "; do grep -q "^$k" "$f" || exit 1; done; for h in "Escopo final" "Fora de escopo" "Questões em aberto" "Critérios de aceite por feature" "Critério de saída testável" "Riscos" "Ordem sugerida"; do grep -qx "## $h" "$f" || exit 1; done'
check "Como verificar no molde e no form de issue de feature" \
  bash -c 'grep -qx "## Como verificar" docs/prompts/issue-feature.md && grep -q "label: Como verificar" .github/ISSUE_TEMPLATE/feature.yml'
check "/fechar: critério de saída, fecha o milestone e guarda o encerramento e o go/no-go nele (CA-G7)" \
  bash -c 'f=.claude/commands/fechar.md; grep -q "critério de saída" "$f" && grep -q "milestones/<ms> -f state=closed -F description=@" "$f" && grep -q "go/no-go: go | no-go" "$f" && ! grep -q "Encerrar M" "$f"'
check "/planejar M<n+1> registra o encerramento no PR dele: doc encerrado e ADR do go/no-go" \
  bash -c 'f=.claude/commands/planejar.md; grep -q "Critério de saída: confirmado" "$f" && grep -q "go/no-go: go" "$f" && grep -q "status: encerrado" "$f" && grep -q "ADR \`Aceita\`" "$f"'
check "CLAUDE.md lista o new-milestone.sh" grep -q '| Criar um milestone (etapa 2) | `./scripts/new-milestone.sh "M<n> — <nome>"` |' CLAUDE.md
check "comandos e CLAUDE.md citam merge.sh travado no head" \
  bash -c 'grep -q "merge.sh <pr> <head>" CLAUDE.md && grep -q "merge.sh <pr> <head>" .claude/commands/abrir-pr.md && grep -q "merge.sh <pr> <head>" .claude/commands/corrigir.md'
# Padrão montado em partes para este arquivo não casar com ele mesmo.
GRAPHQL_CMDS="gh (issue|pr) (create|edit|view)|gh repo"" view"
check "nenhum comando gh de GraphQL nos docs e scripts" \
  bash -c '! grep -rnE "$0" CLAUDE.md docs/ .claude/ scripts/ --exclude=bootstrap.sh' "$GRAPHQL_CMDS"
check "nenhuma referência à pasta antiga de tasks" bash -c '! grep -rn "docs/""tasks" . --exclude-dir=.git'

echo "consistência (CA-H1, CA-H2)"
cd "$SRC"
check "todo ./scripts/X citado no CLAUDE.md, READMEs e comandos existe e é executável" \
  bash -c 'for f in $(grep -rhoE "\./scripts/[a-z/-]+\.sh" CLAUDE.md README.md docs .claude | sort -u); do [ -x "$f" ] || { echo "$f"; exit 1; }; done'
check "todo script de scripts/ está na tabela do CLAUDE.md (menos lib.sh e helpers)" \
  bash -c 'for f in scripts/*.sh scripts/test/run.sh; do [ "$f" = scripts/lib.sh ] && continue; grep -E "^\|" CLAUDE.md | grep -qF "./$f" || { echo "$f"; exit 1; }; done'
check "os 8 comandos citados existem em .claude/commands, e o revisor em .claude/agents" \
  bash -c 'for c in preparar planejar implementar qa abrir-pr revisar corrigir fechar; do [ -f ".claude/commands/$c.md" ] && grep -q "/$c" CLAUDE.md || { echo "$c"; exit 1; }; done; [ -f .claude/agents/revisor.md ] && test "$(ls .claude/commands | wc -l)" = 8'
check "frases-atalho apontam para os comandos certos" \
  bash -c 'grep -qE "^\| .*\`/preparar.*\"importe meus docs\"" CLAUDE.md && grep -qE "^\| .*\`/implementar.*\"próxima task\"" CLAUDE.md && grep -qE "^\| .*\`/abrir-pr.*\"pode abrir o PR\"" CLAUDE.md && grep -qE "^\| .*\`/revisar.*\"revise o PR\"" CLAUDE.md'
check "AGENTS.md é link para o CLAUDE.md num clone novo" \
  bash -c 'git clone -q "$0" "$1/clone" && cd "$1/clone" && test -L AGENTS.md && test "$(readlink AGENTS.md)" = CLAUDE.md && cmp -s AGENTS.md CLAUDE.md' "$SRC" "$WORK"
check "placeholders no mesmo estilo (<N>, <pr>, <head>, <sha7>, M<n>, <ms>)" \
  bash -c '! grep -rnE "#<issue>|--after <issue>|(^|[^N])NNN-<|milestones/<n>|<sha>[^7]" CLAUDE.md README.md docs .claude .github scripts/*.sh'
check "bash -n em todos os scripts" bash -c 'for f in scripts/*.sh scripts/test/*.sh scripts/test/bin/gh; do bash -n "$f" || exit 1; done'
check "workflows e issue forms são YAML válido (CA-4)" \
  python3 -c 'import sys, yaml; [yaml.safe_load(open(f)) for f in sys.argv[1:]]' .github/workflows/*.yml .github/ISSUE_TEMPLATE/*.yml
check "templates da Parte A: spec, índice de ADR, Features no PRD, PR template (CA-6)" \
  bash -c 'grep -qx "## Critérios de aceite vigentes" docs/specs/_template.md && grep -q "^feature: F<n>" docs/specs/_template.md && grep -q "^| .Proposta. |" docs/adr/README.md && grep -q "^| ID | Feature | Prioridade | Spec | Área |" docs/prd.md && grep -q "^\*\*Head:\*\*" .github/pull_request_template.md && grep -qx "## Registro" .github/pull_request_template.md'
check "nenhum arquivo solto na raiz (CA-H5)" \
  bash -c 'test "$(git ls-files | grep -v / | sort | paste -sd " ")" = ".gitignore AGENTS.md CLAUDE.md README.md"'

echo "fumaça ponta a ponta (CA-H3)"
if "$SRC/scripts/test/smoke.sh" > "$WORK/smoke.out" 2>&1; then
  ok "$(tail -1 "$WORK/smoke.out")"
else
  ko "fumaça"; sed 's/^/    /' "$WORK/smoke.out"
fi

echo
echo "$pass ok, $fail falha(s)"
[ "$fail" = 0 ]
