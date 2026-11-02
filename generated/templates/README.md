# Templates

`templates/` holds the files that `forge` installs into a generated workspace. The file documents the
tree and is not installed: `copy_templates` never installs `templates/README.md`.

## The tree is the managed set

The managed set is derived from the tree, not from a static manifest. `forge` reads `templates/` at
runtime and derives every destination path from a file's location. A file added under a category
becomes installable content on the next run, and a file removed from the tree stops being installed.
`FORGE_TOTAL_FILES` is derived from the template tree at runtime.

`forge` verifies the required categories and files before it copies anything. A missing category or
file fails the run before the first copy.

## Mapping

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

The mapping keeps the relative path, so `templates/data/raw/.gitignore` becomes
`data/raw/.gitignore`. The directories come from `create_tree`, not from empty directories in the
template tree, and a template file must land inside one of the twelve generated directories.

## Add or change a template

1. Choose the category of the destination directory.
2. Create or edit the file at `templates/<category>/<relative path>`.
3. Write the bytes the workspace needs; `forge` substitutes nothing.
4. Avoid a symbolic link. Preflight refuses a link anywhere under `templates/`.
5. Keep the file name free of newline, carriage return and tab; spaces are allowed.
6. Run `bash tests/run.sh` from the tool root.

A new file inside an existing directory needs no code change. A new directory needs a change to
`create_tree` and to the tests; [contributing.md](../docs/contributing.md#keep-the-template-tree-and-the-twelve-directories-aligned)
states the alignment rule.

## Verify links and paths

- Resolve a relative link from the file's destination directory. A README in `templates/docs/adr/`
  lands in `docs/adr/`, so `../README.md` points to `docs/README.md`.
- A link to a tool file breaks in the workspace. The workspace has no `forge`, no `lib/` and no
  `docs/architecture.md`.
- A path named in a template must exist in the generated tree. `templates/root/README.md` lands at
  the workspace root, so its relative paths start there.
- Generate a throwaway workspace with `./forge -p "$(mktemp -d)/workspace"` and open the installed
  file. A `root/` template moves to the workspace root, so its links can break after installation
  even when they resolve in the template tree.

## Run the tests

```bash
bash tests/run.sh
```

`tests/run.sh` runs every test file. `tests/test-content.sh` checks the installed READMEs, the
required files and the seven nested `.gitignore` files. [contributing.md](../docs/contributing.md#run-tests-and-lint)
lists the suite requirements and the lint command.

## When to update documentation, tests and changelog

- Add a file: add it to the required-file list when every generation must produce it, and record it
  under `[Unreleased]` in [CHANGELOG.md](../CHANGELOG.md).
- Change a file's content: update the document that states the content contract, and record the
  change in the changelog.
- Change the mapping or a tree rule: update this file and
  [architecture.md](../docs/architecture.md#the-template-to-workspace-mapping), then run the full
  suite.

[contributing.md](../docs/contributing.md) states the full contribution procedure, the checks and the
review.
