extends RefCounted
## What actually reached the screen.
##
## **"`_draw()` ran" is not "anything was drawn."** `CLAUDE.md` records three features shipped on that
## confusion in a single day, each erasable with thousands of checks still green — and a pure position
## function asserted correct while `_draw()` passed a bare `Rect2()` at the call site, painting at zero
## size. Godot refuses to override a native draw call, so `FieldView` cuts a `_paint_cell()` hook out of
## `_draw()` and this net overrides that and captures every argument.
##
## Driven **treed, with real frames pumped** — calling `_draw()` by hand barks about drawing outside
## NOTIFICATION_DRAW, and a node outside the tree has no viewport to draw into at all.


class Spy extends FieldView:
	var seen: Array = []

	func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0) -> void:
		seen.append({"p": p, "r": r, "col": col})
		super._paint_cell(c, p, r, col, squash, rot)


func run(t) -> void:
	var w := World.new()
	w.setup(9)
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
	# Three food at pinned coordinates near the host, so the expected draw count is a number and not a
	# function of the spawner's randomness.
	var host: Vector2 = w.swarm.pos[0]
	for i in 3:
		w.food.pos[i] = host + Vector2(40.0 + i * 20.0, 0.0)
		w.food.alive[i] = 1
	w.food.alive_count = 3
	for i in 4:
		var k := w.swarm.add_clone()
		w.swarm.pos[k] = host + Vector2(-60.0 - i * 25.0, 30.0)

	var spy := Spy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	# Cleared and re-pumped: the node draws once per frame it is asked to, so a multi-frame capture would
	# hold two passes and the count assertion below would be measuring frames, not bodies.
	spy.seen.clear()
	await t.pump_frames(1)

	var expect := 1 + w.swarm.count - 1 + w.food.alive_count + w.pred_count
	t.eq(spy.seen.size(), expect, "호스트·분신·먹이·포식자가 전부 그려졌다")

	# The captured position must EQUAL the simulation's, not merely be non-zero: passing Vector2.ZERO for
	# every body is the exact mutation this check exists to catch, and a count-only assertion survives it.
	var host_hit := false
	for e: Dictionary in spy.seen:
		if e["p"] == w.swarm.pos[0] and e["r"] >= Look.HOST_RADIUS:
			host_hit = true
	t.ok(host_hit, "호스트를 sim 의 좌표 그대로 그렸다")

	var clone_points := {}
	for i in range(1, w.swarm.count):
		for e: Dictionary in spy.seen:
			if e["p"] == w.swarm.pos[i]:
				clone_points[e["p"]] = true
	t.eq(clone_points.size(), w.swarm.count - 1, "분신 넷이 서로 다른 자리에 그려졌다")

	var zeros := 0
	for e: Dictionary in spy.seen:
		if e["p"] == Vector2.ZERO or e["r"] <= 0.0:
			zeros += 1
	t.eq(zeros, 0, "0 좌표나 0 크기로 그려진 것이 없다")

	# A loaded clone is visibly bigger — the one readability requirement in this build, and the only way
	# an abandoned harvest reads as a loss without a number on screen.
	w.swarm.carried[1] = Look.CLONE_LOAD_FULL
	spy.seen.clear()
	await t.pump_frames(1)
	var loaded_r := 0.0
	var empty_r := 0.0
	for e: Dictionary in spy.seen:
		if e["p"] == w.swarm.pos[1]:
			loaded_r = e["r"]
		elif e["p"] == w.swarm.pos[2]:
			empty_r = e["r"]
	t.ok(loaded_r > empty_r, "실은 분신이 빈 분신보다 크게 그려진다 (%.1f > %.1f)" % [loaded_r, empty_r])

	t.root.remove_child(spy)
	spy.queue_free()
