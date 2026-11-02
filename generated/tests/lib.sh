#!/usr/bin/env bash
# tests/lib.sh - shared helpers for the test files.
#
# This file is not an executable test. A test sources it, calls sandbox_init
# once, and uses the assertions below.

set -Eeuo pipefail

FORGE_ROOT=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
FORGE=$FORGE_ROOT/forge
TMP_ROOT=$(cd -P -- "${TMPDIR:-/tmp}" && pwd)
SANDBOX=""
export FORGE_STATUS=0
export FORGE_OUT=""
export FORGE_ERR=""

# sandbox_init creates one private directory and isolates HOME and
# XDG_CONFIG_HOME inside it.
sandbox_init() {
  SANDBOX=$(mktemp -d "$TMP_ROOT/forge-test.XXXXXX")
  export HOME=$SANDBOX/home
  export XDG_CONFIG_HOME=$SANDBOX/config
  mkdir -p -- "$HOME" "$XDG_CONFIG_HOME"
  trap sandbox_cleanup EXIT
}

# sandbox_cleanup removes the sandbox only when the absolute path carries the
# prefix mktemp created.
sandbox_cleanup() {
  if [[ -n ${SANDBOX:-} && -d $SANDBOX && $SANDBOX == "$TMP_ROOT"/forge-test.* ]]; then
    rm -rf -- "$SANDBOX"
  fi
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  local tool=$1
  if ! command -v "$tool" > /dev/null 2>&1; then
    fail "required tool not found: $tool"
  fi
}

assert_eq() {
  local expected=$1 actual=$2 label=$3
  if [[ $expected != "$actual" ]]; then
    fail "$label: expected [$expected], got [$actual]"
  fi
}

assert_file() {
  local path=$1 label=$2
  if [[ ! -f $path ]]; then
    fail "$label: missing file: $path"
  fi
}

assert_dir() {
  local path=$1 label=$2
  if [[ ! -d $path ]]; then
    fail "$label: missing directory: $path"
  fi
}

assert_absent() {
  local path=$1 label=$2
  if [[ -e $path || -L $path ]]; then
    fail "$label: path exists but must not: $path"
  fi
}

assert_contains() {
  local haystack=$1 needle=$2 label=$3
  if [[ $haystack != *"$needle"* ]]; then
    fail "$label: [$needle] not found in: $haystack"
  fi
}

# forge_version prints the version declared by forge.
forge_version() {
  sed -n 's/^FORGE_VERSION="\(.*\)"$/\1/p' "$FORGE" | head -n 1
}

# run_forge runs forge and stores the result in FORGE_STATUS, FORGE_OUT and
# FORGE_ERR.
run_forge() {
  local out=$SANDBOX/stdout.txt err=$SANDBOX/stderr.txt
  FORGE_STATUS=0
  "$FORGE" "$@" > "$out" 2> "$err" || FORGE_STATUS=$?
  FORGE_OUT=$(cat -- "$out")
  FORGE_ERR=$(cat -- "$err")
}

# assert_refused EXPECTED_CODE LABEL ARGS... runs forge and requires the exit
# code, and requires that the destination it names is still absent.
assert_refused() {
  local expected=$1 label=$2
  shift 2
  run_forge "$@"
  if [[ $FORGE_STATUS -ne $expected ]]; then
    fail "$label: expected exit $expected, got $FORGE_STATUS: $FORGE_ERR"
  fi
}

assert_ok() {
  local label=$1
  shift
  run_forge "$@"
  if [[ $FORGE_STATUS -ne 0 ]]; then
    fail "$label: expected exit 0, got $FORGE_STATUS: $FORGE_ERR"
  fi
}

# assert_no_symlink ROOT LABEL fails when ROOT contains a symbolic link.
assert_no_symlink() {
  local root=$1 label=$2 link
  link=$(find "$root" -type l -print -quit)
  if [[ -n $link ]]; then
    fail "$label: symbolic link found: $link"
  fi
}

# verify_checksum DIR CHECKSUM_FILE verifies the archive named inside the file,
# using sha256sum or shasum.
verify_checksum() {
  local dir=$1 file=$2
  (
    cd -- "$dir" || return 1
    if command -v sha256sum > /dev/null 2>&1; then
      sha256sum -c "$file"
    elif command -v shasum > /dev/null 2>&1; then
      shasum -a 256 -c "$file"
    else
      return 1
    fi
  ) > /dev/null 2>&1
}

# generate_workspace creates a workspace in the sandbox and prints its path.
generate_workspace() {
  local dest=$SANDBOX/workspace
  run_forge -p "$dest"
  if [[ $FORGE_STATUS -ne 0 ]]; then
    fail "generating the workspace failed with $FORGE_STATUS: $FORGE_ERR"
  fi
  printf '%s\n' "$dest"
}
