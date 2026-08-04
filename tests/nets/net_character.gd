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


func run(t) -> void:
	# 🔴 **32px 전환에서 안 올렸다.** 턱을 만드는 것은 폭발이고 폭발은 **셀** 단위인데
	# 셀이 안 변했다 — "1셀이면 조금만 파여도 걸린다"가 여전히 그대로다(`character.gd`).
	# ⚠ 반대쪽 근거("타일 하나를 통째로 올라가면 위력 감각이 뭉개진다")는 타일이 8셀이 되며
	# **느슨해졌다**. 두 근거의 방향이 다르고, 좁은 쪽이 이긴다.
	t.eq(Character.STEP_CELLS, 2, "스텝 오프셋이 2셀이다")
	t.eq(Character.W_PX, 32, "캐릭터 폭이 32px = 지형 타일과 같다")
	# 🔴🔴 **`H_PX` 는 아무도 안 재고 있었다.** 아래 검사들이 `FLOOR_TOP - H_PX` 로 기대값을 만드는데
	#  실제값도 같은 상수를 지나서 **양쪽이 같이 틀리면 상쇄된다** — 상자가 32×16이 돼도 전부 초록이다.
	#  ⚠ 그리고 그건 「머리가 벽에 박히는데 지나간다」로만 보인다(GDD 격자).
	t.eq(Character.H_PX, 32, "캐릭터 높이가 32px = 지형 타일과 같다")

	_fall_and_land(t)
	_jump_height(t)
	_ledge(t, 2, true)
	_ledge(t, 3, false)
	_broken_ground(t)
	_wall(t)
	_airborne_never_climbs(t)


func _floor_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	return g


func _walk(g: CellGrid, ch: Character, frames: int, axis: float) -> void:
	for _i in frames:
		ch.step(g, DT, axis, false)


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


## 실제로 뛰어서 도달 높이를 잰다. 🔴 **점프 입력은 한 프레임뿐**이다 —
##  계속 넣으면 착지할 때마다 다시 뛰어서 「한 번 뛴 높이」가 아니게 된다.
func _jump_height(t) -> void:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, REST_Y)
	_walk(g, ch, 5, 0.0)
	t.ok(ch.on_ground, "뛰기 전에 접지 상태다 (검사의 전제)")
	var y0 := ch.y

	ch.step(g, DT, 0.0, true)
	var top := ch.y
	for _i in 120:
		ch.step(g, DT, 0.0, false)
		top = mini(top, ch.y)

	t.eq(y0 - top, JUMP_PEAK_PX, "점프 도달 높이가 %dpx다" % JUMP_PEAK_PX)
	# 🔴 **되돌아오는 것까지 본다.** 안 보면 「떠오른 채로 안 내려오는」 구현도 통과한다.
	t.ok(ch.on_ground and ch.y == y0, "떨어져서 원래 높이로 돌아온다 (y=%d · 시작 %d)" % [ch.y, y0])

	# 🔴 **상수 쪽 — 해석식이 타일로 몇인가.** 거동만 재면 두 상수를 **같은 비율로** 틀리게
	#  고쳤을 때(둘 다 ×3 따위) 도달 높이가 그대로라 안 걸린다. 이 줄이 그 갈래를 문다.
	var peak := Character.JUMP_VY_PX * Character.JUMP_VY_PX / (2.0 * Character.GRAVITY_PX)
	var tile := float(Tuning.TILE_CELLS * Tuning.CELL_PX)
	t.eq(snappedf(peak / tile, 0.001), JUMP_PEAK_TILES,
		"해석식 도달 높이가 %s타일이다 (v²/2g = %.0fpx ÷ 타일 %.0fpx)" % [
			JUMP_PEAK_TILES, peak, tile])


func _ledge_grid(cells: int) -> CellGrid:
	var g := _floor_grid()
	g.apply(CellGrid.cmd_fill(
		LEDGE_CX, FLOOR_CY - cells, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
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
		g.apply(CellGrid.cmd_fill(sx, last_top, ex, CellGrid.H - 1, Mat.STONE))

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
	ch.step(g, DT, 0.0, false)
	t.ok(not ch.on_ground, "시작이 공중이다 (y=%d · 바닥 %d)" % [ch.y, REST_Y])
	t.eq(ch.x, start_x, "턱 왼쪽 면에 붙어 있다")

	# 🔴 **한 프레임이면 갈린다.** 가드가 없으면 이 프레임에 4px 들려서 x가 앞으로 나간다.
	ch.step(g, DT, 1.0, false)
	t.eq(ch.x, start_x, "공중에서 턱을 밀어도 앞으로 안 나간다")
	t.ok(ch.y >= start_y, "공중에서 들리지 않는다 (y=%d · 시작 %d)" % [ch.y, start_y])

	# 착지한 뒤에는 같은 턱을 올라선다 — 가드가 「영영 못 오른다」가 아니라 「공중에서만 안 된다」임을 잰다.
	_walk(g, ch, 90, 1.0)
	t.eq(ch.y, ledge_top_y, "착지한 뒤에는 같은 턱을 올라선다")
