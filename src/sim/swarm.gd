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
##
## ⚠ **There are four hand-maintained columns now, not one** — `force`, `worn`, `atk_cd` and `hp`. Three
## of them share exactly those three points. `hp` has a **fourth**, `_split_fire()`, and it is the only one
## whose value at the split is not a constant: the split changes `force[i]` after `add_clone()` has already
## returned, so the parent's health has nowhere else to be corrected.
var force := PackedInt32Array()

## One part id per body, -1 = none. **Index 0 (the host) is always -1**: the host's parts live in `Body`'s
## eleven slots and come from cards only. ⚠ `resize()` zero-fills and `0 == Parts.BITE`, so a missed
## `worn[0] = -1` is a host silently wearing 물기 — the same -1-is-a-legal-index trap `Body.bound` names.
var worn := PackedInt32Array()

## Contact-attack cooldown per body. `eat_cd` is the FOOD clock and is already spoken for; a clone that
## attacks whatever it touches needs its own, or the two rates fight over one number.
var atk_cd := PackedFloat32Array()

## Hit points per body, and it is **STORED, never derived** — the same rule `force` obeys one column up and
## for the same reason: `F` halves force, and a derived ceiling would halve or restore a body's health on
## the tutorial keystroke. Written at birth from that body's own force × `Rules.HP_PER_FORCE`.
##
## ⚠ **Row 0 is the sentinel -1 and nothing reads it.** The host's health is `World.host_hp` and it stays
## there. Writing the host's real health here too is "a value counted in two places will diverge" breaking
## on the one number a run ends on, so `damage()` refuses index 0 outright — a caller that reaches for it
## gets a refusal rather than a second, quietly wrong, health bar.
var hp := PackedInt32Array()

## Seconds since this body was last hit, counted UP — the same shape `bite_show` already uses, and for the
## same reason: counting down cannot tell "just hit" from "never hit" once it reaches zero. Opens at `INF`.
## Row 0 is the host: `Swarm.damage()` refuses index 0 outright, so `World._contact()`'s host site is the one
## place this row is written, matching `worn[0]`'s own -1-forever pattern for an index the swap never reaches.
var hit_show := PackedFloat32Array()
## Which way that hit came from (unit, or `Vector2.ZERO` before the first hit). The knockback that moves
## `pos` and the flash the view draws both read this.
var hit_dir := PackedVector2Array()
## Seconds since this body last SWUNG at something, counted up the same way — and now written (§B-5):
## `World._contact()`'s pass 1 marks it `0.0` on every clone that actually lands a hit, whether bare-handed
## or through a worn ARC part, at the same moment it sets that clone's own `atk_cd`.
var swing_show := PackedFloat32Array()
## Which way that swing landed — clone toward what it hit (unit, or `Vector2.ZERO` before the first swing).
## The short line `field_view.gd` draws for `Look.CLONE_HIT_LINE_TIME` reads this; the shape mirrors
## `hit_dir`, one column for the hitting side instead of the hit side.
var swing_dir := PackedVector2Array()

## §B-3: which bodies died THIS frame, filled by `damage()` at the moment the row is about to be swapped
## away — `pos` and `carried` are read on the exact same side of `remove_at()` the cargo-loss bookkeeping
## already has to read them on (see the file header), because the row belongs to a stranger the instant the
## swap runs. **Cleared by `begin_frame()`, never by `view`** — `view` may not write `sim` (§0-2).
var died_this_frame: Array[Dictionary] = []

## §F-7: which food spots were eaten THIS frame, filled by `_try_eat()` the moment a mouthful lands — `pos`
## is the food's own spot (fixed, never moves) and `to` is the eater's position that same frame, so `view`
## can draw the crumb travelling toward whichever body actually ate it rather than a fixed point. Cleared
## by `begin_frame()`, the same shape and the same reason `died_this_frame` already has.
var food_eaten_this_frame: Array[Dictionary] = []

## §F-10: where a split happened this frame, one entry per body that actually halved — the ORIGINAL
## position, before the two halves are shoved apart, so `view` can ring the point they came FROM rather
## than either half's new spot. Same clear-and-read shape as the two lists above.
##
## ⚠ **This is the list that proved the clear could not live at the top of `step()`.** `F` is a KEY: the
## shell fills this from `split_hold()` during its input phase, which runs BEFORE `step()`, so a clear at
## `step()`'s top wiped the entry on the same frame it was written and the ring never reached the screen
## once in the real game — with every check on this list green, because each one drives `split_hold()` and
## reads the list back without a `step()` in between. See `begin_frame()`.
var split_this_frame: Array[Dictionary] = []

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

## Seconds since the last bite landed, counted UP in `step()`. The view draws the cone while this is under
## `Look.BITE_SHOW_TIME` and the sim never reads `look.gd` — counting up rather than down is what lets the
## duration stay a presentation constant without breaking the folder contract, and the sim still owns the
## clock so the view holds no state the sim does not know about. Opens at INF: a run does not start
## mid-bite.
##
## ⚠ **These four stayed on `Swarm` while `bound`/`fire()` moved to `Body`**, and they had to: the view
## reads them off the swarm it already draws, and moving them without repointing `field_view.gd` leaves
## `bite_show` at INF forever — the cone simply never draws again, with no error and nothing red.
var bite_show := INF
## Which way the last bite pointed, so the cone the view draws is the cone the sim tested.
var bite_aim := Vector2.RIGHT
## And how big it was. **The shape is per part now, not a pair of `Rules` constants**, so three keys can
## each hold a different ARC part at a different level; the view has no other way to tell which one made
## this cone. Written by `bite()` on success alongside the two above.
var bite_range := 0.0
var bite_arc := 0.0

var host_input := Vector2.ZERO
var host_facing := Vector2.RIGHT

## A SELF burst: how long it has left and how fast it goes. **`dash_cd` is gone** — `Body.bound_cd[key]` is
## the one cooldown, so the two numbers that plan 2's comment warned could disagree about whether the hand
## is free are now one number.
var dash_left := 0.0
var dash_speed := 0.0
## Written by `Body.step()` every frame, read by `_move_host()`. 1.0 when no sustained active is running.
## It is a multiplier and not a speed because the parts table stores `SELF_MUL`, so retuning `HOST_SPEED`
## retunes what a gallop is worth rather than leaving an absolute behind to drift.
var active_speed_mul := 1.0

var clone_grid := SimGrid.new()
var food_grid := SimGrid.new()
var field := Rules.FIELD

## Set by `World.setup()` right after `setup()`, exactly the way `body.swarm` is set. **Null in a net that
## only measures steering** — a `Swarm` net must not need a `World` — so every use is guarded.
var terrain: Terrain = null

## The food the last `step()` was handed. `bite()` takes an aim and a shape and nothing else — the shell
## presses a key, it does not hand the simulation its own world back — so a bite reads whatever the frame
## it happens in was stepped with. Null before the first `step()`, and a bite then simply misses.
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
	worn.resize(Rules.POOL)
	atk_cd.resize(Rules.POOL)
	hp.resize(Rules.POOL)
	hit_show.resize(Rules.POOL)
	hit_dir.resize(Rules.POOL)
	swing_show.resize(Rules.POOL)
	swing_dir.resize(Rules.POOL)
	count = 1
	pos[0] = start
	vel[0] = Vector2.ZERO
	carried[0] = 0.0
	state[0] = FOLLOW
	eat_cd[0] = 0.0
	_target_food[0] = -1
	# `resize()` zero-fills, and 0 is a legal part id — see `worn`'s own comment for what a missed -1 here
	# looks like on screen (nothing) and in the sim (a host wearing 물기 it never earned).
	worn[0] = -1
	atk_cd[0] = 0.0
	# The sentinel. `World.host_hp` is the host's health; this row exists only so the column has the same
	# length as every other one.
	hp[0] = -1
	# The host is a body and it gets hit — `resize()`'s zero-fill is 0.0, not `INF`, and a host that opened
	# already "just hit" would flash and shake on frame one of every run.
	hit_show[0] = INF
	hit_dir[0] = Vector2.ZERO
	swing_show[0] = INF
	swing_dir[0] = Vector2.ZERO
	# §B-3/§F-7/§F-10: a fresh run has died nobody, eaten nothing and split nothing yet.
	died_this_frame.clear()
	food_eaten_this_frame.clear()
	split_this_frame.clear()
	# The one place the host's force is written from nothing. After this only splitting, absorbing, the
	# level and WEARING A PART move it — `Body.wear()` is the fourth writer and it both adds and subtracts,
	# in the same call, because a digested part that keeps paying is ghost force and `F` multiplies it.
	# The run opens with the host alone, so no body exists that did not come from a split. There is no
	# START_CLONES: with the constant still present, `count == 1 + START_CLONES` passes at every value,
	# including the zero that shipped once.
	force[0] = Rules.FORCE_START
	strike_point = start
	scatter_anchor = start
	split_charge = 0.0
	_hold_fired = false
	bite_show = INF
	bite_range = 0.0
	bite_arc = 0.0
	dash_left = 0.0
	dash_speed = 0.0
	active_speed_mul = 1.0
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
	# Through `place()`, not a bare write: splitting with your back against a rock or the field edge
	# otherwise spawns the child inside it, and nothing else ever pushes a body that never moved.
	pos[i] = place(pos[parent] + Vector2(cos(a), sin(a)) * Rules.CLONE_SPAWN_RING, Rules.CLONE_BODY_RADIUS)
	vel[i] = Vector2.ZERO
	carried[i] = 0.0
	force[i] = force_value
	state[i] = state[parent]
	eat_cd[i] = Rules.EAT_PERIOD_CLONE
	wander[i] = Vector2(cos(a), sin(a))
	_wander_cd[i] = Rules.WANDER_PERIOD
	_target_food[i] = -1
	# A clone is born wearing nothing. Parts reach a clone through the corpse roll and never through birth,
	# which is why this is a constant rather than a parameter — a `worn` argument here would make the split
	# a fourth maintenance point for the column and the split has no opinion about parts.
	worn[i] = -1
	# **Every body and every creature opens READY.** Three tables start an attack clock — this one,
	# `setup()`'s row-0 block and `World._spawn_at()` — and if one of them opened at `CLONE_ATTACK_PERIOD`
	# instead, a clone born touching a creature would wait a whole period before its first hit while the
	# other two did not, and no check comparing hit counts across bodies could be satisfied.
	atk_cd[i] = 0.0
	# Born FULL, through the same function the damage cap reads its ceiling from — written out here as a
	# second copy of `force × HP_PER_FORCE`, the birth value and the cap's ceiling could drift apart and
	# a body would be born above or below its own maximum with nothing to say so.
	# The floor inside it is not decoration: `force_value` defaults to 0 and every steering net in the round
	# calls this with no arguments. Without it those bodies are born at 0 hp — alive, drawn, and dead to the
	# first touch, with nothing red anywhere.
	hp[i] = hp_max_of(i)
	# A constant, unconditionally — exactly why `worn[i] = -1` above is one: writing it here is what keeps
	# `_split_fire()` from needing a fourth maintenance point of its own. **A newborn body has not been hit.**
	hit_show[i] = INF
	hit_dir[i] = Vector2.ZERO
	swing_show[i] = INF
	swing_dir[i] = Vector2.ZERO
	return i


## Swap with the last row. **The cargo, the force AND the worn part go with it, and nothing has to
## remember to drop them** — see the file header. That is also the whole of what a clone loses when it
## dies: `damage()` is four lines because this function is where the loss actually happens.
## Index 0 is the host and is never removable.
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
		worn[i] = worn[last]
		atk_cd[i] = atk_cd[last]
		hp[i] = hp[last]
		hit_show[i] = hit_show[last]
		hit_dir[i] = hit_dir[last]
		swing_show[i] = swing_show[last]
		swing_dir[i] = swing_dir[last]
	count -= 1


## Field clamp, then rocks, then the arena — **in that order, and this is the ONLY place a body's position
## is finalised.** Clamping to the field after pushing out of a rock can put the body back inside one;
## clamping to the arena first lets the rock push carry it back out through the rim.
##
## **Public**, and for a measured reason: `World`'s arena summon needs it too. Written by hand there it
## becomes a sixth call site that knows nothing about rocks, and a summoned clone lands inside one with
## every check about the summon green.
func place(p: Vector2, r: float) -> Vector2:
	p = _clamp_field(p)
	if terrain != null:
		p = terrain.push_out(p, r)
		p = terrain.clamp_to_arena(p, r)
	return p


## Which radius row `i` occupies the ground with. **The host and a clone are not the same size**, and this
## one expression is what every distance between a body and anything else is built out of — `_split_fire()`,
## `World._enters_a_body()` and both separation passes each need it. Written out by hand at each of them it is four
## chances for the host to quietly become clone-sized in one of the four.
func body_radius(i: int) -> float:
	return Rules.BODY_RADIUS if i == 0 else Rules.CLONE_BODY_RADIUS


## Move body `i` until it stands `min_d` from `centre`, and move **nothing else**. This is the one-way half
## of separation in one place: the clone↔host pair and both body↔creature pairs are the same correction
## against a point that does not move, and three hand-written copies of the branch below are three chances
## to write the epsilon that once threw a coincident pair ~80,000px.
##
## The coincident case is not hypothetical. `1` steers every clone at the host, the arena summon teleports
## up to forty onto whatever is under them, and a creature can be standing dead centre on a body when this
## runs. **The angle is deterministic from the row index** — never random, or the same overlap resolves
## differently every run and no net can pin it. Emptying it to `Vector2.ZERO` reds five checks across two
## nets, measured.
##
## ⚠ **`l = 0.0` here is a statement of intent and NOT the load-bearing line it is in `_separate()`.**
## Measured: setting it to `0.0001` instead leaves the whole round green, because this branch assigns `dir`
## outright and the push below never divides by `l` — the difference is a ten-thousandth of a pixel. The
## ~80,000px throw belongs to the clone↔clone branch, where the same shape *did* divide. Written the safe
## way anyway, so that a later edit reaching for `d / l` has nothing waiting for it.
##
## Through `place()`, like every other position write: separation runs after movement and is free to shove a
## body straight back into a rock `push_out` had already cleared this frame, with nothing after it to undo
## that. `place()` is also the whole of the answer to a body wedged between a creature and a rock — the push
## is cancelled or slid along the rock's surface rather than honoured through it.
##
## ⚠ **It will move the HOST if it is called with 0.** That is deliberate — a creature must push the host —
## and it is why the "the host is never moved by its own swarm" rule lives at `_separate()`'s guard, at the
## call site, and not in here.
func push_out_of(i: int, centre: Vector2, min_d: float) -> void:
	if i < 0 or i >= count:
		return
	var d := pos[i] - centre
	var l := d.length()
	var dir := Vector2.ZERO
	if l < 0.0001:
		var a := float(i) * 2.3999632
		dir = Vector2(cos(a), sin(a))
		l = 0.0
	else:
		dir = d / l
	if l >= min_d:
		return
	pos[i] = place(pos[i] + dir * (min_d - l), body_radius(i))


## `1`. **No argument: the swarm comes to the host**, and `_move_clone()` reads `pos[0]` live rather than
## a stored point. The argument used to be the mouse and this comment used to argue for it — that
## gathering at the host lets the player park in cleared ground while the clones take the risk. **That
## argument lost** (user, 2026-08-14): a command that sends the swarm somewhere is `3`, and one key that
## means "come here" is what the hand actually reaches for.
##
## ⚠ **This block spent a plan sitting above `place()`**, which was inserted between it and its own
## function — so a reader of the only place a position is finalised was first told it is the `1` key.
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


## A SELF burst, driven by `Body.fire()`. **The cooldown is NOT here** — `Body.bound_cd[key]` owns it, and
## that is what `fire()` refuses on. Plan 2's `try_dash()` kept its own `dash_cd` and read three deleted
## `Rules.DASH_*` constants; the burst's numbers are `SELF_MUL` and `SELF_TIME` on the part's row now, so
## a second SELF part is a row rather than a branch.
func begin_dash(mul: float, time: float) -> bool:
	if time <= 0.0:
		return false
	dash_left = time
	dash_speed = Rules.HOST_SPEED * mul
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


## Every row's force, host included. **`body_panel.gd`'s 무리의 힘 readout is its production caller** — the
## panel is where a player reads what the whole swarm is worth, and the number has to come from one place or
## the panel and the checks drift. Its other caller is the conservation checks; a hand-rolled sum inside
## every net would be the second copy `CLAUDE.md` forbids.
##
## ⚠ **It sums FORCE, never `count`, and that is why it survived the threat model that once read it.** The
## deleted prey/hunter comparison counted bodies for one build, and a split multiplies rows while conserving
## force — so `F` bought the reversal for free. Any future comparison of "how big is the swarm" belongs here
## and not on `count`.
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
##
## ⚠ **This is `hp`'s fourth maintenance point, and the only one whose value is not a constant.** Health is
## CONSERVED across the split exactly as force is: the child takes the floor half of what the parent had,
## the parent keeps the remainder, and the two always sum to what the parent had before.
## The rejected alternative was recomputing both halves to `force × HP_PER_FORCE`. It reads tidier and it
## makes `F` a **heal button** — a clone one hit from death presses one key and comes back whole. Splitting
## is not a power-up is the rule this whole column exists for, and a free heal is a power-up whatever the
## force column does.
##
## ⚠ **Both the hp refusal and the hp conservation are CLONE-ONLY, and the `i > 0` guard on each is
## load-bearing.** Row 0 carries the -1 sentinel because `World.host_hp` is the host's health. Written
## without the guard, `hp[0] < 2` is true of -1 and **the host never splits at all** — the tutorial
## keystroke, deleted; and `was / 2` off -1 is 0, so the host's first child is born at 0 hp, alive and dead
## to the first touch. The host's child keeps the full-for-its-force number `add_clone()` already wrote.
func _split_fire() -> void:
	var snapshot := count
	for i in snapshot:
		if force[i] < 2:
			continue
		# The same guard as `force[i] < 2`, for the same reason: a thing that cannot be halved without
		# producing nothing is not halved. At hp 1 the child takes 0 and the parent keeps 1 — or, with the
		# halves the other way round, a 0-hp parent that is ALIVE, because hp only kills at the moment
		# damage is applied and a zombie never dies of its own accord. No existing split check moved for
		# it: every clone the steering and force nets build is born at full hp and never damaged.
		if i > 0 and hp[i] < 2:
			continue
		var was := hp[i]
		var was_pos := pos[i]
		# Integer division floors, so the child takes the smaller half and the parent the remainder.
		var child := force[i] / 2
		var j := add_clone(i, child)
		if j < 0:
			return
		force[i] -= child
		if i > 0:
			hp[j] = was / 2
			hp[i] = was - hp[j]
		# §F-10: the two halves shove apart, through the exact formula and the exact `place()` funnel §A-3's
		# knockback already uses — `distance = force × Rules.KNOCKBACK_PER_FORCE`, this time the CHILD's own
		# force, so a sliver barely moves and a big half visibly does. Direction is the offset `add_clone()`
		# already placed the child at (`pos[j] - was_pos`), never a second random draw — the same discipline
		# `_write_critter()`'s own comment states: a column may not cost the shared `_rng` a draw, and this
		# is not even a column, but the habit is cheap to keep. Falls back to a fixed axis only in the
		# zero-length edge case a net drives by hand; `add_clone()` itself never produces one.
		var axis: Vector2 = pos[j] - was_pos
		var dir: Vector2 = axis.normalized() if axis.length_squared() > 0.0001 else Vector2.RIGHT
		var dist := float(child) * Rules.KNOCKBACK_PER_FORCE
		pos[i] = place(was_pos - dir * dist, body_radius(i))
		pos[j] = place(pos[j] + dir * dist, Rules.CLONE_BODY_RADIUS)
		# The ring `view` draws is at the point the split happened FROM, not either half's new spot.
		split_this_frame.append({"pos": was_pos})


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


# -- taking damage -------------------------------------------------

## What this body's hp was BORN at, and therefore its ceiling: `force × HP_PER_FORCE`, floored.
## `add_clone()` writes it and `World`'s one-blow cap divides it — a function rather than a column because
## it is a pure read of `force`, and a column would be a fourth thing `_split_fire()` has to maintain.
##
## ⚠ **Row 0 answers -1, the same sentinel `hp[0]` carries.** The host's maximum is `Body.hp_max(level)`,
## which counts levels and worn parts and has nothing to do with `force[0]`; answering a plausible number
## here would be a second, quietly wrong ceiling for the one body a run ends on.
func hp_max_of(i: int) -> int:
	if i <= 0 or i >= count:
		return -1
	return maxi(Rules.BODY_HP_MIN, force[i] * Rules.HP_PER_FORCE)


## Damage one body. Returns true when it **died and its row is GONE** — the caller must stop touching `i`.
##
## Everything a dying clone loses is lost by `remove_at()` swapping the last row over it: cargo, force and
## the worn part go structurally, with no code that has to remember to drop them. That is the whole reason
## the swarm is flat, and it is why this function is four lines.
##
## ⚠ **Index 0 is refused.** The host's health is `World.host_hp`; a caller that damaged row 0 here would
## write a number nothing reads, and the run would never end.
##
## ⚠ **`maxi(0, amount)` is not defensive tidying.** Negative force is reachable — the corpse part roll
## subtracts a bigger part's force from a body that has since been halved — and negative damage HEALS.
##
## `from_dir` (not `hit_dir`, which would shadow the column of the same name) is defaulted for the same
## reason `World._damage_critter`'s third parameter is: most callers have no direction to give.
func damage(i: int, amount: int, from_dir: Vector2 = Vector2.ZERO) -> bool:
	if i <= 0 or i >= count:
		return false
	var dealt := maxi(0, amount)
	# Written FIRST, exactly like `bite_show`: the hit happened even when it does not kill, so the clock and
	# direction have to be true before `remove_at()` can possibly swap a stranger into this row.
	hit_show[i] = 0.0
	hit_dir[i] = from_dir
	# **The knockback**, through `place()` — never a bare write — so a hit next to a rock stops at its edge
	# rather than teleporting the clone through it. `dealt`, not `amount`: healing must not also shove.
	if dealt > 0 and from_dir.length_squared() > 0.0001:
		pos[i] = place(pos[i] + from_dir * (float(dealt) * Rules.KNOCKBACK_PER_FORCE), Rules.CLONE_BODY_RADIUS)
	hp[i] = maxi(0, hp[i] - dealt)
	if hp[i] > 0:
		return false
	# §B-3: the burst reads `pos`/`carried` HERE — the exact same side of `remove_at()` the cargo-loss
	# bookkeeping above already has to read them on; one line later and this would be reading a survivor's.
	died_this_frame.append({"pos": pos[i], "carried": carried[i]})
	remove_at(i)
	return true


# -- what the actives do to the world ------------------------------

## A front cone toward `aim`. **It always swings**: the cone is shown, the cooldown is paid, and
## `World.fire()` dispatches the damage off it.
##
## ⚠ **Eating a crumb is a SIDE EFFECT of the swing, not its purpose, and this is the change plan 4 cannot
## work without.** Returning false on an empty cone made a click aimed at a creature standing on bare
## ground a dead key — no cooldown, no cone, no damage — because `Body.fire()` stops on the refusal and
## never reaches the strike. Three checks that read `not fire(...)` as "the reach is 70px" now read the
## food surviving instead; the reach is still what they measure.
##
## ⚠ **The range and the arc are ARGUMENTS, not `Rules` constants.** They come off the firing part's row
## (`Parts.RANGE` / `Parts.ARC`), which is what lets a second ARC part exist as a row rather than as a
## branch here. This function does not know which part called it and does not need to.
##
## ⚠ **It does not touch a cooldown.** `Body.fire()` owns that, so the cooldown that refuses the second
## click and the cooldown that ticks down are the same number.
func bite(range_px: float, arc: float, aim: Vector2) -> bool:
	var origin := pos[0]
	var dir := aim - origin
	dir = host_facing if dir.length_squared() < 0.0001 else dir.normalized()
	# Written FIRST and unconditionally: the swing happened, so the cone the view draws is the cone the sim
	# tested — including its size, pinned here rather than re-derived in the view from a part id it would
	# have to be told separately.
	bite_show = 0.0
	bite_aim = dir
	bite_range = range_px
	bite_arc = arc
	if _food != null:
		var half_arc := arc * 0.5
		var ids := food_grid.neighbours(origin, range_px, Rules.SENSE_CAP)
		var best := -1
		var best_d := INF
		for id in ids:
			var j := id >> 1
			if j < 0 or j >= _food.alive.size() or _food.alive[j] == 0:
				continue
			var to: Vector2 = _food.pos[j] - origin
			var d := to.length()
			if d > range_px or d >= best_d:
				continue
			# The angle is the skill. Range alone and the cone is a circle with a picture drawn on it.
			if d > 0.0001 and absf(dir.angle_to(to)) > half_arc:
				continue
			best_d = d
			best = j
		if best >= 0 and _food.consume(best):
			eat(0, 1.0)
	return true


## **The frame boundary, and it is NOT the top of `step()`.** The three lists above are read by `view`
## AFTER `step()` and written from two places: inside `step()`, and by the shell's input phase, which runs
## BEFORE it. A clear at `step()`'s top therefore erases every event a KEY produced on the frame it was
## pressed — measured on `split_this_frame`, where `F` drew no ring at all in the real game. So the clear
## sits at the one instant that is after `view`'s read and before either writer: the start of the shell's
## frame. `World.begin_frame()` forwards here; `view` still never writes `sim` (§0-2).
func begin_frame() -> void:
	died_this_frame.clear()
	food_eaten_this_frame.clear()
	split_this_frame.clear()


## One frame. `food` may be null — a net that only measures steering passes nothing and pays for nothing.
##
## Order is load-bearing and is itself measurable: move, then separate, then eat, then — during the great
## absorption only — take whatever arrived at the host. Nothing happens on ordinary contact. Separating
## before moving lets two clones end the frame on top of each other, which is the one thing separation
## exists to prevent.
func step(dt: float, food: Food = null) -> void:
	_food = food
	# Cooldowns and breath are `Body.step()`'s, and `World.step()` calls it just before this one.
	bite_show += dt
	# The contact-attack clock, ticked here for the same reason `bite_show` is: the sim owns every clock a
	# body has. Row 0 rides along harmlessly — the host attacks through a key, not by touching.
	for i in count:
		if atk_cd[i] > 0.0:
			atk_cd[i] = maxf(0.0, atk_cd[i] - dt)
		# Counted UP, both of them — `INF + dt == INF` needs no guard, the same property `bite_show` relies on.
		hit_show[i] += dt
		swing_show[i] += dt
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
	var dir := host_input
	if dir.length_squared() > 0.0001:
		host_facing = dir.normalized()
	# A sustained active multiplies the walk; a burst REPLACES it and locks the facing. They cannot both
	# apply — the burst is already relative to `HOST_SPEED`, so multiplying it again would make a gallop
	# into a dash into a gallop-dash, a stacking rule nobody chose.
	var speed := Rules.HOST_SPEED * active_speed_mul
	if dash_left > 0.0:
		dash_left -= dt
		dir = host_facing
		speed = dash_speed
	# ⚠ **After the dash branch, never before it.** The burst REPLACES `speed`, so a multiply above would be
	# thrown away and a dash would cross water at full speed — water stops being a wall exactly when the
	# player most wants it to be one.
	if terrain != null:
		speed *= terrain.speed_mul(pos[0])
	vel[0] = dir.limit_length(1.0) * speed
	pos[0] = place(pos[0] + vel[0] * dt, Rules.BODY_RADIUS)


func _move_clone(i: int, dt: float, food: Food) -> void:
	var p := pos[i]
	# STRIKE walks at the FOLLOW speed: it is the swarm being sent somewhere on purpose, not wandering.
	var speed := Rules.CLONE_SPEED_SCATTER if state[i] == SCATTER else Rules.CLONE_SPEED_FOLLOW
	if clear_pull:
		speed = Rules.CLEAR_ABSORB_PULL
	# The end of the speed selection, so nothing below can overwrite it. Same rule as the host's.
	if terrain != null:
		speed *= terrain.speed_mul(p)
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
	pos[i] = place(p + vel[i] * dt, Rules.CLONE_BODY_RADIUS)


## Position correction, not a force. Separation is a rendering requirement — sixty bodies on one point
## read as one dot — and a force takes many frames to resolve a full overlap, which is exactly the state a
## rendezvous produces. Each of the pair moves half the overlap, so one step is enough.
##
## Neighbour candidates come from the grid built at the START of the frame, before movement. A clone moves
## at most ~5.7px in a frame against a 32px cell, so the candidate set is the same set; reading current
## positions for the distances keeps the correction exact.
##
## ⚠ **Two pairs, two rules.** Clone↔clone is symmetric and each takes half. **Clone↔host is ONE-WAY: the
## clone takes the whole overlap and `pos[0]` is never written here.** The player is not shoved by their own
## swarm — a host ringed by forty bodies that could each push it would stop standing where the stick says.
## See 「근접전이 안 읽힌다」's A-2 for why the host had no separation at all until now.
func _separate(i: int) -> void:
	# The one-way rule made structural rather than left to the caller's `range(1, count)`. Called with 0 this
	# would otherwise compute `pos[0] - pos[0]`, take the coincident branch, and walk the host off its own
	# coordinate — the exact thing the pair table forbids, reachable by widening one loop bound.
	if i <= 0 or i >= count:
		return
	var ids := clone_grid.neighbours(pos[i], Rules.SEPARATION_MIN, Rules.NEIGHBOUR_CAP)
	for id in ids:
		# **Row 0 is still skipped here and it is not an omission** — the host is in `clone_grid`, but its
		# distance is not `SEPARATION_MIN` and the query above was not asked for its radius. It gets its own
		# block below, at its own distance, with no grid in between.
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
		# ⚠ **Both writes go through `place()`, not the bare field clamp.** Separation runs AFTER movement,
		# so it is free to shove a body straight back into a rock that `push_out` had already cleared this
		# frame — and nothing runs after it to undo that.
		pos[i] = place(pos[i] + half, Rules.CLONE_BODY_RADIUS)
		pos[j] = place(pos[j] - half, Rules.CLONE_BODY_RADIUS)
	_separate_from_host(i)


## The clone↔host half, and it moves the CLONE only. **Derived from the two radii, never a new constant**:
## `SEPARATION_MIN` is already `2 × CLONE_BODY_RADIUS`, so "edge to edge, touching" for a clone against the
## host is `BODY_RADIUS + CLONE_BODY_RADIUS`. A body separated to `SEPARATION_MIN` from the host would still
## stand 6px inside its drawn radius, which is the picture the user was looking at when they said bodies
## stand inside each other.
##
## **Last, after the clone↔clone loop**, so the correction that cannot be undone by moving the other body is
## the last one this body receives in its own call. Run first, the symmetric loop is free to push a clone
## straight back onto the host with nothing behind it.
##
## The coincident branch is not hypothetical: `1` steers every clone at the host and the arena summon
## teleports up to forty onto it, both of which produce an exactly-zero offset. The angle is deterministic
## from the index and `l` goes to **0.0** — see the clone↔clone branch above for the ~80,000px throw an
## epsilon divisor bought there.
##
## ⚠ **The coincident branch fires on a LONE clone, not on the pile** — measured: in a pile the loop above
## has already moved the body off the host by the time this runs, so `l` is non-zero and the ordinary branch
## takes it. A check that drives forty coincident bodies is therefore not checking it; `net_grid` drives one.
##
## **No margin here, unlike the body↔creature pair.** `Rules.SEPARATION_CONTACT_MARGIN` exists to keep a
## body inside `World._contact()`'s bands, and nothing about the host is a band: the host does not attack by
## touching and its own swarm never attacks it.
func _separate_from_host(i: int) -> void:
	# `pos[0]` is never handed in as the row to move, only as the point to move away from — that one
	# asymmetry is the whole of "the host is never moved by its own swarm".
	push_out_of(i, pos[0], Rules.BODY_RADIUS + Rules.CLONE_BODY_RADIUS)


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
	# §F-7: recorded BEFORE `eat()` moves anything, at the food's own fixed spot and this body's own current
	# position — `view` draws a dot travelling from one to the other, reusing the burst list's timer shape.
	food_eaten_this_frame.append({"pos": food.pos[target], "to": pos[i]})
	if i == 0:
		# The host banks instantly. A clone's mouthful is at risk until it walks home — that difference IS
		# the tax the GDD wanted, expressed as a speed, with no constant to tune and nothing to explain.
		eat(0, 1.0)
		# Bare constants. The `host_eat_mul` / `clone_eat_mul` that used to scale these were level-up
		# cards, and cards give parts now — no August part fills the GUT slot, so nothing replaces the
		# factor and eating speed is fixed for this plan.
		eat_cd[0] = Rules.EAT_PERIOD_HOST
	else:
		eat(i, 1.0)
		eat_cd[i] = Rules.EAT_PERIOD_CLONE
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
	# Bare `SENSE_RADIUS` — `sense_mul` went with the cards. The EYES slot is what tunes this from now on
	# and no August part fills it, so a clone's intelligence is fixed for this plan.
	var ids := food_grid.neighbours(p, Rules.SENSE_RADIUS, Rules.SENSE_CAP)
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
