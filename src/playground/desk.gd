extends Area2D
## 탁본 책상 — 플레이어가 가까이 오면 "[E] 탁본" 안내를 띄우고,
## interact(E) 입력에 그리기 오버레이를 연다. 여는 방식은 오버레이(베이스 위에 뜸).

signal interacted  ## 플레이어가 책상에서 E를 눌렀다 — 베이스가 그리기 오버레이를 연다

@onready var _prompt: Label = $Prompt

var _player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _prompt != null:
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		interacted.emit()

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_in_range = true
		if _prompt != null:
			_prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_in_range = false
		if _prompt != null:
			_prompt.visible = false
