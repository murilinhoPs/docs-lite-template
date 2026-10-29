---
updated: AAAA-MM-DD
fase: inventario
---

# Preparo do projeto

Checklist do que o projeto precisa antes do `/planejar`. Você pode abri-lo antes, para saber o que
separar em `_import/`; o `/preparar` o usa como estado da entrevista (retoma de onde parou).

`fase`: `inventario` · `entrevista` · `pronto`

Status: `tem` · `parcial` · `falta` · `n/a`
Nível: **trava** (sem isso o /planejar não roda) · **ajuda** (pode ficar para depois)

| # | Item | Nível | Status | Evidência (arquivo §seção) | Destino | Em aberto |
|---|------|-------|--------|----------------------------|---------|-----------|
| 1 | Visão, problema e público | trava | falta | | prd.md | |
| 2 | Features com IDs e MoSCoW | trava | falta | | prd.md (Features) | |
| 3 | Decisões técnicas: stack, plataformas, hospedagem, banco | trava | falta | | overview.md + ADRs | |
| 4 | Fluxos de usuário com erros e estados vazios | trava | falta | | specs/ | |
| 5 | Modelo de dados e glossário | trava | falta | | overview.md + specs | |
| 6 | Integrações externas (APIs, auth, limites) | trava | falta | | specs + ADRs | |
| 7 | Design system e tokens | trava | falta | | design/ | |
| 8 | Telas ou mockups das features Must | trava | falta | | assets/screens/ | |
| 9 | Requisitos não funcionais | ajuda | falta | | prd.md + specs | |
| 10 | Textos da interface (microcopy, erros) | ajuda | falta | | specs | |
| 11 | Logo, ícones, fontes | ajuda | falta | | assets/design/ + tokens.json | |
| 12 | Dispositivos e tamanhos de tela | ajuda | falta | | qa/print-rules.md | |
| 13 | Métricas de sucesso do MVP | ajuda | falta | | prd.md | |
| 14 | Referências e moodboard | ajuda | falta | | assets/design/ | |
| 15 | Dados de exemplo para testes | ajuda | falta | | issue de setup | |

- Item que não se aplica (ex.: projeto sem integrações) → `n/a`, com o motivo em Em aberto.
- O item 3 também alimenta a issue de setup (stack) e o `.github/workflows/ci.yml` (lint e testes).
- Item `trava` que ficou `parcial` só por `> Pendente:` não impede o `pronto` se o usuário aceitar;
  o `/planejar` deixa as issues que dependem dele para depois.

## Registro da entrevista

<!-- uma linha por rodada: data, itens tratados, decisões, o que virou Pendente -->
