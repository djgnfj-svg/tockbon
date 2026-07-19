extends SceneTree
## 바닥 픽업 자동 검증 (세션46) — 헤드리스 실행:
##   ./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_drop_pickup_auto.gd
## 전 항목 통과 시 "TEST_DROP_PICKUP_OK" 출력 후 종료 코드 0.
##
## 검증 대상 = **바닥 픽업 계약**: 떨어진 뒤 · 지연 동안은 못 줍고 · 지연 뒤 닿으면 가방에 담기고
## 사라진다 · 레이어 계약(layer 0 / mask 2).
##
## 🔴 헤드리스가 **못 잡는 것**(리드가 실게임으로 확인): 픽업 비주얼이 보이는지·튀어나오는 연출·
##   실제로 걸어가 물리 겹침으로 주워지는지. 여기선 body_entered **시그널**을 직접 쏴 핸들러
##   로직(지연 게이트 + 수집)을 결정론적으로 검증한다 — 물리 겹침은 실게임 몫이다.
##
## 공개 계약으로만 검증한다: setup()·그룹·body_entered 시그널·collision_layer/mask·GameState.bag.
## 내부 필드(_pickable 등)는 리팩터 때 옮겨 다니는 물건이라 더듬지 않는다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

var failures: int = 0
var _gs = null
var _scene = null
var _bodies: Array = []  # 만든 가짜 플레이어 몸들 — 끝에 정리


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		print("TEST_DROP_PICKUP_TIMEOUT — 20초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_gs = root.get_node("/root/GameState")
	_scene = load("res://src/props/drop_pickup.tscn") as PackedScene

	await _test_spawns_into_group()
	await _test_layer_contract()
	await _test_delay_blocks_pickup()
	await _test_pickup_after_delay_banks_and_frees()
	await _test_non_player_ignored()

	for b in _bodies:
		if is_instance_valid(b):
			b.free()

	if failures == 0:
		print("TEST_DROP_PICKUP_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_DROP_PICKUP_FAIL — %d개 실패" % failures)
		quit(1)


## [1] setup 후 그룹 "drop_pickups"에 있고 아이템을 실었다.
func _test_spawns_into_group() -> void:
	print("[1] 떨어지면 그룹 \"drop_pickups\"에 들고 아이템을 실었다")
	var p = _spawn(&"mat_slime_core", 3)
	await process_frame
	_check(p.is_in_group("drop_pickups"), "그룹 \"drop_pickups\"에 있다 (숲이 훑을 수 있다)")
	_check(p.item_id == &"mat_slime_core" and p.count == 3, "setup이 아이템·수량을 실었다")
	p.free()


## [2] 🔴 레이어 계약 — layer 0(아무도 감지 안 함, 마법이 안 부딪힘) / mask 2(플레이어만 감지).
func _test_layer_contract() -> void:
	print("[2] 레이어 계약 — layer 0 / mask 2 (마법이 픽업에 안 걸린다)")
	var p = _spawn(&"mat_slime_core", 1)
	await process_frame
	_check(p.collision_layer == 0,
		"collision_layer == 0 — 안 그러면 발사 캐리어(마스크 5)가 픽업에 부딪혀 마법이 조용히 죽는다 (실제 %d)" % p.collision_layer)
	_check(p.collision_mask == 2,
		"collision_mask == 2 — 플레이어(layer 2)만 감지 (실제 %d)" % p.collision_mask)
	_check(p.monitoring, "monitoring == true (안 그러면 body_entered가 안 온다)")
	p.free()


## [3] 🔴 줍기 지연 동안엔 안 주워진다 — 붙어 잡았을 때 프레임에 바로 사라지지 않게.
func _test_delay_blocks_pickup() -> void:
	print("[3] 줍기 지연 동안엔 닿아도 안 주워진다")
	_gs.bag.clear()
	var p = _spawn(&"mat_slime_core", 2)
	await process_frame  # 아직 PICKUP_DELAY(0.35s) 안 — _pickable=false
	var player = _fake_player()
	p.body_entered.emit(player)   # 지연 중 닿음
	await process_frame
	_check(_bag_total() == 0, "지연 중엔 가방이 안 는다 (실제 %d개)" % _bag_total())
	_check(not p.is_queued_for_deletion(), "지연 중엔 픽업이 안 사라진다")
	p.free()


## [4] 🔴 지연이 끝난 뒤 플레이어가 닿으면 → add_to_bag이 불려 가방이 늘고 픽업이 사라진다.
func _test_pickup_after_delay_banks_and_frees() -> void:
	print("[4] 지연 후 닿으면 가방에 담기고 픽업이 사라진다")
	_gs.bag.clear()
	var before := _bag_total()
	var p = _spawn(&"mat_slime_core", 4)
	# PICKUP_DELAY(0.35s)를 넘긴다 — _enable_pickup이 돌아 줍기가 열린다.
	await create_timer(0.5).timeout
	var player = _fake_player()
	p.body_entered.emit(player)
	await process_frame
	_check(_bag_total() == before + 4, "가방이 4개 는다 (%d → %d)" % [before, _bag_total()])
	_check(p.is_queued_for_deletion(), "주워진 픽업은 queue_free 된다")


## [5] 플레이어가 아닌 몸(CharacterBody2D가 아님)은 주워도 무시 — 방어적 타입 체크.
func _test_non_player_ignored() -> void:
	print("[5] CharacterBody2D가 아닌 몸은 안 줍는다")
	_gs.bag.clear()
	var p = _spawn(&"mat_slime_core", 1)
	await create_timer(0.5).timeout   # 지연 넘김
	var not_a_body := Node2D.new()    # CharacterBody2D 아님
	root.add_child(not_a_body)
	p.body_entered.emit(not_a_body)
	await process_frame
	_check(_bag_total() == 0, "잘못된 몸엔 안 담긴다 (실제 %d)" % _bag_total())
	_check(not p.is_queued_for_deletion(), "잘못된 몸엔 픽업이 안 사라진다")
	not_a_body.free()
	p.free()


# ── 헬퍼 ──

## 픽업을 root에 심고 setup까지 마친 상태로 돌려준다 (실제 _die가 하는 것과 같은 순서).
func _spawn(item_id: StringName, count: int):
	var p = _scene.instantiate()
	root.add_child(p)
	p.global_position = Vector2(300, 300)
	p.setup(item_id, count)
	return p


func _fake_player():
	var b := CharacterBody2D.new()
	root.add_child(b)
	_bodies.append(b)
	return b


func _bag_total() -> int:
	var total := 0
	for entry: Dictionary in _gs.bag:
		total += int(entry["count"])
	return total


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
