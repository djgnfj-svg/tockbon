extends SceneTree
## 일회성 마이그레이션. 지금 손으로 쓴 `Stage.MAP`(ASCII)을 TileMapLayer "Terrain"에 그대로 옮겨 심는다.
## 딱 한 번만 돈다 — Terrain 노드가 이미 있으면 거부한다. 이후 지형은 에디터에서 그리고
## `bake_terrain.gd`로 되읽는다.
##
## 실행: Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/paint_terrain_from_map.gd

const StageScript := preload("res://src/stage/stage.gd")

## atlas 타일 좌표 ↔ 재질 id. `build_terrain_tileset.gd`의 TILES와 짝이 맞아야 한다.
const ATLAS_BY_MAT := {
	1: Vector2i(0, 0),  # Mat.STONE
	2: Vector2i(1, 0),  # Mat.WOOD
}


func _init() -> void:
	var packed: PackedScene = load("res://src/stage/stage.tscn")
	var root := packed.instantiate()

	if root.has_node("Terrain"):
		push_error("Terrain 노드가 이미 있다 — 이 스크립트는 처음 한 번만 돈다")
		quit(1)
		return

	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = load("res://src/stage/terrain_tileset.tres")

	var painted := 0
	for ty in StageScript.MAP.size():
		var row: String = StageScript.MAP[ty]
		for tx in row.length():
			var ch := row[tx]
			if not StageScript.MAP_CHARS.has(ch):
				continue
			var mat := int(StageScript.MAP_CHARS[ch])
			terrain.set_cell(Vector2i(tx, ty), 0, ATLAS_BY_MAT[mat])
			painted += 1

	root.add_child(terrain)
	terrain.owner = root

	var new_packed := PackedScene.new()
	var err := new_packed.pack(root)
	if err != OK:
		push_error("씬 pack 실패 — 에러 코드 %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(new_packed, "res://src/stage/stage.tscn")
	if err != OK:
		push_error("씬 저장 실패 — 에러 코드 %d" % err)
		quit(1)
		return

	print("[paint_terrain_from_map] Terrain에 타일 %d개 심음, stage.tscn 저장됨" % painted)
	quit(0)
