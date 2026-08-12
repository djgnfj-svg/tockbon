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

enum { FOLLOW = 0, SCATTER = 1 }

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var carried := PackedFloat32Array()
var state := PackedInt32Array()
var eat_cd := PackedFloat32Array()
var wander := PackedVector2Array()
var _wander_cd := PackedFloat32Array()
var _target_food := PackedInt32Array()
var count := 0

## Banked at the host: what the host bit itself, plus what returning clones handed over. This is the
## number the whole experiment reports.
var banked := 0.0
var absorbed_events := 0

## Where `1` was pressed. **Not the host's position** — clones walk to the point the player named and wait
## there. Gathering at the host lets the player park in cleared ground while the clones take every step of
## the risk, which is backwards from the tension this build exists to measure.
var rally := Vector2.ZERO
var scatter_anchor := Vector2.ZERO

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
	count = 1
	pos[0] = start
	vel[0] = Vector2.ZERO
	carried[0] = 0.0
	state[0] = FOLLOW
	eat_cd[0] = 0.0
	_target_food[0] = -1
	rally = start
	scatter_anchor = start
	clone_grid.configure(field, Rules.GRID_CELL)
	food_grid.configure(field, Rules.FOOD_GRID_CELL)


## -1 when the pool is full. The cap is a real refusal, not a silently ignored request — a level past the
## cap has to be able to pay out something else, and that only works if the caller can see it happened.
func add_clone() -> int:
	# The cap counts clones, not rows: the host is row 0 and is not one of the forty.
	if count - 1 >= Rules.CLONE_CAP:
		return -1
	var i := count
	count += 1
	var a := _rng.randf() * TAU
	pos[i] = pos[0] + Vector2(cos(a), sin(a)) * Rules.ABSORB_RADIUS
	vel[i] = Vector2.ZERO
	carried[i] = 0.0
	state[i] = state[0]
	eat_cd[i] = Rules.EAT_PERIOD_CLONE
	wander[i] = Vector2(cos(a), sin(a))
	_wander_cd[i] = Rules.WANDER_PERIOD
	_target_food[i] = -1
	return i


## Swap with the last row. **The cargo goes with it and nothing has to remember to drop it** — see the
## file header. Index 0 is the host and is never removable.
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
	count -= 1


func command_rally(point: Vector2) -> void:
	rally = point
	for i in range(1, count):
		state[i] = FOLLOW


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


## One frame. `food` may be null — a net that only measures steering passes nothing and pays for nothing.
##
## Order is load-bearing and is itself measurable: move, then separate, then eat, then absorb. Separating
## before moving lets two clones end the frame on top of each other, which is the one thing separation
## exists to prevent.
func step(dt: float, food: Food = null) -> void:
	_rebuild_grids(food)
	_move_host(dt)
	for i in range(1, count):
		_move_clone(i, dt, food)
	for i in range(1, count):
		_separate(i)
	for i in count:
		_try_eat(i, dt, food)
	_absorb()


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
	var speed := Rules.CLONE_SPEED_FOLLOW if state[i] == FOLLOW else Rules.CLONE_SPEED_SCATTER
	var desired := Vector2.ZERO
	_target_food[i] = _nearest_food(p, food)

	if state[i] == FOLLOW:
		var to := rally - p
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
	if pos[i].distance_to(food.pos[target]) > Rules.EAT_RADIUS:
		return
	if not food.consume(target):
		return
	if i == 0:
		# The host banks instantly. A clone's mouthful is at risk until it walks home — that difference IS
		# the tax the GDD wanted, expressed as a speed, with no constant to tune and nothing to explain.
		banked += 1.0
		eat_cd[0] = Rules.EAT_PERIOD_HOST * host_eat_mul
	else:
		carried[i] += 1.0
		eat_cd[i] = Rules.EAT_PERIOD_CLONE * clone_eat_mul
	_target_food[i] = -1


## Touching the host hands the cargo over. **The clone empties; it does not die** — the swarm's size is
## set by level, and a harvest that deleted clones would erase the forty-blobs screenshot every time the
## player collected anything.
func _absorb() -> void:
	for i in range(1, count):
		if carried[i] <= 0.0:
			continue
		if pos[i].distance_to(pos[0]) > Rules.ABSORB_RADIUS:
			continue
		banked += carried[i]
		carried[i] = 0.0
		absorbed_events += 1


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
