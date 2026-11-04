# Matriz CA → teste

Cada critério de aceite das Partes A a H e a verificação que o cobre. "run" = uma verificação de
`./scripts/test/run.sh` (o texto entre aspas é o nome que ela imprime); "fumaça" =
`./scripts/test/smoke.sh` (também rodado pelo `run.sh`); "manual" = sem teste automatizado, com o
comando que confere.

Rodar tudo: `./scripts/test/run.sh` (precisa de `bash`, `git`, `jq`, `yq` e `python3` com `yaml`).

## Partes A e B (modelo v2 + compatível com a nuvem)

| CA | O que | Cobertura |
|---|---|---|
| CA-1 | Nenhum comando gh de GraphQL nos docs e scripts (exceto `bootstrap.sh`) | run: "nenhum comando gh de GraphQL nos docs e scripts" |
| CA-2 | Nada cita a pasta antiga de tasks | run: "nenhuma referência à pasta antiga de tasks" |
| CA-3 | Teste com `gh` simulado de `new-issue.sh`, `open-pr.sh`, `task-status.sh`, `sync-board.sh`: só rotas do repo, roadmap na posição certa | run: seções `new-issue.sh`, `task-status.sh`, `open-pr.sh`, `sync-board.sh (D3)` ("só rotas repos/acme/proj e nada de GraphQL", "fim do milestone e --after, com Ordem renumerada") |
| CA-4 | `bash -n` nos scripts; workflows em YAML válido | run: "bash -n em todos os scripts", "workflows e issue forms são YAML válido (CA-4)". `actionlint`: manual (não instalado aqui) |
| CA-5 | Action de sync verde sem `board.conf`/token | **removido na Parte D** (o Action de sync saiu; o sync é local) |
| CA-6 | Templates: spec, índice de ADR, Features no PRD, PR template | run: "templates da Parte A: spec, índice de ADR, Features no PRD, PR template (CA-6)" |
| CA-7 | `CLAUDE.md`, comandos e prompt descrevem o mesmo fluxo | run: "mesmo fluxo /preparar → /planejar → /planejar M0 → ciclo em todos os docs (CA-E5, CA-G8)" |
| CA-8 | Fluxo local: com `board.conf`, o sync roda | run: "--auto com acesso ao Projects sincroniza (fluxo local, CA-8)" |

## Parte C (merge gate)

| CA | O que | Cobertura |
|---|---|---|
| CA-C1 | `pr-gate` falha com Head divergente e com prints de outro commit, e passa quando bate | run: seção `pr-gate.sh (CA-C1)`; fumaça: passo 6 |
| CA-C2 | `bootstrap.sh` aplica o squash e o ruleset strict com `ci` e `pr-gate` | run: "squash com título e corpo do PR", "ruleset com ci e pr-gate obrigatórios, strict" |
| CA-C3 | `ci.yml` sem filtro de paths, verde em PR só de docs | run: "ci roda em todo pull_request, sem filtro de paths", "PR só de docs: ci verde logo no início" |
| CA-C4 | Só docs trata o `CLAUDE.md` como código | run: "CLAUDE.md conta como código" |
| CA-C5 | Review só por REST e nunca `APPROVE` | run: "review: todo comando gh é gh api repos/{owner}/{repo}/...", "review: posta com -f event=COMMENT, nunca APPROVE nem REQUEST_CHANGES" |
| CA-C6 | README cita os checks obrigatórios e o `open-pr.sh --update` | run: "README: checklist cita os checks obrigatórios e o open-pr.sh --update (CA-C6)" |

## Parte D (comandos)

| CA | O que | Cobertura |
|---|---|---|
| CA-D1 | 7 comandos (8 com o `/preparar`) com papel, argumentos, passos, onde parar e nunca; `revisor` existe | run: "comando /<nome> com papel, argumentos, passos, onde parar e nunca (CA-D1)" ×8 |
| CA-D2 | `revisor` sem Edit/Write, proíbe `--approve` e `--request-changes` | run: "subagente revisor existe, sem Edit nem Write (CA-D2)", "revisor proíbe --approve e --request-changes e usa event=COMMENT" |
| CA-D3 | As quatro regras de Etapa do sync | run: "1. issue fechada → done" … "4. senão → todo"; fumaça: passos 7 e 8 |
| CA-D4 | Nada cita a label de doing, o token, o workflow de sync, nem `review` como status do roadmap | run: "nada cita a label, o token nem o workflow de sync removidos (CA-D4)", "roadmap só com todo, doing e done (CA-D4)" |
| CA-D4b | Testes de `new-issue`, `open-pr`, `task-status` passando com 3 status | run: a suíte toda ("status done no roadmap", "review não é status do roadmap") |
| CA-D5 | Mesmo fluxo em `CLAUDE.md`, comandos, prompt | run: "mesmo fluxo … (CA-E5, CA-G8)" |
| CA-D6 | `AGENTS.md` aponta para o `CLAUDE.md` | run: "AGENTS.md é arquivo normal que manda seguir o CLAUDE.md e os comandos (CA-D6, CA-J5)", "AGENTS.md funciona num clone novo, mesmo com core.symlinks=false". Era um link simbólico até a Parte J, que o trocou por um arquivo normal |

## Parte E (`/preparar`)

| CA | O que | Cobertura |
|---|---|---|
| CA-E1 | `preparo.md` com 15 itens, níveis, colunas e frontmatter | run: "preparo.md: …" ×4 |
| CA-E2 | `/preparar` com 4 fases, paradas e "nunca" | run: "/preparar com as 4 fases (CA-E2)", "/preparar para antes de organizar e entre rodadas", "/preparar: nunca …" |
| CA-E3 | Nenhuma referência à skill de importação; "importe meus docs" → `/preparar` | run: "skill de importação removida, ninguém cita (CA-E3)", "\"importe meus docs\" leva ao /preparar" |
| CA-E4 | Retomável pela `fase` | run: "/preparar é retomável … (CA-E4)". Comportamento real: manual (é um prompt) |
| CA-E5 | Mesmo fluxo em todos os docs | run: "mesmo fluxo … (CA-E5, CA-G8)" |

## Parte F (board copiado)

| CA | O que | Cobertura |
|---|---|---|
| CA-F1 | Campo que falta é criado; Etapa diferente só avisa | run: seção "bootstrap.sh: campos do board copiado (CA-F1)" |
| CA-F2 | README: visibilidade do modelo e o que a cópia traz | run: "README: modelo acessível e o que a cópia traz e não traz (CA-F2)" |

## Parte G (planejamento em duas etapas)

| CA | O que | Cobertura |
|---|---|---|
| CA-G1 | Roadmap com duas seções (template e gerado); sync ignora a seção Milestones | run: "roadmap: duas seções …", "issue de setup no M0, na seção Issues por milestone (CA-G1)", "ignora a seção Milestones … (CA-G1)"; fumaça: passo 2 |
| CA-G2 | PRD sem tabela de milestones; grep vazio | run: "prd.md sem tabela de milestones …", "ninguém manda pôr milestone no prd.md nem no bootstrap.sh (CA-G2)" |
| CA-G3 | `/planejar` em dois modos, recusa fora de ordem, para antes de criar | run: "/planejar com os dois modos (CA-G3)" e as três seguintes |
| CA-G4 | Template de milestone e "Como verificar" | run: "template do doc de milestone (CA-G4)", "Como verificar no molde e no form de issue de feature" |
| CA-G5 | Bootstrap cria só o M0; `new-milestone.sh` idempotente | run: seção `new-milestone.sh (CA-G5)`, "cria só o milestone M0 (CA-G5)"; fumaça: passos 1 e 3 |
| CA-G6 | `/planejar` cria issues com `new-issue.sh`, sem mexer no board, e termina com o sync | run: "/planejar: issues com new-issue.sh, milestone com new-milestone.sh, termina com o sync (CA-G6)" |
| CA-G7 | `/fechar` confere o critério de saída, fecha o milestone e registra o go/no-go | run: "/fechar: … (CA-G7)", "/planejar M<n+1> registra o encerramento no PR dele …"; fumaça: passo 8 |
| CA-G8 | Mesmo fluxo de G7 em todos os docs | run: "mesmo fluxo … (CA-E5, CA-G8)", "fluxo completo: /fechar com go/no-go e /planejar M1 depois (CA-G8)" |

## Parte I (notas do /preparar para o /planejar)

| CA | O que | Cobertura |
|---|---|---|
| CA-I1 | `docs/preparo.md` tem a seção "Para o /planejar" com as duas tabelas e as colunas | run: "preparo.md: seção Para o /planejar com as duas tabelas e as colunas (CA-I1)"; manual: `grep -n "Para o /planejar\|^### Fases\|^### Trabalho" docs/preparo.md` |
| CA-I2 | `preparar.md` sem "fica anotado" e gravando a seção nas fases 1, 2 e 4 (e a 3 só pergunta se contraditório) | run: "preparar.md sem \"fica anotado\" … (CA-I2)"; manual: `grep -n "fica anotado" .claude/commands/preparar.md` (vazio) |
| CA-I3 | `planejar.md` lê a seção no modo 1 (ponto de partida, fonte e divergências) e no modo 2 (trabalho a construir), sem alterá-la | run: "planejar.md lê a seção nos dois modos e não a altera (CA-I3)"; manual: `grep -n "Para o /planejar" .claude/commands/planejar.md` |
| CA-I4 | `CLAUDE.md`, READMEs e esta matriz atualizados; `run.sh` e `smoke.sh` passando | run: "CLAUDE.md, docs/README.md e README citam a passagem pela seção (CA-I4)" e a suíte toda |

## Parte J (operação dentro do repo)

| CA | O que | Cobertura |
|---|---|---|
| CA-J1 | README "Quando algo dá errado" com as linhas de J1; cada mensagem citada existe no código | run: "README: seção Quando algo dá errado, logo depois do Merge gate", "cada mensagem citada na tabela existe em scripts/, .claude/ ou .github/", "a tabela tem as linhas mínimas de J1" |
| CA-J2 | Hotfix com parada de confirmação, `wip:` local, posição no roadmap e retomada; a checagem da task anterior cobre a retomada | run: seção "hotfix e retomada (CA-J2)" (fixture de roadmap + `gh` simulado com `next-task.sh`, `new-issue.sh --existing --after`, `task-status.sh`) |
| CA-J3 | README com as três listas; `atualiza-template.sh` sem `--aplicar` não muda nada, com `--aplicar` não toca nos protegidos, recusa `main` e árvore suja | run: seção "atualiza-template.sh (CA-J3)" (template e projeto locais, sem rede) |
| CA-J4 | `CLAUDE.md` e README dizem qual fonte manda | run: "CLAUDE.md e README dizem qual fonte manda (CA-J4)" |
| CA-J5 | "Em outros agentes" no `CLAUDE.md`; `AGENTS.md` arquivo normal; exemplo de ponta a ponta no `docs/README.md` | run: "CLAUDE.md: Em outros agentes … (CA-J5)", "AGENTS.md é arquivo normal …", "docs/README: exemplo de ponta a ponta com os formatos reais" |
| CA-J6 | `CA.md`, tabela de scripts do `CLAUDE.md` e README atualizados; `run.sh` e `smoke.sh` passando | run: "todo script de scripts/ está na tabela do CLAUDE.md …" (cobre `next-task.sh` e `atualiza-template.sh`) e a suíte toda |

## Parte K (`/preparar` sem material)

Os comandos são prompts: estes CA conferem o texto do `preparar.md` (também automatizados no
`run.sh`, seção "/preparar sem material (Parte K)").

| CA | O que | Cobertura |
|---|---|---|
| CA-K1 | Passo "Material vazio" na Fase 1, com as três situações e as três opções | manual: `sed -n '/^### Fase 1/,/^### Fase 2/p' .claude/commands/preparar.md \| grep -nE "Material vazio\|Pasta vazia\|não existe\|Vou adicionar\|Seguir sem material\|Usar outra pasta"`; run: "Fase 1 tem o passo Material vazio … (CA-K1)" |
| CA-K2 | "Vou adicionar" para e espera, salva no `_import/` com os nomes originais; "Seguir sem material" marca `falta` e registra `sem material` | manual: `grep -nE "pare e espere\|nomes originais\|sem material" .claude/commands/preparar.md`; run: "… (CA-K2)" |
| CA-K3 | Só roda em `fase: inventario`; retomada e `pronto` não mudam | manual: `grep -n "Só quando a \`fase\` é \`inventario\`" .claude/commands/preparar.md`; run: "… (CA-K3)" |
| CA-K4 | Sessão não interativa: para com a mensagem, sem relatório | manual: `grep -n "sessão não interativa" .claude/commands/preparar.md`; run: "… (CA-K4)" |
| CA-K5 | README, `docs/README.md`, prompt de setup e `CA.md` atualizados; `run.sh` e `smoke.sh` passam | manual: `grep -ln "avisa e espera os arquivos" README.md docs/README.md docs/prompts/setup-a-partir-de-docs.md CLAUDE.md`; run: "… (CA-K5)" e a suíte toda |

## Parte L (`/revisar` local e `/abrir-pr` sem número)

| CA | O que | Cobertura |
|---|---|---|
| CA-L1 | `task-atual.sh` resolve por argumento → branch atual → única linha `doing` → única branch `task/*` à frente da `main`; sai 2 (ambíguo, com as candidatas) ou 3 (nada); issue fechada falha; `pr`/`pr_state` open, merged e closed; só REST do repo | run: "task-atual.sh (CA-L1)" |
| CA-L2 | `/abrir-pr` sem número usa o `task-atual.sh`, anuncia a issue e a branch, troca de branch só com a árvore limpa, para em ambíguo/nada/PR mergeado ou fechado e atualiza o PR aberto | run: "… (CA-L2)"; manual: `grep -n "task-atual" .claude/commands/abrir-pr.md` |
| CA-L3 | `/revisar` tem modo PR e modo local; o local revisa `git diff origin/main...HEAD`, avisa alterações não commitadas, marca os checks `n/a (sem PR)`, cita o sha7 e não posta nada | run: "… (CA-L3)"; manual: `sed -n '/^## Modo local/,/^## O que verificar/p' .claude/agents/revisor.md` |
| CA-L4 | O `revisor` aceita número de PR ou `local`, mantém `event=COMMENT` no modo PR e nunca aprova nem pede mudanças | run: "… (CA-L4)" |
| CA-L5 | `CLAUDE.md`, `README.md`, `docs/README.md` e `docs/guia.md` mostram o mesmo ciclo com `/revisar local` (opcional); "Quando algo dá errado" tem as linhas novas; suíte passa | run: "… (CA-L5)" e a suíte toda; manual: `grep -n "revisar local" CLAUDE.md README.md docs/README.md docs/guia.md` |

## Parte M (bootstrap sem board)

| CA | O que | Cobertura |
|---|---|---|
| CA-M1 | `bootstrap.sh --sem-board` (e `BOARD=nao`) pula o board por inteiro e grava `BOARD=nao`; os cinco casos da tabela de M1; o resto do bootstrap igual; argumento desconhecido → erro com o uso | run: "bootstrap.sh --sem-board (CA-M1)" |
| CA-M2 | `sync-board.sh` com `BOARD=nao` sai 0, com a mensagem certa e sem chamar o `gh`, com e sem `--auto`; `task-status.sh` segue | run: "sync-board.sh com BOARD=nao (CA-M2)" |
| CA-M3 | Nenhum arquivo de `.claude/` mudou nesta parte | manual: `git diff --stat d2d6bb1 -- .claude/` (vazio) |
| CA-M4 | README ("Board → Sem board" e "Quando algo dá errado"), `docs/guia.md`, `docs/README.md`, `CLAUDE.md` e esta matriz atualizados | run: "… (CA-M4)" |
| CA-M5 | `run.sh`, `smoke.sh` e `smoke.sh --sem-board` passam | run: "fumaça ponta a ponta, com e sem board (CA-H3, CA-M5)" e a suíte toda |

## Parte N (onde o material do `/preparar` fica e limpeza do `_import/`)

| CA | O que | Cobertura |
|---|---|---|
| CA-N1 | `preparar.md` e `preparo.md` mapeiam PDF → `docs/design/` e imagem → `docs/assets/design/`; a pasta antiga de telas não existe e ninguém a cita | run: "… (CA-N1)"; manual: `grep -rn "assets/scr""eens" --exclude-dir=.git .` (vazio) e `sed -n '/^## Mapa/,/^## Regras/p' .claude/commands/preparar.md` |
| CA-N2 | PDF só é guardado depois do `.md` (ou da extração para ele, com `> Pendente:` no que não der); `docs/design/README.md` existe; o `CLAUDE.md` manda ler os `.md` | run: "… (CA-N2)"; manual: `grep -n "PDF" .claude/commands/preparar.md CLAUDE.md docs/design/README.md` |
| CA-N3 | `_import/*` e `!_import/.gitkeep` no `.gitignore`; a Fase 2 copia (`cp` + `git add`), `git mv` só para rastreado; nomes em kebab-case propostos; arquivo acima de 10 MB gera pergunta | run: "… (CA-N3, CA-N5)" (`git check-ignore`) e "… (CA-N3)"; manual: `grep -n "cp\|10 MB\|kebab" .claude/commands/preparar.md` |
| CA-N4 | A limpeza só roda com `fase: pronto`, depois do PR e antes do relatório; mostra as duas listas, pergunta e só apaga com o "sim"; sem resposta, não apaga | run: "… (CA-N4)"; manual: `sed -n '/Limpeza do/,/Relatório final/p' .claude/commands/preparar.md` |
| CA-N5 | `limpar-import.sh`: lista sem apagar; `--apagar` mantém o `.gitkeep`; recusa raiz, `.`, `..`, `docs`, `scripts`, `.claude`, `.github`, pasta com `.git`, link e caminho fora do repo; `git rm` no rastreado | run: "limpar-import.sh e _import/ fora do git (CA-N3, CA-N5)" |
| CA-N6 | README, `docs/guia.md`, `docs/README.md`, prompt de setup, spec template e esta matriz atualizados; `run.sh` e `smoke.sh` passam | run: "… (CA-N6)" e a suíte toda; manual: `grep -ln "fora do git" README.md docs/README.md docs/guia.md docs/prompts/setup-a-partir-de-docs.md` |

## Parte H (fechamento)

| CA | O que | Cobertura |
|---|---|---|
| CA-H1 | Os greps de H1 só devolvem ocorrências justificadas | run: as verificações de CA-1, CA-D4, CA-E3 e CA-G2 cobrem esses padrões (montados em partes no `run.sh`, para ele não casar consigo mesmo); manual: os seis `grep -rniE` da seção H1 do handoff, com `--exclude-dir=.git`. Sobram só o atalho "importe meus docs", a regra do `CLAUDE.md` que proíbe os subcomandos e o próprio `run.sh` |
| CA-H2 | Scripts e comandos citados existem; a tabela do `CLAUDE.md` bate com a pasta | run: seção "consistência (CA-H1, CA-H2)" |
| CA-H3 | Fumaça ponta a ponta passa; esta matriz cobre A–G | run: "fumaça: … 0 falha(s)"; este arquivo |
| CA-H4 | Título e corpo do PR no estado final | manual: `gh api repos/{owner}/{repo}/pulls/1 -q '.title, .body'` |
| CA-H5 | Nenhum arquivo solto na raiz | run: "nenhum arquivo solto na raiz (CA-H5)" |
| CA-H6 | Relatório final com os quatro itens | manual (resposta na conversa) |

`shellcheck`: não está instalado neste ambiente; rode `shellcheck scripts/*.sh scripts/test/*.sh`
localmente se tiver.
