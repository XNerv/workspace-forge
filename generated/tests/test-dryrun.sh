#!/usr/bin/env bash
# tests/test-dryrun.sh - --dry-run performs no writes.

set -Eeuo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname -- "$0")/lib.sh"
sandbox_init

parent=$SANDBOX/parent
mkdir -p -- "$parent"
dest=$parent/planned

before=$(find "$parent" -mindepth 1 -print | LC_ALL=C sort)

run_forge --dry-run -p "$dest"
assert_eq 0 "$FORGE_STATUS" "a dry run with an absent destination exits 0"
assert_absent "$dest" "the dry run created the destination"
assert_contains "$FORGE_OUT" "$dest" "the plan names the absolute destination"
assert_contains "$FORGE_OUT" "mkdir" "the plan lists directory operations"
assert_contains "$FORGE_OUT" "copy" "the plan lists file operations"
assert_contains "$FORGE_OUT" "dry run" "the plan states that it simulated the run"

after=$(find "$parent" -mindepth 1 -print | LC_ALL=C sort)
assert_eq "$before" "$after" "the dry run wrote inside the parent"

# An existing destination is refused even in a dry run, and nothing is written.
existing=$parent/existing
mkdir -p -- "$existing"
assert_refused 3 "a dry run refuses an empty existing destination" --dry-run -p "$existing"
assert_eq "" "$(find "$existing" -mindepth 1 -print)" "the refusal wrote inside the destination"

printf 'all dry-run checks passed\n'
