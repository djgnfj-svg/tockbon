extends Node2D
## 프로토 필드 1장 — 장애물·적 스폰·채집 노드·출구 게이트·낮밤 (모듈 C). F6 단독 실행 가능.
## TileMap 없이 StaticBody2D+Polygon2D 플레이스홀더 (GDD §10.5 — 낮밤은 CanvasModulate+라이트).

const Util := preload("res://src/field/field_util.gd")
const PlayerScript := preload("res://src/field/player.gd")
const Spawner := preload("res://src/field/enemy_spawner.gd")
const GatherNodeScript := preload("res://src/field/gather_node.gd")
const ExitGateScript := preload("res://src/field/exit_gate.gd")

const MAP_SIZE := Vector2(1280, 832)
const WALL_THICKNESS := 24.0

## 페이즈별 CanvasModulate 색 — 낮/밤은 스프라이트 교체가 아니라 조명으로 (GDD §10.5)
const PHASE_COLORS := {
	Enums.Phase.MORNING: Color(1.0, 0.96, 0.88),
	Enums.Phase.DAY: Color(1.0, 1.0, 1.0),
	Enums.Phase.EVENING: Color(1.0, 0.78, 0.6),
	Enums.Phase.NIGHT: Color(0.22, 0.25, 0.42),
}

const ENEMY_SPAWNS := [
	{"id": &"vine", "pos": Vector2(280, 240)},
	{"id": &"vine", "pos": Vector2(880, 190)},
	{"id": &"hound", "pos": Vector2(980, 560)},
	{"id": &"hound", "pos": Vector2(300, 600)},
	{"id": &"slime", "pos": Vector2(560, 300)},
	{"id": &"slime", "pos": Vector2(620, 330)},
	{"id": &"slime", "pos": Vector2(680, 290)},
	{"id": &"slime", "pos": Vector2(590, 260)},
	{"id": &"slime_elite", "pos": Vector2(640, 170)},
	{"id": &"mist", "pos": Vector2(180, 420)},
	{"id": &"mist", "pos": Vector2(1080, 300)},
	{"id": &"beetle", "pos": Vector2(520, 490)},
]

const GATHER_SPAWNS := [
	{"item": &"mat_vine", "pos": Vector2(240, 700), "night": false},
	{"item": &"mat_mist_essence", "pos": Vector2(1050, 690), "night": false},
	{"item": &"mat_slime_core", "pos": Vector2(760, 420), "night": false},
	{"item": &"mat_night_bloom", "pos": Vector2(720, 130), "night": true},
	{"item": &"mat_moon_sap", "pos": Vector2(150, 150), "night": true},
]

const OBSTACLES := [
	{"pos": Vector2(420, 380), "size": Vector2(70, 40)},
	{"pos": Vector2(840, 470), "size": Vector2(50, 90)},
	{"pos": Vector2(200, 300), "size": Vector2(40, 40)},
	{"pos": Vector2(960, 200), "size": Vector2(90, 36)},
	{"pos": Vector2(560, 620), "size": Vector2(120, 30)},
]

var _modulate_node: CanvasModulate

func _ready() -> void:
	_build_ground_and_walls()
	_build_obstacles()
	_modulate_node = CanvasModulate.new()
	_modulate_node.color = PHASE_COLORS.get(Clock.phase, Color.WHITE)
	add_child(_modulate_node)
	EventBus.phase_changed.connect(_on_phase_changed)
	_spawn_player()
	_spawn_enemies()
	_spawn_gathers()
	_spawn_gate()

func _on_phase_changed(phase: int) -> void:
	if _modulate_node != null and PHASE_COLORS.has(phase):
		_modulate_node.color = PHASE_COLORS[phase]

func _spawn_player() -> void:
	var player: CharacterBody2D = PlayerScript.new()
	player.name = "Player"
	player.global_position = Vector2(640, 650)
	add_child(player)

func _spawn_enemies() -> void:
	for spawn: Dictionary in ENEMY_SPAWNS:
		var def: EnemyDef = Db.get_enemy(spawn["id"])
		if def == null:
			push_warning("field: EnemyDef 없음: %s (data/enemies/*.tres 생성 필요)" % spawn["id"])
			continue
		var enemy: CharacterBody2D = Spawner.spawn(def)
		enemy.global_position = spawn["pos"]
		add_child(enemy)

func _spawn_gathers() -> void:
	for g: Dictionary in GATHER_SPAWNS:
		var node: Variant = GatherNodeScript.new()
		node.item_id = g["item"]
		node.night_only = g["night"]
		node.global_position = g["pos"]
		add_child(node)

func _spawn_gate() -> void:
	var gate: Area2D = ExitGateScript.new()
	gate.name = "ExitGate"
	gate.global_position = Vector2(MAP_SIZE.x - 40.0, 416)
	add_child(gate)

func _build_ground_and_walls() -> void:
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(MAP_SIZE.x, 0), MAP_SIZE, Vector2(0, MAP_SIZE.y),
	])
	ground.color = Color(0.2, 0.3, 0.18)
	ground.z_index = -10
	add_child(ground)
	var half_w := MAP_SIZE.x * 0.5
	var half_h := MAP_SIZE.y * 0.5
	_make_wall(Vector2(half_w, -WALL_THICKNESS * 0.5), Vector2(MAP_SIZE.x, WALL_THICKNESS))
	_make_wall(Vector2(half_w, MAP_SIZE.y + WALL_THICKNESS * 0.5), Vector2(MAP_SIZE.x, WALL_THICKNESS))
	_make_wall(Vector2(-WALL_THICKNESS * 0.5, half_h), Vector2(WALL_THICKNESS, MAP_SIZE.y))
	_make_wall(Vector2(MAP_SIZE.x + WALL_THICKNESS * 0.5, half_h), Vector2(WALL_THICKNESS, MAP_SIZE.y))

func _make_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1    # world
	wall.position = pos
	Util.add_rect_collider(wall, size)
	Util.add_rect_visual(wall, size, Color(0.15, 0.2, 0.13))
	add_child(wall)

func _build_obstacles() -> void:
	for o: Dictionary in OBSTACLES:
		var rock := StaticBody2D.new()
		rock.collision_layer = 1
		rock.position = o["pos"]
		Util.add_rect_collider(rock, o["size"])
		Util.add_rect_visual(rock, o["size"], Color(0.32, 0.3, 0.26))
		add_child(rock)
