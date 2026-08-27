---
name: breakdown
description: Break one roadmap chunk into tickets — scout outside, survey inside, settle the shape with the user, then write them. Use when the user says 쪼개자 / 분해하자 / 티켓 만들자 / 이번 주 목표 나누자, or when the chunk they are about to work has no ticket under it.
---

# breakdown — one chunk, into tickets

**`compass` names the chunk. This skill turns it into tickets. `build-loop` takes one ticket from here.**

⚠⚠ **One chunk per run.** A chunk whose turn has not come gets reversed before anyone reaches it, and
splitting it spends a round on work that will be thrown away.

## 1. Take the bar

Read the chunk's row in `docs/plan/roadmap.md`. **Its 「무엇이 되면 끝인가」 line is the bar**, and every
ticket you write serves it. Read the open tickets in `docs/plan/tickets/` too, so the numbering continues
and nothing already open is written twice.

## 2. Look outside and inside — both, at once

**Send `survey` and `scout` together and wait for both.** They read in their own windows; only their
findings come back here.

| | Skill | When |
|---|---|---|
| **안** | `survey` | **Always.** What already stands here, what already died, which net measures it, which green went false |
| **바깥** | `scout` | **When the chunk needs a technique the user has not named.** Skipped otherwise — and say that it was skipped |

⚠⚠ **This step is why the tickets come out right.** A chunk split without it produces tickets that rebuild
what already exists, or that invent a shape nobody has ever shipped.

**Done when both findings are in hand**, or when the skip is stated out loud.

## 3. Settle the shape with the user — **then stop**

**Put the findings to the user and ask how they want it built.** One grilling round: the frontier of
decisions this chunk forces, each with a recommendation and a reason.

⚠⚠ **Stop here and wait.** The tickets are written from the user's answers, not from your reading of the
findings. **A run that reaches step 4 without an answer from the user has skipped the only step that makes
the tickets theirs.**

⚠ **Where the user has judged this thing before, that judgement counts as an answer** — quote it rather
than asking again.

## 4. Sort each piece into one of two kinds

| Kind | `Type:` | The answer is | Who answers |
|---|---|---|---|
| **결정 티켓** | `grilling` | **무엇을 만들지** | ⚠⚠ **the user, in conversation** |
| **작업 티켓** | `task` | **코드** | an agent, through `build-loop` |

⚠⚠ **A question the user must answer never becomes a `task`.** That is the mistake this skill exists to
prevent: a decision written as a build order gets guessed at, and the guess reaches the screen before
anyone notices it was a guess.

**A 결정 티켓 holds what only the user can decide** — where a piece merely needs a fact, step 2 already
went and got it.

## 5. Write the files

One file per ticket at `docs/plan/tickets/NN-<english-slug>.md`, numbered on from the last:

```
Type: task | grilling
Status: open
Blocked by: NN, NN        ← only when it is genuinely blocked

# <한국어 제목>

## 무엇이 되면 끝인가
<one line — for a 결정 티켓 this is the question the user answers>

## 왜 이 티켓이 있나
<the roadmap chunk it serves, and what breaks without it>

## 지금 어떻게 돼 있나
<from `survey` — what stands, what died, what measures it>

## 남들은 어떻게 하나
<from `scout`, with sources — this section is absent when scout was skipped>
```

**Body in 한국어**, slug in English. **Where the user has judged this thing before, quote them verbatim** —
their own words about a game are a measurement, and this repo has had very few of them.

## 6. Fill the roadmap's 티켓 column

The chunk's row lists its ticket numbers. **A row still saying 없음 after this skill ran means the run did
not finish.**

## Done

**Done when the chunk's bar is true once every ticket you wrote is resolved** — say that out loud against
the list before stopping, and add whatever is missing.

Then hand back: **결정 티켓 → the user answers it in conversation** · **작업 티켓 → `build-loop`.**
