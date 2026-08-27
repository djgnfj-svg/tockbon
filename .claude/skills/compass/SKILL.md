---
name: compass
description: Say where the work stands — this week's goal, then every open ticket ranked by priority. Use when the user asks 뭐하지 / 뭐 해야 되지 / 뭐 한다고 했지 / 이번 주 목표 / 지금 어디까지 했지, or otherwise opens a session asking what to do.
---

# compass — where the work stands

**This skill reads and reports.** Every line it produces comes from a file already on disk.

## Read exactly three

1. **The roadmap** — `docs/plan/roadmap.md`. It holds **this week's chunk** and the bar that
   closes it. This is the only place the week is stated.
2. **Every ticket** — `docs/plan/tickets/*.md`. Each carries a `Status:` line
   (`open` · `claimed` · `resolved`) and may carry `Blocked by: NN, NN`.
3. **The decision log's last five rows and the last five commits** — the table at the foot of
   `docs/plan/log.md`, and `git log --oneline -5`. They say what actually landed.

**Done when every ticket file has been opened**, not a sample of them.

## Rank

**Ready** = `Status: open`, and every ticket named in its `Blocked by:` line is `resolved`.

1. **Named by this week's section.** The map pins the week; a ticket it names outranks every other.
2. **Ready**, lowest number first.
3. **Claimed or blocked**, last, each with the thing holding it.

⚠⚠ **The log's last decisions outrank the ticket numbers.** The user routinely ends a session by deciding
what the next one does. That line is the answer even when no ticket covers it — put it at the top as its
own entry and say it has no ticket.

**Where this week's chunk has no ticket at all, say so and call `press`** — a chunk with no ticket means
the decisions under it were never put to the user, and **that round is what produces the tickets.**
⚠ **`wrap-up` writes them**, after the user has answered — not during the conversation.

## Answer

**Korean, and this shape:**

```
**이번 주** : <one line, from the map>

**1. <ticket name>**
**목표** : <one line — what closing it changes>

**2. <ticket name>**
**목표** : <one line>
```

**Two lines per ticket**, every open ticket listed. **The ranked list is the whole answer.**
