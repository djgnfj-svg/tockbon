extends Node
## 루트 씬 — 씬 전환 담당 (TECH_SPEC §7). 모듈은 EventBus.scene_change_requested로 전환을 요청한다.

const SCENES: Dictionary = {
	&"field": "res://src/field/field.tscn",
	&"base": "res://src/base/base.tscn",
	&"drawing": "res://src/drawing/drawing_room.tscn",
}

@onready var current_scene: Node = $CurrentScene

func _ready() -> void:
	EventBus.scene_change_requested.connect(change_scene)
	# 거점에서 시작 (씬이 아직 없으면 경고만)
	change_scene(&"base")

func change_scene(scene_id: StringName) -> void:
	var path: String = SCENES.get(scene_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("아직 준비되지 않은 씬: %s" % scene_id)
		return
	for child in current_scene.get_children():
		child.queue_free()
	var packed := load(path) as PackedScene
	current_scene.add_child(packed.instantiate())
