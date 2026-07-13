extends Node
## 루트 씬 — 씬 전환·전역 흐름 배선 (TECH_SPEC §7). 모듈은 EventBus.scene_change_requested로 전환을 요청한다.

const SCENES: Dictionary = {
	&"field": "res://src/field/field.tscn",
	&"base": "res://src/base/base.tscn",
	&"drawing": "res://src/drawing/drawing_room.tscn",
}

@onready var current_scene: Node = $CurrentScene

func _input(event: InputEvent) -> void:
	# F11 / Alt+Enter — 전체화면 토글. stretch=viewport라 UI·게임 전체가 창 크기를 따라 스케일된다
	if event.is_action_pressed(&"toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()

func _ready() -> void:
	EventBus.scene_change_requested.connect(change_scene)
	# 귀환·사망 모두 거점으로 (가방 처리·손실은 GameState가 시그널로 이미 수행)
	EventBus.extraction_success.connect(func() -> void: change_scene(&"base"))
	EventBus.player_died.connect(func() -> void: change_scene(&"base"))
	if not SaveManager.load_game():
		_seed_new_game()
	change_scene(&"base")

func change_scene(scene_id: StringName) -> void:
	# 시그널 처리 중(발신 노드가 현재 씬 안) 씬 해제가 안전하도록 지연 실행
	_change_scene_now.call_deferred(scene_id)

func _change_scene_now(scene_id: StringName) -> void:
	var path: String = SCENES.get(scene_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("아직 준비되지 않은 씬: %s" % scene_id)
		return
	for child in current_scene.get_children():
		child.queue_free()
	var packed := load(path) as PackedScene
	current_scene.add_child(packed.instantiate())
	EventBus.scene_changed.emit(scene_id)

## 새 게임 시작 물자 (GDD §5 — 빈손 시작 방지). 세이브가 없을 때만 호출된다.
## **도안은 지급하지 않는다** — 첫 도안은 튜토리얼에서 플레이어가 직접 그린 파이어볼이다.
## 스승이 남기고 간 것: 갈아 둔 먹, 종이 몇 장, 낡은 장비 한 벌.
func _seed_new_game() -> void:
	GameState.add_item(&"ink_basic", 20)
	GameState.add_item(&"paper_1", 5)   # 튜토 1장 + 실패·재시도 여유
	GameState.add_item(&"wand_basic", 1)
	GameState.add_item(&"robe_basic", 1)
	GameState.add_item(&"charm_basic", 1)
	for gear_id: StringName in [&"wand_basic", &"robe_basic", &"charm_basic"]:
		GameState.equip_gear(gear_id)
