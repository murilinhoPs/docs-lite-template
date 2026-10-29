---
description: Abre (ou atualiza) o PR da issue com o head no corpo e mostra o comando de merge travado no head
argument-hint: "[issue]"
---

# /abrir-pr $ARGUMENTS

## Papel

Dev. Entrega a branch da task como PR, com o head aprovado no corpo.

## Argumentos

`$ARGUMENTS` = número da issue (opcional). Sem argumento: a da branch atual (`task/<N>-...`).

## Passos

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
   PR já existe: `./scripts/open-pr.sh --update <pr>`.
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
