extends Control
## 고리 조립 보드 — forge 왼쪽 페이지에 얹히는 **조립 판**.
##
## 🔴 2026-07-17 세션 22 — **3분할됐다** (예전엔 757줄에 조립·채점·기하·렌더·입력·애니가 다 있었다):
##   • `ring_assembly.gd` — 조립 상태기계 (무엇이 놓였나 · 어느 칸이 열렸나). 순수 데이터
##   • `trace_scorer.gd`  — 손그림 탁본 채점 (완성도·정밀도·분석). 순수 수학
##   • **이 파일**         — 기하(어디에 그리나) + `_draw` + `_gui_input` + 애니. 위 둘에 위임한다
## 🔴 **채점 규칙을 바꿀 땐 `trace_scorer.gd`만 연다** — 그리는 재미가 이 게임의 심장이라
## 그 규칙은 매 세션 바뀐다([[takbon-core-fun-drawing]]). 렌더·입력을 열 필요가 없어야 한다.
##
## 모델·규칙의 정본은 각 파일 머리말에 있다. 여기 남은 건 **화면 위의 일**뿐이다.
##
## 🔴 이 보드는 **선택을 스스로 쥐지 않는다.** 문양본·활성 문양은 바깥(오른쪽 탭)이 set_*로
## 주입한다. 오토로드·모듈 의존 없음.
##
## 사용: const RingBoard := preload("res://src/drawing/ring_board.gd")

const RingAssembly := preload("res://src/drawing/ring_assembly.gd")
const TraceScorer := preload("res://src/drawing/trace_scorer.gd")

# ── 조립 계약 재노출 — 바깥(패널·책·테스트)이 RingBoard.STAGE_*/TEMPLATES로 읽어 왔다 ──
const SLOTS := RingAssembly.SLOTS
const GLYPH_NONE := RingAssembly.GLYPH_NONE
const STAGE_JIN := RingAssembly.STAGE_JIN
const STAGE_RUNE := RingAssembly.STAGE_RUNE
const STAGE_GLYPH := RingAssembly.STAGE_GLYPH
const TEMPLATES := RingAssembly.TEMPLATES
const RUNE_FIRE := RingAssembly.RUNE_FIRE
const COMMIT_COVER := TraceScorer.COMMIT_COVER

# ── 어휘 2종 (사용자 확정 2026-07-16) ──
## 🔴 값은 **core가 쥔다**(Enums.GlyphCode = 발사 계약). 여기서 다시 정의하면 언젠가 갈라진다.
const G_GATHER := Enums.GlyphCode.GATHER    # 응집 ← — 안쪽(룬) 방향 화살표
const G_RADIATE := Enums.GlyphCode.RADIATE  # 발산 → — 바깥(진) 방향 화살표
const GLYPH_NAMES := ["응집←", "발산→"]
const GLYPH_KEYS := ["Q", "W"]

# ── 색 (먹·양피지 톤) ──
const RING_LINE := Color(0.42, 0.30, 0.12, 0.55)
const SLOT_OPEN := Color(0.42, 0.30, 0.12, 0.5)    # 열린 빈 칸 — 여기 채워라
const FIRE_HI := Color(0.95, 0.55, 0.15)
const GLYPH_COLORS := [
	Color(0.16, 0.34, 0.55),   # 응집 = 남색
	Color(0.72, 0.28, 0.12),   # 발산 = 주홍
]
const RUNE_COLOR := Color(0.62, 0.22, 0.12)   # 불
const TRACE_INK := Color(0.20, 0.14, 0.09, 0.95)    # 그린 먹선
const GUIDE_HIDE := Color(0.42, 0.30, 0.12, 0.18)   # 숨은 가이드 (아직 안 드러남)
const GUIDE_SHOW := Color(0.80, 0.50, 0.16, 0.55)   # 드러난 가이드 강조

const RING_RADIUS_FRAC := 0.60
const GUIDE_CIRCLE_N := 72            # 진(원) 가이드 밀도

# ── 마우스 휠 크기 조절 (진·룬, 세션 14c) ──
const JIN_SCALE_MIN := 0.72
const JIN_SCALE_MAX := 1.16
const RUNE_SCALE_MIN := 0.55
const RUNE_SCALE_MAX := 1.70
const SCALE_STEP := 0.06
# ── 문양 개별 크기 (칸마다, 세션 15 — 사용자: "문양 모양이 주된 과제 · 각각으로") ──
const GLYPH_SCALE_MIN := 0.55
const GLYPH_SCALE_MAX := 1.85

## 🔴 칸을 고르는 **최대 거리** (세션 22, I3 버그 수정). 이 밖을 클릭하면 칸을 안 바꾼다.
## 예전엔 컷오프가 없어서 판 아무 데나 클릭해도 최근접 열린 칸이 잡혔고, select_slot이
## 현재 칸 coverage > COMMIT_COVER면 **자동 확정**해 버렸다 → **칸 0을 그리다 획을 칸 2 쪽에
## 조금 가깝게 시작하면 칸 0이 멋대로 확정되고 넘어갔다.** *"마음에 들 때까지 다시 그린다"*
## 설계와 정면 충돌. 값은 아래 칸 표시(ro*0.05)·강조(ro*0.11)와 맞췄다.
const SLOT_PICK_FRAC := 0.18

## 지금 손으로 그릴 대상. NONE=그릴 것 없음(문양본 대기 / 다 그림)
enum TraceTarget { NONE, JIN, RUNE, GLYPH }

signal assembly_changed
## 단계가 넘어갔다 — 바깥(패널)이 오른쪽 탭·안내문을 맞춘다. (STAGE_*)
signal stage_advanced(stage: int)
## 지금 그리는 조각의 점수가 갱신됐다 (실시간) — 패널이 현재 점수를 보여준다.
signal score_changed(score: float)
## 한 조각을 [다음]으로 잠갔다 — 패널이 손맛 피드백을 준다. (TraceTarget·칸·그 조각 점수)
signal piece_locked(target: int, slot: int, score: float)
## 마법진을 다 그렸다 — 패널이 분석 리포트를 띄운다. (get_analysis 결과)
signal finished(analysis: Dictionary)

var _asm := RingAssembly.new()
var _scorer := TraceScorer.new()

# ── 데이터 정의 (세션 13 구조화) — 바깥(패널)이 Db에서 읽어 주입한다. 없으면 const 폴백. ──
var _jin_def: JinDef = null
var _rune_def: RuneDef = null
var _glyph_defs: Array[GlyphDef] = []

var _active := G_RADIATE            # 활성 문양 코드 (바깥이 set_active_glyph으로 정한다)
var _cast_t := -1.0
var _cast_dur := 1.3

var _trace := TraceTarget.NONE          # 지금 그릴 대상
var _trace_slot := -1                   # GLYPH일 때 채울 칸
var _drawing := false                   # 마우스 버튼 누른 채 긋는 중
var _jin_scale := 1.0                   # 진 크기 (마우스 휠)
var _rune_scale := 1.0                  # 룬 크기 (마우스 휠)
var _glyph_scale: Dictionary = {}       # slot(int) → float, 문양 개별 크기 (마우스 휠, 세션 15)

# ── 착지 펄스 ("탁") — 조각이 놓인 자리에서 퍼지는 고리 ──
var _pulse_t := -1.0
var _pulse_at := Vector2.ZERO
const PULSE_DUR := 0.28


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	set_process(false)
	resized.connect(_on_resized)


## 판 크기가 바뀌면 채점기의 길이 기준과 가이드를 다시 세운다 (거리 임계값이 전부 반지름 비례다).
func _on_resized() -> void:
	_scorer.set_reference_radius(_outer_radius())
	_set_trace(_trace, _trace_slot)
	queue_redraw()


# ─────────────────────────── 단계 조회 (조립 상태기계에 위임) ───────────────────────────

func stage() -> int:
	return _asm.stage()

func has_jin() -> bool:
	return _asm.has_jin()

func has_rune() -> bool:
	return _asm.has_rune()

func get_open() -> Array[int]:
	return _asm.get_open()

func get_rune() -> int:
	return _asm.get_rune()

func filled_count() -> int:
	return _asm.filled_count()

func can_commit() -> bool:
	return _asm.can_commit()

## 🔴 발사 계약 + **손그림 점수**. 조립기(무엇이 놓였나)와 채점기(얼마나 잘 그렸나)를 합치는
## 유일한 자리 — 둘 다 쥔 게 보드뿐이다 (조립기는 채점을 모르고, 채점기는 칸을 모른다).
## `score`가 여기서 안 실리면 발사도 저장도 점수를 알 길이 없다 (세션 22까지가 그랬다).
## ⚠ 그리는 도중에 불리면 그때까지의 부분 점수다 — 소비자는 맺을 때만 읽는다.
func get_assembly() -> Dictionary:
	var a := _asm.get_assembly()
	a["score"] = float(get_analysis().get("total", 0.0))
	return a


# ─────────────────── 손그림 탁본 — 무엇을 그릴지 정하고 가이드를 세운다 ───────────────────

## 🔴 지금 단계에 맞는 가이드를 세운다 — 무엇을 그릴지 정하고 문지름 상태를 리셋한다.
func _refresh_trace() -> void:
	match _asm.stage():
		STAGE_JIN:
			if not _asm.has_jin():
				_set_trace(TraceTarget.JIN, -1)
				return
		STAGE_RUNE:
			if not _asm.has_rune():
				_set_trace(TraceTarget.RUNE, -1)
				return
		STAGE_GLYPH:
			var k := _asm.next_open_slot()
			if k >= 0:
				_set_trace(TraceTarget.GLYPH, k)
				return
	_set_trace(TraceTarget.NONE, -1)   # 그릴 것 없음 (문양본 대기 / 다 그림)


## 가이드 대상을 세우고 숨은 선 점을 만든 뒤 문지름 상태를 비운다.
## 🔴 여기서 **장착한 펜의 보정도**도 물려 준다 (세션 23) — 조각을 새로 잡을 때마다 다시 읽어,
## 그리는 도중에 펜을 갈아 껴도 다음 조각부터 반영된다. 채점기는 아이템을 모른다(숫자만 받는다).
func _set_trace(target: int, slot: int) -> void:
	_trace = target
	_trace_slot = slot
	_scorer.set_reference_radius(_outer_radius())
	_scorer.set_correction(_pen_correction())
	_scorer.set_guide(_build_guide(target, slot))


## 장착한 펜의 보정도. 오토로드가 없는 환경(순수 단위 테스트)에서도 죽지 않게 0으로 폴백한다.
func _pen_correction() -> float:
	var gs := get_node_or_null(^"/root/GameState")
	return float(gs.stroke_correction()) if gs != null else 0.0


## 대상별 숨은 정답 선 (조밀, 로컬 좌표). 이 위를 문지르면 드러난다.
func _build_guide(target: int, slot: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var ctr := _area_center()
	var ro := _outer_radius()
	match target:
		TraceTarget.JIN:
			# 바깥 원 둘레 (닫힌 고리) — 휠 크기 반영
			var jr := _jin_radius()
			for i in GUIDE_CIRCLE_N + 1:
				pts.append(ctr + Vector2.from_angle(TAU * float(i) / float(GUIDE_CIRCLE_N)) * jr)
		TraceTarget.RUNE:
			# 중심 삼각형 세 변 (_draw_rune과 같은 꼭짓점) — 변마다 촘촘히, 닫힌 형. 휠 크기 반영
			var s := _rune_size()
			var v := PackedVector2Array([
				ctr + Vector2(0, -s), ctr + Vector2(s * 0.87, s * 0.5),
				ctr + Vector2(-s * 0.87, s * 0.5), ctr + Vector2(0, -s)])
			for e in 3:
				for t in 12:
					pts.append(v[e].lerp(v[e + 1], float(t) / 12.0))
			pts.append(v[3])
		TraceTarget.GLYPH:
			# 그 칸의 화살표 선
			if slot >= 0:
				var p := _slot_pos(slot)
				var outward := Vector2.from_angle(_slot_angle(slot))
				var sz := ro * 0.12 * _glyph_scale_of(slot)
				for t in 13:
					pts.append((p - outward * sz).lerp(p + outward * sz, float(t) / 12.0))
	return pts


## 지금 그릴 대상·현재 점수 조회 (바깥이 안내문·점수 표시에 쓴다).
func trace_target() -> int:
	return _trace

func trace_slot() -> int:
	return _trace_slot

func is_tracing() -> bool:
	return _trace != TraceTarget.NONE

func coverage() -> float:
	return _scorer.coverage()

func accuracy() -> float:
	return _scorer.accuracy()

func piece_score() -> float:
	return _scorer.piece_score()

## 지금 가이드 점들 (로컬 좌표) — 헤드리스 테스트가 이 위로 가짜 문지름을 태운다.
func guide_points() -> PackedVector2Array:
	return _scorer.guide_points()

## 잠긴 손그림 조각 수 = 화면에 남아 있는 먹선 줄 수. 재편집이 **덮어쓰는지**(중복 추가가
## 아닌지) 보는 관측점 — 테스트가 쓴다.
func locked_count() -> int:
	return _scorer.locked_pieces().size()


# ─────────────────────────── 문지르기 (채점기에 위임) ───────────────────────────

## 🔴 새 획을 시작한다 (마우스 누름) = **다시 그리기**. 이전 문지름을 덮어쓴다.
## 마음에 들 때까지 다시 그리고 [다음]으로 잠근다 (사용자 확정).
func begin_stroke() -> void:
	_scorer.reset_stroke()
	score_changed.emit(0.0)


## 한 점을 그었다 (드래그). public — 헤드리스 테스트가 가짜 궤적을 태운다.
func trace_stroke(local_pos: Vector2) -> void:
	if _trace == TraceTarget.NONE:
		return
	if not _scorer.add_point(local_pos):
		return   # 가이드에서 너무 멀다 = 이 조각과 무관
	queue_redraw()
	score_changed.emit(_scorer.piece_score())


# ─────────────────────────── [다음] 수동 진행 · 분석 ───────────────────────────

## 🔴 지금 조각을 잠그고(점수 저장) 다음으로 넘어간다 ([다음]). 반환:
##   "advanced" = 다음 조각 · "finished" = 마지막이라 다 그림(분석) · "none" = 그릴 게 없음
func advance() -> String:
	if _trace == TraceTarget.NONE:
		return "none"
	var done := _trace
	var slot := _trace_slot
	var sc := _lock_current()
	match done:
		TraceTarget.JIN:
			_asm.lock_jin()
			_start_pulse(_area_center())
			stage_advanced.emit(_asm.stage())
		TraceTarget.RUNE:
			_asm.lock_rune()
			_start_pulse(_area_center())
			stage_advanced.emit(_asm.stage())
		TraceTarget.GLYPH:
			if slot >= 0:
				_asm.place_glyph(slot, _active)
				_start_pulse(_slot_pos(slot))
	_refresh_trace()
	piece_locked.emit(done, slot, sc)
	assembly_changed.emit()
	queue_redraw()
	if _trace == TraceTarget.NONE:
		finished.emit(get_analysis())
		return "finished"
	return "advanced"


## 🔴 지금 그리던 문양 칸까지 잠그고 마법진을 **끝낸다** (맺기 — 남은 칸은 비운 채). 분석을 낸다.
## 진·룬이 잠겨 있어야 한다(can_commit) — 바깥(패널)이 게이트한다.
func finish() -> Dictionary:
	if _trace == TraceTarget.GLYPH and _trace_slot >= 0 and _scorer.coverage() > 0.0:
		_lock_current()
		_asm.place_glyph(_trace_slot, _active)
		_start_pulse(_slot_pos(_trace_slot))
	_trace = TraceTarget.NONE
	_trace_slot = -1
	queue_redraw()
	# 🔴 M6 (세션 22): 여기서 _slots가 바뀌는데 예전엔 assembly_changed를 안 쏴서 advance()와
	# 불일치였다. 지금은 증상이 없지만 구독자가 늘면 [맺기] 경로만 갱신을 놓친다.
	assembly_changed.emit()
	var a := get_analysis()
	finished.emit(a)
	return a


## 마법진 분석 리포트 — 조각별 점수 + 종합 + 등급 (채점기가 계산, 열린 칸은 조립기가 안다).
func get_analysis() -> Dictionary:
	return _scorer.get_analysis(_asm.get_open())


# ─────────────────── 문양 칸 자유 편집 (칸 클릭 → 골라 다시 그림, 세션 15) ───────────────────
## 🔴 문양 단계에서 **아무 칸이나 골라** 편집한다 (사용자 확정: "칸클릭 문양 선택하고 내가 다시그림").
## 그리던 칸을 충분히 그렸으면 먼저 자동으로 잠그고 넘어간다. 이미 채운 칸도 다시 골라 덮어 그린다.
## public — 보드 입력(_gui_input)과 헤드리스 테스트가 부른다.
func select_slot(k: int) -> void:
	if _asm.stage() != STAGE_GLYPH or not _asm.is_open_slot(k) or k == _trace_slot:
		return
	if _trace == TraceTarget.GLYPH and _trace_slot >= 0 and _scorer.coverage() > COMMIT_COVER:
		_commit_glyph_slot(_trace_slot)         # 그리던 칸을 먼저 확정
	_set_trace(TraceTarget.GLYPH, k)            # 고른 칸에 화살표 가이드를 세운다(그 칸 크기로)
	queue_redraw()
	score_changed.emit(_scorer.piece_score())


## 문양 칸 하나를 잠근다 (그린 먹선·문양·점수 저장). advance()의 문양 확정과 같되 단계는 안 넘긴다.
func _commit_glyph_slot(slot: int) -> void:
	var sc := _lock_current()
	_asm.place_glyph(slot, _active)
	_start_pulse(_slot_pos(slot))
	piece_locked.emit(TraceTarget.GLYPH, slot, sc)
	assembly_changed.emit()


## 지금 조각의 점수·먹선을 채점기에 잠근다. 반환 = 그 조각 점수.
func _lock_current() -> float:
	return _scorer.lock(_piece_key(_trace, _trace_slot), _trace, _trace_slot,
		_active if _trace == TraceTarget.GLYPH else -1)


func _piece_key(target: int, slot: int) -> String:
	match target:
		TraceTarget.JIN:
			return TraceScorer.KEY_JIN
		TraceTarget.RUNE:
			return TraceScorer.KEY_RUNE
		TraceTarget.GLYPH:
			return TraceScorer.glyph_key(slot)
	return "?"


## 🔴 클릭 위치에서 가장 가까운 열린 칸 — **너무 멀면 -1** (I3 버그 수정, 세션 22).
## -1이면 칸을 안 바꾸고 현재 칸을 계속 그린다.
func _nearest_open_slot(pos: Vector2) -> int:
	var best := -1
	var best_d2 := INF
	for k in _asm.get_open():
		var d2 := pos.distance_squared_to(_slot_pos(k))
		if d2 < best_d2:
			best_d2 = d2
			best = k
	var max_d := _outer_radius() * SLOT_PICK_FRAC
	if best_d2 > max_d * max_d:
		return -1
	return best


# ─────────────────────────── 데이터 주입 (Db → 보드) ───────────────────────────

## 진·룬·문양 정의를 주입한다 (색·이름을 여기서 읽는다). 슬롯은 여전히 int code로 저장 —
## 발사 계약(assembly의 정수)은 그대로다. defs 없으면 아래 색 헬퍼가 const로 폴백한다.
func set_defs(jin: JinDef, rune: RuneDef, glyph_defs: Array) -> void:
	_jin_def = jin
	_rune_def = rune
	_glyph_defs.clear()
	for d in glyph_defs:
		var gd := d as GlyphDef
		if gd:
			_glyph_defs.append(gd)
	queue_redraw()


func _jin_color() -> Color:
	return _jin_def.ui_color if _jin_def else RING_LINE

func _rune_color() -> Color:
	return _rune_def.ui_color if _rune_def else RUNE_COLOR

func _glyph_def_by_code(code: int) -> GlyphDef:
	for d in _glyph_defs:
		if d.code == code:
			return d
	return null

func _glyph_color(code: int) -> Color:
	var d := _glyph_def_by_code(code)
	if d:
		return d.ui_color
	return GLYPH_COLORS[clampi(code, 0, GLYPH_COLORS.size() - 1)]


# ─────────────────────────── 바깥이 주입하는 선택 ───────────────────────────

func set_active_glyph(g: int) -> void:
	_active = clampi(g, 0, GLYPH_NAMES.size() - 1)
	queue_redraw()


## 🔴 문양본을 삽입한다 — 이 칸들만 열린다. 닫힌 칸의 문양은 걷어낸다.
func set_template(open_slots: Array) -> void:
	_asm.set_template(open_slots)
	_refresh_trace()                     # 새로 열린 칸의 첫 빈 칸에 문양 유령을 세운다
	queue_redraw()
	assembly_changed.emit()


func clear_all() -> void:
	_asm.clear()
	_scorer.clear()
	_jin_scale = 1.0
	_rune_scale = 1.0
	_glyph_scale = {}
	_pulse_t = -1.0
	_refresh_trace()                     # 진 가이드부터 다시 세운다
	queue_redraw()
	stage_advanced.emit(_asm.stage())
	assembly_changed.emit()


func ring_summary() -> String:
	var counts := {G_GATHER: 0, G_RADIATE: 0}
	var open := _asm.get_open()
	for k in open:
		var g := _asm.glyph_at(k)
		if g != GLYPH_NONE:
			counts[g] += 1
	var parts: Array[String] = []
	for g in GLYPH_NAMES.size():
		if counts[g] > 0:
			parts.append("%s×%d" % [GLYPH_NAMES[g], counts[g]])
	if parts.is_empty():
		return "빈 진" if open.is_empty() else "빈 칸 %d" % open.size()
	return " ".join(parts)


# ─────────────────────────── 기하 ───────────────────────────

func _area_center() -> Vector2:
	return size * 0.5

func _outer_radius() -> float:
	return minf(size.x, size.y) * 0.44

## 진 반지름 — 마우스 휠 크기 반영. 룬·고리·칸은 기준(_outer_radius)에 고정된다.
func _jin_radius() -> float:
	return _outer_radius() * _jin_scale

## 룬 삼각 크기 — 마우스 휠 반영.
func _rune_size() -> float:
	return _outer_radius() * 0.16 * _rune_scale

## 문양 칸 하나의 개별 크기 배율 (휠, 기본 1.0). 세션 15.
func _glyph_scale_of(slot: int) -> float:
	return float(_glyph_scale.get(slot, 1.0))

func _ring_radius() -> float:
	return _outer_radius() * RING_RADIUS_FRAC

func _slot_angle(k: int) -> float:
	return TAU * float(k) / float(SLOTS) - PI / 2.0

func _slot_pos(k: int) -> Vector2:
	return _area_center() + Vector2.from_angle(_slot_angle(k)) * _ring_radius()


# ─────────────────────────── 입력 (손으로 숨은 선 문지르기) ───────────────────────────
## 🔴 좌클릭 드래그로 가이드를 문지르면 먹선이 남는다. 누를 때마다 = 다시 그리기(덮어씀).
## 확정은 자동이 아니다 — 패널의 [다음]이 advance()를 부른다.

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			# 🔴 문양 단계 — 누른 자리의 칸을 골라 편집한다 (세션 15). 다른 칸이면 이전 칸 자동 확정.
			# ⚠ 칸에서 멀면 _nearest_open_slot이 -1을 준다 → 칸을 안 바꾸고 현재 칸을 계속 그린다
			#   (세션 22 I3: 컷오프가 없어서 획 시작점이 옆 칸에 조금 가까우면 현재 칸이 멋대로 확정됐다).
			if _asm.stage() == STAGE_GLYPH:
				var k := _nearest_open_slot(mb.position)
				if k >= 0 and k != _trace_slot:
					select_slot(k)
			_drawing = true
			begin_stroke()                # 새 획 = 다시 그리기 (이전 문지름 덮어씀)
			trace_stroke(mb.position)
		else:
			_drawing = false
		accept_event()
		return
	# 🔴 마우스 휠 — 지금 그릴 조각(진/룬/문양 칸)의 크기 조절 (세션 14c·15)
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_resize_current(SCALE_STEP)
		accept_event()
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_resize_current(-SCALE_STEP)
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _drawing:
		trace_stroke(mm.position)
		accept_event()


## 지금 그리는 조각의 크기를 바꾼다 — 가이드를 새 크기로 다시 세운다(현재 획은 지워짐).
func _resize_current(delta: float) -> void:
	match _trace:
		TraceTarget.JIN:
			_jin_scale = clampf(_jin_scale + delta, JIN_SCALE_MIN, JIN_SCALE_MAX)
		TraceTarget.RUNE:
			_rune_scale = clampf(_rune_scale + delta, RUNE_SCALE_MIN, RUNE_SCALE_MAX)
		TraceTarget.GLYPH:
			# 🔴 문양은 **칸마다 개별** 크기 (세션 15). 지금 고른 칸의 화살표만 키운다.
			if _trace_slot < 0:
				return
			_glyph_scale[_trace_slot] = clampf(_glyph_scale_of(_trace_slot) + delta,
				GLYPH_SCALE_MIN, GLYPH_SCALE_MAX)
		_:
			return   # 없음 단계(문양본 대기/완성)에선 휠 무시
	_set_trace(_trace, _trace_slot)   # 새 크기로 가이드 재생성
	queue_redraw()


# ─────────────────────────── 발사 스윕 · 착지 펄스 ───────────────────────────

func play_cast() -> void:
	_cast_t = 0.0
	set_process(true)


func _start_pulse(at: Vector2) -> void:
	_pulse_at = at
	_pulse_t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	var busy := false
	if _cast_t >= 0.0:
		_cast_t += delta / _cast_dur
		if _cast_t >= 1.0:
			_cast_t = -1.0
		else:
			busy = true
	if _pulse_t >= 0.0:
		_pulse_t += delta / PULSE_DUR
		if _pulse_t >= 1.0:
			_pulse_t = -1.0
		else:
			busy = true
	if not busy:
		set_process(false)
	queue_redraw()


# ─────────────────────────── 렌더 ───────────────────────────

func _draw() -> void:
	var ctr := _area_center()
	var ro := _outer_radius()

	if _cast_t >= 0.0:
		draw_arc(ctr, maxf(_cast_t * (ro * 1.12), 1.0), 0.0, TAU, 64,
			Color(FIRE_HI, 0.5), 3.0, true)

	# 🔴 잠근 조각들 — **그린 먹선을 그대로** 유지한다 (정답 모양으로 안 바꾼다).
	# 단, 지금 다시 그리는 칸/조각은 아래 '지금 그리는 조각'이 새 먹선으로 보여주니 건너뛴다.
	for L in _scorer.locked_pieces():
		if L.target == _trace and L.slot == _trace_slot:
			continue
		_draw_locked(L)

	# 구조 힌트 — 룬까지 그렸으면(문양 단계) 1차 고리 + 열린 빈 칸 위치만 연하게 안내
	if _asm.has_rune():
		draw_arc(ctr, _ring_radius(), 0.0, TAU, 64, RING_LINE, 1.0, true)
		for k in _asm.get_open():
			if _asm.glyph_at(k) == GLYPH_NONE:
				draw_arc(_slot_pos(k), ro * 0.05, 0.0, TAU, 16, SLOT_OPEN, 1.5, true)
		# 🔴 지금 고른(편집 중인) 문양 칸을 강조한다 — 어느 칸을 그리는지 보이게 (세션 15)
		if _trace == TraceTarget.GLYPH and _trace_slot >= 0:
			draw_arc(_slot_pos(_trace_slot), ro * 0.11, 0.0, TAU, 24, Color(FIRE_HI, 0.7), 1.5, true)

	# 🔴 지금 그리는 조각 — 숨은 정답 선(연하게) + 드러난 점(주황) + **그린 먹선 그대로**
	var guide := _scorer.guide_points()
	if _trace != TraceTarget.NONE and guide.size() >= 2:
		draw_polyline(guide, GUIDE_HIDE, 2.0, true)
		for i in guide.size():
			if _scorer.is_revealed(i):
				draw_circle(guide[i], 1.6, GUIDE_SHOW)
		var ink := _scorer.ink()
		if ink.size() >= 2:
			draw_polyline(ink, TRACE_INK, 2.6, true)

	# 착지 펄스 ("탁") — 조각이 놓인 자리에서 퍼지는 밝은 고리
	if _pulse_t >= 0.0:
		draw_arc(_pulse_at, maxf(_pulse_t * (ro * 0.34), 1.0), 0.0, TAU, 28,
			Color(FIRE_HI, (1.0 - _pulse_t) * 0.85), 2.5, true)


## 🔴 잠근 조각 = **그린 먹선 그대로** 렌더 (정답 모양 교체 없음). 색은 조각 종류로 구분.
func _draw_locked(L: TraceScorer.LockedPiece) -> void:
	if L.ink.size() < 2:
		return
	var col := TRACE_INK
	match L.target:
		TraceTarget.JIN:
			col = _jin_color()
		TraceTarget.RUNE:
			col = _rune_color()
		TraceTarget.GLYPH:
			col = _glyph_color(L.glyph)
	draw_polyline(L.ink, col, 2.8, true)
