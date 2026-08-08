extends SceneTree
## Terrain baking — the headless version. The logic lives in `terrain_baker.gd` (shared with the editor version).
##
## Run: Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/bake_terrain.gd

const Baker := preload("res://tools/stage/terrain_baker.gd")


func _init() -> void:
	quit(0 if Baker.bake() else 1)
