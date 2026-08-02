extends SceneTree
## 진행 관문(until_unlock 드롭) + 허기 은퇴 자동 검증 — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_progression_auto.gd
## 전 항목 통과 시 "TEST_PROGRESSION_OK" 출력 후 종료 코드 0.
## ⚠ 못 잡는 것: 실게임 드롭 좌표·등급 후광 겉보기 (헤드리스는 렌더를 못 본다).
## 🔴 세이브 안전: 이 테스트는 enemy_died만 쏜다 — SaveManager의 저장 트리거(extraction_success·bag_lost·day_started)가 아니라 진짜 세이브 파일을 안 건드린다.
## codex는 메모리에서만 굴리고 끝에 원상복구한다.
## 공개 API로만 검증한다 — 내부 필드는 계약이 아니다.
## -s 모드는 오토로드 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지. 동적 타입.

## 관문표 — 지금은 0줄이다. 관문 기계(until_unlock 판정 · `forest_enemy._roll_drops`)는 살아 있어 [2][3]이 in-memory 주입으로 잰다.
## 관문을 되살리면 여기 한 줄 + 적 .tres 한 줄이 짝으로 는다.
const GATES := {}

## 🔴 잡몹 재료 드롭표 — `적: [재료 id, …]`를 명시로 박는다(데이터에서 파생하면 아무도 안 떨궈도 통과한다).
## ⚠ 확률·수량은 F5 튜닝값이라 **안 잰다** — 「그 재료가 그 적에게 붙어 있나」만 잰다.
## ⚠ 한 줄뿐이어도 「그래서 안 잰다」로 바꾸지 마라 — ①재료 붙음 ②아이템 실재 ③두루마리 실재 ④병용 금지를 그대로 잰다.
##  새 몹이 오면 여기 한 줄이 는다(그게 이 표의 목적이다: 「잡아도 얻는 게 없다」로 안 돌아가게).
const MOB_MATERIALS := {
	&"hound": [&"mat_hound_fang"],
}

## 🔴 두루마리 보너스 드롭 — 대역마다 다른 고리를 떨군다(어귀·중간·깊은).
## 이게 「깊이 들어갈 이유」의 살(뼈대는 재료→제작). 여럿이 같은 고리면 대역 설계가 무의미해진다.
## ⚠ 잡몹이 하나라 「대역이 갈렸나」는 잴 데이터가 없다 — SKIP으로 명시한다(PASS 위장 금지).
const MOB_SCROLLS := {
	&"hound": &"gr_explode1",
}

## 🔴 적 .tres 전수 스캔 — 파일명 == `id`가 규약이라 스캔한 파일명으로 Db를 조회한다.
## 기대치를 **명시 숫자로도** 박는다: 스캔만 하면 「폴더가 통째로 비어도 0/0 통과」가 되기 때문.
## 적을 더하면(또는 hound를 접으면) 이 숫자를 같이 고친다 = 그게 그물의 값이다.
const ENEMY_DIR := "res://data/enemies"
## 다섯 = 잡몹 `hound` · 네임드 `hound_alpha` · 보스 `slime_elite`·`gale`·`snake_boss`.
## 네임드는 기존 적의 강화판이라 드롭표(MOB_MATERIALS·MOB_SCROLLS)엔 안 든다 — 네임드 보상은 `test_chapter_auto [1c]`가 데이터로 잰다.
const ENEMY_COUNT_EXPECTED := 5

## 적을 세우는 자리 — `_make_enemy`와 [3c]가 같은 값을 본다(베끼면 갈라진다).
## 플레이어가 없는 무풍지대라 자석·추격이 안 끼어든다.
const SPAWN_AT := Vector2(9000, 9000)
## 🔴 [3b]가 주입할 두루마리 — **실재하는 고리**를 쓴다(`hound`가 실제로 떨구는 그것).
## 가짜 id를 쓰면 픽업이 `push_warning`만 남기고 지나가서 「해금물처럼 생긴 무엇」을 재게 된다.
const SCROLL_UNLOCK := &"gr_explode1"
## [3b] ③ 굴림 횟수 — 확정으로 굳는 고장은 **매번** 나오므로 10회면 충분하다
## (거짓 빨강 확률 = 0.02^10 ≈ 1e-17. 늘려도 검출력은 안 오르고 테스트만 느려진다).
const SCROLL_ROLLS := 10
## [3c] 「시체 옆」의 넉넉한 상한(px) — 흩뿌림(22) + BACK 오버슛 + 지터(±6)를 다 삼키고도
## **원점 낙하(≈12728px)**를 못 삼키는 값. 🔴 연출 상수를 베끼지 않는다(조일 때 거짓 빨강이 난다).
const DROP_NEAR_PX := 80.0

var failures: int = 0
## 🔴 0행 스캔은 PASS가 아니라 SKIP으로 찍는다 — 그린만 보고 「불변식이 지켜졌다」로 읽던 자리다.
var skips: int = 0
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
	_test_mob_drop_tables()
	await _test_locked_guaranteed_drop()
	await _test_unlocked_stops_drop()
	await _test_unlock_drop_guard()
	await _test_drop_lands_at_corpse()
	_test_gate_invariants()
	_test_hunger_retired()

	if skips > 0:
		print("TEST_PROGRESSION_SKIPS — %d개 스캔이 0행이라 잠들어 있다 (위 SKIP 줄 참조)" % skips)
	if failures == 0:
		print("TEST_PROGRESSION_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_PROGRESSION_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 `data/enemies/`의 적 .tres 전수가 Db를 거쳐 로드된다 + 관문표와 데이터가 1:1이다.
## .tres 한 글자가 틀리면 파서가 리소스 전체를 거부하고 Db가 말없이 건너뛴다 — 로드 자체가 검증이다.
## 🔴 목록 대신 폴더를 스캔하고 기대 수를 명시 숫자로 박는다 — 손으로 적은 목록은 최다 스폰 적의 파싱사를 못 잡는다.
##   + `params.sprite` 존재 = 스프라이트 유실을 싸게 잡는 곁그물(도형 금지 규칙의 데이터 쪽 짝).
##   + chase·charge 갈래는 `sight_range`·`move_speed`를 .tres가 반드시 쥔다 — 코드 폴백이 없어 결손이면 적이 안 움직인다.
## GATES = 0줄이라 그 루프는 SKIP으로 찍고, 관문을 복원하면 바로 산다.
func _test_db_loads() -> void:
	print("[1] 적 .tres 전수 Db 로드(폴더 스캔) + 관문표 1:1")
	var ids: Array = []
	for f: String in DirAccess.get_files_at(ENEMY_DIR):
		if f.ends_with(".tres"):
			ids.append(StringName(f.get_basename()))
	_check(ids.size() == ENEMY_COUNT_EXPECTED,
		"data/enemies에 적 .tres %d장 (실제 %d — 적을 더했으면 기대치를 같이 올려라)"
			% [ENEMY_COUNT_EXPECTED, ids.size()])
	for id in ids:
		var def = _db.get_enemy(id)
		_check(def != null, "🔴 %s.tres가 Db에서 로드된다 (파일명 == id 규약)" % id)
		if def == null:
			continue
		_check(def.params.has("sprite"), "%s의 params.sprite가 살아 있다 (도트 유실 그물)" % id)
		# 🔴 `sight_range`는 지우면 모든 추격 적이 그 자리에 굳는데 에러가 0이라 살려 둔 값이다.
		# 🔴 `> 0.0`까지 재는 이유: 존재만 재면 값을 0으로 바꾸는 뮤테이션이 통과한다(실측).
		# 🔴 정본 키는 `sight_range`이고 `aggro_range`는 폴백이다 — 둘 중 하나는 반드시 있어야 한다.
		var ai_kind := str(def.params.get("ai", "chase"))
		if ai_kind == "chase" or ai_kind == "charge":
			var sight := float(def.params.get("sight_range", def.params.get("aggro_range", 0.0)))
			_check(sight > 0.0 and def.params.has("move_speed"),
				"🔴 %s(%s)가 sight_range(옛 aggro_range)·move_speed를 .tres로 쥔다 (실제 시야 %.0f — 코드 폴백은 세84에 걷었다)"
					% [id, ai_kind, sight])
	_check(_db.enemies.size() == ENEMY_COUNT_EXPECTED,
		"🔴 Db.enemies == %d종 (실제 %d — 파싱사면 여기서 줄어든다)"
			% [ENEMY_COUNT_EXPECTED, _db.enemies.size()])
	if GATES.is_empty():
		_skip("관문표(GATES) 0줄 → 「관문 1:1 대조」 루프")
	for unlock_id in GATES:
		var enemy_id: StringName = GATES[unlock_id]
		var entry = _gate_entry_of(enemy_id)
		_check(entry != null, "%s에 until_unlock 드롭이 정확히 1줄 있다" % enemy_id)
		if entry != null:
			_check(entry.until_unlock == unlock_id,
				"%s의 관문 = %s (실제 %s)" % [enemy_id, unlock_id, entry.until_unlock])


## [1b] 🔴 잡몹 재료·두루마리 드롭표가 `.tres`에 실제로 붙어 있나 — 어느 적이 무엇을 떨구는지를 표로 박는다.
## 🔴 여기서 잡는 조용한 고장 넷:
##   ① 재료 줄이 아예 빠졌다(= 전부 `coin`만 떨구던 상태로 회귀)
##   ② `item_id` 오타 → Db에 없는 아이템 → 픽업이 마름모 폴백으로 떨어진다
##   ③ 두루마리 `unlock_id` 오타 → 주워도 **아무것도 안 열리는데 에러가 없다**
##   ④ `unlock_id`와 `until_unlock`을 **같은 줄에 병용** → `_roll_drops`가 `chance`를 통째로 무시해
##      0.02 보너스가 모든 잡몹 확정 드롭이 된다(축이 반대라 병용 금지 — DropEntry 주석)
## ⚠ 확률·수량은 F5 튜닝값이라 일부러 안 잰다 — 조이면 거짓 빨강이 될 뿐이다.
func _test_mob_drop_tables() -> void:
	print("[1b] 잡몹 재료·두루마리 드롭표 (세88 — 그전엔 전부 coin만 떨궜다)")
	var CT: GDScript = load("res://src/core/codex_text.gd")
	for mob: StringName in MOB_MATERIALS:
		var def = _db.get_enemy(mob)
		if def == null:
			_check(false, "%s가 Db에 있다" % mob)
			continue
		var items := {}
		var unlocks := {}
		for drop in def.drops:
			if drop.unlock_id != &"":
				unlocks[drop.unlock_id] = true
				# ④ 병용 금지 — 이 조합은 확률을 죽인다.
				_check(drop.until_unlock == &"",
					"%s: 두루마리 줄에 until_unlock을 병용하지 않았다 (병용하면 확정 드롭이 된다)" % mob)
			if drop.item_id != &"":
				items[drop.item_id] = true
		# ① 재료가 붙어 있나 · ② 그 아이템이 Db에 실재하나
		for mat: StringName in MOB_MATERIALS[mob]:
			_check(items.has(mat), "%s가 %s를 떨군다" % [mob, mat])
			_check(_db.get_item(mat) != null,
				"%s는 Db에 실재하는 아이템이다 (없으면 픽업이 마름모 폴백 = 세54 위반)" % mat)
		# ③ 두루마리 고리가 붙어 있고, 실재하는 **고리**인가
		var want_scroll: StringName = MOB_SCROLLS[mob]
		_check(unlocks.has(want_scroll), "%s가 두루마리 %s를 떨군다" % [mob, want_scroll])
		_check(CT.kind_of(want_scroll) == CT.KIND_RING,
			"%s는 실재하는 문양-고리다 (리졸버 판정 '%s' — 오타면 주워도 아무것도 안 열린다)"
			% [want_scroll, CT.kind_of(want_scroll)])
	# 🔴 융합진 레시피가 `mat_night_bloom`을 3개 요구한다 — 생산자가 0곳이 되면 그 레시피가 조용히 도달 불가가 된다.
	# 🔴 Db의 적 전수를 훑는다 — 표(MOB_MATERIALS)만 훑으면 공급원이 옮겨 갔을 때 살아 있는데도 0으로 보인다.
	var bloom_sources := 0
	for mob2: StringName in _db.enemies:
		var d2 = _db.enemies[mob2]
		if d2 == null:
			continue
		for drop2 in d2.drops:
			if drop2.item_id == &"mat_night_bloom":
				bloom_sources += 1
	_check(bloom_sources >= 1,
		"mat_night_bloom 생산자가 ≥1곳 (실제 %d — 0이면 융합진 레시피가 도달 불가)" % bloom_sources)
	# 🔴 대역이 실제로 갈렸나 — 여럿이 같은 고리면 「깊이 들어갈 이유」가 사라진다.
	# ⚠ 잡몹이 하나라 잴 데이터가 없다 → SKIP(0행은 PASS로 위장하지 않는다).
	#  잡몹이 둘이 되는 순간 이 줄이 저절로 측정으로 바뀐다(딱지가 아니라 스위치다).
	if MOB_SCROLLS.size() < 2:
		_skip("잡몹 %d종 → 「두루마리가 대역마다 갈렸나」" % MOB_SCROLLS.size())
	else:
		var distinct := {}
		for mob3: StringName in MOB_SCROLLS:
			distinct[MOB_SCROLLS[mob3]] = true
		_check(distinct.size() == MOB_SCROLLS.size(),
			"두루마리가 잡몹마다 다른 고리다 (잡몹 %d종 / 서로 다른 고리 %d종)"
				% [MOB_SCROLLS.size(), distinct.size()])


## [2] 🔴 미해금이면 chance와 무관하게 항상 떨어진다 — 관문 줄의 chance를 메모리에서 0으로 내리고 3연속 처치로 잰다.
##  chance 1.0인 채로는 확률 폴백 회귀도 항상 떨어져 검출력이 0이다. ⚠ 주입한 DropEntry·ItemDef는 공유 리소스라 [3] 끝에서 되돌린다.
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
	_gs.codex.erase(&"rune_water")   # 세78: rune_water는 이제 시드지만, 이 관문 테스트는 잠긴 상태를 봐야 해 되돌린다


## [3b] 🔴 해금 드롭 가드(`DropEntry.unlock_id`) — 뮤테이션 둘의 검출자다:
##  ⓐ 해금 가드 줄을 통째로 지운다 · ⓑ 그 가드를 `until_unlock`의 `if…elif` 사슬에 섞는다(= `chance`가 죽어 두루마리가 모든 처치 확정 드롭이 된다)
## 🔴 세 다리로 잰다 — 둘로는 못 잡는다(어느 둘만 재도 「아무것도 안 떨구는 고장」이 통과한다):
##    ① chance 1.0 + **미해금** → 나온다        (아래 둘이 자명 통과가 아님을 세운다)
##    ② chance 1.0 + **해금됨** → 안 나온다      (ⓐ 검출자)
##    ③ chance 0.02 + 미해금 → **확정이 아니다**  (ⓑ 검출자 — 거짓 빨강 확률 0.02^10 ≈ 1e-17)
## ⚠ Db의 EnemyDef.drops는 공유 리소스다 — 끝에 주입 줄과 codex를 **반드시** 되돌린다.
func _test_unlock_drop_guard() -> void:
	print("[3b] 🔴 해금 드롭 가드: 이미 해금된 두루마리는 안 떨군다 · 미해금이어도 확정이 아니다")
	var had: bool = _gs.is_unlocked(SCROLL_UNLOCK)
	# ① 미해금 + 확정 확률 → 나온다 (아래 둘의 자명 통과 방지)
	_gs.codex.erase(SCROLL_UNLOCK)
	_inject_scroll(1.0)
	var rows: Array = await _kill_and_snapshot(&"slime_elite")
	_check(_has_unlock(rows, SCROLL_UNLOCK),
		"① 미해금 + chance 1.0 → 두루마리 %s가 나온다 (실제 %s)" % [SCROLL_UNLOCK, str(_unlocks_of(rows))])
	# ② 해금됨 → 안 나온다 (가드 줄을 지우면 여기가 붉는다)
	_gs.codex[SCROLL_UNLOCK] = true
	rows = await _kill_and_snapshot(&"slime_elite")
	_check(not _has_unlock(rows, SCROLL_UNLOCK),
		"🔴 ② 이미 해금이면 chance 1.0이어도 안 나온다 (실제 %s)" % str(_unlocks_of(rows)))
	# ③ 미해금 + 낮은 확률 → **확정이 아니다** (가드를 if/elif 사슬에 섞으면 chance가 죽어 10/10이 된다)
	_gs.codex.erase(SCROLL_UNLOCK)
	_set_scroll_chance(0.02)
	var hits := 0
	for i in SCROLL_ROLLS:
		rows = await _kill_and_snapshot(&"slime_elite")
		if _has_unlock(rows, SCROLL_UNLOCK):
			hits += 1
	_check(hits < SCROLL_ROLLS,
		"🔴 ③ chance 0.02는 확정이 아니다 (%d회 처치 중 %d회 — %d/%d면 chance가 죽었다)"
			% [SCROLL_ROLLS, hits, SCROLL_ROLLS, SCROLL_ROLLS])
	_remove_scroll()
	if had:
		_gs.codex[SCROLL_UNLOCK] = true
	else:
		_gs.codex.erase(SCROLL_UNLOCK)


## [3c] 🔴 낱개가 죽은 자리에 떨어진다 — `spawn_loose`의 좌표 인자를 `Vector2.ZERO`로 바꾸면 여기가 붉는다(그전엔 재는 그물이 0개였다).
## 🔴 범위형으로 잰다 — 흩뿌림·오버슛·지터 상수를 여기 베끼면 연출을 조일 때마다 거짓 빨강이 난다.
##  재려는 건 「몇 px인가」가 아니라 「시체 옆인가, 딴 세상인가」다.
func _test_drop_lands_at_corpse() -> void:
	print("[3c] 🔴 낱개가 죽은 자리에 떨어진다 (스폰 좌표 — 세101에 인자가 됐다)")
	var rows: Array = await _kill_and_snapshot(&"slime_elite")
	_check(not rows.is_empty(),
		"드롭이 하나라도 나왔다 (0이면 아래 거리 검사가 자명 통과다)")
	var worst := 0.0
	for row in rows:
		worst = maxf(worst, (row["pos"] as Vector2).distance_to(SPAWN_AT))
	_check(not rows.is_empty() and worst <= DROP_NEAR_PX,
		"🔴 모든 낱개가 시체에서 %.0fpx 안이다 (최원 %.1fpx — 원점에 떨어지면 여기서 붉는다)"
			% [DROP_NEAR_PX, worst])


## [4] 🔴 랜덤 조각 은퇴 불변식 — Db의 모든 적 드롭 전수.
## 🔴 관문이 0줄이면 이 스캔이 자명 통과라 둘을 더했다:
##   ① `scanned_drops > 0` = 스캔이 실제로 돌았다 — 불변식이 「없음」을 재므로 루프가 죽어도 늘 그린이 되는 구조였다
##   ② 관문이 0줄이면 중복·짝 검사는 SKIP으로 명시한다(PASS로 위장하지 않는다)
## 🔴 양방향 묶기는 마지막 `seen_gates.size() == GATES.size()`가 한다 — 데이터만 늘어도, 표만 늘어도 빨개진다.
func _test_gate_invariants() -> void:
	print("[4] 불변식: 순수 확률 fragment 0곳 · 관문 중복 0 · 관문표 매핑 · 조각 unlock_id 짝")
	var seen_gates := {}   # {until_unlock: enemy_id}
	var loose_fragments := []
	var scanned_drops := 0
	for enemy_id in _db.enemies:
		var def = _db.enemies[enemy_id]
		for drop in def.drops:
			scanned_drops += 1
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
	# 🔴 스캔이 실제로 돌았다 — 이게 없으면 「없음」을 재는 불변식들이 루프 파손 시에도 전부 그린이다.
	_check(scanned_drops > 0,
		"🔴 적 드롭 줄을 실제로 훑었다 (%d줄 — 0이면 스캔이 죽어 아래 불변식이 통째로 자명 통과다)"
			% scanned_drops)
	_check(loose_fragments.is_empty(),
		"🔴 until_unlock 없는 fragment 드롭 0곳 (잔재: %s)" % str(loose_fragments))
	# ⚠ `seen_gates.size() == GATES.size()`는 GATES 0줄인 지금 「어느 적에도 관문 드롭이 없음」을 이름 목록 없이 요구한다.
	if seen_gates.is_empty():
		_skip("실데이터 관문 0줄 → 「중복 0 · 조각 unlock_id 짝 · 관문표 매핑」 검사")
	for unlock_id in GATES:
		_check(seen_gates.get(unlock_id) == GATES[unlock_id],
			"관문표 매핑: %s → %s (실제 %s)" % [unlock_id, GATES[unlock_id], seen_gates.get(unlock_id)])
	# 🔴 양방향: 데이터가 늘면 표를, 표가 늘면 데이터를 요구한다 (한쪽만 고치면 여기가 빨개진다).
	_check(seen_gates.size() == GATES.size(),
		"🔴 양방향: 데이터 관문 수(%d) == 관문표 줄 수(%d)" % [seen_gates.size(), GATES.size()])


## [5] 🔴 허기 은퇴 — 프로퍼티·함수·balance 필드가 전부 사라졌다.
## `"x" in Object`는 프로퍼티·메서드 둘 다 잡는다 — 남아 있으면 여기서 붉는다.
func _test_hunger_retired() -> void:
	print("[5] 허기 은퇴 잔재 0")
	_check(not ("hunger" in _gs), "GameState.hunger 없음")
	_check(not _gs.has_method("hunger_max"), "GameState.hunger_max() 없음")
	_check(not _gs.has_method("restore_hunger_full"), "GameState.restore_hunger_full() 없음")
	for field in ["hunger_max", "hunger_drain_per_sec", "starve_damage_per_tick"]:
		_check(not (field in _gs.balance), "BalanceData.%s 없음" % field)


# ── 헬퍼 ──

## in-memory 관문 주입 — slime_elite에 fragment_water(until_unlock=rune_water) 한 줄 + 조각 ItemDef.
## EnemyDef·Db.items는 공유 리소스라 [3] 끝에서 `_remove_gate`로 반드시 걷는다.
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
	e.global_position = SPAWN_AT   # 플레이어 없음 — 자석·추격 무풍지대
	return e


## [3b]용 두루마리(해금 드롭) 한 줄을 slime_elite에 주입 — `_inject_gate`와 같은 규약(공유 리소스라 반드시 되돌린다).
## 다른 점은 축뿐이다: 이쪽은 `unlock_id`(드롭이 곧 해금), 저쪽은 `until_unlock`(그 codex가 잠긴 동안 확정 드롭).
## 🔴 둘을 한 줄에 병용하지 않는다 — [1b] ④가 데이터에 대해 금지하는 조합이고, 어기면 재려는 대상 자체가 없어진다.
var _injected_scroll = null

func _inject_scroll(chance: float) -> void:
	if _injected_scroll != null:
		_set_scroll_chance(chance)
		return
	var entry = DropEntry.new()
	entry.item_id = &""          # 두루마리 줄은 아이템이 아니다 (배타 — DropEntry 머리말)
	entry.unlock_id = SCROLL_UNLOCK
	entry.chance = chance
	entry.min_count = 1
	entry.max_count = 1
	_injected_scroll = entry
	_db.get_enemy(&"slime_elite").drops.append(entry)

func _set_scroll_chance(chance: float) -> void:
	if _injected_scroll != null:
		_injected_scroll.chance = chance

func _remove_scroll() -> void:
	if _injected_scroll != null:
		_db.get_enemy(&"slime_elite").drops.erase(_injected_scroll)
		_injected_scroll = null


## 스냅샷에서 두루마리 id만 걷는다 (표시·비교용).
func _unlocks_of(rows: Array) -> Array:
	var out := []
	for row in rows:
		if row["unlock"] != &"":
			out.append(row["unlock"])
	return out


func _has_unlock(rows: Array, unlock_id: StringName) -> bool:
	return _unlocks_of(rows).has(unlock_id)


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
## 보스도 낱개로 떨군다 — slime_elite도 drop_pickups 그룹에 그대로 뜬다(형태 분기 없음).
func _kill_and_collect(id: StringName) -> Array:
	var ids := []
	for row in await _kill_and_snapshot(id):
		ids.append(row["item"])
	return ids


## 처치 1회의 픽업 스냅샷: `{"item": StringName, "unlock": StringName, "pos": Vector2}`.
## 🔴 `item_id`만 걷으면 두루마리 줄(= `item_id`가 빈 줄)과 스폰 좌표가 관측 밖이라 [3b]·[3c]가 통째로 눈을 감는다.
func _kill_and_snapshot(id: StringName) -> Array:
	_clear_drops()
	_gs.ui_modal_open = false
	var enemy = _make_enemy(id)
	await physics_frame
	enemy.take_hit(9999.0, 0, 0, 0.0)
	await physics_frame

	var rows := []
	for p in get_nodes_in_group("drop_pickups"):
		rows.append({"item": p.item_id, "unlock": p.unlock_id, "pos": p.global_position})

	_clear_drops()
	return rows


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


## 🔴 잴 데이터가 0행이면 PASS로 위장하지 않는다 — 그린만 보고 「불변식이 지켜졌다」로 읽던 자리다.
## SKIP은 실패가 아니지만 로그에 남아 「이 그물은 지금 잠들어 있다」를 리드가 볼 수 있게 한다.
func _skip(label: String) -> void:
	skips += 1
	print("  SKIP(0행): " + label + " — 잴 데이터가 없다 (복원되면 자동 가동)")
