---
description: Prepara os docs do projeto antes do /planejar - inventaria o material, organiza os arquivos e entrevista o usuário até nada travar
argument-hint: "[pasta do material, padrão _import/]"
---

# /preparar $ARGUMENTS

## Papel

Analista e redator de docs. Descobre quais docs o projeto já tem, o que falta, organiza o
material em `docs/` e preenche as lacunas entrevistando o usuário. Não escreve código e não cria
issues. Fluxo:
`/preparar` → merge → `/planejar` (visão geral) → merge → `/planejar M0` → merge → ciclo das tasks do M0 → `/fechar` (go/no-go) → `/planejar M1` → ciclo → `/fechar` → `/planejar M2` ….

O estado fica em `docs/preparo.md` (checklist de 15 itens, `fase` no frontmatter). Parar a
qualquer momento é seguro: o próximo `/preparar` retoma por ele.

## Argumentos

`$ARGUMENTS` = a pasta do material a importar (opcional; padrão `_import/`). Se ela estiver vazia
ou não existir, o passo "Material vazio" da Fase 1 decide: com `docs/` já preenchido, o inventário
olha só `docs/`; sem nada, o comando para e pergunta.

## Passos

Sempre na branch `prep/docs`: `git switch prep/docs` se existir (local ou em `origin`), senão
`git switch main && git pull && git switch -c prep/docs`.

### Fase 1: inventário (só leitura)

1. Leia `docs/preparo.md`. Se a `fase` for `entrevista`, pule para a **Fase 3** (retomada); se for
   `pronto`, diga que o preparo terminou e sugira o merge do PR, o `/planejar` (visão geral) e
   depois o `/planejar M0`.
2. **Material vazio.** Só quando a `fase` é `inventario` (na retomada, `entrevista`, e em
   `pronto` este passo não roda). A pasta (padrão `_import/`) está **vazia** se não existe ou só
   tem `.gitkeep`, README e arquivos ocultos. O `docs/` está **sem conteúdo** se `prd.md`,
   `overview.md` e `design/design-system.md` ainda são os do template (placeholders `<…>` ou sem
   alteração) e não há specs nem ADRs além dos templates.
   - **Pasta vazia e `docs/` sem conteúdo** → não siga. Diga em uma frase que não achou nada,
     nomeando a pasta procurada (ex.: "não encontrei nada em `_import/`, e os docs ainda são o
     template"), e pergunte, com `AskUserQuestion` quando disponível:
     1. **Vou adicionar os arquivos (Recomendado):** copie para a pasta ou mande no próximo chat
        (anexados). O que costuma entrar: PRD, design system (md ou PDF), telas, demo, notas.
     2. **Seguir sem material:** entrevista do zero.
     3. **Usar outra pasta:** o usuário informa o caminho.
   - **Pasta vazia, mas `docs/` já tem conteúdo** → siga e diga que o inventário vai olhar só `docs/`.
   - **`$ARGUMENTS` aponta para uma pasta que não existe** → diga isso, nomeando o caminho, e
     ofereça as mesmas três opções.

   Depois da resposta:
   - **Vou adicionar:** pare e espere. Quando o usuário mandar os arquivos no chat, salve-os em
     `_import/` com os nomes originais (sem reescrever) e confirme a lista ("salvei N arquivos em
     `_import/`: …"). Se ele disser que copiou na pasta, releia-a. Aí continue do passo 3.
   - **Seguir sem material:** marque todos os itens do checklist como `falta` e vá para a Fase 2
     com o relatório mostrando que tudo `falta`. Quando o checklist for gravado (Fase 2, passo 6),
     a primeira linha do Registro da entrevista diz `sem material`. A entrevista começa pelos
     itens 1 e 2 (visão e features).
   - **Usar outra pasta:** use-a como a pasta do material daqui em diante e refaça este passo.

   Sem ninguém para responder (sessão não interativa): pare com a mesma mensagem e não invente
   nada. Nunca avance para o relatório sem material e sem a resposta do usuário.
3. Leia todo o material da pasta (md, PDF, imagens, HTML da demo) e o que já existe em `docs/`.
4. Para cada item do checklist, defina o status (`tem`, `parcial`, `falta`, `n/a`) e a evidência
   (`arquivo §seção`). Um arquivo pode cobrir vários itens.
5. Anote as contradições entre fontes (ex.: o PRD diz web, a demo é mobile).
6. Liste os trechos do material sobre **fases, milestones, ordem de entrega** e **trabalho a
   construir** (planos de entrega, listas de tarefas, backlog), cada um com a fonte
   (`arquivo §seção`) e a feature `F#` quando casar. Eles vão para a seção "Para o /planejar" do
   `docs/preparo.md`, sem decidir nada.

### Fase 2: relatório + plano de organização

1. Mostre a tabela do checklist preenchida, com os itens que travam primeiro.
2. Mostre o plano de organização dos arquivos: origem → destino → ação (**mover**,
   **reescrever no template**, **dividir**, **mesclar**, **não importar**), pelo mapa abaixo.
3. Mostre a lista de trechos para a seção "Para o /planejar" (as duas tabelas: fases, milestones e
   ordem de entrega; trabalho a construir).
4. Mostre as contradições e a ordem da entrevista.
5. **Pare** e pergunte: "posso organizar os arquivos e começar a entrevista?". Ajuste o plano
   até o "pode seguir".
6. Depois da aprovação: organize os arquivos (`git mv` quando só mudam de lugar), grave o
   checklist com `fase: entrevista` e `updated:` de hoje, grave a lista na seção
   "Para o /planejar" do `preparo.md` e faça tudo num commit
   (`docs: inventário e organização do material`).

### Fase 3: entrevista (rodadas)

Na retomada (`fase: entrevista`), pergunte só o que está `falta` ou `parcial` no `preparo.md`;
o que está `tem` ou `n/a` não volta.

1. Ordem: primeiro as contradições, depois os itens `trava` (`falta` antes de `parcial`) e por
   fim os itens `ajuda`, se o usuário quiser.
2. Cada rodada tem **no máximo 4 perguntas**, via `AskUserQuestion` quando disponível:
   - quando o material permite um palpite, faça uma pergunta de múltipla escolha com o palpite
     como primeira opção "(Recomendado)" e cite a evidência;
   - em decisão técnica, dê 2–3 opções com prós e contras curtos. A escolha vira um ADR em
     `docs/adr/` (`Aceita` se o usuário decidiu; `Proposta` se ficou "decido depois"), com o
     índice de `docs/adr/README.md` atualizado;
   - em fluxo de usuário, pergunte o que acontece no erro, no vazio e no carregando de cada tela
     Must, não só no caminho feliz;
   - pergunte sobre o que o material diz, nunca o que você já sabe;
   - não pergunte sobre ordem de entrega nem quebre trabalho em tarefas (isso é do `/planejar`):
     só pergunte sobre um trecho da seção "Para o /planejar" se ele for contraditório ou ilegível.
3. Respostas:
   - resposta concreta → escreva no destino (template, frontmatter) e marque `tem` ou `parcial`;
   - "não sei ainda" → `> Pendente: <pergunta>` no destino; o item fica `parcial`;
   - "não se aplica" → `n/a`, com o motivo em Em aberto.
4. Ao fim de cada rodada: atualize o `preparo.md` (status, Em aberto, `updated:` e uma linha no
   Registro da entrevista), faça commit (`docs: preparo, rodada <n>`) e mostre um resumo de uma
   linha por item tocado.
5. **Pare** e pergunte: "mais uma rodada ou paramos aqui?".

### Fase 4: pronto

Quando todos os itens `trava` estiverem `tem` ou `n/a` (ou `parcial` só por `> Pendente:`, se o
usuário aceitar):

1. Marque `fase: pronto` no `preparo.md` e faça commit.
2. Rode `./scripts/bootstrap.sh` (labels `area:*` da tabela Features). Numa sessão na nuvem ele
   não funciona: peça ao usuário para rodar localmente.
3. `git push -u origin prep/docs` e abra um PR só de docs, `[docs] Preparo do projeto`, pelo
   template (sem `Closes`, `**Tipo:** só docs`, testes e prints `n/a: PR só de docs`):
   `gh api repos/{owner}/{repo}/pulls -f head=prep/docs -f base=main -f title="[docs] Preparo do projeto" -F body=@<corpo.md>`
   e depois `./scripts/open-pr.sh --update <pr>` para gravar o `**Head:**`.
4. Relatório final:
   - o que foi criado (arquivos e de onde veio cada um);
   - os ADRs e o status de cada um;
   - os `> Pendente:` que sobraram, por arquivo;
   - os itens `ajuda` em aberto;
   - quantas linhas ficaram em cada tabela da seção "Para o /planejar" (fases e ordem de entrega;
     trabalho a construir);
   - o próximo passo: merge do PR (`./scripts/merge.sh <pr> <head>`), depois `/planejar` (visão
     geral dos milestones no roadmap) e, com esse PR mergeado, `/planejar M0`.

## Mapa: material → destino

| Material | Destino |
|---|---|
| Resumo do projeto, stack, arquitetura, glossário, modelo de dados | `docs/overview.md` |
| Visão, público, escopo, prioridades (MoSCoW), lista de features, métricas | `docs/prd.md` (features ganham IDs `F<n>`) |
| Como uma feature funciona (telas, estados, regras, AC, textos) | `docs/specs/<feature>.md` |
| Decisão técnica (escolha de stack, padrão, trade-off) | `docs/adr/NNNN-<slug>.md` |
| Cores, tipografia, espaçamento, componentes | `docs/design/design-system.md` e `tokens.json` |
| Tela aprovada, mockup | `docs/assets/screens/` |
| Referência visual, logo, moodboard | `docs/assets/design/` |
| Dispositivos, tamanhos de tela, regras de teste e prints | `docs/qa/print-rules.md` |
| Funcionalidade ou trabalho a construir; fases, milestones, ordem de entrega | **não aqui**: vai para a seção Para o /planejar do `docs/preparo.md` (o `/planejar` decide) |

## Regras de importação

- Não invente conteúdo. O que faltar para preencher o template vira `TODO: <o que falta>`;
  ambiguidade ou decisão adiada vira `> Pendente: <pergunta>`.
- Use os templates (`docs/specs/_template.md`, `docs/adr/_template.md`) e mantenha o frontmatter.
- Feature recebe o próximo ID `F<n>` livre; AC, o próximo `AC-F<n>-NN` da feature. IDs nunca são
  reaproveitados.
- ADRs recebem o próximo número livre; o status segue a resposta do usuário (`Aceita` ou
  `Proposta`). Atualize o índice em `docs/adr/README.md`.
- Milestones e ordem de entrega não são decididos aqui: o material sobre isso vai para a seção
  Para o /planejar do `docs/preparo.md`; o `/planejar` lê de lá e escreve a seção Milestones do
  `roadmap.md` (o PRD só aponta para ela).
- Um doc pode virar vários destinos; vários docs podem virar um. Trechos sem destino, pergunte.
- Os originais que foram reescritos ficam em `docs/assets/originais/` ou são apagados, como o
  usuário decidir no plano.

## Onde parar

- Fim da Fase 2: plano mostrado, esperando o "pode seguir".
- Fim de cada rodada da Fase 3: resumo mostrado, esperando "mais uma rodada ou paramos aqui?".
- Fim da Fase 4: PR `[docs] Preparo do projeto` aberto e relatório final entregue.

## Nunca

- Inventar conteúdo (requisito, decisão, texto de interface, valor de token).
- Seguir para o relatório sem material e sem a resposta do usuário (passo "Material vazio").
- Criar issues: isso é do `/planejar`.
- Organizar, mover ou reescrever arquivos antes do "pode seguir" da Fase 2.
- Fazer mais de 4 perguntas numa rodada, ou emendar rodadas sem perguntar se continua.
- Perguntar de novo o que já está `tem` ou `n/a` no `preparo.md`.
- Trabalhar fora da branch `prep/docs` ou dar push na `main`.
