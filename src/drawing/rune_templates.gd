extends RefCounted
## 룬 3종 원시 템플릿 도형 (v2.2: 충격 제거 — 불△ 닫힌 삼각 / 물~ 파형 / 바람◎ 나선).
## recognizer가 $1 전처리(리샘플·회전·스케일 정규화) 후 캐시하며, 역방향 변형도 recognizer가 자동 생성한다.
## 사용: const RuneTemplates := preload("res://src/drawing/rune_templates.gd")
##
## 🔴 단일 진실원 (2026-07-17, 세션 20): 모양은 이제 data/shapes/rune_*.tres(ShapeDef)에서 읽는다.
## - variants = raw_all()의 매칭 점열(그대로) · points = canonical() 대표 점열(정규화).
## 데이터가 없으면 아래 절차 생성으로 폴백한다(진 jin_basic 방식과 동일한 안전망). 모양을 고치려면
## 그 .tres 파일만 열면 되고, 책자·트레이스·인식기가 전부 같은 파일을 먹으므로 mismatch가 불가능하다.

const SHAPE_DIR := "res://data/shapes/"
const RUNE_FILES := {
	Enums.RuneType.FIRE: "rune_fire",
	Enums.RuneType.WATER: "rune_water",
	Enums.RuneType.WIND: "rune_wind",
}
static var _shape_cache: Dictionary = {}  # type(int) -> ShapeDef Resource 또는 null(로드 실패 기억)


## 룬 모양 데이터 (data/shapes/rune_<type>.tres). class_name 캐시에 안 의존하려 load()로 지연 로드.
static func _shape(type: int) -> Resource:
	if _shape_cache.has(type):
		return _shape_cache[type]
	var res: Resource = null
	var id: String = RUNE_FILES.get(type, "")
	if id != "":
		res = load(SHAPE_DIR + id + ".tres")
	_shape_cache[type] = res
	return res


static func raw_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for type: int in Enums.RUNE_TYPES:
		var shape := _shape(type)
		if shape != null and not shape.variants.is_empty():
			for v: PackedVector2Array in shape.variants:
				out.append({"type": type, "points": v.duplicate()})
		else:
			out.append_array(_fallback_raw(type))
	return out


## 자동보정 스냅용 대표 형태 — 중심 (0,0)·최장변 1로 정규화된 점열. data의 points를 그대로 쓴다.
static func canonical(rune_type: int) -> PackedVector2Array:
	var shape := _shape(rune_type)
	if shape != null and shape.points.size() >= 2:
		return shape.points.duplicate()
	return _fallback_canonical(rune_type)


# ─────────────────────────── 절차 폴백 (데이터 없을 때만) ───────────────────────────
## data/shapes/rune_*.tres가 있으면 아래는 절대 실행되지 않는다. 모양의 출생 기록이자 안전망이다.

static func _fallback_raw(type: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match type:
		Enums.RuneType.FIRE:
			# 불△ — 닫힌 삼각형 (회전·찌그러짐·살짝 열린 변형)
			out.append(_t(type, _triangle(0.0, 1.0, true)))
			out.append(_t(type, _triangle(0.26, 1.0, true)))
			out.append(_t(type, _triangle(0.1, 0.85, true)))
			out.append(_t(type, _triangle(0.0, 1.0, false)))
		Enums.RuneType.WATER:
			# 물~ — 파형 (주기·진폭 변형 + 상하 반전)
			out.append(_t(type, _wave(1.5, 0.45)))
			out.append(_t(type, _wave(2.0, 0.40)))
			out.append(_t(type, _wave(2.5, 0.30)))
			out.append(_t(type, _flip_y(_wave(2.0, 0.40))))
		Enums.RuneType.WIND:
			# 바람◎ — 나선 (감김 수 변형 + 거울상)
			out.append(_t(type, _spiral(2.0)))
			out.append(_t(type, _spiral(2.5)))
			out.append(_t(type, _spiral(3.0)))
			out.append(_t(type, _flip_y(_spiral(2.5))))
	return out


static func _fallback_canonical(rune_type: int) -> PackedVector2Array:
	var pts: PackedVector2Array
	match rune_type:
		Enums.RuneType.FIRE:
			pts = _triangle(0.0, 1.0, true)
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
