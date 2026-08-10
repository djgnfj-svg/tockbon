extends RefCounted
## `src/stage/stage1_monsters.gd` (the table) and `src/actor/monster_placement.gd` (the resolver + the
## runner) — `monster-placement-stage1.md`, Stages A+B.
## Its own file, its own process — `net_monster*.gd` is already split several ways for exactly this
## reason (that file's own header), and this feature's own table/resolver share no code with any of them.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Stage := preload("res://src/stage/stage.gd")
const Stage1Monsters := preload("res://src/stage/stage1_monsters.gd")
const MonsterPlacement := preload("res://src/actor/monster_placement.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Character := preload("res://src/actor/character.gd")
const BossAi := preload("res://src/actor/boss_ai.gd")
## The clump XP invariant is "one engagement levels you", so the bound comes from the levelling curve
## itself, not from a number typed twice. `MonsterBolts.BOLT_STOP_PX` is the hen's own stopping distance,
## which is what forces the shelf width.
const Progress := preload("res://src/actor/progress.gd")
const MonsterBolts := preload("res://src/actor/monster_bolts.gd")
## The waking presentation is this feature's own screen half, and its hook is measured here rather
## than in `net_monster_sprite` — what it actually measures is *when a placed row stirs*, which is
## this file's subject. `net_gate` preloads a view for the same reason.
const MonsterView := preload("res://src/view/monster_view.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
## S1 (verify-read) — the wiring line itself must be measured through the real stage, not just through
## `WorldStep` built by hand. Borrowed, not copied — `_wired_root` is the one door every net that stands
## up the real scene already shares (`net_gate.gd`'s own header).
const NetGate := preload("res://tests/nets/net_gate.gd")

const DT := 1.0 / 60.0
## A synthetic flat floor for the pure Stage B checks below — not the real map's `FLOOR_CY`. Only the
## checks that must run against the actual baked terrain (`_no_two_resolved_boxes_intersect_on_the_real_map`,
## `_every_row_stands_exactly_on_the_surface`) use `Stage1Monsters.FLOOR_CY` and `Stage.build_terrain_into`.
const SYN_FLOOR_CY := 200
## Top of `_flat_grid()`'s slab (px) — the same "feet rest here" convention `net_progress.FLOOR_TOP` uses,
## kept as its own constant so Stage D's checks below do not repeat `(SYN_FLOOR_CY - 4) * Tuning.CELL_PX`.
const SYN_FLOOR_TOP := (SYN_FLOOR_CY - 4) * Tuning.CELL_PX

## ══ The clump layout, as literal tile numbers (`left-run-clumps-and-platforms.md` §3/§4) ══
## **Literal on purpose.** Reading these back out of `stage1_monsters.ROWS` or out of the baked map would
## make every check below shrink with whatever it is supposed to be catching — CLAUDE.md's "a check whose
## bounds come from the thing it checks proves nothing", which cost this repo a wall test once already.
## Move a clump or a shelf and these numbers have to be retyped by hand. That is the point.
const CLUMP_TX: Array = [[14, 29], [45, 60], [73, 88]]
const SHELF_TILES: Array = [[20, 30], [51, 61], [79, 89]]
## The shelf's top tile row and the flat's own ground tile row — 2 tiles apart, which is the 64px hop.
const SHELF_TOP_TY := 18
const FLAT_GROUND_TY := 20
## One tile in world px.
const TILE_PX := Tuning.TILE_CELLS * Tuning.CELL_PX


func run(t) -> void:
	_the_sleeping_approach_is_visible_and_the_hen_stays_on_its_shelf(t)
	_table_is_sorted_by_tx(t)
	_adjacent_rows_are_at_least_3_tiles_apart(t)
	_no_two_resolved_boxes_intersect_on_the_real_map(t)
	_every_row_stands_exactly_on_the_surface(t)
	_the_floating_platform_trap_resolves_to_real_ground(t)
	_a_groundless_column_barks_and_reports_not_ok(t)
	_a_low_ceiling_barks_and_reports_not_ok(t)
	_teaching_order_pig_then_hen_then_wolf(t)
	_zone_totals(t)
	_every_clump_is_worth_at_least_sixty_xp(t)
	_the_stone_shelves_are_solid_to_the_ground_by_literal_tile(t)
	_a_shelf_row_resolves_onto_the_shelf_top_not_the_ground(t)
	_every_shelf_hen_keeps_its_240px_of_shelf_to_the_west(t)
	_wake_scan_creates_a_monster_inside_the_activation_band_not_before(t)
	_a_killed_row_never_comes_back(t)
	_reset_rearms_every_row(t)
	_a_capped_refusal_leaves_the_row_dormant_not_spent(t)
	_the_wake_scan_only_runs_on_the_tick(t)
	_the_stir_band_flips_once_not_every_tick(t)
	_materialising_is_one_threshold_with_no_hysteresis(t)
	_a_sleeping_monster_standing_in_fire_still_takes_damage_and_can_die(t)
	_a_sleeping_monster_on_flat_ground_does_not_move(t)
	_a_sleeping_monster_does_not_jump_even_when_blocked(t)
	_a_sleeping_monster_is_excluded_from_separation_both_ways(t)
	_waking_restores_movement(t)
	_the_pit_holds_while_asleep(t)
	# verify-read's own findings (S1-S7), an isolated-worktree adversarial pass on Stages A-C.
	_the_wiring_line_actually_reaches_the_real_stage(t)
	_the_real_map_scan_direction_matters_not_just_synthetic_grids(t)
	_bosses_are_placed_inside_their_own_room(t)
	_pre_stage1_row_count_stays_under_the_cap(t)
	_a_boss_row_still_spawns_when_the_trash_cap_is_full(t)
	_a_boss_refused_at_the_real_cap_barks(t)
	await _the_view_paints_a_wake_mark_exactly_when_a_mob_stirs(t)
	_wake_scan_runs_after_death_removal_so_a_freed_slot_is_usable_the_same_tick(t)
	_wake_scan_runs_before_contact_damage_so_a_mob_that_wakes_overlapping_the_player_hits_the_same_tick(t)


# ══════════════════════════════════════════════════════════════════
#  Stage A — the table and the pure resolver
# ══════════════════════════════════════════════════════════════════

func _table_is_sorted_by_tx(t) -> void:
	var rows := Stage1Monsters.ROWS
	for i in range(1, rows.size()):
		t.ok(int(rows[i]["tx"]) > int(rows[i - 1]["tx"]),
			"행 %d(tx %d)가 앞 행(tx %d)보다 크다 (정렬됨 — 간격 규칙과 깨우기 스캔이 둘 다 이걸 전제한다)" %
				[i, rows[i]["tx"], rows[i - 1]["tx"]])


func _adjacent_rows_are_at_least_3_tiles_apart(t) -> void:
	var rows := Stage1Monsters.ROWS
	for i in range(1, rows.size()):
		var gap := int(rows[i]["tx"]) - int(rows[i - 1]["tx"])
		t.ok(gap >= 3, "행 %d(tx %d)와 행 %d(tx %d)의 간격이 %d타일 — 3타일 이상이다" %
			[i - 1, rows[i - 1]["tx"], i, rows[i]["tx"], gap])


## **On the real baked map** — a terrain change is exactly the class of regression this check exists to
## catch, not just a typo in the table.
func _no_two_resolved_boxes_intersect_on_the_real_map(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	var rows := Stage1Monsters.ROWS
	var boxes: Array[Dictionary] = []
	for row: Dictionary in rows:
		var kind: int = row["kind"]
		var res := MonsterPlacement.resolve(g, int(row["tx"]), kind, Stage1Monsters.FLOOR_CY)
		t.ok(res.get("ok", false), "tx %d(kind %d)가 실제 맵에서 착지한다 (전제)" % [row["tx"], kind])
		if not res.get("ok", false):
			continue
		boxes.append({"px": res["px"], "py": res["py"],
			"w": MonsterDefs.w_px(kind), "h": MonsterDefs.h_px(kind)})
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: Dictionary = boxes[i]
			var b: Dictionary = boxes[j]
			t.ok(not WorldStep._boxes_overlap(a["px"], a["py"], a["w"], a["h"], b["px"], b["py"], b["w"], b["h"]),
				"박스 %d·%d가 실제 맵 위에서 안 겹친다" % [i, j])


## Acceptance 7 — "mobs stand on the ground, not in it and not above it", for **all** 34 rows on the real map.
func _every_row_stands_exactly_on_the_surface(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	for row: Dictionary in Stage1Monsters.ROWS:
		var kind: int = row["kind"]
		var tx: int = row["tx"]
		var res := MonsterPlacement.resolve(g, tx, kind, Stage1Monsters.FLOOR_CY)
		if not res.get("ok", false):
			continue
		var py: int = res["py"]
		var h := MonsterDefs.h_px(kind)
		var feet_cy := floori(float(py + h) / float(Tuning.CELL_PX))
		var cx := tx * Tuning.TILE_CELLS
		t.ok(g.is_solid(cx, feet_cy), "tx %d의 발밑 셀이 단단하다 (지면 위에 정확히 선다)" % tx)
		t.ok(not g.is_solid(cx, feet_cy - 1), "tx %d의 발이 있는 셀은 비어 있다 (안에 묻히지 않는다)" % tx)


## **The exact map fact spec found while building this plan**: `tx149-150` carries a floating bedrock
## block above real ground. A downward scan from the top would land on the block; this proves the
## resolver's upward scan finds the real ground underneath it instead.
func _the_floating_platform_trap_resolves_to_real_ground(t) -> void:
	var g := CellGrid.new()
	var floor_cy := 200
	# Real ground: a slab at the very bottom, five cells thick.
	g.apply(CellGrid.cmd_fill(0, floor_cy - 4, 40, floor_cy, Mat.STONE))
	# A floating 2x2-cell block, well above the ground, with a genuine air gap separating the two —
	# `tx149-150`'s exact shape (ty15-16 floating over real ground at ty20).
	g.apply(CellGrid.cmd_fill(8, floor_cy - 40, 9, floor_cy - 39, Mat.STONE))
	var res := MonsterPlacement.resolve(g, 1, MonsterDefs.KIND_PIG, floor_cy)  # tx=1 -> cx=8, inside both
	t.ok(res.get("ok", false), "착지에 성공한다 (전제)")
	var expect_surface_px := (floor_cy - 4) * Tuning.CELL_PX
	t.eq(int(res["py"]) + MonsterDefs.h_px(MonsterDefs.KIND_PIG), expect_surface_px,
		"실제 지면 위에 착지한다 (%dpx) — 위에 뜬 기반암 블록이 아니다" % expect_surface_px)


func _a_groundless_column_barks_and_reports_not_ok(t) -> void:
	var g := CellGrid.new()  # 아무것도 채우지 않은 완전히 빈 격자 — 어디에도 땅이 없다
	t.expect_error("no ground to stand on")
	var res := MonsterPlacement.resolve(g, 5, MonsterDefs.KIND_PIG, 100)
	t.ok(not res.get("ok", true), "땅이 없는 열은 실패로 보고된다")


func _a_low_ceiling_barks_and_reports_not_ok(t) -> void:
	var g := CellGrid.new()
	var floor_cy := 100
	# 지면 두 칸(99~100), 그 바로 위 한 칸(98)만 비고 다시 막힘(97) — 돼지가 서는 데 필요한 8칸에 한참 못 미친다.
	g.apply(CellGrid.cmd_fill(0, floor_cy - 1, 20, floor_cy, Mat.STONE))
	g.apply(CellGrid.cmd_fill(0, floor_cy - 3, 20, floor_cy - 3, Mat.STONE))
	t.expect_error("no headroom")
	var res := MonsterPlacement.resolve(g, 1, MonsterDefs.KIND_PIG, floor_cy)
	t.ok(not res.get("ok", true), "천장이 낮으면 실패로 보고된다")


func _teaching_order_pig_then_hen_then_wolf(t) -> void:
	var first_pig := _first_tx_of(MonsterDefs.KIND_PIG)
	var first_hen := _first_tx_of(MonsterDefs.KIND_HEN)
	var first_wolf := _first_tx_of(MonsterDefs.KIND_WOLF)
	t.ok(first_pig >= 0 and first_hen >= 0 and first_wolf >= 0, "세 종류 다 표에 있다 (전제)")
	t.ok(first_hen > first_pig, "닭의 첫 등장(tx %d)이 돼지의 첫 등장(tx %d)보다 뒤다" % [first_hen, first_pig])
	t.ok(first_wolf > first_hen, "늑대의 첫 등장(tx %d)이 닭의 첫 등장(tx %d)보다 뒤다" % [first_wolf, first_hen])


func _first_tx_of(kind: int) -> int:
	for row: Dictionary in Stage1Monsters.ROWS:
		if int(row["kind"]) == kind:
			return int(row["tx"])
	return -1


## Pins the counts down (`stage1_monsters.gd`'s own header table), so a future edit to the table has to
## touch this number deliberately instead of drifting past it unnoticed.
func _zone_totals(t) -> void:
	var counts: Dictionary = {}
	for row: Dictionary in Stage1Monsters.ROWS:
		var k: int = row["kind"]
		counts[k] = counts.get(k, 0) + 1
	t.eq(counts.get(MonsterDefs.KIND_PIG, 0), 17, "돼지 총수가 17이다 (pre-① 11 + zone② 6)")
	t.eq(counts.get(MonsterDefs.KIND_HEN, 0), 9, "닭 총수가 9다 (pre-① 5 + zone② 4)")
	t.eq(counts.get(MonsterDefs.KIND_WOLF, 0), 4, "늑대 총수가 4다 (pre-① 2 + zone② 2)")
	t.eq(counts.get(MonsterDefs.KIND_BULL, 0), 1, "황소가 정확히 하나다")
	t.eq(counts.get(MonsterDefs.KIND_ROOSTER, 0), 1, "수탉이 정확히 하나다")
	t.eq(Stage1Monsters.ROWS.size(), 32, "표 전체 행 수가 32다")


## **§6's invariant, and it is per clump, not per run.** A clump is easier to skip than an even spread —
## with three clumps, walking past one throws away a third of the run's XP in a single decision, and
## nothing forces the fight (the player at 260px/s outruns wolf 240, hen 220, pig 160). So **every single
## clump has to be worth a level on its own**, which is `Progress.xp_for_level(0)` — read from the
## levelling curve rather than typed as a second copy of 60.
##
## **The last assert is the one that stops a row from quietly falling outside every clump.** Without it,
## moving one row into a gap leaves the three clump sums untouched and this check green.
func _every_clump_is_worth_at_least_sixty_xp(t) -> void:
	var need := Progress.xp_for_level(0)
	t.ok(need > 0, "전제 — 레벨 1 문턱을 읽었다 (%d)" % need)
	var covered := 0
	for c: Array in CLUMP_TX:
		var xp := 0
		var n := 0
		for row: Dictionary in Stage1Monsters.ROWS:
			var tx := int(row["tx"])
			if tx < int(c[0]) or tx > int(c[1]):
				continue
			xp += MonsterDefs.xp_of(int(row["kind"]))
			n += 1
		covered += n
		t.eq(n, 6, "무리(tx %d-%d)는 6행이다" % [c[0], c[1]])
		t.ok(xp >= need,
			"무리(tx %d-%d) 하나만 잡아도 레벨 1(%dxp)이 된다 (%dxp)" % [c[0], c[1], need, xp])

	var bull_tx := _first_tx_of(MonsterDefs.KIND_BULL)
	var pre := 0
	for row: Dictionary in Stage1Monsters.ROWS:
		if int(row["tx"]) < bull_tx and not BossAi.has_pattern(int(row["kind"])):
			pre += 1
	t.eq(covered, pre, "① 앞 잡몹 %d행이 전부 세 무리 안에 들어 있다 (무리 밖에 흘린 행 %d개)"
		% [pre, pre - covered])


## **The shelves themselves, measured on the real baked map by literal tile number.** §4: ordinary
## `STONE`, top surface 2 tiles (64px) above the flat, **solid all the way down to the ground**, vertical
## sides. Every one of those four words is a separate assert here:
##  · rows 18-19 stone across the whole span — that is "solid to the ground", and it is what makes
##    `resolve()`'s upward scan land on the shelf with no `ty` hint and no code change at all
##  · row 17 open — the top surface really is at row 18, so the rise really is 64px
##  · row 20 stone under it — the shelf sits on the flat, it is not floating
##  · the columns immediately west and east open at rows 18-19 — **vertical faces.** A ramp here would
##    still pass every other check and would be the "ground mound" the user rejected, walkable with
##    `Character.STEP_CELLS`, with no jump involved at all
func _the_stone_shelves_are_solid_to_the_ground_by_literal_tile(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	var tc := Tuning.TILE_CELLS
	var not_stone := 0
	var not_open_above := 0
	var no_ground_under := 0
	var face_blocked := 0
	for sh: Array in SHELF_TILES:
		for tx in range(int(sh[0]), int(sh[1]) + 1):
			for ty in range(SHELF_TOP_TY, FLAT_GROUND_TY):
				for dy in tc:
					for dx in tc:
						if g.mat_at(tx * tc + dx, ty * tc + dy) != Mat.STONE:
							not_stone += 1
			if g.is_solid(tx * tc + tc / 2, (SHELF_TOP_TY - 1) * tc + tc / 2):
				not_open_above += 1
			if not g.is_solid(tx * tc + tc / 2, FLAT_GROUND_TY * tc + tc / 2):
				no_ground_under += 1
		for ty in range(SHELF_TOP_TY, FLAT_GROUND_TY):
			if g.is_solid((int(sh[0]) - 1) * tc + tc / 2, ty * tc + tc / 2):
				face_blocked += 1
			if g.is_solid((int(sh[1]) + 1) * tc + tc / 2, ty * tc + tc / 2):
				face_blocked += 1
	t.eq(not_stone, 0, "선반 세 개가 18~19번 줄 전체까지 돌로 꽉 차 있다 (빈 칸 %d개)" % not_stone)
	t.eq(not_open_above, 0, "선반 바로 위(17번 줄)는 뚫려 있다 — 윗면이 정말 18번 줄이다 (%d칸)"
		% not_open_above)
	t.eq(no_ground_under, 0, "선반 아래 20번 줄은 원래 바닥이다 — 떠 있지 않다 (%d칸)" % no_ground_under)
	t.eq(face_blocked, 0, "선반 양 옆은 비어 있다 — 옆면이 수직이다 (경사면이면 걸어 올라간다) (%d칸)"
		% face_blocked)


## **The row lands on the shelf, and that is the whole "no new column in the table" claim** (§4).
## Pinned as absolute px, both ways: three rows whose `tx` sits inside a shelf must resolve 64px higher
## than three rows that do not. **`tx29`/`tx60`/`tx88` are the east-end rows of the three shelves**;
## `tx14`/`tx45`/`tx73` are the approach-ground rows of the same three clumps.
func _a_shelf_row_resolves_onto_the_shelf_top_not_the_ground(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	var shelf_feet := SHELF_TOP_TY * TILE_PX
	var ground_feet := FLAT_GROUND_TY * TILE_PX
	t.eq(ground_feet - shelf_feet, 64, "전제 — 선반 윗면이 바닥보다 정확히 64px 높다")
	for tx: int in [29, 60, 88]:
		var res := MonsterPlacement.resolve(g, tx, MonsterDefs.KIND_HEN, Stage1Monsters.FLOOR_CY)
		t.ok(res.get("ok", false), "tx%d가 착지한다 (전제)" % tx)
		t.eq(int(res["py"]) + MonsterDefs.h_px(MonsterDefs.KIND_HEN), shelf_feet,
			"tx%d는 선반 윗면(%dpx)에 선다 — 바닥이 아니다" % [tx, shelf_feet])
	for tx: int in [14, 45, 73]:
		var res := MonsterPlacement.resolve(g, tx, MonsterDefs.KIND_HEN, Stage1Monsters.FLOOR_CY)
		t.ok(res.get("ok", false), "tx%d가 착지한다 (전제)" % tx)
		t.eq(int(res["py"]) + MonsterDefs.h_px(MonsterDefs.KIND_HEN), ground_feet,
			"tx%d는 그대로 바닥(%dpx)에 선다 — 선반 밖이다" % [tx, ground_feet])


## **§8b — the shelf carries the hen's own stopping distance.** `_dist_to_target` is horizontal only and
## a stirred hen walks until it is `BOLT_STOP_PX` from the player, so a hen with less than that much
## shelf to its west steps off its own platform during the approach and Acceptance 6 is simply false.
## **That is also why a shelf can hold exactly one hen** — the second one would have to sit further west.
func _every_shelf_hen_keeps_its_240px_of_shelf_to_the_west(t) -> void:
	var need := int(MonsterBolts.BOLT_STOP_PX)
	var total := 0
	for sh: Array in SHELF_TILES:
		var hens := 0
		for row: Dictionary in Stage1Monsters.ROWS:
			var tx := int(row["tx"])
			if int(row["kind"]) != MonsterDefs.KIND_HEN or tx < int(sh[0]) or tx > int(sh[1]):
				continue
			hens += 1
			total += 1
			var west_px := (tx - int(sh[0])) * TILE_PX
			t.ok(west_px >= need,
				"선반(x%d-%d) 위 닭 tx%d의 서쪽에 선반이 %dpx 남아 있다 (%dpx 필요)"
				% [sh[0], sh[1], tx, west_px, need])
		t.ok(hens <= 1, "선반(x%d-%d) 위 닭은 최대 하나다 (%d마리)" % [sh[0], sh[1], hens])
	t.ok(total >= 2, "선반 위 닭이 실제로 존재한다 (%d마리) — 없으면 위 규칙이 아무것도 안 잰다" % total)


# ══════════════════════════════════════════════════════════════════
#  Stage B — rows become monsters
# ══════════════════════════════════════════════════════════════════

func _flat_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, SYN_FLOOR_CY - 4, 4000, SYN_FLOOR_CY, Mat.STONE))
	return g


func _wake_scan_creates_a_monster_inside_the_activation_band_not_before(t) -> void:
	var g := _flat_grid()
	var mp := MonsterPlacement.new()
	mp.set_rows([{"tx": 100, "kind": MonsterDefs.KIND_PIG}], SYN_FLOOR_CY)
	var spawned: Array[int] = []
	# **A 4th parameter, `entrance`** (`boss-entrance-and-hp-bar.md` Stage A) — `wake_scan()` now calls
	#  `spawn_fn` with it unconditionally (true, every row), so a 3-arg spy errors on every call and this
	#  whole check silently measures nothing (`spawned` never grows). Unused here on purpose — this check is
	#  about the activation band, not the entrance flag; `net_boss_entrance.gd` is where that flag is measured.
	var spy := func(_kind: int, px: int, _py: int, _entrance: bool) -> int:
		spawned.append(px)
		return 1
	var center_x := 100 * Tuning.TILE_CELLS * Tuning.CELL_PX

	mp.wake_scan(g, center_x - int(MonsterPlacement.MATERIALIZE_PX) - 50, spy)
	t.eq(spawned.size(), 0, "구현 거리(720px) 밖에서는 스폰 시도가 없다")

	mp.wake_scan(g, center_x, spy)
	t.eq(spawned.size(), 1, "활성화 거리 안에 들어오면 정확히 한 번 스폰된다")
	t.ok(mp.is_live(0), "그 행이 살아있는 상태로 표시된다")

	mp.wake_scan(g, center_x, spy)
	t.eq(spawned.size(), 1, "이미 살아있는 행은 같은 자리에서 다시 스폰을 시도하지 않는다")


func _a_killed_row_never_comes_back(t) -> void:
	var g := _flat_grid()
	var mp := MonsterPlacement.new()
	mp.set_rows([{"tx": 50, "kind": MonsterDefs.KIND_PIG}], SYN_FLOOR_CY)
	# **A boxed counter** — GDScript lambdas capture a local by value (`net_settlement.gd`'s own comment
	#  on this exact trap); an `Array`'s captured value is a reference to the same object, so mutating its
	#  contents (not reassigning the variable) reaches the same object this scope reads.
	var next_id := [1]
	# **4-arg spy** — see the comment on the first `spy` above (`wake_scan()`'s own new `entrance` argument).
	var spy := func(_kind: int, _px: int, _py: int, _entrance: bool) -> int:
		var id: int = next_id[0]
		next_id[0] += 1
		return id
	var center_x := 50 * Tuning.TILE_CELLS * Tuning.CELL_PX

	mp.wake_scan(g, center_x, spy)
	t.ok(mp.is_live(0), "행이 살아났다 (전제)")

	mp.on_monster_died(1)
	t.ok(mp.is_spent(0), "죽고 나면 소진 처리된다")
	t.ok(not mp.is_live(0), "그리고 더 이상 살아있는 상태가 아니다")

	mp.wake_scan(g, center_x, spy)
	t.eq(next_id[0], 2, "소진된 행은 다시 깨어나 스폰을 시도하지 않는다 (id 발급이 늘지 않았다)")


func _reset_rearms_every_row(t) -> void:
	var g := _flat_grid()
	var mp := MonsterPlacement.new()
	mp.set_rows([{"tx": 50, "kind": MonsterDefs.KIND_PIG}], SYN_FLOOR_CY)
	# **4-arg spy** — see the comment on `_wake_scan_creates_a_monster_inside_the_activation_band_not_before`'s
	#  own `spy` (`wake_scan()`'s new `entrance` argument).
	var spy := func(_kind: int, _px: int, _py: int, _entrance: bool) -> int:
		return 1
	var center_x := 50 * Tuning.TILE_CELLS * Tuning.CELL_PX

	mp.wake_scan(g, center_x, spy)
	mp.on_monster_died(1)
	t.ok(mp.is_spent(0), "전제 — 죽어서 소진됐다")

	mp.reset()
	t.ok(not mp.is_spent(0), "reset() 이후엔 소진 상태가 풀린다")
	t.ok(not mp.is_live(0), "그리고 살아있는 상태도 아니다 (처음부터 다시)")

	mp.wake_scan(g, center_x, spy)
	t.ok(mp.is_live(0), "reset() 뒤엔 다시 깨어날 수 있다")


func _a_capped_refusal_leaves_the_row_dormant_not_spent(t) -> void:
	var g := _flat_grid()
	var mp := MonsterPlacement.new()
	mp.set_rows([{"tx": 50, "kind": MonsterDefs.KIND_PIG}], SYN_FLOOR_CY)
	# **4-arg refuse** — see the comment on the first `spy` above (`wake_scan()`'s new `entrance` argument).
	var refuse := func(_kind: int, _px: int, _py: int, _entrance: bool) -> int:
		return 0  # the cap, simulated
	var center_x := 50 * Tuning.TILE_CELLS * Tuning.CELL_PX

	mp.wake_scan(g, center_x, refuse)
	t.ok(not mp.is_live(0), "거절되면 살아있는 상태가 아니다")
	# **Inversion — spend on refusal and this goes red** (the plan's own line): if `wake_scan` marked a
	#  refused row spent, the assertion right below would fail, and the retry check after it would too
	#  (a spent row is skipped forever, so `accept` would never be reached).
	t.ok(not mp.is_spent(0), "그리고 소진되지도 않는다 (다시 시도할 수 있다)")

	# **4-arg accept** — see the comment on the first `spy` above (`wake_scan()`'s new `entrance` argument).
	var accept := func(_kind: int, _px: int, _py: int, _entrance: bool) -> int:
		return 7
	mp.wake_scan(g, center_x, accept)
	t.ok(mp.is_live(0), "다음 틱에 문이 열리면 실제로 살아난다 (재시도가 실제로 동작한다)")


## **The ordering trap** (CLAUDE.md) — a check that reads only final state cannot tell "wakes on the
## tick" from "wakes on the frame" apart, since both eventually reach the same final count. This reads
## the count *between* ticks too.
func _the_wake_scan_only_runs_on_the_tick(t) -> void:
	var g := _flat_grid()
	var ch := Character.new()
	var px := 50 * Tuning.TILE_CELLS * Tuning.CELL_PX
	ch.place(px, SYN_FLOOR_CY * Tuning.CELL_PX - Character.H_PX)
	var world := WorldStep.new(g, SpellSim.new(), ch)
	world.set_placement([{"tx": 50, "kind": MonsterDefs.KIND_PIG}], SYN_FLOOR_CY)
	t.eq(world.monster_count(), 0, "전제 — 아직 틱이 한 번도 안 돌았다")

	for _i in Tuning.TICK_DIVIDER - 1:
		world.frame(DT, 0.0, false, false)
	t.eq(world.monster_count(), 0,
		"틱 경계 전의 60Hz 프레임들에서는 안 깬다 (플레이어가 바로 그 자리에 서 있는데도)")

	world.frame(DT, 0.0, false, false)
	t.eq(world.monster_count(), 1, "틱이 도는 바로 그 프레임에 깬다")


## **Hysteresis, and it moved** (`left-run-clumps-and-platforms.md` §8). The band no longer governs a
## dormant row — it governs a **live monster's `asleep`**, and its numbers are `STIR_ENTER_PX`(420) /
## `STIR_EXIT_PX`, inside the visible band so the player watches the stir happen.
## `stays_active` is pure, so this drives the real production function with no world at all — the same
## door `world_step`'s sleep pass calls, not a copy of the comparison.
##
## A monster hovering inside the band must not flip state every tick.
func _the_stir_band_flips_once_not_every_tick(t) -> void:
	var enter := MonsterPlacement.STIR_ENTER_PX
	var exit_px := MonsterPlacement.STIR_EXIT_PX
	t.ok(exit_px > enter, "전제 — 나가는 문턱이 들어오는 문턱보다 멀다 (그게 대역이다)")
	# **Derived from the constants, not written as literals.** This used to be
	#  `[400, 422, 540, ...]` — chosen by hand to sit inside the 420/560 band, and it **broke the day
	#  `STIR_ENTER_PX` was retuned to 300**, because 400 stopped being inside `enter`. The check owned
	#  neither number and should never have spelled them.
	#  Becomes active just inside `enter`; then jitters strictly **inside the dead band** (above `enter`,
	#  below `exit_px`), where a single-threshold rule would flip on every crossing and the band must not.
	var inside := enter - 20.0
	var lo := enter + 2.0
	var hi := exit_px - 20.0
	t.ok(lo < hi, "전제 — 대역이 흔들릴 만큼 넓다 (%.0f ~ %.0f)" % [lo, hi])
	var offsets := [inside, lo, hi, lo, hi, lo, hi, lo, hi, inside]
	var flips := 0
	var naive_flips := 0
	var last := false
	var naive_last := false
	for d in offsets:
		var now := MonsterPlacement.stays_active(last, d, enter, exit_px)
		if now != last:
			flips += 1
		last = now
		# **Not a copy of the production algorithm** — the naive rule the band exists to replace.
		var naive_now: bool = d <= enter
		if naive_now != naive_last:
			naive_flips += 1
		naive_last = naive_now

	t.eq(flips, 1, "%.0f/%.0f 대역 안에서 흔들려도 실제로는 한 번만 뒤집힌다 (%d번)" % [enter, exit_px, flips])
	t.ok(naive_flips > flips,
		"단일 문턱이었다면 훨씬 자주 뒤집혔을 것이다 (naive %d회 vs 실제 %d회)" % [naive_flips, flips])


## **The other half of §8: materialising has no hysteresis at all** — `wake_scan` passes
## `MATERIALIZE_PX` as *both* ends. A row never returns to dormant once it is live, so an exit threshold
## could only ever have governed how often a refused row re-knocks, and with the boss reserve a pre-①
## row is not refused any more.
##
## **This is what a leftover band would look like**: at 722px a `[720, 840)` exit keeps `_primed` true,
## and a single threshold drops it. The three offsets below are chosen so those two answers differ.
## *Inversion: pass `STIR_EXIT_PX` (or the old 840) as `wake_scan`'s exit and the middle assert goes red.*
func _materialising_is_one_threshold_with_no_hysteresis(t) -> void:
	var g := _flat_grid()
	var mp := MonsterPlacement.new()
	var kind := MonsterDefs.KIND_PIG
	mp.set_rows([{"tx": 50, "kind": kind}], SYN_FLOOR_CY)
	# **4-arg refuse** — see the comment on the first `spy` above (`wake_scan()`'s new `entrance` argument).
	var refuse := func(_kind: int, _px: int, _py: int, _entrance: bool) -> int:
		return 0  # stays dormant regardless — isolates the `_primed` bit from the spawn outcome
	# **Production measures distance to the row's centre**, not its left edge (verify-read's own finding
	#  on the check this replaced) — `half_w` is added here so `d` below **is** the real `dist`.
	var half_w := float(MonsterDefs.w_px(kind)) * 0.5
	var row_center_x := 50 * Tuning.TILE_CELLS * Tuning.CELL_PX + int(half_w)

	mp.wake_scan(g, int(row_center_x + 700.0), refuse)
	t.ok(mp.get("_primed")[0], "720 안(700)에서 준비된다")
	mp.wake_scan(g, int(row_center_x + 722.0), refuse)
	t.ok(not mp.get("_primed")[0],
		"720을 넘자마자(722) 바로 풀린다 — 대역이 남아 있었다면 840까지 붙어 있었을 자리다")
	mp.wake_scan(g, int(row_center_x + 700.0), refuse)
	t.ok(mp.get("_primed")[0], "다시 들어오면 다시 준비된다")


# ══════════════════════════════════════════════════════════════════
#  Stage D — sleep (`Monster.step()`'s own gate)
# ══════════════════════════════════════════════════════════════════

func _frames(w: WorldStep, n: int) -> void:
	for _i in n:
		w.frame(DT, 0.0, false, false)


## **Wakes exactly one row into a real monster and returns the world.** Sleep only ever applies to a
## monster `MonsterPlacement` actually placed (`world_step.gd`'s own gate, `has_row_for`) — a bare
## `world.spawn_monster()` call, the shape every check above this section and every *other* net in this
## repo uses, is permanently un-sleepable by design. Every check below this point routes through here
## instead, specifically to exercise the real sleep path rather than a shape sleep does not apply to.
## `ch` is the caller's own reference (GDScript objects are reference types) so it can move the character
## again after this returns, to test what happens once distance grows.
func _wake_one_row(g: CellGrid, ch: Character, tx: int, kind: int) -> WorldStep:
	var mob_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	ch.place(mob_x, SYN_FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, SpellSim.new(), ch)
	world.set_placement([{"tx": tx, "kind": kind}], SYN_FLOOR_CY)
	_frames(world, Tuning.TICK_DIVIDER)
	return world


## §4.1, half 1 — **a sleeping monster standing in fire still loses hp and can die, with the player far
## away** (the user's own decided behavior: "자는 모습도 불에 탈 거고"). *Inversion: skip `_burn` too while
## asleep and this goes red* — a sleeping hen would then sit in the fire forever at full hp.
## Also closes the design doc's own "XP from an off-screen death still lands" (`Progress` is not positional).
func _a_sleeping_monster_standing_in_fire_still_takes_damage_and_can_die(t) -> void:
	# **The hen, not the pig** — measured directly (`FIRE_SPREAD_TICKS`=1, `FIRE_BURN_PER_TICK`=5,
	#  `Mat.WOOD` fuel=200): a single ignition under an ~11-cell-wide footprint gives at most ~50 ticks of
	#  *some* footprint cell burning (spread reaches the far edge in ~11 ticks, the last cell to catch
	#  then burns ~40 ticks of its own fuel) — a hard ceiling of ~25hp at `Character.BURN_DPS`=10/s no
	#  matter how the wood is arranged around it, which a pig (30 max hp) survives every time (measured:
	#  it stopped at 6hp). The hen's 10 max hp sits well inside that ceiling.
	var kind := MonsterDefs.KIND_HEN
	var tx := 50
	var mob_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	# Wood right under the row's own footprint, on the slab's top row — `Body.standing_in_fire`'s own
	#  "fire is attached to the cells under your feet" (`body.gd`). Placed *before* waking it, since
	#  `resolve()` reads the grid at wake time, not the table.
	var cx0 := floori(float(mob_x) / float(Tuning.CELL_PX))
	var cx1 := floori(float(mob_x + MonsterDefs.w_px(kind) - 1) / float(Tuning.CELL_PX))
	var g := _flat_grid()
	g.apply(CellGrid.cmd_fill(cx0, SYN_FLOOR_CY - 4, cx1, SYN_FLOOR_CY - 4, Mat.WOOD))
	var ch := Character.new()
	var world := _wake_one_row(g, ch, tx, kind)
	t.eq(world.monster_count(), 1, "행이 깨어나 닭이 스폰됐다 (전제)")

	# The player leaves — far enough that the mob sleeps from this tick.
	ch.place(mob_x + 4000, SYN_FLOOR_TOP - Character.H_PX)
	_frames(world, Tuning.TICK_DIVIDER)
	t.ok(world.monster_at(0).asleep, "플레이어가 멀리 있어 잠들었다 (전제)")
	t.ok(g.ignite(cx0, SYN_FLOOR_CY - 4), "나무에 불이 붙었다 (전제)")

	var pr := world.progress()
	t.eq(pr.xp, 0, "죽기 전엔 xp가 0이다 (전제)")
	_frames(world, Tuning.TICK_DIVIDER * 250)
	t.eq(world.monster_count(), 0, "잠든 채로도 불에 타 죽는다 (플레이어는 그동안 멀리 있었다)")
	t.eq(pr.xp, MonsterDefs.xp_of(kind),
		"화면 밖에서 죽어도 xp는 표 값(%d)만큼 정확히 들어온다" % MonsterDefs.xp_of(kind))


## §4.1, half 2 — **a sleeping monster on flat ground does not move**, over hundreds of frames, with the
## player far to one side. *Inversion: run the whole `step()` regardless of `asleep` and this goes red* —
## a pig would then walk the entire distance to the player instead of standing still.
func _a_sleeping_monster_on_flat_ground_does_not_move(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var tx := 50
	var mob_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	var g := _flat_grid()
	var ch := Character.new()
	var world := _wake_one_row(g, ch, tx, kind)
	t.eq(world.monster_count(), 1, "전제")

	ch.place(mob_x + 4000, SYN_FLOOR_TOP - Character.H_PX)
	_frames(world, Tuning.TICK_DIVIDER)
	t.ok(world.monster_at(0).asleep, "멀리 있어 잠들었다 (전제)")
	var x0 := world.monster_at(0).x
	_frames(world, Tuning.TICK_DIVIDER * 100)
	t.eq(world.monster_at(0).x, x0,
		"잠든 채로는 평지에서도 수백 프레임 동안 한 픽셀도 움직이지 않는다")


## The jump/separation session's own trash-mob jump (`monster.gd:step()`, `blocked and on_ground and not
## BossAi.has_pattern(kind)`) sits *inside* the block sleep skips — this proves it stays there in practice,
## not just by reading the line numbers. A wall placed exactly where an awake pig would ram into and hop
## must not move a sleeping one at all.
func _a_sleeping_monster_does_not_jump_even_when_blocked(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var tx := 50
	var mob_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	var wall_cx := floori(float(mob_x + MonsterDefs.w_px(kind)) / float(Tuning.CELL_PX))
	var g := _flat_grid()
	g.apply(CellGrid.cmd_fill(wall_cx, SYN_FLOOR_CY - 40, wall_cx + 2, SYN_FLOOR_CY - 4, Mat.STONE))
	var ch := Character.new()
	var world := _wake_one_row(g, ch, tx, kind)
	t.eq(world.monster_count(), 1, "전제 — 벽 바로 앞에 스폰됐다")

	ch.place(mob_x + 4000, SYN_FLOOR_TOP - Character.H_PX)
	# **Correction (`monster-ai-jump-and-separation.md`, verify-read item 5): sleep now defers to the tick
	#  the monster is actually grounded** (`world_step.gd`'s own sleep decision) — a mob mid-jump must not
	#  freeze `on_ground` at `false` forever (`monster_view.resolve_state` would then stick on
	#  `MON_AIRBORNE`). This wall sits flush against the spawn, so the pig is blocked and jumps on the very
	#  first frame it tries to walk toward the now-far player — it is genuinely airborne for a few frames
	#  before landing, so "asleep" is polled for, not assumed after one fixed tick. The real cycle measured
	#  here is 27 frames (9 ticks) — `Monster._grounded_recently` catches the landing deterministically
	#  within that same tick, so 15 ticks is comfortable margin, not a hope for lucky phase alignment.
	var asleep := false
	for _i in 15:
		_frames(world, Tuning.TICK_DIVIDER)
		if world.monster_at(0).asleep:
			asleep = true
			break
	t.ok(asleep, "잠들었다 (전제 — 벽에 막혀 뛰다가 착지하는 틈을 기다린다)")
	var y0 := world.monster_at(0).y
	var x0 := world.monster_at(0).x
	_frames(world, Tuning.TICK_DIVIDER * 20)
	t.eq(world.monster_at(0).y, y0, "잠든 채로는 막혀 있어도 뛰지 않는다 (y가 그대로다)")
	t.eq(world.monster_at(0).x, x0, "x도 그대로다 (벽 쪽으로 걷지도 않는다)")


## The judgment call the plan left open: sleep excludes a monster from separation, **on both sides**
## (`world_step.gd`'s own comment on why — separation is a form of movement, and a sleeping mob standing
## where an awake one shoves it off would break "the pig stays in the pit"; the reverse — an awake mob
## reading a sleeping one as a push source — has no reason to exist either).
## **Forces `asleep` directly** (`net_progress._kill`'s own directness, `hp = 0`) to isolate the exclusion
## itself from the hysteresis timing that would otherwise decide it — and only calls `frame()` **once**,
## staying inside the tick boundary (`Tuning.TICK_DIVIDER`=3), because the tick branch recomputes `asleep`
## from live distance and would overwrite this override.
func _a_sleeping_monster_is_excluded_from_separation_both_ways(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var x0 := 200
	var x1 := x0 + 5  # heavy overlap — well past `OVERLAP_THRESHOLD_PX`(4)

	# Baseline first, both awake — proves this exact overlap actually triggers real separation, or the
	#  exclusion check below would trivially pass for the wrong reason (nothing ever moves regardless).
	var g1 := _flat_grid()
	var ch1 := Character.new()
	ch1.place(300, SYN_FLOOR_TOP - Character.H_PX)
	var w1 := WorldStep.new(g1, SpellSim.new(), ch1)
	w1.spawn_monster(kind, x0, SYN_FLOOR_TOP - MonsterDefs.h_px(kind))
	w1.spawn_monster(kind, x1, SYN_FLOOR_TOP - MonsterDefs.h_px(kind))
	w1.frame(DT, 0.0, false, false)
	t.ok(w1.monster_at(0).x != x0 or w1.monster_at(1).x != x1,
		"둘 다 깨어있으면 이 겹침이 실제로 분리를 일으킨다 (전제 — 안 그러면 아래 검사가 의미 없다)")

	var g2 := _flat_grid()
	var ch2 := Character.new()
	# **The character's own centre sits exactly on the awake mob's centre**, not merely "close" —
	#  `_next_axis` returns `0.0` there (`monster.gd:_toward_player_axis`, compared centre to centre), so
	#  the awake mob has no walking motion of its own to confound this measurement. `Character.center()`
	#  is `place()`'s `px` plus half `W_PX`, not `px` itself — matching the *monster's* centre needs that
	#  offset subtracted back out, or the character ends up `W_PX/2` off and the mob still walks a couple
	#  px toward it (measured: exactly this mistake read as "separation" moving the mob by 3px).
	var awake_center := x1 + MonsterDefs.w_px(kind) / 2
	ch2.place(awake_center - Character.W_PX / 2, SYN_FLOOR_TOP - Character.H_PX)
	var w2 := WorldStep.new(g2, SpellSim.new(), ch2)
	w2.spawn_monster(kind, x0, SYN_FLOOR_TOP - MonsterDefs.h_px(kind))
	w2.spawn_monster(kind, x1, SYN_FLOOR_TOP - MonsterDefs.h_px(kind))
	w2.monster_at(0).asleep = true
	var sleepy_x := w2.monster_at(0).x
	var awake_x := w2.monster_at(1).x
	w2.frame(DT, 0.0, false, false)
	t.eq(w2.monster_at(0).x, sleepy_x, "자는 쪽은 겹쳐 있어도 밀려나지 않는다 (분리 대상에서 빠진다)")
	t.eq(w2.monster_at(1).x, awake_x,
		"깨어있는 쪽도 자는 쪽에게서 밀려나지 않는다 (자는 쪽이 미는 힘의 근원도 못 된다)")


## Waking restores movement — the same mob moves again once the player returns.
func _waking_restores_movement(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var tx := 50
	var mob_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	var g := _flat_grid()
	var ch := Character.new()
	var world := _wake_one_row(g, ch, tx, kind)
	t.eq(world.monster_count(), 1, "전제")

	ch.place(mob_x + 4000, SYN_FLOOR_TOP - Character.H_PX)
	_frames(world, Tuning.TICK_DIVIDER)
	t.ok(world.monster_at(0).asleep, "멀리 있어 잠들었다 (전제)")
	var x0 := world.monster_at(0).x
	_frames(world, Tuning.TICK_DIVIDER * 10)
	t.eq(world.monster_at(0).x, x0, "자는 동안은 안 움직인다 (전제)")

	ch.place(mob_x + 100, SYN_FLOOR_TOP - Character.H_PX)
	_frames(world, Tuning.TICK_DIVIDER)
	t.ok(not world.monster_at(0).asleep, "플레이어가 가까워지면 다시 깨어난다")
	_frames(world, Tuning.TICK_DIVIDER * 5)
	t.ok(world.monster_at(0).x != x0, "깨어나면 실제로 다시 걷는다")


## Acceptance 4 — a mob trapped in a dug pit is still in that pit after the player is far away for a long
## stretch (asleep the whole time). **A value, not a screenshot**: x and y read unchanged across it.
## **A real pit, not merely flat ground** — `_flat_grid()`'s own slab is only 4 cells thick (top at
## `SYN_FLOOR_CY - 4`), so this test builds its own thicker one (40 cells) with a genuine gap carved down
## into it, walled on both sides by the untouched slab, so `MonsterPlacement.resolve()`'s ordinary upward
## scan lands the row on the pit's own floor — the same production path a real dug pit uses, not a
## hand-picked y.
func _the_pit_holds_while_asleep(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, SYN_FLOOR_CY - 40, 4000, SYN_FLOOR_CY, Mat.STONE))
	var tx := 50
	var mob_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	var pit_cx0 := floori(float(mob_x) / float(Tuning.CELL_PX)) - 3
	var pit_cx1 := floori(float(mob_x + MonsterDefs.w_px(kind)) / float(Tuning.CELL_PX)) + 3
	# Carve down to one cell above the slab's own bottom (`SYN_FLOOR_CY - 1`) — the pit's floor.
	g.apply(CellGrid.cmd_fill(pit_cx0, SYN_FLOOR_CY - 39, pit_cx1, SYN_FLOOR_CY - 1, Mat.EMPTY))
	var ch := Character.new()
	var world := _wake_one_row(g, ch, tx, kind)
	t.eq(world.monster_count(), 1, "구덩이 바닥에 행이 깨어나 스폰됐다 (전제)")
	# The pit's own floor sits far below the flat surface elsewhere in this same grid — comparing to
	#  where this exact kind would stand on *that* flat surface (not the bare surface constant, which is
	#  a cell boundary, not a monster's own `y`) catches the resolver missing the pit entirely.
	var flat_stand_y := SYN_FLOOR_TOP - MonsterDefs.h_px(kind)
	t.ok(world.monster_at(0).y > flat_stand_y,
		"실제로 구덩이 바닥에 섰다 (평지에 섰을 때보다 y가 더 크다 — 더 아래다) (전제)")

	ch.place(mob_x + 4000, SYN_FLOOR_TOP - Character.H_PX)
	_frames(world, Tuning.TICK_DIVIDER)
	t.ok(world.monster_at(0).asleep, "멀리 있어 잠들었다 (전제)")
	var x0 := world.monster_at(0).x
	var y0 := world.monster_at(0).y
	_frames(world, Tuning.TICK_DIVIDER * 300)  # 두 화면을 걸어갔다 오는 정도의 시간
	t.eq(world.monster_at(0).x, x0, "구덩이 속에서 자는 동안 x가 그대로다")
	t.eq(world.monster_at(0).y, y0, "그리고 y도 그대로다 — 판 구덩이에 그대로 있다")


# ══════════════════════════════════════════════════════════════════
#  verify-read's isolated-worktree pass (S1-S7) on Stages A-C
# ══════════════════════════════════════════════════════════════════

## **S1 — the shell's wiring line, un-measured until now.** Deleting `stage.gd`'s
## `_world.set_placement(...)` line left all 31 nets green (`net_gate._wired_root()` *does* call
## `reset_stage()` -> `_build_room()`, so the line runs — nothing downstream ever read the result).
## Drives the real scene, the real table, the real `_build_room()` — not `WorldStep` built by hand.
func _the_wiring_line_actually_reaches_the_real_stage(t) -> void:
	var root := NetGate.new()._wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	t.eq(world.monster_count(), 0, "막 나온 순간에는 아직 아무도 안 깼다 (전제 — 스폰 지점은 첫 행에서 활성화 거리 안이다)")
	for _i in Tuning.TICK_DIVIDER * 3:
		root.call("_physics_process", 1.0 / 60.0)
	t.ok(world.monster_count() > 0,
		"실제 스테이지로 나가면 배선 줄이 실제 표를 밀어넣어 몬스터가 깬다 (지워도 초록이던 자리)")
	root.free()


## **S6 — the real map never actually exercises the scan direction.** Both synthetic checks above
## (`_the_floating_platform_trap_...`) prove the *logic*; this pins `resolve()`'s real output on the real
## map at the two columns where up/down genuinely disagree (measured directly, not assumed):
##  · `tx49` — upward finds `ty20` (the real ground); downward finds `ty15` (the floating bedrock block)
##  · `tx258` (the rooster's own row) — upward finds `ty25` (room ③'s real floor); downward finds `ty12`
##    (its roof)
## **Both columns are -100 from what they were** — `left-run-clumps-and-platforms.md` §1 cut map columns
##  x2-101 and the bake re-origined; the slab and the room themselves did not move one tile relative to
##  each other. The cell rows below (160, 200) are unchanged, which is the point: only x moved.
## Flipping the scan direction would move both of these, on the real map, not only in a hand-built grid.
func _the_real_map_scan_direction_matters_not_just_synthetic_grids(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	var res49 := MonsterPlacement.resolve(g, 49, MonsterDefs.KIND_PIG, Stage1Monsters.FLOOR_CY)
	t.ok(res49.get("ok", false), "tx49가 실제 맵에서 착지한다 (전제)")
	t.eq(int(res49["py"]) + MonsterDefs.h_px(MonsterDefs.KIND_PIG), 160 * Tuning.CELL_PX,
		"tx49가 실제 지면(ty20, cy160)에 선다 — 위에 뜬 기반암(ty15)이 아니다")

	var res258 := MonsterPlacement.resolve(g, 258, MonsterDefs.KIND_ROOSTER, Stage1Monsters.FLOOR_CY)
	t.ok(res258.get("ok", false), "tx258가 실제 맵에서 착지한다 (전제)")
	t.eq(int(res258["py"]) + MonsterDefs.h_px(MonsterDefs.KIND_ROOSTER), 200 * Tuning.CELL_PX,
		"tx258가 방③의 실제 바닥(ty25, cy200)에 선다 — 지붕(ty12)이 아니다")


## **S3 — a boss placed outside its own room is undetectable by every other check here** (they only ask
## "does it land on solid ground", never "in the right room"). Room ① floor is `tx130-159`, measured
## directly. Room ③'s **interior** floor is `tx245-266`** — `tx267`/`268` are the room's own right wall
## (measured: `topmost_solid_cy` jumps from `200` to `96` there, the wall's own height, not the floor's).
func _bosses_are_placed_inside_their_own_room(t) -> void:
	var bull_tx := _first_tx_of(MonsterDefs.KIND_BULL)
	t.ok(bull_tx >= 0, "표에 황소가 있다 (전제)")
	t.ok(bull_tx >= 130 and bull_tx <= 159,
		"황소의 tx(%d)가 방① 바닥 범위(130-159) 안이다" % bull_tx)

	var rooster_tx := _first_tx_of(MonsterDefs.KIND_ROOSTER)
	t.ok(rooster_tx >= 0, "표에 수탉이 있다 (전제)")
	t.ok(rooster_tx >= 245 and rooster_tx <= 266,
		"수탉의 tx(%d)가 방③ 내부 바닥 범위(245-266) 안이다 (267-268은 오른쪽 벽)" % rooster_tx)


## **S4 — `_zone_totals` pins numbers, not the invariant those numbers exist to protect.** Reverting
## pre-① to 24 rows and updating only the hardcoded expected counts there stays green. This asks the
## actual question: does the trash-mob count before the bull's own row fit under `MAX_MONSTERS`.
##
## **The bound was one comparison too loose and this net was green with the bug live**
## (`left-run-clumps-and-platforms.md` §5): `pre_count <= MAX_MONSTERS` reads 20 <= 20 as fine, while
## **20 trash + 1 bull = 21** is the number that decides whether the midboss exists at all. The reserve
## is what the cap actually holds back, so the bound is `MAX_MONSTERS - boss_rows`.
## **This is still only the cheap sibling** — it counts rows and never makes a monster.
## `_a_boss_row_still_spawns_when_the_trash_cap_is_full` below drives the real door.
func _pre_stage1_row_count_stays_under_the_cap(t) -> void:
	var bull_tx := _first_tx_of(MonsterDefs.KIND_BULL)
	t.ok(bull_tx >= 0, "전제 — 황소 tx를 찾았다")
	var pre_count := 0
	var boss_rows := 0
	for row: Dictionary in Stage1Monsters.ROWS:
		if BossAi.has_pattern(int(row["kind"])):
			boss_rows += 1
		elif int(row["tx"]) < bull_tx:
			pre_count += 1
	t.ok(boss_rows > 0, "전제 — 표에 보스 행이 있다")
	t.ok(pre_count <= MonsterDefs.MAX_MONSTERS - boss_rows,
		"① 앞(tx < %d) 잡몹 행 수(%d)가 상한에서 보스 몫(%d칸)을 뺀 값(%d) 이하다"
		% [bull_tx, pre_count, boss_rows, MonsterDefs.MAX_MONSTERS - boss_rows])


## **The cap bug, driven — the check the row count above cannot be** (§5). Fill the world with trash to
## the ceiling the reserve leaves, then let the boss row wake, and assert **the boss is actually alive**.
## Counting rows can only ever say "the table looks fine"; this says "the midboss exists".
##
## **Two asserts, and the first one is the reserve itself.** With `MAX_MONSTERS` 20 and one boss row, the
## trash ceiling is 19 — a 20th trash mob must be turned away *while a slot is still empty*, which is the
## whole mechanism. Without it the 20th trash mob is accepted and the bull is refused with **no error at
## all**, which is exactly what shipped.
##
## *Inversion: delete the `- reserve` from `world_step.spawn_monster` and both asserts go red* — `made`
## becomes 20 and the boss never appears.
func _a_boss_row_still_spawns_when_the_trash_cap_is_full(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var tx := 50
	var mob_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	var g := _flat_grid()
	var ch := Character.new()
	ch.place(mob_x, SYN_FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, SpellSim.new(), ch)
	# One boss row, resolving where the player already stands — inside `MATERIALIZE_PX` from tick one.
	world.set_placement([{"tx": tx, "kind": MonsterDefs.KIND_BULL}], SYN_FLOOR_CY)
	# Trash, far away so none of them ever touch the player or the waking row. **More than the cap on
	#  purpose** — the refusals are what is being measured.
	var made := 0
	for i in MonsterDefs.MAX_MONSTERS + 5:
		if world.spawn_monster(kind, mob_x + 5000 + i * 200, SYN_FLOOR_TOP - MonsterDefs.h_px(kind)) > 0:
			made += 1
	t.eq(made, MonsterDefs.MAX_MONSTERS - 1,
		"잡몹은 상한(%d)에서 보스 몫 1칸을 남기고 %d마리에서 거절된다 (실제 %d마리)"
		% [MonsterDefs.MAX_MONSTERS, MonsterDefs.MAX_MONSTERS - 1, made])

	_frames(world, Tuning.TICK_DIVIDER)
	var bulls := 0
	for i in world.monster_count():
		if world.monster_at(i).kind == MonsterDefs.KIND_BULL:
			bulls += 1
	t.eq(bulls, 1, "잡몹이 꽉 찬 채로도 보스 행이 남겨 둔 자리로 깬다 (황소 %d마리)" % bulls)
	t.eq(world.monster_count(), MonsterDefs.MAX_MONSTERS,
		"그리고 그 자리가 마지막 한 칸이다 (%d마리)" % world.monster_count())


## **The backstop bark** (§5's other half). The reserve is what keeps a boss's slot; the `push_error` is
## for the day the reserve is wrong — a boss made **outside** the table, when the world is genuinely
## full. Unreachable in a correct build, which is what a guard should be. Driven here by spawning a boss
## directly with no placement table at all, so `boss_row_count()` is 0 and every slot is taken.
func _a_boss_refused_at_the_real_cap_barks(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var g := _flat_grid()
	var ch := Character.new()
	ch.place(0, SYN_FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, SpellSim.new(), ch)
	for i in MonsterDefs.MAX_MONSTERS:
		world.spawn_monster(kind, 5000 + i * 200, SYN_FLOOR_TOP - MonsterDefs.h_px(kind))
	t.eq(world.monster_count(), MonsterDefs.MAX_MONSTERS, "전제 — 표 없이 상한까지 꽉 찼다 (예비 0칸)")
	t.expect_error("boss reserve is wrong")
	var id := world.spawn_monster(MonsterDefs.KIND_BULL, 4000, SYN_FLOOR_TOP - MonsterDefs.h_px(MonsterDefs.KIND_BULL))
	t.eq(id, 0, "진짜 상한에서는 보스도 거절된다")
	# A trash mob at the same full cap is refused **silently** — the bark is for bosses only, or every
	#  ordinary over-cap debug spawn would start shouting.
	var id2 := world.spawn_monster(kind, 4000, SYN_FLOOR_TOP - MonsterDefs.h_px(kind))
	t.eq(id2, 0, "잡몹도 거절되지만 조용하다 (짖음은 보스 몫이다)")



## **A `MonsterView` that catches its own wake mark.** The same technique, and the same reason, as
## `net_gate._CapturingGateView`: GDScript refuses to override a native `CanvasItem` call, so the
## production class cuts an ordinary script method out of `_draw()` and a subclass intercepts *that*.
## `super()` still runs, so the real drawing is not replaced by the measurement.
class _CapturingMonsterView extends MonsterView:
	var centers: Array[Vector2] = []
	var ages: Array[float] = []
	## **The modulate the body and the outline each draw with, this frame.** `_draw_flipped` is an
	## ordinary script method (the native `draw_texture_rect_region` sits *inside* it), so overriding it
	## catches presentation A — the dim on a dormant body — which has no other trace at all.
	##
	## **Split by canvas, and that split is not cosmetic.** Measured: with the two folded into one array
	## the check stayed **green** while `_draw_monster_body`'s dim was deleted outright — the outline's
	## own dim (drawn onto a child layer) alone kept the minimum at 0.45. One array measured "something
	## on this node is dim", never "the body is dim". The body is the only thing drawn onto `self`.
	var alphas: Array[float] = []
	var outline_alphas: Array[float] = []

	func _paint_wake_mark(center: Vector2, age: float) -> void:
		centers.append(center)
		ages.append(age)
		super(center, age)

	func _draw_flipped(canvas: CanvasItem, tex: Texture2D, src: Rect2, r: Rect2, flip: bool,
			modulate: Color) -> void:
		if canvas == self:
			alphas.append(modulate.a)
		elif canvas.name == MonsterView.LAYER_OUTLINE:
			outline_alphas.append(modulate.a)
		super(canvas, tex, src, r, flip, modulate)


## **"`_draw()` ran" is not "anything was drawn"** (CLAUDE.md) — so this asserts the arguments
## `MonsterView._draw()` hands its own hook, treed and pumped through real engine frames.
##
## The three states the mark has to tell apart, in one world:
##  · a **debug-spawned** monster, which never sleeps at all (`world_step`'s `has_row_for` gate) — it must
##    never mark, not even on the frame the view first sees it. That is the "already awake" case, and the
##    naive `if not m.asleep: mark()` would fire on it every single frame
##  · a **placed row that is asleep** — materialised at 720 but outside the stir band. No mark
##  · the **stir itself** — the player walks inside `STIR_ENTER_PX` and the row's `asleep` flips. **One mark, at that
##    monster's own centre, at age 0**
##
## *Inversion: delete the `_paint_wake_mark` call from `_draw()` and the last three asserts go red.*
func _the_view_paints_a_wake_mark_exactly_when_a_mob_stirs(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var tx := 50
	var mob_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	var g := _flat_grid()
	var ch := Character.new()
	# **Inside `MATERIALIZE_PX`(720) and outside `STIR_ENTER_PX`** — the exact gap §8a exists to
	#  create: the row is standing there, asleep, before the player can see it.
	ch.place(mob_x + 600, SYN_FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, SpellSim.new(), ch)
	# The control: never placed by the table, so it can never sleep and must never mark.
	world.spawn_monster(kind, mob_x + 3000, SYN_FLOOR_TOP - MonsterDefs.h_px(kind))
	world.set_placement([{"tx": tx, "kind": kind}], SYN_FLOOR_CY)
	_frames(world, Tuning.TICK_DIVIDER * 8)
	t.eq(world.monster_count(), 2, "행이 구현됐다 — 디버그 몹 하나 + 표 행 하나 (전제)")
	var placed := world.monster_at(1)
	t.ok(placed.asleep, "표 행은 깨우기 거리 밖이라 자고 있다 (전제)")
	t.ok(not world.monster_at(0).asleep, "디버그 몹은 애초에 잠들지 않는다 (전제)")

	var view := _CapturingMonsterView.new()
	view.setup(world)
	t.root.add_child(view)
	await t.pump_frames(3)
	t.eq(view.centers.size(), 0,
		"이미 깨어 있는 몹에도, 자고 있는 몹에도 표시를 안 그린다 (그린 횟수 %d)" % view.centers.size())

	# ── presentation A: the dormant body is drawn dim, the awake one is not ──
	# **The control is in the same frame**, so this cannot pass by everything being dim.
	view.alphas.clear()
	view.outline_alphas.clear()
	await t.pump_frames(1)
	t.eq(view.alphas.size(), 2, "전제 — 이 프레임에 몸통이 둘 다 그려졌다 (%d번)" % view.alphas.size())
	t.ok(view.outline_alphas.size() > 0,
		"전제 — 테두리도 그려졌다 (%d번)" % view.outline_alphas.size())
	if view.alphas.size() > 0:
		t.ok(absf(view.alphas.min() - Fx.MONSTER_ASLEEP_ALPHA) < 0.01,
			"자는 몹의 **몸통**을 %.2f 투명도로 흐리게 그린다 (가장 흐린 값 %.3f)"
			% [Fx.MONSTER_ASLEEP_ALPHA, view.alphas.min()])
		t.ok(view.alphas.max() > 0.99,
			"같은 프레임에서 깨어 있는 몹 몸통은 그대로 그린다 (가장 진한 값 %.3f)" % view.alphas.max())
	if view.outline_alphas.size() > 0:
		t.ok(absf(view.outline_alphas.min() - Fx.MONSTER_ASLEEP_ALPHA) < 0.01,
			"**테두리도 같이** 흐려진다 — 몸통만 흐리면 크림색 실루엣만 남는다 (가장 흐린 값 %.3f)"
			% view.outline_alphas.min())

	# The player walks in — inside the stir band.
	ch.place(mob_x, SYN_FLOOR_TOP - Character.H_PX)
	_frames(world, Tuning.TICK_DIVIDER)
	t.ok(not placed.asleep, "표 행이 깨어났다 (전제)")

	var want := MonsterView.box_rect(placed.kind, placed.x, placed.y).get_center()
	want.y -= Fx.MONSTER_WAKE_MARK_LIFT_PX
	view.alphas.clear()
	view.outline_alphas.clear()
	await t.pump_frames(1)
	if view.alphas.size() > 0:
		t.ok(view.alphas.min() > 0.99,
			"깨어난 뒤에는 흐린 몸통이 하나도 없다 (가장 흐린 값 %.3f)" % view.alphas.min())
	if view.outline_alphas.size() > 0:
		t.ok(view.outline_alphas.min() > 0.99,
			"테두리도 마찬가지다 (가장 흐린 값 %.3f)" % view.outline_alphas.min())
	t.eq(view.centers.size(), 1, "깨어난 그 프레임에 정확히 한 번 그린다 (%d번)" % view.centers.size())
	if view.centers.size() > 0:
		t.eq(view.centers[0], want, "그 몹 자신의 자리 바로 위에 그린다 (%s)" % want)
		t.eq(view.ages[0], 0.0, "그리고 그 순간의 나이는 0이다 (막 태어난 표시다)")

	# It ages instead of re-firing: one stir, one mark, and the mark moves through its own life.
	await t.pump_frames(1)
	t.eq(view.centers.size(), 2, "다음 프레임에도 같은 표시 하나를 계속 그린다")
	if view.ages.size() > 1:
		t.ok(view.ages[1] > view.ages[0], "나이가 늘어난다 (%f -> %f)" % [view.ages[0], view.ages[1]])
	t.eq(view.wake_mark_count(), 1, "표시는 여전히 하나뿐이다 (깨어남 한 번 = 표시 한 개)")

	t.root.remove_child(view)
	view.queue_free()


## **S7, half 1 — the wake scan's position relative to the death-removal loop was an unmeasured comment.**
## Fills the cap, kills one monster the same tick a placement row is ready to wake, and asserts the row
## fills the freed slot **the same tick** — only true if death removal runs before the wake scan.
## *Inversion: move `wake_scan` before the death loop and this goes red* (verified by reading the exact
## edit that would do it, not merely claimed).
func _wake_scan_runs_after_death_removal_so_a_freed_slot_is_usable_the_same_tick(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var tx := 50
	var mob_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	var g := _flat_grid()
	var ch := Character.new()
	ch.place(mob_x, SYN_FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, SpellSim.new(), ch)
	# Fill the cap far away from the character so none of them ever contact it or the waking row.
	for i in MonsterDefs.MAX_MONSTERS:
		world.spawn_monster(kind, mob_x + 5000 + i * 200, SYN_FLOOR_TOP - MonsterDefs.h_px(kind))
	t.eq(world.monster_count(), MonsterDefs.MAX_MONSTERS, "상한까지 채웠다 (전제)")
	world.set_placement([{"tx": tx, "kind": kind}], SYN_FLOOR_CY)
	world.monster_at(0).hp = 0  # dies this same tick's on_tick pass
	_frames(world, Tuning.TICK_DIVIDER)
	t.eq(world.monster_count(), MonsterDefs.MAX_MONSTERS,
		"죽어서 빈 자리를 같은 틱 안에서 새 행이 채운다 (사망 제거가 깨우기보다 먼저 돈다)")


## **S7, half 2 — the wake scan's position relative to `_char_hit_by_monsters()` was the other
## unmeasured comment.** A row resolves exactly where the player already stands; if the scan runs before
## the contact check (as the doc claims), the player takes contact damage the **same** tick it wakes.
func _wake_scan_runs_before_contact_damage_so_a_mob_that_wakes_overlapping_the_player_hits_the_same_tick(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var tx := 50
	var mob_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	var stand_y := SYN_FLOOR_TOP - MonsterDefs.h_px(kind)
	var g := _flat_grid()
	var ch := Character.new()
	ch.place(mob_x, stand_y)  # exactly where the row resolves — guaranteed box overlap on wake
	var world := WorldStep.new(g, SpellSim.new(), ch)
	world.set_placement([{"tx": tx, "kind": kind}], SYN_FLOOR_CY)
	t.eq(world.monster_count(), 0, "전제 — 아직 안 깼다")
	_frames(world, Tuning.TICK_DIVIDER)
	t.eq(world.monster_count(), 1, "이 틱에 행이 깬다 (전제)")
	t.ok(ch.hp < Character.MAX_HP,
		"겹친 채로 깨어난 바로 그 틱에 접촉 피해를 입는다 (깨우기가 접촉 판정보다 먼저 돈다)")


## **The dormant approach is visible before the mob wakes — and that is a *relationship*, not a value.**
##
## **Two readers in one night inferred the opposite** from "`STIR_ENTER_PX` 420 < half-viewport 480" and
## concluded mobs wake off screen, so the fix must be to *raise* it. **The camera lead is what they missed**:
## `Fx.CAM_LEAD_PX` leads toward travel, so the visible edge ahead is **480 + that**, not 480 — the mob was
## already visible while asleep, and raising the stir distance **shrinks** that window.
##
## **This does not pin the constant's value** (that would be counting it in two places). It pins the three
## things that make the value legal, so a future retune has to stay inside them.
func _the_sleeping_approach_is_visible_and_the_hen_stays_on_its_shelf(t) -> void:
	var half_view := 480.0        # 960 viewport / 2, at ZOOM_STEPS[0] = 1.0
	var visible_ahead := half_view + Fx.CAM_LEAD_PX
	# **Derived, not written down.** It read `552.0` as a literal and went red the day `CAM_LEAD_PX` moved
	#  72 -> 32 — the number was right and the *source* of it was the bug.
	t.eq(visible_ahead, 480.0 + Fx.CAM_LEAD_PX,
		"진행 방향으로 보이기 시작하는 거리가 %.0fpx다 (480 + 카메라 선행 %.0f — 전제)"
			% [480.0 + Fx.CAM_LEAD_PX, Fx.CAM_LEAD_PX])

	# (1) **Visible before it wakes.** This is the one the two wrong inferences would have broken.
	var window_px := visible_ahead - MonsterPlacement.STIR_ENTER_PX
	t.ok(window_px > 0.0,
		"몹이 깨기 전에 화면에 보인다 (자는 채로 보이는 구간 %.0fpx)" % window_px)
	# **And long enough to read**, not a technicality. At 260px/s, half a second was the complaint.
	t.ok(window_px / Character.MOVE_SPEED_PX >= 0.8,
		"그 구간이 0.8초 이상이다 (%.2f초 — 0.51초일 때 '거의 안 보인다'는 보고가 나왔다)"
			% (window_px / Character.MOVE_SPEED_PX))

	# (2) **The shelf ceiling.** A stirred hen walks until `BOLT_STOP_PX` from the player, so it covers
	#  `STIR_ENTER_PX - 240` px, against 288px of shelf west of every shelf hen.
	var walk := MonsterPlacement.STIR_ENTER_PX - 240.0
	t.ok(walk <= 288.0,
		"깬 닭이 걷는 거리가 선반 여유 288px 안이다 (%.0fpx — 넘으면 선반에서 떨어진다)" % walk)

	# (3) **Hysteresis survives.** Collapsing the band makes a monster on the boundary flip every tick.
	t.ok(MonsterPlacement.STIR_ENTER_PX < MonsterPlacement.STIR_EXIT_PX,
		"들어가는 거리가 나가는 거리보다 작다 (%.0f < %.0f)"
			% [MonsterPlacement.STIR_ENTER_PX, MonsterPlacement.STIR_EXIT_PX])
