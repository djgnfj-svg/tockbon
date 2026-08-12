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

var world: World = null
## What the camera can see, in world coordinates, padded. Everything outside is skipped — 500 food spots
## over nine screens is mostly off-camera at any moment.
var view_rect := Rect2(Vector2.ZERO, Rules.FIELD)

var _last_banked := 0.0
## Decays to zero; scales the host while it does. The harvest has to be visible without reading a number.
var _absorb_pop := 0.0


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

	if not world.swarm.rally.is_equal_approx(world.swarm.pos[0]):
		_paint_ring(c, world.swarm.rally, Look.RALLY_RADIUS, Look.RALLY_COLOR)

	var sw := world.swarm
	for i in range(1, sw.count):
		var p := sw.pos[i]
		if not view_rect.has_point(p):
			continue
		var load_t := clampf(sw.carried[i] / Look.CLONE_LOAD_FULL, 0.0, 1.0)
		var r: float = Look.CLONE_RADIUS * lerpf(1.0, Look.CLONE_LOAD_GROWTH, load_t)
		var col: Color = Look.CLONE_COLOR.lerp(Look.CLONE_LOADED_COLOR, load_t)
		_paint_cell(c, p, r, col, _squash(sw.vel[i], Rules.CLONE_SPEED_FOLLOW), _heading(sw.vel[i]))

	for k in world.pred_count:
		var p := world.pred_pos[k]
		if not view_rect.has_point(p):
			continue
		_paint_cell(c, p, Look.PREDATOR_RADIUS, Look.PREDATOR_COLOR, Vector2.ONE)

	var host_col: Color = Look.HOST_COLOR if world.host_grace <= 0.0 else Look.HOST_HURT_COLOR
	var host_r: float = Look.HOST_RADIUS * (1.0 + _absorb_pop * 0.35)
	_paint_cell(c, sw.pos[0], host_r, host_col, _squash(sw.vel[0], Rules.HOST_SPEED), _heading(sw.vel[0]))


## One body: a shadow ellipse under it, the body, and a lighter top edge. Depth comes from those three
## and from the squash, never from shaded art — the GDD's whole art claim rests on that being enough.
func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0) -> void:
	# The shadow does not rotate with the body — it lies on the ground, and rotating it is the tell that
	# turns a squashed blob back into a spinning sprite.
	c.draw_set_transform(p + Vector2(0.0, r * 0.62), 0.0, Vector2(squash.x, squash.y * 0.42))
	c.draw_circle(Vector2.ZERO, r, SHADOW)
	c.draw_set_transform(p, rot, squash)
	c.draw_circle(Vector2.ZERO, r, col)
	# Drawn unrotated, so the light stays overhead however the body is stretched. Lit from one direction
	# for every body in the scene — the GDD's one hard art rule, and it starts here.
	c.draw_set_transform(p, 0.0, Vector2.ONE)
	c.draw_circle(Vector2(0.0, -r * 0.3), r * 0.5, col.lightened(0.3))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_ring(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	c.draw_arc(p, r, 0.0, TAU, 28, col, 2.0, true)
	c.draw_arc(p, r * 0.45, 0.0, TAU, 18, col, 2.0, true)


## Stretch along travel, squash across it. Cheap, and it is the entire difference between "squares slide"
## and "blobs move".
func _squash(v: Vector2, ref_speed: float) -> Vector2:
	var t := clampf(v.length() / maxf(1.0, ref_speed), 0.0, 1.4)
	return Vector2(1.0 + t * 0.18, 1.0 - t * 0.14)


func _heading(v: Vector2) -> float:
	return v.angle() if v.length_squared() > 1.0 else 0.0
