extends "res://src/field/enemy_base.gd"
## 수액 슬라임 — 다수 소형·사망 시 분열. 약점 룬 없음(배율 1.0) = 다발 도안이 답 (GDD §7).
## 엘리트(def.is_elite): 크고 느림, fragment_water 잔류물 (GDD §6 — 물 룬 해독 경로).

const MINI_HP_FRAC := 0.4
const SPLIT_COUNT := 2

func _init() -> void:
	move_speed = 55.0
	aggro_range = 160.0
	attack_range = 18.0
	attack_cooldown = 0.9
	contact_damage = 4.0
	weakness_mult = 1.0     # 약점 없음 — counter_rune은 게시판 표기용일 뿐 배율 미적용
	body_radius = 7.0
	body_color = Color(0.75, 0.7, 0.3)

func _ready() -> void:
	if def != null and def.is_elite:
		move_speed = 45.0
		contact_damage = 7.0
		body_radius = 13.0
		body_color = Color(0.65, 0.6, 0.25)
	if is_mini:
		contact_damage = 2.0
	super._ready()
	if is_mini:
		_base_max_hp *= MINI_HP_FRAC
		max_hp = _base_max_hp * night_mult
		hp = max_hp

func _post_death() -> void:
	if is_mini:
		return
	var parent := get_parent()
	if parent == null:
		return
	for i in range(SPLIT_COUNT):
		var mini: Variant = (get_script() as GDScript).new()
		mini.def = def
		mini.is_mini = true
		mini.ai_enabled = ai_enabled
		mini.global_position = global_position + Vector2.from_angle(TAU * float(i) / SPLIT_COUNT) * 10.0
		parent.add_child.call_deferred(mini)
