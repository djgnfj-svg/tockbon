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
## 부메랑 선회 각속도(rad/s) — 연출값이라 balance 아닌 여기 상수 (선례: juice의 손맛 수치).
## 8.0 = 180도 유턴에 약 0.4초. 낮추면 크게 휘고 높이면 칼같이 꺾인다 — 사용자가 쏴 보고 조인다.
const BOOMERANG_TURN_RATE := 8.0
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

# 🔴 비행 경로 (세션48). motion=STRAIGHT면 아래 전부 안 쓰이고 예전과 픽셀 동일하게 돈다.
var _motion: int = Enums.JinMotion.STRAIGHT
var _scale: float = 1.0
var _age: float = 0.0            # 발사 후 경과 — 나선 위상·부메랑 반환 시점의 기준
var _lifetime: float = 0.0       # 처음 받은 수명 (부메랑이 반환 시점을 재는 데 쓴다)
var _origin := Vector2.ZERO      # 발사 지점 — 부메랑이 돌아올 목표
var _spiral_amp: float = 0.0
var _spiral_period: float = 0.45
var _turn_ratio: float = 0.5


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
	_lifetime = _life_left
	_origin = global_position
	damage = p_damage
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	_apply_body_radius()
	queue_redraw()


## 🔴 비행 경로·규모를 얹는다 (세션48). setup **뒤에** 부른다 — 안 부르면 예전 그대로 직진 1.0배라
## 옛 호출자·테스트가 그대로 돈다. 진(JinDef)이 없는 매직볼·옛 도안이 정확히 그 경로다.
func set_motion(p_motion: int, p_scale: float, p_spiral_amp: float,
		p_spiral_period: float, p_turn_ratio: float) -> void:
	_motion = p_motion
	_scale = maxf(p_scale, 0.1)
	_spiral_amp = p_spiral_amp
	_spiral_period = maxf(p_spiral_period, 0.05)
	_turn_ratio = clampf(p_turn_ratio, 0.05, 0.95)
	_apply_body_radius()
	queue_redraw()


## 히트박스를 진 몸 반지름에 맞춘다 (형상 리소스는 공유물 — scale로만 건드린다).
func _apply_body_radius() -> void:
	var cs := get_node_or_null("Shape") as CollisionShape2D
	if cs != null and cs.shape is CircleShape2D:
		cs.scale = Vector2.ONE * (body_radius() / (cs.shape as CircleShape2D).radius)


## 진 몸 반지름 — 규모가 곱해진다. 먹선(_draw)과 히트박스가 **같은 함수**를 봐야 갈라지지 않는다
## (선례: ring_power의 is_stable — 보이는 크기와 맞는 크기가 다르면 아무도 못 알아챈다).
func body_radius() -> float:
	return RADIUS_PX * _scale


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	_age += delta
	match _motion:
		Enums.JinMotion.SPIRAL:
			# 진행축에 **수직**으로 사인 흔들림 — 경로가 넓어져 밀집한 적을 훑는다.
			# 위치를 직접 찍지 않고 속도에 수직 성분을 더한다(충돌이 매 프레임 연속으로 잡히게).
			var perp := _velocity.orthogonal().normalized()
			var w := TAU / _spiral_period
			var swing := perp * (_spiral_amp * _scale) * w * cos(w * _age)
			position += (_velocity + swing) * delta
		Enums.JinMotion.BOOMERANG:
			# 반환 시점을 넘기면 발사 지점 쪽으로 속도를 꺾는다 — 유턴이 곡선으로 그려진다.
			# 놓친 적을 **돌아오는 길에** 한 번 더 만난다(진짜 두 번째 기회).
			if _age >= _lifetime * _turn_ratio:
				# 🔴 속도를 **회전**시킨다 — `lerp`로 하면 안 된다. 되돌아올 방향은 지금 방향의
				# 거의 정반대라 두 벡터가 상쇄돼 **속도가 0으로 죽고 진이 공중에 멈춘다**
				# (세션48에 실제로 그렇게 났다: 최대거리 = 끝거리 218.6px로 제자리). 각도만 돌리면
				# 속력이 보존돼 나간 만큼의 기세로 돌아온다.
				var speed := _velocity.length()
				var want := (_origin - global_position).angle()
				var turned := rotate_toward(_velocity.angle(), want, BOOMERANG_TURN_RATE * delta)
				_velocity = Vector2.from_angle(turned) * speed
			position += _velocity * delta
		_:
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
	var r := body_radius()   # 🔴 히트박스와 같은 함수 — 보이는 크기 ≠ 맞는 크기가 되면 아무도 못 알아챈다
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
		var dir := -outward if g == Enums.GlyphCode.GATHER else outward   # 응집만 안쪽 · 발산·관통은 바깥
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
