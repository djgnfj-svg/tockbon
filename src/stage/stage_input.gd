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
## **T and G — lay down a forest and set it alight. Shell only.**
##  **They used to be a set of three with F (pour water) and K (rain), and those two are gone** (decided by
##  the user: "물 이제 필요 없고 빼주고"). What went with them is the one screen where wood, water and fire
##  met, which is how "shallow water cannot put out fire" was made visible — **that rule now has no debug
##  path to the screen at all.** **Room ①'s reward pour is gone too** (`burn-out-of-the-bull-room.md` §4) —
##  the game itself pours no water anywhere in stage 1 until room ③'s own pour is built.
signal wood_requested(world_px: Vector2)
signal ignite_requested(world_px: Vector2)
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
## **F3 — shows or hides the debug readout** (`HUD/Stats`). **A shell-only debug key**, like the spawn keys.
##  The readout is **off when the game boots**: it is fifteen lines of black text and it draws straight over
##  the research window's parchment, covering the thing the player opened it to read. Keeping it is right —
##  it is the only view of tick, chunk and monster counts there is — but it is a developer's view, and
##  nothing about it belongs on a first screen.
signal debug_hud_toggled
## **L — takes a pending boss reward. A shell-only debug key** (`stage1-bosses.md` Stage I).
## **Stands in for a decision the user has explicitly left open** ("how the fire rune is received" — the
## GDD's own open TBD) — the real reward (a rune card through the three-pick window) is milestone step 3, not
## this stage's job; this key exists only to prove the gate works, the same way F stood in for the water rune
## before it existed. **No mouse coordinates** — unlike F/T/G/K, there is nothing to aim; it clears whichever
## boss reward(s) are pending, wherever they are.
signal reward_taken_requested

## **F — the town's one interaction** (`docs/design/town.md`, "stand in front of a fixture, press a key").
##  **It was E and the user moved it to F.** F fell free the same day the debug water pour was removed above;
##  E is now bound to nothing, deliberately — leaving both would put two keys in the town's own on-screen
##  prompt, and a prompt naming two keys is how "which one is it" starts.
##  **Which fixture, and whether there is one at all, is not decided here** — the same discipline as Tab and P:
##  this file says a key was pressed and nothing else. `Fixtures.at()` answers "where am I standing".
## **A raw keycode, not an input-map action.** Interaction *will* survive into the real game and by that rule
##  belongs in `project.godot` — but adding an action there needs an editor restart, and the town is a
##  skeleton being stood up right now. **Move it to the input map the day the town stops being a skeleton.**
signal interact_requested

## **`-` / `=` — camera zoom out / in. A shell-only debug key.**
##  The map is 300x48 tiles = 9600x1536 world px while the screen shows 960x540, so **a tenth of the map is
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
	#  (`monster-placement-stage1.md`) — this key stays only as the debug door every
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


## **Is developer mode on. Off at boot, F3 toggles it** — and while it is off **every debug key below is
##  dead**, not merely quiet: the spawns, the presets, the material brushes, the reward key, reset and zoom.
##
## **Why it exists: the submission build hands this game to a judge who has never seen it.** The keys were
##  always reachable, and one stray `M` stands a bull on top of them, one stray `1` swaps their assembly, one
##  stray `R` throws the run away. None of those look like a key that was pressed — **they look like the game
##  broke.**
##
## **It is the same flag the debug readout already rode**, deliberately: two flags would let the keys be live
##  while the readout that explains them is hidden, which is the worst of the four combinations. `stage.gd`
##  **reads this** rather than keeping its own copy — that copy existed and was deleted in the same change.
##
## **F3 itself is never gated** (it would be a switch that cannot be switched back on), and neither is
##  anything a player uses: movement, jump, fire, Tab, P, ESC and F.
var _debug_on := false


func debug_on() -> bool:
	return _debug_on


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
		# **The town's interaction, and it is a player key** — it sits above the gate for that reason.
		#  **It was E until the user moved it to F** (`interact_requested`'s own header).
		if k.physical_keycode == KEY_F:
			interact_requested.emit()
			return
		# **F3 is read before the gate** — gate it and developer mode could never be switched back on.
		if k.physical_keycode == KEY_F3:
			_debug_on = not _debug_on
			debug_hud_toggled.emit()
			return
		# **R is a player key and it sits above the gate — this was got wrong once and it mattered.**
		#  Terrain is destructible, so a player can blow a pit under their own feet, and with no air-jump
		#  unlock bought the jump clears **108px**. A deeper pit is a run that cannot continue, and **R is the
		#  only way out of it.** Gated behind F3 it becomes a trap a judge cannot escape — strictly worse than
		#  the stray-keypress risk the gate exists for.
		if k.physical_keycode == KEY_R:
			reset_requested.emit()
			return
		# **The gate. Everything past this line is a developer key** (`_debug_on`'s own header).
		if not _debug_on:
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
			# **A key event carries no mouse coordinates**, so the "right now" mouse is read from the viewport
			#  and converted by the same `_to_world` left click goes through. Convert separately here and,
			#  while the camera shakes, only wood and fire land on the wrong cells.
			KEY_T:
				wood_requested.emit(_to_world(get_viewport().get_mouse_position()))
			KEY_G:
				ignite_requested.emit(_to_world(get_viewport().get_mouse_position()))
			KEY_L:
				reward_taken_requested.emit()
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
