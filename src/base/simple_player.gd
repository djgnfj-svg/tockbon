extends CharacterBody2D
## 최소 플레이어 — WASD로만 움직인다. 그게 전부.
## 과한 것(대시·공격·캐스트·애니·HP) 없음. 움직임 감각을 먼저 정한다.

@export var speed: float = 120.0

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()
