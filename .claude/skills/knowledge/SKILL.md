---
name: knowledge
description: Reach the measured tool knowledge in docs/개발지식/ before writing code against Godot, Blender or a measuring instrument, and add a page when a round measures something still true next month. Use when the user says 개발지식 / 이거 어떻게 하더라 / 전에 어떻게 했지 / 이거 남겨줘, when work is about to touch the engine or the exporter, or when a session lands a durable fact no document holds.
---

# knowledge — 개발지식, read before typing and written after measuring

**`docs/개발지식/` holds what the TOOLS do that nobody tells you** — the failure with no exception, no red
and exit code 0. ⚠⚠ **Neither half of this skill invents anything.** A page carries a number and how it
was taken, or it is not written.

| The round is | Go to |
|---|---|
| **About to write code against Godot, Blender, a shader or an instrument** | **Reach** |
| **Ending, and something was measured that is still true next month** | **Write** |
| **Asking what a word means · why a decision went that way · what to build** | ⚠ **Not this skill** |

## Reach

1. **Read `docs/개발지식/README.md`** — its table says what each page holds and how to launch a lab
2. **Open the page the work touches, whole.** ⚠ A page here is short by rule; there is no skimming budget
3. **Say which entry applies before the code is written.** ⚠⚠ **A page read after the tool surprises you
   is a page that cost its round anyway**

⚠ **`build-loop` sends `builder` here.** When you dispatch, **name the page in the plan** — a subagent
inherits no context.

## Write — **only when all five hold**

| | |
|---|---|
| **Measured** | ⚠⚠ **A number and how it was taken.** 「it is known that」 is not a measurement |
| **Durable** | True after this island, this ticket, this week. A fact about the current board belongs to the board |
| **Unowned** | ⚠ **Check the README's routing table first** — `how-nets-lie`, the Blender manual and the glossary each own a kind of fact, and **the same fact in two files drifts** |
| **Actionable** | It changes what the next agent types. **A symptom with no instruction is a war story** |
| **Run** | ⚠⚠ **The page's lab launched on screen this round and was looked at.** Reading the code is not this criterion — 02 and 03 were written, reviewed and shipped while a parse error kept them from loading |

1. **Add a heading to an existing page** where one fits. ⚠ **A new file is the last resort** — three pages
   that are read beat six that are not
2. **Write it in the page's shape**: what happens · how it was measured · **what to do instead**
3. **Add the row to the README's page table** if a file was created

⚠⚠ **A page found wrong is corrected in place and the wrong claim is DELETED**, not struck through.
**A doc saying a tool is broken is a doc to re-test, not to quote**: that cost four days when a Blender
warning outlived its fault.

## The lab

**A page is a folder of four files** — `README.md`, `그림.svg`, `lab.gd`, `stage.gd`. **The code sits
beside the prose so it can be launched from there and read there** (the user).

### Every technique carries its real name

⚠⚠ **Write it `한국어(English)`**, in the page table and on the lab's switch line. **The English half is
what the user types into a search box** — `알파 잘라내기(alpha cutout)` · `Y 축 고정 빌보드(Y-axis
billboard)`. **No established name → say so**: `세로 늘려 보정(통용 이름 없음)`.

⚠⚠ **A name you supplied yourself is the failure this rule exists to stop** — it returns nothing when
searched and reads as authoritative because it sits in the English column. **Check it outside the repo
first.**

### Every number is a dial the user can turn

⚠⚠ **A switch answers「is it there」; a dial answers「what does it do」** — and the second is why a page exists.

| The technique is | What the lab gives |
|---|---|
| **A value** — tilt, outline width, shake distance | ⚠⚠ **← → turn it on screen**, number printed, both ends of a real range reachable |
| **An engine constant with named options** — billboard mode, alpha mode, filter | ⚠⚠ **← → walk every option**, named on screen. **Two of five is not the technique** |
| **Present or absent** | Space toggles it |

**Every dial's starting value carries its origin on that line**: **measured** this round · **sourced**
from a named outside source, linked · ⚠ **`# 추정`**, a guess marked as one.

⚠⚠ **A bare number with no origin is the failure** (the user: ***"You pick those values far
too casually. Nobody studies anything from a test like this."***) — six numbers shipped in `01` with no
origin for any of them.

### The table and the list are checked against each other

**Walk the page's techniques against the lab's switch list.** Every technique the lab does not carry
**says why on its own row** — `들여오기 설정` · `그림이 더 있어야 한다` · `한 화면에서 안 갈린다`.

⚠⚠ **A silent gap reads as coverage.** `01` shipped 「기법 28 · 스위치 16」 with the missing twelve named
nowhere — and they included the normal map and the projection comparison, the two a reader most wants.

## What this skill never does

- ⚠⚠ **It writes no ticket, touches no map, and decides nothing that gets built**
- **It does not carry the user's words** — every quotation lives in the log
- ⚠ **It does not restate what the environment already says.** A one-file lookup stays in the file
