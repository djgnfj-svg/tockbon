# tockbon

Loaded into every session and every agent. **Keep only what applies to everyone** — rules an agent must
have **without reading anything.** Everything else is a doc.
⇒ **Only the user adds to this file**, and before adding, ask whether the doc that owns the subject should
hold it instead. ⚠ **No examples, no case history, no measurements** — whoever needs the evidence opens the
doc that owns it.

## The game — a **cell autobattler**, and it runs

**A node map of islands, a squad of square cells landed by boat.** 「먹을 것을 고르러 간다」

⇒ **Read `cell-army-gdd` before proposing anything, then `idea-inbox`.** `run/main_scene` is
`src/shell/game.tscn`.

## No `git push` until 2026-08-22 (decided by the user)

Local commits are normal; only the remote is frozen. `gh-pages` redeploy counts as a push. **`wrap-up` stops
at the commit.** Delete this section once the date passes.

## Language

**Replies to the user are 한국어. Docs, comments and prompts are English.**

## Reply rule — **the core, and nothing else**

**Every line load-bearing. Answer, then stop.**

- **No emoji. No dates.** Bold is the only emphasis
- **No file paths, no line numbers, no code locations in chat** — say what the thing is, not where it lives
- **No word only you understand.** A doc name or a net name standing in for the thing is not an answer
- **Don't ask.** Look in the conversation first. If you must ask, one sentence
- **A reply covering more than one subject is a list**

### When asked how others do it — name the technique, and who ships it

**The user is new to making games. Their agreement is the absence of anything to disagree with.**

- **Name the technique first, then the games or studios that ship it** — several, disagreeing with each other
- **Checkable sources only, and look it up rather than remembering it.** This file is not a source
- **One line each**, and **give the case against your own recommendation**
- **This binds technical choices as well** — engines, libraries, tooling, verification

## Where things live

**`docs/` is two folders and four loose files. Open a folder's README, not the folder.**

| Path | What it holds |
|---|---|
| `docs/design/` | **Concepts, and the forks that were rejected.** Every doc's header carries `Implemented` and `Accepted` as **two separate axes.** The GDD is `cell-army-gdd` |
| `docs/plans/` `1.ready` `2.active` `3.done` | **The only folder that moves.** One doc per implementation |
| `idea-inbox` | **What the user said, before anyone decided what to do with it.** One row per remark, verbatim, dated, with a state |
| `how-nets-lie` | **Every green measured to be false.** Read it before writing a check and before believing a green round |
| `planning-principles` | **How to judge a direction.** Survived both resets on purpose — read it first |
| `lessons-from-two-dead-games` | **What two deleted games measured**, and the two resets. ⚠ **Nothing in it is a spec** |

- **What the user says in passing goes into `idea-inbox` that turn** — verbatim, dated, with a state.
  **Nothing is deleted from it**
- **A picked idea grows into a `docs/design/` doc with one row in that README**, headed `Implemented` and
  `Accepted` — without them, "written down" reads as "exists"
- **When a fork is taken, record the rejected branch in `docs/design/`**

## Acceptance goes into the doc the moment it happens

When the user says "confirmed" or "I can see it", whoever heard it writes it under the design doc's
`Accepted` section **immediately. Conversations are lost; the repo is kept.**

- **`3.done/` means "implementation finished", not "acceptance passed"**
- ⚠ **Acceptance does not close by inference.** A build, a video, an agent having walked through it —
  **none of those is the user saying it read right**
- ⇒ **A feature nobody has looked at is not progress**
- **Skeleton first, flesh later.** Do not demand every `TBD` be filled before implementing

## Folders are contracts

| Path | The rule it obeys |
|---|---|
| `src/sim/` | **Never touches the tree.** No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`. Every file is constructible and drivable with `.new()` and nothing else |
| `src/view/` | **Reads `sim`, never writes it.** Everything that is a Node or draws lives here, and **each drawing file exposes a hook** (`_paint_cell`, `_paint_text`) so a net can assert the arguments |
| `src/shell/` | **The only place that reads `Input`**, and the only place that wires `sim` to `view`. It builds its children in code, so a net calling `_ready()` exercises the real wiring |
| `src/look.gd` | **Every presentation constant, in exactly one file.** `src/sim/rules.gd` holds every constant that changes what happens |

**`net_draw_leaf` enforces the drawing half and both constant halves. The `sim`/`view` halves are scanned by
nobody — write those when the folder can drift.**

⚠ **A `const` packed array does not parse on 4.7.1.** `const X := PackedInt32Array([1,2,3])` is a parse
error; a plain `const X := [1,2,3]` is fine and stays read-only, but **element typing does not survive**,
which is why every read casts.

## Comments

- **Write why doing it differently dies silently.** What the code does, the code says
- **Keep a measurement where it was taken, and let one place own an explanation**
- **Point at a doc; never summarize one**
- **Name a doc; never path it, never line-number it.** `net_citations` fails on both forms

## No fake code

Code that pretends to work is worse than code that doesn't. **Screen changes but sim doesn't (or the
reverse) is the signature fake.** The other shapes are on `builder` and `verify-read`.
**If you can't do it, say you can't.**

## No fake nets

When the label claims more than the check measures, that green is a false guarantee.
**Invert every new check**, and **a new check needs a case that fails *it*, not only the subject.**

⚠ **The rules for writing one are in `tests/README`; the cases are in `how-nets-lie`. Read both before
writing a check and before believing a green round.**

## Running the nets

⇒ **How the runner behaves, and the traps measured in it, are in `tests/README`.**

## Agent models

**The caller picks it — judgment work gets the strongest model, mechanical work the cheapest, and a model
pinned in an agent's own file wins.** ⚠ **Never lower verification to save money, and the verifier is never
the builder** — the tier for each agent is on `implement-plan`.

## Screenshots

**Seeing the screen is `verify-look`'s alone** — the bridge and the game's own capture tool are documented
on that agent.
