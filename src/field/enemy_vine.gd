extends "res://src/field/enemy_base.gd"
## 재생 덩굴 — 고정형·자가 재생, 약점 불△ (화상이 재생을 정지시킨다) (GDD §7).

## 초당 재생량 — 화상 중에는 정지
var regen_per_sec: float = 2.5

func _apply_params(params: Dictionary) -> void:
	regen_per_sec = float(params.get("regen_per_sec", regen_per_sec))

func _init() -> void:
	move_speed = 0.0
	aggro_range = 80.0
	attack_range = 46.0
	attack_cooldown = 1.2
	contact_damage = 6.0
	weakness_mult = 1.75
	body_radius = 11.0
	body_color = Color(0.25, 0.55, 0.25)

func simulate(delta: float, apply_motion: bool = true) -> void:
	if _state != State.DEAD and not is_burning():
		hp = minf(hp + regen_per_sec * delta, max_hp)
	super.simulate(delta, apply_motion)

func _update_ai(_delta: float) -> void:
	# 고정형 — 이동 없이 사거리 내 가시 공격만
	_ai_velocity = Vector2.ZERO
	var p := _get_player()
	if p == null:
		_state = State.IDLE
		return
	if global_position.distance_to(p.global_position) <= attack_range:
		_state = State.ATTACK
		if _attack_cd <= 0.0:
			_attack_cd = attack_cooldown
			_do_attack(p)
	else:
		_state = State.IDLE

func _anim_key() -> String:
	if _state == State.ATTACK:
		return "attack"
	# 재생 중 표시 — 화상이면 재생이 멎으니 idle (약점 카운터의 시각 언어)
	if hp < max_hp and not is_burning():
		return "regen"
	return "idle"
