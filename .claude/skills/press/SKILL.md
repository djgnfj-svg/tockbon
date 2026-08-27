---
name: press
description: Put on the table what the user did not know to put there — the decisions this direction forces that they have not seen yet, each with a recommendation. Use when the roadmap is being set, when today's work is being chosen, and when work is being split into tickets. Other skills call this one; the user also calls it with 캐물어줘 / 더 물어봐 / 내가 놓친 거 / 뭐 더 정해야 돼.
---

# press — **the angles the user cannot ask for**

## ⚠⚠ This is not `grilling`, and the difference is the whole point

| | Works on | Fails by |
|---|---|---|
| **`grilling`** | **What is already on the table.** A decision tree of what the user named | Asking about things they already settled |
| **`press`** | ⚠⚠ **What is NOT on the table.** The decisions this direction forces that they have not seen | Never running, so a fork is discovered a month late |

**The user is new to making games and has said so.** ⇒ **They cannot ask for the angle they have never
seen.** *"So this too, or that too?"* is the shape they asked for, and it is a shape only somebody who has
looked at how this is normally done can produce.

## When it runs

| Moment | Which skill calls it |
|---|---|
| **The roadmap is being set or repaired** | `roadmap` |
| **Today's or this week's work is being chosen** | `compass` |
| **Work is being split into tickets** | `wrap-up` |

⚠ **A caller runs it once and only when the user is actually deciding.** ⚠⚠ **Never bolt it onto an
ordinary reply** — the user killed the every-reply question round on 2026-08-27 for exactly that reason.

## The method — **look first, then ask**

⚠⚠ **A question invented from your own head is worth nothing here.** It reproduces what the user already
thought of, which is the one thing they do not need.

1. **Send the `research` agent.** What does everyone building this kind of thing have to decide at this
   point, and what do they disagree about? **That disagreement is the question.**
2. **Send the `lookup` agent.** What has this repo already settled, already tried, already reversed?
   ⚠⚠ **A thing they already decided is not a question** — quote their old answer instead of asking again.
3. **Subtract.** What is left — forced by the direction, not settled here, not already asked — is the round.

**Two to five questions. Never more.** ⚠ **The user reads these; a wall of them is the failure mode that
got the previous version deleted.**

## The shape — **the user's own, given 2026-08-24**

⚠ **The labels stay Korean**: they are printed to the user, who reads Korean.

```
---
**질문 1** : <one line>
**추천** : <one line>
**왜** : <one line>

**질문 2** : <one line>
**추천** : <one line>
**왜** : <one line>
```

- **One line each.** Reasoning that does not fit goes in the body above, never in these lines
- ⚠⚠ **Every question carries a recommendation.** A bare question hands the work back to the user, and
  they are the one person here who cannot answer it from experience
- ⚠ **No "the case against" under the recommendation.** The user killed that on 2026-08-22 — it turned
  every recommendation into something they had to re-decide. **When the case against is strong enough to
  matter, the fork IS the question**
- ⚠ **Never ask what the repo can answer.** That is `lookup`'s job and it already ran

## After the round

**Their answers are the decision.** ⚠⚠ **Write them where they belong the moment the conversation is
finished, not during it** (2026-08-27, the user: *"what you do on your own is what comes after the
conversation is finished"*) — **the map and the tickets are `wrap-up`'s hands, not this skill's.**

⚠ **A question they did not answer is not a silent yes.** Carry it to the next round or write it into the
ticket as still open.
