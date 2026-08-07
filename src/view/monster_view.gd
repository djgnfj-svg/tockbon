extends Node2D
## 몬스터 · 닭의 탄 · 죽은 자리. 🔴 화면만 만진다 — 세상은 `WorldStep`에서 **읽기만** 한다.
##
## ⚠ 보간이 없는 게 맞다 — 몬스터는 60Hz(렌더와 같은 시계)라 틱 사이가 없다
##  (`character_view.gd` 첫 줄과 같은 이유).
##
## 🔴🔴 **죽음 통지(`world.died_*`)는 그 틱 안에서만 유효하다**(다음 틱이 지운다 — 폭발 통지와
##  같은 계약, `world_step.gd` 헤더). ⇒ **시체는 `_process()`가 아니라 `on_tick()`에서 붙잡는다**
##  (`blast_fx.on_blasts()`와 같은 문 — `stage.gd`의 `_on_ticked()`가 부른다).
##  ⚠ 안 그러면 통지가 다음 틱에 지워진 뒤에야 읽어서 시체가 원리적으로 안 생긴다.
##
## 🔴🔴 **번쩍·피해 숫자는 액터에 새 통지를 안 만든다 — 뷰가 hp를 프레임마다 관찰해서 만든다.**
##  hp는 이미 공개 필드이고 **id는 절대 재사용되지 않으므로**(`world_step._next_monster_id` 주석)
##  **id로 키를 잡으면 diff가 안전하다** — `character_view._prev_x`(직전 프레임과 비교)와 같은
##  어법이다. ⚠ **id 목록으로 "누가 죽었나"를 diff하는 것과는 다르다** — 그건 `world_step`이
##  통지 배열로 이미 풀어 준 문제이고(위 「동작 ⑩」의 함정), 여기서 diff하는 것은 "살아 있는
##  같은 id의 hp가 줄었나" 하나뿐이라 재사용·순간이동 함정이 안 걸린다.
## ⚠ **못 잡는 자리 하나**: 죽는 바로 그 틱의 마지막 피해는 몬스터가 배열에서 이미 빠진 뒤라
##  이 diff가 못 본다 — 그 프레임엔 번쩍·숫자 없이 시체만 나타난다. 확신 없는 곳(아래 보고).

const WorldStep := preload("res://src/actor/world_step.gd")
const Monster := preload("res://src/actor/monster.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

var _world: WorldStep = null

## id → 직전 프레임 hp. `_scan_hp_changes()`가 채우고 지운다(위 헤더).
var _prev_hp: Dictionary = {}
## id → 남은 번쩍 프레임 수.
var _flash_left: Dictionary = {}

## 피해 숫자 · 시체 — **독립 개체다**(몬스터가 사라져도 얼마간 화면에 남는다).
##  `blast_fx._flashes`와 같은 어법: `Array[Dictionary]` + 나이(age, 프레임).
var _dmg_numbers: Array[Dictionary] = []
var _corpses: Array[Dictionary] = []


func setup(world: WorldStep) -> void:
	_world = world
	queue_redraw()


func _process(_dt: float) -> void:
	advance()
	queue_redraw()


## 한 프레임분 갱신 — hp 변화를 읽어 번쩍·피해 숫자를 만들고, 살아 있는 연출들의 나이를 먹인다.
## 🔴 `_process`가 부르는 것과 **같은 함수다**(`blast_fx.advance()`와 같은 어법) — 그물이 씬 없이
##  프레임을 흘려보낼 수 있게 공개다.
##
## 🔴🔴 **나이를 먹이는 것이 먼저고, hp를 읽는 것이 나중이다.** 순서를 바꾸면 이번 프레임에
##  막 생긴 번쩍·피해 숫자가 **같은 호출 안에서** 한 프레임어치를 먼저 잃는다 — 실측으로
##  `MONSTER_FLASH_FRAMES`(6)짜리 번쩍이 5프레임 뒤에 벌써 꺼지는 것으로 걸렸다(net 실패).
func advance() -> void:
	_decay_flashes()
	_prune(_dmg_numbers, Fx.MONSTER_DMG_NUM_LIFE_FRAMES)
	_prune(_corpses, Fx.MONSTER_CORPSE_LIFE_FRAMES)
	if _world != null:
		_scan_hp_changes()


## 🔴🔴 **죽음 통지를 여기서만 읽는다.** `stage.gd`의 `_on_ticked()`가 부른다 — 프레임마다
##  부르면 통지가 다음 `frame()`의 틱 갈래까지 살아 있어서 시체가 여러 번 생긴다
##  (`world_step.frame()`의 「한 대가 세 대가 된다」 함정과 같은 자리).
func on_tick() -> void:
	if _world == null:
		return
	for i in _world.died_count():
		_corpses.append({
			"x": _world.died_x(i), "y": _world.died_y(i), "kind": _world.died_kind(i), "age": 0,
		})


## hp가 준 몬스터마다 번쩍·피해 숫자를 띄운다. id로 diff한다(위 헤더).
func _scan_hp_changes() -> void:
	var seen: Dictionary = {}
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		seen[m.id] = true
		if _prev_hp.has(m.id):
			var prev: int = _prev_hp[m.id]
			if m.hp < prev:
				_flash_left[m.id] = Fx.MONSTER_FLASH_FRAMES
				_dmg_numbers.append({
					"x": m.center().x, "y": float(m.y), "amount": prev - m.hp, "age": 0,
				})
		_prev_hp[m.id] = m.hp
	# 더 안 사는 id는 정리한다 — 안 지우면 죽은 id가 사전에 무한히 쌓인다(20마리 상한은
	#  살아 있는 몬스터에만 걸리고, 이 사전은 그 상한 밖이다).
	for id in _prev_hp.keys().duplicate():
		if not seen.has(id):
			_prev_hp.erase(id)
			_flash_left.erase(id)


func _decay_flashes() -> void:
	for id in _flash_left.keys().duplicate():
		var left := int(_flash_left[id]) - 1
		if left <= 0:
			_flash_left.erase(id)
		else:
			_flash_left[id] = left


func _prune(list: Array[Dictionary], max_age: int) -> void:
	var i := list.size() - 1
	while i >= 0:
		var age := int(list[i]["age"]) + 1
		if age >= max_age:
			list.remove_at(i)
		else:
			list[i]["age"] = age
		i -= 1


## 무대 리셋(R)이 부른다. `spell_view.clear()`·`blast_fx.clear()`와 같은 문이다 —
##  안 비우면 R 뒤에도 옛 세션의 죽은 id가 사전에 남고, 새 세션의 시체·숫자가 안 섞이는 대신
##  옛 흔적이 화면에 잠깐 얹힐 수 있다(안전을 위해 그냥 비운다).
func clear() -> void:
	_prev_hp.clear()
	_flash_left.clear()
	_dmg_numbers.clear()
	_corpses.clear()
	queue_redraw()


# ══════════════════════════════════════════════════════════════════
#  질의 — 그물이 여기서만 읽는다(`blast_fx`의 「질의」 절과 같은 어법)
# ══════════════════════════════════════════════════════════════════

func corpse_count() -> int:
	return _corpses.size()


func corpse_kind(i: int) -> int:
	return _corpses[i]["kind"]


func is_flashing(id: int) -> bool:
	return _flash_left.has(id)


func dmg_number_count() -> int:
	return _dmg_numbers.size()


func dmg_number_amount(i: int) -> int:
	return _dmg_numbers[i]["amount"]


# ══════════════════════════════════════════════════════════════════
#  그리기
# ══════════════════════════════════════════════════════════════════

func _draw() -> void:
	if _world == null:
		return
	# 🔴 시체가 산 몬스터보다 먼저 그려진다 — 산 몬스터(같은 자리에 새로 선 것)가 시체를
	#  덮어야 「사라졌다」가 자연스럽다. 겹칠 일은 드물지만(다음 스폰이 같은 자리일 때) 순서는
	#  씬 자식 순서(지형 위 · 캐릭터 아래)와 같은 규칙 — 먼저 그린 것이 아래다.
	for c: Dictionary in _corpses:
		_draw_corpse(c)
	for i in _world.monster_count():
		_draw_monster(_world.monster_at(i))
	# 🔴 닭의 탄. `MonsterBolts`가 방향을 안 넘겨서(공개 API가 `x(i)`·`y(i)`뿐이다) 점으로
	#  그린다 — 판정 13의 요구(「작은 점/짧은 선」)를 점으로 채운다.
	for i in _world.bolt_count():
		draw_circle(Vector2(_world.bolt_x(i), _world.bolt_y(i)), Fx.MONSTER_BOLT_R_PX, Fx.MONSTER_BOLT_COLOR)
	for n: Dictionary in _dmg_numbers:
		_draw_dmg_number(n)


func _draw_monster(m: Monster) -> void:
	var r := box_rect(m.kind, m.x, m.y)
	draw_rect(r, Fx.MONSTER_FILL)
	if _flash_left.has(m.id):
		var frac := float(_flash_left[m.id]) / float(Fx.MONSTER_FLASH_FRAMES)
		var c := Fx.MONSTER_FLASH_COLOR
		draw_rect(r, Color(c.r, c.g, c.b, c.a * frac))
	# 🔴 테두리라 번쩍과 겹쳐도 둘 다 보인다 — `character_view`의 「불은 무적 흐림과 겹쳐도
	#  둘 다 보인다」와 같은 이유(불은 무적에 안 걸린다, `monster.gd._burn`).
	if m.burning:
		draw_rect(r, Fx.CHAR_BURN, false, Fx.CHAR_BURN_PX)
	_draw_hp_bar(m.kind, m.x, m.y, m.hp)


func _draw_hp_bar(kind: int, x: int, y: int, hp: int) -> void:
	var bar := hp_bar_rect(kind, x, y)
	draw_rect(bar, Fx.MONSTER_HP_BAR_BG)
	var frac := hp_bar_fill_frac(hp, Defs.max_hp(kind))
	if frac <= 0.0:
		return
	var fill := Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y))
	draw_rect(fill, Fx.MONSTER_HP_BAR_FULL.lerp(Fx.MONSTER_HP_BAR_EMPTY, 1.0 - frac))


func _draw_corpse(c: Dictionary) -> void:
	var kind: int = c["kind"]
	var r := box_rect(kind, c["x"], c["y"])
	var age: int = c["age"]
	var alpha := 1.0 - float(age) / float(Fx.MONSTER_CORPSE_LIFE_FRAMES)
	var col := Fx.MONSTER_CORPSE_COLOR
	draw_rect(r, Color(col.r, col.g, col.b, col.a * alpha))


func _draw_dmg_number(n: Dictionary) -> void:
	# ⚠ 폰트가 없으면 그리지 않는다 — `null`을 넘기면 매 프레임 짖고, 래퍼가 stderr를
	#  실패로 치니 평소 화면이 그물을 빨갛게 만든다(`circle_window._draw`와 같은 규율).
	# 🔴 **`get_theme_default_font()`가 아니다** — 이 노드는 `Node2D`라 `Control`이 아니고
	#  그 함수가 없다(`circle_window`는 `Control`이라 쓸 수 있었다). `Node2D`에서 기본 폰트를
	#  얻는 길은 `ThemeDB`뿐이다.
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var age: int = n["age"]
	var t := float(age) / float(Fx.MONSTER_DMG_NUM_LIFE_FRAMES)
	var alpha := 1.0 - t
	var y := float(n["y"]) - Fx.MONSTER_DMG_NUM_RISE_PX * t
	var col := Fx.MONSTER_DMG_NUM_COLOR
	var text := "-%d" % int(n["amount"])
	# 가운데 정렬 — `circle_window`류는 전부 LEFT라 폭을 직접 재서 절반만큼 왼쪽으로 민다.
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.MONSTER_DMG_NUM_SIZE).x
	draw_string(font, Vector2(float(n["x"]) - w * 0.5, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.MONSTER_DMG_NUM_SIZE,
		Color(col.r, col.g, col.b, col.a * alpha))


# ══════════════════════════════════════════════════════════════════
#  순수 static — 그물이 직접 부른다(`character_view.pick_state`와 같은 어법)
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **순수 static이라 그물이 직접 부른다.** `_draw()`가 이 함수만 쓰므로
##  그물이 재는 값 = 실제로 그려지는 값이다(`character_view.pick_state`·`spell_view`의 「질의」절).
## 🔴 크기가 `monster_defs`(actor)에서 나온다. `fx_tuning`에 크기를 두면 상자 표가 둘이 되고,
##  증상은 「돼지가 벽에서 12px 떠 있다」 하나뿐이다(문서 「화면」 상자).
static func box_rect(kind: int, x: int, y: int) -> Rect2:
	return Rect2(x, y, Defs.w_px(kind), Defs.h_px(kind))


## 🔴 체력바 자리 — 상자 폭에서 나온다(위 상자와 같은 이유로 여기서 폭을 다시 안 만든다).
static func hp_bar_rect(kind: int, x: int, y: int) -> Rect2:
	return Rect2(float(x), float(y) - Fx.MONSTER_HP_BAR_GAP_PX - Fx.MONSTER_HP_BAR_H_PX,
		float(Defs.w_px(kind)), Fx.MONSTER_HP_BAR_H_PX)


## 체력바가 채워진 비율. 0~1로 죈다 — 음수 hp는 `Monster.on_tick`이 이미 `maxi(0, …)`로
##  막지만(문서 「hp를 깎는 문은 하나다」), 화면 쪽에서 한 번 더 죄어 두면 표를 잘못 읽어도
##  체력바가 상자 밖으로 안 나간다.
static func hp_bar_fill_frac(hp: int, max_hp: int) -> float:
	if max_hp <= 0:
		return 0.0
	return clampf(float(hp) / float(max_hp), 0.0, 1.0)
