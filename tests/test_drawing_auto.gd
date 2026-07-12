extends SceneTree
## 모듈 A 자동 검증 — 합성 획 데이터로 인식 파이프라인·SpellDesign 조립을 검사한다.
## 실행: Godot --headless --path . -s res://tests/test_drawing_auto.gd
## 통과 조건: FAIL 0건, 특히 물~/바람◎ 교차 오인식 0건 (GDD 리스크 1).

const Recognizer := preload("res://src/drawing/recognizer.gd")
const DesignBuilder := preload("res://src/drawing/design_builder.gd")

var _pass := 0
var _fail := 0
var _water_wind_cross := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20260712
	_test_circles()
	_test_tails()
	_test_runes()
	_test_arrows()
	_test_assembly_aimed()
	_test_assembly_fixed()
	_test_builder_edges()
	print("──────────────────────────────")
	print("RESULT pass=%d fail=%d water_wind_cross=%d" % [_pass, _fail, _water_wind_cross])
	if _fail == 0 and _water_wind_cross == 0:
		print("DRAWING_AUTO_OK")
	quit(0 if _fail == 0 and _water_wind_cross == 0 else 1)


func _check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: ", name)


# ─────────────────────────── 합성 획 생성기 ───────────────────────────
# 템플릿 생성기와 파라미터화가 다르게 설계됨 — 템플릿을 템플릿으로 검사하지 않기 위함.

func _noisy(pts: PackedVector2Array, e: float) -> PackedVector2Array:
	if e <= 0.0:
		return pts
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p + Vector2(_rng.randf_range(-e, e), _rng.randf_range(-e, e)))
	return out


func _gen_circle(c: Vector2, r: float, aspect := 1.0, noise := 0.0, sweep := 0.98) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 72
	for i in n:
		var a := -PI / 2.0 + TAU * sweep * float(i) / float(n - 1)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * aspect))
	return _noisy(pts, noise)


func _gen_line(a: Vector2, b: Vector2, n := 12, noise := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(a.lerp(b, float(i) / float(n - 1)))
	return _noisy(pts, noise)


func _gen_triangle(c: Vector2, size: float, rot := 0.0, noise := 0.0) -> PackedVector2Array:
	var verts: Array[Vector2] = []
	for k in 3:
		var a := rot - PI / 2.0 + TAU * float(k) / 3.0
		verts.append(c + Vector2(cos(a), sin(a)) * size)
	var pts := PackedVector2Array()
	for e in 3:
		for i in 14:
			pts.append(verts[e].lerp(verts[(e + 1) % 3], float(i) / 14.0))
	pts.append(verts[0])
	return _noisy(pts, noise)


func _gen_angle(start: Vector2, corner: Vector2, end: Vector2, noise := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		pts.append(start.lerp(corner, float(i) / 12.0))
	for i in 12:
		pts.append(corner.lerp(end, float(i + 1) / 12.0))
	return _noisy(pts, noise)


func _gen_wave(origin: Vector2, width: float, amp: float, periods: float,
		phase := 0.0, noise := 0.0, flip := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 56
	for i in n:
		var t := float(i) / float(n - 1)
		var y := amp * sin(phase + TAU * periods * t)
		if flip:
			y = -y
		pts.append(origin + Vector2(width * t, y))
	return _noisy(pts, noise)


func _gen_spiral(c: Vector2, r_max: float, loops: float, growth := 0.7,
		th0 := 0.0, noise := 0.0, inward := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 80
	for i in n:
		var t := float(i) / float(n - 1)
		var th := th0 + loops * TAU * t
		var r := r_max * pow(t, growth)
		pts.append(c + Vector2(cos(th), sin(th)) * r)
	if inward:
		pts.reverse()
	return _noisy(pts, noise)


# ─────────────────────────── 1. 원 기하 판정 ───────────────────────────

func _test_circles() -> void:
	var ctx := {}
	var r := Recognizer.classify_stroke(_gen_circle(Vector2(0.5, 0.5), 0.2), ctx)
	_check(int(r.role) == Enums.StrokeRole.CIRCLE, "정원 → CIRCLE")
	if int(r.role) == Enums.StrokeRole.CIRCLE:
		_check(Vector2(r.center).distance_to(Vector2(0.5, 0.5)) < 0.03, "정원 중심 오차")
		_check(absf(float(r.radius) - 0.2) < 0.03, "정원 반지름 오차")

	r = Recognizer.classify_stroke(_gen_circle(Vector2(0.45, 0.55), 0.22, 0.78), ctx)
	_check(int(r.role) == Enums.StrokeRole.CIRCLE, "찌그러진 원(0.78) → CIRCLE")

	r = Recognizer.classify_stroke(_gen_circle(Vector2(0.5, 0.5), 0.18, 1.0, 0.004), ctx)
	_check(int(r.role) == Enums.StrokeRole.CIRCLE, "노이즈 원 → CIRCLE")

	r = Recognizer.classify_stroke(_gen_triangle(Vector2(0.5, 0.5), 0.2), ctx)
	_check(int(r.role) != Enums.StrokeRole.CIRCLE, "삼각형은 원이 아님")

	r = Recognizer.classify_stroke(_gen_spiral(Vector2(0.5, 0.5), 0.2, 2.5), ctx)
	_check(int(r.role) != Enums.StrokeRole.CIRCLE, "나선은 원이 아님")


# ─────────────────────────── 2. 조준진 꼬리 ───────────────────────────

func _test_tails() -> void:
	var ctx := {
		"has_circle": true,
		"circle_center": Vector2(0.5, 0.5),
		"circle_radius": 0.22,
	}
	var r := Recognizer.classify_stroke(_gen_line(Vector2(0.73, 0.5), Vector2(0.86, 0.5)), ctx)
	_check(int(r.role) == Enums.StrokeRole.TAIL, "오른쪽 꼬리 → TAIL")
	if int(r.role) == Enums.StrokeRole.TAIL:
		_check(absf(float(r.aim_axis)) < 0.1, "오른쪽 꼬리 aim_axis ≈ 0")

	r = Recognizer.classify_stroke(_gen_line(Vector2(0.5, 0.29), Vector2(0.5, 0.16)), ctx)
	_check(int(r.role) == Enums.StrokeRole.TAIL, "위쪽 꼬리 → TAIL")
	if int(r.role) == Enums.StrokeRole.TAIL:
		_check(absf(wrapf(float(r.aim_axis) + PI / 2.0, -PI, PI)) < 0.1, "위쪽 꼬리 aim_axis ≈ -π/2")

	# 진 중심에서 시작하는 긴 직선은 꼬리가 아니라 화살표
	r = Recognizer.classify_stroke(_gen_line(Vector2(0.5, 0.5), Vector2(0.85, 0.5)), ctx)
	_check(int(r.role) == Enums.StrokeRole.ARROW, "중심 발 긴 직선 → ARROW (꼬리 아님)")

	# 꼬리가 이미 있으면 두 번째 꼬리형 획은 꼬리가 되지 않는다
	var ctx2 := ctx.duplicate()
	ctx2["has_tail"] = true
	r = Recognizer.classify_stroke(_gen_line(Vector2(0.73, 0.5), Vector2(0.86, 0.5)), ctx2)
	_check(int(r.role) != Enums.StrokeRole.TAIL, "두 번째 꼬리는 TAIL 아님")


# ─────────────────────────── 3. 룬 4종 ($1 + 감김 게이트) ───────────────────────────

func _rune_case(pts: PackedVector2Array, expected: int, name: String) -> void:
	# 실전과 같은 컨텍스트: 진·꼬리는 이미 있고 룬은 아직 없음
	var ctx := {
		"has_circle": true,
		"circle_center": Vector2(0.5, 0.5),
		"circle_radius": 0.35,
		"has_tail": true,
	}
	var r := Recognizer.classify_stroke(pts, ctx)
	var got := int(r.get("rune_type", -1)) if int(r.role) == Enums.StrokeRole.RUNE else -1
	if expected == Enums.RuneType.WATER and got == Enums.RuneType.WIND:
		_water_wind_cross += 1
	if expected == Enums.RuneType.WIND and got == Enums.RuneType.WATER:
		_water_wind_cross += 1
	_check(got == expected, "%s (got role=%s type=%s score=%.2f)" % [
		name, str(r.role), str(got), float(r.get("score", 0.0))])


func _test_runes() -> void:
	var c := Vector2(0.5, 0.5)
	# 불△ — 깨끗한 획 3 + 노이즈 획 3
	_rune_case(_gen_triangle(c, 0.16), Enums.RuneType.FIRE, "불△ 기본")
	_rune_case(_gen_triangle(c, 0.12, 0.5), Enums.RuneType.FIRE, "불△ 회전 0.5rad")
	var rev_tri := _gen_triangle(c, 0.18, -0.2)
	rev_tri.reverse()
	_rune_case(rev_tri, Enums.RuneType.FIRE, "불△ 역방향")
	for i in 3:
		_rune_case(_gen_triangle(c, 0.15, 0.1 * float(i), 0.005),
			Enums.RuneType.FIRE, "불△ 노이즈 %d" % i)

	# 충격> — 깨끗한 획 3 + 노이즈 획 3
	_rune_case(_gen_angle(Vector2(0.42, 0.36), Vector2(0.60, 0.50), Vector2(0.44, 0.66)),
		Enums.RuneType.IMPACT, "충격> 기본")
	_rune_case(_gen_angle(Vector2(0.40, 0.40), Vector2(0.62, 0.52), Vector2(0.42, 0.60)),
		Enums.RuneType.IMPACT, "충격> 벌림각 변형")
	_rune_case(_gen_angle(Vector2(0.55, 0.35), Vector2(0.45, 0.55), Vector2(0.60, 0.68)),
		Enums.RuneType.IMPACT, "충격> 방향 반전(<형)")
	for i in 3:
		_rune_case(_gen_angle(Vector2(0.42, 0.36), Vector2(0.61, 0.50), Vector2(0.43, 0.65), 0.005),
			Enums.RuneType.IMPACT, "충격> 노이즈 %d" % i)

	# 물~ — 깨끗한 획 3 + 노이즈 획 3
	_rune_case(_gen_wave(Vector2(0.30, 0.50), 0.40, 0.07, 2.0),
		Enums.RuneType.WATER, "물~ 2주기")
	_rune_case(_gen_wave(Vector2(0.32, 0.48), 0.36, 0.09, 1.5, PI / 3.0),
		Enums.RuneType.WATER, "물~ 1.5주기+위상")
	var rev_wave := _gen_wave(Vector2(0.30, 0.52), 0.42, 0.06, 2.5, 0.0, 0.0, true)
	rev_wave.reverse()
	_rune_case(rev_wave, Enums.RuneType.WATER, "물~ 역방향+반전")
	for i in 3:
		_rune_case(_gen_wave(Vector2(0.30, 0.50), 0.40, 0.08, 2.0, 0.3 * float(i), 0.004),
			Enums.RuneType.WATER, "물~ 노이즈 %d" % i)

	# 바람◎ — 깨끗한 획 3 + 노이즈 획 3
	_rune_case(_gen_spiral(c, 0.16, 2.5), Enums.RuneType.WIND, "바람◎ 2.5바퀴")
	_rune_case(_gen_spiral(c, 0.14, 2.0, 0.8, 1.0), Enums.RuneType.WIND, "바람◎ 2바퀴+회전")
	_rune_case(_gen_spiral(c, 0.17, 3.0, 0.7, 0.0, 0.0, true), Enums.RuneType.WIND, "바람◎ 안쪽으로")
	for i in 3:
		_rune_case(_gen_spiral(c, 0.15, 2.5, 0.75, 0.5 * float(i), 0.003),
			Enums.RuneType.WIND, "바람◎ 노이즈 %d" % i)


# ─────────────────────────── 4. 화살표 파라미터 추출 ───────────────────────────

func _test_arrows() -> void:
	var ctx := {
		"has_circle": true,
		"circle_center": Vector2(0.5, 0.5),
		"circle_radius": 0.3,
		"has_tail": true,
		"has_rune": true,
	}
	var dirs: Array[float] = [0.0, PI / 2.0, PI, -PI / 2.0]
	var lens: Array[float] = [0.1, 0.2, 0.4]
	for d: float in dirs:
		var prev_len := 0.0
		for l: float in lens:
			var a := Vector2(0.5, 0.5)
			var b := a + Vector2(cos(d), sin(d)) * l
			var r := Recognizer.classify_stroke(_gen_line(a, b, 10, 0.0008), ctx)
			var tag := "화살표 dir=%.2f len=%.2f" % [d, l]
			_check(int(r.role) == Enums.StrokeRole.ARROW, tag + " → ARROW")
			if int(r.role) == Enums.StrokeRole.ARROW:
				_check(absf(wrapf(float(r.direction) - d, -PI, PI)) < 0.12, tag + " 방향 오차")
				_check(float(r.length) > prev_len, tag + " 길이 증가")
				prev_len = float(r.length)


# ─────────────────────────── 5. 도안 조립 (조준진) ───────────────────────────

func _run_pipeline(point_sets: Array) -> Dictionary:
	var entries: Array[Dictionary] = []
	for pts: PackedVector2Array in point_sets:
		var s := StrokeData.new()
		s.points = pts
		entries.append({"stroke": s, "locked": false, "result": {}})
	return DesignBuilder.classify_entries(entries)


func _test_assembly_aimed() -> void:
	var c := Vector2(0.5, 0.5)
	var sets: Array = [
		_gen_circle(c, 0.22),
		_gen_line(Vector2(0.73, 0.5), Vector2(0.86, 0.5)),
		_gen_triangle(c, 0.10),
		_gen_line(c, c + Vector2(0.18, 0.0), 10),
		_gen_line(c, c + Vector2(cos(0.5), sin(0.5)) * 0.18, 10),
		_gen_line(c, c + Vector2(cos(-0.5), sin(-0.5)) * 0.18, 10),
	]
	var parts := _run_pipeline(sets)
	_check(DesignBuilder.is_complete(parts), "조준진 도안 완성 조건")
	if not DesignBuilder.is_complete(parts):
		return
	var balance := load("res://data/balance.tres") as BalanceData
	var d := DesignBuilder.build(parts, balance)
	_check(d.circle_type == Enums.CircleType.AIMED, "circle_type == AIMED")
	_check(absf(d.aim_axis) < 0.12, "aim_axis ≈ 0")
	_check(d.rune_type == Enums.RuneType.FIRE, "룬 타입 == FIRE")
	_check(d.rune_accuracy >= balance.accuracy_floor and d.rune_accuracy <= 1.0,
		"rune_accuracy ∈ [하한, 1]")
	_check(d.arrows.size() == 3, "화살표 3개")
	if d.arrows.size() == 3:
		_check(absf(wrapf(d.arrows[0].direction, -PI, PI)) < 0.15, "화살표0 상대각 ≈ 0")
		_check(absf(wrapf(d.arrows[1].direction - 0.5, -PI, PI)) < 0.15, "화살표1 상대각 ≈ 0.5")
		for a: ArrowData in d.arrows:
			_check(a.magnitude > 0.0, "magnitude > 0")
			_check(a.origin.length() < 0.05, "origin ≈ 진 중심")
	_check(int(d.ink_cost.get(&"ink_basic", 0)) > 0, "ink_cost > 0")
	_check(d.mana_cost > 0.0, "mana_cost > 0")
	_check(d.strokes.size() == 6, "원본 획 6개 보존")
	var roles := {}
	for s: StrokeData in d.strokes:
		roles[int(s.role)] = int(roles.get(int(s.role), 0)) + 1
	_check(int(roles.get(Enums.StrokeRole.CIRCLE, 0)) == 1, "CIRCLE 획 1")
	_check(int(roles.get(Enums.StrokeRole.TAIL, 0)) == 1, "TAIL 획 1")
	_check(int(roles.get(Enums.StrokeRole.RUNE, 0)) == 1, "RUNE 획 1")
	_check(int(roles.get(Enums.StrokeRole.ARROW, 0)) == 3, "ARROW 획 3")

	# 조준진 상대각: 위쪽 꼬리(aim=-π/2)면 위로 그린 화살표의 상대각 ≈ 0
	var sets2: Array = [
		_gen_circle(c, 0.22),
		_gen_line(Vector2(0.5, 0.29), Vector2(0.5, 0.16)),
		_gen_triangle(c, 0.10),
		_gen_line(c, c + Vector2(0.0, -0.2), 10),
	]
	var parts2 := _run_pipeline(sets2)
	if DesignBuilder.is_complete(parts2):
		var d2 := DesignBuilder.build(parts2, balance)
		_check(absf(wrapf(d2.arrows[0].direction, -PI, PI)) < 0.15,
			"위 꼬리 + 위 화살표 → 상대각 ≈ 0")
	else:
		_check(false, "조준진(위 꼬리) 도안 완성 조건")


# ─────────────────────────── 6. 도안 조립 (고정진 노바) ───────────────────────────

func _test_assembly_fixed() -> void:
	var c := Vector2(0.5, 0.5)
	var sets: Array = [_gen_circle(c, 0.26)]
	sets.append(_gen_spiral(c, 0.10, 2.5))
	var dirs: Array[float] = []
	for k in 8:
		var d := TAU * float(k) / 8.0
		dirs.append(d)
		sets.append(_gen_line(c, c + Vector2(cos(d), sin(d)) * 0.16, 10))
	var parts := _run_pipeline(sets)
	_check(DesignBuilder.is_complete(parts), "고정진 노바 완성 조건")
	if not DesignBuilder.is_complete(parts):
		return
	var balance := load("res://data/balance.tres") as BalanceData
	var d := DesignBuilder.build(parts, balance)
	_check(d.circle_type == Enums.CircleType.FIXED, "circle_type == FIXED")
	_check(d.rune_type == Enums.RuneType.WIND, "룬 타입 == WIND")
	_check(d.arrows.size() == 8, "노바 화살표 8개")
	if d.arrows.size() == 8:
		for k in 8:
			_check(absf(wrapf(d.arrows[k].direction - dirs[k], -PI, PI)) < 0.12,
				"노바 화살표 %d 절대각" % k)


# ─────────────────────────── 7. 빌더 경계값 ───────────────────────────

func _test_builder_edges() -> void:
	var balance := load("res://data/balance.tres") as BalanceData
	var c := Vector2(0.5, 0.5)
	# 정확도 하한: 원시 점수 0.3 → accuracy_floor로 보정
	var circle_stroke := StrokeData.new()
	circle_stroke.points = _gen_circle(c, 0.2)
	var rune_stroke := StrokeData.new()
	rune_stroke.points = _gen_triangle(c, 0.1)
	var arrow_stroke := StrokeData.new()
	arrow_stroke.points = _gen_line(c, c + Vector2(0.9, 0.0), 10)
	var arrow_stroke2 := StrokeData.new()
	arrow_stroke2.points = _gen_line(c + Vector2(0.1, 0.0), c + Vector2(0.3, 0.0), 10)
	var parts := {
		"circle": {"center": c, "radius": 0.2, "stroke": circle_stroke},
		"rune": {"type": Enums.RuneType.WATER, "accuracy_raw": 0.3, "stroke": rune_stroke},
		"arrows": [
			{"direction": 0.0, "length": 0.9, "start": c, "stroke": arrow_stroke},
			{"direction": 0.0, "length": 0.2, "start": c + Vector2(0.1, 0.0), "stroke": arrow_stroke2},
		],
		"extras": [],
		"strokes_ordered": [circle_stroke, rune_stroke, arrow_stroke, arrow_stroke2],
	}
	var d := DesignBuilder.build(parts, balance)
	_check(is_equal_approx(d.rune_accuracy, balance.accuracy_floor), "정확도 하한 보정")
	_check(is_equal_approx(d.arrows[0].magnitude, 1.0), "초과 길이 → magnitude 1.0 클램프")
	# origin은 진 반지름=1.0 정규화 (TECH_SPEC §4): 시작점 0.1, 반지름 0.2 → (0.5, 0)
	_check(d.arrows[1].origin.distance_to(Vector2(0.5, 0.0)) < 0.01, "origin 반지름 정규화")
	# 마나 = 룬 기본 + 발수 (BalanceData 계수)
	var expected_mana: float = balance.rune_mana_base[Enums.RuneType.WATER] \
		+ balance.mana_per_arrow * 2.0
	_check(is_equal_approx(d.mana_cost, expected_mana), "마나 = 룬 기본 + 발수")

	# 조준진 잉크 가산: 같은 부품에 꼬리만 추가하면 잉크 증가
	var ink_fixed := int(d.ink_cost.get(&"ink_basic", 0))
	var tail_stroke := StrokeData.new()
	tail_stroke.points = _gen_line(Vector2(0.71, 0.5), Vector2(0.8, 0.5))
	parts["tail"] = {"aim_axis": 0.0, "stroke": tail_stroke}
	var d2 := DesignBuilder.build(parts, balance)
	_check(int(d2.ink_cost.get(&"ink_basic", 0)) > ink_fixed, "조준진 잉크 가산")
