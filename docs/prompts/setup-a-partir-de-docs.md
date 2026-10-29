# Prompt: montar o projeto a partir de docs existentes

Use quando o projeto já tem PRD, design e outros materiais e você quer que uma IA
(Claude Code ou outra) organize tudo em `docs/`, gere overview, specs e roadmap e crie
as issues no GitHub.

Pré-requisito: `./scripts/bootstrap.sh` já rodado localmente (milestones, labels, board).

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
`.claude/skills/`, `scripts/`, `.github/`),
copie do template antes de começar:
`git clone https://github.com/murilinhoPs/docs-lite-template /tmp/docs-lite-template`
e traga para cá só o que faltar, sem sobrescrever nada que já exista.

Antes de qualquer coisa, leia:
`CLAUDE.md`, `README.md`, `docs/README.md`, `.claude/skills/importar-docs/SKILL.md`
e todos os templates em `docs/` (overview, prd, roadmap, specs/_template.md, adr/README.md,
adr/_template.md, design/design-system.md, design/tokens.json, qa/print-rules.md,
prompts/issue-feature.md).

O `CLAUDE.md` é a regra do projeto: siga o modelo (PRD → specs → issues → roadmap), o mapa
de destinos e as regras de importação dele.

# Material (em `_import/`)

- `prd.md`: PRD do produto
- `design-system.md` e `design-system.pdf`: design system
- `telas.pdf`: telas do app
- `demo.html`: preview navegável de como o app vai funcionar

# Regras para todo o trabalho

- Não invente conteúdo. O que não estiver no material vira `TODO: <o que falta>`.
- Trabalhe em fases. No fim de cada fase, PARE, mostre o resultado e espere meu "pode seguir".
- Faça commits na branch `setup/docs`. Não dê push nem crie nada no GitHub sem eu pedir
  (as issues da Fase 4 são criadas depois que eu aprovar a lista).
- GitHub só pela API REST do repo: use os scripts (`new-issue.sh`, `open-pr.sh`) ou
  `gh api repos/{owner}/{repo}/...`.
- Se o material se contradizer (por exemplo, a PRD diz uma coisa e a demo mostra outra), pergunte qual vale.

# Fase 1: organizar o material

Mostre primeiro o plano (tabela origem → destino → ação). Depois do meu ok:

1. **PRD:** reescreva em `docs/prd.md` seguindo o template (Visão, Público, MoSCoW, Features,
   Milestones). Cada feature ganha um ID `F1`, `F2`… na tabela Features, com prioridade e área.
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
   Essa lista ajuda a escrever as specs e os critérios de aceite na Fase 3.
5. **README:** troque o título e a frase do topo pelo nome e pela descrição do projeto que estão na PRD.
6. Atualize `docs/README.md` com as pastas novas (`assets/demo/`, `assets/originais/`, `design/telas.md`).

# Fase 2: gerar o overview

A partir do README e da PRD, preencha `docs/overview.md`:

- **Resumo:** uma ou duas frases (o que é, para quem, por quê).
- **Stack:** só o que a PRD ou a demo definem. Para cada escolha de stack, proponha um ADR
  em `docs/adr/` com status `Proposta`. Me mostre a lista e só crie os ADRs depois do meu ok
  (atualize o índice em `docs/adr/README.md`).
  Escolhas que não estão no material ficam como `TODO`, com a sua sugestão ao lado.
- **Arquitetura:** diagrama Mermaid com os blocos que a PRD descreve.
- **Glossário:** termos de domínio usados na PRD.

# Fase 3: dividir a PRD em specs por feature + issues

As Fases 3 e 4 seguem o comando `/planejar` (`.claude/commands/planejar.md`): proposta →
aprovação → specs + issues + roadmap num PR só de docs.

1. **Specs:** para cada feature da tabela Features, crie `docs/specs/<feature>.md` a partir de
   `docs/specs/_template.md` (frontmatter `feature: F<n>`, `area:`, `updated:`). Descreva como a
   feature deve funcionar com o que está na PRD, nas telas e nos fluxos da demo, e escreva os
   critérios de aceite com IDs `AC-F<n>-01`, `AC-F<n>-02`… Ambiguidade vira
   `> Pendente: <pergunta>`; não invente.
2. **Issues (só o plano):** divida o trabalho em issues. Cada issue deve:
   - caber num PR revisável (uma tela, um fluxo ou uma integração; nunca "fazer o app todo");
   - ser entregável e testável sozinha, na ordem do roadmap;
   - citar a spec (`**Spec:** docs/specs/<feature>.md (F<n>)`) e os AC da spec que entrega;
   - citar em "Notas técnicas" as telas, os tokens e os ADRs relevantes.
3. Milestones:
   - `M0 Fundação`: a issue `[chore] Setup do projeto` (criada pelo bootstrap) mais o que for
     base técnica (navegação, tema com os tokens, etc.);
   - `M1 MVP`: as features Must;
   - um milestone para Should (ex.: `M2 <nome>`), se fizer sentido;
   - features Could e Won't não viram issues.
4. ANTES de criar qualquer issue, me mostre a lista na ordem do roadmap: título (`[feat] ...`),
   milestone, labels (`type:*`, `area:*`), uma linha de objetivo, os AC cobertos e as
   dependências. Ajuste até eu aprovar.
5. Se houver milestone novo, acrescente-o ao `roadmap.md` (seção `## <milestone>` com o cabeçalho
   da tabela), à tabela de milestones do `prd.md` e à lista de milestones em `scripts/bootstrap.sh`.
6. Confira: todo link do PRD aponta para uma spec que existe, e toda spec tem uma linha na
   tabela Features.

# Fase 4: GitHub (depois do meu ok na lista de issues)

1. Confira os milestones: `gh api repos/{owner}/{repo}/milestones?state=all -q '.[].title'`.
   Milestone que faltar: `gh api repos/{owner}/{repo}/milestones -f title="<milestone>"`.
   Labels `area:*` que faltarem: me peça para rodar `./scripts/bootstrap.sh` localmente (ele lê a
   tabela Features); não crie labels sem perguntar.
2. **Issues:** para cada issue aprovada, na ordem, escreva o corpo no formato de
   `docs/prompts/issue-feature.md` e rode:
   `./scripts/new-issue.sh --title "[feat] <título>" --body-file <corpo.md> --milestone "<milestone>" --labels "type:feature,area:<x>"`.
   O script cria a issue pela API REST e insere a linha no fim do milestone no roadmap, com
   status `todo`.
3. **Board:** rode `./scripts/sync-board.sh --auto`. Onde o board é acessível (Claude Code local),
   ele coloca as issues no board, na ordem do roadmap; numa sessão na nuvem, ele avisa e segue, e
   eu rodo o sync localmente depois do merge.
4. Faça commit do roadmap atualizado na `setup/docs`, me mostre o resultado e pergunte antes de
   dar push. Com o ok: `git push -u origin setup/docs` e abra o PR com
   `gh api repos/{owner}/{repo}/pulls -f head=setup/docs -f base=main -f title="[docs] Setup a partir dos docs" -F body=@<corpo.md>`
   e, em seguida, `./scripts/open-pr.sh --update <pr>` para pôr o `**Head:**` no corpo (o check
   `pr-gate` exige). Eu faço o merge na `main`.

# Ao final

Me entregue:

- a tabela de onde foi parar cada arquivo do material;
- a lista de features (`F<n>`) com a spec de cada uma;
- a lista de issues por milestone, com os números;
- os `TODO`, as linhas `> Pendente:` e os ADRs `Proposta` que dependem de mim;
- o que você não importou ou não conseguiu fazer, e por quê.
````
