extends RefCounted
## Monster bolts — the hen's peck and (`stage1-bosses.md` Stage D) the bull's fire breath. **Not `spell_sim`**
##  — it is the detour `docs/design/monsters.md` settled on (`monsters-minimum`, "behavior (5)"): this repo's
##  sim does not know "who fired" => leave it as is and the hen's bolt hits the hen, and the bull's fire
##  breath hits the bull. Acceptance 15 ("no homing, bolts do not hit their owner") is free here — the same
##  detour, extended to a second kind rather than reopened.
##
## **"It only hits the player" is implemented by not looking at the monster list at all.** Walk the monster
##  list and "skip if it is the shooter" and the bolt has to carry its owner, and that is exactly what this
##  detour was avoiding — **the bolt does not know that monsters exist.**
##
## | property | value |
## |---|---|
## | where does it go | straight. no gravity |
## | who does it hit | the player only |
## | terrain | it disappears on touching a solid cell. **`KIND_FIRE` also records an ignite notification there —
##   it still does not dig terrain itself; `world_step` turns the notification into `cmd_ignite`** |
##
## **`BOLT_STOP_PX` (the stopping distance) and `BOLT_RANGE_PX` (the bolt's lifetime) are different constants —
##  there are two axes.** Make one value serve both and a retreating player can never be hit, in principle:
##  ```
##  the hen fires at 240px -> the player retreats at 260px/s
##  bolt 320px/s - player 260px/s = relative approach 60px/s
##  closing 240px takes 4 seconds = the bolt must fly 1,280px
##  but with a 240px lifetime it dies in 0.75 seconds => it can never hit, in principle
##  ```
##  => At 480 (= 2x) it closes only from 240 to 150px and still does not reach — **retreating pays the price
##  of giving up progress** (GDD, "direction of progress"). Stop, walk sideways or close in and it hits.
##  **The bull's fire breath does not use `BOLT_STOP_PX` at all** — `boss_ai`'s pattern machine decides when
##  it fires, not a distance gate (the bull is a melee charger first; fire is the ranged answer for whatever
##  distance the windup happened to end at).
##
## **Every hen value is a proposal. It has not had the user's acceptance** — `monsters-minimum`, "behavior (8)"
##  and "undecided item 1" carry one line of grounds each. This is a place the user settles on screen.
## **The hen (220px/s) is slower than the player (260px/s)** — just walk backwards and it never hits.
##  Stretching the bolt's lifetime however far does not solve it (undecided item 5, which this doc does not close).
## **`FIRE_DAMAGE`/`FIRE_IGNITE_R` are equally unaccepted** — `stage1-bosses.md` Stage D's own TBD.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")

## Bolt kinds — a column, not a second file (`stage1-bosses.md`'s own words for why this file grew instead
## of splitting). `KIND_PLAIN` is the hen's peck; `KIND_FIRE` is the bull's breath.
const KIND_PLAIN := 0
const KIND_FIRE := 1

## The distance at which the hen **stops** (px, center to center). A quarter of the 960px visible width —
##  the hen and the player fit on one screen together.
const BOLT_STOP_PX := 240.0
## The distance the bolt **lives** (px) — 2x `BOLT_STOP_PX`. It must be a different constant (the box above).
##  Shared by fire bolts too — no reason yet to give the breath its own range.
const BOLT_RANGE_PX := 480.0
## Bolt speed (px/s). Slightly faster than the player (260px/s) — slower and it is dodged by walking so it is
##  not a threat, and as fast as a magic bolt (1,600px/s) it cannot be dodged on sight. Shared by fire bolts.
const BOLT_SPEED_PX := 320.0
## Reload (ticks, 20Hz) = 2 seconds. If half of 20 monsters are hens, that is 5 shots per second — a screen budget.
const RELOAD_TICKS := 40
## Damage. Half of the player's 100 HP and the base magic damage of 10. It rides the 0.2s invulnerability, so
##  several hens firing at once still make one hit.
const BOLT_DAMAGE := 5
## The fire breath's own damage — bigger than the hen's peck (a boss attack, not a trash mob's). **Chosen,
##  not measured** — `stage1-bosses.md`'s own TBD ("health · damage · speed values — none decided").
const FIRE_DAMAGE := 8
## The fire bolt's ignite radius (cells) on terrain impact — the same "carve/ignite radii live in
##  `boss_ai.gd`" split `sim_tuning.gd`'s header names, but this one radius belongs to the *bolt*, not the
##  pattern machine (`carve_r` is the charge's own property; this is the breath's), so it stays here next to
##  `FIRE_DAMAGE` rather than in `boss_ai.MOVE_FIRE`.
const FIRE_IGNITE_R := 2
## How many bolts can live at once (a safety net). **Over the cap it does not fire. It does not discard a bolt** —
##  discard and you get "spam shots and some do not come out", which reads as a malfunction.
const MAX_BOLTS := 32

## Parallel arrays. Unlike the cell grid this is the actor layer, so floats — the same contract as the
##  monsters and the character. `_kind` is `PackedInt32Array` — a small integer column, not a float.
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _dx := PackedFloat32Array()
var _dy := PackedFloat32Array()
var _traveled := PackedFloat32Array()
var _kind := PackedInt32Array()

## **Fire bolts that hit solid terrain since the last `clear_ignitions()`** (cell coords). `step()` only
##  appends — it does not know about `_grid.apply()` (that stays `world_step`'s door, the same one the
##  charge's carve uses, per that file's own comment on why). **Not cleared inside `step()`** — `step()` runs
##  every 60Hz frame but `world_step`'s tick branch only drains this once per 20Hz tick, so clearing here
##  would throw away whatever the other 2 of every 3 frames recorded (the same reason `world_step._died_x`
##  is cleared by the tick branch, not by `_char.step()`).
var _ignite_cx := PackedInt32Array()
var _ignite_cy := PackedInt32Array()


func count() -> int:
	return _x.size()


func x(i: int) -> float:
	return _x[i]


func y(i: int) -> float:
	return _y[i]


func kind(i: int) -> int:
	return _kind[i]


## `dir` is taken as a unit vector — it is not normalized here (the caller already did it).
## Over the cap it **does not fire.** It does not discard bolts already in flight.
func spawn(ox: float, oy: float, dir: Vector2, bolt_kind: int = KIND_PLAIN) -> bool:
	if _x.size() >= MAX_BOLTS:
		return false
	if dir.length_squared() <= 0.0:
		return false
	_x.append(ox)
	_y.append(oy)
	_dx.append(dir.x)
	_dy.append(dir.y)
	_traveled.append(0.0)
	_kind.append(bolt_kind)
	return true


## **One step per frame (60Hz) — this removes tunneling in principle.** 320px/s / 60 = 5.3px per frame and the
##  short side of the player's box is 20px => it cannot skip over. **The real limit has to be measured with the
##  relative speed** (`net_monster_bolts` measures that inequality numerically) — look at the bolt speed alone
##  and you overestimate this margin.
##
## It disappears on touching terrain or when its lifetime runs out. **It does not dig terrain itself** — a
## `KIND_FIRE` bolt only records *where* it touched solid terrain (`_ignite_cx`/`_ignite_cy`); turning that
## into `cmd_ignite` is `world_step`'s job, the same reason `spell_sim` and not `Body` sends grid commands.
func step(grid: CellGrid, dt: float) -> void:
	var step_px := BOLT_SPEED_PX * dt
	var i := _x.size() - 1
	while i >= 0:
		_x[i] += _dx[i] * step_px
		_y[i] += _dy[i] * step_px
		_traveled[i] += step_px
		var cx := floori(_x[i] / float(Tuning.CELL_PX))
		var cy := floori(_y[i] / float(Tuning.CELL_PX))
		if grid.is_solid(cx, cy):
			if _kind[i] == KIND_FIRE:
				_ignite_cx.append(cx)
				_ignite_cy.append(cy)
			_remove_at(i)
		elif _traveled[i] >= BOLT_RANGE_PX:
			_remove_at(i)
		i -= 1


## Read-only queries — `world_step`'s tick branch drains these once per tick (the box above).
func ignite_count() -> int:
	return _ignite_cx.size()


func ignite_cx(i: int) -> int:
	return _ignite_cx[i]


func ignite_cy(i: int) -> int:
	return _ignite_cy[i]


## Called by `world_step`'s tick branch after it has applied `cmd_ignite` for every entry above.
func clear_ignitions() -> void:
	_ignite_cx.clear()
	_ignite_cy.clear()


## Erases bolts overlapping the player's box (whether it hit or was blocked by invulnerability — touching the
##  body makes it disappear).
## Even with several overlapping bolts, **`take_hit` holds "one hit and that is the end of it" with its single
##  invulnerability** — here every overlapping bolt is erased, and the actual damage judgment (the
##  invulnerability check) is done by the caller (`world_step`).
## **Returns the damage to apply, 0 meaning no hit** — the same "0 = not hit" idiom `Body.hit_by_segment`/
##  `hit_by_blast` already use, widened from a bare `bool` now that two bolt kinds can carry different damage.
## **The max across every overlapping bolt, not the first found** — the same reasoning those two functions
##  give: picking "whichever the array order found first" would let the damage depend on an implementation
##  detail nobody chose.
func consume_hits(ch: Character) -> int:
	var lo_x := float(ch.x)
	var hi_x := float(ch.x + Character.W_PX)
	var lo_y := float(ch.y)
	var hi_y := float(ch.y + Character.H_PX)
	var dmg := 0
	var i := _x.size() - 1
	while i >= 0:
		if _x[i] >= lo_x and _x[i] <= hi_x and _y[i] >= lo_y and _y[i] <= hi_y:
			dmg = maxi(dmg, FIRE_DAMAGE if _kind[i] == KIND_FIRE else BOLT_DAMAGE)
			_remove_at(i)
		i -= 1
	return dmg


func _remove_at(i: int) -> void:
	_x.remove_at(i)
	_y.remove_at(i)
	_dx.remove_at(i)
	_dy.remove_at(i)
	_traveled.remove_at(i)
	_kind.remove_at(i)
