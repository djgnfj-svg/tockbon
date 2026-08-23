# THROWAWAY PROBE — measures ONE thing: how many lines it takes to stand the REAL island up in 3D.
#
# **There is no tilemap and none is needed.** The islands are already hand-drawn text grids in
# `islands.gd` — `~` water · `H` harbour · `.` land · `/` ramp · `^` cliff · `B`/`C`/`L` spawns — and
# this reads that same text. Nothing new is authored; the legend gains a HEIGHT column and that is all.
#
# One MultiMesh, one draw call, one box per tile. 48 x 32 = 1536 boxes.
#
# Run:  godot --path . -s .scratch/cell-hook/prototypes/probe_terrain3d.gd
extends SceneTree

const SHOT := "res://.scratch/cell-hook/prototypes/probe_terrain3d_%d.png"
const TILE := 1.0

# The legend, with a height and a colour against each character. **This table is the whole port.**
const LEGEND := {
	"~": [0.15, Color(0.13, 0.26, 0.40)],
	"H": [0.15, Color(0.20, 0.36, 0.50)],
	".": [1.00, Color(0.28, 0.40, 0.24)],
	"/": [1.60, Color(0.42, 0.38, 0.24)],
	"^": [2.40, Color(0.34, 0.32, 0.30)],
	"B": [1.00, Color(0.34, 0.44, 0.24)],
	"C": [1.00, Color(0.34, 0.44, 0.24)],
	"L": [1.00, Color(0.34, 0.44, 0.24)],
}

var _cam: Camera3D
var _yaw := 0.0
var _shot := 0
var _frames := 0
var _w := 0
var _h := 0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)

	var rows: Array = Islands.rows_of(0)
	_h = rows.size()
	_w = String(rows[0]).length()

	var mesh := BoxMesh.new()
	mesh.size = Vector3(TILE, 1.0, TILE)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = _w * _h
	for ty in _h:
		var row := String(rows[ty])
		for tx in _w:
			var ch := row[tx] if tx < row.length() else "~"
			var e: Array = LEGEND.get(ch, LEGEND["~"])
			var hgt: float = e[0]
			var t := Transform3D(Basis().scaled(Vector3(1.0, hgt, 1.0)),
				Vector3(float(tx) - _w * 0.5, hgt * 0.5, float(ty) - _h * 0.5))
			var i := ty * _w + tx
			mm.set_instance_transform(i, t)
			mm.set_instance_color(i, e[1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	world.add_child(mmi)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 1.15
	world.add_child(sun)

	var e2 := Environment.new()
	e2.background_mode = Environment.BG_COLOR
	e2.background_color = Color(0.055, 0.055, 0.075)
	e2.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e2.ambient_light_color = Color(0.52, 0.58, 0.68)
	e2.ambient_light_energy = 0.75
	var env := WorldEnvironment.new()
	env.environment = e2
	world.add_child(env)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = float(_w) * 1.05
	world.add_child(_cam)
	_place_camera()


func _place_camera() -> void:
	var pitch := deg_to_rad(40.0)
	var eye := Vector3(sin(_yaw) * cos(pitch), sin(pitch), cos(_yaw) * cos(pitch)) * 60.0
	_cam.look_at_from_position(eye, Vector3.ZERO, Vector3.UP)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	root.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(SHOT % _shot))
	_shot += 1
	if _shot >= 2:
		print("tiles=%d (%d x %d)" % [_w * _h, _w, _h])
		return true
	_yaw += deg_to_rad(35.0)
	_place_camera()
	_frames = 0
	return false
