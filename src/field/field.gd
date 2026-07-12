extends Node2D
## 프로토 필드 1장 — 장애물·적 스폰·채집 노드·출구 게이트·낮밤 (모듈 C). F6 단독 실행 가능.
## TileMap 없이 StaticBody2D+Polygon2D 플레이스홀더 (GDD §10.5 — 낮밤은 CanvasModulate+라이트).

const Util := preload("res://src/field/field_util.gd")
const PlayerScript := preload("res://src/field/player.gd")
const Spawner := preload("res://src/field/enemy_spawner.gd")
const GatherNodeScript := preload("res://src/field/gather_node.gd")
const ExitGateScript := preload("res://src/field/exit_gate.gd")
const BossIntro := preload("res://src/field/boss_intro.gd")

const MAP_SIZE := Vector2(1280, 832)
const WALL_THICKNESS := 24.0

## 지형 타일러블 텍스처 (ART_SPEC P3 경량판 — TileMap 도입 전, Polygon2D repeat로 적용)
const TEX_GRASS := "res://assets/sprites/field/tile_grass.png"
const TEX_BOSS_FLOOR := "res://assets/sprites/field/tile_boss_floor.png"
const TEX_BUSH := "res://assets/sprites/field/tile_bush.png"
const TEX_ROCK := "res://assets/sprites/field/tile_rock.png"

## 북쪽 보스 존 — 중간보스(바람을 품은 존재) 격리 구역. 남쪽 경계(y=0)의
## BOSS_GATE_X 구간만 뚫려 입구가 된다. 바닥 색으로 본 필드와 구분.
const BOSS_ZONE := Rect2(440, -420, 400, 420)
## 북쪽 벽에서 비워 두는 입구 x 구간 (min, max)
const BOSS_GATE_X := Vector2(576, 704)

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
	{"id": &"gale", "pos": Vector2(640, -240)},   # 중간보스 — 북쪽 보스 존
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
var _boss_node: Node2D

func _ready() -> void:
	_build_ground_and_walls()
	_build_obstacles()
	_build_boss_zone()
	_modulate_node = CanvasModulate.new()
	_modulate_node.color = PHASE_COLORS.get(Clock.phase, Color.WHITE)
	add_child(_modulate_node)
	EventBus.phase_changed.connect(_on_phase_changed)
	_spawn_player()
	_spawn_enemies()
	_spawn_gathers()
	_spawn_gate()
	_spawn_boss_intro()

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
		if spawn["id"] == &"gale":
			_boss_node = enemy

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

## 보스 등장 컷 트리거 — 보스 존 입구(BOSS_GATE_X 구간) 첫 통과 시 1회 재생 (boss_intro.gd)
func _spawn_boss_intro() -> void:
	if _boss_node == null:
		return
	var intro: Variant = BossIntro.new()
	intro.name = "BossIntro"
	intro.boss = _boss_node
	intro.modulate_node = _modulate_node
	intro.global_position = Vector2((BOSS_GATE_X.x + BOSS_GATE_X.y) * 0.5, -20.0)
	add_child(intro)

## 타일러블 텍스처 적용 — 없으면(미임포트) 기존 단색 플레이스홀더 유지
func _apply_tile_tex(poly: Polygon2D, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	poly.texture = load(path)
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	poly.color = Color.WHITE

func _build_ground_and_walls() -> void:
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(MAP_SIZE.x, 0), MAP_SIZE, Vector2(0, MAP_SIZE.y),
	])
	ground.color = Color(0.2, 0.3, 0.18)
	ground.z_index = -10
	_apply_tile_tex(ground, TEX_GRASS)
	add_child(ground)
	var half_w := MAP_SIZE.x * 0.5
	var half_h := MAP_SIZE.y * 0.5
	# 북쪽 벽 — 보스 존 입구(BOSS_GATE_X)만 비우고 좌우 두 조각으로
	_make_wall(Vector2(BOSS_GATE_X.x * 0.5, -WALL_THICKNESS * 0.5),
		Vector2(BOSS_GATE_X.x, WALL_THICKNESS))
	_make_wall(Vector2((BOSS_GATE_X.y + MAP_SIZE.x) * 0.5, -WALL_THICKNESS * 0.5),
		Vector2(MAP_SIZE.x - BOSS_GATE_X.y, WALL_THICKNESS))
	_make_wall(Vector2(half_w, MAP_SIZE.y + WALL_THICKNESS * 0.5), Vector2(MAP_SIZE.x, WALL_THICKNESS))
	_make_wall(Vector2(-WALL_THICKNESS * 0.5, half_h), Vector2(WALL_THICKNESS, MAP_SIZE.y))
	_make_wall(Vector2(MAP_SIZE.x + WALL_THICKNESS * 0.5, half_h), Vector2(WALL_THICKNESS, MAP_SIZE.y))

func _make_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1    # world
	wall.position = pos
	Util.add_rect_collider(wall, size)
	var visual := Util.add_rect_visual(wall, size, Color(0.15, 0.2, 0.13))
	_apply_tile_tex(visual, TEX_BUSH)
	add_child(wall)

func _build_obstacles() -> void:
	for o: Dictionary in OBSTACLES:
		var rock := StaticBody2D.new()
		rock.collision_layer = 1
		rock.position = o["pos"]
		Util.add_rect_collider(rock, o["size"])
		var visual := Util.add_rect_visual(rock, o["size"], Color(0.32, 0.3, 0.26))
		_apply_tile_tex(visual, TEX_ROCK)
		add_child(rock)

## 북쪽 보스 존 — 바닥 색으로 구분되는 격리 구역 + 입구 표식.
## 남쪽 벽은 _build_ground_and_walls의 북쪽 벽 두 조각이 겸한다 (입구 구간만 개방).
func _build_boss_zone() -> void:
	var floor_poly := Polygon2D.new()
	floor_poly.polygon = PackedVector2Array([
		BOSS_ZONE.position,
		BOSS_ZONE.position + Vector2(BOSS_ZONE.size.x, 0),
		BOSS_ZONE.end,
		BOSS_ZONE.position + Vector2(0, BOSS_ZONE.size.y),
	])
	floor_poly.color = Color(0.21, 0.28, 0.32)   # 바람 기운의 냉색 — 본 필드(녹색)와 구분
	floor_poly.z_index = -10
	_apply_tile_tex(floor_poly, TEX_BOSS_FLOOR)
	add_child(floor_poly)
	# 존 외벽 3면 (서·동·북)
	_make_wall(Vector2(BOSS_ZONE.position.x - WALL_THICKNESS * 0.5, BOSS_ZONE.get_center().y),
		Vector2(WALL_THICKNESS, BOSS_ZONE.size.y))
	_make_wall(Vector2(BOSS_ZONE.end.x + WALL_THICKNESS * 0.5, BOSS_ZONE.get_center().y),
		Vector2(WALL_THICKNESS, BOSS_ZONE.size.y))
	_make_wall(Vector2(BOSS_ZONE.get_center().x, BOSS_ZONE.position.y - WALL_THICKNESS * 0.5),
		Vector2(BOSS_ZONE.size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	# 입구 표식 — 통로 바닥 띠 + 바람 소용돌이 문양
	var strip := Polygon2D.new()
	strip.polygon = PackedVector2Array([
		Vector2(BOSS_GATE_X.x, -WALL_THICKNESS), Vector2(BOSS_GATE_X.y, -WALL_THICKNESS),
		Vector2(BOSS_GATE_X.y, WALL_THICKNESS), Vector2(BOSS_GATE_X.x, WALL_THICKNESS),
	])
	strip.color = Color(0.45, 0.6, 0.62, 0.8)
	strip.z_index = -9
	add_child(strip)
	var swirl := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(24):
		var t := float(i) / 23.0
		pts.append(Vector2.from_angle(t * TAU * 2.0) * (3.0 + t * 13.0))
	swirl.points = pts
	swirl.width = 2.0
	swirl.default_color = Color(0.75, 0.92, 0.95, 0.9)
	swirl.position = Vector2((BOSS_GATE_X.x + BOSS_GATE_X.y) * 0.5, -64)
	add_child(swirl)
	# NOTE(EA — GDD §9): 보스 격파 후 '에필로그 탐색' 진입 트리거 지점 — 존 북쪽 끝.
	# EA에서 리드가 scene_change_requested 게이트를 여기(BOSS_ZONE 북단)에 배치한다.
