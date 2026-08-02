extends Area2D
## 고리 조립 캐리어 — 날아가는 것은 마법진이 아니라 그것을 **해석한 원소 마법(불덩이)**이다.
## class_name 없음 — preload로 참조할 것.
##
## 🔴 `_ring`은 **층 배열** `[[8칸], [8칸]…]`이고 캐리어는 이걸 **해석하지 않는다** — 불투명한
## payload로 나르기만 한다. ⚠ `_ring[0]`을 칸으로 읽지 마라(2등급 진에선 그게 배열이다).
## **빈 진도 날아가 몸으로 때린다** — 캐리어 자체가 착탄 damage를 얹고, 전개는 그 위에 덤이다.
## **전개는 적에 닿을 때만** — 벽·수명으로 죽으면 조용히 사라진다.
## 🔴 **node.rotation은 영원히 0** — 방향 정렬은 자식 Fireball 스프라이트만 돌린다(히트박스 불변).
##
## 적 노드 계약: 그룹 "enemies" + take_hit(damage, rune_type, status, status_power).

const RADIUS_PX := 12.0       # 히트박스 반지름 — 꼬리 달린 스프라이트라 작아도 잘 보인다
## 부메랑 선회 각속도(rad/s) — 연출값이라 balance 아닌 여기 상수. 8.0 = 180도 유턴에 약 0.4초.
const BOOMERANG_TURN_RATE := 8.0
## Db에 룬이 없을 때만 쓰는 폴백.
const RUNE_FALLBACK := Color(0.95, 0.35, 0.15)

const Trail := preload("res://src/spell/carrier_trail.gd")

# ── 트레일 연출 — 손맛값(스크립트 const, balance 아님).
const TRAIL_LIFE := 0.25          ## 트레일 포인트 수명(s)
const TRAIL_WIDTH_FRAC := 0.9     ## 트레일 굵기 = body_radius × 이 값
## 🔴 프레임(92×48)이 아니라 불덩이 **코어**의 반지름이다 — 이걸로 스케일해야 보이는 코어 = 히트박스가
## 된다(프레임 크기를 쓰면 뒤로 뻗는 화염 꼬리까지 세어 스침 판정이 거짓말한다).
const SPRITE_FRAME_RADIUS := 14.0

## 착탄 = 안의 고리를 편다. travel = 탄이 가던 방향(전개 회전 기준).
## ⚠ 인자 이름 `ring`은 시그널 계약이라 유지한다 — 실려 오는 건 **층 배열**이다.
signal deployed(ring: Array, at: Vector2, travel: float)

var damage: float = 0.0
var rune_type: int = Enums.RuneType.FIRE
var status: int = Enums.Status.NONE
var status_power: float = 0.0
## 복합 룬 [{rune_type, status, status_power}] — primary 외는 **피해 0**으로 상태만 얹는다
## (적 계약의 0-피해 가드가 도배를 막는다).
var rune_hits: Array = []
## 이 진의 조립 점수(0~1) — **착탄 연출 전용**이다.
## ⚠ 피해엔 이미 `damage`로 반영돼 있다 — 여기서 다시 곱하면 이중 적용이 된다.
var score: float = 0.0

var _ring: Array = []
var _velocity := Vector2.ZERO
var _life_left: float = 0.0
var _consumed := false

# 비행 경로. motion=STRAIGHT면 아래 필드는 전부 안 쓰인다.
var _motion: int = Enums.JinMotion.STRAIGHT
var _scale: float = 1.0
var _age: float = 0.0            # 발사 후 경과 — 나선 위상·부메랑 반환 시점의 기준
var _lifetime: float = 0.0       # 처음 받은 수명 (부메랑이 반환 시점을 재는 데 쓴다)
var _origin := Vector2.ZERO      # 발사 지점 — 부메랑이 돌아올 목표
var _spiral_amp: float = 0.0
var _spiral_period: float = 0.45
var _turn_ratio: float = 0.5

## 원소 볼 스프라이트 — 이글거림 루프는 SpriteFrames가 담당한다(코드 자전·글로우 없음).
var _fireball: AnimatedSprite2D = null
var _trail_spawned := false

## 룬→볼 애니. 전부 같은 92×48 혜성 지오메트리라 오프셋·히트박스·회전은 애니와 무관하다.
const BALL_ANIM := {
	Enums.RuneType.FIRE:  &"fireball",
	Enums.RuneType.WATER: &"waterball",
	Enums.RuneType.WIND:  &"windball",
	Enums.RuneType.BOLT:  &"boltball",
	Enums.RuneType.EARTH: &"earthball",
	Enums.RuneType.GRASS: &"grassball",
}


func _ready() -> void:
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_fireball = get_node_or_null(^"Fireball") as AnimatedSprite2D
	_apply_ball_anim()   # 이 시점엔 rune_type이 기본값 — setup에서 룬 확정 후 다시 부른다
	_apply_sprite_scale()


## 🔴 fireball 폴백을 지우지 마라 — 없는 애니를 play하면 볼이 **에러 없이 투명해진다**.
func _apply_ball_anim() -> void:
	if _fireball == null or _fireball.sprite_frames == null:
		return
	var want: StringName = BALL_ANIM.get(rune_type, &"fireball")
	if not _fireball.sprite_frames.has_animation(want):
		want = &"fireball"
	_fireball.play(want)


## p_ring: **층 배열** `[[8칸]…]` — 캐리어는 내용을 안 본다.
func setup(p_ring: Array, p_angle: float, p_speed: float, p_lifetime: float,
		p_damage: float, p_rune_type: int, p_status: int, p_status_power: float,
		p_rune_hits: Array = [], p_score: float = 0.0) -> void:
	_ring = p_ring.duplicate()
	_velocity = Vector2.RIGHT.rotated(p_angle) * p_speed
	_life_left = maxf(p_lifetime, 0.05)
	_lifetime = _life_left
	_origin = global_position
	damage = p_damage
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	rune_hits = p_rune_hits
	score = p_score
	_apply_ball_anim()
	_apply_body_radius()
	_apply_sprite_scale()
	# 🔴 트레일은 지연 스폰 — set_motion(규모)이 setup **뒤에** 와야 굵기가 최종 body_radius를 본다.
	call_deferred(&"_spawn_trail")


## 비행 경로·규모를 얹는다. setup **뒤에** 부른다 — 안 부르면 직진 1.0배로 남는다.
func set_motion(p_motion: int, p_scale: float, p_spiral_amp: float,
		p_spiral_period: float, p_turn_ratio: float) -> void:
	_motion = p_motion
	_scale = maxf(p_scale, 0.1)
	_spiral_amp = p_spiral_amp
	_spiral_period = maxf(p_spiral_period, 0.05)
	_turn_ratio = clampf(p_turn_ratio, 0.05, 0.95)
	_apply_body_radius()
	_apply_sprite_scale()


## 🔴 형상 리소스는 인스턴스끼리 공유한다 — radius 대신 scale로만 건드린다.
func _apply_body_radius() -> void:
	var cs := get_node_or_null("Shape") as CollisionShape2D
	if cs != null and cs.shape is CircleShape2D:
		cs.scale = Vector2.ONE * (body_radius() / (cs.shape as CircleShape2D).radius)


## 진 몸 반지름 — 🔴 스프라이트·히트박스가 **같은 함수**를 봐야 보이는 크기와 맞는 크기가 안 갈라진다.
func body_radius() -> float:
	return RADIUS_PX * _scale


func _apply_sprite_scale() -> void:
	if _fireball != null:
		_fireball.scale = Vector2.ONE * (body_radius() / SPRITE_FRAME_RADIUS)


## 🔴 트레일은 자식이 아니라 **형제**로 단다 — 캐리어가 착탄으로 죽어도 잔상이 페이드해야 한다.
func _spawn_trail() -> void:
	# 트리 밖 setup(헤드리스)·부모 없음이면 조용히 생략
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
			# 🔴 위치를 직접 찍지 않고 속도에 수직 성분을 더한다 — 순간이동하면 충돌이 건너뛴다.
			var perp := _velocity.orthogonal().normalized()
			var w := TAU / _spiral_period
			var swing := perp * (_spiral_amp * _scale) * w * cos(w * _age)
			position += (_velocity + swing) * delta
		Enums.JinMotion.BOOMERANG:
			# 반환 시점을 넘기면 발사 지점 쪽으로 속도를 꺾는다 — 유턴이 곡선으로 그려진다.
			if _age >= _lifetime * _turn_ratio:
				# 🔴 속도를 **회전**시킨다 — `lerp`면 정반대 벡터끼리 상쇄돼 속도가 0으로 죽고
				# 진이 공중에 멈춘다. 각도만 돌리면 속력이 보존된다.
				var speed := _velocity.length()
				var want := (_origin - global_position).angle()
				var turned := rotate_toward(_velocity.angle(), want, BOOMERANG_TURN_RATE * delta)
				_velocity = Vector2.from_angle(turned) * speed
			position += _velocity * delta
		_:
			position += _velocity * delta
	# 🔴 **스프라이트만** 돌린다 — node.rotation·자식 히트박스는 0 불변이 계약이다.
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
		# 보조 룬은 피해 0으로 상태만 얹는다.
		for rh: Dictionary in rune_hits:
			if int(rh.get("rune_type", -1)) == rune_type:
				continue   # primary는 위에서 이미 얹었다
			node.take_hit(0.0, int(rh.rune_type), int(rh.status), float(rh.status_power))
	# 적 착탄 1회만 — 벽·수명 소멸엔 없다. 🔴 `score`가 착탄 연출이 등급을 아는 유일한 통로다.
	EventBus.spell_impact.emit(global_position, rune_type, score)
	var travel := _velocity.angle() if not _velocity.is_zero_approx() else 0.0
	deployed.emit(_ring, global_position, travel)
	queue_free()


func _die_without_deploy() -> void:
	if _consumed:
		return
	_consumed = true
	queue_free()


func _rune_color() -> Color:
	var db := get_node_or_null(^"/root/Db")
	if db != null:
		var rune := db.get_rune(rune_type) as RuneDef
		if rune != null:
			return rune.ui_color
	return RUNE_FALLBACK
