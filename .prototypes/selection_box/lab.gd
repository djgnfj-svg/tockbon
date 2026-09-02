# **Five ways of drawing the drag-selection box — the marquee the hand pulls with the left button to
# pick several 검사 — on the real island.**
#
# The question, in the user's words (2026-09-02): 「땅에 깔리는 거랑 그냥 사각형이랑 둘 다 해야할듯?
# 그렇게 프로토타입으로 보는거지 해보면서」 — *"the ground-laid one and the plain rectangle both have to
# be tried; that is what a prototype is for, you see it by trying."*
#
# ⚠⚠ **This lab drives the REAL game**, copied from `.prototypes/pads/lab.gd`: it opens `Game`, presses
# 시작하기, waits until the four starting 검사 are ashore, and then hands every candidate ONE fixed drag
# — the same two screen points for all of them — so the sheet compares the drawing and nothing else.
# A box judged on a stand-in block under a stand-in camera would be judged against the wrong ground.
#
# **Two ways to run it, and the default is the one you WATCH.**
#
#   Godot_v4.7.1-stable_win64.exe --path . --script res://.prototypes/selection_box/lab.gd
#       opens a window and stays. **LEFT/RIGHT cycle the candidates.** The game's own keys still work —
#       Q/E turn a quarter, W/A/S/D pan, R/F tilt, the wheel zooms. ESC quits.
#
#   Godot_v4.7.1-stable_win64.exe --path . --script res://.prototypes/selection_box/lab.gd -- shoot
#       photographs every candidate at yaw 0 and after one Q notch, and quits.
#
# ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
# black with no error anywhere.
#
# **A candidate is a folder `NN-name/` beside this file carrying a `scene.gd`** — the contract is in
# `README.md`: `extends RefCounted`, `const NAME`, `mount(game, fv, drag)`, `unmount()`, `lines()`.
extends SceneTree

const DIR := "res://.prototypes/selection_box"
const OUT := "res://.prototypes/selection_box/out/%s_%s.png"

## **The one drag every candidate is handed, in screen px at the opening camera.** A is where the
## button went down, B is where it is now. ⚠ Pinned from a real run — see `_probe()` — so that the
## rect closes over two of the four starting 검사 at the 성채 door and a strip of open ground beside
## them. **Change these and every candidate moves together**, which is the point of having them here.
const DRAG_A := Vector2(440.0, 345.0)
const DRAG_B := Vector2(660.0, 445.0)

## A press that moves less than this before release is a click, and the box is not touched.
const DRAG_MIN_PX := 6.0

## How many ashore bodies the boot waits for before anything is mounted. The island opens with four.
const ASHORE_WANTED := 4


## **Catches the left button before it reaches the game** (2026-09-02, the user at the lab:
## 「마우스로 드래그하는 거 아냐?」 — *"isn't it supposed to be dragged with the mouse?"*). `_input`
## runs before `_unhandled_input`, and marking the event handled is what keeps `Game._press_the_island`
## from picking or letting go on the same press. ⚠ **In the lab the left button belongs to the box.**
## Motion is recorded and NOT consumed — the game's hover plate and pointer keep reading it.
class DragCatcher extends Node:
	var armed := false
	var down := false
	var released := false
	var pressed_at := Vector2.ZERO
	var pos := Vector2.ZERO

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			pos = (event as InputEventMouseMotion).position
			return
		if not (event is InputEventMouseButton):
			return
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = click.position
		if click.pressed:
			down = true
			pressed_at = click.position
		else:
			down = false
			released = true
		if armed:
			get_viewport().set_input_as_handled()
## Frames the boot will wait for them before giving up and saying so.
const BOOT_FRAMES_MAX := 900

var game: Game = null
var field: FieldView = null
var grid: Grid = null

var _names: Array = []
var _cand = null
var _i := 0
var _wait := 0
var _boot := 0
var _boot_frames := 0
var _shot := 0
var _booted := false
var _shooting := false
var _label: Label = null
var _held := {}
## The drag as every candidate receives it — built once at boot, never rebuilt.
var _drag := {}
## Yaw read on the previous gated step, for the settle wait after a Q or E.
var _yaw_last := INF
var _settled := 0
## The live drag (watch mode only). `_dragging` is true from the press to the release; `_moved` says
## whether this press has passed `DRAG_MIN_PX` yet; once it has, `_drag` IS the live one and ←/→
## re-mount with it. `-- shoot` never touches any of this, so the sheet stays reproducible.
var _catch: DragCatcher = null
var _dragging := false
var _moved := false
var _drag_a := Vector2.ZERO
## `-- drive`: a scripted drag fed through `Input.parse_input_event`, the engine's own input path, so
## the live drag can be proven without a hand on the mouse. Prints every remount, then quits.
var _drive := false
var _drive_frame := 0


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	game = Game.new()
	root.add_child(game)
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	_shooting = args.has("shoot")
	_drive = args.has("drive") and not _shooting
	_catch = DragCatcher.new()
	root.add_child(_catch)


func _process(_delta: float) -> bool:
	if _booted and not _shooting:
		return _watch()
	_wait += 1
	if _wait < 4:
		return false
	_wait = 0
	if not _booted:
		return _boot_step()
	return _shoot_step()


# --- getting to the island ---------------------------------------------------------------------

func _boot_step() -> bool:
	match _boot:
		0:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = Look.title_slot_hit_rect_px(0).get_center()
			game._unhandled_input(ev)
		1:
			# Let the island open and the four bodies walk ashore. ⚠ Counted, not guessed: `pads`
			# ran 120 frames blind; this stays on step 1 until `ASHORE_WANTED` are standing.
			if game.battle == null:
				push_error("lab: 시작하기 did not open an island")
				return true
			for _f in 30:
				game._process(1.0 / 60.0)
				_boot_frames += 1
			var ashore: int = game.battle.ashore_ids().size()
			if ashore < ASHORE_WANTED and _boot_frames < BOOT_FRAMES_MAX:
				return false
			if ashore < ASHORE_WANTED:
				push_warning("lab: only %d ashore after %d frames — going on anyway" % [ashore, _boot_frames])
		2:
			field = game.field_view
			grid = game.battle.grid if game.battle != null else null
			if field == null or grid == null:
				push_error("lab: no field or no grid after the island opened")
				return true
			_names = _find_candidates()
			if _names.is_empty():
				push_error("lab: %s holds no candidate folder with a scene.gd" % DIR)
				return true
			_drag = _make_drag(DRAG_A, DRAG_B)
			_probe()
			_ink_check()
			_booted = true
			_label = Label.new()
			_label.position = Vector2(14, 10)
			_label.add_theme_font_size_override("font_size", 20)
			_label.add_theme_color_override("font_color", Color(1, 1, 1))
			_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			_label.add_theme_constant_override("outline_size", 6)
			root.add_child(_label)
			if not _shooting:
				var start := 0
				for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
					if a.is_valid_int() and int(a) >= 1 and int(a) <= _names.size():
						start = int(a) - 1
				_show(start)
				# The lab opens as if the fixed drag had just been released: the box up, the bodies
				# inside it in the hand, the reach lit. Otherwise the poll below takes the box down
				# on the first frame, because nothing is picked yet.
				_release_box()
				_catch.armed = true
	_boot += 1
	return false


func _find_candidates() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for name in d.get_directories():
		if name == "out":
			continue
		if ResourceLoader.exists("%s/%s/scene.gd" % [DIR, name]):
			out.append(name)
	out.sort()
	return out


# --- the drag every candidate is handed ------------------------------------------------------------

## Builds the `drag` dictionary of the contract from two screen points.
##
## **Where the helpers come from**: the rect is `Rect2` normalised with `abs()`; each ground hit is
## `FieldView.screen_to_terrain_px` — the same near-to-far ray walk a press goes through, so the box's
## corners land on the surface the player can SEE and not on the sea-level plane behind a hill — and
## its height is `FieldView._ground_h` on the 조각 that point falls in, which is `Islands.ground_h(level)`
## with the mesh's own `base_h` folded in. World px → the field's world space is `/ Look.TILE_PX`, the
## same division `_place_camera` makes: x → x, world-px y → z.
##
## ⚠ **No lift is added.** The hit is the terrain top itself; a candidate laying geometry on it adds
## `Look.FX_GROUND_LIFT_TILES` (0.02) or the ground z-fights through it.
func _make_drag(a: Vector2, b: Vector2) -> Dictionary:
	var rect := Rect2(a, b - a).abs()
	var corners := [rect.position, rect.position + Vector2(rect.size.x, 0.0),
		rect.end, rect.position + Vector2(0.0, rect.size.y)]
	var ground := PackedVector3Array()
	for c in corners:
		ground.append(ground_hit(c))
	return {
		"a": a,
		"b": b,
		"rect": rect,
		"ground": ground,
		"camera": field._cam,
	}


## **The terrain point under one screen px, in the field's world space.** Handed out so a ground-laid
## candidate can sample the surface along its own edges, not only at the four corners.
func ground_hit(at: Vector2) -> Vector3:
	var w: Vector2 = field.screen_to_terrain_px(at)
	var tv: Vector2i = field.world_to_tile(w)
	var h: float = field._ground_h(tv.x, tv.y)
	return Vector3(w.x / Look.TILE_PX, h, w.y / Look.TILE_PX)


## The screen point a body's feet are drawn at — `world_to_screen_px` on its own stand height, the
## same conversion `body_at_px` measures with.
func body_screen_px(uid: int) -> Vector2:
	var p: Vector2 = game.battle.soldier_pos[uid]
	return field.world_to_screen_px(p * Look.TILE_PX, field._stand_h(p))


## Prints what the fixed drag closes over, so A and B can be pinned from a run instead of guessed.
func _probe() -> void:
	var rect: Rect2 = _drag["rect"]
	print("[lab] cam_px=%s zoom=%.3f yaw=%.1f pitch=%.1f" % [
		str(field.cam_px), field.zoom, field.cam_yaw_deg, field.cam_pitch_deg])
	print("[lab] drag A=%s B=%s rect=%s" % [str(DRAG_A), str(DRAG_B), str(rect)])
	var g: PackedVector3Array = _drag["ground"]
	print("[lab] ground TL=%s TR=%s BR=%s BL=%s" % [str(g[0]), str(g[1]), str(g[2]), str(g[3])])
	for raw in Islands.builds():
		var b := raw as Dictionary
		var low := Vector2(int(b.get("x", 0)), int(b.get("y", 0)))
		print("[lab] build %s low=%s screen=%s" % [str(b.get("kind", "")), str(low),
			str(field.tile_to_screen_px(int(low.x), int(low.y)))])
	var inside := 0
	for uid in game.battle.ashore_ids():
		var p: Vector2 = game.battle.soldier_pos[uid]
		var s := body_screen_px(uid)
		var hit := rect.has_point(s)
		if hit:
			inside += 1
		print("[lab] 검사 %d tile=%s screen=%s inside=%s" % [uid, str(p), str(s), str(hit)])
	print("[lab] %d of %d ashore inside the rect" % [inside, game.battle.ashore_ids().size()])


## Runs `common.gd`'s ink loader once on a known picture and prints its coverage, so a candidate
## agent can trust the alpha it will get back.
func _ink_check() -> void:
	var common: GDScript = load("%s/common.gd" % DIR)
	var tex: ImageTexture = common.load_ink(
		"res://.candidates/selection_box/selbox_frame_01_seed2137183347_64px.png")
	if tex == null:
		push_error("lab: load_ink returned null")
		return
	var img := tex.get_image()
	var n := 0
	var sum := 0.0
	var peak := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y).a
			if a > 0.1:
				n += 1
			sum += a
			peak = maxf(peak, a)
	var total := img.get_width() * img.get_height()
	print("[lab] load_ink frame_01_64px: %dx%d, %d/%d px with alpha>0.1 (%.1f%%), mean alpha %.3f, peak %.3f, ink=%s" % [
		img.get_width(), img.get_height(), n, total, 100.0 * float(n) / float(total),
		sum / float(total), peak, str(common.ink_colour())])


# --- putting one candidate on the board -------------------------------------------------------------

func _apply(k: int) -> void:
	if _cand != null:
		_cand.unmount()
		_cand = null
	var scr: GDScript = load("%s/%s/scene.gd" % [DIR, str(_names[k])])
	_cand = scr.new()
	_cand.mount(game, field, _drag)


func _unmount() -> void:
	if _cand != null:
		_cand.unmount()
		_cand = null


func _show(k: int) -> void:
	_i = posmod(k, _names.size())
	# ⚠ In watch mode the box stands only while the hand is full or a drag is in flight — a candidate
	# switched to with nothing picked is named on the label and drawn on the next drag.
	if _shooting or _dragging or not game.hand.is_empty():
		_apply(_i)
	else:
		_unmount()
	_set_label()


func _set_label() -> void:
	if _label == null:
		return
	var name: String = str(_cand.NAME) if _cand != null else str(_names[_i])
	if _shooting:
		_label.text = name
	else:
		_label.text = "%d/%d  %s\nleft drag = the box · LEFT/RIGHT cycle · Q/E turn · WASD pan · R/F tilt · wheel zoom · ESC quit" % [
			_i + 1, _names.size(), name]


# --- the two shots ------------------------------------------------------------------------------

## Per candidate: mount → shoot yaw 0 → Q → settle → shoot yaw 90 → unmount → E → settle → next.
## Every step is one gated tick (four frames), so 「wait 3 frames」 is met by the gate itself.
func _shoot_step() -> bool:
	var per := 8
	var k: int = _shot / per
	if k >= _names.size():
		return true
	match _shot % per:
		0:
			_apply(k)
			_set_label()
		1:
			# ⚠ **Mount on one step, SHOOT on the next.** `get_texture()` hands back the frame already
			# drawn, so doing both in one step files the picture under the previous candidate's name.
			_save(str(_names[k]), "yaw0")
		2:
			_tap_key(KEY_Q)
			_begin_settle()
		3:
			if not _settled_now():
				return false
		4:
			_save(str(_names[k]), "yaw90")
		5:
			if _cand != null:
				_cand.unmount()
				_cand = null
			_tap_key(KEY_E)
			_begin_settle()
		6:
			if not _settled_now():
				return false
		7:
			pass
	_shot += 1
	return false


## **Sends the game's own key**, so the real `_on_turn_key` → `turn_notch` → sweep runs and the camera
## arrives the way it does for the player. Nothing here writes `cam_yaw_deg`.
func _tap_key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	ev.echo = false
	game._unhandled_input(ev)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	game._unhandled_input(up)


func _begin_settle() -> void:
	_yaw_last = INF
	_settled = 0


## True once the yaw has stopped changing between two gated ticks, nothing is owed to the sweep, and
## three more ticks have passed on top of that.
func _settled_now() -> bool:
	var yaw: float = field.cam_yaw_deg
	var still: bool = is_equal_approx(yaw, _yaw_last) and field._yaw_remaining == 0.0
	_yaw_last = yaw
	if not still:
		_settled = 0
		return false
	_settled += 1
	if _settled < 3:
		return false
	print("[lab] yaw settled at %.1f" % yaw)
	return true


func _save(name: String, which: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/out" % DIR))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT % [name, which]))
	print("[lab] %s %s yaw=%.1f" % [name, which, field.cam_yaw_deg])


# --- the watched run ----------------------------------------------------------------------------

func _tap(code: Key) -> bool:
	var down := Input.is_key_pressed(code)
	var was: bool = _held.get(code, false)
	_held[code] = down
	return down and not was


func _watch() -> bool:
	if Input.is_key_pressed(KEY_ESCAPE):
		return true
	if _drive and _drive_step():
		return true
	if _tap(KEY_RIGHT):
		_show(_i + 1)
	if _tap(KEY_LEFT):
		_show(_i - 1)
	_live_drag()
	# **The box lives exactly as long as the hand is full.** The right button's order goes to the
	# game untouched, `_order_the_island` lets go, and this line takes the box down on that frame.
	if _cand != null and not _dragging and game.hand.is_empty():
		_unmount()
	return false


## **The whole gesture, and not a picture beside it** (2026-09-02, the user at the lab, translated:
## *"when I drag, several should get selected... nothing gets selected, so how do I move them after
## dragging? Drag → the ones inside get selected → the move 판 lights → move."*).
##
## Press: A is the press point. Held: B is the pointer, every frame, and once the drag has passed
## `DRAG_MIN_PX` the drag dictionary is rebuilt exactly as the fixed one is (`_make_drag`) and the
## candidate is unmounted and mounted again with it — for the screen-space and the ground-laid
## candidates alike (04 re-projects its edge points every frame; that is its declared cost and it is
## let show). Release over 6 px: every 검사 whose DRAWN body overlaps the rect goes into the hand
## through the game's own `pick_many` and the reach lights through `_tell_the_view`; nobody inside
## lets go. Release under 6 px: a click, handed to the game's own `_press_the_island` — a body under
## it is picked, empty ground lets go.
func _live_drag() -> void:
	if _catch.down and not _dragging:
		_dragging = true
		_moved = false
		_drag_a = _catch.pressed_at
	if not _dragging:
		return
	var b: Vector2 = _catch.pos
	if not _moved and b.distance_to(_drag_a) >= DRAG_MIN_PX:
		_moved = true
	if _moved:
		_drag = _make_drag(_drag_a, b)
		_apply(_i)
		if _drive:
			print("[lab] remount %s rect=%s" % [str(_cand.NAME), str(_drag["rect"])])
	if _catch.released:
		_catch.released = false
		_dragging = false
		if _moved:
			print("[lab] drag A=%s B=%s rect=%s" % [str(_drag["a"]), str(_drag["b"]), str(_drag["rect"])])
			_release_box()
		else:
			# The game's own left press: `body_at_px` first, then the let-go on nothing.
			game._press_the_island(b)
			print("[lab] click at %s → hand holds %d" % [str(b), game.hand.ids.size()])


## **The release of the box**: pick everyone drawn inside the rect, or let go. Also what the boot
## does with the fixed drag, so the lab opens mid-gesture rather than before it.
func _release_box() -> void:
	var picked := _bodies_in_rect(_drag["rect"])
	if picked.is_empty():
		game._let_go()
		_unmount()
		print("[lab] picked 0: nobody drawn inside the rect — let go")
		return
	game.hand.pick_many(game.battle, picked)
	game._tell_the_view()
	print("[lab] picked %d: %s  reach=%d 조각 / %d 칸" % [game.hand.ids.size(), str(game.hand.ids),
		game.hand.reach.size(), game.hand.reach_blocks.size()])


## **Every ashore 검사 whose drawn picture overlaps `rect`**, measured the way `FieldView.body_at_px`
## measures a press — the sprite's foot and top through `world_to_screen_px`, its ink columns through
## `_ink_cols` — so a body whose head or shoulder is in the box counts, and one standing just under
## its edge does not. ⚠ The arithmetic is copied from `body_at_px` because that function answers one
## body for one point and has no rect twin; a lab may copy, `src/` may not.
func _bodies_in_rect(rect: Rect2) -> PackedInt32Array:
	var out := PackedInt32Array()
	var px_per_tile: float = Look.VIEWPORT_W_PX / field._visible_ground_px().x * Look.TILE_PX
	for raw_id in field._sprite_of_soldier:
		var k := int(field._sprite_of_soldier[raw_id])
		if k < 0 or k >= field._sprites.size():
			continue
		var s: Sprite3D = field._sprites[k]
		if not s.visible or s.texture == null:
			continue
		var xz := Vector2(s.position.x, s.position.z) * Look.TILE_PX
		var half_tall := float(s.texture.get_height()) * s.scale.y * s.pixel_size * 0.5
		var foot: Vector2 = field.world_to_screen_px(xz, s.position.y - half_tall)
		var top: Vector2 = field.world_to_screen_px(xz, s.position.y + half_tall)
		var texel_px := s.scale.x * s.pixel_size * px_per_tile
		var half_w := float(s.texture.get_width()) * 0.5
		var span: Vector2i = field._ink_cols.get(s.texture, Vector2i(0, s.texture.get_width() - 1))
		var left := foot.x + (float(span.x) - half_w) * texel_px
		var right := foot.x + (float(span.y) + 1.0 - half_w) * texel_px
		var drawn := Rect2(left, top.y, right - left, foot.y - top.y)
		if drawn.intersects(rect):
			out.append(int(raw_id))
	out.sort()
	return out


# --- the scripted drive, for proving the live drag through the engine's own input ------------------

func _feed_mouse(at: Vector2, button: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button as MouseButton
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func _feed_motion(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func _feed_key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


## The 칸 the drive orders onto, and who was picked, remembered across the frames the gesture takes.
var _drive_block := -1
var _drive_ids := PackedInt32Array()


## Frame-numbered: a click on empty sea (lets go, box down), a drag over the four at the door (picked
## 4, reach lit), a RIGHT press on a lit 칸 two 칸 east (03-11's order: everyone walks, the hand
## empties, the box comes down), three RIGHT taps to 04, a second drag there, then quit.
func _drive_step() -> bool:
	var f := _drive_frame
	_drive_frame += 1
	var sea := Vector2(1100.0, 600.0)
	var a1 := Vector2(440.0, 345.0)
	var b1 := Vector2(660.0, 445.0)
	var a2 := Vector2(300.0, 200.0)
	var b2 := Vector2(540.0, 330.0)
	if f == 5:
		_feed_mouse(sea, MOUSE_BUTTON_LEFT, true)
	elif f == 7:
		_feed_mouse(sea, MOUSE_BUTTON_LEFT, false)
	elif f == 9:
		print("[lab] after the sea click: hand holds %d, box %s" % [
			game.hand.ids.size(), "up" if _cand != null else "down"])
	elif f == 10:
		_feed_mouse(a1, MOUSE_BUTTON_LEFT, true)
	elif f > 10 and f <= 40:
		_feed_motion(a1.lerp(b1, float(f - 10) / 30.0))
	elif f == 41:
		_feed_mouse(b1, MOUSE_BUTTON_LEFT, false)
	elif f == 50:
		_drive_ids = game.hand.ids.duplicate()
		_drive_block = _block_two_east()
		var at := _block_screen_px(_drive_block)
		print("[lab] reach lit: %d 조각, order 칸 %d at screen %s, can_reach=%s" % [
			game.hand.reach.size(), _drive_block, str(at), str(game.hand.can_reach_block(_drive_block))])
		_feed_mouse(at, MOUSE_BUTTON_RIGHT, true)
	elif f == 52:
		_feed_mouse(_block_screen_px(_drive_block), MOUSE_BUTTON_RIGHT, false)
	elif f == 56:
		var tiles: PackedInt32Array = grid.tiles_of_block(_drive_block)
		var all_in := true
		var orders := []
		for id in _drive_ids:
			var o := int(game.battle.soldier_order[id])
			orders.append(o)
			all_in = all_in and tiles.has(o)
		print("[lab] after the order: soldier_order=%s all in 칸 %d: %s, hand holds %d, box %s" % [
			str(orders), _drive_block, str(all_in), game.hand.ids.size(), "up" if _cand != null else "down"])
	elif f in [60, 70, 80]:
		_feed_key(KEY_RIGHT, true)
	elif f in [62, 72, 82]:
		_feed_key(KEY_RIGHT, false)
	elif f == 90:
		_feed_mouse(a2, MOUSE_BUTTON_LEFT, true)
	elif f > 90 and f <= 120:
		_feed_motion(a2.lerp(b2, float(f - 90) / 30.0))
	elif f == 121:
		_feed_mouse(b2, MOUSE_BUTTON_LEFT, false)
	elif f == 140:
		print("[lab] drive done on %s, hand holds %d, box %s" % [
			str(_names[_i]), game.hand.ids.size(), "up" if _cand != null else "down"])
		return true
	return false


## A lit 칸 two 칸 east of the picked bodies' own 칸, or the first lit 칸 that is not their own.
func _block_two_east() -> int:
	if game.hand.ids.is_empty():
		return -1
	var p: Vector2 = game.battle.soldier_pos[int(game.hand.ids[0])]
	var here := grid.block_of(grid.tile_index(int(p.x), int(p.y)))
	var east := grid.block_of(grid.tile_index(int(p.x) + 2 * Rules.BLOCK_TILES, int(p.y)))
	if game.hand.can_reach_block(east):
		return east
	for b in game.hand.reach_blocks:
		if int(b) != here:
			return int(b)
	return -1


## The middle of a 칸 on the glass, through the same conversion the bodies are drawn with.
func _block_screen_px(block: int) -> Vector2:
	var tiles: PackedInt32Array = grid.tiles_of_block(block)
	var mid := Vector2.ZERO
	for t in tiles:
		mid += Vector2(int(t) % grid.w, int(t) / grid.w)
	mid /= float(maxi(tiles.size(), 1))
	return field.world_to_screen_px(Look.tile_point_px(mid), field._ground_h(int(mid.x), int(mid.y)))
