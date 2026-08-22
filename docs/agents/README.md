# docs/agents — what the imported skills read before they act

**Written 2026-08-22 by `/setup-matt-pocock-skills`.** Three files, and **nothing else belongs here** — this
is configuration the skills read, not documentation a person reads.

| File | Who reads it |
|---|---|
| `issue-tracker.md` | `to-spec` · `to-tickets` · `triage` · `code-review-mp` · `wayfinder` — **where a ticket physically goes** |
| `triage-labels.md` | `triage` — the five role strings |
| `domain.md` | `domain-modeling` and anything exploring the code — points at `CONTEXT.md` |

⚠ **`CLAUDE.md` does not know this folder exists**, and its doc table says `docs/` is *one folder and five
loose files*. **Only the user edits that file**, so the table is stale until they do.
