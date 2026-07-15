extends Node2D
## 모듈 A 인터랙티브 시험대 (tests/test_drawing.tscn 루트, F6 실행).
## 좌: 드로잉 캔버스 / 우: 인식 결과·정확도·잉크·마나 라벨, 자동보정·스탬프·시험 발사 시각화.
## UI는 전부 코드 생성 — .tscn 수동 편집 최소화(병렬 작업 충돌 방지).

const DrawingCanvas := preload("res://src/drawing/drawing_canvas.gd")
const DesignBuilder := preload("res://src/drawing/design_builder.gd")
const StampLibrary := preload("res://src/drawing/stamp_library.gd")
const DesignChecklist := preload("res://src/drawing/design_checklist.gd")
const DesignBook := preload("res://src/drawing/design_book.gd")
const Copy := preload("res://src/drawing/drawing_copy.gd")

const PAPER_COLOR := Color(0.93, 0.89, 0.80)
const BG_COLOR := Color(0.16, 0.13, 0.11)
const TEXT_COLOR := Color(0.90, 0.86, 0.78)
const HINT_COLOR := Color(0.7, 0.66, 0.58)
const WARN_COLOR := Color(0.92, 0.45, 0.35)

const ROLE_NAMES := {
	Enums.StrokeRole.CIRCLE: "진(원)",
	Enums.StrokeRole.RUNE: "룬",
	Enums.StrokeRole.ARROW: "화살표",
	Enums.StrokeRole.DECOR: "미인식(장식)",
}

var _canvas: Control
var _lib := StampLibrary.new()
var _design: SpellDesign = null

var _checklist: VBoxContainer
var _book: HBoxContainer
var _commit_btn: Button              # 🔴 확정 버튼 (F1) — 초안을 맺는다 (Enter와 같은 일)
var _prev_can_commit := false
var _recog_label: Label
var _design_label: Label
var _hint_label: Label
var _stamp_list: ItemList
var _trial: Control

var _paper_select: OptionButton
var _ink_label: Label
var _paper_ids: Array[StringName] = []   # OptionButton 인덱스 → 종이 id
var _paper_id: StringName = &""          # 현재 선택 종이 (빈 값 = 미선택)


func _ready() -> void:
	var ui := Control.new()
	ui.name = "UI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)

	var paper := ColorRect.new()
	paper.color = PAPER_COLOR
	paper.position = Vector2(12, 16)
	paper.size = Vector2(320, 320)
	ui.add_child(paper)

	_canvas = DrawingCanvas.new()
	_canvas.name = "DrawingCanvas"
	_canvas.position = paper.position
	_canvas.size = paper.size
	ui.add_child(_canvas)
	_canvas.design_state_changed.connect(_on_design_state_changed)
	_canvas.stroke_classified.connect(_on_stroke_classified)
	_canvas.stamp_placement_done.connect(_on_stamp_placed)

	var x := 344.0
	var w := 288.0
	var title := _make_label(ui, Vector2(x, 4), Vector2(w, 14), "탁본 — 드로잉·인식 시험대", 11)
	title.add_theme_color_override(&"font_color", Color(0.95, 0.85, 0.6))
	# 작성 체크리스트 — 진 → 룬 → 문양 + 완성 문구(4행).
	# 순서가 강제되므로 지금 차례가 늘 보여야 하고, 해낼 때마다 ✓가 팝한다
	_checklist = DesignChecklist.new()
	_checklist.position = Vector2(x, 22)
	_checklist.size = Vector2(w, 60)
	ui.add_child(_checklist)
	_checklist.bind(_canvas)

	# 도안 책자 — 인식기가 실제로 매칭하는 템플릿을 그대로 보여 준다.
	# 보고 따라 그리면 반드시 인식되므로, 인식 실패의 근본 완화책이기도 하다
	_book = DesignBook.new()
	_book.position = Vector2(x, 84)
	_book.size = Vector2(w, 54)
	ui.add_child(_book)

	_recog_label = _make_label(ui, Vector2(x, 142), Vector2(w, 24), "최근 인식: —", 9)
	_design_label = _make_label(ui, Vector2(x, 168), Vector2(w, 40), "", 9)

	var btn_row := HBoxContainer.new()
	btn_row.position = Vector2(x, 210)
	btn_row.size = Vector2(w, 20)
	ui.add_child(btn_row)
	# 🔴 확정 버튼 (F1) — 초안을 맺는다. Enter와 같은 일. 준비됐을 때만 눌린다
	_commit_btn = Button.new()
	_commit_btn.text = Copy.COMMIT_BUTTON
	_commit_btn.add_theme_font_size_override(&"font_size", 9)
	_commit_btn.disabled = true
	_commit_btn.focus_mode = Control.FOCUS_NONE
	_commit_btn.pressed.connect(func() -> void: _canvas.commit_design())
	btn_row.add_child(_commit_btn)
	_add_button(btn_row, "자동보정", _on_autocorrect)
	_add_button(btn_row, "스탬프 저장", _on_save_stamp)
	_add_button(btn_row, "지우기", func() -> void: _canvas.clear_all())

	_make_label(ui, Vector2(x, 234), Vector2(w, 11), "필체 라이브러리 (클릭 → 캔버스 클릭으로 배치)", 8)
	_stamp_list = ItemList.new()
	_stamp_list.position = Vector2(x, 246)
	_stamp_list.size = Vector2(w, 40)
	_stamp_list.add_theme_font_size_override(&"font_size", 9)
	_stamp_list.item_selected.connect(_on_stamp_selected)
	ui.add_child(_stamp_list)

	_make_label(ui, Vector2(x, 290), Vector2(w, 11), "시험 발사 (실발사는 모듈 B)", 8)
	_trial = Control.new()
	_trial.position = Vector2(x, 302)
	_trial.size = Vector2(w, 50)
	_trial.draw.connect(_draw_trial)
	ui.add_child(_trial)

	_hint_label = _make_label(ui, Vector2(12, 340), Vector2(620, 14), "", 9)
	_set_default_hint()
	_refresh_design_label()

	# ── 종이 선택 + 잉크 게이지 (GDD §5 종이 등급 — 보유 종이만, 기본 = 최저 등급 자동)
	_canvas.ink_state_changed.connect(_on_ink_state_changed)
	_canvas.stroke_rejected.connect(_on_stroke_rejected)
	_canvas.completion_blocked.connect(_on_completion_blocked)
	_canvas.commit_state_changed.connect(_on_commit_state_changed)
	var paper_row := HBoxContainer.new()
	paper_row.position = Vector2(12, 0)
	paper_row.size = Vector2(320, 15)
	paper_row.add_theme_constant_override(&"separation", 8)
	ui.add_child(paper_row)
	_make_label(paper_row, Vector2.ZERO, Vector2(28, 14), "종이:", 9)
	_paper_select = OptionButton.new()
	_paper_select.add_theme_font_size_override(&"font_size", 9)
	_paper_select.custom_minimum_size = Vector2(140, 14)
	_paper_select.item_selected.connect(_on_paper_selected)
	paper_row.add_child(_paper_select)
	_ink_label = _make_label(paper_row, Vector2.ZERO, Vector2(110, 14), "", 9)
	_ink_label.custom_minimum_size = Vector2(110, 14)
	EventBus.resources_changed.connect(_refresh_paper_options)
	# 단독 시험대(F6·tests/test_drawing.tscn)에서만: 종이가 전혀 없으면 기본 종이를 시드해
	# 완성 흐름까지 검증할 수 있게 한다. 게임 씬(Main 하위 드로잉룸)에는 해당 없음.
	if get_tree().current_scene == self and GameState.get_count(&"paper_1") == 0:
		GameState.add_item(&"paper_1", 9)
	_refresh_paper_options()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_Z and k.ctrl_pressed:
		_canvas.undo_last()
	# 🔴 **Enter = 도안을 맺는다** (F1, 2026-07-15) — 명시적 확정. 준비된 초안만 맺힌다
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		_canvas.commit_design()


# ─────────────────────────── UI 빌더 ───────────────────────────

func _make_label(parent: Control, pos: Vector2, sz: Vector2, text: String, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", TEXT_COLOR)
	parent.add_child(l)
	return l


func _add_button(row: HBoxContainer, text: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override(&"font_size", 9)
	b.pressed.connect(handler)
	row.add_child(b)


# ─────────────────────────── 이벤트 ───────────────────────────

func _on_stroke_classified(result: Dictionary) -> void:
	var role := int(result.get("role", Enums.StrokeRole.DECOR))
	var text := "최근 인식: %s" % ROLE_NAMES.get(role, "?")
	if role == Enums.StrokeRole.RUNE:
		text += " %s" % DesignBuilder.rune_name(int(result.rune_type))
	text += "  (점수 %.2f)" % float(result.get("score", 0.0))
	if role == Enums.StrokeRole.DECOR:
		text += "  [%s]" % str(result.get("reason", ""))
	_recog_label.text = text


func _on_design_state_changed(design: SpellDesign, _summary: Dictionary) -> void:
	# 부품 상태 표시는 체크리스트가 맡는다 (캔버스 신호에 직접 물려 있다)
	_design = design
	_refresh_design_label()
	_trial.queue_redraw()


func _refresh_design_label() -> void:
	if _design == null:
		_design_label.text = Copy.INCOMPLETE
		return
	_design_label.text = "%s\n정확도 %d%% · 잉크 %d · 마나 %.0f · 내구 %d/%d" % [
		_design.display_name,
		roundi(_design.rune_accuracy * 100.0),
		int(_design.ink_cost.get(&"ink_basic", 0)),
		_design.mana_cost,
		_design.durability, _design.durability_max,
	]


func _on_autocorrect() -> void:
	if _canvas.autocorrect_rune():
		_set_hint(Copy.AUTOCORRECT_OK)
	else:
		_set_hint(Copy.AUTOCORRECT_NONE)


func _on_save_stamp() -> void:
	var stamp: Dictionary = _canvas.save_rune_stamp()
	if stamp.is_empty():
		_set_hint(Copy.STAMP_NONE)
		return
	var idx := _lib.add(stamp)
	_stamp_list.add_item(_lib.label(idx))
	_set_hint(Copy.STAMP_SAVED)


func _on_stamp_selected(index: int) -> void:
	_canvas.begin_stamp_placement(_lib.get_stamp(index))
	_set_hint(Copy.STAMP_PLACE)


func _on_stamp_placed() -> void:
	_stamp_list.deselect_all()
	_set_default_hint()


# ─────────────────────────── 종이 선택·잉크 게이지 (GDD §5) ───────────────────────────

## 보유 종이 목록 갱신.
## 소진된 현재 종이는 **그리는 중일 때만** 목록에 남긴다 — 값은 이미 치렀으니 그 도안은
## 끝까지 고쳐 그릴 수 있어야 한다. 반대로 캔버스가 비어 있으면 소진분을 걷어내고
## 다음 등급으로 승격한다. 안 그러면 상급 종이를 쥐고도 ×0짜리에 고착돼 완성이 막힌다.
func _refresh_paper_options() -> void:
	var drawn := int(_canvas.get_summary().get("stroke_count", 0)) > 0
	var defs: Array[ItemDef] = []
	for id: StringName in Db.items:
		var def: ItemDef = Db.items[id]
		if def != null and def.kind == Enums.ItemKind.PAPER \
				and (GameState.get_count(id) > 0 or (id == _paper_id and drawn)):
			defs.append(def)
	defs.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.grade < b.grade)
	_paper_select.clear()
	_paper_ids.clear()
	for def in defs:
		_paper_ids.append(def.id)
		_paper_select.add_item("%s ×%d" % [def.display_name, GameState.get_count(def.id)])
	_paper_select.disabled = _paper_ids.is_empty()
	if _paper_ids.is_empty():
		_paper_select.add_item("종이 없음")
		_paper_select.select(0)
		_canvas.set_no_paper()
		return
	# 쓰던 종이가 목록에서 빠졌다(= 소진 + 캔버스가 빔) → 최저 등급으로 승격
	var idx := _paper_ids.find(_paper_id)
	if idx < 0:
		_paper_select.select(0)
		_on_paper_selected(0)
	else:
		_paper_select.select(idx)


func _on_paper_selected(index: int) -> void:
	if index < 0 or index >= _paper_ids.size():
		return
	var id := _paper_ids[index]
	var def: ItemDef = Db.get_item(id)
	if def == null or id == _paper_id:
		return
	_paper_id = id
	_canvas.set_paper(id, def.grade, def.params)
	_set_hint("종이 선택: %s — 캔버스 초기화 (잉크 상한 %d)" % [
		def.display_name, int(def.params.get("ink_capacity", 0))])


func _on_ink_state_changed(used: float, capacity: float) -> void:
	if is_inf(capacity):
		_ink_label.text = "잉크 %.0f / —" % used
		_ink_label.add_theme_color_override(&"font_color", TEXT_COLOR)
		return
	_ink_label.text = "잉크 %.0f / %.0f" % [used, capacity]
	_ink_label.add_theme_color_override(&"font_color",
		WARN_COLOR if used > capacity * 0.85 else TEXT_COLOR)


## 거부는 스승의 목소리로. 순서 위반이면 "지금 무엇을 그려야 하는지",
## 인식 실패면 "어느 룬에 얼마나 가까웠는지"를 숫자로 말해 준다
func _on_stroke_rejected(reason: StringName) -> void:
	_set_warn(Copy.reject_line(reason, _canvas.get_stage(), _canvas.get_last_reject()))


func _on_completion_blocked(_reason: StringName) -> void:
	_design_label.text = Copy.NO_PAPER
	_set_warn(Copy.NO_PAPER)


## 🔴 맺힘 상태 (F1) — 확정 버튼 활성/안내. 준비된 그 순간에만 안내한다(재출력 소음 방지).
func _on_commit_state_changed(can_commit: bool, _committed: bool) -> void:
	_commit_btn.disabled = not can_commit
	if can_commit and not _prev_can_commit:
		_set_hint(Copy.READY_TO_COMMIT)
	_prev_can_commit = can_commit


func _set_hint(text: String) -> void:
	_hint_label.text = text
	_hint_label.add_theme_color_override(&"font_color", HINT_COLOR)


func _set_warn(text: String) -> void:
	_hint_label.text = text
	_hint_label.add_theme_color_override(&"font_color", WARN_COLOR)


func _set_default_hint() -> void:
	# 순서 안내는 체크리스트가 상시 보여 준다 — 힌트는 조작법만
	_set_hint(Copy.CONTROLS)


# ─────────────────────────── 시험 발사 시각화 ───────────────────────────

func _draw_trial() -> void:
	_trial.draw_rect(Rect2(Vector2.ZERO, _trial.size), Color(0.08, 0.07, 0.06, 0.65))
	var font := ThemeDB.fallback_font
	if _design == null:
		_trial.draw_string(font, Vector2(8, 18), Copy.INCOMPLETE, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.8, 0.75, 0.7, 0.6))
		return
	var c := _trial.size * 0.5
	var r := 14.0 + 20.0 * _design.circle_radius
	_trial.draw_arc(c, r, 0.0, TAU, 40, Color(0.75, 0.70, 0.60, 0.5), 1.0)
	var aimed := _design.circle_type == Enums.CircleType.AIMED
	if aimed:
		_trial.draw_line(c, c + Vector2(r + 16.0, 0.0), Color(0.9, 0.6, 0.2, 0.6), 1.0)
		_trial.draw_string(font, Vector2(4, 12), "조준진 — 축=에임(→)", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 9, Color(0.9, 0.6, 0.2, 0.8))
	else:
		_trial.draw_string(font, Vector2(4, 12), "고정진 — 절대각", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 9, Color(0.8, 0.75, 0.7, 0.8))
	var col: Color = DrawingCanvas.RUNE_COLORS.get(int(_design.rune_type), Color.WHITE)
	col = col.lightened(0.45)
	for a: ArrowData in _design.arrows:
		var dirv := Vector2(cos(a.direction), sin(a.direction))
		# origin은 진 반지름=1.0 정규화 (TECH_SPEC §4) → 표시 원 반지름(r px) 곱으로 환산
		var start := c + a.origin * r
		var end := start + dirv * (10.0 + 30.0 * a.magnitude)
		_trial.draw_line(start, end, col, 1.5)
		_trial.draw_line(end, end - dirv.rotated(0.5) * 5.0, col, 1.5)
		_trial.draw_line(end, end - dirv.rotated(-0.5) * 5.0, col, 1.5)
