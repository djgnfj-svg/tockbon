extends RefCounted
## 몸 — 이동·중력 적분·지형 충돌·스텝 오프셋. 격자를 **읽기만** 한다.
##
## 🔴🔴 **`character.gd` 에서 뽑아냈다**(`monsters-minimum` 단계 0). 캐릭터와 몬스터가 같은
##  다섯 줄(중력 → 걷기 → 낙하 → 접지 재계산)을 쓰게 만드는 것이 이 파일의 이유다 —
##  둘로 나뉘면 「몬스터만 자기가 부순 턱에 낀다」같은 어긋남이 반드시 난다.
##
## 🔴 **크기·스텝 높이·중력을 하나도 안 든다. 전부 생성 인자 또는 호출 인자다.**
##  ⚠ `W_PX`·`GRAVITY_PX` 같은 상수로 두면 `Character.W_PX == 20` 류를 **정적으로** 읽는
##  그물(`net_character`·`net_damage`·`net_sprite`·`net_staff`·`net_tables`)이 파스 단계에서
##  깨지는데, `load()`는 파스 실패해도 null이 아니라 **「빨개지는 게 아니라 없어진다」**
##  (통과 수만 조용히 준다) — 구현자가 그 단언들을 지우는 쪽으로 가고, 그러면
##  `net_sprite`가 스스로 적어 둔 방어(「없으면 누가 W_PX를 32로 되돌려도 그물이 전부 초록이다」)가
##  사라진다. ⇒ 캐릭터는 **자기 상수를 그대로 들고** 생성자·호출부에 넘긴다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
## 🔴 통지의 좌표계(고정소수점)를 읽으려면 그 상수가 필요하다 — `character.gd`와 같은 이유로
##  `src/sim/`을 참조하는 것은 계약 안쪽이다(막히는 것은 `src/view/`·`src/stage/`뿐).
const SpellSim := preload("res://src/sim/spell_sim.gd")

## 좌상단 px. 🔴 정수다 — 소수부는 `_rem_*` 가 든다.
##  소수 위치로 두면 상자가 셀 경계를 반 칸 걸치고, 그러면 착지 높이가 매번 최대 1px 달라진다.
var x := 0
var y := 0
var vy := 0.0
var on_ground := false

var w_px: int          # 🔴 생성 뒤 안 바꾼다
var h_px: int
var step_cells: int
var step_px: int

## 아직 1px이 안 된 이동분. 🔴 이게 없으면 프레임당 이동이 **매번 정수로 잘려**
##  실제 속도가 조용히 느려진다.
var _rem_x := 0.0
var _rem_y := 0.0


## ⚠ **크기 유효성 검사를 안 넣는다.** 인자를 뒤바꿔 넣는 실패(`h, w`)는
##  `net_character`의 「8셀 벽에 막힌다」·「3셀 턱에 딱 붙어 막힌다」가 **값으로** 잡는다 —
##  가드를 넣으면 그물이 재던 것을 가드가 가로채고, 그건 거짓 손잡이다.
func _init(box_w: int, box_h: int, step: int) -> void:
	w_px = box_w
	h_px = box_h
	step_cells = step
	step_px = step * Tuning.CELL_PX


## `x`·`y`·`vy`·`on_ground`·`_rem_*` 만 되돌린다. 체력·무적 같은 것은 호출부(`character.gd`
##  등)의 몫이다 — 몸이 아는 것은 몸뿐이다.
func place(px: int, py: int) -> void:
	x = px
	y = py
	vy = 0.0
	_rem_x = 0.0
	_rem_y = 0.0
	on_ground = false


func center() -> Vector2:
	return Vector2(x + w_px * 0.5, y + h_px * 0.5)


## 🔴 중력도 인자로 받는다. 여기 `GRAVITY_PX` 상수를 두지 마라 — `W_PX`와 정확히 같은 함정이다.
##  `net_character`가 `Character.JUMP_VY_PX * Character.JUMP_VY_PX / (2.0 * Character.GRAVITY_PX)`를
##  **정적으로** 읽는다 — 그게 「`GRAVITY`와 `JUMP_VY` 중 하나만 2배로 하면 도달 높이가 4배나
##  절반이 되는데 에러가 안 난다」를 무는 유일한 자동 감지기다.
func apply_gravity(dt: float, gravity_px: float, max_fall_px: float) -> void:
	vy = minf(vy + gravity_px * dt, max_fall_px)


## 수평. 막히면 **스텝 오프셋**을 시도한다.
## ⚠ 막히면 나머지를 **버린다** — 안 들고 있으면 벽에 붙어 있는 동안 나머지가 쌓였다가
##  벽이 사라지는 순간 몸이 몇 px 순간이동한다.
func move_x(grid: CellGrid, dx: float) -> void:
	_rem_x += dx
	var n := roundi(_rem_x)
	_rem_x -= n
	if n == 0:
		return
	var sgn := signi(n)
	# 🔴 1px씩 민다 — 한 번에 밀고 되돌리는 방식은 두꺼운 벽에서 「어디까지 갈 수 있었나」를 잃는다.
	for _i in absi(n):
		if box_free(grid, x + sgn, y):
			x += sgn
			continue
		if not _try_step_up(grid, sgn):
			_rem_x = 0.0
			return


## 🔴 **공중에서는 안 된다.** 안 그러면 벽에 붙어 있는 동안 턱이 아니라 벽을 타고 오른다.
## ⚠ 올라갈 자리(`y - lift`)가 비어 있는지도 같이 본다 — 천장 아래 좁은 틈에서
##  머리를 박고 올라가면 몸이 지형에 끼인다.
func _try_step_up(grid: CellGrid, dx: int) -> bool:
	if not on_ground:
		return false
	for lift in range(1, step_px + 1):
		if box_free(grid, x, y - lift) and box_free(grid, x + dx, y - lift):
			x += dx
			y -= lift
			return true
	return false


## 수직. 막혔으면 true(호출부가 `vy`를 0으로 만든다).
func move_y(grid: CellGrid, dy: float) -> bool:
	_rem_y += dy
	var n := roundi(_rem_y)
	_rem_y -= n
	if n == 0:
		return false
	var sgn := signi(n)
	for _i in absi(n):
		if not box_free(grid, x, y + sgn):
			_rem_y = 0.0
			return true
		y += sgn
	return false


func grounded(grid: CellGrid) -> bool:
	return not box_free(grid, x, y + 1)


## 🔴 **「고체인가」는 격자에 물어본다**(`grid.is_solid`). 여기서 `mat_at() != EMPTY`로 다시
##  판정하면 규칙이 두 벌이 되고, 재료가 늘 때 「탄은 뚫는데 몸은 막힌다」가 된다.
## ⚠ 상자가 덮는 마지막 픽셀은 `px + w_px - 1`이다. `- 1`을 빼면 경계에 딱 붙었을 때
##  옆 칸을 한 줄 더 읽어 **벽에서 1px 떠서 멈춘다.**
## ⚠ 음수 나눗셈은 GDScript에서 0 쪽으로 잘린다(`-1 / 4 == 0`) — 격자 왼쪽·위 밖에서
##  셀 좌표가 한 칸 튄다. `floori`로 내림을 강제한다.
func box_free(grid: CellGrid, px: int, py: int) -> bool:
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cx1 := floori((px + w_px - 1) / float(Tuning.CELL_PX))
	var cy0 := floori(py / float(Tuning.CELL_PX))
	var cy1 := floori((py + h_px - 1) / float(Tuning.CELL_PX))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if grid.is_solid(cx, cy):
				return false
	return true


# ══════════════════════════════════════════════════════════════════
#  맞았나 · 불 위인가 — 🔴🔴 `monsters-minimum` 단계 3의 두 번째 추출
# ══════════════════════════════════════════════════════════════════
# `character.gd`에서 이사해 왔다. 몬스터도 같은 상자 모양이라 두 벌로 두면
# 「몬스터만 안 맞는다」가 반드시 난다 — 판정 1을 여기 다시 건다(거동 변화 0).

## 🔴🔴 **발밑 한 줄을 같이 본다. 이 한 줄이 이 기능의 목숨이다.**
##  서 있는 자리의 셀들은 **빈칸이라 연료가 0**이고, 불은 **발밑 나무 셀**에 붙어 있다.
##  ⚠ 빠뜨리면 코드는 돌고 그물도 짤 수 있는데 **게임에서만 아무 일이 안 난다.**
## 🔴 범위가 `grounded()`가 보는 줄과 같다 — 「밟고 있다」의 뜻이 두 벌이 되지 않는다.
func standing_in_fire(grid: CellGrid) -> bool:
	var cx0 := floori(x / float(Tuning.CELL_PX))
	var cx1 := floori((x + w_px - 1) / float(Tuning.CELL_PX))
	var cy0 := floori(y / float(Tuning.CELL_PX))
	var cy1 := floori((y + h_px) / float(Tuning.CELL_PX))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			# 🔴 **「타나」는 격자에 물어본다** — 여기서 깃발을 직접 까면 규칙이 두 벌이 된다.
			if grid.is_burning(cx, cy):
				return true
	return false


## 🔴🔴 **선분 대 상자다. 사각형 대 사각형이 아니다.**
##  세대 0 탄은 틱당 80px을 뛰고 상자는 20~44px이라, 틱 경계 위치만 맞대면 **도약이 상자를
##  통째로 넘을 수 있다.** 한 프레임이라 눈으로 절대 못 본다(기획 「직격은 매 틱 사각형 겹침으로
##  재면 조용히 안 걸린다」).
func hit_by_segment(spell: SpellSim) -> bool:
	var x0 := spell.get_seg_x0()
	var y0 := spell.get_seg_y0()
	var x1 := spell.get_seg_x1()
	var y1 := spell.get_seg_y1()
	for i in spell.seg_count():
		if _seg_hits_box(_fp_px(x0[i]), _fp_px(y0[i]), _fp_px(x1[i]), _fp_px(y1[i])):
			return true
	return false


## 🔴 **반경은 통지에 안 실려 있다** — 호출부가 `Tuning.blast_rd(gen)` 을 읽는다.
##  실어 보내면 같은 값이 두 곳이 되고, 표를 고치는 날 한쪽만 따라온다.
func hit_by_blast(spell: SpellSim) -> bool:
	var bx := spell.get_blast_x()
	var by := spell.get_blast_y()
	var bg := spell.get_blast_gen()
	for i in spell.blast_count():
		var r := float(Tuning.blast_rd(bg[i]) * Tuning.CELL_PX)
		if _circle_hits_box(_cell_px(bx[i]), _cell_px(by[i]), r):
			return true
	return false


## 🔴🔴 **좌표 변환은 이 함수 하나다.** 통지는 셀 고정소수점이고 몸은 px다 —
##  두 곳에서 바꾸면 한쪽만 고치는 날이 오고, 그 어긋남은 「가끔 안 맞는다」로만 보인다.
static func _fp_px(fp: int) -> float:
	return float(fp) * Tuning.CELL_PX / SpellSim.FP_ONE


## 셀 번호 → 그 셀 **한가운데**의 px. 🔴 위 함수를 지나므로 규칙이 한 벌이다.
static func _cell_px(c: int) -> float:
	return _fp_px((c << SpellSim.FP_SHIFT) + SpellSim.FP_HALF)


## 선분(a→b) 대 상자. ⚠ **시작점이 상자 안이면 참이다** — 상자 안에서 태어난 탄도 잡힌다.
func _seg_hits_box(ax: float, ay: float, bx: float, by: float) -> bool:
	var rng := Vector2(0.0, 1.0)
	rng = _slab(rng, ax, bx - ax, float(x), float(x + w_px))
	rng = _slab(rng, ay, by - ay, float(y), float(y + h_px))
	return rng.x <= rng.y


## 한 축의 슬랩. 살아 있는 구간 `(lo, hi)`를 좁혀서 돌려준다.
## 🔴 **축을 함수 하나로 묶은 이유**: 두 축을 따로 쓰면 한쪽만 고치는 날이 오고,
##  그러면 「세로로 날아오는 탄만 안 맞는다」가 된다.
## ⚠ 축과 나란한 선분(d ≈ 0)은 나눗셈이 아니라 **범위 안에 있나**로 갈린다.
static func _slab(rng: Vector2, a: float, d: float, e0: float, e1: float) -> Vector2:
	if is_zero_approx(d):
		return rng if (a >= e0 and a <= e1) else Vector2(1.0, 0.0)
	var t0 := (e0 - a) / d
	var t1 := (e1 - a) / d
	return Vector2(maxf(rng.x, minf(t0, t1)), minf(rng.y, maxf(t0, t1)))


## 원 대 상자 — 상자에서 원 중심에 **제일 가까운 점**까지의 거리로 본다.
func _circle_hits_box(cx: float, cy: float, r: float) -> bool:
	var dx := cx - clampf(cx, float(x), float(x + w_px))
	var dy := cy - clampf(cy, float(y), float(y + h_px))
	return dx * dx + dy * dy <= r * r
