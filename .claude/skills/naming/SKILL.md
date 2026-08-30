---
name: naming
description: Settle what a thing on screen or in the code is CALLED, and write it into the glossary so the next round can say it in one word. Use when the user says 용어 정리 / 단어 정리 / 이름 붙이자 / 용어집 / 이거 뭐라고 부르지, or when a round stalls because one word is being used for two different things.
---

# naming — one thing, one word, written down

**This skill ends with an edit to `CONTEXT.md`.** A name agreed only in chat is a name that is gone
next session, and this repo has already paid for that: `판` meant both the mat on the ground and the
mark under the cursor for a whole round, and the round could not be steered because neither the user
nor the assistant could say which one they meant.

⚠⚠ **`CONTEXT.md` is the ONLY glossary.** Do not start a second one, and **do not accept a
`CONTEXT-MAP.md` or a per-folder glossary** — this repo has one context and one file. It is where the
agreed test seams live and where interfaces take their vocabulary from; **a name that lives anywhere else
is a name nothing can see.**

⚠⚠ **`domain-modeling` was folded into this skill on 2026-08-29** (the user: *"merge the two and call it
naming"*). They wrote the same file and asked the same question, and one was this repo's own while the
other was imported. **What came across is the during-the-session half below.** What did not: **ADRs**
(this repo has no `docs/adr/`; a decision goes to `docs/roadmap/log.md`, and only `wrap-up` writes there)
and **multi-context maps** (there is one context).

## ⚠⚠ Anything this skill PRINTS goes through `listup` (2026-08-29, the user)

**Call the Skill tool with `listup` before printing a list**, and follow its shape: **one line per thing,
grouped by kind, and no judgement in the line.** That covers **the glossary when the user asks what is in
it**, and **the things you found in step 1.**

⚠ **The word being settled is the exception.** Step 4 puts choices to the user one at a time and that is
a question, not a list.

## When this is the right skill

- **One word is doing two jobs.** That is the emergency case and it outranks everything else.
- **A thing on screen has no word at all**, so every sentence about it is a description.
- **A word in the glossary disagrees with the code.** ⚠ **The code wins and the glossary is corrected**
  — never the reverse, and never silently.

⚠ **This is not a rename tool.** **Moving a code symbol is a change to `src/` and its own round** — this
skill records the mismatch and stops. It touches words and one document.

## ⚠⚠ While the conversation is running — **do this without being asked**

**This half came from `domain-modeling`.** It is not a step; it is what you do the whole time words are
being used.

- **Challenge a term against the glossary the moment it conflicts.** *"The glossary says 「판」 is the
  whole floor, but you seem to mean the white mark. Which?"* ⚠ **Immediately, not at the end**
- **Sharpen a fuzzy word into a precise one.** *"You said 「오브젝트」 — do you mean a building or a
  tree? Those are different rows"*
- **Stress-test with a concrete scenario.** Invent the edge case that forces the boundary to be said out
  loud. **Two words that survive every scenario identically are one word**
- **Cross-check against the code.** ⚠ **Where the glossary and `src/` disagree, the code is true and the
  glossary is corrected** — never the reverse, and never silently
- **Write a settled term in as it settles.** ⚠ **Do not batch them to the end of the round**; a term
  agreed in chat and written down an hour later is the one that gets lost

⚠⚠ **`CONTEXT.md` holds no implementation details.** Not a spec, not a scratch pad, not a place for
decisions. **A glossary and nothing else** — the decisions live in `docs/roadmap/log.md`.
⚠ **Only terms this project actually coined belong.** A general programming concept the project happens
to use is not a row here.

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
what you are looking for, and it is invisible if you list words. **Print that list through `listup`.**

**2. Check `CONTEXT.md` first.** A word may already be settled and simply not have been used.
⚠ **When the user is asking what the glossary HOLDS rather than settling a new word, this step is the
whole job**: print it through `listup` and stop — do not propose names nobody asked for. ⚠ **Parts
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
  moved in its own round, as a change to `src/`.
- ⚠ **Do not write the same fact in two files.** `CONTEXT.md` and nothing else.
