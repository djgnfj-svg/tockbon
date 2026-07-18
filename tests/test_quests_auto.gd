extends SceneTree
## 진행 목표(퀘스트) 자동 검증 — 세션36 도입, 세션37에 스파인 재배치(건설 목표 삽입).
## 실행: Godot --headless --path . -s res://tests/test_quests_auto.gd
## 오토로드는 런타임 get_node로만 접근 (-s 컴파일 시점 미등록 함정).
##
## 🔴 계약: 퀘스트는 순수 오버레이다 — EventBus 이벤트(enemy_died·extraction·codex_unlocked)를
## GameState가 관찰해 카운트를 올리고, 목표에 닿으면 (1) 보상을 창고에 넣고 (2) requires로 물린
## 다음 퀘스트를 연다(스파인). 이미 해금/건설된 대상을 노리는 UNLOCK 퀘스트는 열리는 순간 소급 완료.
## 🔴 **공개 API로만 검증**(advance_quests·is_quest_active/_done·quest_count) — 내부 필드는 계약이 아니다.
##
## 🔴 세션37 스파인: 첫사냥 → 귀환 → 정제대 건설 → 공방 건설 → 해독대 건설 → 물 룬 → 바람 룬.
## 🔴 **건설도 UNLOCK 목표다** — 스테이션은 codex(station_*)로 관리하므로 "○○를 지어라"는
## 건설 순간 base.gd가 쏘는 codex_unlocked(station_*)로 자동 완료된다(룬 해금과 같은 경로).

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

func _clean(gs: Node) -> void:
	gs.quest_progress.clear()
	gs.quest_done.clear()
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

	var q1: QuestDef = db.get_quest(&"q01_first_hunt")
	var q2: QuestDef = db.get_quest(&"q02_come_home")
	var q3: QuestDef = db.get_quest(&"q03_build_refine")
	var q4: QuestDef = db.get_quest(&"q04_build_craft")
	var q5: QuestDef = db.get_quest(&"q05_build_decode")
	var q6: QuestDef = db.get_quest(&"q06_learn_water")
	var q7: QuestDef = db.get_quest(&"q07_learn_wind")
	_check("퀘스트 7장이 data/quests에서 로드됐다",
		q1 != null and q2 != null and q3 != null and q4 != null and q5 != null and q6 != null and q7 != null)
	if q1 == null or q3 == null:
		print("RESULT pass=%d fail=%d" % [_pass, _fail]); quit(); return

	# ── ① 시작 상태: q01만 열려 있다 (requires 사슬) ──
	_check("시작: q01(선행 없음) 열림", gs.is_quest_active(q1))
	_check("시작: q02는 q01 미완료라 잠김", not gs.is_quest_active(q2))
	_check("시작: q03(정제대 건설)는 잠김", not gs.is_quest_active(q3))

	# ── ② KILL — EventBus.enemy_died 배선 end-to-end. 5마리째에 완료 + 보상 + q02 개방 ──
	var core_before: int = gs.get_count(&"mat_slime_core")
	for i in range(4):
		eb.enemy_died.emit(&"slime")
	_check("4마리: q01 진행 4/5, 아직 미완료",
		gs.quest_count(&"q01_first_hunt") == 4 and not gs.is_quest_done(&"q01_first_hunt"))
	eb.enemy_died.emit(&"slime")   # 5마리째
	_check("🔴 5마리: q01 완료", gs.is_quest_done(&"q01_first_hunt"))
	_check("🔴 완료 보상이 창고에 들어왔다 (mat_slime_core +3)", gs.get_count(&"mat_slime_core") == core_before + 3)
	_check("🔴 q01 완료로 q02가 열렸다 (스파인)", gs.is_quest_active(q2))
	eb.enemy_died.emit(&"slime")
	_check("완료된 q01은 더 진행하지 않는다", gs.quest_count(&"q01_first_hunt") == 5)

	# ── ③ EXTRACT — q02 완료 → q03(정제대 건설) 개방 ──
	gs.advance_quests(Enums.QuestGoal.EXTRACT, &"")
	_check("🔴 귀환: q02 완료", gs.is_quest_done(&"q02_come_home"))
	_check("🔴 q03(정제대 건설)이 열렸다", gs.is_quest_active(q3))
	_check("q04(공방 건설)는 아직 잠김", not gs.is_quest_active(q4))

	# ── ④ BUILD — codex_unlocked(station_*) 배선. 건설이 UNLOCK 퀘스트를 자동 완료하고 다음을 연다 ──
	# 🔴 base.gd가 건설 성공 시 EventBus.codex_unlocked.emit(station_id)를 쏜다 — 여기선 그 이벤트만 재현.
	var shell_before: int = gs.get_count(&"mat_beetle_shell")
	eb.codex_unlocked.emit(&"station_refine")
	_check("🔴 정제대 건설: q03 완료", gs.is_quest_done(&"q03_build_refine"))
	_check("q03 보상 지급 (mat_beetle_shell +2)", gs.get_count(&"mat_beetle_shell") == shell_before + 2)
	_check("🔴 q04(공방 건설)가 열렸다", gs.is_quest_active(q4))
	_check("q03 건설로 station_refine이 codex에 심겼다", gs.is_unlocked(&"station_refine"))

	eb.codex_unlocked.emit(&"station_craft")
	_check("🔴 공방 건설: q04 완료", gs.is_quest_done(&"q04_build_craft"))
	_check("🔴 q05(해독대 건설)가 열렸다", gs.is_quest_active(q5))

	eb.codex_unlocked.emit(&"station_decode")
	_check("🔴 해독대 건설: q05 완료", gs.is_quest_done(&"q05_build_decode"))
	_check("🔴 q06(물의 룬)이 열렸다 — 해독대를 지어야 룬을 배운다", gs.is_quest_active(q6))
	_check("q07(바람)은 아직 잠김", not gs.is_quest_active(q7))

	# ── ⑤ UNLOCK 룬 — q06 완료 → q07 개방 ──
	eb.codex_unlocked.emit(&"rune_water")
	_check("🔴 물 룬 해금: q06 완료", gs.is_quest_done(&"q06_learn_water"))
	_check("🔴 q07(바람의 룬)가 열렸다", gs.is_quest_active(q7))
	_check("q07은 rune_water로는 안 끝난다 (target=rune_wind)", not gs.is_quest_done(&"q07_learn_wind"))

	# ── ⑥ 소급 완료 — 이미 해금된 대상을 노리는 퀘스트는 열리는 순간 완료된다 ──
	gs.quest_done.erase(&"q07_learn_wind")
	gs.codex[&"rune_wind"] = true          # UNLOCK 이벤트 없이 이미 해금된 상태를 만든다
	_check("소급 전: q07 열려 있고 미완료", gs.is_quest_active(q7) and not gs.is_quest_done(&"q07_learn_wind"))
	gs.reevaluate_quests()
	_check("🔴 이미 해금된 룬 → q07 소급 완료 (사슬이 안 막힌다)", gs.is_quest_done(&"q07_learn_wind"))

	# ── ⑦ 저장/로드 라운드트립 — 진행·완료가 세이브를 건넌다 ──
	_clean(gs)
	eb.enemy_died.emit(&"slime")           # q01 진행 1/5
	gs.advance_quests(Enums.QuestGoal.EXTRACT, &"")   # q02 시도(잠김 — q01 미완료라 무시돼야)
	_check("잠긴 q02는 EXTRACT로도 안 진행 (requires 게이트)", not gs.is_quest_done(&"q02_come_home"))
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
