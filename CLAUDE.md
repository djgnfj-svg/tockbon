# tockbon

Loaded into every session and every agent. **Keep only what applies to everyone.**

## The game has been reset twice. The current one is a **cell autobattler**, and it now runs

The first — eight months of side-view magic action and a pixel water/fire simulation — was deleted on
2026-08-12, tag `v1-sim`. The second — an **open-field cell game**, one host you drive and a swarm that
scatters, five plans over four days — was deleted on **2026-08-16**, tag `v2-openfield`.
**Both times the harness survived**: this file, `.claude/`, the net runner, `tools/pixel/`, the Korean
font, and `docs/`. **The third game was built on top of that on 2026-08-17 and it plays** — see
「The state of the tree」 below.

**Read `cell-army-gdd-ko` before proposing anything** (English twin: `cell-army-gdd`). Its one line is
**「먹을 것을 고르러 간다」** — an **autobattler**: a node map of islands (상자 · 전투 · 엘리트 · 보스, and
**only 상자 has no fight**), a squad of square cells landed **by boat on the coastline**, and **the island's
특산물 bolted onto the soldiers that survived it.**
**There is no host.** `F` and `V` are gone. Soldiers carry across islands, **HP included**, and **a dead one
is dead for good.** Combat is real time, summoned with the **1~5 hotkeys**; the loss condition is a
**time limit**. The two reference points are pinned in that doc and **the user asked that they never be
dropped**: **Bad North** (2 people, ~790k copies) and **Despot's Game** (100k+, units not controlled at all).
**They answered the same question in opposite directions and both worked** — that is why both are there.
⚠ **Bad North is NOT "place and watch"** — the developer says he lowered the *granularity* of control, not
removed it. Never cite it as grounds for this game having none.

### Why the second game died — **one sentence, and it is the most reusable thing here**

The user played it: *"그냥 재미가 없다… 왜 이 지랄 하는지 모르겠다."*
The diagnosis inverted: not *"the swarm has no merit"* but **"the swarm has no cost."** Splitting conserved
force, HP **and** damage while a damage cap meant a body died in three hits whatever its size — so splitting
multiplied the hits an enemy needed, and absorbing undid it for free.

⇒ **An advantage with no cost is not a decision, and a mechanic that is not a decision is not fun.**
The optimal play was "split to the cap and stay bunched" — learnable once, and then over.

**This test has already caught three more designs in this repo since**, each time by working the arithmetic
rather than arguing: the whole record is in **`lessons-from-two-dead-games`** (Korean: `-ko`).
⚠ **Nothing in that file is a spec.** It holds measured numbers and repeating failure shapes only.

⚠ **The conversation circled six times and the reason is worth keeping.** The problem was one sentence
(*"분신이 왜 있는지 모르겠다"*) and **every answer offered was a new system** — 병종, 부대 지정, 합체,
DB화 — each of which introduced its own unknowns, so nothing ever closed. ⇒ **When a complaint is one
sentence, first ask whether a rule can answer it. A new system cannot be evaluated, only accumulated.**
And underneath it: **there was no reference point.** Balatro's LocalThunk had never played a deckbuilder
but he had *Luck Be a Landlord*. **Without one game to point at, every question is answered by inventing.**

### Three measurement lessons that outlive both games

- **A constant is not what reaches the screen.** A body radius of 8 was cited in chat as "8px", and the
  truth was **38px** — 8 is a *radius*, the camera multiplied by 1.6, and a 1280 viewport was stretched into
  a 1920 window for another 1.5×. **A design argument was built on a number off by 4.8×**, and the same
  shape bit **four separate times**
- **A design complaint can become a number, and that is the instrument to reach for when the answer is
  "it isn't fun".** *"도저히 진행이 안 돼"* became **83% dead air, 150s between kills** by writing a bot that
  played a whole run headless. **The probe is deleted with the game; the move is not**
- ⚠ **And that probe graded itself in its owner's favour twice** — it modelled one-shot as `force >= hp`
  after a cap made that false, and never read the flee table. **A probe that grades its own step must be
  inverted like any other check**

### Play is an instrument the harness does not contain

The last game shipped 34 features with 5 acceptance checks open and **no moment in eight months was fun**.
This one shipped 25 nets and 3541 green checks and **the user could not play it**. Four things three
rounds of adversarial verification missed were found in five minutes of play, twice over.
⇒ **`docs/planning-principles-ko.md` is the only file that survived both resets on purpose.** Its second
line — **planning cannot decide whether something is fun** — is why this section exists.

### ⇒ **A feature is not done until its presentation is done** (decided by the user, 2026-08-17)

**This is now the default for every feature, and it came from the user in as many words** after they played
the first slice: *"원거리가 뭔가에 쏘는 연출 이런 게 다 필요할 거 같아. 지금은 너무 연출적으로 없어서"* ·
*"액션을 보는 맛이 있어야 돼. 패끼리 싸우는 맛"* — and then, once it was in:
**"이번 것처럼 무조건 연출까지 개발하는 게 기본임."**

⇒ **A plan that ships rules and leaves the picture for later is an incomplete plan.** The first slice was
built that way and the user could see the game but not *feel* it; twelve presentation items went in as a
second pass that should have been part of the first.
⇒ **So: when a feature is planned, its presentation is planned with it, in the same doc, and it ships in the
same round.** "It works, the picture comes later" is not a milestone.

⚠ **This is not a licence to gold-plate.** What it means is narrow and measurable: **every rule that changes
state has something on screen that says it happened.** The old game died partly because *"화면에 줄어드는
양이 하나도 없었다"* — the only evidence anything was being hit was that things eventually died.

⚠ **And presentation is where green rounds lie most easily.** `_draw()` running is not anything being
drawn; a hook spy never sees the native call inside the hook; capturing an argument proves it was computed,
never that it was used. **See「No fake nets」— those entries were all earned here.**

### The state of the tree, right now

- **`src/` is built and the game runs end to end.** `run/main_scene` is `src/shell/game.tscn`.
  `src/sim/` (rules · grid · islands · army · battle · run) · `src/view/` (field · hud · panel) ·
  `src/shell/game.gd` · `src/look.gd` · `tools/probe/run_run.gd`
- **The round is green: 9 nets, 725 checks, 2.2s.** `net_battle` `net_boat` `net_islands` `net_run`
  `net_shell` `net_draw_leaf` `net_fx` `net_fx_view` `net_citations`
- **A run plays**: three islands, boat landings, the beak reward, the lion, restart. **And the twelve
  presentation items are in** — see `combat-juice-ko.md`
- `tools/look/` — only its `README.md`. Both probes and all three capture scripts drove the deleted shell.
  ⚠ **Screenshots are not automated right now**; the game is launched and the user looks
- `docs/` — **60-odd docs were deleted on 2026-08-17** because they described the two dead games and a fresh
  session reads them as constraints. **What they measured was distilled into `lessons-from-two-dead-games`
  first.** What is left is small on purpose, and every index lists exactly what is live
- **Everything measured in either dead game is recoverable at `v1-sim` and `v2-openfield`.**
  **Do not restore code OR docs from either.** `v1-sim` was written against integer determinism and a 20Hz
  tick; `v2-openfield` was written against a host, an open field and a swarm you steer. Both would quietly
  re-import a whole set of constraints the current design does not have

### What the user said after playing it — **the open problem going into the next session**

**The presentation passed**: *"연출은 좋아."*
**The game did not**: *"게임이 좀 애매하네. 뭔가 침공하는 느낌이 전혀 없어서. 2D라서 그런 건지 너무
단순한 느낌이야. 사실 전투는 2D나 3D나 똑같을 건데 말이지."*
And, for the second time: *"그냥 배가 곁다리인 게 여전히 별로네."*

⚠ **Read the second sentence carefully — the user answered their own 3D question inside it.**
*"전투는 2D나 3D나 똑같을 건데"* ⇒ **the missing feeling is not a dimension problem.** It is that
**「침공」— invading — does not read**, and the boat is the part that was supposed to carry it.
⇒ **Next session's problem is the boat**, and the user said so: *"이걸 다음 세션에서 잡는 걸로."*
The GDD carries it as Undecided 15 · 16 · 17.

### Korean and English are two files, and they diverge if edited apart

**The user cannot read English; agents read English better.** So the live design docs exist twice —
`foo-ko.md` and `foo.md`, same facts, neither a word-for-word translation of the other.
⚠ **Editing one and not the other is the failure mode.** A fact changed in Korean and not in English means
the next agent builds the old design. **Change both in the same edit**, the way a `push_error` and its
`t.expect_error` are one unit.

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

### A recommendation without a source is not a recommendation (decided by the user)

**The user is new to making games and said so in as many words**: *"I have no data, so whatever you say
feels like it must be right."* That is not agreement — **it is the absence of anything to disagree with**,
and a recommendation that wins that way has not been chosen, only accepted.

- **When you recommend a way of working, name who actually works that way.** Studios, games, people —
  **several, disagreeing with each other**, so there is a spread to pick from. The user picks; you do not
  get approval
- **The source has to be checkable** — a link, or a document with an author and a date. *"Usually in the
  industry…"* is not a source, and neither is this file
- **Look it up rather than remembering it.** A studio named from memory that turns out wrong is worse than
  no example at all, because it cannot be checked and it will be repeated
- **Give the case against your own recommendation too.** Every method has a study or a postmortem arguing
  the other way; leaving it out turns a choice into a pitch
- **This binds technical choices as well** — engines, libraries, tooling, verification. Not just design

⇒ The first one written this way is [how studios schedule art](docs/how-studios-schedule-art-ko.md) —
Valve · Nintendo · Cuphead · Vampire Survivors · Balatro · Unity's own playtest research, **and the answer
turned out to be neither of the two options that had been on the table.** That is what the sources bought.

## Where things live

**`docs/` is small on purpose. This table is the whole of it** — if a file is not listed here or in one of
the three README indexes, it does not exist.

| Doc | Question it answers |
|---|---|
| `cell-army-gdd` · `-ko` | **The GDD. What is being built.** One line, three loops, what is decided, what is not, and the two reference games. ⚠ **It carries several refutation boxes where an earlier claim in the same file is disproved by arithmetic** — those are the most valuable paragraphs in it |
| `what-makes-placement-a-decision` · `-ko` | **Nine shipped games and the rule each used to make position a real choice**, split by whether they need unit control after commitment. With the case against each |
| `lessons-from-two-dead-games` · `-ko` | **What two deleted games measured.** Numbers and repeating failure shapes. ⚠ **Nothing in it is a spec** |
| `docs/planning-principles-ko.md` | **How to judge a direction.** Survived both resets on purpose — read it first |
| `docs/decisions/` | **Why something was *not* done.** Three docs; **two are reversed and kept for that reason** |
| `combat-juice` · `-ko` | **The twelve presentation items, built and accepted.** How a sim event reaches the view without `sim` growing a clock, the full closed hook table, every `look.gd` constant, and what has to break for each net to redden |
| `docs/plans/` `1.ready` `2.active` `3.done` | **The only folder that moves.** `1.ready` and `2.active` are empty; `3.done` holds `first-slice` |
| `docs/harness-todo-ko.md` | **Work on the tools, not the game.** Top item is the user's: **parallelise the build** |
| `docs/how-studios-schedule-art-ko.md` | **When other studios attach the art**, with sources. Written because the user has no data of their own and said so — see the reply rule about recommendations |
| `docs/gdd-audit-ko.md` | **A six-axis audit of the GDD and the slice plan**, run before the build. ⚠ **Its last section lists the findings that were refuted** — read that before re-raising any of them. Korean only |
| `first-slice` (`3.done`) | **How the game was built.** Three islands, one run, end to end — files, numbers, island grids, nets, acceptance. Carries its own adversarial-review section. ⚠ **Its section 6 hook table is superseded** by `combat-juice` |
| `docs/next-game.md` | The two resets, what carried across, and why nothing is restored from a tag |

**A concept never changes folder**; its header carries `Implemented` and `Accepted` as two separate axes.
`docs/archive/` does **not** exist and must not be recreated — **a doc about a dead game gets distilled and
deleted, not archived in place.** Archiving in place is what produced 60 stale docs by 2026-08-17.

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
Four agents hit this the same night. Run `--headless --path <root> --import` in the new worktree first,
before trusting a red round to mean anything.
⚠ **`--headless --script` does NOT re-import, and this file said it did for two days.** Measured twice on
4.7.1: a brand-new `class_name` file is **invisible** to `--script` until an explicit `--import` pass —
the net that references it dies with `Parse error` / `Nonexistent function 'new' in base 'GDScript'`, one
`--import` fixes it. **This is not only a worktree problem**: it bites in the main tree every time a plan
adds a `class_name` file, which is most of them. `run_nets.ps1` now runs the import itself when it sees a
`.gd` with no `.uid` beside it, so the hand-run is only needed when that guard is bypassed.
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

⚠ **All four hold in the tree today, and nets enforce them.** They were written before `src/` existed and
the tree was built to satisfy them on day one rather than retrofitted.

**The scan that enforces the drawing half is `net_draw_leaf`, and it is rebuilt and running.** It was first
written the day a hook that threw its own drawing away passed 54 checks out of 54, and everything it learned
since is in the current one:

- **Two shapes, because one does not fit every file.** A file-wide bound (*at most two `c.draw_` call
  sites*) for simple panels, and a **per-function table** pinning each function's `draw_*` count exactly —
  leaves at 1, composers at 0 — for a big view file
- ⚠ **A per-function table scans the functions it NAMES and nothing else, and that leaked twice — the
  second time out of the fix for the first.** A bare `c.draw_circle(...)` at the top of the view's `_paint`
  reached the screen every frame with **1414 checks green**; naming eight more composers still left eleven
  of twenty-eight functions outside, and the same circle was green again at **1889**. ⇒ **Adding names
  fixes the day it is done and nothing after it.** Close the class instead: walk the file's own `func`
  lines and redden on any name the table does not hold. **A function written tomorrow is red until listed**
- **Count the draw calls AND check the arguments survive.** `c.draw_circle(p, 0.0, col)` inside a leaf
  turned forty rocks and twelve ponds invisible with the round green — so also assert **every parameter a
  leaf is handed is still used in its body**
- **The colour half of the one-file rule**: not one `Color(` or `Color.RED` outside `look.gd`.
  ⚠ **The PIXEL half was never written** — a panel laid its cards out from literals — so that scan's green
  never meant "no presentation constant is loose"

**The `sim`/`view` halves were never scanned at all**: grep `src/sim/` for `extends Node` · `_draw` ·
`Input.` · `get_node` · `$`, and grep `src/view/` for writes to `sim.`. Write each when its folder has
enough in it to drift.

**The one-file rule for presentation constants is inherited and was measured**: scattering them meant the
power doubled and **zero things changed on screen**, because the numbers that would have shown it were in
six places and only one moved.

⚠ **A `const` packed array does not parse. Measured twice on 4.7.1**: `const X := PackedInt32Array([1,2,3])`
is a **parse error** — *"Assigned value for constant isn't a constant expression"* — while a plain `const X
:= [1,2,3]` is fine, nests fine, and folds a `deg_to_rad()` call inside it. Plan 3's part table was written
in the packed form and did not compile as written. A `const` Array is read-only in 4.x so immutability
survives; **element typing does not**, which is why every read of `Parts.*` casts (`int(...)`, `float(...)`).
**Every flat table this repo writes from here walks into it.**

**A flat array of bodies is a correctness contract, not a performance one.** 300 `Node2D`s cost 0.065ms
here — **the engine was never the wall.** The old swarm kept `carried[i]` in a `PackedFloat32Array`, and
that is what made *"a body killed far from home loses its cargo"* **structurally true**, with no code that
had to remember to drop it. ⇒ **The new game's soldiers carry parts across islands and die permanently.
Same shape, same reason** — put the columns in flat arrays and the loss needs no bookkeeping.

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
- **A spy on a hook sees the HOOK, never the native call inside it.** Measured on plan 3: with the whole
  argument chain closed — a literal pinned at `_paint_body`'s call site and read back off the spy —
  **emptying `_paint_dot`'s and `_paint_outline`'s bodies left the round green.** There are no pixels to
  read back headless, so the last inch has to be pinned **structurally**: `net_draw_leaf` now counts
  `draw_*` calls **per function** in `field_view.gd` (each leaf exactly 1, `_paint_cell` 7) and carries
  four cases that fail the *scanner*. ⇒ **Argument capture proves a value was computed and handed on. It
  never proves the value was used.** Chase it to a leaf, then pin the leaf by counting
- **The plan's own fix gets applied to one value and not to its siblings.** Plan 3 predicted in writing
  that five internal slots could change nothing on screen and stay green; the builder closed **corner**
  through `_blob` and left `outline_width`, `colour_depth` and `dot_radius` open one line over — and all
  six *external* slots could stop drawing at once. Four read-only passes found ten of these on an
  already-green round of 811, each confirmed by a mutation. ⇒ **Re-measure the whole table, not the row
  someone is arguing about** — this file's older sentence, re-earned
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
- ⚠ **A ceiling with no floor passes an effect that never happens.** The presentation round found this on
  **four items at once**: every row bounded *"the lunge never overlaps more than 6px"* and none of them said
  *"the lunge is not always zero"*, so **deleting the whole animation stayed green.** ⇒ **Bound both ends,
  in the same row.** The floor is the half that proves the feature exists
- ⚠ **Mouse clicks cannot be driven through `root.push_input()` headless, and they fail silently.**
  The headless window is **64×64**, so the stretch transform is **0.05**; `Viewport.push_input` divides the
  incoming coordinate by it and a click aimed at a dock **arrives at (2000, 6520), hits nothing, and raises
  no error.** Keys carry no coordinate and pass through fine — so **half an input suite can be green while
  the other half is dead.** ⇒ Call `game._unhandled_input(ev)` directly, or multiply by
  `root.get_final_transform()` before pushing. Measured with a spy node: the `InputEventMouseButton` itself
  does reach `_unhandled_input`; **only the coordinate is wrong**
- ⚠ **A `const` Array cannot be mutated at runtime, so "zero this table entry and watch it redden" is not a
  mutation you can write.** Twelve planned net rows died on this. **Drive the accessor instead** — the
  off-by-one in `fx_gain_of` is reachable and the raw table is not
- **Measuring a pure function is not measuring that anything calls it — and the scanner has a hole shaped
  exactly like that.** `net_draw_leaf._scan` skips any function with `draw` count 0, so building geometry
  inside a helper and passing an **empty** array to the leaf reads as *1 draw call, 4/4 arguments used* —
  green, with nothing on screen. ⇒ **Build the points in `_draw()` and hand them to the leaf as an
  argument**, so the spy captures the geometry itself

## Running the nets

**Where it stands: 9 nets, 725 checks, 2.2 seconds, green.** It got there in one day from an empty `src/` —
6 nets / 399 checks for the slice, then 9 / 725 after the presentation pass.

**The bar the old game reached: 25 nets, 3541 checks, 4.6 seconds** — `v2-openfield` at its end
(22/2420 after its presentation pass, 18/889 four days earlier, 16/514 the day before that).
⚠ **That is a scale marker, not a target.** Those nets drove a game that was deleted for not being fun.
A net is `tests/nets/net_*.gd` with one method, `func run(t)`,
and `t` gives you `ok` · `eq` · `pump_frames` · `expect_error` · `root`. **The wrapper reds below five
nets** — that is the scan-broken detector, so nets land in groups, never one at a time.

1. **"N passed" is not green.** `load()` returns non-null on a parse failure, so the count holds even with
   `src/` broken. Only the final `[wrapper]` line decides.
   **A net that ran zero checks is a failure** — the runner snapshots the counter around each net. It was
   added the day a missing `await` made a net **vanish with exit code 0** instead of going red
2. **If `[race]` prints, distrust the result — green included.** Running while someone edits reads
   half-written files.
   ⚠ **`[race]` catches an edit *during* the round, never one *between* rounds** — and comparing two rounds is
   the whole of mutation testing. So the runner now prints **`[지문]`, a fingerprint of every scanned file**:
   **two rounds with different fingerprints did not measure the same tree.** It was added the night five agents
   shared one tree and a mutation verifier had its edit silently reverted between the `Edit` and the run, plus
   two rounds poisoned by someone else's edit landing in the same file. **A mutation whose PRE and POST
   fingerprints differ from each other only by that mutation is the only one that proves anything.**
   ⚠ **For two plans it hashed `path|length|mtime` and NOT the bytes**, so a byte-identical revert moved it
   and the protocol above could not be executed literally — three separate repairs reported this in one
   night and each worked around it by doing the edit and the run in one command. **It hashes the content
   now**; an mtime-only touch leaves the fingerprint where it was, measured.
   ⚠ **And it covers `docs/` and `CLAUDE.md` too, since `net_citations` reads them** — a `src`+`tests` digest
   printed identically while a doc edit changed what the round measured, which is the one claim the print
   exists to make. `.gitattributes` normalises `*.md` for the same reason.
   ⇒ **When the tree is contested, do the edit and the run in ONE command** anyway. **`git status
   --porcelain` is deliberately NOT a red** — an uncommitted tree is the normal state of every builder round,
   so it would red everything
   ⚠ **A hung net is not a slow net, and for two plans the round could not tell them apart.** Zeroing one
   increment made `net_eating` spin for 148.7s with no verdict printed at all — not red, not green — which
   silently disarms mutation testing on the whole net. `run_nets.ps1` now kills any net past
   `$NetTimeoutSec` (120s), reports it red, and **zeroes its pass count** so a partial flush cannot read as
   progress. Proved with a deliberately hanging net
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
**Close any editor you launched when the session ends.**

⇒ **Without the bridge the game screenshots itself, and that is now built: `tools/look/`.** Windowed, seven
frames, quits on its own, every input through `root.push_input()` so nothing is taken from the user.
**`--headless` cannot capture** — no swapchain, `root.get_texture()` comes back blank, and every PNG is a
black rectangle **with no error anywhere.** (Headless still turns real frames and really runs `_draw()`;
what it cannot do is hand back pixels.) Read that folder's README before writing another one: its first
close-up came back **at play scale** because `_apply_zoom()` rewrote the camera before the shot, silently —
**a capture harness is an instrument, so take one frame you already know the answer to before trusting any
of the others.**

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
