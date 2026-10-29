#!/usr/bin/env bash
# Roda UMA vez em cada projeto novo criado a partir do template, LOCALMENTE,
# com o gh do usuário logado. Não funciona nas sessões do Claude Code na nuvem
# (usa GraphQL: gh repo view, gh label, gh project).
# Cria o que o "Use this template" não copia: milestones, labels, a issue de
# setup (com a linha no roadmap), board no Projects, branch pr-assets e
# configurações de merge/proteção.
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
gh label create type:design --repo "$REPO" --color D4C5F9 --description "Mudança visual, exige prints" --force >/dev/null

# area:* = coluna Área da tabela Features do docs/prd.md (linhas com <placeholder> são ignoradas).
AREAS="$(awk -F'|' '
  /^## / { feat = ($0 ~ /^## Features/) }
  feat && /^\|/ {
    if (!hdr) { hdr = 1; for (i = 2; i < NF; i++) { h = $i; gsub(/[ \t]/, "", h); if (h == "Área") col = i }; next }
    if (!col) next
    a = $col; gsub(/[ \t`]/, "", a)
    if (a == "" || a ~ /[<>]/ || a ~ /^-+$/) next
    sub(/^area:/, "", a); print "area:" a
  }' docs/prd.md | sort -u)"
if [ -n "$AREAS" ]; then
  while read -r a; do
    gh label create "$a" --repo "$REPO" --color C5DEF5 --force >/dev/null
  done <<<"$AREAS"
  echo "  labels area:*: $(paste -sd ' ' <<<"$AREAS")"
else
  echo "  aviso: nenhuma área na tabela Features do docs/prd.md; labels area:* não criadas (rode de novo depois de preenchê-la)"
fi
echo "  labels: type:*, prio:*"

# 3. Issue de setup (corpo em docs/prompts/issue-setup.md) e a linha dela no roadmap
SETUP_TITLE="[chore] Setup do projeto"
SETUP_N="$(gh api --paginate "repos/$REPO/issues?state=all&per_page=100" \
  -q ".[] | select(.pull_request == null and .title == \"$SETUP_TITLE\") | .number" | head -n1)"
if [ -z "$SETUP_N" ]; then
  SETUP_N="$(./scripts/new-issue.sh --title "$SETUP_TITLE" --body-file docs/prompts/issue-setup.md \
    --milestone "M0 Fundação" --labels type:chore)"
  echo "  issue de setup criada: #$SETUP_N (faça commit do docs/roadmap.md)"
else
  ./scripts/new-issue.sh --existing "$SETUP_N" >/dev/null
  echo "  issue de setup já existe: #$SETUP_N"
fi

# 4. Board no GitHub Projects (espelho do docs/roadmap.md)
# Copia o projeto modelo (campos Etapa e Ordem + visões Board, Backlog e Roadmap).
# Troque com BOARD_TEMPLATE=<owner>/<número> ./scripts/bootstrap.sh, ou BOARD_TEMPLATE= para não copiar.
BOARD_TEMPLATE="${BOARD_TEMPLATE-murilinhoPs/2}"
CONF="scripts/board.conf"
OWNER="${REPO%%/*}"
if [ -f "$CONF" ]; then
  echo "  board já configurado ($CONF)"
elif ! gh project list --owner "$OWNER" --limit 1 >/dev/null 2>&1; then
  echo "  aviso: board não criado. Rode 'gh auth refresh -s project' e depois este script de novo."
else
  TITLE="$(basename "$REPO")"
  NUM=""
  if [ -n "$BOARD_TEMPLATE" ]; then
    NUM="$(gh project copy "${BOARD_TEMPLATE#*/}" --source-owner "${BOARD_TEMPLATE%%/*}" \
      --target-owner "$OWNER" --title "$TITLE" --format json -q .number 2>/dev/null)" \
      || echo "  aviso: não consegui copiar o projeto modelo $BOARD_TEMPLATE; criando um board vazio"
  fi
  if [ -n "$NUM" ]; then
    fields="$(gh project field-list "$NUM" --owner "$OWNER" --format json --limit 100 \
      -q '[.fields[] | select(.name == "Etapa" or .name == "Ordem") | .name] | sort | join(",")')"
    [ "$fields" = "Etapa,Ordem" ] || echo "  aviso: o modelo $BOARD_TEMPLATE não tem os campos Etapa e Ordem; o sync vai falhar"
    echo "  board copiado do modelo $BOARD_TEMPLATE: projeto #$NUM (com as visões)"
  else
    NUM="$(gh project create --owner "$OWNER" --title "$TITLE" --format json -q .number)"
    gh project field-create "$NUM" --owner "$OWNER" --name "Etapa" \
      --data-type SINGLE_SELECT --single-select-options "todo,doing,review,done" >/dev/null
    gh project field-create "$NUM" --owner "$OWNER" --name "Ordem" --data-type NUMBER >/dev/null
    echo "  board criado: projeto #$NUM"
    echo "  falta na interface: visões Board (por Etapa), Backlog (tabela por Ordem) e Roadmap (por Milestone)"
  fi
  gh project link "$NUM" --owner "$OWNER" --repo "$REPO" >/dev/null
  printf 'OWNER=%s\nPROJECT_NUMBER=%s\n' "$OWNER" "$NUM" > "$CONF"
  echo "  número salvo em $CONF (faça commit desse arquivo)"
fi

# 5. Branch órfã pr-assets para prints de teste
if git ls-remote --exit-code --heads origin pr-assets >/dev/null 2>&1; then
  echo "  pr-assets já existe"
else
  # Commit vazio sem pai, sem trocar de branch (o working tree pode ter mudanças,
  # como o roadmap com a issue de setup).
  commit="$(git commit-tree "$(git hash-object -t tree /dev/null)" -m "pr-assets")"
  git push -q origin "$commit:refs/heads/pr-assets"
  echo "  pr-assets criada"
fi

# 6. Worktree local da pr-assets (fora do repo, ao lado dele)
WT="../$(basename "$PWD")-assets"
if [ ! -d "$WT" ]; then
  git fetch origin pr-assets
  git worktree add "$WT" pr-assets
  echo "  worktree em $WT"
fi

# 7. Só squash merge, apagar branch após merge e formato do squash:
#    commit na main = "<título do PR> (#N)" com o corpo do PR (Closes #X, Co-authored-by).
gh repo edit "$REPO" \
  --enable-squash-merge \
  --enable-merge-commit=false \
  --enable-rebase-merge=false \
  --delete-branch-on-merge
gh api -X PATCH "repos/$REPO" \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY >/dev/null
echo "  merge: só squash, com título e corpo do PR"

# 8. Ruleset da main: sem push direto nem force push, merge só por PR (sem exigir
#    aprovação: projeto solo) e com os checks ci e pr-gate verdes no head, com a
#    branch atualizada com a main (strict). Rodar de novo atualiza o ruleset.
RULESET='{
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
    } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [ { "context": "ci" }, { "context": "pr-gate" } ]
    } }
  ]
}'
RULESET_ID="$(gh api "repos/$REPO/rulesets" -q '.[] | select(.name == "main protegida") | .id' 2>/dev/null | head -n1 || true)"
if [ -n "$RULESET_ID" ]; then
  gh api -X PUT "repos/$REPO/rulesets/$RULESET_ID" --input - >/dev/null <<<"$RULESET" \
    && echo "  ruleset da main atualizado (checks ci e pr-gate, strict)"
elif gh api -X POST "repos/$REPO/rulesets" --input - >/dev/null <<<"$RULESET"; then
  echo "  ruleset da main criado (checks ci e pr-gate, strict)"
else
  echo "  aviso: ruleset não criado (repo privado em plano Free não suporta rulesets; configure em Settings → Rules se disponível)"
fi

# 9. Primeira sincronização
[ -f "$CONF" ] && ./scripts/sync-board.sh || true

echo "Pronto. Faça commit de scripts/board.conf e docs/roadmap.md numa branch e abra um PR (a main é protegida)."
echo "Depois: preencher docs/overview.md e docs/prd.md e pedir ao Claude Code a próxima task (#$SETUP_N)."
