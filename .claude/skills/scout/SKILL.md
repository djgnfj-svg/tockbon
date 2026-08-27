---
name: scout
description: Find how others already did this — three worked cases with sources, and at least one who did the opposite. Use when the user asks 남들은 어떻게 / 다른 게임은 / 레퍼런스 / 사례 찾아줘, and whenever a technique the user has not named is about to be recommended or built.
---

# scout — how others already did it

⚠⚠ **Dispatch it, do not read it here.** Send a subagent, and take back **the findings only**. The moment
a search result lands in this session's window, the context this skill exists to save is gone.

## When it is required, not optional

**`CLAUDE.md` already carries the rule**: never recommend a technique the user has not named without first
checking how others do it. **This skill is that check** — the rule had no skill behind it until now.

**Required** when the answer would introduce a technique, a system, or a shape the user has not named.
**Skipped** when the user named the thing themselves — and **say out loud that it was skipped**, so a
silent skip never reads as a check that passed.

## What comes back, in this shape

| | |
|---|---|
| **사례 셋 이상** | **누가 · 무엇을 했나 · 실제로 어떻게 됐나 · 출처.** A case with no source is not a case |
| **반대 사례 하나 이상** | **안 한 곳, 또는 하다가 뺀 곳**, and why |
| **결론 한 줄** | What the cases together say for the thing at hand |

⚠⚠ **The user is new to making games, so a claim with no source cannot be argued with.** That is why the
count is three and not one, and why the opposite case is required.

⚠ **The opposite case belongs in the FINDINGS, never attached to a recommendation.** The reply rule
forbids a 「반대 근거」 hanging off a recommendation; it does not forbid the research from being complete.
When the case against is strong enough to matter, it becomes a fork in a question, not a footnote.

## Primary sources first

**A developer's own talk, postmortem, or writing.** A summary blog is a pointer — follow it to the thing
it summarises and cite that. **This repo already leans on three**: the Bad North talk, Kingdom Two Crowns,
and how Sea of Thieves builds its water.

## Where it lands

**Into the ticket that asked for it**, under `## 남들은 어떻게 하나`. **No ticket in play → the findings
come back in conversation and nowhere else** — a research file nobody asked for is a file nobody reads.
