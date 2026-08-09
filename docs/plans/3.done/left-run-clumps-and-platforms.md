# Left run — clumps and stone shelves

**Status**: done — **implementation finished, acceptance not passed.** `3.done/` means the first, not the second.
**One line**: the walk to the fire rune is **242 tiles and 29.8 seconds, of which the first 187 never change
height once** — cut 100 tiles of that flat out of the map for real, replace the even sprinkle of mobs with
**3 clumps of sleeping monsters**, and give the flat a vertical axis with **`STONE` shelves 2 tiles up,
hens standing on them.**

**All of it is implemented. None of it has been looked at.** Terrain cut and rebaked (`MAP_W` 400 → 300),
table re-authored, shelves painted, boss reserve in the spawn door, waking presentation A+B, spawn-on-ground
check added. The round is green with the new checks inverted.

**What nobody has run or looked at** — Acceptance **1 · 3 · 4 · 5 · 6 · 7 (the by-eye half) · 9 · 12**.
That is the whole screen half plus the two that need a person walking the map. **8 and 10 and 11 are driven
headless and green; 2 falls out of the cut by construction.** ⇒ **Everything this doc claims about how the
left run now *feels* is unverified.**

**Five things in this doc did not survive contact with the code.** Each is corrected in place below and
marked ⚠ — the XP total (§6), the clump geometry (§3), the blast-radius table (§1), a Bounds row that was
missing entirely, and **the walk time that justifies the whole feature** (§1 again — the shelves stand
*across* the corridor, so 17.5s counts no hops and is wrong by an unknown amount).
A sixth is a hole in the harness rather than in this doc: §5's `push_error` backstop **cannot be measured by
these nets at all.**

**The problem, in the user's words**: **"불의 룬을 얻으러 가는 과정이 재미없다."**

**Reverses one row of** [`../../decisions/mobs-lie-on-the-map-no-arena-room.md`](../../decisions/mobs-lie-on-the-map-no-arena-room.md)
— its rejected-alternatives table killed "all mobs bunched into a few clumps" and recorded the user replacing
it with **"그냥 바닥에 잔잔하게 깔아줘"**. **That line is reversed: clumps come back.** What that decision
protected is *not* reversed — **no arena, no lock-in, no trigger spawning, no respawn**, and its reopen
condition (a level-up before the midboss) is argued in §6 rather than assumed.

**Everything below was measured against source and against the baked map, not read out of another doc.**
Numbers that came out of stale comments in earlier drafts are corrected in place: the pit mouth is **not** at
tile 236, and the player's jump ceiling is **not** 108px.

---

## Why

Computed directly from `src/stage/terrain_map_generated.gd` (first solid tile per column, all 400 columns):

```
x0-1     ty0   B      the left wall
x2-148   ty20  #  ┐
x149-150 ty15  B  │   a floating 2x2 bedrock slab, 5 tiles up
x151-189 ty20  #  ┘   188 tiles of flat, one height
x190-197 ty22  #  ┐
x198-205 ty24  #  │   5 stair steps, 8 tiles wide, 2 tiles down at each seam
x206-213 ty26  #  │
x214-221 ty28  #  │
x222-229 ty30  #  ┘
x230-259 ty32  #      room ① — the bull
```

Spawn is `(3, 19)`; the bull is row `tx245`. **242 tiles = 7,744px, and at `MOVE_SPEED_PX` 260 that is 29.8
seconds.** From `tx3` to `x189` — **187 of those 242 tiles** — the ground is at `ty20` and never moves.

`stage1-map-layout.md` already wrote the verdict from a screenshot: **"걸어도 그림이 안 바뀐다"** and
"랜드마크가 없어 「얼마나 왔나」를 모른다". The mob pass that followed put ~3 mobs per screen along it, evenly,
which changes *what stands on* the flat and never the fact that it is flat.

**Length is a symptom. The missing vertical axis is the cause.** Both halves ship together or neither is
worth doing.

---

## Behavior

### 1. The flat loses 100 columns — **the terrain is cut, the spawn does not move**

**Rejected: moving `SPAWN_TILE` east.** It produces the same walk in the same number of seconds and leaves
~100 tiles of drawn, walkable, empty map behind the player. The user rejected it outright.

**The cut, precisely: delete map columns `x2–101`** — 100 columns of `ty20` flat, uniform, nothing on them.
`x0–1` (the left bedrock wall) stays; `x102–189` is retained and becomes the new `x2–89`.

| | today | after |
|---|---|---|
| `MAP_W` | 400 | **300** (derived from `get_used_rect()` — nothing to hand-edit) |
| Spawn | `(3, 19)` | **`(3, 19)`, unmoved** — still on flat, still 2 tiles from the wall |
| Flat | `x2–189`, **188 tiles** | **`x2–89`, 88 tiles** |
| Floating bedrock slab | `tx149–150` | **`tx49–50`** — survives the cut (§9) |
| Stairs | `x190–229` | `x90–129` |
| Room ① / bull | `x230–259` / `tx245` | `x130–159` / **`tx145`** |
| Spawn → bull | 242 tiles · **29.8s** | 142 tiles · 4,544px · ⚠ **17.5s, and that number is now wrong** |

⚠ **The number this whole compression was justified by is uncomputed and undriven.** **17.5s is
4,544px ÷ `MOVE_SPEED_PX` 260 — a flat walk.** As built the walk is not flat: the three shelves stand
**across** the corridor, so the run to the stairs is **three hops**, each costing airtime this arithmetic
does not contain (the ⚠ row in Bounds). **The true figure is higher and nobody knows by how much.**

**Acceptance 1 says "driven, not computed" for exactly this reason, and it has not been driven.** ⇒ **The
one-line claim at the top of this doc — 29.8s becomes 17.5s — is the single load-bearing number here and it
is the one still unverified.** It is very probably still a large improvement; "probably" is the honest word.

**Everything east of the cut shifts left by exactly 100 tiles (800 cells). There is no way around that** —
`MAP_W`/`MAP_H` come from the drawn region's `get_used_rect()`, so erasing columns on the left re-origins the
whole bake. **Naming the full blast radius is the honest part of this design**, and it is not large:

⚠ **And this table was four sites short.** Written before the edit, checked after it — the four below were
found only because a net went red or a value came out 3,200px wrong, which is the system working, but the
table claimed to be complete and was not. **The lesson is not "add four rows"** — it is that a hand-written
blast radius is a guess until the edit is made. Corrected in place:

| Missed | Why it was missed |
|---|---|
| **`stage_gate.gd:15` `SEAT_TILE_X` 370 → 270** | The row below names `:20-23`, the east wall. The **seat** is at `:15`, outside that range. Left alone, the ending arch stands 3,200px east of the map's right edge |
| **`net_water_rain_cap.gd:27-28`** and **`net_water_rain_speed.gd:27-28`** | Each keeps its **own copy** of `_MOUTH_X0`/`_MOUTH_X1`. The row below names only `net_water_rain`, where the constants are documented |
| **`net_monster_slam.gd:809-828`** | Pins room ①'s left wall in **cells** (1840 / 1900 / 1800), not tiles, so a `tx`-shaped search does not find it |

| Must be re-derived | Today | After |
|---|---|---|
| `stage.gd:304-306` `ROOM1_WATER_X0/X1/ROW` — **game code**, room ①'s reward pour | 1840 / 1860 / 200 | 1040 / 1060 / 200 (row unchanged) |
| `stage_gate.gd:20-23` `WALL_TILE_X0/X1` — **game code**, room ③'s east wall | 367 / 368 | 267 / 268 |
| `net_water_rain.gd:101-102` `_MOUTH_X0/_MOUTH_X1` | 1712 / 2079 | 912 / 1279 |
| `net_gate.gd:23-24,157,179,287,310` room ③ literals | 347 · 366 · 367 · 368 · 369 · 370 | −100 each |
| `net_monster_placement.gd:611-628,640-644` real-map pins | `tx149` · `tx358` · range 345–366 | `tx49` · `tx258` · 245–266 |
| `stage1_monsters.ROWS` | every `tx` | pre-① re-authored (§6); `tx ≥ 190` shifts −100 |

**`net_water_rain` is the one that looks scary and is not.** Its own header (`net_water_rain.gd:88-94`) says
these constants went stale once already, that going red **is the system working**, and writes the procedure:
"read `src/stage/terrain_map_generated.gd` and find the topmost row whose open run is bounded by solid at
both ends and has the floor below it. Multiply tiles by 8 for cells."

**What the vessel actually is, measured** — and it is *not* what earlier drafts of this doc said:

- `_PIT_ROW` = 208 cells = **`ty26`**. `_PIT_X0` is **derived**, not literal: `1712 + ((2079−1712+1) − 176)/2`
  = **1808 = tile 226**. The rain band is tiles **226–247**; the mouth is tiles **214–259**.
  **Tile 236 / cell 1888 is a dead number** — `net_water_rain.gd:92` names 1888 as the stale value from before
  the 312×126 → 400×48 repaint.
- The mouth's **left wall is the stair step at `x206–213`** (its top is `ty26`, so it is solid on row 208) and
  its **right wall is `x260–263`** (also `ty26`). The steps at `x214–221` (`ty28`) and `x222–229` (`ty30`) are
  the funnel's own floor.
  ⇒ **The stairs are part of the water vessel, not scenery.** The cut must not change one tile of `x190`
  rightward — only translate it.
- Verified against the baked map: at `ty26`, tiles 214–259 are all open and tiles 213 and 260 are both solid.

**Where the cut happens, concretely** (`../../design/terrain-baking.md`): the editing original is
**`src/stage/stage.tscn`'s `Terrain` TileMapLayer** — the baked `.gd` is a re-export and is never hand-edited.
Delete the columns there, **save the scene (Ctrl+S — unsaved state is not read)**, then run
**`tools/stage/bake_terrain_editor.gd` (Ctrl+Shift+X)**, which calls `tools/stage/terrain_baker.gd` and
rewrites `src/stage/terrain_map_generated.gd`. **For a 100-column deletion, use the ASCII door instead of the
mouse** — `tools/stage/paint_terrain_from_map.gd` stamps a text map back into the layer, which is the only way
to do this edit exactly. **This is 100 columns of one repeated tile and a bake, and re-typing 20 `tx` numbers.
It is not a day's work and this doc does not claim it is.**

### 2. **The spawn-on-ground check does not exist, and this redraw is exactly the accident it is missing for**

`net_tables.gd:234` uses `Stage.SPAWN_TILE` as **one of six sample positions in the camera-clamp test.** It
never asks what is under it. `stage.gd:50-56` says so in its own words — the map was repainted 312×126 →
400×48, `SPAWN_TILE` stayed `(3, 30)`, the character started inside a sealed cave, and **"not one line of
error is raised. The nets can't catch it either."**

**`net_town.gd:123-135` is the check that exists — for the town.** Its own header says it is
"the check that would have caught `stage.SPAWN_TILE`'s own recorded accident". **The stage has no twin.**

⇒ **This design adds it.** Against a pristine `Stage.build_terrain_into(g)`: the cell under the spawn box is
solid, the spawn box itself is free (32px tall = the row above matters, `net_town`'s own note), and the spawn
is horizontally connected to the bull's row. **A redraw is the one operation that breaks this, and this doc is
a redraw.**

### 3. Clumps — **3, not 4, and the geometry chose that**

- Clump territory is the retained flat minus the opening stretch: **`x14–89`, 76 tiles ≈ 2.5 screens**
  (viewport 960×540 = 30×16.9 tiles). The `0–10` "you get to look at the world before it wants anything"
  opening (`monster-placement-stage1.md` §2) is kept.
- ~~**A clump's footprint is its shelf: ~11 tiles**~~ ⚠ **Wrong, and it was wrong by this doc's own arithmetic.**
  `monster-placement-stage1.md` §3's **3-tile authoring gap** makes 6 rows **15 tiles wide at the absolute
  minimum**, and an 11-tile shelf holds only 4 of them (offsets 0·3·6·9; a 5th at 12 overhangs the east edge
  and `resolve()`'s full-width footing check refuses the row permanently). The shelf is the clump's *floor*,
  never its *footprint*.
  ⇒ **As built: clumps are 16 tiles — 2 rows on the approach ground, 4 on the shelf.**
- ⚠ **So the quiet is smaller than this section promised.** 3 × 16 = 48 tiles of clump inside the 76-tile
  territory leaves **28 for two gaps, and they came out 15 and 12**, not ~21 each. Centres are 31 and 28
  apart, which is the one number that survived.
  **The gaps are uneven because of the slab**: §9 forbids a shelf under `tx49–50`, which is exactly where even
  spacing puts clump B, so B starts at `x51` and the western gap absorbs the offset.
- **"One clump = one screen" was wrong.** The honest statement is **one clump per screen** — the clump is
  16 tiles, the screen is 30, and the rest is quiet.
- **A fourth clump does not fit with quiet worth the name** — and at 16 tiles it does not fit at all: 4 × 16
  is 64 of 76 tiles. The stairs are not an alternative home for it (§7).

**Every mob is a pre-placed row in `stage1_monsters.gd`, as today. Nothing is trigger-spawned.** "배치되어
있는 게 가장 좋지 않을까" — the quiet approach is why clumps are made of *sleeping placed rows* rather than a
spawner. The user wants the **"우르르"** arrival; they do not want mobs materialising out of air.

### 4. Stone shelves — **2 tiles up, and solid to the ground**

**The height is the user's requirement read literally: "올라가기 편할 듯" — a comfortable hop.**

An earlier draft of this doc put the shelf at 3 tiles to buy clearance underneath. **This doc's own measurement
killed that**: the *measured* jump ceiling is **102px** (`character.gd:105-111`, headless, at
`JUMP_CUT_RATIO` 0.2 — the 108px in `character.gd:82` is the formula, and
`stage1-map-layout.md`'s verify-read pass measured the same 102px independently). A 96px rise leaves **6px**
and demands a near-full hold. **That is not a comfortable hop, so 3 tiles is out.**

| | |
|---|---|
| **Material** | ordinary `STONE`. §"No sixth material" below |
| **Top surface** | **64px = 2 tiles above the local ground.** Terrain is authored in tiles, so 64px and 96px were the only two candidates — **there is nothing in between** |
| **Body** | **solid stone all the way down to the ground.** Vertical sides, flat top. No under-space |
| **Width** | **≥10 tiles**, with **≥240px (7.5 tiles) of shelf west of the hen** — the approach side. Forced by §8 |
| **Breakable** | yes, because stone is. **Not a feature this doc claims** — "blow the shelf out from under them" is **explicitly deferred by the user** |

#### The hop, in the measured table

`character.gd:105-111`, at the shipped `JUMP_CUT_RATIO` 0.2:

```
hold 0.05s (3F)  -> 38px       hold 0.17s (10F) ->  89px
hold 0.10s (6F)  -> 64px       hold 0.25s (15F) -> 102px
```

**A 0.10s press clears 64px exactly, and everything above it clears with slack — up to 38px at a full hold.**
That is the shape the user asked for: press, don't hold, and you are up. (At 96px, only the last row of that
table would have worked.)

#### Solid to the ground — **three problems solved by one authoring decision**

The choice was: fill the shelf's underside to the ground, tuck it against a cliff face, or leave an under-space
too small for any mob to enter. **Fill it.** The reasons, in order of weight:

1. **`resolve()` needs no change at all — the whole `ty`-hint problem disappears.**
   `monster_placement.gd:102-129` starts at `floor_cy` and climbs **while the cell above is solid**. On a
   filled shelf's column that climb runs from the map's bottom row, through the ground, through the shelf, and
   stops at the shelf's top surface. **The hen resolves onto the shelf with today's code, unmodified.**
   A *floating* shelf would have needed a new column in the table, a new `used_hint` return value, an
   author-time-vs-runtime rule split, and a reopening of `stage1_monsters.gd:3-5`'s "**`y` is never written
   down**" principle. **All of that is gone.** (The upward scan is exact here because this map has no caves —
   `monster_placement.gd:86`, verified over all 400 columns.)
2. **Nothing can walk under it, so nothing can be head-caught by it.** A 1-tile-thick floating shelf leaves
   32px of clearance and `h_px(KIND_HEN)` is **64** — every shelf underside would have been a wall for hens,
   and a blocked grounded mob *jumps*, so the symptom is a hen pogoing under a slab forever with no error.
   Filling removes the space rather than measuring it.
3. **It is diggable in a way a floating slab is not.** The player can blow a tunnel through it at ground level
   (`blast_rd(0)` = 8 cells = 32px against a 64px body), which is this game's thesis applied to the new
   terrain instead of exempted from it.

**Rejected: a cliff nook.** The flat has no cliffs; authoring them to hold shelves inverts the terrain into
trenches and reads as a different feature entirely.
**Rejected: pillars with gaps too narrow to enter.** The narrowest mob box is the pig at 44px wide, so the
gaps would have to be under 1.4 tiles — that is a filled shelf with decorative holes, at the cost of a rule
nobody can check by looking.

#### **Does it still read as a platform, or is it the "ground mound" the user rejected?**

**The user rejected a mound as a replacement for a platform. This is not that, and the difference is
mechanical, not cosmetic:**

- **A mound is walkable. This is not.** `Character.STEP_CELLS` is 2 = **8px** of automatic step-up
  (`character.gd:74-75`). A 64px vertical face is a wall to that. **The only way onto it is the jump** — which
  is the entire affordance the user was asking for when they said 올라가기 편할 듯.
- **It is the mobs' wall too, by 3px**, so the hen on top is genuinely separated from the ground fight — the
  job the floating shelf was invented to do (§"Containment" below).
- What "mound" would have meant is a **sloped pile you walk up**, which erases both of those. Vertical sides
  keep them.

⚠ **This is the one place this doc walks back toward a shape the user rejected once, and it is a screen
judgment, not a value.** Acceptance 3 names it explicitly so it gets looked at rather than assumed.

#### Containment — **the assertion already exists; do not write a second one**

Mob jump apex is **61px measured** (`monster_defs.gd:58-67`, driven against a wall), against a 64px rise.
**That margin is already pinned as a value**: `net_monster.gd:1044-1045` computes
`PIT_2TILE_CELLS * CELL_PX − apex_px` and asserts `t.eq(margin_px, 3, ...)`. **A 2-tile shelf and the 2-tile
pit are the same geometry**, so that one check already covers the shelf, and its own comment already says it
must bark the day the apex moves. **Restating it here would be a value counted in two places.**

#### Hens on shelves need no new combat code — verified

`monster.gd:297` stops the hen at `MonsterBolts.BOLT_STOP_PX` (240px, `monster_bolts.gd:50`),
`monster.gd:443` gates its fire on the same distance, and **`world_step.gd:334` aims the bolt with a full 2D
`(center − m.center()).normalized()`** — so a hen on a shelf shoots **down** at a player at its foot without
one line being written.

### 5. **The cap bug is live today, and a row-count convention is not a fix**

`stage1_monsters.ROWS` holds **exactly 20 trash rows before `tx245`** (counted: 11 pig · 7 hen · 2 wolf).
`MonsterDefs.MAX_MONSTERS` is 20. `world_step.gd:557` is `if _monsters.size() >= MAX_MONSTERS: return 0`.
`monster_placement.gd:214-219` **never spends a row on refusal** — it retries, silently, forever.

⇒ **A player who kills nothing on the left run arrives at the pit with 20 live mobs, the bull's row is
refused, and the midboss does not exist.** The fire rune is behind the bull and the wood wall is behind the
rune. **No error is raised anywhere.** This is CLAUDE.md's signature fake in its exact local shape, and it is
in the build right now.

**Keeping the row count low is not the fix.** "18 rows so it fits" is a convention a future edit deletes by
adding one row, and it is CLAUDE.md's "swallowing an error so it looks like success" — the failure mode stays
exactly as silent, it just needs one more row to fire.

**The fix: `spawn_monster` reserves slots for boss rows, and barks if a boss is still refused.** Both, not
either:

- **The reserve is the actual repair.** `BossAi.has_pattern(kind)` is already this repo's boss gate
  (`monster.gd:293`, `net_monster_placement.gd:653`) and needs nothing new. In the one door: a **non-boss**
  kind is refused at `MAX_MONSTERS − reserve`; a boss kind is refused only at `MAX_MONSTERS`. A boss always
  has a slot, so the chain cannot break.
- **The reserve count is derived, not typed.** `set_rows()` already walks the pushed table; the number of
  boss-kind rows in it *is* the reserve. Stage 1 has two (bull, rooster). A hand-typed `2` is the same
  convention this section just rejected, one level down.
- **The bark is the backstop.** With the reserve in place a refused boss row can only mean the reserve is
  wrong — which is exactly when a `push_error` is worth its cost. It is unreachable in a correct build, which
  is what a guard should be. `push_error` alone would have been honest and still shipped a game where the
  fire rune is unreachable; **"say you can't" is about not lying, not about leaving the stage broken.**

⚠ **Known hole — the bark is unmeasurable by this harness, and the green beside it does not cover it.**
`t.expect_error` (`tests/run_nets.gd:153`) is `print("[EXPECT] %s")` and nothing else: it hands the wrapper
an **amnesty** so a legitimate bark does not fail the silence check. **It never asserts that the bark
happened.** So `_a_boss_refused_at_the_real_cap_barks` measures only the half that returns 0 — **delete the
`push_error` line outright and that check stays green.** Confirmed by reading the runner, not assumed.

**This is a harness gap, not a code gap**, and it is deliberately not worked around here: a net that greps
`world_step.gd` for the string would be CLAUDE.md's "a check that greps a file measures its text, never what
it computes", which this repo has been evaded on five times in one feature. **The honest record is that the
reserve is measured and the backstop is not.** Whoever gives `expect_error` a "and it must actually fire"
mode closes this and several others at once — that is `harness-manager`'s, not this doc's.

**And the net that should have caught it is one comparison too loose.**
`net_monster_placement.gd:648-658` (`_pre_stage1_row_count_stays_under_the_cap`) asserts
`pre_count <= MAX_MONSTERS` — 20 ≤ 20, green, while 20 trash + 1 bull = 21 is the number that matters. It also
only counts rows, which is the convention this section rejected. ⇒ **tighten it and add a driving check**: fill
the world to the trash ceiling, wake a boss row, and assert `monster_count()` rose **and** the boss is live.
*Inversion: remove the reserve branch and that goes red.* The row-count check stays as the cheap sibling, with
its bound corrected to `MAX_MONSTERS − boss_rows`.

### 6. Counts, and the level-up argued rather than asserted

**3 clumps × 6 = 18 trash rows before the bull.** With the §5 reserve, the worst case is 18 trailing mobs
+ the bull = 19 live, and the bull's slot is structural rather than lucky.

`progress.xp_for_level` = `60 + 30·level` ⇒ cumulative **60 / 150 / 270**.

| | today | after |
|---|---|---|
| Pre-① rows | **20** (11 pig · 7 hen · 2 wolf) | **18** |
| XP for a full clear | **204** (slack 54 over level 2) | ⚠ **192** (11 pig · 5 hen · 2 wolf; slack 42) |

⚠ **"~189" was unreachable, and this section's own invariants are what make it so.** The teaching order
below puts pigs and nothing else in clump A, which is **72 by arithmetic** (6 × 12), and ≥60 each for the
other two floors any legal run at **192**. **192 is not merely the closest — it is the unique minimum**:
`4 pig · 2 hen` and `1 pig · 3 hen · 2 wolf` are the *only* 6-row mixes that hit exactly 60, so the whole
table below is forced once "18 rows, 3 clumps of 6, pig-only first, ≥60 each" is fixed.
**The example mix "9 pig · 6 hen · 3 wolf" cannot be split into three legal clumps at all** — 72 + 60 + 57.
As built the mix is **11 pig · 5 hen · 2 wolf**, which is today's table minus exactly two hens.

**The decision doc's reopen condition is "one level-up before ①" — level 1, 60 XP, not level 2.** The real
risk it names is not the total; it is that **a clump is easier to skip than an even spread.** With mobs one at
a time you fight because it is cheap; with three clumps, skipping one discards a third of the run's XP in a
single decision. And nothing forces the fight: the player at 260px/s outruns the wolf (240), the hen (220) and
the pig (160).

⇒ **The invariant is per clump, not per run: every single clump is worth ≥60 XP on its own**, so **one**
engagement levels you. Six mobs make that easy without distorting the mix — 6 pigs = 72, and the teaching
order (pig alone → pig+hen → pig+wolf) survives. A clump that came out at 2 pig · 3 hen · 1 wolf = 57 would
fail it, which is exactly the accident the invariant exists to catch. **This is a check on the table**: group
rows by clump, sum `xp_of`.

**It is still not a guarantee, and this doc does not claim one.** A player can skip all three. The decision
doc's reopen condition stays open until someone plays it — which is what Acceptance 9 says, in the words that
doc used: **played, not computed.**

### 7. **No clump on the stairs** — three separate reasons, all measured

The stairs (`x90–129` after the cut) are the only other height on the left run, so they look like a home for a
fourth clump. They are not:

- **A step is 8 tiles wide**, and a 4-mob clump at `monster-placement-stage1.md` §3's 3-tile authoring gap
  needs ~12. It does not fit on one step.
- **Straddling a seam is fatal to the row, permanently.** `monster_placement.gd:119-125` requires every cell of
  the footprint to be solid at the resolved row; a 2-tile drop at each seam fails it, and
  `wake_scan` (`monster_placement.gd:207-212`) **spends the row for the rest of the run.** `tx294` and `tx311`
  exist in the table today for exactly this, at 2-tile and 3-tile seams.
- **Anything on the stairs leaves and never returns.** Mob apex is 61px against a 64px step, so a woken mob
  walks *down* the stairs after the player and into the bull room. The stairs would quietly feed the bull
  fight, which is the same accident `monster-placement-stage1.md` names for the `265–290` buffer.

⇒ **The stairs stay empty.** They are already the run's descent; they do not need mobs to be interesting.

### 8. **A dormant row is invisible, and the stir band walks hens off their own shelves**

Two problems in the same mechanism.

**(a) You cannot see a sleeping clump today.** A row that has not woken is *data* — there is no `Monster`
object, so `monster_view` draws nothing. `wake_scan` turns the row into a live monster at `WAKE_PX` 720, and
`world_step.gd:286` updates the live monster's sleep from **the same 720/840 band** — so the monster it just
created is awake on the first tick it exists. **Row → live → walking, in one step, off screen.** "You see the
clump from a distance while it sleeps" is not a thing this build can do.

**(b) A stirred hen immediately walks toward the player.** `_dist_to_target` is **horizontal only**
(`monster.gd:324-325`), and the hen walks until within `BOLT_STOP_PX` 240px. Stir it at 480px with the player
standing still and it covers the full 240px — off any shelf shorter than that.

⇒ **Three constants, and the shelf carries the hen's own stopping distance:**

| | Value | Why |
|---|---|---|
| **Materialise** | one threshold, **no hysteresis**, far enough to be off screen at zoom 1.0 | A row never returns to dormant — `wake_scan` short-circuits on `_monster_id[i] != 0` **forever**, and only death clears it. The `_primed` hysteresis today governs only *how often a refused row re-knocks*, which its own header says (`monster_placement.gd:26-30`); with §5's reserve, refusals are gone |
| **Stir enter / exit** | two values, hysteresis, **inside the half-viewport** so the player watches it happen | This is the live monster's `asleep`, flipping every tick without a band |
| **Shelf** | **≥240px (7.5 tiles) west of the hen** ⇒ ~10 tiles with the hen toward the east end | The binding constraint. West is the approach side, and the worst case is a player who stops and lets the hen close the whole 240px |

**The hen does eventually walk off the east end, and that is intended.** Once the player passes underneath and
keeps going east, the hen follows and drops down after them. **Acceptance 6 is scoped to the approach and the
fight**, which is when the shelf is doing work; a hen that comes down to chase you afterwards is the mob
behaving, not the shelf failing.

**Materialising earlier costs nothing on the cap** — nothing returns to dormant, so it changes *when* rows go
live, never how many are live at the end. §5's ceiling is untouched.

**`stays_active()` is not split into two functions.** `monster_placement.gd:19-38` argues deliberately for one
hysteresis step with two audiences, and that argument still holds — what changes is that the two audiences now
want **different numbers**. ⇒ **the band becomes arguments** (`stays_active(was_active, dist, enter, exit)`)
and there is still exactly one hysteresis step in the repo. Two copies of the comparison is what that header
was written to prevent, and it stays prevented.

**Do not couple any band to zoom.** `-` zooms to `ZOOM_STEPS` 0.075 (a 12,800px view) where everything
materialises on screen. `monster-placement-stage1.md` already named this and declined to fix it, correctly:
zoom is a shell debug axis and `world_step` must not learn about it.

### 9. The floating bedrock slab survives the cut

`tx149–150` is a 2×2 bedrock slab at `ty15` over ground at `ty20`. It is **pinned twice**
(`net_monster_placement.gd:125-140` synthetic, `:611-628` on the real map) as the proof that `resolve()`
scans **up** and ignores floating blocks. Deleting `x2–101` keeps it; it lands at **`tx49–50`**.

**With the shelves filled to the ground (§4), it is the only floating rock on the run**, so the "two kinds of
floating rock teaching opposite things" conflict an earlier draft worried about does not arise.
**One placement rule remains: no shelf directly under it.** The slab's underside is 5 tiles up (160px); a
shelf top at 64px leaves 96px of headroom, and a player jumping 102px from the shelf would clip a ceiling of
unbreakable bedrock for no reason anyone can read.

**It is not the landmark this run needs.** verify-look measured bedrock at `(35,34,40)` against sky at
`(14,14,19)` — 21 per channel — and recorded that bedrock against sky is effectively invisible.
**The shelves are the landmarks; the slab is a net fixture that happens to be in the scenery.**

---

## Screen

**Two new things. One has no code at all.**

1. **Shelves.** They draw for free — `STONE` through the existing cell renderer. What is judged is whether a
   2-tile block with vertical sides **reads as a platform you hop onto** rather than as a lump of terrain
   (§4's flagged risk), and whether a hen on it reads as a threat worth climbing to.
2. **A clump waking.** **The one thing here with no existing code.** The requirement is single: **the player
   can tell a clump woke up.** `monster_view` never reads `asleep` (grepped: zero hits in `src/view/`), so a
   sleeping mob and a walking one are drawn identically.

### Three options, with cost — **the pick is TBD**

| | What it looks like | Cost | Risk |
|---|---|---|---|
| **A · tint** | Asleep mobs draw dimmed; on stir they snap to full colour with a one-frame flash | **Cheapest.** `monster_view` reads `asleep`, one modulate + flash constant in `fx_tuning.gd`. No art, no sim | A dim mob against a near-black sky may read as "far away" or as nothing |
| **B · a staggered mark** | A short mark over each mob as it stirs, **staggered by row index** so the clump wakes as a ripple rather than a switch | **Medium.** A short-lived view effect plus a per-monster timer; the death ring (`fx_tuning.gd:412`) is the shape to copy | A new timed view state is the exact thing that ships drawing nothing |
| **C · a sleep pose** | Each kind gets a crouched frame and physically **stands up** on stir | **Most expensive — art**, a sheet per kind. `Fx.MONSTER_ANIM` falls back to `MON_IDLE`, so a missing sheet degrades quietly | Regenerating a matching pose per kind is `monsters-bigger-boxes.md`'s "the seeds cannot reproduce the beast" |

**A and B compose.** The user has not picked and this doc does not pick for them.

### The headless half of "you can tell it woke" is concrete, whichever is picked

**"`_draw()` ran" is not "anything was drawn"** — and the remedy is in this repo already.
`gate_view.gd:67` cuts `_paint(tex, rect)` out of `_draw()` precisely because GDScript **refuses to override a
native `CanvasItem` call** (a hard parse error), and `net_gate.gd:452` asserts the texture and the rect it was
handed.

⇒ **`monster_view` gains a hook of that shape — and it must not be called `_paint`**, which is already taken
at `monster_view.gd:196` by an unrelated shader-uniform setter. **`_paint_wake_mark(center: Vector2, age: float)`**
or whatever the build prefers, one name, not overloaded.

**The check**: tree a `MonsterView`, `t.pump_frames`, subclass overriding the hook — assert it fires **once
per stirring mob at that mob's own centre**, and **not at all** for a mob that was already awake.
*Inversion: delete the call from `_draw()` and it goes red.*

---

## Bounds

| Situation | What must happen |
|---|---|
| **Trash rows + boss rows exceed 20** | **The boss still spawns**, because the reserve is structural (§5). Not a row-count convention |
| **A boss row is refused anyway** | `push_error` — unreachable in a correct build, which is what makes it worth having. ⚠ **And no net can see whether it is still there** — see the box under §5 |
| **A hen row sits on a shelf** | **Resolves with today's code**, unmodified — the upward scan climbs the filled shelf to its top (§4) |
| **A trash mob tries to climb a shelf** | Cannot, by **3px** — and that margin is already asserted at `net_monster.gd:1044-1045`, not restated here |
| **A mob walks into a shelf's face** | It is blocked and it jumps, reaching 61px against 64px — **it visibly almost makes it.** Same behaviour as any wall on this map; new only in how often it happens |
| ⚠ **The player walks east into a shelf** | **They stop, and the only way on is the hop.** A shelf is 11 tiles of solid ground from row 18 down, standing on the flat the player walks along — it is not beside the path, **it is across it.** `Character.STEP_CELLS` is 8px against a 64px face, so **the run to the stairs is three hops, not a walk**, and there is no way around: the shelf spans the full corridor height at those columns |
| **The player stands on a shelf** | Pigs and wolves cannot reach them. **That is a real safe spot and it is deliberate** — the hen on the same shelf is what contests it. Judged on screen (Acceptance 5) |
| **The player reaches a shelf with a short tap** | 3F = 38px fails, **6F = 0.10s clears 64px exactly**, a full hold clears by 38px. The hop starts at an ordinary press |
| **The player digs a tunnel through a shelf** | Allowed and expected — `blast_rd(0)` is 32px against a 64px body. Terrain stays open (Noita-style, the user's word this round and last) |
| **A mob is inside a space that then closes** | **Cannot happen. In play, solid cells only ever become empty** — spells carve, fire turns `WOOD` to `EMPTY`, and `WATER` is `BEHAVIOR_NONE` so it is not solid (`cell_materials.gd:99`, `cell_grid.gd:1029-1030`). Nothing wedges, ever |
| **The player walks back west** | Two tiles of flat and the map wall. **There is no dead map behind the spawn** — that is what the cut buys |
| **Zoom-out (`-`)** | Every clump materialises on screen. **Do not couple any band to zoom** |
| **A woken clump is left behind** | Stays live forever. Nothing returns to dormant; §5's ceiling counts it |

⚠ **That row was missing entirely, and it is the one most likely to surprise the user on the first walk.**
It follows from §4 — vertical faces, solid to the ground, 64px, "the only way onto it is the jump" — but §4
argues all of that as *how you get **onto*** a shelf, never as *what happens if you would rather not*. The
two are the same fact seen from opposite sides, and only the first was written down. **Anything that assumed
a clear walk from the spawn to the stairs is wrong**, including the walk-time arithmetic in §1's table:
**17.5s is the distance divided by `MOVE_SPEED_PX`, and it does not include three hops.** Acceptance 1 says
"driven, not computed" for exactly this reason and has not been driven.

**This is not presented as a defect.** Three forced hops across the flat is a vertical axis in the most
literal sense, which is what the user asked for. **But it was never decided — it fell out**, and it is the
kind of thing that reads very differently in a doc than under your hands.

---

## Interaction with what exists

| What | How |
|---|---|
| **`docs/decisions/mobs-lie-on-the-map-no-arena-room.md`** | Its "clumps rejected" row is reversed; everything else stands. **The spawner files that** — not this doc, not the build |
| **`src/stage/stage.tscn` `Terrain`** | Where the 100 columns are deleted and the shelves are painted. **The `.gd` is a re-export, never hand-edited** |
| **`src/stage/terrain_map_generated.gd`** | Rewritten by the bake. `MAP_W` 400 → 300 comes free from `get_used_rect()` |
| **`src/stage/stage1_monsters.gd`** | Pre-① rows **re-authored wholesale** (18 rows, 3 clumps); rows east of the cut shift −100. **Still `(tx, kind)` — no new column** |
| **`src/actor/monster_placement.gd`** | **`resolve()` is untouched** (§4). Only the band constants change (§8) |
| **`src/actor/world_step.gd`** | The boss reserve in `spawn_monster` (§5); the three-constant band (§8) |
| **`src/stage/stage.gd` · `src/actor/stage_gate.gd`** | Hardcoded stage-1 cell/tile constants shift −100 (§1's table) |
| **`src/view/monster_view.gd` · `fx_tuning.gd`** | The awakening presentation and its `_paint`-shaped hook. `src/view/` holds every presentation constant |
| **`src/sim/`** | **Untouched.** No new material, no new integer axis. `net_determinism` must not move |
| **Nets** | `net_water_rain` · `net_gate` · `net_monster_placement` re-derived (§1); a **new** stage spawn check (§2); the cap check tightened and driven (§5). **`net_monster.gd:1044-1045` already covers shelf containment** |

### No sixth material — and **the palette is not the reason**

An earlier draft said a pass-through platform material would cost palette slots. **That is wrong.**
`src/view/cell_grid.gdshader:11` fixes `uniform vec4 palette[16]` and `cell_materials.ALL` uses **5**.
**Eleven slots are free.** The real reasons:

- **`is_solid()` is binary and derived**: `cell_grid.gd:1029-1030` is
  `_behavior[mat_at(x,y)] == BEHAVIOR_STATIC`. A one-way platform is not binary — solid to feet falling, empty
  to a body rising or passing sideways. That needs a third behavior **and every physics reader to learn the
  direction of travel**: `body.gd`'s grounding, `box_free`, `move_x`/`move_y`, `monster_placement.resolve`,
  `monster_bolts`, `staff`. **That is a sim-wide axis in the integer-determinism folder**, for one platform.
- **The authoring chain grows too**: `terrain_baker.gd`'s `CHAR_BY_MAT`/`NAME_BY_MAT` (named in
  `terrain_map_generated.gd`'s own header as the two tables to extend), plus rebuilds of
  `build_terrain_atlas.gd` and `build_terrain_tileset.gd` and an `--import` pass.

⇒ **Ordinary `STONE`.** Filling the shelf to the ground (§4) is what makes that survivable — there is no
under-space for the solid/pass-through distinction to matter in.

---

## Cost

**Small, and mostly authoring.** Every heavy mechanism already exists and is already measured.

| | |
|---|---|
| **Terrain — the cut** | Delete 100 uniform columns via the ASCII door, bake. **Not a day's work** |
| **Terrain — the shelves** | 3 × (11 wide × 2 tall) = **66 tiles painted.** As built, exactly that |
| **Coordinate re-derivation** | ~~Six sites~~ ⚠ **Ten** — the four §1 missed. Still all mechanical, and `net_water_rain` carries its own written procedure |
| **Table** | 18 pre-① rows replacing 20, plus a `−100` pass over the rest. **No schema change** |
| **Code** | The boss reserve (one branch in one door), three band constants, and the awakening hook. **`resolve()` unchanged** |
| **Frame cost** | **Goes down.** Peak live at the pit drops 20 → 19 and the run carries 2 fewer trash mobs. **Do not restate the numbers here** — the measured per-kind table is `monster_defs.gd:143-149`, re-taken with `tools/stage/profile_monsters.gd` |
| **Materialising earlier** | **Zero on the ceiling** (§8). It moves some sleeping cost earlier in the run, and a sleeping mob is not free — same table |
| **Awakening presentation** | **A ≈ free · B a small view effect · C an art job.** The only line that varies by an order of magnitude, and it is the TBD |
| **Sim** | **Nothing** |

### What the round actually costs — **measured, and CLAUDE.md's figure is stale**

Recorded here because it was measured here, and because **the stale number is in a file this build must not
edit** (CLAUDE.md is not a teammate's to change).

| | CLAUDE.md says | Measured, both sides of this feature |
|---|---|---|
| A round | ~14s | **29.8s before · 24.4s after** |
| The long pole | `net_water`, 12.4s of it | **`net_gate`, 29.7s before · 24.3s after — it *is* the round** |
| `net_water` | 12.4s, deliberately slow | **14.4s**, still deliberately slow, no longer the pole |

**This feature did not cause it and did not fix it** — `net_gate` dominated the baseline taken before the
first line was written. The round got *faster* across this work, which is the two rows the table lost.
⇒ **`net_gate` is `harness-manager`'s**, and CLAUDE.md's "call harness-manager when a round grows for any
other reason" has been true and unnoticed for some time. **Not called tonight on purpose**: two other tracks
were writing into `tests/`, and a harness change mid-flight makes every red unattributable.

---

## Acceptance

1. **The walk to the bull is ~17s, not 30** — driven, not computed
2. **There is no walkable map behind the spawn** — the wall is two tiles west
3. **A shelf reads as a platform, not as a lump of ground** — §4's flagged risk, and the only thing in this
   doc that walks back toward something the user rejected once
4. **You get onto a shelf with an ordinary press** — not a held one, not a frame-perfect one
5. **A clump reads as a clump, and standing on the shelf is contested** — six mobs at once, then quiet;
   pigs below cannot reach you and the hen above can
6. **A hen on a shelf shoots down at you and is still on its shelf while you approach and fight** — the 240px
   rule. Following you down afterwards is expected, not a failure
7. **You can tell a clump woke up** — by eye for the look; by the `_paint`-shaped hook headless (§Screen)
8. **The bull always appears.** Kill nothing on the whole left run, walk to the pit, and it is there.
   *Also driven headless: fill to the trash ceiling, wake the boss row, assert it lives*
9. **One level-up before the bull** — **played, not computed.** The decision doc's own reopen condition
10. **The spawn is on ground and connected to the bull** — the check that does not exist today (§2)
11. **`net_water_rain` is green with re-derived constants**, and the pit fills exactly as before
12. **Nothing is locked** — the player can walk back, and dig anywhere that is not bedrock

---

## TBD — **four were closed by building, and by whom**

**The user was asleep and the deadline was the same day, so these were closed by the build, not by the user.**
That is recorded here rather than presented as settled: **every row below is reversible on sight**, and the
last two were never the build's to close.

| Was TBD | Closed as | Who decided |
|---|---|---|
| **The exact clump table** | A `tx14–29` **6 pig** · B `tx45–60` **4 pig 2 hen** · C `tx73–88` **1 pig 3 hen 2 wolf**. Shelf rows sit at offsets 6·9·12·15, ground rows at 0·3 | **Forced**, not chosen — §6's invariants leave exactly one legal table (see the ⚠ box in §6) |
| **Exactly where each shelf sits** | `x20–30` · `x51–61` · `x79–89`, top row 18, 11 wide | Build. Constrained by §9 (nothing under `tx49–50`) and by the stairs at `x90` |
| **Which awakening presentation** | **A + B** — dormant bodies dim, and a staggered ring pops at the stir | **Build, and this one is the user's to take back.** The doc says "the user picks" and they were asleep. A+B is what the doc itself calls composable; **C was not attempted** (a sheet per kind) |
| **The three band values** | materialise **720** (`WAKE_PX` keeps that job) · stir enter ~~420~~ → **300** · stir exit **560**. `SLEEP_PX` 840 is gone | Build, then **moved after verify-look**. The ceiling is the shelf (§8b: `stir − 240` px of walk against 288px of shelf ⇒ **528**). The floor is being seen: a mob becomes visible at **552px**, not 480 — the camera lead adds 72 — so the dormant tint and the wake mark are only watchable across `552 − stir`. **420 gave 0.51s; 300 gives 0.97s.** ⇒ **lowering widens the window, raising shrinks it**, which is the opposite of the obvious reading and is why this row moved |

**Still open, and neither is the build's:**

- **Whether a 2-tile block reads as a platform on screen.** Acceptance 3. If it reads as terrain, the fork is
  a floating shelf plus the `ty`-hint work §4 just deleted — **do not take that fork without the user**
- **"Blow the shelf out from under them"** — **the user deferred it. Later, not here**

**And one thing the build learned that was never a TBD**: the shelves are **across** the path, not beside it
(the ⚠ Bounds row). Nobody decided that; it fell out of §4. It is the first thing to look at.
