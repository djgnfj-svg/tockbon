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
## **M/N/B/C — stands a monster at the mouse position. Shell-only debug keys** (`monsters-minimum`,
##  B/C added by `stage1-bosses.md` stage A).
##  Placement is the map doc's share (that doc's "Boundary"), so the stage does not lay monsters down
##  automatically — these keys are "the path by which the thing to be seen reaches the screen".
##  **Exactly the same idiom as F (pouring water).**
## **Passes world coordinates** — the same reason as left click (it drifts while shaking).
## **`kind` is passed as an argument — M (pig) and N (hen) share one signal.** Split the signal in two and
##  `stage.gd`'s handler becomes two as well, and the day a third kind arrives that pair grows again.
##  **B (bull) and C (rooster) prove the point** — `stage1-bosses.md` stage A, zero new signals.
signal monster_requested(world_px: Vector2, kind: int)
## **Firing combinations alternately must be doable within seconds** — that is the only way to measure
##  acceptance 1 and 2.
##  Only **the number** is passed here. The number -> glyph list table is in `stage.gd` (assembly is the shell's job).
signal loadout_requested(n: int)
## Open/close the assembly window (Tab). **Whether it opens or closes is not decided here** — the window knows its own state.
signal assembly_toggled
## **P — open or decline the three-pick.** An input-map action, not a raw keycode, for the same reason as
##  `toggle_assembly`: this key survives into the real game, so it belongs in `project.godot`, not this file's
##  debug-key dictionaries. **Whether it opens or declines is not decided here** — `Progress` knows its own
##  state, the same discipline as the assembly window.
signal pick_toggled
## **ESC — closes whichever window E/Tab/P opened** (user request: "E 해서 뜬 게 ESC로 꺼져야 함. 모든 UI들은").
##  **`ui_cancel`, one of Godot's own built-in default actions** — bound to Escape without needing an entry
##  in `project.godot` (unlike the debug-key dictionaries below, this key survives into the real game, the
##  same reason `toggle_assembly`/`pick_toggled` are actions and not raw keycodes).
## **Which window closes, and whether closing one loses anything, is not decided here** — the same
##  discipline every other toggle signal above already holds.
signal cancel_requested
## **L — takes a pending boss reward. A shell-only debug key** (`stage1-bosses.md` Stage I).
## **Stands in for a decision the user has explicitly left open** ("how the fire rune is received" — the
## GDD's own open TBD) — the real reward (a rune card through the three-pick window) is milestone step 3, not
## this stage's job; this key exists only to prove the gate works, the same way F stood in for the water rune
## before it existed. **No mouse coordinates** — unlike F/T/G/K, there is nothing to aim; it clears whichever
## boss reward(s) are pending, wherever they are.
signal reward_taken_requested

## **E — the town's one interaction** (`docs/design/town.md`, "stand in front of a fixture, press a key").
##  **Which fixture, and whether there is one at all, is not decided here** — the same discipline as Tab and P:
##  this file says a key was pressed and nothing else. `Fixtures.at()` answers "where am I standing".
## **A raw keycode, not an input-map action.** Interaction *will* survive into the real game and by that rule
##  belongs in `project.godot` — but adding an action there needs an editor restart, and the town is a
##  skeleton being stood up right now. **Move it to the input map the day the town stops being a skeleton.**
signal interact_requested

## **`-` / `=` — camera zoom out / in. A shell-only debug key.**
##  The map is 400x48 tiles = 12800x1536 world px while the screen shows 960x540, so **1/13th of the map is
##  visible at once** and level design cannot be read while playing. This key is the only way to see the whole
##  thing without opening the editor.
## Only the **direction** is passed (-1 out, +1 in). The zoom steps live in `stage.gd` — the shell owns
##  the camera, and holding a copy of the table here would make the two drift.
signal zoom_requested(dir: int)

## Physical key -> loadout number. It doesn't go through the input map, so `project.godot` isn't touched
##  and **no editor restart is needed** (this file won't survive into the real game).
## It is **`physical_keycode`**, not `keycode` — every action in `project.godot` is a physical key, so if
##  this file alone used logical keys, **on AZERTY and Dvorak movement would work while only the debug keys die.**
##  With two sets of rules in one repo, that divergence only shows up on someone else's keyboard.
const PRESET_KEYS: Dictionary = {
	KEY_1: 1, KEY_2: 2, KEY_3: 3, KEY_4: 4, KEY_5: 5, KEY_6: 6,
}

## Physical key -> monster kind. Uses `monster_defs.gd`'s ids verbatim — invent a new number here
##  and there are two sets of kind ids.
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
const MONSTER_KEYS: Dictionary = {
	KEY_M: MonsterDefs.KIND_PIG, KEY_N: MonsterDefs.KIND_HEN,
	# **B/C, not R** — R is already `reset_requested`. `stage1-bosses.md` stage A.
	KEY_B: MonsterDefs.KIND_BULL, KEY_C: MonsterDefs.KIND_ROOSTER,
	# **V, because the obvious letter is movement.** The wolf now has map placement too
	#  (`docs/plans/3.done/monster-placement-stage1.md`) — this key stays only as the debug door every
	#  other kind already has (`monsters-minimum`'s own reason for M/N), not the wolf's sole way on screen.
	KEY_V: MonsterDefs.KIND_WOLF,
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
		# **Same two causes as Tab if this key looks dead**: (1) a focused `Control` eating it via
		#  `ui_focus_next`-style consumption (not a risk yet — Stage C has no `Control` for the pick) and
		#  (2) `project.godot`'s input map was edited but the editor was not restarted. Check (2) first here —
		#  there is no window yet to have stolen focus.
		if k.is_action_pressed("open_pick"):
			pick_toggled.emit()
			get_viewport().set_input_as_handled()
			return
		# **Same "is the action known at all" risk as Tab/P above** — `ui_cancel` is built in, so there is no
		#  project-settings edit to forget here, but a renamed/removed built-in action would fail the same
		#  silent way. Checked directly rather than assumed (`net_...` reads `InputMap.has_action`).
		if k.is_action_pressed("ui_cancel"):
			cancel_requested.emit()
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
			KEY_L:
				reward_taken_requested.emit()
			KEY_E:
				interact_requested.emit()
			# **Both the main row and the numpad** — `-` on the main row is `KEY_MINUS` and the numpad's is a
			#  different keycode entirely. Bind only one and it reads as "the key does nothing".
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_requested.emit(-1)
			KEY_EQUAL, KEY_KP_ADD:
				zoom_requested.emit(1)


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
