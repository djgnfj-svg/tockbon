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
	await _test_magnet_survives_no_player()
	await _test_magnet_blocked_during_delay()
	await _test_magnet_out_of_range()
	await _test_magnet_pulls_in_range()
	await _test_magnet_cannot_be_cancelled()
	await _test_arrival_banks_once()
	await _test_item_collected_signal()

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
	# 🔴 세션51: 도착 팝(POP_TIME 0.12s) 동안 픽업은 **아직 살아 있다** — 그래야 플레이어
	# 자리에서 터지는 게 보인다. queue_free는 팝이 끝나고 온다(계약은 그대로: 결국 사라진다).
	await create_timer(0.25).timeout
	_check(p.is_queued_for_deletion(), "주워진 픽업은 (도착 팝 뒤) queue_free 된다")


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


## [6] 🔴 플레이어가 없는 씬에서 자석이 크래시하지 않는다.
## 이게 이 파일에서 제일 조용한 함정이다 — null 가드가 없으면 매 물리 프레임 null 접근으로
## 죽는데, `-s` 헤드리스는 그래도 "OK"를 찍는다(세22·23 패턴). **grep에 SCRIPT ERROR 필수.**
func _test_magnet_survives_no_player() -> void:
	print("[6] 플레이어 없는 씬에서 자석이 크래시하지 않는다 (null 가드)")
	_gs.bag.clear()
	var p = _spawn(&"mat_slime_core", 1)
	await create_timer(0.5).timeout   # 지연 지나 READY — 자석이 매 물리 프레임 돈다
	for i in 5:
		await physics_frame
	_check(is_instance_valid(p) and not p.is_queued_for_deletion(),
		"플레이어가 없으면 픽업은 그냥 바닥에 남는다")
	_check(_bag_total() == 0, "플레이어가 없으면 가방이 안 는다 (실제 %d)" % _bag_total())
	p.free()


## [7] 🔴 줍기 지연 중엔 자석이 안 켜진다 — 지연의 존재 이유(붙어 잡았을 때 연출을 보여준다)를
## 자석이 무력화하면 안 된다.
func _test_magnet_blocked_during_delay() -> void:
	print("[7] 줍기 지연 중엔 자석이 안 켜진다")
	_gs.bag.clear()
	var p = _spawn(&"mat_slime_core", 1)
	# 🔴 픽업 **스폰 지점 그대로**에 세운다: scatter가 어느 방향으로 튀든 거리는 0~22px라
	# 항상 자석 반경 안이다. 자석이 켜져 있었다면 첫 몇 프레임에 무조건 도착한다.
	var player = _magnet_player(Vector2(300, 300))
	# PICKUP_DELAY(0.35s ≈ 21물리프레임)보다 확실히 짧게만 돌린다.
	for i in 12:
		await physics_frame
	_check(_bag_total() == 0, "지연 중엔 자석이 안 끌어당긴다 (실제 %d개)" % _bag_total())
	_check(not p.is_queued_for_deletion(), "지연 중엔 픽업이 안 사라진다")
	_drop_player(player)
	p.free()


## [8] 자석 반경 **밖**이면 안 끌린다.
func _test_magnet_out_of_range() -> void:
	print("[8] 자석 반경 밖이면 안 끌린다")
	_gs.bag.clear()
	var p = _spawn(&"mat_slime_core", 1)
	var player = _magnet_player(Vector2(9000, 9000))   # 처음엔 멀리 (scatter가 끝나게)
	await create_timer(0.5).timeout
	var settled: Vector2 = p.global_position
	player.global_position = settled + Vector2(p.MAGNET_RADIUS + 80.0, 0.0)
	for i in 6:
		await physics_frame
	_check(p.global_position.is_equal_approx(settled),
		"반경 밖에선 픽업이 1px도 안 움직인다 (%s → %s)" % [settled, p.global_position])
	_drop_player(player)
	p.free()


## [9] 자석 반경 **안**이면 플레이어 쪽으로 가까워진다 (거리 단조 감소).
func _test_magnet_pulls_in_range() -> void:
	print("[9] 자석 반경 안이면 플레이어 쪽으로 끌려온다")
	_gs.bag.clear()
	var p = _spawn(&"mat_slime_core", 1)
	var player = _magnet_player(Vector2(9000, 9000))
	await create_timer(0.5).timeout
	player.global_position = p.global_position + Vector2(60.0, 0.0)
	var d0: float = p.global_position.distance_to(player.global_position)
	for i in 3:
		await physics_frame
	var d1: float = p.global_position.distance_to(player.global_position)
	_check(d1 < d0 - 0.5, "거리가 줄어든다 (%.1f → %.1f)" % [d0, d1])
	_drop_player(player)
	if is_instance_valid(p):
		p.free()


## [10] 🔴 한번 끌리기 시작하면 취소되지 않는다 — 반경 밖으로 도망가도 계속 따라온다.
## 경계에서 들락날락하며 아이템이 떨었다 말았다 하면 최악이다("이미 내 것이다"가 깨진다).
func _test_magnet_cannot_be_cancelled() -> void:
	print("[10] 끌리기 시작하면 멀리 도망가도 계속 따라온다")
	_gs.bag.clear()
	var p = _spawn(&"mat_slime_core", 1)
	var player = _magnet_player(Vector2(9000, 9000))
	await create_timer(0.5).timeout
	player.global_position = p.global_position + Vector2(60.0, 0.0)
	for i in 3:
		await physics_frame   # 여기서 HOMING 래치 (물리 프레임 순서상 1프레임으론 부족)
	# 반경의 몇 배로 도망간다 — 취소되면 여기서 멈춰야 하고, 취소 안 되면 계속 쫓아온다.
	player.global_position = p.global_position + Vector2(p.MAGNET_RADIUS * 8.0, 0.0)
	var before: Vector2 = p.global_position
	for i in 5:
		await physics_frame
	_check(p.global_position.distance_to(before) > 1.0,
		"반경 밖으로 도망가도 픽업이 계속 따라온다 (이동 %.1fpx)" % p.global_position.distance_to(before))
	_drop_player(player)
	if is_instance_valid(p):
		p.free()


## [11] 🔴 도착 시 **정확히 1회** 뱅킹 — `body_entered`(안전망)와 거리 도착(자석)이 둘 다
## 있으므로 이중 수집 위험이 실재한다.
## ⚠ **가드는 셋이라 중복 방어선이다** (`_on_body_entered`의 상태 체크 · `_try_collect._collected` ·
## `_collect_at._collected`). 이 테스트는 **묶음 전체가 사라지는 것**을 잡지, 각 줄이 필수임을
## 증명하지 않는다 — 하나만 지우면 나머지 둘이 막아 초록이다(세51 뮤테이션 실측). 그러니
## **"[11]이 지켜 주니 이 줄은 지워도 된다"고 읽지 마라.**
func _test_arrival_banks_once() -> void:
	print("[11] 자석 도착은 1회만 뱅킹한다 (이중 수집 가드)")
	_gs.bag.clear()
	var p = _spawn(&"mat_slime_core", 2)
	var player = _magnet_player(Vector2(9000, 9000))
	await create_timer(0.5).timeout
	player.global_position = p.global_position + Vector2(24.0, 0.0)
	await _await_collected(p)
	_check(_bag_total() == 2, "자석 도착으로 2개가 가방에 들어간다 (실제 %d)" % _bag_total())
	# 도착 팝 도중 픽업은 아직 살아 있다 → 여기서 body_entered가 또 오면 두 번 담길 수 있다.
	if is_instance_valid(p) and not p.is_queued_for_deletion():
		p.body_entered.emit(player)
	await process_frame
	_check(_bag_total() == 2, "도착 뒤 body_entered를 또 쏴도 안 는다 (실제 %d)" % _bag_total())
	_drop_player(player)


## [12] 도착 시 `EventBus.item_collected`가 id·count를 싣고 **1회** 발신된다 (HUD 토스트의 원천).
func _test_item_collected_signal() -> void:
	print("[12] 도착 시 EventBus.item_collected가 id·count를 싣고 1회 온다")
	_gs.bag.clear()
	var bus = root.get_node("/root/EventBus")
	var got: Array = []
	var cb := func(id, n) -> void: got.append([id, n])
	bus.item_collected.connect(cb)
	var p = _spawn(&"mat_slime_core", 3)
	var player = _magnet_player(Vector2(9000, 9000))
	await create_timer(0.5).timeout
	player.global_position = p.global_position + Vector2(24.0, 0.0)
	await _await_collected(p)
	bus.item_collected.disconnect(cb)
	_check(got.size() == 1, "정확히 1회 발신 (실제 %d회)" % got.size())
	if got.size() == 1:
		_check(got[0][0] == &"mat_slime_core" and int(got[0][1]) == 3,
			"id·count가 실려 온다 (실제 %s x%s)" % [got[0][0], got[0][1]])
	else:
		_check(false, "id·count가 실려 온다 (발신이 없어 확인 불가)")
	_drop_player(player)


# ── 헬퍼 ──

## 그룹 "player"에 든 가짜 플레이어 — 자석이 그룹 조회로 찾는 바로 그 수단.
## 🔴 테스트가 끝나면 반드시 `_drop_player`로 그룹에서 빼라: 남아 있으면 **다음 테스트의 픽업이
## 조용히 끌려간다**(테스트끼리 오염된다).
func _magnet_player(pos: Vector2):
	var b := CharacterBody2D.new()
	b.add_to_group("player")
	root.add_child(b)
	b.global_position = pos
	return b


func _drop_player(b) -> void:
	if is_instance_valid(b):
		b.remove_from_group("player")
		b.free()


## 자석이 도착할 때까지 물리 프레임을 돌린다 (최대 1초 — 무한 대기 방지).
func _await_collected(p) -> void:
	for i in 60:
		if _bag_total() > 0:
			return
		await physics_frame



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
