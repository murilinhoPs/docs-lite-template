# Documentação

Tudo que é planejado ou decidido neste projeto vive aqui. O GitHub guarda o código,
as issues de registro, o board (espelho do `roadmap.md`) e os PRs.

| Arquivo / pasta | O que guarda |
|---|---|
| [overview.md](overview.md) | Resumo do projeto, stack e arquitetura |
| [prd.md](prd.md) | Visão, escopo e MoSCoW |
| [roadmap.md](roadmap.md) | Milestones e a ordem das tasks, com status |
| [tasks/](tasks/) | Uma mini-spec por task, numerada (`001-...`) |
| [adr/](adr/) | Decisões técnicas fechadas, numeradas (`0001-...`) |
| [design/](design/) | Design system e tokens |
| [qa/print-rules.md](qa/print-rules.md) | Como e o que printar quando o Claude testa |
| [assets/](assets/) | Imagens oficiais (telas aprovadas, referências) |
| [prompts/](prompts/) | Prompts prontos para passar a uma IA (ex.: montar o projeto a partir de docs existentes) |

## Regras

- A ordem das linhas em `roadmap.md` é a ordem de execução.
- `roadmap.md` manda no board: depois de mudar o roadmap, rode `./scripts/sync-board.sh`.
- Só uma task em `doing` por vez.
- ADR aceito não é editado: um novo ADR o substitui (`superseded by 0007`).
- Mudou comportamento? Atualize a task ou a spec no mesmo commit.
- Imagem oficial vai em `docs/assets/`; print de teste vai na branch `pr-assets`.
- Diagrama é Mermaid; imagem só para tela real ou referência visual.
