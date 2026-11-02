# ADR 0003: Modular development and standalone distribution

- Status: Accepted

## Context

Development needs small files with one responsibility each, a Bash test suite and a ShellCheck run per
file. Distribution needs one directory or archive that runs on a machine without the repository, the
tests or the specification.

A symbolic-link install points at the checkout, so moving the checkout breaks the command. A copy of
the tree has no mark of its version unless the build records one.

## Decision

Develop and test the modular tree: `forge`, `lib/` with six libraries, and `templates/`. Distribute a
standalone bundle that `scripts/build-standalone.sh` builds from that tree.

## Consequences

- `forge` resolves its own directory from its real path, so one file serves the checkout and the
  extracted bundle.
- The build writes `dist/workspace-forge-<version>/` with `forge`, `lib/`, `templates/`, a generated
  `README.md` and `LICENSE`.
- The build also writes `dist/workspace-forge-<version>.tar.gz` and
  `dist/workspace-forge-<version>.tar.gz.sha256`.
- The bundle `README.md` is written by the build and links to nothing outside the extracted directory.
- The repository README links to `docs/`, `tests/` and files that the bundle excludes, so the build
  does not copy it.
- The directory name, the archive name and `--version` all use `FORGE_VERSION` from `forge`.
- `tests/test-standalone.sh` builds the bundle and runs `--version`, `--help` and a real generation
  from the extracted tree.
- GNU `tar` and `gzip` write metadata that prevents bit-identical archives. A build is reproducible
  in content for the same files and settings.
- The cost: two layouts need verification, and a change to `forge` reaches a user only after a new
  build.
