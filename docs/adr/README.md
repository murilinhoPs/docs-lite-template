# Decisões (ADRs)

Cada arquivo `NNNN-<slug>.md` registra uma decisão técnica duradoura: por que foi feito assim.

## Índice

| # | Título | Status | Data |
|---|---|---|---|

Mantenha este índice em dia ao criar um ADR ou mudar o status de um.

## Status

| Status | Significa |
|---|---|
| `Proposta` | Em discussão; ainda pode mudar |
| `Aceita` | Vale para o projeto; o texto não muda mais |
| `Superada por NNNN` | Substituída por um ADR mais novo |
| `Revertida` | Desfeita sem substituta |

## Regras

- Número sequencial com 4 dígitos (`0001`), nunca reaproveitado.
- ADR `Aceita` é imutável. Para mudar a decisão, crie um ADR novo e marque o antigo como
  `Superada por NNNN` (só a linha de status do antigo muda).
- `Questão:` é opcional: a pergunta que o ADR responde ou a issue que o motivou.
- O Claude propõe ADRs como `Proposta` e só os cria depois do ok do usuário.

## Template

Copie [`_template.md`](_template.md):

```markdown
# NNNN. <Decisão em uma frase>

- Status: Proposta      <!-- Proposta | Aceita | Superada por NNNN | Revertida -->
- Data: AAAA-MM-DD
- Questão: <opcional>

## Contexto
## Decisão
## Alternativas consideradas
## Consequências
```
