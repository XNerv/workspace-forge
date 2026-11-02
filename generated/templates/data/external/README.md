# 📁 external/

> Data from outside the workspace, such as a public dataset or a file from another team, kept apart from data this workspace produces.

---

## 📋 Purpose

The `external/` directory holds data that another organization or a public source supplied. A file here keeps its original content, and a note records where the file came from and which terms apply to its use.

The directory starts with this README and a `.gitignore`. The user adds the data files and the note for each source. A checksum is a short fingerprint of the bytes, and the user stores one next to every file.

## 📁 Structure

```text
external/
├── README.md
└── .gitignore
```

## ✅ Rules

- **Provenance** — for each dataset, record the source address, the provider and the terms of use before a project reads it.
- **Read-only** — an external file stays unchanged; a provider correction arrives as a new file under a new name.
- **Checksum** — store a checksum next to each file, so a later reader confirms that the download did not change.
- **No credentials** — a token or a key that opens the source stays outside the workspace; this directory holds data files only.
- **Withdrawal** — when a provider withdraws a dataset, delete the file and record the removal date in the note.
- **Repository later** — the user can later turn this directory into its own Git repository. The `.gitignore` next to this file ignores every entry except `README.md` and itself.

## 🚫 Out of scope

- Data that this workspace produces → `../raw/`, `../interim/` or `../processed/`
- A token or a key for the source → outside the workspace
- Code that downloads the data → `../../projects/`
- A copy that the workspace transforms → `../raw/`

## 🔗 See also

- [Data overview](../README.md)
- [Raw data](../raw/README.md)
- [Processed data](../processed/README.md)
- [Workspace structure decision](../../docs/adr/0001-workspace-structure.md)
