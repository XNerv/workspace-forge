#!/usr/bin/env bash
# links.sh - relative Markdown links and their anchors must resolve.
#
# Independent: no other script is required, and no shared library is sourced.
#
# For every `[text](target)` outside a fenced block: the target must exist next
# to the file (or at the repository root), and a `#anchor` must match a heading
# in the target document. External schemes are skipped.
#
# Exit: 0 clean, 1 violations, 2 usage error.

set -Eeuo pipefail

help() {
  cat <<'EOF'
links.sh - relative Markdown links and their anchors must resolve

Usage: links.sh [options] FILE...

Checks per file:
  - every relative link target exists (next to the file or at the repo root)
  - every #anchor matches a heading in the target document
  - links inside fenced blocks are ignored

Skipped: http, https, mailto, and links that start with # (same-document).

Options:
  -h, --help    show this help
  -t, --tsv     machine-readable output: KIND<TAB>FILE<TAB>LINE<TAB>RULE<TAB>MESSAGE
  -q, --quiet   print only the summary line

Exit codes:
  0  clean
  1  violations found
  2  usage error

Example:
  links.sh README.md spec/README.md generated/docs/usage.md
EOF
}

slug() {
  printf '%s\n' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -e 's/[^a-z0-9 _-]//g' -e 's/ /-/g'
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
  fdir=$(cd -P -- "$(dirname -- "$f")" && pwd)

  while IFS= read -r link; do
    case $link in
      http* | mailto:* | '#'*) continue ;;
    esac
    target=${link%%#*}
    anchor=""
    [[ $link == *#* ]] && anchor=${link#*#}

    if [[ -z $target ]]; then
      path=$f
    elif [[ -e $fdir/$target ]]; then
      path=$fdir/$target
    elif [[ -e $target ]]; then
      path=$target
    else
      emit ERROR "$f" 0 LINK "link target does not exist: $target"
      bad=$((bad + 1))
      continue
    fi

    [[ -n $anchor ]] || continue
    [[ -f $path ]] || continue
    want=$(slug "$anchor")
    found=0
    while IFS= read -r heading; do
      got=$(slug "$heading")
      if [[ $got == "$want" ]]; then
        found=1
        break
      fi
    done < <(grep -E '^#{1,6} ' -- "$path" | sed 's/^#*[[:space:]]*//')
    if ((found == 0)); then
      emit ERROR "$f" 0 ANCHOR "anchor not found in $target: #$anchor"
      bad=$((bad + 1))
    fi
  done < <(awk '
    /^```/ { infence = !infence; next }
    infence { next }
    { print }
  ' "$f" | grep -oE '\]\([^)]+\)' | sed -e 's/^](//' -e 's/)$//')
done

((quiet)) || printf 'links: %d problem(s) in %d file(s)\n' "$bad" "${#files[@]}"
((bad == 0))
