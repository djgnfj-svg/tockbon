# tockbon

Loaded into every session and every agent. **Keep only what applies to everyone** — rules an agent must
have **without reading anything.** Everything else is a doc.
⇒ **Before adding here, ask whether the doc that owns the subject should hold it instead.**

## The game — a **cell autobattler**, and it runs

**A node map of islands, a squad of square cells landed by boat.** 「먹을 것을 고르러 간다」

⇒ **Read `cell-army-gdd` before proposing anything, then `idea-inbox`** — the GDD is behind the user, and
the inbox is the only place the open remarks are indexed. `run/main_scene` is `src/shell/game.tscn`.

## No `git push` until 2026-08-22 (decided by the user)

Local commits pile up as normal — only the remote is frozen. `gh-pages` redeploy counts as a push. The NAN
2026 submission links must stay exactly as judged. **`wrap-up` stops at the commit.** Delete this section
once the date passes. **The submission itself is safe from anything done locally** — judges see `origin/main`
and `gh-pages`, and neither moves while the freeze holds.

## Language

- **Replies to the user are 한국어.**
- **Docs, comments and prompts are English.**
- **Keep a reply short and load-bearing.** When it covers more than one subject, lay it out as a list so it
  reads cleanly.

## Reply rule — **the core, and nothing else**

Length is not the rule; **every line being load-bearing is.** A long reply that circles the point goes
unread, and a short one that hides the answer is worse. **Answer, then stop.**

- **No emoji. No dates.** Bold is the only emphasis
- **No file paths, no line numbers, no code locations in chat.** The user does not open them — say what the
  thing is, not where it lives
- **No word only you understand.** A doc name, a net name or an internal term standing in for the thing is
  not an answer. Say it in the words the user used
- **Don't ask.** Look in the conversation first. If you must ask, one sentence

### When asked how others do it — name the technique, and who ships it

**The user is new to making games and said so**: *"I have no data, so whatever you say feels like it must be
right."* **That is the absence of anything to disagree with, not agreement.**

- **Name the technique first, then the games or studios that ship it** — several, disagreeing with each other
- **Checkable sources only.** *"Usually in the industry…"* is not one, and neither is this file. **Look it up
  rather than remembering it** — a studio named from memory that turns out wrong is worse than no example
- **One line each.** The user is picking something to build, not reading an essay
- **Give the case against your own recommendation too**
- **This binds technical choices as well** — engines, libraries, tooling, verification

## Where things live

**`docs/` is two folders and four loose files. Each folder's README is its index — open the README, not the
folder.**

| Path | What it holds |
|---|---|
| `docs/design/` | **Concepts, and the forks that were rejected.** Every doc's header carries `Implemented` and `Accepted` as **two separate axes.** The GDD is `cell-army-gdd` |
| `docs/plans/` `1.ready` `2.active` `3.done` | **The only folder that moves.** One doc per implementation |
| `idea-inbox` | **What the user said, before anyone decided what to do with it.** One row per remark, verbatim, dated, with a state |
| `how-nets-lie` | **Every green measured to be false.** Read it before writing a check and before believing a green round |
| `planning-principles` | **How to judge a direction.** Survived both resets on purpose — read it first |
| `lessons-from-two-dead-games` | **What two deleted games measured**, and the two resets. ⚠ **Nothing in it is a spec** |


**When the user says something in passing, it goes into `idea-inbox` as one row, that turn.** Verbatim,
dated, with a state. **Nothing is deleted from it.** *"내가 그냥 대화를 하고 있지만 사실 항상 아이디어를
내는 거거든? 근데 니가 그냥 지워버림."*

**Once an idea is picked, it grows into a `docs/design/` doc with one row in that README**, headed
`Implemented` and `Accepted` — without them, "written down" reads as "exists".

**When a fork is taken, record the rejected branch in `docs/design/`.** Laying out options and letting the
user pick means two or three unpicked options appear every round and only the picked one is written down.
Months later the same options get laid out from scratch. **The user lived this with inventory, and again with
the whole game.**


## Acceptance goes into the doc the moment it happens

When the user says "confirmed" or "I can see it", whoever heard it writes it under the design doc's
`Accepted` section **immediately. Conversations are lost; the repo is kept.**

**`3.done/` means "implementation finished", not "acceptance passed".**

⚠ **Acceptance does not close by inference.** A build existing, a video existing, an agent having walked
through it — **none of those is the user saying it read right.** A paragraph once claimed a milestone was met
on the strength of a play video existing; that is reasoning backwards from an artifact.

**This is the failure that killed game one.** Thirty-four features shipped, five acceptance checks left open,
**no moment in eight months was fun**, and nobody had ever run the loop end to end. ⇒ **A feature nobody has
looked at is not progress.**

### Worktrees

- **A verifier in an isolated worktree cannot write docs** — its edits live only in the copy. **The spawner
  writes; the verifier reports.** Afterwards `git worktree remove --force` + `prune` (automatic cleanup
  almost never fires — 700MB in one night, measured)
- **A fresh worktree has no `.godot` import cache and every net goes red for it** — not a code failure.
  ⚠ **`--headless --script` does NOT re-import**, measured twice on 4.7.1: a brand-new `class_name` file is
  invisible until an explicit `--import`. **This bites in the main tree too**, every time a plan adds a
  `class_name` file. `run_nets.ps1` runs the import itself when it sees a `.gd` with no `.uid` beside it
- **A worktree freezes at the commit it branched from.** Re-branch from `main` right before starting — two
  agents once built a session's work against a base that did not know the day's other changes had landed

**Skeleton first, flesh later.** Do not demand every `TBD` in a design doc be filled before implementing.

## Folders are contracts

| Path | The rule it obeys |
|---|---|
| `src/sim/` | **Never touches the tree.** No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`. Every file is constructible and drivable with `.new()` and nothing else |
| `src/view/` | **Reads `sim`, never writes it.** Everything that is a Node or draws lives here, and **each drawing file exposes a hook** (`_paint_cell`, `_paint_text`) so a net can assert the arguments |
| `src/shell/` | **The only place that reads `Input`**, and the only place that wires `sim` to `view`. It builds its children in code, so a net calling `_ready()` exercises the real wiring |
| `src/look.gd` | **Every presentation constant, in exactly one file.** `src/sim/rules.gd` holds every constant that changes what happens |

**All four hold today and nets enforce the drawing half** (`net_draw_leaf`). ⚠ **Its per-function table scans
the functions it NAMES and nothing else, and that leaked twice — the second time out of the fix for the
first.** A bare `c.draw_circle(...)` reached the screen every frame with 1414 checks green; naming eight more
composers still left eleven of twenty-eight functions outside, and it was green again at 1889. ⇒ **Close the
class instead: walk the file's own `func` lines and redden on any name the table does not hold.**

**The `sim`/`view` halves were never scanned at all**: grep `src/sim/` for `extends Node` · `_draw` ·
`Input.` · `get_node` · `$`, and `src/view/` for writes to `sim.`. Write each when its folder can drift.

**The one-file rule for presentation constants was measured**: scattering them meant the power doubled and
**zero things changed on screen**, because the numbers that would have shown it were in six places.
⚠ **The colour half is scanned; the PIXEL half was never written**, so that green never meant "no
presentation constant is loose".

⚠ **A `const` packed array does not parse. Measured twice on 4.7.1**: `const X := PackedInt32Array([1,2,3])`
is a parse error — *"Assigned value for constant isn't a constant expression"* — while a plain `const X :=
[1,2,3]` is fine and nests fine. A `const` Array is read-only in 4.x so immutability survives; **element
typing does not**, which is why every read casts. **Every flat table this repo writes walks into it.**

**A flat array of bodies is a correctness contract, not a performance one.** 300 `Node2D`s cost 0.065ms —
**the engine was never the wall.** Keeping `carried[i]` in a flat array is what made *"a body killed far from
home loses its cargo"* **structurally true**, with no code that had to remember to drop it.

## Comments

- **Write why doing it differently dies silently.** What the code does, the code says
- Keep measurements where they were taken. If the same explanation appears twice, move it to one place
- Point at a doc; never summarize one
- **Name a doc; never path it, never line-number it.** A doc under `docs/plans/` changes folders with its
  status, so the path dies that day — and **a line number is a path into a file.** Adding four lines to one
  header killed ten citations at once. **Name the section, not the number.** This leak was found four
  separate times in one night, each time by someone other than whoever caused it
- ⇒ **`net_citations` greps `src/`, `tests/` and `tools/` and fails on both forms** — and reads `docs/` and
  `CLAUDE.md` too, **but there only for the line-number form.** ⚠ **A pathed citation inside a doc is
  therefore NOT caught**, which is where the docs cite each other most. **It must rejoin wrapped comment
  lines before matching** — a line-wise scan passed three of eleven because the path wrapped across two `##`
  lines. Honour-based did not hold: seventeen line-number citations existed and **six were already dead**,
  one of them cited by the rule forbidding the shape

## No fake code

Code that pretends to work is worse than code that doesn't.

- Hardcoding for this input or this test only · returning a plausible value instead of computing one ·
  reporting a stub as finished · swallowing an error so it looks like success
- **Screen changes but sim doesn't (or the reverse)** — the signature fake

If you can't do it, say you can't.

**One whole class of it was structural, not dishonest.** The deleted game ran three clocks (render, 60Hz
physics, a 20Hz tick) and **five separate defects came out of the seam between them.** ⇒ **If this game ever
runs a fixed timestep under its render loop, read `how-nets-lie` again and write the traps down as they are
measured.**

## No fake nets

When the label claims more than the check measures, that green is a false guarantee.

**Invert every new check.** An uninverted check proves "it runs", not "it measures" — and **a new check
needs a case that fails *it*, not only the subject.** Twice in one night a check was written to catch a
defect and shipped carrying that same defect.

⚠ **The rules for writing one are in `tests/README`; the cases are in `how-nets-lie` — 129 lines of greens
that guaranteed nothing, each one measured. Read it before writing a check and before believing a green
round.** Its four sharpest: **a check that greps a file measures its text, never what it computes** · **a spy
on a hook never sees the native call inside it** · **"`_draw()` ran" is not "anything was drawn"** · **a
ceiling with no floor passes an effect that never happens.**


## Running the nets

**17 nets, 2473 checks, 4.7 seconds, green.** The old game reached 25 / 3541 / 4.6s — ⚠ **a scale marker,
not a target.** Those nets drove a game deleted for not being fun.

⚠ **"N passed" is not green.** `load()` returns non-null on a parse failure, so only the final `[wrapper]`
line decides — and **a net that ran zero checks is a failure.**

⇒ **How the runner behaves, and the six traps measured in it, are in `tests/README`. Read it before
writing a net or believing a round.**


## Agent models

The caller decides `model`. A model pinned in the definition file wins (`harness-manager` = sonnet, the only one).

| Character | Model |
|---|---|
| Judgment changes the outcome — spec · verify-read · verify-look · design | opus |
| Executes a plan — builder | sonnet |
| Mechanical — reading values, finding files | haiku |

**Never lower verification to save money.** The signature failure is "pretends to run", and verify-read ·
verify-look are what catch it. **And the verifier is never the builder** — measured: a builder closed a hole
in one file and left the identical one open one file over; a verifier who had not built it found it.

## Screenshots without the editor

**`tools/look/` screenshots the game itself** — windowed, ten frames in about ten seconds, quitting on its
own, every input through the engine so **nothing is taken from the user.** Read its README first.
**The godot MCP bridge is verify-look's alone and is documented on that agent.**

⚠ **`--headless` cannot capture** — no swapchain, `root.get_texture()` comes back blank, every PNG a black
rectangle **with no error anywhere.** (Headless still turns real frames and really runs `_draw()`.)
⚠ **Take the known-answer shot before trusting any other**: its first close-up came back at play scale
because `_apply_zoom()` rewrote the camera before the shot, silently.
