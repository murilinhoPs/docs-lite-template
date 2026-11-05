---
description: Ciclo automático de uma task (orquestrador) - encadeia /implementar, revisor e qa em paralelo, /corrigir, /abrir-pr e /fechar, parando nas decisões do usuário
argument-hint: "[issue] | fechar [pr]"
---

# /ciclo $ARGUMENTS

## Papel

Orquestrador. **Não implementa, não revisa e não testa por conta própria**: segue os comandos que
já existem (`/implementar`, `/corrigir`, `/abrir-pr`, `/fechar`), delega o review ao subagente
`revisor` (`.claude/agents/revisor.md`) e o teste ao subagente `qa` (`.claude/agents/qa.md`) e
decide o próximo passo. Toda decisão de corrigir, abrir o PR e fazer o merge é do usuário.

## Argumentos

`$ARGUMENTS` =
- número da issue (opcional, como no `/implementar`). Sem argumento: a próxima task do roadmap
  (a `doing` interrompida, se houver; senão a primeira `todo`);
- `fechar [pr]`: retoma direto no passo 8 (o merge já foi feito). Sem o número, o `/fechar` acha
  o último PR mergeado.

## Passos

1. **Implementar.** Siga `.claude/commands/implementar.md` inteiro, com o número da issue se veio.
   - Se ele parar antes dos commits (ordem das tasks, hotfix sem confirmação, AC que não existe
     na spec), **pare** e repita a mensagem dele.
   - Com os commits locais feitos, guarde a issue `<N>`, a branch `task/<N>-<slug>` e o
     `<head>` = `git rev-parse HEAD` (40 caracteres).
   - `git status --porcelain` com algo além dos arquivos não rastreados de sempre (alteração em
     arquivo rastreado, ou arquivo novo que a task criou e não commitou): **pare** e avise.
2. **Revisar e testar em paralelo (só na primeira passada).** Na **mesma mensagem**, chame os dois
   subagentes, cada um só com a entrada mínima: sem resumo da implementação, sem opinião sobre o
   código e sem o relatório do outro, para manter o contexto limpo.
   - `revisor`: `local` e a branch (modo local, que não posta nada);
   - `qa`: a issue, a branch e o `<head>` completo.

   PR só de docs (`./scripts/docs-only.sh`): o QA é dispensado; chame só o `revisor`.
   Se o `qa` disser que não tem acesso ao navegador, espere o `revisor` terminar e rode você mesmo
   `.claude/commands/qa.md` na sessão principal, no mesmo `<head>`.
3. **Juntar os relatórios** e classificar cada achado:

   | Mostrar | Vem de |
   |---|---|
   | Crítico | bloqueante do revisor; AC que falhou no QA |
   | Médio | "deveria" do revisor |
   | Baixo/UI | nit do revisor; sugestão de UX do QA |

4. **Decidir.**
   - **Sem nenhum achado** (revisor sem bloqueante, "deveria" nem nit; QA com todos os ACs
     passando e sem sugestão): vá para o passo 6.
   - **Com qualquer achado: pare.** Mostre o relatório por severidade (Crítico, Médio, Baixo/UI),
     com arquivo, linha e a opção de resolução recomendada para cada ponto, e pergunte: "Como
     deseja proceder? Quais dos pontos acima devemos corrigir agora?" (`AskUserQuestion` com
     `multiSelect`, quando houver; mais de 4 pontos: agrupe por severidade ou pergunte em texto).
     **Não mexa em código antes da resposta.** Nit e "deveria" também esperam a escolha: nada é
     corrigido sem o usuário pedir. O que não for escolhido fica no parecer como **não corrigido**.
     Se o usuário não escolher nada, vá para o passo 6.
5. **Corrigir e retestar** (só o que o usuário escolheu). Siga `.claude/commands/corrigir.md` com
   esses pontos (ainda sem PR: só commit local, sem push). Guarde o `<head>` novo. Depois, **em
   sequência, nunca em paralelo**:
   1. chame o `revisor` de novo (`local` e a branch): o review anterior deixou de valer. Espere.
   2. Se ele achou algo que exige mudança de código (bloqueante, ou "deveria" e nit que o usuário
      ainda queira corrigir), **não rode o QA** (os prints cairiam): volte ao passo 4 só com esse
      relatório.
   3. Sem novos achados de código, chame o `qa` com a issue, a branch e o `<head>` novo (ele usa
      uma pasta de prints nova, com o sha novo; PR só de docs: sem QA).
   4. Volte ao passo 3.

   Máximo de **2 voltas** de correção. Passou disso, pare e pergunte como seguir.
6. **Parecer final.** Diga:
   - o `<sha7>` revisado e testado (os dois têm de ser o mesmo commit);
   - o que o `revisor` aprovou (N bloqueantes, N deveria, N nits) e o que o `qa` aprovou (ACs que
     passaram, com o print de cada um);
   - os achados **não corrigidos**, com a severidade;
   - a pasta dos prints (`pr-assets/issue-<N>/<sha7>/`), ou "n/a: PR só de docs".
7. **Abrir o PR, só com o ok.** Pergunte "Posso abrir o PR?". Se houve correção, avise que o código
   mudou desde o último teste do usuário (o teste dele precisa ser refeito). **Sem o "sim", pare.**
   Com o "sim", siga `.claude/commands/abrir-pr.md` inteiro; no `<resumo.md>` do `open-pr.sh`,
   inclua uma seção "Achados não corrigidos (review local e QA)" com os pontos do parecer, para o
   `/fechar` achá-los mesmo sem review postado no PR. Depois, **pare esperando o merge**, que é do
   usuário: mostre o link do PR, o head e o comando de merge (`./scripts/merge.sh <pr> <head>`),
   lembre que `/revisar` (modo PR, review postado travado no head) continua opcional e diga
   "quando mergear, me avise (ex.: 'mergeado') que eu rodo o `/fechar`". Não consulte o GitHub
   em loop.
8. **Fechar.** Quando o usuário avisar do merge (ou chamar `/ciclo fechar [pr]`), siga
   `.claude/commands/fechar.md` com o PR. Ele mesmo confere o merge e a issue e para se não
   estiverem prontos: repasse a mensagem dele. Para os nits e "deveria" (passo 3 do `/fechar`),
   use o último review do PR, se houver, e a seção "Achados não corrigidos" do corpo do PR.
   Entregue o resumo do `/fechar` e termine o ciclo.

## Onde parar

Todos os pontos esperam o usuário:
- **antes do push**: com achados para decidir (passo 4), com mais de 2 voltas de correção
  (passo 5), ou com o "Posso abrir o PR?" sem resposta (passo 7);
- **depois do PR aberto**: esperando o merge, com o PR, o head e o comando de merge;
- **fim do ciclo**: com o resumo do `/fechar`, e o próximo passo que ele indica (a próxima task
  com `/ciclo` ou `/implementar`, ou o `/planejar M<n+1>`).

E, antes de tudo isso, onde os comandos encadeados param sozinhos (o `/implementar` antes dos
commits, o `/abrir-pr` com task ambígua, o `/fechar` sem merge): repita a mensagem deles e pare.

## Nunca

- Dar push ou abrir PR sem o "sim" do passo 7.
- Fazer o merge.
- Rodar o `/fechar` antes de o usuário avisar do merge, ou consultar o GitHub em loop esperando-o.
- Corrigir qualquer ponto (inclusive nit e "deveria") sem o usuário ter escolhido.
- Revisar ou testar no contexto principal quando há subagente (a única exceção é o `qa` sem
  navegador, no passo 2).
- Passar a um subagente o resumo da implementação, opinião sobre o código ou o relatório do outro.
- Rodar `revisor` e `qa` em paralelo depois de uma correção.
- Passar de 2 voltas de correção sem perguntar.
- Pular `/implementar`, o `revisor` (`/revisar local`), o `qa` (`/qa`) ou o `/fechar`: o `/ciclo`
  só os encadeia, e as regras de cada um continuam valendo.
