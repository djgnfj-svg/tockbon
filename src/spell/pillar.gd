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

## 룬 색은 Db에서 읽는다 (`_rune_color`) — "새 룬 = .tres 한 장"이 색까지 지켜지게.
## 이건 Db에 룬이 없을 때만 쓰는 폴백 (오토로드 없는 컨텍스트도 견딘다 — ring_carrier와 같은 규칙).
const RUNE_FALLBACK := Color(0.95, 0.35, 0.15)

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
## 🔴 스폰 직후 첫 물리 프레임은 overlap이 아직 안 잡힌다 — 한 프레임 흘려보낸 뒤부터 때린다.
var _warmed: bool = false

func _ready() -> void:
	add_to_group("pillars")


func setup(p_damage: float, p_rune_type: int, p_status: int, p_status_power: float) -> void:
	damage = p_damage
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	_life_left = _balance.pillar_duration_sec
	# 🔴 warmup 프레임(_warmed) 직후에 첫 타격이 나가도록 0으로 둔다 — _physics_process 참조.
	# 서자마자 한 번 때린다 (안 그러면 짧은 기둥이 아무것도 못 한다).
	_tick_left = 0.0

	# 🔴 형상 리소스는 **씬 인스턴스들이 공유하는 물건**이다 — radius를 직접 쓰면 모든 기둥이
	# 함께 바뀐다. **scale로만 만진다** (projectile.gd·shockwave.gd와 같은 규칙)
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if shape != null:
		shape.scale = Vector2.ONE * (_balance.pillar_radius_px / BASE_RADIUS)

	_visual = get_node_or_null("Visual") as Polygon2D
	if _visual != null:
		_visual.color = _rune_color(p_rune_type)
		_visual.polygon = _circle_points(_balance.pillar_radius_px)


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	# 사그라든다 — 남은 수명이 곧 밝기 (연출. 밸런스 아님)
	if _visual != null:
		_visual.modulate.a = clampf(_life_left / maxf(_balance.pillar_duration_sec, 0.001), 0.0, 1.0)

	# 🔴 스폰된 그 프레임엔 get_overlapping_*가 아직 비어 있다 (Area2D 겹침은 물리 스텝 한 번 뒤에
	# 갱신된다). 한 프레임을 흘려보낸 뒤에 첫 타격을 낸다 — 안 그러면 "서자마자 1타"가 빈 overlap을
	# 때리고 타이머만 리셋돼 실제 첫 피해가 pillar_tick_sec만큼 밀린다 (짧은 기둥이면 통째로 유실).
	if not _warmed:
		_warmed = true
		return

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


## 룬 색 — Db에서 읽고, 없으면 폴백 (ring_carrier._rune_color와 같은 규칙).
func _rune_color(p_rune_type: int) -> Color:
	var db := get_node_or_null(^"/root/Db")
	if db != null:
		var rune := db.get_rune(p_rune_type) as RuneDef
		if rune != null:
			return rune.ui_color
	return RUNE_FALLBACK


static func _circle_points(radius: float, segments: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / float(segments)) * radius)
	return pts
