# Issue tracker: Local Markdown

⚠ **This repo already ran this convention before this file existed.** `docs/plans/` was deleted on
2026-08-22 and planning moved to `docs/plan/`, so the seed template below is edited in one place to match
what `docs/plan/README.md` already says. **That edit is marked.**

Issues and specs for this repo live as markdown files in `docs/plan/`.

## Conventions

- One feature per directory: `docs/plan/`
- ⚠⚠ **EDITED: there is no `spec.md`.** The upstream original put the spec in a `spec.md`
  and **this repo has never had that file.** What sits at the top is `roadmap.md` (what is being done) and `log.md` (why),
  and `docs/plan/README.md` is its source of truth. **A plan does not get its own file here — it is written
  INTO the ticket as an `## Implementation plan` section**, which is what the `plan-into-ticket` skill does
- Implementation issues are one file per ticket at `docs/plan/tickets/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file. **The slug is English** — `01-what-one-piece-is.md`. Every ticket on every map this repo has ever had uses one, and `docs/plan/README.md` says the same
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

## When a skill says "publish to the issue tracker"

Create a new file under `docs/plan/` (creating the directory if needed).

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## ⚠ The wayfinding section was deleted 2026-08-27

`/wayfinder` is gone, and `compass` + `breakdown` + `docs/plan/roadmap.md` stand in its place.
**`docs/plan/README.md` is the source of truth for how a ticket is shaped and how status moves.**
