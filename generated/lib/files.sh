#!/usr/bin/env bash
#
# lib/files.sh - create directories and install files in the destination.
#
# Both creators enforce the create-only contract: every managed path is absent
# before creation, and an existing path is an internal invariant failure.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  printf 'lib/files.sh is a library: source it from forge, do not run it\n' >&2
  exit 1
fi

# make_dir PATH creates one directory of the destination tree.
make_dir() {
  local path=${1-} parent

  if [[ $path != "$FORGE_TARGET" && $path != "$FORGE_TARGET"/* ]]; then
    die 3 "refusing a directory outside the destination: $path"
  fi
  if [[ -L $path ]]; then
    die 3 "refusing a symbolic link at the destination: $path"
  fi
  if [[ -e $path ]]; then
    die 1 "internal error: directory exists before creation: $path"
  fi

  if [[ $FORGE_DRY_RUN -eq 1 ]]; then
    printf 'mkdir  %s\n' "$path"
    FORGE_CREATED_DIRS=$((FORGE_CREATED_DIRS + 1))
    return 0
  fi

  parent=$(dirname -- "$path")
  if [[ ! -d $parent ]]; then
    die 5 "the parent directory does not exist: $parent"
  fi
  if [[ $path != "$FORGE_TARGET" && -L $parent ]]; then
    die 3 "the parent is a symbolic link: $parent"
  fi
  if [[ ! -w $parent ]]; then
    die 5 "the parent directory is not writable: $parent"
  fi

  if ! mkdir -- "$path"; then
    die 5 "cannot create directory: $path"
  fi
  if [[ ! -d $path || -L $path ]]; then
    die 5 "the created path is not a regular directory: $path"
  fi
  FORGE_CREATED_DIRS=$((FORGE_CREATED_DIRS + 1))
}

# install_file SOURCE DEST RELATIVE installs one template file.
#
# The copy goes to a temporary file in the destination directory and moves into
# place, so a failed copy never leaves a truncated destination file. A local
# process could still replace the destination between the check and the move;
# Section 9.4 of the specification documents that limitation.
install_file() {
  local source=$1 dest=$2 relative=${3:-} parent mode tmp

  if [[ ! -f $source || -L $source ]]; then
    die 5 "not a regular template file: $source"
  fi
  if [[ ! -r $source ]]; then
    die 5 "the template is not readable: $source"
  fi
  if [[ -z $relative ]]; then
    die 1 "internal error: install_file needs a relative path"
  fi

  if ! _abspath "$source" > /dev/null; then
    die 5 "cannot resolve the template path: $source"
  fi
  if ! path_is_within "$FORGE_ABSPATH_RESULT" "$FORGE_HOME/templates"; then
    die 3 "the template is outside the template tree: $source"
  fi
  if ! path_is_within "$dest" "$FORGE_TARGET"; then
    die 3 "refusing a file outside the destination: $dest"
  fi

  if [[ $FORGE_DRY_RUN -eq 1 ]]; then
    printf 'copy   %s -> %s\n' "$source" "$dest"
    FORGE_CREATED_FILES=$((FORGE_CREATED_FILES + 1))
    return 0
  fi

  parent=$(dirname -- "$dest")
  if [[ ! -d $parent ]]; then
    die 5 "the destination parent does not exist: $parent"
  fi
  if [[ -L $parent ]]; then
    die 3 "the destination parent is a symbolic link: $parent"
  fi
  if [[ -e $dest || -L $dest ]]; then
    die 1 "internal error: file exists before creation: $dest"
  fi

  case $dest in
    "$FORGE_TARGET"/scripts/*.sh) mode=755 ;;
    *) mode=644 ;;
  esac

  tmp=$(mktemp -- "$parent/.forge-XXXXXX") || die 5 "cannot create a temporary file in: $parent"
  if ! cp -- "$source" "$tmp"; then
    rm -f -- "$tmp"
    die 5 "cannot copy $source to $dest"
  fi
  if ! chmod "$mode" -- "$tmp"; then
    rm -f -- "$tmp"
    die 5 "cannot set mode $mode on: $dest"
  fi
  if ! mv -- "$tmp" "$dest"; then
    rm -f -- "$tmp"
    die 5 "cannot move the temporary file into place: $dest"
  fi
  if [[ ! -f $dest || -L $dest ]]; then
    die 5 "the installed path is not a regular file: $dest"
  fi
  FORGE_CREATED_FILES=$((FORGE_CREATED_FILES + 1))
}

# make_executables applies u+rx to the four generated scripts. It widens no
# other permission and changes nothing outside the destination.
make_executables() {
  local script path
  for script in backup setup clean doctor; do
    path=$FORGE_TARGET/scripts/$script.sh
    if [[ $FORGE_DRY_RUN -eq 1 ]]; then
      printf 'chmod  %s (u+rx)\n' "$path"
      continue
    fi
    if [[ ! -f $path || -L $path ]]; then
      die 5 "the expected script is missing: $path"
    fi
    if ! chmod u+rx -- "$path"; then
      die 5 "cannot make the script executable: $path"
    fi
    if [[ ! -x $path ]]; then
      die 5 "the script is not executable after chmod: $path"
    fi
  done
}
