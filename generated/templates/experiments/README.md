# 📁 experiments/

> A working area for trials that answer one question before the work becomes a project.

---

## 📋 Purpose

The `experiments/` directory holds trials that answer a question with a short-lived code and data set. A trial keeps its own code, input files and result together, so the user repeats it or abandons it without touching a project.

The directory starts with this README and a `.gitignore`. The user creates each experiment directory by hand with `mkdir` and decides its name.

## 📁 Structure

```text
experiments/
├── README.md
└── .gitignore
```

## ✅ Rules

- **Question first** — name each experiment directory after the question it answers, for example `batch-size-2026-11/`.
- **Manual start** — the user creates each directory with `mkdir experiments/<name>` and adds a `README.md` that states the question and the method.
- **Self-contained** — the code, the input files and the result stay inside the experiment directory, so the directory moves as a unit.
- **Failure stays** — a failed trial stays in place with a note that records the result, so the next trial starts from that note.
- **Promotion** — when a trial proves repeatable, the user copies its code into `../projects/` and continues the work there.
- **Repository later** — the user can later turn this directory into its own Git repository. Each experiment directory can become a repository of its own as well. The `.gitignore` next to this file ignores every entry except `README.md` and itself.

## 🚫 Out of scope

- Durable code → `../projects/`
- Shared datasets → `../data/`
- Workspace automation → `../scripts/`
- Deployment files → `../infrastructure/`

## 🔗 See also

- [Projects](../projects/README.md)
- [Data overview](../data/README.md)
- [Workspace structure decision](../docs/adr/0001-workspace-structure.md)
- [Workspace README](../README.md)
