extends RefCounted
## 인식 결과 → SpellDesign 조립 + 비용 계산 (GDD §4.4, §5 비용 축 분리).
## 잉크 = 그린 총량(길이×필압) + 진 크기 가산 / 마나 = 룬 + **진 규모** + **룬 농도** + 발수 축 (v1.7).
## 역할 축 (TECH_SPEC §4.0): 진 = 규모 / 룬 = **속성 + 농도** / 문양 = **발동 방식 + 세기**.
## v1.9: 문양이 **글자**(glyph)와 **세기**(reach)를 갖는다. reach = 획 길이 ÷ 진 반지름 —
## rune_fill과 정확히 대칭이라 진을 키우면 같은 문양도 배율이 줄고, 마나도 그만큼 더 문다.
## v1.7: 룬에 농도 축(`rune_fill` — 룬이 진을 얼마나 채우는가)이 붙었다. $1 인식기가 크기를
## 정규화해 버리는 탓에 룬을 크게 그리든 작게 그리든 결과가 같았고, 룬 그리기가 4지선다에
## 불과했다. 이제 진을 꽉 채운 룬은 깊이 물들고(상태이상 세기 ↑) 구석에 작게 그린 룬은 옅게 스친다.
## 종이 등급(paper_params)은 호출자가 ItemDef.params를 직접 넘긴다 — Db 없이도 테스트 가능.
## 사용: const DesignBuilder := preload("res://src/drawing/design_builder.gd")

const Recognizer := preload("res://src/drawing/recognizer.gd")
const InkRender := preload("res://src/core/ink_render.gd")

const INK_ID := &"ink_basic"

## ArrowData.path 점 개수 — 저장 크기·투사체 추종 계산 비용과 곡률 보존의 절충
const ARROW_PATH_POINTS := 14

## 캔버스 위쪽 = **앞**. 🔴 **core가 소유한다** (`InkRender.UP_AXIS`) — 이 값이 모듈마다
## 복제되면 세션 7의 "90도 틀어짐"이 재발한다. 여기서는 별칭으로만 둔다.
##
## v2.1에서 의미가 바뀌었다: ~~조준 방향~~ (v2.0에서 발사각이 지팡이로 갔다) →
## **충격파 방향의 기준** (종이 위쪽 = 탄이 가는 쪽. TECH_SPEC §4.0-b)
const UP_AXIS := InkRender.UP_AXIS

## SpellDesign 스키마 기본 내구 — into 재사용 시 durability_bonus가 누적되지 않도록 기준값
static var _base_durability_max: int = SpellDesign.new().durability_max

const RUNE_NAMES := {
	Enums.RuneType.FIRE: "불△",
	Enums.RuneType.IMPACT: "충격>",
	Enums.RuneType.WATER: "물~",
	Enums.RuneType.WIND: "바람◎",
}

const GLYPH_NAMES := {
	Enums.GlyphType.BASIC: "기본",
	Enums.GlyphType.BOUNCE: "팅김⚡",
	Enums.GlyphType.HOMING: "유도∿",
	Enums.GlyphType.PIERCE: "관통‖",
}

## 표기 순서 (Dictionary 순회 순서에 이름을 맡기지 않는다)
const GLYPH_ORDER: Array[int] = [
	Enums.GlyphType.BASIC, Enums.GlyphType.BOUNCE,
	Enums.GlyphType.HOMING, Enums.GlyphType.PIERCE,
]

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
					# 뻗은 거리 — reach(세기 축)의 원료. **총연장(length)과 다른 값이다.**
					# 스탬프(locked) 엔트리의 옛 result엔 없으므로 총연장으로 폴백 (구세이브 호환)
					"extent": float(res.get("extent", res.length)),
					"start": res.start,
					# v1.9 문양 글자 (GDD §4.3). 인식기가 못 읽었으면 BASIC이 들어 있다 —
					# 폴백이지 실패가 아니다. 스탬프(locked) 엔트리의 옛 result엔 키가 없으므로 기본값
					"glyph": int(res.get("glyph", Enums.GlyphType.BASIC)),
					"glyph_score": float(res.get("glyph_score", 0.0)),
					"stroke": stroke,
				})
			_:
				parts.extras.append(stroke)
	return parts


## 도안 완성 조건: 진 1 + 룬 1 + 화살표 1+ (GDD §4)
static func is_complete(parts: Dictionary) -> bool:
	return parts.has("circle") and parts.has("rune") and not parts.arrows.is_empty()


# ─────────────────────── 중첩 진 (재귀, 2026-07-15 — TRUTH §4) ───────────────────────
# **진 안 진 = 재귀.** 여러 원을 그리면 "감싸는 가장 작은 진"으로 트리를 짠다 — 바깥 진이 껍질,
# 안쪽 진들이 그 껍질이 열릴 때 전개되는 내용물. 각 원 노드는 기존 `build()`가 먹는 `parts` 모양
# 그대로라, **build를 노드마다 재귀 호출**하면 SpellDesign 트리가 나온다. 원이 하나뿐이면 루트
# 하나짜리 트리 = `classify_entries`와 정확히 같은 결과 (하위호환).
#
# **핵심 수법**: 룬/문양 판정을 다시 발명하지 않는다. 각 획을 소속 원의 컨텍스트로 기존
# `Recognizer.classify_stroke`에 통과시키면, "진 안에 머물면 룬 / 뚫고 나가면 화살표"가 원마다
# 그대로 성립한다. 인식 규칙이 한 지점(recognizer)에 남는다.

## 원이 점을 감싸는가 (경계에 탈출 여유 ARROW_ESCAPE_R만큼 준다 — 인식기 탈출 판정과 대칭)
static func _circle_contains(center: Vector2, radius: float, p: Vector2) -> bool:
	return center.distance_to(p) <= radius * Recognizer.ARROW_ESCAPE_R


## 이 노드에 이미 그 종류 룬이 있나 (복합 — 같은 종류 중복 금지)
static func _node_has_rune_type(node: Dictionary, rtype: int) -> bool:
	for re: Dictionary in node.runes:
		if int(re.type) == rtype:
			return true
	return false


## entries → 원 노드 트리(루트 배열). 각 노드는 build()가 먹는 parts + {"children": [노드…],
## "radius_cu": 원 반지름(캔버스 단위)}. 원이 없으면 빈 배열.
##
## 알고리즘: (1) 획을 원/비원으로 가른다(detect_circle은 ctx 무관·신뢰 가능) (2) 원들을 감싸기로
## 트리화 — 각 원의 부모 = 그를 감싸는 가장 작은 더 큰 원 (3) 비원 획은 소속 원을 찾아
## 그 원 컨텍스트로 재인식 → 룬이면 그 원의 룬, 화살표면 그 원의 화살표.
static func assemble_tree(entries: Array[Dictionary]) -> Array[Dictionary]:
	var circles: Array[Dictionary] = []
	var others: Array[StrokeData] = []
	for e in entries:
		var stroke: StrokeData = e.stroke
		var c := Recognizer.detect_circle(stroke.points)
		if c.is_circle:
			var node := {
				"circle": {"center": c.center, "radius": c.radius, "stroke": stroke},
				"radius_cu": maxf(float(c.radius), 1e-6),
				"runes": [], "arrows": [], "extras": [], "strokes_ordered": [stroke],
				"children": [],
			}
			stroke.role = Enums.StrokeRole.CIRCLE
			circles.append(node)
		else:
			others.append(stroke)

	if circles.is_empty():
		return []

	# 감싸기 트리 — 각 원의 부모 = 그 중심을 감싸는 **가장 작은 더 큰 원**
	var roots: Array[Dictionary] = []
	for i in circles.size():
		var me: Dictionary = circles[i]
		var mc: Dictionary = me.circle
		var parent: Dictionary = {}
		var parent_r := INF
		for j in circles.size():
			if j == i:
				continue
			var other: Dictionary = circles[j]
			var oc: Dictionary = other.circle
			if float(oc.radius) <= float(mc.radius):
				continue  # 부모는 나보다 커야 한다 (같은 크기 두 원은 형제)
			if not _circle_contains(oc.center, float(oc.radius), mc.center):
				continue
			if float(oc.radius) < parent_r:
				parent_r = float(oc.radius)
				parent = other
		if parent.is_empty():
			roots.append(me)
		else:
			(parent.children as Array).append(me)

	# 비원 획 배정 — 룬은 감싸는 가장 작은 진, 화살표는 뚫고 나온 가장 바깥 진
	for stroke in others:
		var start := stroke.points[0]
		# 시작점을 감싸는 원들, 작은 것부터
		var cand: Array[Dictionary] = []
		for node: Dictionary in circles:
			var cc: Dictionary = node.circle
			if _circle_contains(cc.center, float(cc.radius), start):
				cand.append(node)
		cand.sort_custom(func(a, b): return float(a.circle.radius) < float(b.circle.radius))
		if cand.is_empty():
			continue  # 어느 진에도 안 걸린 획 — 버린다 (DECOR)
		# 머무는(탈출 안 하는) 가장 작은 진 = 룬 소속. 다 뚫으면 가장 바깥 = 화살표 소속
		var owner: Dictionary = {}
		for node: Dictionary in cand:
			var cc: Dictionary = node.circle
			if not Recognizer.detect_escape(stroke.points, cc.center, float(cc.radius)):
				owner = node
				break
		if owner.is_empty():
			owner = cand.back()  # 전부 뚫음 → 화살표는 가장 바깥 껍질의 것
		_assign_stroke_to_node(stroke, owner)

	return roots


## 획 하나를 소속 원 노드에 넣는다 — 그 원 컨텍스트로 재인식해 룬/문양을 가른다.
static func _assign_stroke_to_node(stroke: StrokeData, node: Dictionary) -> void:
	var cc: Dictionary = node.circle
	var ctx := {
		"has_circle": true,
		"circle_center": cc.center,
		"circle_radius": float(cc.radius),
	}
	var res := Recognizer.classify_stroke(stroke.points, ctx)
	stroke.role = int(res.role)
	(node.strokes_ordered as Array).append(stroke)
	match int(res.role):
		Enums.StrokeRole.RUNE:
			# 🔴 복합 — 서로 다른 종류는 여럿 담는다. **같은 종류는 하나뿐**(농도 뻥튀기 금지).
			if _node_has_rune_type(node, int(res.rune_type)):
				stroke.role = Enums.StrokeRole.DECOR
				(node.extras as Array).append(stroke)
			else:
				var re := {
					"type": res.rune_type,
					"accuracy_raw": res.score,
					"stroke": stroke,
				}
				(node.runes as Array).append(re)
				if not node.has("rune"):
					node["rune"] = re   # primary = 첫 룬 (build이 fill 최대로 다시 고른다)
		Enums.StrokeRole.ARROW:
			(node.arrows as Array).append({
				"direction": res.direction,
				"length": res.length,
				"extent": float(res.get("extent", res.length)),
				"start": res.start,
				"glyph": int(res.get("glyph", Enums.GlyphType.BASIC)),
				"glyph_score": float(res.get("glyph_score", 0.0)),
				"stroke": stroke,
			})
		_:
			(node.extras as Array).append(stroke)


## 노드 트리 → SpellDesign 트리 (재귀). 각 노드를 기존 build()로 짓고 children을 이어 붙인다.
## 룬이 없는 노드(껍질만 있고 속성 없음)는 아직 미지원 — null 반환(호출자가 스킵). 미완 노드도 같다.
static func build_tree(node: Dictionary, balance: BalanceData,
		paper_grade: int = 1, paper_params: Dictionary = {}) -> SpellDesign:
	if not node.has("rune"):
		return null
	var d := build(node, balance, null, paper_grade, paper_params)
	var kids: Array[SpellDesign] = []
	for child: Dictionary in node.children:
		var cd := build_tree(child, balance, paper_grade, paper_params)
		if cd != null:
			kids.append(cd)
	d.children = kids
	return d


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
	var radius_cu := maxf(float(circle.radius), 1e-6)  # 캔버스 단위 원 반지름
	# 스키마의 circle_radius(0..1)는 "캔버스를 꽉 채우는 원(반지름 0.5) = 1.0" 기준
	d.circle_radius = clampf(float(circle.radius) / 0.5, 0.0, 1.0)
	# 🔴 복합 룬 (N개, TRUTH §4) — parts.runes(멀티) 우선, 없으면 parts.rune(단일·테스트 폴백) 하나.
	# 각 룬의 농도(fill)는 **자기 획 ÷ 이 진**이라 진을 키우면 같은 룬도 옅어진다 (v1.7).
	# 획이 없는 도안(샘플·구세이브)은 스키마 기본값(중간 농도)을 그대로 둔다.
	var rune_src: Array = parts.get("runes", [])
	if rune_src.is_empty() and parts.has("rune"):
		rune_src = [parts.rune]
	var runes: Array[RuneInstance] = []
	for re: Dictionary in rune_src:
		var acc := clampf(maxf(float(re.get("accuracy_raw", 1.0)), balance.accuracy_floor), 0.0, 1.0)
		var fill := 0.5
		var rs := re.get("stroke") as StrokeData
		if rs != null and rs.points.size() >= 2:
			fill = rune_fill_of(rs, radius_cu)
		elif re.has("fill"):
			fill = clampf(float(re.fill), 0.0, 1.0)
		runes.append(RuneInstance.make(int(re.type), fill, acc))
	d.runes = runes
	# primary(스칼라) = fill 최대 룬 — 탄 색·먹선·약점·마나 기준. 단일 룬이면 그 하나 = 지금과 동일.
	if not runes.is_empty():
		var primary: RuneInstance = runes[0]
		for r: RuneInstance in runes:
			if r.fill > primary.fill:
				primary = r
		d.rune_type = primary.type as Enums.RuneType
		d.rune_fill = primary.fill
		d.rune_accuracy = primary.accuracy

	var arrows: Array[ArrowData] = []
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
		ad.glyph = int(a.get("glyph", Enums.GlyphType.BASIC)) as Enums.GlyphType
		var arrow_stroke := a.get("stroke") as StrokeData
		# v1.9 세기 축 — **룬의 rune_fill과 정확히 대칭**이다: 진 대비 비율이라 같은 문양도
		# 진이 크면 reach가 작아진다. magnitude(원시 길이·잉크·렌더용)와는 **다른 값**이다.
		# 🔴 **뻗은 거리(extent)로 잰다 — 총연장이 아니다** (사용자 확정). 총연장으로 재면
		# "얼마나 멀리 뻗었나"가 아니라 "얼마나 구불구불한가"를 재게 되어, 짧게 그려도 지그재그
		# 진폭만 키우면 최대 사거리·최대 반사를 공짜로 받았다 (InkRender.arrow_extent 주석 참조).
		# 획이 없는 도안(샘플·구세이브)은 스키마 기본값(1.0 = 기준 배율)을 그대로 둔다
		if arrow_stroke != null and arrow_stroke.points.size() >= 2:
			# 획이 있으면 획에서 직접 잰다 — parts를 손으로 조립하는 호출자(테스트·스탬프)가
			# extent를 안 넣어도 옳은 값이 나온다. 키가 있으면 그걸 믿는다 (인식기가 이미 쟀다)
			var extent := float(a.get("extent", 0.0))
			if extent <= 0.0:
				extent = InkRender.arrow_extent(arrow_stroke.points)
			ad.reach = clampf(extent / radius_cu,
				balance.glyph_reach_min, balance.glyph_reach_max)
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

	# 잉크 = **통에서 실제로 나온 양** (v1.8, GDD §4.4 — 사용자 확정).
	# "획"이라는 추상 단위가 아니라 종이에 올라간 먹의 양이다: 지나간 거리 × 그 지점의 붓 굵기.
	# **가산·할증을 붙이지 않는다.** v1.7까지 있던 진 크기 가산(최대 3배)은 **이중 과금**이었다 —
	# 큰 진은 둘레가 길어서 **이미** 잉크를 더 먹는다 (반지름 2배 → 둘레 2배 → 잉크 2배).
	# 그래서 잉크는 **숫자 하나**다: 여기서 쓰는 값과 종이 상한(stroke_ink_units)이 같은 값이다.
	# v1.7까지는 둘이 달랐다 (상한은 물리량, 비용은 할증 붙은 값) — 같은 이름의 두 숫자였다
	var ink := 0.0
	for s: StrokeData in strokes:
		ink += stroke_ink_units(s, balance)
	d.ink_cost = {INK_ID: maxi(1, ceili(ink))}

	# 마나 = 룬 속성 + **진 규모** + **룬 농도** + 발수 축 × 종이 감면 (v1.7, GDD §5 갱신).
	# 진이 위력·크기·사거리를 전부 주므로(TECH_SPEC §4.0) 시전 비용에도 진 축이 붙는다 —
	# 잉크만 물리면 큰 진이 일방적으로 우월해진다. 삼중 처벌은 아니다: 진은 제작 1회·시전 1회.
	# 농도(rune_fill)도 같은 논리다: 공짜면 "룬은 언제나 최대한 크게"가 유일한 정답이 된다.
	# 잉크(제작)는 이미 그린 총량으로 물고 있으니 마나(시전)에도 물린다
	var rune_idx := int(d.rune_type)
	var mana_base := 8.0
	if rune_idx >= 0 and rune_idx < balance.rune_mana_base.size():
		mana_base = balance.rune_mana_base[rune_idx]
	var discount := clampf(float(paper_params.get("mana_discount", 0.0)), 0.0, 1.0)
	# v1.9 문양 축: 발수(mana_per_arrow)에 더해 **각 탄이 얼마나 멀리 가는가**(reach)를 문다.
	# 공짜면 "문양은 언제나 최대한 길게"가 유일한 정답이 된다 (GDD §4.3·§5) — 농도와 같은 논리다.
	# 기준 배율(reach=1.0)인 구세이브·샘플 도안도 t>0이라 조금 문다: reach는 0이 아니라 1이 기본이다
	var reach_t := 0.0
	for ad: ArrowData in arrows:
		reach_t += clampf(inverse_lerp(
			balance.glyph_reach_min, balance.glyph_reach_max, ad.reach), 0.0, 1.0)
	# 농도 마나는 **룬마다** 문다 — 복합이면 룬 하나 더 얹을 때마다 시전 비용이 오른다 (공짜면
	# "룬은 언제나 많이"가 정답). 단일 룬이면 Σfill = primary fill이라 기존과 정확히 같다.
	var fill_sum := 0.0
	for r: RuneInstance in runes:
		fill_sum += r.fill
	if runes.is_empty():
		fill_sum = d.rune_fill
	d.mana_cost = (
		mana_base
		+ balance.circle_mana_mult * d.circle_radius
		+ balance.rune_density_mana_mult * fill_sum
		+ balance.mana_per_arrow * float(arrows.size())
		+ balance.glyph_reach_mana_mult * reach_t
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

	# 진이 한 종류뿐이라 종류 표기가 없다. 문양이 섞여 있으면 **구성**을 보여준다 —
	# "발수 3"과 "관통 1 + 팅김 2"는 전혀 다른 도안인데 이름이 같으면 슬롯에서 구별이 안 된다
	d.display_name = "%s %s" % [RUNE_NAMES.get(int(d.rune_type), "?"), glyph_summary(arrows)]
	return d


## 문양 구성 표기 — 전부 기본이면 발수만("×3"), 글자가 섞이면 종류별로("팅김⚡×2 관통‖×1").
static func glyph_summary(arrows: Array[ArrowData]) -> String:
	var counts := {}
	for ad: ArrowData in arrows:
		counts[int(ad.glyph)] = int(counts.get(int(ad.glyph), 0)) + 1
	if counts.size() <= 1 and counts.has(int(Enums.GlyphType.BASIC)):
		return "×%d" % arrows.size()
	var parts: Array[String] = []
	for g: int in GLYPH_ORDER:
		if counts.has(g):
			parts.append("%s×%d" % [GLYPH_NAMES.get(g, "?"), int(counts[g])])
	return " ".join(parts)


static func glyph_name(glyph_type: int) -> String:
	return GLYPH_NAMES.get(glyph_type, "?")


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


## 룬 농도 (v1.7, TECH_SPEC §4.0) — 룬이 진을 얼마나 채우는가. 0..1.
## 룬 반경 = **획 무게중심에서 가장 먼 점까지의 거리** (외접 반경).
##
## **반드시 회전 불변이어야 한다.** $1 인식기는 회전 불변이라 룬을 돌려 그려도 같은 룬으로
## 인식된다 — 그런데 농도가 회전에 따라 흔들리면 **같은 룬인데 세기만 조용히 달라진다.**
## 플레이어는 이유를 알 수 없고, 알아도 "룬을 축에 맞춰 그리기"라는 숨은 최적 플레이가 생긴다.
##
## 그래서 축 정렬 bbox(AABB)는 **못 쓴다** — AABB는 회전하면 변한다. 실측: 물~처럼 가늘고 긴
## 획을 45도로 눕히면 긴 변이 L → L/√2로 줄어 **농도가 0.80 → 0.57로 29% 증발했다**.
## 무게중심 최대거리는 회전해도 그대로다. 가늘고 긴 획도 과대평가하지 않는다(길이 L → 반경 L/2,
## AABB 긴 변과 같은 값) — AABB의 장점은 전부 가져가면서 회전 결함만 없앤다.
##
## 인식기가 "룬은 진 안에 머문다"로 가르므로(recognizer ARROW_ESCAPE_R) 비율은 자연히 0..1에
## 갇힌다 — 인위적 밴드·리맵 없이 clamp만 한다.
static func rune_fill_of(rune_stroke: StrokeData, circle_radius_cu: float) -> float:
	if rune_stroke == null or rune_stroke.points.size() < 2 or circle_radius_cu <= 1e-6:
		return 0.0
	var centroid := Vector2.ZERO
	for p: Vector2 in rune_stroke.points:
		centroid += p
	centroid /= float(rune_stroke.points.size())
	var rune_radius := 0.0
	for p: Vector2 in rune_stroke.points:
		rune_radius = maxf(rune_radius, centroid.distance_to(p))
	return clampf(rune_radius / circle_radius_cu, 0.0, 1.0)


static func rune_name(rune_type: int) -> String:
	return RUNE_NAMES.get(rune_type, "?")


## 획 하나가 종이에 올린 **먹의 양** (v1.8, GDD §4.4 — 사용자 확정).
## **이 값 하나가 종이 상한 판정에도, 제작 비용(ink_cost)에도 그대로 쓰인다** —
## v1.7까지는 비용에만 진 크기 할증이 따로 붙어 **같은 이름의 두 숫자**가 돌아다녔다.
static func stroke_ink_units(s: StrokeData, balance: BalanceData) -> float:
	return _ink_amount(s) * balance.ink_per_stroke_length


## 통에서 나온 먹의 양 = **∫ 굵기 ds** — 구간 길이 × 그 구간의 붓 굵기를 전부 더한다.
##
## **평균 필압 × 전체 길이로 뭉개지 않는다** (v1.7까지 그랬다). 필압은 획 안에서 변한다 —
## 머물면 굵어지는 누적형이라(drawing_canvas.synth_pressure_step) 한 획에서도 앞은 가늘고 뒤는 굵다.
## 평균으로 뭉개면 "어디서 눌렀는지"가 사라져 **실제로 나온 양이 아니게 된다.**
## 필압 없는 획(스탬프·구세이브)은 굵기 1.0로 본다.
static func _ink_amount(s: StrokeData) -> float:
	var pts := s.points
	if pts.size() < 2:
		return 0.0
	var has_p := s.pressures.size() == pts.size()
	var total := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		var w := 1.0
		if has_p:
			# 구간의 굵기 = 양 끝 필압의 평균 (사다리꼴 적분)
			w = clampf((s.pressures[i - 1] + s.pressures[i]) * 0.5, 0.15, 1.5)
		total += seg * w
	return total
