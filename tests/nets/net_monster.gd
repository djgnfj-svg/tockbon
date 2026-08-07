extends RefCounted
## 몬스터 단계 0·1 — `Body` 추출과 몬스터 한 마리가 서는 것.
##
## 🔴 판정 1(단계 0)은 새 검사 0개다. `Character.W_PX`류는 `net_character`가 이미 재고,
##  층 계약(`src/view/`·`src/stage/` 미참조)도 `net_layers`가 폴더를 재귀 스캔해서 잰다.
## 🔴 여기는 `monster_defs`·`body`·`monster`·`world_step`의 몬스터 몫·`monster_view`를 잰다.
##
## 🔴🔴 **아래 검사들 중 여섯은 첫 판(verify-read)이 격리 사본에서 뮤테이션 12개를 걸어
##  실제로 안 물린 것을 찾은 뒤 고친 것이다** — 새 검사를 넣으면 뒤집어 봐라(CLAUDE.md).
##  | 뚫렸던 것 | 지금 무는 것 |
##  |---|---|
##  | `Monster`가 `Body`에 `w_px`를 안 넘겨도(20px 고정) 착지 y만 보면 안 걸린다 | 가로 이동 없는
##    세로 굴뚝(`_monster_collision_width_gates_the_chimney`) — 32px 틈에 닭은 들어가고 돼지는 걸린다 |
##  | `MAX_MONSTERS`를 20 → 3으로 낮춰도 검사 10이 항진명제라 안 걸린다 | 절대값
##    (`_defs_accessors`의 `MAX_MONSTERS = 20`) |
##  | `stage.gd`의 `monster_requested.connect(`를 지워도(= M키가 죽어도) 66개 전부 초록 | 검사 13이
##    그 문자열도 같이 문다 |
##  | `on_ground`가 영원히 거짓이어도(= 몬스터가 턱을 못 오른다) 전부 초록 | 착지 뒤 `on_ground`가
##    참인지 직접 잰다(옛 검사 7) |
##  | `spawn_monster()`가 `_broken` 문 밖에 있어도 전부 초록 | `net_damage._null_world_refuses`에
##    옮겨 걸었다(그쪽이 `_broken` 계약의 단일 소스다) |
##  | 옛 검사 6·7이 `Monster.step()`을 직접 불러 「몬스터가 세상 루프 안에 산다」의 증인이
##    검사 8 하나뿐이었다 | 6·7을 `world.frame()`을 지나게 다시 짰다 |

## 🔴 주석·문자열 스트리퍼를 **빌려 온다** — 소스 텍스트를 훑는 그물이 여럿이고 스트리퍼는
##  하나여야 한다(`net_damage`·`net_render`와 같은 이유). ⚠ **없이 짰다가 데었다** — 뒤집기로
##  `monster_requested.connect(`를 지우면서 그 사실을 적은 주석에 같은 문자열을 남겼더니
##  `.contains()`가 주석에서 그 문자열을 찾아 **뮤테이션이 하나도 안 물렸다**(실측).
const NetDeterminism := preload("res://tests/nets/net_determinism.gd")

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Body := preload("res://src/actor/body.gd")
const Monster := preload("res://src/actor/monster.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const MonsterView := preload("res://src/view/monster_view.gd")
const MonsterBolts := preload("res://src/actor/monster_bolts.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

const DT := 1.0 / 60.0
const FLOOR_CY := 100
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX
const LEDGE_CX := 30
const STAGE_SCRIPT := "res://src/stage/stage.gd"

# ─── 단계 3 — 탄·폭발 배치 상수 ─────────────────────────────────────
## 발사 원점이 상자 왼쪽으로 이만큼 떨어진다. 🔴 `net_damage.HIT_LEAD_PX`와 같은 값 ·
##  같은 이유다 — 세대 0의 첫 틱 도약(`Tuning.speed_cells(0) * Tuning.CELL_PX`)이 상자보다
##  훨씬 커서, 이 정도 앞에서 쏘면 구간의 양 끝이 **둘 다 상자 밖**인 「도약 배치」가 된다.
const HIT_LEAD_PX := 36

## 폭발을 내리꽂을 발사 원점(셀) — 바닥보다 훨씬 위. `net_damage.BLAST_FROM_CY`와 같은 어법이다.
const BLAST_FROM_CY := FLOOR_CY - 20

func _blast_cmd(cx: int) -> Dictionary:
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	return SpellSim.cmd_fire(cx, BLAST_FROM_CY, 0, 10, Tuning.ELEM_NONE, Glyph.pack(one))

## 🔴🔴 **바닥은 얇게 깐다**(CLAUDE.md 「그물이 느리면…」, 2026-08-07). 옛 바닥(`CellGrid.H-1`까지)이
##  4096×908=3,719,168칸이라 한 번에 2,719ms였다 — 이 파일이 43초를 먹은 원인이 그것이다.
##  ⚠ 안전한 이유: `cell_grid.mat_at()`이 격자 밖을 `STONE`으로 돌려주므로 두꺼울 이유가
##  원래 없었다. 몬스터는 표면 몇 px 안에서만 논다. 32셀(128px)이면 `carve_r`(8셀)의 4배 여유다.
const FLOOR_DEPTH_CY := 32


func run(t) -> void:
	_defs_preconditions(t)
	_defs_accessors(t)
	_body_width_is_a_ctor_arg(t)
	_body_height_is_a_ctor_arg(t)
	_body_step_is_a_ctor_arg(t)
	_monster_collision_width_gates_the_chimney(t)
	_monster_lands_exactly(t)
	_monster_falls_through_the_air(t)
	_frame_is_required_to_move(t)
	_world_holds_monsters(t)
	_spawn_cap(t)
	_spawn_rejects_off_grid(t)
	_ids_are_distinct_and_not_reused(t)
	_view_box_comes_from_the_table(t)
	_shell_hands_the_world_to_the_view(t)
	# ── 단계 2 — 걷는다 ──────────────────────────────────────────
	_walks_toward_the_player(t)
	_walking_monster_blocked_by_wall(t)
	# ── 단계 3 — 다친다 ──────────────────────────────────────────
	_monster_takes_blast_damage(t)
	_monster_hit_by_a_leaping_segment(t)
	_monster_burns_regardless_of_invuln(t)
	_dead_monsters_leave_the_list_correctly(t)
	# ── 단계 4 — 둘이 된다 ───────────────────────────────────────
	_pig_and_hen_cross_the_ledge_differently(t)
	# ── 단계 5 — 돼지가 때린다 ───────────────────────────────────
	_pig_contact_damages_the_player(t)
	_pig_contact_respects_invulnerability(t)
	# ── 단계 6 — 닭이 쏜다 ───────────────────────────────────────
	_hen_stops_at_bolt_range(t)
	_hen_bolt_hits_only_the_player(t)
	_hen_bolt_lifetime_axis(t)
	_hen_bolt_blocked_by_terrain_and_does_not_carve(t)
	_hen_bolt_step_stays_inside_the_player_box(t)
	# ── 단계 7 — 화면 넷 + 시체 ──────────────────────────────────
	_hp_bar_values_come_from_the_table(t)
	_monster_bolt_color_differs_from_magic_bolts(t)
	_hit_triggers_flash_and_a_damage_number_that_ages_out(t)
	_death_notification_spawns_a_corpse_that_ages_out(t)


# ── 1. 전제 ──────────────────────────────────────────────────────
func _defs_preconditions(t) -> void:
	t.ok(Defs.ALL.size() >= 2, "종류가 둘 이상이다 (%d개)" % Defs.ALL.size())
	t.ok(not Defs.ALL.has(Defs.KIND_NONE), "KIND_NONE(예약값)이 ALL에 없다")
	for kind: int in Defs.ALL:
		t.eq(Defs.w_px(kind) % Tuning.CELL_PX, 0,
			"%s의 w_px가 셀(%dpx)의 배수다 (%dpx)" % [
				Defs.name_of(kind), Tuning.CELL_PX, Defs.w_px(kind)])
		t.eq(Defs.h_px(kind) % Tuning.CELL_PX, 0,
			"%s의 h_px가 셀(%dpx)의 배수다 (%dpx)" % [
				Defs.name_of(kind), Tuning.CELL_PX, Defs.h_px(kind)])


# ── 2. 표 접근자 — 절대값과 「다르다」를 둘 다 잰다 ─────────────────
## 🔴 절대값만 재면 표를 죽이고 상수를 박아도 초록이고, 「다르다」만 재면 값이 틀려도 초록이다.
func _defs_accessors(t) -> void:
	t.eq(Defs.w_px(Defs.KIND_PIG), 44, "돼지 w_px = 44")
	t.eq(Defs.h_px(Defs.KIND_PIG), 32, "돼지 h_px = 32")
	t.eq(Defs.step_cells(Defs.KIND_PIG), 1, "돼지 step_cells = 1")
	t.eq(Defs.max_hp(Defs.KIND_PIG), 30, "돼지 max_hp = 30")
	t.eq(Defs.w_px(Defs.KIND_HEN), 24, "닭 w_px = 24")
	t.eq(Defs.h_px(Defs.KIND_HEN), 28, "닭 h_px = 28")
	t.eq(Defs.step_cells(Defs.KIND_HEN), 3, "닭 step_cells = 3")
	t.eq(Defs.max_hp(Defs.KIND_HEN), 10, "닭 max_hp = 10")
	t.ok(Defs.w_px(Defs.KIND_PIG) != Defs.w_px(Defs.KIND_HEN), "돼지 ≠ 닭 (w_px)")
	t.ok(Defs.h_px(Defs.KIND_PIG) != Defs.h_px(Defs.KIND_HEN), "돼지 ≠ 닭 (h_px)")
	t.ok(Defs.step_cells(Defs.KIND_PIG) != Defs.step_cells(Defs.KIND_HEN), "돼지 ≠ 닭 (step_cells)")
	t.ok(Defs.max_hp(Defs.KIND_PIG) != Defs.max_hp(Defs.KIND_HEN), "돼지 ≠ 닭 (max_hp)")
	# 🔴🔴 없으면 `MAX_MONSTERS`를 3으로 낮춰도 검사 10(상한)이 두 값을 같이 읽어 항진명제가
	#  되고, 통과 수만 조용히 준다(실측: 66 → 49, 실패 0개). 20은 사용자가 정한 값이라
	#  「재 보고 조정할 값이 아니다」 — 이 값만은 표에서 파생시키지 않고 직접 박는다.
	t.eq(Defs.MAX_MONSTERS, 20, "MAX_MONSTERS = 20 (사용자가 정한 값이다)")


func _floor_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g


func _wall_grid() -> CellGrid:
	var g := _floor_grid()
	var wall_cx := 30
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 8, wall_cx + 3, FLOOR_CY - 1, Mat.STONE))
	return g


func _ledge_grid(cells: int) -> CellGrid:
	var g := _floor_grid()
	g.apply(CellGrid.cmd_fill(
		LEDGE_CX, FLOOR_CY - cells, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g


# ── 3. Body의 폭이 생성 인자다 ────────────────────────────────────
## 🔴 이게 없으면 `Body`가 인자를 무시하고 20×32를 박아도 `net_character`는 전부 초록이다.
##  ⚠ 높이는 여기서 안 잰다(4가 잰다).
func _body_width_is_a_ctor_arg(t) -> void:
	var g := _wall_grid()
	var wall_px := 30 * Tuning.CELL_PX
	var narrow := Body.new(20, 32, 1)
	narrow.place(40, FLOOR_TOP - 32)
	for _i in 200:
		narrow.move_x(g, 1.0)
	var wide := Body.new(44, 32, 1)
	wide.place(40, FLOOR_TOP - 32)
	for _i in 200:
		wide.move_x(g, 1.0)
	t.eq(narrow.x, wall_px - 20, "폭 20 Body가 벽 앞에서 멈춘다 (x=%d)" % narrow.x)
	t.eq(wide.x, wall_px - 44, "폭 44 Body가 벽 앞에서 멈춘다 (x=%d)" % wide.x)
	t.eq(narrow.x - wide.x, 24, "멈추는 x 차이가 폭 차이(44-20=24)와 같다")


# ── 4. Body의 높이가 생성 인자다 ───────────────────────────────────
## 🔴 인자 순서를 뒤바꾼 실패(w↔h)는 3이 잡는다.
func _body_height_is_a_ctor_arg(t) -> void:
	var g := _floor_grid()
	var short := Body.new(20, 28, 1)
	short.place(160, FLOOR_TOP - 200)
	short.move_y(g, 300.0)
	var tall := Body.new(20, 32, 1)
	tall.place(160, FLOOR_TOP - 200)
	tall.move_y(g, 300.0)
	t.eq(short.y, FLOOR_TOP - 28, "높이 28 Body가 바닥 − 28에 정확히 착지한다")
	t.eq(tall.y, FLOOR_TOP - 32, "높이 32 Body가 바닥 − 32에 정확히 착지한다")
	t.ok(short.y != tall.y, "높이가 다르면 착지 y도 다르다")


# ── 5. Body의 스텝이 생성 인자다 ───────────────────────────────────
## 🔴 몬스터가 그 Body를 쓰는지는 안 잰다(단계 2가 잰다). 없으면 「안 넘기면 단계 4가
##  추출을 다시 연다」가 단계 4까지 조용하다.
func _body_step_is_a_ctor_arg(t) -> void:
	var g := _ledge_grid(2)
	var ledge_px := LEDGE_CX * Tuning.CELL_PX
	# 🔴 `_try_step_up`은 `on_ground`가 참일 때만 작동한다(공중 가드) — 실제 사용(`monster.step`)이
	#  매 프레임 `grounded()`로 갱신하는 것을 여기서도 흉내 낸다. 안 하면 두 Body가 똑같이
	#  「그냥 막힌다」가 되어 이 검사의 요점(step이 실제로 다른 결과를 낸다)이 안 물린다.
	var short_step := Body.new(20, 32, 1)
	short_step.place(40, FLOOR_TOP - 32)
	short_step.on_ground = short_step.grounded(g)
	for _i in 200:
		short_step.move_x(g, 1.0)
	t.eq(short_step.x, ledge_px - 20, "step=1은 2셀 턱에 딱 붙어 막힌다")
	# 🔴 `step_cells` 필드 자체는 아무 로직도 안 읽는다(`step_px`가 생성자에서 직접 나온다) —
	#  값으로 직접 안 재면 그 필드에 든 뮤테이션이 원리적으로 안 잡힌다(검증자 실측).
	t.eq(short_step.step_cells, 1, "step_cells 필드가 생성 인자(1)를 그대로 든다")

	var tall_step := Body.new(20, 32, 3)
	tall_step.place(40, FLOOR_TOP - 32)
	tall_step.on_ground = tall_step.grounded(g)
	for _i in 200:
		tall_step.move_x(g, 1.0)
	t.ok(tall_step.x > ledge_px, "step=3은 2셀 턱을 넘는다 (x=%d)" % tall_step.x)
	t.eq(tall_step.step_cells, 3, "step_cells 필드가 생성 인자(3)를 그대로 든다")


# ── 6-도움. 몬스터 충돌 폭 — 가로 이동 없이 세로 굴뚝으로 잰다 ─────
## 🔴🔴 **착지 y만 보면(옛 검사 6) `Monster`가 `Body`에 `w_px`를 안 넘겨도(20px 고정)
##  66개가 전부 초록이다**(검증자 실측) — 가로 이동이 없으면 폭이 한 번도 안 걸린다.
##  ⇒ **낙하만으로 폭을 건다**: 32px 틈에 닭(24px)은 들어가고 돼지(44px)는 위에 걸린다.
const HOLE_CX := 50
const HOLE_W_CELLS := 8   # 32px — 닭보다 넓고 돼지보다 좁다
## ⚠ 얇은 바닥(`FLOOR_DEPTH_CY` 32셀)보다 깊다 — **일부러 그대로 둔다.** 굴뚝 아래는 어차피
##  얇은 바닥 밖이라 뚫려 있어서, 닭은 격자 밖(자동 고체)에 닿을 때까지 계속 떨어진다.
##  아래 검사는 정확한 깊이가 아니라 `y > FLOOR_TOP`(더 떨어졌나)만 재므로 무관하다.
const HOLE_DEPTH_CELLS := 40


func _chimney_grid() -> CellGrid:
	var g := _floor_grid()
	g.apply(CellGrid.cmd_fill(
		HOLE_CX, FLOOR_CY, HOLE_CX + HOLE_W_CELLS - 1, FLOOR_CY + HOLE_DEPTH_CELLS, Mat.EMPTY))
	return g


## ⚠ **왼쪽 끝을 굴뚝 왼쪽 끝에 맞춘다 — 표에서 나온 값으로 가운데를 잡지 않는다.**
##  가운데로 잡으면(= `hole_center - Defs.w_px(kind)/2`) 오프셋 계산 자체가 `Defs.w_px`를
##  다시 읽어서, `Monster`가 `Body`에 **다른** 폭을 몰래 넘겨도 왼쪽 여백이 자리를 대신 막아
##  「걸린다」가 우연히 다시 나온다(실측 — 돼지 폭을 20으로 몰래 바꿔도 이 검사가 안 물렸다).
##  **왼쪽을 고정하면 실제로 쓰인 폭만이 「굴뚝에 들어맞나」를 정한다.**
func _monster_collision_width_gates_the_chimney(t) -> void:
	var g := _chimney_grid()
	var hole_left := HOLE_CX * Tuning.CELL_PX

	# 🔴 단계 2부터 `_next_axis`가 target을 실제로 읽는다 — target을 스폰 자리의 중심과
	#  같게 둬서 axis가 늘 0이 되게 한다(순수 낙하만 잰다. 걷기는 다른 검사의 몫이다).
	var hen := Monster.new(1, Defs.KIND_HEN, hole_left, FLOOR_TOP - 200)
	var hen_target_x := int(hen.center().x)
	for _i in 600:
		hen.step(g, DT, hen_target_x, 0)
	t.ok(hen.y > FLOOR_TOP, "닭(24px < 32px 틈)이 굴뚝을 통과해 바닥 아래로 더 떨어진다 (y=%d)" % hen.y)

	var pig := Monster.new(2, Defs.KIND_PIG, hole_left, FLOOR_TOP - 200)
	var pig_target_x := int(pig.center().x)
	for _i in 600:
		pig.step(g, DT, pig_target_x, 0)
	t.eq(pig.y, FLOOR_TOP - Defs.h_px(Defs.KIND_PIG),
		"돼지(44px > 32px 틈)는 굴뚝에 안 들어가고 바닥 위에 걸린다 (y=%d)" % pig.y)


# ── 6. 몬스터가 떨어져 지표면에 정확히 선다 ────────────────────────
## 🔴 「보인다」는 헤드리스로 원리적으로 못 잰다 — verify-look이 본다.
## 🔴🔴 **`Monster.step()`을 직접 안 부르고 `world.frame()`을 지나게 짰다** — 안 그러면
##  「몬스터가 세상 루프 안에 산다」의 증인이 검사 8 하나뿐이 되고, 그 증인은
##  「1프레임에 1px 이상 움직였나」만 재서 얇다(검증자 지적).
func _monster_lands_exactly(t) -> void:
	for kind: int in Defs.ALL:
		var world := _new_world()
		var id := world.spawn_monster(kind, 160, FLOOR_TOP - 200)
		t.ok(id > 0, "%s 스폰됐다 (검사의 전제)" % Defs.name_of(kind))
		var m: Monster = world.monster_at(0)
		for _i in 300:
			world.frame(DT, 0.0, false, false)
		t.eq(m.y, FLOOR_TOP - Defs.h_px(kind),
			"%s 몬스터가 바닥 − h_px(%d)에 정확히 선다 (y=%d)" % [Defs.name_of(kind), Defs.h_px(kind), m.y])


# ── 7. 떨어지는 과정 ────────────────────────────────────────────
## ⚠ 없으면 스폰을 바닥에 붙여 놓는 구현이 6을 공짜로 통과한다.
func _monster_falls_through_the_air(t) -> void:
	var world := _new_world()
	var id := world.spawn_monster(Defs.KIND_PIG, 160, FLOOR_TOP - 200)
	t.ok(id > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	var y0 := m.y
	var saw_airborne := false
	for _i in 300:
		world.frame(DT, 0.0, false, false)
		if not m.on_ground:
			saw_airborne = true
	t.ok(m.y != y0, "떨어지며 y가 실제로 바뀐다 (시작 %d → 끝 %d)" % [y0, m.y])
	t.ok(saw_airborne, "떨어지는 동안 on_ground가 거짓인 프레임이 있었다")
	# 🔴🔴 없으면 `on_ground`가 영원히 거짓이어도(= `_try_step_up`의 공중 가드가 늘 막혀
	#  몬스터가 턱을 한 칸도 못 오른다) 66개가 전부 초록이다(검증자 실측). 단계 1엔 `_next_axis`가
	#  0이라 증상이 안 보이고, 단계 2에서 「닭이 턱을 못 넘는다」가 날 때 원인을 엉뚱한 데서 찾게 된다.
	t.ok(m.on_ground, "착지한 뒤 on_ground가 참이다")


# ── 8. frame()을 지나야 움직인다 ───────────────────────────────────
func _new_world() -> WorldStep:
	var g := CellGrid.new()
	# 🔴 여기도 얇게 깐다 — `_floor_grid()`와 같은 이유(위 `FLOOR_DEPTH_CY` 상자).
	#  ⚠ 놓쳤던 자리다: 이 함수가 검사 6·7·8·9·10·11에서 반복 호출되는데 옛 채우기가
	#  그대로 남아 있어서 `net_monster`가 43s→25s로만 줄고 계속 제일 느린 그물이었다.
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(160, FLOOR_TOP - Character.H_PX)
	return WorldStep.new(g, spell, ch)


func _frame_is_required_to_move(t) -> void:
	var world := _new_world()
	var spawn_y := FLOOR_TOP - 200
	var id := world.spawn_monster(Defs.KIND_PIG, 400, spawn_y)
	t.ok(id > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	# 🔴 스폰 자체가 몬스터를 스텝시키지 않는지를 잰다 — 스폰이 조용히 한 프레임을 태우면
	#  여기가 걸린다.
	t.eq(m.y, spawn_y, "frame()을 부르기 전에는 스폰한 y 그대로다")
	world.frame(DT, 0.0, false, false)
	t.ok(m.y != spawn_y, "frame()을 한 번 부르면 몬스터가 움직인다 (y=%d → %d)" % [spawn_y, m.y])


# ── 9. 세상이 든다 ──────────────────────────────────────────────
## 🔴 셋을 같이 걸어야 한다 — 물에서 루프가 한 번도 안 돌고 「잠들었다」가 공짜로 통과했다.
func _world_holds_monsters(t) -> void:
	var world := _new_world()
	world.spawn_monster(Defs.KIND_PIG, 400, FLOOR_TOP - 200)
	t.eq(world.monster_count(), 1, "스폰 뒤 monster_count()가 1이다")

	var loops := 0
	for _i in 30:
		world.frame(DT, 0.0, false, false)
		loops += 1
	t.ok(loops > 1, "프레임을 실제로 여러 바퀴 돌았다 (%d바퀴)" % loops)
	t.eq(world.monster_count(), 1, "그동안 몬스터가 그대로 하나다 (단계 1엔 죽음이 없다)")

	world.reset()
	t.eq(world.monster_count(), 0, "reset() 뒤 monster_count()가 0이다")


# ── 10. 상한 ───────────────────────────────────────────────────
## ⚠ 양성 대조가 없으면 아무것도 안 만드는 구현이 통과한다.
func _spawn_cap(t) -> void:
	var world := _new_world()
	for i in Defs.MAX_MONSTERS:
		var id := world.spawn_monster(Defs.KIND_PIG, 100 + i * 4, FLOOR_TOP - 200)
		t.ok(id > 0, "%d번째 스폰이 성공한다 (상한 %d 이내)" % [i + 1, Defs.MAX_MONSTERS])
	t.eq(world.monster_count(), Defs.MAX_MONSTERS, "상한까지 채웠다 (%d마리)" % Defs.MAX_MONSTERS)
	var over := world.spawn_monster(Defs.KIND_PIG, 900, FLOOR_TOP - 200)
	t.eq(over, 0, "상한을 넘으면 id 0(실패)을 돌려준다")
	t.eq(world.monster_count(), Defs.MAX_MONSTERS, "상한을 넘어도 마릿수가 그대로다")


# ── 14. 격자 밖 좌표는 거절한다 ───────────────────────────────────
## 🔴🔴 verify-look 실측(2026-08-07) — M키가 `get_viewport().get_mouse_position()`을 쓰는데
##  그건 **OS 커서의 실제 위치**라, 커서가 게임 창 밖에 있으면 월드 x가 −983 같은 값으로
##  들어온다. 격자 밖 몬스터는 화면에 절대 안 뜨는데 **상한 20마리 중 한 자리를 유령이 먹는다.**
## 🔴 이 문(`world_step.spawn_monster`)에 두는 이유는 그 함수 머리 주석에 적었다 —
##  **여기가 몬스터를 만드는 유일한 문이라, `_broken`·상한과 나란히 두면 조건이 한 곳에 모인다.**
##  ⚠ `stage.gd`에 두면 그물이 씬 없이 못 재고(헤드리스로 안 돈다), 미래의 다른 호출자
##  (서버 스폰 등)가 각자 다시 짜야 한다.
func _spawn_rejects_off_grid(t) -> void:
	var world := _new_world()
	var grid_w_px := CellGrid.W * Tuning.CELL_PX
	var grid_h_px := CellGrid.H * Tuning.CELL_PX

	t.eq(world.spawn_monster(Defs.KIND_PIG, -983, 100), 0, "왼쪽 밖 좌표는 거절한다 (x=-983)")
	t.eq(world.spawn_monster(Defs.KIND_PIG, 100, -500), 0, "위쪽 밖 좌표는 거절한다 (y=-500)")
	t.eq(world.spawn_monster(Defs.KIND_PIG, grid_w_px + 100, 100), 0, "오른쪽 밖 좌표는 거절한다")
	t.eq(world.spawn_monster(Defs.KIND_PIG, 100, grid_h_px + 100), 0, "아래쪽 밖 좌표는 거절한다")
	# 🔴 좌상단만 보면 못 잡는 자리다 — 상자 오른쪽 끝이 경계를 살짝 넘는 경우도 같이 잰다.
	t.eq(world.spawn_monster(Defs.KIND_PIG, grid_w_px - 1, 100), 0,
		"좌상단은 안이어도 상자 오른쪽 끝이 밖이면 거절한다")
	t.eq(world.monster_count(), 0, "전부 거절됐으니 마릿수가 0이다 (양성 대조가 없으면 무의미하다)")

	# 양성 대조 — 격자 안쪽은 여전히 된다.
	t.ok(world.spawn_monster(Defs.KIND_PIG, 400, 400) > 0, "격자 안 좌표는 그대로 스폰된다 (양성 대조)")
	t.eq(world.monster_count(), 1, "그 하나만 세워졌다")


# ── 11. id가 서로 다르다 · reset() 뒤에도 재사용 안 한다 ───────────
func _ids_are_distinct_and_not_reused(t) -> void:
	var world := _new_world()
	var a := world.spawn_monster(Defs.KIND_PIG, 100, FLOOR_TOP - 200)
	var b := world.spawn_monster(Defs.KIND_PIG, 200, FLOOR_TOP - 200)
	var c := world.spawn_monster(Defs.KIND_HEN, 300, FLOOR_TOP - 200)
	t.ok(a != b and b != c and a != c, "세 id가 서로 다르다 (%d, %d, %d)" % [a, b, c])

	world.reset()
	var d := world.spawn_monster(Defs.KIND_PIG, 100, FLOOR_TOP - 200)
	t.ok(d > c, "reset() 뒤 새 id가 이전 id를 재사용하지 않는다 (%d > %d)" % [d, c])


# ── 12. 뷰가 그리는 상자가 표에서 나온다 ───────────────────────────
## 🔴 색이 맞나 · 화면에 뜨나는 눈이다. `_draw()`가 `box_rect()`만 쓰는지는 아무도 안 잰다 — 규율이다.
func _view_box_comes_from_the_table(t) -> void:
	for kind: int in Defs.ALL:
		var r := MonsterView.box_rect(kind, 40, 60)
		t.eq(r, Rect2(40, 60, Defs.w_px(kind), Defs.h_px(kind)),
			"%s의 box_rect가 표(w=%d,h=%d)에서 나온다" % [Defs.name_of(kind), Defs.w_px(kind), Defs.h_px(kind)])


# ── 13. 껍데기가 뷰에 세상을 넘긴다 · M키가 스폰까지 이어진다 ───────
## 🔴 텍스트라 「부르나」까지고 「도나」가 아니다 — 씬에 노드가 있는지는 `net_render`가 잰다.
## 🔴🔴 **`monster_requested.connect(`와 `_world.spawn_monster(`를 같이 문다** — 없으면
##  M키의 연결이 통째로 지워져도(= 게임에서 M을 눌러도 아무 일이 안 나도) 66개가 전부
##  초록이었다(검증자 실측). HUD가 「몬스터 0/20마리 (M으로 세우기)」로 정상처럼 보여서 더 위험하다.
func _shell_hands_the_world_to_the_view(t) -> void:
	var f := FileAccess.open(STAGE_SCRIPT, FileAccess.READ)
	t.ok(f != null, "stage.gd를 읽었다")
	if f == null:
		return
	# 🔴🔴 **주석·문자열을 지우고 나서 찾는다.** `.contains()`를 원본 소스에 바로 쓰면
	#  「이 문자열을 지웠다」라고 적은 주석 자체가 그 문자열을 다시 담고 있어 검사가 속는다(위 상자).
	var src := NetDeterminism._strip(f.get_as_text())
	t.ok(src.contains("_monster_view.setup("), "껍데기가 `_monster_view.setup(` 을 부른다")
	t.ok(src.contains("monster_requested.connect("),
		"껍데기가 `monster_requested.connect(` 를 부른다 (M키 → 스폰 신호가 이어져 있다)")
	t.ok(src.contains("_world.spawn_monster("),
		"껍데기가 `_world.spawn_monster(` 를 부른다 (스폰 핸들러가 실제로 세상에 만든다)")


# ══════════════════════════════════════════════════════════════════
#  단계 2 — 걷는다
# ══════════════════════════════════════════════════════════════════

func _bare_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g


## 🔴🔴 **단계 3의 피해 검사들이 걸렸던 함정** — 단계 2부터 몬스터가 플레이어 쪽으로 실제로
##  걷는다. 피해·불 검사가 캐릭터를 몬스터에서 먼 곳(예: x=160)에 두면, 판정을 재는 동안
##  몬스터가 그쪽으로 걸어가며 **표적 자리(불 자리 · 폭발 자리)를 벗어난다** — 실측으로
##  「불 위에 서 있었는데 16프레임 만에 burning이 거짓이 됐다」로 드러났다(몬스터가 걸어서
##  불에서 벗어난 것이었다). ⇒ **캐릭터를 몬스터의 스폰 중심과 같은 자리에 둬서 axis가
##  0으로 고정되게 한다** — 걷기가 이 검사들의 관심사가 아닐 때 쓴다.
func _still_ch(stand_x: int, kind: int) -> Character:
	var ch := Character.new()
	var monster_center_x := float(stand_x) + Defs.w_px(kind) * 0.5
	ch.place(roundi(monster_center_x - Character.W_PX * 0.5), FLOOR_TOP - Character.H_PX)
	return ch


## 🔴🔴 **못 재는 것 — 최종 위치만 보면 이 판정이 죽는다**(CLAUDE.md 「최종 상태만 보는 검사」).
##  ⇒ 과정을 잰다: **누적**(`N프레임 이동량 == round(v×N×dt)` ±1px)과 **한 걸음 상한**
##  (`ceil(v×dt)`를 어느 프레임도 안 넘는다 — 순간이동을 잡는다). 수치는 표에서 읽는다.
func _walks_toward_the_player(t) -> void:
	var speed := Defs.speed_px(Defs.KIND_PIG)
	var n := 30
	var step_cap := ceili(speed * DT)

	# 오른쪽에 스폰 → 플레이어(왼쪽)로 걸어와 x가 준다.
	var g1 := _bare_grid()
	var spell1 := SpellSim.new()
	var ch1 := Character.new()
	ch1.place(160, FLOOR_TOP - Character.H_PX)
	var w1 := WorldStep.new(g1, spell1, ch1)
	var y := FLOOR_TOP - Defs.h_px(Defs.KIND_PIG)
	var right_id := w1.spawn_monster(Defs.KIND_PIG, 800, y)
	t.ok(right_id > 0, "오른쪽 스폰이 됐다 (검사의 전제)")
	var right: Monster = w1.monster_at(0)
	var x0 := right.x
	var over_cap_right := false
	for _i in n:
		var prev := right.x
		w1.frame(DT, 0.0, false, false)
		if absi(right.x - prev) > step_cap:
			over_cap_right = true
	var moved_left := x0 - right.x
	t.ok(moved_left > 0, "오른쪽에 스폰하면 왼쪽(플레이어 쪽)으로 걷는다 (x %d → %d)" % [x0, right.x])
	var want := roundi(speed * n * DT)
	t.ok(absi(moved_left - want) <= 1,
		"%d프레임 누적 이동이 v×N×dt에 ±1px로 붙는다 (%d ≈ %d)" % [n, moved_left, want])
	t.ok(not over_cap_right, "어느 프레임도 ceil(v×dt)(%dpx)를 안 넘는다 — 순간이동이 아니다" % step_cap)

	# 왼쪽에 스폰 → 플레이어(오른쪽)로 걸어와 x가 는다. 왼쪽 검사만 있으면 `return 1.0`(늘
	# 오른쪽) 같은 뮤테이션이 안 잡힌다 — 방향을 반대로도 걸어야 그 갈래가 걸린다.
	var g2 := _bare_grid()
	var spell2 := SpellSim.new()
	var ch2 := Character.new()
	ch2.place(900, FLOOR_TOP - Character.H_PX)
	var w2 := WorldStep.new(g2, spell2, ch2)
	var left_id := w2.spawn_monster(Defs.KIND_PIG, 100, y)
	t.ok(left_id > 0, "왼쪽 스폰이 됐다 (검사의 전제)")
	var left: Monster = w2.monster_at(0)
	var x1 := left.x
	var over_cap_left := false
	for _i in n:
		var prev := left.x
		w2.frame(DT, 0.0, false, false)
		if absi(left.x - prev) > step_cap:
			over_cap_left = true
	var moved_right := left.x - x1
	t.ok(moved_right > 0, "왼쪽에 스폰하면 오른쪽(플레이어 쪽)으로 걷는다 (x %d → %d)" % [x1, left.x])
	t.ok(absi(moved_right - want) <= 1,
		"%d프레임 누적 이동이 v×N×dt에 ±1px로 붙는다 (%d ≈ %d)" % [n, moved_right, want])
	t.ok(not over_cap_left, "어느 프레임도 ceil(v×dt)(%dpx)를 안 넘는다 — 순간이동이 아니다" % step_cap)


## 🔴🔴 **뒤집어 보기 — `is_solid`를 통째로 무시하게 만들면 안 된다.** 그러면 바닥을 뚫고
##  영원히 떨어져서 「가로가 막히나」와 무관하게 빨개진다(판정 5가 스스로 금지한 형태).
##  ⇒ 뒤집을 것은 `Body.move_x`의 가로 갈래 하나뿐이고, **대조군**(착지 판정)이 초록으로
##  남아야 진짜 뒤집기다.
func _walking_monster_blocked_by_wall(t) -> void:
	var wall_cx := 60
	var wall_w_cells := 4
	var g := _bare_grid()
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 8, wall_cx + wall_w_cells - 1, FLOOR_CY - 1, Mat.STONE))
	var spell := SpellSim.new()
	var ch := Character.new()
	# 벽 왼쪽에 플레이어를 둔다 — 몬스터는 벽 오른쪽에서 스폰돼 왼쪽(플레이어)으로 걸어오다가
	# 벽의 **오른쪽 면**에서 막힌다(상자 왼쪽 끝이 벽 오른쪽 끝에 닿는다).
	var wall_right_px := (wall_cx + wall_w_cells) * Tuning.CELL_PX
	ch.place(160, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var kind := Defs.KIND_PIG
	var y := FLOOR_TOP - Defs.h_px(kind)
	var mid := world.spawn_monster(kind, wall_right_px + 200, y)
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	for _i in 300:
		world.frame(DT, 0.0, false, false)
	t.eq(m.x, wall_right_px, "벽을 사이에 두면 벽 앞(오른쪽 면)에서 멈추고 더 안 온다")
	t.eq(m.y, y, "가로만 막힌다 — 세로(착지)는 그대로다 (대조군)")


# ══════════════════════════════════════════════════════════════════
#  단계 3 — 다친다
# ══════════════════════════════════════════════════════════════════

## 🔴 값은 표에서 읽는다 — **100(플레이어 MAX_HP)이 아니라 돼지는 30이다.**
## 🔴🔴 **음성 대조(반경 밖)가 필수다** — 없으면 「가까우면 아프다」로 짜도 통과한다.
func _monster_takes_blast_damage(t) -> void:
	var kind := Defs.KIND_PIG
	var stand_x := 600
	var y := FLOOR_TOP - Defs.h_px(kind)
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, y)
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	t.eq(m.hp, Defs.max_hp(kind), "시작 hp가 표값이다 (%d — 100이 아니다, 검사의 전제)" % Defs.max_hp(kind))

	var center_cx := floori((stand_x + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	world.enqueue(_blast_cmd(center_cx))
	for _i in 36:
		world.frame(DT, 0.0, false, false)
	t.eq(m.hp, Defs.max_hp(kind) - Character.DAMAGE_HIT,
		"폭발 반경 안이면 hp가 %d 준다" % Character.DAMAGE_HIT)

	# 음성 대조 — 아주 먼 곳에 세운 몬스터는 같은 폭발에 안 맞는다.
	var far_x := stand_x + 3000
	var g2 := _bare_grid()
	var spell2 := SpellSim.new()
	var ch2 := _still_ch(far_x, kind)
	var world2 := WorldStep.new(g2, spell2, ch2)
	var mid2 := world2.spawn_monster(kind, far_x, y)
	t.ok(mid2 > 0, "먼 자리에도 스폰됐다 (검사의 전제)")
	var m2: Monster = world2.monster_at(0)
	world2.enqueue(_blast_cmd(center_cx))
	for _i in 36:
		world2.frame(DT, 0.0, false, false)
	t.eq(m2.hp, Defs.max_hp(kind), "폭발 반경 밖이면 hp가 그대로다 (음성 대조)")


## 🔴🔴 **터널링 반증 — 닭(24px, 제일 좁은 상자)으로 잰다.** 세대 0의 첫 틱 도약을
##  `Tuning.speed_cells(0) * Tuning.CELL_PX`에서 **읽는다**(40px으로 박으면 반증이 헛돈다 —
##  판정 12와 같은 규율). 닭 hp(10) == `DAMAGE_HIT`(10)이라 **한 방에 죽으므로** 관측은
##  「hp가 준다」가 아니라 「죽는다」다. 돼지로 바꿔서 우회하지 않는다.
func _monster_hit_by_a_leaping_segment(t) -> void:
	var kind := Defs.KIND_HEN
	var stand_x := 600
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	t.eq(m.hp, Defs.max_hp(kind), "닭 시작 hp가 %d다 (DAMAGE_HIT과 같아 한 방에 죽는다)" % Defs.max_hp(kind))

	var leap_px := Tuning.speed_cells(0) * Tuning.CELL_PX
	t.ok(leap_px > Defs.w_px(kind) + HIT_LEAD_PX,
		"한 틱 도약(%dpx)이 리드(%dpx)+상자(%dpx)보다 커서 도약 배치가 실제로 선다"
			% [leap_px, HIT_LEAD_PX, Defs.w_px(kind)])

	var row_cy := floori((stand_y + Defs.h_px(kind) * 0.5) / float(Tuning.CELL_PX))
	var origin_cx := floori((stand_x - HIT_LEAD_PX) / float(Tuning.CELL_PX))
	world.enqueue(SpellSim.cmd_fire(origin_cx, row_cy, 10, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)

	# 🔴 배치가 정말 도약 배치인가 — 구간의 양 끝이 둘 다 상자 밖이어야 한다.
	t.eq(spell.seg_count(), 1, "이 틱에 구간이 하나다 (배치를 읽을 수 있다)")
	if spell.seg_count() == 1:
		var ax := Body._fp_px(spell.get_seg_x0()[0])
		var bx := Body._fp_px(spell.get_seg_x1()[0])
		var box_lo := float(stand_x)
		var box_hi := float(stand_x + Defs.w_px(kind))
		t.ok(ax < box_lo or ax > box_hi, "구간 시작(%.1f)이 상자[%d,%d] 밖이다" % [ax, stand_x, stand_x + Defs.w_px(kind)])
		t.ok(bx < box_lo or bx > box_hi,
			"구간 끝(%.1f)도 상자 밖이다 (도약 배치다 — 점 검사면 여기서 못 잡는다)" % bx)

	t.eq(world.monster_count(), 0, "닭이 한 틱 만에 죽어 목록에서 빠진다 (터널링 없이 맞았다)")
	t.eq(world.died_count(), 1, "죽음 통지가 하나 났다")
	if world.died_count() == 1:
		t.eq(world.died_kind(0), kind, "죽음 통지의 종류가 닭이다")


## 🔴 돼지로 잰다 — 닭(hp10)은 불 DPS 10/초에 1초면 죽어 「비례」가 두세 점밖에 안 나온다.
## 🔴🔴 **「무적과 무관하게」를 재는 유일한 방법 — 탄으로 먼저 맞혀 무적을 켠 채로 잰다.**
##  hp가 아니라 **불 누산기**(`_burn_acc`)로 잰다 — 무적 2틱(6프레임)과 10dps×1/60의 산수가
##  정확히 겹쳐서(0.1초 = 정확히 1점), hp 정수 차감과 무적 만료가 같은 프레임에 겹칠 수 있다.
##  누산기는 매 프레임 값으로 쌓이므로 무적이 뚜렷이 남은 시점에도 이미 잴 수 있다.
func _monster_burns_regardless_of_invuln(t) -> void:
	var kind := Defs.KIND_PIG
	var g := _bare_grid()
	var stand_x := 600
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var cx0 := floori(stand_x / float(Tuning.CELL_PX))
	var cx1 := floori((stand_x + Defs.w_px(kind) - 1) / float(Tuning.CELL_PX))
	g.apply(CellGrid.cmd_fill(cx0 - 2, FLOOR_CY, cx1 + 2, FLOOR_CY, Mat.WOOD))

	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var row_cy := floori((stand_y + Defs.h_px(kind) * 0.5) / float(Tuning.CELL_PX))
	var origin_cx := floori((stand_x - HIT_LEAD_PX) / float(Tuning.CELL_PX))
	world.enqueue(SpellSim.cmd_fire(origin_cx, row_cy, 10, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	t.ok(m.invuln_left > 0, "탄에 먼저 맞아 무적이 켜졌다 (검사의 전제)")
	t.eq(m.hp, Defs.max_hp(kind) - Character.DAMAGE_HIT, "탄에 맞아 hp가 준다 (검사의 전제)")

	var lit := 0
	for cx in range(cx0, cx1 + 1):
		if g.ignite(cx, FLOOR_CY):
			lit += 1
	t.ok(lit > 0, "발밑 나무 %d칸에 불이 붙었다 (검사의 전제)" % lit)

	world.frame(DT, 0.0, false, false)
	world.frame(DT, 0.0, false, false)
	t.ok(m.invuln_left > 0, "아직 무적이 남았다 (검사의 전제 — 무적과 무관함을 재려면 이게 참이어야 한다)")
	t.ok(m.burning, "불 위에 서 있다고 표시된다 (매 프레임 다시 잰다 — 무적을 안 본다)")
	t.ok(m._burn_acc > 0.0, "무적이 남은 채로도 불 피해 누산기가 쌓인다 (무적을 안 보는 갈래다)")

	# 🔴 시간에 비례해 깎이는지는 hp로 잰다. **짧은 창 둘**(20프레임 = 1/3초씩,
	#  합쳐서 2/3초)로 본다 — 나무 연료가 정확히 2초라 60프레임 창 둘(=2초)을 쓰면
	#  「관측 창이 끝나는 순간과 연료가 다하는 순간이 겹치는」 우연이 또 난다(실측으로 데었다).
	var before := m.hp
	for _i in 20:
		world.frame(DT, 0.0, false, false)
	var after_a := m.hp
	t.ok(after_a < before, "1/3초 뒤 불로 더 깎였다 (시간에 비례한다)")
	for _i in 20:
		world.frame(DT, 0.0, false, false)
	var after_b := m.hp
	t.ok(after_b < after_a, "다음 1/3초에도 계속 깎인다")

	# 🔴 뒤집어 보기 — 불에서 나오면(꺼지면) 깎임이 멈춘다. 자연 연료 소진 대신 나무를
	#  다시 깔아 깃발을 지운다(`net_damage._burn_acc_survives_tapping`과 같은 수법 —
	#  나무 재적용이 곧 「불에서 나왔다」다). 자연 소진을 기다리면 돼지가 먼저 죽을 수 있다.
	g.apply(CellGrid.cmd_fill(cx0 - 2, FLOOR_CY, cx1 + 2, FLOOR_CY, Mat.WOOD))
	world.frame(DT, 0.0, false, false)
	world.frame(DT, 0.0, false, false)
	t.ok(not m.burning, "불에서 나왔다 (전제)")
	var after_out := m.hp
	for _i in 30:
		world.frame(DT, 0.0, false, false)
	t.eq(m.hp, after_out, "불이 꺼진 뒤에는 더 안 깎인다")


## 세 마리를 나란히 세운다. 🔴 못 재는 것 셋(개수만/집합만/위치)을 문서가 지목해서
##  전부 같이 잰다 — 특히 **위치**는 「순회 중 제거」(인접한 산 놈이 그 틱을 건너뛴다)를
##  개수·id 집합 둘 다 못 잡는 유일한 자리다.
func _three_hens_world() -> Dictionary:
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(160, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var kind := Defs.KIND_HEN
	var gap := 200
	var base_x := 500
	var y := FLOOR_TOP - Defs.h_px(kind)
	var xs: Array[int] = [base_x, base_x + gap, base_x + gap * 2]
	var ids: Array[int] = []
	for px in xs:
		ids.append(world.spawn_monster(kind, px, y))
	return {"world": world, "ids": ids, "xs": xs}


func _dead_monsters_leave_the_list_correctly(t) -> void:
	var frames_to_run := 40
	var kind := Defs.KIND_HEN

	# 대조군 — 아무도 안 죽는 같은 배치. a·c의 「정상 한 걸음」 기준을 여기서 얻는다.
	var control: Dictionary = _three_hens_world()
	var cw: WorldStep = control["world"]
	for _i in frames_to_run:
		cw.frame(DT, 0.0, false, false)
	var expect_a_x: int = cw.monster_at(0).x
	var expect_c_x: int = cw.monster_at(2).x

	# 본검사 — 가운데(b)만 죽인다.
	var setup: Dictionary = _three_hens_world()
	var world: WorldStep = setup["world"]
	var ids: Array = setup["ids"]
	var xs: Array = setup["xs"]
	var id_a: int = ids[0]
	var id_b: int = ids[1]
	var id_c: int = ids[2]
	t.ok(id_a > 0 and id_b > 0 and id_c > 0, "셋 다 스폰됐다 (검사의 전제)")
	t.eq(world.monster_count(), 3, "① 시작 시점에 monster_count()가 3이다")

	var b_x0: int = xs[1]
	var b_cx := floori((b_x0 + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	world.enqueue(_blast_cmd(b_cx))

	# 🔴🔴 **죽음 통지는 그 틱 안에서만 유효하다**(폭발 통지와 같다 — 다음 틱이 지운다).
	#  40프레임을 다 돌고 나서 읽으면 이미 여러 틱이 더 지나 통지가 비어 있다(실측으로 데었다).
	#  ⇒ **죽는 바로 그 틱에서** 통지를 붙잡는다.
	var loops := 0
	var died_snapshot_count := -1
	var died_snapshot_kind := -1
	for _i in frames_to_run:
		world.frame(DT, 0.0, false, false)
		loops += 1
		if world.died_count() > 0 and died_snapshot_count == -1:
			died_snapshot_count = world.died_count()
			died_snapshot_kind = world.died_kind(0)
	t.ok(loops > 1, "② 프레임을 실제로 여러 바퀴 돌았다 (%d바퀴)" % loops)
	t.eq(world.monster_count(), 2, "③ b가 죽어 monster_count()가 2다")
	t.eq(died_snapshot_count, 1, "죽는 그 틱에 죽음 통지가 정확히 하나 났다")
	t.eq(died_snapshot_kind, kind, "그 통지의 종류가 닭이다")

	# id로 잰다 — 죽은 놈 하나만 빠지고 나머지 집합이 그대로인가.
	var live_ids: Array[int] = []
	for i in world.monster_count():
		live_ids.append(world.monster_at(i).id)
	live_ids.sort()
	var expect_ids: Array[int] = [id_a, id_c]
	expect_ids.sort()
	t.eq(live_ids, expect_ids,
		"죽은 id(%d) 하나만 사라지고 나머지 id 집합(%s)이 그대로다" % [id_b, expect_ids])

	# 위치로 잰다 — a·c가 대조군과 정확히 같은 자리인가(누구도 한 걸음을 안 놓쳤다).
	var a: Monster = null
	var c: Monster = null
	for i in world.monster_count():
		var mm: Monster = world.monster_at(i)
		if mm.id == id_a:
			a = mm
		elif mm.id == id_c:
			c = mm
	t.ok(a != null and c != null, "살아남은 둘을 id로 찾았다 (검사의 전제)")
	if a != null:
		t.eq(a.x, expect_a_x, "a가 대조군과 정확히 같은 자리다 (「순회 중 제거」였다면 한 걸음을 놓쳤을 것이다)")
	if c != null:
		t.eq(c.x, expect_c_x, "c가 대조군과 정확히 같은 자리다")

	# ⚠ 죽음 통지 자체는 위 루프 안에서 **그 틱에** 이미 확인했다(died_snapshot_*) —
	#  여기서 다시 읽으면 그새 지난 틱들이 지워 놔서 항상 비어 있다.


# ══════════════════════════════════════════════════════════════════
#  단계 4 — 둘이 된다
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **턱 높이를 2 또는 3셀로 세운다** — 1셀이면 둘 다 넘고 4셀이면 둘 다 막힌다.
##  3셀을 골랐다: 돼지(`step_cells`=1)는 막히고 닭(`step_cells`=3)은 넘는다.
func _pig_and_hen_cross_the_ledge_differently(t) -> void:
	var ledge_cells := 3
	var ledge_cx := 80
	var g := _bare_grid()
	g.apply(CellGrid.cmd_fill(
		ledge_cx, FLOOR_CY - ledge_cells, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	var ledge_left_px := ledge_cx * Tuning.CELL_PX

	for kind in Defs.ALL:
		var spell := SpellSim.new()
		var ch := Character.new()
		# 플레이어를 턱 훨씬 오른쪽에 둔다 — 몬스터가 왼쪽에서 턱 쪽(오른쪽)으로 걷는다.
		ch.place(ledge_left_px + 400, FLOOR_TOP - Character.H_PX)
		var world := WorldStep.new(g, spell, ch)
		var stand_x := ledge_left_px - 150
		var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
		t.ok(mid > 0, "%s 스폰됐다 (검사의 전제)" % Defs.name_of(kind))
		var m: Monster = world.monster_at(0)
		for _i in 300:
			world.frame(DT, 0.0, false, false)
		if kind == Defs.KIND_PIG:
			t.eq(m.x, ledge_left_px - Defs.w_px(kind),
				"돼지(step=%d)는 %d셀 턱에 막혀 x가 안 는다 (x=%d)"
					% [Defs.step_cells(kind), ledge_cells, m.x])
		else:
			t.ok(m.x > ledge_left_px,
				"닭(step=%d)은 %d셀 턱을 넘는다 (x=%d)" % [Defs.step_cells(kind), ledge_cells, m.x])


# ══════════════════════════════════════════════════════════════════
#  단계 5 — 돼지가 때린다
# ══════════════════════════════════════════════════════════════════

## 🔴 값 ①·② — 절대값(`WorldStep.PIG_CONTACT_DAMAGE`)과 음성 대조(안 겹치면 안 준다)를
##  같이 잰다. **「준다」만 재면 1도 100도 통과한다** — 절대값이 이 판정의 진짜 몸통이다.
func _pig_contact_damages_the_player(t) -> void:
	var kind := Defs.KIND_PIG
	var stand_x := 400
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	t.eq(ch.hp, Character.MAX_HP - WorldStep.PIG_CONTACT_DAMAGE,
		"겹치면 정확히 %d 깎인다" % WorldStep.PIG_CONTACT_DAMAGE)
	t.ok(ch.invuln_left > 0, "무적이 켜졌다 (돼지 접촉도 기존 무적을 탄다)")

	# 🔴 음성 대조 — 안 겹치게 멀찍이 세운다. `_still_ch`는 안 쓴다 — 그건 캐릭터 중심을
	#  몬스터 중심에 맞춰 "겹치게" 만드는 헬퍼라 여기선 정반대다. 딱 1틱만 재서 걷기
	#  드리프트(160px/s × 1틱 = 8px)가 500px 간격을 못 건드리게 한다.
	var far_x := stand_x + 500
	var g2 := _bare_grid()
	var spell2 := SpellSim.new()
	var ch2 := Character.new()
	ch2.place(stand_x, FLOOR_TOP - Character.H_PX)
	var world2 := WorldStep.new(g2, spell2, ch2)
	var mid2 := world2.spawn_monster(kind, far_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid2 > 0, "음성 대조도 스폰됐다 (검사의 전제)")
	for _i in Tuning.TICK_DIVIDER:
		world2.frame(DT, 0.0, false, false)
	t.eq(ch2.hp, Character.MAX_HP, "안 겹치면 안 준다 (음성 대조)")


## 🔴🔴 값 ③ — 무적을 탄다. **계속 겹쳐 둬도 매 틱 안 깎이고 5틱 간격에 한 번씩만 깎인다**
##  (`character.on_tick`이 이미 「5틱 간격 = 두 대」로 적어 둔 그 시계를 그대로 쓴다 —
##  `invuln_left`는 `_char.on_tick()` 안에서만 준다. 「4틱」으로 짜면 이 검사가 빨개진다).
func _pig_contact_respects_invulnerability(t) -> void:
	var kind := Defs.KIND_PIG
	var stand_x := 400
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")

	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	var after_first := ch.hp
	t.eq(after_first, Character.MAX_HP - WorldStep.PIG_CONTACT_DAMAGE, "첫 접촉에 깎인다 (검사의 전제)")

	# 3틱 더(누적 4틱째) — 계속 겹쳐 있어도 무적 안이라 안 더 깎인다.
	for _i in Tuning.TICK_DIVIDER * 3:
		world.frame(DT, 0.0, false, false)
	t.eq(ch.hp, after_first, "무적이 도는 동안은 계속 붙어 있어도 더 안 깎인다")

	# 1틱 더(누적 5틱째) — 무적이 풀려 다시 깎인다.
	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	t.eq(ch.hp, after_first - WorldStep.PIG_CONTACT_DAMAGE,
		"5틱째에 다시 깎인다 (계속 붙어 있어도 초당 4회가 상한이다)")


# ══════════════════════════════════════════════════════════════════
#  단계 6 — 닭이 쏜다
# ══════════════════════════════════════════════════════════════════

## 값 — **빈 공간에서 재야 한다**(막혔다와 헷갈리지 않게). 멈춘 자리와 플레이어의 거리가
##  `BOLT_STOP_PX` ± 한 걸음이어야 한다. 「거리」는 **중심 대 중심**이다(문서 판정 10).
func _hen_stops_at_bolt_range(t) -> void:
	var kind := Defs.KIND_HEN
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(2000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, 100, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	for _i in 600:
		world.frame(DT, 0.0, false, false)
	var char_center_x := float(ch.x) + Character.W_PX * 0.5
	var dist := absf(char_center_x - m.center().x)
	var step_cap := ceili(Defs.speed_px(kind) * DT)
	t.ok(absf(dist - MonsterBolts.BOLT_STOP_PX) <= step_cap,
		"멈춘 자리와 플레이어의 거리(%.1f)가 BOLT_STOP_PX(%.0f) ± 한 걸음(%d) 안이다"
			% [dist, MonsterBolts.BOLT_STOP_PX, step_cap])
	# 🔴🔴 **위 단언만으로는 안 된다** — 기대값을 `MonsterBolts.BOLT_STOP_PX`에서 그대로
	#  읽으므로, 그 상수 자체가 0으로 깨져도(닭이 돼지처럼 들러붙어도) `0 ≈ 0`이라 초록이다
	#  (실측 — CLAUDE.md 「표의 값이 마침 2라 접근자를 return 2로 박아도 2==2다」와 같은 함정).
	#  ⇒ 상수와 무관한 **고정 문턱**으로 "안 붙는다"를 따로 잰다 — 상자가 맞닿는 거리는
	#  기하로 계산하면 약 22px(`(20+24)/2`)이라 60px 문턱이면 넉넉히 가른다.
	t.ok(dist > 60.0, "닭이 플레이어에 바짝 안 붙는다 (거리 %.1f — 돼지처럼 들러붙지 않는다)" % dist)


## 🔴🔴 값 ①·②(음성 대조 셋) — 정지한 플레이어를 맞히고(무적을 탄다), **①쏜 닭 자신
##  ②경로 위 다른 닭 ③경로 위 돼지는 안 맞는다**(탄이 몬스터를 아예 모른다 — `monster_bolts.gd`).
## ⚠ 탄을 직접 만든다(`world._bolts.spawn`) — 자연 발사 주기까지 기다리면 경로 위의 다른
##  닭도 스스로 쏠 수 있어 관측이 섞인다. 자연 발사·정지는 판정 10이 따로 잰다.
func _hen_bolt_hits_only_the_player(t) -> void:
	var hen_kind := Defs.KIND_HEN
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := Character.new()
	var row_y := FLOOR_TOP - Defs.h_px(hen_kind) + Defs.h_px(hen_kind) * 0.5
	# 🔴 자리를 origin 가까이 몰아 둔다 — 돼지·다른 닭이 "경로 위"이면서도 자기 발로
	#  플레이어까지 걸어가 접촉/자연 발사로 관측을 오염시킬 시간이 없게 한다.
	var player_x := 420
	ch.place(player_x, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)

	var shooter := world.spawn_monster(hen_kind, 80, FLOOR_TOP - Defs.h_px(hen_kind))
	var other_hen := world.spawn_monster(hen_kind, 120, FLOOR_TOP - Defs.h_px(hen_kind))
	var pig := world.spawn_monster(Defs.KIND_PIG, 160, FLOOR_TOP - Defs.h_px(Defs.KIND_PIG))
	t.ok(shooter > 0 and other_hen > 0 and pig > 0, "셋 다 스폰됐다 (검사의 전제)")
	var shooter_hp0 := world.monster_at(0).hp
	var other_hen_hp0 := world.monster_at(1).hp
	var pig_hp0 := world.monster_at(2).hp
	# 🔴 다른 닭의 **자연 발사**를 막는다(이 검사는 "직접 쏜 탄"만 잰다 — 자연 발사·정지는
	#  판정 10이 따로 잰다). reload를 크게 박아 이 검사가 도는 동안 다시는 안 쏘게 한다.
	world.monster_at(1).reload_left = 999999

	var bolts: MonsterBolts = world.get("_bolts")
	t.ok(bolts.spawn(80.0, row_y, Vector2(1.0, 0.0)), "탄을 직접 쐈다 (검사의 전제)")

	for _i in 90:
		world.frame(DT, 0.0, false, false)
		if ch.hp < Character.MAX_HP:
			break

	t.eq(ch.hp, Character.MAX_HP - MonsterBolts.BOLT_DAMAGE, "플레이어는 정확히 %d 맞는다" % MonsterBolts.BOLT_DAMAGE)
	t.ok(ch.invuln_left > 0, "플레이어 무적을 탄다")
	t.eq(world.monster_at(0).hp, shooter_hp0, "① 쏜 닭 자신은 안 맞는다")
	t.eq(world.monster_at(1).hp, other_hen_hp0, "② 경로 위 다른 닭도 안 맞는다")
	t.eq(world.monster_at(2).hp, pig_hp0, "③ 경로 위 돼지도 안 맞는다")


## 🔴🔴 값 ③ — 수명 축. **셋을 같이 재야 이 축이 실제로 갈렸는지 안다**(하나만 재면
##  `BOLT_RANGE_PX`를 `BOLT_STOP_PX`로 되돌려도 초록이다). 정지하면 맞고, 다가오면 더
##  빨리 맞고, **260px/s로 물러나면 원리적으로 안 맞는다**(의도된 결과다 — 「고장」으로 읽고
##  값을 올리지 마라. `monster_bolts.gd` 상자의 산수).
func _hen_bolt_lifetime_axis(t) -> void:
	var hit := {}
	for the_case: String in ["stand", "approach", "retreat"]:
		var g := _bare_grid()
		var spell := SpellSim.new()
		var ch := Character.new()
		var start_x := 400
		ch.place(start_x, FLOOR_TOP - Character.H_PX)
		var world := WorldStep.new(g, spell, ch)
		var row_y := float(ch.y) + Character.H_PX * 0.5
		var bolts: MonsterBolts = world.get("_bolts")
		bolts.spawn(100.0, row_y, Vector2(1.0, 0.0))
		var axis := 0.0
		if the_case == "approach":
			axis = -1.0  # 탄 쪽(왼쪽)으로 다가온다
		elif the_case == "retreat":
			axis = 1.0   # 탄에서 먼 쪽(오른쪽)으로 물러난다
		var got_hit := false
		for _i in 200:
			world.frame(DT, axis, false, false)
			if ch.hp < Character.MAX_HP:
				got_hit = true
				break
		hit[the_case] = got_hit
	t.ok(hit["stand"], "멈춰 있으면 맞는다 (양성 대조 — 없으면 수명 0인 탄도 통과한다)")
	t.ok(hit["approach"], "다가오면 더 빨리 맞는다 (상대 속도가 %.0fpx/s)"
		% (MonsterBolts.BOLT_SPEED_PX + Character.MOVE_SPEED_PX))
	t.ok(not hit["retreat"],
		"%.0fpx/s로 물러나면 안 맞는다 (의도된 결과다 — 「고장」으로 읽고 값을 올리지 마라)"
			% Character.MOVE_SPEED_PX)


## 값 ①·② — 벽 뒤 플레이어는 안 맞고 탄이 사라진다. **격자가 한 칸도 안 바뀐다**
##  (`consume_changed()`로 잰다 — 「구멍이 없다」를 눈으로 보는 것보다 좁다. 이게 없으면
##  탄이 `carve_r`을 부르는 구현(마법 탄에서 복사해 오기 쉬운 자리)이 통과한다).
func _hen_bolt_blocked_by_terrain_and_does_not_carve(t) -> void:
	var wall_cx := 60
	var g := _bare_grid()
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 8, wall_cx + 3, FLOOR_CY - 1, Mat.STONE))
	g.consume_changed()  # 기준선을 0으로 맞춘다
	var spell := SpellSim.new()
	var ch := Character.new()
	var wall_right_px := (wall_cx + 4) * Tuning.CELL_PX
	# 🔴 플레이어가 **탄의 사거리(`BOLT_RANGE_PX`) 안**에 있어야 한다 — 벽이 없으면
	#  실제로 맞을 자리여야 "막혔다"와 "그냥 사거리가 다했다"가 안 섞인다.
	ch.place(wall_right_px + 90, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var row_y := float(ch.y) + Character.H_PX * 0.5
	var bolt_origin_x := wall_right_px - 200
	t.ok(float(wall_right_px + 90 - bolt_origin_x) < MonsterBolts.BOLT_RANGE_PX,
		"플레이어가 사거리 안이다 (벽이 없으면 맞았을 배치다 — 검사의 전제)")
	var bolts: MonsterBolts = world.get("_bolts")
	bolts.spawn(float(bolt_origin_x), row_y, Vector2(1.0, 0.0))

	for _i in 90:
		world.frame(DT, 0.0, false, false)

	t.eq(ch.hp, Character.MAX_HP, "벽 뒤 플레이어는 안 맞는다")
	t.eq(world.bolt_count(), 0, "탄이 벽에서 사라졌다")
	t.eq(g.consume_changed(), 0, "탄이 지나도 격자가 한 칸도 안 바뀐다 (지형을 안 판다)")


## 값 ③ — 터널링 부등식을 숫자로 잰다. **상대 속도로 재야 진짜 한계다** — 탄 속도만 쓰면
##  이 검사가 거짓말한다(마법 탄이 정확히 그래서 선분 대 상자가 됐다는 것과 같은 이유).
##  🔴 상수를 읽어서 계산한다 — 숫자를 박으면 탄 속도를 올리는 날 이 검사가 무의미해진다.
func _hen_bolt_step_stays_inside_the_player_box(t) -> void:
	var relative_step := (MonsterBolts.BOLT_SPEED_PX + Character.MOVE_SPEED_PX) * DT
	t.ok(relative_step < Character.W_PX,
		"(탄 속도 + 플레이어 최대 속도) × 1/60 (%.1fpx)이 상자 짧은 변(%dpx)보다 작다 — 프레임 검사로 충분하다"
			% [relative_step, Character.W_PX])


# ══════════════════════════════════════════════════════════════════
#  단계 7 — 화면 넷 + 시체
# ══════════════════════════════════════════════════════════════════
#
# 🔴 체력바·번쩍·피해 숫자·시체 잔상 넷을 여기서 잰다. 🔴🔴 **"뜬다·색이 맞다"는 눈이다**
#  (판정 13, 헤드리스로 원리적으로 못 잰다) — 여기는 **값이 표·실제 hp에서 나오는지**만 잰다.
#  ⚠ 닭의 탄이 실제로 그려지는 자리(`_draw()`의 `world.bolt_x/y`)는 이미 판정 10~12가
#  `WorldStep` 쪽에서 잰 값을 그대로 읽는 것뿐이라 여기서 다시 안 잰다 — `box_rect()`가
#  `_draw()`의 유일한 크기 소스인 것과 달리 그 규율은 코드로만 지킨다(아무도 안 잰다, 위 상자).
# ⚠ 번쩍·피해 숫자·시체의 **감쇠 곡선**(알파가 몇 %씩 주나)은 안 잰다 — `blast_fx`의 섬광
#  곡선(`_ease`·`flash_alpha`)도 이 리포에서 net으로 안 잰다. 여기서 재는 것은 **"떴다·표값과
#  같다·수명대로 사라진다"**까지다.


# ── 체력바 — 값이 표에서 나온다 ─────────────────────────────────
func _hp_bar_values_come_from_the_table(t) -> void:
	for kind: int in Defs.ALL:
		var x := 40
		var y := 60
		var r := MonsterView.hp_bar_rect(kind, x, y)
		t.eq(r.size.x, float(Defs.w_px(kind)),
			"%s 체력바 폭이 상자 폭(%d)과 같다" % [Defs.name_of(kind), Defs.w_px(kind)])
		t.eq(r.position.y, float(y) - Fx.MONSTER_HP_BAR_GAP_PX - Fx.MONSTER_HP_BAR_H_PX,
			"%s 체력바가 상자 위 %.0fpx에 뜬다" % [
				Defs.name_of(kind), Fx.MONSTER_HP_BAR_GAP_PX + Fx.MONSTER_HP_BAR_H_PX])
	t.eq(MonsterView.hp_bar_fill_frac(30, 30), 1.0, "가득 차면 비율 1.0")
	t.eq(MonsterView.hp_bar_fill_frac(0, 30), 0.0, "0이면 비율 0.0")
	t.eq(MonsterView.hp_bar_fill_frac(15, 30), 0.5, "절반이면 비율 0.5")
	t.eq(MonsterView.hp_bar_fill_frac(-5, 30), 0.0, "음수 hp도 0 밑으로 안 내려간다 (죈다)")
	t.eq(MonsterView.hp_bar_fill_frac(999, 30), 1.0, "표보다 큰 hp도 1 위로 안 올라간다 (죈다)")


# ── 닭의 탄 색 — 마법 탄과 갈린다 ───────────────────────────────
## 🔴 절대값이 아니라 **거리**로 잰다 — 정확한 RGB를 박으면 손맛으로 살짝 조이는 날
##  이 검사가 이유 없이 빨개진다. 잰다는 「충분히 멀다」다.
func _monster_bolt_color_differs_from_magic_bolts(t) -> void:
	for elem: int in [Tuning.ELEM_FIRE, Tuning.ELEM_NONE, Tuning.ELEM_WATER]:
		var glow: Color = Fx.ELEM_FX[elem]["glow"]
		t.ok(_rgb_dist(Fx.MONSTER_BOLT_COLOR, glow) > 0.3,
			"닭 탄 색이 마법 탄(원소 %d) 색과 충분히 갈린다" % elem)


## 🔴 `Color`에 `distance_to()`가 없다(Godot 4 GDScript 실측) — RGB 유클리드 거리를 직접 잰다.
func _rgb_dist(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))


# ── 번쩍 · 피해 숫자 — hp가 준 만큼만, 수명대로 사라진다 ──────────
## 🔴🔴 **하드코딩 반증** — 피해 숫자를 상수로 박아도 이 값 자체는 통과할 수 있지만
##  (지금 우연히 `Character.DAMAGE_HIT`와 같다), **실제 hp 변화량을 읽는지**는 절대값 하나로는
##  못 가른다. ⇒ 여기서는 "hp가 준 양과 같다"를 표에서 유도한 상수(`Character.DAMAGE_HIT`)로
##  재서 최소한 우연이 아님을 보인다 — 두 번째 다른 피해량(불)까지 재는 것은 이 검사 밖이다.
func _hit_triggers_flash_and_a_damage_number_that_ages_out(t) -> void:
	var kind := Defs.KIND_PIG
	var stand_x := 600
	var y := FLOOR_TOP - Defs.h_px(kind)
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, y)
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var view := MonsterView.new()
	view.setup(world)
	view.advance()  # 맞기 전 hp(표값)를 기준으로 스냅샷한다
	t.ok(not view.is_flashing(m.id), "맞기 전엔 번쩍이지 않는다 (전제)")
	t.eq(view.dmg_number_count(), 0, "맞기 전엔 피해 숫자가 없다 (전제)")

	var center_cx := floori((stand_x + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	world.enqueue(_blast_cmd(center_cx))
	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	t.eq(m.hp, Defs.max_hp(kind) - Character.DAMAGE_HIT, "폭발에 맞아 hp가 준다 (검사의 전제)")

	view.advance()
	t.ok(view.is_flashing(m.id), "hp가 줄면 그 프레임에 번쩍인다")
	t.eq(view.dmg_number_count(), 1, "피해 숫자가 하나 뜬다")
	t.eq(view.dmg_number_amount(0), Character.DAMAGE_HIT,
		"피해 숫자가 실제로 줄어든 양(%d)과 같다 — 하드코딩이면 표를 바꿔도 안 따라온다"
			% Character.DAMAGE_HIT)

	# 🔴 번쩍과 피해 숫자가 **같은 `advance()` 시계를 공유한다** — 번쩍을 다 태우는 동안에도
	#  피해 숫자는 계속 나이를 먹는다. ⇒ 이미 지난 프레임 수를 세어 두고, 피해 숫자 수명이
	#  끝나기 **직전**까지 나머지를 채운다(상수 값에 안 얽매이게).
	var elapsed := 0  # 생성 호출 자체는 나이를 안 먹인다(위 `advance()`의 순서 — prune이 먼저다)
	for _i in Fx.MONSTER_FLASH_FRAMES - 1:
		view.advance()
		elapsed += 1
	t.ok(view.is_flashing(m.id), "번쩍 프레임이 아직 안 다했다 (전제)")
	view.advance()
	elapsed += 1
	t.ok(not view.is_flashing(m.id), "%d프레임 뒤 번쩍이 꺼진다" % Fx.MONSTER_FLASH_FRAMES)

	while elapsed < Fx.MONSTER_DMG_NUM_LIFE_FRAMES - 1:
		view.advance()
		elapsed += 1
	t.eq(view.dmg_number_count(), 1, "피해 숫자 수명이 아직 안 다했다 (전제)")
	view.advance()
	t.eq(view.dmg_number_count(), 0, "%d프레임 뒤 피해 숫자가 사라진다" % Fx.MONSTER_DMG_NUM_LIFE_FRAMES)
	# 🔴 `MonsterView`는 `Node2D`라 `RefCounted`가 아니다 — 안 지우면 CanvasItem RID가
	#  새서 래퍼가 stderr를 빨갛게 본다(CLAUDE.md 「가짜 그물 금지」의 마지막 상자와 같은 자리 —
	#  실측: `.free()`를 빠뜨리자 이 그물이 "RID 2개 누수"로 실패했다).
	view.free()


# ── 시체 — 죽음 통지를 그 틱에 붙잡아 시체가 되고, 수명대로 사라진다 ─
## 🔴🔴 **`world_step`이 낸 죽음 통지의 첫 소비자다**(team-lead 메모). `on_tick()`이 통지를
##  실제로 읽는지, 그 틱을 놓치면 시체가 원리적으로 안 생기는지를 같이 잰다.
func _death_notification_spawns_a_corpse_that_ages_out(t) -> void:
	var kind := Defs.KIND_HEN
	var stand_x := 600
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")

	var view := MonsterView.new()
	view.setup(world)
	t.eq(view.corpse_count(), 0, "스폰만으로는 시체가 없다 (전제)")

	var center_cx := floori((stand_x + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	world.enqueue(_blast_cmd(center_cx))
	var got_death := false
	for _i in Tuning.TICK_DIVIDER * 3:
		var ticked := world.frame(DT, 0.0, false, false)
		if ticked and world.died_count() > 0:
			# 🔴 죽은 그 틱 안에서 붙잡는다 — 다음 `frame()`의 틱 갈래가 통지를 지운다
			#  (`world_step.gd` 헤더). 놓치면 이 검사 자체가 「원리적으로 안 생긴다」쪽을 증명한다.
			view.on_tick()
			got_death = true
			break
	t.ok(got_death, "닭이 죽어 죽음 통지가 났다 (검사의 전제)")
	t.eq(world.monster_count(), 0, "몬스터 목록에서 빠졌다 (검사의 전제)")
	t.eq(view.corpse_count(), 1, "죽음 통지를 시체 하나로 옮겼다")
	t.eq(view.corpse_kind(0), kind, "시체 종류가 죽은 몬스터와 같다 (닭)")

	for _i in Fx.MONSTER_CORPSE_LIFE_FRAMES - 1:
		view.advance()
	t.eq(view.corpse_count(), 1, "시체 수명이 아직 안 다했다 (전제)")
	view.advance()
	t.eq(view.corpse_count(), 0, "%d프레임 뒤 시체가 사라진다" % Fx.MONSTER_CORPSE_LIFE_FRAMES)
	view.free()  # `Node2D`라 RefCounted가 아니다 — 위 검사와 같은 이유로 직접 지운다.
