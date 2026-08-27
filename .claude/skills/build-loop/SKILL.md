---
name: build-loop
description: Run the build half of the map on one ticket — plan into the ticket, build it, verify it. Use when the user says 짜줘 / 구현하자 / 만들자 / 개발하자 / 이거 만들자, or otherwise asks for a decided ticket to be turned into code.
---

# build-loop — 계획 → 구현 → 검증

**The deciding half is already over.** The ticket holds the decision; this skill turns it into code.
**`breakdown` wrote the ticket. `wrap-up` closes the session after this.**

⚠⚠ **You do not write code here, and you do not read `src/` here.** Every step below happens inside an
agent with **its own context window** — that is the entire reason this skill exists. **The moment a
1900-line view file is opened in this session, the saving is gone.**

## Which ticket

The `claimed` ticket on the live map, or the one the user named. **If more than one is takeable and the
user named none, ask which — first, before anything else.**

## 1. Plan — the `spec` agent

Spawn `spec` on that ticket. It writes an `## Implementation plan` section into the ticket itself and
sets the `Status:` line to `claimed`. **Tell it to call the Skill tool with `plan-into-ticket`.**

⚠⚠ **Pass it the ticket and nothing else.** It has none of this conversation — a subagent inherits no
context. **Anything it needs that is not written down does not reach it.** That is why the plan has to be
prose in the ticket and not an understanding in your head.

## 2. ⚠⚠ The one checkpoint — **the user reads the plan**

**This is the only place the loop stops on purpose.** Put in front of the user: **what is being built, in
what order, and what is out of scope.** Then go back and forth until they are done with it.

**Never proceed on silence.** The user's agreement is the absence of anything to disagree with, and that
needs them to actually have seen it.

## 3. Build — the `builder` agent

⚠⚠ **Nets first or nets after, and it is decided by which folder is being touched** (2026-08-24,
the user): **work that touches `sim` writes the check first** — tell builder to call the Skill tool with
`tdd`. **Work on the screen writes it after**, the way builder already does.

**The reason is measured, not preferred.** Moving the field into 3D put 1033 drawing-bound checks at risk
and **about 480 did not survive.** What lived measured **input → state**; what died **asserted pixels.**
⇒ **A check written first against the screen is a check written to die at the next big change.**

⚠ **`tdd` will not write a test at a seam that is not agreed**, and the agreed three live in the
glossary. If the work needs a new seam, that is the user's call — stop and ask.

Spawn `builder`. It writes what the plan says, runs the nets, reports red/green, and **stops**. It does
not declare anything done.

⚠ **Do not pass builder's impressions to the verifiers.** Pass **what was written where** and **where it
said it was unsure** — nothing else. The moment 「builder said it looks good」 is relayed they are no
longer independent eyes.

## 4. Verify — in parallel

**`verify-read` and `verify-run` always. `verify-look` the moment anything reached the screen.**

⚠ **Do not spawn the screen verifier on a stage that draws nothing** — that is a third of the round trips
spent on nothing.

## 5. Judge

- **All pass** → the answer goes under `## Answer`, `Status: resolved`, and **one line on the map**
- **Any fail** → batch every finding into **ONE** message back to builder
- ⚠⚠ **Bounced three times without passing → stop and take it to the user.** Past that, builder starts
  bending the code to get past verification, and that is the most common path to code that pretends to work

## What comes back to the user

**The report, not the diff.** What was built · what the nets said · what the verifiers found · **what was
not done** · where anyone was unsure.

⚠ **If you find yourself pasting source into the chat, the context saving has already gone.**

**Then name the next step**: another open ticket on this chunk → `build-loop` again · the chunk's bar now
true → `breakdown` for the next chunk · the session ending → `wrap-up`.
