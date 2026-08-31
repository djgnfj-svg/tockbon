# **Photographs the island under ONE palette — the one named in `current.json`.**
#
# ⚠⚠ **This does NOT touch a single colour that Blender bakes.** The ground, the cliff, the stair and
# the buildings are already wearing the palette when this runs, because `bake_all.py` rewrote the
# constants in `tools/blender/*.py` and re-baked before launching it. **What is left here is only what
# Blender does not make**: the sky, the ambient, the sun, the sea shader and the outline ink.
#
# ⚠ **The runtime recolour shader this replaced is deleted.** It swapped baked tones on the way to the
# screen so seven palettes could be shot in one run, and it was the wrong trade twice over: four
# separate bugs to get the instrument honest, and the picture was still a shifted approximation of the
# palette rather than the palette. See `NOTES.md`.
#
# ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
# black with no error at all.
#
# Run:  Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/palette/shoot_one.gd
extends SceneTree

const CURRENT := "res://.prototypes/palette/current.json"
const SHOT := "res://.prototypes/palette/out/%s.png"

var _game: Game = null
var _step := 0
var _wait := 0
var _p := {}


func _initialize() -> void:
	var f := FileAccess.open(CURRENT, FileAccess.READ)
	if f == null:
		push_error("shoot_one: current.json 이 없다 — bake_all.py 가 쓴다")
		quit(1)
		return
	_p = JSON.parse_string(f.get_as_text())
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)


func _col(key: String) -> Color:
	var a: Array = _p[key]
	return Color(float(a[0]), float(a[1]), float(a[2]))


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _wheel_up() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = Look.viewport_size_px() * 0.5
	return ev


## Walks the live tree and writes the parts of the palette Blender does not bake.
func _dress(n: Node) -> void:
	if n is WorldEnvironment:
		var e := (n as WorldEnvironment).environment
		e.background_color = _col("sky")
		e.ambient_light_color = _col("ambient")
		e.ambient_light_energy = float(_p["ambient_energy"])
	if n is DirectionalLight3D:
		(n as DirectionalLight3D).light_energy = float(_p["sun_energy"])
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var over := mi.material_override
		# The sea and the 판 both wear a ShaderMaterial the game put there. Only the sea has a `sea`
		# uniform, and that is what tells them apart without naming a node.
		if over is ShaderMaterial and (over as ShaderMaterial).get_shader_parameter("sea") != null:
			(over as ShaderMaterial).set_shader_parameter("sea", _col("water"))
			(over as ShaderMaterial).set_shader_parameter("foam", _col("foam"))
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				# ⚠ The outline is a `next_pass` shell on the imported material — buildings and props
				# have one, the island does not (it lost its rim on 2026-08-28).
				if m is StandardMaterial3D and (m as StandardMaterial3D).next_pass != null:
					var ink := (m as StandardMaterial3D).next_pass as StandardMaterial3D
					if ink != null:
						ink.albedo_color = _col("outline")
	for c in n.get_children():
		_dress(c)


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			# 시작하기 — the next screen is the island.
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			# Let the run settle so nothing is mid-spawn in the picture.
			for _i in 120:
				_game._process(1.0 / 60.0)
		2:
			# The angle and distance the island was last judged from.
			# ⚠ **Three E presses did this until 2026-08-31**, when the keyboard turn was deleted from
			# the shell. The camera is turned directly now.
			for _i in 3:
				_game.field_view.turn_by(Look.CAM_YAW_STEP_DEG)
		3:
			for _i in 12:
				_game._unhandled_input(_wheel_up())
		4:
			_dress(_game)
		5:
			# ⚠ **A frame after dressing, never the same one.** A material written and read back in one
			# frame catches the frame BEFORE it — which is the undressed island, silently.
			root.get_texture().get_image().save_png(
					ProjectSettings.globalize_path(SHOT % String(_p["name"])))
			print("[palette] %s" % _p["name"])
		_:
			return true
	_step += 1
	return false
