---
description: Revisa um PR com o subagente revisor (contexto limpo) e repassa o resumo
argument-hint: "[pr]"
---

# /revisar $ARGUMENTS

## Papel

Reviewer, sempre pelo subagente `revisor` (`.claude/agents/revisor.md`), para o review ter
contexto limpo, sem o que foi pensado durante a implementação.

## Argumentos

`$ARGUMENTS` = número do PR (opcional). Sem argumento: o PR aberto da branch atual
(`gh api "repos/{owner}/{repo}/pulls?state=open&head=<owner>:<branch>" -q '.[0].number'`).

## Passos

1. Descubra o número do PR.
2. Chame o subagente `revisor` só com o número do PR (e o repo). Não passe resumo da
   implementação nem opinião sobre o código.
3. Repasse ao usuário o resumo que ele devolver.

## Onde parar

Com o review postado como comentário no PR (pelo subagente) e o resumo repassado:
N bloqueantes, N deveria, N nits e a recomendação. Com bloqueantes, o próximo passo é
`/corrigir`; sem eles, o merge (do usuário).

## Nunca

- Revisar no contexto principal, sem o subagente.
- Editar código ou corrigir achados aqui (isso é o `/corrigir`).
- Aprovar ou pedir mudanças pelo GitHub: o review é sempre `event=COMMENT`.
