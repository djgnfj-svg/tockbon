---
name: plan-into-ticket
description: Turn a decided ticket into an implementation plan written INTO that ticket, after interviewing until nothing is left ambiguous. Use when writing an `## Implementation plan` section, or when the build-loop skill sends you here.
---

# plan-into-ticket

**Take what the ticket decided and turn it into something buildable** — buildable meaning **the builder
never has to ask back.**

## ⚠⚠ Interview until the ambiguity is gone (2026-08-29, the user)

***"It cannot work like that. An interview is needed, deep enough that the ambiguous parts disappear."***

**This skill used to say "synthesise, do not interview", and that is what was wrong with it.** A plan
synthesised from a ticket carries every gap the ticket had, and **the builder fills those gaps by
guessing** — which is where a round goes.

- **Ask everything at once, in one batch, before writing the plan.** Not one question at a time
- **Keep going until nothing is left to guess.** Every number, every name, every edge, every "what
  happens when"
- ⚠ **A question you can settle by reading `src/`, the ticket or `log.md` is not a question.** Go read it
- ⚠ **No multiple-choice UI.** List the options as short prose in the body and let the user answer in
  their own words
- ⚠⚠ **This runs in the main session, where the user is.** The `spec` agent that used to hold it was
  deleted on 2026-08-29 for exactly this reason: **it could not have the conversation the plan depends
  on.** ⇒ **Ask them directly. Never write a plan that quietly assumed an answer.**

**Done when**: you can name what the builder will have to decide on their own, and the answer is nothing.

⚠⚠ **This is the imported `to-spec` adapted to this repo, and it exists because `to-spec` cannot be
reached by an agent** — that skill is human-typed only. **Two things were changed and nothing else:**

1. **The plan goes INTO the ticket**, not into a new document. A new doc would make the same fact live in
   two files, and this repo has already deleted a set of documents for exactly that
2. **No user-story list.** That template is written for a team handing work across a boundary; here the
   person who decided it is the person reading it

**What was kept is the part this repo did not have: the seams step.**

## Process

### 1. Read the ticket, then the code — **four questions, and all four get answered**

Learn what already exists and what has to be touched. Use the project's glossary words throughout.
**Everything you learn here is a question you no longer have to ask.**

| | Where |
|---|---|
| **What already stands** at this spot — in `src/`, the tools, the docs | **Name it, so nobody builds it twice** |
| **What already died** here — deleted or reversed | `docs/roadmap/log.md`, `git log`. **Reviving a dead thing costs a round** |
| **Which net measures it**, and is it green right now | `tests/nets/`, `tests/run_nets.ps1` |
| **Which green went false here** | `docs/how-nets-lie.md`, searched for this spot |

⚠⚠ **An empty answer is an answer** — say a section is empty rather than dropping it. **A dropped
section reads as "there was nothing to find" when it means "nobody looked".**
⚠ **This came from the `survey` skill, deleted 2026-08-29 after zero calls.** The questions were right;
having them behind a trigger nobody said was not.

### 1.5. ⚠⚠ Interview — one batch, and do not skip it

**Write down every point where two builders would build differently.** Then put all of them to the user
at once. **Come back to this step if the answers open new gaps**; it is over when they do not.

### 2. ⚠⚠ Name the seams before planning the code

**Sketch the seams at which this will be tested. Prefer an existing seam to a new one. Use the HIGHEST
seam you can. The fewer seams across the codebase the better — the ideal number is one.**

**The agreed seams are already written down in this repo's glossary, and a test will not be written at a
seam that is not one of them.** If this work needs a new one, **say so and stop** — that is the user's
call, not yours.

### 3. Decide the structure

- **Is this a variant of something that exists, or a new kind?** A variant should finish as one more row
  in the table that owns it. If it needs new code, write down why
- **How many files must change to add one new kind?** **More than three means the structure is wrong** —
  replan. Three spots in one file are *one place*
- **If you add an axis, does every consumer follow?** A sim value that grows while the screen stays put is
  nothing happening, as far as the user is concerned

### 4. Write the plan into the ticket

Add an `## Implementation plan` section and set the ticket's `Status:` line to `claimed`.
**The file never moves** — status is the line, not the folder.

The plan contains, and nothing else:

- **Seams** — where this gets measured, from step 2
- **Files to touch and why** — one line each
- **Order** — what has to happen first for the next thing to be possible
- **Risk** — what this could silently break. Check it against the fake-code list and the sim constraints
- **Acceptance** — what you look at to know it is done. Nets and review consume this
- **Out of scope** — what is not being done this round. **Unwritten, builder expands into it**

## Never

- **Do not create or edit anything under `src/`.** That is builder's job
- **Do not restate a number that lives somewhere else.** One place owns it; everywhere else points at it
- ⚠⚠ **Do not fill in what you do not know with something that sounds right.** Ambiguity is not yours
  to decide, and **a plan that reads complete while hiding a guess is worse than one that stops and
  asks** — nothing here pretends to work, plans included
