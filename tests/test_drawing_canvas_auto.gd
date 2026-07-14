extends SceneTree
## 모듈 A 캔버스 계층 자동 검증 — DrawingCanvas에 합성 획을 주입해
## 캡처 → 인식 → SpellDesign 생성 → EventBus 발신 → 취소/자동보정/스탬프를 검사한다.
## 실행: Godot --headless --path . -s res://tests/test_drawing_canvas_auto.gd
## (오토로드 EventBus가 필요하므로 첫 process_frame 이후에 실행한다)

const DrawingCanvas := preload("res://src/drawing/drawing_canvas.gd")

var _pass := 0
var _fail := 0
var _created := 0
var _updated := 0
var _last_recog: Array = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: ", name)


func _on_created(_d: SpellDesign) -> void:
	_created += 1


func _on_updated(_d: SpellDesign) -> void:
	_updated += 1


func _on_recog(role: int, matched: bool, score: float) -> void:
	_last_recog = [role, matched, score]


func _run() -> void:
	# -s 모드에선 오토로드가 없을 수 있으므로 EventBus를 수동 인스턴스화 (core 파일 수정 아님)
	var bus: Node = root.get_node_or_null(^"EventBus")
	if bus == null:
		bus = (load("res://src/core/event_bus.gd") as GDScript).new()
		bus.name = "EventBus"
		root.add_child(bus)
	bus.connect(&"design_created", _on_created)
	bus.connect(&"design_updated", _on_updated)
	bus.connect(&"recognition_result", _on_recog)

	var canvas: Control = DrawingCanvas.new()
	canvas.size = Vector2(320, 320)
	root.add_child(canvas)

	var c := Vector2(0.5, 0.5)
	# 1. 원
	_feed(canvas, _circle_pts(c, 0.22))
	_check(_last_recog.size() == 3 and int(_last_recog[0]) == Enums.StrokeRole.CIRCLE,
		"원 획 → recognition_result CIRCLE")
	# 2. 작성 순서 강제 (TECH_SPEC §6.2) — 진 다음은 룬이다. 문양을 먼저 그으면 무효다.
	# (v1.6에서 조준 꼬리가 폐지됐다 — 이 자리에 있던 TAIL 검사는 그때 죽은 계약이었다)
	var before := int(canvas.get_summary().stroke_count)
	_feed(canvas, _line_pts(c, c + Vector2(0.0, -0.38)))
	_check(int(canvas.get_summary().stroke_count) == before,
		"순서 위반(룬 차례에 문양) → 획 무효")
	_check(canvas.get_stage() == Enums.DrawStage.RUNE, "단계는 여전히 룬")
	# 3. 룬 (불△)
	_feed(canvas, _triangle_pts(c, 0.10))
	_check(int(_last_recog[0]) == Enums.StrokeRole.RUNE, "삼각 획 → RUNE")
	_check(canvas.get_design() == null, "화살표 전에는 미완성")
	# 4. 화살표 → 완성
	_feed(canvas, _line_pts(c, c + Vector2(0.18, 0.0)))
	_check(_created == 1, "design_created 1회 발신")
	var d: SpellDesign = canvas.get_design()
	_check(d != null, "도안 생성됨")
	if d != null:
		_check(d.circle_type == Enums.CircleType.AIMED, "조준진")
		_check(d.rune_type == Enums.RuneType.FIRE, "룬 FIRE")
		_check(d.arrows.size() == 1, "화살표 1")
		_check(int(d.ink_cost.get(&"ink_basic", 0)) > 0, "잉크 > 0")
	# 5. 화살표 추가 → design_updated
	_feed(canvas, _line_pts(c, c + Vector2(0.0, -0.18)))
	_check(_updated >= 1, "design_updated 발신")
	_check(canvas.get_design().arrows.size() == 2, "화살표 2")
	# 6. 취소(undo) → 화살표 1
	canvas.undo_last()
	_check(canvas.get_design() != null and canvas.get_design().arrows.size() == 1,
		"undo 후 화살표 1")
	# 7. 자동보정 — 정확도 유지
	var acc_before: float = canvas.get_design().rune_accuracy
	_check(canvas.autocorrect_rune(), "자동보정 실행됨")
	_check(is_equal_approx(canvas.get_design().rune_accuracy, acc_before),
		"자동보정 후 정확도 유지")
	# 8. 스탬프 저장·배치 — 저장 시점 정확도 보존
	var stamp: Dictionary = canvas.save_rune_stamp()
	_check(not stamp.is_empty() and int(stamp.rune_type) == Enums.RuneType.FIRE, "스탬프 저장")
	canvas.begin_stamp_placement(stamp)
	canvas._place_stamp_at(Vector2(120, 200))
	var d2: SpellDesign = canvas.get_design()
	_check(d2 != null and d2.rune_type == Enums.RuneType.FIRE, "스탬프 배치 후에도 룬 유지")
	if d2 != null:
		var balance := load("res://data/balance.tres") as BalanceData
		var expected := clampf(maxf(float(stamp.score), balance.accuracy_floor), 0.0, 1.0)
		_check(is_equal_approx(d2.rune_accuracy, expected), "스탬프 정확도 보존")
	# 9. 전체 지우기
	canvas.clear_all()
	_check(canvas.get_design() == null, "지우기 후 도안 없음")

	# 10. 종이 확대 (v1.7)
	_test_zoom(canvas)

	print("──────────────────────────────")
	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("DRAWING_CANVAS_AUTO_OK")
	quit(0 if _fail == 0 else 1)


# ─────────────────────────── 종이 확대 (v1.7) ───────────────────────────

## **핵심 불변식: 확대해서 그려도 저장되는 획은 똑같다.**
## 확대는 보는 배율만 바꾼다 — 인식·잉크·발사는 배율을 몰라야 한다.
## 그래서 여기서는 내부 API(_begin_stroke)가 아니라 **실제 마우스 이벤트(화면 좌표)**를 주입한다.
## 내부 API로 검사하면 좌표 변환 버그를 통째로 못 본다 (세션 7의 "중간 표현만 봤다" 교훈).
func _test_zoom(canvas: Control) -> void:
	canvas.clear_all()
	_check(is_equal_approx(canvas.get_zoom(), 1.0), "새 종이는 배율 1.0")

	# (a) 배율 1.0에서 화면 좌표로 그린 획 — 기준
	var pts := _circle_pts(Vector2(0.5, 0.5), 0.22)
	_feed_mouse(canvas, pts)
	var base_pts: PackedVector2Array = canvas._entries[0].stroke.points
	_check(canvas._entries.size() == 1, "마우스 이벤트로 획이 들어간다")

	# (b) 2배로 확대한 뒤 **같은 종이 점**을 화면 좌표로 변환해 그린다 → 정규 좌표가 같아야 한다
	canvas.clear_all()
	canvas.zoom_at(Vector2(160, 160), 2.0)   # 종이 한가운데를 잡고 2배
	_check(is_equal_approx(canvas.get_zoom(), 2.0), "휠 확대 → 배율 2.0")
	_feed_mouse(canvas, pts)
	_check(canvas._entries.size() == 1, "확대 상태에서도 획이 들어간다")
	if canvas._entries.size() == 1 and base_pts.size() > 0:
		var zoom_pts: PackedVector2Array = canvas._entries[0].stroke.points
		# 점 개수는 다를 수 있다(확대하면 더 촘촘히 찍힌다) — 형태가 같은지를 본다
		var max_err := 0.0
		for p: Vector2 in zoom_pts:
			var best := INF
			for q: Vector2 in base_pts:
				best = minf(best, p.distance_to(q))
			max_err = maxf(max_err, best)
		_check(max_err < 0.02,
			"2배로 확대해 그린 획 = 원래 획 (최대 오차 %.4f, 정규 좌표)" % max_err)
		var res: Dictionary = canvas._entries[0].result
		_check(int(res.get("role", -1)) == Enums.StrokeRole.CIRCLE,
			"확대해서 그려도 진으로 인식된다 — 인식기는 배율을 모른다")

	# (c) 커서 아래 종이 점이 확대 후에도 같은 화면 위치에 남는다 (돋보기의 기본)
	canvas.clear_all()
	var cursor := Vector2(240, 80)
	var anchor_before: Vector2 = canvas._to_paper(cursor)
	canvas.zoom_at(cursor, 2.5)
	var anchor_after: Vector2 = canvas._to_paper(cursor)
	_check(anchor_before.distance_to(anchor_after) < 0.5,
		"확대해도 커서가 짚고 있던 종이 점은 그 자리 (오차 %.2fpx)" % anchor_before.distance_to(anchor_after))

	# (d) 종이 밖 허공이 보이지 않는다 — pan은 종이가 뷰를 덮는 범위로 갇힌다
	canvas._set_view(2.0, Vector2(999, 999))
	var pan: Vector2 = canvas._pan
	_check(pan.x <= 0.001 and pan.y <= 0.001, "종이 왼쪽/위 허공 차단 (pan %.1f, %.1f)" % [pan.x, pan.y])
	canvas._set_view(2.0, Vector2(-999, -999))
	pan = canvas._pan
	_check(pan.x >= -320.001 and pan.y >= -320.001,
		"종이 오른쪽/아래 허공 차단 (pan %.1f, %.1f)" % [pan.x, pan.y])

	# (e) 배율 한계
	canvas.zoom_at(Vector2(160, 160), 100.0)
	_check(is_equal_approx(canvas.get_zoom(), 4.0), "최대 배율 ×4에서 멈춘다")
	canvas.zoom_at(Vector2(160, 160), 0.001)
	_check(is_equal_approx(canvas.get_zoom(), 1.0), "축소는 원래 크기(×1)까지만")
	_check(canvas._pan.is_equal_approx(Vector2.ZERO), "배율 1.0이면 종이가 뷰에 딱 맞는다 (pan 0)")

	# (f) 획을 긋는 도중에는 종이가 움직이지 않는다 — 그리다 확대되면 획이 망가진다
	canvas.clear_all()
	canvas._begin_stroke(Vector2(100, 100))
	canvas._gui_input(_wheel(Vector2(160, 160), MOUSE_BUTTON_WHEEL_UP))
	_check(is_equal_approx(canvas.get_zoom(), 1.0), "긋는 중 휠 무시 (배율 그대로)")
	canvas._cancel_stroke()
	canvas.clear_all()


## 화면 좌표로 마우스 이벤트를 주입해 그린다 — 실제 플레이어의 입력 경로 그대로.
## pts_norm(정규)을 현재 배율의 화면 좌표로 변환해 넣는다.
func _feed_mouse(canvas: Control, pts_norm: PackedVector2Array) -> void:
	var s := 320.0
	var zoom: float = canvas.get_zoom()
	var pan: Vector2 = canvas._pan
	var to_screen := func(n: Vector2) -> Vector2: return n * s * zoom + pan
	canvas._gui_input(_click(to_screen.call(pts_norm[0]), true))
	var prev: Vector2 = to_screen.call(pts_norm[0])
	for i in range(1, pts_norm.size()):
		var scr: Vector2 = to_screen.call(pts_norm[i])
		canvas._gui_input(_motion(scr, scr - prev))
		prev = scr
	canvas._gui_input(_click(prev, false))


func _click(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	return e


func _wheel(at: Vector2, button: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = at
	return e


func _motion(at: Vector2, rel: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.relative = rel
	e.pressure = 0.0
	return e


# ─────────────────────────── 합성 획 주입 ───────────────────────────

func _feed(canvas: Control, pts_norm: PackedVector2Array) -> void:
	var s := 320.0
	canvas._begin_stroke(pts_norm[0] * s)
	for i in range(1, pts_norm.size()):
		canvas._append_live(pts_norm[i] * s, 1.0)
	canvas._end_stroke()


func _circle_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 72:
		var a := -PI / 2.0 + TAU * 0.98 * float(i) / 71.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _line_pts(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(a.lerp(b, float(i) / 11.0))
	return pts


func _triangle_pts(c: Vector2, size: float) -> PackedVector2Array:
	var verts: Array[Vector2] = []
	for k in 3:
		var a := -PI / 2.0 + TAU * float(k) / 3.0
		verts.append(c + Vector2(cos(a), sin(a)) * size)
	var pts := PackedVector2Array()
	for e in 3:
		for i in 14:
			pts.append(verts[e].lerp(verts[(e + 1) % 3], float(i) / 14.0))
	pts.append(verts[0])
	return pts
