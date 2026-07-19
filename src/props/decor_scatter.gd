extends Node2D
## 숲 장식 흩뿌리기 (세션46) — 덤불·바위·들꽃을 놀이 구역에 랜덤 배치. forest.tscn엔 노드 하나로 얹혀
## `_ready`에서 스스로 뿌린다(손배치 12개 대신 — 판마다 조금씩 다르고 손이 안 든다). 장식이라 물리·그룹 없음.
## 🔴 z_index 안 올린다(기본 0) → 씬 트리에서 Player보다 앞(위)에 두면 플레이어가 장식 위로 걸어간다.
##   접지 offset(밑동이 원점에 오게)은 스프라이트마다 다르다(크기 다름) — DECOR가 함께 쥔다.
## randf/randi = Godot 전역(부팅 시드) — 장식이라 세이브 무관.

const DECOR := [
	{"tex": preload("res://assets/sprites/field/bush.png"), "off": -10.0},
	{"tex": preload("res://assets/sprites/field/rock.png"), "off": -9.0},
	{"tex": preload("res://assets/sprites/field/flowers.png"), "off": -7.0},
]

## 몇 개 뿌릴지 · 뿌릴 사각 영역 (놀이 구역 = 남쪽 입구~북쪽 포털 회랑).
@export var count: int = 24
@export var area_min := Vector2(-560, -1180)
@export var area_max := Vector2(560, 440)


func _ready() -> void:
	for i in count:
		var d: Dictionary = DECOR[randi() % DECOR.size()]
		var s := Sprite2D.new()
		s.texture = d["tex"]
		s.offset = Vector2(0.0, float(d["off"]))
		s.position = Vector2(randf_range(area_min.x, area_max.x), randf_range(area_min.y, area_max.y))
		add_child(s)
