# Processo de trabalho

A documentação vive em `docs/`. Leia `docs/README.md` e `docs/overview.md` antes de qualquer task.

`docs/roadmap.md` é a referência global: ordem, milestone e status de cada task. O board do
GitHub Projects é só um espelho dele, sincronizado pelo Action `.github/workflows/sync-board.yml`
(no PR, no merge e quando a label `status:doing` muda). Nunca mova cards no board à mão: o
próximo sync desfaz.

Sync do board: toda vez que você mudar o roadmap (task nova, status, número de issue, ordem),
rode `./scripts/sync-board.sh --auto`. Ele só sincroniza se `scripts/board.conf` existir e
`gh project list` funcionar (Claude Code local); caso contrário, sai sem fazer nada e o Action
sincroniza no PR e no merge. Nas sessões na nuvem não há GraphQL, então isso é o esperado.

## Ao pedir "próxima task" ou "implemente a task NNN"

1. Pegue a primeira task `todo` em `docs/roadmap.md` (ou a NNN pedida). Nunca pule a ordem sem eu pedir.
2. Antes de começar, se a task anterior está `review` e o PR dela já foi mergeado:
   `git switch main && git pull`, depois marque-a como `done`
   (`./scripts/set-status.sh docs/tasks/<anterior>.md done`; o número do PR já está no roadmap).
   (Essa atualização vai no primeiro commit da branch da task nova.)
3. Leia `docs/tasks/NNN-*.md` e os ADRs e docs de design que ela cita.
4. Crie (ou recupere) a issue de registro: `./scripts/create-issue.sh docs/tasks/NNN-<slug>.md`.
   Ele usa título, milestone e labels do frontmatter, grava o número no frontmatter e na coluna
   Issue do roadmap e imprime o número. Se a task já tem issue, não cria outra.
5. Crie a branch a partir da main atualizada: `git switch -c task/NNN-<slug>`
6. Marque a task como `doing`: `./scripts/set-status.sh docs/tasks/NNN-<slug>.md doing`.
   Ele muda o roadmap e o frontmatter e põe a label `status:doing` na issue (é ela que leva o
   card para `doing` no board, já que a branch ainda não subiu). Depois rode
   `./scripts/sync-board.sh --auto`.
7. Implemente seguindo os critérios de aceite. Não faça nada fora do escopo.
8. Faça commits locais. NÃO dê push e NÃO abra PR.
9. Pare e me diga: o que mudou, como testar cada CA e o que ficou em aberto.

## Ao pedir "teste você também" (opcional)

1. Rode o app e verifique cada critério de aceite.
2. Siga `docs/qa/print-rules.md` e tire um print por CA.
3. Salve em `task-NNN/` na branch `pr-assets`, usando o worktree `../<repo>-assets`
   (crie com `git worktree add ../<repo>-assets pr-assets` se não existir).
   Junto, gere `task-NNN/print_sizes.txt` no formato de `docs/qa/print-rules.md`
   (hash do commit testado + sha256 de cada print). Se você testar de novo depois de uma
   correção, substitua os prints e o `print_sizes.txt`.
   Faça push só da branch `pr-assets`.
4. Marque `prints: true` no frontmatter da task.
5. Me diga quais CAs passaram e quais falharam, com os caminhos dos prints.

## Ao pedir "pode abrir o PR"

1. Preencha a seção Registro do arquivo da task.
2. Mude o status para `review`: `./scripts/set-status.sh docs/tasks/NNN-<slug>.md review`
   (também tira a label `status:doing` da issue).
3. Commit dessa atualização de docs na mesma branch e rode `./scripts/sync-board.sh --auto`.
4. `git push -u origin task/NNN-<slug>`
5. Abra o PR com `./scripts/open-pr.sh docs/tasks/NNN-<slug>.md`, passando o resumo do que
   entrou pelo stdin (ou `--summary-file <arquivo>`) e, se houver prints, `--prints-file <arquivo>`
   com uma linha por print:
   `![CA-1](https://github.com/<owner>/<repo>/blob/pr-assets/task-NNN/<arquivo>.png?raw=true)`.
   O script usa título `NNN · <título>` e o corpo de `.github/pull_request_template.md`
   (`Closes #<issue>`, Spec, resumo, prints). Depois de criar o PR, ele grava o número na coluna
   PR do roadmap num commit seguinte na mesma branch (`NNN · registra PR #N no roadmap`), dá
   push e imprime a URL.
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
- Tasks importadas recebem `labels` no frontmatter (`type:feature` por padrão).
- Commit local único, sem push. Issues e board só depois do merge (issues com `./scripts/create-issue.sh`;
  o board é preenchido pelo Action quando o roadmap com as issues chegar à `main`).

## Regras gerais

- Decisão técnica nova e duradoura → proponha um ADR em `docs/adr/` e me pergunte antes de criar.
- Mudou comportamento descrito em `docs/`? Atualize o doc no mesmo commit.
- Nunca dê push na `main`.
- GitHub só via REST com escopo do repo: nunca chame direto os subcomandos do gh que usam GraphQL
  (criar ou editar issue, criar PR, ver o repo, `label`, `project`); use os scripts
  (`create-issue.sh`, `set-status.sh`, `open-pr.sh`) ou `gh api repos/{owner}/{repo}/...`.
  Nas sessões na nuvem o GraphQL não existe.
- Task nova pedida no meio do caminho: crie o arquivo em `docs/tasks/` com o próximo número livre
  e insira a linha no roadmap na posição que eu indicar.
- Bug reportado numa issue `type:bug`: se for da task em andamento, corrija nela; senão, crie uma
  task nova com `labels: [type:bug]` apontando para essa issue (coluna Issue do roadmap) e pergunte
  onde ela entra na ordem.
- Labels: `type:*` sempre; `prio:*` só se eu pedir; `area:*` conforme as que existirem no repo
  (`gh api repos/{owner}/{repo}/labels -q '.[].name'`). Não crie labels novas sem perguntar.
  A label `status:doing` é controlada pelo `set-status.sh`; não a use à mão.
