extends RefCounted
## F6 시험대 카탈로그 — **예시 마법진을 손으로 구성**해 바로 쏘게 한다 (2026-07-15).
## 그리기 없이 복합(룬 N개)·중첩(재귀)을 눈으로 확인하는 통로. 인식기를 태우지 않고 룬·자식을
## **직접 지정**하므로 견고하다 (합성 획 인식 실패로 예시가 조용히 망가지지 않는다).
## 획(strokes)은 **먹선 렌더 전용** — 역할만 맞춰 두면 InkRender가 탄의 몸으로 그린다.
## 사용: const ExampleDesigns := preload("res://src/core/example_designs.gd")

const RuneTemplates := preload("res://src/drawing/rune_templates.gd")

## 캔버스 정규 좌표 — InkRender는 CIRCLE 획을 찾아 그 중심·반지름으로 탄을 앉힌다.
const C := Vector2(0.5, 0.5)


# ─────────────────────────── 획 합성 (렌더 전용) ───────────────────────────

static func _circle_stroke(center: Vector2, r: float) -> StrokeData:
	var pts := PackedVector2Array()
	for i in 48:
		var a := -PI / 2.0 + TAU * 0.98 * float(i) / 47.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	var s := StrokeData.new()
	s.points = pts
	s.role = Enums.StrokeRole.CIRCLE
	return s


static func _rune_stroke(rune_type: int, center: Vector2, scale: float) -> StrokeData:
	var canon := RuneTemplates.canonical(rune_type)   # 원점 중심·span 1.0
	var pts := PackedVector2Array()
	for p: Vector2 in canon:
		pts.append(center + p * scale)
	var s := StrokeData.new()
	s.points = pts
	s.role = Enums.StrokeRole.RUNE
	return s


## 앞(위)으로 곧게 뻗는 기본 화살표 = 착탄 시 앞으로 가는 충격파 하나
static func _front_arrow(origin: Vector2 = Vector2(0.0, -1.0)) -> ArrowData:
	var a := ArrowData.new()
	a.glyph = Enums.GlyphType.BASIC
	a.reach = 1.0
	a.direction = -PI / 2.0     # 캔버스 위쪽(UP_AXIS) = 탄이 가는 쪽
	a.origin = origin           # 진 반지름 정규화 (앞 가장자리)
	return a


# ─────────────────────────── 도안 조립 (직접) ───────────────────────────

static func _mk(name: String, radius: float, runes: Array[RuneInstance],
		strokes: Array[StrokeData], arrows: Array[ArrowData],
		children: Array[SpellDesign]) -> SpellDesign:
	var d := SpellDesign.new()
	d.id = StringName("example_%s" % name)
	d.display_name = name
	d.circle_radius = clampf(radius, 0.0, 1.0)
	d.runes = runes
	# primary(스칼라) = fill 최대 룬 — 탄 색·먹선·약점 기준 (build과 같은 규칙)
	var primary: RuneInstance = runes[0]
	for r: RuneInstance in runes:
		if r.fill > primary.fill:
			primary = r
	d.rune_type = primary.type as Enums.RuneType
	d.rune_fill = primary.fill
	d.rune_accuracy = primary.accuracy
	d.arrows = arrows
	d.strokes = strokes
	d.children = children
	d.mana_cost = 0.0        # 시험대는 무한 자원
	d.durability_max = 999
	d.durability = 999
	return d


static func _rune(rune_type: int, fill: float) -> RuneInstance:
	return RuneInstance.make(rune_type, fill, 1.0)


## 카탈로그 — {name, design} 배열. 순서 = F6 숫자키 1..N.
static func catalog() -> Array:
	var out: Array = []

	# 1) 단일 불 — 기준
	out.append({"name": "단일 불", "design": _mk(
		"단일 불", 0.5,
		[_rune(Enums.RuneType.FIRE, 0.6)],
		[_circle_stroke(C, 0.25), _rune_stroke(Enums.RuneType.FIRE, C, 0.18)],
		[_front_arrow()],
		[] as Array[SpellDesign])})

	# 2) 복합 불+물 — 한 탄이 BURN·WET 둘 다 (수증기의 씨앗)
	out.append({"name": "복합 불+물", "design": _mk(
		"복합 불+물", 0.5,
		[_rune(Enums.RuneType.FIRE, 0.6), _rune(Enums.RuneType.WATER, 0.4)],
		[_circle_stroke(C, 0.25),
			_rune_stroke(Enums.RuneType.FIRE, C + Vector2(-0.10, 0.0), 0.12),
			_rune_stroke(Enums.RuneType.WATER, C + Vector2(0.10, 0.0), 0.12)],
		[_front_arrow()],
		[] as Array[SpellDesign])})

	# 3) 복합 불+충격 — 화상 + 넉백을 한 탄에
	out.append({"name": "복합 불+충격", "design": _mk(
		"복합 불+충격", 0.55,
		[_rune(Enums.RuneType.FIRE, 0.5), _rune(Enums.RuneType.IMPACT, 0.5)],
		[_circle_stroke(C, 0.26),
			_rune_stroke(Enums.RuneType.FIRE, C + Vector2(-0.10, 0.0), 0.12),
			_rune_stroke(Enums.RuneType.IMPACT, C + Vector2(0.10, 0.0), 0.12)],
		[_front_arrow()],
		[] as Array[SpellDesign])})

	# 4) 중첩 충격→불 — 껍질(충격)이 날아가 착탄점에서 불을 전개 (재귀 깊이 1)
	var inner_fire := _mk(
		"안쪽 불", 0.28,
		[_rune(Enums.RuneType.FIRE, 0.7)],
		[_circle_stroke(C, 0.14), _rune_stroke(Enums.RuneType.FIRE, C, 0.10)],
		[_front_arrow()],
		[] as Array[SpellDesign])
	out.append({"name": "중첩 충격→불", "design": _mk(
		"중첩 충격→불", 0.6,
		[_rune(Enums.RuneType.IMPACT, 0.6)],
		[_circle_stroke(C, 0.28),
			_rune_stroke(Enums.RuneType.IMPACT, C + Vector2(0.0, -0.16), 0.10)],
		[_front_arrow()],
		[inner_fire] as Array[SpellDesign])})

	# 5) 중첩 껍질 + 복합 안쪽 (불+물) — 착탄점에서 수증기가 피어오르는 그림
	var inner_steam := _mk(
		"안쪽 불+물", 0.30,
		[_rune(Enums.RuneType.FIRE, 0.5), _rune(Enums.RuneType.WATER, 0.5)],
		[_circle_stroke(C, 0.15),
			_rune_stroke(Enums.RuneType.FIRE, C + Vector2(-0.06, 0.0), 0.08),
			_rune_stroke(Enums.RuneType.WATER, C + Vector2(0.06, 0.0), 0.08)],
		[_front_arrow()],
		[] as Array[SpellDesign])
	out.append({"name": "중첩 바람껍질→불+물", "design": _mk(
		"중첩 바람껍질→불+물", 0.62,
		[_rune(Enums.RuneType.WIND, 0.6)],
		[_circle_stroke(C, 0.29),
			_rune_stroke(Enums.RuneType.WIND, C + Vector2(0.0, -0.17), 0.10)],
		[_front_arrow()],
		[inner_steam] as Array[SpellDesign])})

	return out
