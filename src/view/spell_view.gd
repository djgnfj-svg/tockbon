extends Node2D
## 투사체 머리·자취. 🔴 **화면만 만진다 — 시뮬을 절대 안 바꾼다.**
##
## ══ 🔴🔴 이 파일의 계약 = `spell_sim.gd`의 **정반대**다 ═════════════
##  시뮬은 「정수만」이고 여기는 **float 자유**다. 이유가 정반대라서 맞다 —
##  셀은 이산이라 중간 위치가 없지만, **투사체는 연속체라 중간 위치가 실제로 존재한다.**
##  ⇒ 셀 렌더는 보간을 **안 하는 게** 맞고, 여기는 보간을 **해야** 맞다.
##  ⚠ 보간을 빼면 20Hz 시뮬이라 투사체가 **틱당 40px씩 순간이동한다.**
##  🔴 반대로 **여기서 나온 값이 시뮬로 돌아가면 그 순간 락스텝이 깨진다.**
## ══════════════════════════════════════════════════════════════════
##
## 🔴 **투사체당 노드가 0개다.** `_draw()` 하나가 전부 그린다 ⇒ 물리콜백 `add_child` 함정과
##  `queue_free`+그룹 함정이 **둘 다 소멸한다.** 노드로 바꾸면 둘 다 돌아온다.

const SpellSim := preload("res://src/sim/spell_sim.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

## 고정소수점 셀 좌표 → 화면 px.
## ⚠ `1.0 *`가 붙은 이유는 정수 나눗셈을 피하려는 것이다 — 빼면 4/256이 **0이 되고**
##  투사체가 전부 원점에 그려진다(에러는 안 난다).
const FP_TO_PX: float = 1.0 * Tuning.CELL_PX / SpellSim.FP_ONE

var _sim: SpellSim = null

## 이번 프레임이 두 틱 사이 어디인가(0=직전 틱 · 1=이번 틱). 껍데기가 매 프레임 밀어 넣는다.
## ⚠ 시계는 시뮬 소유자에게 있다 — 여기서 `delta`를 누산하면 시계가 둘이 된다.
var _alpha := 0.0

## 투사체 id → 지난 틱 위치들(화면 px). 🔴🔴 **키가 슬롯 인덱스가 아니라 id인 게 핵심이다.**
##  소멸이 swap-remove라 슬롯은 틱마다 뒤바뀌고, 인덱스로 들고 있으면 투사체가 죽는 순간
##  **남의 자취가 순간이동한다** — 에러 하나 없이 화면만 이상해진다.
var _trails: Dictionary = {}

## 직전 `_draw()`가 실제로 뭔가 그렸나. 아래 `set_render_alpha` 주석의 걸쇠다.
var _drew := false


func _ready() -> void:
	# 🔴 가산 합성. 어두운 배경 위에서 「빛나는 것」으로 읽히게 하는 유일한 한 줄이다.
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func setup(sim: SpellSim) -> void:
	_sim = sim
	_trails.clear()
	queue_redraw()


## 두 틱 사이의 보간 위치. 껍데기가 `_process`마다 부른다.
##
## 🔴🔴 **`if active_count() > 0`만 쓰면 안 된다 — 그게 조용히 깨지는 자리다.**
##  `CanvasItem`은 마지막으로 그린 것을 **계속 들고 있는다.** 투사체가 사라진 프레임에
##  `queue_redraw`를 건너뛰면 **죽은 투사체가 화면에 영원히 박혀 있는다** — 에러 하나 없이.
##  ⇒ 「직전에 뭔가 그렸나」를 걸쇠로 들고, **0이 된 그 한 번은 반드시 다시 그린다.**
##  ⚠ **헤드리스가 이걸 원리적으로 못 잰다**(그리지 않는다). 걸쇠가 없으면 실게임에서만 드러난다.
func set_render_alpha(a: float) -> void:
	_alpha = clampf(a, 0.0, 1.0)
	if (_sim != null and _sim.active_count() > 0) or _drew:
		queue_redraw()


## 🔴 **시뮬이 한 틱 돈 뒤에** 부른다. 순서가 뒤집히면 자취가 한 틱 낡는다.
func on_tick() -> void:
	if _sim == null:
		return
	var n := _sim.active_count()
	var ids := _sim.get_id()
	var px := _sim.get_px()
	var py := _sim.get_py()
	var gens := _sim.get_gen()
	var live: Dictionary = {}
	for i in n:
		var id := ids[i]
		live[id] = true
		# ⚠ `PackedVector2Array`는 CoW 값 타입이다 — 꺼내 쓰고 **반드시 되넣어야** 한다.
		#  안 넣으면 append가 에러 없이 증발한다.
		var hist: PackedVector2Array = _trails.get(id, PackedVector2Array())
		hist.append(Vector2(float(px[i]) * FP_TO_PX, float(py[i]) * FP_TO_PX))
		# 🔴 꼬리 길이가 **세대마다 다르다** — 작은 탄은 꼬리도 짧아야 「약하다」로 읽힌다.
		var keep := Fx.trail_ticks(int(gens[i]))
		while hist.size() > keep:
			hist.remove_at(0)
		_trails[id] = hist
	# 🔴 죽은 투사체의 자취를 여기서 안 지우면 딕셔너리가 **영원히 자란다.** 소멸 통지가 없어서
	#  「살아 있는 id 집합」과 대조하는 게 유일한 방법이다.
	for id: int in _trails.keys():
		if not live.has(id):
			_trails.erase(id)


func clear() -> void:
	_trails.clear()
	queue_redraw()


# ══════════════════════════════════════════════════════════════════
#  질의 — 🔴 `_draw()`가 **이 함수들만** 쓴다. 그래서 그물이 재는 값 = 실제로 그려지는 값이다.
# ══════════════════════════════════════════════════════════════════

## 지금 화면에 그려지는 머리 위치. `_alpha`가 0이면 직전 틱, 1이면 이번 틱 자리다.
func head_px(i: int) -> Vector2:
	if not _live(i):
		return Vector2.ZERO
	var px := _sim.get_px()
	var py := _sim.get_py()
	var qx := _sim.get_prev_px()
	var qy := _sim.get_prev_py()
	return Vector2(
		lerpf(float(qx[i]), float(px[i]), _alpha) * FP_TO_PX,
		lerpf(float(qy[i]), float(py[i]), _alpha) * FP_TO_PX)


## 머리부터 꼬리까지. 🔴 **자취의 마지막 기록은 이번 틱의 도착점이라 일부러 뺀다** —
##  머리가 아직 거기 도착하지 않았으므로, 넣으면 자취가 머리보다 앞으로 튀어나간다.
func trail_points(i: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _live(i):
		return out
	out.append(head_px(i))
	var hist: PackedVector2Array = _trails.get(_sim.get_id()[i], PackedVector2Array())
	var k := hist.size() - 2
	while k >= 0:
		out.append(hist[k])
		k -= 1
	return out


## 추적 중인 자취 수. ⚠ 그물이 **누수**를 재는 자리다 — 죽은 투사체가 남으면 여기가 안 줄어든다.
func trail_count() -> int:
	return _trails.size()


# ══════════════════════════════════════════════════════════════════
#  그리기
# ══════════════════════════════════════════════════════════════════

func _draw() -> void:
	if _sim == null:
		_drew = false
		return
	var n := _sim.active_count()
	_drew = n > 0
	# 🔴 자취를 **전부 먼저** 그리고 머리를 나중에 그린다. 한 투사체씩 그리면 뒤 투사체의 자취가
	#  앞 투사체의 머리를 덮는다 — 가산 합성이라 티가 덜 나지만 겹칠 때 머리가 흐려 보인다.
	for i in n:
		_draw_trail(i)
	for i in n:
		_draw_head(i)


func _draw_trail(i: int) -> void:
	var pts := trail_points(i)
	if pts.size() < 2:
		return
	var col: Color = _elem(i)["core"]
	# 🔴 자취 굵기도 머리 크기를 따라간다 — 안 그러면 세대 1이 「가는 탄에 굵은 꼬리」가 된다.
	var w := Fx.TRAIL_PX * Fx.bolt_px(_gen(i)) / Fx.bolt_px(0)
	var segs := pts.size() - 1
	for k in segs:
		# 머리 쪽 1.0 → 꼬리 쪽 0.0. 굵기와 알파를 같이 줄여야 「빨려 들어가는 꼬리」로 보인다.
		var f := 1.0 - float(k) / float(segs)
		draw_line(
			pts[k], pts[k + 1],
			Color(col.r, col.g, col.b, lerpf(Fx.TRAIL_TAIL_A, 1.0, f)),
			maxf(Fx.MIN_DRAW_PX, w * f))


func _draw_head(i: int) -> void:
	var p := head_px(i)
	var e := _elem(i)
	var glow: Color = e["glow"]
	var core: Color = e["core"]
	# 🔴 **머리 크기가 세대를 나른다.** 날아가는 동안 「작은 것들」이 보이는 유일한 축이다.
	var r := Fx.bolt_px(_gen(i))
	draw_circle(p, r * Fx.BOLT_GLOW_RATIO,
		Color(glow.r, glow.g, glow.b, Fx.BOLT_GLOW_A), true)
	draw_circle(p, r, core, true)


func _gen(i: int) -> int:
	if not _live(i):
		return 0
	return int(_sim.get_gen()[i])


func _live(i: int) -> bool:
	return _sim != null and i >= 0 and i < _sim.active_count()


func _elem(i: int) -> Dictionary:
	if not _live(i):
		return Fx.ELEM_FX_MISSING
	return Fx.elem_fx(int(_sim.get_element()[i]))
