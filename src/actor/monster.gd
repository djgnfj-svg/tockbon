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
const BossAi := preload("res://src/actor/boss_ai.gd")

var id: int          # Acceptance 7 measures with this. "The count went down" cannot measure it (you cannot see which one died)
var kind: int
var hp: int

## Remaining invulnerability **ticks**. Same idiom as the character's `invuln_left` — the per-kind values are
##  held by `Defs.invuln_ticks(kind)` (the player uses a constant, monsters use the table. The values
##  themselves are 2 ticks for both right now).
var invuln_left := 0

## The reload clock (ticks) — the hen's peck **and** (`stage1-bosses.md` Stage D) the bull's fire breath share
##  this one field, the same clock idiom as invulnerability (20Hz, shaved in `on_tick`). One field is enough
##  because no kind is ever both at once.
var reload_left := 0

## Am I standing in fire right now. A value the screen will read (stage 7) — it is re-decided every frame,
##  so "I left the fire but keep looking like I am burning" is impossible in principle.
var burning := false

## The last direction faced (+1 right, -1 left). Same idiom as `character.facing` — the screen reads it once
##  the sprite is attached (stage 7). When the axis `_next_axis()` returned is 0 (standing still), **leave it
##  as is** — reset it to 0 and the hen's sprite snaps to the right-facing default every time it stops.
var facing := 1

## **The boss pattern machine's current state** (`boss_ai.Pattern`) — `stage1-bosses.md` Stage B. Stays at its
##  default `IDLE` forever for any kind `BossAi.has_pattern` returns false for (every trash mob), since
##  `_next_axis` never reaches `_boss_axis` to touch it. Read by `monster_view` to draw the wind-up/stun
##  indicator (the stage's screen share) and by `_boss_axis` to pick a direction.
var pattern: int = BossAi.Pattern.IDLE

## Ticks remaining in the current pattern state — the tick-counter idiom (`invuln_left`/`reload_left`),
## decremented in `on_tick` only. `step()` (60Hz) never touches it — that split is the whole of the plan's
## "two questions answered before any code".
var pattern_left := 0

## The charge's (or, Stage D, the fire breath's) locked direction (+1/-1), chosen once when the active state
## begins (`BossAi.advance`'s `WINDUP -> CHARGE`/`FIRE` transition) and held until it ends. Re-reading the
## live toward-player axis every tick would let the bull steer mid-charge, or let a stream of fire bolts read
## as tracking the player across the breath — "runs straight at the player and rams" (the design doc) is the
## point either way.
var pattern_dir := 1

## **Which move is running** (`boss_ai.MoveChoice`) — Stage D. Chosen at the `IDLE -> WINDUP` transition
## (`BossAi.advance`'s round-robin) and read again at `WINDUP`'s own exit to decide `CHARGE` vs `FIRE`.
## Starts at -1 so the very first `advance()` call resolves to index 0 (charge) — see that function's own
## comment on the round-robin arithmetic. Unread for any kind with no move table.
var move_choice := -1

## Did this tick's `step()` calls find `move_x` blocked while charging. **The only channel a 60Hz collision
## reaches the 20Hz pattern clock through** — `on_tick` reads and clears it every tick it advances the machine.
var _charge_blocked := false

## Did this tick's `step()` calls find the body back on the ground while leaping (`stage1-bosses.md` Stage F).
## The same "60Hz collision reaches the 20Hz clock" channel `_charge_blocked` already opened, for the same
## reason — the rooster's leap ends when it actually lands, not on a fixed tick count.
var _leaped_landed := false

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


## **Read-only window onto `_charge_blocked`** — Stage C's carve needs to know "did a real collision just
## end this charge" *before* `on_tick` consumes and clears the flag (a safety-cap timeout also ends a charge,
## but carves nothing — `world_step` reads this first to tell the two apart).
func charge_blocked_now() -> bool:
	return _charge_blocked


## **Read-only window onto `_leaped_landed`** — `stage1-bosses.md` Stage G's slam impact needs to know "did a
## real landing just end this leap" *before* `on_tick` consumes and clears the flag, the same door
## `charge_blocked_now()` already opened for the charge's carve (a safety-cap timeout also ends a leap, but
## ignites nothing). Shared by both kinds that ever enter `Pattern.LEAP` — the caller still has to check
## `kind` to know whether "landed" means "throw fire" (the bull's slam) or "nothing, undecided" (the rooster,
## `stage1-bosses.md`'s own open TBD on landing terrain damage).
func leap_landed_now() -> bool:
	return _leaped_landed


## **Stage H — "speeds up at half health."** Recomputed from `hp` on every call, never cached — the same
## "re-decided every frame" discipline `_burn`'s own `burning` field already holds, so a stale phase-2 read
## cannot exist in principle. `hp * 2 <= max_hp` rather than `hp <= max_hp / 2` — the multiply avoids integer
## division rounding the threshold down for an odd `max_hp` (150 vs. 151/2=75, the two forms would disagree
## by one hp at the boundary).
##
## **`BossAi.has_pattern(kind)` is checked here, not left to each caller** — every *sim* caller
## (`BossAi.advance`/`speed_mult`) was already inert for a trash mob regardless of this value (`advance`
## early-returns before any duration is chosen, `speed_mult` never matches a trash-mob kind), so the gap only
## ever showed on screen: `MonsterView._draw_phase2_tell` calls this with no kind check of its own, and a pig
## at low hp drew the same "this got more dangerous" outline a boss does — wrong on the face of it, a pig at
## 12 hp got weaker, not stronger. **One place holds "does phase 2 apply to this monster at all"**, not one
## copy per caller that could each answer it differently.
func is_phase2() -> bool:
	return BossAi.has_pattern(kind) and hp * 2 <= Defs.max_hp(kind)


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
	var charging := pattern == BossAi.Pattern.CHARGE
	# **Charging does not step up** — `Body.move_x`'s own comment carries the reason (room ①'s left boundary
	#  being only a 2-tile step, well inside `step_cells`=3's reach). Every other state/kind keeps the normal
	#  step-up behavior (`allow_step` defaults true).
	var dx := axis * Defs.speed_px(kind) * BossAi.speed_mult(kind, pattern, is_phase2()) * dt
	if _body.move_x(grid, dx, not charging) and charging:
		_charge_blocked = true
	if _body.move_y(grid, _body.vy * dt):
		_body.vy = 0.0
	_body.on_ground = _body.grounded(grid)
	# **Stage F — latched only while actually leaping.** Read unconditionally (not gated on "was airborne
	#  last frame") because there is nothing else to confuse it with: the moment `WINDUP` hands off to `LEAP`,
	#  `on_tick` gives the body upward velocity in the same tick, so by the time this line runs on any frame
	#  of `LEAP`, `on_ground` genuinely means "back down" and not "never left".
	if pattern == BossAi.Pattern.LEAP:
		_leaped_landed = _body.on_ground
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
	# **The one delegation branch** (`stage1-bosses.md`'s own words — "`_next_axis()` gains exactly one
	#  delegation branch, not one per pattern"). Every pattern's own branching lives inside `_boss_axis`,
	#  not spread across this function; growing a boss's AI must never mean growing the branch count here.
	if BossAi.has_pattern(kind):
		return _boss_axis(target_x)
	# **Stage 6 — the hen stops at range (`MonsterBolts.BOLT_STOP_PX`).** This is that place —
	#  put it outside and "where do I go" lives in two places and only one gets swapped the day AI goes in.
	if kind == Defs.KIND_HEN and _dist_to_target(target_x) <= MonsterBolts.BOLT_STOP_PX:
		return 0.0
	return _toward_player_axis(target_x)


## The pattern-driven axis (`stage1-bosses.md` Stage B, extended by Stages D-F). **Frozen during `WINDUP`/
## `STUN`/`FIRE`/`GORE`** — a body that drifts during the telegraph, the stun window, the fire breath or the
## gore swing reads as broken (`body.gd`'s "does not move a single pixel while telegraphing" comment records
## exactly this bug once already, for the rooster's wind-up itself).
## **Locked during `CHARGE`/`LEAP`** — `pattern_dir`, not the live toward-player axis, so the charge runs in a
## straight line and the leap arcs in one, both the player can read and dodge, not a homing one. `LEAP`'s
## vertical half of the arc is gravity (`step()`'s own `apply_gravity`/`move_y`) — this axis only ever
## answers the horizontal question, same as every other pattern here.
## **`IDLE` is brainless-forward** — the same rule as every other kind, parked in its own function only
## because the pattern states above have to live somewhere.
func _boss_axis(target_x: int) -> float:
	if pattern == BossAi.Pattern.WINDUP or pattern == BossAi.Pattern.STUN \
			or pattern == BossAi.Pattern.FIRE or pattern == BossAi.Pattern.GORE:
		return 0.0
	if pattern == BossAi.Pattern.CHARGE or pattern == BossAi.Pattern.LEAP:
		return float(pattern_dir)
	return _toward_player_axis(target_x)


## Center-to-center distance (px). `_next_axis` (stopping) and `ready_to_fire` (the firing condition) have to
##  use the same standard — measure differently in the two places and "it stopped but is out of range so it
##  does not fire" happens silently.
func _dist_to_target(target_x: int) -> float:
	return absf(float(target_x) - _body.center().x)


## **Does my row-range actually overlap the player's** — Stage E's gore gate needs this, not just
## `_dist_to_target`'s horizontal closeness (verify-read's finding: a player on a ledge above the bull, only
## far *vertically*, still won the horizontal-only gate every time and disabled the boss completely — gore
## never overlapped so it dealt nothing, and because gore always won the gate, the boss never charged either).
## Reconstructs the player's box from `target_y` (its center — the same "own snapshot" idiom `target_x`
## already uses) and `Character.H_PX`, the same open-interval convention `WorldStep._boxes_overlap` uses.
func _vertically_overlaps_target(target_y: int) -> bool:
	var half_h := Character.H_PX * 0.5
	return float(y) < float(target_y) + half_h and float(y + Defs.h_px(kind)) > float(target_y) - half_h


## **The one definition of "toward the player"** — this file's own header says that rule must not appear
## anywhere else, and by Stage B it had quietly grown to three copies (`_next_axis`'s trash-mob path,
## `_boss_axis`'s `IDLE` fallback, and `on_tick`'s charge-direction pick, the last one phrased slightly
## differently with no functional difference — verify-run flagged the drift). All three call this instead.
func _toward_player_axis(target_x: int) -> float:
	var my_x := _body.center().x
	if target_x < my_x:
		return -1.0
	if target_x > my_x:
		return 1.0
	return 0.0


## **It runs only on ticks** — the same reason as `character.on_tick` (call it at 60Hz and one hit becomes three).
##  The entrance is inside `world_step.frame()`'s tick branch, **after** `_char.on_tick` (doc: "behavior (9)").
##
## **`target_x`/`target_y` are their own snapshot, separate from the one `step()`'s loop reads later this
##  frame** — `world_step.frame()`'s own comment pins that one to *after* `_char.step()` runs, and moving
##  this call earlier to share it would break that existing contract for every other kind. A charge's locked
##  direction only needs "roughly where the player is right now" (it holds unchanged for the whole charge
##  either way).
func on_tick(spell: SpellSim, target_x: int, target_y: int) -> void:
	# The reload is a separate clock from the invulnerability but **goes through the same door (the tick)** —
	#  for kinds that never fire it simply never moves off 0.
	if reload_left > 0:
		reload_left -= 1
	# **The pattern machine (`stage1-bosses.md` Stage B) advances here, unconditionally** — it is not gated
	#  behind the invulnerability check below. `invuln_left` ("just got hit") and the boss's `STUN` ("just
	#  rammed a wall or finished breathing") are two different clocks; letting one block the other would mean
	#  getting hit resets how soon a stunned bull can be hit again, which is backwards.
	if BossAi.has_pattern(kind):
		var axis := _toward_player_axis(target_x)
		# **Stage E** — read at the same moment `axis` is, for the same reason: only the instant a move's
		#  active state begins matters (`BossAi.advance`'s own comment on why re-reading later would be wrong).
		#
		# **Both axes, not just the horizontal one** (verify-read's finding) — `_dist_to_target` alone let a
		#  player standing on a ledge above the bull disable it completely: gore kept winning the
		#  horizontal-only gate, its boxes never actually overlapped so it dealt nothing, and because it
		#  never charged, it never rammed, never carved, and never opened the stun window either — the whole
		#  "ram it, stun it, hit it" loop this boss *is* just disappeared. Gore is a melee move; it must
		#  require the boxes to actually be able to touch, not just be horizontally close.
		var in_gore_range := _dist_to_target(target_x) <= BossAi.gore_range_px(kind) \
			and _vertically_overlaps_target(target_y)
		var was_leap := pattern == BossAi.Pattern.LEAP
		var nxt := BossAi.advance(kind, pattern, pattern_left, pattern_dir, move_choice, _charge_blocked, axis,
			in_gore_range, _leaped_landed, is_phase2())
		pattern = int(nxt[0])
		pattern_left = int(nxt[1])
		pattern_dir = int(nxt[2])
		move_choice = int(nxt[3])
		_charge_blocked = false
		_leaped_landed = false
		# **Stage F — the jump itself.** The one side effect this function performs beyond updating its own
		#  fields: the instant `WINDUP` hands off to `LEAP` (not on every tick `LEAP` merely continues), give
		#  the body its upward velocity. `step()` (60Hz, later this same frame) applies gravity and moves it —
		#  `on_tick` only supplies the launch, the same door `_char.step()`'s own jump uses (`character.gd`,
		#  `vy = JUMP_VY_PX`).
		if pattern == BossAi.Pattern.LEAP and not was_leap:
			_body.vy = BossAi.leap_jump_vy_px(kind)
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


## **Does this monster want to fire right now.** `world_step` reads it every frame to make the actual bolt
## and calls `consume_fire()` to reset the reload clock. The bolt is not made here directly — if `Monster`
## made a `MonsterBolts`, the monster would "own" the bolt, and that is exactly what the detour
## (`monster_bolts.gd` header) was avoiding. **It only raises a signal.**
##
## **Two independent gates, not one merged condition** (`stage1-bosses.md` Stage D) — the hen's is a distance
## check (`_dist_to_target`), the bull's is a pattern check (`pattern == Pattern.FIRE`, set by the windup
## that already telegraphed it). Folding them into one shared condition would make one kind's gate readable
## as the other's, which is exactly the kind of accident CLAUDE.md's "two enums sharing a key" box warns about.
func ready_to_fire(target_x: int) -> bool:
	if kind == Defs.KIND_HEN:
		return reload_left <= 0 and _dist_to_target(target_x) <= MonsterBolts.BOLT_STOP_PX
	return BossAi.has_pattern(kind) and pattern == BossAi.Pattern.FIRE and reload_left <= 0


## **The reload amount differs by kind/pattern** — the hen's fixed cadence versus the bull's own
## `MOVE_FIRE.reload_ticks` (`stage1-bosses.md` Stage D). `ready_to_fire`'s own two-gate split is why this
## can pick the right one without re-deriving "which kind is this" from scratch.
func consume_fire() -> void:
	if kind == Defs.KIND_HEN:
		reload_left = MonsterBolts.RELOAD_TICKS
	else:
		reload_left = BossAi.fire_reload_ticks(kind)


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
