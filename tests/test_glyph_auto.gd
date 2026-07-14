extends SceneTree
## 문양 글자 자동 검증 (GDD §4.3 v1.9) — 팅김⚡ / 유도∿ / 관통‖ / 기본(폴백).
## 실행: Godot --headless --path . -s res://tests/test_glyph_auto.gd
##
## 통과 조건: FAIL 0건. 특히
##   (a) **인식 실패가 거부로 새지 않는다** — 어떤 획도 ARROW 역할을 잃지 않는다 (GDD §4.5)
##   (b) 곧은 직선은 언제나 BASIC (튜토리얼 첫 도안이 여기 걸려 있다)
##   (c) 손그림 스트레스 인식률 — 룬이 99.5%다. 문양도 같은 수준이어야 한다

const Recognizer := preload("res://src/drawing/recognizer.gd")
const DesignBuilder := preload("res://src/drawing/design_builder.gd")
const GlyphTemplates := preload("res://src/drawing/glyph_templates.gd")

## 진을 뚫고 나간 획만 문양이다 — 모든 인식 케이스가 이 컨텍스트를 쓴다 (TECH_SPEC §6.1)
const C := Vector2(0.5, 0.5)

var _pass := 0
var _fail := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20260714
	_test_canonical_contract()
	_test_basic_fallback()
	_test_glyphs_clean()
	_test_rotation_invariance()
	_test_glyph_stress()
	_test_heading()
	_test_reach_shape_invariant()
	_test_never_rejected()
	_test_reach()
	_test_mana_axis()
	_test_display_name()
	print("──────────────────────────────")
	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("GLYPH_AUTO_OK")
	quit(0 if _fail == 0 else 1)


func _check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: ", name)


func _glyph_name(g: int) -> String:
	return DesignBuilder.glyph_name(g) if g >= 0 else "?"


# ─────────────────────────── 합성 획 생성기 ───────────────────────────
# 템플릿 생성기와 파라미터화를 **일부러 다르게** 짰다 — 템플릿을 템플릿으로 검사하면
# 아무것도 검증하지 못한다 (test_drawing_auto와 같은 원칙).

func _noisy(pts: PackedVector2Array, e: float) -> PackedVector2Array:
	if e <= 0.0:
		return pts
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p + Vector2(_rng.randf_range(-e, e), _rng.randf_range(-e, e)))
	return out


## 획을 진 중심(C)에서 heading 방향으로 내보낸다 — 로컬 좌표(시작 (0,0)·+X 전진)를 회전·확대.
func _place(local: PackedVector2Array, heading: float, span: float,
		start_r: float, noise: float) -> PackedVector2Array:
	var origin := C + Vector2(cos(heading), sin(heading)) * start_r
	var out := PackedVector2Array()
	for p: Vector2 in local:
		out.append(origin + (p * span).rotated(heading))
	return _noisy(out, noise)


func _line_local(n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2(float(i) / float(n - 1), 0.0))
	return pts


## 지그재그 — 꺾임 수·진폭·좌우 시작 방향을 자유롭게 (템플릿과 다른 파라미터화)
func _zig_local(kinks: int, amp: float, up_first := true) -> PackedVector2Array:
	var segs := kinks + 1
	var verts: Array[Vector2] = []
	for i in segs + 1:
		var y := 0.0
		if i > 0 and i < segs:
			var s := 1.0 if (i % 2 == 1) == up_first else -1.0
			y = amp * s
		verts.append(Vector2(float(i) / float(segs), y))
	var pts := PackedVector2Array()
	for e in segs:
		for i in 10:
			pts.append(verts[e].lerp(verts[e + 1], float(i) / 10.0))
	pts.append(verts[segs])
	return pts


## 한쪽으로 휜 호 — **2차 베지에**로 만든다 (템플릿은 원호다. 다른 곡선족이어야 시험이 된다).
## sag = 현에서 부푸는 양(부호 = 휘는 방향)
func _bow_local(sag: float, n := 30) -> PackedVector2Array:
	var a := Vector2.ZERO
	var b := Vector2(1.0, 0.0)
	var ctrl := Vector2(0.5, sag * 2.0)
	var pts := PackedVector2Array()
	for i in n:
		var t := float(i) / float(n - 1)
		var u := 1.0 - t
		pts.append(a * (u * u) + ctrl * (2.0 * u * t) + b * (t * t))
	return pts


## 곧은 축 + 끝의 화살촉 (촉이 위/아래 어느 쪽으로 꺾이든 같은 글자)
func _spear_local(barb_len: float, barb_deg: float, up := true) -> PackedVector2Array:
	var tip := Vector2(1.0, 0.0)
	var s := -1.0 if up else 1.0
	var barb := tip + Vector2.RIGHT.rotated(PI + deg_to_rad(barb_deg) * s) * barb_len
	var pts := PackedVector2Array()
	for i in 22:
		pts.append(tip * (float(i) / 22.0))
	for i in 9:
		pts.append(tip.lerp(barb, float(i + 1) / 9.0))
	return pts


## 진(반지름 radius)이 있는 컨텍스트에서 획을 분류한다
func _classify(pts: PackedVector2Array, radius := 0.22) -> Dictionary:
	return Recognizer.classify_stroke(pts, {
		"has_circle": true, "circle_center": C, "circle_radius": radius, "has_rune": true,
	})


## 획 → 인식된 글자 (ARROW가 아니면 -1). **-1이 나오면 그 자체로 버그다** — 진을 뚫고 나간
## 획은 무조건 탄이어야 한다
func _glyph_of(pts: PackedVector2Array, radius := 0.22) -> int:
	var r := _classify(pts, radius)
	if int(r.role) != Enums.StrokeRole.ARROW:
		return -1
	return int(r.get("glyph", -1))


func _glyph_case(pts: PackedVector2Array, want: int, name: String, radius := 0.22) -> void:
	var r := _classify(pts, radius)
	var got := int(r.get("glyph", -1)) if int(r.role) == Enums.StrokeRole.ARROW else -1
	_check(got == want, "%s → %s (got %s, role=%s, score=%.2f)" % [
		name, _glyph_name(want), _glyph_name(got), str(r.role),
		float(r.get("glyph_score", 0.0))])


# ────────── 1. 책자 계약 — 캐노니컬을 보고 그대로 그리면 반드시 인식된다 ──────────
# 책자가 "예쁜 그림"이면 거짓말이 된다. 도안 책자는 canonical()을 렌더하므로, 그 점열을
# 캔버스에 옮겨 그린 것이 인식되지 않으면 플레이어는 **보고 따라 그려도 실패**한다.

func _canonical_stroke(g: int, heading: float, span: float) -> PackedVector2Array:
	# canonical은 중심 0·최장변 1 정규화 — 획의 **시작점**을 진 중심에 놓고 heading 쪽으로
	# 뻗게 옮겨 그린다 (플레이어가 실제로 그리는 방식: 진 안에서 출발해 밖으로 뚫는다)
	var canon := GlyphTemplates.canonical(g)
	var out := PackedVector2Array()
	for p: Vector2 in canon:
		out.append(C + ((p - canon[0]) * span).rotated(heading))
	return out


func _test_canonical_contract() -> void:
	for g: int in [Enums.GlyphType.BASIC, Enums.GlyphType.BOUNCE,
			Enums.GlyphType.HOMING, Enums.GlyphType.PIERCE]:
		var canon := GlyphTemplates.canonical(g)
		_check(canon.size() >= 2, "%s canonical 템플릿 존재" % _glyph_name(g))
		# 책자를 여러 방향·크기로 옮겨 그려도 그대로 인식돼야 한다
		for heading: float in [0.0, -PI / 2.0, 2.4]:
			for span: float in [0.36, 0.52]:
				_glyph_case(_canonical_stroke(g, heading, span), g,
					"책자대로 그린 %s (heading=%.1f span=%.2f)" % [
						_glyph_name(g), heading, span])

	# BASIC은 **매칭 템플릿이 아니다** — raw_all()에 없어야 한다 (있으면 폴백이 아니라 글자가 된다)
	var has_basic := false
	for raw: Dictionary in GlyphTemplates.raw_all():
		if int(raw.type) == Enums.GlyphType.BASIC:
			has_basic = true
	_check(not has_basic, "BASIC은 매칭 템플릿이 없다 (폴백이지 글자가 아니다)")

	# 모든 글자가 **전진하며 끝난다** — 끝점이 시작점으로 돌아오면 detect_escape가 룬으로 읽는다
	for raw: Dictionary in GlyphTemplates.raw_all():
		var pts: PackedVector2Array = raw.points
		var advance := pts[pts.size() - 1].x - pts[0].x
		var span_x := 0.0
		for p: Vector2 in pts:
			span_x = maxf(span_x, absf(p.x - pts[0].x))
		_check(advance > 0.5 * span_x, "%s 템플릿은 전진하며 끝난다 (U턴 금지)" % [
			_glyph_name(int(raw.type))])


# ────────── 2. BASIC 폴백 — 곧은 직선과 "어느 글자도 아닌 획" ──────────
# 🔴 튜토리얼 첫 도안이 곧은 화살표다. 여기가 깨지면 온보딩이 깨진다.

func _test_basic_fallback() -> void:
	for heading: float in [0.0, PI / 2.0, PI, -PI / 2.0, 2.2, -1.1]:
		for span: float in [0.16, 0.30, 0.44]:
			_glyph_case(_place(_line_local(), heading, span, 0.0, 0.0),
				Enums.GlyphType.BASIC, "곧은 직선 (heading=%.1f span=%.2f)" % [heading, span])

	# 손 지터가 있는 직선도 BASIC. **이게 진짜 함정이다**: scale_to_square가 얇은 획의
	# 세로 지터를 bbox 높이로 나눠 화면 가득한 가짜 지그재그로 부풀린다 → 팅김⚡ 오인
	for i in 30:
		var pts := _place(_line_local(), _rng.randf_range(0.0, TAU),
			_rng.randf_range(0.18, 0.45), 0.0, _rng.randf_range(0.002, 0.010))
		var got := _glyph_of(pts)
		_check(got == Enums.GlyphType.BASIC,
			"지터 직선 %d → BASIC (got %s)" % [i, _glyph_name(got)])

	# 아주 짧은 획 / 점 하나도 BASIC (거부가 아니다)
	_check(int(Recognizer.recognize_glyph(PackedVector2Array()).type) == Enums.GlyphType.BASIC,
		"빈 점열 → BASIC")
	var tiny := PackedVector2Array([C, C + Vector2(0.001, 0.0)])
	_check(int(Recognizer.recognize_glyph(tiny).type) == Enums.GlyphType.BASIC,
		"길이 0에 가까운 획 → BASIC")

	# 아무 글자도 아닌 엉뚱한 곡선(고리 모양)도 거부가 아니라 BASIC 폴백
	var blob := PackedVector2Array()
	for i in 24:
		var t := float(i) / 23.0
		blob.append(C + Vector2(0.30 * t, 0.10 * sin(TAU * 0.4 * t) + 0.04 * t * t))
	var blob_g := int(Recognizer.recognize_glyph(blob).type)
	_check(blob_g >= 0 and blob_g <= int(Enums.GlyphType.PIERCE),
		"미상 곡선도 유효한 글자를 낸다 (거부 없음)")


# ────────── 3. 글자 3종 — 깨끗한 획 ──────────

func _test_glyphs_clean() -> void:
	# 팅김⚡ — 지그재그
	_glyph_case(_place(_zig_local(3, 0.20), 0.0, 0.40, 0.0, 0.0),
		Enums.GlyphType.BOUNCE, "팅김⚡ 3꺾임")
	_glyph_case(_place(_zig_local(2, 0.24), -PI / 2.0, 0.42, 0.0, 0.0),
		Enums.GlyphType.BOUNCE, "팅김⚡ 2꺾임 위로")
	_glyph_case(_place(_zig_local(4, 0.18, false), 1.2, 0.44, 0.0, 0.0),
		Enums.GlyphType.BOUNCE, "팅김⚡ 4꺾임 반대 시작")

	# 유도∿ — 한쪽으로 휜 호
	_glyph_case(_place(_bow_local(0.26), 0.0, 0.40, 0.0, 0.0),
		Enums.GlyphType.HOMING, "유도∿ 위로 휨")
	_glyph_case(_place(_bow_local(-0.30), -PI / 2.0, 0.42, 0.0, 0.0),
		Enums.GlyphType.HOMING, "유도∿ 아래로 휨")
	_glyph_case(_place(_bow_local(0.38), 2.4, 0.44, 0.0, 0.0),
		Enums.GlyphType.HOMING, "유도∿ 깊게 휨")

	# 관통‖ — 곧은 축 + 화살촉
	_glyph_case(_place(_spear_local(0.28, 42.0), 0.0, 0.40, 0.0, 0.0),
		Enums.GlyphType.PIERCE, "관통‖ 기본")
	_glyph_case(_place(_spear_local(0.34, 55.0, false), -PI / 2.0, 0.42, 0.0, 0.0),
		Enums.GlyphType.PIERCE, "관통‖ 촉 반대쪽")
	_glyph_case(_place(_spear_local(0.22, 32.0), 2.0, 0.44, 0.0, 0.0),
		Enums.GlyphType.PIERCE, "관통‖ 얕은 촉")


# ────────── 4. 회전 불변 — 어느 방향으로 그리든 같은 글자 ──────────
# 문양은 **아무 방향으로나** 그린다 (방향 = 발사각이니 오히려 사방으로 그리는 게 정상이다).
# 회전에 따라 글자가 바뀌면 "위쪽으로 그린 팅김만 팅김"이라는 숨은 규칙이 생긴다.

func _test_rotation_invariance() -> void:
	var locals := {
		Enums.GlyphType.BOUNCE: _zig_local(3, 0.21),
		Enums.GlyphType.HOMING: _bow_local(0.28),
		Enums.GlyphType.PIERCE: _spear_local(0.30, 45.0),
	}
	for want: int in locals:
		for deg: float in [0.0, 30.0, 60.0, 90.0, 137.0, 180.0, 233.0, 300.0]:
			_glyph_case(_place(locals[want], deg_to_rad(deg), 0.40, 0.0, 0.0), want,
				"회전 불변 %s @%.0f도" % [_glyph_name(want), deg])


# ────────── 5. 손그림 스트레스 — 크기·회전·형태·노이즈 무작위 ──────────
# 세션 7 교훈: **깨끗한 합성 도형만 테스트하면 손그림 실패를 못 잡는다.**
# 사람이 실제로 그리는 범위를 무작위로 쓸어 인식률을 실측하고 고정한다.

func _test_glyph_stress() -> void:
	var n := 40
	var miss := {}
	var lost := {}      # ARROW 역할조차 못 받은 획 — 있으면 안 된다 (거부 = 폴백 위반)
	for i in n:
		var heading := _rng.randf_range(0.0, TAU)
		var noise := _rng.randf_range(0.002, 0.010)
		var radius := _rng.randf_range(0.14, 0.24)
		# 문양은 **진을 뚫고 나갈 만큼** 그린다 — 못 뚫은 획은 애초에 문양이 아니다 (TECH_SPEC §6.1).
		# ⚠ 관통‖의 화살촉은 끝점을 진 쪽으로 되당기므로(축 길이의 ~20%) 진에 딱 붙여 그리면
		# 탈출 판정을 잃는다. 사람이 실제로 그리는 크기 범위를 쓴다
		var span := _rng.randf_range(maxf(0.28, radius * 1.9), 0.48)
		var cases := {
			Enums.GlyphType.BASIC: _line_local(),
			Enums.GlyphType.BOUNCE: _zig_local(
				_rng.randi_range(2, 4), _rng.randf_range(0.14, 0.28),
				_rng.randf() < 0.5),
			Enums.GlyphType.HOMING: _bow_local(
				_rng.randf_range(0.20, 0.42) * (1.0 if _rng.randf() < 0.5 else -1.0)),
			Enums.GlyphType.PIERCE: _spear_local(
				_rng.randf_range(0.22, 0.38), _rng.randf_range(30.0, 58.0),
				_rng.randf() < 0.5),
		}
		for want: int in cases:
			var pts := _place(cases[want], heading, span, 0.0, noise)
			var got := _glyph_of(pts, radius)
			if got < 0:
				lost[want] = int(lost.get(want, 0)) + 1
			if got != want:
				miss[want] = int(miss.get(want, 0)) + 1

	var total_bad := 0
	for want: int in [Enums.GlyphType.BASIC, Enums.GlyphType.BOUNCE,
			Enums.GlyphType.HOMING, Enums.GlyphType.PIERCE]:
		var bad := int(miss.get(want, 0))
		total_bad += bad
		_check(int(lost.get(want, 0)) == 0, "손그림 스트레스 %s — 획을 잃음 %d건 (거부 금지)" % [
			_glyph_name(want), int(lost.get(want, 0))])
		_check(bad == 0, "손그림 스트레스 %s — %d/%d 오인식" % [_glyph_name(want), bad, n])
	var rate := 100.0 * float(4 * n - total_bad) / float(4 * n)
	print("GLYPH_STRESS 인식률 %.1f%% (%d/%d)" % [rate, 4 * n - total_bad, 4 * n])


# ────────── 5-b. 그은 방향으로 나간다 (v1.9 회귀) ──────────
# 🔴 **이 검사가 없어서 관통‖이 조용히 빗나가고 있었다.** 세션 10의 문양 163건은 *어느 글자인가*만
# 봤고 **방향은 아무도 안 봤다** — 인식률 100%인 채로 관통탄만 평균 14.6도 옆으로 날아갔다.
# 원인: direction을 획의 **끝점**으로 쟀는데 관통‖은 뒤로 꺾인 **화살촉**으로 끝난다.
# → InkRender.arrow_heading(시작 → 최원점)으로 교체. 여기서 못 박는다.
#
# 이 게임의 정체성이 "그린 대로 나간다"이므로 **방향은 글자 인식만큼 중요한 계약이다.**
# 세션 7의 90도 버그도 같은 구멍에서 나왔다 (중간 표현만 검증).

func _test_heading() -> void:
	var n := 50
	var worst := {}
	for i in n:
		var heading := _rng.randf_range(0.0, TAU)
		var noise := _rng.randf_range(0.002, 0.010)
		var radius := _rng.randf_range(0.14, 0.24)
		var span := _rng.randf_range(maxf(0.28, radius * 1.9), 0.48)
		var cases := {
			Enums.GlyphType.BASIC: _line_local(),
			Enums.GlyphType.BOUNCE: _zig_local(
				_rng.randi_range(2, 4), _rng.randf_range(0.14, 0.28), _rng.randf() < 0.5),
			Enums.GlyphType.HOMING: _bow_local(
				_rng.randf_range(0.20, 0.42) * (1.0 if _rng.randf() < 0.5 else -1.0)),
			Enums.GlyphType.PIERCE: _spear_local(
				_rng.randf_range(0.22, 0.38), _rng.randf_range(30.0, 58.0), _rng.randf() < 0.5),
		}
		for want: int in cases:
			var r := _classify(_place(cases[want], heading, span, 0.0, noise), radius)
			if int(r.role) != Enums.StrokeRole.ARROW:
				continue          # 역할 상실은 _test_glyph_stress가 잡는다
			var err := absf(rad_to_deg(wrapf(float(r.direction) - heading, -PI, PI)))
			worst[want] = maxf(float(worst.get(want, 0.0)), err)

	# 손그림 지터로 몇 도는 흔들린다. 8도는 "그린 대로 나간다"가 체감되는 상한이고,
	# 고치기 전 관통‖의 실측 최대(22.6도)와 명확히 갈라진다 — 회귀하면 반드시 걸린다
	for want: int in [Enums.GlyphType.BASIC, Enums.GlyphType.BOUNCE,
			Enums.GlyphType.HOMING, Enums.GlyphType.PIERCE]:
		var e := float(worst.get(want, 0.0))
		_check(e <= 8.0, "발사각 %s — 그은 방향에서 최대 %.1f도 벗어남 (상한 8도)" % [
			_glyph_name(want), e])
	print("HEADING 최대 오차: 기본 %.1f° · 팅김 %.1f° · 유도 %.1f° · 관통 %.1f°" % [
		float(worst.get(Enums.GlyphType.BASIC, 0.0)),
		float(worst.get(Enums.GlyphType.BOUNCE, 0.0)),
		float(worst.get(Enums.GlyphType.HOMING, 0.0)),
		float(worst.get(Enums.GlyphType.PIERCE, 0.0))])


# ────────── 5-c. reach는 '뻗은 거리'다 — 모양에 흔들리면 안 된다 (v1.9 회귀) ──────────
# 🔴 **v1.9는 reach를 총연장으로 쟀다** — 그건 "얼마나 멀리 뻗었나"가 아니라 "얼마나
# 구불구불한가"였다. 실측(고치기 전): 똑같이 0.40을 뻗어도 직선 2.00 / 진폭 큰 지그재그 3.00
# (상한 포화) / 촘촘한 지그재그 3.00. **짧게 그려도 진폭만 키우면 최대 사거리·최대 반사**를
# 공짜로 받았고, 팅김⚡·유도∿가 기본보다 구조적으로 유리했다.
# 세션 9의 rune_fill 수정과 같은 성격이다 — 정의가 불변량이 아니면 숨은 최적 플레이가 생긴다.

func _test_reach_shape_invariant() -> void:
	var radius := 0.20
	var span := 0.40
	var shapes := {
		"기본(직선)": _line_local(),
		"팅김 2꺾임 얕게": _zig_local(2, 0.10),
		"팅김 4꺾임 깊게": _zig_local(4, 0.30),
		"팅김 8꺾임 촘촘히": _zig_local(8, 0.28),
		"유도 완만": _bow_local(0.15),
		"유도 깊게": _bow_local(0.45),
		"관통 짧은촉": _spear_local(0.22, 34.0, false),
		"관통 긴촉": _spear_local(0.38, 58.0, true),
	}
	# 전부 같은 거리(span)를 뻗었다 → reach가 같아야 한다
	var reaches: Array[float] = []
	for name: String in shapes:
		var pts := _place(shapes[name], -PI / 2.0, span, 0.0, 0.0)
		var r := _classify(pts, radius)
		if int(r.role) != Enums.StrokeRole.ARROW:
			_check(false, "reach 불변성 — %s가 문양으로 안 잡힘" % name)
			continue
		reaches.append(float(r.extent) / radius)
	var lo := reaches[0]
	var hi := reaches[0]
	for v: float in reaches:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	# 관통‖은 촉이 뒤로 꺾여 뻗은 거리가 약간 줄어든다(창끝까지가 곧 extent) — 그건 정상이다.
	# 총연장 기준이면 여기서 2.00~3.00으로 갈렸다. 8%는 그 결함과 명확히 갈라진다
	var spread := (hi - lo) / maxf(lo, 1e-6) * 100.0
	_check(spread <= 8.0,
		"reach 모양 불변성 — 같은 거리를 뻗었는데 %.1f%% 갈림 (%.2f~%.2f, 상한 8%%)" % [
			spread, lo, hi])
	print("REACH 모양 불변성: 같은 거리 → reach %.2f~%.2f (%.1f%% 차)" % [lo, hi, spread])


# ────────── 6. 문양은 절대 거부되지 않는다 (GDD §4.5) ──────────
# 🔴 **이게 제일 중요한 계약이다.** 진을 뚫고 나간 획은 무슨 모양이든 탄이다.
# 룬은 점수 미달 시 DECOR로 떨어져 획이 사라지지만, 문양은 그러면 안 된다.

func _test_never_rejected() -> void:
	var rejected := 0
	var samples := 0
	for i in 60:
		# 무작위 난필 — 아무 글자도 아닌 획들. 진 중심에서 출발해 밖으로 나간다
		var heading := _rng.randf_range(0.0, TAU)
		var pts := PackedVector2Array()
		var n := _rng.randi_range(10, 40)
		var wob := _rng.randf_range(0.0, 0.14)
		var freq := _rng.randf_range(0.3, 3.5)
		var span := _rng.randf_range(0.30, 0.50)
		for k in n:
			var t := float(k) / float(n - 1)
			var local := Vector2(t, wob * sin(TAU * freq * t + _rng.randf_range(-0.4, 0.4)))
			pts.append(C + (local * span).rotated(heading))
		samples += 1
		var r := _classify(pts, _rng.randf_range(0.14, 0.26))
		if int(r.role) != Enums.StrokeRole.ARROW:
			rejected += 1
		elif not r.has("glyph"):
			rejected += 1
	_check(rejected == 0,
		"난필 %d개 전부 문양으로 산다 — 인식 실패 = BASIC 폴백 (거부 %d건)" % [samples, rejected])

	# 인식기 결과에 glyph·glyph_score가 **항상** 실린다 (소비 측이 분기하지 않도록)
	var r2 := _classify(_place(_line_local(), 0.0, 0.35, 0.0, 0.0))
	_check(r2.has("glyph") and r2.has("glyph_score"), "_arrow_result에 glyph·glyph_score 동봉")
	# 진이 없는 첫 획(직진성 폴백 경로)도 마찬가지
	var r3 := Recognizer.classify_stroke(_place(_line_local(), 0.0, 0.35, 0.0, 0.0), {})
	_check(int(r3.role) == Enums.StrokeRole.ARROW and r3.has("glyph"),
		"진 없는 직진 폴백 화살표에도 glyph 동봉")


# ────────── 7. reach — 진 대비 비율 (rune_fill과 대칭) ──────────

func _stroke(pts: PackedVector2Array) -> StrokeData:
	var s := StrokeData.new()
	s.points = pts
	return s


## 진 반지름 radius, 문양 길이 arrow_len(직선)인 도안을 빌드한다
func _build_with(radius: float, arrow_len: float, balance: BalanceData) -> SpellDesign:
	var circle := _stroke(_circle_pts(radius))
	var rune := _stroke(_tri_pts(radius * 0.5))
	var arrow := _stroke(_line_pts(C, C + Vector2(arrow_len, 0.0)))
	return DesignBuilder.build({
		"circle": {"center": C, "radius": radius, "stroke": circle},
		"rune": {"type": Enums.RuneType.FIRE, "accuracy_raw": 0.9, "stroke": rune},
		"arrows": [{
			"direction": 0.0, "length": arrow_len, "start": C,
			"glyph": int(Enums.GlyphType.BASIC), "glyph_score": 0.0, "stroke": arrow,
		}],
		"extras": [], "strokes_ordered": [circle, rune, arrow],
	}, balance)


func _circle_pts(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		var a := -PI / 2.0 + TAU * 0.98 * float(i) / 47.0
		pts.append(C + Vector2(cos(a), sin(a)) * r)
	return pts


func _tri_pts(size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for e in 3:
		var va := C + Vector2(cos(-PI / 2.0 + TAU * float(e) / 3.0),
			sin(-PI / 2.0 + TAU * float(e) / 3.0)) * size
		var vb := C + Vector2(cos(-PI / 2.0 + TAU * float((e + 1) % 3) / 3.0),
			sin(-PI / 2.0 + TAU * float((e + 1) % 3) / 3.0)) * size
		for i in 12:
			pts.append(va.lerp(vb, float(i) / 12.0))
	return pts


func _line_pts(a: Vector2, b: Vector2, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(a.lerp(b, float(i) / float(n - 1)))
	return pts


func _test_reach() -> void:
	var balance := load("res://data/balance.tres") as BalanceData

	# 같은 문양이라도 **진이 크면 reach가 작아진다** — 비율이기 때문이다.
	# (사거리는 진의 축이고 문양은 배율만 정한다: 큰 진에서 멀리 보내려면 그만큼 길게 그어야 한다)
	var small := _build_with(0.14, 0.28, balance)
	var big := _build_with(0.28, 0.28, balance)
	_check(small.arrows[0].reach > big.arrows[0].reach,
		"같은 문양, 진이 크면 reach가 작다 (진0.14 %.2f > 진0.28 %.2f)" % [
			small.arrows[0].reach, big.arrows[0].reach])
	# 값 자체: 길이 0.28 ÷ 반지름 0.14 = 2.0
	_check(absf(small.arrows[0].reach - 2.0) < 0.05,
		"reach = 획 길이 ÷ 진 반지름 (0.28/0.14 = 2.0, got %.2f)" % small.arrows[0].reach)

	# 같은 진에서 길게 그으면 reach가 커진다
	var short_d := _build_with(0.20, 0.16, balance)
	var long_d := _build_with(0.20, 0.50, balance)
	_check(long_d.arrows[0].reach > short_d.arrows[0].reach,
		"같은 진, 길게 그으면 reach ↑ (%.2f → %.2f)" % [
			short_d.arrows[0].reach, long_d.arrows[0].reach])

	# 밸런스 상하한으로 잘린다
	var tiny_d := _build_with(0.30, 0.10, balance)      # 비율 0.33 → 하한
	var huge_d := _build_with(0.12, 0.60, balance)      # 비율 5.0 → 상한
	_check(is_equal_approx(tiny_d.arrows[0].reach, balance.glyph_reach_min),
		"짧은 문양 → glyph_reach_min(%.2f) 클램프" % balance.glyph_reach_min)
	_check(is_equal_approx(huge_d.arrows[0].reach, balance.glyph_reach_max),
		"긴 문양 → glyph_reach_max(%.2f) 클램프" % balance.glyph_reach_max)

	# magnitude는 **원시 길이 그대로** — reach와 별개 값이다 (진 크기와 무관)
	_check(is_equal_approx(small.arrows[0].magnitude, big.arrows[0].magnitude),
		"magnitude는 진 크기에 안 흔들린다 (원시 길이 — reach와 별개)")

	# 획이 없는 도안(샘플·구세이브) → 스키마 기본값 유지
	var empty := StrokeData.new()
	var stub := DesignBuilder.build({
		"circle": {"center": C, "radius": 0.2, "stroke": empty},
		"rune": {"type": Enums.RuneType.FIRE, "accuracy_raw": 0.8, "stroke": empty},
		"arrows": [{"direction": 0.0, "length": 0.9, "start": C, "stroke": empty}],
		"extras": [], "strokes_ordered": [empty],
	}, balance)
	_check(is_equal_approx(stub.arrows[0].reach, ArrowData.new().reach),
		"획 없는 도안 → reach 기본값 1.0 유지 (구세이브 사거리 불변)")
	_check(stub.arrows[0].glyph == Enums.GlyphType.BASIC, "획 없는 도안 → BASIC")

	# 그린 문양의 글자가 도안에 실린다 — 파이프라인 끝까지 살아 있는지
	var circle := _stroke(_circle_pts(0.20))
	var rune := _stroke(_tri_pts(0.10))
	var zig := _place(_zig_local(3, 0.20), 0.0, 0.40, 0.0, 0.0)
	var spear := _place(_spear_local(0.30, 45.0), -PI / 2.0, 0.40, 0.0, 0.0)
	var entries: Array[Dictionary] = []
	for pts: PackedVector2Array in [circle.points, rune.points, zig, spear]:
		entries.append({"stroke": _stroke(pts), "locked": false})
	var parts := DesignBuilder.classify_entries(entries)
	_check(DesignBuilder.is_complete(parts), "지그재그+화살촉 도안 완성 조건")
	if DesignBuilder.is_complete(parts):
		var d := DesignBuilder.build(parts, balance)
		_check(d.arrows.size() == 2, "문양 2개")
		if d.arrows.size() == 2:
			_check(d.arrows[0].glyph == Enums.GlyphType.BOUNCE,
				"캔버스 경유 팅김⚡ (got %s)" % _glyph_name(int(d.arrows[0].glyph)))
			_check(d.arrows[1].glyph == Enums.GlyphType.PIERCE,
				"캔버스 경유 관통‖ (got %s)" % _glyph_name(int(d.arrows[1].glyph)))
			_check(d.arrows[0].reach > 1.0 and d.arrows[1].reach > 1.0,
				"캔버스 경유 reach 계산됨")


# ────────── 8. 마나 축 — 길게 그은 문양은 쏠 때마다 더 문다 (GDD §5) ──────────
# 공짜면 "문양은 언제나 최대한 길게"가 유일한 정답이 된다.

func _test_mana_axis() -> void:
	var balance := load("res://data/balance.tres") as BalanceData
	_check(balance.glyph_reach_mana_mult > 0.0,
		"balance.glyph_reach_mana_mult > 0 — 아래 검사가 문양 축을 실제로 구별한다")

	# 진을 고정하고 문양 길이만 늘린다 → 마나가 오른다 (진·룬 항은 그대로)
	var short_d := _build_with(0.20, 0.16, balance)
	var long_d := _build_with(0.20, 0.50, balance)
	_check(long_d.mana_cost > short_d.mana_cost,
		"긴 문양이 마나를 더 먹는다 (%.2f < %.2f)" % [short_d.mana_cost, long_d.mana_cost])

	# 차이는 정확히 문양 축만큼이다 (다른 항이 새어 들어오지 않았는지)
	var t_short: float = clampf(inverse_lerp(
		balance.glyph_reach_min, balance.glyph_reach_max, short_d.arrows[0].reach), 0.0, 1.0)
	var t_long: float = clampf(inverse_lerp(
		balance.glyph_reach_min, balance.glyph_reach_max, long_d.arrows[0].reach), 0.0, 1.0)
	var expect := balance.glyph_reach_mana_mult * (t_long - t_short)
	_check(absf((long_d.mana_cost - short_d.mana_cost) - expect) < 1e-3,
		"마나 차 = glyph_reach_mana_mult × Δt (기대 %.3f, 실제 %.3f)" % [
			expect, long_d.mana_cost - short_d.mana_cost])

	# 전체 공식 (v1.9) — 룬 기본 + 진 규모 + 룬 농도 + 발수 + **문양 사거리**
	var full: float = balance.rune_mana_base[Enums.RuneType.FIRE] \
		+ balance.circle_mana_mult * long_d.circle_radius \
		+ balance.rune_density_mana_mult * long_d.rune_fill \
		+ balance.mana_per_arrow * 1.0 \
		+ balance.glyph_reach_mana_mult * t_long
	_check(is_equal_approx(long_d.mana_cost, full),
		"마나 = 룬 + 진 + 농도 + 발수 + 문양 사거리 (기대 %.3f, 실제 %.3f)" % [
			full, long_d.mana_cost])


# ────────── 9. 이름 표기 — 문양 구성이 보인다 ──────────

func _test_display_name() -> void:
	var balance := load("res://data/balance.tres") as BalanceData
	# 전부 기본이면 옛 표기 그대로 (발수만)
	var basic_d := _build_with(0.20, 0.30, balance)
	_check(basic_d.display_name.contains("×1") and not basic_d.display_name.contains("기본"),
		"기본뿐인 도안 → 발수만 표기 (got '%s')" % basic_d.display_name)

	# 글자가 섞이면 구성이 드러난다
	var arrows: Array[ArrowData] = []
	for g: int in [Enums.GlyphType.BOUNCE, Enums.GlyphType.BOUNCE, Enums.GlyphType.PIERCE]:
		var ad := ArrowData.new()
		ad.glyph = g as Enums.GlyphType
		arrows.append(ad)
	var summary := DesignBuilder.glyph_summary(arrows)
	_check(summary.contains("팅김⚡×2") and summary.contains("관통‖×1"),
		"문양 구성 표기 (got '%s')" % summary)
