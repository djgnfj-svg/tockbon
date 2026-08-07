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
