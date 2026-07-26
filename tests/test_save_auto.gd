extends SceneTree
## 저장/로드 자동 검증 — 시드→저장→오염→로드→복원 확인.
## 실행: Godot --headless --path . -s res://tests/test_save_auto.gd
## 오토로드는 런타임 get_node로만 접근 (-s 컴파일 시점 미등록 함정).

var _pass := 0
var _fail := 0

func _init() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS: ", label)
	else:
		_fail += 1
		print("FAIL: ", label)

func _run() -> void:
	# 🔴 워치독 + 완료 마커 (세84 감사 #44) — 이 파일만 다른 27종과 규약이 갈려 있었다:
	#   ① `TEST_*_OK` 마커가 없어 **리드의 grep 관행(`_OK` + `SCRIPT ERROR`)에 안 걸렸다**
	#     (저장 테스트가 조용히 안 돌아도 "스위트 그린"으로 읽힌다).
	#   ② 워치독이 없어 `_run`이 await에서 죽으면 프로세스가 **영구 hang**한다.
	create_timer(60.0).timeout.connect(func() -> void:
		print("TEST_SAVE_TIMEOUT — 60초 초과")
		quit(1))
	await process_frame
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("Clock")
	var sm: Node = root.get_node("SaveManager")
	var bus: Node = root.get_node("EventBus")

	# 🔴 [0] 테스트 격리 (세션59) — **-s 부팅은 세이브 뿌리가 save_test로 갈라져야 한다.**
	# 전엔 스위트의 자동 저장·wipe_save()가 실제 플레이 세이브(user://save)를 그대로 때려서
	# **스위트 한 번에 타이틀 「이어하기」가 사라졌다** (사용자: *"자꾸 없어지네"*). 이 확인이
	# 없으면 격리 로직이 지워져도 전 스위트가 그린인 채 옛 사고가 조용히 재발한다.
	_check("🔴 -s 부팅 = 세이브 격리 (root=%s)" % sm.save_root(),
		String(sm.save_root()).contains("save_test"))

	# 클린 시작 (격리 확인 뒤 — 여기서부터의 wipe는 테스트 세이브만 지운다)
	sm.wipe_save()
	_check("초기: 세이브 없음", not sm.has_save())

	# 🔴 [F3 회귀 · 세션 26] **부팅만으로 자동 저장이 준비된다.**
	#
	# 세션 21 대청소가 부팅 흐름을 지우면서 `load_game()`을 부르는 사람이 아무도 안 남았다
	# → `_ready_to_save`가 영원히 false → `save_game()`이 **전부 조용히 return** →
	# **게임을 껐다 켜면 그린 마법진이 통째로 사라졌다.** 에러도 경고도 없었다.
	#
	# 🔴 **이 테스트는 그 버그를 두 세션 동안 못 잡았다 — 검출력이 0이었다.** 아래 「로드: true」가
	# `load_game()`을 **테스트가 직접 불러서** `_ready_to_save`를 켜 줬기 때문이다. 게임은 아무도
	# 안 부르는데 테스트만 불러 준 셈이라, 이후의 저장 검증이 전부 **거짓 초록불**이었다.
	# → 그래서 이 확인은 **`load_game()`을 부르기 전**에 있어야 한다. 순서가 곧 검출력이다.
	#
	# 공개 계약으로만 본다: 귀환(`extraction_success`)했는데 세이브 파일이 생기나.
	bus.extraction_success.emit()
	_check("🔴 부팅만으로 귀환 자동 저장이 실제로 돈다 (SaveManager._ready → load_game)",
		sm.has_save())
	sm.wipe_save()

	_check("초기: 로드 false (새 게임)", not sm.load_game())

	# 시드 — ⚠ 아래 두 키는 **Db 무관 순수 라운드트립 프로브**다 (저장/로드는 id를 해석하지 않는다).
	# 세61 전엔 fragment_water/rune_water였는데 그 .tres가 은퇴해 이름만 프로브로 바꿨다(계약 동일).
	gs.add_item(&"ink_basic", 5)
	gs.add_item(&"__probe_item", 1)
	gs.codex[&"__probe_unlock"] = true
	# 🔴 세션 21 대청소: 옛 SpellDesign(SampleDesigns·도안 내구·rune_fill·arrows) 검증은 걷어냈다 —
	# 자유 드로잉 경로가 통째로 삭제됐다. 고리(RingDesign) 라운드트립만 남는다.
	# 고리 도안 라운드트립. 칸 2=발산(1)·칸 6=응집(0), 열린 칸 [2,6].
	# 세션29: 잉크·특별잉크·크기(경제)도 저장에 실린다 — 저장한 진을 다시 쏴도 그때 그 위력·효과가 난다.
	var ring_a: RingDesign = RingDesign.from_assembly(
		{"rune": 0, "rings": [[-1, -1, 1, -1, -1, -1, 0, -1]], "open": [2, 6],
		"ink": &"ink_mid", "special_ink": &"ink_fire_red", "special_ratio": 0.5, "size": 1.4},
		"테스트 진", 0.77)
	# 🔴 세79 M1: **2겹(층 배열) 도안**도 같이 저장한다 — `rings`가 배열의 배열이 되면서
	# `ResourceSaver`가 중첩 배열을 제대로 나르는지가 **저장 무회귀의 유일한 실측**이다
	# (그 전엔 "문법상 문제 없다"는 추론뿐이었다). 층0=확산×3 · 층1=폭발×1.
	var ring_b: RingDesign = RingDesign.from_assembly(
		{"rune": 0, "jin": &"jin_plain_g2",
		"rings": [[6, 6, 6, -1, -1, -1, -1, -1], [7, -1, -1, -1, -1, -1, -1, -1]],
		"open": [0, 1, 2]},
		"2겹 테스트 진", 0.81)
	# 🔴🔴 세81 M2: **룬 2개(융합진) 도안**도 같이 저장한다 (세84 감사 #17). `rings`(중첩 배열)에
	# 프로브를 세운 것과 **같은 종류의 리스크**인데 `runes`엔 프로브가 없었다 —
	# `test_jin_fusion_auto`의 라운드트립은 in-memory라 **디스크를 안 지난다**.
	# 유실되면 `runes_of([], rune)`가 `[rune]`로 폴백해 **에러 없이 단일 룬으로 퇴화**한다
	# (반응 소멸·피해 감소 — 「쏘는 게 조용히 약해진다」).
	# 룬 값 = WATER(2)·BOLT(4) → 자리 순서가 뒤집히면 primary(젖음 바탕)가 갈린다.
	var ring_c: RingDesign = RingDesign.from_assembly(
		{"rune": 2, "runes": [2, 4], "jin": &"jin_fuse",
		"rings": [[-1, -1, -1, -1, -1, -1, -1, -1], [-1, -1, -1, -1, -1, -1, -1, -1]],
		"open": [0, 1]},
		"융합 테스트 진", 0.9)
	gs.ring_designs = [ring_a, ring_b, ring_c] as Array[RingDesign]
	gs.ring_equipped[1] = ring_a
	gs.mana = 42.0
	clock.day = 3
	clock.time_sec = 123.0

	sm.save_game()
	_check("저장: 파일 생성", sm.has_save())

	# 오염 (로드가 복원해야 함)
	gs.inventory.clear()
	gs.codex.erase(&"__probe_unlock")
	gs.ring_designs = [] as Array[RingDesign]
	# 🔴 크기를 **리터럴로 쓰지 않는다** (세84 감사 #34 — `EQUIP_SLOTS`를 4로 고치면 이 줄이
	# 3칸 배열을 만들어 `load_game`이 슬롯 3을 짚고 **부팅 즉시 out of bounds**로 죽는다).
	# 오염은 「비운다」면 충분하다 — 크기의 단일 소스는 `GameState._reset_equipped()`다.
	for i in range(gs.ring_equipped.size()):
		gs.ring_equipped[i] = null
	gs.mana = 1.0
	clock.day = 1
	clock.time_sec = 0.0

	_check("로드: true", sm.load_game())
	_check("복원: 잉크 5", gs.get_count(&"ink_basic") == 5)
	_check("복원: 프로브 아이템 1", gs.get_count(&"__probe_item") == 1)
	_check("복원: 도감 프로브 키", gs.is_unlocked(&"__probe_unlock"))
	# 고리 도안 라운드트립
	_check("복원: 고리 도안 3종 (1겹·2겹·융합)", gs.ring_designs.size() == 3)
	_check("복원: 고리 칸 보존 (2=발산·6=응집)",
		gs.ring_designs.size() == 3 and int(gs.ring_designs[0].rings[0][2]) == 1
		and int(gs.ring_designs[0].rings[0][6]) == 0)
	_check("복원: 고리 열린칸 보존 [2,6]",
		gs.ring_designs.size() == 3 and gs.ring_designs[0].open == [2, 6])
	_check("복원: 고리 채운칸 수 2", gs.ring_designs.size() == 3 and gs.ring_designs[0].filled_count() == 2)
	_check("복원: 고리 점수 0.77 라운드트립",
		gs.ring_designs.size() == 3 and is_equal_approx(gs.ring_designs[0].total_score, 0.77))
	# 세션29 경제 필드 라운드트립 (ResourceSaver가 @export를 total_score와 같은 기전으로 나른다)
	_check("복원: 잉크 ink_mid",
		gs.ring_designs.size() == 3 and StringName(gs.ring_designs[0].ink) == &"ink_mid")
	_check("복원: 특별잉크 ink_fire_red",
		gs.ring_designs.size() == 3 and StringName(gs.ring_designs[0].special_ink) == &"ink_fire_red")
	_check("복원: 특별 비율 0.5",
		gs.ring_designs.size() == 3 and is_equal_approx(gs.ring_designs[0].special_ratio, 0.5))
	_check("복원: 진 크기 1.4",
		gs.ring_designs.size() == 3 and is_equal_approx(gs.ring_designs[0].size, 1.4))
	# 🔴 세79 M1: 다겹 도안 라운드트립 — 층 수·층별 칸·요약이 전부 살아 돌아오나
	var rb: RingDesign = gs.ring_designs[1] if gs.ring_designs.size() == 3 else null
	_check("복원: 🔴 2겹 도안의 층 수 2 (ResourceSaver가 중첩 배열을 나른다)",
		rb != null and rb.rings.size() == 2)
	_check("복원: 🔴 층0=확산(6)×3 · 층1=폭발(7) — 층 순서가 보존된다",
		rb != null and rb.rings.size() == 2
		and int(rb.rings[0][0]) == 6 and int(rb.rings[0][2]) == 6
		and int(rb.rings[1][0]) == 7)
	# 🔴 `filled_count`가 **모든 층**을 센다 — rings[0]만 보면 3이 나온다(바깥 층 누락)
	_check("복원: 🔴 2겹 채운칸 수 4 (층0 3칸 + 층1 1칸 — rings[0]만 세면 3이다)",
		rb != null and rb.filled_count() == 4)
	_check("복원: 2겹 도안 진 id jin_plain_g2",
		rb != null and StringName(rb.jin) == &"jin_plain_g2")
	# 🔴🔴 세81 M2 융합진 라운드트립 (세84 감사 #17) — **디스크를 지나 룬 목록이 살아 돌아오나.**
	# ⚠ `runes`가 유실되면 `runes_of([], rune)`가 `[rune]`을 돌려줘 **에러도 경고도 없이** 단일 룬이
	# 된다(반응이 통째로 사라진다) — 그래서 `size() == 2`를 **직접** 재고, 자리 순서까지 본다.
	var rc: RingDesign = gs.ring_designs[2] if gs.ring_designs.size() == 3 else null
	_check("복원: 🔴 융합 도안의 룬 2개 (ResourceSaver가 runes 배열을 나른다)",
		rc != null and rc.runes.size() == 2)
	_check("복원: 🔴 룬 자리 순서 보존 [물(2), 번개(4)] — 뒤집히면 primary 바탕이 갈린다",
		rc != null and rc.runes.size() == 2
		and int(rc.runes[0]) == 2 and int(rc.runes[1]) == 4)
	_check("복원: 융합 도안의 primary(rune) == 첫 룬 물(2) — 옛 소비자 무회귀",
		rc != null and int(rc.rune) == 2)
	_check("복원: 융합 도안 진 id jin_fuse",
		rc != null and StringName(rc.jin) == &"jin_fuse")
	# 🔴 발사 계약까지 이어지나 — `to_assembly()`가 `runes`를 실어야 반응이 난다(세26 to_assembly 규율).
	_check("복원: 🔴 to_assembly가 룬 목록을 그대로 싣는다 (발사가 두 상태를 건다)",
		rc != null and (rc.to_assembly().get("runes", []) as Array) == [2, 4])
	_check("복원: 고리 장착 슬롯1 매핑",
		gs.ring_equipped[1] == gs.ring_designs[0] and gs.ring_equipped[0] == null)
	_check("복원: 마나 42", is_equal_approx(gs.mana, 42.0))
	_check("복원: Day 3 · 123초", clock.day == 3 and is_equal_approx(clock.time_sec, 123.0))

	# ── 🔴🔴 옛 세이브 호환 (세84 #4) — 장착 참조가 **인덱스 → 파일 경로**로 바뀌었다.
	# 그 변경의 핵심 계약은 「옛 세이브가 그대로 열린다」인데, 새 형식만 재면 **옛 세이브가 조용히
	# 「전 슬롯 빈 채」로 열리는** 회귀를 못 잡는다(사용자 체감 = 맺어 둔 마법진이 사라졌다, 세26).
	# 그래서 방금 쓴 세이브에서 새 키를 **떼어** 세83까지의 형식으로 만들고 다시 읽는다.
	var spath: String = sm.save_root() + "/save.json"
	var rf := FileAccess.open(spath, FileAccess.READ)
	var raw: Variant = JSON.parse_string(rf.get_as_text()) if rf != null else null
	if rf != null:
		rf.close()
	_check("옛 형식 프로브: save.json을 읽었다", typeof(raw) == TYPE_DICTIONARY)
	if typeof(raw) == TYPE_DICTIONARY:
		var raw_d: Dictionary = raw
		_check("옛 형식 프로브: 새 세이브는 ring_equipped_paths(안정 키)를 싣는다",
			raw_d.has("ring_equipped_paths"))
		_check("옛 형식 프로브: 인덱스도 계속 같이 싣는다 (되돌려도 열린다)",
			raw_d.has("ring_equipped"))
		raw_d.erase("ring_equipped_paths")          # ← 세83까지의 세이브 형식
		var wf := FileAccess.open(spath, FileAccess.WRITE)
		if wf != null:
			wf.store_string(JSON.stringify(raw_d, "\t"))
			wf.close()
		gs.ring_designs = [] as Array[RingDesign]
		for i in range(gs.ring_equipped.size()):
			gs.ring_equipped[i] = null
		_check("옛 형식: 로드 true", sm.load_game())
		_check("옛 형식: 도안 3종 그대로", gs.ring_designs.size() == 3)
		_check("🔴 옛 형식(인덱스 장착): 슬롯1 매핑이 그대로 복원된다 — 옛 세이브 호환",
			gs.ring_designs.size() == 3 and gs.ring_equipped[1] == gs.ring_designs[0]
			and gs.ring_equipped[0] == null and gs.ring_equipped[2] == null)
		_check("옛 형식: 융합 룬 목록도 그대로 (형식은 장착 참조만 가른다)",
			gs.ring_designs.size() == 3 and gs.ring_designs[2].runes.size() == 2)

	# ── 🔴 새로하기 (세션37, F8) — 전부 비우고 시작 해금만 재시드 ──
	# save_manager 노트의 계약: new_game은 save_game이 쓰는 것 전부 + bag·hp를 비우고, 시작 해금
	# (세61: rune_fire·jin_single)만 재시드한다. 씬마다 손으로 비우면 필드가 늘 때 조용히 갈라지므로 core에.
	# 🔴 빈 시작(사용자 확정 세션37): 장비도·지은 스테이션(station_*)도·해독으로 얻은 해금도 남지 않는다.
	# "해독 룬이 사라지나"는 **시드에 없는 임의 해금 키**로 잰다 — 시드 목록이 바뀌어도 안 죽는다
	# (세49에 시드가 6룬으로 불어 이 검증이 깨졌던 교훈. 세61에 시드가 2종으로 줄어도 그대로 유효).
	gs.add_item(&"ink_basic", 7)
	gs.equipment[Enums.ItemKind.PEN] = &"pen_basic"     # 장비 입은 상태를 만든다
	gs.codex[&"__decoded_probe"] = true                  # 해독으로 얻은 해금 (시드에 없는 키)
	gs.codex[&"station_refine"] = true                   # 지은 스테이션
	gs.quest_done[&"q01_first_hunt"] = true
	gs.new_game()
	_check("🔴 새로하기: 창고 비었다", gs.inventory.is_empty())
	_check("🔴 새로하기: 장비 벗겨졌다 (맨손 시작)", gs.equipment.is_empty())
	_check("🔴 새로하기: 퀘스트 진행 초기화", gs.quest_done.is_empty() and gs.quest_progress.is_empty())
	# 🔴 세78: 새로하기가 시작 퀵슬롯을 미리 장착한다 (1=불·2=물·3=바람). 빈 시작이 아니라 3볼 시작.
	_check("🔴 새로하기: 시작 고리 도안 3장 (불·물·바람)", gs.ring_designs.size() == 3)
	_check("🔴 새로하기: 슬롯1=불볼", gs.ring_equipped[0] != null and gs.ring_equipped[0].rune == Enums.RuneType.FIRE)
	_check("🔴 새로하기: 슬롯2=물볼", gs.ring_equipped[1] != null and gs.ring_equipped[1].rune == Enums.RuneType.WATER)
	_check("🔴 새로하기: 슬롯3=바람볼", gs.ring_equipped[2] != null and gs.ring_equipped[2].rune == Enums.RuneType.WIND)
	_check("🔴 새로하기: 시작 해금 재시드 (불·물·바람 룬·단발진) — 안 심으면 아무것도 못 그린다",
		gs.is_unlocked(&"rune_fire") and gs.is_unlocked(&"rune_water")
		and gs.is_unlocked(&"rune_wind") and gs.is_unlocked(&"jin_single"))
	# 🔴 세71 맨몸 파이어볼 계약 — 문양 링(gr_*)은 더는 시드가 아니다(스테이지 클리어 보상으로만).
	#   시드를 되돌리면 이 검사가 빨개진다(시작이 맨몸이어야 조립→탁본 보상 루프가 산다).
	_check("🔴 새로하기: 문양 링(gr_radiate5)은 시드가 아니다 — 스테이지 보상으로만 (맨몸 시작)",
		not gs.is_unlocked(&"gr_radiate5"))
	# 🔴🔴 **시드 집합 == 기대 집합** (세84 감사 #19 · 구조적 테마 T7). 전엔 넷(불·물·바람·단발진)만
	# 세서 **세83이 심은 번개·흙·풀 룬과 세79~82의 임시 시드(jin_plain_g2·jin_fuse·gr_*)가 무측정**
	# 이었다 → 임시 시드를 걷는 세션이 관문·보상 배선을 깜빡하면 **새 게임에서 그 콘텐츠가 책에
	# 아예 안 뜨는데 전 스위트 그린**이다(그리고 세83 「반응 6룬 복원」이 조용히 원상복구된다).
	# 🔴 **명시 열거인 이유**: 「시드를 걷는 세션이 이 줄을 같이 줄이도록 강제」한다 —
	#   CLAUDE.md의 *"관문을 붙이는 세션은 해당 시드 줄을 같이 지워야 한다"*를 기계로 만든 장치다.
	#   ⚠ 그러니 이 목록이 빨개지면 **먼저 `_seed_starting_unlocks`가 의도대로인지 보고**,
	#   의도한 변경이면 여기서 같은 줄을 지워라(기대치를 실측에 맞춰 늘리기만 하면 장치가 죽는다).
	var expect_seed: Array = [
		# 룬 6종 — 불·물·바람(세78 시작 지급) + 번개·흙·풀(세83 복원, **임시 시드**)
		"rune_fire", "rune_water", "rune_wind", "rune_bolt", "rune_earth", "rune_grass",
		# 진 — 단발(세71) + 2등급 일반진(세79 M1) + 융합진(세81 M2, 둘 다 **임시 시드**)
		"jin_single", "jin_plain_g2", "jin_fuse",
		# 문양-고리 — M1 실증 2종(세79) + 응축(세82). **전부 임시 시드**(획득 경로 미설계)
		"gr_spread3", "gr_explode1", "gr_condense2",
	]
	var got_seed: Array = []
	for key: StringName in gs.codex:
		if gs.codex[key]:
			got_seed.append(String(key))
	got_seed.sort()
	expect_seed.sort()
	var seed_missing: Array = []
	for key: String in expect_seed:
		if not key in got_seed:
			seed_missing.append(key)
	var seed_extra: Array = []
	for key: String in got_seed:
		if not key in expect_seed:
			seed_extra.append(key)
	_check("🔴🔴 새로하기: 시드 집합 == 기대 집합 %d개 (없는 것 %s · 더 있는 것 %s)"
			% [expect_seed.size(), str(seed_missing), str(seed_extra)],
		got_seed == expect_seed)
	_check("🔴 새로하기: 해독으로 얻은 해금은 사라졌다", not gs.is_unlocked(&"__decoded_probe"))
	_check("🔴 새로하기: 지은 스테이션(정제대)은 사라졌다 — 거점 빈 시작", not gs.is_unlocked(&"station_refine"))

	# ── 🔴🔴 세86 ⑫ **`inventory_changed` = 자동 저장 트리거** (신호를 갈랐다) ──
	# 세84엔 `resources_changed`뿐이라 저장 트리거로 못 걸었다: 그 신호는 `add_to_bag`(가방)도
	# 쏘는데 **가방은 애초에 저장 대상이 아니라**(사망 시 소실이 설계) 드롭 하나마다 세이브 +
	# 도안 .tres 전량을 다시 쓰는 순수 낭비였다. 그래서 창고 증감만 쏘는 신호를 갈라 냈다.
	# 🔴 **이 그물이 없으면 「제작·상점 뒤 창을 닫으면 롤백」이 조용히 되살아난다** — 신규 기능은
	#   그물이 없으면 초록불이 소실을 덮는다(세85 실측: 미커밋 소실 뒤에도 전 스위트가 그린이었다).
	await process_frame          # 앞 절(new_game)의 저장 예약을 먼저 소진 — 안 하면 우리 wipe 뒤에 깨어난다
	sm.wipe_save()
	# ⚠ GDScript 람다는 로컬을 **값으로** 캡처한다 — `var n := 0`을 늘리면 바깥은 0인 채라
	#   신호가 안 와도 그린이 된다(리드가 이 그물을 짜다 실제로 밟았다). 참조 타입으로 센다.
	var inv_signals := [0]
	var inv_probe := func() -> void: inv_signals[0] += 1
	bus.inventory_changed.connect(inv_probe)
	gs.add_to_bag(&"__bag_probe", 1)
	_check("🔴 가방 획득은 inventory_changed를 **안** 쏜다 (원정 중 드롭은 영구부가 아니다)", inv_signals[0] == 0)
	await process_frame          # 저장 예약(_queue_save)은 deferred라 한 프레임 뒤에 쓴다
	_check("🔴🔴 가방 획득만으로는 저장이 돌지 않는다 (드롭마다 전량 재작성 = 세84가 각하한 낭비)",
		not sm.has_save())
	gs.add_item(&"__inv_probe", 1)
	_check("🔴 창고 입고는 inventory_changed를 쏜다", inv_signals[0] == 1)
	await process_frame
	_check("🔴🔴 창고 증감만으로 자동 저장이 실제로 돈다 (제작·상점·보상이 창을 닫아도 안 롤백)",
		sm.has_save())
	gs.remove_item(&"__inv_probe", 1)
	_check("🔴 창고 소모도 쏜다 (제작 비용 지불이 저장돼야 한다)", inv_signals[0] == 2)
	bus.inventory_changed.disconnect(inv_probe)
	gs.bag.clear()

	# ── 🔴 세86 ⑥ **로드는 codex를 clear하고, 시드는 다시 심는다** ──
	# 전엔 `load_game`이 codex만 clear를 안 해(나머지 사전 6개는 한다) 「로드해도 옛 해금이 남는」
	# 조용한 예외였다. 🔴 그런데 **clear만 넣으면 더 나쁜 게 생긴다**: 빌드가 시작 해금을 늘려도
	# 옛 세이브엔 그 키가 없어 **그 세이브에서만 콘텐츠가 조용히 사라진다**(룬 하나가 책에서 없어지는 식).
	# 그래서 clear → `seed_codex_unlocks()` → 세이브 얹기 순서다. 아래가 그 순서의 그물이다.
	await process_frame
	sm.save_game()
	var cpath: String = sm.save_root() + "/save.json"
	var cf := FileAccess.open(cpath, FileAccess.READ)
	var craw: Variant = JSON.parse_string(cf.get_as_text()) if cf != null else null
	if cf != null:
		cf.close()
	if typeof(craw) == TYPE_DICTIONARY:
		var craw_d: Dictionary = craw
		var saved_codex: Array = craw_d.get("codex", [])
		# 「그 시드가 없던 옛 세이브」를 만든다 — 번개 룬 키를 세이브에서 뗀다.
		saved_codex.erase("rune_bolt")
		craw_d["codex"] = saved_codex
		var cwf := FileAccess.open(cpath, FileAccess.WRITE)
		if cwf != null:
			cwf.store_string(JSON.stringify(craw_d, "\t"))
			cwf.close()
		gs.codex[&"__ghost_unlock"] = true      # 로드가 지워야 할 메모리 잔재
		_check("로드 전 프로브: 유령 해금이 메모리에 있다", gs.is_unlocked(&"__ghost_unlock"))
		_check("codex 프로브: 로드 true", sm.load_game())
		_check("🔴 로드가 codex를 clear한다 — 세이브에 없는 옛 해금이 남지 않는다 (사전 6개와 대칭)",
			not gs.is_unlocked(&"__ghost_unlock"))
		_check("🔴🔴 세이브에 없는 **시드** 해금은 로드 뒤에도 살아 있다 (빌드가 주는 것이라 늘 있다)",
			gs.is_unlocked(&"rune_bolt"))
		_check("세이브에 있던 해금도 그대로 복원된다 (시드 재적용이 세이브를 덮지 않는다)",
			gs.is_unlocked(&"rune_fire") and gs.is_unlocked(&"jin_single"))

	# 뒷정리 — 실제 플레이 세이브 오염 방지
	sm.wipe_save()
	_check("뒷정리: 세이브 삭제", not sm.has_save())

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_SAVE_OK — 전 항목 통과")
	else:
		print("TEST_SAVE_FAIL — %d개 실패" % _fail)
	quit(0 if _fail == 0 else 1)
