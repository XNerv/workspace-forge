#!/usr/bin/env bash
# encoding.sh - file hygiene for text files.
#
# Independent: no other script is required, and no shared library is sourced.
#
# Checks, per file: LF line endings (no CR anywhere, final newline), no BOM, no trailing whitespace,
# no tab anywhere in Markdown, and no U+FFFD.
#
# Exit: 0 clean, 1 violations, 2 usage error.

set -Eeuo pipefail

help() {
  cat <<'EOF'
encoding.sh - file hygiene for text files

Usage: encoding.sh [options] FILE...

Checks per file:
  - no BOM
  - LF line endings: no carriage return anywhere, and a final newline
  - a final newline
  - no trailing whitespace
  - no tab anywhere (Markdown only): an error outside a fenced block,
    where it breaks the paragraph, and a warning inside one, where it is style
  - no U+FFFD replacement character

Options:
  -h, --help    show this help
  -t, --tsv     machine-readable output: KIND<TAB>FILE<TAB>LINE<TAB>RULE<TAB>MESSAGE
  -q, --quiet   print only the summary line

Exit codes:
  0  clean
  1  violations found
  2  usage error

Example:
  encoding.sh README.md spec/README.md
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

emit() { # KIND FILE LINE RULE MESSAGE
  if ((tsv)); then
    printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"
  elif ((quiet == 0)); then
    printf '%-7s %s:%s %-10s %s\n' "$1" "$2" "$3" "$4" "$5"
  fi
}

bad=0
for f in "${files[@]}"; do
  [[ -f $f ]] || { printf 'not a file: %s\n' "$f" >&2; exit 2; }

  if head -c 3 -- "$f" | od -An -tx1 | tr -d ' \n' | grep -qx 'efbbbf'; then
    emit ERROR "$f" 1 BOM 'byte order mark at the start'
    bad=$((bad + 1))
  fi

  cr=$(grep -c "$(printf '\r')" -- "$f" || true)
  if ((cr > 0)); then
    while IFS=: read -r line _; do
      [[ -n $line ]] || continue
      emit ERROR "$f" "$line" CR 'carriage return: the file must use LF'
    done < <(grep -n "$(printf '\r')" -- "$f" | head -5)
    ((cr > 5)) && emit ERROR "$f" 0 CR "$((cr - 5)) more line(s) with carriage return"
    bad=$((bad + cr))
  fi

  if [[ -s $f ]] && [[ -n $(tail -c 1 -- "$f") ]]; then
    emit ERROR "$f" 0 EOF 'no final newline'
    bad=$((bad + 1))
  fi

  while IFS=: read -r line _; do
    [[ -n $line ]] || continue
    emit ERROR "$f" "$line" WHITESPACE 'trailing whitespace'
    bad=$((bad + 1))
  done < <(grep -n '[[:blank:]]$' -- "$f" || true)

  if grep -q $'\xef\xbf\xbd' -- "$f"; then
    emit ERROR "$f" 0 REPLACEMENT 'contains U+FFFD'
    bad=$((bad + 1))
  fi

  case $f in
    *.md)
      while IFS=$'\t' read -r line where; do
        [[ -n $line ]] || continue
        if [[ $where == outside ]]; then
          emit ERROR "$f" "$line" TAB 'tab outside a fenced block'
          bad=$((bad + 1))
        else
          emit WARNING "$f" "$line" TAB 'tab inside a fenced block'
        fi
      done < <(awk '/^```/ { inb = !inb; next } /\t/ { print NR "\t" (inb ? "inside" : "outside") }' "$f")
      ;;
  esac
done

((quiet)) || printf 'encoding: %d violation(s) in %d file(s)\n' "$bad" "${#files[@]}"
((bad == 0))
