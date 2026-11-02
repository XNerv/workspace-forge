# workspace-forge

`workspace-forge` is a create-only Bash generator for a standardized local workspace.

`forge` creates twelve directories with one README each, the root configuration files, four script
skeletons and a `justfile` that forwards calls to those scripts. The tool creates the tree in a
destination that must not exist, and it refuses every other destination.

## What the tool is

The tool is a Bash executable named `forge`, six libraries under `lib/`, and a tree of plain files
under `templates/`.

A run reads the options and checks the host and the destination. The run creates the directories,
copies every template byte for byte, and sets execution bits on four scripts.

A run never merges, updates, repairs or overwrites an existing tree. No option changes that behavior.

## The tool repository and the generated workspace

The tool repository contains the executable, the six libraries, the templates, the tests, the
documentation and the standalone build. The generated workspace is the output of one `forge` run.

The generated workspace contains twelve directories with one README each, the root `.gitignore`,
`.editorconfig` and `.env.example`, a `justfile`, four skeleton scripts and one ADR. The workspace
contains no copy of `forge`, no library and no template.

A template documents workspace content, and it never documents the tool. `templates/README.md`
documents the template tree and is not installed.

## Requirements and compatibility

`forge` needs Bash 4 or newer on Linux or WSL2. The supported baseline is Ubuntu 24.04 LTS or newer.

| Requirement | Detail |
|---|---|
| Shell | Bash 4 or newer |
| Platform | Linux, or WSL2 on Windows |
| Baseline | Ubuntu 24.04 LTS or newer |
| Commands | `find`, `mkdir`, `cp`, `mv`, `mktemp`, `chmod`, `stat`, `sed`, `awk`, `grep`, `sort`, `dirname`, `basename`, `readlink`, and `sha256sum` or `shasum` |
| Development tooling | `just` for the recipes; `shellcheck` for `just lint` |

Preflight refuses native Windows, Git Bash and Cygwin with exit code 4, and it recommends WSL2.
macOS is not supported. A test on a Windows host is not evidence of compatibility.

## Run from a checkout

Run these commands in the directory that contains `forge`:

```bash
./forge --dry-run -p ~/lab
./forge -p ~/lab
```

The first command prints every directory and file it would create, and it writes nothing. The second
command creates `~/lab`. The destination must be absent in both cases.

## Install

`just install` writes one symbolic link at `~/.local/bin/forge` that points at this checkout, and
`just uninstall` removes it. [docs/usage.md](docs/usage.md#installation) states the recipe rules, the
`PATH` line and the standalone bundle.

## Options

| Option | Behavior |
|---|---|
| `-p`, `--path PATH` | Set the workspace destination; also accepts `--path=PATH`. |
| `-n`, `--dry-run` | Print the plan and write nothing. |
| `-h`, `--help` | Print help and exit 0. |
| `-v`, `--version` | Print `forge <version>` and exit 0. |

The table is the complete option set. No other flag exists, and the command never prompts. `-v` is
short for `--version`; no verbose mode exists.

## Create-only, safety and Git-free rules

- **Create-only:** A destination that already exists is refused with exit code 3, and
  [usage](docs/usage.md#create-only-rule) states the complete rule.
- **Safety:** The tool refuses every protected path and unsafe destination form that
  [usage](docs/usage.md#protected-paths) lists.
- **Git-free:** The generator runs no Git command and creates no `.git`;
  [usage](docs/usage.md#what-to-do-after-generating) states the manual version-control steps.

## Architecture

`forge` resolves its own path and loads six libraries in a fixed order, then runs `parse_args`,
`preflight`, `create_tree`, `copy_templates`, `make_executables` and `print_summary`.
[docs/architecture.md](docs/architecture.md) describes each library, the flow, the safety invariants
and the template mapping.

## Tests and lint

```bash
bash tests/run.sh
just lint
```

`bash tests/run.sh` runs every test file under `tests/` and returns non-zero when one fails.
`just lint` runs ShellCheck over `forge`, `lib/*.sh`, `scripts/*.sh` and `tests/*.sh`, and it fails
when ShellCheck is absent.

## Limitations

- **Platform:** The tool runs on Linux and WSL2 only. Native Windows and Git Bash are refused with
  exit code 4, and macOS is not supported.
- **Concurrency:** A local process can change the destination between verification and the atomic
  move. The tool is not a security boundary against a concurrent local adversary.

## License

MIT. See [LICENSE](LICENSE).

Created by **Thiago Soares** - <thiagosilvaandradesoares@gmail.com>.
