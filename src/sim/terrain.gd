class_name Terrain
extends RefCounted
## Rocks, water, and the arena — everything about the field that a body can be pushed by.
##
## **A tiny RefCounted, not part of `World`**, and that is the whole design: `Swarm` has to read it every
## frame to finalise a position, and `Swarm` may not read `World`. A back-reference the other way is the
## circular dependency that would make every `Swarm` net construct a `World` first. `World` owns the one
## instance and hands it to `Swarm` in `setup()`.
##
## Nothing here touches the tree. Every predicate is `distance < radius`, which is also why the view draws
## rocks and water as filled circles rather than through the cell blob — a rounded square's corners stick
## out past the circle this file collides against, and screen and sim disagreeing is the signature fake.

var rock_pos := PackedVector2Array()
var rock_radius := PackedFloat32Array()
var water_pos := PackedVector2Array()
var water_radius := PackedFloat32Array()

## The arena. Zero radius means open; it closes once and never re-opens, which is why there is no
## `open_arena()` to call by mistake.
var arena_centre := Vector2.ZERO
var arena_radius := 0.0
var arena_closed := false


## ⚠ **Takes `World`'s own `_rng`** — a second generator makes the run stop being one seed.
##
## ⚠ **And therefore every attempt draws the SAME number of randoms whether it is accepted or not.** The
## point and the radius are both drawn at the top of the loop body, unconditionally, before anything is
## tested. Drawing the radius only after the point passes makes the draw count depend on how many samples
## were rejected, every downstream draw in `World.setup()` shifts with it, and two builds from one seed
## produce different worlds — a divergence the round's fingerprint cannot tell apart from a real change.
##
## ⚠ **Rejection SKIPS.** After `Rules.PLACE_TRIES` failures the rock is not placed at all; it never falls
## through to a bad point. So `rock_pos.size()` is `<= Rules.ROCK_COUNT` and seed-dependent, and nothing
## may read it as if it were the constant. `net_terrain`'s floor check is what stops the two rock checks
## passing vacuously on an empty array.
func setup(field: Vector2, host_start: Vector2, rng: RandomNumberGenerator) -> void:
	rock_pos.clear()
	rock_radius.clear()
	water_pos.clear()
	water_radius.clear()
	for _n in Rules.ROCK_COUNT:
		for _try in Rules.PLACE_TRIES:
			var p := Vector2(rng.randf() * field.x, rng.randf() * field.y)
			var r := rng.randf_range(Rules.ROCK_RADIUS_MIN, Rules.ROCK_RADIUS_MAX)
			if p.distance_to(host_start) < Rules.ROCK_CLEAR_DIST + r:
				continue
			if _overlaps_rock(p, r):
				continue
			rock_pos.append(p)
			rock_radius.append(r)
			break
	for _n in Rules.WATER_COUNT:
		for _try in Rules.PLACE_TRIES:
			var p := Vector2(rng.randf() * field.x, rng.randf() * field.y)
			var r := rng.randf_range(Rules.WATER_RADIUS_MIN, Rules.WATER_RADIUS_MAX)
			# Water is a floor, not a wall: it may sit on a rock, and only the host's opening ground is
			# cleared of it. Rejecting it against rocks as well would thin twelve circles to a handful on
			# a field this crowded, for a rule nothing in the design asks for.
			if p.distance_to(host_start) < Rules.ROCK_CLEAR_DIST + r:
				continue
			water_pos.append(p)
			water_radius.append(r)
			break


func _overlaps_rock(p: Vector2, r: float) -> bool:
	for j in rock_pos.size():
		if p.distance_to(rock_pos[j]) < rock_radius[j] + r:
			return true
	return false


## How far inside a rock a body may end up and still count as out of it. **A tolerance, not a tuning
## value**: `_push_off` lands a body on `reach` exactly, and a `Vector2` is 32-bit, so a coordinate near
## 2000 comes back a few thousandths off. Compared against zero, `push_out` would chase that dust forever.
const TOUCH_EPS := 0.01


## Move `p` out of every rock it overlaps, to exactly touching. **The contract is the returned point, not
## the work spent getting there: what comes back is not inside a rock.**
##
## ⚠ **Pushing rock by rock cannot hold that, and no pass count fixes it.** A body on the axis between two
## rocks whose seam is narrower than its own diameter is a FIXED POINT — each rock shoves it back into the
## other, and there is no point on that axis outside both. Measured: a `BODY_RADIUS` 14 body between two
## r-100 rocks 10px apart settles 96px from a centre that wants 114, and stays there for the rest of the
## run. This function used to be two sequential passes and a comment blaming the pass count; the diagnosis
## was wrong. **There is now no pass count at all** — the walls are solved together, in one shot, and there
## is nothing left for a loop bound to be right or wrong about.
##
## ⚠ **Rejecting tight seams in `setup()` is not the fix either, and it was worked out before being
## dropped.** A clearance of `2 * Rules.BODY_RADIUS` leaves a 28px seam, which the host fits and a
## **creature** does not — every creature runs through this same function, a maxed crow at 18 and the boss
## at up to 72 — and a clearance sized for the boss thins forty rocks to a handful and shifts the whole
## seed stream with it.
##
## **How it is solved.** Nearest-point-outside-a-union-of-circles has a finite candidate set, and this
## builds all of it for the rocks actually in the way: for each rock the body is inside, the straight push
## off it, plus every crossing of its inflated circle with another rock's. **A crossing is the corner of a
## seam** — the sideways way out of a gap the body cannot fit down, which is the one direction a
## rock-by-rock push can never find. The nearest candidate clear of EVERY rock wins.
##
## ⚠ **Pairing only the two deepest rocks is not enough, and that was measured, not reasoned**: squeezing
## every narrow seam of five generated fields left a body **31.9px** inside a rock, because the crossing
## that answers two walls can sit inside a third. Testing each candidate against the whole array closes it.
##
## When nothing is clear the body is enclosed, no position near it is legal, and the least-buried candidate
## is returned — the next frame's call works from there. A retry loop around this was written, measured and
## deleted: **no configuration in five generated fields needed a second round**, so its bound was a number
## no check could ever bite.
func push_out(p: Vector2, r: float) -> Vector2:
	var inside := PackedInt32Array()
	for j in rock_pos.size():
		if rock_radius[j] + r - p.distance_to(rock_pos[j]) > TOUCH_EPS:
			inside.append(j)
	# The common case and the cheap one: most bodies on most frames touch no rock at all and pay one scan.
	if inside.is_empty():
		return p

	var cands := PackedVector2Array()
	for a in inside:
		# Straight out of `a`. With one rock in the way this IS the answer, so an ordinary walk into a rock
		# can never be turned into a sideways jump by coming through here.
		cands.append(_push_off(p, r, a))
		for b in rock_pos.size():
			if b != a:
				_append_crossings(cands, a, b, r)

	var best := p
	var best_d := INF
	var least := p
	var least_pen := INF
	for q in cands:
		var pen := _deepest_penetration(q, r)
		var d := p.distance_squared_to(q)
		if pen <= TOUCH_EPS:
			# Strictly nearer, never "as near as". ⚠ **The reason is not the one this comment used to give.**
			# It said `<` is what stops a body on the axis of a symmetric seam flickering between two equally
			# near corners — measured, and false: the candidate list is `[push_off(a), crossings(a, b),
			# push_off(b), crossings(b, a)]`, and `_append_crossings` walks the same two points back the other
			# way for `(b, a)`, so **the tied pair is a palindrome** and the first equidistant candidate is
			# also the last. `<=` returns the identical point on that fixture (`net_terrain._t8(a)` pins the
			# coordinate). What keeps the seam still is that the candidate ORDER is fixed, not this operator.
			# `<` is kept because "the nearest" is the rule the function means, and because a tie broken by
			# whatever came last is a rule nobody can predict the day a third rock joins the list.
			if d < best_d:
				best_d = d
				best = q
		elif pen < least_pen:
			least_pen = pen
			least = q
	if best_d < INF:
		return best
	return least


## Onto rock `j`'s surface, exactly touching.
func _push_off(p: Vector2, r: float, j: int) -> Vector2:
	var reach := rock_radius[j] + r
	var away := p - rock_pos[j]
	var d := away.length()
	if d < 0.0001:
		# Exactly on the centre. A fixed direction, never a normalised zero vector: dividing by a zero
		# length here is a NaN position that spreads to the grid and to every distance test that touches
		# this body for the rest of the run.
		return rock_pos[j] + Vector2.RIGHT * reach
	return rock_pos[j] + away / d * reach


## The deepest any rock reaches into a body standing at `p` — negative when it is outside every one of
## them. **This is the predicate the contract is written in**, so `push_out` answers "am I done" by
## measuring rather than by counting how much work it has done.
func _deepest_penetration(p: Vector2, r: float) -> float:
	var worst := -INF
	for j in rock_pos.size():
		worst = maxf(worst, rock_radius[j] + r - p.distance_to(rock_pos[j]))
	return worst


## The two points where rock `a`'s inflated circle meets rock `b`'s, appended in a fixed order. Nothing is
## appended when they do not meet: concentric, too far apart, or one swallowing the other.
func _append_crossings(out: PackedVector2Array, a: int, b: int, r: float) -> void:
	var ca := rock_pos[a]
	var cb := rock_pos[b]
	var ra := rock_radius[a] + r
	var rb := rock_radius[b] + r
	var ab := cb - ca
	var d := ab.length()
	if d < 0.0001 or d > ra + rb or d < absf(ra - rb):
		return
	var along := (ra * ra - rb * rb + d * d) / (2.0 * d)
	var h_sq := ra * ra - along * along
	if h_sq <= 0.0:
		return
	var dir := ab / d
	var base := ca + dir * along
	var perp := Vector2(-dir.y, dir.x) * sqrt(h_sq)
	out.append(base + perp)
	out.append(base - perp)


## ⚠ **Creatures pay this too, not only bodies.** Water that slowed the swarm alone would be a stealth
## field; slowing everything is what makes it the third wall the horse can be herded against.
func speed_mul(p: Vector2) -> float:
	for j in water_pos.size():
		if p.distance_to(water_pos[j]) < water_radius[j]:
			return Rules.WATER_SLOW
	return 1.0


## Read by the creature sense loop only. It is a **different** effect from the slow, and a check that keeps
## one while deleting the other has to exist for each.
func hidden(p: Vector2) -> bool:
	for j in water_pos.size():
		if p.distance_to(water_pos[j]) < water_radius[j]:
			return true
	return false


## The early return IS "it never re-opens". Without it a boss that wanders back out and in again would
## re-centre the arena on wherever it happened to be standing.
func close_arena(centre: Vector2) -> void:
	if arena_closed:
		return
	arena_centre = centre
	arena_radius = Rules.ARENA_RADIUS
	arena_closed = true


## Identity while the arena is open, so every caller can run it unconditionally.
func clamp_to_arena(p: Vector2, r: float) -> Vector2:
	if not arena_closed:
		return p
	return arena_centre + (p - arena_centre).limit_length(maxf(0.0, arena_radius - r))
