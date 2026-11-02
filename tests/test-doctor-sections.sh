#!/usr/bin/env bash
# =============================================================================
# test-doctor-sections.sh - the section rules: every mistake has to stop the run.
#
# Each case copies doctor.sh, breaks exactly one thing with sed, and checks that
# the copy refuses to run (exit 2) with a message that names the problem. The
# file also covers what the other two files do not: the Debian package mapping,
# an empty service section, two modules side by side and colour precedence.
# =============================================================================
set -Eeuo pipefail

root=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
doctor=$root/doctor.sh
work=$(mktemp -d)

cleanup() { find "$work" -delete 2>/dev/null || true; }
trap cleanup EXIT

# The path is built at run time, so shellcheck cannot follow it.
# shellcheck disable=SC1091
source "$root/tests/lib.sh"

# Build a copy with one mutation, run it, and expect a refusal.
expect_refusal() { # NAME EXPECTED_MESSAGE SED_ARG...
  local name=$1 message=$2
  shift 2
  local copy=$work/$name.sh

  sed "$@" "$doctor" > "$copy"
  chmod +x "$copy"

  local status
  set +e
  out=$(bash "$copy" 2>&1)
  status=$?
  set -e

  check "$name refuses to run" test "$status" -eq 2
  check "$name names the problem" grep -qF -- "$message" <<<"$out"
}

# Given: a copy of doctor.sh with exactly one catalogue mistake
# When:  the copy runs
# Then:  it refuses with exit 2 and names the problem
printf '\n  --- section refusals ---\n'

expect_refusal module-empty-name \
  'PACKAGE_MODULES holds an empty name' \
  's/^  "Packages|4|2"$/  "|4|2"/'

expect_refusal module-duplicate \
  'PACKAGE_MODULES repeats the module: Packages' \
  's/^  "Packages|4|2"$/  "Packages|4|2"\n  "Packages|4|2"/'

expect_refusal module-bad-indent \
  'PACKAGE_MODULES has a bad indent' \
  's/^  "Packages|4|2"$/  "Packages|four|2"/'

expect_refusal module-bad-gap \
  'PACKAGE_MODULES has a bad gap' \
  's/^  "Packages|4|2"$/  "Packages|4|two"/'

expect_refusal group-missing-field \
  'PACKAGE_GROUPS needs module|name|description' \
  's/^  "Packages|Lints|source issue checks"$/  "Packages|Lints"/'

expect_refusal group-duplicate \
  'PACKAGE_GROUPS repeats the group: Lints' \
  's/^  "Packages|Lints|source issue checks"$/  "Packages|Lints|source issue checks"\n  "Packages|Lints|other"/'

expect_refusal group-unknown-module \
  'PACKAGE_GROUPS names an unknown module: Nope' \
  's/^  "Packages|Lints|source issue checks"$/  "Nope|Lints|source issue checks"/'

expect_refusal group-without-tools \
  'PACKAGE_GROUPS declares a group with no tools: Empty' \
  's/^  "Packages|Lints|source issue checks"$/&\n  "Packages|Empty|nothing here"/'

expect_refusal module-without-groups \
  'PACKAGE_MODULES declares a module with no groups: Empty' \
  's/^  "Packages|4|2"$/  "Packages|4|2"\n  "Empty|4|2"/'

expect_refusal tool-missing-field \
  'PACKAGE_TOOLS needs module|group|name|minimum|source' \
  's/^  "Packages|Lints|shellcheck|0.9|shellcheck"$/  "Packages|Lints|shellcheck"/'

expect_refusal tool-unknown-module \
  'PACKAGE_TOOLS names an unknown module: Nope' \
  's/^  "Packages|Lints|shellcheck|0.9|shellcheck"$/  "Nope|Lints|shellcheck|0.9|shellcheck"/'

expect_refusal tool-unknown-group \
  'PACKAGE_TOOLS names an unknown group: Packages|Nope' \
  's/^  "Packages|Lints|shellcheck|0.9|shellcheck"$/  "Packages|Nope|shellcheck|0.9|shellcheck"/'

expect_refusal tool-unknown-source \
  'PACKAGE_TOOLS names an unknown source: nope' \
  's/^  "Packages|Lints|shellcheck|0.9|shellcheck"$/  "Packages|Lints|shellcheck|0.9|nope"/'

expect_refusal tool-bad-minimum \
  'PACKAGE_TOOLS has a bad minimum: v0.9' \
  's/^  "Packages|Lints|shellcheck|0.9|shellcheck"$/  "Packages|Lints|shellcheck|v0.9|shellcheck"/'

expect_refusal service-group-duplicate \
  'SERVICE_GROUPS repeats the group: Daemons' \
  's/^  "Daemons|background processes"$/  "Daemons|first"\n  "Daemons|second"/'

expect_refusal service-missing-field \
  'SERVICE_ROWS needs group|service|probe' \
  's/^  "Daemons|docker|docker-daemon"$/  "Daemons|docker"/'

expect_refusal service-unknown-group \
  'SERVICE_ROWS names an unknown group: Nope' \
  's/^  "Daemons|docker|docker-daemon"$/  "Nope|docker|docker-daemon"/'

expect_refusal service-unknown-probe \
  'SERVICE_ROWS names an unknown probe: nope' \
  's/^  "Daemons|docker|docker-daemon"$/  "Daemons|docker|nope"/'

expect_refusal service-section-empty \
  'SERVICE_SECTION needs a name when SERVICE_ROWS is set' \
  "s/^SERVICE_SECTION='Services|4|2'$/SERVICE_SECTION=''/"


no_services_section() { ! grep -q '^Services$' <<<"$out"; }
no_zzz_package() { ! grep -q 'install .* zzz$' <<<"$out"; }

# Given: a catalogue that maps a command to a package
# When:  the report runs
# Then:  the install line carries the package, not the command
printf '\n  --- what the sections produce ---\n'

# The Debian name wins over the command name in the install hint.
mapping=$work/mapping.sh
sed -e 's/^declare -A PACKAGE_DEBIAN=($/&\n  [zzz]=zzz-package/' \
  -e 's|^  "Packages\|Lints\|shellcheck\|0.9\|shellcheck"$|  "Packages\|Lints\|shellcheck\|0.9\|shellcheck"\n  "Packages\|Lints\|zzz\|1.0\|posix"|' \
  "$doctor" > "$mapping"
chmod +x "$mapping"
run_doctor mapping.sh
check 'a mapped tool installs under its package name' grep -q 'sudo apt-get install -y .*zzz-package' <<<"$out"
check 'the command name is not offered as a package' no_zzz_package

# An empty service list keeps its section out of the report.
empty=$work/empty.sh
sed -e '/^  "Daemons|background processes"$/d' \
  -e '/^  "Daemons|docker|docker-daemon"$/d' \
  "$doctor" > "$empty"
chmod +x "$empty"
run_doctor empty.sh
check 'an empty service list draws no section' no_services_section
check 'the packages section still renders' grep -q '^Packages$' <<<"$out"

# Two modules side by side, each with its own indent and gap.
twomod=$work/twomod.sh
sed -e 's/^  "Packages|4|2"$/  "Packages|4|2"\n  "Services|6|3"/' \
  -e 's/^  "Packages|Lints|source issue checks"$/  "Packages|Lints|source issue checks"\n  "Services|Daemons|daemons the project needs"/' \
  -e 's|^  "Packages\|Lints\|shellcheck\|0.9\|shellcheck"$|  "Packages\|Lints\|shellcheck\|0.9\|shellcheck"\n  "Services\|Daemons\|zzz\|1.0\|posix"|' \
  "$doctor" > "$twomod"
chmod +x "$twomod"
run_doctor twomod.sh
check 'a second module gets its own tree' grep -q '^Services$' <<<"$out"
check 'the second module uses its own indent' grep -qE '^ {6}[+\\]-- Daemons' <<<"$out"
check 'the first module keeps its indent' grep -qE '^ {4}\+-- Terminals' <<<"$out"

# Given: a binary in PATH that no package owns
# When:  the report reads its version
# Then:  docker answers for itself and an unknown program shows --
printf '\n  --- a binary no package owns ---\n'

# A program with no package and no special treatment shows -- as its version.
loose=$work/doctor-loose.sh
mkdir -p "$work/bin-loose"
printf '#!/bin/sh\necho "7.8.9"\n' > "$work/bin-loose/zzz"
chmod +x "$work/bin-loose/zzz"
awk '
  /^  "Packages\|Lints\|shellcheck\|0.9\|shellcheck"$/ {
    print
    print "  \"Packages|Lints|zzz|7.0|dpkg\""
    next
  }
  { print }
' "$doctor" > "$loose"
chmod +x "$loose"
run_doctor doctor-loose.sh "$work/bin-loose"
check 'a binary with no package shows --' grep -qE 'zzz +-- +>= 7\.0 +ok' <<<"$out"

# Docker has one: version_of_program() reads the binary itself.
cp "$doctor" "$work/doctor-docker.sh"
chmod +x "$work/doctor-docker.sh"
mkdir -p "$work/bin-docker"
printf '#!/bin/sh\necho "29.8.2"\n' > "$work/bin-docker/docker"
chmod +x "$work/bin-docker/docker"
run_doctor doctor-docker.sh "$work/bin-docker"
check 'docker without a package reads the binary version' \
  grep -qE 'docker +29\.8\.2 +>= 20\.10 +ok' <<<"$out"

# Given: the commands in the catalogue
# When:  each one is resolved to its Debian package
# Then:  every name exists in the repository
printf '\n  --- Debian package names ---\n'

# Every command in the catalogue, and the package the hint would offer for it,
# has to exist in the repository. apt-cache answers when the lists are present.
if apt-cache show bash > /dev/null 2>&1; then
  map_text=$(sed -n '/^declare -A PACKAGE_DEBIAN=(/,/^)/p' "$doctor")
  catalogue=$(sed -n '/^PACKAGE_TOOLS=(/,/^)/p' "$doctor" |
    sed -n 's/^  "[^|]*|[^|]*|\([^|]*\)|.*/\1/p' | LC_ALL=C sort -u)
  unknown=''
  while IFS= read -r command; do
    [[ -n $command ]] || continue
    package=$(grep -oE "\[$command\]=[a-z0-9.+:-]+" <<<"$map_text" | head -1 | cut -d= -f2 || true)
    package=${package:-$command}
    apt-cache show "$package" > /dev/null 2>&1 || unknown+=" $command->$package"
  done <<<"$catalogue"
  check 'every catalogue command maps to a package that exists' test -z "$unknown"
  [[ -z $unknown ]] || printf '          unknown:%s\n' "$unknown"
else
  printf '    skip  no apt lists: package names not checked\n'
fi

# Given: a host without dpkg
# When:  the report starts
# Then:  it refuses with exit 2 instead of comparing numbers
printf '\n  --- the dpkg requirement ---\n'

# Comparing versions is dpkg's job: without it the run stops before probing.
minimal=$work/min-bin
mkdir -p "$minimal"
ln -sf "$(command -v bash)" "$minimal/bash"
set +e
out=$(env PATH="$minimal" bash "$doctor" 2>&1)
status=$?
set -e
check 'a host without dpkg is refused' test "$status" -eq 2
check 'the refusal names dpkg' grep -q 'dpkg is required' <<<"$out"

# Given: a tool reporting a known version against a minimum
# When:  the report compares them
# Then:  ok and too old follow the Debian ordering
printf '\n  --- version comparison ---\n'

# One injected tool, one fake binary, one minimum: the status tells the story.
version_case() { # NAME OUTPUT MINIMUM SHOWN EXPECTED
  local name=$1 output=$2 minimum=$3 shown=$4 expected=$5
  local bin=$work/bin-$name copy=$work/$name.sh

  mkdir -p "$bin"
  printf '#!/bin/sh\necho "%s"\n' "$output" > "$bin/zzz"
  chmod +x "$bin/zzz"

  sed "s#^  \"Packages|Lints|shellcheck|0.9|shellcheck\"\$#&\n  \"Packages|Lints|zzz|$minimum|posix\"#" \
    "$doctor" > "$copy"
  chmod +x "$copy"

  run_doctor "$name.sh" "$bin"
  # The posix probe keeps the dotted number only, so "0.9.0-rc1" shows as 0.9.0.
  check "version $name: $output reads as $shown and is $expected" \
    grep -qE "zzz +$shown +>= $minimum +$expected\$" <<<"$out"
}

version_case numeric-order 1.10 1.9 1.10 ok
version_case numeric-order-old 1.9 1.10 1.9 "too old"
version_case component-count 4.0 4 4.0 ok
version_case suffix-below 0.9.0-rc1 1.0 0.9.0 "too old"
version_case suffix-at-minimum 1.0.0-rc1 1.0.0 1.0.0 ok

# A tool that is too old still gets an install line, because installing fixes it.
stale=$work/stale.sh
mkdir -p "$work/bin-stale"
printf '#!/bin/sh\necho "0.5.0"\n' > "$work/bin-stale/zzz"
chmod +x "$work/bin-stale/zzz"
sed "s#^  \"Packages|Lints|shellcheck|0.9|shellcheck\"\$#&\n  \"Packages|Lints|zzz|1.0|posix\"#" \
  "$doctor" > "$stale"
chmod +x "$stale"
run_doctor stale.sh "$work/bin-stale"
check 'a stale tool is listed as too old' grep -qE 'too old +zzz 0.5.0' <<<"$out"
check 'a stale tool joins the install line' grep -q 'sudo apt-get install -y .*zzz' <<<"$out"

# Given: a terminal that is not a terminal
# When:  the colour variables are set
# Then:  FORCE_COLOR colours and NO_COLOR wins over it
printf '\n  --- colour precedence ---\n'

# The documented command is ./doctor.sh, so a lost mode is a real failure and
# the test states it here rather than letting it look like a colour problem.
check 'doctor.sh is executable' test -x "$doctor"

# bash runs the file, so the colour assertions test colour and nothing else; the
# ambient environment must not decide the result either, since NO_COLOR wins
# over FORCE_COLOR by design.
forced=$(env -u NO_COLOR FORCE_COLOR=1 bash "$doctor" 2>&1 | grep -c $'\033' || true)
check 'FORCE_COLOR emits escapes' test "$forced" -gt 0

suppressed=$(env NO_COLOR=1 FORCE_COLOR=1 bash "$doctor" 2>&1 | grep -c $'\033' || true)
check 'NO_COLOR wins over FORCE_COLOR' test "$suppressed" -eq 0

summary
