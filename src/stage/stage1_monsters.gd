extends RefCounted
## Stage 1's monster placement table — `monster-placement-stage1.md`, Stage A, re-authored
## for `left-run-clumps-and-platforms.md` (the left run cut by 100 columns, the even
## sprinkle replaced by 3 clumps).
## `(tx, kind)` rows only. **`y` is never written down** — `MonsterPlacement` (`src/actor/`) finds the
## ground by scanning **up** from the map's bottom row at wake time, so a terrain redraw cannot rot a
## hand-typed `y` (the doc's own §1: "hand-written y values silently rot the moment a slope moves").
## **That is also what puts a row on a shelf**: a stone shelf is solid to the ground, so the upward scan
## climbs straight through it and stops on its top surface (`left-run-clumps-and-platforms.md` §4) — a row
## whose `tx` lands inside a shelf's tile span resolves onto the shelf with no new column in this table.
##
## **`src/actor/` cannot preload this file** (`net_layers`) — `stage.gd._build_room()` reads `ROWS`/
## `FLOOR_CY` and hands them down through `WorldStep.set_placement()`, the same "shell pushes it in"
## idiom `_char`/`_grid`/`_progress` already use. `src/actor/` never learns this file's name.
##
## **`const`, not `var`** — this is map content, the same shelf `terrain_map_generated.gd` sits on, and
## being `const` is why `net_pick`'s no-inventory scan (anchored on column-0 `var`) never sees it.

const TerrainMap := preload("res://src/stage/terrain_map_generated.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")

## **Derived, never hand-copied** — a redraw that changes `MAP_H` moves this for free
## (`terrain_map_generated.gd`'s own "not matched by hand" for `MAP_H`/`MAP_W`).
## The last valid cell row of the baked map: 48 tiles * 8 cells/tile - 1 = 383.
const FLOOR_CY: int = TerrainMap.MAP_H * Tuning.TILE_CELLS - 1

## Sorted by `tx` — the gap rule and the wake scan both assume it (`monster_placement.gd`'s own header
## on why an unsorted table would make "adjacent" meaningless).
##
## ══ Pre-① is **18 rows in 3 clumps**, not 20 evenly sprinkled ══
## (`left-run-clumps-and-platforms.md` §3/§6. The old 4-zone sprinkle is gone with the 100 columns it
##  lived on — every pre-① `tx` below is new, not shifted.)
##
## **Clump territory is `x14–89`** — the retained flat minus the `0–10` opening. Each clump is 6 rows:
##  2 on the ground of the approach, 4 on an 11-tile `STONE` shelf 2 tiles up whose east end carries the
##  clump's one hen.
##
## | clump | rows | shelf tiles | mix | XP |
## |---|---|---|---|---|
## | A | `tx14–29` | `x20–30` | 6 pig | 72 |
## | B | `tx45–60` | `x51–61` | 4 pig · 2 hen | 60 |
## | C | `tx73–88` | `x79–89` | 1 pig · 3 hen · 2 wolf | 60 |
##
## **Every clump is worth ≥60 XP on its own** (§6's invariant — one engagement levels you; `net_monster_
## placement` measures it by grouping these rows and summing `xp_of`). Total 192.
##
## **Two numbers in the design doc do not survive contact with this table, and both are its own examples:**
##  · **"~189 XP" is unreachable.** A pig-only first clump of 6 is 72 by arithmetic, and ≥60 each for the
##    other two floors the run at **192**. 192 is the minimum, and it is unique: `4 pig · 2 hen` and
##    `1 pig · 3 hen · 2 wolf` are the only 6-row mixes that hit exactly 60.
##  · **"a clump's footprint is its shelf, ~11 tiles" does not hold.** §3's own 3-tile authoring gap
##    (`monster-placement-stage1.md` §3) makes 6 rows **15 tiles** wide at the very least, and the 4 that
##    fit on an 11-tile shelf leave 2 for the ground west of it. ⇒ **clumps are 16 tiles, gaps 15 and 12.**
##
## **The one hen per shelf is a hard limit, not a taste**: §8 requires **≥240px (7.5 tiles) of shelf west
##  of a shelf hen** (a stirred hen walks until it is `BOLT_STOP_PX` from the player and would otherwise
##  step off its own west edge), so on an 11-tile shelf only the easternmost slot qualifies. Clump B's and
##  C's remaining hens stand on the ground.
##
## **Clump A's shelf carries no hen at all** — §6's teaching order is `pig alone -> pig+hen -> pig+wolf`,
##  so the first clump the player ever meets is pigs and nothing else. Its shelf is the uncontested one:
##  it teaches the hop before anything shoots back.
##
## **No clump on the stairs** (§7) and **no shelf under the floating bedrock slab at `tx49–50`** (§9) —
##  clump B's shelf starts at `x51`, one tile clear of it, which is why the two quiet gaps came out uneven.
##
## ══ East of the cut: every `tx` shifted **-100** and nothing else changed ══
##
## **Zone ② (usable range 190–244 after the cut — 245–255 sits under room ③'s roof, `ty12`, not on ②'s own
## floor) stays dormant in this build.** The step from ①'s pit floor (`ty32`) to ②'s shelf (`ty26`) is 6
## tiles against a 3.375-tile jump (`character.gd:91-92`) — not walkable in a normal run until
## `water-jump-and-escape.md` lands. **Placed anyway, per the user's call**
## ("user decision 3" in the same plan doc): the rows simply start waking the day a player can reach them.
##
## **Bosses ride this same table** — the user's call ("user decision 2"): the rooster has to be reachable
## through ordinary play, not only the debug `C` key. Both are also what `spawn_monster`'s boss reserve
## counts (`world_step.gd`, §5) — **the reserve is the number of boss rows in this table, derived, so
## adding a boss row here needs no second edit anywhere.**
##  · **bull, `tx145`** (was 245) — room ① is `x130–159`, floor `ty32`, flat. Mid-room, clear of the left
##    2-tile step at `x129/130` and the right 6-tile rise at `x160`.
##  · **rooster, `tx258`** (was 358) — room ③'s confirmed span is `x245–268`, under its own roof.
##
## **Totals**: pre-① 11 pigs · 5 hens · 2 wolves = 18 · ① 1 bull · ② (dormant) 6 pigs · 4 hens · 2 wolves
## = 12 · ③ 1 rooster. 32 rows. **Boss rows: 2** — that is `spawn_monster`'s reserve.
const ROWS: Array[Dictionary] = [
	# ══ Clump A (tx14-29, shelf x20-30): pig alone. The first mobs the player ever meets. ══
	#  Two on the approach ground, four on the shelf — the shelf four walk west and drop off it, which is
	#  the "우르르" arrival the user asked for.
	{"tx": 14, "kind": MonsterDefs.KIND_PIG},
	{"tx": 17, "kind": MonsterDefs.KIND_PIG},
	{"tx": 20, "kind": MonsterDefs.KIND_PIG},
	{"tx": 23, "kind": MonsterDefs.KIND_PIG},
	{"tx": 26, "kind": MonsterDefs.KIND_PIG},
	{"tx": 29, "kind": MonsterDefs.KIND_PIG},

	# ══ Clump B (tx45-60, shelf x51-61): the hen's first appearance. ══
	#  `tx60` is the shelf's east-end hen — 9 tiles (288px) of shelf west of it, past §8's 240px.
	#  The second hen stands on the ground at `tx48`, two tiles clear of the bedrock slab at `x49-50`.
	{"tx": 45, "kind": MonsterDefs.KIND_PIG},
	{"tx": 48, "kind": MonsterDefs.KIND_HEN},
	{"tx": 51, "kind": MonsterDefs.KIND_PIG},
	{"tx": 54, "kind": MonsterDefs.KIND_PIG},
	{"tx": 57, "kind": MonsterDefs.KIND_PIG},
	{"tx": 60, "kind": MonsterDefs.KIND_HEN},

	# ══ Clump C (tx73-88, shelf x79-89): the wolf's first appearance. The last fight before the stairs. ══
	#  Shelf slots `79/82/85` are wolf·pig·wolf on purpose — only `tx88` has the 288px of shelf west of it
	#  a hen needs, so the other two hens stay on the approach ground.
	{"tx": 73, "kind": MonsterDefs.KIND_HEN},
	{"tx": 76, "kind": MonsterDefs.KIND_HEN},
	{"tx": 79, "kind": MonsterDefs.KIND_WOLF},
	{"tx": 82, "kind": MonsterDefs.KIND_PIG},
	{"tx": 85, "kind": MonsterDefs.KIND_WOLF},
	{"tx": 88, "kind": MonsterDefs.KIND_HEN},

	# -- ① pit (130-159): the midboss. --
	{"tx": 145, "kind": MonsterDefs.KIND_BULL},

	# -- ② combat zone (190-244, the usable range only — 245-255 is room ③'s roof). Dormant until the
	#  water escape lands; see the header above. Every `tx` here is its old value minus 100.
	#  **`tx194`, not `tx190`** — measured directly (net_monster_placement, the real map): `185-192` sits
	#  at `ty26` and `193-212` rises to `ty24`, a real 2-tile step at the `192/193` seam. A row resolved
	#  from `192`'s own (lower) column spills its right edge into `193`'s already-solid, higher ground —
	#  `box_free` correctly refuses it as "no headroom". Starting the row inside the higher segment
	#  (`194`, two tiles clear of the seam) avoids straddling it; the whole box then sits in one
	#  uniform-height stretch instead of two. --
	{"tx": 194, "kind": MonsterDefs.KIND_PIG},
	{"tx": 197, "kind": MonsterDefs.KIND_HEN},
	{"tx": 202, "kind": MonsterDefs.KIND_PIG},
	{"tx": 207, "kind": MonsterDefs.KIND_WOLF},
	# **`tx211`, not `tx212`** — verify-read's own finding, measured against the real map with
	#  `resolve()`'s full-width footing check (added because of this exact row): `193-212` sits at `ty24`
	#  and `213-230` drops to `ty27`, a real 3-tile fall at the `212/213` seam. The hen (48px = 1.5 tiles)
	#  placed at `tx212` had its right edge hanging over `213`'s lower ground — 4 of its 12 footprint
	#  cells with nothing solid under them. `tx211` keeps the whole box inside `193-212`'s own uniform
	#  stretch, one tile clear of the seam.
	{"tx": 211, "kind": MonsterDefs.KIND_HEN},
	{"tx": 217, "kind": MonsterDefs.KIND_PIG},
	{"tx": 222, "kind": MonsterDefs.KIND_HEN},
	{"tx": 227, "kind": MonsterDefs.KIND_PIG},
	{"tx": 232, "kind": MonsterDefs.KIND_WOLF},
	{"tx": 237, "kind": MonsterDefs.KIND_HEN},
	{"tx": 241, "kind": MonsterDefs.KIND_PIG},
	{"tx": 244, "kind": MonsterDefs.KIND_PIG},

	# -- ③ boss room (confirmed span 245-268, under its own roof): the stage boss. --
	{"tx": 258, "kind": MonsterDefs.KIND_ROOSTER},
]
