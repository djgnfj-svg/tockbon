extends CanvasLayer
## 스승이 남긴 필사 수업 — 부팅부터 첫 출격까지의 온보딩 (GDD §2 스승의 메모, §9 데모).
## Main의 UILayer에 자식으로 넣으면 자립 동작한다: EventBus 시그널만으로 현재 씬과
## 단계를 판정하고, 유도 마커는 tutorial_focus로 거점에 위임한다. 타 모듈 노드 접근 없음.
##
## 오두막(이젤 유도) → 드로잉룸(원·불△·화살표·완성) → 오두막(허수아비 시험 발사) → 숲 출격.
## 완료 시 codex_unlocked(tutorial_done) → quest.gd가 이어받는다.

const InkStyle := preload("res://src/ui/ink_style.gd")

const UNLOCK_ID := &"tutorial_done"

# 유도 마커 대상 (EventBus.tutorial_focus) — 거점 시설 id. &"" = 해제
const FOCUS_NONE := &""
const FOCUS_EASEL := &"easel"
const FOCUS_DUMMY := &"dummy"
const FOCUS_DOOR := &"door"

# ── 단계 = _got 플래그 인덱스. 시그널이 순서를 어겨 와도(마지막 획이 화살표면
# design_created가 recognition_result보다 먼저 온다 — drawing_canvas._reclassify_all)
# 플래그 누적 + _advance 루프로 흡수한다.
const STEP_EASEL := 0    # 오두막 — 이젤로              ← scene_changed(&"drawing")
const STEP_CIRCLE := 1   # 드로잉룸 — 원(경계)          ← recognition_result(CIRCLE)
const STEP_RUNE := 2     # 드로잉룸 — 불△(글자)         ← recognition_result(RUNE)
const STEP_ARROW := 3    # 드로잉룸 — 화살표(방향)      ← recognition_result(ARROW)
const STEP_RETURN := 4   # 도안 완성 — 마당으로         ← scene_changed(&"base")
const STEP_TRIAL := 5    # 오두막 — 허수아비 시험 발사  ← training_hit
const STEP_SORTIE := 6   # 오두막 — 숲으로 출격         ← scene_changed(&"field")
const STEP_COUNT := 7

const STEPS := [
	{
		"title": "스승의 메모 — 아침",
		"body": "스승이 사라졌다.\n남은 건 갈아 둔 먹 한 벌.\n「이젤 앞에 앉아라.\n첫 장은 네 손으로.」",
	},
	{
		"title": "스승의 메모 — 첫째 장",
		"body": "「먼저 원을 그려라.\n경계가 서야 글자가 깃들 자리가 생긴다.\n크기는 네 마음만큼이면 된다.」",
	},
	{
		"title": "스승의 메모 — 둘째 장",
		"body": "「원 안에 불의 글자 △를 필사하라.\n한 획이면 충분하다.\n서두르지 마라.」",
	},
	{
		"title": "스승의 메모 — 셋째 장",
		"body": "「글자는 갈 곳을 묻는다.\n화살표를 그어 힘의 방향을 정하라.\n그은 대로 불이 나아간다.」",
	},
	{
		"title": "스승의 메모 — 넷째 장",
		"body": "「네 첫 도안이다. 잘 그렸다.\n먹이 마르기 전에 시험해 보아라.\n마당의 허수아비다.」\n(ESC — 오두막으로)",
	},
	{
		"title": "스승의 메모 — 다섯째 장",
		"body": "「허수아비를 보아라.\n마우스가 곧 방향이다.\n[1]을 눌러 불을 놓아라.」",
	},
	{
		"title": "스승의 메모 — 여섯째 장",
		"body": "「불은 마나를 먹고,\n도안은 쓸수록 닳는다.\n이제 숲으로. 문은 서쪽이다.」",
	},
]

const FINALE := {
	"title": "스승의 메모 — 마지막 장",
	"body": "「숲의 글자를 모아라.\n살아 돌아와야 비로소 지식이 된다.\n나는 조금 앞서 걸을 뿐이다.」",
}

## 수업 도중 이젤을 떠났을 때 (거점 + 필사 단계)
const NOTE_BACK_TO_EASEL := {
	"title": "스승의 메모 — 여백",
	"body": "「그리다 만 도안은\n아무것도 아니다.\n이젤로 돌아가거라.」",
}

## 시험 발사 전에 이젤로 되돌아왔을 때 (드로잉룸 + 시험 단계)
const NOTE_BACK_TO_YARD := {
	"title": "스승의 메모 — 여백",
	"body": "「도안은 달아나지 않는다.\n먼저 마당에서 시험해 보아라.」",
}

## 도안 없이 숲에 든 경우 — 막지는 않되 되돌린다 (막다른 길 방지)
const NOTE_EMPTY_HANDED := {
	"title": "스승의 메모 — 여백",
	"body": "「빈손으로 숲에 드는 자는\n글자가 아니라 흙을 밟는다.\n오두막으로 돌아가라.」",
}

# ── 예외 안내 (막다른 길 방지). 캐스팅 실패 사유별 — Enums.CastFailReason
const HINT_NO_MANA := "마나가 말랐다 — 숨을 고르면 저절로 차오른다."
const HINT_BROKEN := "도안이 닳아 못 쓴다 — 작업대에서 수리하라."
const HINT_INVALID := "손에 쥔 도안이 없다 — 이젤에서 다시 그려라."
const HINT_NO_PAPER := "종이가 없다 — 창고에 종이가 없으면 도안을 맺을 수 없다. 수업은 건너뛸 수 있다."
const HINT_SEC := 7.0

# ── 패널 자리 (뷰포트 640×360 고정 — TECH_SPEC §1)
## 드로잉룸: 우하단. 캔버스(좌 12~332)와 우측 상단 인식 피드백 라벨(y≤168)을 피한다
const DRAW_RECT := Rect2(340, 186, 292, 152)
## 거점·필드: 좌하단 세로 쪽지. HUD 슬롯바(x≥155)·가방 라벨·문 이름표(y≤218)·
## 연구소 이름표(x≥160)를 모두 피한다 — 슬롯 1 카드가 보여야 [1] 지시가 성립한다
const SIDE_RECT := Rect2(4, 220, 148, 132)
const DRAW_FONT := 10
const SIDE_FONT := 9

var _started := false
var _finished := false
var _step := 0
var _got: Array[bool] = [false, false, false, false, false, false, false]
## 현재 씬 — scene_changed로만 추적한다 (게임은 항상 거점에서 시작)
var _scene: StringName = &"base"
var _hint_token := 0

var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _hint_label: Label
var _skip_button: Button
var _close_button: Button


func _ready() -> void:
	visible = false
	# 이미 수업을 마친 필경사에게는 아무것도 하지 않는다.
	# (세이브 로드는 Main._ready — 자식인 이쪽이 먼저 돌아 아직 미반영일 수 있다.
	#  그래서 모든 핸들러가 _done()을 다시 확인한다.)
	if GameState.is_unlocked(UNLOCK_ID):
		return
	_build_ui()
	EventBus.scene_changed.connect(_on_scene_changed)
	EventBus.recognition_result.connect(_on_recognition_result)
	EventBus.design_created.connect(_on_design_created)
	EventBus.training_hit.connect(_on_training_hit)
	EventBus.cast_failed.connect(_on_cast_failed)


# ─────────────────────────── 진행 판정 (시그널 전용) ───────────────────────────

func _on_scene_changed(scene_id: StringName) -> void:
	if _done():
		visible = false
		return
	_scene = scene_id
	_started = true
	# 씬 도착으로 끝나는 단계는 "지금 그 단계일 때만" 인정한다 —
	# 부팅 직후의 base 통지가 4단계(마당 복귀)를 앞질러 켜지 않게.
	if scene_id == &"drawing":
		if _step == STEP_EASEL:
			_got[STEP_EASEL] = true
	elif scene_id == &"base":
		if _step == STEP_RETURN:
			_got[STEP_RETURN] = true
	elif scene_id == &"field" and _step >= STEP_RETURN:
		# 도안을 손에 넣고 숲에 들면 수업은 끝난다 — 허수아비를 건너뛰어도 붙잡지 않는다
		_got[STEP_RETURN] = true
		_got[STEP_TRIAL] = true
		_got[STEP_SORTIE] = true
	_advance()


func _on_recognition_result(role: int, matched: bool, _score: float) -> void:
	if _done() or not _started or not matched:
		return
	if _step > STEP_ARROW:
		return  # 필사 구간은 끝났다 — 이후 드로잉은 수업과 무관
	if role == Enums.StrokeRole.CIRCLE:
		_got[STEP_CIRCLE] = true
	elif role == Enums.StrokeRole.RUNE:
		_got[STEP_RUNE] = true   # 룬 종류는 묻지 않는다 (충격>을 그려도 막지 않는다)
	elif role == Enums.StrokeRole.ARROW:
		_got[STEP_ARROW] = true
	else:
		return
	_advance()


func _on_design_created(_design: SpellDesign) -> void:
	if _done() or not _started or _step > STEP_ARROW:
		return
	# 도안이 존재한다 = 진·룬·화살표가 모두 있었다는 뜻.
	# 완성 획의 recognition_result보다 먼저 도착하므로 세 플래그를 함께 세운다.
	_got[STEP_CIRCLE] = true
	_got[STEP_RUNE] = true
	_got[STEP_ARROW] = true
	_advance()


func _on_training_hit(_rune_type: int, _damage: float) -> void:
	if _done() or not _started:
		return
	_got[STEP_TRIAL] = true
	_advance()


func _on_cast_failed(_design: SpellDesign, reason: int) -> void:
	if _done() or not _started:
		return
	if reason == Enums.CastFailReason.NO_MANA:
		_flash(HINT_NO_MANA)
	elif reason == Enums.CastFailReason.BROKEN:
		_flash(HINT_BROKEN)
	else:
		_flash(HINT_INVALID)


func _done() -> bool:
	return _finished or GameState.is_unlocked(UNLOCK_ID)


func _advance() -> void:
	while _step < STEP_COUNT and _got[_step]:
		_step += 1
	if _step >= STEP_COUNT:
		_finish()
		return
	_refresh()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	EventBus.tutorial_focus.emit(FOCUS_NONE)
	EventBus.codex_unlocked.emit(UNLOCK_ID)
	_place_panel()
	_show_note(FINALE)
	_hint_label.visible = false
	_skip_button.visible = false
	_close_button.visible = true
	visible = true


func _on_skip_pressed() -> void:
	if _finished:
		return
	_finished = true
	EventBus.tutorial_focus.emit(FOCUS_NONE)
	EventBus.codex_unlocked.emit(UNLOCK_ID)
	visible = false


func _on_close_pressed() -> void:
	visible = false


# ─────────────────────────── 표시 ───────────────────────────

func _refresh() -> void:
	_place_panel()
	_show_note(_current_note())
	_hint_label.visible = false
	_skip_button.visible = true
	_close_button.visible = false
	visible = true
	EventBus.tutorial_focus.emit(_focus_target())
	# 종이가 없으면 도안이 맺히지 않는다 (drawing_canvas가 완성을 차단) — 미리 알린다
	if _scene == &"drawing" and _step <= STEP_ARROW and not _has_paper():
		_flash(HINT_NO_PAPER)


## 현재 씬과 단계가 어긋났을 때(이젤을 떠남·빈손 출격) 되돌리는 쪽지를 대신 띄운다
func _current_note() -> Dictionary:
	if _scene == &"field":
		return NOTE_EMPTY_HANDED
	if _scene == &"base" and _step >= STEP_CIRCLE and _step <= STEP_ARROW:
		return NOTE_BACK_TO_EASEL
	if _scene == &"drawing" and _step == STEP_TRIAL:
		return NOTE_BACK_TO_YARD
	return STEPS[_step]


## 유도 마커는 거점에서만 — 드로잉룸·필드에서는 해제한다 (요건 8)
func _focus_target() -> StringName:
	if _scene != &"base":
		return FOCUS_NONE
	if _step == STEP_TRIAL:
		return FOCUS_DUMMY
	if _step == STEP_SORTIE:
		return FOCUS_DOOR
	if _step <= STEP_RETURN:
		return FOCUS_EASEL  # 0단계 + 수업 도중 이젤을 떠난 경우
	return FOCUS_NONE


func _show_note(note: Dictionary) -> void:
	_title_label.text = String(note["title"])
	_body_label.text = String(note["body"])


func _place_panel() -> void:
	var in_drawing := _scene == &"drawing"
	var rect: Rect2 = DRAW_RECT if in_drawing else SIDE_RECT
	var font_size: int = DRAW_FONT if in_drawing else SIDE_FONT
	_panel.position = rect.position
	_panel.size = rect.size
	_body_label.add_theme_font_size_override(&"font_size", font_size)
	_hint_label.add_theme_font_size_override(&"font_size", font_size - 1)


## 예외 안내 — 잠시 띄웠다 지운다 (막다른 길 방지). 겹쳐 호출돼도 마지막 것만 남는다
func _flash(text: String) -> void:
	_hint_label.text = text
	_hint_label.visible = true
	_hint_token += 1
	var token := _hint_token
	var timer := get_tree().create_timer(HINT_SEC)
	timer.timeout.connect(func() -> void:
		if token == _hint_token and is_instance_valid(_hint_label):
			_hint_label.visible = false)


## 보유 종이 유무 — Db·GameState는 core라 조회 가능 (타 모듈 노드 접근 아님)
func _has_paper() -> bool:
	for item_id: StringName in Db.items:
		var def: ItemDef = Db.items[item_id]
		if def != null and def.kind == Enums.ItemKind.PAPER and GameState.get_count(item_id) > 0:
			return true
	return false


# ─────────────────────────── UI 빌드 (전부 코드 생성) ───────────────────────────

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ui_root의 Theme은 형제 CanvasLayer인 이쪽까지 상속되지 않는다 — 같은 먹·한지 테마를 직접 적용
	root.theme = InkStyle.build_theme()
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "NotePanel"
	# 거점 조준·드로잉 입력을 삼키지 않게 (버튼은 자식이라 그대로 입력을 받는다)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override(&"panel", InkStyle.make_panel(
			Color(InkStyle.PAPER.r, InkStyle.PAPER.g, InkStyle.PAPER.b, 0.94),
			InkStyle.INK, 1, 3, 7, 5))
	root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override(&"separation", 3)
	_panel.add_child(vbox)

	_title_label = InkStyle.make_label("", 9, InkStyle.SEAL)
	_title_label.name = "NoteTitle"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	_body_label = InkStyle.make_label("", SIDE_FONT, InkStyle.INK)
	_body_label.name = "NoteBody"
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_body_label)

	_hint_label = InkStyle.make_label("", SIDE_FONT - 1, InkStyle.SEAL)
	_hint_label.name = "NoteHint"
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.visible = false
	vbox.add_child(_hint_label)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(row)

	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.text = "수업 건너뛰기"
	_skip_button.add_theme_font_size_override(&"font_size", 8)
	_skip_button.pressed.connect(_on_skip_pressed)
	row.add_child(_skip_button)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "메모를 접어 둔다"
	_close_button.add_theme_font_size_override(&"font_size", 8)
	_close_button.visible = false
	_close_button.pressed.connect(_on_close_pressed)
	row.add_child(_close_button)
