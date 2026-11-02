# Specification

`workspace-forge.prompt.md` is the source of truth for [`../generated/`](../generated). It is a
complete, self-contained instruction set for an agent: the tool's behaviour, its six libraries, its
templates, its tests, its documentation, its CI, and how to validate everything inside a throwaway
Docker container.

**Spec version: 29** — synchronised with `workspace-forge` 0.1.0.

## The rule

The generation run may be performed by **an agent or by a human** working through the prompt by hand;
both are legitimate and must produce the same files. The rule is about editing outside such a run:

- **Nobody hand-edits `generated/`.** Not a comment, not a version bump, not a one-line fix. The edit
  survives until the next regeneration and then disappears without a trace, which is worse than a
  merge conflict: nothing tells you it happened.
- **A human edits the prompt and regenerates**, by hand or through an agent.
- **An agent writes back every change that must last.** While an agent runs the generation it edits
  files under `generated/` freely. Whatever must survive the next run goes into
  `workspace-forge.prompt.md` in the same change. A fix that exists only in the output is a
  regression scheduled for the next regeneration.

The acceptance test is symmetrical: every lasting change in `generated/` traces to a sentence in
the prompt, and every sentence in the prompt that describes `generated/` is true of it. Section 0.9
of the prompt states this for the agent; this file states it for the maintainer.

## Workflow

1. Edit `workspace-forge.prompt.md`.
2. Hand the prompt to an agent working in this repository.
3. The agent writes the tool to `generated/`, one level above `spec/`, and replaces the previous
   generation itself: Section 0.1 of the prompt defines the guards for that removal.
4. Review `git diff -- generated/` as a change to the specification, not as a code review.
5. Run the [wording audit](#wording-audit) over the prompt and over the generated files you touched.
6. Record behavioural changes in [`CHANGELOG.md`](CHANGELOG.md) and bump the spec version above.
7. Commit `spec/`, `generated/` and any `.github/` change in the same commit.

Step 6 matters: a commit that touches only one of the two is either an unfinished change or a hand
edit.

## The one documented deviation

GitHub reads `.github/` at the repository root only, so the CI workflows and the issue and pull
request templates live at [`../.github/`](../.github), not inside `generated/`. Every other file in
`generated/` is exactly what the specification produces.

If you later extract `generated/` into its own repository, move `.github/` back into it.

## Validation

Section 14 of the specification describes the validation run. It mounts the repository root
read-only and enters `generated/` inside the container. Where the text says "the tool repository",
it means `generated/`.

The validation container installs `shellcheck` and `just`. Both are required; the suite fails rather
than skipping when one is missing. The workflow YAML is not linted there: GitHub validates it.

## Wording audit

Section 0.10 of the prompt states the writing rules and the audit procedure. Run this audit after
every change to the prompt: an edit invalidates the previous audit. It applies to the prompt itself
and to the files the prompt generates.

The mechanical part runs without judgement:

```bash
bash spec/audit/run.sh
```

It exits 1 on a banned phrase, a literal intensifier, or a prose sentence over 25 words. It prints
warnings - `may`, sentence-initial pronouns, open quantifiers, long bullets - and never fails on
them, because deciding those needs a reader. The disposition table for each warning is in Section
0.10 of the prompt. Add `--json` for a machine-readable report.

1. **Inventory.** Extract every normative sentence: imperatives, `MUST`/`NEVER` rules and bullets
   that constrain behaviour. Skip narrative, examples and this changelog.
2. **Test.** Apply four questions to each: who performs the action, what exactly is acted on, where
   it happens, how someone would verify it. Record the question that fails.
3. **Rewrite only the failures.** Name actor, verb and object; replace a metaphor with the concrete
   action; replace a vague qualifier with the deciding condition; state a weak modal with "must".
   A rewrite must not be longer than the original.
4. **Accept.** Re-run the patterns below; every remaining hit needs a justification. Compare sizes -
   the document must not grow. Confirm that `MUST`, `MUST NOT` and `NEVER` counts are unchanged, or
   that the change is deliberate and recorded.

A hit is a candidate, not a defect. These patterns find the text worth reading again:

```text
\b(propagat\w*|owns?|owned|belongs? to|lives? in|carries?|drives?)\b        metaphors
\b(persistent|appropriate|reasonable|as needed|where relevant|if useful|normally|usually)\b
\b(should|may|might|ideally|preferably)\b                                   weak modals
\bis (done|made|performed|handled|validated|verified|created)\b             agentless passive
```

`may` is usually a permission or a factual possibility, and `own`/`owned` is usually literal
filesystem ownership. Both classes produce false positives; keep them out of the list of
rewrites unless the four questions fail.

## Files

| File | Purpose |
|---|---|
| `workspace-forge.prompt.md` | The specification. Everything else here is about it. |
| `README.md` | This document: the rule, the workflow, the deviation. |
| `CHANGELOG.md` | Changes to the specification, versioned independently from the tool. |
| `audit/run.sh` | Runs every audit below and aggregates the exit codes. |
| `audit/prose.sh` | Wording: banned phrases, intensifiers, prose sentences over 25 words. |
| `audit/paths.sh` | References to `spec/`, `generated/` and `.github/` must exist. |
| `audit/links.sh` | Relative Markdown links and their anchors must resolve. |
| `audit/counts.sh` | Numbers stated in prose must match the repository. |
| `audit/refs.sh` | Section references, "below/above" targets and list numbering. |
| `audit/encoding.sh` | LF line endings (no CR, final newline), BOM, trailing whitespace, tabs (error outside a block, warning inside), U+FFFD; runs on every text file in the repository. |
| `audit/code-fences.sh` | Balanced fences, language tag, no empty block. |
| `audit/tree.sh` | A documented tree must match the filesystem. |
