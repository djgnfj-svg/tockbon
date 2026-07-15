extends Area2D
## 기둥 — v2.1 (TECH_SPEC §4.0-b). 모듈 B. class_name 없음 — preload로 참조할 것.
##
## 🔴 **기둥은 규칙이 아니라 결과다.** 아무도 "기둥을 만들어라"라고 하지 않는다 —
## **충격파끼리 부딪히면** 그 자리에 선다 (shockwave._collide_with).
## 사용자: *"그 충격파끼리 맞으면 기둥이 되는 거임."*
##
## 룬을 겨눈 화살표 8개는 **중심에서 저절로 만난다.** 밖을 겨눈 8개는 영영 안 만난다.
## **"몇 개부터 기둥인가"를 정한 곳이 어디에도 없다** — 만나면 만나는 거고 어긋나면 안 만난다.
##
## 지속형이다 — 서 있는 동안 안에 든 적을 tick마다 때린다.
## 적 노드 계약: 그룹 "enemies" + take_hit(damage, rune_type, status, status_power).

const RUNE_COLORS: Dictionary = {
	Enums.RuneType.FIRE: Color(1.0, 0.55, 0.1),
	Enums.RuneType.WATER: Color(0.25, 0.55, 1.0),
	Enums.RuneType.WIND: Color(0.65, 0.95, 0.45),
}

## 씬의 CollisionShape2D가 쥔 CircleShape2D 반지름 — **공유 리소스라 불변**. scale로만 키운다
const BASE_RADIUS := 14.0

var damage: float = 0.0
var rune_type: int = Enums.RuneType.FIRE
var status: int = Enums.Status.NONE
var status_power: float = 0.0

var _balance: BalanceData = preload("res://data/balance.tres")
var _life_left: float = 0.0
var _tick_left: float = 0.0
var _visual: Polygon2D = null

func _ready() -> void:
	add_to_group("pillars")


func setup(p_damage: float, p_rune_type: int, p_status: int, p_status_power: float) -> void:
	damage = p_damage
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	_life_left = _balance.pillar_duration_sec
	_tick_left = 0.0   # 서자마자 한 번 때린다 — 안 그러면 짧은 기둥이 아무것도 못 한다

	# 🔴 형상 리소스는 **씬 인스턴스들이 공유하는 물건**이다 — radius를 직접 쓰면 모든 기둥이
	# 함께 바뀐다. **scale로만 만진다** (projectile.gd·shockwave.gd와 같은 규칙)
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if shape != null:
		shape.scale = Vector2.ONE * (_balance.pillar_radius_px / BASE_RADIUS)

	_visual = get_node_or_null("Visual") as Polygon2D
	if _visual != null:
		_visual.color = RUNE_COLORS.get(p_rune_type, Color.WHITE)
		_visual.polygon = _circle_points(_balance.pillar_radius_px)


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	# 사그라든다 — 남은 수명이 곧 밝기 (연출. 밸런스 아님)
	if _visual != null:
		_visual.modulate.a = clampf(_life_left / maxf(_balance.pillar_duration_sec, 0.001), 0.0, 1.0)

	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = _balance.pillar_tick_sec
	for node: Node2D in get_overlapping_bodies():
		_hit(node)
	for area: Area2D in get_overlapping_areas():
		_hit(area)


func _hit(node: Node2D) -> void:
	if not node.is_in_group("enemies"):
		return
	if node.has_method("take_hit"):
		node.take_hit(damage, rune_type, status, status_power)


static func _circle_points(radius: float, segments: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / float(segments)) * radius)
	return pts
