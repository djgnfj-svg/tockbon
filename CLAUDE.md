# tockbon

Loaded into every session and every agent. **Keep only what applies to everyone.**

## The game was deleted on 2026-08-12. This repo is a harness with no game in it yet

**`src/` does not exist.** Eight months of side-view magic action plus a pixel water/fire simulation were
thrown away in one decision, and **what is left is the harness that built it** — this file, `.claude/`,
the net runner, `tools/pixel/`, and the Korean font.

**The new direction is in `docs/next-game.md`** — top-down magic-circle core defense, shipping December 2026.
**Read it before proposing anything.** It also records why the old game died, so the same call is not
re-litigated from scratch.

**Everything the old game measured is recoverable at the tag `v1-sim`.** Nothing was lost, only unloaded.
**Do not restore code from it** — it was written against constraints (integer determinism, a 20Hz sim tick)
that no longer apply and would quietly re-import the whole cost.

⇒ **Rules below that need a game to be true have been removed rather than kept as fiction.** Folder
contracts, tick-rate traps and simulation budgets all go back in **when the new game has folders and a
tick**, written from what is then measured — not copied from a game that no longer exists.

## No `git push` until 2026-08-22 (decided by the user)

Local commits keep piling up as normal — only the remote is frozen. `gh-pages` redeploy counts as a push.
The NAN 2026 submission links must stay exactly as judged. **`wrap-up` stops at the commit.**
Delete this section once the date passes.

⚠ **`README.md` still describes the deleted game**, and that is deliberate — it is what the judges saw.
Rewrite it only after the freeze lifts.

## Language — answer the user in Korean, always

**Every reply to the user is in 한국어.** Even when they write in English — they cannot read English.

Docs, comments and prompts are English. **Korean is what the user reads**: their own commands,
commit messages, in-game text, **net check labels** and the net runner's console output.

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

### And **do not close a conversation the user is still having**

Ending three replies in a row with "shall I start?" reads as being shut down, and it was — **the user said so
in those words.** A design conversation is not a task waiting for a green light. **Answer, add what the answer
opens up, and stop** — the user will say when they are done thinking.

## Where things live

| Doc | Question it answers |
|---|---|
| `docs/next-game.md` | **What is being built now, and why the last one was thrown away** |
| `docs/archive/` | **Closed work. Don't read it, don't update it** — nothing there is true about today |

`design/`, `decisions/` and `plans/` **do not exist yet.** They come back with the first feature.
The structure they had, which is worth restoring unchanged:

- `design/` — what a feature looks like. **A concept never changes folder**; its header carries
  `Implemented` and `Accepted` as two separate axes
- `decisions/` — **why something was *not* done.** The rejected branch and the reason, nothing else
- `plans/` `1.ready` `2.active` `3.done` — **the only folder that moves.** The folder a doc sits in is its status

**Never state the same thing twice.** A value counted in two places will diverge.

**A refutation that lands in a different doc than the claim does not propagate.** One doc said a wide bowl of
water never settles; another had **already measured it settling** and wrote the correction **in its own file.**
The first was never fixed, its stronger reading was inherited, and a whole stage's cost model was built on it.
⇒ **When a measurement refutes another doc, go and edit that doc.** Recording the refutation where you happen
to be standing is how the same wrong number gets inherited twice.

**And a correction pass only checks the row that makes a claim.** The same table held two rotted numbers: the
loud one was re-measured, and the quiet one beside it — off by a factor of twenty-four — was waved through
with a correction box explicitly blessing it. It survived **because it was not making a dramatic claim.**
⇒ **Re-measure the whole table, not the row someone is arguing about.**

**When a fork is taken, record the rejected branch in `docs/decisions/`** — what was dropped and why, nothing
else. **This matters more than it looks**: laying out options and letting the user pick means two or three
unpicked options appear every round, and the design doc records only the picked one. Months later the same
options get laid out from scratch. The user lived this with inventory, and again with the whole game.

**When a feature comes up in conversation, create a `docs/design/` doc and add one row to its README.**
Head the doc with two lines, `Implemented` and `Accepted` — without them, "written down" reads as "exists".

**Moving a `plans/` doc means three edits**: fix the `**Status**:` line inside it (there is exactly one),
fix every link pointing at it, and report all three folders as a table. **Links leak every single time.**

## Acceptance goes into the doc the moment it happens

When the user says "confirmed" or "I can see it", whoever heard it writes it under the
design doc's `Accepted` section immediately.
**Conversations are lost; the repo is kept.** The next session sees only the repo.

**`3.done/` means "implementation finished", not "acceptance passed".**

⚠ **And acceptance does not close by inference.** A build existing, a video existing, an agent having walked
through it — **none of those is the user saying it read right.** A paragraph once claimed a milestone was met
on the strength of a play video existing; that is reasoning backwards from an artifact, and it is how a doc
starts lying. **Acceptance is written down when it is heard.**

**This is the failure that killed the last game.** Thirty-four features shipped, five acceptance checks left
open, and **the user reported that no moment in eight months was fun.** Nobody had ever run the loop end to
end. ⇒ **A feature nobody has looked at is not progress**, and a pile of them is not a game.

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

## Folders are contracts — **and the new game has none yet**

The deleted game split `src/` into four folders with enforced rules, and a net scanned them recursively.
**That device worked and is worth rebuilding** — but its contents were specific to a deterministic
simulation, so **copying them forward would import constraints the new game does not have.**

⇒ **When the new game's first folders appear, write their contract here and build the scan that enforces
it.** Until then this section is deliberately empty.

**One rule from the old set survives on its own merit**: presentation constants live in exactly one file.
Scattering them was measured — the power doubled and **zero things changed on screen**, because the numbers
that would have shown it were in six places and only one moved.

## Comments

- **Write why doing it differently dies silently.** What the code does, the code says
- Keep measurements where they were taken
- If the same explanation appears in two files, move it to one
- Point at a doc; never summarize one
- **Name a doc; never path it, never line-number it.** A doc under `docs/plans/` changes folders with its
  status, so the path dies that day — and **a line number is a path into a file.** Adding four lines to one
  doc's header killed ten citations at once; the fix is to name the section, not to renumber, since
  renumbering breaks again on the next edit above it. **This leak was found four separate times in one
  night, each time by someone other than whoever caused it**, including twice by the person who had just
  fixed the same thing elsewhere.
  ⇒ **`net_citations` greps `src/`, `tests/` and `tools/` and fails on both forms.** Honour-based did not
  hold while it lasted: two citations stayed dead through *four* separate hand sweeps in one night, found
  only on the fifth. **`tools/` was outside its reach at first and widening it immediately found two more** —
  a scan scoped to where the bug was found is scoped too narrowly. **It must rejoin wrapped comment lines
  before matching**: a line-wise scan passed **three of eleven**, because the path wrapped across two `##`
  lines — coverage that looks like coverage and licenses everyone to stop sweeping
- **The line-number half was honour-based for weeks longer, and it rotted the whole time.** Seventeen
  `name.gd:NNN` citations existed and **six were already dead**, pointing at unrelated statements while
  reading as precise — **one of the six was cited by the rule forbidding the shape.** The moment the net
  covered it, it found **five more that the hand sweep had just missed.** Name the symbol: a function or
  constant name survives edits above it

**`net_citations` was deleted with the rest of the nets. It is the first one worth rebuilding** — it needs
no game, only text.

## No fake code

Code that pretends to work is worse than code that doesn't.

- Hardcoding for this input or this test only
- Returning a plausible value instead of computing one
- Reporting a stub as finished
- Swallowing an error so it looks like success
- **Screen changes but sim doesn't (or the reverse)** — the signature fake

If you can't do it, say you can't.

**And one whole class of it was structural, not dishonest.** The deleted game ran three clocks (render,
60Hz physics, a 20Hz simulation tick) and **five separate defects came out of the seam between them** — a
60Hz event whose period shared a factor with the divider was invisible to the tick; a check that pumped one
physics frame measured nothing at all; a hit test sampling one position in three let a player and a
projectile pass through each other, which read as "this tuning value cannot be changed" for two sessions.

⇒ **If the new game ever runs a fixed timestep under its render loop, read this paragraph again and write
the traps down as they are measured.** They are not in the general case — they are what happens when two
clocks meet, and they cost more than anything else in that codebase.

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
spaces, so the mid-token wrap — the shape it existed to find — stayed invisible; and a dim-check folded two
alphas into one array, so deleting one outright stayed green because the other's minimum held. **Neither was
caught by inverting the code. Both were caught by inverting the check.** ⇒ A new check needs a case that
fails *it*, not only one that fails what it points at.

These survive **even after you confirm every mutation goes red**:

- **A check that reads only final state cannot measure an ordering contract.** Iteration order was reversed,
  final state was identical, three checks stayed green. Add a check that measures the process
- **A/B comparison catches "diverged", never "vanished".** Fold two paths into one and `scan == scan` — 39
  checks all green. "Slower without it" is caught only by timing
- **A loop whose condition is false from the start never runs the check at all.** A settle loop passed with
  zero iterations. Assert the iteration count too
- **A check that greps a file measures its text, never what it computes.** Five scans shipped in one feature
  and **every one was evaded** — a decoy line, one added term, an `@export` moving the declaration off
  `^var`, the same write from another file, an early `return` between the two lines a scan compared.
  **Drive the value instead.** `_ready()` · `_gui_input()` · `_physics_process()` and ordinary methods are
  all callable on an **untreed node** with enough wiring — **and `_draw()` too**, once the runner pumps
  frames. **Nothing in this engine resists headless.**
  **"It can't be driven headless" has been claimed four times and was wrong four times.** The fourth cost
  the most: a panel that **never set `visible`** shipped under 5,576 green checks, because the same file had
  written down "no font outside the tree" as if it were a fact
- **"`_draw()` ran" is not "anything was drawn."** Counting the call — even through a `super()` that draws
  nothing — measures the engine, not the picture. Three separate features shipped this way in one day, each
  erasable with 6,163 checks still green. **Godot refuses to override a native draw call**
  (`draw_texture_rect`, `draw_string`) — it is a parse error. ⇒ **Cut a `_paint(...)`-shaped hook out of
  `_draw()` and override that**, then assert the arguments. And drive it **treed with `pump_frames`** —
  calling `_draw()` by hand barks "drawing outside NOTIFICATION_DRAW"
- **Wiring a node by hand in the net hides the line that wires it in the shell.** Helpers that pre-set
  `@onready` fields let you delete the real `setup()` call and stay green while the game shows nothing.
  **Null the field back out before calling `_ready()`**
- **A check whose bounds come from the thing it checks proves nothing.** A wall test read the wall's own
  extent and asserted inside it — shrink the rectangle and the test shrinks with it. **Pin literal
  coordinates**
- **Measuring a pure function is not measuring that anything calls it.** A rect function was asserted
  correct; `_draw()` was then free to pass a bare `Rect2()` and **320 checks stayed green** — the notice
  painting at zero size, invisible. **Capture the argument at the hook and assert it equals what the pure
  function returns.** The builder had closed this exact hole one file over and left it open here; a verifier
  who had not built it found it. **This is the case for the verifier never being the builder** — measured,
  not assumed
- **A tuning constant with a floor on one end and none on the other is half-measured.** One frame-count
  constant carried `>= 12`; its twin did not, so **2 through 11 were green** and the fade collapsed to a pop —
  the very thing the beat existed to remove. **One bite does not prove the range**

## Running the nets

**There are no nets right now.** `tests/nets/` was deleted with the game; `tests/run_nets.gd` and
`run_nets.ps1` survive and work as-is. The rules below are the runner's, not any net's.

1. **"N passed" is not green.** `load()` returns non-null on a parse failure, so the count holds even with
   `src/` broken. Only the final `[wrapper]` line decides.
   **A net that ran zero checks is a failure** — the runner snapshots the counter around each net. It was
   added the day a missing `await` made a net **vanish with exit code 0** instead of going red
2. **If `[race]` prints, distrust the result — green included.** Running while someone edits reads
   half-written files
3. **Each net runs in its own process, in parallel.** Not for speed — for honesty: amnesty stays inside its
   own net. Do not break this property
4. **Call `harness-manager` when a round grows.** The old game's round was ~28s and **one net was 24.3s of
   it, unnoticed for weeks** because this line named the wrong net. Slow means verification gets skipped,
   and then none of the above matters
5. **`_draw()` is measurable headless.** The runner pumps real frames (`t.pump_frames(n)` after
   `t.root.add_child`). "There is no font outside the tree" was **wrong twice over** — the default theme is
   there untreed too, and the only real cause was `_initialize()` quitting before a single frame.
   **Only pixel appearance is verify-look's.**

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
The server reconnects on its own even if no tool is called — resolve is not a mechanism.

**Never take the user's mouse or keyboard.** No window focus, key injection, or OS screen capture.
The user is on the same machine.
**`godot_*` screenshots are the exception** — the editor captures its viewport directly and steals no input.

Check three things before launching:

1. Is the editor already up
2. The game window steals focus. If the user is working, ask
3. **Is there a path for the thing you want to see to reach the screen** — the most common miss.
   Water material and colour were both in, but nothing called `set_water`, so not one cell appeared.
   If the path is missing, wire it into the shell first

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

## Art is generated locally and picked by eye

`tools/pixel/` runs a local ComfyUI (FLUX.2 klein) — **no credits, 6-25 seconds an image.** It survived the
reset because it is the one asset from the old project that knows nothing about the game.

**The user decides art by looking at real candidates, never by discussion.** Every settled art decision in
the old project came from generating a board and pointing at one. **Paid generation only when the user asks
for it.**

Two things it measured that outlive the old game:

- **Generate at the size you will use.** Upscaling cannot invent pixels; a ring made at 448 and stretched to
  896 was judged "low pixel", and generating at 896 directly fixed it
- **Texture comes from the preset, not the seed.** Six seeds on one preset gave six compositions with
  identical texture; five prompts on one seed gave five pictures that matched. Parts drawn from *different*
  presets can never be made to match, however the prompt is tuned
