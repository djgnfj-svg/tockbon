extends Control
## 드로잉 캔버스 — 획 캡처(마우스/태블릿 필압)·잉크 렌더·인식 파이프라인·SpellDesign 생성.
## 좌클릭 드래그 = 획 / 우클릭 = 획 취소·마지막 획 취소 / undo_last()는 Ctrl+Z용으로 외부에서 호출.
## 완성(진1+룬1+화살표1+) 시 EventBus.design_created, 이후 변경마다 design_updated 발신.

const Recognizer := preload("res://src/drawing/recognizer.gd")
const DesignBuilder := preload("res://src/drawing/design_builder.gd")
const RuneTemplates := preload("res://src/drawing/rune_templates.gd")
const InkStroke := preload("res://src/drawing/ink_stroke.gd")

signal stroke_classified(result: Dictionary)
signal design_state_changed(design: SpellDesign, summary: Dictionary)
signal stamp_placement_done

const MIN_PX_DIST := 1.2               # 라이브 점 추가 최소 간격(px)
const STAMP_SIZE := 0.22               # 스탬프 배치 크기 (캔버스 정규화, 최장변)

const ROLE_COLORS := {
	Enums.StrokeRole.CIRCLE: Color(0.13, 0.11, 0.10),
	Enums.StrokeRole.TAIL: Color(0.45, 0.29, 0.12),
	Enums.StrokeRole.ARROW: Color(0.22, 0.24, 0.38),
	Enums.StrokeRole.DECOR: Color(0.13, 0.11, 0.10, 0.35),
}
const RUNE_COLORS := {
	Enums.RuneType.FIRE: Color(0.48, 0.18, 0.11),
	Enums.RuneType.IMPACT: Color(0.42, 0.34, 0.08),
	Enums.RuneType.WATER: Color(0.11, 0.29, 0.42),
	Enums.RuneType.WIND: Color(0.18, 0.42, 0.31),
}

var _entries: Array[Dictionary] = []   # {"stroke": StrokeData, "line": Line2D, "locked": bool, "result": Dictionary}
var _parts: Dictionary = {"arrows": [], "extras": [], "strokes_ordered": []}
var _design: SpellDesign = null
var _balance: BalanceData

var _drawing := false
var _live_line: Line2D = null
var _live_points := PackedVector2Array()
var _live_pressures := PackedFloat32Array()
var _stamp_pending: Dictionary = {}


func _ready() -> void:
	_balance = load("res://data/balance.tres") as BalanceData
	if _balance == null:
		_balance = BalanceData.new()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _canvas_scale() -> float:
	return maxf(minf(size.x, size.y), 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if not _stamp_pending.is_empty():
					_place_stamp_at(mb.position)
				else:
					_begin_stroke(mb.position)
			elif _drawing:
				_end_stroke()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _drawing:
				_cancel_stroke()
			elif not _stamp_pending.is_empty():
				_stamp_pending = {}
				stamp_placement_done.emit()
			else:
				undo_last()
			accept_event()
	elif event is InputEventMouseMotion and _drawing:
		var mm := event as InputEventMouseMotion
		var pressure := mm.pressure
		if pressure <= 0.001:
			pressure = 1.0  # 필압 미지원 장치(마우스) 기본값
		_append_live(mm.position, pressure)


# ─────────────────────────── 획 캡처 ───────────────────────────

func _begin_stroke(pos: Vector2) -> void:
	_drawing = true
	_live_points = PackedVector2Array()
	_live_pressures = PackedFloat32Array()
	_live_line = InkStroke.new()
	add_child(_live_line)
	_append_live(pos, 1.0)


func _append_live(pos: Vector2, pressure: float) -> void:
	var p := pos.clamp(Vector2.ZERO, size)
	if not _live_points.is_empty() and _live_points[_live_points.size() - 1].distance_to(p) < MIN_PX_DIST:
		return
	_live_points.append(p)
	_live_pressures.append(pressure)
	_live_line.append_live(p)


func _cancel_stroke() -> void:
	_drawing = false
	if _live_line != null:
		_live_line.queue_free()
		_live_line = null


func _end_stroke() -> void:
	_drawing = false
	var s := _canvas_scale()
	if _live_points.size() < 3 or Recognizer.path_length(_live_points) / s < Recognizer.MIN_STROKE_LEN:
		_cancel_stroke()
		return
	var norm := PackedVector2Array()
	for p: Vector2 in _live_points:
		norm.append(p / s)
	var stroke := StrokeData.new()
	stroke.points = norm
	stroke.pressures = _live_pressures.duplicate()
	var entry := {"stroke": stroke, "line": _live_line, "locked": false, "result": {}}
	_live_line.setup(_live_points, _live_pressures)
	_live_line = null
	_entries.append(entry)
	_reclassify_all()
	var res: Dictionary = entry.result
	var role := int(res.get("role", Enums.StrokeRole.DECOR))
	var bus := _bus()
	if bus != null:
		bus.emit_signal(&"recognition_result", role, role != Enums.StrokeRole.DECOR,
			float(res.get("score", 0.0)))
	stroke_classified.emit(res)


# ─────────────────────────── 상태 재구축 ───────────────────────────

func _reclassify_all() -> void:
	_parts = DesignBuilder.classify_entries(_entries)
	for e in _entries:
		_apply_style(e)
	if DesignBuilder.is_complete(_parts):
		var was_complete := _design != null
		_design = DesignBuilder.build(_parts, _balance, _design)
		var bus := _bus()
		if bus != null:
			bus.emit_signal(&"design_updated" if was_complete else &"design_created", _design)
	else:
		_design = null
	design_state_changed.emit(_design, get_summary())


func _apply_style(e: Dictionary) -> void:
	var line := e.line as Line2D
	if line == null:
		return
	var res: Dictionary = e.result
	var role := int(res.get("role", Enums.StrokeRole.DECOR))
	if role == Enums.StrokeRole.RUNE:
		line.default_color = RUNE_COLORS.get(int(res.get("rune_type", 0)), InkStroke.INK_COLOR)
	else:
		line.default_color = ROLE_COLORS.get(role, InkStroke.INK_COLOR)


func get_design() -> SpellDesign:
	return _design


func get_summary() -> Dictionary:
	var summary := {
		"has_circle": _parts.has("circle"),
		"has_tail": _parts.has("tail"),
		"has_rune": _parts.has("rune"),
		"rune_type": -1,
		"rune_accuracy_raw": 0.0,
		"arrow_count": (_parts.arrows as Array).size(),
		"extra_count": (_parts.extras as Array).size(),
		"stroke_count": _entries.size(),
	}
	if _parts.has("rune"):
		summary.rune_type = int(_parts.rune.type)
		summary.rune_accuracy_raw = float(_parts.rune.accuracy_raw)
	return summary


func undo_last() -> void:
	if _entries.is_empty():
		return
	var e: Dictionary = _entries.pop_back()
	var line := e.line as Line2D
	if line != null:
		line.queue_free()
	_reclassify_all()


func clear_all() -> void:
	_cancel_stroke()
	_stamp_pending = {}
	for e in _entries:
		var line := e.line as Line2D
		if line != null:
			line.queue_free()
	_entries.clear()
	_design = null
	_parts = {"arrows": [], "extras": [], "strokes_ordered": []}
	design_state_changed.emit(null, get_summary())


# ─────────────────────────── 자동보정 (GDD §4.4) ───────────────────────────

## 그린 룬을 템플릿 형태로 스냅. rune_accuracy는 현재값 유지 — 엔트리를 잠가 재채점을 막는다.
func autocorrect_rune() -> bool:
	for e in _entries:
		var res: Dictionary = e.result
		if int(res.get("role", -1)) != Enums.StrokeRole.RUNE:
			continue
		var stroke: StrokeData = e.stroke
		var canon := RuneTemplates.canonical(int(res.rune_type))
		if canon.is_empty():
			return false
		var bbox := _points_bbox(stroke.points)
		var span := maxf(maxf(bbox.size.x, bbox.size.y), 0.05)
		var center := bbox.get_center()
		var snap_pts := PackedVector2Array()
		for p: Vector2 in canon:
			snap_pts.append(center + p * span)
		stroke.points = snap_pts
		stroke.pressures = PackedFloat32Array()
		e["locked"] = true
		_rebuild_line(e)
		_reclassify_all()
		return true
	return false


# ─────────────────────────── 필체 스탬프 (GDD v1.3 — 정확도 보존) ───────────────────────────

## 현재 인식된 룬을 스탬프로 추출. 없으면 빈 딕셔너리.
func save_rune_stamp() -> Dictionary:
	for e in _entries:
		var res: Dictionary = e.result
		if int(res.get("role", -1)) != Enums.StrokeRole.RUNE:
			continue
		var stroke: StrokeData = e.stroke
		var bbox := _points_bbox(stroke.points)
		var span := maxf(maxf(bbox.size.x, bbox.size.y), 1e-6)
		var center := bbox.get_center()
		var unit := PackedVector2Array()
		for p: Vector2 in stroke.points:
			unit.append((p - center) / span)
		return {
			"rune_type": int(res.rune_type),
			"score": float(res.score),
			"points": unit,
			"pressures": stroke.pressures.duplicate(),
		}
	return {}


## 스탬프 배치 모드 시작 — 다음 캔버스 좌클릭 위치에 배치된다.
func begin_stamp_placement(stamp: Dictionary) -> void:
	if stamp.is_empty():
		return
	_stamp_pending = stamp


func is_placing_stamp() -> bool:
	return not _stamp_pending.is_empty()


func _place_stamp_at(pos_px: Vector2) -> void:
	var s := _canvas_scale()
	var pos_n := pos_px.clamp(Vector2.ZERO, size) / s
	var stamp := _stamp_pending
	_stamp_pending = {}
	# 기존 룬은 교체 (MVP 룬 1개 규칙)
	for i in range(_entries.size() - 1, -1, -1):
		var res: Dictionary = _entries[i].result
		if int(res.get("role", -1)) == Enums.StrokeRole.RUNE:
			var old := _entries[i].line as Line2D
			if old != null:
				old.queue_free()
			_entries.remove_at(i)
	var pts := PackedVector2Array()
	for p: Vector2 in stamp.points:
		pts.append(pos_n + Vector2(p) * STAMP_SIZE)
	var stroke := StrokeData.new()
	stroke.points = pts
	stroke.pressures = stamp.get("pressures", PackedFloat32Array())
	stroke.role = Enums.StrokeRole.RUNE
	var entry := {
		"stroke": stroke,
		"line": InkStroke.new(),
		"locked": true,  # 재인식 금지 — 저장 시점 정확도 그대로 보존
		"result": {
			"role": Enums.StrokeRole.RUNE,
			"rune_type": int(stamp.rune_type),
			"score": float(stamp.score),
		},
	}
	add_child(entry.line)
	_entries.append(entry)
	_rebuild_line(entry)
	_reclassify_all()
	stamp_placement_done.emit()


# ─────────────────────────── 내부 유틸 ───────────────────────────

## EventBus 오토로드 런타임 조회 — 컴파일 타임 전역 참조를 피해
## 헤드리스(-s) 테스트에서도 이 스크립트가 로드되게 한다. 시그널 계약은 TECH_SPEC §5 그대로.
func _bus() -> Node:
	return get_node_or_null(^"/root/EventBus")


func _rebuild_line(e: Dictionary) -> void:
	var line := e.line as Line2D
	var stroke: StrokeData = e.stroke
	if line == null:
		return
	var s := _canvas_scale()
	var px := PackedVector2Array()
	for p: Vector2 in stroke.points:
		px.append(p * s)
	line.setup(px, stroke.pressures)
	_apply_style(e)


func _points_bbox(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var lo: Vector2 = pts[0]
	var hi: Vector2 = pts[0]
	for p: Vector2 in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)
