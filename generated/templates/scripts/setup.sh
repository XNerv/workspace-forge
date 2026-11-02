#!/usr/bin/env bash
#
# setup.sh - prepare this workspace on a new machine.
#
# Usage: setup.sh [--help]
#
# Accepted arguments: --help. The script takes no other option and no
# positional argument.
#
# This script ships as a skeleton. Edit this script to match this workspace:
# add the prerequisites and the steps this workspace needs.

set -Eeuo pipefail

not_implemented() {
  printf 'not implemented: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
setup.sh - prepare this workspace on a new machine

Usage: setup.sh [--help]

The script ships as a skeleton; edit it to match this workspace.
It installs nothing and changes no global configuration until you add the steps.

Options:
  --help   show this help and exit 0
EOF
}

execute_setup() {
  # Create the workspace prerequisites the user decides this workspace needs.
  not_implemented "execute_setup"
}

main() {
  while (($#)); do
    case $1 in
      --help)
        usage
        exit 0
        ;;
      -*)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
      *)
        printf 'unexpected argument: %s\n' "$1" >&2
        exit 2
        ;;
    esac
  done
  execute_setup
}

main "$@"
