extends RefCounted
## 인식 결과 → SpellDesign 조립 + 비용 계산 (GDD §4.4, §5 비용 축 분리).
## 잉크 = 그린 총량(길이×필압) + 원 크기·조준진 가산 / 마나 = 룬 + 발수 축.
## 사용: const DesignBuilder := preload("res://src/drawing/design_builder.gd")

const Recognizer := preload("res://src/drawing/recognizer.gd")

const INK_ID := &"ink_basic"

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
			Enums.StrokeRole.TAIL:
				if not parts.has("tail"):
					parts["tail"] = {"aim_axis": res.aim_axis, "stroke": stroke}
					ctx["has_tail"] = true
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
static func build(parts: Dictionary, balance: BalanceData, into: SpellDesign = null) -> SpellDesign:
	var d := into
	if d == null:
		d = SpellDesign.new()
		_seq += 1
		d.id = StringName("design_%d_%d" % [Time.get_ticks_msec(), _seq])

	var aimed: bool = parts.has("tail")
	d.circle_type = Enums.CircleType.AIMED if aimed else Enums.CircleType.FIXED
	var circle: Dictionary = parts.circle
	# 스키마의 circle_radius(0..1)는 "캔버스를 꽉 채우는 원(반지름 0.5) = 1.0" 기준
	d.circle_radius = clampf(float(circle.radius) / 0.5, 0.0, 1.0)
	d.aim_axis = float(parts.tail.aim_axis) if aimed else 0.0
	d.rune_type = parts.rune.type
	d.rune_accuracy = clampf(
		maxf(float(parts.rune.accuracy_raw), balance.accuracy_floor), 0.0, 1.0)

	var arrows: Array[ArrowData] = []
	var radius_cu := maxf(float(circle.radius), 1e-6)  # 캔버스 단위 원 반지름
	for a: Dictionary in parts.arrows:
		var ad := ArrowData.new()
		var abs_dir := float(a.direction)
		ad.direction = wrapf(abs_dir - d.aim_axis, -PI, PI) if aimed else abs_dir
		ad.magnitude = clampf(float(a.length) / balance.arrow_full_length, 0.05, 1.0)
		# origin은 진 반지름 = 1.0 정규화 (가장자리 = 1.0, TECH_SPEC §4)
		ad.origin = (Vector2(a.start) - Vector2(circle.center)) / radius_cu
		arrows.append(ad)
	d.arrows = arrows

	var strokes: Array[StrokeData] = []
	strokes.assign(parts.strokes_ordered)
	d.strokes = strokes

	# 잉크: 총 획 길이(×필압) 비례 + 원 크기 가산 + 조준진 가산 (GDD §4.1, §4.4)
	var total_len := 0.0
	for s: StrokeData in strokes:
		total_len += _ink_length(s)
	var ink := balance.ink_per_stroke_length * total_len
	ink *= 1.0 + balance.circle_radius_ink_mult * d.circle_radius
	if aimed:
		ink *= balance.aimed_circle_ink_mult
	d.ink_cost = {INK_ID: maxi(1, ceili(ink))}

	# 마나: 룬 + 발수 축 (원 크기와 무관 — 같은 축 삼중 처벌 금지, GDD §5)
	var rune_idx := int(d.rune_type)
	var mana_base := 8.0
	if rune_idx >= 0 and rune_idx < balance.rune_mana_base.size():
		mana_base = balance.rune_mana_base[rune_idx]
	d.mana_cost = mana_base + balance.mana_per_arrow * float(arrows.size())

	var kind := "조준진" if aimed else "고정진"
	d.display_name = "%s %s ×%d" % [RUNE_NAMES.get(int(d.rune_type), "?"), kind, arrows.size()]
	return d


static func rune_name(rune_type: int) -> String:
	return RUNE_NAMES.get(rune_type, "?")


## 획 잉크량 = 경로 길이 × 평균 필압 (잉크 = Σ 길이×폭, TECH_SPEC §6)
static func _ink_length(s: StrokeData) -> float:
	var plen := Recognizer.path_length(s.points)
	if s.pressures.is_empty():
		return plen
	var sum := 0.0
	for p in s.pressures:
		sum += p
	return plen * clampf(sum / float(s.pressures.size()), 0.15, 1.5)
