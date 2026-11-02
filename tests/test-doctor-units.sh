#!/usr/bin/env bash
# =============================================================================
# test-doctor-units.sh - the pure functions, called directly.
#
# doctor.sh stops before main() when it is sourced, so this file loads it and
# calls the helpers with arguments: no PATH shim, no container, no copy of the
# sections. If a helper gains a side effect, these tests notice first.
#
# Given  doctor.sh loaded into this shell
# When   a helper is called with known arguments
# Then   it returns the documented value and touches nothing
# =============================================================================
set -Eeuo pipefail

root=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=/dev/null
source "$root/doctor.sh"
# The path is built at run time, so shellcheck cannot follow it.
# shellcheck disable=SC1091
source "$root/tests/lib.sh"

expect() { # NAME EXPECTED COMMAND...
  local name=$1 expected=$2
  shift 2
  local got
  got=$("$@")
  check "$name" test "$got" = "$expected"
}

printf '\n  --- spacing: the width of a column ---\n'

# Given: a column width
# When:  spaces pads it
# Then:  the result is exactly that many spaces
expect 'spaces 0 is empty' '' spaces 0
expect 'spaces 3 is three spaces' '   ' spaces 3
expect 'spaces 8 is eight spaces' '        ' spaces 8

printf '\n  --- tree markers: branch or corner ---\n'

# Given: an index and a total
# When:  marker picks the drawing
# Then:  everything but the last item is a branch
expect 'the only item is a corner' '\--' marker 0 1
expect 'the first of two is a branch' '+--' marker 0 2
expect 'the second of two is a corner' '\--' marker 1 2
expect 'the middle of three is a branch' '+--' marker 1 3

printf '\n  --- children: the lead and its bar ---\n'

# Given: a group and its position among its siblings
# When:  children_lead builds the lead of its rows
# Then:  the bar stays while a group follows, and disappears on the last one
expect 'a group with siblings below keeps the bar' '  |   ' children_lead '  ' 0 2
expect 'the last group drops the bar' '      ' children_lead '  ' 1 2
expect 'indent four with siblings' '    |   ' children_lead '    ' 0 3

printf '\n  --- version_ge: the ordering rule ---\n'

# Given: two versions
# When:  version_ge compares them the way dpkg does
# Then:  every rule of the Debian ordering holds
check '1.10 is at least 1.9' version_ge 1.10 1.9
check '1.9 is not at least 1.10' refuses version_ge 1.9 1.10
check '4.0 is at least 4' version_ge 4.0 4
check '5.3.2 is at least 5.3' version_ge 5.3.2 5.3
check '5.3 is not at least 5.3.2' refuses version_ge 5.3 5.3.2
check 'an epoch outranks a higher number' version_ge 1:0.1 2.0
check 'a tilde sorts before the release' refuses version_ge 1.0~rc1 1.0
check 'a higher revision wins' version_ge 1.0-2 1.0-1
check 'an ubuntu revision outranks the plain one' version_ge 1.0-1ubuntu1 1.0-1
check 'a lower revision loses' refuses version_ge 1.0-1 1.0-2
check 'a bare integer sorts below its zero-padded form' refuses version_ge 4 4.0
check 'an empty version is never enough' refuses version_ge '' 1.0
check 'a version always covers itself' version_ge 1.0.0 1.0.0

printf '\n  --- version_of_program: the package first ---\n'

# Given: a command whose package dpkg knows, and one it does not
# When:  version_of_program reads the number
# Then:  the package version wins, and the unknown one says --
check 'a packaged command reads the dpkg version' \
  test "$(version_of_program bash)" = "$(dpkg-query -W -f='${Version}' bash 2>/dev/null)"
check 'an unknown program reports --' test "$(version_of_program nosuch-command-here)" = --
check 'the owner of a packaged command is its package' test "$(package_owner bash)" = bash

printf '\n  --- probes: what they say without their tool ---\n'

# Given: a PATH where nothing is installed
# When:  a probe asks for its tool
# Then:  it reports absent, never a wrong state
check 'a missing docker CLI reports absent' \
  test "$(PATH=/nonexistent probe_docker anything)" = absent
check 'a missing docker daemon CLI reports absent' \
  test "$(PATH=/nonexistent probe_docker_daemon)" = absent
check 'a missing systemctl reports absent' \
  test "$(PATH=/nonexistent probe_systemd sshd.service)" = absent
check 'a missing user bus reports absent' \
  test "$(PATH=/nonexistent probe_systemd_user sshd.service)" = absent
check 'an unknown probe reports unknown' test "$(probe_service mystery x)" = unknown

printf '\n  --- map_systemd_state: the eight states ---\n'

# Given: the five fields systemd reports
# When:  map_systemd_state names the state
# Then:  each unit type lands on the documented word
expect 'a running service' running \
  map_systemd_state sshd.service loaded active running success simple
expect 'a listening socket' listening \
  map_systemd_state docker.socket loaded active listening success -
expect 'a scheduled timer' scheduled \
  map_systemd_state logrotate.timer loaded active waiting success -
expect 'a watching path unit' watching \
  map_systemd_state watch.path loaded active waiting success -
expect 'a finished oneshot' 'done' \
  map_systemd_state once.service loaded inactive dead success oneshot
expect 'a stopped service' stopped \
  map_systemd_state nginx.service loaded inactive dead success simple
expect 'a failed run' failed \
  map_systemd_state bad.service loaded failed failed exit-code oneshot
expect 'an unknown unit' absent \
  map_systemd_state gone.service not-found inactive dead success -
expect 'an activating unit' unknown \
  map_systemd_state slow.service loaded activating start success simple

printf '\n  --- joins: a list in one line ---\n'

# Given: a list of items
# When:  it is joined
# Then:  one item carries no separator
expect 'commas join' 'a, b, c' join_commas a b c
expect 'one item has no comma' 'a' join_commas a
expect 'spaces join' 'a b c' join_spaces a b c
expect 'one item has no space' 'a' join_spaces a

summary
