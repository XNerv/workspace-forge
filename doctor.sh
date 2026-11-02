#!/usr/bin/env bash
# =============================================================================
# doctor.sh - report the host environment this project needs.
#
# The report has two sections, each a list of rows under a group name:
#
#   Packages   name | version found | minimum required | status
#   Services   name | probe used    | state found
#
# The group line above the rows says what they are for.
#
# A package is ok, missing or too old. A service is healthy when
# running, listening, scheduled, watching or done; stopped, failed, absent and
# unknown are reported and fail the run.
#
# Reads only; installs nothing. The guide, with the use cases, is in README.md,
# section "Host checks".
#
# Exit: 0 when nothing needs attention, 1 when something does, 2 on a usage
#       error or an inconsistent section.
# =============================================================================

set -Eeuo pipefail

# Deterministic output: sorting, matching and formatting stop depending on the
# caller's locale. Exported because the commands this script runs inherit it.
export LC_ALL=C

# #############################################################################
# ## PART 1 - THE PART YOU EDIT                                            ####
# #############################################################################

# -----------------------------------------------------------------------------
# 1.1 Packages - modules, groups and tools
#
#   "Name|indent|gap"                       PACKAGE_MODULES: one row per section
#   "Module|Group|description"              PACKAGE_GROUPS: one row per purpose
#   "Module|Group|command|minimum|source"   PACKAGE_TOOLS: one row per command
#
#   minimum: "POSIX" for presence only, or a Debian version ("4.0",
#            "1.0-1ubuntu1", "1:2.0"). Ordering is dpkg's: the run stops at
#            start-up when dpkg is absent, instead of comparing numbers.
#   source:  one of PACKAGE_SOURCES. It answers "installed?" through
#            is_installed() and "which version?" through version_of(). For dpkg,
#            version_of_program() (1.3) reads the package database and only runs
#            the program when no package owns it.
#   PACKAGE_DEBIAN names the Debian package of each command, for the install
#   hint. The version is read by version_of_program() in 1.3.
#
#   README.md, "Host checks", has the guide and the use cases.
# -----------------------------------------------------------------------------
PACKAGE_MODULES=(
  "Packages|4|2"
)

PACKAGE_GROUPS=(
  "Packages|Terminals|command-line environments"
  "Packages|Standard Tools|standard command-line utilities"
  "Packages|Lints|source issue checks"
  "Packages|Recipe Runners|recipe invocation"
  "Packages|Container Runtimes|container execution environments"
)

PACKAGE_TOOLS=(
  "Packages|Terminals|bash|4.0|builtin"
  "Packages|Standard Tools|awk|POSIX|posix"
  "Packages|Standard Tools|grep|POSIX|posix"
  "Packages|Standard Tools|sed|POSIX|posix"
  "Packages|Standard Tools|find|POSIX|posix"
  "Packages|Standard Tools|sort|POSIX|posix"
  "Packages|Recipe Runners|just|1.0|just"
  "Packages|Lints|shellcheck|0.9|shellcheck"
  "Packages|Container Runtimes|docker|20.10|dpkg"
)

# One line per command the catalogue checks, with the package Ubuntu 24.04 LTS
# (noble) ships for it; DGX OS is noble-based and uses the same names. The hint
# installs this name. The version still comes from whatever package owns the
# binary, and from version_of_program() when nothing owns it.
declare -A PACKAGE_DEBIAN=(
  [bash]=bash
  [awk]=mawk               # noble installs awk as mawk; gawk is the GNU alternative
  [grep]=grep
  [sed]=sed
  [find]=findutils
  [sort]=coreutils
  [just]=just              # 1.21.0 in noble, universe
  [shellcheck]=shellcheck  # 0.9.0 in noble, universe
  [docker]=docker.io       # the engine; Debian's "docker" is a KDE tray
)


PACKAGE_SOURCES=' builtin posix just shellcheck dpkg '

# A minimum is "POSIX" or a Debian version: a digit, then the characters dpkg
# accepts (epoch colon, tilde for a pre-release, plus, dot, dash, letters).
DEBIAN_VERSION='^[0-9][A-Za-z0-9.+~:-]*$'

# -----------------------------------------------------------------------------
# 1.2 Services - units the project needs, and their state
#
#   SERVICE_SECTION  "Name|indent|gap"
#   SERVICE_GROUPS   "Name|description"
#   SERVICE_ROWS     "Group|unit|probe"    the unit keeps its suffix: sshd.service
#
#   A group with no rows is allowed and prints msg_no_service under its name,
#   so the section reads as a declaration.
#   probe: one of SERVICE_PROBES. A socket or a timer needs its companion
#   service to exist, or systemd refuses the unit.
#   States are mapped by map_systemd_state(); the healthy ones are listed in
#   SERVICE_HEALTHY (1.4). README.md has the guide and the use cases.
# -----------------------------------------------------------------------------
SERVICE_SECTION='Services|4|2'

SERVICE_GROUPS=(
  "Daemons|background processes"
  "Sockets|on-demand activation"
  "Timers|scheduled jobs"
  "Containers|container instances"
)

SERVICE_ROWS=(
  "Daemons|docker|docker-daemon"
)

SERVICE_PROBES=' systemd systemd-user docker docker-daemon '

# -----------------------------------------------------------------------------
# 1.3 Versions - where the number in the report comes from
#
#   A binary is read through the package that owns it; when no package owns it,
#   the case below decides, one line per program. Anything else is --.
# -----------------------------------------------------------------------------

# Seconds a probe may run before it is killed, so a stuck daemon cannot hang
# the report. Every --version and every daemon call goes through it.
probe_timeout=5

# The package that owns a binary; empty when dpkg knows no owner, which is the
# case of a program installed outside the package manager.
package_owner() { # NAME
  local binary
  binary=$(readlink -f -- "$(command -v "$1" 2>/dev/null)" 2>/dev/null) || return 0
  # No owner is a normal answer, not a failure: the caller must not see 1.
  dpkg-query --search "$binary" 2>/dev/null | head -1 | sed 's/[,:].*//' || true
}

# The version of a program: the package version when a package owns it, and the
# way the program reports itself when it does not. -- means "not readable".
version_of_program() { # NAME
  local package version

  package=$(package_owner "$1")
  if [[ -n $package ]]; then
    version=$(dpkg-query --show --showformat='${Version}' "$package" 2>/dev/null)
    if [[ -n $version ]]; then
      printf '%s' "$version"
      return 0
    fi
  fi

  case $1 in
    docker) timeout "$probe_timeout" docker --version 2>/dev/null |
      grep -oE '[0-9]+(\.[0-9]+)+' | head -1 || true ;;
    *) printf '%s' '--' ;;
  esac
}

# -----------------------------------------------------------------------------
# 1.4 Shared appearance - text and spacing used by both sections
# -----------------------------------------------------------------------------
step_gap=3      # spaces between a next-step command and its description
summary_shift=2 # columns the missing/install block moves right of the tree
cell_pad=1      # extra columns inside each cell
header_pad=6    # columns before the title block
min_width=56    # the rule is never narrower than this

branch='+--'    # marker for an item that has a sibling below
last='\--'      # marker for the final item
bar='|'         # vertical continuation

label_ok='ok'
label_missing='missing'
label_stale='too old'
label_next='next'
label_needs='needs'   # opens the gap block: what the module is short of
label_run='run'       # closes it: the command that clears the gap
label_start='start'
label_running='running'
label_listening='listening'
label_scheduled='scheduled'
label_watching='watching'
label_done='done'
label_stopped='stopped'
label_failed='failed'
label_absent='absent'
label_unknown='unknown'

# The gap block keeps one label column, so its text lines up under the widest
# label it uses. "too old" is seven columns wide; the others pad to it.
summary_label_width=7

# Service states that need no action. Everything else is reported and fails the
# run; adding a state is a change here, not a new branch in the renderer.
SERVICE_HEALTHY=' running listening scheduled watching done '

msg_ok='everything required is present'
msg_no_service='no unit declared'  # printed under a service group with no rows
install_cmd='sudo apt-get install -y'
start_cmd='sudo systemctl start'

title_name='doctor'
title_about='checks the host environment this project needs'

# Shown under the ok banner. Each entry is "command|what it does"; the
# descriptions line up on their own.
next_steps=(
  "just --list|list the recipes"
  "just test|run the tool suite"
  "just lint|lint the Bash sources"
)



# #############################################################################
# ## PART 2 - THE PART YOU DO NOT EDIT                                     ####
# #############################################################################

# Report state. The collect and measure functions fill it, the draw functions
# read it; nothing is exported and nothing survives the run. The names say which
# side of the report owns them.
#
# Record shapes, decoded with IFS='|' read at every consumer:
#   state_package_rows   module|group|name|version|need|status|colour
#   state_service_rows   group|name|state|probe|colour
#   state_module_*       one entry per module, parallel to state_module_names
#   state_steps          one formatted command line, descriptions aligned
#
# A new field means a new column at the end, never in the middle: the decoders
# read by position, so inserting one shifts every field after it.
declare -a state_module_names=() state_module_indents=() state_module_gaps=()
declare -a state_module_missing=() state_module_stale=()
declare -a state_module_install=()
declare -A state_group_indent=() state_group_gap=()

declare -a state_package_rows=()
declare -a state_package_missing=() state_package_stale=()

declare -a state_service_rows=()
declare -a state_service_stopped=() state_service_failed=()
declare -a state_service_absent=() state_service_unknown=() state_service_start=()
state_service_problem=0

declare -a state_steps=()

state_width_name=0 state_width_version=0 state_width_need=0
state_width_service_name=0 state_width_service_probe=0
state_table_width=0
state_title_name_pad=0 state_title_about_pad=0

bold='' dim='' red='' green='' yellow='' reset=''

# -----------------------------------------------------------------------------
# 2.1 Helpers
# -----------------------------------------------------------------------------
usage() {
  cat <<EOF
doctor.sh - report the host environment this project needs

Usage: doctor.sh [options]

  -h, --help      show this help

Exit: 0 when nothing needs attention, 1 when it does, 2 on a usage error.
The full guide is in README.md, section "Host checks".
EOF
}

fail() { printf 'doctor.sh: %s\n' "$1" >&2; exit 2; }

# Comparing versions is dpkg's job, so the run stops here without it rather
# than comparing numbers and guessing.
require_dpkg() {
  command -v dpkg > /dev/null 2>&1 ||
    fail "dpkg is required to compare versions; run this on a Debian-like host"
}

# Print N spaces. One place owns the "pad with spaces" idea.
spaces() { printf '%*s' "$1" ''; }

# The marker for a row: a branch when a sibling follows, a corner at the end.
marker() { # INDEX TOTAL
  if (($1 == $2 - 1)); then printf '%s' "$last"; else printf '%s' "$branch"; fi
}

# The lead of a group's children: a bar while the group has siblings below.
children_lead() { # INDENT INDEX TOTAL
  if (($2 == $3 - 1)); then printf '%s' "$1    "; else printf '%s%s   ' "$1" "$bar"; fi
}

# Count the rows that start with PREFIX; the validators use it to refuse a
# module with no groups and a group with no tools.
count_rows() { # PREFIX ROW...
  local prefix=$1 count=0 row
  shift
  for row in "$@"; do
    [[ $row == "$prefix"* ]] && count=$((count + 1))
  done
  printf '%s' "$count"
}

# Drop repeated lines, keeping the order of first appearance.
dedupe() { printf '%s\n' "$@" | awk '!seen[$0]++'; }

join_commas() { local out; out=$(printf '%s, ' "$@"); printf '%s' "${out%, }"; }
join_spaces() { local out; out=$(printf '%s ' "$@"); printf '%s' "${out% }"; }

# Colour is dropped on a pipe. NO_COLOR wins over everything; FORCE_COLOR only
# beats "stdout is a pipe".
setup_colour() {
  [[ -n ${NO_COLOR:-} ]] && return 0
  if [[ -n ${FORCE_COLOR:-} ]] || [[ -t 1 ]]; then
    bold=$'\e[1m' dim=$'\e[2m' red=$'\e[31m' green=$'\e[32m' yellow=$'\e[33m' reset=$'\e[0m'
  fi
}

# The colour escape for a colour name carried in the report rows.
colour_of() { # NAME
  case $1 in
    green) printf '%s' "$green" ;;
    red) printf '%s' "$red" ;;
    yellow) printf '%s' "$yellow" ;;
    *) printf '' ;;
  esac
}

# -----------------------------------------------------------------------------
# 2.2 Package version probing
# -----------------------------------------------------------------------------
# Version ordering is dpkg's job: it decides what apt can install, it knows
# epochs, tildes and revisions, and there is no second opinion worth keeping.
# require_dpkg() stops the run when dpkg is absent, before anything is compared.
version_ge() { # HAVE WANT
  [[ -n $1 && -n $2 ]] || return 1
  dpkg --compare-versions "$1" ge "$2" 2>/dev/null
}

any_version() { # COMMAND - first dotted number in --version
  run_probe "$1" --version 2>/dev/null |
    head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true
}

# Every probe runs under probe_timeout: a stuck daemon must not hang the report.
run_probe() { timeout "$probe_timeout" "$@"; }

# How a source answers "is it installed". The package database answers for
# dpkg, without running the program; every other source asks the PATH.
is_installed() { # SOURCE NAME
  local package
  case $1 in
    dpkg)
      package=$(package_owner "$2")
      if [[ -n $package ]]; then
        dpkg-query --show --showformat='${Status}' "$package" 2>/dev/null |
          grep -q '^install ok installed$'
      else
        # No package owns it; the binary in PATH is what says it is here.
        command -v "$2" > /dev/null 2>&1
      fi
      ;;
    *) command -v "$2" > /dev/null 2>&1 ;;
  esac
}

version_of() { # SOURCE NAME
  local source=$1 name=$2
  case $source in
    builtin) printf '%s.%s' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" ;;
    posix) any_version "$name" ;;
    just) run_probe just --version 2>/dev/null | head -1 | sed -E 's/^[^0-9]*//' || true ;;
    shellcheck) run_probe shellcheck --version 2>/dev/null |
      sed -n 's/^version: //p' | head -1 || true ;;
    dpkg) version_of_program "$name" ;;
    *) printf '' ;;
  esac
}

# -----------------------------------------------------------------------------
# 2.3 Service probes
# -----------------------------------------------------------------------------
# Ask systemd for the five fields, in one call, for either bus. One call covers
# every unit type: service, oneshot, socket, timer and path.
systemd_show() { # SCOPE UNIT - prints "load|active|sub|result|type"
  local scope=$1 unit=$2 key value
  local load='' active='' sub='' result='' type=''
  local -a command=(systemctl)

  [[ $scope == user ]] && command+=(--user)
  command+=(show -p LoadState -p ActiveState -p SubState -p Result -p Type -- "$unit")

  while IFS='=' read -r key value; do
    case $key in
      LoadState) load=$value ;;
      ActiveState) active=$value ;;
      SubState) sub=$value ;;
      Result) result=$value ;;
      Type) type=$value ;;
    esac
  done <<<"$(run_probe "${command[@]}" 2>/dev/null || true)"

  printf '%s|%s|%s|%s|%s' "$load" "$active" "$sub" "$result" "$type"
}

# Pure: the whole decision, with no command run. UNIT is needed only to tell a
# timer (scheduled) from a path unit (watching), which share the same SubState.
map_systemd_state() { # UNIT LOAD ACTIVE SUB RESULT TYPE
  local unit=$1 load=$2 active=$3 sub=$4 result=$5 type=$6

  if [[ $load != loaded ]]; then printf '%s' "$label_absent"; return; fi
  if [[ $result == failed || $active == failed ]]; then printf '%s' "$label_failed"; return; fi

  case "$active:$sub" in
    active:listening) printf '%s' "$label_listening" ;;
    active:waiting)
      case $unit in
        *.path) printf '%s' "$label_watching" ;;
        *) printf '%s' "$label_scheduled" ;;
      esac
      ;;
    active:exited) printf '%s' "$label_done" ;;
    active:*) printf '%s' "$label_running" ;;
    inactive:dead)
      # An oneshot that ran and finished well is done, not stopped.
      if [[ $type == oneshot && $result == success ]]; then
        printf '%s' "$label_done"
      else
        printf '%s' "$label_stopped"
      fi
      ;;
    inactive:*) printf '%s' "$label_stopped" ;;
    *) printf '%s' "$label_unknown" ;;
  esac
}

# One bus, one unit: the fields in, one state out.
probe_systemd_scope() { # SCOPE UNIT
  local load active sub result type
  command -v systemctl > /dev/null 2>&1 || { printf '%s' "$label_absent"; return; }
  IFS='|' read -r load active sub result type <<<"$(systemd_show "$1" "$2")"
  map_systemd_state "$2" "$load" "$active" "$sub" "$result" "$type"
}

probe_systemd() { # UNIT - the system bus
  probe_systemd_scope system "$1"
}

probe_systemd_user() { # UNIT - the user bus; without a session it is invisible
  probe_systemd_scope user "$1"
}

probe_docker() { # CONTAINER
  local running
  command -v docker > /dev/null 2>&1 || { printf '%s' "$label_absent"; return; }
  running=$(run_probe docker inspect --format '{{.State.Running}}' "$1" 2>/dev/null || true)
  case $running in
    true) printf '%s' "$label_running" ;;
    false) printf '%s' "$label_stopped" ;;
    *) printf '%s' "$label_absent" ;;
  esac
}

probe_docker_daemon() { # no argument: it asks the engine, not a container
  command -v docker > /dev/null 2>&1 || { printf '%s' "$label_absent"; return; }
  if run_probe docker info > /dev/null 2>&1; then
    printf '%s' "$label_running"
  else
    printf '%s' "$label_stopped"
  fi
}

probe_service() { # PROBE SERVICE
  case $1 in
    systemd) probe_systemd "$2" ;;
    systemd-user) probe_systemd_user "$2" ;;
    docker) probe_docker "$2" ;;
    docker-daemon) probe_docker_daemon ;;
    *) printf '%s' "$label_unknown" ;;
  esac
}

# -----------------------------------------------------------------------------
# 2.4 Section validation - a typo stops the script instead of hiding a row
# -----------------------------------------------------------------------------
validate_packages() {
  local module group desc name source row seen module_list

  seen=' '
  module_list=' '
  for row in "${PACKAGE_MODULES[@]}"; do
    IFS='|' read -r module group desc <<<"$row"
    [[ -n $module ]] || fail "PACKAGE_MODULES holds an empty name"
    [[ $seen == *" $module "* ]] && fail "PACKAGE_MODULES repeats the module: $module"
    seen+="$module "
    module_list+="$module "
    [[ -z $group || $group =~ ^[0-9]+$ ]] || fail "PACKAGE_MODULES has a bad indent: $row"
    [[ -z $desc || $desc =~ ^[0-9]+$ ]] || fail "PACKAGE_MODULES has a bad gap: $row"
  done

  seen=' '
  for row in "${PACKAGE_GROUPS[@]}"; do
    IFS='|' read -r module group desc <<<"$row"
    [[ -n $module && -n $group && -n $desc ]] ||
      fail "PACKAGE_GROUPS needs module|name|description: $row"
    [[ $seen == *" $module|$group "* ]] && fail "PACKAGE_GROUPS repeats the group: $group"
    seen+="$module|$group "
    [[ $module_list == *" $module "* ]] || fail "PACKAGE_GROUPS names an unknown module: $module"
  done

  for row in "${PACKAGE_TOOLS[@]}"; do
    IFS='|' read -r module group name minimum source <<<"$row"
    [[ -n $module && -n $group && -n $name && -n $minimum && -n $source ]] ||
      fail "PACKAGE_TOOLS needs module|group|name|minimum|source: $row"
    [[ $module_list == *" $module "* ]] || fail "PACKAGE_TOOLS names an unknown module: $module"
    [[ $seen == *" $module|$group "* ]] || fail "PACKAGE_TOOLS names an unknown group: $module|$group"
    [[ $PACKAGE_SOURCES == *" $source "* ]] || fail "PACKAGE_TOOLS names an unknown source: $source"
    [[ $minimum == POSIX || $minimum =~ $DEBIAN_VERSION ]] ||
      fail "PACKAGE_TOOLS has a bad minimum: $minimum"
  done

  # A module with no groups, or a group with no tools, would render a title alone.
  for row in "${PACKAGE_MODULES[@]}"; do
    IFS='|' read -r module _ <<<"$row"
    (($(count_rows "$module|" "${PACKAGE_GROUPS[@]}"))) ||
      fail "PACKAGE_MODULES declares a module with no groups: $module"
  done
  for row in "${PACKAGE_GROUPS[@]}"; do
    IFS='|' read -r module group _ <<<"$row"
    (($(count_rows "$module|$group|" "${PACKAGE_TOOLS[@]}"))) ||
      fail "PACKAGE_GROUPS declares a group with no tools: $group"
  done
}

validate_services() {
  local group name probe row seen title indent gap

  ((${#SERVICE_ROWS[@]})) || return 0

  IFS='|' read -r title indent gap <<<"$SERVICE_SECTION"
  [[ -n $title ]] || fail "SERVICE_SECTION needs a name when SERVICE_ROWS is set"
  [[ -z $indent || $indent =~ ^[0-9]+$ ]] || fail "SERVICE_SECTION has a bad indent: $SERVICE_SECTION"
  [[ -z $gap || $gap =~ ^[0-9]+$ ]] || fail "SERVICE_SECTION has a bad gap: $SERVICE_SECTION"

  seen=' '
  for row in "${SERVICE_GROUPS[@]}"; do
    IFS='|' read -r group _ <<<"$row"
    [[ -n $group ]] || fail "SERVICE_GROUPS holds an empty name"
    [[ $seen == *" $group "* ]] && fail "SERVICE_GROUPS repeats the group: $group"
    seen+="$group "
  done

  for row in "${SERVICE_ROWS[@]}"; do
    IFS='|' read -r group name probe <<<"$row"
    [[ -n $group && -n $name && -n $probe ]] ||
      fail "SERVICE_ROWS needs group|service|probe: $row"
    [[ $seen == *" $group "* ]] || fail "SERVICE_ROWS names an unknown group: $group"
    [[ $SERVICE_PROBES == *" $probe "* ]] || fail "SERVICE_ROWS names an unknown probe: $probe"
  done

}

# -----------------------------------------------------------------------------
# 2.5 Collection - turn the sections into the rows the report prints
# -----------------------------------------------------------------------------
collect_module_layout() {
  local row module indent gap i
  state_module_names=()
  state_module_indents=()
  state_module_gaps=()

  for row in "${PACKAGE_MODULES[@]}"; do
    IFS='|' read -r module indent gap <<<"$row"
    state_module_names+=("$module")
    state_module_indents+=("${indent:-4}")
    state_module_gaps+=("${gap:-2}")
  done

  # Each group inherits the spacing of the module that owns it.
  for row in "${PACKAGE_GROUPS[@]}"; do
    IFS='|' read -r module group _ <<<"$row"
    for ((i = 0; i < ${#state_module_names[@]}; i++)); do
      if [[ ${state_module_names[i]} == "$module" ]]; then
        state_group_indent["$module|$group"]=${state_module_indents[i]}
        state_group_gap["$module|$group"]=${state_module_gaps[i]}
        break
      fi
    done
  done
}

collect_packages() {
  local row module group name minimum source need have
  state_package_rows=()
  state_package_missing=()
  state_package_stale=()

  for row in "${PACKAGE_TOOLS[@]}"; do
    IFS='|' read -r module group name minimum source <<<"$row"

    if [[ $minimum == POSIX ]]; then need='POSIX'; else need=">= $minimum"; fi

    if ! is_installed "$source" "$name"; then
      state_package_rows+=("$module|$group|$name|--|$need|$label_missing|red")
      state_package_missing+=("$name")
      continue
    fi

    have=$(version_of "$source" "$name")
    [[ $have == '--' ]] && have=''
    have=${have:-}

    if [[ $minimum != POSIX && -n $have ]] && ! version_ge "$have" "$minimum"; then
      state_package_rows+=("$module|$group|$name|$have|$need|$label_stale|yellow")
      state_package_stale+=("$name $have")
      continue
    fi

    state_package_rows+=("$module|$group|$name|${have:---}|$need|$label_ok|green")
  done

  if ((${#state_package_missing[@]})); then
    mapfile -t state_package_missing < <(dedupe "${state_package_missing[@]}")
  fi
  if ((${#state_package_stale[@]})); then
    mapfile -t state_package_stale < <(dedupe "${state_package_stale[@]}")
  fi
}

# One summary per module: what it misses, and the command that closes the gap.
collect_module_summaries() {
  local i row owner name have status module
  state_module_missing=()
  state_module_stale=()
  state_module_install=()

  for ((i = 0; i < ${#state_module_names[@]}; i++)); do
    module=${state_module_names[i]}
    local -a missing=() stale=() needed=() packages=()
    local joined=''

    for row in "${state_package_rows[@]}"; do
      IFS='|' read -r owner _ name have _ status _ <<<"$row"
      [[ $owner == "$module" ]] || continue
      case $status in
        "$label_missing") missing+=("$name") ;;
        "$label_stale") stale+=("$name $have") ;;
      esac
    done
    if ((${#missing[@]})); then mapfile -t missing < <(dedupe "${missing[@]}"); fi
    if ((${#stale[@]})); then mapfile -t stale < <(dedupe "${stale[@]}"); fi

    if ((${#missing[@]})); then joined=$(join_commas "${missing[@]}"); fi
    state_module_missing+=("$joined")
    state_module_stale+=("$(printf '%s\n' "${stale[@]}")")

    local item
    for item in "${missing[@]}"; do needed+=("$item"); done
    for item in "${stale[@]}"; do needed+=("${item%% *}"); done
    joined=''
    if ((${#needed[@]})); then
      for item in "${needed[@]}"; do packages+=("${PACKAGE_DEBIAN[$item]:-$item}"); done
      mapfile -t packages < <(dedupe "${packages[@]}")
      joined=$(join_spaces "${packages[@]}")
    fi
    state_module_install+=("$joined")
  done
}

collect_services() {
  local row group name probe state colour
  state_service_rows=()
  state_service_stopped=()
  state_service_failed=()
  state_service_absent=()
  state_service_unknown=()
  state_service_start=()
  state_service_problem=0

  ((${#SERVICE_ROWS[@]})) || return 0

  for row in "${SERVICE_ROWS[@]}"; do
    IFS='|' read -r group name probe <<<"$row"
    state=$(probe_service "$probe" "$name")

    if [[ $SERVICE_HEALTHY == *" $state "* ]]; then
      colour=green
    else
      case $state in
        "$label_stopped") colour=yellow; state_service_stopped+=("$name") ;;
        "$label_failed") colour=red; state_service_failed+=("$name") ;;
        "$label_absent") colour=red; state_service_absent+=("$name") ;;
        *) colour=yellow; state=$label_unknown; state_service_unknown+=("$name") ;;
      esac
    fi

    if [[ $probe == systemd || $probe == docker-daemon ]] &&
      [[ $state == "$label_stopped" || $state == "$label_failed" ]]; then
      state_service_start+=("$name")
    fi

    state_service_rows+=("$group|$name|$state|$probe|$colour")
  done

  state_service_problem=$((
    ${#state_service_stopped[@]} + ${#state_service_failed[@]} +
      ${#state_service_absent[@]} + ${#state_service_unknown[@]}
  ))
}

# The commands printed under the ok banner, with their descriptions aligned.
build_steps() {
  local row command width=0
  state_steps=()
  for row in "${next_steps[@]}"; do
    command=${row%%|*}
    ((${#command} > width)) && width=${#command}
  done
  for row in "${next_steps[@]}"; do
    state_steps+=("$(printf '%-*s%*s%s' "$width" "${row%%|*}" "$step_gap" '' "${row#*|}")")
  done
}

# -----------------------------------------------------------------------------
# 2.6 Measurement - every column and the frame come from the data
# -----------------------------------------------------------------------------
widen() { if (($1 > state_table_width)); then state_table_width=$1; fi; }

measure_packages() {
  local row module group name have need status

  state_width_name=4
  state_width_version=5
  state_width_need=5
  for row in "${state_package_rows[@]}"; do
    IFS='|' read -r _ _ name have need _ _ <<<"$row"
    ((${#name} > state_width_name)) && state_width_name=${#name}
    ((${#have} > state_width_version)) && state_width_version=${#have}
    ((${#need} > state_width_need)) && state_width_need=${#need}
  done
  state_width_name=$((state_width_name + cell_pad))
  state_width_version=$((state_width_version + cell_pad))
  state_width_need=$((state_width_need + cell_pad))

  # The title is a name centred over its description, both on one axis.
  local block=${#title_name}
  ((${#title_about} > block)) && block=${#title_about}
  state_title_name_pad=$((header_pad + (block - ${#title_name}) / 2))
  state_title_about_pad=$((header_pad + (block - ${#title_about}) / 2))

  widen $((header_pad + ${#title_name}))
  widen $((header_pad + ${#title_about}))
  for row in "${PACKAGE_MODULES[@]}"; do
    IFS='|' read -r module _ _ <<<"$row"
    widen ${#module}
  done
  for row in "${PACKAGE_GROUPS[@]}"; do
    IFS='|' read -r module group desc <<<"$row"
    widen $((state_group_indent["$module|$group"] + 3 + 1 + ${#group} +
      state_group_gap["$module|$group"] + ${#desc}))
  done
  for row in "${state_package_rows[@]}"; do
    IFS='|' read -r module group _ _ _ status _ <<<"$row"
    widen $((state_group_indent["$module|$group"] + 4 + 3 + 1 +
      state_width_name + 1 + state_width_version + 1 + state_width_need + 1 + ${#status}))
  done

  local i item
  for ((i = 0; i < ${#state_module_names[@]}; i++)); do
    [[ -n ${state_module_missing[i]} ]] &&
      widen $((state_module_indents[i] + summary_shift + summary_label_width +
        state_module_gaps[i] + ${#state_module_missing[i]}))
    while IFS= read -r item; do
      [[ -z $item ]] ||
        widen $((state_module_indents[i] + summary_shift + summary_label_width +
          state_module_gaps[i] + ${#item}))
    done <<<"${state_module_stale[i]}"
    [[ -n ${state_module_install[i]} ]] &&
      widen $((state_module_indents[i] + summary_shift + summary_label_width +
        state_module_gaps[i] + ${#install_cmd} + 1 + ${#state_module_install[i]}))
  done
  for row in "${state_steps[@]}"; do
    widen $((state_module_indents[0] + ${#label_next} + state_module_gaps[0] + ${#row}))
  done
}

measure_services() {
  local row group name state probe
  state_width_service_name=6
  state_width_service_probe=5

  for row in "${state_service_rows[@]}"; do
    IFS='|' read -r _ name _ probe _ <<<"$row"
    ((${#name} > state_width_service_name)) && state_width_service_name=${#name}
    ((${#probe} > state_width_service_probe)) && state_width_service_probe=${#probe}
  done
  state_width_service_name=$((state_width_service_name + cell_pad))
  state_width_service_probe=$((state_width_service_probe + cell_pad))

  ((${#state_service_rows[@]})) || return 0

  local title indent gap
  IFS='|' read -r title indent gap <<<"$SERVICE_SECTION"
  widen ${#title}
  for row in "${SERVICE_GROUPS[@]}"; do
    IFS='|' read -r group desc <<<"$row"
    widen $((${indent:-4} + 3 + 1 + ${#group} + ${gap:-2} + ${#desc}))
  done
  for row in "${state_service_rows[@]}"; do
    IFS='|' read -r _ _ state _ _ <<<"$row"
    widen $((${indent:-4} + 4 + 3 + 1 + state_width_service_name + 1 +
      state_width_service_probe + 1 + ${#state}))
  done
  for row in "${SERVICE_GROUPS[@]}"; do
    IFS='|' read -r group _ <<<"$row"
    (($(count_rows "$group|" "${state_service_rows[@]}"))) && continue
    widen $((${indent:-4} + 4 + 3 + 1 + ${#msg_no_service}))
  done
}

measure_report() {
  state_table_width=$min_width
  measure_packages
  measure_services
}

# -----------------------------------------------------------------------------
# 2.7 Rendering
# -----------------------------------------------------------------------------
rule() {
  local line
  printf -v line '%*s' "$state_table_width" ''
  printf '%s\n' "${dim}${line// /-}${reset}"
}

# A labelled line, arguments in the order they reach the screen.
say() { # INDENT GAP COLOUR LABEL TEXT
  printf '%s%s%s%s%s%s\n' "$1" "$3" "$4" "$reset" "$2" "$5"
}

# A line of the gap block: the label pads to the block's column, so every text
# starts at the same place whatever the label length.
summary_line() { # INDENT GAP COLOUR LABEL TEXT
  local shown
  printf -v shown '%-*s' "$summary_label_width" "$4"
  say "$1" "$2" "$3" "$shown" "$5"
}

# One group heading: indent, marker, name, gap, description.
draw_group() { # INDENT GAP INDEX TOTAL NAME DESCRIPTION
  printf '%s%s%s%s %s%s%s%s\n' "$1" "${dim}" "$(marker "$3" "$4")" "${reset}" \
    "$5" "$2" "${dim}" "$6${reset}"
}

# The children of a group, each body already formatted by the caller.
draw_children() { # INDENT INDEX TOTAL BODY...
  local indent=$1 index=$2 total=$3
  shift 3
  local -a bodies=("$@")
  local lead i
  lead=$(children_lead "$indent" "$index" "$total")
  for ((i = 0; i < ${#bodies[@]}; i++)); do
    printf '%s%s%s%s %s\n' "${dim}" "$lead" "$(marker "$i" "${#bodies[@]}")" "${reset}" \
      "${bodies[i]}"
  done
}

draw_frame() {
  rule
  printf '%*s%s%s%s\n' "$state_title_name_pad" '' "${bold}" "$title_name" "${reset}"
  printf '%*s%s%s%s\n' "$state_title_about_pad" '' "${dim}" "$title_about" "${reset}"
  rule
  printf '\n'
}

draw_packages() {
  local i gi item
  local -a module_groups=()
  local module indent gap group desc name have need status colour

  for ((i = 0; i < ${#state_module_names[@]}; i++)); do
    module=${state_module_names[i]}
    local tree_indent=${state_module_indents[i]}
    local group_gap=${state_module_gaps[i]}
    indent=$(spaces "$tree_indent")
    gap=$(spaces "$group_gap")

    ((i == 0)) || printf '\n'
    printf '%s%s%s\n' "${bold}" "$module" "${reset}"

    module_groups=()
    for item in "${PACKAGE_GROUPS[@]}"; do
      [[ $item == "$module|"* ]] && module_groups+=("$item")
    done

    for ((gi = 0; gi < ${#module_groups[@]}; gi++)); do
      IFS='|' read -r _ group desc <<<"${module_groups[gi]}"
      draw_group "$indent" "$gap" "$gi" "${#module_groups[@]}" "$group" "$desc"

      local -a bodies=()
      for item in "${state_package_rows[@]}"; do
        [[ $item == "$module|$group|"* ]] || continue
        IFS='|' read -r _ _ name have need status colour <<<"$item"
        bodies+=("$(printf '%-*s %-*s %-*s %s%s%s' \
          "$state_width_name" "$name" "$state_width_version" "$have" \
          "$state_width_need" "$need" "$(colour_of "$colour")${bold}" "$status" "${reset}")")
      done
      draw_children "$indent" "$gi" "${#module_groups[@]}" "${bodies[@]}"
    done

    # A module reports only its own gaps, right under its own tree.
    if [[ -n ${state_module_missing[i]} || -n ${state_module_stale[i]} ]]; then
      local summary_indent
      summary_indent=$(spaces $((tree_indent + summary_shift)))
      printf '\n'
      [[ -n ${state_module_missing[i]} ]] &&
        summary_line "$summary_indent" "$gap" "${bold}" "$label_needs" \
          "${state_module_missing[i]}"
      while IFS= read -r item; do
        [[ -z $item ]] ||
          summary_line "$summary_indent" "$gap" "${yellow}${bold}" "$label_stale" "$item"
      done <<<"${state_module_stale[i]}"
      [[ -n ${state_module_install[i]} ]] &&
        summary_line "$summary_indent" "$gap" "${bold}" "$label_run" \
          "$install_cmd ${state_module_install[i]}"
    fi
  done
}

draw_services() {
  ((${#state_service_rows[@]})) || return 0

  local title indent gap
  IFS='|' read -r title indent gap <<<"$SERVICE_SECTION"
  indent=$(spaces "${indent:-4}")
  gap=$(spaces "${gap:-2}")

  local sg
  local group desc name state probe colour item

  printf '\n'
  printf '%s%s%s\n' "${bold}" "$title" "${reset}"

  for ((sg = 0; sg < ${#SERVICE_GROUPS[@]}; sg++)); do
    IFS='|' read -r group desc <<<"${SERVICE_GROUPS[sg]}"
    draw_group "$indent" "$gap" "$sg" "${#SERVICE_GROUPS[@]}" "$group" "$desc"

    local -a bodies=()
    for item in "${state_service_rows[@]}"; do
      [[ $item == "$group|"* ]] || continue
      IFS='|' read -r _ name state probe colour <<<"$item"
      bodies+=("$(printf '%-*s %-*s %s%s%s' \
        "$state_width_service_name" "$name" "$state_width_service_probe" "$probe" \
        "$(colour_of "$colour")${bold}" "$state" "${reset}")")
    done
    # An empty group still says so, under its name, so the section reads as a
    # declaration and not as an omission.
    if ((${#bodies[@]} == 0)); then
      bodies+=("${dim}${msg_no_service}${reset}")
    fi
    draw_children "$indent" "$sg" "${#SERVICE_GROUPS[@]}" "${bodies[@]}"
  done

  ((state_service_problem)) || return 0

  printf '\n'
  # The order is the order of severity: absent, then failed, stopped, unknown.
  ((${#state_service_absent[@]})) &&
    say "$indent" "$gap" "${red}${bold}" "$label_absent" "$(join_commas "${state_service_absent[@]}")"
  ((${#state_service_failed[@]})) &&
    say "$indent" "$gap" "${red}${bold}" "$label_failed" "$(join_commas "${state_service_failed[@]}")"
  ((${#state_service_stopped[@]})) &&
    say "$indent" "$gap" "${yellow}${bold}" "$label_stopped" "$(join_commas "${state_service_stopped[@]}")"
  ((${#state_service_unknown[@]})) &&
    say "$indent" "$gap" "${yellow}${bold}" "$label_unknown" "$(join_commas "${state_service_unknown[@]}")"

  if ((${#state_service_start[@]})); then
    printf '\n'
    say "$indent" "$gap" "${bold}" "$label_start" "$start_cmd $(join_spaces "${state_service_start[@]}")"
  fi
}

draw_summary() {
  local indent gap step_pad i

  if ((${#state_package_missing[@]} + ${#state_package_stale[@]} +
    state_service_problem == 0)); then
    indent=$(spaces "${state_module_indents[0]}")
    gap=$(spaces "${state_module_gaps[0]}")
    step_pad=$(spaces $((${#label_next} + state_module_gaps[0])))

    printf '\n'
    say "$indent" "$gap" "${green}${bold}" "$label_ok" "$msg_ok"
    printf '\n'
    say "$indent" "$gap" "${bold}" "$label_next" "${state_steps[0]}"
    for ((i = 1; i < ${#state_steps[@]}; i++)); do
      printf '%s%s%s\n' "$indent" "$step_pad" "${state_steps[i]}"
    done
    rule
    return 0
  fi

  rule
  return 1
}

# -----------------------------------------------------------------------------
# 2.8 Main
# -----------------------------------------------------------------------------
main() {
  local IFS=$' \t\n'

  setup_colour

  while (($#)); do
    case $1 in
      -h | --help) usage; exit 0 ;;
      *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
  done

  require_dpkg
  validate_packages
  validate_services

  collect_module_layout
  collect_packages
  collect_module_summaries
  collect_services
  build_steps

  measure_report

  draw_frame
  draw_packages
  draw_services
  draw_summary
}

# Run the report only when executed; a test may source this file to reach the
# pure helpers (spaces, marker, children_lead, version_ge, map_systemd_state).
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
