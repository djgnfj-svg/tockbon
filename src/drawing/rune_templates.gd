extends RefCounted
## 룬 4종 원시 템플릿 도형 (GDD §4.2 — 불△ 닫힌 삼각 / 충격> 꺾인 각선 / 물~ 파형 / 바람◎ 나선).
## recognizer가 $1 전처리(리샘플·회전·스케일 정규화) 후 캐시하며, 역방향 변형도 recognizer가 자동 생성한다.
## 사용: const RuneTemplates := preload("res://src/drawing/rune_templates.gd")


static func raw_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# 불△ — 닫힌 삼각형 (회전·찌그러짐·살짝 열린 변형)
	out.append(_t(Enums.RuneType.FIRE, _triangle(0.0, 1.0, true)))
	out.append(_t(Enums.RuneType.FIRE, _triangle(0.26, 1.0, true)))
	out.append(_t(Enums.RuneType.FIRE, _triangle(0.1, 0.85, true)))
	out.append(_t(Enums.RuneType.FIRE, _triangle(0.0, 1.0, false)))
	# 충격> — 꺾인 각선 (벌림각·팔 길이 변형)
	out.append(_t(Enums.RuneType.IMPACT, _angle_shape(60.0, 1.0)))
	out.append(_t(Enums.RuneType.IMPACT, _angle_shape(90.0, 1.0)))
	out.append(_t(Enums.RuneType.IMPACT, _angle_shape(110.0, 1.0)))
	out.append(_t(Enums.RuneType.IMPACT, _angle_shape(80.0, 0.65)))
	# 물~ — 파형 (주기·진폭 변형 + 상하 반전)
	out.append(_t(Enums.RuneType.WATER, _wave(1.5, 0.45)))
	out.append(_t(Enums.RuneType.WATER, _wave(2.0, 0.40)))
	out.append(_t(Enums.RuneType.WATER, _wave(2.5, 0.30)))
	out.append(_t(Enums.RuneType.WATER, _flip_y(_wave(2.0, 0.40))))
	# 바람◎ — 나선 (감김 수 변형 + 거울상)
	out.append(_t(Enums.RuneType.WIND, _spiral(2.0)))
	out.append(_t(Enums.RuneType.WIND, _spiral(2.5)))
	out.append(_t(Enums.RuneType.WIND, _spiral(3.0)))
	out.append(_t(Enums.RuneType.WIND, _flip_y(_spiral(2.5))))
	return out


## 자동보정 스냅용 대표 형태 — 중심 (0,0)·최장변 1로 정규화된 점열.
static func canonical(rune_type: int) -> PackedVector2Array:
	var pts: PackedVector2Array
	match rune_type:
		Enums.RuneType.FIRE:
			pts = _triangle(0.0, 1.0, true)
		Enums.RuneType.IMPACT:
			pts = _angle_shape(90.0, 1.0)
		Enums.RuneType.WATER:
			pts = _wave(2.0, 0.40)
		Enums.RuneType.WIND:
			pts = _spiral(2.5)
		_:
			return PackedVector2Array()
	var lo: Vector2 = pts[0]
	var hi: Vector2 = pts[0]
	for p: Vector2 in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var span := maxf(maxf(hi.x - lo.x, hi.y - lo.y), 1e-6)
	var center := (lo + hi) * 0.5
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append((p - center) / span)
	return out


static func _t(type: int, pts: PackedVector2Array) -> Dictionary:
	return {"type": type, "points": pts}


static func _triangle(rot: float, squash: float, closed: bool) -> PackedVector2Array:
	var verts: Array[Vector2] = []
	for k in 3:
		var a := rot - PI / 2.0 + TAU * float(k) / 3.0
		var r := squash if k == 1 else 1.0
		verts.append(Vector2(cos(a), sin(a)) * r)
	var pts := PackedVector2Array()
	var per_edge := 16
	for e in 3:
		var va := verts[e]
		var vb := verts[(e + 1) % 3]
		var frac := 0.85 if (e == 2 and not closed) else 1.0
		for i in per_edge:
			pts.append(va.lerp(vb, frac * float(i) / float(per_edge)))
	if closed:
		pts.append(verts[0])
	return pts


static func _angle_shape(spread_deg: float, arm2: float) -> PackedVector2Array:
	# 꼭짓점이 오른쪽, 팔이 왼쪽으로 벌어지는 ">" 형태 (회전 정규화로 방향은 무관)
	var half := deg_to_rad(spread_deg) * 0.5
	var dir1 := Vector2(cos(PI - half), sin(PI - half))
	var dir2 := Vector2(cos(PI + half), sin(PI + half))
	var start := dir1 * 1.0
	var end := dir2 * arm2
	var pts := PackedVector2Array()
	var per_arm := 14
	for i in per_arm:
		pts.append(start.lerp(Vector2.ZERO, float(i) / float(per_arm)))
	for i in per_arm + 1:
		pts.append(Vector2.ZERO.lerp(end, float(i) / float(per_arm)))
	return pts


static func _wave(periods: float, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 48
	for i in n:
		var t := float(i) / float(n - 1)
		pts.append(Vector2(2.0 * t, -amp * sin(TAU * periods * t)))
	return pts


static func _spiral(loops: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 72
	for i in n:
		var t := float(i) / float(n - 1)
		var th := loops * TAU * t
		var r := lerpf(0.05, 1.0, t)
		pts.append(Vector2(cos(th), sin(th)) * r)
	return pts


static func _flip_y(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(Vector2(p.x, -p.y))
	return out
