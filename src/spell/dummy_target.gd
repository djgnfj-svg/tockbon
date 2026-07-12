extends StaticBody2D
## 테스트 허수아비 — 적 노드 계약 검증 전용 (그룹 "enemies", 레이어 3, take_hit).
## 실제 적 구현은 모듈 C. 이 파일은 src/spell/ 내 테스트 보조로만 사용한다.

var hits: Array[Dictionary] = []

@onready var _visual: Polygon2D = $Visual

func _ready() -> void:
	add_to_group("enemies")

func take_hit(damage: float, rune_type: int, status: int, status_power: float) -> void:
	hits.append({
		"damage": damage,
		"rune_type": rune_type,
		"status": status,
		"status_power": status_power,
	})
	print("[DummyTarget] 피격 damage=%.2f rune=%d status=%d power=%.2f" % [
		damage, rune_type, status, status_power])
	_flash()

func _flash() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(_visual, "modulate", Color.WHITE, 0.25)
