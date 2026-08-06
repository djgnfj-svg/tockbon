extends SceneTree
## ASCII 맵을 `stage.tscn`의 TileMapLayer "Terrain"에 심는다. **굽기의 역방향이다.**
##
## 🔴🔴 **이 방향이 있어야 맵을 사람 아닌 쪽에서 만들 수 있다**(2026-08-07, 사용자가 정했다:
##  「타일은 사용자가 디자인하고 클로드가 찍는다」). 굽기만 있으면 에디터 붓질이 유일한 입력이라
##  ASCII를 만들어 낼 수는 있어도 **그걸 사람이 눈으로 보고 다듬을 방법이 없다.**
##
## ```
## ASCII 파일  →  [이 스크립트]  →  Terrain 레이어  →  에디터에서 다듬는다  →  [굽기]  →  게임
## ```
##
## 실행:
##   Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/paint_terrain_from_map.gd -- <맵파일>
##   ... -- --from-generated        지금 구워져 있는 맵을 되심는다(왕복 확인용)
##
## 🔴 **인자 없이 돌면 아무것도 안 한다.** 전에는 「Terrain이 없을 때만 도는 일회성」이었는데,
##  그 잠금을 푸는 순간 **실수로 돌리면 사용자가 그린 것을 덮는다.** 인자를 강제하는 것이
##  그 자리를 대신하는 안전장치다.
##
## ══ 🔴🔴 씬을 다시 저장하지 않는다 — `tile_map_data` 한 줄만 갈아 끼운다 ══════
##  **2026-08-07에 세 번 데이고 온 자리다.** `ResourceSaver.save(packed_scene)` 로 씬을 통째로
##  다시 쓰면 헤드리스에서 아래가 **전부 조용히** 일어난다:
##
##   ① **uid가 통째로 날아간다** — `[gd_scene ... uid=]` 와 `[ext_resource ... uid=]` 아홉 줄.
##     헤드리스엔 uid 캐시가 없다. 지금 아무도 uid로 이 씬을 참조하지 않아 **게임이 안 깨지고**,
##     그래서 에디터가 다음에 열 때 새로 발급해 **심을 때마다 씬 diff가 난다**
##   ② **노드 속성이 사라진다** — 새 `TileMapLayer` 로 갈아 끼우면 `position = Vector2(0, 1)` 과
##     `unique_id` 가 없어진다. 🔴 **굽기는 셀 좌표만 읽으므로**(`get_used_rect()`)
##     **왕복 검사가 초록인 채로** 속성만 날아간다
##   ③ **`tile_map_data` 가 2배가 된다** — `clear()` 도 `tile_map_data = PackedByteArray()` 도
##     지운 셀을 **`source_id = -1` 기록으로 남기고** 새 셀을 뒤에 붙인다(실측: 21,048 → 41,816자).
##     게임은 멀쩡히 돌고 굽기도 정상이라 **아무도 안 짖는 부풀음**이다
##
##  ⇒ **셀 데이터만 메모리에서 만들어 그 한 줄을 텍스트로 교체한다.** 씬의 나머지는 손도 안 댄다.
## ══════════════════════════════════════════════════════════════════

const Baker := preload("res://tools/stage/terrain_baker.gd")

const TILESET_PATH := "res://src/stage/terrain_tileset.tres"
const SCENE_PATH := "res://src/stage/stage.tscn"
const DATA_PREFIX := "tile_map_data = PackedByteArray(\""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("사용법: --script tools/stage/paint_terrain_from_map.gd -- <맵파일 | --from-generated>")
		print("  🔴 인자 없이는 안 돈다 — 실수로 돌리면 그려 둔 Terrain을 덮는다.")
		quit(1)
		return

	var rows := _load_rows(args[0])
	if rows.is_empty():
		quit(1)
		return

	var tileset := load(TILESET_PATH) as TileSet
	if tileset == null:
		push_error("타일셋을 못 읽었다 — %s (build_terrain_tileset.gd를 먼저 돌려라)" % TILESET_PATH)
		quit(1)
		return

	var atlas_by_mat := _atlas_by_mat(tileset)
	if atlas_by_mat.is_empty():
		quit(1)
		return

	# 🔴 **덮기 전에 백업.** 지금 씬에 들어 있는 것이 유일본이다 —
	#  구운 텍스트는 마지막 굽기 시점 것이라 그 뒤의 붓질이 안 들어 있다.
	if not _backup(tileset):
		quit(1)
		return

	# 셀 데이터를 **메모리에서만** 만든다. 이 노드는 씬에 안 붙는다.
	var scratch := TileMapLayer.new()
	scratch.tile_set = tileset

	var chars := Baker.CHAR_BY_MAT
	# 글자 → 재질. `CHAR_BY_MAT`의 역방향이라 **굽기와 심기가 같은 표를 쓴다.**
	# ⚠ 여기서 따로 표를 들면 굽고 심는 왕복이 한 바퀴 돌 때마다 어긋난다.
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

	# ⚠ **모르는 글자를 조용히 건너뛰면 그 자리가 빈칸이 되고 아무도 안 짖는다** —
	#  맵 한가운데가 통째로 비어도 「그렇게 그렸나 보다」로 읽힌다.
	if not unknown.is_empty():
		push_error("모르는 글자가 있다 — %s (CHAR_BY_MAT에 없다)" % unknown)
		quit(1)
		return
	if painted == 0:
		push_error("심은 타일이 0개다 — 맵 파일이 비었거나 전부 '.'이다")
		quit(1)
		return

	var b64 := Marshalls.raw_to_base64(scratch.tile_map_data)
	scratch.free()

	if not _replace_data_line(b64):
		quit(1)
		return

	print("[paint_terrain_from_map] 타일 %d개 심음 (%d행), tile_map_data 교체됨" % [painted, rows.size()])
	print("  ⚠ 아직 게임에 안 반영됐다 — bake_terrain.gd 로 구워야 한다.")
	quit(0)


## 맵 원본을 읽는다. `--from-generated`면 지금 구워져 있는 것을 되쓴다.
func _load_rows(src: String) -> Array[String]:
	var out: Array[String] = []
	if src == "--from-generated":
		var gen := load("res://src/stage/terrain_map_generated.gd")
		if gen == null:
			push_error("terrain_map_generated.gd를 못 읽었다")
			return out
		out.assign(gen.MAP)
		return out

	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		push_error("맵 파일을 못 열었다 — %s (에러 %d)" % [src, FileAccess.get_open_error()])
		return out
	# ⚠ 줄 끝 공백을 안 지운다 — 폭이 줄마다 달라도 그대로 심는다.
	#  굽기가 `get_used_rect()`로 실제 영역을 찾으므로 오른쪽 빈칸은 무해하다.
	for line in f.get_as_text().split("\n"):
		var s := line.trim_suffix("\r")
		if s.is_empty():
			continue
		out.append(s)
	f.close()
	if out.is_empty():
		push_error("맵 파일이 비었다 — %s" % src)
	return out


## 🔴🔴 **재질 → atlas 좌표를 타일셋 리소스에서 읽는다. 표를 여기 박지 않는다.**
##  2026-08-07까지 이 스크립트가 `{1: (0,0), 2: (1,0)}`을 하드코딩했고 **기반암(3)이 빠져 있었다** —
##  그대로 돌렸으면 맵의 `B`가 **에러 없이 사라졌다.** 타일셋이 이미 재질을 들고 있으므로
##  (custom data "material") 거기서 뽑는 것이 유일한 단일 소스다.
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
				push_error("재질 %d에 타일이 둘이다 — 어느 쪽을 쓸지 정해지지 않는다" % mat)
				return {}
			out[mat] = coords
	if out.is_empty():
		push_error("타일셋에서 재질을 하나도 못 읽었다 — build_terrain_tileset.gd를 다시 돌려라")
	return out


## 씬 텍스트의 `tile_map_data` 한 줄을 갈아 끼운다. 🔴 **씬의 나머지는 손도 안 댄다** — 위 헤더.
func _replace_data_line(b64: String) -> bool:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	if f == null:
		push_error("씬을 못 읽었다 — %s" % SCENE_PATH)
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

	# ⚠ **0개도 2개도 실패다.** 0이면 Terrain이 아직 없거나 저장 형식이 바뀐 것이고,
	#  2개 이상이면 TileMapLayer가 둘이라 **어느 쪽을 칠했는지 알 수 없다.**
	#  🔴 둘 다 조용히 넘어가면 「심었다는데 화면이 안 바뀐다」로만 드러난다.
	if hits != 1:
		push_error(("씬에서 tile_map_data 줄을 %d개 찾았다 (1개여야 한다) — " +
			"Terrain 노드가 없거나 TileMapLayer가 여럿이다") % hits)
		return false

	f = FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("씬을 쓰기로 못 열었다 — %s" % SCENE_PATH)
		return false
	f.store_string("\n".join(out))
	f.close()
	return true


## 지금 Terrain을 텍스트로 떠 둔다. 🔴 굽기와 같은 글자표를 쓰므로 **되심을 수 있는 형식이다.**
## ⚠ 씬을 인스턴스화해서 읽는다 — 텍스트만 봐서는 base64 안의 셀을 못 읽는다.
func _backup(tileset: TileSet) -> bool:
	var packed: PackedScene = load(SCENE_PATH)
	var root := packed.instantiate()
	var terrain := root.get_node_or_null("Terrain") as TileMapLayer
	if terrain == null:
		push_error("Terrain(TileMapLayer) 노드가 없다 — stage.tscn에 먼저 세워라")
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

	# ⚠ `Time.`을 쓴다 — 여긴 `tools/`라 `src/sim/`의 정수 결정론 계약 밖이다.
	var path := "res://tools/stage/terrain_backup_%d.txt" % Time.get_unix_time_from_system()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("백업 파일을 못 열었다 — %s. 🔴 백업 없이는 안 덮는다" % path)
		return false
	f.store_string("\n".join(lines))
	f.close()
	print("[paint_terrain_from_map] 기존 Terrain %d×%d 백업: %s" % [rect.size.x, rect.size.y, path])
	return true
