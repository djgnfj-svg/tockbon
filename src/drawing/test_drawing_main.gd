extends Node2D
## 모듈 A 인터랙티브 시험대 (tests/test_drawing.tscn 루트, F6 실행).
## 좌: 드로잉 캔버스 / 우: 인식 결과·정확도·잉크·마나 라벨, 자동보정·스탬프·시험 발사 시각화.
## UI는 전부 코드 생성 — .tscn 수동 편집 최소화(병렬 작업 충돌 방지).

const DrawingCanvas := preload("res://src/drawing/drawing_canvas.gd")
const DesignBuilder := preload("res://src/drawing/design_builder.gd")
const StampLibrary := preload("res://src/drawing/stamp_library.gd")

const PAPER_COLOR := Color(0.93, 0.89, 0.80)
const BG_COLOR := Color(0.16, 0.13, 0.11)
const TEXT_COLOR := Color(0.90, 0.86, 0.78)
const HINT_COLOR := Color(0.7, 0.66, 0.58)
const WARN_COLOR := Color(0.92, 0.45, 0.35)

const ROLE_NAMES := {
	Enums.StrokeRole.CIRCLE: "진(원)",
	Enums.StrokeRole.TAIL: "조준 꼬리",
	Enums.StrokeRole.RUNE: "룬",
	Enums.StrokeRole.ARROW: "화살표",
	Enums.StrokeRole.DECOR: "미인식(장식)",
}

var _canvas: Control
var _lib := StampLibrary.new()
var _design: SpellDesign = null

var _status_label: Label
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
	_status_label = _make_label(ui, Vector2(x, 22), Vector2(w, 46), "", 10)
	_recog_label = _make_label(ui, Vector2(x, 70), Vector2(w, 26), "최근 인식: —", 10)
	_design_label = _make_label(ui, Vector2(x, 98), Vector2(w, 44), "", 10)

	var btn_row := HBoxContainer.new()
	btn_row.position = Vector2(x, 146)
	btn_row.size = Vector2(w, 22)
	ui.add_child(btn_row)
	_add_button(btn_row, "자동보정", _on_autocorrect)
	_add_button(btn_row, "스탬프 저장", _on_save_stamp)
	_add_button(btn_row, "지우기", func() -> void: _canvas.clear_all())

	_make_label(ui, Vector2(x, 172), Vector2(w, 12), "필체 라이브러리 (클릭 → 캔버스 클릭으로 배치)", 9)
	_stamp_list = ItemList.new()
	_stamp_list.position = Vector2(x, 186)
	_stamp_list.size = Vector2(w, 54)
	_stamp_list.add_theme_font_size_override(&"font_size", 9)
	_stamp_list.item_selected.connect(_on_stamp_selected)
	ui.add_child(_stamp_list)

	_make_label(ui, Vector2(x, 244), Vector2(w, 12), "시험 발사 (방향·크기 미리보기 — 실발사는 모듈 B)", 9)
	_trial = Control.new()
	_trial.position = Vector2(x, 258)
	_trial.size = Vector2(w, 94)
	_trial.draw.connect(_draw_trial)
	ui.add_child(_trial)

	_hint_label = _make_label(ui, Vector2(12, 340), Vector2(620, 14), "", 9)
	_set_default_hint()
	_refresh_status(_canvas.get_summary())
	_refresh_design_label()

	# ── 종이 선택 + 잉크 게이지 (GDD §5 종이 등급 — 보유 종이만, 기본 = 최저 등급 자동)
	_canvas.ink_state_changed.connect(_on_ink_state_changed)
	_canvas.stroke_rejected.connect(_on_stroke_rejected)
	_canvas.completion_blocked.connect(_on_completion_blocked)
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
	if k != null and k.pressed and not k.echo and k.keycode == KEY_Z and k.ctrl_pressed:
		_canvas.undo_last()


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


func _on_design_state_changed(design: SpellDesign, summary: Dictionary) -> void:
	_design = design
	_refresh_status(summary)
	_refresh_design_label()
	_trial.queue_redraw()


func _refresh_status(summary: Dictionary) -> void:
	var circle_text := "—"
	if summary.get("has_circle", false):
		circle_text = "조준진" if summary.get("has_tail", false) else "고정진"
	var rune_text := "—"
	if summary.get("has_rune", false):
		rune_text = "%s (원시 %.2f)" % [
			DesignBuilder.rune_name(int(summary.rune_type)),
			float(summary.rune_accuracy_raw),
		]
	_status_label.text = "진: %s\n룬: %s\n화살표 %d개 · 장식 %d획 · 총 %d획" % [
		circle_text, rune_text,
		int(summary.get("arrow_count", 0)),
		int(summary.get("extra_count", 0)),
		int(summary.get("stroke_count", 0)),
	]


func _refresh_design_label() -> void:
	if _design == null:
		_design_label.text = "도안 미완성 — 진 1 + 룬 1 + 화살표 1+ 필요"
		return
	_design_label.text = "완성: %s\n정확도 %d%% · 잉크 %d · 마나 %.0f · 내구 %d/%d" % [
		_design.display_name,
		roundi(_design.rune_accuracy * 100.0),
		int(_design.ink_cost.get(&"ink_basic", 0)),
		_design.mana_cost,
		_design.durability, _design.durability_max,
	]


func _on_autocorrect() -> void:
	if _canvas.autocorrect_rune():
		_set_hint("자동보정: 룬을 템플릿 형태로 스냅 (정확도는 유지)")
	else:
		_set_hint("보정할 룬이 없습니다")


func _on_save_stamp() -> void:
	var stamp: Dictionary = _canvas.save_rune_stamp()
	if stamp.is_empty():
		_set_hint("저장할 룬이 없습니다 — 먼저 룬을 그려 인식시키세요")
		return
	var idx := _lib.add(stamp)
	_stamp_list.add_item(_lib.label(idx))
	_set_hint("스탬프 저장됨 — 목록에서 클릭 후 캔버스를 클릭해 배치")


func _on_stamp_selected(index: int) -> void:
	_canvas.begin_stamp_placement(_lib.get_stamp(index))
	_set_hint("캔버스를 클릭해 스탬프 배치 (우클릭 = 취소) · 정확도는 저장 시점 값 보존")


func _on_stamp_placed() -> void:
	_stamp_list.deselect_all()
	_set_default_hint()


# ─────────────────────────── 종이 선택·잉크 게이지 (GDD §5) ───────────────────────────

## 보유 종이 목록 갱신 — 현재 선택 종이는 소진돼도 목록에 남긴다 (편집 흐름 보존).
## 미선택 상태에서 보유 종이가 생기면 최저 등급을 자동 선택한다 (비차단).
func _refresh_paper_options() -> void:
	var defs: Array[ItemDef] = []
	for id: StringName in Db.items:
		var def: ItemDef = Db.items[id]
		if def != null and def.kind == Enums.ItemKind.PAPER \
				and (GameState.get_count(id) > 0 or id == _paper_id):
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
	if _paper_id == StringName():
		_paper_select.select(0)
		_on_paper_selected(0)
	else:
		_paper_select.select(maxi(_paper_ids.find(_paper_id), 0))


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


func _on_stroke_rejected(_reason: StringName) -> void:
	_set_warn("잉크 상한 초과 — 획이 무효 처리되었습니다. 획을 지우면(우클릭) 잉크가 회복됩니다")


func _on_completion_blocked(_reason: StringName) -> void:
	_design_label.text = "종이가 없어 도안을 완성할 수 없습니다 — 종이를 확보하세요"
	_set_warn("보유 종이 0장 — 그리기는 가능하지만 도안 완성은 차단됩니다")


func _set_hint(text: String) -> void:
	_hint_label.text = text
	_hint_label.add_theme_color_override(&"font_color", HINT_COLOR)


func _set_warn(text: String) -> void:
	_hint_label.text = text
	_hint_label.add_theme_color_override(&"font_color", WARN_COLOR)


func _set_default_hint() -> void:
	_set_hint("좌클릭 드래그 = 획 · 우클릭/Ctrl+Z = 취소 · 원 → (꼬리) → 룬 → 화살표 순서 추천")


# ─────────────────────────── 시험 발사 시각화 ───────────────────────────

func _draw_trial() -> void:
	_trial.draw_rect(Rect2(Vector2.ZERO, _trial.size), Color(0.08, 0.07, 0.06, 0.65))
	var font := ThemeDB.fallback_font
	if _design == null:
		_trial.draw_string(font, Vector2(8, 18), "도안 미완성", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
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
