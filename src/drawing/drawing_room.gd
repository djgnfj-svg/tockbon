extends "res://src/drawing/test_drawing_main.gd"
## 거점 이젤의 드로잉 방 — 시험대 UI 재사용 + 거점 복귀 (Phase 2 통합, 리드).
## 완성 도안은 design_created → GameState.designs로 자동 수집된다.

## OS 커서는 화면 픽셀 기준 — 창 1280×720(뷰포트 2배)에 맞춘 2x 익스포트본. 핫스팟 = 붓끝
const CURSOR_BRUSH_PATH := "res://assets/sprites/ui/cursor_brush_x2.png"
const CURSOR_HOTSPOT := Vector2(2, 28)

func _ready() -> void:
	super._ready()
	var back := Button.new()
	back.text = "거점으로 (ESC)"
	back.add_theme_font_size_override(&"font_size", 10)
	# 하단 힌트 라벨(12, 340)과 겹치면 스승의 경고문이 버튼에 가려진다 — 우상단으로 뺀다
	back.position = Vector2(524, 1)
	back.pressed.connect(_go_base)
	$UI.add_child(back)
	if ResourceLoader.exists(CURSOR_BRUSH_PATH):
		Input.set_custom_mouse_cursor(load(CURSOR_BRUSH_PATH), Input.CURSOR_ARROW, CURSOR_HOTSPOT)

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_go_base()
		get_viewport().set_input_as_handled()

func _go_base() -> void:
	EventBus.scene_change_requested.emit(&"base")
