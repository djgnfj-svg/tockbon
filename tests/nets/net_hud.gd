extends RefCounted
## The live bank, swarm size and carried total — the three numbers the HUD shows during PLAY.
##
## It was measured by nothing: printing the bank as a literal `0` was green, because no net loaded `Hud`
## at all. A HUD that lies is worse than no HUD.
##
## `draw_string` is native and cannot be overridden, so `Hud` routes every readout through `_paint_text`
## and this net captures the strings that went to it.
##
## **The end-of-run panel (`_paint_result`) is gone from `hud.gd`** — the run shell plan replaced it with
## `EndingScreen`, whose own net (`net_screens.gd`) is where those four numbers are checked now.


class Spy extends Hud:
	var lines: Array[String] = []

	func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
		lines.append(text)
		super._paint_text(c, p, text, font_size, col)


func run(t) -> void:
	var w := World.new()
	w.setup(77)
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
	# A run opens with clones now; this check places its own swarm, so cut back to the host first.
	w.swarm.count = 1
	for i in 5:
		var k := w.swarm.add_clone()
		w.swarm.carried[k] = float(i)
	w.swarm.banked = 137.0

	var spy := Spy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.lines.clear()
	await t.pump_frames(1)

	t.ok(_has(spy.lines, "137"), "은행 숫자가 화면에 그대로 나온다 %s" % str(spy.lines))
	t.ok(_has(spy.lines, "무리 5"), "무리 수가 나온다")
	t.ok(_has(spy.lines, "지고 있는 것 10"), "무리가 지고 있는 것의 합(0+1+2+3+4)이 나온다")

	t.root.remove_child(spy)
	spy.queue_free()


func _has(lines: Array[String], needle: String) -> bool:
	for l: String in lines:
		if l.contains(needle):
			return true
	return false
