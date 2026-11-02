#!/usr/bin/env bash
# =============================================================================
# test-doctor-services.sh - the Services section, against a real docker daemon.
#
# The container probe and the daemon probe are the two a container can exercise,
# so they are the two this file covers with docker. The systemd mapping is driven
# by a systemctl shim instead, because there is no systemd inside a container.
# Without a reachable daemon the file reports a skip and exits 0, so the suite
# still runs on a machine without docker.
#
# Given  a container, a daemon or a systemctl shim
# When   doctor.sh runs
# Then   the Services row, the summary and the hint say what happened
# =============================================================================
set -Eeuo pipefail

root=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
doctor=$root/doctor.sh
# The path is built at run time, so shellcheck cannot follow it.
# shellcheck disable=SC1091
source "$root/tests/lib.sh"

work=$(mktemp -d)
target=dsh-doctor-services-test
# Every container this suite starts carries this label, so a removal can never
# touch a container somebody else created.
label=dsh-doctor

# The containers this suite owns: same label, same name.
own_container() { # NAME
  docker ps -aq --filter "label=$label" --filter "name=^$1$"
}

cleanup() {
  docker rm -f "$(own_container "$target")" > /dev/null 2>&1 || true
  # find -delete removes the tree bottom-up, without a recursive force flag
  find "$work" -delete 2>/dev/null || true
}
trap cleanup EXIT


# A container with the same name that this suite did not create is not ours to
# remove: skip instead of deleting somebody else's work.
if docker ps -aq --filter "name=^$target$" | grep -q . && [[ -z $(own_container "$target") ]]; then
  skip_test "a container named $target exists and was not started here"
fi

if ! docker info > /dev/null 2>&1; then
  skip_test 'no docker daemon: the service probes are not exercised'
fi

# A copy of the doctor with one extra row pointing at the test container.
copy_with() { # ROW... - extra SERVICE_ROWS entries
  local row
  for row in "$@"; do
    printf '%s\n' "$row"
  done > "$work/extra.txt"

  awk -v extra="$work/extra.txt" '
    /^SERVICE_ROWS=\($/ { print; while ((getline row < extra) > 0) print row; next }
    { print }
  ' "$doctor" > "$work/doctor.sh"
  chmod +x "$work/doctor.sh"
}

printf '\n  --- the container probe, against the real daemon ---\n'

# Given: one container, started, stopped and then removed
# When:  the report runs after each step
# Then:  the row follows the container, and the summary follows the row
copy_with "  \"Daemons|$target|docker\""

docker run -d --label "$label" --name "$target" ubuntu:24.04 sleep 120 > /dev/null
run_doctor doctor.sh
save_output services-running
expect_match "$target +docker +running"
check 'a container gets no start hint' refuses grep -qE '^ *start ' <<<"$out"

docker stop "$target" > /dev/null
run_doctor doctor.sh
save_output services-stopped
expect_match "$target +docker +stopped"
expect_match "stopped +$target"
check 'a container gets no start hint' refuses grep -qE '^ *start ' <<<"$out"

docker rm -f "$(own_container "$target")" > /dev/null
run_doctor doctor.sh
save_output services-absent
expect_match "$target +docker +absent"

printf '\n  --- the daemon probe ---\n'

# Given: a reachable daemon, then a shim that answers nothing
# When:  the report asks the engine
# Then:  running turns into stopped, and a start hint appears
run_doctor doctor.sh
expect_match 'docker +docker-daemon +running'

mkdir -p "$work/bin"
# shellcheck disable=SC2016 # $1 belongs to the shim, not to this script
printf '#!/bin/sh\ncase "$1" in version) echo 29.0.0 ;; *) exit 1 ;; esac\n' \
  > "$work/bin/docker"
chmod +x "$work/bin/docker"
run_doctor doctor.sh "$work/bin"
save_output services-daemon-down
expect_match 'docker +docker-daemon +stopped'
expect_contains 'sudo systemctl start docker'

printf '\n  --- a long unit name ---\n'

# Given: a service whose name is wider than any other column
# When:  the report measures the frame
# Then:  the rule grows with it and the name is printed in full
copy_with '  "Daemons|a-service-with-a-rather-long-name|docker"'
run_doctor doctor.sh
longest=$(awk 'length > n { n = length } END { print n }' <<<"$out")
rule=$(grep -E '^-+$' <<<"$out" | awk '{ print length }' | LC_ALL=C sort -u)
check 'the rule spans the longest line' test "$rule" -ge "$longest"
expect_contains 'a-service-with-a-rather-long-name'

printf '\n  --- the systemd mapping, driven by a shim ---\n'

# Given: a systemctl that prints the five fields from the environment
# When:  the fields vary
# Then:  the state word matches map_systemd_state
copy_with '  "Daemons|fixture|systemd"'
mkdir -p "$work/sysd"
cat > "$work/sysd/systemctl" <<'SHIM'
#!/bin/sh
printf 'LoadState=%s\n' "${FAKE_LOAD:-loaded}"
printf 'ActiveState=%s\n' "${FAKE_ACTIVE:-inactive}"
printf 'SubState=%s\n' "${FAKE_SUB:-dead}"
printf 'Result=%s\n' "${FAKE_RESULT:-success}"
printf 'Type=%s\n' "${FAKE_TYPE:-simple}"
SHIM
chmod +x "$work/sysd/systemctl"

systemd_report() { # ENV... - the fixture copy, run with the shim on PATH
  (
    cd "$work" || exit 1
    env PATH="$work/sysd:/usr/bin:/bin" "$@" ./doctor.sh 2>&1 || true
  )
}

systemd_state() { # ENV... - the last column of the fixture row
  systemd_report "$@" | awk '/fixture/ { print $NF; exit }'
}

check 'a running service reports running' \
  test "$(systemd_state FAKE_ACTIVE=active FAKE_SUB=running)" = running
check 'a socket reports listening' \
  test "$(systemd_state FAKE_ACTIVE=active FAKE_SUB=listening)" = listening
check 'a timer reports scheduled' \
  test "$(systemd_state FAKE_ACTIVE=active FAKE_SUB=waiting)" = scheduled
check 'a finished oneshot reports done' \
  test "$(systemd_state FAKE_ACTIVE=inactive FAKE_SUB=dead FAKE_TYPE=oneshot)" = "done"
check 'a stopped service reports stopped' \
  test "$(systemd_state FAKE_ACTIVE=inactive FAKE_SUB=dead FAKE_TYPE=simple)" = stopped
check 'a failed run reports failed' \
  test "$(systemd_state FAKE_ACTIVE=failed FAKE_SUB=failed FAKE_RESULT=failed)" = failed
check 'an unknown unit reports absent' \
  test "$(systemd_state FAKE_LOAD=not-found)" = absent
check 'activating is unknown' \
  test "$(systemd_state FAKE_ACTIVE=activating FAKE_SUB=start)" = unknown

printf '\n  --- a group with no unit still speaks ---\n'

# Given: the four groups, with only Daemons carrying a row
# When:  the report draws the section
# Then:  the empty groups say so, under their own name
out=$(systemd_report FAKE_ACTIVE=inactive FAKE_SUB=dead)
for group in Sockets Paths Timers Containers; do
  check "$group is drawn with an empty note" \
    grep -qE "^ *[+\\]-- $group .*$" <<<"$out"
done
check 'the empty note appears once per empty group' \
  test "$(grep -c 'no unit declared' <<<"$out")" -eq 4

printf '\n  --- what reaches the summary ---\n'

# Given: a scheduled service and an activating one
# When:  the report runs
# Then:  the scheduled one is healthy and silent; the unknown one is reported
out=$(systemd_report FAKE_ACTIVE=active FAKE_SUB=waiting)
save_output shim-scheduled
check 'a scheduled service is not listed as a problem' \
  refuses grep -qE '^ *scheduled ' <<<"$out"
out=$(systemd_report FAKE_ACTIVE=activating FAKE_SUB=start)
expect_match '^ *unknown .*fixture'

# Given: one absent container and one stopped service
# When:  the summary is drawn
# Then:  severity decides the order: absent comes first
copy_with '  "Daemons|gone-container|docker"' '  "Daemons|fixture|systemd"'
out=$(systemd_report FAKE_ACTIVE=inactive FAKE_SUB=dead)
save_output shim-summary-order
absent_line=$(grep -n '^ *absent ' <<<"$out" | cut -d: -f1 | head -1)
stopped_line=$(grep -n '^ *stopped ' <<<"$out" | cut -d: -f1 | head -1)
check 'absent is listed before stopped' test "${absent_line:-0}" -lt "${stopped_line:-0}"

summary
