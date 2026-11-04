---
description: Revisa um PR (review postado) ou a branch da task antes do PR (review só na conversa), com o subagente revisor
argument-hint: "[pr | local]"
---

# /revisar $ARGUMENTS

## Papel

Reviewer, sempre pelo subagente `revisor` (`.claude/agents/revisor.md`), para o review ter
contexto limpo, sem o que foi pensado durante a implementação.

## Argumentos

`$ARGUMENTS` = número do PR, `local` ou nada.

| Modo | Quando | O que revisa | Onde o resultado vai |
|---|---|---|---|
| PR | há PR (argumento `<pr>`, ou o PR aberto da branch atual) | `git diff origin/main...<head>` do PR | review `event=COMMENT` travado no head |
| Local | `/revisar local`, ou a branch atual não tem PR | `git diff origin/main...HEAD` da branch atual | **só na conversa**; nada é postado no GitHub |

## Passos

1. Resolva o modo:
   - número → modo PR com esse PR;
   - `local` → modo local;
   - sem argumento → `./scripts/task-atual.sh`: `pr_state=open` → modo PR com o `pr`; sem PR
     aberto → modo local, avisando "sem PR, revisando localmente". Saída `2` (ambíguo):
     pergunte qual das candidatas; sem ninguém para responder, pare.
2. **Nada para revisar:** na `main`, ou sem commits à frente da `main`
   (`git rev-list --count origin/main..HEAD` é `0`), pare e diga "nada para revisar: a branch
   não tem commits à frente da main".
3. Chame o subagente `revisor` só com a entrada do modo: o número do PR (modo PR) ou `local` e a
   branch (modo local). Não passe resumo da implementação nem opinião sobre o código.
4. Repasse ao usuário o que ele devolver: no modo PR, o resumo e o link do review; no modo local,
   o review completo e o resumo, com o sha7 revisado.

## Onde parar

- Modo PR: com o review postado como comentário no PR (pelo subagente) e o resumo repassado
  (N bloqueantes, N deveria, N nits e a recomendação). Com bloqueantes, o próximo passo é
  `/corrigir`; sem eles, o merge (do usuário).
- Modo local: com o review na conversa, sem nada postado. Com bloqueantes: `/corrigir` e
  `/revisar` de novo. Sem bloqueantes: `/abrir-pr`; depois do PR aberto, o `/revisar` roda no
  modo PR e posta o review travado no head (o local não substitui o review do PR).
- Commit novo depois do review (local ou de PR): o review deixa de valer.

## Nunca

- Revisar no contexto principal, sem o subagente.
- Editar código ou corrigir achados aqui (isso é o `/corrigir`).
- Aprovar ou pedir mudanças pelo GitHub: o review é sempre `event=COMMENT`.
- No modo local, postar qualquer coisa no GitHub.
