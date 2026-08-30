# **Five ways of telling the player where a body may go, on the real island.**
#
# ⚠⚠ **This lab drives the REAL game**, unlike `.prototypes/shoreline/lab.gd` which builds its own
# little world. The 판 is a mark lying on the ground the game actually ships, under the game's own
# camera, sun and sea — a mark judged on a lab's stand-in block would be judged against the wrong
# ground. So this opens `Game`, presses 시작하기, and then hangs each version's marks in the field's
# own world.
#
# **Two ways to run it, and the default is the one you WATCH.**
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/pads/lab.gd
#       opens a window and stays. **1..5 pick a version · LEFT/RIGHT step through them.** The game's
#       own keys still work — Q/E turn, R/F tilt, wheel zooms, TAB is the shipped 판. ESC quits.
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/pads/lab.gd -- shoot
#       photographs every version twice — the whole board, then zoomed in — and quits.
#
# ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
# black with no error anywhere.
#
# **A version is a folder with a `scene.gd` carrying `static func build(lab) -> Node3D`.** It may
# return null (`01-now` does — the shipped 판 is a baked object and it only has to be switched on).
extends SceneTree

const DIR := "res://.prototypes/pads"
const OUT := "res://.prototypes/pads/out/%s_%s.png"
## How far above the walking surface a mark floats. ⚠ **The game uses 0.02 for the same job**
## (`Look.FX_GROUND_LIFT_TILES`); anything less and the ground z-fights through it.
const LIFT := 0.02
## Wheel notches for the close shot. Five notches of `ZOOM_STEP` is about double.
const NEAR_NOTCHES := 5

var game: Game = null
var field: FieldView = null
var grid: Grid = null
## **The 조각 under the cursor, or -1 for nowhere.**
var hover_tile := -1
## **The 칸 under the cursor** — the 2x2 lump, numbered exactly as `field_view._wash_cells` numbers it.
##
## ⚠⚠ **THE HOVER LIGHTS A 칸 AND NOT A 조각** (2026-08-29, the user: 「칸만 되야하는데 조각 자체가
## 되는듯? 저 칸만 되는게 좋을듯」, correcting a round that had lit one 조각). This is the same unit the
## shipped 판 picks out, decided 2026-08-27 and **not** overturned.
var hover_block := -1

var _names: Array = []
var _extra: Node3D = null
var _i := 0
var _wait := 0
var _boot := 0
var _shot := 0
var _booted := false
var _shooting := false
var _label: Label = null
var _held := {}


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	game = Game.new()
	root.add_child(game)
	_shooting = OS.get_cmdline_args().has("shoot") or OS.get_cmdline_user_args().has("shoot")


func _process(_delta: float) -> bool:
	# ⚠ **The watched run is not gated.** The hover has to answer on the frame the cursor crosses a
	# 조각; the four-frame gate below is for the boot and the shots, where a frame has to be let
	# through before it can be read back.
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
			# Let the island open and the bodies land where they land.
			for _i2 in 120:
				game._process(1.0 / 60.0)
		2:
			field = game.field_view
			grid = game.battle.grid if game.battle != null else null
			if field == null or grid == null:
				push_error("lab: 시작하기 did not open an island")
				return true
			_names = _find_versions()
			if _names.is_empty():
				push_error("lab: .prototypes/pads holds no version folder with a scene.gd")
				return true
			_booted = true
			if _shooting:
				# ⚠ **A photographed run has no cursor**, so the hover is pointed by hand — two 조각
				# east of the body, close enough to be in frame and clear of the body's own picture.
				# **Both the shipped 판 and the versions are told**, or the sheet compares a lit 칸
				# against an unlit one and calls it a difference of mechanism.
				var b: Vector2i = body_tile() + Vector2i(2, 0)
				hover_tile = grid.tile_index(b.x, b.y)
				hover_block = block_of(b.x, b.y)
				field.set_hover_tile(hover_tile)
			if not _shooting:
				_label = Label.new()
				_label.position = Vector2(14, 10)
				_label.add_theme_font_size_override("font_size", 22)
				_label.add_theme_color_override("font_color", Color(1, 1, 1))
				_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
				_label.add_theme_constant_override("outline_size", 6)
				root.add_child(_label)
				# **A bare number on the command line is which version to open on.** Coming back to
				# one candidate after changing it is the whole use of this thing, and pressing a key
				# every time is how the wrong one gets looked at.
				var start := 0
				for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
					if a.is_valid_int() and int(a) >= 1 and int(a) <= _names.size():
						start = int(a) - 1
				_show(start)
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


# --- putting one version on the board ------------------------------------------------------------

func _apply(k: int) -> void:
	if _extra != null:
		_extra.queue_free()
		_extra = null
	# ⚠ **Every version starts from the same board**: the shipped 판 off, and only `01-now` turns it
	# back on. Without this line version two is photographed wearing version one's marks.
	field.set_pads_revealed(false)
	var scr: GDScript = load("%s/%s/scene.gd" % [DIR, str(_names[k])])
	var made = scr.build(self)
	if made != null:
		_extra = made
		field._world.add_child(_extra)


func _show(k: int) -> void:
	_i = posmod(k, _names.size())
	_apply(_i)
	if _label != null:
		_label.text = "%d/%d  %s\n1..%d pick · LEFT/RIGHT step · Q/E turn · R/F tilt · wheel zoom · ESC quit" % [
			_i + 1, _names.size(), str(_names[_i]), _names.size()]


# --- the two shots ------------------------------------------------------------------------------

func _shoot_step() -> bool:
	var per := 4
	var k: int = _shot / per
	if k >= _names.size():
		return true
	match _shot % per:
		0:
			_apply(k)
		1:
			# ⚠ **Apply on one step, SHOOT on the next.** `get_texture()` hands back the frame already
			# drawn, so doing both in one step files every picture under the previous version's name.
			_save(str(_names[k]), "far")
		2:
			_zoom(NEAR_NOTCHES)
		3:
			_save(str(_names[k]), "near")
			_zoom(-NEAR_NOTCHES)
	_shot += 1
	return false


func _zoom(notches: int) -> void:
	var at := Look.viewport_size_px() * 0.5
	var f := Look.ZOOM_STEP if notches > 0 else 1.0 / Look.ZOOM_STEP
	for _n in absi(notches):
		field.zoom_at(at, f)


func _save(name: String, which: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT % [name, which]))
	print("[lab] %s %s" % [name, which])


# --- the watched run ----------------------------------------------------------------------------

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
	# **The cursor, polled rather than listened for.** The game's own handler already turns a motion
	# event into a tile; asking it again here costs one call and keeps the lab out of the input path.
	var t: int = game._tile_at(root.get_mouse_position())
	if t != hover_tile:
		hover_tile = t
		hover_block = -1 if t < 0 else block_of(t % grid.w, t / grid.w)
		# ⚠ **The whole version is rebuilt on every crossing.** A thousand triangles is nothing, and a
		# prototype that keeps a second incremental path is a prototype with two ways to be wrong.
		_apply(_i)
	return false


# --- what a version is handed --------------------------------------------------------------------

## How high a mark on this tile floats, in world units. **World units are tiles** and the island's
## own level-0 top is `Islands.base_h()` above zero, which is why this is not just the level.
func tile_y(tx: int, ty: int) -> float:
	return Islands.ground_h(grid.level_at(tx, ty)) + LIFT


func walkable(tx: int, ty: int) -> bool:
	return grid.is_passable(tx, ty)


## **Which 칸 a 조각 belongs to.** ⚠ The arithmetic is copied from `field_view._wash_cells` on purpose:
## a lab that numbers the lumps its own way would light a different 칸 from the one the game lights.
func block_of(tx: int, ty: int) -> int:
	var span: int = Look.WASH_BLOCK_TILES
	var across: int = (grid.w + span - 1) / span
	return (ty / span) * across + (tx / span)


## The low corner of a 칸, in 조각. **The 칸 is `Look.WASH_BLOCK_TILES` across from there.**
func block_origin(blk: int) -> Vector2i:
	var span: int = Look.WASH_BLOCK_TILES
	var across: int = (grid.w + span - 1) / span
	return Vector2i((blk % across) * span, (blk / across) * span)


## Every land tile, walkable or not. **Water is what this excludes** — an unreachable plateau is land.
func is_land(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= grid.w or ty >= grid.h:
		return false
	return grid.water[ty * grid.w + tx] == 0


## Where the one body on the board is standing, or the middle of the island if there is none.
func body_tile() -> Vector2i:
	var b := game.battle
	if b != null:
		for uid in b.ashore_ids():
			var p: Vector2 = b.soldier_pos[uid]
			return Vector2i(int(p.x), int(p.y))
	return Vector2i(grid.w / 2, grid.h / 2)


## **Every tile a body standing on `from` can walk to, and how many steps it costs.** Uses the game's
## own `can_step`, so a version showing reach shows the rule rather than a second opinion of it.
func reach(from: Vector2i, max_steps: int) -> Dictionary:
	var out := {}
	if not walkable(from.x, from.y):
		return out
	out[grid.tile_index(from.x, from.y)] = 0
	var frontier: Array[int] = [grid.tile_index(from.x, from.y)]
	while not frontier.is_empty():
		var next: Array[int] = []
		for t in frontier:
			var d: int = out[t]
			if d >= max_steps:
				continue
			var tx := t % grid.w
			var ty := t / grid.w
			for off in Grid.NEIGHBOURS:
				var nx: int = tx + int(off[0])
				var ny: int = ty + int(off[1])
				if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
					continue
				var nt := grid.tile_index(nx, ny)
				if out.has(nt):
					continue
				if not grid.can_step(t, nt):
					continue
				out[nt] = d + 1
				next.append(nt)
		frontier = next
	return out


## An unshaded, alpha-blended material — what every mark here is drawn with. **Unshaded on purpose**:
## a mark that takes the sun goes dark in the island's own shadow, which is exactly where it is most
## needed.
func flat_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## One flat quad lying on the ground, `size` tiles across, centred on `c`. Vertex colour carries the
## alpha so one material can draw a whole faded field in a single mesh.
func lay_quad(st: SurfaceTool, c: Vector3, sx: float, sz: float, col: Color) -> void:
	var a := Vector3(c.x - sx * 0.5, c.y, c.z - sz * 0.5)
	var b := Vector3(c.x + sx * 0.5, c.y, c.z - sz * 0.5)
	var d := Vector3(c.x + sx * 0.5, c.y, c.z + sz * 0.5)
	var e := Vector3(c.x - sx * 0.5, c.y, c.z + sz * 0.5)
	for v in [a, b, d, a, d, e]:
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


## The same quad with its corners taken off — **a rounded square, drawn as a fan**. The shipped 판 is
## rounded and a mark that is not reads as a different object standing on the ground, so a version
## comparing itself against `01-now` uses this rather than `lay_quad`.
func lay_round_quad(st: SurfaceTool, c: Vector3, size: float, radius: float, col: Color) -> void:
	var ring := round_ring(size, radius)
	var n := ring.size()
	for i in n:
		var p: Vector2 = ring[i]
		var q2: Vector2 = ring[(i + 1) % n]
		_v(st, c, col)
		_v(st, Vector3(c.x + p.x, c.y, c.z + p.y), col)
		_v(st, Vector3(c.x + q2.x, c.y, c.z + q2.y), col)


## The outline of one rounded square, about its own centre. **Handed out** so a version can build a
## side wall on the same points the top was cut from.
func round_ring(size: float, radius: float) -> PackedVector2Array:
	var half := size * 0.5
	var r: float = clampf(radius, 0.0, half)
	var ring := PackedVector2Array()
	# The four corners, each swung through a quarter turn about its own centre.
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for i in 4:
		var q: Vector2 = corners[i]
		var mid := Vector2(q.x * (half - r), q.y * (half - r))
		var a0 := atan2(q.y, q.x) - PI * 0.25
		for j in ROUND_SEGS + 1:
			var a: float = a0 + PI * 0.5 * (float(j) / float(ROUND_SEGS))
			ring.append(mid + Vector2(cos(a), sin(a)) * r)
	return ring


## **A lifted 판 with a side, so it reads as a plate standing off the ground rather than a brighter
## patch of it** (2026-08-29, the user: 「판이 떠야함」). A flat quad raised under this camera is only
## a quad that moved; what says 「떠 있다」 is the wall you can see under its edge.
func lay_round_slab(st: SurfaceTool, c: Vector3, size: float, radius: float,
					thick: float, top: Color, side: Color) -> void:
	var ring := round_ring(size, radius)
	var n := ring.size()
	for i in n:
		var p: Vector2 = ring[i]
		var q: Vector2 = ring[(i + 1) % n]
		var a := Vector3(c.x + p.x, c.y, c.z + p.y)
		var b := Vector3(c.x + q.x, c.y, c.z + q.y)
		_v(st, c, top)
		_v(st, a, top)
		_v(st, b, top)
		# The wall under that edge, dropped `thick` and wound both ways — the material culls nothing.
		var a2 := Vector3(a.x, c.y - thick, a.z)
		var b2 := Vector3(b.x, c.y - thick, b.z)
		_v(st, a, side)
		_v(st, a2, side)
		_v(st, b2, side)
		_v(st, a, side)
		_v(st, b2, side)
		_v(st, b, side)


func _v(st: SurfaceTool, at: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal(Vector3.UP)
	st.add_vertex(at)


## How many segments one rounded corner is cut into. Three is enough at this size; the corner is a
## third of a tile on screen at the opening zoom.
const ROUND_SEGS := 3


## The node a version hands back: one mesh, one material, one draw call.
func one_mesh(st: SurfaceTool, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
