#!/usr/bin/env bash
# tests/test-scripts.sh - the generated scripts satisfy their contract.

set -Eeuo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname -- "$0")/lib.sh"
sandbox_init

workspace=$(generate_workspace)
before=$(find "$workspace" -type f -print | LC_ALL=C sort)

for script in backup setup clean doctor; do
  path=$workspace/scripts/$script.sh
  assert_file "$path" "generated script $script"
  if [[ ! -x $path ]]; then
    fail "the generated script is not executable: $path"
  fi
  if ! bash -n "$path"; then
    fail "the generated script has a syntax error: $path"
  fi
  status=0
  bash "$path" --help > /dev/null 2>&1 || status=$?
  assert_eq 0 "$status" "$script --help exits 0"
  if grep -q '\.env' "$path"; then
    fail "$script mentions the local environment file"
  fi
done

setup=$workspace/scripts/setup.sh
if ! grep -q 'execute_setup' "$setup"; then
  fail "setup.sh does not define execute_setup"
fi
for forbidden in check_prerequisites install_dependencies run_dry_run; do
  if grep -q "$forbidden" "$setup"; then
    fail "setup.sh contains the removed stage $forbidden"
  fi
done

backup=$workspace/scripts/backup.sh
for stage in assert_output_outside_workspace build_excludes run_dry_run create_backup; do
  if ! grep -q "$stage" "$backup"; then
    fail "backup.sh does not define the stage $stage"
  fi
done

after=$(find "$workspace" -type f -print | LC_ALL=C sort)
assert_eq "$before" "$after" "a --help call changed the generated tree"

printf 'all script contract checks passed\n'
