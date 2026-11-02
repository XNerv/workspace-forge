#!/usr/bin/env bash
# tests/test-standalone.sh - build, checksum and run the standalone bundle.

set -Eeuo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname -- "$0")/lib.sh"
sandbox_init

version=$(forge_version)
if [[ -z $version ]]; then
  fail "forge declares no FORGE_VERSION"
fi

copy=$SANDBOX/repo
mkdir -p -- "$copy"
cp -R -- "$FORGE_ROOT/forge" "$FORGE_ROOT/lib" "$FORGE_ROOT/templates" \
  "$FORGE_ROOT/scripts" "$FORGE_ROOT/README.md" "$FORGE_ROOT/LICENSE" "$copy/"

status=0
bash "$copy/scripts/build-standalone.sh" > "$SANDBOX/build.log" 2>&1 || status=$?
if [[ $status -ne 0 ]]; then
  fail "the standalone build failed with $status: $(cat -- "$SANDBOX/build.log")"
fi

bundle=$copy/dist/workspace-forge-$version
assert_file "$bundle/forge" "the bundle executable"
assert_dir "$bundle/lib" "the bundle libraries"
assert_dir "$bundle/templates" "the bundle templates"
libraries=$(find "$bundle/lib" -maxdepth 1 -type f -name '*.sh' | wc -l)
assert_eq 6 "$((libraries))" "the bundle library count"

tarball=$copy/dist/workspace-forge-$version.tar.gz
checksum=$tarball.sha256
assert_file "$tarball" "the distribution archive"
assert_file "$checksum" "the archive checksum"
if ! verify_checksum "$copy/dist" "$(basename -- "$checksum")"; then
  fail "the archive checksum does not verify"
fi

extract=$SANDBOX/extract
mkdir -p -- "$extract"
tar -xzf "$tarball" -C "$extract"
bundle=$extract/workspace-forge-$version
assert_file "$bundle/forge" "the extracted executable"
assert_eq "forge $version" "$("$bundle/forge" --version)" "the extracted bundle version"
status=0
"$bundle/forge" --help > /dev/null 2>&1 || status=$?
assert_eq 0 "$status" "the extracted bundle --help"

status=0
"$bundle/forge" --dry-run -p "$SANDBOX/planned" > /dev/null 2>&1 || status=$?
assert_eq 0 "$status" "the extracted bundle dry run"
assert_absent "$SANDBOX/planned" "the extracted bundle wrote during the dry run"

status=0
"$bundle/forge" -p "$SANDBOX/generated" > /dev/null 2>&1 || status=$?
assert_eq 0 "$status" "the extracted bundle generated a workspace"
assert_file "$SANDBOX/generated/docs/adr/0001-workspace-structure.md" "the extracted bundle ADR"
assert_no_symlink "$SANDBOX/generated" "the extracted bundle generation"

printf 'all standalone checks passed\n'
