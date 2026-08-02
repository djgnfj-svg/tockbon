extends Node2D
## 폭발 연출 — **섬광 · 스파크 · 총구 · 화면 흔들림.** 🔴 화면만 만진다.
##
## ══ 🔴🔴 여기 있는 `randf()`가 정상인 이유 ═══════════════════════
##  `spell_sim.gd`는 난수가 **금지**다(스트림이라 호출 횟수 하나만 달라도 영원히 갈라진다).
##  여기는 정반대다 — **연출은 선을 넘지 않는다.** 클라마다 스파크가 다른 각도로 튀어도
##  세상은 한 톨도 안 갈라진다. ⇒ 시뮬 난수는 `CellHash`, 연출 난수는 `randf()`가 맞다.
##  ⚠ **여기서 나온 값이 커맨드가 되는 순간** 그 계약이 깨진다. 이 파일은 아무것도 안 돌려준다.
## ══════════════════════════════════════════════════════════════════
##
## 🔴 **폭발마다 `GPUParticles2D`를 `add_child` 하지 마라.** 지금 이 설계에는 물리 노드가 하나도
##  없어서 「물리콜백 한복판의 `add_child`」 함정과 「`queue_free`+그룹」 함정이 **둘 다 소멸해
##  있다.** 노드를 붙이는 순간 둘 다 돌아오고, 전자는 엔진 ERROR 집계로만 잡힌다.
##  ⇒ 섬광도 스파크도 **딕셔너리 항목 하나**이고 `_draw()`가 전부 그린다.
##
## 🔴 **히트스톱은 없다.** `Engine.time_scale`이 `_physics_process`를 멈춰 시뮬 틱이 멈추고,
##  락스텝에서 클라 하나만 멈추면 그대로 desync다(설계 §8). 그 몫은 **흔들림·섬광 지속**이 갚는다.

const Tuning := preload("res://src/world/spell/spell_tuning.gd")

## 살아 있는 섬광들. ⚠ 최대 `Tuning.FX_MAX`개라 `Array[Dictionary]`로 충분하다 —
##  32개짜리 평행 배열로 짜면 읽기만 어려워지고 얻는 게 없다(`SpellSim`은 틱마다 32개를 만져서 반대다).
var _fx: Array[Dictionary] = []

## 화면 흔들림. 🔴 진폭은 **정수 px**다 — `snap_2d_transforms_to_pixel`이 켜져 있어 소수부는
##  어차피 버려진다. float으로 들고 있으면 「0.5px로 줄였는데 아무 일도 안 난다」가 된다.
var _shake_px := 0
var _shake_left := 0.0
var _shake_full := 0.0
var _shake_offset := Vector2i.ZERO

var _clock := 0.0

## 총구. 🔴 **쏘기 전에도 위력 단만큼 밝다** — v1이 죽은 항목 중 하나가 「총구가 위력을 안
##  따라간다」였다. 껍데기가 매 프레임 밀어 넣는다.
## ⚠ 기본이 `false`다 — 캐릭터가 없는 이 프로토타입에서만 켠다. 켤 소비자가 없으면 그냥 안 그린다.
var muzzle_px := Vector2.ZERO
var muzzle_tier := 0
var muzzle_element := Tuning.ELEM_WATER
var muzzle_visible := false


func _ready() -> void:
	# 🔴 가산 합성. 섬광이 「빛」으로 읽히는 유일한 한 줄이다(`spell_view.gd`와 같다).
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


## ⚠ 시계가 **시뮬 틱이 아니라 프레임 델타**다. 연출은 20Hz에 묶일 이유가 없고, 묶으면
##  0.14초짜리 P1 섬광이 3프레임짜리 깜빡임이 된다.
func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()


# ══════════════════════════════════════════════════════════════════
#  방아쇠
# ══════════════════════════════════════════════════════════════════

## 폭발 하나. `px`는 **화면 px**다(셀 좌표가 아니다 — 변환은 껍데기가 한다).
##
## 🔴 `from_px` = **투사체가 마지막으로 보이던 자리.** 거기서 착탄점까지 짧은 줄기를 그어
##  「탄이 벽에 닿기 직전에 사라지고 그 앞쪽에서 터진다」를 메운다(`Tuning.STREAK_FRAC` 주석).
##  ⚠ 안 주면(`INF`) 줄기 없이 예전 그림이다 — **모르면 안 그리는 게 맞다.** 엉뚱한 점에서
##   줄기를 그으면 「마법이 이상한 데서 튀어나온다」가 된다.
func add_blast(px: Vector2, tier: int, element: int, from_px: Vector2 = Vector2.INF) -> void:
	var fx := _fx_of(tier)
	_spawn(px, tier, element, 1.0, int(fx["sparks"]), _ms(int(fx["flash_ms"])), from_px)
	_kick(int(fx["shake_px"]), _ms(int(fx["shake_ms"])))


## 총구 섬광. 🔴 **발사 즉시 로컬로 친다** — 커맨드가 아니다(설계 §9).
## ⚠ 폭발보다 작고 짧지만 **단은 그대로 따라간다.** 여기를 고정하면 v1의 그 항목이 그대로 재발한다.
func add_muzzle(px: Vector2, tier: int, element: int) -> void:
	var fx := _fx_of(tier)
	_spawn(px, tier, element, Tuning.MUZZLE_SCALE,
		maxi(2, int(fx["sparks"]) / 4),
		_ms(int(fx["flash_ms"])) * Tuning.MUZZLE_SCALE)
	_kick(int(fx["shake_px"]) / Tuning.MUZZLE_SHAKE_DIV,
		_ms(int(fx["shake_ms"])) / float(Tuning.MUZZLE_SHAKE_DIV))


func clear() -> void:
	_fx.clear()
	_shake_px = 0
	_shake_left = 0.0
	_shake_full = 0.0
	_shake_offset = Vector2i.ZERO
	queue_redraw()


## 🔴 `_process`가 부르는 것과 **같은 함수**다 — 그물이 씬 없이 시간을 흘려보낼 수 있게 공개다.
##  ⚠ 여기가 private면 「수명이 다하면 사라지나」를 헤드리스로 아예 못 잰다.
func advance(dt: float) -> void:
	_clock += dt
	var i := _fx.size() - 1
	while i >= 0:
		var e: Dictionary = _fx[i]
		e["t"] = float(e["t"]) + dt
		if float(e["t"]) >= float(e["life"]):
			_fx.remove_at(i)
		i -= 1
	_advance_shake(dt)


# ══════════════════════════════════════════════════════════════════
#  질의 — 🔴 `_draw()`가 **이 함수들만** 쓴다. 그물이 재는 값 = 실제로 그려지는 값이다.
# ══════════════════════════════════════════════════════════════════

func active_count() -> int:
	return _fx.size()


## 지금 그려지는 섬광 반경. 뜨는 순간 `FLASH_START`배로 시작해 최종 반경까지 퍼진다.
func flash_radius(i: int) -> float:
	if i < 0 or i >= _fx.size():
		return 0.0
	var e: Dictionary = _fx[i]
	return float(e["radius"]) * lerpf(Tuning.FLASH_START, 1.0, _ease(_norm(e)))


## 지금 그려지는 밝기. 제곱으로 죽어서 **앞이 세고 뒤가 짧다**(타격감이 앞에 몰린다).
func flash_alpha(i: int) -> float:
	if i < 0 or i >= _fx.size():
		return 0.0
	var k := 1.0 - _norm(_fx[i])
	return k * k


func spark_count(i: int) -> int:
	if i < 0 or i >= _fx.size():
		return 0
	var dirs: PackedVector2Array = _fx[i]["dirs"]
	return dirs.size()


## 착탄 줄기의 시작점. `INF`면 줄기가 없다(껍데기가 안 넘겼거나 총구다).
## ⚠ 그물이 **껍데기가 실제로 넘기나**를 재는 자리다 — 안 넘겨도 화면은 「예전처럼」 멀쩡해 보인다.
func streak_from(i: int) -> Vector2:
	if i < 0 or i >= _fx.size():
		return Vector2.INF
	return _fx[i]["from"]


## 🔴 `_draw()`가 색을 고르는 **바로 그 함수**다 — 공개인 이유는 그물이 마젠타 폴백을 재기 위해서다.
##  원소를 늘리고 색을 잊는 게 정확히 T8인데, 「비명을 지르는 장치」 자체는 아무도 안 재고 있었다.
func elem_palette(element: int) -> Dictionary:
	return _elem_fx(element)


## 이번 흔들림의 **최대** 진폭(정수 px). 지금 값이 아니라 시작 값이다.
func shake_amp_px() -> int:
	return _shake_px


## 카메라에 그대로 얹을 값. 🔴 **껍데기가 `Camera2D.offset`에 넣는다** — 이 노드가 카메라를
##  들고 있지 않은 이유는, 들면 씬 구조를 알게 되어 그물이 씬 없이 못 돌기 때문이다.
##  ⚠ 껍데기 `_process`와 이 노드 `_process`의 순서는 보장이 없어 **한 프레임 늦을 수 있다** —
##   16ms짜리 흔들림에서는 관측 불가다.
func shake_offset() -> Vector2i:
	return _shake_offset


## 대기 중 총구 무리의 반경. 🔴 **위력 단이 쏘기 전에 화면에 보이는 자리다.**
func muzzle_radius() -> float:
	var pulse := 1.0 + Tuning.MUZZLE_PULSE_AMP * sin(_clock * TAU * Tuning.MUZZLE_PULSE_HZ)
	return float(int(_fx_of(muzzle_tier)["bolt_px"])) * Tuning.MUZZLE_IDLE_RATIO * pulse


# ══════════════════════════════════════════════════════════════════
#  그리기
# ══════════════════════════════════════════════════════════════════

func _draw() -> void:
	for i in _fx.size():
		_draw_flash(i)
	if muzzle_visible:
		_draw_muzzle()


func _draw_flash(i: int) -> void:
	var e: Dictionary = _fx[i]
	var pos: Vector2 = e["pos"]
	var pal := _elem_fx(int(e["elem"]))
	var glow: Color = pal["glow"]
	var core: Color = pal["core"]
	var a := flash_alpha(i)
	var r := flash_radius(i)
	draw_circle(pos, r, Color(glow.r, glow.g, glow.b, a * Tuning.FLASH_GLOW_A), true)
	draw_circle(pos, r * Tuning.FLASH_CORE_RATIO, Color(core.r, core.g, core.b, a), true)

	var u := _norm(e)
	var prog := _ease(u)
	var tail := float(e["reach"]) * Tuning.SPARK_TAIL * (1.0 - u)
	var w := maxf(1.0,
		float(int(_fx_of(int(e["tier"]))["trail_px"])) * Tuning.SPARK_WIDTH_RATIO * (1.0 - u))
	var sc := Color(core.r, core.g, core.b, a)
	var dirs: PackedVector2Array = e["dirs"]
	var dist: PackedFloat32Array = e["dist"]
	for k in dirs.size():
		var d := dist[k] * prog
		var p1 := pos + dirs[k] * d
		var p0 := pos + dirs[k] * maxf(0.0, d - tail)
		# 길이가 1px 아래로 줄면 그리는 값이 없다 — 스파크 32개 × 섬광 16개에서 이게 쌓인다.
		if p0.distance_squared_to(p1) < Tuning.MIN_DRAW_PX:
			continue
		draw_line(p0, p1, sc, w)

	# 🔴 착탄 줄기 — 투사체가 마지막으로 보이던 자리에서 여기까지. 섬광보다 **빨리** 죽는다
	#  (한 프레임을 메우는 게 목적이라 오래 남으면 「선이 박혀 있다」로 보인다).
	var from: Vector2 = e["from"]
	if from.is_finite() and u < Tuning.STREAK_FRAC and from.distance_squared_to(pos) >= Tuning.MIN_DRAW_PX:
		var sa := 1.0 - u / Tuning.STREAK_FRAC
		draw_line(from, pos, Color(core.r, core.g, core.b, sa),
			maxf(Tuning.MIN_DRAW_PX,
				float(int(_fx_of(int(e["tier"]))["trail_px"])) * Tuning.STREAK_WIDTH_RATIO))


func _draw_muzzle() -> void:
	var pal := _elem_fx(muzzle_element)
	var glow: Color = pal["glow"]
	var core: Color = pal["core"]
	var r := muzzle_radius()
	draw_circle(muzzle_px, r, Color(glow.r, glow.g, glow.b, Tuning.MUZZLE_IDLE_A), true)
	draw_circle(muzzle_px, r * Tuning.MUZZLE_CORE_RATIO, core, true)


# ══════════════════════════════════════════════════════════════════
#  내부
# ══════════════════════════════════════════════════════════════════

func _spawn(px: Vector2, tier: int, element: int, scale: float, spark_n: int, life: float,
		from_px: Vector2 = Vector2.INF) -> void:
	var fx := _fx_of(tier)
	var reach := float(int(fx["spark_px"])) * scale
	var dirs := PackedVector2Array()
	var dist := PackedFloat32Array()
	var n := maxi(spark_n, 1)
	for k in n:
		# 균등 방사 + 지터. 🔴 지터가 없으면 폭죽이 아니라 **도표**로 보인다.
		var ang := TAU * float(k) / float(n) + randf_range(-Tuning.SPARK_SPREAD, Tuning.SPARK_SPREAD)
		dirs.append(Vector2(cos(ang), sin(ang)))
		dist.append(reach * randf_range(Tuning.SPARK_SPEED_MIN, 1.0))
	_fx.append({
		"pos": px,
		"tier": clampi(tier, 0, Tuning.FX_TIERS.size() - 1),
		"elem": element,
		"t": 0.0,
		"life": maxf(life, 0.001),
		"radius": float(int(fx["flash_px"])) * scale,
		"reach": reach,
		"dirs": dirs,
		"dist": dist,
		"from": from_px,
	})
	# ⚠ **가장 오래된 것부터** 버린다. 새 것을 버리면 큰 폭발이 조용히 안 보이는 일이 생긴다.
	while _fx.size() > Tuning.FX_MAX:
		_fx.remove_at(0)


## 흔들림은 **겹치는 게 아니라 더 센 쪽이 이긴다.** 더하면 P3 두 방에 화면이 날아간다.
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
	var amp := float(_shake_px) * pow(u, Tuning.SHAKE_DECAY_POW)
	# 🔴 **원 위에서** 뽑는다 — 사각형 균등 난수로 뽑으면 평균 진폭이 절반으로 죽어서
	#  「11px로 올렸는데 5px처럼 보인다」가 된다.
	var ang := randf() * TAU
	_shake_offset = Vector2i(roundi(cos(ang) * amp), roundi(sin(ang) * amp))


func _norm(e: Dictionary) -> float:
	return clampf(float(e["t"]) / float(e["life"]), 0.0, 1.0)


## 빨리 퍼지고 천천히 멎는다.
func _ease(u: float) -> float:
	var k := 1.0 - u
	return 1.0 - k * k


func _ms(v: int) -> float:
	return float(v) / 1000.0


## ⚠ 단을 **클램프한다** — 시뮬 단이 늘고 FX 표가 안 따라오면 여기서 죽는 대신 마지막 단으로
##  떨어진다. 그 상태를 조용히 두면 안 되므로 N8이 길이 불일치를 따로 빨갛게 세운다.
func _fx_of(tier: int) -> Dictionary:
	return Tuning.FX_TIERS[clampi(tier, 0, Tuning.FX_TIERS.size() - 1)]


func _elem_fx(element: int) -> Dictionary:
	return Tuning.ELEM_FX.get(element, Tuning.ELEM_FX_MISSING)
