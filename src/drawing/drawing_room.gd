extends "res://src/drawing/test_drawing_main.gd"
## 거점 이젤의 드로잉 방 — 시험대 UI 재사용 + 거점 복귀 (Phase 2 통합, 리드).
## 완성 도안은 design_created → GameState.designs로 자동 수집된다.

func _ready() -> void:
	super._ready()
	var back := Button.new()
	back.text = "거점으로 돌아가기 (ESC)"
	back.add_theme_font_size_override(&"font_size", 10)
	back.position = Vector2(12, 340)
	back.pressed.connect(_go_base)
	$UI.add_child(back)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_go_base()
		get_viewport().set_input_as_handled()

func _go_base() -> void:
	EventBus.scene_change_requested.emit(&"base")
