---
name: plan-into-ticket
description: Turn a decided ticket into an implementation plan written INTO that ticket, after interviewing until nothing is left ambiguous. Use when writing an `## Implementation plan` section, or when the build-loop skill sends you here.
---

# plan-into-ticket

**Turn what the ticket decided into something buildable** — buildable meaning **the builder never has to
ask back.**

## ⚠⚠ Interview until the ambiguity is gone (2026-08-29, the user)

***"An interview is needed, deep enough that the ambiguous parts disappear."***

**This skill used to say "synthesise, do not interview", and that was what was wrong with it.** A plan
synthesised from a ticket carries every gap the ticket had, and **the builder fills those gaps by
guessing** — which is where a round goes.

- **Ask everything at once, in one batch, before writing the plan.** Not one question at a time
- **Keep going until nothing is left to guess** — every number, name, edge, and "what happens when"
- ⚠ **A question you can settle by reading `src/` or the ticket is not a question.** Go read it
- ⚠ **No multiple-choice UI.** Options as short prose; the user answers in their own words
- ⚠⚠ **This runs in the main session, where the user is.** The `spec` agent that held it was deleted for
  exactly this reason — it could not have the conversation the plan depends on

**Done when** you can name what the builder will decide on their own, and the answer is nothing.

⚠ **The plan goes INTO the ticket, never into a new document** — the same fact in two files is what this
repo has already deleted a set of documents over. **No user-story list**: that template hands work across
a team boundary, and here the person who decided it is the person reading it.

## 1. Read the ticket, then the code — **four questions, all four answered**

| | Where |
|---|---|
| **What already stands** at this spot | `src/`, the tools, the docs. **Name it, so nobody builds it twice** |
| **What already died** here — deleted or reversed | `git log`. **Reviving a dead thing costs a round** |
| **Which net measures it**, and is it green right now | `tests/nets/` |
| **Which green went false here** | `docs/how-nets-lie.md`, searched for this spot |

⚠⚠ **An empty answer is an answer** — say a section is empty rather than dropping it. **A dropped section
reads as "there was nothing to find" when it means "nobody looked".**

## 2. Interview — one batch, and do not skip it

**Write down every point where two builders would build differently**, then put all of them to the user at
once. **Come back here if the answers open new gaps**; it is over when they do not.

## 3. Name the seams before planning the code

**Prefer an existing seam to a new one, and use the HIGHEST one you can.** The fewer seams across the
codebase the better — the ideal number is one.

⚠⚠ **The agreed seams are in the glossary, and no test is written at a seam that is not one of them.**
Work needing a new one → **say so and stop.** That is the user's call.

## 4. Decide the structure

- **A variant of something that exists, or a new kind?** A variant should finish as one more row in the
  table that owns it. If it needs new code, write down why
- **How many files must change to add one new kind?** **More than three means the structure is wrong** —
  replan. Three spots in one file are *one place*
- **If you add an axis, does every consumer follow?** A sim value that grows while the screen stays put is
  nothing happening, as far as the user is concerned

## 5. Write the plan into the ticket

Add an `## Implementation plan` section and set `Status: claimed`. **The file never moves** — status is
the line, not the folder. **The plan contains this and nothing else:**

- **Seams** — where this gets measured, from step 3
- **Files to touch and why** — one line each
- **Order** — what has to happen first for the next thing to be possible
- **Risk** — what this could silently break
- **Acceptance** — what you look at to know it is done. Nets and review consume this
- **Out of scope** — ⚠ **unwritten, builder expands into it**

## Never

- **Do not create or edit anything under `src/`** — that is builder's job
- **Do not restate a number that lives somewhere else.** One place owns it; everywhere else points at it
- ⚠⚠ **Do not fill in what you do not know with something that sounds right.** **A plan that reads
  complete while hiding a guess is worse than one that stops and asks** — nothing here pretends to work,
  plans included
