extends CanvasLayer
## 스승이 남긴 필사 수업 — 온보딩 튜토리얼 (GDD §9 데모 범위, §2 스승의 메모).
## Main의 UILayer에 자식으로 넣으면 자립 동작한다:
## tutorial_done 미해금 상태에서 드로잉룸 진입(EventBus.scene_change_requested)을
## 감지해 수업을 시작하고, recognition_result / design_created 시그널만으로
## 단계를 판정한다. 타 모듈 노드에는 접근하지 않는다 (TECH_SPEC §10).

const UNLOCK_ID := &"tutorial_done"

# 뷰포트 640×360 고정 (TECH_SPEC §1). 드로잉 캔버스(좌측 12~332px)와
# 우측 상단 인식 피드백 라벨(y≤170)을 가리지 않는 우측 하단 자리.
const PANEL_RECT := Rect2(340, 186, 292, 150)

# 한지·먹 팔레트 — src/ui/ink_style.gd와 동일 톤 (모듈 경계상 상수만 복제)
const PAPER := Color(0.941, 0.902, 0.824)
const PAPER_DARK := Color(0.886, 0.831, 0.718)
const INK := Color(0.165, 0.149, 0.133)
const INK_FAINT := Color(0.522, 0.478, 0.408)
const SEAL := Color(0.710, 0.278, 0.180)

# 단계 인덱스 = _got 플래그 인덱스. 시그널이 어떤 순서로 와도(예: 마지막 획이
# 화살표면 design_created가 recognition_result보다 먼저 온다 — drawing_canvas
# _end_stroke의 실제 순서) 플래그 누적 + _advance 루프로 흡수한다.
const STEP_CIRCLE := 0
const STEP_RUNE := 1
const STEP_ARROW := 2
const STEP_DESIGN := 3
const STEP_COUNT := 4

const STEPS := [
	{
		"title": "스승의 메모 — 첫 장",
		"body": "먹은 갈아 두었다.\n먼저 원을 그려 경계를 세워라.\n경계가 서야 글자가 깃들 자리가 생긴다.\n크기는 네 마음만큼이면 된다.",
	},
	{
		"title": "스승의 메모 — 둘째 장",
		"body": "좋은 원이다.\n이제 원 안에 불의 글자 △를 필사하라.\n한 획이면 충분하다. 서두르지 마라.",
	},
	{
		"title": "스승의 메모 — 셋째 장",
		"body": "글자는 갈 곳을 묻는다.\n화살표를 그어 힘의 방향을 정하라.\n그은 방향으로 불이 나아갈 것이다.",
	},
	{
		"title": "스승의 메모 — 넷째 장",
		"body": "경계, 글자, 방향 — 모두 갖췄다.\n먹이 마르기 전에 도안을 마무리하여라.\n지운 획이 있다면 다시 그으면 된다.",
	},
]

const FINALE := {
	"title": "스승의 메모 — 마지막 장",
	"body": "네 첫 도안이다. 잘 그렸다.\n먹이 마르면 숲으로 나가 보아라.\n숲의 글자들이 너를 기다린다.\n나는 조금 앞서 걷고 있을 뿐이다.",
}

var _lesson_started := false
var _step := 0
var _got: Array[bool] = [false, false, false, false]

var _title_label: Label
var _body_label: Label
var _close_button: Button
var _skip_button: Button


func _ready() -> void:
	visible = false
	# 이미 수업을 마친 필경사에게는 아무것도 하지 않는다 (요건 1)
	if GameState.is_unlocked(UNLOCK_ID):
		return
	_build_ui()
	EventBus.scene_change_requested.connect(_on_scene_change_requested)
	EventBus.recognition_result.connect(_on_recognition_result)
	EventBus.design_created.connect(_on_design_created)


# ─────────────────────────── 진행 판정 (시그널 전용) ───────────────────────────

func _on_scene_change_requested(scene_id: StringName) -> void:
	if GameState.is_unlocked(UNLOCK_ID):
		return
	if scene_id == &"drawing":
		if not _lesson_started:
			_lesson_started = true
			_show_step()
		visible = true
	else:
		# 수업은 드로잉룸에서만 보인다 — 진행 상태는 보존, 재진입 시 이어서
		visible = false


func _on_recognition_result(role: int, matched: bool, _score: float) -> void:
	if not _active() or not matched:
		return
	match role:
		Enums.StrokeRole.CIRCLE:
			_got[STEP_CIRCLE] = true
		Enums.StrokeRole.RUNE:
			_got[STEP_RUNE] = true
		Enums.StrokeRole.ARROW:
			_got[STEP_ARROW] = true
		_:
			return
	_advance()


func _on_design_created(_design: SpellDesign) -> void:
	if not _active():
		return
	_got[STEP_DESIGN] = true
	_advance()


func _active() -> bool:
	return _lesson_started and not GameState.is_unlocked(UNLOCK_ID)


func _advance() -> void:
	var before := _step
	while _step < STEP_COUNT and _got[_step]:
		_step += 1
	if _step >= STEP_COUNT:
		_complete()
	elif _step != before:
		_show_step()


func _complete() -> void:
	EventBus.codex_unlocked.emit(UNLOCK_ID)
	_title_label.text = FINALE.title
	_body_label.text = FINALE.body
	_skip_button.visible = false
	_close_button.visible = true


func _on_skip_pressed() -> void:
	EventBus.codex_unlocked.emit(UNLOCK_ID)
	visible = false


func _on_close_pressed() -> void:
	visible = false


func _show_step() -> void:
	_title_label.text = STEPS[_step].title
	_body_label.text = STEPS[_step].body


# ─────────────────────────── UI 빌드 (전부 코드 생성) ───────────────────────────

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.name = "NotePanel"
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.add_theme_stylebox_override(&"panel", _make_panel_box())
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 5)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "NoteTitle"
	_title_label.add_theme_font_size_override(&"font_size", 9)
	_title_label.add_theme_color_override(&"font_color", SEAL)
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.name = "NoteBody"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_size_override(&"font_size", 10)
	_body_label.add_theme_color_override(&"font_color", INK)
	vbox.add_child(_body_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "메모를 접어 둔다"
	_close_button.visible = false
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_style_button(_close_button)
	_close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(_close_button)

	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.text = "수업 건너뛰기"
	_skip_button.anchor_left = 1.0
	_skip_button.anchor_right = 1.0
	_skip_button.offset_left = -96.0
	_skip_button.offset_right = -6.0
	_skip_button.offset_top = 4.0
	_skip_button.offset_bottom = 24.0
	_style_button(_skip_button)
	_skip_button.pressed.connect(_on_skip_pressed)
	root.add_child(_skip_button)


func _make_panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _style_button(b: Button) -> void:
	b.add_theme_font_size_override(&"font_size", 9)
	b.add_theme_color_override(&"font_color", INK)
	b.add_theme_color_override(&"font_hover_color", INK)
	b.add_theme_color_override(&"font_pressed_color", PAPER)
	b.add_theme_stylebox_override(&"normal", _make_button_box(PAPER_DARK, INK))
	b.add_theme_stylebox_override(&"hover", _make_button_box(PAPER, INK))
	b.add_theme_stylebox_override(&"pressed", _make_button_box(INK, INK))
	b.add_theme_stylebox_override(&"disabled", _make_button_box(PAPER_DARK, INK_FAINT))


func _make_button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb
