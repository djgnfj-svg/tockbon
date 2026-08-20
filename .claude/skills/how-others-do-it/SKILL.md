---
name: how-others-do-it
description: Answers "how do other games do this" with named techniques and the studios that ship them. Use when the user asks 「다른 게임들은 어떻게 해」 「다른 회사는」 「레퍼런스」 「사례 좀」 「업계에서는」 「이런 거 쓰는 데 있어?」, or asks the same about engines, libraries, tooling or verification. Also use before recommending any technique the user has not named themselves.
---

# How others do it

**The user is new to making games and has said so.** *"I have no data, so whatever you say feels like it
must be right."* **Their agreement is the absence of anything to disagree with, not agreement.** That is the
whole reason this skill exists: an answer they cannot check is an answer they cannot refuse.

## The four rules

- **Name the technique first, then the games or studios that ship it** — several, and **disagreeing with
  each other.** One example reads as "this is how it's done"; three that conflict read as "here is the
  space, pick"
- **Checkable sources only.** *"Usually in the industry…"* is not one. Neither is `CLAUDE.md`, and neither
  is this file
- **One line each.** The user is picking something to build, not reading an essay
- **Give the case against your own recommendation**

## Look it up. Do not remember it.

**A studio named from memory that turns out wrong is worse than no example at all** — it spends the user's
trust on something they cannot check, in exactly the direction they already cannot push back on.

⇒ **Search before answering, every time, even when you are sure.** Then link what you used.
**Prefer the primary source**: a developer's own postmortem, a talk, a docs page, the studio's own words.
A listicle repeating a claim is not the claim's source.

**When the search does not settle it, say it did not.** *"I could not find a shipped example"* is a real
answer and the user can act on it. A plausible-sounding one is not.

## This binds technical choices too

Engines, libraries, tooling, verification, process. **A recommendation about how to WORK needs sources the
same way a recommendation about the game does** — that half is easier to assert and just as unfalsifiable
from where the user is standing.

## Shape of the answer

**Conclusion first: the recommendation is the first line, before any of the evidence.** Then:

- **The technique, named**, in the words the user used
- **Two to four shipped examples, one line each**, disagreeing where they disagree
- **What it costs**, not only what it buys
- **The case against your recommendation**, under that label
- **Sources, as links.** If a claim has no link, say so on that line

**The three parts are named out loud** — recommendation, why, the case against. A reader who cannot point
at the sentence that is the recommendation did not get one.
