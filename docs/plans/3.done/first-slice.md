# Plan — the first slice: three islands, one run, end to end

**Status**: `3.done` — built, and the round is green (9 nets / 725 checks).
⚠ **`3.done` is implementation, not acceptance.** What the user has and has not confirmed on screen lives in
the design headers: the slice itself was played, and the twelve presentation items were accepted separately.
**Design**: [the cell army GDD](../../design/cell-army-gdd.md) (Korean: `cell-army-gdd-ko`).
**Presentation shipped on top of this**: [combat juice](../../design/combat-juice.md) (Korean: `combat-juice-ko`).
⚠ **That doc's hook table supersedes section 6 here.** The authority is `net_draw_leaf._table()`.

⚠ **Read the GDD section *"The remaining rules, filled in so the first slice can be built"* first.**
Everything here that is not a user quote is a **first value to be fixed by measuring**, not a truth.

⚠ **This was written when `src/` was empty**, so it builds the tree from nothing and satisfies the four
folder contracts in CLAUDE.md on day one rather than retrofitting them. **The tree exists now** — read this
as the record of how it was built, not as instructions to build it again.

**Goal, in the user's words**: *"keep it light and get the whole thing running."*

> ## ⚠⚠ Read this before anything else — **the probe is built first, and the view second**
>
> Two adversarial passes were run against this plan before it shipped. **Every defect either found was
> found by running a script, and none by rereading.** Between them they killed: the movement rule, the
> combat table (twice), what two of the three islands teach, and the claim that the boss can be lost.
>
> ⇒ **So the order is inverted from how this repo has always worked.** `src/sim/` and
> `tools/probe/run_run.gd` come **first**, and the numbers get closed by measurement **before a single line
> of `src/view/` is written.** Phase A produces no picture at all and that is correct.
>
> **This is also the answer to "why does building take nine rounds."** Rounds are expensive because a
> builder writes, a verifier finds it wrong, and the loop turns. **A probe closes the arithmetic in one
> pass, on the sim alone, with no view to rewrite.** Section 12 is the evidence: a Python script did in
> twenty minutes what three rounds of reading did not.

---

## 1. What ships

| | |
|---|---|
| Session | Straight-line map of **3 islands**, no branches, no chest, no elite |
| Islands | **grassland (bison) → grassland (bison + crow) → lion (boss)** |
| Soldier types | **2** — melee single-target, ranged area. Bound to keys **`1`** and **`2`** |
| Enemies | **3** — bison (melee), crow (ranged), lion (boss) |
| Specialty | **1** — the beak, range +1, awarded on island 2 |
| Artifacts · meta · unlocks | **none.** A run starts from the same state every time |
| Terrain | **one level.** No tiers, no ramps, no flying. `#` tiles are impassable holes |
| Lose | The island timer runs out, **or every soldier is dead** |
| Map screen | **cut.** Clearing an island goes straight to the next one — section 10 |

⚠ **"Every soldier is dead" is a second lose condition. It has been added to the GDD** (Undecided item 4),
because a plan is not where a rule gets decided.

---

## 2. Files

```
PHASE A — sim and probe. No Node, no picture.
  src/sim/rules.gd       every constant that changes what happens
  src/sim/grid.gd        tiles, passability, reservation, BFS flow field
  src/sim/islands.gd     the three islands, and their spawn/limit lookups
  src/sim/army.gd        the roster that survives islands (flat arrays)
  src/sim/battle.gd      one island's fight. step(dt) drives everything
  src/sim/run.gd         session state: which island, rewards, run over
  tools/probe/run_run.gd headless run-player. Section 11

PHASE B — the picture.
  src/look.gd            every presentation constant, and nothing else has one
  src/view/field_view.gd the island. Node2D. _draw() calls _paint_* hooks only
  src/view/hud_view.gd   timer, berths, key roster, enemies left
  src/view/panel_view.gd reward pick / win / lose / restart
  src/shell/game.gd      the only file that reads Input. Builds children in code
```

**`src/sim/` never touches the tree** — no `Node`, no `_draw`, no `Input`, no `get_node`, no `$`.
**`src/view/` reads sim and never writes it.** **`src/shell/` is the only `Input` reader.**

⚠ **`class_name` on a brand-new file is invisible to `--headless --script` until an `--import` pass.**
`run_nets.ps1` runs the import when it sees a `.gd` with no `.uid` beside it — **do not bypass that guard.**
⚠ **`const X := PackedInt32Array([...])` does not parse.** Every table is a plain `const` Array, and every
read casts (`int(...)`, `float(...)`).

---

## 3. Numbers

### 3.1 Screen and grid — pin these two together or the 4.8× error comes back

| | Value |
|---|---|
| Viewport | **1280 × 720**, and the window is not stretched |
| Camera zoom | **1.0.** There is no zoom in the first slice |
| Tile | **40 px on screen.** One tile = one grid cell = 40 px, no multiplier anywhere |
| Grid | **32 × 18 tiles** — exactly fills the viewport |

⚠ **Write the px value in the comment beside every ratio.** A radius of 8 was cited as "8px" and was
really 38px in the last game, and the same shape bit four times.

### 3.2 Distance and combat semantics — stated once, in tiles

- **All range and area values are in tiles**, centre to centre.
- **A unit may attack when `distance <= range + 1.5`.** Range 0 therefore means "any of the eight
  neighbours". ⚠ **`+1.0` was the first draft and it excluded diagonals** (1.414 > 1.0), which capped melee
  at four attackers per target and quietly killed the lion's area attack — section 12.7.
- **Compare with an epsilon of `1e-4`.** A diagonal is exactly 1.41421…; a bare `<=` on a float boundary is
  a coin flip.
- **A unit stops moving as soon as its target is in range.** Without this line a range-4 soldier walks into
  melee and the ranged type does not exist. **This one rule changes island 3's damage taken by 30%.**
- **`area > 0`** also damages every other **enemy of the attacker** within `area` of the primary target.
  **No friendly fire.**
- **Targeting is nearest-first**, recomputed when the target dies or leaves range.
- **Soldiers in transit on a boat are excluded from enemy *movement* targeting, and can still be shot.**
  Without the exclusion an enemy targets a soldier standing on water, `flow_field` is asked for a path to
  an impassable tile, and every enemy freezes.

### 3.3 The unit table — `rules.gd`

Columns: `name · max_hp · damage · attack_period(s) · range · area · speed(tiles/s) · detect(tiles)`

| id | name | hp | dmg | period | range | area | speed | detect |
|---|---|---|---|---|---|---|---|---|
| 0 | `CELL_MELEE` | 14 | 2.0 | 1.0 | 0 | 0 | 4.0 | — |
| 1 | `CELL_RANGED` | 8 | 1.5 | 1.0 | 4 | 1.0 | 4.0 | — |
| 2 | `BISON` | 20 | 3.0 | 2.0 | 0 | 0 | 2.5 | **6** |
| 3 | `CROW` | 6 | 1.5 | 1.0 | 3 | 0 | 6.0 | 12 |
| 4 | `LION` | **140** | **4.0** | 1.5 | 0 | **1.5** | 2.5 | **2** |

**Soldiers have no detect radius** — they always advance on the nearest enemy.
**Body radius is not in this table.** It changes nothing about what happens, so it lives in `look.gd` —
section 6. It was here in the first draft and that violated the one-file rule.

⚠ **The lion's row is a guess and Phase A exists to replace it.** At 50 HP the boss was **unlosable with
every soldier on 1 HP** (section 12.7). 140/4.0/1.5 is a starting point aimed at the band in section 11,
**not a measured value.**

### 3.4 The run

| | Value |
|---|---|
| Starting force | **10** — **6 `CELL_MELEE` + 4 `CELL_RANGED`** |
| Island 1 reward | **+3 soldiers** (2 melee + 1 ranged), **at full HP** |
| Island 2 reward | **the beak** — the player clicks one surviving soldier |
| Island 3 | boss. No reward. Clearing it ends the run |
| Time limits | **60 s · 60 s · 90 s**, and the clock starts **when the island opens**, not on first landing |
| HP carryover | **Yes, exactly as it stands.** No healing anywhere |
| Death | **Permanent.** `alive` goes to 0 and the row stays |
| After the run | **A restart button.** The next run starts from the identical state |

**The beak**: `range += 1.0`. **No +1 HP** — that candidate is unadopted, and the slice is where we learn
whether "who do I bolt it onto" is a decision.

⚠ **The beak raises the effective contact width.** Range 1 means the second rank attacks, so a `w`-wide
front becomes `w × 2` — the GDD now carries this. **It is the boss's answer and the terrain's undoing in
one line.**

### 3.5 The boats

| | Value |
|---|---|
| Fleet | **2** |
| Capacity | **5 per boat** |
| Launch | **On the dock click.** Not on a timer |
| Crossing | **3.0 s each way**, constant. Round trip 6.0 s, then that berth frees |
| Where a boat comes from | **the water tile on the map border nearest the chosen dock** |

⚠ **"A port at (16,17)" was the first draft and it sent boats across dry land** — 58–77% of the straight
line was over land on all three islands. Spawning at the nearest border water fixes it without a pathing
rule, and it puts the boat where a coastal enemy can reach it.

**One deployment**: press `1`/`2` to load (up to 5), then **click a dock** to launch.
**Who boards**: the **highest-HP living soldier of that type that is still in reserve** — not yet landed
on this island, and not already aboard. **A soldier that has landed cannot be re-boarded.**
⚠ **The first draft wrote "ashore" here and in the input table, which says the exact opposite of the
sentence beside it.** Clicking with an empty boat, or with no berth free, does
nothing. **Loading is allowed while both boats are at sea**; the load goes out on whichever returns first,
and only on a click.

**Unloading**: the first soldier takes the dock tile, the rest take the **nearest free passable tiles by
BFS from it**, in load order. **If fewer free tiles are available than the boat is carrying, it waits at the dock** until they are.

⚠ **A constant crossing means the far dock is free.** Deliberate, and the first thing to change if "which
dock" turns out not to be a decision.

---

## 4. The islands — `islands.gd`

**Format**: each island is a `const` Array of **18 strings of exactly 32 characters**.

| Char | Means |
|---|---|
| `~` | water — impassable, not landable |
| `.` | land |
| `#` | hole — impassable land |
| `D` | dock — land, and the only tile a boat may be sent to |
| `B` `C` `L` | land, with a bison / crow / lion starting there |

**Dock index** = the order a `D` is met scanning **row-major, top-left first**. `battle.launch(0)` is the
first `D` in that order.

**"Narrowest cut" means: for each column `x`, count the passable tiles in it; take the minimum over all
columns that have at least one.** Nothing more — it is a number a net can compute in four lines and cannot
get subtly wrong.
⚠ **The first draft used the phrase with no definition at all, and its numbers were true under no single
reading** — section 12.8. **A minimum vertex cut was the second attempt and was dropped**: it is the more
correct notion and it is a max-flow, which means the net would carry a second implementation of a graph
algorithm and start measuring itself.

⚠ **All three grids are machine-checked** by `net_islands`: 18 rows, 32 columns, legend-only characters,
every dock adjacent to water, and **the game's own walker** (`grid.flow_field` + `grid.step_toward`)
reaching every enemy from every dock.

### Island 1 — open grassland, 2 docks, 4 bison. Narrowest cut **9**

```
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~............................~~
~~............................~~
~~............####............~~
~~............####............~~
~~..........B......B..........~~
~~............................~~
~~D..........................D~~
~~............................~~
~~..........B......B..........~~
~~............####............~~
~~............####............~~
~~............................~~
~~............................~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

**What it teaches**: nothing constrains you. **Sending everyone is correct here** — it is the baseline the
next island is measured against.

### Island 2 — a wall with a 2-tile neck. Narrowest cut **2**

```
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~.............##.............~~
~~.............##.............~~
~~..C..........##.........C...~~
~~.............##.............~~
~~D............##.............~~
~~.............##.B...........~~
~~............................~~
~~.................B..........~~
~~.............##.B...........~~
~~D............##.............~~
~~.............##.B...........~~
~~.............##.............~~
~~.............##.............~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

Docks `(2,6)` `(2,11)`. Wall at columns 15–16, **open on rows 8 and 9 only**.
Enemies: crow `(4,4)` west of the wall; **four bison at `(18,7)` `(19,9)` `(18,10)` `(18,12)`, parked just
east of the neck**, and a crow at `(26,4)`.

⚠ **The garrison went from two bison to four, and the bison's detect landed on 6 after going to 3 and
back, and all of it is measured.** At detect 8 from column 21 the bison walked out through the neck one at a time and were
surrounded. Moving them to column 26 fixed that and **broke it a second way**: the fight then happened five
columns east of the neck, which had nothing to do with anything. **And position was never the problem** —
two bison are 46 HP and 4.5 DPS against thirteen soldiers' 23.5 DPS, **a five-fold gap no terrain can
close.** ⇒ **A bottleneck only bites if the garrison can trade with the width of the front.**

✓ **With four bison at column 18–19 it now bites, and here are the numbers.** Island 2, 13 soldiers:

| policy | damage taken | deaths | result |
|---|---|---|---|
| all thirteen, both boats | **43.5** | 1 | won in 16.5 s |
| three only | 46.5 | 3 | **timed out, then wiped** |
| one boat at a time | **123.0** | 6 | won in 35.5 s |
| ranged only (5) | **19.5** | 0 | won |
| melee only (8) | **108.0** | 6 | won, on 13 HP |

**Dribbling costs 2.8× and melee-only costs 5.5× what ranged-only does.** Both of the island's stated
lessons are now true by measurement rather than by assertion.

⚠ **Detect 3 was tried first and gave the bison a blind spot**: a soldier's reach is 5.5, so at detect 3
**a bison can never notice a ranged soldier at all** — four ranged cleared island 1 taking **zero damage**.
**Detect 6 closes that free win (36 damage), still bites at the neck, and punishes dribbling harder.**

⚠ **The crow at `(4,4)` is the only enemy in the slice that can shoot a boat**, and its position is
measured, not eyeballed: the boat for dock `(2,6)` comes from border water `(0,6)`, and `(4,4)` is 2.8
tiles from the dock — inside `3 + 1.5`. **The first draft put it at `(8,3)`, which was 6.1 tiles away and
could never fire.** The plan claimed the fix was in without measuring it.

**What it teaches** — ⚠ **not what the first draft said.** It said *"the first island where sending
everyone is wrong."* **That is false**: with the contact cap binding both sides, 13 committed and 3
committed take identical damage. The queue is free.

- **Dribbling costs, and this one is measured.** Committing all 13 takes **21 damage**; sending 3 takes
  **30 and one death**; feeding one boat at a time takes **31.5**. Fewer soldiers → less DPS → a longer
  fight → more damage, because enemy DPS is a rate
- **Composition matters at a neck.** Melee is capped by the width; ranged shoots over the queue uncapped
⚠ **"13 committed and 3 committed take identical damage" was written here and it is false** — measured
21 against 30. It came from a theoretical cap that the real geometry does not reproduce.

### Island 3 — a small ring with two 3-tile doorways. Narrowest cut **9**

```
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~............................~~
~~............................~~
~~............................~~
~~.........########...........~~
~~.........#..C...#...........~~
~~............................~~
~~D...........L..............D~~
~~........................C...~~
~~.........#..B...#...........~~
~~.........########...........~~
~~............................~~
~~..........B.................~~
~~...........................,~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

Docks `(2,8)` `(29,8)`. Ring walls: rows 5 and 11 across columns 11–18; columns 11 and 18 closed on rows
6 and 10; **both open on rows 7, 8, 9 — two 3-tile doorways, one per side.**
Inside: crow `(14,6)`, lion `(14,8)`, bison `(14,10)`. Outside: bison `(12,13)`, crow `(26,9)`.

⚠ **The ring interior went from 56 tiles to 30**, because at 56 the soldiers simply walked in and
surrounded the lion — **eight attackers on it by t=12.5 s, and the doorway was a corridor, not a front.**
⚠ **The outer crow moved to `(26,9)` so it can shoot a boat arriving at the east dock**, the way `(4,4)`
does on island 2. It is 3.2 tiles from that dock, inside a crow's 4.5 reach.

⚠ **The right doorway is new.** With only the left one, the east dock took **68.7 s of a 90 s limit** just
to walk around the ring — a hidden timeout trap nothing in the plan mentioned. Two doorways also make the
dock choice symmetric, **and they are the only place in the slice where pulling can be tried**: hold them
at one door, come in the other.

⚠ **The lion's detect is 2.** At 6 it walked out of its own ring by t=6.0 s and the fight happened on open
ground, so the doorway never became a front and **the beak's whole reason to exist never occurred.**

⚠ **Row 14 ends in a `,` — deliberate bait for `net_islands`.** Fix it to `.` in `islands.gd` **only after
confirming the net reddens on it.**

**What it teaches**: the boss is decided by **how much HP arrived**, and by whether the beak lets a second
rank reach through a doorway.

---

## 5. The sim — shapes and entry points

### `grid.gd`

```
var w: int, h: int
var passable: PackedByteArray          # w*h
var dock_tiles: PackedInt32Array       # in row-major order — this defines dock_index
var reserved: PackedInt32Array         # tile -> unit id, or -1
func load_rows(rows: Array) -> void
func is_passable(tx: int, ty: int) -> bool
func flow_field(target_tile: int) -> PackedInt32Array
func step_toward(unit_id: int, from: Vector2, field: PackedInt32Array) -> Vector2
func release_all(unit_id: int) -> void
```

**Movement is a BFS flow field.** `flow_field` breadth-first-searches from the target tile over passable
tiles, **8-way**, and **treats reserved tiles as passable** — otherwise a field would have to be rebuilt
whenever anybody moved. `step_toward` moves to the neighbour with the lowest field value that is passable
**and unreserved**, reserves it, releases the tile behind, and returns the point to walk toward.
**If every candidate is taken, return the current position** — the unit stands.

**Reservation lifetime**: a unit holds **at most two tiles** — the one it stands on and the one it is
walking into — and `step_toward` is what swaps them. `release_all(unit_id)` on death or on boarding.
**Enemies reserve tiles exactly as soldiers do**, or a soldier walks through a bison.

A field is rebuilt **when a unit's target changes, and at most every 0.5 s**; the cache lives on `battle`,
keyed by target tile, cleared each rebuild window. The grid is 576 tiles, so one BFS is ~576 operations —
twenty units at 2 Hz is ~23k operations a second. **The engine was never the wall.**

⚠ **Greedy 8-way descent was the first draft and it is broken.** Run against these grids it stalls on
**five of twenty-six dock→enemy pairs** — both island 2 docks to the north-east crow, and the island 3 east
dock to everything inside the ring. **Flood-fill connectivity does not prove reachability under a movement
rule**, which is why `net_islands` drives the real functions above.

### `islands.gd`

```
const ISLAND_ROWS: Array   # 3 entries, each 18 strings
const TIME_LIMITS: Array   # [60.0, 60.0, 90.0]
func rows_of(i: int) -> Array
func spawns_of(i: int) -> Array      # [{type_id, tile}]
func time_limit_of(i: int) -> float
func count() -> int
```

### `army.gd`

```
var type_id: PackedInt32Array
var hp: PackedFloat32Array
var has_beak: PackedByteArray
var alive: PackedByteArray
func add(type_id: int) -> int          # added at full HP
func kill(i: int) -> void
func living_ids_of_type(t: int) -> Array     # sorted by hp, descending
func range_of(i: int) -> float               # base + 1.0 if has_beak
func living_count() -> int
```

**A dead soldier's row stays and `alive` goes to 0.** Nothing has to remember to drop anything — the same
shape the old swarm's `carried[i]` had, and the reason it was structurally correct.

### `battle.gd`

```
enum Outcome { RUNNING, WON, LOST }
func setup(grid, army, spawns: Array, time_limit: float) -> void
func load_soldier(type_id: int) -> bool
func launch(dock_index: int) -> bool
func step(dt: float) -> void
func outcome() -> int
func enemies_left() -> int
```

**`step(dt)` order, and it is a contract**: boats → landings → targeting → movement → attacks → deaths →
timer. **A net measures the order, not only the final state.**

### `run.gd`

```
enum State { BATTLE, REWARD, WON, LOST }
enum Reward { NONE, COUNT, BEAK }
var island_index: int
var army: Army
func begin_island() -> Battle
func finish_island(won: bool) -> void
func pending_reward() -> int
func apply_beak(soldier_id: int) -> void
func take_count_reward() -> void
func restart() -> void
func state() -> int
```

**Island 1's reward has nothing to click**, so `finish_island(true)` applies it and goes straight to the
next island. **Only the beak opens a REWARD state.**

---

## 6. The view

**Every drawing file exposes `_paint_*` hooks and `_draw()` calls nothing else**, so a net can override the
hook and assert the arguments.

| File | Hooks | `draw_*` calls in each |
|---|---|---|
| `field_view.gd` | `_paint_tile` · `_paint_dock` · `_paint_body` · `_paint_beak` · `_paint_hp` · `_paint_boat` | 2 · 1 · 2 · 1 · 2 · 1 |
| `hud_view.gd` | `_paint_timer` · `_paint_berth` · `_paint_load` · `_paint_key` · `_paint_enemies_left` | 1 · 1 · 1 · 2 · 1 |
| `panel_view.gd` | `_paint_panel` · `_paint_message` · `_paint_roster_entry` · `_paint_button` | 1 · 2 · 2 · 2 |

⚠ **This table is NOT the authority and must not be treated as one — `net_draw_leaf`'s `_table()` is.**
**It was rotted for as long as it existed**: the `hud_view.gd` row omitted `_paint_load` and the `panel_view.gd`
row omitted `_paint_message`, both of which the code and the net have always carried. It was found on
2026-08-17 while writing the combat-juice doc, which restates the same table a third time — **and a table
living in three places diverges three times.** ⇒ **Read the counts off `net_draw_leaf._table()`. When juice
lands, that function and the combat-juice doc move together and this row set stays as history.**

⚠ **All three view files are in the table, and that is the point.** The first draft listed two and left
`panel_view` outside — **that is the exact hole that shipped a bare `draw_circle` under 1414 green checks
and again under 1889.**

⚠ **`_paint_tile` is 2, not 1, and `_paint_dock` exists at all, because the GDD's screen section asks the
tile layer for three things** — a faint grid, three terrain colours, and a dock marker. **One draw call
cannot deliver them**, and a table that says 1 would have made the screen spec unbuildable while the net
stayed green about it.

**Everything a leaf is handed must be used in its body**, and `net_draw_leaf` asserts it — a
`draw_circle(p, 0.0, col)` once turned forty rocks invisible with the round green.

**Every colour and every pixel constant lives in `look.gd`**, including **the body radius per unit type**
(a ratio of 0.35 is **14 px** at a 40 px tile).

**`panel_view` is a `Node2D`, not a `Control`.** It draws its own rectangles and reports hit-rects to the
shell; **it does not own a `Button`**, because a `Control` with `set_anchors_preset` and untouched offsets
keeps `size == (0,0)` and piles into the corner while every check about it passes.

---

## 7. The shell

`game.gd` builds `field_view`, `hud_view`, `panel_view` **in code** in `_ready()`, so a net calling
`_ready()` exercises the real wiring.

| Input | Effect |
|---|---|
| `1` / `2` | load the highest-HP living **in-reserve** soldier of that type onto the pending boat |
| Left click on a dock | launch the pending boat to that dock |
| Left click on a roster entry, in REWARD | bolt the beak on |
| Left click on the restart rect, in WON / LOST | start a fresh run |

⚠ **Never pre-set an `@onready` field from a net.** Null it back out before `_ready()`, or the line that
does the wiring can be deleted and the round stays green while the game shows nothing.

**`project.godot`'s `run/main_scene`** points at a one-node scene carrying `game.gd`.

---

## 8. Nets — **six, landing as one group**

The wrapper reds below five, and the round does not run at all today.

| Net | What it measures | The inversion that must bite |
|---|---|---|
| `net_battle` | Drives `battle.step(dt)` and asserts **through it**: no two living units share a tile · nearest-first · `range+1.5` reach at exactly 1.0, 1.41421 and 2.0 · epsilon boundary · beak adds 1.0 · area splash · no friendly fire · stop-when-in-range · permanent death · **step order** · in-transit soldiers are hit but do not hit | one per assertion, and **making `step_toward` skip its reservation check must redden it** (`grid.reserve` does not exist — reservation lives inside `step_toward`) |
| `net_boat` | fleet 2 · cap 5 · launch on click · **`launch` false at t=5.9 and true at t=6.0** · unload placement · boat waits when fewer than 5 tiles free · load while at sea | let a soldier aboard attack; make the berth free at 5.9 |
| `net_islands` | 3 islands · 18×32 · legend-only · docks adjacent to water · **`grid.flow_field` + `grid.step_toward` bring a walker within its attack reach of every enemy, from every dock** — *not* onto the enemy's tile, which is reserved and can never be entered · narrowest cut is 9 / 2 / 9 | **the `,` on island 3 row 14**, and **a fixture island with a disconnected enemy** — a greedy dead end would not bite a BFS walker |
| `net_run` | 3 islands · rewards · **HP carries by identity, not by count** · wipe loses · timeout loses · restart resets | rebuild `army` inside `begin_island` — a count-only check stays green |
| `net_shell` | `game.gd::_ready()` builds three children · each is `visible` · **each laid-out rect lands inside a 1280×720 viewport** · treed with `pump_frames` so `_draw` really runs · `_paint_*` arguments captured and equal to what the sim holds | delete one `add_child`; return a bare `Rect2()` from a layout function |
| `net_draw_leaf` | the per-function `draw_*` table in section 6, **across all three view files**, **and any function in those files the table does not name is red** · every leaf argument is used · no `Color(` or `Color.` and no literal assigned to `_px _width _radius _size _margin _alpha _ratio _offset _gap _font_size` outside `look.gd` | a bare `draw_circle` in an unnamed function; `draw_circle(p, 0.0, col)`; a colour moved into `field_view.gd` |

`net_citations` already exists, making **seven** — and **`net_probe`** makes eight: it feeds
`tools/probe/run_run.gd` a run that must be reported as a loss, because *the last probe this repo had
graded itself in its owner's favour twice.*

⚠ **Phase A ships `net_battle · net_boat · net_islands · net_run · net_probe · net_citations` = six.**
Without `net_probe` it was exactly five, equal to the wrapper's floor, **so one net slipping to Phase B
would have stopped the round running at all.**

⚠ **`net_grid` was a separate net in the first draft and has been folded into `net_battle`.** Measuring
`grid.reserve` on its own proves a pure function correct and proves nothing about whether `battle.step`
ever calls it — *"measuring a pure function is not measuring that anything calls it"*, and that hole cost
this repo a notice painting at zero size under 320 green checks.

⚠ **`net_islands` must call the game's functions, not reimplement BFS.** A net with its own walker measures
the net.

**Each net runs in its own process.** **A net that runs zero checks is a failure.**
**Only the final `[wrapper]` line is green.**

---

## 9. Acceptance

| Piece | Accepted when |
|---|---|
| Movement | Two soldiers walking into the same gap **queue** instead of overlapping, on screen |
| Boats | A berth visibly empties for 6 seconds and the player has to wait |
| Island 1 | The force lands and clears it. **Sending everyone is correct here** |
| Island 2 | The neck **visibly queues** melee while ranged shoot over; **the west crow shoots the boat** |
| Beak | The bolted soldier attacks from a distance the others cannot |
| Island 3 | **Won arriving healthy and lost arriving chipped — both seen**, not one |
| HP carryover | Soldiers visibly arrive at island 3 damaged |
| Loss | The screen says **why** — timed out or wiped — with enemies-left still on screen |

⚠ **None of these is accepted by an agent having walked through it.** Acceptance is the user saying they
saw it, written into the GDD the moment it is heard.

---

## 10. Deliberately not in this slice

Chest and elite islands · artifacts · map branches · meta unlocks · tiers, ramps, flying · fog · knockback ·
a recovery path · a second specialty · enemy-strength formulas · `tools/look/`.

**And cut during review, having been in the first draft**: the **map screen** (`map_view.gd`). A
straight-line map of three nodes offers **no choice at all** — clicking the only next node is not a
decision — so it costs a screen and a net and buys a click. Clearing an island goes straight to the next.
⚠ **This makes explicit what section 12.9 says**: the slice proves the **main** loop and merely *executes*
the session loop.

---

## 11. Phase A is not finished until the probe closes these numbers

**`tools/probe/run_run.gd`** plays a whole run headless with a scripted policy and prints, per island:
soldiers lost · HP pool in and out · fight duration · **seconds in which no input was possible**.

Four policies, all required:

| Policy | The number it has to produce |
|---|---|
| Everything at once | **Wins all three islands from full health.** If it loses, the enemies are too strong |
| One boat at a time, waiting | **Loses more HP than "everything"**, on every island. If not, dribbling is free |
| Only ranged | **Clears island 2, and is wiped on island 1.** That exact pair is the neck doing its job — and it is the criterion, because "beats" was in the first draft with no operational meaning and could not be judged |
| Everything, entering the boss at 60% pool | **Loses.** ⚠ **This is the row that currently fails** — see below |

⚠ **The last row is the one that failed.** A full simulation of the first draft's numbers won the boss
**with every soldier on 1 HP** — enemy DPS is fixed and the fight is short, so total damage taken does not
scale with how weak you are. **`Winnable healthy, lost chipped` was unobservable.** The lion's row was
raised on that basis and **is still unverified**; Phase A closes it or the boss is decoration.

⚠ **And the dead-air number is why the probe prints it.** *"It isn't fun"* became **83% dead air, 150 s
between kills** in the last game by writing exactly this. The tool was deleted with that game; the move
was not. **The GDD now records that an autobattler collides head-on with planning principle 1, and this
print is the only instrument that settles it.**

⚠ **The last probe this repo had graded itself in its owner's favour twice.** **Invert this one**: feed it
a run it must report as a loss.

---

## 12. What two adversarial passes broke

**Every item below was found by running something. None was found by rereading.**

### 12.1 Three island grids disagreed with their own prose
Island 3's row 9 was fully open, so the ring had a second doorway the prose denied. Island 2's crows were
both behind the wall, so no enemy in the slice could reach a boat while the plan claimed that picture was
in. **All 54 rows were confirmed 32 characters by script; the two defects came out the same way.**

### 12.2 The first combat table made island 3 unwinnable
Bison at 4.0/1.5 s and soldiers at 10 HP cost more than half the pool on island 1 alone, and the boss was a
guaranteed wipe. **An island you can only lose on is not a lose condition, it is a wall.**

### 12.3 The movement rule was broken and its net measured the wrong thing
Greedy 8-way descent **stalls on five of twenty-six dock→enemy pairs** — island 2's two docks to the
north-east crow, and island 3's east dock to everything in the ring.
⚠ **The first repair of this section claimed "every other pair walked fine". That was false** — its script
only walked island 3. **A correction pass that only re-measures the row being argued about is the failure
CLAUDE.md names, and it happened here, inside the fix for it.**
⇒ Movement became a BFS flow field, and `net_islands` drives the real functions.

### 12.4 There was no way to lose before the clock, and no way to play again
A wipe left an empty roster staring at a running timer, and finishing left no restart. Both added, and
**the wipe rule went back into the GDD** rather than staying buried here.

### 12.5 The corrected numbers said island 2 taught the wrong lesson
*"Sending everyone is wrong"* is false: with the cap binding both sides, 13 committed and 3 committed take
**identical damage and identical deaths.** The queue is free. That claim came from the GDD's contact-line
section, **which had already been overturned when this plan was written, and the plan inherited it anyway.**

### 12.6 The island-2 neck did not bind, and the lion left its ring
Bison detect 8 reached the neck from column 21, so **the enemy walked out through the bottleneck one at a
time and was surrounded** — the neck constrained nobody. And lion detect 6 walked it onto the doorway tile
by t=6.0 s, so **the fight happened on open ground and the beak's reason to exist never occurred.**
⇒ Enemies moved to column 26, bison detect 6, lion detect 2.

### 12.7 `range + 1.0` excluded diagonals, and it broke three things at once
A diagonal neighbour is 1.41421 away. At `+1.0`: **at most four melee can hit one target**, **the lion's
area attack catches almost nothing** because orthogonal neighbours are 1.414 apart from each other, and
**the orthogonal case sits exactly on the float boundary.** ⇒ `+1.5`, with an epsilon.

### 12.8 "Narrowest cut" had no definition and no reading made the prose true
The prose claimed **9 / 2 / 3**. Under per-column passable count the islands are **9 / 2 / 7**; under a
minimum vertex cut they are something else again. **True under neither reading**, and the net was told to
assert a number the plan could not name.
⇒ **Definition pinned to per-column passable count, and the numbers re-measured to 9 / 2 / 7.**
⚠ **The min-vertex-cut definition was tried first and abandoned mid-check** — the script written to confirm
it returned the same value for all three islands, which is obviously wrong, and **rather than debug a
max-flow that the net would then have to reimplement in GDScript, the definition was replaced with one that
cannot be got subtly wrong.** A measurement the instrument cannot be trusted to make is not a measurement.

### 12.9 The one this plan cannot fix — **the session loop has no decision in it**
Three islands in a line, one reward each, no fork. Every session-level choice the GDD describes needs a
branch and there is none. ⚠ **The user's goal was a session loop, and it will run** — but if the question
afterwards is *"is the run interesting?"*, this slice cannot answer it, only *"is the island interesting?"*
⇒ **The cheapest fix is one fork**: island 2 offered as a choice of two, count on one side and the beak on
the other. **Not in this plan. It is one node's worth of work and it is the user's call.**

### 12.10 ⚠⚠ The boss still has no band, and the cause is geometry, not numbers — **one open decision**

The rewrite was re-simulated. **Raising the lion to 140 HP did not create a band.** Sweeping the HP pool
the army enters island 3 with:

| entering pool | 152 | 122 | 91 | 61 | 30 | **8** |
|---|---|---|---|---|---|---|
| result | WON | WON | WON | WON | WON | **WON** |

**Thirteen soldiers on 5% health still clear the boss**, and a 19× difference in HP moves the clear time
only from 21.5 s to 32.7 s. Worse, **it is not even monotonic** — 40% takes 32.7 s and 20% takes 28.6 s, so
tightening the timer produces *"a weaker army wins where a stronger one lost"*, which is unlearnable.

**The cause**: a soldier's reach is `4 + 1.5 =` **5.5**, and **every enemy on island 3 reaches at most 4.5**
(the crow), the lion being melee. **The back rank is not merely untargeted — it is physically out of range
of everything on the island.** So the army's floor DPS is fixed no matter how hurt it is:
**three ranged soldiers on 24 HP clear the boss island alone, taking 15 damage and losing nobody**, while
eight melee on 112 HP are wiped.
⇒ **No targeting rule fixes this.** "Ranged enemies prefer ranged soldiers" was simulated and **changed not
one line**, because the preference never gets a chance to apply.

> ### The one change that produces a band — **give the lion range 5**
>
> With `LION range 0 → 5` and nothing else touched, the sweep becomes:
>
> | entering pool | 152 | 137 | 114 | 91 | **84** | 61 | 30 |
> |---|---|---|---|---|---|---|---|
> | result | WON | WON | WON | WON | **WIPED** | WIPED | WIPED |
>
> **The flip is at 55–60% of the pool** — which is the number section 11 asks for, arrived at rather than
> assumed. **Islands 1 and 2 do not move at all**, since neither has a lion.
>
> ⚠ **This is a design change, not a tuning value: the lion stops being a melee boss.** Raising the crow's
> range instead was tried and does nothing — a crow has 6 HP and dies before it matters. **The only body on
> that island that lives long enough to punish a back rank is the lion.**
> ⇒ **The user decides.** Until then the lion's row keeps `range 0`, and section 11's fourth policy row
> **fails on purpose** rather than being quietly retired.

⚠ **And the next subsection and the island-3 acceptance row cannot both stand.** *"Ranged soldiers never take a
hit, recorded rather than patched"* and *"lost arriving chipped"* are the same fact from two sides.
**Whichever way the lion goes settles both.**

### 12.11 Two things measured and left alone, on purpose
**Ranged soldiers never take a hit.** Nearest-first plus stop-in-range means a melee front makes the back
line permanently safe — so **HP carryover and permanent death only ever bite melee.** That is also how Bad
North's archers behave, so it is recorded as something to watch in the first playtest rather than patched
with a rule nobody asked for.
**The east dock on island 3 was a 68.7 s walk** before the second doorway; with it, both docks are
symmetric. **If dock choice turns out to be nothing, that symmetry is the first thing to break.**

---

## 13. Scope — honestly

**Phase A is one session's work and Phase B is another.** Six sim files plus a probe, with the numbers
closed by measurement, is a full day. Adding four view files, a shell, and six nets on the same day is not,
and the record agrees: `v2-openfield` took days to reach 16 nets and 514 checks.

⚠ **And Phase A alone is worth shipping**, because the four rows in section 11 are the questions that
decide whether this design survives — **none of them needs a picture.**

**What this plan still cannot deliver**: whether it is fun. The last game shipped 34 features with nobody
having run the loop end to end. **This exists to be played, not to be finished.**
