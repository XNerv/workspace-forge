#!/usr/bin/env bash
# paths.sh - references to this repository must resolve.
#
# Independent: no other script is required, and no shared library is sourced.
#
# Only tokens that start with a repository top-level directory are checked:
# `spec/`, `generated/` and `.github/`. Those are unambiguous claims about this
# repository. A token such as `tests/run.sh` is relative to the generated tool
# and a token such as `workspace/` describes a destination, so both are skipped
# by design: checking them would produce false positives on every run.
#
# Exit: 0 clean, 1 violations, 2 usage error.

set -Eeuo pipefail

help() {
  cat <<'EOF'
paths.sh - references to this repository must resolve

Usage: paths.sh [options] FILE...

Checks per file:
  every `path` in backticks that starts with spec/, generated/ or .github/
  must exist. Other relative paths are skipped by design.

Skipped: absolute paths, ~, $variables, globs, <placeholders>, URLs, anchors,
paths with a space.

Options:
  -h, --help    show this help
  -t, --tsv     machine-readable output: KIND<TAB>FILE<TAB>LINE<TAB>RULE<TAB>MESSAGE
  -q, --quiet   print only the summary line

Exit codes:
  0  clean
  1  violations found
  2  usage error

Example:
  paths.sh README.md spec/README.md
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

# The repository root, so a bare `spec/` or `generated/` resolves wherever the
# audit is started from.
repo_root=$(cd -P -- "$(dirname -- "$0")/../.." && pwd)

bad=0
for f in "${files[@]}"; do
  [[ -f $f ]] || { printf 'not a file: %s\n' "$f" >&2; exit 2; }
  case $(basename -- "$f") in
    CHANGELOG.md) continue ;; # history: it names files that no longer exist
  esac
  fdir=$(cd -P -- "$(dirname -- "$f")" && pwd)
  bt=$(printf '\140')

  # shellcheck disable=SC2016  # the grep pattern matches a literal backtick on purpose
  while IFS= read -r raw; do
    token=${raw#"$bt"}
    token=${token%"$bt"}
    case $token in
      *' '* | *'*'* | *'?'* | *'$'* | *'<'* | *'>'* | *'{'* | *'}'* | *'|'* | *'='* | *'...'*) continue ;;
      /* | '~'* | http* | mailto:* | '#'*) continue ;;
    esac
    case $token in
      spec/* | generated/* | .github/*) ;;
      *) continue ;;
    esac
    token=${token%%#*}
    token=${token%%[.,:;]}
    [[ -n $token ]] || continue
    if [[ ! -e $fdir/$token && ! -e $repo_root/$token ]]; then
      emit ERROR "$f" 0 PATH "path does not exist: $token"
      bad=$((bad + 1))
    fi
  done < <(grep -o '`[^`]*`' -- "$f")
done

((quiet)) || printf 'paths: %d broken reference(s) in %d file(s)\n' "$bad" "${#files[@]}"
((bad == 0))
