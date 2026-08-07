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
const Body := preload("res://src/actor/body.gd")
const Monster := preload("res://src/actor/monster.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const MonsterView := preload("res://src/view/monster_view.gd")

const DT := 1.0 / 60.0
const FLOOR_CY := 100
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX
const LEDGE_CX := 30
const STAGE_SCRIPT := "res://src/stage/stage.gd"

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
	_ids_are_distinct_and_not_reused(t)
	_view_box_comes_from_the_table(t)
	_shell_hands_the_world_to_the_view(t)


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

	var hen := Monster.new(1, Defs.KIND_HEN, hole_left, FLOOR_TOP - 200)
	for _i in 600:
		hen.step(g, DT, 0, 0)
	t.ok(hen.y > FLOOR_TOP, "닭(24px < 32px 틈)이 굴뚝을 통과해 바닥 아래로 더 떨어진다 (y=%d)" % hen.y)

	var pig := Monster.new(2, Defs.KIND_PIG, hole_left, FLOOR_TOP - 200)
	for _i in 600:
		pig.step(g, DT, 0, 0)
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
