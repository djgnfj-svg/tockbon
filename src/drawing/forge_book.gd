extends Control
## 도안 책자 — 제작대(forge_panel)의 **오른쪽 페이지**. 탭으로 진·룬·문양을 넘겨 본다.
##
## 이 책자는 **참조**다 — 골라서 찍는 게 아니라 **보고 따라 그린다** (사용자 결정, 세션 8).
## 그래서 여기서 무엇을 고르든 캔버스는 달라지지 않는다. 탭은 "지금 뭘 그릴 차례인지"를
## 펼쳐 보여 줄 뿐이고, 판정은 끝까지 인식기가 한다 — 손으로 그린다는 정체성이 그대로 남는다.
##
## 룬 칸은 `RuneTemplates.canonical()`의 **인식기가 실제로 매칭하는 그 점열**을 렌더한다.
## 보이는 게 곧 판정 기준이므로 정직하고, 따라 그리면 반드시 인식된다.
## 먹선은 core InkRender 한 곳에서만 만든다 (TECH_SPEC §4.4).
##
## 사용: const ForgeBook := preload("res://src/drawing/forge_book.gd")
##       var b := ForgeBook.new(); b.size = ...; parent.add_child(b)
##       b.show_tab(Enums.DrawStage.RUNE)   # 캔버스 단계를 따라가게 하려면

const RuneTemplates := preload("res://src/drawing/rune_templates.gd")
const GlyphTemplates := preload("res://src/drawing/glyph_templates.gd")
const InkRender := preload("res://src/core/ink_render.gd")
const Copy := preload("res://src/drawing/drawing_copy.gd")

## 플레이어가 탭을 손으로 넘겼다 — 제작대가 "따라가기"를 멈추는 신호
signal tab_selected(stage: int)
## 본보기를 골랐다 — 종이에 옅게 얹어 달라는 뜻. **찍는 게 아니라 따라 그릴 밑그림이다**
signal glyph_picked(stage: int, unit_pts: PackedVector2Array)

const TAB_ORDER: Array[int] = [
	Enums.DrawStage.CIRCLE, Enums.DrawStage.RUNE, Enums.DrawStage.ARROW,
]
const TAB_LABEL := {
	Enums.DrawStage.CIRCLE: Copy.BOOK_CIRCLE,
	Enums.DrawStage.RUNE: Copy.BOOK_RUNE,
	Enums.DrawStage.ARROW: Copy.BOOK_ARROW,
}

## 룬 → 해금 id (TECH_SPEC §5.1). 시작은 불·충격만 열려 있다
const RUNE_UNLOCK := {
	Enums.RuneType.FIRE: &"rune_fire",
	Enums.RuneType.IMPACT: &"rune_impact",
	Enums.RuneType.WATER: &"rune_water",
	Enums.RuneType.WIND: &"rune_wind",
}
const RUNE_ORDER: Array[int] = [
	Enums.RuneType.FIRE, Enums.RuneType.IMPACT,
	Enums.RuneType.WATER, Enums.RuneType.WIND,
]

## 문양 4종 (v1.9) — **기본이 첫 칸**이다. 글자가 아니라 폴백이므로 언제나 열려 있고,
## "글자를 못 그려도 탄은 나간다"를 눈으로 먼저 보여 준다
const GLYPH_ORDER: Array[int] = [
	Enums.GlyphType.BASIC, Enums.GlyphType.BOUNCE,
	Enums.GlyphType.HOMING, Enums.GlyphType.PIERCE,
]

# ── 한지·먹 톤 (src/ui의 InkStyle은 타 모듈이라 참조하지 않는다 — CLAUDE.md 모듈 규칙) ──
const INK := Color(0.13, 0.11, 0.10)
const TITLE_COLOR := Color(0.30, 0.22, 0.14)
const NAME_COLOR := Color(0.24, 0.19, 0.14)
const DESC_COLOR := Color(0.42, 0.36, 0.29)
const LOCKED_COLOR := Color(0.55, 0.50, 0.44)
const CELL_BG := Color(0.86, 0.81, 0.70, 0.55)      # 본보기 칸 — 종이보다 살짝 어둡게
const CELL_LINE := Color(0.55, 0.48, 0.38, 0.45)
const TAB_ON_BG := Color(0.80, 0.74, 0.62, 0.95)    # 펼친 탭 — 종이와 이어진 것처럼
const TAB_OFF_BG := Color(0.68, 0.62, 0.52, 0.75)
const TAB_ON_TEXT := Color(0.22, 0.16, 0.10)
const TAB_OFF_TEXT := Color(0.42, 0.37, 0.30)
const CURRENT_MARK := Color(0.72, 0.45, 0.15)       # 지금 그릴 차례인 탭의 표식
const PICKED_EDGE := Color(0.72, 0.45, 0.15, 0.9)   # 종이에 얹은 본보기 칸의 테두리

const LOCKED_ALPHA := 0.22
const TAB_H := 17.0
const TAB_GAP := 2.0
const CELL_R := 2.0                # 칸 모서리
const FADE_SEC := 0.12             # 페이지 넘김 — 짧게

var _stage: int = Enums.DrawStage.CIRCLE      # 지금 펼친 탭
var _current: int = Enums.DrawStage.CIRCLE    # 캔버스가 요구하는 단계 (표식용)
var _tab_rects: Array[Rect2] = []
var _page: Control                            # 탭 내용 — 통째로 갈아 끼운다
## 클릭 가능한 본보기 칸 — {rect(책자 로컬), pts, unlocked}
var _cells: Array[Dictionary] = []
var _picked := -1                             # 지금 종이에 얹혀 있는 칸 (이 탭 안에서의 index)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # 탭을 눌러야 하므로 입력을 받는다


func _ready() -> void:
	_page = Control.new()
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _page != null:
		_rebuild()


## 캔버스 단계가 바뀌면 책자도 그 장을 펼친다 — 손이 멈춘 자리를 책이 먼저 열어 준다.
## 플레이어가 직접 넘긴 탭은 존중한다(follow=false로 호출하지 않는 한 덮어쓰지 않음).
func follow_stage(stage: int) -> void:
	_current = stage
	if _stage != stage:
		_stage = stage
		_rebuild()
	else:
		queue_redraw()


## 탭을 직접 펼친다
func show_tab(stage: int) -> void:
	if _stage == stage:
		return
	_stage = stage
	_rebuild()


## 해금 상태를 다시 읽는다 (연구로 룬이 열리면 호출)
func refresh() -> void:
	_rebuild()


# ─────────────────────────── 탭 ───────────────────────────

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in _tab_rects.size():
		if not _tab_rects[i].has_point(mb.position):
			continue
		var stage: int = TAB_ORDER[i]
		if stage != _stage:
			show_tab(stage)
			tab_selected.emit(stage)
		accept_event()
		return
	# 본보기 칸 — 누르면 그 형태가 종이에 옅게 얹힌다. 미해금 룬은 누를 게 없다
	for i in _cells.size():
		var cell := _cells[i]
		if not Rect2(cell.rect).has_point(mb.position) or not bool(cell.unlocked):
			continue
		_pick(i)
		accept_event()
		return


## 같은 칸을 다시 누르면 밑그림을 걷는다 (얹기/걷기 토글)
func _pick(i: int) -> void:
	if _picked == i:
		_picked = -1
		glyph_picked.emit(_stage, PackedVector2Array())
	else:
		_picked = i
		glyph_picked.emit(_stage, PackedVector2Array(_cells[i].pts))
	queue_redraw()


func _draw() -> void:
	# 탭 — 페이지 위쪽에 물린 색인 꼬리표. 지금 그릴 차례엔 등불빛 점을 얹는다
	var tab_w := (size.x - TAB_GAP * float(TAB_ORDER.size() - 1)) / float(TAB_ORDER.size())
	_tab_rects.clear()
	var font := ThemeDB.fallback_font
	for i in TAB_ORDER.size():
		var stage: int = TAB_ORDER[i]
		var r := Rect2(float(i) * (tab_w + TAB_GAP), 0.0, tab_w, TAB_H)
		_tab_rects.append(r)
		var on := stage == _stage
		draw_rect(r, TAB_ON_BG if on else TAB_OFF_BG, true)
		# 펼친 탭은 아래 테두리를 지워 페이지와 이어 붙인다 — 책의 색인 꼬리표처럼
		draw_line(r.position, r.position + Vector2(r.size.x, 0.0), CELL_LINE, 1.0)
		if not on:
			draw_line(r.position + Vector2(0.0, r.size.y),
				r.position + r.size, CELL_LINE, 1.0)

		var text: String = TAB_LABEL.get(stage, "")
		var fs := 10
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, r.position + Vector2((r.size.x - tw) * 0.5, TAB_H * 0.72),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TAB_ON_TEXT if on else TAB_OFF_TEXT)
		# 지금 그릴 차례 — 체크리스트의 ▶와 같은 뜻을 책자에서도 보이게
		if stage == _current:
			draw_circle(r.position + Vector2(5.0, TAB_H * 0.5), 2.0, CURRENT_MARK)

	# 페이지 바닥 — 탭 아래로 이어지는 면
	var body := Rect2(0.0, TAB_H, size.x, size.y - TAB_H)
	draw_rect(body, TAB_ON_BG, true)
	draw_rect(body, CELL_LINE, false, 1.0)

	# 지금 종이에 얹혀 있는 본보기 — 어느 칸을 따라 긋고 있는지 보이게
	if _picked >= 0 and _picked < _cells.size():
		draw_rect(Rect2(_cells[_picked].rect).grow(1.0), PICKED_EDGE, false, 1.0)


# ─────────────────────────── 페이지 내용 ───────────────────────────

func _rebuild() -> void:
	if _page == null:
		return
	for c in _page.get_children():
		_page.remove_child(c)
		c.queue_free()
	_cells.clear()
	_picked = -1
	_page.position = Vector2(6.0, TAB_H + 6.0)
	_page.size = Vector2(maxf(size.x - 12.0, 1.0), maxf(size.y - TAB_H - 12.0, 1.0))

	# 이 부품이 무엇을 정하는가 — 칸을 보기 전에 한 번 읽히게
	var desc := Label.new()
	desc.text = String(Copy.TAB_DESC.get(_stage, ""))
	desc.size = Vector2(_page.size.x, 24.0)
	desc.add_theme_font_size_override(&"font_size", 8)
	desc.add_theme_color_override(&"font_color", DESC_COLOR)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(desc)

	var top := 26.0
	match _stage:
		Enums.DrawStage.CIRCLE:
			_build_circle_page(top)
		Enums.DrawStage.RUNE:
			_build_rune_page(top)
		Enums.DrawStage.ARROW:
			_build_arrow_page(top)
	# 진은 한 종류다 — 고를 게 없으니 펼치자마자 종이에 얹어 준다.
	# 룬·문양은 여러 칸이라 플레이어가 고를 때까지 기다린다
	if _stage == Enums.DrawStage.CIRCLE and not _cells.is_empty():
		_pick(0)
	queue_redraw()


## 진 — 한 종류다 (v1.6). 크게 하나 보여 주고, 크기가 곧 규모임을 말한다
func _build_circle_page(top: float) -> void:
	var w := _page.size.x
	_cell(Rect2(w * 0.5 - 52.0, top, 104.0, 104.0), _circle_pts(),
		Copy.BOOK_CIRCLE_NAME, "", true)


## 룬 4종 — 2×2. 인식기 템플릿 그대로. 미해금은 흐린 빈 칸 + "?"
func _build_rune_page(top: float) -> void:
	var w := _page.size.x
	var cw := (w - 6.0) * 0.5
	var ch := 78.0
	for i in RUNE_ORDER.size():
		var rune: int = RUNE_ORDER[i]
		var unlocked := _is_unlocked(rune)
		var r := Rect2(float(i % 2) * (cw + 6.0), top + float(i / 2) * (ch + 6.0), cw, ch)
		_cell(r,
			RuneTemplates.canonical(rune) if unlocked else PackedVector2Array(),
			Copy.rune_label(rune) if unlocked else Copy.BOOK_LOCKED,
			String(Copy.RUNE_EFFECT.get(rune, "")) if unlocked else Copy.BOOK_LOCKED_HINT,
			unlocked)


## 문양 4종 — 2×2. **룬 장과 같은 문법으로 읽힌다** (v1.9): 모양이 방식을, 길이가 세기를 정한다.
## 인식기 템플릿(GlyphTemplates.canonical) 그대로 그린다 — **보이는 게 곧 판정 기준**이고,
## 보고 따라 그리면 반드시 그 글자로 인식된다 (test_glyph_auto가 못 박는다).
##
## **기본은 글자가 아니다** — 어느 글자도 아닌 곧은 획이 곧 기본 탄이다. 그래서 첫 칸에 두고
## "글자를 못 그려도 탄은 나간다"를 눈으로 보여 준다 (인식 실패는 거부가 아니라 폴백, GDD §4.5).
func _build_arrow_page(top: float) -> void:
	var w := _page.size.x
	var cw := (w - 6.0) * 0.5
	var ch := 78.0
	for i in GLYPH_ORDER.size():
		var g: int = GLYPH_ORDER[i]
		var unlocked := _is_glyph_unlocked(g)
		var r := Rect2(float(i % 2) * (cw + 6.0), top + float(i / 2) * (ch + 6.0), cw, ch)
		_cell(r,
			GlyphTemplates.canonical(g) if unlocked else PackedVector2Array(),
			Copy.glyph_label(g) if unlocked else Copy.BOOK_LOCKED,
			String(Copy.GLYPH_EFFECT.get(g, "")) if unlocked else Copy.BOOK_LOCKED_HINT,
			unlocked)


## 문양 해금 — **기본은 언제나 열려 있다** (글자가 아니므로 배울 것도 없다. 튜토리얼 첫 도안이 이것이다).
## 나머지 셋은 GDD §6에서 **탁본으로 배우는 세 번째 어휘**다.
## ⚠ **탁본 콘텐츠(문양 조각 드랍·해독)는 아직 없다** — 지금은 전부 열어 둔다. 안 그러면
## 어휘를 만들어 놓고 **아무도 쓸 수 없다**. 해금 배선은 콘텐츠가 붙을 때 (BACKLOG §1).
func _is_glyph_unlocked(_glyph_type: int) -> bool:
	return true


## 한 칸 = 한지 칸 + 먹선 본보기 + 이름 + 한 줄 설명. 해금된 칸은 **누르면 종이에 얹힌다**
func _cell(r: Rect2, pts: PackedVector2Array, name_text: String, desc_text: String,
		unlocked: bool) -> void:
	# 클릭 판정은 책자 로컬 좌표로 (칸은 _page 안에 앉아 있다)
	_cells.append({
		"rect": Rect2(_page.position + r.position, r.size),
		"pts": pts,
		"unlocked": unlocked,
	})
	var box := Control.new()
	box.position = r.position
	box.size = r.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(box)

	var has_desc := desc_text != ""
	var glyph_h := r.size.y - (24.0 if has_desc else 14.0)
	var bg := ColorRect.new()
	bg.color = CELL_BG
	bg.size = Vector2(r.size.x, glyph_h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)

	if pts.size() >= 2:
		# canonical()은 중심 0·최장변 1 정규화 점열 — 칸 중앙에 앉힌다
		var span := minf(r.size.x, glyph_h) * 0.62
		var c := Vector2(r.size.x * 0.5, glyph_h * 0.5)
		var px := PackedVector2Array()
		for p: Vector2 in pts:
			px.append(c + p * span)
		var line := InkRender.make_line(px, PackedFloat32Array(),
			InkRender.BASE_WIDTH * 0.8, InkRender.INK_COLOR)
		if not unlocked:
			line.modulate.a = LOCKED_ALPHA
		box.add_child(line)
	elif not unlocked:
		# 미해금 — 빈 칸에 물음표. "여기 글자가 하나 들어온다"는 자리를 남긴다
		var q := Label.new()
		q.text = Copy.BOOK_LOCKED
		q.size = Vector2(r.size.x, glyph_h)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override(&"font_size", 20)
		q.add_theme_color_override(&"font_color", LOCKED_COLOR)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(q)

	var n := Label.new()
	n.text = name_text
	n.position = Vector2(0.0, glyph_h + 1.0)
	n.size = Vector2(r.size.x, 11.0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override(&"font_size", 9)
	n.add_theme_color_override(&"font_color", NAME_COLOR if unlocked else LOCKED_COLOR)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(n)

	if not has_desc:
		return
	var d := Label.new()
	d.text = desc_text
	d.position = Vector2(0.0, glyph_h + 11.0)
	d.size = Vector2(r.size.x, 11.0)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override(&"font_size", 7)
	d.add_theme_color_override(&"font_color", DESC_COLOR if unlocked else LOCKED_COLOR)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(d)


## GameState는 오토로드 — 없으면(단독 테스트) 전부 열린 것으로 본다
func _is_unlocked(rune: int) -> bool:
	var gs := get_node_or_null(^"/root/GameState")
	if gs == null:
		return true
	return bool(gs.call(&"is_unlocked", RUNE_UNLOCK.get(rune, &"")))


# ── 진·문양 표본 (중심 0 · 최장변 1 — canonical()과 같은 좌표계) ──

func _circle_pts() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var a := -PI / 2.0 + TAU * 0.97 * float(i) / 39.0
		pts.append(Vector2(cos(a), sin(a)) * 0.5)
	return pts


## 위(앞)로 뻗는 문양 — 캔버스 위쪽이 조준 방향이라 위로 그린다.
## bow > 0이면 휜다
func _arrow_pts(bow: float) -> PackedVector2Array:
	var a := Vector2(0.0, 0.5)
	var b := Vector2(0.0, -0.5)
	var ctrl := a.lerp(b, 0.5) + Vector2(bow, 0.0)
	var pts := PackedVector2Array()
	for i in 16:
		var t := float(i) / 15.0
		var u := 1.0 - t
		pts.append(a * (u * u) + ctrl * (2.0 * u * t) + b * (t * t))
	return pts
