extends Control
## 고리 조립 보드 — forge 왼쪽 페이지에 얹히는 **조립 판** (2026-07-16 방향 전환).
##
## 자유 손그림+인식이 아니라 **고정 칸에 조각을 얹어 조립**한다 (사용자 확정):
##   • 진 = **일반진 하나**(그냥 동그라미. 스파이크 없음) — 바깥 그릇(경계)
##   • 룬 = 중심(지금은 **불만**)
##   • 🔴 **문양본(틀)이 칸을 연다** — 2방 문양본 = 정해진 2자리만 열림 (스텐실). 문양본 없으면
##     빈 진(그냥 날아가 맞기만). 문양본을 얻어 삽입할수록 열리는 자리가 넓어진다 (2방→4방→8방).
##   • 문양 = 열린 칸을 채우는 조각 (응집←/발산→). 낮에 탁본으로 얻은 것으로 채운다.
##
## 🔴 이 보드는 **선택을 스스로 쥐지 않는다.** 문양본·활성 문양은 바깥(오른쪽 탭)이 set_*로
## 주입한다. 오토로드·모듈 의존 없음.
##
## 사용: const RingBoard := preload("res://src/drawing/ring_board.gd")

const SLOTS := 8
const GLYPH_NONE := -1

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
const SLOT_OPEN := Color(0.42, 0.30, 0.12, 0.5)    # 열린 빈 칸 — 여기 채워라
const FIRE_HI := Color(0.95, 0.55, 0.15)
const GLYPH_COLORS := [
	Color(0.16, 0.34, 0.55),   # 응집 = 남색
	Color(0.72, 0.28, 0.12),   # 발산 = 주홍
]
const RUNE_COLOR := Color(0.62, 0.22, 0.12)   # 불

const RING_RADIUS_FRAC := 0.60

signal assembly_changed

var _active := G_RADIATE            # 활성 문양 (바깥이 set_active_glyph으로 정한다)
var _open: Array[int] = [0, 2]      # 지금 문양본이 연 칸들 (기본 2방)
var _slots: Array[int] = []         # SLOTS개, 값 = 문양 or GLYPH_NONE (열린 칸만 채워진다)
var _cast_t := -1.0
var _cast_dur := 1.3


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	set_process(false)
	_reset_slots()


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


## 활성 문양을 **열린 칸 전체에 자동 적용**. 이미 다 그 문양이면 걷는다 (얹기/걷기 토글).
func apply_ring(g: int) -> void:
	_active = clampi(g, 0, GLYPH_NAMES.size() - 1)
	if _open.is_empty():
		return
	var already_full := true
	for k in _open:
		if _slots[k] != _active:
			already_full = false
			break
	for k in _open:
		_slots[k] = GLYPH_NONE if already_full else _active
	queue_redraw()
	assembly_changed.emit()


func clear_all() -> void:
	_reset_slots()
	queue_redraw()
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


## 🔴 진은 언제나 쏠 수 있다 — 문양본이 없어(빈 진) 전개할 게 없어도 날아가 맞는다 (사용자 확정).
func can_commit() -> bool:
	return true


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


# ─────────────────────────── 입력 (열린 칸을 눌러 채우기/비우기) ───────────────────────────

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


## 열린 칸만 반응한다. place=true → 활성 문양(같으면 걷기 토글) / place=false → 비움
func _click(pos: Vector2, place: bool) -> void:
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
	queue_redraw()
	assembly_changed.emit()


# ─────────────────────────── 발사 스윕 ───────────────────────────

func play_cast() -> void:
	_cast_t = 0.0
	set_process(true)

func _process(delta: float) -> void:
	if _cast_t < 0.0:
		return
	_cast_t += delta / _cast_dur
	if _cast_t >= 1.0:
		_cast_t = -1.0
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

	# 진 = 일반진(그냥 동그라미)
	draw_arc(ctr, ro, 0.0, TAU, 72, RING_LINE, 3.0, true)
	draw_arc(ctr, ro * 0.965, 0.0, TAU, 72, Color(RING_LINE, 0.4), 1.5, true)

	# 1차 고리 선
	draw_arc(ctr, _ring_radius(), 0.0, TAU, 64, RING_LINE, 1.5, true)

	# 🔴 열린 칸만 그린다 (문양본이 연 자리). 닫힌 칸은 아예 안 보인다.
	var fired := sweep_r >= _ring_radius()
	for k in _open:
		var p := _slot_pos(k)
		var g := _slots[k]
		if g == GLYPH_NONE:
			# 열린 빈 칸 — 여기 채우라는 표식 (작은 원)
			draw_arc(p, ro * 0.05, 0.0, TAU, 16, SLOT_OPEN, 1.5, true)
		else:
			_draw_glyph(p, g, _slot_angle(k), ro, fired)

	# 중심 룬 (불)
	_draw_rune(ctr, ro, _cast_t >= 0.0 and _cast_t < 0.25)


## 문양 하나 — 화살표. 응집=안쪽(룬), 발산=바깥(진).
func _draw_glyph(p: Vector2, g: int, angle: float, ro: float, fired: bool) -> void:
	var col: Color = GLYPH_COLORS[g]
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
	var col := FIRE_HI if ignite else RUNE_COLOR
	var s := ro * 0.16
	draw_arc(ctr, ro * 0.28, 0.0, TAU, 40, INK_FAINT, 1.0, true)
	var pts := PackedVector2Array([
		ctr + Vector2(0, -s), ctr + Vector2(s * 0.87, s * 0.5),
		ctr + Vector2(-s * 0.87, s * 0.5), ctr + Vector2(0, -s)])
	draw_polyline(pts, col, 3.0, true)
