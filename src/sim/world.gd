class_name World
extends RefCounted
## One run: the swarm, the food, the ground, the creatures, and the four numbers the experiment reports.
## **Not "the predators"** — that word belonged to the deleted threat model, where a critter chased you
## until your total force outgrew it. A creature's damage is now its own force in both directions and its
## disposition comes from its species, so nothing here compares two strengths at all.
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

## Rocks, water and the arena. **Constructed at the declaration, not in `setup()`**, for the same reason
## `body` is: `setup()` calls into it on its own first pass and `_step_critters()` reads it every frame
## with no null guard. `Swarm.terrain` is the nullable one — a steering net builds a `Swarm` and no
## `World` — and this one must never be.
var terrain := Terrain.new()

## Creatures are a flat table too, for the same reason the swarm is: nothing here needs to be a Node.
## **Eight columns, and every one of them is written by `_spawn_at()` and swapped by `_remove_critter()`.**
## A column that only one of those two knows about is the shape that leaks — a survivor inherits a dead
## creature's number and nothing goes red.
var critter_pos := PackedVector2Array()
var critter_dir := PackedVector2Array()
var critter_species := PackedInt32Array()    ## `Parts.Species` — CROW · HORSE · BOSS
var critter_force := PackedInt32Array()      ## per individual, inside its species' range
var critter_hp := PackedInt32Array()         ## force × `Rules.HP_PER_FORCE`, written at spawn
var critter_flees := PackedInt32Array()      ## 1 = runs away, 0 = stands and hits back
var critter_atk_cd := PackedFloat32Array()   ## contact-attack cooldown, the clone's own clock mirrored
## Seconds of crow counter left. A crow stands still until something damages it and then walks at the
## nearest body for `Rules.CROW_COUNTER_TIME`; without its own column that timer has nowhere to live.
var critter_counter := PackedFloat32Array()
var critter_count := 0

## The one boss's row, kept live through every swap. Everything about the boss reads it, so
## `_remove_critter()` repairs **both** halves — the boss itself dying, and the last row (which may BE the
## boss) being swapped down over someone else. A stale index is a boss that stops walking with nothing on
## screen to say so.
var boss_index := -1

## The row `_contact()` is currently working on, repaired by `_remove_critter()` exactly the way
## `boss_index` is: -1 when that creature died, the new index when the swap moved it.
##
## ⚠ **It exists because `strike()` returns a HIT COUNT and a count delta is not an identity.** A clone's
## cone kills every creature it covers, so "somebody died" was read as "the one that walked into the clone
## died": `_contact` answered true, its second pass never ran, and the creature got a free frame with no
## retaliation. Only the walk sets this — `fire()`'s host strike leaves it at -1.
var _watched_row := -1

## Corpses are a table of their own, and **every column is a COPY**. A corpse that remembered which row
## it came from would be reading a stranger before the frame it was born on ended: `_remove_critter()`
## swaps the last creature down into the dead one's index on that same call.
##
## **Four columns, one removal.** `_remove_corpse()` swaps all four; miss one and a corpse inherits a
## consumed one's progress, species or worth, which reads as a meal that finished by itself.
var corpse_pos := PackedVector2Array()
var corpse_species := PackedInt32Array()   ## `Parts.Species`, copied at death
var corpse_force := PackedInt32Array()     ## what the individual was worth, copied at death
## 0..1, and it is **kept when the eater walks away**. Resuming is what makes interrupting a meal a cost
## rather than an annoyance, so nothing anywhere resets this to zero.
var corpse_progress := PackedFloat32Array()
var corpse_count := 0

var elapsed := 0.0
var host_hp := Rules.HOST_HP
var host_grace := 0.0

## The run's end. **The placeholder that set this on eating the fiercest critter is gone with the threat
## model it read**; what sets it now is finishing the BOSS's corpse in `_step_corpses()`, and only that. Killing
## the boss and walking away leaves the run open on purpose — the meal is the last act.
var stage_cleared := false

## Ids of species eaten at least once, first-eaten order. **`Cards.roll()` reads it as the card pool's
## only lock** — a horse part cannot be offered before a horse has been eaten. `_step_corpses()` is the
## one thing that appends, when a corpse is FINISHED rather than when its creature dies, and the crow is
## what a run meets in its first minute: the pool opens off the common creature, so a run that never
## corners a horse still sees cards.
var species_eaten := PackedInt32Array()

var clones_lost := 0
var cargo_lost := 0.0
## Clones only, host excluded. **The run opens alone**, so this opens at zero and every body it ever
## counts came out of an `F`.
var peak_swarm := 0

## Levels earned but not yet spent. The shell holds the game still while there are CARDS ON SCREEN and
## shows them; `step()` refuses to advance only then, so a level-up cannot be ignored by walking away
## from it. **A level with nothing to offer BANKS and the world keeps running** — the card pool is empty
## until the first corpse is FINISHED, which can be after the first level, and a guard on `pending_levels`
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
	# ⚠ **The call order below is pinned and it is load-bearing.** Every step draws from the one shared
	# `_rng`, so inserting a draw anywhere re-rolls everything after it and the same seed stops building the
	# same world. Terrain goes before food and before the creatures because both of those are placed against
	# it, and `swarm.terrain` is set the moment the ground exists — the swarm's very next `place()` reads it.
	terrain.setup(Rules.FIELD, swarm.pos[0], _rng)
	swarm.terrain = terrain
	food.setup(Rules.FIELD, Rules.FOOD_SPOTS, _rng)
	# No opening clones. The host starts at `FORCE_START` and the first body is one the player split off,
	# which is what makes the first `F` the tutorial instead of a key nothing needed.
	peak_swarm = swarm.count - 1
	critter_pos.resize(Rules.CRITTER_MAX)
	critter_dir.resize(Rules.CRITTER_MAX)
	critter_species.resize(Rules.CRITTER_MAX)
	critter_force.resize(Rules.CRITTER_MAX)
	critter_hp.resize(Rules.CRITTER_MAX)
	critter_flees.resize(Rules.CRITTER_MAX)
	critter_atk_cd.resize(Rules.CRITTER_MAX)
	critter_counter.resize(Rules.CRITTER_MAX)
	corpse_pos.resize(Rules.CORPSE_MAX)
	corpse_species.resize(Rules.CORPSE_MAX)
	corpse_force.resize(Rules.CORPSE_MAX)
	corpse_progress.resize(Rules.CORPSE_MAX)
	critter_count = 0
	corpse_count = 0
	boss_index = -1
	# Counted by species rather than rolled, so the opening is the same SHAPE every run. **The loop walks the
	# table and never names a species** — the two hand-written loops it replaced were what made adding a
	# species a code edit rather than a row, and `SPECIES_START[BOSS]` being 0 is what keeps the boss out of
	# it. It goes through `_spawn_herd` so an opening elephant arrives with the other two, exactly as a
	# mid-run one does; a herd size of 1 makes that identical to the old single spawn.
	for s in Rules.SPECIES_START.size():
		for _i in int(Rules.SPECIES_START[s]):
			_spawn_herd(s)
	_place_boss()


## A run no longer ends on a clock — `Run.step()` is what detects the end (death or the placeholder
## clear) and flips the phase. This method only ever refuses to advance while CARDS ARE ON SCREEN.
func step(dt: float) -> void:
	# ⚠ **`not offer.is_empty()` is the whole of the banking rule and it is one condition.** Written as
	# `pending_levels > 0` alone it also freezes `swarm.step()`, `food.step()`, `_step_critters()`,
	# `_grow()`, `host_grace` and the critter spawn timer — six behaviours, not one — and it does so from
	# the first level of every run, because the pool is empty until a corpse is finished. The ecosystem being
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
	# swarm is being swallowed, and a crow that walks in still costs the host hp mid-victory. The outcome is
	# latched (a hit mid-beat cannot turn a win into a death), but the picture would still show the world
	# turning hostile at the exact moment it was won.
	# ⚠ This freeze is about WHEN the ecosystem steps, never about who is hunting whom — it was written
	# against the deleted threat model and it survived that deletion unchanged, which is the point.
	if not beat_frozen:
		_step_critters(dt)
		# Frozen with the ecosystem, and for a sharper reason than the critters are: a corpse finishing
		# mid-absorption pays 경험치, which `_grow()` turns into a level, which opens three cards on top of
		# the ending screen. The beat is the "you won" moment and nothing may be earned during it.
		_step_corpses(dt)
		# Inside the freeze for the sharpest reason of the three: the arena closing teleports every clone at
		# once, and the great absorption is walking those same clones home one by one.
		_step_arena()
		# ⚠ **The arrival is frozen too, and the clock with it.** Left outside, a crow walked onto the field
		# mid-"you won" — the one moment the beat exists to hold the ecosystem out of. Freezing the timer
		# rather than only the call is what makes coming back resume rather than fire the arrival it owed.
		_next_critter -= dt
		if _next_critter <= 0.0:
			_next_critter = Rules.CRITTER_INTERVAL
			_spawn_critter()
	_grow()
	if host_grace > 0.0:
		host_grace -= dt
	peak_swarm = maxi(peak_swarm, swarm.count - 1)


## **Three species are three hands, and this is where the difference lives.** A crow stands where it is
## until something damages it and then walks at the nearest body; a horse runs from whatever it can see and
## out-runs every sustained speed in the game, so it is HERDED rather than chased; the boss wanders until
## `BOSS_HUNT_AT` and then comes at the host for the rest of the run, ignoring its senses entirely.
##
## **Nothing crosses the map to reach the player except the boss**, and that exemption is the whole of "it
## cannot be escaped". Six things walking at you from the far edge on a timer is what the user rejected.
func _step_critters(dt: float) -> void:
	# ⚠ **Forwards, over a bound RE-READ every iteration, with an index that does not advance when row `k`
	# stops holding the creature it held.** `for k in range(critter_count - 1, -1, -1)` materialises its
	# index list once, and walking backwards protects against creature `k`'s OWN death only: `_contact(k)`
	# dispatches `strike()`, which hits every creature in the clone's cone and can therefore remove a row at
	# any `j < k`. `_remove_critter(j)` copies row `last` down into `j` — and a backwards walk has ALREADY
	# stepped that row, so it is reached again and the creature takes two steps in one frame. The tail of
	# the frozen list then indexes rows at or past the new `critter_count`, which are sized to the cap and
	# never cleared: a stale creature moves, contacts, damages, and can be "killed" a second time.
	#
	# Forwards inverts that: the row moved down into the already-stepped region is an UNSTEPPED one, so the
	# worst case is one creature missing one frame of walk. `_contact`'s return is what covers the case the
	# old comment was written for — row `k` dying and a stranger landing in it — and it is now an identity,
	# not a count. See `_watched_row`.
	var k := 0
	while k < critter_count:
		var s := critter_species[k]
		critter_atk_cd[k] = maxf(0.0, critter_atk_cd[k] - dt)
		critter_counter[k] = maxf(0.0, critter_counter[k] - dt)
		var p := critter_pos[k]
		var target := -1
		var best := Rules.CRITTER_SENSE * Rules.CRITTER_SENSE
		for i in swarm.count:
			# Water's SECOND effect, and it is a different rule from the slow: a body standing in water is
			# not seen at all. A check that keeps one while deleting the other has to exist for each.
			if terrain.hidden(swarm.pos[i]):
				continue
			var d: float = p.distance_squared_to(swarm.pos[i])
			if d < best:
				best = d
				target = i

		var dir := critter_dir[k]
		if s == Parts.Species.BOSS:
			if elapsed >= Rules.BOSS_HUNT_AT:
				# **`CRITTER_SENSE` is not consulted.** It comes to you from anywhere on the field, which is
				# the one sentence the boss exists to make true.
				var to: Vector2 = swarm.pos[0] - p
				if to.length_squared() > 0.0001:
					dir = to.normalized()
			elif _rng.randf() < dt * 0.6:
				var a := _rng.randf() * TAU
				dir = Vector2(cos(a), sin(a))
		elif critter_counter[k] > 0.0 and target >= 0:
			var to: Vector2 = swarm.pos[target] - p
			if to.length_squared() > 0.0001:
				dir = to.normalized()
		elif critter_flees[k] == 1 and target >= 0:
			var away: Vector2 = p - swarm.pos[target]
			if away.length_squared() > 0.0001:
				dir = away.normalized()
		elif int(Rules.SPECIES_HUNTS[s]) == 1 and target >= 0:
			# The lion, and nothing else. It is under `HOST_SPEED`, so this is pressure and never a death
			# sentence — see the speed chain in `rules.gd`.
			var to_body: Vector2 = swarm.pos[target] - p
			if to_body.length_squared() > 0.0001:
				dir = to_body.normalized()
		elif int(Rules.SPECIES_WANDER[s]) == 1:
			# **The same drift the boss uses before `BOSS_HUNT_AT`, read off a table instead of a species
			# check.** `dt * 0.6` is a turn every ~1.7s on average; a herd born at one spot therefore
			# spreads slowly rather than dispersing, which is what makes a straggler a moment.
			#
			# ⚠ **`dir` is left ALONE on the frames that do not turn**, and that is the whole of "it keeps
			# walking". Re-rolling every frame is a creature vibrating in place, which is what the crow's
			# `Vector2.ZERO` branch below already looks like and is not what wandering means.
			if _rng.randf() < dt * 0.6 or dir.length_squared() < 0.0001:
				var wa := _rng.randf() * TAU
				dir = Vector2(cos(wa), sin(wa))
		else:
			# **A crow does not wander.** Standing still is what makes the common creature a thing you walk
			# up to rather than a thing that arrives, and it is the only species left in this branch.
			dir = Vector2.ZERO
		critter_dir[k] = dir

		var speed := Rules.HOST_SPEED * float(Rules.SPECIES_SPEED_MUL[s]) * terrain.speed_mul(p)
		var next := terrain.push_out(_clamp_field(p + dir * speed * dt), critter_radius(k))
		# ⚠ **The boss, and only the boss, is held inside the arena it closed.** The circle is the one wall
		# the run's last act is fought inside, and nothing else here ever put the boss back in it: a boss
		# that ends up outside walks the host's cage empty while the host cannot follow. Ordinary creatures
		# are deliberately left free — a crow wandering out of the fight is not worth a wall.
		if s == Parts.Species.BOSS:
			next = terrain.clamp_to_arena(next, critter_radius(k))
		# ⚠ **Clones are walls, and the `and not _blocked(p, k)` half is not decoration.** A predicate on the
		# destination alone freezes any creature that is ALREADY overlapping a body — which happens the
		# instant a clone walks onto a standing crow, and to a whole swarm at once when the arena's summon
		# teleports it onto whatever is underneath. Every candidate near `p` would then be blocked too and
		# the creature is stuck for the rest of the run. Blocking only moves that REDUCE clearance lets an
		# overlapped creature walk out. `_blocked` exempts the boss outright — see its own comment.
		if _blocked(next, k) and not _blocked(p, k):
			next = p
		critter_pos[k] = next
		# The return value says row `k` no longer holds the creature it held, so the index must NOT advance:
		# whatever is in it now is unstepped, or the row is past the end and the loop condition ends the walk.
		if _contact(k, next):
			continue
		k += 1


## The FIELD's edge, which every creature obeys. The arena's is a separate wall and only the boss obeys it
## — see the `clamp_to_arena` call in `_step_critters`. ⚠ **This comment used to say the boss was inside the
## arena by construction and needed no clamp; that was measured false** and the clamp is now written out.
## A crow wandering out of the fight is still not worth a wall.
func _clamp_field(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.0, Rules.FIELD.x), clampf(p.y, 0.0, Rules.FIELD.y))


## Is any body in the way at `p`. **This is the mechanism herding is made of** — the design says a horse
## stops dead against a rock, a clone or the field edge, and rocks and the edge were the only two that
## existed.
##
## ⚠ **The boss is exempt, always.** A boss walking at a host ringed by forty clones would otherwise stop
## on the outermost one and never reach the arena's radius: a wall of bodies, which is exactly the escape
## the design says does not exist. The exemption matters MORE at the deferred 0.75× speed, not less — a
## boss that is both slower than the host and stoppable by a ring never arrives by any route at all.
func _blocked(p: Vector2, k: int) -> bool:
	if critter_species[k] == Parts.Species.BOSS:
		return false
	var r := critter_radius(k)
	for i in swarm.count:
		var body_r := Rules.BODY_RADIUS if i == 0 else Rules.CLONE_BODY_RADIUS
		if p.distance_to(swarm.pos[i]) < r + body_r:
			return true
	return false


## **The shared body of both radius functions**, and the two guards in it are each a bug that was written
## down before it was written out.
##
## ⚠ `species < 0` first: `Parts.Species.NONE` is `-1`, which is a perfectly legal GDScript index and
## returns the LAST row of every table — a corpse of nothing would come back the size of the boss.
## ⚠ `maxi(1, MAX - MIN)`: the boss's minimum and maximum force are the same number on purpose, so the span
## is zero and `120 / 0` is NaN. A NaN radius is unhittable, undrawn, and poisons every comparison it
## touches into passing silently.
func _radius_of(species: int, force_value: int) -> float:
	if species < 0:
		return 0.0
	var lo := int(Rules.SPECIES_FORCE_MIN[species])
	var hi := int(Rules.SPECIES_FORCE_MAX[species])
	var span := float(maxi(1, hi - lo))
	var ramp := clampf((float(force_value) - float(lo)) / span, 0.0, 1.0)
	# Size belongs to the SPECIES; force leans on it by at most half again, so a maxed crow (18) never
	# reaches the weakest horse (22).
	return float(Rules.SPECIES_RADIUS[species]) * (1.0 + 0.5 * ramp)


## **The name survives and the body is replaced**, which is why the view keeps working across this plan.
func critter_radius(k: int) -> float:
	return _radius_of(critter_species[k], critter_force[k])


## How far a creature can touch from its centre. **`_contact` only** — the view draws the radius, not this.
##
## The bonus exists for one species: 물기 reaches `RANGE 70 + the boss's radius 48` = 118px while the boss's
## own contact would reach `48 + BODY_RADIUS 14` = 62px, and that 56px band is a force-10 host killing a
## 360-hp boss backpedalling, damage-free.
func critter_reach(k: int) -> float:
	return critter_radius(k) + float(Rules.SPECIES_REACH_BONUS[critter_species[k]])


## A corpse is the creature it came from, slightly collapsed. **Through `_radius_of`, not a formula of its
## own** — a second copy of the size rule is how a boss corpse ends up the size of a crow's.
func corpse_radius(i: int) -> float:
	return _radius_of(corpse_species[i], corpse_force[i]) * Rules.CORPSE_RADIUS_MUL


## How far a body can eat this corpse from. **The corpse's own size is part of the sum**: a reach measured
## from the centre alone means a boss carcass has to be stood on dead centre, which is the bug the user
## caught on the first play with food and is exactly what the two `EAT_RADIUS_*` constants were widened for.
func corpse_reach(i: int, is_host: bool) -> float:
	return (Rules.EAT_RADIUS_HOST if is_host else Rules.EAT_RADIUS_CLONE) + corpse_radius(i)


## A dead creature leaves a corpse where it fell, carrying copies of what it was.
##
## ⚠ **At the cap the kill leaves nothing and nothing is evicted.** "I came back and my kill was gone" is a
## bug report; a kill in the middle of a pile of sixty-four that quietly paid nothing is one confused frame.
func _add_corpse(p: Vector2, species: int, force_value: int) -> void:
	if corpse_count >= Rules.CORPSE_MAX:
		return
	var i := corpse_count
	corpse_pos[i] = p
	corpse_species[i] = species
	corpse_force[i] = force_value
	corpse_progress[i] = 0.0
	corpse_count += 1


## Swaps **all four** columns down, the same discipline every flat table here obeys. Without it the row a
## finished corpse leaves behind keeps another corpse's progress, species and worth — and the number it
## keeps is the one that just paid out, so the next meal is free.
func _remove_corpse(i: int) -> void:
	var last := corpse_count - 1
	if i != last:
		corpse_pos[i] = corpse_pos[last]
		corpse_species[i] = corpse_species[last]
		corpse_force[i] = corpse_force[last]
		corpse_progress[i] = corpse_progress[last]
	corpse_count -= 1


## The eating beat. **Two phases, and the split is what makes the rule below true.**
##
## ⚠ **Progress advances ONCE PER FRAME, not once per eater.** Forty clones on the boss would finish a
## six-second meal in 0.15s — and forty bodies on one point is precisely what `1` and `V` produce, so the
## beat would vanish at the one moment it was built for. The meal takes the same time whoever is eating;
## what the crowd buys is that somebody is always standing on it.
##
## ⚠ **And a body eats ONE corpse at a time — the nearest in reach**, which is why phase A exists at all.
## Walking corpses and collecting their eaters instead lets one clone standing in a pile advance every
## corpse in it at once, so a pile finishes in the time of its slowest member.
func _step_corpses(dt: float) -> void:
	if corpse_count <= 0:
		return
	# -- phase A: one pick per BODY. -1 is "nothing in reach", and every row is written below. --
	var pick := PackedInt32Array()
	pick.resize(swarm.count)
	for bi in swarm.count:
		var best := -1
		var best_d := 0.0
		for ci in corpse_count:
			var d := swarm.pos[bi].distance_to(corpse_pos[ci])
			if d > corpse_reach(ci, bi == 0):
				continue
			if best < 0 or d < best_d:
				best = ci
				best_d = d
		pick[bi] = best

	# -- phase B: backwards over corpses, because finishing one swaps the last row down into it. --
	for ci in range(corpse_count - 1, -1, -1):
		# **Bodies ascending, first match wins** — row 0 is the host, so this IS the rule "the host if the
		# host is among them, else the lowest clone index", with no second comparison to keep in step.
		var eater := -1
		for bi in swarm.count:
			if pick[bi] == ci:
				eater = bi
				break
		# **Progress is kept, not reset.** Coming back resumes; that is the whole cost of being interrupted.
		if eater < 0:
			continue
		# `EAT_TIME` is the corpse's own force × the constant, never a flat number: a crow is half a second
		# and the boss is six, and "a crow is a mouthful, the boss is the end of the run" is the beat.
		# The floor is for hand-written fixtures only — no spawned creature has force 0.
		corpse_progress[ci] += dt / maxf(0.0001, float(corpse_force[ci]) * Rules.EAT_TIME_PER_FORCE)
		if corpse_progress[ci] < 1.0:
			continue
		# ⚠ **`eat(eater, ...)`, never `eat(0, ...)`.** A clone's kill lands in `carried`, where losing the
		# clone on the way home still costs you the meal — that is the entire cargo rule, and paying it into
		# `banked` deletes it while every total in the round still adds up.
		swarm.eat(eater, float(corpse_force[ci]) * Rules.EXP_PER_FORCE)
		if not species_eaten.has(corpse_species[ci]):
			# First-eaten ORDER, not a set: the ending screen prints the order it happened in. This is also
			# the one line that opens the card pool, and the crow is what a run meets first.
			species_eaten.append(corpse_species[ci])
		if corpse_species[ci] == Parts.Species.BOSS:
			# **The corpse ends the run, not the kill.** Killing it and walking away leaves the run open.
			stage_cleared = true
		# **Clones only**, and the caller is what enforces it: the host's parts come from cards and only
		# from there, so `eater == 0` rolls nothing.
		if eater > 0:
			_roll_part(eater, corpse_species[ci])
		_remove_corpse(ci)


## A clone wears what it finishes. **The pool is SCANNED off the table, never hardcoded** — the table is the
## content, so a row added to `parts.gd` is in the pool the same day, and a hand-written list of droppable
## ids beside it is the thing that diverges instead. `Parts.DROPS` is what keeps 말 갈기 and 말 폐활량 out
## of this build's pool without deleting their rows.
##
## The length comes off `Parts.SPECIES` because `parts.gd` declares no row count of its own; `net_parts`
## asserts every column is the same length, which is what makes reading one of them safe.
func _roll_part(eater: int, species: int) -> void:
	if _rng.randf() >= Rules.PART_DROP_CHANCE:
		return
	var pool := PackedInt32Array()
	for p in Parts.SPECIES.size():
		if int(Parts.SPECIES[p]) == species and int(Parts.DROPS[p]) == 1:
			pool.append(p)
	if pool.is_empty():
		return
	var part: int = pool[_rng.randi_range(0, pool.size() - 1)]
	if swarm.worn[eater] >= 0:
		# ⚠ **Subtract then add, in the same call** — the written-never-derived rule `Body.wear()` obeys, and
		# for the same reason: force is stored per body because `F` halves it.
		#
		# `maxi(0, ...)` is load-bearing. `F` halves a body's force but NOT the FORCE column of what it
		# wears, so a force-2 clone wearing 말 다리 (5) sits at 7, splits to 3, and swapping to 까마귀 발 (2)
		# would leave it at -2 before the new part lands. Negative force is negative damage, and negative
		# damage HEALS the thing it hits — `_damage_critter`'s own `maxi` is this pair's other half.
		swarm.force[eater] = maxi(0, swarm.force[eater] - int(Parts.FORCE[swarm.worn[eater]]))
		# hp moves with the part exactly as force does, floored: a damaged clone trading an HP-5 part for an
		# HP-0 one would otherwise land at 0 and be alive until something touched it.
		swarm.hp[eater] = maxi(Rules.BODY_HP_MIN,
				swarm.hp[eater] - int(Parts.HP[swarm.worn[eater]]))
	swarm.worn[eater] = part
	swarm.force[eater] += int(Parts.FORCE[part])
	# ⚠ **A clone has no ceiling**, so `Parts.HP` on one both raises and HEALS. Deliberate and one line to
	# change; the host is the only body with an `hp_max()`.
	swarm.hp[eater] += int(Parts.HP[part])


## **The run's last act, and it is one comparison.** The boss walks at the host after `Rules.BOSS_HUNT_AT`
## (see `_step_critters`); the moment it is within `Rules.ARENA_RADIUS` the field becomes a circle centred
## between the two and the scattered swarm is handed back inside it. It happens once — `close_arena()`'s own
## early return is what makes that structural rather than a condition kept in step here.
##
## The host needs no clamp written here: `Swarm.place()` runs `clamp_to_arena` on every move already, which
## is why that function is the only place a body's position is finalised.
##
## ⚠ **Nothing here waits for the boss to arrive on its own, and no check may.** `Rules.SPECIES_SPEED_MUL`'s
## boss entry is below the host's speed, so a player who keeps walking is never caught and this may not fire
## in a whole run. That is a tuning number the user deferred to the first play session — raise that ONE
## constant, nothing here changes — and the deferral is written down in its own decisions doc.
func _step_arena() -> void:
	# ⚠ **The hunt has to have started, and distance alone is not that.** A boss still wandering
	# (`_rng.randf() < dt * 0.6`, ~250px segments at 150px/s) random-walks further than the field over the
	# 150 seconds before it hunts, so drifting once inside `ARENA_RADIUS` closed the arena at t = 20 —
	# permanently, with nothing drawn to explain it, around a boss that then walked back out and a host that
	# could not follow. The whole sentence this function implements is "the run's LAST act".
	if elapsed < Rules.BOSS_HUNT_AT:
		return
	# `boss_index` is -1 once the boss is dead, and the guard is what makes the ending safe: without it this
	# reads `critter_pos` of whatever `_remove_critter()` swapped down, or a row past `critter_count`.
	if boss_index < 0 or terrain.arena_closed:
		return
	var bp := critter_pos[boss_index]
	if bp.distance_to(swarm.pos[0]) > Rules.ARENA_RADIUS:
		return
	# The midpoint of the two, so the fight opens with neither of them standing on the rim.
	terrain.close_arena((bp + swarm.pos[0]) * 0.5)
	# **A teleport around the HOST, not a clamp to the rim.** A clone 3000px out clamped to the circle lands
	# somewhere on the arena edge, arbitrarily far from the host — "the scattered swarm is summoned into it"
	# is the sentence, and clamping satisfies the letter of it while handing back nothing.
	#
	# ⚠ **Through `swarm.place()`, never a bare write to `pos[i]`.** A 300px ring around the host holds rocks
	# of radius up to 90; a hand-written position drops a clone inside one, and the next frame's `push_out`
	# then shoves it out along whatever normal it happens to have — or along `Vector2.RIGHT` if it landed
	# dead centre. `place()`'s "the only place a position is finalised" means this call site too.
	for i in range(1, swarm.count):
		var offset := (swarm.pos[i] - swarm.pos[0]).limit_length(Rules.ARENA_SUMMON_RING)
		swarm.pos[i] = swarm.place(swarm.pos[0] + offset, Rules.CLONE_BODY_RADIUS)


## THE one place a creature loses hp. Returns true when it died, so callers stop touching index `k`.
##
## ⚠ **`maxi(0, amount)` on the first line.** Negative damage HEALS, and a negative attacker force is
## reachable: the corpse part roll subtracts a bigger part's force from a body that has since been halved.
## `Swarm.damage()` carries the same pair for the same reason.
func _damage_critter(k: int, amount: int) -> bool:
	critter_hp[k] -= maxi(0, amount)
	# **The counter is armed by damage from ANY source** — a bite, a clone's contact, a worn part's swing.
	# That is the whole of "the crow stands and counters": walk up to it and it hits back.
	if critter_species[k] == Parts.Species.CROW:
		critter_counter[k] = Rules.CROW_COUNTER_TIME
	if critter_hp[k] > 0:
		return false
	# ⚠ **The corpse is added BEFORE the row is removed**, because it copies three of that row's values and
	# `_remove_critter()` swaps a stranger into `k` on this very call. Reading them afterwards is the same
	# ordering bug `_damage_clone()` spends its whole doc comment on, in a second place.
	#
	# **A kill pays nothing by itself.** The 경험치, the species record and the part roll all hang off
	# something standing here long enough to finish the corpse — that is the whole beat.
	_add_corpse(critter_pos[k], critter_species[k], critter_force[k])
	_remove_critter(k)
	return true


## Returns how many creatures were hit. **THE one place damage is dealt by an attack**, from the host's key
## and from a clone's worn part alike.
##
## Every creature the cone covers, not the nearest — no `return` inside the loop. Backwards, because
## `_remove_critter` swaps the last row down into `k`.
func strike(origin: Vector2, facing: Vector2, part: int, attacker_force: int) -> int:
	if part < 0 or part >= Parts.SHAPE.size() or Parts.SHAPE[part] != Parts.Shape.ARC:
		return 0
	var reach := float(Parts.RANGE[part])
	var half_arc := float(Parts.ARC[part]) * 0.5
	var hits := 0
	for k in range(critter_count - 1, -1, -1):
		var to: Vector2 = critter_pos[k] - origin
		# **The target's own size counts.** Reach measured centre-to-centre alone means a boss 48px wide is
		# missed from a distance a crow would be hit at.
		if to.length() > reach + critter_radius(k):
			continue
		if absf(facing.angle_to(to)) > half_arc:
			continue
		hits += 1
		_damage_critter(k, attacker_force)
	return hits


## The shell's one entry point for the three keys. **`Body` may not hold a `World`** — it is already held
## BY one and a RefCounted cycle never frees — so the ARC branch's damage is dispatched here, from the part
## id read before delegating.
##
## `Body.fire()` returns a bool, never the part, which is why the id is read first.
func fire(key: int, aim: Vector2) -> bool:
	var part := -1
	if key >= 0 and key < body.bound.size():
		part = body.bound[key]
	if not body.fire(key, aim):
		return false
	if part >= 0 and Parts.SHAPE[part] == Parts.Shape.ARC:
		# `swarm.bite_aim` and not the raw `aim`: it is the direction the sim itself tested, so the cone
		# drawn, the cone tested and the cone that damages are one thing.
		strike(swarm.pos[0], swarm.bite_aim, part, swarm.force[0])
	return true


## Damage one clone. **`carried[i]` is read BEFORE the call and that ordering is the whole function.**
## `remove_at()` swaps the last row into `i`, so reading it afterwards reads a SURVIVOR's cargo — the clone
## that died is credited with someone else's haul, the ending screen's 지고 있던 것 is quietly wrong, and
## nothing anywhere goes red.
##
## The bookkeeping is `World`'s, which is why it cannot live on `Swarm`.
func _damage_clone(i: int, amount: int) -> bool:
	var cargo := swarm.carried[i]
	if not swarm.damage(i, amount):
		return false
	cargo_lost += cargo
	clones_lost += 1
	return true


## Returns true when row `k` no longer holds the creature it held on entry — it died, or a swap moved it —
## so the caller stops touching index `k`. **An identity, never a count**; see `_watched_row`.
##
## ⚠ **Two passes, and the host is checked first in the second one.** A single backwards pass makes index 0
## the LAST body considered while the retaliation stops at the first body in reach, so a creature touching
## both the host and any clone always hits the clone — and "a boss reaching the host takes 120 off it in one
## touch" would be true only in a swarm of one.
##
## Contact is centre-to-centre against the SUM of the radii, both ways.
func _contact(k: int, p: Vector2) -> bool:
	var reach := critter_reach(k)
	# -- pass 1: clones attack what they touch. Backwards, because `remove_at` swaps down. --
	for i in range(swarm.count - 1, 0, -1):
		var worn: int = swarm.worn[i]
		var swings: bool = worn >= 0 and Parts.SHAPE[worn] == Parts.Shape.ARC
		# ⚠ **The band is the CLONE's, and for a worn active it is exactly the band `strike()` hits in.**
		# `critter_reach()` carries `SPECIES_REACH_BONUS`, which exists so the boss out-reaches 물기 — read
		# here it admitted a clone at 126px from the boss and then swung an 88px beak: zero damage, a full
		# `CLONE_ATTACK_PERIOD` burned, every period, while the same clone with nothing on dealt its force.
		# Wearing the stage's own reward made a clone strictly WORSE in the fight it was dropped for.
		var band: float = (float(Parts.RANGE[worn]) + critter_radius(k)) if swings \
				else (critter_radius(k) + Rules.CLONE_BODY_RADIUS)
		if p.distance_to(swarm.pos[i]) > band:
			continue
		if swarm.atk_cd[i] > 0.0:
			continue
		if swings:
			var aim: Vector2 = p - swarm.pos[i]
			# ⚠ **No direction, no swing — and no cooldown for one.** `Vector2.ZERO.angle_to(to)` is
			# `atan2(0, 0)`, which is 0 for EVERY target, so a creature standing dead centre on a clone
			# turns its cone into a full circle and the swing lands 180° behind it. Reachable: `_blocked()`
			# deliberately lets an already-overlapped creature stand, and the arena's summon teleports up to
			# forty clones onto whatever is underneath them. The overlap resolves on its own next frame.
			if aim.length_squared() < 0.0001:
				continue
			swarm.atk_cd[i] = Rules.CLONE_ATTACK_PERIOD
			# ⚠ `strike()` returns a HIT COUNT, never "row k died" — and the cone hits every creature it
			# covers, so a count delta answers "somebody died". `_watched_row` is the identity: -1 when this
			# creature died, a different index when the swap moved it, and either way every line below
			# would be reading a stranger — or, past `critter_count`, a stale row the cap never cleared.
			_watched_row = k
			strike(swarm.pos[i], aim.normalized(), worn, swarm.force[i])
			var still := _watched_row
			_watched_row = -1
			if still != k:
				return true
		else:
			swarm.atk_cd[i] = Rules.CLONE_ATTACK_PERIOD
			if _damage_critter(k, swarm.force[i]):
				return true

	# -- pass 2: it hits back, ONCE, and the host is checked first. --
	if critter_flees[k] == 1 or critter_atk_cd[k] > 0.0:
		return false
	if p.distance_to(swarm.pos[0]) <= reach + Rules.BODY_RADIUS:
		critter_atk_cd[k] = Rules.CLONE_ATTACK_PERIOD
		if host_grace <= 0.0:
			# Its own force, in this direction exactly as in the other. Nothing gates who may hurt whom.
			host_hp -= critter_force[k]
			host_grace = Rules.HOST_HIT_GRACE
		return false
	for i in range(swarm.count - 1, 0, -1):
		if p.distance_to(swarm.pos[i]) > reach + Rules.CLONE_BODY_RADIUS:
			continue
		critter_atk_cd[k] = Rules.CLONE_ATTACK_PERIOD
		# ⚠ **The clone is DAMAGED, not deleted** (user: 분신도 체력을 가질 거야). It loses its cargo, its
		# force and its worn part only when its hp reaches zero, and `_damage_clone` is where the reading
		# order that keeps the cargo honest lives.
		#
		# ⚠ **And `_damage_clone`'s return is NOT this function's return.** `_contact` means "creature `k`
		# died"; a clone dying does not change `k`'s row, and folding the two would make `_step_critters`
		# skip a live creature. One character, entirely plausible, invisible in final state.
		_damage_clone(i, critter_force[k])
		return false
	# ⚠ **One creature, one attack, one period.** The loop returns after the FIRST clone in reach, so a crow
	# standing in a pile of forty chips one of them every period instead of attacking forty — a wide swarm
	# still pays, and it pays in a currency you can watch.
	return false


## Swaps **all eight** columns down and then repairs `boss_index`. Eight is the whole table — a ninth added
## without a line here lands a dead creature's number on a survivor, with nothing on screen to say so.
func _remove_critter(k: int) -> void:
	var last := critter_count - 1
	if k != last:
		critter_pos[k] = critter_pos[last]
		critter_dir[k] = critter_dir[last]
		critter_species[k] = critter_species[last]
		critter_force[k] = critter_force[last]
		critter_hp[k] = critter_hp[last]
		critter_flees[k] = critter_flees[last]
		critter_atk_cd[k] = critter_atk_cd[last]
		critter_counter[k] = critter_counter[last]
	# **Both halves, and each is its own bug.** The boss dying is what the run's ending walks through; the
	# boss being the LAST row is what every other creature's death walks through. Missing either leaves an
	# index pointing at a stranger, or past `critter_count` entirely.
	if k == boss_index:
		boss_index = -1
	elif last == boss_index:
		boss_index = k
	# The same repair, on the cursor `_contact()` is holding. See that field's own comment.
	if k == _watched_row:
		_watched_row = -1
	elif last == _watched_row:
		_watched_row = k
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
## climbs with every level while the number on the left of the HUD's `현재/최대` stays where it was, which
## reads as the maximum being decoration.
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
	# is what says the pool can actually produce something — and since the corpse beat landed, the first
	# crow finished opens it, which is what makes "a run showed zero cards" impossible rather than unlikely.
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
	# ⚠ **Floored at 1: taking a card may not end the run.** Digesting a 말 갈기 gives back the hp that part
	# was carrying (`Parts.HP`, 5), and a host already under that would flip to ENDING·DIED on the very next
	# frame — killed by a level-up, from a screen with no way to decline. The plan gives HP no floor anywhere
	# and `_contact()` is meant to be the only thing that can reach zero. **Not "a heart"** — there is no
	# heart row any more; the HUD prints 현재/최대 as a number.
	host_hp = maxi(1, host_hp + delta)
	pending_levels -= 1
	offer = Cards.roll(_rng, species_eaten) if pending_levels > 0 else PackedInt32Array()
	return true


## The periodic arrival. **`BOSS` is never rolled** — its weight is 0, `setup()` places exactly one, and
## there is never a second.
##
## ⚠ **The weights are summed here rather than assumed to total anything.** Written against a hardcoded sum
## a row added to `SPECIES_SPAWN_WEIGHT` would shift every species' share and the last row would be
## unreachable, which is a bug that looks exactly like bad luck.
func _spawn_critter() -> void:
	_spawn_herd(_roll_species())


## Pure enough to drive: give it the rng and it walks the weight table. **Falls back to the last non-zero
## row**, never to CROW — a fallback naming a species is a second place the table is written.
func _roll_species() -> int:
	var total := 0
	for w in Rules.SPECIES_SPAWN_WEIGHT:
		total += int(w)
	if total <= 0:
		return int(Parts.Species.CROW)
	var pick := _rng.randi_range(0, total - 1)
	var last := int(Parts.Species.CROW)
	for s in Rules.SPECIES_SPAWN_WEIGHT.size():
		var w := int(Rules.SPECIES_SPAWN_WEIGHT[s])
		if w <= 0:
			continue
		last = s
		pick -= w
		if pick < 0:
			return s
	return last


## **One roll of a spot, `SPECIES_HERD[species]` bodies around it.** This is the whole of "무리 지어 다닌다"
## in this build: nothing keeps a herd together afterwards, and nothing needs to — they are born neighbours,
## they wander at the same speed, and a straggler falling out of the group is what the design wants to be
## catchable. Coding cohesion would have to code the straggler back in.
##
## **How far a HERD's anchor must be from the host**, which is not the same number as a lone creature's.
## A member is placed within `SPAWN_HERD_SPREAD` of the anchor and deliberately does not re-test the
## distance itself — so the spread has to be paid for up front, or the far side of a herd rolled at exactly
## `CRITTER_SPAWN_MIN_DIST` lands 220px inside the guarantee and something materialises on screen. Measured:
## the first run of this with a flat minimum spawned a member at 865px against the literal 900.
func _anchor_min_dist(species: int) -> float:
	var extra := Rules.SPAWN_HERD_SPREAD if int(Rules.SPECIES_HERD[species]) > 1 else 0.0
	return Rules.CRITTER_SPAWN_MIN_DIST + extra


## Returns the number actually written, which is short of the herd size at the cap.
func _spawn_herd(species: int) -> int:
	var size := maxi(1, int(Rules.SPECIES_HERD[species]))
	var born := 0
	var anchor := Vector2(-1.0, -1.0)
	for _m in size:
		var k := _spawn_at(species, anchor)
		if k < 0:
			break
		# The FIRST member's accepted position becomes the anchor, so the rest are placed around a spot that
		# has already passed the distance and rock rules rather than around a raw sample.
		if anchor.x < 0.0:
			anchor = critter_pos[k]
		born += 1
	return born


## **The one place an ordinary creature row is born.** Returns -1 at the cap.
##
## Off-camera, never on top of the player and never inside a rock: something materialising in your lap
## reads as a bug, and something materialising inside a wall is pushed out along a normal from wherever it
## landed on the next frame, which reads as worse.
##
## **`anchor` is the herd's spot**, or a negative vector for "roll one anywhere". A herd member samples in a
## `SPAWN_HERD_SPREAD` disc around the anchor and obeys the same rock rule; it does NOT re-check the distance
## to the host, because the anchor already cleared it and re-checking would scatter a herd across the map
## whenever the host happened to stand near it.
func _spawn_at(species: int, anchor: Vector2 = Vector2(-1.0, -1.0)) -> int:
	if critter_count >= Rules.CRITTER_MAX:
		return -1
	var host: Vector2 = swarm.pos[0]
	# Force first, because the radius the rejection tests is this creature's own.
	var force_value := _rng.randi_range(int(Rules.SPECIES_FORCE_MIN[species]),
			int(Rules.SPECIES_FORCE_MAX[species]))
	var r := _radius_of(species, force_value)
	var p := host
	for _try in Rules.PLACE_TRIES:
		if anchor.x >= 0.0:
			var a := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * Rules.SPAWN_HERD_SPREAD
			p = _clamp_field(anchor + Vector2(cos(a), sin(a)) * d)
			if terrain.push_out(p, r) == p:
				break
			continue
		p = Vector2(_rng.randf_range(0.0, Rules.FIELD.x), _rng.randf_range(0.0, Rules.FIELD.y))
		if p.distance_to(host) >= _anchor_min_dist(species) and terrain.push_out(p, r) == p:
			break
	# Falling through the tries uses the last sample PUSHED OUT, which is the one thing that cannot be
	# inside a rock. Distance is the softer of the two rules and is the one that gives.
	p = terrain.push_out(p, r)
	return _write_critter(species, p, force_value)


## The boss gets **its own sampler**, and the count is not decoration: the band at `BOSS_SPAWN_MIN_DIST`
## from the field's centre is 12.2% of the field, so the shared twelve tries fall through about one call in
## five, and a placement check has to be provably green rather than green seven times in ten.
func _place_boss() -> void:
	var species := int(Parts.Species.BOSS)
	var host: Vector2 = swarm.pos[0]
	var force_value := _rng.randi_range(int(Rules.SPECIES_FORCE_MIN[species]),
			int(Rules.SPECIES_FORCE_MAX[species]))
	var r := _radius_of(species, force_value)
	var spot := terrain.push_out(_clamp_field(_boss_spot(host, Rules.BOSS_PLACE_TRIES)), r)
	boss_index = _write_critter(species, spot, force_value)


## Where the boss opens, as a pure function of the host and how many samples it is allowed. **`tries` is an
## argument and not a direct read of `Rules.BOSS_PLACE_TRIES` for one reason**: the backstop below fires
## only when every sample falls inside `BOSS_SPAWN_MIN_DIST`, which at 200 tries is a 1-in-10¹¹ event and
## therefore unreachable by driving `setup()`. Passing 0 is how a check reaches the branch at all — the
## sampler and the backstop each satisfied the placement floor on their own and neither was measured, so
## `BOSS_PLACE_TRIES → 0`, `if false:` on the guard, and a backstop rewritten to `best = host` (**the boss
## spawns on top of the player**) were all green.
##
## ⚠ **It does NOT track the farthest sample, and the doc line that said so was describing dead code.**
## The loop breaks the instant a sample clears the floor, so the kept point is always that breaking sample;
## whenever the tracking would have mattered no sample cleared the floor and the backstop overrides the
## answer anyway. `if d > best_d:` → `if true:` was green and always would be. Same seed stream: one
## `randf` pair per try either way, accepted or not.
func _boss_spot(host: Vector2, tries: int) -> Vector2:
	for _try in tries:
		var p := Vector2(_rng.randf_range(0.0, Rules.FIELD.x), _rng.randf_range(0.0, Rules.FIELD.y))
		if p.distance_to(host) >= Rules.BOSS_SPAWN_MIN_DIST:
			return p
	return _boss_backstop(host)


## The field corner farthest from the host, inset so the boss is not half outside the world. Pure, and it
## is a function rather than four lines inside the sampler so that a check can pin all four quadrants.
func _boss_backstop(host: Vector2) -> Vector2:
	var inset := 200.0
	return Vector2(inset if host.x > Rules.FIELD.x * 0.5 else Rules.FIELD.x - inset,
			inset if host.y > Rules.FIELD.y * 0.5 else Rules.FIELD.y - inset)


## The row write both spawners share — **all eight columns, in one place**, so a new column cannot be
## written by one path and forgotten by the other.
func _write_critter(species: int, p: Vector2, force_value: int) -> int:
	var k := critter_count
	critter_pos[k] = p
	# A **unit** vector. `resize()` zero-fills, and a zero direction is a creature that never moves and is
	# drawn at rotation 0 with nothing to say so.
	var a := _rng.randf() * TAU
	critter_dir[k] = Vector2(cos(a), sin(a))
	critter_species[k] = species
	critter_force[k] = force_value
	critter_hp[k] = force_value * Rules.HP_PER_FORCE
	# Born with its species' disposition. The column stays per-creature because that is what the movement
	# code reads and a later stage varies it individually.
	critter_flees[k] = int(Rules.SPECIES_FLEES[species])
	# **Every body and every creature opens READY** — the three tables that start an attack clock may not
	# differ, or a row born mid-run lands its first hit a full period late for a reason nothing states.
	critter_atk_cd[k] = 0.0
	critter_counter[k] = 0.0
	critter_count += 1
	return k
