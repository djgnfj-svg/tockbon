---
name: naming
description: Settle what a thing on screen or in the code is CALLED, and write it into the glossary so the next round can say it in one word. Use when the user says 용어 정리 / 단어 정리 / 이름 붙이자 / 용어집 / 이거 뭐라고 부르지, or when a round stalls because one word is being used for two different things.
---

# naming — one thing, one word, written down

**This skill ends with an edit to `CONTEXT.md`.** A name agreed only in chat is a name that is gone
next session, and this repo has already paid for that: `판` meant both the mat on the ground and the
mark under the cursor for a whole round, and the round could not be steered because neither the user
nor the assistant could say which one they meant.

⚠⚠ **`CONTEXT.md` is the ONLY glossary.** Do not start a second one. It is where the agreed test seams
live and where `domain-modeling` reads the vocabulary that interfaces are built from — **a name that
lives anywhere else is a name nothing can see.**

## When this is the right skill

- **One word is doing two jobs.** That is the emergency case and it outranks everything else.
- **A thing on screen has no word at all**, so every sentence about it is a description.
- **A word in the glossary disagrees with the code.** ⚠ **The code wins and the glossary is corrected**
  — never the reverse, and never silently.

⚠ **This is not a rename tool.** Renaming a symbol is `domain-modeling`'s job and it touches `src/`.
This skill touches words and one document.

## The four things a name needs

Every row this skill writes carries all four. **A row missing one is not finished.**

| | What | Why it is required |
|---|---|---|
| **1** | **The Korean word** | The user speaks Korean. **An answer that uses only the English word is not an answer to the user** |
| **2** | **The code symbol**, or a dash | A name with no symbol is a design; the dash says so out loud |
| **3** | **What it is, in one line** | Not what it looks like — what it IS and what it does |
| **4** | **What it is NOT** | ⚠⚠ **The load-bearing column.** A name is only sharp against the thing it is nearest to, and the collisions this skill exists to stop all live here |

## How to run it

**1. Find every thing that is being pointed at without a word.** Read the last few turns and the code
around what is being built. **List the things, not the words** — two things sharing one word is exactly
what you are looking for, and it is invisible if you list words.

**2. Check `CONTEXT.md` first.** A word may already be settled and simply not have been used. ⚠ **Parts
of that file are older than the sides swapping** — a row that reads as though the beast were the player
is stale, and stale is a finding, not a fact.

**3. Propose ONE Korean word per thing.** Rules:
- **Short.** It gets said out loud dozens of times a round.
- **A common Korean word wherever one fits.** ⚠ **Never a coinage when a plain word exists** — 「마당」
  beats 「지면패치」, and the user should not have to learn vocabulary to describe their own game.
- ⚠ **Never a metaphor in place of a plain noun.** This repo's reply rules already forbid it in prose;
  a name is prose that never goes away.
- **Say what it is NOT, in the same breath.** If you cannot, the word is not sharp enough yet.

**4. Put the choices to the user, one question per thing**, in this repo's grilling shape. ⚠ **The name
is the user's decision.** Recommend, give the reason, and wait.

**5. Write the settled rows into `CONTEXT.md`** — into the section they belong to, or a new one when
there is none. ⚠ **A reversal is written ONTO the file, never by deleting what it overturned**: the dead
word stays with a line saying what killed it and when. **The dead words are how the next round avoids
re-proposing them.**

**6. Say the new word back, in the next sentence you write.** A name that is agreed and then not used
is not yet a name.

## What this skill must not do

- ⚠ **Do not name what has not been built and is not being decided now.** A glossary of things that do
  not exist is a design document, and this repo does not keep one.
- ⚠ **Do not rename a code symbol as part of this.** Record the mismatch as a row and stop; the symbol
  is `domain-modeling`'s to move, and moving it is a change to `src/` with its own round.
- ⚠ **Do not write the same fact in two files.** `CONTEXT.md` and nothing else.
