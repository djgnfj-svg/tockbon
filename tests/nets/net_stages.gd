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
const UnlockDefs := preload("res://src/actor/unlock_defs.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const SettlementWindow := preload("res://src/view/settlement_window.gd")
const Baker := preload("res://tools/stage/terrain_baker.gd")
## The other half of the same pipe — the write direction (see the painter check at the bottom).
const Painter := preload("res://tools/stage/paint_terrain_from_map.gd")

const STAGE_SCENE := "res://src/stage/stage.tscn"

## Where the baker probe writes. **`user://`, never `res://`** — a bake aimed at the real artifact would
## rewrite a checked-in file from inside a test run.
const PROBE_OUT := "user://net_stages_bake_probe.gd"

## ══ The synthetic room's numbers, all of them different from stage 1's and from the town's ══
##  Kept as named constants so the checks below read as "the value the row carried", not as bare literals
##  that happen to match.
## **A pair matching neither real row** — the town's far picture with the farm's near one. Either real
## pair would leave "it came from the row" and "it came from the old ternary" indistinguishable for one
## of the two rooms.
const SYN_BG_FAR := Fx.BG_TOWN_FAR_TEXTURE
const SYN_BG_NEAR := Fx.BG_NEAR_TEXTURE
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
	_no_row_chains_into_itself_or_out_of_the_table(t)
	await _with_no_next_the_run_ends_exactly_as_it_does_today(t)
	await _the_chain_walks_into_the_next_stage_and_keeps_the_run(t)
	await _a_self_chaining_row_barks_and_ends_the_run_instead(t)
	_the_baker_writes_where_it_is_told(t)
	_the_baker_reads_the_layer_it_is_told(t)
	_the_painter_writes_only_the_layer_it_is_told(t)


# ══════════════════════════════════════════════════════════════════
#  The table itself
# ══════════════════════════════════════════════════════════════════

## **The check a forgotten field dies on.** Adding a stage 2 row that omits `gate` (or `title`, or
## `monsters`) is the single most likely way this table gets it wrong, and without this the omission would
## surface as a null deref two files away — or worse, as stage 2 quietly keeping stage 1's gate.
func _every_row_carries_every_field(t) -> void:
	t.ok(StageDefs.ROWS.size() >= 2,
		"방 표에 마을과 스테이지가 모두 있다 (%d행)" % StageDefs.ROWS.size())
	# **A floor, not an exact count.** The list grows as fields move into the table (the backdrop pair did),
	#  and pinning the number would make every such move look like a failure. What the premise has to stop is
	#  the loop below running zero times — the `checked` count at the end is the other half of that.
	t.ok(StageDefs.REQUIRED_KEYS.size() >= 7,
		"필수 열쇠가 최소 7개다 (전제 — 목록이 비면 아래 루프가 안 돈다) — %d개"
			% StageDefs.REQUIRED_KEYS.size())
	t.ok(StageDefs.REQUIRED_KEYS.has("next"), "그 목록에 '이어질 곳'이 들어 있다")
	var checked := 0
	for i in StageDefs.ROWS.size():
		var row: Dictionary = StageDefs.ROWS[i]
		for key: String in StageDefs.REQUIRED_KEYS:
			t.ok(row.has(key), "%d번 방이 '%s' 를 들고 있다" % [i, key])
			checked += 1
	t.eq(checked, StageDefs.ROWS.size() * StageDefs.REQUIRED_KEYS.size(),
		"모든 행 × 모든 열쇠를 실제로 돌았다 (%d번)" % checked)

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
		"bg_far": SYN_BG_FAR,
		"bg_near": SYN_BG_NEAR,
		# **`NO_NEXT`, because this check is about the fields and not the chain** — the chain has its own
		#  three checks below. Omitting the key is not an option: `_apply_room()` reads every required key
		#  unconditionally, and a missing one aborts the call **midway**, which reads here as the *spawn*
		#  check failing at the town's tile. That is exactly how this row went red once.
		"next": StageDefs.NO_NEXT,
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

	# ── the backdrop came from the row ──
	# **The pair is deliberately mismatched** (`SYN_BG_FAR`/`SYN_BG_NEAR`: the town's far picture with the
	#  farm's near one). Either real pair would leave "it came from the row" and "it came from the ternary
	#  this line replaced" indistinguishable for one of the two rooms.
	#  **Measured: only one of the two lines below bites per hardcode**, and which one names the culprit —
	#  push the farm pair and the *far* check goes red, push the town pair and the *near* one does. Neither
	#  half alone covers both; the mismatch is what makes the pair cover them.
	# **Read off the node, not scanned in the source.** `net_town` covers row -> node for the town; what is
	#  missing without this is **per-row** coverage — a `_apply_room()` that pushed one fixed pair regardless
	#  of the row would still satisfy that check and give stage 2 stage 1's sky.
	var sky: Variant = root.get("_sky")
	t.ok(sky != null, "셸이 하늘을 잡고 있다 (전제)")
	if sky != null:
		var far: Texture2D = (sky as Object).get("_far")
		var near: Texture2D = (sky as Object).get("_near")
		t.ok(far != null and near != null, "배경 두 장이 실렸다 (전제)")
		if far != null and near != null:
			t.eq(far.resource_path, SYN_BG_FAR, "행이 들고 온 먼 배경이 하늘에 닿았다")
			t.eq(near.resource_path, SYN_BG_NEAR, "행이 들고 온 가까운 배경도 닿았다")

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
#  The chain — `town -> 1 -> 2 -> 3`
# ══════════════════════════════════════════════════════════════════

## **Static shape.** A row pointing at itself rebuilds the same stage once per frame forever, which on screen
## is the game freezing at the gate; a row pointing outside the table barks on every later room build.
## `_enter_stage()` refuses both at run time (driven below) — this is the same two questions asked of the
## table itself, so a bad row is caught by reading it and not only by walking into it.
func _no_row_chains_into_itself_or_out_of_the_table(t) -> void:
	var checked := 0
	for i in StageDefs.ROWS.size():
		var nxt := int(StageDefs.ROWS[i]["next"])
		checked += 1
		if nxt == StageDefs.NO_NEXT:
			continue
		t.ok(nxt != i, "%d번 방이 자기 자신으로 이어지지 않는다" % i)
		t.ok(nxt >= StageDefs.STAGE_1 and nxt < StageDefs.ROWS.size(),
			"%d번 방이 이어지는 곳(%d)이 표 안의 스테이지다" % [i, nxt])
	t.eq(checked, StageDefs.ROWS.size(), "모든 행의 이어짐을 실제로 봤다 (%d행)" % checked)
	# **Today every room answers `NO_NEXT`, and that is the fact the whole "nothing changes" claim rests on.**
	#  Written as a value so that the day stage 2 lands, this line is what says out loud that it did.
	t.eq(int(StageDefs.ROWS[StageDefs.STAGE_1]["next"]), StageDefs.NO_NEXT,
		"스테이지1 뒤에는 아직 아무것도 없다 (그래서 클리어가 오늘 그대로 정산 화면이다)")


## **The negative half, and it is the one the brief cares about most: with `NO_NEXT`, nothing moved.**
## A clear opens the settlement screen, with the clear title, and the shell stays on the same stage.
##
## **Measured, and written down because it is the weakest inversion in this file**: deleting the
## `_next_stage_id != NO_NEXT` term from `_sync_settlement()`'s guard **turns no line here red.** The chain
## is entered with `-1`, `_enter_stage()` refuses it as "not a stage in the table", and the fall-through
## leaves `_stage_id` and the panel exactly as this function expects. What catches it is the **wrapper's
## silence check** — the refusal's `push_error` is undeclared, so the round goes red with 153 green checks.
## That is a real bite in this repo (only the final `[래퍼]` line decides) but it is second-hand: it depends
## on `NO_NEXT` being an id the guard rejects. **Give `NO_NEXT` a value that happens to be a real stage and
## nothing here would catch it at all** — which is the actual reason it is `-1` and not `ROOM_TOWN`.
func _with_no_next_the_run_ends_exactly_as_it_does_today(t) -> void:
	var root: Node = await _treed_stage(t)
	if root == null:
		return
	var gate_view: Variant = root.get("_gate_view")
	var settlement: Variant = root.get("_settlement")
	if gate_view == null or settlement == null:
		t.ok(false, "셸이 아치와 정산창을 잡고 있다 (전제)")
		_drop_stage(t, root)
		return
	(root as Object).call("_leave_town")
	t.eq(int((root as Object).get("_next_stage_id")), StageDefs.NO_NEXT,
		"스테이지1에 서면 다음이 없다 (전제 — 표에서 읽은 값이다)")
	for _i in Fx.GATE_TAKE_FRAMES:
		(gate_view as Object).call("tick_gate", true)
	(root as Object).call("_sync_settlement")
	t.eq(int((root as Object).get("_stage_id")), StageDefs.STAGE_1,
		"클리어해도 스테이지가 안 바뀐다 (이어질 곳이 없다)")
	t.ok(bool((settlement as Object).call("is_showing")), "그대로 정산 화면이 열린다")
	t.ok(bool((settlement as Object).get("_cleared")), "그리고 클리어로 열린다")
	t.eq(String((settlement as Object).get("_clear_title")), Fx.SETTLEMENT_TITLE_CLEAR,
		"제목도 스테이지1 클리어 그대로다")
	_drop_stage(t, root)
	_restore_stage1_gate()


## **The whole chain, walked for real into a real second row.**
##
## **The row is appended to the table and popped again** — the chain can only be driven *into a stage*, and
## the game has one (`stage_defs.gd`'s own box on why `ROWS` is a `static var`). Nothing here invents stage 2
## content: the synthetic row is a flat stone room with one pig, and what is measured is the plumbing.
##
## **What this is really guarding**: `_enter_stage()` reaching for `reset_stage()` — the obvious thing to do,
## since the shell had exactly one rebuild path — **wipes every 원석, every unlock, the level and the earned
## rune the instant you walk into stage 2, and nothing barks.** Each of those is a separate check below so a
## red line names which one was lost.
func _the_chain_walks_into_the_next_stage_and_keeps_the_run(t) -> void:
	var root: Node = await _treed_stage(t)
	if root == null:
		return
	var gate_view: Variant = root.get("_gate_view")
	var settlement: Variant = root.get("_settlement")
	var world: Variant = root.get("_world")
	var grid: Variant = root.get("_grid")
	if gate_view == null or settlement == null or world == null or grid == null:
		t.ok(false, "셸이 아치·정산창·세계·격자를 잡고 있다 (전제)")
		_drop_stage(t, root)
		return

	var stage_2 := _push_synthetic_stage(StageDefs.NO_NEXT)
	t.eq(stage_2, StageDefs.STAGE_1 + 1, "표에 두 번째 스테이지를 붙였다 (전제)")

	# Out of the town, then stage 1's row with its `next` pointed at the row just appended.
	(root as Object).call("_leave_town")
	var chained := StageDefs.row(StageDefs.STAGE_1).duplicate()
	chained["next"] = stage_2
	(root as Object).call("_apply_room", chained)
	t.eq(int((root as Object).get("_next_stage_id")), stage_2, "셸이 이어질 곳을 들었다 (전제)")

	# ── the run, earned in stage 1 ──
	var pr: Variant = (world as Object).call("progress")
	(pr as Object).call("add_xp", 500)
	(pr as Object).set("gems", 42)
	(pr as Object).call("grant_rune", Tuning.ELEM_FIRE)
	t.ok((pr as Object).call("buy", UnlockDefs.UNLOCK_DOUBLE_JUMP), "연구대에서 하나 샀다 (전제)")
	(pr as Object).call("add_damage", 777)
	# **Turned by hand** — this check drives `_sync_settlement()` directly rather than running physics, so
	#  `run_ticks` would sit at 0 and "it survived" would be true after a `reset()` as well.
	for _i in 40:
		(pr as Object).call("advance_tick")
	(pr as Object).call("set_boss_reward_pending", MonsterDefs.KIND_ROOSTER)
	# **Snapshotted after the purchase, not before it** — `buy()` spends 원석, so a literal would be asserting
	#  against a number the setup itself already changed.
	var level_before := int((pr as Object).get("level"))
	var gems_before := int((pr as Object).get("gems"))
	var gems_run_before := int((pr as Object).call("gems_this_run"))
	var picks_before := int((pr as Object).get("pending_picks"))
	var ticks_before := int((pr as Object).get("run_ticks"))
	t.ok(level_before > 0, "레벨이 올랐다 (전제 — %d)" % level_before)
	# **Each premise is what keeps its own check from being vacuous.** `gems_this_run()` reading 0 here would
	#  make "그대로다" below true after a `reset()` as well, and the check would guard nothing.
	t.ok(gems_run_before > 0, "이번 런에 번 원석이 0이 아니다 (전제 — %d)" % gems_run_before)
	t.ok(picks_before > 0, "안 뽑은 뽑기가 남아 있다 (전제 — %d)" % picks_before)

	for _i in Fx.GATE_TAKE_FRAMES:
		(gate_view as Object).call("tick_gate", true)
	(root as Object).call("_sync_settlement")

	# ── it walked in ──
	t.eq(int((root as Object).get("_stage_id")), stage_2, "게이트가 다음 스테이지로 데려갔다")
	t.ok(not bool((settlement as Object).call("is_showing")),
		"정산 화면은 안 열린다 (런이 안 끝났다 — 스테이지가 이어진다)")
	t.eq(String((root as Object).get("_stage_title")), SYN_TITLE,
		"다음 스테이지의 클리어 제목을 들었다 (스테이지1 것이 아니다)")
	t.eq((grid as Object).call("mat_at", PROBE_TX * Tuning.TILE_CELLS + 4, 5 * Tuning.TILE_CELLS + 4),
		Mat.STONE, "그리고 다음 스테이지의 지도가 지어졌다")

	# ── and the run came with it ──
	t.eq(int((pr as Object).get("level")), level_before, "레벨이 그대로다")
	# **This one alone would not catch a `reset()`** — `gems` deliberately survives `reset()` too (its own box
	#  in `progress.gd`: the town's whole reason to exist). It is here so a red line can separate "the whole
	#  object was replaced" from "the run was reset"; the three checks around it are what actually bite.
	t.eq(int((pr as Object).get("gems")), gems_before, "원석이 그대로다")
	t.eq(int((pr as Object).call("gems_this_run")), gems_run_before,
		"이번 런에 번 원석도 그대로다 (_gems_at_run_start 를 다시 안 찍었다)")
	t.eq(int((pr as Object).get("damage_dealt")), 777, "이번 런에 준 피해도 그대로다")
	t.eq(int((pr as Object).get("pending_picks")), picks_before,
		"안 뽑은 뽑기도 그대로다 (보상이지 스테이지 것이 아니다)")
	t.eq(int((pr as Object).get("run_ticks")), ticks_before,
		"런 시간도 이어진다 (정산 화면이 런 전체를 말해야 한다)")
	t.ok(bool((pr as Object).call("is_unlocked", UnlockDefs.UNLOCK_DOUBLE_JUMP)), "산 해금이 그대로다")
	t.ok(bool((pr as Object).call("owns_rune", Tuning.ELEM_FIRE)), "황소가 준 룬도 그대로다")

	# ── but the stage's own record did not ──
	# **Carried across, stage 2's arch is lit and its east wall already down on the frame you arrive**, and
	#  stepping on its seat ends the run instantly. That is what makes this a stage's record, not a run's.
	t.ok(not bool((pr as Object).call("boss_died", MonsterDefs.KIND_ROOSTER)),
		"그런데 보스가 죽었다는 기록은 안 따라온다 (따라오면 다음 스테이지 문이 처음부터 열려 있다)")
	t.ok(not bool((gate_view as Object).call("take_done")),
		"문의 시계도 0으로 돌아갔다 (그래서 매 프레임 다시 넘어가지 않는다)")

	_pop_synthetic_stage()
	_drop_stage(t, root)
	_restore_stage1_gate()


## **A row that points at itself must bark, not loop.** Without the refusal `_enter_stage()` rebuilds the same
## stage once per physics frame forever, which on screen is the game freezing on the seat with no error at all.
##
## **And the refusal falls through to the settlement screen** — a refusal that silently did nothing would
## strand the player on the seat with no way on and no way out, which is worse than ending the run there.
func _a_self_chaining_row_barks_and_ends_the_run_instead(t) -> void:
	var root: Node = await _treed_stage(t)
	if root == null:
		return
	var gate_view: Variant = root.get("_gate_view")
	var settlement: Variant = root.get("_settlement")
	if gate_view == null or settlement == null:
		t.ok(false, "셸이 아치와 정산창을 잡고 있다 (전제)")
		_drop_stage(t, root)
		return
	(root as Object).call("_leave_town")
	var loops := StageDefs.row(StageDefs.STAGE_1).duplicate()
	loops["next"] = StageDefs.STAGE_1
	(root as Object).call("_apply_room", loops)
	for _i in Fx.GATE_TAKE_FRAMES:
		(gate_view as Object).call("tick_gate", true)
	t.expect_error("stage %d chains into itself" % StageDefs.STAGE_1)
	(root as Object).call("_sync_settlement")
	t.eq(int((root as Object).get("_stage_id")), StageDefs.STAGE_1, "자기 자신으로 이어지면 안 넘어간다")
	t.ok(bool((settlement as Object).call("is_showing")),
		"대신 정산 화면이 열린다 (자리에 갇히지 않는다)")

	# **Out of the table barks too** — a row pointing at a stage nobody wrote.
	var outside := StageDefs.row(StageDefs.STAGE_1).duplicate()
	outside["next"] = 99
	(root as Object).call("_apply_room", outside)
	(settlement as Object).call("close")
	t.expect_error("chains into 99, which is not a stage in the table")
	(root as Object).call("_sync_settlement")
	t.eq(int((root as Object).get("_stage_id")), StageDefs.STAGE_1, "표 밖으로 이어져도 안 넘어간다")
	t.ok(bool((settlement as Object).call("is_showing")), "여기서도 정산 화면이 열린다")

	_drop_stage(t, root)
	_restore_stage1_gate()


## Appends a real second stage to the table and returns its id. **Flat stone, one pig, its own gate and its
## own title** — plumbing, not content: nothing here is a guess about what stage 2 contains.
func _push_synthetic_stage(next_id: int) -> int:
	var monsters: Array[Dictionary] = [{"tx": SYN_MONSTER_TX, "kind": MonsterDefs.KIND_PIG}]
	StageDefs.ROWS.append({
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
		"bg_far": SYN_BG_FAR,
		"bg_near": SYN_BG_NEAR,
		"next": next_id,
	})
	return StageDefs.ROWS.size() - 1


## **Popped again in the same check that pushed it.** Checks in one file share one process (CLAUDE.md), and a
## table left two rows long would make every later table check measure a stage nobody wrote.
func _pop_synthetic_stage() -> void:
	StageDefs.ROWS.resize(StageDefs.STAGE_1 + 1)


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


## ══ The painter — **the write direction, and it was the one hard blocker on a second stage** ══
##
## `terrain_baker.bake()` was given a source layer and an output path; `paint_terrain_from_map.gd` was not.
## **The bake reads a layer into text; the paint writes text back into a layer, and a map is authored in the
## write direction** — so a parameterised baker over a single-layer painter is half a pipe. It refused
## outright (`hits != 1`) the moment `stage.tscn` held two `TileMapLayer`s, which is exactly what a second
## stage is.
##
## **Driven on synthetic scene text, not on `stage.tscn`.** The real scene has one layer today, so it cannot
## show the difference between "counts the property across the file" and "tracks which node it belongs to" —
## and that difference *is* the fix. The second assert below is the one that fails against the old code.
func _the_painter_writes_only_the_layer_it_is_told(t) -> void:
	var scene := "\n".join([
		"[node name=\"Terrain\" type=\"TileMapLayer\" parent=\".\"]",
		"tile_map_data = PackedByteArray(\"AAAA\")",
		"",
		"[node name=\"Terrain2\" type=\"TileMapLayer\" parent=\".\"]",
		"tile_map_data = PackedByteArray(\"BBBB\")",
	])

	# **The premise, and the negative half**: the whole file carries the property twice, so the old
	#  file-wide count would have read 2 and refused. Without this the checks below prove nothing new.
	var whole_file := scene.count(Painter.DATA_PREFIX)
	t.eq(whole_file, 2, "전제 — 파일 전체로 세면 tile_map_data가 2개다 (예전 코드는 여기서 거절했다)")

	var a := Painter.swap_layer_data(scene, "Terrain", "ZZZZ")
	t.eq(int(a["hits"]), 1, "이름을 대면 그 레이어 하나만 바꾼다 (%d개)" % int(a["hits"]))
	t.ok(String(a["text"]).contains("PackedByteArray(\"ZZZZ\")"), "지정한 레이어가 새 값으로 바뀐다")
	t.ok(String(a["text"]).contains("PackedByteArray(\"BBBB\")"),
		"그리고 다른 레이어는 손도 안 댄다 (스테이지 2를 칠하다 스테이지 1을 덮지 않는다)")
	t.ok(not String(a["text"]).contains("PackedByteArray(\"AAAA\")"), "옛 값은 남지 않는다")

	var b := Painter.swap_layer_data(scene, "Terrain2", "YYYY")
	t.eq(int(b["hits"]), 1, "두 번째 레이어도 이름으로 정확히 집힌다")
	t.ok(String(b["text"]).contains("PackedByteArray(\"AAAA\")"),
		"이번엔 첫 번째 레이어가 그대로 남는다 (방향이 반대로도 성립한다)")
	t.ok(String(b["text"]).contains("PackedByteArray(\"YYYY\")"), "두 번째가 바뀐다")

	# **A name nobody drew must not silently paint something else.** 0 hits is what the caller refuses on.
	var miss := Painter.swap_layer_data(scene, "NoSuchLayer", "QQQQ")
	t.eq(int(miss["hits"]), 0, "없는 레이어 이름은 0개 — 조용히 엉뚱한 걸 칠하지 않는다")
	t.eq(String(miss["text"]), scene, "그리고 원문이 그대로다")
