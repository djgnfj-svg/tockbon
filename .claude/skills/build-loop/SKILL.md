---
name: build-loop
description: Run the build half of the map on one ticket — plan into the ticket, build it, verify it. Use when the user says 짜줘 / 구현하자 / 만들자 / 개발하자 / 이거 만들자, or otherwise asks for a decided ticket to be turned into code.
---

# build-loop — plan → build → verify

**The deciding half is already over.** The ticket holds the decision; this skill turns it into code.
**`wrap-up` wrote the ticket, and closes the session after this.**

⚠⚠ **You do not write code here, and you do not read `src/` here.** Every step below happens inside an
agent with **its own context window** — that is the entire reason this skill exists. **The moment a
1900-line view file is opened in this session, the saving is gone.**

## Which ticket

The `claimed` ticket on the live map, or the one the user named. **If more than one is takeable and the
user named none, ask which — first, before anything else.**

## 1. Interview, then write the plan — **you, here, not an agent**

⚠⚠ **This step used to be the `spec` agent, and that agent was deleted on 2026-08-29** (the user: *"I do
not think that agent is needed — the process is splitting into tickets, talking one ticket through with
me, turning that into a planning document, and handing it to the builder"*). **Every part of that except
the handoff is a conversation with the user, and an agent cannot have one.**

1. **Interview the user on this one ticket** until nothing is left to guess. **Call the Skill tool with
   `plan-into-ticket`** — it holds what to ask and the shape the plan takes.
2. **Write the plan into the ticket** as an `## Implementation plan` section and set `Status:` to
   `claimed`. **The file never moves**; status is the line, not the folder.

⚠⚠ **The plan is what reaches builder, and nothing else does.** A subagent inherits no context, so
**anything you understood but did not write down does not exist.** That is the whole reason the plan is
prose in the ticket rather than an understanding in your head.

### Attack it first — the `adversary` agent

⚠⚠ **ALWAYS, and there is no small-ticket exception** (2026-08-29, the user: *"the adversarial
review is needed even when it is small and obvious"*). **Send `adversary` at the finished plan before the
user sees it**, every time. It reads plans the way `verify` reads code: **prove it wrong.**
⚠ **"Small and obvious" is a judgement about the plan, made by whoever wrote it** — which is exactly
the judgement this step exists to check. **On a genuinely small ticket it comes back in one line**, and
that line is cheap.
⚠⚠ **Put its blockers in front of the user WITH the plan**, never instead of it. **It does not decide,
and it never proposes a different direction.**

## 2. ⚠⚠ The one checkpoint — **the interview, not a read**

**This is the only place the loop stops on purpose**, and it is **an interview** (2026-08-29, the user:
*"an interview is needed, deep enough that the ambiguous parts disappear"*).

**Put in front of the user**: what is being built, in what order, what is out of scope — **and every
blocker `adversary` found, all at once.**

⚠⚠ **Go until nothing is left for builder to guess.** If the answers open new gaps, ask again. **The bar
is that builder never has to ask back** — a builder who guesses is how a round is spent.
⚠ **Never proceed on silence.** The user's agreement is the absence of anything to disagree with, and that
needs them to actually have seen it.

## 3. Build — the `builder` agent

⚠⚠ **Nets first or nets after, and it is decided by which folder is being touched** (2026-08-24,
the user): **work that touches `sim` writes the check first** — tell builder to write the net before the code.
**Work on the screen writes it after**, the way builder already does.

**The reason is measured, not preferred.** Moving the field into 3D put 1033 drawing-bound checks at risk
and **about 480 did not survive.** What lived measured **input → state**; what died **asserted pixels.**
⇒ **A check written first against the screen is a check written to die at the next big change.**

⚠⚠ **No check is written at a seam that is not agreed**, and the agreed three live in the glossary.
If the work needs a new seam, that is the user's call — stop and ask.

### ⚠⚠ Split it — **this rule moved here out of `CLAUDE.md` on 2026-08-30**

***"From now on, whatever can be split should be split and run in parallel by itself."*** ⚠ **Work that
touches the SAME file is not split** — three agents in `field_view.gd` voided the measurement three times
and cost two rounds. **Blender work and code work never collide.**

**Where the round actually goes slow is the nets** (2026-08-30, the user: *"the round-trip is long, so
split the net writing, write them fast and review them fast"*).

- **Nets are separate files, so writing several IS splittable** — one agent per net, spawned at once,
  and **every result read in one pass**, never one at a time
- ⚠⚠ **They all measure ONE source.** While builder is still editing `src/`, every net aims at a moving
  target and the runner's fingerprint line is what catches it. ⇒ **Split the nets after builder stops**,
  or across files builder is not in

### ⚠⚠ Four questions before a net is written — **or it grows to 790 lines**

**Measured 2026-08-30**: 15 nets, **11,845 lines, 790 on average.** **The whole suite runs in 14 seconds**
— ⇒ **writing is what costs the round, never running.**

| | |
|---|---|
| **Does it go red on THIS defect?** | ⚠⚠ **The one nobody asks, and the reason nets grow** — not knowing what it catches means writing everything |
| **Same verdict every run?** | Pin the seed and the input list |
| **Seconds, not minutes?** | A net past 120s is killed and reported red |
| **Runs with nobody watching?** | A check that needs the user to look is not a net |

⚠ **This is `diagnosing-bugs`' Phase 1 bar applied to nets**; that skill holds the long form.

Spawn `builder`. It writes what the plan says, runs the nets, reports red/green, and **stops**. It does
not declare anything done.

⚠ **Do not pass builder's impressions to the verifiers.** Pass **what was written where** and **where it
said it was unsure** — nothing else. The moment 「builder said it looks good」 is relayed they are no
longer independent eyes.

## 4. Verify — in parallel

**`verify` always. `verify-look` the moment anything reached the screen.**

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
true → `grilling` to settle the next chunk with the user · the session ending → `wrap-up`.
