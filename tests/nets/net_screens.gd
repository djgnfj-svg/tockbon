extends RefCounted
## The title and ending screens, driven treed with real frames pumped — proven to draw, still not wired.
##
## Neither screen calls `get_tree().quit()` or reads `Input` itself; both only emit signals for the shell
## to act on.
##
## **The spies below capture ONLY `_paint_rect` and `_paint_text` — the two hooks both screens' files
## document as the only place `draw_rect`/`draw_string` are ever called.** Earlier drafts of this net
## captured `_paint_button`/`_paint_slot` instead, which only proves the hook was CALLED with the right
## arguments — a spy overriding a hook and appending before calling `super()` cannot see whether the base
## class's body, further down, actually drew anything. `if bg == BUTTON_BG_OFF: return` inside
## `_paint_button` passed every check built that way. Watching the two true leaves means nothing above
## them can put a pixel on screen without this net seeing it.
##
## **Position and font size are asserted, not just colour and rect.** A position or font size that is
## captured and never read back is exactly as unmeasured as not capturing it at all — `ROW_GAP` set to
## 3400 (five of six rows pushed off-screen) and `BUTTON_LABEL_INSET` set to (9999, 9999) both passed
## when only text VALUE and colour were checked.
##
## **Every rect and position is a LITERAL**, computed by hand from the 1280x720 headless viewport — never
## read back through `_rect_of()`/`_slot_rect_of()`, the functions that produced them, which move together
## with a bug in either.
##
## **Clicks are driven through the real hit test**, `root.push_input(ev, true)` — calling `_gui_input`
## directly skips `mouse_filter` entirely, so a Control silently set to `IGNORE` still passed. Every click
## check carries its own negative control (a click in empty space asserting nothing fired), because "the
## button correctly ignored a miss" and "the whole input pipeline is dead" observe identically otherwise.
## **`push_input(ev, false)` fires identically here, measured** — this project's headless viewport is
## 1280x720 and `get_visible_rect()` agrees, so there is no size mismatch for `in_local_coords` to correct.
## `true` is kept anyway because it is the honest, free choice for what this call means, not because
## coordinates would otherwise mangle in this project.


class TitleSpy extends TitleScreen:
	var rects: Array[Dictionary] = []
	var texts: Array[Dictionary] = []

	func _paint_rect(c: CanvasItem, r: Rect2, col: Color, filled: bool, width: float) -> void:
		rects.append({"r": r, "col": col, "filled": filled, "width": width})
		super._paint_rect(c, r, col, filled, width)

	func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
		texts.append({"p": p, "text": text, "font_size": font_size, "col": col})
		super._paint_text(c, p, text, font_size, col)


class EndingSpy extends EndingScreen:
	var rects: Array[Dictionary] = []
	var texts: Array[Dictionary] = []

	func _paint_rect(c: CanvasItem, r: Rect2, col: Color, filled: bool, width: float) -> void:
		rects.append({"r": r, "col": col, "filled": filled, "width": width})
		super._paint_rect(c, r, col, filled, width)

	func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
		texts.append({"p": p, "text": text, "font_size": font_size, "col": col})
		super._paint_text(c, p, text, font_size, col)


func run(t) -> void:
	# ================================================================
	# group 1 — the title screen
	# ================================================================
	var title := TitleSpy.new()
	t.root.add_child(title)
	await t.pump_frames(2)

	var vp: Vector2 = title.get_viewport().get_visible_rect().size
	t.eq(vp, Vector2(1280.0, 720.0), "설정: 헤드리스 뷰포트가 1280x720이다 (아래 리터럴이 이 값을 전제한다)")
	t.eq(title.size, vp, "타이틀이 화면 전체 크기를 갖는다")
	t.ok(title.size != Vector2.ZERO, "0 크기로 접혀 있지 않다")

	# Distinctness first — every colour-pair check below is meaningless if look.gd's two sides collapse
	# to the same value. `want`-style expected colours read out of `look.gd` (the file under test) is
	# exactly the shape that let BUTTON_BG_OFF := BUTTON_BG stay green in an earlier draft.
	t.ok(Look.BUTTON_BG != Look.BUTTON_BG_OFF, "설정: 활성/비활성 배경색이 서로 다르다")
	t.ok(Look.SCREEN_TEXT != Look.BUTTON_TEXT_OFF, "설정: 활성/비활성 글자색이 서로 다르다")

	# And the constants with no pair to be distinct FROM — BUTTON_EDGE and the two edge widths have
	# nothing to differ against, so a check that reads its expected value back out of the same constant
	# has zero defence if that constant itself drifts. Pinned to literals here, once: mutating
	# `BUTTON_EDGE` alone stayed green through every later check before this line existed, because every
	# one of them compared the drawn colour to `Look.BUTTON_EDGE` — the same value being tested.
	t.eq(Look.BUTTON_EDGE, Color(0.95, 0.85, 0.45), "설정: BUTTON_EDGE 값이 리터럴과 같다")
	t.eq(Look.BUTTON_EDGE_WIDTH, 2.0, "설정: BUTTON_EDGE_WIDTH 값이 리터럴과 같다")
	t.eq(Look.SLOT_EDGE_WIDTH, 1.0, "설정: SLOT_EDGE_WIDTH 값이 리터럴과 같다")
	t.eq(Look.SLOT_EMPTY, Color(0.2, 0.18, 0.17), "설정: SLOT_EMPTY 값이 리터럴과 같다")

	title.rects.clear()
	title.texts.clear()
	title.queue_redraw()
	await t.pump_frames(1)

	var buttons := [
		{"r": Rect2(500.0, 209.0, 280.0, 62.0), "bg": Look.BUTTON_BG, "text_col": Look.SCREEN_TEXT,
				"label_p": Vector2(524.0, 248.0), "label": "시작하기"},
		{"r": Rect2(500.0, 289.0, 280.0, 62.0), "bg": Look.BUTTON_BG_OFF, "text_col": Look.BUTTON_TEXT_OFF,
				"label_p": Vector2(524.0, 328.0), "label": "도감"},
		{"r": Rect2(500.0, 369.0, 280.0, 62.0), "bg": Look.BUTTON_BG_OFF, "text_col": Look.BUTTON_TEXT_OFF,
				"label_p": Vector2(524.0, 408.0), "label": "설정"},
		{"r": Rect2(500.0, 449.0, 280.0, 62.0), "bg": Look.BUTTON_BG, "text_col": Look.SCREEN_TEXT,
				"label_p": Vector2(524.0, 488.0), "label": "종료"},
	]
	for k in 4:
		var w: Dictionary = buttons[k]
		var fill: Variant = _find_rect(title.rects, w["r"], true)
		t.ok(fill != null and fill["col"] == w["bg"], "%d번 버튼 배경이 그 자리, 그 색으로 그려졌다" % k)
		var edge: Variant = _find_rect(title.rects, w["r"], false)
		t.ok(edge != null and edge["col"] == Look.BUTTON_EDGE and edge["width"] == Look.BUTTON_EDGE_WIDTH,
				"%d번 버튼 테두리가 그 자리, 그 두께로 그려졌다" % k)
		var lbl: Variant = _find_text(title.texts, w["label_p"])
		t.ok(lbl != null and lbl["text"] == w["label"] and lbl["font_size"] == 28
				and lbl["col"] == w["text_col"], "%d번 버튼 이름표가 그 위치, 그 글꼴 크기, 그 색으로 나온다" % k)

	t.eq(title.rects.size(), 9, "배경 하나 + 버튼 넷의 배경·테두리, 그 이상도 이하도 그려지지 않는다")
	t.eq(title.texts.size(), 4, "버튼 이름표 넷, 그 이상도 이하도 그려지지 않는다")

	# The full-screen background rect is already IN `title.rects` (it is one of the 9 counted above) and
	# already covered by nothing — the count alone passes at any colour, including magenta, or with
	# `filled=false` (a black screen with one thin outline). Pinned here, by value.
	# Pinned to a literal, not `Look.TITLE_BG` read back — the same self-reference the earlier constants
	# fell into. Once, here; the draw check below can then safely read `Look.TITLE_BG`.
	t.eq(Look.TITLE_BG, Color(0.07, 0.05, 0.05), "설정: TITLE_BG 값 자체가 리터럴과 같다")
	var bg: Variant = _find_rect(title.rects, Rect2(Vector2.ZERO, vp), true)
	t.ok(bg != null and bg["col"] == Look.TITLE_BG, "타이틀 배경이 그 색으로, 채워져서 그려진다")

	# -- clicks, through the real hit test, each with its own negative control ---------------------
	var sig := {"start": false, "quit": false}
	title.start_pressed.connect(func(): sig["start"] = true)
	title.quit_pressed.connect(func(): sig["quit"] = true)

	t.root.push_input(_click_at(Rect2(500.0, 209.0, 280.0, 62.0).get_center()), true)
	await t.pump_frames(1)
	t.ok(sig["start"], "0번(시작하기)을 실제 클릭 경로로 누르면 start_pressed가 나간다")

	sig["start"] = false
	t.root.push_input(_click_at(Rect2(500.0, 289.0, 280.0, 62.0).get_center()), true)
	await t.pump_frames(1)
	t.ok(not sig["start"] and not sig["quit"], "1번(도감)을 눌러도 아무 신호도 나가지 않는다")

	t.root.push_input(_click_at(Rect2(500.0, 449.0, 280.0, 62.0).get_center()), true)
	await t.pump_frames(1)
	t.ok(sig["quit"] and not sig["start"], "3번(종료)을 누르면 quit_pressed만 나간다 (start_pressed 아님)")

	sig["quit"] = false
	t.root.push_input(_click_at(Vector2(20.0, 20.0)), true)
	await t.pump_frames(1)
	t.ok(not sig["start"] and not sig["quit"],
			"부정 대조: 버튼이 하나도 없는 빈 자리를 눌러도 아무 신호도 나가지 않는다")

	t.root.remove_child(title)
	title.queue_free()

	# ================================================================
	# group 2 — the ending screen
	# ================================================================
	var ending := EndingSpy.new()
	t.root.add_child(ending)
	await t.pump_frames(2)

	t.eq(ending.size, vp, "엔딩도 화면 전체 크기를 갖는다")
	t.ok(ending.size != Vector2.ZERO, "엔딩도 0 크기로 접혀 있지 않다")
	# Pinned on its own: the "differs" check further down cannot catch both sides drifting to the same
	# wrong colour together.
	t.eq(Look.ENDING_CLEARED, Color(0.95, 0.85, 0.45), "설정: ENDING_CLEARED 값 자체가 리터럴과 같다")
	t.eq(Look.ENDING_DIED, Color(0.85, 0.35, 0.32), "설정: ENDING_DIED 값 자체가 리터럴과 같다")

	# -- a CLEARED run: headline, buttons and the eleven slots, all from one capture ----------------
	var r_cleared := RunResult.new()
	r_cleared.outcome = Run.Outcome.CLEARED
	ending.result = r_cleared
	ending.rects.clear()
	ending.texts.clear()
	ending.queue_redraw()
	await t.pump_frames(1)

	# Guarded with `if`, not just `!= null` folded into the same line: a missing headline must fail this
	# ONE check, not crash the rest of the net on the next line's unguarded index and lose every check
	# after it (buttons, slots, the DIED headline, both click groups, rows 15/15b) to a single draw call.
	var head_cleared: Variant = _find_text(ending.texts, Vector2(420.0, 90.0))
	t.ok(head_cleared != null, "클리어 헤드라인이 그 위치에 실제로 그려졌다")
	if head_cleared != null:
		t.eq(head_cleared["text"], "보스를 삼켰다", "클리어 헤드라인 문구가 맞다")
		t.eq(head_cleared["font_size"], 40, "헤드라인 글꼴 크기가 40이다")
		t.eq(head_cleared["col"], Look.ENDING_CLEARED, "클리어 헤드라인 색이 맞다")

	var e_buttons := [
		{"r": Rect2(351.0, 600.0, 280.0, 62.0), "label_p": Vector2(375.0, 639.0), "label": "다시 하기"},
		{"r": Rect2(649.0, 600.0, 280.0, 62.0), "label_p": Vector2(673.0, 639.0), "label": "타이틀로"},
	]
	for k in 2:
		var w: Dictionary = e_buttons[k]
		var fill: Variant = _find_rect(ending.rects, w["r"], true)
		t.ok(fill != null and fill["col"] == Look.BUTTON_BG, "엔딩 %d번 버튼 배경이 그 자리, 그 색으로 그려졌다" % k)
		var edge: Variant = _find_rect(ending.rects, w["r"], false)
		t.ok(edge != null and edge["col"] == Look.BUTTON_EDGE and edge["width"] == Look.BUTTON_EDGE_WIDTH,
				"엔딩 %d번 버튼 테두리가 그 자리, 그 두께로 그려졌다" % k)
		var lbl: Variant = _find_text(ending.texts, w["label_p"])
		t.ok(lbl != null and lbl["text"] == w["label"] and lbl["font_size"] == 28
				and lbl["col"] == Look.SCREEN_TEXT, "엔딩 %d번 버튼 이름표가 그 위치, 그 글꼴 크기, 그 색으로 나온다" % k)

	var slot0_fill: Variant = _find_rect(ending.rects, Rect2(391.0, 500.0, 38.0, 38.0), true)
	t.ok(slot0_fill != null and slot0_fill["col"] == Look.SLOT_EMPTY, "0번 칸 배경이 그 자리, 그 색으로 그려졌다")
	var slot0_edge: Variant = _find_rect(ending.rects, Rect2(391.0, 500.0, 38.0, 38.0), false)
	t.ok(slot0_edge != null and slot0_edge["col"] == Look.BUTTON_EDGE and slot0_edge["width"] == Look.SLOT_EDGE_WIDTH,
			"0번 칸 테두리가 그 자리, 그 두께로 그려졌다")
	t.ok(_find_rect(ending.rects, Rect2(851.0, 500.0, 38.0, 38.0), true) != null,
			"10번 칸 배경이 그 자리에 그려졌다")
	t.eq(_count_sized(ending.rects, Vector2(38.0, 38.0)), 22, "칸 11개의 배경·테두리, 그 이상도 이하도 그려지지 않는다")

	# rows, by position AND font size, from this same capture — value-by-value comes later at check 15
	var row0: Variant = _find_text(ending.texts, Vector2(420.0, 146.0))
	t.ok(row0 != null, "0번째 줄(걸린 시간)이 제 위치에 그려졌다")
	if row0 != null:
		t.eq(row0["font_size"], 24, "0번째 줄 글꼴 크기가 24다")
	var row5: Variant = _find_text(ending.texts, Vector2(420.0, 146.0 + 5.0 * 34.0))
	t.ok(row5 != null, "5번째 줄(같이 날아간 것)이 제 위치에 그려졌다")

	# The full-screen dim rect — inherited from `hud.gd`'s `OVER_DIM`, the whole reason a frozen field
	# behind the ending doesn't read as still-live. Deleting the `_paint_rect` call for it, or drawing it
	# in the wrong colour, changed nothing the checks above measure: none of them count total rects or
	# read the dim rect's own colour. Both are pinned here — the constant to a literal first, same reason
	# as `TITLE_BG` above.
	t.eq(Look.ENDING_DIM, Color(0.04, 0.03, 0.03, 0.86), "설정: ENDING_DIM 값 자체가 리터럴과 같다")
	var dim: Variant = _find_rect(ending.rects, Rect2(Vector2.ZERO, vp), true)
	t.ok(dim != null and dim["col"] == Look.ENDING_DIM, "엔딩 배경이 그 색으로, 채워져서 그려진다")
	# 1 dim + 11칸×2(배경·테두리) + 2버튼×2(배경·테두리) = 27. 9 = 헤드라인 1 + 줄 6 + 버튼 이름표 2.
	t.eq(ending.rects.size(), 27, "엔딩 사각형 27개, 그 이상도 이하도 그려지지 않는다")
	t.eq(ending.texts.size(), 9, "엔딩 글자 9개, 그 이상도 이하도 그려지지 않는다")

	# -- a DIED run: only the headline needs re-checking here ---------------------------------------
	var r_died := RunResult.new()
	r_died.outcome = Run.Outcome.DIED
	ending.result = r_died
	ending.texts.clear()
	ending.queue_redraw()
	await t.pump_frames(1)
	var head_died: Variant = _find_text(ending.texts, Vector2(420.0, 90.0))
	t.ok(head_died != null, "죽음 헤드라인이 그 위치에 실제로 그려졌다")
	if head_died != null:
		t.eq(head_died["text"], "먹혔다", "죽음 헤드라인 문구가 맞다")
		t.eq(head_died["col"], Look.ENDING_DIED, "죽음 헤드라인 색이 맞다")

	if head_cleared != null and head_died != null:
		t.ok(head_cleared["text"] != head_died["text"], "헤드라인 문구가 승패에 따라 다르다")
		t.ok(head_cleared["col"] != head_died["col"], "헤드라인 색도 승패에 따라 다르다")

	# -- a filled slot actually draws its label ------------------------------------------------------
	# ⚠ **A PART name in the square a part actually takes.** This fixture said `까마귀` in slot 0 — a
	# SPECIES name in the head square — and `Run._snapshot()` fills `body_slots` from `Parts.NAME`, so it
	# was asserting a string no run could ever produce. 말 다리 in the hindlimb square is one a real run
	# does: 391 + 4×46 = 575, plus `SLOT_LABEL_INSET` (4, 30).
	var r_slot := RunResult.new()
	r_slot.outcome = Run.Outcome.CLEARED
	var slots := PackedStringArray()
	slots.resize(11)
	slots[Parts.Slot.HINDLIMBS] = "말 다리"
	r_slot.body_slots = slots
	ending.result = r_slot
	ending.texts.clear()
	ending.queue_redraw()
	await t.pump_frames(1)
	var slot_label: Variant = _find_text(ending.texts, Vector2(579.0, 530.0))
	t.ok(slot_label != null and slot_label["text"] == "말 다리" and slot_label["font_size"] == 12,
			"칸이 채워지면 그 이름이 그 위치, 그 글꼴 크기로 그려진다 %s" % [_dump(ending.texts)])
	# The other ten squares stay label-less: a screen that prints the same name in every square would pass
	# the line above on its own.
	t.eq(ending.texts.size(), 10, "채워진 칸 하나만 이름을 적는다 (헤드라인 1 + 줄 6 + 버튼 2 + 칸 1)")

	# -- restart_pressed / title_pressed, through the real hit test, and never swapped --------------
	# Each assertion checks the RIGHT signal fired AND the WRONG one did not — a swap (다시 하기 emitting
	# title_pressed) would still make "something fired" true, and only the paired negative half catches it.
	var esig := {"restart": false, "title": false}
	ending.restart_pressed.connect(func(): esig["restart"] = true)
	ending.title_pressed.connect(func(): esig["title"] = true)

	t.root.push_input(_click_at(Rect2(351.0, 600.0, 280.0, 62.0).get_center()), true)
	await t.pump_frames(1)
	t.ok(esig["restart"] and not esig["title"], "다시 하기를 누르면 restart_pressed만 나간다 (title_pressed 아님)")

	esig["restart"] = false
	t.root.push_input(_click_at(Rect2(649.0, 600.0, 280.0, 62.0).get_center()), true)
	await t.pump_frames(1)
	t.ok(esig["title"] and not esig["restart"], "타이틀로를 누르면 title_pressed만 나간다 (restart_pressed 아님)")

	esig["title"] = false
	t.root.push_input(_click_at(Vector2(20.0, 20.0)), true)
	await t.pump_frames(1)
	t.ok(not esig["restart"] and not esig["title"], "부정 대조: 빈 자리를 눌러도 아무 신호도 나가지 않는다")

	# -- 15: the seven rows, matched with their labels, by value --------
	# `net_hud.gd`'s own comment records why a bare number match is worthless: swapping two rows stayed
	# green, and deleting one outright stayed green too, because a shorter number was a substring of a
	# longer one. None of the values below are substrings of one another.
	var r15 := RunResult.new()
	r15.outcome = Run.Outcome.CLEARED
	r15.elapsed = 125.0
	r15.experience = 311
	r15.species = PackedStringArray(["까마귀", "말"])
	r15.peak_swarm = 47
	r15.clones_lost = 13
	r15.cargo_lost = 29
	ending.result = r15
	ending.texts.clear()
	ending.queue_redraw()
	await t.pump_frames(1)
	t.ok(_has(ending.texts, "걸린 시간 2:05"), "걸린 시간이 라벨과 함께 나온다 %s" % [_dump(ending.texts)])
	t.ok(_has(ending.texts, "먹은 경험치 311"), "먹은 경험치가 라벨과 함께 나온다")
	t.ok(_has(ending.texts, "먹은 종 까마귀, 말"), "먹은 종이 라벨과 함께 나온다")
	t.ok(_has(ending.texts, "최대 무리 47"), "최대 무리가 라벨과 함께 나온다")
	t.ok(_has(ending.texts, "잃은 클론 13"), "잃은 클론이 라벨과 함께 나온다")
	t.ok(_has(ending.texts, "같이 날아간 것 29"), "같이 날아간 것이 라벨과 함께 나온다")

	# -- 15b: nothing eaten reads as 없음, not a blank line -------------
	var r15b := RunResult.new()
	r15b.outcome = Run.Outcome.DIED
	r15b.species = PackedStringArray()
	ending.result = r15b
	ending.texts.clear()
	ending.queue_redraw()
	await t.pump_frames(1)
	t.ok(_has(ending.texts, "먹은 종 없음"), "먹은 종이 비어 있으면 없음이라고 나온다")

	# -- 15c: the same line, off a REAL run instead of a hand-built result ------------------------------
	# ⚠ **Everything above feeds this screen a `RunResult` written by hand**, so the path
	# `World.species_eaten → Run._snapshot() → RunResult.species → this string` was cut in the middle: the
	# snapshot's own loop is driven in `net_run`, and the screen is driven here, and nothing joined them.
	#
	# **Horse first on purpose.** The expected order is NOT the enum's own (CROW is 0), so a snapshot that
	# read `Parts.SPECIES_NAME` straight through instead of walking `species_eaten` would come back
	# "까마귀, 말" and look perfectly right.
	var real := Run.new()
	real.start(35)
	for i in real.world.food.alive.size():
		real.world.food.alive[i] = 0
	real.world.food.alive_count = 0
	real.world.critter_count = 0
	real.world.boss_index = -1
	_finish_corpse(real, Parts.Species.HORSE, 35)
	# A finished horse pays 105 경험치, which banks a level, which rolls an offer — and `World.step()`
	# refuses to advance while cards are on screen. Cleared by hand or the second meal never starts.
	real.world.pending_levels = 0
	real.world.offer = PackedInt32Array()
	_finish_corpse(real, Parts.Species.CROW, 10)
	t.eq(real.world.species_eaten.size(), 2, "설정: 말과 까마귀를 그 순서로 실제로 다 먹었다")
	real.world.host_hp = 0
	real.step(1.0 / 60.0)
	t.eq(real.phase, Run.Phase.ENDING, "설정: 그 런이 실제로 끝났다")
	ending.result = real.result
	ending.texts.clear()
	ending.queue_redraw()
	await t.pump_frames(1)
	t.ok(_has(ending.texts, "먹은 종 말, 까마귀"),
			"진짜 런에서 먹은 종이 먹은 순서 그대로 화면에 나온다 %s" % [_dump(ending.texts)])

	t.root.remove_child(ending)
	ending.queue_free()


## Seed one corpse under the host and step the run to completion. 0.999, never 0.99: a meal is
## `corpse_force × EAT_TIME_PER_FORCE`, so a horse is 1.75s and one frame at 0.99 adds 0.019 and finishes
## nothing at all — the check would then measure an empty list and read as a bug in the snapshot.
##
## ⚠ §C floors every corpse at `CORPSE_BITES_MIN` (3) bites regardless of `corpse_progress`, so a single
## `step()` no longer finishes it — this loops until the corpse is actually gone.
func _finish_corpse(r: Run, species: int, force_value: int) -> void:
	r.world.corpse_count = 1
	r.world.corpse_pos[0] = r.world.swarm.pos[0]
	r.world.corpse_species[0] = species
	r.world.corpse_force[0] = force_value
	r.world.corpse_bites_left[0] = r.world._bites_for(force_value)
	r.world.corpse_progress[0] = 0.999
	var n := 0
	while r.world.corpse_count > 0 and n < 500:
		r.step(1.0 / 60.0)
		# A level banked on a non-final bite must not freeze the meal behind its own card panel — cleared
		# only while still eating, so a caller's second meal cannot get stuck behind the first's pool.
		if r.world.corpse_count > 0:
			r.world.pending_levels = 0
			r.world.offer = PackedInt32Array()
		n += 1


func _click_at(p: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = p
	return ev


## Returns the FIRST captured rect entry matching both the literal rect and the fill/outline flag, or
## null. Filled and outline draws share the same `r`, so the flag disambiguates a button's background
## from its edge.
func _find_rect(rects: Array[Dictionary], r: Rect2, filled: bool) -> Variant:
	for e: Dictionary in rects:
		if e["r"] == r and e["filled"] == filled:
			return e
	return null


func _find_text(texts: Array[Dictionary], p: Vector2) -> Variant:
	for e: Dictionary in texts:
		if e["p"] == p:
			return e
	return null


func _count_sized(rects: Array[Dictionary], sz: Vector2) -> int:
	var n := 0
	for e: Dictionary in rects:
		if e["r"].size == sz:
			n += 1
	return n


func _has(texts: Array[Dictionary], needle: String) -> bool:
	for e: Dictionary in texts:
		if (e["text"] as String).contains(needle):
			return true
	return false


func _dump(texts: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in texts:
		out.append(e["text"])
	return out
