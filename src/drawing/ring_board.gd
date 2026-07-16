extends Control
## 고리 조립 보드 — forge 왼쪽 페이지에 얹히는 **조립 판** (2026-07-16 방향 전환 · 세션 13 순차 조립).
##
## 자유 손그림+인식이 아니라 **고정 칸에 조각을 얹어 조립**한다 (사용자 확정):
##   • 진 = **일반진 하나**(그냥 동그라미. 스파이크 없음) — 바깥 그릇(경계)
##   • 룬 = 중심(지금은 **불만**)
##   • 🔴 **문양본(틀)이 칸을 연다** — 2방 문양본 = 정해진 2자리만 열림 (스텐실). 문양본 없으면
##     빈 진(그냥 날아가 맞기만). 문양본을 얻어 삽입할수록 열리는 자리가 넓어진다 (2방→4방→8방).
##   • 문양 = 열린 칸을 채우는 조각 (응집←/발산→). 낮에 탁본으로 얻은 것으로 채운다.
##
## 🔴 세션 13 — **순차 조립** (사용자: "진 → 룬 → 문양 하나씩 넣기, 이전에 그렇게 했었다"):
##   빈 판에서 시작해 **진을 놓고 → 룬을 놓고 → 문양을 한 칸씩** 얹는다. 이전 일괄 자동채움
##   (apply_ring: 열린 칸 전부 한 번에)이 "툭 완성"돼 조립하는 맛을 죽였다 — 걷어냈다.
##   조각이 놓일 때마다 착지 펄스("탁")로 손맛을 준다.
##
## 🔴 이 보드는 **선택을 스스로 쥐지 않는다.** 문양본·활성 문양은 바깥(오른쪽 탭)이 set_*로
## 주입한다. 오토로드·모듈 의존 없음.
##
## 사용: const RingBoard := preload("res://src/drawing/ring_board.gd")

const SLOTS := 8
const GLYPH_NONE := -1

# ── 조립 단계 — 옛 자유드로잉과 **같은 문법**(Enums.DrawStage 재사용, 세션 13):
##   진(CIRCLE) → 룬(RUNE) → 문양(ARROW). 옛 캔버스가 이 순서를 강제하던 그 열거형이다.
const STAGE_JIN := Enums.DrawStage.CIRCLE    # 진(그릇)을 놓을 차례
const STAGE_RUNE := Enums.DrawStage.RUNE     # 룬(중심)을 놓을 차례
const STAGE_GLYPH := Enums.DrawStage.ARROW   # 문양을 한 칸씩 얹을 차례

# ── 어휘 2종 (사용자 확정 2026-07-16) ──
## 🔴 값은 **core가 쥔다**(Enums.GlyphCode = 발사 계약). 여기서 다시 정의하면 언젠가 갈라진다 —
## 세션 22 전까지 발사(ring_spell_system)가 이 상수를 꺼내려고 보드 전체를 preload하고 있었다.
const G_GATHER := Enums.GlyphCode.GATHER    # 응집 ← — 안쪽(룬) 방향 화살표
const G_RADIATE := Enums.GlyphCode.RADIATE  # 발산 → — 바깥(진) 방향 화살표
const GLYPH_NAMES := ["응집←", "발산→"]
const GLYPH_KEYS := ["Q", "W"]

const RUNE_FIRE := 0   # 지금은 불만

## 🔴 문양본(틀) — 각 틀이 **어느 칸을 여는지** 정한다 (칸 0=위, 시계방향으로 2=오른쪽…).
## 얻어서 삽입한다. 배치가 곧 콘텐츠 — 2방은 좁고 8방은 전방위. (지금은 전부 보유로 친다.)
const TEMPLATES := [
	{"name": "2방", "slots": [0, 2]},          # 위·오른쪽
	{"name": "3방(우)", "slots": [1, 2, 3]},    # 오른쪽으로 몰린 셋
	{"name": "4방", "slots": [0, 2, 4, 6]},     # 십자
	{"name": "8방", "slots": [0, 1, 2, 3, 4, 5, 6, 7]},  # 전방위
]

# ── 색 (먹·양피지 톤) ──
const INK_FAINT := Color(0.16, 0.13, 0.11, 0.22)
const RING_LINE := Color(0.42, 0.30, 0.12, 0.55)
const GHOST := Color(0.42, 0.30, 0.12, 0.22)       # 아직 안 놓인 자리 안내(유령)
const SLOT_OPEN := Color(0.42, 0.30, 0.12, 0.5)    # 열린 빈 칸 — 여기 채워라
const FIRE_HI := Color(0.95, 0.55, 0.15)
const GLYPH_COLORS := [
	Color(0.16, 0.34, 0.55),   # 응집 = 남색
	Color(0.72, 0.28, 0.12),   # 발산 = 주홍
]
const RUNE_COLOR := Color(0.62, 0.22, 0.12)   # 불

const RING_RADIUS_FRAC := 0.60

# ── 🔴 손그림 = 탁본 (세션 14b, 사용자 재조율 · 14c 손맛: **그린 대로 남는다**) ──
## 조립이 정답 모양을 **숨은 선(가이드)**으로 준다. 그 위를 손으로 그리면 **그린 궤적 그대로**(스냅 안 함)
## 먹선이 남는다 — 구불구불해도 된다, **자기만의 마법진**(사용자 확정). 너무 벗어난 획만 무시한다.
##   • 완성도(cover) = 가이드를 얼마나 지났나   • 정밀도(acc) = 선에 얼마나 가깝게 그렸나 (관대)
## 조각마다 점수 → **[다음]으로 수동 진행**(마음에 안 들면 다시 그려 덮어씀) → 다 그리면 분석 리포트.
## 🔴 잠근 조각은 **그린 먹선을 그대로 유지**한다 — 정답 모양으로 안 바꾼다(사용자: "완료 시 그림 변경 별로").
## 정본: memory takbon-hand-trace-commit.
const CONSIDER_FRAC := 0.24           # 가이드에서 이보다 멀면 이 조각과 무관(펜 뗌). 이 안이면 그린 대로 남는다
const REVEAL_RADIUS_FRAC := 0.08      # 그린 점 주변 이만큼 가이드가 드러난다(완성도)
const ACC_TOL_FRAC := 0.20            # 평균 이 정도 벗어나면 정밀도 0 — **관대**(구불구불 허용)
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
const COMMIT_COVER := 0.15           # 칸을 바꿀 때 이만큼 그렸으면 이전 칸을 자동 잠근다
const TRACE_INK := Color(0.20, 0.14, 0.09, 0.95)    # 자동추적된 먹선 (선에 붙음)
const GUIDE_HIDE := Color(0.42, 0.30, 0.12, 0.18)   # 숨은 가이드 (아직 안 드러남)
const GUIDE_SHOW := Color(0.80, 0.50, 0.16, 0.55)   # 드러난 가이드 강조

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

var _stage := STAGE_JIN
var _has_jin := false
var _has_rune := false

# ── 데이터 정의 (세션 13 구조화) — 바깥(패널)이 Db에서 읽어 주입한다. 없으면 const 폴백. ──
var _jin_def: JinDef = null
var _rune_def: RuneDef = null
var _glyph_defs: Array[GlyphDef] = []

var _active := G_RADIATE            # 활성 문양 코드 (바깥이 set_active_glyph으로 정한다)
var _open: Array[int] = [0, 2]      # 지금 문양본이 연 칸들 (기본 2방)
var _slots: Array[int] = []         # SLOTS개, 값 = 문양 or GLYPH_NONE (열린 칸만 채워진다)
var _cast_t := -1.0
var _cast_dur := 1.3

# ── 손그림 탁본 상태 ──
var _trace := TraceTarget.NONE          # 지금 그릴 대상
var _trace_slot := -1                   # GLYPH일 때 채울 칸 (열린 칸 중 다음 빈 칸)
var _guide: PackedVector2Array = []     # 숨은 정답 선 (조밀, 로컬 좌표)
var _revealed: PackedByteArray = []     # 각 가이드 점이 드러났나 (0/1)
var _ink: PackedVector2Array = []       # 자동추적된 먹선 (선에 붙음, 렌더용)
var _dev_sum := 0.0                     # 그린 점들의 선-이탈 누적 (정밀도용)
var _dev_n := 0
var _drawing := false                   # 마우스 버튼 누른 채 긋는 중
var _scores := {}                       # 잠근 조각 점수: key("jin"/"rune"/"g<k>") → {cover, acc, score, glyph}
var _locked: Array = []                 # 🔴 잠근 조각의 손그림: {target, slot, ink, glyph} — 그린 대로 유지
var _jin_scale := 1.0                   # 진 크기 (마우스 휠)
var _rune_scale := 1.0                  # 룬 크기 (마우스 휠)
var _glyph_scale: Dictionary = {}       # slot(int) → float, 문양 개별 크기 (마우스 휠, 세션 15)

# ── 착지 펄스 ("탁") — 조각이 놓인 자리에서 퍼지는 고리 ──
var _pulse_t := -1.0
var _pulse_at := Vector2.ZERO
const PULSE_DUR := 0.28


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_slots()


func _ready() -> void:
	set_process(false)


# ─────────────────────────── 단계 조회 ───────────────────────────

func stage() -> int:
	return _stage

func has_jin() -> bool:
	return _has_jin

func has_rune() -> bool:
	return _has_rune


# ─────────────────── 손그림 탁본 (진 → 룬 → 문양, 자동추적 + 점수) ───────────────────
## 🔴 세션 14b: 조각은 **숨은 선을 문질러(탁본) 드러내고**, [다음]으로 잠근다. 문지르면 먹선이
## 선에 자동으로 붙어 추적된다(보정). 완성도·정밀도로 점수를 매기고, 다 그리면 분석한다.

## 🔴 지금 단계에 맞는 가이드를 세운다 — 무엇을 그릴지 정하고 문지름 상태를 리셋한다.
func _refresh_trace() -> void:
	match _stage:
		STAGE_JIN:
			if not _has_jin:
				_set_trace(TraceTarget.JIN, -1)
				return
		STAGE_RUNE:
			if not _has_rune:
				_set_trace(TraceTarget.RUNE, -1)
				return
		STAGE_GLYPH:
			var k := _next_open_slot()
			if k >= 0:
				_set_trace(TraceTarget.GLYPH, k)
				return
	_set_trace(TraceTarget.NONE, -1)   # 그릴 것 없음 (문양본 대기 / 다 그림)


## 열린 칸 중 아직 빈 첫 칸 (없으면 -1). 채우는 순서 = 문양본이 준 순.
func _next_open_slot() -> int:
	for k in _open:
		if _slots[k] == GLYPH_NONE:
			return k
	return -1


## 가이드 대상을 세우고 숨은 선 점을 만든 뒤 문지름 상태를 비운다.
func _set_trace(target: int, slot: int) -> void:
	_trace = target
	_trace_slot = slot
	_guide = _build_guide(target, slot)
	_reset_stroke()


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

## 완성도 = 가이드를 얼마나 드러냈나 (0~1).
func coverage() -> float:
	if _guide.is_empty():
		return 0.0
	var n := 0
	for r in _revealed:
		n += r
	return float(n) / float(_guide.size())

## 정밀도 = 문지른 점들이 선에 얼마나 붙었나 (0~1). 문지른 게 없으면 0.
func accuracy() -> float:
	if _dev_n == 0:
		return 0.0
	var tol := _outer_radius() * ACC_TOL_FRAC
	if tol <= 0.0:
		return 0.0
	return clampf(1.0 - (_dev_sum / float(_dev_n)) / tol, 0.0, 1.0)

## 지금 조각 점수 = 완성도 × 정밀도 보정. 완성도가 지배하고 정밀도가 품질을 얹는다.
func piece_score() -> float:
	return coverage() * (0.5 + 0.5 * accuracy())

## 지금 가이드 점들 (로컬 좌표) — 헤드리스 테스트가 이 위로 가짜 문지름을 태운다.
func guide_points() -> PackedVector2Array:
	return _guide


# ─────────────────────────── 문지르기 → 자동추적 → 점수 ───────────────────────────

## 문지름 상태를 비운다 (새 가이드 / 다시 그리기 = 덮어쓰기).
func _reset_stroke() -> void:
	_revealed = PackedByteArray()
	_revealed.resize(_guide.size())
	_ink = PackedVector2Array()
	_dev_sum = 0.0
	_dev_n = 0


## 🔴 새 획을 시작한다 (마우스 누름) = **다시 그리기**. 이전 문지름을 덮어쓴다.
## 마음에 들 때까지 다시 그리고 [다음]으로 잠근다 (사용자 확정).
func begin_stroke() -> void:
	_reset_stroke()
	score_changed.emit(0.0)


## 한 점을 그었다 (드래그). 🔴 **그린 궤적 그대로** 먹선을 남긴다 (스냅 안 함 — 구불구불 OK).
## 가이드에서 너무 멀면(CONSIDER 밖) 이 조각과 무관한 획이라 무시한다. 이탈은 정밀도로 채점(관대).
## public — 헤드리스 테스트가 가짜 궤적을 태운다.
func trace_stroke(local_pos: Vector2) -> void:
	if _trace == TraceTarget.NONE or _guide.is_empty():
		return
	var best_d2 := INF
	for j in _guide.size():
		var d2 := local_pos.distance_squared_to(_guide[j])
		if d2 < best_d2:
			best_d2 = d2
	var consider := _outer_radius() * CONSIDER_FRAC
	if best_d2 > consider * consider:
		return   # 가이드에서 너무 멀다 = 이 조각과 무관 (펜 뗌)
	_dev_sum += sqrt(best_d2)
	_dev_n += 1
	_ink.append(local_pos)               # 🔴 그린 대로 남긴다 (선에 안 붙임)
	var rr := _outer_radius() * REVEAL_RADIUS_FRAC
	var rr2 := rr * rr
	for j in _guide.size():
		if _revealed[j] == 0 and _guide[j].distance_squared_to(local_pos) <= rr2:
			_revealed[j] = 1
	queue_redraw()
	score_changed.emit(piece_score())


# ─────────────────────────── [다음] 수동 진행 · 분석 ───────────────────────────

## 🔴 지금 조각을 잠그고(점수 저장) 다음으로 넘어간다 ([다음]). 반환:
##   "advanced" = 다음 조각 · "finished" = 마지막이라 다 그림(분석) · "none" = 그릴 게 없음
func advance() -> String:
	if _trace == TraceTarget.NONE:
		return "none"
	var done := _trace
	var slot := _trace_slot
	_lock_current()
	match done:
		TraceTarget.JIN:
			_has_jin = true
			_start_pulse(_area_center())
			_stage = STAGE_RUNE
			stage_advanced.emit(_stage)
		TraceTarget.RUNE:
			_has_rune = true
			_start_pulse(_area_center())
			_stage = STAGE_GLYPH
			stage_advanced.emit(_stage)
		TraceTarget.GLYPH:
			if slot >= 0:
				_slots[slot] = _active
				_start_pulse(_slot_pos(slot))
	var sc := float(_scores[_piece_key(done, slot)].score)
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
	if _trace == TraceTarget.GLYPH and _trace_slot >= 0 and coverage() > 0.0:
		_lock_current()
		_slots[_trace_slot] = _active
		_start_pulse(_slot_pos(_trace_slot))
	_trace = TraceTarget.NONE
	_trace_slot = -1
	queue_redraw()
	var a := get_analysis()
	finished.emit(a)
	return a


# ─────────────────── 문양 칸 자유 편집 (칸 클릭 → 골라 다시 그림, 세션 15) ───────────────────
## 🔴 문양 단계에서 **아무 칸이나 골라** 편집한다 (사용자 확정: "칸클릭 문양 선택하고 내가 다시그림").
## 그리던 칸을 충분히 그렸으면 먼저 자동으로 잠그고 넘어간다. 이미 채운 칸도 다시 골라 덮어 그린다.
## public — 보드 입력(_gui_input)과 헤드리스 테스트가 부른다.
func select_slot(k: int) -> void:
	if _stage != STAGE_GLYPH or not (k in _open) or k == _trace_slot:
		return
	if _trace == TraceTarget.GLYPH and _trace_slot >= 0 and coverage() > COMMIT_COVER:
		_commit_glyph_slot(_trace_slot)         # 그리던 칸을 먼저 확정
	_set_trace(TraceTarget.GLYPH, k)            # 고른 칸에 화살표 가이드를 세운다(그 칸 크기로)
	queue_redraw()
	score_changed.emit(piece_score())


## 문양 칸 하나를 잠근다 (그린 먹선·문양·점수 저장). advance()의 문양 확정과 같되 단계는 안 넘긴다.
func _commit_glyph_slot(slot: int) -> void:
	_lock_current()
	_slots[slot] = _active
	_start_pulse(_slot_pos(slot))
	var sc := float(_scores[_piece_key(TraceTarget.GLYPH, slot)].score)
	piece_locked.emit(TraceTarget.GLYPH, slot, sc)
	assembly_changed.emit()


## 클릭 위치에서 가장 가까운 열린 칸 (없으면 -1).
func _nearest_open_slot(pos: Vector2) -> int:
	var best := -1
	var best_d2 := INF
	for k in _open:
		var d2 := pos.distance_squared_to(_slot_pos(k))
		if d2 < best_d2:
			best_d2 = d2
			best = k
	return best


## 지금 조각의 점수 + **그린 먹선**을 저장한다. 먹선은 잠근 뒤에도 그대로 렌더된다 (정답 모양 교체 없음).
## 🔴 같은 조각(같은 칸·진·룬)을 다시 그리면 이전 먹선을 걷어내고 새것으로 교체한다 (재편집).
func _lock_current() -> void:
	_scores[_piece_key(_trace, _trace_slot)] = {
		"cover": coverage(), "acc": accuracy(), "score": piece_score(),
		"glyph": _active if _trace == TraceTarget.GLYPH else -1,
	}
	for i in range(_locked.size() - 1, -1, -1):
		if int(_locked[i].target) == _trace and int(_locked[i].slot) == _trace_slot:
			_locked.remove_at(i)
	_locked.append({
		"target": _trace, "slot": _trace_slot,
		"ink": _ink.duplicate(), "glyph": _active,
	})


func _piece_key(target: int, slot: int) -> String:
	match target:
		TraceTarget.JIN:
			return "jin"
		TraceTarget.RUNE:
			return "rune"
		TraceTarget.GLYPH:
			return "g%d" % slot
	return "?"


## 마법진 분석 리포트 — 조각별 점수 + 종합 + 등급. 패널이 리포트 UI로 그린다.
func get_analysis() -> Dictionary:
	var glyphs: Array = []
	for k in _open:
		var key := "g%d" % k
		if _scores.has(key):
			var e: Dictionary = _scores[key]
			glyphs.append({"slot": k, "glyph": int(e.glyph),
				"cover": float(e.cover), "acc": float(e.acc), "score": float(e.score)})
	var vals: Array = []
	if _scores.has("jin"):
		vals.append(float(_scores["jin"].score))
	if _scores.has("rune"):
		vals.append(float(_scores["rune"].score))
	for g in glyphs:
		vals.append(float(g.score))
	var total := 0.0
	for v in vals:
		total += float(v)
	total = total / float(vals.size()) if not vals.is_empty() else 0.0
	return {
		"jin": _scores.get("jin", null), "rune": _scores.get("rune", null),
		"glyphs": glyphs, "total": total, "grade": _grade(total),
	}


## 종합 점수 → 등급 이름 (분석 리포트용).
func _grade(s: float) -> String:
	if s >= 0.90:
		return "명인"
	if s >= 0.75:
		return "능숙"
	if s >= 0.55:
		return "무난"
	if s >= 0.35:
		return "거침"
	return "서툼"


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
	var next: Array[int] = []
	for s in open_slots:
		var k := int(s)
		if k >= 0 and k < SLOTS and not (k in next):
			next.append(k)
	_open = next
	for k in SLOTS:
		if not (k in _open):
			_slots[k] = GLYPH_NONE       # 닫힌 칸은 비운다
	_refresh_trace()                     # 새로 열린 칸의 첫 빈 칸에 문양 유령을 세운다
	queue_redraw()
	assembly_changed.emit()


func clear_all() -> void:
	_stage = STAGE_JIN
	_has_jin = false
	_has_rune = false
	_reset_slots()
	_scores = {}
	_locked = []
	_jin_scale = 1.0
	_rune_scale = 1.0
	_glyph_scale = {}
	_pulse_t = -1.0
	_refresh_trace()                     # 진 가이드부터 다시 세운다
	queue_redraw()
	stage_advanced.emit(_stage)
	assembly_changed.emit()


func _reset_slots() -> void:
	_slots = []
	for k in SLOTS:
		_slots.append(GLYPH_NONE)


# ─────────────────────────── 조회 ───────────────────────────

func get_rune() -> int:
	return RUNE_FIRE


func get_open() -> Array[int]:
	return _open


func filled_count() -> int:
	var n := 0
	for k in _open:
		if _slots[k] != GLYPH_NONE:
			n += 1
	return n


## 🔴 진은 문양이 없어도(빈 진) 날아가 맞는다 — 단, **진과 룬은 놓여 있어야** 마법진이다 (세션 13).
func can_commit() -> bool:
	return _has_jin and _has_rune


## 조립 결과 스냅샷 — 발사·맺기가 읽는다. 순수 데이터. (진 하나라 rings=1줄)
func get_assembly() -> Dictionary:
	return {"ring_count": 1, "rune": RUNE_FIRE, "rings": [Array(_slots)],
		"open": _open.duplicate()}


func ring_summary() -> String:
	var counts := {G_GATHER: 0, G_RADIATE: 0}
	for k in _open:
		if _slots[k] != GLYPH_NONE:
			counts[_slots[k]] += 1
	var parts: Array[String] = []
	for g in GLYPH_NAMES.size():
		if counts[g] > 0:
			parts.append("%s×%d" % [GLYPH_NAMES[g], counts[g]])
	if parts.is_empty():
		return "빈 진" if _open.is_empty() else "빈 칸 %d" % _open.size()
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
## 🔴 좌클릭 드래그로 가이드를 문지르면 먹선이 선에 붙어 드러난다. 누를 때마다 = 다시 그리기(덮어씀).
## 확정은 자동이 아니다 — 패널의 [다음]이 advance()를 부른다.

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			# 🔴 문양 단계 — 누른 자리의 칸을 골라 편집한다 (세션 15). 다른 칸이면 이전 칸 자동 확정.
			if _stage == STAGE_GLYPH:
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
	# 🔴 마우스 휠 — 지금 그릴 조각(진/룬)의 크기 조절 (세션 14c)
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


## 지금 그리는 조각(진/룬)의 크기를 바꾼다 — 가이드를 새 크기로 다시 세운다(현재 획은 지워짐).
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

	var sweep_r := -1.0
	if _cast_t >= 0.0:
		sweep_r = _cast_t * (ro * 1.12)
		draw_arc(ctr, maxf(sweep_r, 1.0), 0.0, TAU, 64, Color(FIRE_HI, 0.5), 3.0, true)

	# 🔴 잠근 조각들 — **그린 먹선을 그대로** 유지한다 (정답 모양으로 안 바꾼다).
	# 단, 지금 다시 그리는 칸/조각은 아래 '지금 그리는 조각'이 새 먹선으로 보여주니 건너뛴다.
	for L in _locked:
		if int(L.target) == _trace and int(L.slot) == _trace_slot:
			continue
		_draw_locked(L)

	# 구조 힌트 — 룬까지 그렸으면(문양 단계) 1차 고리 + 열린 빈 칸 위치만 연하게 안내
	if _has_rune:
		draw_arc(ctr, _ring_radius(), 0.0, TAU, 64, RING_LINE, 1.0, true)
		for k in _open:
			if _slots[k] == GLYPH_NONE:
				draw_arc(_slot_pos(k), ro * 0.05, 0.0, TAU, 16, SLOT_OPEN, 1.5, true)
		# 🔴 지금 고른(편집 중인) 문양 칸을 강조한다 — 어느 칸을 그리는지 보이게 (세션 15)
		if _trace == TraceTarget.GLYPH and _trace_slot >= 0:
			draw_arc(_slot_pos(_trace_slot), ro * 0.11, 0.0, TAU, 24, Color(FIRE_HI, 0.7), 1.5, true)

	# 🔴 지금 그리는 조각 — 숨은 정답 선(연하게) + 드러난 점(주황) + **그린 먹선 그대로**
	if _trace != TraceTarget.NONE and _guide.size() >= 2:
		draw_polyline(_guide, GUIDE_HIDE, 2.0, true)
		for i in _guide.size():
			if _revealed[i] == 1:
				draw_circle(_guide[i], 1.6, GUIDE_SHOW)
		if _ink.size() >= 2:
			draw_polyline(_ink, TRACE_INK, 2.6, true)

	# 착지 펄스 ("탁") — 조각이 놓인 자리에서 퍼지는 밝은 고리
	if _pulse_t >= 0.0:
		var pr := _pulse_t * (ro * 0.34)
		var pa := (1.0 - _pulse_t) * 0.85
		draw_arc(_pulse_at, maxf(pr, 1.0), 0.0, TAU, 28, Color(FIRE_HI, pa), 2.5, true)


## 🔴 잠근 조각 = **그린 먹선 그대로** 렌더 (정답 모양 교체 없음). 색은 조각 종류로 구분.
func _draw_locked(L: Dictionary) -> void:
	var ink: PackedVector2Array = L.ink
	if ink.size() < 2:
		return
	var col := TRACE_INK
	match int(L.target):
		TraceTarget.JIN:
			col = _jin_color()
		TraceTarget.RUNE:
			col = _rune_color()
		TraceTarget.GLYPH:
			col = _glyph_color(int(L.glyph))
	draw_polyline(ink, col, 2.8, true)
