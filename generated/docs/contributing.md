# Contributing

`workspace-forge` is developed as a Bash program with plain-file templates, a Bash test suite and
ShellCheck lint.

The guide states how to change a template, keep the tree aligned, run the checks and update the
changelog. The security and portability review and the preparation of a contribution follow the
template workflow.

## Where a change goes

In the source repository, `spec/workspace-forge.prompt.md` produces `generated/`, and nobody
hand-edits the output. A change to the tool goes into the specification first. A new generation run
then replaces the whole tree, so an edit that exists only in the output disappears at the next run.

## Change a template

1. Find the file under `templates/`. [templates/README.md](../templates/README.md#mapping) states the
   mapping from template path to workspace path.
2. Edit the file. `forge` copies the bytes without substitution.
3. Resolve every relative link from the file's destination directory, not from its template
   directory.
4. Run `bash tests/run.sh`.
5. Record the change under `[Unreleased]` in [CHANGELOG.md](../CHANGELOG.md).

## Add a template

1. Choose the category whose directory holds the file in the workspace.
2. Create the file at `templates/<category>/<relative path>`.
3. Do not create a symbolic link; preflight refuses one under `templates/`.
4. Add the file to the required-file list in the tests when every generation must produce it.
5. Run the suite and add the changelog entry.

## Keep the template tree and the twelve directories aligned

`create_tree` creates the twelve directories, and no template creates a directory. A template file
must land inside one of those twelve. A new directory needs a change to `create_tree` and to the
tests.

Each directory has one README. A template README uses the five sections of the other workspace
READMEs: Purpose, Structure, Rules, Out of scope and See also. `tests/test-content.sh` checks that
order.

## Run tests and lint

```bash
bash tests/run.sh
just lint
```

`bash tests/run.sh` runs every test file under `tests/` in sorted order and returns non-zero when one
fails. `just lint` runs ShellCheck over `forge`, `lib/*.sh`, `scripts/*.sh` and `tests/*.sh`, and it
fails when ShellCheck is absent.

The suite needs `just` and `shellcheck`. A missing tool fails the run, and no test skips silently.

Run a syntax check on every Bash file before the suite:

```bash
for f in forge lib/*.sh scripts/*.sh tests/*.sh; do bash -n "$f"; done
```

## Update the changelog

Add an entry under `[Unreleased]` in [CHANGELOG.md](../CHANGELOG.md). Use the Keep a Changelog
headings: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed` and `Security`. State the behavior that
changed, not the file that changed.

When a version is prepared, move the entries under that version heading. `FORGE_VERSION` in `forge`
is the single source of the version number.

## Review security

- Create-only: no code overwrites, merges or deletes an existing path.
- Preflight writes nothing, and every write happens after preflight passes.
- Path comparisons use canonical paths and component boundaries.
- No step follows a symbolic link inside the generated tree.
- No `eval`, no unquoted expansion and no network call enters the tool.
- A template holds no credential, token or private path.
- Run `just lint` and fix every finding before you send the change.

## Review portability

- The tool runs on Bash 4 or newer, on Linux and WSL2 only.
- A new command must appear in the preflight dependency check.
- A path with spaces must survive every layer, and a control character must stay rejected.
- A feature newer than Bash 4.0 must not enter the tool.
- Test on Linux or WSL2. A run on native Windows or Git Bash proves nothing, because preflight
  refuses that platform.

## Prepare a contribution

1. State the behavior that changes and the reason.
2. State the platform and the Bash version that ran the suite.
3. Include the test result and the `just lint` result.
4. Keep the change free of unrelated edits.
5. Update the document that states the changed fact, and the changelog entry.
6. Record a design decision in a new file next to [0001-why-forge.md](adr/0001-why-forge.md), with
   one decision per file.
