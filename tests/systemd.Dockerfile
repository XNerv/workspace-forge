# =============================================================================
# systemd.Dockerfile - the container the systemd test boots.
#
# test-doctor-systemd.sh needs a container that runs systemd as PID 1, because
# the probe reads real units with systemctl show. This image is that container:
# the same Ubuntu baseline as everything else here, with the init as its command,
# so no third-party image and no pinned version have to be fetched.
#
# The test builds it on demand:
#
#   docker build -f tests/systemd.Dockerfile -t dsh-systemd .
#
# README.md, "Host checks", has the guide.
# =============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# systemd-sysv is what places /sbin/init; dbus comes with systemd.
RUN apt-get update \
 && apt-get install -y --no-install-recommends systemd systemd-sysv \
 && apt-get clean

# systemd wants SIGRTMIN+3, not SIGTERM, to shut down cleanly.
STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
