#!/usr/bin/env bash
# tests/test-args.sh - parsing, help, version and usage errors.

set -Eeuo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname -- "$0")/lib.sh"
sandbox_init

version=$(forge_version)
if [[ -z $version ]]; then
  fail "forge declares no FORGE_VERSION"
fi

assert_eq "forge $version" "$("$FORGE" --version)" "--version prints the version"
assert_eq "forge $version" "$("$FORGE" -v)" "-v prints the version"

run_forge --help
assert_eq 0 "$FORGE_STATUS" "--help exits 0"
assert_contains "$FORGE_OUT" "--dry-run" "help documents --dry-run"
assert_contains "$FORGE_OUT" "--path" "help documents --path"
assert_contains "$FORGE_OUT" "Exit codes" "help documents the exit codes"
assert_contains "$FORGE_OUT" "create-only" "help states the create-only rule"
assert_contains "$FORGE_OUT" "Protections" "help documents the protections"
run_forge -h
assert_eq 0 "$FORGE_STATUS" "-h exits 0"

# Help wins when both flags are present.
run_forge --version --help
assert_eq 0 "$FORGE_STATUS" "help wins over version"
assert_contains "$FORGE_OUT" "Usage:" "help wins over version: output"

# Version exits 0 before preflight, so a forbidden destination is not examined.
run_forge --version -p /
assert_eq 0 "$FORGE_STATUS" "version exits before preflight"
assert_eq "forge $version" "$FORGE_OUT" "version output with -p /"

# -n works alone and with -p, and writes nothing.
run_forge -n
assert_eq 0 "$FORGE_STATUS" "-n alone exits 0"
assert_contains "$FORGE_OUT" "$HOME/workspace" "-n alone plans the default"
assert_absent "$HOME/workspace" "-n alone writes nothing"

dest=$SANDBOX/planned
run_forge -n -p "$dest"
assert_eq 0 "$FORGE_STATUS" "-n -p exits 0"
assert_absent "$dest" "-n -p writes nothing"

run_forge -n --path "$dest"
assert_eq 0 "$FORGE_STATUS" "--path PATH exits 0"
run_forge -n --path="$dest"
assert_eq 0 "$FORGE_STATUS" "--path=PATH exits 0"

space_dest="$SANDBOX/path with spaces"
run_forge -n -p "$space_dest"
assert_eq 0 "$FORGE_STATUS" "a path with spaces exits 0"
assert_contains "$FORGE_OUT" "$space_dest" "a path with spaces reaches the plan"

trailing=$SANDBOX/trailing
run_forge -n -p "$trailing/"
assert_eq 0 "$FORGE_STATUS" "a trailing slash exits 0"
assert_absent "$trailing" "a trailing slash writes nothing"

# The plan goes to stdout and carries no diagnostic label.
run_forge -n -p "$SANDBOX/clean-output"
assert_eq 0 "$FORGE_STATUS" "plan exits 0"
assert_contains "$FORGE_OUT" "$SANDBOX/clean-output" "the plan names the absolute path"
case $FORGE_OUT in
  *"error:"* | *"warning:"* | *"info:"*)
    fail "a diagnostic label leaked into the plan"
    ;;
esac

# Usage errors: exit code 2 and no write.
usage_error() {
  local label=$1
  shift
  assert_refused 2 "$label" "$@"
}
usage_error "unknown long option" --bogus
usage_error "unknown short option" -x
usage_error "attached short value" -pDIR
usage_error "clustered short options" -nh
usage_error "missing -p value" -p
usage_error "missing --path value" --path
usage_error "empty --path value" --path=
usage_error "empty -p value" -p ""
usage_error "repeated --path" -p "$SANDBOX/one" --path "$SANDBOX/two"
usage_error "positional argument" extra
usage_error "argument after --" -- extra
usage_error "tilde user" -p "~root"
usage_error "tab in path" -p $'tab\there'
usage_error "newline in path" -p $'line\nbreak'

# ~ alone expands to HOME, which the protection table refuses.
assert_refused 3 "tilde alone" -n -p '~'

# forge runs through a symbolic link and from a directory whose name has spaces.
mkdir -p -- "$SANDBOX/bin" "$SANDBOX/dir with spaces"
ln -s -- "$FORGE" "$SANDBOX/bin/forge-link"
assert_eq "forge $version" "$("$SANDBOX/bin/forge-link" --version)" "forge through a symbolic link"
assert_eq "forge $version" "$(cd "$SANDBOX/dir with spaces" && "$FORGE" --version)" "forge from a directory with spaces"

printf 'all args checks passed\n'
