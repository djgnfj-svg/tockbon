extends SceneTree
## Rebuilds `src/stage/terrain_tileset.tres`. **Run only when a material is added.**
## Do not hand-edit the .tres — this script is the only door.
## **You no longer "add a tile to this script"** — the palette is derived from `Mat.ALL`.
##
## Run: Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/build_terrain_tileset.gd

const Mat := preload("res://src/sim/cell_materials.gd")
const Palette := preload("res://tools/stage/terrain_palette.gd")

const OUT_PATH := "res://src/stage/terrain_tileset.tres"

## **The table is gone.** Atlas coordinates <-> material used to be written here by hand, and
##  it had to **match** the slot order of `assets/stage/terrain_tiles.png`.
##  => Both are now derived from `terrain_palette.gd` — **there is nothing to match.**
## That png is baked now too (`build_terrain_atlas.gd`). **Run that first** —
##  building a tileset from a png with too few slots creates **tiles pointing at slots that do not exist.**


func _init() -> void:
	var tex := load("res://assets/stage/terrain_tiles.png") as Texture2D
	if tex == null:
		push_error("could not read the atlas texture - assets/stage/terrain_tiles.png")
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

	# add_source comes first — TileData must know its owning TileSet to find the custom data layer.
	#  Swap the order and it fails quietly with "Parameter tile_set is null" (measured).
	tileset.add_source(atlas, 0)

	var ids := Palette.paintable()
	# Check first whether the png really is that wide. If it is narrow, `create_tile` fails quietly and
	#  **tiles appear as brushes but carry no material** — that is this pipeline's signature silent death.
	var need := Palette.tile_px() * ids.size()
	if tex.get_width() < need:
		push_error("the atlas texture is too narrow - %dpx needed but it is %dpx. Run build_terrain_atlas.gd first"
			% [need, tex.get_width()])
		quit(1)
		return

	for i in ids.size():
		var coords := Palette.atlas_of(i)
		atlas.create_tile(coords)
		var data := atlas.get_tile_data(coords, 0)
		data.set_custom_data("material", int(ids[i]))

	# **Collect the uids before saving. `ResourceSaver.save` wipes them wholesale.**
	#  **It actually wiped them once** — running this script **again** for the first time made
	#   `uid="uid://d4d6jvryupnxn"` disappear from the `.tres`. A freshly built `TileSet` knows neither its path
	#   nor its uid, and headless has no editor uid cache.
	#  **`stage.tscn` references this resource by uid.** Right now `path` is written alongside it so
	#   the game does not break, but **the editor reissues a new uid next time it opens, giving a scene diff** —
	#   the same burn `docs/design/terrain-baking.md` took on the planting side.
	#  => **Read them from the file before overwriting and put them back.** No value is hardcoded — what was there is preserved.
	var keep := _read_uids(OUT_PATH)

	var err := ResourceSaver.save(tileset, OUT_PATH)
	if err != OK:
		push_error("TileSet save failed - error code %d" % err)
		quit(1)
		return

	if not _restore_uids(OUT_PATH, keep):
		quit(1)
		return

	print("[build_terrain_tileset] 저장됨: %s (타일 %d개)" % [OUT_PATH, ids.size()])
	quit(0)


## Collects `uid="uid://..."` from the file. The key is `""` (the header) or the `path` of an ext_resource.
static func _read_uids(path: String) -> Dictionary:
	var out := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out  # On first creation there is no uid to preserve — that is normal
	for line in f.get_as_text().split("
"):
		var uid := _attr(line, "uid")
		if uid == "":
			continue
		if line.begins_with("[gd_resource"):
			out[""] = uid
		elif line.begins_with("[ext_resource"):
			out[_attr(line, "path")] = uid
	return out


## Restores the uids right after saving. If there is something to restore and it cannot be, **it barks and returns false** —
## letting it pass quietly commits the scene with a broken reference.
static func _restore_uids(path: String, keep: Dictionary) -> bool:
	if keep.is_empty():
		return true
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("could not read back the saved %s" % path)
		return false
	var lines := f.get_as_text().split("
")
	var restored := 0
	for i in lines.size():
		var line: String = lines[i]
		var key := ""
		if line.begins_with("[gd_resource"):
			key = ""
		elif line.begins_with("[ext_resource"):
			key = _attr(line, "path")
		else:
			continue
		if not keep.has(key) or _attr(line, "uid") != "":
			continue
		# Instead of inserting before `format=3]` / `id="..."]`, append it **before the closing bracket** —
		# Godot does not care about attribute order.
		lines[i] = line.substr(0, line.length() - 1) + " uid=\"%s\"]" % keep[key]
		restored += 1
	if restored == 0:
		return true
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w == null:
		push_error("could not open %s to restore its uid" % path)
		return false
	w.store_string("
".join(lines))
	print("  uid %d개를 지켰다 (ResourceSaver 가 지운 것을 되돌렸다)" % restored)
	return true


## Just the value out of `key="value"`. Empty string if absent.
static func _attr(line: String, key: String) -> String:
	var at := line.find(key + "=\"")
	if at < 0:
		return ""
	var from := at + key.length() + 2
	var to := line.find("\"", from)
	return line.substr(from, to - from) if to > from else ""
