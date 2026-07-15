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
const StrokeGuide := preload("res://src/drawing/stroke_guide.gd")
const InkRender := preload("res://src/core/ink_render.gd")

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
## 종이 확대 배율이 바뀌었다 (1.0 = 원래 크기) — 배율 표시 UI용
signal zoom_changed(zoom: float)
## 본보기를 들었다/놓았다/걷었다 — 조작 안내 문구용 (active=false면 본보기가 없다)
signal trace_changed(active: bool)

const MIN_PX_DIST := 1.2               # 라이브 점 추가 최소 간격(px)
const STAMP_SIZE := 0.22               # 스탬프 배치 크기 (캔버스 정규화, 최장변)
const REJECT_COLOR := Color(0.75, 0.15, 0.10)  # 무효 획 경고색

# ── 본보기 조절 (휠 = 크기 / Shift+휠 = 회전) ──
# 크기가 곧 농도(룬)·세기(문양)라 **플레이어가 정할 수 있어야 한다** (StrokeGuide 상단 계약)
const TRACE_SPAN_STEP := 1.12          # 휠 한 칸 — 곱셈이라 작을 때 곱게 움직인다
const TRACE_SPAN_MIN := 0.05
const TRACE_SPAN_MAX := 0.70
const TRACE_ROT_STEP := PI / 12.0      # Shift+휠 한 칸 (15도)

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
	Enums.RuneType.WATER: Color(0.11, 0.29, 0.42),
	Enums.RuneType.WIND: Color(0.18, 0.42, 0.31),
}

# ── 방위 가이드 — **종이 위쪽 = 탄이 가는 쪽** (v2.1) ──
# 🔴 **의미가 두 번 바뀌었다. 지금 것은 충격파 축이다** (TECH_SPEC §4.0-b):
#   v1.5~v1.9: **발사 방향** ("위로 그은 화살표가 에임으로 나간다")
#   v2.0:      **폐지** — 발사 방향이 지팡이로 가면서 종이에 방위가 없어졌다 (지웠다)
#   v2.1:      **충격파 방향** — 되살아났다. 위로 그으면 적을 **밀어내고**, 아래로 그으면
#              **나에게 끌어온다.** 화살표 = 착탄 후 충격이 가는 쪽이기 때문이다
# **순수 배경 렌더다** — _draw()로 그리므로 절대 _entries에 들어가지 않는다(획으로 인식 불가).
const GUIDE_LINE := Color(0.13, 0.11, 0.10, 0.10)    # 중심 십자 — 먹선보다 훨씬 옅게
const GUIDE_TEXT := Color(0.13, 0.11, 0.10, 0.26)    # 방위 글자
const GUIDE_FRONT := Color(0.42, 0.30, 0.12, 0.42)   # 앞(탄이 가는 쪽)만 살짝 진하게 — 기준축
const GUIDE_MARGIN := 0.045          # 글자를 가장자리에서 띄우는 비율 (캔버스 최단변 대비)
const GUIDE_FONT_RATIO := 0.038      # 글자 크기 비율 — 캔버스가 커도 작아도 비슷하게 보이게
const GUIDE_DOT := 2.0               # 중심점 반지름(px) — 진(원)을 그릴 자리를 암시

# ── 본보기 얹기 (v1.7) — 책자에서 고른 형태를 종이에 **옅게** 깔아 준다 ──
# 책자는 참조 전용이므로(골라 찍는 게 아니다) 따라 그을 자리를 보여 주는 것까지가 도움의 끝이다.
# **순수 배경 렌더다** — _draw()로 그리므로 _entries에 들어가지 않는다(획으로 인식될 수 없다).
const TRACE_INK := Color(0.13, 0.11, 0.10, 0.17)   # 먹선보다 훨씬 옅게 — 내 획이 언제나 주인공
## 🔴 **탁본 필사 — 완성된 도안을 옅게 깐다** (2026-07-15). 게임의 심장(탁본)으로 예시를 따라
## 그린다. 내 획보다 옅되 따라 그릴 만큼은 보인다. 순수 배경 — 인식·잉크·발사에 영향 없다.
const RUBBING_INK := Color(0.16, 0.13, 0.11, 0.32)
const RUBBING_WIDTH := 2.0
const TRACE_WIDTH := 2.0
## 문양 본보기의 **화살촉** 길이 (캔버스 최단변 대비). 색·굵기는 선과 같다 —
## 다르면 "선 + 딴 물건"으로 읽히지 화살표 하나로 안 보인다
const TRACE_HEAD := 0.030
## 본보기 표준 크기 (캔버스 정규 단위). 인식기가 실제로 잘 받는 크기다
const TRACE_CIRCLE_SPAN := 0.44      # 진 — 지름 0.44 (반지름 0.22)
const TRACE_RUNE_FRAC := 0.45        # 룬 — 진 지름의 45% (진 안에 넉넉히 앉는다)
const TRACE_ARROW_SPAN := 0.50       # 문양 — 진(0.22)을 뚫고 나가는 길이

# ── 수락 연출 (v1.6) — 획이 받아들여지는 순간이 보여야 "해냈다"는 감각이 생긴다 ──
# 연출 수치다(밸런스 아님). Tween은 대상 노드에 묶여 있어 노드가 사라지면 함께 죽는다 — 안전.
# ── 종이 확대 (v1.7) — **작은 문양을 정밀하게 그리기 위한 돋보기** ──
# 확대는 **보는 배율만** 바꾼다. 저장되는 획은 언제나 종이 정규 좌표(0..1)라
# 인식·발사·잉크는 배율과 무관하다 — 4배로 확대해 그린 진도 종이 위 크기 그대로다.
const ZOOM_MIN := 1.0                # 1.0 = 종이 전체가 보이는 상태. 그보다 축소할 이유는 없다
const ZOOM_MAX := 4.0
const ZOOM_STEP := 1.15              # 휠 한 칸 배율 (약 5칸에 2배)
const ZOOM_EPS := 0.001              # 부동소수 여유 — 1.0 근처에서 "확대 중" 오판 방지
const ZOOM_LABEL := Color(0.13, 0.11, 0.10, 0.38)
const ZOOM_LABEL_RATIO := 0.040      # 배율 글자 크기 비율 (캔버스 최단변 대비)

const FLASH_LIGHTEN := 0.55          # 수락된 획이 번쩍이는 밝기
const FLASH_SEC := 0.30              # 번쩍임이 잦아드는 시간
const FLASH_WIDTH_MULT := 1.5        # 번쩍일 때 굵어지는 배율
const COMPLETE_FLASH_SEC := 0.55     # 완성 순간 — 도안 전체가 함께 빛난다 (더 길고 크게)
const COMPLETE_LIGHTEN := 0.75

var _entries: Array[Dictionary] = []   # {"stroke": StrokeData, "line": Line2D, "locked": bool, "result": Dictionary}
## 🔴 **중첩 진 트리 (재귀).** assemble_tree의 루트 배열. `_parts`는 그중 첫 루트(=껍질) —
## parts와 노드 딕셔너리가 같은 키라 기존 접근이 그대로 산다. 단계·수락은 **활성 노드**(방금 그린
## 원)를 따른다: 껍질을 완성한 뒤 안쪽 진을 그리면 그 안쪽 진의 룬을 받을 수 있어야 하기 때문.
var _roots: Array = []
var _parts: Dictionary = {"arrows": [], "extras": [], "strokes_ordered": []}
var _design: SpellDesign = null
var _balance: BalanceData

# ── 종이 한 장 = 도안 한 장 (GDD §5) ──
# 값은 **종이 한 장에 한 번만** 치른다. 도안이 맺힌 뒤 undo로 잠시 무너졌다가 다시 맺혀도
# 종이를 또 뜯지 않고, 새 도안으로 갈라지지도 않는다 — 고쳐 그리는 게 새로 그리는 것보다
# 비쌀 이유가 없기 때문이다. _built가 그 "이 종이에서 맺힌 도안"을 계속 쥐고 있다.
var _built: SpellDesign = null      # 이 종이에서 맺힌 도안 (미완성으로 무너져도 놓지 않는다)
var _paper_charged := false         # 이 종이 값은 이미 치렀다

# ── 종이 뷰 (확대·이동). 획 좌표는 **종이 픽셀**이고, 화면 픽셀과는 이 둘로만 오간다 ──
var _zoom := 1.0
var _pan := Vector2.ZERO            # 종이 원점이 놓이는 화면 위치(px)
var _panning := false
var _pan_from := Vector2.ZERO

# ── 우클릭 — **되돌리기가 아니다** (사용자 확정. 되돌리기는 Ctrl+Z만) ──
# 누르고 있으면 휠이 **회전**이 된다. 떼는 순간의 취소 동작은 회전을 안 했을 때만 발동한다
var _rmb_held := false
var _rmb_turned := false
## 획(Line2D)이 사는 레이어. 여기에 zoom·pan을 걸면 획·가이드·본보기가 함께 확대된다.
## 캔버스는 clip_contents=true라 넘치는 부분은 자동으로 잘린다
var _ink_layer: Node2D = null

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

# ── 본보기(트레이스) — 책자에서 집어 종이에 놓는 자국. **놓이면 자석이 된다** ──
# _trace = 화면에 보이는 선 (캔버스 정규 좌표) — 들고 있는 중이든 놓았든 여기 들어 있다
# _trace_held = 아직 마우스에 붙어 있다 {unit, span, rot} — 비어 있으면 종이에 놓인 상태
# _trace_placed = 종이에 앉았다 → 이때만 획을 끌어당긴다 (들고 있는 동안엔 안 끈다)
var _trace := PackedVector2Array()
var _trace_held: Dictionary = {}
var _trace_placed := false
## 탁본 필사 — 깔린 옅은 참조 먹선들 (Line2D). _entries와 무관한 순수 배경.
var _rubbing_lines: Array[Line2D] = []
## 어느 부품의 본보기인가 — 문양일 때만 화살촉을 그린다 (방향이 있는 글자는 문양뿐)
var _trace_stage: int = -1
## 자석이 쓰는 종이 픽셀 좌표 캐시 (_live_points와 같은 좌표계) — 획 점마다 다시 만들지 않는다
var _trace_px := PackedVector2Array()

var _paper_mode := false               # false = 종이 미설정(레거시 — 상한·소모·차단 없음)
var _paper_id: StringName = &""
var _paper_grade: int = 1
var _paper_params: Dictionary = {}
var _ink_used: float = 0.0
## 지금 긋는 중인 획이 쓴 먹 — **확정 전 미리보기**다. 게이지는 _ink_used + _live_ink를 보여 준다.
## 이게 없으면 다 긋고 나서야 상한 초과를 알고 획이 통째로 무효가 된다 (그리는 손이 벌을 받는다).
## 증분으로 쌓는다 — 점마다 획 전체를 다시 적분하면 긴 획에서 O(n²)가 된다
var _live_ink: float = 0.0


func _ready() -> void:
	_balance = load("res://data/balance.tres") as BalanceData
	if _balance == null:
		_balance = BalanceData.new()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)                 # 획을 그리는 동안에만 켠다 — 유휴 프레임 비용 0
	_ink_layer = Node2D.new()
	_ink_layer.name = "InkLayer"
	add_child(_ink_layer)


func _canvas_scale() -> float:
	return maxf(minf(size.x, size.y), 1.0)


# ─────────────────────────── 종이 확대 (v1.7) ───────────────────────────
#
# **좌표계는 둘뿐이다.**
#   화면 픽셀 — 마우스 이벤트가 오는 좌표. 확대하면 같은 종이 점이 다른 화면 위치에 온다
#   종이 픽셀 — 획이 저장되는 좌표 (0..size). **확대와 무관하다.** 정규화(÷_canvas_scale)하면 0..1
# 이 경계를 넘는 건 _to_paper() 하나뿐이다. 나머지 로직은 확대를 모른다 —
# 그래서 4배로 확대해 그린 획도 인식·잉크·발사가 원래와 완전히 같다.

## 화면 픽셀 → 종이 픽셀
func _to_paper(screen_px: Vector2) -> Vector2:
	return (screen_px - _pan) / _zoom


## 현재 배율 (1.0 = 종이 전체)
func get_zoom() -> float:
	return _zoom


## 종이를 원래 크기로 되돌린다 (종이를 갈거나 제작대를 열 때)
func reset_view() -> void:
	_set_view(1.0, Vector2.ZERO)


## 커서 아래의 **종이 점을 붙잡은 채** 배율만 바꾼다 — 확대해도 보던 자리가 달아나지 않는다
func zoom_at(screen_px: Vector2, factor: float) -> void:
	var next := clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(next, _zoom):
		return
	var anchor := _to_paper(screen_px)          # 이 종이 점을
	_set_view(next, screen_px - anchor * next)  # 같은 화면 위치에 고정


func _set_view(zoom: float, pan: Vector2) -> void:
	var prev := _zoom
	_zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	_pan = _clamp_pan(pan)
	if _ink_layer != null:
		_ink_layer.position = _pan
		_ink_layer.scale = Vector2.ONE * _zoom
	queue_redraw()
	if not is_equal_approx(prev, _zoom):
		zoom_changed.emit(_zoom)


## 종이가 언제나 뷰를 덮게 한다 — 확대해 놓고 종이 밖 허공을 보는 일이 없도록.
## 배율 1.0에서는 pan이 0으로 고정된다 (종이 = 뷰).
func _clamp_pan(pan: Vector2) -> Vector2:
	var span := size * _zoom - size   # 확대로 넘치는 양 (배율 1.0이면 0)
	return Vector2(
		clampf(pan.x, -maxf(span.x, 0.0), 0.0),
		clampf(pan.y, -maxf(span.y, 0.0), 0.0))


# ─────────────────────────── 방위 가이드 (배경 렌더) ───────────────────────────

## 캔버스 크기가 바뀌면 가이드를 다시 그린다 (시험대·드로잉룸 크기가 다르다)
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_set_view(_zoom, _pan)   # 크기가 바뀌면 이동 한계도 바뀐다 — 다시 가둔다
		queue_redraw()


## 종이 위 방위 안내 — **위 = 앞 = 탄이 가는 쪽** (v2.1 충격파 축).
## 획(자식 Line2D)은 이 위에 그려지므로 그린 먹선이 언제나 주인공이고 가이드는 참고선으로 남는다.
##
## 🔴 **화살표를 위에 그으면 적을 밀어내고, 아래에 그으면 나에게 끌어온다** — 화살표가
## **착탄 후 충격이 가는 쪽**이기 때문이다 (TECH_SPEC §4.0-b). 이 표시가 그 설계를 떠올리게 한다.
func _draw() -> void:
	# 가이드·본보기는 **종이에 인쇄된 것**이다 — 획과 같은 변환을 받아 함께 확대된다.
	# (배율 표시만 이 변환 밖에 있다. 아래 _draw_zoom_label 참고)
	draw_set_transform(_pan, 0.0, Vector2.ONE * _zoom)

	var c := size * 0.5
	var s := _canvas_scale()
	var m := s * GUIDE_MARGIN
	var font := ThemeDB.fallback_font
	var fs := maxi(int(s * GUIDE_FONT_RATIO), 7)

	# 중심 십자 — 진(원)을 그릴 자리를 암시한다
	draw_line(Vector2(c.x, m), Vector2(c.x, size.y - m), GUIDE_LINE, 1.0)
	draw_line(Vector2(m, c.y), Vector2(size.x - m, c.y), GUIDE_LINE, 1.0)
	draw_circle(c, GUIDE_DOT, GUIDE_LINE)

	# 위쪽(앞 = 탄이 가는 쪽)만 화살촉을 얹어 기준축임을 표시 — 나머지는 글자만
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
		_draw_trace_arrow(px, _trace_stage == Enums.DrawStage.ARROW)

	# 🔴 **내가 그린 문양에도 촉이 붙는다** — "이 획이 어디를 가리키는가"가 보여야 한다.
	# 문양은 방향을 가진 글자이고, 거꾸로 그으면 탄이 정반대로 날아간다. 그린 뒤에 그걸
	# 확인할 방법이 없으면 플레이어는 왜 빗나갔는지 영영 알 수 없다.
	# 촉은 인식기가 실제로 읽은 방향(InkRender.arrow_heading)을 그린다 — **보이는 게 진실이다.**
	# 먹선과 같은 색이라 내 획의 일부로 읽힌다 (딴 물건이 얹힌 게 아니다)
	var arrow_col: Color = ROLE_COLORS.get(Enums.StrokeRole.ARROW, Color.BLACK)
	for e in _entries:
		if int((e.result as Dictionary).get("role", -1)) != Enums.StrokeRole.ARROW:
			continue
		var stroke: StrokeData = e.stroke
		if stroke.points.size() < 2:
			continue
		_draw_heading_arrow(stroke.points[0] * s, InkRender.arrow_tip(stroke.points) * s,
			arrow_col, InkRender.BASE_WIDTH * 0.7)

	_draw_zoom_label(font, s)


## 🔴 **문양 본보기는 화살표다.** 작대기만 깔아 두면 어느 쪽이 시작인지 알 수 없고,
## **거꾸로 그으면 탄이 정반대로 날아간다** (사용자가 실제로 겪은 문제다).
## 촉을 **선과 같은 먹색·같은 굵기**로 그린다 — 색이 다르면 "선 + 딴 물건"으로 읽히지
## 화살표 하나로 안 보인다. 룬·진은 방향이 없는 글자라 안 그린다 (없는 방향을 있는 척할 순 없다).
func _draw_trace_arrow(px: PackedVector2Array, is_arrow: bool) -> void:
	if not is_arrow or px.size() < 2:
		return
	# 인식기가 실제로 겨누는 점(최원점)을 쓴다 — 관통‖은 촉이 아니라 창끝이 겨눈 곳이다.
	# 보이는 화살촉과 날아가는 방향이 갈라지면 본보기가 거짓말을 한다
	_draw_heading_arrow(px[0], InkRender.arrow_tip(px), TRACE_INK, TRACE_WIDTH)


## 시작점 → 겨눈 점을 화살촉으로. 발사각(InkRender.arrow_heading)과 **같은 두 점**을 쓴다
func _draw_heading_arrow(from: Vector2, tip: Vector2, col: Color, w: float) -> void:
	var dir := tip - from
	if dir.length_squared() < 4.0:
		return
	dir = dir.normalized()
	var side := dir.orthogonal()
	var len_px := maxf(_canvas_scale() * TRACE_HEAD, 5.0)
	draw_polyline(PackedVector2Array([
		tip - dir * len_px + side * len_px * 0.5, tip,
		tip - dir * len_px - side * len_px * 0.5,
	]), col, w, true)


func _guide_text(font: Font, fs: int, text: String, at: Vector2, col: Color, centered: bool) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := at
	if centered:
		pos.x -= w * 0.5
	pos.y += float(fs) * 0.35   # 베이스라인 → 시각적 중앙 보정
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## 배율 표시 — **확대 변환 밖**에서 그린다. 돋보기의 눈금은 종이에 인쇄된 게 아니라
## 들여다보는 사람 쪽에 있다: 4배로 확대해도 글자는 같은 크기로 구석에 남는다.
func _draw_zoom_label(font: Font, s: float) -> void:
	if _zoom <= ZOOM_MIN + ZOOM_EPS:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var fs := maxi(int(s * ZOOM_LABEL_RATIO), 8)
	var text := "×%.1f" % _zoom
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(size.x - w - float(fs) * 0.6, float(fs) * 1.4),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ZOOM_LABEL)


# ─────────────────────────── 본보기 얹기 (v1.7) ───────────────────────────

## 책자에서 고른 본보기를 **집는다** — 마우스에 붙어 따라다니고, 종이를 누르면 그 자리에 놓인다
## (스탬프와 같은 문법 — 사용자 확정). 놓인 본보기는 **자석이 된다**: 그 위를 손으로 그으면
## 획이 선으로 끌린다 (_append_live).
##
## 🔴 **본보기는 획이 아니다.** 잉크를 안 먹고, 인식되지도 않는다. 손으로 그어야 획이 된다 —
## 본보기는 손을 돕기만 한다. 획을 뗄 때 걷힌다 (한 획에 한 본보기).
##
## unit_pts: 중심 0 · 최장변 1 정규화 점열 (RuneTemplates.canonical()과 같은 좌표계).
## 크기는 **지금 종이 위에 있는 것**에서 출발한다 (진을 둘렀으면 그 진에 맞는 크기) —
## 하지만 **휠로 바꿀 수 있다.** 크기가 곧 농도(룬, v1.7)·세기(문양, v1.9)라서, 고정이면
## 다들 같은 크기로 그리게 되어 **그 두 축이 통째로 죽는다.**
func show_trace(stage: int, unit_pts: PackedVector2Array) -> void:
	if unit_pts.size() < 2:
		clear_trace()
		return
	_stamp_pending = {}          # 스탬프와 본보기를 동시에 들 수는 없다
	_trace_stage = stage
	_trace_held = {
		"unit": unit_pts,
		"span": _trace_span_for(stage),
		# 문양은 **위로 세워** 얹는다 — 캔버스 위쪽이 조준 방향이다 (GDD §4.1).
		# 본보기(canonical)는 +X 전진이므로 안 돌리면 옆으로 누워 버린다
		"rot": (-PI / 2.0) if stage == Enums.DrawStage.ARROW else 0.0,
	}
	_trace_placed = false
	_refresh_trace(_to_paper(get_local_mouse_position()))
	trace_changed.emit(true)


## 지금 종이 위에 있는 것에 맞는 기본 크기 — 진을 둘렀으면 그 진에 어울리는 크기로 시작한다
func _trace_span_for(stage: int) -> float:
	var has_circle := _parts.has("circle")
	match stage:
		Enums.DrawStage.RUNE:
			if has_circle:
				return float(_parts.circle.radius) * 2.0 * TRACE_RUNE_FRAC
			return TRACE_CIRCLE_SPAN * TRACE_RUNE_FRAC
		Enums.DrawStage.ARROW:
			if has_circle:
				# 그린 진을 확실히 뚫고 나가는 길이로 (짧으면 문양으로 인식되지 않는다)
				return maxf(TRACE_ARROW_SPAN, float(_parts.circle.radius) * 2.6)
			return TRACE_ARROW_SPAN
	return TRACE_CIRCLE_SPAN


## 본보기를 앵커 자리에 편다 (종이 정규 좌표). 들고 있는 동안엔 마우스가 앵커다
func _refresh_trace(paper_pos: Vector2) -> void:
	if _trace_held.is_empty():
		return
	var c := paper_pos / _canvas_scale()
	var span := float(_trace_held.span)
	var rot := float(_trace_held.rot)
	var unit: PackedVector2Array = _trace_held.unit
	_trace = PackedVector2Array()
	for p: Vector2 in unit:
		_trace.append(c + (p * span).rotated(rot))
	queue_redraw()


## 종이에 앉힌다 — 이제부터 이 선이 손을 끈다
func _place_trace_at(paper_pos: Vector2) -> void:
	_refresh_trace(paper_pos)
	_trace_held = {}
	_trace_placed = true
	var s := _canvas_scale()
	_trace_px = PackedVector2Array()
	for t: Vector2 in _trace:
		_trace_px.append(t * s)
	trace_changed.emit(true)


## 휠 = 크기 / **우클릭 누른 채 휠 = 회전** (사용자 확정).
## **크기가 곧 농도(룬)·세기(문양)**라 플레이어가 정해야 한다 (StrokeGuide 상단 계약)
func _adjust_trace(up: bool, rotating: bool, screen_pos: Vector2) -> void:
	if rotating:
		_rmb_turned = true      # 이번 우클릭은 회전용이었다 — 뗄 때 본보기를 물리지 않는다
		_trace_held["rot"] = wrapf(float(_trace_held.rot)
			+ (TRACE_ROT_STEP if up else -TRACE_ROT_STEP), -PI, PI)
	else:
		_trace_held["span"] = clampf(float(_trace_held.span)
			* (TRACE_SPAN_STEP if up else 1.0 / TRACE_SPAN_STEP),
			TRACE_SPAN_MIN, TRACE_SPAN_MAX)
	_refresh_trace(_to_paper(screen_pos))


## 🔴 완성된 도안을 **옅은 탁본**으로 깐다 — 그 위에 필사(따라 그리기)한다. 사용자 획과 같은
## _ink_layer에 넣어 줌·팬이 함께 걸리고, z_index로 내 획 뒤에 둔다. 순수 배경이라 _entries에
## 안 들어가고 인식·잉크·발사에 영향이 없다. 중첩 진은 자식까지 겹쳐 깐다 (착탄 그림 그대로).
func show_rubbing(design: SpellDesign) -> void:
	clear_rubbing()
	if design != null:
		_add_rubbing_strokes(design)
	queue_redraw()


func _add_rubbing_strokes(design: SpellDesign) -> void:
	var s := _canvas_scale()
	for stroke: StrokeData in design.strokes:
		if stroke.points.size() < 2:
			continue
		var line := Line2D.new()
		var px := PackedVector2Array()
		for p: Vector2 in stroke.points:
			px.append(p * s)
		line.points = px
		line.width = RUBBING_WIDTH
		line.default_color = RUBBING_INK
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		# ⚠ z_index를 음수로 두지 말 것 — 캔버스 종이 배경 **뒤로** 밀려 탁본이 안 보인다
		# (실측으로 잡음). 대신 _ink_layer의 맨 앞 자식으로 넣어 그리기 순서로만 내 획 뒤에 둔다.
		_ink_layer.add_child(line)
		_ink_layer.move_child(line, 0)
		_rubbing_lines.append(line)
	for child: SpellDesign in design.children:
		_add_rubbing_strokes(child)


func clear_rubbing() -> void:
	for l: Line2D in _rubbing_lines:
		if is_instance_valid(l):
			l.queue_free()
	_rubbing_lines.clear()


func has_rubbing() -> bool:
	return not _rubbing_lines.is_empty()


func clear_trace() -> void:
	_trace_held = {}
	_trace_placed = false
	_trace_stage = -1
	_trace_px = PackedVector2Array()
	if _trace.is_empty():
		return
	_trace = PackedVector2Array()
	queue_redraw()
	trace_changed.emit(false)


func has_trace() -> bool:
	return not _trace.is_empty()


## 본보기를 들고 있는 중인가 (아직 종이에 안 놓음) — 좌클릭이 획이 아니라 "놓기"가 된다
func is_holding_trace() -> bool:
	return not _trace_held.is_empty()


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
		# 휠 = 종이 확대. 획을 긋는 중에는 손대지 않는다 — 그리다 종이가 움직이면 획이 망가진다.
		# 단 **본보기를 들고 있으면 휠은 그 본보기의 크기**다 (Shift+휠 = 회전) — 크기가 곧
		# 농도(룬)·세기(문양)라 플레이어가 반드시 정할 수 있어야 한다 (StrokeGuide 상단 계약)
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			if is_holding_trace():
				_adjust_trace(true, _rmb_held, mb.position)
			elif not _drawing:
				zoom_at(mb.position, ZOOM_STEP)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			if is_holding_trace():
				_adjust_trace(false, _rmb_held, mb.position)
			elif not _drawing:
				zoom_at(mb.position, 1.0 / ZOOM_STEP)
			accept_event()
			return
		# 휠 클릭 드래그 = 종이 밀기. 좌클릭은 획, 우클릭은 취소라 남는 버튼이 이것뿐이다
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed and not _drawing
			_pan_from = mb.position
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if not _stamp_pending.is_empty():
					_place_stamp_at(_to_paper(mb.position))
				elif is_holding_trace():
					_place_trace_at(_to_paper(mb.position))   # 들고 있던 본보기를 종이에 놓는다
				else:
					_begin_stroke(_to_paper(mb.position))
			elif _drawing:
				_end_stroke()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			# 🔴 **우클릭은 더 이상 "뒤로가기"가 아니다** (사용자 확정 — 되돌리기는 Ctrl+Z만).
			# 대신 **누르고 있으면 휠이 회전**이 된다 (본보기를 들고 있을 때).
			# 누른 동안 휠을 굴렸다면 떼는 순간의 취소 동작은 건너뛴다 — 회전하려다 본보기를
			# 물려 버리면 손이 배신당한다
			if mb.pressed:
				_rmb_held = true
				_rmb_turned = false
			else:
				_rmb_held = false
				if not _rmb_turned:
					if _drawing:
						_cancel_stroke()
					elif not _stamp_pending.is_empty():
						_stamp_pending = {}
						stamp_placement_done.emit()
					elif has_trace():
						clear_trace()   # 들고 있던 / 놓아 둔 본보기를 걷는다
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			_set_view(_zoom, _pan + mm.relative)
			accept_event()
			return
		# 들고 있는 본보기는 마우스를 따라다닌다 (스탬프와 같은 문법)
		if is_holding_trace():
			_refresh_trace(_to_paper(mm.position))
			return
		if not _drawing:
			return
		if mm.pressure > 0.001:
			# 진짜 필압 장치 — 합성 경로를 끄고 압력을 그대로 쓴다
			_tablet = true
			_append_live(_to_paper(mm.position), mm.pressure)
		else:
			# 마우스: 이동 거리만 적립하고, 필압은 _process가 시간으로 굴린다.
			# **화면 픽셀 그대로 적립한다** — 필압은 손이 얼마나 빨리 움직였는가의 함수이고,
			# 손 속도는 종이를 확대해도 변하지 않는다. 종이 좌표로 재면 확대할수록 굵어져 버린다
			_moved_px += mm.relative.length()
			_append_live(_to_paper(mm.position), _cur_pressure)


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
	_live_ink = 0.0                    # 게이지 미리보기를 새 획으로 다시 센다
	_tablet = false
	_cur_pressure = 1.0                # 보통 속도의 필압에서 출발 — 툭 찍으면 1.0
	_moved_px = 0.0
	_live_line = InkStroke.new()
	_ink_layer.add_child(_live_line)
	_append_live(pos, _cur_pressure)
	set_process(true)                  # 그리는 동안에만 시간을 돌린다


## pos는 **종이 픽셀** (호출자가 _to_paper로 변환해 넘긴다)
func _append_live(pos: Vector2, pressure: float) -> void:
	var p := pos.clamp(Vector2.ZERO, size)
	# 🔴 본보기 자석 — **여기가 끌어당김이 일어나는 유일한 지점이다.** 그리는 중인 점이 전부
	# 여길 지나므로, 저장되는 획·보이는 먹선·인식·잉크가 전부 끌린 좌표로 일관된다.
	# 선에서 멀면 안 끌린다(SNAP_RADIUS) — 본보기가 손을 납치하면 안 된다.
	# _trace는 **정규 좌표**이고 p는 종이 픽셀이라 배율을 맞춰 넘긴다
	if _trace_placed and _trace_px.size() >= 2:
		p = StrokeGuide.pull(p, _trace_px, _correction_strength(),
			StrokeGuide.SNAP_RADIUS * _canvas_scale())
	# 최소 간격은 **화면 기준**으로 판정한다 — 확대하면 종이 좌표 간격이 그만큼 촘촘해져야
	# 손이 움직인 만큼 점이 찍힌다 (확대의 목적이 정밀도인데 여기서 다시 뭉개면 의미가 없다)
	var min_dist := MIN_PX_DIST / _zoom
	if not _live_points.is_empty() and _live_points[_live_points.size() - 1].distance_to(p) < min_dist:
		return
	var prev := _live_points[_live_points.size() - 1] if not _live_points.is_empty() else p
	_live_points.append(p)
	_live_pressures.append(pressure)
	_live_line.append_live(p)
	_accrue_live_ink(prev, p, pressure)


## 방금 그은 한 구간이 먹은 먹을 게이지에 즉시 얹는다 — **긋는 동안 게이지가 차오른다.**
## 계산은 확정 잉크(DesignBuilder.stroke_ink_units = ∫굵기 ds)와 **같은 공식**이다:
## 구간 길이(정규 좌표) × 그 구간의 붓 굵기 × 계수. 안 그러면 미리보기가 거짓말이 된다.
##
## ⚠ 마우스 획은 확정 시 필압이 **평균 1.0으로 정규화**되므로(_end_stroke), 미리보기에서도
## 굵기 1.0으로 본다 — 그래야 긋는 중 숫자와 뗀 뒤 숫자가 일치한다. 태블릿은 진짜 압력을 쓴다.
func _accrue_live_ink(prev: Vector2, p: Vector2, pressure: float) -> void:
	if _balance == null or _live_points.size() < 2:
		return
	var seg := prev.distance_to(p) / _canvas_scale()   # 종이 픽셀 → 정규 (잉크는 정규 기준)
	var w := 1.0
	if _tablet:
		var n := _live_pressures.size()
		w = clampf((_live_pressures[n - 2] + pressure) * 0.5, 0.15, 1.5)
	_live_ink += seg * w * _balance.ink_per_stroke_length
	ink_state_changed.emit(_ink_used + _live_ink, get_ink_capacity())


func _cancel_stroke() -> void:
	_drawing = false
	set_process(false)
	if _live_line != null:
		_live_line.queue_free()
		_live_line = null
	_clear_live_ink()


## 라이브 미리보기를 걷고 게이지를 확정값으로 되돌린다 (획 취소·무효 처리 후)
func _clear_live_ink() -> void:
	if _live_ink == 0.0:
		return
	_live_ink = 0.0
	ink_state_changed.emit(_ink_used, get_ink_capacity())


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
	# 원은 컨텍스트와 무관하게 먼저 가른다 — classify_stroke는 진이 이미 있으면 원을 감지하지
	# 않기 때문(§6.1). 이걸 안 하면 두 번째(안쪽/껍질) 원이 룬·화살표로 오인돼 중첩이 막힌다.
	var cdet := Recognizer.detect_circle(stroke.points)
	var pre: Dictionary
	var pre_role: int
	if cdet.is_circle:
		pre = {"role": Enums.StrokeRole.CIRCLE,
			"center": cdet.center, "radius": cdet.radius, "score": cdet.score}
		pre_role = Enums.StrokeRole.CIRCLE
	else:
		pre = Recognizer.classify_stroke(stroke.points, _recognizer_ctx())
		pre_role = int(pre.get("role", Enums.StrokeRole.DECOR))
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
	# 미리보기는 여기서 끝난다 — 아래 _reclassify_all → _recompute_ink가 **확정값**을 다시 쏜다.
	# 안 걷으면 이 획의 먹이 두 번 세어진다 (미리보기 + 확정)
	_live_ink = 0.0
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
	# 본보기는 **한 획을 돕고 걷힌다** — 놔두면 다음 획(다른 글자)까지 엉뚱하게 끌어당긴다.
	# 같은 글자를 또 그리려면 책자에서 다시 집는다 (집는 값이 싸므로 번거롭지 않다).
	# ⚠ 거부된 획(_reject_live_line 경로)에서는 **안 걷는다** — 다시 그려야 하니 남겨 둔다
	clear_trace()
	var res: Dictionary = entry.result
	var role := int(res.get("role", Enums.StrokeRole.DECOR))
	var bus := _bus()
	if bus != null:
		bus.emit_signal(&"recognition_result", role, role != Enums.StrokeRole.DECOR,
			float(res.get("score", 0.0)))
	stroke_classified.emit(res)


# ─────────────────────────── 상태 재구축 ───────────────────────────

func _reclassify_all() -> void:
	# 트리는 항상 조립한다 — 단계·수락(활성 노드)의 진실이 여기에 있다.
	_roots = DesignBuilder.assemble_tree(_entries)
	var nested := _count_circles(_roots) >= 2
	if nested:
		# 🔴 중첩 — 껍질(첫 루트)이 _parts. 노드 딕셔너리가 parts와 같은 키라 summary·렌더가 산다.
		_parts = _roots[0] if not _roots.is_empty() else _empty_parts()
		_apply_tree_results(_roots)
	else:
		# 단일 원 — 기존 경로 그대로 (e.result 세팅·_built id 재사용까지 보존)
		_parts = DesignBuilder.classify_entries(_entries)
	for e in _entries:
		_apply_style(e)
	var blocked := false
	var complete: bool = (not _roots.is_empty() and _roots[0].has("rune")) if nested \
		else DesignBuilder.is_complete(_parts)
	if complete:
		# 값을 아직 안 치른 종이에서만 보유를 따진다. 이미 치른 종이는 몇 번을 고쳐 그려도
		# 공짜다 — 종이는 이미 뜯었으니까 (undo → 재작성이 이중 과금되던 버그의 근본)
		var first := not _paper_charged
		if first and not _paper_available():
			_design = null
			blocked = true
		else:
			if nested:
				# 재귀 트리 — build_tree는 into(id 재사용)를 아직 안 받는다. 껍질+자식을 새로 짓는다.
				_built = DesignBuilder.build_tree(_roots[0], _balance, _paper_grade, _paper_params)
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


static func _empty_parts() -> Dictionary:
	return {"arrows": [], "extras": [], "strokes_ordered": []}


## 트리 전체의 원(진) 개수 — 2 이상이면 중첩이다
static func _count_circles(roots: Array) -> int:
	var n := 0
	for node: Dictionary in roots:
		n += 1 + _count_circles(node.children)
	return n


## 활성 노드 = **마지막으로 그린 원**의 노드. 단계·수락이 이걸 따른다 — 껍질을 완성한 뒤
## 안쪽 진을 그리면 그 안쪽 진을 채우는 중이므로. 원이 하나면 그 하나 = 루트(기존과 동일).
func _active_node() -> Dictionary:
	var last_circle: StrokeData = null
	for e in _entries:
		var s: StrokeData = e.stroke
		if s.role == Enums.StrokeRole.CIRCLE:
			last_circle = s
	if last_circle == null:
		return {}
	return _find_node_by_circle(_roots, last_circle)


static func _find_node_by_circle(roots: Array, circle_stroke: StrokeData) -> Dictionary:
	for node: Dictionary in roots:
		if node.circle.stroke == circle_stroke:
			return node
		var found := _find_node_by_circle(node.children, circle_stroke)
		if not found.is_empty():
			return found
	return {}


## 트리에서 각 획의 역할을 엔트리 result에 반영 — 스타일·자동보정이 e.result를 읽기 때문.
func _apply_tree_results(roots: Array) -> void:
	var by_id := {}
	for node: Dictionary in roots:
		_collect_node_results(node, by_id)
	for e in _entries:
		var s: StrokeData = e.stroke
		e["result"] = by_id.get(s.get_instance_id(), {"role": Enums.StrokeRole.DECOR})


func _collect_node_results(node: Dictionary, by_id: Dictionary) -> void:
	var cs: StrokeData = node.circle.stroke
	by_id[cs.get_instance_id()] = {
		"role": Enums.StrokeRole.CIRCLE,
		"center": node.circle.center, "radius": node.circle.radius,
	}
	if node.has("rune"):
		var rs: StrokeData = node.rune.stroke
		by_id[rs.get_instance_id()] = {
			"role": Enums.StrokeRole.RUNE,
			"rune_type": node.rune.type, "score": node.rune.accuracy_raw,
		}
	for a: Dictionary in node.arrows:
		var as_: StrokeData = a.stroke
		by_id[as_.get_instance_id()] = {"role": Enums.StrokeRole.ARROW, "direction": a.direction}
	for x: StrokeData in node.extras:
		by_id[x.get_instance_id()] = {"role": Enums.StrokeRole.DECOR}
	for child: Dictionary in node.children:
		_collect_node_results(child, by_id)


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
	if _roots.is_empty():
		return Enums.DrawStage.CIRCLE
	# 활성 노드(방금 그린 원)를 채우는 중이다 — 껍질을 다 그린 뒤 안쪽 진의 룬을 받으려면
	# 단계가 그 안쪽 진을 따라야 한다. 원이 하나면 활성 노드 = 루트 (기존과 동일).
	var active := _active_node()
	if active.is_empty() or not active.has("rune"):
		return Enums.DrawStage.RUNE
	return Enums.DrawStage.ARROW


## 이 단계에서 지금 무엇을 그려야 하는지 — 거부 메시지·안내 공용
static func stage_hint(stage: int) -> String:
	return STAGE_HINTS.get(stage, "")


## 이 역할의 획을 지금 단계에서 받을 수 있나. DECOR(인식 실패)는 어느 단계에서도 거부한다 —
## "장식으로 남았습니다"보다 "지금은 룬을 그릴 차례"가 플레이어에게 훨씬 쓸모 있다.
func _accepts_role(role: int) -> bool:
	# 🔴 원은 언제나 받는다 — 새 원은 **새 노드(껍질 또는 안쪽 진)**를 연다. 중첩의 관문.
	if role == Enums.StrokeRole.CIRCLE:
		return true
	var allowed: Array = STAGE_ROLES.get(get_stage(), [])
	return allowed.has(role)


## 현재 부품 상태 → 인식기 컨텍스트. classify_entries가 마지막에 도달했을 컨텍스트와 같다.
## 새 획을 **엔트리에 넣기 전에** 미리 채점해 단계 위반을 가려내기 위한 것.
func _recognizer_ctx() -> Dictionary:
	# 비원 획은 **활성 노드**(방금 그린 원) 컨텍스트로 미리 채점한다 — 안쪽 진에 그린 룬은
	# 안쪽 진 기준으로 판정돼야 한다. 원이 하나면 그 하나 = 기존과 동일.
	var active := _active_node()
	var ctx := {}
	if not active.is_empty():
		ctx["has_circle"] = true
		ctx["circle_center"] = active.circle.center
		ctx["circle_radius"] = active.circle.radius
		if active.has("rune"):
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
	_panning = false
	reset_view()      # 새 종이는 원래 크기로 편다 — 확대한 채로 다음 도안을 시작하지 않는다
	for e in _entries:
		var line := e.line as Line2D
		if line != null:
			line.queue_free()
	_entries.clear()
	_design = null
	# 종이를 새로 편다 — 다음 도안은 새 종이 값을 치른다
	_built = null
	_paper_charged = false
	clear_trace()                   # 본보기도 걷는다 (진이 사라져 앉을 자리가 없어졌다)
	clear_rubbing()                 # 탁본도 걷는다 — 새 종이엔 필사할 밑그림이 없다
	_roots = []
	_parts = _empty_parts()
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


## pos_px는 **종이 픽셀** (_gui_input이 _to_paper로 변환해 넘긴다 — 확대해도 찍히는 자리가 맞다)
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
	_ink_layer.add_child(entry.line)
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


## 획 자동보정 강도 — **아이템이 올린다**(좋은 붓), 그래서 GameState.stroke_correction()이
## 진실이다 (선례: hp_max·mana_max — TECH_SPEC §4.2 balance 직접 참조 금지).
## GameState가 없는 단독 테스트에서만 balance 기본값으로 폴백한다
func _correction_strength() -> float:
	var gs := _game_state()
	if gs != null and gs.has_method(&"stroke_correction"):
		return float(gs.call(&"stroke_correction"))
	return _balance.stroke_correct_strength


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
	_clear_live_ink()          # 무효 획은 먹을 안 먹는다 — 게이지도 되돌린다
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
