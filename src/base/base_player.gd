extends CharacterBody2D
## 거점 임시 플레이어 — WASD 이동만 (모듈 D 플레이스홀더).
## 통합 시 모듈 C의 플레이어로 교체된다 (TEAM_PLAN Phase 2).

var _speed: float = 120.0

func _ready() -> void:
	_speed = GameState.balance.player_move_speed

func _physics_process(_delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = input * _speed
	move_and_slide()
