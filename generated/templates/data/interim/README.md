# 📁 interim/

> Working files that a transformation produces between the original data and a finished dataset.

---

## 📋 Purpose

The `interim/` directory holds files that one step of a transformation produces and a later step reads. An interim file is disposable: when the command that builds it changes, the user deletes the old file and runs the command again.

The directory starts with this README and a `.gitignore`. The user adds the build command and the files that the command produces.

## 📁 Structure

```text
interim/
├── README.md
└── .gitignore
```

## ✅ Rules

- **Repeatable build** — the command that builds each file is idempotent, which means a second run on the same input produces the same output.
- **Named inputs** — each interim file records the raw file it came from and the command that produced it.
- **Checksum** — record a checksum next to each file that a later step reads; a checksum is a short fingerprint of the file bytes.
- **Deletion** — delete an interim file after its build command changes, because the next run produces it again from the raw input.
- **Repository later** — the user can later turn this directory into its own Git repository. The `.gitignore` next to this file ignores every entry except `README.md` and itself.

## 🚫 Out of scope

- An original data file → `../raw/`
- A dataset that a project reads → `../processed/`
- Data from outside the team → `../external/`
- Code that runs the transformation → `../../projects/`

## 🔗 See also

- [Data overview](../README.md)
- [Raw data](../raw/README.md)
- [Processed data](../processed/README.md)
- [Workspace structure decision](../../docs/adr/0001-workspace-structure.md)
