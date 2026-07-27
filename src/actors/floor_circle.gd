extends Node2D
## 발밑 바닥 마법진 — **「내가 조립한 그 마법진」이 시전 동안 발밑에 열린다** (세98).
## 정본 = `docs/takbon-design/spell_cast_visual_design.md`(확정 ③) · 규격 = `docs/VFX_SPEC.md`.
##
## 🔴🔴 **이 파일은 그리기만 한다 — 무엇을 그릴지는 `vfx.gd`가 정해서 넘긴다.**
## 점열(`paths`)은 `RingBoard.compose_guide_paths`가 만든 **조립본 그 자체**고, 색은 룬이 판다.
## 그래서 **매핑표가 없다**: 문양 3개면 문양이 3개, 2층이면 두 겹, 융합진이면 룬이 둘로 저절로
## 나온다(설계 §2). 나중에 문양을 늘려도 **이 파일은 안 고친다.**
##
## 🔴 **시간 언어는 조립 책의 완성 연출과 같은 곡선을 쓴다**(설계 §6 — `RingBoard`의 static 셋):
##   `finish_t_at_radius(r)` = 파도가 반지름 r에 닿는 시점 → **조각이 나타나는 순간**(안→밖 = 연산 순서)
##   `finish_wave_frac(t)`   = 파도의 지금 반지름 → 훑고 지나가는 원호
##   `finish_glow_at(r, t)`  = 그 조각이 지금 얼마나 밝나 → **덧대는** 알파·굵기
## 🔴 밑알파(`_alpha`)는 그 위에 **따로** 얹는다 — `finish_glow_at`은 t=1에서 0으로 꺼지므로
##   그것만 쓰면 **시전이 끝나기도 전에 원이 사라진다**(맺을 때와 달리 여긴 「켜 두는」 연출이다).
##
## 🔴 수명을 **스스로 안 끝낸다** — 탄이 나가면 `release()`, 끊기면 `cancel()`이 끝낸다.
##   시전 시간과 원이 닫히는 시간이 갈리면 그게 세23 「리포트 140인데 130으로 때린다」의 시간판이다.
##   🔴🔴 **`duration`은 「채우는 시간」이지 수명이 아니다**(확정 ⑦ — 좌클릭을 떼면 나간다).
##   다 차면 원은 **열린 채 머문다**: `_t`가 1.0에서 포화하고 머리 빛(`head`)이 잦아들어
##   **차분히 켜진 상태**로 앉는다 — 홀드 구간의 그림이 그것이다. 그동안 계속 발을 따라간다.
##   ⚠ 그래도 안전망 하나는 둔다(`_SAFETY_MULT` + `_SAFETY_HOLD`) — 둘 중 아무것도 안 오면 원이
##   **영원히 발을 따라다닌다**. 🔴 홀드를 그 계산에 그냥 더하면 반대로 **오래 들 때 원이 사라진다**.
##
## class_name 없음 — 모듈 규칙(preload로만 참조).

## 🔴 **모듈 간 preload의 명시 예외 ② — 기하 단일 소스**(takbon-rules §0 · 설계 §7).
## 좌표·시간 곡선을 **베끼면** 조립 판·책과 갈라져 「맺을 때 본 그림 ≠ 쓸 때 나오는 그림」이 된다.
## `ring_board.gd`의 이 함수들은 static·순수라 Control 인스턴스 없이 그대로 부를 수 있고,
## `class_name`이 없어 preload가 유일한 진입로다(판례 = `src/hud/hud.gd`·`src/hud/tab_panel.gd`).
const RingBoard := preload("res://src/drawing/ring_board.gd")

# ── 연출값 (밸런스 아님 — VFX_SPEC §4 · 설계 §3. 손맛은 F5가 조인다) ──────────────────
## 🔴 **z=1이 유일한 자리다**(설계 ⓑ): Ground·프롭 0 · **플레이어 2** · 지팡이 3.
## ⚠ 음수로 내리지 마라 — 세54에 음수 z가 Ground 뒤로 숨는 걸 실제로 밟았다(`shadow.gd` 머리말).
const FLOOR_Z := 1
const LINE_W_PLAIN := 1.4        ## 무난한 진의 선 굵기(px)
const LINE_W_PERFECT := 2.0      ## 퍼펙트의 선 굵기 — 등급이 굵기로도 읽힌다
## ⚠ 무난한 진의 밑알파 — **F5에서 제일 먼저 조일 값이다.** 「옅게」(설계 §3)와 「그래도 시전이
##   시작된 게 보여야 한다」가 여기서 부딪힌다. 도구 배경(어두운 회보라)에선 0.34도 보였지만
##   마을 바닥은 더 밝다 — 안 보이면 이 줄만 올려라(0.80은 퍼펙트 자리라 안 건드린다).
const ALPHA_PLAIN := 0.42
const ALPHA_PERFECT := 0.80      ## 퍼펙트의 밑알파(밝게)
const GLOW_ALPHA := 0.55         ## 파도 머리가 지날 때 **덧대는** 알파
const GLOW_W := 1.5              ## 파도 머리가 지날 때 **덧대는** 굵기(px)
## 🔴 파도가 바깥에 닿은 뒤 **머리 빛이 잦아드는** 정규 시간.
## 없으면 진 윤곽(r≈1)의 머리 빛이 `finish_glow_at`에서 **최대치로 굳는다** — 파도(`finish_wave_frac`)가
## 1.0에서 포화하므로 `wave - r`이 영영 0이라 머리가 안 지나간다. 첫 판이 실제로 그렇게 나왔다:
## **테두리만 두꺼운 도넛**이 되고 안쪽 구성(문양·룬)이 그 옆에서 안 읽혔다.
## ⚠ 잦아들기 시작하는 시각은 `finish_t_at_radius(1.0)`에서 **파생**한다(0.60을 베끼지 않는다).
const SETTLE_T := 0.12
const SWEEP_W := 1.6             ## 훑고 지나가는 파도 원호 굵기(px)
const SWEEP_ALPHA := 0.34        ## 그 원호의 알파
const RELEASE_TIME := 0.16       ## 탄이 나갈 때 — **확 퍼지며** 꺼진다(「나갔다」)
## ⚠ 이 배율을 키우면 `tools/vfx_shot.gd`의 `floor` 프리셋 `crop`(148 = ±74)을 같이 봐라 —
##   퍼펙트 ro(50) × 이 값이 그 안에 들어야 「퍼지는 순간」이 안 잘린다.
const RELEASE_SCALE := 1.35
const CANCEL_TIME := 0.10        ## 끊겼을 때 — **오므라들며** 꺼진다(「접혔다」 = 정반대 읽기)
const CANCEL_SCALE := 0.55
## 안전망 — `release()`/`cancel()`이 둘 다 안 오면 스스로 죽는다. **채우는 동안**의 여유 배수.
## 🔴 넉넉히 잡는다: 이건 **연출이 아니라 누수 방지**다(짧게 잡으면 히트스톱 한 번에 원이 먼저 꺼진다).
const _SAFETY_MULT := 4.0
## 🔴🔴 **세98(홀드 발사): 홀드 시간을 수명으로 세지 마라.** 다 차면 원은 「떼거나 끊길 때까지」
## 열린 채 머무는데(확정 ⑦), `_dur * _SAFETY_MULT`만 보면 **오래 들고 있을 때 원이 조용히 사라진다**
## — 그 자멸은 `push_warning`이라 `SCRIPT ERROR` grep에도 안 걸린다(감사 T6).
## 그래서 다 찬 뒤엔 이 상한을 **따로** 얹는다. 🔴 **0이나 무한으로 만들지 마라**: 안전망을 지우면
## release/cancel이 둘 다 안 오는 경로에서 원이 **영원히 발을 따라다닌다**(그게 이 상수의 존재 이유다).
## 사람이 쥐고 있을 수 있는 시간보다 넉넉하되 유한하다.
const _SAFETY_HOLD := 60.0

## 🔴🔴 **F5 한 줄 비교 스위치**(설계 ⓜ) — 원이 **발을 따라가나(true) · 클릭한 자리에 박히나(false)**.
## 확정 ③(발밑)과 ⑤(시전 중 감속 이동)가 동시에 참이라 **반드시 갈린다**: 월드 고정이면
## **가장 공들인 마법일수록 원이 발밑에서 제일 많이 벗어난다**(퍼펙트가 가장 오래·가장 느리다).
## 기본값 = 따라간다. 실게임에서 "원이 미끄러진다"로 읽히면 이 줄만 false로 바꿔 비교해라.
const FOLLOW_FEET := true

var _paths: Array[PackedVector2Array] = []
var _colors := PackedColorArray()
## 각 서브패스의 **정규 반지름**(중심에서의 평균 거리 ÷ ro) — 룬(≈0) → 층(0.42·0.68) →
## 진 윤곽(≈1) 순서가 그대로 나온다 = 파도가 훑는 순서가 곧 연산 순서다.
## ⚠ `RingBoard._subpath_radii`와 같은 식이지만 그건 **인스턴스 함수 + Control 상태**에 묶여 있어
##   부를 수 없다(설계 §6이 초고의 「재사용된다」를 여기서 좁혔다). 식 자체는 평균 거리 하나다.
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


## 🔴 `paths`는 **원점(0,0) 기준 로컬 좌표**여야 한다 — 노드 위치가 곧 원의 중심이라
## 발을 따라갈 때 점열을 다시 안 만든다(`vfx.gd`가 `ctr = Vector2.ZERO`로 합성해 넘긴다).
## `colors`는 `paths`와 **같은 길이**(자리마다 색 하나 — 융합진은 룬 자리가 서로 다른 색이다).
func setup(paths: Array[PackedVector2Array], colors: PackedColorArray, ro: float,
		duration: float, quality: float, follow: Node2D) -> void:
	_paths = paths
	_colors = colors
	_ro = maxf(ro, 1.0)
	# 🔴 시전 시간이 0이면(balance로 즉발 복원) 0으로 나누지 않게 — 그때는 첫 프레임에 다 그린다.
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


## 🔴 아래 셋은 **헤드리스 관측점**이다(`RingBoard.finish_progress` 선례) — 렌더는 못 봐도
## 「크기가 등급을 따라가나 · 구성이 그림에 반영됐나 · 색을 룬이 판았나」는 값으로 잴 수 있다.
## ⚠ 지우지 마라: `tests/test_floor_circle_auto.gd`가 이 셋으로만 이 연출을 본다.

## 실제로 그리는 최대 반지름(px) — 점열에서 잰다. 🔴 `_ro`를 그냥 돌려주지 않는 게 핵심이다:
## 그러면 "ro는 커졌는데 점열을 다시 안 만들었다"를 **못 잡는다**(값만 맞고 그림은 그대로).
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


## 조각별 색 — 🔴 **합성 `GlyphRingDef.ui_color`(불색 주황)가 새어 들어왔는지**를 잡는 자리다.
func colors() -> PackedColorArray:
	return _colors


## 🔴 탄이 나갔다 — 확 퍼지며 꺼진다. 이 순간이 「마법진이 풀려 마법이 됐다」로 읽혀야 한다.
func release() -> void:
	_end(RELEASE_SCALE, RELEASE_TIME)


## 🔴 시전이 끊겼다(구르기·모달·책) — **오므라들며** 꺼진다. 퍼지는 것과 정반대 움직임이라
## "나갔다"와 "접혔다"가 눈으로 갈린다. 안 지우면 원만 남아 *"쐈는데 안 나갔다"*가 된다(설계 ⓝ).
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
	# 안전망 — `release()`/`cancel()`이 둘 다 안 왔다. ⚠ 원이 영원히 발을 따라다니는 것보다는 낫다.
	# 🔴 다 찬 뒤(`_t >= 1.0` = 홀드)는 수명이 아니라 **플레이어가 쥔 시간**이라 상한을 따로 얹는다
	#   (`_SAFETY_HOLD` 주석 — 안 갈라 두면 오래 들고 있을 때 원이 에러 없이 사라진다).
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
	# 🔴 파도가 다 훑은 뒤엔 머리 빛을 걷는다 — 그래야 원이 **차분히 켜진 상태**로 앉는다(SETTLE_T 주석).
	var head := 1.0 - clampf((_t - _settle) / SETTLE_T, 0.0, 1.0)
	for i in _paths.size():
		var sub := _paths[i]
		if sub.size() < 2:
			continue                       # 빈 층 자리 — 그릴 게 없다(자리만 지킨다)
		if _t < _reveal[i]:
			continue                       # 🔴 파도가 아직 안 닿았다 = **제 차례가 아니다**
		var glow := RingBoard.finish_glow_at(_radii[i], _t) * head
		var col := _colors[i] if i < _colors.size() else _base_col
		col.a = clampf(_alpha + GLOW_ALPHA * glow, 0.0, 1.0)
		draw_polyline(sub, col, _width + GLOW_W * glow, true)
	# 훑고 지나가는 파도 원호 — 어디까지 열렸나가 한 눈에 보인다. 다 훑으면(wave≥1) 사라진다.
	if wave < 1.0 and wave > 0.0:
		var sweep := _base_col
		sweep.a = SWEEP_ALPHA
		draw_arc(Vector2.ZERO, maxf(wave * _ro, 1.0), 0.0, TAU, 48, sweep, SWEEP_W, true)
