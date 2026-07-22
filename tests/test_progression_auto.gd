extends SceneTree
## 진행 관문(until_unlock 드롭) + 허기 은퇴 자동 검증 (세션 58) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_progression_auto.gd
## 전 항목 통과 시 "TEST_PROGRESSION_OK" 출력 후 종료 코드 0. 정본 = docs/PROGRESSION.md.
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##   • [1] 편집한 적 6종 .tres가 Db를 거쳐 로드된다 (세50 침묵 파싱사 그물 — "파일 고쳤다"≠완료)
##     + until_unlock 드롭이 slime_elite·gale·snake_boss에 정확히 있다
##   • [2] 미해금 = **확정** 드롭 — 관문 줄의 chance를 메모리 0으로 내리고 3연속 처치로 "항상"을 잰다
##     (chance **무시** 계약을 [2]가 직접 잰다 — 안 내리면 chance 1.0이라 확률 폴백 회귀를 못 잡는다)
##   • [3] 해금 = 드롭 **중단** (나머지 드롭은 그대로 나온다 — 관문이 남을 안 건드리는 것까지)
##   ⚠ 세66: 상자 은퇴 — 모든 적이 낱개로 떨군다(slime_elite 포함). 수확은 drop_pickups 그룹의
##   공개 `item_id`만 걷으면 된다(옛 상자 루팅 흐름은 제거됐다).
##   • [4] 불변식: fragment_*가 until_unlock 없이(순수 확률로) 등장하는 곳 0 · until_unlock 중복 0 ·
##     관문표 매핑 일치 · 조각 아이템의 params.unlock_id와 드롭의 until_unlock이 짝이다
##     (PROGRESSION.md의 표는 테스트가 못 읽는다 — 이 불변식이 표↔데이터 갈라짐을 대신 감시한다)
##   • [5] 허기 은퇴 잔재 0 (GameState·BalanceData에 hunger 계열 프로퍼티·함수 없음)
## ⚠ 못 잡는 것: 실게임 드롭 좌표·등급 후광 겉보기 (헤드리스는 렌더를 못 본다).
##
## 🔴 세이브 안전: 이 테스트는 enemy_died만 쏜다 — SaveManager가 저장하는 트리거는
## extraction_success·bag_lost·day_started 뿐이라 **진짜 세이브 파일을 안 건드린다**(wipe_save 불필요).
## codex는 메모리에서만 굴리고 끝에 원상복구한다.
##
## 공개 API로만 검증한다(takbon-verify §3). 내부 필드는 계약이 아니다.
## -s 모드는 오토로드 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지. 동적 타입.

## 관문표 (docs/PROGRESSION.md §관문표와 1:1 — 표를 바꾸면 여기도 바꾼다).
## 🔴 세61 콘텐츠 리셋: 룬 조각·관문 드롭을 전부 걷어 관문표 = 0줄. 관문 **기계**(until_unlock
## 판정, forest_enemy._roll_drops)는 남아 있으므로 [2][3]이 in-memory DropEntry 주입으로 계속
## 잰다. 사용자가 관문을 되살리면 여기 한 줄 + 적 .tres 한 줄이 짝으로 는다.
const GATES := {}
## 관문 조각을 잃은(랜덤 은퇴) 잡몹 3종 — fragment 줄이 아예 없어야 한다.
const RETIRED := [&"vine", &"beetle", &"mist"]

var failures: int = 0
var _db = null
var _bus = null
var _gs = null
var _enemy_scene = null
var _container = null   # get_tree().current_scene 역할 — _die가 드롭을 여기 심는다


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_PROGRESSION_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_db = root.get_node("/root/Db")
	_bus = root.get_node("/root/EventBus")
	_gs = root.get_node("/root/GameState")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene

	# _die가 get_tree().current_scene에 드롭을 심는다 — 헤드리스엔 메인 씬이 없어 컨테이너를 세운다.
	_container = Node2D.new()
	root.add_child(_container)
	current_scene = _container

	_test_db_loads()
	await _test_locked_guaranteed_drop()
	await _test_unlocked_stops_drop()
	_test_gate_invariants()
	_test_hunger_retired()

	if failures == 0:
		print("TEST_PROGRESSION_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_PROGRESSION_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 편집한 적 6종이 Db를 거쳐 로드된다 + 관문표와 데이터가 1:1이다 (세50 그물).
## .tres 한 글자가 틀리면 파서가 리소스 전체를 거부하고 Db가 말없이 건너뛴다 — 로드 자체가 검증이다.
## 세61: 관문 드롭 줄을 걷어냈으므로 GATES = 0줄 — 루프는 자명 통과지만 관문 복원 시 바로 산다.
func _test_db_loads() -> void:
	print("[1] 편집한 적 6종 Db 로드 + 관문표 1:1")
	for id in [&"vine", &"beetle", &"mist", &"slime_elite", &"gale", &"snake_boss"]:
		_check(_db.get_enemy(id) != null, "%s가 Db에서 로드된다" % id)
	for unlock_id in GATES:
		var enemy_id: StringName = GATES[unlock_id]
		var entry = _gate_entry_of(enemy_id)
		_check(entry != null, "%s에 until_unlock 드롭이 정확히 1줄 있다" % enemy_id)
		if entry != null:
			_check(entry.until_unlock == unlock_id,
				"%s의 관문 = %s (실제 %s)" % [enemy_id, unlock_id, entry.until_unlock])


## [2] 🔴 미해금이면 chance와 무관하게 **항상** 떨어진다. until_unlock 경로는 randf를 아예 안 타지만,
## "항상"은 주장 말고 잰다: 🔴 관문 줄의 chance를 **메모리에서 0으로 내리고** 3연속 처치 —
## 이래야 "chance 무시" 계약을 [2]가 직접 재고, 판정이 확률로 되돌아가는 회귀([3]의 반대 방향)도
## [2] 단독으로 붉는다 (chance 1.0인 채로는 확률 폴백도 항상 떨어져 검출력 0 — 세58 리뷰).
## ⚠ Db의 DropEntry는 공유 리소스다 — 끝에 chance 원상복구 필수.
## 🔴 세61: 실데이터 관문 줄이 0이라 **in-memory DropEntry를 slime_elite에 주입**해서 기계를 잰다
## (Db 딕셔너리·EnemyDef.drops는 평범한 컨테이너다 — 끝나면 제거). 조각 ItemDef도 같이 주입한다
## (루팅 패널이 Db.get_item으로 이름을 찾는다). 관문을 되살리면 실데이터 검증으로 되돌려도 된다.
func _test_locked_guaranteed_drop() -> void:
	print("[2] 미해금 = 확정 드롭 (in-memory 관문 주입, chance를 0으로 내려 잰다)")
	_inject_gate()
	_gs.codex.erase(&"rune_water")
	var gate = _gate_entry_of(&"slime_elite")
	if gate == null:
		_check(false, "주입한 관문 줄을 못 찾았다 — _inject_gate가 깨졌다")
		return
	gate.chance = 0.0   # chance **무시** 계약을 직접 잰다 — 확률 폴백 회귀면 여기서 붉는다
	for i in 3:
		var ids: Array = await _kill_and_collect(&"slime_elite")
		_check(ids.has(&"fragment_water"),
			"처치 %d/3: fragment_water가 나왔다 (실제 %s)" % [i + 1, str(ids)])


## [3] 🔴 해금됐으면 조각은 안 나오고, 나머지 드롭(mat_slime_core, chance 1.0)은 그대로 나온다 —
## 관문이 "그 줄만" 걸러야지 테이블 전체를 삼키면 안 된다. [2]가 주입한 관문을 이어 쓰고 여기서 걷는다.
func _test_unlocked_stops_drop() -> void:
	print("[3] 해금 = 조각 드롭 중단 (나머지 드롭은 유지)")
	_gs.codex[&"rune_water"] = true
	var ids: Array = await _kill_and_collect(&"slime_elite")
	_check(not ids.has(&"fragment_water"), "🔴 fragment_water가 안 나왔다 (실제 %s)" % str(ids))
	_check(ids.has(&"mat_slime_core"), "mat_slime_core(확률 1.0)는 그대로 나온다 (실제 %s)" % str(ids))
	_remove_gate()
	_gs.codex.erase(&"rune_water")   # 세61 시드엔 rune_water가 없다 — 깨끗이 되돌린다


## [4] 🔴 랜덤 조각 은퇴 불변식 — Db의 **모든** 적 드롭 전수 (PROGRESSION.md 표의 감시자).
func _test_gate_invariants() -> void:
	print("[4] 불변식: 순수 확률 fragment 0곳 · 관문 중복 0 · 관문표 매핑 · 조각 unlock_id 짝")
	var seen_gates := {}   # {until_unlock: enemy_id}
	var loose_fragments := []
	for enemy_id in _db.enemies:
		var def = _db.enemies[enemy_id]
		for drop in def.drops:
			if drop.until_unlock == &"":
				if String(drop.item_id).begins_with("fragment_"):
					loose_fragments.append("%s→%s" % [enemy_id, drop.item_id])
				continue
			_check(not seen_gates.has(drop.until_unlock),
				"관문 %s는 한 곳뿐이다 (중복: %s·%s)" % [drop.until_unlock, seen_gates.get(drop.until_unlock), enemy_id])
			seen_gates[drop.until_unlock] = enemy_id
			# 🔴 조각 아이템의 params.unlock_id와 드롭의 until_unlock이 짝이어야 해독이 그 룬을 연다 —
			# 어긋나면 "확정으로 떨어지는데 해독해도 관문이 안 닫히는" 무한 드롭이 된다.
			var item = _db.get_item(drop.item_id)
			_check(item != null and item.params.get("unlock_id", &"") == drop.until_unlock,
				"%s의 %s: 조각 unlock_id == until_unlock (%s)" % [enemy_id, drop.item_id, drop.until_unlock])
	_check(loose_fragments.is_empty(),
		"🔴 until_unlock 없는 fragment 드롭 0곳 (잔재: %s)" % str(loose_fragments))
	for unlock_id in GATES:
		_check(seen_gates.get(unlock_id) == GATES[unlock_id],
			"관문표 매핑: %s → %s (실제 %s)" % [unlock_id, GATES[unlock_id], seen_gates.get(unlock_id)])
	_check(seen_gates.size() == GATES.size(),
		"관문 수 == 관문표 %d줄 (실제 %d — 표에 없는 관문이 데이터에 있다)" % [GATES.size(), seen_gates.size()])


## [5] 🔴 허기 은퇴 (세58 D1) — 프로퍼티·함수·balance 필드가 전부 사라졌다.
## `"x" in Object`는 프로퍼티·메서드 둘 다 잡는다 — 남아 있으면 여기서 붉는다.
func _test_hunger_retired() -> void:
	print("[5] 허기 은퇴 잔재 0")
	_check(not ("hunger" in _gs), "GameState.hunger 없음")
	_check(not _gs.has_method("hunger_max"), "GameState.hunger_max() 없음")
	_check(not _gs.has_method("restore_hunger_full"), "GameState.restore_hunger_full() 없음")
	for field in ["hunger_max", "hunger_drain_per_sec", "starve_damage_per_tick"]:
		_check(not (field in _gs.balance), "BalanceData.%s 없음" % field)


# ── 헬퍼 ──

## 세61: in-memory 관문 주입 — slime_elite에 fragment_water(until_unlock=rune_water) 한 줄 +
## 조각 ItemDef. EnemyDef·Db.items는 공유 리소스라 [3] 끝에서 _remove_gate로 반드시 걷는다.
var _injected_gate = null
var _injected_item := false

func _inject_gate() -> void:
	if _injected_gate != null:
		return
	var entry = DropEntry.new()
	entry.item_id = &"fragment_water"
	entry.chance = 1.0
	entry.until_unlock = &"rune_water"
	_injected_gate = entry
	_db.get_enemy(&"slime_elite").drops.append(entry)
	if _db.get_item(&"fragment_water") == null:
		var frag = ItemDef.new()
		frag.id = &"fragment_water"
		frag.kind = Enums.ItemKind.FRAGMENT
		frag.display_name = "물 조각(테스트)"
		frag.params = {"unlock_id": &"rune_water"}
		_db.items[&"fragment_water"] = frag
		_injected_item = true

func _remove_gate() -> void:
	if _injected_gate != null:
		_db.get_enemy(&"slime_elite").drops.erase(_injected_gate)
		_injected_gate = null
	if _injected_item:
		_db.items.erase(&"fragment_water")
		_injected_item = false

func _make_enemy(id: StringName):
	var e = _enemy_scene.instantiate()
	e.enemy_id = id          # _ready가 이걸로 Db.get_enemy → def 로드
	root.add_child(e)
	e.global_position = Vector2(9000, 9000)   # 플레이어 없음 — 자석·추격 무풍지대
	return e


## 그 적의 until_unlock 드롭 — 정확히 1줄일 때만 그 줄을 준다 (0줄·2줄이면 null = [1]에서 붉는다).
func _gate_entry_of(enemy_id: StringName):
	var def = _db.get_enemy(enemy_id)
	if def == null:
		return null
	var found = null
	var n := 0
	for drop in def.drops:
		if drop.until_unlock != &"":
			n += 1
			found = drop
	return found if n == 1 else null


## 적 하나를 처치하고 **실제로 나온 드롭의 item_id 전부**를 걷어 온다 — 전부 **낱개 픽업**(공개 `item_id`).
## 🔴 세66: 상자 은퇴로 보스도 낱개로 떨군다 — 옛 상자 루팅 흐름(interacted→loot_card/advance)은
## 사라졌다. 이제 slime_elite도 drop_pickups 그룹에 그대로 뜬다(형태 분기 없음).
func _kill_and_collect(id: StringName) -> Array:
	_clear_drops()
	_gs.ui_modal_open = false
	var enemy = _make_enemy(id)
	await physics_frame
	enemy.take_hit(9999.0, 0, 0, 0.0)
	await physics_frame

	var ids := []
	for p in get_nodes_in_group("drop_pickups"):
		ids.append(p.item_id)

	_clear_drops()
	return ids


func _clear_drops() -> void:
	for n in get_nodes_in_group("drop_pickups"):
		if is_instance_valid(n):
			n.free()
	_gs.ui_modal_open = false


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
