extends RefCounted
## 닭의 탄 — 단순 투사체. 🔴🔴 **`spell_sim`이 아니다** — `docs/design/몬스터.md`가 정한
##  우회로다(`monsters-minimum` 「동작 ⑤」): 이 리포의 시뮬은 "누가 쐈나"를 모른다 ⇒
##  그대로 두면 닭이 쏜 탄이 닭을 때린다.
##
## 🔴🔴 **"플레이어만 때린다"는 몬스터 목록을 아예 안 보는 것으로 구현한다.** 몬스터
##  목록을 돌면서 "쏜 놈이면 건너뛴다"로 짜면 탄이 소유자를 들어야 하고, 그건 이
##  우회로가 피하려던 바로 그것이다 — **탄은 몬스터라는 것을 모른다.**
##
## | 성질 | 값 |
## |---|---|
## | 어디로 | 직선. 중력 없다 |
## | 누굴 때리나 | 플레이어만 |
## | 지형 | 고체 셀에 닿으면 사라진다. **지형을 안 판다** |
##
## 🔴🔴 **`BOLT_STOP_PX`(멈추는 거리)와 `BOLT_RANGE_PX`(탄 수명)는 다른 상수다 — 축이 둘이다.**
##  같은 값으로 겸하면 물러나는 플레이어에게 원리적으로 절대 안 맞는다:
##  ```
##  닭이 240px에서 쏜다 → 플레이어가 260px/s로 물러난다
##  탄 320px/s − 플레이어 260px/s = 상대 접근 60px/s
##  240px을 메우려면 4초 = 탄이 1,280px을 날아야 한다
##  그런데 수명이 240px이면 0.75초에 죽는다 ⇒ 원리적으로 절대 안 맞는다
##  ```
##  ⇒ 480(= 2배)이면 240 → 150px까지만 좁혀 안 닿는다 — **뒤로 물러나는 것은 진행을 포기하는
##  값을 치른다**(GDD 「진행 방향」). 멈추거나 옆으로 걷거나 다가가면 맞는다.
##
## 🔴🔴 **모든 값이 제안이다. 사용자 판정을 안 받았다** — `monsters-minimum` 「동작 ⑧」·
##  「미정 1번」에 근거가 한 줄씩 있다. 화면에서 사용자가 정할 자리다.
## ⚠ **닭(220px/s)이 플레이어(260px/s)보다 느리다** — 뒤로 걷기만 하면 영영 안 맞는다.
##  탄 수명을 아무리 늘려도 안 풀린다(미정 5번, 이 문서가 안 닫는다).

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")

## 닭이 **멈추는** 거리(px, 중심 대 중심). 보이는 폭 960px의 1/4 — 닭과 플레이어가
##  한 화면에 같이 들어온다.
const BOLT_STOP_PX := 240.0
## 탄이 **사는** 거리(px) — `BOLT_STOP_PX`의 2배. 반드시 다른 상수다(위 상자).
const BOLT_RANGE_PX := 480.0
## 탄 속도(px/s). 플레이어(260px/s)보다 살짝 빠르다 — 느리면 걸어서 피해져 위협이 아니고,
##  마법 탄(1,600px/s)만큼이면 보고 못 피한다.
const BOLT_SPEED_PX := 320.0
## 재장전(틱, 20Hz) = 2초. 20마리 중 절반이 닭이면 초당 5발 — 화면 예산이다.
const RELOAD_TICKS := 40
## 피해. 플레이어 100HP·기준 마법 피해 10의 절반. 무적 0.2초를 타므로 여러 닭이 동시에
##  쏴도 한 대다.
const BOLT_DAMAGE := 5
## 동시에 살 수 있는 탄 수(안전망). 🔴 **상한을 넘으면 안 쏜다. 탄을 버리지 않는다** —
##  버리면 「몰아 쏘면 몇 발이 안 나간다」가 되고 그건 고장으로 읽힌다.
const MAX_BOLTS := 32

## 평행 배열. 🔴 셀 격자와 달리 액터 층이라 float — 몬스터·캐릭터와 같은 계약이다.
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _dx := PackedFloat32Array()
var _dy := PackedFloat32Array()
var _traveled := PackedFloat32Array()


func count() -> int:
	return _x.size()


func x(i: int) -> float:
	return _x[i]


func y(i: int) -> float:
	return _y[i]


## `dir`은 단위 벡터로 받는다 — 여기서 정규화하지 않는다(호출부가 이미 했다).
## 🔴 상한을 넘으면 **안 쏜다.** 이미 나는 탄을 버리지 않는다.
func spawn(ox: float, oy: float, dir: Vector2) -> bool:
	if _x.size() >= MAX_BOLTS:
		return false
	if dir.length_squared() <= 0.0:
		return false
	_x.append(ox)
	_y.append(oy)
	_dx.append(dir.x)
	_dy.append(dir.y)
	_traveled.append(0.0)
	return true


## 🔴🔴 **프레임(60Hz)마다 한 걸음 — 터널링을 원리적으로 없앤다.** 320px/s ÷ 60 = 5.3px/프레임이고
##  플레이어 상자의 짧은 변이 20px이다 ⇒ 못 넘는다. ⚠ **상대 속도로 재야 진짜 한계다**
##  (`net_monster_bolts`가 그 부등식을 숫자로 잰다) — 탄 속도만 보면 이 여유를 과대평가한다.
##
## 지형에 닿거나 수명이 다하면 사라진다. **지형을 안 판다** — 격자에 커맨드를 안 보낸다.
func step(grid: CellGrid, dt: float) -> void:
	var step_px := BOLT_SPEED_PX * dt
	var i := _x.size() - 1
	while i >= 0:
		_x[i] += _dx[i] * step_px
		_y[i] += _dy[i] * step_px
		_traveled[i] += step_px
		var cx := floori(_x[i] / float(Tuning.CELL_PX))
		var cy := floori(_y[i] / float(Tuning.CELL_PX))
		if _traveled[i] >= BOLT_RANGE_PX or grid.is_solid(cx, cy):
			_remove_at(i)
		i -= 1


## 플레이어 상자와 겹치는 탄을 지운다(맞았든 무적에 막혔든 — 몸에 닿으면 사라진다).
## 🔴 겹치는 탄이 여럿이어도 **`take_hit`이 무적 하나로 「하나라도 맞으면 끝」을 지킨다** —
##  여기서는 겹치는 탄을 전부 지우고, 실제 피해 판정(무적 검사)은 호출부(`world_step`)가 한다.
## 돌려주는 값: 겹친 탄이 있었나(피해를 시도해야 하는지).
func consume_hits(ch: Character) -> bool:
	var lo_x := float(ch.x)
	var hi_x := float(ch.x + Character.W_PX)
	var lo_y := float(ch.y)
	var hi_y := float(ch.y + Character.H_PX)
	var hit := false
	var i := _x.size() - 1
	while i >= 0:
		if _x[i] >= lo_x and _x[i] <= hi_x and _y[i] >= lo_y and _y[i] <= hi_y:
			hit = true
			_remove_at(i)
		i -= 1
	return hit


func _remove_at(i: int) -> void:
	_x.remove_at(i)
	_y.remove_at(i)
	_dx.remove_at(i)
	_dy.remove_at(i)
	_traveled.remove_at(i)
