# tockbon — **one island, held against the beasts**, and `src/` runs

## ⚠⚠ **THE GLOSSARY IS LOADED BELOW. READ IT BEFORE THE FIRST TOOL CALL.** (2026-08-28, the user)

@GLOSSARY.md

***"판이 뭔지 제대로 이해한 거 맞아? ... 시작하면 바로 읽어야지."*** **A round was spent building the
wrong thing because the word 판 was guessed at instead of read.**

⚠⚠ **A word you are about to use for a thing on screen is checked there FIRST**, not after the user
says it is wrong. ⚠ **Where it disagrees with `src/`, the code is true** — and **say so out loud**
rather than quietly picking one.


## ⚠⚠ **The ground the game is played on**

**What this week is doing is read out of `docs/roadmap/README.md`, never out of this file.**

⚠ **The bar is Bad North.** **The island HAS a second storey and a stair, and they passed by eye.**
⇒ **Do not delete them.**

⚠⚠ **Read ticket 01 — what one piece is — BEFORE opening Blender.** Skipping it cost a round: a live
rule (**corners are not cut at 45°, they are slightly tilted**) got trampled.

**A human company holds one island and builds it up. The beasts come by boat.** ⚠⚠ **The sides were
swapped 2026-08-26 by the user.** **The island is ONE**; drawing eight was what the project could not
afford. **The player never places a boat.** **A timer brings a boss.** **Raiding another island is how
more are taken.** **There is no eating for parts** — the art could not carry it.
**Squads are commanded on the board at any time** — hands move.

**The frame** — ⚠⚠ **December is a DEMO, not a release** (2026-08-26, the user: *"Change it to a December
demo."*) · **roguelike** · **funding after it** · **raiding other islands is IN, not deferred.**
⚠ **This line has flipped twice and is settled by whichever the user said last, never by argument.**
⚠ **What DEMO returns**: saves, an options screen, sound, a store page and its builds, and language stop
being December's problem. None were built, so nothing is lost.

**The code runs and the game launches.** ⚠⚠ **What is being made is read out of `docs/roadmap/` and the
roadmap, and there is no third place.** **Do not go looking for one, and do not cite one.**

⚠⚠ **`main` is not the whole repo.** Two sessions collided on it once and one rebuilt the docs around a
game folded on another branch. ⇒ **Run `git ls-remote --heads origin` before concluding anything.**
`62ff57d` is the folded cell game whole; `salvage/cell-harness` is docs discarded on purpose;
`archive-full-history` is everything from before the resets.

# Language

**Replies to the user are Korean. Every document, comment and prompt is English.**

⚠⚠ **English means ALL of it, quotations included** (2026-08-27, the user). **When the user's own words
are cited in a doc, translate them and keep the citation** — a doc that mixes the two is what this rule
exists to stop.

⚠ **Three things stay Korean because translating them would break what they name**: **a skill's trigger
phrases** (the user types those words), **the labelled lines a question is printed with** (output, not
prose), and **the glossary's Korean column in `GLOSSARY.md`** (the Korean word IS the name).

**One exception: the GDD is Korean** (2026-08-22, the user) — one page, and the user is the one who reads
it. ⚠ **No twin.** Korean twins existed and were deleted because the same fact in two files drifts.

# Reply rule — **the core, and nothing else**

**The answer goes in the FIRST LINE and is under 100 characters.** Reasons after it, never before. Stop.

- ⚠⚠ **No abstract word.** Name the thing and the number. **Never** 「improved」 「cleaned up」 「optimised」
  「the structure」 「the system」 「properly」 — **a sentence that would still be true of a different repo
  says nothing**
- **No emoji.** Bold is the only emphasis
- **No file paths, no line numbers, no code locations in chat** — say what the thing is, not where it lives
- **No word only you understand.** A doc name or a net name standing in for the thing is not an answer
- **The user is new to making games. Their agreement is the absence of anything to disagree with**

## ⚠⚠ **No recommendation unless it was asked for** (2026-08-29, the user)

***"Unless I say so, no recommendations — it is confusing rather than helpful."***
⇒ **Report what is there and stop.** An unasked recommendation is one more thing to read, and one more
thing to have to disagree with.

- **When it IS asked for, label it** — **what you recommend · why**, in that order
- ⚠ **No 「the case against」 attached to one** (2026-08-22, the user: *"I do not really get why that
  against part keeps coming up."*)
- ⚠ **Never recommend a technique the user has not named without first checking how others do it**

## ⚠⚠ **It has to be readable** (2026-08-29, the user)

***"What you are saying is too hard to look at, hard to read. Separate it properly and make it easy on
the eye."*** **The failure is density, not length.**

- **One bullet, one line.** Needs three lines of prose? Then it is its own heading, or it is cut
- **Bold at most one phrase per line.** Bold on every clause emphasises nothing — that is what went wrong
- **⚠ marks a thing that will actually bite**, never emphasis. Two per reply is already many
- **One subject, one heading**, with a blank line between. A reply covering three subjects is three headings
- **Short sentences.** A clause that only qualifies another clause gets deleted

## ⚠⚠ **A reply does NOT end with questions** (2026-08-27, the user)

***"There are too many questions. It is making me not want to read."*** ⇒ **Answer the thing, and stop.**

- **Ask only when the work genuinely cannot go on without the answer**, and then ask **one** question, in
  plain prose, at the end. **A question you can settle by reading the repo is not a question**
- ⚠ **Never close a live conversation by asking whether to begin**
- ⚠ **Do not compensate by moving the questions into the body.** Fewer words on screen is the point
- ⚠ **Unchanged by this**: **finding facts is your job, never the user's**

**The shape a question is printed in lives in the `grilling` skill, and nowhere else.**

# Running the game

**"게임 켜줘" = run THIS folder's `Godot_v4.7.1-stable_win64.exe` with `--path` here. Nothing else** —
not `play.bat`, not the other Godot in `~/bin`.

# Nothing pretends to work

**Code that pretends to work is worse than code that doesn't, and a green that measures less than its
label says is worse than a red. If you can't do it, say you can't.**

# ⚠⚠ **Anything the player LOOKS at is MADE, never typed** (2026-08-28, the user)

***"UI나 이런것들 코드가 아니라 항상 제대로 만들라고 ... pixellab이나 블랜더 MCP 사용하라고"***

**A HUD, a button, an icon, a panel, a mark on the ground — build it in a tool and load the result.**
**Blender (the MCP) for anything with a shape in the world; `tools/pixel/` (local ComfyUI) or pixellab
for anything flat.** ⚠ **`draw_rect` + `draw_string` chrome is not a placeholder, it is the thing that
ships** — that is exactly how the island wore a grey button and a digit nobody chose until they were
deleted. **If a screen is worth having, it is worth being designed.**

⚠ **What this does NOT forbid**: a shader, a line the sim needs to prove something, or a throwaway
probe. **The test is whether the PLAYER is meant to look at it.**

## ⚠⚠ **A mesh has a `.blend` in `blend/`, and that file is the original** (2026-08-31, the user)

***"모델을 만들어 놓고 원본 파일이 있는 상태에서 그걸 쓰는 거지, 코드로 남기는 건 말이 안 된다."***
**Open it, change it, export from it. Never rebuild a mesh from a script.**
⇒ **Before touching any shape, read `docs/manual/blender.md`.**

# The docs

**Open a folder's README, not the folder.**

| Path | What it holds |
|---|---|
| `docs/design/` | **What is being made, and the forks that were rejected.** ⚠ **Sixteen fork docs and NO GDD, which is the defect** — the folder is not thin, the one page that says what the game is has never been written. When it is, it is **one page**. A fork doc opens with a `Status:` line and **a reversal is written onto it, never by deleting it** |
| `docs/roadmap/` | **The only map and the work under it**, at the top of `docs/` (the folder took over from `docs/plan/` on 2026-08-31). **`README.md` IS the map** — what is being done, one row per task with a status mark, plus the chunk table. **`log.md` is why it came out that way, and every quotation lives there.** **`task-NN-name/`** is one task — its `NN.task.md` says what is on screen when it ends, and the **`MM-name/`** folders beside it are its tickets, each holding a `NN-MM.ticket.md` and whatever that ticket produced, **one day each**, numbered from `01` inside that task. ⚠⚠ **Task folders sit directly here; there is no `tasks/` layer.** ⚠⚠ **A description file is named after its own number, never `TASK.md` or `TICKET.md`** — otherwise every open tab carries the same name and none can be told apart, and the number and the name are repeated inside the file so they never come apart. **Status is a `Status:` line inside the file — files never move between folders.** The chain: `compass` → `grilling` (which settles what a stretch actually builds, sending `research` outside when it needs an outside fact) → `build-loop` → `wrap-up`, with `roadmap` checking it. ⚠⚠ **Only `wrap-up` writes to these files, and only after the conversation is finished** |
| `docs/reference/` | **What came in from outside**: the screenshots a decision was made from, and the notes `research` leaves when a search took real work. All `YYYY-MM-DD-what-it-is`. ⚠⚠ **A ticket keeps the conclusion; the material stays here** — and `wrap-up` asks before deleting a shot |
| `lessons-from-two-dead-games` | **What the two games that died actually measured** |
| `how-nets-lie` | **Every green measured to be false.** Read it before writing a check and before believing a green round |
| `planning-principles` | **How to judge a direction.** Survived both resets on purpose — read it first |

- **An idea the user picks becomes a ticket on the map**, not a design doc. **When a fork is taken,
  record the rejected branch in `docs/design/`**
- ⚠ **The user's own words about a game are a measurement, and this repo has had very few of them.** When
  the user says what they thought of something they played, **carry the judgement into the ticket it
  belongs to, in English and word for word** — never soften it, never leave it only in chat
- **Skeleton first, flesh later.** Do not demand every `TBD` be filled before implementing

# How the code is laid out

**Where a new file goes is decided by this table and nothing else** — it is what lets a net drive the
whole game headless in seconds.

| Path | The rule it obeys |
|---|---|
| `src/sim/` | **Never touches the tree.** No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`. Every file is constructible and drivable with `.new()` and nothing else |
| `src/view/` | **Reads `sim`, never writes it.** Everything that is a Node or draws lives here. ⚠ **Every view exposes `_paint_*` hooks**, the field included — but the field's hooks build a 3D world, so **asserting their arguments does not measure what the player sees.** What a net measures here is the three-fold surface named in `GLOSSARY.md`, not the hook |
| `src/shell/` | **The only place that reads `Input`**, and the only place that wires `sim` to `view`. It builds its children in code, so a net calling `_ready()` exercises the real wiring |
| `src/look.gd` | **Every presentation constant, in exactly one file.** `src/sim/rules.gd` holds every constant that changes what happens |

⚠⚠ **When the field moved to 3D it took a large share of the checks with it** — what died asserted
pixels, what survived measured **input → state**. ⇒ **Prefer the shape that survives; reach for pixels
only when the pixels are the subject.**

⚠ **No check is written at a seam `GLOSSARY.md` does not name.**
