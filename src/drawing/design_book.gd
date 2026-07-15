extends HBoxContainer
## 도안 책자 — 진·룬·문양의 **정식 형태를 그림으로** 보여 주는 참조 패널.
##
## 핵심: 룬은 `RuneTemplates.canonical()`의 **인식기가 실제로 매칭하는 그 점열**을 렌더한다.
## 그래서 정직하고(보이는 게 곧 판정 기준), 보고 따라 그리면 반드시 인식된다.
## 먹선은 core InkRender를 쓴다 — 자체 구현 금지 (TECH_SPEC §4.4).
## 640×360 뷰포트라 세로 공간이 없다 — 가로 한 줄(진 1 · 룬 4 · 문양 2)로 앉힌다.
## 사용: const DesignBook := preload("res://src/drawing/design_book.gd")
##       var b := DesignBook.new(); parent.add_child(b)   # _ready에서 스스로 채운다

const RuneTemplates := preload("res://src/drawing/rune_templates.gd")
const InkRender := preload("res://src/core/ink_render.gd")
const Copy := preload("res://src/drawing/drawing_copy.gd")

const GROUP_COLOR := Color(0.95, 0.85, 0.60)
const LABEL_COLOR := Color(0.72, 0.68, 0.60)
const LOCKED_COLOR := Color(0.45, 0.42, 0.38)
const CELL_BG := Color(0.90, 0.86, 0.77, 0.16)   # 한지 칸

const CELL := Vector2(32, 28)      # 한 칸(px)
const GLYPH_SPAN := 19.0           # 칸 안에서 도형이 차지하는 px (여백 확보)
const WIDTH_MULT := 0.5            # 좁은 칸이라 먹선을 가늘게 — 안 그러면 뭉갠다
const LOCKED_ALPHA := 0.30
const FONT_SIZE := 8
const GROUP_FONT_SIZE := 9

## 룬 → 해금 id (TECH_SPEC §5.1). 시작은 불 룬만 (v2.2: 충격 룬 폐지)
const RUNE_UNLOCK := {
	Enums.RuneType.FIRE: &"rune_fire",
	Enums.RuneType.WATER: &"rune_water",
	Enums.RuneType.WIND: &"rune_wind",
}
const RUNE_ORDER: Array[int] = [
	Enums.RuneType.FIRE, Enums.RuneType.WATER, Enums.RuneType.WIND,
]

var _rune_cells: HBoxContainer


func _init() -> void:
	add_theme_constant_override(&"separation", 8)


func _ready() -> void:
	# 진 — 한 종류다 (v1.6)
	var circle_cells := _group(Copy.BOOK_CIRCLE)
	circle_cells.add_child(_cell(_circle_pts(), true, ""))

	# 룬 4종 — 인식기 템플릿 그대로
	_rune_cells = _group(Copy.BOOK_RUNE)

	# 문양 — 곡선도 된다는 걸 보여 주는 게 핵심
	var arrow_cells := _group(Copy.BOOK_ARROW)
	arrow_cells.add_child(_cell(_arrow_pts(0.0), true, Copy.BOOK_ARROW_STRAIGHT))
	arrow_cells.add_child(_cell(_arrow_pts(0.32), true, Copy.BOOK_ARROW_CURVED))

	refresh()


## 해금 상태를 다시 읽어 룬 칸을 갱신한다 (연구로 룬이 열리면 호출)
func refresh() -> void:
	if _rune_cells == null:
		return
	for child in _rune_cells.get_children():
		_rune_cells.remove_child(child)
		child.queue_free()
	for rune: int in RUNE_ORDER:
		var unlocked := _is_unlocked(rune)
		var pts := RuneTemplates.canonical(rune) if unlocked else PackedVector2Array()
		_rune_cells.add_child(_cell(pts, unlocked,
			Copy.rune_label(rune) if unlocked else Copy.BOOK_LOCKED))


## GameState는 오토로드 — 없으면(단독 테스트) 전부 열린 것으로 본다
func _is_unlocked(rune: int) -> bool:
	var gs := get_node_or_null(^"/root/GameState")
	if gs == null:
		return true
	return bool(gs.call(&"is_unlocked", RUNE_UNLOCK.get(rune, &"")))


# ─────────────────────────── 칸 만들기 ───────────────────────────

## 한 무리 = [제목] + 칸들. 반환값은 칸을 담을 HBox
func _group(title: String) -> HBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override(&"font_size", GROUP_FONT_SIZE)
	l.add_theme_color_override(&"font_color", GROUP_COLOR)
	box.add_child(l)
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override(&"separation", 3)
	box.add_child(cells)
	add_child(box)
	return cells


## 한 칸 = 한지 배경 + 먹선 도형 + 이름. 잠긴 룬은 흐리게 + "?"
func _cell(pts: PackedVector2Array, unlocked: bool, label: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)

	var slot := Control.new()
	slot.custom_minimum_size = CELL
	var bg := ColorRect.new()
	bg.color = CELL_BG
	bg.size = CELL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)

	if pts.size() >= 2:
		# canonical()은 중심 0·최장변 1 정규화 점열 — 칸 중앙에 GLYPH_SPAN 크기로 앉힌다
		var px := PackedVector2Array()
		for p: Vector2 in pts:
			px.append(CELL * 0.5 + p * GLYPH_SPAN)
		var line := InkRender.make_line(px, PackedFloat32Array(),
			InkRender.BASE_WIDTH * WIDTH_MULT, InkRender.INK_COLOR)
		if not unlocked:
			line.modulate.a = LOCKED_ALPHA
		slot.add_child(line)
	box.add_child(slot)

	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override(&"font_size", FONT_SIZE)
	l.add_theme_color_override(&"font_color", LABEL_COLOR if unlocked else LOCKED_COLOR)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(CELL.x, 10)
	box.add_child(l)
	return box


# ── 진·문양 표본 (중심 0 · 최장변 1 — canonical()과 같은 좌표계) ──

func _circle_pts() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var a := -PI / 2.0 + TAU * 0.97 * float(i) / 39.0
		pts.append(Vector2(cos(a), sin(a)) * 0.5)
	return pts


## 위(앞)로 뻗는 문양 — 캔버스 위쪽이 조준 방향이라 위로 그린다.
## bow > 0이면 휜다: **곡선도 된다**는 걸 보여 주는 게 이 칸의 목적이다
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
