extends Node2D
## 스펠 발사 시스템 — 모듈 B. 필드 씬에 자식으로 넣기만 하면 되는 자립 노드.
## EventBus.cast_requested 수신 → 내구·마나 검사 → SpellDesign.arrows를 투사체로 컴파일.
##
## **역할 축 (v1.7, TECH_SPEC §4.0)**: 진 = 규모(위력·크기·사거리) / 룬 = 속성+농도(상태이상 종류·세기)
## / 문양 = 방식(방향·기점·발수). 그래서 한 도안의 모든 탄은 **위력·크기·사거리·상태이상이 같고**,
## 문양마다 다른 건 방향·기점뿐이다.
## 문양 길이(ArrowData.magnitude)는 전투 스탯에 **쓰지 않는다** — 소비 금지.
##
## 진 규칙 (GDD §4.1): AIMED=도안 전체가 에임 방향으로 회전 (발사각 = direction + (에임 − aim_axis)).
## FIXED는 구세이브 호환용 — 회전 없이 그린 절대각 그대로.

const ProjectileScene := preload("res://src/spell/projectile.tscn")
const ProjectileScript := preload("res://src/spell/projectile.gd")
const InkRender := preload("res://src/core/ink_render.gd")

## 캐스팅 마법진 연출 (밸런스 수치 아님 — 연출 전용. 선례: src/field/boss_intro.gd)
const CIRCLE_GROW_SEC := 0.14        # 발밑에서 진이 펼쳐지는 시간
const CIRCLE_FADE_SEC := 0.26        # 사그라드는 시간 (총 0.4초 — 연사를 가리지 않는 길이)
const CIRCLE_SCALE_FROM := 0.75      # 펼쳐지기 전 크기
const CIRCLE_Z := -5                 # 지형(-10..-8) 위, 플레이어(0) 아래 — 바닥에 깔린 진

## 배율 수치는 전부 balance.tres 소유: magnitude_damage_base(위력 배율 = base + magnitude,
## mag 0.5 = 1.0배), magnitude_size_min/max(크기 배율), circle_radius_px(오프셋 스케일)
var balance: BalanceData = preload("res://data/balance.tres")

func _ready() -> void:
	EventBus.cast_requested.connect(_on_cast_requested)

func _on_cast_requested(design: SpellDesign, origin: Vector2, aim_dir: Vector2) -> void:
	if design == null or design.arrows.is_empty():
		EventBus.cast_failed.emit(design, Enums.CastFailReason.INVALID)
		return
	# 내구를 마나보다 먼저 검사 — 손상 도안에 마나를 낭비하지 않게
	if design.is_broken():
		EventBus.cast_failed.emit(design, Enums.CastFailReason.BROKEN)
		return
	if not GameState.spend_mana(design.mana_cost):
		EventBus.cast_failed.emit(design, Enums.CastFailReason.NO_MANA)
		return
	_spawn_projectiles(design, origin, aim_dir)
	design.durability -= 1
	EventBus.cast_executed.emit(design, design.mana_cost)

## 위력 = 기본 위력 × **진 규모** × 룬 계수 (TECH_SPEC §4.0).
## v1.6: 규모는 진이 정한다 — 문양 길이(magnitude)는 위력에 물리지 않는다.
## v1.7: **rune_accuracy를 위력에서 뺐다** (축 위반 해소) — 위력은 진의 축이고,
## accuracy는 속성 순도로 옮겨 갔다 (compute_status_power). 룬이 위력을 흔들면 진이 의미를 잃는다.
## 도안 하나에서 나가는 모든 탄이 같은 위력이다 (문양은 방식만 정하므로).
func compute_damage(design: SpellDesign, rune: RuneDef) -> float:
	var rune_coef := rune.base_damage if rune != null else 1.0
	return balance.projectile_base_damage * (balance.circle_damage_base + design.circle_radius) \
		* rune_coef


## 상태이상 세기 — **룬의 농도 축** (v1.7, TECH_SPEC §4.0).
## 세기 = RuneDef.status_power × 농도(rune_fill) × 순도(rune_accuracy, 하한 accuracy_floor).
## 진을 꽉 채운 룬은 깊이 물들고, 구석에 작게 그린 룬은 옅게 스친다. 위력은 건드리지 않는다.
## 규모와 마찬가지로 도안당 하나의 값 — 문양은 방식만 정하므로 탄마다 다르지 않다.
func compute_status_power(design: SpellDesign, rune: RuneDef) -> float:
	if rune == null:
		return 0.0
	var density := lerpf(balance.rune_density_min, balance.rune_density_max,
		clampf(design.rune_fill, 0.0, 1.0))
	var accuracy := maxf(design.rune_accuracy, balance.accuracy_floor)
	return rune.status_power * density * accuracy


## 투사체 크기 배율 — 진 규모 축 (TECH_SPEC §4.0)
func compute_size_scale(design: SpellDesign) -> float:
	return lerpf(balance.circle_size_min, balance.circle_size_max,
		clampf(design.circle_radius, 0.0, 1.0))


## 사거리(투사체 수명, 초) — 진 규모 축. 속도는 고정이므로 수명 = 사거리 (TECH_SPEC §4.0)
func compute_lifetime(design: SpellDesign) -> float:
	return balance.projectile_lifetime_sec * lerpf(balance.circle_range_min, balance.circle_range_max,
		clampf(design.circle_radius, 0.0, 1.0))

func _spawn_projectiles(design: SpellDesign, origin: Vector2, aim_dir: Vector2) -> void:
	var rune: RuneDef = Db.get_rune(design.rune_type)
	if rune == null:
		push_warning("SpellSystem: RuneDef 미등록 (rune_type=%d) — 기본 계수로 발사" % design.rune_type)
	var aim_angle := aim_dir.angle() if aim_dir.length_squared() > 0.0 else 0.0
	# 조준진은 도안 전체가 에임으로 돈다. 고정진은 회전 0 — 진·투사체가 같은 값을 쓴다
	var rotate_by := 0.0
	if design.circle_type == Enums.CircleType.AIMED:
		rotate_by = aim_angle - design.aim_axis
	_spawn_cast_circle(design, origin, rotate_by)

	var scene := ProjectileScene
	if rune != null and rune.projectile_scene != null:
		scene = rune.projectile_scene

	# 규모(진)·농도(룬)는 도안당 한 번만 계산한다 — 문양마다 다르지 않다 (TECH_SPEC §4.0)
	var damage := compute_damage(design, rune)
	var size_scale := compute_size_scale(design)
	var lifetime := compute_lifetime(design)
	var status_power := compute_status_power(design, rune)

	for arrow: ArrowData in design.arrows:
		var world_angle := arrow.direction + rotate_by
		var offset := (arrow.origin * design.circle_radius * balance.circle_radius_px).rotated(rotate_by)
		var proj := scene.instantiate() as ProjectileScript
		if proj == null:
			push_warning("SpellSystem: projectile_scene이 투사체 스크립트가 아님 — 스킵")
			continue
		add_child(proj)
		proj.global_position = origin + offset
		proj.setup(
			damage,
			design.rune_type,
			rune.status if rune != null else Enums.Status.NONE,
			status_power,
			balance.projectile_base_speed,
			world_angle,
			size_scale,
			arrow.path,
			arrow.path_pressures,
			lifetime
		)

## 발밑에 내가 그린 진이 먹선으로 펼쳐졌다 사라진다 (GDD §10.5). 순수 비주얼 — 충돌·물리 없음.
## strokes가 없는 샘플·구세이브 도안이면 build_design이 null → 조용히 스킵.
func _spawn_cast_circle(design: SpellDesign, origin: Vector2, rotate_by: float) -> void:
	var circle := InkRender.build_design(design, InkRender.unit_px(balance), {"bright": true})
	if circle == null:
		return
	circle.name = "CastCircle"
	circle.z_index = CIRCLE_Z
	circle.scale = Vector2.ONE * CIRCLE_SCALE_FROM
	circle.rotation = rotate_by
	add_child(circle)
	circle.global_position = origin

	var tw := circle.create_tween()
	tw.tween_property(circle, "scale", Vector2.ONE, CIRCLE_GROW_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(circle, "modulate:a", 0.0, CIRCLE_FADE_SEC) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(circle.queue_free)
