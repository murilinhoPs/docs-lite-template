---
description: Planeja um milestone (PM + docs) - propõe issues, ACs e mudanças de spec e, depois da aprovação, abre o PR de planejamento
argument-hint: <milestone>
---

# /planejar $ARGUMENTS

## Papel

PM + docs. Transforma o PRD e as specs em issues ordenadas para o milestone. Não escreve código.

## Argumentos

`$ARGUMENTS` = o milestone (ex.: `M1 MVP` ou só `M1`). Obrigatório: sem ele, pergunte.

## Passos

1. Confira `docs/preparo.md`: se a `fase` não for `pronto` (com o PR de preparo mergeado), pare e
   sugira `/preparar`. Itens `trava` que ficaram `parcial` por `> Pendente:`: as issues que
   dependem deles ficam para depois (diga quais).
   Leia `docs/prd.md` (tabela Features), as specs em `docs/specs/`, os ADRs e o `docs/roadmap.md`.
2. Proponha, **sem criar nada**:
   - as issues do milestone, na ordem: título (`[feat] ...`, `[chore] ...`), área, spec, labels
     (`type:*`, `area:*`), ACs (IDs `AC-F<n>-NN`) e posição no roadmap;
   - para feature nova ou AC que ainda não existe na spec, o texto dos ACs novos (próximo ID
     livre da feature) e das seções de spec que mudam;
   - os itens `> Pendente:` que precisam da decisão do usuário.
3. Pare e espere a aprovação. Ajuste a proposta até o "pode seguir".
4. Depois da aprovação:
   1. `git switch main && git pull` e `git switch -c plan/<milestone-slug>`.
   2. Escreva ou atualize as specs (e o `prd.md`, se surgir feature nova). Milestone que não
      existe no GitHub: `gh api repos/{owner}/{repo}/milestones -f title="<milestone>"`, e
      acrescente-o ao `roadmap.md`, ao `prd.md` e à lista do `scripts/bootstrap.sh`.
   3. Crie cada issue, na ordem, com o corpo no formato de `docs/prompts/issue-feature.md`:
      `./scripts/new-issue.sh --title "[feat] ..." --body-file <corpo.md> --milestone "<milestone>" --labels "type:feature,area:<x>" [--after <issue>]`.
      O script cria a issue e insere a linha no roadmap com status `todo`.
   4. Commit (`docs: planejamento <milestone>`) e `git push -u origin plan/<milestone-slug>`.
   5. Abra o PR só de docs pelo template (`.github/pull_request_template.md`, sem `Closes`,
      `**Tipo:** só docs`, prints e testes `n/a: PR só de docs`):
      `gh api repos/{owner}/{repo}/pulls -f head=plan/<milestone-slug> -f base=main -f title="[docs] Planejamento <milestone>" -F body=@<corpo.md>`
      e depois `./scripts/open-pr.sh --update <pr>` para gravar o `**Head:**` (o `pr-gate` exige).
   6. `./scripts/sync-board.sh --auto` (sem board acessível, ele avisa e segue).
5. Pare.

## Onde parar

- Depois da proposta (passo 3), esperando a aprovação.
- Com o PR de planejamento aberto: passe o link do PR, a lista de issues criadas (número,
  título, posição) e o comando de merge (`./scripts/merge.sh <pr> <head>`).

## Nunca

- Criar issue, branch ou arquivo antes da aprovação.
- Inventar requisito: o que falta vira `> Pendente:` ou `TODO:`.
- Reaproveitar ID de feature (`F<n>`) ou de AC removido.
- Misturar código no PR de planejamento. Ajustes de spec durante uma task vão no PR da task.
- Dar push na `main`.
