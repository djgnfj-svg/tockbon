extends Sprite2D
## 숲 나무 (세션46) — 단색 삼각형 Polygon2D → 도트 스프라이트 3종. **위치에 따라 변형을 랜덤**으로
## 골라 forest.tscn을 안 건드리고도 12개 인스턴스가 다 달라진다.
## 🔴 north(y<-500)=침엽수·마른나무(성긴 심층 = 어두운 바닥 그라디언트와 어울림) · south=활엽수·침엽수
##   (무성한 숲). 밑동(접지점 y=61, 시트 높이 64)이 노드 원점에 오게 offset은 씬에서 -29로 고정.
## randi = Godot 전역(부팅 시드) — 장식이라 세이브에 안 들어간다 (드롭 굴림과 같은 RNG).

const PINE := preload("res://assets/sprites/field/tree_pine.png")
const ROUND := preload("res://assets/sprites/field/tree_round.png")
const DEAD := preload("res://assets/sprites/field/tree_dead.png")


func _ready() -> void:
	# 북쪽 심층일수록 침엽수·마른나무, 남쪽은 활엽수·침엽수 (같은 값 둘 = 그쪽 가중치를 높인다).
	var pool: Array = [PINE, DEAD, PINE] if global_position.y < -500.0 else [ROUND, PINE, ROUND]
	texture = pool[randi() % pool.size()]
