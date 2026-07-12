extends Control
## 모듈 E 단일 진입점 — 통합 시 Main의 UILayer에 이 씬 하나만 넣는다 (TECH_SPEC §7).
## 화면 스택 관리: day_started → 게시판 → 장착 선택 / 도감 토글(Tab) / ESC로 최상단 닫기.

const InkStyle := preload("res://src/ui/ink_style.gd")

@onready var hud: Control = $Hud
@onready var fx: Control = $FxOverlay
@onready var bulletin: Control = $Screens/Bulletin
@onready var loadout: Control = $Screens/Loadout
@onready var codex: Control = $Screens/Codex

var _stack: Array[Control] = []
## 현재 씬 id — Main의 scene_changed로 추적 (게시판은 거점에서만). 게임은 항상 거점에서 시작
var _scene_id: StringName = &"base"
## 필드·드로잉룸에서 하루가 시작되면 게시판을 보류했다가 거점 복귀 시 연다
var _bulletin_pending: bool = false

func _ready() -> void:
	theme = InkStyle.build_theme()
	EventBus.day_started.connect(_on_day_started)
	EventBus.scene_changed.connect(_on_scene_changed)
	bulletin.connect("closed", _on_bulletin_closed)
	loadout.connect("confirmed", func() -> void: close_panel(loadout))
	codex.connect("closed", func() -> void: close_panel(codex))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_codex"):
		toggle_codex()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and not _stack.is_empty():
		close_top()
		get_viewport().set_input_as_handled()

# ── 스택

func open_panel(panel: Control) -> void:
	if panel in _stack:
		return
	_stack.append(panel)
	panel.call("open")  # 화면 공통 계약: open()에서 visible=true + refresh
	GameState.ui_modal_open = true

func close_panel(panel: Control) -> void:
	_stack.erase(panel)
	panel.visible = false
	GameState.ui_modal_open = not _stack.is_empty()

func close_top() -> void:
	if _stack.is_empty():
		return
	close_panel(_stack.back())

func toggle_codex() -> void:
	if codex in _stack:
		close_panel(codex)
	else:
		open_panel(codex)

func is_open(panel: Control) -> bool:
	return panel in _stack

# ── 하루 흐름: 게시판 → 장착 선택 (거점에서만 — 필드 자정엔 보류 후 복귀 시 표시)

func _on_day_started(_day: int) -> void:
	if _scene_id != &"base":
		_bulletin_pending = true
		return
	if bulletin in _stack:
		bulletin.call("refresh")
	else:
		open_panel(bulletin)

func _on_scene_changed(scene_id: StringName) -> void:
	_scene_id = scene_id
	if _bulletin_pending and scene_id == &"base":
		_bulletin_pending = false
		open_panel(bulletin)

func _on_bulletin_closed() -> void:
	close_panel(bulletin)
	open_panel(loadout)
