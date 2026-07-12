extends "res://src/field/enemy_base.gd"
## 안개 정령 — 부유·산개, 약점 바람◎ (GDD §7).
## 산개(dispersed) 상태에서는 바람 이외 피해 65% 감소 — 바람 룬만 온전히 박힌다.

## 산개 중 비(非)바람 피해 배율
var dispersed_resist: float = 0.35
var disperse_period: float = 2.5
var hover_min: float = 55.0
var hover_max: float = 95.0
## 산개 상태 — 주기 토글. 테스트에서 직접 설정해 저항 검증
var dispersed: bool = false

var _disperse_timer: float = 0.0

func _init() -> void:
	move_speed = 70.0
	aggro_range = 200.0
	attack_range = 30.0
	attack_cooldown = 1.1
	contact_damage = 5.0
	weakness_mult = 2.0
	body_radius = 9.0
	body_color = Color(0.75, 0.8, 0.9)

func _ready() -> void:
	super._ready()
	collision_mask = 0        # 부유 — 지형을 통과해 떠다닌다
	_disperse_timer = disperse_period
	_refresh_alpha()

func _apply_params(params: Dictionary) -> void:
	dispersed_resist = float(params.get("dispersed_resist", dispersed_resist))
	disperse_period = float(params.get("disperse_period", disperse_period))
	hover_min = float(params.get("hover_min", hover_min))
	hover_max = float(params.get("hover_max", hover_max))

func _apply_defense(dmg: float, rune_type: int) -> float:
	if dispersed and rune_type != Enums.RuneType.WIND:
		return dmg * dispersed_resist
	return dmg

func _update_ai(delta: float) -> void:
	_disperse_timer -= delta
	if _disperse_timer <= 0.0:
		_disperse_timer = disperse_period
		dispersed = not dispersed
		_refresh_alpha()
	var p := _get_player()
	if p == null:
		_state = State.IDLE
		_ai_velocity = Vector2.ZERO
		return
	var to_p := p.global_position - global_position
	var dist := to_p.length()
	if dist > aggro_range:
		_state = State.IDLE
		_ai_velocity = Vector2.ZERO
		return
	var dir := to_p.normalized()
	var radial := 0.0
	if dist > hover_max:
		radial = 1.0
	elif dist < hover_min:
		radial = -1.0
	# 접선 성분으로 흐르듯 배회 (산개·부유 연출)
	var tangent := Vector2(-dir.y, dir.x) * sin(float(Time.get_ticks_msec()) / 400.0)
	_ai_velocity = dir * radial * move_speed + tangent * move_speed * 0.6
	if dist <= attack_range:
		_state = State.ATTACK
		if _attack_cd <= 0.0:
			_attack_cd = attack_cooldown
			_do_attack(p)
	else:
		_state = State.CHASE

func _refresh_alpha() -> void:
	modulate.a = 0.45 if dispersed else 0.9

func _anim_key() -> String:
	return "scatter" if dispersed else "gather"
