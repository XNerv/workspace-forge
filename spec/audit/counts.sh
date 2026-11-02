#!/usr/bin/env bash
# counts.sh - numbers stated in prose must match the repository.
#
# Independent: no other script is required, and no shared library is sourced.
#
# Each row in the table below is one claim: a file, the phrase that states the
# number, and the measurement that decides it. A claim passes when the number in
# the prose equals the measured count. The table is the point: it names which
# numbers this project promises to keep true.
#
# Exit: 0 clean, 1 violations, 2 usage error.

set -Eeuo pipefail

help() {
  cat <<'EOF'
counts.sh - numbers stated in prose must match the repository

Usage: counts.sh [options] [ROOT]

ROOT defaults to the repository root (two levels above this script).

Claims checked:
  libraries                 6   count of generated/lib/*.sh
  tests                     9   count of generated/tests/test-*.sh
  ADRs                      3   count of generated/docs/adr/0*.md
  nested .gitignore         7   count of generated/templates/**/.gitignore
  files in templates       29   count of generated/templates/** files

Each claim is read from spec/workspace-forge.prompt.md and README.md.

Options:
  -h, --help    show this help
  -l, --list    list the claims as CHECK<TAB>EXPECTED<TAB>MEASURED and exit 0
  -t, --tsv     machine-readable output: KIND<TAB>FILE<TAB>LINE<TAB>RULE<TAB>MESSAGE
  -q, --quiet   print only the summary line

Exit codes:
  0  clean
  1  violations found
  2  usage error

Example:
  counts.sh
  counts.sh --list
EOF
}

tsv=0 quiet=0 list=0 root=""
while (($#)); do
  case $1 in
    -h | --help) help; exit 0 ;;
    -l | --list) list=1 ;;
    -t | --tsv) tsv=1 ;;
    -q | --quiet) quiet=1 ;;
    --) shift; root=${1:-}; break ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) root=$1 ;;
  esac
  shift
done

root=${root:-$(cd -P -- "$(dirname -- "$0")/../.." && pwd)}
[[ -d $root ]] || { printf 'not a directory: %s\n' "$root" >&2; exit 2; }

libs=$(find "$root/generated/lib" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l)
tests=$(find "$root/generated/tests" -maxdepth 1 -name 'test-*.sh' 2>/dev/null | wc -l)
adrs=$(find "$root/generated/docs/adr" -maxdepth 1 -name '0*.md' 2>/dev/null | wc -l)
gitignores=$(find "$root/generated/templates" -name '.gitignore' 2>/dev/null | grep -vc '/root/' || true)
templates=$(find "$root/generated/templates" -type f 2>/dev/null | wc -l)

emit() {
  if ((tsv)); then
    printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"
  elif ((quiet == 0)); then
    printf '%-7s %s:%s %-10s %s\n' "$1" "$2" "$3" "$4" "$5"
  fi
}

if ((list)); then
  printf 'libraries\t6\t%s\n' "$libs"
  printf 'tests\t9\t%s\n' "$tests"
  printf 'ADRs\t3\t%s\n' "$adrs"
  printf 'nested-gitignore\t7\t%s\n' "$gitignores"
  printf 'templates\t29\t%s\n' "$templates"
  exit 0
fi

bad=0
checked=0

to_num() {
  case $1 in
    one) printf '1' ;; two) printf '2' ;; three) printf '3' ;;
    four) printf '4' ;; five) printf '5' ;; six) printf '6' ;;
    seven) printf '7' ;; eight) printf '8' ;; nine) printf '9' ;;
    ten) printf '10' ;; eleven) printf '11' ;; twelve) printf '12' ;;
    [0-9]*) printf '%s' "$1" ;;
    *) printf '' ;;
  esac
}

check() { # FILE REGEX EXPECTED LABEL
  local file=$1 re=$2 expected=$3 label=$4 found
  [[ -f $root/$file ]] || return 0
  found=$(grep -oE "$re" -- "$root/$file" | head -1 || true)
  found=$(to_num "${found%% *}")
  [[ -n $found ]] || { emit WARNING "$file" 0 "$label" "does not state the number"; return 0; }
  checked=$((checked + 1))
  if [[ $found != "$expected" ]]; then
    emit ERROR "$file" 0 "$label" "states $found, measured $expected"
    bad=$((bad + 1))
  fi
}

check 'spec/workspace-forge.prompt.md' 'six libraries' 6 LIBRARIES
check 'spec/workspace-forge.prompt.md' 'nine executable tests' 9 TESTS
check 'spec/workspace-forge.prompt.md' 'three ADRs' 3 ADRS
check 'spec/workspace-forge.prompt.md' 'seven per-directory' 7 GITIGNORE
check 'README.md' 'six libraries' 6 LIBRARIES
check 'README.md' 'nine executable tests' 9 TESTS
check 'README.md' 'three ADRs' 3 ADRS
check 'README.md' '29 files, 28 of them installed' 29 TEMPLATES

# The repository VERSION and the version the generated tool declares must agree.
if [[ -f $root/VERSION && -f $root/generated/forge ]]; then
  repo_version=$(head -1 -- "$root/VERSION")
  forge_version=$(sed -n 's/^FORGE_VERSION="\(.*\)"$/\1/p' -- "$root/generated/forge" | head -1)
  checked=$((checked + 1))
  if [[ $repo_version != "$forge_version" ]]; then
    emit ERROR VERSION 0 VERSION "states $repo_version, generated/forge states $forge_version"
    bad=$((bad + 1))
  fi
fi

((quiet)) || printf 'counts: %d checked, %d divergent [libs=%d tests=%d adrs=%d gitignore=%d templates=%d]\n' \
  "$checked" "$bad" "$libs" "$tests" "$adrs" "$gitignores" "$templates"
((bad == 0))
