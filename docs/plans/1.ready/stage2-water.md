# Stage 2 — the water stage

**Status**: ready — **skeleton.** The shape is mapped and the prerequisites are named; **the four GDD slots
are not all filled and this doc does not pretend they are.**

**One line**: stage 2 does not invent a mechanic. **Unlimited jumping underwater already ships**
(`water-jump-and-escape`, stage 1 of that doc, measured), and stage 2 is **the stage built around it** —
a stone cistern where **height is the wall and water is the ladder.**

**The user was not available while this was written.** Four calls below are marked **[mine]** — they are the
build's, not the user's, and every one is reversible on sight. Everything else is either traced to code and
docs, or left **TBD**.

**Source docs**: `GDD.md` ("The stage template", "Inside a stage — the zone loop") · `water.md` (what water
costs, measured) · `water-jump-and-escape` (the movement grammar, measured) · `stage1-map-layout` (what a
stage's map doc looks like) · `left-run-clumps-and-platforms` (everything stage-agnostic that stage 2 inherits)
· `terrain-baking` (how a map is painted and baked) · `monsters.md` (what stage 2's monsters may and may not be)

---

## What the repo already decides — closed, not open

| Closed | Where |
|---|---|
| **Water is stage 2** | `GDD.md`, "The stage template" — decided by the user |
| **The movement grammar** | Unlimited jumps while in water at or above `WATER_WET` (32). `character.gd`, measured: **climbs 42–45px per 200ms jump cycle, 208 px/s sustained** (`water-jump-and-escape`, acceptance 4·7) |
| **Stage 1's last scene is stage 2's tutorial** | `GDD.md` and `water.md` both say it. **The player has already climbed water once before arriving** |
| **The midboss reward is a key, not a power-up** | `GDD.md`, "Inside a stage — the zone loop": *"a place you can't pass without it"* |
| **Map height is 48 tiles, globally** | `stage.gd:1221` refuses any map whose row count is not `MAP_H`; `town_map.gd:28` and `fx_tuning.gd:1475`/`:1494` (background depth banding) both derive from it. **Width is per-stage.** ⇒ **A stage 2 deeper than 48 tiles is out of scope** |
| **The gate is generic** | `gate-ending.md`: *"the day stage 2 exists, what changes is where it leads, not what it is."* `stage_gate.gd` is geometry plus one predicate — **nothing about it is stage-1-specific except its two coordinate constants** |
| **20 live monsters, boss slots reserved** | `monster_defs.MAX_MONSTERS` = 20; the reserve is derived from boss rows in the pushed table (`boss-slots-are-reserved-in-the-spawn-door`) |
| **Mob rows are `(tx, kind)` — no `y`** | `stage1_monsters.gd`; `monster_placement.resolve()` scans **up** from the map floor at wake time |
| **The sim is 20Hz integer** | `src/sim/` — no float, `Vector2`, `sqrt`, `sin`, `randi`, `OS.`, `Time.` |

---

## 1. What the stage is

### The shape

**A stone cistern.** Bedrock shell, stone interior, standing water in the low places, and **vertical rises
that cannot be walked or jumped out of.** Stage 1 is a long horizontal walk with a dip in it; stage 2 is the
opposite reading of the same 48 rows — **the corridor turns vertical and water is what makes vertical passable.**

**Three zones plus a locked fourth** — the shape stage 1 actually shipped, not the GDD's nominal four
(`GDD.md`: *"The GDD assumed 4 zones per stage; stage 1 has three"*). **[mine]** — chosen so every
stage-agnostic thing in `left-run-clumps-and-platforms` transfers with no reinterpretation. The user may want
four.

```
enter (from stage 1's gate) → ① flooded approach → the dry shaft (blocked)
→ ② → midboss → the key → flood the shaft, climb it → ③ boss → gate
                                        ④ locked, visible, needs the double jump
```

### How long

**The unit is stage 1, measured**: `MAP_W` = 300 tiles (`terrain_map_generated.gd:12`), `MOVE_SPEED_PX` = 260
⇒ **9,600px / 260 = 36.9 seconds of pure walking**, end to end, before a single fight. Spawn→midboss is
142 tiles ≈ 17.5s *computed* — and `left-run-clumps-and-platforms` §1 flags that number as **wrong and never
driven**, because three shelves stand across the corridor and the arithmetic contains no hops.

⇒ **Stage 2 is sized at 200–300 tiles**, i.e. **25–37 seconds of walking.** **TBD: the exact width.** It is
the one number that costs painting labour directly (§5), so it is the user's to set against how much of the
night exists.

**Vertical travel is slower than horizontal and that is the point.** Climbing water is 208 px/s against
walking's 260 — so a 10-tile shaft (320px) is **1.5s of climbing** and reads as a beat, not a wait.

### Theme — **TBD, and it is not cosmetic**

`GDD.md` pins theme as *"= material layout"*, and materials decide which rune matters: *"Terrain decides which
rune is strong in which room."* Four materials exist (`cell_materials`: empty · stone · wood · bedrock) plus
water; **11 palette slots are free** (`left-run-clumps-and-platforms`, "No sixth material").

**The open question is wood.** A cistern of pure stone means **the fire rune — stage 1's whole reward — does
nothing in stage 2.** That may be right (a stage that answers a different rune) or wrong (a reward that dies
one stage after you earn it). **TBD, the user's.** Naming the fork is this doc's job; taking it is not.

---

## 2. The movement grammar in practice

### What is impossible without water

**Measured, not computed**: the character's jump ceiling is **102px** — `character.gd`'s own hold-time table
beside `JUMP_CUT_RATIO` (0.2), driven headless. **The 108px in the same file is the formula `v²/2g` and is not
what happens.** A 0.10s press clears **64px**; only a 0.25s hold reaches 102. `STEP_CELLS` is 2 cells =
**8px** of automatic step-up.

⇒ **A vertical stone face over 3.2 tiles is a wall.** With the town's double jump (`progress.air_jump_budget()`
returns 1 when `UNLOCK_DOUBLE_JUMP` is bought) it is roughly two of those.

⇒ **A shaft 10 tiles tall is impassable at any jump count, and trivial once flooded** — because in water the
limit is not raised, it is *removed*. **That asymmetry is the whole grammar**: every other traversal tool in
this game gives you *one more* jump; water gives you *all of them*.

### What a level built to exploit it looks like

- **Shafts, not slopes.** The stage's connective tissue is vertical: rooms stacked, joined by rises that are
  10+ tiles of sheer bedrock. A ramp anywhere is a hole in the design
- **Bedrock, not stone, for anything that must stay a wall.** `stage1-map-layout` already learned this —
  *"a lock holds only in bedrock; a stone wall is not a lock"*, because `blast_rd(0)` is 8 cells and
  `cell_grid`'s destruction filter excludes only `_indestructible`
- **Bedrock floors under every pool.** A stone floor under water is a floor the player can blow out, and
  **the water leaves through the hole.** That is a good puzzle exactly once and a soft-locked stage the rest of
  the time
- **Water sits where it is useful and where it is in the way.** The same pool that is a ladder up is also the
  thing standing between you and a ledge you could otherwise have walked to

### The first thirty seconds

**The player arrives already knowing this** — stage 1's escape taught it. So stage 2's opening is not a
tutorial, it is a **confirmation**: a short flooded stretch with a ledge 6 tiles up and no other way on.
Step in, jump, jump, jump, you are up. **No text.** `water-jump-and-escape` closed "the player works it out
alone" as intended-with-fallback-text-TBD; stage 2 inherits that TBD unchanged.

### One thing the grammar does *not* have — **danger**

**There is no drowning** (`water-jump-and-escape`, "Decided"), no buoyancy, no drag. Underwater the current
push is a real term (`body.water_flow()`, measured **45 px/s peak, 10–17% of walking**) and nothing else.
⇒ **Deep water is a pure advantage.** A whole stage of pure advantage is flat, and this doc does not have a
fix for it that costs nothing. **TBD** — the honest candidates are (a) accept it, water is the reward for
solving the puzzle; (b) put the monsters in the water (§4); (c) build drowning, which is a new axis and was
deliberately not built. **(a) and (b) are free; (c) is not.**

---

## 3. The midboss key

### **[mine] Recommendation: the water rune, and the wall it opens is height, not material**

**Stage 1**: fire rune → burn the wood wall. **Stage 2**: water rune → **make your own water** → climb it.

**Why this and not something invented**: the water rune already exists end to end.
`sim_tuning.ELEM_WATER` = 2 with `{"trace": TRACE_WET}`; `spell_sim.gd:561` turns that trace into
`cmd_water(x, y, water_r(gen), WATER_MAX)`; `cell_grid` applies it through `_write_water`, not `_write_cell`,
so the amount survives. **Bolt art exists** (`fx_tuning.gd:1344`). **The Korean name exists**
(`fx_tuning.gd:1544`). ⇒ **Zero new sim, zero new art, zero new rune.**

**The wall**: a dry bedrock shaft, 10+ tiles, bedrock floor, no ramp. With the rune you fill it and climb it.
**This is the GDD's requirement literally** — *natural law becoming the means of progression* — and it is the
same sentence as stage 1's with one word changed.

**Sizing, from shipping constants**: `water_r(0)` = 6 cells (`sim_tuning.SIM_SIZES`), so one generation-0 hit
wets an integer disc of **113 cells at `WATER_MAX` 255 ≈ 28,800 units**. A 1-tile-wide, 10-tile-tall shaft is
8 × 80 = 640 cells ⇒ **163,200 units ⇒ roughly 6 hits.**

> ⚠ **Treat that "6" as an order of magnitude and nothing more — the arithmetic assumes hits add up, and they
> do not.** `_write_water` **sets** `_aux`, it does not add: a second disc landing where water already sits
> **overwrites to `WATER_MAX`** and contributes nothing there, while the water that fell out of the first
> disc has already spread along the floor. Firing rate, aim and the shaft's own width all move the answer.
> ⇒ **The real figure is unknown and must be driven before a shaft is painted at any height.** If it turns
> out to be twenty hits, the key is a chore rather than a beat, and the shaft gets narrower or the rune's
> radius gets a second look.

### The collision with the town, and why it is not a defect

**The water rune is already for sale** — `unlock_defs.gd:56`, `UNLOCK_RUNE_WATER`, `for_sale: true`, at
`progress.GEMS_PER_UNLOCK` = 10 원석. So a player who bought it walks past stage 2's midboss.

**That is the GDD's design, not an accident**: *"the midboss's role changes per run… dropping from 'key' to
'reward' is where permanent progress is felt."* The GDD also pins the price rule — *"it must be met as a wall
once"* — and that value is **TBD** there and stays TBD here.

### The forks not taken, and their price

| Alternative | Price |
|---|---|
| **Lightning rune** — GDD's own thematic pair for water (*"lightning follows conductors"*) | **A new element end to end**: a new `ELEM_*`, a new `TRACE_*` with a new sim behaviour, bolt art, palette entry, an unlock row, and `sim_tuning`'s own note that `TRACE_WET` grows when it lands. **`monsters.md` and `water.md` both record that wetness has no measurable value until this exists** — so it is the *right* long answer and the wrong one for a stage that must ship |
| **A new "swim/dive" ability** | A second physics axis in `src/actor/`, and it competes with the ability stage 1 already taught. `water-jump-and-escape` closed buoyancy and swimming as **not built**, on purpose |
| **A key that is not a rune** (a tool, a switch) | Breaks the GDD's rule that combat and traversal are not separate systems. Cheap to build, expensive to the design |

---

## 4. The bosses

### The machine is free; the beasts are not

`boss_ai.gd` already carries a pattern table and a tick machine — `MOVES` per kind, `Pattern`
`IDLE/WINDUP/CHARGE/STUN/FIRE/GORE/LEAP`, a phase change at half health, 20Hz state with 60Hz movement.
`Monster` delegates to it for any kind `BossAi.has_pattern(kind)` covers.

**Two bosses, the same shape as stage 1** — **TBD, not decided here.** What *is* decided is what the machine
costs to extend, and its own header states it: **a `MOVES` row alone is not enough.** `advance`'s `WINDUP`
transition falls through to the bull's charge for any kind it does not explicitly name — it **barks now**
rather than doing it silently, but a new boss still needs its own `kind ==` branch. ⇒ **per new boss:
one `MOVES` row + one branch + 9 animation sheets** (`monster-animation`).

### The user's deferred wish — recorded, not designed around

Team-lead reports the user called stage 1's bosses **"too boring — bigger, more gimmicks"** and then deferred
it. **That line is not in the repo anywhere** (searched) — it is conversation, and this doc records it as
something to confirm rather than as a decision.

**What this doc does with it**: it does not design to a deferred wish, and it does not repeat the shape the
user called boring either. Two observations, both free:

- **`stage1-bosses` already lists its own boring parts, measured**: phase 2 *halves* the windup telegraph
  right when the boss gets more dangerous (0.85s → ~0.4s, untouched); the slam's +80px reach *"rarely finds a
  moving player"* and changes the fight by one second; the gore gate is 120px against gore's real 54px reach,
  a ~66px dead band a bull whiffs into. **Three tuning items with numbers already taken** — a stage-2 boss
  built on the same machine inherits all three unless someone looks
- **The cheapest "gimmick" in this stage is water itself.** `cmd_water` is already a command and
  `MOVE_SLAM`'s terrain ignite is the precedent for a boss move that touches the grid. **A boss that floods
  its own room is one `MOVES` row and no new sim** — and §6's budget says it must be **one** body of water in
  motion, so it is a move, not a permanent state. **TBD, and the user's**

### The 20-cap during a boss fight is still open

`stage1-bosses` records *"whether trash mobs appear during a boss fight is TBD"* — unchanged and inherited.

---

## 5. Monsters — **stage 2 is not a farm, and there is no honest fiction that makes it one**

Today's kinds are 돼지 · 닭 · 늑대 · 황소 · 거대 수탉 (`monster_defs.ALL`). **[mine]: only the wolf survives
the move.** Its own table entry describes it as *"a lunging predator"* — nothing about it is farm-bound —
while a pig or a hen in a flooded cistern reads as stage 1 leaking through the gate.

**What `monsters.md` already constrains, and it is not this doc's to reopen:**
- **No insects.** The user's decision, and it explicitly *"keeps applying when deciding stages 2 and 3"*
- **No flyer** — not taste, mechanics: only 2 of 17 glyphs run (spread · blast) and **homing does not exist**,
  so a flyer can only be hit by manual aim. Adding homing means standing up a **third glyph kind** in the
  pipeline (`glyph_defs` has only `KIND_SPAWN` and `KIND_TERMINAL`) — a different order of magnitude
- **Roles need not be filled per stage.** `monsters.md` names a **burrower** as stage 2's own candidate

**Stage 2's roster is TBD.** What is not TBD is the cost of each new kind:

| Per new kind | What |
|---|---|
| **Art** | **5 sheets** for a trash mob, **9** for a boss (`monster-animation`). Local ComfyUI via `tools/pixel/gen.py` `PRESETS["monster"]` — **zero pixellab credits**, generated at exactly **4× the target** (16× and 8× were measured and fail to fill the box), chroma-green ground cut with `cutbg.py`, padded — never scaled — with `pad_sheet.py` |
| **Contracts** | **Box must equal the sheet** (`net_monster_sprite`) and **both dimensions must be multiples of `CELL_PX` 4** (`net_monster._defs_preconditions`). The bull's 86×54 art failed the second and was padded to 88×56 |
| **Code** | one `monster_defs.DEFS` row, one `fx_tuning.MONSTER_ANIM` block with **frame counts written down**, and a re-take of the cost table with `tools/stage/profile_monsters.gd` |
| **Frame budget** | Measured, `monster_defs.gd`: 20 hens = **+6,828µs = 41.0%** of the 60Hz frame; 20 roosters = **73.8%**. Cost is **sublinear in box cells** — the hen is 2.2× the pig's cells for 1.6× the cost. **A big stage-2 kind is affordable; twenty of them are not** |

### Two placement facts that change in a water stage — **found here, not inherited**

1. **`resolve()`'s upward scan is exact only because stage 1 has no caves.** Its own header says so:
   *"This map has no caves anywhere, so the climb is exact for all 300 columns."* The climb runs up from
   `floor_cy` **while the cell above is solid** — **a stage 2 with overhangs, cisterns or a roofed shaft
   breaks that premise, and it breaks silently**: the row resolves onto the wrong surface, or `push_error`s
   and is spent for the rest of the run (`wake_scan` never returns a spent row to dormant)
2. **Water is not solid** (`BEHAVIOR_NONE`), so the climb passes straight through it and a row over a flooded
   column resolves onto the **submerged** floor. That is arguably correct — it is still the floor — but
   **what a submerged monster does is undecided.** `monsters.md`: *"How they meet water — do they wash away ·
   sink · drown. After water closes."* **TBD, and it is stage 2's to close, because stage 2 is the first
   place it happens.**

---

## 6. Cost — **the number that constrains the whole stage**

### Standing water is cheap. This is measured, at almost exactly one screen's width

`water.md`'s own table, headless:

| Bowl width | Chunks holding water | **Awake chunks (max)** |
|---|---|---|
| 32 cells | 6 | 7 |
| 128 cells | 18 | 16 |
| **256 cells (32 tiles ≈ one screen)** | 30 | **18** |

18 chunks × 41µs ≈ **740µs/tick = 1.5% of the 20Hz budget.** The interior of a pool is packed, blocked above
and below, moves nothing and sleeps; **only the surface band stays awake, and that band does not grow much
with width** (7 → 16 → 18 across an 8× width increase).

> ⚠ **Read that table for what it is: a bowl that was poured and is still flattening — and at these widths it
> never finishes.** `water.md` measured a 32-cell bowl stopping at 2,798 ticks and a **128-cell bowl still
> going at 4,000 ticks (200 seconds)**, with volume conserved exactly. ⇒ **"18 awake" is not a transient. A
> wide poured pool holds ~18 chunks awake indefinitely, at 1.5% of budget each, forever.**
> **Ten such pools would be 15% of budget with nothing happening on screen**, and that is the shape of the
> mistake this section exists to stop.

⇒ **The lake is not the problem — provided it never has to flatten.** That is the whole argument for
authoring water flat (below), and **it is the single most load-bearing unmeasured claim in this doc**: a
perfectly uniform pool has a neighbour difference of 0 everywhere, `WATER_MIN_DIFF` is 4, `_water_share`
moves nothing below that line, so the chunks should sleep on the first tick. **That is reasoning from
constants, not a measurement.** ⇒ Acceptance 1 exists to measure it, and **it must be measured before any
terrain is painted** — if authored water does not sleep, the stage's whole premise is priced wrong.

### Water in motion is the problem, and one pour already sits at the cap

| Measured | Value | Where |
|---|---|---|
| `MAX_CHUNKS_PER_TICK` | **100** | `sim_tuning.gd:202` |
| `WATER_SUBSTEPS` | **3** ⇒ effective width **≈33 chunks** | `sim_tuning.gd:127` |
| `g.step()` **while pinned at the cap** | **84ms/tick against a 50ms budget = 168%** | `water.md`, "Cost" |
| Stage 1's room-① pour (`WATER_RAIN_PER_TICK` 20,000 over 176 cells) | active chunks **76–100, frequently at the cap** | `water-jump-and-escape`, verify-look in the real game |

⇒ **One pour of the size this game already ships is at the ceiling.** **Two at once is over it** — that
second sentence is **inference, not measurement**: two pours far enough apart touch disjoint chunk sets, so
their counts add. It has never been run, because the game has never had two.

**Over the cap does not drop frames** — the cliff is gone (cap 512 → 100 made cost independent of volume;
verify-look saw **60 FPS held** while chunks sat at 100). **It delays water.** And `water-jump-and-escape`
says exactly what that costs: *"water slowing during the escape scene means the presentation is broken."*

> ⚠ **The 168% and the 60 FPS contradict each other, and nobody knows why.** `water.md` records exactly that
> and does not resolve it: *"Headless measurement and the real game disagree — why was not measured."*
> ⇒ **Do not quote 168% as the operative number and do not quote 60 FPS as the all-clear.** What is safe to
> build on is only the direction — **at the cap, water arrives later than the design asked for** — and that
> is enough for the rule below. **The day stage 2's flood scene is built, the disagreement has to be settled
> first**, because a scene whose whole beat is "the water rises" is the first thing it can eat.

### **[mine] The level-design rule that falls out**

> **At most one body of water may be in motion at a time.**

Everything else must be **already at rest** when the player reaches it. Concretely:

- Pools are **authored flat and full**, not poured — a flat pool has nothing to flatten
  (`WATER_MIN_DIFF` = 4 means neighbours within 4 do not move) ⇒ **it sleeps on tick 1**
- Pools are **walled**. `water.md` measured a puddle on open floor spreading to **424 cells wide at 4,000
  ticks and still growing**, with an estimated rest width of ~860. Open water on a flat floor is a chunk band
  that never stops
- **The player's own water is the moving body.** The water rune, and any boss move that floods, are the
  budget. Nothing in the terrain competes with them
- **Never two flood scenes in one room**

### The prerequisite nobody has built — **`~` bakes water with zero water in it**

`water.md` says water comes from **both** sources, and *"already on the map — lakes · rivers · groundwater,
drawn together with the terrain"* is half of that. **The door exists and is wrong:**

- `terrain_baker.CHAR_BY_MAT` maps `Mat.WATER → "~"` and `terrain_map_generated.gd:66` carries it in
  `MAP_CHARS`. **The character appears zero times in the map body** — it has never been used
- `build_map_into` issues `cmd_fill` → `_fill_rect` → **`_write_cell`**, and `cell_grid.gd:930-932` sets
  `_mat = WATER`, **`_flag = 0`, `_aux = 0`**

⇒ **Paint a lake today and you get a lake with amount 0**: drawn as water, containing none. No jumping, no
extinguishing, no flow — **and not one line of error.** `water.md` named this exact hazard from the other
side (*"`_write_cell` zeroes `_flag` and `_aux` together ⇒ the water amount vanishes on the spot"*) and
nobody has walked into it yet because nobody has painted a `~`.

⇒ **[mine] This is stage 2's first build item, before a single tile is painted.** It is small — a fill that
routes `Mat.WATER` through `_write_water` at `WATER_MAX` instead of `_write_cell` — and it is what makes the
"authored at rest" rule above possible at all. **It is also the cheapest net in this doc**: build the map,
`step()` once, assert `active_chunk_count() == 0` **and** `aux_at` at a pool cell is `WATER_MAX`.
*Inversion: route it back through `_write_cell` and both go red.*

### What it costs to build, in this repo's units

| | |
|---|---|
| **Tiles to paint** | **9,600–14,400** (200–300 × 48). Stage 1 is 14,400. **The single largest item, and it is hand labour** — the ASCII door (`paint_terrain_from_map.gd`) is the only way to do it at scale |
| **Mob rows** | one new `stage2_monsters.gd`, same `(tx, kind)` schema. ~18–30 rows |
| **New art** | **TBD by roster.** 5 sheets per trash kind, 9 per boss, zero credits, local ComfyUI. **The unavoidable minimum if stage 2 is not a farm is one new trash kind** |
| **New sim behaviour** | **One thing: authored water at rest** (above). **Everything else is zero** — no new material, no new element, no new physics axis |
| **Shell** | **Zero. Not this doc's cost** — a per-stage table for map, spawn tile, mob rows, gate geometry and stage name is being built in parallel. The stage-1 literals it absorbs are `stage.gd`'s `ROOM1_WATER_X0/X1/ROW`, `stage_gate.SEAT_TILE_X`/`WALL_TILE_X0/X1` and `stage1_monsters.FLOOR_CY` |
| **Net time** | A round is **24.4s**, of which `net_gate` is **24.3s** and `net_water` **14.4s** — measured either side of `left-run-clumps-and-platforms`. (**CLAUDE.md says ~28s**; that line is the older figure and the measured pair is used here.) A stage-2 map net is the cheap `net_tables._stage_map` shape; **the water-at-rest check is cheap precisely because it asserts nothing settles** — the opposite of `net_water`'s 1,200-tick settle. ⇒ **Expect single-digit seconds added, and call `harness-manager` if it is more** |

---

## 7. What it reuses unchanged — **more than expected**

**Nothing in this list needs a line changed.**

| Reused | Note |
|---|---|
| **The whole water sim** | Amount-based water, chunk sleep, fall K=4, left-right sharing, shallow colour, water-puts-out-fire. `water.md`'s six stages all run |
| **`WaterSource`** | `RefCounted`, pours a band over N ticks, already the shipping path and already what the nets drive. **A stage-2 flood scene is a second construction of the same object** |
| **`cmd_water` / `set_water` / `aux_at`** | The official doors. The water rune already goes through them |
| **Unlimited underwater jumping** | `character.gd`, threshold `WATER_WET` 32, measured. **The reason stage 2 exists** |
| **Current push** | `body.water_flow()`, `WATER_PUSH_PX` 130. `water.md` warns it *"reads weak in a wide, even river"* — **stage 2 is named there as where that limit becomes real** |
| **Clumps · stone shelves · the wake bands · the boss reserve** | `left-run-clumps-and-platforms`, **all stage-agnostic.** The shelf is a 2-tile solid block you hop onto with a 0.10s press; the materialise/stir bands are `stays_active(was_active, dist, enter, exit)` arguments, not stage constants |
| **`monster_placement.resolve()`** | Unchanged — **subject to the two caveats in §5** |
| **`boss_ai.gd`** | The pattern machine, phase 2 at half health, the windup/stun windows |
| **The bake pipeline** | `stage.tscn`'s `Terrain` → `bake_terrain_editor.gd` → `terrain_map_generated.gd`. `terrain-baking`'s own TBD already names *"when there is more than one stage"* as arriving soon |
| **`stage_gate.gd` + `gate_view`** | One object, two coordinates. Stage 2's entrance is stage 1's exit |
| **The whole meta loop** | Town, research bench, 원석, the three-pick, settlement, the end-of-content notice |
| **Palette** | 5 of 16 slots used. **11 free** — a sixth material is affordable if the theme wants one |

---

## Bounds

| Situation | What must happen |
|---|---|
| **A pool the player blows the floor out of** | The water leaves. **Bedrock floors under anything load-bearing**; a stone floor is a puzzle you get once |
| **Two pours at once** | **Must not be possible.** §6's rule. Over the cap water is delayed, and a delayed flood is a broken scene, not a slow one |
| **The player floods the key shaft and leaves** | The water stays — **water is never consumed** (structural, `water.md`). The shaft stays open for the rest of the run. **Intended**: it is a door you opened |
| **The player reaches the shaft with the water rune bought in town** | They open it immediately and skip the midboss. **GDD's design, not a bug** |
| **A mob row sits over a flooded column** | It resolves onto the submerged floor. **What it then does is undecided** (§5) |
| **A cave or overhang anywhere in the map** | **`resolve()`'s upward scan stops being exact, silently.** Either the map has no caves, or the scan needs a `ty` hint — which reopens `stage1_monsters`' *"`y` is never written down"* principle |
| **A pool wide enough to never settle** | `water.md`: a 128-cell bowl **does not stop by 4,000 ticks**. Authored-flat water sidesteps this entirely; poured water does not |
| **Fire in a stage with water** | Already correct and already surprising: only cells **touching** water resist, and fire **passes under** a water-topped wood body more than 1 cell thick. If stage 2 has wood, this is on screen |
| **Zoom-out (`-`)** | Same as stage 1 — everything materialises on screen. **Do not couple any band to zoom** |

---

## Acceptance

1. **A painted pool is full and asleep** — `aux_at` is `WATER_MAX`, `active_chunk_count()` is 0 after one `step()`
2. **The dry shaft cannot be climbed** — driven, at jump budget 0 **and** 1 (the double jump must not open it)
3. **The water rune opens it** — driven: N hits, then a character climbs out. **N is measured, not assumed**
4. **The stage rolls end to end** — spawn to gate with no soft lock, driven, the shape of `net_tables`' stage-1 reachability check
5. **The spawn is on ground and connected to the midboss** — the check `left-run-clumps-and-platforms` §2 added for stage 1, twinned
6. **Active chunks stay under the cap at every scripted moment** — the one number §6 is built around
7. **The stage reads as a different place from stage 1** — by eye, verify-look's
8. **The climb reads as climbing, not flailing** — by eye. Stage 1's measurement (42–45px per cycle, 3–4px of sag) is the bar it must not fall below
9. **The player works the shaft out alone** — **played, not computed.** Only the user closes it

---

## TBD — **do not force these full**

**The four GDD slots, and only one has a recommendation:**

| Slot | State |
|---|---|
| **Theme** (= material layout) | **TBD.** Stone cistern is the shape; **whether wood exists is the live fork** (§1) — it decides whether the fire rune survives past stage 1 |
| **Direction** | **TBD.** `GDD.md` forbids pinning "right" globally. Left-to-right is cheapest (the gate sits at stage 1's right edge); **a stage that descends is what the theme wants** |
| **Midboss reward** | **Recommended: the water rune** (§3) — **[mine], argued from what ships, not chosen by the user** |
| **Boss reward** | **TBD.** Stage 1's is itself listed as *"permanent material (gear enchanting came up, unconfirmed)"* |

**Also open:**

- **Map width** (200–300 tiles) — the number that sets the painting labour
- **Whether stage 2 has a locked fourth zone at all**, and what is in it. Stage 1's ④ reward is still TBD
- **The monster roster.** `monsters.md` offers a burrower; "no insects" and "no flyer" are hard walls
- **What a submerged monster does** — wash away, sink, drown, or nothing (§5)
- **The two bosses** — identity and moves. The machine costs one `MOVES` row + one branch + 9 sheets each
- **Whether trash mobs appear during a boss fight** — inherited open from `stage1-bosses`
- **The price of the water rune in town**, so the shaft is met as a wall once (`GDD.md`'s own rule)
- **How many water-rune hits fill the key shaft** — arithmetic exists (≈6), **measurement does not**
- **Fallback text** if the player does not work the shaft out — inherited from `water-jump-and-escape`
- **Whether the current is worth anything in a wide river** — `water.md` names stage 2 as where its known
  weakness becomes real, and recommends accepting it

---

## What this doc is least sure of — **read this before building on it**

Listed so it is flagged rather than found.

1. **That authored-flat water sleeps.** §6. Reasoning from `WATER_MIN_DIFF`, not a measurement, and **the
   whole cost argument rests on it.** Measure it first
2. **The 168%-of-budget figure.** Headless, and it disagrees with the real game's 60 FPS. `water.md` records
   the disagreement and nobody has explained it
3. **"Six water-rune hits fill the shaft."** `_write_water` overwrites rather than adds, so the arithmetic's
   premise is wrong. Order of magnitude only
4. **"Two pours exceed the cap."** Inference from disjoint chunk sets. Never run
5. **The 18-awake-chunks table and its 41µs per chunk** are `water.md`'s, copied. **Not re-measured here**,
   and the cap in force when they were taken is not recorded in that doc
6. **Everything about how stage 2 *feels*.** Every claim about the shaft reading as a wall, or the climb
   reading as a beat, is design reasoning. **Only the user closes those**

**And one thing outside the doc's control**: the deployed web build is a day behind `main`, so **nothing
here reaches anyone without a redeploy the user has not approved.** That is not a reason to change the
design; it is a reason not to count stage 2 as shipped when it is merged.

---

## The honest read — **this cannot be built well tonight, and here is what can**

**What makes it a multi-session feature, not a long night:**

1. **9,600–14,400 tiles of hand-drawn level.** Stage 1's map was drawn by the user, rejected on sight
   (*"내가 생각한 느낌이 아니다"*), and redrawn. **A map nobody has looked at is not a stage** — and the user is
   not available to look
2. **New art.** Stage 2 is not a farm; the minimum honest roster is one new trash kind (5 sheets) and the
   generation loop is a real pipeline with a downscale factor, a chroma cut and two size contracts
3. **Two bosses.** Stage 1's took a full plan doc of its own, thirteen numbered risks, and they are still
   unaccepted
4. **Four GDD slots, three of them the user's** — and this doc exists precisely because they cannot be asked

### The smaller honest version — **one zone, no bosses, no new art**

**Build the door and the grammar; leave the stage for the user.**

- **One flooded corridor, ~60 tiles**, behind stage 1's existing gate. Painting: **~2,900 tiles**, one sitting
- **Authored water at rest** — the §6 prerequisite. **Do this first; it is the one thing that must be built
  either way**, and it is small
- **One shaft**, 10 tiles, bedrock, dry. **The water rune opens it** — granted by debug or by the existing
  research bench, not by a midboss that does not exist yet
- **Monsters: the wolf only**, reusing today's art. Thin fiction, but the only kind whose fiction survives
- **It ends in the end-of-content notice that already ships.** No boss, no second gate
- **Nets: the four cheap ones** — pool asleep and full, shaft unclimbable at both jump budgets, shaft
  climbable after the rune, spawn-on-ground-and-connected

**What that proves, which is exactly what stage 2 needs proven**: that the stage door works, that authored
water works, and that **"height is the wall and water is the ladder" reads under someone's hands.**
**Everything after it is content, and content is the user's call.**
