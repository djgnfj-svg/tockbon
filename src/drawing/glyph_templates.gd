extends RefCounted
## 문양 글자 3종 원시 템플릿 (GDD §4.3 — 팅김⚡ 지그재그 / 유도∿ 한쪽 호 / 관통‖ 직선+화살촉).
## recognizer가 $1 전처리(리샘플·회전·스케일 정규화) 후 캐시한다.
##
## **기본(BASIC)은 템플릿이 없다.** 어느 글자도 아닌 획이 곧 기본 탄이고, 인식 실패는 거부가
## 아니라 **폴백**이다 (GDD §4.5 — 진을 뚫고 나간 획은 무조건 탄이다). canonical(BASIC)만
## 책자 렌더용으로 곧은 직선을 돌려준다 — 매칭에는 쓰이지 않는다.
##
## 🔴 **모든 글자는 전진하며 끝난다.** 끝점이 시작점 근처로 돌아오는 U턴 형태를 쓰면
## `recognizer.detect_escape`가 "진을 안 뚫었다"로 읽어 **룬으로 오인**한다 (TECH_SPEC §6.1 —
## 끝점이 시작점보다 진 중심에서 ARROW_ESCAPE_GAIN만큼 더 멀어야 한다). 그래서 유도∿의 호는
## 스윕 180도를 넘기지 않고, 관통‖의 화살촉도 축 길이의 1/3을 넘지 않는다.
##
## 좌표: 시작점 (0,0)에서 **+X로 전진**, 진행 길이 1 기준. $1이 회전을 정규화하므로 방향 자체는
## 무관하지만 일관성을 위해 전부 +X로 맞춘다. 좌우 거울상은 raw_all()이 함께 낸다 —
## **회전 정규화는 반사를 흡수하지 못한다** (rune_templates가 물~·바람◎에 _flip_y를 두는 것과 같은 이유).
## 사용: const GlyphTemplates := preload("res://src/drawing/glyph_templates.gd")


static func raw_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# 팅김⚡ — 지그재그 (꺾임 수·진폭 변형). 부호가 교대하는 꺾임이 여러 번 = 이 글자의 표식
	_add(out, Enums.GlyphType.BOUNCE, _zigzag(3, 0.22))
	_add(out, Enums.GlyphType.BOUNCE, _zigzag(3, 0.15))
	_add(out, Enums.GlyphType.BOUNCE, _zigzag(2, 0.24))
	_add(out, Enums.GlyphType.BOUNCE, _zigzag(4, 0.19))
	# 유도∿ — 한쪽으로만 휜 호 (스윕 변형). 곡률 부호가 안 바뀌고 꺾임이 호 전체에 퍼진다
	_add(out, Enums.GlyphType.HOMING, _bow(100.0))
	_add(out, Enums.GlyphType.HOMING, _bow(130.0))
	_add(out, Enums.GlyphType.HOMING, _bow(160.0))
	# 관통‖ — 곧은 축 + 끝의 화살촉 (촉 길이·벌림 변형). 꺾임이 **끝에 한 번**, 급하게
	_add(out, Enums.GlyphType.PIERCE, _spear(0.28, 42.0))
	_add(out, Enums.GlyphType.PIERCE, _spear(0.34, 52.0))
	_add(out, Enums.GlyphType.PIERCE, _spear(0.22, 34.0))
	return out


## 책자가 **보이는 그대로 렌더**하는 대표 형태 — 중심 (0,0)·최장변 1로 정규화된 점열.
## RuneTemplates.canonical()과 같은 좌표계다. **보고 따라 그리면 반드시 그 글자로 인식된다**
## (test_glyph_auto가 못 박는다) — 그게 책자의 존재 이유다.
## BASIC은 곧은 직선을 낸다: 매칭 템플릿은 아니지만 "글자 없는 획"의 그림이 곧 직선이다.
static func canonical(glyph_type: int) -> PackedVector2Array:
	var pts: PackedVector2Array
	match glyph_type:
		Enums.GlyphType.BASIC:
			pts = _straight()
		Enums.GlyphType.BOUNCE:
			pts = _zigzag(3, 0.22)
		Enums.GlyphType.HOMING:
			pts = _bow(130.0)
		Enums.GlyphType.PIERCE:
			pts = _spear(0.28, 42.0)
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


## 원본 + 좌우 거울상을 함께 넣는다 (지그재그가 위로 꺾여 시작하든 아래로 꺾여 시작하든 같은 글자다)
static func _add(out: Array[Dictionary], type: int, pts: PackedVector2Array) -> void:
	out.append({"type": type, "points": pts})
	out.append({"type": type, "points": _flip_y(pts)})


static func _straight() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 24
	for i in n:
		pts.append(Vector2(float(i) / float(n - 1), 0.0))
	return pts


## 지그재그 — kinks개의 꺾임. 양 끝은 축 위에 있고 중간 꼭짓점이 위아래로 교대한다.
static func _zigzag(kinks: int, amp: float) -> PackedVector2Array:
	var segs := kinks + 1
	var verts: Array[Vector2] = []
	for i in segs + 1:
		var y := 0.0
		if i > 0 and i < segs:
			y = amp if (i % 2 == 1) else -amp
		verts.append(Vector2(float(i) / float(segs), y))
	return _polyline(verts, 12)


## 한쪽으로만 휜 호 — 현(0,0)→(1,0), 스윕 sweep_deg만큼 -Y쪽으로 부푼다.
## ⚠ 180도를 넘기면 끝점이 시작점 쪽으로 되말려 탈출 판정을 잃는다 (파일 상단 주석).
static func _bow(sweep_deg: float) -> PackedVector2Array:
	var sweep := deg_to_rad(clampf(sweep_deg, 20.0, 170.0))
	var r := 0.5 / sin(sweep * 0.5)
	var center := Vector2(0.5, sqrt(maxf(r * r - 0.25, 0.0)))
	var a0 := (Vector2(0.0, 0.0) - center).angle()
	var pts := PackedVector2Array()
	var n := 40
	for i in n:
		var a := a0 + sweep * float(i) / float(n - 1)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## 곧은 축 + 끝의 화살촉 — (0,0)→(1,0)을 긋고 촉을 한쪽으로 되꺾는다.
## barb_deg = 되돌아오는 축(-X)에서 촉이 벌어진 각. 촉은 **뒤로** 오지만 끝점은 여전히
## 시작점보다 훨씬 앞이라 탈출 판정이 산다.
static func _spear(barb_len: float, barb_deg: float) -> PackedVector2Array:
	var tip := Vector2(1.0, 0.0)
	var barb := tip + Vector2.RIGHT.rotated(PI + deg_to_rad(barb_deg)) * barb_len
	var shaft: Array[Vector2] = [Vector2.ZERO, tip]
	var head: Array[Vector2] = [tip, barb]
	var pts := _polyline(shaft, 26)
	var barb_pts := _polyline(head, 9)
	for i in range(1, barb_pts.size()):
		pts.append(barb_pts[i])
	return pts


## 꼭짓점 배열 → 변마다 per_edge등분한 폴리라인 (마지막 꼭짓점 포함)
static func _polyline(verts: Array[Vector2], per_edge: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for e in verts.size() - 1:
		for i in per_edge:
			pts.append(verts[e].lerp(verts[e + 1], float(i) / float(per_edge)))
	pts.append(verts[verts.size() - 1])
	return pts


static func _flip_y(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(Vector2(p.x, -p.y))
	return out
