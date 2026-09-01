---
name: knowledge
description: Reach the measured tool knowledge in docs/개발지식/ before writing code against Godot, Blender or a measuring instrument, and add a page when a round measures something still true next month. Use when the user says 개발지식 / 이거 어떻게 하더라 / 전에 어떻게 했지 / 이거 남겨줘, when work is about to touch the engine or the exporter, or when a session lands a durable fact no document holds.
---

# knowledge — 개발지식, read before typing and written after measuring

**`docs/개발지식/` holds what the TOOLS do that nobody tells you** — the failure that has no exception,
no red and exit code 0. **This skill is its two halves: reaching it, and growing it.**

⚠⚠ **Neither half invents anything.** A page carries a number and how it was taken, or it is not written.

## Which half

| The round is | Go to |
|---|---|
| **About to write code against Godot, Blender, a shader or an instrument** | **Reach** |
| **Ending, and something was measured that is still true next month** | **Write** |
| **Asking what a word means · why a decision went that way · what to build** | ⚠ **Not this skill.** The README's routing table says where |

## Reach

1. **Read `docs/개발지식/README.md`.** Its table says what each page holds and how to launch a lab.
2. **Open the page the work touches, whole.** ⚠ A page here is short by rule — **there is no skimming
   budget to save.**
3. **Say which entry applies before the code is written**, in one line. ⚠⚠ **A page read after the tool
   surprises you is a page that cost its round anyway.**

⚠ **`build-loop` sends `builder` here.** When you are the one dispatching, **name the page in the plan** —
a subagent inherits no context, and a pointer you held in your head does not exist.

## Write

**Only when all five hold. Any one missing and it is not a page.**

| | |
|---|---|
| **Measured** | ⚠⚠ **A number and how it was taken.** 「it is known that」is not a measurement |
| **Durable** | True after this island, this ticket, this week. **A fact about the current board belongs to the board** |
| **Unowned** | ⚠ **Check the README's routing table first** — `how-nets-lie`, `docs/manual/blender.md`, `GLOSSARY.md`, `log.md`, `docs/reference/` each own a kind of fact, and **the same fact in two files drifts** |
| **Actionable** | It changes what the next agent types. **A symptom with no instruction is a war story** |
| **Run** | ⚠⚠ **The page's lab launched on screen this round and was looked at.** Static reading of the code is not this criterion — 02 and 03 were written, reviewed and shipped while a parse error kept them from loading at all |

1. **Add a heading to an existing page** where one fits. ⚠ **A new file is the last resort** — three
   pages that are read beat six that are not.
2. **Write it in the page's shape**: what happens · how it was measured · **what to do instead.**
3. **Add the row to the README's page table** if a file was created.

⚠⚠ **A page found wrong is corrected in place, and the wrong claim stays with a line saying it was
measured false.** **That is the opposite of `docs/reference/`, which is frozen** — the difference is that
an agent reads this folder to decide what to type. **A doc saying a tool is broken is a doc to re-test,
not to quote**: that exact sentence cost four days when a Blender warning outlived its fault.

## The lab

**A page is a folder, and the folder is four files** — `README.md`, `그림.svg`, `lab.gd`, `stage.gd`.
**The code sits beside the prose so it can be launched from there and read there**
(2026-08-31, the user: ***"The Godot code has to be inside 개발지식, so running it shows you straight
away ... so I can read the code myself, and see how it was implemented."***).

### Every technique carries its real name

⚠⚠ **Write it `한국어(English)`, in the page table and on the lab's own switch line.** **The English
half is what the user types into a search box**, so it is the name practitioners actually use —
`알파 잘라내기(alpha cutout)` · `Y 축 고정 빌보드(Y-axis billboard)` · `깊이 밀어주기(depth bias)`.

**When a technique has no established name, the second half says so**: `세로 늘려 보정(통용 이름 없음)`.
⚠⚠ **A name you supplied yourself is the failure this rule exists to stop** — it returns nothing when
searched, and reads as authoritative precisely because it is in the English column.

⚠ **Check the name outside the repo before writing it.** `docs/reference/` holds what previous
searches found; a name that is in neither the reference folder nor a search result is `통용 이름 없음`.

### Every number is a dial the user can turn

⚠⚠ **A switch answers「is it there」. A dial answers「what does it do」** — and the second is the
question a page exists for.

| The technique is | What the lab gives |
|---|---|
| **A value** — tilt degrees, outline width, shake distance, stretch amount | ⚠⚠ **← → turn it on screen**, with the number printed and both ends of a real range reachable |
| **An engine constant with named options** — billboard mode, alpha mode, projection, filter | ⚠⚠ **← → walk every option the engine has**, named on screen. **Two of five is not the technique** |
| **Present or absent** — a shadow disc exists or it does not | Space toggles it |

**Every dial's starting value carries its origin on that line of code**, one of three:

- **measured** — this round, on screen, and the page says how
- **sourced** — a line in `docs/reference/` or a named outside source
- ⚠ **`# 추정`** — a guess, marked as one, so the dial is where it gets disproved

⚠⚠ **A bare number with no origin is the failure** (2026-08-31, the user: ***"You pick those values
far too casually, and that is disgusting. Nobody studies anything from a test like this."***).
**Measured 2026-08-31 in `01`: `12.0` degrees of lean, `1.10` outline scale, `Color(1.18, 1.14, 1.22)`
separation, `3.2` breathe rate, `0.35` stretch floor, `0.02` depth push — six numbers, no origin for
any of them**, in a folder whose own rule says a number arrives with how it was taken.

### The table and the list are checked against each other

**Walk the page's techniques one by one against the lab's switch list.** Every technique the lab does
not carry **says why on its own row** — `들여오기 설정` · `그림이 더 있어야 한다` ·
`한 화면에서 안 갈린다`.

⚠⚠ **A silent gap reads as coverage.** `01` shipped 「기법 28 · 스위치 16」 with the missing twelve
named nowhere on the table, and the twelve included the normal map and the projection comparison —
**the two a reader most wants to see.**

## What this skill never does

- ⚠⚠ **It does not write a ticket, touch the map, or decide what gets built.** That chain is
  `grilling` → `build-loop` → `wrap-up`
- **It does not carry the user's words.** Every quotation lives in `docs/roadmap/log.md`
- ⚠ **It does not restate what the environment already says.** A one-file lookup stays in the file,
  where it cannot go stale
