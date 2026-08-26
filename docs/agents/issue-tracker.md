# Issue tracker: Local Markdown

⚠ **This repo already ran this convention before this file existed.** `docs/plans/` was deleted on
2026-08-22 and planning moved to `.scratch/`, so the seed template below is edited in one place to match
what `.scratch/README.md` already says. **That edit is marked.**

Issues and specs for this repo live as markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- ⚠⚠ **EDITED: there is no `spec.md`.** The upstream original put the spec in `.scratch/<slug>/spec.md`
  and **this repo has never had that file.** What sits at the top of a directory is `map.md`, the map,
  and `.scratch/README.md` is its source of truth. **A plan does not get its own file here — it is written
  INTO the ticket as an `## Implementation plan` section**, which is what the `plan-into-ticket` skill does
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file. **The slug is English** — `01-what-one-piece-is.md`. Every ticket on every map this repo has ever had uses one, and `.scratch/README.md` says the same
- ⚠⚠ **EDITED: `Status:` is NOT the triage state here.** `Status:` is the wayfinding state — `open` · `claimed` · `resolved` — and `.scratch/README.md` is its source of truth. **A triage role goes on its own `Triage:` line** (see `triage-labels.md`). Collapsing the two would make a triaged ticket read as a claimed one. ⚠ **No ticket in this repo has ever carried a `Triage:` line** — the rule exists so that the day one does, it does not collide with `Status:`
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<feature-slug>/` (creating the directory if needed).

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `.scratch/<effort>/map.md` (the Notes / Decisions-so-far / Fog body).
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `.scratch/<effort>/issues/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.
