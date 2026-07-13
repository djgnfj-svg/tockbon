extends Node2D
## 프로토 필드 1장 — 장애물·적 스폰·채집 노드·출구 게이트·낮밤 (모듈 C). F6 단독 실행 가능.
## 지형: tileset_field.png 임포트 시 TileMapLayer 4장(정식 16×16 타일셋, ART_SPEC P3),
## 없으면 StaticBody2D+Polygon2D 경량판 폴백 (GDD §10.5 — 낮밤은 CanvasModulate+라이트).

const Util := preload("res://src/field/field_util.gd")
const PlayerScript := preload("res://src/field/player.gd")
const Spawner := preload("res://src/field/enemy_spawner.gd")
const GatherNodeScript := preload("res://src/field/gather_node.gd")
const ExitGateScript := preload("res://src/field/exit_gate.gd")
const BossIntro := preload("res://src/field/boss_intro.gd")

const MAP_SIZE := Vector2(1280, 832)
const WALL_THICKNESS := 24.0

## 지형 타일러블 텍스처 (ART_SPEC P3 경량판 — 타일셋 미임포트 시 폴백 경로에서 사용)
const TEX_GRASS := "res://assets/sprites/field/tile_grass.png"
const TEX_BOSS_FLOOR := "res://assets/sprites/field/tile_boss_floor.png"
const TEX_BUSH := "res://assets/sprites/field/tile_bush.png"
const TEX_ROCK := "res://assets/sprites/field/tile_rock.png"

## 정식 16×16 타일셋 (ART_SPEC P3) — 존재하면 TileMapLayer 지형, 없으면 Polygon2D 폴백
const TILESET_PATH := "res://assets/sprites/field/tileset_field.png"
const TILE_SOURCE_ID := 0
const TILE_PX := 16
## 지형 배치 seed 고정 — 매 실행 동일한 맵
const TERRAIN_SEED := 20260713

## 아틀라스 좌표 계약 (128×48px, 8열×3행 — 리드 확정, 변경 금지)
const T_GRASS_A := Vector2i(0, 0)
const T_GRASS_B := Vector2i(1, 0)
const T_GRASS_TUFT := Vector2i(2, 0)
const T_GRASS_FLOWER := Vector2i(3, 0)
const T_BOSS_A := Vector2i(4, 0)
const T_BOSS_B := Vector2i(5, 0)
const T_BOSS_RUNE := Vector2i(6, 0)
const T_GATE_STRIP := Vector2i(7, 0)
const T_BUSH_A := Vector2i(0, 1)
const T_BUSH_B := Vector2i(1, 1)
const T_BUSH_TOP := Vector2i(2, 1)
const T_ROCK := Vector2i(3, 1)
const T_STONE_A := Vector2i(4, 1)
const T_STONE_B := Vector2i(5, 1)
const T_TREE_A_CANOPY := Vector2i(6, 1)
const T_TREE_B_CANOPY := Vector2i(7, 1)
const T_TREE_A_TRUNK := Vector2i(6, 2)
const T_TREE_B_TRUNK := Vector2i(7, 2)

const USED_TILES: Array[Vector2i] = [
	T_GRASS_A, T_GRASS_B, T_GRASS_TUFT, T_GRASS_FLOWER,
	T_BOSS_A, T_BOSS_B, T_BOSS_RUNE, T_GATE_STRIP,
	T_BUSH_A, T_BUSH_B, T_BUSH_TOP, T_ROCK, T_STONE_A, T_STONE_B,
	T_TREE_A_CANOPY, T_TREE_B_CANOPY, T_TREE_A_TRUNK, T_TREE_B_TRUNK,
]
## 전체 16×16 충돌 박스 타일 (물리 계약)
const SOLID_TILES: Array[Vector2i] = [
	T_BUSH_A, T_BUSH_B, T_BUSH_TOP, T_STONE_A, T_STONE_B, T_ROCK,
]
## 둥치 충돌 박스 (-4,0)~(4,8) 타일
const TRUNK_TILES: Array[Vector2i] = [T_TREE_A_TRUNK, T_TREE_B_TRUNK]

## 북쪽 보스 존 — 중간보스(바람을 품은 존재) 격리 구역. 남쪽 경계(y=0)의
## BOSS_GATE_X 구간만 뚫려 입구가 된다. 바닥 색으로 본 필드와 구분.
## 16px 타일 정렬: 셀 x 27..52, y -26..-1
const BOSS_ZONE := Rect2(432, -416, 416, 416)
## 북쪽 벽에서 비워 두는 입구 x 구간 (min, max) — 셀 x 36..43
const BOSS_GATE_X := Vector2(576, 704)

## 페이즈별 CanvasModulate 색 — 낮/밤은 스프라이트 교체가 아니라 조명으로 (GDD §10.5)
const PHASE_COLORS := {
	Enums.Phase.MORNING: Color(1.0, 0.96, 0.88),
	Enums.Phase.DAY: Color(1.0, 1.0, 1.0),
	Enums.Phase.EVENING: Color(1.0, 0.78, 0.6),
	Enums.Phase.NIGHT: Color(0.22, 0.25, 0.42),
}

const PLAYER_SPAWN := Vector2(640, 650)
const EXIT_GATE_POS := Vector2(MAP_SIZE.x - 40.0, 416.0)

## 나무 배치 (타일 경로) — 그루 수·클리어런스(px)
const TREE_EDGE_COUNT := 27
const TREE_INNER_COUNT := 8
const TREE_CLEAR_ENEMY := 56.0
const TREE_CLEAR_GATHER := 48.0
const TREE_CLEAR_PLAYER := 80.0
const TREE_CLEAR_EXIT := 96.0
const TREE_CLEAR_OBSTACLE := 24.0
## 보스존 게이트 통로 접근 구간 — 나무 배치 금지
const GATE_CORRIDOR_RECT := Rect2(560, -48, 160, 128)

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
	if ResourceLoader.exists(TILESET_PATH):
		_build_terrain_tiles()
		_build_obstacles()
	else:
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
	player.global_position = PLAYER_SPAWN
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
	gate.global_position = EXIT_GATE_POS
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
	_add_entrance_swirl()
	# NOTE(EA — GDD §9): 보스 격파 후 '에필로그 탐색' 진입 트리거 지점 — 존 북쪽 끝.
	# EA에서 리드가 scene_change_requested 게이트를 여기(BOSS_ZONE 북단)에 배치한다.

## 입구 바람 소용돌이 문양 — 타일·폴백 양 경로 공용
func _add_entrance_swirl() -> void:
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

## ── 정식 타일 지형 (ART_SPEC P3) ─────────────────────────────────────────
## tileset_field.png 임포트 시에만 실행. TileMapLayer 4장:
## Ground(z-10, 바닥) / Walls(z-9, 물리 벽) / Trunks(z0, 나무 둥치) / Canopy(z1, 캐노피).
## 플레이어는 Trunks 다음에 add되어 둥치 위·캐노피 아래에 그려진다.
## 배치는 TERRAIN_SEED 고정 — 매 실행 동일한 맵.

func _build_terrain_tiles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TERRAIN_SEED
	var ts := _make_tileset()
	var ground := _make_tile_layer("Ground", -10, ts)
	var walls := _make_tile_layer("Walls", -9, ts)
	var trunks := _make_tile_layer("Trunks", 0, ts)
	var canopy := _make_tile_layer("Canopy", 1, ts)
	_fill_ground(ground, rng)
	_fill_walls(walls, rng)
	_plant_trees(trunks, canopy, walls, rng)
	# 입구 바닥 띠는 gate_strip 타일이 대체 — 소용돌이 문양만 유지
	_add_entrance_swirl()

func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_PX, TILE_PX)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)   # world
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load(TILESET_PATH)
	src.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	ts.add_source(src, TILE_SOURCE_ID)
	for coords: Vector2i in USED_TILES:
		src.create_tile(coords)
	var half := TILE_PX * 0.5
	var full_box := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	for coords: Vector2i in SOLID_TILES:
		_set_tile_collision(src, coords, full_box)
	# 둥치는 아랫부분만 막는다 — 캐노피 밑을 지나다닐 수 있게 (타일 로컬, 중심 원점)
	var trunk_box := PackedVector2Array([
		Vector2(-4, 0), Vector2(4, 0), Vector2(4, 8), Vector2(-4, 8),
	])
	for coords: Vector2i in TRUNK_TILES:
		_set_tile_collision(src, coords, trunk_box)
	return ts

func _set_tile_collision(src: TileSetAtlasSource, coords: Vector2i, points: PackedVector2Array) -> void:
	var td: TileData = src.get_tile_data(coords, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, points)

func _make_tile_layer(layer_name: String, z: int, ts: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = ts
	layer.z_index = z
	add_child(layer)
	return layer

## BOSS_ZONE의 셀 좌표 (x 27..52, y -26..-1 — 16px 정렬 보장됨)
func _boss_cells() -> Rect2i:
	return Rect2i(Vector2i(BOSS_ZONE.position) / TILE_PX, Vector2i(BOSS_ZONE.size) / TILE_PX)

## 게이트 개방 셀 x 구간 [x, y) — 셀 36..43
func _gate_cell_range() -> Vector2i:
	return Vector2i(int(BOSS_GATE_X.x) / TILE_PX, int(BOSS_GATE_X.y) / TILE_PX)

func _fill_ground(ground: TileMapLayer, rng: RandomNumberGenerator) -> void:
	var field_w := int(MAP_SIZE.x) / TILE_PX
	var field_h := int(MAP_SIZE.y) / TILE_PX
	for cy in range(field_h):
		for cx in range(field_w):
			ground.set_cell(Vector2i(cx, cy), TILE_SOURCE_ID, _pick_grass(rng))
	var boss := _boss_cells()
	for cy in range(boss.position.y, boss.end.y):
		for cx in range(boss.position.x, boss.end.x):
			ground.set_cell(Vector2i(cx, cy), TILE_SOURCE_ID, _pick_boss_floor(rng))
	# 게이트 통로 (y -1..0) — 본 필드·보스존 바닥 위에 덮어쓰기
	var gate := _gate_cell_range()
	for cy in range(-1, 1):
		for cx in range(gate.x, gate.y):
			ground.set_cell(Vector2i(cx, cy), TILE_SOURCE_ID, T_GATE_STRIP)

func _fill_walls(walls: TileMapLayer, rng: RandomNumberGenerator) -> void:
	var field_w := int(MAP_SIZE.x) / TILE_PX
	var field_h := int(MAP_SIZE.y) / TILE_PX
	var gate := _gate_cell_range()
	# 남쪽 — 필드에 면한 최전열(y=field_h)은 밝은 윗면
	for cx in range(-2, field_w + 2):
		walls.set_cell(Vector2i(cx, field_h), TILE_SOURCE_ID, T_BUSH_TOP)
		walls.set_cell(Vector2i(cx, field_h + 1), TILE_SOURCE_ID, _pick_bush(rng))
	# 서·동 — 세로 벽은 밝은 윗면(bush_top) 없이 일반 수풀만 (밑단 음영이 사다리 무늬를 만듦)
	for cy in range(-1, field_h):
		walls.set_cell(Vector2i(-2, cy), TILE_SOURCE_ID, _pick_bush(rng))
		walls.set_cell(Vector2i(-1, cy), TILE_SOURCE_ID, _pick_bush(rng))
		walls.set_cell(Vector2i(field_w, cy), TILE_SOURCE_ID, _pick_bush(rng))
		walls.set_cell(Vector2i(field_w + 1, cy), TILE_SOURCE_ID, _pick_bush(rng))
	# 북쪽 (본 필드↔보스존 경계) — 게이트 열은 양 행 모두 개방.
	# 보스존 남쪽 바닥 두 줄(y -2..-1)이 벽에 덮이는 것은 의도된 것.
	for cx in range(-2, field_w + 2):
		if cx >= gate.x and cx < gate.y:
			continue
		walls.set_cell(Vector2i(cx, -2), TILE_SOURCE_ID, _pick_bush(rng))
		walls.set_cell(Vector2i(cx, -1), TILE_SOURCE_ID, T_BUSH_TOP)
	# 보스존 외벽 — 돌벽 (서·동 2열 y -27..-3 + 북쪽 2행 y -28..-27)
	var boss := _boss_cells()
	for cy in range(boss.position.y - 1, -2):
		for cx: int in [boss.position.x - 2, boss.position.x - 1, boss.end.x, boss.end.x + 1]:
			walls.set_cell(Vector2i(cx, cy), TILE_SOURCE_ID, _pick_stone(rng))
	for cx in range(boss.position.x - 2, boss.end.x + 2):
		walls.set_cell(Vector2i(cx, boss.position.y - 2), TILE_SOURCE_ID, _pick_stone(rng))
		walls.set_cell(Vector2i(cx, boss.position.y - 1), TILE_SOURCE_ID, _pick_stone(rng))

## 나무 배치 — 가장자리 밴드 위주 + 내부 소량. 스폰·게이트·장애물 클리어런스 확보.
func _plant_trees(trunks: TileMapLayer, canopy: TileMapLayer, walls: TileMapLayer,
		rng: RandomNumberGenerator) -> void:
	var occupied: Dictionary = {}
	var placed := 0
	var attempts := 0
	while placed < TREE_EDGE_COUNT and attempts < 600:
		attempts += 1
		if _try_place_tree(_random_edge_cell(rng), trunks, canopy, walls, occupied, rng):
			placed += 1
	placed = 0
	attempts = 0
	while placed < TREE_INNER_COUNT and attempts < 400:
		attempts += 1
		var cell := Vector2i(rng.randi_range(6, 73), rng.randi_range(6, 45))
		if _try_place_tree(cell, trunks, canopy, walls, occupied, rng):
			placed += 1

## 맵 테두리에서 1~3셀 이내 밴드의 랜덤 셀
func _random_edge_cell(rng: RandomNumberGenerator) -> Vector2i:
	var field_w := int(MAP_SIZE.x) / TILE_PX
	var field_h := int(MAP_SIZE.y) / TILE_PX
	var depth := rng.randi_range(1, 3)
	match rng.randi_range(0, 3):
		0:
			return Vector2i(rng.randi_range(1, field_w - 2), depth)
		1:
			return Vector2i(rng.randi_range(1, field_w - 2), field_h - 1 - depth)
		2:
			return Vector2i(depth, rng.randi_range(1, field_h - 2))
		_:
			return Vector2i(field_w - 1 - depth, rng.randi_range(1, field_h - 2))

func _try_place_tree(cell: Vector2i, trunks: TileMapLayer, canopy: TileMapLayer,
		walls: TileMapLayer, occupied: Dictionary, rng: RandomNumberGenerator) -> bool:
	var top := cell + Vector2i.UP   # 캐노피는 둥치 바로 위 셀
	if occupied.has(cell) or occupied.has(top):
		return false
	if walls.get_cell_source_id(cell) != -1 or walls.get_cell_source_id(top) != -1:
		return false
	var world := Vector2(cell.x * TILE_PX + TILE_PX * 0.5, cell.y * TILE_PX + TILE_PX * 0.5)
	if not _tree_spot_clear(world):
		return false
	var use_a := rng.randf() < 0.5
	trunks.set_cell(cell, TILE_SOURCE_ID, T_TREE_A_TRUNK if use_a else T_TREE_B_TRUNK)
	canopy.set_cell(top, TILE_SOURCE_ID, T_TREE_A_CANOPY if use_a else T_TREE_B_CANOPY)
	occupied[cell] = true
	occupied[top] = true
	return true

## 스폰 지점(사망 드롭·잔류물도 그 근방) 및 통로·장애물과의 간섭 검사
func _tree_spot_clear(world: Vector2) -> bool:
	for spawn: Dictionary in ENEMY_SPAWNS:
		if world.distance_to(spawn["pos"] as Vector2) < TREE_CLEAR_ENEMY:
			return false
	for g: Dictionary in GATHER_SPAWNS:
		if world.distance_to(g["pos"] as Vector2) < TREE_CLEAR_GATHER:
			return false
	if world.distance_to(PLAYER_SPAWN) < TREE_CLEAR_PLAYER:
		return false
	if world.distance_to(EXIT_GATE_POS) < TREE_CLEAR_EXIT:
		return false
	if GATE_CORRIDOR_RECT.has_point(world):
		return false
	for o: Dictionary in OBSTACLES:
		var r := Rect2((o["pos"] as Vector2) - (o["size"] as Vector2) * 0.5, o["size"] as Vector2)
		if r.grow(TREE_CLEAR_OBSTACLE).has_point(world):
			return false
	return true

func _pick_grass(rng: RandomNumberGenerator) -> Vector2i:
	var roll := rng.randf()
	if roll < 0.55:
		return T_GRASS_A
	if roll < 0.90:
		return T_GRASS_B
	if roll < 0.97:
		return T_GRASS_TUFT
	return T_GRASS_FLOWER

func _pick_boss_floor(rng: RandomNumberGenerator) -> Vector2i:
	var roll := rng.randf()
	if roll < 0.80:
		return T_BOSS_A
	if roll < 0.97:
		return T_BOSS_B
	return T_BOSS_RUNE

func _pick_bush(rng: RandomNumberGenerator) -> Vector2i:
	return T_BUSH_A if rng.randf() < 0.5 else T_BUSH_B

func _pick_stone(rng: RandomNumberGenerator) -> Vector2i:
	return T_STONE_A if rng.randf() < 0.5 else T_STONE_B
