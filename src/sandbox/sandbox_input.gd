extends Node
## 마우스·키 → **커맨드**. 🔴 프로토타입 전용이고, **격자를 직접 안 만진다**(설계 §8 ②).
##  여기서 `_mat[i] = WATER`를 하는 순간 멀티를 붙일 때 그 자리가 통째로 재작성이다.
##
## 🔴🔴 **좌클릭이 칠하기에서 발사로 옮겨갔다.** 발사가 주역이라 그게 맞고, 그래서
##  `mouse_filter` 확인도 「칠해지나」가 아니라 **「발사되나」**로 옮겨간다.
##  ⚠ 화면을 덮는 `Control`의 기본 `mouse_filter`(STOP)가 좌클릭을 통째로 먹으면
##   **에러 없이 발사가 죽고 전 스위트는 그린이다.** 헤드리스가 절대 못 잡는다.

const CellGrid := preload("res://src/world/cells/cell_grid.gd")
const CellRenderer := preload("res://src/world/cells/cell_renderer.gd")
const Mat := preload("res://src/world/cells/cell_materials.gd")
const SpellSim := preload("res://src/world/spell/spell_sim.gd")
const Tuning := preload("res://src/world/spell/spell_tuning.gd")

signal command_requested(cmd: Dictionary)
signal reset_requested
signal divider_nudged(delta: int)
signal hud_toggled

const BRUSH_MIN := 0
const BRUSH_MAX := 12

## 발사 원점. 🔴 **캐릭터가 없어서 「총구」가 없다** — 중클릭으로 옮기는 고정점이다.
##  ⚠ v1이 죽은 항목 중 하나가 정확히 「총구가 위력을 안 따라간다」였는데,
##   이 프로토타입에는 총구가 없어서 **그 항목만은 못 잰다.** 캐릭터가 생길 때 다시 봐라.
const ORIGIN_DEFAULT := Vector2i(40, 108)

var selected_mat := Mat.WATER
var brush_radius := 3
var power_tier := 0
var element := Tuning.ELEM_WATER
var fire_origin := ORIGIN_DEFAULT

var _painting := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_fire_at(mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_painting = mb.pressed
			if mb.pressed:
				_paint_at(mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and mb.pressed:
			fire_origin = _to_cell(mb.position)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		match k.keycode:
			KEY_1:
				power_tier = 0
			KEY_2:
				power_tier = 1
			KEY_3:
				power_tier = 2
			KEY_Q:
				element = Tuning.ELEM_WATER
			KEY_E:
				element = Tuning.ELEM_BOLT
			KEY_4:
				selected_mat = Mat.WATER
			KEY_5:
				selected_mat = Mat.STONE
			KEY_6:
				selected_mat = Mat.EMPTY
			KEY_L:
				var c := _to_cell(get_viewport().get_mouse_position())
				command_requested.emit(CellGrid.cmd_strike(c.x, c.y))
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
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_painting = false
		return
	_paint_at(get_viewport().get_mouse_position())


## 🔴🔴 **float이 시뮬로 들어가는 유일한 문이고, 여기서 딱 한 번 닫힌다.**
##  마우스는 float이지만 커맨드가 되는 순간 **셀 단위 정수 차이**로 양자화된다. 그 뒤로는
##  비행도 폭발도 전부 정수라 모든 클라가 같은 셀에서 터진다(`spell_sim.gd` 머리말).
##  ⚠ 여기서 방향을 정규화하지 마라 — `atan2`·`normalized()`가 들어오는 순간 계약이 깨진다.
##   정규화는 `SpellSim.fire()`가 **정수 제곱근**으로 한다.
func _fire_at(pos: Vector2) -> void:
	var c := _to_cell(pos)
	command_requested.emit(SpellSim.cmd_fire(
		fire_origin.x, fire_origin.y, c.x - fire_origin.x, c.y - fire_origin.y,
		power_tier, element))


func _paint_at(pos: Vector2) -> void:
	var c := _to_cell(pos)
	command_requested.emit(CellGrid.cmd_paint(c.x, c.y, brush_radius, selected_mat))


## ⚠ 카메라가 없어서 캔버스 변환이 항등이다 — 뷰포트 좌표가 곧 월드 좌표다.
##  카메라를 붙이는 순간 여기가 **에러 없이** 틀어진다(클릭이 엉뚱한 셀에 간다).
## 🔴 **B2가 화면 흔들림용 `Camera2D`를 붙인다 = 이 함수가 그때 틀어진다.**
##  답은 `get_global_mouse_position()`(캔버스 변환이 반영된다) 기반으로 바꾸는 것이다.
func _to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CellRenderer.CELL_PX), floori(pos.y / CellRenderer.CELL_PX))
