extends Node2D
## 모듈 B 인터랙티브 테스트 — tests/test_spell.tscn 루트 (F6 실행).
## 키 1/2/3 = 샘플 도안 발사(노바/산탄/물의 창), 마우스 = 조준, 키 4 = 마나·내구 회복.

var designs: Array[SpellDesign] = SampleDesigns.all()

@onready var _caster: Marker2D = $Caster
@onready var _info: Label = $UiLayer/Info

func _ready() -> void:
	EventBus.cast_executed.connect(_on_cast_executed)
	EventBus.cast_failed.connect(_on_cast_failed)

func _unhandled_input(event: InputEvent) -> void:
	for i in range(designs.size()):
		if event.is_action_pressed("cast_slot_%d" % (i + 1)):
			var aim := (get_global_mouse_position() - _caster.global_position).normalized()
			EventBus.cast_requested.emit(designs[i], _caster.global_position, aim)
	if event.is_action_pressed("cast_slot_4"):
		GameState.restore_mana_full()
		for d: SpellDesign in designs:
			d.durability = d.durability_max
		print("[TestSpell] 마나·내구 회복")

func _process(_delta: float) -> void:
	_info.text = "1=노바(불)  2=산탄(충격)  3=물의 창  4=회복  마우스=조준\n마나 %.0f / %.0f\n내구  노바 %d · 산탄 %d · 창 %d" % [
		GameState.mana, GameState.balance.mana_max,
		designs[0].durability, designs[1].durability, designs[2].durability]
	queue_redraw()

func _draw() -> void:
	# 발사 지점과 에임 방향 표시 (루트가 원점이므로 전역=로컬)
	var from := _caster.position
	var aim := (get_global_mouse_position() - _caster.global_position).normalized()
	draw_line(from, from + aim * 40.0, Color(1, 1, 1, 0.4), 1.0)
	draw_circle(from, 3.0, Color(0.9, 0.9, 1.0))

func _on_cast_executed(design: SpellDesign, mana_spent: float) -> void:
	print("[TestSpell] cast_executed: %s (마나 %.0f, 내구 %d)" % [
		design.display_name, mana_spent, design.durability])

func _on_cast_failed(design: SpellDesign, reason: int) -> void:
	var reason_name: String = Enums.CastFailReason.keys()[reason]
	print("[TestSpell] cast_failed: %s — %s" % [
		design.display_name if design != null else "(null)", reason_name])
