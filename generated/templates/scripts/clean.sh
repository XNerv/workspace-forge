#!/usr/bin/env bash
#
# clean.sh - remove what this workspace generates and no longer needs.
#
# Usage: clean.sh [--help]
#
# Accepted arguments: --help. The script takes no other option and no
# positional argument.
#
# This script ships as a skeleton. Edit this script to match this workspace:
# the scope below is intentionally open and you decide it.

set -Eeuo pipefail

not_implemented() {
  printf 'not implemented: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
clean.sh - remove what this workspace generates and no longer needs

Usage: clean.sh [--help]

The script ships as a skeleton; it removes nothing until you implement it.
Edit it to match this workspace and decide what the cleaning covers.

Options:
  --help   show this help and exit 0
EOF
}

clean() {
  # Perform whatever cleaning process this workspace requires —
  # including external/generated artifacts, not only files inside the workspace.
  not_implemented "clean"
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
  clean
}

main "$@"
