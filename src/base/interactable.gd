extends Area2D
## 거점 상호작용 지점 — 플레이어 접근 시 [E] 힌트 표시, interact 입력으로 시설 활성 (모듈 D).
## 물리 레이어: layer=7(interaction), mask=2(player).

signal activated(facility_id: StringName)

@export var facility_id: StringName
@export var title: String = ""

var _player_in := false

@onready var _hint: Label = get_node_or_null("Hint")

func _ready() -> void:
	body_entered.connect(func(_body: Node2D) -> void: _set_player_in(true))
	body_exited.connect(func(_body: Node2D) -> void: _set_player_in(false))
	if _hint != null:
		_hint.text = "[E] %s" % title
		_hint.visible = false

func _set_player_in(inside: bool) -> void:
	_player_in = inside
	if _hint != null:
		_hint.visible = inside

func _unhandled_input(event: InputEvent) -> void:
	if _player_in and event.is_action_pressed(&"interact"):
		activated.emit(facility_id)
		get_viewport().set_input_as_handled()
