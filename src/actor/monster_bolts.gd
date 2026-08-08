extends RefCounted
## The hen's bolt — a simple projectile. **It is not `spell_sim`** — it is the detour
##  `docs/design/monsters.md` settled on (`monsters-minimum`, "behavior (5)"): this repo's sim does not know
##  "who fired" => leave it as is and the hen's bolt hits the hen.
##
## **"It only hits the player" is implemented by not looking at the monster list at all.** Walk the monster
##  list and "skip if it is the shooter" and the bolt has to carry its owner, and that is exactly what this
##  detour was avoiding — **the bolt does not know that monsters exist.**
##
## | property | value |
## |---|---|
## | where does it go | straight. no gravity |
## | who does it hit | the player only |
## | terrain | it disappears on touching a solid cell. **it does not dig terrain** |
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
##
## **Every value is a proposal. It has not had the user's acceptance** — `monsters-minimum`, "behavior (8)"
##  and "undecided item 1" carry one line of grounds each. This is a place the user settles on screen.
## **The hen (220px/s) is slower than the player (260px/s)** — just walk backwards and it never hits.
##  Stretching the bolt's lifetime however far does not solve it (undecided item 5, which this doc does not close).

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")

## The distance at which the hen **stops** (px, center to center). A quarter of the 960px visible width —
##  the hen and the player fit on one screen together.
const BOLT_STOP_PX := 240.0
## The distance the bolt **lives** (px) — 2x `BOLT_STOP_PX`. It must be a different constant (the box above).
const BOLT_RANGE_PX := 480.0
## Bolt speed (px/s). Slightly faster than the player (260px/s) — slower and it is dodged by walking so it is
##  not a threat, and as fast as a magic bolt (1,600px/s) it cannot be dodged on sight.
const BOLT_SPEED_PX := 320.0
## Reload (ticks, 20Hz) = 2 seconds. If half of 20 monsters are hens, that is 5 shots per second — a screen budget.
const RELOAD_TICKS := 40
## Damage. Half of the player's 100 HP and the base magic damage of 10. It rides the 0.2s invulnerability, so
##  several hens firing at once still make one hit.
const BOLT_DAMAGE := 5
## How many bolts can live at once (a safety net). **Over the cap it does not fire. It does not discard a bolt** —
##  discard and you get "spam shots and some do not come out", which reads as a malfunction.
const MAX_BOLTS := 32

## Parallel arrays. Unlike the cell grid this is the actor layer, so floats — the same contract as the
##  monsters and the character.
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _dx := PackedFloat32Array()
var _dy := PackedFloat32Array()
var _traveled := PackedFloat32Array()


func count() -> int:
	return _x.size()


func x(i: int) -> float:
	return _x[i]


func y(i: int) -> float:
	return _y[i]


## `dir` is taken as a unit vector — it is not normalized here (the caller already did it).
## Over the cap it **does not fire.** It does not discard bolts already in flight.
func spawn(ox: float, oy: float, dir: Vector2) -> bool:
	if _x.size() >= MAX_BOLTS:
		return false
	if dir.length_squared() <= 0.0:
		return false
	_x.append(ox)
	_y.append(oy)
	_dx.append(dir.x)
	_dy.append(dir.y)
	_traveled.append(0.0)
	return true


## **One step per frame (60Hz) — this removes tunneling in principle.** 320px/s / 60 = 5.3px per frame and the
##  short side of the player's box is 20px => it cannot skip over. **The real limit has to be measured with the
##  relative speed** (`net_monster_bolts` measures that inequality numerically) — look at the bolt speed alone
##  and you overestimate this margin.
##
## It disappears on touching terrain or when its lifetime runs out. **It does not dig terrain** — it sends no
##  command to the grid.
func step(grid: CellGrid, dt: float) -> void:
	var step_px := BOLT_SPEED_PX * dt
	var i := _x.size() - 1
	while i >= 0:
		_x[i] += _dx[i] * step_px
		_y[i] += _dy[i] * step_px
		_traveled[i] += step_px
		var cx := floori(_x[i] / float(Tuning.CELL_PX))
		var cy := floori(_y[i] / float(Tuning.CELL_PX))
		if _traveled[i] >= BOLT_RANGE_PX or grid.is_solid(cx, cy):
			_remove_at(i)
		i -= 1


## Erases bolts overlapping the player's box (whether it hit or was blocked by invulnerability — touching the
##  body makes it disappear).
## Even with several overlapping bolts, **`take_hit` holds "one hit and that is the end of it" with its single
##  invulnerability** — here every overlapping bolt is erased, and the actual damage judgment (the
##  invulnerability check) is done by the caller (`world_step`).
## Return value: was there an overlapping bolt (should damage be attempted).
func consume_hits(ch: Character) -> bool:
	var lo_x := float(ch.x)
	var hi_x := float(ch.x + Character.W_PX)
	var lo_y := float(ch.y)
	var hi_y := float(ch.y + Character.H_PX)
	var hit := false
	var i := _x.size() - 1
	while i >= 0:
		if _x[i] >= lo_x and _x[i] <= hi_x and _y[i] >= lo_y and _y[i] <= hi_y:
			hit = true
			_remove_at(i)
		i -= 1
	return hit


func _remove_at(i: int) -> void:
	_x.remove_at(i)
	_y.remove_at(i)
	_dx.remove_at(i)
	_dy.remove_at(i)
	_traveled.remove_at(i)
