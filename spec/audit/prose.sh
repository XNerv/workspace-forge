#!/usr/bin/env bash
# prose.sh - deterministic wording audit for the specification.
#
# Independent: no other script is required, and no shared library is sourced.
#
# Errors are rules that need no context to decide: banned phrases, literal
# intensifiers, and prose sentences over the word limit. Warnings are signals
# that need a reader: permission "may", sentence-initial pronouns, open
# quantifiers, comparisons without a baseline, and long bullets.
#
# Exit: 0 clean, 1 violations, 2 usage error.

set -Eeuo pipefail

help() {
  cat <<'EOF'
prose.sh - deterministic wording audit for the specification

Usage: prose.sh [options] FILE...

Errors:
  - a banned phrase: etc., and so on, as needed, if useful, where relevant
  - a literal intensifier: should, very, really, quite, extremely, robust,
    seamless, elegant, intuitive
  - a prose sentence longer than 25 words

Warnings (reported, never fatal):
  - may as permission or possibility
  - a sentence that starts with a pronoun
  - an open quantifier: some, several, many, most, various
  - a comparison without a baseline: better, faster, safer, smaller, cheaper
  - a bullet longer than 25 words

Options:
  -h, --help      show this help
  -t, --tsv       machine-readable output: KIND<TAB>FILE<TAB>LINE<TAB>RULE<TAB>MESSAGE
  -w, --warnings  list the warnings under each file
  -q, --quiet     print only the final totals

Exit codes:
  0  clean
  1  violations found
  2  usage error

Example:
  prose.sh README.md spec/README.md spec/workspace-forge.prompt.md
EOF
}

MAX_WORDS=25
ERR_LITERAL='etc.|and so on|as needed|if useful|where relevant|when appropriate|as appropriate'
ERR_WORDS='should|very|really|quite|extremely|robust|seamless|elegant|intuitive'

tsv=0 quiet=0 warnings=0 files=()
while (($#)); do
  case $1 in
    -h | --help) help; exit 0 ;;
    -t | --tsv) tsv=1 ;;
    -w | --warnings) warnings=1 ;;
    -q | --quiet) quiet=1 ;;
    --) shift; files+=("$@"); break ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) files+=("$1") ;;
  esac
  shift
done
((${#files[@]})) || { printf 'no file given\n' >&2; exit 2; }

work=$(mktemp -d)
trap 'find "$work" -delete 2>/dev/null || true' EXIT

audit_file() {
  local f=$1

  awk -v max="$MAX_WORDS" -v file="$f" '
    function flush(   n, i, s, w, parts, words) {
      if (unit == "") return
      gsub(/\*\*/, "", unit)
      n = split(unit, parts, /[.!?][ \t]+/)
      for (i = 1; i <= n; i++) {
        s = parts[i]
        gsub(/[ \t]+/, " ", s)
        sub(/^ /, "", s)
        sub(/^\*\*[^*]+\*\*[.:]?[ \t]+/, "", s)
        if (s == "") continue
        w = split(s, words, " ")
        if (w > max) {
          k = (kind == "prose") ? "ERROR" : "WARNING"
          printf "%s\t%s\t%d\tLENGTH\tsentence of %d words: %s\n", k, file, start, w, substr(s, 1, 100)
        }
      }
      unit = ""
    }
    /^```/ { flush(); infence = !infence; next }
    infence { next }
    /^[ \t]*$/ { flush(); next }
    /^#/ { flush(); next }
    /^\|/ { flush(); next }
    /^\- No metaphor/ { flush(); next }
    /^\- No vague qualifier/ { flush(); next }
    /^\- No unfalsifiable claim/ { flush(); next }
    /^\*\*Contents:\*\*/ { flush(); next }
    /^[-*] / || /^[0-9]+\. / {
      flush(); kind = "bullet"; start = NR; unit = $0
      sub(/^([-*]|[0-9]+\.) +/, "", unit)
      next
    }
    /^[ \t]+/ { if (unit != "") unit = unit " " $0; next }
    { flush(); kind = "prose"; start = NR; unit = $0 }
    END { flush() }
  ' "$f"

  awk -v lit="$ERR_LITERAL" -v wrd="$ERR_WORDS" -v file="$f" '
    BEGIN { nlit = split(lit, lp, "|"); nwrd = split(wrd, wp, "|") }
    /^```/ { infence = !infence; next }
    infence { next }
    /^#/ { next }
    /^\|/ { next }
    /^\- No metaphor/ { next }
    /^\- No vague qualifier/ { next }
    /^\- No unfalsifiable claim/ { next }
    {
      m = tolower($0)
      gsub(/`[^`]*`/, "", m)
      gsub(/"[^"]*"/, "", m)
      for (i = 1; i <= nlit; i++)
        if (index(m, lp[i]) > 0) printf "ERROR\t%s\t%d\tPHRASE\tbanned phrase: %s\n", file, NR, lp[i]
      for (i = 1; i <= nwrd; i++)
        if (m ~ ("(^|[^a-z])" wp[i] "([^a-z]|$)")) printf "ERROR\t%s\t%d\tWORD\tbanned word: %s\n", file, NR, wp[i]
    }
  ' "$f"

  awk -v file="$f" '
    /^```/ { infence = !infence; next }
    infence { next }
    /^#/ { next }
    /^\|/ { next }
    {
      m = tolower($0)
      gsub(/`[^`]*`/, "", m)
      if (m ~ /(^|[^a-z])may([^a-z]|$)/) printf "WARNING\t%s\t%d\tMAY\tmay as permission or possibility\n", file, NR
      if (m ~ /(^|[.!?][ \t]+)(it|this|that|they|these|those)([^a-z]|$)/) printf "WARNING\t%s\t%d\tPRONOUN\tsentence starts with a pronoun\n", file, NR
      if (m ~ /(^|[^a-z])(some|several|many|most|various)([^a-z]|$)/) printf "WARNING\t%s\t%d\tQUANTIFIER\topen quantifier\n", file, NR
      if (m ~ /(^|[^a-z])(better|faster|safer|smaller|cheaper)([^a-z]|$)/) printf "WARNING\t%s\t%d\tCOMPARATIVE\tcomparison without a baseline\n", file, NR
    }
  ' "$f"
}

total_err=0
total_warn=0
for f in "${files[@]}"; do
  [[ -f $f ]] || { printf 'not a file: %s\n' "$f" >&2; exit 2; }
  out=$work/report.tsv
  audit_file "$f" >"$out"
  errs=$(grep -c '^ERROR' "$out" || true)
  warns=$(grep -c '^WARNING' "$out" || true)
  total_err=$((total_err + errs))
  total_warn=$((total_warn + warns))

  if ((tsv)); then
    cat -- "$out"
    continue
  fi
  ((quiet)) || printf '== %s: %d error(s), %d warning(s)\n' "$f" "$errs" "$warns"
  if ((errs > 0 && quiet == 0)); then
    while IFS=$'\t' read -r _ _ line rule text; do
      printf '  ERROR   L%-5s %-10s %s\n' "$line" "$rule" "$text"
    done < <(grep '^ERROR' "$out")
  fi
  if ((warnings == 1 && warns > 0 && quiet == 0)); then
    while IFS=$'\t' read -r _ _ line rule text; do
      printf '  warning L%-5s %-10s %s\n' "$line" "$rule" "$text"
    done < <(grep '^WARNING' "$out")
  fi
done

((quiet)) || printf '\ntotal: %d error(s), %d warning(s)\n' "$total_err" "$total_warn"
((total_err == 0))
