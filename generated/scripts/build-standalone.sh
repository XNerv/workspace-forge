#!/usr/bin/env bash
#
# build-standalone.sh - build the self-contained workspace-forge bundle.
#
# Output, under dist/:
#   workspace-forge-<version>/                  executable bundle
#   workspace-forge-<version>.tar.gz            distribution archive
#   workspace-forge-<version>.tar.gz.sha256     checksum of the archive
#
# The archive is reproducible for the same files and settings as far as GNU
# tar and gzip allow: the build sorts the entries, pins the owner and the
# modification time and disables the gzip timestamp. gzip still records its own
# version and compression level, so two machines can produce different bytes
# with the same input.

set -Eeuo pipefail

repo=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
cd -- "$repo"

version=""
version=$(sed -n 's/^FORGE_VERSION="\(.*\)"$/\1/p' forge | head -n 1)
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'cannot read a semantic version from forge\n' >&2
  exit 1
fi

for library in common args preflight files tree templates; do
  if [[ ! -f lib/$library.sh ]]; then
    printf 'missing library: lib/%s.sh\n' "$library" >&2
    exit 1
  fi
done
for script in backup setup clean doctor; do
  if [[ ! -f templates/scripts/$script.sh ]]; then
    printf 'missing template script: templates/scripts/%s.sh\n' "$script" >&2
    exit 1
  fi
done
for file in forge README.md LICENSE; do
  if [[ ! -f $file ]]; then
    printf 'missing file: %s\n' "$file" >&2
    exit 1
  fi
done
if [[ ! -d templates ]]; then
  printf 'missing directory: templates\n' >&2
  exit 1
fi

dist=$repo/dist
bundle_name=workspace-forge-$version
tarball=$dist/$bundle_name.tar.gz
checksum=$tarball.sha256

base=$(mktemp -d)
cleanup() {
  if [[ -n ${base:-} && -d $base && $base == /tmp/* ]]; then
    rm -rf -- "$base"
  fi
}
trap cleanup EXIT

stage=$base/$bundle_name
mkdir -p -- "$stage/lib" "$stage/templates"
cp -- forge "$stage/forge"
chmod u+rx -- "$stage/forge"
cp -- lib/*.sh "$stage/lib/"
cp -R -- templates/. "$stage/templates/"
cp -- LICENSE "$stage/LICENSE"

cat > "$stage/README.md" <<EOF
# workspace-forge $version

This bundle is the self-contained form of workspace-forge $version. It creates a
standardized workspace in a destination that does not exist yet.

## Run it

\`\`\`bash
./forge --dry-run -p ~/lab    # plan; prints every path, writes nothing
./forge -p ~/lab              # create the workspace
./forge --help                # options, protections and exit codes
\`\`\`

The destination must not exist, not even as an empty directory: the generator is
create-only and never updates an existing workspace.

## What it creates

The workspace holds twelve directories, each with a README that states its
purpose and its rules. The root holds a \`justfile\`, \`.gitignore\`,
\`.editorconfig\`, \`.env.example\` and four skeleton scripts under \`scripts/\`:
\`setup.sh\`, \`doctor.sh\`, \`backup.sh\` and \`clean.sh\`. Every stage of those scripts
fails with \`not implemented\` until you edit the script for this workspace.

## Contents

- \`forge\` - the executable
- \`lib/\` - the six libraries the executable loads
- \`templates/\` - the files the executable installs

## Requirements

Bash 4 or newer on Linux or WSL2. The supported baseline is Ubuntu 24.04 LTS or
newer. Native Windows shells and macOS are refused with exit code 4.

## License

MIT. See \`LICENSE\` in this directory.
EOF

# Verify the staged bundle before publishing anything.
smoke=$base/smoke
mkdir -p -- "$smoke"
actual=$("$stage/forge" --version)
if [[ $actual != "forge $version" ]]; then
  printf 'unexpected --version output: %s\n' "$actual" >&2
  exit 1
fi
"$stage/forge" --help > /dev/null
"$stage/forge" --dry-run -p "$smoke/planned" > /dev/null
if [[ -e $smoke/planned ]]; then
  printf 'the dry run created a destination\n' >&2
  exit 1
fi
"$stage/forge" -p "$smoke/workspace" > /dev/null
if [[ ! -f $smoke/workspace/docs/adr/0001-workspace-structure.md ]]; then
  printf 'the bundle did not generate the workspace\n' >&2
  exit 1
fi

mkdir -p -- "$dist"
case $dist/$bundle_name in
  "$repo"/dist/workspace-forge-*) ;;
  *)
    printf 'refusing to replace an unexpected path: %s\n' "$dist/$bundle_name" >&2
    exit 1
    ;;
esac
if [[ -e $dist/$bundle_name ]]; then
  rm -rf -- "${dist:?}/${bundle_name:?}"
fi
rm -f -- "$tarball" "$checksum"
mv -- "$stage" "$dist/$bundle_name"

tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
  -C "$dist" -cf - "$bundle_name" | gzip -n > "$tarball"
(
  cd -- "$dist"
  sha256sum "$(basename -- "$tarball")" > "$(basename -- "$checksum")"
)

printf 'built %s\n' "$tarball"
printf 'built %s\n' "$checksum"
printf 'bundle %s\n' "$dist/$bundle_name"
