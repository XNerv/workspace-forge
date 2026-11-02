# 📁 data/

> Data files grouped by processing stage, so a reader can tell the original input from a finished dataset.

---

## 📋 Purpose

The `data/` directory separates data by how far it has moved from its source. The user places a file in `raw/` as it arrived. A command writes an intermediate copy into `interim/` during a transformation, and a project reads the finished dataset from `processed/`. Files from another team or a public source stay in `external/`, apart from the files this workspace produces.

Each stage directory holds its own `README.md` with the details for that stage. Every stage answers the same questions. Provenance states who provided a file and under which terms. Immutability states whether a file changes in place. Regeneration states which command rebuilds a file. Integrity states how a reader confirms that a file did not change, and a checksum is a short fingerprint computed from the file contents.

Each stage directory is self-contained and ready to become its own Git repository. The user decides when to create that repository; the generator creates no repository and makes no commit.

## 📁 Structure

```text
data/
├── README.md
├── external/
│   ├── README.md
│   └── .gitignore
├── interim/
│   ├── README.md
│   └── .gitignore
├── processed/
│   ├── README.md
│   └── .gitignore
└── raw/
    ├── README.md
    └── .gitignore
```

## ✅ Rules

- **`raw/` provenance** — record who provided each file, the date and the terms of use in a note next to the data.
- **`raw/` checksum** — record a checksum when a file arrives, so a later reader confirms that the file did not change.
- **`raw/` immutability** — a raw file never changes; a correction arrives as a new file with a note that names the replaced file.
- **`interim/` transformation** — each file records the raw input it came from and the command that produced it.
- **`interim/` rebuild** — the command that builds an interim file is idempotent, which means a second run produces the same output.
- **`processed/` rebuild** — a fix goes into the command that builds the dataset, and the user rebuilds the file from its inputs.
- **`processed/` integrity** — store a checksum next to each dataset and compare it before a project reads the file.
- **`external/` origin** — record the source address, the provider and the terms that apply before a project reads an external file.
- **`external/` read-only** — an external file stays unchanged; a provider correction arrives as a new file under a new name.
- **Ignore rules** — each stage directory ships a `.gitignore`, and the `data/` root ships no ignore file.
- **No invented data** — a note marks an example file as fictional, and a fictional file never enters `raw/` as a real record.

## 🚫 Out of scope

- Code that transforms data → `../projects/`
- Analysis results → `../experiments/`
- Workspace-wide instructions → `../docs/`
- Deployment files → `../infrastructure/`
- Archive files from `../scripts/backup.sh` → a directory outside the workspace

## 🔗 See also

- [Raw data](raw/README.md)
- [Interim data](interim/README.md)
- [Processed data](processed/README.md)
- [External data](external/README.md)
- [Workspace structure decision](../docs/adr/0001-workspace-structure.md)
- [Workspace README](../README.md)
