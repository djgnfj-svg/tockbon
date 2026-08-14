class_name FieldView
extends Node2D
## Draws the world. Reads `world`, never writes it.
##
## **Everything is drawn from one `_draw()` on one node**, not from sixty nodes and not from a MultiMesh.
## MultiMesh is disqualified twice over: its per-instance state is invisible headless in 4.7.1 (transforms
## read back as identity, colours as black, `multimesh_get_buffer()` size 0, **and no error is raised**),
## and the full game needs clones that do not look alike.
##
## `_draw()` does nothing except call `_paint()`, and `_paint()` does nothing except call `_paint_cell()`
## per body. **That is not decoration — it is the only way a net can assert what was drawn.** Counting
## that `_draw()` ran measures the engine; `CLAUDE.md` records three features shipped that way in one day,
## each erasable with thousands of checks still green. A native call like `draw_circle` cannot be
## overridden (parse error), so the hook has to be a method of ours that takes the values as arguments.

const SHADOW := Color(0.0, 0.0, 0.0, 0.22)
## Tessellation, not appearance — the same class of number as `_blob()`'s eight points, and it stays here
## with them rather than in `look.gd`, which holds what a thing looks like and not how finely it is cut.
const RING_SEGMENTS := 28
const RING_WIDTH := 2.0
const CONE_SEGMENTS := 12

var world: World = null
## What the camera can see, in world coordinates, padded. Everything outside is skipped — 500 food spots
## over nine screens is mostly off-camera at any moment.
var view_rect := Rect2(Vector2.ZERO, Rules.FIELD)

var _last_banked := 0.0
## Decays to zero; scales the host while it does. The harvest has to be visible without reading a number.
var _absorb_pop := 0.0


## **Called by the shell every time a `World` is bound**, and the node outlives every run — `main.gd`
## builds one `FieldView` in `_ready()` and only re-points `world`. `_last_banked` is a high-water mark of
## the bank; carried into the next run it sits far above a fresh `banked` of 0, `banked > _last_banked` is
## false for the whole of run two, and the host stops scaling on eating. Nothing errors and the HUD bar
## still moves, so the screen does not even look dead — it just quietly stops rewarding every run after
## the first.
func reset_pop() -> void:
	_last_banked = 0.0
	_absorb_pop = 0.0


func _process(delta: float) -> void:
	if world == null:
		return
	if world.swarm.banked > _last_banked:
		_absorb_pop = minf(1.0, _absorb_pop + (world.swarm.banked - _last_banked) * 0.12)
		_last_banked = world.swarm.banked
	_absorb_pop = maxf(0.0, _absorb_pop - delta * 2.2)
	queue_redraw()


func _draw() -> void:
	_paint(self)


func _paint(c: CanvasItem) -> void:
	if world == null:
		return
	var food := world.food
	for i in food.pos.size():
		if food.alive[i] == 0:
			continue
		var p := food.pos[i]
		if not view_rect.has_point(p):
			continue
		_paint_cell(c, p, Look.FOOD_RADIUS, Look.FOOD_COLOR, Vector2.ONE)

	var sw := world.swarm
	# The marker for `3`, drawn only while somebody is actually on their way there. The guard used to be
	# `rally != pos[0]`, and rally is the host now — that condition would be false forever and the ring
	# would have disappeared with every net still green.
	if _striking(sw):
		_paint_ring(c, sw.strike_point, Look.STRIKE_RADIUS, Look.STRIKE_COLOR)

	for i in range(1, sw.count):
		var p := sw.pos[i]
		if not view_rect.has_point(p):
			continue
		var load_t := clampf(sw.carried[i] / Look.CLONE_LOAD_FULL, 0.0, 1.0)
		var r: float = Rules.CLONE_BODY_RADIUS * lerpf(1.0, Look.CLONE_LOAD_GROWTH, load_t)
		var col: Color = Look.CLONE_COLOR.lerp(Look.CLONE_LOADED_COLOR, load_t)
		_paint_cell(c, p, r, col, _squash(sw.vel[i], Rules.CLONE_SPEED_FOLLOW), _heading(sw.vel[i]))

	for k in world.critter_count:
		var p := world.critter_pos[k]
		if not view_rect.has_point(p):
			continue
		var prey := world.is_hunter_of(k)
		_paint_cell(c, p, world.critter_radius(k),
				Look.CRITTER_PREY_COLOR if prey else Look.CRITTER_COLOR,
				Vector2.ONE, _heading(world.critter_dir[k] * Rules.CRITTER_SPEED))

	# Under the host, so the body stays the thing being read. `bite_show` counts UP from the moment a bite
	# landed and opens at INF, so a run that has never bitten draws nothing without a second flag to keep
	# in sync. Shape comes from the two `Rules` constants `_bite()` itself tested with — a cone tuned here
	# to look right would be a picture of a hit that did not happen.
	if sw.bite_show < Look.BITE_SHOW_TIME:
		_paint_cone(c, sw.pos[0], sw.bite_aim, Rules.BITE_RANGE, Rules.BITE_ARC, Look.BITE_COLOR)

	var host_col: Color = Look.HOST_COLOR if world.host_grace <= 0.0 else Look.HOST_HURT_COLOR
	# The radius is a `Rules` constant, not a `Look` one: it decides who `V` absorbs. Drawing it from
	# anywhere else is how the picture stops being the simulation.
	var host_r: float = Rules.BODY_RADIUS * (1.0 + _absorb_pop * 0.35)
	_paint_cell(c, sw.pos[0], host_r, host_col, _squash(sw.vel[0], Rules.HOST_SPEED), _heading(sw.vel[0]))

	# The `F` wind-up, over the host. 0.45 seconds with nothing on screen is a key that reads as broken,
	# and the arc is the only feedback the hold has. Starts at the top and sweeps clockwise.
	if sw.split_charge > 0.0:
		var t := clampf(sw.split_charge / Rules.SPLIT_HOLD_TIME, 0.0, 1.0)
		_paint_arc(c, sw.pos[0], Rules.BODY_RADIUS * Look.SPLIT_CHARGE_RING,
				-PI * 0.5, -PI * 0.5 + TAU * t, Look.SPLIT_CHARGE_COLOR, Look.SPLIT_CHARGE_WIDTH)


## Is anybody on their way to the strike point. Asked of the swarm rather than remembered here — the view
## may not hold state the sim does not know about.
func _striking(sw: Swarm) -> bool:
	for i in range(1, sw.count):
		if sw.state[i] == Swarm.STRIKE:
			return true
	return false


## One body: a shadow ellipse under it, the body, and a lighter top edge. Depth comes from those three
## and from the squash, never from shaded art — the GDD's whole art claim rests on that being enough.
func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0) -> void:
	# The shadow does not rotate with the body — it lies on the ground, and rotating it is the tell that
	# turns a squashed blob back into a spinning sprite.
	c.draw_set_transform(p + Vector2(0.0, r * 0.62), 0.0, Vector2(squash.x, squash.y * 0.42))
	c.draw_colored_polygon(_blob(r), SHADOW)
	c.draw_set_transform(p, rot, squash)
	c.draw_colored_polygon(_blob(r), col)
	# Drawn unrotated, so the light stays overhead however the body is stretched. Lit from one direction
	# for every body in the scene — the GDD's one hard art rule, and it starts here.
	c.draw_set_transform(p, 0.0, Vector2.ONE)
	c.draw_colored_polygon(_blob(r * 0.52, Vector2(0.0, -r * 0.3)), col.lightened(0.28))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## **A square with its corners knocked off** — the shape the GDD asked for and the user asked for again
## after seeing circles. Eight points, built per call: cheaper than it looks against `draw_circle`, which
## tessellates a great many more.
func _blob(r: float, at: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var k := r * Look.CORNER
	return PackedVector2Array([
		at + Vector2(-r + k, -r), at + Vector2(r - k, -r),
		at + Vector2(r, -r + k), at + Vector2(r, r - k),
		at + Vector2(r - k, r), at + Vector2(-r + k, r),
		at + Vector2(-r, r - k), at + Vector2(-r, -r + k),
	])


## Two full circles. Forwards to the leaf and draws nothing itself, so overriding `_paint_arc` sees both
## of them — a spy on this method would only learn that it was called.
func _paint_ring(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	_paint_arc(c, p, r, 0.0, TAU, col, RING_WIDTH)
	_paint_arc(c, p, r * 0.45, 0.0, TAU, col, RING_WIDTH)


## The only place `draw_arc` is called in this file. It takes the sweep as arguments because the `F` charge
## is a PARTIAL arc: a hook that only ever drew full circles could not carry the one value the wind-up is.
func _paint_arc(c: CanvasItem, p: Vector2, r: float, from: float, to: float, col: Color,
		width: float) -> void:
	c.draw_arc(p, r, from, to, RING_SEGMENTS, col, width, true)


## A filled wedge: apex at `p`, centred on `dir`, `range_px` long and `arc` radians wide. The only place
## `draw_colored_polygon` is called outside `_paint_cell`, and it takes range and arc as arguments so the
## net can assert the cone drawn is the cone `Swarm._bite()` tested.
func _paint_cone(c: CanvasItem, p: Vector2, dir: Vector2, range_px: float, arc: float,
		col: Color) -> void:
	var a0 := dir.angle() - arc * 0.5
	var pts := PackedVector2Array([p])
	for k in CONE_SEGMENTS + 1:
		var a := a0 + arc * (float(k) / float(CONE_SEGMENTS))
		pts.append(p + Vector2(cos(a), sin(a)) * range_px)
	c.draw_colored_polygon(pts, col)


## Stretch along travel, squash across it. Cheap, and it is the entire difference between "squares slide"
## and "blobs move".
func _squash(v: Vector2, ref_speed: float) -> Vector2:
	var t := clampf(v.length() / maxf(1.0, ref_speed), 0.0, 1.4)
	return Vector2(1.0 + t * 0.18, 1.0 - t * 0.14)


func _heading(v: Vector2) -> float:
	return v.angle() if v.length_squared() > 1.0 else 0.0
