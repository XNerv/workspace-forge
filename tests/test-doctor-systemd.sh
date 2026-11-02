#!/usr/bin/env bash
# =============================================================================
# test-doctor-systemd.sh - the systemd probe, against real systemd, one unit per state.
#
# This is the high-fidelity test: a privileged container boots systemd as PID 1,
# fixture units are created and started for real, and the doctor reads them with
# `systemctl show`. It needs docker with --privileged; the image it boots comes
# from tests/systemd.Dockerfile and is built on demand. When docker or the build
# is missing the file reports a skip and exits 0, so the suite still runs
# anywhere.
#
# Two fixtures need a companion service, because systemd refuses a socket or a
# timer whose target unit does not exist:
#   fixture-socket.socket -> fixture-socket.service
#   fixture-timer.timer   -> fixture-timer.service
# =============================================================================
set -Eeuo pipefail

root=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
doctor=$root/doctor.sh
# The library comes first: the skips below record themselves through it.
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$root/tests/lib.sh"
image=dsh-systemd
container=dsh-doctor-systemd-test
work=$(mktemp -d)
# Every container this suite starts carries this label; a removal only ever
# touches what the suite created.
label=dsh-doctor

own_container() { # NAME
  docker ps -aq --filter "label=$label" --filter "name=^$1$"
}

cleanup() {
  docker rm -f "$(own_container "$container")" > /dev/null 2>&1 || true
  find "$work" -delete 2>/dev/null || true
}
trap cleanup EXIT


# A container with the same name that this suite did not create is not ours to
# remove: skip instead of deleting somebody else's work.
if docker ps -aq --filter "name=^$container$" | grep -q . && [[ -z $(own_container "$container") ]]; then
  skip_test "a container named $container exists and was not started here"
fi

if ! docker info > /dev/null 2>&1; then
  skip_test 'no docker daemon'
fi
if ! docker image inspect "$image" > /dev/null 2>&1; then
  printf '  |     building %s from tests/systemd.Dockerfile\n' "$image"
  if ! docker build -q -f "$root/tests/systemd.Dockerfile" -t "$image" "$root" > /dev/null 2>&1; then
    skip_test "cannot build $image: docker build -f tests/systemd.Dockerfile -t $image ."
  fi
fi

# A copy of the doctor with one row per fixture, all on the real systemd probe.
copy_with_fixtures() {
  # Each unit goes to the group that names what it is: a .service is a daemon,
  # a .socket is a socket, a .path is a file trigger, a .timer is scheduled work.
  awk '
    { print }
    /^SERVICE_ROWS=\($/ {
      print "  \"Daemons|fixture-running.service|systemd\""
      print "  \"Daemons|fixture-oneshot.service|systemd\""
      print "  \"Daemons|fixture-stopped.service|systemd\""
      print "  \"Daemons|fixture-failed.service|systemd\""
      print "  \"Daemons|fixture-absent.service|systemd\""
      print "  \"Daemons|fixture-user.service|systemd-user\""
      print "  \"Sockets|fixture-socket.socket|systemd\""
      print "  \"Paths|fixture-path.path|systemd\""
      print "  \"Timers|fixture-timer.timer|systemd\""
    }
  ' "$doctor" > "$work/doctor.sh"
  chmod +x "$work/doctor.sh"
}

unit() { # NAME CONTENT - writes a unit file inside the container
  docker exec -i "$container" bash -c "cat > /etc/systemd/system/$1" <<<"$2"
}

start_unit() { # NAME - a failing job is expected for the "failed" fixture
  docker exec "$container" systemctl start "$1" > /dev/null 2>&1 || true
}

# Given: a container running systemd with one fixture unit per state
# When:  the report reads them with systemctl show
# Then:  every state maps to the word the Services section prints, and the
#        summary reports only the states that need attention
printf '\n  --- systemd, PID 1 in a privileged container ---\n'

docker rm -f "$(own_container "$container")" > /dev/null 2>&1 || true
docker run -d --label "$label" --name "$container" --privileged \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw --cgroupns=host \
  "$image" > /dev/null

# systemd may come up as "degraded" in a container; both mean it is answering.
state=''
for _ in $(seq 20); do
  state=$(docker exec "$container" systemctl is-system-running 2>/dev/null || true)
  case $state in
    running | degraded) break ;;
  esac
  sleep 1
done
if [[ $state != running && $state != degraded ]]; then
  skip_test "systemd did not come up in the container (state: ${state:-none})"
fi
printf '  |     systemd state: %s\n' "$state"

copy_with_fixtures

# The report travels by docker cp, so no host path has to be visible to the
# daemon: this file runs the same way on a host, in a container or in CI.
docker cp "$work/doctor.sh" "$container:/tmp/doctor.sh"

unit fixture-running.service '[Unit]
Description=fixture running
[Service]
ExecStart=/bin/sleep 600'
unit fixture-oneshot.service '[Unit]
Description=fixture oneshot
[Service]
Type=oneshot
ExecStart=/bin/true'
unit fixture-socket.service '[Unit]
Description=fixture socket service
[Service]
ExecStart=/bin/sleep 600'
unit fixture-socket.socket '[Unit]
Description=fixture socket
[Socket]
ListenStream=127.0.0.1:23456'
unit fixture-timer.service '[Unit]
Description=fixture timer service
[Service]
Type=oneshot
ExecStart=/bin/true'
unit fixture-timer.timer '[Unit]
Description=fixture timer
[Timer]
OnActiveSec=1h'
unit fixture-path.service '[Unit]
Description=fixture path service
[Service]
ExecStart=/bin/sleep 600'
unit fixture-path.path '[Unit]
Description=fixture path
[Path]
PathExists=/tmp/fixture-trigger'
unit fixture-stopped.service '[Unit]
Description=fixture stopped
[Service]
ExecStart=/bin/sleep 600'
unit fixture-failed.service '[Unit]
Description=fixture failed
[Service]
Type=oneshot
ExecStart=/bin/false'

docker exec "$container" systemctl daemon-reload
start_unit fixture-running.service
start_unit fixture-oneshot.service
start_unit fixture-socket.socket
start_unit fixture-timer.timer
start_unit fixture-path.path
start_unit fixture-failed.service
sleep 1

out=$(docker exec "$container" bash /tmp/doctor.sh 2>&1 || true)
save_output systemd
printf '%s\n' "$out" | sed -n '/^Services/,$p' | sed 's/^/  | /'

fixture_state() { grep -E " $1 " <<<"$out" | awk '{ print $NF; exit }'; }

# Which group a fixture is drawn under, read from the report: the group header
# is the line that opens a tree branch, and it is three fields above the row.
group_of() { # UNIT
  awk -v unit="$1" '
    /^ *[+\\]-- [A-Za-z]+  / { group = $2 }
    index($0, unit) { print group; exit }
  ' <<<"$out"
}

check 'a service sits under Daemons' test "$(group_of fixture-running.service)" = Daemons
check 'the user unit sits under Daemons' test "$(group_of fixture-user.service)" = Daemons
check 'the socket sits under Sockets' test "$(group_of fixture-socket.socket)" = Sockets
check 'the path sits under Paths' test "$(group_of fixture-path.path)" = Paths
check 'the timer sits under Timers' test "$(group_of fixture-timer.timer)" = Timers

check 'a long-running service reports running' test "$(fixture_state fixture-running.service)" = "running"
check 'a finished oneshot reports done' test "$(fixture_state fixture-oneshot.service)" = "done"
check 'a socket reports listening' test "$(fixture_state fixture-socket.socket)" = "listening"
check 'a timer reports scheduled' test "$(fixture_state fixture-timer.timer)" = "scheduled"
check 'a path unit reports watching' test "$(fixture_state fixture-path.path)" = "watching"
check 'a user unit without a session reports absent' \
  test "$(fixture_state fixture-user.service)" = "absent"
check 'a service that never started reports stopped' test "$(fixture_state fixture-stopped.service)" = "stopped"
check 'a unit whose run failed reports failed' test "$(fixture_state fixture-failed.service)" = "failed"
check 'a unit that does not exist reports absent' test "$(fixture_state fixture-absent.service)" = "absent"

check 'the summary lists the stopped fixture' grep -qE '^ *stopped .*fixture-stopped' <<<"$out"
check 'the summary lists the failed fixture' grep -qE '^ *failed .*fixture-failed' <<<"$out"
no_healthy_lines() { ! grep -qE '^ *(running|listening|scheduled|done) +fixture' <<<"$out"; }
check 'healthy states are not listed in the summary' no_healthy_lines

summary
