# **Nine bodies in ONE 블록 (칸), placed five different ways, at two body sizes.**
#
# ⚠⚠ **This lab drives the REAL game**, the way `.prototypes/pads/lab.gd` does: the nine stand on the
# ground the game ships, under its own camera, sun and sea, and **they are drawn by `FieldView`'s own
# body path** — same texture, same billboard, same ground disc. A body drawn by the lab itself would
# be a picture of the lab.
#
# **Two ways to run it, and the default is the one you WATCH.**
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/nine/lab.gd
#       opens a window and stays. **1..5 pick a version · LEFT/RIGHT step · SPACE swaps body size.**
#       The game's own keys still work — Q/E turn, R/F tilt, wheel zooms. ESC quits.
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/nine/lab.gd -- shoot
#       photographs every version at every size and quits.
#
# ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
# black with no error anywhere.
#
# **A version is a folder with a `scene.gd` carrying two statics**:
#   `static func title() -> String`
#   `static func seats(c: Vector2, face: Vector2) -> PackedVector2Array`   # nine, in 조각 position units
extends SceneTree

const DIR := "res://.prototypes/nine"
const OUT := "res://.prototypes/nine/out/%s_%s.png"
## How many bodies stand in the 블록.
const NINE := 9
## The body sizes SPACE steps through in the watched run. **1.0 is exactly what the game ships.**
## ⚠ **The shoot no longer sweeps these** — see `FACES`.
const SCALES := [1.0, 1.25]
## ⚠⚠ **THE SHOOT SWEEPS FACINGS, AND IT SWEPT BODY SIZES UNTIL 2026-08-31.** The size question was
## answered by the first sheet; **the live one is 「what does 「it turns」 mean」** (the user, on seeing
## it: 「What is this turning? Tell me about the turning first」), and a facing is the only thing that
## can answer it in a still picture. ⚠ **A version that ignores the facing is photographed twice
## identically, and that identity is itself the result** — it is what「doesn't turn」looks like.
const FACES := [Vector2(0, 1), Vector2(1, 0)]
## What each facing is called in a file name. Same length as `FACES`.
const FACE_NAMES := ["south", "east"]
## Wheel notches for the shot. The nine have to fill the frame or the sheet is a picture of an island.
const NEAR_NOTCHES := 9

var game: Game = null
var field: FieldView = null
var grid: Grid = null
## The 블록 the nine stand in, as its low corner in 조각.
var block_low := Vector2i.ZERO
## Which way the ranks face. **Fixed and not derived**: a facing that came out of the sim would differ
## between versions and the sheet would be comparing two things at once.
var face := Vector2(0, 1)

var _names: Array = []
var _seats := PackedVector2Array()
var _scale := 1.0
var _i := 0
var _booted := false
var _shooting := false
var _wait := 0
var _boot := 0
var _shot := 0
var _label: Label = null
var _held := {}


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	game = Game.new()
	root.add_child(game)
	_shooting = OS.get_cmdline_args().has("shoot") or OS.get_cmdline_user_args().has("shoot")


func _process(_delta: float) -> bool:
	if _booted:
		# ⚠⚠ **THE NINE ARE RE-STOOD EVERY FRAME, AND THAT IS NOT A FIXUP.** They are real bodies in a
		# real fight: left alone the sim musters them, walks them and re-seats them, and the picture
		# being judged would drift out from under the camera between the shot and the sheet.
		_restand()
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
			for _i2 in 90:
				game._process(1.0 / 60.0)
		2:
			field = game.field_view
			grid = game.battle.grid if game.battle != null else null
			if field == null or grid == null:
				push_error("lab: 시작하기 did not open an island")
				return true
			_names = _find_versions()
			if _names.is_empty():
				push_error("lab: .prototypes/nine holds no version folder with a scene.gd")
				return true
			block_low = _pick_block()
			_make_nine()
			_frame_camera()
			_booted = true
			print("[lab] block_low=%s centre=%s ashore=%d roster=%d pos0=%s cam=%s zoom=%f" % [
				str(block_low), str(_block_centre()), game.battle.ashore_ids().size(),
				game.run.army.type_id.size(), str(game.battle.soldier_pos[0]),
				str(field.cam_px), field.zoom])
			if not _shooting:
				_label = Label.new()
				_label.position = Vector2(14, 10)
				_label.add_theme_font_size_override("font_size", 20)
				_label.add_theme_color_override("font_color", Color(1, 1, 1))
				_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
				_label.add_theme_constant_override("outline_size", 6)
				root.add_child(_label)
				_show(0)
			else:
				_apply(0, 0)
	_boot += 1
	return false


func _find_versions() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for name in d.get_directories():
		if ResourceLoader.exists("%s/%s/scene.gd" % [DIR, name]):
			out.append(name)
	out.sort()
	return out


## **A flat 블록 with a whole 조각 of walkable land in every direction round it.**
##
## ⚠ **All four 조각, not one**: nine bodies spill over the whole 블록, and a 블록 with one 조각 of
## plateau in it would stand three of them inside a cliff.
## ⚠⚠ **THE RING OF LAND ROUND IT IS THE HALF THAT WAS MISSING** (measured 2026-08-31 by looking at
## the first sheet): the first pick was the flat 블록 furthest from the 성채, which is the one on the
## shore — **five of the nine stood against open water and the sheet was half sea.** A crowd is judged
## against the ground it stands on, so the ground has to be in frame all the way round it.
func _pick_block() -> Vector2i:
	var b := Rules.BLOCK_TILES
	var mid := Vector2(grid.w, grid.h) * 0.5
	var best := Vector2i(-1, -1)
	var best_score := 1.0e9
	for by in range(0, grid.h - b + 1, b):
		for bx in range(0, grid.w - b + 1, b):
			if not _clear_block(bx, by):
				continue
			var score := Vector2(bx, by).distance_to(mid)
			if score < best_score:
				best_score = score
				best = Vector2i(bx, by)
	return best if best.x >= 0 else Vector2i(grid.w / 2, grid.h / 2)


## Whether the 블록 at `(bx, by)` is flat, walkable, and ringed by one more 조각 of walkable land on
## every side — sixteen 조각 in all, at one single level.
func _clear_block(bx: int, by: int) -> bool:
	var b := Rules.BLOCK_TILES
	var lvl := -999
	for dy in range(-1, b + 1):
		for dx in range(-1, b + 1):
			var tx := bx + dx
			var ty := by + dy
			if tx < 0 or ty < 0 or tx >= grid.w or ty >= grid.h:
				return false
			if not grid.is_passable(tx, ty):
				return false
			var l := grid.level_at(tx, ty)
			if lvl == -999:
				lvl = l
			elif l != lvl:
				return false
	return true


## **Rebuilds the fight with a roster of exactly nine 검사 and nothing else on the board.**
##
## ⚠⚠ **`battle.setup` AND NOT AN APPEND TO THE COLUMNS.** A `Battle` sizes every per-body column off
## the roster at setup; recruiting after it leaves nine rows in `Army` and four in `soldier_pos`, and
## the first `step` walks off the end of six arrays at once.
## ⚠ **Spawns are handed in EMPTY** — a 늑대 in frame is one more thing the eye lands on, and this
## sheet is about nine men standing.
func _make_nine() -> void:
	var b := game.battle
	var army := game.run.army
	var slot := army.slot_of_type(Rules.SWORDSMAN)
	while army.type_id.size() < NINE:
		army.recruit(slot)
	b.setup(grid, army, [], b.keep_tiles, b.muster_tile)
	# ⚠⚠ **THE HP LINE IS NOT BOOKKEEPING — WITHOUT IT ALL NINE DIE ON THE FIRST SUB-STEP.** `setup`
	# leaves `soldier_hp` at 0 and `place_ashore` is what fills it, so a body stood on the board by
	# hand is ASHORE with no health, and the death phase kills every 검사 the frame after it is placed.
	# **Measured 2026-08-31**: the first ten shots came back with an empty island and no error anywhere.
	for i in NINE:
		b.soldier_state[i] = Battle.SoldierState.ASHORE
		b.soldier_hp[i] = game.run.army.max_hp_of(i)
	# ⚠⚠ **NOT ONE OF THEM RESERVES A 조각, AND THAT IS DELIBERATE.** `FieldView` reads the reservation
	# slot to spread a crowd; an unreserved body answers slot 0, whose offset is zero, so **the seat
	# this lab computes is exactly where the body is drawn.** Reserve them and every version would be
	# photographed wearing `01-now`'s ring on top of its own arrangement.
	for i in NINE:
		grid.release_all(i)


## Points the camera at the middle of the 블록 and zooms in until the nine fill the frame.
func _frame_camera() -> void:
	for _n in NEAR_NOTCHES:
		field.zoom_at(Look.viewport_size_px() * 0.5, Look.ZOOM_STEP)
	var c := Look.tile_point_px(_block_centre())
	field.cam_px = c - field._visible_ground_px() * 0.5
	field._clamp_cam()


## The middle of the 블록 in 조각 POSITION units — the space `Look.tile_point_px` takes, where a body
## standing on 조각 (x, y) has position (x, y). ⚠ **Not the 조각 index and not world px.**
func _block_centre() -> Vector2:
	return Vector2(block_low) + Vector2.ONE * (float(Rules.BLOCK_TILES) - 1.0) * 0.5


# --- putting one version on the board ------------------------------------------------------------

func _apply(k: int, scale_i: int) -> void:
	var scr: GDScript = load("%s/%s/scene.gd" % [DIR, str(_names[k])])
	_seats = scr.seats(_block_centre(), face)
	_scale = float(SCALES[scale_i % SCALES.size()])
	_i = k
	_restand()


## Writes the nine bodies onto their seats, and stretches the drawn pictures by `_scale`.
##
## ⚠⚠ **THE SIZE IS APPLIED TO THE SPRITES AND NOT TO `Look`.** Every body size in the game is a
## `const` in `look.gd` and a const cannot be moved at runtime, so a lab that wanted two sizes in one
## round had to reach the nodes. ⚠ **The ground disc is NOT scaled with them** — it is drawn into the
## fx buffer from the body's radius, and at 1.25 it sits a quarter narrow. **The disc is not what this
## sheet is about; say it out loud rather than let it be read as a result.**
func _restand() -> void:
	var b := game.battle
	if b == null or _seats.is_empty():
		return
	for i in mini(NINE, b.soldier_pos.size()):
		b.soldier_pos[i] = _seats[i]
		b.soldier_order[i] = -1
	if _scale == 1.0 or field == null:
		return
	for k in field._sprites_used:
		var s: Sprite3D = field._sprites[k]
		if s.texture == null or not s.visible:
			continue
		# Grown about the FEET and not about the middle, or a bigger body floats off the ground.
		var tall := float(s.texture.get_height()) * s.scale.y / Look.TILE_PX
		var foot := s.position.y - tall * 0.5
		s.scale = Vector3(s.scale.x * _scale, s.scale.y * _scale, 1.0)
		var tall2 := float(s.texture.get_height()) * s.scale.y / Look.TILE_PX
		s.position.y = foot + tall2 * 0.5


func _show(k: int) -> void:
	_apply(posmod(k, _names.size()), maxi(SCALES.find(_scale), 0))
	if _label != null:
		var scr: GDScript = load("%s/%s/scene.gd" % [DIR, str(_names[_i])])
		var fi := maxi(FACES.find(face), 0)
		_label.text = "%d/%d  %s — %s\n몸 크기 x%.2f · 부대가 보는 쪽 %s\n1..%d 고르기 · ←→ 넘기기 · SPACE 크기 · T 보는 쪽 · Q/E 화면 돌리기 · ESC" % [
			_i + 1, _names.size(), str(_names[_i]), scr.title(), _scale,
			str(FACE_NAMES[fi]), _names.size()]


# --- the shots -----------------------------------------------------------------------------------

func _shoot_step() -> bool:
	var per := 2
	var n: int = _shot / per
	var total: int = _names.size() * FACES.size()
	if n >= total:
		return true
	var k: int = n / FACES.size()
	var fi: int = n % FACES.size()
	match _shot % per:
		0:
			face = FACES[fi]
			_apply(k, 0)
		1:
			# ⚠ **Apply on one step, SHOOT on the next.** `get_texture()` hands back the frame already
			# drawn, so doing both in one step files every picture under the previous seat plan.
			_save(str(_names[k]), str(FACE_NAMES[fi]))
	_shot += 1
	return false


## How much of the frame one picture keeps, in screen px. **The zoom is capped by `Look.ZOOM_MAX`**, so
## the nine can only be made to fill the picture by cutting the picture down to them — a full 1280 x 720
## frame of which the crowd is one twentieth is a sheet about an island.
const CROP := Vector2i(500, 440)
## How far above the ground point the crop is centred. Bodies stand UP from their feet, so a box
## centred on the ground puts every head against its top edge.
const CROP_RISE := 90


func _save(name: String, which: String) -> void:
	var img := root.get_texture().get_image()
	var p := (field.tile_to_screen_px(block_low.x, block_low.y)
			+ field.tile_to_screen_px(block_low.x + 1, block_low.y + 1)) * 0.5
	var x := clampi(int(p.x) - CROP.x / 2, 0, maxi(img.get_width() - CROP.x, 0))
	var y := clampi(int(p.y) - CROP_RISE - CROP.y / 2, 0, maxi(img.get_height() - CROP.y, 0))
	img.get_region(Rect2i(x, y, CROP.x, CROP.y)).save_png(
		ProjectSettings.globalize_path(OUT % [name, which]))
	print("[lab] %s %s  sprites=%d ashore=%d" % [name, which,
		field._sprites_used, game.battle.ashore_ids().size()])


# --- the watched run -----------------------------------------------------------------------------

func _tap(code: Key) -> bool:
	var down := Input.is_key_pressed(code)
	var was: bool = _held.get(code, false)
	_held[code] = down
	return down and not was


func _watch() -> bool:
	if Input.is_key_pressed(KEY_ESCAPE):
		return true
	for n in _names.size():
		if _tap((KEY_1 + n) as Key):
			_show(n)
	if _tap(KEY_RIGHT):
		_show(_i + 1)
	if _tap(KEY_LEFT):
		_show(_i - 1)
	if _tap(KEY_SPACE):
		_scale = float(SCALES[(maxi(SCALES.find(_scale), 0) + 1) % SCALES.size()])
		_show(_i)
	# ⚠ **T turns what the NINE are looking at, and Q/E turn the CAMERA.** They are two different
	# turnings and the whole subject of this round is telling them apart, so they are on separate keys.
	if _tap(KEY_T):
		var at := FACES.find(face)
		face = FACES[(maxi(at, 0) + 1) % FACES.size()]
		_show(_i)
	return false
