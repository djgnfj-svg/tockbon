---
name: wrap-up
description: Closes out the session. Repairs the docs that drifted, writes the new tickets, clears the loose images, runs the nets, commits. Use whenever the user's message contains 마무리 — "마무리", "마무리하자", "마무리했어", "마무리 좀" — or says "wrap up".
---

# Wrap-up

**The work finishes and the state never changes.** A ticket stays `claimed`; a doc points at a deleted
file; the next session believes all of it.

⚠⚠ **Two things only: repair what drifted, then commit.** Anything that is not a document gone wrong is
not this skill's business.

## 1. List what actually finished

Built, fixed, deleted, decided. **"Almost done" is not done.** Do not mix done and not-done.

## 2. Repair the docs

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

- `docs/plan/tasks/NN-<english-slug>/MM-<english-slug>.md` — **inside the task it serves**, numbered on
  from the last ticket **in that task**, starting at `01`. Its task's number goes into the roadmap
- **A ticket is one day.** ⚠ **If it does not fit in a day, the user says how it splits** — never you
- **A task with no folder yet** gets `NN-<english-slug>/TASK.md` first, one sentence saying what is on
  screen when the task ends
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
