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
##   • [4] 불변식: fragment_*가 until_unlock 없이(순수 확률로) 등장하는 곳 0 · until_unlock 중복 0 ·
##     관문표 매핑 일치 · 조각 아이템의 params.unlock_id와 드롭의 until_unlock이 짝이다
##     (PROGRESSION.md의 표는 테스트가 못 읽는다 — 이 불변식이 표↔데이터 갈라짐을 대신 감시한다)
##   • [5] 허기 은퇴 잔재 0 (GameState·BalanceData에 hunger 계열 프로퍼티·함수 없음)
## ⚠ 못 잡는 것: 상자 카드 렌더·실게임 드롭 좌표 — 상자 경유 흐름 자체는 test_chest_auto가 잰다.
##
## 🔴 세이브 안전: 이 테스트는 enemy_died만 쏜다 — SaveManager가 저장하는 트리거는
## extraction_success·bag_lost·day_started 뿐이라 **진짜 세이브 파일을 안 건드린다**(wipe_save 불필요).
## codex는 메모리에서만 굴리고 끝에 원상복구한다.
##
## 공개 API로만 검증한다(takbon-verify §3). 내부 필드는 계약이 아니다.
## -s 모드는 오토로드 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지. 동적 타입.

## 관문표 (docs/PROGRESSION.md §관문표와 1:1 — 표를 바꾸면 여기도 바꾼다).
const GATES := {
	&"rune_water": &"slime_elite",
	&"rune_wind": &"gale",
	&"rune_grass": &"snake_boss",
}
## 관문 조각을 잃은(랜덤 은퇴) 잡몹 3종 — fragment 줄이 아예 없어야 한다.
const RETIRED := [&"vine", &"beetle", &"mist"]

var failures: int = 0
var _db = null
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


## [1] 🔴 편집한 적 6종이 Db를 거쳐 로드된다 + until_unlock가 제자리에 있다 (세50 그물).
## .tres 한 글자가 틀리면 파서가 리소스 전체를 거부하고 Db가 말없이 건너뛴다 — 로드 자체가 검증이다.
func _test_db_loads() -> void:
	print("[1] 편집한 적 6종 Db 로드 + until_unlock 존재")
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
func _test_locked_guaranteed_drop() -> void:
	print("[2] 미해금 = 확정 드롭 (slime_elite → fragment_water, chance를 0으로 내려 잰다)")
	var had: bool = _gs.is_unlocked(&"rune_water")
	_gs.codex.erase(&"rune_water")   # 🔴 시드가 룬 6종을 미리 여니 테스트가 직접 끈다
	var gate = _gate_entry_of(&"slime_elite")
	if gate == null:
		_check(false, "관문 줄을 못 찾았다 — [1]이 먼저 붉었을 것")
		return
	var old_chance: float = gate.chance
	gate.chance = 0.0
	for i in 3:
		_clear_drops()
		var enemy = _make_enemy(&"slime_elite")
		await physics_frame
		enemy.take_hit(9999.0, 0, 0, 0.0)
		await physics_frame
		_check(_dropped_ids().has(&"fragment_water"),
			"처치 %d/3: fragment_water가 떨어졌다 (실제 %s)" % [i + 1, str(_dropped_ids())])
	gate.chance = old_chance   # 🔴 공유 리소스 원상복구
	_clear_drops()
	if had:
		_gs.codex[&"rune_water"] = true   # 원상복구


## [3] 🔴 해금됐으면 조각은 안 나오고, 나머지 드롭(mat_slime_core, chance 1.0)은 그대로 나온다 —
## 관문이 "그 줄만" 걸러야지 테이블 전체를 삼키면 안 된다.
func _test_unlocked_stops_drop() -> void:
	print("[3] 해금 = 조각 드롭 중단 (나머지 드롭은 유지)")
	_gs.codex[&"rune_water"] = true
	_clear_drops()
	var enemy = _make_enemy(&"slime_elite")
	await physics_frame
	enemy.take_hit(9999.0, 0, 0, 0.0)
	await physics_frame
	var ids := _dropped_ids()
	_check(not ids.has(&"fragment_water"), "🔴 fragment_water가 안 떨어졌다 (실제 %s)" % str(ids))
	_check(ids.has(&"mat_slime_core"), "mat_slime_core(확률 1.0)는 그대로 나온다 (실제 %s)" % str(ids))
	_clear_drops()


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


## 지금 떨어져 있는 낱개 픽업들의 item_id. ⚠ 상자 내용물은 안 걷는다 — chest의 `_contents`는
## 비공개라 계약이 아니다(takbon-verify §3). 이 테스트의 처치 검증은 잡몹(slime_elite)만 쓰고,
## snake_boss 관문은 데이터 수준([1]·[4])으로 잰다 — 상자 경유 흐름 자체는 test_chest_auto의 몫.
func _dropped_ids() -> Array:
	var ids := []
	for p in get_nodes_in_group("drop_pickups"):
		ids.append(p.item_id)
	return ids


func _clear_drops() -> void:
	for n in get_nodes_in_group("drop_pickups"):
		if is_instance_valid(n):
			n.free()
	for n in get_nodes_in_group("chests"):
		if is_instance_valid(n):
			n.free()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
