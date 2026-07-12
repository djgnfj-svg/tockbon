extends "res://src/field/enemy_base.gd"
## 숲 사냥개 — 예열 후 직선 돌진, 약점 충격> (넉백이 돌진을 끊는다) (GDD §7).

enum ChargeState { NORMAL, WINDUP, DASH, RECOVER }

var charge_trigger_range: float = 120.0
var charge_speed: float = 330.0
var windup_sec: float = 0.5
var dash_sec: float = 0.4
var recover_sec: float = 0.8

var _charge_state: ChargeState = ChargeState.NORMAL
var _charge_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _dash_hit_done: bool = false

func _apply_params(params: Dictionary) -> void:
	charge_trigger_range = float(params.get("charge_trigger_range", charge_trigger_range))
	charge_speed = float(params.get("charge_speed", charge_speed))
	windup_sec = float(params.get("windup_sec", windup_sec))
	dash_sec = float(params.get("dash_sec", dash_sec))
	recover_sec = float(params.get("recover_sec", recover_sec))

func _init() -> void:
	move_speed = 95.0
	aggro_range = 220.0
	attack_range = 20.0
	attack_cooldown = 1.0
	contact_damage = 8.0
	weakness_mult = 1.75
	body_radius = 8.0
	body_color = Color(0.5, 0.35, 0.2)

func _update_ai(delta: float) -> void:
	var p := _get_player()
	if p == null:
		_state = State.IDLE
		_charge_state = ChargeState.NORMAL
		_ai_velocity = Vector2.ZERO
		return
	var dist := global_position.distance_to(p.global_position)
	match _charge_state:
		ChargeState.NORMAL:
			if dist > aggro_range:
				_state = State.IDLE
				_ai_velocity = Vector2.ZERO
			elif dist <= charge_trigger_range:
				_charge_state = ChargeState.WINDUP
				_charge_timer = windup_sec
				_charge_dir = global_position.direction_to(p.global_position)
				_state = State.ATTACK
				_ai_velocity = Vector2.ZERO
			else:
				_state = State.CHASE
				_ai_velocity = global_position.direction_to(p.global_position) * move_speed
		ChargeState.WINDUP:
			_ai_velocity = Vector2.ZERO
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.DASH
				_charge_timer = dash_sec
				_dash_hit_done = false
				_charge_dir = global_position.direction_to(p.global_position)
		ChargeState.DASH:
			_ai_velocity = _charge_dir * charge_speed
			_charge_timer -= delta
			if not _dash_hit_done and dist <= body_radius + 12.0:
				_dash_hit_done = true
				_do_attack(p)
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.RECOVER
				_charge_timer = recover_sec
		ChargeState.RECOVER:
			_ai_velocity = Vector2.ZERO
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.NORMAL

func _apply_status(status: int, power: float) -> void:
	super._apply_status(status, power)
	# 충격 넉백 = 돌진 캔슬 (약점 룬의 기계적 카운터)
	if status == Enums.Status.KNOCKBACK and _charge_state != ChargeState.NORMAL:
		_charge_state = ChargeState.RECOVER
		_charge_timer = recover_sec
