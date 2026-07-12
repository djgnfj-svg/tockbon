extends Area2D
## 드롭 픽업 — 플레이어 접촉 시 GameState.add_to_bag (모듈 C).
## 레이어 6(pickup). 아이템 ID는 모듈 D 합의 규약을 따른다.

const Util := preload("res://src/field/field_util.gd")

var item_id: StringName = &""
var count: int = 1

func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 1 << 5    # 6 = pickup
	collision_mask = 1 << 1     # player
	Util.add_circle_collider(self, 10.0)
	# 아이템별 고정 색상 (id 해시 → 색) 플레이스홀더
	var h := float(hash(item_id) % 360) / 360.0
	Util.add_rect_visual(self, Vector2(7, 7), Color.from_hsv(h, 0.55, 0.9))
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	GameState.add_to_bag(item_id, count)
	queue_free()
