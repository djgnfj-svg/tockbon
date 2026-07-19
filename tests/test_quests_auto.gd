extends SceneTree
## 진행 목표(퀘스트) 자동 검증 — 세션36 도입 · 세션37 스파인 재배치 · **세션40 턴인(정산) 모델**.
## 실행: Godot --headless --path . -s res://tests/test_quests_auto.gd
## 오토로드는 런타임 get_node로만 접근 (-s 컴파일 시점 미등록 함정).
##
## 🔴 세션40 계약: 목표를 채워도 **자동 완료되지 않는다** — "정산 대기(claimable)"가 된다.
##  길잡이(NPC)에게 말 걸 때 `claim_ready_quests()`가 (1) 완료 처리 (2) 보상 지급 (3) 다음 퀘스트 개방을 한다.
##  advance_quests는 이제 카운트만 올리고 quest_ready만 쏜다. 보상·완료는 정산에서만.
## 🔴 "보고 = 귀환": 길잡이 앞에 섰다는 건 집에 왔다는 뜻 → 정산이 "살아 돌아와라"(EXTRACT)도 함께 채운다.
## 🔴 세션41 온보딩: q00(첫 마법진 그리기)이 사슬 맨 앞에 끼었다. q01·q02는 q00을 물어(requires),
##  q00을 정산해야 **나란히** 열린다(첫 원정 두 목표). q02는 여전히 q01과 동시에 열려 원정 중 active다(세션40 취지 유지).
##  DRAW 목표는 도안 수(ring_designs)로 판정 = 이미 그린 세이브도 소급 충족(UNLOCK/BUILD가 codex로 소급 안전한 것과 같은 결).
## 🔴 **공개 API로만 검증**(advance_quests·claim_ready_quests·is_quest_*·quest_count) — 내부 필드는 계약이 아니다.
##
## 🔴 세션37 스파인: 첫사냥 → (살아 귀환) → 정제대 → 공방 → 해독대 → 물 룬 → 바람 룬.
## 🔴 **건설도 UNLOCK 목표다** — 스테이션은 codex(station_*)로 관리하므로 codex_unlocked(station_*)로 달성된다.

var _pass := 0
var _fail := 0
var _ready_fires := 0   # quest_ready 발신 횟수 (달성 넛지 배선 확인용)

func _init() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS: ", label)
	else:
		_fail += 1
		print("FAIL: ", label)

func _clean(gs: Node) -> void:
	gs.quest_progress.clear()
	gs.quest_done.clear()
	gs.ring_designs.clear()   # q00(DRAW=상태 기반)이 시작부터 미충족이도록 그린 도안을 비운다 (세션41)
	for k: StringName in [&"rune_water", &"rune_wind",
			&"station_refine", &"station_craft", &"station_decode"]:
		gs.codex.erase(k)

func _run() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var db: Node = root.get_node("Db")
	var eb: Node = root.get_node("EventBus")
	var sm: Node = root.get_node("SaveManager")

	# 깨끗한 시작 — 실게임 세이브가 이 프로세스에 로드됐을 수 있어 퀘스트·해금·건설을 초기화한다.
	_clean(gs)
	eb.quest_ready.connect(func(_id: StringName) -> void: _ready_fires += 1)

	var q0: QuestDef = db.get_quest(&"q00_first_draw")
	var q1: QuestDef = db.get_quest(&"q01_first_hunt")
	var q2: QuestDef = db.get_quest(&"q02_come_home")
	var q3: QuestDef = db.get_quest(&"q03_build_refine")
	var q4: QuestDef = db.get_quest(&"q04_build_craft")
	var q5: QuestDef = db.get_quest(&"q05_build_decode")
	var q6: QuestDef = db.get_quest(&"q06_learn_water")
	var q7: QuestDef = db.get_quest(&"q07_learn_wind")
	_check("퀘스트 8장이 data/quests에서 로드됐다",
		q0 != null and q1 != null and q2 != null and q3 != null and q4 != null and q5 != null and q6 != null and q7 != null)
	if q0 == null or q1 == null or q3 == null:
		print("RESULT pass=%d fail=%d" % [_pass, _fail]); quit(); return

	# ── ① 온보딩 시작(세션41): q00(첫 마법진)만 열리고, q01·q02는 q00을 물어 잠긴다 ──
	_check("시작: q00(첫 마법진) 열림", gs.is_quest_active(q0))
	_check("시작: q01(첫 사냥)은 q00 미완료라 잠김", not gs.is_quest_active(q1))
	_check("시작: q02(살아 돌아와라)도 q00 미완료라 잠김", not gs.is_quest_active(q2))

	# 🔴 첫 마법진을 그린다(ring_design_committed) → q00은 상태(ring_designs)로 정산 대기가 된다.
	#   DRAW는 카운트가 아니라 도안 수로 판정하므로, 이미 그린 세이브도 자동 충족돼 사슬이 안 막힌다.
	eb.ring_design_committed.emit(RingDesign.new())
	_check("🔴 그리면 q00 정산 대기(claimable) — 상태(ring_designs)로 판정", gs.is_quest_claimable(q0))
	_check("🔴 그려도 턴인 전엔 완료 아님", not gs.is_quest_done(&"q00_first_draw"))
	gs.claim_ready_quests()
	_check("🔴 정산: q00 완료", gs.is_quest_done(&"q00_first_draw"))
	_check("🔴 q00 완료로 q01·q02가 나란히 열렸다 (첫 원정 두 목표)",
		gs.is_quest_active(q1) and gs.is_quest_active(q2))
	_check("q03(정제대 건설)는 q02 미완료라 아직 잠김", not gs.is_quest_active(q3))

	# ── ② KILL — 5마리째는 "정산 대기"일 뿐. 아직 완료·보상 아님 (턴인 모델) ──
	var core_before: int = gs.get_count(&"mat_slime_core")
	for i in range(4):
		eb.enemy_died.emit(&"slime")
	_check("4마리: q01 진행 4/5, 아직 정산 대기 아님",
		gs.quest_count(&"q01_first_hunt") == 4 and not gs.is_quest_claimable(q1))
	eb.enemy_died.emit(&"slime")   # 5마리째
	_check("🔴 5마리: q01 정산 대기(claimable)", gs.is_quest_claimable(q1))
	_check("🔴 5마리: 아직 완료 아님 (턴인 전)", not gs.is_quest_done(&"q01_first_hunt"))
	_check("🔴 5마리: 보상도 아직 없음 (완료 전)", gs.get_count(&"mat_slime_core") == core_before)
	_check("🔴 달성 순간 quest_ready가 발신됐다 (넛지 배선)", _ready_fires >= 1)
	_check("🔴 아직 귀환 안 함 → q02(살아 돌아와라)는 정산 대기 아님", not gs.is_quest_claimable(q2))
	eb.enemy_died.emit(&"slime")   # 6마리째
	_check("달성 뒤엔 더 세지 않는다 (진행 막대가 need에서 멈춘다)", gs.quest_count(&"q01_first_hunt") == 5)

	# ── ③ 귀환 없이 말 걸기 — q01만 정산된다. 🔴 **원정 없이 q02가 공짜로 완료되지 않는다** ──
	var claimed: Array = gs.claim_ready_quests()
	_check("🔴 정산: q01 완료", gs.is_quest_done(&"q01_first_hunt"))
	_check("🔴 정산 때 보상 지급 (mat_slime_core +3)", gs.get_count(&"mat_slime_core") == core_before + 3)
	_check("🔴 귀환 없이 말만 걸어선 q02 완료 안 된다 (공짜 완료 방지)", not gs.is_quest_done(&"q02_come_home"))
	_check("q02는 정산 반환에도 없다", not (&"q02_come_home" in claimed))

	# ── ④ 실제 귀환(extraction_success) → q02 정산 대기 → 정산 완료 → q03 개방 ──
	var fang_before: int = gs.get_count(&"mat_hound_fang")
	eb.extraction_success.emit()
	_check("🔴 귀환해야 q02 정산 대기 (진짜 귀환이 채운다)", gs.is_quest_claimable(q2))
	gs.claim_ready_quests()
	_check("🔴 정산: q02 완료 + 보상 (mat_hound_fang +2)",
		gs.is_quest_done(&"q02_come_home") and gs.get_count(&"mat_hound_fang") == fang_before + 2)
	_check("🔴 q02 완료로 q03(정제대 건설)가 열렸다", gs.is_quest_active(q3))
	_check("정산 뒤 정산할 게 없다", not gs.has_claimable_quest())

	# ── ④ BUILD — codex_unlocked(station_*)로 달성. 여전히 정산해야 완료 ──
	var shell_before: int = gs.get_count(&"mat_beetle_shell")
	eb.codex_unlocked.emit(&"station_refine")
	_check("🔴 정제대 건설: q03 정산 대기 (아직 완료 아님)",
		gs.is_quest_claimable(q3) and not gs.is_quest_done(&"q03_build_refine"))
	gs.claim_ready_quests()
	_check("🔴 정산: q03 완료 + 보상 (mat_beetle_shell +2)",
		gs.is_quest_done(&"q03_build_refine") and gs.get_count(&"mat_beetle_shell") == shell_before + 2)
	_check("🔴 q04(공방 건설)가 열렸다", gs.is_quest_active(q4))

	# ── ④-b 연쇄 정산 — 공방·해독대를 다 지어놓고 한 번에 정산하면 고정점 루프가 q04→q05를 잇는다 ──
	eb.codex_unlocked.emit(&"station_craft")    # q04 달성
	eb.codex_unlocked.emit(&"station_decode")   # station_decode 해금(단 q05는 q04 미완료라 아직 잠김)
	_check("🔴 선행(q04) 미완료면 지어놔도 q05는 정산 불가",
		gs.is_quest_claimable(q4) and not gs.is_quest_claimable(q5) and not gs.is_quest_active(q5))
	gs.claim_ready_quests()   # q04 정산 → q05 열림 → 이미 지어져 있어 연쇄 정산
	_check("🔴 연쇄 정산: q04·q05 둘 다 완료 (고정점 루프)",
		gs.is_quest_done(&"q04_build_craft") and gs.is_quest_done(&"q05_build_decode"))
	_check("🔴 q06(물의 룬)이 열렸다 — 해독대를 지어야 룬을 배운다", gs.is_quest_active(q6))
	_check("q07(바람)은 아직 잠김", not gs.is_quest_active(q7))

	# ── ⑤ UNLOCK 룬 — q06 달성(rune_water) → 정산 완료 → q07 개방 ──
	eb.codex_unlocked.emit(&"rune_water")
	_check("🔴 물 룬 해금: q06 정산 대기 (아직 완료 아님)",
		gs.is_quest_claimable(q6) and not gs.is_quest_done(&"q06_learn_water"))
	gs.claim_ready_quests()
	_check("🔴 정산: q06 완료 + q07 개방", gs.is_quest_done(&"q06_learn_water") and gs.is_quest_active(q7))
	_check("q07은 rune_water로는 안 끝난다 (target=rune_wind)", not gs.is_quest_done(&"q07_learn_wind"))

	# ── ⑥ 소급 — 이미 해금된 대상을 노리는 퀘스트는 **열리는 순간 정산 대기**. reevaluate는 자동완료 안 함 ──
	gs.quest_done.erase(&"q07_learn_wind")
	gs.codex[&"rune_wind"] = true          # UNLOCK 이벤트 없이 이미 해금된 상태를 만든다
	_check("🔴 소급: 이미 해금된 룬 → q07 열리자마자 정산 대기",
		gs.is_quest_active(q7) and gs.is_quest_claimable(q7) and not gs.is_quest_done(&"q07_learn_wind"))
	gs.reevaluate_quests()
	_check("🔴 reevaluate는 자동완료하지 않는다 (턴인 전엔 미완료)", not gs.is_quest_done(&"q07_learn_wind"))
	gs.claim_ready_quests()
	_check("🔴 정산해야 q07 완료 (사슬은 정산으로 흐른다)", gs.is_quest_done(&"q07_learn_wind"))

	# ── ⑦ requires 게이트 + 저장/로드 라운드트립 ──
	_clean(gs)
	gs.quest_done[&"q00_first_draw"] = true   # 온보딩 q00 완료 선세팅 — 이래야 q01이 열려 진행된다 (세션41)
	eb.enemy_died.emit(&"slime")           # q01 진행 1/5
	eb.codex_unlocked.emit(&"station_refine")   # station_refine 해금, 그러나 q03은 q02 미완료라 잠김
	_check("🔴 선행(q02) 미완료면 건설해도 q03은 정산 불가 (requires 게이트)", not gs.is_quest_claimable(q3))
	gs.quest_done[&"q01_first_hunt"] = true
	sm.save_game()
	gs.quest_progress.clear()
	gs.quest_done.clear()
	sm.load_game()
	_check("🔴 로드: q01 완료 상태 복원", gs.is_quest_done(&"q01_first_hunt"))
	_check("🔴 로드: q01 진행 카운트(1) 복원", gs.quest_count(&"q01_first_hunt") == 1)

	# 뒷정리 — 세이브 파일 삭제(스위트 규약) + 메모리 초기화.
	sm.wipe_save()
	_clean(gs)

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_QUESTS_OK — 전 항목 통과")
	quit()
