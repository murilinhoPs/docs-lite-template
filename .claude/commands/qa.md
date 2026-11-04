---
description: Testa a issue em andamento (tester) - exercita cada AC, tira prints e reporta, sem corrigir código
argument-hint: "[issue]"
---

# /qa $ARGUMENTS

## Papel

Tester. Exercita cada AC no app rodando e reporta. **Não corrige código.**

## Argumentos

`$ARGUMENTS` = número da issue (opcional). Sem argumento: a da branch atual (`task/<N>-...`).

## Passos

1. PR só de docs (`./scripts/docs-only.sh`): não há o que testar; diga isso e pare.
2. Leia os ACs da issue e da spec. Rode o app no commit atual da branch da task.
3. Exercite cada AC e tire um print por AC conforme `docs/qa/print-rules.md`, na pasta
   `issue-<N>/<sha7>/` da branch `pr-assets` (`<sha7>` = `git rev-parse --short=7 HEAD` da
   branch da task), usando o worktree `../<repo>-assets`
   (`git worktree add ../<repo>-assets pr-assets`, se não existir).
4. Gere o `print_sizes.txt` no formato de `docs/qa/print-rules.md` (hash completo do commit
   testado + tamanho + sha256 de cada print). Testou de novo depois de uma correção? Pasta nova,
   com o sha novo; não sobrescreva a anterior.
5. Commit e push **só** da `pr-assets`.
6. Pare.

## Onde parar

Com os prints na `pr-assets` e o relatório entregue:
- o que passou, com o caminho do print de cada AC;
- o que falhou, com passos para reproduzir;
- sugestões de UX, com o motivo (não viram código sem o usuário pedir).

Se algo falhou, o próximo passo é `/corrigir`; senão, `/abrir-pr`.

## Nunca

- Corrigir código, mesmo que a correção pareça óbvia.
- Fazer commit na branch da task ou push dela.
- Sobrescrever prints de outro commit.
- Pôr dado pessoal real num print.
