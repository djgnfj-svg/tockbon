extends RefCounted
## 인식 결과 → SpellDesign 조립 + 비용 계산 (GDD §4.4, §5 비용 축 분리).
## 잉크 = 그린 총량(길이×필압) + 진 크기 가산 / 마나 = 룬 + **진 규모** + 발수 축 (v1.6).
## 역할 축 (TECH_SPEC §4.0): 진 = 규모 / 룬 = 속성 / 문양 = 방식.
## 종이 등급(paper_params)은 호출자가 ItemDef.params를 직접 넘긴다 — Db 없이도 테스트 가능.
## 사용: const DesignBuilder := preload("res://src/drawing/design_builder.gd")

const Recognizer := preload("res://src/drawing/recognizer.gd")
const InkRender := preload("res://src/core/ink_render.gd")

const INK_ID := &"ink_basic"

## ArrowData.path 점 개수 — 저장 크기·투사체 추종 계산 비용과 곡률 보존의 절충
const ARROW_PATH_POINTS := 14

## 캔버스 위쪽 = 조준 방향 (GDD §4.1). 모든 도안의 aim_axis가 이 값이고,
## 발사 시 도안이 통째로 마우스 에임 쪽으로 회전한다 — 위로 그은 화살표가 에임으로 나간다.
const UP_AXIS := -PI / 2.0

## SpellDesign 스키마 기본 내구 — into 재사용 시 durability_bonus가 누적되지 않도록 기준값
static var _base_durability_max: int = SpellDesign.new().durability_max

const RUNE_NAMES := {
	Enums.RuneType.FIRE: "불△",
	Enums.RuneType.IMPACT: "충격>",
	Enums.RuneType.WATER: "물~",
	Enums.RuneType.WIND: "바람◎",
}

static var _seq := 0


## 엔트리 배열을 그린 순서대로 재분류해 부품 딕셔너리를 만든다.
## entries[i] = {"stroke": StrokeData, "locked": bool, "result": Dictionary}
## locked(스탬프·자동보정) 엔트리는 재인식하지 않고 기존 result를 유지한다 — 정확도 보존 (GDD v1.3).
static func classify_entries(entries: Array[Dictionary]) -> Dictionary:
	var ctx := {}
	var parts := {"arrows": [], "extras": [], "strokes_ordered": []}
	for e in entries:
		var stroke: StrokeData = e.stroke
		var res: Dictionary
		if e.get("locked", false):
			res = e.result
		else:
			res = Recognizer.classify_stroke(stroke.points, ctx)
			e["result"] = res
		stroke.role = res.role
		parts.strokes_ordered.append(stroke)
		match int(res.role):
			Enums.StrokeRole.CIRCLE:
				if not parts.has("circle"):
					parts["circle"] = {"center": res.center, "radius": res.radius, "stroke": stroke}
					ctx["has_circle"] = true
					ctx["circle_center"] = res.center
					ctx["circle_radius"] = res.radius
				else:
					stroke.role = Enums.StrokeRole.DECOR
					parts.extras.append(stroke)
			Enums.StrokeRole.RUNE:
				if not parts.has("rune"):
					parts["rune"] = {
						"type": res.rune_type,
						"accuracy_raw": res.score,
						"stroke": stroke,
					}
					ctx["has_rune"] = true
				else:
					stroke.role = Enums.StrokeRole.DECOR
					parts.extras.append(stroke)
			Enums.StrokeRole.ARROW:
				parts.arrows.append({
					"direction": res.direction,
					"length": res.length,
					"start": res.start,
					"stroke": stroke,
				})
			_:
				parts.extras.append(stroke)
	return parts


## 도안 완성 조건: 진 1 + 룬 1 + 화살표 1+ (GDD §4)
static func is_complete(parts: Dictionary) -> bool:
	return parts.has("circle") and parts.has("rune") and not parts.arrows.is_empty()


## parts → SpellDesign. into를 주면 기존 인스턴스를 갱신한다(id 유지).
## paper_grade·paper_params: 선택된 종이의 등급·ItemDef.params (TECH_SPEC §4.1 PAPER 키).
## 기본 인자는 무보정(등급 1·감면 0·보너스 0)과 같아 기존 호출과 호환된다.
static func build(parts: Dictionary, balance: BalanceData, into: SpellDesign = null,
		paper_grade: int = 1, paper_params: Dictionary = {}) -> SpellDesign:
	var d := into
	if d == null:
		d = SpellDesign.new()
		_seq += 1
		d.id = StringName("design_%d_%d" % [Time.get_ticks_msec(), _seq])

	# 진은 한 종류다 (v1.6): 모든 도안이 조준진이고 **캔버스 위쪽이 곧 조준 방향**이다.
	# 발사 시 도안이 통째로 에임 쪽으로 돈다 — 대칭 노바를 그리면 회전해도 노바이므로
	# 고정진의 역할이 자연히 흡수된다. 예외 없는 규칙 하나 (GDD §4.1)
	d.circle_type = Enums.CircleType.AIMED
	d.aim_axis = UP_AXIS
	var circle: Dictionary = parts.circle
	# 스키마의 circle_radius(0..1)는 "캔버스를 꽉 채우는 원(반지름 0.5) = 1.0" 기준
	d.circle_radius = clampf(float(circle.radius) / 0.5, 0.0, 1.0)
	d.rune_type = parts.rune.type
	d.rune_accuracy = clampf(
		maxf(float(parts.rune.accuracy_raw), balance.accuracy_floor), 0.0, 1.0)

	var arrows: Array[ArrowData] = []
	var radius_cu := maxf(float(circle.radius), 1e-6)  # 캔버스 단위 원 반지름
	for a: Dictionary in parts.arrows:
		var ad := ArrowData.new()
		# **캔버스 절대각 그대로 저장한다.** 원본 획(strokes)·발사 기점(origin)도 전부 캔버스
		# 좌표이고, 발사 때 spell_system이 `aim - aim_axis` 만큼 **한 번만** 통째로 회전시킨다.
		# 여기서 aim_axis를 미리 빼면 발사 때 또 빠져서 **90도 틀어진다** (실측으로 잡힌 버그).
		ad.direction = wrapf(float(a.direction), -PI, PI)
		# v1.6: magnitude는 **기록만 남는다** — 위력·크기는 진이 정한다 (TECH_SPEC §4.0).
		# 필드를 지우지 않는 이유: 문양 종류(증폭·유도…) 도입 시 이 값을 다시 쓴다 (BACKLOG §1)
		ad.magnitude = clampf(float(a.length) / balance.arrow_full_length, 0.05, 1.0)
		# origin은 진 반지름 = 1.0 정규화 (가장자리 = 1.0, TECH_SPEC §4)
		ad.origin = (Vector2(a.start) - Vector2(circle.center)) / radius_cu
		var arrow_stroke := a.get("stroke") as StrokeData
		ad.path = _arrow_path(arrow_stroke)
		if not ad.path.is_empty():
			# path와 같은 리샘플 인덱스 — 붓을 누른 굵기 변화가 그대로 날아간다.
			# 필압 없는 획(마우스·스탬프)이면 빈 배열이 나오고 먹선은 균일 굵기로 폴백한다.
			ad.path_pressures = InkRender.resample_pressures(
				arrow_stroke.pressures, ARROW_PATH_POINTS)
		arrows.append(ad)
	d.arrows = arrows

	var strokes: Array[StrokeData] = []
	strokes.assign(parts.strokes_ordered)
	d.strokes = strokes

	# 잉크: 총 획 길이(×필압) 비례 + 원 크기 가산 (GDD §4.1, §4.4).
	# 조준진 가산은 없다 — 조준이 기본이 됐으니 가산할 대상이 없다 (balance.aimed_circle_ink_mult 미사용)
	var total_len := 0.0
	for s: StrokeData in strokes:
		total_len += _ink_length(s)
	var ink := balance.ink_per_stroke_length * total_len
	ink *= 1.0 + balance.circle_radius_ink_mult * d.circle_radius
	d.ink_cost = {INK_ID: maxi(1, ceili(ink))}

	# 마나 = 룬 + **진 규모** + 발수 축 × 종이 감면 (v1.6, GDD §5 갱신).
	# 진이 위력·크기·사거리를 전부 주므로(TECH_SPEC §4.0) 시전 비용에도 진 축이 붙는다 —
	# 잉크만 물리면 큰 진이 일방적으로 우월해진다. 삼중 처벌은 아니다: 진은 제작 1회·시전 1회
	var rune_idx := int(d.rune_type)
	var mana_base := 8.0
	if rune_idx >= 0 and rune_idx < balance.rune_mana_base.size():
		mana_base = balance.rune_mana_base[rune_idx]
	var discount := clampf(float(paper_params.get("mana_discount", 0.0)), 0.0, 1.0)
	d.mana_cost = (
		mana_base
		+ balance.circle_mana_mult * d.circle_radius
		+ balance.mana_per_arrow * float(arrows.size())
	) * (1.0 - discount)

	# 종이 등급: 내구 보정·등급 기록 (GDD §5). 스키마 기본값에서 매번 재계산 — into 재사용 시 비누적
	d.paper_grade = paper_grade
	d.durability_max = _base_durability_max + int(paper_params.get("durability_bonus", 0))
	# 새 도안만 만땅으로 시작한다. **재빌드(into)는 닳은 내구를 그대로 안고 간다** —
	# 안 그러면 이미 쓴 도안에 획 하나 덧그어 잉크 없이 완전 수리하는 우회가 생긴다
	# (수리 경제는 작업대 소관 — 모듈 D). 상한이 줄면 현재값도 함께 잘린다
	if into == null:
		d.durability = d.durability_max
	else:
		d.durability = mini(d.durability, d.durability_max)

	# 진이 한 종류뿐이라 종류 표기가 없다
	d.display_name = "%s ×%d" % [RUNE_NAMES.get(int(d.rune_type), "?"), arrows.size()]
	return d


## 화살표 획 → ArrowData.path (시작점 = 원점, +X = direction인 로컬 경로, 캔버스 단위).
## 좌표 변환은 먹선 렌더와 같은 core 함수를 그대로 쓴다 (TECH_SPEC §4.4) — 그려진 획과
## 날아가는 궤적이 어긋나지 않으려면 변환이 한 지점이어야 한다. 직선 화살표에도 채운다
## (소비 측이 곡선/직선을 분기하지 않도록 — 거의 직선인 path가 들어갈 뿐).
static func _arrow_path(stroke: StrokeData) -> PackedVector2Array:
	if stroke == null or stroke.points.size() < 2:
		return PackedVector2Array()
	var local := InkRender.arrow_local_points(stroke, 1.0)
	if local.size() < 2:
		return PackedVector2Array()
	return Recognizer.resample(local, ARROW_PATH_POINTS)


static func rune_name(rune_type: int) -> String:
	return RUNE_NAMES.get(rune_type, "?")


## 획 하나의 잉크 게이지 사용량 — 종이 ink_capacity 상한 판정 기준 (TECH_SPEC §4.1).
## 원 크기·조준진 가산은 경제 비용(ink_cost)에만 붙고, 종이 위 물리 잉크량에는 넣지 않는다.
static func stroke_ink_units(s: StrokeData, balance: BalanceData) -> float:
	return _ink_length(s) * balance.ink_per_stroke_length


## 획 잉크량 = 경로 길이 × 평균 필압 (잉크 = Σ 길이×폭, TECH_SPEC §6)
static func _ink_length(s: StrokeData) -> float:
	var plen := Recognizer.path_length(s.points)
	if s.pressures.is_empty():
		return plen
	var sum := 0.0
	for p in s.pressures:
		sum += p
	return plen * clampf(sum / float(s.pressures.size()), 0.15, 1.5)
