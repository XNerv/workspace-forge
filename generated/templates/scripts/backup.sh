#!/usr/bin/env bash
#
# backup.sh - create a backup archive of this workspace.
#
# Usage: backup.sh --output DIR [--dry-run] [--help]
#
# Accepted arguments:
#   --output DIR   directory that receives the archive; required
#   --dry-run      print the command and the planned archive; create nothing
#   --help         show this help and exit 0
#
# This script ships as a skeleton. Edit this script to match this workspace:
# the archive tool, the exclude list and the retention policy are yours.

set -Eeuo pipefail

not_implemented() {
  printf 'not implemented: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
backup.sh - create a backup archive of this workspace

Usage: backup.sh --output DIR [--dry-run] [--help]

The script ships as a skeleton; every stage fails until you implement it.
The data/ directory is excluded from the backup by default.

Options:
  --output DIR   directory that receives the archive; required
  --dry-run      print the command and the planned archive; create nothing
  --help         show this help and exit 0
EOF
}

assert_output_outside_workspace() {
  # Guarantee the output directory is not inside the archived tree, including through a symbolic link.
  not_implemented "assert_output_outside_workspace"
}

build_excludes() {
  # Assemble the exclude list (secrets, operational files, caches, outputs).
  not_implemented "build_excludes"
}

run_dry_run() {
  # Print the command and planned archive path; create nothing.
  not_implemented "run_dry_run"
}

create_backup() {
  # Create the archive readable and writable only by its owner (mode 600); refuse to overwrite an existing backup.
  not_implemented "create_backup"
}

main() {
  local output="" dry_run=0
  while (($#)); do
    case $1 in
      --help)
        usage
        exit 0
        ;;
      --output)
        if (($# < 2)); then
          printf 'option --output requires a value\n' >&2
          exit 2
        fi
        output=$2
        shift 2
        ;;
      --output=*)
        output=${1#--output=}
        shift
        ;;
      --dry-run)
        dry_run=1
        shift
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

  if [[ -z $output ]]; then
    printf 'option --output is required\n' >&2
    exit 2
  fi

  assert_output_outside_workspace "$output"
  build_excludes
  if [[ $dry_run -eq 1 ]]; then
    run_dry_run
  else
    create_backup
  fi
}

main "$@"
