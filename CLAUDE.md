# tockbon — a **beast roguelike**, and `src/` runs

**Ten beasts take one island at a time from the humans who hold it.** You start as a wolf, the enemy is
human, the first of them cavemen, and **there is no eating for parts** — the art could not carry it.
**Hands do not move during a fight**: where you land decides who you fight, and that is the decision.

**The frame, decided 2026-08-22**: a **demo in December**, not a release · **roguelike** · **funding**
after the demo. **Whether December is also a release is decided the day the demo stands.**

**The code runs and the game launches. There is no GDD.** ⚠ **What is being made is read out of
`.scratch/cell-hook/`** — a map and nine tickets. **Read the map before deciding what this repo is.**

⚠⚠ **`main` is not the whole repo.** Two sessions collided on it once and one rebuilt the docs around a
game folded on another branch. ⇒ **Run `git ls-remote --heads origin` before concluding anything.**

**The other branches**: `62ff57d` is the folded cell game whole; `salvage/cell-harness` is docs discarded
on purpose; `archive-full-history` is everything from before the resets.

# Language

**Replies to the user are 한국어. Docs, comments and prompts are English.**

**One exception: the GDD is 한국어** (2026-08-22, decided by the user) — one page, and the user is the one
who reads it. ⚠ **No twin.** Korean twins existed and were deleted because the same fact living in two
files drifts.

# Reply rule — **the core, and nothing else**

**The answer goes in the first line. Reasons after it, never before.** Every line load-bearing. Stop.

- **Label a recommendation, in two parts and in this order** — **what you recommend · why.**
  An unlabelled paragraph reads as description, and the user cannot tell what is being proposed.
  **Never leave the recommendation to be inferred**
- ⚠ **No 「반대 근거」 attached to a recommendation** (2026-08-22, the user: *"추천 이후 반대 저 부분은 왜
  자꾸 나오는 건지 잘 모르겠네"*). It used to be a required third part and it turned every recommendation
  into a thing the user had to re-decide. **If the case against is strong enough to matter, it is not a
  recommendation — put the fork in a closing question instead**
- ⚠ **Never recommend a technique the user has not named without first checking how others do it**
- **No emoji.** Bold is the only emphasis
- **No file paths, no line numbers, no code locations in chat** — say what the thing is, not where it lives
- **No word only you understand.** A doc name or a net name standing in for the thing is not an answer
- **A reply covering more than one subject is a list**
- **The user is new to making games. Their agreement is the absence of anything to disagree with**

## ⚠ **Every reply ends with a grilling round**

**Grilling is how this repo asks** (2026-08-24, the user: *"그릴링 쓰자"*). ⚠⚠ **This replaces
「exactly one question」**, which the user set 2026-08-22 (*"하나 씩 하나 씩 해줘 하나 씩"*) and
reversed here. **The record of the reversal lives in `idea-inbox`, never in this file.**

**Hold the open decisions as a tree.** The **frontier** is every decision whose prerequisites are already
settled — the questions askable **now**, without guessing at an answer you have not heard yet.
**Ask the whole frontier in one round, then wait.**

- ⚠ **A question whose answer depends on another question still open in this round belongs to a LATER
  round.** That is the one thing that keeps a round from being a wall
- ⚠⚠ **Finding facts is your job, never the user's.** A frontier question needing a fact from the repo,
  the code, or the web — **go get it.** Dispatch a subagent and **do not block**: only the questions
  downstream of it wait. Ask the rest of the frontier now
- **The decisions are the user's.** Put each one to them and wait
- **Done when the frontier is empty** — every branch visited, nothing silently assumed
- ⚠ **A frontier of one is a round of one.** Never pad a round to look like grilling

⚠⚠ **The shape of each question is the user's, given 2026-08-24** (*"질문 추천 왜 / 질문 : /
추천 : / 왜: / 이렇게가 맞는데.."*). **A horizontal rule, then numbered blocks of three labelled lines:**

```
---
**질문 1** : <one line>
**추천** : <one line>
**왜** : <one line>

**질문 2** : <one line>
**추천** : <one line>
**왜** : <one line>
```

- **One line each.** The reasoning that does not fit belongs in the body above, not in these lines
- ⚠ **Only ask what has a recommendation and a reason.** A confirmation check is not a question
- ⚠ **Do not bury the recommendation in prose above and leave a bare question at the bottom** — that is
  what this replaces. The user: *"질문이 너무 길어서 그래서 정확하게 뭘 말하는 건지 잘 모르겠네"*
- ⚠ **No emoji, still.** The imported grilling template uses them; **this repo's no-emoji rule wins**

# Nothing pretends to work

**Code that pretends to work is worse than code that doesn't, and a green that measures less than its
label says is worse than a red. If you can't do it, say you can't.**

# The docs

**`docs/` is two folders and five loose files; planning lives outside it in `.scratch/`.** **Open a
folder's README, not the folder.**

| Path | What it holds |
|---|---|
| `docs/design/` | **What is being made, and the forks that were rejected.** ⚠ **Nearly empty, and that is a defect** — there is no GDD. When one is written it is **one page** — 넘어가면 아무도 안 읽는다. A fork doc opens with a `Status:` line and **a reversal is written onto it, never by deleting it** |
| `docs/agents/` | **What the imported skills read before they act, and the only configuration in `docs/`.** ⚠ **Not reading matter** — `to-spec` · `to-tickets` · `triage` · `code-review-mp` load it |
| `.scratch/<일>/` | **Where planning lives.** `map.md` is the map; `issues/NN-이름.md` are its tickets. **Status is a `Status:` line inside the file — files never move between folders.** `wayfinder` owns this |
| `lessons-from-two-dead-games` | **What the two games that died actually measured** |
| `idea-inbox` | **What the user said, before anyone decided what to do with it.** One row per remark, verbatim, dated, with a state |
| `acceptance-debt` | **What shipped and nobody has looked at**, and under 「본 것」 **the user's own words about a game, never deleted** — they are the only judgement this repo has ever received about whether a game of its own was any good. Filled at `wrap-up`; a row leaves only when the user says they looked |
| `how-nets-lie` | **Every green measured to be false.** Read it before writing a check and before believing a green round |
| `planning-principles` | **How to judge a direction.** Survived both resets on purpose — read it first |

- **What the user says in passing goes into `idea-inbox` that turn** — verbatim, dated, with a state, and
  **nothing is deleted from it**
- **A picked idea becomes a ticket on the map**, not a design doc. **What is built is read out of `src/`
  and `tests/nets/`.** **When a fork is taken, record the rejected branch in `docs/design/`**
- **When the user says they looked at something, their own words go into `acceptance-debt` that turn** —
  ⚠⚠ **verbatim.** 「잘되네」「조작감이 너무 ㅈ같음」「참 애매하네」 were lost once with a deleted doc, and
  they were the only measurement this repo had of whether the game is any good
- **Skeleton first, flesh later.** Do not demand every `TBD` be filled before implementing

# How the code is laid out

**Where a new file goes is decided by this table and nothing else** — it is what lets a net drive the
whole game headless in seconds.

| Path | The rule it obeys |
|---|---|
| `src/sim/` | **Never touches the tree.** No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`. Every file is constructible and drivable with `.new()` and nothing else |
| `src/view/` | **Reads `sim`, never writes it.** Everything that is a Node or draws lives here. ⚠ **The six 2D views expose a `_paint_*` hook** so a net can assert the arguments; **the field does not** — it builds a 3D world instead, and what replaces the hook is ticket 09's first question |
| `src/shell/` | **The only place that reads `Input`**, and the only place that wires `sim` to `view`. It builds its children in code, so a net calling `_ready()` exercises the real wiring |
| `src/look.gd` | **Every presentation constant, in exactly one file.** `src/sim/rules.gd` holds every constant that changes what happens |

⚠⚠ **Measured 2026-08-24: of 2841 checks, 1033 were tied to drawing in 2D and about 480 did not survive
the field moving to 3D.** What survived measured **input → state**; what died asserted pixels. ⇒ **Prefer
the shape that survives; reach for pixels only when the pixels are the subject.**

⚠ **`CONTEXT.md` holds the magic-circle words and is wrong.** It is the glossary **and the three agreed
test seams**; `tdd` will not write a test at a seam that is not named there.
