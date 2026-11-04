# Helpers dos testes (gh simulado + repo temporário). Uso: source scripts/test/helpers.sh
# Define SRC, WORK (apagado na saída), check/ok/ko, setup <nome> e consultas ao log do gh.

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
  echo '[{"number":3,"title":"M0 — Fundação e spike"},{"number":4,"title":"M1 — MVP"}]' > "$GH_STATE/milestones.json"
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
section() { awk -v h="### $1" '/^## Issues por milestone/ { iss = 1 } $0 == h && iss { s = 1; next } /^##/ { s = 0 } s && /\| #[0-9]/' "$R" | sed -E 's/^\| *//; s/ *\| *$//; s/ *\| */|/g'; }
# Toda chamada à API usa só rotas do repo e nenhum comando GraphQL foi usado.
only_repo_routes() {
  ! grep '^API ' "$GH_LOG" | grep -qv "^API [A-Z]* repos/acme/proj/" &&
    ! grep -qE '^gh (issue|pr|repo|label) ' "$GH_LOG"
}
no_graphql() { only_repo_routes && ! grep -q '^gh project ' "$GH_LOG"; }
body() { printf '**Spec:** docs/specs/%s.md  (F1)\n**Área:** area:x\n\n## Critérios de aceite\n- [ ] AC-F1-01: entra\n- [ ] AC-F1-02: sai\n' "$1" > "$GH_STATE/$1.md"; echo "$GH_STATE/$1.md"; }
