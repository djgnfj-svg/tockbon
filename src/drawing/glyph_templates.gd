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
## **회전 정규화는 반사를 흡수하지 못한다** (data/shapes 쪽 물~·바람◎ variants가 거울상을 따로 담는 것과 같은 이유).
## 사용: const GlyphTemplates := preload("res://src/drawing/glyph_templates.gd")


## 🔴 단일 진실원 (2026-07-17, 세션 20): 모양은 data/shapes/glyph_*.tres(ShapeDef)가 **유일한 출처**다.
## - variants = raw_all()의 매칭 점열(좌우 거울상까지 **이미 구워져 있음** → 여기선 재-flip 안 한다).
## - points = canonical() 대표 점열(정규화). BASIC·THRUST는 variants가 비어도 points는 있다.
## 절차 생성 폴백은 없다 — 데이터가 없거나 비어 있으면 push_error로 크게 실패한다(조용히 빈 값을
## 돌려주면 인식기가 아무것도 못 알아보는데 원인이 안 보이기 때문).
const SHAPE_DIR := "res://data/shapes/"
const GLYPH_FILES := {
	Enums.GlyphType.BASIC: "glyph_basic",
	Enums.GlyphType.BOUNCE: "glyph_bounce",
	Enums.GlyphType.HOMING: "glyph_homing",
	Enums.GlyphType.PIERCE: "glyph_pierce",
	Enums.GlyphType.THRUST: "glyph_thrust",
}
## raw_all()이 매칭 템플릿을 내는 글자 순서 (BASIC·THRUST는 매칭 없음 — 폴백/거부).
const GLYPH_MATCH_TYPES: Array[int] = [Enums.GlyphType.BOUNCE, Enums.GlyphType.HOMING, Enums.GlyphType.PIERCE]
static var _shape_cache: Dictionary = {}  # type(int) -> ShapeDef Resource 또는 null


static func _shape(type: int) -> Resource:
	if _shape_cache.has(type):
		return _shape_cache[type]
	var res: Resource = null
	var id: String = GLYPH_FILES.get(type, "")
	if id != "":
		res = load(SHAPE_DIR + id + ".tres")
	_shape_cache[type] = res
	return res


static func raw_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for type: int in GLYPH_MATCH_TYPES:
		var shape := _shape(type)
		if shape != null and not shape.variants.is_empty():
			for v: PackedVector2Array in shape.variants:
				out.append({"type": type, "points": v.duplicate()})
		else:
			push_error("GlyphTemplates.raw_all: %s 없음/비어있음 (%s%s.tres)" % [
				Enums.GlyphType.keys()[type], SHAPE_DIR, GLYPH_FILES.get(type, "?")])
	return out


## 책자가 **보이는 그대로 렌더**하는 대표 형태 — 중심 (0,0)·최장변 1로 정규화된 점열. data의 points를 그대로 쓴다.
## RuneTemplates.canonical()과 같은 좌표계다. **보고 따라 그리면 반드시 그 글자로 인식된다**
## (test_glyph_auto가 못 박는다) — 그게 책자의 존재 이유다.
## BASIC은 곧은 직선을 낸다: 매칭 템플릿은 아니지만 "글자 없는 획"의 그림이 곧 직선이다.
static func canonical(glyph_type: int) -> PackedVector2Array:
	var shape := _shape(glyph_type)
	if shape != null and shape.points.size() >= 2:
		return shape.points.duplicate()
	push_error("GlyphTemplates.canonical: %s 없음/비어있음 (%s%s.tres)" % [
		Enums.GlyphType.keys()[glyph_type], SHAPE_DIR, GLYPH_FILES.get(glyph_type, "?")])
	return PackedVector2Array()


## 화살촉 — 점열의 **머리(마지막 점)**에 얹는 두 갈래 미늘을 `b1 → 촉 → b2` 한 폴리라인으로 돌려준다.
## 🔴 **렌더 전용 장식이다** (사용자 확정 2026-07-15 뒤집음): 문양을 화살표로 **보이게** 하려고
## 그린다. 인식·raw_all에는 절대 들어가지 않는다 — "보고 따라 그리면 그 글자로 인식된다"는 촉 없는
## 몸통 기준 그대로다 (test_glyph_auto 불변). 촉 길이는 글자 전체 크기의 비율이라 **어느 좌표계
## (canonical 정규·본보기 캔버스)로 줘도 알아서 비례한다** — 그리는 쪽은 span만 곱하면 된다.
static func head_barbs(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 2:
		return PackedVector2Array()
	var tip: Vector2 = pts[pts.size() - 1]
	var dir: Vector2 = tip - pts[pts.size() - 2]
	if dir.length() < 1e-6:
		return PackedVector2Array()
	dir = dir.normalized()
	var lo: Vector2 = pts[0]
	var hi: Vector2 = pts[0]
	for p: Vector2 in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var extent := maxf(maxf(hi.x - lo.x, hi.y - lo.y), 1e-6)
	var barb := extent * 0.30
	var ang := deg_to_rad(148.0)
	var out := PackedVector2Array()
	out.append(tip + dir.rotated(ang) * barb)
	out.append(tip)
	out.append(tip + dir.rotated(-ang) * barb)
	return out
