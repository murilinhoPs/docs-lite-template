# <Nome do projeto>

<Uma frase sobre o projeto.> Documentação completa em [docs/](docs/README.md).

## Como este repositório funciona

| O quê | Onde | Pergunta que responde |
|---|---|---|
| Visão, escopo, features | `docs/prd.md` | O que o produto é e por quê |
| Comportamento atual de cada feature | `docs/specs/<feature>.md` | Como funciona **hoje** |
| Decisões | `docs/adr/` | Por que foi feito assim |
| Trabalho a fazer | **Issues do GitHub** | O que falta mudar |
| Ordem de execução e status | `docs/roadmap.md` | O que vem agora |
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
- **O Claude Code trabalha por comandos** (`.claude/commands/`), um por fase, e segue o
  [`CLAUDE.md`](CLAUDE.md). Outras ferramentas (Codex, opencode, Cursor) leem o
  [`AGENTS.md`](AGENTS.md), um link para o `CLAUDE.md`; os comandos de `.claude/` são só do Claude Code.
- **Só API REST do repositório:** os scripts (`new-issue.sh`, `task-status.sh`, `open-pr.sh`,
  `merge.sh`) usam `gh api repos/{owner}/{repo}/...` e funcionam em qualquer ambiente, inclusive
  nas sessões do Claude Code na nuvem. A exceção é o `sync-board.sh` (`gh project`).

## Comandos

Fluxo: `/preparar` (até nada travar) → `/planejar` → ciclo das tasks.

| Comando | Papel | Para quando |
|---|---|---|
| `/preparar [pasta]` | Analista de docs | `docs/preparo.md` em `fase: pronto` e PR de docs aberto |
| `/planejar <milestone>` | PM + docs | PR de planejamento aberto (specs + issues + roadmap) |
| `/implementar [issue]` | Dev | Commits locais feitos, antes do push |
| `/qa [issue]` | Tester | Prints na `pr-assets` e relatório entregue |
| `/abrir-pr [issue]` | Dev | PR aberto ou atualizado, com o head no corpo |
| `/revisar [pr]` | Reviewer (subagente) | Review postado como comentário |
| `/corrigir [pr ou issue]` | Dev | Correções commitadas (e enviadas, se o PR existir) |
| `/fechar [pr]` | PM | Board, nits e milestone atualizados |

## Ciclo de uma task, em comandos

0. `/preparar` (uma vez por projeto) → inventaria o material de `_import/`, organiza em `docs/` e
   entrevista você até nada travar o planejamento; abre o PR `[docs] Preparo do projeto`.
1. `/planejar M1` → propõe issues, ACs e specs; depois do seu ok, abre o PR de planejamento. Você faz o merge.
2. `/implementar` → pega a primeira issue `todo`, cria `task/<N>-<slug>`, marca `doing` e faz commits locais.
3. Você testa contra os ACs (o `/implementar` diz como).
4. `/qa` (opcional) → o Claude testa como tester e salva prints em `pr-assets/issue-<N>/<sha7>/`.
5. `/abrir-pr` → marca `done`, dá push e abre o PR com o head no corpo e o comando de merge pronto.
6. `/revisar` → o subagente `revisor` posta um review (`COMMENT`) com bloqueantes, deveria e nits.
7. `/corrigir` → corrige só o apontado, atualiza o PR e diz se você precisa testar de novo.
8. Você faz o merge (`./scripts/merge.sh <pr> <head>`) e roda `/fechar` (board, nits e milestone).

---

## Começando um projeto a partir deste template

```bash
gh repo create meu-projeto --template murilinhoPs/docs-lite-template --private --clone
cd meu-projeto
gh auth refresh -s project
./scripts/bootstrap.sh
```

Depois do bootstrap, rode `/preparar` no Claude Code (veja "Preparando o projeto") e, com o PR de
preparo mergeado, `/planejar M1`.

O `bootstrap.sh` roda **só localmente**, com o `gh` do usuário logado: ele usa GraphQL
(`gh project`, `gh label`, `gh repo edit`), que as sessões do Claude Code na nuvem não têm.

Ele cria o que o template não copia: milestones, labels (`type:*`, `prio:*` e as `area:*` da
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
- [ ] Planejar o primeiro milestone com `/planejar M1`
- [ ] Ajustar `docs/qa/print-rules.md` para a plataforma
- [ ] Apagar `scripts/publish-template.sh` (só serve para o template)

Issue "fila" (opcional): uma issue `type:chore` que lista o trabalho que depende de algo que você
não tem à mão (ex.: Mac para testar iOS). Quando um AC ou print não puder ser feito por isso, o PR
diz `n/a: <motivo> — #<fila>`.

Os scripts têm testes com `gh` simulado: `./scripts/test/run.sh` (precisa de `jq` e `yq`).

## Preparando o projeto: `/preparar`

O `/preparar` roda antes do `/planejar`. Ele descobre quais docs o projeto já tem, o que falta e
preenche as lacunas entrevistando você. O estado fica em [`docs/preparo.md`](docs/preparo.md),
um checklist de 15 itens (8 que **travam** o planejamento e 7 que **ajudam**); abra-o antes para
saber o que separar.

1. Coloque o material numa pasta `_import/` (PRD, briefing, notas, PDFs, telas, demo em HTML) e
   rode `/preparar` (ou peça "importe meus docs"). Sem material, ele começa pelo que há em `docs/`.
2. **Inventário:** ele lê tudo e marca cada item do checklist como `tem`, `parcial`, `falta` ou
   `n/a`, com a evidência, e anota as contradições entre as fontes.
3. **Plano:** mostra o checklist, o plano de organização dos arquivos (o que vai para onde) e a
   ordem da entrevista. Nada é movido antes do seu "pode seguir".
4. **Entrevista:** rodadas de até 4 perguntas, começando pelas contradições e pelo que trava, com
   palpites tirados do material. Decisão técnica vira ADR; "não sei ainda" vira `> Pendente:`.
   Ao fim de cada rodada ele faz commit e pergunta se continua; parar é seguro, o próximo
   `/preparar` retoma pelo `preparo.md`.
5. **Pronto:** com os itens que travam resolvidos, ele abre o PR `[docs] Preparo do projeto`.
   Depois do merge, rode `/planejar M1`.

Ele não inventa conteúdo e não cria issues (isso é do `/planejar`). O mapa "material → destino"
e as regras de importação estão em [`.claude/commands/preparar.md`](.claude/commands/preparar.md).
Também há um prompt pronto em
[`docs/prompts/setup-a-partir-de-docs.md`](docs/prompts/setup-a-partir-de-docs.md).

**Usando outra IA?** Codex, opencode e Cursor leem o `AGENTS.md` (link para o `CLAUDE.md`), mas
não rodam os comandos do Claude Code. Peça para ela seguir o arquivo do comando da fase
(`.claude/commands/<fase>.md`), começando por `.claude/commands/preparar.md`.
