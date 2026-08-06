extends SceneTree
## `src/stage/terrain_tileset.tres`를 다시 만든다. **재질이 늘 때만 돌린다.**
## ⚠ 손으로 .tres를 고치지 마라 — 이 스크립트가 유일한 문이다.
## 🔴 **더 이상 「이 스크립트에 타일을 추가」하지 않는다** — 팔레트가 `Mat.ALL` 에서 파생된다.
##
## 실행: Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/build_terrain_tileset.gd

const Mat := preload("res://src/sim/cell_materials.gd")
const Palette := preload("res://tools/stage/terrain_palette.gd")

const OUT_PATH := "res://src/stage/terrain_tileset.tres"

## 🔴🔴 **표가 사라졌다.** atlas 좌표 ↔ 재질이 여기 손으로 적혀 있었고,
##  `assets/stage/terrain_tiles.png` 의 칸 순서와 **둘이 맞아야** 했다(2026-08-07까지).
##  ⇒ 이제 둘 다 `terrain_palette.gd` 에서 파생된다 — **맞출 것이 없다.**
## ⚠ 그 png 도 이제 구워진다(`build_terrain_atlas.gd`). **그걸 먼저 돌려라** —
##  칸이 모자란 png 로 타일셋을 만들면 **없는 칸을 가리키는 타일**이 생긴다.


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

	var ids := Palette.paintable()
	# 🔴 png 가 실제로 그만큼 넓은지 먼저 본다. 좁으면 `create_tile` 이 조용히 실패하고
	#  **붓은 보이는데 재질이 안 붙는 타일**이 생긴다 — 그게 이 파이프라인의 대표 침묵사다.
	var need := Palette.tile_px() * ids.size()
	if tex.get_width() < need:
		push_error("atlas 텍스처가 좁다 — %dpx 필요한데 %dpx다. build_terrain_atlas.gd 를 먼저 돌려라"
			% [need, tex.get_width()])
		quit(1)
		return

	for i in ids.size():
		var coords := Palette.atlas_of(i)
		atlas.create_tile(coords)
		var data := atlas.get_tile_data(coords, 0)
		data.set_custom_data("material", int(ids[i]))

	# 🔴🔴 **저장하기 전에 uid 를 챙긴다. `ResourceSaver.save` 가 그걸 통째로 날린다.**
	#  ⚠ **2026-08-07에 실제로 날렸다** — 이 스크립트를 처음으로 **다시** 돌렸더니
	#   `.tres` 의 `uid="uid://d4d6jvryupnxn"` 이 사라졌다. 새로 만든 `TileSet` 은 경로도 uid 도
	#   모르고, 헤드리스엔 에디터의 uid 캐시가 없다.
	#  🔴 **`stage.tscn` 이 이 리소스를 uid 로 참조한다.** 지금은 `path` 도 같이 적혀 있어
	#   게임이 안 깨지지만, **에디터가 다음에 열 때 새 uid 를 발급해 씬 diff 가 난다** —
	#   `docs/design/지형-굽기.md` 가 심기 쪽에서 똑같이 데인 자리다.
	#  ⇒ **덮어쓰기 전 파일에서 읽어 다시 넣는다.** 값을 박지 않는다 — 있던 것을 그대로 지킨다.
	var keep := _read_uids(OUT_PATH)

	var err := ResourceSaver.save(tileset, OUT_PATH)
	if err != OK:
		push_error("TileSet 저장 실패 — 에러 코드 %d" % err)
		quit(1)
		return

	if not _restore_uids(OUT_PATH, keep):
		quit(1)
		return

	print("[build_terrain_tileset] 저장됨: %s (타일 %d개)" % [OUT_PATH, ids.size()])
	quit(0)


## 파일에서 `uid="uid://..."` 를 걷어 온다. 키는 `""`(헤더) 또는 ext_resource 의 `path`.
static func _read_uids(path: String) -> Dictionary:
	var out := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out  # 첫 생성이면 지킬 uid 가 없다 — 정상이다
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


## 저장 직후 uid 를 되돌린다. 되돌릴 게 있는데 못 되돌리면 **짖고 false** —
## 🔴 조용히 넘어가면 씬 참조가 끊긴 채로 커밋된다.
static func _restore_uids(path: String, keep: Dictionary) -> bool:
	if keep.is_empty():
		return true
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("저장한 %s 를 다시 못 읽었다" % path)
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
		# `format=3]` / `id="..."]` 앞에 끼워 넣지 않고 **닫는 대괄호 앞**에 붙인다 —
		# 속성 순서는 Godot 이 안 따진다.
		lines[i] = line.substr(0, line.length() - 1) + " uid=\"%s\"]" % keep[key]
		restored += 1
	if restored == 0:
		return true
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w == null:
		push_error("%s 에 uid 를 되돌리려 열지 못했다" % path)
		return false
	w.store_string("
".join(lines))
	print("  uid %d개를 지켰다 (ResourceSaver 가 지운 것을 되돌렸다)" % restored)
	return true


## `key="값"` 에서 값만. 없으면 빈 문자열.
static func _attr(line: String, key: String) -> String:
	var at := line.find(key + "=\"")
	if at < 0:
		return ""
	var from := at + key.length() + 2
	var to := line.find("\"", from)
	return line.substr(from, to - from) if to > from else ""
