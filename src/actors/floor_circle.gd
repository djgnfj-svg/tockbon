extends Node2D
## 발밑 바닥 마법진 — 조립한 그 마법진이 시전 동안 발밑에 열린다.
##
## 🔴🔴 **이 파일은 그리기만 한다 — 무엇을 그릴지는 `vfx.gd`가 정해서 넘긴다.** 점열은 조립본
## 그 자체고 색은 룬이 판다. 그래서 **매핑표가 없다** — 문양을 늘려도 이 파일은 안 고친다.
##
## 🔴 밑알파(`_alpha`)는 `finish_glow_at` 위에 **따로** 얹는다 — 그것만 쓰면 t=1에서 0으로 꺼져
##   **시전이 끝나기도 전에 원이 사라진다**(맺을 때와 달리 여긴 「켜 두는」 연출이다).
##
## 🔴 수명을 **스스로 안 끝낸다** — 탄이 나가면 `release()`, 끊기면 `cancel()`이 끝낸다.
##   🔴🔴 **`duration`은 「채우는 시간」이지 수명이 아니다**: 다 차면 원은 열린 채 머문다.
##   안전망(`_SAFETY_MULT`+`_SAFETY_HOLD`)만 둘 다 안 올 때를 막는다.

## 🔴 **모듈 간 preload의 명시 예외 — 기하 단일 소스.** 좌표·시간 곡선을 베끼면 조립 판·책과
## 갈라져 「맺을 때 본 그림 ≠ 쓸 때 나오는 그림」이 된다.
const RingBoard := preload("res://src/drawing/ring_board.gd")

# ── 연출값 (밸런스 아님 — 손맛은 F5가 조인다) ────────────────────────────────────
## 🔴 z 순서: Ground·프롭 0 · **여기 1** · 플레이어 2 · 지팡이 3.
## ⚠ 음수로 내리지 마라 — 음수 z는 Ground 뒤로 숨는다.
const FLOOR_Z := 1
const LINE_W_PLAIN := 1.4        ## 무난한 진의 선 굵기(px)
const LINE_W_PERFECT := 2.0      ## 퍼펙트의 선 굵기 — 등급이 굵기로도 읽힌다
## ⚠ 무난한 진의 밑알파 — 「옅게」와 「그래도 시전이 시작된 게 보여야 한다」가 여기서 부딪힌다.
##   안 보이면 이 줄만 올려라.
const ALPHA_PLAIN := 0.42
const ALPHA_PERFECT := 0.80      ## 퍼펙트의 밑알파(밝게)
const GLOW_ALPHA := 0.55         ## 파도 머리가 지날 때 **덧대는** 알파
const GLOW_W := 1.5              ## 파도 머리가 지날 때 **덧대는** 굵기(px)
## 🔴 파도가 바깥에 닿은 뒤 머리 빛이 잦아드는 정규 시간. 없으면 진 윤곽(r≈1)의 머리 빛이
## **최대치로 굳어 「테두리만 두꺼운 도넛」**이 되고 안쪽 구성이 안 읽힌다.
const SETTLE_T := 0.12
const SWEEP_W := 1.6             ## 훑고 지나가는 파도 원호 굵기(px)
const SWEEP_ALPHA := 0.34        ## 그 원호의 알파
const RELEASE_TIME := 0.16       ## 탄이 나갈 때 — **확 퍼지며** 꺼진다(「나갔다」)
const RELEASE_SCALE := 1.35
const CANCEL_TIME := 0.10        ## 끊겼을 때 — **오므라들며** 꺼진다(「접혔다」 = 정반대 읽기)
const CANCEL_SCALE := 0.55
## 안전망 — `release()`/`cancel()`이 둘 다 안 오면 스스로 죽는다. 🔴 넉넉히 잡는다: 연출이 아니라
## 누수 방지라, 짧게 잡으면 히트스톱 한 번에 원이 먼저 꺼진다.
const _SAFETY_MULT := 4.0
## 🔴🔴 **홀드 시간을 수명으로 세지 마라** — `_dur * _SAFETY_MULT`만 보면 오래 들고 있을 때 원이
## 조용히 사라진다(자멸이 `push_warning`이라 `SCRIPT ERROR` grep에도 안 걸린다). 그래서 다 찬
## 뒤엔 이 상한을 따로 얹는다. 🔴 **0이나 무한으로 만들지 마라** — 그러면 원이 영원히 발을 따라다닌다.
const _SAFETY_HOLD := 60.0

## F5 비교 스위치 — 원이 발을 따라가나(true) · 클릭한 자리에 박히나(false).
## 월드 고정이면 **가장 공들인 마법일수록 원이 발밑에서 제일 많이 벗어난다**(가장 오래·가장 느리다).
const FOLLOW_FEET := true

var _paths: Array[PackedVector2Array] = []
var _colors := PackedColorArray()
## 각 서브패스의 정규 반지름 — 룬(≈0) → 층 → 진 윤곽(≈1)이라 파도가 훑는 순서가 곧 연산 순서다.
var _radii := PackedFloat32Array()
var _reveal := PackedFloat32Array()   ## 조각 i가 나타나는 정규 시각 = finish_t_at_radius(_radii[i])
var _settle := 0.6                    ## 파도가 바깥(r=1)에 닿는 정규 시각 — 머리 빛이 잦아들기 시작
var _base_col := Color.WHITE          ## 파도 원호 색 (= 첫 룬 색)
var _ro := 1.0
var _alpha := ALPHA_PLAIN
var _width := LINE_W_PLAIN
var _dur := 0.3
var _t := 0.0                          ## 정규 시전 진행도 0~1
var _age := 0.0                        ## 실제 경과(초) — 안전망 전용
var _ending := false                   ## release/cancel 트윈이 도는 중 (시간축은 멈춘다)
var _follow: Node2D = null             ## 발을 따라갈 대상 (null = 앵커에 박힌다)


## 🔴 `paths`는 **원점(0,0) 기준 로컬 좌표**여야 한다 — 노드 위치가 곧 원의 중심이라 발을 따라갈 때
## 점열을 다시 안 만든다. `colors`는 `paths`와 **같은 길이**(융합진은 룬 자리가 서로 다른 색이다).
func setup(paths: Array[PackedVector2Array], colors: PackedColorArray, ro: float,
		duration: float, quality: float, follow: Node2D) -> void:
	_paths = paths
	_colors = colors
	_ro = maxf(ro, 1.0)
	# 🔴 시전 시간이 0이어도 0으로 나누지 않게 — 그때는 첫 프레임에 다 그린다.
	_dur = maxf(duration, 0.0001)
	_alpha = lerpf(ALPHA_PLAIN, ALPHA_PERFECT, quality)
	_width = lerpf(LINE_W_PLAIN, LINE_W_PERFECT, quality)
	_follow = follow if FOLLOW_FEET else null
	if not _colors.is_empty():
		_base_col = _colors[0]
	_radii.resize(_paths.size())
	_reveal.resize(_paths.size())
	var inv := 1.0 / _ro
	for i in _paths.size():
		var sub := _paths[i]
		var acc := 0.0
		for p: Vector2 in sub:
			acc += p.length()
		var r := acc / float(maxi(sub.size(), 1)) * inv
		_radii[i] = r
		_reveal[i] = RingBoard.finish_t_at_radius(r)
	_settle = RingBoard.finish_t_at_radius(1.0)
	z_index = FLOOR_Z
	queue_redraw()


## 🔴 아래 셋은 **헤드리스 관측점**이다 — 지우지 마라. 그물이 이 셋으로만 이 연출을 본다.

## 실제로 그리는 최대 반지름(px) — 🔴 `_ro`를 그냥 돌려주면 "ro는 커졌는데 점열을 다시 안 만들었다"를
## 못 잡는다(값만 맞고 그림은 그대로). 그래서 점열에서 잰다.
func bounds_radius() -> float:
	var m := 0.0
	for sub in _paths:
		for p: Vector2 in sub:
			m = maxf(m, p.length())
	return m


## 그려진 조각 수 — 진 윤곽 1 + 룬 자리 + 문양 모티프들. **조립이 늘면 이 수가 는다.**
func subpath_count() -> int:
	var n := 0
	for sub in _paths:
		if sub.size() >= 2:
			n += 1
	return n


## 조각별 색 — 🔴 합성 `GlyphRingDef.ui_color`가 새어 들어왔는지를 잡는 자리다.
func colors() -> PackedColorArray:
	return _colors


## 탄이 나갔다 — 확 퍼지며 꺼진다(「마법진이 풀려 마법이 됐다」).
func release() -> void:
	_end(RELEASE_SCALE, RELEASE_TIME)


## 시전이 끊겼다 — **오므라들며** 꺼진다. 퍼지는 것과 정반대 움직임이라 "나갔다"와 "접혔다"가
## 눈으로 갈린다. 🔴 안 지우면 원만 남아 *"쐈는데 안 나갔다"*가 된다.
func cancel() -> void:
	_end(CANCEL_SCALE, CANCEL_TIME)


func _end(to_scale: float, time: float) -> void:
	if _ending:
		return
	_ending = true
	_t = 1.0
	queue_redraw()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE * to_scale, time).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, time)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	# 🔴 끝나는 중에도 **따라가는 것만은 계속한다** — 퍼지는 원이 발에서 떨어져 나가면
	#   "내 발밑에서 풀렸다"가 "저기서 뭔가 터졌다"로 읽힌다.
	if _follow != null:
		if is_instance_valid(_follow):
			global_position = _follow.global_position
		else:
			_follow = null
	if _ending:
		return
	_t = minf(_t + delta / _dur, 1.0)
	_age += delta
	# 🔴 다 찬 뒤(홀드)는 수명이 아니라 플레이어가 쥔 시간이라 상한을 따로 얹는다 —
	#   안 갈라 두면 오래 들고 있을 때 원이 에러 없이 사라진다.
	var limit := _dur * _SAFETY_MULT
	if _t >= 1.0:
		limit += _SAFETY_HOLD
	if _age > limit:
		push_warning("[floor_circle] release/cancel이 안 왔다 — 안전망으로 스스로 지운다")
		_end(RELEASE_SCALE, RELEASE_TIME)
		return
	queue_redraw()


func _draw() -> void:
	var wave := RingBoard.finish_wave_frac(_t)
	# 🔴 파도가 다 훑은 뒤엔 머리 빛을 걷는다 — 그래야 원이 차분히 켜진 상태로 앉는다.
	var head := 1.0 - clampf((_t - _settle) / SETTLE_T, 0.0, 1.0)
	for i in _paths.size():
		var sub := _paths[i]
		if sub.size() < 2:
			continue                       # 빈 층 자리 — 자리만 지킨다
		if _t < _reveal[i]:
			continue                       # 파도가 아직 안 닿았다 = 제 차례가 아니다
		var glow := RingBoard.finish_glow_at(_radii[i], _t) * head
		var col := _colors[i] if i < _colors.size() else _base_col
		col.a = clampf(_alpha + GLOW_ALPHA * glow, 0.0, 1.0)
		draw_polyline(sub, col, _width + GLOW_W * glow, true)
	# 훑고 지나가는 파도 원호 — 어디까지 열렸나가 한 눈에 보인다. 다 훑으면(wave≥1) 사라진다.
	if wave < 1.0 and wave > 0.0:
		var sweep := _base_col
		sweep.a = SWEEP_ALPHA
		draw_arc(Vector2.ZERO, maxf(wave * _ro, 1.0), 0.0, TAU, 48, sweep, SWEEP_W, true)
