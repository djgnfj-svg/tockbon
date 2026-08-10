extends RefCounted
## The town — `docs/design/town.md`.
##
## **Three things are measurable here and they are not the same thing.**
##  1. **The room** — is it actually a hollow, all-bedrock box, and does the character land inside it.
##     This is the check that would have caught `stage.SPAWN_TILE`'s own recorded accident (the map was
##     repainted, the spawn tile stayed, and the character started sealed inside rock with nothing barking)
##  2. **The door** (`Fixtures.at`) — pure, so it is driven directly with made-up seats
##  3. **The wiring** — E at the gate really leaves, E at a bench really does that bench's thing. Driven
##     through the real scene, because 1 and 2 can both be perfect while nothing is connected
##
## **What is not measurable**: whether the room reads as "home". `town.md`'s screen section is the eye's —
##  it asks for a bright room in front of a broken village and there is no art at all yet.

const Stage := preload("res://src/stage/stage.gd")
const TownMap := preload("res://src/stage/town_map.gd")
const TownView := preload("res://src/view/town_view.gd")
const Fixtures := preload("res://src/actor/fixtures.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")
const Progress := preload("res://src/actor/progress.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
## Only for `ELEM_NAMES` — the research bench's text is built from it, so the check reads the same table
## rather than writing the three names down a second time.
const Fx := preload("res://src/view/fx_tuning.gd")
const ResearchWindow := preload("res://src/view/research_window.gd")
const ResearchLayout := preload("res://src/view/research_layout.gd")

const STAGE_SCENE := "res://src/stage/stage.tscn"
## One tile in cells, and in world px. Derived, never written down — the two would drift.
const TILE_CELLS: int = Tuning.TILE_CELLS
const TILE_PX: int = Tuning.TILE_CELLS * Tuning.CELL_PX


func run(t) -> void:
	_the_room_is_a_hollow_bedrock_box(t)
	_the_room_is_built_out_of_bedrock_and_nothing_else(t)
	_you_land_inside_the_room_and_on_its_floor(t)
	_the_fixtures_stand_in_the_room_and_do_not_overlap(t)
	_the_door_answers_where_you_are_standing(t)
	_the_research_bench_shows_locked_and_unlocked_together(t)
	_the_blocks_stand_on_the_floor(t)
	_the_fixture_art_is_loaded_at_its_own_size(t)
	_the_town_has_its_own_backdrop(t)
	_the_research_window_art_loads(t)
	_the_panel_slices_tile_the_window_exactly(t)
	_the_rows_stack_inside_the_panel(t)
	_the_item_row_is_the_rune_pool(t)
	_the_gate_leaves_and_being_downed_comes_back(t)


# ══════════════════════════════════════════════════════════════════
#  1. The room
# ══════════════════════════════════════════════════════════════════

## **The map's shape, read off the rows the game actually builds from.** `rows()` is generated from four
##  numbers, so this is measuring the generator — which is the point: hand-written rows are what go wrong
##  silently, and this is what makes the generated ones trustworthy instead.
func _the_room_is_a_hollow_bedrock_box(t) -> void:
	var rows := TownMap.rows()
	t.eq(rows.size(), TownMap.MAP_H, "마을 지도의 줄 수가 무대와 같다 (%d줄)" % TownMap.MAP_H)
	# **The same tile size as the stage map.** The camera clamps to the grid rather than the map
	#  (`stage.world_size`), so a smaller town would leave the player able to walk off the drawn area.
	t.eq(TownMap.MAP_W, Stage.MAP_W, "마을 지도의 폭이 무대와 같다 (%d칸)" % Stage.MAP_W)
	t.eq(TownMap.MAP_H, Stage.MAP_H, "마을 지도의 높이가 무대와 같다")

	var wrong_width := 0
	var stray := 0
	for ty in rows.size():
		var row: String = rows[ty]
		if row.length() != TownMap.MAP_W:
			wrong_width += 1
			continue
		for tx in row.length():
			var ch := row[tx]
			if ch != "B" and ch != ".":
				stray += 1
			var inside := tx >= TownMap.ROOM_X0 and tx <= TownMap.ROOM_X1 \
				and ty >= TownMap.ROOM_Y0 and ty <= TownMap.ROOM_Y1
			if inside and ch != ".":
				stray += 1
			if not inside and ch != "B":
				stray += 1
	t.eq(wrong_width, 0, "모든 줄의 폭이 같다")
	t.eq(stray, 0, "방 안은 전부 빈칸이고 방 밖은 전부 기반암이다 (어긋난 칸 %d개)" % stray)

	# **The room is big enough to be a room.** A "walkable room" that is two tiles wide is a menu with a
	#  floor — the whole reason the town is walked and not clicked (`town.md`, "Form").
	var w := TownMap.ROOM_X1 - TownMap.ROOM_X0 + 1
	var h := TownMap.ROOM_Y1 - TownMap.ROOM_Y0 + 1
	t.ok(w >= 30, "방이 가로로 한 화면(30타일)보다 넓다 (%d타일 — 걸어 다닐 값어치가 있다)" % w)
	# Character 32px = 1 tile. Three tiles of headroom is "you can jump indoors".
	t.ok(h >= 3, "방 높이가 캐릭터 셋 이상이다 (%d타일 — 실내에서 점프가 된다)" % h)


## **Driven through the real builder, into a real grid.** The rows above are text; this is the only check
##  that says the town is *made of bedrock*, which is the entire "the town does not get dug up" rule
##  (`town.md`, "all town terrain is bedrock").
##
## **Bedrock is asserted by material, not by `is_solid`.** Stone is solid too — a town built of stone would
##  pass a solidity check and then be blasted open on the first cast, with nothing red anywhere.
func _the_room_is_built_out_of_bedrock_and_nothing_else(t) -> void:
	var g := CellGrid.new()
	Stage.build_map_into(g, TownMap.rows(), TownMap.MAP_CHARS)

	# A cell inside the room, a cell in each wall, and the floor right under the spawn.
	var in_x := (TownMap.ROOM_X0 + TownMap.ROOM_X1) / 2 * TILE_CELLS
	var in_y := (TownMap.ROOM_Y0 + TownMap.ROOM_Y1) / 2 * TILE_CELLS
	t.ok(not g.is_solid(in_x, in_y), "방 한가운데는 비어 있다")
	t.eq(g.mat_at((TownMap.ROOM_X0 - 1) * TILE_CELLS, in_y), Mat.BEDROCK, "왼쪽 벽이 기반암이다")
	t.eq(g.mat_at((TownMap.ROOM_X1 + 1) * TILE_CELLS, in_y), Mat.BEDROCK, "오른쪽 벽이 기반암이다")
	t.eq(g.mat_at(in_x, (TownMap.ROOM_Y0 - 1) * TILE_CELLS), Mat.BEDROCK, "천장이 기반암이다")
	t.eq(g.mat_at(in_x, (TownMap.ROOM_Y1 + 1) * TILE_CELLS), Mat.BEDROCK, "바닥이 기반암이다")

	# **Nothing burnable, and nothing diggable** — the table itself is what makes that true, so it is
	#  measured on the table and not by sampling cells (`town_map.MAP_CHARS`'s own comment).
	t.eq(TownMap.MAP_CHARS.size(), 1, "마을 지도의 글자표에 기반암 하나뿐이다 (나무를 그려 넣을 수가 없다)")
	t.ok(TownMap.MAP_CHARS.has("B"), "그 하나가 기반암이다")


## **The accident this exists for is on the record**: the stage map was repainted, `SPAWN_TILE` was not, and
##  the character started inside a sealed cave — "launch the game and the surface is never seen at all. Not
##  one line of error is raised" (`stage.SPAWN_TILE`'s own box).
##
## **Standing room is measured, not just "the tile is empty"** — the character is 32px tall (one tile), so a
##  spawn on the floor row needs the row above it clear as well, and a check on one cell would not see that.
func _you_land_inside_the_room_and_on_its_floor(t) -> void:
	var sp := TownMap.SPAWN_TILE
	t.ok(sp.x >= TownMap.ROOM_X0 and sp.x <= TownMap.ROOM_X1, "출발 타일이 방의 가로 범위 안이다 (x %d)" % sp.x)
	t.ok(sp.y >= TownMap.ROOM_Y0 and sp.y <= TownMap.ROOM_Y1, "출발 타일이 방의 세로 범위 안이다 (y %d)" % sp.y)
	t.eq(sp.y, TownMap.ROOM_Y1, "출발 타일이 방의 맨 아랫줄이다 (허공에서 떨어지지 않는다)")

	var g := CellGrid.new()
	Stage.build_map_into(g, TownMap.rows(), TownMap.MAP_CHARS)
	var px := sp.x * TILE_PX
	var py := sp.y * TILE_PX
	var blocked := 0
	for cy in range(floori(py / float(Tuning.CELL_PX)),
			floori((py + Character.H_PX - 1) / float(Tuning.CELL_PX)) + 1):
		for cx in range(floori(px / float(Tuning.CELL_PX)),
				floori((px + Character.W_PX - 1) / float(Tuning.CELL_PX)) + 1):
			if g.is_solid(cx, cy):
				blocked += 1
	t.eq(blocked, 0, "출발 자리에 캐릭터 상자가 통째로 들어간다 (막힌 칸 %d개)" % blocked)
	# And the floor really is right under it — otherwise "on the bottom row" would be true in mid-air too.
	t.ok(g.is_solid(floori(px / float(Tuning.CELL_PX)),
			floori((py + Character.H_PX) / float(Tuning.CELL_PX))),
		"그 바로 아래는 바닥이다")


func _the_fixtures_stand_in_the_room_and_do_not_overlap(t) -> void:
	t.eq(TownMap.FIXTURE_TILES.size(), Fixtures.NAMES.size(),
		"설비가 종류 수만큼 놓였다 (%d개)" % Fixtures.NAMES.size())
	for kind: int in Fixtures.NAMES:
		t.ok(TownMap.FIXTURE_TILES.has(kind), "%s의 자리가 있다" % Fixtures.name_of(kind))
		var tx: int = TownMap.FIXTURE_TILES.get(kind, -1)
		t.ok(tx >= TownMap.ROOM_X0 and tx <= TownMap.ROOM_X1,
			"%s가 방 안에 서 있다 (타일 %d)" % [Fixtures.name_of(kind), tx])

	# **No two standing spots may overlap.** They can (the room is 40 tiles and the reach is 40px), and
	#  `Fixtures.at` would then answer "the nearer one" — a defensible answer to a question level design
	#  should never have asked. This is where that gets caught.
	var seats := TownMap.fixture_seats()
	var kinds: Array = seats.keys()
	for i in kinds.size():
		for j in range(i + 1, kinds.size()):
			var d := absf(float(seats[kinds[i]]) - float(seats[kinds[j]]))
			t.ok(d > Fixtures.REACH_PX * 2,
				"%s와 %s의 서는 자리가 안 겹친다 (%.0fpx > %dpx)" % [
					Fixtures.name_of(kinds[i]), Fixtures.name_of(kinds[j]), d, Fixtures.REACH_PX * 2])


# ══════════════════════════════════════════════════════════════════
#  2. The door — `Fixtures.at`, pure
# ══════════════════════════════════════════════════════════════════

## **Made-up seats, not the town's.** The question here is the lookup's own behaviour, and driving it with
##  the real room would tie this check to level design — move a bench and a check about arithmetic goes red.
func _the_door_answers_where_you_are_standing(t) -> void:
	var seats := {Fixtures.KIND_RESEARCH: 1000.0, Fixtures.KIND_GATE: 2000.0}
	t.eq(Fixtures.at(seats, 1000.0), Fixtures.KIND_RESEARCH, "설비 위에 서면 그 설비다")
	t.eq(Fixtures.at(seats, 1000.0 + Fixtures.REACH_PX), Fixtures.KIND_RESEARCH,
		"닿는 거리 끝까지는 그 설비다 (%dpx)" % Fixtures.REACH_PX)
	t.eq(Fixtures.at(seats, 1000.0 + Fixtures.REACH_PX + 1), -1, "한 걸음 더 가면 아무것도 아니다")
	t.eq(Fixtures.at(seats, 2000.0 - Fixtures.REACH_PX), Fixtures.KIND_GATE, "왼쪽에서 다가가도 닿는다")
	t.eq(Fixtures.at(seats, 1500.0), -1, "둘 사이 한가운데선 아무것도 아니다")
	t.eq(Fixtures.at({}, 1000.0), -1, "설비가 하나도 없으면 아무것도 아니다")

	# **The block's own far edge must be inside the reach.** This is the gap that was found by walking to the
	#  gate on screen and watching the prompt fail to appear at 41px (`Fixtures.REACH_PX`'s own box) — a band
	#  where the character is visibly standing on the fixture and nothing happens.
	for kind: int in Fx.TOWN_FIXTURES:
		var half := float(Fx.TOWN_FIXTURES[kind]["w"]) * Fx.TOWN_FIXTURE_ZOOM * 0.5
		t.ok(Fixtures.REACH_PX >= half,
			"닿는 거리가 %s 그림의 반폭보다 넓다 (%d >= %.0f — 설비 위에 서 있는데 안 뜨는 구간이 없다)" % [
				Fixtures.name_of(kind), Fixtures.REACH_PX, half])
	var widest := 0.0
	for kind: int in Fx.TOWN_FIXTURES:
		widest = maxf(widest, float(Fx.TOWN_FIXTURES[kind]["w"]) * Fx.TOWN_FIXTURE_ZOOM * 0.5)
	t.eq(Fixtures.at(seats, 1000.0 + widest), Fixtures.KIND_RESEARCH, "가장 넓은 설비의 끝에 서도 그 설비다")

	# **Overlapping seats: the nearer one.** Level design must not create this (measured above), but the
	#  function still has to answer, and "whichever the table listed first" is not an answer.
	var tight := {Fixtures.KIND_RESEARCH: 1000.0, Fixtures.KIND_ASSEMBLY: 1010.0}
	t.eq(Fixtures.at(tight, 1009.0), Fixtures.KIND_ASSEMBLY, "겹치면 더 가까운 쪽이다")
	t.eq(Fixtures.at(tight, 1001.0), Fixtures.KIND_RESEARCH, "반대쪽에서도 더 가까운 쪽이다")

	for kind: int in [Fixtures.KIND_RESEARCH, Fixtures.KIND_ASSEMBLY, Fixtures.KIND_GATE]:
		t.ok(String(Fixtures.name_of(kind)) != "", "%d번 설비에 이름이 있다" % kind)
	t.eq(String(Fixtures.name_of(-1)), "", "설비가 없으면 이름도 없다 (안내가 안 뜬다)")


## **The list is what the research bench *is* today** (`town.md`: "unlocked and locked sitting in one list is
##  the best possible demonstration that the pool widened"). So the thing measured is that locked really
##  reads as locked — a bench that showed everything open would make the pool look already-widened on run one.
func _the_research_bench_shows_locked_and_unlocked_together(t) -> void:
	var pr := Progress.new()
	var before := Stage.research_text(pr)
	t.ok(before.contains("잠김"), "처음엔 잠긴 룬이 보인다 (%s)" % before)
	t.ok(not pr.owns_rune(Tuning.ELEM_FIRE), "불 룬은 아직 없다 (전제)")

	pr.grant_rune(Tuning.ELEM_FIRE)
	var after := Stage.research_text(pr)
	t.ok(before != after, "룬을 얻으면 목록이 달라진다 (풀이 넓어진 것이 눈에 보인다)")
	# **Counted, not searched for.** "It contains 잠김" stays true with one rune unlocked and with none.
	t.eq(before.count("잠김") - after.count("잠김"), 1, "잠긴 룬이 정확히 하나 줄었다")
	for rune: int in Tuning.ELEM_ALL:
		var nm := str(Fx.ELEM_NAMES.get(rune, "?"))
		t.ok(after.contains(nm), "목록에 %s 룬이 (잠겼든 아니든) 들어 있다" % nm)


## The block is drawn standing on the room's floor. **Pure static on both sides** — no scene needed.
##  Off by anything and the benches float or sink, which reads as a bug in the terrain, not in the fixtures.
func _the_blocks_stand_on_the_floor(t) -> void:
	var floor_y := TownView.floor_y()
	t.eq(floor_y, float(TownMap.ROOM_Y1 + 1) * TILE_PX, "바닥선이 방의 바닥줄이다")
	var seats := TownMap.fixture_seats()
	for kind: int in seats:
		var r := TownView.fixture_rect(kind, float(seats[kind]))
		t.eq(r.end.y, floor_y, "%s 그림의 밑변이 바닥에 닿는다" % Fixtures.name_of(kind))
		t.eq(r.get_center().x, float(seats[kind]), "%s 그림이 자리 한가운데다" % Fixtures.name_of(kind))
		# **The character is 32px tall.** A fixture shorter than the player does not read as something you
		#  walk up to, and that is the whole reason `TOWN_FIXTURE_ZOOM` exists.
		t.ok(r.size.y > Character.H_PX,
			"%s가 캐릭터보다 크다 (%.0f > %d)" % [Fixtures.name_of(kind), r.size.y, Character.H_PX])
		# And it fits in the room, so nothing is drawn through the ceiling.
		t.ok(r.size.y < (TownMap.ROOM_Y1 - TownMap.ROOM_Y0 + 1) * TILE_PX,
			"%s가 방 천장을 안 뚫는다" % Fixtures.name_of(kind))


## **The art really loads, and the size in the table is the png's own size.** Both halves matter: a path typo
##  drops that fixture to the magenta fallback (visible but wrong), and a wrong size in the table stretches
##  the sprite — pixel art scaled by a non-integer factor is the one thing that reads as broken at a glance.
##
## **This is the check that would have caught what actually happened**: `assets/town/` and the two town
##  backdrops sat in the repo unused while the town rendered as coloured boxes in a black room.
func _the_fixture_art_is_loaded_at_its_own_size(t) -> void:
	var sprites := TownView.load_sprites()
	t.eq(sprites.size(), Fixtures.NAMES.size(), "설비 종류 수만큼 그림을 읽었다")
	for kind: int in Fx.TOWN_FIXTURES:
		var path: String = Fx.TOWN_FIXTURES[kind]["path"]
		var tex: Texture2D = sprites.get(kind)
		t.ok(tex != null, "%s 그림을 읽었다 (%s)" % [Fixtures.name_of(kind), path])
		if tex == null:
			continue
		t.eq(float(tex.get_width()), float(Fx.TOWN_FIXTURES[kind]["w"]),
			"%s 표의 폭이 png의 폭이다 (늘어나지 않는다)" % Fixtures.name_of(kind))
		t.eq(float(tex.get_height()), float(Fx.TOWN_FIXTURES[kind]["h"]),
			"%s 표의 높이가 png의 높이다" % Fixtures.name_of(kind))
	# **Integer zoom only.** A 1.5x upscale of pixel art gives some pixels twice the size of others.
	t.eq(Fx.TOWN_FIXTURE_ZOOM, floorf(Fx.TOWN_FIXTURE_ZOOM), "확대 배율이 정수다 (픽셀 크기가 안 섞인다)")


## **The town has its own backdrop and something actually calls for it.**
##  The two constants existed with the art on disk and **nothing ever called `set_backdrop` with them** —
##  `sky_background._ready` hardcoded the farm pair, so the town rendered black. This measures both halves:
##  the pictures load, and the shell names them.
func _the_town_has_its_own_backdrop(t) -> void:
	for path: String in [Fx.BG_TOWN_FAR_TEXTURE, Fx.BG_TOWN_NEAR_TEXTURE]:
		t.ok(load(path) != null, "마을 배경 그림을 읽는다 (%s)" % path)
	t.ok(Fx.BG_TOWN_FAR_TEXTURE != Fx.BG_FAR_TEXTURE,
		"마을 먼 배경이 무대 것과 다른 그림이다 (같으면 갈아 끼우는 의미가 없다)")
	t.ok(Fx.BG_TOWN_NEAR_TEXTURE != Fx.BG_NEAR_TEXTURE, "마을 가까운 배경도 다른 그림이다")
	# ══ Driven, not scanned — and the claim this replaced was wrong twice ══
	#
	# This used to open `stage.gd` and look for the literal `BG_TOWN_FAR_TEXTURE` in its source, on the
	#  stated grounds that "the backdrop cannot be read back off the node — `sky_background` keeps the
	#  textures private and exposes no accessor."
	#  **Both halves were false.** `net_background._set_backdrop_stores_the_pair_it_is_given` has always read
	#  them back with `get("_far")` and compared `resource_path`; and the shell no longer names the constant
	#  at all — the backdrop comes out of the room table now, so a text scan would have been looking for a
	#  string that is correctly absent.
	# **A scan measures a file's text, never what it computes** (CLAUDE.md). Building the town and reading
	#  what actually reached the node is the same question asked of the thing itself.
	var bg_root := _wired_root(t)
	t.ok(bg_root != null, "마을을 세운다 (전제)")
	if bg_root != null:
		var sky: Variant = bg_root.get("_sky")
		var far: Texture2D = sky.get("_far")
		var near: Texture2D = sky.get("_near")
		t.ok(far != null and near != null, "마을을 지으면 배경 두 장이 실제로 실린다 (전제)")
		if far != null and near != null:
			t.eq(far.resource_path, Fx.BG_TOWN_FAR_TEXTURE,
				"그리고 그게 마을 먼 배경이다 (무대 것이 아니라 — 방 표에서 나온 값이다)")
			t.eq(near.resource_path, Fx.BG_TOWN_NEAR_TEXTURE, "가까운 배경도 마을 것이다")
		bg_root.free()

	# **And the room has to be somewhere the backdrop can be seen.** This is the check for the bug that
	#  actually happened: the room was cut at tile rows 30-41, `sky_background` clamps the far picture at
	#  `BG_UNDER_TOP_Y` and fills everything below with the underground bands, and the town rendered **black
	#  with the right art loaded and the right constants set.** Nothing barked, because nothing was wrong —
	#  the room was simply underground.
	# **The floor is compared, not the ceiling.** A room whose floor is above the line but whose top pokes
	#  through would still show sky where the player stands, so the floor is the honest boundary.
	var floor_y := float(TownMap.ROOM_Y1 + 1) * TILE_PX
	t.ok(floor_y <= Fx.BG_UNDER_TOP_Y,
		"마을 바닥(%.0fpx)이 배경의 지면선(%.0fpx) 위다 (아래면 하늘 대신 땅속 띠가 덮는다)" % [
			floor_y, Fx.BG_UNDER_TOP_Y])


# ══════════════════════════════════════════════════════════════════
#  3. The wiring — driven through the real scene
# ══════════════════════════════════════════════════════════════════

## **The research window's art.** Same shape as the fixture check above and for the same reason: a path typo
##  drops the window to its flat-parchment fallback, which is visible but wrong, and nothing else notices.
func _the_research_window_art_loads(t) -> void:
	t.ok(load(Fx.RESEARCH_PANEL) != null, "연구 패널 그림을 읽는다")
	var sheet: Texture2D = load(Fx.RESEARCH_SLOT_SHEET)
	t.ok(sheet != null, "슬롯 시트를 읽는다")
	if sheet != null:
		# **Both cuts must be inside the sheet.** A source rect past the right edge draws transparent — the
		#  slot frame silently vanishes and the icons float on bare parchment.
		for src: Rect2 in [Fx.RESEARCH_SLOT_LOCKED_SRC, Fx.RESEARCH_SLOT_OPEN_SRC]:
			t.ok(Rect2(0.0, 0.0, sheet.get_width(), sheet.get_height()).encloses(src),
				"슬롯 조각 %s이 시트(%dx%d) 안이다" % [src, sheet.get_width(), sheet.get_height()])
		t.ok(not Fx.RESEARCH_SLOT_LOCKED_SRC.intersects(Fx.RESEARCH_SLOT_OPEN_SRC),
			"잠긴 조각과 빈 조각이 안 겹친다 (자물쇠가 빈 칸에 묻어 나오지 않는다)")
	var icons := ResearchWindow.load_icons()
	t.eq(icons.size(), Fx.RESEARCH_ICONS.size(), "아이콘을 표에 적힌 수만큼 읽었다 (%d개)" % Fx.RESEARCH_ICONS.size())
	for key: String in Fx.RESEARCH_ICONS:
		t.ok(icons.get(key) != null, "%s 아이콘을 읽었다 (%s)" % [key, Fx.RESEARCH_ICONS[key]])
	# **Every row's icon key must exist**, or that row draws with no icon and the slot frame looks empty.
	for entry: Array in Fx.RESEARCH_ROWS:
		t.ok(icons.has(entry[0]), "%s 줄의 아이콘 열쇠(%s)가 표에 있다" % [entry[1], entry[0]])


## **The nine slices cover the window exactly, once, with no gap and no overlap** — and the four corners are
##  drawn at their source size, never scaled.
##
## **Area is not enough on its own**: nine rects can sum to the right area while sitting in the wrong places.
##  So the corners are checked by position *and* size, and the total is checked as an area — the pair catches
##  both "a corner got stretched" and "an edge slice is the wrong length".
func _the_panel_slices_tile_the_window_exactly(t) -> void:
	var tex_size := Vector2(512.0, 512.0)
	var b := Fx.RESEARCH_PANEL_BORDER_PX
	for win: Rect2 in [Fx.RESEARCH_RECT, Rect2(0.0, 0.0, 300.0, 200.0), Rect2(10.0, 20.0, 600.0, 500.0)]:
		var slices := ResearchLayout.nine(win, tex_size, b)
		t.eq(slices.size(), 9, "%s에서 조각이 아홉이다" % win)
		var area := 0.0
		for pair: Array in slices:
			var src: Rect2 = pair[0]
			var dst: Rect2 = pair[1]
			area += dst.size.x * dst.size.y
			t.ok(dst.size.x >= 0.0 and dst.size.y >= 0.0, "%s 조각 크기가 음수가 아니다" % win)
			t.ok(Rect2(Vector2.ZERO, tex_size).encloses(src), "원본 조각 %s이 그림 안이다" % src)
		t.eq(area, win.size.x * win.size.y, "%s에서 아홉 조각의 넓이 합이 창 넓이와 같다 (틈도 겹침도 없다)" % win)
		# The four corners, 1:1 and in the four corners. **This is the whole point of a 9-slice** — stretch a
		#  carved stone corner and it smears, and an area check alone cannot see that.
		var corners := {0: win.position, 2: Vector2(win.end.x - b, win.position.y),
			6: Vector2(win.position.x, win.end.y - b), 8: win.end - Vector2(b, b)}
		for i: int in corners:
			var dst: Rect2 = slices[i][1]
			t.eq(dst.size, Vector2(b, b), "%s의 %d번 모서리가 원본 크기 그대로다 (안 늘어난다)" % [win, i])
			t.eq(dst.position, corners[i], "%s의 %d번 모서리가 제자리다" % [win, i])


## The four rows stack inside the panel's own inside, in order, without overlapping — and there is room left
## for the footer that says nothing is buyable.
func _the_rows_stack_inside_the_panel(t) -> void:
	var size := Fx.RESEARCH_RECT.size
	var rows := ResearchLayout.rows(size)
	t.eq(rows.size(), Fx.RESEARCH_ROWS.size(), "줄이 표에 적힌 수만큼 나온다 (%d줄)" % Fx.RESEARCH_ROWS.size())
	var inner := ResearchLayout.inner(size)
	for i in rows.size():
		t.ok(inner.encloses(rows[i]), "%d번 줄이 패널 안쪽에 들어간다" % i)
		t.ok(rows[i].size.y > 0.0, "%d번 줄에 높이가 있다" % i)
		# The slot frame and the text after it both fit.
		t.ok(inner.encloses(ResearchLayout.slot(rows[i])), "%d번 줄의 슬롯 틀이 패널 안이다" % i)
		t.ok(ResearchLayout.text_x(rows[i]) < inner.end.x, "%d번 줄의 글이 시작할 자리가 남는다" % i)
		# **Both text baselines inside the row** — the state line used to be placed from the row's centre and
		#  its descender ran past the bottom, so the last row's "잠김" collided with the footer on screen.
		#  Measured as a value now, because "does it overlap" is exactly what the eye had to catch.
		var base: Array = ResearchLayout.text_baselines(rows[i])
		t.ok(base[0] > rows[i].position.y and base[0] <= rows[i].end.y,
			"%d번 줄의 이름 글자가 줄 안이다" % i)
		t.ok(base[1] > base[0] and base[1] <= rows[i].end.y,
			"%d번 줄의 상태 글자가 이름 아래이면서 줄 안이다" % i)
		if i > 0:
			t.ok(rows[i].position.y >= rows[i - 1].end.y, "%d번 줄이 앞 줄 아래다 (안 겹친다)" % i)
	# The material line above and the footer below both sit inside, and clear of the rows.
	var mat := ResearchLayout.material_line(size)
	var foot := ResearchLayout.footer_line(size)
	t.ok(inner.encloses(mat) and inner.encloses(foot), "재료 줄과 바닥 줄이 패널 안이다")
	t.ok(mat.end.y <= rows[0].position.y, "재료 줄이 첫 줄 위다")
	t.ok(foot.position.y >= rows[rows.size() - 1].end.y, "바닥 줄이 마지막 줄 아래다")


## **The item row is the rune pool, and locked reads as locked.** `town.md` keeps "item unlock" and the GDD's
##  "pool" as one thing on purpose, so this is the row that has to move when a rune is earned.
func _the_item_row_is_the_rune_pool(t) -> void:
	var pr := Progress.new()
	var before := ResearchWindow.row_state("item", pr)
	pr.grant_rune(Tuning.ELEM_FIRE)
	var after := ResearchWindow.row_state("item", pr)
	t.ok(before != after, "룬을 얻으면 아이템 줄이 달라진다 (풀이 넓어진 것이 이 줄에서 보인다)")
	t.eq(before.count(Fx.RESEARCH_LOCKED_TEXT) - after.count(Fx.RESEARCH_LOCKED_TEXT), 1,
		"잠긴 룬이 정확히 하나 줄어든다")
	# **The other three rows do not move**, because nothing unlocks them — and saying "잠김" is the true
	#  thing about them, not a placeholder.
	for entry: Array in Fx.RESEARCH_ROWS:
		if entry[0] == "item":
			continue
		t.eq(ResearchWindow.row_state(entry[0], pr), Fx.RESEARCH_LOCKED_TEXT,
			"%s 줄은 룬을 얻어도 그대로 잠김이다 (해금이 아예 없다)" % entry[1])
	t.eq(ResearchWindow.row_state("item", null), Fx.RESEARCH_LOCKED_TEXT,
		"진행 상태가 없으면 잠김으로 떨어진다 (터지지 않는다)")


## **The half the two sections above cannot see.** The room can be perfect and the lookup can be perfect
##  while E is connected to nothing, and both would stay green.
##
## **The loop is measured in both directions**: the gate really leaves the town, and being downed really
##  brings you back. One direction alone is a door that only opens outward.
func _the_gate_leaves_and_being_downed_comes_back(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return

	t.ok(bool(root.get("_in_town")), "게임은 마을에서 시작한다 (전제 — 달리기가 여기서 닫힌다)")
	var ch: Variant = root.get("_char")
	var seats := TownMap.fixture_seats()
	# **The town's own wall is there before we leave** — without this, the "no longer bedrock" check below
	#  would pass for a room that was never built in the first place.
	t.eq((root.get("_grid") as Object).call("mat_at", (TownMap.ROOM_X0 - 1) * TILE_CELLS,
			(TownMap.ROOM_Y0 + TownMap.ROOM_Y1) / 2 * TILE_CELLS), Mat.BEDROCK,
		"마을에 있는 동안 그 자리는 기반암 벽이다 (전제)")

	# **Standing nowhere: E does nothing.** Measured first, so "E always leaves" cannot pass.
	_stand_at(ch, (float(seats[Fixtures.KIND_RESEARCH]) + float(seats[Fixtures.KIND_ASSEMBLY])) * 0.5)
	root.call("_interact")
	t.ok(bool(root.get("_in_town")), "설비 사이에서 E를 눌러도 마을에 남는다")

	# The research bench speaks, and what it says is the rune list.
	_stand_at(ch, float(seats[Fixtures.KIND_RESEARCH]))
	var window: Variant = root.get("_research_window")
	t.ok(not bool(window.visible), "연구창은 닫힌 채로 시작한다 (전제)")
	root.call("_interact")
	t.ok(String(root.get("_town_message")).contains("연구대"), "연구대 앞에서 E를 누르면 연구대가 말한다")
	t.ok(bool(window.visible), "그리고 연구창이 열린다")
	t.ok(bool(root.get("_in_town")), "마을에도 남는다")
	root.call("_interact")
	t.ok(not bool(window.visible), "한 번 더 누르면 닫힌다")
	# Open it again, so the gate below has something to close.
	root.call("_interact")
	t.ok(bool(window.visible), "다시 열었다 (아래 검사의 전제)")

	# The gate leaves.
	_stand_at(ch, float(seats[Fixtures.KIND_GATE]))
	root.call("_interact")
	t.ok(not bool(root.get("_in_town")), "출발문 앞에서 E를 누르면 마을을 떠난다")
	t.eq(String(root.get("_town_message")), "", "떠나면서 마을의 말은 지워진다")
	t.ok(not bool((root.get("_research_window") as Object).get("visible")),
		"연구창도 같이 닫힌다 (마을의 양피지가 무대 1 위에 남지 않는다)")
	# **The room really changed** — the flag flipping without the terrain following would be the flag lying.
	var grid: Variant = root.get("_grid")
	var wall_x := (TownMap.ROOM_X0 - 1) * TILE_CELLS
	var mid_y := (TownMap.ROOM_Y0 + TownMap.ROOM_Y1) / 2 * TILE_CELLS
	t.ok(grid.mat_at(wall_x, mid_y) != Mat.BEDROCK,
		"떠난 뒤 그 자리는 더 이상 마을의 기반암 벽이 아니다 (깃발만 바뀌고 지형이 안 따라오면 여기가 빨개진다)")
	t.eq(Vector2i(ch.x, ch.y),
		Vector2i(Stage.SPAWN_TILE.x * TILE_PX, Stage.SPAWN_TILE.y * TILE_PX),
		"그리고 무대 1의 출발 자리에 서 있다")

	# **E in the stage does nothing while standing** — otherwise it would be a free escape from a fight.
	root.call("_interact")
	t.ok(not bool(root.get("_in_town")), "무대에서 멀쩡할 때 E는 아무 일도 안 한다")

	# **Downed: the door moved** (`run-end-settlement.md`). E while downed no longer goes
	#  home by itself — the settlement screen opens on its own instead, and now *its* button is what closes
	#  the run. This is the only check in the suite that measures the whole loop actually closing end to end:
	#  downed -> the panel opens -> the button -> the town.
	ch.take_hit(Character.MAX_HP, false)
	t.ok(bool(ch.downed), "쓰러졌다 (전제)")
	root.call("_interact")
	t.ok(not bool(root.get("_in_town")), "쓰러진 채 E를 눌러도 더는 마을로 안 돌아간다 (그 문은 사라졌다)")

	root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.call("is_showing")), "대신, 쓰러지고 한 프레임만 지나도 정산 화면이 저절로 열린다")

	# **The signal's own connection lives in `_ready()`, which never runs outside the tree** (this file's own
	#  wiring discipline, `_wired_root`'s header) — the same reason every other window here is driven by
	#  calling its target function directly rather than emitting the input signal that would reach it in the
	#  real game (`_toggle_pick`/`_toggle_assembly` above are called the same way). `enter_town` is exactly
	#  what `stage.gd`'s own `_settlement.town_pressed.connect(enter_town)` would have run.
	root.call("enter_town")
	t.ok(bool(root.get("_in_town")), "정산 화면의 버튼이 하는 일(enter_town)을 실행하면 마을로 돌아온다")
	t.eq(Vector2i(ch.x, ch.y),
		Vector2i(TownMap.SPAWN_TILE.x * TILE_PX, TownMap.SPAWN_TILE.y * TILE_PX),
		"마을의 출발 자리에 서 있다")
	t.ok(not ch.downed, "그리고 다시 서 있다 (달리기가 닫히고 새로 시작한다)")
	t.ok(not bool(settlement.call("is_showing")), "마을로 돌아오면서 정산 화면도 닫힌다 (reset_stage()가 닫는다)")

	root.free()


## Puts the character's **centre** at `x` — `Fixtures.at` takes a centre, and placing by the left edge would
##  put every check half a body off, which at a 40px reach is enough to change the answer.
func _stand_at(ch: Variant, center_x: float) -> void:
	ch.place(int(center_x - Character.W_PX * 0.5), TownMap.SPAWN_TILE.y * TILE_PX)


## **The same wiring `net_render._wired_stage_root` does, cut down to what `_interact` needs.**
##  It is duplicated rather than shared for this repo's usual reason — each net runs in its own process, so
##  there is no shared base class (`net_water_rain`'s header states the same policy).
##  **The node names are not invented here**: `net_render` asserts every one of them exists in the scene, so
##  a renamed node goes red there first, by name, rather than as a null crash here.
func _wired_root(t) -> Node:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세웠다 (전제)")
	if scene == null or not scene.can_instantiate():
		return null
	var root := scene.instantiate()
	for pair: Array in [["_hud", "HUD/Stats"], ["_hp_view", "HUD/HpBar"],
			["_levelup_label", "HUD/LevelUp"],
			["_spell_view", "SpellView"], ["_blast_fx", "BlastFx"],
			["_circle_window", "HUD/CircleWindow"], ["_pick_window", "HUD/ThreePickWindow"],
			["_camera", "Camera2D"], ["_monster_view", "MonsterView"],
			["_renderer", "CellRenderer"], ["_town_view", "TownView"], ["_input", "StageInput"],
			# `_build_room()` swaps the backdrop, so this is no longer optional either — the same way
			#  `_town_view` became required one feature earlier.
			["_sky", "SkyBackground"],
			# `_interact()` reaches the research window now, and `_build_room()` closes it.
			["_research_window", "HUD/ResearchWindow"],
			# **`_settlement`** (`run-end-settlement.md`, Stage D) — `reset_stage()`'s own
			#  last line below now calls `_settlement.close()`, so every check in this file dies on a null
			#  before measuring anything without this.
			["_settlement", "HUD/SettlementWindow"],
			# **`_gate_view`** (`stage-clear-sequence.md`) — `_sync_settlement()` now calls `tick_gate()` on it
			#  every physics frame and `reset_stage()` calls `reset_gate()`, both unconditionally. Left out,
			#  every check in this file that drives either one dies on a null mid-call and **disappears rather
			#  than fails** — the shape this file's own `if root == null: return` discipline exists for.
			["_gate_view", "GateView"],
			# **`_boss_bar`** (`boss-entrance-and-hp-bar.md` Stage C) — `reset_stage()` (via `_rebuild()`)
			#  and `_physics_process()` both touch it unconditionally now (`clear_boss()`/
			#  `set_entrance_frames()`). Left out, `root.call("reset_stage")` a few lines below crashes on a
			#  null mid-call, the same risk this file's own comment already names for `_gate_view` one line up.
			["_boss_bar", "HUD/BossBar"]]:
		var n := root.get_node_or_null(NodePath(pair[1]))
		t.ok(n != null, "씬에 %s 가 있다 (전제)" % pair[1])
		if n == null:
			root.free()
			return null
		root.set(pair[0], n)
	root.get_node("CellRenderer").call("setup", root.get("_grid"))
	root.get_node("TownView").call("setup", root.get("_char"))
	root.get_node("SkyBackground").call("setup", root.get_node("Camera2D"))
	root.get_node("HUD/ResearchWindow").call("setup", (root.get("_world") as Object).call("progress"))
	# `_ready()` never runs outside the tree, so the room is built by hand — the same call `reset_stage()`
	#  makes, through the shell's own door rather than by reaching for `build_map_into` directly.
	root.call("reset_stage")
	return root
