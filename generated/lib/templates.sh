#!/usr/bin/env bash
#
# lib/templates.sh - install the template tree and print the summary.
#
# The managed set comes from the files under templates/, not from a static
# manifest: templates/root/<relative> maps to the destination root and
# templates/<category>/<relative> maps to <category>/<relative>.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  printf 'lib/templates.sh is a library: source it from forge, do not run it\n' >&2
  exit 1
fi

cat_root_files() {
  printf '%s\n' README.md justfile .gitignore .editorconfig .env.example
}

# _require_templates fails before any copy when a required template is absent.
_require_templates() {
  local template_root=$FORGE_HOME/templates file script
  while IFS= read -r file; do
    if [[ ! -f $template_root/root/$file ]]; then
      die 5 "missing root template: $template_root/root/$file"
    fi
  done < <(cat_root_files)
  for script in backup setup clean doctor; do
    if [[ ! -f $template_root/scripts/$script.sh ]]; then
      die 5 "missing script template: $template_root/scripts/$script.sh"
    fi
  done
  if [[ ! -f $template_root/scripts/README.md ]]; then
    die 5 "missing script documentation: $template_root/scripts/README.md"
  fi
  if [[ ! -f $template_root/docs/adr/0001-workspace-structure.md ]]; then
    die 5 "missing ADR template"
  fi
}

# copy_templates installs every template file exactly once. A NUL-terminated
# marker after find proves that find read the whole category.
copy_templates() {
  local template_root=$FORGE_HOME/templates category source relative marker

  _require_templates
  while IFS= read -r category; do
    marker=0
    while IFS= read -r -d '' source; do
      if [[ $source == 'forge-find-done' ]]; then
        marker=1
        continue
      fi
      if [[ $category == root ]]; then
        relative=${source#"$template_root/root/"}
      else
        relative=${source#"$template_root/"}
      fi
      if [[ -z $relative || $relative == "$source" ]]; then
        die 5 "cannot map the template path: $source"
      fi
      install_file "$source" "$FORGE_TARGET/$relative" "$relative"
    done < <(find -- "$template_root/$category" -type f -print0 && printf 'forge-find-done\0')
    if [[ $marker -ne 1 ]]; then
      die 5 "find failed while reading: $template_root/$category"
    fi
  done < <(_template_categories)

  if [[ $FORGE_DRY_RUN -eq 1 ]]; then
    return 0
  fi
  if [[ $FORGE_CREATED_FILES -ne $FORGE_TOTAL_FILES ]]; then
    die 5 "installed $FORGE_CREATED_FILES files, expected $FORGE_TOTAL_FILES"
  fi
  _verify_tree
}

_template_categories() {
  printf '%s\n' root docs scripts data experiments projects infrastructure
}

# _verify_tree checks the generated tree after a real run.
_verify_tree() {
  local relative link directory
  for directory in . docs docs/adr scripts data data/raw data/interim \
    data/processed data/external experiments projects infrastructure; do
    if [[ $directory == . ]]; then
      relative=$FORGE_TARGET/README.md
    else
      relative=$FORGE_TARGET/$directory/README.md
    fi
    if [[ ! -f $relative ]]; then
      die 5 "the generated README is missing: $relative"
    fi
  done
  for directory in data/raw data/interim data/processed data/external \
    experiments projects infrastructure; do
    relative=$FORGE_TARGET/$directory/.gitignore
    if [[ ! -s $relative ]]; then
      die 5 "the nested .gitignore is missing or empty: $relative"
    fi
  done
  for relative in justfile .gitignore .editorconfig .env.example \
    docs/adr/0001-workspace-structure.md scripts/backup.sh scripts/setup.sh \
    scripts/clean.sh scripts/doctor.sh; do
    if [[ ! -f $FORGE_TARGET/$relative ]]; then
      die 5 "the generated file is missing: $FORGE_TARGET/$relative"
    fi
  done
  link=$(find "$FORGE_TARGET" -type l -print -quit)
  if [[ -n $link ]]; then
    die 5 "the generated tree contains a symbolic link: $link"
  fi
}

print_summary() {
  printf '\nworkspace: %s\n' "$FORGE_TARGET"
  if [[ $FORGE_DRY_RUN -eq 1 ]]; then
    printf 'mode: dry run; the counters below are simulated plans\n'
    printf 'directories planned: %d (workspace total: %d)\n' \
      "$FORGE_CREATED_DIRS" "$FORGE_TOTAL_DIRS"
    printf 'files planned: %d (template total: %d)\n' \
      "$FORGE_CREATED_FILES" "$FORGE_TOTAL_FILES"
  else
    printf 'mode: real run\n'
    printf 'directories created in this run: %d (workspace total: %d)\n' \
      "$FORGE_CREATED_DIRS" "$FORGE_TOTAL_DIRS"
    printf 'files created in this run: %d (template total: %d)\n' \
      "$FORGE_CREATED_FILES" "$FORGE_TOTAL_FILES"
  fi
  printf '\nlimitations:\n'
  printf '  - a local process can change the destination between verification and write\n'
  printf '  - the generator runs no Git command; the workspace has no .git and no commit\n'
  printf '  - Linux and WSL2 only; native Windows and macOS are refused\n'
  printf '\nnext step: adapt scripts/setup.sh first, then scripts/doctor.sh,\n'
  printf 'scripts/backup.sh and scripts/clean.sh to this workspace.\n'
}
