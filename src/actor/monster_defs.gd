extends RefCounted
## The monster kind table. The precedent is `src/sim/glyph_defs.gd` — id constants + a `DEFS` dictionary +
##  an explicit `ALL` list + static accessors. **One new kind = one line here.**
##
## What is deliberately not in the table right now — put it in and it reads as "this value is live", and that
##  is a false knob: "how it attacks", "damage taken", "fire DPS" (stages 5 and 6).
##  "Damage taken 10" and "fire DPS 10/s" get no columns in the table —
##  `monsters-minimum`, "behavior (7)" pinned "use the player's constants verbatim. No axes are added".
##
## The stage each column is first read in: `w_px`, `h_px`, `step_cells` and `max_hp` = stage 1 · `speed_px` =
##  stage 2 · `invuln_ticks` = stage 3. `speed_px` went in from the start in order to establish that the box
##  and the gait come from **the same table** — `invuln_ticks` lives here for the same reason (the player has
##  a single constant, monsters can differ per kind so it is a table cell. Both values are 2 ticks right now).

## A reserved value. The death notification arrays (`_died_kind`) and the view carry the kind as an integer,
##  and **if 0 were a valid kind, a cleared slot would silently be drawn as a pig.**
##  Two precedents: `glyph_defs.GLYPH_NONE = 0` ("the end of the list is 0 itself") ·
##  why `spell_view._elem_id` gives -1 for a dead slot ("falling to 0 nearly drew a nonexistent projectile as fire").
const KIND_NONE := 0
const KIND_PIG := 1
const KIND_HEN := 2
const KIND_BULL := 3
const KIND_ROOSTER := 4
## **The wolf** — `docs/design/monsters.md`'s own "the wolf is tawny/chestnut, brighter than the pig and
##  warmer than the dirt" (the user's rule: species are told apart by brightness first). Its art landed with a
##  full animation set and **the row it needed to exist at all is this one** — until now it was "art on disk
##  and nothing more", that doc's own words.
## **It is not assigned to a stage.** Stage 1's pair is pig + hen (that doc's "Stage 1's trash mobs — two"),
##  and **placement is the map's share, not this table's**. Adding the row makes it spawnable and drawable;
##  it does not put one on the ground anywhere.
const KIND_WOLF := 5

## Iteration goes **only through this explicit list**. It does not assume the values are contiguous.
const ALL: Array[int] = [KIND_PIG, KIND_HEN, KIND_BULL, KIND_ROOSTER, KIND_WOLF]

## 20 is a value decided by the user — not a value to measure and adjust.
const MAX_MONSTERS := 20

## `xp`/`money` are **per-kind by nature, not "how it attacks"** — the header above excludes damage-taken and
##  fire-DPS columns because those read as "this value is live" (a false knob), but a pig being worth more
##  than a hen is a plain fact about the kind (`docs/plans/3.done/levelup-and-three-picks.md`, Stage B).
##  Provisional values from that plan's own table — knobs to turn once XP is on screen, not by the user yet.
const DEFS: Dictionary = {
	KIND_PIG: {
		"name": &"돼지", "w_px": 44, "h_px": 32, "step_cells": 1,
		"max_hp": 30, "speed_px": 160.0, "invuln_ticks": 2,
		"xp": 12, "money": 5,
	},
	# **24x28 -> 48x64 when the enlarged art landed** (`monsters.md`: "the trash mobs are too small", the
	#  user's decision, and `hen_body.png` is 48x64). **The picture is what moved this, not a tuning pass** —
	#  the box follows the art because `net_monster_sprite` asserts the two are equal.
	#
	# **A gameplay property was lost with it, and it is not a bug**: at 24px the hen fit through a 32px gap
	#  and the pig did not, which was the narrow-mob-drops-through-a-hole behaviour `net_monster._monster_
	#  collision_width_gates_the_chimney` measured. **At 48px nothing in the table is narrower than the pig**,
	#  so that check now measures the pig against the bull instead. If "one mob slips through gaps" is wanted
	#  back, it needs a *narrow* kind, not a smaller hen.
	#
	# **The cost is 4.6x, and it is measured, not assumed** — see the profile table below.
	KIND_HEN: {
		"name": &"닭", "w_px": 48, "h_px": 64, "step_cells": 3,
		"max_hp": 10, "speed_px": 220.0, "invuln_ticks": 2,
		"xp": 6, "money": 3,
	},
	# **`w_px`/`h_px` are not free here** — `stage1-bosses.md` Risk 1: `net_monster_sprite` asserts the sheet
	#  equals the box, and `net_monster._defs_preconditions` asserts the box is a `Tuning.CELL_PX`(4) multiple
	#  (every other kind already satisfies both). `bull_body.png`'s art came out at 86x54 (4x → downscale,
	#  the trash-mob pipeline), which fails the second contract — so the png was padded to 88x56, the original
	#  86x54 pixels placed unmoved at (1, 2): 1px transparent margin left/right, 2px on top, **0px on the
	#  bottom** (so the feet-on-the-last-row contract carries over, and 1px symmetric each side keeps
	#  `minx+maxx == w-1`). No pixel resampled — this is not the "regenerate, don't scale" case.
	#  `rooster_body.png` (72x80) already satisfied both contracts untouched.
	# `max_hp`/`speed_px`/`xp`/`money` are provisional — `stage1-bosses.md`'s own TBD ("skeleton first, set on
	#  screen"). `invuln_ticks` is carried over unexamined from the trash-mob table.
	# `step_cells` = 3 for both — `net_monster._pig_and_hen_cross_the_ledge_differently` hardcodes a binary
	#  contract ("pig is blocked at a 3-cell ledge, every other kind clears it"), so any kind added to `ALL`
	#  inherits "clears a 3-cell ledge". A big body stepping a 3-cell ledge is fine fiction for the bull too.
	KIND_BULL: {
		"name": &"황소", "w_px": 88, "h_px": 56, "step_cells": 3,
		"max_hp": 300, "speed_px": 140.0, "invuln_ticks": 2,
		"xp": 200, "money": 100,
	},
	KIND_ROOSTER: {
		"name": &"거대 수탉", "w_px": 72, "h_px": 80, "step_cells": 3,
		"max_hp": 250, "speed_px": 200.0, "invuln_ticks": 2,
		"xp": 250, "money": 120,
	},
	# **48x28 is the art's own size** (`wolf_body.png`), already a multiple of 4 on both sides — no padding,
	#  unlike the bull. Long and low: wider than the pig and barely half its height.
	# **Every number except the box is provisional and nobody has set them** — "skeleton first" (`monsters.md`
	#  leaves health, damage and movement speed TBD for exactly this reason). The shape chosen: **faster than
	#  the pig and thinner** (240 vs 160 px/s, 24 vs 30 hp), because the art is a lunging predator and the
	#  pig's identity is already "a big body that falls into a pit".
	# **It has no lunge in the sim.** `wolf_lunge.png` plays when it is in contact range, the same door the
	#  pig's shove uses — the picture shows an attack when an attack happens, but the *dash* the art implies is
	#  not a mechanic. `boss_ai` is where a real lunge would go, and it is not built.
	KIND_WOLF: {
		"name": &"늑대", "w_px": 48, "h_px": 28, "step_cells": 3,
		"max_hp": 24, "speed_px": 240.0, "invuln_ticks": 2,
		"xp": 15, "money": 6,
	},
}

## **The cost table. Re-take it with `tools/stage/profile_monsters.gd`, do not edit it by hand.**
##  `stage1-bosses.md`'s Cost section asked whoever builds Stage A to leave the numbers here; the hen's box
##  then grew 4.6x and there was **no way to re-take them**, which is how a measured number becomes a stale
##  one. There is a tool now. Same method as verify-run's original: 600 frames warmed, 3 runs (median), one
##  `world.frame()` per frame, an empty world subtracted. 60Hz budget = 16,667µs.
##
##  | | box cells | 1 alive | % of 60Hz | **20 alive (measured)** | % of 60Hz |
##  |---|---|---|---|---|---|
##  | 돼지 pig | 88 (44x32) | +192µs | 1.2% | **+3,416µs** | 20.5% |
##  | 닭 hen | 192 (48x64) | +306µs | 1.8% | **+5,318µs** | 31.9% |
##  | 황소 bull | 308 (88x56) | +556µs | 3.3% | +13,586µs | 81.5% |
##  | 거대 수탉 rooster | 360 (72x80) | +662µs | 4.0% | +13,014µs | 78.1% |
##  | 늑대 wolf | 84 (48x28) | +197µs | 1.2% | +4,004µs | 24.0% |
##
##  **Empty world: 67µs.** The pig (+192 vs. the old +220) and the bull (+556 vs. +570) reproduce verify-run's
##  original numbers; the rooster comes out lower (+662 vs. +1,010) — machine state, not a code change.
##
##  **Cost is sublinear in box cells, and the old projection assumed it was linear.**
##  The hen has **2.2x the pig's cells and costs 1.6x** as much. `monsters-bigger-boxes.md` §4 built its whole
##  estimate on cells-are-proportional and flagged it as an assumption; this is the measurement, and the
##  assumption was pessimistic. **The enlarged hen was projected at ~250µs and lands at 306µs, and 20 of them
##  at 31.9% of the frame — affordable.** The old "1.6x the bull on 17% more cells" rooster puzzle dissolves
##  into the same shape: per-cell work is not what dominates.
##
##  **The 20-at-once column is measured, not multiplied** — 20 bulls is not a real scene, but the 20-pig and
##  20-hen rows are exactly the scene `MAX_MONSTERS` describes and were the one thing nobody had ever run.
##  Note they come in *under* 1-monster x 20 (3,416 vs 3,840): the per-frame fixed cost is paid once.
##
##  **What this still does not measure**: monsters *plus* fire plus water on one screen. `monsters.md`'s "the
##  problem is not monsters alone but the overlap" is untouched, and water's acceptance 7 is still open.

## **Index `DEFS[kind][...]` directly.** Do not use `.get(..., default)` —
##  a kind missing from the table silently becomes a pig. `character_view._cell_rect` recorded the same discipline.
static func name_of(kind: int) -> StringName:
	return DEFS[kind]["name"]


static func w_px(kind: int) -> int:
	return DEFS[kind]["w_px"]


static func h_px(kind: int) -> int:
	return DEFS[kind]["h_px"]


static func step_cells(kind: int) -> int:
	return DEFS[kind]["step_cells"]


static func max_hp(kind: int) -> int:
	return DEFS[kind]["max_hp"]


static func speed_px(kind: int) -> float:
	return DEFS[kind]["speed_px"]


static func invuln_ticks(kind: int) -> int:
	return DEFS[kind]["invuln_ticks"]


static func xp_of(kind: int) -> int:
	return DEFS[kind]["xp"]


static func money_of(kind: int) -> int:
	return DEFS[kind]["money"]
