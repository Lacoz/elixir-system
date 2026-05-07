# Tickets (`tk`)

This project uses **[ticket](https://github.com/wedow/ticket)** — git-backed
issue tracking with the `tk` CLI. Tickets live as Markdown files with YAML
frontmatter in `.tickets/`.

Install: see upstream README ([brew tap wedow/tools](https://github.com/wedow/ticket)).

Quick reference: `tk help`, `tk ready`, `tk create`, `tk close`, `tk show <id>`.

Intent for capability work must be recorded per **`AGENTS.md`** (§7).

Migrating from Beads: if you still have `.beads/issues.jsonl`, use **`tk migrate-beads`**
from [ticket](https://github.com/wedow/ticket), review `.tickets/`, then remove `.beads/`.
