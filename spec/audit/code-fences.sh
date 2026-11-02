#!/usr/bin/env bash
# code-fences.sh - fenced code block hygiene for Markdown files.
#
# Independent: no other script is required, and no shared library is sourced.
#
# Checks: fences are balanced, every opening fence has a language tag,
# and no block is left empty.
#
# Exit: 0 clean, 1 violations, 2 usage error.

set -Eeuo pipefail

help() {
  cat <<'EOF'
code-fences.sh - fenced code block hygiene for Markdown files

Usage: code-fences.sh [options] FILE...

Checks per file:
  - every opening fence carries a language tag (```bash, ```text, ...)
  - fences are balanced (an unclosed fence is an error)
  - no empty block

Options:
  -h, --help    show this help
  -t, --tsv     machine-readable output: KIND<TAB>FILE<TAB>LINE<TAB>RULE<TAB>MESSAGE
  -q, --quiet   print only the summary line

Exit codes:
  0  clean
  1  violations found
  2  usage error

Example:
  code-fences.sh README.md spec/workspace-forge.prompt.md
EOF
}

tsv=0 quiet=0 files=()
while (($#)); do
  case $1 in
    -h | --help) help; exit 0 ;;
    -t | --tsv) tsv=1 ;;
    -q | --quiet) quiet=1 ;;
    --) shift; files+=("$@"); break ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) files+=("$1") ;;
  esac
  shift
done
((${#files[@]})) || { printf 'no file given\n' >&2; exit 2; }

emit() {
  if ((tsv)); then
    printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"
  elif ((quiet == 0)); then
    printf '%-7s %s:%s %-10s %s\n' "$1" "$2" "$3" "$4" "$5"
  fi
}

bad=0
for f in "${files[@]}"; do
  [[ -f $f ]] || { printf 'not a file: %s\n' "$f" >&2; exit 2; }

  while IFS=$'\t' read -r line rule message; do
    [[ -n $line ]] || continue
    emit ERROR "$f" "$line" "$rule" "$message"
    bad=$((bad + 1))
  done < <(awk '
    /^```/ {
      if (!open) {
        open = 1; start = NR; lang = substr($0, 4); lines = 0
        if (lang == "") printf "%d\tNOTAG\topening fence without a language tag\n", NR
        next
      }
      open = 0
      if (lines == 0) printf "%d\tEMPTY\tempty fenced block\n", start
      next
    }
    open {
      lines++
    }
    END { if (open) printf "%d\tUNCLOSED\tunclosed fence\n", start }
  ' "$f")
done

((quiet)) || printf 'code-fences: %d problem(s) in %d file(s)\n' "$bad" "${#files[@]}"
((bad == 0))
