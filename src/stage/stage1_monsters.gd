extends RefCounted
## Stage 1's monster placement table — `docs/plans/3.done/monster-placement-stage1.md`, Stage A.
## `(tx, kind)` rows only. **`y` is never written down** — `MonsterPlacement` (`src/actor/`) finds the
## ground by scanning **up** from the map's bottom row at wake time, so a terrain redraw cannot rot a
## hand-typed `y` (the doc's own §1: "hand-written y values silently rot the moment a slope moves").
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
## **Why the pre-① total is 20, not the design doc's original 24** (its own "What the user has to
## decide", item 1): `net_monster._defs_accessors` asserts `MonsterDefs.MAX_MONSTERS == 20` as a literal,
## and 24 rows all wakeable by the time a player who kills nothing reaches ① (activation half-width
## 720px, well inside every zone's own width) would refuse the last 4 with **no error at all** — not a
## crash, just monsters that quietly never appear. **The user's call**: cut to ≤20 rather than raise the
## cap. **One row cut from each of the four pre-① zones, not a whole zone deleted** — deleting a zone
## would either break the teaching order (pig -> hen -> wolf) or erase a zone's own rhythm; a single row
## per zone keeps both. **The row that first introduces a kind into the run is never the one cut** — a
## pig alone, then pig+hen, then pig+wolf still happens in exactly that order, only slightly thinner.
## Cut, one each: a pig from Warm-up A, a pig from Warm-up B, a wolf from Warm-up C, a hen from Approach.
##
## **Zone ② (real usable range 290–344, not the design doc's 290–355 — spec's own correction: 345–355
## sits under room ③'s roof, `ty12`, not on ②'s own floor) is placed here, fully, and stays dormant in
## this build.** The step from ①'s pit floor (`ty32`) to ②'s shelf (`ty26`) is 6 tiles against a
## 3.375-tile jump (`character.gd:91-92`) — not walkable in a normal run until
## `docs/plans/2.active/water-jump-and-escape.md` lands. **Placed anyway, per the user's call**
## ("user decision 3" in the same plan doc): there is no reason to ever reopen this table again once
## that door opens — the rows simply start waking the day a player can reach them.
##
## **Bosses ride this same table** — the user's call ("user decision 2"): the rooster has to be
## reachable through ordinary play, not only the debug `C` key, or the stage's own ending stays behind a
## door nobody in a normal run ever presses. Coordinates below are read from measured map data, not
## invented:
##  · **bull, `tx245`** — room ① is `x230–259`, floor `ty32`, flat, measured directly by walking a bot
##    through it (`stage1-map-layout.md`, "값으로 확인"). `tx245` sits mid-room, clear of the left 2-tile
##    step at `x229/230` and the right 6-tile rise at `x260`.
##  · **rooster, `tx358`** — room ③'s exact tile bounds are not separately re-measured here (the map
##    doc's own `x360–380` is stated as approximate, "좌표는 대략값이다"), but this plan's own spec pass
##    computed the real terrain profile of `terrain_map_generated.gd` directly and found `tx345–368`
##    sitting under the room's roof (solid at `ty12`) with `tx350` resolving to floor `ty25` (surface
##    `ty24`) — **inside the room, not on the roof**. `tx358` sits inside that same confirmed span,
##    clear of both `tx345` and `tx368`'s edges.
##
## **Totals**: pre-① 11 pigs · 7 hens · 2 wolves = 20 · ① 1 bull · ② (dormant) 6 pigs · 4 hens · 2 wolves
## = 12 · ③ 1 rooster. 34 rows.
const ROWS: Array[Dictionary] = [
	# -- Warm-up A (10-60): pig alone. The first mob the player ever meets. --
	{"tx": 20, "kind": MonsterDefs.KIND_PIG},
	{"tx": 45, "kind": MonsterDefs.KIND_PIG},

	# -- Warm-up B (60-130): the hen's first appearance. --
	{"tx": 65, "kind": MonsterDefs.KIND_PIG},
	{"tx": 72, "kind": MonsterDefs.KIND_HEN},
	{"tx": 82, "kind": MonsterDefs.KIND_PIG},
	{"tx": 92, "kind": MonsterDefs.KIND_HEN},
	{"tx": 102, "kind": MonsterDefs.KIND_PIG},
	{"tx": 112, "kind": MonsterDefs.KIND_HEN},
	{"tx": 122, "kind": MonsterDefs.KIND_HEN},

	# -- Warm-up C (130-190): the wolf's first appearance. --
	{"tx": 138, "kind": MonsterDefs.KIND_PIG},
	{"tx": 148, "kind": MonsterDefs.KIND_WOLF},
	{"tx": 160, "kind": MonsterDefs.KIND_PIG},
	{"tx": 172, "kind": MonsterDefs.KIND_WOLF},
	{"tx": 182, "kind": MonsterDefs.KIND_PIG},

	# -- Approach to ① (190-230): slightly denser, the last stretch before the bull. --
	{"tx": 196, "kind": MonsterDefs.KIND_PIG},
	{"tx": 203, "kind": MonsterDefs.KIND_HEN},
	{"tx": 211, "kind": MonsterDefs.KIND_PIG},
	{"tx": 218, "kind": MonsterDefs.KIND_HEN},
	{"tx": 224, "kind": MonsterDefs.KIND_PIG},
	{"tx": 228, "kind": MonsterDefs.KIND_HEN},

	# -- ① pit (230-259): the midboss. Room measured directly, not the map doc's approximate range. --
	{"tx": 245, "kind": MonsterDefs.KIND_BULL},

	# -- ② combat zone (290-344, the usable range only — 345-355 is room ③'s roof). Dormant until the
	#  water escape lands; see the header above.
	#  **`tx294`, not `tx290`** — measured directly (net_monster_placement, the real map): `285-292` sits
	#  at `ty26` and `293-312` rises to `ty24`, a real 2-tile step at the `292/293` seam. A row resolved
	#  from `292`'s own (lower) column spills its right edge into `293`'s already-solid, higher ground —
	#  `box_free` correctly refuses it as "no headroom". Starting the row inside the higher segment
	#  (`294`, two tiles clear of the seam) avoids straddling it; the whole box then sits in one
	#  uniform-height stretch instead of two. --
	{"tx": 294, "kind": MonsterDefs.KIND_PIG},
	{"tx": 297, "kind": MonsterDefs.KIND_HEN},
	{"tx": 302, "kind": MonsterDefs.KIND_PIG},
	{"tx": 307, "kind": MonsterDefs.KIND_WOLF},
	# **`tx311`, not `tx312`** — verify-read's own finding, measured against the real map with
	#  `resolve()`'s full-width footing check (added because of this exact row): `293-312` sits at `ty24`
	#  and `313-330` drops to `ty27`, a real 3-tile fall at the `312/313` seam. The hen (48px = 1.5 tiles)
	#  placed at `tx312` had its right edge hanging over `313`'s lower ground — 4 of its 12 footprint
	#  cells with nothing solid under them. `tx311` keeps the whole box inside `293-312`'s own uniform
	#  stretch, one tile clear of the seam.
	{"tx": 311, "kind": MonsterDefs.KIND_HEN},
	{"tx": 317, "kind": MonsterDefs.KIND_PIG},
	{"tx": 322, "kind": MonsterDefs.KIND_HEN},
	{"tx": 327, "kind": MonsterDefs.KIND_PIG},
	{"tx": 332, "kind": MonsterDefs.KIND_WOLF},
	{"tx": 337, "kind": MonsterDefs.KIND_HEN},
	{"tx": 341, "kind": MonsterDefs.KIND_PIG},
	{"tx": 344, "kind": MonsterDefs.KIND_PIG},

	# -- ③ boss room (confirmed span 345-368, under its own roof): the stage boss. --
	{"tx": 358, "kind": MonsterDefs.KIND_ROOSTER},
]
