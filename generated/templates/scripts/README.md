# 📁 scripts/

> Shell scripts that the `justfile` calls, shipped as skeletons that stop with an error until the user writes each stage.

---

## 📋 Purpose

The `scripts/` directory holds the commands that act on the workspace. The `justfile` in the workspace root names one recipe per script, and a recipe is a named command that `just` runs. The command `just backup` reaches `scripts/backup.sh` without the user typing a path.

Each script ships as a skeleton with a header, an argument block and named stage functions. A stage function whose body calls `not_implemented` does not pretend to work: it prints `not implemented: <stage>` to stderr and exits 1.

## 📁 Structure

```text
scripts/
├── README.md
├── backup.sh
├── clean.sh
├── doctor.sh
└── setup.sh
```

## ✅ Rules

- **Bash header** — each script starts with `#!/usr/bin/env bash` and applies `set -Eeuo pipefail`, so a failed command stops the run.
- **Header comment** — a comment block at the top states the script's purpose, usage, accepted arguments and the reminder to edit it.
- **Entry block** — each script parses its arguments and calls the named stage functions in order.
- **Loud failure** — `not_implemented` prints `not implemented: <stage>` to stderr and exits 1, so a stage without code refuses to report success.
- **Help** — `--help` prints the usage block and exits 0 without creating a file.
- **No installs** — no script installs a package, changes global configuration, starts a service or uses the network.
- **`setup.sh`** — the file defines the stub `execute_setup`, the stage that creates the prerequisites this workspace needs. The file has no `check_prerequisites` or `install_dependencies` function and reads no `.env`.
- **`backup.sh`** — the file defines the stubs `assert_output_outside_workspace`, `build_excludes`, `run_dry_run` and `create_backup`. The stages check the output path, assemble the exclude list, print a dry-run plan and create the archive.
- **`backup.sh` options** — the entry block accepts `--output DIR` and `--dry-run`, and the script excludes `data/` by default.
- **Symbolic links** — a symbolic link is a file that points at another path. `assert_output_outside_workspace` refuses an output path that reaches inside the archive through one.
- **`clean.sh`** — the file defines the stub `clean`, the stage that removes what this workspace produces, including files outside the workspace.
- **`doctor.sh`** — the file defines the stubs `check_tools`, `check_structure` and `check_permissions`, which report a missing tool, a missing directory and an unsafe permission.
- **Your edit** — the user edits each script to match the workspace. Replace a stub body with the commands this workspace needs, and keep the header and the option set.

## 🚫 Out of scope

- A one-time command → the user runs it in a terminal
- An archive that `backup.sh` writes → the `--output` directory, outside the workspace
- Deployment files → `../infrastructure/`
- Instructions longer than a script header → `../docs/`
- Project code → `../projects/`

## 🔗 See also

- [backup.sh](backup.sh)
- [setup.sh](setup.sh)
- [clean.sh](clean.sh)
- [doctor.sh](doctor.sh)
- [justfile](../justfile)
- [Infrastructure](../infrastructure/README.md)
- [Workspace README](../README.md)
