extends RefCounted
## 지형 굽기의 실제 로직. `bake_terrain.gd`(헤드리스)와 `bake_terrain_editor.gd`(에디터 안) 둘 다
## 이 하나를 부른다 — 로직을 두 곳에 베끼면 갈라진다.
##
## `stage.tscn`의 Terrain(TileMapLayer)을 읽어 `src/stage/terrain_map_generated.gd`를 다시 쓴다.
## 🔴 `Stage.MAP`·`Stage.MAP_CHARS`·`Stage.MAP_W`·`Stage.MAP_H`·`Stage.build_terrain_into()`는
## 안 건드린다 — 전부 이 산출물을 그대로 재수출한다. `net_tables.gd`의 `_wood_clumps`·`_stage_map`이
## 이걸 직접 재기 때문에, 굽기를 새 이름으로 만들면 그 그물이 "실제로 도는 지형"이 아니라 죽은
## 곁가지를 재게 된다.
##
## 🔴🔴 **그려진 영역을 `TileMapLayer.get_used_rect()`로 스스로 찾는다** — 원점(0,0)에서 고정폭을
## 읽지 않는다. ⚠ **실측으로 이걸 배웠다**: 사용자가 312×126타일을 그렸는데 그중 (0,0)~(63,35)
## 바깥은 옛 방식(고정창)이 조용히 건너뛰어 구운 결과가 통째로 빈칸이었다. `get_used_rect()`는
## 음수 좌표(원점 위·왼쪽으로 그린 부분)도 잡고, 그 좌표를 0부터 시작하도록 옮겨 담는다.
##
## 🔴 **그래도 상한은 있다** — 실제로 도는 시뮬 격자(`CellGrid.W`·`H`)가 셀 단위로 고정 크기다.
## 그린 영역이 그보다 크면 **조용히 잘리는 대신 여기서 짖는다** — 잘려서 구멍 난 지형보다
## 「못 구웠다」가 낫다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

## 재질 id ↔ ASCII 글자. `build_terrain_tileset.gd`의 TILES와 한 몸으로 움직인다 — 재질을 늘리면 여기도.
const CHAR_BY_MAT := {
	Mat.STONE: "#",
	Mat.WOOD: "=",
	Mat.BEDROCK: "B",
}


## 성공하면 true. 실패하면 `push_error`로 짖고 false — 호출자가 종료 코드로 바꾼다.
static func bake() -> bool:
	var packed: PackedScene = load("res://src/stage/stage.tscn")
	var root := packed.instantiate()
	var terrain := root.get_node_or_null("Terrain") as TileMapLayer
	if terrain == null:
		push_error("Terrain(TileMapLayer) 노드가 없다 — stage.tscn에 먼저 세워라")
		return false

	var rect := terrain.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		push_error("Terrain에 그려진 타일이 없다 — 굽기 전에 그려라")
		return false

	var map_w := rect.size.x
	var map_h := rect.size.y
	var cap_w := CellGrid.W / Tuning.TILE_CELLS
	var cap_h := CellGrid.H / Tuning.TILE_CELLS
	if map_w > cap_w or map_h > cap_h:
		push_error(
			("그린 영역(%d×%d타일)이 격자 용량(%d×%d타일)을 넘는다 — " +
			"CellGrid.W·H·X_SHIFT를 키우고 다시 구워라") % [map_w, map_h, cap_w, cap_h])
		return false

	var rows: Array[String] = []
	for ty in map_h:
		var chars := PackedStringArray()
		chars.resize(map_w)
		for tx in map_w:
			var cell := Vector2i(rect.position.x + tx, rect.position.y + ty)
			var data := terrain.get_cell_tile_data(cell)
			if data == null:
				chars[tx] = "."
				continue
			var mat: int = data.get_custom_data("material")
			if not CHAR_BY_MAT.has(mat):
				push_error("%s 재질 id %d에 대응하는 글자가 없다 — CHAR_BY_MAT을 늘려라" % [cell, mat])
				return false
			chars[tx] = CHAR_BY_MAT[mat]
		rows.append("".join(chars))

	var out := "extends RefCounted\n"
	out += "## 자동 생성 — 손으로 고치지 마라.\n"
	out += "## 지형을 고치려면 Godot 에디터에서 stage.tscn의 Terrain(TileMapLayer)을 다시 그리고\n"
	out += "## 구워라(스크립트 에디터에서 `bake_terrain_editor.gd` 열고 실행, 또는 헤드리스 `bake_terrain.gd`).\n"
	out += "## MAP_W·MAP_H는 그린 영역의 실제 크기다(`TileMapLayer.get_used_rect()`) — 손으로 안 맞춘다.\n"
	out += "## 재질을 새로 추가했으면 `build_terrain_tileset.gd`·`terrain_baker.gd`의 표도 같이 늘려야 한다.\n\n"
	out += "const Mat := preload(\"res://src/sim/cell_materials.gd\")\n\n"
	out += "const MAP_W := %d\n" % map_w
	out += "const MAP_H := %d\n\n" % map_h
	out += "const MAP: Array[String] = [\n"
	for row in rows:
		out += "\t\"%s\",\n" % row
	out += "]\n\n"
	# 🔴🔴 **`CHAR_BY_MAT`에서 파생한다. 리터럴로 박지 마라.**
	#  2026-08-07까지 이 줄이 `{"#": Mat.STONE, "=": Mat.WOOD, "B": Mat.BEDROCK}` 문자열이었고,
	#  그러면 **`CHAR_BY_MAT`을 늘리고 여기를 안 늘리는 순간 조용히 갈라진다** — 구운 맵에는
	#  새 글자가 들어 있는데 게임이 그 글자를 모른다. `Stage.MAP_CHARS.has(ch)`가 false라
	#  **그 칸이 에러 없이 빈칸이 된다.** 물이 들어오는 날 정확히 여기서 났을 것이다.
	# ⚠ 이름은 `Mat.<상수>`로 뽑아야 한다 — 숫자를 박으면 재료 id를 옮기는 날 또 갈라진다.
	var name_by_mat := {Mat.STONE: "STONE", Mat.WOOD: "WOOD", Mat.BEDROCK: "BEDROCK"}
	var pairs := PackedStringArray()
	for mat: int in CHAR_BY_MAT:
		if not name_by_mat.has(mat):
			# 재료를 늘리고 위 표를 안 늘리면 여기서 짖는다. 조용히 숫자로 뱉지 않는다 —
			# 그러면 생성 파일이 재료 id를 하드코딩한 채로 살아남는다.
			push_error("재질 id %d의 상수 이름을 모른다 — terrain_baker의 name_by_mat을 늘려라" % mat)
			return false
		pairs.append("\"%s\": Mat.%s" % [CHAR_BY_MAT[mat], name_by_mat[mat]])
	out += "const MAP_CHARS: Dictionary = {%s}\n" % ", ".join(pairs)

	var f := FileAccess.open("res://src/stage/terrain_map_generated.gd", FileAccess.WRITE)
	if f == null:
		push_error("생성 파일을 못 열었다 — 에러 코드 %d" % FileAccess.get_open_error())
		return false
	f.store_string(out)
	f.close()

	print("[terrain_baker] terrain_map_generated.gd 다시 씀 (%d×%d타일, 원점 옮김 %s)" % [
		map_w, map_h, -rect.position])
	return true
