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
4. Se todas as issues do milestone fecharam
   (`gh api "repos/{owner}/{repo}/milestones?state=open" -q '.[] | select(.open_issues == 0) | .number'`),
   feche-o: `gh api -X PATCH repos/{owner}/{repo}/milestones/<n> -f state=closed`.
5. Pare.

## Onde parar

Com o board, os nits e o milestone atualizados. Resuma: PR e issue fechados, issues novas
(número e título), milestone fechado ou não, e a próxima task do roadmap (primeira linha `todo`).

## Nunca

- Mudar o roadmap na `main` (ela é protegida; a linha já entrou como `done` com o PR).
- Criar issue de nit sem o usuário aprovar.
- Pôr as issues novas no roadmap: isso é do `/planejar`.
