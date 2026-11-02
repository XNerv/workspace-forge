# 📁 infrastructure/

> Files that describe the machines and services this workspace uses, kept apart from the code that runs on them.

---

## 📋 Purpose

The `infrastructure/` directory holds the files that define the machines, services and networks that a project uses. The files stay apart from project code because a deployment changes when the environment changes, and project code changes when the program changes.

The directory starts with this README and a `.gitignore`. The user creates a subdirectory when the first file for that area arrives.

## 📁 Structure

```text
infrastructure/
├── README.md
└── .gitignore
```

## ✅ Rules

- **Configuration** — the user creates `configs/` for files that set values such as a host name or a port for one environment.
- **Manifests** — the user creates `manifests/` for a manifest, a file that states the objects to deploy and the settings each one uses.
- **Recipes** — the user creates `recipes/` for a recipe, a recorded sequence of operations that builds or changes one environment.
- **Scripts** — the user creates `scripts/` for helper scripts that only a deployment runs, apart from the workspace scripts in `../../scripts/`.
- **Stacks** — the user creates `stacks/` for a stack, a set of components that run together, such as a database and its service.
- **Documentation** — the user creates `docs/` inside this directory for notes that apply to one deployment, and the workspace documentation stays in `../../docs/`.
- **Reports** — the user creates `reports/` for the output of a deployment check, such as the resources that a run created or changed.
- **No credentials** — a password or a key stays outside this directory, and a file here names the variable that supplies the value.
- **Repository later** — the user can later turn this directory into its own Git repository. The `.gitignore` next to this file ignores every entry except `README.md` and itself.

## 🚫 Out of scope

- Project source code → `../projects/`
- Workspace automation → `../scripts/`
- Dataset files → `../data/`
- Instructions about the workspace → `../docs/`
- A password or a key → outside the workspace

## 🔗 See also

- [Workspace README](../README.md)
- [Script skeletons](../scripts/README.md)
- [Workspace documentation](../docs/README.md)
- [Projects](../projects/README.md)
