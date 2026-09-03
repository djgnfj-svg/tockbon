---
name: wrap-up
description: Closes the session — verifies and closes this session's tickets and tasks, deletes the closed ticket folders, repairs the map, clears the loose images, runs the nets, commits — and in a worktree pushes and opens the PR. Use whenever the user's message contains 마무리 — "마무리", "마무리하자", "마무리했어", "마무리 좀" — or says "wrap up".
---

# 마무리 — the session ends and the state has to end with it

**The work finishes and nothing else moves.** A ticket stays `claimed`; the map still says the week is
open; the next session believes all of it and rebuilds what is already built.

⚠⚠ **Run this skill, do not remember it.** Run from memory once, the ticket and map half fell out of the
round entirely — five commits landed and the map was never opened.

⚠⚠ **A ticket is closed because it was CHECKED, never because the work happened.**

⚠⚠ **This repo keeps NO log.** What a round decided goes into the ticket while it is open, and the map's
✅ is all that survives it. **Do not write a decision log, a session summary, or a failure diary.**

**Nine steps, in this order, one at a time. Say each result out loud before moving on.**

## 1. What actually finished

**List it: built · fixed · deleted · decided.** ⚠ **"Almost done" goes on the not-done list.**
**Done when** both lists are written and nothing sits in both.

## 2. Open every ticket this session touched

One file at a time. **Done when** each has been opened and read, and you can name it.

## 3. Check each against its own `## Done when`

⚠⚠ **Read that section and check it, do not recall it.** Run the check, look at the screen, read the
number. **A ticket whose bar was never checked is not closed** — it goes back on the open list with one
line saying what is missing.

**Done when** every ticket has a verdict: **met**, or **not met and what is missing**.

## 4. Close the ones that passed — **and delete them**

- ⚠⚠ **A closed ticket's FOLDER is deleted, screenshots and all.** What survives is its row on the map,
  flipped to ✅ with at most one line saying what it built
- ⚠ **Anything in that ticket that is still TRUE of the game moves first** — to `GLOSSARY.md` if it is a
  word, to the task file if it is a settled rule, to a new ticket if it is unfinished. **Then delete**
- ⚠ **Do not mark it `resolved` and leave the file.** That is what buried this repo once already
- ⚠⚠ **Clear every `Blocked by:` line that names it.** The blocker is satisfied, and a `Blocked by:`
  pointing at a deleted ticket is what `net_process` reds on

**Done when** nothing that passed step 3 is still on disk, and the map says what each one built.

## 5. Check the task above them

**Open `NN.task.md`.** Every ticket in its table now closed and deleted?

- **Yes** → flip its row on the map to ✅ and **delete the whole task folder**
- **No** → name the ones still open. **A task with one open ticket is an open task**

## 6. The map

**Opened every session, whatever the round built.** ⚠ The failure this pays for: a round touched no
`src/`, so 「repair the docs」 read as already-done and the map went a day stale with a net count of 59
against a measured 63.

- **This week's row** — does its status still match what happened
- **The open-ticket table** — a row per open ticket, and no row for one that no longer exists
- **What is still the user's to answer** — every open question, by name
- **Any number that went stale** — net counts most of all

⚠⚠ **The map says what IS, never what happened.** No session sections, no dates, no 「이 라운드가」.
**If you are about to write a paragraph explaining an earlier round, delete it instead.**

**Done when** all four are either changed or said to be already right.

## 7. New tickets, dead references, loose pictures

- **New tickets** — anything the user decided that no ticket holds. ⚠ **You write down answers, you do
  not invent work.** A question the user must answer is `Type: grilling`, never `task`
- ⚠⚠ **A ticket is NOT a day.** **Two tasks a week; a task carries as many tickets as the work takes.**
  ⚠ **Where a task is cut is the user's, never yours**
- **Dead references** — does any doc or comment point at what you deleted or renamed
- **Loose pictures** — `ls image*.png image*.jpg` (gitignored, so `git status` cannot see them).
  ⚠ **Say how many and ask which mattered** — that is the user's call
- ⚠⚠ **`CLAUDE.md` — do not touch it.** Only the user adds to it. If something belongs there, say so and stop
- **Acceptance** — ask whether they looked, then [`ACCEPTANCE.md`](ACCEPTANCE.md)
- **Memory** — delete what became wrong. **Do not add.** What can live in the repo lives in the repo

**Done when** each of the seven has an answer, including 「doesn't apply」.

## 8. Run the nets — **this is the batch**

⚠⚠ **No net is written per ticket** (`CLAUDE.md`), so this run is where the suite earns its keep.
**Never skip it, and never add a net here to cover the round.**

```
powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1
```

- **Never commit a red you caused.** If it fails, stop and take it to the user
- ⚠ **Do not fix the net to make it pass**
- ⚠⚠ **A red that was already there is reported, not a blocker** — measure at the START of the session
  too, and when the counts match and this session touched none of those files it is pre-existing.
  **Say the numbers either way; never call it green**
- ⚠ **Where the nets cannot run at all, say so and say why** — an unrun suite is not a passing one

**Done when** the numbers are written down, before and after.

## 9. Commit, then stop

- **`git status` first** — anything unintended mixed in
- **Korean message**, saying what was done and why
- ⚠⚠ **Where it lands depends on ONE thing: is this session in a worktree.** Check it, do not assume —
  the working directory is under `.claude/worktrees/` or it is not

**On `main` — the ordinary case**

- **Straight to `main`. Do not branch, do not ask** — settled by the user. **Asking is itself friction**
- ⚠ **Do not push.** Only when the user says so

**In a worktree**

- **Commit to the worktree's own branch, push it, and OPEN THE PR.** ⚠⚠ **Do not ask** — the user
  settled this: 「앞으로 마무리하면 그 PR을 띄우도록하자 그 워크트리상태면」
- ⚠⚠ **Never merge it and never push to `main`** — merging is the user's
- **The PR body is what the report says**, in Korean: what was built · what the nets measured, before
  and after · what is still the user's to answer. ⚠ **Not a session diary** — the same rule the map obeys
- ⚠ **If a PR already stands on that branch, the pushed commits join it** — say so instead of making one
- **Hand back the PR's URL on the last line of the report.** A branch nobody was given a link to is a
  branch nobody merges

## The report

**What finished · what didn't and why · what is still the user's to answer · candidates for next**, and
**the PR link when there is one.**
⚠ **Never write unfinished as finished.** The moment a doc says "done", the next session believes it.
