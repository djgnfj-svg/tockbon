class_name FieldView
extends Node2D
## Draws the world. Reads `world`, never writes it.
##
## **Everything is drawn from one `_draw()` on one node**, not from sixty nodes and not from a MultiMesh.
## MultiMesh is disqualified twice over: its per-instance state is invisible headless in 4.7.1 (transforms
## read back as identity, colours as black, `multimesh_get_buffer()` size 0, **and no error is raised**),
## and the full game needs clones that do not look alike.
##
## `_draw()` does nothing except call `_paint()`, and `_paint()` does nothing except call a `_paint_*`
## leaf — a cell per body, a disc per rock, a label per cluster, an arc, a cone. **Every pixel goes through
## one of them, and that is not decoration — it is the only way a net can assert what was drawn.** Counting
## that `_draw()` ran measures the engine; `CLAUDE.md` records three features shipped that way in one day,
## each erasable with thousands of checks still green. A native call like `draw_circle` cannot be
## overridden (parse error), so the hook has to be a method of ours that takes the values as arguments.

## Tessellation, not appearance — the same class of number as `_blob()`'s eight points, and it stays here
## with them rather than in `look.gd`, which holds what a thing looks like and not how finely it is cut.
const RING_SEGMENTS := 28
const RING_WIDTH := 2.0
const CONE_SEGMENTS := 12
## Limb pairs and eye dots are drawn once per side. **Only one side's offset is written in `look.gd`** —
## the sign is derived, so a pair cannot be tuned into asymmetry by editing one of two constants.
const MIRROR := [1.0, -1.0]

## How `_body_order()` packs one body into one sortable int: `(depth << 10) | (kind << 8) | index`.
## **Bit layout, not appearance** — the same class of number as `RING_SEGMENTS` above, and it stays here
## with it rather than in `look.gd`, which holds what a thing looks like. Nothing here changes a picture;
## changing any of it changes which body ends up on top, which is why the net drives the extremes.
##
## `DEPTH_MIN`/`DEPTH_MAX` bracket `Rules.FIELD`'s y (0…2160) with room on both sides for a body that has
## walked off it, and the biased depth then spans 0…5120 — 13 bits, so the whole key stays well inside 32.
const KIND_CLONE := 0
const KIND_CRITTER := 1
const KIND_HOST := 2
const KIND_SHIFT := 8
const KIND_MASK := 3
const IDX_MASK := 255
const DEPTH_SHIFT := 10
const DEPTH_MIN := -1024.0
const DEPTH_MAX := 4096.0

## Which colour goes with which species, in `Parts.Species`' own order. **A presentation LOOKUP, not a
## presentation constant**: the three colours themselves live in `look.gd` and this table only says which
## one a species gets, so the one-file rule is not broken by it.
##
## ⚠ **`Hud` reads this table too, for the minimap's marks.** One table with two readers, deliberately: a
## second copy in the HUD is the divergence the one-file rule exists to stop, and a minimap drawing a horse
## in the crow's colour is a picture nobody would ever check.
## ⚠ **A species in the enum and in `rules.gd` but missing from here is an index-out-of-range at DRAW time**
## — in `_creature()` and in `Hud._minimap_marks()` — and for two plans nothing anywhere asserted this
## table's length. `net_field._c31_every_species_table_is_eleven_rows` now pins it beside the eleven in
## `rules.gd`, so a row added there and forgotten here is a red round rather than a crash in play.
const SPECIES_COLOR := [Look.CROW_COLOR, Look.HORSE_COLOR, Look.BOSS_COLOR,
	Look.SQUIRREL_COLOR, Look.ELEPHANT_COLOR, Look.CHEETAH_COLOR, Look.LION_COLOR,
	Look.MOUSE_COLOR, Look.RABBIT_COLOR, Look.DOG_COLOR, Look.BOAR_COLOR]

var world: World = null
## What the camera can see, in world coordinates, padded. Everything outside is skipped — 500 food spots
## over nine screens is mostly off-camera at any moment.
var view_rect := Rect2(Vector2.ZERO, Rules.FIELD)

var _last_banked := 0.0
## Decays to zero; scales the host while it does. The harvest has to be visible without reading a number.
var _absorb_pop := 0.0

## §E's summon rings, a clone's own death burst (§B-3), a monster's (§B-4), `F`'s own split ring (§F-10) and
## the food-eaten pop (§F-7), all in one list. **The view's own array** — the one sanctioned exception to
## §0-2 beyond `_absorb_pop`, because a burst has to keep drawing after the body it marks is gone from `sim`
## entirely. Every entry carries `{"pos": Vector2, "r0": float, "col": Color, "t": float}`; `_process`
## advances `t` and drops an entry once it reaches its own duration. Two keys are OPTIONAL and only the
## food pop writes them: `"to": Vector2` (the point the dot travels TOWARD) and `"dur": float` (its own
## duration, since 0.15s runs many times faster than `Look.BURST_TIME`'s shared 0.4s) — their absence is
## what tells `_paint` a ring rather than a travelling dot, see the branch there.
var _deaths: Array[Dictionary] = []
## Whether `Terrain.arena_closed` was already true the LAST time `_process` looked. `Terrain` never clears
## the flag once it flips, so this is what lets the view see the single frame it flips on — the same shape
## `_last_banked` already uses to catch `banked` moving, and for the identical reason: `sim` holds no
## one-shot "the view has already reacted to this" bit of its own.
var _arena_was_closed := false


## **Called by the shell every time a `World` is bound**, and the node outlives every run — `main.gd`
## builds one `FieldView` in `_ready()` and only re-points `world`. `_last_banked` is a high-water mark of
## the bank; carried into the next run it sits far above a fresh `banked` of 0, `banked > _last_banked` is
## false for the whole of run two, and the host stops scaling on eating. Nothing errors and the HUD bar
## still moves, so the screen does not even look dead — it just quietly stops rewarding every run after
## the first.
func reset_pop() -> void:
	_last_banked = 0.0
	_absorb_pop = 0.0
	_arena_was_closed = false
	_deaths.clear()


func _process(delta: float) -> void:
	if world == null:
		return
	if world.swarm.banked > _last_banked:
		_absorb_pop = minf(1.0, _absorb_pop + (world.swarm.banked - _last_banked) * 0.12)
		_last_banked = world.swarm.banked
	_absorb_pop = maxf(0.0, _absorb_pop - delta * 2.2)
	# §E's summon: the arena closes exactly once, `Terrain.arena_closed` never clears, so the edge itself —
	# not the level — is what says "teleport them now". Caught the same frame `World.step()` moved the swarm,
	# since `main.gd`'s own `_process` runs `run.step()` before its children's `_process` this same frame.
	var arena_closed: bool = world.terrain.arena_closed
	if arena_closed and not _arena_was_closed:
		for i in range(1, world.swarm.count):
			_deaths.append({"pos": world.swarm.pos[i], "r0": Look.ARENA_SUMMON_R0,
					"col": Look.ARENA_WALL_COLOR, "t": 0.0})
	_arena_was_closed = arena_closed
	# §B-3: a clone's own death burst. `sim` fills `died_this_frame` and clears it at the top of its NEXT
	# `step()` — this is a READ, never a clear; `view` may not write `sim` (§0-2). Colour and size both read
	# `carried` at the moment of death, the same lerp the live clone loop below computes from it.
	for d: Dictionary in world.swarm.died_this_frame:
		var carried_v: float = float(d["carried"])
		var load_t := clampf(carried_v / Look.CLONE_LOAD_FULL, 0.0, 1.0)
		_deaths.append({"pos": d["pos"],
				"r0": Look.CLONE_DEATH_R_BASE + carried_v * Look.CLONE_DEATH_R_PER_LOAD,
				"col": Look.CLONE_COLOR.lerp(Look.CLONE_LOADED_COLOR, load_t), "t": 0.0})
	# §B-4: a monster's own death burst, in its species colour at its own (pre-death) radius.
	for d: Dictionary in world.critters_died_this_frame:
		_deaths.append({"pos": d["pos"], "r0": float(d["r"]) * Look.MONSTER_DEATH_R_MUL,
				"col": SPECIES_COLOR[int(d["species"])], "t": 0.0})
	# §F-7: a dot sucked toward whichever body ate it. **Reuses this list's timer, not its duration or its
	# ring shape** — 0.15s runs many times faster than `Look.BURST_TIME`'s shared 0.4s, and a moving point is
	# not a growing circle, so `"to"` and `"dur"` ride along and the branch in `_paint` reads them.
	for d: Dictionary in world.swarm.food_eaten_this_frame:
		_deaths.append({"pos": d["pos"], "to": d["to"], "r0": Look.FOOD_POP_R, "col": Look.FOOD_COLOR,
				"t": 0.0, "dur": Look.FOOD_POP_TIME})
	# §F-10: `F`'s own burst, at the point the split happened. The plain ring shape, so it needs neither key.
	for d: Dictionary in world.swarm.split_this_frame:
		_deaths.append({"pos": d["pos"], "r0": Look.SPLIT_POP_R0, "col": Look.SPLIT_CHARGE_COLOR, "t": 0.0})
	# Every burst grows and fades over its OWN duration (`Look.BURST_TIME` unless the entry names its own,
	# `"dur"`); one that has run its course is dropped HERE rather than in `_paint`, so a run that never
	# stops does not pile up an ever-growing list of fully-faded circles nobody draws.
	var alive: Array[Dictionary] = []
	for d: Dictionary in _deaths:
		d["t"] = float(d["t"]) + delta
		if float(d["t"]) < float(d.get("dur", Look.BURST_TIME)):
			alive.append(d)
	_deaths = alive
	queue_redraw()


func _draw() -> void:
	_paint(self)


func _paint(c: CanvasItem) -> void:
	if world == null:
		return
	# **The ground first, and through `_paint_disc` rather than `_paint_cell`.** All three of `Terrain`'s
	# predicates are `distance < radius`, so rock and water are CIRCLES in the sim; `_paint_cell` draws a
	# rounded square whose corners stick ~26px past a 90px rock's collision circle, and you would walk
	# through visible rock. Water goes down first because it is a floor and rock is a wall on it.
	#
	# ⚠ **Not culled against `view_rect`, and that is deliberate.** A body is culled on its centre, which is
	# right for a 14px body and wrong for a 180px water circle: the centre leaves the padded rect while
	# most of the disc is still on camera, and the floor would pop out from under the host. Fifty-two
	# circles is not a budget worth a bug.
	var ground := world.terrain
	for j in ground.water_pos.size():
		_paint_disc(c, ground.water_pos[j], ground.water_radius[j], Look.WATER_COLOR)
	for j in ground.rock_pos.size():
		_paint_disc(c, ground.rock_pos[j], ground.rock_radius[j], Look.ROCK_COLOR)

	# §E: the arena. **After water and rocks, before corpses** — floor above, bodies below (plan 4 built it
	# and drew nothing at all; `arena` was zero hits across `view`, `shell` and `look.gd`). `arena_radius` is
	# `0.0` until `Terrain.close_arena()` sets it to `Rules.ARENA_RADIUS` in one call — there is no gradual
	# close for a ring to interpolate through (`net_run`'s own check 15 drives that single frame) — so this
	# reads it LIVE and unconditionally: nothing draws before the boss arrives, and the wall appears the one
	# frame it does and stays every frame after, with no separate "is it closing" flag to keep in step.
	# ⚠ **`_paint_arc` directly, NOT `_paint_ring`.** `_paint_ring` is the two-circle MARKER shape (`r` and
	# `r × 0.45`) the strike point and every burst want; on a 900px arena that second circle is a 405px ring
	# in the wall's own colour and width, straight through the middle of the fight, reading as a second wall.
	# `_paint_arc` is already a leaf with its own row in `net_draw_leaf`'s table, so this costs no new one.
	if ground.arena_radius > 0.0:
		_paint_arc(c, ground.arena_centre, ground.arena_radius, 0.0, TAU, Look.ARENA_WALL_COLOR,
				Look.ARENA_WALL_WIDTH)

	# A corpse is the ground too — drawn under every body, so a swarm standing on one still reads as bodies.
	# The ring is the SWARM eating, in the host's own yellow, and it is the only thing on screen that says a
	# six-second boss meal is running at all.
	for i in world.corpse_count:
		var cp := world.corpse_pos[i]
		if not view_rect.has_point(cp):
			continue
		var cr := world.corpse_radius(i)
		# The DRAWN body shrinks with bites eaten; `cr` itself stays whole for the ring below and for
		# `corpse_reach()`, which reads the same `corpse_radius()` — only the cell's own radius shrinks.
		# `corpse_bites_total()` is floored at `Rules.CORPSE_BITES_MIN` (3), never 0 — the divide is safe.
		var shrink := Look.CORPSE_SHRINK_BASE + Look.CORPSE_SHRINK_RANGE * \
				(float(world.corpse_bites_left[i]) / float(world.corpse_bites_total(i)))
		_paint_cell(c, cp, cr * shrink, Look.CORPSE_COLOR, Vector2.ONE)
		var done := world.corpse_progress[i]
		# ⚠ **`shrink` is on the ring too.** The ring is drawn AROUND the corpse, so it has to shrink with the
		# drawn body — at the last bite the body is `0.45 × cr` and an unshrunk ring at `1.5 × cr` is a hoop
		# 3.3× the corpse's diameter floating in empty grass. What must NOT shrink is `cr` itself: it is the
		# same `corpse_radius()` `corpse_reach()` reads, and moving it moves where the swarm can eat from.
		if done > 0.0:
			_paint_arc(c, cp, cr * shrink * Look.CORPSE_PROGRESS_RING, -PI * 0.5, -PI * 0.5 + TAU * done,
					Look.CORPSE_PROGRESS_COLOR, Look.CORPSE_PROGRESS_WIDTH)

	var food := world.food
	for i in food.pos.size():
		if food.alive[i] == 0:
			continue
		var p := food.pos[i]
		if not view_rect.has_point(p):
			continue
		_paint_cell(c, p, Look.FOOD_RADIUS, Look.FOOD_COLOR, Vector2.ONE)

	var sw := world.swarm
	# §A-3's host mark, and it is the LAST thing in the floor layer — after the food, before the `3` marker —
	# so no body is ever drawn under it and it cannot read as something the swarm is doing. Gated on the
	# candidate and on nothing else: permanent is the whole of what it is for. See `Look.HOST_MARK_RING`.
	if _rimmed():
		_paint_arc(c, sw.pos[0], Rules.BODY_RADIUS * Look.HOST_MARK_RING, 0.0, TAU,
				Look.HOST_MARK_COLOR, Look.HOST_MARK_WIDTH)

	# The marker for `3`, drawn only while somebody is actually on their way there. The guard used to be
	# `rally != pos[0]`, and rally is the host now — that condition would be false forever and the ring
	# would have disappeared with every net still green.
	if _striking(sw):
		_paint_ring(c, sw.strike_point, Look.STRIKE_RADIUS, Look.STRIKE_COLOR)

	_paint_bodies(c)

	# §A-1: sorted, the host's slot can be covered by any creature south of it — and the bite cone is the one
	# melee mark the user has already accepted, so 갈래 ㄴ lifts it out of that slot and draws it over every
	# body instead. Under the other two candidates the pass is in a fixed order and `_paint_host` draws it
	# exactly where it has been since plan 2. **One shape and one guard, both in `_paint_bite_cone`**; the two
	# call sites are mutually exclusive, which is what stops a frame drawing two cones or none.
	if _rimmed():
		_paint_bite_cone(c)

	# The `F` wind-up, over the host. 0.45 seconds with nothing on screen is a key that reads as broken,
	# and the arc is the only feedback the hold has. Starts at the top and sweeps clockwise.
	if sw.split_charge > 0.0:
		var t := clampf(sw.split_charge / Rules.SPLIT_HOLD_TIME, 0.0, 1.0)
		_paint_arc(c, sw.pos[0], Rules.BODY_RADIUS * Look.SPLIT_CHARGE_RING,
				-PI * 0.5, -PI * 0.5 + TAU * t, Look.SPLIT_CHARGE_COLOR, Look.SPLIT_CHARGE_WIDTH)

	# The view's own `_deaths` list: summon rings, a clone's or a monster's death burst, `F`'s own split ring,
	# and the food-eaten pop. **Over every body, and that is the whole point of where it sits.** Drawn under
	# them — where this block used to be, up with the floor — a clone dying inside the swarm bursts at 10px
	# beneath forty 8px bodies and cannot be seen at all, which is exactly the picture plan 2's unanswered
	# "does losing a fat clone hurt" is waiting on. A burst marks a body that is GONE; nothing can occlude it.
	#
	# **A food entry carries `"to"` and nothing else does** — that presence is the whole of the branch, rather
	# than a separate tag duplicating it.
	for d: Dictionary in _deaths:
		var frac := clampf(float(d["t"]) / float(d.get("dur", Look.BURST_TIME)), 0.0, 1.0)
		var col: Color = d["col"]
		col.a *= (1.0 - frac)
		if d.has("to"):
			# §F-7: a shrinking point travelling from the eaten spot to the eater, through `_paint_disc` —
			# the same leaf rocks and ponds already use, so this costs no new leaf either.
			var from_p: Vector2 = d["pos"]
			var to_p: Vector2 = d["to"]
			_paint_disc(c, from_p.lerp(to_p, frac), float(d["r0"]) * (1.0 - frac), col)
		else:
			var burst_r: float = float(d["r0"]) * lerpf(1.0, Look.BURST_GROWTH, frac)
			_paint_ring(c, d["pos"], burst_r, col)

	# **The numbers, last, so nothing is drawn over them.** The comparison the whole stage is about — is
	# that thing bigger than me — happens without moving your eyes to a panel.
	for e: Dictionary in _force_labels():
		_paint_label(c, e["p"], e["text"], Look.FORCE_LABEL_COLOR)


# -- every body on the field, in one ordered pass ---------------------------------------------------------
## Is 갈래 ㄴ what is being drawn. **Three gates ask this and it is one question**: the sorted pass, the dark
## rim and the host's ground ring are the three marks that candidate IS, so a build that answered yes to one
## and no to another would be photographing something nobody proposed. See `melee-legibility-ko`'s 갈래 ㄴ.
func _rimmed() -> bool:
	return Look.BODY_STYLE == Look.BodyStyle.RIM


## Every body on screen, back to front. **The three loops this replaces were not interchangeable** — each
## carried work the others did not (a clone's cargo colour and its swing line, a creature's afterimages and
## its hit spark, the host's two pops and its eleven-argument `_paint_body`) — so they survive whole as
## `_paint_clone` / `_paint_critter` / `_paint_host` and only the ORDER they are called in is new.
func _paint_bodies(c: CanvasItem) -> void:
	for key in _body_order():
		var kind := (key >> KIND_SHIFT) & KIND_MASK
		var idx := key & IDX_MASK
		if kind == KIND_CLONE:
			_paint_clone(c, idx)
		elif kind == KIND_CRITTER:
			_paint_critter(c, idx)
		else:
			_paint_host(c)


## The draw order as sortable integers: `(depth << DEPTH_SHIFT) | (kind << KIND_SHIFT) | index`.
##
## **A `PackedInt32Array` and its NATIVE sort, never `Array.sort_custom`** — a comparator is one GDScript
## call per comparison, several hundred of them a frame at a hundred bodies, and this runs every frame at
## exactly the moment the swarm is largest. Packing the key is what means no callback exists at all.
## ⚠ **Unmeasured**: no timing was taken for it, the shape was only chosen so that a measurement, when it is
## taken, has nothing to blame.
##
## `index` is eight bits, so `Rules.POOL` and `Rules.CRITTER_MAX` both fit — a table grown past 255 rows
## would silently alias two bodies onto one key, which is why the net asserts both against 256 rather than
## trusting this sentence.
##
## Ties fall to `kind`, so at equal y the host draws over a clone. **Outside 갈래 ㄴ the high part IS `kind`**,
## which reproduces the old clones → creatures → host order out of this same array rather than keeping a
## second loop alive beside it that could drift.
func _body_order() -> PackedInt32Array:
	var out := PackedInt32Array()
	var sorted := _rimmed()
	var sw := world.swarm
	# Culled BEFORE the append, exactly where the three loops culled it: the sort must never see an
	# off-camera body. **The host is not culled and never was** — it is the thing the camera follows.
	for i in range(1, sw.count):
		if view_rect.has_point(sw.pos[i]):
			out.append((_depth(sw.pos[i].y, KIND_CLONE, sorted) << DEPTH_SHIFT)
					| (KIND_CLONE << KIND_SHIFT) | i)
	for k in world.critter_count:
		if view_rect.has_point(world.critter_pos[k]):
			out.append((_depth(world.critter_pos[k].y, KIND_CRITTER, sorted) << DEPTH_SHIFT)
					| (KIND_CRITTER << KIND_SHIFT) | k)
	out.append((_depth(sw.pos[0].y, KIND_HOST, sorted) << DEPTH_SHIFT) | (KIND_HOST << KIND_SHIFT))
	out.sort()
	return out


## Where one body sits in the order: its y under 갈래 ㄴ, its kind otherwise. **Clamped, and at both ends** —
## a body north of the field would go negative and wrap down into the kind bits, putting a stray clone on top
## of everything, and a body far south would climb into them from the other side. A floor with no ceiling is
## half-measured, so the net drives one body past each end.
func _depth(y: float, kind: int, sorted: bool) -> int:
	return (int(clampf(y, DEPTH_MIN, DEPTH_MAX)) - int(DEPTH_MIN)) if sorted else kind


## One clone's slot: the block that was the clone loop, moved whole. Not culled here — `_body_order` culled
## it, and culling twice is two rules to keep in step.
func _paint_clone(c: CanvasItem, i: int) -> void:
	var sw := world.swarm
	var p := sw.pos[i]
	var load_t := clampf(sw.carried[i] / Look.CLONE_LOAD_FULL, 0.0, 1.0)
	var r: float = Rules.CLONE_BODY_RADIUS * lerpf(1.0, Look.CLONE_LOAD_GROWTH, load_t)
	var col: Color = Look.CLONE_COLOR.lerp(Look.CLONE_LOADED_COLOR, load_t)
	# §B-3: the same flash a creature gets, mixed toward FROM the clone's own cargo colour — a fat clone
	# does not flash the same tone an empty one does, because `col` already carries `load_t`.
	var clone_hit_t := sw.hit_show[i]
	if clone_hit_t < Look.HIT_FLASH_TIME:
		col = col.lerp(Look.HIT_FLASH_COLOR,
				Look.HIT_FLASH_STRENGTH * (1.0 - clone_hit_t / Look.HIT_FLASH_TIME))
	var squash := _squash(sw.vel[i], Rules.CLONE_SPEED_FOLLOW)
	var rot := _heading(sw.vel[i])
	_paint_hit_bloom(c, p, r, clone_hit_t)
	# The body lunges at what it swung at. **The bloom above stays at the true position** — being hit and
	# hitting are two events and one must not drag the other's mark off the body it belongs to.
	var lunge := _lunge_offset(sw.swing_dir[i], sw.swing_show[i], Look.SWING_LUNGE_TIME)
	p += lunge
	_paint_cell(c, p, r, col, squash, rot)
	_paint_rim(c, p, r, Look.CORNER, squash, rot)
	# §B-5: the clone's own swing line, toward what it hit — through `_paint_part_line`, the leaf a limb
	# already uses, so forty simultaneous swings cost no new leaf.
	var swing_t := sw.swing_show[i]
	if swing_t < Look.CLONE_HIT_LINE_TIME:
		var swing_dir: Vector2 = sw.swing_dir[i]
		if swing_dir.length_squared() > 0.0001:
			_paint_part_line(c, p, p + swing_dir * (Rules.CLONE_BODY_RADIUS * Look.CLONE_HIT_LINE_RING),
					Look.CLONE_HIT_LINE_WIDTH, Look.CLONE_HIT_LINE_COLOR)


## The loud half of a hit, and the only part of it with any AREA. Every body takes it — clone, creature and
## host — off the same up-counting `hit_show` column the flash reads, so no timer lives here (§0-2 of
## 연출 한 판) and pause stops all of a hit's marks together.
##
## ⚠ **Drawn BEFORE the body, never over it.** A filled halo painted on top hides the body it is telling you
## about, and *which* one was hit is the thing a wide melee has to keep. Growing from the body's own radius
## outward means the visible part is always the ring of light OUTSIDE the silhouette.
##
## ⚠ **This exists because a tint has no area on 갈래 ㄱ.** With the body drawn as a stroke,
## `HIT_FLASH_STRENGTH` repaints two pixels and the user's read was that nothing happened at all. Both marks
## go through leaves that already have their own rows (`_paint_disc`, `_paint_arc`), so this composer draws
## nothing itself and costs no new leaf.
func _paint_hit_bloom(c: CanvasItem, p: Vector2, r: float, hit_t: float) -> void:
	if hit_t >= Look.HIT_FLASH_TIME:
		return
	var frac := hit_t / Look.HIT_FLASH_TIME
	var fade := 1.0 - frac
	var bloom: Color = Look.HIT_BLOOM_COLOR
	bloom.a *= fade
	_paint_disc(c, p, r * lerpf(1.0, Look.HIT_BLOOM_R_MUL, frac), bloom)
	var wave: Color = Look.HIT_WAVE_COLOR
	wave.a *= fade
	_paint_arc(c, p, r + Look.HIT_WAVE_R * frac, 0.0, TAU, wave, Look.HIT_WAVE_WIDTH)


## How far a body is DRAWN from where it stands, because it is mid-swing. Out and back over
## `Look.SWING_LUNGE_TIME`, peaking at the halfway point and exactly zero at both ends — a body that ended
## displaced would drift away from the circle the sim collides with, and every hit would land from a place
## the picture does not show.
##
## ⚠ **Pure, and it never touches `sim`.** The lunge is a gesture; moving the real position would change
## who is in reach of whom, which is the one thing presentation may not do.
func _lunge_offset(dir: Vector2, swing_t: float, span: float) -> Vector2:
	if swing_t >= span or dir.length_squared() <= 0.0001:
		return Vector2.ZERO
	# `sin(pi x)` is the out-and-back: 0 at x=0, 1 at the middle, 0 at x=1, and smooth at the peak so the
	# snap back does not read as a teleport the way a triangle wave does.
	return dir * (sin(PI * (swing_t / span)) * Look.SWING_LUNGE_PUSH)


## One creature's slot: the block that was the critter loop, moved whole.
##
## **Colour comes from the species and size comes from the species**, and both used to come from `threat` —
## one number the design deleted. Red-for-hunter/blue-for-prey was a comparison against the swarm's total
## force; nothing derives behaviour from a comparison any more, so nothing draws from one.
##
## ⚠ **`_heading` needs `length_squared > 1.0`.** `critter_dir` is a UNIT vector, so handing it over bare
## draws every creature at rotation 0 — the whole field facing east, with no error and nothing red. It is
## scaled to the speed that direction actually walks at, which is the same number `_step_critters` uses.
func _paint_critter(c: CanvasItem, k: int) -> void:
	var p := world.critter_pos[k]
	var s := world.critter_species[k]
	var r := world.critter_radius(k)
	var species_col: Color = SPECIES_COLOR[s]
	# §F-12: trailing ghosts, gated by SPECIES rather than by this frame's actual speed — cheetah and
	# horse are the only rows where `Rules.SPECIES_SPEED_MUL[s] > 1.0`, so the trail itself is the "this
	# one out-runs you" information rather than decoration on whatever happens to be moving. Drawn from
	# the UNFLASHED species colour, before the hit-flash lerp below, and BEFORE the real body so the real
	# body paints on top of its own trail. `critter_dir[k]` is always a valid unit vector (never zero —
	# see `_write_critter()`), so no length guard is needed the way `_heading()` needs one.
	if float(Rules.SPECIES_SPEED_MUL[s]) > 1.0:
		var back_dir: Vector2 = -world.critter_dir[k]
		for g in Look.AFTERIMAGE_COUNT:
			var step_n := g + 1
			var ghost_p := p + back_dir * (r * Look.AFTERIMAGE_GAP_RING * float(step_n))
			var fade := 1.0 - float(step_n) / float(Look.AFTERIMAGE_COUNT + 1)
			# A copy-and-mutate, never `Color(...)` — that literal is what `net_draw_leaf`'s colour scan
			# forbids outside `look.gd`, and species_col's own r/g/b are already the right ones.
			var ghost_col: Color = species_col
			ghost_col.a = Look.AFTERIMAGE_ALPHA * fade
			# **No rim on a ghost**, deliberately: three hard dark edges trailing a body is the opposite of
			# what a fading trail says. See `Look.BODY_RIM_COLOR`.
			_paint_cell(c, ghost_p, r, ghost_col, Vector2.ONE)
	# **Mixed toward white, never painted over.** `critter_hit_show` counts UP from the hit and opens at
	# `INF`, so an untouched neighbour's `hit_t` never satisfies this and its colour never moves — the
	# whole reason a wide swarm hitting one creature does not read as the field going white.
	# ⚠ **`HIT_FLASH_STRENGTH` caps the weight below 1.0**, or the frame the hit lands (`hit_t == 0.0`,
	# reachable on every clone-contact hit) is a flat white overpaint — see that constant's own note.
	var hit_t := world.critter_hit_show[k]
	if hit_t < Look.HIT_FLASH_TIME:
		species_col = species_col.lerp(Look.HIT_FLASH_COLOR,
				Look.HIT_FLASH_STRENGTH * (1.0 - hit_t / Look.HIT_FLASH_TIME))
	var rot := _heading(world.critter_dir[k] * float(Rules.SPECIES_SPEED_MUL[s]) * Rules.HOST_SPEED)
	_paint_hit_bloom(c, p, r, hit_t)
	# The creature's own swing: the lunge, and a line toward what it swung at. Both off
	# `critter_swing_show`, which is written where `critter_atk_cd` is — so a swing the host's grace period
	# ate still shows, and the grace period does not read as the creature having stopped attacking.
	var swing_t := world.critter_swing_show[k]
	var swing_dir: Vector2 = world.critter_swing_dir[k]
	# ⚠ **The lunge is scaled by the SPECIES now.** `_lunge_offset` stays the one curve — a clone uses it
	# unchanged — and the multiplier is applied here, at the one call site that has a species to ask about.
	# Folding it into `_lunge_offset` would hand the clone a species it does not have. See
	# `Look.SPECIES_LUNGE_MUL`, whose comment carries why the elephant and the lion are not 1.0.
	var swung := p + _lunge_offset(swing_dir, swing_t, Look.SWING_LUNGE_TIME) \
			* float(Look.SPECIES_LUNGE_MUL[s])
	_paint_cell(c, swung, r, species_col, Vector2.ONE, rot)
	_paint_rim(c, swung, r, Look.CORNER, Vector2.ONE, rot)
	if swing_t < Look.CRITTER_SWING_TIME and swing_dir.length_squared() > 0.0001:
		_paint_swing(c, s, swung, r, swing_dir, swing_t / Look.CRITTER_SWING_TIME)
	# The hit spark: a second, separate mark, through the SAME leaf rocks and ponds already use rather
	# than a new one. `critter_hit_dir` points AWAY from the attacker (`World._damage_critter`'s own
	# doc), so the struck surface sits the other way, at `-hit_dir` from the centre.
	if hit_t < Look.HIT_FLASH_TIME:
		var spark_t := 1.0 - hit_t / Look.HIT_FLASH_TIME
		var hit_dir: Vector2 = world.critter_hit_dir[k]
		var hit_p := (p - hit_dir * r) if hit_dir.length_squared() > 0.0001 else p
		_paint_disc(c, hit_p, Look.HIT_SPARK_R * spark_t, Look.HIT_FLASH_COLOR)


# -- one gesture per species ------------------------------------------------------------------------------
## **Which shape a creature's attack is, by species.** One `_paint_part_line` for everything was the whole of
## a monster attacking until now, and the user's read of it was that monsters do not appear to attack at all
## (*"몬스터가 공격하면 몬스터마다 좀 다르게 해야지"*, *"뭔가 뜨면서 공격을 해야 될 거 아니야"*).
##
## **A composer: it draws nothing itself and every branch reaches an EXISTING leaf** (`_paint_part_line`,
## `_paint_disc`, `_paint_arc`), which is what makes seven new gestures cost zero new leaves and keeps the
## three spies that already watch those leaves able to see all of them. Every constant is in `look.gd`, in
## the `one gesture per species` block.
##
## `t` is the swing's own progress, `0 → 1` across `Look.CRITTER_SWING_TIME`, so no gesture holds a timer.
##
## ⚠ **The default branch is the line this file drew before, not "nothing".** 말·다람쥐·치타·토끼 cannot
## reach it — a fleeing creature never attacks and `critter_swing_show` stays `INF` for it — but a species
## added tomorrow and forgotten here must still draw something rather than silently swinging at nothing.
func _paint_swing(c: CanvasItem, s: int, at: Vector2, r: float, dir: Vector2, t: float) -> void:
	match s:
		Parts.Species.CROW:
			_paint_swing_peck(c, at, r, dir)
		Parts.Species.MOUSE:
			_paint_swing_gnaw(c, at, r, dir, t)
		Parts.Species.DOG:
			_paint_swing_bite(c, at, r, dir, t)
		Parts.Species.BOAR:
			_paint_swing_charge(c, at, r, dir, t)
		Parts.Species.ELEPHANT:
			_paint_swing_shove(c, at, r, dir)
		Parts.Species.LION:
			_paint_swing_pounce(c, at, r, dir, t)
		Parts.Species.BOSS:
			_paint_swing_stomp(c, at, r, t)
		_:
			_paint_swing_lash(c, at, r, dir)


## 까마귀 쪼기: two strokes off the body's edge at ±`Look.SWING_PECK_ANGLE`, both full length for the whole
## window. **`MIRROR` is the pair, so only one sign is ever written** — the same refusal the limb pairs make.
func _paint_swing_peck(c: CanvasItem, at: Vector2, r: float, dir: Vector2) -> void:
	for m: float in MIRROR:
		var d := dir.rotated(Look.SWING_PECK_ANGLE * m)
		var edge := at + d * r
		_paint_part_line(c, edge, edge + d * (r * Look.SWING_PECK_RING), Look.CRITTER_SWING_WIDTH,
				Look.CRITTER_SWING_COLOR)


## 들쥐 갉기: one shrinking dot at the contact point and no line at all. See `Look.SWING_GNAW_RING`.
func _paint_swing_gnaw(c: CanvasItem, at: Vector2, r: float, dir: Vector2, t: float) -> void:
	_paint_disc(c, at + dir * r, r * Look.SWING_GNAW_RING * (1.0 - t), Look.CRITTER_SWING_COLOR)


## 들개 물어뜯기: one stroke that turns from `-SWING_BITE_SWEEP` to `+SWING_BITE_SWEEP` across the window.
## **The rotation is the mark** — the length alone is a poke and reads as a crow's single line.
func _paint_swing_bite(c: CanvasItem, at: Vector2, r: float, dir: Vector2, t: float) -> void:
	var d := dir.rotated(lerpf(-Look.SWING_BITE_SWEEP, Look.SWING_BITE_SWEEP, t))
	_paint_part_line(c, at, at + d * (r * Look.SWING_BITE_RING), Look.CRITTER_SWING_WIDTH,
			Look.CRITTER_SWING_COLOR)


## 멧돼지 들이받기: an arc centred on `dir` that opens from a point to the full `SWING_CHARGE_ARC` as the
## window runs. **The sweep is a function of `t`, not a fixed wedge** — a whole arc from the first frame is
## a shield, and this has to read as tusks coming up through you.
func _paint_swing_charge(c: CanvasItem, at: Vector2, r: float, dir: Vector2, t: float) -> void:
	var a0 := dir.angle() - Look.SWING_CHARGE_ARC * 0.5
	_paint_arc(c, at, r * Look.SWING_CHARGE_RING, a0, a0 + Look.SWING_CHARGE_ARC * t,
			Look.CRITTER_SWING_COLOR, Look.CRITTER_SWING_WIDTH)


## 코끼리 밀치기: one heavy bar ACROSS the swing direction at the contact point. Paired with
## `Look.SPECIES_LUNGE_MUL`'s doubled push, which is applied at `_paint_critter`'s one call site.
func _paint_swing_shove(c: CanvasItem, at: Vector2, r: float, dir: Vector2) -> void:
	var across := Vector2(-dir.y, dir.x) * (r * Look.SWING_SHOVE_RING)
	var mid := at + dir * r
	_paint_part_line(c, mid - across, mid + across,
			Look.CRITTER_SWING_WIDTH * Look.SWING_SHOVE_WIDTH_MUL, Look.CRITTER_SWING_COLOR)


## 사자 덮치기: the lunge is the gesture (`Look.SPECIES_LUNGE_MUL` ×3) and this is only where it lands — one
## dot ahead of the body, shrinking from `Look.HIT_SPARK_R` to nothing. **No line**, deliberately: a line
## from a body that has already thrown itself forward marks the same distance a second time.
func _paint_swing_pounce(c: CanvasItem, at: Vector2, r: float, dir: Vector2, t: float) -> void:
	_paint_disc(c, at + dir * (r * Look.SWING_POUNCE_RING), Look.HIT_SPARK_R * (1.0 - t),
			Look.CRITTER_SWING_COLOR)


## 보스 내려찍기: a ring on the ground at its feet, growing to `Look.SWING_STOMP_RING × r` and fading out.
## **`_paint_arc` from 0 to TAU, never `_paint_ring`** — that leaf draws a second circle at `r × 0.45`, the
## companion circle that dragged itself across the arena wall for a whole plan.
func _paint_swing_stomp(c: CanvasItem, at: Vector2, r: float, t: float) -> void:
	# A copy-and-mutate, never a `Color(...)` literal — `net_draw_leaf`'s colour scan forbids one here.
	var col: Color = Look.CRITTER_SWING_COLOR
	col.a *= (1.0 - t)
	_paint_arc(c, at, lerpf(r, r * Look.SWING_STOMP_RING, t), 0.0, TAU, col, Look.ARENA_WALL_WIDTH)


## The fallback, and it is what this file drew for every species before the gestures existed. Unreachable
## through the shipped tables — see `_paint_swing`'s own note on why that is deliberate rather than dead.
func _paint_swing_lash(c: CanvasItem, at: Vector2, r: float, dir: Vector2) -> void:
	_paint_part_line(c, at, at + dir * (r * Look.CRITTER_SWING_RING), Look.CRITTER_SWING_WIDTH,
			Look.CRITTER_SWING_COLOR)


## The host's slot: the block that closed `_paint`, moved whole.
func _paint_host(c: CanvasItem) -> void:
	var sw := world.swarm
	# Under the unsorted candidates the cone rides here, exactly where it has been since plan 2 — under the
	# host, over every creature. Sorted, this slot can be covered by anything south of it, so `_paint` lifts
	# the cone into the overlay instead. The two call sites are exclusive; the shape is in one place.
	if not _rimmed():
		_paint_bite_cone(c)

	var host_col: Color = Look.HOST_COLOR if world.host_grace <= 0.0 else Look.HOST_HURT_COLOR
	# The radius is a `Rules` constant, not a `Look` one: it decides who `V` absorbs. Drawing it from
	# anywhere else is how the picture stops being the simulation.
	var host_r: float = Rules.BODY_RADIUS * (1.0 + _absorb_pop * 0.35)
	# §F-9: the level-up pop. **A different colour and a different strength from the harvest pop above** —
	# `_absorb_pop` never tints `host_col` at all, so any tint here already reads as its own event, and the
	# radius multiplier (`LEVEL_POP_STRENGTH`) is its own number rather than a reuse of `0.35`. Driven off
	# `World.level_show`, a sim-owned clock, never a diff of `level` held here.
	var level_t := 1.0 - clampf(world.level_show / Look.LEVEL_POP_TIME, 0.0, 1.0)
	if level_t > 0.0:
		host_r *= (1.0 + level_t * Look.LEVEL_POP_STRENGTH)
		host_col = host_col.lerp(Look.LEVEL_POP_COLOR, level_t)
	# **The host, and only the host, goes through `_paint_body`.** A clone has no `Body` — it carries one
	# part index (plan 4) — so it keeps the bare `_paint_cell` of `_paint_clone`.
	var b := world.body
	# The host takes the same bloom every other body takes — row 0 of the very same column, so "I was hit"
	# and "it was hit" are one mark and not two that can drift apart.
	_paint_hit_bloom(c, sw.pos[0], host_r, sw.hit_show[0])
	_paint_body(c, sw.pos[0], host_r, host_col, _squash(sw.vel[0], Rules.HOST_SPEED), _heading(sw.vel[0]),
			_body_corner(b), _body_outline_width(b), _body_colour_depth(b), _body_dot_radius(b),
			b.slot_part)


## The bite cone, and **one function precisely because it is drawn from two places** — the host's own slot
## under FILL and LINE, the overlay under 갈래 ㄴ. `bite_show` counts UP from the moment a bite landed and
## opens at INF, so a run that has never bitten draws nothing without a second flag to keep in sync.
## **Shape comes off the swarm, which stored what `bite()` itself tested with** — a cone tuned here to look
## right would be a picture of a hit that did not happen, and a constant would be one part's cone drawn over
## another part's hit now that range and arc belong to the part that fired.
func _paint_bite_cone(c: CanvasItem) -> void:
	var sw := world.swarm
	if sw.bite_show < Look.BITE_SHOW_TIME:
		_paint_cone(c, sw.pos[0], sw.bite_aim, sw.bite_range, sw.bite_arc, Look.BITE_COLOR)


## §A-3's dark rim, on one body's own silhouette. **Called from every body's own slot, right after that
## body's `_paint_cell`** — before it the fill covers it, a slot later it separates the wrong pair.
##
## It draws nothing outside 갈래 ㄴ, and the gate is here rather than at the three call sites so a body
## cannot be given a rim in one candidate and not another by somebody editing one loop. Food, corpses and
## afterimage ghosts never reach it at all: they are not bodies, or they are a trail. See
## `Look.BODY_RIM_COLOR`.
func _paint_rim(c: CanvasItem, p: Vector2, r: float, corner: float, squash: Vector2, rot: float) -> void:
	if not _rimmed():
		return
	var width := _rim_width(r)
	# **Inside, never outside.** The stroke is centred at `r - width * 0.5`, so its outer edge lands exactly
	# on `r` and the drawn body is never wider than the radius the sim collides with — the same refusal
	# `_paint_disc`'s own note already makes for rocks.
	_paint_outline(c, p, r - width * 0.5, corner, Look.BODY_RIM_COLOR, width, squash, rot)


## Pure, so a net can pin both ends of the clamp and the knee between them rather than trusting a picture
## headless has no pixels to read back. Why it is absolute px with a fraction cap rather than either alone
## is on `Look.BODY_RIM_WIDTH`.
func _rim_width(r: float) -> float:
	return minf(Look.BODY_RIM_WIDTH, r * Look.BODY_RIM_MAX_FRACTION)


# -- the number under every body -------------------------------------------------------------------------
## One entry per label, `{"p": Vector2, "text": String}`, where `p` is the DRAW ORIGIN — the cluster's
## centroid, minus half the measured string width, plus `Look.FORCE_LABEL_OFFSET` in y.
##
## **Pure, so a net can compare the hook's arguments to it** — and a net that only calls this proves the
## arithmetic and not the picture, which is why the leaf takes the same values as arguments.
##
## Four rules, and every one of them would destroy the readout on its own:
## 1. **The host is always its own label.** Never absorbed into a cluster, however tight the swarm is.
## 2. **Mine and theirs never share a cluster**, and neither do two different species: a swarm of 8 among
##    crows of 3 must not read 11, and a boss of 120 beside a crow of 10 must not read 130 — whose `?`
##    lookup would then have no species to ask about.
## 3. **A species never eaten reads `?`**, so the number under a body is knowledge you earned. The boss is
##    the exception and shows its 120 from `t = 0`: by the rule it would read `?` for the whole run, and
##    seeing the number you cannot yet reach is the arc.
## 4. **A mine-side label carries hp too** (`힘·체력`); theirs stays one number. Their hp is not a number
##    you manage, and four numbers on forty creatures is the debug overlay the HUD's own header records.
func _force_labels() -> Array:
	var out := []
	if world == null:
		return out
	var sw := world.swarm

	# Rule 1. ⚠ **The host's hp is `World.host_hp`, never `swarm.hp[0]`** — row 0 of that column is the -1
	# sentinel the swarm's own doc defines, and printing it puts `-1` under the host on the opening frame.
	out.append(_label(sw.pos[0], "%d·%d" % [sw.force[0], world.host_hp]))

	# Rule 2, half one: clones cluster only with clones.
	var cp := PackedVector2Array()
	var cf := PackedInt32Array()
	var ch := PackedInt32Array()
	for i in range(1, sw.count):
		if not view_rect.has_point(sw.pos[i]):
			continue
		cp.append(sw.pos[i])
		cf.append(sw.force[i])
		ch.append(sw.hp[i])
	for cl: Dictionary in _cluster(cp, cf, ch):
		out.append(_label(cl["c"], "%d·%d" % [cl["f"], cl["h"]]))

	# Rule 2, half two: creatures cluster only with creatures of the same species — one pass per species,
	# which is what makes sharing structurally impossible rather than a distance test that happens to fail.
	for s in SPECIES_COLOR.size():
		var kp := PackedVector2Array()
		var kf := PackedInt32Array()
		var kh := PackedInt32Array()
		for k in world.critter_count:
			if world.critter_species[k] != s or not view_rect.has_point(world.critter_pos[k]):
				continue
			kp.append(world.critter_pos[k])
			kf.append(world.critter_force[k])
			kh.append(world.critter_hp[k])
		if kp.is_empty():
			continue
		# Rules 3 and 4.
		var known := s == Parts.Species.BOSS or world.species_eaten.has(s)
		for cl: Dictionary in _cluster(kp, kf, kh):
			out.append(_label(cl["c"], ("%d" % cl["f"]) if known else "?"))
	return out


## Greedy: walk the list, join the first cluster whose RUNNING centroid is within
## `Look.FORCE_CLUSTER_RADIUS`, else open a new one.
##
## ⚠ **Not `SimGrid.neighbours()`, and that is the whole reason this loop is written out.** The grid
## truncates at `NEIGHBOUR_CAP` by design, so a pile of forty would sum to eight — silently capped at
## exactly the moment `1` and `V` make a pile of forty, which is the moment the number matters most.
func _cluster(pts: PackedVector2Array, forces: PackedInt32Array, hps: PackedInt32Array) -> Array:
	var out := []
	for i in pts.size():
		var joined := false
		for cl: Dictionary in out:
			var centre: Vector2 = cl["c"]
			if centre.distance_to(pts[i]) > Look.FORCE_CLUSTER_RADIUS:
				continue
			var n := int(cl["n"]) + 1
			cl["n"] = n
			cl["c"] = centre + (pts[i] - centre) / float(n)
			cl["f"] = int(cl["f"]) + forces[i]
			cl["h"] = int(cl["h"]) + hps[i]
			joined = true
			break
		if not joined:
			out.append({"c": pts[i], "n": 1, "f": forces[i], "h": hps[i]})
	return out


## Centring, done HERE and not by the alignment argument. ⚠ **Godot 4 ignores
## `HORIZONTAL_ALIGNMENT_CENTER` when `width` is negative**, so passing it does nothing at all and every
## label sits half its own width to the right of the centroid it documents — invisible headless, because
## there are no pixels and the spy captures a `p` that is correct for what it was told. Measured here, the
## offset is an argument a net can read back.
func _label(centre: Vector2, text: String) -> Dictionary:
	var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			Look.FORCE_LABEL_SIZE).x
	return {"p": Vector2(centre.x - w * 0.5, centre.y + Look.FORCE_LABEL_OFFSET), "text": text}


## Is anybody on their way to the strike point. Asked of the swarm rather than remembered here — the view
## may not hold state the sim does not know about.
func _striking(sw: Swarm) -> bool:
	for i in range(1, sw.count):
		if sw.state[i] == Swarm.STRIKE:
			return true
	return false


# -- what the internal slots are worth, in pixels ----------------------
## **Four pure functions of `Body`, and every one of them is keyed on `slot_level`, not on which part sits
## there.** An internal slot's job is to change a drawing value, so the value has to move with the level as
## well as with the part — a function that only asked "is something worn" would make a Lv3 hide identical
## to a Lv1 one, which is the same shape as a level that does nothing.
##
## ⚠ **No part in the August table occupies `BONE`, `EYES` or `HIDE`**, so all three are at their bare-body
## value for the whole of this plan. They are still driven — a net can put a part in the slot by hand — but
## nothing a player does reaches them, and `GUT` and `LUNG` have no drawing value at all (see `look.gd`).

## Bone SHARPENS: it takes the corner cut DOWN, floored so the body never becomes a plain square. A bare
## body is `Look.CORNER` exactly, which is the number every body in the game drew with before this plan.
func _body_corner(b: Body) -> float:
	var lv := b.slot_level[Parts.Slot.BONE]
	return maxf(Look.CORNER_MIN, Look.CORNER - float(lv) * Look.CORNER_PER_BONE)


## Hide/fur: an outline that thickens per level. Zero on a bare body, and `_paint_body` draws nothing at
## zero rather than a hairline nobody asked for.
func _body_outline_width(b: Body) -> float:
	var lv := b.slot_level[Parts.Slot.HIDE]
	return 0.0 if lv <= 0 else Look.HIDE_OUTLINE_WIDTH * float(lv)


## Hide/fur again, the other half: how much darker the whole body reads. One slot, two values, because the
## design names both ("outline and colour depth") and a single one of them is half the slot.
func _body_colour_depth(b: Body) -> float:
	return float(b.slot_level[Parts.Slot.HIDE]) * Look.HIDE_COLOR_DEPTH


## Eyes: the dot radius, as a multiple of the body's radius. **Zero means no eyes and nothing is drawn** —
## a bare body has no dots, which is exactly the picture today, so this slot adds marks instead of moving
## them.
func _body_dot_radius(b: Body) -> float:
	var lv := b.slot_level[Parts.Slot.EYES]
	return 0.0 if lv <= 0 else Look.EYE_DOT_RADIUS + float(lv - 1) * Look.EYE_DOT_PER_LEVEL


## **The host's body, with what it is wearing on it.** The hook the net asserts, and it takes the internal
## slots' effects as SEPARATE, EXPLICIT arguments rather than reading them back off `Body` — a net has to
## be able to pin a bare body's corner radius and a bone-wearing body's corner radius as literals. "The
## arguments differ" is the A/B comparison that lets five internal slots change nothing on screen and stay
## green, which is how a doubled power once moved zero pixels.
##
## It goes on to call `_paint_cell` for the base blob, so a spy that finds the host by its radius through
## that hook still finds it. Everything a part adds is drawn on top, **in the host's own colour lifted by
## `Look.PART_COLOR_LIFT`** — one tone on the whole body is what escaped the "texture comes from the
## preset" constraint, so a part is a shape and a lift, never a picture.
func _paint_body(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float,
		corner: float, outline_width: float, colour_depth: float, dot_radius: float,
		slot_part: PackedInt32Array) -> void:
	# Hide/fur deepens the whole body before anything is drawn on it — an internal slot changes a VALUE, and
	# this is the value it changes.
	var body_col := col.darkened(colour_depth)
	_paint_cell(c, p, r, body_col, squash, rot, corner)
	# **The rim and hide/fur's outline are one stroke at two strengths and must never both be drawn.**
	# Wearing hide THICKENS and DARKENS the line the body already had rather than adding a second concentric
	# one — which is also what keeps 갈래 ㄴ's rim from eating the `HIDE` square's only visible payout, the
	# cost `melee-legibility-ko` names for giving the host a standing outline.
	if outline_width > 0.0:
		_paint_outline(c, p, r - outline_width * 0.5, corner,
				body_col.darkened(Look.HIDE_OUTLINE_DARKEN), outline_width, squash, rot)
	else:
		_paint_rim(c, p, r, corner, squash, rot)

	var part_col := body_col.lightened(Look.PART_COLOR_LIFT)
	# The body's own frame: `fwd` along the facing, `side` across it. Limb pairs mirror on `side`, so only
	# one sign is written anywhere and the other is derived — see `look.gd`.
	var fwd := Vector2(cos(rot), sin(rot))
	var side := Vector2(-sin(rot), cos(rot))

	if _has(slot_part, Parts.Slot.HEAD):
		_paint_part_shape(c, p + fwd * (r * Look.PART_HEAD_ANCHOR), r * Look.PART_HEAD_SIZE, corner,
				part_col)
	if _has(slot_part, Parts.Slot.TORSO):
		_paint_part_shape(c, p + fwd * (r * Look.PART_TORSO_ANCHOR), r * Look.PART_TORSO_BULGE, corner,
				part_col)
	if _has(slot_part, Parts.Slot.BACK):
		_paint_part_shape(c, p + fwd * (r * Look.PART_BACK_ANCHOR), r * Look.PART_BACK_SIZE, corner,
				part_col)
	if _has(slot_part, Parts.Slot.FORELIMBS):
		_paint_limb_pair(c, p, r, fwd, side, Look.PART_FORELIMB_ANCHOR, part_col)
	if _has(slot_part, Parts.Slot.HINDLIMBS):
		_paint_limb_pair(c, p, r, fwd, side, Look.PART_HINDLIMB_ANCHOR, part_col)
	if _has(slot_part, Parts.Slot.TAIL):
		var root := p + fwd * (r * Look.PART_TAIL_ANCHOR)
		_paint_part_line(c, root, root - fwd * (r * Look.PART_TAIL_LENGTH), Look.PART_TAIL_WIDTH, part_col)

	# Eyes are the one internal slot that adds marks rather than changing a number, and the number IS the
	# radius: 0 means no eyes and nothing is drawn, which is exactly a bare body's picture today.
	if dot_radius > 0.0:
		if Look.BODY_STYLE == Look.BodyStyle.LINE:
			# 갈래 ㄱ: the body already carries ONE centred nucleus from `_paint_cell_line`, so this square
			# does not add a second mark — `the-body-is-a-line-drawn-by-code` rejected two eyes by name,
			# because a face has a front and this body takes parts on all six sides. The slot enlarges the
			# nucleus instead, concentric and in the body's own colour, which is what an internal slot is
			# for. `Look.EYE_DOT_COLOR` was chosen to read against a FILLED bright body and would sit on the
			# ground colour here, so it is not what a hollow body's dot is painted with.
			_paint_dot(c, p, _outline_dot_r(r, dot_radius), body_col)
		else:
			var eye := Look.EYE_DOT_OFFSET
			for s: float in MIRROR:
				_paint_dot(c, p + fwd * (r * eye.x) + side * (r * eye.y * s), r * dot_radius,
						Look.EYE_DOT_COLOR)


func _has(slot_part: PackedInt32Array, slot: int) -> bool:
	return slot < slot_part.size() and slot_part[slot] >= 0


func _paint_limb_pair(c: CanvasItem, p: Vector2, r: float, fwd: Vector2, side: Vector2,
		anchor: Vector2, col: Color) -> void:
	for s: float in MIRROR:
		var root := p + fwd * (r * anchor.x) + side * (r * anchor.y * s)
		_paint_part_line(c, root, root + side * (r * Look.PART_LIMB_LENGTH * s), Look.PART_LIMB_WIDTH, col)


## An external part that is a lump: the same knocked-off square as a body, smaller, at its anchor. The
## only place `draw_colored_polygon` is called for a part.
func _paint_part_shape(c: CanvasItem, p: Vector2, r: float, corner: float, col: Color) -> void:
	c.draw_colored_polygon(_blob(r, p, corner), col)


## An external part that is a line: a limb or a tail. Width is absolute px on purpose — a limb that thins
## with the body disappears rather than scaling.
func _paint_part_line(c: CanvasItem, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	c.draw_line(a, b, col, width)


## Hide/fur's outline, and 갈래 ㄴ's rim, traced around the body's own silhouette so neither can drift from
## it. **One leaf for both**, because they are one stroke at two strengths — see `_paint_rim` and
## `melee-legibility-ko`'s 갈래 ㄴ.
##
## ⚠ **`squash` and `rot` are arguments and they are not decoration.** The body is drawn through
## `draw_set_transform(p, rot, squash)`; an outline built in world space from an untransformed `_blob` sits
## square and unrotated around a stretched, turned body, and at speed the two visibly come apart. The
## mismatch predates the rim — hide's outline has always had it — and is closed here for both.
##
## ⚠ **The caller passes the radius it wants the stroke CENTRED on, never the body's own `r`.** A stroke
## drawn at `r` straddles it and the picture ends up wider than the collision circle.
func _paint_outline(c: CanvasItem, p: Vector2, r: float, corner: float, col: Color,
		width: float, squash: Vector2, rot: float) -> void:
	var pts := _blob(r, Vector2.ZERO, corner)
	var cs := cos(rot)
	var sn := sin(rot)
	for i in pts.size():
		var q := Vector2(pts[i].x * squash.x, pts[i].y * squash.y)
		pts[i] = p + Vector2(q.x * cs - q.y * sn, q.x * sn + q.y * cs)
	pts.append(pts[0])
	c.draw_polyline(pts, col, width)


## The eye dots. **One of the three places `draw_circle` is called in this file** — the others are
## `_paint_disc` and 갈래 ㄱ's own `_paint_cell_line`, both kept apart on purpose; see their notes. It was
## two until the fork was built, and this sentence has to move every time that count does.
func _paint_dot(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	c.draw_circle(p, r, col)


## A filled circle at world scale — the ground's own leaf, and one of the three places this file draws one
## (the others are `_paint_dot` and 갈래 ㄱ's `_paint_cell_line`). It exists because
## `Terrain`'s three predicates are all `distance < radius`: a rock drawn as a blob is walkable at its
## corners and solid a few pixels in from its edge, which is screen and sim disagreeing in the one feature
## herding rests on.
##
## ⚠ **Not `_paint_dot`** — that leaf is the eyes and a net spies it; folding forty rocks into the same spy
## makes every eye assertion unreadable. ⚠ **Not `_paint_arc`** either: `draw_arc` strokes an outline, so a
## 90px rock would come back hollow.
func _paint_disc(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	c.draw_circle(p, r, col)


## **Every body on the field passes through here, and the fork lives in this one branch.** Which of the two
## pictures is drawn is `Look.BODY_STYLE`: `melee-legibility-ko` opens that fork and nobody has picked, and
## `the-body-is-a-line-drawn-by-code` is what decided the line by generating candidates and looking at them.
## Six call sites reach this — corpses, food, clones, afterimages, critters and the host's base blob — so
## putting the branch here rather than at the call sites is what makes "every body" true by construction
## instead of by a list somebody has to keep.
##
## ⚠ **The signature is unchanged on purpose.** Every spy in the round overrides exactly this hook, so a
## dispatcher that keeps the signature keeps all of them capturing every body under both candidates.
##
## `corner` defaults to `Look.CORNER` because a clone, a crumb and a critter have no `Body` and no bone
## slot; only the host's corner ever moves.
func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0,
		corner: float = Look.CORNER) -> void:
	if Look.BODY_STYLE == Look.BodyStyle.LINE:
		_paint_cell_line(c, p, r, col, squash, rot, corner)
	else:
		_paint_cell_fill(c, p, r, col, squash, rot, corner)


## 갈래 ㄴ, and what the build has drawn since plan 1: a shadow ellipse under it, the body, and a lighter top
## edge. Depth comes from those three and from the squash, never from shaded art — the GDD's whole art claim
## rests on that being enough.
##
## ⚠ **Under 갈래 ㄱ only the squash of those four survives, and neither fill can simply be kept.** A hollow
## body has nowhere to hide them: the shadow would show THROUGH the outline as a second dark shape offset
## downward, and the top edge is a filled blob at 52% of the body that would read as a smaller body sitting
## inside the bigger one and fight the nucleus for the same eye.
func _paint_cell_fill(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float,
		corner: float) -> void:
	# The shadow does not rotate with the body — it lies on the ground, and rotating it is the tell that
	# turns a squashed blob back into a spinning sprite.
	c.draw_set_transform(p + Vector2(0.0, r * 0.62), 0.0, Vector2(squash.x, squash.y * 0.42))
	c.draw_colored_polygon(_blob(r, Vector2.ZERO, corner), Look.CELL_SHADOW)
	c.draw_set_transform(p, rot, squash)
	c.draw_colored_polygon(_blob(r, Vector2.ZERO, corner), col)
	# Drawn unrotated, so the light stays overhead however the body is stretched. Lit from one direction
	# for every body in the scene — the GDD's one hard art rule, and it starts here.
	c.draw_set_transform(p, 0.0, Vector2.ONE)
	c.draw_colored_polygon(_blob(r * 0.52, Vector2(0.0, -r * 0.3), corner), col.lightened(0.28))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 갈래 ㄱ: the same knocked-off square, stroked as a closed line, with one dot at its centre and nothing
## between them. The radius is the body's own `r`, so the footprint on screen does not move by a pixel
## between the two candidates — only fill versus line changes, and a comparison that moved two axes would
## answer nothing.
##
## ⚠ **It strokes its own polyline instead of calling `_paint_outline`, and draws its own circle instead of
## calling `_paint_dot`.** Both would have been reuse, and both would have folded every body on the field
## into a spy that today answers a much narrower question: `_paint_outline` is the HIDE slot's outline and
## `net_paint` asserts it is reached only when hide is worn, `_paint_dot` is the eyes. Same argument
## `_paint_disc` already carries in its own note for not being `_paint_dot`.
func _paint_cell_line(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float,
		corner: float) -> void:
	var pts := _blob(r, Vector2.ZERO, corner)
	pts.append(pts[0])
	c.draw_set_transform(p, rot, squash)
	c.draw_polyline(pts, col, _outline_width(r))
	# The nucleus is drawn AFTER the transform is reset: it stays a true circle under squash and stays
	# centred under rotation, which is the property that beat two eyes when the candidates were looked at.
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_circle(p, _outline_dot_r(r), col)


## Pure, so a net can pin the stroke at literal radii instead of trusting a picture headless has no pixels
## to read back. Why it is a fraction of the body rather than a flat pixel count is on `OUTLINE_WIDTH_RING`.
func _outline_width(r: float) -> float:
	return clampf(r * Look.OUTLINE_WIDTH_RING, Look.OUTLINE_WIDTH_MIN, Look.OUTLINE_WIDTH_MAX)


## Pure, same reason. `bonus` is the EYES slot's own dot radius and is 0.0 for every body but a host wearing
## something in that square — under 갈래 ㄱ the slot ENLARGES the one nucleus instead of adding a second pair
## of marks, which is what keeps an internal slot changing a drawing VALUE rather than adding a shape.
func _outline_dot_r(r: float, bonus: float = 0.0) -> float:
	return maxf(r * (Look.OUTLINE_DOT_RING + bonus), Look.OUTLINE_DOT_MIN)


## **A square with its corners knocked off** — the shape the GDD asked for and the user asked for again
## after seeing circles. Eight points, built per call: cheaper than it looks against `draw_circle`, which
## tessellates a great many more.
##
## ⚠ **`corner` is an ARGUMENT, not `Look.CORNER` read in here.** Bone sharpens the host's corners, so it
## is a per-body value; read internally, a net could not pin a bare body's corner against a bone-wearing
## body's and the whole bone slot could change nothing with every check green.
func _blob(r: float, at: Vector2 = Vector2.ZERO, corner: float = Look.CORNER) -> PackedVector2Array:
	var k := r * corner
	return PackedVector2Array([
		at + Vector2(-r + k, -r), at + Vector2(r - k, -r),
		at + Vector2(r, -r + k), at + Vector2(r, r - k),
		at + Vector2(r - k, r), at + Vector2(-r + k, r),
		at + Vector2(-r, r - k), at + Vector2(-r, -r + k),
	])


## Two full circles — a MARKER, not a plain circle. Forwards to the leaf and draws nothing itself, so
## overriding `_paint_arc` sees both of them; a spy on this method would only learn that it was called.
##
## ⚠ **It carries no `width` argument, and it must not grow one back.** §E's arena wall briefly went through
## here for its own thickness, which drew its inner echo at `900 × 0.45` = 405px in the wall's colour across
## the middle of the boss fight. A caller that wants one circle at its own width calls `_paint_arc` — which
## is already a counted leaf — rather than widening this into two shapes behind one name.
func _paint_ring(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	_paint_arc(c, p, r, 0.0, TAU, col, RING_WIDTH)
	_paint_arc(c, p, r * 0.45, 0.0, TAU, col, RING_WIDTH)


## The only place `draw_arc` is called in this file. It takes the sweep as arguments because the `F` charge
## is a PARTIAL arc: a hook that only ever drew full circles could not carry the one value the wind-up is.
func _paint_arc(c: CanvasItem, p: Vector2, r: float, from: float, to: float, col: Color,
		width: float) -> void:
	c.draw_arc(p, r, from, to, RING_SEGMENTS, col, width, true)


## A filled wedge: apex at `p`, centred on `dir`, `range_px` long and `arc` radians wide. It takes range and
## arc as arguments so the net can assert the cone drawn is the cone `Swarm._bite()` tested. **The body's
## own fill is `_paint_cell_fill` since the fork was built, not `_paint_cell`** — that name is a dispatcher
## now and draws nothing.
func _paint_cone(c: CanvasItem, p: Vector2, dir: Vector2, range_px: float, arc: float,
		col: Color) -> void:
	var a0 := dir.angle() - arc * 0.5
	var pts := PackedVector2Array([p])
	for k in CONE_SEGMENTS + 1:
		var a := a0 + arc * (float(k) / float(CONE_SEGMENTS))
		pts.append(p + Vector2(cos(a), sin(a)) * range_px)
	c.draw_colored_polygon(pts, col)


## The only text this file has ever drawn. `draw_string` is native and Godot refuses to override it (parse
## error), so the leaf has to be ours and take the values as arguments.
##
## ⚠ **`ThemeDB.fallback_font`, not `get_theme_default_font()`** — this is a `Node2D` and that method is a
## `Control`'s. The fallback font tofus Korean, which is safe here and only here: every label this file
## draws is digits, a middle dot, or `?`.
##
## ⚠ **`p` arrives ALREADY CENTRED and the alignment is LEFT** — see `_label` for why passing CENTER here
## would silently do nothing.
func _paint_label(c: CanvasItem, p: Vector2, text: String, col: Color) -> void:
	c.draw_string(ThemeDB.fallback_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			Look.FORCE_LABEL_SIZE, col)


## Stretch along travel, squash across it. Cheap, and it is the entire difference between "squares slide"
## and "blobs move".
func _squash(v: Vector2, ref_speed: float) -> Vector2:
	var t := clampf(v.length() / maxf(1.0, ref_speed), 0.0, 1.4)
	return Vector2(1.0 + t * 0.18, 1.0 - t * 0.14)


func _heading(v: Vector2) -> float:
	return v.angle() if v.length_squared() > 1.0 else 0.0
