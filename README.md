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
| Visualização | Board do Projects | Espelho do roadmap |

- **A spec descreve o presente; a issue descreve a mudança.** Um PR que muda comportamento
  atualiza a spec no mesmo PR. Features têm IDs estáveis (`F1`, `F2`…) e cada critério de aceite
  também (`AC-F2-03`).
- **O roadmap dá a ordem:** cada linha é uma issue, com status `todo`/`doing`/`review`/`done`.
  Ele fica no repo porque as sessões do Claude Code na nuvem não leem o Projects.
- **O board é um espelho do roadmap:** o Action [`sync-board.yml`](.github/workflows/sync-board.yml)
  roda `./scripts/sync-board.sh`. Mude o roadmap, nunca o board.
- **Funciona no Claude Code local e na nuvem:** durante uma task o Claude só usa a API REST do
  repositório (`new-issue.sh`, `task-status.sh`, `open-pr.sh`), que as sessões na nuvem aceitam.
- **O Claude Code segue o [`CLAUDE.md`](CLAUDE.md):** implementa uma issue por vez, na ordem do roadmap.

Ciclo de uma issue:

1. "Implemente a próxima task" → o Claude lê a primeira issue `todo` do roadmap e a spec dela,
   cria `task/<N>-<slug>`, marca `doing` (roadmap + label `status:doing`) e implementa com
   commits locais, atualizando a spec se o comportamento mudar.
2. Você testa contra os critérios de aceite.
3. (Opcional) "Teste você também" → o Claude testa e salva prints em `pr-assets/issue-<N>/<sha7>/`.
4. "Pode abrir o PR" → status `review`, push da branch e PR com `Closes #N`, head e AC.
5. Você faz o squash merge.

---

## Começando um projeto a partir deste template

```bash
gh repo create meu-projeto --template murilinhoPs/docs-lite-template --private --clone
cd meu-projeto
gh auth refresh -s project
./scripts/bootstrap.sh
```

O `bootstrap.sh` roda **só localmente**, com o `gh` do usuário logado: ele usa GraphQL
(`gh project`, `gh label`, `gh repo edit`), que as sessões do Claude Code na nuvem não têm.

Ele cria o que o template não copia: milestones, labels (`type:*`, `prio:*`, `status:doing` e as
`area:*` da tabela Features do `prd.md`), board no Projects (cópia do projeto modelo, com os
campos Etapa e Ordem e as visões; número salvo em `scripts/board.conf`), a issue `[chore] Setup do projeto` com a linha dela no roadmap, branch
`pr-assets`, worktree de prints, squash-only e proteção da `main`. Pode rodar de novo: ele pula
o que já existe (rode de novo depois de preencher a tabela Features, para criar as `area:*`).

O projeto modelo é `murilinhoPs/2`. Para usar outro: `BOARD_TEMPLATE=<owner>/<número> ./scripts/bootstrap.sh`.
O modelo precisa ter o campo `Etapa` (single select com `todo`, `doing`, `review`, `done`) e o
campo `Ordem` (number); as visões vêm junto na cópia.

## Sync do board

O board é atualizado pelo Action [`sync-board.yml`](.github/workflows/sync-board.yml):

| Evento | De onde vem a Etapa |
|---|---|
| push na `main` que muda `docs/roadmap.md` (merge) | roadmap da `main` |
| PR aberto/atualizado que muda `docs/roadmap.md` | roadmap do head do PR (é assim que `review` aparece) |
| label `status:doing` adicionada/removida numa issue | roadmap da `main` + label |
| Run workflow (manual) | roadmap da `main` |

Etapa = status do roadmap, exceto quando a issue tem a label `status:doing`: aí é `doing`. A label
é posta pelo `./scripts/task-status.sh <N> doing` quando a task começa (a branch só sobe no PR) e
tirada no `review`. Uma issue `todo` com PR aberto (`Closes #N`) também aparece como `review`.
No Claude Code local, o `task-status.sh` roda o sync na hora; nas sessões na nuvem quem
sincroniza é o Action.

O `GITHUB_TOKEN` padrão do Action não acessa Projects de usuário, então ele usa um token seu:

1. Crie um token em GitHub → Settings → Developer settings:
   - **classic**, com os escopos `project` e `repo`; ou
   - **fine-grained**, com acesso ao repositório (Issues e Pull requests: read) e, em
     Account permissions, **Projects: read and write**.
   Se o fine-grained não enxergar o board da sua conta, use o classic.
2. No repositório: Settings → Secrets and variables → Actions → New repository secret,
   nome `PROJECT_TOKEN`, valor = o token.

Sem `scripts/board.conf` ou sem o secret, o Action termina verde com um aviso: o template
recém-criado não fica com CI vermelho.

## Checklist do projeto novo

- [ ] Rodar `./scripts/bootstrap.sh` localmente (não funciona numa sessão na nuvem)
- [ ] Commit de `scripts/board.conf` e `docs/roadmap.md` (issue de setup) gerados pelo bootstrap,
      numa branch + PR (a `main` fica protegida)
- [ ] Criar o token e o secret `PROJECT_TOKEN` (veja "Sync do board")
- [ ] Conferir o board: o bootstrap copia o projeto modelo
      [murilinhoPs/projects/2](https://github.com/users/murilinhoPs/projects/2) com as visões
      **Board** (por Etapa), **Backlog** (tabela por Ordem) e **Roadmap** (por Milestone).
      Se a cópia falhar, ele cria um board vazio e as visões ficam para fazer à mão
- [ ] Trocar o título e a frase deste README
- [ ] Preencher `docs/overview.md` e `docs/prd.md` (com a tabela Features) e criar as specs em
      `docs/specs/` (ou importar docs que você já tem, veja abaixo)
- [ ] Rodar `./scripts/bootstrap.sh` de novo para criar as labels `area:*` da tabela Features
- [ ] Criar as primeiras issues com `./scripts/new-issue.sh` (ou pedir ao Claude)
- [ ] Ajustar `docs/qa/print-rules.md` para a plataforma
- [ ] Apagar `scripts/publish-template.sh` (só serve para o template)

Issue "fila" (opcional): uma issue `type:chore` que lista o trabalho que depende de algo que você
não tem à mão (ex.: Mac para testar iOS). Quando um AC ou print não puder ser feito por isso, o PR
diz `n/a: <motivo> — #<fila>`.

Os scripts têm testes com `gh` simulado: `./scripts/test/run.sh` (precisa de `jq` e `yq`).

## Importando docs que você já tem

Se o projeto já tem briefing, specs, notas, decisões ou imagens, o Claude Code organiza tudo
em `docs/` com a skill [`importar-docs`](.claude/skills/importar-docs/SKILL.md).

1. Coloque os arquivos numa pasta do repositório, por exemplo `_import/` (ou anexe na conversa).
2. Peça ao Claude Code: "importe meus docs de `_import/`" (ou rode `/importar-docs`).
3. Ele lê cada arquivo e pergunta o que ele é (PRD, spec de feature, trabalho a fazer, decisão técnica, design...),
   sugerindo um palpite.
4. Ele mostra um plano: o que vai para onde, quais features e specs surgem, quais issues serão
   criadas (título, milestone, labels, AC), o que não será importado e o que ficará como `TODO`.
5. Você muda o que quiser (destino de um doc, ordem das issues, milestones) até aprovar.
6. Só então ele organiza os arquivos, cria as issues aprovadas (com as linhas no roadmap) e faz
   um commit local, sem push.

Ele não inventa conteúdo: o que faltar nos templates vira `TODO: <o que falta>`.
O mapa de destinos e as regras ficam no [`CLAUDE.md`](CLAUDE.md), na seção
"Ao pedir 'importe meus docs'".

**Quer o setup completo** (organizar o material, gerar overview, specs e roadmap e criar as
issues no GitHub)? Use o prompt pronto em
[`docs/prompts/setup-a-partir-de-docs.md`](docs/prompts/setup-a-partir-de-docs.md).

**Usando outra IA?** Ela não lê skills do Claude Code. Peça para ela ler o `CLAUDE.md` e o
`SKILL.md` acima antes de começar, ou copie o conteúdo deles para o arquivo de instruções
da ferramenta (`.cursorrules`, `.github/copilot-instructions.md` etc.).
