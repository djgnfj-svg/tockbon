extends Node2D
## 고리 조립 발사 시스템 — 모듈 B (세션 12~). 필드 씬에 자식으로 넣기만 하면 되는 자립 노드.
## EventBus.ring_cast_requested 수신 → 진(캐리어)을 조준 방향으로 쏜다.
##
## 🔴 세션 22: 옛 spell_system(SpellDesign·cast_requested)을 매장해 **이게 유일한 발사 경로**다.
##
## 발사 모델 (사용자 확정 세션 10):
##   1) 발사 = 조립한 마법진(진)이 통째로 조준 방향으로 날아간다 (ring_carrier).
##   2) 착탄 = 적에 닿는 그 자리에서 안의 고리가 전개된다:
##        • 발산→ 칸: 그 방향으로 불 탄환 (projectile.tscn 순수 직진탄 재사용)
##        • 응집← 칸: 하나로 모여 불기둥 (pillar.tscn 재사용, 많을수록 굵다)
##
## 마나·내구 판정 없음 (고리 모델의 경제는 #17에서 정한다 — 지금은 순수 발사 검증).

const RingPower := preload("res://src/core/ring_power.gd")
const CarrierScene := preload("res://src/spell/ring_carrier.tscn")
const CarrierScript := preload("res://src/spell/ring_carrier.gd")
const BoltScript := preload("res://src/spell/projectile.gd")
const PillarScene := preload("res://src/spell/pillar.tscn")
const PillarScript := preload("res://src/spell/pillar.gd")

const SLOTS := 8
const UP_AXIS := -PI / 2.0

## 응집 굵기 — 기둥 하나당 scale 증가분 (연출값, 밸런스 아님. 선례: spell_system CIRCLE_* 연출 상수).
## 응집 1개면 기본 크기, 여럿 모이면 굵어진다 ("많을수록 굵다").
const PILLAR_SCALE_PER_GATHER := 0.22

var balance: BalanceData = preload("res://data/balance.tres")


func _ready() -> void:
	EventBus.ring_cast_requested.connect(_on_ring_cast)


## 🔴 세션 23: `assembly.score`(손그림 종합)가 **위력을 정한다**. 점수를 안 실어 온 assembly는
## 기준 위력(1.0)으로 폴백한다 — 옛 저장·테스트가 조용히 0 피해가 되지 않도록.
## (펑 판정은 **여기가 아니라 조립대**의 몫이다 — 터진 마법진은 애초에 발사까지 오지 않는다.)
func _on_ring_cast(assembly: Dictionary, origin: Vector2, aim_dir: Vector2) -> void:
	var rings: Array = assembly.get("rings", [])
	if rings.is_empty():
		return
	var ring: Array = rings[0]
	if ring.size() < SLOTS:
		return
	var angle := aim_dir.angle() if aim_dir.length_squared() > 0.0 else 0.0
	var rune_type := int(assembly.get("rune", Enums.RuneType.FIRE))   # 🔴 세션 34: 발사가 고른 룬을 쓴다
	var power := _power_of(assembly)
	# 🔴 특별잉크 화상 증폭 (세션29) — 위력(피해)과 별개 축이라 따로 나른다. 전개는 나중이라
	# 그때 assembly가 없으므로, power처럼 캐리어에 실어 착탄까지 들고 간다.
	var status_mult := Db.status_mult_of(StringName(assembly.get("special_ink", &"")),
		float(assembly.get("special_ratio", 0.0)))

	# 🔴 지팡이 발사 패턴 부활 (세션 42). 옛 소비자(spell_system.wand_shots)는 세션22에 매장됐고
	# 그 뒤로 이 새 경로는 무조건 단발이었다 — GameState.wand_pattern()이 정의만 되고 orphan이었다.
	# 이제 진(캐리어)을 패턴이 정한 각도들로 **여러 개** 쏜다. 착탄 전개는 캐리어당 그대로 돈다.
	var pattern := GameState.wand_pattern()
	for a: float in _wand_angles(angle, pattern):
		_spawn_carrier(ring, origin, a, power, status_mult, rune_type)


## 진(캐리어) 하나를 origin에서 angle 방향으로 쏜다. 패턴이 여러 각도면 이걸 여러 번 부른다.
func _spawn_carrier(ring: Array, origin: Vector2, angle: float,
		power: float, status_mult: float, rune_type: int) -> void:
	var carrier := CarrierScene.instantiate() as CarrierScript
	if carrier == null:
		return
	add_child(carrier)
	carrier.global_position = origin
	var fire := _fire_hit(power, status_mult, rune_type)
	carrier.setup(ring, angle,
		balance.projectile_base_speed, balance.projectile_lifetime_sec,
		fire.damage, fire.rune_type, fire.status, fire.status_power)
	carrier.deployed.connect(_on_carrier_deployed.bind(power, status_mult, rune_type))


## 발사 각도 목록 — 지팡이 패턴이 정한다 (수치는 balance, 선례: wand_multi_count 등).
## SINGLE=에임 1발 · MULTI=에임 좌우로 퍼진 산탄 · NOVA=내 주변 전방위(에임 무시, 균등 분할).
func _wand_angles(base: float, pattern: int) -> Array:
	match pattern:
		Enums.WandPattern.MULTI:
			var n := maxi(balance.wand_multi_count, 1)
			if n == 1:
				return [base]
			var spread := deg_to_rad(balance.wand_multi_spread_deg)
			var out: Array = []
			for i in n:
				out.append(base - spread * 0.5 + spread * (float(i) / float(n - 1)))
			return out
		Enums.WandPattern.NOVA:
			var n2 := maxi(balance.wand_nova_count, 1)
			var out2: Array = []
			for i in n2:
				out2.append(base + TAU * float(i) / float(n2))
			return out2
		_:
			return [base]


## assembly → 위력 배율. 손그림 점수(곡선) × **잉크 등급 배수** × **진 크기**(세션29). 규칙은
## core가 쥔다(리포트·HUD와 같은 값). 점수 없는 옛 도안 = 기준 위력(1.0)에 잉크·크기만 곱한다.
func _power_of(assembly: Dictionary) -> float:
	var ink_mult := Db.ink_mult(StringName(assembly.get("ink", &"")))
	var size := float(assembly.get("size", 1.0))
	if not assembly.has("score"):
		return ink_mult * RingPower.size_mult(size)
	return RingPower.power_of(float(assembly.get("score", 0.0)), ink_mult, size)


## 착탄 = 안의 고리를 편다. 물리 콜백 중일 수 있으니 지연 실행 (Area2D를 콜백 안에서 즉시
## add_child하면 "flushing queries" 에러로 조용히 안 생긴다 — projectile/shockwave와 같은 함정).
func _on_carrier_deployed(ring: Array, at: Vector2, travel: float, power: float, status_mult: float, rune_type: int) -> void:
	call_deferred(&"_deploy_now", ring, at, travel, power, status_mult, rune_type)


func _deploy_now(ring: Array, at: Vector2, travel: float, power: float, status_mult: float, rune_type: int) -> void:
	var fire := _fire_hit(power, status_mult, rune_type)
	var gather := 0
	for k in SLOTS:
		var g := int(ring[k])
		if g == Enums.GlyphCode.RADIATE:
			_spawn_bolt(at, travel + TAU * float(k) / float(SLOTS), fire)
		elif g == Enums.GlyphCode.GATHER:
			gather += 1
	if gather > 0:
		_spawn_pillar(at, gather, fire)


## 발산 = 순수 직진 탄환. effects={}로 쓰면 팅김·유도·관통 없이 곧게 날아가 적에 닿으면 소멸한다.
##
## 🔴 세션 22 (M2): 탄 씬을 **룬 데이터가 정한다** — 예전엔 `preload(projectile.tscn)`로 박아 놔서
## `RuneDef.projectile_scene`을 읽는 코드가 죽은 spell_system뿐이었다. 결합 비용만 내고 이득이 0이었고,
## *"새 룬 = .tres 한 장"*(jin_def.gd:6)이라는 이 프로젝트의 약속이 새 경로에서 깨져 있었다.
## 이제 물·바람 룬 추가가 진짜로 .tres 한 장이다.
func _spawn_bolt(at: Vector2, angle: float, fire: Dictionary) -> void:
	var scene := fire.get("scene") as PackedScene
	if scene == null:
		push_warning("룬에 projectile_scene이 없다 — 발산 탄을 못 쏜다 (data/runes/*.tres 확인)")
		return
	var bolt := scene.instantiate() as BoltScript
	if bolt == null:
		return
	add_child(bolt)
	bolt.global_position = at
	bolt.setup(fire.damage, fire.rune_type, fire.status, fire.status_power,
		balance.projectile_base_speed, angle, {}, balance.projectile_lifetime_sec)


## 응집 = 착탄점에 불기둥 하나. 응집 칸이 많을수록 굵다 (node scale).
func _spawn_pillar(at: Vector2, gather: int, fire: Dictionary) -> void:
	var pillar := PillarScene.instantiate() as PillarScript
	if pillar == null:
		return
	add_child(pillar)
	pillar.global_position = at
	pillar.scale = Vector2.ONE * (1.0 + PILLAR_SCALE_PER_GATHER * float(gather - 1))
	pillar.setup(fire.damage, fire.rune_type, fire.status, fire.status_power)


## 룬 히트 정보 — Db에서 **고른 룬** RuneDef를 읽어 피해·상태·세기 + **탄 씬**을 뽑는다 (세션 34).
## 등록이 없으면 기본 피해(balance)로 폴백하되 scene은 null (탄은 못 쏜다 — _spawn_bolt가 경고).
##
## 🔴 `power` = 손그림·잉크·크기가 정한 위력 배율 → **피해에** 곱한다 (세션 23·29).
## 🔴 `status_mult` = 특별잉크 화상 증폭 (세션29) → **상태이상 세기에만** 곱한다. 피해(power)와
## 상태(status_mult)는 **다른 축**이다 — 잉크 등급=피해, 특별잉크=상태. 섞으면 축이 겹친다.
## (룬 농도 세기는 조립 단계에서 status_power에 이미 반영돼 이 rune.status_power로 들어온다.)
func _fire_hit(power: float = 1.0, status_mult: float = 1.0,
		rune_type: int = Enums.RuneType.FIRE) -> Dictionary:
	var rune: RuneDef = Db.get_rune(rune_type)
	if rune == null:
		return {"damage": balance.projectile_base_damage * power, "rune_type": rune_type,
			"status": Enums.Status.NONE, "status_power": 0.0, "scene": null}
	return {"damage": balance.projectile_base_damage * rune.base_damage * power,
		"rune_type": rune_type, "status": rune.status,
		"status_power": rune.status_power * status_mult,
		"scene": rune.projectile_scene}
