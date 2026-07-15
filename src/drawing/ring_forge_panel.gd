extends Control
## 고리 조립 제작대 — **책을 좌우로 펼친다.** forge_panel(자유 드로잉)의 껍데기를 그대로
## 잇되(사용자 요청 "이전 왼쪽 UI를 그대로 쓰고 적용되는 형식으로"), 속을 조립 모델로 바꾼다.
##
## 왼쪽 페이지 = **조립 보드**(RingBoard — 일반진 하나 + 불 룬 + 1차 고리 8칸) ·
## 오른쪽 페이지 = **조각 선택기**(RingBook — 진·룬·문양 **탭**). 문양(응집←·발산→)을 누르면
## 왼쪽 1차 고리 8칸에 자동 적용된다. 하단 **Enter(또는 ✓버튼) = 맺기**.
##
## 🔴 옛 forge_panel은 그대로 살아 있다 — 이건 방향 전환을 **손맛으로 확인하려는 평행 패널**이다.
##
## 계약: open() → 열림 / closed 시그널 → 닫힘 / design_committed(assembly) → 맺힘.
## 사용: const RingForgePanel := preload("res://src/drawing/ring_forge_panel.gd")

const RingBoard := preload("res://src/drawing/ring_board.gd")
const RingBook := preload("res://src/drawing/ring_book.gd")

signal closed
## 도안이 방금 맺혔다 — 여는 쪽(작업대·거점)이 발사·연출에 쓴다. assembly = board.get_assembly()
signal design_committed(assembly: Dictionary)

# ── 레이아웃 (뷰포트 640×360 고정) ──
const BOOK_RECT := Rect2(16, 10, 608, 340)
const PAGE_W := 304.0
const BOARD_RECT := Rect2(30, 30, 268, 268)          # 왼쪽 페이지의 조립 보드
const BOOK_RECT_R := Rect2(332, 24, 280, 262)        # 오른쪽 페이지의 선택기(탭)
const SAY_RECT := Rect2(30, 302, 268, 40)            # 스승의 말
const COMMIT_BTN_RECT := Rect2(332, 300, 150, 22)    # 확정 버튼 (맺기)
const HINT_RECT := Rect2(332, 326, 280, 22)
const TITLE_RECT := Rect2(28, 14, 300, 14)

# ── 한지·먹 톤 (forge_panel과 동일) ──
const DIM := Color(0.05, 0.04, 0.03, 0.62)
const PAPER_L := Color(0.93, 0.89, 0.80)
const PAPER_R := Color(0.89, 0.84, 0.74)
const SPINE := Color(0.62, 0.55, 0.45, 0.55)
const EDGE := Color(0.45, 0.38, 0.30, 0.70)
const SHADOW := Color(0.0, 0.0, 0.0, 0.35)
const TITLE_COLOR := Color(0.36, 0.26, 0.16)
const HINT_COLOR := Color(0.50, 0.45, 0.38)
const SAY_COLOR := Color(0.30, 0.24, 0.18)
const WARN_COLOR := Color(0.62, 0.22, 0.14)

const OPEN_SEC := 0.20
const OPEN_FROM_X := 0.04
const CLOSE_SEC := 0.12

const Copy_START := "문양본(틀)을 삽입하고, 열린 칸을 문양으로 채우세요"

var _board: Control
var _book: Control
var _title: Label
var _say: Label
var _hint: Label
var _commit_btn: Button
var _spread: Control

var _committed := false
var _template_idx := 0        # 지금 삽입된 문양본 (기본 = TEMPLATES[0] = 2방)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_build()


# ─────────────────────────── 열고 닫기 ───────────────────────────

func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	_committed = false
	_board.call(&"set_template", RingBoard.TEMPLATES[_template_idx].slots)
	_board.call(&"set_active_glyph", RingBoard.G_RADIATE)
	_book.call(&"sync_state", _template_idx, RingBoard.G_RADIATE)
	_set_say(Copy_START, false)
	_refresh_commit()
	_spread_open()


func close() -> void:
	if not visible:
		return
	# 🔴 맺기(Enter)를 깜빡해도 쏠 수 있게 — 닫을 때 유효한 조립이면 자동으로 맺는다.
	# (조립=완성이라 별도 확정 단계가 손맛에 군더더기였다. Enter는 여전히 즉시 맺기로 남는다.)
	if not _committed and bool(_board.call(&"can_commit")):
		_committed = true
		design_committed.emit(_board.call(&"get_assembly"))
		_refresh_commit()
	var tw := create_tween()
	tw.tween_property(_spread, ^"scale", Vector2(OPEN_FROM_X, 1.0), CLOSE_SEC) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		visible = false
		closed.emit())


func _spread_open() -> void:
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread.scale = Vector2(OPEN_FROM_X, 1.0)
	var tw := create_tween()
	tw.tween_property(_spread, ^"scale", Vector2.ONE, OPEN_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func() -> void:
		_board.mouse_filter = Control.MOUSE_FILTER_STOP)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_try_commit()
			get_viewport().set_input_as_handled()
		KEY_Q:
			_apply_glyph(RingBoard.G_GATHER)
			get_viewport().set_input_as_handled()
		KEY_W:
			_apply_glyph(RingBoard.G_RADIATE)
			get_viewport().set_input_as_handled()


# ─────────────────────────── 선택기 → 보드 ───────────────────────────

## 문양을 골랐다 — 열린 칸 전체에 자동 적용. 탭 하이라이트도 맞춘다.
func _apply_glyph(glyph: int) -> void:
	_board.call(&"apply_ring", glyph)
	_book.call(&"sync_state", _template_idx, glyph)
	_set_say("%s — 칸을 눌러 방향을 뺄 수 있어요 (우클릭=비움)"
		% RingBoard.GLYPH_NAMES[glyph], false)


func _on_glyph_selected(glyph: int) -> void:
	_apply_glyph(glyph)


## 문양본을 삽입했다 — 보드가 그 칸들을 연다.
func _on_template_selected(idx: int, slots: Array) -> void:
	_template_idx = idx
	_board.call(&"set_template", slots)
	_set_say("%s 문양본 — 열린 칸을 문양으로 채우세요" % RingBoard.TEMPLATES[idx].name, false)
	_refresh_commit()


# ─────────────────────────── 맺기 ───────────────────────────

func _on_assembly_changed() -> void:
	_refresh_commit()


func _try_commit() -> void:
	if not bool(_board.call(&"can_commit")):
		_set_say("문양을 하나라도 고리에 얹어야 맺힌다", true)
		return
	_committed = true
	_set_say("맺혔다 — 책을 덮고(ESC) 쏴 보세요", false)
	design_committed.emit(_board.call(&"get_assembly"))
	_refresh_commit()


func _refresh_commit() -> void:
	_commit_btn.disabled = not bool(_board.call(&"can_commit"))
	_commit_btn.text = "✓ 맺힘" if _committed else "✓ 맺기 (Enter)"


func _set_say(text: String, warn: bool) -> void:
	if text == "":
		return
	_say.text = text
	_say.add_theme_color_override(&"font_color", WARN_COLOR if warn else SAY_COLOR)


# ─────────────────────────── 외부 조회 ───────────────────────────

func get_assembly() -> Dictionary:
	if not _committed:
		return {}
	return _board.call(&"get_assembly")


func can_commit() -> bool:
	return bool(_board.call(&"can_commit"))


func clear_board() -> void:
	_board.call(&"clear_all")
	_committed = false
	_set_say(Copy_START, false)
	_refresh_commit()


func play_cast() -> void:
	_board.call(&"play_cast")


# ─────────────────────────── 책 만들기 ───────────────────────────

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_spread = Control.new()
	_spread.name = "Spread"
	_spread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spread.pivot_offset = BOOK_RECT.get_center()
	add_child(_spread)

	var pages := Control.new()
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages.draw.connect(_draw_pages.bind(pages))
	_spread.add_child(pages)

	var paper := ColorRect.new()
	paper.color = PAPER_L
	paper.position = BOARD_RECT.position
	paper.size = BOARD_RECT.size
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread.add_child(paper)

	_board = RingBoard.new()
	_board.name = "RingBoard"
	_board.position = BOARD_RECT.position
	_board.size = BOARD_RECT.size
	_spread.add_child(_board)
	_board.connect(&"assembly_changed", _on_assembly_changed)

	_book = RingBook.new()
	_book.name = "RingBook"
	_book.position = BOOK_RECT_R.position
	_book.size = BOOK_RECT_R.size
	_spread.add_child(_book)
	_book.connect(&"glyph_selected", _on_glyph_selected)
	_book.connect(&"template_selected", _on_template_selected)

	_commit_btn = Button.new()
	_commit_btn.position = COMMIT_BTN_RECT.position
	_commit_btn.size = COMMIT_BTN_RECT.size
	_commit_btn.text = "✓ 맺기 (Enter)"
	_commit_btn.add_theme_font_size_override(&"font_size", 9)
	_commit_btn.disabled = true
	_commit_btn.focus_mode = Control.FOCUS_NONE
	_commit_btn.pressed.connect(_try_commit)
	_spread.add_child(_commit_btn)

	_title = _label(TITLE_RECT, 10, TITLE_COLOR)
	_title.text = "고리 조립 마법진"
	_say = _label(SAY_RECT, 8, SAY_COLOR)
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say.text = Copy_START
	_hint = _label(HINT_RECT, 8, HINT_COLOR)
	_hint.text = "문양본 탭=틀 삽입 · 문양 탭/Q·W=채우기 · 칸 클릭=개별 조절 · Enter=맺기 · ESC=덮기"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _draw_pages(on: Control) -> void:
	var shadow := BOOK_RECT.grow(3.0)
	on.draw_rect(shadow, SHADOW, true)
	on.draw_rect(BOOK_RECT, PAPER_L, true)

	var right := Rect2(BOOK_RECT.position + Vector2(PAGE_W, 0.0),
		Vector2(PAGE_W, BOOK_RECT.size.y))
	on.draw_rect(right, PAPER_R, true)

	var mid := BOOK_RECT.position.x + PAGE_W
	for i in 7:
		var t := float(i) / 6.0
		var col := SPINE
		col.a = SPINE.a * (1.0 - t) * 0.8
		var w := 1.0 + t * 2.0
		on.draw_line(Vector2(mid - t * 7.0, BOOK_RECT.position.y),
			Vector2(mid - t * 7.0, BOOK_RECT.end.y), col, w)
		on.draw_line(Vector2(mid + t * 7.0, BOOK_RECT.position.y),
			Vector2(mid + t * 7.0, BOOK_RECT.end.y), col, w)
	on.draw_line(Vector2(mid, BOOK_RECT.position.y), Vector2(mid, BOOK_RECT.end.y),
		Color(0.42, 0.35, 0.27, 0.8), 1.0)

	on.draw_rect(BOOK_RECT, EDGE, false, 1.0)


func _label(r: Rect2, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread.add_child(l)
	return l
