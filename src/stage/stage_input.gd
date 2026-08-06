extends Node
## 키·마우스 → **커맨드**. 🔴 껍데기 전용이고, **격자를 직접 안 만진다.**
##  여기서 `_mat[i] = STONE`을 하는 순간 멀티를 붙일 때 그 자리가 통째로 재작성이다.
##
## 🔴 **디버그 키는 입력 맵을 안 지난다**(raw keycode). 이 파일은 본편에 안 남으므로
##  `project.godot`에 액션을 늘릴 이유가 없고, 늘리면 **에디터 재시작이 필요해진다.**
##  ⚠ 반대로 이동·점프는 본편에 남으므로 **입력 맵 액션**이다(`move_left`·`move_right`·`jump`).

## 좌클릭. **월드 좌표**를 넘긴다 — 뷰포트 좌표를 그대로 넘기면 흔드는 동안 조준이 어긋난다.
signal fire_requested(world_px: Vector2)
signal reset_requested
## 🔴 **F — 마우스 자리에 물을 붓는다. 껍데기 전용 디버그 키다.**
##  게임 안에서 물이 생기는 길은 **단계 5의 물 룬**이고, 그때까지 이 키가 **물을 화면에서 보는
##  유일한 길**이다. ⚠ 룬이 서면 이 키는 남겨도 되고 지워도 된다 — 무대는 본편에 안 남는다.
## ⚠ **월드 좌표를 넘긴다** — 좌클릭과 같은 이유다(흔들리는 동안 어긋난다).
signal water_requested(world_px: Vector2)
## 🔴🔴 **조합을 번갈아 쏘는 것이 몇 초 안에 돼야 한다** — 그게 판정 1·2를 재는 유일한 방법이다.
##  ⚠ 여기는 **번호만** 넘긴다. 번호 → 문양 목록 표는 `stage.gd`에 있다(조립은 껍데기의 일이다).
signal loadout_requested(n: int)
## 조립창 열기/닫기(Tab). ⚠ **여는지 닫는지를 여기서 안 정한다** — 창이 제 상태를 안다.
signal assembly_toggled

## 🔴 물리 키 → 조합 번호. 입력 맵을 안 지나므로 `project.godot`을 안 고치고,
##  그래서 **에디터 재시작이 필요 없다**(이 파일은 본편에 안 남는다).
## ⚠ `keycode`가 아니라 **`physical_keycode`**다 — `project.godot`의 액션이 전부 물리 키라
##  이 파일만 논리 키를 쓰면 **AZERTY·Dvorak에서 이동은 되는데 디버그 키만 안 먹는다.**
##  한 리포에 규칙이 두 벌이면 그 갈라짐은 남의 자판에서만 드러난다.
const PRESET_KEYS: Dictionary = {
	KEY_1: 1, KEY_2: 2, KEY_3: 3, KEY_4: 4, KEY_5: 5,
}


## 🔴 이동·점프는 **폴링**이다 — 이벤트로 받으면 키를 누르고 있는 동안의 상태를 껍데기가
##  따로 들고 있어야 하고, 창이 포커스를 잃으면 그 상태가 눌린 채로 남는다.
func move_axis() -> float:
	return Input.get_axis("move_left", "move_right")


## ⚠ **`_physics_process`에서만 불러라.** `is_action_just_pressed`는 「이번 프레임에 눌렸나」인데,
##  물리 프레임이 렌더 프레임보다 드물면 `_process`에서 부를 때 같은 누름을 두 번 본다.
func jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump")


## 🔴🔴 **가변 점프가 읽는 값 — 「지금 누르고 있나」다**(위 `jump_pressed` 와 다른 물음).
##  ⚠ **폴링이라 위 함수의 `_physics_process` 제약이 없다.** `just_pressed` 는 「이번 프레임」이라
##   프레임 종류를 타지만 이건 상태를 그대로 읽는다 — 그래서 릴리즈를 놓치는 일이 원리적으로 없고,
##   `character.step` 이 컷을 **클램프**로 두는 것과 짝이다.
func jump_held() -> bool:
	return Input.is_action_pressed("jump")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			fire_requested.emit(_to_world(mb.position))
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		# 🔴 **조립창은 본편에 남으므로 입력 맵 액션이다** — 위 디버그 키(raw keycode)와 반대다.
		#  이동·점프와 같은 칸이고, 그래서 `project.godot`에 `toggle_assembly`가 있다.
		# ⚠ **Tab이 안 먹는 원인이 둘이다**: ① 창 안 `Control`이 포커스를 잡으면 `ui_focus_next`가
		#  GUI에서 Tab을 먹어 여기 **안 온다** ② 입력 맵을 고친 뒤 에디터를 안 재시작했다.
		#  🔴 증상이 똑같으니 ①(`focus_mode = NONE`)부터 확인해라.
		if k.is_action_pressed("toggle_assembly"):
			assembly_toggled.emit()
			get_viewport().set_input_as_handled()
			return
		if PRESET_KEYS.has(k.physical_keycode):
			loadout_requested.emit(int(PRESET_KEYS[k.physical_keycode]))
			return
		match k.physical_keycode:
			KEY_R:
				reset_requested.emit()
			KEY_F:
				# 🔴 **키 이벤트에는 마우스 좌표가 없다.** 그래서 뷰포트에서 「지금」의 마우스를
				#  읽어 같은 `_to_world` 로 변환한다 — 좌클릭과 **같은 문을 지나야** 두 길이
				#  안 갈라진다. ⚠ 여기서만 따로 변환하면 흔들리는 동안 물만 엉뚱한 셀에 떨어진다.
				water_requested.emit(_to_world(get_viewport().get_mouse_position()))


## 🔴🔴 **뷰포트 좌표 ≠ 월드 좌표다** — 흔들림용 `Camera2D`가 붙어 있는 한.
##  캔버스 변환을 되돌리지 않으면 **에러 하나 없이 클릭이 엉뚱한 셀로 간다.**
##  ⚠ 흔들리지 않을 때 카메라가 뷰포트 한가운데라 변환이 다시 항등이 된다 —
##   그래서 **가만히 있을 때 테스트하면 버그가 안 보인다.** 흔드는 동안에만 드러난다.
##
## 🔴 `CanvasItem.get_global_mouse_position()`을 못 쓴다 — 이 노드는 `Node`라 `CanvasItem`이
##  아니다. `Viewport.get_canvas_transform()`이 같은 값을 주고, **이벤트가 준 좌표에도** 쓸 수 있다
##  (`get_global_mouse_position()`은 늘 「지금」의 마우스라 이벤트 좌표를 못 변환한다).
func _to_world(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pos
