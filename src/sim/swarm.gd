class_name Swarm
extends RefCounted
## The host and every clone, as rows in flat packed arrays. Index 0 is the host and always exists.
##
## **Why flat arrays and not one Node per clone — the reason is NOT frame budget.** Measured on this
## machine (4.7.1, headless): 300 `Node2D`s with a method call and a position write cost 0.065ms, and 300
## `CharacterBody2D`s cost the same as 60. The engine was never the wall.
##
## The reason is `carried`. Held as a float in a `PackedFloat32Array`, "a clone killed far from home loses
## everything it was carrying" is **structurally true** — `remove_at()` swaps with the last row and the
## number is gone, with no code anywhere that has to remember to drop it. Held as a field on an object
## that something else also references, the rule fails silently and every check stays green. That is the
## exact fake `CLAUDE.md` names, and this build's whole tension is that one rule.
##
## Nothing here touches the tree: no Node, no `_draw`, no `Input`. A net drives all of it with `.new()`.

enum { FOLLOW = 0, SCATTER = 1, STRIKE = 2 }

## The three active slots, in the order the shell fires them: left click, right click, `space`.
const SLOT_COUNT := 3
## `space`. The one slot that refuses a non-movement active — see `bind()`.
const SLOT_MOVEMENT := 2

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var carried := PackedFloat32Array()
var state := PackedInt32Array()
var eat_cd := PackedFloat32Array()
var wander := PackedVector2Array()
var _wander_cd := PackedFloat32Array()
var _target_food := PackedInt32Array()
## **STORED, never recomputed.** Derived from anything, halving a body costs nothing — the next frame
## recomputes it back to full, the total is not conserved, and `F` buys a free double in silence. That is
## the whole reason splitting is a decision, so the number has to be the thing that moves.
##
## It is the ninth packed array, and three functions hand-maintain the row set: `setup()`'s resize block,
## `add_clone()`, and `remove_at()`'s swap. Miss the swap and a dead clone's force lands on a survivor —
## no error, nothing on screen. **The net for it has to kill a clone that is NOT the last row**, or the
## swap branch never runs and the missing line stays green.
var force := PackedInt32Array()
var count := 0

## Banked at the host: what the host bit itself, plus what returning clones handed over. This is the
## number the whole experiment reports.
var banked := 0.0

## Monotonic. Every mouthful this run, host and clones together, never decremented — `eat()` is the only
## place it moves. This is what the ending reports as 경험치: `banked` alone loses everything a dying
## clone was carrying, and the ending must report what the run ATE, not what it happened to bank.
var eaten := 0.0

## Set by `Run._begin_clear()` for the great absorption's duration. While true, `step()` steers every
## clone straight at the host and skips `_separate()` entirely — see both call sites below.
var clear_pull := false

## Where `3` was pressed: clones walk here and STAY. **`1` has no field** — rallying is at the host and
## `_move_clone()` reads `pos[0]` live every frame, so there is nothing to keep in sync. A `rally` field
## holding a per-frame copy of the host's position would be a second source of truth for something the
## swarm can already read, which is why it was deleted rather than repointed.
var strike_point := Vector2.ZERO
var scatter_anchor := Vector2.ZERO

## How far into the `F` hold we are, in seconds. The view draws it; it is the only feedback the wind-up
## has. Resets to zero on firing AND on release — on firing so the arc empties the instant the split lands.
var split_charge := 0.0

## True from the moment a hold fires until the key comes up. **Zeroing `split_charge` is not enough to stop
## the ratchet**, and the reasoning that it was is what shipped once: at zero the charge simply winds again
## and fires every `SPLIT_HOLD_TIME` the finger stays down — measured, four fires in one hold, count 1 → 8.
## "Charged to zero" and "charged to zero having already fired" are two different states, so they need two
## different values. Cleared only by `split_release()`, which is also what a panel opening calls.
var _hold_fired := false

## What is in each of the three slots, and each one's cooldown. `bound_cd[SLOT_MOVEMENT]` stays 0 forever:
## the dash keeps `dash_cd`, and two cooldowns for one act is two numbers that can disagree.
var bound := PackedInt32Array()
var bound_cd := PackedFloat32Array()

## Seconds since the last bite landed, counted UP in `step()`. The view draws the cone while this is under
## `Look.BITE_SHOW_TIME` and the sim never reads `look.gd` — counting up rather than down is what lets the
## duration stay a presentation constant without breaking the folder contract, and the sim still owns the
## clock so the view holds no state the sim does not know about. Opens at INF: a run does not start
## mid-bite.
var bite_show := INF
## Which way the last bite pointed, so the cone the view draws is the cone the sim tested.
var bite_aim := Vector2.RIGHT

var host_input := Vector2.ZERO
var host_facing := Vector2.RIGHT
var dash_left := 0.0
var dash_cd := 0.0

## What the level-up cards move. Multipliers rather than replaced constants, so `rules.gd` stays the one
## place a base value is written and a card is always readable as "×1.15 of the number in that file".
var host_speed_mul := 1.0
var host_eat_mul := 1.0
var clone_eat_mul := 1.0
var sense_mul := 1.0
var dash_cd_mul := 1.0

var clone_grid := SimGrid.new()
var food_grid := SimGrid.new()
var field := Rules.FIELD

## The food the last `step()` was handed. `fire()` takes an aim and nothing else — the shell presses a key,
## it does not hand the simulation its own world back — so a bite reads whatever the frame it happens in
## was stepped with. Null before the first `step()`, and a bite then simply misses.
var _food: Food = null

var _rng := RandomNumberGenerator.new()


func setup(rng_seed: int = 1, start: Vector2 = Rules.FIELD * 0.5) -> void:
	_rng.seed = rng_seed
	pos.resize(Rules.POOL)
	vel.resize(Rules.POOL)
	carried.resize(Rules.POOL)
	state.resize(Rules.POOL)
	eat_cd.resize(Rules.POOL)
	wander.resize(Rules.POOL)
	_wander_cd.resize(Rules.POOL)
	_target_food.resize(Rules.POOL)
	force.resize(Rules.POOL)
	count = 1
	pos[0] = start
	vel[0] = Vector2.ZERO
	carried[0] = 0.0
	state[0] = FOLLOW
	eat_cd[0] = 0.0
	_target_food[0] = -1
	# The one place the host's force is written from nothing. After this only splitting, absorbing and the
	# level move it — and the run opens with the host alone, so no body exists that did not come from a
	# split. There is no START_CLONES: with the constant still present, `count == 1 + START_CLONES` passes
	# at every value, including the zero that shipped once.
	force[0] = Rules.FORCE_START
	strike_point = start
	scatter_anchor = start
	split_charge = 0.0
	_hold_fired = false
	bite_show = INF
	bound = PackedInt32Array([Actives.BITE, Actives.NONE, Actives.DASH])
	bound_cd = PackedFloat32Array()
	bound_cd.resize(SLOT_COUNT)
	clone_grid.configure(field, Rules.GRID_CELL)
	food_grid.configure(field, Rules.FOOD_GRID_CELL)


## -1 when the pool is full. The cap is a real refusal, not a silently ignored request — a split past the
## cap has to leave the body that could not divide holding its force whole, and that only works if the
## caller can see it happened.
##
## **`parent` is not decoration.** The old signature spawned from `pos[0]` with `state[0]`, and reusing it
## unchanged makes every child of every clone appear on the host — with every net in plan 2 still passing,
## because they all split the host. The defaults exist for the nets that measure movement and do not care
## about force; no production caller uses either.
func add_clone(parent: int = 0, force_value: int = 0) -> int:
	# The cap counts clones, not rows: the host is row 0 and is not one of the forty.
	if count - 1 >= Rules.CLONE_CAP:
		return -1
	var i := count
	count += 1
	var a := _rng.randf() * TAU
	pos[i] = pos[parent] + Vector2(cos(a), sin(a)) * Rules.CLONE_SPAWN_RING
	vel[i] = Vector2.ZERO
	carried[i] = 0.0
	force[i] = force_value
	state[i] = state[parent]
	eat_cd[i] = Rules.EAT_PERIOD_CLONE
	wander[i] = Vector2(cos(a), sin(a))
	_wander_cd[i] = Rules.WANDER_PERIOD
	_target_food[i] = -1
	return i


## Swap with the last row. **The cargo AND the force go with it and nothing has to remember to drop
## them** — see the file header. Index 0 is the host and is never removable.
func remove_at(i: int) -> void:
	if i <= 0 or i >= count:
		return
	var last := count - 1
	if i != last:
		pos[i] = pos[last]
		vel[i] = vel[last]
		carried[i] = carried[last]
		state[i] = state[last]
		eat_cd[i] = eat_cd[last]
		wander[i] = wander[last]
		_wander_cd[i] = _wander_cd[last]
		_target_food[i] = _target_food[last]
		force[i] = force[last]
	count -= 1


## `1`. **No argument: the swarm comes to the host**, and `_move_clone()` reads `pos[0]` live rather than
## a stored point. The argument used to be the mouse and this comment used to argue for it — that
## gathering at the host lets the player park in cleared ground while the clones take the risk. **That
## argument lost** (user, 2026-08-14): a command that sends the swarm somewhere is `3`, and one key that
## means "come here" is what the hand actually reaches for.
func command_rally() -> void:
	for i in range(1, count):
		state[i] = FOLLOW


## `3`. Clones walk to the point and STAY there rather than drifting back, and they do not steer at food
## on the way — that is the whole difference between sending the swarm and letting it wander.
func command_strike(point: Vector2) -> void:
	strike_point = point
	for i in range(1, count):
		state[i] = STRIKE


func command_scatter() -> void:
	scatter_anchor = pos[0]
	for i in range(1, count):
		state[i] = SCATTER
		var a := _rng.randf() * TAU
		wander[i] = Vector2(cos(a), sin(a))
		_wander_cd[i] = Rules.WANDER_PERIOD


func try_dash() -> bool:
	if dash_cd > 0.0 or dash_left > 0.0:
		return false
	dash_left = Rules.DASH_TIME
	dash_cd = Rules.DASH_COOLDOWN * dash_cd_mul
	return true


## How close to the rendezvous counts as arrived. **It has to grow with the swarm.** A fixed 24px disc
## cannot hold forty bodies that each want 16px of clearance — that needs a disc about 55px across — so
## every clone kept steering inward while separation pushed outward, and the swarm ground itself into a
## single dot: closest pair 2.15px after twenty seconds, 58 pairs overlapping. Measured, and it was the
## exact state both the cap comment and the separation header name as the case that matters.
##
## The clones-fill-a-disc form: area per body is `SEPARATION_MIN²`, so the radius goes as `sqrt(n)`.
func rally_radius() -> float:
	return maxf(Rules.ARRIVE_RADIUS, Rules.SEPARATION_MIN * sqrt(float(maxi(1, count - 1))) * 0.62)


func total_carried() -> float:
	var sum := 0.0
	for i in range(1, count):
		sum += carried[i]
	return sum


## Every row's force, host included. **`World.is_hunter_of()` is its production caller** and that is the
## whole reason it has to exist: the prey/hunter comparison read `count` once, and a split multiplies rows
## while conserving force, so `F` bought the reversal for free. The conservation checks are its other
## caller — a hand-rolled sum inside every net would be the second copy `CLAUDE.md` forbids.
func total_force() -> int:
	var sum := 0
	for i in count:
		sum += force[i]
	return sum


# -- F, the split --------------------------------------------------

## Called every frame `F` is down. Fires once the charge reaches `SPLIT_HOLD_TIME` — hold it four times as
## long without letting go and the count goes up once, because `_hold_fired` stays set until the key is
## released. See that field for why the reset alone does not do it.
func split_hold(dt: float) -> void:
	if _hold_fired:
		return
	split_charge += dt
	if split_charge < Rules.SPLIT_HOLD_TIME:
		return
	split_charge = 0.0
	_hold_fired = true
	_split_fire()


## `F` came up, or a panel opened. An incomplete charge is DROPPED, not paused — resuming a wind-up across
## a menu is a decision the player did not make. This is also the only place the one-split-per-hold latch
## clears: releasing the key is what makes the next split a second decision.
func split_release() -> void:
	split_charge = 0.0
	_hold_fired = false


## **Every body with force >= 2 halves at once**, not the host alone. The parent keeps the LARGER half
## (`5 → 3 + 2`): it fights in front, so it keeps the odd point.
##
## ⚠ `carried` is NOT divided — the parent keeps all of it. Cargo is something a body is holding, not a
## substance it is made of, and halving it hands a stranger half a harvest it never walked home.
##
## ⚠ **The loop bound must never be read live, so this must never become a `while i < count`.** Measured
## on 4.7.1: `for i in <int>` evaluates its bound ONCE, so `for i in count` with `add_clone()` appending
## inside is already safe and `snapshot` is the bound written down rather than a guard against the
## language. A `while i < count` rewritten in for readability is the shape that actually bites — one press
## then walks the whole swarm down to force 1, because the `2` that came out of a `5` is split again
## inside the same press (measured: forces end `3,2,1,1` instead of `3,2,2,1`).
##
## Over the cap, bodies split in index order, lowest first, until `add_clone()` refuses; the rest keep
## their force whole. A body at force 1 does not split and that is not an error.
func _split_fire() -> void:
	var snapshot := count
	for i in snapshot:
		if force[i] < 2:
			continue
		# Integer division floors, so the child takes the smaller half and the parent the remainder.
		var child := force[i] / 2
		var j := add_clone(i, child)
		if j < 0:
			return
		force[i] -= child


# -- V, the absorb -------------------------------------------------

## Every clone within reach of the host **dies**, and its force and its cargo go to the host. Returns how
## many were taken, so a press that reached nothing is visible to the caller as 0.
##
## ⚠ Cargo arriving this way is BANKED, never routed through `eat()` — it was counted into `eaten` the
## moment it was picked up, and paying it again would make walking a clone home worth double.
##
## Backwards, because `remove_at()` swaps the last row down and a forward walk would skip whatever landed
## in `i`.
func absorb() -> int:
	var reach := Rules.ABSORB_RADIUS_BODIES * Rules.BODY_RADIUS
	var taken := 0
	for i in range(count - 1, 0, -1):
		if pos[i].distance_to(pos[0]) > reach:
			continue
		force[0] += force[i]
		banked += carried[i]
		carried[i] = 0.0
		remove_at(i)
		taken += 1
	return taken


# -- the three slots -----------------------------------------------

## **The only entry point for the three keys.** False when the slot is empty, on cooldown, or the active
## itself refused. A key that does its own thing instead of coming through here is a fourth code path the
## panel's input gate would have to know about separately.
func fire(slot: int, aim: Vector2) -> bool:
	if slot < 0 or slot >= bound.size():
		return false
	if bound_cd[slot] > 0.0:
		return false
	match bound[slot]:
		Actives.BITE:
			return _bite(slot, aim)
		Actives.DASH:
			# The dash keeps `dash_cd`. `bound_cd[slot]` is deliberately left alone so the two cooldowns
			# cannot disagree about whether the hand is free.
			return try_dash()
	return false


## False when `space` is handed something that is not a movement active. It is a real refusal the panel
## reports in a line of Korean — silently ignoring the click is how a player concludes the panel is broken.
func bind(slot: int, active: int) -> bool:
	if slot < 0 or slot >= bound.size():
		return false
	if slot == SLOT_MOVEMENT and not Actives.MOVEMENT.has(active):
		return false
	bound[slot] = active
	return true


## A front cone toward `aim`, and it eats the NEAREST food inside it. **A real function, not an
## animation** — a click that only draws is the idle hand this plan exists to remove. Plan 4 replaces what
## it hits, not the key.
func _bite(slot: int, aim: Vector2) -> bool:
	if _food == null:
		return false
	var origin := pos[0]
	var dir := aim - origin
	dir = host_facing if dir.length_squared() < 0.0001 else dir.normalized()
	var half_arc := Rules.BITE_ARC * 0.5
	var ids := food_grid.neighbours(origin, Rules.BITE_RANGE, Rules.SENSE_CAP)
	var best := -1
	var best_d := INF
	for id in ids:
		var j := id >> 1
		if j < 0 or j >= _food.alive.size() or _food.alive[j] == 0:
			continue
		var to: Vector2 = _food.pos[j] - origin
		var d := to.length()
		if d > Rules.BITE_RANGE or d >= best_d:
			continue
		# The angle is the skill. Range alone and the cone is a circle with a picture drawn on it.
		if d > 0.0001 and absf(dir.angle_to(to)) > half_arc:
			continue
		best_d = d
		best = j
	if best < 0:
		return false
	if not _food.consume(best):
		return false
	eat(0, 1.0)
	bound_cd[slot] = Rules.BITE_COOLDOWN
	bite_show = 0.0
	bite_aim = dir
	return true


## One frame. `food` may be null — a net that only measures steering passes nothing and pays for nothing.
##
## Order is load-bearing and is itself measurable: move, then separate, then eat, then — during the great
## absorption only — take whatever arrived at the host. Nothing happens on ordinary contact. Separating
## before moving lets two clones end the frame on top of each other, which is the one thing separation
## exists to prevent.
func step(dt: float, food: Food = null) -> void:
	_food = food
	for s in bound_cd.size():
		bound_cd[s] = maxf(0.0, bound_cd[s] - dt)
	bite_show += dt
	_rebuild_grids(food)
	_move_host(dt)
	for i in range(1, count):
		_move_clone(i, dt, food)
	if not clear_pull:
		# Separation pushes bodies 16px apart every frame; run it during the great absorption and forty
		# clones sit in a ring not moving while the sim says they are being pulled home — screen and sim
		# disagreeing, which CLAUDE.md names as the signature fake.
		for i in range(1, count):
			_separate(i)
	for i in count:
		_try_eat(i, dt, food)
	if clear_pull:
		_clear_arrivals()


func _rebuild_grids(food: Food) -> void:
	clone_grid.begin(count)
	for i in count:
		clone_grid.insert(i, SimGrid.KIND_CLONE, pos[i])
	if food == null:
		food_grid.begin(0)
		return
	food_grid.begin(food.pos.size())
	for i in food.pos.size():
		if food.alive[i] == 1:
			food_grid.insert(i, SimGrid.KIND_FOOD, food.pos[i])


func _move_host(dt: float) -> void:
	if dash_cd > 0.0:
		dash_cd -= dt
	var dir := host_input
	if dir.length_squared() > 0.0001:
		host_facing = dir.normalized()
	var speed := Rules.HOST_SPEED * host_speed_mul
	if dash_left > 0.0:
		dash_left -= dt
		dir = host_facing
		speed = Rules.DASH_SPEED
	vel[0] = dir.limit_length(1.0) * speed
	pos[0] = _clamp_field(pos[0] + vel[0] * dt)


func _move_clone(i: int, dt: float, food: Food) -> void:
	var p := pos[i]
	# STRIKE walks at the FOLLOW speed: it is the swarm being sent somewhere on purpose, not wandering.
	var speed := Rules.CLONE_SPEED_SCATTER if state[i] == SCATTER else Rules.CLONE_SPEED_FOLLOW
	if clear_pull:
		speed = Rules.CLEAR_ABSORB_PULL
	var desired := Vector2.ZERO
	_target_food[i] = _nearest_food(p, food)

	if clear_pull:
		# The great absorption: every clone is steered straight at the host, replacing FOLLOW/SCATTER
		# entirely for the beat's duration. See Run._begin_clear().
		#
		# `to.limit_length(speed * dt) / dt`, not `to.normalized() * speed`: nothing else in this
		# function decelerates on arrival, and at 900px/s a clone within one frame's travel of the host
		# overshoots every frame it is that close and oscillates there for the rest of the beat. The
		# numbers stay correct either way (ABSORB_RADIUS clears the overshoot, `eaten` doesn't move) —
		# it is the picture that breaks, and this beat IS the "you won" moment. Capping `desired` at
		# exactly what closes the remaining distance this frame lands the clone on the host and stops it,
		# with no separate arrive-radius to tune.
		var to := pos[0] - p
		if to.length() > 0.001:
			desired = to.limit_length(speed * dt) / dt
	elif state[i] == FOLLOW:
		# `pos[0]` read live every frame, not a stored rally point — that is the whole of `1`.
		var to := pos[0] - p
		if to.length() > rally_radius():
			desired = to.normalized() * speed
	elif state[i] == STRIKE:
		# Arrive and STAY. No food seeking: the swarm was sent here, and a clone that peels off after a
		# crumb is the swarm not obeying the one command that aims it.
		var to := strike_point - p
		if to.length() > rally_radius():
			desired = to.normalized() * speed
	else:
		var off := p - scatter_anchor
		if off.length() > Rules.SCATTER_RADIUS:
			# The leash. Without it a scattering clone walks off the map and the swarm stops being one.
			desired = -off.normalized() * speed
		elif _target_food[i] >= 0:
			var to := food.pos[_target_food[i]] - p
			if to.length() > 0.001:
				desired = to.normalized() * speed
		else:
			_wander_cd[i] -= dt
			if _wander_cd[i] <= 0.0:
				var a := _rng.randf() * TAU
				wander[i] = Vector2(cos(a), sin(a))
				_wander_cd[i] = Rules.WANDER_PERIOD
			desired = wander[i] * speed

	vel[i] = desired.limit_length(speed)
	pos[i] = _clamp_field(p + vel[i] * dt)


## Position correction, not a force. Separation is a rendering requirement — sixty bodies on one point
## read as one dot — and a force takes many frames to resolve a full overlap, which is exactly the state a
## rendezvous produces. Each of the pair moves half the overlap, so one step is enough.
##
## Neighbour candidates come from the grid built at the START of the frame, before movement. A clone moves
## at most ~5.7px in a frame against a 32px cell, so the candidate set is the same set; reading current
## positions for the distances keeps the correction exact.
func _separate(i: int) -> void:
	var ids := clone_grid.neighbours(pos[i], Rules.SEPARATION_MIN, Rules.NEIGHBOUR_CAP)
	for id in ids:
		var j := id >> 1
		if j <= 0 or j >= count or j == i:
			continue
		var d := pos[i] - pos[j]
		var l := d.length()
		var dir := Vector2.ZERO
		if l < 0.0001:
			# Exactly coincident. A deterministic angle from the index, never a random one: the same
			# overlap must resolve the same way every run or a net cannot pin it.
			#
			# **`l` goes to zero here, not to a small epsilon.** Written as `l = 0.0001` with the push
			# still dividing by `l`, a coincident pair was thrown ~80,000px — to opposite corners of the
			# field, in one step, silently, with `net_grid` green because its gap assertion was measuring
			# the blow-up. Found by inverting the check rather than the code.
			var a := float(i) * 2.3999632
			dir = Vector2(cos(a), sin(a))
			l = 0.0
		else:
			dir = d / l
		if l >= Rules.SEPARATION_MIN:
			continue
		var half := dir * (Rules.SEPARATION_MIN - l) * 0.5
		pos[i] = _clamp_field(pos[i] + half)
		pos[j] = _clamp_field(pos[j] - half)


func _try_eat(i: int, dt: float, food: Food) -> void:
	if eat_cd[i] > 0.0:
		eat_cd[i] -= dt
		return
	if food == null:
		return
	var target := _target_food[i] if i > 0 else _nearest_food(pos[i], food)
	if target < 0 or food.alive[target] == 0:
		return
	var reach := Rules.EAT_RADIUS_HOST if i == 0 else Rules.EAT_RADIUS_CLONE
	if pos[i].distance_to(food.pos[target]) > reach:
		return
	if not food.consume(target):
		return
	if i == 0:
		# The host banks instantly. A clone's mouthful is at risk until it walks home — that difference IS
		# the tax the GDD wanted, expressed as a speed, with no constant to tune and nothing to explain.
		eat(0, 1.0)
		eat_cd[0] = Rules.EAT_PERIOD_HOST * host_eat_mul
	else:
		eat(i, 1.0)
		eat_cd[i] = Rules.EAT_PERIOD_CLONE * clone_eat_mul
	_target_food[i] = -1


## THE ONLY PLACE `banked` OR `carried[i]` GROWS BY NEW MATERIAL. Moving cargo between two bodies is not
## eating and must not call this — `absorb()`, `_clear_arrivals()` and `Run._finish_clear()` all assign
## directly, and that asymmetry is the whole point: cargo arriving home was already counted here when it
## was picked up.
func eat(i: int, amount: float) -> void:
	eaten += amount
	if i == 0:
		banked += amount
	else:
		carried[i] += amount


## **The great absorption only**, and it is called from `step()` behind `clear_pull`. Arrival removes the
## whole body, cargo or none.
##
## This function used to do a second, unrelated job: on ordinary contact a loaded clone emptied into the
## host and stayed alive. **That branch is gone** — cargo comes home because the player pressed `V`, or
## because the run cleared, and nothing else. Automatic handover made recall discipline free, which is the
## thing the build measures.
##
## ⚠ **Do not fold this away with it.** `Run::step()` waits on `swarm.count <= 1`, and removing a body on
## arrival is the only thing that ever makes that true; delete it and every cleared run hangs for the full
## `CLEAR_ABSORB_TIME` and limps out through `Run._finish_clear()`'s fallback loop, with the `FieldView`
## absorb-pop firing once in a lump instead of once per body. Removing on arrival rather than waiting for
## the beat's end is also why the beat is not a still frame: measured, most of a 40-body swarm converges
## well inside `CLEAR_ABSORB_TIME`, and the ordinary rule left every empty clone sitting motionless on the
## host for the remainder — screen and sim disagreeing, `CLAUDE.md`'s own name for it.
##
## Backwards, because `remove_at()` swaps the last row down and a forward walk would skip whatever landed
## in `i` — the same reason every other flat-array removal in this build walks backwards.
func _clear_arrivals() -> void:
	for i in range(count - 1, 0, -1):
		if pos[i].distance_to(pos[0]) > Rules.ABSORB_RADIUS:
			continue
		# Force comes home with the body, exactly as `absorb()` does it. Three functions bring a body home
		# — this one, `absorb()`, and `Run._finish_clear()` — and for a while only `absorb()` moved force,
		# so the total was silently not conserved across the great absorption while `V` preserved it. Two
		# implementations of one rule, already forked; `net_force`'s clear-beat check pins all three.
		force[0] += force[i]
		banked += carried[i]
		carried[i] = 0.0
		remove_at(i)


func _nearest_food(p: Vector2, food: Food) -> int:
	if food == null:
		return -1
	var ids := food_grid.neighbours(p, Rules.SENSE_RADIUS * sense_mul, Rules.SENSE_CAP)
	var best := -1
	var best_d := INF
	for id in ids:
		var j := id >> 1
		if j < 0 or j >= food.alive.size() or food.alive[j] == 0:
			continue
		var d := p.distance_squared_to(food.pos[j])
		if d < best_d:
			best_d = d
			best = j
	return best


func _clamp_field(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.0, field.x), clampf(p.y, 0.0, field.y))
