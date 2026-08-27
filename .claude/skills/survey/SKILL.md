---
name: survey
description: Report what this repo already holds at one spot — what stands, what already died, which net measures it, and which green went false here. Use when the user asks 지금 어떻게 돼 있어 / 이미 있나 / 뭐가 있지 / 코드 어떤지 봐줘, and before any ticket is written.
---

# survey — what is already here

⚠⚠ **Dispatch it, do not read it here.** Send a subagent, and take back **the findings only.** A 1900-line
view file opened in this session costs more than everything this skill saves.

## Why it exists

**A piece was cut six times and failed six times** (2026-08-26). Every reason was already written down,
and nobody read it. **This skill is the read that did not happen.**

## What comes back — four things, always four

| | Where it is found |
|---|---|
| **이미 있는 것** | What already stands at this spot — in `src/`, in the tools, in the docs. **Name it, so nobody builds it twice** |
| **이미 죽은 것** | What was deleted or reversed here. Reviving a dead thing costs a round, and this repo has lost rounds that way |
| **재고 있는 그물** | Is there a check on this spot, and is it green right now? |
| **여기서 났던 거짓 초록** | `docs/how-nets-lie.md`, searched for this spot. **A green that measures less than its label is worse than a red** |

**Done when all four are answered** — an empty one is answered by saying it is empty. **An empty section
is a measurement**, and a missing one is a gap in the survey.

## Facts only

⚠⚠ **This skill does not judge.** Balance, fun, polish, and "this could be better" belong to playing the
game, not to reading it. **The only finding that stops the user is one that blocks code from being
written** — everything else is reported and left alone.

⚠ **Where the vocabulary in `CONTEXT.md` disagrees with `src/`, the code is what is true.** Parts of that
glossary are older than the day the sides were swapped.

## Where it lands

**Into the ticket that asked for it**, under `## 지금 어떻게 돼 있나`. **No ticket in play → back in
conversation only.**
