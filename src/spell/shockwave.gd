extends Area2D
## 충격파 — v2.1 착탄 축 (TECH_SPEC §4.0-b). 모듈 B. class_name 없음 — preload로 참조할 것.
##
## 🔴 **화살표 하나 = 충격파 하나.** 사용자: *"화살표라는 문양은 적과의 히트 이후의 충격이
## 어디로 가는가를 정하는 거임. 그래서 그 **충격파끼리 맞으면 기둥이 되는 거임.**"*
##
## **탄이 곧 진**이므로(§4.0-a) 적에 닿는 순간 진이 히트 지점에 놓이고, 진 위에 그려진
## 화살표들이 **각자 제자리에서 제 방향으로** 충격파를 뿜는다 — 종이 위의 배치가 곧 착탄 그림이다.
##
## 🔴 **기둥을 여기서 "만들지" 않는다.** "수렴하면 기둥"이라고 적는 순간 창발이 아니라 규칙이
## 되고, **"몇 개부터 기둥인가"**라는 답 없는 질문이 따라온다. 충격파끼리 **부딪히면** 기둥이
## 서고, 어긋나면 안 선다. 룬을 겨눈 화살표 8개는 **중심에서 저절로 만난다.**
##
## 적 노드 계약: 그룹 "enemies" + take_hit(damage, rune_type, status, status_power).

const PillarScene := preload("res://src/spell/pillar.tscn")

## 씬의 CollisionShape2D가 쥔 CircleShape2D 반지름 — **공유 리소스라 불변**. scale로만 키운다
const BASE_RADIUS := 5.0

const RUNE_COLORS: Dictionary = {
	Enums.RuneType.FIRE: Color(1.0, 0.55, 0.1),
	Enums.RuneType.IMPACT: Color(1.0, 0.9, 0.2),
	Enums.RuneType.WATER: Color(0.25, 0.55, 1.0),
	Enums.RuneType.WIND: Color(0.65, 0.95, 0.45),
}

## 이 충격파가 적을 때리는 피해 (= 탄 피해 × shockwave_damage_mult)
var damage: float = 0.0
## **탄의 피해 원본** — 기둥이 자기 배율을 곱할 재료다.
## ⚠ `damage`에서 역산(÷ shockwave_mult)하지 않는다 — 배율을 0으로 두는 순간 0으로 나눈다
var base_damage: float = 0.0
var rune_type: int = Enums.RuneType.FIRE
var status: int = Enums.Status.NONE
var status_power: float = 0.0

var _balance: BalanceData = preload("res://data/balance.tres")
var _velocity := Vector2.ZERO
var _life_left: float = 0.0
var _consumed := false
## 이미 때린 적 — 충격파는 **적을 뚫고 지나간다**(파동이다). 안 그러면 적이 앞을 막고 선
## 순간 충격파가 죽어 **서로 만나지 못하고 기둥이 영영 안 선다**
var _hit_ids: Array[int] = []

func _ready() -> void:
	add_to_group("shockwaves")
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


## p_base_damage: **탄의 피해** — 충격파 피해와 기둥 피해가 **각자의 배율**로 여기서 나온다
func setup(p_base_damage: float, p_rune_type: int, p_status: int, p_status_power: float,
		p_angle: float) -> void:
	base_damage = p_base_damage
	damage = p_base_damage * _balance.shockwave_damage_mult
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	rotation = p_angle
	_velocity = Vector2.RIGHT.rotated(p_angle) * _balance.shockwave_speed
	_life_left = _balance.shockwave_lifetime_sec

	# 🔴 형상 리소스(CircleShape2D)는 **씬 인스턴스들이 공유하는 물건**이다 — radius를 직접
	# 쓰면 모든 충격파가 함께 바뀐다. **scale로만 만진다** (projectile.gd와 같은 규칙)
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if shape != null:
		shape.scale = Vector2.ONE * (_balance.shockwave_radius_px / BASE_RADIUS)

	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.color = RUNE_COLORS.get(p_rune_type, Color.WHITE)


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	position += _velocity * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	_hit_enemy(body)

func _on_area_entered(area: Area2D) -> void:
	# 🔴 **여기가 기둥이 서는 유일한 자리다** — 다른 충격파와 부딪혔다.
	if area.is_in_group("shockwaves"):
		_collide_with(area)
		return
	_hit_enemy(area)


## 충격파끼리 만났다 → 그 사이에 기둥이 선다. 둘 다 소진된다 (부딪혀 멎었으므로).
## ⚠ 양쪽이 서로를 감지하므로 이 함수는 **한 쌍에 두 번** 불린다 — `_consumed` 가드가 막는다.
func _collide_with(other: Area2D) -> void:
	if _consumed or other.get("_consumed"):
		return
	var at := (global_position + other.global_position) * 0.5
	_consumed = true
	other.call_deferred(&"_consume")
	_spawn_pillar(at)
	queue_free()


## 🔴 **같은 프레임에 예약된 기둥**까지 함께 본다. 기둥은 `call_deferred`로 트리에 들어가므로
## **이번 프레임 안에는 "pillars" 그룹에 안 잡힌다** — 그룹만 검사하면 충격파 8개가 중심에서
## 만날 때 여러 쌍이 각자 기둥을 세워 **피해가 몇 배로 겹친다.**
## 프레임이 바뀌면(그때는 이미 트리에 들어가 그룹으로 잡힌다) 저절로 비워진다.
static var _pending: Array[Vector2] = []
static var _pending_frame: int = -1

## 이미 선(또는 이번 프레임에 예약된) 기둥 근처면 새로 세우지 않는다.
## ⚠ **이건 "규칙"이 아니라 중복 방지다.** "수렴하면 기둥"을 정하는 게 아니라,
## **하나의 사건이 하나의 기둥이 되게** 할 뿐이다 (창발은 그대로 산다).
func _spawn_pillar(at: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var frame := Engine.get_physics_frames()
	if _pending_frame != frame:
		_pending.clear()
		_pending_frame = frame
	for p: Vector2 in _pending:
		if p.distance_to(at) < _balance.pillar_merge_px:
			return
	for node: Node in get_tree().get_nodes_in_group("pillars"):
		var p2 := node as Node2D
		if p2 != null and not p2.is_queued_for_deletion() \
				and p2.global_position.distance_to(at) < _balance.pillar_merge_px:
			return
	_pending.append(at)
	var pillar := PillarScene.instantiate()
	# 🔴 여기는 물리 콜백 안이다 — Area2D를 즉시 add_child 하면 물리 서버가 거부하고
	# **기둥이 조용히 안 선다.** 위치·setup을 먼저 끝내고 지연 추가한다
	var n2d := parent as Node2D
	pillar.position = n2d.to_local(at) if n2d != null else at
	pillar.call(&"setup", base_damage * _balance.pillar_damage_mult,
		rune_type, status, status_power)
	parent.call_deferred(&"add_child", pillar)


func _hit_enemy(node: Node2D) -> void:
	if _consumed or not node.is_in_group("enemies"):
		return
	var id := node.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids.append(id)
	if node.has_method("take_hit"):
		node.take_hit(damage, rune_type, status, status_power)
	# 소멸하지 않는다 — 파동은 적을 지나쳐 계속 간다 (위 _hit_ids 주석 참조)


func _consume() -> void:
	if _consumed:
		return
	_consumed = true
	queue_free()
