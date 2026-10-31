---
milestone: M<n> — <nome>
status: planejado         # planejado | em andamento | encerrado
updated: AAAA-MM-DD
---

# M<n> — <nome>

Escrito pelo `/planejar M<n>` quando este milestone é o próximo. É plano, não comportamento: os
ACs vivem nas specs das features (`AC-F<n>-NN`) e aqui só são referenciados. Quando o milestone
encerra, o `/fechar` fecha o milestone no GitHub e o PR do próximo `/planejar M<n+1>` marca este
doc como histórico (`status: encerrado`); depois disso ele não é mais atualizado.

## Escopo final

<features (F#) e o que entra de cada uma neste milestone>

## Fora de escopo

## Questões em aberto

> Pendente: ...

## Critérios de aceite por feature

<!-- só referencia os AC-F<n>-NN das specs; AC novo nasce na spec -->
- F<n> ([specs/<feature>.md](../specs/<feature>.md)): AC-F<n>-01, AC-F<n>-02

## Critério de saída testável

<o mesmo do roadmap, detalhado; no M0, o go/no-go>

## Riscos

## Ordem sugerida

1. #<issue> <título>
