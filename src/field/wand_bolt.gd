extends Area2D
## 기본 완드 약공격 투사체 — 마나 0·소형 단발 (모듈 C 소유 — 마법진 투사체는 모듈 B).
## 레이어 4(player_projectile), 월드·적과 충돌.

const Util := preload("res://src/field/field_util.gd")

var damage: float = 4.0
var dir: Vector2 = Vector2.RIGHT
var speed: float = 320.0
var lifetime_sec: float = 0.8

func _ready() -> void:
	add_to_group("player_projectiles")      # 모듈 B 투사체와 동일 그룹 규약
	collision_layer = 1 << 3                # 4 = player_projectile
	collision_mask = (1 << 0) | (1 << 2)    # world + enemy
	Util.add_circle_collider(self, 3.0)
	Util.add_circle_visual(self, 3.0, Color(0.9, 0.9, 0.75))
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += dir * speed * delta
	lifetime_sec -= delta
	if lifetime_sec <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_hit"):
		# 완드 평타는 룬 없음(-1) — 약점 배율·상태이상 미적용
		body.call("take_hit", damage, -1, Enums.Status.NONE, 0.0)
	queue_free()
