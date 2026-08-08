extends SceneTree
## Plants an ASCII map into the TileMapLayer "Terrain" of `stage.tscn`. **The inverse of baking.**
##
## **This direction is what makes it possible to build a map from something other than a human**
##  (decided by the user: "the user designs the tiles and Claude plants them"). With baking only, editor brush work
##  is the sole input — ASCII can be produced, but **there is no way for a human to look at it and refine it.**
##
## ```
## ASCII file  ->  [this script]  ->  Terrain layer  ->  refine in the editor  ->  [bake]  ->  game
## ```
##
## Run:
##   Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/paint_terrain_from_map.gd -- <mapfile>
##   ... -- --from-generated        re-plants the currently baked map (for the round-trip check)
##
## **With no argument it does nothing.** It used to be "one-shot, runs only when Terrain is empty", and
##  the moment that lock was opened, **running it by mistake overwrites what the user painted.** Forcing an
##  argument is the safety that stands in its place.
##
## == **The scene is not re-saved — only the one `tile_map_data` line is swapped** ======
##  **Burned three times here.** Rewriting the whole scene with `ResourceSaver.save(packed_scene)` makes all of
##  the following happen **silently** in headless:
##
##   (1) **uids vanish wholesale** — nine lines of `[gd_scene ... uid=]` and `[ext_resource ... uid=]`.
##     Headless has no uid cache. Nobody references this scene by uid today, so **the game does not break**,
##     and the editor reissues them next open, giving **a scene diff on every plant**
##   (2) **Node properties disappear** — swapping in a new `TileMapLayer` loses `position = Vector2(0, 1)` and
##     `unique_id`. **Baking reads only cell coordinates** (`get_used_rect()`), so
##     **the round-trip check stays green** while the properties evaporate
##   (3) **`tile_map_data` doubles** — neither `clear()` nor `tile_map_data = PackedByteArray()` removes
##     cleared cells; they stay as **`source_id = -1` records** with new cells appended (measured: 21,048 -> 41,816 chars).
##     The game runs fine and baking is correct, so it is **bloat that nobody barks about**
##
##  => **Build the cell data in memory only and replace that one line as text.** The rest of the scene is untouched.
## ==================================================================

const Baker := preload("res://tools/stage/terrain_baker.gd")

const TILESET_PATH := "res://src/stage/terrain_tileset.tres"
const SCENE_PATH := "res://src/stage/stage.tscn"
const DATA_PREFIX := "tile_map_data = PackedByteArray(\""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("사용법: --script tools/stage/paint_terrain_from_map.gd -- <맵파일 | --from-generated>")
		print("  인자 없이는 안 돈다 — 실수로 돌리면 그려 둔 Terrain을 덮는다.")
		quit(1)
		return

	var rows := _load_rows(args[0])
	if rows.is_empty():
		quit(1)
		return

	var tileset := load(TILESET_PATH) as TileSet
	if tileset == null:
		push_error("could not read the tileset - %s (run build_terrain_tileset.gd first)" % TILESET_PATH)
		quit(1)
		return

	var atlas_by_mat := _atlas_by_mat(tileset)
	if atlas_by_mat.is_empty():
		quit(1)
		return

	# **Back up before overwriting.** What is in the scene right now is the only copy —
	#  the baked text is from the last bake, so brush work since then is not in it.
	if not _backup(tileset):
		quit(1)
		return

	# Build the cell data **in memory only**. This node is never attached to the scene.
	var scratch := TileMapLayer.new()
	scratch.tile_set = tileset

	var chars := Baker.CHAR_BY_MAT
	# Character -> material. The inverse of `CHAR_BY_MAT`, so **baking and planting use the same table.**
	# Hold a separate table here and the bake/plant round trip drifts on every lap.
	var mat_by_char := {}
	for mat: int in chars:
		mat_by_char[chars[mat]] = mat

	var painted := 0
	var unknown := {}
	for ty in rows.size():
		var row: String = rows[ty]
		for tx in row.length():
			var ch := row[tx]
			if ch == ".":
				continue
			if not mat_by_char.has(ch):
				unknown[ch] = int(unknown.get(ch, 0)) + 1
				continue
			scratch.set_cell(Vector2i(tx, ty), 0, atlas_by_mat[mat_by_char[ch]])
			painted += 1

	# **Silently skipping an unknown character makes that spot empty and nobody barks** —
	#  even a wholly empty middle of the map reads as "I guess that's how it was painted".
	if not unknown.is_empty():
		push_error("there is an unknown character - %s (not in CHAR_BY_MAT)" % unknown)
		quit(1)
		return
	if painted == 0:
		push_error("0 tiles were planted - the map file is empty or all '.'")
		quit(1)
		return

	var b64 := Marshalls.raw_to_base64(scratch.tile_map_data)
	scratch.free()

	if not _replace_data_line(b64):
		quit(1)
		return

	print("[paint_terrain_from_map] 타일 %d개 심음 (%d행), tile_map_data 교체됨" % [painted, rows.size()])
	print("  아직 게임에 안 반영됐다 — bake_terrain.gd 로 구워야 한다.")
	quit(0)


## Reads the map source. With `--from-generated` it reuses whatever is currently baked.
func _load_rows(src: String) -> Array[String]:
	var out: Array[String] = []
	if src == "--from-generated":
		var gen := load("res://src/stage/terrain_map_generated.gd")
		if gen == null:
			push_error("could not read terrain_map_generated.gd")
			return out
		out.assign(gen.MAP)
		return out

	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		push_error("could not open the map file - %s (error %d)" % [src, FileAccess.get_open_error()])
		return out
	# Trailing whitespace is not stripped — rows of differing width are planted as they are.
	#  Baking finds the real region with `get_used_rect()`, so blanks on the right are harmless.
	for line in f.get_as_text().split("\n"):
		var s := line.trim_suffix("\r")
		if s.is_empty():
			continue
		out.append(s)
	f.close()
	if out.is_empty():
		push_error("the map file is empty - %s" % src)
	return out


## **Material -> atlas coordinates is read from the tileset resource. No table is hardcoded here.**
##  This script used to hardcode `{1: (0,0), 2: (1,0)}` and **bedrock (3) was missing** —
##  run as-is, the map's `B` would have **vanished with no error.** The tileset already holds the material
##  (custom data "material"), so pulling it from there is the only single source.
func _atlas_by_mat(tileset: TileSet) -> Dictionary:
	var out := {}
	for si in tileset.get_source_count():
		var sid := tileset.get_source_id(si)
		var atlas := tileset.get_source(sid) as TileSetAtlasSource
		if atlas == null:
			continue
		for ti in atlas.get_tiles_count():
			var coords := atlas.get_tile_id(ti)
			var data := atlas.get_tile_data(coords, 0)
			if data == null:
				continue
			var mat: int = data.get_custom_data("material")
			if out.has(mat):
				push_error("material %d has two tiles - which one to use is undecided" % mat)
				return {}
			out[mat] = coords
	if out.is_empty():
		push_error("not one material could be read from the tileset - run build_terrain_tileset.gd again")
	return out


## Swaps the one `tile_map_data` line in the scene text. **The rest of the scene is untouched** — see the header.
func _replace_data_line(b64: String) -> bool:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	if f == null:
		push_error("could not read the scene - %s" % SCENE_PATH)
		return false
	var text := f.get_as_text()
	f.close()

	var out := PackedStringArray()
	var hits := 0
	for line in text.split("\n"):
		if line.begins_with(DATA_PREFIX):
			out.append("%s%s\")" % [DATA_PREFIX, b64])
			hits += 1
			continue
		out.append(line)

	# **Both 0 and 2 are failures.** 0 means Terrain does not exist yet or the save format changed, and
	#  2 or more means there are two TileMapLayers, so **which one got painted is unknowable.**
	#  Let either pass quietly and it only surfaces as "it says it planted but the screen didn't change".
	if hits != 1:
		push_error(("found %d tile_map_data lines in the scene (it must be 1) - " +
			"either the Terrain node is missing or there are several TileMapLayers") % hits)
		return false

	f = FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("could not open the scene for writing - %s" % SCENE_PATH)
		return false
	f.store_string("\n".join(out))
	f.close()
	return true


## Dumps the current Terrain as text. It uses the same character table as baking, so **it can be planted straight back.**
## It reads by instantiating the scene — the cells inside the base64 cannot be read from the text alone.
func _backup(tileset: TileSet) -> bool:
	var packed: PackedScene = load(SCENE_PATH)
	var root := packed.instantiate()
	var terrain := root.get_node_or_null("Terrain") as TileMapLayer
	if terrain == null:
		push_error("there is no Terrain(TileMapLayer) node - stand one up in stage.tscn first")
		root.free()
		return false

	var rect := terrain.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		print("[paint_terrain_from_map] 기존 Terrain이 비어 있다 — 백업 안 함")
		root.free()
		return true

	var lines := PackedStringArray()
	for ty in rect.size.y:
		var chars := PackedStringArray()
		chars.resize(rect.size.x)
		for tx in rect.size.x:
			var data := terrain.get_cell_tile_data(Vector2i(rect.position.x + tx, rect.position.y + ty))
			if data == null:
				chars[tx] = "."
				continue
			var mat: int = data.get_custom_data("material")
			chars[tx] = Baker.CHAR_BY_MAT.get(mat, "?")
		lines.append("".join(chars))
	root.free()

	# `Time.` is used here — this is `tools/`, outside `src/sim/`'s integer determinism contract.
	var path := "res://tools/stage/terrain_backup_%d.txt" % Time.get_unix_time_from_system()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("could not open the backup file - %s. It does not overwrite without a backup" % path)
		return false
	f.store_string("\n".join(lines))
	f.close()
	print("[paint_terrain_from_map] 기존 Terrain %d×%d 백업: %s" % [rect.size.x, rect.size.y, path])
	return true
