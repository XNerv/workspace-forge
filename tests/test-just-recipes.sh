#!/usr/bin/env bash
# =============================================================================
# test-just-recipes.sh - the root justfile only delegates.
#
# The repository has two halves: spec/ is the source of truth, generated/ is the
# tool it produces. The recipe name says which half it acts on, and the body
# only delegates, so a change in either never needs a change here.
#
# Given  the justfile as written
# When   its text is read, and just is asked to list it
# Then   every recipe delegates, none reaches the network, and the list matches
# =============================================================================
set -Eeuo pipefail

root=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
# The path is built at run time, so shellcheck cannot follow it.
# shellcheck disable=SC1091
source "$root/tests/lib.sh"

justfile=$root/justfile
recipes=(
  default
  generated-test generated-lint generated-build generated-plan
  generated-create generated-install generated-uninstall
  root-test spec-audit
)
generated_recipes=(
  generated-test generated-lint generated-build generated-plan
  generated-create generated-install generated-uninstall
)

printf '\n  --- the file the repository ships ---\n'

# Given: the file at the repository root
# When:  its settings are read
# Then:  bash is the shell and recipes receive their arguments
check 'the justfile exists' test -f "$justfile"
check 'every recipe runs under bash -uc' grep -qF 'set shell := ["bash", "-uc"]' "$justfile"
check 'recipes receive their arguments' grep -qF 'set positional-arguments := true' "$justfile"

printf '\n  --- every recipe delegates ---\n'

# The body of a recipe is the indented block under its header.
bodies=$(awk '
  /^[a-z_][a-z0-9_-]*( [^:]*)?:.*$/ && !/:=/ { inside = 1; next }
  /^[^[:space:]]/ { inside = 0 }
  inside && /^[[:space:]]+/ { print }
' "$justfile")

# Given: the recipe bodies
# When:  each line is checked
# Then:  it either enters generated/, spec/ or tests/, or hands over to just
offenders=$(printf '%s\n' "$bodies" | grep -vE 'generated|spec/|tests/|just ' || true)
check 'no recipe does work of its own' test -z "$offenders"
[[ -z $offenders ]] || printf '          outside generated/, spec/ and tests/: %s\n' "$offenders"

# Given: the recipe bodies
# When:  they are searched for side channels
# Then:  none reaches git or the network
check 'no recipe runs git' refuses grep -qE '(^|[^a-z])git ' <<<"$bodies"
check 'no recipe uses the network' refuses grep -qE '(curl|wget|ssh) ' <<<"$bodies"

printf '\n  --- the recipes the notes promise ---\n'

# Given: the file line by line
# When:  a recipe header is found
# Then:  the line above it is a comment, so just --list has a description
undocumented=''
previous=''
while IFS= read -r line; do
  # `set name := value` also ends in a colon-like pair; it is not a recipe.
  if [[ $line =~ ^[a-z_][a-z0-9_-]*( [^:]*)?:.*$ && ! $line =~ ':=' &&
    ! $previous =~ ^# ]]; then
    undocumented+=" $line"
  fi
  [[ -n $line ]] && previous=$line
done < "$justfile"
check 'every recipe carries a comment above it' test -z "$undocumented"

printf '\n  --- a guarda de generated/ ---\n'

# Given: both halves of the repository
# When:  a recipe enters the tool
# Then:  it requires the guard, and the guard points at the document to run
unguarded=''
for recipe in "${generated_recipes[@]}"; do
  grep -qE "^$recipe( [^:]*)?: _need-generated$" "$justfile" || unguarded+=" $recipe"
done
check 'every generated- recipe requires the guard' test -z "$unguarded"
[[ -z $unguarded ]] || printf '          without the guard:%s\n' "$unguarded"
check 'the guard names the agent and the document' \
  grep -qE 'an agent must run spec/workspace-forge\.prompt\.md' "$justfile"

# Given: the recipes the notes describe
# When:  just lists the file, or the file is read when just is absent
# Then:  every name is there
if command -v just > /dev/null 2>&1; then
  set +e
  listed=$(just --justfile "$justfile" --list 2>&1)
  set -e
  for recipe in "${recipes[@]}"; do
    check "just lists $recipe" grep -qE "^ *$recipe( |$)" <<<"$listed"
  done
else
  printf '    skip  just is not installed: the list comes from the text\n'
  for recipe in "${recipes[@]}"; do
    check "the justfile declares $recipe" grep -qE "^$recipe( [^:]*)?:" "$justfile"
  done
fi

summary
