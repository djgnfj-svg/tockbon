# THROWAWAY PROBE — not part of the game. Answers one question and is then deleted or kept as a
# prototype: **can the map be a 3D space while every beast stays a flat board that faces the camera?**
#
# Run:  godot --path . -s .scratch/cell-hook/prototypes/probe_3d.gd
# It writes three pngs next to itself and quits.
extends SceneTree

const SHOT_DIR := "res://.scratch/cell-hook/prototypes/"
const WOLF := "res://assets/beast/wolf_r.png"
const TILE := 1.0
const GRID := 16

var _cam: Camera3D
var _yaw := 0.0
var _shot := 0
var _frames := 0


func _initialize() -> void:
	root.size = Vector2i(960, 540)
	var world := Node3D.new()
	root.add_child(world)

	# --- the ground: one box per tile, height read off a hand-made bump map -----------------------
	# This is the "격자에 높이만 준다" the map already decided. No modelling, no mesh authoring —
	# the height is a number per tile and the code builds the box.
	var mat := StandardMaterial3D.new()
	for gy in GRID:
		for gx in GRID:
			var h := _height_at(gx, gy)
			var box := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(TILE, maxf(0.2, h), TILE)
			box.mesh = mesh
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.20, 0.32, 0.18) if h > 0.25 else Color(0.10, 0.22, 0.34)
			box.material_override = m
			box.position = Vector3(float(gx) - GRID * 0.5, maxf(0.2, h) * 0.5, float(gy) - GRID * 0.5)
			world.add_child(box)

	# --- the wolves: flat boards that always face the camera --------------------------------------
	var tex: Texture2D = load(WOLF)
	for k in 24:
		var s := Sprite3D.new()
		s.texture = tex
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.pixel_size = 0.022
		var gx := 3 + (k % 6) * 2
		var gy := 4 + (k / 6) * 2
		var h: float = maxf(0.2, _height_at(gx, gy))
		s.position = Vector3(float(gx) - GRID * 0.5, h + 0.45, float(gy) - GRID * 0.5)
		world.add_child(s)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -40.0, 0.0)
	sun.light_energy = 1.2
	world.add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.055, 0.055, 0.075)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.65)
	e.ambient_light_energy = 0.7
	env.environment = e
	world.add_child(env)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 18.0
	world.add_child(_cam)
	_place_camera()


func _height_at(gx: int, gy: int) -> float:
	# A hand-made island: a raised spine down the middle, a bump, water at the rim.
	var dx := float(gx) - GRID * 0.5
	var dy := float(gy) - GRID * 0.5
	var r := sqrt(dx * dx + dy * dy)
	if r > 6.5:
		return 0.0
	var h := 0.6 + (6.5 - r) * 0.18
	if gx > 8 and gy > 8:
		h += 0.9
	return h


func _place_camera() -> void:
	# **40 degrees, the angle the user picked by eye.** The camera orbits the island's centre; the
	# island itself never moves, which is the cheaper of the two ways written on 티켓 07.
	var pitch := deg_to_rad(40.0)
	var dist := 20.0
	var eye := Vector3(sin(_yaw) * cos(pitch), sin(pitch), cos(_yaw) * cos(pitch)) * dist
	_cam.look_at_from_position(eye, Vector3.ZERO, Vector3.UP)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(SHOT_DIR + "probe_3d_%d.png" % _shot))
	_shot += 1
	if _shot >= 3:
		return true
	_yaw += deg_to_rad(45.0)
	_place_camera()
	_frames = 0
	return false
