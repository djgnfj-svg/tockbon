extends Control
## 조각 선택기 — 고리 조립 제작대의 **오른쪽 페이지** (2026-07-16 방향 전환).
##
## 옛 forge_book처럼 **탭으로 넘겨 본다**: 진 · 룬 · 문양본 · 문양. 고른 것이 왼쪽 보드에 곧바로 적용된다.
##   • 진 탭 — 일반진 하나 (열람용)
##   • 룬 탭 — 불 하나 (열람용)
##   • 🔴 문양본 탭 — **틀을 삽입한다**(2방/3방/4방/8방). 얻은 문양본이 **어느 칸을 열지** 정한다.
##   • 문양 탭 — 응집←·발산→ (열린 칸을 이걸로 채운다)
##
## 오토로드 의존 없음. 사용: const RingBook := preload("res://src/drawing/ring_book.gd")

const RingBoard := preload("res://src/drawing/ring_board.gd")

## 진을 골랐다 — 보드에 진(그릇)을 놓는다 (세션 13 순차 조립)
signal jin_selected
## 룬을 골랐다 — 보드 중심에 룬을 놓는다
signal rune_selected
## 문양본을 삽입했다 — 보드가 이 칸들을 연다 (idx = TEMPLATES 인덱스, slots = 열 인덱스 배열)
signal template_selected(idx: int, slots: Array)
## 문양을 골랐다 — 열린 칸을 한 칸 채운다 (RingBoard.G_*)
signal glyph_selected(glyph: int)

const TAB_JIN := 0
const TAB_RUNE := 1
const TAB_TEMPLATE := 2
const TAB_GLYPH := 3
const TAB_ORDER := [TAB_JIN, TAB_RUNE, TAB_TEMPLATE, TAB_GLYPH]
const TAB_LABEL := ["진", "룬", "문양본", "문양"]

# ── 한지·먹 톤 ──
const INK := Color(0.13, 0.11, 0.10)
const DESC_COLOR := Color(0.44, 0.37, 0.30)
const NAME_COLOR := Color(0.24, 0.19, 0.14)
const CELL_BG := Color(0.86, 0.81, 0.70, 0.55)
const CELL_SEL_BG := Color(0.80, 0.74, 0.62, 0.95)
const CELL_LINE := Color(0.55, 0.48, 0.38, 0.45)
const SEL_EDGE := Color(0.72, 0.45, 0.15, 0.95)
const TAB_ON_BG := Color(0.80, 0.74, 0.62, 0.95)
const TAB_OFF_BG := Color(0.68, 0.62, 0.52, 0.75)
const TAB_ON_TEXT := Color(0.22, 0.16, 0.10)
const TAB_OFF_TEXT := Color(0.42, 0.37, 0.30)
const OPEN_DOT := Color(0.85, 0.50, 0.18)          # 문양본 아이콘: 열린 칸
const SHUT_DOT := Color(0.30, 0.26, 0.20, 0.4)     # 닫힌 칸

const TAB_H := 18.0
const TAB_GAP := 2.0

const TAB_DESC := [
	"진 — 바깥 그릇. 지금은 일반진 하나.",
	"룬 — 중심 속성. 지금은 불만.",
	"문양본 — 삽입하면 그 자리가 열린다. 얻은 만큼 넓어진다.",
	"문양 — 열린 칸을 이걸로 채운다.",
]
const GLYPH_DESC := ["안쪽(룬)으로", "바깥(진)으로"]

var _stage := TAB_JIN                 # 진 탭부터 편다 (순차 조립)
var _template_idx := 0                # 지금 삽입된 문양본 (하이라이트)
var _active := RingBoard.G_RADIATE    # 지금 고른 문양 코드 (하이라이트)
var _jin_placed := false              # 진을 이미 놓았나 (탭 표식)
var _rune_placed := false             # 룬을 이미 놓았나
var _tab_rects: Array[Rect2] = []
## 클릭 가능한 칸 — {rect, kind:"jin"/"rune"/"template"/"glyph", value}
var _cells: Array[Dictionary] = []

# ── 주입 데이터 (세션 13 구조화) — 패널이 Db에서 읽어 넣는다. 없으면 RingBoard const 폴백. ──
var _jin_defs: Array = []
var _rune_def: RuneDef = null
var _glyph_defs: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## Db에서 읽은 진·룬·문양 정의를 주입한다 (셀 이름·색을 여기서 열거한다).
func set_defs(jins: Array, rune: RuneDef, glyph_defs: Array) -> void:
	_jin_defs = jins
	_rune_def = rune
	_glyph_defs = glyph_defs
	queue_redraw()


## 문양 셀 행 — 주입된 def, 없으면 RingBoard const로 폴백. 통일 딕셔너리로 반환.
func _glyph_rows() -> Array:
	# 🔴 `key`(키 힌트)는 여기 없다 — 세션 25에 문양 고르기가 **마우스 클릭 전용**이 됐다.
	var rows: Array = []
	if _glyph_defs.is_empty():
		for g in RingBoard.GLYPH_NAMES.size():
			rows.append({"name": RingBoard.GLYPH_NAMES[g],
				"desc": GLYPH_DESC[g], "color": RingBoard.GLYPH_COLORS[g],
				"inward": g == RingBoard.G_GATHER, "code": g})
	else:
		for d in _glyph_defs:
			rows.append({"name": d.display_name, "desc": d.desc,
				"color": d.ui_color, "inward": d.inward, "code": d.code})
	return rows


func _jin_name() -> String:
	return String(_jin_defs[0].display_name) if not _jin_defs.is_empty() else "일반진"

func _rune_name() -> String:
	return _rune_def.display_name if _rune_def else "불"

func _rune_ui_color() -> Color:
	return _rune_def.ui_color if _rune_def else RingBoard.RUNE_COLOR

func _jin_ui_color() -> Color:
	return _jin_defs[0].ui_color if not _jin_defs.is_empty() else RingBoard.RING_LINE


## 보드의 현재 상태를 받아 하이라이트를 맞춘다 (열 때·키 입력 시)
func sync_state(template_idx: int, active_glyph: int) -> void:
	_template_idx = template_idx
	_active = active_glyph
	queue_redraw()


## 바깥(패널)이 단계 진행에 맞춰 탭을 넘겨 준다. placed 표식도 갱신.
func go_stage(tab: int, jin_placed: bool, rune_placed: bool) -> void:
	_stage = clampi(tab, 0, TAB_ORDER.size() - 1)
	_jin_placed = jin_placed
	_rune_placed = rune_placed
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


# ─────────────────────────── 입력 ───────────────────────────

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in _tab_rects.size():
		if _tab_rects[i].has_point(mb.position):
			_stage = TAB_ORDER[i]
			queue_redraw()
			accept_event()
			return
	for cell in _cells:
		if not Rect2(cell.rect).has_point(mb.position):
			continue
		match String(cell.kind):
			"jin":
				jin_selected.emit()
			"rune":
				rune_selected.emit()
			"template":
				_template_idx = int(cell.value)
				template_selected.emit(_template_idx, RingBoard.TEMPLATES[_template_idx].slots)
			_:
				_active = int(cell.value)
				glyph_selected.emit(_active)
		queue_redraw()
		accept_event()
		return


# ─────────────────────────── 렌더 ───────────────────────────

func _draw() -> void:
	_tab_rects.clear()
	_cells.clear()
	var font := ThemeDB.fallback_font

	var tab_w := (size.x - TAB_GAP * float(TAB_ORDER.size() - 1)) / float(TAB_ORDER.size())
	for i in TAB_ORDER.size():
		var stage: int = TAB_ORDER[i]
		var r := Rect2(float(i) * (tab_w + TAB_GAP), 0.0, tab_w, TAB_H)
		_tab_rects.append(r)
		var on := stage == _stage
		draw_rect(r, TAB_ON_BG if on else TAB_OFF_BG, true)
		draw_line(r.position, r.position + Vector2(r.size.x, 0.0), CELL_LINE, 1.0)
		if not on:
			draw_line(r.position + Vector2(0.0, r.size.y), r.position + r.size, CELL_LINE, 1.0)
		var text: String = TAB_LABEL[i]
		var fs := 10
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, r.position + Vector2((r.size.x - tw) * 0.5, TAB_H * 0.72),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TAB_ON_TEXT if on else TAB_OFF_TEXT)

	var body := Rect2(0.0, TAB_H, size.x, size.y - TAB_H)
	draw_rect(body, TAB_ON_BG, true)
	draw_rect(body, CELL_LINE, false, 1.0)

	var top := TAB_H + 8.0
	_text(font, Vector2(8, top), TAB_DESC[_stage], DESC_COLOR, 9)
	top += 20.0

	match _stage:
		TAB_JIN:
			_draw_single_cell(font, top, _jin_name(), "왼쪽에 손으로 그리기", "jin", "jin",
				_jin_placed, _jin_ui_color())
		TAB_RUNE:
			_draw_single_cell(font, top, _rune_name(), "왼쪽에 손으로 그리기", "fire", "rune",
				_rune_placed, _rune_ui_color())
		TAB_TEMPLATE:
			_draw_template_cells(font, top)
		TAB_GLYPH:
			_draw_glyph_cells(font, top)


func _draw_single_cell(font: Font, top: float, name_text: String, desc: String,
		icon: String, kind: String, placed: bool, icon_col: Color) -> void:
	var cw := 120.0
	var ch := 120.0
	var r := Rect2((size.x - cw) * 0.5, top, cw, ch)
	_cells.append({"rect": r, "kind": kind, "value": 0})
	draw_rect(r, CELL_SEL_BG if placed else CELL_BG, true)
	draw_rect(r, SEL_EDGE if placed else CELL_LINE, false, 2.0 if placed else 1.0)
	_draw_icon(icon, r.get_center() + Vector2(0, -10.0), 30.0, [icon_col])
	var label := "✓ 그림" if placed else desc
	_text_center(font, r.position + Vector2(cw * 0.5, ch - 26.0), name_text, NAME_COLOR, 11)
	_text_center(font, r.position + Vector2(cw * 0.5, ch - 12.0), label,
		SEL_EDGE if placed else DESC_COLOR, 8)


## 문양본 탭 — 2×2 격자. 각 칸에 **8점 고리 다이어그램**(열린 자리만 채워짐)으로 모양을 보여 준다
func _draw_template_cells(font: Font, top: float) -> void:
	var n := RingBoard.TEMPLATES.size()
	var gap := 6.0
	var cw := (size.x - 16.0 - gap) * 0.5
	var ch := 82.0
	for i in n:
		var col := i % 2
		var row := i / 2
		var r := Rect2(8.0 + float(col) * (cw + gap), top + float(row) * (ch + gap), cw, ch)
		_cells.append({"rect": r, "kind": "template", "value": i})
		var sel := _template_idx == i
		draw_rect(r, CELL_SEL_BG if sel else CELL_BG, true)
		draw_rect(r, SEL_EDGE if sel else CELL_LINE, false, 2.0 if sel else 1.0)
		_draw_icon("template", r.get_center() + Vector2(0, -8.0), 22.0,
			RingBoard.TEMPLATES[i].slots)
		_text_center(font, r.position + Vector2(cw * 0.5, ch - 14.0),
			String(RingBoard.TEMPLATES[i].name), NAME_COLOR, 10)


## 문양 탭 — 주입된 문양 def를 열거 (응집·발산…). 하드코딩 없음.
func _draw_glyph_cells(font: Font, top: float) -> void:
	var rows := _glyph_rows()
	var n := rows.size()
	if n == 0:
		return
	var gap := 8.0
	var cw := (size.x - 16.0 - gap * float(n - 1)) / float(n)
	var ch := 120.0
	for i in n:
		var row: Dictionary = rows[i]
		var code := int(row.code)
		var r := Rect2(8.0 + float(i) * (cw + gap), top, cw, ch)
		_cells.append({"rect": r, "kind": "glyph", "value": code})
		var sel := _active == code
		draw_rect(r, CELL_SEL_BG if sel else CELL_BG, true)
		draw_rect(r, SEL_EDGE if sel else CELL_LINE, false, 2.0 if sel else 1.0)
		_draw_glyph_icon(r.get_center() + Vector2(0, -14.0), 26.0, row.color, bool(row.inward))
		# 🔴 키 힌트("[Q]")를 뗐다 (세션 25) — 문양도 **셀을 클릭해서** 고른다.
		# 진·룬·문양본이 전부 클릭인데 문양만 키를 광고하고 있었다 (클릭도 됐는데 몰랐다).
		_text_center(font, r.position + Vector2(cw * 0.5, ch - 30.0),
			String(row.name), NAME_COLOR, 11)
		_text_center(font, r.position + Vector2(cw * 0.5, ch - 15.0), String(row.desc), DESC_COLOR, 8)


## 아이콘. template = 8점 고리(열린 칸 강조) / glyph = 8방향 화살표 다발 / jin·fire = 진·룬
func _draw_icon(kind: String, c: Vector2, s: float, data: Array) -> void:
	match kind:
		"jin":
			var jc: Color = data[0] if data.size() > 0 else RingBoard.RING_LINE
			draw_arc(c, s, 0.0, TAU, 40, jc, 2.5, true)
			draw_arc(c, s * 0.5, 0.0, TAU, 32, Color(jc, 0.5), 1.5, true)
		"fire":
			var col: Color = data[0] if data.size() > 0 else RingBoard.RUNE_COLOR
			draw_polyline(PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(s * 0.87, s * 0.5),
				c + Vector2(-s * 0.87, s * 0.5), c + Vector2(0, -s)]), col, 2.5, true)
		"template":
			# 8점 고리 — 열린 자리는 주황 채움, 닫힌 자리는 흐린 점
			draw_arc(c, s, 0.0, TAU, 32, Color(RingBoard.RING_LINE, 0.5), 1.0, true)
			for k in RingBoard.SLOTS:
				var p := c + Vector2.from_angle(TAU * float(k) / float(RingBoard.SLOTS) - PI / 2.0) * s
				if k in data:
					draw_circle(p, s * 0.16, OPEN_DOT)
				else:
					draw_circle(p, s * 0.10, SHUT_DOT)
		_:
			pass


## 문양 아이콘 — 8방향 화살표 다발. 색·방향은 def에서 온다 (inward=응집, outward=발산).
func _draw_glyph_icon(c: Vector2, s: float, col: Color, inward: bool) -> void:
	for k in 8:
		var outward := Vector2.from_angle(TAU * float(k) / 8.0 - PI / 2.0)
		var inner := c + outward * (s * 0.45)
		var outer := c + outward * s
		var tip := inner if inward else outer
		var tail := outer if inward else inner
		var hdir := (tip - tail).normalized()
		draw_line(tail, tip, col, 1.6, true)
		draw_line(tip, tip - hdir.rotated(0.5) * s * 0.28, col, 1.6, true)
		draw_line(tip, tip - hdir.rotated(-0.5) * s * 0.28, col, 1.6, true)


func _text(font: Font, at: Vector2, text: String, col: Color, fs: int) -> void:
	draw_string(font, at + Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _text_center(font: Font, at: Vector2, text: String, col: Color, fs: int) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-tw * 0.5, fs * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
