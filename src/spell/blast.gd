extends Area2D
## 폭발 — 광역 **1회** 타격. class_name 없음 — preload로 참조할 것.
##
## 🔴 폭발은 규칙이 아니라 결과다 — 변형형 문양 EXPLODE가 안쪽 층 결과를 융합할 때 착탄점에 선다.
## 반경은 안쪽 결과가 얼마나 퍼져 있었나에 달려서 **호출자가 계산해 `setup`으로 넘긴다**(기둥과 달리
## balance 고정값이 아니다). 기둥과 달리 원샷이라 `_hit_ids`로 같은 적 이중 타격을 막는다.
## 적 노드 계약: 그룹 "enemies" + take_hit(damage, rune_type, status, status_power).

## Db에 룬이 없을 때만 쓰는 폴백 — 오토로드 없는 컨텍스트도 견디게.
const RUNE_FALLBACK := Color(0.95, 0.35, 0.15)

## 씬 CollisionShape2D의 CircleShape2D 반지름 — **인스턴스끼리 공유하는 리소스라 불변**. scale로만 키운다.
const BASE_RADIUS := 14.0

# ── 연출값 (밸런스 아님 — 손맛이라 스크립트 const. 피해·반경은 setup 인자다) ──────────
## 링이 다 퍼져 사라지기까지. 이게 곧 노드 수명이다
const FLASH_SEC := 0.30
## 시작 반경 = 최종 반경 × 이것 (0에서 시작하면 한 점에서 튀어나와 눈이 못 따라간다)
const RING_START_FRAC := 0.25
## 팽창 링 굵기(px) — 노드 scale로 커져도 굵기는 고정으로 보이게 매 프레임 되나눈다
const RING_WIDTH_PX := 3.0
## 안쪽 코어 섬광 반경 = 최종 반경 × 이것
const CORE_FRAC := 0.55
## 코어가 꺼지는 시점 (수명 비율) — 링보다 먼저 꺼져야 "터졌다 → 파문"으로 읽힌다
const CORE_FADE_FRAC := 0.45
const CIRCLE_SEGMENTS := 24

var damage: float = 0.0
var rune_type: int = Enums.RuneType.FIRE
var status: int = Enums.Status.NONE
var status_power: float = 0.0
## 복합 룬 — primary 외 룬을 피해 0으로 상태만 얹는다(적 0-피해 가드가 도배를 막는다).
var rune_hits: Array = []
## 폭발 반경(px) — 안쪽 층의 결과에 따라 달라져 **호출자가 정한다**
var radius_px: float = BASE_RADIUS

## 🔴 스폰 직후 첫 물리 프레임은 overlap이 아직 안 잡힌다 — 한 프레임 흘려보낸 뒤에 때린다.
var _warmed: bool = false
var _struck: bool = false
## 🔴 몸(body)과 히트박스(area) 양쪽으로 잡히는 적이 있어, 순회 두 번이 곧 이중 타격이 된다.
var _hit_ids: Array[int] = []
var _life_left: float = FLASH_SEC
var _age: float = 0.0
var _core: Polygon2D = null
var _ring: Line2D = null


func _ready() -> void:
	add_to_group("blasts")


func setup(p_damage: float, p_rune_type: int, p_status: int, p_status_power: float,
		p_radius_px: float, p_rune_hits: Array = []) -> void:
	damage = p_damage
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	rune_hits = p_rune_hits
	radius_px = maxf(p_radius_px, 1.0)
	_life_left = FLASH_SEC

	# 🔴 형상 리소스는 인스턴스끼리 공유한다 — radius를 직접 쓰면 모든 폭발이 같이 바뀐다. scale로만 만져라.
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if shape != null:
		shape.scale = Vector2.ONE * (radius_px / BASE_RADIUS)

	var color := _rune_color(p_rune_type)
	_core = get_node_or_null("Core") as Polygon2D
	if _core != null:
		_core.color = color
		_core.polygon = _circle_points(radius_px * CORE_FRAC, CIRCLE_SEGMENTS)
		_core.scale = Vector2.ONE * RING_START_FRAC
	_ring = get_node_or_null("Ring") as Line2D
	if _ring != null:
		_ring.default_color = color
		_ring.points = _ring_points(radius_px, CIRCLE_SEGMENTS)
		_ring.width = RING_WIDTH_PX
		_ring.scale = Vector2.ONE * RING_START_FRAC


func _physics_process(delta: float) -> void:
	# 🔴 스폰 프레임엔 get_overlapping_*가 아직 비어 있다. 원샷이라 여기서 때리면
	# **아무도 못 때리고 조용히 사라진다** — 기둥과 달리 두 번째 기회가 없다.
	if not _warmed:
		_warmed = true
		return
	if not _struck:
		_struck = true
		_strike()
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


## 팽창하는 링 + 페이드 — 도형 금지 규칙의 명시적 예외(섬광은 도트로 그릴 물건이 아니다).
func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / FLASH_SEC, 0.0, 1.0)
	# ease-out — 터지는 순간 확 퍼졌다가 끝에서 느려진다
	var s := lerpf(RING_START_FRAC, 1.0, 1.0 - pow(1.0 - t, 3.0))
	if _ring != null:
		_ring.scale = Vector2.ONE * s
		_ring.width = RING_WIDTH_PX / s   # 노드가 커져도 선 굵기는 그대로 보이게
		_ring.modulate.a = 1.0 - t
	if _core != null:
		_core.scale = Vector2.ONE * s
		_core.modulate.a = clampf(1.0 - t / CORE_FADE_FRAC, 0.0, 1.0)


func _strike() -> void:
	for node: Node2D in get_overlapping_bodies():
		_hit(node)
	for area: Area2D in get_overlapping_areas():
		_hit(area)


func _hit(node: Node2D) -> void:
	if node == null or not node.is_in_group("enemies"):
		return
	var id := node.get_instance_id()
	if _hit_ids.has(id):
		return   # 몸과 히트박스로 두 번 잡힌 같은 적 — 원샷은 한 번뿐이다
	_hit_ids.append(id)
	if node.has_method("take_hit"):
		node.take_hit(damage, rune_type, status, status_power)
		# 보조 룬은 피해 0으로 상태만 얹는다 — 원샷이라 적당 한 번.
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


## 닫힌 링 — 첫 점을 끝에 한 번 더 찍어 이음매를 메운다 (Line2D.closed에 기대지 않는다).
static func _ring_points(radius: float, segments: int = 12) -> PackedVector2Array:
	var pts := _circle_points(radius, segments)
	if pts.size() > 0:
		pts.append(pts[0])
	return pts
