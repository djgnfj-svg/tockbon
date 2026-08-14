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
## The host's slots, its bindings and its breath. **Constructed at the declaration, not in `setup()`** —
## `hud.gd` reads `world.body.hp_max()` inside `_draw()`, and a `World` whose body is null crashes there
## rather than drawing nothing. A clone gets no `Body`; it carries one part index (plan 4).
var body := Body.new()

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

## Ids of species eaten at least once, first-eaten order. **`Cards.roll()` reads it as the card pool's
## only lock** — a horse part cannot be offered before a horse has been eaten. Nothing in this plan
## appends to it either: plan 4's corpses are what put anything in it, so through plan 3 the pool is empty,
## every level BANKS, and the ending prints 없음.
var species_eaten := PackedInt32Array()

var clones_lost := 0
var cargo_lost := 0.0
## Clones only, host excluded. **The run opens alone**, so this opens at zero and every body it ever
## counts came out of an `F`.
var peak_swarm := 0

## Levels earned but not yet spent. The shell holds the game still while there are CARDS ON SCREEN and
## shows them; `step()` refuses to advance only then, so a level-up cannot be ignored by walking away
## from it. **A level with nothing to offer BANKS and the world keeps running** — the card pool is empty
## until the first horse is eaten, which is long after the first level, and a guard on `pending_levels`
## alone freezes the whole game there. Loud in play, completely silent in every check.
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
	body.setup()
	# **The one wire between them.** `Body` reaches the world through the swarm and nothing else: wearing a
	# part moves `swarm.force[0]`, biting eats a crumb the swarm was stepped with, and a gallop writes the
	# swarm's speed multiplier. Miss this line and every one of those silently does nothing — `Body`'s own
	# methods all null-check, so there is no error to see.
	body.swarm = swarm
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
## clear) and flips the phase. This method only ever refuses to advance while CARDS ARE ON SCREEN.
func step(dt: float) -> void:
	# ⚠ **`not offer.is_empty()` is the whole of the banking rule and it is one condition.** Written as
	# `pending_levels > 0` alone it also freezes `swarm.step()`, `food.step()`, `_step_critters()`,
	# `_grow()`, `host_grace` and the critter spawn timer — six behaviours, not one — and it does so from
	# the first level of every run, because the pool is empty until a horse is eaten. The ecosystem being
	# LIVE while a stack of cards waits is the other half of this rule and it is deliberate: the cards
	# arrive as a cascade the moment the pool opens, which is the rhythm the GDD asks for.
	if pending_levels > 0 and not offer.is_empty():
		return
	elapsed += dt
	# Before the swarm, always. `Body.step()` writes `swarm.active_speed_mul`, which `_move_host()` reads
	# this same frame; after, the host spends every frame at the previous frame's speed.
	body.step(dt)
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
## carrying. The pick that follows is a separate thing — `take_card` hands over a PART, not a multiplier.
##
## A level also raises current HP by `HP_PER_LEVEL`, because raising the maximum raises the current by the
## same amount and **there is no other source of healing in this plan.** Without this line `hp_max()`
## climbs with every level while the row of hearts stays as full as it was, which reads as the maximum
## being decoration.
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
		host_hp += Rules.HP_PER_LEVEL
	# ⚠ **`offer.is_empty()` is no longer a "needs a roll" sentinel.** With banking, "levels pending and no
	# offer" is the normal state for minutes, so this line ran `roll()` every single frame; `species_eaten`
	# is what says the pool can actually produce something.
	if pending_levels > 0 and offer.is_empty() and not species_eaten.is_empty():
		offer = Cards.roll(_rng, species_eaten)


## Applying a card is the only place the run's numbers move outside of play. **`card` is a `Parts` id.**
## Returns false when the pick was not actually available, so a stray click cannot conjure a level.
##
## **There is no `match` here any more and there must never be one again.** Every branch it used to have
## moved a `Swarm` multiplier or the host's HP; a card is now one call to `Body.wear()`, and everything a
## card can do is a column in the parts table. A branch here is the sentence "this table is the content of
## the game" dying.
##
## **No branch here calls `add_clone()`.** The two that did were the split cards; bodies now come from `F`
## alone, and a card that made one would create force out of nothing.
func take_card(card: int) -> bool:
	if pending_levels <= 0 or not offer.has(card):
		return false
	# Current HP follows the maximum. `Body` may not hold a `World` — `World` already holds `Body`, and a
	# RefCounted cycle never frees — so the difference is taken here rather than inside `wear()`. It is a
	# difference of `hp_max()`, which is a pure function of what is worn, NOT a second copy of the force
	# rule: force is stored per body because `F` halves it, and this is not.
	var hp_before := body.hp_max(level)
	body.wear(card)
	var delta := body.hp_max(level) - hp_before
	# ⚠ **Floored at 1: taking a card may not end the run.** Digesting a 말 갈기 costs a heart, and a
	# one-heart host would flip to ENDING·DIED on the very next frame — killed by a level-up, from a screen
	# with no way to decline. The plan gives HP no floor anywhere and `_contact()` is meant to be the only
	# thing that can reach zero.
	host_hp = maxi(1, host_hp + delta)
	pending_levels -= 1
	offer = Cards.roll(_rng, species_eaten) if pending_levels > 0 else PackedInt32Array()
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
