#!/usr/bin/env bash
# Testes dos scripts com gh simulado (scripts/tests/bin/gh).
# Cada teste roda numa cópia do repo, com origin https://github.com/acme/proj
# e um repo bare local no lugar do GitHub para o push.
#
# Uso: ./scripts/tests/run.sh
set -euo pipefail

SRC="$(git rev-parse --show-toplevel)"
STUB="$SRC/scripts/tests/bin"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export GH_REPO=acme/proj
unset GITHUB_REPOSITORY

pass=0
fail=0
ok() { echo "  ok   $1"; pass=$((pass + 1)); }
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
  git add -A && git commit -qm init && git push -q -u origin main

  export GH_STATE="$dir/state" GH_LOG="$dir/state/gh.log" GH_PROJECTS=0
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
T=docs/tasks/001-setup-projeto.md
count() { grep -c -- "$1" "$GH_LOG" || true; }
# Toda chamada à API usa só rotas do repo, e nenhum comando GraphQL foi usado
# (gh project só no sync local).
only_repo_routes() {
  ! grep '^API ' "$GH_LOG" | grep -v "^API [A-Z]* repos/acme/proj/" -q &&
    ! grep -E '^gh (issue|pr|repo|label) ' "$GH_LOG" -q
}
no_graphql() { only_repo_routes && ! grep -q '^gh project ' "$GH_LOG"; }

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
  exit "$fail"
) || fail=$((fail + 1))

echo "create-issue.sh"
setup create
n1="$(./scripts/create-issue.sh "$T")"
n2="$(./scripts/create-issue.sh "$T")"
check "cria a issue #1" test "$n1" = 1
check "segunda execução não cria outra (CA-2)" test "$n2:$(count 'API POST repos/acme/proj/issues$')" = 1:1
check "título, corpo, milestone e labels" test "$(jq -c '.[0] | [.title, .body, .milestone, [.labels[].name]]' "$GH_STATE/issues.json")" \
  = '["001 · Setup do projeto","Spec: docs/tasks/001-setup-projeto.md",3,["type:chore"]]'
check "frontmatter issue: \"#1\"" grep -qx 'issue: "#1"' "$T"
check "coluna Issue do roadmap" grep -qF '| 001 | [Setup do projeto](tasks/001-setup-projeto.md) | todo | #1 | |' docs/roadmap.md
git checkout -q -- "$T" docs/roadmap.md
n3="$(./scripts/create-issue.sh "$T")"
check "sem o número no arquivo, reaproveita a issue pelo título" test "$n3:$(count 'API POST repos/acme/proj/issues$')" = 1:1
check "só rotas repos/acme/proj e nada de GraphQL (CA-4)" no_graphql

echo "set-status.sh"
./scripts/set-status.sh "$T" doing >/dev/null
check "frontmatter e roadmap em doing" test "$(grep -c '^status: doing' "$T"):$(grep -c '| doing | #1 |' docs/roadmap.md)" = 1:1
cp docs/tasks/_template.md "$GH_STATE/t.md"
(source scripts/lib.sh && fm_set "$GH_STATE/t.md" status doing)
check "fm_set mantém o comentário da linha" grep -q '^status: doing  *# todo | doing' "$GH_STATE/t.md"
check "label status:doing na issue" test "$(jq -c '[.[0].labels[].name] | sort' "$GH_STATE/issues.json")" = '["status:doing","type:chore"]'
check "só rotas repos/acme/proj e nada de GraphQL (CA-4)" no_graphql

echo "open-pr.sh"
git switch -qc task/001-setup-projeto
./scripts/set-status.sh "$T" review >/dev/null
git commit -qam "001 · docs" && git push -qu origin task/001-setup-projeto
url="$(echo "Scaffold do projeto." | ./scripts/open-pr.sh "$T")"
check "imprime a URL do PR" test "$url" = https://github.com/acme/proj/pull/2
check "título e branches" test "$(jq -c '.[0] | [.title, .head.ref, .base.ref]' "$GH_STATE/pulls.json")" \
  = '["001 · Setup do projeto","task/001-setup-projeto","main"]'
body="$(jq -r '.[0].body' "$GH_STATE/pulls.json")"
check "corpo: Closes, Spec e resumo" grep -qzP 'Closes #1\n\nSpec: docs/tasks/001-setup-projeto.md\n\n## O que entrou\n\nScaffold do projeto.\n' <<<"$body"
check "PR na coluna PR do roadmap" grep -qF '| review | #1 | #2 |' docs/roadmap.md
check "commit do PR na branch, com push" test "$(git log -1 --format=%s):$(git rev-list --count '@{u}..HEAD')" = "001 · registra PR #2 no roadmap:0"
check "label status:doing removida" test "$(jq -c '[.[0].labels[].name]' "$GH_STATE/issues.json")" = '["type:chore"]'
url2="$(./scripts/open-pr.sh "$T" </dev/null)"
check "segunda execução não abre outro PR" test "$url2:$(count 'API POST repos/acme/proj/pulls$')" = "$url:1"
check "só rotas repos/acme/proj e nada de GraphQL (CA-4)" no_graphql

echo "sync-board.sh"
setup sync
printf 'OWNER=acme\nPROJECT_NUMBER=7\n' > scripts/board.conf
check "--auto sem acesso ao Projects (nuvem) sai sem erro" ./scripts/sync-board.sh --auto
rm scripts/board.conf
check "--auto sem board.conf sai sem erro" ./scripts/sync-board.sh --auto
check "sem --auto e sem board.conf falha" bash -c '! ./scripts/sync-board.sh'
printf 'OWNER=acme\nPROJECT_NUMBER=7\n' > scripts/board.conf
# 001 todo com PR aberto, 002 todo com status:doing, 003 done.
cat >> docs/roadmap.md <<'MD'
| 002 | [Dois](tasks/002-dois.md) | todo | #11 | |
| 003 | [Três](tasks/003-tres.md) | done | #12 | #13 |
MD
sed -i 's/| 001 | \(.*\) | todo | | |/| 001 | \1 | todo | #10 | |/' docs/roadmap.md
echo '[{"number":11,"labels":[{"name":"status:doing"}],"state":"open"}]' > "$GH_STATE/issues.json"
echo '[{"number":14,"body":"Closes #10\n\nSpec: ..."}]' > "$GH_STATE/pulls.json"
echo '{"items":[{"id":"PVTI_12","content":{"type":"Issue","repository":"acme/proj","number":12}}]}' > "$GH_STATE/items.json"
export GH_PROJECTS=1
./scripts/sync-board.sh >/dev/null
check "PR aberto vira review" grep -q 'item-edit --project-id PVT_1 --id PVTI_10 --field-id F_ETAPA --single-select-option-id O_review' "$GH_LOG"
check "label status:doing vira doing" grep -q 'id PVTI_11 --field-id F_ETAPA --single-select-option-id O_doing' "$GH_LOG"
check "done fica done" grep -q 'id PVTI_12 --field-id F_ETAPA --single-select-option-id O_done' "$GH_LOG"
check "ordem pela linha do roadmap" grep -q 'id PVTI_11 --field-id F_ORDEM --number 2' "$GH_LOG"
check "só adiciona ao board o que não está lá (CA-6)" test "$(count 'project item-add')" = 2
check "sem GITHUB_REPOSITORY, usa o remote; só rotas do repo" only_repo_routes
: > "$GH_LOG"
GITHUB_REPOSITORY=acme/proj ./scripts/sync-board.sh --auto >/dev/null
check "--auto com acesso ao Projects sincroniza" test "$(count 'project item-edit')" = 6

echo "workflow sync-board.yml (CA-5)"
RUN="$(yq -r '.jobs.sync.steps[1].run' .github/workflows/sync-board.yml)"
rm scripts/board.conf
o="$(GH_TOKEN=x bash -ec "$RUN")"
check "sem board.conf: verde, com aviso" grep -q '^::warning::Sem scripts/board.conf' <<<"$o"
printf 'OWNER=acme\nPROJECT_NUMBER=7\n' > scripts/board.conf
o="$(GH_TOKEN='' bash -ec "$RUN")"
check "sem PROJECT_TOKEN: verde, com aviso" grep -q '^::warning::Secret PROJECT_TOKEN' <<<"$o"
o="$(GH_TOKEN=x bash -ec "$RUN")"
check "com os dois: roda o sync" grep -q '^Board sincronizado' <<<"$o"

echo
echo "$pass ok, $fail falha(s)"
[ "$fail" = 0 ]
