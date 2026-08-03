extends RefCounted
## 조립된 마법진 하나 — 🔴🔴 **장착 상태의 단일 소스다.**
##
## 디버그 키도 (앞으로) 조립창도 **이것 하나**를 만진다. 각자 상태를 들면
## 「키를 눌렀는데 총구가 그대로다」가 되고 **에러가 하나도 안 난다.**
##
## ```
##    디버그 키 1~5 ──▶ set_from_packed()
##                          SpellCircle ──▶ 총구 그림 (character_view가 **읽는다**)
##    조립창 클릭   ──▶ set_circle()      ├─▶ HUD
##                      set_rune()        └─▶ 발사 커맨드 (can_fire · element · packed_glyphs)
##                      place_glyph()
## ```
##
## 🔴 **좌표를 안 든다.** 좌표는 화면의 몫이다 — `src/actor/`는 float 허용이라 `Vector2`가
##  들어와도 **그물이 안 짖고**, 그때부터 조립 규칙과 그림이 한 덩어리가 된다.
##
## ⚠ **왜 `src/sim/`이 아닌가**: 조립 상태는 매 틱 도는 결정론 상태가 아니다. 격자·투사체는
##  락스텝이지만 **플레이어의 장착은 호스트 권위**다(GDD 멀티 표).
##
## 🔴🔴 **제약을 여기 적지 않는다.** `glyph_defs.DEFS`를 **읽기만** 한다 — 따로 적으면 규칙이
##  두 벌이 되고, `spell_sim.fire()`가 막는 배치를 조립창이 통과시킨다. 그 상태는
##  「눌러도 아무 일이 안 일어난다」로만 보인다.
##
## 🔴 **놓는 규칙이 종류마다 달라서 함수를 안 합쳤다** — 진은 늘 놓이고(층을 비운다),
##  룬도 늘 놓이고, 문양만 `max_per_circle`을 본다. `slot_kind` 스위치 하나로 합치면
##  룬 자리와 진이 늘 때마다 그 스위치가 커지고, 세 축이 그 안에서 다시 붙는다.

const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

## 🔴🔴 **빈 룬 자리. 여기가 단일 소스다** — 뷰도 이 상수를 읽는다.
##
## ⚠ **왜 0이 아닌가**: `sim_tuning.ELEM_FIRE`가 이미 0이다. 0을 빈 값으로 쓰면
##  **빈 룬 자리가 불 룬으로 읽히고**, 조립창은 빈칸을 그리는데 발사는 불이 나간다.
##  **에러가 하나도 안 난다.** 진(`CIRCLE_NONE`)·문양(`GLYPH_NONE`)만 0 규율을 쓸 수 있다.
##
## ⚠ **왜 `src/sim/`이 아닌가**: 시뮬은 빈 룬을 **모른다.** 빈 룬이면 커맨드를 아예 안 만든다.
##  소비자 없는 상수를 sim에 두면 그게 거짓 손잡이다.
## 🔴 그물이 **`ELEM_ALL` 안에 이 값이 없다**를 잰다 — 그 한 줄이 위 함정을 계약으로 못박는다.
const RUNE_EMPTY := -1

var _circle_id := CircleDefs.CIRCLE_NONE
## 안쪽이 0번(= 1층)이다. `GLYPH_NONE` = 빈 층.
var _layers: Array[int] = []
## `RUNE_EMPTY` = 빈 자리.
var _runes: Array[int] = []


func _init(circle_id: int = CircleDefs.CIRCLE_ROUND) -> void:
	set_circle(circle_id)
	# 🔴 **시작 상태는 진·룬이 채워져 있다**(GDD 「기본 지급 진: 동그라미, 2층」).
	#  ⚠ 빈 룬으로 켜지면 게임이 「못 쏘는」 상태로 시작하고, 그건 고장으로 읽힌다.
	for slot in _runes.size():
		set_rune(slot, Tuning.ELEM_FIRE)


func circle_id() -> int:
	return _circle_id


func layer_count() -> int:
	return _layers.size()


func rune_count() -> int:
	return _runes.size()


func glyph_at(layer: int) -> int:
	if layer < 0 or layer >= _layers.size():
		return Glyph.GLYPH_NONE
	return _layers[layer]


func rune_at(slot: int) -> int:
	if slot < 0 or slot >= _runes.size():
		return RUNE_EMPTY
	return _runes[slot]


# ══════════════════════════════════════════════════════════════════
#  놓기 — 🔴 **종류마다 규칙이 다르다**
# ══════════════════════════════════════════════════════════════════

## 진을 놓는다. **늘 놓인다** — 진에는 제약이 없어서 `can_place_circle`이 없다(그러면 거짓 손잡이다).
##
## 🔴 진마다 층 수가 다르므로 `_layers`·`_runes`는 **런타임에 길이가 변한다.** 진이 1종이라
##  지금은 안 드러나지만, 모델이 그걸 표현 못 하게 짜면 진이 둘이 되는 날 모델을 다시 만든다.
##
## 🔴 **진을 바꾸면 층과 룬 자리를 전부 비운다.** 앞에서부터 살리고 넘치는 것만 버리면
##  **마지막 문양 하나가 조용히 사라진다.** 통째로 비우면 그림이 통째로 바뀌어 **눈에 보인다.**
func set_circle(id: int) -> void:
	# ⚠ **같은 진을 다시 놓는 것은 아무 일도 안 한다** — 안 그러면 실수로 한 번 더 클릭해서
	#  조립이 통째로 날아간다.
	if id == _circle_id:
		return
	_circle_id = id
	_layers.resize(CircleDefs.layers(id))
	_layers.fill(Glyph.GLYPH_NONE)
	_runes.resize(CircleDefs.rune_slots(id))
	_runes.fill(RUNE_EMPTY)


## 룬을 놓는다(`RUNE_EMPTY`면 뺀다). **늘 놓인다** — 룬에도 제약이 없다.
##
## 🔴 **모르는 룬은 안 받는다.** 받으면 `can_fire()`가 통과시키고 `spell_sim.fire()`가
##  커맨드 경계에서 짖는데, 그때 화면에서는 이미 「좌클릭했는데 아무 일도 안 난다」다.
func set_rune(slot: int, rune_id: int) -> bool:
	if slot < 0 or slot >= _runes.size():
		return false
	if rune_id != RUNE_EMPTY and not Tuning.ELEM_ALL.has(rune_id):
		push_error("SpellCircle: 모르는 룬 %d — 놓지 않는다" % rune_id)
		return false
	_runes[slot] = rune_id
	return true


## 이 층에 이 문양을 놓을 수 있나. 🔴 **`can_place_*`가 문양에만 있는 이유**는 제약이 문양에만
##  있어서다 — 진·룬에 검사 함수를 만들면 늘 true를 주는 거짓 손잡이가 된다.
##
## 🔴🔴 **쏘고 나서 실패하면 고장으로 읽힌다**(기획 「극단값」). 그래서 제약이 발사 시점이
##  아니라 **조립 시점**에 드러나야 한다. ⚠ 그래도 `spell_sim.fire()`의 검증은 남는다 —
##  네트워크는 조립창을 안 지난다. 두 검사는 서로 다른 것을 지키고 **같은 표를 읽는다.**
func can_place_glyph(layer: int, glyph_id: int) -> bool:
	if layer < 0 or layer >= _layers.size():
		return false
	# 빼기는 늘 된다. 🔴 빼기를 다른 길로 만들면 「놓기는 막혔는데 빼기가 상태를 깬다」가 생긴다.
	if glyph_id == Glyph.GLYPH_NONE:
		return true
	return _list_ok(_with(layer, glyph_id))


## 문양을 놓는다(`GLYPH_NONE`이면 뺀다). 못 놓으면 false — **조용히**다.
## ⚠ 여기서 짖으면 안 된다. 못 놓는 것은 **정상 조작**이고(팔레트가 흐리게 보여 주는 것이
##  단계 4의 몫), 짖으면 클릭 한 번이 래퍼의 stderr 검사를 빨갛게 만든다.
func place_glyph(layer: int, glyph_id: int) -> bool:
	if not can_place_glyph(layer, glyph_id):
		return false
	_layers[layer] = glyph_id
	return true


## 🔴 **놓은 뒤의 목록을 미리 만들어 잰다.** 「지금 이 문양이 몇 개인가」만 세면
##  덮어쓰기(그 층에 이미 확산이 있는데 같은 층에 확산을 또 놓기)를 하나 더 세서
##  **놓을 수 있는 것을 막는다.**
func _with(layer: int, glyph_id: int) -> Array[int]:
	var out: Array[int] = []
	for i in _layers.size():
		var id: int = glyph_id if i == layer else _layers[i]
		if id != Glyph.GLYPH_NONE:
			out.append(id)
	return out


## 🔴🔴 **규칙이 한 벌인 지점.** `can_place_glyph`와 `set_from_packed`가 **같은 이 함수**를
##  부른다 — 둘이 각자 재면 「프리셋으로는 들어가는데 클릭으로는 못 놓는」 배치가 생긴다.
## ⚠ 여기 적힌 규칙이 하나도 없는 게 요점이다. 전부 `glyph_defs.DEFS`에서 읽는다.
static func _list_ok(list: Array[int]) -> bool:
	if list.size() > Tuning.GLYPH_MAX_LAYERS:
		return false
	for id: int in list:
		if not Glyph.DEFS.has(id):
			return false
		var cap := int(Glyph.DEFS[id]["max_per_circle"])
		# 🔴 **0 = 무제한.** 세지도 않는다 — `spell_sim._valid_glyphs`와 같은 읽기다.
		if cap > 0 and list.count(id) > cap:
			return false
	return true


# ══════════════════════════════════════════════════════════════════
#  🔴🔴 쏠 수 있나 — 빈 룬 자리가 하나라도 있으면 못 쏜다
# ══════════════════════════════════════════════════════════════════

## ```
## can_fire()  =  진이 있다  &&  빈 룬 자리가 하나도 없다
## ```
##
## 🔴 **문양은 없어도 되고 룬은 있어야 한다.** 기획 「극단값」이 「층 2개를 다 비우고 쏘면
##  쏴져야 한다 — **진+룬만으로도** 마법은 성립한다」고 적은 문장에 이미 들어 있다.
##
## ⚠ **룬 자리가 하나뿐이라 「전부 차야 한다」와 「하나라도 차면 된다」가 지금 같은 답을 낸다.**
##  룬 자리가 여럿이 되는 날 갈라진다(병렬 진에서 2/3만 채우면 2발이 나가는 게 자연스럽다).
##  🔴 **그때 정한다.** 지금 고른 것은 「전부 차야 한다」고, 적어 두는 것이 요점이다.
func can_fire() -> bool:
	if _circle_id == CircleDefs.CIRCLE_NONE:
		return false
	for rune_id: int in _runes:
		if rune_id == RUNE_EMPTY:
			return false
	return true


## 발사 커맨드가 쓰는 룬.
## ⚠ **`can_fire()`가 참일 때만 뜻이 있다** — 빈 자리면 커맨드가 아예 안 만들어진다.
## 🔴 **룬 자리가 하나라는 가정이 여기 한 곳에만 있다.** 진을 늘리면서 여러 룬을 어떻게 합칠지
##  (융합·병렬·순차) 안 정하면 래퍼의 stderr 검사에 공짜로 걸린다 — 진 표에 아직 칸조차 없다.
func element() -> int:
	if _runes.size() != 1:
		push_error("SpellCircle: 룬 자리가 %d개다 — 발사는 아직 하나만 안다" % _runes.size())
		return Tuning.ELEM_FIRE
	return _runes[0]


# ══════════════════════════════════════════════════════════════════
#  목록 ↔ 정수
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **빈 층을 건너뛴다.** 그대로 팩하면 문양이 **에러 없이 증발한다**:
##
## ```
## 1층 비었다 · 2층 폭발  →  그대로 팩하면 g = GLYPH_NONE | (BLAST << 4)
##                          그런데 GLYPH_NONE = 0 이 「목록 끝」이다
##                          first(g) = 0  →  탄은 **빈 목록**을 들고 난다
## ```
##
## ⇒ 「2층에만 넣으면 아무 일도 안 일어난다」로만 보인다. 빈 층은 아무 일도 안 하니
## 건너뛰는 것이 규칙이고, 「두 층을 다 비우고 쏘면 쏴져야 한다」(기획 「극단값」)는
## `g == 0`이라는 **이미 있는 경로**로 그대로 떨어진다.
func glyph_list() -> Array[int]:
	var out: Array[int] = []
	for id: int in _layers:
		if id != Glyph.GLYPH_NONE:
			out.append(id)
	return out


## 🔴 **시프트를 여기서 하지 않는다** — `glyph_defs`의 세 함수가 유일한 시프트 자리다
##  (그 파일 주석: 두 곳에서 시프트하면 반드시 갈라진다).
## ⚠ 총구가 매 `_draw()`에 부르므로 배열 하나를 만드는 값을 **일부러 치른다.**
##  직접 시프트해서 아끼면 그 순간 규칙이 두 벌이 된다.
func packed_glyphs() -> int:
	return Glyph.pack(glyph_list())


## 🔴🔴 **디버그 키가 들어오는 문이다.** 앞 층부터 조밀하게 채운다 —
##  키 3(폭발 하나)이면 1층 폭발 · 2층 빈칸이다. 🔴 왕복이 계약이다:
##  `set_from_packed(g)` 뒤 `packed_glyphs() == g`.
##
## ⚠ **문양만 바꾼다** — 진과 룬은 안 건드린다. 프리셋은 「어떤 문양 조합인가」지 장착 전체가 아니다.
##
## ⚠ **못 놓는 배치는 짖고 안 받는다.** 받으면 「클릭으로는 못 놓는데 프리셋으로는 들어가는」
##  상태가 생기고, 그 상태의 `packed_glyphs()`를 `fire()`가 거부해서 화면에서는
##  **「눌러도 아무 일이 안 일어난다」**로만 보인다.
func set_from_packed(g: int) -> bool:
	# 🔴 음수는 **영원히 돈다.** `rest`가 산술 시프트라 `-1 >> 4 == -1`이고, 아래 while이
	#  안 끝나 프레임이 통째로 얼어붙는다(에러 없이). `Glyph.pack`은 음수를 안 내놓지만
	#  이 함수는 정수를 그대로 받는 문이다.
	if g < 0:
		push_error("SpellCircle: 음수 목록 %d — 받지 않는다" % g)
		return false

	var list: Array[int] = []
	var cur := g
	while cur != Glyph.GLYPH_NONE:
		list.append(Glyph.first(cur))
		cur = Glyph.rest(cur)

	if list.size() > _layers.size():
		push_error("SpellCircle: 문양 %d개를 %d층 진에 넣을 수 없다" % [
			list.size(), _layers.size()])
		return false
	if not _list_ok(list):
		push_error("SpellCircle: 목록 %s가 문양 제약에 걸린다" % [list])
		return false

	# ⚠ **먼저 전부 비운다.** 안 비우면 키 4(두 층) 뒤에 키 3(한 층)을 눌렀을 때
	#  2층에 앞 문양이 남아 「뺐는데 안 빠진다」가 된다.
	_layers.fill(Glyph.GLYPH_NONE)
	for i in list.size():
		_layers[i] = list[i]
	return true
