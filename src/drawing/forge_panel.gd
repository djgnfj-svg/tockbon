extends Control
## 도안 제작대 — **책을 좌우로 펼친다.** 게임 본편에 들어갈 마법 제작 UI (사용자 결정, 세션 8).
##
## 왼쪽 페이지 = 종이(그린다) · 오른쪽 페이지 = 도안 책자(본다).
## 책자는 **참조**다 — 골라서 찍는 게 아니라 보고 따라 그린다. 입력은 끝까지 손그림 하나뿐이고
## 판정은 인식기가 한다. 오른쪽에서 무엇을 고르든 캔버스는 달라지지 않는다.
##
## 오버레이다 — 씬을 갈아 끼우지 않는다. 작업대에 다가가 열고(E), ESC로 닫으면
## 뒤에 있던 세계가 그대로 남아 있다. 그려서 바로 쏴 보는 왕복이 끊기지 않는 게 핵심.
##
## 계약(ui_root의 화면들과 동일): open() → 열림 / closed 시그널 → 닫힘. 여는 쪽이 스택을 관리한다.
## 사용: const ForgePanel := preload("res://src/drawing/forge_panel.gd")
##       var f := ForgePanel.new(); parent.add_child(f); f.open()

const DrawingCanvas := preload("res://src/drawing/drawing_canvas.gd")
const DesignChecklist := preload("res://src/drawing/design_checklist.gd")
const ForgeBook := preload("res://src/drawing/forge_book.gd")
const Copy := preload("res://src/drawing/drawing_copy.gd")

signal closed
## 도안이 방금 맺혔다 — 여는 쪽(작업대·거점)이 연출·안내에 쓴다
signal design_completed(design: SpellDesign)
## 🔴 탁본 필사 — 책 펼친 중 숫자키를 눌렀다. 예시 목록은 바깥(시험대·거점)이 쥐므로 인덱스만
## 올린다. 받은 쪽이 해당 도안을 show_rubbing으로 깐다.
signal example_requested(idx: int)

# ── 레이아웃 (뷰포트 640×360 고정) ──
const BOOK_RECT := Rect2(16, 10, 608, 340)
const PAGE_W := 304.0                                # 반쪽
const CANVAS_RECT := Rect2(38, 34, 260, 260)         # 왼쪽 페이지의 종이
const INK_BAR_RECT := Rect2(38, 298, 260, 5)
const CHECK_RECT := Rect2(38, 307, 260, 42)
const BOOK_RECT_R := Rect2(332, 24, 280, 262)        # 오른쪽 페이지의 책자
const SAY_RECT := Rect2(332, 288, 280, 26)           # 스승의 말 — 책의 여백에 적힌다
const COMMIT_BTN_RECT := Rect2(332, 316, 150, 20)    # 🔴 확정 버튼 (F1) — 초안을 맺는다
const HINT_RECT := Rect2(332, 338, 280, 12)
const TITLE_RECT := Rect2(28, 16, 280, 14)

# ── 한지·먹 톤 (src/ui의 InkStyle은 타 모듈 — CLAUDE.md 모듈 규칙상 참조하지 않는다) ──
const DIM := Color(0.05, 0.04, 0.03, 0.62)           # 뒤 세계를 눌러 준다 (닫으면 다시 보인다)
const PAPER_L := Color(0.93, 0.89, 0.80)             # 왼쪽 = 그리는 종이 (가장 밝게)
const PAPER_R := Color(0.89, 0.84, 0.74)             # 오른쪽 = 책장 (살짝 어둡게 — 두 장으로 읽히게)
const SPINE := Color(0.62, 0.55, 0.45, 0.55)         # 접힘 — 가운데로 갈수록 어두워진다
const EDGE := Color(0.45, 0.38, 0.30, 0.70)
const SHADOW := Color(0.0, 0.0, 0.0, 0.35)
const TITLE_COLOR := Color(0.36, 0.26, 0.16)
const INFO_COLOR := Color(0.48, 0.42, 0.34)
const HINT_COLOR := Color(0.50, 0.45, 0.38)
const SAY_COLOR := Color(0.30, 0.24, 0.18)
const WARN_COLOR := Color(0.62, 0.22, 0.14)
const INK_FILL := Color(0.20, 0.17, 0.15, 0.85)
const INK_OVER_FILL := Color(0.62, 0.22, 0.14, 0.9)
const INK_TRACK := Color(0.72, 0.66, 0.56, 0.55)

# ── 펼침 연출 — 책이 좌우로 열린다 ──
const OPEN_SEC := 0.20
const OPEN_FROM_X := 0.04            # 접힌 상태(세로 한 줄)에서 벌어진다
const CLOSE_SEC := 0.12

var _canvas: Control
var _book: Control
var _checklist: Control
var _paper: ColorRect
var _ink_bar: Control
var _title: Label
var _say: Label
var _hint: Label
var _commit_btn: Button              # 🔴 확정 버튼 (F1) — 초안이 준비됐을 때만 눌린다
var _prev_can_commit := false        # 확정 안내는 준비된 그 순간에만 (매 갱신 재출력 금지)
var _spread: Control                 # 책 전체 — 펼침 tween이 물리는 노드

var _paper_id: StringName = &""
var _ink_used: float = 0.0
var _ink_cap: float = INF
var _opening := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 열려 있는 동안 뒤 세계로 클릭이 새지 않게
	visible = false


func _ready() -> void:
	_build()


# ─────────────────────────── 열고 닫기 ───────────────────────────

func is_open() -> bool:
	return visible


## 🔴 완성된 도안을 캔버스에 옅은 탁본으로 깐다 — 그 위에 필사한다 (캔버스로 forwarding).
func show_rubbing(design: SpellDesign) -> void:
	_canvas.call(&"show_rubbing", design)


func clear_rubbing() -> void:
	_canvas.call(&"clear_rubbing")


## 책을 펼친다. 종이는 보유분 중 최저 등급을 자동으로 집는다 — 열자마자 그릴 수 있어야 한다
func open() -> void:
	if visible:
		return
	visible = true
	_pick_paper()
	_book.call(&"refresh")                  # 그새 해금된 룬이 있을 수 있다
	_book.call(&"follow_stage", _canvas.call(&"get_stage"))
	_say.text = ""
	# 다시 펼치면 확정 안내를 새로 낼 수 있게 한다 (이미 준비된 초안을 안고 다시 열 수 있다)
	_prev_can_commit = false
	_on_commit_state_changed(bool(_canvas.call(&"can_commit")), bool(_canvas.call(&"is_committed")))
	_spread_open()


func close() -> void:
	if not visible:
		return
	var tw := create_tween()
	tw.tween_property(_spread, ^"scale", Vector2(OPEN_FROM_X, 1.0), CLOSE_SEC) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		visible = false
		closed.emit())


## 펼침 — 접힌 책이 좌우로 벌어진다. 벌어지는 동안엔 종이가 입력을 받지 않는다
## (스케일 중 좌표가 어긋난 채로 획이 들어가면 엉뚱한 자리에 먹이 앉는다)
func _spread_open() -> void:
	_opening = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread.scale = Vector2(OPEN_FROM_X, 1.0)
	var tw := create_tween()
	tw.tween_property(_spread, ^"scale", Vector2.ONE, OPEN_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func() -> void:
		_opening = false
		_canvas.mouse_filter = Control.MOUSE_FILTER_STOP)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_Z and k.ctrl_pressed:
		_canvas.call(&"undo_last")
		get_viewport().set_input_as_handled()
		return
	# 🔴 **Enter = 도안을 맺는다** (F1, 2026-07-15) — 명시적 확정. 준비된 초안만 맺힌다.
	if k != null and k.pressed and not k.echo \
			and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER):
		_try_commit()
		get_viewport().set_input_as_handled()
		return
	# 🔴 탁본 필사 — 숫자키로 예시를 부른다 (책 펼친 중). 실제 예시 목록은 바깥(시험대·거점)이
	# 쥐고 있으므로 요청만 올린다. 0 = 탁본 걷기.
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_0:
			_canvas.call(&"clear_rubbing")
			get_viewport().set_input_as_handled()
		elif k.keycode >= KEY_1 and k.keycode <= KEY_9:
			example_requested.emit(k.keycode - KEY_1)
			get_viewport().set_input_as_handled()


# ─────────────────────────── 종이 ───────────────────────────

## 보유한 종이 중 **가장 낮은 등급**을 집는다 (아끼는 손이 기본). 한 장도 없으면 그릴 수는
## 있되 도안이 맺히지 않는다.
##
## 규칙 하나가 이 함수를 지배한다: **그리던 종이는 바꾸지 않는다.** 종이를 바꾸면 캔버스가
## 지워지므로(set_paper → clear_all), 획이 하나라도 있으면 손대지 않는다. 쓰던 종이가
## 소진돼도 마찬가지다 — 값은 이미 치렀으니 그 도안은 끝까지 고쳐 그릴 수 있다.
## 승격은 **캔버스가 빈 자리에서만** 일어난다: 종이를 비우거나 새로 펼칠 때.
func _pick_paper() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	var db := get_node_or_null(^"/root/Db")
	if gs == null or db == null:
		return
	var drawn := int(_canvas.call(&"get_summary").get("stroke_count", 0)) > 0
	if drawn:
		_refresh_title()
		return                              # 그리는 중 — 종이를 갈면 그린 획이 사라진다
	for def: ItemDef in _papers_owned(gs, db):
		if _paper_id == def.id:
			_refresh_title()
			return                          # 이미 그 종이를 쓰고 있다
		_paper_id = def.id
		_canvas.call(&"set_paper", def.id, def.grade, def.params)
		_refresh_title()
		return
	_paper_id = &""
	_canvas.call(&"set_no_paper")
	_refresh_title()


## 보유 중인 종이를 등급 오름차순으로. Db를 훑으므로 종이 종류가 늘어도 코드가 안 바뀐다
func _papers_owned(gs: Node, db: Node) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for id: StringName in db.get(&"items"):
		var def: ItemDef = db.call(&"get_item", id)
		if def == null or def.kind != Enums.ItemKind.PAPER:
			continue
		if int(gs.call(&"get_count", id)) > 0:
			out.append(def)
	out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.grade < b.grade)
	return out


func _refresh_title() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	var db := get_node_or_null(^"/root/Db")
	if _paper_id == StringName():
		_title.text = "%s  ·  %s 없음" % [Copy.FORGE_TITLE, Copy.FORGE_PAPER]
		_title.add_theme_color_override(&"font_color", WARN_COLOR)
		return
	var count := int(gs.call(&"get_count", _paper_id)) if gs != null else 0
	var def: ItemDef = db.call(&"get_item", _paper_id) if db != null else null
	var paper_name: String = def.display_name if def != null else String(_paper_id)
	_title.text = "%s  ·  %s ×%d" % [Copy.FORGE_TITLE, paper_name, count]
	# 마지막 장을 쓰고 있으면 미리 알린다 — 다 그리고 나서 "종이 없음"을 보는 것보다 낫다
	_title.add_theme_color_override(&"font_color",
		WARN_COLOR if count == 0 else TITLE_COLOR)


# ─────────────────────────── 캔버스 신호 ───────────────────────────

## 그 부품을 그려냈다 — 밑그림은 걷고, 책은 다음 장을 편다.
func _on_stage_changed(stage: int) -> void:
	_canvas.call(&"clear_trace")
	_book.call(&"follow_stage", stage)


## 책자에서 본보기를 **집는다** — 마우스에 붙어 따라오다가 종이를 누르면 앉는다 (빈 점열 = 걷는다).
## 앉은 본보기는 자석이 된다: 그 위를 그으면 획이 끌린다 (StrokeGuide)
func _on_glyph_picked(stage: int, unit_pts: PackedVector2Array) -> void:
	if unit_pts.is_empty():
		_canvas.call(&"clear_trace")
	else:
		_canvas.call(&"show_trace", stage, unit_pts)


## 본보기를 들었나/놓았나/걷었나 — 지금 뭘 할 수 있는지 말해 준다.
## 새 조작(휠 = 크기)을 아무도 안 알려 주면 **크기가 세기라는 걸 영영 모른다**
func _on_trace_changed(active: bool) -> void:
	if not active:
		_set_say(Copy.CONTROLS, false)
		return
	if bool(_canvas.call(&"is_holding_trace")):
		# 문양은 고무줄 겨눔, 룬은 눌러 앉히기 — 조작이 다르므로 문구도 다르다
		_set_say(Copy.TRACE_HELD_ARROW if bool(_canvas.call(&"is_arrow_trace")) \
			else Copy.TRACE_HELD, false)
	else:
		_set_say(Copy.TRACE_PLACED, false)


func _on_stroke_rejected(reason: StringName) -> void:
	_set_say(Copy.reject_line(reason, _canvas.call(&"get_stage"),
		_canvas.call(&"get_last_reject")), true)


func _on_completion_blocked(_reason: StringName) -> void:
	_set_say(Copy.NO_PAPER, true)


func _on_design_completed(design: SpellDesign) -> void:
	_set_say(Copy.COMPLETE, false)
	_refresh_title()                        # 종이 한 장이 방금 소모됐다
	design_completed.emit(design)


## 🔴 확정 시도 (F1) — Enter·버튼 공용. 준비 안 됐으면 캔버스가 조용히 무시한다(false).
func _try_commit() -> void:
	_canvas.call(&"commit_design")


## 맺힘 상태가 바뀌었다 — 버튼 활성/문구를 맞춘다. 준비된 **그 순간에만** 안내를 띄운다
## (매 갱신 재출력하면 거부 메시지 등을 덮어 소음이 된다).
func _on_commit_state_changed(can_commit: bool, _committed: bool) -> void:
	_commit_btn.disabled = not can_commit
	if can_commit and not _prev_can_commit:
		_set_say(Copy.READY_TO_COMMIT, false)
	_prev_can_commit = can_commit


func _on_ink_changed(used: float, capacity: float) -> void:
	_ink_used = used
	_ink_cap = capacity
	_ink_bar.queue_redraw()


## 먹 게이지 — 남은 먹이 곧 남은 설계 여지다 (GDD §5: 배분이 곧 설계)
func _draw_ink_bar() -> void:
	var r := Rect2(Vector2.ZERO, _ink_bar.size)
	_ink_bar.draw_rect(r, INK_TRACK, true)
	if not is_finite(_ink_cap) or _ink_cap <= 0.0:
		return
	var t := clampf(_ink_used / _ink_cap, 0.0, 1.0)
	var fill := r
	fill.size.x *= t
	_ink_bar.draw_rect(fill, INK_OVER_FILL if t > 0.98 else INK_FILL, true)


func _set_say(text: String, warn: bool) -> void:
	if text == "":
		return
	_say.text = text
	_say.add_theme_color_override(&"font_color", WARN_COLOR if warn else SAY_COLOR)


# ─────────────────────────── 책 만들기 ───────────────────────────

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# 책 전체 — 펼침 tween이 이 노드에 물린다. 피벗은 접힘(가운데)
	_spread = Control.new()
	_spread.name = "Spread"
	_spread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spread.pivot_offset = BOOK_RECT.get_center()
	add_child(_spread)

	var pages := Control.new()                 # 종이·접힘·테두리를 그리는 배경
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages.draw.connect(_draw_pages.bind(pages))
	_spread.add_child(pages)

	# 왼쪽 페이지 — 종이. 캔버스는 이 위에 얹는다
	_paper = ColorRect.new()
	_paper.color = PAPER_L
	_paper.position = CANVAS_RECT.position
	_paper.size = CANVAS_RECT.size
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread.add_child(_paper)

	_canvas = DrawingCanvas.new()
	_canvas.name = "DrawingCanvas"
	_canvas.position = CANVAS_RECT.position
	_canvas.size = CANVAS_RECT.size
	_spread.add_child(_canvas)
	_canvas.connect(&"stage_changed", _on_stage_changed)
	_canvas.connect(&"stroke_rejected", _on_stroke_rejected)
	_canvas.connect(&"completion_blocked", _on_completion_blocked)
	_canvas.connect(&"design_completed", _on_design_completed)
	_canvas.connect(&"ink_state_changed", _on_ink_changed)
	_canvas.connect(&"trace_changed", _on_trace_changed)
	_canvas.connect(&"commit_state_changed", _on_commit_state_changed)

	_ink_bar = Control.new()
	_ink_bar.position = INK_BAR_RECT.position
	_ink_bar.size = INK_BAR_RECT.size
	_ink_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink_bar.draw.connect(_draw_ink_bar)
	_spread.add_child(_ink_bar)

	_checklist = DesignChecklist.new()
	_checklist.position = CHECK_RECT.position
	_checklist.size = CHECK_RECT.size
	_spread.add_child(_checklist)
	_checklist.call(&"bind", _canvas)

	# 오른쪽 페이지 — 책자(탭). 여기서 고르는 건 **볼 장**이지 그릴 것이 아니다.
	# 다만 고른 본보기는 종이에 옅게 얹힌다 — 찍는 게 아니라 따라 그을 밑그림으로
	_book = ForgeBook.new()
	_book.position = BOOK_RECT_R.position
	_book.size = BOOK_RECT_R.size
	_spread.add_child(_book)
	_book.connect(&"glyph_picked", _on_glyph_picked)

	# 🔴 확정 버튼 (F1) — 초안이 준비됐을 때만 눌린다. Enter와 같은 일을 한다(둘 다 제공).
	_commit_btn = Button.new()
	_commit_btn.position = COMMIT_BTN_RECT.position
	_commit_btn.size = COMMIT_BTN_RECT.size
	_commit_btn.text = Copy.COMMIT_BUTTON
	_commit_btn.add_theme_font_size_override(&"font_size", 9)
	_commit_btn.disabled = true
	_commit_btn.focus_mode = Control.FOCUS_NONE   # Enter가 버튼 포커스로 새지 않게 — 캔버스가 주인공
	_commit_btn.pressed.connect(_try_commit)
	_spread.add_child(_commit_btn)

	_title = _label(TITLE_RECT, 10, TITLE_COLOR)
	_say = _label(SAY_RECT, 8, SAY_COLOR)
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = _label(HINT_RECT, 8, HINT_COLOR)
	_hint.text = "%s   ·   Enter = 맺기   ·   %s" % [Copy.CONTROLS, Copy.FORGE_CLOSE]
	_refresh_title()


## 펼친 책 — 두 장의 한지, 가운데 접힘, 바깥 그림자
func _draw_pages(on: Control) -> void:
	var shadow := BOOK_RECT.grow(3.0)
	on.draw_rect(shadow, SHADOW, true)
	on.draw_rect(BOOK_RECT, PAPER_L, true)

	var right := Rect2(BOOK_RECT.position + Vector2(PAGE_W, 0.0),
		Vector2(PAGE_W, BOOK_RECT.size.y))
	on.draw_rect(right, PAPER_R, true)

	# 접힘 — 가운데로 갈수록 어두워지는 띠. 두 장으로 갈라진 게 눈에 읽혀야 "책"이 된다
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


# ─────────────────────────── 외부 조회 ───────────────────────────

## 지금 종이 위에 **맺힌** 도안 (없으면 null) — 작업대가 "그린 걸 바로 쏴 보기"에 쓴다.
## 🔴 초안(미확정)은 여기 안 잡힌다 — Enter로 맺어야 실재한다 (F1).
func get_design() -> SpellDesign:
	return _canvas.call(&"get_design")


## 초안이 준비돼 Enter 한 번이면 맺히는가 — 작업대가 "왜 못 쏘는지"를 안내하는 데 쓴다
func can_commit() -> bool:
	return bool(_canvas.call(&"can_commit"))


## 🔴 개발 시험대용 무한 잉크 (잉크 상한 무시). 게임 본편에선 쓰지 않는다.
func set_ink_unlimited(v: bool) -> void:
	_canvas.call(&"set_ink_unlimited", v)


## 종이를 비운다 — 빈 자리가 났으니 이때 종이도 다시 집는다 (소진분 → 다음 등급 승격)
func clear_canvas() -> void:
	_canvas.call(&"clear_all")
	_pick_paper()
	_say.text = ""
