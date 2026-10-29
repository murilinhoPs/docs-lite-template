---
name: importar-docs
description: Importa documentos que já existem (briefings, specs, notas, decisões, imagens) para a estrutura de docs/ e cria as issues do trabalho a fazer. Pergunta o que é cada doc, apresenta um plano de organização, ajusta o plano com o usuário e só então executa. Use quando o usuário pedir para importar, organizar ou migrar docs existentes para este projeto.
---

# Importar docs existentes

O mapa "tipo de material → destino" e as regras de importação estão na seção
**Ao pedir "importe meus docs"** do `CLAUDE.md`. Esta skill é o passo a passo interativo.

Nada é criado, movido ou apagado (nem issues no GitHub) antes da aprovação do plano (passo 4).

Lembre o modelo: o PRD lista as features (`F<n>`), a spec diz como cada feature funciona hoje
(com os AC vigentes), a issue é o trabalho a fazer e o roadmap dá a ordem das issues.

## 1. Contexto

1. Leia `CLAUDE.md`, `docs/README.md` e os templates: `docs/overview.md`, `docs/prd.md`,
   `docs/roadmap.md`, `docs/specs/_template.md`, `docs/adr/README.md`, `docs/adr/_template.md`,
   `docs/design/design-system.md` e os corpos de issue em `docs/prompts/issue-*.md`.
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
- se decisões técnicas encontradas já estão `Aceita` ou ainda são `Proposta`;
- o que fazer com os originais depois da importação (manter fora de `docs/` ou apagar).

## 3. Plano

Apresente o plano numa tabela, uma linha por destino:

| Origem | Destino | Ação | Observações |
|---|---|---|---|
| `briefing.md` (seção Visão) | `docs/prd.md` → Visão | reescrever no template | |
| `briefing.md` (seção Stack) | `docs/overview.md` → Stack | reescrever no template | vira ADR 0001? |
| `features.txt` | `docs/prd.md` → Features (F1–F4) + `docs/specs/auth.md`, `docs/specs/perfil.md` | dividir | AC viram `AC-F1-01`… |
| `features.txt` (o que falta construir) | 4 issues `[feat]` no M1 | criar issues | depois da aprovação |
| `tela-login.png` | `docs/assets/screens/login.png` | mover | |
| `notas-reuniao.md` | — | não importar | sem conteúdo duradouro |

Ações possíveis: **mover** (arquivo vai como está), **reescrever no template**,
**dividir** (um doc vira vários), **mesclar** (vários docs viram um), **criar issues**,
**não importar**.

Abaixo da tabela, liste:

- features com ID (`F<n>`), prioridade, spec e área;
- issues na ordem em que entrarão no `roadmap.md`: título (`[feat] ...`), milestone, labels e
  os AC (da spec) que cada uma cobre;
- ADRs com número e status (`Proposta`, salvo se o usuário disse que já estão aceitos);
- lacunas que vão virar `TODO`;
- o que acontece com os originais.

## 4. Ajustes

Pergunte: **"Quer mudar algum doc de lugar, a ordem das issues ou qualquer outra coisa
antes de eu começar?"**. Aplique as mudanças pedidas, mostre o plano atualizado e repita
até o usuário aprovar explicitamente. Não comece sem um "pode seguir" (ou equivalente).

## 5. Execução

A execução segue o mesmo caminho do `/planejar` (`.claude/commands/planejar.md`, passo 4):
proposta aprovada → specs + issues + roadmap num PR só de docs.

1. Siga o plano aprovado e as regras de importação do `CLAUDE.md`, numa branch nova a partir da
   `main` atualizada: `git switch -c plan/importacao`.
2. Use `git mv` para arquivos que só mudam de lugar, para manter o histórico.
3. Escreva PRD (tabela Features), specs e ADRs (atualize o índice em `docs/adr/README.md`).
4. Crie as issues aprovadas, na ordem do plano, com `./scripts/new-issue.sh` (corpo no formato
   de `docs/prompts/issue-feature.md`). O script cria a issue pela API REST do repo e insere a
   linha no roadmap. Se um milestone não existir no GitHub, crie antes com
   `gh api repos/{owner}/{repo}/milestones -f title="<milestone>"`.
5. Ao terminar, confira: todo link em `docs/README.md`, `docs/prd.md` e `docs/roadmap.md` aponta
   para um arquivo existente, toda spec citada numa issue existe, todo AC citado numa issue
   existe na spec, e os milestones do roadmap batem com os de `scripts/bootstrap.sh`.
6. Faça o commit (`docs: importa docs existentes`), `git push -u origin plan/importacao` e abra
   o PR só de docs como no `/planejar`
   (`gh api repos/{owner}/{repo}/pulls ... -F body=@<corpo.md>` e depois
   `./scripts/open-pr.sh --update <pr>` para o `**Head:**`). O merge é do usuário.

## 6. Relatório

Diga ao usuário:

- o que foi para onde (a tabela final), as issues criadas, com número, e o link do PR;
- os `TODO` que ficaram, por arquivo;
- o que não foi importado e por quê;
- próximos passos (ex.: revisar o PRD, aceitar os ADRs, criar as labels `area:*` novas
  rodando `./scripts/bootstrap.sh` localmente).
