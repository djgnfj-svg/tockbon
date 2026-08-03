extends Node2D
## 폭발 연출 — **섬광 · 화면 흔들림.** 🔴 화면만 만진다. 시뮬로 돌아가는 값이 하나도 없다.
##
## 🔴 **스파크가 없다.** 기획 「화면」이 명시적으로 뺐다 — 타격감은 올리지만
##  **조합의 차이를 안 나른다.** 이 단계가 재는 것은 「예쁘다」가 아니라 「두 조합이 갈리나」다.
##
## 🔴🔴 **폭발마다 노드를 `add_child` 하지 마라.** 지금 이 설계에는 물리 노드가 하나도 없어서
##  「물리콜백 한복판의 `add_child`」 함정과 「`queue_free`+그룹」 함정이 **둘 다 소멸해 있다.**
##  노드를 붙이는 순간 둘 다 돌아온다. ⇒ 섬광은 **딕셔너리 항목 하나**이고 `_draw()`가 전부 그린다.
##
## 🔴 **히트스톱은 없다.** `Engine.time_scale`이 `_physics_process`를 멈춰 시뮬 틱이 멈추고,
##  락스텝에서 클라 하나만 멈추면 그대로 desync다. 그 몫은 **흔들림·섬광 지속**이 갚는다.

const SpellSim := preload("res://src/sim/spell_sim.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

## 살아 있는 섬광들. ⚠ 최대 `Fx.FLASH_MAX`개라 `Array[Dictionary]`로 충분하다 —
##  32개를 매 틱 만지는 `spell_sim`과 달리 여기는 드물게 몇 개다.
var _flashes: Array[Dictionary] = []

## 화면 흔들림. 🔴 진폭은 **정수 px**다(`Fx.SHAKE_PX` 주석).
var _shake_px := 0
var _shake_left := 0.0
var _shake_full := 0.0
var _shake_offset := Vector2i.ZERO

## 직전 `_draw()`가 실제로 뭔가 그렸나. 🔴 `CanvasItem`은 **마지막으로 그린 것을 계속 들고 있어서**,
##  섬광이 0이 된 그 한 프레임을 안 다시 그리면 죽은 섬광이 화면에 영원히 박힌다.
##  ⚠ **헤드리스가 원리적으로 못 잰다**(그리지 않는다).
var _drew := false


func _ready() -> void:
	# 🔴 가산 합성. 어두운 배경 위에서 「빛」으로 읽히게 하는 유일한 한 줄이다(`spell_view.gd`와 같다).
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


## ⚠ 시계가 **시뮬 틱이 아니라 프레임 델타**다. 연출이 20Hz에 묶이면 0.21초짜리 섬광이
##  4프레임짜리 깜빡임이 되고, 그러면 「여덟 번의 리듬」이 애초에 안 보인다.
func _process(delta: float) -> void:
	advance(delta)
	if not _flashes.is_empty() or _drew:
		queue_redraw()


# ══════════════════════════════════════════════════════════════════
#  방아쇠 — 🔴 시뮬의 폭발 통지가 들어오는 유일한 문
# ══════════════════════════════════════════════════════════════════

## 껍데기가 `spell.step()` **직후에** 부른다.
##
## ⚠ 인자는 **셀 좌표**다 — px 변환을 여기서 한 번만 한다. 껍데기가 변환해서 넘기면
##  같은 변환이 두 곳이 되고, 그 둘이 갈라지면 「섬광이 구멍에서 조금 빗나간다」로만 보인다.
## 🔴 `PackedInt32Array`를 인자로 받는 건 안전하다 — **읽기만 한다.** 여기서 `append` 하면
##  CoW 사본에 쓰는 것이라 조용히 증발한다(그 함정은 쓰기 쪽에만 있다).
func on_blasts(xs: PackedInt32Array, ys: PackedInt32Array,
		elems: PackedByteArray, gens: PackedByteArray) -> void:
	for k in xs.size():
		# 🔴 섬광 크기·흔들림 세기가 **세대 표에서** 나온다. 고정하면 작은 폭발도 크게 번쩍이고,
		#  그러면 「작은 것들이 약하다」가 화면에서 통째로 사라진다 — v1이 죽은 방식이다.
		var gen := int(gens[k])
		_add(
			Vector2((xs[k] + 0.5) * Tuning.CELL_PX, (ys[k] + 0.5) * Tuning.CELL_PX),
			Fx.flash_px(gen), int(elems[k]))
		# ⚠ **더 센 쪽이 이긴다**(`_kick`) — 세대 0 하나와 세대 1 여덟이 같은 틱에 터져도
		#  화면은 큰 쪽으로 흔들린다.
		_kick(Fx.shake_px(gen), Fx.SHAKE_SEC)


func clear() -> void:
	_flashes.clear()
	_shake_px = 0
	_shake_left = 0.0
	_shake_full = 0.0
	_shake_offset = Vector2i.ZERO
	queue_redraw()


## 🔴 `_process`가 부르는 것과 **같은 함수**다 — 그물이 씬 없이 시간을 흘려보낼 수 있게 공개다.
##  ⚠ 여기가 private면 「수명이 다하면 사라지나」를 헤드리스로 아예 못 잰다.
func advance(dt: float) -> void:
	var i := _flashes.size() - 1
	while i >= 0:
		var e: Dictionary = _flashes[i]
		e["t"] = float(e["t"]) + dt
		if float(e["t"]) >= float(e["life"]):
			_flashes.remove_at(i)
		i -= 1
	_advance_shake(dt)


# ══════════════════════════════════════════════════════════════════
#  질의 — 🔴 `_draw()`가 **이 함수들만** 쓴다. 그래서 그물이 재는 값 = 실제로 그려지는 값이다.
# ══════════════════════════════════════════════════════════════════

func active_count() -> int:
	return _flashes.size()


## 지금 그려지는 섬광 반경. 뜨는 순간 `FLASH_START`배로 시작해 최종 반경까지 퍼진다.
func flash_radius(i: int) -> float:
	if i < 0 or i >= _flashes.size():
		return 0.0
	var e: Dictionary = _flashes[i]
	return float(e["radius"]) * lerpf(Fx.FLASH_START, 1.0, _ease(_norm(e)))


## 지금 그려지는 밝기. 제곱으로 죽어서 **앞이 세고 뒤가 짧다**(타격감이 앞에 몰린다).
func flash_alpha(i: int) -> float:
	if i < 0 or i >= _flashes.size():
		return 0.0
	var k := 1.0 - _norm(_flashes[i])
	return k * k


## 🔴 카메라에 그대로 얹을 값. **껍데기가 `Camera2D.offset`에 넣는다** — 이 노드가 카메라를
##  들고 있지 않은 이유는, 들면 씬 구조를 알게 되어 그물이 씬 없이 못 돌기 때문이다.
func shake_offset() -> Vector2i:
	return _shake_offset


# ══════════════════════════════════════════════════════════════════
#  그리기
# ══════════════════════════════════════════════════════════════════

func _draw() -> void:
	_drew = not _flashes.is_empty()
	for i in _flashes.size():
		var e: Dictionary = _flashes[i]
		var pal := Fx.elem_fx(int(e["elem"]))
		var glow: Color = pal["glow"]
		var core: Color = pal["core"]
		var a := flash_alpha(i)
		var r := flash_radius(i)
		if r < Fx.MIN_DRAW_PX:
			continue
		var pos: Vector2 = e["pos"]
		draw_circle(pos, r, Color(glow.r, glow.g, glow.b, a * Fx.FLASH_GLOW_A), true)
		draw_circle(pos, r * Fx.FLASH_CORE_RATIO, Color(core.r, core.g, core.b, a), true)


# ══════════════════════════════════════════════════════════════════
#  내부
# ══════════════════════════════════════════════════════════════════

func _add(px: Vector2, radius: float, element: int) -> void:
	_flashes.append({
		"pos": px, "elem": element, "t": 0.0,
		"life": Fx.FLASH_SEC, "radius": radius,
	})
	# ⚠ **가장 오래된 것부터** 버린다. 새 것을 버리면 마지막 폭발이 조용히 안 보인다.
	while _flashes.size() > Fx.FLASH_MAX:
		_flashes.remove_at(0)


## 🔴 흔들림은 **겹치는 게 아니라 더 센 쪽이 이긴다.** 더하면 여덟 번 터질 때 화면이 날아간다.
func _kick(px: int, secs: float) -> void:
	if px <= 0 or secs <= 0.0:
		return
	_shake_px = maxi(_shake_px, px)
	_shake_left = maxf(_shake_left, secs)
	_shake_full = maxf(_shake_full, _shake_left)


## ⚠ **끝나는 그 호출 안에서 전부 0으로 돌려놓는다.** 「다음 호출에 정리」로 두면 한 프레임 동안
##  진폭이 남아 있는 상태가 관측되고, 그물이 「안 멎는다」와 「한 틱 늦게 멎는다」를 못 가른다.
func _advance_shake(dt: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(0.0, _shake_left - dt)
	if _shake_left <= 0.0 or _shake_full <= 0.0:
		_shake_px = 0
		_shake_full = 0.0
		_shake_offset = Vector2i.ZERO
		return
	var u := _shake_left / _shake_full
	var amp := float(_shake_px) * pow(u, Fx.SHAKE_DECAY_POW)
	# 🔴 **원 위에서** 뽑는다 — 사각형 균등 난수로 뽑으면 평균 진폭이 절반으로 죽어서
	#  「5px로 올렸는데 2px처럼 보인다」가 된다.
	# ⚠ 여기 `randf()`가 정상인 이유: **연출은 선을 넘지 않는다.** 클라마다 흔들림 방향이
	#  달라도 세상이 한 톨도 안 갈라진다 — 시뮬 난수 금지와 정반대 자리다.
	var ang := randf() * TAU
	_shake_offset = Vector2i(roundi(cos(ang) * amp), roundi(sin(ang) * amp))


func _norm(e: Dictionary) -> float:
	return clampf(float(e["t"]) / float(e["life"]), 0.0, 1.0)


## 빨리 퍼지고 천천히 멎는다.
func _ease(u: float) -> float:
	var k := 1.0 - u
	return 1.0 - k * k
