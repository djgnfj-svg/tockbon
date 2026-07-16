extends RefCounted
## 룬 3종 원시 템플릿 도형 (v2.2: 충격 제거 — 불△ 닫힌 삼각 / 물~ 파형 / 바람◎ 나선).
## recognizer가 $1 전처리(리샘플·회전·스케일 정규화) 후 캐시하며, 역방향 변형도 recognizer가 자동 생성한다.
## 사용: const RuneTemplates := preload("res://src/drawing/rune_templates.gd")
##
## 🔴 단일 진실원 (2026-07-17, 세션 20): 모양은 data/shapes/rune_*.tres(ShapeDef)가 **유일한 출처**다.
## - variants = raw_all()의 매칭 점열(그대로) · points = canonical() 대표 점열(정규화).
## 절차 생성 폴백은 없다 — 데이터가 없거나 비어 있으면 push_error로 크게 실패한다(조용히 빈 값을
## 돌려주면 인식기가 아무것도 못 알아보는데 원인이 안 보이기 때문). 모양을 고치려면 그 .tres 파일만
## 열면 되고, 책자·트레이스·인식기가 전부 같은 파일을 먹으므로 mismatch가 불가능하다.

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
			push_error("RuneTemplates.raw_all: %s 없음/비어있음 (%s%s.tres)" % [
				Enums.RuneType.keys()[type], SHAPE_DIR, RUNE_FILES.get(type, "?")])
	return out


## 자동보정 스냅용 대표 형태 — 중심 (0,0)·최장변 1로 정규화된 점열. data의 points를 그대로 쓴다.
static func canonical(rune_type: int) -> PackedVector2Array:
	var shape := _shape(rune_type)
	if shape != null and shape.points.size() >= 2:
		return shape.points.duplicate()
	push_error("RuneTemplates.canonical: %s 없음/비어있음 (%s%s.tres)" % [
		Enums.RuneType.keys()[rune_type], SHAPE_DIR, RUNE_FILES.get(rune_type, "?")])
	return PackedVector2Array()
