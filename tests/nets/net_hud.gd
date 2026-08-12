extends RefCounted
## The four numbers, as a player reads them.
##
## **Three of the four the experiment reports reach the screen through this file**, and it was measured by
## nothing: printing the bank as a literal `0` was green, because no net loaded `Hud` at all. A HUD that
## lies is worse than no HUD — the whole build exists to produce these numbers and have a person read them.
##
## `draw_string` is native and cannot be overridden, so `Hud` routes every readout through `_paint_text`
## and this net captures the strings that went to it.


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

	# The four end-of-run numbers. **Matched with their labels, and pinned to values that are not
	# substrings of each other.** A bare number match was measured worthless: swapping the clones-lost and
	# peak-swarm rows stayed green, and deleting the clones-lost row outright stayed green too, because
	# `"7"` was satisfied by the banked `"137"`. A player would read the swarm peak under "clones lost".
	w.clones_lost = 42
	w.cargo_lost = 23.0
	w.peak_swarm = 19
	w.over = true
	spy.lines.clear()
	await t.pump_frames(1)
	t.ok(_has(spy.lines, "모은 것 137"), "결과에 모은 것이 나온다 %s" % str(spy.lines))
	t.ok(_has(spy.lines, "잃은 분신 42"), "결과에 잃은 분신이 제 이름표를 달고 나온다")
	t.ok(_has(spy.lines, "같이 날아간 것 23"), "결과에 같이 날아간 화물이 나온다")
	t.ok(_has(spy.lines, "가장 컸을 때 19"), "결과에 가장 컸을 때가 나온다")

	t.root.remove_child(spy)
	spy.queue_free()


func _has(lines: Array[String], needle: String) -> bool:
	for l: String in lines:
		if l.contains(needle):
			return true
	return false
