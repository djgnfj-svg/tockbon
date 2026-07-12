extends Area2D
## 회오리 투사체 — 중간보스(바람을 품은 존재) 전용 3연발 (모듈 C).
## 레이어 5(enemy_projectile), 마스크 2(player). 접촉 시 player.take_damage 호출.

const Util := preload("res://src/field/field_util.gd")

var damage: float = 6.0
var dir: Vector2 = Vector2.RIGHT
var speed: float = 170.0
var lifetime_sec: float = 2.8

var _swirl: Line2D

func _ready() -> void:
	add_to_group("enemy_projectiles")
	collision_layer = 1 << 4                # 5 = enemy_projectile
	collision_mask = 1 << 1                 # 2 = player
	Util.add_circle_collider(self, 5.0)
	Util.add_circle_visual(self, 5.0, Color(0.72, 0.88, 0.86, 0.75))
	# 회전하는 소용돌이 선 (플레이스홀더)
	_swirl = Line2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var t := float(i) / 11.0
		pts.append(Vector2.from_angle(t * TAU * 1.5) * (1.5 + t * 5.0))
	_swirl.points = pts
	_swirl.width = 1.2
	_swirl.default_color = Color(0.95, 1.0, 0.98, 0.9)
	add_child(_swirl)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += dir * speed * delta
	_swirl.rotation += 9.0 * delta
	lifetime_sec -= delta
	if lifetime_sec <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.call("take_damage", damage)
	queue_free()
