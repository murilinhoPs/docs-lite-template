#!/usr/bin/env bash
# Roda UMA vez em cada projeto novo criado a partir do template.
# Cria o que o "Use this template" não copia: milestones, branch pr-assets
# e configurações de merge/proteção.
#
# Uso: ./scripts/bootstrap.sh
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

# 2. Branch órfã pr-assets para prints de teste
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

# 3. Worktree local da pr-assets (fora do repo, ao lado dele)
WT="../$(basename "$PWD")-assets"
if [ ! -d "$WT" ]; then
  git fetch origin pr-assets
  git worktree add "$WT" pr-assets
  echo "  worktree em $WT"
fi

# 4. Só squash merge e apagar branch após merge
gh repo edit "$REPO" \
  --enable-squash-merge \
  --enable-merge-commit=false \
  --enable-rebase-merge=false \
  --delete-branch-on-merge
echo "  merge: só squash"

# 5. Bloqueia push direto e force push na main (sem exigir aprovação: projeto solo)
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

echo "Pronto. Próximo passo: preencher docs/overview.md, docs/prd.md e pedir ao Claude Code a task 001."
