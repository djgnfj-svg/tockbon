---
name: survey
description: Report what this repo already holds at one spot — what stands, what already died, which net measures it, and which green went false here. Use when the user asks 지금 어떻게 돼 있어 / 이미 있나 / 뭐가 있지 / 코드 어떤지 봐줘, and before any ticket is written.
---

# survey — what is already here

⚠⚠ **Dispatch it, do not read it here.** Send the **`lookup`** agent and take back **the findings only.**
A 1900-line view file opened in this session costs more than everything this skill saves.

⚠ **`lookup` is the inside half and it never touches the web.** When the question turns out to need a
fact from outside this repo, that is `scout` and its **`research`** agent — a different agent, on purpose.

## Why it exists

**A piece was cut six times and failed six times** (2026-08-26). Every reason was already written down,
and nobody read it. **This skill is the read that did not happen.**

## What comes back — four things, always four

| | Where it is found |
|---|---|
| **What already stands** | What already stands at this spot — in `src/`, in the tools, in the docs. **Name it, so nobody builds it twice** |
| **What already died** | What was deleted or reversed here. Reviving a dead thing costs a round, and this repo has lost rounds that way |
| **Which net measures it** | Is there a check on this spot, and is it green right now? |
| **Which green went false here** | `docs/how-nets-lie.md`, searched for this spot. **A green that measures less than its label is worse than a red** |

**Done when all four are answered** — an empty one is answered by saying it is empty. **An empty section
is a measurement**, and a missing one is a gap in the survey.

## Facts only

⚠⚠ **This skill does not judge.** Balance, fun, polish, and "this could be better" belong to playing the
game, not to reading it. **The only finding that stops the user is one that blocks code from being
written** — everything else is reported and left alone.

⚠ **Where the vocabulary in `CONTEXT.md` disagrees with `src/`, the code is what is true.** Parts of that
glossary are older than the day the sides were swapped.

## Where it lands

**Into the ticket that asked for it**, under the ticket heading `## 지금 어떻게 돼 있나` (the tickets are Korean, so the heading is). **No ticket in play → back in
conversation only.**
