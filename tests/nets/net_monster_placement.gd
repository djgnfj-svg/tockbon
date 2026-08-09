extends RefCounted
## `src/stage/stage1_monsters.gd` (the table) and `src/actor/monster_placement.gd` (the resolver + the
## runner) — `docs/plans/3.done/monster-placement-stage1.md`, Stages A+B.
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


func run(t) -> void:
	_table_is_sorted_by_tx(t)
	_adjacent_rows_are_at_least_3_tiles_apart(t)
	_no_two_resolved_boxes_intersect_on_the_real_map(t)
	_every_row_stands_exactly_on_the_surface(t)
	_the_floating_platform_trap_resolves_to_real_ground(t)
	_a_groundless_column_barks_and_reports_not_ok(t)
	_a_low_ceiling_barks_and_reports_not_ok(t)
	_teaching_order_pig_then_hen_then_wolf(t)
	_zone_totals(t)
	_wake_scan_creates_a_monster_inside_the_activation_band_not_before(t)
	_a_killed_row_never_comes_back(t)
	_reset_rearms_every_row(t)
	_a_capped_refusal_leaves_the_row_dormant_not_spent(t)
	_the_wake_scan_only_runs_on_the_tick(t)
	_hysteresis_flips_once_not_every_tick(t)
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
	t.eq(counts.get(MonsterDefs.KIND_HEN, 0), 11, "닭 총수가 11이다 (pre-① 7 + zone② 4)")
	t.eq(counts.get(MonsterDefs.KIND_WOLF, 0), 4, "늑대 총수가 4다 (pre-① 2 + zone② 2)")
	t.eq(counts.get(MonsterDefs.KIND_BULL, 0), 1, "황소가 정확히 하나다")
	t.eq(counts.get(MonsterDefs.KIND_ROOSTER, 0), 1, "수탉이 정확히 하나다")
	t.eq(Stage1Monsters.ROWS.size(), 34, "표 전체 행 수가 34다")


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
	var spy := func(_kind: int, px: int, _py: int) -> int:
		spawned.append(px)
		return 1
	var center_x := 100 * Tuning.TILE_CELLS * Tuning.CELL_PX

	mp.wake_scan(g, center_x - int(MonsterPlacement.WAKE_PX) - 50, spy)
	t.eq(spawned.size(), 0, "활성화 거리(720px) 밖에서는 스폰 시도가 없다")

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
	var spy := func(_kind: int, _px: int, _py: int) -> int:
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
	var spy := func(_kind: int, _px: int, _py: int) -> int:
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
	var refuse := func(_kind: int, _px: int, _py: int) -> int:
		return 0  # the cap, simulated
	var center_x := 50 * Tuning.TILE_CELLS * Tuning.CELL_PX

	mp.wake_scan(g, center_x, refuse)
	t.ok(not mp.is_live(0), "거절되면 살아있는 상태가 아니다")
	# **Inversion — spend on refusal and this goes red** (the plan's own line): if `wake_scan` marked a
	#  refused row spent, the assertion right below would fail, and the retry check after it would too
	#  (a spent row is skipped forever, so `accept` would never be reached).
	t.ok(not mp.is_spent(0), "그리고 소진되지도 않는다 (다시 시도할 수 있다)")

	var accept := func(_kind: int, _px: int, _py: int) -> int:
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


## **Hysteresis** — `WAKE_PX`(720)/`SLEEP_PX`(840) as a band, not one threshold. A row hovering inside
## the band must not flip its internal `_primed` bit every tick.
func _hysteresis_flips_once_not_every_tick(t) -> void:
	var g := _flat_grid()
	var mp := MonsterPlacement.new()
	var kind := MonsterDefs.KIND_PIG
	mp.set_rows([{"tx": 50, "kind": kind}], SYN_FLOOR_CY)
	var refuse := func(_kind: int, _px: int, _py: int) -> int:
		return 0  # stays dormant regardless — isolates the `_primed` bit from the spawn outcome
	# **Verify-read's own finding**: production measures distance to the row's **centre**
	#  (`monster_placement.gd:171-173`, `tx * TILE_CELLS * CELL_PX + half_w`), not its left edge. A
	#  variable named `center_x` that actually held the left edge made every offset below land ~22px
	#  (the pig's own `half_w`) short of where it claimed to be — every one of 700/715/725 landed at
	#  678/693/703, **never once inside [720, 840)**, so this check never entered the band it claims to
	#  test. Fixed by adding `half_w` here, so `d` below **is** the real `dist` `wake_scan` computes.
	var half_w := float(MonsterDefs.w_px(kind)) * 0.5
	var row_center_x := 50 * Tuning.TILE_CELLS * Tuning.CELL_PX + int(half_w)

	# Primes once at 700 (inside `WAKE_PX`=720); then jitters between 722 and 780 — **inside the [720,
	# 840) dead band**, never below 720 (which would re-prime, already primed) and never above 840 (which
	# would un-prime) — before finally dropping to 700 again. A single-threshold rule (no band) flips on
	# every crossing of 720; the band must not.
	var offsets := [700.0, 722.0, 780.0, 722.0, 780.0, 722.0, 780.0, 722.0, 780.0, 700.0]
	var flips := 0
	var naive_flips := 0
	var last: bool = mp.get("_primed")[0]
	var naive_last := false
	for d in offsets:
		mp.wake_scan(g, int(row_center_x + d), refuse)
		var now: bool = mp.get("_primed")[0]
		if now != last:
			flips += 1
		last = now
		# **Not a copy of the production algorithm** — the naive rule the band exists to replace:
		#  "primed iff dist <= WAKE_PX", recomputed from `d`, which (now) **is** the real `dist` — the
		#  same value production's own `wake_scan` computes, not a separate quantity like the raw offset
		#  used to be before the fix above.
		var naive_now: bool = d <= MonsterPlacement.WAKE_PX
		if naive_now != naive_last:
			naive_flips += 1
		naive_last = naive_now

	t.eq(flips, 1, "720/840 대역 안에서 흔들려도 실제로는 한 번만 뒤집힌다 (%d번)" % flips)
	t.ok(naive_flips > flips,
		"단일 문턱이었다면 훨씬 자주 뒤집혔을 것이다 (naive %d회 vs 실제 %d회)" % [naive_flips, flips])


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
##  · `tx149` — upward finds `ty20` (the real ground); downward finds `ty15` (the floating bedrock block)
##  · `tx358` (the rooster's own row) — upward finds `ty25` (room ③'s real floor); downward finds `ty12`
##    (its roof)
## Flipping the scan direction would move both of these, on the real map, not only in a hand-built grid.
func _the_real_map_scan_direction_matters_not_just_synthetic_grids(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	var res149 := MonsterPlacement.resolve(g, 149, MonsterDefs.KIND_PIG, Stage1Monsters.FLOOR_CY)
	t.ok(res149.get("ok", false), "tx149가 실제 맵에서 착지한다 (전제)")
	t.eq(int(res149["py"]) + MonsterDefs.h_px(MonsterDefs.KIND_PIG), 160 * Tuning.CELL_PX,
		"tx149가 실제 지면(ty20, cy160)에 선다 — 위에 뜬 기반암(ty15)이 아니다")

	var res358 := MonsterPlacement.resolve(g, 358, MonsterDefs.KIND_ROOSTER, Stage1Monsters.FLOOR_CY)
	t.ok(res358.get("ok", false), "tx358가 실제 맵에서 착지한다 (전제)")
	t.eq(int(res358["py"]) + MonsterDefs.h_px(MonsterDefs.KIND_ROOSTER), 200 * Tuning.CELL_PX,
		"tx358가 방③의 실제 바닥(ty25, cy200)에 선다 — 지붕(ty12)이 아니다")


## **S3 — a boss placed outside its own room is undetectable by every other check here** (they only ask
## "does it land on solid ground", never "in the right room"). Room ① floor is `tx230-259`, measured
## directly. Room ③'s **interior** floor is `tx345-366`** — `tx367`/`368` are the room's own right wall
## (measured: `topmost_solid_cy` jumps from `200` to `96` there, the wall's own height, not the floor's).
func _bosses_are_placed_inside_their_own_room(t) -> void:
	var bull_tx := _first_tx_of(MonsterDefs.KIND_BULL)
	t.ok(bull_tx >= 0, "표에 황소가 있다 (전제)")
	t.ok(bull_tx >= 230 and bull_tx <= 259,
		"황소의 tx(%d)가 방① 바닥 범위(230-259) 안이다" % bull_tx)

	var rooster_tx := _first_tx_of(MonsterDefs.KIND_ROOSTER)
	t.ok(rooster_tx >= 0, "표에 수탉이 있다 (전제)")
	t.ok(rooster_tx >= 345 and rooster_tx <= 366,
		"수탉의 tx(%d)가 방③ 내부 바닥 범위(345-366) 안이다 (367-368은 오른쪽 벽)" % rooster_tx)


## **S4 — `_zone_totals` pins numbers, not the invariant those numbers exist to protect.** Reverting
## pre-① to 24 rows and updating only the hardcoded expected counts there stays green. This asks the
## actual question: does the trash-mob count before the bull's own row fit under `MAX_MONSTERS`.
func _pre_stage1_row_count_stays_under_the_cap(t) -> void:
	var bull_tx := _first_tx_of(MonsterDefs.KIND_BULL)
	t.ok(bull_tx >= 0, "전제 — 황소 tx를 찾았다")
	var pre_count := 0
	for row: Dictionary in Stage1Monsters.ROWS:
		if int(row["tx"]) < bull_tx and not BossAi.has_pattern(int(row["kind"])):
			pre_count += 1
	t.ok(pre_count <= MonsterDefs.MAX_MONSTERS,
		"① 앞(tx < %d) 잡몹 행 수(%d)가 상한(%d) 이하다" % [bull_tx, pre_count, MonsterDefs.MAX_MONSTERS])


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
