# tockbon — a **cell autobattler**, and it runs

**A node map of islands, a squad of square cells landed by boat.** 「먹을 것을 고르러 간다」
`run/main_scene` is `src/shell/game.tscn`, and the GDD is `cell-army-gdd`.

**Only the user adds to this file.**

# Language

**Replies to the user are 한국어. Docs, comments and prompts are English.**

# Reply rule — **the core, and nothing else**

**The answer goes in the first line. Reasons after it, never before.** Every line load-bearing.
Answer, then stop.

- **Label a recommendation, in these three parts and in this order** — **what you recommend · why ·
  the case against it.** An unlabelled paragraph reads as description, and the user cannot tell what is
  being proposed. **Never leave the recommendation to be inferred**
- **No emoji.** Bold is the only emphasis
- **No file paths, no line numbers, no code locations in chat** — say what the thing is, not where it lives
- **No word only you understand.** A doc name or a net name standing in for the thing is not an answer
- **Don't ask.** Look in the conversation first. If you must ask, one sentence
- **A reply covering more than one subject is a list**
- **The user is new to making games. Their agreement is the absence of anything to disagree with**

# Nothing pretends to work

**Code that pretends to work is worse than code that doesn't, and a green that measures less than its
label says is worse than a red. If you can't do it, say you can't.**

# No `git push` until 2026-08-22 (decided by the user)

Local commits are normal; only the remote is frozen. `gh-pages` redeploy counts as a push. **`wrap-up` stops
at the commit.** Delete this section once the date passes.

# The docs

**`docs/` is two folders and four loose files. Open a folder's README, not the folder.**

| Path | What it holds |
|---|---|
| `docs/design/` | **Concepts, and the forks that were rejected.** Every doc's header carries `Implemented` and `Accepted` as **two separate axes.** The GDD lives here |
| `docs/plans/` `1.ready` `2.active` `3.done` | **The only folder that moves.** One doc per implementation |
| `idea-inbox` | **What the user said, before anyone decided what to do with it.** One row per remark, verbatim, dated, with a state |
| `acceptance-debt` | **What shipped and nobody has looked at.** Filled at `wrap-up`; a row leaves only when the user says they looked |
| `how-nets-lie` | **Every green measured to be false.** Read it before writing a check and before believing a green round |
| `planning-principles` | **How to judge a direction.** Survived both resets on purpose — read it first |

- **What the user says in passing goes into `idea-inbox` that turn** — verbatim, dated, with a state.
  **Nothing is deleted from it**
- **A picked idea grows into a `docs/design/` doc with one row in that README**, headed `Implemented` and
  `Accepted` — without them, "written down" reads as "exists"
- **When a fork is taken, record the rejected branch in `docs/design/`**
- **When the user says they looked at something, the verdict goes under that design doc's `Accepted`
  section that turn.** The rest of acceptance is `wrap-up`'s
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
