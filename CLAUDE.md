# Processo de trabalho

A documentação vive em `docs/`. Leia `docs/README.md` e `docs/overview.md` antes de qualquer task.

## Ao pedir "próxima task" ou "implemente a task NNN"

1. Pegue a primeira task `todo` em `docs/roadmap.md` (ou a NNN pedida). Nunca pule a ordem sem eu pedir.
2. Antes de começar, se a task anterior está `review` e o PR dela já foi mergeado:
   `git switch main && git pull`, depois marque-a como `done` no roadmap, com o número do PR.
3. Leia `docs/tasks/NNN-*.md` e os ADRs e docs de design que ela cita.
4. Crie a issue de registro:
   `gh issue create --title "NNN · <título>" --body "Spec: docs/tasks/NNN-<slug>.md" --milestone "<milestone>"`
5. Crie a branch a partir da main atualizada: `git switch -c task/NNN-<slug>`
6. Marque a task como `doing` no roadmap e no frontmatter, com o número da issue.
7. Implemente seguindo os critérios de aceite. Não faça nada fora do escopo.
8. Faça commits locais. NÃO dê push e NÃO abra PR.
9. Pare e me diga: o que mudou, como testar cada CA e o que ficou em aberto.

## Ao pedir "teste você também" (opcional)

1. Rode o app e verifique cada critério de aceite.
2. Siga `docs/qa/print-rules.md` e tire um print por CA.
3. Salve em `task-NNN/` na branch `pr-assets`, usando o worktree `../<repo>-assets`
   (crie com `git worktree add ../<repo>-assets pr-assets` se não existir).
   Faça push só da branch `pr-assets`.
4. Marque `prints: true` no frontmatter da task.
5. Me diga quais CAs passaram e quais falharam, com os caminhos dos prints.

## Ao pedir "pode abrir o PR"

1. Preencha a seção Registro do arquivo da task.
2. Mude o status para `review` no roadmap e no frontmatter.
3. Commit dessa atualização de docs na mesma branch.
4. `git push -u origin task/NNN-<slug>`
5. `gh pr create` com título `NNN · <título>` e corpo seguindo `.github/pull_request_template.md`:
   - `Closes #<issue>`
   - Spec: `docs/tasks/NNN-<slug>.md`
   - Resumo do que entrou
   - Prints (se houver): `![CA-1](https://github.com/<owner>/<repo>/blob/pr-assets/task-NNN/<arquivo>.png?raw=true)`
6. Me passe o link do PR.

O merge (squash) é sempre feito por mim.

## Ao pedir "importe meus docs"

Siga a skill `.claude/skills/importar-docs/SKILL.md`: pergunte o que é cada doc,
apresente o plano, ajuste com o usuário e só execute depois da aprovação.

Mapa do que vai para onde:

| Material | Destino |
|---|---|
| Resumo do projeto, stack, arquitetura, glossário | `docs/overview.md` |
| Visão, público, escopo, prioridades (MoSCoW) | `docs/prd.md` |
| Milestones e ordem de entrega | `docs/roadmap.md` |
| Funcionalidade ou trabalho a construir | `docs/tasks/NNN-<slug>.md` + linha no roadmap |
| Decisão técnica (escolha de stack, padrão, trade-off) | `docs/adr/NNNN-<slug>.md` |
| Cores, tipografia, espaçamento, componentes | `docs/design/design-system.md` e `tokens.json` |
| Tela aprovada, mockup | `docs/assets/screens/` |
| Referência visual, logo, moodboard | `docs/assets/design/` |
| Regras de teste e prints | `docs/qa/print-rules.md` |

Regras de importação:

- Não invente conteúdo. O que faltar para preencher o template vira `TODO: <o que falta>`.
- Use os templates (`_template.md`) e mantenha o frontmatter.
- Tasks e ADRs recebem o próximo número livre. Tasks importadas entram como `todo`.
- ADR importado entra como `proposed`, a menos que eu diga que já está aceito.
- Milestone novo entra no `roadmap.md`, na tabela do `prd.md` e na lista do `scripts/bootstrap.sh`.
- Um doc pode virar vários destinos; vários docs podem virar um. Trechos sem destino, pergunte.
- Commit local único, sem push.

## Regras gerais

- Decisão técnica nova e duradoura → proponha um ADR em `docs/adr/` e me pergunte antes de criar.
- Mudou comportamento descrito em `docs/`? Atualize o doc no mesmo commit.
- Nunca dê push na `main`.
- Task nova pedida no meio do caminho: crie o arquivo em `docs/tasks/` com o próximo número livre
  e insira a linha no roadmap na posição que eu indicar.
