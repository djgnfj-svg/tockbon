extends Control
## 드로잉 캔버스 — 획 캡처(마우스/태블릿 필압)·잉크 렌더·인식 파이프라인·SpellDesign 생성.
## 좌클릭 드래그 = 획 / 우클릭 = 획 취소·마지막 획 취소 / undo_last()는 Ctrl+Z용으로 외부에서 호출.
## 완성(진1+룬1+화살표1+) 시 EventBus.design_created, 이후 변경마다 design_updated 발신.
## 종이 등급(GDD §5): set_paper() 호출 시 잉크 상한·완성 시 종이 소모·0장 완성 차단이 활성화.
## set_paper()를 부르지 않은 캔버스는 기존과 동일하게 동작한다 (레거시 — 단독 테스트 호환).

const Recognizer := preload("res://src/drawing/recognizer.gd")
const DesignBuilder := preload("res://src/drawing/design_builder.gd")
const RuneTemplates := preload("res://src/drawing/rune_templates.gd")
const InkStroke := preload("res://src/drawing/ink_stroke.gd")
const Copy := preload("res://src/drawing/drawing_copy.gd")

signal stroke_classified(result: Dictionary)
signal design_state_changed(design: SpellDesign, summary: Dictionary)
signal stamp_placement_done
## 잉크 사용량 변화 — 게이지 표시용. capacity는 종이 미설정 시 INF
signal ink_state_changed(used: float, capacity: float)
## 획이 무효 처리됨. reason: &"out_of_order"(단계 위반) / &"unrecognized"(형이 흐트러짐) / &"ink_over"
signal stroke_rejected(reason: StringName)
## 도안이 방금 맺혔다 — 이 화면의 클라이맥스 (완성 연출용. 갱신 시엔 안 쏜다)
signal design_completed(design: SpellDesign)
## 작성 단계 변화 (Enums.DrawStage) — 체크리스트 UI 갱신용
signal stage_changed(stage: int)
## 도안 완성 조건은 갖췄으나 보유 종이가 없어 생성이 차단됨 (reason: &"no_paper")
signal completion_blocked(reason: StringName)

const MIN_PX_DIST := 1.2               # 라이브 점 추가 최소 간격(px)
const STAMP_SIZE := 0.22               # 스탬프 배치 크기 (캔버스 정규화, 최장변)
const REJECT_COLOR := Color(0.75, 0.15, 0.10)  # 무효 획 경고색

# ── 마우스 필압 합성 (누적형) ──
# 마우스엔 필압이 없다. 대신 **한 자리에 머무는 시간**만큼 그 지점이 굵어진다 —
# 붓을 눌러 두면 먹이 번지는 감각. 순간 속도에 즉각 반응하는 게 아니라 목표를 향해
# 시간 상수 SYNTH_TAU로 접근하므로, 멈춰 있으면 계속 자라고 그으면 서서히 얇아진다.
# ⚠ 멈춘 마우스는 InputEventMouseMotion이 아예 안 온다 — 그래서 _process에서 시간을 돌린다.
const SYNTH_P_MIN := 0.35              # 최고 속도로 그을 때 수렴 필압 (얇음)
const SYNTH_P_MAX := 1.5               # 멈춰 있을 때 수렴 필압 (상한 — 무한정 굵어지지 않는다)
const SYNTH_SPEED_REF := 750.0         # 이 속도(px/s) 이상이면 SYNTH_P_MIN. 보통 속도(≈330px/s)에서 ≈1.0
const SYNTH_TAU := 0.35                # 목표 접근 시간 상수(s). 0.5초 머물면 1.0 → ≈1.38 (눈에 띄게 굵다)

# ── 작성 순서 (TECH_SPEC §6.2) — 진 → 룬 → 문양 ──
# 순서는 규칙이 아니라 **문법**이다: 인식기는 진의 안/밖으로 룬과 화살표를 가르므로(§6.1)
# 진이 없으면 그 판정 자체가 불가능하다. 단계에 안 맞는 획은 무효 — 잉크도 소모되지 않는다.
# 단계는 **부품 보유 상태에서 파생**한다(get_stage) — 별도 상태 변수를 두지 않으므로
# undo·스탬프·자동보정과 자동으로 일관된다.
## 각 단계는 정확히 한 종류의 획만 받는다 (v1.6 — 조준 꼬리 폐지로 예외가 사라졌다)
const STAGE_ROLES := {
	Enums.DrawStage.CIRCLE: [Enums.StrokeRole.CIRCLE],
	Enums.DrawStage.RUNE: [Enums.StrokeRole.RUNE],
	Enums.DrawStage.ARROW: [Enums.StrokeRole.ARROW],
}
const STAGE_HINTS := {
	Enums.DrawStage.CIRCLE: "진(원)을 먼저 그리세요",
	Enums.DrawStage.RUNE: "룬을 그리세요",
	Enums.DrawStage.ARROW: "문양(화살표)을 그리세요",
}

const ROLE_COLORS := {
	Enums.StrokeRole.CIRCLE: Color(0.13, 0.11, 0.10),
	Enums.StrokeRole.ARROW: Color(0.22, 0.24, 0.38),
	Enums.StrokeRole.DECOR: Color(0.13, 0.11, 0.10, 0.35),
}
const RUNE_COLORS := {
	Enums.RuneType.FIRE: Color(0.48, 0.18, 0.11),
	Enums.RuneType.IMPACT: Color(0.42, 0.34, 0.08),
	Enums.RuneType.WATER: Color(0.11, 0.29, 0.42),
	Enums.RuneType.WIND: Color(0.18, 0.42, 0.31),
}

# ── 방위 가이드 (v1.6) — "캔버스 위쪽 = 조준 방향(앞)"을 종이 위에 보이게 한다 ──
# 규칙이 안 보이면 플레이어가 매번 머릿속으로 방향을 상상하며 그려야 한다. 이 표시가
# "뒤쪽으로 견제탄을 심는다" 같은 의도적 설계를 떠올리게 하는 장치다 (GDD §4.1).
# **순수 배경 렌더다** — _draw()로 그리므로 절대 _entries에 들어가지 않는다(획으로 인식 불가).
const GUIDE_LINE := Color(0.13, 0.11, 0.10, 0.10)    # 중심 십자 — 먹선보다 훨씬 옅게
const GUIDE_TEXT := Color(0.13, 0.11, 0.10, 0.26)    # 방위 글자
const GUIDE_FRONT := Color(0.42, 0.30, 0.12, 0.42)   # 앞(조준 방향)만 살짝 진하게 — 이게 핵심축
const GUIDE_MARGIN := 0.045          # 글자를 가장자리에서 띄우는 비율 (캔버스 최단변 대비)
const GUIDE_FONT_RATIO := 0.038      # 글자 크기 비율 — 캔버스가 커도 작아도 비슷하게 보이게
const GUIDE_DOT := 2.0               # 중심점 반지름(px) — 진(원)을 그릴 자리를 암시

# ── 본보기 얹기 (v1.7) — 책자에서 고른 형태를 종이에 **옅게** 깔아 준다 ──
# 책자는 참조 전용이므로(골라 찍는 게 아니다) 따라 그을 자리를 보여 주는 것까지가 도움의 끝이다.
# **순수 배경 렌더다** — _draw()로 그리므로 _entries에 들어가지 않는다(획으로 인식될 수 없다).
const TRACE_INK := Color(0.13, 0.11, 0.10, 0.17)   # 먹선보다 훨씬 옅게 — 내 획이 언제나 주인공
const TRACE_WIDTH := 2.0
## 본보기 표준 크기 (캔버스 정규 단위). 인식기가 실제로 잘 받는 크기다
const TRACE_CIRCLE_SPAN := 0.44      # 진 — 지름 0.44 (반지름 0.22)
const TRACE_RUNE_FRAC := 0.45        # 룬 — 진 지름의 45% (진 안에 넉넉히 앉는다)
const TRACE_ARROW_SPAN := 0.50       # 문양 — 진(0.22)을 뚫고 나가는 길이

# ── 수락 연출 (v1.6) — 획이 받아들여지는 순간이 보여야 "해냈다"는 감각이 생긴다 ──
# 연출 수치다(밸런스 아님). Tween은 대상 노드에 묶여 있어 노드가 사라지면 함께 죽는다 — 안전.
const FLASH_LIGHTEN := 0.55          # 수락된 획이 번쩍이는 밝기
const FLASH_SEC := 0.30              # 번쩍임이 잦아드는 시간
const FLASH_WIDTH_MULT := 1.5        # 번쩍일 때 굵어지는 배율
const COMPLETE_FLASH_SEC := 0.55     # 완성 순간 — 도안 전체가 함께 빛난다 (더 길고 크게)
const COMPLETE_LIGHTEN := 0.75

var _entries: Array[Dictionary] = []   # {"stroke": StrokeData, "line": Line2D, "locked": bool, "result": Dictionary}
var _parts: Dictionary = {"arrows": [], "extras": [], "strokes_ordered": []}
var _design: SpellDesign = null
var _balance: BalanceData

# ── 종이 한 장 = 도안 한 장 (GDD §5) ──
# 값은 **종이 한 장에 한 번만** 치른다. 도안이 맺힌 뒤 undo로 잠시 무너졌다가 다시 맺혀도
# 종이를 또 뜯지 않고, 새 도안으로 갈라지지도 않는다 — 고쳐 그리는 게 새로 그리는 것보다
# 비쌀 이유가 없기 때문이다. _built가 그 "이 종이에서 맺힌 도안"을 계속 쥐고 있다.
var _built: SpellDesign = null      # 이 종이에서 맺힌 도안 (미완성으로 무너져도 놓지 않는다)
var _paper_charged := false         # 이 종이 값은 이미 치렀다

var _drawing := false
var _live_line: Line2D = null
var _live_points := PackedVector2Array()
var _live_pressures := PackedFloat32Array()
var _stamp_pending: Dictionary = {}

var _last_stage := Enums.DrawStage.CIRCLE   # 마지막으로 알린 단계 (변화 감지용 — 진실은 get_stage())
## 마지막 거부의 상세 — {role, score, near_rune, min_score, stage, reason}.
## stroke_rejected 수신 측이 get_last_reject()로 읽어 구체적인 문구를 만든다
var _last_reject: Dictionary = {}

var _tablet := false                   # 이 획이 진짜 필압 장치로 그려졌나 — 합성·정규화를 건너뛴다
var _cur_pressure := 1.0               # 합성 필압 누적값
var _moved_px := 0.0                   # 이번 프레임에 움직인 거리 — _process에서 속도로 환산 후 리셋

var _trace := PackedVector2Array()     # 종이에 옅게 깔린 본보기 (캔버스 정규 좌표)

var _paper_mode := false               # false = 종이 미설정(레거시 — 상한·소모·차단 없음)
var _paper_id: StringName = &""
var _paper_grade: int = 1
var _paper_params: Dictionary = {}
var _ink_used: float = 0.0


func _ready() -> void:
	_balance = load("res://data/balance.tres") as BalanceData
	if _balance == null:
		_balance = BalanceData.new()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)                 # 획을 그리는 동안에만 켠다 — 유휴 프레임 비용 0


func _canvas_scale() -> float:
	return maxf(minf(size.x, size.y), 1.0)


# ─────────────────────────── 방위 가이드 (배경 렌더) ───────────────────────────

## 캔버스 크기가 바뀌면 가이드를 다시 그린다 (시험대·드로잉룸 크기가 다르다)
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## 종이 위 방위 안내 — 위=앞(조준 방향). 획(자식 Line2D)은 이 위에 그려지므로
## 그린 먹선이 언제나 주인공이고 가이드는 그 아래 참고선으로 남는다.
func _draw() -> void:
	var c := size * 0.5
	var s := _canvas_scale()
	var m := s * GUIDE_MARGIN
	var font := ThemeDB.fallback_font
	var fs := maxi(int(s * GUIDE_FONT_RATIO), 7)

	# 중심 십자 — 진(원)을 그릴 자리를 암시한다
	draw_line(Vector2(c.x, m), Vector2(c.x, size.y - m), GUIDE_LINE, 1.0)
	draw_line(Vector2(m, c.y), Vector2(size.x - m, c.y), GUIDE_LINE, 1.0)
	draw_circle(c, GUIDE_DOT, GUIDE_LINE)

	# 위쪽(앞)만 화살촉을 얹어 조준축임을 표시 — 나머지는 글자만
	var tip := Vector2(c.x, m)
	var barb := maxf(s * 0.018, 3.0)
	draw_line(tip, tip + Vector2(-barb, barb * 1.4), GUIDE_FRONT, 1.0)
	draw_line(tip, tip + Vector2(barb, barb * 1.4), GUIDE_FRONT, 1.0)

	_guide_text(font, fs, Copy.GUIDE_FRONT, Vector2(c.x, m + float(fs) * 1.5), GUIDE_FRONT, true)
	_guide_text(font, fs, Copy.GUIDE_BACK,
		Vector2(c.x, size.y - m - float(fs) * 0.5), GUIDE_TEXT, true)
	_guide_text(font, fs, Copy.GUIDE_LEFT, Vector2(m + float(fs) * 0.5, c.y), GUIDE_TEXT, false)
	_guide_text(font, fs, Copy.GUIDE_RIGHT,
		Vector2(size.x - m - float(fs) * 1.5, c.y), GUIDE_TEXT, false)

	# 책자에서 고른 본보기 — 방위 가이드 위, 내 획 아래(자식 Line2D)에 옅게 깔린다
	if _trace.size() >= 2:
		var px := PackedVector2Array()
		for p: Vector2 in _trace:
			px.append(p * s)
		draw_polyline(px, TRACE_INK, TRACE_WIDTH, true)


func _guide_text(font: Font, fs: int, text: String, at: Vector2, col: Color, centered: bool) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := at
	if centered:
		pos.x -= w * 0.5
	pos.y += float(fs) * 0.35   # 베이스라인 → 시각적 중앙 보정
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# ─────────────────────────── 본보기 얹기 (v1.7) ───────────────────────────

## 책자에서 고른 본보기를 종이에 옅게 얹는다 — **보고 따라 그으라고.**
## unit_pts: 중심 0 · 최장변 1 정규화 점열 (RuneTemplates.canonical()과 같은 좌표계).
##
## 자리는 **지금 종이 위에 있는 것**에 맞춘다: 진을 이미 둘렀다면 룬·문양 본보기는 그 진의
## 중심·크기에 맞춰 앉는다. "여기 이만하게 앉혀라"가 말이 아니라 그림으로 보이는 게 핵심이다.
func show_trace(stage: int, unit_pts: PackedVector2Array) -> void:
	_trace = PackedVector2Array()
	if unit_pts.size() < 2:
		queue_redraw()
		return
	var c := Vector2(0.5, 0.5)
	var span := TRACE_CIRCLE_SPAN
	var has_circle := _parts.has("circle")
	match stage:
		Enums.DrawStage.RUNE:
			if has_circle:
				c = Vector2(_parts.circle.center)
				span = float(_parts.circle.radius) * 2.0 * TRACE_RUNE_FRAC
			else:
				span = TRACE_CIRCLE_SPAN * TRACE_RUNE_FRAC
		Enums.DrawStage.ARROW:
			if has_circle:
				c = Vector2(_parts.circle.center)
				# 그린 진을 확실히 뚫고 나가는 길이로 (짧으면 문양으로 인식되지 않는다)
				span = maxf(TRACE_ARROW_SPAN, float(_parts.circle.radius) * 2.6)
			else:
				span = TRACE_ARROW_SPAN
	for p: Vector2 in unit_pts:
		_trace.append(c + p * span)
	queue_redraw()


func clear_trace() -> void:
	if _trace.is_empty():
		return
	_trace = PackedVector2Array()
	queue_redraw()


func has_trace() -> bool:
	return not _trace.is_empty()


# ─────────────────────────── 종이 등급 (GDD §5) ───────────────────────────

## 종이 선택 — 캔버스를 리셋한다(기존 획 초기화). params = ItemDef.params (TECH_SPEC §4.1 PAPER 키)
func set_paper(paper_id: StringName, grade: int, params: Dictionary) -> void:
	_paper_mode = true
	_paper_id = paper_id
	_paper_grade = grade
	_paper_params = params.duplicate()
	clear_all()


## 보유 종이 없음 — 그리기는 허용하되 도안 완성(생성)은 차단
func set_no_paper() -> void:
	set_paper(&"", 1, {})


func get_paper_id() -> StringName:
	return _paper_id


func get_ink_used() -> float:
	return _ink_used


func get_ink_capacity() -> float:
	if not _paper_mode or _paper_params.is_empty():
		return INF
	return float(_paper_params.get("ink_capacity", INF))


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
		if mm.pressure > 0.001:
			# 진짜 필압 장치 — 합성 경로를 끄고 압력을 그대로 쓴다
			_tablet = true
			_append_live(mm.position, mm.pressure)
		else:
			# 마우스: 이동 거리만 적립하고, 필압은 _process가 시간으로 굴린다
			_moved_px += mm.relative.length()
			_append_live(mm.position, _cur_pressure)


## 마우스 필압 합성 — 그리는 중에만 돈다 (set_process 토글, TECH_SPEC §10).
## 모션 이벤트가 아니라 **시간**을 돌려야 "가만히 머물면 굵어진다"가 성립한다.
func _process(delta: float) -> void:
	if not _drawing or _tablet or _live_line == null or delta <= 0.0:
		return
	var speed := _moved_px / delta
	_moved_px = 0.0
	_cur_pressure = synth_pressure_step(_cur_pressure, speed, delta)
	if _live_pressures.is_empty():
		return
	# 안 움직였으면 새 점이 없다 — 마지막 점의 필압만 키워 그 자리가 부풀게 한다.
	# 라이브 먹선도 매 프레임 갱신해야 "그리는 중에 부푸는 것"이 실제로 보인다.
	_live_pressures[_live_pressures.size() - 1] = _cur_pressure
	_live_line.refresh_live_pressures(_live_pressures)


## 누적형 필압 한 스텝 — 느릴수록 목표가 높고, 목표를 향해 시간 상수로 접근한다.
## 순수 함수(씬·입력 무관)라 헤드리스에서 그대로 검증한다.
static func synth_pressure_step(cur: float, speed_px: float, delta: float) -> float:
	var t := clampf(speed_px / SYNTH_SPEED_REF, 0.0, 1.0)
	var target := lerpf(SYNTH_P_MAX, SYNTH_P_MIN, t)
	return lerpf(cur, target, 1.0 - exp(-delta / SYNTH_TAU))


## 합성 필압을 **평균 정확히 1.0**으로 정규화 — 잉크 소모 중립 (사용자 결정: 밸런스 변화 0).
## design_builder._ink_length()가 `길이 × 평균 필압`으로 잉크를 뽑으므로, 평균이 1.0이면
## 필압이 상수 1.0이던 때와 소모량이 완전히 같다. 그리는 습관이 경제에 새지 않는다.
## 개별 값은 1.0을 넘을 수 있다 — 여기서 클램프하면 평균이 1.0에서 밀린다.
## 렌더 쪽(InkRender.pressure_curve)이 [MIN_PRESSURE, MAX_PRESSURE]로 잘라 준다.
static func normalize_pressures(pressures: PackedFloat32Array) -> PackedFloat32Array:
	if pressures.is_empty():
		return pressures
	var sum := 0.0
	for p: float in pressures:
		sum += p
	var mean := sum / float(pressures.size())
	if mean <= 1e-6:
		return pressures
	var out := PackedFloat32Array()
	for p: float in pressures:
		out.append(p / mean)
	return out


# ─────────────────────────── 획 캡처 ───────────────────────────

func _begin_stroke(pos: Vector2) -> void:
	_drawing = true
	_live_points = PackedVector2Array()
	_live_pressures = PackedFloat32Array()
	_tablet = false
	_cur_pressure = 1.0                # 보통 속도의 필압에서 출발 — 툭 찍으면 1.0
	_moved_px = 0.0
	_live_line = InkStroke.new()
	add_child(_live_line)
	_append_live(pos, _cur_pressure)
	set_process(true)                  # 그리는 동안에만 시간을 돌린다


func _append_live(pos: Vector2, pressure: float) -> void:
	var p := pos.clamp(Vector2.ZERO, size)
	if not _live_points.is_empty() and _live_points[_live_points.size() - 1].distance_to(p) < MIN_PX_DIST:
		return
	_live_points.append(p)
	_live_pressures.append(pressure)
	_live_line.append_live(p)


func _cancel_stroke() -> void:
	_drawing = false
	set_process(false)
	if _live_line != null:
		_live_line.queue_free()
		_live_line = null


func _end_stroke() -> void:
	_drawing = false
	set_process(false)
	var s := _canvas_scale()
	if _live_points.size() < 3 or Recognizer.path_length(_live_points) / s < Recognizer.MIN_STROKE_LEN:
		_cancel_stroke()
		return
	var norm := PackedVector2Array()
	for p: Vector2 in _live_points:
		norm.append(p / s)
	var stroke := StrokeData.new()
	stroke.points = norm
	# 합성 필압만 평균 1.0으로 정규화 — 잉크 중립. 태블릿의 진짜 압력은 건드리지 않는다
	stroke.pressures = _live_pressures.duplicate() if _tablet \
		else normalize_pressures(_live_pressures)
	# 작성 순서 — 지금 단계가 받지 않는 획은 무효 (TECH_SPEC §6.2).
	# 엔트리에 넣기 전에 거른다: _ink_used는 _entries에서 재계산되므로 잉크도 소모되지 않는다.
	# 인식 실패(DECOR)는 **순서 문제가 아니라 형이 흐트러진 것** — 사유를 갈라 다른 말을 해 준다
	var pre := Recognizer.classify_stroke(stroke.points, _recognizer_ctx())
	var pre_role := int(pre.get("role", Enums.StrokeRole.DECOR))
	if not _accepts_role(pre_role):
		_reject_live_line()
		# 왜 안 됐는지를 구체적으로 남긴다 — 어느 룬에 얼마나 가까웠는지(near_rune/score)까지.
		# "거의 됐다"와 "전혀 아니다"를 구별할 수 있어야 다시 그릴 마음이 생긴다
		_last_reject = pre.duplicate()
		_last_reject["stage"] = get_stage()
		stroke_rejected.emit(
			&"unrecognized" if pre_role == Enums.StrokeRole.DECOR else &"out_of_order")
		return
	# 종이 잉크 상한 — 초과하게 되는 획은 무효 처리, 획을 지우면 회복 (TECH_SPEC §4.1)
	if _ink_used + DesignBuilder.stroke_ink_units(stroke, _balance) > get_ink_capacity():
		_reject_live_line()
		stroke_rejected.emit(&"ink_over")
		return
	var entry := {"stroke": stroke, "line": _live_line, "locked": false, "result": {}}
	_live_line.setup(_live_points, stroke.pressures)
	_live_line = null
	_entries.append(entry)
	var was_complete := _design != null
	_reclassify_all()
	# 수락 확인: 방금 그린 획이 제 역할 색으로 한 번 번쩍인다.
	# 도안이 이번 획으로 맺혔다면 개별 번쩍임 대신 전체가 함께 빛난다 (클라이맥스를 덮지 않게)
	if _design != null and not was_complete:
		_flash_all_lines()
		design_completed.emit(_design)
	else:
		_flash_line(entry.line as Line2D, FLASH_LIGHTEN, FLASH_SEC)
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
	var blocked := false
	if DesignBuilder.is_complete(_parts):
		# 값을 아직 안 치른 종이에서만 보유를 따진다. 이미 치른 종이는 몇 번을 고쳐 그려도
		# 공짜다 — 종이는 이미 뜯었으니까 (undo → 재작성이 이중 과금되던 버그의 근본)
		var first := not _paper_charged
		if first and not _paper_available():
			_design = null
			blocked = true
		else:
			# into=_built — 같은 종이에서 맺힌 도안은 **같은 id·같은 내구**로 이어진다
			_built = DesignBuilder.build(_parts, _balance, _built, _paper_grade, _paper_params)
			_design = _built
			if first:
				_consume_paper()
				_paper_charged = true
			var bus := _bus()
			if bus != null:
				bus.emit_signal(&"design_created" if first else &"design_updated", _design)
	else:
		# 미완성 — 발사는 못 한다. 단 _built는 놓지 않는다: 다시 맺히면 그 도안으로 돌아간다
		_design = null
	_recompute_ink()
	_emit_stage_if_changed()
	design_state_changed.emit(_design, get_summary())
	if blocked:
		completion_blocked.emit(&"no_paper")


## 단계는 파생값이라 매번 계산해도 되지만, 시그널은 실제로 바뀔 때만 쏜다
func _emit_stage_if_changed() -> void:
	var stage := get_stage()
	if stage == _last_stage:
		return
	_last_stage = stage
	stage_changed.emit(stage)


# ─────────────────────────── 수락 연출 ───────────────────────────

## 방금 수락된 획이 한 번 번쩍인다 — 역할 색으로 밝게 떴다가 제 색으로 잦아든다.
## Tween은 line에 묶이므로 line이 사라지면 자동으로 죽는다 (undo·clear 중 안전).
func _flash_line(line: Line2D, lighten: float, sec: float) -> void:
	if line == null or not is_instance_valid(line):
		return
	var base_col := line.default_color
	var base_w := line.width
	line.default_color = base_col.lightened(lighten)
	line.width = base_w * FLASH_WIDTH_MULT
	var tw := line.create_tween()
	tw.set_parallel(true)
	tw.tween_property(line, ^"default_color", base_col, sec)
	tw.tween_property(line, ^"width", base_w, sec)


## 도안이 맺히는 순간 — 그린 획 전체가 함께 빛난다. 이 화면의 클라이맥스
func _flash_all_lines() -> void:
	for e in _entries:
		_flash_line(e.line as Line2D, COMPLETE_LIGHTEN, COMPLETE_FLASH_SEC)


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


# ─────────────────────────── 작성 단계 (TECH_SPEC §6.2) ───────────────────────────

## 현재 단계 — 부품 보유 상태에서 파생한다 (상태 변수 없음 → undo·스탬프와 자동 일관)
func get_stage() -> int:
	if not _parts.has("circle"):
		return Enums.DrawStage.CIRCLE
	if not _parts.has("rune"):
		return Enums.DrawStage.RUNE
	return Enums.DrawStage.ARROW


## 이 단계에서 지금 무엇을 그려야 하는지 — 거부 메시지·안내 공용
static func stage_hint(stage: int) -> String:
	return STAGE_HINTS.get(stage, "")


## 이 역할의 획을 지금 단계에서 받을 수 있나. DECOR(인식 실패)는 어느 단계에서도 거부한다 —
## "장식으로 남았습니다"보다 "지금은 룬을 그릴 차례"가 플레이어에게 훨씬 쓸모 있다.
func _accepts_role(role: int) -> bool:
	var allowed: Array = STAGE_ROLES.get(get_stage(), [])
	return allowed.has(role)


## 현재 부품 상태 → 인식기 컨텍스트. classify_entries가 마지막에 도달했을 컨텍스트와 같다.
## 새 획을 **엔트리에 넣기 전에** 미리 채점해 단계 위반을 가려내기 위한 것.
func _recognizer_ctx() -> Dictionary:
	var ctx := {}
	if _parts.has("circle"):
		ctx["has_circle"] = true
		ctx["circle_center"] = _parts.circle.center
		ctx["circle_radius"] = _parts.circle.radius
	if _parts.has("rune"):
		ctx["has_rune"] = true
	return ctx


## 마지막으로 거부된 획의 상세 (stroke_rejected 직후에 읽는다).
## near_rune·score가 있으면 "어느 룬에 얼마나 가까웠는지"를 말해 줄 수 있다.
func get_last_reject() -> Dictionary:
	return _last_reject


func get_design() -> SpellDesign:
	return _design


func get_summary() -> Dictionary:
	var summary := {
		"has_circle": _parts.has("circle"),
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
	# 종이를 새로 편다 — 다음 도안은 새 종이 값을 치른다
	_built = null
	_paper_charged = false
	_trace = PackedVector2Array()   # 본보기도 걷는다 (진이 사라져 앉을 자리가 없어졌다)
	_parts = {"arrows": [], "extras": [], "strokes_ordered": []}
	_recompute_ink()
	_emit_stage_if_changed()
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
	# 스탬프는 룬이다 — 진이 없으면 놓을 자리가 없다 (TECH_SPEC §6.2).
	# RUNE 단계 = 룬을 채움 / ARROW 단계 = 기존 룬 교체 (교체는 순서 위반이 아니라 편집이다)
	if get_stage() == Enums.DrawStage.CIRCLE:
		_stamp_pending = {}
		stroke_rejected.emit(&"out_of_order")
		stamp_placement_done.emit()
		return
	var s := _canvas_scale()
	var pos_n := pos_px.clamp(Vector2.ZERO, size) / s
	var stamp := _stamp_pending
	_stamp_pending = {}
	var pts := PackedVector2Array()
	for p: Vector2 in stamp.points:
		pts.append(pos_n + Vector2(p) * STAMP_SIZE)
	var stroke := StrokeData.new()
	stroke.points = pts
	stroke.pressures = stamp.get("pressures", PackedFloat32Array())
	stroke.role = Enums.StrokeRole.RUNE
	# 잉크 상한 — 교체로 사라질 기존 룬의 잉크는 회수분으로 계산
	var freed := 0.0
	for e in _entries:
		var prev: Dictionary = e.result
		if int(prev.get("role", -1)) == Enums.StrokeRole.RUNE:
			var prev_stroke: StrokeData = e.stroke
			freed += DesignBuilder.stroke_ink_units(prev_stroke, _balance)
	if _ink_used - freed + DesignBuilder.stroke_ink_units(stroke, _balance) > get_ink_capacity():
		stroke_rejected.emit(&"ink_over")
		stamp_placement_done.emit()
		return
	# 기존 룬은 교체 (MVP 룬 1개 규칙)
	for i in range(_entries.size() - 1, -1, -1):
		var res: Dictionary = _entries[i].result
		if int(res.get("role", -1)) == Enums.StrokeRole.RUNE:
			var old := _entries[i].line as Line2D
			if old != null:
				old.queue_free()
			_entries.remove_at(i)
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


## GameState 오토로드 런타임 조회 — _bus()와 같은 이유
func _game_state() -> Node:
	return get_node_or_null(^"/root/GameState")


## 완성(생성) 가능 여부 — 종이 미설정(레거시)·GameState 부재(단독 테스트)는 항상 허용
func _paper_available() -> bool:
	if not _paper_mode:
		return true
	if _paper_id == StringName():
		return false
	var gs := _game_state()
	if gs == null:
		return true
	return int(gs.call(&"get_count", _paper_id)) > 0


func _consume_paper() -> void:
	if not _paper_mode or _paper_id == StringName():
		return
	var gs := _game_state()
	if gs != null:
		gs.call(&"remove_item", _paper_id, 1)


func _recompute_ink() -> void:
	if _balance == null:
		return
	_ink_used = 0.0
	for e in _entries:
		var stroke: StrokeData = e.stroke
		_ink_used += DesignBuilder.stroke_ink_units(stroke, _balance)
	ink_state_changed.emit(_ink_used, get_ink_capacity())


## 상한 초과 획 시각 경고 — 경고색으로 바꾼 뒤 페이드아웃하며 제거
func _reject_live_line() -> void:
	var line := _live_line
	_live_line = null
	if line == null:
		return
	line.default_color = REJECT_COLOR
	var tw := line.create_tween()
	tw.tween_property(line, ^"modulate:a", 0.0, 0.35)
	tw.tween_callback(line.queue_free)


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
