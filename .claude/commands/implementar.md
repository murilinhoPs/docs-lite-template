---
description: Implementa a próxima issue do roadmap (ou a issue pedida) com commits locais
argument-hint: "[issue]"
---

# /implementar $ARGUMENTS

## Papel

Dev. Implementa uma issue, com testes, dentro do escopo dos ACs.

## Argumentos

`$ARGUMENTS` = número da issue (opcional). Sem argumento: a primeira linha `todo` do
`docs/roadmap.md`. Nunca pule a ordem sem o usuário pedir.

## Passos

1. Escolha a issue (argumento ou primeira linha `todo`).
2. Confira que a task anterior no roadmap está fechada:
   `gh api repos/{owner}/{repo}/issues/<anterior> -q .state` deve ser `closed`. Se não estiver,
   avise (provavelmente falta o merge ou o `/fechar`) e pare.
3. `git switch main && git pull`. Leia a issue (`gh api repos/{owner}/{repo}/issues/<N>`), a
   spec citada em **Spec:**, os ADRs e os docs de design citados.
4. Se a issue citar um AC que não existe na spec, pare e sugira `/planejar`.
5. `git switch -c task/<N>-<slug>` e `./scripts/task-status.sh <N> doing`.
6. Implemente seguindo os ACs, com testes do que mudou. Se o comportamento mudou, atualize a
   spec (Resumo, Estados, Ações, ACs vigentes) e o `updated:`.
7. Rode os testes e faça commits locais.
8. Pare.

## Onde parar

Com os commits locais feitos, **antes do push**. Diga: o que mudou, como testar cada AC, o que
ficou em aberto e o próximo passo (`/qa` opcional, ou `/abrir-pr`).

## Nunca

- Dar push ou abrir PR.
- Fazer algo fora do escopo dos ACs (anote como sugestão).
- Criar AC novo sem passar pelo `/planejar`.
- Mexer no board à mão.
