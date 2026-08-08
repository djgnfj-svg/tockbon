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

## Iteration goes **only through this explicit list**. It does not assume the values are contiguous.
const ALL: Array[int] = [KIND_PIG, KIND_HEN]

## 20 is a value decided by the user — not a value to measure and adjust.
const MAX_MONSTERS := 20

const DEFS: Dictionary = {
	KIND_PIG: {
		"name": &"돼지", "w_px": 44, "h_px": 32, "step_cells": 1,
		"max_hp": 30, "speed_px": 160.0, "invuln_ticks": 2,
	},
	KIND_HEN: {
		"name": &"닭", "w_px": 24, "h_px": 28, "step_cells": 3,
		"max_hp": 10, "speed_px": 220.0, "invuln_ticks": 2,
	},
}


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
