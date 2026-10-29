# Prompt: montar o projeto a partir de docs existentes

Use quando o projeto já tem PRD, design e outros materiais e você quer que uma IA
(Claude Code ou outra) organize tudo em `docs/`, gere overview, tasks e roadmap e crie
as issues no GitHub.

Como usar:

1. Coloque o material numa pasta `_import/` na raiz do projeto.
2. Ajuste a lista em **Material** abaixo com os seus arquivos.
3. Copie tudo a partir de "Contexto" e cole na IA.

---

````markdown
# Contexto

Este repositório segue o template docs-lite-template:
https://github.com/murilinhoPs/docs-lite-template

Se o projeto não foi criado a partir dele, ou se faltar algum arquivo (`CLAUDE.md`, `docs/`,
`.claude/skills/`, `scripts/bootstrap.sh`, `.github/pull_request_template.md`),
copie do template antes de começar:
`git clone https://github.com/murilinhoPs/docs-lite-template /tmp/docs-lite-template`
e traga para cá só o que faltar, sem sobrescrever nada que já exista.

Antes de qualquer coisa, leia:
`CLAUDE.md`, `README.md`, `docs/README.md`, `.claude/skills/importar-docs/SKILL.md`
e todos os templates em `docs/` (overview, prd, roadmap, tasks/_template.md,
adr/_template.md, design/design-system.md, design/tokens.json, qa/print-rules.md).

O `CLAUDE.md` é a regra do projeto: siga o mapa de destinos e as regras de importação dele.

# Material (em `_import/`)

- `prd.md`: PRD do produto
- `design-system.md` e `design-system.pdf`: design system
- `telas.pdf`: telas do app
- `demo.html`: preview navegável de como o app vai funcionar

# Regras para todo o trabalho

- Não invente conteúdo. O que não estiver no material vira `TODO: <o que falta>`.
- Trabalhe em fases. No fim de cada fase, PARE, mostre o resultado e espere meu "pode seguir".
- Faça commits na branch `setup/docs`. Não dê push nem crie nada no GitHub sem eu pedir.
- Se o material se contradizer (por exemplo, a PRD diz uma coisa e a demo mostra outra), pergunte qual vale.

# Fase 1: organizar o material

Mostre primeiro o plano (tabela origem → destino → ação). Depois do meu ok:

1. **PRD:** reescreva em `docs/prd.md` seguindo o template (Visão, Público, MoSCoW, Milestones).
   Preserve todo o conteúdo. O que não couber nas seções vai para uma seção "Notas" no fim.
   Guarde o original em `docs/assets/originais/prd.md`.
2. **Design system:** reescreva em `docs/design/design-system.md` seguindo o template.
   Extraia cores, tipografia e espaçamento para `docs/design/tokens.json`, somente
   com os valores que aparecem no material. O PDF vai para `docs/assets/design/design-system.pdf`.
3. **Telas:** mova o PDF para `docs/assets/screens/telas.pdf`. Depois me pergunte se devo
   exportar cada tela como PNG (`docs/assets/screens/<nome-da-tela>.png`). Se eu
   disser que sim, use nomes curtos em kebab-case e crie uma tabela em `docs/design/telas.md`
   com tela → arquivo → seção da PRD.
4. **Demo:** mova para `docs/assets/demo/index.html`. Leia o HTML e liste os fluxos que ele mostra.
   Essa lista ajuda a escrever as tasks e os critérios de aceite na Fase 3.
5. **README:** troque o título e a frase do topo pelo nome e pela descrição do projeto que estão na PRD.
6. Atualize `docs/README.md` com as pastas novas (`assets/demo/`, `assets/originais/`, `design/telas.md`).

# Fase 2: gerar o overview

A partir do README e da PRD, preencha `docs/overview.md`:

- **Resumo:** uma ou duas frases (o que é, para quem, por quê).
- **Stack:** só o que a PRD ou a demo definem. Para cada escolha de stack, proponha um ADR
  em `docs/adr/` com status `proposed`. Me mostre a lista e só crie os ADRs depois do meu ok.
  Escolhas que não estão no material ficam como `TODO`, com a sua sugestão ao lado.
- **Arquitetura:** diagrama Mermaid com os blocos que a PRD descreve.
- **Glossário:** termos de domínio usados na PRD.

# Fase 3: dividir em tasks e montar o roadmap

1. Divida a PRD em tasks. Cada task deve:
   - caber num PR revisável (uma tela, um fluxo ou uma integração; nunca "fazer o app todo");
   - ser entregável e testável sozinha, na ordem do roadmap;
   - ter critérios de aceite verificáveis, escritos a partir da PRD, das telas e dos fluxos da demo;
   - citar em "Notas técnicas" as telas, a seção da PRD, os tokens e os ADRs relevantes.
2. Milestones:
   - `M0 Fundação`: a task 001 (setup), que já existe, mais o que for base técnica
     (navegação, tema com os tokens, etc.);
   - `M1 MVP`: os itens Must da PRD;
   - um milestone para Should (ex.: `M2 <nome>`), se fizer sentido;
   - itens Could e Won't não viram tasks.
3. ANTES de criar os arquivos, me mostre a lista: número, título, milestone, uma linha de
   objetivo e as dependências. Ajuste até eu aprovar.
4. Depois do ok, crie `docs/tasks/NNN-<slug>.md` com base no `_template.md`, com `status: todo`,
   e preencha `docs/roadmap.md` na ordem de execução.
5. Se houver milestone novo, acrescente-o ao `roadmap.md`, à tabela de milestones do `prd.md`
   e à lista de milestones em `scripts/bootstrap.sh`.
6. Confira: todo link do roadmap aponta para um arquivo que existe, e vice-versa.

Ao fim desta fase, me pergunte se pode dar push da `setup/docs` e abrir o PR.
Eu faço o merge na `main`.

# Fase 4: GitHub (só depois do merge da `setup/docs`)

1. `git switch main && git pull`.
2. **Milestones, labels e board:** rode `./scripts/bootstrap.sh` (só funciona localmente, com o
   `gh` do usuário; numa sessão na nuvem, peça para eu rodar). Ele cria os milestones que
   faltam, as labels, o board no Projects (salvo em `scripts/board.conf`), a branch `pr-assets`
   e as proteções. O board exige o escopo `project` no gh (`gh auth refresh -s project`);
   se não houver, me avise. Confirme com `gh api repos/{owner}/{repo}/milestones -q '.[].title'`.
3. **Issues:** para cada task do roadmap, na ordem:
   `./scripts/create-issue.sh docs/tasks/NNN-<slug>.md`. Ele usa título, milestone e labels do
   frontmatter e grava o número da issue no frontmatter (`issue:`) e na coluna Issue do roadmap.
   O status continua `todo`.
4. **Board:** o Action `.github/workflows/sync-board.yml` coloca as issues no board, na ordem do
   roadmap, quando o PR da `setup/issues` abrir e quando ele for mergeado (precisa do secret
   `PROJECT_TOKEN`, veja o README). No Claude Code local, rode também `./scripts/sync-board.sh --auto`.
   Me lembre de criar as visões na interface (Board por Etapa, Backlog por Ordem,
   Roadmap por Milestone) e o secret `PROJECT_TOKEN`, se ainda não existir.
5. Faça commit dessas atualizações (roadmap, frontmatters, `scripts/board.conf`) numa branch
   `setup/issues`, me mostre o resultado e pergunte antes de dar push e abrir o PR.

# Ao final

Me entregue:

- a tabela de onde foi parar cada arquivo do material;
- a lista de tasks por milestone, com os números das issues;
- os `TODO` e os ADRs `proposed` que dependem de mim;
- o que você não importou ou não conseguiu fazer, e por quê.
````
