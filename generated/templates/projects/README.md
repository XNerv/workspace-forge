# 📁 projects/

> Durable codebases, one project per directory, where work continues after a trial proves the idea.

---

## 📋 Purpose

The `projects/` directory holds the codebases that the user maintains. A project keeps its own build files, dependency list, tests and `README.md`, so the directory moves to a new machine as a unit.

The directory starts with this README and a `.gitignore`. The user creates each project directory by hand and gives it a name that states what the project does.

## 📁 Structure

```text
projects/
├── README.md
└── .gitignore
```

## ✅ Rules

- **Independent build** — each project holds the files that build and run it, and no project reads a file from another project.
- **Own README** — each project directory contains a `README.md` that states how to build, run and test the project.
- **Own dependencies** — each project records its dependencies in its own file, so an update in one project leaves the others unchanged.
- **Short name** — use a lowercase name with hyphens, for example `invoice-export/`.
- **Shared material** — a dataset that two projects read goes in `../data/`, and each project names that path in its README.
- **Repository later** — the user can later turn this directory into its own Git repository, and each project directory is expected to become one. The `.gitignore` next to this file ignores every entry except `README.md` and itself.

## 🚫 Out of scope

- Trial code → `../experiments/`
- Datasets → `../data/`
- Deployment files → `../infrastructure/`
- Workspace-wide automation → `../scripts/`
- Instructions about the workspace → `../docs/`

## 🔗 See also

- [Experiments](../experiments/README.md)
- [Data overview](../data/README.md)
- [Infrastructure](../infrastructure/README.md)
- [Workspace documentation](../docs/README.md)
- [Workspace README](../README.md)
