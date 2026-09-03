---
name: naming
description: Settle what a thing on screen or in the code is CALLED, and write it into the glossary so the next round can say it in one word. Use when the user says 용어 정리 / 단어 정리 / 이름 붙이자 / 용어집 / 이거 뭐라고 부르지, or when a round stalls because one word is being used for two different things.
---

# naming — one thing, one word, written down

**This skill ends with an edit to `GLOSSARY.md`.** A name agreed only in chat is gone next session:
`판` meant both the mat on the ground and the mark under the cursor for a whole round, and the round
could not be steered because neither side could say which one they meant.

⚠⚠ **`GLOSSARY.md` is the ONLY glossary.** Do not start a second one, and do not accept a per-folder
one — **a name that lives anywhere else is a name nothing can see.**
⚠⚠ **It holds no implementation details, no spec, no history** — a term's row says what the word means
NOW. **Only terms this project actually coined** belong; a general programming concept is not a row.
⚠⚠ **A reversed word is deleted, not struck through** — the only thing kept is its name on the
「다시 제안하지 않는 낱말」 list, so nobody proposes it again.

## When this is the right skill

- **One word is doing two jobs.** The emergency case, and it outranks everything else
- **A thing on screen has no word at all**, so every sentence about it is a description
- **A word in the glossary disagrees with the code**

⚠⚠ **Where the glossary and `src/` disagree, the code is true and the glossary is corrected** — never
the reverse, and never silently.
⚠ **This is not a rename tool.** Moving a code symbol is a change to `src/` and its own round; this skill
records the mismatch and stops.

## ⚠⚠ Anything this skill PRINTS goes through `listup`

**Call the Skill tool with `listup` before printing a list** and follow its shape: one line per thing,
grouped by kind, no judgement in the line. ⚠ **The word being settled is the exception** — step 4 is a
question, not a list.

## ⚠⚠ While the conversation runs — **do this without being asked**

- **Challenge a term against the glossary the moment it conflicts** — *"the glossary says 「판」 is the
  whole floor, but you seem to mean the white mark. Which?"* ⚠ **Immediately, not at the end**
- **Sharpen a fuzzy word** — *"you said 「오브젝트」 — a building or a tree? Those are different rows"*
- **Stress-test with a concrete scenario.** **Two words that survive every scenario identically are one word**
- **Write a settled term in as it settles.** ⚠ **Do not batch them to the end of the round**

## The four things a name needs

**A row missing one is not finished.**

| | What | Why |
|---|---|---|
| **1** | **The Korean word** | The user speaks Korean. **An English-only answer is not an answer** |
| **2** | **The code symbol**, or a dash | A name with no symbol is a design; the dash says so out loud |
| **3** | **What it is, in one line** | Not what it looks like — what it IS and does |
| **4** | **What it is NOT** | ⚠⚠ **The load-bearing column.** A name is only sharp against its nearest neighbour, and every collision this skill exists to stop lives here |

## How to run it

1. **Find every thing being pointed at without a word.** **List the things, not the words** — two things
   sharing one word is invisible if you list words. Print it through `listup`
2. **Check `GLOSSARY.md` first.** ⚠ When the user is asking what it HOLDS rather than settling a word,
   **this step is the whole job** — print it and stop, do not propose names nobody asked for.
   ⚠ **Parts of it are older than the sides swapping**; a stale row is a finding, not a fact
3. **Propose ONE Korean word per thing** — **short**, because it gets said dozens of times a round;
   **a common word wherever one fits** (⚠ **never a coinage when a plain word exists** — 「마당」 beats
   「지면패치」); ⚠ **never a metaphor in place of a plain noun**; and **say what it is NOT in the same breath**
4. **Put the choices to the user, one question per thing.** ⚠ **The name is the user's decision** —
   recommend, give the reason, wait
5. **Write the settled rows in.** ⚠ **A reversal is written ONTO the file, never by deleting what it
   overturned** — the dead word stays with a line saying what killed it and when, which is how the next
   round avoids re-proposing it
6. **Say the new word back in the next sentence you write.** A name agreed and then not used is not a name

## What this skill must not do

- ⚠ **Do not name what has not been built and is not being decided now.** A glossary of things that do
  not exist is a design document, and this repo does not keep one
- ⚠ **Do not write the same fact in two files.** `GLOSSARY.md` and nothing else
