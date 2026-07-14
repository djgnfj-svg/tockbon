extends RefCounted
## $1 유니스트로크 인식기 + 기하 판정 파이프라인 (TECH_SPEC §6, GDD §4.4).
## 순수 정적 함수 — 씬·오토로드 의존 없음(헤드리스 테스트 가능). 좌표는 캔버스 정규화(0..1).
##
## classify_stroke 파이프라인 (획 종료 시 1회):
##   (a) 원 기하 판정 — 컨텍스트에 원이 없을 때만. $1 미사용
##   (b) 탈출 판정 → 화살표 — 진이 있을 때만. 룬은 진 안에 머무르고 화살표는 진을
##       뚫고 나간다는 기하 규칙 (TECH_SPEC §6.1). 직진성과 무관하므로 곡선 화살표가 산다
##   (c) 직진 사전 게이트 → 화살표 (진이 없는 첫 획 등, 탈출 판정을 못 할 때)
##   (d) $1 룬 인식 — 감김(총 회전각) 밴드로 후보를 먼저 제한해
##       물~ / 바람◎ 교차 오인식을 구조적으로 차단 (GDD 리스크 1)
##   (e) 폴백 화살표 / DECOR
##
## **조준 꼬리는 폐지됐다** (v1.6): 진은 한 종류뿐이고 캔버스 위쪽이 곧 조준 방향이다.
## 인식기는 TAIL을 더 이상 생산하지 않는다 — enum 값은 구세이브 도안 렌더용으로 core에 남아 있다.
## 진 경계에서 밖으로 나가는 짧은 획은 이제 **화살표**로 잡힌다 (탈출 판정과 일관).
## 사용: const Recognizer := preload("res://src/drawing/recognizer.gd")

const RuneTemplates := preload("res://src/drawing/rune_templates.gd")
const GlyphTemplates := preload("res://src/drawing/glyph_templates.gd")

# ── $1 파라미터 ──
const RESAMPLE_N := 64
const ANGLE_RANGE := PI / 4.0          # 최적 회전 황금분할 탐색 범위 ±45°
const ANGLE_PRECISION := 0.035         # ≈ 2°
const RUNE_MIN_SCORE := 0.60           # 미달 시 룬으로 인정하지 않음

# ── 감김 밴드 (|총 회전각| rad) — 바람◎ 게이트 ──
# **불△에는 감김 게이트를 두지 않는다.** 실측 분포(스무딩 후, 손그림 240샘플):
#     충격> 0.00~0.67 / 물~ 0.00~0.48 / 불△ 0.16~0.90 / 바람◎ 2.05~3.00 (바퀴)
# 불△는 충격>·물~과 **완전히 겹쳐** 이들을 가르는 문턱이 존재하지 않는다 —
# 예전엔 0.55바퀴 게이트가 감김이 낮게 측정된 삼각형에서 불△를 후보에서 통째로 빼 버렸고,
# 그래서 물~/충격> 템플릿에만 매칭돼 0.4점 → DECOR로 떨어졌다 (불이 안 그려지던 원인).
# 불/충격/물의 구별은 $1 템플릿 매칭이 잘한다(삼각형 0.97 vs 오답 0.40) — 거기에 맡긴다.
# 하드 게이트는 **바람◎에만** 남긴다: 물~ vs 바람◎ 교차 오인식이 실제 리스크이고(GDD 리스크 1),
# 이 둘은 감김이 0.48 대 2.05로 확실히 갈린다.
const WINDING_WIND_MIN := 1.50 * TAU   # 이상 → {바람◎}만

# ── 파형성(곡률 부호 교대) — 충격> vs 물~ 게이트 ──
const RUN_RESAMPLE_N := 32
const RUN_MIN_TURN := 0.45             # 유의미한 꺾임 런의 최소 누적 회전(rad)
const RUN_SMOOTH_PASSES := 2           # 런 계산 전 이동평균 스무딩 횟수 (노이즈 런 억제)
## 충격>/물~ 점수차가 이 값 미만이면 ($1이 확신 못 함) 곡률런으로 가른다.
## 0.03~0.12 실측 스윕에서 0.08이 최고(전체 99.5%) — 양 끝이 아니라 중앙값이라 과적합도 아니다
const RUNS_TIE_MARGIN := 0.08


# ── 원 기하 판정 ──
const CIRCLE_RESAMPLE_N := 48
const CIRCLE_MAX_GAP_RATIO := 0.35     # 시작-끝 거리 / bbox 대각선
const CIRCLE_MAX_RADIUS_CV := 0.14     # 반지름 변동계수(std/mean)
const CIRCLE_NET_MIN := 0.70 * TAU     # 총 회전각 하한 (한 바퀴 근사)
const CIRCLE_NET_MAX := 1.40 * TAU     # 상한 (나선 배제)
const CIRCLE_MAX_TURN := 1.15          # 국소 최대 꺾임(rad) — 삼각형 등 다각형 배제

# ── 화살표 ──
const ARROW_STRAIGHT_PRE := 0.90       # 이상이면 룬을 건너뛰고 즉시 화살표
const ARROW_STRAIGHT_FALLBACK := 0.80  # 룬 실패 시 폴백 화살표 최소 직진성

# ── 문양 글자 (v1.9, GDD §4.3) ──
# **인식 실패는 거부가 아니라 BASIC 폴백이다.** 진을 뚫고 나간 획은 무조건 탄이다 (GDD §4.5) —
# 아래 상수들은 "글자로 인정할 문턱"이지 "획을 버릴 문턱"이 아니다.
const GLYPH_MIN_SCORE := 0.62          # 미달 → BASIC
## 최고점과 차점의 차이가 이 미만이면 ($1이 확신 못 함) 기하 피처로 가른다
const GLYPH_TIE_MARGIN := 0.08
## 🔴 **BASIC을 가르는 진짜 잣대.** 현(시작→끝)에서 벗어나는 최대 수직거리 ÷ 현 길이.
## 미만이면 **템플릿을 태우지 않고** 즉시 BASIC — 글자가 아니라 그냥 곧은 획이다.
##
## 직진성으로는 못 가른다. 실측 분포(손그림 6000샘플): **직진성은 BASIC 0.868~1.000 vs
## 유도∿ 0.673~0.909로 겹친다** — 곡률이 완만한 호는 경로가 거의 안 늘어나기 때문이다
## (사가타 0.2의 호도 직진성 0.90). 반면 chord_bow는 **BASIC 0.003~0.059 vs 글자 0.112~0.443,
## 빈 구간이 통째로 비어 있다.** 0.08은 그 한가운데다 (ARROW_ESCAPE_R을 잡은 것과 같은 수법).
##
## 이 게이트가 없으면 scale_to_square가 얇은 획의 세로 지터를 bbox 높이로 나눠
## **화면 가득한 가짜 지그재그**로 부풀려, 살짝 흔들린 직선이 팅김⚡에 붙는다.
const GLYPH_MIN_BOW := 0.08
## 이 이상 곧으면 템플릿을 아예 안 태운다 — 튜토리얼의 직선 화살표가 여기로 빠진다.
## **ARROW_STRAIGHT_PRE(0.90)를 재사용하지 않는다**: 그 값은 "룬이냐 화살표냐"의 잣대이지
## "글자냐 아니냐"의 잣대가 아니다. 0.90으로 자르면 유도∿의 완만한 호(최대 0.909)를
## 통째로 BASIC으로 떨궈 인식률이 1.4% 깎였다 (실측). 곧은 획은 직진성 0.99+라 여유가 크다.
const GLYPH_BASIC_STRAIGHT := 0.95
## 국소 최대 꺾임(rad, 스무딩 후) — 이상이면 "급반전"(관통‖의 화살촉). 유도∿는 곡률이
## 호 전체에 퍼져 이 아래에 머문다
const GLYPH_SHARP_TURN := 0.55

# ── 탈출 판정 (곡선 화살표, TECH_SPEC §6.1) ──
# "룬은 진 안에 머무르고, 화살표는 진을 뚫고 나간다" — 직진성이 아니라 기하 위치로 가른다.
const ARROW_ESCAPE_R := 1.05           # 끝점 중심거리 ≥ radius × 이 값이어야 "진 밖"
const ARROW_ESCAPE_GAIN := 0.12        # 끝점이 시작점보다 최소 radius × 이 값만큼 더 멀어야 함
const ARROW_ESCAPE_MAX_WINDING := WINDING_WIND_MIN  # 이상 감기면 바람◎ — 탈출 판정을 양보한다

const MIN_POINTS := 4
const MIN_STROKE_LEN := 0.02

static var _templates: Array[Dictionary] = []
static var _glyph_templates: Array[Dictionary] = []


## ctx: {has_circle, circle_center, circle_radius, has_tail, has_rune}
## 반환: {"role": Enums.StrokeRole, "score": float, ...역할별 페이로드}
static func classify_stroke(points: PackedVector2Array, ctx: Dictionary) -> Dictionary:
	if points.size() < MIN_POINTS or path_length(points) < MIN_STROKE_LEN:
		return {"role": Enums.StrokeRole.DECOR, "score": 0.0, "reason": "too_short"}

	if not ctx.get("has_circle", false):
		var c := detect_circle(points)
		if c.is_circle:
			return {
				"role": Enums.StrokeRole.CIRCLE,
				"center": c.center, "radius": c.radius, "score": c.score,
			}
	else:
		# 진을 뚫고 나간 획은 직진성과 무관하게 화살표 — 곡선 화살표가 여기서 산다
		if detect_escape(
				points,
				ctx.get("circle_center", Vector2(0.5, 0.5)),
				ctx.get("circle_radius", 0.25)):
			return _arrow_result(points, straightness(points))

	var st := straightness(points)
	if st >= ARROW_STRAIGHT_PRE:
		return _arrow_result(points, st)

	if not ctx.get("has_rune", false):
		var r := recognize_rune(points)
		if r.score >= RUNE_MIN_SCORE:
			return {
				"role": Enums.StrokeRole.RUNE,
				"rune_type": r.type, "score": r.score, "net_rotation": r.net,
			}
		if st >= ARROW_STRAIGHT_FALLBACK:
			return _arrow_result(points, st)
		# 실패해도 **어느 룬에 얼마나 가까웠는지**를 함께 돌려준다 — "거의 됐다"와
		# "전혀 아니다"를 플레이어가 구별할 수 있어야 다시 그릴 마음이 생긴다
		return {
			"role": Enums.StrokeRole.DECOR, "score": float(r.score),
			"reason": "rune_low_score",
			"near_rune": int(r.type), "min_score": RUNE_MIN_SCORE,
		}

	if st >= ARROW_STRAIGHT_FALLBACK:
		return _arrow_result(points, st)
	return {"role": Enums.StrokeRole.DECOR, "score": 0.0, "reason": "unclassified"}


# ─────────────────────────── (a) 원 ───────────────────────────

static func detect_circle(points: PackedVector2Array) -> Dictionary:
	var out := {"is_circle": false, "center": Vector2.ZERO, "radius": 0.0, "score": 0.0}
	var pts := resample(points, CIRCLE_RESAMPLE_N)
	var bbox := _bbox(pts)
	var size := bbox.size.length()
	if size < 1e-6:
		return out
	var center := _centroid(pts)
	var mean_r := 0.0
	for p: Vector2 in pts:
		mean_r += p.distance_to(center)
	mean_r /= float(pts.size())
	if mean_r < 1e-6:
		return out
	var var_r := 0.0
	for p: Vector2 in pts:
		var d := p.distance_to(center) - mean_r
		var_r += d * d
	var cv := sqrt(var_r / float(pts.size())) / mean_r
	var gap := pts[0].distance_to(pts[pts.size() - 1])
	var net := absf(net_rotation(pts))
	var mturn := max_turn(pts)
	out.center = center
	out.radius = mean_r
	out.score = clampf(1.0 - cv * 3.0, 0.0, 1.0)
	out.is_circle = (
		gap <= CIRCLE_MAX_GAP_RATIO * size
		and cv <= CIRCLE_MAX_RADIUS_CV
		and net >= CIRCLE_NET_MIN and net <= CIRCLE_NET_MAX
		and mturn <= CIRCLE_MAX_TURN
	)
	return out


# ─────────────────────────── (b) 탈출 (곡선 화살표) ───────────────────────────

## 획이 진을 뚫고 바깥으로 나갔는가 — 곡선 화살표를 룬과 가르는 유일한 판정 (TECH_SPEC §6.1).
## 조건: 끝점이 진 밖(radius × ARROW_ESCAPE_R) && 끝점이 시작점보다 진 중심에서 유의미하게 멀다.
## 곡률·직진성은 보지 않는다 — 활처럼 휜 화살표도 그대로 통과한다.
## 예외: 바람◎ 나선처럼 여러 바퀴 감긴 획은 진을 삐져나가도 룬에 양보한다 (감김 상한).
static func detect_escape(points: PackedVector2Array, center: Vector2, radius: float) -> bool:
	if radius <= 1e-6:
		return false
	var first := points[0]
	var last := points[points.size() - 1]
	var d0 := first.distance_to(center)
	var d1 := last.distance_to(center)
	if d1 < radius * ARROW_ESCAPE_R:
		return false
	if d1 < d0 + radius * ARROW_ESCAPE_GAIN:
		return false
	return absf(winding(points)) < ARROW_ESCAPE_MAX_WINDING


# ─────────────────────────── (d) $1 룬 ───────────────────────────

## 룬 인식 — **후보를 지우지 않고 $1 점수로 고른다.** 피처(감김·곡률런)는 후보를 삭제하는
## 하드 게이트가 아니라, $1이 확신하지 못할 때만 개입하는 보조 신호다.
## 옛 방식(피처가 후보를 통째로 지움)은 정답을 지워 버리는 실패가 잦았다 — 실측(4종 × 300샘플):
##     하드 게이트 96.7% (불△ 100 / 충격> 88.7 / 물~ 99.0 / 바람◎ 99.0)
##     이 방식     99.5% (불△ 100 / 충격> 100  / 물~ 99.0 / 바람◎ 99.0)   물/바람 교차 둘 다 0
static func recognize_rune(points: PackedVector2Array) -> Dictionary:
	_ensure_templates()
	var net := winding(points)
	var allowed := winding_candidates(absf(net))
	var by_type := _type_scores(points, allowed)

	var best_type := int(allowed[0])
	for t: int in allowed:
		if float(by_type.get(t, 0.0)) > float(by_type.get(best_type, 0.0)):
			best_type = t

	# 충격> vs 물~ — 감김이 둘 다 낮아 $1이 흔들릴 수 있다. **점수가 근소할 때만**
	# 곡률 부호 교대 수로 가른다(">"는 꺾임 런 ≤1, 파형은 ≥2). 점수차가 뚜렷하면 $1을 믿는다 —
	# 이 조건 없이 무조건 런으로 지우면 노이즈 있는 충격>의 11%가 물~로 새어 나갔다
	var runner_up := _runner_up(by_type, allowed, best_type)
	if _is_impact_water_pair(best_type, runner_up) \
			and float(by_type[best_type]) - float(by_type[runner_up]) < RUNS_TIE_MARGIN:
		best_type = int(Enums.RuneType.WATER) if curvature_runs(points) >= 2 \
			else int(Enums.RuneType.IMPACT)

	return {"type": best_type, "score": float(by_type.get(best_type, 0.0)), "net": net}


## 허용 후보별 최고 점수 (같은 룬의 여러 템플릿 중 최고)
static func _type_scores(points: PackedVector2Array, allowed: Array[int]) -> Dictionary:
	return _best_scores(normalize_for_match(points), _templates, allowed)


## 정규화된 획 vs 템플릿 집합 → 타입별 최고 $1 점수.
## **룬과 문양은 템플릿 집합이 완전히 분리돼 있다** — 두 enum의 정수값이 겹치므로(FIRE=0=BASIC)
## 한 배열에 섞으면 조용히 서로를 먹는다. 작성 순서가 후보를 그 단계 것만으로 제한한다는
## GDD §4.4의 "문법이 인식을 지킨다"가 코드에선 이 분리로 나타난다
static func _best_scores(norm: PackedVector2Array, templates: Array[Dictionary],
		allowed: Array[int]) -> Dictionary:
	var out := {}
	for t: int in allowed:
		out[t] = 0.0
	for t: Dictionary in templates:
		var ty := int(t.type)
		if not allowed.has(ty):
			continue
		var score := clampf(
			1.0 - distance_at_best_angle(norm, t.points) / (0.5 * sqrt(2.0)), 0.0, 1.0)
		if score > float(out[ty]):
			out[ty] = score
	return out


static func _runner_up(by_type: Dictionary, allowed: Array[int], best: int) -> int:
	var second := -1
	for t: int in allowed:
		if t == best:
			continue
		if second < 0 or float(by_type.get(t, 0.0)) > float(by_type.get(second, 0.0)):
			second = t
	return second


static func _is_impact_water_pair(a: int, b: int) -> bool:
	return (
		(a == Enums.RuneType.IMPACT and b == Enums.RuneType.WATER)
		or (a == Enums.RuneType.WATER and b == Enums.RuneType.IMPACT))


## 감김 밴드 → 허용 룬 후보. 물~(≤0.48바퀴)과 바람◎(≥2.05바퀴)은 절대 같은 밴드에 없다.
## 그 아래에서는 불△·충격>·물~을 **전부 후보로 두고 $1이 고르게** 한다 — 이 셋의 감김은
## 서로 겹쳐서 게이트로 가를 수 없다(위 상수 주석의 실측 분포 참고).
static func winding_candidates(net_abs: float) -> Array[int]:
	var out: Array[int] = []
	if net_abs >= WINDING_WIND_MIN:
		out.append(Enums.RuneType.WIND)
	else:
		out.append(Enums.RuneType.FIRE)
		out.append(Enums.RuneType.IMPACT)
		out.append(Enums.RuneType.WATER)
	return out


## 감김(총 회전각) 피처 — **스무딩 후** 측정한다. 손 지터가 만드는 가짜 꺾임이
## 서로 상쇄되지 않고 누적되면 값이 크게 튄다(스무딩 전 충격>가 2.14바퀴까지 치솟아
## 바람◎ 게이트에 잘못 걸릴 수 있었다). 스무딩하면 충격>·물~이 0.67바퀴 아래로 내려앉아
## 바람◎(≥2.05)과의 간격이 확실해진다.
static func winding(points: PackedVector2Array) -> float:
	return net_rotation(smoothed(resample(points, RESAMPLE_N), RUN_SMOOTH_PASSES))


static func _ensure_templates() -> void:
	if not _templates.is_empty():
		return
	for raw: Dictionary in RuneTemplates.raw_all():
		var pts: PackedVector2Array = raw.points
		_templates.append({"type": raw.type, "points": normalize_for_match(pts)})
		var rev := pts.duplicate()
		rev.reverse()
		_templates.append({"type": raw.type, "points": normalize_for_match(rev)})


# ─────────────────────────── (e) 화살표 + 문양 글자 ───────────────────────────

## 한 획에서 기하와 글자를 **함께** 읽는다 (GDD §4.4). 방향·기점·길이는 시작·끝·총연장만 쓰므로
## 모양이 그대로 남아 $1 매칭에 넘길 수 있다 — 궤적을 포기했기에 가능해진 일이다.
static func _arrow_result(points: PackedVector2Array, st: float) -> Dictionary:
	var g := recognize_glyph(points)
	return {
		"role": Enums.StrokeRole.ARROW,
		"direction": (points[points.size() - 1] - points[0]).angle(),
		"length": path_length(points),
		"start": points[0],
		"score": st,
		"glyph": int(g.type),
		"glyph_score": float(g.score),
	}


## 문양 글자 인식 (GDD §4.3) — 팅김⚡ / 유도∿ / 관통‖, **어느 것도 아니면 BASIC**.
## 반환: {"type": Enums.GlyphType, "score": float}
##
## 🔴 **거부가 없다.** 룬은 점수 미달이면 DECOR로 떨궈 획을 버리지만, 문양은 진을 뚫고 나간
## 이상 무조건 탄이다 — 실패의 값이 BASIC이다 (GDD §4.5).
static func recognize_glyph(points: PackedVector2Array) -> Dictionary:
	var basic := {"type": int(Enums.GlyphType.BASIC), "score": 0.0}
	if points.size() < MIN_POINTS or path_length(points) < MIN_STROKE_LEN:
		return basic
	# 아주 곧은 획은 템플릿을 태우지 않고 즉시 BASIC — 튜토리얼의 직선 화살표가 여기로 나간다
	if straightness(points) >= GLYPH_BASIC_STRAIGHT:
		return basic
	# 현에서 거의 안 벗어나는 획도 BASIC — **이쪽이 주 방어선이다** (상수 주석의 실측 분포)
	if chord_bow(points) < GLYPH_MIN_BOW:
		return basic

	_ensure_glyph_templates()
	var allowed: Array[int] = [
		Enums.GlyphType.BOUNCE, Enums.GlyphType.HOMING, Enums.GlyphType.PIERCE]
	var by_type := _best_scores(normalize_for_match(points), _glyph_templates, allowed)
	var best := int(allowed[0])
	for t: int in allowed:
		if float(by_type[t]) > float(by_type[best]):
			best = t

	# 피처는 **후보를 지우지 않는다.** $1이 확신 못 할 때(점수차 < 마진)만 개입하고, 그때도
	# 접전 중인 둘 중 하나를 가리킬 때만 뒤집는다 — 세 번째 글자를 끌어오지 않는다.
	# 세션 7 교훈: 피처를 하드 게이트로 쓰면 정답을 통째로 지워 버린다 (recognize_rune 주석)
	var runner_up := _runner_up(by_type, allowed, best)
	if runner_up >= 0 \
			and float(by_type[best]) - float(by_type[runner_up]) < GLYPH_TIE_MARGIN:
		var hinted := feature_glyph(points)
		if hinted == best or hinted == runner_up:
			best = hinted

	var score := float(by_type[best])
	if score < GLYPH_MIN_SCORE:
		return basic
	return {"type": best, "score": score}


## 기하 피처가 가리키는 글자 — $1이 흔들릴 때의 보조 신호.
## 세 글자의 표식은 서로 겹치지 않는다:
##   팅김⚡ = 부호가 교대하는 꺾임 런이 **여러 개** (지그재그)
##   관통‖ = 런 1개 + **급반전** (화살촉이 한 점에 꺾임을 몰아 넣는다)
##   유도∿ = 런 1개 + 완만 (같은 부호의 곡률이 호 전체에 **퍼진다**)
static func feature_glyph(points: PackedVector2Array) -> int:
	if curvature_runs(points) >= 2:
		return int(Enums.GlyphType.BOUNCE)
	if glyph_max_turn(points) >= GLYPH_SHARP_TURN:
		return int(Enums.GlyphType.PIERCE)
	return int(Enums.GlyphType.HOMING)


## 국소 최대 꺾임 — **스무딩 후** 잰다. 손 지터가 만드는 가짜 꺾임은 원본에서 1rad을 우습게
## 넘겨 모든 획을 "급반전"으로 만든다 (curvature_runs가 같은 전처리를 쓰는 이유와 동일)
static func glyph_max_turn(points: PackedVector2Array) -> float:
	return max_turn(smoothed(resample(points, RUN_RESAMPLE_N), RUN_SMOOTH_PASSES))


## 획이 현(시작→끝)에서 벗어나는 최대 수직거리 ÷ 현 길이. 곧은 획은 0에 가깝다.
## 직진성(= 현 ÷ 경로길이)과 다른 것을 잰다: 잔물결이 많아 경로가 긴 획도 현 근처에 머물 수 있다.
static func chord_bow(points: PackedVector2Array) -> float:
	var pts := smoothed(resample(points, RUN_RESAMPLE_N), RUN_SMOOTH_PASSES)
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	var chord := a.distance_to(b)
	if chord <= 1e-6:
		return 0.0
	var axis := (b - a) / chord
	var m := 0.0
	for p: Vector2 in pts:
		m = maxf(m, absf((p - a).cross(axis)))
	return m / chord


## 문양 템플릿은 **역방향 변형을 넣지 않는다** (룬과 다른 점).
## 관통‖의 화살촉은 **끝**에 있어야 한다 — 획은 진 안에서 시작해 밖에서 끝나므로 방향이
## 기하로 이미 정해져 있고, 역방향 템플릿을 넣으면 "촉이 진 쪽에 붙은 획"까지 관통으로 읽힌다.
## 좌우 거울상은 GlyphTemplates.raw_all()이 이미 함께 낸다.
static func _ensure_glyph_templates() -> void:
	if not _glyph_templates.is_empty():
		return
	for raw: Dictionary in GlyphTemplates.raw_all():
		var pts: PackedVector2Array = raw.points
		_glyph_templates.append({"type": raw.type, "points": normalize_for_match(pts)})


# ─────────────────────────── $1 기하 유틸 ───────────────────────────

static func normalize_for_match(points: PackedVector2Array) -> PackedVector2Array:
	var p := resample(points, RESAMPLE_N)
	p = rotate_points(p, -indicative_angle(p))
	p = scale_to_square(p)
	return translate_to_origin(p)


static func resample(points: PackedVector2Array, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.is_empty():
		out.resize(n)
		return out
	var interval := path_length(points) / float(n - 1)
	if interval <= 1e-12:
		for i in n:
			out.append(points[0])
		return out
	out.append(points[0])
	var acc := 0.0
	var prev := points[0]
	var i := 1
	while i < points.size():
		var d := prev.distance_to(points[i])
		if acc + d >= interval and d > 0.0:
			var q := prev.lerp(points[i], (interval - acc) / d)
			out.append(q)
			prev = q
			acc = 0.0
		else:
			acc += d
			prev = points[i]
			i += 1
	while out.size() < n:
		out.append(points[points.size() - 1])
	if out.size() > n:
		out.resize(n)
	return out


static func indicative_angle(pts: PackedVector2Array) -> float:
	return (_centroid(pts) - pts[0]).angle()


static func rotate_points(pts: PackedVector2Array, ang: float) -> PackedVector2Array:
	var c := _centroid(pts)
	var cs := cos(ang)
	var sn := sin(ang)
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		var v := p - c
		out.append(c + Vector2(v.x * cs - v.y * sn, v.x * sn + v.y * cs))
	return out


static func scale_to_square(pts: PackedVector2Array) -> PackedVector2Array:
	var bbox := _bbox(pts)
	var w := maxf(bbox.size.x, 1e-6)
	var h := maxf(bbox.size.y, 1e-6)
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(Vector2(p.x / w, p.y / h))
	return out


static func translate_to_origin(pts: PackedVector2Array) -> PackedVector2Array:
	var c := _centroid(pts)
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p - c)
	return out


static func distance_at_best_angle(pts: PackedVector2Array, tmpl: PackedVector2Array) -> float:
	var phi := 0.5 * (sqrt(5.0) - 1.0)
	var a := -ANGLE_RANGE
	var b := ANGLE_RANGE
	var x1 := phi * a + (1.0 - phi) * b
	var f1 := _distance_at_angle(pts, tmpl, x1)
	var x2 := (1.0 - phi) * a + phi * b
	var f2 := _distance_at_angle(pts, tmpl, x2)
	while absf(b - a) > ANGLE_PRECISION:
		if f1 < f2:
			b = x2
			x2 = x1
			f2 = f1
			x1 = phi * a + (1.0 - phi) * b
			f1 = _distance_at_angle(pts, tmpl, x1)
		else:
			a = x1
			x1 = x2
			f1 = f2
			x2 = (1.0 - phi) * a + phi * b
			f2 = _distance_at_angle(pts, tmpl, x2)
	return minf(f1, f2)


static func _distance_at_angle(pts: PackedVector2Array, tmpl: PackedVector2Array, ang: float) -> float:
	var cs := cos(ang)
	var sn := sin(ang)
	var n := mini(pts.size(), tmpl.size())
	if n == 0:
		return INF
	var total := 0.0
	for i in n:
		var p: Vector2 = pts[i]
		var rp := Vector2(p.x * cs - p.y * sn, p.x * sn + p.y * cs)
		total += rp.distance_to(tmpl[i])
	return total / float(n)


# ─────────────────────────── 공용 피처 ───────────────────────────

static func path_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## 리샘플 후 직진성 = 직선거리 / 경로길이 (지터에 강함)
static func straightness(points: PackedVector2Array) -> float:
	var p := resample(points, 24)
	var plen := path_length(p)
	if plen <= 1e-9:
		return 0.0
	return clampf(p[0].distance_to(p[p.size() - 1]) / plen, 0.0, 1.0)


## 부호 있는 총 회전각 — 감김 횟수 피처 (물~ vs 바람◎ 게이트)
static func net_rotation(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, pts.size() - 1):
		var v1 := pts[i] - pts[i - 1]
		var v2 := pts[i + 1] - pts[i]
		if v1.length_squared() < 1e-12 or v2.length_squared() < 1e-12:
			continue
		total += v1.angle_to(v2)
	return total


## 유의미한(|누적 회전| ≥ RUN_MIN_TURN) 같은 부호 꺾임 런의 개수 — 파형성 척도.
## 직선 0 / ">" 1 / 물결(1.5주기+) ≥ 2.
static func curvature_runs(points: PackedVector2Array) -> int:
	var pts := smoothed(resample(points, RUN_RESAMPLE_N), RUN_SMOOTH_PASSES)
	var runs := 0
	var run_sum := 0.0
	for i in range(1, pts.size() - 1):
		var v1 := pts[i] - pts[i - 1]
		var v2 := pts[i + 1] - pts[i]
		if v1.length_squared() < 1e-12 or v2.length_squared() < 1e-12:
			continue
		var t := v1.angle_to(v2)
		if run_sum != 0.0 and signf(t) != signf(run_sum):
			if absf(run_sum) >= RUN_MIN_TURN:
				runs += 1
			run_sum = 0.0
		run_sum += t
	if absf(run_sum) >= RUN_MIN_TURN:
		runs += 1
	return runs


static func max_turn(pts: PackedVector2Array) -> float:
	var m := 0.0
	for i in range(1, pts.size() - 1):
		var v1 := pts[i] - pts[i - 1]
		var v2 := pts[i + 1] - pts[i]
		if v1.length_squared() < 1e-12 or v2.length_squared() < 1e-12:
			continue
		m = maxf(m, absf(v1.angle_to(v2)))
	return m


## 끝점 고정 이동평균 스무딩 — 지터 억제용 (렌더·피처 공용)
static func smoothed(pts: PackedVector2Array, passes := 1) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var cur := pts
	for _p in passes:
		var out := PackedVector2Array()
		out.append(cur[0])
		for i in range(1, cur.size() - 1):
			out.append((cur[i - 1] + cur[i] * 2.0 + cur[i + 1]) * 0.25)
		out.append(cur[cur.size() - 1])
		cur = out
	return cur


static func _centroid(pts: PackedVector2Array) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	return c / float(pts.size())


static func _bbox(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var lo: Vector2 = pts[0]
	var hi: Vector2 = pts[0]
	for p: Vector2 in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)
