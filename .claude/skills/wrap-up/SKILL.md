---
name: wrap-up
description: Closes out the session. Repairs the docs that drifted, writes the new tickets, clears the loose images, runs the nets, commits. Use whenever the user's message contains 마무리 — "마무리", "마무리하자", "마무리했어", "마무리 좀" — or says "wrap up".
---

# Wrap-up

**The work finishes and the state never changes.** A ticket stays `claimed`; a doc points at a deleted
file; the next session believes all of it.

⚠⚠ **Two things only: repair what drifted, then commit.** Anything that is not a document gone wrong is
not this skill's business.

⚠⚠ **Run this skill, do not remember it.** It was run from memory once and **step 2's roadmap half fell
out of the round entirely** — the steps below are short precisely so there is no reason to skip loading them.

## 1. List what actually finished

Built, fixed, deleted, decided. **"Almost done" is not done.** Do not mix done and not-done.

## 2. Repair the docs

⚠⚠ **THE MAP AND THE LOG ARE WRITTEN EVERY SESSION, WITH NO EXCEPTION** (2026-08-31, the user: *"a
wrap-up is something you always do, and you were not doing it — from now on, do it"*).

**The failure this pays for, measured the same day**: a round built a docs folder and three labs,
touched no `src/`, and **「repair the docs」 read as already-done.** What was actually stale was
`docs/roadmap/README.md` — its opening section still said 「the next session opens here」 from the
previous night, its net counts were **59 against a measured 63**, and a roadmap conversation had been
**abandoned half-way with two questions open and nothing written down.**

⇒ **Two files are opened by name every time, whatever the round built:**

| File | What goes in, every session |
|---|---|
| **`docs/roadmap/README.md`** | What this session changed about the plan · **what is still the user's to answer** · any number that went stale |
| **`docs/roadmap/log.md`** | What happened and why, with the user's own words translated and kept |

⚠ **A round that decided nothing still writes both** — 「nothing was decided, and here is what is still
open」 is exactly what the next session needs. **A map left mid-conversation is drift, not a pause.**

- **Ticket `Status:`** — is a finished ticket still `claimed`
- **The roadmap's status column** — **flip every row that finished to ✅.** A row left unflipped is how
  the next session concludes the work never happened
- **Dead references** — does any doc or comment point at what you deleted or renamed this session
- ⚠⚠ **`CLAUDE.md` — do not touch it.** Not edit, not measure. **Only the user adds to it, and only when
  they say so.** If something must land there, name it in the report and stop
- **Acceptance** — ask whether they looked, then [`ACCEPTANCE.md`](ACCEPTANCE.md)
- **Memory** — **delete what became wrong. Do not add.** What can live in the repo lives in the repo

**Say you checked each, or say it doesn't apply.** Never skip silently.

## 3. Write the tickets

**Anything the user decided this session that no ticket holds.** ⚠ **You are writing down answers, not
inventing work** — open forks are `grilling`'s round, and that happens before this step.

- `docs/roadmap/task-NN-<english-slug>/MM-<english-slug>/NN-MM.ticket.md` — **a folder inside the task it
  serves**, numbered on from the last ticket **in that task**, starting at `01`. Its task's number goes
  into the roadmap
- ⚠ **What the ticket produced goes in that same folder** — the screenshot, the measurement, the note.
  **That is where a ticket says how it went**, and step 4's loose images land here instead of being cleared
- **A ticket is one day.** ⚠ **If it does not fit in a day, the user says how it splits** — never you
- **A task with no folder yet** gets `docs/roadmap/task-NN-<english-slug>/NN.task.md` first, one sentence
  saying what is on screen when the task ends. ⚠ **Task folders sit directly under `docs/roadmap/`**
- **Answer is code → `Type: task`. Answer is what to build → `Type: grilling`**, the user answers it
- ⚠⚠ **A question the user must answer never becomes a `task`** — it gets guessed at, and the guess
  reaches the screen before anyone notices it was a guess

## 4. Clear the loose images

**Pasted screenshots land in the repo root and pile up.** ⚠ **They are gitignored, so `git status` cannot
see them** — `ls image*.png image*.jpg` is the only way this step finds them.

- **A shot a decision was made from** → `docs/reference/YYYY-MM-DD-what-it-shows.png`
- **The rest** → delete
- ⚠⚠ **Count them and ask first.** Which shots mattered is the user's call

## 5. Run the nets

```
powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1
```

**Never commit a red you caused.** If it fails, stop and take it to the user. **Do not fix the net to
make it pass.**

⚠⚠ **A red that was already there is reported, not a blocker.** **Measure it at the start of the
session too** — when the counts come back identical and this session touched none of those files, it is
**pre-existing**, and holding the commit hostage to it only loses the session's work. **Say the numbers
out loud either way**; never call it green.

## 6. Commit — **and stop here**

- **Straight to `main`. Do not branch, do not ask** — settled by the user. **Asking is itself friction**
- `git status` first: anything unintended mixed in
- **Korean message**, saying what was done and why
- ⚠ **Do not push.** Only when the user says so

## 7. Report

What finished · **what didn't, and why** · candidates for next.

⚠ **Do not write unfinished as finished.** The moment a doc says "done", the next session believes it.
