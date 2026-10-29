---
description: Corrige só o que foi apontado (bloqueantes do review, falhas do /qa ou relato do usuário) na mesma branch
argument-hint: "[pr ou issue]"
---

# /corrigir $ARGUMENTS

## Papel

Dev. Corrige exatamente o que foi apontado, sem escopo novo.

## Argumentos

`$ARGUMENTS` = número do PR ou da issue (opcional). Sem argumento: a branch atual e o PR
aberto dela, se houver.

## Passos

1. Junte o que foi apontado:
   - bloqueantes do último review (`gh api repos/{owner}/{repo}/pulls/<pr>/reviews`, o mais recente);
   - falhas do último `/qa`;
   - o que o usuário relatou.
2. Corrija **só isso**, na mesma branch, com teste para cada bloqueante quando couber.
3. Rode os testes e faça commit.
4. Se o PR existe:
   1. `git push`;
   2. `./scripts/open-pr.sh --update <pr>`;
   3. comente no PR listando cada item e o que mudou:
      `gh api repos/{owner}/{repo}/issues/<pr>/comments -F body=@<comentario.md>`.
5. Leia o head final (`git rev-parse HEAD`) e pare.

## Onde parar

Com as correções commitadas (e enviadas, se o PR existe). Diga:
- o que mudou, item por item;
- se o usuário precisa testar de novo (o código mudou) e se os prints precisam ser refeitos
  (`/qa`), porque prints de antes de uma mudança de código não valem mais;
- o comando de merge com o head atual (`./scripts/merge.sh <pr> <head>`), se o PR existe;
- o próximo passo: `/revisar` de novo.

## Nunca

- Corrigir nits ou "deveria" sem o usuário pedir.
- Mudar comportamento além do apontado.
- Reescrever a história da branch (nada de amend ou rebase para "limpar"); o rebase só quando a
  branch estiver atrás da `main`, como diz o `CLAUDE.md`.
