# 📁 raw/

> Original data exactly as it arrived, unchanged so that a later result names the input it used.

---

## 📋 Purpose

The `raw/` directory holds data in the exact form that its source delivered. A file enters this directory once and stays byte for byte identical, so a published result names the exact input it used.

The directory starts with this README and a `.gitignore`. The user adds the dataset files and a note that records each source. A checksum is a short fingerprint computed from the file bytes, and the user records one for every file that arrives.

## 📁 Structure

```text
raw/
├── README.md
└── .gitignore
```

## ✅ Rules

- **Immutability** — a raw file never changes; a correction arrives as a new file with a note that names the replaced file.
- **Provenance** — for each dataset, record who provided it, the date and the terms of use in a note next to the files.
- **Checksum** — record a checksum when a file arrives, so a later reader confirms that the file did not change.
- **One source per file** — a file that merges two providers is a derived file, and `../interim/` holds it.
- **Repository later** — the user can later turn this directory into its own Git repository. The `.gitignore` next to this file ignores every entry except `README.md` and itself.

## 🚫 Out of scope

- A cleaned or corrected copy → `../interim/`
- A dataset that a project reads → `../processed/`
- Data from a provider outside the team → `../external/`
- Code that transforms data → `../../projects/`

## 🔗 See also

- [Data overview](../README.md)
- [Interim data](../interim/README.md)
- [External data](../external/README.md)
- [Workspace structure decision](../../docs/adr/0001-workspace-structure.md)
