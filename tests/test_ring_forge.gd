extends Control
## ─────────────────────────────────────────────────────────────────────────
## 고리 조립 마법진 — **프로토타입** (2026-07-16, 사용자 확정 방향)
##
## 참고 이미지("화염룡 브레스 마법진")의 조립 모델을 실제로 만져 보는 최소 슬라이스다.
##   • 진이 **고정 칸**을 준다: 고리 N겹 × 8칸. 칸을 클릭해 글자를 끼운다 (반자동 조립)
##   • **고리 = 실행 단계**: 중심(룬 발화) → 안 고리 → 밖 고리, 순서대로 (중심에서 바깥으로)
##   • 자유 조준이 아니라 **어느 칸을 채우느냐**로 방향·패턴이 나온다 —
##     밖 고리 8칸 다 투사 = 전방위 / 오른쪽 3칸만 = 오른쪽으로만. 창발이 딱 떨어지고 읽힌다.
##
## 이건 기존 게임(자유 드로잉)과 **완전히 분리된** 실험 씬이다 — 오토로드·모듈 의존 없음.
## 손맛이 좋으면 이걸 바탕으로 본 게임을 새로 깐다.
##
## 조작: 좌클릭 = 칸에 글자 끼움(중심=룬) / 우클릭 = 비움 / 1·2·3 = 진 단계(고리 수) /
##       Q·W·E = 팔레트 글자 고르기 / Space = 발사(중심→밖 실행) / R = 전부 비우기
## ─────────────────────────────────────────────────────────────────────────

const SLOTS_PER_RING := 8
const GLYPH_NONE := -1

# 팔레트 — 지금 어휘는 3종 (사용자 확정 2026-07-16). 도형 하나하나가 힘을 갖고, 조합이 목적.
const G_GATHER := 0    # 응집 ◎ — 힘을 한 점에 모은다
const G_SPREAD := 1    # 확산 ✳ — 사방으로 번진다
const G_RADIATE := 2   # 발산 → — 그 칸 방향(바깥)으로 뻗어 나간다
const GLYPH_NAMES := ["응집◎", "확산✳", "발산→"]
const GLYPH_KEYS := ["Q", "W", "E"]

const RUNE_NAMES := ["불△", "물~", "바람◎"]

# ── 색 (먹·양피지 톤) ──
const BG := Color(0.91, 0.87, 0.78)
const INK := Color(0.16, 0.13, 0.11)
const INK_FAINT := Color(0.16, 0.13, 0.11, 0.22)
const RING_LINE := Color(0.42, 0.30, 0.12, 0.55)
const SLOT_EMPTY := Color(0.16, 0.13, 0.11, 0.18)
const FIRE_HI := Color(0.95, 0.55, 0.15)
const GLYPH_COLORS := [
	Color(0.16, 0.34, 0.55),   # 응집 = 남색
	Color(0.22, 0.46, 0.24),   # 확산 = 녹
	Color(0.72, 0.28, 0.12),   # 발산 = 주홍
]
const RUNE_COLORS := [
	Color(0.62, 0.22, 0.12),   # 불
	Color(0.14, 0.34, 0.5),    # 물
	Color(0.2, 0.44, 0.32),    # 바람
]

var _ring_count := 2
var _rune := G_GATHER * 0 # 0 = 불
var _slots: Array = []          # _slots[r] = Array[int] (SLOTS_PER_RING), 값 = 글자 or GLYPH_NONE
var _active := G_RADIATE        # 팔레트에서 고른 글자
var _cast_t := -1.0             # 발사 진행 0..1 (음수 = 대기)
var _cast_dur := 1.3


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_rebuild_slots(-1)
	grab_focus()


# ─────────────────────────── 기하 ───────────────────────────

func _area_center() -> Vector2:
	return Vector2(size.x * 0.34, size.y * 0.53)

func _outer_radius() -> float:
	return minf(size.x * 0.66, size.y) * 0.42

## 🔴 문양 고리는 **룬과 진 사이**에만 있다 (사용자 확정 2026-07-16). 진은 바깥 그릇(경계)이라
## 문양을 얹지 않는다 — 고리들은 진 경계에 못 닿고 그 안쪽 띠(RING_BAND)에 갇힌다.
const RING_BAND_INNER := 0.54   # 룬 자리(0.28R)를 확실히 비운다 — 룬이 안내선에 안 겹치게
const RING_BAND_OUTER := 0.84   # 진 안쪽 (진 경계 1.0에는 안 닿는다)

## 고리 r의 반지름 (0 = 가장 안쪽). 진 단계(고리 수)가 띠 안 배치를 정한다.
func _ring_radius(r: int) -> float:
	var ro := _outer_radius()
	if _ring_count <= 1:
		return ro * (RING_BAND_INNER + RING_BAND_OUTER) * 0.5
	return ro * lerpf(RING_BAND_INNER, RING_BAND_OUTER, float(r) / float(_ring_count - 1))

## 고리 r, 칸 k의 각도 (위쪽 = -90도 기준, 시계 방향)
func _slot_angle(k: int) -> float:
	return TAU * float(k) / float(SLOTS_PER_RING) - PI / 2.0

func _slot_pos(r: int, k: int) -> Vector2:
	return _area_center() + Vector2.from_angle(_slot_angle(k)) * _ring_radius(r)


func _rebuild_slots(preserve_from: int) -> void:
	var old := _slots
	_slots = []
	for r in _ring_count:
		var ring: Array[int] = []
		for k in SLOTS_PER_RING:
			var v := GLYPH_NONE
			if preserve_from >= 0 and r < old.size():
				v = int(old[r][k])
			ring.append(v)
		_slots.append(ring)


# ─────────────────────────── 입력 ───────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_click(mb.position, true)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_click(mb.position, false)
			accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_1: _ring_count = 1; _rebuild_slots(0); queue_redraw()
		KEY_2: _ring_count = 2; _rebuild_slots(0); queue_redraw()
		KEY_3: _ring_count = 3; _rebuild_slots(0); queue_redraw()
		KEY_Q: _active = G_GATHER; queue_redraw()
		KEY_W: _active = G_SPREAD; queue_redraw()
		KEY_E: _active = G_RADIATE; queue_redraw()
		KEY_R: _rebuild_slots(-1); queue_redraw()
		KEY_SPACE: _begin_cast()


## place=true → 끼움(중심=룬 순환, 칸=활성 글자) / place=false → 비움
func _click(pos: Vector2, place: bool) -> void:
	var ctr := _area_center()
	# 중심(룬) — 반지름 0.30R 안
	if pos.distance_to(ctr) < _outer_radius() * 0.30:
		if place:
			_rune = (_rune + 1) % RUNE_NAMES.size()
		queue_redraw()
		return
	# 가장 가까운 칸 (임계 안일 때만)
	var best_r := -1
	var best_k := -1
	var best_d := _outer_radius() * 0.11   # 칸 히트 반경 (고리가 촘촘해도 안 겹치게)
	for r in _ring_count:
		for k in SLOTS_PER_RING:
			var d := pos.distance_to(_slot_pos(r, k))
			if d < best_d:
				best_d = d
				best_r = r
				best_k = k
	if best_r >= 0:
		_slots[best_r][best_k] = (_active if place else GLYPH_NONE)
		queue_redraw()


func _begin_cast() -> void:
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
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var ctr := _area_center()
	var ro := _outer_radius()
	var font := ThemeDB.fallback_font

	# 발사 스윕 — 중심에서 바깥으로 자라는 고리 (실행 순서를 눈으로)
	var sweep_r := -1.0
	if _cast_t >= 0.0:
		sweep_r = _cast_t * (ro * 1.12)
		draw_arc(ctr, maxf(sweep_r, 1.0), 0.0, TAU, 64, Color(FIRE_HI, 0.5), 3.0, true)

	# 진 = 바깥 그릇(경계). 문양은 여기 못 얹는다 — 그릇이지 고리가 아니다.
	_draw_jin(ctr, ro)

	# 문양 고리 선 (룬과 진 사이 띠 안)
	for r in _ring_count:
		draw_arc(ctr, _ring_radius(r), 0.0, TAU, 64, RING_LINE, 1.5, true)

	# 칸 + 얹힌 글자
	for r in _ring_count:
		var fired := sweep_r >= _ring_radius(r)   # 스윕이 이 고리를 지났나
		for k in SLOTS_PER_RING:
			var p := _slot_pos(r, k)
			var g := int(_slots[r][k])
			if g == GLYPH_NONE:
				draw_circle(p, ro * 0.02, SLOT_EMPTY)      # 빈 칸 = 옅은 점
			else:
				_draw_glyph(p, g, _slot_angle(k), ro, fired)

	# 중심 룬 — 자기 자리(안쪽 원) 안에만. 이름표는 안 붙인다(안내선·슬롯과 겹친다 — HUD에 표시).
	_draw_rune(ctr, _rune, ro, _cast_t >= 0.0 and _cast_t < 0.25)

	_draw_palette(font)
	_draw_hud(font)


## 글자 하나 — 도형이 곧 힘이다. angle = 그 칸이 바깥을 보는 방향.
func _draw_glyph(p: Vector2, g: int, angle: float, ro: float, fired: bool) -> void:
	var col: Color = GLYPH_COLORS[g]
	if fired:
		col = FIRE_HI
	var sz := ro * 0.075
	var w := 2.5 if fired else 2.0
	match g:
		G_GATHER:   # 응집 ◎ — 이중 원 (힘을 한 점에 모은다)
			draw_arc(p, sz, 0.0, TAU, 20, col, w, true)
			draw_arc(p, sz * 0.5, 0.0, TAU, 16, col, w, true)
		G_SPREAD:   # 확산 ✳ — 방사 별 (사방으로 번진다)
			for i in 6:
				var d := Vector2.from_angle(TAU * float(i) / 6.0)
				draw_line(p, p + d * sz, col, w, true)
		G_RADIATE:  # 발산 → — 바깥 방향 화살표 (그 칸 방향으로 뻗는다)
			var dir := Vector2.from_angle(angle)
			var a := p - dir * sz
			var b := p + dir * sz
			draw_line(a, b, col, w, true)
			var back := -dir.rotated(0.5) * sz * 0.7
			var back2 := -dir.rotated(-0.5) * sz * 0.7
			draw_line(b, b + back, col, w, true)
			draw_line(b, b + back2, col, w, true)


## 진 = 바깥 그릇. 두꺼운 경계 + 단계(고리 수)만큼 스파이크 — 참고 이미지의 "4단계 진" 느낌.
## 문양은 이 위에 못 얹힌다 (룬과 진 사이에만). 여기선 그릇의 규모·단계를 보여줄 뿐.
func _draw_jin(ctr: Vector2, ro: float) -> void:
	draw_arc(ctr, ro, 0.0, TAU, 72, RING_LINE, 3.0, true)
	draw_arc(ctr, ro * 0.965, 0.0, TAU, 72, Color(RING_LINE, 0.4), 1.5, true)
	# 단계 스파이크 — 진 단계 수를 바깥에 뾰족이로 표시 (12방향)
	var spikes := 12
	for i in spikes:
		var a := TAU * float(i) / float(spikes) - PI / 2.0
		var d := Vector2.from_angle(a)
		draw_line(ctr + d * ro, ctr + d * (ro + ro * 0.035 * float(_ring_count)),
			RING_LINE, 2.0, true)


func _draw_rune(ctr: Vector2, rune: int, ro: float, ignite: bool) -> void:
	var col: Color = RUNE_COLORS[rune]
	if ignite:
		col = FIRE_HI
	var s := ro * 0.16
	draw_arc(ctr, ro * 0.28, 0.0, TAU, 40, INK_FAINT, 1.0, true)
	match rune:
		0:   # 불 △
			var pts := PackedVector2Array([
				ctr + Vector2(0, -s), ctr + Vector2(s * 0.87, s * 0.5),
				ctr + Vector2(-s * 0.87, s * 0.5), ctr + Vector2(0, -s)])
			draw_polyline(pts, col, 3.0, true)
		1:   # 물 ~
			var wv := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				wv.append(ctr + Vector2(-s + 2.0 * s * t, sin(t * TAU) * s * 0.4))
			draw_polyline(wv, col, 3.0, true)
		2:   # 바람 ◎
			draw_arc(ctr, s * 0.8, 0.0, TAU, 28, col, 3.0, true)
			draw_arc(ctr, s * 0.35, 0.0, TAU, 20, col, 3.0, true)


func _palette_rects() -> Array:
	var rects := []
	var x := size.x * 0.72
	var y := size.y * 0.22
	var w := size.x * 0.24
	var h := 46.0
	for g in GLYPH_NAMES.size():
		rects.append({"rect": Rect2(x, y + float(g) * (h + 10.0), w, h), "glyph": g})
	return rects


func _draw_palette(font: Font) -> void:
	_guide_text(font, Vector2(size.x * 0.72, size.y * 0.22 - 16.0),
		"팔레트 (Q·W·E로 고르기)", INK, 14, false)
	for entry in _palette_rects():
		var rect: Rect2 = entry.rect
		var g: int = entry.glyph
		var sel := g == _active
		draw_rect(rect, Color(GLYPH_COLORS[g], 0.14 if sel else 0.06))
		draw_rect(rect, GLYPH_COLORS[g] if sel else INK_FAINT, false, 2.0 if sel else 1.0)
		_draw_glyph(rect.position + Vector2(26, rect.size.y * 0.5), g, 0.0, _outer_radius(), false)
		_guide_text(font, rect.position + Vector2(52, rect.size.y * 0.5 + 5),
			"%s   [%s]" % [GLYPH_NAMES[g], GLYPH_KEYS[g]], INK, 15, false)


func _draw_hud(font: Font) -> void:
	_guide_text(font, Vector2(20, 26), "고리 조립 마법진 — 프로토타입", INK, 20, false)
	_guide_text(font, Vector2(20, 50),
		"진(바깥 그릇) 단계: %d   ·   문양은 룬과 진 사이   ·   활성: %s" % [
			_ring_count, GLYPH_NAMES[_active]],
		INK, 14, false)
	# 실행 순서 요약 — 중심에서 바깥으로
	var lines := ["실행 순서 (중심 → 밖):", "  0. 룬 발화 — %s" % RUNE_NAMES[_rune]]
	for r in _ring_count:
		lines.append("  %d. %d고리 — %s" % [r + 1, r + 1, _ring_summary(r)])
	var y := size.y - 20.0 - float(lines.size()) * 20.0
	for i in lines.size():
		var col := FIRE_HI if (_cast_t >= 0.0 and _stage_active(i)) else INK
		_guide_text(font, Vector2(20, y + float(i) * 20.0), lines[i], col, 14, false)
	_guide_text(font, Vector2(size.x * 0.72, size.y - 92.0),
		"좌클릭=끼움 (중심=룬)", INK, 13, false)
	_guide_text(font, Vector2(size.x * 0.72, size.y - 72.0),
		"우클릭=비움 · R=초기화", INK, 13, false)
	_guide_text(font, Vector2(size.x * 0.72, size.y - 44.0),
		"[Space] 발사 (중심→밖)", FIRE_HI, 16, false)


## 고리에 뭐가 얼마나 들었나 — "투사×3", "응집×4 확산×1", 빈 고리는 "빈 칸"
func _ring_summary(r: int) -> String:
	var counts := {0: 0, 1: 0, 2: 0}
	for k in SLOTS_PER_RING:
		var g := int(_slots[r][k])
		if g != GLYPH_NONE:
			counts[g] += 1
	var parts: Array[String] = []
	for g in GLYPH_NAMES.size():
		if counts[g] > 0:
			parts.append("%s×%d" % [GLYPH_NAMES[g], counts[g]])
	return "빈 칸" if parts.is_empty() else " ".join(parts)


## HUD 실행 요약에서 지금 스윕이 밝히는 줄 (i=0 룬, i>=1 고리)
func _stage_active(i: int) -> bool:
	if _cast_t < 0.0:
		return false
	var sweep := _cast_t * (_outer_radius() * 1.12)
	if i == 0:
		return _cast_t < 0.25
	return sweep >= _ring_radius(i - 1)


func _guide_text(font: Font, at: Vector2, text: String, col: Color, fs: int, centered: bool) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := at
	if centered:
		pos.x -= w * 0.5
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
