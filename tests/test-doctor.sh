#!/usr/bin/env bash
# tests/test-doctor.sh - behaviour and output quality of doctor.sh.
#
# Each case runs doctor.sh with a controlled PATH, prints what the script
# produced, and saves that output under tests/output/<case>.txt. Assertions
# follow the printed block, so a failure is readable next to the output that
# caused it.
#
# Covered:
#   1. exit code and summary for each state
#   2. version comparison, including a version below the minimum
#   3. layout: alignment, and the rule following the table width
#   4. output quality: pure ASCII, no colour in a pipe, no wide or trailing space
#   5. contract: read-only, deterministic, groups in section order
set -Eeuo pipefail

root=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
outdir=$root/tests/output/test-doctor
work=$(mktemp -d)
trap 'find "$work" -delete 2>/dev/null || true' EXIT
mkdir -p "$outdir"

# The docker row is decided by the package database, and a test machine cannot
# promise docker.io. This copy swaps the row for the bash package, which every
# Debian-like host has, so the report is the same everywhere.
doctor=$work/doctor.sh
awk '
  /^  "Packages\|Container Runtimes\|docker\|20\.10\|dpkg"$/ {
    print "  \"Packages|Container Runtimes|bash|4.0|dpkg\""
    next
  }
  { print }
' "$root/doctor.sh" > "$doctor"
chmod +x "$doctor"

# The path is built at run time, so shellcheck cannot follow it.
# shellcheck disable=SC1091
source "$root/tests/lib.sh"

# The two shortcuts this file uses inside if/else blocks.
ok() { check "$1" true; }
bad() { check "$1" false; }
contains() { [[ $out == *"$1"* ]]; }

# The report runs with this PATH plus the fixture's own directory. A stub engine
# answers the Services row, so the exit code depends on packages alone; a case
# that wants a silent daemon puts its own docker in the fixture directory.
base=$(base_bin "$work/base")
# shellcheck disable=SC2016 # $1 belongs to the stub, not to this script
printf '#!/bin/sh\ncase "$1" in info) exit 0 ;; inspect) echo true ;; esac\n' \
  > "$work/base/docker"
chmod +x "$work/base/docker"

fake_bin() { tool_bin "$@"; }

# Run doctor.sh, print its output, save it, and expose $status.
case_run() { # NAME BIN_DIR [ENV...]
  local name=$1 bin=$2
  shift 2
  set +e
  out=$(cd "$work" && env PATH="$bin:$base" "$@" "$doctor" 2>&1)
  status=$?
  set -e
  printf '%s\n' "$out" > "$outdir/$name.txt"
  printf '\n  --- %s (exit %d, saved to tests/output/%s.txt) ---\n' "$name" "$status" "$name"
  printf '%s\n' "$out" | sed 's/^/  | /'
  printf '\n'
}

case_run_script() { # NAME SCRIPT_PATH BIN_DIR
  local name=$1 script=$2 bin=$3
  set +e
  out=$(cd "$work" && env PATH="$bin:$base" bash "$script" 2>&1)
  status=$?
  set -e
  printf '%s\n' "$out" > "$outdir/$name.txt"
  printf '\n  --- %s (exit %d, saved to tests/output/%s.txt) ---\n' "$name" "$status" "$name"
  printf '%s\n' "$out" | sed 's/^/  | /'
  printf '\n'
}

# The package tree only: the services section has its own markers.
packages_block() { printf '%s\n' "$out" | sed -n '/^Packages$/,/^Services$/p'; }
group_count() { packages_block | grep -cE '^    [+\\]-- '; }
leaf_count() { packages_block | grep -cE '^(    \|   |        )[+\\]-- '; }
is_ascii() { ! printf '%s' "$out" | LC_ALL=C grep -q '[^ -~]'; }
no_ansi() { ! printf '%s' "$out" | grep -q $'\033'; }
no_wide() { (( $(printf '%s\n' "$out" | awk 'length > 100' | wc -l) == 0 )); }
no_trailing() { ! printf '%s\n' "$out" | grep -qE ' +$'; }

# Every tool line must start its status at the same column.
status_columns() {
  awk '
    /^(    \|   |        )[+\\]-- / {
      line = $0
      sub(/ok$/, "", line)
      sub(/missing$/, "", line)
      sub(/too old$/, "", line)
      print length(line)
    }
  ' <<<"$(packages_block)" | LC_ALL=C sort -u | wc -l
}

# The rules must be one width, and at least as wide as the widest line.
rule_widths() { grep -E '^-+$' <<<"$out" | awk '{ print length }' | LC_ALL=C sort -u; }
widest_line() { grep -vE '^-+$' <<<"$out" | awk '{ print length }' | LC_ALL=C sort -rn | head -1; }


# Given: a host where tools are present, missing, old or answerless
# When:  doctor.sh runs with that host on PATH
# Then:  the exit code and the rows say what needs attention
# --- 1. states ---------------------------------------------------------------
complete=$work/bin_complete
fake_bin "$complete" 1.40.0 0.10.0
case_run complete "$complete"
check 'exit 0 when everything is present' test "$status" -eq 0
check 'summary says ok' contains 'ok  everything required is present'
check 'next block is printed' contains 'next  just --list'

partial=$work/bin_partial
fake_bin "$partial" '' 0.10.0
case_run just-missing "$partial"
check 'exit 1 when just is missing' test "$status" -eq 1
check 'summary names the missing tool' contains 'needs    just'
check 'install command names only the missing tool' contains 'sudo apt-get install -y just'
check 'a missing tool shows -- in the found column' grep -qE 'just +-- +>=' <<<"$out"

none=$work/bin_none
fake_bin "$none" '' ''
case_run both-missing "$none"
check 'both missing are listed in order' contains 'needs    just, shellcheck'

# Given: a tool that reports a specific version
# When:  the minimum is compared
# Then:  ok, too old or -- follow the comparison
# --- 2. versions -------------------------------------------------------------
old=$work/bin_old
fake_bin "$old" 0.9.0 0.10.0
case_run just-old "$old"
check 'exit 1 when just is too old' test "$status" -eq 1
check 'the report says too old with the version found' contains 'too old  just 0.9.0'
check 'a too old tool is not reported as missing' test "${out#*needs    }" = "${out}"

old2=$work/bin_old2
fake_bin "$old2" 1.40.0 0.8.0
case_run shellcheck-old "$old2"
check 'shellcheck below 0.9 is too old' contains 'too old  shellcheck 0.8.0'

edge=$work/bin_edge
fake_bin "$edge" 1.0 0.9
case_run exact-minimum "$edge"
check 'exact minimum passes' test "$status" -eq 0

# Given: a program installed with its daemon down
# When:  the report runs
# Then:  the package row stays ok and Services carries the state
# --- 3. the package check stops at presence ---------------------------------
# A program whose daemon is down is installed: the package row says ok, and the
# daemon state belongs to the services section.
nodaemon=$work/bin_nodaemon
mkdir -p "$nodaemon"
printf '#!/bin/sh\nexit 1\n' > "$nodaemon/docker"
cp "$complete/just" "$complete/shellcheck" "$nodaemon/" 2>/dev/null || true
chmod +x "$nodaemon"/* 2>/dev/null || true
case_run daemon-down "$nodaemon"
check 'exit 1 when the service is down' test "$status" -eq 1
check 'the daemon state is reported by the services section' contains 'docker  docker-daemon  stopped'
check 'the services summary names the stopped daemon' contains 'stopped  docker'

# Given: the complete host
# When:  the tree is drawn
# Then:  every column, marker and rule lines up
# --- 4. layout ---------------------------------------------------------------
case_run complete-layout "$complete"
check 'all tool lines align their status column' test "$(status_columns)" -eq 1
check 'five groups are drawn' test "$(group_count)" -eq 5
check 'nine tools are drawn' test "$(leaf_count)" -eq 9
check 'the tree is introduced by a Packages label' grep -qE '^ *Packages$' <<<"$out"
label_line=$(printf '%s\n' "$out" | grep -nE '^ *Packages$' | cut -d: -f1)
first_group=$(printf '%s\n' "$out" | grep -n '^    [+\\]-- ' | head -1 | cut -d: -f1)
check 'the label comes before the first group' test "$label_line" -lt "$first_group"
check 'all rules share one width' test "$(rule_widths | wc -l)" -eq 1
check 'the rule spans the widest line' test "$(rule_widths)" -ge "$(widest_line)"

wide=$work/doctor_wide.sh
awk '{ print } /^  "Packages\|Standard Tools\|awk/ { print "  \"Packages|Standard Tools|a-very-long-tool-name-here|2.0|posix\"" }' "$doctor" > "$wide"
chmod +x "$wide"
if grep -q 'a-very-long-tool-name-here' "$wide"; then
  case_run_script long-name "$wide" "$complete"
  check 'a 24-character tool name keeps the alignment' test "$(status_columns)" -eq 1
  check 'the long name appears in full' contains 'a-very-long-tool-name-here'
  check 'the rule grows with the table' test "$(rule_widths)" -ge "$(widest_line)"
else
  bad 'could not inject a long tool name'
fi

# just keeps the whole string; the posix probe trims it to the dotted number.
longver=$work/bin_longver
mkdir -p "$longver"
cp "$complete/shellcheck" "$longver/" 2>/dev/null || true
printf '#!/bin/sh\necho "29.8.2-rc1+build.12345.abcdef"\n' > "$longver/just"
chmod +x "$longver"/*
case_run long-version "$longver"
check 'a 27-character version keeps the alignment' test "$(status_columns)" -eq 1
check 'the long version appears in full' contains '29.8.2-rc1+build.12345.abcdef'
check 'the rule still spans the widest line' test "$(rule_widths)" -ge "$(widest_line)"

# Given: a tool listed twice and a tool added to the catalogue
# When:  the report runs
# Then:  the tree repeats it and the summary names it once
# --- 5. sections: duplicates and new tools --------------------------------
dup=$work/doctor_dup.sh
awk '{ print } /^  "Packages\|Lints\|shellcheck/ { print "  \"Packages|Lints|just|1.0|just\"" }' "$doctor" > "$dup"
chmod +x "$dup"
case_run_script duplicate-tool "$dup" "$none"
check 'a tool in two groups is drawn twice' test "$(printf '%s\n' "$out" | grep -c -- '-- just')" -eq 2
check 'a tool in two groups is reported once' test "$(grep -m1 '^ *needs' <<<"$out" | grep -o just | wc -l)" -eq 1

newtool=$work/doctor_new.sh
awk '{ print } /^  "Packages\|Lints\|shellcheck/ { print "  \"Packages|Lints|jq|1.6|posix\"" }' "$doctor" > "$newtool"
chmod +x "$newtool"
case_run_script new-tool "$newtool" "$none"
check 'a new tool is checked and reported' contains 'jq'
check 'a new tool joins the install line' grep -qE 'run +sudo apt-get install -y .*jq' <<<"$out"

# Given: a terminal that receives the report as text
# When:  the bytes are checked
# Then:  the output is ASCII, uncoloured on a pipe, narrow and trimmed
# --- 6. output quality -------------------------------------------------------
case_run complete-quality "$complete"
check 'output is pure ASCII' is_ascii
check 'no ANSI escapes in a pipe' no_ansi
check 'no line is wider than 100 columns' no_wide
check 'no trailing whitespace' no_trailing

set +e
forced=$(cd "$work" && env PATH="$complete:/usr/bin:/bin" FORCE_COLOR=1 "$doctor" 2>&1)
set -e
printf '%s\n' "$forced" > "$outdir/forced-color.txt"
if printf '%s' "$forced" | grep -q $'\033'; then
  ok 'FORCE_COLOR emits ANSI escapes'
else
  bad 'FORCE_COLOR emits ANSI escapes'
fi

# Given: the command line
# When:  the flags are passed
# Then:  help exits 0 and an unknown option exits 2
# --- 7. options --------------------------------------------------
set +e
help_out=$(cd "$work" && "$doctor" -h 2>&1)
help_status=$?
set -e
printf '%s\n' "$help_out" > "$outdir/help.txt"
printf '\n  --- help (exit %d) ---\n' "$help_status"
printf '%s\n' "$help_out" | sed 's/^/  | /'
printf '\n'
check '-h exits 0' test "$help_status" -eq 0
check '-h documents the flag' grep -q -- '--help' <<<"$help_out"

set +e
bad_out=$(cd "$work" && "$doctor" --nope 2>&1)
bad_status=$?
set -e
printf '%s\n' "$bad_out" > "$outdir/unknown-option.txt"
check 'an unknown option exits 2' test "$bad_status" -eq 2
check 'an unknown option is named in the message' grep -q 'unknown option: --nope' <<<"$bad_out"

case_run complete-version "$complete"
check 'the header names the script without an extension' grep -qE '^ +doctor$' <<<"$out"
check 'the header carries a description under the name' grep -qE '^ {6}checks the host environment this project needs$' <<<"$out"

name_line=$(printf '%s\n' "$out" | sed -n '2p')
about_line=$(printf '%s\n' "$out" | sed -n '3p')
about_col=$(printf '%s\n' "$about_line" | awk '{ match($0, /[^ ]/); print RSTART }')
name_col=$(printf '%s\n' "$name_line" | awk '{ match($0, /[^ ]/); print RSTART }')

# Doubled centres, so the comparison stays in whole numbers.
centre2() { printf '%s\n' "$1" | awk '{ match($0, /[^ ]/); s = RSTART - 1; t = $0; sub(/^ +/, "", t); print 2 * s + length(t) }'; }
distance() { local a=$1 b=$2; if ((a > b)); then printf '%s' $((a - b)); else printf '%s' $((b - a)); fi; }

check 'the description starts at the seventh column' test "$about_col" -eq 7
check 'the name sits to the right of the padding' test "$name_col" -gt 7
check 'the name is centred over the description' test "$(distance "$(centre2 "$name_line")" "$(centre2 "$about_line")")" -le 1

longhead=$work/doctor_longhead.sh
sed 's/^title_about=.*/title_about="a much longer description than the default one that must move the name to the right"/' \
  "$doctor" > "$longhead"
chmod +x "$longhead"
case_run_script long-description "$longhead" "$complete"
long_name=$(printf '%s\n' "$out" | sed -n '2p')
long_about=$(printf '%s\n' "$out" | sed -n '3p')
long_col=$(printf '%s\n' "$long_name" | awk '{ match($0, /[^ ]/); print RSTART }')
check 'a longer description moves the name right' test "$long_col" -gt "$name_col"
check 'the name stays centred' test "$(distance "$(centre2 "$long_name")" "$(centre2 "$long_about")")" -le 1
check 'the rule grows with the longer description' test "$(rule_widths)" -ge "$(widest_line)"

longname=$work/doctor_longname.sh
sed 's/^title_name=.*/title_name="doctor-with-a-name-longer-than-the-description-text"/' \
  "$doctor" > "$longname"
chmod +x "$longname"
case_run_script long-name-header "$longname" "$complete"
ln_name=$(printf '%s\n' "$out" | sed -n '2p')
ln_about=$(printf '%s\n' "$out" | sed -n '3p')
check 'a longer name stays centred over the description' \
  test "$(distance "$(centre2 "$ln_name")" "$(centre2 "$ln_about")")" -le 1
check 'the description moves right when the name is longer' \
  test "$(printf '%s\n' "$ln_about" | awk '{ match($0, /[^ ]/); print RSTART }')" -gt 7
check 'the rule spans the title' test "$(rule_widths)" -ge "$(printf '%s\n' "$out" | head -2 | tail -1 | awk '{print length}')"

# Given: a run of the report
# When:  the filesystem and a second run are observed
# Then:  nothing is written and the output repeats byte for byte
# --- 8. contract -------------------------------------------------------------
before=$(find "$work" -maxdepth 1 -mindepth 1 | wc -l)
case_run complete-readonly "$complete"
after=$(find "$work" -maxdepth 1 -mindepth 1 | wc -l)
check 'doctor.sh writes nothing' test "$before" -eq "$after"

first=$out
case_run complete-again "$complete"
check 'two runs produce identical output' test "$first" = "$out"

case_run complete-order "$complete"
shell_order=$(printf '%s\n' "$out" | grep -n 'Terminals ' | head -1 | cut -d: -f1)
audit_order=$(printf '%s\n' "$out" | grep -n 'Standard Tools ' | head -1 | cut -d: -f1)
recipes_order=$(printf '%s\n' "$out" | grep -n 'Recipe Runners ' | head -1 | cut -d: -f1)
container_order=$(printf '%s\n' "$out" | grep -n 'Container Runtimes ' | head -1 | cut -d: -f1)
if ((shell_order < audit_order && audit_order < recipes_order && recipes_order < container_order)); then
  ok 'groups render in section order'
else
  bad 'groups render in section order'
fi


printf 'outputs saved in %s (%d files)\n' "${outdir#"$root"/}" \
  "$(find "$outdir" -type f | wc -l)"
summary
