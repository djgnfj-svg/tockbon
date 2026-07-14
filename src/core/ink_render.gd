extends RefCounted
## 먹선 렌더 공용 (core·리드 소유) — SpellDesign.strokes(플레이어가 그린 원본 획)를
## Line2D 먹선으로 그린다. 드로잉룸·캐스팅 마법진·투사체·UI 썸네일이 전부 이 파일 하나를 쓴다.
## GDD §10.5: "드로잉한 그대로가 이펙트가 된다" — 새 에셋 없이 플레이어의 획이 그대로 화면에 나온다.
## 계약: TECH_SPEC §4.4. 사용: const InkRender := preload("res://src/core/ink_render.gd")

const BASE_WIDTH := 3.5
const INK_COLOR := Color(0.13, 0.11, 0.10)
const MAX_CURVE_POINTS := 16
const MIN_PRESSURE := 0.15
## 필압 상한이 1.0이 아닌 이유: 마우스 합성 필압은 **평균 1.0으로 정규화**되므로(잉크 소모 중립화,
## design_builder._ink_length가 평균 필압을 곱한다) 1.0을 넘는 구간이 반드시 생긴다.
## 1.0에서 자르면 "머물러서 부푼 자리"가 렌더에서 깎여 나간다. 태블릿 필압(0..1)은 영향 없음.
const MAX_PRESSURE := 1.6

## 종이 위 먹 (드로잉룸·UI 썸네일) — 어두운 안료
const RUNE_INK := {
	Enums.RuneType.FIRE: Color(0.48, 0.18, 0.11),
	Enums.RuneType.IMPACT: Color(0.42, 0.34, 0.08),
	Enums.RuneType.WATER: Color(0.11, 0.29, 0.42),
	Enums.RuneType.WIND: Color(0.18, 0.42, 0.31),
}
## 필드 발광 (캐스팅 마법진·투사체) — 어두운 숲 바닥에서 읽히도록. projectile.gd RUNE_COLORS와 동계열
const RUNE_BRIGHT = {
	Enums.RuneType.FIRE: Color(1.0, 0.55, 0.1),
	Enums.RuneType.IMPACT: Color(1.0, 0.9, 0.2),
	Enums.RuneType.WATER: Color(0.25, 0.55, 1.0),
	Enums.RuneType.WIND: Color(0.65, 0.95, 0.45),
}
## 룬이 아닌 획(진·꼬리·장식)의 색 — bright=필드 / false=종이
const STRUCTURE_INK := Color(0.13, 0.11, 0.10)
const STRUCTURE_BRIGHT := Color(0.95, 0.92, 0.82)

## build_design 기본 필터: 화살표 제외 — 화살표는 진에 남지 않고 투사체로 날아간다 (TECH_SPEC §4.4)
const CIRCLE_ROLES: Array[int] = [
	Enums.StrokeRole.CIRCLE, Enums.StrokeRole.RUNE,
	Enums.StrokeRole.TAIL, Enums.StrokeRole.DECOR,
]
## 전체 획 — 썸네일·도감처럼 "플레이어가 그린 그림 전부"를 보여줄 때.
## StrokeRole이 늘면 **여기만** 고친다 (호출자가 각자 목록을 복제하면 조용히 어긋난다)
const ALL_ROLES: Array[int] = [
	Enums.StrokeRole.CIRCLE, Enums.StrokeRole.RUNE, Enums.StrokeRole.ARROW,
	Enums.StrokeRole.TAIL, Enums.StrokeRole.DECOR,
]


## 캔버스 단위 1.0 → 월드 px. **circle_radius_px의 2배로 고정** — 이래야 진 반지름
## (캔버스 circle_radius×0.5) × unit_px = circle_radius × circle_radius_px 가 되어
## 기존 ArrowData.origin 월드 공식과 스케일이 일치한다 (TECH_SPEC §4.4 — 이 관계를 깨지 말 것)
static func unit_px(balance: BalanceData) -> float:
	return balance.circle_radius_px * 2.0


static func rune_color(rune_type: int, bright: bool = false) -> Color:
	var table: Dictionary = RUNE_BRIGHT if bright else RUNE_INK
	return table.get(rune_type, INK_COLOR)


static func role_color(role: int, rune_type: int, bright: bool = false) -> Color:
	if role == Enums.StrokeRole.RUNE:
		return rune_color(rune_type, bright)
	var base := STRUCTURE_BRIGHT if bright else STRUCTURE_INK
	if role == Enums.StrokeRole.DECOR:
		base.a *= 0.35
	return base


## 진(원)의 중심 — 도안의 앵커. CIRCLE 획이 없으면 전체 획의 중심으로 폴백.
static func circle_center(design: SpellDesign) -> Vector2:
	for s: StrokeData in design.strokes:
		if s.role == Enums.StrokeRole.CIRCLE and s.points.size() > 0:
			return _centroid(s.points)
	var all := PackedVector2Array()
	for s: StrokeData in design.strokes:
		all.append_array(s.points)
	return _centroid(all) if all.size() > 0 else Vector2.ZERO


## 도안 → 먹선 Line2D 트리. **진 중심이 원점**이므로 반환 노드를 발밑에 두면 그대로 마법진이 된다.
## strokes가 비면 null (샘플 도안 — 호출자가 기존 스프라이트로 폴백).
## opts: roles(Array[int] 필터) / bright(bool) / width_mult(float) / alpha(float)
static func build_design(design: SpellDesign, px_per_unit: float, opts: Dictionary = {}) -> Node2D:
	if design == null or design.strokes.is_empty():
		return null
	var roles: Array = opts.get("roles", CIRCLE_ROLES)
	var bright: bool = opts.get("bright", false)
	var width_mult: float = opts.get("width_mult", 1.0)
	var alpha: float = opts.get("alpha", 1.0)
	var center := circle_center(design)

	var root := Node2D.new()
	var drawn := 0
	for s: StrokeData in design.strokes:
		if not roles.has(int(s.role)):
			continue
		var pts := PackedVector2Array()
		for p: Vector2 in s.points:
			pts.append((p - center) * px_per_unit)
		if pts.size() < 2:
			continue
		var col := role_color(int(s.role), int(design.rune_type), bright)
		col.a *= alpha
		root.add_child(make_line(pts, s.pressures, BASE_WIDTH * width_mult, col))
		drawn += 1
	if drawn == 0:
		root.free()
		return null
	return root


## 도안이 실제로 그려질 경계 (진 중심 = 원점, **캔버스 단위**, 선 굵기 제외).
## 칸에 맞춰 넣으려면 bbox를 알아야 하는데 bbox는 그려 봐야 안다 — 그 때문에 렌더를 두 번 하지
## 않도록 core가 점 계산만 따로 해준다. make_line과 **같은 스무딩**을 적용하므로 결과가 정확히 일치한다.
## 반환 Rect2에 배율 s를 곱하면 build_design(design, s)의 bbox와 같다 (스무딩은 선형 = 스케일과 교환 가능).
## 그릴 획이 없으면 빈 Rect2.
static func design_bbox(design: SpellDesign, roles: Array = CIRCLE_ROLES) -> Rect2:
	if design == null or design.strokes.is_empty():
		return Rect2()
	var center := circle_center(design)
	var found := false
	var mn := Vector2.ZERO
	var mx := Vector2.ZERO
	for s: StrokeData in design.strokes:
		if not roles.has(int(s.role)) or s.points.size() < 2:
			continue
		var pts := PackedVector2Array()
		for p: Vector2 in s.points:
			pts.append(p - center)
		for p: Vector2 in smoothed(pts, 1):
			if not found:
				mn = p
				mx = p
				found = true
				continue
			mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
			mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	if not found:
		return Rect2()
	return Rect2(mn, mx - mn)


## 화살표 획 → 먹선 Line2D. **시작점=원점, +X=발사 방향**인 로컬 공간으로 회전·정규화한다.
## 투사체는 rotation에 월드 발사각만 넣으면 그린 획이 그대로 날아가는 모양이 된다.
static func arrow_line(stroke: StrokeData, px_per_unit: float, opts: Dictionary = {}) -> Line2D:
	var pts := arrow_local_points(stroke, px_per_unit)
	if pts.size() < 2:
		return null
	var bright: bool = opts.get("bright", true)
	var rune_type: int = opts.get("rune_type", Enums.RuneType.FIRE)
	var col: Color = opts.get("color", rune_color(rune_type, bright))
	return make_line(pts, stroke.pressures, BASE_WIDTH * float(opts.get("width_mult", 1.0)), col)


## 화살표 획의 로컬 점열 — 시작=원점, 시작→끝 벡터가 +X. 캔버스 단위 × px_per_unit.
static func arrow_local_points(stroke: StrokeData, px_per_unit: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := stroke.points.size()
	if n < 2:
		return out
	var start := stroke.points[0]
	var abs_dir := (stroke.points[n - 1] - start).angle()
	for p: Vector2 in stroke.points:
		out.append((p - start).rotated(-abs_dir) * px_per_unit)
	return out


## 투사체 먹선 — ArrowData.path(이미 로컬 +X 정규화된 점열)를 **머리가 노드 원점**에 오도록
## 평행이동해 Line2D를 만든다. 꼬리가 x<0으로 뒤에 끌리므로 충돌 지점(원점)과 보이는 머리가 일치.
## 투사체 렌더의 보편 규칙이라 core가 소유한다 (모듈 B·적 투사체·곡선 추종이 재구현하지 않게).
## path가 2점 미만이면 null — 호출자가 기존 스프라이트로 폴백.
static func tail_line(path: PackedVector2Array, pressures: PackedFloat32Array,
		px_per_unit: float, opts: Dictionary = {}) -> Line2D:
	if path.size() < 2:
		return null
	var head := path[path.size() - 1] * px_per_unit
	var pts := PackedVector2Array()
	for p: Vector2 in path:
		pts.append(p * px_per_unit - head)
	var bright: bool = opts.get("bright", true)
	var rune_type: int = opts.get("rune_type", Enums.RuneType.FIRE)
	var col: Color = opts.get("color", rune_color(rune_type, bright))
	return make_line(pts, pressures, BASE_WIDTH * float(opts.get("width_mult", 1.0)), col)


## 필압 배열을 n개로 리샘플 — ArrowData.path(리샘플된 점열)와 인덱스를 맞추기 위해.
## 점열은 호길이 기준 리샘플이지만 필압은 느리게 변하므로 균일 인덱스 샘플로 충분하다.
static func resample_pressures(pressures: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if pressures.is_empty() or n < 2:
		return out
	for i in n:
		var t := float(i) / float(n - 1)
		out.append(pressures[int(round(t * float(pressures.size() - 1)))])
	return out


static func make_line(points: PackedVector2Array, pressures: PackedFloat32Array,
		width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.points = smoothed(points, 1)
	line.width_curve = pressure_curve(pressures)
	return line


## 필압 → Line2D.width_curve (획의 굵기 변화를 그대로 보존).
## Curve의 기본 max_value는 1.0이라 1.0 초과 필압이 조용히 잘린다 — 명시적으로 열어 준다.
static func pressure_curve(pressures: PackedFloat32Array) -> Curve:
	if pressures.size() < 2:
		return null
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = MAX_PRESSURE
	var n := mini(pressures.size(), MAX_CURVE_POINTS)
	for i in n:
		var t := float(i) / float(n - 1)
		var idx := int(t * float(pressures.size() - 1))
		curve.add_point(Vector2(t, clampf(pressures[idx], MIN_PRESSURE, MAX_PRESSURE)))
	return curve


## 이동평균 스무딩 — 손 떨림 제거. Recognizer.smoothed의 core 사본
## (core는 모듈을 preload하지 않는다 — 의존 방향 유지, TECH_SPEC §2)
static func smoothed(points: PackedVector2Array, iterations: int = 1) -> PackedVector2Array:
	var pts := points
	for _i in maxi(iterations, 0):
		if pts.size() < 3:
			return pts
		var out := PackedVector2Array()
		out.append(pts[0])
		for i in range(1, pts.size() - 1):
			out.append((pts[i - 1] + pts[i] + pts[i + 1]) / 3.0)
		out.append(pts[pts.size() - 1])
		pts = out
	return pts


static func _centroid(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p: Vector2 in points:
		sum += p
	return sum / float(points.size())
