# Guia do processo

Resumo para pessoas de como este template funciona. A fonte do processo é o
[`CLAUDE.md`](../CLAUDE.md) e os comandos de [`.claude/commands/`](../.claude/commands/): se este
guia divergir deles, vale o que está lá. Os detalhes de uso (bootstrap, board, merge gate, erros,
atualização a partir do template) ficam no [`README.md`](../README.md).

## 1. O modelo: onde fica cada coisa

| O quê | Onde |
|---|---|
| Visão, escopo, features (`F1`, `F2`…, com MoSCoW) | `docs/prd.md` |
| Como cada feature funciona **hoje**, com os ACs vigentes (`AC-F<n>-NN`) | `docs/specs/<feature>.md` |
| Decisões técnicas, com índice e status (`Proposta`, `Aceita`, `Superada`, `Revertida`) | `docs/adr/` |
| Trabalho a fazer | **Issues do GitHub** (a issue é a task; o número dela é o ID) |
| Visão geral dos milestones e ordem e status das issues | `docs/roadmap.md` |
| Plano do milestone em andamento | `docs/milestones/m<n>.md` |
| Checklist do preparo, notas do material para o `/planejar` e registro da entrevista | `docs/preparo.md` |
| Material a importar (fora do git; limpo no fim do `/preparar`, com o seu "sim") | `_import/` |
| PDFs de referência (design system, telas) | `docs/design/` (os agentes leem os `.md`) |
| Imagens (prints, telas, mockups, logo, moodboard) | `docs/assets/design/` |
| Board do Projects | espelho do roadmap; nunca é editado à mão |

- A spec descreve o presente; a issue descreve a mudança; o PR que muda comportamento atualiza a spec.
- PDFs e imagens são referência para pessoas: os agentes leem os `.md`, e um PDF só é guardado
  depois de o conteúdo dele estar no `.md` correspondente.
- IDs de feature e de AC nunca são reaproveitados. ADR `Aceita` não é editado: um novo o substitui.
- A versão do PRD é uma tag `prd-vX.Y`; o texto dos docs não leva sha nem versão.
- O [`docs/README.md`](README.md) tem um exemplo de ponta a ponta: um AC saindo do PRD e passando
  por spec, issue, roadmap, PR e review até o `/fechar`.

## 2. O fluxo de um projeto novo

```
bootstrap.sh (local, uma vez)
→ /preparar → merge
→ /planejar (visão geral) → merge
→ /planejar M0 → merge
→ ciclo das tasks: /implementar → seu teste → (/qa) → /revisar local (opcional) → /abrir-pr
  → /revisar → /corrigir → merge → /fechar
→ /fechar no fim do M0 (go/no-go) → /planejar M1 → ciclo → …
```

## 3. Os comandos

Cada comando, em `.claude/commands/`, tem papel, argumentos, passos, onde parar e o que nunca fazer.

| Comando | O que faz |
|---|---|
| `/preparar [pasta]` | Lê o material de `_import/` e preenche o checklist de 15 itens do `preparo.md` (8 travam o planejamento, 7 ajudam). Registra o que o material diz sobre fases, ordem de entrega e trabalho a fazer em "Para o /planejar". Mostra o plano de organização e para; depois entrevista você em rodadas de até 4 perguntas (decisão técnica vira ADR; dúvida vira `> Pendente:`). É retomável e termina com o PR `[docs] Preparo do projeto`; depois pergunta se pode apagar o `_import/`. Sem material (pasta vazia e docs ainda no template, ou pasta inexistente), ele para e pergunta: você adiciona os arquivos (podem vir no chat e são salvos em `_import/`), segue sem material ou indica outra pasta. |
| `/planejar` | Escreve a visão geral de todos os milestones no roadmap, partindo das fases registradas pelo `/preparar`, com a fonte e as divergências. Não cria nada no GitHub. O M0 é sempre "Fundação e spike", com go/no-go. |
| `/planejar M<n>` | Só para o **próximo** milestone (o anterior encerrado): escreve o doc do milestone e os ACs nas specs, propõe as issues (usando o trabalho registrado) e para. Depois do seu ok, cria o milestone e as issues e abre o PR `[docs] Planejar M<n>`, que também registra o encerramento do milestone anterior. |
| `/implementar [issue]` | Retoma a task `doing` ou pega a primeira `todo`, confere que a anterior está fechada, cria `task/<N>-<slug>`, marca `doing` e implementa com testes, com commits locais e sem push. **Hotfix:** com outra task em andamento, confirma com você, guarda a task atual num commit `wip:` local, põe o hotfix logo depois da última `done` e, depois do `/fechar` dele, retoma a task interrompida. |
| `/qa [issue]` | Tester, sem corrigir código: testa cada AC e salva prints em `pr-assets/issue-<N>/<sha7>/`. |
| `/abrir-pr [issue]` | Sem argumento, descobre a issue e o PR pelo `task-atual.sh` (para se houver dúvida). Marca `done`, dá push e abre o PR (ou atualiza o que já existe) com o head no corpo e o comando de merge pronto. |
| `/revisar [pr \| local]` | O subagente `revisor` (só leitura, contexto limpo) revisa com Bloqueante, Deveria e Nit. Modo PR: posta um review `COMMENT` travado no head. Modo local (`/revisar local`, ou a branch sem PR): revisa `git diff origin/main...HEAD` antes do PR e devolve o review só na conversa, com os checks como `n/a (sem PR)`. |
| `/corrigir [pr ou issue]` | Corrige só o que foi apontado, atualiza o PR e diz se você precisa testar de novo. |
| `/fechar [pr]` | Pós-merge: sync do board e nits que viram issue (se você aprovar). No fim do milestone, confere o critério de saída e o go/no-go e os guarda no milestone fechado. |
| `/ciclo [issue] \| fechar [pr]` | Atalho do ciclo da task (orquestrador): `/implementar`, depois os subagentes `revisor` (local) e `qa` em paralelo; para com os achados por severidade e corrige só o que você escolher (no máximo 2 voltas); abre o PR só com o seu "sim" e espera o merge; `fechar` roda o `/fechar`. |

**Em outros agentes** (Codex, opencode, Hermes, Cursor): o `AGENTS.md` manda seguir o
`CLAUDE.md`. Sem slash commands, o agente segue `.claude/commands/<x>.md`; sem subagentes, o
`/revisar` roda numa sessão nova.

## 4. Os scripts

Os scripts que o Claude roda usam só `gh api repos/{owner}/{repo}/...` e funcionam no Claude Code
local e na nuvem. A exceção é o `sync-board.sh`, que usa `gh project`.

| Script | O que faz |
|---|---|
| `bootstrap.sh` | Só local, uma vez por projeto: cria o milestone M0 e a issue de setup, as labels, o board (cópia do projeto modelo, com `Etapa` e `Ordem`), a branch `pr-assets`, a configuração do squash e o ruleset da `main` com os checks obrigatórios. Com `--sem-board`, pula o board e grava `BOARD=nao`. |
| `new-milestone.sh "M<n> — <nome>"` | Cria o milestone, sem duplicar. |
| `new-issue.sh` | Cria a issue e a linha `todo` no roadmap; `--existing <N>` põe no roadmap uma issue que já existe, e `--after` também move a linha. |
| `next-task.sh [<N>]` | Escolhe a task, confere a ordem e detecta o hotfix. |
| `task-atual.sh [<N>]` | Diz qual é a task, a branch e o PR (argumento, branch atual, linha `doing`, branch à frente da `main`); nunca chuta. |
| `task-status.sh <N> <todo\|doing\|done>` | Muda o status e sincroniza o board quando dá. |
| `open-pr.sh <N>` | Abre o PR pelo template e grava o número dele no roadmap; `--update <pr>` atualiza o Head e os prints depois de um push. |
| `merge.sh <pr> <head>` | Squash travado no head: o GitHub recusa se houve push depois da sua conferência. |
| `sync-board.sh` | Calcula a Etapa de cada card: issue fechada → `done`; PR aberto → `review`; `doing` ou `done` sem PR → `doing`; senão `todo`. |
| `limpar-import.sh [--apagar]` | Lista o `_import/`; com `--apagar`, apaga tudo menos o `.gitkeep` (o `/preparar` pergunta antes). |
| `atualiza-template.sh [--aplicar]` | Traz o processo novo do template para um projeto antigo, sem tocar nos arquivos do projeto. |
| `docs-only.sh`, `pr-gate.sh` | Auxiliares do merge gate. |

## 5. Merge gate

- Dois checks obrigatórios, num ruleset strict que também exige a branch atualizada com a `main`:
  - **`pr-gate`:** o `Head:` do corpo do PR tem que ser o head real, e os prints citados têm que
    valer para o código desse head (commits só de docs depois dos prints não os invalidam);
  - **`ci`:** os testes da stack (placeholder até a issue de setup); roda em todo PR e fica verde
    logo no início num PR só de docs.
- PR só de docs (tudo em `docs/` ou `*.md`, menos o `CLAUDE.md`) dispensa prints e QA.
- O merge é sempre seu: `./scripts/merge.sh <pr> <head>`.

## 6. Roadmap e board

- O `roadmap.md` tem duas seções: **Milestones** (prosa) e **Issues por milestone** (tabelas
  `| Ordem | Issue | Título | Status | Spec | PR |`).
- O roadmap guarda o destino de cada linha (`todo`, `doing`, `done`): o `/abrir-pr` já marca
  `done`, então nenhuma task precisa de um segundo PR. O board mostra o andamento real, lido do GitHub.
- O board é opcional: `./scripts/bootstrap.sh --sem-board` grava `BOARD=nao` e o sync diz "nada a
  sincronizar". Sem board, o andamento fica no roadmap, nos milestones e nas issues (veja "Board →
  Sem board" no `README.md`).
- Nunca existem issues, nem milestone no GitHub, de milestones futuros.
- O fim de um milestone não precisa de PR próprio: o `/fechar` guarda o encerramento no milestone
  do GitHub, e o PR do próximo `/planejar M<n+1>` o registra nos docs.

## 7. Onde está o resto

| Para | Veja |
|---|---|
| Começar um projeto, o board e o projeto modelo, o merge gate | [`README.md`](../README.md) |
| O que fazer quando algo dá errado (mensagens reais dos scripts) | `README.md`, "Quando algo dá errado" |
| Trazer o processo novo para um projeto antigo | `README.md`, "Atualizar a partir do template" |
| As regras que o agente segue | [`CLAUDE.md`](../CLAUDE.md) e [`.claude/commands/`](../.claude/commands/) |
| Templates | `docs/preparo.md`, `docs/milestones/_template.md`, `docs/specs/_template.md`, `docs/adr/`, `docs/prompts/issue-*.md`, `.github/ISSUE_TEMPLATE/`, `.github/pull_request_template.md` |
| Testes dos scripts | `./scripts/test/run.sh`, o fumaça `./scripts/test/smoke.sh` e a matriz `scripts/test/CA.md` |

## 8. Limites conhecidos

- O board é copiado do projeto modelo `murilinhoPs/2`: para outra conta usar o template, ele
  precisa estar público, ou a pessoa usa `BOARD_TEMPLATE=<owner>/<número>`.
- O `bootstrap.sh` e o `sync-board.sh` precisam do `gh` local com o escopo `project`; numa sessão
  na nuvem, o sync avisa e segue.
- Os comandos são prompts: os testes do repo conferem o texto deles, não uma execução real.
