extends RefCounted
## 캐릭터 — 이동·중력·점프·착지·**스텝 오프셋**. 격자를 **읽기만** 한다.
##
## 🔴🔴 **`Node`가 아니라 `RefCounted`인 게 요점이다.** 캐릭터가 `Node`면 스텝 오프셋을
##  헤드리스로 못 잰다 — 판정 4(「자기가 부순 지형 위를 걸어 다니나」)가 그물로 넘어가느냐
##  눈으로만 보느냐가 여기서 갈린다.
##
## 🔴🔴 **Godot 물리(`CharacterBody2D` + 콜리전)를 쓰지 않는다.** 지형이 TileMap이 아니라 4px
##  셀 배열이라, 물리 엔진에 태우려면 **폭발마다 콜리전 셰이프를 다시 구워야 한다.**
##  폭발 하나가 셀 수백 개를 바꾸니 그게 진짜 비용이다. ⇒ 이동·착지를 직접 짜고 셀을 직접 읽는다.
##
## 🔴 **여기는 float을 써도 된다.** GDD 멀티 표가 못 박았다 — 격자·투사체는 결정론,
##  **플레이어·몬스터·아이템은 호스트 권위**다. 정수 지옥은 격자에 닿는 코드만이다.
##  ⚠ 그래서 이 파일은 `net_determinism`의 대상이 아니다. 대신 `net_layers`가
##   **`src/view/`·`src/stage/` 경로 문자열이 안 나오는 것**을 잰다.
##   🔴 그건 「화면을 참조하지 않는다」까지고, **「씬 트리를 모른다」는 아무도 안 잰다** —
##    `Input`·`Engine` 같은 전역은 preload 없이 닿으므로 경로 스캔에 안 걸린다.
##    지키는 것은 규율뿐이다. 여기에 `Input.`을 한 줄 쓰면 그물은 초록이고 서버만 죽는다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

## 캐릭터 크기. 🔴 **16px = 4셀 = 지형 타일과 정확히 같다**(GDD 격자).
##  캐릭터와 타일 두께를 같게 잡은 것이 「저 벽을 뚫으면 지나갈 수 있다」를 화면에서 세게 만드는 장치다.
const W_PX := 16
const H_PX := 16

## 🔴🔴 **스텝 오프셋 2셀(8px).** 이게 없으면 캐릭터가 **자기가 부순 4px 턱에 걸려 멈춘다.**
##  셀이 4px이라 폭발이 지나간 자리는 매끈한 바닥이 아니라 1~2셀짜리 턱이 널린 면이고,
##  이 게임에서는 그게 예외가 아니라 **기본 상태**다 — 마법을 쏘는 게 곧 지형을 부수는 것이니까.
##
## ⚠ **2셀인 이유**: 4셀(16px)로 두면 지형 타일 하나를 통째로 걸어 올라가서
##  **「저 벽을 뚫으면 지나갈 수 있다」는 위력 감각이 뭉개진다.** 1셀이면 조금만 파여도 걸린다.
## ⚠ 대신 쓸 수 있던 것(경사면 처리 · 캡슐 충돌 · 아무것도 안 함)은 기획 문서 「나중에 다시 열 것」에 있다.
const STEP_CELLS := 2
const STEP_PX := STEP_CELLS * Tuning.CELL_PX

## 🔴 손맛값이다 — 화면을 보고 정했다. 근거를 같이 적어야 다음 사람이 못 되돌린다.
##  · 이동 130px/s = 8타일/s. 960px 화면을 7.4초에 가로지른다. 「걷는다」로 읽히는 하한쯤이다
##  · 중력 1200px/s² + 점프 -360px/s ⇒ 도달 높이 v²/2g = 54px = **3.4타일**,
##    체공 0.6초. 3타일 = 캐릭터 셋을 쌓은 높이라 「저기까지 뛴다」가 눈으로 가늠된다
##  · 낙하 상한 900px/s는 프레임당 15px(4셀)로, 벽을 뚫고 지나가지 않게 하는 안전선이다
const MOVE_SPEED_PX := 130.0
const GRAVITY_PX := 1200.0
const JUMP_VY_PX := -360.0
const MAX_FALL_PX := 900.0

## 좌상단 px. 🔴🔴 **정수다. 소수부는 `_rem_*`가 따로 들고 있는다.**
##  소수 위치로 두면 상자가 셀 경계를 반 칸 걸치고, 그러면 **착지 높이가 매번 최대 1px 달라진다** —
##  캐릭터가 지표면에서 1px 떠 있는 상태로 영원히 서 있고, 그건 그물이 「정확히 지표면」을
##  못 재게 만든다(실측: 384가 기대인데 384.0~384.99가 나왔다).
##  ⚠ 그리고 `snap_2d_transforms_to_pixel`이 켜져 있어 **어차피 화면에서는 정수로 그려진다** —
##   소수 위치는 얻는 게 하나도 없이 판정만 흐린다.
var x := 0
var y := 0
var vy := 0.0
var on_ground := false
## 마지막으로 향한 쪽(+1 오른쪽 · -1 왼쪽). 마우스가 캐릭터 위에 정확히 있을 때의 기본 방향이다.
var facing := 1

## 아직 1px이 안 된 이동분. 🔴 이게 없으면 프레임당 2.17px가 **매번 2px로 잘려**
##  실제 속도가 60px/s만큼 조용히 느려진다.
var _rem_x := 0.0
var _rem_y := 0.0


func place(px: int, py: int) -> void:
	x = px
	y = py
	vy = 0.0
	_rem_x = 0.0
	_rem_y = 0.0
	on_ground = false


func center() -> Vector2:
	return Vector2(x + W_PX * 0.5, y + H_PX * 0.5)


## 🔴🔴 **60Hz(`_physics_process` 매번)로 돈다 — 시뮬 20Hz에 묶지 마라.**
##  20Hz에 묶으면 조작이 뚝뚝 끊겨 재는 것 3(「손에 붙나」)이 통째로 깨진다.
##  호스트 권위라 틱에 묶일 이유가 없다(GDD 멀티 표).
func step(grid: CellGrid, dt: float, axis: float, jump: bool) -> void:
	on_ground = _grounded(grid)
	if jump and on_ground:
		vy = JUMP_VY_PX
	vy = minf(vy + GRAVITY_PX * dt, MAX_FALL_PX)

	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1
	# 🔴 축을 나눠 푼다 — 한 번에 대각으로 밀면 모서리에서 어느 쪽이 막혔는지 알 수 없어
	#  「벽에 붙어 점프하면 가끔 통과한다」가 된다.
	_move_x(grid, axis * MOVE_SPEED_PX * dt)
	if _move_y(grid, vy * dt):
		vy = 0.0
	on_ground = _grounded(grid)


## 수평. 막히면 **스텝 오프셋**을 시도한다.
## ⚠ 막히면 나머지를 **버린다** — 안 들고 있으면 벽에 붙어 있는 동안 나머지가 쌓였다가
##  벽이 사라지는 순간 캐릭터가 몇 px 순간이동한다.
func _move_x(grid: CellGrid, dx: float) -> void:
	_rem_x += dx
	var n := roundi(_rem_x)
	_rem_x -= n
	if n == 0:
		return
	var sgn := signi(n)
	# 🔴 1px씩 민다 — 한 번에 밀고 되돌리는 방식은 두꺼운 벽에서 「어디까지 갈 수 있었나」를 잃는다.
	for _i in absi(n):
		if _box_free(grid, x + sgn, y):
			x += sgn
			continue
		if not _try_step_up(grid, sgn):
			_rem_x = 0.0
			return


## 🔴 **공중에서는 안 된다.** 안 그러면 벽에 붙어 있는 동안 턱이 아니라 벽을 타고 오른다.
## ⚠ 올라갈 자리(`y - lift`)가 비어 있는지도 같이 본다 — 천장 아래 좁은 틈에서
##  머리를 박고 올라가면 캐릭터가 지형에 끼인다.
func _try_step_up(grid: CellGrid, dx: int) -> bool:
	if not on_ground:
		return false
	for lift in range(1, STEP_PX + 1):
		if _box_free(grid, x, y - lift) and _box_free(grid, x + dx, y - lift):
			x += dx
			y -= lift
			return true
	return false


## 수직. 막혔으면 true(호출부가 `vy`를 0으로 만든다).
func _move_y(grid: CellGrid, dy: float) -> bool:
	_rem_y += dy
	var n := roundi(_rem_y)
	_rem_y -= n
	if n == 0:
		return false
	var sgn := signi(n)
	for _i in absi(n):
		if not _box_free(grid, x, y + sgn):
			_rem_y = 0.0
			return true
		y += sgn
	return false


func _grounded(grid: CellGrid) -> bool:
	return not _box_free(grid, x, y + 1)


## 🔴 **「고체인가」는 격자에 물어본다**(`grid.is_solid`). 여기서 `mat_at() != EMPTY`로 다시
##  판정하면 규칙이 두 벌이 되고, 재료가 늘 때 「탄은 뚫는데 캐릭터는 막힌다」가 된다.
## ⚠ 상자가 덮는 마지막 픽셀은 `px + W_PX - 1`이다. `- 1`을 빼면 경계에 딱 붙었을 때
##  옆 칸을 한 줄 더 읽어 **벽에서 1px 떠서 멈춘다.**
## ⚠ 음수 나눗셈은 GDScript에서 0 쪽으로 잘린다(`-1 / 4 == 0`) — 격자 왼쪽·위 밖에서
##  셀 좌표가 한 칸 튄다. `floori`로 내림을 강제한다.
func _box_free(grid: CellGrid, px: int, py: int) -> bool:
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cx1 := floori((px + W_PX - 1) / float(Tuning.CELL_PX))
	var cy0 := floori(py / float(Tuning.CELL_PX))
	var cy1 := floori((py + H_PX - 1) / float(Tuning.CELL_PX))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if grid.is_solid(cx, cy):
				return false
	return true
