# Regras de prints

Prints só são gerados quando o Claude testa a task (passo opcional do processo).

## Onde salvar

Branch `pr-assets`, pasta `task-NNN/`, um arquivo por critério de aceite:

```
task-NNN/
├── ca-1-<descricao>.png
├── ca-2-<descricao>.png
└── print_sizes.txt
```

## `print_sizes.txt`

Prova que os prints são da versão do código que vai no PR:

```
commit: <hash completo do HEAD testado>
ca-1-<descricao>.png  <largura>x<altura>  <sha256 de 64 caracteres>
ca-2-<descricao>.png  <largura>x<altura>  <sha256 de 64 caracteres>
```

Para gerar (no worktree da `pr-assets`, com `file` e `sha256sum` disponíveis):

```bash
cd ../<repo>-assets/task-NNN
{ echo "commit: $(git -C ../../<repo> rev-parse HEAD)"
  for f in *.png; do
    size=$(file "$f" | grep -oE '[0-9]+ x [0-9]+' | tr -d ' ')
    echo "$f  $size  $(sha256sum "$f" | cut -d' ' -f1)"
  done; } > print_sizes.txt
```

No review, confira se o `commit:` é o último commit do PR. Se não for, os prints estão
desatualizados.

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
