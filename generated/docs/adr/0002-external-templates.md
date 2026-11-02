# ADR 0002: Why templates are external files

- Status: Accepted

## Context

A workspace contains files whose bytes matter: `.gitignore`, `.editorconfig`, `.env.example`, the
generated `justfile`, the twelve READMEs and the four scripts. The seven nested `.gitignore` files
carry exact required content.

A heredoc inside a Bash library would place that content in shell code. The author would escape `$`,
backticks, quotes and backslashes, and ShellCheck would parse the text as shell. A template change
would then appear as a library change, mixed with the copying logic.

## Decision

Store every installed file as a regular file under `templates/<category>/<relative>`. `install_file`
copies the bytes with `cp` and `mv`, and it applies no substitution.

## Consequences

- A template is reviewed, diffed and copied as a file, and the installed bytes equal the stored bytes.
- Shell quoting has no path from a template into the tool.
- The path rule needs no per-file entry in the code: a template under a category maps to the same
  relative path in the workspace.
- `templates/README.md` is skipped, and preflight refuses a symbolic link under `templates/`.
- The cost: ShellCheck does not read a template script. `tests/test-scripts.sh` checks the four
  scripts for existence, the execution bit and `bash -n`, and the scripts stay skeletons.
- The cost: `copy_templates` trusts the tree, so a misplaced file under a category becomes installed
  content; review checks the tree.
