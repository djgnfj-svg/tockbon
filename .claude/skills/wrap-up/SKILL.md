---
name: wrap-up
description: Closes the session — verifies and closes this session's tickets and tasks, repairs the map and the log, clears the loose images, runs the nets, commits. Use whenever the user's message contains 마무리 — "마무리", "마무리하자", "마무리했어", "마무리 좀" — or says "wrap up".
---

# 마무리 — the session ends and the state has to end with it

**The work finishes and nothing else moves.** A ticket stays `claimed`; the map still says the week is
open; the next session believes all of it and rebuilds what is already built.

⚠⚠ **Run this skill, do not remember it.** It was run from memory once (2026-08-31) and **the ticket
and map half fell out of the round entirely** — five commits landed and neither the map nor the log
was opened.

## ⚠⚠ The rule the order exists for

**A ticket is not closed because the work happened. It is closed because it was CHECKED and then
closed** (2026-08-31, the user: *"verifying this session's tickets and tasks and closing them has to be
part of the wrap-up"*).

**Ten steps, in this order, one at a time. Say the result of each out loud before moving to the next.**

---

## 1. What actually finished

**List it: built · fixed · deleted · decided.** ⚠ **"Almost done" goes on the not-done list.**
**Done when** the two lists are written and nothing sits in both.

## 2. Open every ticket this session touched

**One file at a time.** `docs/roadmap/task-NN-*/MM-*/NN-MM.ticket.md`.
**Done when** every ticket touched this session has been opened and read, and you can name each one.

## 3. Check each ticket against its own `## Done when`

⚠⚠ **Read that section and check it, do not recall it.** Run the check, look at the screen, read the
number. **A ticket whose bar was never checked is not closed** — it is put back on the open list with
one line saying what is missing.

**Done when** every ticket from step 2 has a verdict: **met** or **not met, and what is missing.**

## 4. Close the ones that passed

- **`Status:` → `resolved`**, and the answer written under `## Answer`
- ⚠ **The file never moves between folders.** Status is a line inside it
- **What the ticket produced stays in that ticket's folder** — the screenshot, the measurement, the note

**Done when** no ticket that passed step 3 is still `open` or `claimed`.

## 5. Check the task above them

**Open `NN.task.md`.** Is every ticket in its table now `resolved`?

- **Yes** → the task is done. Set its `Status:` and flip its row on the map to ✅
- **No** → say which tickets are still open. **A task with one open ticket is an open task**

**Done when** every task that owns a ticket from step 2 has been opened and its status is right.

## 6. The map — `docs/roadmap/README.md`

**Opened every session, whatever the round built.** ⚠ The failure this pays for: a round touched no
`src/`, so 「repair the docs」 read as already-done, and the map's opening section was a day stale with
a net count of 59 against a measured 63.

- **This week's row** — does its status still match what happened
- **The opening section** — rewrite it for the session that opens next
- **What is still the user's to answer** — every open question, by name
- **Any number that went stale** — net counts most of all

**Done when** all four have been looked at and each is either changed or said to be already right.

## 7. The log — `docs/roadmap/log.md`

**What happened and why.** ⚠⚠ **The user's own words go here and nowhere else** — translated to
English, with the citation kept.

⚠ **A round that decided nothing still writes an entry.** 「nothing was decided, here is what is still
open」 is exactly what the next session needs.

**Done when** this session has an entry with a date on it.

## 8. New tickets, dead references, loose pictures

- **New tickets** — anything the user decided that no ticket holds. ⚠ **You are writing down answers,
  not inventing work.** A question the user must answer is `Type: grilling`, never `task`
- ⚠⚠ **A ticket is NOT a day** (2026-09-01, the user: 「티켓은 여러 개여도 돼. 태스크가 두 개라는 거지.
  주당」). **Two tasks a week; a task carries as many tickets as the work takes.** ⚠ **Where a task is
  cut is still the user's, never yours**
- **Dead references** — does any doc or comment point at what you deleted or renamed
- **Loose pictures** — `ls image*.png image*.jpg` (they are gitignored, so `git status` cannot see
  them). ⚠ **Check how many there are and ask which ones mattered** — that is the user's call
- ⚠⚠ **`CLAUDE.md` — do not touch it.** Only the user adds to it. If something belongs there, say so
  in the report and stop
- **Acceptance** — ask whether they looked, then [`ACCEPTANCE.md`](ACCEPTANCE.md)
- **Memory** — delete what became wrong. **Do not add.** What can live in the repo lives in the repo

**Done when** each of the seven has an answer, including 「doesn't apply」.

## 9. Run the nets

```
powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1
```

- **Never commit a red you caused.** If it fails, stop and take it to the user
- ⚠ **Do not fix the net to make it pass**
- ⚠⚠ **A red that was already there is reported, not a blocker** — measure it at the START of the
  session too, and when the counts match and this session touched none of those files it is
  pre-existing. **Say the numbers out loud either way; never call it green**
- ⚠ **Where the nets cannot run at all, say so and say why** — an unrun suite is not a passing one

**Done when** the numbers are written down, before and after.

## 10. Commit, then stop

- **`git status` first** — anything unintended mixed in
- **Straight to `main`. Do not branch, do not ask** — settled by the user. **Asking is itself friction**
- **Korean message**, saying what was done and why
- ⚠ **Do not push.** Only when the user says so

## The report

**What finished · what didn't and why · what is still the user's to answer · candidates for next.**

⚠ **Never write unfinished as finished.** The moment a doc says "done", the next session believes it.
