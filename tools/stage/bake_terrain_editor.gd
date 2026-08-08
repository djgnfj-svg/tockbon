@tool
extends EditorScript
## Terrain baking — the version run inside the editor. The logic lives in `terrain_baker.gd` (shared with the headless version).
##
## How to use: open this file in the script editor and press "Run" (the play button, Ctrl+Shift+X) at the top right.
## Paint the Terrain and **save the scene (Ctrl+S) first** — unsaved state is not read.

const Baker := preload("res://tools/stage/terrain_baker.gd")


func _run() -> void:
	Baker.bake()
