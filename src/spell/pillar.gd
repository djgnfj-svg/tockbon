extends Area2D
## 기둥 — 지속형 장판. class_name 없음 — preload로 참조할 것.
##
## 🔴 기둥은 규칙이 아니라 결과다 — 씬에 배치하지 않고 ring_spell_system._spawn_pillar가
## 응집 칸이 모인 착탄점에 직접 세운다. "몇 개부터 기둥인가"를 정한 곳은 아무 데도 없다.
## 적 노드 계약: 그룹 "enemies" + take_hit(damage, rune_type, status, status_power).

## Db에 룬이 없을 때만 쓰는 폴백 — 오토로드 없는 컨텍스트도 견디게.
const RUNE_FALLBACK := Color(0.95, 0.35, 0.15)

## 씬의 CollisionShape2D가 쥔 CircleShape2D 반지름 — **공유 리소스라 불변**. scale로만 키운다
const BASE_RADIUS := 14.0

var damage: float = 0.0
var rune_type: int = Enums.RuneType.FIRE
var status: int = Enums.Status.NONE
var status_power: float = 0.0
## 복합 룬 — primary 외 룬을 피해 0으로 상태만 얹는다(적 0-피해 가드가 도배를 막는다).
var rune_hits: Array = []

var _balance: BalanceData = preload("res://data/balance.tres")
var _life_left: float = 0.0
var _tick_left: float = 0.0
var _visual: Polygon2D = null
## 🔴 스폰 직후 첫 물리 프레임은 overlap이 아직 안 잡힌다 — 한 프레임 흘려보낸 뒤부터 때린다.
var _warmed: bool = false

func _ready() -> void:
	add_to_group("pillars")


func setup(p_damage: float, p_rune_type: int, p_status: int, p_status_power: float,
		p_rune_hits: Array = []) -> void:
	damage = p_damage
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	rune_hits = p_rune_hits
	_life_left = _balance.pillar_duration_sec
	# 서자마자 한 번 때린다 — 안 그러면 짧은 기둥이 아무것도 못 한다.
	_tick_left = 0.0

	# 🔴 형상 리소스는 인스턴스끼리 공유한다 — radius를 직접 쓰면 모든 기둥이 같이 바뀐다. scale로만 만져라.
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

	# 🔴 스폰 프레임엔 get_overlapping_*가 아직 비어 있다 — 여기서 때리면 빈 overlap에 타이머만
	# 리셋돼 첫 피해가 한 tick 밀린다(짧은 기둥이면 통째로 유실).
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
		# 보조 룬은 피해 0으로 상태만 얹는다. 기둥은 틱마다 갱신이라 반응도 틱마다 다시 날 수 있다.
		for rh: Dictionary in rune_hits:
			if int(rh.get("rune_type", -1)) == rune_type:
				continue
			node.take_hit(0.0, int(rh.rune_type), int(rh.status), float(rh.status_power))


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
