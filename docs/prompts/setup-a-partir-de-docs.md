# Prompt: montar o projeto a partir de docs existentes

Use quando o projeto já tem PRD, design, telas, demo ou outros materiais e você quer que uma IA
organize tudo em `docs/`, preencha o que falta e planeje as primeiras issues.

Antes: crie o projeto a partir do template, rode `./scripts/bootstrap.sh` localmente e coloque o
material numa pasta `_import/` na raiz. Se quiser saber o que separar, abra `docs/preparo.md`
(o checklist que a IA vai usar).

## No Claude Code

1. Rode `/preparar` (ou peça "importe meus docs de `_import/`") e responda às rodadas de
   perguntas até o `docs/preparo.md` chegar em `fase: pronto`. Parar no meio é seguro: o próximo
   `/preparar` retoma de onde parou. No fim, ele abre o PR `[docs] Preparo do projeto`.
2. Faça o merge do PR e rode `/planejar M1`.

Depois disso, o ciclo de cada task é `/implementar` → (`/qa`) → `/abrir-pr` → (`/revisar` →
`/corrigir`) → merge → `/fechar`.

## Em outros agentes (Codex, opencode, Hermes etc.)

Eles leem o `AGENTS.md`, mas não rodam os comandos do Claude Code. Cole isto:

````markdown
Leia o `AGENTS.md` e siga `.claude/commands/preparar.md` como se fosse o comando `/preparar`,
com o material em `_import/`. Respeite as paradas do comando: mostre o plano e espere o meu
"pode seguir" antes de organizar os arquivos, faça no máximo 4 perguntas por rodada e pergunte
se continuamos ao fim de cada rodada. Não invente conteúdo e não crie issues.

Quando `docs/preparo.md` estiver em `fase: pronto` e o PR tiver sido mergeado, siga
`.claude/commands/planejar.md` para o milestone M1.
````
