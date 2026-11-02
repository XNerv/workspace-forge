#!/usr/bin/env bash
#
# lib/tree.sh - create the twelve workspace directories.
#
# The root counts as the first directory, so FORGE_TOTAL_DIRS=12 includes it.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  printf 'lib/tree.sh is a library: source it from forge, do not run it\n' >&2
  exit 1
fi

# _tree_directories prints the twelve relative paths in creation order.
_tree_directories() {
  printf '%s\n' . docs docs/adr scripts data data/raw data/interim \
    data/processed data/external experiments projects infrastructure
}

create_tree() {
  local relative path
  while IFS= read -r relative; do
    if [[ $relative == . ]]; then
      path=$FORGE_TARGET
    else
      path=$FORGE_TARGET/$relative
    fi
    make_dir "$path"
  done < <(_tree_directories)

  if [[ $FORGE_CREATED_DIRS -ne $FORGE_TOTAL_DIRS ]]; then
    die 1 "created $FORGE_CREATED_DIRS directories, expected $FORGE_TOTAL_DIRS"
  fi
  if [[ $FORGE_DRY_RUN -eq 1 ]]; then
    return 0
  fi

  while IFS= read -r relative; do
    if [[ $relative == . ]]; then
      path=$FORGE_TARGET
    else
      path=$FORGE_TARGET/$relative
    fi
    if [[ ! -d $path || -L $path ]]; then
      die 5 "the generated directory is missing or is a link: $path"
    fi
  done < <(_tree_directories)
}
