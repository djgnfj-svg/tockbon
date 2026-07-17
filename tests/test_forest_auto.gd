extends SceneTree
## 숲 원정 자동 검증 (세션 26 — F1·F2) — 헤드리스 실행:
##   ./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_forest_auto.gd
## 전 항목 통과 시 "TEST_FOREST_OK" 출력 후 종료 코드 0.
##
## 검증 대상 = **원정 루프**: 나가서 · 맞고 · 때리고 · 돌아온다.
##
## 🔴 여기서 지키는 건 헤드리스가 **실제로 잡을 수 있는** 것들이다:
##   • 적의 물리 레이어 계약 (4=enemy) — 틀리면 마법이 부딪히기만 하고 `take_hit`이 안 불린다
##   • 그룹 `"player"` — 빠지면 적이 제자리에 굳는데 **에러가 안 난다**
##   • `extraction_success`·`bag_lost` 발신 — 안 쏘면 가방 정산·자동 저장이 **조용히** 안 돈다
## ⚠ 반대로 **못 잡는 것**: 좌클릭이 발사에 닿는지(`Ground.mouse_filter`). 헤드리스엔 렌더가 없어
## Control 히트 테스트가 실제와 다르다 — `push_input`을 써도 검출력이 0이다 (세션 25에 실측했다).
## **에디터로 띄운 실제 게임에서만 재현된다.**
##
## 공개 계약으로만 검증한다 (CLAUDE.md): EventBus 시그널 · 그룹 · zone_id · take_hit.
## 노드 경로·내부 필드는 리팩터 때 옮겨 다니는 물건이라 계약이 아니다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

const GLYPH_NONE := -1

var failures: int = 0
var _bus = null
var _gs = null
var _scene = null
var _forest = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_FOREST_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_gs = root.get_node("/root/GameState")
	_scene = load("res://src/field/forest.tscn") as PackedScene

	await _test_scene_wired()
	await _test_sortie_heals()
	await _test_enemy_chases_me()
	await _test_enemy_touch_hurts_me()
	await _test_my_spell_can_hit_and_kill()
	await _test_extract_banks_the_run()
	await _test_death_loses_the_bag()
	await _test_kill_drops_into_bag()
	await _test_drop_survives_extraction_lost_on_death()

	# 🔴 뒷정리 — **실제 플레이 세이브 오염 방지** (test_save_auto와 같은 이유).
	# ⚠ 세션 26의 F3(SaveManager._ready → load_game)으로 **저장이 살아나면서 생긴 일**이다:
	# 위 [6]·[7]이 쏘는 `extraction_success`·`bag_lost`에 SaveManager가 물려 있어, 이제 이 테스트가
	# **user://save/save.json을 진짜로 쓴다.** 안 지우면 다음 부팅이 그 빈 껍데기를 이어 받아
	# **플레이하던 마법진이 사라진다** (실제로 겪었다 — 스위트를 돌리자 세이브가 테스트 찌꺼기로
	# 덮여 있었다). 🔴 새 시그널을 쏘는 테스트를 더할 땐 SaveManager가 물려 있는지 확인해라.
	root.get_node("/root/SaveManager").wipe_save()

	if failures == 0:
		print("TEST_FOREST_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_FOREST_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 숲에 있어야 할 것 — 적·플레이어·귀환 지점·발사 시스템.
func _test_scene_wired() -> void:
	print("[1] 숲 배선 — 적 · 플레이어 · 귀환 지점 · 발사 시스템")
	await _fresh()
	_check(_enemies().size() >= 3, "적이 3마리 이상 (실제 %d)" % _enemies().size())
	_check(_player() != null, "플레이어가 그룹 \"player\"에 있다 = 적이 나를 찾을 수 있다")
	_check(_zone(&"extract") != null, "귀환 지점(zone_id=extract)이 있다")
	# ⚠ **경로**로 확인한다 — PackedScene으로 두면 base⇄forest **순환 preload**가 생겨
	# 돌아갈 곳이 노드 0개 껍데기로 굳는다 (forest.gd `base_scene_path` 주석).
	# 🔴 **이 확인은 그 버그를 못 잡는다**: 여기선 forest.tscn을 먼저 로드하므로 base preload가
	# 멀쩡히 끝난다. **베이스로 부팅한 실제 게임에서만** 깨졌다 — 잡는 건 경로라는 설계지 이 줄이 아니다.
	var back: String = str(_forest.get("base_scene_path"))
	_check(ResourceLoader.exists(back), "돌아갈 곳(%s)이 실재한다" % back)
	# 발사 시스템의 존재는 **행동으로** 확인한다 — 노드 이름이 아니라 "쏘면 진이 생기나".
	_bus.ring_cast_requested.emit(_assembly(1.0), Vector2(9000, 9000), Vector2(1, 0))
	await physics_frame
	_check(_carriers().size() == 1,
		"쏘니 진(캐리어)이 생긴다 = RingSpellSystem이 숲에 있다 (실제 %d)" % _carriers().size())
	_clear()


## [2] 🔴 출격 = 만HP. 이게 없으면 **죽는 게 이득**이 된다 — 벌이 없는 지금(사용자 확정),
## 다친 몸으로 걸어 돌아오느니 그 자리에서 죽는 편이 싸다.
func _test_sortie_heals() -> void:
	print("[2] 출격하면 HP가 찬다 (안 그러면 죽는 게 이득이 된다)")
	_gs.hp = 7.0
	await _fresh()
	_check(is_equal_approx(_gs.hp, _gs.hp_max()),
		"숲에 들어서면 HP %0.f/%0.f" % [_gs.hp, _gs.hp_max()])


## [3] 적이 쫓아온다 — aggro_range(.tres) 안에 서면 거리가 줄어든다.
## 🔴 그룹 "player"가 빠지면 여기서 잡힌다: 적이 **제자리에 굳는데 에러는 안 난다.**
func _test_enemy_chases_me() -> void:
	print("[3] 적이 쫓아온다")
	await _fresh()
	var enemy = _enemies()[0]
	var player = _player()
	# aggro_range(slime=160) 안, attack_range(18) 밖 — 다가오되 아직 안 때리는 거리.
	player.global_position = enemy.global_position + Vector2(90, 0)
	var before: float = enemy.global_position.distance_to(player.global_position)
	for i in 20:
		await physics_frame
	var after: float = enemy.global_position.distance_to(player.global_position)
	_check(after < before - 4.0, "거리 %.0f → %.0f (다가왔다)" % [before, after])


## [4] 접촉 피해 — 붙으면 HP가 깎인다. GameState가 원장이다 (씬을 갈아타도 남는 값).
func _test_enemy_touch_hurts_me() -> void:
	print("[4] 적에 닿으면 아프다")
	await _fresh()
	var enemy = _enemies()[0]
	var player = _player()
	player.global_position = enemy.global_position   # attack_range 안
	var before: float = _gs.hp
	for i in 10:
		await physics_frame
	_check(_gs.hp < before, "HP %.0f → %.0f" % [before, _gs.hp])


## [5] 🔴 **내 마법이 적에게 닿는다.** 적이 레이어 4(enemy)가 아니면 캐리어(마스크 5)가 못 보거나
## world로 읽혀 **부딪히기만 하고 take_hit이 안 불린다** — 에러도 경고도 없이 "안 죽는 적"이 된다.
## 그리고 죽으면 그룹에서 빠진다 (숲이 남은 수를 세는 근거).
func _test_my_spell_can_hit_and_kill() -> void:
	print("[5] 내 마법이 적을 때리고 죽인다")
	await _fresh()
	var enemy = _enemies()[0]
	var hits := []
	# 🔴 Callable을 붙잡아 뒤에서 **끊는다.** 안 끊으면 아래 take_hit이 `enemy`를 지운 뒤에도
	# 람다가 살아, 이후 테스트([8])가 다른 적을 죽여 enemy_hit을 쏠 때마다 죽은 캡처가 발화해
	# "Lambda capture was freed" 에러를 쏟는다 (테스트는 통과해도 로그가 오염된다).
	var on_hit := func(who, dmg, _rune) -> void:
		if who == enemy:
			hits.append(dmg)
	_bus.enemy_hit.connect(on_hit)
	var from: Vector2 = enemy.global_position + Vector2(-120, 0)
	_bus.ring_cast_requested.emit(_assembly(1.0), from, Vector2(1, 0))
	var frames := 0
	while hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	_check(not hits.is_empty(), "쏜 진이 적을 때렸다 (%d 물리 프레임) — 0이면 레이어 계약이 깨졌다" % frames)
	_clear()

	# 계약: take_hit이 치명타면 죽고 그룹에서 빠진다.
	var before := _enemies().size()
	enemy.take_hit(9999.0, 0, 0, 0.0)
	await process_frame
	_check(_enemies().size() == before - 1,
		"치명타를 맞은 적이 사라진다 (%d → %d)" % [before, _enemies().size()])
	_bus.enemy_hit.disconnect(on_hit)


## [6] 🔴 귀환 = `extraction_success`. 수신자(GameState 가방 정산 · SaveManager 자동 저장)는
## **이미 연결돼 있는데 세션 25까지 발신자가 없었다** — 필드가 그 자리다 (event_bus.gd 주석).
## 안 쏘면 돌아와도 **아무것도 정산되지 않는다.** 조용히.
func _test_extract_banks_the_run() -> void:
	print("[6] 귀환 지점에서 E → extraction_success (가방 정산 · 자동 저장)")
	await _fresh()
	var got := []
	var cb := func() -> void: got.append(1)
	_bus.extraction_success.connect(cb)
	_zone(&"extract").interacted.emit()
	await process_frame
	_check(got.size() == 1, "귀환하면 extraction_success가 한 번 온다 (실제 %d)" % got.size())

	# 🔴 두 번 눌러도 한 번만 — 귀환 중에 또 E를 누르면 씬을 두 번 갈아탄다.
	_zone(&"extract").interacted.emit()
	await process_frame
	_check(got.size() == 1, "연타해도 한 번뿐 (실제 %d)" % got.size())
	_bus.extraction_success.disconnect(cb)


## [7] 🔴 쓰러지면 `bag_lost`. 지금은 가방이 비어 no-op이지만 **그게 계약이다** —
## 탁본이 붙는 날 저절로 돈다. SaveManager도 여기 물려 있다 (세이브스컴 방지).
## 사용자 확정: 벌은 없다 — 그냥 베이스로 돌아온다.
func _test_death_loses_the_bag() -> void:
	print("[7] 쓰러지면 bag_lost (벌은 없지만 계약은 돈다)")
	await _fresh()
	var got := []
	var cb := func() -> void: got.append(1)
	_bus.bag_lost.connect(cb)
	_gs.damage_player(99999.0)
	await process_frame
	_check(got.size() == 1, "HP 0 → bag_lost가 한 번 온다 (실제 %d)" % got.size())
	_bus.bag_lost.disconnect(cb)


## [8] 🔴 적을 죽이면 **드롭이 가방에 담긴다** (세션 27 — 사용자: "드롭을 먼저").
## 세션 30에 숲이 비엘리트 5종(슬라임·안개·사냥개·덩굴·갑충)으로 늘었다 — 드롭이 전부 확률이라
## **여럿을 죽여 하나라도** 담기는지 본다. "안 담긴다"(호출 누락)와 "가끔 안 나온다"(확률)를
## 가르려 표본을 키운다(8마리 중 갑충 0.9·사냥개 0.8·안개 0.7 등이 섞여 사실상 확실).
func _test_kill_drops_into_bag() -> void:
	print("[8] 적을 죽이면 드롭이 가방에 담긴다")
	await _fresh()
	_gs.bag.clear()
	var enemies := _enemies()
	_check(enemies.size() >= 5, "표본이 되는 적이 충분하다 (%d)" % enemies.size())

	# 배치된 적들의 드롭 테이블 합집합 — 담긴 건 반드시 이 안의 id여야 한다 (엉뚱한 id 방지).
	# 🔴 공개 API로만: enemy_id(@export) + Db.get_enemy. 내부 _def를 더듬지 않는다(리팩터 함정).
	var db = root.get_node("/root/Db")
	var valid := {}
	for e in enemies:
		var def = db.get_enemy(e.enemy_id)
		if def != null:
			for d in def.drops:
				valid[d.item_id] = true

	for e in enemies:
		e.take_hit(9999.0, 0, 0, 0.0)
	await process_frame
	var total := 0
	for entry: Dictionary in _gs.bag:
		total += int(entry["count"])
	_check(total > 0, "적 %d마리를 죽이면 가방에 뭔가 담긴다 (실제 %d개 — 0이면 _die가 드롭을 안 굴린 것)"
		% [enemies.size(), total])
	# 담긴 건 전부 이 적들의 드롭 테이블 아이템이어야 한다 (엉뚱한 id가 아니라).
	for entry: Dictionary in _gs.bag:
		_check(valid.has(entry["id"]),
			"담긴 %s가 배치된 적의 드롭 테이블에 있다" % str(entry["id"]))
	_gs.bag.clear()


## [9] 🔴 드롭의 **익스트랙션 계약** — 귀환하면 창고로, 죽으면 사라진다.
## 드롭 자체(위)와 인벤 배선(가방→창고)이 **이어지는지**를 본다. 이게 루프의 심장이다.
func _test_drop_survives_extraction_lost_on_death() -> void:
	print("[9] 드롭 → 귀환하면 창고행 · 죽으면 사라진다")
	await _fresh()
	_gs.bag.clear()
	var before: int = _gs.get_count(&"mat_slime_core")

	# 드롭을 확정으로 하나 넣는다 (확률에 흔들리지 않게 직접 — 인벤 흐름만 본다)
	_gs.add_to_bag(&"mat_slime_core", 3)
	_zone(&"extract").interacted.emit()      # 귀환
	await process_frame
	_check(_gs.get_count(&"mat_slime_core") == before + 3,
		"귀환하면 가방이 창고로 회수된다 (%d → %d)" % [before, _gs.get_count(&"mat_slime_core")])
	_check(_gs.bag.is_empty(), "회수 후 가방은 빈다")

	# 이번엔 죽어서 잃는다 — 창고는 그대로, 가방만 증발
	await _fresh()
	var banked: int = _gs.get_count(&"mat_slime_core")
	_gs.add_to_bag(&"mat_slime_core", 5)
	_gs.damage_player(99999.0)                # 사망 → bag_lost
	await process_frame
	_check(_gs.bag.is_empty(), "죽으면 가방이 비워진다")
	_check(_gs.get_count(&"mat_slime_core") == banked,
		"죽어도 창고(이미 회수한 것)는 그대로다 (%d)" % banked)


# ── 헬퍼 ──

## 매번 **새 숲**에서 시작한다. 앞 숲을 남기면 플레이어가 둘이 되고(그룹 "player"가 엉킨다)
## EventBus 수신자도 둘이 돼 `_die`가 두 번 돈다.
## ⚠ 귀환·사망 테스트는 `change_scene_to_packed`를 태워 **베이스를 current_scene으로 올린다** —
## 그것도 같이 치운다 (안 치우면 다음 테스트에 베이스의 플레이어·발사 시스템이 섞여 든다).
func _fresh() -> void:
	if _forest != null:
		_forest.free()
		_forest = null
	if current_scene != null:
		current_scene.free()
		current_scene = null
	_forest = _scene.instantiate()
	root.add_child(_forest)
	await process_frame
	await physics_frame


func _assembly(score: float) -> Dictionary:
	var r := []
	for k in 8:
		r.append(GLYPH_NONE)
	return {"rings": [r], "score": score}


func _enemies() -> Array:
	var out := []
	for n in get_nodes_in_group("enemies"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


func _carriers() -> Array:
	var out := []
	for n in get_nodes_in_group("player_projectiles"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


## 🔴 그룹으로 찾는다 — **적이 나를 찾는 바로 그 경로**다. 노드 경로로 찾으면 그룹이 빠져도
## 테스트는 통과하고 게임에서만 적이 굳는다 (검출력이 0이 된다).
func _player():
	return get_first_node_in_group("player")


func _zone(id: StringName):
	for z in get_nodes_in_group("interact_zones"):
		if z.zone_id == id:
			return z
	return null


func _clear() -> void:
	for n in _carriers():
		n.queue_free()
	for n in get_nodes_in_group("pillars"):
		n.queue_free()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
