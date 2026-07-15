extends StaticBody2D
## 오두막 마당의 짚 허수아비 — 시험 발사 표적 (모듈 D, GDD §7 "밤 [거점] … 시험 발사").
##
## 적 노드 계약(그룹 "enemies" + take_hit)을 구현하지만 **죽지 않는다**: 맞으면 흔들리고
## 피해 숫자만 띄운다. 명중은 EventBus.training_hit으로 알린다 (튜토리얼 판정용).
##
## enemy_hit / enemy_died는 발신하지 않는다 — 도감·퀘스트·HUD가 이걸 "적"으로 오인하면
## 첫 처치 해금이나 퀘스트 단계가 거점에서 엉뚱하게 진행된다.
## 물리 레이어: layer = 1(world) | 3(enemy) — 투사체(마스크 world|enemy)에 맞고, 몸으로도 막힌다.

const STRAW := Color(0.827, 0.678, 0.376)
const STRAW_DARK := Color(0.616, 0.478, 0.259)
const POLE := Color(0.451, 0.322, 0.208)
const CLOTH := Color(0.788, 0.749, 0.667)
const SEAL := Color(0.710, 0.278, 0.180)

## 룬별 피해 숫자 색 — projectile.gd RUNE_COLORS와 동일 톤
const RUNE_COLORS: Dictionary = {
	Enums.RuneType.FIRE: Color(1.0, 0.55, 0.1),
	Enums.RuneType.WATER: Color(0.25, 0.55, 1.0),
	Enums.RuneType.WIND: Color(0.65, 0.95, 0.45),
}

var _body: Node2D
var _shake: Tween


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = (1 << 0) | (1 << 2)   # world + enemy
	collision_mask = 0
	_build_visual()
	_build_collider()


## 적 노드 계약 — 투사체가 호출한다 (projectile.gd _handle_collision)
func take_hit(damage: float, rune_type: int, _status: int, _status_power: float) -> void:
	EventBus.training_hit.emit(rune_type, damage)
	_play_shake()
	_pop_damage(damage, RUNE_COLORS.get(rune_type, Color.WHITE))


# ─────────────────────────── 연출 ───────────────────────────

func _play_shake() -> void:
	if _body == null:
		return
	if _shake != null and _shake.is_valid():
		_shake.kill()
	_body.rotation = 0.0
	_shake = create_tween()
	for angle: float in [0.22, -0.16, 0.09, 0.0]:
		_shake.tween_property(_body, "rotation", angle, 0.07)


func _pop_damage(damage: float, color: Color) -> void:
	var label := Label.new()
	label.text = "%d" % roundi(damage)
	label.add_theme_font_size_override(&"font_size", 10)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.09, 0.08, 0.07))
	label.add_theme_constant_override(&"outline_size", 3)
	label.position = Vector2(-6, -30)
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", -46.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


# ─────────────────────────── 조립 (코드 생성 — 전용 스프라이트 없음) ───────────────────────────

func _build_visual() -> void:
	# 흔들리는 부분만 따로 묶는다 (기둥은 고정, 몸통이 휘청인다)
	var pole := Polygon2D.new()
	pole.polygon = PackedVector2Array([
		Vector2(-2, -6), Vector2(2, -6), Vector2(2, 14), Vector2(-2, 14)])
	pole.color = POLE
	add_child(pole)

	_body = Node2D.new()
	_body.name = "Body"
	add_child(_body)

	var arms := Polygon2D.new()   # 가로 막대 (팔)
	arms.polygon = PackedVector2Array([
		Vector2(-13, -14), Vector2(13, -14), Vector2(13, -10), Vector2(-13, -10)])
	arms.color = POLE
	_body.add_child(arms)

	var torso := Polygon2D.new()  # 짚단 몸통
	torso.polygon = PackedVector2Array([
		Vector2(-7, -12), Vector2(7, -12), Vector2(6, 4), Vector2(-6, 4)])
	torso.color = STRAW
	_body.add_child(torso)

	var belt := Polygon2D.new()   # 허리 새끼줄
	belt.polygon = PackedVector2Array([
		Vector2(-7, -3), Vector2(7, -3), Vector2(7, -1), Vector2(-7, -1)])
	belt.color = STRAW_DARK
	_body.add_child(belt)

	var head := Polygon2D.new()   # 천을 씌운 머리
	head.polygon = PackedVector2Array([
		Vector2(-5, -22), Vector2(5, -22), Vector2(5, -13), Vector2(-5, -13)])
	head.color = CLOTH
	_body.add_child(head)

	var mark := Polygon2D.new()   # 가슴의 붉은 표적 점 — 여기를 노려라
	mark.polygon = PackedVector2Array([
		Vector2(-2, -9), Vector2(2, -9), Vector2(2, -5), Vector2(-2, -5)])
	mark.color = SEAL
	_body.add_child(mark)

	var tag := Label.new()
	tag.text = "허수아비"
	tag.add_theme_font_size_override(&"font_size", 10)
	tag.position = Vector2(-30, 16)
	tag.size = Vector2(60, 14)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tag)


func _build_collider() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 26)
	shape.shape = rect
	shape.position = Vector2(0, -8)
	add_child(shape)
