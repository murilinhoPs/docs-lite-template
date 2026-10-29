---
description: Prepara os docs do projeto antes do /planejar - inventaria o material, organiza os arquivos e entrevista o usuário até nada travar
argument-hint: "[pasta do material, padrão _import/]"
---

# /preparar $ARGUMENTS

## Papel

Analista e redator de docs. Descobre quais docs o projeto já tem, o que falta, organiza o
material em `docs/` e preenche as lacunas entrevistando o usuário. Não escreve código e não cria
issues. Fluxo: `/preparar` (até nada travar) → `/planejar` → ciclo das tasks.

O estado fica em `docs/preparo.md` (checklist de 15 itens, `fase` no frontmatter). Parar a
qualquer momento é seguro: o próximo `/preparar` retoma por ele.

## Argumentos

`$ARGUMENTS` = a pasta do material a importar (opcional; padrão `_import/`). Pode estar vazia
ou não existir: aí o inventário olha só o que já está em `docs/`.

## Passos

Sempre na branch `prep/docs`: `git switch prep/docs` se existir (local ou em `origin`), senão
`git switch main && git pull && git switch -c prep/docs`.

### Fase 1: inventário (só leitura)

1. Leia `docs/preparo.md`. Se a `fase` for `entrevista`, pule para a **Fase 3** (retomada); se for
   `pronto`, diga que o preparo terminou e sugira o merge do PR e o `/planejar M1`.
2. Leia todo o material da pasta (md, PDF, imagens, HTML da demo) e o que já existe em `docs/`.
3. Para cada item do checklist, defina o status (`tem`, `parcial`, `falta`, `n/a`) e a evidência
   (`arquivo §seção`). Um arquivo pode cobrir vários itens.
4. Anote as contradições entre fontes (ex.: o PRD diz web, a demo é mobile).

### Fase 2: relatório + plano de organização

1. Mostre a tabela do checklist preenchida, com os itens que travam primeiro.
2. Mostre o plano de organização dos arquivos: origem → destino → ação (**mover**,
   **reescrever no template**, **dividir**, **mesclar**, **não importar**), pelo mapa abaixo.
3. Mostre as contradições e a ordem da entrevista.
4. **Pare** e pergunte: "posso organizar os arquivos e começar a entrevista?". Ajuste o plano
   até o "pode seguir".
5. Depois da aprovação: organize os arquivos (`git mv` quando só mudam de lugar), grave o
   checklist com `fase: entrevista` e `updated:` de hoje, e faça commit
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
   - pergunte sobre o que o material diz, nunca o que você já sabe.
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
   - o próximo passo: merge do PR (`./scripts/merge.sh <pr> <head>`) e depois `/planejar M1`.

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
| Funcionalidade ou trabalho a construir | **não aqui**: fica anotado para o `/planejar` (issues) |

## Regras de importação

- Não invente conteúdo. O que faltar para preencher o template vira `TODO: <o que falta>`;
  ambiguidade ou decisão adiada vira `> Pendente: <pergunta>`.
- Use os templates (`docs/specs/_template.md`, `docs/adr/_template.md`) e mantenha o frontmatter.
- Feature recebe o próximo ID `F<n>` livre; AC, o próximo `AC-F<n>-NN` da feature. IDs nunca são
  reaproveitados.
- ADRs recebem o próximo número livre; o status segue a resposta do usuário (`Aceita` ou
  `Proposta`). Atualize o índice em `docs/adr/README.md`.
- Milestone novo entra no `roadmap.md`, na tabela do `prd.md` e na lista do `scripts/bootstrap.sh`.
- Um doc pode virar vários destinos; vários docs podem virar um. Trechos sem destino, pergunte.
- Os originais que foram reescritos ficam em `docs/assets/originais/` ou são apagados, como o
  usuário decidir no plano.

## Onde parar

- Fim da Fase 2: plano mostrado, esperando o "pode seguir".
- Fim de cada rodada da Fase 3: resumo mostrado, esperando "mais uma rodada ou paramos aqui?".
- Fim da Fase 4: PR `[docs] Preparo do projeto` aberto e relatório final entregue.

## Nunca

- Inventar conteúdo (requisito, decisão, texto de interface, valor de token).
- Criar issues: isso é do `/planejar`.
- Organizar, mover ou reescrever arquivos antes do "pode seguir" da Fase 2.
- Fazer mais de 4 perguntas numa rodada, ou emendar rodadas sem perguntar se continua.
- Perguntar de novo o que já está `tem` ou `n/a` no `preparo.md`.
- Trabalhar fora da branch `prep/docs` ou dar push na `main`.
