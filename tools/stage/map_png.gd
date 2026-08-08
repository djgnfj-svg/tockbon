extends SceneTree
## PNG <-> ASCII map. **So the user can draw the level in an image editor instead of an editor brush.**
##
## The map is 400x48 tiles. Painting that with the editor's tile brush is thousands of drags, and the
## in-editor view shows about 30 tiles at a time — **the shape of the level cannot be seen while drawing it.**
## One pixel = one tile makes the whole stage one small image, and any image editor can redraw it.
##
## ```
## bake  ->  [--to-png]  ->  edit the image  ->  [--to-map]  ->  paint_terrain_from_map  ->  bake  ->  game
## ```
##
## Run:
##   Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/map_png.gd -- --to-png <out.png> [scale]
##   Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/map_png.gd -- --to-map <in.png> <out.txt> [scale]
##
## **This script converts only. It never touches the scene or the baked map** — planting is
##  `paint_terrain_from_map.gd`'s job, which already backs up and swaps the one scene line. Doing it here
##  as well would leave two doors into the terrain, and the day one grows a step the other quietly skips it.
##
## == **The palette is drawing colors, not the game's colors** ============
##  Bedrock (`0x232228`) and empty (`0x0e0e13`) differ by 21 per channel — on screen that reads as
##  "the sky and the unbreakable wall are both near-black" (`3.done/stage1-map-layout.md`, acceptance 3),
##  and **in a drawing tool it is invisible.** So the export uses **colors that separate by eye**, and
##  the import matches by **nearest color** so that a hand-picked, slightly-off swatch still lands.
## ==================================================================

const Mat := preload("res://src/sim/cell_materials.gd")
const Baker := preload("res://tools/stage/terrain_baker.gd")
const TerrainMap := preload("res://src/stage/terrain_map_generated.gd")

## Material -> drawing color. **Held here, not derived from `cell_materials`** — see the header box.
const COLOR_BY_MAT := {
	Mat.EMPTY: Color8(255, 255, 255),
	Mat.STONE: Color8(128, 128, 128),
	Mat.WOOD: Color8(150, 75, 0),
	Mat.BEDROCK: Color8(0, 0, 0),
	Mat.WATER: Color8(40, 110, 255),
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("사용법:")
		print("  --to-map <입력.png> <출력.txt> [배율]   그림 -> 맵 텍스트")
		print("  --to-png <출력.png> [배율]              지금 구워진 맵 -> 그림")
		quit(1)
		return

	match args[0]:
		"--to-png":
			quit(0 if _to_png(args[1], _scale(args, 2)) else 1)
		"--to-map":
			if args.size() < 3:
				push_error("--to-map needs an output path too")
				quit(1)
				return
			quit(0 if _to_map(args[1], args[2], _scale(args, 3)) else 1)
		_:
			push_error("unknown mode - %s" % args[0])
			quit(1)


## **Both 0 and a negative are refused.** `image.get_pixel(x / 0)` would not bark; it would divide by zero
##  and hand back a map of a single material.
func _scale(args: PackedStringArray, i: int) -> int:
	if args.size() <= i:
		return 1
	var s := int(args[i])
	if s <= 0:
		push_error("scale must be 1 or more - got %s" % args[i])
		return 1
	return s


func _to_png(out_path: String, scale: int) -> bool:
	var rows: Array = TerrainMap.MAP
	var w: int = TerrainMap.MAP_W
	var h: int = TerrainMap.MAP_H
	var mat_by_char := _mat_by_char()

	var img := Image.create_empty(w * scale, h * scale, false, Image.FORMAT_RGBA8)
	for ty in h:
		var row: String = rows[ty]
		for tx in w:
			var ch := row[tx]
			# An unknown character becomes empty **loudly**. Silently it would read as "that part of the
			#  map was blank to begin with" — the same trap `paint_terrain_from_map` guards.
			var mat: int = Mat.EMPTY
			if ch != ".":
				if not mat_by_char.has(ch):
					push_error("unknown character '%s' at (%d, %d)" % [ch, tx, ty])
					return false
				mat = mat_by_char[ch]
			img.fill_rect(Rect2i(tx * scale, ty * scale, scale, scale), COLOR_BY_MAT[mat])

	var err := img.save_png(out_path)
	if err != OK:
		push_error("could not write the png - %s (error %d)" % [out_path, err])
		return false
	print("[map_png] %dx%d타일 -> %s (%dx%d px, 배율 %d)" % [w, h, out_path, w * scale, h * scale, scale])
	return true


func _to_map(in_path: String, out_path: String, scale: int) -> bool:
	var img := Image.load_from_file(in_path)
	if img == null:
		push_error("could not read the image - %s" % in_path)
		return false
	var w := img.get_width() / scale
	var h := img.get_height() / scale
	if w <= 0 or h <= 0:
		push_error("scale %d is larger than the image (%dx%d)" % [scale, img.get_width(), img.get_height()])
		return false

	# **A tile is read from the pixel at the center of its block, not the corner.** With antialiasing on
	#  (any tool that is not pixel-art), corners blend with the neighbouring tile and a one-tile-wide
	#  wall picks up its neighbour's material — **and the map still looks plausible.**
	var half := scale / 2
	var lines := PackedStringArray()
	var counts := {}
	for ty in h:
		var chars := PackedStringArray()
		chars.resize(w)
		for tx in w:
			var c := img.get_pixel(tx * scale + half, ty * scale + half)
			var mat := _nearest_mat(c)
			counts[mat] = int(counts.get(mat, 0)) + 1
			chars[tx] = "." if mat == Mat.EMPTY else Baker.CHAR_BY_MAT[mat]
		lines.append("".join(chars))

	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("could not open the output file - %s" % out_path)
		return false
	f.store_string("\n".join(lines))
	f.close()

	var report := PackedStringArray()
	for mat: int in Mat.ALL:
		report.append("%s %d" % [Baker.NAME_BY_MAT.get(mat, "EMPTY"), int(counts.get(mat, 0))])
	print("[map_png] %s -> %s  %dx%d타일" % [in_path, out_path, w, h])
	print("  " + " · ".join(report))
	# **A map made almost entirely of one material is the signature of a wrong scale or a wrong palette**,
	#  and it plants without a single error. Say it out loud rather than deciding for the user.
	var top := 0
	for mat: int in counts:
		top = maxi(top, int(counts[mat]))
	if top > w * h * 95 / 100:
		print("  ⚠ 한 재료가 95%를 넘는다 — 배율이나 색이 틀렸을 수 있다")
	return true


## Nearest color in RGB. **Not an exact match** — a swatch picked by hand in a drawing tool is never the
##  exact literal, and an exact match would drop the whole map to empty with no error.
func _nearest_mat(c: Color) -> int:
	var best: int = Mat.EMPTY
	var best_d := INF
	for mat: int in COLOR_BY_MAT:
		var p: Color = COLOR_BY_MAT[mat]
		var d := (c.r - p.r) * (c.r - p.r) + (c.g - p.g) * (c.g - p.g) + (c.b - p.b) * (c.b - p.b)
		if d < best_d:
			best_d = d
			best = mat
	return best


## The inverse of `CHAR_BY_MAT`. **Baking's table is the one source** — hold a copy here and the two drift.
func _mat_by_char() -> Dictionary:
	var out := {}
	for mat: int in Baker.CHAR_BY_MAT:
		out[Baker.CHAR_BY_MAT[mat]] = mat
	return out
