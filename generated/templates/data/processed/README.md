# 📁 processed/

> Finished datasets that a project or a report reads directly, rebuilt by a recorded command from the earlier stages.

---

## 📋 Purpose

The `processed/` directory holds the datasets that analysis code reads. Each file comes from the stages before it, and a recorded command rebuilds it, so the user edits that command and not the file.

The directory starts with this README and a `.gitignore`. The user adds the datasets and a note that names the input files and the build command for each dataset.

## 📁 Structure

```text
processed/
├── README.md
└── .gitignore
```

## ✅ Rules

- **Integrity** — store a checksum next to each dataset; a checksum is a short fingerprint of the contents, so a change fails the comparison.
- **Rebuild, not patch** — a fix goes into the command that builds the dataset, and the user rebuilds the file from its inputs.
- **Build record** — a note next to each dataset names the input files and the command that produced it.
- **Reader check** — a project that reads a dataset compares the checksum before the analysis starts.
- **Repository later** — the user can later turn this directory into its own Git repository. The `.gitignore` next to this file ignores every entry except `README.md` and itself.

## 🚫 Out of scope

- An original data file → `../raw/`
- A working file from a transformation step → `../interim/`
- Analysis code → `../../projects/`
- A notebook and its result → `../../experiments/`
- Data from outside the team → `../external/`

## 🔗 See also

- [Data overview](../README.md)
- [Raw data](../raw/README.md)
- [Interim data](../interim/README.md)
- [External data](../external/README.md)
- [Workspace structure decision](../../docs/adr/0001-workspace-structure.md)
