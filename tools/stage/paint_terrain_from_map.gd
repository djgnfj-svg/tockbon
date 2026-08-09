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
## The section header a `.tscn` writes before every node. The layer name is matched against this.
const NODE_PREFIX := "[node name=\""

## Stage 1's layer. **A default, not the contract** — the same two-argument treatment
## `terrain_baker.bake()` already carries, and this was the half of the pipe that was missing.
##
## **The bake is the read direction; the paint is the write direction, and a stage is made in the write
## direction.** `bake()` was parameterised and this was not, so the moment `stage.tscn` held a second
## `TileMapLayer` this refused outright (`hits != 1`) and **there was no headless way to author a second
## map at all.** That was the one hard blocker on adding a stage; the rest of the pipe was ready.
const DEFAULT_LAYER := "Terrain"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("사용법: --script tools/stage/paint_terrain_from_map.gd -- <맵파일 | --from-generated> [레이어]")
		print("  인자 없이는 안 돈다 — 실수로 돌리면 그려 둔 레이어를 덮는다.")
		print("  레이어를 안 적으면 %s — 스테이지 2는 제 레이어 이름을 적어야 한다." % DEFAULT_LAYER)
		quit(1)
		return
	var layer := DEFAULT_LAYER if args.size() < 2 else args[1]

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
	if not _backup(tileset, layer):
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

	if not _replace_data_line(b64, layer):
		quit(1)
		return

	print("[paint_terrain_from_map] %s 에 타일 %d개 심음 (%d행), tile_map_data 교체됨"
		% [layer, painted, rows.size()])
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


## **The text surgery, pure and static — a net drives this with a synthetic two-layer scene and no
## files at all.** The file reading and writing stay in `_replace_data_line` below; everything that can
## be wrong lives here.
##
## Returns `{"text": String, "hits": int}`. **`hits` must be 1**; the caller is what refuses otherwise.
##
## **Section tracking is the whole idea.** A `.tscn` writes a `[node name=...]` header before each
## node's properties, so which node a `tile_map_data` line belongs to is readable from the text alone —
## no instantiating the scene, which this file's header forbids for its own reasons. Counting the
## property across the whole file instead is what made a second `TileMapLayer` impossible.
static func swap_layer_data(text: String, layer: String, b64: String) -> Dictionary:
	var out := PackedStringArray()
	var hits := 0
	var in_target := false
	for line in text.split("\n"):
		if line.begins_with(NODE_PREFIX):
			in_target = line.begins_with("%s%s\"" % [NODE_PREFIX, layer])
		if in_target and line.begins_with(DATA_PREFIX):
			out.append("%s%s\")" % [DATA_PREFIX, b64])
			hits += 1
			continue
		out.append(line)
	return {"text": "\n".join(out), "hits": hits}


## Swaps the one `tile_map_data` line in the scene text. **The rest of the scene is untouched** — see the header.
##
## **It tracks which node section each line is inside**, rather than counting `tile_map_data` lines
## across the whole file. That is the entire difference between "there may only ever be one
## TileMapLayer" and "say which one". A `.tscn` writes `[node name=...]` before each node's
## properties, so the section is readable from the text alone — no instantiating the scene, which is
## what the header forbids.
func _replace_data_line(b64: String, layer: String) -> bool:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	if f == null:
		push_error("could not read the scene - %s" % SCENE_PATH)
		return false
	var text := f.get_as_text()
	f.close()

	var swapped := swap_layer_data(text, layer, b64)
	var hits := int(swapped["hits"])

	# **Both 0 and 2 are still failures, and now they mean something narrower.** 0 means that layer has
	#  no `tile_map_data` — a wrong name, or a layer with nothing drawn on it yet. 2 or more can only
	#  happen if one node section carries the property twice, which is a corrupt scene.
	#  Let either pass quietly and it surfaces only as "it says it planted but the screen didn't change".
	if hits != 1:
		push_error(("found %d tile_map_data lines under node %s (it must be 1) - " +
			"either that node is missing, is not a TileMapLayer, or has nothing drawn on it")
			% [hits, layer])
		return false

	f = FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("could not open the scene for writing - %s" % SCENE_PATH)
		return false
	f.store_string(String(swapped["text"]))
	f.close()
	return true


## Dumps the current Terrain as text. It uses the same character table as baking, so **it can be planted straight back.**
## It reads by instantiating the scene — the cells inside the base64 cannot be read from the text alone.
func _backup(tileset: TileSet, layer: String) -> bool:
	var packed: PackedScene = load(SCENE_PATH)
	var root := packed.instantiate()
	var terrain := root.get_node_or_null(NodePath(layer)) as TileMapLayer
	if terrain == null:
		push_error("there is no %s(TileMapLayer) node - stand one up in stage.tscn first" % layer)
		root.free()
		return false

	var rect := terrain.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		print("[paint_terrain_from_map] 기존 %s이 비어 있다 — 백업 안 함" % layer)
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
	var path := "res://tools/stage/terrain_backup_%s_%d.txt" % [layer, Time.get_unix_time_from_system()]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("could not open the backup file - %s. It does not overwrite without a backup" % path)
		return false
	f.store_string("\n".join(lines))
	f.close()
	print("[paint_terrain_from_map] 기존 %s %d×%d 백업: %s" % [layer, rect.size.x, rect.size.y, path])
	return true
