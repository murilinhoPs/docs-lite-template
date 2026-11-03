# <Nome do projeto>

<Uma frase sobre o projeto.> Documentação completa em [docs/](docs/README.md).

## Como este repositório funciona

| O quê | Onde | Pergunta que responde |
|---|---|---|
| Visão, escopo, features | `docs/prd.md` | O que o produto é e por quê |
| Comportamento atual de cada feature | `docs/specs/<feature>.md` | Como funciona **hoje** |
| Decisões | `docs/adr/` | Por que foi feito assim |
| Trabalho a fazer | **Issues do GitHub** | O que falta mudar |
| Milestones (visão geral) e ordem e status das issues | `docs/roadmap.md` | O que vem agora |
| Plano do milestone em andamento | `docs/milestones/m<n>.md` | O que entra neste milestone |
| Visualização | Board do Projects | Espelho do roadmap + andamento no GitHub |

- **A spec descreve o presente; a issue descreve a mudança.** Um PR que muda comportamento
  atualiza a spec no mesmo PR. Features têm IDs estáveis (`F1`, `F2`…) e cada critério de aceite
  também (`AC-F2-03`).
- **O roadmap dá a ordem e guarda o destino:** cada linha é uma issue, com status `todo`, `doing`
  ou `done`. A linha já entra como `done` no PR da task, então a `main` mostra o estado real depois
  de cada merge, sem PR extra.
- **O board espelha o roadmap e o andamento:** `./scripts/sync-board.sh` calcula a Etapa (issue
  fechada → `done`, PR aberto → `review`, roadmap `doing`/`done` sem PR → `doing`, senão `todo`).
  Mude o roadmap, nunca o board.
- **Resumo do processo:** [`docs/guia.md`](docs/guia.md) explica o modelo, o fluxo, os comandos e
  os scripts numa página só.
- **Qual fonte manda:** este README é o guia para pessoas; o agente segue o [`CLAUDE.md`](CLAUDE.md)
  e os comandos de `.claude/commands/`. Guias, tutoriais ou docs fora do repo são resumos; se
  divergirem, vale o que está no `CLAUDE.md` e nos comandos.
- **O Claude Code trabalha por comandos** (`.claude/commands/`), um por fase, e segue o
  [`CLAUDE.md`](CLAUDE.md). Outras ferramentas (Codex, opencode, Hermes, Cursor) leem o
  [`AGENTS.md`](AGENTS.md), um arquivo curto que manda seguir o `CLAUDE.md` e os arquivos dos
  comandos (veja "Em outros agentes" no `CLAUDE.md`).
- **Só API REST do repositório:** os scripts (`new-issue.sh`, `task-status.sh`, `open-pr.sh`,
  `merge.sh`) usam `gh api repos/{owner}/{repo}/...` e funcionam em qualquer ambiente, inclusive
  nas sessões do Claude Code na nuvem. A exceção é o `sync-board.sh` (`gh project`).

## Comandos

Fluxo: `/preparar` → merge → `/planejar` (visão geral) → merge → `/planejar M0` → merge → ciclo das tasks do M0 → `/fechar` (go/no-go) → `/planejar M1` → ciclo → `/fechar` → `/planejar M2` ….

| Comando | Papel | Para quando |
|---|---|---|
| `/preparar [pasta]` | Analista de docs | `docs/preparo.md` em `fase: pronto` e PR de docs aberto |
| `/planejar` | PM | Visão geral dos milestones no roadmap; PR `[docs] Roadmap: visão geral` aberto |
| `/planejar M<n>` | PM + docs | Só o próximo milestone: doc, specs, milestone e issues; PR `[docs] Planejar M<n>` aberto |
| `/implementar [issue]` | Dev | Commits locais feitos, antes do push |
| `/qa [issue]` | Tester | Prints na `pr-assets` e relatório entregue |
| `/abrir-pr [issue]` | Dev | PR aberto ou atualizado, com o head no corpo |
| `/revisar [pr]` | Reviewer (subagente) | Review postado como comentário |
| `/corrigir [pr ou issue]` | Dev | Correções commitadas (e enviadas, se o PR existir) |
| `/fechar [pr]` | PM | Board, nits e milestone atualizados |

## Ciclo de uma task, em comandos

0. `/preparar` (uma vez por projeto) → inventaria o material de `_import/`, organiza em `docs/` e
   entrevista você até nada travar o planejamento; abre o PR `[docs] Preparo do projeto`.
1. `/planejar` (uma vez) → visão geral: todos os milestones no roadmap, sem issues; depois `/planejar M<n>`
   para o próximo milestone → doc do milestone, ACs nas specs e issues; você faz o merge de cada PR.
2. `/implementar` → pega a primeira issue `todo`, cria `task/<N>-<slug>`, marca `doing` e faz commits locais.
3. Você testa contra os ACs (o `/implementar` diz como).
4. `/qa` (opcional) → o Claude testa como tester e salva prints em `pr-assets/issue-<N>/<sha7>/`.
5. `/abrir-pr` → marca `done`, dá push e abre o PR com o head no corpo e o comando de merge pronto.
6. `/revisar` → o subagente `revisor` posta um review (`COMMENT`) com bloqueantes, deveria e nits.
7. `/corrigir` → corrige só o apontado, atualiza o PR e diz se você precisa testar de novo.
8. Você faz o merge (`./scripts/merge.sh <pr> <head>`) e roda `/fechar` (board e nits). Na última
   issue do milestone, o `/fechar` confere o critério de saída, fecha o milestone e, no M0, pergunta
   o go/no-go; aí vem o `/planejar M<n+1>`, cujo PR registra o encerramento (doc `encerrado` e, no
   M0, o ADR do go/no-go).

---

## Começando um projeto a partir deste template

```bash
gh repo create meu-projeto --template murilinhoPs/docs-lite-template --private --clone
cd meu-projeto
gh auth refresh -s project
./scripts/bootstrap.sh
```

Depois do bootstrap, rode `/preparar` no Claude Code (veja "Preparando o projeto") e, com o PR de
preparo mergeado, `/planejar` (visão geral) e `/planejar M0`.

O `bootstrap.sh` roda **só localmente**, com o `gh` do usuário logado: ele usa GraphQL
(`gh project`, `gh label`, `gh repo edit`), que as sessões do Claude Code na nuvem não têm.

Ele cria o que o template não copia: o milestone `M0 — Fundação e spike` (os outros nascem no
`/planejar M<n>`), labels (`type:*`, `prio:*` e as `area:*` da
tabela Features do `prd.md`), board no Projects (cópia do projeto modelo, com os campos Etapa e
Ordem e as visões; número salvo em `scripts/board.conf`), a issue `[chore] Setup do projeto` com a
linha dela no roadmap, branch `pr-assets`, worktree de prints, squash com título e corpo do PR e o
ruleset da `main`. Pode rodar de novo: ele pula o que já existe (rode de novo depois de preencher
a tabela Features, para criar as `area:*`).

O board é uma cópia do projeto modelo `murilinhoPs/2` (veja "Board → Projeto modelo").

## Board

O board é um espelho: `./scripts/sync-board.sh` copia a Ordem do roadmap e calcula a Etapa de cada
issue, nesta ordem: issue fechada → `done`; PR aberto com `Closes #N` → `review`; roadmap `doing`
ou `done` sem PR → `doing`; senão `todo`. Ele lê o roadmap da working tree, então funciona de
qualquer branch.

### Projeto modelo

O `bootstrap.sh` cria o board copiando um projeto modelo (`gh project copy`), por padrão o
[`murilinhoPs/2`](https://github.com/users/murilinhoPs/projects/2). Para usar outro:
`BOARD_TEMPLATE=<owner>/<número> ./scripts/bootstrap.sh` (`BOARD_TEMPLATE=` vazio não copia e
cria um board sem visões).

**O modelo precisa estar acessível.** A cópia só funciona se quem roda o bootstrap consegue ver
o projeto modelo. Para usar o template em outra conta, o projeto 2 precisa ser público (no
projeto: Settings → Visibility → Public), ou a pessoa cria o próprio modelo e usa
`BOARD_TEMPLATE=<owner>/<número>`. Se a cópia falhar, o bootstrap cria um board vazio (com os
campos, sem as visões) e avisa.

| A cópia traz | A cópia não traz |
|---|---|
| Visões (Board, Backlog, Roadmap, com agrupamento e ordenação) | Itens (issues, PRs e rascunhos) |
| Campos personalizados (Etapa, Ordem) | Colaboradores |
| Workflows configurados, exceto o auto-add | O link com repositórios (o bootstrap faz o `link` depois) |
| Insights | |

**O que o modelo precisa ter para o sync funcionar:**

- campo `Etapa`, single select com as opções `todo`, `doing`, `review` e `done`;
- campo `Ordem`, number;
- visões **Board** (colunas por Etapa), **Backlog** (tabela ordenada por Ordem) e **Roadmap**
  (agrupado por Milestone).

Se o modelo copiado não tiver `Ordem`, o bootstrap cria o campo e avisa. Sem `Etapa`, ele cria
com as quatro opções e avisa que as visões que dependem dela precisam ser ajustadas na interface.
Se a `Etapa` existir sem alguma das quatro opções, ele não altera o campo: só avisa quais faltam.

### Sync

O sync usa `gh project`, então só roda onde o board é acessível (Claude Code local, com
`gh auth refresh -s project`). Os comandos e o `task-status.sh` chamam `./scripts/sync-board.sh --auto`:
numa sessão na nuvem ele avisa "board não sincronizado; rode `./scripts/sync-board.sh` localmente"
e segue. Não há Action nem token para o board.

## Merge gate

A aprovação (`/abrir-pr`) vale para um head específico. O ruleset da `main`, criado pelo
`bootstrap.sh`, exige dois checks verdes no head e a branch atualizada com a `main` (strict):

| Check | Workflow | O que confere |
|---|---|---|
| `pr-gate` | [`pr-gate.yml`](.github/workflows/pr-gate.yml) → `scripts/pr-gate.sh` | O `**Head:**` do corpo do PR é o head do PR; se o corpo cita `pr-assets/issue-<N>/<sha7>/`, os prints são de um commit cujo código é o do head (depois deles, só docs mudaram) |
| `ci` | [`ci.yml`](.github/workflows/ci.yml) | Lint e testes da stack (placeholder até a issue de setup); roda em todo PR, sem filtro de paths |

- **Push depois de abrir o PR:** rode `./scripts/open-pr.sh --update <pr>`. Ele reescreve o
  `**Head:**` e a pasta de prints no corpo, sem mexer no resto. Se o push mudou código, teste de
  novo (e refaça os prints com `/qa`). O `pr-gate` falha enquanto isso não acontecer.
- **PR só de docs** (`./scripts/docs-only.sh`: tudo em `docs/` ou `*.md`, exceto o `CLAUDE.md`):
  dispensa prints e QA. O `ci` termina verde logo no início e o `pr-gate` só confere o `Head:`.
- **PR aberto à mão** (por exemplo o do `board.conf`): rode `./scripts/open-pr.sh --update <pr>`
  para pôr a linha `**Head:**` no corpo.
- **Merge travado no head:** `./scripts/merge.sh <pr> <head>` (o mesmo que
  `gh api -X PUT repos/{owner}/{repo}/pulls/<pr>/merge -f merge_method=squash -f sha=<head>`):
  se o head mudou depois da sua conferência, o GitHub recusa. O `/abrir-pr` e o `/corrigir`
  mostram o comando com o head atual. O botão de merge da interface continua funcionando, mas
  **sem** essa trava.
- **Squash:** o commit na `main` fica `<título do PR> (#N)`, com o corpo do PR como mensagem
  (inclui o `Closes #X`). Coautoria: `open-pr.sh --coauthor "Nome <email>"` põe o
  `Co-authored-by:` como última linha do corpo, que é onde o GitHub reconhece o trailer.

## Quando algo dá errado

Na coluna Sintoma, o texto entre crases é a mensagem que o script, o check ou o comando imprime.

| Sintoma | Causa | O que fazer |
|---|---|---|
| `pr-gate` vermelho: `Head do corpo desatualizado` | push depois de o corpo do PR ser escrito | `./scripts/open-pr.sh --update <pr>` (o `/corrigir` e o `/abrir-pr` já fazem); se o push mudou código, teste de novo |
| `pr-gate` vermelho: `O corpo do PR não tem a linha **Head:**` | PR aberto à mão (ex.: o do `board.conf`) | `./scripts/open-pr.sh --update <pr>` |
| `pr-gate` vermelho: `e o código mudou até o head` | os prints são de um commit anterior e o código mudou depois | `/qa` de novo (prints do head atual) e `--update`; ou `--prints "n/a: <motivo>"` se a mudança não é visual |
| `pr-gate` vermelho: `não bate com o commit` ou `print_sizes.txt na branch pr-assets` | a pasta citada não é a dos prints, ou não existe | `/qa` de novo e `./scripts/open-pr.sh --update <pr>` |
| `open-pr.sh`: `Não há prints em pr-assets/issue-` | nenhum print vale para o head (nunca rodou o `/qa`, ou o código mudou depois) | `/qa`, ou `--prints "n/a: <motivo>"` |
| `open-pr.sh`: `Há commits sem push` ou `A branch não tem upstream` | o PR só abre com tudo enviado | `git push -u origin task/<N>-<slug>` |
| merge bloqueado: branch atrás da `main` (ruleset strict) | a `main` andou | pedir "atualize a branch": rebase em `origin/main`, push e `--update` |
| conflito no rebase (`CONFLICT` do git) | a mesma parte mudou na `main` | o agente para e mostra os arquivos; você decide |
| `merge.sh`: `Head branch was modified` | push depois do review ou do sha copiado | conferir o push; `/revisar` se mudou código; rodar o `merge.sh` com o head atual |
| `merge.sh`: `Use o sha completo (40 caracteres) do head` | sha curto ou errado | copiar o head de 40 caracteres que o `/abrir-pr` mostra |
| `/implementar` para: `escreva o AC na spec` | a issue cita um AC que ninguém escreveu | escrever o AC na spec (no PR da task ou pelo `/planejar M<n>` do milestone atual) |
| `/implementar` para: `ainda está aberta: falta o merge ou o /fechar` | o PR anterior não foi mergeado ou o `/fechar` não rodou | merge e `/fechar`, ou passar o número da issue para pular a ordem |
| `/implementar` pergunta: `está em andamento; faço o hotfix` | `/implementar <N>` com outra task `doing` | confirmar (o agente guarda a task atual num commit `wip:` local) ou negar |
| `/planejar M<n>` recusa: `só planejo o milestone que for o próximo` | o milestone anterior não foi encerrado (ou o M0 não teve go) | `/fechar` do anterior; no M0, registrar o go/no-go |
| `new-issue.sh`: `não existe no repo` (milestone) | o milestone ainda não foi criado no GitHub | `./scripts/new-milestone.sh "M<n> — <nome>"` (no `/planejar M<n>`) |
| `sync-board.sh`: `gh sem acesso ao Projects` | `gh` sem o escopo `project` (ou sessão na nuvem) | `gh auth refresh -s project` e rodar localmente |
| `sync-board.sh`: `Sem scripts/board.conf` | o bootstrap não criou o board | `./scripts/bootstrap.sh` de novo, depois de liberar o escopo |
| `sync-board.sh`: `Campos Etapa/Ordem não encontrados` | o projeto não tem os campos | criar `Etapa` (todo, doing, review, done) e `Ordem` (number) no projeto, ou rodar o bootstrap num projeto novo |
| card no lugar errado | alguém arrastou à mão, ou o roadmap está diferente | `./scripts/sync-board.sh`; se continuar, corrigir o roadmap |
| `ci` sempre verde: `configure os testes da stack em .github/workflows/ci.yml` | o `ci.yml` ainda é o placeholder | preencher lint e testes da stack (AC da issue de setup) |

## Checklist do projeto novo

- [ ] Rodar `./scripts/bootstrap.sh` localmente (não funciona numa sessão na nuvem)
- [ ] Commit de `scripts/board.conf` e `docs/roadmap.md` (issue de setup) gerados pelo bootstrap,
      numa branch + PR (a `main` fica protegida); no PR, rode `./scripts/open-pr.sh --update <pr>`
      para o `pr-gate` passar
- [ ] Conferir em Settings → Rules o ruleset `main protegida` com os checks obrigatórios `ci` e
      `pr-gate` (strict); repo privado no plano Free não tem rulesets
- [ ] Na issue de setup, trocar o placeholder do `.github/workflows/ci.yml` pelo lint e testes da stack
- [ ] Conferir o board: o bootstrap copia o projeto modelo
      [murilinhoPs/projects/2](https://github.com/users/murilinhoPs/projects/2) com as visões
      **Board** (por Etapa), **Backlog** (tabela por Ordem) e **Roadmap** (por Milestone).
      Se a cópia falhar, ele cria um board vazio e as visões ficam para fazer à mão
- [ ] Trocar o título e a frase deste README
- [ ] Rodar `/preparar` (com o material que você já tem em `_import/`, se houver) até o
      `docs/preparo.md` chegar em `fase: pronto`, e fazer o merge do PR de preparo
- [ ] Rodar `./scripts/bootstrap.sh` de novo para criar as labels `area:*` da tabela Features
- [ ] Planejar: `/planejar` (visão geral dos milestones) e, depois do merge, `/planejar M0`
- [ ] Ajustar `docs/qa/print-rules.md` para a plataforma
- [ ] Apagar `scripts/publish-template.sh` (só serve para o template)

Issue "fila" (opcional): uma issue `type:chore` que lista o trabalho que depende de algo que você
não tem à mão (ex.: Mac para testar iOS). Quando um AC ou print não puder ser feito por isso, o PR
diz `n/a: <motivo> — #<fila>`.

Os scripts têm testes com `gh` simulado: `./scripts/test/run.sh` (precisa de `jq`, `yq` e `python3`
com `yaml`). Ele roda também o teste de fumaça `./scripts/test/smoke.sh`, que percorre o fluxo de
um projeto novo de ponta a ponta. A matriz critério de aceite → teste fica em
[`scripts/test/CA.md`](scripts/test/CA.md).

## Preparando o projeto: `/preparar`

O `/preparar` roda antes do `/planejar`. Ele descobre quais docs o projeto já tem, o que falta e
preenche as lacunas entrevistando você. O estado fica em [`docs/preparo.md`](docs/preparo.md),
um checklist de 15 itens (8 que **travam** o planejamento e 7 que **ajudam**); abra-o antes para
saber o que separar.

1. Coloque o material na pasta `_import/` (já vem no template, vazia, só com um `.gitkeep`): PRD,
   briefing, notas, PDFs, telas, demo em HTML. Depois rode `/preparar` (ou peça "importe meus docs").
   Sem nada em `_import/` (e com os docs ainda no template), o `/preparar` avisa e espera os arquivos; você pode mandá-los no chat, e ele os salva em `_import/`.
2. **Inventário:** ele lê tudo e marca cada item do checklist como `tem`, `parcial`, `falta` ou
   `n/a`, com a evidência, e anota as contradições entre as fontes.
3. **Plano:** mostra o checklist, o plano de organização dos arquivos (o que vai para onde) e a
   ordem da entrevista. Nada é movido antes do seu "pode seguir".
4. **Entrevista:** rodadas de até 4 perguntas, começando pelas contradições e pelo que trava, com
   palpites tirados do material. Decisão técnica vira ADR; "não sei ainda" vira `> Pendente:`.
   Ao fim de cada rodada ele faz commit e pergunta se continua; parar é seguro, o próximo
   `/preparar` retoma pelo `preparo.md`.
5. **Pronto:** com os itens que travam resolvidos, ele abre o PR `[docs] Preparo do projeto`.
   Depois do merge, rode `/planejar` (visão geral) e, com ele mergeado, `/planejar M0`.

Ele não inventa conteúdo e não cria issues (isso é do `/planejar`). O que o material diz sobre
fases, ordem de entrega e trabalho a fazer fica registrado na seção "Para o /planejar" do
`preparo.md`, e o `/planejar` parte dali. O mapa "material → destino"
e as regras de importação estão em [`.claude/commands/preparar.md`](.claude/commands/preparar.md).
Também há um prompt pronto em
[`docs/prompts/setup-a-partir-de-docs.md`](docs/prompts/setup-a-partir-de-docs.md).

**Usando outra IA?** Codex, opencode, Hermes e Cursor leem o `AGENTS.md`, que manda seguir o
`CLAUDE.md`, mas não rodam os comandos do Claude Code. Peça para ela seguir o arquivo do comando
da fase (`.claude/commands/<fase>.md`), começando por `.claude/commands/preparar.md`. O `/revisar`
roda numa sessão nova, sem o contexto de quem implementou (veja "Em outros agentes" no `CLAUDE.md`).

## Atualizar a partir do template

Repos criados a partir de um template não recebem as mudanças dele. Para trazer o processo novo
para um projeto antigo:

1. `git switch main && git pull && git switch -c chore/atualiza-template`
2. `./scripts/atualiza-template.sh` mostra o que mudou (não altera nada). Se o projeto ainda não
   tem esse script, copie-o do template antes.
3. `./scripts/atualiza-template.sh --aplicar` traz os caminhos "pode trazer inteiro" e mantém os
   protegidos (não faz commit). Revise com `git diff --cached` e mescle à mão o que ele listar.
4. `./scripts/bootstrap.sh` (cria só o que falta, como labels novas).
5. Reaplique no `CLAUDE.md` as regras próprias do projeto, se havia, e abra o PR
   `[chore] Atualiza processo do template`.

O template padrão é `https://github.com/murilinhoPs/docs-lite-template.git`; para outro, passe a
URL como argumento ou em `TEMPLATE_URL`.

| | Caminhos |
|---|---|
| **Pode trazer inteiro** | `.claude/`, `scripts/` (menos `scripts/board.conf`), `.github/` (menos `.github/workflows/ci.yml`), `CLAUDE.md`, `AGENTS.md`, `docs/guia.md` |
| **Mesclar à mão, se personalizou** | `docs/README.md`, `docs/qa/print-rules.md`, `docs/prompts/`, os `_template.md`, `docs/adr/README.md` (o índice é do projeto; só o texto de cima vem do template) |
| **Nunca sobrescrever** | `docs/prd.md`, `docs/roadmap.md`, `docs/preparo.md`, `docs/overview.md`, `docs/specs/*` (menos o template), `docs/adr/0*`, `docs/milestones/m*`, `docs/design/*`, `docs/assets/*`, `scripts/board.conf`, `.github/workflows/ci.yml` |

O script não apaga do projeto o que o template apagou: confira com o `git diff --stat` que ele mostra.
