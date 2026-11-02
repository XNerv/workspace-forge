# Specification changelog

Changes to the specification in this directory. The tool has its own changelog at
[`../generated/CHANGELOG.md`](../generated/CHANGELOG.md).

## [29]

- `encoding.sh` states the LF requirement explicitly and reports the line of every carriage return
  instead of one error per file.
- `run.sh` runs it over every text file in the repository, not only the four documents: 78 files
  instead of 5.

## [28]

- The fenced-block check is `spec/audit/code-fences.sh`, not `fences.sh`. The name states the object
  it checks, which a bare `fences` did not.

## [27]

- Sections 0.3 and 0.10 state that the audit runs in both modes: it reads files and writes nothing,
  so a use-mode run still audits and still reports the result.

## [26]

- Section 0.3 allows temporary directories created with `mktemp -d` in both modes, so a use-mode
  run can still build a throwaway workspace outside the project root.

## [25]

- Section 0.3 states the two operating modes. In development the agent may read and write any path
  under the project root; in use it may only run `just` recipes from the root and changes nothing.
- `.git` is never written in either mode, and `.github/` takes a write only for a change about
  GitHub itself.

## [24]

- Section 0.3 contradicted Sections 0.9 and 0.10: it forbade writing anywhere at `$REPO_ROOT`, while
  0.9 requires the agent to write changes back into the prompt and 0.10 lets it fix a wrong check.
  The allow-list now names `spec/workspace-forge.prompt.md` and `spec/audit/`.
- The Section 0.10 title names the audit, because the section states both the writing rules and the
  procedure that enforces them.

## [23]

- Section 0.10 replaces the vague "if the text shows why" with one closed question per warning
  class: the condition of a permission, the antecedent of a pronoun, the list of a long bullet. A
  yes answer leaves the sentence alone; a no answer means the warning is right.

## [22]

- Section 0.10 removes the last piece of bookkeeping from the warning loop: a fixed warning leaves
  nothing behind, and a warning that stays is justified by the sentence that carries the condition,
  the antecedent or the list. No baseline file, no reason in the report.
- Section 16.1 reports warnings remaining by class, which is checkable against the tool output.

## [21]

- Section 0.10 turns the warning rules into a loop per text change: list, improve without losing
  meaning, re-check, justify when fixing would change the meaning, fix what the change broke
  elsewhere, and run the full gate before delivery.

## [20]

- Section 0.10 makes the warning rules executable: it names `prose.sh -w` so the list is visible,
  points the reason at the disposition table, sends the reason to the report, and claims a warning the
  change caused elsewhere.
- Section 16.1 records kept warnings and their reasons in the `Audit:` field.

## [19]

- Section 0.10 states the warning rules in four short sentences instead of six long ones: fix or
  keep with a reason, fixing is always allowed, a kept warning keeps a reason, untouched lines are
  out of scope.

## [18]

- Section 0.10 binds the justification to the warning: when the agent edits a line whose warning was
  already justified, the justification travels with it - the same reason or a better one, never none.

## [17]

- Section 0.10 says that a warning accepted earlier does not bind the agent: on a line it edits,
  fixing the warning is always allowed.

## [16]

- Section 0.10 scopes warnings to the change: each warning on a changed line is fixed or justified,
  and a warning already accepted is not re-justified.
- `prose.sh` no longer counts bold markers as words, so a bullet with a bold lead-in is measured on
  its sentence, not on the label.
- `prose.sh` measured four warning classes that never fired, because the patterns used `\b`, which
  gawk reads as backspace. The count jumped from 47 to 136 as soon as the four classes fired.

## [15]

- The tab rule has one owner. `encoding.sh` reports a tab outside a fenced block as an error and a
  tab inside one as a warning; `fences.sh` keeps only the delimiters.
- `counts.sh` no longer checks a template count the prompt never states.

## [14]

- Section 0.10 defines the failure mode it was missing: a check that reports a violation on correct
  text is itself wrong, and the fix goes into the check. When exit 0 is unreachable without breaking
  a requirement, the agent stops as in Section 0.7 and names the check, the line and what it tried.
- Section 15 gains the audit as a completion criterion, and Section 16.1 gains an `Audit:` field in
  the summary, so a red audit can no longer be reported as success.

## [13]

- `spec/audit/refs.sh` checks what no other script could: a `Section N` reference that names no
  heading, a "table/list/block below or above" with no target in that direction, and ordered-list
  numbering with a gap.
- `run.sh` runs it together with the others.

## [12]

- Section 0.10 describes the new arrangement of `spec/`: the prompt, the two documents and the
  audit scripts, which are written by hand and never generated.
- It states which check to run for which edit, and that a full `run.sh` is the gate before
  reporting completion.

## [11]

- Every audit script takes `-h/--help`, `-t/--tsv` and `-q/--quiet`, and returns 0 clean, 1
  violations, 2 usage error. Each runs alone; none sources a shared library.
- `run.sh` gains `--list` and `--only NAMES`, and rejects an unknown name with exit 2.
- Section 0.10 states the gate: a full `run.sh` before reporting completion, always; a single check
  is feedback while editing and never replaces it.

## [10]

- The audit grew from one check to seven. `spec/audit/run.sh` runs all of them and aggregates the exit
  codes: `prose`, `paths`, `links`, `counts`, `encoding`, `fences` and `tree`.
- `paths` verifies references to `spec/`, `generated/` and `.github/`; `links` verifies relative links
  and anchors; `counts` compares declared numbers with measured ones; `tree` compares a documented
  tree with the filesystem.
- Section 0.10 now names `run.sh`, so the re-verification after a change covers the whole set.
## [9]

- The wording audit is a Bash script, `spec/audit/prose.sh`, not Python. The project runs on Bash 4
  and standard tools, and the audit now needs nothing else: `awk` and `grep`, which preflight already
  requires. The `python3` fallback paragraph leaves Section 0.10 with it, and this replaces the
  `spec/audit/wording.py` named in version 7. The file is `prose.sh` because it measures prose -

## [8]

- Section 0.10 now carries the audit procedure and the disposition table for warnings, so an agent
  executing the prompt can run the check and act on its output without reading another file.
- It also states that the audit is repository tooling, not part of the generated tool, and that a
  host without `python3` runs it inside the validation container.

## [7]

- Section 0.10 names the automatic check: `python3 spec/audit/wording.py` over the prompt and the two
  READMEs, which must exit 0.
- `spec/audit/wording.py` implements the mechanical part of the audit: banned phrases, literal
  intensifiers and prose sentences over 25 words fail; `may`, sentence-initial pronouns, open
  quantifiers and long bullets are warnings.

## [6]

- Section 0.10 gives the writing rules: four questions a sentence must answer, seven prohibitions
  (metaphor, vague qualifier, weak modal, agentless passive, unfalsifiable claim, undefined term,
  long sentence), and the explicit scope - this prompt, the report, and every file written under
  `WORKSPACE_FORGE_ROOT` during the generation.
- The same section requires re-verification after every change to the prompt, and `spec/README.md`
  gains the audit procedure and the detection patterns.

## [5]

- Section 0.9 states who may write the output directory: only a generation run does, and that run may
  be executed by an agent or by a human working through the prompt by hand. Nobody hand-edits the
  output outside a run, and every change an agent makes that must last is written back into the prompt
  in the same change. The acceptance test is symmetrical - changes trace to the prompt, and the prompt
  true of the changes.

## [4]

- `yamllint` is no longer a required tool and the workflows are no longer linted in CI: GitHub already
  validates workflow YAML, and the check was close to redundant. The step now validates only the
  justfile (`just --list`), which nothing else parses.
- The required tools are ShellCheck and `just`, in CI, in the validation container and in the
  dependency lists of the tool documents.
- The claim that "the test suite needs yamllint" was false in four documents and is removed: no test
  invokes it.
- Section 10 now names the suite dependencies once and requires every document that lists them to
  name exactly ShellCheck and `just`, so the sentence cannot drift back.
## [3]

Clarifications found while executing version 2 end to end:

- `.github/` is described everywhere as living one level above the prompt's directory
  (`$PROMPT_DIR/../.github`), never inside `generated/`. Sections 0.1, 3, 13.1, 13.3 and 13.4 use the
  same phrasing.
- The standalone bundle ships a distribution `README.md` written by the build, self-contained and
  linking to nothing outside the extracted directory. The repository README is not copied, because
  it links to `docs/` and `tests/` that the bundle excludes.
- Tests must not end a function or test with `[[ ... ]] && command`: under `set -e` a false condition
  becomes the exit status and a passing check fails the run.
- `parse_args` must match `--` before the wildcard branches; behind a wildcard it is unreachable
  (SC2221/SC2222).
- The boundary assertion in `test-common.sh` uses the exact pairs from Section 6.3.2.
- Rule bullets require U+2014 EM DASH, and `test-content.sh` checks the character.
- `.shellcheckrc` may only carry SC1090/SC1091; the four findings this design reliably produces
  (SC2034 cross-library state, SC2088 literal tilde, SC1124 directive inside a `case`, unused loop
  variable) each have a stated fix, and none justifies widening the configuration.
- CI lints the workflows with `yamllint -d relaxed ../.github/workflows/*.yml`: from `generated/` the
  path starts with `../.github/`, never `.github/`.
- The copyright line names the author and the contact: `Copyright (c) 2026 Thiago Soares
  <thiagosilvaandradesoares@gmail.com>`, and the tool README closes with a License and author section
  (Sections 11.1 and 11.3). The placeholder `<AUTHOR NAME>` is gone.
- Section 0.8 gives a suggested work order and requires running the suite after each part, not only in
  Section 14.
- The `install` recipe requirements in Section 12.1 regained their lead-in sentence; the list had lost
  it and read as orphans under the note about the two justfiles.
## [2]

- The prompt file is named `workspace-forge.prompt.md`: subject first, artifact type as suffix.

- The output location is fixed: the agent writes the tool to `generated/`, a sibling of `spec/`, and
  that directory is the tool repository root. The tool keeps the name `workspace-forge`.
- Replacing a previous generation is allowed under explicit guards: the resolved path must equal
  `$REPO_ROOT/generated`, must be a real directory and not a symbolic link, must not be `/`, `$HOME`,
  the prompt directory or an ancestor of it, and `$REPO_ROOT` must be inside the agent's working
  workspace. Removal uses `find ... -delete` plus `rmdir`, never `rm -rf` and never a glob.
- `.github/` is written to the repository root, one level above `generated/`, because GitHub reads it
  only there. It is the single deviation from a plain tool tree.
- CI and the validation procedure run with `working-directory: generated`, and the validation mounts
  the repository root so the workflows remain reachable.
## [1]

- Initial specification, synchronised with `workspace-forge` 0.1.0.
- Validation runs only inside a throwaway Docker container, never on the host or on WSL. The
  container installs `shellcheck`, `just` and `yamllint`; a missing tool fails the run instead of
  skipping checks.
- The generated `justfile` uses `set positional-arguments := true` and `"$@"`, so a destination
  path containing a space reaches the script as one argument.
- Documentation ownership is explicit: each fact has exactly one document, and the others link to
  it. Generated READMEs explain technical terms in plain words on first use.
- Tests never modify the tool repository; the standalone build runs in a private copy.
- The CLI interaction matrix covers help, version, dry-run, tilde expansion, trailing slashes,
  control characters, attached and unknown short options, and stream separation.
