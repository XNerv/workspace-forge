#!/usr/bin/env bash
# tests/test-existing-destination.sh - the create-only contract.

set -Eeuo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname -- "$0")/lib.sh"
sandbox_init

# An existing empty directory is refused, in a real run and in a dry run.
empty=$SANDBOX/empty
mkdir -p -- "$empty"
assert_refused 3 "an empty directory is refused" -p "$empty"
assert_refused 3 "an empty directory is refused in a dry run" --dry-run -p "$empty"
assert_eq "" "$(find "$empty" -mindepth 1 -print)" "the empty directory stayed empty"

# An existing non-empty directory is refused and its content is untouched.
full=$SANDBOX/full
mkdir -p -- "$full/sub"
printf 'keep me\n' > "$full/sub/file.txt"
assert_refused 3 "a non-empty directory is refused" -p "$full"
assert_eq "keep me" "$(cat -- "$full/sub/file.txt")" "the existing content changed"

# A regular file at the destination is refused and keeps its content.
file=$SANDBOX/afile
printf 'original\n' > "$file"
assert_refused 3 "a regular file is refused" -p "$file"
assert_eq "original" "$(cat -- "$file")" "the existing file changed"

# A symbolic link at the destination is refused, even when its target is absent.
target=$SANDBOX/target
link=$SANDBOX/link
ln -s -- "$target" "$link"
assert_refused 3 "a symbolic link is refused" -p "$link"
assert_absent "$target" "the symlink target was created"
if [[ ! -L $link ]]; then
  fail "the symbolic link at the destination changed"
fi

# The same link is refused in a dry run.
assert_refused 3 "a symbolic link is refused in a dry run" --dry-run -p "$link"

printf 'all existing-destination checks passed\n'
