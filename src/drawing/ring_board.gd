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
const G_GATHER := 0    # 응집 ← — 안쪽(룬) 방향 화살표
const G_RADIATE := 1   # 발산 → — 바깥(진) 방향 화살표
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

signal assembly_changed
## 단계가 넘어갔다 — 바깥(패널)이 오른쪽 탭·안내문을 맞춘다. (STAGE_*)
signal stage_advanced(stage: int)

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


# ─────────────────────────── 순차 배치 (진 → 룬 → 문양) ───────────────────────────
## 🔴 세션 13 (사용자: "결정하고 넘어가는 과정이 있어야"): 배치는 **자동으로 안 넘어간다.**
## 조각을 놓으면 보드에 뜨기만 하고(한 박자 = 놓음), **confirm()**(Enter)을 눌러야 다음 단계로
## 넘어간다(두 박자 = 결정). Enter는 진·룬 단계=확정/다음, 문양 단계=맺기.

## 진을 놓는다 (진 단계에서만). **넘어가지 않는다** — confirm()이 넘긴다.
func place_jin() -> bool:
	if _stage != STAGE_JIN:
		return false
	_has_jin = true
	_start_pulse(_area_center())
	queue_redraw()
	assembly_changed.emit()
	return true


## 룬을 놓는다 (룬 단계에서만). **넘어가지 않는다.**
func place_rune() -> bool:
	if _stage != STAGE_RUNE:
		return false
	_has_rune = true
	_start_pulse(_area_center())
	queue_redraw()
	assembly_changed.emit()
	return true


## 🔴 현재 단계를 **확정하고 다음으로** 넘긴다 (Enter). 반환:
##   "advanced" = 다음 단계로 넘어감 · "commit" = 문양 단계이니 맺을 차례 ·
##   "need_jin"/"need_rune" = 아직 조각을 안 놓음 (넘길 수 없음)
func confirm() -> String:
	match _stage:
		STAGE_JIN:
			if not _has_jin:
				return "need_jin"
			_stage = STAGE_RUNE
			_start_pulse(_area_center())
			queue_redraw()
			stage_advanced.emit(_stage)
			return "advanced"
		STAGE_RUNE:
			if not _has_rune:
				return "need_rune"
			_stage = STAGE_GLYPH
			_start_pulse(_area_center())
			queue_redraw()
			stage_advanced.emit(_stage)
			return "advanced"
		_:
			return "commit"


## 🔴 문양을 **빈 열린 칸 하나에** 얹는다 (일괄 아님 — 한 칸씩). 채울 칸이 없으면 false.
## 문양 단계에서만. 채우는 순서 = 열린 칸 나열 순서(문양본이 준 순).
func place_glyph_next(g: int) -> bool:
	if _stage != STAGE_GLYPH:
		return false
	_active = clampi(g, 0, GLYPH_NAMES.size() - 1)
	for k in _open:
		if _slots[k] == GLYPH_NONE:
			_slots[k] = _active
			_start_pulse(_slot_pos(k))
			queue_redraw()
			assembly_changed.emit()
			return true
	return false   # 열린 칸이 다 찼다


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
	queue_redraw()
	assembly_changed.emit()


func clear_all() -> void:
	_stage = STAGE_JIN
	_has_jin = false
	_has_rune = false
	_reset_slots()
	_pulse_t = -1.0
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

func _ring_radius() -> float:
	return _outer_radius() * RING_RADIUS_FRAC

func _slot_angle(k: int) -> float:
	return TAU * float(k) / float(SLOTS) - PI / 2.0

func _slot_pos(k: int) -> Vector2:
	return _area_center() + Vector2.from_angle(_slot_angle(k)) * _ring_radius()


# ─────────────────────────── 입력 (클릭으로 순차 배치) ───────────────────────────

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_click(mb.position, true)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_click(mb.position, false)
		accept_event()


## 🔴 단계에 맞게 클릭을 처리한다:
##   • 진 단계 — 판 아무 데나 좌클릭 = 진 놓기
##   • 룬 단계 — 중심 근처 좌클릭 = 룬 놓기
##   • 문양 단계 — 열린 칸 좌클릭 = 활성 문양 얹기(같으면 걷기) / 우클릭 = 비움
func _click(pos: Vector2, place: bool) -> void:
	match _stage:
		STAGE_JIN:
			if place:
				place_jin()
		STAGE_RUNE:
			if place and pos.distance_to(_area_center()) < _ring_radius():
				place_rune()
		STAGE_GLYPH:
			_click_slot(pos, place)


func _click_slot(pos: Vector2, place: bool) -> void:
	var best_k := -1
	var best_d := _outer_radius() * 0.15
	for k in _open:
		var d := pos.distance_to(_slot_pos(k))
		if d < best_d:
			best_d = d
			best_k = k
	if best_k < 0:
		return
	if not place:
		_slots[best_k] = GLYPH_NONE
	elif _slots[best_k] == _active:
		_slots[best_k] = GLYPH_NONE
	else:
		_slots[best_k] = _active
		_start_pulse(_slot_pos(best_k))
	queue_redraw()
	assembly_changed.emit()


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

	# 진 = 일반진(그냥 동그라미). 아직 안 놓였으면 유령으로 "여기 놓아라" 안내.
	if _has_jin:
		var jc := _jin_color()
		draw_arc(ctr, ro, 0.0, TAU, 72, jc, 3.0, true)
		draw_arc(ctr, ro * 0.965, 0.0, TAU, 72, Color(jc, 0.4), 1.5, true)
	else:
		draw_arc(ctr, ro, 0.0, TAU, 72, GHOST, 2.0, true)

	# 룬·고리·칸은 진이 놓인 뒤에만 그린다.
	if _has_jin:
		if _has_rune:
			# 1차 고리 선
			draw_arc(ctr, _ring_radius(), 0.0, TAU, 64, RING_LINE, 1.5, true)
			# 🔴 열린 칸만 그린다 (문양본이 연 자리). 닫힌 칸은 아예 안 보인다.
			var fired := sweep_r >= _ring_radius()
			for k in _open:
				var p := _slot_pos(k)
				var g := _slots[k]
				if g == GLYPH_NONE:
					draw_arc(p, ro * 0.05, 0.0, TAU, 16, SLOT_OPEN, 1.5, true)
				else:
					_draw_glyph(p, g, _slot_angle(k), ro, fired)
			# 중심 룬 (불)
			_draw_rune(ctr, ro, _cast_t >= 0.0 and _cast_t < 0.25)
		else:
			# 룬 놓을 차례 — 중심에 유령 표식
			draw_arc(ctr, ro * 0.16, 0.0, TAU, 24, GHOST, 2.0, true)

	# 착지 펄스 ("탁") — 조각이 놓인 자리에서 퍼지는 밝은 고리
	if _pulse_t >= 0.0:
		var pr := _pulse_t * (ro * 0.34)
		var pa := (1.0 - _pulse_t) * 0.85
		draw_arc(_pulse_at, maxf(pr, 1.0), 0.0, TAU, 28, Color(FIRE_HI, pa), 2.5, true)


## 문양 하나 — 화살표. 응집=안쪽(룬), 발산=바깥(진).
func _draw_glyph(p: Vector2, g: int, angle: float, ro: float, fired: bool) -> void:
	var col := _glyph_color(g)
	if fired:
		col = FIRE_HI
	var sz := ro * 0.09
	var w := 2.5 if fired else 2.0
	var outward := Vector2.from_angle(angle)
	var dir := outward if g == G_RADIATE else -outward
	var a := p - dir * sz
	var b := p + dir * sz
	draw_line(a, b, col, w, true)
	draw_line(b, b + -dir.rotated(0.5) * sz * 0.7, col, w, true)
	draw_line(b, b + -dir.rotated(-0.5) * sz * 0.7, col, w, true)


func _draw_rune(ctr: Vector2, ro: float, ignite: bool) -> void:
	var col := FIRE_HI if ignite else _rune_color()
	var s := ro * 0.16
	draw_arc(ctr, ro * 0.28, 0.0, TAU, 40, INK_FAINT, 1.0, true)
	var pts := PackedVector2Array([
		ctr + Vector2(0, -s), ctr + Vector2(s * 0.87, s * 0.5),
		ctr + Vector2(-s * 0.87, s * 0.5), ctr + Vector2(0, -s)])
	draw_polyline(pts, col, 3.0, true)
