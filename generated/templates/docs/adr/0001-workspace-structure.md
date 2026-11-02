# 0001 - One directory per responsibility

- Status: accepted

## Context

A personal workspace mixes source code, experiment output, datasets, deployment files
and notes. Without a rule, the same directory collects all of them: a dataset sits
next to a script, an experiment result sits next to a project, and a reader cannot
tell which file belongs to which activity.

The workspace also has to stay understandable to its owner months later, when the
context that produced a file is gone. A directory name is the cheapest record of
what a file is for, and it survives every tool change.

## Decision

The workspace keeps one top-level directory per responsibility:

- `projects/` holds source code of work that continues.
- `experiments/` holds work that answers a question and then stops.
- `data/` holds datasets in four stages: `raw/`, `interim/`, `processed/` and `external/`.
- `infrastructure/` holds configuration, manifests and deployment files.
- `docs/` holds explanations of the workspace and its decisions.
- `scripts/` holds the automation that the `justfile` calls.

Each directory states its own purpose and limits in its `README.md`. A file sits in
the directory whose subject it matches, and a file that fits no directory prompts a
new decision rather than a new folder inside an existing one.

Project autonomy follows from the same rule: each project and each experiment holds
the files below it, so the user can move that directory elsewhere without breaking
another activity. The workspace root holds only the files that apply to every
directory.

The workspace root carries no version number. Each project and each experiment
records its own version in its own `README.md`, so two activities advance
independently.

## Consequences

- A reader finds a file by its subject, not by memory of the day it was created.
- A directory that grows a second subject is split, and the split follows this rule.
- The root stays small: its files apply to every directory below it.
- Moving a project or an experiment out of the workspace needs no change to the
  other directories.
