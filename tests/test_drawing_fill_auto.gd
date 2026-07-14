extends SceneTree
## 룬 농도 축 (`rune_fill`) 자동 검증 — v1.7 역할 축 (TECH_SPEC §4.0).
## 실행: Godot --headless --path . -s res://tests/test_drawing_fill_auto.gd
##
## 이 축이 존재하는 이유: $1 인식기가 크기를 정규화해 버려서 룬을 크게 그리든 작게 그리든
## 결과가 같았다 — 룬 그리기가 "4지선다 찍기"였다. 이제 **룬이 진을 얼마나 채우는가**가
## 상태이상 세기를 정한다. 그래서 이 테스트가 못 박아야 하는 것은 딱 넷이다:
##   (1) 같은 진 안에서 룬 크기가 fill을 실제로 가른다 (작게 ≠ 크게)
##   (2) fill은 **비율**이다 — 룬을 그대로 두고 진만 키우면 내려간다
##   (3) fill ∈ [0, 1] 은 어떤 입력에도 깨지지 않는다
##   (4) 농도가 마나에 값을 매긴다 — 공짜면 "언제나 최대한 크게"가 유일한 정답이 된다
## 실측값도 함께 찍는다 — 밴드가 현실적인지는 사람이 봐야 판단할 수 있다.

const Recognizer := preload("res://src/drawing/recognizer.gd")
const DesignBuilder := preload("res://src/drawing/design_builder.gd")

var _pass := 0
var _fail := 0


func _init() -> void:
	var balance := load("res://data/balance.tres") as BalanceData
	_test_definition(balance)
	_test_size_bands(balance)
	_test_ratio_not_absolute(balance)
	_test_bounds(balance)
	_test_mana_axis(balance)
	_report_measured(balance)
	print("──────────────────────────────")
	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("DRAWING_FILL_AUTO_OK")
	quit(0 if _fail == 0 else 1)


func _check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: ", name)


# ────────── 1. 정의: 룬 반경 = **무게중심 → 최원점 거리** (외접 반경) ──────────
# **회전 불변이 이 정의의 존재 이유다.** $1 인식기는 회전 불변이라 룬을 돌려 그려도 같은 룬이다.
# 농도가 회전에 흔들리면 같은 룬인데 세기만 조용히 달라진다 — "축에 맞춰 그리기"라는 숨은
# 최적 플레이가 생긴다. 축 정렬 bbox(AABB)를 쓰면 정확히 그 사고가 난다 (v1.7 초안의 실제 버그).

func _test_definition(_balance: BalanceData) -> void:
	# 납작한 물~ 형태 (가로로 긴 획). 무게중심에서 양 끝점까지가 최대 거리
	var s := StrokeData.new()
	s.points = PackedVector2Array([
		Vector2(0.20, 0.45), Vector2(0.35, 0.55), Vector2(0.50, 0.45)])
	var expect := _circumradius(s.points) / 0.25
	var fill := DesignBuilder.rune_fill_of(s, 0.25)
	_check(absf(fill - expect) < 1e-4,
		"외접 반경 정의 — fill = (무게중심→최원점) / 진반지름 = %.4f (got %.4f)" % [expect, fill])

	# 🔴 회귀 방지 — **돌려 그려도 농도는 그대로다** (AABB였다면 여기서 깨진다)
	var base_fill := DesignBuilder.rune_fill_of(s, 0.25)
	var worst := 0.0
	for deg: float in [15.0, 30.0, 45.0, 60.0, 90.0, 137.0]:
		var rot := StrokeData.new()
		var pivot := _centroid(s.points)
		var pts := PackedVector2Array()
		for p: Vector2 in s.points:
			pts.append(pivot + (p - pivot).rotated(deg_to_rad(deg)))
		rot.points = pts
		var f := DesignBuilder.rune_fill_of(rot, 0.25)
		worst = maxf(worst, absf(f - base_fill))
		_check(absf(f - base_fill) < 1e-4,
			"%.0f도 돌려 그려도 fill 동일 (%.4f vs %.4f)" % [deg, f, base_fill])
	print("[측정] 회전 불변 — 최대 편차 %.6f (AABB 정의였다면 0.23까지 벌어졌다)" % worst)

	# 획 없음 / 진 없음 → 0 (샘플 도안·구세이브 방어)
	_check(DesignBuilder.rune_fill_of(null, 0.25) == 0.0, "null 획 → fill 0")
	_check(DesignBuilder.rune_fill_of(StrokeData.new(), 0.25) == 0.0, "빈 획 → fill 0")
	_check(DesignBuilder.rune_fill_of(s, 0.0) == 0.0, "진 반지름 0 → fill 0")


func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	return c / float(pts.size())


func _circumradius(pts: PackedVector2Array) -> float:
	var c := _centroid(pts)
	var r := 0.0
	for p: Vector2 in pts:
		r = maxf(r, c.distance_to(p))
	return r


# ────────── 2. 같은 진 안: 작게 그린 룬 vs 꽉 채운 룬 ──────────
# 이것이 축의 전부다. 여기가 갈라지지 않으면 v1.7은 아무것도 바꾸지 않은 것이다.

func _test_size_bands(balance: BalanceData) -> void:
	var r := 0.24
	var small := _build(r, _triangle(0.06), balance)
	var big := _build(r, _triangle(0.22), balance)
	_check(small != null and big != null, "작은 룬·큰 룬 도안 완성")
	if small == null or big == null:
		return
	print("[측정] 진 0.24 — 작은 룬(△0.06) fill=%.3f / 큰 룬(△0.22) fill=%.3f" % [
		small.rune_fill, big.rune_fill])
	_check(small.rune_fill < 0.35,
		"진 구석에 작게 그린 룬 → 옅다 (fill %.3f < 0.35)" % small.rune_fill)
	_check(big.rune_fill > 0.7,
		"진을 꽉 채운 룬 → 짙다 (fill %.3f > 0.7)" % big.rune_fill)
	# 크기가 갈라져도 **속성은 그대로다** — 농도 축이 속성 축을 오염시키면 안 된다
	_check(small.rune_type == Enums.RuneType.FIRE and big.rune_type == Enums.RuneType.FIRE,
		"룬 크기가 달라도 속성(불△)은 같다")

	# 단조성 — 중간 크기는 중간 농도. 밴드 두 점만 찍으면 계단 함수도 통과한다
	var prev := -1.0
	for size: float in [0.05, 0.09, 0.13, 0.17, 0.21]:
		var d := _build(r, _triangle(size), balance)
		if d == null:
			_check(false, "룬 △%.2f 도안 완성" % size)
			return
		_check(d.rune_fill > prev, "룬이 클수록 fill이 오른다 (△%.2f → %.3f)" % [size, d.rune_fill])
		prev = d.rune_fill


# ────────── 3. fill은 비율이다 — 절대 크기가 아니다 ──────────

func _test_ratio_not_absolute(balance: BalanceData) -> void:
	# (a) 룬을 그대로 두고 **진만 키우면** 농도가 내려간다 (같은 글자가 넓은 종이에서 옅어진다)
	var prev := 99.0
	for r: float in [0.18, 0.24, 0.30, 0.36]:
		var d := _build(r, _triangle(0.12), balance)
		if d == null:
			_check(false, "진 %.2f 도안 완성" % r)
			return
		_check(d.rune_fill < prev,
			"진이 커지면 같은 룬의 fill이 내려간다 (진 %.2f → %.3f)" % [r, d.rune_fill])
		prev = d.rune_fill

	# (b) **룬/진 비율이 같으면 fill도 같다** — circle_radius(진 규모)를 바꿔도 농도 축은 안 따라간다.
	# 두 축이 섞이면 "진을 키우는 것"만으로 상태이상까지 세지는 축 위반이 생긴다
	var a := _build(0.20, _triangle(0.12), balance)   # 비율 0.6
	var b := _build(0.30, _triangle(0.18), balance)   # 비율 0.6 (진·룬 둘 다 1.5배)
	_check(a != null and b != null, "비율 동일 도안 2개 완성")
	if a == null or b == null:
		return
	_check(absf(a.rune_fill - b.rune_fill) < 0.02,
		"룬/진 비율이 같으면 fill도 같다 (%.3f vs %.3f)" % [a.rune_fill, b.rune_fill])
	# 규모 축(circle_radius)은 실제로 갈라져 있다 — 위 검사가 "안 따라간다"를 진짜로 구별한다
	_check(absf(a.circle_radius - b.circle_radius) > 0.15,
		"같은 두 도안의 circle_radius는 다르다 (%.2f vs %.2f) — 규모/농도가 별개 축" % [
			a.circle_radius, b.circle_radius])


# ────────── 4. fill ∈ [0, 1] — 어떤 입력에도 ──────────

func _test_bounds(balance: BalanceData) -> void:
	# 진보다 큰 룬을 억지로 밀어 넣어도(인식기는 이런 획을 화살표로 가르지만, 빌더는 방어해야 한다)
	# 상한 1.0을 넘지 않는다. 빌더에 부품을 직접 주입해 인식기를 우회한다
	var huge := StrokeData.new()
	huge.points = _triangle(0.60)
	var d := DesignBuilder.build(_stub_parts(0.15, huge), balance)
	_check(is_equal_approx(d.rune_fill, 1.0), "진보다 큰 룬 → fill 1.0 클램프 (got %.3f)" % d.rune_fill)

	# 실제 인식 경로를 지나온 4종 룬 × 여러 크기 — 전부 0..1
	var all_ok := true
	for r: float in [0.18, 0.24, 0.32]:
		for pts: PackedVector2Array in [
				_triangle(0.10), _triangle(0.18),
				_angle(0.12), _angle(0.18),
				_wave(0.20, 0.05), _wave(0.34, 0.08),
				_spiral(0.09, 2.5), _spiral(0.15, 2.5)]:
			var dd := _build(r, pts, balance)
			if dd == null:
				continue   # 그 크기에서 인식이 안 되는 조합은 이 테스트의 관심사가 아니다
			if dd.rune_fill < 0.0 or dd.rune_fill > 1.0:
				all_ok = false
	_check(all_ok, "룬 4종 × 진 3종 — rune_fill ∈ [0, 1]")

	# 획이 없는 도안(샘플·구세이브)은 스키마 기본값(중간 농도)을 유지한다 — 0으로 죽지 않는다
	var empty := StrokeData.new()
	var d_empty := DesignBuilder.build(_stub_parts(0.20, empty), balance)
	_check(is_equal_approx(d_empty.rune_fill, SpellDesign.new().rune_fill),
		"획 없는 도안 → 스키마 기본 농도 유지 (got %.2f)" % d_empty.rune_fill)


# ────────── 5. 농도에 값을 매긴다 — 마나 (v1.7) ──────────
# 잉크(제작)는 그린 총량으로 이미 물고 있다. 마나(시전)에도 물리지 않으면
# "룬은 언제나 최대한 크게"가 유일한 정답이 되고 축이 선택이 아니라 의무가 된다.

func _test_mana_axis(balance: BalanceData) -> void:
	var r := 0.24
	var small := _build(r, _triangle(0.06), balance)
	var big := _build(r, _triangle(0.22), balance)
	if small == null or big == null:
		_check(false, "마나 비교용 도안 완성")
		return
	# 진 규모·룬 속성·발수가 전부 같다 — 마나 차이는 오직 농도에서 온다
	_check(is_equal_approx(small.circle_radius, big.circle_radius)
			and small.rune_type == big.rune_type
			and small.arrows.size() == big.arrows.size(),
		"마나 비교 — 농도 외 축이 동일")
	_check(big.mana_cost > small.mana_cost,
		"짙은 룬이 마나를 더 먹는다 (옅음 %.2f < 짙음 %.2f)" % [small.mana_cost, big.mana_cost])
	var expected_gap := balance.rune_density_mana_mult * (big.rune_fill - small.rune_fill)
	_check(absf((big.mana_cost - small.mana_cost) - expected_gap) < 1e-3,
		"마나 차 == rune_density_mana_mult × Δfill (%.3f vs %.3f)" % [
			big.mana_cost - small.mana_cost, expected_gap])
	print("[측정] 마나 — 옅은 룬 %.2f / 짙은 룬 %.2f (Δ%.2f, mult=%.1f)" % [
		small.mana_cost, big.mana_cost, big.mana_cost - small.mana_cost,
		balance.rune_density_mana_mult])
	_check(balance.rune_density_mana_mult > 0.0,
		"balance.rune_density_mana_mult > 0 — 위 검사가 농도 축을 실제로 구별한다")


# ────────── 실측 표 — 밴드가 현실적인지는 사람이 봐야 한다 ──────────

func _report_measured(balance: BalanceData) -> void:
	print("[측정] 진 0.24 안에서 룬 4종의 fill (그린 크기별):")
	var cases := {
		"불△": [_triangle(0.06), _triangle(0.14), _triangle(0.22)],
		"충격>": [_angle(0.08), _angle(0.14), _angle(0.20)],
		"물~": [_wave(0.14, 0.04), _wave(0.28, 0.07), _wave(0.44, 0.10)],
		"바람◎": [_spiral(0.06, 2.5), _spiral(0.12, 2.5), _spiral(0.20, 2.5)],
	}
	for name: String in cases:
		var line := "  %-6s " % name
		for pts: PackedVector2Array in cases[name]:
			var d := _build(0.24, pts, balance)
			line += ("fill=%.3f " % d.rune_fill) if d != null else "(미인식) "
		print(line)


# ─────────────────────────── 도안 조립 ───────────────────────────

## 진(r) + 룬(rune_pts) + 화살표 1 → 인식 파이프라인 경유 SpellDesign. 미완성이면 null.
func _build(r: float, rune_pts: PackedVector2Array, balance: BalanceData) -> SpellDesign:
	var c := Vector2(0.5, 0.5)
	var entries: Array[Dictionary] = []
	for pts: PackedVector2Array in [
			_circle(c, r), rune_pts, _line(c, c + Vector2(r + 0.18, 0.0))]:
		var s := StrokeData.new()
		s.points = pts
		entries.append({"stroke": s, "locked": false, "result": {}})
	var parts := DesignBuilder.classify_entries(entries)
	if not DesignBuilder.is_complete(parts):
		return null
	return DesignBuilder.build(parts, balance)


## 인식기를 우회한 합성 부품 — 경계값(진보다 큰 룬·빈 획)을 빌더에 직접 먹인다
func _stub_parts(radius: float, rune_stroke: StrokeData) -> Dictionary:
	var c := Vector2(0.5, 0.5)
	var circle_stroke := StrokeData.new()
	circle_stroke.points = _circle(c, radius)
	var arrow_stroke := StrokeData.new()
	arrow_stroke.points = _line(c, c + Vector2(0.3, 0.0))
	return {
		"circle": {"center": c, "radius": radius, "stroke": circle_stroke},
		"rune": {"type": Enums.RuneType.FIRE, "accuracy_raw": 0.9, "stroke": rune_stroke},
		"arrows": [{"direction": 0.0, "length": 0.3, "start": c, "stroke": arrow_stroke}],
		"extras": [],
		"strokes_ordered": [circle_stroke, rune_stroke, arrow_stroke],
	}


# ─────────────────────────── 합성 획 (캔버스 단위 0..1) ───────────────────────────
# 전부 캔버스 중앙(0.5, 0.5)을 중심으로 그린다 — 진 안에 놓이는지가 인식의 전제다.

func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 72:
		var a := -PI / 2.0 + TAU * 0.98 * float(i) / 71.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _line(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(a.lerp(b, float(i) / 11.0))
	return pts


## 외접원 반지름 size인 정삼각형 → bbox = (√3·size) × (1.5·size), 긴 변은 가로
func _triangle(size: float) -> PackedVector2Array:
	var c := Vector2(0.5, 0.5)
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


## 충격> — 벌림 size의 꺾인 획
func _angle(size: float) -> PackedVector2Array:
	var c := Vector2(0.5, 0.5)
	var start := c + Vector2(-size * 0.7, -size)
	var corner := c + Vector2(size * 0.7, 0.0)
	var end := c + Vector2(-size * 0.7, size)
	var pts := PackedVector2Array()
	for i in 13:
		pts.append(start.lerp(corner, float(i) / 12.0))
	for i in 12:
		pts.append(corner.lerp(end, float(i + 1) / 12.0))
	return pts


## 물~ — 폭 width·진폭 amp의 2주기 파형 (중앙 정렬)
func _wave(width: float, amp: float) -> PackedVector2Array:
	var origin := Vector2(0.5 - width * 0.5, 0.5)
	var pts := PackedVector2Array()
	for i in 56:
		var t := float(i) / 55.0
		pts.append(origin + Vector2(width * t, amp * sin(TAU * 2.0 * t)))
	return pts


## 바람◎ — 최대 반지름 r_max의 나선
func _spiral(r_max: float, loops: float) -> PackedVector2Array:
	var c := Vector2(0.5, 0.5)
	var pts := PackedVector2Array()
	for i in 80:
		var t := float(i) / 79.0
		var th := loops * TAU * t
		pts.append(c + Vector2(cos(th), sin(th)) * r_max * pow(t, 0.7))
	return pts
