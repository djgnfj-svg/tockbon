---
name: roadmap
description: Draw the whole way to December, check it against what happened, and lay it out as numbered tasks — two a week — with as many tickets under each as the work takes. Use when the user says 로드맵 점검 / 로드맵 보자 / 로드맵 정비 / 로드맵 다시 / 태스크 나누자 / 일단위로 / 12월까지 되나, or asks whether the plan still holds.
---

# roadmap — draw the whole way, then cut it into tasks

**`compass` answers "what do I do now". This one answers "is this way still right, and what are the
tasks".** ⚠⚠ **It never edits a file, opens a ticket, or writes code** — `wrap-up` writes what it
settles, after the conversation.

⚠⚠ **An audit is not the work.** The only finding that stops the user is one that **blocks code from
being written.** Balance, fun and polish are judged by playing — leave them out.

## Three layers

| Layer | What it is |
|---|---|
| **The roadmap** | **The whole way to December, on one page.** The tasks fall out of it |
| **A task** | **One numbered folder.** `NN.task.md` says what is on screen when it ends |
| **A ticket** | **One piece of the task, and a folder too.** What it produced piles up beside it |

**A ticket's number is unique inside its task, never across the repo** — task 03's second is `03-02`,
and task 04 has its own `02`.

## ⚠⚠ The grain is the TASK, not the ticket

> *"I never said a ticket is one a day. There can be many tickets. What is two is the TASKS. Per week."*
> (2026-09-01, the user)

⇒ **Two tasks a week, and a task carries as many tickets as the work takes** — one, or eight, and several
may be finished in one sitting.

⚠⚠ **Do not split a ticket to make it fit a day, and do not count tickets against the days left in the
week.** ⚠ **How a task is cut, in what order, and where it stops is never yours** — that was rolled back
twice, 2026-08-30 and 2026-08-31.

## Read

1. **The roadmap** — every row, every chunk, its bar, its tasks, its order
2. **Every task and every ticket in it**, `Status:` line included. ⚠ **A task folder with no ticket yet is
   a measurement, not a fault** — say so
3. **The commits since the map was last true** — ⚠ **there is no decision log**; the commits are the record
4. **The nets, run once.** ⚠⚠ **The map's net counts go stale faster than anything else on it** —
   measured 2026-08-30, the map said 실패 79 against a real 통과 629 · 실패 59, and named three red nets
   when seven of eleven were red

**Done when every row has been checked against a commit or a task.**

## The three findings, and only these three

| Finding | How you know |
|---|---|
| **Drift** | The map states something the commits contradict, or a decision landed in chat and never reached the map |
| **Gap** | A stretch December needs that **no task covers** |
| **Remaining** | What December still owes, counted off the map's own list |

⚠ **A `Status:` line the commits disagree with is drift, not a bookkeeping error** — say which is true
and how you know.

## One task, one thing

**A task's row is a sentence the user could say out loud** — *짐승이 오고 싸운다* · *부대를 쪼개고 합친다*
· *포탑*. **That sentence is the whole row.**

**A row may carry**: what is on screen when the task ends, in one sentence · which chunk it serves and its
status mark · **the tickets that already exist**, never ones invented to fill the row.

**What belongs to the user instead**: how many tickets and in what order · how many days · how far the
task reaches · which of several things named in one sentence comes first.

⚠⚠ **Cutting a task into tickets is the user's call, never yours** (2026-08-30, the user: *"you deciding
details on your own must never happen"*). Measured the same day: a stretch was cut into five ordered
tickets with acceptance lists, **every cut the model's own**, and the round was rolled back.

⚠ **A measurement is not a decision.** A number off a tombstone or a net run belongs in the row; a scope
call, an ordering or an acceptance bar does not.

⚠ **Every task is judged against the core fun line at the top of the map.** A task that does not move it
is a task to say so about. **The second dead game shipped 3541 green checks and was not fun.**

## Answer — Korean, in this order

1. **드리프트 · 구멍 · 남은 것** — three sections under those exact headings, one line per finding, each
   naming the task, net or commit it came from. **An empty section is said to be empty**
2. **The task table** — every task to December, numbered, one line each, one thing each
3. **The nearest task's tickets** — the ones that already sit in it. ⚠ **Do not assign them days**, and
   **where its cut is not settled, say so and stop**
4. **What is still the user's to answer** — the cuts, the orderings, the day counts, the stopping points

## Then keep asking — the report is not the end

**A drift report says what is wrong with the map. It does not help fill it.**

⚠⚠ **`grilling` runs whenever the map does not yet say what a task builds** — on the nearest undecided
task, not on every blank row at once. **A row that names a task but not a thing is not a plan**, and
neither is a task folder with no ticket.

⚠ **Skip `grilling` on a task the user already settled.** Re-opening a settled decision is the most
expensive thing this skill can do.
