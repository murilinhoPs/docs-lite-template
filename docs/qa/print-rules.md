# Regras de prints

Prints só são gerados quando o Claude testa a task (passo opcional do processo).

## Onde salvar

Branch `pr-assets`, uma pasta por issue e por commit testado (`<sha7>` = `git rev-parse --short=7 HEAD`
da branch da task), um arquivo por critério de aceite:

```
issue-<N>/
└── <sha7>/
    ├── ac-f2-01-<descricao>.png
    ├── ac-f2-02-<descricao>.png
    └── print_sizes.txt
```

Testou de novo depois de uma correção? Crie uma pasta nova com o sha novo. As pastas antigas
ficam como histórico; não sobrescreva.

## `print_sizes.txt`

Prova que os prints são da versão do código que vai no PR:

```
commit: <hash completo do HEAD testado>
ac-f2-01-<descricao>.png  <largura>x<altura>  <sha256 de 64 caracteres>
ac-f2-02-<descricao>.png  <largura>x<altura>  <sha256 de 64 caracteres>
```

Para gerar (no worktree da `pr-assets`, com `file` e `sha256sum` disponíveis):

```bash
cd ../<repo>-assets/issue-<N>/<sha7>
{ echo "commit: $(git -C ../../../<repo> rev-parse HEAD)"
  for f in *.png; do
    size=$(file "$f" | grep -oE '[0-9]+ x [0-9]+' | tr -d ' ')
    echo "$f  $size  $(sha256sum "$f" | cut -d' ' -f1)"
  done; } > print_sizes.txt
```

O PR aponta para a pasta do head final (seção Prints do PR template). No review, confira se
o `commit:` é o **Head** do corpo do PR. O único commit que pode vir depois dele é o
`registra PR #N no roadmap`, feito pelo `open-pr.sh`, que só toca `docs/roadmap.md`.

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
