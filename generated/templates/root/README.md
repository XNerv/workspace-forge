# 📁 workspace/

> A personal workspace that keeps projects, experiments, data, infrastructure, documentation and automation in separate directories.

---

## 📋 Purpose

The workspace gathers one person's material in a single place. Each top-level directory holds one kind of material, so a directory holds the files of its subject and nothing else. The root holds the files that apply to every directory: the `justfile`, the `.gitignore`, the `.editorconfig` and the `.env.example`.

The `justfile` holds one recipe per script, and a recipe is a named command that `just` runs. The command `just backup` runs the recipe `backup`, and that recipe calls `scripts/backup.sh`. The scripts start as skeletons, so a stage that the user has not written yet stops with an error message.

## 📁 Structure

```text
workspace/
├── README.md
├── justfile
├── .gitignore
├── .editorconfig
├── .env.example
├── docs/
├── scripts/
├── data/
├── experiments/
├── projects/
└── infrastructure/
```

## ✅ Rules

- **Placement** — put a file in the directory whose subject it matches, and keep the root for files that apply to the whole workspace.
- **Forwarding** — the `justfile` forwards every call to a script in `scripts/` and holds no logic of its own.
- **Editor settings** — `.editorconfig` sets UTF-8, LF line endings, a final newline and an indent of two spaces.
- **Ignore rules** — `.gitignore` lists paths that a Git repository ignores, and the rules apply after the user creates that repository.
- **Example variables** — `.env.example` shows variable names with placeholder values and holds no real credential.
- **New directories** — a directory that the user adds contains its own `README.md` in the same section order as this file.
- **Ownership** — the user edits every file here, and the generator never changes a file that already exists.

## 🚫 Out of scope

- Project source code → `projects/`
- Experiment output → `experiments/`
- Dataset files → `data/`
- Deployment files → `infrastructure/`
- Long explanations → `docs/`
- Archive files that `scripts/backup.sh` writes → a directory outside the workspace, chosen by the user

## 🔗 See also

- [Workspace documentation](docs/README.md)
- [Workspace structure decision](docs/adr/0001-workspace-structure.md)
- [Script skeletons](scripts/README.md)
- [Data stages](data/README.md)
- [Experiments](experiments/README.md)
- [Projects](projects/README.md)
- [Infrastructure](infrastructure/README.md)
- [justfile](justfile)
- [Editor settings](.editorconfig)
- [Environment example](.env.example)
