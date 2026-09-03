extends SceneTree
## **One piece on screen at a time, in the GAME's light, driven by hand.**
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/piece_viewer.gd
## ```
##
## ⚠⚠ **A PIECE SHOWN UNDER BLENDER'S LIGHT LIES, AND THAT IS THE WHOLE REASON THIS FILE EXISTS.**
## The Blender-side viewer it was written against (`tools/blender/one_piece.py`) was deleted 2026-08-27
## and the whole `tools/blender/` folder went on 2026-08-31; **this is what is left, and it shows the
## same baked block under the field's sun, the field's ambient and the field's outline pass.** The
## failure it keeps catching: **a value that reads correctly in Blender goes black in the game.** A
## block judged here has been judged where it has to survive.
##
## ⚠ **It loads `assets/terrain/pieces.glb` and adds NOTHING of its own to the geometry.** If a block
## looks wrong here, the block is wrong — not the viewer. The only things this file invents are the
## camera, the light, the sea plane and the labels, and each of them is copied from `field_view.gd`
## rather than retuned, so there is one place those numbers live and it is `src/look.gd`.
##
## ⚠ **Not a net and never green.** Nothing here asserts. It exists so a human can look, which is the
## only way 「사용자가 화면을 보고 「됐다」고 말한다」 can ever be met.
##
## The hand:
##   **← →** or **A D**   the previous / next block
##   **Tab**              one block  <->  the whole kit in a row
##   **left-drag**        pan (the island is twenty tiles across and the stair is not in the middle)
##   **H**                back to the middle
##   **right-drag / Q E** turn
##   **R F**              tilt
##   **wheel / + -**      zoom
##   **O**                the outline pass on / off
##   **G**                the sea plane on / off
##   **S**                save a PNG under `tools/shot/out/pieces/`
##   **Esc**              quit
##
## The flags, all after a bare `--`:
##   `--glb res://assets/terrain/island.glb`   look at the baked island instead of the 31-block kit
##   `--at X,Z`                                aim at a spot rather than the middle
##   `--zoom N`                                start N tiles wide
##   `--shot1`                                 render THIS aim from three yaws and quit
##
## ⚠ **`--shot` stood beside `--shot1` until 2026-08-27 and is gone** — the tombstone where `_shoot_all`
## stood, below `_zoom`, carries what it knew. `--shot1` is the flag that survived, because it is the one
## the Blender manual's own loop actually carries. (`tools/blender/README.md`, which carried that
## loop until 2026-08-31, is deleted with the rest of that folder.)

const GLB := "res://assets/terrain/pieces.glb"

## ⚠ **Under `tools/shot/out/`, which carries a `.gdignore`.** Godot imports every PNG it can see, and
## ninety-seven screenshots were costing fifty-seven `.import` files until they were moved behind that
## file (2026-08-27). A shot written anywhere else in the project puts them straight back.
const SHOT_DIR := "res://tools/shot/out/pieces"

## ⚠⚠ **`pieces.glb` AND `island.glb` ARE NOT THE SAME KIND OF FILE, AND THE VIEWER HAS TO KNOW WHICH.**
## Measured 2026-09-03 by reading both:
##
##   `pieces.glb`  the 31 `KIT_*` blocks · **a colour per vertex** (layer `Col` in `island.blend`)
##   `island.glb`  `island` and `pads`   · **a colour per vertex** · white albedo the colours multiply
##
## ⚠ **BOTH CARRY COLOUR TODAY AND THE TEST BELOW STILL HAS TO RUN.** Until 2026-09-03 `pieces.glb` was
## ten dead parts with **no colour attribute at all** and one flat stone albedo, and that is what this
## switch was written for. A `.glb` dropped in here with no colours would still be handed a switch that
## multiplies its albedo by nothing, so the test stays.
## ⚠⚠ **THE `KIT_*` BLOCKS CARRY NO MATERIAL IN `island.blend`.** `_apply_outline` and the colour switch
## below both reach for `surface_get_material(i)` and both skip a surface that has none, so **whether
## the kit shows an outline here depends on what the export gave it.** If a block comes up flat and
## un-outlined, that is this, and it is the export to fix — not the viewer.
##
## The game turns `vertex_color_use_as_albedo` on for the island and **deliberately not** for anything
## without colours — `field_view` carries the bug report for the day it was turned on for the buildings
## and their walls came out in wedges. ⇒ **This viewer does the same test per file**, so a piece that
## has no colours is not handed a switch that would multiply its albedo by nothing.
var _vertex_coloured := false

## ⚠ **A block is 2x2 조각** — `Rules.BLOCK_TILES` = 2, and every `KIT_*` object in `island.blend` spans
## ±1.0 with a coastal skirt out to ±1.25. So the single-block view is framed on 2 tiles plus air.
## Framing on the mesh's own AABB instead would make a tall block look the same size as a flat one,
## which is exactly the comparison being made.
## ⚠⚠ **`ROW_VIEW_TILES` WAS CHOSEN FOR TEN BLOCKS AND THE KIT IS 31.** Ten at a 2.6 span needed 31
## tiles; 31 blocks need about 81, so `Tab` now frames roughly the middle twelve and the rest stand off
## the sides. **The wheel still zooms out to 60** — which is not enough either. Left as it is on purpose:
## this is a number to move, not a bug to hunt.
const PIECE_TILES := 2.0
const ONE_VIEW_TILES := 4.2
const ROW_VIEW_TILES := 31.0
const ROW_GAP_TILES := 0.6

var _world: Node3D = null
var _cam: Camera3D = null
var _sun: DirectionalLight3D = null
var _sea: MeshInstance3D = null
var _holder: Node3D = null
var _label: Label = null

var _pieces: Array[Node3D] = []
var _names: Array[String] = []
var _index := 0
var _row := false
var _outline_on := true

var _yaw := Look.CAM_YAW_DEG
var _pitch := Look.CAM_PITCH_DEG
var _view_tiles := ONE_VIEW_TILES
var _turning := false
var _turn_from := Vector2.ZERO

## ⚠⚠ **WHERE THE CAMERA LOOKS, AND IT IS NOT ALWAYS THE ORIGIN.** A single piece is two tiles across
## and needs no pan; **the baked island is twenty**, and the thing worth looking at on it — the stair —
## is nowhere near its middle. Without this the island can only be judged from orbit, which is the
## distance at which every version of it has looked acceptable.
var _focus := Vector3.ZERO
var _panning := false
var _pan_from := Vector2.ZERO


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("piece_viewer: --headless 로는 볼 것이 없다. 창을 띄워서 돌려라")
		quit(1)
		return
	var cli := OS.get_cmdline_user_args()
	var path := GLB
	var at := ""
	for i in cli.size():
		if cli[i] == "--glb" and i + 1 < cli.size():
			path = cli[i + 1]
		elif cli[i] == "--at" and i + 1 < cli.size():
			at = cli[i + 1]
		elif cli[i] == "--zoom" and i + 1 < cli.size():
			_view_tiles = float(cli[i + 1])
	if not _load_pieces(path):
		quit(1)
		return
	_build_world()
	_build_label()
	_wire_input()
	_show()
	if at != "":
		var xz := at.split(",")
		if xz.size() == 2:
			_focus = Vector3(float(xz[0]), 0.0, float(xz[1]))
			_place_camera()
	# ⚠ **`--shot1` saves exactly what `--at` and `--zoom` framed and quits.** It is the only
	# fire-and-quit path left; `--shot`, which walked every mesh instead and therefore threw the aim
	# away, was deleted 2026-08-27 — see the tombstone below `_zoom`.
	# ⚠ **`"--shot1" in cli` is an exact array-element test, not a prefix test**, which is why the two
	# flags could sit here side by side without `--shot` swallowing `--shot1`. Keep it exact if a second
	# shot flag is ever added back.
	if "--shot1" in cli:
		_shoot_one(at)


## Every top-level child of the baked scene is one block, in the order the export laid them down.
## ⚠ **The order is the file's and is not re-sorted here.** The kit's names carry it — `KIT_<level>_<kind>_<n>`,
## with `<n>` running 0..30 across the whole kit — so the label under a block says which one it is and a
## viewer that re-sorted them would say something else. See the Blender manual for the counts.
func _load_pieces(path: String) -> bool:
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		# ⚠ **`pieces.glb` CAN be re-baked** — export the 31 `KIT_*` objects out of `blend/island.blend`
		# again; the Blender manual carries the loop. (This said 「there is no way to re-bake this
		# file」 while it pointed at ten dead parts, and that stopped being true on 2026-09-03.)
		push_error("piece_viewer: %s 를 못 읽었다. blend/island.blend 의 KIT_* 를 다시 구워라 — 섬을 보려면 `-- --glb res://assets/terrain/island.glb`" % path)
		return false
	var baked := packed.instantiate()
	for child in baked.get_children():
		if child is MeshInstance3D:
			var piece := child as MeshInstance3D
			baked.remove_child(piece)
			# ⚠ **The owner has to go with the parent.** A node lifted out of an imported scene still
			# points at that scene as its owner, and re-parenting it then barks 「will make owner
			# inconsistent」 on stderr. This repo counts undeclared stderr as a failure, so it is
			# cleared here rather than tolerated.
			piece.owner = null
			# ⚠⚠ **CLEARED BECAUSE A BAKE THAT LAYS THE BLOCKS OUT SIDEWAYS AIMS THIS VIEWER AT
			# EMPTY SEA.** The old ten-part `pieces.glb` was exported as a row, so a part arrived standing
			# at z = 3.6 and the first run of this file photographed water. **The 31 `KIT_*` blocks all sit
			# at the ORIGIN in `island.blend`**, so today this line is a no-op — and it stays, because it
			# is one line and the failure it stops is silent.
			# ⇒ **The transform is cleared and the block is centred on its own AABB below.**
			piece.transform = Transform3D.IDENTITY
			_pieces.append(piece)
			_names.append(piece.name)
	if _pieces.is_empty():
		push_error("piece_viewer: %s 안에 메시가 없다" % path)
		return false
	# Asked of the FIRST mesh's arrays, which is where the answer actually is — not of the material's
	# switch, which is off in both files as they come out of Blender.
	var first: Mesh = (_pieces[0] as MeshInstance3D).mesh
	var arrays: Array = first.surface_get_arrays(0)
	_vertex_coloured = arrays.size() > Mesh.ARRAY_COLOR and arrays[Mesh.ARRAY_COLOR] != null
	if _vertex_coloured:
		for piece in _pieces:
			var mesh: Mesh = (piece as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				var sm := mesh.surface_get_material(i) as StandardMaterial3D
				if sm != null:
					sm.vertex_color_use_as_albedo = true
	return true


func _build_world() -> void:
	_world = Node3D.new()
	root.add_child(_world)

	# ⚠⚠ **THE SUN IS COPIED FROM `field_view._build_world`, LINE FOR LINE.** Every one of these five
	# lines was chosen against a measurement written up in `how-nets-lie` or in the decision
	# log — one sun and no fill, one shadow split and not four, the normal bias that killed the acne.
	# **Retuning any of them here would make this viewer lie about the game.**
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(Look.SUN_PITCH_DEG, Look.SUN_YAW_DEG, 0.0)
	_sun.light_energy = Look.SUN_ENERGY
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = Look.SUN_SHADOW_DIST_TILES
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.shadow_normal_bias = Look.SUN_SHADOW_NORMAL_BIAS
	_world.add_child(_sun)

	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Look.COL_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Look.COL_AMBIENT
	e.ambient_light_energy = Look.AMBIENT_ENERGY
	var env := WorldEnvironment.new()
	env.environment = e
	_world.add_child(env)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.far = Look.CAM_FAR_TILES
	_world.add_child(_cam)

	# ⚠ **A flat sea, and it is NOT the game's water shader.** The shader reads a coastline the baked
	# island exports and a lone block has none, so it would draw a white rim round nothing. This is a
	# plain plane at the waterline, there to say which way is down and where a block's coastal skirt ends
	# — the wave and the foam are judged on the island, not here.
	_sea = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	_sea.mesh = plane
	var water := StandardMaterial3D.new()
	# `COL_WATER` is the trough tone of the game's sea (`COL_WATER_CREST` is the other), and the
	# roughness is the one the water shader settles at. Flat, because the ripple is not the subject.
	water.albedo_color = Look.COL_WATER
	water.roughness = 0.74
	_sea.material_override = water
	_sea.position = Vector3(0.0, Look.SEA_DROP_TILES * -1.0, 0.0)
	_world.add_child(_sea)

	_holder = Node3D.new()
	_world.add_child(_holder)


func _build_label() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24.0, 18.0)
	_label.add_theme_font_size_override("font_size", 22)  # was Look.HUD_FONT_SIZE_PX, deleted 2026-08-29 with the HUD
	_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.90))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_label)


## Puts the current selection under the camera. **Rebuilt on every change rather than hidden and
## shown**, because the outline is a `next_pass` on a SHARED material out of the imported scene: a
## piece left in the tree keeps its shell, and toggling the outline would then apply to some pieces
## and not others depending on which had been visited.
func _show() -> void:
	# ⚠⚠ **THE PIECE IS TAKEN OUT OF ITS OLD SLOT BEFORE THE SLOT IS FREED, AND BOTH HALVES MATTER.**
	# Removing the slot alone leaves the piece parented to a node that is no longer in the tree, and
	# the next `add_child` then fails with 「already has a parent」 — **every piece after the first
	# frame silently failed to appear and the shots came back as empty sea.** Freeing the slot without
	# detaching first would take the whole kit down with it, and they are the only copy there is.
	for piece in _pieces:
		var parent := piece.get_parent()
		if parent != null:
			parent.remove_child(piece)
	for child in _holder.get_children():
		_holder.remove_child(child)
		child.queue_free()
	if _row:
		var span := PIECE_TILES + ROW_GAP_TILES
		var left := -0.5 * (float(_pieces.size()) - 1.0) * span
		for i in _pieces.size():
			var slot := Node3D.new()
			slot.position = _centring(_pieces[i]) + Vector3(left + float(i) * span, 0.0, 0.0)
			slot.add_child(_pieces[i])
			_holder.add_child(slot)
	else:
		var slot := Node3D.new()
		slot.position = _centring(_pieces[_index])
		slot.add_child(_pieces[_index])
		_holder.add_child(slot)
		# ⚠ **A mesh wider than a piece pulls the frame open to fit it.** `--glb island.glb` hands this
		# viewer ONE mesh twenty tiles across, and framing that on `ONE_VIEW_TILES` photographs a patch
		# of grass. The zoom keys still override it — this only sets where the view starts.
		var wide := _widest(_pieces[_index])
		if wide > PIECE_TILES and is_equal_approx(_view_tiles, ONE_VIEW_TILES):
			_view_tiles = wide * 1.25
	_apply_outline()
	_place_camera()
	_write_label()


## How far a block has to be shifted for its own middle to sit on the origin.
## ⚠ **Sideways only — the height is left alone.** Centring y as well would put every block's waist on
## the waterline, and **where a block sits against the water is half of what is being judged**: a level 0
## block spanning z -0.12 .. 0.21 and a level 2 block spanning -0.12 .. 1.21 are the same picture only
## if the sea stays where it is.
## The wider of a mesh's two ground axes, in tiles. Turning is around the vertical, so the frame has to
## hold the LONGER of the two or a 90° turn walks the subject off the side of the screen.
func _widest(piece: MeshInstance3D) -> float:
	var box := piece.mesh.get_aabb()
	return maxf(box.size.x, box.size.z)


func _centring(piece: MeshInstance3D) -> Vector3:
	var box := piece.mesh.get_aabb()
	var mid := box.position + box.size * 0.5
	return Vector3(-mid.x, 0.0, -mid.z)


## The field's outline pass, copied from `field_view._outline` — the mesh inside out, grown along its
## normals, unshaded, front faces culled, drawn under the real one.
## ⚠ **`O` clears it by setting `next_pass` back to null**, which is why the guard below re-applies
## rather than skipping: a piece that has been toggled off has no shell to be found.
func _apply_outline() -> void:
	for piece in _pieces:
		var mi := piece as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var sm := mesh.surface_get_material(i) as StandardMaterial3D
			if sm == null:
				continue
			if not _outline_on:
				sm.next_pass = null
				continue
			if sm.next_pass != null:
				continue
			var shell := StandardMaterial3D.new()
			shell.albedo_color = Look.COL_OUTLINE
			shell.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			shell.cull_mode = BaseMaterial3D.CULL_FRONT
			shell.grow = true
			shell.grow_amount = Look.OUTLINE_GROW
			sm.next_pass = shell


## ⚠ **`size` is the visible WIDTH in tiles** — `KEEP_WIDTH` above is what makes that true, and it is
## the same convention `field_view` uses so the zoom numbers mean the same thing in both.
func _place_camera() -> void:
	_cam.size = _view_tiles
	var back := 40.0
	var basis := Basis.from_euler(Vector3(deg_to_rad(-_pitch), deg_to_rad(_yaw), 0.0))
	_cam.transform = Transform3D(basis, _focus + basis * Vector3(0.0, 0.0, back))


func _write_label() -> void:
	var head := ""
	if _row:
		head = "블록 %d 개 나란히 — %s" % [_pieces.size(), ", ".join(_names)]
	else:
		head = "%d / %d   %s" % [_index + 1, _pieces.size(), _names[_index]]
	_label.text = "%s\n돌리기 오른쪽드래그·Q E   기울기 R F   확대 휠   외곽선 O (%s)   바다 G (%s)   한장/전체 Tab   저장 S   끝 Esc" % [
		head,
		"켜짐" if _outline_on else "꺼짐",
		"켜짐" if _sea.visible else "꺼짐",
	]


## ⚠⚠ **`root.window_input` AND NOT `_unhandled_input`.** A script run with `--script` IS the
## `SceneTree`, and a `SceneTree` has no input callback; `root` is the Window, and a Window emits every
## event it receives on this signal. **This is the whole input table of the viewer.**
func _wire_input() -> void:
	root.window_input.connect(_on_input)


func _on_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		_on_key(event as InputEventKey)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_RIGHT:
			_turning = click.pressed
			_turn_from = click.position
		elif click.button_index == MOUSE_BUTTON_LEFT:
			_panning = click.pressed
			_pan_from = click.position
		elif click.button_index == MOUSE_BUTTON_WHEEL_UP and click.pressed:
			_zoom(1.0 / 1.12)
		elif click.button_index == MOUSE_BUTTON_WHEEL_DOWN and click.pressed:
			_zoom(1.12)
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _turning:
			_yaw += (motion.position.x - _turn_from.x) * Look.CAM_YAW_PER_PX_DEG
			_turn_from = motion.position
			_place_camera()
			return
		if _panning:
			# ⚠ **Dragged in the camera's own ground plane, not in world x/z.** Panning along world axes
			# after the view has been turned sends the island sideways-and-backwards under the hand, and
			# the first thing anyone does on this viewer is turn it.
			var d := motion.position - _pan_from
			_pan_from = motion.position
			var per_px := _view_tiles / float(root.size.x)
			var right := _cam.global_transform.basis.x
			var up := _cam.global_transform.basis.y
			_focus -= right * d.x * per_px
			_focus += up * d.y * per_px
			_place_camera()


func _on_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_ESCAPE:
			quit()
		KEY_LEFT, KEY_A:
			_step(-1)
		KEY_RIGHT, KEY_D:
			_step(1)
		KEY_TAB:
			_row = not _row
			_view_tiles = ROW_VIEW_TILES if _row else ONE_VIEW_TILES
			_show()
		KEY_Q:
			_yaw -= Look.CAM_YAW_STEP_DEG
			_place_camera()
		KEY_E:
			_yaw += Look.CAM_YAW_STEP_DEG
			_place_camera()
		KEY_R:
			_tilt(Look.CAM_PITCH_STEP_DEG)
		KEY_F:
			_tilt(-Look.CAM_PITCH_STEP_DEG)
		KEY_EQUAL, KEY_KP_ADD:
			_zoom(1.0 / 1.12)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom(1.12)
		KEY_O:
			_outline_on = not _outline_on
			_apply_outline()
			_write_label()
		KEY_G:
			_sea.visible = not _sea.visible
			_write_label()
		KEY_H:
			_focus = Vector3.ZERO
			_place_camera()
		KEY_S:
			_save_shot()


## ⚠ **Wraps rather than clamping.** Thirty-one blocks judged one after another is a loop the hand
## does dozens of times; a clamp at either end makes the last block feel like a wall.
func _step(by: int) -> void:
	if _row:
		_row = false
		_view_tiles = ONE_VIEW_TILES
	_index = wrapi(_index + by, 0, _pieces.size())
	_focus = Vector3.ZERO
	_show()


func _tilt(by: float) -> void:
	_pitch = clampf(_pitch + by, Look.CAM_PITCH_MIN_DEG, Look.CAM_PITCH_MAX_DEG)
	_place_camera()


func _zoom(by: float) -> void:
	_view_tiles = clampf(_view_tiles * by, 1.2, 60.0)
	_place_camera()


## ⚠⚠ **TOMBSTONE — `_shoot_all()` and its `--shot` flag stood here and were deleted 2026-08-27.**
##
## **What it did.** Given `-- --shot`, it drove the viewer with a hand made of code: for each mesh in the
## loaded glb it framed the piece, photographed it twice — once at the game's own yaw with the sea plane
## ON, once turned 55° with the sea OFF — then switched to the all-in-a-row view, saved one
## last frame, printed a count and quit. Everything it saved went to `SHOT_DIR`, the same folder `S`
## still writes to.
##
## **Why it was killed.** Its only entry was its own CLI flag; nothing in `src/`, `tests/` or any script
## invoked it, and no round ever consumed its output folder. It was also aimed at a file that had gone
## dead: it was written for the ten parts of the old `pieces.glb`, whose baking script was deleted
## 2026-08-27, and the live target `island.glb` holds one island mesh, so "walk every mesh from two
## angles and then line them up in a row" degenerated to one piece photographed twice plus a row of one.
## `--shot1` does that job properly and is the flag the Blender manual's loop carries.
## ⚠⚠ **THE PREMISE MOVED BACK ON 2026-09-03**: `pieces.glb` is now the 31 `KIT_*` blocks out of
## `blend/island.blend`, and it IS re-bakeable. **A sheet of 31 blocks is a real thing to want again** —
## this tombstone is kept as the design of the one that would be written, not as a reason not to.
##
## **What it knew, and it outlives the code.** ⚠⚠ **THE SECOND SHOT TURNED THE SEA OFF, AND THAT WAS
## NOT A PREFERENCE.** The old kit's two wall parts hung from the waterline DOWNWARDS — `wall_coast` ran
## from y -0.62 to +0.02 — so an opaque sea plane hid all but the top 0.05 of them, and the first run of
## this mode photographed **a white line**. ⚠ **Those two parts are gone**; what replaces them is every
## `KIT_*` block's coastal skirt, which reaches out to ±1.25 and down to z -0.12 — **under the water
## again.** ⇒ **`G` (sea off) is not a garnish. Any judgement of how a block meets the water is taken
## with the sea off, whatever takes the picture.**
##
## ⚠ **Why two angles and not one**: the shore wall and the slightly-tilted corner are the two things
## this repo kept failing on, and neither of them shows from straight ahead. The 55° turn existed for
## the corner. **This is the argument for `Q`/`E` still being hand controls** — turning is how a corner
## is judged, and a still picture cannot be turned.
##
## ⚠ **Why it was added at all** (2026-08-26): two rounds of judgement never happened because
## the user was on mobile and could not see the screen, so a picture that survives a phone was worth
## having. **It was never a substitute for the window**, and its own header said so.
##
## **`_shoot_one()` below is what remains of this idea**, and `_settle()` is shared with it — neither is
## orphaned by this deletion.


## One frame, from three yaws, at whatever `--at` / `--zoom` aimed at. Three because a stair read from a
## single angle is the thing this repo has already got wrong twice.
func _shoot_one(tag: String) -> void:
	var stem := tag.replace(",", "_").replace("-", "m")
	for turn in [0.0, 40.0, -40.0]:
		_yaw = Look.CAM_YAW_DEG + turn
		_place_camera()
		await _settle(4)
		await _save_shot("at%s_y%d" % [stem, int(turn)])
	print("piece_viewer: 한 자리 · 각도 셋")
	quit()


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


## ⚠ **The label is hidden for the shot and put back afterwards.** A judgement about colour taken off
## a picture with white text burnt into the corner is a judgement about the text.
func _save_shot(tag: String = "") -> void:
	_label.visible = false
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var stem := "row" if _row else _names[_index]
	if tag != "":
		stem = "%s_%s" % [stem, tag]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var path := "%s/%s.png" % [SHOT_DIR, stem]
	if img.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("piece_viewer: %s 를 못 썼다" % path)
	else:
		print("piece_viewer: %s" % path)
	_label.visible = true
