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

func _ready() -> void:
	theme = InkStyle.build_theme()
	EventBus.day_started.connect(_on_day_started)
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

func close_panel(panel: Control) -> void:
	_stack.erase(panel)
	panel.visible = false

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

# ── 하루 흐름: 게시판 → 장착 선택

func _on_day_started(_day: int) -> void:
	if bulletin in _stack:
		bulletin.call("refresh")
	else:
		open_panel(bulletin)

func _on_bulletin_closed() -> void:
	close_panel(bulletin)
	open_panel(loadout)
