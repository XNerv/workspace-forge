# =============================================================================
# Dockerfile - the host the validation needs, and nothing else.
#
# The report checks a Debian-like host, so the image is Ubuntu 24.04 LTS, the
# baseline the catalogue targets. It carries what the suite calls: the standard
# tools, just, shellcheck, and the docker CLI. The two files backed by docker
# talk to the daemon of the host that starts the container, through the socket,
# which is why the run command mounts it.
#
#   docker build -f tests/Dockerfile -t dsh-doctor .
#   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock dsh-doctor
#
# The context is the repository root, because the image copies the whole tree;
# only this file lives with the tests. .dockerignore stays at the root, where
# docker looks for it.
#
# README.md, "Host checks", has the guide and the use cases.
# =============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# The apt lists stay on purpose: the package-name test asks apt-cache about each
# Debian name, and skips when the lists are absent. apt-get clean drops only the
# downloaded archives.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash coreutils findutils grep mawk sed \
      just shellcheck docker.io \
 && apt-get clean

WORKDIR /src
COPY . .

# The suite is the default command; a single file can be named instead.
CMD ["bash", "tests/run.sh"]
