# Architecture

`forge` is a Bash executable, six libraries and a tree of template files. The document states what
each part does, the order of a run, the invariants a run keeps and the reasons behind the template
layout.

## The executable

`forge` is the only executable at the tool root, and it holds the only definition of the version.

The file resolves its real path through symbolic links with `readlink`, `dirname` and `cd -P`, then
exports `FORGE_HOME`. The file sets `FORGE_VERSION` and exports it. The file loads the six libraries
in a fixed order and defines `main`.

`forge` applies `set -Eeuo pipefail`, and the libraries never change shell options. A source guard
runs `main "$@"` only when `forge` is executed, so a test can source the file without starting a
generation.

Path resolution lets the same file run from the checkout and from an extracted bundle.
[ADR 0001](adr/0001-why-forge.md) records why the tool is a Bash program with no template engine.

## The six libraries

| Library | Duty |
|---|---|
| `lib/common.sh` | Colors, the message functions, `die`, `_abspath`, `path_is_within` and `path_is_forbidden`. |
| `lib/args.sh` | The CLI defaults, `usage`, `parse_args` and argument validation. |
| `lib/preflight.sh` | The host checks, destination resolution, protected-path checks and template-tree validation. |
| `lib/files.sh` | `make_dir`, `install_file` and `make_executables`. |
| `lib/tree.sh` | `create_tree`, which creates the twelve directories parent before child. |
| `lib/templates.sh` | `copy_templates` and `print_summary`. |

A library defines functions and constants, and it runs no step when sourced. A library executed
directly prints a message and exits non-zero. Global names use the `FORGE_` prefix.

[ADR 0003](adr/0003-standalone-vs-modular.md) records why the libraries stay separate in development
while the build ships one bundle.

## The templates

`templates/` holds every installed file under seven categories: `root/`, `docs/`, `scripts/`, `data/`,
`experiments/`, `projects/` and `infrastructure/`. A template is plain data, and `forge` copies the
bytes without substitution.

`templates/README.md` documents the template tree and is not installed. Preflight refuses a symbolic
link anywhere under `templates/`.

## Execution flow

`main` runs six steps in this order: `parse_args`, `preflight`, `create_tree`, `copy_templates`,
`make_executables` and `print_summary`.

1. `parse_args` reads the four options and sets the defaults. `--help` and `--version` exit 0 here
   before any check, and help wins when both flags appear. A usage error exits 2.
2. `preflight` checks Bash 4, the platform, the required commands and `HOME`. The step resolves the
   destination and checks the protected paths and the template tree. A refusal exits 3, a missing
   requirement exits 4, and a failed filesystem check exits 5, all before any write.
3. `create_tree` creates the twelve directories, parent before child, through `make_dir`.
4. `copy_templates` installs every template file at the destination path the mapping gives it.
5. `make_executables` sets `u+rx` on the four destination scripts and changes no other file.
6. `print_summary` prints the absolute path, the counters, the simulation state, the limitations and
   the script to adapt first.

`--dry-run` sets `FORGE_DRY_RUN=1` during `parse_args`. Steps 3 to 5 then record planned actions,
and step 6 prints the simulated counters; nothing changes on disk.

A filesystem failure exits 5, and a broken internal invariant exits 1. An ERR trap prints what the
run already created before the process exits.

## Safety invariants

- Preflight creates no directory and no file.
- The destination is absent at the start, and every managed path is absent when the tool creates it.
- `make_dir` and `install_file` treat an existing path as an invariant failure or a safety refusal.
- `install_file` copies to a temporary file in the destination directory and moves it with `mv`.
- A failed copy removes the temporary file and leaves the destination intact.
- No step follows a symbolic link inside the generated tree.
- A template source must be canonical under `FORGE_HOME/templates`, and a destination must be
  canonical under `FORGE_TARGET`.
- The tool never deletes or replaces a user file.
- A dry run creates no directory, file or temporary file, inside or outside the destination.

`forge` applies the protected-path table that [usage.md](usage.md#protected-paths) states.

## The template-to-workspace mapping

| Template path | Generated path |
|---|---|
| `templates/root/<relative>` | `<relative>` at the workspace root |
| `templates/docs/<relative>` | `docs/<relative>` |
| `templates/scripts/<relative>` | `scripts/<relative>` |
| `templates/data/<relative>` | `data/<relative>` |
| `templates/experiments/<relative>` | `experiments/<relative>` |
| `templates/projects/<relative>` | `projects/<relative>` |
| `templates/infrastructure/<relative>` | `infrastructure/<relative>` |
| `templates/README.md` | Not installed |

The mapping preserves the relative hierarchy and accepts file names with spaces. A template source
must be a regular file under the template root after canonicalization, and `install_file` rejects a
source outside it.

The twelve directories come from `create_tree`, not from empty directories in the template tree. A
template file lands inside an existing directory and never creates one.

[templates/README.md](../templates/README.md) states how to add a template and how to verify its links
and paths.

## Why templates are separate from code

The installed content includes files whose bytes matter, such as `.gitignore`, `.editorconfig`,
`.env.example`, the `justfile` and the scripts. A heredoc inside a library would add a quoting layer
for `$`, backticks and quotes, and ShellCheck would read the text as shell code. A template file is
reviewed, diffed and copied as plain data. [ADR 0002](adr/0002-external-templates.md) records that
decision and its costs.

## Why the generator runs no Git command

Preflight requires no `git` binary, and a run creates no `.git` directory and no commit. The output
depends only on the templates and the arguments, so a run inside a repository and a run outside one
produce the same files.

The user decides when to initialize a repository and which directories become repositories.
[usage.md](usage.md#what-to-do-after-generating) states those steps.
