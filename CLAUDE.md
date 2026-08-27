# tockbon — **one island, held against the beasts**, and `src/` runs

## ⚠⚠ **THIS WEEK IS THE MAP. NOTHING ELSE.** (2026-08-26, the user)

***"Getting the map right is enough for this week. Focus on that."*** **Every round this week is about
the ground the game is played on** — not the bodies, not the beasts landing, not the nets, not the
cleanup. **If a reply raises anything else it is off-task**: ***"You are asking about way too much."***

⚠ **The bar is Bad North.** **The island HAS a second storey and a stair, and they passed by eye.**
⇒ **Do not delete them.**

⚠⚠ **How a storey is measured** (2026-08-26, the user): **one notch is half a tile · a storey is two
notches · a stair is one notch.** Ground is level 0, the stair 1, the second storey 2 — and a body may
cross **one** notch, which is what makes the stair the only way up. **A third storey is levels 3 and 4
and costs no rule change; nothing has been raised that high yet.**

⚠⚠ **Read ticket 01 — what one piece is — BEFORE opening Blender.** Skipping it cost a round: a live
rule (**corners are not cut at 45°, they are slightly tilted**) got trampled.

**A human company holds one island and builds it up. The beasts come by boat.** ⚠⚠ **The sides were
swapped 2026-08-26 by the user.** The player is **one swordsman and no other type** — the faceless
low-poly body that used to be the enemy — and the beasts (**wolf, bear, crow, lion**) are what lands on
your coast. **The island is ONE**; drawing eight was what the project could not afford. **The boats
belong to the beasts; the player never places one.** **A timer brings a boss.** **Raiding another island
is how more are taken.** **There is no eating for parts** — the art could not carry it.

⚠ **`Hands do not move during a fight` is dead** (2026-08-25, after the user played Bad North).
**Hands move**: squads are commanded on the board, at any time.

**The frame** — ⚠⚠ **December is a DEMO, not a release** (2026-08-26, the user: *"Change it to a December
demo."*) · **roguelike** · **funding after it** · **raiding other islands is IN, not deferred.**
⚠ **This line has flipped twice and is settled by whichever the user said last, never by argument.**
⚠ **What DEMO returns**: saves, an options screen, sound, a store page and its builds, and language stop
being December's problem. None were built, so nothing is lost.

**The code runs and the game launches. There is no GDD.** ⚠⚠ **What is being made is read out of
`docs/plan/`, and it is the only planning map there is.** **Do not go looking for a second map, and do
not cite one.**

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
prose), and **the glossary's Korean column in `CONTEXT.md`** (the Korean word IS the name).

**One exception: the GDD is Korean** (2026-08-22, the user) — one page, and the user is the one who reads
it. ⚠ **No twin.** Korean twins existed and were deleted because the same fact in two files drifts.

# Reply rule — **the core, and nothing else**

**The answer goes in the first line. Reasons after it, never before.** Every line load-bearing. Stop.

- **Label a recommendation, in two parts and in this order** — **what you recommend · why.**
  **Never leave it to be inferred**; an unlabelled paragraph reads as description
- ⚠ **No 「the case against」 attached to a recommendation** (2026-08-22, the user: *"I do not really get
  why that against part keeps coming up."*). **If it is strong enough to matter, this is not a
  recommendation — put the fork in a closing question instead**
- ⚠ **Never recommend a technique the user has not named without first checking how others do it**
- **No emoji.** Bold is the only emphasis
- **No file paths, no line numbers, no code locations in chat** — say what the thing is, not where it lives
- **No word only you understand.** A doc name or a net name standing in for the thing is not an answer
- **A reply covering more than one subject is a list**
- **The user is new to making games. Their agreement is the absence of anything to disagree with**

## ⚠⚠ **A reply does NOT end with questions** (2026-08-27, the user)

***"There are too many questions. It is making me not want to read."*** ⇒ **Answer the thing, and stop.**

- **Ask only when the work genuinely cannot go on without the answer**, and then ask **one** question, in
  plain prose, at the end. **A question you can settle by reading the repo is not a question**
- ⚠ **Never close a live conversation by asking whether to begin**
- ⚠ **Do not compensate by moving the questions into the body.** Fewer words on screen is the point
- ⚠ **Unchanged by this**: **finding facts is your job, never the user's**, and **a recommendation is
  still labelled**

**Grilling is a skill now and nothing else** — `grilling`, invoked when the user is **choosing a
direction or brainstorming**, or asks for it by name. **The shape a question is printed in lives there.**

# Nothing pretends to work

**Code that pretends to work is worse than code that doesn't, and a green that measures less than its
label says is worse than a red. If you can't do it, say you can't.**

# The docs

**`docs/` is four folders and three loose files.** **Open a folder's README, not the folder.**

| Path | What it holds |
|---|---|
| `docs/design/` | **What is being made, and the forks that were rejected.** ⚠ **Nearly empty, and that is a defect** — there is no GDD. When one is written it is **one page**. A fork doc opens with a `Status:` line and **a reversal is written onto it, never by deleting it** |
| `docs/skill-config/` | **What imported skills read before they act, and the only configuration in `docs/`.** ⚠ **Not reading matter** — **`code-review-mp` is the only skill that loads it**, and it reads one file |
| `docs/plan/` | **The only map.** **`roadmap.md` is what is being done** — **one dated row per week, each carrying a status mark**, plus the chunk table; **`log.md` is why it came out that way, and every quotation lives there**; **`tickets/NN-name.md`** are the work. **Status is a `Status:` line inside the file — files never move between folders.** The chain: `compass` → `press` (which sends `lookup` + `research`) → `build-loop` → `wrap-up`, with `roadmap` checking it. ⚠⚠ **Only `wrap-up` writes to these files, and only after the conversation is finished** |
| `docs/reference/` | **The screenshots the user sent that a decision was made from.** Named `YYYY-MM-DD-what-it-shows.png`. ⚠ **`wrap-up` moves them here and deletes the rest, and the user says which is which** |
| `lessons-from-two-dead-games` | **What the two games that died actually measured** |
| `how-nets-lie` | **Every green measured to be false.** Read it before writing a check and before believing a green round |
| `planning-principles` | **How to judge a direction.** Survived both resets on purpose — read it first |

- **An idea the user picks becomes a ticket on the map**, not a design doc. **What is built is read out of
  `src/` and `tests/nets/`.** **When a fork is taken, record the rejected branch in `docs/design/`**
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
| `src/view/` | **Reads `sim`, never writes it.** Everything that is a Node or draws lives here. ⚠ **Every view exposes `_paint_*` hooks**, the field included — but the field's hooks build a 3D world, so **asserting their arguments does not measure what the player sees.** What a net measures here is the three-fold surface named in `CONTEXT.md`, not the hook |
| `src/shell/` | **The only place that reads `Input`**, and the only place that wires `sim` to `view`. It builds its children in code, so a net calling `_ready()` exercises the real wiring |
| `src/look.gd` | **Every presentation constant, in exactly one file.** `src/sim/rules.gd` holds every constant that changes what happens |

⚠⚠ **When the field moved to 3D it took a large share of the checks with it** — what died asserted
pixels, what survived measured **input → state**. ⇒ **Prefer the shape that survives; reach for pixels
only when the pixels are the subject.**

⚠ **`CONTEXT.md` is the glossary and the three agreed test seams** — **no check is written at a seam
that is not named there.** ⚠ **Parts of its vocabulary predate the swap** and still read as though the
beast were the player. **Where a word in it disagrees with `src/`, the code is what is true.**
