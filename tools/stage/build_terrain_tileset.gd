extends SceneTree
## 일회성 세팅 스크립트. `src/stage/terrain_tileset.tres`를 다시 만든다.
## 재질이 늘어나면(물 등) 이 스크립트에 타일을 추가하고 다시 돌린다 — 손으로 .tres를 고치지 마라.
##
## 실행: Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/build_terrain_tileset.gd

const Mat := preload("res://src/sim/cell_materials.gd")

## atlas 타일 좌표 ↔ 재질. `assets/stage/terrain_tiles.png`가 이 순서로 32px 정사각형을 이어붙인 것.
const TILES := [
	{"atlas": Vector2i(0, 0), "mat": Mat.STONE},
	{"atlas": Vector2i(1, 0), "mat": Mat.WOOD},
	{"atlas": Vector2i(2, 0), "mat": Mat.BEDROCK},
]


func _init() -> void:
	var tex := load("res://assets/stage/terrain_tiles.png") as Texture2D
	if tex == null:
		push_error("atlas 텍스처를 못 읽었다 — assets/stage/terrain_tiles.png")
		quit(1)
		return

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "material")
	tileset.set_custom_data_layer_type(0, TYPE_INT)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(32, 32)

	# 🔴 add_source가 먼저다 — TileData가 소속 TileSet을 알아야 custom data 계층을 찾는다.
	#  순서를 바꾸면 "Parameter tile_set is null" 로 조용히 실패한다(실측).
	tileset.add_source(atlas, 0)

	for entry in TILES:
		var coords: Vector2i = entry["atlas"]
		atlas.create_tile(coords)
		var data := atlas.get_tile_data(coords, 0)
		data.set_custom_data("material", int(entry["mat"]))

	var err := ResourceSaver.save(tileset, "res://src/stage/terrain_tileset.tres")
	if err != OK:
		push_error("TileSet 저장 실패 — 에러 코드 %d" % err)
		quit(1)
		return

	print("[build_terrain_tileset] 저장됨: src/stage/terrain_tileset.tres (타일 %d개)" % TILES.size())
	quit(0)
