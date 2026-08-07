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
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const MonsterBolts := preload("res://src/actor/monster_bolts.gd")

var id: int          # 🔴 판정 7이 이것으로 잰다. 「개수가 줄었다」로는 못 잰다(죽은 놈이 빠졌는지 안 보인다)
var kind: int
var hp: int

## 남은 무적 **틱** 수. 🔴 캐릭터의 `invuln_left`와 같은 어법 — 종류마다 다른 값은
##  `Defs.invuln_ticks(kind)`가 든다(플레이어는 상수, 몬스터는 표. 값 자체는 지금 둘 다 2틱).
var invuln_left := 0

## 🔴 닭 전용 재장전 시계(틱). 다른 종류는 안 쓴다 — 지금은 닭만 원거리라 필드 하나로
##  충분하다. 틱마다 `on_tick`이 깎는다(무적과 같은 시계 어법 — 20Hz).
var reload_left := 0

## 지금 불 위에 서 있나. 🔴 화면이 읽을 값이다(단계 7) — 매 프레임 다시 판정하므로
##  「불에서 나왔는데 계속 타 보인다」가 원리적으로 없다.
var burning := false

## 아직 1이 안 된 불 피해. `hp`를 정수로 지키는 장치다 — `character._burn_acc`와 같은 이유.
var _burn_acc := 0.0

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
	# 🔴 **다 움직인 뒤에 본다** — `character.step()`과 같은 이유(방금 떠난 자리의 불로 안 깎인다).
	_burn(grid, dt)


## 다음 한 걸음을 어디로. 🔴🔴 **단계 2 — 「플레이어 쪽으로」한 줄이다.**
##  타깃(플레이어 중심)이 내 중심보다 오른쪽이면 +1, 왼쪽이면 -1, 같으면 0.
##  ⚠ **중심 대 중심으로 잰다** — 상자 왼쪽 끝으로 재면 상자 폭만큼 조용히 치우친다
##  (닭의 사거리 판정 10이 「중심 대 중심」을 이미 정의로 못 박았다 — 여기도 같은 기준을 쓴다).
##
## 🔴🔴 **인자를 지금 넓혀 둔다. 아직 `grid`·`target_y`는 안 쓴다.** `target_x` 하나면 이 함수가
##  격자를 못 보는데, 길찾기는 지형을 읽어야 하고 활성화 거리(미정 13번)도 이 함수 안이다 ⇒
##  AI를 넣는 날 서명부터 바뀌고, 그러면 미리 뽑아 둔 값이 절반 무효가 된다.
## 🔴 닭의 「사거리에서 멈춘다」도 이 함수 안이다(단계 6) — 밖에 두면 「어디로 갈까」가 두 곳이 되고,
##  AI를 넣는 날 한쪽만 갈아끼운다 ⇒ 닭만 멍청하게 남는다.
##
## ⚠ 안 쓰는 인자가 그물을 빨갛게 만들지 않는다(실측, 2026-08-07 Godot 4.7.1 헤드리스) —
##  `@warning_ignore`를 붙이지 마라. 없어도 된다.
func _next_axis(_grid: CellGrid, target_x: int, _target_y: int) -> float:
	# 🔴🔴 **단계 6 — 닭은 사거리(`MonsterBolts.BOLT_STOP_PX`)에서 멈춘다.** 여기가 그 자리다 —
	#  밖에 두면 「어디로 갈까」가 두 곳이 되고 AI를 넣는 날 한쪽만 갈아끼운다.
	if kind == Defs.KIND_HEN and _dist_to_target(target_x) <= MonsterBolts.BOLT_STOP_PX:
		return 0.0
	var my_x := _body.center().x
	if target_x < my_x:
		return -1.0
	if target_x > my_x:
		return 1.0
	return 0.0


## 🔴 중심 대 중심 거리(px). `_next_axis`(멈춤)와 `ready_to_fire`(사격 조건)가 같은 기준을
##  써야 한다 — 두 곳에서 다르게 재면 「멈췄는데 사거리 밖이라 안 쏜다」가 조용히 난다.
func _dist_to_target(target_x: int) -> float:
	return absf(float(target_x) - _body.center().x)


## 🔴🔴 **틱에서만 돈다** — `character.on_tick`과 같은 이유(60Hz에서 부르면 한 대가 세 대가 된다).
##  입구는 `world_step.frame()`의 틱 갈래 안, `_char.on_tick` **뒤**다(문서 「동작 ⑨」).
func on_tick(spell: SpellSim) -> void:
	# 🔴 재장전은 무적과 별개 시계지만 **같은 문(틱)을 지난다** — 닭이 아니어도 그냥 0에서 안 움직인다.
	if reload_left > 0:
		reload_left -= 1
	if invuln_left > 0:
		invuln_left -= 1
		return
	if not (_body.hit_by_segment(spell) or _body.hit_by_blast(spell)):
		return
	hp = maxi(0, hp - Character.DAMAGE_HIT)
	invuln_left = Defs.invuln_ticks(kind)


## 🔴🔴 **닭이 지금 쏘고 싶은가.** `world_step`이 프레임마다 읽어 실제 탄을 만들고
##  `consume_fire()`로 재장전 시계를 되돌린다. 🔴 탄을 여기서 직접 만들지 않는다 —
##  `Monster`가 `MonsterBolts`를 만들면 몬스터가 탄을 "소유"하게 되고, 그건 이 우회로
##  전체(`monster_bolts.gd` 헤더)가 피하려던 것이다. **신호만 낸다.**
func ready_to_fire(target_x: int) -> bool:
	return kind == Defs.KIND_HEN and reload_left <= 0 \
		and _dist_to_target(target_x) <= MonsterBolts.BOLT_STOP_PX


func consume_fire() -> void:
	reload_left = MonsterBolts.RELOAD_TICKS


## 🔴🔴 **불 위에 서 있으면 깎인다 — 무적을 갱신하지도, 무적에 걸리지도 않는다**
##  (`character._burn`과 같은 계약 — 「연료를 어디 두느냐가 곧 레벨 디자인」이 몬스터에도 산다).
## 🔴 「받는 피해」·「불 DPS」는 표에 열을 안 만든다 — 플레이어 상수(`Character.DAMAGE_HIT`·
##  `Character.BURN_DPS`)를 그대로 쓴다(문서 「동작 ⑦」·「축을 안 늘린다」).
func _burn(grid: CellGrid, dt: float) -> void:
	burning = _body.standing_in_fire(grid)
	if not burning:
		return
	_burn_acc += Character.BURN_DPS * dt
	var whole := floori(_burn_acc)
	if whole <= 0:
		return
	_burn_acc -= float(whole)
	hp = maxi(0, hp - whole)
