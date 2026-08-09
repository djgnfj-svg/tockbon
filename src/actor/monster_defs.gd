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

## Iteration goes **only through this explicit list**. It does not assume the values are contiguous.
const ALL: Array[int] = [KIND_PIG, KIND_HEN, KIND_BULL, KIND_ROOSTER]

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
	KIND_HEN: {
		"name": &"닭", "w_px": 24, "h_px": 28, "step_cells": 3,
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
}

## **The first boss-box measurement** — `stage1-bosses.md`'s Cost section asked whoever builds Stage A to
##  leave it here. Measured by verify-run: 600 frames warmed, 3 runs, one `world.frame()` call per frame —
##
##  | | box cells | extra µs over an empty world (81-93µs) | % of the 16,667µs 60Hz budget |
##  |---|---|---|---|
##  | pig | ~108 | +220 | ~1.3% |
##  | 황소 (bull) | 308 (88x56) | +570 | ~3.4% |
##  | 거대 수탉 (rooster) | 360 (72x80) | +1,010 | ~6.1% |
##
##  Both land inside the plan's predicted 330-1,060µs band. **One number is unexplained, not just unmeasured**:
##  the rooster costs 1.6x the bull on only 17% more cells. Its 200 speed_px vs the bull's 140 (more sub-steps
##  per frame in `Body.move_x`/`move_y`) is a plausible cause, not a confirmed one — nobody has isolated it.

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
