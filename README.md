# <Nome do projeto>

<Uma frase sobre o projeto.> Documentação completa em [docs/](docs/README.md).

## Como este repositório funciona

- **Tudo é documentado em `docs/`:** PRD, roadmap, tasks, ADRs e design.
- **Issues são só registro:** número, labels, milestone e link para a task em `docs/tasks/`.
- **O board no Projects é um espelho do `docs/roadmap.md`:** `./scripts/sync-board.sh` copia
  status (Etapa) e ordem do roadmap para o board. Mude o roadmap, nunca o board.
- **O Claude Code segue o [`CLAUDE.md`](CLAUDE.md):** implementa uma task por vez, na ordem do roadmap.

Ciclo de uma task:

1. "Implemente a próxima task" → o Claude abre a issue, cria `task/NNN-<slug>` e implementa com commits locais.
2. Você testa contra os critérios de aceite.
3. (Opcional) "Teste você também" → o Claude testa e salva prints na branch `pr-assets`.
4. "Pode abrir o PR" → push da branch e PR com `Closes #N`.
5. Você faz o squash merge.

---

## Começando um projeto a partir deste template

```bash
gh repo create meu-projeto --template murilinhoPs/docs-lite-template --private --clone
cd meu-projeto
./scripts/bootstrap.sh
```

Antes, dê ao gh acesso a Projects: `gh auth refresh -s project`.

O `bootstrap.sh` cria o que o template não copia: milestones, labels, board no Projects
(campos Etapa e Ordem, número salvo em `scripts/board.conf`), branch `pr-assets`, worktree
de prints, squash-only e proteção da `main`. Pode rodar de novo: ele pula o que já existe.

Depois:

- [ ] Commit do `scripts/board.conf` gerado pelo bootstrap
- [ ] Criar as visões do board na interface do Projects:
      **Board** agrupado por Etapa · **Backlog** em tabela ordenada por Ordem · **Roadmap** por Milestone
- [ ] Criar labels `area:*` do projeto, se fizer sentido (`gh label create "area:ui" --color C5DEF5`)
- [ ] Trocar o título e a frase deste README
- [ ] Preencher `docs/overview.md` e `docs/prd.md`
- [ ] Escrever as primeiras tasks em `docs/tasks/` e listá-las em `docs/roadmap.md`
      (ou importar docs que você já tem, veja abaixo)
- [ ] Ajustar `docs/qa/print-rules.md` para a plataforma
- [ ] Apagar `scripts/publish-template.sh` (só serve para o template)

## Importando docs que você já tem

Se o projeto já tem briefing, specs, notas, decisões ou imagens, o Claude Code organiza tudo
em `docs/` com a skill [`importar-docs`](.claude/skills/importar-docs/SKILL.md).

1. Coloque os arquivos numa pasta do repositório, por exemplo `_import/` (ou anexe na conversa).
2. Peça ao Claude Code: "importe meus docs de `_import/`" (ou rode `/importar-docs`).
3. Ele lê cada arquivo e pergunta o que ele é (PRD, task, decisão técnica, design...),
   sugerindo um palpite.
4. Ele mostra um plano: o que vai para onde, o que vira várias tasks, o que não será importado
   e o que ficará como `TODO`.
5. Você muda o que quiser (destino de um doc, ordem das tasks, milestones) até aprovar.
6. Só então ele organiza os arquivos e faz um commit local, sem push.

Ele não inventa conteúdo: o que faltar nos templates vira `TODO: <o que falta>`.
O mapa de destinos e as regras ficam no [`CLAUDE.md`](CLAUDE.md), na seção
"Ao pedir 'importe meus docs'".

**Quer o setup completo** (organizar o material, gerar overview, tasks e roadmap e criar as
issues no GitHub)? Use o prompt pronto em
[`docs/prompts/setup-a-partir-de-docs.md`](docs/prompts/setup-a-partir-de-docs.md).

**Usando outra IA?** Ela não lê skills do Claude Code. Peça para ela ler o `CLAUDE.md` e o
`SKILL.md` acima antes de começar, ou copie o conteúdo deles para o arquivo de instruções
da ferramenta (`.cursorrules`, `.github/copilot-instructions.md` etc.).
