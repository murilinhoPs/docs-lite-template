# Processo de trabalho

Este arquivo e `.claude/commands/` são a fonte do processo. Guias, tutoriais ou docs fora do repo
são resumos para pessoas; se divergirem, vale o que está aqui.

| O quê | Onde | Pergunta que responde |
|---|---|---|
| Visão, escopo, features | `docs/prd.md` | O que o produto é e por quê |
| Comportamento atual de cada feature | `docs/specs/<feature>.md` | Como funciona **hoje** |
| Decisões | `docs/adr/` | Por que foi feito assim |
| Trabalho a fazer | **Issues do GitHub** | O que falta mudar |
| Milestones (visão geral) e ordem e status das issues | `docs/roadmap.md` | O que vem agora |
| Plano do milestone em andamento | `docs/milestones/m<n>.md` | O que entra neste milestone |
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
| Preparar os docs | `/preparar [pasta]` | "importe meus docs", "prepare o projeto" | `docs/preparo.md` em `fase: pronto` e PR de docs aberto (sem nada em `_import/` e com os docs no template, ele avisa e espera os arquivos, que podem vir no chat) |
| Planejar: visão geral | `/planejar` | "planeje o roadmap" | PR `[docs] Roadmap: visão geral` aberto |
| Planejar: um milestone | `/planejar M<n>` | "planeje o M1" | PR `[docs] Planejar M<n>` aberto, issues criadas |
| Implementar | `/implementar [issue]` | "próxima task", "implemente a issue N" | commits locais, antes do push |
| Testar | `/qa [issue]` | "teste você também" | prints na `pr-assets` e relatório |
| Abrir o PR | `/abrir-pr [issue]` | "pode abrir o PR" (sem precisar do número: descobre pelo `task-atual.sh`) | PR aberto ou atualizado, com o head no corpo |
| Revisar | `/revisar [pr \| local]` | "revise o PR", "revise localmente" | modo PR: review postado (subagente `revisor`); modo local (sem PR): review só na conversa |
| Corrigir | `/corrigir [pr ou issue]` | "corrija" | correções commitadas (e enviadas) |
| Fechar | `/fechar [pr]` | "fechei o merge", "feche a task" | board e nits atualizados; no fim do milestone, critério de saída e go/no-go |

Fluxo: `/preparar` → merge → `/planejar` (visão geral) → merge → `/planejar M0` → merge → ciclo das
tasks do M0 → `/fechar` (go/no-go) → `/planejar M1` → ciclo → `/fechar` → `/planejar M2` …

Ciclo de uma task: `/implementar` → seu teste → `/revisar local` (opcional) → `/abrir-pr` →
`/revisar` → merge → `/fechar`.

## Em outros agentes

O `AGENTS.md` aponta para este arquivo. Para agentes sem os recursos do Claude Code:

- **Sem slash commands:** quando o usuário pedir `/<comando> [args]` (ou a frase equivalente da
  tabela acima), abra `.claude/commands/<comando>.md` e siga o arquivo inteiro, com
  `$ARGUMENTS` = os args. Ignore o frontmatter (`description`, `argument-hint`, `allowed-tools`, `model`).
- **Sem subagentes:** o `/revisar` deve rodar numa sessão nova (ou com outro modelo), seguindo
  `.claude/agents/revisor.md` só com leitura, para o review ter contexto limpo. Na mesma sessão
  que implementou, avise o usuário e não poste o review.

| Agente | Onde lê as regras | Como chamar um comando |
|---|---|---|
| Claude Code | `CLAUDE.md` | slash command (`/implementar`) ou a frase da tabela |
| Codex, opencode, Hermes, Cursor… | `AGENTS.md` → `CLAUDE.md` | pedir "siga `.claude/commands/<x>.md`", ou cadastrar esses arquivos como prompts da ferramenta |

## Planejamento em duas etapas

- **Etapa 1, visão geral** (`/planejar`): a seção Milestones do `roadmap.md` lista todos os
  milestones (`M<n> — <nome>`: objetivo, escopo em `F#`, critério de saída, dependências,
  tamanho), sem tasks e sem nada no GitHub. O M0 é sempre **Fundação e spike**, com go/no-go.
- **Etapa 2, um milestone** (`/planejar M<n>`): só quando ele é o próximo (o anterior encerrado),
  escreve `docs/milestones/m<n>.md`, cria o milestone no GitHub e as issues, num PR de docs.
- **Nunca existem issues, nem milestone no GitHub, de milestones futuros.** O `bootstrap.sh` cria
  só o M0; os outros nascem no `/planejar M<n>`.
- O material importado sobre fases, ordem de entrega e trabalho a fazer passa do `/preparar` para
  o `/planejar` pela seção "Para o /planejar" do `docs/preparo.md` (registro, não decisão).
- Uma feature `F#` entra em no máximo um milestone; features `Won't` ficam fora. Milestone novo
  entra só no `roadmap.md` (etapa 1) e no GitHub (etapa 2); o PRD aponta para o roadmap.

## Status: o roadmap guarda o destino, o GitHub mostra o andamento

- O roadmap tem três status: `todo`, `doing` e `done`. O `/implementar` marca `doing`; o
  `/abrir-pr` já marca `done`, porque é o estado que a linha terá quando o PR entrar na `main`
  (assim nenhuma task precisa de um segundo PR). Mude status só com `./scripts/task-status.sh`.
- O board é um espelho calculado pelo `./scripts/sync-board.sh`: issue fechada → `done`; PR
  aberto com `Closes #N` → `review`; roadmap `doing` ou `done` sem PR → `doing`; senão `todo`.
  Nunca mova cards à mão: o próximo sync desfaz.
- O sync usa `gh project`, então só roda onde o board é acessível (Claude Code local). Os
  comandos rodam `./scripts/sync-board.sh --auto`: sem acesso, ele avisa e segue.
- Se `scripts/board.conf` tem `BOARD=nao`, não existe board: não tente criá-lo nem sincronizá-lo
  (o sync diz "nada a sincronizar" e segue). Veja "Board → Sem board" no `README.md`.

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
| Criar um milestone (etapa 2) | `./scripts/new-milestone.sh "M<n> — <nome>"` |
| Criar uma issue (e a linha no roadmap) | `./scripts/new-issue.sh --title ... --body-file ... --milestone ... --labels ... [--after <N>]` |
| Pôr no roadmap uma issue que já existe | `./scripts/new-issue.sh --existing <N> [--after <N>]` |
| Mudar status | `./scripts/task-status.sh <N> <todo\|doing\|done>` |
| Abrir o PR / atualizar Head e prints | `./scripts/open-pr.sh <N> ...` / `./scripts/open-pr.sh --update <pr>` |
| Ver os checks do head | `gh api repos/{owner}/{repo}/commits/<head>/check-runs` |
| Comentar no PR | `gh api repos/{owner}/{repo}/issues/<pr>/comments -F body=@<arquivo>` |
| Merge travado no head | `./scripts/merge.sh <pr> <head>` |
| Listar labels | `gh api repos/{owner}/{repo}/labels -q '.[].name'` |
| Sincronizar o board (só onde ele é acessível) | `./scripts/sync-board.sh [--auto]` |
| Saber se o PR é só de docs | `./scripts/docs-only.sh [base] [head]` |
| Conferir Head e prints (o check `pr-gate` roda) | `GITHUB_EVENT_PATH=<evento.json> ./scripts/pr-gate.sh` |
| Configurar um projeto novo (uma vez, só local, pelo usuário) | `./scripts/bootstrap.sh` |
| Publicar este template (só no repo do template) | `./scripts/publish-template.sh [nome]` |
| Escolher a próxima task e conferir a ordem (`/implementar`) | `./scripts/next-task.sh [<N>]` |
| Saber qual é a task, a branch e o PR (`/abrir-pr`, `/revisar`) | `./scripts/task-atual.sh [<N>]` |
| Trazer as mudanças do template para um projeto antigo | `./scripts/atualiza-template.sh [--aplicar] [url]` |
| Rodar os testes dos scripts | `./scripts/test/run.sh` |

## Issues

- Título: `[feat] <título>`, `[bug] <título>`, `[chore] <título>` ou `[docs] <título>`.
- Corpo: `docs/prompts/issue-feature.md` (mesmo formato do form `.github/ISSUE_TEMPLATE/feature.yml`),
  `docs/prompts/issue-bug.md` ou, para setup, `docs/prompts/issue-setup.md`.
- AC novo nasce na spec, com o próximo ID livre daquela feature (`AC-F<n>-NN`), pelo `/planejar`,
  e a issue o referencia. AC removido não reaproveita o ID.
- Labels: `type:*` sempre (`type:design` = mudança visual, exige prints); `prio:*` só se o usuário
  pedir (e `prio:baixa` nos nits aprovados no `/fechar`); `area:*` conforme as que existirem no repo.
  Não crie labels novas sem perguntar.
- Task nova pedida no meio do caminho (feature fora do plano): proposta pelo `/planejar`, dizendo
  em qual milestone entra. No milestone em andamento: ACs na spec + issue + linha no roadmap na
  posição indicada (`--after`). Num milestone futuro: só o escopo (`F#`) na seção Milestones do
  roadmap; a issue nasce no `/planejar M<n>` dele.
- Hotfix com uma task em andamento: só quando o usuário passa a issue (`/implementar <N>`) e outra
  está `doing`. Pare e confirme; guarde a task atual num commit `wip:` local (sem push); a linha do
  hotfix vai para logo depois da última `done` (`new-issue.sh --existing <N> --after <última done>`).
  Depois do `/fechar` do hotfix, `/implementar` retoma a task interrompida (passos em
  `.claude/commands/implementar.md`).
- Bug reportado numa issue `type:bug`: se for da task em andamento, corrija nela (`/corrigir`);
  senão, ponha a issue no roadmap (`./scripts/new-issue.sh --existing <N>`) e pergunte onde entra.
- Issue "fila" (opcional): uma issue `type:chore` que lista trabalho que depende de algo que não
  temos (ex.: Mac/iOS). Quando um AC ou print não puder ser feito por isso, o PR diz
  `n/a: <motivo> — #<fila>`.

## Regras gerais

- Decisão técnica nova e duradoura → proponha um ADR (`Proposta`) em `docs/adr/` e pergunte antes
  de criar. ADR `Aceita` não é editado: um novo ADR o substitui (`Superada por NNNN`).
- Mudou comportamento? Atualize a spec no mesmo commit.
- Versão do PRD é uma git tag `prd-vX.Y`; nunca escreva sha ou versão no texto dos docs.
- Nunca dê push na `main`.
- Outras ferramentas leem o `AGENTS.md`, que manda seguir este arquivo e os comandos de
  `.claude/` (veja "Em outros agentes").
