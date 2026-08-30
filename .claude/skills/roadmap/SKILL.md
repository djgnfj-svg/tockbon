---
name: roadmap
description: Check the roadmap against what happened, then lay the way out again week by week, one thing per week. Use when the user says 로드맵 점검 / 로드맵 보자 / 로드맵 정비 / 로드맵 다시 / 주단위로 / 12월까지 되나, or asks whether the plan still holds.
---

# roadmap — check the way, then lay it out at week grain

**`compass` answers "what do I do now". This skill answers "is this way still right, and what is each
week".** It reports and it designs; **it never edits a file, opens a ticket, or writes code** —
`wrap-up` writes what this settles, after the conversation.

⚠⚠ **An audit is not the work.** The only finding that stops the user is one that **blocks code from
being written**. Balance, fun, and polish are judged by playing, not by reading — leave them out.

## Read

1. **The roadmap** — `docs/roadmap.md`. Every week, every chunk, its bar, its tickets, its order.
2. **Every ticket** — `docs/plan/tickets/*.md`, `Status:` line included.
3. **The decision log and the commits** — `docs/plan/log.md` and
   `git log --oneline --since=<the log's last dated row>`.
4. **The nets, run once** — `powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1`.
   ⚠⚠ **The map's net counts go stale faster than anything else on it** — measured 2026-08-30, the map
   said 실패 79 and the run said **통과 629 · 실패 59**, and the map named three red nets when seven of
   eleven were red.

**Done when every week of the roadmap has been checked against a commit or a ticket.**

## The three findings, and only these three

| Finding | How you know |
|---|---|
| **Drift** | The map states something the commits contradict, or a decision landed in chat and never reached the map |
| **Gap** | A stretch the roadmap needs before December that **no ticket covers** |
| **Remaining** | What December still owes, counted off the map's own list |

⚠ **A `Status:` line the commits disagree with is drift, not a bookkeeping error** — say which one is
true and how you know.

## ⚠⚠ **One week, one thing** — the grain this map is drawn at

**A week's row is a sentence the user could say out loud**: *짐승이 오고 싸운다* · *부대를 쪼개고
합친다* · *포탑*. **That sentence is the whole row.**

⚠⚠ **Slicing a week is the user's call, never yours** (2026-08-30, the user: *"the tickets have too
much detail in them, starting from a bigger chunk is right, you deciding details on your own must
never happen"*). **Measured the same day**: a week was cut into five ordered tickets, each with its own
acceptance list, and **every cut and every ordering was the model's own** — the round was rolled back.

**What a week row may carry**

- **What is on screen when the week ends**, in one sentence
- **Which chunk it serves**, and its status mark
- **The tickets that already exist for it** — never tickets invented to fill the row

**What belongs to the user instead**

- **How many pieces a week is cut into, and in what order**
- **How far a week reaches** — where it stops and the next begins
- **Which of several things named in one sentence comes first**

⚠ **A measurement is not a decision.** A number read out of a tombstone or a net run belongs in the
row; **a scope call, an ordering, or an acceptance bar does not.**

## ⚠ Every week is judged against one line

**The core fun line lives at the top of `docs/roadmap.md`.** A week that does not move it is a
week to say so about. ⚠⚠ **The second dead game shipped 3541 green checks and was not fun** — the cause
was one decision that cost nothing to make. **Read `docs/lessons-from-two-dead-games.md` before arguing
a week is worth its place.**

## Answer

**Korean**, in this order:

1. **드리프트 · 구멍 · 남은 것** — three sections under those exact headings. Each finding is one line
   and names the ticket, net or commit it came from. **Where a section is empty, say it is empty** —
   a clean section is a measurement.
2. **The week table** — every week to December, one line each, one thing each.
3. **What is still the user's to answer** — the slices, the orderings, the stopping points.

## ⚠⚠ Then keep asking — **the report is not the end**

**A drift report tells the user what is wrong with the map. It does not help them fill it.**

**`grilling` runs whenever the map does not yet say what a stretch builds** (2026-08-29, the user:
*"the roadmap should grill — what gets built has to be asked, and asked again"*).

⚠⚠ **A roadmap row that names a week but not a thing is not a plan.** **`grilling` is what turns one
of them into something a ticket can be cut from** — run it on the nearest undecided stretch, not on
every blank week at once.

⚠ **Skip `grilling` on a stretch the user already settled.** Re-opening a settled decision is the most
expensive thing this skill can do.

⚠⚠ **No file is edited here.** What this settles is written by `wrap-up`, after the conversation — the
repo's own rule, pointed out by the user twice.
