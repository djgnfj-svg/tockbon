---
name: build-loop
description: Run the build half of the map on one ticket — plan into the ticket, build it, verify it. Use when the user says 짜줘 / 구현하자 / 만들자 / 개발하자 / 이거 만들자, or otherwise asks for a decided ticket to be turned into code.
---

# build-loop — plan → build → verify

**The deciding half is over.** The ticket holds the decision; this skill turns it into code.

⚠⚠ **You do not write code here, and you do not read `src/` here.** Every step runs in an agent with its
own context window — that is the whole reason this skill exists. **Open a 1900-line view file in this
session and the saving is gone.**

**Which ticket**: the `claimed` one on the live map, or the one the user named. More than one takeable and
none named → **ask first, before anything else.**

## 1. Interview, then write the plan — **you, here, not an agent**

1. **Interview the user on this one ticket** until nothing is left to guess. Call the Skill tool with
   `plan-into-ticket` — it holds what to ask and the shape the plan takes.
2. **Write the plan into the ticket** under `## Implementation plan` and set `Status: claimed`.
   **The file never moves**; status is the line, not the folder.

⚠⚠ **The plan is what reaches builder, and nothing else does.** A subagent inherits no context, so
anything you understood but did not write down does not exist.

### Attack it first — the `adversary` agent

⚠⚠ **ALWAYS, and there is no small-ticket exception** (2026-08-29, the user). Send it at the finished
plan **before the user sees it**. On a genuinely small ticket it comes back in one line, and that line is
cheap. **Put its blockers in front of the user WITH the plan**, never instead of it. It does not decide.

## 2. The one checkpoint — **an interview, not a read**

**Put in front of the user**: what is being built, in what order, what is out of scope, and every blocker
`adversary` found — all at once.

- ⚠⚠ **Go until nothing is left for builder to guess.** If the answers open new gaps, ask again
- ⚠ **Never proceed on silence.** Agreement is the absence of anything to disagree with

## 3. Build — the `builder` agent

- **`sim` work writes the net FIRST. Screen work writes it after** (2026-08-24, the user)
- **Measured, not preferred**: the 3D move put 1033 drawing-bound checks at risk and about 480 died. What
  lived measured **input → state**; what died asserted pixels
- ⚠⚠ **No check at a seam that is not agreed** — the agreed three are in the glossary. A new seam is the
  user's call, so stop and ask
- ⚠⚠ **Godot, shader or Blender-export work reads `docs/개발지식/` first** — call `knowledge`, and **name
  the page in the plan** or the pointer never reaches builder

### Split it

***"Whatever can be split should be split and run in parallel"*** (2026-08-30, the user).

- ⚠ **Never split work touching the SAME file** — three agents in one view file voided the measurement
  three times and cost two rounds. Blender work and code work never collide
- **Nets are separate files, so writing several splits well** — one agent per net, spawned at once, and
  every result read in one pass
- ⚠⚠ **Split the nets only after builder stops**, or across files builder is not in. A net aimed at a
  source that is still moving measures nothing

### Four questions before a net is written

**Measured 2026-08-30: 15 nets, 11,845 lines, 790 each — and the whole suite runs in 14 seconds.**
⇒ **Writing is what costs the round, never running.** `diagnosing-bugs` holds the long form.

| | |
|---|---|
| **Does it go red on THIS defect?** | ⚠⚠ The one nobody asks, and the reason nets grow |
| **Same verdict every run?** | Pin the seed and the input list |
| **Seconds, not minutes?** | Past 120s it is killed and reported red |
| **Runs with nobody watching?** | A check that needs the user to look is not a net |

Spawn `builder`. It writes what the plan says, runs the nets, reports red/green, and **stops**. It does
not declare anything done.

⚠ **Do not pass builder's impressions to the verifiers.** Pass what was written where, and where it said
it was unsure — nothing else.

## 4. Verify — in parallel

**`verify` always. `verify-look` the moment anything reached the screen.**
⚠ **Never spawn the screen verifier on a stage that draws nothing** — a third of the round trips for nothing.

## 5. Judge

- **All pass** → the answer under `## Answer`, `Status: resolved`, and **one line on the map**. ⚠ **`wrap-up` then deletes the ticket's folder** — anything in it still true of the game moves out first
- **Any fail** → batch every finding into **ONE** message back to builder
- ⚠⚠ **Bounced three times without passing → stop and take it to the user.** Past that builder bends the
  code to get past verification, the commonest path to code that pretends to work

## What comes back to the user

**The report, not the diff**: what was built · what the nets said · what the verifiers found · **what was
not done** · where anyone was unsure.
⚠ **Pasting source into the chat means the context saving has already gone.**

**Then name the next step**: another open ticket → `build-loop` · the chunk's bar now true → `grilling` ·
the session ending → `wrap-up`.
