#!/usr/bin/env bash
# Teste de fumaça: o fluxo de um projeto novo, ponta a ponta, com gh simulado.
#
# bootstrap (só M0) → roadmap geral válido → new-milestone → new-issue (linha todo)
# → task-status doing → open-pr (Head e prints) → pr-gate (verde e vermelho)
# → sync-board (Etapa calculada) → merge → fechar o milestone (encerramento guardado
# nele, como o /fechar faz) → pré-condição do /planejar M1.
#
# Uso: ./scripts/test/smoke.sh [--sem-board]   (o ./scripts/test/run.sh roda os dois)
#   --sem-board: o mesmo fluxo com ./scripts/bootstrap.sh --sem-board; o sync não chama o gh.
set -euo pipefail
SEM_BOARD=0
case "${1:-}" in
  --sem-board) SEM_BOARD=1 ;;
  "") ;;
  *) echo "Uso: ./scripts/test/smoke.sh [--sem-board]" >&2; exit 1 ;;
esac

# shellcheck source=scripts/test/helpers.sh
source "$(dirname "$0")/helpers.sh"
PATH="$STUB:$PATH"
R=docs/roadmap.md
M0="M0 — Fundação e spike"
step() { echo "$1"; }

setup "smoke$([ "$SEM_BOARD" = 1 ] && echo -sem-board)"
export GH_LOCAL=1
echo '[]' > "$GH_STATE/milestones.json"
sed -i 's/| F1 | <nome> | Must | \[specs\/<feature>.md\](specs\/<feature>.md) | area:<x> |/| F1 | Login | Must | [specs\/auth.md](specs\/auth.md) | area:auth |/' docs/prd.md

step "1. bootstrap: só o M0 e a issue de setup"
BOOT_ARGS=(); [ "$SEM_BOARD" = 1 ] && BOOT_ARGS=(--sem-board)
./scripts/bootstrap.sh "${BOOT_ARGS[@]}" > "$GH_STATE/boot.out" 2>&1 || { ko "bootstrap"; sed 's/^/    /' "$GH_STATE/boot.out"; }
check "só o milestone M0 no GitHub" test "$(jq -c '[.[].title]' "$GH_STATE/milestones.json")" = "[\"$M0\"]"
check "issue de setup #1 na seção Issues por milestone, todo" test "$(section "$M0")" = "1|#1|[chore] Setup do projeto|todo|—|"
if [ "$SEM_BOARD" = 1 ]; then
  check "sem board: board.conf = BOARD=nao e nenhuma chamada gh project" \
    test "$(cat scripts/board.conf):$(count '^gh project')" = "BOARD=nao:0"
else
  check "board copiado do modelo e board.conf gravado" test -s scripts/board.conf
fi
git add -A && git commit -qm "bootstrap" && git push -q

step "2. /planejar (visão geral): roadmap geral válido"
# Simula a etapa 1: mais um milestone na seção Milestones, só prosa.
awk '/^## Issues por milestone/ && !done {
  print "### M1 — MVP"; print "- **Objetivo:** login funcionando"; print "- **Escopo:** F1 | F2 (#prosa)"
  print "- **Critério de saída:** login de ponta a ponta no Android"; print "- **Depende de / decisões abertas:** go do M0"
  print "- **Tamanho:** M"; print ""; done = 1 } { print }' "$R" > "$R.tmp" && mv "$R.tmp" "$R"
valid_roadmap() {
  awk '/^## Milestones/ { m = 1; next } /^## / { m = 0 }
    m && /^### M[0-9]+ — / { if (h) chk(); h = $0; f = 0; next }
    m && /^- \*\*(Objetivo|Escopo|Critério de saída|Depende de \/ decisões abertas|Tamanho):\*\*/ { f++ }
    function chk() { if (f != 5) { print "faltam campos em " h > "/dev/stderr"; bad = 1 } }
    END { if (h) chk(); exit bad || !h }' "$R"
}
check "cada milestone da visão geral tem os 5 campos" valid_roadmap
check "a visão geral não cria issue nem milestone no GitHub" \
  test "$(jq length "$GH_STATE/issues.json"):$(jq length "$GH_STATE/milestones.json"):$(source scripts/lib.sh && roadmap_rows "$R" | wc -l)" = "1:1:1"

step "3. /planejar M0: new-milestone (idempotente) e new-issue"
check "new-milestone acha o M0 do bootstrap" test "$(./scripts/new-milestone.sh "$M0")" = 1
printf '**Spec:** docs/specs/auth.md  (F1)\n**Milestone:** docs/milestones/m0.md\n\n## Critérios de aceite\n- [ ] AC-F1-01: entra\n' > "$GH_STATE/corpo.md"
N="$(./scripts/new-issue.sh --title "[feat] Spike de login" --body-file "$GH_STATE/corpo.md" --milestone M0 --labels type:feature)"
check "issue nova no M0, linha todo depois da de setup" test "$(section "$M0" | sed -n 2p)" = "2|#$N|[feat] Spike de login|todo|specs/auth.md|"
check "nenhum milestone futuro no GitHub" test "$(jq length "$GH_STATE/milestones.json")" = 1
git commit -qam "Planejar M0" && git push -q

step "4. /implementar: task-status doing"
git switch -qc "task/$N-spike"
./scripts/task-status.sh "$N" doing > /dev/null
check "status doing no roadmap" test "$(source scripts/lib.sh && roadmap_get "$R" "$N" status)" = doing
mkdir -p docs/specs && echo "# F1" > docs/specs/auth.md && echo app > app.txt
git add -A && git commit -qm "Spike de login"
CODE="$(git rev-parse HEAD)"

step "5. /qa e /abrir-pr: prints, done, open-pr com Head"
# O bootstrap criou a pr-assets e o worktree ../<repo>-assets.
ASSETS="$(cd .. && pwd)/$(basename "$PWD")-assets"
check "bootstrap criou o worktree da pr-assets" test -d "$ASSETS"
prints() { (cd "$ASSETS" && mkdir -p "issue-$N/${1:0:7}" \
  && printf 'commit: %s\nac-f1-01.png  1x1  %064d\n' "$1" 0 > "issue-$N/${1:0:7}/print_sizes.txt" \
  && git add -A && git commit -qm "prints ${1:0:7}" && git push -q origin pr-assets); }
prints "$CODE"
./scripts/task-status.sh "$N" done > /dev/null
git commit -qam "Marca #$N como done" && git push -qu origin "task/$N-spike"
echo PASS > "$GH_STATE/tests.txt"
url="$(echo "Spike de login." | ./scripts/open-pr.sh "$N" --tests-file "$GH_STATE/tests.txt")"
PR="${url##*/}"
HEAD_SHA="$(git rev-parse HEAD)"
body_now() { jq -r --argjson p "$PR" '.[] | select(.number == $p) | .body' "$GH_STATE/pulls.json"; }
check "PR aberto com Head = head final" grep -qxF "**Head:** $HEAD_SHA" <<<"$(body_now)"
check "PR cita os prints do commit de código" grep -qF "pr-assets/issue-$N/${CODE:0:7}/" <<<"$(body_now)"
check "número do PR na coluna PR, linha done" test "$(source scripts/lib.sh && roadmap_get "$R" "$N" pr):$(source scripts/lib.sh && roadmap_get "$R" "$N" status)" = "#$PR:done"

step "6. pr-gate: verde e vermelho"
gate() { gh api "repos/acme/proj/pulls/$PR" | jq '{pull_request: (. + {base: {ref: "main"}})}' > "$GH_STATE/event.json" \
  && GITHUB_EVENT_PATH="$GH_STATE/event.json" ./scripts/pr-gate.sh; }
check "verde: Head certo e prints valem (depois deles só docs)" gate
echo "mais" >> app.txt && git commit -qam "Corrige" && git push -q
o="$(gate 2>&1 || true)"
check "vermelho: Head desatualizado depois de um push" grep -q "Head do corpo desatualizado" <<<"$o"
./scripts/open-pr.sh --update "$PR" > /dev/null 2>&1
o="$(gate 2>&1 || true)"
check "vermelho: código mudou depois dos prints" grep -q "e o código mudou até o head" <<<"$o"
prints "$(git rev-parse HEAD)"
./scripts/open-pr.sh --update "$PR" > /dev/null 2>&1
check "verde de novo com prints do head novo" gate

SEM_SYNC="Sem board (BOARD=nao em scripts/board.conf): nada a sincronizar."
step "7. sync-board: Etapa calculada"
: > "$GH_LOG"
if [ "$SEM_BOARD" = 1 ]; then
  check "sem board: nada a sincronizar, sem chamar o gh" \
    bash -c 'test "$(./scripts/sync-board.sh --auto)" = "$0" && test ! -s "$1"' "$SEM_SYNC" "$GH_LOG"
else
./scripts/sync-board.sh > /dev/null
etapa() { grep -q "id PVTI_$1 --field-id F_ETAPA --single-select-option-id O_$2" "$GH_LOG"; }
check "setup sem PR → todo" etapa 1 todo
check "issue com PR aberto → review" etapa "$N" review
fi

step "8. merge travado no head e /fechar"
check "merge.sh com o head atual" ./scripts/merge.sh "$PR" "$(git rev-parse HEAD)"
# O GitHub fecha o PR e a issue (Closes #N); a de setup também já foi entregue.
jq --argjson p "$PR" 'map(if .number == $p then .state = "closed" | .merged_at = "2026-01-01T00:00:00Z" else . end)' \
  "$GH_STATE/pulls.json" > "$GH_STATE/x" && mv "$GH_STATE/x" "$GH_STATE/pulls.json"
jq 'map(.state = "closed")' "$GH_STATE/issues.json" > "$GH_STATE/x" && mv "$GH_STATE/x" "$GH_STATE/issues.json"
: > "$GH_LOG"
if [ "$SEM_BOARD" = 1 ]; then
  check "sem board: o sync do /fechar também não chama o gh" \
    bash -c 'test "$(./scripts/sync-board.sh)" = "$0" && test ! -s "$1"' "$SEM_SYNC" "$GH_LOG"
else
./scripts/sync-board.sh > /dev/null
check "issues fechadas → done no board" bash -c 'grep -q "id PVTI_1 --field-id F_ETAPA --single-select-option-id O_done" "$0" && grep -q "id PVTI_$1 --field-id F_ETAPA --single-select-option-id O_done" "$0"' "$GH_LOG" "$N"
fi
MS="$(jq -r '.[0].milestone.number' "$GH_STATE/issues.json")"
check "milestone sem issues abertas (fim de milestone)" test "$(gh api "repos/acme/proj/milestones/$MS" -q .open_issues)" = 0
printf 'Encerrado em 2026-01-02.\nCritério de saída: confirmado — login de ponta a ponta\ngo/no-go: go — o spike provou o login\n' > "$GH_STATE/enc.md"
gh api -X PATCH "repos/acme/proj/milestones/$MS" -f state=closed -F "description=@$GH_STATE/enc.md" > /dev/null
desc="$(gh api "repos/acme/proj/milestones?state=closed" -q '.[] | select(.title | startswith("M0 ")) | .description')"
check "pré-condição do /planejar M1: M0 fechado, critério confirmado e go" \
  bash -c 'grep -q "Critério de saída: confirmado" <<<"$0" && grep -q "go/no-go: go" <<<"$0"' "$desc"
[ "$SEM_BOARD" = 1 ] && check "sem board: nenhuma chamada gh project no fluxo" test "$(count '^gh project')" = 0
check "o fluxo todo só usou rotas repos/acme/proj na API" \
  bash -c '! grep "^API " "$0" | grep -qv "^API [A-Z]* repos/acme/proj\(/\|$\)"' "$GH_LOG"

echo
echo "fumaça$([ "$SEM_BOARD" = 1 ] && echo " --sem-board"): $pass ok, $fail falha(s)"
[ "$fail" = 0 ]
