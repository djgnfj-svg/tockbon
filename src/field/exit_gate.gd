extends Area2D
## 출구 게이트 — 항상 열림. 플레이어 진입 시 extraction_success 발신 (GDD §7).

const Util := preload("res://src/field/field_util.gd")

var _triggered: bool = false

func _ready() -> void:
	add_to_group("exit_gates")
	collision_layer = 1 << 6    # 7 = interaction
	collision_mask = 1 << 1     # player
	Util.add_rect_collider(self, Vector2(28, 56))
	# 문기둥 2개 + 빛나는 아치 (플레이스홀더)
	Util.add_rect_visual(self, Vector2(28, 56), Color(0.85, 0.9, 0.75, 0.25))
	var left := Util.add_rect_visual(self, Vector2(6, 56), Color(0.5, 0.42, 0.3))
	left.position = Vector2(-11, 0)
	var right := Util.add_rect_visual(self, Vector2(6, 56), Color(0.5, 0.42, 0.3))
	right.position = Vector2(11, 0)
	body_entered.connect(_on_body_entered)
	body_exited.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_triggered = false)

func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	EventBus.extraction_success.emit()
