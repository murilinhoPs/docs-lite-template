# Processo de trabalho

| O quê | Onde | Pergunta que responde |
|---|---|---|
| Visão, escopo, features | `docs/prd.md` | O que o produto é e por quê |
| Comportamento atual de cada feature | `docs/specs/<feature>.md` | Como funciona **hoje** |
| Decisões | `docs/adr/` | Por que foi feito assim |
| Trabalho a fazer | **Issues do GitHub** | O que falta mudar |
| Ordem de execução e status | `docs/roadmap.md` | O que vem agora |
| Visualização | Board do Projects | Espelho do roadmap |

A spec descreve o presente, nunca planos. A issue descreve a mudança. Um PR que muda
comportamento atualiza a spec no mesmo PR.

Leia `docs/README.md` e `docs/overview.md` antes de qualquer task.

`docs/roadmap.md` é a referência de ordem e status (as sessões na nuvem não leem o Projects).
O board é só um espelho, sincronizado pelo Action `.github/workflows/sync-board.yml` (no PR, no
merge e quando a label `status:doing` muda). Nunca mova cards no board à mão: o próximo sync desfaz.

O número da issue é o ID da task: branch `task/<N>-<slug>`, prints em `pr-assets/issue-<N>/`.

## GitHub: só REST com escopo do repo

Nunca use os subcomandos `issue create/edit/view`, `pr create` nem `repo view` do gh (nem
`gh project` fora do `sync-board.sh`): use os scripts ou `gh api repos/{owner}/{repo}/...`.
Nas sessões na nuvem não há GraphQL.

| Para | Use |
|---|---|
| Ler uma issue | `gh api repos/{owner}/{repo}/issues/<N>` |
| Criar uma issue (e a linha no roadmap) | `./scripts/new-issue.sh --title ... --body-file ... --milestone ... --labels ... [--after <N>]` |
| Pôr no roadmap uma issue que já existe | `./scripts/new-issue.sh --existing <N> [--after <N>]` |
| Mudar status | `./scripts/task-status.sh <N> <todo\|doing\|review\|done>` |
| Abrir o PR | `./scripts/open-pr.sh <N> --summary-file <arquivo> ...` |
| Atualizar Head e prints do PR depois de um push | `./scripts/open-pr.sh --update <pr>` |
| Ler um PR / os checks do head | `gh api repos/{owner}/{repo}/pulls/<pr>` / `gh api repos/{owner}/{repo}/commits/<head>/check-runs` |
| Postar um review | `gh api repos/{owner}/{repo}/pulls/<pr>/reviews -f commit_id=<head> -f event=COMMENT -F body=@review.md` |
| Listar labels | `gh api repos/{owner}/{repo}/labels -q '.[].name'` |

Só rode `./scripts/sync-board.sh` se `scripts/board.conf` existir e `gh project list` funcionar
(Claude Code local); senão o Action sincroniza. O `task-status.sh` já faz essa checagem e roda o
sync quando dá.

## Ao pedir "próxima task" ou "implemente a issue N"

1. Pegue a primeira linha `todo` do roadmap (ou a issue N pedida). Nunca pule a ordem sem eu pedir.
   Se a linha anterior está `review` e o PR dela já foi mergeado: `git switch main && git pull`
   e `./scripts/task-status.sh <anterior> done` (grava também o número do PR mergeado na coluna PR;
   essa mudança vai no primeiro commit da branch nova).
2. Leia a issue (`gh api repos/{owner}/{repo}/issues/<N>`), a spec citada em **Spec:** e os ADRs
   e docs de design citados.
3. Se a issue citar um AC que não existe na spec, pare e me pergunte.
4. Crie a branch a partir da main atualizada: `git switch -c task/<N>-<slug>`.
   Marque `doing`: `./scripts/task-status.sh <N> doing` (roadmap + label `status:doing`, que
   leva o card para `doing` no board antes de a branch subir).
5. Implemente seguindo os critérios de aceite. Não faça nada fora do escopo.
6. Se o comportamento mudou, atualize a spec (Resumo, Estados, Ações, AC vigentes) e o `updated:`.
7. Faça commits locais. NÃO dê push e NÃO abra PR.
8. Pare e me diga: o que mudou, como testar cada AC e o que ficou em aberto.

## Ao pedir "teste você também" (opcional)

PR só de docs (`./scripts/docs-only.sh`: tudo em `docs/` ou `*.md`, exceto o `CLAUDE.md`)
dispensa este passo e os prints.

1. Rode o app e verifique cada critério de aceite.
2. Siga `docs/qa/print-rules.md` e tire um print por AC.
3. Salve em `issue-<N>/<sha7>/` na branch `pr-assets` (`<sha7>` = `git rev-parse --short=7 HEAD`
   da branch da task), usando o worktree `../<repo>-assets`
   (crie com `git worktree add ../<repo>-assets pr-assets` se não existir).
   Junto, gere `print_sizes.txt` no formato de `docs/qa/print-rules.md`. Testou de novo depois
   de uma correção? Pasta nova, com o sha novo; não sobrescreva a anterior.
   Faça push só da branch `pr-assets`.
4. Me diga quais AC passaram e quais falharam, com os caminhos dos prints.

## Ao pedir "pode abrir o PR"

1. `./scripts/task-status.sh <N> review` (tira a label `status:doing`) e commit na mesma branch.
2. `git push -u origin task/<N>-<slug>`
3. `./scripts/open-pr.sh <N> --summary-file <resumo.md> [--tests-file <saida.txt> | --tests "n/a: <motivo>"] [--prints "n/a: <motivo>"] [--coauthor "Nome <email>"]`.
   O script monta o corpo pelo `.github/pull_request_template.md`: `Closes #N`, spec (e se ela
   mudou na branch), **Head** de 40 caracteres, **Tipo** (código / só docs, pelo diff), resumo,
   AC da issue, testes, pasta de prints do head (`pr-assets/issue-<N>/<sha7>/`, se existir),
   Registro e, com `--coauthor`, a linha `Co-authored-by:` como última linha. Ele não faz commit
   depois de abrir o PR: o head do PR é o commit aprovado. Imprime a URL.
4. Me passe o link do PR.

O merge (squash) é sempre feito por mim. O commit na `main` fica `<título do PR> (#M)`, com o
corpo do PR como mensagem (por isso o `Co-authored-by:` precisa ser a última linha).

## Depois que o PR está aberto

O "pode abrir o PR" aprova um head. Os checks obrigatórios `ci` e `pr-gate` precisam estar verdes
nesse head, e a branch precisa estar atualizada com a `main`.

- Todo push num PR aberto é seguido de `./scripts/open-pr.sh --update <pr>`, que reescreve o
  **Head** e a pasta de prints no corpo. Se o push mudou código, me avise que o meu teste (e os
  prints, se houver) precisa ser refeito; o `pr-gate` falha enquanto os prints forem de outro commit.
- Se o GitHub indicar que a branch está atrás da `main`: `git fetch origin main`,
  `git rebase origin/main`, `git push --force-with-lease`, `./scripts/open-pr.sh --update <pr>` e
  me avise (o head mudou, então vale o item acima). Conflito no rebase: pare e me pergunte.
- `pr-gate` vermelho: leia a mensagem do check (ela diz o que fazer) e corrija; não contorne.

## Ao pedir "revise o PR"

1. Leia só o diff real do head atual: `git fetch origin main <branch>` e
   `git diff origin/main...<head>`, com `<head>` = `head.sha` de `gh api repos/{owner}/{repo}/pulls/<pr>`.
   Leia também a issue, a spec e os ADRs citados.
2. Verifique:
   - cada AC da issue tem código e teste correspondentes;
   - a spec foi atualizada se o comportamento mudou;
   - `pr-gate` e `ci` estão verdes no head (`gh api repos/{owner}/{repo}/commits/<head>/check-runs`);
   - em PR visual (`type:design` ou com prints), abra cada print e confira o conteúdo contra os
     AC, não só o tamanho.
3. Classifique cada achado:
   - **Bloqueante:** impede o merge. Diga o que corrigir, por quê e em quais arquivos. A correção
     vai no mesmo PR; depois do push, o review é refeito.
   - **Deveria:** melhoria que não bloqueia. Vira issue de follow-up só se eu pedir.
   - **Nit:** estilo ou detalhe. Só é reportado.
4. Poste o review travado no head:
   `gh api repos/{owner}/{repo}/pulls/<pr>/reviews -f commit_id=<head> -f event=COMMENT -F body=@review.md`.
   Sempre `event=COMMENT`: o GitHub não deixa o autor aprovar o próprio PR, e quem decide o merge
   sou eu.
5. Me resuma: N bloqueantes, N deveria, N nits, e se você recomenda o merge.

Push novo depois de um review: o review antigo deixa de valer; refaça só se eu pedir.

## Task nova pedida no meio do caminho

1. Se for feature, escreva os AC novos na spec primeiro (próximo ID livre da feature).
2. Crie a issue com o corpo de `docs/prompts/issue-feature.md` (bug: `issue-bug.md`) e insira a
   linha no roadmap na posição que eu indicar:
   `./scripts/new-issue.sh --title "[feat] ..." --body-file <corpo.md> --milestone "<milestone>" --labels "type:feature,area:<x>" --after <issue>`.
3. Bug reportado numa issue `type:bug`: se for da task em andamento, corrija nela; senão, ponha a
   issue no roadmap (`./scripts/new-issue.sh --existing <N>`) e pergunte onde ela entra na ordem.

## Issues

- Título: `[feat] <título>`, `[bug] <título>`, `[chore] <título>` ou `[docs] <título>`.
- Corpo: `docs/prompts/issue-feature.md` (mesmo formato do form `.github/ISSUE_TEMPLATE/feature.yml`),
  `docs/prompts/issue-bug.md` ou, para setup, `docs/prompts/issue-setup.md`.
- AC novo nasce na spec, com o próximo ID livre daquela feature (`AC-F<n>-NN`), e a issue o
  referencia. AC removido não reaproveita o ID.
- Labels: `type:*` sempre (`type:design` = mudança visual, exige prints); `prio:*` só se eu pedir;
  `area:*` conforme as que existirem no repo. Não crie labels novas sem perguntar.
  A label `status:doing` é controlada pelo `task-status.sh`; não a use à mão.
- Issue "fila" (opcional): uma issue `type:chore` que lista trabalho que depende de algo que não
  temos (ex.: Mac/iOS). Quando um AC ou print não puder ser feito por isso, o PR diz
  `n/a: <motivo> — #<fila>` e o item vai para a lista da fila.

## Ao pedir "importe meus docs"

Siga a skill `.claude/skills/importar-docs/SKILL.md`: pergunte o que é cada doc,
apresente o plano, ajuste com o usuário e só execute depois da aprovação.

Mapa do que vai para onde:

| Material | Destino |
|---|---|
| Resumo do projeto, stack, arquitetura, glossário | `docs/overview.md` |
| Visão, público, escopo, prioridades (MoSCoW), lista de features | `docs/prd.md` (features ganham IDs `F<n>`) |
| Como uma feature funciona (telas, estados, regras, AC) | `docs/specs/<feature>.md` |
| Funcionalidade ou trabalho a construir | **issue** + linha no `docs/roadmap.md` |
| Milestones e ordem de entrega | `docs/roadmap.md` (+ milestones no GitHub) |
| Decisão técnica (escolha de stack, padrão, trade-off) | `docs/adr/NNNN-<slug>.md` |
| Cores, tipografia, espaçamento, componentes | `docs/design/design-system.md` e `tokens.json` |
| Tela aprovada, mockup | `docs/assets/screens/` |
| Referência visual, logo, moodboard | `docs/assets/design/` |
| Regras de teste e prints | `docs/qa/print-rules.md` |

Regras de importação:

- Não invente conteúdo. O que faltar para preencher o template vira `TODO: <o que falta>`;
  ambiguidade numa spec vira `> Pendente: <pergunta>`.
- Use os templates (`docs/specs/_template.md`, `docs/adr/_template.md`) e mantenha o frontmatter.
- ADRs recebem o próximo número livre e entram como `Proposta`, a menos que eu diga que já
  estão aceitos. Atualize o índice em `docs/adr/README.md`.
- Milestone novo entra no `roadmap.md`, na tabela do `prd.md` e na lista do `scripts/bootstrap.sh`;
  no GitHub, crie com `gh api repos/{owner}/{repo}/milestones -f title="<milestone>"`.
- Um doc pode virar vários destinos; vários docs podem virar um. Trechos sem destino, pergunte.
- Issues só são criadas depois da aprovação do plano (o plano mostra título, milestone, labels e
  AC de cada uma), com `./scripts/new-issue.sh`, na ordem do roadmap. Elas entram como `todo`.
- Commit local único, sem push.

## Regras gerais

- Decisão técnica nova e duradoura → proponha um ADR (`Proposta`) em `docs/adr/` e me pergunte
  antes de criar. ADR `Aceita` não é editado: um novo ADR o substitui (`Superada por NNNN`).
- Mudou comportamento? Atualize a spec no mesmo commit.
- Versão do PRD é uma git tag `prd-vX.Y`; nunca escreva sha ou versão no texto dos docs.
- Nunca dê push na `main`.
