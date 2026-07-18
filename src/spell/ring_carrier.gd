extends Area2D
## 고리 조립 캐리어 — 모듈 B (세션 12~). class_name 없음 — preload로 참조할 것.
##
## 🔴 **진이 곧 투사체다** (고리 모델, 사용자 확정 세션 10). 조립한 마법진(진)이 통째로 조준
## 방향으로 날아가고, **적에 닿는 순간 안의 고리 패턴이 그 자리에서 전개된다** — 껍질이 내용물을
## 착탄점에 배달한다. [[takbon-nested-circle-model]] 껍질=배달.
##   • 발산→ 칸: 그 화살표 방향으로 불 탄환이 퍼진다 (ring_spell_system이 projectile.tscn 스폰)
##   • 응집← 칸: 하나로 모여 불기둥 하나 (pillar.tscn, 많을수록 굵다)
##
## **빈 진도 날아가 몸으로 때린다** (문양본이 없어 전개할 게 없어도 — RingBoard.can_commit 항상 참).
##   → 캐리어 자체가 착탄 시 damage를 얹는다. 전개는 그 위에 덤이다.
##
## **전개는 적에 닿을 때만.** 벽·수명으로 죽으면 조용히 사라진다 (안 맞으면 전개 없음 — 데모 규칙).
## **회전하지 않는다.** 진은 진행 방향을 보고 빙글 돌지 않는다 (방향은 _velocity만 안다).
##
## 적 노드 계약: 그룹 "enemies" + take_hit(damage, rune_type, status, status_power).

const RADIUS_PX := 18.0       # 히트박스·먹선 반지름 (진 몸) — 세션 13: 9→18 (발사체가 안 보였다)
const RING_COLOR := Color(0.98, 0.66, 0.28)
const RUNE_FALLBACK := Color(0.95, 0.35, 0.15)

## 착탄 = 안의 고리를 편다. ring_spell_system이 받아 발산 탄환·응집 기둥을 스폰한다.
## travel = 탄이 가던 방향 (전개 회전 기준).
signal deployed(ring: Array, at: Vector2, travel: float)

var damage: float = 0.0
var rune_type: int = Enums.RuneType.FIRE
var status: int = Enums.Status.NONE
var status_power: float = 0.0

var _ring: Array = []
var _velocity := Vector2.ZERO
var _life_left: float = 0.0
var _consumed := false


func _ready() -> void:
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## p_ring: 8칸 배열 (RingBoard.G_GATHER / G_RADIATE / GLYPH_NONE). p_angle: 조준각.
func setup(p_ring: Array, p_angle: float, p_speed: float, p_lifetime: float,
		p_damage: float, p_rune_type: int, p_status: int, p_status_power: float) -> void:
	_ring = p_ring.duplicate()
	_velocity = Vector2.RIGHT.rotated(p_angle) * p_speed
	_life_left = maxf(p_lifetime, 0.05)
	damage = p_damage
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	# 히트박스를 진 반지름에 맞춘다 (형상 리소스는 공유물 — scale로만)
	var cs := get_node_or_null("Shape") as CollisionShape2D
	if cs != null and cs.shape is CircleShape2D:
		cs.scale = Vector2.ONE * (RADIUS_PX / (cs.shape as CircleShape2D).radius)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	position += _velocity * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_die_without_deploy()   # 수명 끝 = 못 맞음 → 전개 없이 사라진다


func _on_body_entered(body: Node2D) -> void:
	_handle(body)


func _on_area_entered(area: Area2D) -> void:
	_handle(area)


func _handle(node: Node2D) -> void:
	if _consumed:
		return
	if node.is_in_group("enemies"):
		_hit_enemy(node)
	else:
		_die_without_deploy()   # 마스크상 적 아니면 벽 — 못 맞음 처리


## 적 착탄 — 진 몸으로 때리고, 그 자리에서 고리를 전개한다.
func _hit_enemy(node: Node2D) -> void:
	_consumed = true
	if node.has_method("take_hit"):
		node.take_hit(damage, rune_type, status, status_power)
	var travel := _velocity.angle() if not _velocity.is_zero_approx() else 0.0
	deployed.emit(_ring, global_position, travel)
	queue_free()


func _die_without_deploy() -> void:
	if _consumed:
		return
	_consumed = true
	queue_free()


## 진 = **날아가는 마법진**. 조립한 그대로(외곽 진 + 룬 + 문양 화살표)를 그려 통째로 날아가는 게
## 보이게 한다. 회전하지 않는다 (진행 방향을 안 본다).
func _draw() -> void:
	var r := RADIUS_PX
	# 글로우(은은한 후광) — 배경과 상관없이 눈에 띄게
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(RING_COLOR, 0.30), 6.0, true)
	# 외곽 진 이중선
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, RING_COLOR, 2.5, true)
	draw_arc(Vector2.ZERO, r * 0.58, 0.0, TAU, 24, Color(RING_COLOR, 0.85), 1.5, true)
	# 중심 룬 (삼각) — 룬 색
	var rc := _rune_color()
	var s := r * 0.30
	draw_polyline(PackedVector2Array([
		Vector2(0, -s), Vector2(s * 0.87, s * 0.5),
		Vector2(-s * 0.87, s * 0.5), Vector2(0, -s)]), rc, 1.8, true)
	# 문양 화살표 — 응집=안쪽 / 발산=바깥 (조립한 칸 그대로)
	var n := _ring.size()
	if n <= 0:
		return
	for k in n:
		var g := int(_ring[k])
		if g < 0:
			continue
		var ang := TAU * float(k) / float(n) - PI / 2.0
		var outward := Vector2.from_angle(ang)
		var p := outward * (r * 0.78)
		var dir := outward if g == Enums.GlyphCode.RADIATE else -outward   # 발산(밖) / 응집(안)
		var a := p - dir * (r * 0.14)
		var b := p + dir * (r * 0.14)
		draw_line(a, b, RING_COLOR, 1.8, true)
		draw_line(b, b - dir.rotated(0.5) * (r * 0.1), RING_COLOR, 1.8, true)
		draw_line(b, b - dir.rotated(-0.5) * (r * 0.1), RING_COLOR, 1.8, true)


## 룬 색 — Db에서 읽고, 없으면 폴백. (오토로드 없는 컨텍스트도 견딘다)
func _rune_color() -> Color:
	var db := get_node_or_null(^"/root/Db")
	if db != null:
		var rune := db.get_rune(rune_type) as RuneDef
		if rune != null:
			return rune.ui_color
	return RUNE_FALLBACK
