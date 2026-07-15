extends "res://src/field/enemy_base.gd"
## 중간보스 — 바람을 품은 존재 (GDD §7). 약점 불△ (v2.2: 충격 룬 폐지 — 바람 룬을 주는 보스라
## 자기 룬이 약점일 수 없어, 시작부터 쥐는 불로 옮겼다).
## 패턴: (a) 돌풍 밀치기 — 예열 텔레그래프 후 반경 내 플레이어 밀어냄+피해
##       (b) 회오리 투사체 — 플레이어 조준 3연발 (gale_whirlwind.gd)
##       (c) 체력 50% 이하 2페이즈 — 이동 속도·패턴 주기 격화
## 격파 시 엘리트 경로(enemy_base._die)로 fragment_wind 잔류물 + codex_unlocked(enemy_gale).

enum GaleState { NORMAL, GUST_WINDUP, VOLLEY }

const Whirlwind := preload("res://src/field/gale_whirlwind.gd")

# ── 패턴 수치 — 원장은 EnemyDef.params (data/enemies/gale.tres)
var gust_period: float = 3.0
var gust_windup: float = 0.8
var gust_radius: float = 90.0
var gust_damage: float = 8.0
var gust_push_dist: float = 70.0
var volley_period: float = 4.5
var volley_count: int = 3
var volley_interval: float = 0.25
var proj_speed: float = 170.0
var proj_damage: float = 6.0
var proj_lifetime: float = 2.8
var phase2_speed_mult: float = 1.3
## 2페이즈에서 패턴 주기에 곱하는 배율 (<1 = 빨라짐)
var phase2_rate_mult: float = 0.65

## 체력 50% 이하 격화 여부 — 테스트가 직접 확인
var phase2_active: bool = false

var _gale_state: GaleState = GaleState.NORMAL
var _gust_cd: float = 1.0
var _gust_timer: float = 0.0
var _volley_cd: float = 2.0
var _volley_left: int = 0
var _volley_timer: float = 0.0
var _telegraph: Line2D

func _init() -> void:
	move_speed = 55.0
	aggro_range = 260.0
	attack_range = 30.0
	attack_cooldown = 1.5
	contact_damage = 10.0
	weakness_mult = 1.6
	body_radius = 16.0
	body_color = Color(0.62, 0.78, 0.78)

func _apply_params(params: Dictionary) -> void:
	gust_period = float(params.get("gust_period", gust_period))
	gust_windup = float(params.get("gust_windup", gust_windup))
	gust_radius = float(params.get("gust_radius", gust_radius))
	gust_damage = float(params.get("gust_damage", gust_damage))
	gust_push_dist = float(params.get("gust_push_dist", gust_push_dist))
	volley_period = float(params.get("volley_period", volley_period))
	volley_count = int(params.get("volley_count", volley_count))
	volley_interval = float(params.get("volley_interval", volley_interval))
	proj_speed = float(params.get("proj_speed", proj_speed))
	proj_damage = float(params.get("proj_damage", proj_damage))
	proj_lifetime = float(params.get("proj_lifetime", proj_lifetime))
	phase2_speed_mult = float(params.get("phase2_speed_mult", phase2_speed_mult))
	phase2_rate_mult = float(params.get("phase2_rate_mult", phase2_rate_mult))

func _build_body() -> void:
	super._build_body()
	if _anim_sprite == null:
		# 몸통 소용돌이 무늬 — 시트 없는 환경의 플레이스홀더 (◎ 무늬는 시트에 포함)
		var swirl := Line2D.new()
		var pts := PackedVector2Array()
		for i in range(20):
			var t := float(i) / 19.0
			pts.append(Vector2.from_angle(t * TAU * 1.6) * (2.0 + t * 10.0))
		swirl.points = pts
		swirl.width = 1.5
		swirl.default_color = Color(0.92, 0.98, 0.95, 0.8)
		add_child(swirl)
	# 돌풍 예열 텔레그래프 링 — 엘리트 scale(1.35)을 보정해 월드 반경과 일치시킨다
	_telegraph = Line2D.new()
	_telegraph.points = Util.circle_points(gust_radius / maxf(scale.x, 0.01), 28)
	_telegraph.closed = true
	_telegraph.width = 2.0
	_telegraph.default_color = Color(0.8, 0.95, 1.0, 0.0)
	_telegraph.visible = false
	add_child(_telegraph)

func take_hit(damage: float, rune_type: int, status: int, status_power: float) -> void:
	super.take_hit(damage, rune_type, status, status_power)
	_check_phase2()

func _update_ai(delta: float) -> void:
	_check_phase2()   # 화상 틱 등 take_hit 밖의 피해도 페이즈 전환에 반영
	var p := _get_player()
	if p == null:
		_state = State.IDLE
		_gale_state = GaleState.NORMAL
		_ai_velocity = Vector2.ZERO
		_hide_telegraph()
		return
	_gust_cd = maxf(_gust_cd - delta, 0.0)
	_volley_cd = maxf(_volley_cd - delta, 0.0)
	var dist := global_position.distance_to(p.global_position)
	match _gale_state:
		GaleState.NORMAL:
			if dist <= gust_radius and _gust_cd <= 0.0:
				_gale_state = GaleState.GUST_WINDUP
				_gust_timer = gust_windup
				_state = State.ATTACK
				_ai_velocity = Vector2.ZERO
				_telegraph.visible = true
			elif dist > gust_radius and dist <= aggro_range and _volley_cd <= 0.0:
				_gale_state = GaleState.VOLLEY
				_volley_left = volley_count
				_volley_timer = 0.0
				_state = State.ATTACK
				_ai_velocity = Vector2.ZERO
			elif dist > aggro_range:
				_state = State.IDLE
				_ai_velocity = Vector2.ZERO
			elif dist > attack_range:
				_state = State.CHASE
				_ai_velocity = global_position.direction_to(p.global_position) * move_speed
			else:
				_state = State.ATTACK
				_ai_velocity = Vector2.ZERO
				if _attack_cd <= 0.0:
					_attack_cd = attack_cooldown
					_do_attack(p)
		GaleState.GUST_WINDUP:
			_ai_velocity = Vector2.ZERO
			_gust_timer -= delta
			# 예열 진행에 따라 링이 진해진다 (시각 텔레그래프)
			_telegraph.default_color.a = 0.25 + 0.55 * (1.0 - maxf(_gust_timer, 0.0) / gust_windup)
			if _gust_timer <= 0.0:
				_do_gust(p)
				_hide_telegraph()
				_gale_state = GaleState.NORMAL
				_gust_cd = gust_period
		GaleState.VOLLEY:
			_ai_velocity = Vector2.ZERO
			_volley_timer -= delta
			if _volley_timer <= 0.0 and _volley_left > 0:
				_volley_left -= 1
				_volley_timer = volley_interval
				_fire_whirlwind(p)
			if _volley_left <= 0:
				_gale_state = GaleState.NORMAL
				_volley_cd = volley_period

## 돌풍 방출 — 예열 중 반경을 벗어났으면 헛방 (대시 회피가 카운터플레이)
func _do_gust(p: Node2D) -> void:
	if global_position.distance_to(p.global_position) > gust_radius:
		return
	var dir := global_position.direction_to(p.global_position)
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	if p is PhysicsBody2D:
		(p as PhysicsBody2D).move_and_collide(dir * gust_push_dist)
	else:
		p.global_position += dir * gust_push_dist
	if p.has_method("take_damage"):
		p.call("take_damage", gust_damage * night_mult)

func _fire_whirlwind(p: Node2D) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var dir := global_position.direction_to(p.global_position)
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var wind: Variant = Whirlwind.new()
	wind.damage = proj_damage * night_mult
	wind.dir = dir
	wind.speed = proj_speed
	wind.lifetime_sec = proj_lifetime
	wind.global_position = global_position + dir * (body_radius * scale.x + 6.0)
	parent.add_child(wind)

func _check_phase2() -> void:
	if phase2_active or hp <= 0.0 or max_hp <= 0.0:
		return
	if hp <= max_hp * 0.5:
		phase2_active = true
		move_speed *= phase2_speed_mult
		gust_period *= phase2_rate_mult
		volley_period *= phase2_rate_mult
		modulate = Color(1.0, 0.9, 0.82)   # 격화 표시 (플레이스홀더)

func _hide_telegraph() -> void:
	if _telegraph != null:
		_telegraph.visible = false

func _anim_key() -> String:
	match _gale_state:
		GaleState.GUST_WINDUP:
			return "gust"
		GaleState.VOLLEY:
			return "volley"
	return "idle"

func _post_death() -> void:
	# 격파 팝 — 간결한 바람 burst (GDD §2: 처치 연출은 무겁지 않게)
	var parent := get_parent()
	if parent != null:
		var burst := CPUParticles2D.new()
		burst.one_shot = true
		burst.emitting = true
		burst.amount = 24
		burst.lifetime = 0.6
		burst.explosiveness = 1.0
		burst.spread = 180.0
		burst.initial_velocity_min = 60.0
		burst.initial_velocity_max = 150.0
		burst.color = Color(0.78, 0.93, 0.9)
		burst.global_position = global_position
		burst.finished.connect(burst.queue_free)
		parent.add_child.call_deferred(burst)
	# NOTE(EA — GDD §9): 중간보스 격파 후 '에필로그 탐색' 진입 트리거 지점.
	# EA에서 리드가 scene_change_requested(&"epilogue") 연결 예정 — 지금은 표식만 남긴다.
