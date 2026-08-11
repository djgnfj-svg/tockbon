# tockbon

Loaded into every session and every agent. **Keep only what applies to everyone.**

## Language — answer the user in Korean, always

**Every reply to the user is in 한국어.** Even when they write in English — they cannot read English.

Docs, comments and prompts are English. **Korean is what the user reads**: their own commands,
commit messages, in-game text (material names, HUD), **net check labels** and the net runner's console output.
Details and the terminology table are in `docs/plans/3.done/english-migration.md`.

**A `push_error` message and the `t.expect_error` that forgives it are one unit** — they are matched by plain
substring, so translating one side alone leaves the bark undeclared and the wrapper's silence check fails.
Change both in the same edit.

## Reply rule — **the whole reply under 50 characters**

"Be brief" didn't work, so it is a number now (decided by the user). Long replies go unread and block work.

- **Not one sentence — the entire reply is 50 chars.** Over that, write it in a doc and name the file
- **No tables or lists in chat.** Docs carry detail
- **Don't ask.** Look for the answer in the conversation first. If you must ask, one sentence
- **No emoji.** Bold is the only emphasis
- **No dates.** "Decided by the user" is enough. Only a reversed decision needs one
- **Cut every word that isn't load-bearing** — in docs and in chat

### The exception — **when the user asks to be told something, answer in chat** (decided by the user)

**The 50 characters govern work reports** ("done", "here's the file"). **They do not govern answers.**
When the user asks a question — "what is this", "list the options", "how does it work", "what's next and why" —
**write the answer, and a list is allowed.** Keep it as short as it can be while still answering; do not pad.

**Filing the answer in a doc and replying with the filename is the failure this exception exists to stop.**
A doc may be written *as well*, when the answer is worth keeping — **but the chat still carries the answer.**

## Where things live

| Looking for | Go to |
|---|---|
| How nets die · mutation testing | `.claude/agents/verify-read.md` |
| Net speed · runner internals | `.claude/agents/harness-manager.md`, `tests/run_nets.ps1` |
| Headless observation traps | `.claude/agents/verify-run.md` |
| Editor bridge · screenshots | `.claude/agents/verify-look.md` |
| Team operation · when to verify | `.claude/skills/build-feature/SKILL.md` |

| Doc | Question it answers |
|---|---|
| `docs/GDD.md` | What is this game |
| `docs/archive/nan2026/` | **What was submitted to NAN 2026. Closed — read it, don't update it** |
| `docs/design/` | What does this feature look like |
| `docs/decisions/` | **Why was that not done** |
| `docs/plans/` `1.ready` `2.active` `3.done` | What are we building now |

`design/` and `decisions/` never move between folders. Only `plans/` moves.

**Never state the same thing twice.** GDD holds the face and points at the detail.
A value counted in two places will diverge.

**A refutation that lands in a different doc than the claim does not propagate.** `water.md` said a wide bowl
never settles; `water-and-chunk-sleep.md` had **already measured it settling** and written "that conclusion
is false up to width 256" — **in its own file.** `water.md` was never corrected, its stronger reading
("never" rather than "not by tick 4,000") was inherited by `stage2-water.md`, and a stage's whole cost model
was built on it. ⇒ **When a measurement refutes another doc, go and edit that doc.** Recording the refutation
where you happen to be standing is how the same wrong number gets inherited twice.

**And a correction pass only checks the row that makes a claim.** The same table held two rotted numbers: the
loud one (a bowl that "never settles") was re-measured, and the quiet one beside it — 2,798 ticks, actually
**115** — was waved through, with a correction box explicitly writing *"the 32-cell bowl's 2,798 stands."*
It survived **because it was not making a dramatic claim.** ⇒ **Re-measure the whole table, not the row
someone is arguing about.**

**When a fork is taken, record the rejected branch in `docs/decisions/`** — what was dropped
and why, nothing else. Format lives in that folder's README.

**When a feature comes up in conversation, create a `docs/design/` doc and add one row to its README.**
Head the doc with two lines, `Implemented` and `Accepted` — without them, "written down" reads as "exists".

**Moving a `plans/` doc means three edits**: fix the `**Status**:` line inside it (there is exactly one),
fix every link pointing at it, and report all three folders as a table. **Links leak every single time.**

## Acceptance goes into the doc the moment it happens

When the user says "confirmed" or "I can see it", whoever heard it writes it under the
design doc's `Accepted` section immediately.
**Conversations are lost; the repo is kept.** The next session sees only the repo.

**`3.done/` means "implementation finished", not "acceptance passed".**

**A verifier running in an isolated worktree cannot write docs** — its edits live only in the copy.
The spawner writes; the verifier only reports. Afterwards `git worktree remove --force` + `prune`
(automatic cleanup almost never fires — 700MB in one night, measured).

**A fresh worktree has no `.godot` import cache, and every net goes red for it** — not a code failure.
Four agents hit this the same night. Run the engine headless once in the new worktree first (any
`--headless --script` invocation re-imports) before trusting a red round to mean anything.
**A worktree also freezes at the commit it branched from** — two agents built a full session's worth of
work against a base that did not know the day's other changes had landed. Re-branch from `main` right
before starting, not from whatever commit happened to be current earlier.

**Skeleton first, flesh later.** Do not demand every `TBD` in a design doc be filled before implementing.

## Folders are contracts

| Folder | Contract | Base type |
|---|---|---|
| `src/sim/` | **Integer determinism.** No float · `Vector2` · `sqrt` · `sin` · `randi` · `OS.` · `Time.`. Knows nothing of the scene tree | `RefCounted` |
| `src/actor/` | float allowed. Still knows nothing of the scene tree | `RefCounted` |
| `src/view/` | Screen only. Reads the sim, never writes it | `Node` |
| `src/stage/` | Shell — tick loop · input · HUD · stage. Will not survive into the real game | `Node` |

`fire_cmd()` in `src/actor/aim.gd` is the single door into integer land.
Presentation constants live in `src/view/fx_tuning.gd`, sim constants in `src/sim/sim_tuning.gd`.
Nets scan the folders recursively — no hand-maintained registry.

## Comments

- **Write why doing it differently dies silently.** What the code does, the code says
- Keep measurements where they were taken
- If the same explanation appears in two files, move it to one
- Point at a doc; never summarize one
- **Name a doc; never path it, never line-number it.** The GDD's rule (`Name docs, don't path them` — a doc
  under `docs/plans/` changes folders with its status, so the path dies that day) extends one level down:
  **a line number is a path into a file.** Adding four lines to `town.md`'s header killed ten `town.md:NNN`
  citations at once, and the fix is to name the section, not to renumber — renumbering breaks again on the
  next edit above it. **This leak was found four separate times in one night, each time by someone other than
  whoever caused it**, including twice by the person who had just fixed the same thing elsewhere.
  ⇒ **`net_citations` greps `src/`, `tests/` and `tools/` for `docs/plans/[0-9]` and fails.** It exists and
  is committed — though this line briefly claimed it did **before** it was built, which is this file's own
  *"written down reads as exists"* failure committed inside the warning about it. Honour-based did not hold
  while it lasted: two citations stayed dead through *four* separate hand sweeps in one night, found only on
  the fifth. **`tools/` was outside its reach at first and widening it immediately found two more** — a scan
  scoped to where the bug was found is scoped too narrowly. Grep is the right instrument here because the rule being enforced is itself
  a text rule about comments, not a proxy for behaviour (contrast "a check that greps a file measures its
  text", below). **It must rejoin wrapped comment lines before matching, and confirm the cited name resolves
  to a real file.** A line-wise scan passed **three of eleven**, because the path wrapped across two `##`
  lines — coverage that looks like coverage and licenses everyone to stop sweeping

## No fake code

Code that pretends to work is worse than code that doesn't.

- Hardcoding for this input or this test only
- Returning a plausible value instead of computing one
- Reporting a stub as finished
- Swallowing an error so it looks like success
- **Screen changes but sim doesn't (or the reverse)** — the signature fake

If you can't do it, say you can't.

**One trap that raises nothing and is not about honesty at all**: a 60Hz event whose period shares a factor with
`TICK_DIVIDER` is **invisible to a 20Hz check.** A blocked pig's jump cycle is 27 frames, 27 is a multiple of 3,
so the single frame it touches ground lands on the same tick phase every time and the tick never sees it —
**the symptom is not a wrong value but a thing that never happens.** `_charge_blocked` · `_leaped_landed` ·
`_grounded_recently` are all the same passage: **latch the 60Hz fact, let the tick read and clear it.**
Three times now. Reach for that shape before writing a fourth.

**The fourth arrived, wearing the other face — the *check* was the victim, not the feature.** A check pumped
**one** `_physics_process` to observe something `_on_ticked()` drives, and **one physics frame crosses a tick
boundary at most one time in three — in that check's phase, none.** It passed while measuring nothing, and
the mutation it was written to catch stayed green at 437. `net_gate.gd:274` had already written the rule
down — *"pump well past one to be sure a tick actually ran"*. ⇒ **Observing anything tick-driven means
pumping `TICK_DIVIDER * 2`, never one frame.**

**The fifth was the most expensive, because it froze a tuning value nobody suspected.** `monster_bolts.
consume_hits` tests a bolt as a **point**, and it runs on the **tick** while the bolt moves on the **frame** —
so it samples one position in three. A player walking into a bolt closes ~9px per frame against a 20px-wide
box, and **a whole tick is 28px**: the two pass through each other with no sample in between.
**The symptom was not "a bolt missed".** It was that `character.MOVE_SPEED_PX` could not be changed —
260 hit, and **both 240 and 300 missed**, so a *slower* player dodged better than a faster one. That made the
uneven 5,4,4 gait (260 ÷ 60 = 4.333) unfixable, and the gait is where the screen shake the user kept
reporting comes from. **Two sessions read it as "too fast, it tunnels" and reverted the speed.**
⇒ **A hit test that runs on the tick must sweep the tick, not the frame** — and when a value "cannot be
changed without breaking something", suspect the sampling rate of whatever breaks.

## No fake nets

When the label claims more than the check measures, that green is a false guarantee.

**Invert every new check.** An uninverted check proves "it runs", not "it measures".
**If the inversion doesn't bite, suspect the check last — first confirm the mutation actually landed.**
String replacement has silently matched zero times, twice.

**A truncated search is not a search.** `grep ... | head` on a term with many hits **silently drops the one
that matters**, and an empty tail reads as an absence. That is how "there is no scan of this file" was
asserted confidently about a scan that exists — the noisy match filled the window and hid the quiet one.
⇒ **Count the hits before reading them**, and never conclude *absence* from a truncated result.

**Invert the instrument, not only the subject.** Twice in one night a check was written to catch a defect and
**shipped carrying that same defect**: a scanner for citations wrapped across comment lines joined only on
spaces, so the mid-token wrap — the shape it existed to find — stayed invisible, and every hand sweep that
night miscounted 56 as 53; and a dim-check folded body and outline alpha into one array, so deleting the body
dim outright stayed green because the outline's minimum held. **Neither was caught by inverting the code.
Both were caught by inverting the check.** ⇒ A new check needs a case that fails *it*, not only one that
fails what it points at.

Failure shapes are listed in `verify-read.md`. Only these three live here — **they survive
even after you confirm every mutation goes red**:

- **A check that reads only final state cannot measure an ordering contract.** Iteration order was reversed, final state was identical, three checks stayed green. Add a check that measures the process
- **A/B comparison catches "diverged", never "vanished".** Fold two paths into one and `scan == scan` — 39 checks all green. "Slower without it" is caught only by timing
- **A loop whose condition is false from the start never runs the check at all.** A settle loop passed with zero iterations. Assert the iteration count too
- **A check that greps a file measures its text, never what it computes.** Five scans shipped in one feature and
  **every one was evaded** — a decoy line, one added term (`PICK_RECT.position + Vector2(600,500)`), an `@export`
  moving the declaration off `^var`, the same write from another file, an early `return` between the two lines a
  scan compared. **Drive the value instead.** `_ready()` · `_gui_input()` · `_physics_process()` and ordinary
  methods are all callable on an **untreed node** with enough wiring — **and `_draw()` too**, once the runner
  pumps frames. **Nothing in this engine resists headless.**
  **"It can't be driven headless" has been claimed four times and was wrong four times.** The fourth cost the most:
  a settlement panel that **never set `visible`** shipped under 5,576 green checks, and the reason nobody caught it
  was that the same file had written down "no font outside the tree" as if it were a fact
- **"`_draw()` ran" is not "anything was drawn."** Counting the call — even through a `super()` that draws nothing —
  measures the engine, not the picture. Three separate features shipped this way in one day: an arch, a title,
  a whole magic circle, each erasable with 6,163 checks still green.
  **Godot refuses to override a native draw call** (`draw_texture_rect`, `draw_string`) — it is a parse error.
  ⇒ **Cut a `_paint(...)`-shaped hook out of `_draw()` and override that**, then assert the arguments.
  And drive it **treed with `pump_frames`** — calling `_draw()` by hand barks "drawing outside NOTIFICATION_DRAW".
- **Wiring a node by hand in the net hides the line that wires it in the shell.** `_wired_root` helpers pre-set
  `@onready` fields, so deleting the real `setup()` call in `stage.gd` stays green while the game shows nothing.
  **Null the field back out before calling `_ready()`**, or the shell's only wiring line is untested.
- **A check whose bounds come from the thing it checks proves nothing.** A wall test read `wall_cells()` and
  asserted inside it — shrink the rectangle and the test shrinks with it. **Pin literal coordinates.**
- **Measuring a pure function is not measuring that anything calls it.** `notice_rect()` was asserted to sit
  between the last row and the button; `_draw()` was then free to hand `_draw_notice` a bare `Rect2()` and
  **320 checks stayed green** — the end-of-content notice painting at zero size, invisible, in the one feature
  written to tell the player the build ends there. **Capture the argument at the hook and assert it equals what
  the pure function returns.** The builder had closed this exact hole for `gate_view` in the same feature and
  left it open one file over; a verifier who had not built it found it. **This is the case for the verifier
  never being the builder** — measured, not assumed.
- **A tuning constant with a floor on one end and none on the other is half-measured.** `GATE_TAKE_FRAMES`
  carried `>= 12`; its twin `GATE_ARCH_FADE_FRAMES` did not, so **2 through 11 were green** and the fade
  collapsed to a pop — the very thing the beat existed to remove. `= 1` bit only because integer division
  made the midpoint probe read `tint(0,0)`. **One bite does not prove the range.**

## Running the nets

1. **"N passed" is not green.** `load()` returns non-null on a parse failure, so the count holds even with `src/` broken. Only the final `[wrapper]` line decides.
   **A net that ran zero checks is now a failure** — the runner snapshots the counter around each net. It was added
   the day a missing `await` made a net **vanish with exit code 0** instead of going red
2. **If `[race]` prints, distrust the result — green included.** Running while someone edits reads half-written files
3. **Each net runs in its own process, in parallel.** Not for speed — for honesty: amnesty stays inside its own net. Do not break this property
4. **A round is ~28s and `net_gate` alone is 24.3s of it** — measured either side of `left-run-clumps-and-platforms`
   (29.8s round / 29.7s gate before, 24.4s / 24.3s after). **`net_gate` has been the long pole for some time and
   nobody noticed**, because this line said `net_water`. `net_water` is 14.4s and is **not a target** — its two
   slow checks (waking every cell, the design doc's 1,200-tick settle) were measured and kept on purpose.
   ⇒ **`net_gate` is `harness-manager`'s**, and so is converting it to a treed root (rejected in-feature because
   uncounted engine frames would break its exact-frame check — a harness job, not a feature's).
   ⇒ **Call `harness-manager` when a round grows for any other reason.** Slow means verification gets skipped,
   and then none of the above matters
5. **`_draw()` is measurable headless.** The runner pumps real frames (`t.pump_frames(n)` after `t.root.add_child`).
   "There is no font outside the tree" was **wrong twice over** — the default theme is there untreed too, and the
   only real cause was `_initialize()` quitting before a single frame. **Only pixel appearance is verify-look's.**

## Agent models

The caller decides `model`. A model pinned in the definition file wins (`harness-manager` = sonnet, the only one).

| Character | Model |
|---|---|
| Judgment changes the outcome — spec · verify-read · verify-look · design | opus |
| Executes a plan — builder | sonnet |
| Mechanical — reading values, finding files | haiku |

**Never lower verification to save money.** The signature failure is "pretends to run",
and verify-read · verify-look are what catch it.

## godot MCP

The bridge (`127.0.0.1:6550`) accepts one client. **`godot_*` is verify-look only.** Everything else is headless.
The server reconnects on its own even if no tool is called — resolve is not a mechanism. The fix is in `build-feature/SKILL.md`.

**Never take the user's mouse or keyboard.** No window focus, key injection, or OS screen capture.
The user is on the same machine.
**`godot_*` screenshots are the exception** — the editor captures its viewport directly and steals no input.

Check three things before launching:

1. Is the editor already up
2. The game window steals focus. If the user is working, ask
3. **Is there a path for the thing you want to see to reach the screen** — the most common miss.
   Water material and color were both in, but nothing called `set_water`, so not one cell appeared.
   If the path is missing, wire it into the stage first

**If you can't grab the bridge, stop and report.** Killing someone else's idle `godot-mcp` is not the answer —
it once killed this session's server too and the tools vanished entirely.
Without the bridge the game can `save_png()` itself. `--headless` cannot capture.
**Close any editor you launched when the session ends.**

### Closing the editor is not enough — `godot-mcp` (node) survives

**Agents do not launch that node.** Claude Code starts it automatically when a session opens,
and **it does not die when the session ends.** Measured: no editor running, **6 node processes** alive.

**The symptom is not "can't grab the bridge" — it is "the user can't see the screen".**
The moment an editor launches, all of them grab 6550, and the losers **retry forever**,
flooding the editor output panel with `Another client is already connected` until nothing else is readable.

**Count the competitors before launching verify-look:**
```powershell
Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'godot' }
```
**More than one: tell the user before launching the editor.** Finding out afterwards is finding out too late.

Killing them stays the user's call — it also cuts this session's server (`godot_*` disappears
entirely) and new nodes restart immediately (killed 6, 2 came back). **It does not get clean.**
