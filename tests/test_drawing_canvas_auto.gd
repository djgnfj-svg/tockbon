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
	# 2. 꼬리
	_feed(canvas, _line_pts(Vector2(0.73, 0.5), Vector2(0.86, 0.5)))
	_check(int(_last_recog[0]) == Enums.StrokeRole.TAIL, "꼬리 획 → TAIL")
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

	print("──────────────────────────────")
	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("DRAWING_CANVAS_AUTO_OK")
	quit(0 if _fail == 0 else 1)


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
