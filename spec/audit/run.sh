#!/usr/bin/env bash
# run.sh - run every audit and aggregate the exit codes.
#
# Each check prints its own report. The script exits 1 when any check fails, so
# one broken file never hides the others - the same aggregation Section 14.3
# uses for the container validation.
#
# This is the gate. Running one check while you edit is allowed and never
# replaces a full run before you report completion.
#
# Exit: 0 clean, 1 violations, 2 usage error.

set -Eeuo pipefail

root=$(cd -P -- "$(dirname -- "$0")/../.." && pwd)
here=$root/spec/audit
rc=0

help() {
  cat <<'EOF'
run.sh - run every audit and aggregate the exit codes

Usage: run.sh [options]

Options:
  -h, --help        show this help
  -l, --list        list the checks and exit 0
  -o, --only NAMES  run only these checks, comma separated
  -t, --tsv         forward --tsv to every check
  -q, --quiet       forward --quiet to every check

Without options it runs all checks against the repository.

Exit codes:
  0  clean
  1  one or more checks failed
  2  usage error

Workflow:
  While you edit, run the narrowest check for what you touched.
  Before you report completion, run this script with no arguments.
EOF
}

checks() {
  printf 'prose\tbanned phrases, intensifiers, prose sentences over 25 words\tFILE...\n'
  printf 'encoding\tCR, BOM, final newline, whitespace, tabs, U+FFFD\tFILE...\n'
  printf 'code-fences\tbalanced fences, language tag, empty block\tFILE...\n'
  printf 'paths\treferences to spec/, generated/ and .github/ exist\tFILE...\n'
  printf 'links\trelative links and their anchors resolve\tFILE...\n'
  printf 'counts\tnumbers stated in prose match the repository\t[ROOT]\n'
  printf 'refs\tcross-references, direction words, list numbering\tFILE...\n'
  printf 'tree-readme\tREADME layout matches the repository\t-\n'
  printf 'tree-spec\tspec tree matches generated/\t-\n'
}

selected=""
tsv=""
quiet=""
while (($#)); do
  case $1 in
    -h | --help) help; exit 0 ;;
    -l | --list) checks; exit 0 ;;
    -o | --only) selected=${2:-}; shift ;;
    -t | --tsv) tsv=--tsv ;;
    -q | --quiet) quiet=--quiet ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

names=$(checks | cut -f1 | tr '\n' ',' | sed 's/,$//')
if [[ -n $selected ]]; then
  IFS=',' read -r -a requested <<<"$selected"
  for name in "${requested[@]}"; do
    if [[ ",$names," != *",$name,"* ]]; then
      printf 'unknown check: %s\nknown: %s\n' "$name" "$names" >&2
      exit 2
    fi
  done
fi

want() {
  [[ -z $selected ]] && return 0
  [[ ",$selected," == *",$1,"* ]]
}

run() {
  local label=$1
  shift
  want "$label" || return 0
  printf '\n== %s\n' "$label"
  "$@" || rc=1
}

docs=("$root/README.md" "$root/spec/README.md" "$root/spec/CHANGELOG.md" "$root/spec/workspace-forge.prompt.md")

# Every text file in the repository, for the checks that apply to any file.
text_files=()
while IFS= read -r f; do
  text_files+=("$f")
done < <(find "$root" \( -path "$root/.git" -o -path "$root/generated/dist" \) -prune -o -type f \
  \( -name '*.md' -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' -o -name 'justfile' \
     -o -name '.gitignore' -o -name '.gitattributes' -o -name 'LICENSE' -o -name 'VERSION' \) -print | LC_ALL=C sort)
opts=()
[[ -n $tsv ]] && opts+=("$tsv")
[[ -n $quiet ]] && opts+=("$quiet")

run prose bash "$here/prose.sh" "${opts[@]}" "${docs[@]}"
run encoding bash "$here/encoding.sh" "${opts[@]}" "${text_files[@]}"
run code-fences bash "$here/code-fences.sh" "${opts[@]}" "${docs[@]}"
run paths bash "$here/paths.sh" "${opts[@]}" "${docs[@]}"
run links bash "$here/links.sh" "${opts[@]}" "${docs[@]}"
run counts bash "$here/counts.sh" "${opts[@]}" "$root"
run refs bash "$here/refs.sh" "${opts[@]}" --heads "$root/spec/workspace-forge.prompt.md" "${docs[@]}"
run tree-readme bash "$here/tree.sh" "${opts[@]}" "$root" "$root/README.md" '^## Repository layout'
run tree-spec bash "$here/tree.sh" "${opts[@]}" "$root/generated" \
  "$root/spec/workspace-forge.prompt.md" '^## 3[.] Required repository structure' --ignore dist/

if [[ -z $selected ]]; then
  printf '\n== result: %s\n' "$([[ $rc -eq 0 ]] && echo 'all clean' || echo 'violations found')"
fi
exit "$rc"
