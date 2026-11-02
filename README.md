# workspace-forge

A create-only Bash generator for a standardized local workspace — and the specification that
produces the generator itself.

## Start here

```bash
./doctor.sh      # check the host tools; names what is missing and the version it needs
just --list      # the recipes, each naming the half it acts on
just root-test   # this repository's suite
```

`doctor.sh` is the entry point. It reads only the host, exits 1 while something required is missing,
and prints the command that installs it. Nothing else here runs without `just`, so run it first when
`just` is absent.

This repository holds two artefacts:

| Path | Role |
|---|---|
| `spec/` | The specification: the prompt and the checks that enforce it. **Source of truth.** |
| `generated/` | The tool exactly as the specification produces it. **Never edited by hand.** |

The relation is one-way:

```text
edit spec/  ->  regenerate  ->  review the diff  ->  commit both
```

Only a generation run writes `generated/`, and that run may be executed by an agent or by a human
working through the prompt by hand. Nobody hand-edits the output afterwards, and every lasting
change goes back into the prompt; a fix that exists only in the output is a fix that the next
regeneration silently deletes. See [`spec/README.md`](spec/README.md) for the workflow, the spec
version and the one documented deviation.

## What the tool does

`generated/forge` creates a workspace with twelve directories in a destination that must not
already exist. It is **create-only**: it never merges, updates, repairs or overwrites an existing
tree, and no flag changes that. `--dry-run` prints the plan and writes nothing.

It is a Bash script with six libraries, plain-file templates copied byte for byte, nine executable
tests, and no runtime dependency beyond Bash 4 and standard command-line tools. It runs no Git
command, uses no network and never prompts for input.

## What a generated workspace looks like

`cd generated && ./forge -p ~/workspace` produces exactly this tree, byte for byte:

```text
workspace/
├── README.md
├── .gitignore
├── .editorconfig
├── .env.example
├── justfile
├── docs/
│   ├── README.md
│   └── adr/
│       ├── README.md
│       └── 0001-workspace-structure.md
├── scripts/
│   ├── README.md
│   ├── backup.sh
│   ├── clean.sh
│   ├── doctor.sh
│   └── setup.sh
├── data/
│   ├── README.md
│   ├── external/
│   │   ├── README.md
│   │   └── .gitignore
│   ├── interim/
│   │   ├── README.md
│   │   └── .gitignore
│   ├── processed/
│   │   ├── README.md
│   │   └── .gitignore
│   └── raw/
│       ├── README.md
│       └── .gitignore
├── experiments/
│   ├── README.md
│   └── .gitignore
├── infrastructure/
│   ├── README.md
│   └── .gitignore
└── projects/
    ├── README.md
    └── .gitignore
```

Twelve directories, twelve READMEs (one per directory, same five-section standard), a root
`justfile` whose four recipes only forward arguments to the scripts, four script skeletons that
fail loudly until you fill them in, one ADR, and eight `.gitignore` files: one at the root and
seven inside the directories that may later become independent repositories.

## Quick start

```bash
git clone https://github.com/<owner>/workspace-forge.git
cd workspace-forge/generated

./forge --dry-run -p ~/lab     # plan: prints every directory and file, writes nothing
./forge -p ~/lab               # create ~/lab
```

Requirements: Bash 4 or newer, Linux or WSL2, with Ubuntu 24.04 LTS or newer as the supported
baseline. Native Windows, Git Bash and macOS are refused with exit code `4`; run the tool from a
WSL2 shell, not from PowerShell or CMD.

## Host checks (`doctor.sh`)

`doctor.sh` answers one question: can this host run the project? The script reads and never installs,
and it exits non-zero while something needs attention.

### What it checks

Two sections, two reports:

| Section | Question | Columns |
|---|---|---|
| `Packages` | is the command present, and new enough? | command, version found, minimum, status |
| `Services` | is the unit or container up? | unit, probe, state |

Package statuses are `ok`, `missing` and `too old`. The package check answers one question: is the
program installed, and new enough? A row whose source is `dpkg` reads the version apt recorded; when
dpkg owns no package, `version_of_program()` holds a case per program that needs a special way of
reading it. Docker is the case in hand: Docker Desktop mounts the binary into WSL with no package
behind it, so the program reports its own version. Every probe runs under a five-second timeout, so a
daemon that hangs cannot hang the report. A program with no package and no case shows `--`. Whether a
daemon answers belongs to `Services`, so a program whose daemon is down still reports `ok` here.

Service states split in two. The healthy ones (`running`, `listening`, `scheduled`, `watching`, `done`)
print green and stay out of the summary; `stopped`, `failed`, `absent` and `unknown` are reported and
make the exit code 1. A group with no row still appears, with `no unit declared` under it.

### Usage

```bash
./doctor.sh          # report; exit 0 when clean, 1 when not
./doctor.sh -h       # usage
```

Colour is dropped when stdout is not a terminal. `NO_COLOR=1` forces it off; `FORCE_COLOR=1` keeps it
on through a pipe.

### Reading the output

```text
Packages
  +-- Lints  source issue checks
  |   \-- shellcheck  --      >= 0.9    missing

    needs    just, shellcheck
    run      sudo apt-get install -y just shellcheck

Services
  +-- Daemons  background processes
  |   \-- docker  docker-daemon  running
  +-- Sockets  on-demand activation
  |   \-- no unit declared
  +-- Timers  scheduled jobs
  |   \-- no unit declared
  \-- Containers  container instances
      \-- no unit declared
```

The package section closes with its gaps and the command that clears them; the service section
closes with the states that need attention and, when one can be started, the command. The `install`
line translates a command to its Debian package, using the names Ubuntu 24.04 LTS ships (`awk` is
`mawk`, `find` is `findutils`, `docker` is `docker.io`); a tool absent from the map falls back to its
own name. The `dpkg` source asks the package database who owns the binary, so `docker.io` and
`docker-ce` both work without a catalogue edit.

A minimum is either `POSIX` (presence only) or a Debian version. Ordering is `dpkg
--compare-versions`, so an epoch (`1:2.0`), a pre-release (`1.0~rc1`) and a revision (`1.0-1ubuntu1`)
all count. `dpkg` is required: without it the script stops with exit 2 at start-up, instead of
comparing numbers and guessing.

### Use cases

**First run on a fresh machine.** `./doctor.sh` lists what is missing, prints one `install` line and
exits 1. Run that command and call it again to reach `ok  everything required is present`.

**Gate in CI.** The exit code is the gate: 0 means the runner has what the build needs. The report
reaches the job log, and the `install` line tells what to add to the image.

**After adding a tool to a section.** Edit `PACKAGE_TOOLS`, run `./doctor.sh`, and the new leaf
appears with the version this host reports. No other change is needed.

**After adding a service.** Declare the group, then one row with the unit name and its suffix
(`sshd.service`, `docker.socket`). A socket or a timer needs its companion service to exist, or
systemd refuses the unit.

**Inside a container.** `docker run --rm -v "$PWD:/src:ro" ubuntu:24.04 bash /src/doctor.sh` reports
what a minimal image lacks. The docker probes read `absent` unless the socket is mounted, with
`-v /var/run/docker.sock:/var/run/docker.sock`.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | nothing needs attention |
| 1 | a package or a service needs attention, and the summary names it |
| 2 | usage error, or inconsistent sections: unknown group, probe, source or minimum |

### Tests

```bash
bash tests/run.sh                   # every file, one summary
bash tests/test-doctor-units.sh     # the pure helpers, called directly
bash tests/test-doctor-sections.sh  # a mistake in any section stops the run
bash tests/test-doctor-services.sh  # docker probes, against the real daemon
bash tests/test-doctor-systemd.sh   # real systemd in a privileged container
bash tests/test-just-recipes.sh     # the justfile only delegates
```

Every file reads as Given / When / Then and shares `tests/lib.sh`, which holds the assertions and the
fixtures; a file sets up a host, runs the report once, and states what it must say. CI runs each file
as its own job, so a failure names the file instead of hiding in one long log.

The suite also runs in the image the repository ships, which carries the tools it calls:

```bash
docker build -f tests/Dockerfile -t dsh-doctor .

# Four files: no host access at all.
docker run --rm dsh-doctor

# All six: adds the socket, so the two docker-backed files can run.
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock dsh-doctor
```

Each file keeps its records under `tests/output/<file>/`: a `results.txt` with every assertion, plus
the reports it produced. A failing run then leaves something readable behind. The directory is ignored
by Git.

The socket is the only host resource the suite ever asks for, and only two files need it. The systemd
file copies its report into the container it starts, so no checkout path has to be visible to the
daemon. The image is a snapshot of the checkout: rebuild it after changing the tests.

#### What that costs in trust

The socket is a root-level interface. Whoever reaches it can start a privileged container that mounts
the host, so a run with the socket has the same power as a run as root. Add it on a disposable machine
or a CI runner, and keep credentials off that host. Without the socket the container reaches nothing.

The systemd file also starts one privileged container and mounts the cgroup tree read-write. Both are
what running systemd inside a container requires; the container is short-lived and named by the suite.
The test image runs as root, copies the checkout without `.git`, and installs only the packages named
in its Dockerfile.

`test-doctor-systemd.sh` boots an Ubuntu container with systemd as PID 1, built on demand from
`tests/systemd.Dockerfile`; nothing is pulled from a third party. Without docker, or when the build
fails, the file reports a skip and exits 0, so the suite still runs anywhere.

## Repository layout

```text
.
├── README.md                       this file
├── LICENSE                         MIT; the tool ships the same file as generated/LICENSE
├── .gitignore                      build output and editor noise
├── .gitattributes                  pins LF for every text file
├── justfile                        orchestrator: test, lint, build, plan, create, install, uninstall
├── doctor.sh                       host report: reads only, installs nothing
├── VERSION                         generator version, also shown by doctor.sh
├── .github/                        CI, release and contribution templates (repository level)
├── tests/                          the host-check suite; see "Host checks"
├── spec/                           the specification
│   ├── workspace-forge.prompt.md   the prompt that generates the tool
│   ├── README.md                   workflow, spec version, the one deviation
│   ├── CHANGELOG.md                changes to the specification
│   └── audit/                      the checks that enforce Section 0.10
└── generated/                      the tool, exactly as the specification produces it
    ├── forge                       entrypoint, sole definition of the version
    ├── lib/                        six libraries
    ├── templates/                  installable content: 29 files, 28 of them installed
    ├── tests/                      nine executable tests
    ├── scripts/                    standalone build
    ├── docs/                       usage, architecture, contributing, three ADRs
    ├── justfile                    test, lint, build, install, uninstall, release
    ├── README.md
    ├── CHANGELOG.md
    ├── LICENSE
    ├── .editorconfig
    ├── .shellcheckrc
    └── .gitignore
```

`.github/` sits at the repository root because GitHub reads workflows and contribution templates
only from there. It is the single deviation from `generated/` being the complete tool tree; see
[`spec/README.md`](spec/README.md).

## Development

From the repository root, `just` delegates into `generated/`:

The name says which half a recipe acts on: `generated-*` enters the tool,
`spec-*` reads the specification, `root-*` checks this repository. A
`generated-*` recipe needs the tool tree; without it the recipe stops and names
the document an agent must run.

```bash
just generated-test          # the tool's suite
just generated-lint          # shellcheck on forge, lib/, scripts/, tests/
just generated-build         # standalone bundle in generated/dist/
just generated-plan -p ~/lab # plan only: every directory and file, writes nothing
just generated-create -p ~/lab  # create the workspace
just generated-install       # symlink ~/.local/bin/forge -> this checkout
just generated-uninstall     # remove only that link

just root-test               # this repository's suite: the host report
just spec-audit              # the specification's own checks

# Check the host tools this repository needs (reads only; installs nothing):
./doctor.sh

# Test doctor.sh itself:
bash tests/run.sh

# The audit of the specification (exits 1 on a violation):
bash spec/audit/run.sh

```

`create` forwards its arguments verbatim to `generated/forge`, so every flag and every usage error
behaves exactly as it does when you call the tool directly. With no arguments it targets
`$HOME/workspace`, like the tool does.

`install` writes one symbolic link and nothing else: no package, no copy, no `PATH` edit. It refuses
to replace a regular file or a link owned by another program. Because the link points at this
checkout, moving or deleting `generated/` breaks the command; the standalone bundle is the
self-contained alternative.

The test suite requires `just` and `shellcheck`; CI installs both and fails if either is unavailable.
Tests run on Linux, inside Docker or CI — not on the host and not on WSL.

To change the tool, edit the specification and regenerate. Do not patch `generated/`.

## License

MIT. See [`LICENSE`](LICENSE). `generated/LICENSE` is the same license, shipped with the tool.

Created by **Thiago Soares** -
[thiagosilvaandradesoares@gmail.com](mailto:thiagosilvaandradesoares@gmail.com).
