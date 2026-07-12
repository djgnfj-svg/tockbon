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
	SaveManager.load_game()  # 세이브 없으면 false → 아래 시드가 새 게임 구성
	_seed_prototype()
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

## 프로토 시드 — 튜토리얼(4개월차) 구현 전까지의 시작 물자·도안 (GDD §5 시작 물자)
func _seed_prototype() -> void:
	if GameState.designs.is_empty():
		GameState.designs = SampleDesigns.all()
		for i in range(mini(GameState.designs.size(), GameState.EQUIP_SLOTS)):
			GameState.equip(i, GameState.designs[i])
	if GameState.get_count(&"ink_basic") == 0:
		GameState.add_item(&"ink_basic", 20)
		GameState.add_item(&"paper_1", 3)
		GameState.add_item(&"wand_basic", 1)
		GameState.add_item(&"robe_basic", 1)
		GameState.add_item(&"charm_basic", 1)
	# 시작 장비 자동 착용 (GDD §5 시작 물자 — 세이브에 장비가 없을 때만)
	if GameState.equipment.is_empty():
		for gear_id: StringName in [&"wand_basic", &"robe_basic", &"charm_basic"]:
			if GameState.get_count(gear_id) > 0:
				GameState.equip_gear(gear_id)
