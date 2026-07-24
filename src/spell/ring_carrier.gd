extends Area2D
## 고리 조립 캐리어 — 모듈 B (세션 12~). class_name 없음 — preload로 참조할 것.
##
## 🔴 **해석된 원소 마법이 날아간다** (세72 재정의 — GDD §3·§5). 마법진(공식)은 발사 순간 총구에
## 잠깐 빛나고(vfx 머즐 링 = "식이 계산되는 순간"), 날아가는 건 그것을 **해석한 원소 마법 = 불덩이
## (파이어볼)**다. 마법진 자체는 안 날아간다 — 세71까지의 "진이 곧 투사체(날아가는 마법진 볼)"를
## 은퇴시켰다(사용자: *"진이 날아갈 필요없는데… 마법진은 수학이고 해석된 마법이 나간다"*).
## 착탄 시 안의 고리(_ring)가 그 자리에서 전개되는 계약은 그대로다 — 껍질=배달. [[takbon-nested-circle-model]]
##   • 발산→ 칸: 그 화살표 방향으로 불 탄환이 퍼진다 (ring_spell_system이 projectile.tscn 스폰)
##   • 응집← 칸: 하나로 모여 불기둥 하나 (pillar.tscn, 많을수록 굵다)
##
## **빈 진도 날아가 몸으로 때린다** (열린 칸을 안 채워 전개할 게 없어도 — RingBoard.can_commit 항상 참).
##   → 캐리어 자체가 착탄 시 damage를 얹는다. 전개는 그 위에 덤이다.
##
## **전개는 적에 닿을 때만.** 벽·수명으로 죽으면 조용히 사라진다 (안 맞으면 전개 없음 — 데모 규칙).
## **node.rotation은 영원히 0** — 대신 자식 Fireball **스프라이트만** 진행 방향으로 회전한다(혜성형
## 꼬리가 뒤로 뻗게, 세72). 히트박스(자식 Shape)는 원형이라 회전 무관하지만, node를 안 돌려 계약을
## 지킨다(스프라이트 로컬 회전은 Shape에 영향 0).
##
## 적 노드 계약: 그룹 "enemies" + take_hit(damage, rune_type, status, status_power).

const RADIUS_PX := 12.0       # 히트박스 반지름 (진 몸) — 세13: 9→18(안 보였다) → 세72: 18→12
                              # (혜성 스프라이트+꼬리가 커서 축소. 꼬리 달린 스프라이트라 히트박스 작아도 잘 보인다)
## 부메랑 선회 각속도(rad/s) — 연출값이라 balance 아닌 여기 상수 (선례: juice의 손맛 수치).
## 8.0 = 180도 유턴에 약 0.4초. 낮추면 크게 휘고 높이면 칼같이 꺾인다 — 사용자가 쏴 보고 조인다.
const BOOMERANG_TURN_RATE := 8.0
## 트레일·룬 색이 Db에 룬이 없을 때 폴백 (vfx와 같은 규칙).
const RUNE_FALLBACK := Color(0.95, 0.35, 0.15)

const Trail := preload("res://src/spell/carrier_trail.gd")

# ── 트레일 연출 (세션59) — 손맛값(스크립트 const, balance 아님). 사용자가 쏴 보고 조인다.
const TRAIL_LIFE := 0.25          ## 트레일 포인트 수명(s)
const TRAIL_WIDTH_FRAC := 0.9     ## 트레일 굵기 = body_radius × 이 값
## 🔴 불덩이 **코어**의 반지름(px) — 혜성형 92×48 프레임, 코어 중심 (74,24), 반지름 14(나머지는
## 왼쪽 화염 꼬리 + 투명 패딩). body_radius를 **코어**에 맞춰 스케일해 **보이는 코어 = 히트박스**가
## 되게 한다(세50 "보이는 크기 ≠ 맞는 크기" — 코어 반지름을 안 쓰면 스침 판정이 거짓말). 코어 뒤로
## 뻗는 화염 꼬리가 히트박스를 넘는 건 당연(꼬리는 안 맞는 잔염 = 빛). 🔴 값은 F5로 조인다.
const SPRITE_FRAME_RADIUS := 14.0

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

## 불덩이 스프라이트 (씬 자식 Fireball) — 이글거림 루프는 SpriteFrames가 담당(자전·글로우 코드 제거).
var _fireball: AnimatedSprite2D = null
var _trail_spawned := false


func _ready() -> void:
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_fireball = get_node_or_null(^"Fireball") as AnimatedSprite2D
	if _fireball != null:
		_fireball.play(&"fireball")
	_apply_sprite_scale()


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
	_apply_sprite_scale()
	# 트레일은 지연 스폰 — set_motion(규모)이 setup **뒤에** 오므로, 굵기가 최종 body_radius를 보게.
	call_deferred(&"_spawn_trail")


## 🔴 비행 경로·규모를 얹는다 (세션48). setup **뒤에** 부른다 — 안 부르면 예전 그대로 직진 1.0배라
## 옛 호출자·테스트가 그대로 돈다. 진(JinDef)이 없는 옛 도안이 정확히 그 경로다.
func set_motion(p_motion: int, p_scale: float, p_spiral_amp: float,
		p_spiral_period: float, p_turn_ratio: float) -> void:
	_motion = p_motion
	_scale = maxf(p_scale, 0.1)
	_spiral_amp = p_spiral_amp
	_spiral_period = maxf(p_spiral_period, 0.05)
	_turn_ratio = clampf(p_turn_ratio, 0.05, 0.95)
	_apply_body_radius()
	_apply_sprite_scale()


## 히트박스를 진 몸 반지름에 맞춘다 (형상 리소스는 공유물 — scale로만 건드린다).
func _apply_body_radius() -> void:
	var cs := get_node_or_null("Shape") as CollisionShape2D
	if cs != null and cs.shape is CircleShape2D:
		cs.scale = Vector2.ONE * (body_radius() / (cs.shape as CircleShape2D).radius)


## 진 몸 반지름 — 규모가 곱해진다. 스프라이트·히트박스가 **같은 함수**를 봐야 갈라지지 않는다
## (선례: ring_power의 is_stable — 보이는 크기와 맞는 크기가 다르면 아무도 못 알아챈다).
func body_radius() -> float:
	return RADIUS_PX * _scale


## 불덩이 스프라이트를 body_radius에 맞춘다 — 프레임 반지름(24px)을 body_radius로 스케일.
## _ready(생성)·setup(룬 확정)·set_motion(규모 확정)이 부른다.
func _apply_sprite_scale() -> void:
	if _fireball != null:
		_fireball.scale = Vector2.ONE * (body_radius() / SPRITE_FRAME_RADIUS)


## 트레일 스폰 — **형제**(spell_system의 자식)로 단다. 캐리어가 착탄으로 죽어도 잔상이 페이드하게
## (설계 §2-C). 🔴 트레일은 player_projectiles 그룹 무가입 — 테스트가 이 그룹으로 탄을 센다.
func _spawn_trail() -> void:
	# 🔴 null 가드 — 트리 밖 setup(헤드리스가 setup만 부르는 경우)·부모 없음이면 조용히 생략
	if _trail_spawned or _consumed or not is_inside_tree():
		return
	var parent := get_parent()
	if parent == null:
		return
	_trail_spawned = true
	var trail := Trail.new()
	parent.add_child(trail)
	trail.setup(self, _rune_color(), body_radius() * TRAIL_WIDTH_FRAC, TRAIL_LIFE)


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
				# (세션48에 실제로 그렇게 났다). 각도만 돌리면 속력이 보존돼 나간 만큼의 기세로 돌아온다.
				var speed := _velocity.length()
				var want := (_origin - global_position).angle()
				var turned := rotate_toward(_velocity.angle(), want, BOOMERANG_TURN_RATE * delta)
				_velocity = Vector2.from_angle(turned) * speed
			position += _velocity * delta
		_:
			position += _velocity * delta
	# 🔴 스프라이트를 진행 방향으로 정렬(혜성형 — 꼬리가 뒤로). **스프라이트만** 돌린다: node.rotation·
	# 자식 히트박스는 0 불변. 이글거림·나부낌은 SpriteFrames 루프가 담당(옛 볼의 _spin·글로우 은퇴).
	if _fireball != null and _velocity.length_squared() > 0.01:
		_fireball.rotation = _velocity.angle()
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
	# "탄이 박혔다" 연출 신호 (세션59 설계 §3) — 적 착탄 1회만. 벽·수명 소멸(_die_without_deploy)엔 없다.
	EventBus.spell_impact.emit(global_position, rune_type)
	var travel := _velocity.angle() if not _velocity.is_zero_approx() else 0.0
	deployed.emit(_ring, global_position, travel)
	queue_free()


func _die_without_deploy() -> void:
	if _consumed:
		return
	_consumed = true
	queue_free()


## 룬 색 — Db에서 읽고, 없으면 폴백. (오토로드 없는 컨텍스트도 견딘다) 트레일 색이 이걸 쓴다.
func _rune_color() -> Color:
	var db := get_node_or_null(^"/root/Db")
	if db != null:
		var rune := db.get_rune(rune_type) as RuneDef
		if rune != null:
			return rune.ui_color
	return RUNE_FALLBACK
