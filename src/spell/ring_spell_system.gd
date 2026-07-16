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


func _on_ring_cast(assembly: Dictionary, origin: Vector2, aim_dir: Vector2) -> void:
	var rings: Array = assembly.get("rings", [])
	if rings.is_empty():
		return
	var ring: Array = rings[0]
	if ring.size() < SLOTS:
		return
	var angle := aim_dir.angle() if aim_dir.length_squared() > 0.0 else 0.0

	var carrier := CarrierScene.instantiate() as CarrierScript
	if carrier == null:
		return
	add_child(carrier)
	carrier.global_position = origin
	var fire := _fire_hit()
	carrier.setup(ring, angle,
		balance.projectile_base_speed, balance.projectile_lifetime_sec,
		fire.damage, fire.rune_type, fire.status, fire.status_power)
	carrier.deployed.connect(_on_carrier_deployed)


## 착탄 = 안의 고리를 편다. 물리 콜백 중일 수 있으니 지연 실행 (Area2D를 콜백 안에서 즉시
## add_child하면 "flushing queries" 에러로 조용히 안 생긴다 — projectile/shockwave와 같은 함정).
func _on_carrier_deployed(ring: Array, at: Vector2, travel: float) -> void:
	call_deferred(&"_deploy_now", ring, at, travel)


func _deploy_now(ring: Array, at: Vector2, travel: float) -> void:
	var fire := _fire_hit()
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


## 불 룬 히트 정보 — Db에서 불 RuneDef를 읽어 피해·상태·세기 + **탄 씬**을 뽑는다.
## 등록이 없으면 기본 불 피해(balance)로 폴백하되 scene은 null (탄은 못 쏜다 — _spawn_bolt가 경고).
func _fire_hit() -> Dictionary:
	var rune: RuneDef = Db.get_rune(Enums.RuneType.FIRE)
	if rune == null:
		return {"damage": balance.projectile_base_damage, "rune_type": Enums.RuneType.FIRE,
			"status": Enums.Status.BURN, "status_power": 0.0, "scene": null}
	return {"damage": balance.projectile_base_damage * rune.base_damage,
		"rune_type": Enums.RuneType.FIRE, "status": rune.status, "status_power": rune.status_power,
		"scene": rune.projectile_scene}
