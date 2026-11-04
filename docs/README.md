# Documentação

| O quê | Onde | Pergunta que responde |
|---|---|---|
| Visão, escopo, features | [prd.md](prd.md) | O que o produto é e por quê |
| Comportamento atual de cada feature | [specs/](specs/) `<feature>.md` | Como funciona **hoje** |
| Decisões | [adr/](adr/README.md) | Por que foi feito assim |
| Trabalho a fazer | **Issues do GitHub** | O que falta mudar |
| Milestones (visão geral) e ordem e status das issues | [roadmap.md](roadmap.md) | O que vem agora |
| Plano do milestone em andamento | [milestones/](milestones/) `m<n>.md` | O que entra neste milestone |
| Visualização | Board do Projects | Espelho do roadmap |

A spec descreve o presente, nunca planos. A issue descreve a mudança. Um PR que muda
comportamento atualiza a spec no mesmo PR.

## Arquivos

| Arquivo / pasta | O que guarda |
|---|---|
| [guia.md](guia.md) | Resumo do processo para pessoas: modelo, fluxo, comandos, scripts, merge gate (se divergir, vale o `CLAUDE.md`) |
| [`../_import/`](../_import/) | Material a importar pelo `/preparar` (PRD, design, telas, demo, notas). Sem nada em `_import/` (e com os docs ainda no template), o `/preparar` avisa e espera os arquivos; você pode mandá-los no chat, e ele os salva em `_import/`. |
| [preparo.md](preparo.md) | Checklist do preparo (o que o projeto precisa antes do `/planejar`), a seção "Para o /planejar" (o que o material diz sobre fases, ordem de entrega e trabalho a fazer) e o registro da entrevista |
| [overview.md](overview.md) | Resumo do projeto, stack e arquitetura |
| [prd.md](prd.md) | Visão, escopo, MoSCoW e a tabela de Features (`F1`, `F2`…) |
| [specs/](specs/) | Uma spec viva por feature, com os AC vigentes (`AC-F<n>-NN`) |
| [roadmap.md](roadmap.md) | Milestones (visão geral, em prosa) e as issues por milestone, com ordem e status |
| [milestones/](milestones/) | Um doc por milestone já detalhado (`m<n>.md`): escopo, ACs referenciados, critério de saída, riscos, ordem; vira histórico quando encerra |
| [adr/](adr/README.md) | Decisões técnicas, numeradas (`0001-...`), com índice |
| [design/](design/) | Design system e tokens |
| [qa/print-rules.md](qa/print-rules.md) | Como e o que printar quando o Claude testa |
| [assets/](assets/) | Imagens oficiais (telas aprovadas, referências) |
| [prompts/](prompts/) | Corpos modelo de issue e prompts prontos para passar a uma IA |

## Regras

- A ordem das linhas em `roadmap.md` é a ordem de execução. Cada linha é uma issue.
- Ciclo de uma task: `/implementar` → seu teste → `/revisar local` (opcional) → `/abrir-pr` → `/revisar` → merge → `/fechar`. O review local fica só na conversa;
  o do PR é postado travado no head.
- Planejamento em duas etapas: `/planejar` escreve a visão geral dos milestones; `/planejar M<n>`
  detalha só o próximo. Nunca existem issues (nem milestone no GitHub) de milestones futuros.
  O material sobre fases e trabalho a fazer passa do `/preparar` para o `/planejar` pela seção
  "Para o /planejar" do `preparo.md`.
- Fluxo: `/preparar` → merge → `/planejar` (visão geral) → merge → `/planejar M0` → merge → ciclo das tasks do M0 → `/fechar` (go/no-go) → `/planejar M1` → ciclo → `/fechar` → `/planejar M2` ….
- `roadmap.md` guarda o destino de cada issue (`todo`, `doing`, `done`). O board espelha o roadmap
  e o andamento no GitHub (issue fechada → `done`, PR aberto → `review`), pelo
  `./scripts/sync-board.sh`, que roda onde o board é acessível. Nunca mova cards à mão.
- Cada fase do trabalho tem um comando em `.claude/commands/` (veja o `CLAUDE.md`).
- Só uma issue em `doing` por vez.
- Merge só com os checks `ci` e `pr-gate` verdes no head e a branch atualizada com a `main`.
  PR só de docs (tudo em `docs/` ou `*.md`, exceto o `CLAUDE.md`) dispensa prints e QA.
- IDs de feature (`F<n>`) e de AC (`AC-F<n>-NN`) nunca são renomeados nem reaproveitados.
- ADR `Aceita` não é editado: um novo ADR o substitui (`Superada por 0007`).
- Versão do PRD: git tag `prd-vX.Y` (`git tag prd-v1.0 && git push origin prd-v1.0`). Nunca
  escreva sha ou número de versão no texto dos docs; o histórico está no git.
- Imagem oficial vai em `docs/assets/`; print de teste vai na branch `pr-assets`
  (`issue-<N>/<sha7>/`).
- Diagrama é Mermaid; imagem só para tela real ou referência visual.

## Exemplo de ponta a ponta

O mesmo critério de aceite atravessando o processo. Os formatos são os dos templates do repo.

**1. PRD** (`docs/prd.md`, tabela Features):

```markdown
| ID | Feature | Prioridade | Spec | Área |
|---|---|---|---|---|
| F1 | Login com e-mail | Must | [specs/login.md](specs/login.md) | area:auth |
```

**2. Spec** (`docs/specs/login.md`, seção "Critérios de aceite vigentes"):

```markdown
- AC-F1-01: com e-mail e senha válidos, o usuário entra e vê a tela inicial
- AC-F1-02: com a senha errada, aparece "E-mail ou senha incorretos" e o campo de senha é limpo
```

**3. Issue** (`/planejar M1`, corpo no formato de `docs/prompts/issue-feature.md`), título
`[feat] Login com e-mail`, labels `type:feature,area:auth`, milestone `M1 — MVP`:

```markdown
**Spec:** docs/specs/login.md  (F1)
**Milestone:** docs/milestones/m1.md
**Área:** area:auth

## Critérios de aceite
- [ ] AC-F1-01: com e-mail e senha válidos, o usuário entra e vê a tela inicial
- [ ] AC-F1-02: com a senha errada, aparece "E-mail ou senha incorretos" e o campo de senha é limpo

## Como verificar
- Teste automatizado: login válido e senha errada
- Fluxo manual: abrir /login, errar a senha, conferir a mensagem
- Plataformas: web 1280×800
- Precisa de print: sim (→ `type:design`) / não
```

**4. Roadmap** (`docs/roadmap.md`, seção "Issues por milestone", linha criada pelo `new-issue.sh`):

```markdown
### M1 — MVP

| Ordem | Issue | Título | Status | Spec | PR |
|---|---|---|---|---|---|
| 2 | #12 | [feat] Login com e-mail | todo | specs/login.md | |
```

**5. PR** (`/abrir-pr`, corpo pelo `.github/pull_request_template.md`):

```markdown
Closes #12

**Spec:** docs/specs/login.md (não muda comportamento)
**Head:** <sha de 40 caracteres>
**Tipo:** código

## Critérios de aceite
- [ ] AC-F1-01: …
- [ ] AC-F1-02: …

## Testes
(saída real dos testes)
`git rev-parse --short HEAD`: <sha7>

## Prints
[pr-assets/issue-12/<sha7>/](…)
```

A linha do roadmap já vai `done` nesse PR, e o número do PR entra na coluna PR.

**6. Review** (`/revisar`, subagente `revisor`, postado com `event=COMMENT` travado no head):

```markdown
## Bloqueante
(nenhum)

## Deveria
- src/login.ts:42 — a mensagem de erro está fixa no código; deveria vir do arquivo de textos.

## Nit
- src/login.ts:10 — import não usado.

Recomendação: pode fazer o merge (0 bloqueantes, 1 deveria, 1 nit).
```

**7. Merge e `/fechar`:** você roda `./scripts/merge.sh <pr> <head>`. O `/fechar` confere que a
issue #12 fechou, sincroniza o board (o card vai para `done`) e pergunta quais nits e "deveria"
viram issue. O "deveria" aprovado vira `[chore] Textos de erro do login no arquivo de textos`,
com `prio:baixa` e sem linha no roadmap; o próximo `/planejar M<n>` decide onde ele entra.

