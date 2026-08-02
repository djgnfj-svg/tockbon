extends Node
## 마우스·키 → **커맨드**. 🔴 프로토타입 전용이고, **격자를 직접 안 만진다**(설계 §8 ②).
##  여기서 `_mat[i] = WATER`를 하는 순간 멀티를 붙일 때 그 자리가 통째로 재작성이다.

const CellGrid := preload("res://src/world/cells/cell_grid.gd")
const CellRenderer := preload("res://src/world/cells/cell_renderer.gd")
const Mat := preload("res://src/world/cells/cell_materials.gd")

signal command_requested(cmd: Dictionary)
signal reset_requested
signal divider_nudged(delta: int)
signal hud_toggled

const BRUSH_MIN := 0
const BRUSH_MAX := 12

var selected_mat := Mat.WATER
var brush_radius := 3

var _painting := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_painting = mb.pressed
			if mb.pressed:
				_paint_at(mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var c := _to_cell(mb.position)
			command_requested.emit(CellGrid.cmd_strike(c.x, c.y))
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		match k.keycode:
			KEY_1:
				selected_mat = Mat.WATER
			KEY_2:
				selected_mat = Mat.STONE
			KEY_3:
				selected_mat = Mat.EMPTY
			KEY_BRACKETLEFT:
				brush_radius = maxi(BRUSH_MIN, brush_radius - 1)
			KEY_BRACKETRIGHT:
				brush_radius = mini(BRUSH_MAX, brush_radius + 1)
			KEY_R:
				reset_requested.emit()
			KEY_MINUS:
				divider_nudged.emit(1)  # 분주기 ↑ = 틱 레이트 ↓
			KEY_EQUAL:
				divider_nudged.emit(-1)
			KEY_QUOTELEFT:
				hud_toggled.emit()


func _process(_dt: float) -> void:
	if not _painting:
		return
	# 창 밖에서 버튼을 놓으면 릴리즈 이벤트를 못 받는다 — 실제 상태로 재확인한다.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_painting = false
		return
	_paint_at(get_viewport().get_mouse_position())


func _paint_at(pos: Vector2) -> void:
	var c := _to_cell(pos)
	command_requested.emit(CellGrid.cmd_paint(c.x, c.y, brush_radius, selected_mat))


## ⚠ 카메라가 없어서 캔버스 변환이 항등이다 — 뷰포트 좌표가 곧 월드 좌표다.
##  카메라를 붙이는 순간 여기가 **에러 없이** 틀어진다(클릭이 엉뚱한 셀에 간다).
func _to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CellRenderer.CELL_PX), floori(pos.y / CellRenderer.CELL_PX))
