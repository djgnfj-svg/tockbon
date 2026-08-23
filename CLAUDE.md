# tockbon — a **beast roguelike**, and `src/` runs

**Ten beasts take one island at a time from the humans who hold it.** ⚠ **The lines below still describe
the cell game**, which the user left behind on 2026-08-22 — **eating for parts is out** (the art could not
carry it) and **the player's side is wolves, the enemy is humans, the first of them cavemen.**
**The map under `.scratch/cell-hook/` is what this repo is making; this file is behind it.**
**Hands do not move during a fight** — where you land decides who you fight, and that is the decision.
⚠ **The hook is that the assembled body reads on screen** (2026-08-22, the user). The parts exist; the body
does not show them yet. **Everything else hangs off that.**

**The frame, decided 2026-08-22**: a **demo in December**, not a release · **roguelike** · **funding** after
the demo. **Whether December is also a release is decided the day the demo stands.**

⚠⚠ **This was measured false on 2026-08-24 and is replaced.** It said there was no `run/main_scene` and
the code was not restored. **The code is restored and the game launches**; `run/main_scene` points at the
shell scene; **twenty nets run green (2841 checks, 4.6s).** **There is still no GDD** — that one stands.
**What is being made is read out of `.scratch/cell-hook/`** — a map and eight tickets, three of them closed.

⚠⚠ **The magic-circle game was picked the morning of 2026-08-22 and dropped that evening.** The deadline
dropped it: with one, **the side whose concept already stands wins.** **Its design was kept as an idea.**

# Where everything is — **read this before deciding what this repo is**

⚠⚠ **`main` is not the whole repo, and on 2026-08-22 two sessions collided on it twice.** The first read
`main` only, concluded the cell game was still live, and rebuilt docs around a game folded on another
branch. The second wrote to `main` while this one worked, and the two had different games in mind.
**Nothing was lost the second time — both sides were merged.**

⇒ **Run `git ls-remote --heads origin` before you conclude anything about direction.** What is on `main`
is what was merged, never what exists.

| Where | What is in it |
|---|---|
| `main` | **Everything current.** All of the above is merged here as of 2026-08-22 |
| `62ff57d` | **The cell game, whole** — `src/`, twenty nets, its GDD, its eight dropped forks. **This is what is being made**, and restoring it is a live decision, not a rollback |
| `salvage/cell-harness` | Seven commits that polished the cell game's docs on 2026-08-22, **discarded on purpose** when the fold was found. Kept only so nothing was thrown away silently |
| `archive-full-history` | The full history from before the resets |

**The user's own words about a game are in `acceptance-debt` under 「본 것」, and they are never deleted** —
they went missing once already, inside design docs that were deleted, and they are the only judgement this
repo has ever received about whether a game of its own was any good.

# Language

**Replies to the user are 한국어. Docs, comments and prompts are English.**

**One exception: the GDD is 한국어** (2026-08-22, decided by the user). It is one page and **the user is
the one who reads it** — an English GDD they never open is not a GDD. ⚠ **No twin.** Korean twins existed
and the user deleted them on 2026-08-19 because the same fact living in two files drifts.

# Reply rule — **the core, and nothing else**

**The answer goes in the first line. Reasons after it, never before.** Every line load-bearing.
Answer, then stop.

- **Label a recommendation, in two parts and in this order** — **what you recommend · why.**
  An unlabelled paragraph reads as description, and the user cannot tell what is being proposed.
  **Never leave the recommendation to be inferred**
- ⚠ **No 「반대 근거」 attached to a recommendation** (2026-08-22, the user: *"추천 이후 반대 저 부분은 왜
  자꾸 나오는 건지 잘 모르겠네"*). It used to be a required third part and it turned every recommendation
  into a thing the user had to re-decide. **If the case against is strong enough to matter, it is not a
  recommendation — put the fork in the one closing question instead**
- ⚠ **Never recommend a technique the user has not named themselves without first checking how others do
  it** — named techniques, and who ships them. This was a skill until 2026-08-22 and the skill was deleted;
  **the guard is what was worth keeping**
- **No emoji.** Bold is the only emphasis
- **No file paths, no line numbers, no code locations in chat** — say what the thing is, not where it lives
- **No word only you understand.** A doc name or a net name standing in for the thing is not an answer
- **A reply covering more than one subject is a list**
- **The user is new to making games. Their agreement is the absence of anything to disagree with**

## ⚠ **Every reply ends with exactly one question**

**One.** 2026-08-22, the user: *"지금 질문이 뭐야 그래서 내가 정해야 될 게 뭐고 하나 씩 하나 씩 해줘 하나 씩."*

- **It is the last line**, and it is the **one thing the user must decide next** — not a status check, not
  「이렇게 할까요」 on something already decided
- **Never two.** Two questions is the failure this rule exists to stop. Whatever is second waits for the
  next reply
- ⚠ **This replaces 「Don't ask」**, which produced replies with nothing to answer and left the user to work
  out what was being put to them

# Nothing pretends to work

**Code that pretends to work is worse than code that doesn't, and a green that measures less than its
label says is worse than a red. If you can't do it, say you can't.**

# The docs

**`docs/` is two folders and five loose files, and planning lives outside it in `.scratch/`.**
**Open a folder's README, not the folder.**

| Path | What it holds |
|---|---|
| `docs/design/` | **What is being made, and the forks that were rejected.** ⚠ **It is nearly empty and that is a defect** — the cell game's GDD and its eight dropped forks are at `62ff57d` and were not brought back. ⚠ **There is no GDD right now** — the cell one went with the game and the new one waits on the map. When one is written it is **one page** — 넘어가면 아무도 안 읽는다. A fork doc opens with a `Status:` line and **a reversal is written onto it, never by deleting it** |
| `docs/agents/` | **What the imported skills read before they act, and the only configuration in `docs/`.** Issues are files under `.scratch/`; the five triage labels are unchanged; the domain is single-context, so `CONTEXT.md` at the root is the glossary. ⚠ **Not reading matter** — `to-spec` · `to-tickets` · `triage` · `code-review-mp` load it |
| `.scratch/<일>/` | **Where planning lives.** `map.md` is the map; `issues/NN-이름.md` are its tickets. **Status is a `Status:` line inside the file — files never move between folders.** `wayfinder` owns this |
| `lessons-from-two-dead-games` | **What the two games that died actually measured.** The only survivor of both resets besides `planning-principles` |
| `idea-inbox` | **What the user said, before anyone decided what to do with it.** One row per remark, verbatim, dated, with a state |
| `acceptance-debt` | **What shipped and nobody has looked at.** Filled at `wrap-up`; a row leaves only when the user says they looked |
| `how-nets-lie` | **Every green measured to be false.** Read it before writing a check and before believing a green round |
| `planning-principles` | **How to judge a direction.** Survived both resets on purpose — read it first |

- **What the user says in passing goes into `idea-inbox` that turn** — verbatim, dated, with a state.
  **Nothing is deleted from it**
- **A picked idea becomes a ticket on the map**, not a design doc. ⚠ **The `Implemented` / `Accepted`
  headers are gone** — ten concept docs carried them and were deleted on 2026-08-22 because nobody could
  read them. **What is built is read out of `src/` and `tests/nets/`**, and what the user has judged is
  read out of `acceptance-debt`
- **When a fork is taken, record the rejected branch in `docs/design/`**
- **When the user says they looked at something, their own words go into `acceptance-debt` that turn** —
  ⚠⚠ **verbatim.** On 2026-08-22 the design docs were deleted and 「잘되네」「조작감이 너무 ㅈ같음」
  「참 애매하네」 went with them. **Those quotes were the only measurement this repo had of whether the
  game is any good.** The rest of acceptance is `wrap-up`'s
- **Skeleton first, flesh later.** Do not demand every `TBD` be filled before implementing

# How the code is laid out

**Where a new file goes is decided by this table and nothing else.** It is what lets a net drive the whole
game headless in seconds.

| Path | The rule it obeys |
|---|---|
| `src/sim/` | **Never touches the tree.** No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`. Every file is constructible and drivable with `.new()` and nothing else |
| `src/view/` | **Reads `sim`, never writes it.** Everything that is a Node or draws lives here. ⚠ **The six 2D views still expose a `_paint_*` hook** so a net can assert the arguments; **the field does not any more** — it builds a 3D world instead, and what replaces the hook is ticket 09's first question |
| `src/shell/` | **The only place that reads `Input`**, and the only place that wires `sim` to `view`. It builds its children in code, so a net calling `_ready()` exercises the real wiring |
| `src/look.gd` | **Every presentation constant, in exactly one file.** `src/sim/rules.gd` holds every constant that changes what happens |

⚠⚠ **The paragraph that used to sit here was measured false on 2026-08-24 and is replaced.** It said
`net_draw_leaf` had gone with the cell game, that two nets were left, and that the folder rule was
honour-based. **`src/` and all twenty nets are back**, and **the whole round was run twice that day:
2841 checks, 0 failures, 4.6s, stderr clean.** `net_draw_leaf` runs and does scan `src/view/` — the
per-function `draw_*` table, the closed function class, the leaf arguments, and both constant halves.

⚠ **What is honestly weak is different, and it is measured** (ticket 08 counted it): **1033 of the 2841
are tied to drawing in 2D.** About **550 of those survive a move to 3D and about 480 do not** —
`net_camera` dies whole (46, it pins one 2D expression), `net_fx_view` almost whole (210 of 227, it
asserts `_paint_*` arguments in pixels). **The two that mostly survive, `net_shell` and `net_slots`,
survive because they measure input → state, not paint.** ⇒ **When writing a new check, prefer the shape
that survives: assert what the hand did to the state, and reach for pixels only when the pixels are the
subject.**

⚠⚠ **`CONTEXT.md` still holds the magic-circle words and is wrong** — it is rewritten when the cell game
comes back. **It holds the words** — 그물, and the cell game's own — in 한국어 and in code,
**and the three agreed test seams.** `tdd` will not write a test at a seam that is not named there.
⚠ **Every word in it is a design, not a measurement, until `src/` holds it** — the file says so itself.
