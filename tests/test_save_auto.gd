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
	gs.ring_designs = [ring_a] as Array[RingDesign]
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
	gs.ring_equipped = [null, null, null, null] as Array[RingDesign]
	gs.mana = 1.0
	clock.day = 1
	clock.time_sec = 0.0

	_check("로드: true", sm.load_game())
	_check("복원: 잉크 5", gs.get_count(&"ink_basic") == 5)
	_check("복원: 프로브 아이템 1", gs.get_count(&"__probe_item") == 1)
	_check("복원: 도감 프로브 키", gs.is_unlocked(&"__probe_unlock"))
	# 고리 도안 라운드트립
	_check("복원: 고리 도안 1종", gs.ring_designs.size() == 1)
	_check("복원: 고리 칸 보존 (2=발산·6=응집)",
		gs.ring_designs.size() == 1 and int(gs.ring_designs[0].rings[0][2]) == 1
		and int(gs.ring_designs[0].rings[0][6]) == 0)
	_check("복원: 고리 열린칸 보존 [2,6]",
		gs.ring_designs.size() == 1 and gs.ring_designs[0].open == [2, 6])
	_check("복원: 고리 채운칸 수 2", gs.ring_designs.size() == 1 and gs.ring_designs[0].filled_count() == 2)
	_check("복원: 고리 점수 0.77 라운드트립",
		gs.ring_designs.size() == 1 and is_equal_approx(gs.ring_designs[0].total_score, 0.77))
	# 세션29 경제 필드 라운드트립 (ResourceSaver가 @export를 total_score와 같은 기전으로 나른다)
	_check("복원: 잉크 ink_mid",
		gs.ring_designs.size() == 1 and StringName(gs.ring_designs[0].ink) == &"ink_mid")
	_check("복원: 특별잉크 ink_fire_red",
		gs.ring_designs.size() == 1 and StringName(gs.ring_designs[0].special_ink) == &"ink_fire_red")
	_check("복원: 특별 비율 0.5",
		gs.ring_designs.size() == 1 and is_equal_approx(gs.ring_designs[0].special_ratio, 0.5))
	_check("복원: 진 크기 1.4",
		gs.ring_designs.size() == 1 and is_equal_approx(gs.ring_designs[0].size, 1.4))
	_check("복원: 고리 장착 슬롯1 매핑",
		gs.ring_equipped[1] == gs.ring_designs[0] and gs.ring_equipped[0] == null)
	_check("복원: 마나 42", is_equal_approx(gs.mana, 42.0))
	_check("복원: Day 3 · 123초", clock.day == 3 and is_equal_approx(clock.time_sec, 123.0))

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
	_check("🔴 새로하기: 고리 도안 비었다", gs.ring_designs.is_empty())
	_check("🔴 새로하기: 시작 해금 재시드 (불 룬·단발진, 세61) — 안 심으면 아무것도 못 그린다",
		gs.is_unlocked(&"rune_fire") and gs.is_unlocked(&"jin_single"))
	_check("🔴 새로하기: 해독으로 얻은 해금은 사라졌다", not gs.is_unlocked(&"__decoded_probe"))
	_check("🔴 새로하기: 지은 스테이션(정제대)은 사라졌다 — 거점 빈 시작", not gs.is_unlocked(&"station_refine"))

	# 뒷정리 — 실제 플레이 세이브 오염 방지
	sm.wipe_save()
	_check("뒷정리: 세이브 삭제", not sm.has_save())

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
