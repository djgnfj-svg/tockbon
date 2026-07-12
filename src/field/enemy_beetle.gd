extends "res://src/field/enemy_base.gd"
## 갑주 갑충 — 장갑 피해 감소, WET(젖음)가 갑주를 무력화. 약점 물~ (GDD §7, §4.2).

## 장갑 피해 감소율 — 젖음 상태가 아니면 받는 피해의 70% 경감
var armor_reduction: float = 0.7

func _apply_params(params: Dictionary) -> void:
	armor_reduction = float(params.get("armor_reduction", armor_reduction))

func _init() -> void:
	move_speed = 40.0
	aggro_range = 170.0
	attack_range = 24.0
	attack_cooldown = 1.4
	contact_damage = 9.0
	weakness_mult = 1.75
	body_radius = 12.0
	body_color = Color(0.25, 0.3, 0.5)

func _apply_defense(dmg: float, _rune_type: int) -> float:
	if not has_status(Enums.Status.WET):
		return dmg * (1.0 - armor_reduction)
	return dmg
