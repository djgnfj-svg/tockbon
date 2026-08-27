---
name: scout
description: Find how others already did this — three worked cases with sources, and at least one who did the opposite. Use when the user asks 남들은 어떻게 / 다른 게임은 / 레퍼런스 / 사례 찾아줘, and whenever a technique the user has not named is about to be recommended or built.
---

# scout — how others already did it

⚠⚠ **Dispatch it, do not read it here.** Send the **`research`** agent and take back **the findings only**.
The moment a search result lands in this session's window, the context this skill exists to save is gone.

⚠ **`research` is the outside half and it never answers from memory.** Anything that could be settled by
reading this repo is `survey` and its **`lookup`** agent — a different agent, on purpose.

## When it is required, not optional

**`CLAUDE.md` already carries the rule**: never recommend a technique the user has not named without first
checking how others do it. **This skill is that check** — the rule had no skill behind it until now.

**Required** when the answer would introduce a technique, a system, or a shape the user has not named.
**Skipped** when the user named the thing themselves — and **say out loud that it was skipped**, so a
silent skip never reads as a check that passed.

## What comes back, in this shape

| | |
|---|---|
| **Three cases or more** | **Who · what they did · how it actually turned out · the source.** A case with no source is not a case |
| **One opposite case or more** | **Somebody who did not do it, or did it and took it back**, and why |
| **One line of conclusion** | What the cases together say for the thing at hand |

⚠⚠ **The user is new to making games, so a claim with no source cannot be argued with.** That is why the
count is three and not one, and why the opposite case is required.

⚠ **The opposite case belongs in the FINDINGS, never attached to a recommendation.** The reply rule
forbids a "the case against" clause hanging off a recommendation; it does not forbid the research from being complete.
When the case against is strong enough to matter, it becomes a fork in a question, not a footnote.

## Primary sources first

**A developer's own talk, postmortem, or writing.** A summary blog is a pointer — follow it to the thing
it summarises and cite that. **This repo already leans on three**: the Bad North talk, Kingdom Two Crowns,
and how Sea of Thieves builds its water.

## Where it lands

**Into the ticket that asked for it**, under the ticket heading `## 남들은 어떻게 하나` (the tickets are Korean, so the heading is). **No ticket in play → the findings
come back in conversation and nowhere else** — a research file nobody asked for is a file nobody reads.
