# Processo de trabalho

| O quê | Onde | Pergunta que responde |
|---|---|---|
| Visão, escopo, features | `docs/prd.md` | O que o produto é e por quê |
| Comportamento atual de cada feature | `docs/specs/<feature>.md` | Como funciona **hoje** |
| Decisões | `docs/adr/` | Por que foi feito assim |
| Trabalho a fazer | **Issues do GitHub** | O que falta mudar |
| Ordem de execução e status | `docs/roadmap.md` | O que vem agora |
| Visualização | Board do Projects | Espelho do roadmap + andamento no GitHub |

A spec descreve o presente, nunca planos. A issue descreve a mudança. Um PR que muda
comportamento atualiza a spec no mesmo PR.

Leia `docs/README.md` e `docs/overview.md` antes de qualquer task.

O número da issue é o ID da task: branch `task/<N>-<slug>`, prints em `pr-assets/issue-<N>/<sha7>/`.

## Fases → comandos

Cada fase tem um comando em `.claude/commands/`, com papel, passos, onde parar e o que nunca fazer.
Siga o comando; as frases ao lado continuam valendo e levam ao mesmo comando.

| Fase | Comando | Frase | Para quando |
|---|---|---|---|
| Planejar um milestone | `/planejar <milestone>` | "planeje o M1" | PR de planejamento aberto |
| Implementar | `/implementar [issue]` | "próxima task", "implemente a issue N" | commits locais, antes do push |
| Testar | `/qa [issue]` | "teste você também" | prints na `pr-assets` e relatório |
| Abrir o PR | `/abrir-pr [issue]` | "pode abrir o PR" | PR aberto com o head no corpo |
| Revisar | `/revisar [pr]` | "revise o PR" | review postado (subagente `revisor`) |
| Corrigir | `/corrigir [pr ou issue]` | "corrija" | correções commitadas (e enviadas) |
| Fechar | `/fechar [pr]` | "fechei o merge", "feche a task" | board, nits e milestone atualizados |

Importar docs que já existem: skill `.claude/skills/importar-docs/SKILL.md` ("importe meus docs").

## Status: o roadmap guarda o destino, o GitHub mostra o andamento

- O roadmap tem três status: `todo`, `doing` e `done`. O `/implementar` marca `doing`; o
  `/abrir-pr` já marca `done`, porque é o estado que a linha terá quando o PR entrar na `main`
  (assim nenhuma task precisa de um segundo PR). Mude status só com `./scripts/task-status.sh`.
- O board é um espelho calculado pelo `./scripts/sync-board.sh`: issue fechada → `done`; PR
  aberto com `Closes #N` → `review`; roadmap `doing` ou `done` sem PR → `doing`; senão `todo`.
  Nunca mova cards à mão: o próximo sync desfaz.
- O sync usa `gh project`, então só roda onde o board é acessível (Claude Code local). Os
  comandos rodam `./scripts/sync-board.sh --auto`: sem acesso, ele avisa e segue.

## Merge gate

- O PR aprova um head. Os checks obrigatórios `ci` e `pr-gate` precisam estar verdes nesse head,
  com a branch atualizada com a `main`. O `pr-gate` exige o `**Head:**` do corpo igual ao head e
  prints de um commit cujo código é o do head (depois deles, só docs podem ter mudado).
- Todo push num PR aberto é seguido de `./scripts/open-pr.sh --update <pr>`. Se o push mudou
  código, avise que o teste do usuário (e os prints) precisa ser refeito.
- Branch atrás da `main`: `git fetch origin main`, `git rebase origin/main`,
  `git push --force-with-lease`, `./scripts/open-pr.sh --update <pr>` e avise (o head mudou).
  Conflito no rebase: pare e pergunte.
- O merge é sempre do usuário, travado no head: `./scripts/merge.sh <pr> <head>`.
  Os comandos que deixam o PR pronto mostram esse comando com o head atual.
- PR só de docs (`./scripts/docs-only.sh`: tudo em `docs/` ou `*.md`, exceto este arquivo)
  dispensa prints e QA.

## GitHub: só REST com escopo do repo

Nunca use os subcomandos `issue create/edit/view`, `pr create`, `pr merge` nem `repo view` do gh:
use os scripts ou `gh api repos/{owner}/{repo}/...`. A única exceção é o `sync-board.sh`, que
usa `gh project` e só roda onde o board é acessível.

| Para | Use |
|---|---|
| Ler uma issue / um PR | `gh api repos/{owner}/{repo}/issues/<N>` / `gh api repos/{owner}/{repo}/pulls/<pr>` |
| Criar uma issue (e a linha no roadmap) | `./scripts/new-issue.sh --title ... --body-file ... --milestone ... --labels ... [--after <N>]` |
| Pôr no roadmap uma issue que já existe | `./scripts/new-issue.sh --existing <N> [--after <N>]` |
| Mudar status | `./scripts/task-status.sh <N> <todo\|doing\|done>` |
| Abrir o PR / atualizar Head e prints | `./scripts/open-pr.sh <N> ...` / `./scripts/open-pr.sh --update <pr>` |
| Ver os checks do head | `gh api repos/{owner}/{repo}/commits/<head>/check-runs` |
| Comentar no PR | `gh api repos/{owner}/{repo}/issues/<pr>/comments -F body=@<arquivo>` |
| Merge travado no head | `./scripts/merge.sh <pr> <head>` |
| Listar labels | `gh api repos/{owner}/{repo}/labels -q '.[].name'` |

## Issues

- Título: `[feat] <título>`, `[bug] <título>`, `[chore] <título>` ou `[docs] <título>`.
- Corpo: `docs/prompts/issue-feature.md` (mesmo formato do form `.github/ISSUE_TEMPLATE/feature.yml`),
  `docs/prompts/issue-bug.md` ou, para setup, `docs/prompts/issue-setup.md`.
- AC novo nasce na spec, com o próximo ID livre daquela feature (`AC-F<n>-NN`), pelo `/planejar`,
  e a issue o referencia. AC removido não reaproveita o ID.
- Labels: `type:*` sempre (`type:design` = mudança visual, exige prints); `prio:*` só se o usuário
  pedir (e `prio:baixa` nos nits aprovados no `/fechar`); `area:*` conforme as que existirem no repo.
  Não crie labels novas sem perguntar.
- Task nova pedida no meio do caminho: proposta pelo `/planejar` (ACs na spec + issue + linha no
  roadmap na posição indicada, com `--after`).
- Bug reportado numa issue `type:bug`: se for da task em andamento, corrija nela (`/corrigir`);
  senão, ponha a issue no roadmap (`./scripts/new-issue.sh --existing <N>`) e pergunte onde entra.
- Issue "fila" (opcional): uma issue `type:chore` que lista trabalho que depende de algo que não
  temos (ex.: Mac/iOS). Quando um AC ou print não puder ser feito por isso, o PR diz
  `n/a: <motivo> — #<fila>`.

## Importação de docs

A skill `importar-docs` pergunta o que é cada doc, apresenta o plano e só executa depois da
aprovação. As issues saem como no `/planejar`: proposta → aprovação → specs + issues + roadmap
num PR de docs.

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

- Não invente conteúdo. O que faltar vira `TODO: <o que falta>`; ambiguidade numa spec vira
  `> Pendente: <pergunta>`.
- Use os templates (`docs/specs/_template.md`, `docs/adr/_template.md`) e mantenha o frontmatter.
- ADRs recebem o próximo número livre e entram como `Proposta`, a menos que o usuário diga que já
  estão aceitos. Atualize o índice em `docs/adr/README.md`.
- Milestone novo entra no `roadmap.md`, na tabela do `prd.md` e na lista do `scripts/bootstrap.sh`;
  no GitHub, crie com `gh api repos/{owner}/{repo}/milestones -f title="<milestone>"`.
- Um doc pode virar vários destinos; vários docs podem virar um. Trechos sem destino, pergunte.

## Regras gerais

- Decisão técnica nova e duradoura → proponha um ADR (`Proposta`) em `docs/adr/` e pergunte antes
  de criar. ADR `Aceita` não é editado: um novo ADR o substitui (`Superada por NNNN`).
- Mudou comportamento? Atualize a spec no mesmo commit.
- Versão do PRD é uma git tag `prd-vX.Y`; nunca escreva sha ou versão no texto dos docs.
- Nunca dê push na `main`.
- Este arquivo também é lido como `AGENTS.md` (link simbólico) por outras ferramentas; os
  comandos de `.claude/` são só do Claude Code.
