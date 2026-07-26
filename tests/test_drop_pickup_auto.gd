extends SceneTree
## 바닥 픽업 자동 검증 (세션46) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_drop_pickup_auto.gd
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
	await _test_unlock_label()
	await _test_unlock_collect()
	await _test_unlock_already_owned()
	await _test_empty_payload_no_reentry()
	await _test_unlock_is_not_a_diamond()

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


## [13] 🔴 해금물(문양-고리 두루마리) 페이로드 + **그 문구가 원시 id가 아니다** (세88 §3-B-2).
##
## 🔴 **화면 문구는 픽업의 일이 아니다** — HUD가 `codex_unlocked`를 받아 `CodexText`로 낸다.
## 픽업이 라벨 필드를 들고 있던 초안은 걷었다(소비자가 HUD로 옮겨가 **소비자 0 = 거짓 손잡이**가
## 됐다 — 감사 T3). 그래서 여기서는 **페이로드 계약**은 픽업에, **문구 계약**은 core에 각각 묻는다.
## ⚠ 안내 문구를 글자로 박지 않는다 — `hint_for_kind`와 대조해 관계식으로 잰다(문구를 다듬어도
##   거짓 빨강이 안 나게. 세79 교훈).
func _test_unlock_label() -> void:
	print("[13] 해금물 페이로드 + 문구가 원시 id가 아니다")
	var CT: GDScript = load("res://src/core/codex_text.gd")
	var p = _spawn_unlock(&"gr_spread3")
	await process_frame
	_check(p.item_id == &"" and p.unlock_id == &"gr_spread3",
		"페이로드가 해금물 쪽에만 실렸다 (item_id와 배타 — DropEntry 계약)")
	var line: String = CT.acquired_line(p.unlock_id)
	_check(line != "", "획득 문장이 나온다 (실제 %s)" % line)
	_check(not line.contains("gr_"), "원시 id가 아니다 (실제 %s)" % line)
	_check(line.contains(CT.hint_for_kind(CT.KIND_RING)),
		"고리는 「밴드」 자리를 가르친다 = 룬·진과 안내가 갈린다 (실제 %s)" % line)
	p.free()


## [14] 🔴 해금물 줍기 = `codex_unlocked` **1회** · 가방 무변경 · 픽업 사라짐 · `item_collected` 안 옴.
## 🔴 `item_collected`를 **안 쏘는 것이 계약이다**: 그 시그널은 문자열을 못 싣고 HUD가
## `Db.get_item`으로 이름을 스스로 찾으므로, 해금물에 쏘면 토스트에 **원시 id가 뜬다**.
func _test_unlock_collect() -> void:
	print("[14] 해금물 줍기 = codex_unlocked 1회 · 가방은 안 는다")
	_gs.bag.clear()
	_gs.codex.erase(&"gr_spread3")
	var bus = root.get_node("/root/EventBus")
	var unlocks: Array = []
	var items: Array = []
	var cb1 := func(id) -> void: unlocks.append(id)
	var cb2 := func(id, n) -> void: items.append([id, n])
	bus.codex_unlocked.connect(cb1)
	bus.item_collected.connect(cb2)
	var p = _spawn_unlock(&"gr_spread3")
	var player = _magnet_player(Vector2(9000, 9000))
	await create_timer(0.5).timeout   # 줍기 지연이 풀리게
	player.global_position = p.global_position + Vector2(24.0, 0.0)
	await _await_gone(p)
	bus.codex_unlocked.disconnect(cb1)
	bus.item_collected.disconnect(cb2)
	_check(unlocks.size() == 1 and unlocks[0] == &"gr_spread3",
		"codex_unlocked가 정확히 1회 (실제 %s)" % [unlocks])
	_check(_gs.is_unlocked(&"gr_spread3"), "codex에 심겼다 (해금음·UNLOCK 퀘스트가 여기 딸려 온다)")
	_check(_bag_total() == 0, "가방은 안 는다 — 아이템이 아니다 (실제 %d)" % _bag_total())
	_check(items.is_empty(), "item_collected는 안 온다 = 원시 id 토스트 방지 (실제 %s)" % [items])
	_check(_gone(p), "픽업이 사라진다")
	_drop_player(player)


## [15] 이미 해금된 고리를 또 주워도 **재발신 0** — 그래도 픽업은 사라진다(바닥 유령 방지).
## ⚠ 재발신하면 해금음·UNLOCK 퀘스트가 중복 반응한다(boss_room의 is_unlocked 가드와 같은 결).
func _test_unlock_already_owned() -> void:
	print("[15] 이미 해금이면 재발신 없이 조용히 사라진다")
	_gs.bag.clear()
	_gs.codex[&"gr_spread3"] = true
	var bus = root.get_node("/root/EventBus")
	var unlocks: Array = []
	var cb := func(id) -> void: unlocks.append(id)
	bus.codex_unlocked.connect(cb)
	var p = _spawn_unlock(&"gr_spread3")
	var player = _magnet_player(Vector2(9000, 9000))
	await create_timer(0.5).timeout
	player.global_position = p.global_position + Vector2(24.0, 0.0)
	await _await_gone(p)
	bus.codex_unlocked.disconnect(cb)
	_check(unlocks.is_empty(), "재발신 0회 (실제 %s)" % [unlocks])
	_check(_gone(p), "그래도 픽업은 사라진다")
	_drop_player(player)


## [16] 🔴🔴 빈 페이로드 픽업이 **재호출 고리 없이** 치워진다 (세88에 고친 실존 버그).
##
## 옛 코드: `_collect_at`이 `if _collected or item_id == &"": return`으로 **`_collected`를 세우기
## 전에** 빠져나갔다. 자석이 도착하면 `_physics_process`가 **매 프레임 다시 부르고**, 픽업은
## 플레이어에 **붙은 채 영원히 안 사라진다** — 에러도 경고도 없다. 두루마리(item_id가 빈 픽업)가
## 바로 그 함정을 열었다. 뮤테이션(`_collected = true`를 조기 return 뒤로 옮김) → 여기가 빨개진다.
func _test_empty_payload_no_reentry() -> void:
	print("[16] 빈 페이로드는 재호출 고리 없이 치워진다")
	_gs.bag.clear()
	var p = _scene.instantiate()
	root.add_child(p)
	p.global_position = Vector2(300, 300)
	p.setup(&"", 0)                                  # 페이로드 없음
	var player = _magnet_player(Vector2(300, 300))   # 반경 안 = 자석이 곧바로 도착
	for i in 40:
		await physics_frame
	_check(_gone(p), "빈 픽업이 사라진다 (안 사라지면 플레이어에 붙어 영구 잔존)")
	_check(_bag_total() == 0, "가방엔 유령 항목이 안 들어간다 (실제 %d)" % _bag_total())
	_drop_player(player)
	if is_instance_valid(p) and not p.is_queued_for_deletion():
		p.free()


## [17] 🔴 해금물은 **등급색 마름모로 안 선다** — 세54 도형 플레이스홀더 금지.
## `_apply_color`가 `Db.get_item` null이면 마름모 `Polygon2D` 폴백으로 떨어지던 자리다
## (CLAUDE.md가 *"drop_pickup 마름모 선례는 각하됐다"*고 그 이름으로 못 박았다).
## ⚠ 두루마리 PNG가 있든 없든 성립한다: 있으면 스프라이트가 켜지고 없으면 후광만 남는다 —
## 어느 쪽이든 **마름모 알파는 0**이어야 한다.
func _test_unlock_is_not_a_diamond() -> void:
	print("[17] 해금물은 등급색 마름모로 안 선다 (세54 도형 금지)")
	var p = _spawn_unlock(&"gr_explode1")
	await process_frame
	var vis: Polygon2D = p.get_node("Visual")
	_check(is_zero_approx(vis.color.a),
		"마름모 알파 0 (실제 %.2f — 0이 아니면 도형 스탠드인이 화면에 선다)" % vis.color.a)
	# 🔴🔴 **두루마리 PNG가 실제로 로드되나** — 「파일을 만들었다」는 완료가 아니다(세50).
	# 마름모 알파만 재면 **PNG가 없어도 통과한다**(그때는 후광만 남아 바닥에 아무것도 안 보인다).
	# ⚠ `.import` 사이드카가 없으면 `ResourceLoader.exists`가 false라 여기서 걸린다 — 아트를
	#   받은 세션이 `--import`를 잊는 것이 정확히 이 그물이 잡는 실패다.
	var sprite: Sprite2D = vis.get_node_or_null("Sprite") as Sprite2D
	_check(sprite != null and sprite.visible and sprite.texture != null,
		"두루마리 스프라이트가 켜지고 텍스처가 실렸다 (안 실리면 바닥에 후광만 남는다)")
	p.free()


# ── 헬퍼 ──

## 해금물(두루마리) 픽업 — `item_id`는 비우고 `unlock_id`만 싣는다(둘은 배타다).
func _spawn_unlock(uid: StringName):
	var p = _scene.instantiate()
	root.add_child(p)
	p.global_position = Vector2(300, 300)
	p.setup(&"", 1, -1.0, uid)
	return p


## 픽업이 사라질 때까지 돌린다 — 🔴 해금물은 **가방이 안 늘어서** `_await_collected`를 못 쓴다
## (그걸로 기다리면 1초 헛돌고 판정이 타이밍에 흔들린다).
func _await_gone(p) -> void:
	for i in 60:
		if _gone(p):
			return
		await physics_frame
	await create_timer(0.2).timeout   # 도착 팝 뒤 queue_free까지의 여유


func _gone(p) -> bool:
	return (not is_instance_valid(p)) or p.is_queued_for_deletion()


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
