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

## Predators are a flat array too, for the same reason the swarm is: nothing here needs to be a Node.
var pred_pos := PackedVector2Array()
var pred_count := 0

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
var _next_predator := Rules.PREDATOR_INTERVAL
var _rng := RandomNumberGenerator.new()


func setup(run_seed: int = 1) -> void:
	_rng.seed = run_seed
	swarm.setup(run_seed)
	food.setup(Rules.FIELD, Rules.FOOD_SPOTS, _rng)
	pred_pos.resize(Rules.PREDATOR_MAX)
	pred_count = 0
	for _i in Rules.PREDATOR_START:
		_spawn_predator()


func step(dt: float) -> void:
	if over or pending_levels > 0:
		return
	elapsed += dt
	swarm.step(dt, food)
	food.step(dt)
	_step_predators(dt)
	_grow()
	if host_grace > 0.0:
		host_grace -= dt
	peak_swarm = maxi(peak_swarm, swarm.count - 1)
	_next_predator -= dt
	if _next_predator <= 0.0:
		_next_predator = Rules.PREDATOR_INTERVAL
		_spawn_predator()
	if elapsed >= Rules.RUN_LENGTH or host_hp <= 0:
		over = true


## Predators walk at the nearest body, host or clone alike, and understand nothing else. They are slower
## than the host and faster than a scattered clone — that ordering is the entire threat model.
func _step_predators(dt: float) -> void:
	for k in pred_count:
		var p := pred_pos[k]
		var target := -1
		var best := INF
		for i in swarm.count:
			var d: float = p.distance_squared_to(swarm.pos[i])
			if d < best:
				best = d
				target = i
		if target < 0:
			continue
		var to: Vector2 = swarm.pos[target] - p
		if to.length() > 0.001:
			p += to.normalized() * Rules.PREDATOR_SPEED * dt
			pred_pos[k] = p
		_bite(p)


func _bite(p: Vector2) -> void:
	if p.distance_to(swarm.pos[0]) <= Rules.PREDATOR_RADIUS:
		if host_grace <= 0.0:
			host_hp -= 1
			host_grace = Rules.HOST_HIT_GRACE
		return
	# Backwards, because `remove_at` swaps the last row into `i` — walking forwards would skip whatever
	# landed there. Every flat-array removal in this build has the same shape.
	for i in range(swarm.count - 1, 0, -1):
		if p.distance_to(swarm.pos[i]) > Rules.PREDATOR_RADIUS:
			continue
		cargo_lost += swarm.carried[i]
		clones_lost += 1
		swarm.remove_at(i)
		return


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


func _spawn_predator() -> void:
	if pred_count >= Rules.PREDATOR_MAX:
		return
	# Off-camera, never on top of the player: a predator materialising in your lap reads as a bug, and it
	# is not what this build is measuring.
	var host: Vector2 = swarm.pos[0]
	var p := host
	for _try in 12:
		p = Vector2(_rng.randf_range(0.0, Rules.FIELD.x), _rng.randf_range(0.0, Rules.FIELD.y))
		if p.distance_to(host) >= Rules.PREDATOR_SPAWN_MIN_DIST:
			break
	pred_pos[pred_count] = p
	pred_count += 1
