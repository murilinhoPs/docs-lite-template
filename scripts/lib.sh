# Funções comuns aos scripts. Uso: source "$(dirname "$0")/lib.sh"
#
# Só usa git local e arquivos: nada aqui chama a API do GitHub.

# owner/repo a partir do remote origin. Aceita git@github.com:o/r.git,
# https://github.com/o/r(.git) e proxies como http://proxy:1234/git/o/r.
repo_slug() {
  local url owner name
  url="$(git remote get-url origin)"
  url="${url%/}"
  url="${url%.git}"
  url="${url//://}"
  name="${url##*/}"
  url="${url%/*}"
  owner="${url##*/}"
  [ -n "$owner" ] && [ -n "$name" ] || { echo "Não consegui ler owner/repo do remote origin." >&2; return 1; }
  echo "$owner/$name"
}

# Caminho do arquivo relativo à raiz do repo (docs/tasks/001-x.md).
repo_path() {
  echo "$(cd "$(dirname "$1")" && git rev-parse --show-prefix)$(basename "$1")"
}

# Texto como string JSON entre aspas, para usar dentro de filtros -q/--jq.
jq_str() {
  jq -Rn --arg s "$1" '$s'
}

# Valor de uma chave do frontmatter, sem aspas e sem comentário.
# fm_get <arquivo> <chave>
fm_get() {
  awk -v k="$2" '
    NR == 1 && /^---$/ { fm = 1; next }
    fm && /^---$/ { exit }
    fm && index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      sub(/[ \t]+#[^"]*$/, "", v)
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      gsub(/^"|"$/, "", v)
      print v
      exit
    }' "$1"
}

# Troca o valor de uma chave do frontmatter, mantendo o comentário da linha.
# fm_set <arquivo> <chave> <valor>
fm_set() {
  local tmp
  tmp="$(mktemp)"
  awk -v k="$2" -v val="$3" '
    NR == 1 && /^---$/ { fm = 1; print; next }
    fm && /^---$/ { fm = 0 }
    fm && index($0, k ":") == 1 {
      rest = substr($0, length(k) + 2)
      c = ""
      if (match(rest, /[ \t]+#[^"]*$/)) c = substr(rest, RSTART)
      print k ": " val c
      found = 1
      next
    }
    { print }
    END { if (!found) exit 2 }' "$1" > "$tmp" || { rm -f "$tmp"; echo "Chave '$2' não encontrada no frontmatter de $1." >&2; return 1; }
  cat "$tmp" > "$1"
  rm -f "$tmp"
}

# Troca uma coluna da linha da task no roadmap.
# roadmap_set <arquivo> <NNN> <status|issue|pr> <valor>
roadmap_set() {
  local col tmp
  case "$3" in
    status) col=4 ;;
    issue) col=5 ;;
    pr) col=6 ;;
    *) echo "Coluna desconhecida: $3" >&2; return 1 ;;
  esac
  tmp="$(mktemp)"
  # Linhas de task: | 001 | [Título](...) | status | #12 | #13 |
  awk -F'|' -v OFS='|' -v id="$2" -v col="$col" -v val="$4" '
    { n = $2; gsub(/^[ \t]+|[ \t]+$/, "", n) }
    n == id && NF >= 7 { $col = " " val " "; found = 1 }
    { print }
    END { if (!found) exit 2 }' "$1" > "$tmp" || { rm -f "$tmp"; echo "Task $2 não encontrada em $1." >&2; return 1; }
  cat "$tmp" > "$1"
  rm -f "$tmp"
}
