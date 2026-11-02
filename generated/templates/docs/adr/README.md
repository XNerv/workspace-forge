# 📁 adr/

> Architecture Decision Records (ADRs) are short files that state one design decision with its context and consequences, and this directory keeps them.

---

## 📋 Purpose

An ADR answers a question that a reader asks months after the change: why does the workspace separate these directories? A record states the situation, the choice and the result, so a later reader judges the choice without repeating the discussion.

The file `0001-workspace-structure.md` records the decision that produced the current layout of the workspace.

## 📁 Structure

```text
adr/
├── README.md
└── 0001-workspace-structure.md
```

## ✅ Rules

- **One decision per file** — a file states one decision, so a reader accepts or rejects it without reading a second subject.
- **Fixed order** — each record gives its status, its context, its decision and its consequences in that order.
- **Numbered names** — name a new record with the next number and a short title, for example `0002-name-the-next-decision.md`.
- **Status line** — mark a record as proposed, accepted or replaced, so a reader knows whether the decision still applies.
- **Replacement** — when a decision changes, add a new record that names the record it replaces and leave the old file unchanged.
- **Context first** — state the situation and the constraints that required a choice before the choice itself.

## 🚫 Out of scope

- A guide to the workspace → `../README.md`
- Task lists and meeting notes → the project directory that holds the work
- A command that performs a decision → `../../scripts/`

## 🔗 See also

- [Workspace structure decision](0001-workspace-structure.md)
- [Documentation directory](../README.md)
- [Workspace README](../../README.md)
