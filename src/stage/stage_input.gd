extends Node
## Keys and mouse -> **commands**. The shell only, and it **never touches the grid directly.**
##  The moment `_mat[i] = STONE` happens here, that spot gets rewritten wholesale when multiplayer is added.
##
## **Debug keys do not go through the input map** (raw keycode). This file won't survive into the real game,
##  so there is no reason to add actions to `project.godot`, and adding them **would require an editor restart.**
##  Conversely, movement and jump do survive into the real game, so they are **input map actions**
##  (`move_left`, `move_right`, `jump`).

## Left click. Passes **world coordinates** — pass viewport coordinates as-is and aim drifts while shaking.
signal fire_requested(world_px: Vector2)
signal reset_requested
## **F — pours water at the mouse position. A shell-only debug key.**
##  The way water comes into being inside the game is **stage 5's water rune**, and until then this key is
##  **the only way to see water on screen.** Once the rune stands up this key may stay or go — the stage
##  won't survive into the real game.
## **Passes world coordinates** — the same reason as left click (it drifts while shaking).
signal water_requested(world_px: Vector2)
## **T and G — lay down a forest and set it alight. Shell only.**
##  Together with F the three are one set — **wood, water and fire must gather on one screen** for
##  "shallow water cannot put out fire" to be visible.
##  Before that the map held only 91 cells of wood, so that rule **could not appear on screen in principle**
##  (`stage.gd`'s T box).
signal wood_requested(world_px: Vector2)
signal ignite_requested(world_px: Vector2)
## **K — toggles rain on the mouse row. A shell-only debug key.**
##  Unlike F (a single-point pour) it pours **a little at a time across N ticks** — the state lives in
##  `src/sim/water_source.gd` (not `stage.gd`'s share).
## **It is a toggle** — press again and it stops. Otherwise the only way to turn it off is resetting the whole stage with R.
signal rain_requested(world_px: Vector2)
## **M/N — stands a monster at the mouse position. Shell-only debug keys** (`monsters-minimum`).
##  Placement is the map doc's share (that doc's "Boundary"), so the stage does not lay monsters down
##  automatically — these keys are "the path by which the thing to be seen reaches the screen".
##  **Exactly the same idiom as F (pouring water).**
## **Passes world coordinates** — the same reason as left click (it drifts while shaking).
## **`kind` is passed as an argument — M (pig) and N (hen) share one signal.** Split the signal in two and
##  `stage.gd`'s handler becomes two as well, and the day a third kind arrives that pair grows again.
signal monster_requested(world_px: Vector2, kind: int)
## **Firing combinations alternately must be doable within seconds** — that is the only way to measure
##  acceptance 1 and 2.
##  Only **the number** is passed here. The number -> glyph list table is in `stage.gd` (assembly is the shell's job).
signal loadout_requested(n: int)
## Open/close the assembly window (Tab). **Whether it opens or closes is not decided here** — the window knows its own state.
signal assembly_toggled

## Physical key -> loadout number. It doesn't go through the input map, so `project.godot` isn't touched
##  and **no editor restart is needed** (this file won't survive into the real game).
## It is **`physical_keycode`**, not `keycode` — every action in `project.godot` is a physical key, so if
##  this file alone used logical keys, **on AZERTY and Dvorak movement would work while only the debug keys die.**
##  With two sets of rules in one repo, that divergence only shows up on someone else's keyboard.
const PRESET_KEYS: Dictionary = {
	KEY_1: 1, KEY_2: 2, KEY_3: 3, KEY_4: 4, KEY_5: 5,
}

## Physical key -> monster kind. Uses `monster_defs.gd`'s ids verbatim — invent a new number here
##  and there are two sets of kind ids.
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
const MONSTER_KEYS: Dictionary = {
	KEY_M: MonsterDefs.KIND_PIG, KEY_N: MonsterDefs.KIND_HEN,
}


## Movement and jump are **polled** — taking them as events would make the shell hold the held-key state
##  separately, and that state stays stuck as pressed when the window loses focus.
func move_axis() -> float:
	return Input.get_axis("move_left", "move_right")


## **Call this only from `_physics_process`.** `is_action_just_pressed` means "was it pressed this frame",
##  and when physics frames are rarer than render frames, calling it from `_process` sees the same press twice.
func jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump")


## **The value variable jump reads — "is it held right now"** (a different question from `jump_pressed` above).
##  **Being polled, it carries none of that function's `_physics_process` constraint.** `just_pressed` means
##   "this frame" and so depends on the frame kind, while this reads the state directly — so missing a release
##   is impossible in principle, and it pairs with `character.step` keeping the cut as a **clamp**.
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
		# **The assembly window survives into the real game, so it is an input map action** — the opposite
		#  of the debug keys above (raw keycode). It sits in the same slot as movement and jump, which is
		#  why `project.godot` has `toggle_assembly`.
		# **There are two causes for Tab not working**: (1) if a `Control` inside the window takes focus,
		#  `ui_focus_next` eats Tab in the GUI and it **never gets here** (2) the editor wasn't restarted
		#  after editing the input map.
		#  The symptoms are identical, so check (1) (`focus_mode = NONE`) first.
		if k.is_action_pressed("toggle_assembly"):
			assembly_toggled.emit()
			get_viewport().set_input_as_handled()
			return
		if PRESET_KEYS.has(k.physical_keycode):
			loadout_requested.emit(int(PRESET_KEYS[k.physical_keycode]))
			return
		if MONSTER_KEYS.has(k.physical_keycode):
			# The same door as F — a key event carries no mouse coordinates, so the viewport's "right now" mouse is used.
			monster_requested.emit(_to_world(get_viewport().get_mouse_position()),
				int(MONSTER_KEYS[k.physical_keycode]))
			return
		match k.physical_keycode:
			KEY_R:
				reset_requested.emit()
			KEY_F:
				# **A key event carries no mouse coordinates.** So the "right now" mouse is read from the
				#  viewport and converted by the same `_to_world` — the two paths only stay together by
				#  **going through the same door** as left click. Convert separately just here and, while
				#  shaking, only the water lands on the wrong cell.
				water_requested.emit(_to_world(get_viewport().get_mouse_position()))
			# Goes through **the same door** as F — convert the three differently and, while the camera
			#  shakes, only wood and fire land on the wrong cells (the `_to_world` box above).
			KEY_T:
				wood_requested.emit(_to_world(get_viewport().get_mouse_position()))
			KEY_G:
				ignite_requested.emit(_to_world(get_viewport().get_mouse_position()))
			KEY_K:
				rain_requested.emit(_to_world(get_viewport().get_mouse_position()))


## **Viewport coordinates != world coordinates** — as long as a `Camera2D` for shake is attached.
##  Without undoing the canvas transform, **a click goes to the wrong cell with no error at all.**
##  When not shaking, the camera sits at the viewport center and the transform is the identity again —
##   so **testing while standing still hides the bug.** It only shows up while shaking.
##
## `CanvasItem.get_global_mouse_position()` can't be used — this node is a `Node`, not a `CanvasItem`.
##  `Viewport.get_canvas_transform()` gives the same value and can be used **on coordinates an event gave too**
##  (`get_global_mouse_position()` is always the "right now" mouse and cannot convert event coordinates).
func _to_world(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pos
