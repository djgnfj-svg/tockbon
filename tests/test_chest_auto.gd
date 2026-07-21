extends SceneTree
## 상자 + 능동 루팅 자동 검증 (세션 55) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_chest_auto.gd
## 전 항목 통과 시 "TEST_CHEST_OK" 출력 후 종료 코드 0.
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##   • EnemyDef.drops_chest가 .tres에서 로드된다(snake_boss=true·vine=false, 세50 침묵 데이터 그물)
##   • forest_enemy._die 분기: drops_chest 적은 **상자 하나**(pickup 0), 잡몹은 **낱개 픽업**(chest 0)
##   • loot_panel: loot_card→advance 완료 시 add_to_bag + item_collected + contents remove_at + 자동 닫힘
##   • chest 통합: [E](interacted) → 패널 열림 → 다 루팅 → contents 비면 상자가 스스로 free
## ⚠ 못 잡는 것: 카드 **클릭 도달**·진행 바 **렌더**·상자 스프라이트 열림 프레임 — 실게임 push_input·스샷.
##
## 공개 API로만 검증한다(takbon-verify §3). 내부 필드는 계약이 아니다.
## -s 모드는 오토로드 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지. 동적 타입.

var failures: int = 0
var _db = null
var _bus = null
var _gs = null
var _enemy_scene = null
var _chest_scene = null
var _panel_scene = null
var _container = null   # get_tree().current_scene 역할 — _die가 드롭을 여기 심는다


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_CHEST_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_db = root.get_node("/root/Db")
	_bus = root.get_node("/root/EventBus")
	_gs = root.get_node("/root/GameState")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene
	_chest_scene = load("res://src/props/chest.tscn") as PackedScene
	_panel_scene = load("res://src/hud/loot_panel.tscn") as PackedScene

	# 🔴 _die가 get_tree().current_scene에 드롭을 심는다 — 헤드리스엔 메인 씬이 없어 null이라
	# 컨테이너를 만들어 current_scene으로 세운다(실게임에선 숲 씬이 그 자리).
	_container = Node2D.new()
	root.add_child(_container)
	current_scene = _container
	_gs.ui_modal_open = false

	await _test_schema_loads()
	await _test_die_spawns_chest()
	await _test_die_spawns_loose()
	await _test_loot_panel_collects()
	await _test_chest_integration()

	if failures == 0:
		print("TEST_CHEST_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_CHEST_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 drops_chest가 .tres에서 로드된다 (세50 그물 — "필드 추가했다"≠완료).
func _test_schema_loads() -> void:
	print("[1] EnemyDef.drops_chest 로드 (Db 경유)")
	var boss = _db.get_enemy(&"snake_boss")
	var vine = _db.get_enemy(&"vine")
	_check(boss != null and vine != null, "snake_boss·vine def가 로드된다")
	if boss != null:
		_check(boss.drops_chest == true, "snake_boss.drops_chest == true (실제 %s)" % str(boss.drops_chest))
	if vine != null:
		_check(vine.drops_chest == false, "vine.drops_chest == false (기본값, 실제 %s)" % str(vine.drops_chest))


## [2] 🔴 drops_chest 적을 죽이면 상자 하나가 생기고 낱개 픽업은 0.
func _test_die_spawns_chest() -> void:
	print("[2] _die: drops_chest 적 → 상자 하나 (픽업 0)")
	_clear_drops()
	var enemy = _make_enemy(&"snake_boss", Vector2(9000, 9000))
	await physics_frame
	enemy.take_hit(9999.0, 0, 0, 0.0)   # 즉사
	await physics_frame
	var chests := get_nodes_in_group("chests")
	var pickups := get_nodes_in_group("drop_pickups")
	_check(chests.size() == 1, "상자 정확히 1개 (실제 %d)" % chests.size())
	_check(pickups.size() == 0, "낱개 픽업 0개 (실제 %d)" % pickups.size())
	_clear_drops()


## [3] 🔴 잡몹(drops_chest false)을 죽이면 낱개 픽업이 생기고 상자는 0.
## vine의 mat_vine은 chance 기본 1.0이라 최소 1개 픽업이 보장된다(RNG에 안 흔들린다).
func _test_die_spawns_loose() -> void:
	print("[3] _die: 잡몹 → 낱개 픽업 (상자 0)")
	_clear_drops()
	var enemy = _make_enemy(&"vine", Vector2(9000, 9000))
	await physics_frame
	enemy.take_hit(9999.0, 0, 0, 0.0)
	await physics_frame
	var chests := get_nodes_in_group("chests")
	var pickups := get_nodes_in_group("drop_pickups")
	_check(chests.size() == 0, "🔴 잡몹은 상자 0개 (실제 %d) — 분기가 반대면 여기서 잡힌다" % chests.size())
	_check(pickups.size() >= 1, "낱개 픽업 1개 이상 (mat_vine 보장, 실제 %d)" % pickups.size())
	_clear_drops()


## [4] 🔴 loot_panel: loot_card→advance 완료 = add_to_bag + item_collected + remove_at + 자동 닫힘.
func _test_loot_panel_collects() -> void:
	print("[4] loot_panel: 카드 루팅 → 가방 + 토스트 + 배열 비움 + 닫힘")
	var panel = _make_panel()
	var contents := [{"id": &"mat_slime_core", "count": 2}]

	var collected := []
	var cb := func(id, n) -> void: collected.append([id, n])
	_bus.item_collected.connect(cb)
	var closed_hits := [0]
	var ccb := func() -> void: closed_hits[0] += 1
	panel.closed.connect(ccb)

	var bag_before: int = _gs.bag.size()
	panel.open(contents)
	_check(panel.is_open(), "open 후 is_open() == true")
	panel.loot_card(0)
	panel.advance(999.0)   # 즉시 완료
	await process_frame

	_check(contents.is_empty(), "🔴 contents가 참조로 비워졌다 (실제 크기 %d)" % contents.size())
	_check(collected.size() == 1, "item_collected 1회 (실제 %d)" % collected.size())
	if collected.size() == 1:
		_check(collected[0][0] == &"mat_slime_core" and int(collected[0][1]) == 2,
			"토스트 payload = (mat_slime_core, 2) (실제 %s)" % str(collected[0]))
	_check(_gs.bag.size() == bag_before + 1, "가방에 항목 1개 추가됐다 (%d → %d)" % [bag_before, _gs.bag.size()])
	_check(closed_hits[0] == 1, "🔴 다 비어 자동으로 닫혔다 (closed 1회, 실제 %d)" % closed_hits[0])
	_check(not panel.is_open(), "닫힌 뒤 is_open() == false")
	_check(_gs.ui_modal_open == false, "닫힘에 ui_modal_open 내려갔다")

	_bus.item_collected.disconnect(cb)
	panel.closed.disconnect(ccb)
	_free(panel.get_parent())   # CanvasLayer 루트째 free
	# 가방 뒷정리 — 이 테스트가 남긴 항목을 걷어낸다(실행 프로세스라 영구화는 없지만 깔끔하게).
	if _gs.bag.size() > bag_before:
		_gs.bag.resize(bag_before)


## [5] 🔴 상자 통합 — [E](interacted) → 패널 열림 → 다 루팅 → contents 비면 상자가 스스로 free.
func _test_chest_integration() -> void:
	print("[5] 상자 통합: [E] → 패널 → 루팅 완료 → 상자 소멸")
	_clear_drops()
	_gs.ui_modal_open = false
	var chest = _chest_scene.instantiate()
	_container.add_child(chest)
	chest.global_position = Vector2(100, 100)
	var contents := [{"id": &"mat_slime_core", "count": 1}]
	chest.setup(contents)
	await physics_frame

	var bag_before: int = _gs.bag.size()
	# 🔴 [E] 프레스를 흉내 — interact_zone의 공개 시그널을 직접 쏜다(클릭·키는 헤드리스가 못 잡는다).
	chest.get_node("InteractZone").interacted.emit()
	await process_frame

	# 상자가 loot_panel을 current_scene(_container)에 "Loot"로 붙였다.
	var loot_layer = _container.get_node_or_null("Loot")
	_check(loot_layer != null, "상자가 loot_panel을 띄웠다")
	if loot_layer != null:
		var panel = loot_layer.get_node("Panel")
		_check(panel.is_open(), "패널이 열려 있다")
		panel.loot_card(0)
		panel.advance(999.0)   # 즉시 완료 → contents 비움 → 자동 닫힘 → 상자 _on_loot_closed
		await process_frame
		await process_frame    # queue_free 반영 대기(상자·패널 둘 다 deferred)

	_check(_gs.bag.size() == bag_before + 1, "가방에 1개 들어왔다 (%d → %d)" % [bag_before, _gs.bag.size()])
	_check(not is_instance_valid(chest), "🔴 다 주운 상자가 스스로 사라졌다")
	_check(_container.get_node_or_null("Loot") == null, "패널도 정리됐다")

	if _gs.bag.size() > bag_before:
		_gs.bag.resize(bag_before)
	_clear_drops()


# ── 헬퍼 ──

func _make_enemy(id: StringName, pos: Vector2):
	var e = _enemy_scene.instantiate()
	e.enemy_id = id          # _ready가 이걸로 Db.get_enemy → def 로드
	root.add_child(e)
	e.global_position = pos
	return e


func _make_panel():
	var layer = _panel_scene.instantiate()
	root.add_child(layer)
	return layer.get_node("Panel")


## 씹히지 않게 서브테스트 사이에서 상자·픽업·패널을 싹 비운다.
func _clear_drops() -> void:
	for n in get_nodes_in_group("chests"):
		_free(n)
	for n in get_nodes_in_group("drop_pickups"):
		_free(n)
	var stray = _container.get_node_or_null("Loot")
	if stray != null:
		_free(stray)


func _free(node) -> void:
	if node != null and is_instance_valid(node):
		node.free()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
