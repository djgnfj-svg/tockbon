# tockbon — a **cell autobattler**, and it runs

**A node map of islands, a squad of square cells landed by boat.** 「먹을 것을 고르러 간다」
`run/main_scene` is `src/shell/game.tscn`, and the GDD is `cell-army-gdd`.

**Only the user adds to this file.**

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

**`docs/` is one folder and five loose files, and planning lives outside it in `.scratch/`.**
**Open a folder's README, not the folder.**

| Path | What it holds |
|---|---|
| `docs/design/` | **The GDD, and the forks that were rejected.** The GDD is **one page** — 넘어가면 아무도 안 읽는다. A fork doc opens with a `Status:` line and **a reversal is written onto it, never by deleting it** |
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
| `src/view/` | **Reads `sim`, never writes it.** Everything that is a Node or draws lives here, and **each drawing file exposes a hook** (`_paint_cell`, `_paint_text`) so a net can assert the arguments |
| `src/shell/` | **The only place that reads `Input`**, and the only place that wires `sim` to `view`. It builds its children in code, so a net calling `_ready()` exercises the real wiring |
| `src/look.gd` | **Every presentation constant, in exactly one file.** `src/sim/rules.gd` holds every constant that changes what happens |

**`net_draw_leaf` enforces the drawing half and both constant halves. The `sim`/`view` halves are scanned by
nobody — write those when the folder can drift.**

**`CONTEXT.md` at the root holds the words** — 세포 vs 병사, 슬롯, 소환 띠, 그물 — in 한국어 and in code,
**and the three agreed test seams.** `tdd` will not write a test at a seam that is not named there.
