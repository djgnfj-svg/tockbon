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
	# 🔴 워치독 + 완료 마커 — 마커가 없으면 테스트가 조용히 안 돌아도 「스위트 그린」으로 읽히고,
	#  워치독이 없으면 _run이 await에서 죽을 때 프로세스가 영구 hang한다.
	create_timer(60.0).timeout.connect(func() -> void:
		print("TEST_SAVE_TIMEOUT — 60초 초과")
		quit(1))
	await process_frame
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("Clock")
	var sm: Node = root.get_node("SaveManager")
	var bus: Node = root.get_node("EventBus")

	# 🔴 [0] 테스트 격리 — -s 부팅은 세이브 뿌리가 save_test로 갈라져야 한다. 안 갈리면 스위트의
	#  자동 저장·wipe_save()가 실제 플레이 세이브를 때린다(격리가 지워져도 전 스위트는 그린이다).
	_check("🔴 -s 부팅 = 세이브 격리 (root=%s)" % sm.save_root(),
		String(sm.save_root()).contains("save_test"))

	# 클린 시작 (격리 확인 뒤 — 여기서부터의 wipe는 테스트 세이브만 지운다)
	sm.wipe_save()
	_check("초기: 세이브 없음", not sm.has_save())

	# 🔴 부팅만으로 자동 저장이 준비된다. 아무도 load_game()을 안 부르면 _ready_to_save가 영원히
	#  false → save_game()이 전부 조용히 return → 껐다 켜면 그린 마법진이 사라진다(에러도 경고도 없다).
	# 🔴 이 확인은 load_game()을 부르기 전에 있어야 한다 — 아래 「로드: true」가 먼저 오면 테스트가
	#  직접 켜 준 셈이라 이후 저장 검증이 전부 거짓 초록이 된다. 순서가 곧 검출력이다.
	bus.extraction_success.emit()
	_check("🔴 부팅만으로 귀환 자동 저장이 실제로 돈다 (SaveManager._ready → load_game)",
		sm.has_save())
	sm.wipe_save()

	_check("초기: 로드 false (새 게임)", not sm.load_game())

	# 시드 — ⚠ 아래 두 키는 Db 무관 순수 라운드트립 프로브다 (저장/로드는 id를 해석하지 않는다).
	gs.add_item(&"ink_basic", 5)
	gs.add_item(&"__probe_item", 1)
	gs.codex[&"__probe_unlock"] = true
	# 고리 도안 라운드트립. 칸 2=발산(1)·칸 6=응집(0), 열린 칸 [2,6].
	# 잉크·특별잉크·크기(경제)도 저장에 실린다 — 저장한 진을 다시 쏴도 그때 그 위력·효과가 난다.
	var ring_a: RingDesign = RingDesign.from_assembly(
		{"rune": 0, "rings": [[-1, -1, 1, -1, -1, -1, 0, -1]], "open": [2, 6],
		"ink": &"ink_mid", "special_ink": &"ink_fire_red", "special_ratio": 0.5, "size": 1.4},
		"테스트 진", 0.77)
	# 🔴 2겹(층 배열) 도안도 같이 저장한다 — rings가 배열의 배열이 되면서 ResourceSaver가 중첩 배열을
	#  제대로 나르는지가 저장 무회귀의 유일한 실측이다. 층0=확산×3 · 층1=폭발×1.
	var ring_b: RingDesign = RingDesign.from_assembly(
		{"rune": 0, "jin": &"jin_plain_g2",
		"rings": [[6, 6, 6, -1, -1, -1, -1, -1], [7, -1, -1, -1, -1, -1, -1, -1]],
		"open": [0, 1, 2]},
		"2겹 테스트 진", 0.81)
	# 🔴 룬 2개(융합진) 도안도 같이 저장한다 — test_jin_fusion_auto의 라운드트립은 in-memory라
	#  디스크를 안 지난다. 유실되면 runes_of([], rune)가 [rune]로 폴백해 에러 없이 단일 룬으로 퇴화한다
	#  (반응 소멸·피해 감소 — 「쏘는 게 조용히 약해진다」).
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
	# 🔴 크기를 리터럴로 쓰지 않는다 — EQUIP_SLOTS를 4로 고치면 이 줄이 3칸 배열을 만들어
	#  load_game이 슬롯 3을 짚고 부팅 즉시 out of bounds로 죽는다. 크기의 단일 소스는 GameState._reset_equipped()다.
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
	# 경제 필드 라운드트립 (ResourceSaver가 @export를 total_score와 같은 기전으로 나른다)
	_check("복원: 잉크 ink_mid",
		gs.ring_designs.size() == 3 and StringName(gs.ring_designs[0].ink) == &"ink_mid")
	_check("복원: 특별잉크 ink_fire_red",
		gs.ring_designs.size() == 3 and StringName(gs.ring_designs[0].special_ink) == &"ink_fire_red")
	_check("복원: 특별 비율 0.5",
		gs.ring_designs.size() == 3 and is_equal_approx(gs.ring_designs[0].special_ratio, 0.5))
	_check("복원: 진 크기 1.4",
		gs.ring_designs.size() == 3 and is_equal_approx(gs.ring_designs[0].size, 1.4))
	# 🔴 다겹 도안 라운드트립 — 층 수·층별 칸·요약이 전부 살아 돌아오나
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
	# 🔴 융합진 라운드트립 — 디스크를 지나 룬 목록이 살아 돌아오나.
	# ⚠ runes가 유실되면 runes_of([], rune)가 [rune]을 돌려줘 에러도 경고도 없이 단일 룬이 된다
	#  (반응이 통째로 사라진다) — 그래서 size() == 2를 직접 재고, 자리 순서까지 본다.
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
	# 🔴 발사 계약까지 이어지나 — to_assembly()가 runes를 실어야 반응이 난다.
	_check("복원: 🔴 to_assembly가 룬 목록을 그대로 싣는다 (발사가 두 상태를 건다)",
		rc != null and (rc.to_assembly().get("runes", []) as Array) == [2, 4])
	_check("복원: 고리 장착 슬롯1 매핑",
		gs.ring_equipped[1] == gs.ring_designs[0] and gs.ring_equipped[0] == null)
	_check("복원: 마나 42", is_equal_approx(gs.mana, 42.0))
	_check("복원: Day 3 · 123초", clock.day == 3 and is_equal_approx(clock.time_sec, 123.0))

	# ── 🔴 옛 세이브 호환 — 장착 참조가 인덱스 → 파일 경로로 바뀌었다. 새 형식만 재면 옛 세이브가
	#  조용히 「전 슬롯 빈 채」로 열리는 회귀를 못 잡는다(체감 = 맺어 둔 마법진이 사라졌다).
	#  그래서 방금 쓴 세이브에서 새 키를 떼어 옛 형식으로 만들고 다시 읽는다.
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

	# ── 🔴 새로하기 — 전부 비우고 시작 해금만 재시드 ──
	# 🔴 빈 시작: 장비도·지은 스테이션(station_*)도·해독으로 얻은 해금도 남지 않는다.
	# "해독 룬이 사라지나"는 시드에 없는 임의 해금 키로 잰다 — 시드 목록이 바뀌어도 안 죽는다.
	gs.add_item(&"ink_basic", 7)
	gs.equipment[Enums.ItemKind.PEN] = &"pen_basic"     # 장비 입은 상태를 만든다
	gs.codex[&"__decoded_probe"] = true                  # 해독으로 얻은 해금 (시드에 없는 키)
	gs.codex[&"station_refine"] = true                   # 지은 스테이션
	gs.quest_done[&"q01_first_hunt"] = true
	gs.new_game()
	_check("🔴 새로하기: 창고 비었다", gs.inventory.is_empty())
	_check("🔴 새로하기: 장비 벗겨졌다 (맨손 시작)", gs.equipment.is_empty())
	_check("🔴 새로하기: 퀘스트 진행 초기화", gs.quest_done.is_empty() and gs.quest_progress.is_empty())
	# 🔴 시작 도안은 한 장이다(슬롯 1 = 불볼). codex 시드만 걷으면 「책에서 못 고른다」일 뿐이고
	#  1·2·3 키로는 그대로 나간다(발사는 to_assembly()가 도안을 읽고 codex를 안 본다) → 챕터 보상이
	#  첫 판부터 쏘던 것이 되어 보상 지도가 통째로 무너진다.
	# 🔴 슬롯 2·3이 비었다는 것 자체가 재발 감지기다 — 도안 시드가 돌아오면 여기가 빨개진다.
	_check("🔴 새로하기: 시작 고리 도안 1장 (불뿐)", gs.ring_designs.size() == 1)
	_check("🔴 새로하기: 슬롯1=불볼", gs.ring_equipped[0] != null and gs.ring_equipped[0].rune == Enums.RuneType.FIRE)
	_check("🔴🔴 새로하기: 슬롯2가 비어 있다 (물 룬은 ch1 클리어 보상이다)", gs.ring_equipped[1] == null)
	_check("🔴🔴 새로하기: 슬롯3이 비어 있다 (바람 룬은 ch2 클리어 보상이다)", gs.ring_equipped[2] == null)
	_check("🔴 새로하기: 시작 해금 재시드 (불 룬·단발진·발산 고리) — 안 심으면 아무것도 못 그린다",
		gs.is_unlocked(&"rune_fire") and gs.is_unlocked(&"jin_single") and gs.is_unlocked(&"gr_radiate5"))
	# 🔴 보상·제작으로 얻는 키가 시작엔 없다. 하나라도 시드로 남으면 그 획득 경로가 소급 완료로 덮여
	#  조용히 죽는다(관문을 붙였는데 아무 일도 안 나는 형태로 실제 겪었다).
	_check("🔴🔴 새로하기: 챕터 보상 룬(물·바람·풀)이 시작엔 없다",
		not gs.is_unlocked(&"rune_water") and not gs.is_unlocked(&"rune_wind")
		and not gs.is_unlocked(&"rune_grass"))
	_check("🔴🔴 새로하기: 제작·드롭 대상(번개·흙 룬·진 2종·고리 3종)이 시작엔 없다",
		not gs.is_unlocked(&"rune_bolt") and not gs.is_unlocked(&"rune_earth")
		and not gs.is_unlocked(&"jin_plain_g2") and not gs.is_unlocked(&"jin_fuse")
		and not gs.is_unlocked(&"gr_spread3") and not gs.is_unlocked(&"gr_explode1")
		and not gs.is_unlocked(&"gr_condense2"))
	# 🔴 시드 집합 == 기대 집합. 명시 열거인 이유: 「시드를 걷는 사람이 이 줄을 같이 줄이도록」 강제한다.
	# ⚠ 이 목록이 빨개지면 먼저 _seed_starting_unlocks가 의도대로인지 보고, 의도한 변경이면 여기서
	#  같은 줄을 지워라(기대치를 실측에 맞춰 늘리기만 하면 장치가 죽는다).
	# ⚠ 개수 검사로 바꾸지 마라 — 개수는 같고 내용이 갈려도 통과해 장치가 죽는다.
	var expect_seed: Array = [
		"rune_fire",     # 시작 룬 = 불 하나
		"jin_single",    # 시작 진 = 단발진
		"gr_radiate5",   # 시작 고리 = 발산×5 (세88에 ch1 보상 → 시작 지급으로 이관)
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

	# ── 🔴 inventory_changed = 자동 저장 트리거 (신호를 갈랐다) ──
	# 가방은 애초에 저장 대상이 아니라(사망 시 소실이 설계) 드롭 하나마다 세이브 + 도안 .tres 전량을
	#  다시 쓰는 건 순수 낭비였다 — 그래서 창고 증감만 쏘는 신호를 갈라 냈다.
	# 🔴 이 그물이 없으면 「제작·상점 뒤 창을 닫으면 롤백」이 조용히 되살아난다(초록불이 소실을 덮는다).
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

	# ── 🔴 로드는 codex를 clear하고, 시드는 다시 심는다 ──
	# clear만 넣으면 더 나쁜 게 생긴다: 빌드가 시작 해금을 늘려도 옛 세이브엔 그 키가 없어 그 세이브
	#  에서만 콘텐츠가 조용히 사라진다. 그래서 clear → seed_codex_unlocks() → 세이브 얹기 순서다.
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
		saved_codex.erase("gr_radiate5")   # 🔴 살아 있는 시드 키여야 한다 (세88: rune_bolt는 제작 대상이 됐다)
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
			gs.is_unlocked(&"gr_radiate5"))
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
