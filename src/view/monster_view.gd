extends Node2D
## 몬스터. 🔴 화면만 만진다 — 세상은 `WorldStep`에서 **읽기만** 한다.
##
## ⚠ 보간이 없는 게 맞다 — 몬스터는 60Hz(렌더와 같은 시계)라 틱 사이가 없다
##  (`character_view.gd` 첫 줄과 같은 이유).

const WorldStep := preload("res://src/actor/world_step.gd")
const Monster := preload("res://src/actor/monster.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

var _world: WorldStep = null


func setup(world: WorldStep) -> void:
	_world = world
	queue_redraw()


## 몬스터는 매 프레임 움직인다(60Hz) — 조건 없이 매번 다시 그린다.
##  ⚠ `spell_view`의 `_drew` 걸쇠 함정(「사라진 프레임에 `queue_redraw`를 건너뛰면 죽은 것이
##  화면에 영원히 박힌다」)은 여기 없다.
func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _world == null:
		return
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		var r := box_rect(m.kind, m.x, m.y)
		# 🔴 단계 1은 색 한 종류다(`Fx.MONSTER_FILL`) — 종류별 색 표는 단계 4다.
		draw_rect(r, Fx.MONSTER_FILL)


## 🔴🔴 **순수 static이라 그물이 직접 부른다.** `_draw()`가 이 함수만 쓰므로
##  그물이 재는 값 = 실제로 그려지는 값이다(`character_view.pick_state`·`spell_view`의 「질의」절).
## 🔴 크기가 `monster_defs`(actor)에서 나온다. `fx_tuning`에 크기를 두면 상자 표가 둘이 되고,
##  증상은 「돼지가 벽에서 12px 떠 있다」 하나뿐이다(문서 「화면」 상자).
static func box_rect(kind: int, x: int, y: int) -> Rect2:
	return Rect2(x, y, Defs.w_px(kind), Defs.h_px(kind))
