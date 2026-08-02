extends SceneTree
## 챕터 보스방 자동 검증 — **챕터 루프**: 골라 들어가 · 보스를 잡고 · 살아서 출구로 나온다.
##   통과하면 "TEST_CHAPTER_OK". 재는 축 = 챕터 `.tres` 로드 · 보스 스폰 두 경로 · 접촉 피해 ·
##   내 마법이 보스에 닿나 · 처치 → codex + 보상 룬 · 출구 정산(보스 전/후) · 사망 → bag_lost ·
##   미등록 챕터 폴백 · 풀/네임드/지점 산출 **데이터** 유효성.
## ⚠ 못 잡는 것: 클릭 도달·패널 카드 클릭·상자 렌더 — 실게임 MCP 몫.
## ⚠ **이 파일은 `interacted`를 직접 emit해 「정산 채널」만 잰다 — 실제 [E] 눌림은 아무 그물도 안 잰다.**
##   걸어가 나가는 경로가 다시 서면 그때 실눌림 그물을 새로 세워라(선례 = `test_spell_cast_auto`의 이벤트 주입).
## ⚠ [8]은 오염 가드를 재느라 push_error 한 줄(USER ERROR)을 **의도적으로** 낸다.
## ⚠ -s 모드는 오토로드 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.

const GLYPH_NONE := -1

## 챕터별 잡몹 **자리 수**를 명시 상수로 박는다.
## 🔴 데이터에서 파생(`ch.mob_spawns.size()`)하면 **표를 비워도 통과한다** — 실제로 ch2·ch3가
##  0마리인 채 전 스위트가 그린이었다. 손으로 박아야 「배치를 채웠다」가 측정된다.
## ⚠ 굴림은 「자리 수」가 아니라 「거기 뭐가 서나」를 흔들므로 이 표는 정확 일치다.
## ⚠ F5로 수량을 조이면 이 표도 같이 고쳐라 — 그게 이 상수의 목적이다.
const MOB_COUNT: Dictionary = {&"ch1": 9, &"ch2": 7, &"ch3": 9}

## 챕터 확정 보상 실값 표 — 보스를 잡으면 그 보스의 속성 룬을 얻는다.
## 🔴 손으로 박는다 — ch2·ch3의 `reward_unlock`이 **빈 문자열**이던 걸 아무 그물도 안 잡았다.
const REWARD: Dictionary = {&"ch1": &"rune_water", &"ch2": &"rune_wind", &"ch3": &"rune_grass"}

## 「만든 적이 무대에 오르나」 — 두 갈래다.
## `STAGED` = 무대에 **서야 한다**(안 서면 유령 콘텐츠다).
## `BENCHED` = {적 id: 왜 뺐나}. 🔴 **일부러** 안 서되 **정의는 살아 있어야 한다.**
##  🔴 둘이 짝이라 둘 다 필요하다 — 「안 선다」만 재면 `.tres`를 통째로 지워도 그린이고,
##   「살아 있다」만 재면 스폰이 되살아나도 그린이다. 다시 세우면 줄을 BENCHED→STAGED로 옮겨라.
const STAGED: Array[StringName] = [&"hound"]
const BENCHED: Dictionary = {
	&"hound_alpha": "세112 R8 — hound와 ai가 똑같이 charge라 구별점이 HP·크기·tint·드롭(전부 스칼라)뿐",
}

## 🔴 **나가는 길의 zone_id — 종류가 이것 하나다.**
## ⚠ 노드 이름·좌표로 바꾸지 마라 — 판 종료가 다른 노드에 붙는 날 그물만 제자리에 남는다.
const EXIT_ZONE := &"exit"


var failures: int = 0
var _bus = null
var _gs = null
var _db = null
var _scene = null
var _room = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		print("TEST_CHAPTER_TIMEOUT — 40초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_scene = load("res://src/field/boss_room.tscn") as PackedScene

	await _test_chapters_load()
	await _test_chapter_tables()
	await _test_landmark_drops()
	await _test_boss_spawn_both_paths()
	await _test_contact_damage()
	await _test_my_spell_can_hit_boss()
	await _test_kill_plants_clear_and_exits_unchanged()
	await _test_exit_extracts_without_boss()
	await _test_reward_label_on_screen()
	await _test_exit_banks_the_run_after_clear()
	await _test_death_loses_the_bag()
	await _test_missing_chapter_falls_back()

	# 🔴 뒷정리 — extraction_success·bag_lost에 SaveManager가 물려 있어 **진짜 세이브를 쓴다.**
	# 안 지우면 플레이 세이브가 테스트 찌꺼기로 덮인다.
	root.get_node("/root/SaveManager").wipe_save()

	if failures == 0:
		print("TEST_CHAPTER_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_CHAPTER_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 챕터 3장이 Db를 거쳐 로드된다 — `.tres`가 한 글자 어긋나면 리소스가 **조용히 사라지고**
##  전 스위트가 그린이다. order·보스 id 실재·클리어 키 파생까지 한 번에 잰다.
func _test_chapters_load() -> void:
	print("[1] 챕터 3장 로드 (Db 경유) · order · 파생 클리어 키")
	var expected := {&"ch1": 1, &"ch2": 2, &"ch3": 3}
	for id: StringName in expected:
		var ch = _db.get_chapter(id)
		_check(ch != null, "Db.get_chapter(%s)가 null이 아니다 (파서가 거부하면 조용히 스킵)" % id)
		if ch == null:
			continue
		_check(ch.order == expected[id], "%s order == %d (실제 %d)" % [id, expected[id], ch.order])
		_check(_db.get_enemy(ch.boss_enemy_id) != null,
			"%s 보스 id(%s)가 Db.enemies에 실재한다" % [id, ch.boss_enemy_id])
	var sorted = _db.chapters_sorted()
	_check(sorted.size() == 3, "chapters_sorted가 3장 (실제 %d)" % sorted.size())
	var ch3 = _db.get_chapter(&"ch3")
	if ch3 != null:
		_check(ch3.boss_scene_path != "" and ResourceLoader.exists(ch3.boss_scene_path),
			"ch3 전용 씬 경로(%s)가 실재한다" % ch3.boss_scene_path)
	var ch1 = _db.get_chapter(&"ch1")
	if ch1 != null:
		_check(_db.chapter_clear_id(ch1) == &"chapter_clear_ch1",
			"클리어 키 파생 == chapter_clear_ch1 (실제 %s)" % _db.chapter_clear_id(ch1))


## [1b] 🔴 챕터 3장의 **배치·보상 실값 표** — 기대치를 손으로 박아 잰다.
## 배치 수를 데이터에서 파생하면 표를 비워도 통과한다(MOB_COUNT 머리말). 보상도 같은 결이다.
## 🔴 보상 id가 **실재하는 룬**인지도 잰다 — 오타면 클리어해도 아무것도 안 열리는데
##  `codex_unlocked`는 그대로 발신돼 **에러 없이 조용히 사라진다**.
func _test_chapter_tables() -> void:
	print("[1b] 챕터 3장 배치·보상 실값 표 (명시 상수 대조)")
	var CT: GDScript = load("res://src/core/codex_text.gd")
	for cid: StringName in MOB_COUNT:
		var ch = _db.get_chapter(cid)
		if ch == null:
			_check(false, "%s가 로드됐다" % cid)
			continue
		_check(ch.mob_spawns.size() == int(MOB_COUNT[cid]),
			"%s: 잡몹 %d마리 (실제 %d — 0이면 빈 방이다)" % [cid, int(MOB_COUNT[cid]), ch.mob_spawns.size()])
		_check(ch.reward_unlock == REWARD[cid],
			"%s: 보상 == %s (실제 %s)" % [cid, REWARD[cid], ch.reward_unlock])
		# 🔴 보상 id가 실재하는 룬인가 — 리졸버가 종류를 못 찾으면 오타이거나 데이터가 죽은 것이다.
		_check(CT.kind_of(ch.reward_unlock) == CT.KIND_RUNE,
			"%s: 보상 %s가 실재하는 룬이다 (리졸버 판정 '%s')" % [cid, ch.reward_unlock, CT.kind_of(ch.reward_unlock)])
		# 죽은 항목 = **이 자리가 아무것도 안 세운다** — `enemy_id`가 실재하거나, `pool_tag`가
		#  살아 있는 후보를 갖거나 둘 중 하나여야 한다(굴리는 자리는 `enemy_id`가 비는 게 정상이다).
		# 🔴 빈 항목·오타 태그·후보 전멸이면 **아무 적도 안 서는데 에러가 0**이다.
		var dead := 0
		for ms in ch.mob_spawns:
			if ms == null:
				dead += 1
			elif ms.pool_tag != &"":
				if _live_pool_ids(ch, ms.pool_tag).is_empty():
					dead += 1
			elif ms.enemy_id == &"" or _db.get_enemy(ms.enemy_id) == null:
				dead += 1
		_check(dead == 0, "%s: 배치 항목이 전부 뭔가를 세운다 (죽은 항목 %d — id도 태그도 없는 자리)"
			% [cid, dead])
		_check_pools(ch)
	# 🔴 유령 콘텐츠 감지기 — 배치·풀·네임드 셋을 **다** 훑는다. `named_pool` 훑기를 그만두면
	#  「일부러 뺐다」를 재는 쪽(`BENCHED`)이 자명 통과가 된다.
	var seen := {}
	for cid2: StringName in MOB_COUNT:
		var c2 = _db.get_chapter(cid2)
		if c2 == null:
			continue
		for ms2 in c2.mob_spawns:
			if ms2 != null and ms2.enemy_id != &"":
				seen[ms2.enemy_id] = true
		for mw in c2.mob_pool:
			if mw != null and mw.enemy_id != &"" and mw.weight > 0:
				seen[mw.enemy_id] = true
		for ns2 in c2.named_pool:
			if ns2 != null and ns2.enemy_id != &"" and ns2.chance > 0.0:
				seen[ns2.enemy_id] = true
	for id: StringName in STAGED:
		_check(seen.has(id), "%s가 어느 챕터엔가 실제로 배치됐다 (세87까지 스폰 0곳)" % id)
	for id: StringName in BENCHED:
		_check(not seen.has(id),
			"🔴 %s는 지금 **일부러** 무대에 없다 (%s) — 배치가 돌아왔으면 위상을 다시 정한 것이니 STAGED로 옮겨라"
				% [id, BENCHED[id]])
		# 🔴 짝이 되는 줄 — 스폰만 뺀 것이지 삭제가 아니다. 정의를 지우면 여기와 `test_charge_telegraph_auto [5]`가 같이 죽는다.
		_check(_db.get_enemy(id) != null,
			"🔴 %s의 정의는 Db에 살아 있다 (R8은 스폰만 뺀 것이지 삭제가 아니다)" % id)


## [1c] 🔴 풀·네임드 **데이터 쪽** 검사 — 굴림 자체는 `test_mob_roll_auto`가 잰다(그 파일은
##  in-memory 주입으로 기계를 재므로 실데이터가 조용히 비거나 어긋난 걸 못 잡는다 — 두 축이 짝이다).
## 🔴🔴 가장 중요한 줄 = **보스 id 제외**. 풀·네임드에 `boss_enemy_id`가 섞이면 잡몹 한 마리를
##  잡았을 뿐인데 `chapter_clear_*` + 보상 룬이 **전부 조용히 나간다(에러 0)**.
func _check_pools(ch) -> void:
	var cid: StringName = ch.id
	# 이 챕터가 **실제로 세우는** 지점 id 집합 — `Db`에 있느냐가 아니라 이 챕터의 `landmarks`에
	#  있느냐를 본다(다른 챕터의 지점을 가리키면 해석기가 세울 데를 못 찾는다).
	var lm_ids := {}
	for slot in ch.landmarks:
		if slot != null and slot.landmark_id != &"":
			lm_ids[slot.landmark_id] = true
	for mw in ch.mob_pool:
		if mw == null:
			_check(false, "%s: mob_pool에 null 항목이 있다" % cid)
			continue
		_check(_db.get_enemy(mw.enemy_id) != null,
			"%s: 풀 항목 %s가 실재하는 적이다 (오타면 그 자리가 조용히 빈다)" % [cid, mw.enemy_id])
		_check(mw.enemy_id != ch.boss_enemy_id,
			"🔴🔴 %s: 풀에 보스 id(%s)가 없다 — 있으면 잡몹 한 마리가 챕터를 클리어한다" % [cid, ch.boss_enemy_id])
		_check(mw.weight > 0,
			"%s: 풀 항목 %s의 weight > 0 (0 이하는 안 뽑히니 데이터에 남길 이유가 없다)" % [cid, mw.enemy_id])
	# ⚠ **지금 이 루프는 0바퀴 돈다**(세 챕터 다 `named_pool`이 비었다) — 아래 다섯은 자명 통과다.
	#  🔴 그래도 남긴다: 네임드를 되살리는 순간 한 줄도 안 고치고 저절로 측정으로 바뀐다.
	#  🔴 「지금 안 선다」를 실제로 재는 곳은 [1b]의 `BENCHED`다 — 그 표가 없으면 0바퀴가 「통과」로 위장한다.
	for ns in ch.named_pool:
		if ns == null:
			_check(false, "%s: named_pool에 null 항목이 있다" % cid)
			continue
		_check(_db.get_enemy(ns.enemy_id) != null,
			"%s: 네임드 %s가 실재하는 적이다" % [cid, ns.enemy_id])
		_check(ns.enemy_id != ch.boss_enemy_id,
			"🔴🔴 %s: 네임드에 보스 id(%s)가 없다 (풀과 같은 이유)" % [cid, ch.boss_enemy_id])
			# 🔴 확률이 0이나 1로 굳어도 **에러가 없다** — 0 = 영영 안 뜸(만든 값어치 0) ·
			#  1 = 매 판 뜸(「오늘 뭔가 있다」가 아님). 양끝이면 「가끔 뜬다」가 통째로 죽은 것이다.
		_check(ns.chance > 0.0 and ns.chance < 1.0,
			"🔴 %s: 네임드 %s의 확률이 양끝이 아니다 (실제 %.2f — 0이면 영영 안 뜨고 1이면 늘 뜬다)"
				% [cid, ns.enemy_id, ns.chance])
			# 🔴 조건부다 — 「비어 있어야 한다」로 두면 **데이터를 채우는 순간 전 스위트가 빨개진다.**
			#  🔴 이 형태가 곧 「미등록 id를 잡는 그물」이다 — 검사를 두 개 만들지 마라.
			#  ⚠ 미등록 id는 조용하다: 해석기가 자리를 못 찾으면 원점에 서거나 안 서는데, 둘 다 「오늘은 안 떴네」로 읽힌다.
		_check(ns.at_landmark == &"" or lm_ids.has(ns.at_landmark),
			"%s: 네임드 %s의 at_landmark가 비었거나 이 챕터의 지점이다 (실제 '%s' / 챕터 지점 %s)"
				% [cid, ns.enemy_id, ns.at_landmark, str(lm_ids.keys())])
			# 🔴 지점이 선 챕터의 네임드는 **그 지점에** 선다. 반대(자유 좌표)가 에러 0 · 전 스위트 그린이었다 —
			#  둥지를 세워 놓고 우두머리는 반대편에 섰고, 위 줄로는 못 잡는다(「비었으면 통과」라서).
			#  ⚠ `test_nest_open_auto [4]`로도 못 잡는다 — 그건 해석기를 in-memory 주입으로 재고 **라이브 `.tres`를 안 본다.**
			# 🔴 「지점 옆이 아닌 네임드」를 일부러 만들 땐 이 줄을 같이 고쳐라 — 막아서는 건 고장이 아니라 의도다.
		if not lm_ids.is_empty():
			_check(ns.at_landmark != &"",
				"🔴 %s: 지점을 세운 챕터인데 네임드 %s의 at_landmark가 비어 있다 — 우두머리가 지점과 무관한 자리에 선다 (챕터 지점 %s)"
					% [cid, ns.enemy_id, str(lm_ids.keys())])


## [1d] 🔴 지점 산출(`LandmarkDef.drops`)의 **조건부 대조**.
## 🔴 왜 조건부인가 — 「지점 0이면 빨강」으로 짜면 지점을 안 세운 챕터가 첫날부터 빨개진다.
##  재려는 건 「지점을 안 세웠다」가 아니라 **「세워 놓고 아무것도 안 주는 지점」**이다.
## 재는 것 셋:
##  ⓐ 지점이 선 챕터는 그 `drops`가 비어 있지 않다. ⚠ `lm_nest`는 지금 **의도적으로 빨갛다** —
##    빨강을 없애려고 이 줄을 무르게 만들지 마라.
##  ⓑ 🔴 **바닥 층**(반드시 뭔가 나오는 줄)이 최소 하나. 줄마다 독립 굴림이라 확정 줄이 없으면
##    **빈손인 판이 확률적으로 반드시 나오는데 에러가 0**이고, 재현이 확률이라 버그로 안 보인다.
##    🔴 `chance == 1.0`만 재면 부족하다 — `_roll_drops`가 `if n > 0`으로 걸러 `min_count 0`인 줄은
##    확정처럼 보이는데 0을 굴린다. ⇒ 바닥 층 = `chance ≥ 1.0` + `item_id` 있음 + `min_count ≥ 1`.
##  ⓒ 🔴 `unlock_id`·`until_unlock`이 있는 줄이 0 — 굴림이 두 필드를 그대로 처리해서 「지점이
##    문양-고리를 준다」와 「모든 줄이 확정 드롭이 된다」가 데이터 한 줄로 조용히 성립한다.
func _test_landmark_drops() -> void:
	print("[1d] 지점 산출 drops 조건부 대조 (지점이 선 챕터만 · 바닥 층 · unlock 금지)")
	var slots_total := 0
	for cid: StringName in MOB_COUNT:
		var ch = _db.get_chapter(cid)
		if ch == null:
			continue
			# 지점을 안 세운 챕터는 **정상이다** — 조건부의 심장이 이 줄이다.
		if ch.landmarks.is_empty():
			continue
		var seen := 0
		for slot in ch.landmarks:
			if slot == null:
				continue
			var lm = _db.get_landmark(slot.landmark_id)
			if lm == null:
				continue
			seen += 1
			_check_landmark_drops(cid, lm)
		# ⚠ 루프가 **실제로 돌았나** — 슬롯 id가 안 풀리면 위 검사가 통째로 자명 통과가 된다.
		#  (사슬 자체는 `test_landmark_road_auto`가 진다 — 여기 줄은 이 항목의 자기 증명이다.)
		_check(seen == ch.landmarks.size(),
			"%s: 지점 슬롯 %d개가 전부 LandmarkDef로 풀린다 (실제 %d — 밑돌면 아래 검사가 자명 통과다)"
				% [cid, ch.landmarks.size(), seen])
		slots_total += seen
	_check(slots_total > 0,
		"지점이 선 챕터가 하나라도 있다 (실제 %d채 — 0이면 이 항목 전체가 자명 통과다)" % slots_total)


## 지점 한 채의 산출 규칙 — 위 [1d] 머리말의 ⓐⓑⓒ를 한 자리에서 잰다.
func _check_landmark_drops(cid: StringName, lm) -> void:
	var lid: StringName = lm.id
	# ⓐ 세워 놓고 아무것도 안 주는 지점 (지금 lm_nest — 의도된 빨강)
	_check(not lm.drops.is_empty(),
		"🔴 %s: 지점 %s가 산출을 준다 (drops %d줄 — 0이면 밟을 값어치가 없는 이정표다)"
			% [cid, lid, lm.drops.size()])
	if lm.drops.is_empty():
		return
	var floor_rows := 0
	var unlock_rows := 0
	var gate_rows := 0
	for d in lm.drops:
		if d == null:
			_check(false, "%s: 지점 %s의 drops에 null 줄이 있다" % [cid, lid])
			continue
		# ⓑ 바닥 층의 정의 — 「확정처럼 보이는」이 아니라 **「반드시 뭔가 나오는」**이다(머리말 참조).
		if d.chance >= 1.0 and d.item_id != &"" and d.min_count >= 1:
			floor_rows += 1
		if d.unlock_id != &"":
			unlock_rows += 1
		if d.until_unlock != &"":
			gate_rows += 1
	_check(floor_rows >= 1,
		"🔴🔴 %s: 지점 %s에 바닥 층이 있다 (chance≥1.0 + item_id + min_count≥1 인 줄 %d개 — 0이면 빈손인 판이 나온다)"
			% [cid, lid, floor_rows])
	# ⓒ 배타 짝 — 스키마 주석이 금지한 둘을 기계가 진다
	_check(unlock_rows == 0,
		"🔴 %s: 지점 %s의 drops에 unlock_id가 없다 (실제 %d줄 — 있으면 지점이 문양-고리를 준다)"
			% [cid, lid, unlock_rows])
	_check(gate_rows == 0,
		"🔴 %s: 지점 %s의 drops에 until_unlock이 없다 (실제 %d줄 — 있으면 chance가 통째로 죽어 전부 확정 드롭이 된다)"
			% [cid, lid, gate_rows])


## [2] 보스 스폰 **두 경로 각각** + 출격 만HP.
## ch1 = forest_enemy 범용(add_child 전 enemy_id 대입) · ch3 = snake_boss 전용 씬.
## 🔴 스폰 위치는 **등가가 아니라 반경**으로 잰다 — 보스는 살아 움직여, 부하가 걸리면 몇 px 어긋나
##  `< 2.0`이 3~4회 중 1회 빨개졌다(실측 드리프트 8.5px). 재는 건 「지금 어디」가 아니라 「거기서 **시작했나**」다.
## ⚠ **이 검사는 「대입이 `add_child` 앞」 계약을 재지 않는다** — 뮤테이션 3회 전부 그린이었다.
##  그 계약이 진짜로 망가뜨리는 건 `snake_body`의 자취 프리시드인데 이후 프레임에 따라잡아 복구된다
##  ⇒ **지금 어느 그물도 안 잰다.** 재려면 `snake_body`를 단위로 세워라(씬을 통과시키면 또 flake다).
const SPAWN_TOL := 60.0

func _test_boss_spawn_both_paths() -> void:
	print("[2] 보스 스폰 두 경로 (ch1 범용 · ch3 전용 씬) + 출격 만HP")
	_gs.hp = 7.0
	await _fresh(&"ch1")
	_check(is_equal_approx(_gs.hp, _gs.hp_max()),
		"출격하면 HP가 찬다 %.0f/%.0f (안 그러면 죽는 게 이득)" % [_gs.hp, _gs.hp_max()])
	# ch1엔 잡몹 길이 깔려 "enemies"에 보스 1 + 잡몹 N이 섞인다 — 보스는 enemy_id로 특정한다.
	var ch1 = _db.get_chapter(&"ch1")
	_check_enemy_count(&"ch1")
	# 🔴 카메라가 **방 안에 묶였나** — `player.tscn`의 Camera2D엔 `limit_*`이 없어(마을에선 경계까지
	#  잘 안 가 안 드러났다) 보스방이 `_ready`에서 Ground rect로 채운다. 안 채우면 화면 절반이 방 밖이다.
	# ⚠ 값을 박지 않고 Ground rect와 **대조**한다 — 방 크기를 바꿔도 거짓 빨강이 안 난다.
	var ground: ColorRect = _room.get_node_or_null("Ground")
	var cam: Camera2D = _room.get_node_or_null("Player/Camera2D")
	if ground != null and cam != null:
		var tl: Vector2 = ground.global_position
		_check(cam.limit_left == int(tl.x) and cam.limit_top == int(tl.y)
			and cam.limit_right == int(tl.x + ground.size.x) and cam.limit_bottom == int(tl.y + ground.size.y),
			"카메라 limit == Ground rect (실제 L%d T%d R%d B%d / 방 %s~%s)"
			% [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom, tl, tl + ground.size])
	else:
		_check(false, "Ground·Camera2D를 찾았다 (구조가 바뀌면 이 그물이 죽는다)")

	var boss = _boss(&"ch1")
	_check(boss != null, "ch1 보스(slime_elite)가 잡몹 사이에 스폰됐다")
	if boss != null:
		var want: Vector2 = ch1.boss_spawn
		_check(boss.global_position.distance_to(want) < SPAWN_TOL,
			"ch1 보스가 boss_spawn(%s) 근처에서 시작했다 (실제 %s)" % [want, boss.global_position])

	await _fresh(&"ch3")
	var ch3 = _db.get_chapter(&"ch3")
	_check_enemy_count(&"ch3")
	var boss3 = _boss(&"ch3")
	_check(boss3 != null, "ch3 보스(snake_boss)가 스폰됐다")
	if boss3 != null:
		_check(boss3.get_node_or_null("SnakeBody") != null,
			"ch3 보스에 SnakeBody가 있다 = 전용 씬이 진짜 로드됐다 (범용 스폰이면 없다)")
		# 🔴 전용 씬도 boss_spawn에 서야 한다 — 대입이 `add_child` **앞**이어야 `snake_body`가
		#  그 자리 기준으로 자취를 프리시드한다(뒤면 마디가 원점에서 끌려온다 = 「정지 뭉침」).
		var want3: Vector2 = _db.get_chapter(&"ch3").boss_spawn
		_check(boss3.global_position.distance_to(want3) < SPAWN_TOL,
			"ch3 보스가 boss_spawn(%s) 근처에서 시작했다 (실제 %s)" % [want3, boss3.global_position])


## [2b] 접촉 피해 — 붙으면 HP가 깎인다. 🔴 이걸 빼면 **적→플레이어 피해 채널이 전 스위트 어디에도 없다**
##  (ch1 보스는 접촉이 유일한 공격 수단이라 조용히 죽어도 전부 그린이 된다). `GameState.hp`가 원장이다.
func _test_contact_damage() -> void:
	print("[2b] 보스에 닿으면 아프다 (적→플레이어 피해 채널)")
	await _fresh(&"ch1")
	var enemy = _boss(&"ch1")   # 🔴 보스에 붙는다 (잡몹이 아니라 — 보스 접촉 채널을 잰다)
	var player = get_first_node_in_group("player")
	player.global_position = enemy.global_position   # attack_range 안
	var before: float = _gs.hp
	var frames := 0
	while is_equal_approx(_gs.hp, before) and frames < 90:
		await physics_frame
		frames += 1
	_check(_gs.hp < before, "HP %.0f → %.0f (90프레임 안에 접촉 피해)" % [before, _gs.hp])


## [3] 내 마법이 보스에게 닿는다 — **물리 레이어 계약**.
## 적이 레이어 4(enemy)가 아니면 캐리어(마스크 5)가 부딪히기만 하고 take_hit이 안 불린다 —
## 에러도 경고도 없이 "안 죽는 보스"가 된다. 발사 시스템의 존재도 행동으로 함께 확인한다.
func _test_my_spell_can_hit_boss() -> void:
	print("[3] 내 마법이 보스를 때린다 (레이어 계약 · RingSpellSystem 존재)")
	await _fresh(&"ch1")
	# 발사 시스템 존재 — "쏘면 진이 생기나" (노드 이름이 아니라 행동으로).
	_bus.ring_cast_requested.emit(_assembly(1.0), Vector2(9000, 9000), Vector2(1, 0))
	await physics_frame
	_check(_carriers().size() == 1,
		"쏘니 진(캐리어)이 생긴다 = RingSpellSystem이 방에 있다 (실제 %d)" % _carriers().size())
	_clear()

	var boss = _boss(&"ch1")   # 🔴 보스를 특정 (잡몹 섞임)
	var hits := []
	var on_hit := func(who, dmg, _rune) -> void:
		if who == boss:
			hits.append(dmg)
	_bus.enemy_hit.connect(on_hit)
	_bus.ring_cast_requested.emit(_assembly(1.0), boss.global_position + Vector2(-120, 0), Vector2(1, 0))
	var frames := 0
	while hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	_check(not hits.is_empty(),
		"쏜 진이 보스를 때렸다 (%d 물리 프레임) — 0이면 레이어 계약이 깨졌다" % frames)
	_bus.enemy_hit.disconnect(on_hit)
	_clear()


## [4] 처치 → chapter_clear codex + 보상 룬. 클리어 판정 = 처치 순간(루팅·귀환 무관).
## 🔴 **처치는 나가는 길을 하나도 안 바꾼다** — 길은 처음부터 전부 서 있다(탈출이 목표, 보스는 선택).
##  개수를 처치 **전후로 대조**하므로 포탈 스폰이 어떤 이름으로 되살아나도 여기가 빨개진다.
## 🔴 클리어 안내가 **없는 물건을 가리키지 않는지**도 같이 잰다(sticky = 유효한 지시만).
func _test_kill_plants_clear_and_exits_unchanged() -> void:
	print("[4] 처치 → 클리어 codex + 보상 룬 해금 (+ 나가는 길은 처치 전후로 안 변한다)")
	var reward: StringName = REWARD[&"ch1"]
	_gs.codex.erase(&"chapter_clear_ch1")   # 앞 테스트·저장 잔재 제거 — 첫 클리어 경로를 잰다
	_gs.codex.erase(reward)                 # 🔴 보상 첫 획득 경로를 잰다 (맨몸 시작 = 시드 아님)
	await _fresh(&"ch1")
	# 상시 귀환 — 출구는 **처음부터** 있다. 반복 사냥터가 되려면 언제든 나갈 수 있어야 한다.
	# 잡몹만 잡고 나가는 건 **재료만 얻고 확정 보상은 못 얻는** 것이라 공짜가 아니다.
	_check(_zone(EXIT_ZONE) != null,
		"처치 전에도 출구(zone_id=%s)가 있다 = 언제든 나갈 수 있다" % EXIT_ZONE)
	var exits_before: int = _exits().size()
	_check(exits_before >= 1, "처치 전 나가는 길이 %d개 (0이면 방이 통째로 소프트락이다)" % exits_before)
	_check(not _gs.is_unlocked(&"chapter_clear_ch1"), "처치 전엔 클리어 codex가 없다")
	_check(not _gs.is_unlocked(reward), "처치 전엔 보상 룬(%s)이 없다 (맨몸 시작)" % reward)

	# 🔴 보스를 특정해 잡는다 — 잡몹을 잡으면 클리어가 안 된다 (mob_spawns 섞임)
	_boss(&"ch1").take_hit(99999.0, 0, 0, 0.0)
	await process_frame
	await physics_frame
	_check(_gs.is_unlocked(&"chapter_clear_ch1"),
		"보스를 잡으면 chapter_clear_ch1이 심긴다 (codex_unlocked 경유)")
	# 🔴 보상 해금 — `reward_unlock`은 `chapter_clear`와 **별도 축**이다.
	#  뮤테이션: `_on_enemy_died`의 발신 줄을 지우면 여기가 빨개진다(검출력 확인).
	_check(_gs.is_unlocked(reward),
		"보스를 잡으면 보상 룬 %s가 해금된다 (ChapterDef.reward_unlock)" % reward)
	# 🔴 처치가 **새 길을 열지 않는다.**
	_check(_exits().size() == exits_before,
		"🔴 처치해도 나가는 길 수가 그대로다 %d (실제 %d — 늘면 포탈이 되살아난 것)"
			% [exits_before, _exits().size()])
	# 🔴 zone_id를 안 보고 「`_extract`에 이어진 지점 수」로 잰다 — 위 줄은 `&"exit"`으로만 세므로
	#  **다른 zone_id로 되살린 포탈을 못 잡는다**(뮤테이션 실측).
	# ⚠ 「지점 수 == 출구 수」로 재지 마라 — 지점이 자기 InteractZone을 들고 오면 거짓 빨강이다.
	_check(_extract_wired_count() == exits_before,
		"🔴 `_extract`에 이어진 지점이 출구 %d개뿐이다 (실제 %d — 이름만 바꾼 포탈도 여기 걸린다)"
			% [exits_before, _extract_wired_count()])
	# 🔴 이 검사는 **방향이 뒤집힌 것**이다 — 옛 줄은 "출구로 나가라"를 **요구**해 폐기된 규칙을 굳혔고,
	#  코드를 고치자 여기가 빨개져 **고치지 말라고 압력을 줬다**. 지우지 않고 뒤집었다(잴 대상은 그대로다).
	# ⚠ 목록에 새 낱말을 더할 땐 **폐기가 확정된 것만** 넣어라(살아 있는 낱말은 거짓 빨강이다).
	var clear_line: String = _room.get_node("Hud/Hud").say_line()
	for dead: String in ["포탈", "출구", "꾹"]:
		_check(not clear_line.contains(dead),
			"🔴 클리어 안내가 **폐기된 규칙('%s')**을 안 가르친다 (sticky = 유효한 지시만): '%s'"
				% [dead, clear_line])
	_check(clear_line.contains(_db.get_chapter(&"ch1").title),
		"🔴 클리어 안내가 **무엇을 깼는지**는 말한다 (자명 통과 방지 — 빈 줄이면 위 셋이 전부 통과다): '%s'"
			% clear_line)


## [4b] 🔴 **보스를 안 잡고** 남쪽 출구로 나간다 — 상시 귀환.
##  이게 「반복 사냥터」의 실체다: 잡몹만 잡고 재료를 챙겨 나갈 수 있어야 한다.
##  ⚠ 공짜가 아니다 — 잡몹만 잡고 나가면 재료만 얻고 확정 보상(룬)은 못 얻는다.
## 🔴 정산 경로가 `_extract`에 **실제로 이어졌나**를 잰다 — 연결을 잊으면 가방이 조용히 증발한다.
func _test_exit_extracts_without_boss() -> void:
	print("[4b] 보스를 안 잡고 출구 E → extraction 1회 + 가방→창고")
	await _fresh(&"ch1")
	var ex = _zone(EXIT_ZONE)
	if ex == null:
		_check(false, "출구(zone_id=%s)가 없어 검사 불가" % EXIT_ZONE)
		return
	# 🔴 전제 — 보스가 아직 살아 있다(재려는 것은 「안 잡았는데도 나갈 수 있나」다).
	_check(_boss(&"ch1") != null, "보스가 아직 살아 있다 = 안 잡고 나가는 경로를 잰다 (전제)")
	_gs.bag.clear()
	var before: int = _gs.get_count(&"mat_slime_core")
	_gs.add_to_bag(&"mat_slime_core", 3)
	var got := []
	var cb := func() -> void: got.append(1)
	_bus.extraction_success.connect(cb)
	# 🔴 두 emit을 await 전에 — 씬 전환은 프레임 끝이라 이 시점엔 방이 살아 있고 가드만 재게 된다.
	ex.interacted.emit()
	ex.interacted.emit()
	await process_frame
	_bus.extraction_success.disconnect(cb)
	_check(got.size() == 1, "출구 연타에도 extraction_success 1회 (실제 %d)" % got.size())
	_check(_gs.get_count(&"mat_slime_core") == before + 3,
		"보스를 안 잡아도 가방이 창고로 회수된다 (%d → %d)" % [before, _gs.get_count(&"mat_slime_core")])
	_check(_gs.bag.is_empty(), "회수 후 가방이 빈다")


## [4c] 🔴 클리어 보상 문구 — **실제로 화면에 나가는 줄**을 읽는다.
## 🔴 리졸버(`CodexText`)를 테스트가 직접 부르면 `boss_room`이 옛 경로를 그대로 써도 **그린이다**
##  (뮤테이션 실측: 검출 0). **「결과 값이 같다」는 「같은 길로 왔다」가 아니다.** 그래서 `hud.say_line()`을 읽는다.
## 잡는 것 둘: ① 원시 id 노출("보상: rune_water") ② **거짓 지시**(옛 안내는 룬을 밴드에 끼우라 가르쳤다).
## ⚠ 「표시명이 나온다」는 ch2에서 **검출력이 없다** — 챕터 제목에 이미 "바람"이 들어 있다.
##  진짜 검출자는 **원시 id 부재**와 **「진 중심」**이다.
func _test_reward_label_on_screen() -> void:
	print("[4c] 클리어 보상 문구 — 보스를 잡고 HUD 줄을 읽는다 (원시 id·거짓 안내 금지)")
	var CT: GDScript = load("res://src/core/codex_text.gd")
	for cid: StringName in [&"ch1", &"ch2", &"ch3"]:
		var ch = _db.get_chapter(cid)
		if ch == null:
			continue
		var rid: StringName = ch.reward_unlock
		_gs.codex.erase(rid)                        # 보상 줄은 **첫 처치에만** 붙는다
		_gs.codex.erase(_db.chapter_clear_id(ch))
		await _fresh(cid)
		var boss = _boss(cid)
		if boss == null:
			_check(false, "%s 보스를 못 찾았다" % cid)
			continue
		boss.take_hit(99999.0, 0, 0, 0.0)
		await process_frame
		await physics_frame
		var hud = _room.get_node("Hud/Hud")
		var line: String = hud.say_line()
		_check(not line.contains(String(rid)), "%s: HUD에 원시 id '%s'가 안 나온다" % [cid, rid])
		_check(line.contains(CT.name_of(rid)), "%s: HUD에 표시명 '%s'가 나온다" % [cid, CT.name_of(rid)])
		_check(line.contains("진 중심"),
			"%s: 룬 보상 안내가 「진 중심」이다 (「밴드에 끼워라」면 거짓 지시다)" % cid)


## [5] 🔴 **보스를 잡은 뒤의 정산 채널** — 재클리어(codex가 이미 있는 파밍 재방문) 경로다.
## 🔴 [4b]와 따로 두는 이유 = 재는 게 다르다. [4b]는 *안 잡고* 나가는 길이고,
##  합치면 **원정 정산의 절반이 그물 밖으로 빠진다**.
## 🔴 재방문 소프트락은 구조적으로 없다(출구엔 조건이 없다) — 그래도 한 바퀴 돌려 가드가 codex를 보게 되는 회귀를 잡는다.
func _test_exit_banks_the_run_after_clear() -> void:
	print("[5] 보스 처치 후 출구 E → extraction_success 1회 · 가방이 창고로 (재클리어)")
	await _fresh(&"ch1")   # [4]에서 chapter_clear_ch1이 이미 있다 = 재클리어 경로
	_boss(&"ch1").take_hit(99999.0, 0, 0, 0.0)   # 🔴 보스를 특정 (잡몹 섞임)
	await process_frame
	await physics_frame
	_check(not _exits().is_empty(), "재클리어여도 나가는 길이 있다 (출구엔 조건이 없다)")

	var near = _zone(EXIT_ZONE)
	if near == null:
		_check(false, "출구를 못 찾았다 (검사 불가)")
		return

	_gs.bag.clear()
	var before: int = _gs.get_count(&"mat_slime_core")
	_gs.add_to_bag(&"mat_slime_core", 3)
	var got := []
	var cb := func() -> void: got.append(1)
	_bus.extraction_success.connect(cb)
	# 🔴 두 emit을 await 전에 — 씬 전환은 프레임 끝이라 이 시점엔 방이 살아 있고 가드만 재게 된다.
	# ⚠ 시그널을 직접 쏜다 — 여기서 재는 건 **정산 채널**뿐이고, 실눌림은 지금 그물이 0이다.
	near.interacted.emit()
	near.interacted.emit()
	await process_frame
	_check(got.size() == 1, "귀환은 연타해도 extraction_success가 한 번뿐 (실제 %d)" % got.size())
	_check(_gs.get_count(&"mat_slime_core") == before + 3,
		"보스 근처 출구로 나가도 가방이 창고로 회수된다 (%d → %d)"
			% [before, _gs.get_count(&"mat_slime_core")])
	_check(_gs.bag.is_empty(), "회수 후 가방은 빈다")
	_bus.extraction_success.disconnect(cb)


## [6] 🔴 쓰러지면 bag_lost — 가방 증발 + 자동 저장(세이브스컴 방지). 창고(이미 회수한 것)는 그대로.
func _test_death_loses_the_bag() -> void:
	print("[6] 쓰러지면 bag_lost · 창고는 그대로")
	await _fresh(&"ch1")
	var banked: int = _gs.get_count(&"mat_slime_core")
	_gs.bag.clear()
	_gs.add_to_bag(&"mat_slime_core", 5)
	var got := []
	var cb := func() -> void: got.append(1)
	_bus.bag_lost.connect(cb)
	_gs.damage_player(99999.0)
	await process_frame
	_check(got.size() == 1, "HP 0 → bag_lost가 한 번 온다 (실제 %d)" % got.size())
	_check(_gs.bag.is_empty(), "죽으면 가방이 비워진다")
	_check(_gs.get_count(&"mat_slime_core") == banked,
		"죽어도 창고(이미 회수한 것)는 그대로다 (%d)" % banked)
	_bus.bag_lost.disconnect(cb)


## [8] `pending_chapter`가 비거나 미등록이면 **조용히 빈 방을 띄우지 않는다** — push_error + 베이스 복귀.
## ⚠ 이 테스트는 push_error 한 줄(USER ERROR)을 의도적으로 낸다 — grep은 `SCRIPT ERROR`를 보라.
func _test_missing_chapter_falls_back() -> void:
	print("[8] 미등록 챕터 → 빈 방 금지, 베이스로 되돌아간다 (아래 ERROR 한 줄은 의도된 것)")
	# ⚠ _fresh를 안 쓴다 — 복귀가 베이스를 로드하면 연습장 허수아비 5개가 그룹 "enemies"에 들어와
	# "보스 없음" 검사가 오염된다. add_child **직후**(await 전 = 복귀 전)에 재야 한다.
	if _room != null and is_instance_valid(_room):
		_room.free()
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.free()
	_room = null
	_gs.pending_chapter = &"no_such_chapter"
	var room = _scene.instantiate()
	root.add_child(room)
	current_scene = room
	_check(_enemies().is_empty(), "보스가 스폰되지 않았다 (빈 방을 조용히 띄우지 않는다)")
	for i in 5:   # call_deferred + change_scene 처리 여유
		await process_frame
	_check(not is_instance_valid(room) or current_scene != room,
		"베이스로 되돌아갔다 (방이 current_scene에서 내려갔다)")
	_gs.pending_chapter = &""


# ── 헬퍼 ──

## 매번 **새 방**에서 시작한다. 앞 방을 남기면 플레이어가 둘이 되고(그룹 "player"가 엉킨다)
## EventBus 수신자도 둘이 돼 _die가 두 번 돈다. 귀환·사망·[8]은 change_scene으로 current_scene을
## base로 바꿔 놓는다 — 그것도 같이 치운다.
func _fresh(chapter_id: StringName) -> void:
	if _room != null and is_instance_valid(_room):
		_room.free()
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.free()
	_room = null
	current_scene = null
	_gs.pending_chapter = chapter_id
	_room = _scene.instantiate()
	root.add_child(_room)
	# 🔴 current_scene을 실게임처럼 세운다 — 적 `_die`가 드롭/상자의 부모로 이걸 쓴다.
	#  안 세우면 헤드리스에선 null이라 상자가 조용히 안 떨어진다.
	current_scene = _room
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


## 🔴 보스만 집는다 — "enemies"에 보스+잡몹이 섞여서 `_enemies()[0]`을 쓰면 잡몹을 집어
##  보스를 못 잡는다(클리어가 안 된다). enemy_id로 가른다.
func _boss(chapter_id: StringName):
	var ch = _db.get_chapter(chapter_id)
	if ch == null:
		return null
	for n in _enemies():
		if n.enemy_id == ch.boss_enemy_id:
			return n
	return null


## 🔴 방 안에 실제로 선 적의 수 — **정확 일치가 아니라 범위**인 유일한 자리.
##  네임드는 매 판 독립으로 굴려 「하나도 안 뜸」이 정상이라, 정확 일치면 뜬 판마다 빨개진다.
## 🔴 검출력은 **하한이 옛 정확 기대치 그대로**라 안 떨어진다 — 표를 비우거나 풀 굴림이 조용히
##  실패하면 여전히 하한에서 빨개진다. 상한은 `named_pool.size()`가 천장이라 「굴림이 자리를 늘린다」를 잡는다.
## ⚠ 지금은 `named_pool`이 비어 상한 == 하한(= 정확 일치)이다 — 데이터가 그렇게 말한 것이다.
##  🔴 **파생을 상수로 굳히지 마라** — 네임드를 되살리는 날 거짓 빨강이 된다.
func _check_enemy_count(cid: StringName) -> void:
	var ch = _db.get_chapter(cid)
	var floor_n: int = 1 + int(MOB_COUNT[cid])
	var named_max: int = ch.named_pool.size() if ch != null else 0
	var got: int = _enemies().size()
	_check(got >= floor_n,
		"%s: 보스 1 + 잡몹 %d = 최소 %d마리가 섰다 (실제 %d — 밑돌면 자리가 조용히 비었다)"
			% [cid, int(MOB_COUNT[cid]), floor_n, got])
	_check(got <= floor_n + named_max,
		"%s: 최대 %d마리 (보스1+잡몹%d+네임드%d, 실제 %d — 넘으면 굴림이 자리를 늘린 것)"
			% [cid, floor_n + named_max, int(MOB_COUNT[cid]), named_max, got])


## 어떤 `pool_tag`가 **실제로 세울 수 있는** 적 id들 — 「살아 있는 후보」의 정의를 한 곳에 둔다.
## ⚠ 굴림 구현이 아니라 **데이터 유효성**이다(굴림 자체는 `test_mob_roll_auto`).
##  후보가 0이면 그 자리는 아무것도 안 세우고 **에러가 0**이다 — 그래서 [1b]가 죽은 항목으로 센다.
func _live_pool_ids(ch, tag: StringName) -> Array:
	var out := []
	for mw in ch.mob_pool:
		if mw == null or mw.pool_tag != tag or mw.weight <= 0:
			continue
		if mw.enemy_id == &"" or mw.enemy_id == ch.boss_enemy_id or _db.get_enemy(mw.enemy_id) == null:
			continue
		out.append(mw.enemy_id)
	return out


func _carriers() -> Array:
	var out := []
	for n in get_nodes_in_group("player_projectiles"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


func _zone(id: StringName):
	for z in get_nodes_in_group("interact_zones"):
		if z.zone_id == id:
			return z
	return null


func _interact_zones() -> Array:
	var out := []
	for z in get_nodes_in_group("interact_zones"):
		if not z.is_queued_for_deletion():
			out.append(z)
	return out


## 나가는 길 전량 — 방의 탈출구는 이게 전부다.
func _exits() -> Array:
	var out := []
	for z in _interact_zones():
		if z.zone_id == EXIT_ZONE:
			out.append(z)
	return out


## 🔴 방 안에서 **`_extract`에 이어진** 지점 수 — 「나가는 길이 몇 개인가」의 **zone_id 무관** 정의다.
## `_zone(&"portal")`처럼 값을 박아 재면 **그 값만 피해 되살려도 통과한다**(뮤테이션 실측).
func _extract_wired_count() -> int:
	var n := 0
	for z in _interact_zones():
		for c in z.interacted.get_connections():
			var cal: Callable = c["callable"]
			if cal.get_object() == _room and cal.get_method() == "_extract":
				n += 1
				break
	return n


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
