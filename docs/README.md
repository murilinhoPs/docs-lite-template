# Documentação

| O quê | Onde | Pergunta que responde |
|---|---|---|
| Visão, escopo, features | [prd.md](prd.md) | O que o produto é e por quê |
| Comportamento atual de cada feature | [specs/](specs/) `<feature>.md` | Como funciona **hoje** |
| Decisões | [adr/](adr/README.md) | Por que foi feito assim |
| Trabalho a fazer | **Issues do GitHub** | O que falta mudar |
| Ordem de execução e status | [roadmap.md](roadmap.md) | O que vem agora |
| Visualização | Board do Projects | Espelho do roadmap |

A spec descreve o presente, nunca planos. A issue descreve a mudança. Um PR que muda
comportamento atualiza a spec no mesmo PR.

## Arquivos

| Arquivo / pasta | O que guarda |
|---|---|
| [overview.md](overview.md) | Resumo do projeto, stack e arquitetura |
| [prd.md](prd.md) | Visão, escopo, MoSCoW e a tabela de Features (`F1`, `F2`…) |
| [specs/](specs/) | Uma spec viva por feature, com os AC vigentes (`AC-F<n>-NN`) |
| [roadmap.md](roadmap.md) | Milestones e a ordem das issues, com status |
| [adr/](adr/README.md) | Decisões técnicas, numeradas (`0001-...`), com índice |
| [design/](design/) | Design system e tokens |
| [qa/print-rules.md](qa/print-rules.md) | Como e o que printar quando o Claude testa |
| [assets/](assets/) | Imagens oficiais (telas aprovadas, referências) |
| [prompts/](prompts/) | Corpos modelo de issue e prompts prontos para passar a uma IA |

## Regras

- A ordem das linhas em `roadmap.md` é a ordem de execução. Cada linha é uma issue.
- `roadmap.md` manda no board: o Action `.github/workflows/sync-board.yml` copia o roadmap para o
  board no PR, no merge e quando a label `status:doing` muda. Nunca mova cards à mão.
- Só uma issue em `doing` por vez.
- Merge só com os checks `ci` e `pr-gate` verdes no head e a branch atualizada com a `main`.
  PR só de docs (tudo em `docs/` ou `*.md`, exceto o `CLAUDE.md`) dispensa prints e QA.
- IDs de feature (`F<n>`) e de AC (`AC-F<n>-NN`) nunca são renomeados nem reaproveitados.
- ADR `Aceita` não é editado: um novo ADR o substitui (`Superada por 0007`).
- Versão do PRD: git tag `prd-vX.Y` (`git tag prd-v1.0 && git push origin prd-v1.0`). Nunca
  escreva sha ou número de versão no texto dos docs; o histórico está no git.
- Imagem oficial vai em `docs/assets/`; print de teste vai na branch `pr-assets`
  (`issue-<N>/<sha7>/`).
- Diagrama é Mermaid; imagem só para tela real ou referência visual.
