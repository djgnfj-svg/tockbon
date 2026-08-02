extends Node2D
## 마나 폭발 — 적이 죽으면 몸에 박혀 있던 마법 빛이 터져 나와 흩어진다.
## 코어 섬광 + 팽창 링 + 사방으로 튀는 파편. 🔴 마나 수치는 안 준다(순수 연출).
##
## 🔴🔴 **플레이어 쪽으로 수렴하는 궤적을 넣지 마라** — 넣는 순간 *"주웠나?"*가 생기는데, 이건
##   삼켜져 있던 빛이 **풀려나는** 그림이지 **수확하는** 그림이 아니다. 드롭은 모여들고 마나는
##   흩어져서 궤적만으로 「전리품 vs 죽음」이 갈린다. 🔴 그물이 **「안 가나」**를 재는 것도 그래서다
##   (일부러 안 하는 것은 그물이 없으면 조용히 뒤집힌다).
##
## 🔴 **색은 마나 푸른색 하나다 — 룬 속성별로 가르지 마라.** 가르면 *"무슨 마나인가"*라는 없는 축이
##   생긴다. 그래서 이 파일은 `RuneDef.ui_color`도 `status_rules`도 안 본다.
##
## 🔴 **크기·파편 수의 파생원은 `setup(body_px)` 하나 = 프레임 한 변 × global_scale.** 한 변만 보면
##   덩치 배수를 놓쳐 **86px 몸에 64px짜리 폭발**이 터져 시체보다 작아진다.
##
## 🔴 **노드 하나가 전부를 그린다**(자식 0 · 트윈 0 · `_draw` 하나) — 파편마다 노드를 심으면
##   광역 마법으로 다섯을 같은 프레임에 죽일 때 노드가 5+5×7로 튄다.
## 🔴 **수명을 스스로 쥔다** — 적은 곧바로 `queue_free`되므로 이 노드는 current_scene에 붙어
##   적보다 오래 산다.

# ── 색 (룬 색도 상태 색도 아니라 파생원이 없다 — 팔레트의 청 램프 3단 그대로) ──────────
const MANA_CORE := Color(0.643, 0.867, 0.859)    ## A4DDDB — 터지는 순간의 심지(가장 밝다)
const MANA_BRIGHT := Color(0.451, 0.745, 0.827)  ## 73BED3 — 파편·링 본색
const MANA_DEEP := Color(0.310, 0.561, 0.729)    ## 4F8FBA — 짙은 쪽 파편(떼에 결이 생긴다)

## 🔴 계약 상수 — `vfx.gd`의 `VFX_Z := 55`가 「죽음 연출 위로」의 근거로 이 값을 든다.
## 바꾸려면 거기 주석도 같은 커밋에 고쳐라.
const BURST_Z := 50

# ── 기하: 전부 **보이는 몸 한 변**의 비율이다 (px로 박으면 덩치를 안 탄다) ──────────
## 🔴 코어는 **몸보다 커야 한다** — 스프라이트가 같은 프레임에 사라지므로 작으면
##  「몸이 터졌다」가 아니라 「작은 파란 게 나타났다」로 읽힌다.
const CORE_FRAC := 0.42       ## 터짐 코어 반지름 = 몸 한 변 × 이 값
const RING_FRAC := 0.78       ## 팽창 링이 닿는 최대 반지름
const RING_W_FRAC := 0.060    ## 링 굵기
const RING_W_MIN := 1.6       ## 링 최소 굵기(px) — 작은 몸에서 선이 사라지지 않게
## 🔴 링은 **퍼질수록 가늘어진다** — 굵기가 일정하면 「원이 커진다」고 읽히고, 얇아지면
##   **충격파가 잦아든다**로 읽힌다(같은 궤적인데 뜻이 다르다).
const RING_W_START := 1.7     ## 링 굵기 배수: 시작
const RING_W_END := 0.45      ## 링 굵기 배수: 끝
const SHARD_LEN_FRAC := 0.26  ## 파편 길이
const SHARD_W_FRAC := 0.070   ## 파편 반폭 — 뾰족해야 「조각」이지 「알갱이」가 아니다
const SHARD_DIST_FRAC := 0.62 ## ② 터지는 힘으로 튀어나가는 거리
## 🔴 ③ 터진 뒤에도 계속 뻗는다(급감속). 0이면 파편이 제자리에 박힌 채 꺼져 「흩어진다」가 아니라
##   「점멸한다」가 된다.
const SHARD_DRIFT_FRAC := 0.34
## 🔴 ③ 떠오른다 — 흩어지는 데 방향이 하나 있어야 「돌아갔다」로 읽힌다(그냥 옅어지면 「꺼졌다」다).
##   ⚠ 플레이어 쪽은 안 된다(머리말 — 각하된 궤적이다).
const SHARD_RISE_FRAC := 0.34
const SHARD_SHRINK := 0.55    ## ④ 사라질 때까지 줄어드는 배수 (페이드와 같이 걸려야 「흩어져 사라진다」)
const SHARD_SPREAD := 0.35    ## 거리 흔들림(±) — 균등하면 방사 대칭이 기계적이다
const SHARD_ANGLE_JITTER := 0.30  ## 각도 흔들림(rad, ±)

# ── 개수: 몸에서 파생 ──────────────────────────────────────────────────────────
const SHARD_BASE := 4         ## 아무리 작아도 이만큼은 튄다
const SHARD_PER_PX := 0.05    ## 보이는 몸 한 변 px마다
const SHARD_MIN := 6
const SHARD_MAX := 16         ## 🔴 상한 = 다중 처치 과부하 방어
## 보스는 더 크고 파편도 많다. ⚠ 판별은 `params.ai`가 `boss_`로 시작하나 — 새 키를 안 만든다.
const BOSS_COUNT_MULT := 1.75
const BOSS_SIZE_MULT := 1.35

# ── 시간 (연출값 — 밸런스 아님. 손맛은 F5가 조인다) ──────────────────────────────
## 🔴 **코어와 링의 수명이 갈려 있다.** 하나로 묶으면 큰 반투명 원반이 링 안을 내내 채워
##   터짐이 아니라 **「파란 접시」**가 된다. 코어 = 곧장 꺼지는 섬광, 링 = 퍼지는 충격파.
const CORE_SEC := 0.10        ## ① 코어 섬광이 사는 시간(s)
const RING_SEC := 0.24        ## ① 팽창 링이 사는 시간(s)
const OUT_SEC := 0.16         ## ② 파편이 터지는 힘으로 튀는 시간(s)
## ③④ 흩어져 사라지는 시간(s) — 짧으면 죽음이 툭 끊기고, 길면 시체 자리에 파란 게 늘어진다.
const FADE_SEC := 0.30
## 🔴 **흩어지는 앞부분은 안 꺼진다** — 터지자마자 옅어지면 파편이 퍼지는 게 보이기도 전에 사라져
##   「흩어졌다」가 아니라 「증발했다」로 읽힌다. 이 비율만큼은 제 색·제 크기로 퍼진 다음 꺼진다.
const FADE_HOLD := 0.35
## 버틴 뒤 꺼지는 곡선. 1.0(선형)보다 크면 처음엔 진하게 버티다 끝에 빨리 꺼진다.
const FADE_POW := 1.4

const RING_SEGS := 28         ## 링 원 분할 수

## 튀어나가는 쪽은 **감속**이다(터진 힘이 잦아든다).
const OUT_EASE_POW := 2.5
## 흩어지는 쪽은 더 세게 감속한다 — 계속 같은 속도로 뻗으면 「날아간다」로 읽힌다.
const DRIFT_EASE_POW := 2.0

var _t: float = 0.0
var _life: float = 0.0
var _count: int = 0
var _core_r: float = 0.0
var _ring_r: float = 0.0
var _ring_w: float = 0.0
var _shard_len: float = 0.0
var _shard_w: float = 0.0
var _dist: float = 0.0
var _drift_px: float = 0.0
var _rise_px: float = 0.0
## 파편마다의 흔들림 — `setup`에서 한 번만 굴린다(매 프레임 굴리면 파편이 떨린다).
var _angles: PackedFloat32Array = PackedFloat32Array()
var _spread: PackedFloat32Array = PackedFloat32Array()


## `body_px` = 보이는 몸 한 변(프레임 한 변 × global_scale) — 파생원 하나다.
## ⚠ **플레이어를 안 받는다** — 인자를 되살리려는 순간이 곧 각하된 수렴 궤적을 되살리는 순간이다.
func setup(body_px: float, boss: bool) -> void:
	var side := maxf(body_px, 8.0)
	var size_mult := BOSS_SIZE_MULT if boss else 1.0
	_core_r = side * CORE_FRAC * size_mult
	_ring_r = side * RING_FRAC * size_mult
	_ring_w = maxf(side * RING_W_FRAC, RING_W_MIN)
	_shard_len = side * SHARD_LEN_FRAC * size_mult
	_shard_w = side * SHARD_W_FRAC * size_mult
	_dist = side * SHARD_DIST_FRAC * size_mult
	_drift_px = side * SHARD_DRIFT_FRAC * size_mult
	_rise_px = side * SHARD_RISE_FRAC * size_mult
	var n := SHARD_BASE + roundi(side * SHARD_PER_PX)
	if boss:
		n = roundi(float(n) * BOSS_COUNT_MULT)
	_count = clampi(n, SHARD_MIN, SHARD_MAX)
	# 🔴 균등 각도 + 흔들림 — 완전 균등이면 방사 대칭이 기계적이고, 완전 랜덤이면 한쪽에 뭉쳐
	#   「사방으로」가 깨진다.
	var base := randf() * TAU
	_angles.resize(_count)
	_spread.resize(_count)
	for i in _count:
		_angles[i] = base + TAU * float(i) / float(_count) \
			+ randf_range(-SHARD_ANGLE_JITTER, SHARD_ANGLE_JITTER)
		_spread[i] = 1.0 + randf_range(-SHARD_SPREAD, SHARD_SPREAD)
	_life = OUT_SEC + FADE_SEC
	z_index = BURST_Z
	queue_redraw()


# ── 공개 관측점 (헤드리스는 「예쁜가」를 못 재도 아래는 잰다) ────────────────────────

## 이번 폭발의 파편 수 — 「덩치에 따라 는다」의 측정 가능한 형태.
func shard_count() -> int:
	return _count


## 링이 닿는 최대 반지름(월드 px). ⚠ 되계산하지 않고 **실제로 그리는 값**을 돌려준다.
func burst_radius() -> float:
	return _ring_r


## 지금 파편이 실제로 그려지는 자리(월드) — 🔴 그물이 「흩어지나 · 누구에게도 안 모이나」를 재는
## 자리다. 상태 변수가 아니라 `_draw`가 쓰는 그 계산을 그대로 돌려준다.
func shard_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	var xf := global_transform
	for i in _count:
		out.append(xf * _shard_local(i))
	return out


## 0(막 터졌다) ~ 1(다 사라졌다).
func progress() -> float:
	return clampf(_t / maxf(_life, 0.0001), 0.0, 1.0)


## 🔴🔴 **`_process`가 아니라 `_physics_process`인 것이 계약이다** — 헤드리스에서 시간이 결정적이어야
##  한다. `_process`의 delta는 fps 상한이 풀린 테스트 실행에서 제멋대로라 그물이 **몇 프레임을 돌려야
##  몇 초인지 모른다.** 물리 delta는 1/60 고정이라 `await physics_frame`이 곧 시간이 된다.
func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= _life:
		queue_free()


func _draw() -> void:
	# 🔴 스프라이트가 같은 프레임에 사라지므로 **코어가 그 자리를 이어받는 물건**이다 —
	#   작게 시작하면 한 프레임 「몸이 없는」 구멍이 보인다.
	if _t < CORE_SEC:
		var tc := clampf(_t / CORE_SEC, 0.0, 1.0)
		var core := MANA_CORE
		# 🔴 급히 꺼진다(제곱) — 천천히 꺼지면 큰 반투명 원반이 링 안에 앉아 평평해진다.
		core.a = pow(1.0 - tc, 2.0) * 0.95
		draw_circle(Vector2.ZERO, _core_r * lerpf(1.0, 1.35, tc), core)
	if _t < RING_SEC:
		var tr := clampf(_t / RING_SEC, 0.0, 1.0)
		var eo := 1.0 - pow(1.0 - tr, 3.0)
		var ring := MANA_BRIGHT
		ring.a = pow(1.0 - tr, 1.4)
		draw_arc(Vector2.ZERO, _ring_r * lerpf(0.26, 1.0, eo), 0.0, TAU, RING_SEGS,
			ring, _ring_w * lerpf(RING_W_START, RING_W_END, eo), true)

	var alpha := _shard_alpha()
	if alpha <= 0.0:
		return
	# 🔴 줄어들기와 페이드를 **같이** 건다 — 하나만 걸면 「작아지며 남는다」나 「제 크기로 꺼진다」가
	#   되고, 둘 다 「흩어져 사라졌다」로는 안 읽힌다.
	var shrink := lerpf(1.0, SHARD_SHRINK, _vanish_t())
	var ln := _shard_len * shrink
	var w := _shard_w * shrink
	for i in _count:
		var pos := _shard_local(i)
		# 🔴 파편은 **끝까지 바깥을 향한다** — 방향이 도는 순간 「무언가에 끌린다」가 된다.
		var aim := Vector2.from_angle(_angles[i])
		var perp := aim.orthogonal()
		var col := MANA_BRIGHT if i % 2 == 0 else MANA_DEEP
		col.a = alpha
		draw_colored_polygon(PackedVector2Array([
			pos + aim * ln * 0.62,
			pos + perp * w,
			pos - aim * ln * 0.38,
			pos - perp * w,
		]), col)


## 파편 i의 지금 자리(로컬) = 터진 힘(감속) + 이어지는 흩어짐(더 급감속) + 떠오름.
## 🔴 `_draw`와 `shard_positions()`가 **같은 함수**를 쓴다 — 따로 계산하면 그물이 거짓 그린이 된다.
func _shard_local(i: int) -> Vector2:
	if i < 0 or i >= _count:
		return Vector2.ZERO
	var dir := Vector2.from_angle(_angles[i])
	var ta := clampf(_t / OUT_SEC, 0.0, 1.0)
	var td := _drift_t()
	var out_r := _dist * _spread[i] * (1.0 - pow(1.0 - ta, OUT_EASE_POW)) \
		+ _drift_px * _spread[i] * (1.0 - pow(1.0 - td, DRIFT_EASE_POW))
	return dir * out_r + Vector2(0.0, -_rise_px * (1.0 - pow(1.0 - td, 2.0)))


## 흩어짐 진행 0~1 — 터진 힘이 다한 뒤부터 센다.
func _drift_t() -> float:
	return clampf((_t - OUT_SEC) / FADE_SEC, 0.0, 1.0)


## 꺼짐 진행 0~1 — 🔴 **흩어짐과 다른 시계다**(`FADE_HOLD`만큼 늦게 시작한다).
## 위치는 `_drift_t`가, 사라짐은 이게 판다 — 갈라 둬야 「퍼진 다음 꺼진다」가 나온다.
func _vanish_t() -> float:
	return clampf((_drift_t() - FADE_HOLD) / maxf(1.0 - FADE_HOLD, 0.0001), 0.0, 1.0)


## 버틴 뒤 뒤로 갈수록 빨리 꺼진다.
func _shard_alpha() -> float:
	return pow(1.0 - _vanish_t(), FADE_POW)
