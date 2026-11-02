#!/usr/bin/env bash
# refs.sh - cross-references, directional words and list numbering.
#
# Independent: no other script is required, and no shared library is sourced.
#
# Checks per file:
#   - every "Section N" or "Section N.M" names an existing heading
#   - every "table/list/block below" has its target after it, and "above" before it
#   - every ordered list starts at 1 and increments by 1
#
# Exit: 0 clean, 1 violations, 2 usage error.

set -Eeuo pipefail

help() {
  cat <<'EOF'
refs.sh - cross-references, directional words and list numbering

Usage: refs.sh [options] FILE...

Checks per file:
  - "Section N" and "Section N.M" must name an existing heading
  - "table below" / "list below" / "block below" must have the target within
    the window that follows; "above" must have it within the window before
  - an ordered list must start at 1 and increment by 1

Options:
  -h, --help          show this help
  -t, --tsv           machine-readable output
  -q, --quiet         print only the summary line
  -H, --heads FILE    resolve Section numbers against FILE instead of the
                      file being checked (for cross-document references)
  -w, --window N      lines to search for a directional target (default 20)

Exit codes:
  0  clean
  1  violations found
  2  usage error

Examples:
  refs.sh spec/workspace-forge.prompt.md
  refs.sh --heads spec/workspace-forge.prompt.md spec/README.md
EOF
}

tsv=0 quiet=0 heads="" window=20
files=()
while (($#)); do
  case $1 in
    -h | --help) help; exit 0 ;;
    -t | --tsv) tsv=1 ;;
    -q | --quiet) quiet=1 ;;
    -H | --heads) heads=${2:-}; shift ;;
    -w | --window) window=${2:-20}; shift ;;
    --) shift; files+=("$@"); break ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) files+=("$1") ;;
  esac
  shift
done
((${#files[@]})) || { printf 'no file given\n' >&2; exit 2; }
[[ -z $heads ]] || [[ -f $heads ]] || { printf 'not a file: %s\n' "$heads" >&2; exit 2; }

emit() {
  if ((tsv)); then
    printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"
  elif ((quiet == 0)); then
    printf '%-7s %s:%s %-10s %s\n' "$1" "$2" "$3" "$4" "$5"
  fi
}

headings() { # FILE -> one id per line
  grep -E '^#{2,3} [0-9]' -- "$1" |
    sed -E -e 's/^### ([0-9]+\.[0-9]+) .*/\1/' -e 's/^## ([0-9]+)\..*/\1/' |
    grep -E '^[0-9]+(\.[0-9]+)?$' | sort -u
}

bad=0
for f in "${files[@]}"; do
  [[ -f $f ]] || { printf 'not a file: %s\n' "$f" >&2; exit 2; }

  source_file=${heads:-$f}
  known=$(headings "$source_file")

  # 1. Section references
  # shellcheck disable=SC2016  # the sed pattern matches a literal backtick on purpose
  while IFS=: read -r line ref; do
    [[ -n $ref ]] || continue
    if ! grep -qxF -- "$ref" <<<"$known"; then
      emit ERROR "$f" "$line" SECTION "no such section: $ref"
      bad=$((bad + 1))
    fi
  done < <(sed -E -e 's/`[^`]*`/ /g' -e 's/"[^"]*"/ /g' -- "$f" | grep -noE 'Sections? [0-9]+(\.[0-9]+)?' | sed -E 's/^([0-9]+):Sections? /\1:/')

  # 2. Directional words: table/list/block below|above
  # shellcheck disable=SC2016  # the sed pattern matches a literal backtick on purpose
  while IFS=: read -r line word target; do
    [[ -n $target ]] || continue
    if [[ $word == below ]]; then
      from=$((line + 1))
      to=$((line + window))
    else
      from=$((line - window))
      ((from < 1)) && from=1
      to=$((line - 1))
    fi
    ((to < from)) && continue
    case $target in
      table) pat='^\|' ;;
      list) pat='^([-*] |[0-9]+\. )' ;;
      block) pat='^```' ;;
      *) pat='^\|' ;;
    esac
    if ! sed -n "${from},${to}p" -- "$f" | grep -qE "$pat"; then
      emit ERROR "$f" "$line" DIRECTION "no $target $word within $window lines"
      bad=$((bad + 1))
    fi
  done < <(sed -E -e 's/`[^`]*`/ /g' -e 's/"[^"]*"/ /g' -- "$f" | grep -noE '(table|list|block) (below|above)' | sed -E 's/^([0-9]+):([a-z]+) (below|above)/\1:\3:\2/')

  # 3. Ordered list numbering
  while IFS=: read -r line problem; do
    [[ -n $problem ]] || continue
    emit ERROR "$f" "$line" LIST "$problem"
    bad=$((bad + 1))
  done < <(awk '
    /^#/ { prev = ""; next }
    /^[0-9]+\. / {
      match($0, /^[0-9]+/)
      n = substr($0, 1, RLENGTH) + 0
      if (prev == "") {
        if (n != 1) printf "%d:list starts at %d\n", NR, n
      } else if (n != prev + 1 && n != 1) {
        printf "%d:expected %d or 1, found %d\n", NR, prev + 1, n
      }
      prev = n
      next
    }
    { next }
  ' "$f")
done

((quiet)) || printf 'refs: %d problem(s) in %d file(s)\n' "$bad" "${#files[@]}"
((bad == 0))
