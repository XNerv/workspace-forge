#!/usr/bin/env bash
#
# doctor.sh - check that this workspace is ready to work in.
#
# Usage: doctor.sh [--help]
#
# Accepted arguments: --help. The script takes no other option and no
# positional argument.
#
# This script ships as a skeleton. Edit this script to match this workspace:
# name the tools, the directories and the permissions this workspace needs.

set -Eeuo pipefail

not_implemented() {
  printf 'not implemented: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
doctor.sh - check that this workspace is ready to work in

Usage: doctor.sh [--help]

The script ships as a skeleton; every check fails until you implement it.
It installs nothing and changes no configuration.

Options:
  --help   show this help and exit 0
EOF
}

check_tools() {
  # Verify required tools are available without installing anything.
  not_implemented "check_tools"
}

check_structure() {
  # Verify the expected directories and files exist.
  not_implemented "check_structure"
}

check_permissions() {
  # Verify scripts are executable and files have safe permissions.
  not_implemented "check_permissions"
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
  check_tools
  check_structure
  check_permissions
}

main "$@"
