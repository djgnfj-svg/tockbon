# .claude/skills — 28 skills, and which three are this repo's

**Twenty-five came from `mattpocock/skills` verbatim** — thirteen on 2026-08-22, then twelve more the same
day on the user's ***「다가져와서 사용해보자」***. **Three were written here**; three others were written
here and deleted the same day. **Both halves of that are below.**

⚠ **The counts on this page were wrong until 2026-08-27** — it said 26 skills, 12 self-firing and one
written here, when the real numbers are 28, 14 and three. **Re-count instead of trusting a written total**:
`ls .claude/skills/*/SKILL.md | wc -l`, and `grep -l "disable-model-invocation: true"` for the locked ones.

⚠⚠ **Every skill here is KEPT on purpose** (2026-08-27, the user: ***"잠겨 있는 것도 종종 써서"*** ·
***"인터뷰 계열도 다 남겨"***). An audit proposed cutting sixteen and **the user overruled it**. What was
cleaned instead was the junk inside them: twelve `agents/openai.yaml` files for another company's tool,
which nothing in Claude Code reads, were deleted the same day.

**Start with `/ask-matt`** — it is the upstream router that says which skill fits a situation. ⚠ **It does
not know `wrap-up`**, so read this file first.

---

## Two ways a skill starts, and it is not visible from the name

| | How many | What it means |
|---|---|---|
| **Fires on its own** | **14** | The description is a trigger. A wrong description means it never fires — the most common harness failure |
| **Only when the user types `/name`** | **14** | Carries `disable-model-invocation: true`. **An agent cannot start these**, and asking it to is refused |

`wayfinder` `implement` `to-spec` `to-tickets` `ask-matt` `grill-me` `grill-with-docs` `handoff`
`improve-codebase-architecture` `setup-matt-pocock-skills` `teach` `to-questionnaire` `triage` `wait-what`
are the fourteen. **Everything else fires on its own.**

## The three this repo wrote

**Three others were deleted on 2026-08-22** — the user's call, and the reasoning held up: `implement-plan`
(394 lines) had its verification half already written down in `how-nets-lie`, `audit-harness` reported on a
harness a person can read, and `how-others-do-it` sat on top of `research`. **What was worth keeping was
moved before they went** — two measurements into `how-nets-lie`, the five-agent order into
`.claude/agents/README.md`, and the 「남들은 어떻게 하나」 guard back into `CLAUDE.md` as one line.

| Skill | What it does | Why nothing upstream covers it |
|---|---|---|
| **`wrap-up`** | Closes the session — reflects what finished into the docs, runs the nets, commits, and **asks whether the user looked** | **`handoff` is not this.** Handoff writes a note for the next agent and puts it OUTSIDE the repo; wrap-up writes INTO the repo, and it is the only place acceptance gets asked for |
| **`build-loop`** | Runs the build half of the map on ONE ticket — plan into it, build it, verify it | Its triggers are the user's own words (짜줘 · 구현하자 · 만들자), and it is wired to this repo's tickets and verify agents |
| **`plan-into-ticket`** | Writes an `## Implementation plan` INTO the ticket, synthesis only, no interview | Upstream plans live in their own files; here the plan has to land in the ticket, because `.scratch/island-hold/` is the only map |

## What is wired up, and what is not

- **`docs/agents/` exists** — `/setup-matt-pocock-skills` ran on 2026-08-22. The tracker is **local
  markdown**, which is what `.scratch/` already was
- ⚠ **`ask-matt` says `/code-review`; this repo's copy is `code-review-mp`** — renamed on import because
  Claude Code ships a `code-review` of its own. **The originals were left unedited on purpose**
- ⚠ **`ask-matt` routes to none of this repo's own work.** It describes the upstream flow only

## What was deliberately left upstream — eleven

**Seven the author marked `in-progress`** (`claude-handoff` `implement-spec` `loop-me`
`setup-ts-deep-modules` `writing-beats` `writing-fragments` `writing-shape`) and **four for another stack**
(`git-guardrails-claude-code` `migrate-to-shoehorn` `scaffold-exercises` `setup-pre-commit`).
**Say the word and they come too** — the full set is 36.
