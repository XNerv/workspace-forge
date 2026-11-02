# 📁 docs/

> Written explanations of how this workspace is organized, why its directories are separate, and which decisions produced the layout.

---

## 📋 Purpose

The `docs/` directory holds the written explanation that a reader needs before changing the workspace. Each file covers one subject, so a question about the layout leads to one page instead of a long note.

The `adr/` subdirectory holds the design decisions. An Architecture Decision Record (ADR) is a short file that states one decision, the context that required it and the consequences that follow.

## 📁 Structure

```text
docs/
├── README.md
└── adr/
    ├── README.md
    └── 0001-workspace-structure.md
```

## ✅ Rules

- **One subject per file** — a file that grows past one subject splits into a second file whose name states the second subject.
- **Decisions in `adr/`** — put each design decision in its own record under `adr/`, because the reasoning stays useful after the files change.
- **Links over duplicates** — a page that needs a fact from another page links to it instead of repeating the paragraph.
- **Same change** — when a directory changes, update the page that describes it in the same change.
- **Plain Markdown** — write the pages in Markdown, a plain text format that an editor and a browser display with headings and links.
- **New record** — give a new record the next number and a title, and state its status, context, decision and consequences.

## 🚫 Out of scope

- Commands that automate a task → `../scripts/`
- Dataset files → `../data/`
- Project source code → `../projects/`
- Trial results → `../experiments/`
- Deployment settings → `../infrastructure/`

## 🔗 See also

- [Architecture Decision Records](adr/README.md)
- [Workspace structure decision](adr/0001-workspace-structure.md)
- [Script documentation](../scripts/README.md)
- [Workspace README](../README.md)
