extends RefCounted
## 물을 한 띠(`_BAND_ROWS`행)에 N틱에 걸쳐 조금씩 붓는다 — "비처럼". `RefCounted`라 씬 트리를 모른다.
## 🔴 **한 행이 아니다** — 낙하 상한(`WATER_FALL_CELLS × WATER_SUBSTEPS`)만큼의 띠다.
##  이유는 `tick()` 헤더에 있다(화면 줄무늬).
##
## 🔴🔴 **왜 `src/sim/`인가, `stage.gd` 가 아닌가**: 이 기능의 제일 큰 위험(판정 6, 「물이
##  제 속도로 오나」)은 값으로만 재진다. 상태를 껍데기 안에 두면 그물이 씬을 못 세워서
##  **붓기를 그물 안에 다시 구현해서** 재게 되고, 그러면 재는 코드와 출하되는 코드가 갈린다
##  (`docs/plans/2.active/water-jump-and-escape.md` 「어디에 두나」).
##  ⇒ **부르는 쪽(`stage.gd`)은 「언제 시작하나」·「매 틱 부른다」만 안다.** 셈은 여기가 전부 든다.
##
## ⚠ **`cell_grid.step()` 안에 넣지 않는다** — 넣으면 이 리포의 39개 그물이 부르는 `step()`의
##  뜻이 전부 바뀐다. 이 소스는 **부르는 쪽이 스스로 `tick()` 을 부르는 것**으로 격자와 분리된다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

var _x0: int
var _x1: int
var _row: int
var _per_tick: int

## 🔴 **소스가 스스로 센 「실제로 들어간 양」이다** — 부으려던 양이 아니다.
##  벽에 거절된 칸(`set_water`가 `false`)과 `WATER_MAX`에 막혀 못 들어간 몫은 안 든다.
##  ⇒ 이 값과 격자의 물 총량을 맞대는 것이 그물 B-1(보존)의 유일한 방법이다.
var _poured := 0


func _init(x0: int, x1: int, row: int, per_tick: int) -> void:
	_x0 = x0
	_x1 = x1
	_row = row
	_per_tick = per_tick


## 🔴🔴 **한 행이 아니라 `WATER_FALL_CELLS × WATER_SUBSTEPS`행짜리 띠에 붓는다** (2026-08-08,
##  화면에서 발견됐다 — 아래 「왜 한 행이 아닌가」).
##
## 🔴 **하드코딩하지 않는다 — 낙하 상한에서 파생시킨다.** K(`WATER_FALL_CELLS`)를 바꾸면
##  이 띠의 높이도 저절로 같이 바뀐다. 둘이 따로 놀면 다음에 또 줄무늬가 난다.
const _BAND_ROWS := Tuning.WATER_FALL_CELLS * Tuning.WATER_SUBSTEPS

## 한 틱에 정확히 한 번, 정확히 `_row .. _row + _BAND_ROWS - 1` 띠에만 붓는다.
##
## 🔴🔴 **왜 한 행이 아닌가 — 화면에서 가로 줄무늬가 났었다**(verify-look, 2026-08-08).
##  낙하가 한 틱에 `K × 서브스텝`(=`_BAND_ROWS`)칸을 옮기는데 붓기는 한 행만 채우니,
##  그 행이 다음 틱에 통째로 아래로 내려가고 **위는 완전히 빈 채로 한 틱을 보낸다** —
##  12칸(48px) 간격의 빈 줄이 정확히 그 값과 일치했다.
##  ⇒ **`_BAND_ROWS`행 띠를 매 틱 다시 채우면, 그 띠가 통째로 12칸 내려가는 순간 새 띠가
##  바로 그 자리를 메운다** — 빈틈이 원리적으로 0이 된다(`net_water._rain_leaves_no_gaps`가 잰다).
##
## 🔴🔴 **`stage.gd` 의 `_on_ticked()` 안에서만 불러라 — `_physics_process` 가 아니다.**
##  물리 프레임마다 부르면 `TICK_DIVIDER`(3)배 빨리 붓게 되고, **에러가 안 난다** —
##  화면에서는 「생각보다 빨리 찬다」로만 보인다(그물 B-2가 이 계약을 값으로 잰다).
##
## 🔴🔴 **덮어쓰기가 아니라 더하기다.** `set_water` 는 그 자리를 통째로 새 값으로 만든다 —
##  그냥 `set_water(x, y, per_cell)` 을 매 틱 부르면 이전 틱에 쌓인 물이 조용히 사라진다.
##  ⇒ **읽고(`aux_at`) 더해서(`mini(WATER_MAX, ...)`) 쓴다.**
## ⚠ **벽은 알아서 거절된다** — `set_water` 가 `EMPTY`·`WATER` 가 아닌 칸에는 `false` 를 돌려주므로
##  거절된 칸은 `before`/`after` 를 안 재고 `_poured` 에도 안 든다. **`_BAND_ROWS`행이 지형을 뚫고
##  나가도 같다** — 그 행들은 그냥 거절되고 총량이 그만큼 덜 들어간다(안 샌다, `_poured`가 증거다).
##
## ⚠ **칸당 양이 옛 방식의 `1/_BAND_ROWS`로 준다**(폭×`_BAND_ROWS`칸에 나누므로). 지금 값(K=4·
##  서브스텝=3 ⇒ 12행)에서 칸당 양이 `WATER_WET`(32) 아래로 떨어질 수 있다 — 얕은 물 색으로
##  칠해진다는 뜻이다. **화면에서 어떻게 보이는지는 안 재고 열어 둔다**(verify-look의 몫).
func tick(grid: CellGrid) -> void:
	var width := _x1 - _x0 + 1
	if width <= 0:
		return
	var per_cell := _per_tick / (width * _BAND_ROWS)
	if per_cell <= 0:
		return
	for y in range(_row, _row + _BAND_ROWS):
		for x in range(_x0, _x1 + 1):
			var before := grid.aux_at(x, y)
			var after := mini(Tuning.WATER_MAX, before + per_cell)
			if grid.set_water(x, y, after):
				_poured += after - before


## 이 소스가 지금까지 실제로 부어 넣은 양의 누적.
func poured() -> int:
	return _poured
