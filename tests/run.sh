#!/usr/bin/env bash
# tests/run.sh - run every tests/test-*.sh and aggregate the results.
#
# Each test file is self-contained: it prints its own lines and exits non-zero
# when a check fails. This runner keeps going after a failure, so one broken
# file never hides the others.
#
# Exit: 0 all passed, 1 at least one failure, 2 no test file found.
set -Eeuo pipefail

dir=$(cd -P -- "$(dirname -- "$0")" && pwd)
found=0
failed=0

while IFS= read -r t; do
  found=$((found + 1))
  printf '\n== %s\n' "${t#"$dir"/}"
  if ! bash "$t"; then
    failed=$((failed + 1))
  fi
done < <(find "$dir" -maxdepth 1 -type f -name 'test-*.sh' | LC_ALL=C sort)

if ((found == 0)); then
  printf 'no test-*.sh found in %s\n' "$dir" >&2
  exit 2
fi

printf '\n%d file(s), %d with failures\n' "$found" "$failed"
printf 'reports saved in %s\n' "${dir#"$PWD"/}/output"
((failed == 0))
