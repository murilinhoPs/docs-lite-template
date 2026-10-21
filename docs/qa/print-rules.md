# Regras de prints

Prints só são gerados quando o Claude testa a task (passo opcional do processo).

## Onde salvar

Branch `pr-assets`, pasta `task-NNN/`, um arquivo por critério de aceite:

```
task-NNN/
├── ca-1-<descricao>.png
└── ca-2-<descricao>.png
```

## Método por plataforma

| Plataforma | Como printar | Tamanho |
|---|---|---|
| Web | Navegador headless (Playwright) | 1280×800 |
| Android | `adb exec-out screencap -p > print.png` | Tela do emulador |
| Desktop/Linux | Ferramenta de screenshot do sistema | Janela do app |

Remova as linhas que não se aplicam ao projeto.

## O que conferir

- O print mostra o estado descrito no CA, não só a tela.
- Nenhum dado pessoal real aparece.
