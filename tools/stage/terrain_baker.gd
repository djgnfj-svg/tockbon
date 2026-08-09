extends RefCounted
## The actual logic of terrain baking. Both `bake_terrain.gd` (headless) and `bake_terrain_editor.gd` (in-editor)
## call this one — copy the logic into two places and they diverge.
##
## Reads a `TileMapLayer` of `stage.tscn` and rewrites a generated map script. **Which layer and which file
## are arguments now** (`bake()`'s two parameters, both defaulting to stage 1's) — a second stage is a second
## layer in the same scene baked to its own artifact, and the room table (`src/stage/stage_defs.gd`) names
## whichever one a stage uses. Stage 1's call is unchanged.
## `Stage.MAP` · `Stage.MAP_CHARS` · `Stage.MAP_W` · `Stage.MAP_H` · `Stage.build_terrain_into()` are
## left alone — they all re-export this artifact as is. Because `_wood_clumps` and `_stage_map` in `net_tables.gd`
## measure this directly, building a bake under a new name makes that net measure a dead side branch
## instead of "the terrain that actually runs".
##
## **It finds the painted region itself with `TileMapLayer.get_used_rect()`** — it does not read a fixed width
## from the origin (0,0). **This was learned by measurement**: the user painted 312x126 tiles and everything
## outside (0,0)~(63,35) was silently skipped by the old approach (a fixed window), baking an entirely empty
## result. `get_used_rect()` catches negative coordinates too (parts painted above/left of the origin) and
## shifts them to start at 0.
##
## **There is still a ceiling** — the sim grid that actually runs (`CellGrid.W` · `H`) is a fixed size in cells.
## If the painted region is larger, **it barks here instead of being silently clipped** — "could not bake" is
## better than terrain clipped full of holes.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

## **Adding a material means adding one line here. It is the only hand work left of the four places**
##  (the brush image and the tileset table disappeared into `terrain_palette.gd` derivations).
## **And it is right that this one remains** — which character to use cannot be derived, and
##  leaving it out makes **baking bark and stop** (`CHAR_BY_MAT.has(mat)` below). It is the only one of the four that dies loudly.
##  Even so a net catches it first — `net_tables` measures whether every material that becomes a brush has a character.
## The character must be **one character** (one slot is one character) and **distinct from the others** — if they
##  collide, planting a baked map back merges two materials into one. A net measures both.
const CHAR_BY_MAT := {
	Mat.STONE: "#",
	Mat.WOOD: "=",
	Mat.BEDROCK: "B",
	Mat.WATER: "~",
}

## **Material id -> GDScript constant name. Held by hand too — the hidden fifth of "the four places to fix".**
##  **This line was missing from the table in `docs/design/terrain-baking.md`** (found later).
##   It was hiding as a local variable inside `bake()`, and when adding water, growing only `CHAR_BY_MAT` gave
##   **the brush appearing and tiles placing, while baking died with "I don't know the constant name of material id 4".**
##  **That is why it was promoted here** — a net cannot see a local variable. Now `net_tables` measures it.
##
## **It cannot be derived.** Inverting value->name with `get_script_constant_map()` **collides** —
##  `STONE` (1) and `FLAG_SHALLOW` (1), `EMPTY` (0) and `BEHAVIOR_NONE` (0) are the same values.
##  Filtering by name convention is possible but that is **a heuristic that goes stale**. => Hold it by hand, and let a net measure it.
const NAME_BY_MAT := {
	Mat.STONE: "STONE",
	Mat.WOOD: "WOOD",
	Mat.BEDROCK: "BEDROCK",
	Mat.WATER: "WATER",
}


## Stage 1's source layer and artifact. **Defaults, not the contract** — a second stage is a second
## `TileMapLayer` in the same scene baked to its own file, and that is the whole of `bake()`'s two arguments.
const DEFAULT_SOURCE_NODE := "Terrain"
const DEFAULT_OUT_PATH := "res://src/stage/terrain_map_generated.gd"


## true on success. On failure it barks with `push_error` and returns false — the caller turns it into an exit code.
##
## **Both arguments default to stage 1's**, so `bake()` with no arguments is byte-for-byte the call the two
## entry points (`bake_terrain.gd` headless, `bake_terrain_editor.gd` in-editor) already made.
static func bake(source_node: String = DEFAULT_SOURCE_NODE,
		out_path: String = DEFAULT_OUT_PATH) -> bool:
	var packed: PackedScene = load("res://src/stage/stage.tscn")
	var root := packed.instantiate()
	var terrain := root.get_node_or_null(NodePath(source_node)) as TileMapLayer
	if terrain == null:
		# **The node's name is in the message.** With it hardcoded to "Terrain", baking stage 2's layer and
		#  misspelling it would bark about a node that is not the one being asked for.
		push_error("there is no %s(TileMapLayer) node - stand one up in stage.tscn first" % source_node)
		root.free()
		return false

	var rect := terrain.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		push_error("no tiles are drawn on %s - draw before baking" % source_node)
		root.free()
		return false

	var map_w := rect.size.x
	var map_h := rect.size.y
	var cap_w := CellGrid.W / Tuning.TILE_CELLS
	var cap_h := CellGrid.H / Tuning.TILE_CELLS
	if map_w > cap_w or map_h > cap_h:
		push_error(
			("the drawn region (%dx%d tiles) exceeds grid capacity (%dx%d tiles) - " +
			"raise CellGrid.W/H/X_SHIFT and bake again") % [map_w, map_h, cap_w, cap_h])
		root.free()
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
				push_error("%s has no character for material id %d - extend CHAR_BY_MAT" % [cell, mat])
				root.free()
				return false
			chars[tx] = CHAR_BY_MAT[mat]
		rows.append("".join(chars))
	# The scene has been read and nothing below touches it. **Freed rather than left behind** — a `Node` from
	#  `instantiate()` is not reference counted, and a net that drives this would end its process with
	#  "ObjectDB instances leaked at exit" on stderr, which the wrapper counts as a failed round.
	root.free()

	var out := "extends RefCounted\n"
	out += "## Generated automatically - do not edit by hand.\n"
	out += "## To change the terrain, redraw stage.tscn's %s(TileMapLayer) in the Godot editor and\n" % source_node
	out += "## bake (open `bake_terrain_editor.gd` in the script editor and run it, or headless `bake_terrain.gd`).\n"
	out += "## MAP_W and MAP_H are the drawn region's real size (`TileMapLayer.get_used_rect()`) - not matched by hand.\n"
	# **The artifact's header goes stale too.** This used to point at "the table in `build_terrain_tileset.gd`",
	#  but **that table is gone** (derived in `terrain_palette.gd`) and `NAME_BY_MAT` was not written down.
	out += "## If a new material was added, extend `terrain_baker.gd`'s CHAR_BY_MAT and NAME_BY_MAT and\n"
	out += "## **this file must be baked again** - fix only the tool and this artifact does not follow.\n"
	out += "## (The brush drawing and the tileset table derive from `terrain_palette.gd`, so there is nothing to touch.)\n\n"
	out += "const Mat := preload(\"res://src/sim/cell_materials.gd\")\n\n"
	out += "const MAP_W := %d\n" % map_w
	out += "const MAP_H := %d\n\n" % map_h
	out += "const MAP: Array[String] = [\n"
	for row in rows:
		out += "\t\"%s\",\n" % row
	out += "]\n\n"
	# **Derived from `CHAR_BY_MAT`. Do not hardcode it as a literal.**
	#  This line used to be the string `{"#": Mat.STONE, "=": Mat.WOOD, "B": Mat.BEDROCK}`, and with that,
	#  **the moment you grow `CHAR_BY_MAT` without growing this, they silently diverge** — the baked map
	#  contains a new character the game does not know. `Stage.MAP_CHARS.has(ch)` is false, so
	#  **that cell becomes empty with no error.** It would have fired exactly here the day water arrived.
	# The name must come out as `Mat.<constant>` — hardcode the number and it diverges again the day a material id moves.
	var pairs := PackedStringArray()
	for mat: int in CHAR_BY_MAT:
		if not NAME_BY_MAT.has(mat):
			# Grow a material without growing the table above and it barks here. It does not silently emit a number —
			# that would leave the generated file surviving with a hardcoded material id.
			push_error("the constant name for material id %d is unknown - extend terrain_baker's NAME_BY_MAT" % mat)
			return false
		pairs.append("\"%s\": Mat.%s" % [CHAR_BY_MAT[mat], NAME_BY_MAT[mat]])
	out += "const MAP_CHARS: Dictionary = {%s}\n\n" % ", ".join(pairs)
	# **The accessor the room table calls** (`stage_defs.map_rows()`). Emitted here rather than written into
	#  the artifact by hand — the artifact is overwritten on every bake, so a hand-added function lives
	#  exactly until the next redraw and then the table's `map` field dies with nothing barking.
	out += "## The accessor `stage_defs.map_rows()` calls. Every map script has one, so the room table holds\n"
	out += "## the script and never a per-stage branch.\n"
	out += "static func rows() -> Array[String]:\n"
	out += "\treturn MAP\n"

	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("could not open %s - error code %d" % [out_path, FileAccess.get_open_error()])
		return false
	f.store_string(out)
	f.close()

	print("[terrain_baker] %s 다시 씀 (%d×%d타일, 원점 옮김 %s)" % [
		out_path.get_file(), map_w, map_h, -rect.position])
	return true
