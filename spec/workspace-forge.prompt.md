# Prompt — Implement `workspace-forge`

Spec version: 29

**How to read this document.** "You" is the agent executing this prompt; a human reads the same
instructions. A rule binds whether it is written as an imperative ("Create ..."), as a bold
prohibition ("Never ...") or with `MUST`. `STOP` means: halt, print the check that failed and the
resolved path, and ask the human before continuing. "The tool repository root" always means the
output directory defined in Section 0.1. When two requirements conflict, or a single requirement is
ambiguous and acting could destroy something, stop and ask: never resolve a conflict by choosing
the convenient reading.

> **Safety-first specification for humans and agents.**
> This document describes how to implement the `workspace-forge` tool, not how to use the generated
workspace.
>
> **For agents:** read Section 0 completely before creating any file. If a precondition fails, stop
and ask; do not bypass a protection with flags.
> **For humans:** the safety decisions are in Section 0 and in the tables in Sections 5, 6 and 9.
Acceptance criteria are in Sections 14 and 15.

**Contents:** 0 preconditions | 1 objective | 2 generated workspace | 3 repository tree | 4 `forge`
and libraries | 5 CLI | 6 library duties | 7 templates | 8 README standard | 9 security and dry-run
| 10 tests | 11 documentation | 12 dev configuration | 13 CI and releases | 14 Docker validation |
15 completion checklist | 16 report.

---

## 0. Preconditions, scope and absolute rules

### 0.1 Output directory and its replacement

**Location.** This prompt is the file `spec/workspace-forge.prompt.md`. The tool is written to the
directory `generated/`, a sibling of `spec/`:

- `PROMPT_DIR` - the directory that contains this prompt, resolved with `cd -P`.
- `REPO_ROOT` - the parent of `PROMPT_DIR`.
- `WORKSPACE_FORGE_ROOT` - `$REPO_ROOT/generated`, resolved to an absolute path before any write.

`WORKSPACE_FORGE_ROOT` **is** the tool repository root: `forge`, `lib/`, `templates/`, `tests/`,
`docs/`, `justfile`, `README.md`, `CHANGELOG.md`, `LICENSE`, `.editorconfig`, `.shellcheckrc` and
`.gitignore` live directly inside it. The tool is named `workspace-forge`; only its directory is
called `generated`. Every path this document calls "the tool repository root" means that directory.

One exception: `.github/` is written one level above the prompt's directory - at
`$PROMPT_DIR/../.github`, the same path as `$REPO_ROOT/.github` - and never inside
`WORKSPACE_FORGE_ROOT`. GitHub reads workflows, issue templates and pull request templates only from
the root of the repository that hosts them, and `.github/` is repository infrastructure rather than
part of the distributed tool. Do not create it in both places.

Everything else at `$REPO_ROOT` - `spec/`, `README.md`, `justfile`, `LICENSE`, `.gitignore` -
already exists and is outside this prompt: read it, never modify it.

**Replacement.** The directory may already exist and may be non-empty: it holds the previous
generation. You **may** remove it and regenerate. Removal is allowed only when every guard
below holds, and every guard is mandatory:

1. `WORKSPACE_FORGE_ROOT` resolves to exactly `$REPO_ROOT/generated` - string equality on canonical
   paths after `cd -P`, never a prefix match.
2. Its basename is exactly `generated`.
3. It is a real directory: `[[ -d "$WORKSPACE_FORGE_ROOT" && ! -L "$WORKSPACE_FORGE_ROOT" ]]`. A
   symbolic link is refused, never followed.
4. It is not `/`, not `$HOME`, not an ancestor of `PROMPT_DIR`, not equal to `PROMPT_DIR`, and it
   does not contain `PROMPT_DIR`.
5. `REPO_ROOT` is your working workspace or a descendant of it, and that workspace is not `/`
   and not `$HOME`. If the working workspace is unknown, **STOP** and ask.
6. The variable is non-empty: `: "${WORKSPACE_FORGE_ROOT:?}"`. Never delete through a value that
   could expand to nothing.

If any guard fails, **STOP**, print the resolved path and the guard that failed, and ask. Do not
improvise, do not widen a pattern, do not clean anything else.

**Procedure**, once every guard holds:

1. Print the resolved absolute path and one line saying what is about to be deleted.
2. Delete the contents with `find -- "$WORKSPACE_FORGE_ROOT" -mindepth 1 -delete`, then remove the
   now-empty directory with `rmdir -- "$WORKSPACE_FORGE_ROOT"`.
3. `find ... -delete` and `rmdir` are the only deletion commands allowed for this step: always a
   quoted path after `--`, never a glob such as `generated/*`, never another path at `$REPO_ROOT`.

If `WORKSPACE_FORGE_ROOT` does not exist, create it and continue. If it exists and is empty,
continue without deleting. Deleting anything outside that single directory is a hard failure of this
prompt, not a matter of preference.

### 0.2 What this prompt produces

This prompt produces the tool repository:

- `forge`, libraries, templates, tests, documentation, lint/CI configuration and release
  preparation.
- No end-user workspace in `$HOME/workspace` during implementation.
- Generated workspaces only in disposable locations: `mktemp -d` directories on the host, or
  `/home/project` inside the validation container.

### 0.3 Operating modes and write limits

The task runs in one of two modes. The user states which one; when the task does not, ask before you
write anything.

**Development.** The agent builds, repairs or regenerates the tool. It may read and write any path
under the project root, with two exceptions:

- `.git` is never written, renamed or deleted, in either mode. Git data belongs to the user.
- `.github/` takes a write only when the change concerns GitHub itself: a workflow, an issue
  template, a pull request template, or a file those read. A change about the tool goes in the tool.

**Use.** The agent runs the tool and changes nothing. In this mode it:

- runs `just <recipe>` from the repository root, and nothing else;
- never invokes `generated/forge` or a script under `generated/` itself; a recipe that calls them is
  the sanctioned path;
- never writes, renames or deletes a path under the project root.

A request that needs a file changed belongs to a development run.

The audit of Section 0.10 runs in both modes. It reads files and writes nothing, so it never
conflicts with either mode: a use-mode agent still runs it and still reports the result.

Temporary directories created with `mktemp -d` and validated by prefix are allowed in both modes.

Forbidden in both modes:

- Write to the real `$HOME`, `~/.local`, `~/.config`, `~/.ssh`, `~/.gnupg` or equivalents.
- Run `just install`, `just release`, or a real `backup.sh`/`clean.sh` with real side effects.
- Change global Git configuration, `PATH`, shell startup files or system configuration.
- Use `sudo`, install host packages or access the network during local development.
- Create a remote repository, run `git push`, create a remote tag or publish a release.

Network access is allowed to pull the validation image (Section 14.2), inside the validation
container (Section 14.3) and inside CI. Installing packages inside that container is allowed and
expected: the checks need ShellCheck and `just`. Never install packages on the host or in WSL.

### 0.4 Absolute prohibitions

You **MUST NOT**:

- Delete recursively outside a validated temporary directory; every recursive deletion needs an
  absolute path and a prefix guard.
- Use `eval`, source untrusted files, `curl | sh`, `wget | sh` or equivalents.
- Use `chmod -R 777`, `chown`, `sudo` or change permissions outside the destination.
- Use `git clean -fdx`, `git reset --hard`, `git push`, `git remote add` or `gh release` locally.
  The generator itself never invokes Git; this prohibition additionally covers the surrounding
  engineering work.
- Copy or follow a symbolic link outside the allowed tree.
- Create real secrets, tokens, keys or credentials; examples must be clearly fictitious.
- Use `find ... -exec rm`, `xargs rm` or destructive automatic cleanup to "undo" a partial failure.
- Claim that something was created, executed, validated or published without actually doing it.

### 0.5 Definitions

- **Tool repository:** `WORKSPACE_FORGE_ROOT`; contains `forge`, `lib/`, `templates/`, `tests/`,
  `docs/`, `justfile`, `README.md` and the configuration files. `.github/` lives one level above, at
  `$REPO_ROOT/.github` (Section 0.1).
- **Generated workspace:** the destination created by `forge`; by default `$HOME/workspace`;
  separate from the tool.
- **Managed path:** a relative path derived from a regular file under `templates/`, excluding
  `templates/README.md`, mapped to the destination.
- **Dry-run:** simulation without any destination writes. Its counters are simulated (Section 9.2).
- **Create-only:** the tool refuses to run if the destination already exists in any form, including
  an empty directory. It never updates, merges into or repairs an existing workspace.
- **Preflight:** the read-only validation phase that runs before any write. It can refuse the run
  but can never create anything.
- **Stub:** a stage function whose body is one comment plus a call to `not_implemented`, so the
  script fails loudly instead of pretending to work.
- **TOCTOU:** "time-of-check to time-of-use": the gap between verifying a path and using it, during
  which another process could change it.
- **ADR:** architecture decision record: a short document with context, decision and consequences
  for one design choice.

### 0.6 Result classification

Every verification must be classified as:

- **Passed:** executed and completed as expected.
- **Failed:** executed and found a problem.
- **Not verified:** tool, platform or environment unavailable.
- **Not applicable:** verification does not apply to the case.

### 0.7 Safe stop

If any precondition fails, **STOP** without writing. Explain:

- what was checked;
- why the operation was refused;
- what the user must provide or fix;
- what was **not** changed.

`forge` refuses a destination that already exists by design; do not try to bypass that refusal with
any flag or manual edit.

### 0.8 Suggested work order

The sections describe the target, not a strict sequence. A reliable order is:

1. `forge` and `lib/`, until `./forge --help` and `./forge --dry-run -p DIR` work.
2. `templates/`, until a real run produces the tree in Section 3.
3. `tests/`, until `bash tests/run.sh` exits 0.
4. The repository documents, the `justfile` and the CI workflows.
5. Section 14, once, at the end.

Run the suite after each part, not only at the end: a defect caught while writing the libraries costs
one edit, and the same defect caught in Section 14 costs a rework across four files.

### 0.9 Who may write the output directory

Only a generation run produces `WORKSPACE_FORGE_ROOT`. **That run may be performed by an agent or by
a human** working through this document by hand; both are legitimate, and both must produce the same
files. What follows separates the two cases: writing during a run, and editing outside one:

- **A generation run writes the files.** While it runs, the files under `WORKSPACE_FORGE_ROOT` are
  being created and corrected; that is expected, by either author.
- **Nobody edits the output outside a generation.** A human does not patch a file there afterwards,
  and an agent does not leave behind a fix that this prompt does not describe. Such an edit is
  overwritten by the next run, without a warning and without a trace.
- **A human changes this prompt and regenerates**, by hand or through an agent. That is the supported
  path, and it is the only one.
- **An agent writes back every change that must last.** While an agent runs the generation it edits
  files under `WORKSPACE_FORGE_ROOT` freely. A change that must survive the next run - a defect fixed
  during validation, a sentence clarified, a check added - also goes into this prompt, in the same
  change. If it cannot be written here as a sentence a later agent or human could follow, it does not
  belong in the output directory either.
- **Acceptance test: both directions must match.** Before reporting completion, compare the two. Every
  lasting change in the output traces to a sentence in this prompt, and every sentence here that
  describes a file in the output is true of that file. What fails either direction is reverted or
  written into this prompt.

A fix that lives only in the output is a regression scheduled for the next regeneration, and it fails
silently: nothing in the repository records that it happened.

### 0.10 Writing rules and the audit

These rules cover every sentence you write. That includes this prompt, the report from Section 16,
and every file the generation creates under `WORKSPACE_FORGE_ROOT`. It covers READMEs, documentation,
script comments and `justfile` comments.

A sentence passes when a reader with no access to you answers four questions without asking:

- who performs the action;
- what exactly is acted on;
- where it happens;
- how someone would verify it.

A reader of a generated file never sees this prompt. A vague sentence there cannot be resolved by
looking here.

- Name the actor, the verb and the object. No passive voice that hides who acts.
- No metaphor as a rule: "owns", "lives in", "belongs to", "carries", "propagates". Say what the
  file contains, where the rule is stated, which command creates the file.
- No vague qualifier: persistent, appropriate, reasonable, as needed, where relevant, if useful,
  normally, usually. Replace it with the condition that decides the case, or delete it.
- "should" is never a requirement. State the requirement with "must", or drop the sentence.
- No unfalsifiable claim: clear, correct, robust, high quality. Name the observable instead.
- Define a term the first time it appears, and keep one name for one thing.
- One idea per sentence, twenty-five words maximum.

**Every change re-verifies.** An edit to this prompt invalidates the previous audit. Run the audit
and fix what it reports:

1. Run `bash spec/audit/run.sh`: it runs every check and exits 1 on any violation.
2. If it exits 1, fix what it names and run it again until it exits 0.
3. Apply the disposition table below to each warning. Never turn a warning into an error.
4. Run it again and confirm exit 0 and that no file grew.
5. Report the counts before and after, and the size delta per file.

| Warning | Keep it when | Otherwise |
|---|---|---|
| `may` | it states a permission with an explicit condition, or a fact that can happen | rewrite with `must` or `must not` |
| sentence-initial pronoun | the antecedent is in the previous sentence of the same paragraph | name the referent |
| open quantifier | never | replace it with a count or a named set |
| comparative without baseline | never | name the measure, or delete the comparison |
| bullet over 25 words | the items are a closed enumeration | split at the semicolons, one item per line |

A warning that no row covers stays untouched and appears in the report.

**What the audit is.** The audit runs in both modes of Section 0.3, because it only reads files.

`spec/audit/` holds the Bash scripts that enforce this section. They are written by hand and never
generated: they are not in `WORKSPACE_FORGE_ROOT` and never ship with the tool. `run.sh` calls the
others and aggregates their exit codes; each script runs alone and documents itself with `--help`.
Every script returns 0 clean, 1 violation, 2 usage error, and needs only Bash 4, `awk` and `grep`.

**Which one to run.** Match the check to what you touched:

| You changed | Run |
|---|---|
| a sentence or a paragraph | `prose.sh FILE...` |
| a link or an anchor | `links.sh FILE...` |
| a file name or a path reference | `paths.sh FILE...` |
| a number stated in prose | `counts.sh` |
| a fenced block | `code-fences.sh FILE...` |
| a documented tree | `tree.sh ROOT DOC HEADING` |
| a section reference or a "table below" | `refs.sh FILE...` |
| a line ending, a tab or a BOM | `encoding.sh FILE...` (all files) |

`run.sh --list` prints the same set with their arguments. While you edit, run the narrow check. A full
run of `run.sh` is the gate: run it before you report completion, every time, and the narrow check
never replaces it.

**When a check is wrong.** If a check reports a violation on text you believe is correct, the check
is wrong: fix the check, not the text. If you cannot reach exit 0 without breaking a requirement,
STOP as Section 0.7 describes. Report which check, which line, and what you tried.

**Warnings.** Every text change follows the same loop:

1. List the warnings in the file you edited, with `prose.sh -w`.
2. Fix each warning your change introduced, without losing meaning. Keep the technical content and
   use plain, valid construction.
3. Run the check again. A warning you fixed is gone: nothing else to record.
4. Three classes can be correct in context. Answer the question attached to each one:

   - `may`: does the sentence state the condition of the permission?
   - pronoun: is the antecedent in the previous sentence of the same paragraph?
   - long bullet: is the content a closed list?

5. If the answer is yes, leave the sentence alone. Otherwise the warning is right: rewrite the
   sentence.
6. If your change breaks something outside the lines you edited, that place is yours: fix it there
   too.
7. Before you report completion, run `run.sh` in full.

Never add a note in the file to explain a warning. The sentence must answer the question by itself.

The audit catches the mechanical part. Re-check by hand the text you touched, and after a full
generation every file written under `WORKSPACE_FORGE_ROOT`. A change that introduces a sentence
failing the four questions is not complete, even when the behaviour it describes is correct.

---

## 1. Objective

Implement the tool `workspace-forge` inside the output directory defined in Section 0.1: a personal
Bash tool that generates standardized workspaces. Create real files in the environment; do not stop at
instructions in the reply.

The repository contains the `forge` executable, six modular libraries, installable templates,
automated tests, documentation, lint/CI configuration and release preparation. It must be
versionable, testable and create-only, and it must run only on Linux and WSL2.

The tool repository and the generated workspace are different things. Never mix installable
templates with documentation that describes the tool alone.

## 2. Generated workspace

`forge` produces a separate destination, by default `~/workspace`, containing the 12 directories with
one README each (Section 6.5), root configuration, four skeleton scripts (`backup.sh`, `setup.sh`,
`clean.sh`, `doctor.sh`), one ADR, and a `justfile` that only forwards calls to those four scripts.

The generated scripts are standardized and simple on purpose: they ship as skeletons for the user to
adapt, and every unimplemented stage stays a stub (Section 0.5).

---

## 3. Required repository structure

The root must contain the tree below. It is a text diagram, not code: nothing in it executes, and it
has no input, output or side effects.

The root of the tree is the output directory from Section 0.1, named `generated/`. The tool inside it
is named `workspace-forge`; the directory name is not part of the tool.

```text
generated/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── justfile
├── .gitignore
├── .editorconfig
├── .shellcheckrc
├── forge
├── lib/
│   ├── common.sh
│   ├── args.sh
│   ├── preflight.sh
│   ├── files.sh
│   ├── tree.sh
│   └── templates.sh
├── templates/
│   ├── README.md
│   ├── root/
│   ├── docs/
│   ├── scripts/
│   ├── data/
│   ├── experiments/
│   ├── projects/
│   └── infrastructure/
├── tests/
│   ├── lib.sh
│   ├── run.sh
│   ├── test-args.sh
│   ├── test-common.sh
│   ├── test-content.sh
│   ├── test-dryrun.sh
│   ├── test-existing-destination.sh
│   ├── test-preflight.sh
│   ├── test-scripts.sh
│   ├── test-scripts-behavior.sh
│   └── test-standalone.sh
├── docs/
│   ├── architecture.md
│   ├── usage.md
│   ├── contributing.md
│   └── adr/
│       ├── 0001-why-forge.md
│       ├── 0002-external-templates.md
│       └── 0003-standalone-vs-modular.md
└── scripts/
│   └── build-standalone.sh
```

`.github/` is not in this tree: it is written one level above the prompt's directory, at
`$PROMPT_DIR/../.github`, never inside `generated/` (Section 0.1). It holds the workflows and the
contribution templates.

Notes:

- `templates/README.md` documents the tool and is **not** installed.
- `FORGE_VERSION` in `forge` is the single source of the version (Section 4.3). The generator never
  runs Git; the tool repository may itself be a Git repository for development, which does not
  affect generation.
- Do not add modules, directories or dependencies that the implementation, tests or documentation do
  not need.
- All code, comments, messages, filenames and documentation must be in English.

---

## 4. Executable architecture

### 4.1 `forge`

`forge` must be a small Bash executable that:

1. Resolves its real path, including through a symbolic link.
2. Sets and exports `FORGE_HOME` and `FORGE_VERSION`.
3. Loads the six libraries in the required order.
4. Defines and runs `main "$@"`.
5. Returns exit codes consistent with the result.

Resolve the path without relying on `readlink -f`. The Bash snippet below follows symbolic links up
to the real file and stores its absolute directory in `FORGE_HOME`. It only reads the filesystem (it
never writes) and prints nothing, so it behaves the same in dry-run and in a real run. Use
`readlink`, `dirname` and `cd -P` in a loop:

```bash
source_path=${BASH_SOURCE[0]}
while [[ -L $source_path ]]; do
  source_dir=$(cd -P -- "$(dirname -- "$source_path")" && pwd)
  source_path=$(readlink "$source_path")
  [[ $source_path == /* ]] || source_path="$source_dir/$source_path"
done
FORGE_HOME=$(cd -P -- "$(dirname -- "$source_path")" && pwd)
export FORGE_HOME
```

Rules:

- Apply `set -Eeuo pipefail` in `forge`, not in libraries.
- Libraries must not execute the main flow when sourced.
- `forge` must work when executed directly or through a symbolic link.
- The file must start with `#!/usr/bin/env bash` and be executable.
- Use the source guard below. It is Bash and runs `main` only when `forge` is executed directly, so
  sourcing `forge` from a test never starts a generation. It writes nothing and needs no flags.

```bash
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
```

### 4.2 Libraries

Create exactly these six libraries:

1. `lib/common.sh`
2. `lib/args.sh`
3. `lib/preflight.sh`
4. `lib/files.sh`
5. `lib/tree.sh`
6. `lib/templates.sh`

All must be loaded in that order.

Libraries define functions and constants only. If a library is executed directly, it must print a
clear message and exit non-zero.

Use the `FORGE_` prefix for globals to avoid collisions. Examples: `FORGE_TARGET`, `FORGE_DRY_RUN`,
`FORGE_CREATED_DIRS`, `FORGE_CREATED_FILES`, `FORGE_TOTAL_DIRS`, `FORGE_TOTAL_FILES`.

### 4.3 Single version source

`FORGE_VERSION` must be defined only in `forge`, before loading libraries.

- `--version` prints `forge <FORGE_VERSION>` on one line and exits 0.
- Documentation, `CHANGELOG.md`, `justfile`, CI and release workflows read the version from `forge`;
  do not declare a second constant.
- CI and release extract the version with the shell snippet below. Input: the `forge` file. Output:
  `0.1.0` on stdout, without quotes. It reads one file and writes nothing; it is not part of
  generation.

```bash
sed -n 's/^FORGE_VERSION="\(.*\)"$/\1/p' forge
```

- The standalone build copies `forge`, so the version travels with the artifact.
- The release workflow must reject a `vX.Y.Z` tag that does not match `FORGE_VERSION`.

### 4.4 Exit codes

| Code | Meaning |
|---:|---|
| 0 | Success, help, version or a valid dry-run |
| 1 | Unexpected general error |
| 2 | Usage error: unknown option, missing value, invalid combination |
| 3 | Safety refusal: forbidden path, invalid destination, destination already exists |
| 4 | Missing environment/dependency: Bash < 4, unsupported platform |
| 5 | Filesystem failure: creation, copy, permission, or tree verification |
| 6 | Reserved for future use; currently no path produces it |

`die CODE MESSAGE` prints the message to stderr and exits with `CODE`. Do not hide the original
cause. On partial failure, report what was already created before exiting.

---

## 5. CLI behavior

### 5.1 Required options

| Option | Behavior |
|---|---|
| `-p`, `--path PATH` | Set the workspace destination. Also accepts `--path=PATH`. |
| `-n`, `--dry-run` | Show operations without executing them. |
| `-h`, `--help` | Show help and exit 0. |
| `-v`, `--version` | Show version and exit 0. |

The option set above is complete: no other flags exist and the tool never prompts.

**Flag case:** every short flag is lowercase. `-v` is the short form of `--version`; this tool has
no verbose mode, so `-v` never means "verbose". Never add an uppercase form of this flag.

Parsing rules:

- Accept separate short options (`-p PATH`, `-n`, `-h`, `-v`). Do not accept clusters such as `-nh`.
- Accept `--path PATH` and `--path=PATH`.
- Reject `-p` without a value, `--path` without a value, an empty value, unknown options and
  positional arguments.
- Reject multiple `--path`/`-p` occurrences.
- Accept `--` as a terminator; any argument after it is an error because there is no positional
  target.
- `-h`/`--help` and `-v`/`--version` take precedence and exit 0 before preflight. If both are
  present, help wins.
- Do not use `getopts` for long options; use a `case` loop.
- Reject paths containing newline, carriage return or tab. Spaces are allowed.
- Expand only `~` and `~/...` in `--path`. Reject `~user`; do not use `eval`; do not expand
  user-supplied `$VAR`.

### 5.2 Defaults

| Variable | Default |
|---|---|
| `FORGE_TARGET` | `$HOME/workspace` |
| `FORGE_DRY_RUN` | `0` |
| `FORGE_CREATED_DIRS` | `0` |
| `FORGE_CREATED_FILES` | `0` |
| `FORGE_TOTAL_DIRS` | `12` |
| `FORGE_TOTAL_FILES` | derived from the template tree at runtime |

### 5.3 Combinations

| Combination | Result |
|---|---|
| `--dry-run -p PATH` (destination absent) | Plans the creation; writes nothing; exit 0. |
| `--dry-run -p PATH` (destination exists) | Refused with code 3; writes nothing. |
| `-p PATH` (destination exists, even empty) | Refused with code 3; writes nothing. |
| `-p PATH` (destination absent) | Creates the workspace; exit 0. |

### 5.4 Destination-exists refusal

Because `forge` is create-only, a destination that already exists — including an empty directory —
is always refused with code 3 before any write, in both real and dry runs. No flag overrides this
refusal. The refusal message reports the absolute destination path and states that the destination
must not exist.

### 5.5 Help

`usage` must use a short quoted heredoc and describe:

- defaults;
- examples;
- `--dry-run`;
- path protections;
- exit codes;
- the create-only behavior (destination must not exist).

---

## 6. Library responsibilities

### 6.1 `common.sh`

Implement:

- Colors with a fallback when output is not a terminal, `NO_COLOR` is set or `TERM=dumb`.
- `log`, `ok`, `warn`, `err`, `info` and `die`.
- `_abspath` for absolute path resolution.
- Pure helpers `path_is_within` and `path_is_forbidden`.

#### Message streams

- `--help` and `--version`: stdout.
- Dry-run plan and final summary: stdout.
- Diagnostics, warnings and errors: stderr.
- Do not emit ANSI codes when the relevant output is not a terminal.

#### `_abspath`

Try, in order:

1. `python3`, if available.
2. `realpath`, if available.
3. A safe manual fallback, without claiming symbolic-link resolution when it is not possible.

Contract:

- Reject empty input.
- Prefix relative paths with `$PWD`.
- Resolve symbolic links in existing components.
- For a nonexistent path, resolve the longest existing prefix and append the normalized suffix;
  never let `..` escape the prefix.
- Return an error when a safe absolute path cannot be determined.
- Handle spaces; reject newline, carriage return and tab.
- Never use `eval`.
- Print the resolved path on stdout, and also set `FORGE_ABSPATH_RESULT` to it and
  `FORGE_ABSPATH_CANONICAL` to `1` only when all existing components were resolved, `0` otherwise.
  Both variables are internal to `preflight`.
- **The two globals only survive a plain call.** A command substitution runs in a subshell, so
  `target=$(_abspath "$path")` yields the path but silently loses `FORGE_ABSPATH_RESULT` and
  `FORGE_ABSPATH_CANONICAL`. Use exactly one of two forms:
  - **(a)** `_abspath "$path"` as a plain statement, then read the globals. Required wherever the
    flag matters, and preflight must use this form.
  - **(b)** `target=$(_abspath "$path")` only when you need the printed path and never read the flag
    afterwards.
  - **Mixing both is the defect:** calling through `$( )` and then reading the flag. It refuses
    every destination with code 3.
- Do not turn an incomplete resolution into a false canonical guarantee. Preflight must require full
  resolution before it decides whether the destination exists.

#### Path helpers

`path_is_within CHILD PARENT` compares normalized absolute paths using component boundaries:

- `CHILD == PARENT` is true.
- `CHILD` starting with `PARENT/` is true.
- `/various` is **not** a child of `/var`.
- `/var/foo` is a child of `/var`.
- For `PARENT=/`, every absolute path is a descendant; therefore `/` in the protection table is an
  **exact** rule, not a subtree rule.

`path_is_forbidden PATH` is pure, testable without writing and uses the table in Section 6.3.2. Path
protection comparisons are case-sensitive on the supported Linux/WSL2 platforms. Do not use case
folding for filesystem operations.

#### `die`

- `die CODE MESSAGE`.
- Print `err MESSAGE` to stderr.
- Exit with `CODE`; use 1 if the code is invalid.
- Do not use `die` inside command substitution when the intent is to terminate the parent process;
  document this.

### 6.2 `args.sh`

Implement:

- CLI defaults.
- `usage` with a short quoted heredoc.
- `parse_args` using a `case` loop.
- Order the `case` branches so `--` is matched before the wildcard branches (`-?*`, `--*`). Behind a
  wildcard the terminator is unreachable, which ShellCheck reports as SC2221/SC2222.
- Validation of required arguments and incompatible combinations.
- Safe `~` expansion.
- Rejection of unknown options, missing values, empty values, positional arguments and multiple
  `--path` occurrences.

Help follows Section 5.5 and must not invent flags or mention Git.

### 6.3 `preflight.sh`

Implement `preflight()` to run, in this order, without writing to the destination:

1. Require Bash 4+ (`BASH_VERSINFO[0] >= 4`).
   - Reject `msys*`, `cygwin*` and `win32*` with code 4; native Windows/Git Bash is not safely
     supported.
2. Check essential dependencies: `find`, `mkdir`, `cp`, `mv`, `mktemp`, `chmod`, `stat`, `sed`,
   `awk`, `grep`, `sort`, `dirname`, `basename`, `readlink`, `sha256sum` or `shasum`. There is no
   `git` dependency.
3. Require `HOME` to be set and absolute; it is used by the protections.
4. Expand the default and supported destination paths; reject `~user` and control characters.
5. Resolve the absolute path with `_abspath`.
6. Validate the parent directory: it must exist, be a directory, be writable and searchable. Do not
   create intermediate parent directories.
7. If the destination exists in any form (empty directory, non-empty directory, file, symlink or
   other type), refuse with code 3. `forge` is create-only.
8. If the destination does not exist, require that the parent exists and the destination is a direct
   child; do not create the parent tree.
9. Compare the canonical destination with the forbidden path table.
10. Reject overlap with `FORGE_HOME`: the destination cannot be equal to, inside, or an ancestor of
    the tool repository.
11. Check the template tree: `FORGE_HOME/templates` exists, is readable, contains the required
    categories and has no symbolic links.

#### 6.3.1 Normalization

- Remove trailing slashes except for `/`.
- Resolve `.` and `..` before comparison.
- Compare canonical paths, not the lexical form supplied by the user.
- Path protection comparisons are case-sensitive (Linux/WSL2).
- Use component boundaries; never use `[[ $path == "$forbidden"* ]]` without the `/` separator.

#### 6.3.2 Forbidden path table

| Path | Rule | Note |
|---|---|---|
| `/` | refuse **exact** | Do not refuse all descendants. |
| `$HOME` | refuse **exact** | Descendants are allowed except the sensitive paths below. |
| `$HOME/.ssh`, `.gnupg`, `.aws`, `.azure`, `.kube`, `.docker`, `.config`, `.local`, `.password-store`, `.terraform.d`, `.npmrc`, `.pypirc`, `.netrc`, `.git-credentials` | refuse equal or descendant | Configuration and credentials. |
| `/usr`, `/etc`, `/bin`, `/sbin`, `/var`, `/boot`, `/dev`, `/sys`, `/proc` | refuse equal or descendant | Canonicalize before comparing. |
| `/root`, `/opt`, `/srv`, `/run` | refuse equal or descendant | Additional safety paths; document them. |
| `/home` | refuse **exact** | Refuse the parent itself; homes follow the other-user rule below. |
| Recognized temporary root | refuse **exact** | See the temporary exception below. |
| Strict descendant of a recognized temporary root | allow | Narrow, documented exception. |

Additional rules:

- Other users' homes: a canonical destination under `/home/` that is not `$HOME` or below it is
  refused.
- The table is minimal and must be documented. Extending it is allowed; reducing it or adding an
  exception requires an explicit code or configuration change, never a generic flag, and no flag
  changes this table.
- Comparisons use canonical paths and component boundaries: `/various` is not a child of `/var`.

#### 6.3.3 Temporary exception

The `/var` rule must not block tests and legitimate temporary directories. Allow a destination when
**all** conditions are true:

1. The destination is a **strict** descendant of a recognized temporary root.
2. The canonical root is one of `/tmp`, `/var/tmp`, or a path under `/var/tmp/`.
3. The destination is not equal to the temporary root.
4. The destination contains no component that is a symbolic link outside the canonical root.
5. The root came from `TMPDIR` (or `/tmp` when unset), was canonicalized and was validated against
   the list above. Do not trust an arbitrary `TMPDIR`.

This exception is not a general `/var` bypass and does not apply to other forbidden paths. Document
it in the README and tests.

#### 6.3.4 Symbolic links

- Refuse an existing destination that is a symbolic link.
- Refuse any symbolic link under `templates/`.
- The destination parent may be a symbolic link (for example `/tmp`) if the canonical parent is
  allowed; do not follow links inside the created tree.
- `make_dir` and `install_file` must refuse existing components that are symbolic links.
- Never use `cp` directly over a destination that may be a symbolic link. Use a temporary file in
  the same directory and `mv`, or refuse.

#### 6.3.5 No writes during preflight

- Preflight **must not** create directories or files.
- In dry-run, preflight still refuses an existing destination with code 3.

### 6.4 `files.sh`

Implement:

- `make_dir`
- `install_file`
- `make_executables`

#### 6.4.1 Destination-exists contract

`forge` is create-only. Before creation begins, preflight guarantees the destination does not exist.
Therefore every managed path must be **absent** when it is about to be created. If `install_file` or
`make_dir` encounters an already-existing path — because of a race or internal ordering error — it
treats that as an internal invariant failure and exits with code 1 (not a silent skip and not a
destructive overwrite).

#### 6.4.2 `make_dir`

- Create a directory only when absent.
- If it exists as a regular directory, treat it as an invariant violation (code 1), because it
  must not exist.
- If it exists as a symbolic link, file or other type, refuse with code 3; do not follow the link.
- Create one level at a time with `mkdir -- "$path"`; do not use `mkdir -p` for the destination
  tree.
- Require the parent to exist and be a regular directory; refuse if the parent path is not canonical
  or contains an unresolved symbolic link.
- In dry-run, do **not** require the parent to exist: it is a directory that this same run
  plans to create, so it is not on disk yet. Validate the parent only in a real run.
- In dry-run, record the planned action with an absolute path; do not create.
- Increment `FORGE_CREATED_DIRS` only when the directory is actually created; in dry-run the counter
  represents planned work.
- The destination root counts in `FORGE_CREATED_DIRS`. The expected total is `FORGE_TOTAL_DIRS=12`,
  including the root. Document and test the difference between "created in this run" and "total in
  the workspace".

#### 6.4.3 `install_file`

Conceptual signature: `install_file SOURCE DEST RELATIVE_PATH`.

- Verify that the source exists, is a regular file, is not a symbolic link, is readable and is
  canonically under `FORGE_HOME/templates`.
- Verify that the destination is canonically under `FORGE_TARGET`.
- Verify that the destination parent exists and is a regular directory; refuse if the parent path is
  not canonical or contains an unresolved symbolic link. In dry-run, skip the existence check for
  the same reason as `make_dir`: the planned parent is not on disk yet.
- Refuse if the destination already exists (create-only): exit with code 1 as an invariant failure,
  because preflight refuses an existing destination.
- Never replace directories with files or files with directories.
- Never remove user extra files.
- Avoid truncating the destination on failure:
  1. Create a temporary file in the destination directory with `mktemp`.
  2. Copy the source to the temporary file with `cp --`.
  3. Set the temporary permission: `644` for a regular file or `755` for a script.
  4. Use `mv -- "$tmp" "$dest"` for an atomic move on the same filesystem.
  5. On failure, remove the temporary file and leave the destination intact.
- Count created files only.
- In dry-run, show the action only; do not create a temporary file in the destination.
- Document the TOCTOU limitation: a local process could change the destination between verification
  and `mv`. For a personal tool this is acceptable when documented; do not claim protection against
  a concurrent local adversary.

#### 6.4.4 `make_executables`

Apply execution permissions only to **destination** files that need them:

- `scripts/backup.sh`
- `scripts/setup.sh`
- `scripts/clean.sh`
- `scripts/doctor.sh`

Rules:

- Do not use indiscriminate `chmod +x`.
- Do not change the tool repository during workspace generation.
- The tool repository must have execution bits set during implementation/finalization for `forge`,
  `tests/run.sh`, `tests/test-*.sh` and `scripts/build-standalone.sh`; `make_executables` does not
  do this during generation.
- Verify that the path exists, is a regular file and is not a symbolic link.
- Ensure `u+rx` on scripts; do not widen existing file permissions beyond that. New script files may
  be `755`. The call must be safe to repeat.
- In dry-run, report planned permission changes without modifying them.
- If an expected script is missing, treat it as a tree verification failure, not silent success.

### 6.5 `tree.sh`

Implement `create_tree()` to create the 12 functional directories:

| # | Directory | README | Own `.gitignore` |
|---:|---|---|---|
| 1 | `.` (root) | `README.md` | no (root `.gitignore` is a template) |
| 2 | `docs/` | `docs/README.md` | no |
| 3 | `docs/adr/` | `docs/adr/README.md` | no |
| 4 | `scripts/` | `scripts/README.md` | no |
| 5 | `data/` | `data/README.md` | **no** |
| 6 | `data/raw/` | `data/raw/README.md` | yes |
| 7 | `data/interim/` | `data/interim/README.md` | yes |
| 8 | `data/processed/` | `data/processed/README.md` | yes |
| 9 | `data/external/` | `data/external/README.md` | yes |
| 10 | `experiments/` | `experiments/README.md` | yes |
| 11 | `projects/` | `projects/README.md` | yes |
| 12 | `infrastructure/` | `infrastructure/README.md` | yes |

That is the complete list. `infrastructure/` has no subdirectories, and the `data/` root itself has
**no** `.gitignore`.

Rules:

- Create parents before children, starting at the root.
- Use `make_dir`, respecting dry-run, validation, types and counters.
- `FORGE_TOTAL_DIRS=12` includes the root. After a real run, verify all 12 directories exist and
  none is a symbolic link; in dry-run, verify only the expected list.

### 6.6 `templates.sh`

Implement:

- `copy_templates()`
- `print_summary()`

#### `copy_templates()`

1. Locate the template root at `FORGE_HOME/templates`.
2. Copy `templates/root/<relative>` to `$TARGET/<relative>`, and `templates/<category>/<relative>`
   to `$TARGET/<category>/<relative>` for the categories `docs`, `scripts`, `data`, `experiments`,
   `projects` and `infrastructure`.
3. Preserve the relative hierarchy and handle file names with spaces safely.
4. Skip `templates/README.md`, which documents the tool, and never copy anything outside the
   template tree.
5. Every destination path must be absent: never overwrite (create-only).

Use `find -print0` with Bash 4-compatible reading. Do not depend on recursive glob expansion. Keep
counters in the current shell; do not use a pipeline that runs the loop in a subshell. A valid
approach is `while ... done < <(find ... -print0 && printf 'find-done\0')`, checking a completion
marker for `find` failure. The marker **must** end with a NUL byte: the loop reads records with
`read -d ''`, so a marker without the trailing NUL makes the final `read` return status 1 and the
marker is never seen. The loop does not abort under `set -e`, so the symptom is a completion check
that reports a failed `find` while every file was copied. Alternatively, use a NUL-separated list
file in a temporary directory, documented and safely removed; do not write that temporary file in
the destination.

Rules:

- `find` must use `-type f` and must not follow symbolic links. Preflight already rejects links
  under `templates/`.
- Check `find` and each copy for errors.
- Reject a source path outside `FORGE_HOME/templates` after canonicalization.
- Reject names with newline, carriage return or tab; spaces are allowed.
- Verify required categories and files before copying.
- In dry-run, do not create directories, copy files, create destination temporaries or write state.
- After a real copy, verify the 12 directories, 12 READMEs and required file list. If something is
  missing, fail with code 5 and report the missing path.

#### `print_summary()`

Print to stdout:

- Absolute workspace path.
- `FORGE_TOTAL_DIRS=12` and directories created in this run.
- Files created.
- Whether the run was a simulation.
- The limitations listed in Section 9.4, and which of the four scripts to adapt first.

Counter semantics:

- `FORGE_CREATED_DIRS`: created in this run; planned in dry-run.
- `FORGE_CREATED_FILES`: files installed in this run; planned in dry-run.
- `FORGE_TOTAL_DIRS`: fixed at 12, reported as informational context, never written into a README.
- `FORGE_TOTAL_FILES`: derived from the template tree at runtime.

---

## 7. Installable templates

### 7.1 `templates/root/`

Must contain:

- `README.md`
- `justfile`
- `.gitignore`
- `.editorconfig`
- `.env.example`

The five files above are the **only** files installed directly into the generated workspace root.
The seven per-directory `.gitignore` files (`experiments/`, `projects/`, `infrastructure/`,
`data/raw/`, `data/interim/`, `data/processed/`, `data/external/`) are separate templates defined in
Section 7.9; they are not part of `templates/root/` and must not be listed or emitted here.

The generated root `README.md` follows the standard in Section 8 and uses the H1 `# 📁 workspace/`.
It explains the directory layout and the separation between projects, experiments, data and
infrastructure, but it must not write a number such as "12 directories", because Section 8 forbids
counts in READMEs.

The root `justfile` must contain exactly four recipes — `backup`, `setup`, `clean`, `doctor` — plus
a `default` recipe that lists them. Each of the four recipes is a one-line delegator with no
argument validation and no logic:

```just
set shell := ["bash", "-uc"]
set positional-arguments := true

default:
    @just --list

backup *args:
    @bash scripts/backup.sh "$@"

setup *args:
    @bash scripts/setup.sh "$@"

clean *args:
    @bash scripts/clean.sh "$@"

doctor *args:
    @bash scripts/doctor.sh "$@"
```

Rules:

- `set shell := ["bash", "-uc"]` and `set positional-arguments := true`. Both settings matter: with
  `{{args}}` a path containing a space would be split into separate arguments, while
  `positional-arguments` plus `"$@"` delivers it intact.
- Recipes forward all arguments verbatim through `"$@"`; they **never** validate arguments, never
  reject names or paths, and never contain logic.
- Recipes do not install dependencies, use Git, access the network, or provide destructive cleanup
  beyond what the script itself does.
- No recipe performs any argument validation; that responsibility belongs entirely to the target
  script.

The root `.gitignore` below is declarative configuration, not code: `forge` only copies it as a
file, so it does not execute, takes no input and has no side effects. Its rules matter only after
the user creates a Git repository. It must use a minimal, portable policy:

```gitignore
# Secrets and local environment
.env
.env.*
!.env.example
*.key
*.pem
*.p12
*.pfx

# Python
__pycache__/
*.py[cod]
.venv/
venv/
.pytest_cache/

# Operating system and editors
.DS_Store
*.swp
*.swo
*~
```

The root `.gitignore` must **not** contain `data/raw/*`, `data/interim/*`, `data/processed/*`,
`data/external/*`, `experiments/*/outputs/*` or any similar nested pattern. Each of those
directories ships its own `.gitignore` (Section 7.9), and duplicating the rules at the root would
contradict that rule. The root file handles secrets, Python caches and editor noise only.

The `.editorconfig` must use UTF-8, LF, final newline, trailing-whitespace removal and consistent
indentation:

- two spaces by default;
- four spaces for `*.sh`;
- tabs for `Makefile` and `*.mk`;
- do not apply the Makefile rule to all build files.

The `.env.example` must contain only illustrative variables without real credentials:

```dotenv
# Example. Replace the values; do not use real credentials.
APP_ENV=development
API_BASE_URL=http://localhost:8080
API_TOKEN=replace-me
DATABASE_URL=postgresql://user:change-me@localhost:5432/db
```

The `.env.example` is a reference document only; no script reads, creates or validates a real
`.env`.

### 7.2 `templates/docs/`

Must contain:

- `README.md`
- `adr/README.md`
- `adr/0001-workspace-structure.md`

The ADR explains the structure, separation of responsibilities, project autonomy and versioning
policy. `adr/README.md` opens by explaining in one sentence what an Architecture Decision Record is,
because the abbreviation `ADR` appears in the other READMEs. Neither file may mention Git or
attribute tests or results that do not exist.

### 7.3 `templates/scripts/`

Must contain:

- `README.md`
- `backup.sh`
- `setup.sh`
- `clean.sh`
- `doctor.sh`

The `README.md` documents the shared contract, the list of stub functions per script, and the
instruction to adapt the scripts to the workspace's specific use.

#### Shared contract for all four scripts

Every script:

- starts with `#!/usr/bin/env bash` and applies `set -Eeuo pipefail`.
- has a commented header block stating its purpose, usage, accepted arguments, and a reminder to
  "edit this script to match this workspace".
- defines a `not_implemented` function that prints `not implemented: <stage>` to stderr and exits 1.
- accepts `--help` and exits 0 without creating anything.
- has a small argument-parsing entry block that delegates to named stage functions.
- installs no packages, changes no global configuration, starts no services, and uses no network.
- is shipped as a skeleton: each unimplemented stage contains **only** a descriptive comment plus a
  call to `not_implemented "<stage>"`.

#### `setup.sh`

Contains a single stage function `execute_setup`, which is a stub:

```bash
execute_setup() {
  # Create the workspace prerequisites the user decides this workspace needs.
  not_implemented "execute_setup"
}
```

- There is **no** `check_prerequisites`, `install_dependencies` or `run_dry_run` function.
- The script is built on top of `execute_setup`: parse arguments (`--help` handled inline), then
  call `execute_setup`.
- `setup.sh` contains nothing related to `.env` (it never reads, creates or validates `.env` or
  `.env.example`).

#### `backup.sh`

Defines exactly four stage stubs:

```bash
assert_output_outside_workspace() {
  # Guarantee the output directory is not inside the archived tree, including through a symbolic link.
  not_implemented "assert_output_outside_workspace"
}

build_excludes() {
  # Assemble the exclude list (secrets, operational files, caches, outputs).
  not_implemented "build_excludes"
}

run_dry_run() {
  # Print the command and planned archive path; create nothing.
  not_implemented "run_dry_run"
}

create_backup() {
  # Create the archive readable and writable only by its owner (mode 600); refuse to overwrite an existing backup.
  not_implemented "create_backup"
}
```

- `data/` is excluded by default; there is no opt-in flag.
- The intended interface accepts `--output DIR` and `--dry-run`; these are parsed by the entry block
  (a stub for now, but the option set is fixed and must not grow).
- Backup is **never** run during workspace generation; the user runs it later after fleshing out the
  stubs.

#### `clean.sh`

A full skeleton, not limited to artifacts inside the generated workspace:

```bash
clean() {
  # Perform whatever cleaning process this workspace requires —
  # including external/generated artifacts, not only files inside the workspace.
  not_implemented "clean"
}
```

- `clean.sh` may clean anything the workspace's specific use requires; the scope is intentionally
  open and is decided by the user.
- No destructive action is pre-implemented; the removal stage is a stub.

#### `doctor.sh`

A full skeleton with named stage stubs:

```bash
check_tools() {
  # Verify required tools are available without installing anything.
  not_implemented "check_tools"
}

check_structure() {
  # Verify the expected directories and files exist.
  not_implemented "check_structure"
}

check_permissions() {
  # Verify scripts are executable and files have safe permissions.
  not_implemented "check_permissions"
}
```

- The entry block (with `--help`) calls the three stages in order.

### 7.4 `templates/data/`

Must contain:

- `README.md` (for the `data/` root itself)
- `raw/README.md` and `raw/.gitignore`
- `interim/README.md` and `interim/.gitignore`
- `processed/README.md` and `processed/.gitignore`
- `external/README.md` and `external/.gitignore`

The four `.gitignore` files use the exact content defined in Section 7.9. The `data/` root gets
**no** `.gitignore`.

The root `README.md` documents the four stages and states that each stage directory is
self-contained and ready to become its own repository. For each stage, answer these questions in
plain words, naming the technical term next to its explanation:

- Where did the data come from, who provided it, and under which terms (provenance)?
- May the files be edited in place, or must a corrected copy be added (immutability)?
- How is each file produced or updated (transformation and regeneration)?
- How can a reader tell that a file is unchanged (integrity: a checksum is a short fingerprint of
  the file; a schema or a version record also helps)?

Do not create fictional data as if it were real. If examples are necessary, identify them clearly as
fictional and keep them out of `raw/` as production data.

### 7.5 `templates/experiments/`

Must contain exactly:

- `README.md`
- `.gitignore` (Section 7.9)

The README explains how experiments are organized under `experiments/`, how to create a new
experiment directory manually, and that each experiment may become its own Git repository, which is
why the directory ships a `.gitignore` that ignores its contents except the README and the
`.gitignore` itself.

### 7.6 `templates/projects/`

Must contain exactly:

- `README.md`
- `.gitignore` (Section 7.9)

The README explains how projects are organized under `projects/`, how to create a new project
directory manually, and that each project is expected to become an independent Git repository.

### 7.7 `templates/infrastructure/`

Must contain exactly:

- `README.md`
- `.gitignore` (Section 7.9)

There are no subdirectories (`configs/`, `docs/`, `manifests/`, `recipes/`, `scripts/`, `stacks/`,
`reports/`). The README describes the conceptual areas (configuration, manifests, recipes, scripts,
stacks, documentation, reports), states that the user creates those directories on demand, and gives
each area a few plain words: a manifest declares what to deploy, a recipe is a recorded sequence of
operations, and a stack is a set of components that run together. The generator never creates
sub-repositories by default; the shipped `.gitignore` exists so the directory is ready to become
one.

### 7.8 `templates/README.md`

This file documents `workspace-forge` and **must not** be installed.

Explain:

- the mapping between template tree and generated tree;
- how to add or change a template;
- how to verify links and paths;
- how to run tests;
- when to update documentation, tests and changelog;
- that the managed set is derived from the tree, not from a static manifest.

### 7.9 Per-directory `.gitignore` files (nested independent repositories)

Seven generated directories are designed to host **independent Git repositories created by the user
later**: `experiments/`, `projects/`, `infrastructure/`, `data/raw/`, `data/interim/`,
`data/processed/` and `data/external/`.

For that to work, the surrounding workspace must ignore everything these directories contain, while
still versioning the directory's own `README.md` and `.gitignore`. The generator therefore installs
one `.gitignore` inside each of those seven directories from the corresponding template category:

- `templates/experiments/.gitignore`
- `templates/projects/.gitignore`
- `templates/infrastructure/.gitignore`
- `templates/data/raw/.gitignore`
- `templates/data/interim/.gitignore`
- `templates/data/processed/.gitignore`
- `templates/data/external/.gitignore`

Each of these seven files has **exactly** this content, byte for byte, with a trailing newline:

```gitignore
/*
!/README.md
!.gitignore
```

Meaning: ignore every entry inside this directory, then re-include the `README.md` and the
`.gitignore` itself. Anything the user later places here — project sources, experiment outputs,
dataset files, infrastructure manifests — stays out of the outer workspace repository, so each such
directory can become its own repository without polluting the parent.

Rules:

- These files carry **no comments and no extra patterns**. The three lines above are the complete
  content.
- They are ordinary installable templates: they flow through the same
  `templates/<category>/<relative>` mapping as every other file and are counted by
  `FORGE_CREATED_FILES` and `FORGE_TOTAL_FILES`.
- The `data/` root gets **no** `.gitignore` of its own. `data/` only contains its `README.md` and
  the four subdirectories; the ignore rules are in the four subdirectories.
- The root `.gitignore` must not repeat these rules (Section 7.1).
- After a real run, `_verify_tree` may assert that all seven files exist; it must not assert
  anything about their content beyond existence and non-emptiness.
- No test may invoke `git check-ignore` or any other Git command. Existence and content are asserted
  by reading the files directly.

`experiments/`, `projects/` and `infrastructure/` contain **only** `README.md` and `.gitignore`
after generation. The user creates their subdirectories and initializes their repositories manually
afterwards; the generator never creates them and never runs Git.

---

## 8. Required README standard

All 12 READMEs in the generated workspace (one per directory, listed in Section 6.5) must follow the
same order. The block below is the required shape in Markdown, not text to copy literally: replace
every placeholder with directory-specific content.

```markdown
# 📁 directory-name/

> One-sentence description of the directory and why it exists.

---

## 📋 Purpose

Explain the responsibility and limits of the directory.

## 📁 Structure

Show the real structure in a code block.

## ✅ Rules

- **Short term** — objective description.

## 🚫 Out of scope

- Content that does not belong here and its correct destination.

## 🔗 See also

- [Related document](relative/path.md)
```

Rules:

- H1 uses an emoji and the directory basename ending in `/`; the root uses `workspace/`.
- Tagline in a blockquote, one sentence explaining what the directory is and why it exists.
- Horizontal rule after the tagline.
- Section order: `## 📋 Purpose`, `## 📁 Structure`, `## ✅ Rules`, `## 🚫 Out of scope`, `## 🔗 See
  also`.
- There is no `## 💡 How to use` section anywhere in the generated READMEs.
- Purpose has one or two paragraphs.
- Structure blocks match the real files. Do not document nonexistent files as present.
- Rules use bullets in the form `- **Short term** — description`, with U+2014 EM DASH as the separator. A hyphen or an en dash is a defect.
- Out of scope names the correct destination for each item.
- Links are relative and valid; do not use absolute links for workspace files.
- Emojis appear only in headings and subtitles, not in body text.
- Content is specific to each directory, without repeated generic text.
- Write for a reader who is not a specialist in this domain. The first time a technical term appears
  (`checksum`, `manifest`, `recipe`, `stack`, `idempotent`, `symbolic link`, `ADR`), explain it in
  the same sentence in plain words; otherwise use the everyday word. A term explained in one
  directory is not explained for the others.
- READMEs must not state directory or file counts.
- READMEs must not claim that the generator uses Git or that the workspace contains a `.git`
  directory or commits.
- The exception is the "independent repository" note required in Section 7.9: the seven nested
  READMEs must state that the directory can become its own Git repository. That sentence describes
  an action the **user** performs later; it must not describe Git as something `forge` does.
- In `experiments/`, `projects/`, `infrastructure/` and the four `data/` stage directories
  (`data/raw/`, `data/interim/`, `data/processed/`, `data/external/`), the Structure block must show
  exactly the two files that exist at generation time: `README.md` and `.gitignore`. These seven
  READMEs must not depict sample subdirectories, placeholder projects or example experiments,
  because the directory starts empty apart from those two files (Section 7.9).
- The `data/` README (`data/README.md`) documents the four stage directories and may name them in
  its `## 📁 Structure` block; it must not claim that `data/` itself ships a `.gitignore`, because it
  does not.
- A README may describe the role a directory will play once the user adds content, but must not
  describe that content as already present.

---

## 9. Security, create-only behavior and dry-run

### 9.1 Create-only semantics

- A destination that already exists (including an empty directory) is always refused with code 3.
- A refusal writes nothing: no directory, no file, no permission change.
- A successful run creates every managed path exactly once, in a destination that was absent at the
  start.
- Extra files cannot exist at the start of a successful run; the tool never deletes anything.

### 9.2 Dry-run

`--dry-run` plans without writing: it prints absolute paths for every directory and file it would
create, changes no permissions and creates nothing inside or outside the destination. It still
refuses an existing destination with code 3, because the destination must not exist even for
planning.

Counters printed during `--dry-run` are **simulated**: they report what would be created, not what
exists on disk. Never report a dry-run count as proof that files were created, and never compare a
dry-run count with a real-run count as if both measured the same thing.

Temporary resources outside the destination are allowed only when strictly necessary for an isolated
verification, documented and safely removed. A normal dry-run does not need them; if a temporary
list file is used, it must be outside the destination, private and removed with a guard.

### 9.3 Error handling

- Use `set -Eeuo pipefail` in `forge` and tests; do not change shell options inside libraries.
- Preserve meaningful exit codes.
- Do not silence copy, validation or creation failures.
- Do not use `|| true` to hide unexpected failures.
- If a partial operation fails, report what was done and what was not.
- Do not attempt destructive automatic cleanup to undo a partial failure.
- Do not leave a truncated destination file when a copy fails.
- On partial failure, print a partial summary with counters and paths already created.

### 9.4 Documented limitations

Document at least:

- TOCTOU between verification and writing; the tool is not a security boundary against a concurrent
  local adversary.
- Native Windows and Git Bash are unsupported; preflight refuses MSYS/Cygwin and recommends WSL.
  Tests on a Windows host are not evidence of compatibility.
- WSL2 is the supported Windows path.
- The generator performs no Git operations, so the generated workspace has no `.git` and no commit;
  the user manages their own version control manually.
- macOS is not supported.
- The supported baseline is Ubuntu 24.04 LTS or newer; other Linux distributions are untested.

### 9.5 Inspecting what will be generated

Three checks are enough, and none of them adds a flag: the option set in Section 5.1 is closed.

1. **Plan only.** `./forge --dry-run -p DIR` prints every directory and file it would create, plus
   the summary, and writes nothing (Section 9.2). It shows paths, never file contents.

2. **Read the source.** The exact bytes that will be installed already exist under `templates/`.
   `templates/root/<relative>` maps to the destination root and `templates/<category>/<relative>`
   maps to `<category>/<relative>` (Section 6.6); `templates/README.md` is never installed.
   Reviewing those files is reviewing the generated content.

3. **Generate into a throwaway directory and compare.**

```bash
base=$(mktemp -d)
./forge -p "$base/workspace"
find "$base/workspace" -type f | sort
diff -r -- "$base/workspace" /path/to/previous/workspace
```

`mktemp -d` creates a new temporary parent, `forge -p` fills `$base/workspace`, `find` lists what
was produced, and `diff -r` reports whether an existing workspace differs. Replace the last path
with a workspace you already have, or drop that line. Leave `$base` in place: the operating system
cleans `/tmp`, and deleting it is not part of this check.

Because generation is create-only, a second run against the same path is refused with code 3. Always
use a fresh directory.

Rules:

- Do not add `--list`, `--preview` or any other inspection flag.
- Do not make `--dry-run` print file contents.
- Do not write into an existing destination to inspect it.

---

## 10. Automated tests

Implement nine executable tests plus shared utilities.

Executable tests:

1. `tests/test-args.sh` — parsing, help, version and usage errors.
2. `tests/test-common.sh` — `_abspath`, path boundaries, prohibitions.
3. `tests/test-content.sh` — README content, counts and required files.
4. `tests/test-dryrun.sh` — dry-run performs no writes.
5. `tests/test-existing-destination.sh` — create-only refusal.
6. `tests/test-preflight.sh` — path protections, symlinks, unsupported platform.
7. `tests/test-scripts.sh` — scripts exist, are executable, and pass `bash -n`.
8. `tests/test-scripts-behavior.sh` — `--help`, stub behavior and justfile forwarding.
9. `tests/test-standalone.sh` — build, checksum and bundle execution.

Shared utilities:

- `tests/lib.sh` — shared helpers, not an executable test.
- `tests/run.sh` — the test runner.

All tests must:

- Use `mktemp -d` for isolation.
- Register and clean their own temporary directories with a `trap`.
- Validate the absolute temporary prefix before any recursive deletion; never delete arbitrary
  directories.
- Isolate `HOME` and `XDG_CONFIG_HOME`.
- Not depend on the real personal workspace.
- Never modify the tool repository. A test that needs build output or a working copy creates it
  under `mktemp -d`.
- Check exit codes and content, not only messages.
- Never end a test, a function or a loop body with `[[ ... ]] && command`. Under `set -e` a false
  condition becomes the exit status of that function or test, so a passing check fails the run. Write
  `if ...; then ...; fi` instead.
- Fail with messages that identify the problem.
- Use `LC_ALL=C` for sorting and byte comparisons.
- Use `stat -c`/`stat -f` and `sha256sum`/`shasum -a 256` with explicit fallback; fail clearly if
  neither is available.
- Never install tools. The suite needs ShellCheck and `just` and nothing else; the validation
  container and CI install exactly those (Sections 13.1 and 14.3). A test that needs a tool which is
  missing fails with a clear message; it never skips silently. Every document that lists the suite
  dependencies names exactly these two - no third tool, and no tool the suite does not use.
- Never call Git; the generator is Git-free.

### 10.1 `tests/run.sh`

- Require Bash 4+.
- Find only regular files under `tests/` matching `test-*.sh`.
- Sort with `LC_ALL=C sort`.
- Run each test with `bash`.
- Print status per test.
- Continue after an individual failure unless the test infrastructure is unusable.
- Return non-zero if any test fails.
- Return an error if no tests are found.
- Avoid running `run.sh` recursively.
- Do not use `eval`.

### 10.2 `tests/test-dryrun.sh`

Verify that `forge --dry-run -p DEST` does not create the destination when absent, and writes
nothing.

Also verify:

- No files are written to the destination or its parent.
- Output includes the absolute path and planned operations.
- The process exits 0 for a valid simulation with an absent destination.
- With an **existing** destination (including an empty one), `--dry-run` exits 3 and writes nothing.

### 10.3 `tests/test-existing-destination.sh`

Verify the create-only contract:

- An existing empty directory is refused with code 3 (both real and `--dry-run`).
- An existing non-empty directory is refused with code 3.
- An existing regular file at the destination is refused with code 3.
- An existing symbolic link at the destination is refused with code 3.
- Nothing is written into any existing destination in any of these cases.

### 10.4 `tests/test-content.sh`

Verify all 12 READMEs (one per directory, Section 6.5), including the root README.

For each README, validate:

- Existence and non-empty content.
- Correct title: root `# 📁 workspace/`; others `# 📁 <basename>/`.
- Presence and order of the five required sections:
  - `## 📋 Purpose`
  - `## 📁 Structure`
  - `## ✅ Rules`
  - `## 🚫 Out of scope`
  - `## 🔗 See also`
- Absence of `## 💡 How to use` in every README.
- Relative links exist when they point to files that must be generated.
- Every rule bullet separates term and description with U+2014 EM DASH; a hyphen or an en dash fails
  the check.
- Tagline in a blockquote and a horizontal rule after the tagline.
- Total README count is 12 and total directory count is 12, matching the table in Section 6.5.
- No README contains a directory or file count.
- No README claims that `forge` uses Git, or that the workspace ships a `.git` directory or commits.
  The seven nested READMEs **are** allowed to say the directory can become an independent Git
  repository (Section 7.9); do not fail them for that.
- Required files exist: `justfile`, `.gitignore`, `.editorconfig`, `.env.example`, the ADR, and the
  four scripts.
- No symbolic links in the generated tree.

Also verify the seven per-directory `.gitignore` files (Section 7.9):

- Each of `experiments/.gitignore`, `projects/.gitignore`, `infrastructure/.gitignore`,
  `data/raw/.gitignore`, `data/interim/.gitignore`, `data/processed/.gitignore` and
  `data/external/.gitignore` exists and is a regular file.
- Each has exactly the three expected lines in order — `/*`, `!/README.md`, `!.gitignore` — with no
  comments and no extra patterns.
- Each ends with a trailing newline.
- `data/.gitignore` does **not** exist; the `data/` root has no `.gitignore`.
- The root `.gitignore` contains none of `data/raw/*`, `data/interim/*`, `data/processed/*`,
  `data/external/*` or `experiments/*/outputs/*`.
- `experiments/`, `projects/` and `infrastructure/` contain exactly two entries each — `README.md`
  and `.gitignore` — and no subdirectories.

Assert these by reading the files directly. Do **not** invoke `git`, `git check-ignore` or any Git
command.

Use portable tools such as `find` instead of depending on `**` and recursive shell globs.

### 10.5 `tests/test-preflight.sh`

Verify that the tool refuses:

- The personal home directory directly.
- The root `/`.
- Forbidden critical paths.
- Invalid or unresolvable paths.
- A destination that is a symbolic link.
- A destination inside the tool repository or an ancestor of it.
- A destination with a nonexistent parent.
- `~user` and control characters.
- Native Windows/Git Bash (`OSTYPE=msys*`), with code 4.
- An existing destination (empty or otherwise), with code 3.

It also verifies the accepted side, which the refusal list alone cannot cover: a destination under a
symbolic-link parent is accepted (the parent may be a link; only the destination itself may not be),
and a non-canonical path such as `<tmp>/existing/../name` is normalized and accepted.

Use the shared `assert_refused` helper from `tests/lib.sh` instead of repeating the pattern, and do
not repeat the `path_is_within` / `path_is_forbidden` assertions here: Section 10.9 assigns them to
`test-common.sh`. Usage errors such as unknown options, missing values and positional arguments
are covered by `test-args.sh` (Section 10.9), not by this file.

Then verify the opposite direction, which is the regression test for a lost `_abspath` flag:

- A valid destination under an isolated `HOME` is accepted: `forge --dry-run -p "$HOME/workspace"`
  exits 0. If `_abspath` loses `FORGE_ABSPATH_CANONICAL`, this case fails with code 3.

Verify component boundaries:

- `path_is_within "/various" "/var"` is false.
- `path_is_within "/var/foo" "/var"` is true.
- `path_is_within "/var" "/var"` is true.
- `path_is_forbidden "/"` is true.
- `path_is_forbidden "/various"` is false.
- `path_is_forbidden "/srv"` is true.
- `path_is_forbidden "/home/other"` is true when `$HOME` differs from `/home/other`.
- `path_is_forbidden "$HOME"` is true.
- `path_is_forbidden "$HOME/workspace"` is false with `HOME` isolated in a temporary directory not
  under a forbidden path.
- `path_is_forbidden "$HOME/.ssh"` is true.

Do not write to these destinations during the test. Use `--dry-run` to ensure refusal occurs before
modification. Verify that the tool refuses and that the paths remain unchanged.

### 10.6 `tests/test-scripts.sh`

Verify the generated `scripts/` contract:

- `backup.sh`, `setup.sh`, `clean.sh` and `doctor.sh` exist, are regular files, are executable, and
  pass `bash -n`.
- Each script's `--help` exits 0 and creates nothing.
- No script contains `.env` logic (no read, create or validate of `.env` or `.env.example`).
- `setup.sh` contains `execute_setup` and no `check_prerequisites`, `install_dependencies` or
  `run_dry_run`.
- `backup.sh` contains the four stubs `assert_output_outside_workspace`, `build_excludes`,
  `run_dry_run` and `create_backup`.

### 10.7 `tests/test-scripts-behavior.sh`

Verify runtime behavior of the four scripts:

- Each stage stub prints `not implemented: <stage>` to stderr and exits 1 when invoked directly.
- `backup.sh` without `--output` exits non-zero (argument validation is in the script, not the
  justfile).
- Every one of the four scripts rejects an unknown option with exit code 2, not only `backup.sh`.
- The root `justfile` recipes `backup`, `setup`, `clean`, `doctor` forward arguments verbatim and
  contain no argument validation or logic (assert the recipe bodies are single `bash scripts/<x>.sh
  "$@"` delegators using positional arguments).
- The justfile is **executed**, because `just` is a required dependency of this environment. In a
  generated workspace verify that `just --list` and `just` list the four recipes and exit 0; that
  `just <tool> --help` exits 0 for all four; that `just backup` without arguments exits 2; that
  `just backup --unknown` and `just backup --output` without a value exit 2; that `just backup
  --output DIR` and `just doctor` exit 1 with `not implemented:` on stderr; and that a path
  containing a space reaches the script as a single argument.
- The repository's own `justfile` is verified without side effects with `just --dry-run` on `test`,
  `lint`, `build`, `install`, `uninstall` and `release`. Never execute `install`, `uninstall`,
  `release` or `test` for real.

The four generation-time scripts are skeletons; behavioral coverage is limited to `--help`, stub
exit behavior and argument handling that is already implemented. Document what cannot be verified
until the user fills in the stubs.

### 10.8 `tests/test-standalone.sh`

Build the standalone artifact in a private copy of the repository, so the test never writes `dist/`
into the repository itself, and verify:

- `dist/workspace-forge-<version>/` contains `forge`, `lib/` (six libraries) and `templates/`.
- The `.tar.gz` and `.tar.gz.sha256` are produced.
- The extracted bundle passes `--version`, `--help` and a real generation in a temporary directory
  outside the original tree.

### 10.9 `tests/test-args.sh` and `tests/test-common.sh`

`test-args.sh` covers the whole user-facing CLI, not only the happy path:

- `--version` and `-v` print exactly `forge <version>` and exit 0; `--help` and `-h` exit 0 and
  document the options, the create-only rule, the protections and the exit codes.
- Help wins over version, and version exits 0 before preflight.
- `-n` works alone and with `-p`; `--path=PATH` and `--path PATH` both work; a path with spaces
  survives intact.
- These are usage errors with code 2: unknown long option, unknown short option, attached short
  value (`-pDIR`), clustered short options (`-nh`), missing value, empty value, repeated `--path`,
  positional argument, argument after `--`, `~user`, a tab and a newline in the path.
- `~` alone expands to `HOME`, which is itself a forbidden destination, so it exits 3.
- A destination with a trailing slash is accepted, and the plan still writes nothing.
- On success the plan goes to stdout and no diagnostic label leaks into it.
- `forge` runs through a symbolic link and from a directory whose name contains spaces.

`test-common.sh` covers the pure helpers: `_abspath` (normalization, symbolic links, spaces,
relative input, empty input, control characters) and `path_is_within` / `path_is_forbidden`
component boundaries, including the temporary-root exception. Use the exact pairs from Section 6.3.2
(`/various` is not inside `/var`; `/var/x` is); do not invent new paths for this assertion.

---

## 11. Repository documentation

Each fact is stated in exactly one document. A document that needs a fact stated elsewhere summarizes
it in one sentence and links to it; it never repeats the list, table or procedure. The documents:

- `README.md` - orientation: what the tool is, requirements, quick start, the option table,
  limitations.
- `docs/usage.md` - the user manual: installation, destination rules, the exhaustive protected-path
  list, exit codes, worked examples, inspection, and what to do after generating.
- `docs/architecture.md` - internals: the executable, the six libraries, the execution flow,
  invariants and the reasoning behind them.
- `docs/contributing.md` - maintenance: template workflow, tree alignment, tests, lint, changelog,
  review.
- `docs/adr/*` - one decision per file: status, context, decision, consequences.

Write for a human: short sentences, one idea per paragraph, a table or numbered list for any
enumeration, and every example runnable exactly as written. Delete any section that only restates
another document.

### 11.1 `README.md`

Cover, in this order: what `workspace-forge` is; the difference between the tool repository and the
generated workspace; requirements and compatibility; how to run it from a checkout and how to
install it; the option table; one sentence each for the create-only rule, the safety rules and the
Git-free generator, each linking to the document that states it; a short architecture summary; how to
run tests and lint; and the platform and concurrency limitations.

End the README with a License section: MIT, a link to `LICENSE`, and the author and contact below.

Document only the options and behavior specified here; do not invent flags or removed features.

### 11.2 `CHANGELOG.md`

Follow Keep a Changelog and SemVer, with:

- `[Unreleased]`
- `[0.1.0]`

The initial version describes only implemented and verified features. Do not declare published
releases. If using a date, state clearly that the version was not published.

### 11.3 `LICENSE`

Use the MIT license and this exact copyright line:

```text
Copyright (c) 2026 Thiago Soares <thiagosilvaandradesoares@gmail.com>
```

The author is Thiago Soares and the contact is thiagosilvaandradesoares@gmail.com. Do not invent any
other legal name, email or organization, and do not add a second copyright holder.

### 11.4 `docs/architecture.md`

Describe the executable, the six libraries and their responsibilities, the templates, the execution
flow, the safety invariants, the template-to-workspace mapping, why templates are separate from
code, and why the generator is Git-free. The exhaustive protected-path list is in
`docs/usage.md`; link to it instead of repeating it.

Expected flow:

`parse_args → preflight → create_tree → copy_templates → make_executables → print_summary`

Explain the conditions and shortcuts of this flow, including help, version, dry-run and preflight
errors.

### 11.5 `docs/usage.md`

This is the user manual, and it states the exhaustive lists: installation, destination rules, the
protected-path list, the exit-code table, worked examples for `./forge`, `./forge -p ~/lab`,
`./forge --dry-run`, `./forge --help` and `./forge --version`, how to inspect a generation, and what
to do after generating.

The examples must match the real semantics and state three risks: `./forge` targets
`$HOME/workspace` (so run `--dry-run` first), the destination must not already exist, and WSL2 is
the supported Windows environment.

### 11.6 `docs/contributing.md`

Document how to add or change a template, how to keep the template tree and the 12-directory
structure (Section 6.5) aligned, how to run tests and lint, how to update the changelog, how to
review security and portability, and how to prepare a contribution.

### 11.7 Repository ADRs

Create three ADRs:

- `docs/adr/0001-why-forge.md`: Bash standalone versus tools such as Cookiecutter or Copier.
- `docs/adr/0002-external-templates.md`: external templates instead of giant heredocs.
- `docs/adr/0003-standalone-vs-modular.md`: modular development and standalone distribution.

Each ADR contains context, decision and consequences. Record real project decisions; do not
attribute nonexistent tests or results.

---

## 12. Development configuration

### 12.1 `justfile`

All recipes must use valid `just` syntax.

Include:

- `default`: list recipes with `just --list`.
- `test`: run `bash tests/run.sh`.
- `lint`: run ShellCheck on `forge`, `lib/*.sh`, `scripts/*.sh` and `tests/*.sh`; fail if ShellCheck
  is unavailable, without installing it.
- `build`: run `bash scripts/build-standalone.sh`.
- `install`: install a symbolic link at `~/.local/bin/forge`.
- `uninstall`: remove only the link owned by the installation, never a regular file.
- `release`: validate version and repository state, and prepare the local semantic tag.

Note: this tool-repository `justfile` is for developing `workspace-forge` itself and is **not** the
generated workspace's `justfile`. The generated justfile (Section 7.1) only forwards to the four
scripts.

The `install` recipe must:

- verify the source executable and resolve the real repository path;
- create `~/.local/bin` only when needed, and refuse if `~/.local` or `~/.local/bin` is a symbolic
  link;
- never replace a regular file or a link owned by another program: refuse and tell the user;
- leave `PATH` unchanged and explain how to add `~/.local/bin` to it.

Uninstallation must verify the link target before removal; never remove a regular file.

The `release` recipe must not publish a release or push tags without explicit authorization. Check
for an existing tag and refuse to overwrite it. Document that the user must authorize remote
operations separately. It may create a local tag, but must state that it was not pushed.

### 12.2 `.gitignore`

This is the **tool repository** ignore file, not the generated workspace one (Section 7.1) and not
the seven nested ones (Section 7.9). It is declarative configuration, not code: nothing in it
executes. Ignore only:

```gitignore
dist/
.DS_Store
*.swp
*.bak
*.tmp
```

Add other exclusions only when truly necessary and documented. Do not ignore code, templates, tests,
documentation or required workflows.

### 12.3 `.editorconfig`

Set `root = true`, UTF-8, LF, final newline, trailing-whitespace removal, two spaces by default,
four spaces for `*.sh`, and tabs for `Makefile` and `*.mk`. Do not apply the Makefile rule to all
build files.

### 12.4 `.shellcheckrc`

Configure:

```text
shell=bash
disable=SC1090,SC1091
```

#### Known ShellCheck findings

This design reliably triggers four findings. Each has a correct fix; none is a reason to widen
`.shellcheckrc`:

- `SC2034` for a `FORGE_*` value written in one library and read in another: `export` it, or annotate
  only the line that writes it, never the whole file.
- `SC2088` for a literal `~` in a pattern: compare through a variable (`tilde='~'`), not a quoted
  literal.
- `SC1124` for a `# shellcheck disable=` directive placed inside a `case` body: move the directive
  above the construct.
- An unused loop variable: remove the variable; do not silence the warning.

Disable these warnings only because the project uses dynamically sourced libraries. Do not globally
disable other checks to hide errors. Include comments explaining the justification and verify that
the installed ShellCheck version accepts the configuration. The block above is a declarative
configuration file, not code: ShellCheck reads it when linting, and it changes no files.

---

## 13. CI and releases

### 13.1 `.github/workflows/ci.yml`

Run on `push` and `pull_request` with a single Ubuntu runner.

The workflow lives one level above the prompt's directory, at
`$PROMPT_DIR/../.github/workflows/ci.yml` (the same file as `$REPO_ROOT/.github/workflows/ci.yml`),
never inside `generated/`, because GitHub reads it only from the repository root (Section 0.1). Every
job therefore sets `defaults: run: working-directory: generated`, so relative paths such as `forge`,
`tests/run.sh` and `dist/` resolve inside the tool, and any artifact `path:` is written from the
repository root as `generated/dist/...`. The release workflow follows the same rule.

CI must:

1. Check out the repository with `persist-credentials: false`.
2. Prepare a Bash version compatible with project requirements.
3. Install every tool the tests and checks need - ShellCheck and `just` - as a required step, and
   fail the job if either is unavailable. Do not install tools on the user machine.
4. Validate the justfile first, because it is the cheapest check and fails in seconds:
   `just --list` parses every recipe. GitHub validates the workflow YAML itself, so the workflows are
   not linted again here; a missing `just` is a job failure, not a skip.
5. Run `shellcheck` on `forge`, `lib/*.sh`, `scripts/*.sh` and `tests/*.sh`.
6. Run `bash tests/run.sh`.
7. Validate the template tree and expected file correspondence.
8. Validate generation in a temporary directory.
9. Verify that `--dry-run` does not create the destination.
10. Verify that an existing destination is refused with code 3.

Rules:

- Use `permissions: contents: read`.
- Do not use `pull_request_target`.
- Do not include tokens or secrets.
- Use supported action versions; do not use `@master`. If the environment allows resolving a full
  SHA, pin the action by SHA.
- There is no macOS step; macOS is not supported.
- Do not install tools on the user machine to "complete" validation.
- The dependency step is mandatory. Never downgrade a missing tool to a warning, an echo or a silent
  skip.

### 13.2 `scripts/build-standalone.sh`

The standalone build must not be a stub presented as functional.

Generate a versioned bundle at `dist/workspace-forge-<version>/` with `forge` (executable), `lib/`
(six libraries), `templates/`, and the distribution `README.md` and `LICENSE`. Also generate
`dist/workspace-forge-<version>.tar.gz` and `dist/workspace-forge-<version>.tar.gz.sha256`.

The distribution `README.md` is written by the build, not copied from the repository: the repository
README links to `docs/`, `tests/` and to files the bundle excludes. It must be self-contained - what
the bundle is, which version it contains, how to run `./forge`, what the four scripts are, and the
license - and must not link to anything outside the extracted directory.

The bundle is the executable artifact; the tarball is the distribution format.

- produce the artifact in `dist/`, validate the inputs, and fail when a required file is missing
  (the four scripts under `templates/scripts/` and the six libraries under `lib/`);
- preserve the structure needed for execution and exclude `.git`, caches, secrets, tests, CI and
  development docs;
- be reproducible for the same files and settings; document the GNU `tar`/`gzip` limits that prevent
  bit-identical output;
- test the artifact in a temporary directory outside the original tree, and not depend on that tree
  after extraction;
- verify `--version`, `--help`, `--dry-run` and a real generation inside the extracted artifact;
- fail, and publish nothing, when the build or the artifact test fails;
- never delete `dist/` recursively without a guard.

If the standalone implementation cannot be completed, document the limitation and treat the release
as blocked: the release workflow must fail if the build or the artifact test fails.

### 13.3 `.github/workflows/release.yml`

Configure for `v*` tags.

It lives one level above the prompt's directory, at `$PROMPT_DIR/../.github/workflows/release.yml`,
like `ci.yml` (Section 13.1), and sets `defaults: run: working-directory: generated`.

The workflow must:

1. Validate the tag and the version declared in `forge`.
2. Run the CI steps from Section 13.1.
3. Build the functional standalone artifact.
4. Test the artifact.
5. Publish the release artifact with minimum necessary permissions.

Rules:

- Split jobs: `test` with `permissions: contents: read`; `release` with `permissions: contents:
  write` and `needs: test`.
- Use `actions/upload-artifact` and `actions/download-artifact` to transfer the artifact; do not
  grant write permission to the test job.
- Validate `GITHUB_REF_NAME` with `^v[0-9]+\.[0-9]+\.[0-9]+$`.
- Compare the tag with `FORGE_VERSION`; reject a mismatch.
- Do not simulate a successful publication. Do not publish during local execution of this task.
- The workflow may publish when a valid tag is pushed to the remote repository, but pushing the tag
  is a separate explicit authorization.
- Do not use `pull_request_target`, long-lived tokens or unnecessary permissions.
- Do not publish if tests, lint, build or artifact testing fail.
- Prefer `gh release create` with `GH_TOKEN` and `--verify-tag` over unpinned third-party actions.

### 13.4 Contribution templates

Create them one level above the prompt's directory, under `$PROMPT_DIR/../`, never inside the tool (Section 0.1):

- `.github/ISSUE_TEMPLATE/bug.md`
- `.github/ISSUE_TEMPLATE/feature.md`
- `.github/PULL_REQUEST_TEMPLATE.md`

Issue templates need valid frontmatter, a title, a description, the fields needed to reproduce the
report and the environment. The bug template adds reproduction steps, expected and observed
behavior, OS, Bash and forge version, and a warning not to include secrets; the feature template
adds the problem, the proposed solution and the alternatives. The pull request template needs a
`What changes` section and a checklist for tests, lint, documentation, changelog, security and
portability.

---

## 14. Final repository validation

Run the numbered steps below inside the validation container (Section 14.3). Sections 14.1 and 14.2
are host-side checks you perform before starting it. Before considering the implementation complete:

In this layout the tool repository is the output directory from Section 0.1 - `generated/` - and the
repository root is its parent. Every path below is relative to that directory, and `.github/` is one
level above it.

1. Verify that all required files and directories exist.
2. Verify that `forge`, `tests/run.sh`, `tests/test-*.sh` and `scripts/build-standalone.sh` are
   executable. On a filesystem that cannot store executable bits (NTFS behind a Windows bind mount),
   this cannot be decided from the host: verify it inside the container copy instead and record the
   host-side check as not applicable.
3. Run `bash -n` on Bash scripts and `forge`.
4. Install ShellCheck inside the container (Section 14.3) and run it; classify it as not verified
   only if the installation fails.
5. Run `bash tests/run.sh`.
6. Run `./forge --help` and `./forge --version`.
7. Run `./forge --dry-run` with a nonexistent temporary destination and verify that nothing was
   created.
8. Generate a workspace in a temporary directory.
9. Verify the 12 directories and 12 READMEs listed in Section 6.5, and the seven per-directory
   `.gitignore` files from Section 7.9, each with its exact three-line content. Verify that
   `data/.gitignore` does not exist and that the root `.gitignore` contains none of the nested
   `data/*` or `experiments/*` rules.
10. Verify that an existing (including empty) destination is refused with code 3.
11. Verify section order and required content.
12. Verify relative links, paths, scripts and configuration.
13. Build and test the standalone artifact.
14. Validate workflow and configuration syntax with available tools; classify what cannot be
    checked.
15. Verify the final tool repository state.

Rules:

- Use `find` to locate READMEs; do not rely on `**/README.md`.
- All tests must use their own temporary directories and remove them safely. Never use critical
  paths or real personal directories for write tests.
- Never run `./forge` without `-p` during implementation or validation; the default
  `$HOME/workspace` is a real destination. Always pass an explicit destination: a `mktemp -d` path
  on the host, or `/home/project/workspace` inside the container.
- Do not run `just install`, `just release`, or a real `backup.sh`/`clean.sh` with real side effects
  during validation.
- Do not install tools on the user machine just to declare all tests passed.
- Validation runs **only** inside a named Docker container, which stays running after the run. It
  never runs on the host, on WSL, or in a pre-existing container.
- If no Docker endpoint is usable, do not validate at all; use Section 14.6.

### 14.1 Identify where you are (informational)

These read-only probes print nothing and write nothing. They answer "where am I", which goes into
the summary (Section 16.1). They do **not** choose the validation platform: validation always runs
in Docker (Section 14.2).

1. **Container:** `test -e /.dockerenv` or `test -e /run/.containerenv` succeeds.
2. **WSL:** `grep -qi microsoft /proc/version` succeeds, or `WSL_DISTRO_NAME` is set.
3. **Other Linux host:** none of the above.

Docker running on WSL matches both probes, because a container inherits the host kernel. In that
case you are inside a container.

Being on WSL or on a Linux host does **not** authorize running the tests there.

### 14.2 Require a Docker endpoint

Validation requires Docker, wherever you happen to be running.

1. The CLI exists: `command -v docker` succeeds.
2. The daemon is reachable, which the binary alone does not prove:

```bash
docker version --format '{{.Server.Version}}'
```

This Bash snippet asks the Docker daemon for its version. Input: the CLI and a reachable endpoint
(`DOCKER_HOST`, `DOCKER_CONTEXT`, or the default socket). Output: one version line on stdout. It
reads no project file and writes nothing.

3. The endpoint counts as usable only when that command prints a version and exits 0. A remote
   endpoint set through `DOCKER_HOST` is acceptable: it is still the Docker used for validation.
4. The image must be **Ubuntu 24.04 LTS or newer**. If it is not present locally, pull it once with
   `docker pull ubuntu:24.04`; if the environment forbids pulling, stop and use Section 14.6. The
   next command pulls it too, when needed. Prove the version inside the container, never on the
   host:

```bash
docker run --rm -i ubuntu:24.04 bash -s <<'EOS'
  distro=$(sed -n "s/^ID=//p" /etc/os-release | tr -d '"')
  version=$(sed -n "s/^VERSION_ID=//p" /etc/os-release | tr -d '"')
  [[ $distro == ubuntu ]] || { echo "unsupported distro: ${distro:-unknown}" >&2; exit 1; }
  [[ $version =~ ^[0-9]+\.[0-9]+$ ]] || { echo "unsupported version: ${version:-unknown}" >&2; exit 1; }
  major=${version%%.*}; minor=${version#*.}
  (( 10#$major > 24 || (10#$major == 24 && 10#$minor >= 4) )) || { echo "unsupported version: $version" >&2; exit 1; }
  echo "ok: ubuntu $version"
EOS
```

This Bash snippet is fed to a throwaway container through stdin, which keeps the quoting simple. It
reads `/etc/os-release`, compares the two numbers in base 10, prints `ok: ubuntu <version>` and
exits 0, or prints one line to stderr and exits non-zero. It mounts nothing and writes nothing on
the host. `--rm` removes this probe container on exit: it is not the validation container and
proves nothing. `docker run` returns the exit code of the script.

5. Record the image tag and the distribution version reported by the probe; both belong in the
   summary (Section 16.1).

### 14.3 Run the validation inside the container

The numbered steps of Section 14 run in this container. The probes of Sections 14.1 and 14.2 run on
the host before it starts. Nothing is generated, built or tested outside the container.

The container is **named and left running**, so its files stay available for inspection. Pick a free
random 4-digit suffix before starting:

```bash
prefix=workspace-forge
name=""
for _ in $(seq 1 100); do
  candidate=$(printf '%s-%04d' "$prefix" "$(( RANDOM % 10000 ))")
  if ! docker ps -a --format '{{.Names}}' | grep -qx -- "$candidate"; then
    name=$candidate
    break
  fi
done
[ -n "$name" ] || { echo "no free ${prefix}-NNNN name" >&2; exit 1; }
echo "container: $name"
```

`RANDOM % 10000` yields a number from 0 to 9999, `printf %04d` pads it to four digits, and the loop
retries while `docker ps -a` already lists that exact name. `grep -qx` compares whole lines, so
`-0001` never matches `-00010`. After 100 collisions the block stops with an error instead of
looping forever. The result always looks like `workspace-forge-4827`.

Then start the container and run the validation inside it:

```bash
test -f forge || { echo "run this from the tool repository root (the generated/ directory)" >&2; exit 1; }
src=$(pwd)
repo_root=$(cd -P -- "$(dirname -- "$src")" && pwd)
: "${name:?run the naming block above first}"

docker run -d --name "$name" \
  --security-opt no-new-privileges \
  --pids-limit 256 \
  -e HOME=/home/project \
  -v "$repo_root:/repo:ro" \
  ubuntu:24.04 sleep infinity > /dev/null

[ "$(docker inspect --format '{{.State.Running}}' "$name")" = true ] || { echo "container is not running" >&2; exit 1; }

docker exec "$name" bash -c '
  set -Eeuo pipefail
  apt-get update -qq > /dev/null 2>&1
  apt-get install -y -qq shellcheck just > /dev/null 2>&1
'

docker exec "$name" bash -c '
  set -Eeuo pipefail
  mkdir -p /home/project
  cp -R /repo /home/project/repo
  cd /home/project/repo/generated
  rc=0
  bash -n forge lib/*.sh tests/*.sh scripts/*.sh templates/scripts/*.sh || rc=1
  bash tests/run.sh || rc=1
  ./forge --dry-run -p /home/project/workspace || rc=1
  ./forge -p /home/project/workspace || rc=1
  just --list > /dev/null || rc=1
  shellcheck forge lib/*.sh scripts/*.sh tests/*.sh || rc=1
  exit "$rc"
'
```

What each part does:

- `docker run -d ... sleep infinity > /dev/null`: starts the container detached with a keep-alive
  process, so it stays running after the test instead of exiting with it. The redirect discards the
  container id printed by `docker run`, which has no information.
- `--name "$name"`: fixes the name chosen above, so the run can be found again.
- `-v "$repo_root:/repo:ro"`: the whole repository is mounted **read-only** at `/repo`, so the tool is
  reachable at `/repo/generated` and `.github/` at `/repo/.github`. A root process inside the container
  cannot modify it and cannot leave root-owned files on a Windows mount.
- No `--network none`: the container needs network to install the tools used by the checks. The
  repository stays read-only, so the network cannot modify the sources, and the tests themselves do
  not use it.
- `--security-opt no-new-privileges` and `--pids-limit 256`: no privilege escalation and a bounded
  process count. `--cap-drop ALL` is deliberately not used, because `apt-get` fails without the
  default capabilities; the container is disposable and mounts no host path writable.
- `-e HOME=/home/project`: sets the container user home to the directory used by the run. Without it
  `HOME` is `/root`, and `forge` refuses any path under `/home/` that is not `$HOME` or below it, so
  `/home/project/workspace` would be rejected with code 3 (Section 6.3.2).
- `docker inspect ... = true`: fails early with a clear message when the container did not start,
  instead of letting `docker exec` report an obscure error.
- The first `docker exec` installs every tool the tests and checks need - `shellcheck` and `just` -
  inside the container, with the package-manager output discarded so the validation log
  stays readable. This step is mandatory: if it fails, stop and report with Section 14.6 instead of
  running a suite that would silently lose coverage.
- The second `docker exec` runs every check in the foreground and keeps going after a failure, so
  one broken step never hides the others. It exits 0 only when all of them passed, and 1 when any of
  them failed; the output says which.
- `mkdir -p /home/project` and `cp -R /repo /home/project/repo` create the working copy inside the
  container, never on the host, and the next command enters the tool at
  `/home/project/repo/generated`. A container created from the image starts with no
  `/home/project`, so nothing is deleted inside it; to run again you replace the container (Section
  14.4).
- `/home/project/workspace`: one destination for both commands. `--dry-run` writes nothing, so
  planning and then creating against the same path is safe, and the second command proves what the
  first announced. The path is a strict descendant of `$HOME`, which the protection table allows.
  Running `--dry-run` again after the real run exits 3, because the destination then exists.

The two blocks cover steps 3, 5, 7, 8 and 14 of Section 14; step 4 is the `shellcheck` line, which
runs last so a lint failure never hides the functional results. Run the remaining checks with the
same `docker exec "$name" ...` pattern while the container is running, staying inside
`/home/project/repo/generated`.

The examples use `ubuntu:24.04`; a newer tag satisfies Section 14.2 just as well.

Do not add `--privileged`, do not mount the Docker socket, and do not mount any host path writable.

### 14.4 Keep the container running, then replace it to re-test

- Do **not** pass `--rm`, and do **not** stop the container. It stays running after the test and
  holds `/home/project` for inspection.
- Inspect it without copying anything to the host:

```bash
docker exec -it "$name" bash
docker exec "$name" find /home/project/workspace -type f
```

The first command opens an interactive shell inside the container; the second lists the generated
files. Neither command writes anything by itself.

- To run the validation again, destroy the container first and then repeat Section 14.3:

```bash
docker rm -f "$name"
```

`-f` is needed because the container is running. This removes exactly that container and no other.
Do not instead clean the old destination to reuse the container: that needs recursive deletion
inside it, which Section 0.4 forbids. The next container starts with no `/home/project`, so the run
is clean without deleting anything inside a container. Reusing the old container is not an option:
`/home/project/workspace` already exists and `forge` refuses an existing destination with code 3.

- The naming block in Section 14.3 then picks a new random free number. Uniqueness is checked
  against the containers that exist at that moment.
- Report the container name and the `docker exec` exit code in the summary (Section 16.1). If the
  shell variable `name` is gone, recover it with `docker ps -a --filter name=workspace-forge-
  --format '{{.Names}}'`.
- Nothing is written on the host: the repository is mounted read-only and no file is copied out of
  the container.
- Remove only the container this procedure created, and only to re-test. Never run `docker system
  prune`, never remove another container, never remove images.
- Never delete anything under `/mnt/c` or any other Windows drive.
- If no free name is found after 100 attempts, report it and ask the user. Do not remove containers
  you did not create.

### 14.5 Hosts without a POSIX shell

The commands in Sections 14.2 and 14.3 are Bash. If the host cannot run Bash (native Windows with
PowerShell, for example), do not hand-translate them into the host shell: quoting mistakes cause
silent damage. Instead, put the body of the second `docker exec` in a script file outside the
repository, mount that file read-only, and run it inside the container:

```bash
docker run -d --name "$name" \
  --security-opt no-new-privileges \
  --pids-limit 256 \
  -e HOME=/home/project \
  -v "$repo_root:/repo:ro" \
  -v "$driver:/driver:ro" \
  ubuntu:24.04 sleep infinity > /dev/null

docker exec "$name" bash /driver/validate.sh
```

`$src` and `$name` come from Section 14.3. `$driver` is a directory outside the repository, created
with `mktemp -d`; `validate.sh` holds the same commands as Section 14.3, once they are in a file no
inline quoting is needed. The mount stays read-only, so the container still cannot modify the
repository or the driver. Keep the container flags, the name and the destination from Section 14.3
unchanged.

Record in the summary that a driver file was used and where it lived.

### 14.6 If Docker is not available

Do not run the tests anywhere else. WSL and the host are not substitutes.

Tell the user, in the reply:

- that the tests will **not** be run;
- which check failed: no `docker` CLI, unreachable daemon, image unavailable, or pulling not
  permitted;
- the values you detected: the `docker version` output or its error, and where you were running
  (Section 14.1);
- what the user must do:
  - Linux or WSL: install and start Docker Engine, or enable the Docker Desktop WSL integration,
    then confirm the user can reach the socket with `docker info`.
  - native Windows: install Docker Desktop with the WSL 2 backend.
  - confirm the setup with `docker run --rm ubuntu:24.04 echo ok` (a throwaway probe, not the
    validation container).
- that every check depending on Docker is classified as **Not verified** (Section 0.6), and that
  completion is not claimed (Section 15).

Those commands are for the user only. Do not run them yourself, do not install anything and do not
change the host.

---

## 15. Completion criteria

The implementation is ready for review when:

- [ ] The required structure exists.
- [ ] Code is modular and templates are separate.
- [ ] The CLI is documented and validated.
- [ ] Path protections work, including exact versus subtree rules.
- [ ] `--dry-run` performs no writes.
- [ ] The create-only contract is enforced: an existing (including empty) destination is refused
  with code 3.
- [ ] The generated workspace contains all seven per-directory `.gitignore` files with the exact
  content from Section 7.9, no `.gitignore` at the `data/` root, and no nested ignore rules
  duplicated in the root `.gitignore`.
- [ ] The nine executable tests exist and pass inside the validation container.
- [ ] Validation ran inside a named Docker container based on Ubuntu 24.04 or newer, which was left
  running, with the endpoint, image and container name recorded, or the missing Docker endpoint was
  reported with the steps to prepare it (Sections 14.2 and 14.6).
- [ ] Documentation matches real behavior.
- [ ] CI is configured.
- [ ] `bash spec/audit/run.sh` exits 0, or the failure is reported with its cause (Section 0.10).
- [ ] The standalone build is implemented and tested, or publication is explicitly blocked by the
  limitation.
- [ ] No remote operation, push, remote tag or release was performed.
- [ ] All code, comments, messages, filenames and documentation are in English.

Do not declare the project complete if a critical part is simulated, incomplete or untested.

---

## 16. Expected output

Write the files into `WORKSPACE_FORGE_ROOT`; do not assume a path you did not verify, and do not
paste every source file into the reply.

Report the absolute repository path plus the summary in Section 16.1. Do not create a remote
repository, push commits or publish releases. The result must be a consistent local repository,
ready for review.

### 16.1 Summary template

Return the plain-text template below as the final summary. It is not code and has no side effects.
Keep each label, its colon and its value on one line; when a value needs more room, continue on
following lines indented by four spaces. Write `none` instead of leaving a field empty, and use
exactly one classification word per status field, chosen from Section 0.6.

```text
Root:            absolute path of the tool repository
Structure:       <N> files / <M> directories, measured with find, excluding dist/
Environment:     host kind (Section 14.1); Docker endpoint and image (Section 14.2);
                 container name (Section 14.3); Bash version
Tests:           [Passed/Failed/Not verified/Not applicable] command and exit code
Lint:            [Passed/Failed/Not verified/Not applicable] tools run and exit code
Generated:       [Passed/Failed/Not verified/Not applicable] directories, READMEs,
                 .gitignore files, total files, create-only refusal code
Standalone:      [Passed/Failed/Not verified/Not applicable] artifact, checksum, smoke test
Audit:           [Passed/Failed/Not verified] command and exit code; warnings remaining,
                 by class; unreachable violations and why
Fixed:           defects found and corrected during the work, or none
Not verified:    checks that were skipped, each with its reason, or none
Pending:         work the user must still do, or none
Residual risks:  accepted limitations, or none
```

Rules for the fields:

- `Structure:` reports two measured numbers and nothing else. Give the command you used in
  parentheses if the numbers are not obvious. Do not mix file counts with directory counts in one
  number, and do not list a breakdown that does not add up.
- `Tests:`, `Lint:`, `Generated:` and `Standalone:` each carry exactly one classification. A field
  that passed is not mentioned again under `Fixed:` or `Not verified:`.
- `Fixed:` lists defects that were found and corrected. Corrected defects are not failures, so they
  never appear as a failed status field.
- `Not verified:` lists what was skipped and why, one per line, indented. A missing tool or an
  unsupported platform belongs here.
- Every `[Failed]` field must state what failed and the exact error or exit code. Do not write
  `[Failed]` without evidence.
- Never invent a number. If you did not measure it, write `not measured`.
