# Plan — the boat and the landing: an open coastline, a fleet that moves, and a camera

**Status**: `3.done` — **all six stages built. The round is 11 nets / 967 checks green (2026-08-18).**
Two independent verify-read passes ran **59 mutations** across the stages; every hole they found was closed
and re-confirmed red by separate sweeps. The probe was rewritten and run.

⚠ **verify-look never ran, and it is not going to.** It was held in `2.active` waiting for one — and then
**the user launched the build and looked at it themselves**, which is the stronger instrument. `3.done`
means implementation finished, and it is. **Acceptance is a separate axis and it lives in the design
doc's `Accepted` line**, which now carries the user's words: *"참 애매하네. 그래도 그동안 중에서 제일
평범하네."* ⇒ **The one sentence this plan aimed at — 「배가 곁다리다」 — did not come back. The game still
did not land.** Do not read this folder move as acceptance.

⚠ **What the build measured is NOT in this file.** The probe's numbers live in
`boat-invasion` / `-ko`, section 1-A — that is the doc whose own question they answer, and a figure
written in two places diverges. **What is here is only what this plan got wrong or cut.**
**Design**: [the boat and the landing](../../design/boat-invasion.md) (Korean: `boat-invasion-ko`).
**Rejected fork**: [open coastline over fixed docks](../../decisions/open-coastline-over-fixed-docks.md).
**Presentation contract**: [combat juice](../../design/combat-juice.md) — its hook table and
`net_draw_leaf._table()` are the authority for every `draw_*` count named here.

**Goal, in the user's words**: 「침공」 has to read, and *"배가 곁다리인 게 여전히 별로네."* has to stop
being true.

> ## ⚠⚠ What this plan does NOT buy — read before anything else
>
> The design doc's section 1 says it in as many words and it is repeated here because a built thing
> reads as a proved thing: **decided #9 leaves `TIME_LIMITS` alone, so "an open coastline has a cost"
> is not proven by this round.** Piecemeal engagement is still nearly free in walk-clock. What this
> plan delivers is the *machinery* for a cost — a shore you can read, cliffs that block it, a crossing
> whose length varies by **2.1–2.4×**, and a fleet whose position is moved by where you land — plus
> **the probe run that measures whether the cost exists.** Stage 6 reports numbers; it does not tune
> the clock. Reading this build as "the landing decision now has a cost" is the failure this repo has
> lived through twice.

---

## 0. What is settled, what this plan decided, and what is still a guess

**Settled by the user** — the ten rows of the design doc's 「정해진 것」 table, plus three answers given
after the first draft of this plan:

- **Island above, sea below** — accepted. All three grids are drawn that way.
- **A boat sails a straight line and may not cross land** — accepted: *"3번도 맞고"*.
- ⚠ **Harbours are PLURAL, and there is no single exact launch point** — *"항구는 여러 곳인데?
  정확히 정해진 데가 없다는 게 맞을 듯"*. **This overturned the first draft of this plan**, which had one
  fixed harbour per island. Section 4 is rebuilt around it.

**Decided by this plan**, because the design doc left them open and a builder cannot proceed without
them:

| Design doc | This plan's answer | Section |
|---|---|---|
| 미정 1 — how the screen says a coast is blocked | One predicate, `grid.can_land_at(harbour, tile)`, drives both the drag overlay and `launch`. The screen cannot disagree with the rule | 3, 6 |
| 미정 2 — the drag's details | Grab the boat — its hull at its harbour, or its HUD icon — drag, release on a tile. Release elsewhere cancels and the icon shakes | 6 |
| 미정 3 — what a landable tile is | Passable land, **orthogonally** adjacent to water. Diagonal touch does not count | 3 |
| 미정 4 — what `D` becomes | **Deleted.** A dock character is a second rule saying what "unblocked coast" already says | 3 |
| 미정 5 — the two speeds | big **3.0** tiles/s, fast **5.0**. `2 × 5 < 4 × 3` ✓ with a 20% margin | 4 |
| 미정 6 — boat identity and per-boat timing | **The berth is deleted, not indexed.** A boat is at a harbour or it is in `boats`; there is no second timer | 4 |
| 미정 7 — crossing time scales with distance | Yes. `t = distance / speed`, and the distance is now a property of the (harbour, landing) pair | 4 |
| 미정 8 — the three islands at 48×32 | Authored and measured, harbours included. Section 5 | 5 |
| 미정 9 — how cliff coast is stored | A legend character, `^`, impassable. **No elevation axis** | 3 |
| 미정 10 — what a ramp is | `/`, passable land. This round a ramp is a **doorway through a cliff**, not a climb | 3 |
| 미정 11 — the boat that cannot unload | The wait rule stays; the failure case is forbidden at authoring time by a net, and a waiting boat is **drawn waiting** | 4, 7 |
| 미정 12 — enemy movement seeing boats | **No change.** `ashore_only = true` stays and a net pins it | 4 |
| 미정 13 · 14 — landing exposure, a cost for the line | **Not this round.** Section 1 of the design doc demoted both | 10 |

**Still a guess, and named as such**: every number in section 7, the two speeds, whether 60/60/90
survives a 1.7× longer walk, and — stated plainly in 4.6 — **whether "land next to a harbour" is
dominant.** Stage 6 measures all four and **reports**.

---

## 1. Files

```
stage 1 — ADDITIVE ONLY. Nothing is deleted; every existing net stays green
  src/sim/grid.gd         water · landable · harbour_tiles · start_harbour · sendable[h] ·
                          line_tests · water_line_clear · can_land_at · home_harbour_for.
                          Legend gains H ^ / — and KEEPS D and dock_tiles
  src/sim/rules.gd        LINE_SAMPLE_STEP only
  tests/nets/net_coast.gd NEW — landability, the straight line, and the returning rule.
                          Fixtures only: it reads no island

stage 2 — THE SWAP. Atomic: the API, its caller, its islands and its nets move together
  src/sim/rules.gd        BOATS table replaces FLEET / CAP / CROSSING
  src/sim/grid.gd         D · DOCK_CHAR · dock_tiles deleted
  src/sim/islands.gd      three 48×32 grids, new legend, THREE harbours each
  src/sim/battle.gd       boat_at · per-boat pending · outbound/returning · launch(boat, tile).
                          dock_count · dock_tile · _border_water_near deleted
  src/look.gd             GRID_W/H 48×32 · WATER_MARGIN_TILES 5
  tests/                  net_boat and net_islands rewritten; net_battle · net_run · net_shell ·
                          net_fx_view patched where the grid size or the dock API reaches them

stage 3 — src/look.gd zoom range · src/view/field_view.gd transform · src/shell/game.gd pan+zoom ·
          tests/nets/net_camera.gd NEW
stage 4 — src/shell/game.gd the drag · field_view overlay · hud_view per-boat icons
stage 5 — src/view/field_view.gd hulls, passengers, the return leg, TRANSIT bodies, cliff faces ·
          src/look.gd the constants in 7.2
stage 6 — tools/probe/run_run.gd the new API, plus a landing-point policy pair
```

**No new file under `src/view/`.** `net_draw_leaf` asserts `src/view/` holds exactly three drawing
files; the camera lives inside `field_view.gd` because that is the node whose transform it is.

⚠ **Cite this plan by NAME in comments — never by path and never by line number.** It changes folder
with its status, so the path dies that day, and `net_citations` greps `src/`, `tests/` and `tools/`
for both shapes. Name the section, not the number.

⚠ **`class_name` on a brand-new file is invisible to `--headless --script` until an `--import` pass.**
`net_coast.gd` and `net_camera.gd` declare no `class_name`, so they are safe; **`run_nets.ps1`'s
import guard still must not be bypassed.**
⚠ **`const X := PackedInt32Array([...])` does not parse.** Every table below is a plain `const` Array
and every read casts.

---

## 2. Order — six stages, each verifiable on its own

| # | Stage | Picture? | Green means |
|---|---|---|---|
| 1 | **Grid, legend, harbours, islands** — `grid.gd` · `islands.gd` · `Look.GRID_W/H` | no | `net_islands` · `net_coast` |
| 2 | **The swap** — `rules.gd` · `battle.gd` · `islands.gd` · `Look.GRID_W/H` and the nets that follow the grid size | no | `net_boat` · `net_islands` · `net_battle` · `net_run` · `net_shell` |
| 3 | **The camera** — `field_view.gd` transform · `look.gd` zoom · `game.gd` pan/zoom | **yes** | `net_camera` · `net_shell` · **verify-look** |
| 4 | **The drag** — `game.gd` gesture · the overlay · per-boat icons | **yes** | `net_shell` · `net_draw_leaf` · **verify-look** |
| 5 | **The fleet as a picture** — hulls at harbours, passengers, the return leg, TRANSIT bodies, waiting marker, cliff faces | **yes** | `net_fx_view` · `net_draw_leaf` · **verify-look** |
| 6 | **The probe** — new API, landing-point policy pair, run and **report** | no | numbers on the console |

### ⚠⚠ The boundary rule: **a stage is what can be GREEN at its halt, not which files it touches**

**A first draft of this table split stage 1 by file** — "`grid.gd` · `islands.gd` · `Look.GRID_W/H`" —
and it was wrong, caught by the builder before a line was written. Deleting `dock_tiles` there leaves
`battle.gd::launch` permanently dead while `net_boat`, `net_battle`, `net_shell`, `net_run` and
`net_fx_view` are not rewritten until stage 2: **the halt cannot be green, and a red halt measures
nothing.** The corrected boundaries:

- **Stage 1 is ADDITIVE ONLY. Nothing is deleted and nothing existing changes meaning.** `grid.gd`
  gains `water` · `landable` · `harbour_tiles` · `start_harbour` · `sendable` · `line_tests` ·
  `water_line_clear` · `can_land_at` · `home_harbour_for`, and the legend gains `H` · `^` · `/`.
  **`D`, `DOCK_CHAR` and `dock_tiles` all stay.** `islands.gd` and `Look.GRID_W/H` are **not touched**.
  ⇒ `net_coast` is fixture-only, so it needs none of the new islands, and **every existing net stays
  green because nothing was taken away.**
- **Stage 2 is atomic and there is no way to make it smaller.** The harbour API, its only caller
  (`battle.gd`), the islands it reads and the nets that drive it all move in one edit — `launch`'s
  signature cannot half-change. This is where `D` · `DOCK_CHAR` · `dock_tiles` · `FLEET` · `CAP` ·
  `CROSSING` · `_border_water_near` die.
- **Stage 2 also carries every net literal that follows from the grid size**, because they go red the
  instant `Look.GRID_W/H` move: `net_shell`'s tile count, its `_rects_land_on_screen` split into a map
  rect and a viewport rect, and `net_fx_view`'s tile expectation.
  ⚠ **Set `WATER_MARGIN_TILES` to 5 in stage 2, not stage 3.** It costs nothing without a camera and
  it stops the tile-count literal having to be rewritten twice.

⚠ **Stage 2 ends with a green round and a wrong screen** — 1920×1280 of map in a 1280×720 viewport,
no camera. That is expected, it is why stages 1 and 2 carry no verify-look, and **they must not be
shipped alone: stage 3 lands in the same round.**

⚠ **Stages 3, 4 and 5 each put something on screen and each is a verify-look stop.** *"이번 것처럼
무조건 연출까지 개발하는 게 기본임"* — the picture is planned with the rule, not after it.

---

## 3. Terrain — the legend, and what "blocked" means

### 3.1 The legend

| Char | Means | `passable` | `water` | landable |
|---|---|---|---|---|
| `~` | water | 0 | 1 | — |
| `H` | **harbour** — water, and a tile boats sail from and return to. **Several per island** | 0 | 1 | — |
| `.` | land | 1 | 0 | if orthogonally beside water |
| `#` | hole — impassable land, inland | 0 | 0 | no |
| `^` | **cliff** — impassable land, at the coast | 0 | 0 | no |
| `/` | **ramp** — passable land, the only way through a cliff wall | 1 | 0 | if orthogonally beside water |
| `B` `C` `L` | land with a bison / crow / lion on it | 1 | 0 | as `.` |

⚠ **The three new characters land in stage 1; `D` dies in stage 2.** Stage 1 only *adds* to the legend
— `H` and `^` need no code beyond not being in `LAND_CHARS`, and `/` joins it — so today's islands keep
loading exactly as they do now. See the boundary rule in section 2.

**`D` is deleted**, and with it `Grid.DOCK_CHAR`, `grid.dock_tiles`, `battle.dock_count()`,
`battle.dock_tile()` and `game.gd::_click_dock`. ⚠ **`islands.gd`'s legend comment currently reads
*"`D` dock — land, and the only tile a boat may be sent to"*. It goes false the moment this ships —
rewrite it in the same edit.**

**`harbour_tiles` is filled in row-major order**, the same convention `dock_tiles` used, so a harbour
index is stable and reproducible.

### 3.2 ⚠ A cliff is impassable and NOTHING else. There is no elevation axis this round

Decided #7 is *"일단은 그냥 못 가는 것뿐이야"* and the design doc adds *"이번 라운드에 절벽 규칙을
늘리지 않는다."* ⇒ **`^` is exactly as impassable as `#` and differs from it only in the legend
character**, which is what the view reads to colour it — the same split water and hole have had since
day one (`grid.passable` is one byte and both are 0 in it).

**That is the whole mechanism, and it is structural rather than a rule**: a cliff tile sits between
the sea and the land behind it, so the land behind is not orthogonally adjacent to water and is
therefore **not landable, with no code that has to remember it.** Blocking a stretch of coast is
`^^^^` in a row of the island, and nothing else.

⇒ **A ramp is a doorway, not a climb.** `/` is passable land, and the only passable tile inside a
cliff wall. Island 2's two-tile ramp is the same lesson today's `##` neck teaches, drawn as a cliff.
⚠ **If elevation ever becomes real, `^` and `/` already exist as their own characters**, so the
upgrade is local — but *"높은 곳이 사거리를 벌어 준다"*, flying units, and clifftop watchers are all
named-and-parked, not built.

### 3.3 Landable — the definition, and why orthogonal

```
landable[t] = passable[t] == 1  AND  any of the FOUR orthogonal neighbours is water
```

**Diagonal adjacency does not count** (`Grid.NEIGHBOURS` is 8-way and this test deliberately is not).
A tile touching the sea only at a corner is a tile you would have to come ashore *through* the corner
between two blocked tiles; landing there reads as landing on the rock beside it.

### 3.4 Sendable — the straight-line rule, now **per harbour**

**A boat sails a straight line from the harbour it is sitting at, and may not cross land.**

```
can_land_at(h, t) = landable[t]  AND  water_line_clear(harbour_tiles[h], t)
```

`water_line_clear(a, b)` samples the segment at **`Rules.LINE_SAMPLE_STEP` = 0.05 tiles** (fine enough
that a one-tile wall cannot be stepped over), rounds each sample to a tile, and rejects the line if any
sampled tile is not water — **except tiles within Chebyshev distance 1 of `b`, which are exempt.**

⚠ **The step lives in `rules.gd`, not `look.gd` or `grid.gd`.** A coarser step accepts targets a finer
one refuses, so it **changes what happens** — that is the folder contract's whole test. It also keeps
it out of `net_draw_leaf`'s widened literal sweep, which only reaches `src/view/` and `src/shell/`.

⚠ **An island with no `H` is a defined no-op, not a bark.** `harbour_tiles` empty ⇒ `start_harbour` is
**-1**, `sendable` is empty, `can_land_at` is false for every tile, and nothing errors. **Stage 1
depends on this**: at that halt every real island and every existing net fixture still has zero
harbours. `grid.load_rows` does not validate its legend today either — that is `net_islands`' job —
and a bark here would have to be forgiven by every net that hands it a hand-written fixture.

⚠ **The exemption is load-bearing and it was measured.** Without it, a shallow approach rounds onto
the beach tile *next door* to its target, and a draft of island 1 refused **20 of its 36** beaches for
grazing the sand beside them. Grazing the neighbouring beach is not sailing over the island.

**This one rule does four jobs**, which is why it is worth adding:

1. The boat never slides over the island — the failure `_border_water_near` existed to avoid
   (measured in the first slice: a single fixed port sent boats across **58–77% dry land**).
2. A headland **shadows** the coast behind it, so cliffs block by geometry as well as by passability.
   Island 2's ridge runs into the sea for exactly this reason.
3. The drag gets something to say — 미정 1's *"놓았는데 아무 일도 안 일어나는 것은 지금 부두와 같은
   실패다"*.
4. ⚠ **With harbours plural it becomes the heart of the design**: **which coast you can reach depends
   on where your fleet is sitting.** Section 4.6 is the measurement.

### 3.5 ⚠ `sendable` is computed ONCE per harbour, in `load_rows`, and never per frame

`sendable` is an Array of `PackedByteArray`, one per harbour. `load_rows` fills `landable` for all
`w*h` tiles, then runs the line test **only over the landable ones** (~80 per island) **for each
harbour** (3): **~120k operations, once per island.** Computed live for the overlay instead it would
be 1536 tiles × ~500 samples = **750k operations a frame**, which is a real wall.

**`grid.line_tests` counts every line test ever run**, and a net asserts it does not move across 60
pumped frames. A cached value that is silently recomputed is invisible in every other check.

---

## 4. The fleet

### 4.1 The table — `rules.gd`

`FLEET`, `CAP` and `CROSSING` are **deleted**. In their place:

```gdscript
## Columns: name, capacity, speed (tiles/s).
const BOATS := [
    ["BIG",  4, 3.0],
    ["FAST", 2, 5.0],
]
```

with `boat_count()`, `cap_of(i)`, `boat_speed_of(i)`, `boat_name_of(i)`. Korean labels live in
`HudView`, exactly as `TYPE_LABELS` does for units — `Rules.name_of` returns identifiers and the user
cannot read English.

> ### The inequality is an acceptance condition, not a comment
>
> Round-trip throughput is `cap × speed / (2 × distance)`, so the fast boat must **lose on throughput
> and win on latency** or it dominates every send:
>
> **`cap_fast × speed_fast  <  cap_big × speed_big`** → **`2 × 5.0 = 10  <  4 × 3.0 = 12`** ✓
>
> ⚠ **Exactly 2× is a tie and the decision dies** — 4×3 = 12 = 2×6. *"빠른 배가 두 배 빠르다"* cannot
> be used. The margin here is **20%**.
> ⚠ **Distance cancels out of that comparison, so plural harbours do not touch it.** The inequality is
> the same whether a crossing is 7 tiles or 26.
> ⚠ **The net writes both sides out as literals** and never reads them back off `Rules`.

### 4.2 ⚠ The berth is DELETED, not indexed — 미정 6

The design doc asked what state carries boat identity and per-boat berth timing. **The answer is that
there is no berth.** A boat is in exactly one of two states:

```gdscript
var boat_at := PackedInt32Array()   # size boat_count(): which harbour this boat is sitting at
var pending := []                   # size boat_count(): each a PackedInt32Array of soldier ids
var boats: Array = []               # the ones at sea. A boat is busy IFF it is in here
```

⇒ **`berth_free_in` is gone.** Today it is a timer covering a return leg nothing draws; here the
return leg **is drawn** (7.2, P6), so the timer and the picture would be two copies of one fact — and
two clocks drift. **A boat is loadable and draggable exactly when it is not in `boats`.**

A boat at sea carries `boat` · `speed` · `phase` · `from` · `to` · `dist` · `t` · `soldiers`, with

```
phase OUTBOUND : from = harbour_tiles[boat_at[b]], to = the landing tile, soldiers = the cargo
phase RETURNING: from = the landing tile,          to = the new home harbour, soldiers = empty
```

On arrival of a RETURNING boat it leaves `boats` and `boat_at[b]` becomes that harbour.
**Waiting-to-unload is OUTBOUND with `t` past arrival** — no third state.

### 4.3 ⚠ A boat returns to the nearest harbour that can STILL see where it landed

This is the rule the user was told about, in the form the arithmetic survived:

```
home_harbour_for(landing) = the harbour h minimising distance(h, landing)
                            AMONG the harbours for which can_land_at(h, landing) is true
                            (ties to the lower tile index)
```

**The set is never empty** — the boat sailed from one such harbour, so at worst it stays put.

⚠ **The naive form of this rule — "the nearest harbour, full stop" — is a trap, and it was measured
rather than argued.** On island 3 it strands **2 of 46** beachheads: land there and the fleet moves to
a harbour that can no longer see the beach you just took, so you cannot reinforce your own landing and
**nothing on screen would explain why.** The clause above makes that unrepresentable. **`net_coast`
carries the stranding case as a fixture, so the clause cannot be quietly dropped.**

⇒ **What the rule buys**: the landing decision picks the next crossing's length *and* what coast the
fleet can still reach. **The supply line follows the invasion.** No new UI, no new input.

### 4.4 The calls that change

| Was | Becomes | Why |
|---|---|---|
| `load_soldier(t) -> bool` | `load_soldier(t) -> int`, the boat it boarded, or **-1** | The HUD has to mark the right boat, and a bool cannot say which |
| `launch(dock_index) -> bool` | `launch(boat, tile) -> bool` | The drag carries both |
| `berth_free_in` | **deleted** — membership in `boats` is the state | 4.2 |
| `dock_count()` · `dock_tile(d)` | `harbour_count()` · `harbour_tile(h)` · `boat_at` · `can_land_at(h, t)` | Docks are gone; harbours are several |
| `t / Rules.CROSSING` in `_phase_boats` | `boat.t * boat.speed / boat.dist` | Distance and speed both matter |
| `2.0 * Rules.CROSSING` in `launch` | **nothing** — the return leg is simulated, not timed | 4.2 |
| `_try_unload` from `boat["dock"]` | from `boat["target"]`, then the boat turns RETURNING | The target is any coast tile |
| `_border_water_near` | **deleted** | The origin is the boat's harbour |

**Who boards which boat** — `load_soldier(type_id)` puts the highest-HP living in-reserve soldier of
that type onto **the lowest-index boat that is at a harbour and has room**: the big boat first, the
fast boat when the big one is full or at sea.
⚠ **This is a feel item and the user marked it temporary** — *"병사 태우는 게 숫자 키인 게 좀 별로야
근데 일단은 저렇게 하고"*. It is a rule only because per-boat capacity forces the question.

> ### ⚠ One rule genuinely changes: **a boat at sea can no longer be loaded**
>
> Today loading is allowed while both boats are out, and the load goes on whichever berth frees first.
> With per-boat cargo that sentence has no referent — *which* queue is it joining?
> ⇒ **`load_soldier` returns -1 when every boat is at sea.** A harbour drawn empty then means exactly
> one thing: nothing to load, nothing to send.
> ⚠ **This tightens the throughput limit, which is the point of decided #6 — and it is the row most
> likely to produce dead air.** `_input_open` in the probe measures precisely this, and **stage 6
> reports it.** If the number is bad the answer is a third boat or a shorter round trip, not a quiet
> revert.

### 4.5 The boat that cannot unload — 미정 11

**The wait rule is unchanged**: `_try_unload` fills from `_free_tiles_from(target, cargo)`
breadth-first and **the whole boat waits** when there are fewer free tiles than soldiers. Partial
landing would silently reorder the deployment the player chose.

The design doc's fear — *"두 칸짜리 곶에 배를 보내면 영영 안 내리고, 섬이 타임아웃까지 멈추는데 화면에
설명이 하나도 없다"* — is answered in three places, none of which is a new rule:

1. **The search already walks over reserved tiles** and only collects free ones, so it escapes inland.
   The only real failure is a *disconnected* pocket.
2. **A net forbids the pocket at authoring time**: every sendable tile must sit in a passable region
   of at least `4` tiles. Measured on all three islands: the smallest is **716**. The check exists for
   the islands that come next.
3. **A waiting boat is drawn waiting** — 7.2, P7. The stall stops being silent whether or not the
   other two hold.

### 4.6 ⚠⚠ Does the returning rule collapse? — **measured, and the honest answer**

Main asked this before adopting it, and it is the right question: if the fleet chases the player, the
distance cost might evaporate. Every figure below comes from the generator that produced section 5's
grids, over **every** sendable landing on every island.

| | island 1 | island 2 | island 3 |
|---|---|---|---|
| **wave 1** (from the start harbour) | 11.70–24.60 · **×2.10** | 11.00–26.40 · **×2.40** | 13.00–24.60 · **×1.89** |
| **steady state** (after relocation) | 7.00–14.56 · **×2.08** | 8.00–12.04 · **×1.51** | 7.00–14.32 · **×2.05** |
| the fleet actually relocates on | 30 of 47 landings | 32 of 38 | 32 of 46 |

**1. It does not flatten the map.** Relocation makes every beach cheaper, but the *spread survives* —
7.00 tiles at the cheapest beach against 14.56 at the dearest, a **2× standing tax** on whoever
commits to the far one. The cost is reduced, not deleted.

**2. What actually replaces distance as the cost is REACH, and that is the better half.** Measured
sendable counts per harbour:

| island | start harbour | the other two |
|---|---|---|
| 1 | **47** tiles, columns 2–45 | 24 (cols 18–20, 28–45) · 29 (cols 2–19, 26–33) |
| 2 | **38** tiles, columns 2–17 **and** 24–45 | 23 (cols **24–45 only**) · 21 (cols **2–21 only**) |
| 3 | **46** tiles, columns 2–45 | 29 (cols 2–17, 22–32) · 33 (cols 13–27, 31–45) |

⇒ **The fleet starts where it can see the whole coast, and every landing trades breadth for
proximity.** On island 2 this is absolute: **once your fleet has moved to the east harbour it cannot
send a boat to the west shore at all** — the ridge is in the way — and the ramp becomes the only route
back. That is a real commitment, produced by geometry, with no rule written for it.

**3. What it does to the two speeds** — the gap between the boats' busy times, across all landings:

| | wave 1 | steady state |
|---|---|---|
| big boat busy | 7.33 – 12.81 s | 4.67 – 9.71 s |
| fast boat busy | 4.40 – 7.69 s | 2.80 – 5.82 s |
| **the gap** | **2.93 – 5.13 s** | **1.87 – 3.88 s** |

⇒ **The speed difference matters about a third less in steady state and most on the opening or
flanking crossing.** That is a division of labour rather than a loss: **the fast boat opens a front,
the big boat feeds one that is already open.** The throughput inequality is untouched (4.1).

> ### ⚠ What this does NOT settle
>
> **"Always land next to a harbour" is cheaper, and nothing here forbids it.** What it costs is reach
> (the near harbours see roughly half the coast) and the choice of where to fight — but **whether that
> is enough to stop it being dominant is not something arithmetic can answer**, because it depends on
> how much a bad landing costs in the fight, and that is the very number decided #9 left unmeasured.
> ⇒ **Stage 6's landing-point policy pair is the instrument.** Do not read this section as proof.
>
> ### ⇒ ANSWERED, against this section (2026-08-18)
>
> **It dominates 3 of 3 islands.** The reach cost above is real and it is not enough. **The cause is not
> in this section** — the landing point does move casualties, by up to 49%, and the clock does not bind,
> so those casualties stop nothing. **Numbers in `boat-invasion` / `-ko`, section 1-A; consequences in
> 11-A below.** ⚠ **The arithmetic in this section was right and its conclusion was still wrong**, which
> is exactly why the caveat was written.

### 4.7 ⚠ `ashore_only = true` does not move — 미정 12

`_phase_movement`'s enemy scan keeps excluding soldiers aboard. Chasing one means asking `flow_field`
for a path to a water tile, which comes back unreachable everywhere, and **every enemy on the island
freezes with nothing logged.** Shooting a boat is still allowed; that is `enemy_target`, a different
scan, and it is what makes the crossing dangerous.

⚠ **A net pins it from both sides**: an approaching boat pulls no enemy into motion, **and** every
enemy that should be moving is moving. The first half alone is satisfied by an island where nothing
moves at all.

---

## 5. The three islands, at 48×32 — **authored and measured**

**Format**: each island is a `const` Array of **32 strings of exactly 48 characters**.
48 × 32 = **1536 tiles**, 40 px each = **1920 × 1280 canvas px**. **Three `H` tiles per island.**

| | island 1 | island 2 | island 3 |
|---|---|---|---|
| harbour tiles (row-major) | **1337 · 1398 · 1512** | **1382 · 1402 · 1514** | **1303 · 1432 · 1512** |
| harbour x,y | (41,27) (6,29) (24,31) | (38,28) (10,29) (26,31) | (7,27) (40,29) (24,31) |
| **start harbour** | **1512** | **1514** | **1512** |
| coast tiles (landable) | 82 | 76 | 80 |
| sendable from the start | **47** | **38** | **46** |
| sendable, union over harbours | 50 | 44 | 48 |
| wave-1 crossing, tiles | 11.70 – 24.60 | 11.00 – 26.40 | 13.00 – 24.60 |
| steady-state crossing, tiles | 7.00 – 14.56 | 8.00 – 12.04 | 7.00 – 14.32 |
| narrowest column cut | **15** | **2** | **10** |
| spawns | 4 bison | 4 bison · 2 crow | lion · 2 crow · 2 bison |
| enemies detecting a fresh landing | 0 – 1 | 0 – 2 | 0 – 2 |
| smallest region a sendable tile sits in | 744 | 760 | 716 |
| walker pairs for `net_islands` | 200 | 264 | 240 |

**The start harbour is derived, not declared**: *the harbour whose nearest reachable coast tile is
farthest away*, ties to the lowest tile index. One sentence, computable in `load_rows`, and it means
every island opens with the fleet out at sea and the longest crossing of the run.
⚠ **The net pins the resulting TILE as a literal and asserts the RULE on a separate fixture.** Pinning
only the tile lets the rule be replaced by "harbour 0" and stay green on these three islands, where it
happens to be index 2 every time.

⇒ **Every island has a beach no enemy detects and a beach two do.** That is the design doc's section 1
structure — the landing point already picks who engages — surviving the redraw. **What it costs in
walk-clock is still unmeasured**; stage 6.

⚠ **`TIME_LIMITS` stays `[60.0, 60.0, 90.0]`.** Decided #9. Stage 6 reports; nobody edits it here.

⚠ **`battle.gd`'s `FIELD_TTL` comment says "the grid is 576 tiles… ~23k operations a second".**
Both numbers die: **1536 tiles**, and twenty units at 2 Hz is **~61k operations a second.**

### Island 1 — open, one bay, 4 bison. Narrowest cut **15**

The baseline the other two are measured against. **Deliberately no headland**: a draft put two cliff
promontories on it and they shadowed **50 of its 74** coast tiles, which is not a baseline. The bay at
columns 20–27 is the nearest landing from the start harbour (11.70) and the dearest to *hold*
(14.56 in steady state) — the one beach where the two costs disagree.

```
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~~",
"~~............................................~~",
"~~............................................~~",
"~~............................................~~",
"~~............................................~~",
"~~............................................~~",
"~~...........####..............####...........~~",
"~~...........####..............####...........~~",
"~~...........####..............####...........~~",
"~~............................................~~",
"~~............................................~~",
"~~................B...........B...............~~",
"~~.....B.................................B....~~",
"~~............................................~~",
"~~............................................~~",
"~~............................................~~",
"~~..................~~~~~~~~..................~~",
"~~..................~~~~~~~~..................~~",
"~~..................~~~~~~~~..................~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~H~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~~~~~~~~~~~~~~~~~~",
```

### Island 2 — a cliff ridge into the sea, one 2-tile ramp. Narrowest cut **2**

The neck lesson, redrawn as a cliff, and **the island where plural harbours pay for themselves.** The
ridge runs from the back wall into the water to row 25, so it shadows the coast at columns 20–21 and
splits the shore into a **west beach (2–19)** and an **east beach (24–45)**. Two crows west, four bison
east; crossing between them means the ramp at rows 12–13, **two tiles wide**.

⇒ **The start harbour (26,31) sees both shores. The west harbour sees only 2–21 and the east only
24–45.** Landing commits your fleet to one side.

**The crows can shoot a boat**: the west crow at (8,18) covers the approach to the west beach at
3.0 tiles, well inside `range 3 + REACH_BONUS 1.5 = 4.5`.

```
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~~",
"~~....................^^......................~~",
"~~....................^^......................~~",
"~~....................^^......................~~",
"~~....................^^......................~~",
"~~....................^^......................~~",
"~~....................^^......................~~",
"~~....................^^......................~~",
"~~....................^^..B...................~~",
"~~....................^^.....B................~~",
"~~....................//......................~~",
"~~....................//......................~~",
"~~....................^^..B...................~~",
"~~....................^^......B...............~~",
"~~....................^^......................~~",
"~~....................^^......................~~",
"~~......C.......C.....^^......................~~",
"~~....................^^......................~~",
"~~....................^^......................~~",
"~~~~~~~~~~~~~~~~~~~~~~^^~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~^^~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~^^~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~^^~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~^^~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~~~~",
"~~~~~~~~~~H~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~~~~~~~~~~~~~~~~",
```

⚠ **The ridge is two tiles wide everywhere, including its sea leg.** A one-tile wall leaks
diagonally — `Grid.NEIGHBOURS` is 8-way — and a unit slipping through the ridge deletes the island.

### Island 3 — a cliff ring with two ramp doors, behind a bay. Narrowest cut **10**

The ring in cliff, at columns 15–33 and rows 6–15, with a **two-tile ramp door on each side** (rows
10–11). Lion at the centre, a crow and a bison inside, a bison and a crow outside.

⚠ **This is the island that measured the returning rule's trap**: under "nearest harbour, full stop",
landing at **(18,18)** or **(17,19)** would strand the beachhead. 4.3's clause is what fixes it.

```
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~~",
"~~............................................~~",
"~~............................................~~",
"~~............................................~~",
"~~.............^^^^^^^^^^^^^^^^^^^............~~",
"~~.............^.................^............~~",
"~~.............^....C............^............~~",
"~~.............^.................^............~~",
"~~............./........L......../............~~",
"~~............./................./............~~",
"~~.............^.................^............~~",
"~~.............^............B....^............~~",
"~~.............^.................^............~~",
"~~.............^^^^^^^^^^^^^^^^^^^............~~",
"~~............................................~~",
"~~......B...............................C.....~~",
"~~............................................~~",
"~~................~~~~~~~~~~~~~...............~~",
"~~................~~~~~~~~~~~~~...............~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~H~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
"~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~~~~~~~~~~~~~~~~~~",
```

⚠ **The narrowest-cut figures are re-derived, not carried over.** `net_islands` defines the cut as
*"for each column, count the passable tiles; take the minimum over columns that have at least one"*,
and that definition is unchanged. **15 · 2 · 10 were computed from these exact rows.** Edit a row and
the number moves; re-measure it, never read it back off `Islands`.

---

## 6. Input — one gesture for the boat, one for the camera

`game.gd` stays the only file that reads an event. `_click_dock` is deleted whole.

| Input | Effect |
|---|---|
| `1` / `2` | load the highest-HP living in-reserve soldier of that type onto the first boat that is at a harbour with room |
| **Left press on a boat** — its hull on the map, or its HUD icon — loaded and at a harbour | **begin a boat drag** |
| Left drag, boat drag in progress | the overlay shows the coast **that boat's harbour** can reach; the tile under the cursor is the candidate |
| **Left release over a sendable tile** | `battle.launch(boat, tile)` |
| Left release anywhere else | cancel — the boat's icon shakes, exactly as a refused key does |
| **Left press elsewhere on the field** | **begin a camera pan** |
| Left drag, camera pan in progress | `cam_px -= motion / zoom` |
| **Wheel** | zoom about the cursor, clamped |
| Left click on a roster entry, in REWARD | bolt the beak on (unchanged) |
| Left click on the restart rect, in WON / LOST | fresh run (unchanged) |

**Both drags are left-drag, and what disambiguates them is where the press landed** — decided #4 and
decided #5 are both "drag", so one has to be qualified.

⚠ **The boat has TWO grab targets and that is deliberate.** The hull at its harbour is the direct
reading of decided #8 (*"내가 뭐를 보내는지도 보이고"*) and it is what a player will try first; the
HUD icon is the fallback for when the camera is zoomed in and the harbour is off-screen. **They are
two renderings of one object, not two controls** — the same drag, started either way.

⚠ **The overlay is per boat, because reach is per harbour** (3.4). Two boats sitting at different
harbours show different coasts, and on island 2 that difference is a whole shore.

⚠ **While the panel is up (`panel_view.panel_active()`) neither drag exists.** The panel is asked
first, as today.
⚠ **A hold (`_hold_sec > 0`) refuses every one of these at the one existing line in
`_unhandled_input`.** A drag in flight when a hold begins is cancelled.

⚠ **Correction, measured with positive and negative controls**: "mouse clicks cannot be driven through
`root.push_input()` headless" is **wrong**, and an earlier draft of this plan (and of `CLAUDE.md`) said
so. The real rule is **`in_local_coords` must be `true`**: `push_input(ev, true)` delivers intact — a
click sent at (900,300) reached a control at its own (100,100); the same click with `in_local_coords`
left `false` (or omitted) is what lands at (18000, 5720), because `Viewport.push_input` divides by the
stretch transform a second time in that mode. `DisplayServer.window_get_size()` reports (0,0) headless,
not 64×64; the 0.05 transform is real, only the "divides once or twice" half of the old claim was
backwards. ⇒ **Stage 4's drag suite should drive real clicks through `root.push_input(ev, true)` —
the engine's own hit test — rather than calling `game._unhandled_input(ev)` by hand**, which is
strictly weaker: a hand call bypasses whatever the tree (the panel, a control eating the event) would
have swallowed first. `InputEventMouseMotion` and the button *release* both have to be built and
pushed too — a drag suite that only pushes presses is half a suite.

---

## 7. The screen

### 7.1 The camera — **one transform, in one place**

⚠ **There is still no `Camera2D`.** `field_view` carries the whole transform itself:

```
field_view.scale    = Vector2(zoom, zoom)
field_view.position = -cam_px * zoom + shake_offset()
screen_to_world_px(at) = (at - field_view.position) / zoom
```

⇒ **The pan, the zoom and the shake compose in exactly one expression**, and every screen→world
conversion goes through the one function beside it. `game.gd`'s own comment predicted the alternative:
*"Add one and this line is wrong everywhere on screen at once"*, and `field_view.position` was
**already** a second offset on the same axis. Two composition points is the same bug shipped twice.

⚠ **`hud_view` and `panel_view` are siblings, not children**, so every absolute rectangle in
`look.gd`'s HUD and panel sections is untouched by the camera. That is why they stay `Node2D`s.

| Constant | Value | Both ends |
|---|---|---|
| `ZOOM_MIN` | **0.5625** | ≤ 0.5625 or the whole map does not fit (1280/1920 = 0.667 is too big); ≥ 0.4 or a 14 px body is under 6 px |
| `ZOOM_MAX` | **1.0** | ≥ 1.0 (one tile = 40 px, today's scale) and ≤ 1.5 |
| `ZOOM_STEP` | **1.15** per notch | > 1.05 or a notch does nothing; < 1.4 or two notches cross the range |
| `WATER_MARGIN_TILES` | **1 → 5** | At `ZOOM_MIN` the visible world is 2275 px wide against a 1920 px map: **4.45 tiles of bare ground on each side.** ≥ 5, and ≤ 8 (2436 tiles painted at 5; 58×42) |

**The clamp**: `cam_px` is clamped per axis to `[0, map_px - viewport_px / zoom]`; when the map is
narrower than the visible world on an axis (every zoom below 0.667 horizontally) it is **centred** on
that axis instead. **Zoom keeps the world point under the cursor fixed**:
`position' = at - (at - position) * zoom' / zoom`, then re-clamp.

### 7.2 The presentation items — planned with the rules, shipped in the same stages

| # | Item | Stage | Where |
|---|---|---|---|
| P1 | **Pan and zoom move the field**, and the water margin covers every exposed edge | 3 | `field_view` |
| P2 | **A hull sits at every harbour a boat is at**, drawn from that boat's capacity — big 124 px wide, fast 72 px, both wider than a 40 px tile and unmistakable from each other. **Two boats at one harbour are offset by boat index** so neither hides the other | 5 | `_paint_hull` |
| P3 | **Every passenger is drawn on deck, with its HP bar**, at its own body radius | 5 | `_paint_body` · `_paint_hp`, reused |
| P4 | **TRANSIT bodies are drawn at all** — so the flash, the flinch and the HP bar finally paint at sea. ⚠ The tracer already flies to the boat and the target line is already drawn out to it; **the only missing half was the body** | 5 | `field_view` layer 6 |
| P5 | **A destination marker for the whole crossing** — a ring on the target tile and a route line from the hull to it | 5 | `_paint_ring` · `_paint_route` |
| P6 | ⚠ **The return leg is drawn** — the empty hull sails from where it unloaded to its new harbour. **Without it the fleet teleports and the player never learns the rule that 4.3 exists to create**; it is also why `berth_free_in` can be deleted | 5 | `field_view` |
| P7 | **A boat that arrived and cannot unload is drawn waiting** — the hull carries a mark for as long as it waits, so the stall of 미정 11 can never be silent | 5 | `_paint_hull` colour |
| P8 | **The drag overlay** — every tile *that boat's harbour* can reach is tinted, the candidate is ringed in the accept colour, a non-sendable candidate in the refuse colour, and the route is drawn from that harbour | 4 | `_paint_overlay` |
| P9 | **One HUD icon per boat**, showing its own capacity, its load, and whether it is at a harbour or at sea | 4 | `hud_view` |
| P10 | **Cliff and ramp read as themselves** — their own fills, plus a face line along a cliff tile's seaward edge so height reads in 2D | 5 | `_paint_cliff_face` |

⚠ **P4 is a two-line fix, not a feature**, and it is the one the design doc calls out: *"「배가 깎여서
도착한다」는 규칙으로 일어나고 화면에 안 나온다."*
⚠ **P6 is the one that would be easiest to skip and the most expensive to skip.** The relocation is a
rule that changes state; a rule that changes state has something on screen saying it happened.

⚠ **Every new number below is a first value to be re-measured by eye**, exactly as `look.gd`'s combat
section says of its forty-four. **The 2.0 canvas-px floor on any amplitude still binds** — and note it
is a floor in *world* px now, so at `ZOOM_MIN` a 2.0 px motion reaches the glass at 1.1 px. Anything
that must read while zoomed out is specified at 4.0.

| Constant | Value | Floor | Ceiling |
|---|---|---|---|
| `BOAT_SLOT_PX` | 26.0 | ≥ 24 (a 14 px melee body plus air) | ≤ 40 (a 4-slot hull must stay under 3.5 tiles) |
| `BOAT_HULL_PAD_PX` | 10.0 | ≥ 4 (a visible gunwale) | ≤ 20 |
| `BOAT_HULL_H_PX` | 56.0 | > 40 (**taller than a tile** — decided #8) | ≤ 80 |
| `HULL_BERTH_OFFSET_PX` | 30.0 | ≥ 28 (two hulls at one harbour must not overlap) | ≤ 60 |
| `ROUTE_WIDTH_PX` | 3.0 | ≥ 2 (the snap floor) | ≤ 6 |
| `TARGET_RING_R_PX` | 18.0 | ≥ 12 | ≤ 20 (two adjacent rings must not overlap) |
| `DROP_TINT_ALPHA` | 0.18 | > 0.06 or the tint is invisible | < 0.4 or the terrain under it is not |
| `CLIFF_FACE_WIDTH_PX` | 4.0 | ≥ 3 (it has to read at `ZOOM_MIN`, where it is 2.25 px) | ≤ 8 |
| `HULL_WAIT_BLINK_SEC` | 0.5 | ≥ 0.3 (a blink under 5 frames is unseen) | ≤ 1.0 |

New colours, all in `look.gd`: `COL_CLIFF` · `COL_CLIFF_FACE` · `COL_RAMP` · `COL_HARBOUR` ·
`COL_SENDABLE` · `COL_DROP_OK` · `COL_DROP_NO` · `COL_ROUTE` · `COL_HULL_WAIT`.
⚠ **`COL_DROP_OK` / `COL_DROP_NO` deliberately reuse `COL_WIN` / `COL_LOSE`** — the same accept and
refuse pair the key boxes already use. One concept, one value.

### 7.3 The hook table moves — `net_draw_leaf._table()` is the authority

`field_view.gd` gains, all with their `draw_*` counts pinned:

| Function | draws | Note |
|---|---|---|
| `_paint_hull` | 2 | the hull rect and its outline; the wait state is a **colour**, not a third call |
| `_paint_overlay` | 1 | one tinted rect per sendable tile |
| `_paint_cliff_face` | 1 | a line along the tile's seaward edge |
| `_paint_route` | 1 | harbour → candidate while dragging, hull → target while crossing |
| `screen_to_world_px` · `world_to_tile` · `pan_by` · `zoom_at` · `_clamp_cam` · `_visible_world_rect` · `_hull_rect` · `_deck_slots` · `set_drag` | 0 | camera and geometry are pure; **0 is as load-bearing as a leaf's count** |
| `_paint_boat` | — | **deleted**, replaced by `_paint_hull` |

⚠ **The table is CLOSED**: any `func` in a view file the table does not name is red. **The totals at
the bottom of `net_draw_leaf` must move with it** — today `68` functions and `20` leaves, written out
as literals precisely so a silent addition cannot slip through. **Recount them; do not derive them.**
⚠ **`hud_view.gd` also gains functions** (per-boat icons) and its row must grow too.

---

## 8. Nets — **eleven, and every check names its mutation**

The wrapper reds below five. Today's round is 9 nets / 725 checks / 2.2 s; this adds two.

⚠ **The last plan named 22 checks and the build needed 293.** The table below names the *shapes*, and
each row names a mutation as `file · exact string · which labelled check must redden`. **A check with
no named mutation is not on this list on purpose** — write it, then invert it, then add it.

### 8.1 `net_coast` — NEW. Landability, the straight line, and the returning rule

Hand-built fixtures only; nothing here reads an island.

| Check | Mutation that must redden it |
|---|---|
| land orthogonally beside water is landable | `grid.gd` · drop the `passable[t] == 1` test → `물이 아닌 칸이 상륙지가 됐다` |
| **a diagonal-only touch is NOT landable** | `grid.gd` · use `Grid.NEIGHBOURS` for the adjacency → `대각선으로만 물에 닿은 칸은 상륙지가 아니다` |
| a cliff coast is not landable, **and the land behind it is not either** | `grid.gd` · move `^` into `LAND_CHARS` → both labels |
| a ramp in a cliff wall is passable and is landable when it touches water | `grid.gd` · remove `/` from `LAND_CHARS` → `램프는 걸을 수 있다` |
| the straight line refuses a target behind a headland | `grid.gd` · delete the `water_line_clear` call in `can_land_at` → `곶 뒤의 해안은 못 보낸다` |
| **the adjacent-tile exemption**: a shallow approach to the beach beside another beach is ACCEPTED | `grid.gd` · delete the Chebyshev-1 exemption → `옆 모래를 스치는 항로는 거절하지 않는다` |
| the sampler cannot step over a one-tile wall | `grid.gd` · change the 0.05 step to 1.0 → `한 칸짜리 벽을 건너뛰지 않는다` |
| **reach is per harbour**: a fixture with two harbours where a tile is sendable from one and not the other | `grid.gd` · collapse `sendable` to one array → `항구마다 보낼 수 있는 해안이 다르다` |
| **the start harbour is the one farthest from its own reachable coast**, on a fixture where that is NOT index 0 and NOT the last | `grid.gd` · `start_harbour = 0` → `함대는 해안에서 가장 먼 항구에서 시작한다` |
| **`home_harbour_for` never strands a beachhead** — the fixture where the *nearest* harbour cannot see the landing | `battle.gd`/`grid.gd` · drop the `can_land_at(h, landing)` filter → `배는 자기가 내려준 해안을 다시 볼 수 있는 항구로 돌아간다` |
| `home_harbour_for` still picks the NEAREST among those that qualify | `grid.gd` · return the first qualifying harbour → `그 중에서는 가장 가까운 항구다` |
| `sendable` is filled by `load_rows` and `line_tests` does not move afterwards | `grid.gd` · make `can_land_at` call `water_line_clear` directly → `항로 검사는 섬마다 한 번만 돈다` |
| **a grid with no `H` at all**: `start_harbour == -1`, `can_land_at` false everywhere, no error | `grid.gd` · index `harbour_tiles[0]` unguarded → `항구가 없는 격자는 조용히 아무 데도 못 보낸다` |
| **the scanner's own failing cases** — a fixture that must be landable, one that must not, one line that must clear and one that must not | if any stops biting, everything above goes green on an empty tree |

### 8.2 `net_camera` — NEW. One transform, and it is the only one

| Check | Mutation |
|---|---|
| `screen_to_world_px` round-trips at zoom 0.5625, 0.75 and 1.0, and at two pans | `field_view.gd` · drop the `/ zoom` → `줌 0.75에서 화면 좌표가 월드로 되돌아온다` |
| **the shake is inside the same expression** — a shaken frame's conversion is still exact | `field_view.gd` · `position = -cam_px * zoom` → `흔들리는 프레임에도 클릭이 같은 칸을 가리킨다` |
| **the world point under the cursor does not move across a zoom notch** (< 0.01 px) | `field_view.gd` · `zoom_at` ignores its `at` → `줌은 커서 밑의 점을 붙잡는다` |
| at `ZOOM_MIN` the whole map is inside the visible world rect | `look.gd` · `ZOOM_MIN := 0.7` → `가장 멀리서 섬 전체가 보인다` |
| at every zoom the painted area (map + margin) covers the viewport | `look.gd` · `WATER_MARGIN_TILES := 1` → `줌 아웃해도 맨바닥이 안 드러난다` |
| the clamp holds: pan hard in all four directions, the visible rect never leaves map+margin | `field_view.gd` · delete `_clamp_cam()` → `아무리 밀어도 지도 밖으로 못 나간다` |
| **both ends of `ZOOM_MIN`, `ZOOM_MAX` and `ZOOM_STEP`** | each constant, both directions → six labels |

⚠ **A ceiling with no floor passes an effect that never happens.** *"the pan never leaves the map"* is
satisfied by a pan that does not move; **every clamp check is paired with one asserting the camera
really moved**, in the same row of the net.

### 8.3 `net_boat` — rewritten

| Check | Mutation |
|---|---|
| **capacities 4 and 2, written as literals** | `rules.gd` · `["FAST", 3, 5.0]` → `빠른 배는 둘까지만 태운다` |
| **`2 × 5.0 < 4 × 3.0`, both sides written out** | `rules.gd` · `["FAST", 2, 6.0]` (the exact tie the doc forbids) → `빠른 배는 처리량에서 진다` |
| crossing time is `distance / speed`: two targets at measured distances from one harbour, and the **ratio** of arrival times equals the ratio of distances | `battle.gd` · `f = t * speed / 12.0` → `먼 해안일수록 오래 걸린다` |
| the fast boat arrives first over the same route | `rules.gd` · equal speeds → `빠른 배가 먼저 닿는다` |
| **the boat leaves from `boat_at`, not from a fixed tile** — launch, land, then launch again and measure the second crossing from the NEW harbour | `battle.gd` · `from = harbour_tile(start_harbour)` → `두 번째 배는 옮겨간 항구에서 출발한다` |
| **the return leg is simulated**: after unloading the boat is still in `boats` with `phase == RETURNING`, its cargo empty, and it arrives at `home_harbour_for(landing)` | `battle.gd` · remove the boat on unload → `내려놓은 배는 빈 채로 항구까지 돌아간다` |
| **a boat is loadable and draggable exactly when it is not in `boats`** — refused one frame before the return completes, accepted on it, **for each boat separately** | `battle.gd` · mark it home on unload → `큰 배는 돌아온 뒤에야 다시 나간다` and its fast twin |
| `boat_at` really moves, and only on arrival | `battle.gd` · set `boat_at` at launch → `항구는 도착할 때 바뀐다` |
| `launch` refuses: an empty boat · a boat at sea · a non-landable tile · a tile this boat's harbour cannot see · an out-of-range boat index | one per clause → five labels |
| **a tile sendable from harbour A and not from B is refused for the boat sitting at B** | `battle.gd` · use `start_harbour` in the check → `배마다 보낼 수 있는 해안이 다르다` |
| **per-boat pending is independent** — loading four then two leaves 4 and 2, not 6 in one place | `battle.gd` · share one array → `두 배의 화물은 서로 섞이지 않는다` |
| `load_soldier` returns **which** boat, big first, and -1 when both are at sea | `battle.gd` · drop the at-sea test → `바다에 나간 배에는 못 태운다` |
| unload places the first soldier on the **target** tile, the rest breadth-first | `battle.gd` · `_free_tiles_from(harbour…)` → `첫 병사가 고른 칸을 차지한다` |
| the whole boat waits when the shore is short (the cove fixture, at cap 4 and cap 2 — **asymmetric on purpose**) | `battle.gd` · land the part that fits → `빈 칸이 모자라면 아무도 안 내린다` |
| cargo rides the boat's coordinate and cannot shoot back | unchanged from today |

### 8.4 `net_islands` — rewritten

Shape **32 × 48** · legend `~H.#^/BCL` only · **exactly three `H` per island, all on water** ·
**harbour tiles and the start harbour tile as literals** · per-harbour sendable counts
`[47,24,29] [38,23,21] [46,29,33]` · cut `[15, 2, 10]` · spawns `[4, 6, 5]` · coast `[82, 76, 80]` ·
wave-1 and steady-state crossing bounds · every sendable tile's region ≥ 4 tiles ·
**the game's own walker reaches every enemy from every sendable tile.**

⚠ **Cache the flow field per enemy, not per pair.** 704 pairs × a 1536-tile BFS is ~10M operations and
would put this net alone past the whole round's current 2.2 s. Fifteen fields, then 704 walks.
⚠ **Every literal above is written out.** `EXPECT_LIMITS` already carries the scar: a sweep put the
boss island on 5 seconds and **the whole round stayed green**, because the three checks that touched
the limits compared against the value's own source.
⚠ **The start harbour is index 2 on all three islands, so pinning the index proves nothing.** Pin the
tile, and let `net_coast`'s fixture prove the rule.

| Mutation | Label that must redden |
|---|---|
| `islands.gd` · replace one `^` of island 2's ridge with `.` (one column only) | **Does not redden anything — measured, not a working mutation.** Both ridge columns have exactly 2 passable tiles at every row, and the ridge sits on no water line, so opening a single column moves neither the cut nor any harbour's sendable count. See the two working replacements below |
| `islands.gd` · open island 2's ridge in **both** columns (22 and 23) at one row | `섬 2 의 최협 절단` (2 → 3) |
| `islands.gd` · shorten island 2's ridge sea leg — row 25, **both** columns `^^` → `~~` | `섬 2 의 항구 %d 에서 보낼 수 있는 해안 칸 수` (moves to `[23, 22, 39]`) |
| `islands.gd` · replace one `/` of island 3's west door with `^` | `섬 3 은 32행 x 48자다` does not fire (shape is unaffected) — **only the cut label fires**, `섬 3 의 최협 절단`. Sealing one west-door tile still leaves the other one open, and the walker survives on the east door alone regardless — `섬 3 — 배로 닿는 모든 해안에서 모든 적의 사거리 안까지 실제로 걸어간다` only reddens once **all four** ramp tiles (both tiles of both doors) are sealed, measured at 144 failing pairs |
| `islands.gd` · move island 2's east harbour one row down | `섬 2 의 항구 타일` |
| `islands.gd` · delete island 1's westmost `H` | `섬마다 항구는 셋이다` |
| `islands.gd` · delete one character from any row | `섬 %d 은 32행 x 48자다` |
| `islands.gd` · put a `,` in a row | `섬 %d 에 범례 밖 글자가 없다` (the existing bait, kept) |
| the walker fixture: a sealed enemy behind a wall | `벽 저쪽에 갇힌 적에게는 못 간다고 말한다` — the self-check, kept |

### 8.5 `net_shell` — the drag, driven for real

| Check | Mutation |
|---|---|
| press on the big boat's hull → motion → release on a sendable tile launches boat 0 to **that tile** | `game.gd` · release ignores the position → `놓은 칸으로 배가 간다` |
| the same gesture started on the HUD icon does the same thing | `game.gd` · drop the icon branch → `HUD 아이콘으로도 같은 배를 끌 수 있다` |
| release on a shadowed tile launches nothing **and the icon shakes** | `game.gd` · drop the cancel branch → two labels |
| **the overlay follows the dragged boat's harbour** — after a relocation the tinted set changes | `field_view.gd` · use `start_harbour` → `옮겨간 항구에서는 다른 해안이 뜬다` |
| press on the field pans; the same press on a hull does **not** | `game.gd` · route every press to the pan → `배를 누르면 카메라가 안 움직인다` |
| the wheel zooms, and a click after a zoom+pan still hits the tile the player sees | `game.gd` · use `event.position` raw → `줌하고 밀어도 누른 칸이 맞다` |
| terrain tiles drawn: **2436** (58 × 42), grid itself **1536** — both literals | `look.gd` · `WATER_MARGIN_TILES := 1` → `물 여백까지 2436칸이다` |
| **field rectangles land inside the MAP rect (0,0,1920,1280); HUD and panel rectangles inside the viewport** | `look.gd` · any layout function returning a bare `Rect2()` → the area half of `_rects_land_on_screen` |
| `grid.line_tests` is unchanged across 60 pumped frames | `field_view.gd` · call `can_land_at` per tile per frame → `항로 검사가 매 프레임 다시 안 돈다` |
| per-boat HUD text reads each boat's own load and capacity | `hud_view.gd` · read boat 0's cap for both → `2번 배가 자기 정원을 쓴다` |
| everything already there — three children, the two holds, the beak, the restart | unchanged |

⚠ **`_rects_land_on_screen` splitting into two rectangles is the subtle one.** Field rects are now in
world space, so the old single check would either fail everywhere or be widened to admit anything —
and widening it kills it for the HUD, which is what it was written for.

### 8.6 The rest

- **`net_draw_leaf`** — the new `_table()` rows, the new totals (recounted, not derived), and the
  existing seven scanner self-checks unchanged. **`src/view/` still holds exactly three files.**
- **`net_fx_view`** — TRANSIT bodies now paint, so the flash and the flinch at sea are assertable for
  the first time. ⚠ **Its tile-count expectation is currently written as `(Look.GRID_W + 2 *
  WATER_MARGIN_TILES) * (…)`, which derives its bound from the constants it checks. Make it a literal.**
- **`net_battle`** — only where it names `Rules.CROSSING`. The phase order, the reach table and the
  step contract do not move. **Add the pair from 4.7**: an approaching boat pulls no enemy into
  motion, *and* the enemies that should move are moving.
- **`net_run`**, **`net_fx`**, **`net_citations`** — touched where they name docks or the dead constants.

---

## 9. Acceptance

| Piece | Accepted when |
|---|---|
| **Survey** | Zoomed out, the whole island is on screen at once and the cliffs, ramps, harbours and enemies are readable **before the first boat leaves** |
| **The drag** | Dragging a boat shows which coast **that boat** can reach; releasing on a blocked stretch visibly refuses |
| **The fleet moves** | After a landing, the empty hull is seen sailing to a different harbour, and the next drag offers a different coast |
| **Two boats** | The big one is visibly bigger and visibly slower, and sending it costs a visibly longer wait |
| **The crossing is an event** | The passengers are visible aboard, their HP bars move when a crow fires, and the destination is on screen the whole way |
| **The whole army cannot go at once** | A roster of 10 goes out in **two waves**; "who are the first six" is live from the first click |
| **The same island, two ways** | Two runs landing at different beaches give **different casualties and duration** — the probe measures it (stage 6) |
| ⚠ **The verdict** | **The user does not say 「배가 곁다리다」 again.** Everything above is a proxy |

⚠ **None of these is accepted by an agent having walked through it, and none by a video existing.**
Acceptance is the user saying they saw it, written into `boat-invasion-ko.md` **and**
`boat-invasion.md` the moment it is heard.

---

## 10. Deliberately not in this round

Landing exposure · a cost for landing in a line · mid-crossing redirect (decided #10, a named TODO) ·
choosing which harbour a boat returns to · a third boat · a unit type that ignores cliffs · clifftop
watchers · elevation as a real axis · flying · loading a specific soldier onto a specific boat · fog ·
a map screen · `TIME_LIMITS`.

⚠ **`TIME_LIMITS` is on this list and that is decided #9, not an oversight.** Stage 6 measures; the
change is a separate decision with the user.
⚠ **"Choosing which harbour to return to" is on this list on purpose.** 4.3 derives it, which is what
keeps the gesture to one drag; making it a choice is a second control and a second decision, and it
can be added later without touching anything else.

---

## 11. Stage 6 — the probe, and the numbers it must print

`tools/probe/run_run.gd` needs the new API (`launch(boat, tile)`, per-boat `pending`, `boat_at`, no
`berth_free_in`) and one new policy **pair**.

⚠ **Confirmed the only file still on the dead API, with four breakages — two of them SILENT.** The
loud two are a straight parse-time failure on `launch(dock_index)` and on `berth_free_in`. The silent
pair, measured, are the ones stage 6 has to not walk back into by accident:
- `battle.pending.size()` used to be "how many soldiers are waiting to board" and still parses —
  `pending` is now an `Array` of one `PackedInt32Array` per boat, so `.size()` silently returns the
  BOAT COUNT instead, and any probe logic reading it as a cargo count is wrong with no error.
- `if battle.load_soldier(...)` used to read a `bool`; `load_soldier` now returns the boarded boat's
  index or `-1`. `if 0:` is falsy in GDScript, so **boat 0 boarding successfully reads as failure**,
  and only boat 1 (or later) reads as success — the exact inverse of what the probe needs to log.

| Policy | The number it has to produce |
|---|---|
| **Same island, two beaches** — identical roster, one run landing at the nearest bay, one at the far flank | **Different casualties and different duration.** If they match, the landing point is not a decision and the round bought a picture |
| **Land-beside-a-harbour vs land-where-the-enemy-is-not** | ⚠ **The 4.6 question.** Cheapest steady-state beach against the quietest beach. If the cheap one wins on both casualties and duration, "land next to a harbour" is dominant and the design doc's reopen condition has fired |
| Everything at once (kept) | Wins all three islands from full health, **inside the unchanged limits** |
| One boat at a time (kept) | Loses more HP than "everything", on every island |
| **Dead air**, `_input_open` (kept) | ⚠ **The number to watch.** A boat at sea can no longer be loaded (4.4), so the hand has less to press |

⚠ **The probe grades in its owner's favour unless it is inverted.** The existing must-lose run stays,
and the new pair needs its own: **two runs landing at the SAME beach must produce identical numbers**,
or the difference above is noise rather than the landing point.

⇒ **The output of stage 6 is a report, not an edit.** If policy 1 cannot win an island inside 60 s,
that is a finding for the user, and the design doc's *"짓고 나서 프로브 측정으로 다시 잡는다"* is where
it goes.

### 11-A. What stage 6 actually produced, and what it cut (2026-08-18)

**The five rows above were all produced. The numbers are in `boat-invasion` / `-ko`, section 1-A** —
they are not repeated here. Three things belong in this file rather than that one:

**① Three pre-boat probe policies were dropped, and it was the builder's call, flagged rather than
silent.** None of them appears in the table above, so none was required by this plan:

| Dropped | Why |
|---|---|
| **ranged-only** (first-slice policy 3) | a roster-composition question, untouched by this feature |
| **chipped-boss entry, plus its boss sweep** (first-slice policy 4 and its band sweep) | the lion's range is still 0 and that decision is still the user's; the sweep measured a band that does not exist yet |
| **the two-doors bait pair** (first-slice policy 5) | ⚠ **This one could not be translated.** It compared "two soldiers to the west dock, everyone else to the east" — **it is dock sequencing**, and with an open coastline there is no dock to sequence. Its question survives in the new same-island-two-beaches pair; its implementation does not |

⚠ **Recorded here because a silently deleted policy reads as a policy that passed.** The boss band in
particular was a first-slice row that failed **on purpose** and was kept failing rather than retired;
**dropping its sweep means nobody is watching it any more**, and that is a real loss, not a tidy-up.

**② One prediction in this plan was wrong.** Section 4.6 required the dribble policy to cost more on all
three islands, and it holds on **2 of 3** — on island 1 dribbling wins on casualties, damage *and* time.
⇒ **"Hoarding is free" is back on one island**, which is the shape the second game died of. It is written
into the design doc's 1-A rather than only here.

**③ Section 4.6's caveat was the right one and it resolved against the design.** That section ended
*"do not read this as proof"* about whether landing next to a harbour dominates. **Measured: it dominates
3 of 3.** The re-open condition in
[open coastline over fixed docks](../../decisions/open-coastline-over-fixed-docks.md) has fired, and that
doc now carries both the firing **and** the reason it is not being re-opened — the cause is the clock, not
the coastline, and reverting to 1-of-N docks would not touch it.

---

## 12. Documents that go false the day this ships

**Fix them in the same edit as the code**, and **Korean and English together** — a fact changed in one
and not the other means the next agent builds the old design.

| Doc / comment | What dies |
|---|---|
| `islands.gd` legend comment | *"`D` dock — the only tile a boat may be sent to"* |
| `field_view.gd` layer-6 comment | *"The boat IS the cargo on screen"* — the passengers are drawn now |
| `battle.gd` `FIELD_TTL` comment | *"the grid is 576 tiles… ~23k operations a second"* → 1536 and ~61k |
| `battle.gd` `launch` comment | *"The berth frees `2 * Rules.CROSSING` after this call"* — there is no berth |
| `rules.gd` `CROSSING` comment | *"the first thing to change if 「which dock」 turns out not to be a decision"* — it has been changed; the constant is gone |
| `hud_view.gd` header | *"The berth rectangle IS the resource meter"* — it is now a boat icon, and the empty harbour on the map is the other half |
| `look.gd` header | *"no camera zoom"*, and **every px comment is now "at zoom 1.0"** |
| `look.gd` shake section | *"THERE IS NO `Camera2D` … CAMERA_ZOOM stays unread"* — still no `Camera2D`, but the reason given (absolute dock rectangles) is dead |
| `game.gd` `_click_dock` | the whole function, and the comment that predicted this change |
| `boat-invasion.md` · `-ko` | `**Implemented**:`, the *"지금 돌아가는 것"* snapshot table (**the doc says itself it is deleted the day this is implemented**), and 미정 1–12, which this plan answers |
| `cell-army-gdd.md` · `-ko` | 미정 15 and 16 close; 미정 17 (2D or 3D) is re-judged on the new screen |
| `cell-army-gdd.md` · `-ko`, 「투입」 | *"2척 × 정원 5 = 10 = 시작 병력 전부다"*. **A wave is 4 + 2 = 6 now, so the starting roster takes two.** ⚠ **It appears TWICE in each twin** — once in 「투입」 and once inside a later refutation box — and re-measuring only the row someone is arguing about is this repo's named failure. ⚠ The design doc's section 6 already refuted it: **go and edit the GDD, not the doc you are standing in** |
| `cell-army-gdd.md` · `-ko`, 「화면 — 첫 판에 필요한 만큼만」 | the row *"선착장 — 해안의 특정 칸에 표시"* |
| `combat-juice.md` · `-ko` | its hook table, which restates `net_draw_leaf._table()` |

⚠ **`docs/plans/README.md` and `CLAUDE.md` are already updated** — do not edit them again for this.

---

## 13. Risk — what this can break silently

- **The camera breaks every screen-coordinate consumer at once.** The mitigation is that there is only
  one conversion function and the HUD and panel are outside the transform. **If a second conversion
  appears anywhere, that is the bug.**
- **`ashore_only` and `flow_field`.** Anything that lets an enemy chase a water tile freezes the whole
  island **with nothing logged.** 4.7.
- **A cached `sendable` that silently recomputes** costs 750k operations a frame and is invisible in
  every check but the counter. 3.5.
- ⚠ **A returning boat that is not drawn is a fleet that teleports.** The relocation rule is the whole
  of what plural harbours buy, and P6 is the only thing that tells the player it happened.
- ⚠ **`home_harbour_for` without its visibility filter strands beachheads** — measured at 2 of 46 on
  island 3, silently, ending in a timeout. 4.3.
- **A one-tile cliff wall leaks diagonally.** Island 2's ridge is two wide everywhere for this reason.
- **`net_draw_leaf`'s closed table.** Nine new functions in `field_view.gd`; miss one in the table and
  the round is red — which is the point — but **miss one in the totals and the class quietly reopens.**
- **The wave arithmetic depends on `START_MELEE + START_RANGED = 10` and caps 4 + 2 = 6.** Change any
  of the three and "two waves" stops being true; the design doc's section 6 is the only place that
  arithmetic lives.
- **Fake-code shapes to watch, from `CLAUDE.md`'s list**: a drag overlay whose predicate is not the one
  `launch` uses (screen changes, sim does not); a hull drawn at a harbour the sim does not think the
  boat is at; a "waiting" mark driven by a view-side timer rather than by the boat still being in
  `boats`.
