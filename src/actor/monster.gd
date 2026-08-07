extends RefCounted
## 몬스터 한 마리 — `Body`를 쓰고 체력·종류·id를 든다. 격자를 **읽기만** 한다.
##
## 🔴🔴 **`_next_axis()`가 「다음 한 걸음을 어디로」를 답하는 유일한 자리다**
##  (`docs/design/몬스터.md`가 미리 요구한 함수). AI가 오면 이 함수만 갈아 끼운다 —
##  여기 말고 다른 곳에 「플레이어 쪽으로」가 나오면 안 된다.
##
## ⚠ `src/actor/`라 float을 써도 되고 씬 트리는 모른다(GDD 멀티 표 — 몬스터는 호스트 권위).

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Body := preload("res://src/actor/body.gd")
const Character := preload("res://src/actor/character.gd")
const Defs := preload("res://src/actor/monster_defs.gd")

var id: int          # 🔴 판정 7이 이것으로 잰다. 「개수가 줄었다」로는 못 잰다(죽은 놈이 빠졌는지 안 보인다)
var kind: int
var hp: int

## x·y·on_ground는 캐릭터와 같은 어법 — **프로퍼티로 `_body`를 넘긴다**(뷰가 `m.x`로 읽는다).
var _body: Body


func _init(monster_id: int, monster_kind: int, px: int, py: int) -> void:
	id = monster_id
	kind = monster_kind
	hp = Defs.max_hp(kind)
	_body = Body.new(Defs.w_px(kind), Defs.h_px(kind), Defs.step_cells(kind))
	_body.place(px, py)


var x: int:
	get: return _body.x
var y: int:
	get: return _body.y
var on_ground: bool:
	get: return _body.on_ground


func center() -> Vector2:
	return _body.center()


## 🔴🔴 **다섯 줄, 순서가 계약이다**(`monsters-minimum` 단계 1). 접지를 먼저 갱신한 뒤에
##  `_next_axis()`를 부른다 — 사거리에서 멈추는 판단이 그 값을 쓰게 될 날을 위해서다.
##
## 🔴 중력은 `Character.GRAVITY_PX`·`MAX_FALL_PX`에서 그대로 읽는다 — 「받는 피해」·「불 DPS」와
##  같은 자리다(축을 안 늘린다). 몬스터용 중력 열을 만들면 미정이 두 곳으로 는다.
##  ⚠ 귀결: 돼지도 닭도 플레이어와 낙하 곡선이 같다. 큰 놈이 무겁게 안 떨어진다.
func step(grid: CellGrid, dt: float, target_x: int, target_y: int) -> void:
	_body.on_ground = _body.grounded(grid)
	var axis := _next_axis(grid, target_x, target_y)
	_body.apply_gravity(dt, Character.GRAVITY_PX, Character.MAX_FALL_PX)
	_body.move_x(grid, axis * Defs.speed_px(kind) * dt)
	if _body.move_y(grid, _body.vy * dt):
		_body.vy = 0.0
	_body.on_ground = _body.grounded(grid)


## 다음 한 걸음을 어디로. 🔴 지금은 한 줄이다. AI가 오면 이 함수만 갈아끼운다.
##
## 🔴🔴 **인자를 지금 넓혀 둔다. 지금은 안 쓴다.** `target_x` 하나면 이 함수가 격자를 못 보는데,
##  길찾기는 지형을 읽어야 하고 활성화 거리(미정 13번)도 이 함수 안이다 ⇒ AI를 넣는 날
##  서명부터 바뀌고, 그러면 미리 뽑아 둔 값이 절반 무효가 된다.
## 🔴 닭의 「사거리에서 멈춘다」도 이 함수 안이다(단계 6) — 밖에 두면 「어디로 갈까」가 두 곳이 되고,
##  AI를 넣는 날 한쪽만 갈아끼운다 ⇒ 닭만 멍청하게 남는다.
##
## ⚠ 안 쓰는 인자가 그물을 빨갛게 만들지 않는다(실측, 2026-08-07 Godot 4.7.1 헤드리스) —
##  `@warning_ignore`를 붙이지 마라. 없어도 된다.
func _next_axis(_grid: CellGrid, _target_x: int, _target_y: int) -> float:
	return 0.0
