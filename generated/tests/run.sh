#!/usr/bin/env bash
# tests/run.sh - run every executable test under tests/.

set -Eeuo pipefail

if ((BASH_VERSINFO[0] < 4)); then
  printf 'Bash 4 or newer is required, found %s\n' "$BASH_VERSION" >&2
  exit 4
fi

tests_dir=$(cd -P -- "$(dirname -- "$0")" && pwd)
failures=0
total=0

files=()
while IFS= read -r file; do
  files+=("$file")
done < <(find "$tests_dir" -maxdepth 1 -type f -name 'test-*.sh' -print | LC_ALL=C sort)

if ((${#files[@]} == 0)); then
  printf 'no tests found under %s\n' "$tests_dir" >&2
  exit 1
fi

for file in "${files[@]}"; do
  total=$((total + 1))
  name=${file##*/}
  status=0
  printf '== %s\n' "$name"
  bash "$file" || status=$?
  if [[ $status -eq 0 ]]; then
    printf '   passed\n'
  else
    printf '   FAILED (exit %s)\n' "$status"
    failures=$((failures + 1))
  fi
done

printf '\n%s test(s), %s failure(s)\n' "$total" "$failures"
if ((failures > 0)); then
  exit 1
fi
exit 0
