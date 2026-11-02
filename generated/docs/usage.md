# Usage

`forge` generates a standardized workspace in a destination that does not exist yet.

The manual states installation, destination rules, protected paths, exit codes, worked examples,
inspection and the steps after generation.

## Installation

`forge` needs Bash 4 or newer on Linux or WSL2. See
[the requirements section](../README.md#requirements-and-compatibility) for the required commands and
the supported baseline.

Run every command in this section from the tool repository root, the directory that contains `forge`.

### Symbolic-link install

```bash
just install
```

The recipe writes one symbolic link at `~/.local/bin/forge` that points at this checkout. The recipe
creates `~/.local/bin` when the directory is absent, and it refuses a symbolic link at `~/.local` or
`~/.local/bin`. The recipe also refuses to replace a regular file or a link owned by another program.

The recipe leaves `PATH` unchanged. Run this line to use `forge` by name in the current shell:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add the same line to your shell profile to keep the setting.

Remove the link with:

```bash
just uninstall
```

The recipe removes only the link whose target is this checkout, and it never removes a regular file.

### Standalone bundle

```bash
bash scripts/build-standalone.sh
```

The script writes a versioned bundle under `dist/`, a `.tar.gz` archive and a `.sha256` checksum.
Extract the archive in any directory, and run `./forge` from the extracted directory.
[ADR 0003](adr/0003-standalone-vs-modular.md) records the bundle layout and the build rules.

## Destination rules

`forge` accepts the destination through `-p PATH`, `--path PATH` or `--path=PATH`. The default
destination is `$HOME/workspace`.

The command expands `~` and `~/...` in the value, and it rejects `~user`. Spaces are allowed in a
path; newline, carriage return, tab and other control characters are rejected.

The parent directory must already exist, be a directory, and be writable and searchable. `forge`
creates no intermediate parent. The destination must be a direct child of that parent.

Comparisons use canonical absolute paths, component boundaries and case-sensitive equality:
`/various` is not inside `/var`.

### Create-only rule

A destination that already exists is refused with exit code 3, and the refusal writes nothing. The
rule covers an empty directory, a non-empty directory, a regular file, a symbolic link and any other
type. No option overrides the rule, and a dry run refuses the same destinations.

A successful run creates every managed path exactly once, in a destination that was absent when the
run started. `forge` never merges, repairs, overwrites or deletes an existing file.

`forge` also refuses a destination that equals, sits inside or contains the tool directory.

### Symbolic links

A destination that is a symbolic link is refused. A parent that is a symbolic link is allowed when
its canonical path passes the path checks.

## Protected paths

`forge` refuses these paths after canonicalization. The comparison uses component boundaries and is
case-sensitive.

| Path | Rule | Note |
|---|---|---|
| `/` | Refuse the exact path | Descendants are not refused by this row. |
| `$HOME` | Refuse the exact path | Descendants are allowed except the sensitive paths below. |
| `$HOME/.ssh`, `$HOME/.gnupg`, `$HOME/.aws`, `$HOME/.azure`, `$HOME/.kube`, `$HOME/.docker`, `$HOME/.config`, `$HOME/.local`, `$HOME/.password-store`, `$HOME/.terraform.d`, `$HOME/.npmrc`, `$HOME/.pypirc`, `$HOME/.netrc`, `$HOME/.git-credentials` | Refuse the path and every descendant | Configuration files and credentials. |
| `/usr`, `/etc`, `/bin`, `/sbin`, `/var`, `/boot`, `/dev`, `/sys`, `/proc` | Refuse the path and every descendant | Canonicalize before comparing. |
| `/root`, `/opt`, `/srv`, `/run` | Refuse the path and every descendant | Additional safety paths. |
| `/home` | Refuse the exact path | The parent itself; the homes follow the rule below. |
| A recognized temporary root | Refuse the exact path | See the temporary exception. |
| A strict descendant of a recognized temporary root | Allow | The narrow exception below. |

### The temporary exception

`/var` is a protected path, and tests and temporary work use directories under it. `forge` allows a
destination under a temporary root when all five conditions hold:

1. The destination is a strict descendant of the root.
2. The canonical root is `/tmp`, `/var/tmp` or a path under `/var/tmp/`.
3. The destination is not equal to the temporary root.
4. No component of the destination is a symbolic link that points outside the canonical root.
5. The root came from `TMPDIR`, or from `/tmp` when `TMPDIR` is unset. `forge` canonicalizes that root
   and checks it against the list in condition 2.

The exception covers the `/var` rule only, and it is not a general bypass. No other protected path
accepts it.

### Other users' homes

`forge` refuses `/home` itself and a canonical destination under `/home/` that is not `$HOME` or
below `$HOME`. The rule protects the home directory of another user on the same machine.

## Exit codes

| Code | Meaning |
| ---: | --- |
| 0 | Success, help, version or a valid dry run |
| 1 | Unexpected general error |
| 2 | Usage error: unknown option, missing value or invalid combination |
| 3 | Safety refusal: protected path, invalid destination or an existing destination |
| 4 | Missing environment or dependency: Bash older than 4, an unsupported platform, `HOME`, or a required command |
| 5 | Filesystem failure: creation, copy, permission or tree verification |
| 6 | Reserved; no code path produces it |

`die CODE MESSAGE` prints the message to stderr and exits with the code. A partial failure reports
what the run already created before it exits.

## Examples

Run every command in this section from the tool repository root.

### Run with the default destination

```bash
./forge
```

The command targets `$HOME/workspace`. Run the dry-run example first; an existing destination is
refused with exit code 3.

### Create a workspace at ~/lab

```bash
./forge -p ~/lab
```

`forge` expands `~` and creates the full workspace at `~/lab`. The destination must be absent, and the
parent `$HOME` must already exist.

### Plan without writing

```bash
./forge --dry-run
```

The command prints every directory and file it would create under `$HOME/workspace`, plus the
summary, and it writes nothing. The counters in a dry run are simulated.

### Show help

```bash
./forge --help
```

Help exits 0 and lists the options, the defaults, examples, the path protections, the exit codes and
the create-only rule.

### Show version

```bash
./forge --version
```

The command prints `forge` and the version on one line, and it exits 0. `FORGE_VERSION` in `forge` is
the single source of that value.

## Inspecting what will be generated

Three checks cover inspection, and none adds an option.

1. **Plan only.** `./forge --dry-run -p DIR` prints every directory and file it would create, and it
   writes nothing. The plan prints paths, never file contents.
2. **Read the source.** The bytes that will be installed already exist under `templates/`, and
   [architecture.md](architecture.md#the-template-to-workspace-mapping) states the mapping. Reviewing
   those files reviews the generated content.
3. **Generate into a throwaway directory and compare.**

```bash
base=$(mktemp -d)
./forge -p "$base/workspace"
find "$base/workspace" -type f | sort
```

`mktemp -d` creates the parent, `forge -p` fills `$base/workspace`, and `find` lists the files. Run
`diff -r -- "$base/workspace" OTHER` with a workspace you already have to compare. Leave `$base` in
place; the operating system cleans `/tmp`.

Generation is create-only, so a second run against the same path exits 3. Use a fresh directory for
each comparison.

## What to do after generating

The summary prints the absolute workspace path, the counters, whether the run was a simulation, the
documented limitations and the script to adapt first.

1. Read the root `README.md`, the root `justfile` and `docs/adr/0001-workspace-structure.md`.
2. Edit `scripts/setup.sh`, `scripts/backup.sh`, `scripts/clean.sh` and `scripts/doctor.sh`. Each
   script accepts `--help`, and each unfinished stage prints `not implemented: <stage>` and exits 1.
3. Fill `data/raw/` with source data. Keep the other data stages for intermediate and processed
   files.
4. Initialize a Git repository only where you want one. The generator wrote no `.git` directory and
   made no commit.
5. Run `just --list` in the workspace to list the four recipes. Each recipe forwards its arguments to
   one script.

`experiments/`, `projects/`, `infrastructure/` and the four `data/` stage directories ship a
`.gitignore`. The file ignores the directory contents and keeps the README and the ignore file. The
generator wrote that file; the user decides when to run `git init`.

## Risks

- **Default destination:** `./forge` targets `$HOME/workspace`. Run `./forge --dry-run` before the
  first real run.
- **Existing destination:** The destination must not already exist. `forge` never merges into an
  existing tree, and it refuses every destination form with code 3.
- **Windows:** WSL2 is the supported Windows environment. Native Windows and Git Bash are refused
  with exit code 4.
