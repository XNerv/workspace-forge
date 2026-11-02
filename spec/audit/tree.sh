#!/usr/bin/env bash
# tree.sh - a documented directory tree must match the filesystem.
#
# Independent: no other script is required, and no shared library is sourced.
#
# Reads the first ```text block after a heading, turns the box-drawing tree into
# plain paths, and checks every declared path against ROOT. By default only
# declared-but-missing paths are errors; with --extras, paths present on disk
# but absent from the block are reported too.
#
# Exit: 0 clean, 1 violations, 2 usage error.

set -Eeuo pipefail

help() {
  cat <<'EOF'
tree.sh - a documented directory tree must match the filesystem

Usage: tree.sh [options] ROOT DOC HEADING

  ROOT     directory the block describes
  DOC      Markdown file that holds the block
  HEADING  extended regex that matches the heading before the block

Checks:
  every path declared in the tree block exists under ROOT
  with --extras: every path on disk is declared in the block

Options:
  -h, --help             show this help
  -e, --extras           also report paths on disk that the block omits
  -i, --ignore PREFIX    skip paths with this prefix (repeatable)
  -t, --tsv              machine-readable output
  -q, --quiet            print only the summary line

Exit codes:
  0  clean
  1  divergences found
  2  usage error

Example:
  tree.sh . README.md '^## Repository layout'
  tree.sh generated spec/workspace-forge.prompt.md '^## 3[.] Required' --ignore dist/
EOF
}

tsv=0 quiet=0 extras=0
ignore=()
pos=()
while (($#)); do
  case $1 in
    -h | --help) help; exit 0 ;;
    -t | --tsv) tsv=1 ;;
    -q | --quiet) quiet=1 ;;
    -e | --extras) extras=1 ;;
    -i | --ignore) ignore+=("${2:-}"); shift ;;
    --) shift; pos+=("$@"); break ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) pos+=("$1") ;;
  esac
  shift
done

((${#pos[@]} == 3)) || { printf 'need ROOT, DOC and HEADING\n' >&2; exit 2; }
root=${pos[0]} doc=${pos[1]} heading=${pos[2]}

[[ -d $root ]] || { printf 'not a directory: %s\n' "$root" >&2; exit 2; }
[[ -f $doc ]] || { printf 'not a file: %s\n' "$doc" >&2; exit 2; }

emit() {
  if ((tsv)); then
    printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"
  elif ((quiet == 0)); then
    printf '%-7s %s:%s %-10s %s\n' "$1" "$2" "$3" "$4" "$5"
  fi
}

bar=$(printf '\342\224\202')
tee=$(printf '\342\224\234')
corner=$(printf '\342\224\224')
dash=$(printf '\342\224\200')

block=$(awk -v re="$heading" '
  $0 ~ re { seen = 1; next }
  seen && /^```text/ { inb = 1; next }
  seen && inb && /^```/ { exit }
  inb { print }
' "$doc" | sed -e "s/$bar/|/g" -e "s/$tee/+ /g" -e "s/$corner/\\\\ /g" -e "s/$dash/-/g")

if [[ -z $block ]]; then
  printf 'warning: no text block after /%s/ in %s\n' "$heading" "$doc" >&2
  exit 0
fi

declared=$(printf '%s\n' "$block" | awk '
  /^[| ]*[+\\]- / {
    mark = index($0, "- ")
    depth = int((mark - 3) / 4)
    name = substr($0, mark + 2)
    sub(/  +.*$/, "", name)
    sub(/[[:space:]]+$/, "", name)
    if (name == "" || name == ".") next
    path = ""
    for (i = 1; i <= depth && i <= n; i++) path = path stack[i] "/"
    path = path name
    sub(/\/$/, "", path)
    stack[depth + 1] = name
    n = depth + 1
    print path
  }
')

skipped() {
  local p=$1 i
  for i in "${ignore[@]:-}"; do
    [[ -n $i && $p == "$i"* ]] && return 0
  done
  return 1
}

bad=0
while IFS= read -r p; do
  [[ -n $p ]] || continue
  skipped "$p" && continue
  if [[ ! -e $root/$p ]]; then
    emit ERROR "$doc" 0 MISSING "declared but not on disk: $p"
    bad=$((bad + 1))
  fi
done <<<"$declared"

if ((extras)); then
  while IFS= read -r p; do
    [[ -n $p ]] || continue
    skipped "$p" && continue
    if ! grep -qxF -- "$p" <<<"$declared"; then
      emit ERROR "$doc" 0 EXTRA "on disk but not declared: $p"
      bad=$((bad + 1))
    fi
  done < <(cd "$root" && find . -mindepth 1 | sed 's|^\./||' | sort)
fi

((quiet)) || printf 'tree: %d divergence(s) between %s and %s\n' "$bad" "$root" "$doc"
((bad == 0))
