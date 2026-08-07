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
## 🔴 **`CELL_PX` 하나 때문에 든다** — 몸에 붙은 불을 셀 격자에 스냅해야 땅불과 어휘가 같아진다
##  (`_draw_body_flames` 상자). ⚠ 시뮬 상수를 뷰가 읽는 것은 여기서만이다.
const Tuning := preload("res://src/sim/sim_tuning.gd")

## 🔴 셰이더가 받는 이름. **상수로 둔다** — 문자열을 박으면 한 글자 틀렸을 때
##  **아무 일도 안 일어나고 에러도 없다**(`net_render` 의 「거짓 손잡이」 절이 그 사연이다).
const FLASH_COLOR_PARAM := "flash_color"

## 🔴🔴 **레이어 이름 — 그물이 이것으로 찾는다. 자식 인덱스로 찾지 마라.**
##  ⚠ **실측(2026-08-08)**: 그물이 `get_child(0)` 으로 번쩍 레이어를 잡고 있었는데
##   외곽선 레이어를 앞에 넣자 **조용히 엉뚱한 노드를 재기 시작했다.**
##   ⇒ 순서는 그리기 계약이지 **이름표가 아니다.** 레이어가 늘 때마다 그물이 깨지면 안 된다.
const LAYER_OUTLINE := "Outline"
const LAYER_FLASH := "Flash"
const LAYER_NUMBER := "Number"

var _world: WorldStep = null

## id → 직전 프레임 hp. `_scan_hp_changes()`가 채우고 지운다(위 헤더).
var _prev_hp: Dictionary = {}
## id → 남은 번쩍 프레임 수.
var _flash_left: Dictionary = {}

## 피해 숫자 · 시체 — **독립 개체다**(몬스터가 사라져도 얼마간 화면에 남는다).
##  `blast_fx._flashes`와 같은 어법: `Array[Dictionary]` + 나이(age, 프레임).
var _dmg_numbers: Array[Dictionary] = []
var _corpses: Array[Dictionary] = []
## 죽는 순간 터지는 고리. 🔴 **시체와 같은 통지에서 같이 생기지만 수명이 다르다**(더 짧다) —
##  그래서 한 배열에 못 담는다(`_prune` 이 배열 단위로 수명을 받는다).
var _death_pops: Array[Dictionary] = []

## 종류 → 몸 그림. 🔴 `Defs.ALL`에서 만든다 — 종류를 늘리면(`monster_defs.gd` 한 줄 +
##  `fx_tuning.MONSTER_SHEETS` 한 줄) 여기는 안 건드려도 된다.
## ⚠ **`null` 검사를 안 붙인다 — 대신 `.get()`으로 읽는 쪽이 대체한다**(`_draw_monster_body`).
##  `character_view._body_tex`와 다른 규율이다: 캐릭터는 하나뿐이라 깨지면 그냥 짖어도 되지만,
##  몬스터는 종류가 늘 여럿이라 하나가 깨져도 나머지 종류는 마저 보여야 한다(위 `MONSTER_FILL` 상자).
var _sheets: Dictionary = _load_sheets()

## 프레임 계수기 — 몸에 붙은 불의 흔들림 시계다.
## 🔴 **`Time.` 을 안 쓴다.** 여기는 `src/view/` 라 결정론 계약 밖이지만, 프레임 계수기면
##  그물이 `advance()` 를 N번 불러 **같은 그림을 재현할 수 있다**(벽시계는 못 그런다).
var _frame: int = 0

## 🔴🔴 **번쩍 전용 자식 노드.** 셰이더 머티리얼이 **노드 단위**라 여기 그리는 것 전부가
##  흰 실루엣이 된다 ⇒ **몸과 같은 노드에 못 둔다.**
##  ⚠ 자식이라 부모보다 **나중에** 그려진다 = 몸 위에 얹힌다. 그게 필요한 순서다.
var _flash_layer: Node2D = null
## 🔴 피해 숫자는 번쩍보다도 위다 — 안 그러면 번쩍이 숫자를 덮는다(둘 다 흰 계열이라 최악이다).
var _number_layer: Node2D = null
## 🔴🔴 **외곽선은 몸 「아래」다 — 자식인데 `show_behind_parent` 로 뒤로 보낸다.**
##  ⚠ 자식은 기본이 부모보다 위인데 외곽선이 몸을 덮으면 **실루엣이 통째로 크림색이 된다.**
##  🔴 번쩍과 **같은 셰이더에 다른 색**을 건다 — 색이 노드 단위 uniform 이라 노드를 나눠야 한다.
var _outline_layer: Node2D = null


## 자식 노드에 그리기를 위임하는 껍데기. 🔴 **자식마다 스크립트 파일을 만들지 않으려는 것**이다 —
##  파일이 늘면 「이 노드는 뭘 하나」가 세 곳으로 흩어진다.
##
## 🔴🔴 **`fn.call(self)` 다 — 자기를 넘긴다. 이게 이 클래스의 존재 이유의 절반이다.**
##  ⚠ **인자 없이 부르던 때 실제 버그가 났다**(2026-08-08): 위임받은 함수가
##   **암묵적 `self`(= 부모 MonsterView)** 에 그렸고, 부모는 그리는 중이 아니라
##   **그 명령이 조용히 버려졌다.** 피해 숫자가 화면에서 통째로 사라졌는데 **에러도 없고
##   그물도 전부 초록**이었다(그물은 배열을 읽지 캔버스를 안 읽는다).
##  ⇒ 캔버스를 인자로 강제하면 **받는 쪽이 그것을 안 쓰는 것이 눈에 보인다.**
class _Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


## 🔴 static — `_init`이 돌기 전에도 그물이 값을 검증할 수 있게(`net_monster_sprite`).
static func _load_sheets() -> Dictionary:
	var out: Dictionary = {}
	for kind: int in Defs.ALL:
		out[kind] = load(Fx.MONSTER_SHEETS[kind]) as Texture2D
	return out


## 🔴🔴 **레이어를 여기서 만든다 — 씬 파일에 안 넣는다.**
##  ⚠ 그물이 이 노드를 씬 없이 `new()` 로 세워 `advance()` 만 흘리는 일이 있고(공개 함수인 이유),
##   그때 `_ready` 가 안 돌아 레이어가 **null 인 채로 산다.** ⇒ **그리는 쪽이 null 을 견뎌야 한다.**
##  🔴 씬 파일에 박으면 그 두 세계가 갈라지고, 갈라진 증상은 **화면에만** 나온다.
func _ready() -> void:
	var sh := load(Fx.MONSTER_FLASH_SHADER) as Shader
	# 🔴 **외곽선을 먼저 만든다** — 자식 순서가 곧 그리기 순서이고, 이것만 `show_behind_parent` 다.
	_outline_layer = _make_layer(_draw_outlines, LAYER_OUTLINE)
	_outline_layer.show_behind_parent = true
	_paint(_outline_layer, sh, Fx.MONSTER_OUTLINE_COLOR)
	_flash_layer = _make_layer(_draw_flashes, LAYER_FLASH)
	_paint(_flash_layer, sh, Fx.MONSTER_FLASH_COLOR)
	# ⚠ **셰이더가 없으면 머티리얼 없이 간다** — 그러면 번쩍이 옛 모양(흰 사각형)이 되고
	#  외곽선은 **몸 그림 그대로가 여덟 번 깔려** 뭉개진다. 🔴 **그래도 짖지 않는다**:
	#  이 파일의 규율이 「몬스터 쪽은 대체하고 짖지 않는다」다(`_load_sheets`).
	_number_layer = _make_layer(_draw_numbers, LAYER_NUMBER)


## 레이어에 실루엣 셰이더를 걸고 색을 넣는다.
## 🔴 **색은 노드 단위 uniform 이라 여기서 한 번 넣으면 된다** — 모든 몬스터가 같은 색이다.
##  ⚠ **세기는 못 넣는다**(몬스터마다 다르다) — 그리는 쪽이 modulate 알파로 넘긴다.
func _paint(layer: Node2D, sh: Shader, color: Color) -> void:
	if sh == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter(FLASH_COLOR_PARAM, color)
	layer.material = mat


func _make_layer(fn: Callable, nm: String) -> Node2D:
	var n := _Layer.new()
	n.fn = fn
	n.name = nm   # 🔴 그물이 이 이름으로 찾는다(위 상자) — 인덱스는 레이어가 늘면 어긋난다
	add_child(n)
	return n


func setup(world: WorldStep) -> void:
	_world = world
	queue_redraw()


func _process(_dt: float) -> void:
	advance()
	queue_redraw()
	# 🔴 자식은 부모의 `queue_redraw()` 를 **안 받는다.** 안 부르면 번쩍·숫자가 첫 프레임에서
	#  얼어붙고, 증상은 「맞아도 안 번쩍인다」 하나뿐이다.
	for layer: Node2D in [_outline_layer, _flash_layer, _number_layer]:
		if layer != null:
			layer.queue_redraw()


## 한 프레임분 갱신 — hp 변화를 읽어 번쩍·피해 숫자를 만들고, 살아 있는 연출들의 나이를 먹인다.
## 🔴 `_process`가 부르는 것과 **같은 함수다**(`blast_fx.advance()`와 같은 어법) — 그물이 씬 없이
##  프레임을 흘려보낼 수 있게 공개다.
##
## 🔴🔴 **나이를 먹이는 것이 먼저고, hp를 읽는 것이 나중이다.** 순서를 바꾸면 이번 프레임에
##  막 생긴 번쩍·피해 숫자가 **같은 호출 안에서** 한 프레임어치를 먼저 잃는다 — 실측으로
##  `MONSTER_FLASH_FRAMES`(6)짜리 번쩍이 5프레임 뒤에 벌써 꺼지는 것으로 걸렸다(net 실패).
func advance() -> void:
	_frame += 1
	_decay_flashes()
	_prune(_dmg_numbers, Fx.MONSTER_DMG_NUM_LIFE_FRAMES)
	_prune(_corpses, Fx.MONSTER_CORPSE_LIFE_FRAMES)
	_prune(_death_pops, Fx.MONSTER_DEATH_POP_FRAMES)
	if _world != null:
		_scan_hp_changes()


## 🔴🔴 **죽음 통지를 여기서만 읽는다.** `stage.gd`의 `_on_ticked()`가 부른다 — 프레임마다
##  부르면 통지가 다음 `frame()`의 틱 갈래까지 살아 있어서 시체가 여러 번 생긴다
##  (`world_step.frame()`의 「한 대가 세 대가 된다」 함정과 같은 자리).
func on_tick() -> void:
	if _world == null:
		return
	for i in _world.died_count():
		var d := {
			"x": _world.died_x(i), "y": _world.died_y(i), "kind": _world.died_kind(i), "age": 0,
		}
		_corpses.append(d)
		# 🔴🔴 **죽는 순간 터진다 — 닭의 피격 피드백은 이것뿐이다**(`fx_tuning.MONSTER_DEATH_POP_FRAMES`).
		#  ⚠ 닭은 한 방에 죽어서 `_scan_hp_changes` 의 hp diff 가 볼 대상이 **이미 배열에서 빠졌다.**
		#   ⇒ 번쩍도 숫자도 한 프레임도 안 뜬다. **죽음 통지만이 그 순간을 안다.**
		#  🔴 **시체와 같은 통지에서 같이 만든다** — 따로 걸면 「시체는 있는데 터짐이 없는」
		#   조합이 생길 수 있고, 그건 두 경로가 갈라졌다는 뜻이라 화면에서만 보인다.
		_death_pops.append(d.duplicate())


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
				_add_dmg_number(m, prev - m.hp)
		_prev_hp[m.id] = m.hp
	# 더 안 사는 id는 정리한다 — 안 지우면 죽은 id가 사전에 무한히 쌓인다(20마리 상한은
	#  살아 있는 몬스터에만 걸리고, 이 사전은 그 상한 밖이다).
	for id in _prev_hp.keys().duplicate():
		if not seen.has(id):
			_prev_hp.erase(id)
			_flash_left.erase(id)


## 🔴🔴 **같은 몬스터의 최근 숫자가 있으면 거기에 더한다 — 새로 안 만든다** (2026-08-07, 사용자가 정했다).
##
## ⚠ **화면에서 `-10` 셋이 겹쳐 `-1000` 처럼 보이고 체력바까지 덮었다.** 숫자가 셋인 것이 아니라
##  **셋이 같은 자리에 겹치는 것**이 문제였다 — 자리가 `m.center()` 라 연타면 좌표가 거의 같다.
##
## 🔴 **나이를 0으로 되감고 자리도 갱신한다.** 안 되감으면 합친 숫자가 **곧 사라져서**
##  마지막 한 방이 표시 없이 들어간 것처럼 보인다. 자리를 갱신하는 것은 몬스터가 그동안
##  움직였을 수 있어서다(돼지는 밀고 들어온다).
## ⚠ **되감기가 곧 「영영 안 늙는다」의 위험이다** — `MONSTER_DMG_NUM_MERGE_FRAMES` 주석이
##  그래서 「수명보다 짧아야 한다」를 못 박았다. **계속 맞는 동안 숫자가 안 사라지는 것은 의도다.**
##
## 🔴 **id 로 찾는다.** 좌표로 찾으면 두 몬스터가 겹쳐 설 때 남의 피해가 합쳐진다.
func _add_dmg_number(m: Monster, amount: int) -> void:
	for n: Dictionary in _dmg_numbers:
		if n["id"] == m.id and int(n["age"]) < Fx.MONSTER_DMG_NUM_MERGE_FRAMES:
			n["amount"] = int(n["amount"]) + amount
			n["age"] = 0
			n["x"] = m.center().x
			n["y"] = float(m.y)
			return
	_dmg_numbers.append({
		"id": m.id, "x": m.center().x, "y": float(m.y), "amount": amount, "age": 0,
	})


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
	_death_pops.clear()
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


func death_pop_count() -> int:
	return _death_pops.size()


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
	# 🔴 **두 겹이다 — 마법 탄과 같은 문법(무리 + 심), 다른 색.** 색만 바꾸면 안 갈렸다:
	#  옛 분홍과 무속성 보라는 85° 떨어져 있었는데도 헷갈렸다(`fx_tuning.MONSTER_BOLT_COLOR` 상자).
	for i in _world.bolt_count():
		var p := Vector2(_world.bolt_x(i), _world.bolt_y(i))
		draw_circle(p, Fx.MONSTER_BOLT_R_PX, Fx.MONSTER_BOLT_COLOR)
		draw_circle(p, Fx.MONSTER_BOLT_R_PX * Fx.MONSTER_BOLT_CORE_FRAC, Fx.MONSTER_BOLT_CORE)
	# 🔴 죽는 순간의 터짐 — **시체·몬스터보다 위, 번쩍보다 아래**다.
	for p: Dictionary in _death_pops:
		_draw_death_pop(p)
	# ⚠ 레이어가 없으면(그물이 씬 없이 세운 경우) 여기서 마저 그린다 — 안 그러면
	#  「씬에서는 보이는데 그물에서는 없는」 두 세계가 생긴다.
	if _flash_layer == null:
		_draw_flashes(self)
	if _number_layer == null:
		_draw_numbers(self)
	# ⚠ 외곽선은 여기서 안 그린다 — 레이어가 없으면 **몸 위에** 깔려 실루엣을 통째로 덮는다.
	#  🔴 그물이 씬 없이 세우는 경우라 화면이 없고, 「없는 편이 틀린 것보다 낫다」.


## 🔴 번쩍 레이어가 부른다(`_flash_layer`). **이 노드 좌표계와 같다** — 자식이 부모 변환을 잇는다.
##
## 🔴🔴 **`canvas` 를 인자로 받는다. 이 한 줄이 없어서 피해 숫자가 화면에서 통째로 사라졌었다.**
##  ⚠ 2026-08-08, verify-look 이 잡았다 — 배열에는 `-40` 이 있고 폰트도 있고 레이어도 보이는데
##   **화면에 아무것도 없었다.** 원인은 이 함수와 `_draw_numbers` 의 **비대칭**이었다:
##   번쩍은 `canvas` 를 골라 잡았고 숫자는 **암묵적 `self`(= MonsterView)** 에 그렸는데,
##   그 함수는 **자식 레이어의 `_draw()` 안에서** 불리므로 MonsterView 는 그리는 중이 아니다
##   ⇒ **그 그리기 명령이 조용히 버려진다.**
##  🔴 **그물이 원리적으로 못 잡았다** — 그물은 배열을 읽지 캔버스를 안 읽는다.
##  ⇒ **이제 `_Layer` 가 캔버스를 인자로 넘긴다**(그 클래스 상자) — 실수할 자리를 문법에서 없앴다.
func _draw_flashes(canvas: CanvasItem) -> void:
	if _world == null:
		return
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		if not _flash_left.has(m.id):
			continue
		var r := box_rect(m.kind, m.x, m.y)
		var frac := float(_flash_left[m.id]) / float(Fx.MONSTER_FLASH_FRAMES)
		var a := Fx.MONSTER_FLASH_COLOR.a * frac
		var tex: Texture2D = _sheets.get(m.kind)
		if tex == null:
			# 폴백 — 셰이더가 걸려 있어도 `TEXTURE` 가 흰 1×1이라 결과가 「흰 사각형 × 세기」다
			#  (`monster_flash.gdshader` 머리). 즉 **옛 동작 그대로**다.
			var c := Fx.MONSTER_FLASH_COLOR
			canvas.draw_rect(r, Color(c.r, c.g, c.b, a))
			continue
		_draw_flipped(canvas, tex, r, m.facing < 0, Color(1.0, 1.0, 1.0, a))


## 🔴🔴 **외곽선 — 몸 그림을 여덟 방향으로 밀어 깔고, 그 위에 몸이 덮는다.**
##
## ⚠ **왜 있나**: verify-look 이 돼지를 **검은 하늘**에 세우니 **다리와 아랫배가 녹았다**
##  (2026-08-08. `fx_tuning.MONSTER_OUTLINE_COLOR` 상자가 그 사연을 든다).
##
## 🔴 **셰이더가 단색으로 칠하므로 밀어 깐 여덟 장이 그대로 테두리가 된다** — 알파만 남고
##  색은 uniform 이라, 몸 그림의 어두운 픽셀이 그대로 어둡게 깔리는 일이 없다.
##  ⚠ **`modulate` 곱셈으로는 이걸 못 한다** — 곱하면 원본이 어두워질 뿐 **밝아지지 않는다.**
##   그래서 이 연출은 **셰이더 없이는 원리적으로 안 된다**(사용자가 그 축을 골랐다).
##
## 🔴 **시체에도 두른다** — 시체가 배경에 녹으면 「죽은 자리」가 안 보인다. 산 몸과 같은 문제다.
func _draw_outlines(canvas: CanvasItem) -> void:
	if _world == null:
		return
	for c: Dictionary in _corpses:
		var age: int = c["age"]
		var alpha := 1.0 - float(age) / float(Fx.MONSTER_CORPSE_LIFE_FRAMES)
		# ⚠ 시체는 페이드하므로 외곽선도 같이 옅어져야 한다 — 안 그러면 몸이 사라진 뒤
		#  **크림색 윤곽만 남아 떠 있다.**
		_outline_one(canvas, c["kind"], c["x"], c["y"], false, alpha)
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		_outline_one(canvas, m.kind, m.x, m.y, m.facing < 0, 1.0)


func _outline_one(canvas: CanvasItem, kind: int, x: int, y: int, flip: bool, alpha: float) -> void:
	var tex: Texture2D = _sheets.get(kind)
	if tex == null:
		return   # 폴백은 단색 사각형이라 외곽선이 뜻을 안 갖는다
	var r := box_rect(kind, x, y)
	var col := Color(1.0, 1.0, 1.0, alpha)
	for d: Vector2 in Fx.MONSTER_OUTLINE_DIRS:
		_draw_flipped(canvas, tex, Rect2(r.position + d * Fx.MONSTER_OUTLINE_PX, r.size), flip, col)


## ⚠ **`canvas` 를 반드시 아래로 넘긴다** — 위 `_draw_flashes` 상자가 그 사연을 든다.
func _draw_numbers(canvas: CanvasItem) -> void:
	for n: Dictionary in _dmg_numbers:
		_draw_dmg_number(canvas, n)


func _draw_monster(m: Monster) -> void:
	var r := box_rect(m.kind, m.x, m.y)
	_draw_monster_body(m, r)
	# 🔴 **번쩍은 여기가 아니다** — 셰이더가 노드 단위라 `_flash_layer` 로 나갔다(위 상자).
	if m.burning:
		_draw_body_flames(self, r, m.id)
	_draw_hp_bar(m.kind, m.x, m.y, m.hp)


## 🔴🔴 **몸에 붙은 불 — 여러 군데다.** 원래 상자 테두리 하나였고 화면에서
##  **「주황 선택 상자」**로 읽혔다(2026-08-07, 판정 13). 같은 화면의 땅불이 진짜 픽셀 불이라
##  대비가 잔인했다 — `fx_tuning.MONSTER_BURN_FLAMES` 상자가 그 사연을 들고 있다.
##
## 🔴 **자리는 몬스터 id 로 고정한다** — 프레임마다 다시 뽑으면 불꽃이 **매 프레임 순간이동**하고
##  그건 불이 아니라 노이즈다. 움직이는 것은 **크기뿐**이고, 위상을 어긋내 다 같이 안 뛰게 한다.
## ⚠ **불꽃이 상자를 조금 넘어간다** — 몸 윤곽을 모르므로(알파를 안 읽는다) 안쪽에만 두면
##  실루엣 가장자리에서 불이 끊겨 보인다. 넘치는 편이 「몸을 감싼다」로 읽힌다.
##
## 🔴🔴 **원이 아니라 셀 격자에 맞춘 사각 픽셀이다** (2026-08-08, verify-look 이 화면에서 잡았다).
##  ⚠ **`draw_circle` 두 겹이었고 「빨간 테두리 + 노란 속」이라 「과녁 다섯 개」로 읽혔다.**
##   바로 옆 땅불은 불규칙한 픽셀 덩어리라 누가 봐도 불이었다 ⇒ **대비가 그대로였다.**
##   「주황 선택 상자」가 「주황 과녁 다섯」이 됐을 뿐 **여전히 도형**이었다.
##
## 🔴🔴 **고친 방향은 색이 아니라 어휘다 — 땅불과 같은 문법으로 그린다.**
##  땅불은 `CELL_PX`(4px) 격자에 칠해진 픽셀이다 ⇒ 몸의 불도 **4px 정렬된 사각 픽셀 덩어리**로 그린다.
##  🔴 **완벽한 원은 이 게임 화면에 없는 모양이다** — 지형도 불도 물도 전부 셀이다.
##   그래서 원은 아무리 색을 맞춰도 「UI」로 읽힌다. 같은 실수를 볼트 무리에서도 했다.
##
## ⚠ **덩어리 모양도 id·i 로 고정한다** — 프레임마다 다시 뽑으면 지글거리는 노이즈가 된다.
##  움직이는 것은 **높이(혀가 날름거리는 것)** 뿐이다.
func _draw_body_flames(canvas: CanvasItem, r: Rect2, id: int) -> void:
	var cell := float(Tuning.CELL_PX)
	for i in Fx.MONSTER_BURN_FLAMES:
		var p := flame_pos(r, id, i)
		# 위상을 불꽃마다 어긋낸다 — 안 그러면 다섯이 한 몸으로 뛴다.
		var phase := float(i) * TAU / float(Fx.MONSTER_BURN_FLAMES)
		var wob := sin(float(_frame) / Fx.MONSTER_BURN_PERIOD_FRAMES * TAU + phase)
		# 🔴 **셀에 스냅한다.** 스냅을 빼면 불이 셀 격자와 어긋나 「위에 떠 있는 것」이 된다.
		var bx := floorf(p.x / cell) * cell
		var by := floorf(p.y / cell) * cell
		# 혀 높이 — 1~3셀. `wob` 이 크기가 아니라 **높이**를 흔든다(불은 위로 자란다).
		var tall := 1 + int(roundf((wob * 0.5 + 0.5) * (Fx.MONSTER_BURN_TALL_CELLS - 1)))
		for k in tall:
			# 위로 갈수록 좁아지고 밝아진다 — 그것이 「불꽃 혀」의 전부다.
			var w := cell * float(tall - k)
			var col: Color = Fx.FIRE_LO if k < tall - 1 else Fx.FIRE_HI
			canvas.draw_rect(Rect2(bx - w * 0.5, by - cell * float(k + 1), w, cell), col)


## 🔴 죽는 순간 터지는 고리 — **닭의 유일한 피격 피드백**이다(`fx_tuning.MONSTER_DEATH_POP_FRAMES`).
##  ⚠ 벌어지면서 옅어진다. 벌어지기만 하면 「고리가 남았다」로, 옅어지기만 하면 「깜빡였다」로 읽힌다.
func _draw_death_pop(p: Dictionary) -> void:
	var r := box_rect(p["kind"], p["x"], p["y"])
	var t := float(p["age"]) / float(Fx.MONSTER_DEATH_POP_FRAMES)
	var radius := maxf(r.size.x, r.size.y) * 0.5 * lerpf(1.0, Fx.MONSTER_DEATH_POP_SCALE, t)
	var c := Fx.MONSTER_DEATH_POP_COLOR
	draw_arc(r.get_center(), radius, 0.0, TAU, 24, Color(c.r, c.g, c.b, c.a * (1.0 - t)),
		Fx.MONSTER_DEATH_POP_PX)


## 🔴🔴 **그림은 `r`(= `Defs`에서 나온 상자)에 맞춰 그린다 — 텍스처 자기 픽셀 크기를 안 믿는다.**
##  `draw_texture_rect`가 목적지 크기로 늘이거나 줄이므로, 그림이 상자와 갈려도 **화면은 여전히
##  상자 크기다**(`net_monster_sprite`가 "지금은 같다"를 값으로 잰다 — 갈리면 거기가 먼저 빨개진다).
##
## 🔴 **텍스처가 없으면(로딩 실패) `MONSTER_FILL` 사각형으로 대체한다.** 위 `fx_tuning.MONSTER_FILL`
##  상자가 그 이유를 적었다 — 몬스터는 종류가 늘 여럿이라 하나가 깨져도 나머지는 마저 보여야 한다.
##
## ⚠ **몬스터 그림은 오른쪽을 본다 — 왼쪽으로 갈 때 뒤집는다**(`character_view._draw`와 같은 어법,
##  `draw_set_transform`으로 좌우 스케일을 뒤집는다). ⚠ **되돌리는 것을 잊지 마라** —
##  안 되돌리면 이 뒤에 그리는 것(번쩍·불 테두리·체력바) 전부가 뒤집힌 좌표계에서 그려진다.
func _draw_monster_body(m: Monster, r: Rect2) -> void:
	var tex: Texture2D = _sheets.get(m.kind)
	if tex == null:
		draw_rect(r, Fx.MONSTER_FILL)
		return
	_draw_flipped(self, tex, r, m.facing < 0, Color.WHITE)


## 🔴 몸 그림을 상자에 맞춰 그린다. 왼쪽을 보면 뒤집는다.
##  ⚠ **되돌리는 것을 잊지 마라** — 안 되돌리면 이 뒤에 그리는 것 전부가 뒤집힌 좌표계로 간다.
##  🔴 **그래서 이 함수 하나로 묶었다.** 몸과 번쩍이 같은 뒤집기를 따로 짜면 **둘이 갈라지는 날**
##   맞은 돼지의 흰 실루엣만 반대로 서고, 그건 화면에서만 보인다.
## ⚠ `canvas` 를 받는 이유: 번쩍은 **자식 노드**에 그린다(셰이더가 노드 단위다).
func _draw_flipped(canvas: CanvasItem, tex: Texture2D, r: Rect2, flip: bool, modulate: Color) -> void:
	canvas.draw_set_transform(Vector2(r.position.x + (r.size.x if flip else 0.0), r.position.y),
		0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	canvas.draw_texture_rect(tex, Rect2(Vector2.ZERO, r.size), false, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hp_bar(kind: int, x: int, y: int, hp: int) -> void:
	var bar := hp_bar_rect(kind, x, y)
	draw_rect(bar, Fx.MONSTER_HP_BAR_BG)
	var frac := hp_bar_fill_frac(hp, Defs.max_hp(kind))
	if frac <= 0.0:
		return
	var fill := Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y))
	draw_rect(fill, Fx.MONSTER_HP_BAR_FULL.lerp(Fx.MONSTER_HP_BAR_EMPTY, 1.0 - frac))


## 🔴🔴 **시체도 몸 그림이다 — 어둡게 깔고 페이드한다**(2026-08-07, 판정 13이 여기서 실패했다).
##  ⚠ **원래 자주 사각형이었고 화면에서 「UI 조각이 남았나」로 읽혔다** — 같은 화면의 몸은
##   스프라이트인데 시체만 도형이라 **스프라이트를 붙인 값이 절반 깎였다.**
## 🔴 **어둡게 하는 것은 `modulate` 곱셈이다** — 알파 채널이 그대로 살아서 실루엣이 정확하다.
##  ⚠ 곱셈이라 **밝아지게는 못 한다.** 「죽으면 어두워진다」와 방향이 같아서 여기서는 맞다.
##
## ⚠ **방향을 모른다 — 늘 오른쪽을 본다.** 죽음 통지(`world.died_*`)가 `facing` 을 안 넘긴다.
##  🔴 **왼쪽으로 걷다 죽으면 시체가 홱 돌아선다.** 통지에 한 칸을 더하면 고쳐지지만
##   그건 `src/actor/` 계약을 건드리는 일이라 **이번 범위 밖**이다. 눈에 띄면 그때 하라.
func _draw_corpse(c: Dictionary) -> void:
	var kind: int = c["kind"]
	var r := box_rect(kind, c["x"], c["y"])
	var age: int = c["age"]
	var alpha := 1.0 - float(age) / float(Fx.MONSTER_CORPSE_LIFE_FRAMES)
	var tex: Texture2D = _sheets.get(kind)
	if tex == null:
		# 폴백 — `_draw_monster_body` 와 같은 규율(짖지 않고 대체한다).
		var col := Fx.MONSTER_CORPSE_COLOR
		draw_rect(r, Color(col.r, col.g, col.b, col.a * alpha))
		return
	var d := Fx.MONSTER_CORPSE_DIM
	draw_texture_rect(tex, r, false, Color(d, d, d, alpha))


## 🔴🔴 **`canvas.draw_string` 이다 — 맨 `draw_string` 이 아니다.**
##  ⚠ **여기가 2026-08-08의 그 자리다**(위 `_draw_flashes` 상자). 맨 `draw_string` 은
##   MonsterView 자신에게 거는 것이고, 이 함수는 **자식 레이어가 그리는 중**에 불리므로
##   **그 명령이 조용히 버려진다. 에러도 안 난다.**
##  🔴 `net_monster` 가 이 규칙을 **소스에서** 잰다 — 거동으로는 헤드리스가 못 잡는다.
func _draw_dmg_number(canvas: CanvasItem, n: Dictionary) -> void:
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
	# 🔴 **체력바 위에서 시작한다** — `m.y` 에서 그대로 띄우면 체력바를 덮는다
	#  (2026-08-08, verify-look 이 화면에서 봤다. `MONSTER_DMG_NUM_LIFT_PX` 상자).
	var y := float(n["y"]) - Fx.MONSTER_DMG_NUM_LIFT_PX - Fx.MONSTER_DMG_NUM_RISE_PX * t
	var col := Fx.MONSTER_DMG_NUM_COLOR
	var text := "-%d" % int(n["amount"])
	# 가운데 정렬 — `circle_window`류는 전부 LEFT라 폭을 직접 재서 절반만큼 왼쪽으로 민다.
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.MONSTER_DMG_NUM_SIZE).x
	canvas.draw_string(font, Vector2(float(n["x"]) - w * 0.5, y), text,
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


## 🔴🔴 **몸에 붙은 불꽃 하나의 자리. 순수 static 이라 그물이 직접 부른다.**
##
## 🔴 **id 와 인덱스만으로 정해진다 — 프레임이 안 들어간다.** 자리가 프레임마다 바뀌면
##  불꽃이 **매 프레임 순간이동**하고 그건 불이 아니라 노이즈다(움직이는 것은 크기뿐).
## ⚠ **`randi` 가 아니라 해시다.** `randi` 를 쓰면 같은 몬스터의 불이 프레임마다 다른 자리에 서고,
##  그물도 재현을 못 한다. 여기는 `src/view/` 라 결정론 계약 밖이지만 **재현성은 여전히 필요하다.**
##
## 🔴 **아래로 치우친다**(`MONSTER_BURN_LOW_BIAS`) — 고르게 뿌리면 「불에 탄다」가 아니라
##  「반짝이가 붙었다」로 보인다. 불은 아래에서 올라온다.
static func flame_pos(r: Rect2, id: int, i: int) -> Vector2:
	# 두 큰 홀수를 섞는다 — 인접한 id·i 가 인접한 자리로 가지 않게 하는 것이 전부다.
	var h := (id * 2654435761 + i * 40503) & 0xFFFFFF
	var fx := float(h & 0xFF) / 255.0
	var fy := float((h >> 8) & 0xFF) / 255.0
	fy = Fx.MONSTER_BURN_LOW_BIAS + (1.0 - Fx.MONSTER_BURN_LOW_BIAS) * fy
	return r.position + Vector2(r.size.x * fx, r.size.y * fy)


## 체력바가 채워진 비율. 0~1로 죈다 — 음수 hp는 `Monster.on_tick`이 이미 `maxi(0, …)`로
##  막지만(문서 「hp를 깎는 문은 하나다」), 화면 쪽에서 한 번 더 죄어 두면 표를 잘못 읽어도
##  체력바가 상자 밖으로 안 나간다.
static func hp_bar_fill_frac(hp: int, max_hp: int) -> float:
	if max_hp <= 0:
		return 0.0
	return clampf(float(hp) / float(max_hp), 0.0, 1.0)
