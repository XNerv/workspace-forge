#!/usr/bin/env bash
# tests/test-common.sh - _abspath, path boundaries and path prohibitions.

set -Eeuo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname -- "$0")/lib.sh"
sandbox_init

# shellcheck source=../forge
source "$FORGE"

expect_abspath_error() {
  local label=$1
  shift
  local status=0
  _abspath "$@" > /dev/null 2>&1 || status=$?
  if [[ $status -eq 0 ]]; then
    fail "$label: _abspath accepted the input"
  fi
}

assert_eq "$SANDBOX/foo/bar" "$(cd "$SANDBOX" && _abspath "foo/bar")" "relative path"
assert_eq "$SANDBOX/b" "$(_abspath "$SANDBOX/a/../b")" "normalization of .."
assert_eq "$SANDBOX/a/b" "$(_abspath "$SANDBOX/a/./b")" "normalization of ."
assert_eq "$SANDBOX/dir" "$(_abspath "$SANDBOX/dir/")" "trailing slash"
assert_eq "$SANDBOX/with space/file" "$(_abspath "$SANDBOX/with space/file")" "spaces"
assert_eq "/" "$(_abspath "/")" "root"

mkdir -p -- "$SANDBOX/real"
ln -s -- "$SANDBOX/real" "$SANDBOX/link"
assert_eq "$SANDBOX/real/file" "$(_abspath "$SANDBOX/link/file")" "symbolic link component"

expect_abspath_error "empty path" ""
expect_abspath_error "tab in path" $'tab\there'
expect_abspath_error "newline in path" $'line\nbreak'

# The plain call keeps both globals; the printed line matches them.
out=$SANDBOX/abspath.txt
_abspath "$SANDBOX/a/../b" > "$out"
assert_eq "$SANDBOX/b" "$(cat -- "$out")" "_abspath prints the path"
assert_eq "$SANDBOX/b" "$FORGE_ABSPATH_RESULT" "FORGE_ABSPATH_RESULT"
assert_eq 1 "$FORGE_ABSPATH_CANONICAL" "FORGE_ABSPATH_CANONICAL"

# Component boundaries: /various is not inside /var.
if path_is_within "/various" "/var"; then
  fail "/various must not be inside /var"
fi
if ! path_is_within "/var/foo" "/var"; then
  fail "/var/foo must be inside /var"
fi
if ! path_is_within "/var" "/var"; then
  fail "/var must be inside /var"
fi
if ! path_is_within "/anything" "/"; then
  fail "every absolute path is inside /"
fi

if ! path_is_forbidden "/"; then
  fail "/ must be forbidden"
fi
if path_is_forbidden "/various"; then
  fail "/various must be allowed"
fi
if ! path_is_forbidden "/srv"; then
  fail "/srv must be forbidden"
fi
if ! path_is_forbidden "/home/other"; then
  fail "another user's home must be forbidden"
fi
if ! path_is_forbidden "$HOME"; then
  fail "HOME must be forbidden"
fi
if path_is_forbidden "$HOME/workspace"; then
  fail "HOME/workspace must be allowed"
fi
if ! path_is_forbidden "$HOME/.ssh"; then
  fail "HOME/.ssh must be forbidden"
fi
if ! path_is_forbidden "$HOME/.ssh/key"; then
  fail "a path below HOME/.ssh must be forbidden"
fi

# The temporary exception: the root itself is refused, a strict descendant is
# allowed.
if ! path_is_forbidden "$TMP_ROOT"; then
  fail "the temporary root must be forbidden"
fi
if path_is_forbidden "$TMP_ROOT/new-workspace"; then
  fail "a new child of the temporary root must be allowed"
fi
if ! path_is_forbidden "/var/tmp/workspace"; then
  fail "/var/tmp/workspace must be forbidden while TMPDIR is unset"
fi
if (TMPDIR=/var/tmp; path_is_forbidden "/var/tmp/workspace"); then
  fail "/var/tmp/workspace must be allowed while TMPDIR names /var/tmp"
fi

printf 'all common checks passed\n'
