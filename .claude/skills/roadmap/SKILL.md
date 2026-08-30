---
name: roadmap
description: Draw the whole way to December, check it against what happened, and lay it out as numbered tasks whose tickets are one day each. Use when the user says 로드맵 점검 / 로드맵 보자 / 로드맵 정비 / 로드맵 다시 / 태스크 나누자 / 일단위로 / 12월까지 되나, or asks whether the plan still holds.
---

# roadmap — draw the whole way, then cut it into tasks

**`compass` answers "what do I do now". This skill answers "is this way still right, and what are the
tasks".** It reports and it designs; **it never edits a file, opens a ticket, or writes code** —
`wrap-up` writes what this settles, after the conversation.

⚠⚠ **An audit is not the work.** The only finding that stops the user is one that **blocks code from
being written**. Balance, fun, and polish are judged by playing, not by reading — leave them out.

## ⚠⚠ Three layers, and the two-tier number that holds them

| Layer | What it is | Where it lives |
|---|---|---|
| **The roadmap** | **The whole way to the December demo, on one page.** The tasks fall out of it | `docs/roadmap/README.md` |
| **A task** | **One numbered folder.** `NN.task.md` says what is on screen when it ends; the ticket folders that build it sit beside it | `docs/roadmap/task-NN-<english-slug>/NN.task.md` |
| **A ticket** | **One day of work, and a folder too.** `NN-MM.ticket.md` describes it; **what it produced piles up beside it** — the screenshot, the measurement, the note that says how it went | `docs/roadmap/task-NN-<slug>/MM-<english-slug>/NN-MM.ticket.md` |

**A ticket's number is unique inside its task, never across the repo.** Task `03`'s second ticket is
**03-02**, and task `04` has its own `02`.

⚠⚠ **A ticket is one day.** The week was the grain until 2026-08-30 and it did not hold — **a week is
too big to keep quality inside it.** ⇒ **A ticket that cannot be finished in a day is two tickets**,
and cutting it is the user's call, not yours.

⚠⚠ **`docs/plan/` and its flat `tickets/` folder are both gone.** Forty-five ticket files were deleted
2026-08-30 (the user: *"deleting them all would be fine"*), the folder became `docs/roadmap/` on
2026-08-31, and **the map's ticket-number column is dead references.** ⚠ **Task folders sit directly
under `docs/roadmap/` — there is no `tasks/` layer.**

## Read

1. **The roadmap** — `docs/roadmap/README.md`. Every row, every chunk, its bar, its tasks, its order.
2. **Every task** — `docs/roadmap/task-*/NN.task.md` and the `NN-MM.ticket.md` in every ticket folder inside it,
   `Status:` line included.
   ⚠ **Where a task folder holds no ticket yet, say so** — an empty task is a measurement, not a fault.
3. **The decision log and the commits** — `docs/roadmap/log.md` and
   `git log --oneline --since=<the log's last dated row>`.
4. **The nets, run once** — `powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1`.
   ⚠⚠ **The map's net counts go stale faster than anything else on it** — measured 2026-08-30, the map
   said 실패 79 and the run said **통과 629 · 실패 59**, and the map named three red nets when seven of
   eleven were red.

**Done when every row of the roadmap has been checked against a commit or a task.**

## The three findings, and only these three

| Finding | How you know |
|---|---|
| **Drift** | The map states something the commits contradict, or a decision landed in chat and never reached the map |
| **Gap** | A stretch the roadmap needs before December that **no task covers** |
| **Remaining** | What December still owes, counted off the map's own list |

⚠ **A `Status:` line the commits disagree with is drift, not a bookkeeping error** — say which one is
true and how you know.

## ⚠⚠ **One task, one thing** — the grain the map is drawn at

**A task's row is a sentence the user could say out loud**: *짐승이 오고 싸운다* · *부대를 쪼개고
합친다* · *포탑*. **That sentence is the whole row.**

⚠⚠ **Cutting a task into tickets is the user's call, never yours** (2026-08-30, the user: *"the tickets
have too much detail in them, starting from a bigger chunk is right, you deciding details on your own
must never happen"*). **Measured the same day**: a stretch was cut into five ordered tickets, each with
its own acceptance list, and **every cut and every ordering was the model's own** — the round was rolled
back.

**What a task row may carry**

- **What is on screen when the task ends**, in one sentence
- **Which chunk it serves**, and its status mark
- **The tickets that already exist inside it** — never tickets invented to fill the row

**What belongs to the user instead**

- **How many tickets a task is cut into, and in what order**
- **How many days a task takes**, and which day each ticket lands on
- **How far a task reaches** — where it stops and the next begins
- **Which of several things named in one sentence comes first**

⚠ **A measurement is not a decision.** A number read out of a tombstone or a net run belongs in the
row; **a scope call, an ordering, or an acceptance bar does not.**

## ⚠ Every task is judged against one line

**The core fun line lives at the top of `docs/roadmap/README.md`.** A task that does not move it is a task to
say so about. ⚠⚠ **The second dead game shipped 3541 green checks and was not fun** — the cause was one
decision that cost nothing to make. **Read `docs/lessons-from-two-dead-games.md` before arguing a task
is worth its place.**

## Answer

**Korean**, in this order:

1. **드리프트 · 구멍 · 남은 것** — three sections under those exact headings. Each finding is one line
   and names the task, net or commit it came from. **Where a section is empty, say it is empty** —
   a clean section is a measurement.
2. **The task table** — every task to December, **numbered**, one line each, one thing each.
3. **The nearest task's days** — the tickets that already sit in it, one line each, one day each.
   ⚠ **Where its cut is not settled, say it is not settled** and stop. **Never fill the days yourself.**
4. **What is still the user's to answer** — the cuts, the orderings, the day counts, the stopping points.

## ⚠⚠ Then keep asking — **the report is not the end**

**A drift report tells the user what is wrong with the map. It does not help them fill it.**

**`grilling` runs whenever the map does not yet say what a task builds** (2026-08-29, the user: *"the
roadmap should grill — what gets built has to be asked, and asked again"*).

⚠⚠ **A row that names a task but not a thing is not a plan**, and **a task folder with no ticket in it
is not a plan either**. **`grilling` is what turns one of them into something a ticket can be cut from**
— run it on the nearest undecided task, not on every blank row at once.

⚠ **Skip `grilling` on a task the user already settled.** Re-opening a settled decision is the most
expensive thing this skill can do.

⚠⚠ **No file is edited here.** What this settles is written by `wrap-up`, after the conversation — the
repo's own rule, pointed out by the user twice.
