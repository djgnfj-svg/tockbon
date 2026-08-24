---
name: plan-into-ticket
description: Turn a decided ticket into an implementation plan written INTO that ticket. Synthesis only, no interview. Use when writing an `## Implementation plan` section, or when the build-loop skill sends you here.
---

# plan-into-ticket

**Take what the ticket already decided and turn it into something buildable.** Do NOT interview the user;
synthesise what is already there.

⚠⚠ **This is the imported `to-spec` adapted to this repo, and it exists because `to-spec` cannot be
reached by an agent** — that skill is human-typed only. **Two things were changed and nothing else:**

1. **The plan goes INTO the ticket**, not into a new document. A new doc would make the same fact live in
   two files, and this repo has already deleted a set of documents for exactly that
2. **No user-story list.** That template is written for a team handing work across a boundary; here the
   person who decided it is the person reading it

**What was kept is the part this repo did not have: the seams step.**

## Process

### 1. Read the ticket, then the code

Learn what already exists and what has to be touched. Use the project's glossary words throughout.

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
- **Do not fill in what you do not know with something that sounds right.** Ambiguity is not yours to
  decide — batch every blocker into one message back and let the user answer
