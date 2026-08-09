extends RefCounted
## The room table — `src/stage/stage_defs.gd`, `stage.gd._apply_room()`, `stage_gate.set_geometry()` and
## `terrain_baker.bake()`'s two arguments.
##
## **What this file exists to catch is a bug that cannot happen yet**: a second stage added to the table
## while one of its per-stage fields silently keeps stage 1's value. With one stage in the table, a
## "every row's seat is distinct" check would loop zero times and pass on nothing (CLAUDE.md's own
## "a loop whose condition is false from the start"), and a "row 1 equals stage 1's constants" check is a
## tautology once the row references those constants.
##
## ⇒ **The measurement is a synthetic row driven through the real shell.** `_apply_room()` takes the row as
## an argument for exactly this reason: hand it a room whose map, character table, spawn, monster table,
## gate and title all differ from stage 1's, and every one of those has to show up in the world. A field
## left reading a stage-1 constant does not follow, and this net names which one.

const StageDefs := preload("res://src/stage/stage_defs.gd")
const Stage := preload("res://src/stage/stage.gd")
const StageGate := preload("res://src/actor/stage_gate.gd")
const TownMap := preload("res://src/stage/town_map.gd")
const TerrainMap := preload("res://src/stage/terrain_map_generated.gd")
const Stage1Monsters := preload("res://src/stage/stage1_monsters.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const SettlementWindow := preload("res://src/view/settlement_window.gd")
const Baker := preload("res://tools/stage/terrain_baker.gd")

const STAGE_SCENE := "res://src/stage/stage.tscn"

## Where the baker probe writes. **`user://`, never `res://`** — a bake aimed at the real artifact would
## rewrite a checked-in file from inside a test run.
const PROBE_OUT := "user://net_stages_bake_probe.gd"

## ══ The synthetic room's numbers, all of them different from stage 1's and from the town's ══
##  Kept as named constants so the checks below read as "the value the row carried", not as bare literals
##  that happen to match.
const SYN_SPAWN := Vector2i(7, 3)
const SYN_MONSTER_TX := 111
const SYN_SEAT_TX := 100
const SYN_FLOOR_TY := 30
const SYN_WALL_TX0 := 90
const SYN_WALL_TX1 := 91
const SYN_WALL_TY0 := 10
const SYN_WALL_TY1 := 11
const SYN_TITLE := "합성 스테이지 클리어"

## The column the grid is probed at — mid-map, so it is inside every room's own width.
const PROBE_TX := 150

## A width that is **not** stage 1's, for the "width is per-stage" check.
const NARROW_W := 100


## **A map script that is not either real one.** `stage_defs.map_rows()` calls `rows()` on whatever the row's
## `map` field holds, so a synthetic stage needs nothing but this shape — which is itself the claim being
## measured: adding a stage does not mean editing a `match` somewhere.
##
## **Row 0 uses `#` and every other row uses `S`, and neither means what stage 1 means by them.** `#` is
## stone in the real table and **wood** in the synthetic one; `S` is not in the real table at all. That is
## what separates "the map came from the row" from "the character table came from the row" — one check each,
## below.
class _SyntheticMap:
	const TM := preload("res://src/stage/terrain_map_generated.gd")
	static func rows() -> Array[String]:
		var out: Array[String] = []
		for ty in TM.MAP_H:
			out.append(("#" if ty == 0 else "S").repeat(TM.MAP_W))
		return out


## Catches the title `_draw()` actually paints. **`_draw_title` is the production hook `net_settlement`
## already overrides for the same reason** — GDScript refuses to override the native `draw_string`, and
## counting `_draw()` calls measures the engine, not the picture.
class _CapturingSettlement extends SettlementWindow:
	var painted := ""
	var paints := 0
	func _draw_title(font: Font, title: String, pos: Vector2) -> void:
		painted = title
		paints += 1
		super(font, title, pos)


func run(t) -> void:
	_every_row_carries_every_field(t)
	_stage_ones_row_is_the_stage_that_used_to_be_scattered(t)
	_an_unknown_room_barks_and_falls_back_to_the_town(t)
	_both_map_scripts_answer_the_same_accessor(t)
	_a_maps_width_is_its_own_and_its_height_is_not(t)
	await _apply_room_reads_every_field_out_of_the_row(t)
	await _the_room_the_shell_builds_comes_from_the_stage_id(t)
	await _the_panel_paints_the_title_the_room_carried(t)
	_the_baker_writes_where_it_is_told(t)
	_the_baker_reads_the_layer_it_is_told(t)


# ══════════════════════════════════════════════════════════════════
#  The table itself
# ══════════════════════════════════════════════════════════════════

## **The check a forgotten field dies on.** Adding a stage 2 row that omits `gate` (or `title`, or
## `monsters`) is the single most likely way this table gets it wrong, and without this the omission would
## surface as a null deref two files away — or worse, as stage 2 quietly keeping stage 1's gate.
func _every_row_carries_every_field(t) -> void:
	t.ok(StageDefs.ROWS.size() >= 2,
		"방 표에 마을과 스테이지가 모두 있다 (%d행)" % StageDefs.ROWS.size())
	t.eq(StageDefs.REQUIRED_KEYS.size(), 6, "필수 열쇠가 6개다 (전제 — 목록이 비면 아래 루프가 안 돈다)")
	var checked := 0
	for i in StageDefs.ROWS.size():
		var row: Dictionary = StageDefs.ROWS[i]
		for key: String in StageDefs.REQUIRED_KEYS:
			t.ok(row.has(key), "%d번 방이 '%s' 를 들고 있다" % [i, key])
			checked += 1
	t.eq(checked, StageDefs.ROWS.size() * 6, "모든 행 × 모든 열쇠를 실제로 돌았다 (%d번)" % checked)

	# **A stage is not a town.** Every row from 1 up must be able to be cleared and to be left.
	var stages := 0
	for i in range(StageDefs.STAGE_1, StageDefs.ROWS.size()):
		stages += 1
		var row: Dictionary = StageDefs.ROWS[i]
		var gate: Dictionary = row["gate"]
		t.ok(not gate.is_empty(), "%d번 스테이지에 나가는 문이 있다 (빈 문이면 못 끝낸다)" % i)
		for key: String in StageDefs.GATE_KEYS:
			t.ok(gate.has(key), "%d번 스테이지의 문이 '%s' 를 들고 있다" % [i, key])
		t.ok(not String(row["title"]).is_empty(),
			"%d번 스테이지에 클리어 제목이 있다 (빈 제목이면 정산 화면이 이름을 못 부른다)" % i)
		t.ok(not (row["monsters"] as Array).is_empty(), "%d번 스테이지에 몬스터 표가 있다" % i)
	t.eq(stages, StageDefs.ROWS.size() - 1, "스테이지 행을 하나도 안 빼고 돌았다 (%d개)" % stages)

	# The town is the one room that has none of those, and it says so rather than carrying stage 1's.
	var town: Dictionary = StageDefs.ROWS[StageDefs.ROOM_TOWN]
	t.ok((town["gate"] as Dictionary).is_empty(), "마을에는 나가는 문이 없다")
	t.ok((town["monsters"] as Array).is_empty(), "마을에는 몬스터가 없다")
	t.eq(String(town["title"]), "", "마을에는 클리어 제목이 없다 (마을은 깨는 곳이 아니다)")


## **A pin, not a tautology.** The row references `stage_gate.gd`'s and `stage1_monsters.gd`'s own
## constants, so these cannot drift — what they catch is somebody typing literals into the row instead,
## which is precisely how "the table says one thing and the game does another" starts.
func _stage_ones_row_is_the_stage_that_used_to_be_scattered(t) -> void:
	var row := StageDefs.row(StageDefs.STAGE_1)
	var rows := StageDefs.map_rows(row)
	t.eq(rows.size(), TerrainMap.MAP_H, "스테이지1 행의 지도가 구운 지도와 같은 높이다")
	t.eq(rows[0].length(), TerrainMap.MAP_W, "그리고 같은 너비다")
	t.eq(rows[20], TerrainMap.MAP[20], "가운데 한 줄이 구운 지도의 그 줄 그대로다")
	t.eq(row["chars"], TerrainMap.MAP_CHARS, "글자표도 구운 지도의 것 그대로다")
	t.eq(row["spawn"], Stage.SPAWN_TILE, "출발 타일이 무대가 내보내는 값과 같다")
	t.eq((row["monsters"] as Array).size(), Stage1Monsters.ROWS.size(),
		"몬스터 표가 스테이지1의 표 그대로다 (%d행)" % Stage1Monsters.ROWS.size())
	var gate: Dictionary = row["gate"]
	t.eq(int(gate["seat_tx"]), StageGate.STAGE1_SEAT_TILE_X, "문 자리가 스테이지1의 열이다")
	t.eq(int(gate["floor_ty"]), StageGate.STAGE1_FLOOR_TILE_Y, "문 바닥이 스테이지1의 행이다")
	t.eq(int(gate["wall_tx0"]), StageGate.STAGE1_WALL_TILE_X0, "동쪽 벽 왼쪽 열이 스테이지1의 것이다")
	t.eq(int(gate["wall_tx1"]), StageGate.STAGE1_WALL_TILE_X1, "동쪽 벽 오른쪽 열도 그렇다")
	t.eq(int(gate["wall_ty0"]), StageGate.STAGE1_WALL_TILE_Y0, "동쪽 벽 윗 행도 그렇다")
	t.eq(int(gate["wall_ty1"]), StageGate.STAGE1_WALL_TILE_Y1, "동쪽 벽 아랫 행도 그렇다")
	t.eq(String(row["title"]), Fx.SETTLEMENT_TITLE_CLEAR, "클리어 제목이 정산 화면의 그 문장이다")
	# **The floor row is global, and this is where that is stated as a value.** It derives from the map
	#  height, which `build_map_into`'s guard holds at 48 tiles for every room.
	t.eq(StageDefs.FLOOR_CY, TerrainMap.MAP_H * Tuning.TILE_CELLS - 1,
		"배치용 바닥 행이 지도 높이에서 나온다 (스테이지마다 다른 값이 아니다)")


## **An id nobody put in the table must not return an empty row.** An empty Dictionary would build no map
## at all and read on screen as "R did nothing" — this repo's own signature silent shape.
func _an_unknown_room_barks_and_falls_back_to_the_town(t) -> void:
	t.expect_error("no room 99 in the table")
	var row := StageDefs.row(99)
	t.eq(row, StageDefs.ROWS[StageDefs.ROOM_TOWN], "표에 없는 방을 물으면 짖고 마을을 돌려준다")
	t.expect_error("no room -1 in the table")
	t.eq(StageDefs.row(-1), StageDefs.ROWS[StageDefs.ROOM_TOWN], "음수도 마찬가지다")


## **The one thing that lets the table hold a script instead of a `match`.** Both real map scripts answer
## `rows()`, and the baker emits that function so a redraw cannot delete it.
func _both_map_scripts_answer_the_same_accessor(t) -> void:
	var town := StageDefs.map_rows(StageDefs.row(StageDefs.ROOM_TOWN))
	t.eq(town.size(), TerrainMap.MAP_H, "마을 지도가 rows()로 나온다 (%d줄)" % town.size())
	t.eq(town, TownMap.rows(), "그리고 그건 마을 지도가 스스로 만드는 바로 그 줄들이다")
	t.eq(TerrainMap.rows(), TerrainMap.MAP, "구운 지도의 rows()는 MAP 그대로다")


## **The one decision this feature was given, driven as a value: width is per-stage, height is global.**
##
## `build_map_into()` used to compare every row against `MAP_W` — stage 1's own re-export — so a stage 2 of
## any other width would have been refused with nothing but a `push_error` to say why. It now takes the
## width from the map it was handed. **The height guard is deliberately left alone**: 48 tiles is what the
## town's room, the background's depth banding and the placement floor row all hang off, so a map of another
## height is refused **on purpose**, and that refusal is measured here rather than assumed from reading it.
func _a_maps_width_is_its_own_and_its_height_is_not(t) -> void:
	var mid_cy := 4
	var narrow: Array[String] = []
	for _ty in TerrainMap.MAP_H:
		narrow.append("S".repeat(NARROW_W))
	var g := CellGrid.new()
	Stage.build_map_into(g, narrow, {"S": Mat.STONE})
	t.eq(g.mat_at((NARROW_W / 2) * Tuning.TILE_CELLS + 4, mid_cy), Mat.STONE,
		"스테이지1보다 좁은 지도가 짖지 않고 그대로 지어진다 (너비는 스테이지마다 다르다)")
	t.eq(g.mat_at((NARROW_W + 10) * Tuning.TILE_CELLS + 4, mid_cy), Mat.EMPTY,
		"그리고 그 지도가 없는 열은 비어 있다 (스테이지1 너비까지 늘려 짓지 않는다)")

	# **Ragged rows still bark** — the width became the map's own, not "whatever each row felt like".
	var ragged := narrow.duplicate()
	ragged[1] = "S".repeat(NARROW_W - 1)
	t.expect_error("MAP row 1 is %d wide" % (NARROW_W - 1))
	var g2 := CellGrid.new()
	Stage.build_map_into(g2, ragged, {"S": Mat.STONE})
	t.eq(g2.mat_at(4, 5 * Tuning.TILE_CELLS + 4), Mat.EMPTY,
		"줄마다 너비가 다르면 짖고 거기서 멈춘다")

	# **Wider than the grid barks too.** It used to be clipped in silence, which reads on screen as terrain
	#  full of holes — the baker already refuses to write such a map, and now the builder refuses to build one.
	var too_wide: Array[String] = []
	var over_w := CellGrid.W / Tuning.TILE_CELLS + 1
	for _ty in TerrainMap.MAP_H:
		too_wide.append("S".repeat(over_w))
	t.expect_error("MAP is %d tiles wide" % over_w)
	var g3 := CellGrid.new()
	Stage.build_map_into(g3, too_wide, {"S": Mat.STONE})
	t.eq(g3.mat_at(4, mid_cy), Mat.EMPTY, "격자보다 넓은 지도는 짖고 한 칸도 안 짓는다")

	# **The height is global and this is the refusal.** A stage of another height is not a thing this build
	#  can hold — see `build_map_into`'s own comment for what has to be answered first.
	var short_map: Array[String] = []
	for _ty in TerrainMap.MAP_H - 1:
		short_map.append("S".repeat(NARROW_W))
	t.expect_error("MAP has %d rows" % (TerrainMap.MAP_H - 1))
	var g4 := CellGrid.new()
	Stage.build_map_into(g4, short_map, {"S": Mat.STONE})
	t.eq(g4.mat_at(4, mid_cy), Mat.EMPTY,
		"높이가 다른 지도는 짖고 한 칸도 안 짓는다 (높이는 방마다 다르지 않다 — 정해진 것이다)")


# ══════════════════════════════════════════════════════════════════
#  The shell, driven with a room that is not stage 1
# ══════════════════════════════════════════════════════════════════

## **The check this whole file was written for.** Every field of the synthetic row must reach the world.
##
## **Measured inversion, one per field**: point any one of `_apply_room()`'s reads back at stage 1's
## constant — `Stage1Monsters.ROWS` instead of `room["monsters"]`, `SPAWN_TILE` instead of `room["spawn"]`,
## `Fx.SETTLEMENT_TITLE_CLEAR` instead of `room["title"]`, dropping the `set_geometry()` call, or building
## `MAP`/`MAP_CHARS` instead of the row's — and exactly the corresponding check below goes red while the
## rest stay green. That one-to-one is the point: a red line here names the field, not just the file.
func _apply_room_reads_every_field_out_of_the_row(t) -> void:
	var root: Node = await _treed_stage(t)
	if root == null:
		return

	var grid: Variant = root.get("_grid")
	var world: Variant = root.get("_world")
	var ch: Variant = root.get("_char")
	t.ok(grid != null and world != null and ch != null, "셸이 격자·세계·캐릭터를 잡고 있다 (전제)")
	if grid == null or world == null or ch == null:
		_drop_stage(t, root)
		return

	var monsters: Array[Dictionary] = [{"tx": SYN_MONSTER_TX, "kind": MonsterDefs.KIND_PIG}]
	var synthetic := {
		"map": _SyntheticMap,
		"chars": {"S": Mat.STONE, "#": Mat.WOOD},
		"spawn": SYN_SPAWN,
		"monsters": monsters,
		"gate": {
			"seat_tx": SYN_SEAT_TX, "floor_ty": SYN_FLOOR_TY,
			"wall_tx0": SYN_WALL_TX0, "wall_tx1": SYN_WALL_TX1,
			"wall_ty0": SYN_WALL_TY0, "wall_ty1": SYN_WALL_TY1,
		},
		"title": SYN_TITLE,
	}

	# **Wiped first, so what is read back was written by this call and not left over from `_ready()`'s own
	#  town build.** Without it the two checks below could pass on the town's bedrock never being overwritten.
	(grid as Object).call("apply", CellGrid.cmd_reset())
	var mid_cx := PROBE_TX * Tuning.TILE_CELLS + 4
	t.eq((grid as Object).call("mat_at", mid_cx, 4), Mat.EMPTY, "지우고 시작한다 (전제)")

	(root as Object).call("_apply_room", synthetic)

	# ── the map came from the row ──
	# Row 5 is `S`, which the real character table does not contain at all: build stage 1's map here and
	#  this cell is sky, build stage 1's *chars* and `S` is skipped — either way it is not stone.
	t.eq((grid as Object).call("mat_at", mid_cx, 5 * Tuning.TILE_CELLS + 4), Mat.STONE,
		"행이 들고 온 지도가 실제로 격자에 들어갔다 (5행이 돌이다)")
	# ── the character table came from the row ──
	# Row 0 is `#`, which the synthetic table calls **wood** and the real one calls stone. This is the one
	#  check that separates "the map came from the row" from "the glyph table came from the row".
	t.eq((grid as Object).call("mat_at", mid_cx, 4), Mat.WOOD,
		"행이 들고 온 글자표를 썼다 (#을 돌이 아니라 나무로 읽었다)")

	# ── the spawn came from the row ──
	var tile_px := Tuning.TILE_CELLS * Tuning.CELL_PX
	t.eq(int((ch as Object).get("x")), SYN_SPAWN.x * tile_px, "행이 들고 온 자리에 캐릭터가 섰다 (x)")
	t.eq(int((ch as Object).get("y")), SYN_SPAWN.y * tile_px, "행이 들고 온 자리에 캐릭터가 섰다 (y)")

	# ── the monster table came from the row ──
	var placement: Variant = (world as Object).get("_placement")
	t.ok(placement != null, "세계가 배치를 잡고 있다 (전제)")
	if placement != null:
		t.eq(int((placement as Object).call("row_count")), 1,
			"행이 들고 온 몬스터 표가 들어갔다 (스테이지1의 32행이 아니다)")
		t.eq(int((placement as Object).call("tx_at", 0)), SYN_MONSTER_TX, "그 표의 열까지 그대로다")

	# ── the gate geometry came from the row ──
	t.eq(StageGate.seat_px(), (float(SYN_SEAT_TX) + 0.5) * float(StageGate.TILE_PX),
		"행이 들고 온 문 자리가 실제로 밀려 들어갔다")
	t.eq(StageGate.floor_y_px(), float(SYN_FLOOR_TY) * float(StageGate.TILE_PX),
		"문의 바닥선도 그렇다")
	var wall := StageGate.wall_cells()
	t.eq(wall.position.x, SYN_WALL_TX0 * Tuning.TILE_CELLS, "동쪽 벽의 왼쪽 끝도 그렇다")
	t.eq(wall.end.x, (SYN_WALL_TX1 + 1) * Tuning.TILE_CELLS - 1, "동쪽 벽의 오른쪽 끝도 그렇다")
	t.eq(wall.position.y, SYN_WALL_TY0 * Tuning.TILE_CELLS, "동쪽 벽의 윗 끝도 그렇다")
	t.eq(wall.end.y, (SYN_WALL_TY1 + 1) * Tuning.TILE_CELLS - 1, "동쪽 벽의 아랫 끝도 그렇다")

	# ── the clear title came from the row ──
	t.eq(String((root as Object).get("_stage_title")), SYN_TITLE,
		"행이 들고 온 클리어 제목을 셸이 들고 있다")

	_drop_stage(t, root)
	_restore_stage1_gate()


## **The other half**: `_apply_room()` reading its argument proves nothing if `_build_room()` hands it the
## wrong row. This drives the two real doors — the departure gate and the settlement button — and checks the
## room that actually got built, not the id that was set.
##
## **`_in_town` is derived here, not stored** — this is where that is measured as a value. Set the id and the
## bool follows; there is no second field for a door to forget.
func _the_room_the_shell_builds_comes_from_the_stage_id(t) -> void:
	var root: Node = await _treed_stage(t)
	if root == null:
		return
	var grid: Variant = root.get("_grid")
	var ch: Variant = root.get("_char")
	var world: Variant = root.get("_world")
	if grid == null or ch == null or world == null:
		t.ok(false, "셸이 격자·캐릭터·세계를 잡고 있다 (전제)")
		_drop_stage(t, root)
		return

	t.eq(int((root as Object).get("_stage_id")), StageDefs.ROOM_TOWN, "게임은 마을에서 시작한다")
	t.ok(bool(root.get("_in_town")), "그리고 _in_town 은 그 번호에서 파생된다 (참)")
	t.eq(String((root as Object).get("_stage_title")), "", "마을에는 클리어 제목이 없다")

	(root as Object).call("_leave_town")
	t.eq(int((root as Object).get("_stage_id")), StageDefs.STAGE_1, "출발문을 나서면 1번 스테이지다")
	t.ok(not bool(root.get("_in_town")), "그리고 _in_town 은 거짓이 된다 (파생 — 따로 쓰는 곳이 없다)")
	var tile_px := Tuning.TILE_CELLS * Tuning.CELL_PX
	t.eq(int((ch as Object).get("x")), Stage.SPAWN_TILE.x * tile_px,
		"스테이지1의 출발 타일에 섰다 (표에서 나온 값이다)")
	t.eq(String((root as Object).get("_stage_title")), Fx.SETTLEMENT_TITLE_CLEAR,
		"스테이지1의 클리어 제목을 들었다")
	t.eq(StageGate.seat_px(),
		(float(StageGate.STAGE1_SEAT_TILE_X) + 0.5) * float(StageGate.TILE_PX),
		"스테이지1의 문 자리가 밀려 들어갔다")
	var placement: Variant = (world as Object).get("_placement")
	if placement != null:
		t.eq(int((placement as Object).call("row_count")), Stage1Monsters.ROWS.size(),
			"스테이지1의 몬스터 표가 들어갔다 (%d행)" % Stage1Monsters.ROWS.size())
	# **Literal cell, not a value read back out of the map.** `left-run-clumps-and-platforms.md` put bedrock
	#  in column 0 of every row; a check that asked the map what it holds there would shrink with the map.
	t.eq((grid as Object).call("mat_at", 4, 4), Mat.BEDROCK,
		"그리고 격자에 스테이지1의 지도가 들어갔다 (0열 최상단이 기반암)")

	(root as Object).call("enter_town")
	t.eq(int((root as Object).get("_stage_id")), StageDefs.ROOM_TOWN, "정산 버튼이 하는 일로 마을에 돌아온다")
	t.ok(bool(root.get("_in_town")), "그리고 _in_town 이 다시 참이다")
	t.eq(String((root as Object).get("_stage_title")), "", "클리어 제목도 마을 것으로 돌아온다")

	_drop_stage(t, root)
	_restore_stage1_gate()


## **"The shell holds the title" is not "the panel shows it."** Two halves, both driven:
##  1. the shell hands `_stage_title` to `open()` on a real clear — not a hand-called `open()`
##  2. `_draw()` paints the string `open()` was handed, not `Fx.SETTLEMENT_TITLE_CLEAR`
##
## Without (2), `open()` could store the argument and `_draw()` ignore it, and stage 2's clear screen would
## say "스테이지 1 클리어" with every other check green — the exact shape `net_settlement`'s own H3 correction
## records for `_cleared`.
func _the_panel_paints_the_title_the_room_carried(t) -> void:
	# ── half 1: the shell's own open path ──
	var root: Node = await _treed_stage(t)
	if root == null:
		return
	var gate_view: Variant = root.get("_gate_view")
	var settlement: Variant = root.get("_settlement")
	if gate_view == null or settlement == null:
		t.ok(false, "셸이 아치와 정산창을 잡고 있다 (전제)")
		_drop_stage(t, root)
		return

	# Out of the town first — the panel's `want` carries `not _in_town` — then the synthetic room over it.
	(root as Object).call("_leave_town")
	(root as Object).call("_apply_room", _title_only_room())
	t.eq(String((root as Object).get("_stage_title")), SYN_TITLE, "합성 방의 제목을 들었다 (전제)")
	# The take clock, turned by hand the way the seat would turn it. `take_done()` is what opens the panel
	#  as a clear (`_sync_settlement`'s own `want`), and it latches, so this needs no character position.
	for _i in Fx.GATE_TAKE_FRAMES:
		(gate_view as Object).call("tick_gate", true)
	t.ok(bool((gate_view as Object).call("take_done")), "문이 데려가는 시계가 다 돌았다 (전제)")
	(root as Object).call("_sync_settlement")
	t.ok(bool((settlement as Object).call("is_showing")), "정산 화면이 열렸다 (전제)")
	t.ok(bool((settlement as Object).get("_cleared")), "그리고 클리어로 열렸다 (전제)")
	t.eq(String((settlement as Object).get("_clear_title")), SYN_TITLE,
		"셸이 방이 들고 온 제목을 정산창에 넘겼다 (fx_tuning 의 상수가 아니다)")
	_drop_stage(t, root)
	_restore_stage1_gate()

	# ── half 2: the paint call itself ──
	var win := _CapturingSettlement.new()
	t.root.add_child(win)
	win.open(1, 2, 3, true, SYN_TITLE)
	# **`tick_countup()` is what asks for the repaint** — the shell drives it once per physics frame and it
	#  is the window's only `queue_redraw()`. Without it the second `open()` below stores its state and the
	#  picture never changes, which is how this check first read a stale title.
	win.tick_countup()
	await t.pump_frames(2)
	t.ok(win.paints > 0, "정산창이 제목을 실제로 한 번 이상 그렸다 (%d회)" % win.paints)
	t.eq(win.painted, SYN_TITLE, "그리고 그린 문자열이 open()에 준 제목 그대로다")

	# And the death title still wins over it — the argument must not have taken `_cleared`'s job.
	win.open(1, 2, 3, false, SYN_TITLE)
	win.tick_countup()
	await t.pump_frames(2)
	t.eq(win.painted, Fx.SETTLEMENT_TITLE,
		"쓰러져서 열면 여전히 죽음 제목이다 (제목 인자가 _cleared 를 대신하지 않는다)")

	t.root.remove_child(win)
	win.queue_free()


# ══════════════════════════════════════════════════════════════════
#  The baker's two arguments
# ══════════════════════════════════════════════════════════════════

## **Driven, not read off the signature.** A default argument that is accepted and then ignored looks exactly
## like one that works — so the bake is aimed at a file in `user://` and the file has to appear there.
## If `out_path` were still the hardcoded `res://` name, nothing would exist at this path and this goes red
## (and the real artifact would have been rewritten from inside a test, which is the other reason to check).
func _the_baker_writes_where_it_is_told(t) -> void:
	_remove_probe()
	t.ok(not FileAccess.file_exists(PROBE_OUT), "굽기 전에는 그 자리에 파일이 없다 (전제)")
	t.ok(Baker.bake(Baker.DEFAULT_SOURCE_NODE, PROBE_OUT), "시킨 자리로 굽는 게 성공한다")
	t.ok(FileAccess.file_exists(PROBE_OUT), "시킨 자리에 파일이 생겼다 (out_path 가 살아 있다)")
	var f := FileAccess.open(PROBE_OUT, FileAccess.READ)
	t.ok(f != null, "구운 파일을 연다 (전제)")
	if f == null:
		return
	var src := f.get_as_text()
	f.close()
	t.ok(src.contains("const MAP_W := %d" % TerrainMap.MAP_W),
		"구운 결과의 너비가 지금 지도의 너비다 (%d)" % TerrainMap.MAP_W)
	t.ok(src.contains("const MAP_H := %d" % TerrainMap.MAP_H),
		"높이도 그렇다 (%d)" % TerrainMap.MAP_H)
	# **The accessor the room table depends on.** Written into the artifact by hand it would live exactly
	#  until the next redraw, and then the table's `map` field would die with nothing barking.
	t.ok(src.contains("static func rows() -> Array[String]:"),
		"구운 결과가 rows() 를 들고 나온다 (방 표가 부르는 그 함수다)")
	t.ok(src.contains("return MAP"), "그리고 그 함수가 MAP 을 돌려준다")
	_remove_probe()


## The other argument. **A layer that is not there must bark by the name it was asked for** — with the name
## hardcoded, baking stage 2's layer and misspelling it would complain about a node nobody asked about.
func _the_baker_reads_the_layer_it_is_told(t) -> void:
	t.expect_error("there is no NoSuchLayer(TileMapLayer) node")
	t.ok(not Baker.bake("NoSuchLayer", PROBE_OUT), "없는 층을 시키면 실패한다 (source_node 가 살아 있다)")
	t.ok(not FileAccess.file_exists(PROBE_OUT), "그리고 아무것도 안 쓴다")


func _remove_probe() -> void:
	if FileAccess.file_exists(PROBE_OUT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_OUT))


# ══════════════════════════════════════════════════════════════════
#  helpers
# ══════════════════════════════════════════════════════════════════

## Stage 1's map and monsters with **only** the title and gate swapped — used where the point is the title
## alone and a synthetic map would just make the state harder to read.
func _title_only_room() -> Dictionary:
	var row := StageDefs.row(StageDefs.STAGE_1).duplicate()
	row["title"] = SYN_TITLE
	return row


## **Put back what the synthetic rows moved.** The gate's geometry is process-global static state, and every
## check in this file shares one process (CLAUDE.md: one process per net file, not per check).
func _restore_stage1_gate() -> void:
	StageGate.set_geometry(
		StageGate.STAGE1_SEAT_TILE_X, StageGate.STAGE1_FLOOR_TILE_Y,
		StageGate.STAGE1_WALL_TILE_X0, StageGate.STAGE1_WALL_TILE_X1,
		StageGate.STAGE1_WALL_TILE_Y0, StageGate.STAGE1_WALL_TILE_Y1)


## **The real scene, treed, with Godot running `_ready()`** — `net_research._treed_stage`'s idiom, copied
## rather than shared (each net runs in its own process, so there is no base class to share).
## A hand-wired root would pre-set the `@onready` fields and hide the shell's own wiring lines.
func _treed_stage(t) -> Node:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세웠다 (전제)")
	if scene == null or not scene.can_instantiate():
		return null
	var root := scene.instantiate()
	t.root.add_child(root)
	await t.pump_frames(2)
	return root


func _drop_stage(t, root: Node) -> void:
	t.root.remove_child(root)
	root.queue_free()
