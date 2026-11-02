#!/usr/bin/env bash
# =============================================================================
# lib.sh - the shared vocabulary of the test suite.
#
# Every test file reads as Given / When / Then:
#
#   Given  a fixture: a doctor.sh copy, a PATH, a fake binary, a container
#   When   the fixture runs, once
#   Then   check lines state what the report must say, and the expect_* helpers
#          say it in one line
#
# A file sources this library, builds fixtures, calls check for each assertion,
# and ends with summary, which prints the totals and exits non-zero on failure.
#
# This file is not a test: run.sh only executes test-*.sh.
# =============================================================================
set -Eeuo pipefail

# The file that sources this library sets these two before calling any fixture.
doctor=${doctor:-}
work=${work:-}

pass=0
failed=0
out=''
results=''

# --- assertions --------------------------------------------------------------
check() { # NAME COMMAND...
  local name=$1
  shift
  if "$@"; then
    pass=$((pass + 1))
    results+="ok    $name"$'\n'
    printf '    ok    %s\n' "$name"
  else
    failed=$((failed + 1))
    results+="FAIL  $name"$'\n'
    printf '    FAIL  %s\n' "$name"
  fi
}

refuses() { ! "$@"; }

expect_contains() { # TEXT
  check "the report says: $1" grep -qF -- "$1" <<<"$out"
}

expect_match() { # REGEX
  check "the report matches: $1" grep -qE -- "$1" <<<"$out"
}

# --- fixtures ----------------------------------------------------------------
# A PATH directory holding the two tools the project expects to carry.
tool_bin() { # DIR JUST_VERSION SHELLCHECK_VERSION
  local dir=$1 just=${2:-} shellcheck=${3:-}
  mkdir -p "$dir"
  if [[ -n $just ]]; then
    printf '#!/bin/sh\necho "just %s"\n' "$just" > "$dir/just"
  fi
  if [[ -n $shellcheck ]]; then
    printf '#!/bin/sh\nprintf "shellcheck %s\\nversion: %s\\n"\n' \
      "$shellcheck" "$shellcheck" > "$dir/shellcheck"
  fi
  chmod +x "$dir"/* 2>/dev/null || true
}

# A PATH directory with the tools the report itself runs, and nothing else. A
# fixture that omits just or shellcheck then really has them missing, whatever
# the machine running the suite has installed.
base_bin() { # DIR
  local dir=$1 tool path
  mkdir -p "$dir"
  for tool in bash awk grep sed find sort head tr timeout readlink dpkg dpkg-query; do
    path=$(command -v "$tool" 2>/dev/null) || continue
    ln -sf "$path" "$dir/$tool"
  done
  printf '%s' "$dir"
}

# --- running -----------------------------------------------------------------
# Run a doctor copy with a PATH prefix and keep what it said. A report that
# finds a gap exits 1, so a non-zero status is a result, not an error: set -e is
# off for the duration.
run_doctor() { # FILE [PATH_PREFIX]
  local file=$1 prefix=${2:-}
  set +e
  if [[ -n $prefix ]]; then
    out=$(cd "$work" && PATH="$prefix:/usr/bin:/bin" "./$file" 2>&1)
  else
    out=$(cd "$work" && "./$file" 2>&1)
  fi
  set -e
}

# --- output ------------------------------------------------------------------
# tests/output keeps what each report said, so a failure can be read after the
# run without repeating it. The directory sits beside the test files.
tests_output() {
  # A file that manages its own directory sets outdir; the rest get one named
  # after the file, beside it.
  if [[ -n ${outdir:-} ]]; then
    printf '%s' "$outdir"
    return 0
  fi
  printf '%s' "$(dirname -- "$0")/output/$(basename -- "$0" .sh)"
}

save_output() { # NAME
  local dir
  dir=$(tests_output)
  mkdir -p "$dir"
  printf '%s\n' "$out" > "$dir/$1.txt"
}

# What the run checked, one line per assertion, so a file that produces no
# report still leaves a record of what it did.
save_results() {
  local dir
  dir=$(tests_output)
  mkdir -p "$dir"
  printf '%s' "$results" > "$dir/results.txt"
}

# A file that cannot run leaves the reason and stops without failing the suite.
skip_test() { # MESSAGE
  printf '  skip  %s\n' "$1"
  results+="skip  $1"$'\n'
  save_results
  exit 0
}

# --- reporting ---------------------------------------------------------------
summary() {
  printf '\n  %d passed, %d failed\n' "$pass" "$failed"
  save_results
  ((failed == 0))
}
