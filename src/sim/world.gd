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
## `threat` decides which way the chase runs — see `Rules.FORCE_PER_THREAT`.
var critter_pos := PackedVector2Array()
var critter_threat := PackedInt32Array()
var critter_dir := PackedVector2Array()
var critter_count := 0

var critters_eaten := 0

var elapsed := 0.0
var host_hp := Rules.HOST_HP
var host_grace := 0.0

## Placeholder end condition: set the frame a critter at CRITTER_THREAT_MAX is eaten. Plan 4 replaces the
## condition with the real boss check, not the plumbing that reads it — see `_contact()`.
var stage_cleared := false

## Ids of species eaten at least once, first-eaten order. Nothing in this plan appends to it — plan 4 is
## what puts anything in it; until then the ending prints 없음.
var species_eaten := PackedInt32Array()

var clones_lost := 0
var cargo_lost := 0.0
## Clones only, host excluded. **The run opens alone**, so this opens at zero and every body it ever
## counts came out of an `F`.
var peak_swarm := 0

## Levels earned but not yet spent. The shell holds the game still while this is non-zero and shows the
## three cards; `step()` refuses to advance, so a level-up cannot be ignored by walking away from it.
var level := 0
var pending_levels := 0
var offer := PackedInt32Array()

## True while the great absorption beat runs. `Run._begin_clear()` sets this and nothing else touches it
## — a fresh `World` always starts `false`, and a `World` that ever sets it is already headed to ENDING,
## so it never needs to be cleared within one `World`'s life.
##
## Two effects, one flag, on purpose — both are "must not advance during the beat", the same class of
## problem, and a second flag for the second one would just be two names for one moment in time:
##  · `_grow()` refuses to hand out a level while this holds — one earned by eating the boss would open
##    three cards on top of the ending screen
##  · `_step_critters()` does not run while this holds — see the note at its call site in `step()` for why
var beat_frozen := false

## Running total of bank already charged for levels. Not a level count and not a high-water mark of
## `banked` — the cost rises, so the two stopped being the same number the day `LEVEL_COST_GROWTH` landed.
var _level_paid := 0.0
var _next_critter := Rules.CRITTER_INTERVAL
var _rng := RandomNumberGenerator.new()


func setup(run_seed: int = 1) -> void:
	_rng.seed = run_seed
	swarm.setup(run_seed)
	food.setup(Rules.FIELD, Rules.FOOD_SPOTS, _rng)
	# No opening clones. The host starts at `FORCE_START` and the first body is one the player split off,
	# which is what makes the first `F` the tutorial instead of a key nothing needed.
	peak_swarm = swarm.count - 1
	critter_pos.resize(Rules.CRITTER_MAX)
	critter_threat.resize(Rules.CRITTER_MAX)
	critter_dir.resize(Rules.CRITTER_MAX)
	critter_count = 0
	for _i in Rules.CRITTER_START:
		_spawn_critter()


## A run no longer ends on a clock — `Run.step()` is what detects the end (death or the placeholder
## clear) and flips the phase. This method only ever refuses to advance on an unspent level.
func step(dt: float) -> void:
	if pending_levels > 0:
		return
	elapsed += dt
	swarm.step(dt, food)
	food.step(dt)
	# Frozen for the same reason `_grow()` is, below: the great absorption is the "you won" moment and
	# nothing in the ecosystem may act during it. Left running, critters keep chasing and fleeing while the
	# swarm is being swallowed, and one that is still a hunter costs the host a heart mid-victory. The
	# outcome is latched (a hit mid-beat cannot turn a win into a death), but the picture would still show
	# the world turning hostile at the exact moment it was won.
	# ⚠ `is_hunter_of()` and `critter_threat` are deleted by plan 4 — this freeze is about WHEN the
	# ecosystem steps, not about who is hunting whom, and must survive that deletion unchanged.
	if not beat_frozen:
		_step_critters(dt)
	_grow()
	if host_grace > 0.0:
		host_grace -= dt
	peak_swarm = maxi(peak_swarm, swarm.count - 1)
	_next_critter -= dt
	if _next_critter <= 0.0:
		_next_critter = Rules.CRITTER_INTERVAL
		_spawn_critter()


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
##
## ⚠ **It reads FORCE, never `swarm.count`.** Counted in bodies this comparison hands `F` a free
## power-up: a split conserves the total and multiplies the rows, so holding the key turns one force-10
## host into ten bodies and flips a threat-1 critter from hunter to prey having earned nothing. Force is
## the number the game compares — see `Rules.FORCE_PER_THREAT` for the measurement.
func is_hunter_of(k: int) -> bool:
	return float(swarm.total_force()) >= float(critter_threat[k]) * Rules.FORCE_PER_THREAT


func critter_radius(k: int) -> float:
	return Rules.CRITTER_RADIUS_BASE + float(critter_threat[k]) * Rules.CRITTER_RADIUS_PER_THREAT


## Returns true when the critter itself died, so the caller stops touching index `k`.
func _contact(k: int, p: Vector2) -> bool:
	var reach := critter_radius(k)
	if is_hunter_of(k):
		# The swarm eats it. Any body in the swarm counts — this is the payoff for having grown.
		#
		# ⚠ **`eat(i, ...)`, never `eat(0, ...)`.** `eat()` routes row 0 to `banked` and every other row to
		# `carried[i]`, so paying index 0 whatever body actually made contact would drop a clone's kill
		# straight into the bank from anywhere on the map — the single largest income in the game, with no
		# walk home and nothing to lose by dying out there. The recall tax has to be structural or it is
		# not a tax; see `Swarm.eat()`'s own header.
		for i in swarm.count:
			if p.distance_to(swarm.pos[i]) <= reach:
				swarm.eat(i, float(critter_threat[k]) * Rules.CRITTER_MEAT)
				critters_eaten += 1
				if critter_threat[k] == Rules.CRITTER_THREAT_MAX:
					# Placeholder end condition — plan 4 rewrites the condition, not the plumbing.
					stage_cleared = true
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


## What the *next* level costs, in banked. The cost rises: a flat one at the ×10 force scale hands out a
## level every few seconds by the midgame. `n` is how many levels have already been granted, so the first
## level costs `LEVEL_COST_BASE` exactly.
##
## **Public because the HUD's progress bar needs it.** The bar used to restate the formula in `hud.gd`,
## which held while the cost was flat and would have started lying the moment it was not.
func level_cost(n: int) -> float:
	return Rules.LEVEL_COST_BASE * pow(Rules.LEVEL_COST_GROWTH, float(n))


## How far the bank has come toward the next level, 0..1. The one place the fraction is computed.
func level_progress() -> float:
	var cost := level_cost(level)
	return clampf((swarm.banked - _level_paid) / cost, 0.0, 1.0)


## A level pays `FORCE_PER_LEVEL` into the host and that is its WHOLE payout — the cards no longer hand
## out clones, so force is the only thing a level makes. Bodies come from `F`.
##
## It is paid out of `banked`, never `eaten`: a clone that dies far from home costs you the level it was
## carrying. The pick that follows is a separate thing — `take_card` moves multipliers, not the swarm.
func _grow() -> void:
	if beat_frozen:
		return
	while true:
		# Cost read before `level` moves, because it is a function OF `level`.
		var cost := level_cost(level)
		if swarm.banked - _level_paid < cost:
			break
		_level_paid += cost
		level += 1
		pending_levels += 1
		swarm.force[0] += Rules.FORCE_PER_LEVEL
	if pending_levels > 0 and offer.is_empty():
		offer = Cards.roll(_rng)


## Applying a card is the only place the run's numbers move outside of play. Returns false when the pick
## was not actually available, so a stray click cannot conjure a level.
##
## **No branch here calls `add_clone()`.** The two that did were the split cards; bodies now come from `F`
## alone, and a card that made one would create force out of nothing.
func take_card(card: int) -> bool:
	if pending_levels <= 0 or not offer.has(card):
		return false
	match card:
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
