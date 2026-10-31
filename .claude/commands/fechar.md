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
4. **Fim de milestone** (`<ms>` = número do milestone no GitHub, `.milestone.number` da issue).
   Se essa era a última issue aberta do milestone (todas as linhas dele no
   roadmap `done` e `gh api repos/{owner}/{repo}/milestones/<ms> -q .open_issues` é `0`):
   1. Mostre o **critério de saída** de `docs/milestones/m<n>.md` e peça ao usuário que confirme
      que foi atingido. Se não foi, pare: o que falta vira issue pelo `/planejar M<n>`.
   2. **M0:** pergunte o **go/no-go** e o porquê (o que o spike provou ou não).
   3. Feche o milestone no GitHub guardando o encerramento na descrição dele (é só REST: nenhum
      arquivo muda aqui, a `main` é protegida):
      `gh api -X PATCH repos/{owner}/{repo}/milestones/<ms> -f state=closed -F description=@<encerramento.md>`,
      com o `encerramento.md` assim:
      ```
      Encerrado em AAAA-MM-DD.
      Critério de saída: confirmado — <o que foi conferido>
      go/no-go: go | no-go — <motivo>        (só no M0)
      ```
   4. O doc `docs/milestones/m<n>.md` (`status: encerrado`) e, no M0, o ADR `Aceita` do go/no-go
      entram no PR do próximo `/planejar M<n+1>`, que lê essa descrição.
   5. **No-go no M0:** pare. O usuário revisa o PRD e o roadmap antes de qualquer `/planejar M1`.
5. Pare.

## Onde parar

Com o board, os nits e o milestone atualizados. Resuma: PR e issue fechados, issues novas
(número e título), milestone fechado ou não e o próximo passo:
- milestone ainda aberto: a próxima task do roadmap (primeira linha `todo`), com `/implementar`;
- milestone encerrado: `/planejar M<n+1>` (no M0, só com **go**); o PR dele registra o
  encerramento (doc `encerrado` e, no M0, o ADR do go/no-go).

## Nunca

- Mudar arquivos direto na `main` (ela é protegida; a linha da task já entrou como `done` com o PR,
  e o encerramento do milestone vai no PR do próximo `/planejar M<n+1>`).
- Fechar o milestone sem o usuário confirmar o critério de saída, ou seguir para o M1 com no-go.
- Criar issue de nit sem o usuário aprovar.
- Pôr as issues novas no roadmap: isso é do `/planejar`.
