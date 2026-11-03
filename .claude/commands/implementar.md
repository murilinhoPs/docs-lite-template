---
description: Implementa a próxima issue do roadmap (ou a issue pedida) com commits locais
argument-hint: "[issue]"
---

# /implementar $ARGUMENTS

## Papel

Dev. Implementa uma issue, com testes, dentro do escopo dos ACs.

## Argumentos

`$ARGUMENTS` = número da issue (opcional). Sem argumento: a task interrompida (linha `doing` do
`docs/roadmap.md`), se houver; senão a primeira linha `todo`. Nunca pule a ordem sem o usuário
pedir; passar o número é pedir (ex.: hotfix).

## Passos

1. `git fetch origin main` e `./scripts/next-task.sh [<N>]`: ele imprime a issue e confere a ordem.
   - Sai com 1: pare e repita a mensagem dele. Sem argumento, ele exige a linha anterior do
     roadmap com a issue fechada: "A task anterior (#<P>) ainda está aberta: falta o merge ou o
     /fechar." (o usuário faz o merge e o `/fechar`, ou passa o número da issue para pular a ordem).
   - Sai com 2: é um **hotfix** com outra task em andamento; siga a seção "Hotfix" abaixo.
2. **Retomada** (a issue escolhida está `doing` e já tem branch `task/<N>-<slug>`): volte para a
   branch, `git rebase origin/main` (conflito: pare, mostre os arquivos e pergunte) e continue do
   passo 5. O commit `wip:` do hotfix pode ficar ou ser desfeito com `git reset --soft HEAD~1`;
   nunca reescreva o que já teve push.
3. `git switch main && git pull`. Leia a issue (`gh api repos/{owner}/{repo}/issues/<N>`), a
   spec citada em **Spec:**, os ADRs e os docs de design citados.
4. Se a issue citar um AC que não existe na spec, pare: "A issue #<N> cita <AC>, que não existe
   em <spec>: escreva o AC na spec (no PR desta task ou pelo /planejar M<n>)."
5. `git switch -c task/<N>-<slug>` (se ainda não existe) e `./scripts/task-status.sh <N> doing`.
6. Implemente seguindo os ACs, com testes do que mudou. Se o comportamento mudou, atualize a
   spec (Resumo, Estados, Ações, ACs vigentes) e o `updated:`.
7. Rode os testes e faça commits locais.
8. Pare.

### Hotfix (`/implementar <N>` com outra task `doing`)

1. **Pare e confirme**: "A task #<atual> está em andamento; faço o hotfix #<N> antes?". Sem o
   "sim", não mexa em nada.
2. Na branch da task atual: commit local de tudo (`git add -A && git commit -m "wip: <resumo>"`),
   sem push.
3. `git switch main && git pull` e `git switch -c task/<N>-<slug>`.
4. Roadmap: a linha do hotfix vai para logo depois da última linha `done` (antes da task
   interrompida): `./scripts/new-issue.sh --existing <N> --after <última done>`. O script cria a
   linha se ela não existe, ou a move se já está no roadmap. Depois,
   `./scripts/task-status.sh <N> doing`. A task interrompida continua `doing`.
5. Siga os passos 3 a 8 acima. O hotfix tem o ciclo normal (`/abrir-pr`, `/revisar`, merge, `/fechar`).
6. Depois do `/fechar` do hotfix, `/implementar` sem argumento acha a task interrompida (`doing`)
   e a retoma (passo 2). A linha anterior a ela agora é o hotfix, já fechado.

## Onde parar

Com os commits locais feitos, **antes do push**. Diga: o que mudou, como testar cada AC, o que
ficou em aberto e o próximo passo (`/qa` opcional, ou `/abrir-pr`).

## Nunca

- Dar push ou abrir PR.
- Fazer algo fora do escopo dos ACs (anote como sugestão).
- Começar um hotfix sem a confirmação do usuário, ou dar push no commit `wip:`.
- Criar AC novo sem passar pelo `/planejar`.
- Mexer no board à mão.
