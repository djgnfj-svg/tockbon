class_name SampleDesigns
## 검증용 샘플 도안 팩토리 — 모듈 B·C·E가 드로잉(A) 완성 전에 사용 (TEAM_PLAN Phase 0-7).
## strokes는 비어 있다: 렌더 시 strokes가 비었으면 파라미터 기반 대체 렌더를 쓸 것.

## 고정진 + 불△ + 8방향 노바
static func nova_fire() -> SpellDesign:
	var d := SpellDesign.new()
	d.id = &"sample_nova_fire"
	d.display_name = "샘플: 불꽃 노바"
	# v1.5: 진은 한 종류다 — 전부 AIMED, 기준축 = 캔버스 위쪽 (GDD §4.1).
	# 노바는 대칭이라 통째로 회전해도 노바다 — 옛 고정진의 역할이 그대로 흡수된다
	d.circle_type = Enums.CircleType.AIMED
	d.aim_axis = -PI / 2.0
	d.circle_radius = 0.7
	d.rune_type = Enums.RuneType.FIRE
	d.rune_accuracy = 0.9
	for i in range(8):
		var a := ArrowData.new()
		a.direction = TAU * float(i) / 8.0
		a.magnitude = 0.4
		d.arrows.append(a)
	d.mana_cost = 24.0
	d.ink_cost = {&"ink_basic": 12}
	return d

## 조준진 + 바람◎ + 3발 산탄 (±15도)
static func aimed_shotgun_wind() -> SpellDesign:
	var d := SpellDesign.new()
	d.id = &"sample_shotgun_wind"
	d.display_name = "샘플: 바람 산탄"
	d.circle_type = Enums.CircleType.AIMED
	d.circle_radius = 0.5
	d.aim_axis = 0.0
	d.rune_type = Enums.RuneType.WIND
	d.rune_accuracy = 0.85
	for offset: float in [-0.26, 0.0, 0.26]:
		var a := ArrowData.new()
		a.direction = offset
		a.magnitude = 0.5
		d.arrows.append(a)
	d.mana_cost = 15.0
	d.ink_cost = {&"ink_basic": 8}
	return d

## 조준진 + 물~ + 대형 단발
static func aimed_lance_water() -> SpellDesign:
	var d := SpellDesign.new()
	d.id = &"sample_lance_water"
	d.display_name = "샘플: 물의 창"
	d.circle_type = Enums.CircleType.AIMED
	d.circle_radius = 0.4
	d.aim_axis = 0.0
	d.rune_type = Enums.RuneType.WATER
	d.rune_accuracy = 0.95
	var a := ArrowData.new()
	a.direction = 0.0
	a.magnitude = 1.0
	d.arrows.append(a)
	d.mana_cost = 12.0
	d.ink_cost = {&"ink_basic": 6}
	return d

static func all() -> Array[SpellDesign]:
	return [nova_fire(), aimed_shotgun_wind(), aimed_lance_water()]
