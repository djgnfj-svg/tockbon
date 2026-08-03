extends RefCounted
## 캐릭터가 자기가 부순 지형 위를 걸어 다니나 (기획 판정 4).
##
## 🔴 이 그물이 도는 것 자체가 `src/actor/character.gd` 가 RefCounted 인 덕이다.
## Node 였으면 씬을 세워야 하고, 그럼 이 판정이 "눈으로만" 재는 것이 된다.
##
## ⚠ 캐릭터는 1px 단위로 미는데 프레임당 이동이 2.17px라 **마지막 조각이 소수**다.
## 그래서 "정확히 얼마"가 아니라 "1px 이내"로 잰다. 세로는 다르다 —
## 착지는 1px씩 내려가다 막히는 것이라 **정확히** 지표면이어야 한다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")

const DT := 1.0 / 60.0
const FLOOR_CY := 100      # 바닥 윗면 셀
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX     # 400px
const REST_Y := FLOOR_TOP - Character.H_PX       # 384px — 바닥에 선 캐릭터의 y


func run(t) -> void:
	# 기획이 못 박은 값이다. 4셀로 늘리면 타일 하나를 통째로 걸어 올라가서
	# "저 벽을 뚫으면 지나갈 수 있다"는 위력 감각이 뭉개진다.
	t.eq(Character.STEP_CELLS, 2, "스텝 오프셋이 2셀이다")
	t.eq(Character.W_PX, 16, "캐릭터 폭이 16px = 지형 타일과 같다")

	_fall_and_land(t)
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


const LEDGE_CX := 30
const LEDGE_PX := LEDGE_CX * Tuning.CELL_PX      # 120px — 턱의 왼쪽 면


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
		# 벽에 붙어 멈춘다. 상자 오른쪽 끝이 턱 왼쪽 면이라 x가 **정확히** ledge_px - 16이다.
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
##  ⇒ **처음부터 턱 왼쪽 면에 붙여 놓고 공중에서 시작한다.**
##
## 🔴 턱은 2셀이다 — `_ledge(2, true)`가 **같은 지형에서 걸어서는 올라선다**를 이미 쟀다.
##  그래서 여기서 못 오르는 것은 지형 탓이 아니라 **가드 하나 때문**이라는 게 확정된다.
func _airborne_never_climbs(t) -> void:
	var g := _ledge_grid(2)
	var ledge_top_y := (FLOOR_CY - 2) * Tuning.CELL_PX - Character.H_PX  # 376
	var ch := Character.new()
	# 턱 위(376)와 바닥 위(384) 사이. 발이 턱 옆구리에 걸리는 높이이면서 아직 공중이다.
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
