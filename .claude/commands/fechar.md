---
description: Fecha uma task depois do merge (PM) - confere a issue, sincroniza o board, transforma nits aprovados em issues e fecha o milestone
argument-hint: "[pr]"
---

# /fechar $ARGUMENTS

## Papel

PM. Faz o pós-merge: confere, sincroniza e decide o que vira trabalho novo.

## Argumentos

`$ARGUMENTS` = número do PR (opcional). Sem argumento: o último PR mergeado
(`gh api "repos/{owner}/{repo}/pulls?state=closed&sort=updated&direction=desc&per_page=5"`).

## Passos

1. Confira que o PR foi mergeado (`gh api repos/{owner}/{repo}/pulls/<pr> -q .merged` é `true`)
   e que a issue dele fechou (`gh api repos/{owner}/{repo}/issues/<N> -q .state`). Se não, avise e pare.
2. `git switch main && git pull` e `./scripts/sync-board.sh --auto` (a issue fechada aparece como
   `done`; sem board acessível, ele avisa e segue).
3. Liste os nits e os "deveria" do último review do PR e pergunte quais viram issue.
   Os aprovados viram issues com `prio:baixa`, **sem** linha no roadmap (o próximo `/planejar`
   decide onde entram, com `./scripts/new-issue.sh --existing <N>`):
   `gh api repos/{owner}/{repo}/issues -f title="[chore] ..." -F body=@<corpo.md> -f "labels[]=type:chore" -f "labels[]=prio:baixa"`.
4. **Fim de milestone.** Se essa era a última issue aberta do milestone (todas as linhas dele no
   roadmap `done` e `gh api repos/{owner}/{repo}/milestones/<n> -q .open_issues` é `0`):
   1. Mostre o **critério de saída** de `docs/milestones/m<n>.md` e peça ao usuário que confirme
      que foi atingido. Se não foi, pare: o que falta vira issue pelo `/planejar M<n>`.
   2. Feche o milestone no GitHub: `gh api -X PATCH repos/{owner}/{repo}/milestones/<n> -f state=closed`.
   3. **M0:** pergunte o **go/no-go** e registre num ADR `Aceita` (`docs/adr/NNNN-go-no-go-m0.md`,
      com o que o spike provou e a decisão), atualizando o índice de `docs/adr/README.md`.
   4. Numa branch `fechar/m<n>` a partir da `main`: marque o doc `status: encerrado` (ele vira
      histórico), inclua o ADR do go/no-go (M0) e abra um PR só de docs `[docs] Encerrar M<n>`
      (`gh api repos/{owner}/{repo}/pulls ...` + `./scripts/open-pr.sh --update <pr>`), com o
      comando de merge (`./scripts/merge.sh <pr> <head>`).
   5. **No-go no M0:** pare. O usuário revisa o PRD e o roadmap antes de qualquer `/planejar M1`.
5. Pare.

## Onde parar

Com o board, os nits e o milestone atualizados. Resuma: PR e issue fechados, issues novas
(número e título), milestone fechado ou não e o próximo passo:
- milestone ainda aberto: a próxima task do roadmap (primeira linha `todo`), com `/implementar`;
- milestone encerrado: merge do PR `[docs] Encerrar M<n>` e depois `/planejar M<n+1>`
  (no M0, só com **go**).

## Nunca

- Mudar arquivos direto na `main` (ela é protegida; a linha da task já entrou como `done` com o PR,
  e o encerramento do milestone vai num PR de docs).
- Fechar o milestone sem o usuário confirmar o critério de saída, ou seguir para o M1 com no-go.
- Criar issue de nit sem o usuário aprovar.
- Pôr as issues novas no roadmap: isso é do `/planejar`.
