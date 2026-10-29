# Funções comuns aos scripts. Uso: source "$(dirname "$0")/lib.sh"
#
# Só usa git local e arquivos: nada aqui chama a API do GitHub.

# owner/repo: $GITHUB_REPOSITORY (no Action) ou o remote origin. Aceita
# git@github.com:o/r.git, https://github.com/o/r(.git) e proxies como http://proxy:1234/git/o/r.
repo_slug() {
  if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    echo "$GITHUB_REPOSITORY"
    return
  fi
  local url owner name
  url="$(git config --get remote.origin.url)"
  url="${url%/}"
  url="${url%.git}"
  url="${url//://}"
  name="${url##*/}"
  url="${url%/*}"
  owner="${url##*/}"
  [ -n "$owner" ] && [ -n "$name" ] || { echo "Não consegui ler owner/repo do remote origin." >&2; return 1; }
  echo "$owner/$name"
}

# Texto como string JSON entre aspas, para usar dentro de filtros -q/--jq.
jq_str() {
  jq -Rn --arg s "$1" '$s'
}

# Filtro jq que casa o título de um milestone com "M1 MVP" ou só com o código "M1".
milestone_filter() {
  echo "select(.title == $(jq_str "$1") or (.title | startswith($(jq_str "$1 "))))"
}

# Linhas do roadmap: | Ordem | Issue | Título | Status | Spec | PR |
# Com -F'|': $2 ordem, $3 issue (#N), $4 título, $5 status, $6 spec, $7 PR.

# Sai com 0 se a issue tem linha no roadmap. roadmap_has <arquivo> <N>
roadmap_has() {
  awk -F'|' -v n="#$2" '{ i = $3; gsub(/[ \t]/, "", i) } i == n { found = 1 } END { exit !found }' "$1"
}

# Troca uma coluna da linha da issue. roadmap_set <arquivo> <N> <status|pr> <valor>
roadmap_set() {
  local col tmp
  case "$3" in
    status) col=5 ;;
    pr) col=7 ;;
    *) echo "Coluna desconhecida: $3" >&2; return 1 ;;
  esac
  tmp="$(mktemp)"
  awk -F'|' -v OFS='|' -v n="#$2" -v col="$col" -v val="$4" '
    { i = $3; gsub(/[ \t]/, "", i) }
    i == n && NF >= 8 { $col = " " val " "; found = 1 }
    { print }
    END { if (!found) exit 2 }' "$1" > "$tmp" || { rm -f "$tmp"; echo "Issue #$2 não está em $1." >&2; return 1; }
  cat "$tmp" > "$1"
  rm -f "$tmp"
}

# Valor de uma coluna da linha da issue. roadmap_get <arquivo> <N> <titulo|status|spec|pr>
roadmap_get() {
  local col
  case "$3" in
    titulo) col=4 ;;
    status) col=5 ;;
    spec) col=6 ;;
    pr) col=7 ;;
  esac
  awk -F'|' -v n="#$2" -v col="$col" '
    { i = $3; gsub(/[ \t]/, "", i) }
    i == n { v = $col; gsub(/^[ \t]+|[ \t]+$/, "", v); print v; exit }' "$1"
}

# Insere a linha de uma issue e renumera a coluna Ordem.
# roadmap_insert <arquivo> <N> <título> <spec> <milestone> [<depois da issue>]
# Sem "depois", entra no fim da seção "## <milestone>" (criada no fim do arquivo se faltar).
roadmap_insert() {
  local tmp title
  title="${3//|//}"
  tmp="$(mktemp)"
  awk -v row="| | #$2 | $title | todo | $4 | |" -v ms="$5" -v after="${6:+#$6}" '
    function issue_of(l,  f) { split(l, f, "|"); gsub(/[ \t]/, "", f[3]); return f[3] }
    function is_row(l) { return l ~ /^\|[^|]*\|[ \t]*#[0-9]+[ \t]*\|/ }
    { line[NR] = $0 }
    END {
      at = 0
      if (after != "") {
        for (i = 1; i <= NR; i++) if (is_row(line[i]) && issue_of(line[i]) == after) at = i
        if (!at) { print "Issue " after " não está no roadmap." > "/dev/stderr"; exit 2 }
      } else {
        h = 0
        for (i = 1; i <= NR; i++) {
          t = line[i]
          if (sub(/^## /, "", t) && (t == ms || index(t, ms " ") == 1)) { h = i; break }
        }
        if (h) for (i = h + 1; i <= NR && line[i] !~ /^## /; i++) if (line[i] ~ /^\|/) at = i
      }
      n = NR
      if (!at) {
        # Seção nova no fim do arquivo.
        if (line[n] != "") line[++n] = ""
        line[++n] = "## " ms
        line[++n] = ""
        line[++n] = "| Ordem | Issue | Título | Status | Spec | PR |"
        line[++n] = "|---|---|---|---|---|---|"
        at = n
      }
      k = 0
      for (i = 1; i <= n; i++) {
        out = line[i]
        if (is_row(out)) { sub(/^\|[^|]*\|/, "| " ++k " |", out) }
        print out
        if (i == at) { r = row; sub(/^\| \|/, "| " ++k " |", r); print r }
      }
    }' "$1" > "$tmp" || { rm -f "$tmp"; return 1; }
  cat "$tmp" > "$1"
  rm -f "$tmp"
}

# Caminho da spec citada no corpo da issue ("**Spec:** docs/specs/x.md (F2)"), ou vazio.
spec_from_body() {
  grep -m1 -oE '\*\*Spec:\*\*[[:space:]]*docs/specs/[^[:space:])]+\.md' <<<"$1" | grep -oE 'docs/specs/[^[:space:]]+' || true
}

# Sai com 0 se o board do Projects é acessível daqui (board.conf + gh project funcionando).
board_available() {
  local conf
  conf="$(git rev-parse --show-toplevel)/scripts/board.conf"
  [ -f "$conf" ] || return 1
  # shellcheck source=/dev/null
  (source "$conf" && gh project list --owner "$OWNER" --limit 1 >/dev/null 2>&1)
}
