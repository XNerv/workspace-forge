#!/usr/bin/env bash
# tests/test-preflight.sh - path protections, symbolic links and the platform.

set -Eeuo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname -- "$0")/lib.sh"
sandbox_init

# The destination must be absent for every probe, so each refusal below points
# at a path that does not exist.
assert_refused 3 "HOME is refused" -p "$HOME"
assert_refused 3 "/ is refused" -p /
assert_refused 3 "/usr is refused" -p /usr
assert_refused 3 "/etc is refused" -p /etc
assert_refused 3 "/var is refused" -p /var
assert_refused 3 "/bin is refused" -p /bin
assert_refused 3 "/srv is refused" -p /srv
assert_refused 3 "/home/other is refused" -p /home/other

# A destination inside the tool repository is refused.
assert_refused 3 "inside the tool repository" -p "$FORGE_ROOT/inside"
# An ancestor of the tool repository exists already, and is refused.
assert_refused 3 "an ancestor of the tool repository" -p "$FORGE_ROOT/.."

# A destination whose parent does not exist is refused.
assert_refused 3 "a missing parent" -p "$SANDBOX/missing/child"

# A symbolic link at the destination is refused.
mkdir -p -- "$SANDBOX/real"
ln -s -- "$SANDBOX/real" "$SANDBOX/link"
assert_refused 3 "a symbolic link destination" -p "$SANDBOX/link"

# An existing directory, empty or not, is refused with code 3.
mkdir -p -- "$SANDBOX/existing"
assert_refused 3 "an existing directory" -p "$SANDBOX/existing"

# Native Windows shells are refused with code 4.
status=0
env OSTYPE=msys "$FORGE" --dry-run -p "$SANDBOX/msys" > /dev/null 2>&1 || status=$?
assert_eq 4 "$status" "OSTYPE=msys is refused with code 4"
status=0
env OSTYPE=cygwin "$FORGE" --dry-run -p "$SANDBOX/cygwin" > /dev/null 2>&1 || status=$?
assert_eq 4 "$status" "OSTYPE=cygwin is refused with code 4"

# A destination below a symbolic-link parent is accepted, because only the
# destination itself may not be a link.
mkdir -p -- "$SANDBOX/linkparent"
ln -s -- "$SANDBOX/real" "$SANDBOX/linkparent/link"
run_forge --dry-run -p "$SANDBOX/linkparent/link/child"
assert_eq 0 "$FORGE_STATUS" "a symbolic-link parent is accepted"

# A non-canonical path is normalized and accepted.
run_forge --dry-run -p "$SANDBOX/existing/../normalized"
assert_eq 0 "$FORGE_STATUS" "a non-canonical path is accepted"
assert_absent "$SANDBOX/normalized" "the normalized destination was created"

# A valid destination under the isolated HOME is accepted with exit 0. If
# _abspath loses FORGE_ABSPATH_CANONICAL, this case fails with code 3.
run_forge --dry-run -p "$HOME/workspace"
assert_eq 0 "$FORGE_STATUS" "HOME/workspace is accepted"
assert_absent "$HOME/workspace" "the dry run wrote inside HOME"

printf 'all preflight checks passed\n'
