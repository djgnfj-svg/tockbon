class_name World
extends RefCounted
## One run: the swarm, the food, the predators, and the four numbers the experiment reports.
##
## **The four numbers are the output of this build**, not a HUD nicety: banked total, clones lost, cargo
## lost with them, peak swarm size. Two runs — one greedy, one cautious — and the comparison is the
## verdict. Without them the build answers "did it feel nice", which is the question planning already
## failed at five times in one day.

var swarm := Swarm.new()
var food := Food.new()

## Critters are a flat array too, for the same reason the swarm is: nothing here needs to be a Node.
## `threat` decides which way the chase runs — see `Rules.SWARM_PER_THREAT`.
var critter_pos := PackedVector2Array()
var critter_threat := PackedInt32Array()
var critter_dir := PackedVector2Array()
var critter_count := 0

var critters_eaten := 0

var elapsed := 0.0
var host_hp := Rules.HOST_HP
var host_grace := 0.0
var over := false

var clones_lost := 0
var cargo_lost := 0.0
var peak_swarm := 1

## Levels earned but not yet spent. The shell holds the game still while this is non-zero and shows the
## three cards; `step()` refuses to advance, so a level-up cannot be ignored by walking away from it.
var level := 0
var pending_levels := 0
var offer := PackedInt32Array()

var _split_paid := 0.0
var _next_critter := Rules.CRITTER_INTERVAL
var _rng := RandomNumberGenerator.new()


func setup(run_seed: int = 1) -> void:
	_rng.seed = run_seed
	swarm.setup(run_seed)
	food.setup(Rules.FIELD, Rules.FOOD_SPOTS, _rng)
	for _i in Rules.START_CLONES:
		swarm.add_clone()
	peak_swarm = swarm.count - 1
	critter_pos.resize(Rules.CRITTER_MAX)
	critter_threat.resize(Rules.CRITTER_MAX)
	critter_dir.resize(Rules.CRITTER_MAX)
	critter_count = 0
	for _i in Rules.CRITTER_START:
		_spawn_critter()


func step(dt: float) -> void:
	if over or pending_levels > 0:
		return
	elapsed += dt
	swarm.step(dt, food)
	food.step(dt)
	_step_critters(dt)
	_grow()
	if host_grace > 0.0:
		host_grace -= dt
	peak_swarm = maxi(peak_swarm, swarm.count - 1)
	_next_critter -= dt
	if _next_critter <= 0.0:
		_next_critter = Rules.CRITTER_INTERVAL
		_spawn_critter()
	if elapsed >= Rules.RUN_LENGTH or host_hp <= 0:
		over = true


## Critters wander until something comes within `CRITTER_SENSE`, and then the comparison decides which of
## the two is the meal. **Nothing crosses the map to reach the player** — walking at you from the far edge
## on a timer is what the user rejected, and an ecosystem is exactly the thing that does not do that.
func _step_critters(dt: float) -> void:
	# Backwards: `_remove_critter` swaps the last row down into `k`, and a forward walk would then skip it.
	for k in range(critter_count - 1, -1, -1):
		var p := critter_pos[k]
		var target := -1
		var best := Rules.CRITTER_SENSE * Rules.CRITTER_SENSE
		for i in swarm.count:
			var d: float = p.distance_squared_to(swarm.pos[i])
			if d < best:
				best = d
				target = i

		var dir := critter_dir[k]
		if target >= 0:
			var away: Vector2 = (p - swarm.pos[target])
			var toward: Vector2 = -away
			# Outgrown: it runs. Still bigger than the swarm: it comes. One comparison, both directions.
			dir = away.normalized() if is_hunter_of(k) else toward.normalized()
		elif _rng.randf() < dt * 0.6:
			var a := _rng.randf() * TAU
			dir = Vector2(cos(a), sin(a))
		critter_dir[k] = dir

		p += dir * Rules.CRITTER_SPEED * dt
		p = Vector2(clampf(p.x, 0.0, Rules.FIELD.x), clampf(p.y, 0.0, Rules.FIELD.y))
		critter_pos[k] = p
		_contact(k, p)


## Has the swarm outgrown critter `k`. **The reversal the whole design is about, as one comparison.**
func is_hunter_of(k: int) -> bool:
	return float(swarm.count - 1) >= float(critter_threat[k]) * Rules.SWARM_PER_THREAT


func critter_radius(k: int) -> float:
	return Rules.CRITTER_RADIUS_BASE + float(critter_threat[k]) * Rules.CRITTER_RADIUS_PER_THREAT


## Returns true when the critter itself died, so the caller stops touching index `k`.
func _contact(k: int, p: Vector2) -> bool:
	var reach := critter_radius(k)
	if is_hunter_of(k):
		# The swarm eats it. Any body in the swarm counts — this is the payoff for having grown.
		for i in swarm.count:
			if p.distance_to(swarm.pos[i]) <= reach:
				swarm.banked += float(critter_threat[k]) * Rules.CRITTER_MEAT
				critters_eaten += 1
				_remove_critter(k)
				return true
		return false

	if p.distance_to(swarm.pos[0]) <= reach:
		if host_grace <= 0.0:
			host_hp -= 1
			host_grace = Rules.HOST_HIT_GRACE
		return false
	# Backwards, because `remove_at` swaps the last row into `i` — walking forwards would skip whatever
	# landed there. Every flat-array removal in this build has the same shape.
	for i in range(swarm.count - 1, 0, -1):
		if p.distance_to(swarm.pos[i]) > reach:
			continue
		cargo_lost += swarm.carried[i]
		clones_lost += 1
		swarm.remove_at(i)
		return false
	return false


func _remove_critter(k: int) -> void:
	var last := critter_count - 1
	if k != last:
		critter_pos[k] = critter_pos[last]
		critter_threat[k] = critter_threat[last]
		critter_dir[k] = critter_dir[last]
	critter_count -= 1


## One level per SPLIT_PER_BANKED banked. The level does not spend the bank and does not grow the swarm on
## its own — it hands the player a pick, and `take_card` is what actually pays out.
func _grow() -> void:
	while swarm.banked - _split_paid >= Rules.SPLIT_PER_BANKED:
		_split_paid += Rules.SPLIT_PER_BANKED
		level += 1
		pending_levels += 1
	if pending_levels > 0 and offer.is_empty():
		offer = Cards.roll(_rng)


## Applying a card is the only place the run's numbers move outside of play. Returns false when the pick
## was not actually available, so a stray click cannot conjure a level.
func take_card(card: int) -> bool:
	if pending_levels <= 0 or not offer.has(card):
		return false
	match card:
		Cards.SPLIT_1:
			swarm.add_clone()
		Cards.SPLIT_3:
			for _i in 3:
				swarm.add_clone()
		Cards.HOST_SPEED:
			swarm.host_speed_mul *= 1.12
		Cards.HOST_BITE:
			swarm.host_eat_mul *= 0.82
		Cards.CLONE_BITE:
			swarm.clone_eat_mul *= 0.82
		Cards.SENSE:
			swarm.sense_mul *= 1.25
		Cards.DASH:
			swarm.dash_cd_mul *= 0.8
		Cards.TOUGH:
			host_hp += 1
	pending_levels -= 1
	offer = Cards.roll(_rng) if pending_levels > 0 else PackedInt32Array()
	return true


func _spawn_critter() -> void:
	if critter_count >= Rules.CRITTER_MAX:
		return
	# Off-camera, never on top of the player: something materialising in your lap reads as a bug, and it
	# is not what this build is measuring.
	var host: Vector2 = swarm.pos[0]
	var p := host
	for _try in 12:
		p = Vector2(_rng.randf_range(0.0, Rules.FIELD.x), _rng.randf_range(0.0, Rules.FIELD.y))
		if p.distance_to(host) >= Rules.CRITTER_SPAWN_MIN_DIST:
			break
	critter_pos[critter_count] = p
	critter_threat[critter_count] = _rng.randi_range(Rules.CRITTER_THREAT_MIN, Rules.CRITTER_THREAT_MAX)
	var a := _rng.randf() * TAU
	critter_dir[critter_count] = Vector2(cos(a), sin(a))
	critter_count += 1
