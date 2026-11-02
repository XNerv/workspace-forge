#!/usr/bin/env bash
# tests/test-content.sh - README content, counts and required files.

set -Eeuo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname -- "$0")/lib.sh"
sandbox_init

workspace=$(generate_workspace)

directories=(. docs docs/adr scripts data data/raw data/interim \
  data/processed data/external experiments projects infrastructure)
expected_sections=("## 📋 Purpose" "## 📁 Structure" "## ✅ Rules" \
  "## 🚫 Out of scope" "## 🔗 See also")

directories_on_disk=$(find "$workspace" -type d | wc -l)
assert_eq 12 "$((directories_on_disk))" "the workspace directory count"
readmes_on_disk=$(find "$workspace" -type f -name README.md | wc -l)
assert_eq 12 "$((readmes_on_disk))" "the workspace README count"

check_readme() {
  local readme=$1 base=$2
  local expected_title="# 📁 $base/"
  assert_file "$readme" "README for $base"
  if [[ ! -s $readme ]]; then
    fail "the README is empty: $readme"
  fi
  assert_eq "$expected_title" "$(head -n 1 "$readme")" "README title for $base"

  local -a actual=()
  while IFS= read -r line; do
    actual+=("$line")
  done < <(grep -E '^## ' "$readme")
  if [[ ${#actual[@]} -ne 5 ]]; then
    fail "$base README has ${#actual[@]} level-two sections, expected 5"
  fi
  local index
  for index in 0 1 2 3 4; do
    assert_eq "${expected_sections[$index]}" "${actual[$index]}" "$base section order"
  done
  if grep -q '## 💡 How to use' "$readme"; then
    fail "$base README contains the removed How to use section"
  fi

  local blockquote_line hr_line
  blockquote_line=$(grep -n '^> ' "$readme" | head -n 1 | cut -d: -f1)
  hr_line=$(grep -n '^---$' "$readme" | head -n 1 | cut -d: -f1)
  if [[ -z $blockquote_line ]]; then
    fail "$base README has no blockquote tagline"
  fi
  if [[ -z $hr_line ]]; then
    fail "$base README has no horizontal rule"
  fi
  if ((hr_line < blockquote_line)); then
    fail "$base README puts the horizontal rule before the tagline"
  fi

  local bullets=0 bullet
  while IFS= read -r bullet; do
    bullets=$((bullets + 1))
    if [[ $bullet != *' — '* ]]; then
      fail "$base README rule bullet lacks an em dash: $bullet"
    fi
  done < <(awk '/^## ✅ Rules$/ { inside = 1; next } /^## / { inside = 0 } inside && /^- / { print }' "$readme")
  if ((bullets == 0)); then
    fail "$base README has no rule bullets"
  fi

  local link target
  while IFS= read -r link; do
    case $link in
      http* | mailto:* | '#'*) continue ;;
    esac
    target=${link%%#*}
    if [[ -z $target ]]; then
      continue
    fi
    if [[ ! -e $(dirname -- "$readme")/$target ]]; then
      fail "$base README has a broken relative link: $link"
    fi
  done < <(grep -oE '\]\([^)]+\)' "$readme" | sed -E 's/^\]\((.*)\)$/\1/')

  if grep -Eq '([0-9]+) (directories|directory|READMEs|files|scripts)' "$readme"; then
    fail "$base README states a directory or file count"
  fi
  if grep -Eqi '(\.git/|\.git directory|git commits?|commit was made)' "$readme"; then
    fail "$base README claims that the workspace ships a .git directory or a commit"
  fi
  if grep -Eqi 'forge (uses|runs|creates|initializes)[^.]*git' "$readme"; then
    fail "$base README claims that forge uses Git"
  fi
}

for directory in "${directories[@]}"; do
  if [[ $directory == . ]]; then
    readme=$workspace/README.md
    base=workspace
  else
    readme=$workspace/$directory/README.md
    base=${directory##*/}
  fi
  check_readme "$readme" "$base"
done

for file in justfile .gitignore .editorconfig .env.example \
  docs/adr/0001-workspace-structure.md scripts/backup.sh scripts/setup.sh \
  scripts/clean.sh scripts/doctor.sh; do
  assert_file "$workspace/$file" "required generated file $file"
done

# The seven nested .gitignore files carry exactly three lines.
nested=(experiments projects infrastructure data/raw data/interim \
  data/processed data/external)
expected_ignore=$'/*\n!/README.md\n!.gitignore'
for directory in "${nested[@]}"; do
  path=$workspace/$directory/.gitignore
  assert_file "$path" "nested .gitignore in $directory"
  assert_eq "$expected_ignore" "$(cat -- "$path")" "content of $directory/.gitignore"
  lines=$(wc -l < "$path")
  assert_eq 3 "$((lines))" "line count of $directory/.gitignore"
done
assert_absent "$workspace/data/.gitignore" "data/.gitignore must not exist"

if grep -qF 'data/raw/*' "$workspace/.gitignore"; then
  fail "the root .gitignore repeats the data/raw rules"
fi
if grep -qF 'experiments/*/outputs/*' "$workspace/.gitignore"; then
  fail "the root .gitignore repeats the experiments rules"
fi

# experiments/, projects/ and infrastructure/ hold exactly two entries.
for directory in experiments projects infrastructure; do
  entries=$(find "$workspace/$directory" -mindepth 1 -maxdepth 1 -printf '%f\n' | LC_ALL=C sort)
  assert_eq $'.gitignore\nREADME.md' "$entries" "$directory holds only README.md and .gitignore"
done

assert_no_symlink "$workspace" "the generated workspace"

printf 'all content checks passed\n'
