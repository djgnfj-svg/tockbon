# THROWAWAY PROBE — measures ONE thing: does a Node3D subtree parented under a Node2D render at all,
# and do 2D canvas items still draw ON TOP of it? The whole 3D port hangs on this: `Game` is a Node2D
# and `FieldView` is its first child, so if 3D does not survive that parent the port has to restructure
# the shell as well as the view.
extends SceneTree

const SHOT := "res://.scratch/cell-hook/prototypes/probe_3d_under_2d.png"

var _frames := 0


class Canvas2D:
	extends Node2D

	func _draw() -> void:
		# A 2D bar across the bottom. If the 3D box shows AND this bar is over it, both halves hold.
		draw_rect(Rect2(0.0, 600.0, 1280.0, 120.0), Color(0.9, 0.2, 0.3))


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var two := Canvas2D.new()
	root.add_child(two)

	var world := Node3D.new()
	two.add_child(world)          # ← the whole question: Node3D under Node2D

	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 0.4)
	box.material_override = mat
	world.add_child(box)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	world.add_child(sun)

	var cam := Camera3D.new()
	world.add_child(cam)
	cam.look_at_from_position(Vector3(3.0, 3.0, 4.0), Vector3.ZERO, Vector3.UP)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT))
	print("saved")
	return true
