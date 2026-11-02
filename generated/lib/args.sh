#!/usr/bin/env bash
#
# lib/args.sh - defaults, help text and command-line parsing.
#
# This file defines functions and constants only; sourcing it starts nothing.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  printf 'lib/args.sh is a library: source it from forge, do not run it\n' >&2
  exit 1
fi

# The counters and the destination are globals: another library writes them and
# a third reads them, so export each one and keep ShellCheck quiet with a real
# use rather than a file-wide suppression.
export FORGE_TARGET="${HOME:-}/workspace"
export FORGE_DRY_RUN=0
export FORGE_CREATED_DIRS=0
export FORGE_CREATED_FILES=0
export FORGE_TOTAL_DIRS=12
export FORGE_TOTAL_FILES=0
FORGE_TARGET_SET=0

usage() {
  cat <<'EOF'
forge - create a standardized workspace

Usage:
  forge [OPTIONS]

Options:
  -p, --path PATH   destination directory; default: $HOME/workspace
  -n, --dry-run     print every planned directory and file; write nothing
  -h, --help        show this help and exit 0
  -v, --version     show the version and exit 0

The destination must not exist, not even as an empty directory: forge is
create-only and never updates an existing workspace.

Examples:
  forge --dry-run -p ~/lab    # plan; prints paths, writes nothing
  forge -p ~/lab              # create the workspace in ~/lab
  forge                       # create $HOME/workspace, after a dry run

Protections:
  forge refuses /, $HOME, system directories, the home directory of another
  user and any path inside this tool repository. A destination below the
  temporary root ($TMPDIR, or /tmp when unset) is allowed when the
  destination is a new child of that root.

Exit codes:
  0  success, help, version or a valid dry run
  1  unexpected error
  2  usage error
  3  safety refusal: forbidden path or destination already exists
  4  missing requirement: Bash 4, a supported platform, HOME or a tool
  5  filesystem failure

Platform: Linux and WSL2. Native Windows shells and macOS are refused.
EOF
}

# _expand_tilde VALUE prints VALUE with a leading ~ or ~/ replaced by HOME.
# ~user is rejected with status 1; no other expansion happens.
_expand_tilde() {
  local value=$1 tilde='~'
  if [[ $value == "$tilde" ]]; then
    printf '%s\n' "${HOME:-}"
  elif [[ $value == "$tilde"/* ]]; then
    printf '%s\n' "${HOME:-}/${value#"$tilde/"}"
  elif [[ $value == "$tilde"* ]]; then
    return 1
  else
    printf '%s\n' "$value"
  fi
}

# _set_target VALUE OPTION validates one destination value and stores it.
_set_target() {
  local raw=$1 option=$2 expanded=""
  if [[ -z $raw ]]; then
    die 2 "empty value for $option"
  fi
  case $raw in
    *$'\n'* | *$'\r'* | *$'\t'*)
      die 2 "control character in the value of $option"
      ;;
  esac
  if ! expanded=$(_expand_tilde "$raw"); then
    die 2 "~user is not supported: $raw"
  fi
  if [[ -z $expanded ]]; then
    die 2 "empty value for $option"
  fi
  if [[ $FORGE_TARGET_SET -eq 1 ]]; then
    die 2 "$option given more than once"
  fi
  FORGE_TARGET=$expanded
  FORGE_TARGET_SET=1
}

# parse_args reads every option. Help wins over version, and both exit before
# preflight. Branches for -- come before the wildcards, so the terminator is
# reachable and ShellCheck reports no duplicate pattern.
parse_args() {
  local value="" option="" show_version=0
  while (($#)); do
    case $1 in
      --)
        shift
        if (($#)); then
          die 2 "unexpected argument after --: $1"
        fi
        break
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -v | --version)
        show_version=1
        shift
        ;;
      -n | --dry-run)
        FORGE_DRY_RUN=1
        shift
        ;;
      -p | --path)
        if (($# < 2)); then
          die 2 "$1 requires a value"
        fi
        option=$1
        value=$2
        shift 2
        _set_target "$value" "$option"
        ;;
      --path=*)
        value=${1#--path=}
        _set_target "$value" "--path"
        shift
        ;;
      --*)
        die 2 "unknown option: $1"
        ;;
      -?*)
        die 2 "unknown option: $1"
        ;;
      *)
        die 2 "unexpected argument: $1"
        ;;
    esac
  done
  if ((show_version)); then
    printf 'forge %s\n' "$FORGE_VERSION"
    exit 0
  fi
}
