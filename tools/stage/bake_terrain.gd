extends SceneTree
## 지형 굽기 — 헤드리스판. 로직은 `terrain_baker.gd`에 있다(에디터판과 공유).
##
## 실행: Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/bake_terrain.gd

const Baker := preload("res://tools/stage/terrain_baker.gd")


func _init() -> void:
	quit(0 if Baker.bake() else 1)
