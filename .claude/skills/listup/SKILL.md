---
name: listup
description: Name everything that actually exists at one spot, one line each, grouped by kind and nothing else. Use when the user says 리스트업 / 리스트로 / 목록으로 / 하나씩 나열 / 뭐뭐 있는지, or asks to see the contents of a folder before deciding what to do with them.
---

# listup — what is actually there, one line each

**One file, one line, grouped by kind.** No ranking, no judgement, no recommendation.

## ⚠⚠ The list comes from the filesystem, never from an index document

**Measured**: two README files in this repo each listed scripts that had been deleted a commit
earlier, run commands included, and each missed the one that had been added. **A hand-kept index is
always the version before the last commit.** ⇒ `ls` / `find` the spot, then open the files. **An index
document is one more thing to list, not the source of the list.**

## The steps

1. **Find the spot.** The user names it, or it is what the conversation is already about. **Never widen
   it** — asked for `docs/`, do not also list the skills.
2. **List the files there for real**, subfolders included.
3. **Read only the head of each file** — the title, the first `Status:` line, the first sentence of
   prose. **That is where the one line comes from.** Do not read a file whole to describe it.
4. **Print it: kind by kind, one line per file.**

## The line

**`이름 — 무엇인가`**, and it fits on one line at a normal terminal width.

- ⚠ **The line says what the thing IS.** A filename reworded is not a line — the user can already read
  the filename. **What is in it that they cannot see from outside** is the line.
- **A status the file carries goes at the head of the line** and costs nothing: `[open]`, `[resolved]`,
  `[틀이 죽었다]`.
- **A number that is cheap and tells you something goes in** — how many lines, what date it last moved.
  ⚠ **Two numbers is already too many.**

## The grouping

**By kind, and by nothing else.** The folder is usually the kind. When one folder holds two kinds — a
plan file and a ticket, a picture and a research note — **split it and give each half a heading.**
⚠ **Do not group by alive / dead, by priority, or by what you would do about them.** That is a judgement,
and this skill does not make one.

## What this is not

- **It does not work anything out.** What already died here, which net measures it, whether that green is
  false — those are questions `plan-into-ticket` asks. **This one only names what is there.**
- **Not `compass`** — that one ranks what to do next. **Nothing here is ranked.**
- ⚠⚠ **It does not end with a recommendation, and it does not ask what to do with any of it.** The user
  asked to see the shelf. **They will say what comes off it.**
