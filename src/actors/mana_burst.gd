extends Node2D
## 🔴🔴 **마나 폭발** — 적이 죽으면 **몸에 박혀 있던 마법 빛이 터져 나와 흩어진다.**
## 정본 = `docs/takbon-design/enemy_feel_design.md` §3-B · 규격 = `docs/VFX_SPEC.md`.
## 세100에 `forest_enemy._spawn_death_puff`(적 색 Polygon2D 링)를 대체했다.
##
## ```
## ① 몸이 그 자리에서 푸르게 터진다      ← 스프라이트는 같은 프레임에 사라진다(queue_free)
## ② 마나 파편이 사방으로 튄다
## ③ 흩어지며 떠올라 옅어진다
## ④ 사라진다                            ← 🔴 마나 수치는 **안 준다**(순수 연출)
## ```
##
## 🔴🔴 **파편은 플레이어에게 안 온다 — 사용자가 각하했다**(세100):
##   *"잠깐 빨려오는건 없음 폭발해서 마나로 돌아갔다는 연출이지 마나가 들어오는건 없음"* ·
##   *"몬스터 잡아서 마나회복하는것도 없어"*
##
##   **「마나로 돌아간다」의 상대는 플레이어가 아니라 세계다.** 세계관이 그렇게 적어 뒀다
##   (`docs/takbon-design/world_and_visual_design.md` §3): *"적 = 몸 어딘가에 마법 빛이 박혀 있다
##   (삼켰다) · **적의 죽음 = 그 빛이 터져 나온다(돌려준다)**"*. 삼켜져 있던 빛이 **풀려나는** 그림이지
##   **수확하는** 그림이 아니다.
##   ⚠ **플레이어 쪽으로 수렴하는 궤적을 다시 넣지 마라** — 넣는 순간 *"주웠나?"*가 생기고,
##     그건 이 연출이 하려는 말의 정반대다. 그물 = `test_mana_burst_auto [4]`가 **수렴을 잡는다**
##     (「가나」가 아니라 **「안 가나」**를 재는 검사다 — 일부러 안 하는 것은 그물이 없으면 조용히 뒤집힌다).
##
## ✅ **덕분에 「드롭 자석과 헷갈린다」가 저절로 없어졌다.** 세51 드롭은 플레이어에게 **모여들고**
##   마나는 **흩어진다** — 궤적이 서로 반대라 속도·색으로 억지로 가를 필요가 없다.
##   같은 프레임에 겹쳐도 **모이는 것 = 전리품 · 퍼지는 것 = 죽음**으로 저절로 읽힌다.
##   (`tools/vfx_shot.gd -- death`가 둘을 **한 시트에 같이 찍는다** — 그 대비를 눈으로 보라고.)
##
## 🔴 **색은 마나 푸른색 하나다 — 룬 속성별로 가르지 마라**(설계 §3). 색을 가르면
##   *"무슨 마나인가"*라는 **없는 축**이 생긴다. 그래서 이 파일은 `RuneDef.ui_color`도
##   `status_rules`도 안 본다 — VFX_SPEC §1-1의 「파생만 쓴다」에 걸리는 물건이 아니다
##   (룬 색도 상태 색도 아니라 **파생원이 없다**. `forest_enemy.CHARGE_BAND_*`·`GUST_RING_COLOR`가
##   같은 자리다). ⚠ 그 대신 값은 **TAKBON 60의 청 램프 3단 그대로**다(`assets/aseprite/takbon.gpl`).
##
## 🔴 **크기·파편 수는 「보이는 몸」에서 나온다** — 파생원 하나(`setup`의 `body_px`)다.
##   ⚠ 설계 §3은 *"파생원은 「프레임 한 변」 하나다"*라고 적었는데 그건 §2-A-2의 **48px 재작이 끝나
##   `params.size`가 전부 1.0이 된 뒤**를 전제한 문장이다. 지금 라이브는 그렇지 않다
##   (`hound_alpha` 1.35 · `slime_elite` 1.9 · `snake_boss.tscn` 씬 scale 1.5). 한 변만 보면
##   **86px 몸에 64px짜리 폭발**이 터져 시체보다 작다 ⇒ **한 변 × global_scale = 보이는 몸 한 변**
##   하나를 파생원으로 삼는다. 리뷰가 모순이라 지적한 것은 「한 변」과 「scale」을 **서로 다른 축
##   두 개로** 든 초안이었고, 곱은 축이 둘이 아니라 **화면에 실제로 보이는 크기 하나**다
##   (`_attach_shadow`가 자식이라 저절로 그 곱을 얻는 것과 같은 값이다).
##
## 🔴 **`z_index`는 50이다 — 바꾸지 마라.** `vfx.gd`가 `VFX_Z := 55`의 근거로 *"죽음 연출(50) 위로"*를
##   든다(감사 T4 — 주석이 계약인데 코드와 같이 안 늙는 자리). 바꾸려면 그 인용을 같은 커밋에 고쳐라.
##
## 🔴 **노드 하나가 전부를 그린다**(자식 0 · 트윈 0 · `_draw` 하나). 파편마다 `Polygon2D`를 심으면
##   광역 마법으로 다섯을 같은 프레임에 죽일 때 **노드가 5 + 5×7**로 튄다(설계 §9 「다중 처치
##   과부하」). 여기선 **처치당 노드 하나**라 그 자리가 구조적으로 안 생긴다.
##
## 🔴 **수명을 스스로 쥔다** — 적은 `_die`에서 곧바로 `queue_free`되므로 이 노드는
##   `get_tree().current_scene`에 붙어 **적보다 오래 산다**(`_spawn_loose`·유언 탄과 같은 관용구).
##
## class_name 없음 — 모듈 규칙(`const ManaBurst := preload(...)`로만 참조).

# ── 색 (TAKBON 60 청 램프 3단 — 위 머리말의 「파생원이 없다」 참조) ──────────────────
const MANA_CORE := Color(0.643, 0.867, 0.859)    ## A4DDDB — 터지는 순간의 심지(가장 밝다)
const MANA_BRIGHT := Color(0.451, 0.745, 0.827)  ## 73BED3 — 파편·링 본색
const MANA_DEEP := Color(0.310, 0.561, 0.729)    ## 4F8FBA — 짙은 쪽 파편(떼에 결이 생긴다)

## 🔴 계약 상수 — `vfx.gd`의 `VFX_Z := 55`가 이 값 위에 선다(머리말 참조).
const BURST_Z := 50

# ── 기하: 전부 **보이는 몸 한 변**의 비율이다 (숫자를 화면 px로 박으면 덩치를 안 탄다) ──
## 🔴 코어는 **몸보다 커야 한다** — 스프라이트가 같은 프레임에 사라지므로 코어가 작으면
##  「몸이 터졌다」가 아니라 **「작은 파란 게 나타났다」**로 읽힌다(실측: 0.30 = 몸의 0.84배 지름).
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
## 🔴 ③ **터진 뒤에도 계속 뻗는다**(급감속). 여기가 0이면 파편이 **제자리에 박힌 채 꺼져**
##   「흩어진다」가 아니라 「점멸한다」가 된다 — 각하된 ③(빨려옴)의 자리를 메우는 것이 이 값이다.
## ⚠ 이 둘의 **합**이 파편이 닿는 최대 반경을 정한다(× 덩치 × 보스 배수 × `1+SHARD_SPREAD`) —
##   `tools/vfx_shot.gd`의 `death` 프리셋 `crop`이 그 산수에서 나온다. **키우면 거기도 키워라**,
##   안 그러면 파편이 **잘린 채** 찍혀 「충분히 흩어졌나」 판단이 거짓이 된다(도구의 최악 실패).
const SHARD_DRIFT_FRAC := 0.34
## 🔴 ③ **떠오른다** — 흩어지는 데 **방향이 하나 있어야** 「돌아갔다」로 읽힌다(그냥 옅어지면
##   「꺼졌다」다). 위로 두는 근거 = 세계관의 「마법 = 빛」 + `vfx.gd`의 솟는 플레어(`FLARE_RISE`)와
##   같은 높이 언어. ⚠ **플레이어 쪽은 안 된다**(머리말 — 각하된 궤적이다).
const SHARD_RISE_FRAC := 0.34
const SHARD_SHRINK := 0.55    ## ④ 사라질 때까지 줄어드는 배수 (페이드와 같이 걸려 「흩어져 사라진다」)
const SHARD_SPREAD := 0.35    ## 거리 흔들림(±) — 균등하면 방사 대칭이 기계적이다(VFX_SPEC §1-3)
const SHARD_ANGLE_JITTER := 0.30  ## 각도 흔들림(rad, ±)

# ── 개수: 몸에서 파생 (「6~8개」는 64px 몸의 값이지 상수가 아니다) ──────────────────
const SHARD_BASE := 4         ## 아무리 작아도 이만큼은 튄다
const SHARD_PER_PX := 0.05    ## 보이는 몸 한 변 px마다 (64px 몸 = 4 + 3 = 7개 = 설계의 6~8)
const SHARD_MIN := 6
const SHARD_MAX := 16         ## 🔴 상한 = 다중 처치 과부하 방어(설계 §9)
## 보스는 더 크고 파편도 많다(설계 §3). ⚠ 판별은 **`params.ai`가 `boss_`로 시작하나**이고
## 그건 이미 데이터에 있다 — 새 키를 안 만든다(「새 적 = .tres 한 장」).
const BOSS_COUNT_MULT := 1.75
const BOSS_SIZE_MULT := 1.35

# ── 시간 (연출값 — 밸런스 아님. 🔴 손맛은 F5가 조인다: VFX_SPEC §4) ────────────────
## 🔴🔴 **코어와 링의 수명이 갈려 있다.** 하나로 묶었더니 큰 반투명 원반이 링 안을 0.2초 내내
##   채워 **「파란 접시」**로 읽혔다(실측) — 터짐이 아니라 평평한 색면이다.
##   코어는 **몸을 이어받고 곧장 꺼지는 섬광**(짧게), 링은 **퍼져 나가는 충격파**(길게)다.
const CORE_SEC := 0.10        ## ① 코어 섬광이 사는 시간(s)
const RING_SEC := 0.24        ## ① 팽창 링이 사는 시간(s) — 코어보다 오래 남아 「퍼졌다」를 진다
const OUT_SEC := 0.16         ## ② 파편이 터지는 힘으로 튀는 시간(s)
## 🔴 ③④ 흩어져 사라지는 시간(s). **F5에서 제일 먼저 조일 값이다** — 짧으면 죽음이 툭 끊기고,
##   길면 시체 자리에 파란 게 오래 남아 늘어진다. 총 수명 = `OUT_SEC + FADE_SEC`.
const FADE_SEC := 0.30
## 🔴🔴 **흩어지는 앞부분은 안 꺼진다** — 실측: 터지자마자 옅어지기 시작하면 파편이 **퍼지는 게
##   보이기도 전에** 사라져 「흩어졌다」가 아니라 **「증발했다」**로 읽혔다(격자 두 칸 만에 실종).
##   이 비율만큼은 **제 색·제 크기로 퍼진 다음** 꺼지기 시작한다.
const FADE_HOLD := 0.35
## 버틴 뒤 꺼지는 곡선. 1.0(선형)보다 크면 **처음엔 진하게 버티다 끝에 빨리** 꺼진다.
const FADE_POW := 1.4

const RING_SEGS := 28         ## 링 원 분할 수 (`vfx.RING_SEGMENTS` 24와 같은 결)

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


## 🔴 `body_px` = **보이는 몸 한 변**(프레임 한 변 × global_scale) — 파생원 하나다(머리말).
## `boss` = 더 크고 파편도 많다.
## ⚠ **플레이어를 안 받는다.** 세100에 「빨려온다」가 각하되며 따라갈 몸이 없어졌다 —
##   인자를 되살리려는 순간이 곧 각하된 궤적을 되살리는 순간이다(머리말).
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
	# 🔴 균등 각도 + 흔들림 — 완전 균등이면 「방사 대칭이 기계적」(VFX_SPEC §1-3)이고, 완전 랜덤이면
	#   한쪽에 뭉쳐 「사방으로」가 깨진다. 균등을 바탕으로 흔드는 게 `_spawn_loose`의 결과 같다.
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


# ── 공개 관측점 (헤드리스는 「예쁜가」를 못 재도 아래는 잰다 — `charge_band_reach()` 선례) ──

## 이번 폭발의 파편 수 — 「덩치에 따라 는다」의 측정 가능한 형태.
func shard_count() -> int:
	return _count


## 링이 닿는 최대 반지름(월드 px) — 「덩치에 따라 커진다」의 측정 가능한 형태.
## ⚠ 되계산하지 않고 **실제로 그리는 값**을 돌려준다(세85 「검증 도구가 거짓말한다」).
func burst_radius() -> float:
	return _ring_r


## 지금 파편이 실제로 그려지는 자리(월드). 🔴 **그물이 「흩어지나 · 누구에게도 안 모이나」를 재는
## 자리**다 — 상태 변수가 아니라 `_draw`가 쓰는 그 계산을 그대로 돌려준다(그리는 값과 재는 값이
## 갈리지 않게).
func shard_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	var xf := global_transform
	for i in _count:
		out.append(xf * _shard_local(i))
	return out


## 0(막 터졌다) ~ 1(다 사라졌다).
func progress() -> float:
	return clampf(_t / maxf(_life, 0.0001), 0.0, 1.0)


## 🔴🔴 **`_process`가 아니라 `_physics_process`인 것이 계약이다** — 🔴 **`-s` 헤드리스에서
##  시간이 결정적이어야 한다**: `_process`의 delta는 fps 상한이 풀린 테스트 실행에서 프레임마다
##  제멋대로라(수십 μs) 그물이 **몇 프레임을 돌려야 0.46초인지 모른다.** 물리 delta는 1/60 고정이라
##  `await physics_frame`이 곧 시간이 된다(`test_mana_burst_auto`가 「흩어졌나」를 재는 근거다 —
##  못 재면 그 그물은 존재만 확인하고 아무것도 안 잰다).
##  ⚠ 형제 연출(세51 드롭 자석)도 `_physics_process`라 같은 박자로 돈다.
func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= _life:
		queue_free()


func _draw() -> void:
	# ① 몸이 터진다 — 코어(채운 원)가 몸 자리를 채웠다가 옅어지고, 링이 바깥으로 퍼진다.
	#   🔴 스프라이트는 같은 프레임에 사라지므로 **코어가 그 자리를 이어받는 물건**이다.
	#     작게 시작하면 한 프레임 「몸이 없는」 구멍이 보인다 — 그래서 처음부터 몸만 하다.
	if _t < CORE_SEC:
		var tc := clampf(_t / CORE_SEC, 0.0, 1.0)
		var core := MANA_CORE
		# 🔴 **급히 꺼진다**(제곱) — 천천히 꺼지면 큰 반투명 원반이 링 안에 앉아 평평해진다(실측).
		core.a = pow(1.0 - tc, 2.0) * 0.95
		draw_circle(Vector2.ZERO, _core_r * lerpf(1.0, 1.35, tc), core)
	if _t < RING_SEC:
		var tr := clampf(_t / RING_SEC, 0.0, 1.0)
		var eo := 1.0 - pow(1.0 - tr, 3.0)
		var ring := MANA_BRIGHT
		ring.a = pow(1.0 - tr, 1.4)
		draw_arc(Vector2.ZERO, _ring_r * lerpf(0.26, 1.0, eo), 0.0, TAU, RING_SEGS,
			ring, _ring_w * lerpf(RING_W_START, RING_W_END, eo), true)

	# ②③④ 파편 — 사방으로 튀었다가 흩어지며 떠올라 사라진다.
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
		# 🔴 파편은 **끝까지 바깥을 향한다** — 방향이 도는 순간 「무언가에 끌린다」가 되고,
		#   그게 각하된 ③이다(머리말). 흩어지는 그림엔 돌아설 이유가 없다.
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


## 파편 i의 지금 자리(로컬). 🔴 `_draw`와 `shard_positions()`가 **같은 함수**를 쓴다 —
## 그리는 값과 재는 값을 따로 계산하면 그물이 거짓 그린이 된다(감사 T5의 이 파일판).
##
## 셋을 더한다: ② 터진 힘(감속) + ③ 이어지는 흩어짐(더 급감속) + ③ 떠오름.
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


## ④ 꺼짐 진행 0~1 — 🔴 **흩어짐과 다른 시계다**(`FADE_HOLD`만큼 늦게 시작한다).
## 위치는 `_drift_t`가, 사라짐은 이게 판다 — 갈라 둬야 **「퍼진 다음 꺼진다」**가 나온다.
func _vanish_t() -> float:
	return clampf((_drift_t() - FADE_HOLD) / maxf(1.0 - FADE_HOLD, 0.0001), 0.0, 1.0)


## ④ 사라진다 — 버틴 뒤 **뒤로 갈수록 빨리** 꺼진다(`FADE_POW`).
func _shard_alpha() -> float:
	return pow(1.0 - _vanish_t(), FADE_POW)
