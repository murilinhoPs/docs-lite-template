---
description: Abre (ou atualiza) o PR da issue com o head no corpo e mostra o comando de merge travado no head
argument-hint: "[issue]"
---

# /abrir-pr $ARGUMENTS

## Papel

Dev. Entrega a branch da task como PR, com o head aprovado no corpo.

## Argumentos

`$ARGUMENTS` = número da issue (opcional). Sem argumento, o comando descobre sozinho com
`./scripts/task-atual.sh` (branch atual, linha `doing` do roadmap, branch `task/*` à frente da
`main`): o usuário não precisa informar a issue nem o PR.

## Passos

0. **Descubra a task:** `./scripts/task-atual.sh [<N>]`. A saída é
   `issue=<N> branch=<branch> pr=<P|-> pr_state=<open|merged|closed|-> origem=<...>`.
   - Saída `2` (ambíguo): pergunte qual das candidatas (`AskUserQuestion` quando houver), com o
     título da issue e a branch. Sem ninguém para responder, pare.
   - Saída `3` (nada encontrado): pare e diga "não achei task implementada; rode `/implementar`
     ou passe o número da issue".
   - Saída `1` (issue fechada): pare e repita a mensagem do script.
   - `pr_state=merged` ou `closed`: pare e avise ("a #<N> já tem o PR #<P> `<estado>`").
   - A primeira linha da resposta diz o que foi descoberto: "Issue #<N>, branch
     `task/<N>-<slug>`, PR novo" ou "PR existente #<P>: atualizo".
   - Fora da branch da task: com a árvore limpa (`git status --porcelain` vazio),
     `git switch task/<N>-<slug>` e siga; com a árvore suja, **pare** e peça ao usuário para
     commitar ou guardar as mudanças antes de trocar de branch.
1. Confira a spec: atualizada nesta branch, ou o comportamento não mudou.
2. Rode os testes da stack e guarde a saída real num arquivo (`<saida.txt>`).
3. `./scripts/task-status.sh <N> done` e commit (`Marca #<N> como done no roadmap`). O roadmap
   guarda o destino: a linha já entra na `main` como `done` junto com o PR.
4. `git push -u origin task/<N>-<slug>`.
5. PR ainda não existe:
   `./scripts/open-pr.sh <N> --summary-file <resumo.md> --tests-file <saida.txt> [--prints "n/a: <motivo>"] [--coauthor "Nome <email>"]`.
   O script monta o corpo pelo template (`Closes #N`, `**Head:**`, Tipo, resumo, ACs, testes,
   prints da `pr-assets` que valem para o head, Registro), grava o número do PR no roadmap num
   commit seguinte (só `docs/roadmap.md`), dá push e atualiza o `**Head:**`.
   PR já existe e está aberto (`pr=<P>`, `pr_state=open`): `./scripts/open-pr.sh --update <P>`,
   sem o usuário informar nada.
6. Leia o head final: `git rev-parse HEAD`.
7. Pare.

## Onde parar

Com o PR aberto ou atualizado e o head no corpo. Passe:
- o link do PR e o head (40 caracteres);
- o comando de merge pronto, travado nesse head:
  `./scripts/merge.sh <pr> <head>`
  (o mesmo que `gh api -X PUT repos/{owner}/{repo}/pulls/<pr>/merge -f merge_method=squash -f sha=<head>`);
- o próximo passo: `/revisar` (opcional) e o merge, que é do usuário.

## Nunca

- Fazer o merge: ele é sempre do usuário.
- Abrir o PR com testes inventados: é a saída real ou `n/a: <motivo>`.
- Citar prints que não valem para o head (código mudou depois deles): rode `/qa` de novo ou
  passe `--prints "n/a: <motivo>"`.
- Dar push na `main`.
- Chutar a task quando o `task-atual.sh` devolve mais de um candidato, ou trocar de branch com a
  árvore suja.
- Abrir um segundo PR para uma issue que já tem PR (aberto: atualize; mergeado ou fechado: pare).
