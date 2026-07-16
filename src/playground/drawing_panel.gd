extends Control
## 그리기 오버레이 — 씬(.tscn)으로 재구성한 버전.
##
## 🔴 목적: **에디터에서 드래그로 UI를 편집한다.** 겉틀(책 배경·좌우 페이지·라벨·버튼·잉크바)은
## 전부 drawing_panel.tscn의 노드다 → Godot 에디터에서 위치·크기·색·글꼴을 직접 만진다.
## 엔진 위젯 3개(DrawingCanvas·ForgeBook·DesignChecklist)는 잘 도는 것을 슬롯에 얹어 재사용한다
## — 인식기 내부까지 시각 편집할 필요는 없으니까.
##
## 배선은 forge_panel의 것을 그대로 가져왔다(검증된 계약). 계약: open() → 열림 / closed → 닫힘.
## 슬롯 노드 이름을 바꾸면 아래 @onready 경로도 같이 바꿔야 한다.

const DrawingCanvas := preload("res://src/drawing/drawing_canvas.gd")
const ForgeBook := preload("res://src/drawing/forge_book.gd")
const DesignChecklist := preload("res://src/drawing/design_checklist.gd")
const Copy := preload("res://src/drawing/drawing_copy.gd")

signal closed
signal design_completed(design: SpellDesign)
## 탁본 필사 — 숫자키로 예시를 부른다. 예시 목록은 바깥이 쥐므로 인덱스만 올린다.
signal example_requested(idx: int)

# ── 겉틀 슬롯 (전부 씬 노드 — 에디터에서 편집) ──
@onready var _canvas_slot: Control = $Book/LeftPage/CanvasSlot
@onready var _book_slot: Control = $Book/RightPage/BookSlot
@onready var _checklist_slot: Control = $Book/ChecklistSlot
@onready var _ink_bar: ProgressBar = $Book/InkBar
@onready var _title: Label = $Book/Title
@onready var _say: Label = $Book/Say
@onready var _hint: Label = $Book/Hint
@onready var _commit_btn: Button = $Book/CommitButton

# ── 슬롯에 얹는 엔진 위젯 ──
var _canvas: Control
var _book: Control
var _checklist: Control

var _paper_id: StringName = &""
var _prev_can_commit := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 열려 있는 동안 뒤 세계로 클릭이 새지 않게
	visible = false


func _ready() -> void:
	# 캔버스 — 왼쪽 페이지 슬롯을 채운다. size로 좌표계가 잡히므로 슬롯을 키우면 종이가 커진다.
	_canvas = DrawingCanvas.new()
	_fill_slot(_canvas_slot, _canvas)
	_canvas.connect(&"stage_changed", _on_stage_changed)
	_canvas.connect(&"stroke_rejected", _on_stroke_rejected)
	_canvas.connect(&"completion_blocked", _on_completion_blocked)
	_canvas.connect(&"design_completed", _on_design_completed)
	_canvas.connect(&"ink_state_changed", _on_ink_changed)
	_canvas.connect(&"trace_changed", _on_trace_changed)
	_canvas.connect(&"commit_state_changed", _on_commit_state_changed)

	# 책자 — 오른쪽 페이지 슬롯. 진/룬/문양 탭, 예시를 골라 종이에 옅게 얹는다.
	_book = ForgeBook.new()
	_fill_slot(_book_slot, _book)
	_book.connect(&"glyph_picked", _on_glyph_picked)

	# 체크리스트 — 진 → 룬 → 문양 진행 표시.
	_checklist = DesignChecklist.new()
	_fill_slot(_checklist_slot, _checklist)
	_checklist.call(&"bind", _canvas)

	_commit_btn.pressed.connect(_try_commit)
	_commit_btn.disabled = true
	_commit_btn.focus_mode = Control.FOCUS_NONE   # Enter가 버튼 포커스로 새지 않게 — 캔버스가 주인공
	if _hint.text == "":
		_hint.text = "%s   ·   Enter = 맺기   ·   %s" % [Copy.CONTROLS, Copy.FORGE_CLOSE]
	_refresh_title()


## 위젯을 슬롯 크기에 맞춰 채운다 (앵커 전체 — 슬롯을 리사이즈하면 위젯도 따라간다)
func _fill_slot(slot: Control, widget: Control) -> void:
	widget.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(widget)


# ─────────────────────────── 열고 닫기 ───────────────────────────

func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	_pick_paper()
	_book.call(&"refresh")
	_book.call(&"follow_stage", _canvas.call(&"get_stage"))
	_say.text = ""
	_prev_can_commit = false
	_on_commit_state_changed(bool(_canvas.call(&"can_commit")), bool(_canvas.call(&"is_committed")))


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


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
	if k.keycode == KEY_Z and k.ctrl_pressed:
		_canvas.call(&"undo_last")
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		_try_commit()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_0:
		_canvas.call(&"clear_rubbing")
		get_viewport().set_input_as_handled()
	elif k.keycode >= KEY_1 and k.keycode <= KEY_9:
		example_requested.emit(k.keycode - KEY_1)
		get_viewport().set_input_as_handled()


# ─────────────────────────── 탁본(예시 얹기) ───────────────────────────

## 완성된 도안을 캔버스에 옅은 탁본으로 깐다 — 그 위에 따라 그린다.
func show_rubbing(design: SpellDesign) -> void:
	_canvas.call(&"show_rubbing", design)


func clear_rubbing() -> void:
	_canvas.call(&"clear_rubbing")


# ─────────────────────────── 종이 ───────────────────────────

func _pick_paper() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	var db := get_node_or_null(^"/root/Db")
	if gs == null or db == null:
		return
	var drawn := int(_canvas.call(&"get_summary").get("stroke_count", 0)) > 0
	if drawn:
		_refresh_title()
		return
	for def: ItemDef in _papers_owned(gs, db):
		if _paper_id == def.id:
			_refresh_title()
			return
		_paper_id = def.id
		_canvas.call(&"set_paper", def.id, def.grade, def.params)
		_refresh_title()
		return
	_paper_id = &""
	_canvas.call(&"set_no_paper")
	_refresh_title()


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
		return
	var count := int(gs.call(&"get_count", _paper_id)) if gs != null else 0
	var def: ItemDef = db.call(&"get_item", _paper_id) if db != null else null
	var paper_name: String = def.display_name if def != null else String(_paper_id)
	_title.text = "%s  ·  %s ×%d" % [Copy.FORGE_TITLE, paper_name, count]


# ─────────────────────────── 캔버스 신호 ───────────────────────────

func _on_stage_changed(stage: int) -> void:
	_canvas.call(&"clear_trace")
	_book.call(&"follow_stage", stage)


func _on_glyph_picked(stage: int, unit_pts: PackedVector2Array) -> void:
	if unit_pts.is_empty():
		_canvas.call(&"clear_trace")
	else:
		_canvas.call(&"show_trace", stage, unit_pts)


func _on_trace_changed(active: bool) -> void:
	if not active:
		_set_say(Copy.CONTROLS, false)
		return
	if bool(_canvas.call(&"is_holding_trace")):
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
	_refresh_title()
	design_completed.emit(design)


func _try_commit() -> void:
	_canvas.call(&"commit_design")


func _on_commit_state_changed(can_commit: bool, _committed: bool) -> void:
	_commit_btn.disabled = not can_commit
	if can_commit and not _prev_can_commit:
		_set_say(Copy.READY_TO_COMMIT, false)
	_prev_can_commit = can_commit


func _on_ink_changed(used: float, capacity: float) -> void:
	# 무한 잉크(샌드박스)나 종이 없음 → 상한이 INF라 바를 숨긴다
	if not is_finite(capacity) or capacity <= 0.0:
		_ink_bar.visible = false
		return
	_ink_bar.visible = true
	_ink_bar.max_value = capacity
	_ink_bar.value = used


func _set_say(text: String, _warn: bool) -> void:
	if text == "":
		return
	_say.text = text


# ─────────────────────────── 외부 조회 ───────────────────────────

func get_design() -> SpellDesign:
	return _canvas.call(&"get_design")


func can_commit() -> bool:
	return bool(_canvas.call(&"can_commit"))


## 개발 샌드박스용 무한 잉크 (잉크 경제 없이 그리는 손맛만)
func set_ink_unlimited(v: bool) -> void:
	_canvas.call(&"set_ink_unlimited", v)


func clear_canvas() -> void:
	_canvas.call(&"clear_all")
	_pick_paper()
	_say.text = ""
