# tockbon

Loaded into every session and every agent. **Keep only what applies to everyone.**

## The old game was deleted on 2026-08-12. A new one started the same day and **its first loop is playable**

Eight months of side-view magic action plus a pixel water/fire simulation were thrown away in one decision.
**What survived is the harness that built it** — this file, `.claude/`, the net runner, `tools/pixel/`, the
Korean font — and on top of it now sits **`src/`, a working prototype of the cell game.**

**Read `docs/next-game.md` and the cell GDD before proposing anything.** They also record why the old game
died, so the same call is not re-litigated from scratch.
⚠ **And read `stages-and-evolution` in the same breath — it is newer than the GDD wherever they disagree.**
Two planning conversations on 2026-08-13 deleted card prices and species currencies, replaced tiers with
habitats, split force from disposition, and put swarm growth **on a key** (`F` splits everything in half,
`V` absorbs a radius) — **the level-up no longer grows the swarm at all.**

⇒ **A third one on 2026-08-14 turned that into something buildable, and changed six things doing it.**
The body is **eleven slots**, not ten (breath got its own). **`1` gathers at the host** and **`3` sends the
swarm at the mouse point**. **All three keys — left click included — are empty squares the player binds an
active into**; there is no fixed basic attack. **A kill leaves a corpse and eating it takes time**, standing
still, interruptible. The August scope is **one stage, two species (crow · horse), one boss, three parts**.
**And the word "apex" is dead — say boss**; it did not survive contact with the user.
⇒ **`grassland-whole-loop` is now an index over four plans built in order** — the run shell, hands and
commands, the body and its parts, the grassland field. **Godot was re-examined the same day and stands.**

⇒ **Four adversarial reviews then found sixty-odd problems in those plans, and the pattern is worth keeping:
the plans were dense and their JOINTS were empty.** A deletion counted in one file that lived in four · a
net that vanishes instead of going red when a file stops parsing · a new column on a flat table with no
matching line in `setup`, `add_clone` and the hand-written swap · a value that reads as derived making the
mechanic it belongs to free · a check that measures a table's shape rather than a behaviour.
**Six more answers came out of it**: an active's reach is written on the part · the host's parts come from
cards only · a corpse pays its own force in cells · **nothing gates the boss** (damage is the attacker's
force both ways) · **the run opens alone** (`START_CLONES` 0) · **the camera pulls back as the swarm grows**,
which is the answer to the field feeling small. **The prototype in `src/` is a reference, not a base** — the
user's call is to write it again properly.

⇒ **A second, larger review the same day found 74 more, and the four plans are NOT corrected for it.**
Five independent reviewers; **the ranking that mattered was how many of them found the same thing alone.**
**Plan 4 is NOT BUILDABLE** — the field's composition and the rule for what an attack hits are both absent.
Read **`adversarial-review-2026-08-14-ko`** before building any plan. Its three loudest: `cells_eaten` is
double-counted and two of its own nets contradict each other · nothing rebinds the view after `restart()` ·
`EAT_RADIUS` names a constant that does not exist, which is **the bug the user caught on the first play**.

⇒ **Then the design moved again, and it moved the numbers.** **`docs/design/hunting-and-the-boss-ko.md` is
newer than the GDD, than `stages-and-evolution`, and than all four plans.** The host opens at **force 10**
so splitting is the tutorial, and **every monster went ×10** with it (crow 10 · horse 30–40 · boss 120).
**Size comes from the species**, force adds at most 1.5× — a strong crow is never a horse. **Say 경험치, not
cells.** The three species are three different hands: **the crow stands still and counters** (walk up and
hit it), **the horse out-runs even the swarm and is HERDED** into clones, rocks or the edge, and **the boss
cannot be escaped** — it comes to you, closes an arena, and the scattered swarm is summoned into it.
**Clones attack on contact**, so a swarm spread wide pays for it. **Rocks and water both ship and nothing
was deferred** — the user was offered the cut twice and refused; the schedule takes it instead.

**What runs**: one host you drive, a swarm that scatters and rallies, clones that carry what they ate until
they touch you, an ecosystem of critters that chase or flee depending on how big the swarm has got, and a
level-up card pick. **What does not**: parts, slots, traits, chimeras, habitats, meta.
**Species currencies and tiers are not merely unbuilt — they were cut from the design.**

⇒ **The user played it and confirmed the fun.** Read the acceptance section of `proto-round-trip` before
designing anything on top of it. **Four things that three rounds of adversarial
verification and 102 green checks did not catch were found in five minutes of play**: a swarm that started
at zero, an eat radius smaller than the body, a Control laid out from a zero size, and a threat model that
was simply the wrong design. **Play is an instrument the harness does not contain.**

⚠ **The direction changed five times on 2026-08-12 alone**, and the magic circle was dropped at the end of
it. **`docs/planning-principles-ko.md` is what came out of that day** — eight one-line judgments that hold
whatever the game turns out to be. **Open it before any planning conversation.** The first of them:
**the hands must never be idle**; the second: **planning cannot decide whether something is fun.**

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

⚠ **The submission itself is safe from anything done locally.** What the judges see is `origin/main` and
`gh-pages`, and neither moves while the freeze holds — the local `README.md` and `docs/` have already been
rewritten past them, and that only reaches the remote after 2026-08-22.
**`docs/archive/` was deleted locally on 2026-08-12**; the submission files still sit on `origin/main` under
their original name (`docs/submission/`), and the sources are also at the tag `v1-sim`.

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

#### The exception has a ceiling — **10 lines** (decided by the user)

It buys an answer, not an essay. A design conversation ran five rounds where **every reply was a list of
options plus reasoning plus a recommendation plus the next question**, and the user stopped the conversation
to say the brevity rule had apparently been deleted. **It had not — the exception was being read as a
licence.**

- **One axis per reply.** Not the axis and its consequence and the axis after that
- **Options are one line each.** The reason goes on the same line or is cut
- **One line of recommendation.** Not three reasons for it
- **The next question is one line, at the end** — or it waits for the next reply
- **Do not restate what the user just said back to them.** They know what they said

**Rule of thumb: if the reply has more than one bold heading's worth of thought in it, it is two replies.**

### And **do not close a conversation the user is still having**

Ending three replies in a row with "shall I start?" reads as being shut down, and it was — **the user said so
in those words.** A design conversation is not a task waiting for a green light. **Answer, add what the answer
opens up, and stop** — the user will say when they are done thinking.

## Where things live

| Doc | Question it answers |
|---|---|
| `docs/next-game.md` | **What is being built now, and why the last one was thrown away** |
| `docs/planning-principles-ko.md` | **How to judge a direction.** Survives every direction change — read it first |
| `docs/design/` | **What a feature looks like.** Read its README first — the newest doc wins where they disagree |
| `docs/decisions/` | **Why something was *not* done.** The rejected branch and the reason, nothing else |
| `docs/plans/` `1.ready` `2.active` `3.done` | **The only folder that moves.** The folder a doc sits in is its status |
| `docs/adversarial-review-2026-08-14-ko.md` | **What is wrong with the four plans**, from five independent reviewers. **Read it before building any of them** |

**All three exist and hold ~50 docs.** `docs/archive/` does **not** exist — it was deleted on 2026-08-12,
and this table claimed the opposite of the truth on both counts for two days. **A concept never changes
folder**; its header carries `Implemented` and `Accepted` as two separate axes.

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

## Folders are contracts

| Path | The rule it obeys |
|---|---|
| `src/sim/` | **Never touches the tree.** No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`. Every file here is constructible and drivable by a net with `.new()` and nothing else |
| `src/view/` | **Reads `sim`, never writes it.** Everything that is a Node or draws lives here, and **each drawing file exposes a hook** (`_paint_cell`, `_paint_text`) so a net can assert the arguments |
| `src/shell/` | **The only place that reads `Input`**, and the only place that wires `sim` to `view`. It builds its children in code, so a net calling `_ready()` exercises the real wiring |
| `src/look.gd` | **Every presentation constant, in exactly one file.** `src/sim/rules.gd` holds every constant that changes what happens |

**The scan that enforces this is not written yet** — with a handful of files it would be a check that
cannot fail. Write it when a folder has enough in it to drift: grep `src/sim/` for `extends Node` · `_draw`
· `Input.` · `get_node` · `$`, grep `src/view/` for writes to `sim.`, grep outside `look.gd` for colour and
pixel literals.

**The one-file rule for presentation constants is inherited and was measured**: scattering them meant the
power doubled and **zero things changed on screen**, because the numbers that would have shown it were in
six places and only one moved.

**The flat-array swarm is a correctness contract, not a performance one.** 300 `Node2D`s cost 0.065ms here
— the engine was never the wall. `carried[i]` living in a `PackedFloat32Array` is what makes "a clone
killed far from home loses its cargo" **structurally true**, with no code that has to remember to drop it.

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

**`net_citations` is rebuilt and running.** It joins wrapped comment lines **two ways** — space-joined and
tight-joined — because a space-join alone cannot see a mid-token wrap, which is the shape it exists to
find, and it carries two synthetic cases that fail the scanner itself rather than the tree.

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
- **`visible` is not "on screen", and neither is being wired.** `set_anchors_preset` sets anchors and
  **leaves the offsets alone**, so a `Control` added to a bare `CanvasLayer` keeps `size == (0, 0)` — and
  a panel that lays itself out from `size` then piles into the top-left corner while every check about it
  passes. Assert the size against the viewport and assert the laid-out rectangles land inside it
- **A tuning constant with a floor on one end and none on the other is half-measured.** One frame-count
  constant carried `>= 12`; its twin did not, so **2 through 11 were green** and the fade collapsed to a pop —
  the very thing the beat existed to remove. **One bite does not prove the range**

## Running the nets

**Ten nets, 111 checks, about one second.** A net is `tests/nets/net_*.gd` with one method, `func run(t)`,
and `t` gives you `ok` · `eq` · `pump_frames` · `expect_error` · `root`. **The wrapper reds below five
nets** — that is the scan-broken detector, so nets land in groups, never one at a time.

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
  presets can never be made to match, however the prompt is tuned.
  ⚠ **This is the constraint the cell game escaped, and it is worth knowing how**: a part is worn **in the
  host's own colour**, so there is only ever one tone and nothing has to match. **It bought back the cap on
  how many species a habitat can have** — see [the body is a line](docs/decisions/the-body-is-a-line-drawn-by-code.md).
  The rule still binds anything that keeps its own colours

**And three things measured on 2026-08-13, generating for the cell game:**

- **Naming an animal overrides the view.** Six species asked for top-down came out in front view. Forcing
  the view back made the animal leave — a top-down lion is an orange square, because **a mane is surface and
  surface does not show from above.** ⇒ On a top-down body, **only what sticks out reads**
- **A part generates well only if it survives being cut off a body.** Jaws do. **A leg does not** — detached
  it is a brown stick
- **Do not generate what is a shape.** An outline, a dot and a limb are a radius, a thickness and a length;
  code draws them, squash and stretch are free on numbers and destructive on pixels
