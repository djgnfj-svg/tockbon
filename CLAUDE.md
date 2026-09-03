# tockbon — **one island, held against the beasts**, and `src/` runs

@GLOSSARY.md

⚠⚠ **The glossary above is read BEFORE the first tool call.** A round was spent building the wrong
thing because 판 was guessed at instead of read. ***"판이 뭔지 제대로 이해한 거 맞아? ... 시작하면 바로
읽어야지."***
⚠⚠ **A word you are about to use for a thing on screen is checked there FIRST**, not after the user
says it is wrong.
⚠ **Where it disagrees with `src/`, the code is true** — and say so out loud rather than quietly
picking one.

# Reply rule

**The answer goes in the FIRST LINE and is under 100 characters.** Reasons after it, never before. Stop.

- **Name the thing and the number.** Never 「improved」「cleaned up」「optimised」「the structure」「properly」
- **One bullet, one line.** Three lines of prose is its own heading, or it is cut
- **One bold phrase per line at most.** Bold on every clause emphasises nothing
- **One subject, one heading**, with a blank line between. Three subjects is three headings
- **Short sentences.** A clause that only qualifies another clause gets deleted
- **⚠ marks what will actually bite**, never emphasis. Two per reply is already many
- **No emoji. No file paths, no line numbers, no code locations** — say what the thing is, not where it lives
- **No word only you understand.** A doc name or a net name standing in for the thing is not an answer
- **No recommendation unless asked.** When asked, label it — **what · why**, and no 「the case against」
- ⚠ **Never recommend a technique the user has not named** without first checking how others do it
- **Do not end with questions.** Ask one, in plain prose, only when the work cannot go on without it
- ⚠ **A question you can settle by reading the repo is not a question**, and never ask whether to begin
- ⚠ **Finding facts is your job, never the user's**

**The user is new to making games. Their agreement is the absence of anything to disagree with.**
The shape a question is printed in lives in the `grilling` skill, and nowhere else.

# Language

**Replies to the user are Korean. Every document, comment and prompt is English** — quotations
included: translate the user's words and keep the citation.

⚠ **Korean stays in four places** because translating them would break what they name: a skill's
trigger phrases, the labelled lines a question prints with, the glossary's Korean column, and
`docs/개발지식/`. **The GDD is Korean too** — one page, and ⚠ **no twin**, because the same fact in two
files drifts.

# Nothing pretends to work

**Code that pretends to work is worse than code that doesn't, and a green that measures less than its
label says is worse than a red. If you can't do it, say you can't.**

# Anything the player LOOKS at is MADE, never typed

**A HUD, a button, an icon, a panel, a mark on the ground — build it in a tool and load the result.**
⚠⚠ **`draw_rect` + `draw_string` chrome is not a placeholder, it is the thing that ships.**
⇒ **Read `docs/manual/` before making anything the player looks at, or touching any mesh.**

# The ground the game is played on

**A human company holds one island and builds it up. The beasts come by boat.**
**The island is ONE** — drawing eight was what the project could not afford. The player never places a
boat. A timer brings a boss. Raiding another island is how more are taken. There is no eating for
parts. Squads are commanded on the board at any time.

⚠ **The bar is Bad North.** **The island HAS a second storey and a stair, and they passed by eye** —
do not delete them.

**December ships an EARLY-ACCESS RELEASE.** Roguelike · funding after it. ⚠ **This line has flipped and is settled by whichever the user said
last, never by argument.**

⚠⚠ **What is being made is read out of `docs/roadmap/`, and there is no third place.** Do not go
looking for one, and do not cite one.

⚠⚠ **`main` is not the whole repo** — two sessions collided on it once. **Run
`git ls-remote --heads origin` before concluding anything.** `62ff57d` is the folded cell game whole;
`salvage/cell-harness` is docs discarded on purpose; `archive-full-history` is everything before the
resets.

# The docs — **only what is true NOW**

⚠⚠ **No logs. No decision history. No failure diaries. No outside-material dumps.** A document says what
stands today; **what it used to say is deleted, not struck through.** Old documents were measured to be
the biggest source of confusion in this repo, and every one of them was written by an earlier round
that thought it was being helpful.

| Path | What it holds |
|---|---|
| `docs/roadmap/` | **The only map.** `README.md` is what is being done and this folder's own shape. ⚠⚠ **A finished ticket's folder is DELETED** — what survives is one ✅ in the map's table |
| `docs/manual/` | **How to work an instrument** — making what the player sees, and Blender |
| `docs/개발지식/` | The measured tool knowledge, in Korean, written for the user to read |
| `how-nets-lie` | **The shapes a false green comes in.** Read it before writing a check and before believing a green round. **Shapes only — no incidents, no dates** |
| `planning-principles` | **How to judge a direction.** One line each — read it first |

- **An idea the user picks becomes a ticket on the map.** There is no design-doc folder and no reference
  folder; **a conclusion goes in the ticket and the material is not kept**
- ⚠ **The user's own words about a game are a measurement.** Carry the judgement into the ticket it
  belongs to, word for word — **but only while that ticket is open.** It goes with the ticket
- **Skeleton first, flesh later.** Do not demand every `TBD` be filled before implementing
- ⚠ **Writing more is not doing more.** If a paragraph explains why an earlier round was wrong, cut it

# How the code is laid out

**Where a new file goes is decided by this table and nothing else** — it is what lets a net drive the
whole game headless in seconds.

| Path | The rule it obeys |
|---|---|
| `src/sim/` | **Never touches the tree.** No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`. Constructible and drivable with `.new` and nothing else |
| `src/view/` | **Reads `sim`, never writes it.** Everything that is a Node or draws lives here. ⚠ The field's `_paint_*` hooks build a 3D world, so asserting their arguments does not measure what the player sees |
| `src/shell/` | **The only place that reads `Input`**, and the only place that wires `sim` to `view`. A net calling `_ready` exercises the real wiring |
| `src/look.gd` | **Every presentation constant, in exactly one file.** `src/sim/rules.gd` holds every constant that changes what happens |

⚠⚠ **What died in the 3D move asserted pixels; what survived measured input → state.** Prefer the shape
that survives, and reach for pixels only when the pixels are the subject.
⚠ **No check is written at a seam `GLOSSARY.md` does not name.**

# Running the game

**"게임 켜줘" = run THIS folder's `Godot_v4.7.1-stable_win64.exe` with `--path` here. Nothing else** —
not `play.bat`, not the other Godot in `~/bin`.
