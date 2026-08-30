---
name: knowledge
description: Reach the measured tool knowledge in docs/knowledge/ before writing code against Godot, Blender or a measuring instrument, and add a page when a round measures something still true next month. Use when the user says 개발지식 / 이거 어떻게 하더라 / 전에 어떻게 했지 / 이거 남겨줘, when work is about to touch the engine or the exporter, or when a session lands a durable fact no document holds.
---

# knowledge — 개발지식, read before typing and written after measuring

**`docs/knowledge/` holds what the TOOLS do that nobody tells you** — the failure that has no exception,
no red and exit code 0. **This skill is its two halves: reaching it, and growing it.**

⚠⚠ **Neither half invents anything.** A page carries a number and how it was taken, or it is not written.

## Which half

| The round is | Go to |
|---|---|
| **About to write code against Godot, Blender, a shader or an instrument** | **Reach** |
| **Ending, and something was measured that is still true next month** | **Write** |
| **Asking what a word means · why a decision went that way · what to build** | ⚠ **Not this skill.** The README's routing table says where |

## Reach

1. **Read `docs/knowledge/README.md`.** Its table says what each page holds. ⚠⚠ **There are no pages
   yet** — say so plainly and carry on; an empty folder is a measurement, not a fault.
2. **Open the page the work touches, whole.** ⚠ A page here is short by rule — **there is no skimming
   budget to save.**
3. **Say which entry applies before the code is written**, in one line. ⚠⚠ **A page read after the tool
   surprises you is a page that cost its round anyway.**

⚠ **`build-loop` sends `builder` here.** When you are the one dispatching, **name the page in the plan** —
a subagent inherits no context, and a pointer you held in your head does not exist.

## Write

**Only when all four hold. Any one missing and it is not a page.**

| | |
|---|---|
| **Measured** | ⚠⚠ **A number and how it was taken.** 「it is known that」is not a measurement |
| **Durable** | True after this island, this ticket, this week. **A fact about the current board belongs to the board** |
| **Unowned** | ⚠ **Check the README's routing table first** — `how-nets-lie`, `tools/blender/README`, `CONTEXT.md`, `log.md`, `docs/reference/` each own a kind of fact, and **the same fact in two files drifts** |
| **Actionable** | It changes what the next agent types. **A symptom with no instruction is a war story** |

1. **Add a heading to an existing page** where one fits. ⚠ **A new file is the last resort** — three
   pages that are read beat six that are not.
2. **Write it in the page's shape**: what happens · how it was measured · **what to do instead.**
3. **Add the row to the README's page table** if a file was created.

⚠⚠ **A page found wrong is corrected in place, and the wrong claim stays with a line saying it was
measured false.** **That is the opposite of `docs/reference/`, which is frozen** — the difference is that
an agent reads this folder to decide what to type. **A doc saying a tool is broken is a doc to re-test,
not to quote**: that exact sentence cost four days when a Blender warning outlived its fault.

## What this skill never does

- ⚠⚠ **It does not write a ticket, touch the map, or decide what gets built.** That chain is
  `grilling` → `build-loop` → `wrap-up`
- **It does not carry the user's words.** Every quotation lives in `docs/roadmap/log.md`
- ⚠ **It does not restate what the environment already says.** A one-file lookup stays in the file,
  where it cannot go stale
