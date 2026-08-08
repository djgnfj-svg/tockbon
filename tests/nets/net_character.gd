extends RefCounted
## 캐릭터가 자기가 부순 지형 위를 걸어 다니나 (기획 판정 4).
##
## 🔴 이 그물이 도는 것 자체가 `src/actor/character.gd` 가 RefCounted 인 덕이다.
## Node 였으면 씬을 세워야 하고, 그럼 이 판정이 "눈으로만" 재는 것이 된다.
##
## ⚠ 캐릭터는 1px 단위로 미는데 프레임당 이동이 4.33px라 **마지막 조각이 소수**다.
## 그래서 "정확히 얼마"가 아니라 "1px 이내"로 잰다. 세로는 다르다 —
## 착지는 1px씩 내려가다 막히는 것이라 **정확히** 지표면이어야 한다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")
## 🔴 C-시리즈(물살)가 힘 함수(`water_flow`)를 캐릭터 없이 직접 잰다 — `standing_in_fire`처럼
##  `Body`는 자기 상수를 안 들어서 `Body.new(w, h, step)`으로 세워야 한다(이 파일 헤더 참조 없음,
##  `body.gd` 헤더가 그 이유를 든다).
const Body := preload("res://src/actor/body.gd")

const DT := 1.0 / 60.0
const FLOOR_CY := 100      # 바닥 윗면 셀
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX     # 400px
const REST_Y := FLOOR_TOP - Character.H_PX       # 368px — 바닥에 선 캐릭터의 y

## 🔴🔴 **바닥은 얇게 깐다 — CLAUDE.md 「그물이 느리면 그건 성능 문제가 아니라 하네스가
##  버려지는 경로다」.** 실측: `CellGrid.H - 1`까지 까는 옛 바닥이 4096×908=3,719,168칸이라
##  한 번에 2,719ms였다(이 파일이 그물 전체에서 46초 — 검사 수가 아니라 바닥을 몇 번 까느냐로
##  시간이 정해졌다). ⚠ **안전한 이유**: `cell_grid.mat_at()`이 격자 밖을 `STONE`으로
##  돌려주므로 바닥이 두꺼울 이유가 원래 없었다 — 캐릭터는 표면 몇 px 안에서만 논다.
## 🔴 32셀(128px)로 잡았다 — 폭발이 지형을 파는 검사가 없는 파일이라 `carve_r`(8셀) 여유를
##  안 볼 필요는 없지만, 이 값을 같은 파일에 실려 있을 미래의 판 검사와 값을 맞춰 둔다.
const FLOOR_DEPTH_CY := 32

## 🔴🔴 **사람이 낼 수 있는 최단 키 누름(프레임). 가변 점프를 이걸로 잰다.**
##  손가락이 키를 눌렀다 떼는 데 **0.05초쯤** 걸린다 — 1~2프레임(0.017~0.033초)은
##  **사람이 못 내는 입력**이고, 그걸로 재면 게임에서 안 되는 것도 통과한다(실제로 났다).
const HUMAN_TAP_FRAMES := 3


func run(t) -> void:
	# 🔴 **32px 전환에서 안 올렸다.** 턱을 만드는 것은 폭발이고 폭발은 **셀** 단위인데
	# 셀이 안 변했다 — "1셀이면 조금만 파여도 걸린다"가 여전히 그대로다(`character.gd`).
	# ⚠ 반대쪽 근거("타일 하나를 통째로 올라가면 위력 감각이 뭉개진다")는 타일이 8셀이 되며
	# **느슨해졌다**. 두 근거의 방향이 다르고, 좁은 쪽이 이긴다.
	t.eq(Character.STEP_CELLS, 2, "스텝 오프셋이 2셀이다")
	# 🔴🔴 **폭은 더 이상 타일과 같지 않다 — 2026-08-04에 충돌 상자만 20으로 좁혔다**
	#  (사용자 판정: 「벽에 닿기 전에 닿았다는 판정」). GDD 「캐릭터 두께 = 타일」은 **눈에 보이는**
	#  크기의 계약이고 그건 그림 칸(`Fx.CHAR_CELL_PX` 32)이 지킨다 — `net_sprite` 가 그쪽을 잰다.
	#  ⚠ **여기서 32를 다시 단언하지 마라.** 그러면 그림과 상자를 가른 것이 통째로 되돌아간다.
	t.eq(Character.W_PX, 20, "캐릭터 충돌 폭이 20px이다 (그림 칸 32px보다 좁다)")
	t.ok(Character.W_PX < Character.H_PX,
		"충돌 상자가 세로로 길다 (%dx%d — 세로는 안 건드렸다)" % [Character.W_PX, Character.H_PX])
	# 🔴🔴 **`H_PX` 는 아무도 안 재고 있었다.** 아래 검사들이 `FLOOR_TOP - H_PX` 로 기대값을 만드는데
	#  실제값도 같은 상수를 지나서 **양쪽이 같이 틀리면 상쇄된다** — 상자가 32×16이 돼도 전부 초록이다.
	#  ⚠ 그리고 그건 「머리가 벽에 박히는데 지나간다」로만 보인다(GDD 격자).
	t.eq(Character.H_PX, 32, "캐릭터 높이가 32px = 지형 타일과 같다")

	_fall_and_land(t)
	_jump_height(t)
	_short_press_jumps_lower(t)
	_ledge(t, 2, true)
	_ledge(t, 3, false)
	_broken_ground(t)
	_wall(t)
	_airborne_never_climbs(t)
	# ── A. 물속 무한 점프 (water-jump-and-escape.md 단계 1) ──
	_submerged_jump_fires_repeatedly(t)
	_submerged_jump_boundary(t)
	_leaving_water_blocks_the_very_next_frame(t)
	_submerged_jump_includes_the_foot_row(t)
	# ── C. 물살이 캐릭터를 민다 (water-jump-and-escape.md 단계 4) ──
	_water_push_zero_when_symmetric(t)
	_water_push_sign_both_ways(t)
	_water_push_scales_with_diff(t)
	_water_push_zero_at_equilibrium(t)
	_water_push_pair_moves_and_stops(t)
	_water_push_does_not_move_water(t)
	_water_push_ignores_fire(t)
	_water_push_stops_the_frame_water_leaves(t)


func _floor_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g


## ⚠ 걷기라 점프 인자는 둘 다 거짓이다 — **누르지도 않았고 누르고 있지도 않다.**
func _walk(g: CellGrid, ch: Character, frames: int, axis: float) -> void:
	for _i in frames:
		ch.step(g, DT, axis, false, false)


## 떨어지고 착지한다. 착지 위치가 1px이라도 어긋나면 캐릭터가 지형에 박히거나 떠 있다.
func _fall_and_land(t) -> void:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, 200)
	_walk(g, ch, 120, 0.0)
	t.ok(ch.on_ground, "떨어진 뒤 착지한다")
	t.eq(ch.y, REST_Y, "착지 높이가 지표면에 정확히 붙는다")


## 🔴🔴 **점프 도달 높이 — 계획 위험 1을 닫는 자리다.**
##  `GRAVITY_PX` 와 `JUMP_VY_PX` 중 **하나만** ×2 하면 도달 높이가 4배나 절반이 되는데
##  **에러가 하나도 안 난다.** 실측(2026-08-04): `JUMP_VY` 만 안 올린 상태로 그물 **1288개가
##  전부 초록**이었다. ⇒ 아래 둘이 그걸 무는 유일한 자동 감지기다.
##
## 🔴 **거동과 상수를 따로 잰다. 두 값이 다르니 한 줄로 섞지 마라:**
##  · 거동 **102px** — 실제로 뛰어서 잰 값. 🔴 1px씩 미는 이동이라 **정수 절삭이 깎는다.**
##    ⚠ 여기 해석식 108을 쓰면 **영원히 빨갛다.** 절삭은 버그가 아니라 이 이동 방식의 성질이다
##  · 상수 **3.375타일** — 해석식 `v²/2g` = 108px ÷ 타일 32px. **타일로 읽어야** 배율이 또
##    바뀌는 날 이 줄이 같이 늙지 않는다
const JUMP_PEAK_PX := 102
const JUMP_PEAK_TILES := 3.375

const LEDGE_CX := 30
const LEDGE_PX := LEDGE_CX * Tuning.CELL_PX      # 120px — 턱의 왼쪽 면


## 실제로 뛰어서 도달 높이를 잰다. 🔴 **점프 입력(`jump`)은 한 프레임뿐**이다 —
##  계속 넣으면 착지할 때마다 다시 뛰어서 「한 번 뛴 높이」가 아니게 된다.
##  ⚠ **`jump_held` 는 계속 참이다.** 가변 점프가 들어온 뒤로 이 둘이 다른 축이고,
##   여기서 재는 「도달 높이 102px」는 **끝까지 누른 점프**의 값이다.
func _jump_height(t) -> void:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, REST_Y)
	_walk(g, ch, 5, 0.0)
	t.ok(ch.on_ground, "뛰기 전에 접지 상태다 (검사의 전제)")
	var y0 := ch.y

	ch.step(g, DT, 0.0, true, true)
	var top := ch.y
	for _i in 120:
		ch.step(g, DT, 0.0, false, true)
		top = mini(top, ch.y)

	t.eq(y0 - top, JUMP_PEAK_PX, "끝까지 누른 점프의 도달 높이가 %dpx다" % JUMP_PEAK_PX)
	# 🔴 **되돌아오는 것까지 본다.** 안 보면 「떠오른 채로 안 내려오는」 구현도 통과한다.
	t.ok(ch.on_ground and ch.y == y0, "떨어져서 원래 높이로 돌아온다 (y=%d · 시작 %d)" % [ch.y, y0])

	# 🔴 **상수 쪽 — 해석식이 타일로 몇인가.** 거동만 재면 두 상수를 **같은 비율로** 틀리게
	#  고쳤을 때(둘 다 ×3 따위) 도달 높이가 그대로라 안 걸린다. 이 줄이 그 갈래를 문다.
	var peak := Character.JUMP_VY_PX * Character.JUMP_VY_PX / (2.0 * Character.GRAVITY_PX)
	var tile := float(Tuning.TILE_CELLS * Tuning.CELL_PX)
	t.eq(snappedf(peak / tile, 0.001), JUMP_PEAK_TILES,
		"해석식 도달 높이가 %s타일이다 (v²/2g = %.0fpx ÷ 타일 %.0fpx)" % [
			JUMP_PEAK_TILES, peak, tile])


## 🔴🔴 **가변 점프 — 누른 시간이 높이를 정한다**(2026-08-04, 사용자 요청).
##
## 🔴 **「짧게 누르면 낮다」만 재면 안 된다** — 점프가 통째로 죽어도(`vy = JUMP_VY_PX` 를 지워도)
##  「낮다」는 참이다. ⇒ 세 가지를 **같이** 잰다:
##   ① 짧게 눌러도 **실제로 뜬다**(0이 아니다)   ② 끝까지 누른 것보다 **낮다**
##   ③ 중간까지 누르면 **그 사이에 있다** — 이게 「시간에 따라 조절된다」이고,
##      ①②만으로는 **두 단계짜리 스위치**(눌렀나/뗐나)와 구별이 안 된다
##
## ⚠ 높이 비교라 **정확한 px를 안 박는다.** 컷 비율을 손대면 값이 다 바뀌는데 그때마다
##  기대값을 고치게 하면 「그물이 상수를 베낀다」가 되고, 그건 아무것도 안 재는 것이다.
func _short_press_jumps_lower(t) -> void:
	# 🔴🔴 **`HUMAN_TAP_FRAMES` 로 잰다. 1프레임으로 재지 마라 — 그래서 한 번 놓쳤다.**
	#  처음엔 1프레임(0.017초) 누름을 「짧게」로 썼고 **그물은 초록인데 게임에서는 안 됐다**
	#  (사용자: 「안 된 듯」). 컷 비율 0.55에서 1프레임은 46%라 잘 갈렸지만, **사람이 낼 수 있는
	#  최단 탭(0.05초)은 67%**였다 — 손으로는 거의 항상 최대가 나왔다.
	#  🔴 **사람이 못 내는 입력으로 재면 「된다」가 나오고 게임에서는 안 된다.**
	#
	# ⚠ 컷이 물리는 구간은 `18 × (1 − 비율)` 프레임이다. 「중간」이 그 밖이면 `full` 과 같은 값이
	#  나와 **검사가 경계에 앉아 조용히 아무것도 안 잰다** — 8을 골랐다가 실제로 그랬다(102 vs 102).
	var full := _jump_peak(999)                  # 끝까지 누른다
	var half := _jump_peak(HUMAN_TAP_FRAMES * 2) # 그 두 배로 누른다
	var tap := _jump_peak(HUMAN_TAP_FRAMES)      # 사람이 낼 수 있는 최단 탭

	t.ok(tap > 0, "사람이 낼 수 있는 최단 탭으로도 뜬다 (%dpx — 점프가 죽은 게 아니다)" % tap)
	t.ok(tap < full, "짧게 누르면 끝까지 누른 것보다 낮다 (%d < %d)" % [tap, full])
	# 🔴 **여기가 「스위치가 아니라 조절」을 가르는 줄이다.**
	t.ok(tap < half and half < full,
		"중간까지 누르면 그 사이 높이다 (%d < %d < %d — 누른 시간에 비례한다)" % [tap, half, full])
	# 🔴🔴 **「갈리긴 한다」로는 부족하다 — 손에 잡히려면 확실히 갈려야 한다.**
	#  이 줄이 이번 실패(컷 0.55)를 무는 자리다: 그때 최단 탭이 **67%**였고 지금은 37%다.
	#  ⚠ 절반이라는 문턱 자체는 손맛값이다. 다만 **없으면 「조금이라도 낮으면 통과」**가 되고,
	#   그건 화면에서 아무도 못 느끼는 차이까지 초록으로 만든다.
	t.ok(tap * 2 < full,
		"최단 탭이 최대의 절반 아래다 (%d / %d = %d%% — 손으로 조절이 느껴진다)" % [
			tap, full, int(100.0 * float(tap) / float(full))])
	# ⚠ 상수 쪽도 같이 본다. 거동만 재면 컷을 1.0으로 두고 `JUMP_VY_PX` 를 줄여도
	#  「낮다」가 성립해서, 「가변 점프가 있다」와 「점프가 그냥 약하다」가 구별이 안 된다.
	t.ok(Character.JUMP_CUT_RATIO > 0.0 and Character.JUMP_CUT_RATIO < 1.0,
		"컷 비율이 0과 1 사이다 (%.2f — 1이면 안 잘리고 0이면 즉시 멈춘다)" % Character.JUMP_CUT_RATIO)


## 점프해서 도달한 높이(px). `hold_frames` 만큼 키를 누르고 있다가 뗀다.
## ⚠ `jump`(눌린 순간)는 첫 프레임뿐이고 `jump_held` 만 이어진다 — 게임과 같은 모양이다.
func _jump_peak(hold_frames: int) -> int:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, REST_Y)
	_walk(g, ch, 5, 0.0)
	var y0 := ch.y
	var top := y0
	for i in 120:
		ch.step(g, DT, 0.0, i == 0, i < hold_frames)
		top = mini(top, ch.y)
	return y0 - top


func _ledge_grid(cells: int) -> CellGrid:
	var g := _floor_grid()
	# 🔴 위 `FLOOR_DEPTH_CY` 상자와 같은 이유로 얇게 깐다 — 턱 위도 표면 몇 px만 있으면 된다.
	g.apply(CellGrid.cmd_fill(
		LEDGE_CX, FLOOR_CY - cells, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g


## 턱 `cells`셀. 2셀은 걸어서 올라서고 3셀은 못 올라선다.
func _ledge(t, cells: int, expect_climb: bool) -> void:
	var ledge_cx := LEDGE_CX
	var ledge_top_cy := FLOOR_CY - cells
	var g := _ledge_grid(cells)

	var ch := Character.new()
	ch.place(40, REST_Y)
	_walk(g, ch, 120, 1.0)

	var ledge_px := ledge_cx * Tuning.CELL_PX
	var top_y := ledge_top_cy * Tuning.CELL_PX - Character.H_PX
	if expect_climb:
		t.ok(ch.x > ledge_px, "%d셀 턱을 걸어서 올라선다 (x=%d)" % [cells, ch.x])
		t.eq(ch.y, top_y, "%d셀 턱 위에 선다" % cells)
	else:
		# 벽에 붙어 멈춘다. 상자 오른쪽 끝이 턱 왼쪽 면이라 x가 **정확히** ledge_px - 32이다.
		t.eq(ch.x, ledge_px - Character.W_PX, "%d셀 턱에 딱 붙어 막힌다" % cells)
		t.eq(ch.y, REST_Y, "%d셀 턱을 못 올라간다" % cells)


## 🔴🔴 **이게 판정 4의 본체다.** 폭발이 지나간 자리는 매끈한 바닥이 아니라
## 1셀짜리 턱이 널린 면이고, 이 게임에서는 그게 예외가 아니라 기본 상태다.
func _broken_ground(t) -> void:
	var g := _floor_grid()
	var last_top := FLOOR_CY
	for k in range(1, 7):
		var sx := 30 + (k - 1) * 4
		# 마지막 단은 오른쪽 끝까지 — 안 그러면 캐릭터가 계단을 다 오르고 도로 떨어져서
		# 그물이 "못 올라갔다"와 "올라갔다가 내려왔다"를 못 가른다.
		var ex := 33 + (k - 1) * 4 if k < 6 else CellGrid.W - 1
		last_top = FLOOR_CY - k
		# 🔴 마지막 단(k=6)이 가로 전체(4096칸)로 넓어지는 자리라 얇게 안 깔면 이게 또
		#  3.7M칸이 된다 — `FLOOR_DEPTH_CY` 상자와 같은 이유.
		g.apply(CellGrid.cmd_fill(sx, last_top, ex, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))

	var ch := Character.new()
	ch.place(40, REST_Y)
	_walk(g, ch, 180, 1.0)
	t.eq(ch.y, last_top * Tuning.CELL_PX - Character.H_PX, "1셀 턱 여섯 개를 걸어서 넘는다")
	t.ok(ch.on_ground, "계단을 다 오르고 접지 상태다")


## 3셀보다 높은 벽은 못 넘는다 — 스텝 오프셋이 만능이 되면 지형이 의미를 잃는다.
func _wall(t) -> void:
	var g := _floor_grid()
	var wall_cx := 30
	var wall_x := wall_cx * Tuning.CELL_PX - Character.W_PX
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 8, wall_cx + 3, FLOOR_CY - 1, Mat.STONE))
	var ch := Character.new()
	ch.place(40, REST_Y)
	_walk(g, ch, 120, 1.0)
	t.eq(ch.x, wall_x, "8셀 벽에 막힌다")


## 🔴🔴 **공중에서는 스텝 오프셋이 안 걸린다.** 걸리면 벽에 붙어 있는 동안 턱이 아니라
## **벽을 타고 오른다** — 점프 높이가 지형 설계의 축인데 그게 통째로 무의미해진다.
##
## ⚠ **멀리서 걸어와서는 이걸 못 잰다.** 344px에서 떨어지면 벽에 닿기 전에 반드시 착지하고
##  (낙하 40px ≈ 15프레임 = 전진 26px), 그러면 `on_ground` 가드를 지워도 초록이다.
##  실측: 20프레임에 x=83까지밖에 못 가는데 벽이 x=104였다 — **닿지도 못했다.**
##  ⚠ **이 실측은 16px 세상의 값이다**(32px 전환 전). 결론(멀리서 걸어오면 못 잰다)은 그대로지만
##   숫자는 안 맞는다 — **다시 재지 않았다.** 아래 시작 자리는 상수에서 파생되므로 저절로 따라온다.
##  ⇒ **처음부터 턱 왼쪽 면에 붙여 놓고 공중에서 시작한다.**
##
## 🔴 턱은 2셀이다 — `_ledge(2, true)`가 **같은 지형에서 걸어서는 올라선다**를 이미 쟀다.
##  그래서 여기서 못 오르는 것은 지형 탓이 아니라 **가드 하나 때문**이라는 게 확정된다.
func _airborne_never_climbs(t) -> void:
	var g := _ledge_grid(2)
	var ledge_top_y := (FLOOR_CY - 2) * Tuning.CELL_PX - Character.H_PX  # 360
	var ch := Character.new()
	# 턱 위(360)와 바닥 위(368) 사이. 발이 턱 옆구리에 걸리는 높이이면서 아직 공중이다.
	var start_y := ledge_top_y + 4
	var start_x := LEDGE_PX - Character.W_PX
	ch.place(start_x, start_y)

	# 이 두 줄이 전제다. 깨지면 아래 검사가 「공중」을 안 재는 것이라 무의미해진다.
	ch.step(g, DT, 0.0, false, false)
	t.ok(not ch.on_ground, "시작이 공중이다 (y=%d · 바닥 %d)" % [ch.y, REST_Y])
	t.eq(ch.x, start_x, "턱 왼쪽 면에 붙어 있다")

	# 🔴 **한 프레임이면 갈린다.** 가드가 없으면 이 프레임에 4px 들려서 x가 앞으로 나간다.
	ch.step(g, DT, 1.0, false, false)
	t.eq(ch.x, start_x, "공중에서 턱을 밀어도 앞으로 안 나간다")
	t.ok(ch.y >= start_y, "공중에서 들리지 않는다 (y=%d · 시작 %d)" % [ch.y, start_y])

	# 착지한 뒤에는 같은 턱을 올라선다 — 가드가 「영영 못 오른다」가 아니라 「공중에서만 안 된다」임을 잰다.
	_walk(g, ch, 90, 1.0)
	t.eq(ch.y, ledge_top_y, "착지한 뒤에는 같은 턱을 올라선다")


# ══════════════════════════════════════════════════════════════════
#  A. 물속 무한 점프 (`docs/plans/2.active/water-jump-and-escape.md` 단계 1)
# ══════════════════════════════════════════════════════════════════
#
# ⚠ `net_water`가 아니다 — 재는 것이 **캐릭터의 거동**이지 물의 거동이 아니다(계획).
# 🔴 **바닥을 새로 안 깐다** — 이 아래 그릇들은 **바닥이 없는** 빈 격자 + 물기둥뿐이다.
#  `_floor_grid()`(위, 32셀 깊이의 STONE)을 재사용하지 않는 이유는 정확히 반대다: A-시리즈는
#  `on_ground`가 **시종 거짓**이어야 「물만으로 점프가 먹는다」가 값으로 잡힌다 — 바닥이 있으면
#  캐릭터가 착지해서 `on_ground`가 껴들고, 그러면 이 검사들이 무엇을 재는지 갈리지 않는다.

## `set_water`는 `cmd_fill`을 못 지난다(`net_water._cmd_fill_refuses_water`와 같은 이유) —
## 칸마다 부른다. 상자가 작아서(아래 상수) 비용은 무시할 만하다.
func _water_box(g: CellGrid, x0: int, x1: int, y0: int, y1: int, amount: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			g.set_water(x, y, amount)


## A-시리즈가 공유하는 물기둥의 자리(셀). 폭은 캐릭터 상자(5칸) + 발밑 한 줄 여유,
## 높이는 점프 도달(102px = 25.5셀)보다 훨씬 넉넉하다 — 3연속 점프가 위아래 어느 쪽 가장자리도
## 안 벗어난다.
const WATER_CX0 := 300
const WATER_CX1 := 314
const WATER_CY0 := 150
const WATER_CY1 := 230
const WATER_START_Y := (WATER_CY0 + 20) * Tuning.CELL_PX


## 바닥 없는 그릇 + 그 물기둥 한가운데에 놓인 캐릭터. `amount`가 곧 물의 깊이다 —
## A-2(경계 짝)가 이 인자로 32와 33을 갈라 잰다.
func _submerged(amount: int) -> Array:
	var g := CellGrid.new()
	_water_box(g, WATER_CX0, WATER_CX1, WATER_CY0, WATER_CY1, amount)
	var ch := Character.new()
	ch.place(WATER_CX0 * Tuning.CELL_PX, WATER_START_Y)
	return [g, ch]


## 🔴🔴 **A-1 — 깊은 물에서 공중 점프가 먹는다. 연속 3번.**
##
## ⚠ **뒤집으면 빨개지는 것**: 점프 조건을 `on_ground` 만으로 되돌리면 — 이 그릇엔 바닥이
##  없어 `on_ground`가 시종 거짓이므로 **한 번도 못 뛰고 그대로 떨어진다.**
##
## 🔴 **「vy == JUMP_VY_PX」를 문자 그대로는 안 잰다 — 계획의 표현과 다르게 짰다.**
##  `character.step()`은 점프를 대입한 **그 프레임 안에서 곧바로 중력을 더한다**
##  (`_body.apply_gravity`: `vy = minf(vy + GRAVITY_PX*dt, ...)`, 점프 대입 바로 다음 줄).
##  이건 지면 점프도 똑같이 겪는 것이라 물이 만든 문제가 아니다 — 그래서 매 점프 직후의 `vy`는
##  정확히 `JUMP_VY_PX + GRAVITY_PX*DT`(한 프레임의 중력)다. **그 결정론적인 값**으로
##  「점프가 실제로 발사됐다」를 잰다. `net_character`의 다른 검사들도 `vy`를 직접 안 재고
##  `y`로 재는 것과 같은 이유다.
func _submerged_jump_fires_repeatedly(t) -> void:
	var made := _submerged(Tuning.WATER_MAX)
	var g: CellGrid = made[0]
	var ch: Character = made[1]

	ch.step(g, DT, 0.0, false, false)
	t.ok(not ch.on_ground, "물기둥엔 바닥이 없어 시작이 공중이다 (전제)")

	var expected := Character.JUMP_VY_PX + Character.GRAVITY_PX * DT
	for i in 3:
		ch.step(g, DT, 0.0, true, true)
		t.eq(ch.vy, expected, "%d번째 공중 점프가 물속에서 발사된다 (vy=%.1f)" % [i + 1, ch.vy])


## 🔴🔴 **A-2 — 경계 짝. 32(임계 그대로, 얕음)에서는 안 먹고 33(한 톨 더 깊다)에서는 먹는다.**
##
## ⚠ **뒤집으면 빨개지는 것**: `>` ↔ `>=`를 바꾸면 둘 중 하나가 반대로 나온다.
## 🔴 **0에서만 재면 임계를 200으로 바꿔도 통과한다**(계획이 짚은 함정 — 「값이 우연히 맞는다」).
##  그래서 임계값의 바로 위·아래를 **같이** 잰다.
func _submerged_jump_boundary(t) -> void:
	var expected := Character.JUMP_VY_PX + Character.GRAVITY_PX * DT

	var shallow := _submerged(Tuning.WATER_WET)
	var g0: CellGrid = shallow[0]
	var ch0: Character = shallow[1]
	ch0.step(g0, DT, 0.0, false, false)
	ch0.step(g0, DT, 0.0, true, true)
	t.ok(ch0.vy != expected,
		"물 %d(임계, 얕음)에서는 공중 점프가 안 먹는다 (vy=%.1f)" % [Tuning.WATER_WET, ch0.vy])

	var deep := _submerged(Tuning.WATER_WET + 1)
	var g1: CellGrid = deep[0]
	var ch1: Character = deep[1]
	ch1.step(g1, DT, 0.0, false, false)
	ch1.step(g1, DT, 0.0, true, true)
	t.eq(ch1.vy, expected,
		"물 %d(한 톨 더 깊다)에서는 공중 점프가 먹는다 (vy=%.1f)" % [Tuning.WATER_WET + 1, ch1.vy])


## 🔴🔴 **A-3 — 물 밖으로 나오면 그 프레임에 막힌다.**
##
## ⚠ **뒤집으면 빨개지는 것**: `in_water`를 `on_tick()`에서만 갱신하거나 한 번만 캐시하면 —
##  물을 지운 바로 다음 프레임에도 점프가 먹는다(최대 `TICK_DIVIDER`(3)프레임 낡은 답으로 판정한다).
##  🔴 **이게 「프레임마다 읽나」를 값으로 잡는 자리다.** 한 프레임 안에서만 갈리므로
##  **눈으로는 절대 못 본다** — 그물만 잡는다(계획).
func _leaving_water_blocks_the_very_next_frame(t) -> void:
	var made := _submerged(Tuning.WATER_MAX)
	var g: CellGrid = made[0]
	var ch: Character = made[1]

	ch.step(g, DT, 0.0, false, false)
	var expected := Character.JUMP_VY_PX + Character.GRAVITY_PX * DT
	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, expected, "물속에서 점프가 먹는다 (전제)")

	# 물을 통째로 지운다 — 캐릭터가 있는 상자 + 발밑 한 줄이 전부 사라진다.
	_water_box(g, WATER_CX0, WATER_CX1, WATER_CY0, WATER_CY1, 0)
	t.ok(not ch.on_ground, "여전히 공중이다 (전제 — 바닥이 없어서 물이 없어도 안 선다)")

	# 🔴 물이 사라진 바로 다음 프레임이다. 점프를 다시 누르지만 이제는 안 먹어야 한다 —
	#  그러면 이번 프레임의 `vy`는 중력만 더한 값이지 `JUMP_VY_PX`로 되돌아간 값이 아니다.
	var vy_before := ch.vy
	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, vy_before + Character.GRAVITY_PX * DT,
		"물 밖으로 나온 바로 다음 프레임에 점프가 안 먹는다 (중력만 더해진 vy=%.1f)" % ch.vy)


## 🔴🔴 **A-4 — 범위가 발밑 한 줄을 포함한다.**
##
## ⚠ **뒤집으면 빨개지는 것**: `standing_in_water`의 `cy1`을 `+1` 없이(`(x+h_px-1)`로) 계산하면
##  상자 안이 완전히 비어 있으므로 점프가 안 먹는다.
## 🔴 **`standing_in_fire`와 답이 같은지로 짜지 않는다** — 둘을 한 헬퍼로 접으면
##  `scan == scan`인 항진명제가 된다(CLAUDE.md 「맞대기는 갈라짐만 잡고 사라짐을 못 잡는다」).
##  대신 **셀 배치를 직접 만들고 절대 답을 단언한다**: 상자 안은 그대로 EMPTY로 두고
##  발밑 한 줄에만 깊은 물을 놓는다.
## 🔴🔴 **확인 스텝을 안 둔다 — 이게 이 검사의 핵심이다.**
## `standing_in_water`는 `step()` **맨 앞**(중력이 캐릭터를 움직이기 전)에서 읽힌다.
## ⚠ **처음엔 확인용 `step()`을 먼저 한 번 불렀었고, 그게 가짜 그물이었다** — verify-read가
##  `body.gd`의 `+h_px` 를 `+h_px-1`(발밑 줄 삭제)로 바꿔도 38/38 초록인 것을 값으로 잡았다:
##  확인 스텝의 중력이 캐릭터를 1px 떨어뜨려(`py=800→801`) **상자 자기 밑변이 발밑 행(208)과
##  겹쳐 버렸다** — 발밑 줄이 없어도 물이 이미 상자 안이라 통과한 것이다.
##  ⇒ **점프를 시도하는 그 `step()` 을 처음이자 유일한 호출로 만든다** — 그러면 `in_water`가
##  `place()`가 놓은 자리 그대로(중력이 한 톨도 안 움직인 채로) 읽힌다.
func _submerged_jump_includes_the_foot_row(t) -> void:
	var g := CellGrid.new()
	var ch := Character.new()
	var px := 400 * Tuning.CELL_PX
	var py := 200 * Tuning.CELL_PX
	ch.place(px, py)

	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cx1 := floori((px + Character.W_PX - 1) / float(Tuning.CELL_PX))
	var cy1 := floori((py + Character.H_PX) / float(Tuning.CELL_PX))
	# 🔴 **상자의 마지막 줄(cy1-1)이 비어 있다는 것을 값으로 먼저 잰다** — 안 재면 물이 실은
	#  상자 안에 있는데 「발밑 줄만 있다」고 우연히 믿는 것과 못 가른다.
	t.eq(g.mat_at(cx0, cy1 - 1), Mat.EMPTY, "상자의 마지막 줄엔 물이 없다 (전제)")
	# 상자가 덮는 줄(cy0..cy1-1)은 그대로 EMPTY다 — 발밑 한 줄(cy1)에만 깊은 물을 놓는다.
	for x in range(cx0, cx1 + 1):
		g.set_water(x, cy1, Tuning.WATER_MAX)

	var expected := Character.JUMP_VY_PX + Character.GRAVITY_PX * DT
	ch.step(g, DT, 0.0, true, true)
	t.ok(not ch.on_ground, "공중이다 (전제 — 바닥이 없다)")
	t.eq(ch.vy, expected,
		"발밑 한 줄에만 깊은 물이 있어도 점프가 먹는다 (vy=%.1f)" % ch.vy)


# ══════════════════════════════════════════════════════════════════
#  C. 물살이 캐릭터를 민다 (`docs/plans/2.active/water-jump-and-escape.md` 단계 4)
# ══════════════════════════════════════════════════════════════════
#
# ⚠ **C-1~C-4는 `Body.water_flow()`를 직접 잰다** — 계획이 「힘 함수를 따로 재라」고 못 박은
#  자리다. **C-5·C-6은 그 힘이 실제로 `Character.step()`의 움직임에 닿는지를 짝으로 잰다**
#  (힘 함수 따로 · 그 힘이 움직임에 닿는지 따로 — CLAUDE.md 「짝으로 짜라, 뒤쪽만 쓰면
#  항진명제다」의 그 자리).

## `Body` 하나를 세우고 좌표를 돌려준다 — `standing_in_water`·`water_flow`가 보는 것과
## 같은 범위(상자 + 발밑 한 줄)를 여기서 구해 **어디에 물을 놓을지**를 정한다.
## `[body, cx0, cx1, cy0, cy1]`.
func _water_push_body(px: int, py: int) -> Array:
	var body := Body.new(Character.W_PX, Character.H_PX, Character.STEP_CELLS)
	body.place(px, py)
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cx1 := floori((px + Character.W_PX - 1) / float(Tuning.CELL_PX))
	var cy0 := floori(py / float(Tuning.CELL_PX))
	var cy1 := floori((py + Character.H_PX) / float(Tuning.CELL_PX))
	return [body, cx0, cx1, cy0, cy1]


## 🔴🔴 **C-1 — 좌우가 같으면 물살이 0이다.**
## ⚠ **뒤집으면 빨개지는 것**: 한쪽만 세거나 부호를 빠뜨리면(예: `right`를 안 빼고 `left`만
##  돌려주면) 대칭인데도 0이 아닌 값이 나온다.
func _water_push_zero_when_symmetric(t) -> void:
	var g := CellGrid.new()
	var made := _water_push_body(500 * Tuning.CELL_PX, 200 * Tuning.CELL_PX)
	var body: Body = made[0]
	var cx0: int = made[1]
	var cx1: int = made[2]
	var cy0: int = made[3]
	var cy1: int = made[4]
	for cy in range(cy0, cy1 + 1):
		t.ok(g.set_water(cx0 - 1, cy, Tuning.WATER_MAX), "왼쪽 기둥에 물을 놓는다 (전제)")
		t.ok(g.set_water(cx1 + 1, cy, Tuning.WATER_MAX), "오른쪽 기둥에도 같은 양을 놓는다 (전제)")
	t.eq(body.water_flow(g), 0, "좌우가 같으면 물살이 0이다")


## 🔴🔴 **C-2 — 부호. 왼쪽에만 물 ⇒ 양수(오른쪽으로), 오른쪽에만 물 ⇒ 음수. 둘 다 잰다.**
## ⚠ **뒤집으면 빨개지는 것**: `diff`를 `right - left`로 뒤집으면 둘 다 반대로 나온다.
##  🔴 **한쪽만 재면 부호 뒤집기가 반은 통과한다** — 그래서 둘을 같이 잰다.
func _water_push_sign_both_ways(t) -> void:
	var g_left := CellGrid.new()
	var made_left := _water_push_body(500 * Tuning.CELL_PX, 200 * Tuning.CELL_PX)
	var body_left: Body = made_left[0]
	for cy in range(made_left[3], made_left[4] + 1):
		g_left.set_water(made_left[1] - 1, cy, Tuning.WATER_MAX)
	var push_left := body_left.water_flow(g_left)
	t.ok(push_left > 0, "왼쪽에만 물 — 오른쪽으로 민다 (양수, %d)" % push_left)

	var g_right := CellGrid.new()
	var made_right := _water_push_body(500 * Tuning.CELL_PX, 200 * Tuning.CELL_PX)
	var body_right: Body = made_right[0]
	for cy in range(made_right[3], made_right[4] + 1):
		g_right.set_water(made_right[2] + 1, cy, Tuning.WATER_MAX)
	var push_right := body_right.water_flow(g_right)
	t.ok(push_right < 0, "오른쪽에만 물 — 왼쪽으로 민다 (음수, %d)" % push_right)


## 🔴🔴 **C-3 — 세기가 차이에 비례한다. 차이를 늘리면 힘이 엄격히 커진다.**
## ⚠ **뒤집으면 빨개지는 것**: 상수를 그냥 돌려주면(「계산 안 하고 그럴듯한 값」) 세 값이 같아진다.
## ⚠ **정확히 비례라고 안 박는다** — `WATER_MIN_DIFF` 문턱이 낮은 차이를 깎아내려 정확한
##  선형은 아니다(계획이 그렇게 경고했다). **엄격히 커지나만** 잰다.
func _water_push_scales_with_diff(t) -> void:
	var amounts := [80, 160, Tuning.WATER_MAX]
	var pushes: Array[int] = []
	for amount in amounts:
		var g := CellGrid.new()
		var made := _water_push_body(500 * Tuning.CELL_PX, 200 * Tuning.CELL_PX)
		var body: Body = made[0]
		for cy in range(made[3], made[4] + 1):
			g.set_water(made[1] - 1, cy, amount)
		pushes.append(body.water_flow(g))
	t.ok(pushes[0] < pushes[1] and pushes[1] < pushes[2],
		"차이가 늘수록 힘이 엄격히 커진다 (%d < %d < %d)" % [pushes[0], pushes[1], pushes[2]])


## 🔴🔴 **C-4 — 고인 물(평형)에서는 0이다.**
##
## 🔴 **처음 버전이 항진명제였다**(verify-read, 2026-08-08) — 웅덩이가 캐릭터 발밑보다
##  **아래**에 고여 스캔 범위(상자+발밑 줄) 안에 물이 한 칸도 없었다. 문턱을 0으로 지워도
##  「볼 물이 없어서」 여전히 0이 나와 69/69 초록이었다 — **문턱이 잡은 게 아니었다.**
##  ⇒ **캐릭터가 실제로 잠기는 웅덩이로 다시 짠다**(verify-read가 확인한 폭 12 장면).
##
## ⚠ **뒤집으면 빨개지는 것**: `WATER_MIN_DIFF` 문턱을 빼면(0으로 하면) 정착 뒤에도 반올림
##  잔차 때문에 0이 아닌 값이 계속 나온다.
## 🔴 **웅덩이 폭을 12칸으로 좁게 판다** — 넓은 웅덩이는 `docs/design/물.md`가 적어 둔
##  「정지 수면이 균일하지 않다」(먼 칸끼리는 어긋날 수 있다)에 걸린다. verify-read 실측
##  (폭 12 → 정착 69틱, 잔차 |left-right| 23, 문턱 36)이 이 폭에서 문턱 안에 든다는 것을 이미 쟀다.
## ⚠ **왼쪽 절반에만 붓는다** — 「처음부터 대칭이라 0」이 아니라 「흘러서 0이 됐다」임을 재려면
##  시작을 비대칭으로 둬야 한다.
## ⚠ **여유가 크지 않다**(잔차 23 vs 문턱 36 — 1.6배). 이 폭·이 배치에서는 통과하지만,
##  캐릭터 상자가 수면에 걸쳐 절반만 잠기는 배치라면 넘길 수 있다 — **그건 안 쟀다.**
func _water_push_zero_at_equilibrium(t) -> void:
	var g := CellGrid.new()
	var pool_w := 12
	var bx0 := 500                     # 웅덩이 왼쪽 안쪽 칸
	var cx0 := bx0 + 3                 # 캐릭터를 웅덩이 안쪽에 둔다(양쪽에 다 여유가 있게)
	var cy1 := 300                     # 웅덩이 바닥 = 캐릭터 상자의 발밑 줄
	var cy0 := cy1 - (Character.H_PX / Tuning.CELL_PX)  # 상자 위쪽 줄
	# 🔴🔴 **깊이가 절반의 요점이다.** 처음엔 30행 깊이로 부었는데, 그러면 웅덩이가 상자 높이보다
	#  훨씬 두꺼워져 **두 이웃 기둥이 상자 범위(8행) 안에서 전부 255로 꽉 찬다** — 진짜 잔차(수면
	#  꼭대기 한 줄에서만 남는다, `물.md` 「정지 수면이 균일하지 않다」)는 상자 범위 **위**에
	#  있어서 안 보였다. 그때는 문턱을 0으로 지워도 **여전히 0**이었다(실측·verify-read가
	#  다른 경로로도 짚은 자리) — 상자 범위 안이 이미 좌우가 완전히 같아서 문턱이 할 일이 없었다.
	#  ⇒ **깊이를 상자 높이(8행)에 맞춰 얕게 부어 수면이 상자 범위 안에 오게 한다.**
	var cy_pour_top := cy1 - 16

	var made := _water_push_body(cx0 * Tuning.CELL_PX, cy0 * Tuning.CELL_PX)
	var body: Body = made[0]

	# 벽 둘 + 바닥 하나 — 캐릭터의 두 이웃 기둥(cx0-1·cx1+1)이 전부 이 웅덩이 안이다.
	g.apply(CellGrid.cmd_fill(bx0 - 1, cy_pour_top, bx0 - 1, cy1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(bx0 + pool_w, cy_pour_top, bx0 + pool_w, cy1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(bx0 - 1, cy1, bx0 + pool_w, cy1, Mat.STONE))
	# 왼쪽 절반에만, 바닥까지 깊게 붓는다 — 12칸에 퍼진 뒤에도 상자 높이(8칸)를 넉넉히 덮는다.
	for cx in range(bx0, bx0 + pool_w / 2):
		for cy in range(cy_pour_top + 1, cy1):
			g.set_water(cx, cy, Tuning.WATER_MAX)

	g.step()
	var settle := 1
	while g.active_chunk_count() > 0 and settle < 2000:
		g.step()
		settle += 1
	t.ok(settle > 1 and settle < 2000, "웅덩이가 상한 안에 평형에 든다 (%d틱 — 루프가 헛돌지 않았다)"
		% settle)
	t.eq(g.active_chunk_count(), 0, "정말 평형이다 (전제)")

	# 🔴 **캐릭터가 실제로 물에 잠겼는지 먼저 잰다** — 이게 없으면 이전처럼 「볼 물이 없어서
	#  0」과 「평형이라 0」을 못 가른다.
	t.eq(g.mat_at(cx0, cy0), Mat.WATER, "캐릭터 상자 맨 위 줄이 실제로 물에 잠겼다 (전제)")
	t.eq(g.mat_at(cx0, cy1 - 1), Mat.WATER, "캐릭터 상자 맨 아래 줄도 잠겼다 (전제)")
	t.eq(body.water_flow(g), 0, "실제로 잠긴 채로도 평형에 든 웅덩이에서는 물살이 0이다")


## 🔴🔴 **C-5 — 짝 검사. 힘이 실제로 움직임에 닿는지, 그리고 안 닿을 때(대조군)도 확인한다.**
## ⚠ **뒤집으면 빨개지는 것**: `water_push`를 `move_x`의 합에 안 더하면 ①이 안 움직여 red.
## 🔴 **②만으로는 항진명제다** — 물이 없는데 안 움직이는 것은 당연하다. **①이 있어야**
##  「그 물살이 실제로 움직임에 닿았다」가 값으로 선다.
func _water_push_pair_moves_and_stops(t) -> void:
	var px := 500 * Tuning.CELL_PX
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cy0 := floori(REST_Y / float(Tuning.CELL_PX))
	var cy1 := floori((REST_Y + Character.H_PX) / float(Tuning.CELL_PX))

	# ① 왼쪽에만 물 — 입력 0 · 땅 위. 밀리면 오른쪽(+x)으로 간다.
	var g_water := _floor_grid()
	var ch_water := Character.new()
	ch_water.place(px, REST_Y)
	for cy in range(cy0, cy1 + 1):
		g_water.set_water(cx0 - 1, cy, Tuning.WATER_MAX)
	for _i in 30:
		ch_water.step(g_water, DT, 0.0, false, false)
	t.ok(ch_water.x > px, "① 왼쪽에만 물이 있으면(입력 0·땅 위) x가 오른쪽으로 움직인다 (%d → %d)"
		% [px, ch_water.x])

	# ② 같은 배치에서 물만 지운다 — ①과 짝이다.
	var g_dry := _floor_grid()
	var ch_dry := Character.new()
	ch_dry.place(px, REST_Y)
	for _i in 30:
		ch_dry.step(g_dry, DT, 0.0, false, false)
	t.eq(ch_dry.x, px, "② 같은 배치에서 물만 지우면 안 움직인다 (①과 짝이다)")


## 🔴🔴 **C-6 — 캐릭터가 물을 안 민다. 폴더 계약(`src/actor/` float → `src/sim/` 정수 결정론
##  읽기 전용)을 값으로 지킨다.**
## ⚠ **뒤집으면 빨개지는 것**: 실수로 격자에 쓰면(예: 지나간 자리의 물을 지운다) red.
func _water_push_does_not_move_water(t) -> void:
	var px := 500 * Tuning.CELL_PX
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(px, REST_Y)
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cy0 := floori(REST_Y / float(Tuning.CELL_PX))
	var cy1 := floori((REST_Y + Character.H_PX) / float(Tuning.CELL_PX))
	for cy in range(cy0, cy1 + 1):
		g.set_water(cx0 - 1, cy, Tuning.WATER_MAX)
	var before := g.count_material(Mat.WATER)
	t.ok(before > 0, "물이 실제로 놓였다 (전제)")

	for _i in 30:
		ch.step(g, DT, 0.0, false, false)

	t.eq(g.count_material(Mat.WATER), before, "캐릭터가 여러 프레임 움직여도 물 칸 수가 그대로다")
	var total := 0
	for cy in range(cy0 - 5, cy1 + 6):
		for cx in range(cx0 - 10, cx0 + 20):
			if g.mat_at(cx, cy) == Mat.WATER:
				total += g.aux_at(cx, cy)
	t.eq(total, before * Tuning.WATER_MAX, "물의 총량도 그대로다 (캐릭터가 시뮬을 안 건드린다)")


## 🔴🔴 **C-7 — 옆에 불이 있어도 물살이 안 오염된다.**
##
## 🔴 **verify-read가 이 가드 없이 값으로 확인했다**(2026-08-08): 왼쪽 기둥을 나무로 채우고
##  불을 붙이면 `_aux`(남은 연료) 합이 590 — `mat_at()==WATER` 확인 없이 그냥 더하면
##  `diff = 590`(9행 기준 평균 ≈65)이 문턱(36)을 넘어 **불이 캐릭터를 물처럼 민다.**
##  ⚠ **뒤집으면 빨개지는 것**: `body.gd`의 `water_flow`에서 `mat_at(...) == Mat.WATER` 두 줄을
##  지우면(또는 우회하면) 이 검사가 0이 아닌 값을 보고 red가 된다.
func _water_push_ignores_fire(t) -> void:
	var g := CellGrid.new()
	var made := _water_push_body(500 * Tuning.CELL_PX, 200 * Tuning.CELL_PX)
	var body: Body = made[0]
	var cx0: int = made[1]
	var cy0: int = made[3]
	var cy1: int = made[4]
	# 왼쪽 기둥을 나무로 채우고 불을 붙인다 — 오른쪽은 그대로 비어 있다.
	for cy in range(cy0, cy1 + 1):
		g.apply(CellGrid.cmd_fill(cx0 - 1, cy, cx0 - 1, cy, Mat.WOOD))
	for cy in range(cy0, cy1 + 1):
		g.ignite(cx0 - 1, cy)
	t.ok(g.burning_count() > 0, "나무가 실제로 탄다 (전제)")

	var fuel_sum := 0
	for cy in range(cy0, cy1 + 1):
		fuel_sum += g.aux_at(cx0 - 1, cy)
	t.ok(fuel_sum > 0, "타는 기둥에 남은 연료(`_aux`)가 실제로 있다 (전제, 합 %d)" % fuel_sum)

	t.eq(body.water_flow(g), 0, "물이 아닌(타는) 이웃은 물살에 안 섞인다 — 0이다")


## 🔴🔴 **C-8 — 물 밖으로 나오면 그 프레임에 멈춘다.** 점프의 A-3과 같은 자리(짝)다.
##
## 🔴 **코드는 맞았지만 이 검사가 없어서 안 잡혔다**(verify-read, 2026-08-08): `water_push`를
##  `recoil_vx`처럼 멤버로 바꿔 감쇠시키고 물이 없어져도 남게 했더니 **69/69 초록**이었다 —
##  「물 밖으로 나오면 멈춘다」를 재는 검사가 하나도 없었기 때문이다.
## ⚠ **뒤집으면 빨개지는 것**: `water_push`를 지역 변수가 아니라 누적되는 멤버로 만들면,
##  물을 지운 다음 프레임에도 (감쇠하며) 계속 밀려 `x2 != x1`이 된다.
## 🔴 **1프레임만 민다** — 여러 프레임을 밀면 캐릭터가 원래 기둥 밖으로(1셀=4px) 나가
##  「물 밖」과 「물살이 셀 경계를 벗어났다」가 섞인다. 여기서 재는 것은 **물을 지운 그 자체**다.
func _water_push_stops_the_frame_water_leaves(t) -> void:
	var px := 500 * Tuning.CELL_PX
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cy0 := floori(REST_Y / float(Tuning.CELL_PX))
	var cy1 := floori((REST_Y + Character.H_PX) / float(Tuning.CELL_PX))

	var g := _floor_grid()
	var ch := Character.new()
	ch.place(px, REST_Y)
	for cy in range(cy0, cy1 + 1):
		g.set_water(cx0 - 1, cy, Tuning.WATER_MAX)

	# 한 프레임만 민다 — 아직 같은 기둥 옆이다(4px 미만 이동, 셀 경계를 안 넘는다).
	ch.step(g, DT, 0.0, false, false)
	var x1 := ch.x
	t.ok(x1 > px, "한 프레임 만에 물살로 밀렸다 (전제, %d → %d)" % [px, x1])

	# 물을 지운다 — 같은 기둥(cx0-1)이다. 캐릭터가 아직 안 옮겨간 것이 위 전제다.
	for cy in range(cy0, cy1 + 1):
		g.set_water(cx0 - 1, cy, 0)
	ch.step(g, DT, 0.0, false, false)
	var x2 := ch.x
	t.eq(x2, x1, "물이 사라진 바로 다음 프레임에 더 안 밀린다 (감쇠하며 남지 않는다)")
