#!/usr/bin/env bash
# tests/test-scripts-behavior.sh - stub behavior and justfile forwarding.

set -Eeuo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname -- "$0")/lib.sh"
sandbox_init

require_tool just
workspace=$(generate_workspace)
justfile=$workspace/justfile

assert_file "$justfile" "the generated justfile"
if ! grep -q 'set shell := \["bash", "-uc"\]' "$justfile"; then
  fail "the generated justfile lacks the bash shell setting"
fi
if ! grep -q 'set positional-arguments := true' "$justfile"; then
  fail "the generated justfile lacks positional arguments"
fi
for tool in backup setup clean doctor; do
  if ! grep -qF "@bash scripts/$tool.sh \"\$@\"" "$justfile"; then
    fail "the generated justfile does not forward to scripts/$tool.sh"
  fi
done
if grep -q '{{' "$justfile"; then
  fail "the generated justfile interpolates arguments instead of forwarding them"
fi

# Each stub prints its stage name and exits 1 when called directly.
check_stub() {
  local script=$1 stage=$2
  shift 2
  local status=0 err
  err=$(bash "$workspace/scripts/$script" "$@" 2>&1 > /dev/null) || status=$?
  assert_eq 1 "$status" "$script stub exit code"
  assert_contains "$err" "not implemented: $stage" "$script stub message"
}

check_stub setup.sh execute_setup
check_stub clean.sh clean
check_stub doctor.sh check_tools
check_stub backup.sh assert_output_outside_workspace --output "$SANDBOX/backup"

# backup.sh requires --output, and every script rejects an unknown option.
status=0
bash "$workspace/scripts/backup.sh" > /dev/null 2>&1 || status=$?
assert_eq 2 "$status" "backup.sh without --output exits 2"

for script in backup setup clean doctor; do
  status=0
  bash "$workspace/scripts/$script.sh" --unknown > /dev/null 2>&1 || status=$?
  assert_eq 2 "$status" "$script.sh rejects an unknown option with 2"
done

# The justfile is executed because just is a required dependency.
just_in_workspace() {
  ( cd "$workspace" && just "$@" )
}
status=0
just_in_workspace --list > /dev/null 2>&1 || status=$?
assert_eq 0 "$status" "just --list exits 0"
listed=$(just_in_workspace --list)
for recipe in backup setup clean doctor; do
  assert_contains "$listed" "$recipe" "just --list names $recipe"
done
status=0
default_list=$(just_in_workspace 2> /dev/null) || status=$?
assert_eq 0 "$status" "just with no recipe exits 0"
for recipe in backup setup clean doctor; do
  assert_contains "$default_list" "$recipe" "the default just recipe names $recipe"
done

for tool in backup setup clean doctor; do
  status=0
  just_in_workspace "$tool" --help > /dev/null 2>&1 || status=$?
  assert_eq 0 "$status" "just $tool --help exits 0"
done

status=0
just_in_workspace backup > /dev/null 2>&1 || status=$?
assert_eq 2 "$status" "just backup without arguments exits 2"
status=0
just_in_workspace backup --unknown > /dev/null 2>&1 || status=$?
assert_eq 2 "$status" "just backup --unknown exits 2"
status=0
just_in_workspace backup --output > /dev/null 2>&1 || status=$?
assert_eq 2 "$status" "just backup --output without a value exits 2"

err=""
status=0
err=$(cd "$workspace" && just backup --output "$SANDBOX/backups" 2>&1 > /dev/null) || status=$?
assert_eq 1 "$status" "just backup --output DIR exits 1"
assert_contains "$err" "not implemented:" "just backup --output DIR reports the stub"
status=0
(cd "$workspace" && just doctor > /dev/null 2>&1) || status=$?
assert_eq 1 "$status" "just doctor exits 1"

# A path with a space reaches the script as one argument: a split would be a
# usage error with exit code 2 instead of the stub exit code 1.
status=0
(cd "$workspace" && just backup --output "$SANDBOX/dir with space" > /dev/null 2>&1) || status=$?
assert_eq 1 "$status" "a path with a space reaches backup.sh as one argument"

# The repository's own justfile is checked without side effects.
for recipe in test lint build install uninstall release; do
  status=0
  (cd "$FORGE_ROOT" && just --dry-run "$recipe" > /dev/null 2>&1) || status=$?
  assert_eq 0 "$status" "just --dry-run $recipe exits 0"
done

printf 'all script behavior checks passed\n'
