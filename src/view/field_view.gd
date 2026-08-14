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
## Limb pairs and eye dots are drawn once per side. **Only one side's offset is written in `look.gd`** —
## the sign is derived, so a pair cannot be tuned into asymmetry by editing one of two constants.
const MIRROR := [1.0, -1.0]

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
	# in sync. **Shape comes off the swarm, which stored what `bite()` itself tested with** — a cone tuned
	# here to look right would be a picture of a hit that did not happen, and a constant would be one part's
	# cone drawn over another part's hit now that range and arc belong to the part that fired.
	if sw.bite_show < Look.BITE_SHOW_TIME:
		_paint_cone(c, sw.pos[0], sw.bite_aim, sw.bite_range, sw.bite_arc, Look.BITE_COLOR)

	var host_col: Color = Look.HOST_COLOR if world.host_grace <= 0.0 else Look.HOST_HURT_COLOR
	# The radius is a `Rules` constant, not a `Look` one: it decides who `V` absorbs. Drawing it from
	# anywhere else is how the picture stops being the simulation.
	var host_r: float = Rules.BODY_RADIUS * (1.0 + _absorb_pop * 0.35)
	# **The host, and only the host, goes through `_paint_body`.** A clone has no `Body` — it carries one
	# part index (plan 4) — so it keeps the bare `_paint_cell` above.
	var b := world.body
	_paint_body(c, sw.pos[0], host_r, host_col, _squash(sw.vel[0], Rules.HOST_SPEED), _heading(sw.vel[0]),
			_body_corner(b), _body_outline_width(b), _body_colour_depth(b), _body_dot_radius(b),
			b.slot_part)

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
	if outline_width > 0.0:
		_paint_outline(c, p, r, corner, body_col.darkened(Look.HIDE_OUTLINE_DARKEN), outline_width)

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


## Hide/fur's outline, traced around the body's own silhouette so it cannot drift from it.
func _paint_outline(c: CanvasItem, p: Vector2, r: float, corner: float, col: Color,
		width: float) -> void:
	var pts := _blob(r, p, corner)
	pts.append(pts[0])
	c.draw_polyline(pts, col, width)


## The eye dots. The only place `draw_circle` is called in this file.
func _paint_dot(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	c.draw_circle(p, r, col)


## One body: a shadow ellipse under it, the body, and a lighter top edge. Depth comes from those three
## and from the squash, never from shaded art — the GDD's whole art claim rests on that being enough.
##
## `corner` defaults to `Look.CORNER` because a clone, a crumb and a critter have no `Body` and no bone
## slot; only the host's corner ever moves.
func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0,
		corner: float = Look.CORNER) -> void:
	# The shadow does not rotate with the body — it lies on the ground, and rotating it is the tell that
	# turns a squashed blob back into a spinning sprite.
	c.draw_set_transform(p + Vector2(0.0, r * 0.62), 0.0, Vector2(squash.x, squash.y * 0.42))
	c.draw_colored_polygon(_blob(r, Vector2.ZERO, corner), SHADOW)
	c.draw_set_transform(p, rot, squash)
	c.draw_colored_polygon(_blob(r, Vector2.ZERO, corner), col)
	# Drawn unrotated, so the light stays overhead however the body is stretched. Lit from one direction
	# for every body in the scene — the GDD's one hard art rule, and it starts here.
	c.draw_set_transform(p, 0.0, Vector2.ONE)
	c.draw_colored_polygon(_blob(r * 0.52, Vector2(0.0, -r * 0.3), corner), col.lightened(0.28))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
