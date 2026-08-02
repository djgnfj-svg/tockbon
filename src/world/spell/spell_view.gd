extends Node2D
## 투사체·궤적 렌더 — 🔴 **화면만 만진다. 시뮬을 절대 안 바꾼다.**
##
## ══ 🔴🔴 이 파일의 계약 = `spell_sim.gd`의 **정반대**다 ═════════════
##  시뮬은 「정수만」이고 여기는 **float 자유**다. 이유가 정반대라서 맞다 —
##  셀은 이산이라 중간 위치가 없지만, **투사체는 연속체라 중간 위치가 실제로 존재한다.**
##  ⇒ 셀 렌더는 보간을 **안 하는 게** 맞고, 여기는 보간을 **해야** 맞다.
##  ⚠ 보간을 빼면 20Hz 시뮬이라 투사체가 **틱당 40px씩 순간이동한다.**
##
##  🔴 그래서 여기 있는 `float`·`lerpf`·`Vector2`는 전부 정상이다. 반대로
##   **여기서 나온 값이 시뮬로 돌아가면 그 순간 락스텝이 깨진다** — 이 파일은 시뮬을 **읽기만** 한다.
## ══════════════════════════════════════════════════════════════════
##
## 🔴 **투사체당 노드가 0개다.** `_draw()` 하나가 전부 그린다 ⇒ 물리콜백 `add_child` 함정과
##  `queue_free`+그룹 함정이 **둘 다 소멸한다**(`spell_sim.gd` 머리말). 노드로 바꾸면 둘 다 돌아온다.

const SpellSim := preload("res://src/world/spell/spell_sim.gd")
const Tuning := preload("res://src/world/spell/spell_tuning.gd")
const CellRenderer := preload("res://src/world/cells/cell_renderer.gd")

## 고정소수점 셀 좌표 → 화면 px. 🔴 **셀 크기의 단일 소스는 `CellRenderer`다** — 4를 여기 박으면
##  셀 렌더와 투사체가 서로 다른 축척으로 그려지고, 그건 「조준이 미묘하게 빗나간다」로만 보인다(T5).
## ⚠ `1.0 *`가 붙은 이유는 정수 나눗셈을 피하려는 것이다 — 빼면 4/256이 **0이 되고**
##  투사체가 전부 원점에 그려진다(에러는 안 난다).
const FP_TO_PX: float = 1.0 * CellRenderer.CELL_PX / SpellSim.FP_ONE

var _sim: SpellSim = null

## 이번 프레임이 두 틱 사이 어디인가(0=직전 틱 · 1=이번 틱). 껍데기가 매 프레임 밀어 넣는다.
## ⚠ 시계는 시뮬 소유자에게 있다 — 여기서 `delta`를 누산하면 시계가 둘이 된다.
var _alpha := 0.0

## 투사체 id → 지난 틱 위치들(화면 px). 🔴🔴 **키가 슬롯 인덱스가 아니라 id인 게 핵심이다.**
##  소멸이 swap-remove라 슬롯은 틱마다 뒤바뀌고, 인덱스로 들고 있으면 투사체가 죽는 순간
##  **남의 자취가 순간이동한다** — 에러 하나 없이 화면만 이상해진다.
var _trails: Dictionary = {}

## 직전 `_draw()`가 실제로 뭔가 그렸나. 🔴 위 `set_render_alpha` 주석의 걸쇠다.
var _drew := false


func _ready() -> void:
	# 🔴 가산 합성. 어두운 배경 위에서 「빛나는 것」으로 읽히게 하는 유일한 한 줄이다.
	#  ⚠ 테마에 PNG를 물리는 길(StyleBox)로 가면 침묵사한다 — 여기는 코드로만 주입한다.
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func setup(sim: SpellSim) -> void:
	_sim = sim
	_trails.clear()
	queue_redraw()


## 두 틱 사이의 보간 위치. 껍데기가 `_process`마다 부른다.
## ⚠ **그릴 게 없으면 다시 그리지 않는다** — 셀 렌더러가 「활성 청크 0이면 업로드도 건너뛴다」로
##  정지 상태 비용을 0으로 만든 것과 같은 규율이다. 🔴 **`BlastFx`는 반대다** — 총구가 1.6Hz로
##  맥동해서 매 프레임 다시 그리는 게 맞다.
##
## 🔴🔴 **`if active_count() > 0`만 쓰면 안 된다 — 그게 조용히 깨지는 자리다.**
##  `CanvasItem`은 마지막으로 그린 것을 **계속 들고 있는다.** 투사체가 사라진 프레임에 `queue_redraw`를
##  건너뛰면 **죽은 투사체가 화면에 영원히 박혀 있는다** — 에러 하나 없이.
##  ⇒ 「직전에 뭔가 그렸나」를 걸쇠로 들고, **0이 된 그 한 번은 반드시 다시 그린다.**
##  ⚠ 헤드리스는 이걸 못 잰다(그리지 않는다). 걸쇠가 없으면 실게임에서만 드러난다.
func set_render_alpha(a: float) -> void:
	_alpha = clampf(a, 0.0, 1.0)
	if (_sim != null and _sim.active_count() > 0) or _drew:
		queue_redraw()


## 🔴 **시뮬이 한 틱 돈 **뒤**에 부른다.** 순서가 뒤집히면 자취가 한 틱 낡는다.
func on_tick() -> void:
	if _sim == null:
		return
	var n := _sim.active_count()
	var ids := _sim.get_id()
	var px := _sim.get_px()
	var py := _sim.get_py()
	var tier := _sim.get_tier()
	var live: Dictionary = {}
	for i in n:
		var id := ids[i]
		live[id] = true
		# ⚠ `PackedVector2Array`는 CoW 값 타입이다 — 꺼내 쓰고 **반드시 되넣어야** 한다.
		#  안 넣으면 append가 에러 없이 증발한다(`cell_grid.gd`가 `_charge_next`로 데인 자리).
		var hist: PackedVector2Array = _trails.get(id, PackedVector2Array())
		hist.append(Vector2(float(px[i]) * FP_TO_PX, float(py[i]) * FP_TO_PX))
		var keep := int(_fx(tier[i])["trail_ticks"])
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


func trail_width(i: int) -> float:
	if not _live(i):
		return 0.0
	return float(int(_fx(_sim.get_tier()[i])["trail_px"]))


## 🔴 **날아가는 0.3초 동안 위력 단이 눈에 보이는 유일한 축이다.** 여기를 고정하면 그게 v1이다.
func bolt_radius(i: int) -> float:
	if not _live(i):
		return 0.0
	return float(int(_fx(_sim.get_tier()[i])["bolt_px"]))


## 추적 중인 자취 수. ⚠ 그물이 **누수**를 재는 자리다 — 죽은 투사체가 남으면 여기가 안 줄어든다.
func trail_count() -> int:
	return _trails.size()


## 이 id가 **마지막으로 기록된 자리**. 없으면 `Vector2.INF`.
## 🔴🔴 **터진 투사체의 「마지막으로 보이던 자리」를 꺼내는 문이다.** 시뮬이 투사체를 터진 그 틱에
##  제거해서, 이걸 안 꺼내면 착탄점까지 날아가는 그림이 통째로 없다(`Tuning.STREAK_FRAC` 주석).
## ⚠ **호출 시점이 계약이다** — `on_tick()`이 죽은 id를 지우므로 **그 전에** 꺼내야 한다.
##  껍데기의 틱 순서가 그래서 「폭발 통지 → `on_tick`」이다. 뒤집으면 조용히 `INF`만 나온다.
func last_trail_px(id: int) -> Vector2:
	var hist: PackedVector2Array = _trails.get(id, PackedVector2Array())
	if hist.is_empty():
		return Vector2.INF
	return hist[hist.size() - 1]


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
	var w := trail_width(i)
	var segs := pts.size() - 1
	for k in segs:
		# 머리 쪽 1.0 → 꼬리 쪽 0.0. 굵기와 알파를 같이 줄여야 「빨려 들어가는 꼬리」로 보인다.
		var f := 1.0 - float(k) / float(segs)
		draw_line(
			pts[k], pts[k + 1],
			Color(col.r, col.g, col.b, lerpf(Tuning.TRAIL_TAIL_A, 1.0, f)),
			maxf(Tuning.MIN_DRAW_PX, w * f))


func _draw_head(i: int) -> void:
	var p := head_px(i)
	var r := bolt_radius(i)
	var e := _elem(i)
	var glow: Color = e["glow"]
	var core: Color = e["core"]
	draw_circle(p, r * Tuning.BOLT_GLOW_RATIO,
		Color(glow.r, glow.g, glow.b, Tuning.BOLT_GLOW_A), true)
	draw_circle(p, r, core, true)


# ══════════════════════════════════════════════════════════════════
#  내부
# ══════════════════════════════════════════════════════════════════

func _live(i: int) -> bool:
	return _sim != null and i >= 0 and i < _sim.active_count()


## ⚠ 단을 **클램프한다** — 시뮬이 단을 늘리고 FX 표가 안 따라오면 여기서 죽는 대신 마지막 단으로
##  떨어진다. 그 상태를 조용히 두면 안 되므로 N8이 길이 불일치를 따로 빨갛게 세운다.
func _fx(tier: int) -> Dictionary:
	return Tuning.FX_TIERS[clampi(tier, 0, Tuning.FX_TIERS.size() - 1)]


func _elem(i: int) -> Dictionary:
	if not _live(i):
		return Tuning.ELEM_FX_MISSING
	var e := int(_sim.get_element()[i])
	return Tuning.ELEM_FX.get(e, Tuning.ELEM_FX_MISSING)
