extends SceneTree
## 모듈 A 자동 검증 — 합성 획 데이터로 인식 파이프라인·SpellDesign 조립을 검사한다.
## 실행: Godot --headless --path . -s res://tests/test_drawing_auto.gd
## 통과 조건: FAIL 0건, 특히 물~/바람◎ 교차 오인식 0건 (GDD 리스크 1).

const Recognizer := preload("res://src/drawing/recognizer.gd")
const DesignBuilder := preload("res://src/drawing/design_builder.gd")
const DrawingCanvas := preload("res://src/drawing/drawing_canvas.gd")
const DesignChecklist := preload("res://src/drawing/design_checklist.gd")
const DesignBook := preload("res://src/drawing/design_book.gd")
const RuneTemplates := preload("res://src/drawing/rune_templates.gd")
const Copy := preload("res://src/drawing/drawing_copy.gd")

var _pass := 0
var _fail := 0
var _water_wind_cross := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20260712
	_test_circles()
	_test_no_tails()
	_test_runes()
	_test_rune_stress()
	_test_arrows()
	_test_curved_arrows()
	_test_arrow_path()
	_test_arrow_pressures()
	_test_synth_pressure_math()
	_test_assembly_aimed()
	_test_assembly_fixed()
	_test_builder_edges()
	_test_nested_tree()
	_run_tree_tests()


## 실제 캔버스 노드를 구동하는 테스트는 **트리가 활성화된 뒤**에 돌려야 한다 —
## _init 시점엔 씬 트리가 아직 안 살아 있어 _ready도 안 돌고 get_node(절대경로)도 실패한다.
func _run_tree_tests() -> void:
	await process_frame
	_test_synth_pressure_canvas()
	_test_draw_order()
	_test_nested_canvas()
	await _test_orientation_guide()
	await _test_copy_and_feedback()
	await _test_design_book()
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


## 활처럼 휜 획 — 2차 베지에. bow = 현(a→b)에서 수직으로 부푸는 양(부호 = 휜 방향)
func _gen_arc(a: Vector2, b: Vector2, bow: float, n := 24, noise := 0.0) -> PackedVector2Array:
	var ctrl := a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * bow * 2.0
	var pts := PackedVector2Array()
	for i in n:
		var t := float(i) / float(n - 1)
		var u := 1.0 - t
		pts.append(a * (u * u) + ctrl * (2.0 * u * t) + b * (t * t))
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


# ────────── 2. 조준 꼬리 폐지 (v1.6) — 꼬리 모양 획은 이제 화살표 ──────────
# 진은 한 종류뿐이고 캔버스 위쪽이 곧 조준 방향이다. 인식기는 TAIL을 생산하지 않는다.
# 예전에 꼬리로 잡히던 "진 경계에서 밖으로 나가는 짧은 획"은 이제 탈출 판정에 걸려 화살표가 된다.

func _test_no_tails() -> void:
	var ctx := {
		"has_circle": true,
		"circle_center": Vector2(0.5, 0.5),
		"circle_radius": 0.22,
	}
	# 예전 꼬리 샘플들 — 전부 ARROW여야 하고, TAIL은 어디에서도 나오지 않는다
	var r := Recognizer.classify_stroke(_gen_line(Vector2(0.73, 0.5), Vector2(0.86, 0.5)), ctx)
	_check(int(r.role) == Enums.StrokeRole.ARROW, "예전 오른쪽 꼬리 → 이제 ARROW")

	r = Recognizer.classify_stroke(_gen_line(Vector2(0.5, 0.29), Vector2(0.5, 0.16)), ctx)
	_check(int(r.role) == Enums.StrokeRole.ARROW, "예전 위쪽 꼬리 → 이제 ARROW")

	r = Recognizer.classify_stroke(_gen_line(Vector2(0.5, 0.5), Vector2(0.85, 0.5)), ctx)
	_check(int(r.role) == Enums.StrokeRole.ARROW, "중심 발 긴 직선 → ARROW")

	# 인식기는 어떤 컨텍스트에서도 TAIL을 반환하지 않는다
	var no_tail := true
	for pts: PackedVector2Array in [
			_gen_line(Vector2(0.73, 0.5), Vector2(0.86, 0.5)),
			_gen_line(Vector2(0.5, 0.29), Vector2(0.5, 0.16)),
			_gen_circle(Vector2(0.5, 0.5), 0.2),
			_gen_triangle(Vector2(0.5, 0.5), 0.12),
			_gen_wave(Vector2(0.32, 0.50), 0.36, 0.08, 2.0)]:
		for c: Dictionary in [{}, ctx]:
			if int(Recognizer.classify_stroke(pts, c).role) == Enums.StrokeRole.TAIL:
				no_tail = false
	_check(no_tail, "인식기가 TAIL을 생산하지 않는다 (꼬리 폐지)")


# ─────────────────────────── 3. 룬 4종 ($1 + 감김 게이트) ───────────────────────────

func _rune_case(pts: PackedVector2Array, expected: int, name: String) -> void:
	_rune_case_r(pts, expected, name, 0.35)


func _rune_case_r(pts: PackedVector2Array, expected: int, name: String, radius: float) -> void:
	# 실전과 같은 컨텍스트: 진은 이미 있고 룬은 아직 없음
	var ctx := {
		"has_circle": true,
		"circle_center": Vector2(0.5, 0.5),
		"circle_radius": radius,
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


# ────────── 3.5 룬 스트레스 — 손그림 변형 (크기·회전·노이즈 무작위) ──────────
# **이 테스트가 없어서 불△ 버그를 놓쳤다.** 기존 룬 테스트는 깨끗한 합성 도형만 썼는데,
# 작고 지터가 있는 삼각형은 감김이 0.5바퀴 아래로 내려가 옛 감김 게이트에 불△가
# 후보에서 통째로 빠졌고 → 물~/충격> 템플릿에만 매칭돼 0.4점 → DECOR로 떨어졌다.
# 사람이 실제로 그리는 범위를 무작위로 쓸어 인식률을 고정한다.

func _test_rune_stress() -> void:
	var ctx := {
		"has_circle": true, "circle_center": Vector2(0.5, 0.5), "circle_radius": 0.25,
	}
	var miss := {}
	var n := 40
	for i in n:
		var cases := {
			Enums.RuneType.FIRE: _gen_triangle(Vector2(0.5, 0.5),
				_rng.randf_range(0.07, 0.22), _rng.randf_range(0.0, TAU),
				_rng.randf_range(0.002, 0.012)),
			Enums.RuneType.IMPACT: _gen_angle(
				Vector2(0.5, 0.5) + Vector2(-_rng.randf_range(0.08, 0.18),
					-_rng.randf_range(0.08, 0.18)),
				Vector2(0.5, 0.5) + Vector2(_rng.randf_range(0.06, 0.14), 0.0),
				Vector2(0.5, 0.5) + Vector2(-_rng.randf_range(0.08, 0.18),
					_rng.randf_range(0.08, 0.18)),
				_rng.randf_range(0.002, 0.010)),
			Enums.RuneType.WATER: _gen_wave(Vector2(0.30, 0.50),
				_rng.randf_range(0.24, 0.40), _rng.randf_range(0.05, 0.10),
				_rng.randf_range(1.4, 2.6), _rng.randf_range(0.0, PI),
				_rng.randf_range(0.002, 0.008)),
			Enums.RuneType.WIND: _gen_spiral(Vector2(0.5, 0.5),
				_rng.randf_range(0.09, 0.20), _rng.randf_range(2.0, 3.0),
				_rng.randf_range(0.6, 0.85), _rng.randf_range(0.0, TAU),
				_rng.randf_range(0.002, 0.008)),
		}
		for want: int in cases:
			var r := Recognizer.classify_stroke(cases[want], ctx)
			var got := int(r.get("rune_type", -1)) if int(r.role) == Enums.StrokeRole.RUNE else -1
			if got != want:
				miss[want] = int(miss.get(want, 0)) + 1
			if want == Enums.RuneType.WATER and got == Enums.RuneType.WIND:
				_water_wind_cross += 1
			if want == Enums.RuneType.WIND and got == Enums.RuneType.WATER:
				_water_wind_cross += 1

	for want: int in [Enums.RuneType.FIRE, Enums.RuneType.IMPACT,
			Enums.RuneType.WATER, Enums.RuneType.WIND]:
		var bad := int(miss.get(want, 0))
		_check(bad == 0, "손그림 스트레스 %s — %d/%d 실패" % [
			DesignBuilder.rune_name(want), bad, n])


# ─────────────────────────── 4. 화살표 파라미터 추출 ───────────────────────────

func _test_arrows() -> void:
	var ctx := {
		"has_circle": true,
		"circle_center": Vector2(0.5, 0.5),
		"circle_radius": 0.3,
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


# ────────────── 4.5 곡선 화살표 (탈출 판정, TECH_SPEC §6.1) ──────────────
# 구별자는 직진성이 아니라 기하 위치: 룬은 진 안에 머무르고 화살표는 진을 뚫고 나간다.
# 룬이 아직 없는 컨텍스트로 검사한다 — 곡선 획이 룬으로 새지 않아야 진짜 통과다.

func _curved_arrow_case(pts: PackedVector2Array, radius: float, name: String) -> void:
	var ctx := {
		"has_circle": true,
		"circle_center": Vector2(0.5, 0.5),
		"circle_radius": radius,
	}
	var r := Recognizer.classify_stroke(pts, ctx)
	var st := Recognizer.straightness(pts)
	_check(int(r.role) == Enums.StrokeRole.ARROW,
		"%s → ARROW (got role=%s, straightness=%.2f)" % [name, str(r.role), st])
	# 직진성 폴백이 아니라 탈출 판정이 잡은 것이어야 의미가 있다
	_check(st < Recognizer.ARROW_STRAIGHT_FALLBACK,
		"%s 은(는) 직진성 폴백으로는 못 잡는 곡률 (straightness=%.2f)" % [name, st])


func _test_curved_arrows() -> void:
	var c := Vector2(0.5, 0.5)
	_curved_arrow_case(_gen_arc(c, c + Vector2(0.34, 0.0), 0.13), 0.28, "곡선 화살표 오른쪽·위로 휨")
	_curved_arrow_case(_gen_arc(c, c + Vector2(0.34, 0.0), -0.13), 0.28, "곡선 화살표 오른쪽·아래로 휨")
	_curved_arrow_case(
		_gen_arc(c, c + Vector2(cos(2.2), sin(2.2)) * 0.36, 0.14, 24, 0.002),
		0.28, "곡선 화살표 비스듬·노이즈")
	# 진 가장자리에서 출발해 크게 휘어 나가는 획도 화살표
	_curved_arrow_case(
		_gen_arc(Vector2(0.5, 0.28), Vector2(0.86, 0.62), 0.20), 0.24, "곡선 화살표 가장자리 발")

	# 회귀: 진 안에 그린 곡선 룬은 여전히 룬 — 탈출 판정이 물~·바람◎을 먹으면 안 된다
	_rune_case_r(_gen_wave(Vector2(0.32, 0.50), 0.36, 0.08, 2.0), Enums.RuneType.WATER,
		"물~ 진(0.28) 안", 0.28)
	_rune_case_r(_gen_wave(Vector2(0.36, 0.50), 0.28, 0.06, 2.0, PI / 3.0), Enums.RuneType.WATER,
		"물~ 진(0.22) 안", 0.22)
	_rune_case_r(_gen_spiral(c, 0.15, 2.5), Enums.RuneType.WIND, "바람◎ 진(0.28) 안", 0.28)
	_rune_case_r(_gen_spiral(c, 0.12, 2.0, 0.8, 1.0), Enums.RuneType.WIND,
		"바람◎ 진(0.22) 안", 0.22)
	_rune_case_r(_gen_triangle(c, 0.12), Enums.RuneType.FIRE, "불△ 진(0.22) 안", 0.22)
	_rune_case_r(_gen_angle(Vector2(0.42, 0.36), Vector2(0.60, 0.50), Vector2(0.44, 0.66)),
		Enums.RuneType.IMPACT, "충격> 진(0.28) 안", 0.28)


# ────────────── 4.6 ArrowData.path — 곡률 보존 (TECH_SPEC §4) ──────────────
# 좌표계: 획 시작점 = 원점, +X = direction(시작→끝 벡터). 단위는 캔버스 단위.

func _test_arrow_path() -> void:
	var balance := load("res://data/balance.tres") as BalanceData
	var c := Vector2(0.5, 0.5)
	var curved := _gen_arc(c, c + Vector2(0.34, 0.0), 0.13)
	var straight := _gen_line(c, c + Vector2(cos(2.0), sin(2.0)) * 0.30, 12, 0.0008)
	var parts := _run_pipeline([_gen_circle(c, 0.24), _gen_triangle(c, 0.10), curved, straight])
	_check(DesignBuilder.is_complete(parts), "곡선 화살표 도안 완성 조건")
	if not DesignBuilder.is_complete(parts):
		return
	var d := DesignBuilder.build(parts, balance)
	_check(d.arrows.size() == 2, "화살표 2개 (곡선 + 직선)")
	if d.arrows.size() != 2:
		return

	for i in 2:
		var p: PackedVector2Array = d.arrows[i].path
		var tag := "path[%d]" % i
		_check(p.size() == DesignBuilder.ARROW_PATH_POINTS,
			"%s 리샘플 %d점 (got %d)" % [tag, DesignBuilder.ARROW_PATH_POINTS, p.size()])
		if p.size() < 2:
			continue
		var last: Vector2 = p[p.size() - 1]
		_check(p[0].length() < 0.01, "%s 첫 점 ≈ 원점 (got %s)" % [tag, str(p[0])])
		_check(absf(last.y) < 0.02, "%s 끝 점 y ≈ 0 (got %.3f)" % [tag, last.y])
		_check(last.x > 0.0, "%s 끝 점 x > 0 — +X가 발사 방향 (got %.3f)" % [tag, last.x])

	# 곡선 화살표의 path는 실제로 휘어 있다 / 직선 화살표의 path는 평평하다
	var bow_curved := _max_abs_y(d.arrows[0].path)
	var bow_straight := _max_abs_y(d.arrows[1].path)
	_check(bow_curved > 0.05, "곡선 화살표 path가 휘어 있다 (max|y|=%.3f)" % bow_curved)
	_check(bow_straight < 0.02, "직선 화살표 path는 평평하다 (max|y|=%.3f)" % bow_straight)
	# 그린 획의 사가타(≈0.13)가 보존됐는가 — 스케일이 캔버스 단위 그대로여야 한다
	_check(absf(bow_curved - 0.13) < 0.03,
		"곡선 화살표 곡률 크기 보존 (그린 사가타 0.13 vs path %.3f)" % bow_curved)

	# 빈 획(샘플 도안·구세이브) → 빈 path (직선 폴백 계약)
	var empty := StrokeData.new()
	var stub := {
		"circle": {"center": c, "radius": 0.2, "stroke": empty},
		"rune": {"type": Enums.RuneType.FIRE, "accuracy_raw": 0.8, "stroke": empty},
		"arrows": [{"direction": 0.0, "length": 0.2, "start": c, "stroke": empty}],
		"extras": [], "strokes_ordered": [empty],
	}
	var d2 := DesignBuilder.build(stub, balance)
	_check(d2.arrows[0].path.is_empty(), "점 없는 획 → 빈 path (직선 폴백)")


func _max_abs_y(pts: PackedVector2Array) -> float:
	var m := 0.0
	for p: Vector2 in pts:
		m = maxf(m, absf(p.y))
	return m


# ────────── 4.7 ArrowData.path_pressures — 붓맛이 탄에도 실린다 ──────────
# 진(strokes)에만 필압이 살고 투사체(path)는 균일 굵기면 붓맛이 한쪽에만 남는다.
# path_pressures는 path와 **같은 리샘플 인덱스**를 써야 굵기가 획과 어긋나지 않는다.

## 붓을 눌렀다 떼는 필압 — 가운데가 가장 굵다
func _gen_pressures(n: int, lo: float, hi: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in n:
		out.append(lerpf(lo, hi, sin(float(i) / float(n - 1) * PI)))
	return out


func _test_arrow_pressures() -> void:
	var balance := load("res://data/balance.tres") as BalanceData
	var c := Vector2(0.5, 0.5)
	var curved := _gen_arc(c, c + Vector2(0.34, 0.0), 0.13)
	var straight := _gen_line(c, c + Vector2(cos(2.0), sin(2.0)) * 0.30, 12, 0.0008)
	# 곡선 화살표에만 필압을 싣는다(태블릿). 직선 쪽은 필압 배열이 빈 획 —
	# 자동보정·스탬프·샘플 도안이 그렇다 (마우스는 캔버스가 1.0으로 채우므로 비지 않는다)
	var press := _gen_pressures(curved.size(), 0.25, 1.0)
	var parts := _run_pipeline(
		[_gen_circle(c, 0.24), _gen_triangle(c, 0.10), curved, straight],
		[PackedFloat32Array(), PackedFloat32Array(), press, PackedFloat32Array()])
	_check(DesignBuilder.is_complete(parts), "필압 도안 완성 조건")
	if not DesignBuilder.is_complete(parts):
		return
	var d := DesignBuilder.build(parts, balance)
	_check(d.arrows.size() == 2, "필압 도안 화살표 2개")
	if d.arrows.size() != 2:
		return

	var pen: ArrowData = d.arrows[0]
	var mouse: ArrowData = d.arrows[1]
	_check(pen.path_pressures.size() == pen.path.size(),
		"path_pressures 길이 == path 길이 (%d vs %d)" % [
			pen.path_pressures.size(), pen.path.size()])
	_check(pen.path_pressures.size() == DesignBuilder.ARROW_PATH_POINTS,
		"path_pressures %d점" % DesignBuilder.ARROW_PATH_POINTS)
	# 필압 없는 획 → 빈 배열 (make_line이 균일 굵기로 폴백하는 계약)
	_check(mouse.path_pressures.is_empty(), "필압 없는 획 → 빈 path_pressures")

	# 눌렀다 뗀 굵기 변화가 실제로 살아있다 — 상수 배열로 뭉개지면 안 된다
	var lo := INF
	var hi := -INF
	for p: float in pen.path_pressures:
		lo = minf(lo, p)
		hi = maxf(hi, p)
	_check(hi - lo > 0.3, "필압 변화 보존 (min=%.2f max=%.2f)" % [lo, hi])
	_check(lo >= 0.0 and hi <= 1.0, "필압 값 ∈ [0, 1]")
	# 가운데가 가장 굵다 — 리샘플이 획의 필압 프로파일 순서를 뒤집지 않았다
	var mid: float = pen.path_pressures[pen.path_pressures.size() / 2]
	_check(mid > pen.path_pressures[0] and mid > pen.path_pressures[pen.path_pressures.size() - 1],
		"필압 프로파일 순서 보존 (가운데가 양 끝보다 굵다)")

	# 저장·로드 왕복 — SaveManager와 같은 메커니즘(ResourceSaver로 SpellDesign 통째 저장)
	var tmp := "user://test_drawing_arrow_roundtrip.tres"
	_check(ResourceSaver.save(d, tmp) == OK, "도안 저장")
	var back := ResourceLoader.load(tmp, "", ResourceLoader.CACHE_MODE_IGNORE) as SpellDesign
	_check(back != null, "도안 로드")
	if back != null and back.arrows.size() == 2:
		var rp: ArrowData = back.arrows[0]
		_check(rp.path.size() == pen.path.size(), "왕복 후 path 길이 보존")
		_check(rp.path_pressures.size() == pen.path_pressures.size(),
			"왕복 후 path_pressures 길이 보존")
		var path_ok := true
		for i in rp.path.size():
			if rp.path[i].distance_to(pen.path[i]) > 1e-4:
				path_ok = false
		var press_ok := true
		for i in rp.path_pressures.size():
			if absf(rp.path_pressures[i] - pen.path_pressures[i]) > 1e-4:
				press_ok = false
		_check(path_ok, "왕복 후 path 값 보존")
		_check(press_ok, "왕복 후 path_pressures 값 보존")
		_check(back.arrows[1].path_pressures.is_empty(), "왕복 후 빈 path_pressures 유지")
	else:
		_check(false, "왕복 후 화살표 2개")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))


# ────────── 4.8 마우스 필압 합성 (누적형) — 순수 계산 ──────────
# 마우스엔 필압이 없다. "한 자리에 오래 머물수록 그 지점이 굵어진다"를 시간으로 만든다.

## 제자리(또는 주어진 속도)에서 sec초 동안 필압을 굴린다 — 60fps 스텝
func _synth_hold(start: float, speed: float, sec: float) -> float:
	var p := start
	var steps := int(round(sec * 60.0))
	for _i in steps:
		p = DrawingCanvas.synth_pressure_step(p, speed, 1.0 / 60.0)
	return p


func _test_synth_pressure_math() -> void:
	# 머물면 굵어진다 — 0.5초면 눈에 띄게 (사용자가 원한 핵심 감각)
	var held := _synth_hold(1.0, 0.0, 0.5)
	_check(held > 1.3, "0.5초 머물면 굵어진다 (1.0 → %.2f)" % held)
	_check(held < DrawingCanvas.SYNTH_P_MAX, "머문 필압 < 상한 %.2f" % DrawingCanvas.SYNTH_P_MAX)
	var held_long := _synth_hold(1.0, 0.0, 5.0)
	_check(held_long <= DrawingCanvas.SYNTH_P_MAX + 1e-3,
		"오래 머물러도 상한을 넘지 않는다 (%.2f)" % held_long)
	_check(held_long > held, "더 오래 머물수록 더 굵다")

	# 빠르게 그으면 얇아진다
	var fast := _synth_hold(1.0, DrawingCanvas.SYNTH_SPEED_REF, 0.5)
	_check(fast < 0.6, "빠르게 그으면 얇다 (1.0 → %.2f)" % fast)
	_check(fast >= DrawingCanvas.SYNTH_P_MIN - 1e-3, "얇아져도 하한 %.2f 이상" % DrawingCanvas.SYNTH_P_MIN)

	# 보통 속도(≈330px/s)로 그으면 1.0 근처 — 상수 1.0이던 기존 감각이 기본값
	var normal := _synth_hold(1.0, 330.0, 1.0)
	_check(absf(normal - 1.0) < 0.15, "보통 속도 → 필압 ≈ 1.0 (%.2f)" % normal)

	# 단조성: 느릴수록 굵다
	var prev := 99.0
	for speed: float in [0.0, 200.0, 400.0, 600.0, 800.0]:
		var p := _synth_hold(1.0, speed, 1.0)
		_check(p < prev, "속도 %.0f px/s → 더 얇다 (%.2f)" % [speed, p])
		prev = p


# ────────── 4.9 잉크 중립 + 캔버스 실경로 (마우스 vs 태블릿) ──────────

func _mean(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v: float in a:
		s += v
	return s / float(a.size())


## 캔버스 픽셀 좌표 획들 — 300×300 캔버스 기준 (정규화하면 캔버스 단위 = /300)
const CV := 300.0
const CV_C := Vector2(150, 150)


func _px_circle(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		var a := -PI / 2.0 + TAU * 0.98 * float(i) / 47.0
		pts.append(CV_C + Vector2(cos(a), sin(a)) * r)
	return pts


func _px_line(a: Vector2, b: Vector2, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(a.lerp(b, float(i) / float(n - 1)))
	return pts


## 반 바퀴 호 — 진 안에 머무는 **굽은** 획. 원이 아니고(0.5바퀴 < CIRCLE_NET_MIN) 직진성도 낮아
## ARROW 단계에서 DECOR로 떨어진다. (예전엔 _px_circle이 이 역할이었으나 이제 원은 새 노드로 수락됨)
func _px_arc(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := -PI / 2.0 + PI * float(i) / 23.0
		pts.append(CV_C + Vector2(cos(a), sin(a)) * r)
	return pts


func _px_tri_at(c: Vector2, size: float) -> PackedVector2Array:
	var verts: Array[Vector2] = []
	for k in 3:
		var a := -PI / 2.0 + TAU * float(k) / 3.0
		verts.append(c + Vector2(cos(a), sin(a)) * size)
	var pts := PackedVector2Array()
	for e in 3:
		for i in 14:
			pts.append(verts[e].lerp(verts[(e + 1) % 3], float(i) / 14.0))
	pts.append(verts[0])
	return pts


func _px_triangle(size: float) -> PackedVector2Array:
	var verts: Array[Vector2] = []
	for k in 3:
		var a := -PI / 2.0 + TAU * float(k) / 3.0
		verts.append(CV_C + Vector2(cos(a), sin(a)) * size)
	var pts := PackedVector2Array()
	for e in 3:
		for i in 14:
			pts.append(verts[e].lerp(verts[(e + 1) % 3], float(i) / 14.0))
	pts.append(verts[0])
	return pts


func _new_canvas() -> Node:
	var canvas := DrawingCanvas.new()
	canvas.size = Vector2(CV, CV)
	root.add_child(canvas)
	return canvas


## 픽셀 점열을 실제 입력 이벤트(다운 → 모션 → 업)로 캔버스에 먹인다.
## hold_frames: 다운 직후 **모션 없이** 시간만 흐르는 프레임 수 (= 멈춘 마우스. 진짜로
## InputEventMouseMotion이 안 오는 상황이라, _process가 없으면 아무 일도 일어나지 않는다)
## tablet_pressure: > 0이면 태블릿 필압으로 모션을 보낸다
func _stroke_on(canvas: Node, pts: PackedVector2Array, hold_frames := 0,
		tablet_pressure := 0.0) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pts[0]
	canvas._gui_input(down)

	for _i in hold_frames:
		canvas._process(1.0 / 60.0)   # 제자리 — 모션 이벤트 없음

	var prev: Vector2 = pts[0]
	for i in range(1, pts.size()):
		var mm := InputEventMouseMotion.new()
		mm.relative = pts[i] - prev
		mm.position = pts[i]
		mm.pressure = tablet_pressure
		canvas._gui_input(mm)
		canvas._process(1.0 / 60.0)
		prev = pts[i]

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = prev
	canvas._gui_input(up)


## 필압 검사용 — **진(원)을 그린다.** 첫 획은 진이어야 하므로(TECH_SPEC §6.2 작성 순서)
## 직선으로는 획이 아예 받아들여지지 않는다. 시작점에서 머문 뒤 원을 그린다.
func _drive_canvas(hold_frames: int, tablet_pressure: float) -> Node:
	var canvas := _new_canvas()
	_stroke_on(canvas, _px_circle(60.0), hold_frames, tablet_pressure)
	return canvas


func _test_synth_pressure_canvas() -> void:
	var balance := load("res://data/balance.tres") as BalanceData

	# ── 마우스: 0.5초 머물다가 긋기 ──
	var canvas := _drive_canvas(30, 0.0)
	_check(canvas._entries.size() == 1, "마우스 획 1개 확정")
	if canvas._entries.size() != 1:
		canvas.queue_free()
		return
	var stroke: StrokeData = canvas._entries[0].stroke
	_check(stroke.pressures.size() == stroke.points.size(), "필압 개수 == 점 개수")

	# 합성 필압은 평균 1.0으로 정규화된다 — **계통적 잉크 인플레를 막는 장치** (세션 7)
	var mean := _mean(stroke.pressures)
	_check(absf(mean - 1.0) < 1e-3, "합성 필압 평균 == 1.0 (got %.5f)" % mean)

	# ⚠ v1.8: **"필압은 잉크에 중립"은 더 이상 목표가 아니다.**
	# 잉크는 **통에서 나온 양**이고(GDD §4.4), 꾹 눌러 굵게 그으면 실제로 더 쓴다.
	# v1.7까지의 "상수 1.0과 정확히 동일" 보장은 **평균으로 뭉갠 데서 나온 착시**였다 —
	# 구간별로 적분하면 **어디서 눌렀는지**가 반영되므로 정확히 같을 수 없다.
	# 여기서 지킬 것은 '동일'이 아니라 **'계통적으로 부풀지 않는다'**이다 (평균 1.0 정규화의 목적).
	var flat := StrokeData.new()
	flat.points = stroke.points
	var ones := PackedFloat32Array()
	for _i in stroke.points.size():
		ones.append(1.0)
	flat.pressures = ones
	var ink_synth := DesignBuilder.stroke_ink_units(stroke, balance)
	var ink_flat := DesignBuilder.stroke_ink_units(flat, balance)
	var drift := absf(ink_synth - ink_flat) / maxf(ink_flat, 1e-6)
	_check(drift < 0.05,
		"필압 합성이 잉크를 계통적으로 부풀리지 않는다 (편차 %.2f%% < 5%%: %.3f vs %.3f)" % [
			drift * 100.0, ink_synth, ink_flat])

	# 머문 자리가 실제로 굵다 — 정규화 후에도 앞쪽(머문 구간)이 뒤쪽(그은 구간)보다 두껍다
	_check(stroke.pressures[0] > stroke.pressures[stroke.pressures.size() - 1],
		"머문 시작점이 그은 끝점보다 굵다 (%.2f vs %.2f)" % [
			stroke.pressures[0], stroke.pressures[stroke.pressures.size() - 1]])
	canvas.queue_free()

	# ── 머문 시간이 길수록 그 지점이 더 굵다 (누적형의 정의) ──
	var short_c := _drive_canvas(6, 0.0)     # 0.1초
	var long_c := _drive_canvas(60, 0.0)     # 1.0초
	if short_c._entries.size() == 1 and long_c._entries.size() == 1:
		var s_p: PackedFloat32Array = short_c._entries[0].stroke.pressures
		var l_p: PackedFloat32Array = long_c._entries[0].stroke.pressures
		_check(l_p[0] > s_p[0],
			"오래 머물수록 그 지점이 굵다 (0.1초 %.2f < 1.0초 %.2f)" % [s_p[0], l_p[0]])
	else:
		_check(false, "머문 시간 비교용 획 확정")
	short_c.queue_free()
	long_c.queue_free()

	# ── 태블릿: 진짜 필압은 합성·정규화를 타지 않는다 ──
	var tab := _drive_canvas(30, 0.5)
	_check(tab._entries.size() == 1, "태블릿 획 1개 확정")
	if tab._entries.size() == 1:
		var t_stroke: StrokeData = tab._entries[0].stroke
		var t_mean := _mean(t_stroke.pressures)
		# 정규화됐다면 평균이 1.0이 됐을 것 — 0.5 근처면 원본 압력이 그대로 살아 있다
		_check(absf(t_mean - 1.0) > 0.1,
			"태블릿 필압은 평균 1.0으로 정규화되지 않는다 (평균 %.2f)" % t_mean)
		var tail_ok := true
		for i in range(1, t_stroke.pressures.size()):
			if absf(t_stroke.pressures[i] - 0.5) > 1e-3:
				tail_ok = false
		_check(tail_ok, "태블릿 필압 값이 입력 그대로(0.5) 보존된다")
	tab.queue_free()


# ────────── 4.10 작성 순서 강제 (TECH_SPEC §6.2) — 진 → 룬 → 문양 ──────────
# 순서는 문법이다: 인식기가 진의 안/밖으로 룬과 화살표를 가르므로 진이 없으면 판정이 불가능하다.
# **강제는 캔버스에만 있다** — Recognizer는 순수하게 남는다(위 인식기 테스트들이 그 증거).

func _test_draw_order() -> void:
	var rejected: Array[StringName] = []
	var stages: Array[int] = []
	var canvas := _new_canvas()
	canvas.stroke_rejected.connect(func(r: StringName) -> void: rejected.append(r))
	canvas.stage_changed.connect(func(s: int) -> void: stages.append(s))

	_check(canvas.get_stage() == Enums.DrawStage.CIRCLE, "빈 캔버스 → CIRCLE 단계")

	# ── CIRCLE 단계: 진이 아닌 획은 전부 거부 ──
	_stroke_on(canvas, _px_line(CV_C, CV_C + Vector2(80, 0)))     # 화살표 모양
	_check(canvas._entries.is_empty(), "CIRCLE 단계 — 직선 거부 (획 안 남음)")
	_check(rejected.size() == 1 and rejected[0] == &"out_of_order",
		"CIRCLE 단계 — 거부 사유 out_of_order")
	_check(canvas.get_ink_used() == 0.0, "거부된 획은 잉크를 소모하지 않는다")

	_stroke_on(canvas, _px_triangle(30.0))                        # 룬 모양
	_check(canvas._entries.is_empty(), "CIRCLE 단계 — 룬 거부")
	_check(canvas.get_stage() == Enums.DrawStage.CIRCLE, "거부 후에도 CIRCLE 단계 유지")

	# ── 진을 그리면 RUNE 단계로 ──
	_stroke_on(canvas, _px_circle(60.0))
	_check(canvas._entries.size() == 1, "진(원) 수락")
	_check(canvas.get_stage() == Enums.DrawStage.RUNE, "진 후 → RUNE 단계")
	_check(stages.has(Enums.DrawStage.RUNE), "stage_changed(RUNE) 발신")
	var ink_after_circle: float = canvas.get_ink_used()
	_check(ink_after_circle > 0.0, "수락된 획은 잉크를 소모한다")

	# ── RUNE 단계: 룬만 받는다. 화살표도, 예전 꼬리 모양 획도 전부 거부 ──
	rejected.clear()
	_stroke_on(canvas, _px_line(CV_C, CV_C + Vector2(80, 0)))     # 진을 뚫는 화살표
	_check(canvas._entries.size() == 1, "RUNE 단계 — 화살표 거부")
	_check(rejected.size() == 1 and rejected[0] == &"out_of_order",
		"RUNE 단계 — 화살표 거부 사유 out_of_order")
	_check(is_equal_approx(canvas.get_ink_used(), ink_after_circle),
		"거부 후 잉크 사용량 불변")

	# 꼬리 폐지(v1.6): 예전에 꼬리로 수락되던 획이 이제 화살표라 RUNE 단계에서 거부된다
	rejected.clear()
	_stroke_on(canvas, _px_line(CV_C + Vector2(66, 0), CV_C + Vector2(80, 0), 8))
	_check(canvas._entries.size() == 1, "RUNE 단계 — 예전 꼬리 모양 획도 거부 (꼬리 폐지)")
	_check(rejected.size() == 1 and rejected[0] == &"out_of_order",
		"예전 꼬리 획 거부 사유 out_of_order")

	# ── 룬을 그리면 ARROW 단계로 ──
	_stroke_on(canvas, _px_triangle(30.0))
	_check(canvas._entries.size() == 2, "RUNE 단계 — 룬 수락")
	_check(canvas.get_stage() == Enums.DrawStage.ARROW, "룬 후 → ARROW 단계")

	# ── ARROW 단계: 문양만 수락 ──
	rejected.clear()
	_stroke_on(canvas, _px_arc(40.0))        # 굽은 호 — 원도 룬도 아니라 DECOR로 떨어진다
	_check(canvas._entries.size() == 2, "ARROW 단계 — 미인식(DECOR) 획 거부")
	# 형이 흐트러진 것은 순서 위반과 다른 사유 — 다른 말을 해 줘야 한다 (자동보정 유도)
	_check(rejected.size() == 1 and rejected[0] == &"unrecognized",
		"ARROW 단계 — DECOR 거부 사유 unrecognized")

	_stroke_on(canvas, _px_line(CV_C, CV_C + Vector2(80, 0)))
	_check(canvas._entries.size() == 3, "ARROW 단계 — 문양 수락")
	_check(int(canvas.get_summary().get("arrow_count", 0)) == 1, "문양 1개")
	_check(canvas.get_design() != null, "진+룬+문양 → 도안 완성")

	# 진은 한 종류 — 모든 도안이 조준진이고 조준축은 캔버스 위쪽
	var made: SpellDesign = canvas.get_design()
	_check(made.circle_type == Enums.CircleType.AIMED, "캔버스 도안 → AIMED")
	_check(is_equal_approx(made.aim_axis, DesignBuilder.UP_AXIS), "캔버스 도안 → aim_axis = 위쪽")

	# ── undo하면 단계가 되돌아간다 (단계는 부품에서 파생하므로 자동) ──
	canvas.undo_last()                        # 문양 제거
	_check(canvas.get_stage() == Enums.DrawStage.ARROW, "문양 undo — 아직 ARROW 단계 (룬 있음)")
	canvas.undo_last()                        # 룬 제거
	_check(canvas.get_stage() == Enums.DrawStage.RUNE, "룬 undo → RUNE 단계로 되돌아감")
	canvas.undo_last()                        # 진 제거
	_check(canvas.get_stage() == Enums.DrawStage.CIRCLE, "진 undo → CIRCLE 단계로 되돌아감")
	_check(canvas.get_ink_used() == 0.0, "전부 undo → 잉크 0")

	# 되돌아간 뒤엔 다시 진부터 — 순서 강제가 살아 있다
	rejected.clear()
	_stroke_on(canvas, _px_triangle(30.0))
	_check(canvas._entries.is_empty() and rejected.size() == 1,
		"undo 후 CIRCLE 단계 — 룬 다시 거부")
	canvas.queue_free()

	# ── stage_hint: 각 단계가 "지금 뭘 그려야 하는지" 말해 준다 ──
	for stage: int in [Enums.DrawStage.CIRCLE, Enums.DrawStage.RUNE, Enums.DrawStage.ARROW]:
		_check(DrawingCanvas.stage_hint(stage) != "", "stage_hint(%d) 비어 있지 않음" % stage)


# ────────── 4.10b 중첩 진 (재귀) — 캔버스가 두 번째 원을 새 노드로 받는다 ──────────
# 껍질을 완성한 뒤 안쪽 진을 그리면, 단계가 그 안쪽 진을 따라가고(활성 노드) 도안에 자식이 붙는다.

func _test_nested_canvas() -> void:
	var canvas := _new_canvas()
	# 껍질: 큰 진 + 룬(안쪽 진과 안 겹치게 위쪽에) + 뚫는 화살표 → 단일 도안 완성
	_stroke_on(canvas, _px_circle(70.0))
	_check(canvas.get_stage() == Enums.DrawStage.RUNE, "껍질 진 후 → RUNE 단계")
	_stroke_on(canvas, _px_tri_at(CV_C + Vector2(0, -45), 15.0))
	_stroke_on(canvas, _px_line(CV_C, CV_C + Vector2(0, -100)))
	_check(canvas.get_design() != null, "껍질만으로 도안 완성 (단일)")
	_check(canvas.get_design().children.is_empty(), "아직 자식 없음")

	# 안쪽 진 — ARROW 단계에서도 원은 수락된다 (새 노드). 활성 노드가 안쪽 진으로 바뀐다
	_stroke_on(canvas, _px_circle(25.0))
	_check(canvas._entries.size() == 4, "ARROW 단계에서 두 번째(안쪽) 원 수락")
	_check(canvas.get_stage() == Enums.DrawStage.RUNE,
		"활성 노드가 안쪽 진 → 다시 RUNE 단계 (안쪽 진의 룬 차례)")

	# 안쪽 진의 룬
	_stroke_on(canvas, _px_tri_at(CV_C, 10.0))
	var d: SpellDesign = canvas.get_design()
	_check(d != null, "중첩 도안 완성")
	if d != null:
		_check(d.children.size() == 1, "껍질 도안이 안쪽 진 1개를 품는다")
		_check(d.rune_type == Enums.RuneType.FIRE, "껍질 룬 = 불")
		if d.children.size() == 1:
			_check(d.children[0].circle_radius < d.circle_radius, "안쪽 진 규모 < 껍질 규모")

	# 탁본 필사 — 완성 도안을 배경으로 깐다. _entries·인식엔 영향 없어야 한다 (순수 배경)
	var entries_before: int = canvas._entries.size()
	canvas.show_rubbing(d)
	_check(canvas.has_rubbing(), "show_rubbing → 탁본 깔림")
	_check(canvas._entries.size() == entries_before, "탁본은 _entries를 건드리지 않는다")
	canvas.clear_rubbing()
	_check(not canvas.has_rubbing(), "clear_rubbing → 탁본 걷힘")
	canvas.queue_free()


# ────────── 4.11 방위 가이드 (v1.6) — 위=앞(조준 방향)을 종이 위에 보이게 ──────────
# 순수 배경 렌더(_draw)라 **획으로 인식될 수 없다**. 그 구조적 보장을 여기서 고정한다.

func _test_orientation_guide() -> void:
	# 크기가 달라도(시험대 320 / 드로잉룸 등) 렌더가 성립해야 한다 — 실제로 _draw를 태운다
	for sz: Vector2 in [Vector2(300, 300), Vector2(120, 90), Vector2(480, 200)]:
		var canvas := DrawingCanvas.new()
		canvas.size = sz
		root.add_child(canvas)
		canvas.queue_redraw()
		await process_frame     # 이 프레임에 _draw()가 실제로 실행된다
		_check(canvas._entries.is_empty(),
			"방위 가이드는 획이 아니다 — %s 캔버스에 엔트리 0" % str(sz))
		_check(canvas.get_ink_used() == 0.0, "방위 가이드는 잉크를 쓰지 않는다 (%s)" % str(sz))
		_check(canvas.get_stage() == Enums.DrawStage.CIRCLE,
			"방위 가이드가 있어도 시작 단계는 CIRCLE (%s)" % str(sz))
		canvas.queue_free()

	# 가이드 위에 그린 진은 정상 인식된다 — 가이드가 인식을 방해하지 않는다
	var c2 := _new_canvas()
	c2.queue_redraw()
	await process_frame
	_stroke_on(c2, _px_circle(60.0))
	_check(c2._entries.size() == 1, "가이드 위에 그린 진 → 정상 수락")
	_check(c2.get_stage() == Enums.DrawStage.RUNE, "가이드 위에 그린 진 → RUNE 단계")
	c2.queue_free()


# ────────── 4.12 문구(스승의 목소리) + 단계 완료 피드백 (v1.6) ──────────
# 문구는 drawing_copy.gd 한 곳. 튜토리얼이 가르친 어휘(원·글자·화살표)를 그대로 쓴다.
# 연출은 헤드리스로 "보이는지"를 검증할 수 없으므로 **노드가 생기고 정리되는지**와
# **문구가 단계별로 맞게 나오는지**를 검증한다.

func _test_copy_and_feedback() -> void:
	# ── 문구: 단계별로 다르고, 어휘가 튜토리얼과 통일돼 있다 ──
	var stages: Array[int] = [
		Enums.DrawStage.CIRCLE, Enums.DrawStage.RUNE, Enums.DrawStage.ARROW]
	var seen := {}
	for st: int in stages:
		var todo := String(Copy.TODO.get(st, ""))
		var done := String(Copy.DONE.get(st, ""))
		var master := String(Copy.MASTER.get(st, ""))
		_check(todo != "" and done != "" and master != "", "단계 %d — 문구 3종 존재" % st)
		_check(not seen.has(todo), "단계 %d — TODO 문구가 단계마다 다르다" % st)
		seen[todo] = true
		_check(master.begins_with("「") and master.ends_with("」"),
			"단계 %d — 거부 문구는 스승의 목소리(「」)" % st)
	# 어휘: 명사는 **기능 용어**로 명시한다 — 진 · 룬 · 문양 (사용자 결정).
	# 톤(「」스승의 목소리)은 유지하되, 부품 이름이 모호하면 안 된다
	_check(String(Copy.TODO[Enums.DrawStage.CIRCLE]).contains("진"), "CIRCLE 문구에 '진'")
	_check(String(Copy.TODO[Enums.DrawStage.RUNE]).contains("룬"), "RUNE 문구에 '룬'")
	_check(String(Copy.TODO[Enums.DrawStage.ARROW]).contains("문양"), "ARROW 문구에 '문양'")
	_check(String(Copy.MASTER[Enums.DrawStage.RUNE]).contains("룬")
		and String(Copy.MASTER[Enums.DrawStage.RUNE]).contains("진"),
		"RUNE 거부 문구가 '진'·'룬'을 명시한다")
	_check(String(Copy.MASTER[Enums.DrawStage.ARROW]).contains("문양"),
		"ARROW 거부 문구가 '문양'을 명시한다")
	# 은유 어휘("글자")로 되돌아가지 않았는지 — 기능 용어가 모호해지면 안 된다
	var vocab_ok := true
	for st: int in stages:
		for s: String in [String(Copy.TODO[st]), String(Copy.DONE[st])]:
			if s.contains("글자"):
				vocab_ok = false
	_check(vocab_ok, "체크리스트에 은유 어휘('글자')가 없다 — 기능 용어로 명시")

	# ── 거부 사유가 갈린다: 단계 위반 vs 형이 흐트러짐(DECOR) ──
	var reasons: Array[StringName] = []
	var canvas := _new_canvas()
	canvas.stroke_rejected.connect(func(r: StringName) -> void: reasons.append(r))
	_stroke_on(canvas, _px_line(CV_C, CV_C + Vector2(80, 0)))   # CIRCLE 단계에 화살표 → 순서 위반
	_check(reasons.size() == 1 and reasons[0] == &"out_of_order",
		"단계 위반 → out_of_order")
	_check(Copy.reject_line(&"out_of_order", Enums.DrawStage.CIRCLE)
		== Copy.MASTER[Enums.DrawStage.CIRCLE], "out_of_order → 그 단계의 스승 대사")

	_stroke_on(canvas, _px_circle(60.0))       # 진 → RUNE 단계
	reasons.clear()
	# 진·룬이 다 있는 상태가 아니어도, RUNE 단계에서 형이 안 잡힌 획은 DECOR로 떨어진다
	_stroke_on(canvas, _px_triangle(30.0))     # 룬 수락 → ARROW 단계
	reasons.clear()
	_stroke_on(canvas, _px_arc(40.0))          # ARROW 단계에서 굽은 호 = DECOR (원은 이제 새 노드로 수락됨)
	_check(reasons.size() == 1 and reasons[0] == &"unrecognized",
		"인식 실패 → unrecognized (순서 위반과 다른 사유)")
	_check(Copy.UNRECOGNIZED.contains("자동보정"), "인식 실패 문구가 자동보정으로 유도한다")

	# ── 실패 이유를 **구체적으로**: 어느 룬에 얼마나 가까웠나 ──
	# "거의 됐다"(0.55)와 "전혀 아니다"(0.10)를 플레이어가 구별할 수 있어야 한다
	var near := Copy.unrecognized_line({
		"near_rune": Enums.RuneType.FIRE, "score": 0.42, "min_score": 0.60})
	_check(near.contains("불△"), "실패 문구가 가장 가까운 룬을 알려 준다 (got %s)" % near)
	_check(near.contains("0.42") and near.contains("0.60"),
		"실패 문구가 점수와 문턱을 숫자로 보여 준다")
	_check(near.contains("자동보정"), "실패 문구가 자동보정으로 유도한다")
	# 정보가 없으면 일반 문구로 폴백 (구세이브·스탬프 등)
	_check(Copy.unrecognized_line({}) == Copy.UNRECOGNIZED, "정보 없으면 일반 문구 폴백")
	# 인식기가 실제로 near_rune을 담아 준다
	var decor := Recognizer.classify_stroke(
		_gen_line(Vector2(0.35, 0.42), Vector2(0.62, 0.58), 10, 0.05),
		{"has_circle": true, "circle_center": Vector2(0.5, 0.5), "circle_radius": 0.4})
	if int(decor.role) == Enums.StrokeRole.DECOR:
		_check(decor.has("near_rune") and decor.has("min_score"),
			"인식기 DECOR 결과에 near_rune·min_score가 담긴다")

	# ── 연출: 노드가 생기고 정리된다 (트윈 후 잔여 노드 없음) ──
	# 거부된 획의 라인은 붉게 스쳐 사라진다 — 페이드가 끝나면 자식 노드가 남지 않아야 한다.
	# 먹선은 캔버스 직속이 아니라 **_ink_layer**의 자식이다 (v1.7 종이 확대 — 이 레이어에
	# zoom·pan이 걸린다). 캔버스 직속 자식을 세면 InkLayer 자신이 끼어들어 어긋난다
	var ink_layer: Node2D = canvas._ink_layer
	_check(ink_layer.get_child_count() >= canvas._entries.size(), "수락 획마다 먹선 노드 존재")
	# 트윈은 **실제 시간**으로 돈다 — 헤드리스는 프레임이 실시간보다 훨씬 빨라
	# 프레임 수로 기다리면 안 된다(그래서 이 검사가 처음엔 헛통과할 뻔했다). 타이머로 기다린다
	await create_timer(0.8).timeout
	_check(ink_layer.get_child_count() == canvas._entries.size(),
		"거부·번쩍임 연출 후 잔여 노드 없음 (먹선 %d == 엔트리 %d)" % [
			ink_layer.get_child_count(), canvas._entries.size()])

	# ── 도안 완성 신호 — 클라이맥스 연출의 방아쇠 ──
	var completed: Array[SpellDesign] = []
	canvas.design_completed.connect(func(d: SpellDesign) -> void: completed.append(d))
	_stroke_on(canvas, _px_line(CV_C, CV_C + Vector2(0, -80)))   # 화살표 → 완성
	_check(completed.size() == 1, "도안이 맺히는 순간 design_completed 1회")
	_stroke_on(canvas, _px_line(CV_C, CV_C + Vector2(80, 0)))    # 화살표 추가 → 갱신일 뿐
	_check(completed.size() == 1, "이후 화살표 추가는 완성 신호를 다시 쏘지 않는다")
	await create_timer(0.9).timeout      # 완성 번쩍임(0.55s)이 끝날 실제 시간
	_check(ink_layer.get_child_count() == canvas._entries.size(), "완성 연출 후에도 잔여 노드 없음")
	canvas.queue_free()

	# ── 체크리스트: 캔버스에 붙여 단계별 문구가 실제로 나오는지 ──
	var c2 := _new_canvas()
	var cl := DesignChecklist.new()
	root.add_child(cl)
	cl.bind(c2)
	await process_frame
	_check(_row_text(cl, 0).contains(String(Copy.TODO[Enums.DrawStage.CIRCLE])),
		"체크리스트 1행 = 원 (아직)")
	_check(_row_text(cl, 0).contains(Copy.NOW_MARK), "1행에 '지금' 표식")
	_stroke_on(c2, _px_circle(60.0))
	await process_frame
	_check(_row_text(cl, 0).contains(String(Copy.DONE[Enums.DrawStage.CIRCLE])),
		"원을 두른 뒤 1행이 완료형으로 바뀐다")
	_check(_row_text(cl, 0).begins_with("✓"), "완료 항목에 ✓")
	_check(_row_text(cl, 1).contains(Copy.NOW_MARK), "2행(글자)이 '지금'으로 승격")
	_stroke_on(c2, _px_triangle(30.0))
	await process_frame
	_check(_row_text(cl, 1).contains("불△"), "글자를 앉힌 뒤 룬 이름 표시")
	_check(_row_text(cl, 3) == "", "미완성 — 완성 문구는 비어 있다")
	_stroke_on(c2, _px_line(CV_C, CV_C + Vector2(0, -80)))
	await process_frame
	_check(_row_text(cl, 3) == Copy.COMPLETE, "완성 — 클라이맥스 문구가 뜬다")
	_check(_row_text(cl, 2).contains("1획"), "화살표 개수 표시")
	cl.queue_free()
	c2.queue_free()


func _row_text(cl: Node, idx: int) -> String:
	var l := cl.get_child(idx) as Label
	return l.text if l != null else ""


# ────────── 4.13 도안 책자 — 인식기가 매칭하는 그 형태를 보여 준다 ──────────
# 책자가 "예쁜 그림"이면 거짓말이 된다. **canonical() 템플릿 그대로**여야
# 보고 따라 그린 게 실제로 인식된다 — 그게 이 패널의 존재 이유다.

func _test_design_book() -> void:
	var book := DesignBook.new()
	root.add_child(book)
	await process_frame

	# 무리 3개: 진 · 룬 · 문양
	_check(book.get_child_count() == 3, "책자 무리 3개 (진·룬·문양)")
	_check(book._rune_cells != null and book._rune_cells.get_child_count() == 4,
		"룬 칸 4개 (불·충격·물·바람)")

	# 책자가 그리는 점열이 인식기 템플릿과 **같은 것**이어야 한다
	for rune: int in DesignBook.RUNE_ORDER:
		var canon := RuneTemplates.canonical(rune)
		_check(canon.size() >= 2, "%s canonical 템플릿 존재" % Copy.rune_label(rune))

	# 책자를 보고 그대로 그리면 반드시 인식된다 — 이게 책자의 계약이다
	var ctx := {
		"has_circle": true, "circle_center": Vector2(0.5, 0.5), "circle_radius": 0.30,
	}
	for rune: int in DesignBook.RUNE_ORDER:
		# canonical(중심 0·최장변 1)을 캔버스 좌표(중심 0.5, 크기 0.22)로 옮겨 그린다
		var pts := PackedVector2Array()
		for p: Vector2 in RuneTemplates.canonical(rune):
			pts.append(Vector2(0.5, 0.5) + p * 0.22)
		var r := Recognizer.classify_stroke(pts, ctx)
		var got := int(r.get("rune_type", -1)) if int(r.role) == Enums.StrokeRole.RUNE else -1
		_check(got == rune, "책자대로 그린 %s → 그대로 인식 (got %s)" % [
			Copy.rune_label(rune), Copy.rune_label(got) if got >= 0 else str(r.role)])

	# 해금 반영 — GameState가 있으면 잠긴 룬은 "?"로 가려진다
	var gs := root.get_node_or_null(^"/root/GameState")
	if gs != null:
		var locked_shown := false
		for i in book._rune_cells.get_child_count():
			var cell := book._rune_cells.get_child(i)
			var label := cell.get_child(1) as Label
			if label != null and label.text == Copy.BOOK_LOCKED:
				locked_shown = true
		var all_open := true
		for rune: int in DesignBook.RUNE_ORDER:
			if not bool(gs.call(&"is_unlocked", DesignBook.RUNE_UNLOCK[rune])):
				all_open = false
		_check(all_open or locked_shown, "잠긴 룬은 '?'로 가려진다")
	book.queue_free()


# ────────── 5. 도안 조립 — 진은 한 종류, 캔버스 위쪽 = 조준 방향 (v1.6) ──────────

func _run_pipeline(point_sets: Array, pressure_sets: Array = []) -> Dictionary:
	var entries: Array[Dictionary] = []
	for i in point_sets.size():
		var s := StrokeData.new()
		s.points = point_sets[i]
		if i < pressure_sets.size():
			s.pressures = pressure_sets[i]
		entries.append({"stroke": s, "locked": false, "result": {}})
	return DesignBuilder.classify_entries(entries)


func _test_assembly_aimed() -> void:
	var c := Vector2(0.5, 0.5)
	# 위(↑)·오른쪽 위·왼쪽 위로 뻗는 화살표 3개. 절대각: -π/2, -π/2+0.5, -π/2-0.5
	var abs_dirs: Array[float] = [-PI / 2.0, -PI / 2.0 + 0.5, -PI / 2.0 - 0.5]
	var sets: Array = [_gen_circle(c, 0.22), _gen_triangle(c, 0.10)]
	for ad: float in abs_dirs:
		sets.append(_gen_line(c, c + Vector2(cos(ad), sin(ad)) * 0.18, 10))
	var parts := _run_pipeline(sets)
	_check(DesignBuilder.is_complete(parts), "도안 완성 조건")
	if not DesignBuilder.is_complete(parts):
		return
	var balance := load("res://data/balance.tres") as BalanceData
	var d := DesignBuilder.build(parts, balance)
	# 진은 한 종류 — 꼬리 없이도 항상 조준진, 조준축은 캔버스 위쪽
	_check(d.circle_type == Enums.CircleType.AIMED, "꼬리 없이도 circle_type == AIMED")
	_check(is_equal_approx(d.aim_axis, DesignBuilder.UP_AXIS), "aim_axis == 캔버스 위쪽(-π/2)")
	_check(d.rune_type == Enums.RuneType.FIRE, "룬 타입 == FIRE")
	_check(d.rune_accuracy >= balance.accuracy_floor and d.rune_accuracy <= 1.0,
		"rune_accuracy ∈ [하한, 1]")
	_check(d.arrows.size() == 3, "화살표 3개")
	if d.arrows.size() == 3:
		# **실제 발사각으로 검증한다.** direction(중간 표현)만 보면 계약이 어긋나도 통과한다 —
		# 세션 7에 aim_axis가 두 번 빠져 모든 문양이 90도 틀어져 나가는데도 이 테스트가
		# 초록이던 사고가 실제로 있었다. 종이에 그은 방향이 화면에서 어디로 나가는지를 본다.
		for aim: float in [0.0, -PI / 2.0, PI, 1.1]:
			# 위(↑)로 그은 문양 = 앞 → **에임 방향 그대로**
			_check(absf(wrapf(_world_angle(d, d.arrows[0], aim) - aim, -PI, PI)) < 0.15,
				"위(↑)로 그은 문양 → 에임 방향으로 발사 (에임 %.1f rad)" % aim)
			# 나머지 둘은 에임 기준 ±0.5 rad 벌어진다 (그린 그대로의 상대 배치)
			_check(absf(wrapf(_world_angle(d, d.arrows[1], aim) - aim - 0.5, -PI, PI)) < 0.15,
				"문양1 → 에임 기준 +0.5 rad (에임 %.1f rad)" % aim)
			_check(absf(wrapf(_world_angle(d, d.arrows[2], aim) - aim + 0.5, -PI, PI)) < 0.15,
				"문양2 → 에임 기준 -0.5 rad (에임 %.1f rad)" % aim)
		for a: ArrowData in d.arrows:
			_check(a.magnitude > 0.0, "magnitude > 0")
			_check(a.origin.length() < 0.05, "origin ≈ 진 중심")
	_check(int(d.ink_cost.get(&"ink_basic", 0)) > 0, "ink_cost > 0")
	_check(d.mana_cost > 0.0, "mana_cost > 0")
	_check(d.strokes.size() == 5, "원본 획 5개 보존")
	_check(not d.display_name.contains("조준진") and not d.display_name.contains("고정진"),
		"display_name에 진 종류 표기 없음 (got %s)" % d.display_name)
	var roles := {}
	for s: StrokeData in d.strokes:
		roles[int(s.role)] = int(roles.get(int(s.role), 0)) + 1
	_check(int(roles.get(Enums.StrokeRole.CIRCLE, 0)) == 1, "CIRCLE 획 1")
	_check(int(roles.get(Enums.StrokeRole.TAIL, 0)) == 0, "TAIL 획 0 (꼬리 폐지)")
	_check(int(roles.get(Enums.StrokeRole.RUNE, 0)) == 1, "RUNE 획 1")
	_check(int(roles.get(Enums.StrokeRole.ARROW, 0)) == 3, "ARROW 획 3")


## **실제 발사각** — spell_system.gd의 공식을 그대로 옮긴 것 (모듈 B와 같은 계약).
## 종이에 그은 문양이 화면에서 어디로 나가는가. 이 값이 틀리면 게임이 틀린 것이다.
## 중간 표현(ArrowData.direction)만 검사하면 두 모듈의 계약이 어긋나도 초록이 뜬다 — 실제로 그랬다.
func _world_angle(design: SpellDesign, arrow: ArrowData, aim_angle: float) -> float:
	return arrow.direction + (aim_angle - design.aim_axis)


# ─────────────────────────── 6. 도안 조립 (대칭 노바) ───────────────────────────

## 대칭 노바 — 고정진이 사라져도 노바는 노바다. 통째로 회전해도 모양이 같으므로
## 고정진의 역할이 조준진에 자연히 흡수된다는 것이 이 설계의 근거다 (v1.6).
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
	_check(DesignBuilder.is_complete(parts), "노바 완성 조건")
	if not DesignBuilder.is_complete(parts):
		return
	var balance := load("res://data/balance.tres") as BalanceData
	var d := DesignBuilder.build(parts, balance)
	_check(d.circle_type == Enums.CircleType.AIMED, "노바도 AIMED (고정진 폐지)")
	_check(is_equal_approx(d.aim_axis, DesignBuilder.UP_AXIS), "노바 aim_axis == 캔버스 위쪽")
	_check(d.rune_type == Enums.RuneType.WIND, "룬 타입 == WIND")
	_check(d.arrows.size() == 8, "노바 화살표 8개")
	if d.arrows.size() == 8:
		# 그린 절대각 그대로 보존된다 (회전은 발사 때 spell_system이 한 번만 한다)
		for k in 8:
			_check(absf(wrapf(d.arrows[k].direction - dirs[k], -PI, PI)) < 0.12,
				"노바 화살표 %d — 그린 절대각 보존" % k)
		# **회전 불변성**: 어느 에임이든 8발이 45°씩 벌어진 채로 통째로 돈다.
		# 이것이 "고정진을 버려도 노바는 노바"라는 설계 근거다 (GDD §4.1)
		for aim: float in [0.0, -PI / 2.0, 1.1]:
			var angles: Array[float] = []
			for a: ArrowData in d.arrows:
				angles.append(wrapf(_world_angle(d, a, aim), 0.0, TAU))
			angles.sort()
			var uniform := true
			for k in 8:
				var gap := wrapf(angles[(k + 1) % 8] - angles[k], 0.0, TAU)
				if absf(gap - TAU / 8.0) > 0.12:
					uniform = false
			_check(uniform, "노바 — 에임 %.1f rad에서도 8발 45° 균등 (회전해도 노바)" % aim)


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
	# 마나 = 룬 기본 + **진 규모** + **룬 농도** + 발수 + **문양 사거리** (v1.9, TECH_SPEC §4.0 —
	# 진이 위력·크기·사거리를, 룬 농도가 상태이상 세기를, 문양 reach가 사거리 배율을 주므로
	# 시전 비용에 세 축이 다 붙는다). reach = 획 길이 ÷ 진 반지름: 0.9/0.2 = 4.5 → 상한 클램프,
	# 0.2/0.2 = 1.0 (기준 배율) — 문양별로 t가 다르다는 것까지 이 케이스가 덮는다
	var reach_t := 0.0
	for ad: ArrowData in d.arrows:
		reach_t += clampf(inverse_lerp(
			balance.glyph_reach_min, balance.glyph_reach_max, ad.reach), 0.0, 1.0)
	var expected_mana: float = balance.rune_mana_base[Enums.RuneType.WATER] \
		+ balance.circle_mana_mult * d.circle_radius \
		+ balance.rune_density_mana_mult * d.rune_fill \
		+ balance.mana_per_arrow * 2.0 \
		+ balance.glyph_reach_mana_mult * reach_t
	_check(is_equal_approx(d.mana_cost, expected_mana),
		"마나 = 룬 기본 + 진 규모 + 룬 농도 + 발수 + 문양 사거리")
	_check(balance.circle_mana_mult > 0.0,
		"balance.circle_mana_mult > 0 — 위 검사가 진 축의 존재를 실제로 구별한다")
	_check(balance.rune_density_mana_mult > 0.0 and d.rune_fill > 0.0,
		"rune_density_mana_mult > 0 且 rune_fill > 0 — 위 검사가 농도 축을 실제로 구별한다")
	# 두 문양의 reach가 실제로 다르다 — 위 검사가 문양 축을 뭉뚱그리지 않고 개별로 센다
	_check(d.arrows[0].reach > d.arrows[1].reach,
		"긴 문양의 reach > 짧은 문양의 reach (%.2f > %.2f)" % [
			d.arrows[0].reach, d.arrows[1].reach])

	# 잉크 = **통에서 나온 양**뿐이다 (v1.8, GDD §4.4). 가산·할증이 하나도 안 붙는다:
	# 조준진 가산(v1.6 폐지)도, 진 크기 할증(v1.8 폐지 — 이중 과금)도 없다.
	# 큰 진은 **둘레가 길어서** 이미 잉크를 더 먹으므로 할증이 필요 없었다
	var total_ink := 0.0
	for s: StrokeData in [circle_stroke, rune_stroke, arrow_stroke, arrow_stroke2]:
		total_ink += DesignBuilder.stroke_ink_units(s, balance)
	_check(int(d.ink_cost.get(&"ink_basic", 0)) == maxi(1, ceili(total_ink)),
		"잉크 = Σ(획이 올린 먹의 양). 할증 없음 (got %d, expected %d)" % [
			int(d.ink_cost.get(&"ink_basic", 0)), maxi(1, ceili(total_ink))])
	# 🔴 위 검사가 진짜로 '할증 없음'을 구별하는가 — 폐기된 계수들이 1이 아님을 확인해 둔다.
	# (둘 중 하나라도 다시 곱해지면 위 등식이 즉시 깨진다)
	_check(balance.aimed_circle_ink_mult > 1.0 and balance.circle_radius_ink_mult > 0.0,
		"폐기 계수가 여전히 0/1이 아니다 — 위 검사가 '할증 없음'을 실제로 구별한다")
	# 위 등식의 좌변은 ink_cost(제작 비용), 우변은 stroke_ink_units(종이 상한 판정 기준)이다.
	# 즉 **둘이 같은 값에서 나온다**는 것까지 위 한 줄이 못 박는다 (v1.8: 잉크는 숫자 하나)

	# 🔴 필압은 **구간별**로 먹힌다 — 평균으로 뭉개지 않는다 (v1.8).
	# 같은 경로·같은 평균 필압이라도 **어디서 눌렀는지**가 다르면 나온 먹의 양이 다르다
	var flat := StrokeData.new()
	flat.points = _gen_line(Vector2(0.2, 0.5), Vector2(0.8, 0.5), 9)
	flat.pressures = PackedFloat32Array([0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6])
	var heavy_end := StrokeData.new()
	heavy_end.points = flat.points
	# 평균은 같지만(0.6) 굵은 구간이 **뒤쪽에 몰려 있다**
	heavy_end.pressures = PackedFloat32Array([0.2, 0.2, 0.2, 0.2, 0.2, 1.0, 1.0, 1.0, 1.0])
	var ink_flat := DesignBuilder.stroke_ink_units(flat, balance)
	var ink_heavy := DesignBuilder.stroke_ink_units(heavy_end, balance)
	_check(ink_flat > 0.0 and ink_heavy > 0.0, "필압 획 잉크량 > 0")
	_check(absf(ink_flat - ink_heavy) > 0.01,
		"같은 평균 필압이라도 **눌린 위치**가 다르면 먹의 양이 다르다 (평활 %.2f vs 뒤쪽 %.2f)" % [
			ink_flat, ink_heavy])


# ────────── 5b. 중첩 진 (재귀, 2026-07-15 — TRUTH §4) ──────────
# 껍질 진이 안쪽 진을 품는다: 감싸는 가장 작은 진으로 트리를 짠다. 룬은 자기 진에, 화살표는
# 뚫고 나온 껍질에 붙는다. 단일 원이면 루트 하나·자식 0 = classify_entries와 동치(하위호환).

func _entries_from(point_sets: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pts: PackedVector2Array in point_sets:
		var s := StrokeData.new()
		s.points = pts
		entries.append({"stroke": s, "locked": false, "result": {}})
	return entries


func _test_nested_tree() -> void:
	var balance := load("res://data/balance.tres") as BalanceData
	var c := Vector2(0.5, 0.5)

	# 단일 원 — 트리는 루트 1개, 자식 0 (하위호환)
	var flat_sets: Array = [
		_gen_circle(c, 0.28),
		_gen_triangle(c, 0.10),                       # 불 룬
		_gen_line(c, c + Vector2(0.0, -0.42), 12),    # 위로 뚫는 화살표
	]
	var flat_roots := DesignBuilder.assemble_tree(_entries_from(flat_sets))
	_check(flat_roots.size() == 1, "단일 원 → 루트 1개")
	if flat_roots.size() == 1:
		_check((flat_roots[0].children as Array).is_empty(), "단일 원 → 자식 0")
		_check(flat_roots[0].has("rune"), "단일 원 루트에 룬 있음")
		_check((flat_roots[0].arrows as Array).size() == 1, "단일 원 루트에 화살표 1개")

	# 중첩 — 큰 껍질(0.30) 안에 작은 진(0.10). 각 진에 자기 불 룬, 껍질에 뚫는 화살표.
	var nested_sets: Array = [
		_gen_circle(c, 0.30),                          # 껍질
		_gen_circle(c, 0.10),                          # 안쪽 진
		_gen_triangle(c, 0.045),                       # 안쪽 진의 룬 (중심)
		_gen_triangle(Vector2(0.5, 0.74), 0.04),       # 껍질의 룬 (환형부: 0.10 밖·0.30 안)
		_gen_line(c, c + Vector2(0.0, -0.46), 12),     # 껍질을 뚫는 화살표
	]
	var roots := DesignBuilder.assemble_tree(_entries_from(nested_sets))
	_check(roots.size() == 1, "중첩 → 루트(껍질) 1개")
	if roots.size() != 1:
		return
	var shell: Dictionary = roots[0]
	_check((shell.children as Array).size() == 1, "껍질이 안쪽 진 1개를 품는다")
	_check(shell.has("rune") and int(shell.rune.type) == Enums.RuneType.FIRE,
		"껍질 룬 = 불 (환형부 획이 껍질에 소속)")
	_check((shell.arrows as Array).size() == 1, "화살표는 뚫고 나온 껍질에 소속")
	if (shell.children as Array).size() == 1:
		var inner: Dictionary = shell.children[0]
		_check(inner.has("rune") and int(inner.rune.type) == Enums.RuneType.FIRE,
			"안쪽 진 룬 = 불 (안쪽 획이 안쪽 진에 소속)")
		_check((inner.arrows as Array).is_empty(), "안쪽 진엔 화살표 없음")
		_check(float(inner.radius_cu) < float(shell.radius_cu), "안쪽 진이 껍질보다 작다")

	# build_tree → SpellDesign 트리
	var d := DesignBuilder.build_tree(shell, balance)
	_check(d != null, "build_tree → SpellDesign")
	if d != null:
		_check(d.children.size() == 1, "SpellDesign.children 1개")
		_check(d.rune_type == Enums.RuneType.FIRE, "껍질 SpellDesign 룬 = 불")
		if d.children.size() == 1:
			_check(d.children[0] is SpellDesign, "자식이 SpellDesign 타입")
			_check(d.children[0].circle_radius < d.circle_radius,
				"자식 진 규모 < 껍질 진 규모")
		# 재귀 트리가 .tres로 라운드트립되는가 (Godot 서브리소스 직렬화)
		var tmp := "user://_nested_roundtrip.tres"
		ResourceSaver.save(d, tmp)
		var loaded := ResourceLoader.load(tmp, "", ResourceLoader.CACHE_MODE_IGNORE) as SpellDesign
		_check(loaded != null and loaded.children.size() == 1,
			"중첩 SpellDesign .tres 라운드트립 (자식 보존)")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
