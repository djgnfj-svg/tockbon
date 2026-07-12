extends RefCounted
## $1 유니스트로크 인식기 + 기하 판정 파이프라인 (TECH_SPEC §6, GDD §4.4).
## 순수 정적 함수 — 씬·오토로드 의존 없음(헤드리스 테스트 가능). 좌표는 캔버스 정규화(0..1).
##
## classify_stroke 파이프라인 (획 종료 시 1회):
##   (a) 원 기하 판정 — 컨텍스트에 원이 없을 때만. $1 미사용
##   (b) 조준진 꼬리 판정 — 원이 있고 꼬리가 없을 때만
##   (c) 직진 사전 게이트 → 화살표 (파라미터 직접 추출)
##   (d) $1 룬 인식 — 감김(총 회전각) 밴드로 후보를 먼저 제한해
##       물~ / 바람◎ 교차 오인식을 구조적으로 차단 (GDD 리스크 1)
##   (e) 폴백 화살표 / DECOR
## 사용: const Recognizer := preload("res://src/drawing/recognizer.gd")

const RuneTemplates := preload("res://src/drawing/rune_templates.gd")

# ── $1 파라미터 ──
const RESAMPLE_N := 64
const ANGLE_RANGE := PI / 4.0          # 최적 회전 황금분할 탐색 범위 ±45°
const ANGLE_PRECISION := 0.035         # ≈ 2°
const RUNE_MIN_SCORE := 0.60           # 미달 시 룬으로 인정하지 않음

# ── 감김 밴드 (|총 회전각| rad) — 후보 룬 게이트 ──
const WINDING_FIRE_MIN := 0.55 * TAU   # 미만 → {충격>, 물~} / 이상 → {불△}
const WINDING_WIND_MIN := 1.50 * TAU   # 이상 → {바람◎}만

# ── 파형성(곡률 부호 교대) — 충격> vs 물~ 게이트 ──
const RUN_RESAMPLE_N := 32
const RUN_MIN_TURN := 0.45             # 유의미한 꺾임 런의 최소 누적 회전(rad)
const RUN_SMOOTH_PASSES := 2           # 런 계산 전 이동평균 스무딩 횟수 (노이즈 런 억제)


# ── 원 기하 판정 ──
const CIRCLE_RESAMPLE_N := 48
const CIRCLE_MAX_GAP_RATIO := 0.35     # 시작-끝 거리 / bbox 대각선
const CIRCLE_MAX_RADIUS_CV := 0.14     # 반지름 변동계수(std/mean)
const CIRCLE_NET_MIN := 0.70 * TAU     # 총 회전각 하한 (한 바퀴 근사)
const CIRCLE_NET_MAX := 1.40 * TAU     # 상한 (나선 배제)
const CIRCLE_MAX_TURN := 1.15          # 국소 최대 꺾임(rad) — 삼각형 등 다각형 배제

# ── 조준진 꼬리 판정 ──
const TAIL_ANNULUS_MIN := 0.70         # 시작점 중심거리 ∈ [0.70r, 1.35r]
const TAIL_ANNULUS_MAX := 1.35
const TAIL_MAX_LEN_RATIO := 1.10       # 획 길이 ≤ 1.10 × r
const TAIL_MIN_STRAIGHT := 0.75

# ── 화살표 ──
const ARROW_STRAIGHT_PRE := 0.90       # 이상이면 룬을 건너뛰고 즉시 화살표
const ARROW_STRAIGHT_FALLBACK := 0.80  # 룬 실패 시 폴백 화살표 최소 직진성

const MIN_POINTS := 4
const MIN_STROKE_LEN := 0.02

static var _templates: Array[Dictionary] = []


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
	elif not ctx.get("has_tail", false):
		var t := detect_tail(
			points,
			ctx.get("circle_center", Vector2(0.5, 0.5)),
			ctx.get("circle_radius", 0.25))
		if t.is_tail:
			return {"role": Enums.StrokeRole.TAIL, "aim_axis": t.aim_axis, "score": t.score}

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
		return {"role": Enums.StrokeRole.DECOR, "score": float(r.score), "reason": "rune_low_score"}

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


# ─────────────────────────── (b) 꼬리 ───────────────────────────

static func detect_tail(points: PackedVector2Array, center: Vector2, radius: float) -> Dictionary:
	var out := {"is_tail": false, "aim_axis": 0.0, "score": 0.0}
	if radius <= 1e-6:
		return out
	var first := points[0]
	var last := points[points.size() - 1]
	var d0 := first.distance_to(center)
	var d1 := last.distance_to(center)
	var plen := path_length(points)
	var st := straightness(points)
	var ok := (
		d0 >= TAIL_ANNULUS_MIN * radius and d0 <= TAIL_ANNULUS_MAX * radius
		and d1 > maxf(d0 + 0.02, radius * 1.02)
		and plen <= TAIL_MAX_LEN_RATIO * radius
		and st >= TAIL_MIN_STRAIGHT
	)
	if ok:
		out.is_tail = true
		out.aim_axis = (last - center).angle()
		out.score = st
	return out


# ─────────────────────────── (c) $1 룬 ───────────────────────────

static func recognize_rune(points: PackedVector2Array) -> Dictionary:
	_ensure_templates()
	var rs := resample(points, RESAMPLE_N)
	var net := net_rotation(rs)
	var allowed := winding_candidates(absf(net))
	# 저감김 밴드({충격>, 물~})는 곡률 부호 교대 수로 한 번 더 가른다:
	# ">"는 유의미한 꺾임 런 ≤1, 파형은 교대 런 ≥2.
	if allowed.has(int(Enums.RuneType.IMPACT)) and allowed.has(int(Enums.RuneType.WATER)):
		if curvature_runs(points) >= 2:
			allowed.erase(int(Enums.RuneType.IMPACT))
		else:
			allowed.erase(int(Enums.RuneType.WATER))
	var norm := normalize_for_match(points)
	var best_d := INF
	var best_type := int(Enums.RuneType.FIRE)
	for t: Dictionary in _templates:
		if not allowed.has(int(t.type)):
			continue
		var d := distance_at_best_angle(norm, t.points)
		if d < best_d:
			best_d = d
			best_type = int(t.type)
	var score := 0.0
	if best_d < INF:
		score = clampf(1.0 - best_d / (0.5 * sqrt(2.0)), 0.0, 1.0)
	return {"type": best_type, "score": score, "net": net}


## 감김 밴드 → 허용 룬 후보. 물~(|net|≈0)과 바람◎(|net|≥1.5바퀴)은 절대 같은 밴드에 없다.
static func winding_candidates(net_abs: float) -> Array[int]:
	var out: Array[int] = []
	if net_abs >= WINDING_WIND_MIN:
		out.append(Enums.RuneType.WIND)
	elif net_abs >= WINDING_FIRE_MIN:
		out.append(Enums.RuneType.FIRE)
	else:
		out.append(Enums.RuneType.IMPACT)
		out.append(Enums.RuneType.WATER)
	return out


static func _ensure_templates() -> void:
	if not _templates.is_empty():
		return
	for raw: Dictionary in RuneTemplates.raw_all():
		var pts: PackedVector2Array = raw.points
		_templates.append({"type": raw.type, "points": normalize_for_match(pts)})
		var rev := pts.duplicate()
		rev.reverse()
		_templates.append({"type": raw.type, "points": normalize_for_match(rev)})


# ─────────────────────────── (d) 화살표 ───────────────────────────

static func _arrow_result(points: PackedVector2Array, st: float) -> Dictionary:
	return {
		"role": Enums.StrokeRole.ARROW,
		"direction": (points[points.size() - 1] - points[0]).angle(),
		"length": path_length(points),
		"start": points[0],
		"score": st,
	}


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
