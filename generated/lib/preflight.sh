#!/usr/bin/env bash
#
# lib/preflight.sh - the read-only validation phase.
#
# preflight never creates a directory or a file. It either returns 0 or exits
# with the code that names the failure.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  printf 'lib/preflight.sh is a library: source it from forge, do not run it\n' >&2
  exit 1
fi

# preflight validates the requirement order of Section 6.3: platform, tools,
# HOME, destination resolution, parent, existence, the protection table, the
# tool repository and the template tree.
preflight() {
  local tool parent lexical template_root category link count

  if ((BASH_VERSINFO[0] < 4)); then
    die 4 "Bash 4 or newer is required, found ${BASH_VERSION}"
  fi
  case ${OSTYPE:-} in
    msys* | cygwin* | win32*)
      die 4 "unsupported platform ${OSTYPE}: use Linux or WSL2"
      ;;
  esac

  for tool in find mkdir cp mv mktemp chmod stat sed awk grep sort dirname \
    basename readlink; do
    if ! command -v "$tool" > /dev/null 2>&1; then
      die 4 "required tool not found: $tool"
    fi
  done
  if ! command -v sha256sum > /dev/null 2>&1 && ! command -v shasum > /dev/null 2>&1; then
    die 4 "required tool not found: sha256sum or shasum"
  fi

  if [[ -z ${HOME:-} ]]; then
    die 4 "HOME is not set"
  fi
  if [[ $HOME != /* ]]; then
    die 4 "HOME must be an absolute path: $HOME"
  fi

  case $FORGE_TARGET in
    *$'\n'* | *$'\r'* | *$'\t'*)
      die 2 "control character in the destination path"
      ;;
  esac

  # A symbolic link at the destination itself is refused, even when it points
  # to a path that does not exist yet. Check the expanded form before
  # canonicalization resolves the link away.
  lexical=$FORGE_TARGET
  if [[ $lexical != /* ]]; then
    lexical=$PWD/$lexical
  fi
  if [[ -L $lexical ]]; then
    die 3 "the destination is a symbolic link: $lexical"
  fi

  # The canonical path decides every comparison. The plain call keeps
  # FORGE_ABSPATH_CANONICAL in this shell; a command substitution would lose it.
  if ! _abspath "$FORGE_TARGET" > /dev/null; then
    die 3 "cannot resolve the destination path: $FORGE_TARGET"
  fi
  if [[ $FORGE_ABSPATH_CANONICAL -ne 1 ]]; then
    die 5 "cannot verify the destination safely: $FORGE_TARGET"
  fi
  FORGE_TARGET=$FORGE_ABSPATH_RESULT

  parent=$(dirname -- "$FORGE_TARGET")
  if [[ ! -d $parent ]]; then
    die 3 "the destination parent does not exist: $parent"
  fi
  if [[ ! -w $parent || ! -x $parent ]]; then
    die 3 "the destination parent is not writable: $parent"
  fi

  if [[ -e $FORGE_TARGET ]]; then
    die 3 "the destination already exists and must not: $FORGE_TARGET"
  fi

  if path_is_forbidden "$FORGE_TARGET"; then
    die 3 "refusing forbidden destination: $FORGE_TARGET"
  fi

  if path_is_within "$FORGE_TARGET" "$FORGE_HOME" || path_is_within "$FORGE_HOME" "$FORGE_TARGET"; then
    die 3 "the destination overlaps the tool repository: $FORGE_TARGET"
  fi

  template_root=$FORGE_HOME/templates
  if [[ ! -d $template_root || ! -r $template_root ]]; then
    die 5 "template tree is missing or unreadable: $template_root"
  fi
  for category in root docs scripts data experiments projects infrastructure; do
    if [[ ! -d $template_root/$category ]]; then
      die 5 "missing template category: $category"
    fi
  done
  link=$(find "$template_root" -type l -print -quit)
  if [[ -n $link ]]; then
    die 3 "the template tree contains a symbolic link: $link"
  fi

  count=$(find "$template_root" -type f -print | wc -l)
  count=${count//[[:space:]]/}
  if [[ -f $template_root/README.md ]]; then
    count=$((count - 1))
  fi
  FORGE_TOTAL_FILES=$count
  export FORGE_TOTAL_FILES
}
