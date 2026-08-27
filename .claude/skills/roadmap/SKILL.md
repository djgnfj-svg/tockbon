---
name: roadmap
description: Check the roadmap against what actually happened — where the map has drifted, which stretch of the way has no ticket, and what December still owes. Use when the user says 로드맵 점검 / 로드맵 보자 / 로드맵 맞나 / 12월까지 되나, or asks whether the plan still holds.
---

# roadmap — check the way, do not walk it

**`compass` answers "what do I do now". This skill answers "is this way still right".** It reports on the map;
it never edits the map, opens a ticket, or writes code.

⚠⚠ **An audit is not the work.** The only finding that stops the user is one that **blocks code from being
written**. Balance, fun, and polish are judged by playing, not by reading — leave them out.

## Read

1. **The roadmap** — `docs/plan/roadmap.md`. Every chunk, its bar, its tickets, its order.
2. **Every ticket** — `docs/plan/tickets/*.md`, `Status:` line included.
3. **The decision log and the commits** — `docs/plan/log.md` and
   `git log --oneline --since=<the log's last dated row>`.

**Done when every chunk of the roadmap has been checked against a commit or a ticket.**

## The three findings, and only these three

| Finding | How you know |
|---|---|
| **Drift** | The map states something the commits contradict, or a decision landed in chat and never reached the map |
| **Gap** | A stretch the roadmap needs before December that **no ticket covers** |
| **Remaining** | What December still owes, counted off the map's own list |

⚠ **A `Status:` line the commits disagree with is drift, not a bookkeeping error** — say which one is
true and how you know.

## Answer

**Korean**, three sections printed under these exact headings, in this order — **드리프트 · 구멍 · 남은 것.** Each finding is one line, and
each names the file or commit it came from.

**Where a section is empty, say it is empty.** A clean section is a measurement.

⚠⚠ **The map is not edited here.** Fixing what this skill finds is the user's call, taken after they read
it — the repair is a later round, and often a ticket.
