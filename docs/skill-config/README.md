# docs/skill-config — what the imported skills read before they act

**Written 2026-08-22 by the upstream setup skill, which has since been deleted.** ⚠ **Renamed from `docs/agents/` on 2026-08-27** —
the old name read as a folder of agents, and it misled a session that same day. **The agents live in
`.claude/agents/`.**

**Two files, and nothing else belongs here** — this is configuration the skills read, not documentation a
person reads.

| File | Who reads it |
|---|---|
| `issue-tracker.md` | `code-review-mp` — **where a ticket physically goes.** ⚠ The other four readers were deleted 2026-08-27 |
| `domain.md` | `domain-modeling` and anything exploring the code — points at `CONTEXT.md` |

⚠ **`triage-labels.md` was deleted on 2026-08-27.** It mapped five triage roles — maintainer, reporter,
ready-for-human — onto label strings, and **no ticket in this repo ever carried one.** A game built by one
person has no reporter. **Restoring it means restoring the triage flow with it.**

⚠⚠ **Only the user edits `CLAUDE.md`.** Its doc table already names this folder. When something here needs
that file to change, **report it to the user** — never edit it in.
