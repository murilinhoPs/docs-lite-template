# Prompt: montar o projeto a partir de docs existentes

Use quando o projeto já tem PRD, design, telas, demo ou outros materiais e você quer que uma IA
organize tudo em `docs/`, preencha o que falta e planeje as primeiras issues.

Antes: crie o projeto a partir do template, rode `./scripts/bootstrap.sh` localmente e coloque o
material numa pasta `_import/` na raiz. Se quiser saber o que separar, abra `docs/preparo.md`
(o checklist que a IA vai usar). Sem nada em `_import/` (e com os docs ainda no template), o `/preparar` avisa e espera os arquivos; você pode mandá-los no chat, e ele os salva em `_import/`.

## No Claude Code

1. Rode `/preparar` (ou peça "importe meus docs de `_import/`") e responda às rodadas de
   perguntas até o `docs/preparo.md` chegar em `fase: pronto`. Parar no meio é seguro: o próximo
   `/preparar` retoma de onde parou. No fim, ele abre o PR `[docs] Preparo do projeto`.
   O `_import/` fica fora do git: PDFs são copiados para `docs/design/` (depois de o conteúdo
   estar no `.md`), imagens para `docs/assets/design/`.
2. Ao final, o `/preparar` pergunta se pode limpar o `_import/` ("Posso apagar tudo em
   `_import/`?"), mostrando antes o que não foi importado. Só apaga com o seu "sim".
3. Faça o merge do PR e rode `/planejar` (visão geral): ele escreve os milestones no
   `docs/roadmap.md` e abre o PR `[docs] Roadmap: visão geral`.
4. Faça o merge e rode `/planejar M0` (fundação e spike): issues só do M0, num PR de docs.

O fluxo inteiro: `/preparar` → merge → `/planejar` (visão geral) → merge → `/planejar M0` → merge → ciclo das tasks do M0 → `/fechar` (go/no-go) → `/planejar M1` → ciclo → `/fechar` → `/planejar M2` ….

Depois disso, o ciclo de cada task é `/implementar` → (`/qa`) → `/abrir-pr` → (`/revisar` →
`/corrigir`) → merge → `/fechar`.

## Em outros agentes (Codex, opencode, Hermes etc.)

Eles leem o `AGENTS.md`, mas não rodam os comandos do Claude Code. Cole isto:

````markdown
Leia o `AGENTS.md` e siga `.claude/commands/preparar.md` como se fosse o comando `/preparar`,
com o material em `_import/`. Respeite as paradas do comando: mostre o plano e espere o meu
"pode seguir" antes de organizar os arquivos, faça no máximo 4 perguntas por rodada e pergunte
se continuamos ao fim de cada rodada. Não invente conteúdo e não crie issues. Copie (não mova)
os arquivos: PDF para `docs/design/` só depois de o conteúdo estar no `.md`, imagem para
`docs/assets/design/`; leia sempre os `.md`, nunca os PDFs. No fim, pergunte se pode apagar o
`_import/` e só apague com o meu "sim".

Quando `docs/preparo.md` estiver em `fase: pronto` e o PR tiver sido mergeado, siga
`.claude/commands/planejar.md` sem argumento (visão geral dos milestones). Depois do merge do
roadmap, siga o mesmo arquivo para o M0 (`/planejar M0`).
````
