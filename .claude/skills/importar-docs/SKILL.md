---
name: importar-docs
description: Importa documentos que já existem (briefings, specs, notas, decisões, imagens) para a estrutura de docs/. Pergunta o que é cada doc, apresenta um plano de organização, ajusta o plano com o usuário e só então executa. Use quando o usuário pedir para importar, organizar ou migrar docs existentes para este projeto.
---

# Importar docs existentes

O mapa "tipo de material → destino" e as regras de importação estão na seção
**Ao pedir "importe meus docs"** do `CLAUDE.md`. Esta skill é o passo a passo interativo.

Nada é criado, movido ou apagado antes da aprovação do plano (passo 4).

## 1. Contexto

1. Leia `CLAUDE.md`, `docs/README.md` e os templates: `docs/overview.md`, `docs/prd.md`,
   `docs/roadmap.md`, `docs/tasks/_template.md`, `docs/adr/_template.md`,
   `docs/design/design-system.md`.
2. Pergunte onde estão os docs a importar, se o usuário não disse (pasta, arquivos anexados,
   links). Liste o que encontrou e confirme que é tudo.

## 2. Inventário e perguntas

Leia cada doc inteiro. Para cada um, monte um palpite:

- o que ele é (tipo do mapa no `CLAUDE.md`);
- se ele cobre mais de um tipo (ex.: um briefing com visão + stack + lista de features);
- trechos ambíguos ou que não se encaixam em nada.

Depois **pergunte ao usuário o que é cada doc**. Use `AskUserQuestion` quando disponível
(até 4 docs por chamada, uma pergunta por doc), com o seu palpite como primeira opção
marcada "(Recomendado)" e o resto do mapa como alternativas. Sem essa ferramenta, pergunte
em texto, numa lista numerada, com o palpite ao lado de cada doc.

Pergunte também, quando relevante:

- quais milestones o projeto tem, se os docs sugerem mais que `M0 Fundação` e `M1 MVP`;
- se decisões técnicas encontradas já estão aceitas ou ainda são propostas;
- o que fazer com os originais depois da importação (manter fora de `docs/` ou apagar).

## 3. Plano

Apresente o plano numa tabela, uma linha por destino:

| Origem | Destino | Ação | Observações |
|---|---|---|---|
| `briefing.md` (seção Visão) | `docs/prd.md` → Visão | reescrever no template | |
| `briefing.md` (seção Stack) | `docs/overview.md` → Stack | reescrever no template | vira ADR 0001? |
| `features.txt` | `docs/tasks/002-...` a `005-...` | dividir em tasks | 4 tasks no M1 |
| `tela-login.png` | `docs/assets/screens/login.png` | mover | |
| `notas-reuniao.md` | — | não importar | sem conteúdo duradouro |

Ações possíveis: **mover** (arquivo vai como está), **reescrever no template**,
**dividir** (um doc vira vários), **mesclar** (vários docs viram um), **não importar**.

Abaixo da tabela, liste:

- tasks na ordem em que entrarão no `roadmap.md`, com milestone;
- ADRs com número e status proposto;
- lacunas que vão virar `TODO`;
- o que acontece com os originais.

## 4. Ajustes

Pergunte: **"Quer mudar algum doc de lugar, a ordem das tasks ou qualquer outra coisa
antes de eu começar?"**. Aplique as mudanças pedidas, mostre o plano atualizado e repita
até o usuário aprovar explicitamente. Não comece sem um "pode seguir" (ou equivalente).

## 5. Execução

1. Siga o plano aprovado e as regras de importação do `CLAUDE.md`.
2. Use `git mv` para arquivos que só mudam de lugar, para manter o histórico.
3. Ao terminar, confira: todo link em `docs/README.md` e `docs/roadmap.md` aponta para um
   arquivo existente, toda task listada no roadmap existe em `docs/tasks/` e vice-versa,
   e os milestones do roadmap batem com os de `scripts/bootstrap.sh`.
4. Faça um commit local: `docs: importa docs existentes`. Não dê push.

## 6. Relatório

Diga ao usuário:

- o que foi para onde (a tabela final);
- os `TODO` que ficaram, por arquivo;
- o que não foi importado e por quê;
- próximos passos (ex.: revisar o PRD, aceitar os ADRs, rodar `./scripts/bootstrap.sh`
  se os milestones mudaram).
