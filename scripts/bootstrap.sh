#!/usr/bin/env bash
# Roda UMA vez em cada projeto novo criado a partir do template.
# Cria o que o "Use this template" não copia: milestones, labels, board no
# Projects, branch pr-assets e configurações de merge/proteção.
# Pode ser rodado de novo: pula o que já existe.
#
# Uso: ./scripts/bootstrap.sh
# Para o board: gh auth refresh -s project
set -euo pipefail

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "Configurando $REPO"

# 1. Milestones (os mesmos títulos do docs/roadmap.md)
for m in "M0 Fundação" "M1 MVP"; do
  if gh api "repos/$REPO/milestones?state=all" -q '.[].title' | grep -qx "$m"; then
    echo "  milestone já existe: $m"
  else
    gh api "repos/$REPO/milestones" -f title="$m" >/dev/null
    echo "  milestone criado: $m"
  fi
done

# 2. Labels (prefixo fixo, uma cor por grupo). Remove as labels padrão do GitHub.
for l in bug documentation duplicate enhancement "good first issue" "help wanted" invalid question wontfix; do
  gh label delete "$l" --repo "$REPO" --yes >/dev/null 2>&1 || true
done
while read -r name color; do
  gh label create "$name" --repo "$REPO" --color "$color" --force >/dev/null
done <<'LABELS'
type:feature 1D76DB
type:bug D73A4A
type:docs 0E8A16
type:chore BFD4F2
prio:alta B60205
prio:media FBCA04
prio:baixa FEF2C0
LABELS
echo "  labels: type:*, prio:* (adicione area:* conforme o projeto)"

# 3. Board no GitHub Projects (espelho do docs/roadmap.md)
CONF="scripts/board.conf"
OWNER="${REPO%%/*}"
if [ -f "$CONF" ]; then
  echo "  board já configurado ($CONF)"
elif ! gh project list --owner "$OWNER" --limit 1 >/dev/null 2>&1; then
  echo "  aviso: board não criado. Rode 'gh auth refresh -s project' e depois este script de novo."
else
  NUM="$(gh project create --owner "$OWNER" --title "$(basename "$REPO")" --format json -q .number)"
  gh project link "$NUM" --owner "$OWNER" --repo "$REPO" >/dev/null
  gh project field-create "$NUM" --owner "$OWNER" --name "Etapa" \
    --data-type SINGLE_SELECT --single-select-options "todo,doing,review,done" >/dev/null
  gh project field-create "$NUM" --owner "$OWNER" --name "Ordem" --data-type NUMBER >/dev/null
  printf 'OWNER=%s\nPROJECT_NUMBER=%s\n' "$OWNER" "$NUM" > "$CONF"
  echo "  board criado: projeto #$NUM (salvo em $CONF; faça commit desse arquivo)"
  echo "  falta na interface: visões Board (por Etapa), Backlog (tabela por Ordem) e Roadmap (por Milestone)"
fi

# 4. Branch órfã pr-assets para prints de teste
if git ls-remote --exit-code --heads origin pr-assets >/dev/null 2>&1; then
  echo "  pr-assets já existe"
else
  current="$(git branch --show-current)"
  git switch --orphan pr-assets
  git commit --allow-empty -m "pr-assets"
  git push -u origin pr-assets
  git switch "$current"
  echo "  pr-assets criada"
fi

# 5. Worktree local da pr-assets (fora do repo, ao lado dele)
WT="../$(basename "$PWD")-assets"
if [ ! -d "$WT" ]; then
  git fetch origin pr-assets
  git worktree add "$WT" pr-assets
  echo "  worktree em $WT"
fi

# 6. Só squash merge e apagar branch após merge
gh repo edit "$REPO" \
  --enable-squash-merge \
  --enable-merge-commit=false \
  --enable-rebase-merge=false \
  --delete-branch-on-merge
echo "  merge: só squash"

# 7. Bloqueia push direto e force push na main (sem exigir aprovação: projeto solo)
gh api -X POST "repos/$REPO/rulesets" --input - >/dev/null <<'JSON' || echo "  aviso: ruleset não criado (repo privado em plano Free não suporta rulesets; configure em Settings → Rules se disponível)"
{
  "name": "main protegida",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
    } }
  ]
}
JSON

# 8. Primeira sincronização (só faz algo se já houver tasks com issue)
[ -f "$CONF" ] && ./scripts/sync-board.sh || true

echo "Pronto. Próximo passo: preencher docs/overview.md, docs/prd.md e pedir ao Claude Code a task 001."
