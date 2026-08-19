# tockbon

Loaded into every session and every agent. **Keep only what applies to everyone.**

⚠ **This file was 726 lines on 2026-08-19 and the user cut it to ~300** — *"어느센가 claude.md 가 너무
길어졌다"*. Four sections moved out whole; **nothing was deleted, only relocated**, and each pointer below
names where. ⇒ **When you add here, ask first whether it belongs in the doc that owns the subject.**
This file holds **rules every agent must have without reading anything**; everything else is a doc.

## The game — a **cell autobattler**, and it runs

**Read `cell-army-gdd` before proposing anything.** One line: **「먹을 것을 고르러 간다」** — a node map of
islands (상자 · 전투 · 엘리트 · 보스, **only 상자 has no fight**), a squad of square cells landed **by boat on
an open coastline**, and **what you eat turned into 세포 and objects you fit together between rounds.**

- **There is no host**, no `F`, no `V`, and **the keyboard does nothing in this game at all**
- **You plan the whole landing, press start, and watch.** The hand does not move during combat
  (`plan-then-watch`, user, 2026-08-18). The 1~5 summon keys are deleted
  ⚠⚠ **OVERTURNED on 2026-08-19 in design, NOT in code** — the user decided **the boat stays live during
  the fight** (「배만 좀 참여하는 걸로」): you may keep choosing when and where to send the next one,
  **and a soldier already ashore still cannot be touched.** The tree above is what SHIPS; `push-inland`
  holds the derivation. ⚠ **The reason the old rule was taken — a fight is one minute — is gone**, and
  `plan-then-watch`'s own sentence says its rules 1/4/5 hold each other up, **so 4 and 5 are now
  unsupported and nobody has re-decided them**
- **Boats are unlimited and one-seat, and there is deliberately no brake yet** — 「일단 빼고 만든 이후에
  추가하자는 거임」. **Nothing licenses writing a cap**
- **Soldiers carry across islands, HP included, and a dead one is dead for good**
- The loss condition is a **time limit**, ⚠ **and the probe measured it has never once bound** — 15
  island-runs, worst plan at 49%. ⚠⚠ **The user deleted the time limit on 2026-08-19** (「제한 시간
  개념은 없어져야 될 거 같고」) — **in design, not in code.** ⇒ **The loss condition is therefore
  UNDECIDED.** `Lose.WIPED` already ships and the GDD wrote it as a *second* condition standing behind the
  clock; **nobody has confirmed it as the only one**, and with no clock **nothing charges for waiting.**
  ⚠ Deleting it also disarms the probe, whose entire grade is *"% of the time limit"*
- Two reference points the user asked never to be dropped: **Bad North** (2 people, ~790k) and **Despot's
  Game** (100k+, units not controlled at all). ⚠ **Bad North is NOT "place and watch"** — the developer says
  he lowered the *granularity* of control, not removed it

**The tree**: `src/sim/` (rules · grid · islands · army · battle · run · map) · `src/view/` (field · hud ·
panel · map · title) · `src/shell/game.gd` · `src/look.gd` · `tools/probe/run_run.gd`. `run/main_scene` is
`src/shell/game.tscn`. **A run plays end to end from the title.**
**Round: 15 nets, 2216 checks, 4.5s, green.**

⚠ **`title-and-map` step 5 is NOT built** — `MAP_NODES`'s island column is `[0, 1, 2, 1, 2, -1, 2]`, so
**three grids serve six island-opening nodes** and every route replays terrain it has solved. The user
decided six. **This is the standing instance of 「내가 말한대로 개발을 안하네」.**
✅ **Its gate is answered — 「층마다 둘 중 하나」 (user, 2026-08-19)**, so the node table stands and the
grids can be authored. ⚠ **The chest's payout is NOT answered and must not be built this round.**

### Why the second game died — the most reusable sentence here

The user played it: *"그냥 재미가 없다."* The diagnosis inverted: not *"the swarm has no merit"* but
**"the swarm has no cost."**

⇒ **An advantage with no cost is not a decision, and a mechanic that is not a decision is not fun.**

**This test has caught three more designs since**, each time by working the arithmetic rather than arguing —
the record is in `lessons-from-two-dead-games`. ⚠ **Nothing in that file is a spec.**

⚠ **And the conversation circled six times**, because the complaint was one sentence (*"분신이 왜 있는지
모르겠다"*) and **every answer offered was a new system.** ⇒ **When a complaint is one sentence, first ask
whether a rule can answer it. A new system cannot be evaluated, only accumulated.**

### What the user has said after playing — the open problems

**Every verdict is recorded in the doc that owns it**, not here — `idea-inbox` indexes the open ones.
The state of it: 「배가 곁다리」 stopped coming back after `boat-invasion`. **「애매하다」 did not come back
last round, which is not the same as closed.** The title and the map drew **no complaint after their
readability pass — the closest thing to a pass this repo has recorded.**

⚠ **Both of the two that stood here were DROPPED by the user on 2026-08-19** — 「조작감이 너무 ㅈ같음」
and 「싸움이 좀 아직은 별로네」, in their own words: ***"지워주고"***. `idea-inbox` rows 13 and 23 keep both.
**`dropped` is not `refuted`** — no arithmetic killed either, so **do not re-raise them and do not treat
them as answered.** The measurement behind the first (10–13 precision drags an island) stays in the probe.

⇒ **Nothing is open here now.** The live work is `title-and-map` step 5, whose gate — 「층마다 둘 중
하나」 — the user answered on 2026-08-19. ⚠ **One thing IS undecided and it is arithmetic-bearing:
what the chest pays.** The design doc says artifacts under a ✅ with the user's quote; the user said
미정 on 2026-08-19. **Both quotes stand and neither wins by inference.**

⇒ Read *"제일 평범하네"* against what came before it: eight months of not one fun moment, then *"그냥 재미가
없다"*. **"Ordinary" is the highest mark anything here has been given, and it is still not "fun".**

⚠ **The named trap is here.** *"애매하다"* is one sentence. ⇒ **Turn it into a number before choosing what to
add** — the move that produced *83% dead air, 150s between kills* is in `lessons-from-two-dead-games`, and
the probe that does it exists at `tools/probe/run_run.gd`.

### A feature is not done until its presentation is done (decided by the user)

*"이번 것처럼 무조건 연출까지 개발하는 게 기본임."* ⇒ **A plan that ships rules and leaves the picture for
later is an incomplete plan.** Presentation is planned in the same doc and ships in the same round.

⚠ **This is not a licence to gold-plate.** What it means is narrow: **every rule that changes state has
something on screen that says it happened.** The old game died partly because *"화면에 줄어드는 양이 하나도
없었다"*. ⚠ **And presentation is where green rounds lie most easily** — see `how-nets-lie`.

### Play is an instrument the harness does not contain

Game two shipped 25 nets and 3541 green checks and **the user could not play it.** Four things three rounds
of adversarial verification missed were found in five minutes of play, twice over.
⇒ **`planning-principles` survived both resets on purpose.** Its second line — **planning cannot decide
whether something is fun** — is why this section exists.

### Do not restore code OR docs from a tag

Everything measured in either dead game is recoverable at `v1-sim` and `v2-openfield`. **Restoring re-imports
a whole set of constraints this design does not have** — `v1-sim` assumes integer determinism and a 20Hz
tick, `v2-openfield` assumes a host, an open field and a swarm you steer.

## No `git push` until 2026-08-22 (decided by the user)

Local commits pile up as normal — only the remote is frozen. `gh-pages` redeploy counts as a push. The NAN
2026 submission links must stay exactly as judged. **`wrap-up` stops at the commit.** Delete this section
once the date passes. **The submission itself is safe from anything done locally** — judges see `origin/main`
and `gh-pages`, and neither moves while the freeze holds.

## Language

**Every reply to the user is in 한국어**, even when they write in English.

**Docs, comments and prompts are English, one file each** — the Korean twins were deleted on 2026-08-19 after
checking that every pair carried the same facts and section structure. **Do not recreate a `-ko` twin.**

**Korean is what the user reads**: their own commands, commit messages, in-game text, **net check labels**,
and the net runner's console output. **A `push_error` message and the `t.expect_error` that forgives it are
one unit** — matched by plain substring, so translating one side leaves the bark undeclared.

## Reply rule — **the whole reply under 50 characters**

"Be brief" didn't work, so it is a number now. Long replies go unread and block work.

- **Not one sentence — the entire reply is 50 chars.** Over that, write it in a doc and name the file
- **No tables or lists in chat. No emoji. No dates.** Bold is the only emphasis
- **Don't ask.** Look in the conversation first. If you must ask, one sentence
- **Cut every word that isn't load-bearing** — in docs and in chat

### The exception — when the user asks to be told something, answer in chat

**The 50 characters govern work reports** ("done", "here's the file"). **They do not govern answers.**
When the user asks — "what is this", "list the options", "how does it work" — **write the answer, and a list
is allowed.** **Filing the answer in a doc and replying with the filename is the failure this exception
exists to stop.** A doc may be written *as well*; the chat still carries the answer.

#### The exception has a ceiling — **10 lines**

It buys an answer, not an essay. Five rounds of options-plus-reasoning-plus-recommendation-plus-question and
**the user stopped the conversation to say the brevity rule had apparently been deleted. It had not.**

- **One axis per reply.** Options are one line each; the reason goes on that line or is cut
- **One line of recommendation**, and the next question is one line at the end — or it waits
- **Do not restate what the user just said back to them**
- **If the reply has more than one bold heading's worth of thought, it is two replies**

### Do not close a conversation the user is still having

Ending three replies in a row with "shall I start?" reads as being shut down, and **the user said so in those
words.** **Answer, add what the answer opens up, and stop.**

### A recommendation without a source is not a recommendation

**The user is new to making games and said so**: *"I have no data, so whatever you say feels like it must be
right."* **That is the absence of anything to disagree with, not agreement.**

- **Name who actually works that way** — studios, games, people, **several, disagreeing with each other**
- **The source has to be checkable.** *"Usually in the industry…"* is not one, and neither is this file
- **Look it up rather than remembering it.** A studio named from memory that turns out wrong is worse than no
  example, because it cannot be checked and it will be repeated
- **Give the case against your own recommendation too**
- **This binds technical choices as well** — engines, libraries, tooling, verification

⇒ The first one written this way is `how-studios-schedule-art`, **and the answer turned out to be neither of
the two options that had been on the table.**

## Where things live

**`docs/` is small on purpose. This table plus the three README indexes is the whole of it.**

| Doc | Question it answers |
|---|---|
| `cell-army-gdd` | **The GDD. What is being built.** ⚠ Its refutation boxes — where an earlier claim is disproved by arithmetic in the same file — are the most valuable paragraphs in it |
| `idea-inbox` | **What the user said, before anyone decided what to do with it.** One row per remark, verbatim, dated, with a state. **Three rows are open and one — 「넷이 의미가 있나」 — has never been answered** |
| `planning-principles` | **How to judge a direction.** Survived both resets on purpose — read it first |
| `how-nets-lie` | **Every green measured to be false.** The casebook behind 「No fake nets」. **Read it before writing a check and before believing a green round** |
| `lessons-from-two-dead-games` | **What two deleted games measured**, and the three measurement lessons that outlive them — *a constant is not what reaches the screen* (a radius of 8 was cited as 8px and reached the screen at **38px**, off by 4.8x, and the same shape bit four times) · *a design complaint can become a number* · *a probe that grades its own step must be inverted*. ⚠ **Nothing in it is a spec** |
| `what-makes-placement-a-decision` | Nine shipped games and the rule each used to make position a real choice, with the case against each |
| `parallel-build` | **Worktree per builder, and the report the user reads.** ⚠ **Never run**, and **its section 6 is an adversarial review of itself** that moved four of its own claims and found a blocking defect in `run_nets.ps1` |
| `how-studios-schedule-art` | **When other studios attach the art**, with sources |
| `gdd-audit` | **Findings already refuted — do not raise them again.** Fifteen of them |
| `docs/decisions/` | **Why something was *not* done.** Seven docs; **two are reversed and kept for that reason** |
| `push-inland` | ⚠⚠ **The newest and the biggest — one combat node becomes a continent you land on and push through for 10–15 minutes, with the boat as the only live control.** Nothing built, nothing accepted. **Read its retraction boxes**: six of its own numbers were refuted by an independent re-measure, one "cross-check" turned out to be an algebraic identity, and **every remaining question lands on R, the roster size, which nobody has decided** |
| `title-and-map` · `plan-then-watch` · `session-loop` · `boat-invasion` · `combat-juice` | The design docs. Each header carries `Implemented` and `Accepted` as **two separate axes**, and several carry refutations of their own earlier drafts |
| `docs/plans/` `1.ready` `2.active` `3.done` | **The only folder that moves.** `1.ready` empty; `2.active` holds `speed-off-open-landing` (**building**) and `title-and-map` (**paused**); `3.done` holds three |
| `docs/next-game.md` | The two resets and what carried across |

**Moved out of this file on 2026-08-19, unedited**: the fake-green casebook → `how-nets-lie`; the godot MCP
bridge → `.claude/agents/verify-look.md` (its only user); what pixel generation measured →
`tools/pixel/README.md`.

**A concept never changes folder.** `docs/archive/` does **not** exist and must not be recreated — **a doc
about a dead thing gets distilled and deleted.** Archiving in place produced 60 stale docs by 2026-08-17.

**Never state the same thing twice.** A value counted in two places will diverge.

**A refutation that lands in a different doc than the claim does not propagate.** One doc's wrong claim was
already disproved by a measurement written **in a different file**; it was never fixed and a whole stage's
cost model was built on it. ⇒ **Go and edit the doc that makes the claim.**

**And a correction pass only checks the row someone is arguing about.** One table held two rotted numbers:
the loud one was re-measured and the quiet one beside it — **off by a factor of twenty-four** — was waved
through **because it was not making a dramatic claim.** ⇒ **Re-measure the whole table.**

**When the user says something in passing, it goes into `idea-inbox` as one row, that turn.** Verbatim,
dated, with a state. **Nothing is deleted from it.**

⚠ **Two process rules are now forced by `net_process` rather than by good faith**, because both were
written in two places each and skipped both times: **a plan carrying an `OPEN questions` section must
declare whether they were sent**, and **a plan must carry a `## Round log` with all five fields per block.**
Four plans predate it and the exemption list **is pinned at four — plan number five is checked.**
⚠ **It forces the shape, never the truth**: a `Sent to the user: yes` on a message nobody sent passes. ⚠ **This exists because the heavier rule below was never
followed** — *"내가 그냥 대화를 하고 있지만 사실 항상 아이디어를 내는 거거든? 근데 니가 그냥 지워버림."* A
design doc costs more than a remark, so the remark was dropped instead.

**Once an idea is picked, it grows into a `docs/design/` doc with one row in that README**, headed
`Implemented` and `Accepted` — without them, "written down" reads as "exists".

**When a fork is taken, record the rejected branch in `docs/decisions/`.** Laying out options and letting the
user pick means two or three unpicked options appear every round and only the picked one is written down.
Months later the same options get laid out from scratch. **The user lived this with inventory, and again with
the whole game.**

**Moving a `plans/` doc means three edits**: the `**Status**:` line inside it, every link pointing at it, and
a report of all three folders. **Links leak every single time.**

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

**Invert every new check.** An uninverted check proves "it runs", not "it measures". **If the inversion
doesn't bite, suspect the check last** — first confirm the mutation actually landed. String replacement has
silently matched zero times, twice.

**Invert the instrument, not only the subject.** Twice in one night a check was written to catch a defect and
**shipped carrying that same defect.** ⇒ A new check needs a case that fails *it*.

**A truncated search is not a search.** `grep ... | head` on a term with many hits **silently drops the one
that matters. Count the hits before reading them.**

⚠ **These are the rules. The cases are in `how-nets-lie` — 129 lines of greens that guaranteed nothing, each
one measured. Read it before writing a check and before believing a green round.** Its four sharpest:
**a check that greps a file measures its text, never what it computes** · **a spy on a hook never sees the
native call inside it** · **"`_draw()` ran" is not "anything was drawn"** · **a ceiling with no floor passes
an effect that never happens.**

## Running the nets

**15 nets, 2216 checks, 4.5 seconds, green.** The old game reached 25 / 3541 / 4.6s — ⚠ **a scale marker,
not a target.** Those nets drove a game deleted for not being fun.

A net is `tests/nets/net_*.gd` with one method, `func run(t)`; `t` gives `ok` · `eq` · `pump_frames` ·
`expect_error` · `root`. **The wrapper reds below five nets** — that is the scan-broken detector, so nets
land in groups, never one at a time.

1. **"N passed" is not green.** `load()` returns non-null on a parse failure. Only the final `[wrapper]` line
   decides. **A net that ran zero checks is a failure** — added the day a missing `await` made a net vanish
   with exit code 0
2. **If `[race]` prints, distrust the result — green included.** ⚠ It catches an edit *during* a round, never
   one *between* rounds, and comparing two rounds is the whole of mutation testing. ⇒ **`[지문]` hashes the
   content of every scanned file** (`src`, `tests`, `docs`, `CLAUDE.md`): **two rounds with different
   fingerprints did not measure the same tree.** ⇒ **When the tree is contested, do the edit and the run in
   ONE command.** `git status --porcelain` is deliberately NOT a red — an uncommitted tree is the normal
   state of every builder round
3. ⚠ **A hung net is not a slow net**, and for two plans the round could not tell them apart — one net spun
   148.7s with no verdict printed at all, silently disarming mutation testing. The runner now kills any net
   past `$NetTimeoutSec` (120s), reports it red, and **zeroes its pass count**
4. **Each net runs in its own process, in parallel.** Not for speed — **for honesty**: amnesty stays inside
   its own net. Measured: net 1's forged bark was covered by net 3's declaration when they shared one.
   **Do not break this property**
5. **`_draw()` is measurable headless.** The runner pumps real frames (`t.pump_frames(n)` after
   `t.root.add_child`). **"It can't be driven headless" has been claimed four times and was wrong four
   times.** Only pixel appearance is verify-look's
6. ⚠ **Mouse clicks cannot be driven through `root.push_input()` headless, and they fail silently.** The
   headless window is 64x64 so the stretch transform is 0.05; a click aimed at a dock **arrives at
   (2000, 6520), hits nothing, and raises no error.** Keys pass through fine — so **half an input suite can
   be green while the other half is dead.** Call `game._unhandled_input(ev)` directly

**Call `harness-manager` when a round grows.** The old game's round was ~28s and **one net was 24.3s of it,
unnoticed for weeks.** Slow means verification gets skipped, and then none of the above matters.

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
