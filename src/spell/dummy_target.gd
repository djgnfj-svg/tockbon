extends StaticBody2D
## 테스트 허수아비 — 적 노드 계약 검증 전용 (그룹 "enemies", collision_layer=4(enemy), take_hit).
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
	# 적 노드 계약: enemy_hit 발신은 take_hit 내부 책임 (실제 적은 약점 배율 반영 최종 피해로 발신)
	EventBus.enemy_hit.emit(self, damage, rune_type)
	_pop()

## 팝 — 흰 섬광 + 크기 펀치 (피격 손맛, 세션 38). 허수아비는 StaticBody라 넉백은 없다.
## forest_enemy._pop과 같은 연출 (연습장에서도 손맛이 같게).
func _pop() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(2.2, 2.2, 2.2)
	_visual.scale = Vector2(1.35, 1.35)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "modulate", Color.WHITE, 0.18)
	tween.tween_property(_visual, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
