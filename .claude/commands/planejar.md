---
description: Planeja em duas etapas - sem argumento escreve a visão geral dos milestones no roadmap; com M<n> detalha o próximo milestone e cria as issues dele depois da aprovação
argument-hint: "[M<n>]"
---

# /planejar $ARGUMENTS

## Papel

PM + docs. Planeja em duas etapas e não escreve código:

1. **Visão geral** (`/planejar`): todos os milestones no `docs/roadmap.md`, só em prosa. Nada no GitHub.
2. **Um milestone** (`/planejar M<n>`): só quando ele é o próximo, detalha o milestone e quebra
   em issues pequenas, criadas depois do "pode seguir".

Regra de ouro: **nunca existem issues (nem milestone no GitHub) de milestones futuros.**

## Argumentos

`$ARGUMENTS` vazio → **Modo 1** (visão geral). `M<n>` (ex.: `M0`, `M1`) → **Modo 2** (esse milestone).

## Passos

### Modo 1: `/planejar` → visão geral (etapa 1)

Pré-condições: `docs/preparo.md` com `fase: pronto` (se não, avise e pergunte se segue mesmo
assim) e a tabela Features do `docs/prd.md` preenchida.

1. Leia `docs/prd.md`, as specs que existem, os ADRs, `docs/overview.md` e `docs/preparo.md`,
   incluindo a seção **"Para o /planejar"**: as linhas de "Fases, milestones e ordem de entrega"
   são o ponto de partida da seção Milestones. Se a tabela estiver vazia, proponha do zero.
2. `git switch main && git pull && git switch -c plan/roadmap`. Escreva a seção **Milestones** do
   `docs/roadmap.md`. Para cada milestone, **só**:
   - `### M<n> — <nome>` (travessão; o mesmo título será usado no GitHub);
   - **Objetivo** (1 frase), **Escopo** (ids `F#`), **Critério de saída** testável
     (ex.: "o fluxo X roda de ponta a ponta no Android"), **Depende de / decisões abertas** e
     **Tamanho** (P, M ou G).
3. **M0 — Fundação e spike** é sempre um spike de risco com **go/no-go** antes do M1: os riscos
   vêm das decisões técnicas e das integrações do `preparo.md` (itens 3 e 6) e do PRD. O M0 também
   contém a issue de setup (criada pelo `bootstrap.sh`).
4. Cada feature `F#` entra em **no máximo um** milestone; features `Won't` ficam fora.
   Dúvidas viram `> Pendente:` no próprio roadmap. Atualize o `updated:` do roadmap.
5. Mostre a seção Milestones dizendo quais milestones vieram do material (com a fonte, da seção
   "Para o /planejar") e onde a proposta diverge dele e por quê, e **pare** até o "pode seguir".
   Ajuste até a aprovação.
6. Depois do ok: commit (`docs: roadmap, visão geral`), `git push -u origin plan/roadmap` e um PR
   só de docs, `[docs] Roadmap: visão geral`, pelo template (sem `Closes`, `**Tipo:** só docs`,
   testes e prints `n/a: PR só de docs`):
   `gh api repos/{owner}/{repo}/pulls -f head=plan/roadmap -f base=main -f title="[docs] Roadmap: visão geral" -F body=@<corpo.md>`
   e depois `./scripts/open-pr.sh --update <pr>` para o `**Head:**`. O merge do PR é a aprovação.

### Modo 2: `/planejar M<n>` → um milestone (etapa 2)

0. **Pré-condições.**
   - O milestone existe na seção Milestones do `docs/roadmap.md` (se não, sugira o Modo 1).
   - O anterior está **encerrado** pelo `/fechar`: o milestone `M<n-1>` fechado no GitHub, com
     `Critério de saída: confirmado` na descrição
     (`gh api "repos/{owner}/{repo}/milestones?state=closed" -q '.[] | select(.title | startswith("M<n-1> ")) | .description'`).
     Para o M1, a descrição do M0 também diz `go/no-go: go`. Para o M0, basta o roadmap mergeado
     (a issue de setup já existe).
   - Se não, **pare**: "só planejo o milestone que for o próximo".
1. Releia o `roadmap.md`, o PRD, as specs, os ADRs e **o que mudou desde o milestone anterior**:
   `git log` do milestone anterior, issues de follow-up `prio:baixa` sem linha no roadmap
   (`gh api "repos/{owner}/{repo}/issues?state=open&labels=prio:baixa"`) e os `> Pendente:` que sobraram.
   Leia também, na seção "Para o /planejar" do `docs/preparo.md`, as linhas de **"Trabalho a
   construir"** cujas features entram neste milestone: elas entram na quebra em issues.
2. Escreva `docs/milestones/m<n>.md` a partir de `docs/milestones/_template.md`, curto. AC novo
   de feature nasce na spec da feature (`AC-F<n>-NN`, próximo ID livre); o doc só referencia.
3. Quebre em **issues pequenas** (uma por feature ou tela), cada uma com: título `[feat] ...`,
   área, links para o doc do milestone e a spec, ACs, prioridade (se pedida), posição no roadmap e
   **"Como verificar"** (teste automatizado, fluxo manual, plataformas; se precisa de print →
   `type:design`). Corpo no formato de `docs/prompts/issue-feature.md`. Follow-ups `prio:baixa`
   que entram neste milestone vão com `./scripts/new-issue.sh --existing <N>`. Issue que veio de
   uma linha de "Trabalho a construir" cita a fonte no corpo (`Fonte: <arquivo §seção>`, em Contexto).
4. Mostre o doc e a lista de issues e **pare** até o "pode seguir". Nada é criado antes.
5. Depois do ok, numa branch `plan/m<n>` a partir da `main` atualizada:
   1. o encerramento do milestone anterior, a partir da descrição dele no GitHub: o doc
      `docs/milestones/m<n-1>.md` com `status: encerrado` (vira histórico) e, no M1, o ADR `Aceita`
      do go/no-go do M0 (`docs/adr/NNNN-go-no-go-m0.md`, com o motivo), com o índice de
      `docs/adr/README.md` atualizado;
   2. specs novas ou alteradas e `docs/milestones/m<n>.md` (`status: planejado`);
   3. o milestone no GitHub: `./scripts/new-milestone.sh "M<n> — <nome>"` (idempotente; no M0 o
      `bootstrap.sh` já criou);
   4. as issues, na ordem:
      `./scripts/new-issue.sh --title "[feat] ..." --body-file <corpo.md> --milestone "M<n> — <nome>" --labels "type:feature,area:<x>" [--after <N>]`
      (o script também escreve a linha `todo` no roadmap, em "Issues por milestone");
   5. se o escopo mudou, atualize a seção Milestones do `roadmap.md` no mesmo PR;
   6. commit (`docs: planejar M<n>`), push e PR só de docs `[docs] Planejar M<n>`, como no Modo 1
      (`gh api .../pulls` + `./scripts/open-pr.sh --update <pr>`);
   7. `./scripts/sync-board.sh --auto` (sem board acessível, ele avisa e segue). Não adicione
      cards nem campos à mão.

## Onde parar

- Modo 1: depois de mostrar a seção Milestones (esperando o "pode seguir") e com o PR
  `[docs] Roadmap: visão geral` aberto. Passe o link e o comando de merge
  (`./scripts/merge.sh <pr> <head>`). Próximo passo: merge e `/planejar M0`.
- Modo 2: depois de mostrar o doc e as issues (esperando o "pode seguir") e com o PR
  `[docs] Planejar M<n>` aberto. Passe o link, as issues criadas (número, título, posição) e o
  comando de merge. Próximo passo: merge e `/implementar`.

## Nunca

- Abrir issues ou criar milestone no GitHub de um milestone que não é o próximo.
- No Modo 1: criar issue, milestone no GitHub ou spec.
- Criar qualquer coisa (branch, arquivo, issue, milestone) antes do "pode seguir".
- Usar os subcomandos do gh que usam GraphQL para issues: issues só com `./scripts/new-issue.sh`.
- Mexer no board à mão: ele só muda pelo `./scripts/sync-board.sh`.
- Inventar requisito: o que falta vira `> Pendente:` ou `TODO:`. Reaproveitar ID de feature ou de AC.
- Misturar código num PR de planejamento, ou dar push na `main`.
- Alterar a seção "Para o /planejar" do `docs/preparo.md`: ela é registro do material importado.
