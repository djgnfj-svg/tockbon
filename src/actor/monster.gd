extends RefCounted
## One monster — uses `Body` and holds HP, kind and id. It only **reads** the grid.
##
## **`_next_axis()` is the only place answering "where does the next step go"**
##  (a function `docs/design/monsters.md` demanded in advance). When AI arrives, only this function gets swapped —
##  "toward the player" must not appear anywhere else.
##
## It is `src/actor/`, so floats are allowed and it does not know the scene tree (GDD multiplayer table —
##  monsters are host-authoritative).

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Body := preload("res://src/actor/body.gd")
const Character := preload("res://src/actor/character.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const MonsterBolts := preload("res://src/actor/monster_bolts.gd")

var id: int          # Acceptance 7 measures with this. "The count went down" cannot measure it (you cannot see which one died)
var kind: int
var hp: int

## Remaining invulnerability **ticks**. Same idiom as the character's `invuln_left` — the per-kind values are
##  held by `Defs.invuln_ticks(kind)` (the player uses a constant, monsters use the table. The values
##  themselves are 2 ticks for both right now).
var invuln_left := 0

## The hen's reload clock (ticks). No other kind uses it — only the hen is ranged for now, so one field is
##  enough. `on_tick` shaves it every tick (the same clock idiom as invulnerability — 20Hz).
var reload_left := 0

## Am I standing in fire right now. A value the screen will read (stage 7) — it is re-decided every frame,
##  so "I left the fire but keep looking like I am burning" is impossible in principle.
var burning := false

## The last direction faced (+1 right, -1 left). Same idiom as `character.facing` — the screen reads it once
##  the sprite is attached (stage 7). When the axis `_next_axis()` returned is 0 (standing still), **leave it
##  as is** — reset it to 0 and the hen's sprite snaps to the right-facing default every time it stops.
var facing := 1

## Fire damage that has not reached 1 yet. The device that keeps `hp` an integer — same reason as
##  `character._burn_acc`.
var _burn_acc := 0.0

## x, y and on_ground use the same idiom as the character — **`_body` is exposed through properties**
##  (the view reads `m.x`).
var _body: Body


func _init(monster_id: int, monster_kind: int, px: int, py: int) -> void:
	id = monster_id
	kind = monster_kind
	hp = Defs.max_hp(kind)
	_body = Body.new(Defs.w_px(kind), Defs.h_px(kind), Defs.step_cells(kind))
	_body.place(px, py)


var x: int:
	get: return _body.x
var y: int:
	get: return _body.y
var on_ground: bool:
	get: return _body.on_ground


func center() -> Vector2:
	return _body.center()


## **Five lines, and the order is a contract** (`monsters-minimum` stage 1). Grounding is refreshed first,
##  then `_next_axis()` is called — for the day the "stop at range" decision starts using that value.
##
## Gravity is read straight from `Character.GRAVITY_PX` and `MAX_FALL_PX` — the same place as "damage taken"
##  and "fire DPS" (no axes are added). Make a monster gravity column and the undecided items grow to two places.
##  Consequence: pigs and hens have the same fall curve as the player. A big one does not fall heavily.
func step(grid: CellGrid, dt: float, target_x: int, target_y: int) -> void:
	_body.on_ground = _body.grounded(grid)
	var axis := _next_axis(grid, target_x, target_y)
	# A screen-only value — not used for behavior (the same place as the `facing` assignment in `character.step()`).
	#  When it is 0 (stopped) it is not touched — `character.gd` already set that discipline (header above).
	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1
	_body.apply_gravity(dt, Character.GRAVITY_PX, Character.MAX_FALL_PX)
	_body.move_x(grid, axis * Defs.speed_px(kind) * dt)
	if _body.move_y(grid, _body.vy * dt):
		_body.vy = 0.0
	_body.on_ground = _body.grounded(grid)
	# **Look after all the moving is done** — the same reason as `character.step()` (you do not get shaved by
	#  the fire at the spot you just left).
	_burn(grid, dt)


## Where does the next step go. **Stage 2 — the one line of "toward the player".**
##  If the target (the player's center) is right of my center, +1; left, -1; equal, 0.
##  **It is measured center to center** — measure from the box's left edge and it silently skews by the box
##  width (the hen's range acceptance 10 already pinned "center to center" as the definition — the same
##  standard is used here).
##
## **The arguments are widened now. `grid` and `target_y` are not used yet.** With only `target_x` this
##  function cannot see the grid, but pathfinding has to read the terrain and the activation distance
##  (undecided item 13) also lives inside this function => the day AI goes in, the signature changes first,
##  and then half the values pulled out in advance become void.
## The hen's "stop at range" is also inside this function (stage 6) — put it outside and "where do I go" lives
##  in two places, and the day AI goes in only one gets swapped => only the hen stays stupid.
##
## An unused argument does not turn the nets red (measured, Godot 4.7.1 headless) —
##  do not attach `@warning_ignore`. It is not needed.
func _next_axis(_grid: CellGrid, target_x: int, _target_y: int) -> float:
	# **Stage 6 — the hen stops at range (`MonsterBolts.BOLT_STOP_PX`).** This is that place —
	#  put it outside and "where do I go" lives in two places and only one gets swapped the day AI goes in.
	if kind == Defs.KIND_HEN and _dist_to_target(target_x) <= MonsterBolts.BOLT_STOP_PX:
		return 0.0
	var my_x := _body.center().x
	if target_x < my_x:
		return -1.0
	if target_x > my_x:
		return 1.0
	return 0.0


## Center-to-center distance (px). `_next_axis` (stopping) and `ready_to_fire` (the firing condition) have to
##  use the same standard — measure differently in the two places and "it stopped but is out of range so it
##  does not fire" happens silently.
func _dist_to_target(target_x: int) -> float:
	return absf(float(target_x) - _body.center().x)


## **It runs only on ticks** — the same reason as `character.on_tick` (call it at 60Hz and one hit becomes three).
##  The entrance is inside `world_step.frame()`'s tick branch, **after** `_char.on_tick` (doc: "behavior (9)").
func on_tick(spell: SpellSim) -> void:
	# The reload is a separate clock from the invulnerability but **goes through the same door (the tick)** —
	#  for non-hens it simply never moves off 0.
	if reload_left > 0:
		reload_left -= 1
	if invuln_left > 0:
		invuln_left -= 1
		return
	# **`hit_by_segment`/`hit_by_blast` return a power percent, 0 = not hit — `max`, not `or`**
	#  (the same reasoning as `character.on_tick`, so the two do not read the notice differently).
	var pw := maxi(_body.hit_by_segment(spell), _body.hit_by_blast(spell))
	if pw <= 0:
		return
	hp = maxi(0, hp - Character.DAMAGE_HIT * pw / 100)
	invuln_left = Defs.invuln_ticks(kind)


## **Does the hen want to fire right now.** `world_step` reads it every frame to make the actual bolt and calls
##  `consume_fire()` to reset the reload clock. The bolt is not made here directly —
##  if `Monster` made a `MonsterBolts`, the monster would "own" the bolt, and that is exactly what this whole
##  detour (`monster_bolts.gd` header) was avoiding. **It only raises a signal.**
func ready_to_fire(target_x: int) -> bool:
	return kind == Defs.KIND_HEN and reload_left <= 0 \
		and _dist_to_target(target_x) <= MonsterBolts.BOLT_STOP_PX


func consume_fire() -> void:
	reload_left = MonsterBolts.RELOAD_TICKS


## **Standing in fire shaves you — it neither refreshes invulnerability nor is stopped by it**
##  (the same contract as `character._burn` — "where you put fuel is level design" lives for monsters too).
## "Damage taken" and "fire DPS" get no columns in the table — the player's constants
##  (`Character.DAMAGE_HIT`, `Character.BURN_DPS`) are used verbatim (doc: "behavior (7)", "no axes are added").
func _burn(grid: CellGrid, dt: float) -> void:
	burning = _body.standing_in_fire(grid)
	if not burning:
		return
	_burn_acc += Character.BURN_DPS * dt
	var whole := floori(_burn_acc)
	if whole <= 0:
		return
	_burn_acc -= float(whole)
	hp = maxi(0, hp - whole)
