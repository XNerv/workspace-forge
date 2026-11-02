#!/usr/bin/env bash
#
# lib/common.sh - message streams, colours, path resolution and path protection.
#
# This file defines functions and constants only; sourcing it starts nothing.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  printf 'lib/common.sh is a library: source it from forge, do not run it\n' >&2
  exit 1
fi

# A colour decorates only the stream it writes to. NO_COLOR and TERM=dumb
# switch every colour off.
FORGE_COLOR_STDOUT=0
FORGE_COLOR_STDERR=0
if [[ -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb ]]; then
  if [[ -t 1 ]]; then
    FORGE_COLOR_STDOUT=1
  fi
  if [[ -t 2 ]]; then
    FORGE_COLOR_STDERR=1
  fi
fi

_forge_red=$'\033[31m'
_forge_green=$'\033[32m'
_forge_yellow=$'\033[33m'
_forge_blue=$'\033[34m'
_forge_reset=$'\033[0m'

_forge_print() {
  local fd=$1 colour=$2 message=$3 enabled=0
  if [[ $fd -eq 1 ]]; then
    enabled=$FORGE_COLOR_STDOUT
  else
    enabled=$FORGE_COLOR_STDERR
  fi
  if [[ $enabled -eq 1 && -n $colour ]]; then
    printf '%s%s%s\n' "$colour" "$message" "$_forge_reset" >&"$fd"
  else
    printf '%s\n' "$message" >&"$fd"
  fi
}

# log writes a plain diagnostic line to stderr.
log() {
  _forge_print 2 "" "$*"
}

# info, ok, warn and err label a diagnostic line and write it to stderr.
info() {
  _forge_print 2 "$_forge_blue" "info: $*"
}

ok() {
  _forge_print 2 "$_forge_green" "ok: $*"
}

warn() {
  _forge_print 2 "$_forge_yellow" "warning: $*"
}

err() {
  _forge_print 2 "$_forge_red" "error: $*"
}

# die CODE MESSAGE prints the message to stderr and exits with CODE.
# It terminates the current process, so never call it inside a command
# substitution when the parent must stop: the exit code would stay in the
# subshell. Exit codes outside 1..125 are replaced by 1.
die() {
  local code=${1:-1}
  shift 2>/dev/null || true
  case $code in
    '' | *[!0-9]*) code=1 ;;
  esac
  if ((code < 1 || code > 125)); then
    code=1
  fi
  err "${*:-unexpected error}"
  exit "$code"
}

# _abspath PATH prints the absolute form of PATH and sets two globals:
# FORGE_ABSPATH_RESULT holds the same path and FORGE_ABSPATH_CANONICAL holds 1
# when every existing component was resolved.
#
# Call it as a plain statement when the flag matters: a command substitution
# runs in a subshell and loses both globals.
_abspath() {
  local input=${1-} resolved=""

  FORGE_ABSPATH_RESULT=""
  FORGE_ABSPATH_CANONICAL=0

  if [[ -z $input ]]; then
    err "_abspath: empty path"
    return 1
  fi
  case $input in
    *$'\n'* | *$'\r'* | *$'\t'*)
      err "_abspath: control character in path: $input"
      return 1
      ;;
  esac

  if command -v python3 > /dev/null 2>&1; then
    resolved=$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[2]))' -- "$input" 2>/dev/null) || resolved=""
  fi
  if [[ -z $resolved ]] && command -v realpath > /dev/null 2>&1; then
    resolved=$(realpath -m -- "$input" 2>/dev/null) || resolved=""
  fi
  if [[ -z $resolved ]]; then
    resolved=$(_abspath_manual "$input") || return 1
  fi
  if [[ -z $resolved || $resolved != /* ]]; then
    err "_abspath: cannot resolve an absolute path for: $input"
    return 1
  fi

  FORGE_ABSPATH_RESULT=$resolved
  FORGE_ABSPATH_CANONICAL=1
  export FORGE_ABSPATH_RESULT FORGE_ABSPATH_CANONICAL
  printf '%s\n' "$resolved"
}

# _abspath_manual resolves the longest existing prefix with cd -P and appends
# the normalized suffix. A nonexistent component cannot be a symbolic link, so
# the result is canonical whenever the prefix resolves.
_abspath_manual() {
  local input=$1 dir suffix="" base
  [[ $input == /* ]] || input=$PWD/$input
  while [[ $input != / && $input == */ ]]; do
    input=${input%/}
  done
  dir=$input
  while [[ ! -d $dir ]]; do
    if [[ $dir == / ]]; then
      return 1
    fi
    suffix="/${dir##*/}$suffix"
    dir=${dir%/*}
    if [[ -z $dir ]]; then
      dir=/
    fi
  done
  base=$(cd -P -- "$dir" 2>/dev/null && pwd) || return 1
  _abspath_join "$base" "$suffix"
}

# _abspath_join BASE SUFFIX normalizes BASE plus SUFFIX, one component at a
# time. A .. that would leave BASE is an error, never a silent escape.
_abspath_join() {
  local base=$1 suffix=$2 part result=""
  local -a parts=() tail=()
  local IFS=/
  read -r -a parts <<< "${base#/}"
  if [[ -n $suffix ]]; then
    read -r -a tail <<< "${suffix#/}"
  fi
  for part in "${tail[@]}"; do
    case $part in
      '' | .) ;;
      ..)
        if ((${#parts[@]} == 0)); then
          err "_abspath: path escapes the filesystem root: $base$suffix"
          return 1
        fi
        unset "parts[$(( ${#parts[@]} - 1 ))]"
        ;;
      *) parts+=("$part") ;;
    esac
  done
  for part in "${parts[@]}"; do
    result="$result/$part"
  done
  printf '%s\n' "${result:-/}"
}

# path_is_within CHILD PARENT compares absolute paths on component boundaries:
# /various is not inside /var, while /var/foo is. CHILD equal to PARENT counts
# as within.
path_is_within() {
  local child=${1-} parent=${2-}
  [[ -n $child && -n $parent ]] || return 1
  while [[ $child != / && $child == */ ]]; do
    child=${child%/}
  done
  while [[ $parent != / && $parent == */ ]]; do
    parent=${parent%/}
  done
  if [[ $parent == / ]]; then
    [[ $child == /* ]]
    return
  fi
  [[ $child == "$parent" || $child == "$parent"/* ]]
}

# _forge_temp_root prints the canonical temporary root this run trusts. TMPDIR
# counts only when it resolves to /tmp, /var/tmp or a path below /var/tmp;
# anything else falls back to /tmp.
_forge_temp_root() {
  local candidate=${TMPDIR:-/tmp} canonical
  canonical=$(cd -P -- "$candidate" 2>/dev/null && pwd) || canonical=/tmp
  case $canonical in
    /tmp | /var/tmp | /var/tmp/*) printf '%s\n' "$canonical" ;;
    *) printf '/tmp\n' ;;
  esac
}

# path_is_forbidden PATH answers whether the destination table refuses PATH.
# The function is pure: it reads HOME and TMPDIR and writes nothing.
path_is_forbidden() {
  local path=${1-} home=${HOME:-} tmp_root name system
  [[ -n $path && $path == /* ]] || return 1

  # / is an exact rule: every descendant is refused by the other rules.
  if [[ $path == / ]]; then
    return 0
  fi
  if [[ -n $home && $path == "$home" ]]; then
    return 0
  fi

  # Configuration and credential paths below HOME.
  for name in .ssh .gnupg .aws .azure .kube .docker .config .local \
    .password-store .terraform.d .npmrc .pypirc .netrc .git-credentials; do
    if [[ -n $home ]] && path_is_within "$path" "$home/$name"; then
      return 0
    fi
  done

  # The temporary exception: a strict descendant of the trusted root.
  tmp_root=$(_forge_temp_root)
  if [[ $path == "$tmp_root" ]]; then
    return 0
  fi
  if path_is_within "$path" "$tmp_root"; then
    return 1
  fi

  # System directories: equal or descendant.
  for system in /usr /etc /bin /sbin /var /boot /dev /sys /proc /root /opt \
    /srv /run; do
    if path_is_within "$path" "$system"; then
      return 0
    fi
  done

  # /home itself and every home that is not $HOME or below it.
  if [[ $path == /home ]]; then
    return 0
  fi
  if path_is_within "$path" /home; then
    if [[ -n $home ]] && path_is_within "$path" "$home"; then
      return 1
    fi
    return 0
  fi
  return 1
}
