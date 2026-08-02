extends SceneTree
## 진행 목표(퀘스트) 자동 검증 — 헤드리스 실행:
##   Godot --headless --path . -s res://tests/test_quests_auto.gd
## 오토로드는 런타임 get_node로만 접근 (-s 컴파일 시점 미등록 함정).
## 🔴 계약: 목표를 채워도 자동 완료가 아니다 — 「정산 대기(claimable)」가 되고
##  `claim_ready_quests()`가 완료·보상·다음 개방을 한다. 「보고 = 귀환」이라 정산이 EXTRACT도 채운다.
## 🔴 **공개 API로만** 검증한다(advance_quests·claim_ready_quests·is_quest_*·quest_count) — 내부 필드는 계약이 아니다.

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

## 🔴 대역을 주입할 땐 **원본을 보관한다** — 「빈 자리라 빌려 쓴다」는 전제는 콘텐츠가 복원되는
## 순간 거짓이 되고, 그때 뒷정리의 `erase`가 **진짜 .tres를 지운다**(실데이터 그물이 조용히 사라진다).
## `{id: QuestDef|null}` — null = 원래 없었다(그때만 erase한다).
var _quest_backup := {}

func _backup_quest(db: Node, id: StringName) -> void:
	if not _quest_backup.has(id):
		_quest_backup[id] = db.quests.get(id, null)

func _inject_quest(db: Node, id: StringName, target: StringName, requires: StringName) -> QuestDef:
	_backup_quest(db, id)
	var q := QuestDef.new()
	q.id = id
	q.goal = Enums.QuestGoal.UNLOCK
	q.target = target
	q.requires = requires
	db.quests[id] = q
	return q

## 있으면 되돌리고, 없을 때만 지운다 (test_rune_unlock_auto의 흙 룬 원복 패턴과 같은 규약).
func _restore_quests(db: Node) -> void:
	for id: StringName in _quest_backup:
		var orig = _quest_backup[id]
		if orig != null:
			db.quests[id] = orig
		else:
			db.quests.erase(id)
	_quest_backup.clear()

func _clean(gs: Node) -> void:
	gs.quest_progress.clear()
	gs.quest_done.clear()
	gs.quest_seen.clear()     # 🔴 [!] 접수 초기화 (세션43) — 미접수 상태로 되돌린다
	gs.ring_designs.clear()   # q00(DRAW=상태 기반)이 시작부터 미충족이도록 그린 도안을 비운다 (세션41)
	# 🔴 여기서 지운다 — 실게임 세이브가 같은 프로세스에 로드됐을 수 있고, 남아 있으면
	#   「정산이 건물을 되돌린다」 그물이 **이미 해금** 가드에 걸려 자명 통과가 된다.
	for k: StringName in [&"rune_water", &"rune_wind",
			&"station_refine", &"station_craft"]:
		gs.codex.erase(k)

func _run() -> void:
	# 🔴 워치독 — `_run`이 중간에 죽으면(런타임 에러로 함수 중단) `quit()`에 못 닿아 프로세스가 **영구 hang**한다.
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_QUESTS_TIMEOUT — 30초 초과 (테스트가 중간에 죽었을 수 있다)")
		quit(1))
	await process_frame
	var gs: Node = root.get_node("GameState")
	var db: Node = root.get_node("Db")
	var eb: Node = root.get_node("EventBus")
	var sm: Node = root.get_node("SaveManager")

	# 🔴 주입 전 **Db 퀘스트 목록을 스냅샷**한다 — 공유 레지스트리에 대역을 심으므로 끝나고
	#   원래 목록으로 돌아왔는지가 계약이다. 안 돌아오면 뒤쪽 실데이터 검증이 조용히 갈린다.
	var quests_at_start: Array = db.quests.keys()
	quests_at_start.sort()

	# 깨끗한 시작 — 실게임 세이브가 이 프로세스에 로드됐을 수 있어 퀘스트·해금·건설을 초기화한다.
	_clean(gs)
	eb.quest_ready.connect(func(_id: StringName) -> void: _ready_fires += 1)

	# 🔴 룬 퀘스트 .tres가 은퇴했다 — UNLOCK·소급 사슬 **기계**는 그대로라 q06/q07을 in-memory
	#   QuestDef로 주입해 계속 잰다(Db.quests는 평범한 Dictionary다). 끝나면 원본으로 되돌린다.
	# 🔴 이 재배선(q04→q06)이 아래 ④-b 「연쇄 정산(고정점 루프)」 그물을 살려 둔다.
	var q6: QuestDef = _inject_quest(db, &"q06_learn_water", &"rune_water", &"q04_build_craft")
	var q7: QuestDef = _inject_quest(db, &"q07_learn_wind", &"rune_wind", &"q06_learn_water")

	var q0: QuestDef = db.get_quest(&"q00_first_draw")
	var q1: QuestDef = db.get_quest(&"q01_first_hunt")
	var q2: QuestDef = db.get_quest(&"q02_come_home")
	var q3: QuestDef = db.get_quest(&"q03_build_refine")
	var q4: QuestDef = db.get_quest(&"q04_build_craft")
	# 🔴 **5장**이다 — 위 주입 2장은 기계 검증용이라 이 수에 안 든다.
	_check("퀘스트 5장이 data/quests에서 로드됐다 (q00~q04 · 세85에 q05 해독대 은퇴)",
		q0 != null and q1 != null and q2 != null and q3 != null and q4 != null)
	_check("🔴 q05(해독대 건설)는 은퇴해 Db에 없다 — 「없는 건물을 세우라」는 유령 목표 0",
		db.get_quest(&"q05_build_decode") == null)
	if q0 == null or q1 == null or q3 == null or q4 == null:
		# 여기까지 왔으면 위 _check가 이미 빨개졌다 — 종료코드도 실패로.
		print("RESULT pass=%d fail=%d" % [_pass, _fail])
		_restore_quests(db)
		quit(1)
		return

	# ── ⓐ 마을 되살리기 데이터 계약 — 「퀘스트를 깨면 건물이 저절로 선다」 ──
	#  ① 되돌리는 통로가 `reward_unlock`에 실려 있다(없으면 건물이 영영 잔해다 — 에러 0).
	#  ② 🔴 **목표가 자기 자신의 해금이 아니다** — `UNLOCK station_*`을 인터림 브리지가 채워 주면
	#     **자기 완료 조건을 스스로 심는 순환**이 된다. 그 형태로 되돌아오면 여기가 빨개진다.
	# 🔴 지금은 되돌릴 건물이 없어 `reward_unlock`이 비어 있다 — 그 codex를 쏴도 받는 노드가
	#   0곳이라(`base.gd`의 `STATION_UNLOCKS == {}`) 그대로 두면 **조용히 죽은 보상**이 된다.
	#   ⚠ 아래 ⓑ의 **양방향 검사**가 「열쇠와 문」이 다시 갈라지는 순간을 잡는다.
	_check("🔴 세90: q03·q04가 station_* 해금을 안 준다 (되돌릴 건물이 마을에 없다)",
		q3.reward_unlock == &"" and q4.reward_unlock == &"")
	# 🔴 보상이 **통째로 사라지지는 않았다** — 재료는 남는다. 이걸 안 재면 「보상 없는 퀘스트」로
	#   조용히 퇴화한 것을 못 잡는다.
	_check("🔴 q03·q04의 재료 보상은 살아 있다 (q03 %d종 · q04 %d종)"
			% [q3.reward_items.size(), q4.reward_items.size()],
		not q3.reward_items.is_empty() and not q4.reward_items.is_empty())
	_check("🔴 q04가 q05에서 이관받은 mat_night_bloom ×2를 그대로 든다 (세85 총량 보존)",
		int(q4.reward_items.get(&"mat_night_bloom", 0)) == 2)
	_check("🔴🔴 건설 UNLOCK 순환 재발 감지 — q03·q04의 **목표**가 station_* 해금이 아니다",
		q3.goal != Enums.QuestGoal.UNLOCK and q4.goal != Enums.QuestGoal.UNLOCK)

	# ── ⓑ 🔴 **잠근 건물엔 여는 열쇠가 있어야 하고, 열쇠엔 열 문이 있어야 한다** ──
	#  `base.gd`의 `STATION_UNLOCKS`에 올린 건물은 codex 해금 전까지 [E]가 안 먹는다(잔해).
	#  그 id를 **아무도 안 쏘면 그 건물은 영영 잠긴다** — 기존 세이브엔 옛 값이 남아 F5로는
	#  안 드러난다(새 게임에서만 죽는다).
	#  🔴 표를 **직접 읽는다**(id를 베끼지 않는다) — 베끼면 표가 늘 때 그물만 옛 목록에 남는다.
	#  🔴 **양방향이라야 어느 쪽을 혼자 되살려도 빨개진다**:
	#    ⓐ 표에만 올리고 퀘스트를 안 주면 → **영영 잔해** · ⓑ 퀘스트만 주고 표에 안 올리면 → **죽은 보상**.
	#  ⚠ 한 방향만 두면 표가 비는 순간 루프가 0회라 검출력이 통째로 0이 된다.
	var base_script = load("res://src/base/base.gd")
	var gated: Dictionary = base_script.STATION_UNLOCKS
	var granters: Dictionary = {}
	for gq: QuestDef in db.all_quests():
		if gq.reward_unlock != &"":
			granters[gq.reward_unlock] = String(gq.id)
	print("     게이트 표 %d줄 %s" % [gated.size(), gated])
	# ⓐ 문 → 열쇠 (표가 비면 0회, 채우면 자동 가동)
	for node_name in gated:
		_check("🔴 잠근 건물 %s(%s)를 열어 주는 퀘스트가 있다 — 없으면 영영 잔해다"
				% [node_name, gated[node_name]],
			granters.has(gated[node_name]))
	# ⓑ 🔴 열쇠 → 문 (표가 비어도 **산다**)
	for unlock: StringName in granters:
		if not String(unlock).begins_with("station_"):
			continue   # 룬·진·고리 해금은 건물과 무관하다
		_check("🔴 %s를 주는 퀘스트(%s)가 있으면 그 건물이 게이트 표에 있다 — 없으면 죽은 보상이다"
				% [unlock, granters[unlock]],
			gated.values().has(unlock))

	# ── ① 온보딩 시작: q00(첫 마법진)만 열리고, q01·q02는 q00을 물어 잠긴다 ──
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

	# ── ② KILL — 처치(=count 충족)는 "정산 대기"일 뿐. 아직 완료·보상 아님 (턴인 모델) ──
	# q01 count는 1이다(보스 1처치). 잡기 전엔 대기가 아님도 함께 잰다.
	var core_before: int = gs.get_count(&"mat_slime_core")
	_check("처치 전: q01 진행 0, 정산 대기 아님",
		gs.quest_count(&"q01_first_hunt") == 0 and not gs.is_quest_claimable(q1))
	eb.enemy_died.emit(&"hound")   # 1마리 = count(1) 충족
	_check("🔴 처치: q01 정산 대기(claimable)", gs.is_quest_claimable(q1))
	_check("🔴 처치: 아직 완료 아님 (턴인 전)", not gs.is_quest_done(&"q01_first_hunt"))
	_check("🔴 처치: 보상도 아직 없음 (완료 전)", gs.get_count(&"mat_slime_core") == core_before)
	_check("🔴 달성 순간 quest_ready가 발신됐다 (넛지 배선)", _ready_fires >= 1)
	_check("🔴 아직 귀환 안 함 → q02(살아 돌아와라)는 정산 대기 아님", not gs.is_quest_claimable(q2))
	eb.enemy_died.emit(&"hound")   # 한 마리 더
	_check("달성 뒤엔 더 세지 않는다 (진행 막대가 need에서 멈춘다)", gs.quest_count(&"q01_first_hunt") == 1)

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

	# ── ④ 마을 되살리기 — q03은 **사냥**이고, 정산이 건물을 되돌린다(codex는 입력이 아니라 출력) ──
	#  🔴 발신 **횟수**를 센다 — 값만 보면 「같은 길로 왔나」를 못 잰다.
	# 🔴 `reward_unlock` → `codex_unlocked` 기계를 in-memory 주입으로 잰다: 지금 그 필드를 채운
	#  퀘스트가 0곳이라 「안 쏜다」로 뒤집으면 **그 기계를 아무도 안 재게 된다**.
	#  ⚠ **원본을 보관했다 되돌린다** · `.tres`는 안 건드린다(캐시된 Resource의 필드만 잠시 바꾼다).
	var q3_unlock_orig: StringName = q3.reward_unlock
	q3.reward_unlock = &"station_refine"
	var shell_before: int = gs.get_count(&"mat_beetle_shell")
	var refine_emits := [0]
	var on_refine := func(id: StringName) -> void:
		if id == &"station_refine": refine_emits[0] += 1
	eb.codex_unlocked.connect(on_refine)
	for i in q3.need() - 1:
		eb.enemy_died.emit(&"hound")
	_check("🔴 목표 수(%d)에 한 마리 모자라면 아직 정산 대기 아님 (검출력 대조)" % q3.need(),
		not gs.is_quest_claimable(q3))
	eb.enemy_died.emit(&"hound")
	_check("🔴 짐승 %d마리: q03 정산 대기 (아직 완료 아님)" % q3.need(),
		gs.is_quest_claimable(q3) and not gs.is_quest_done(&"q03_build_refine"))
	_check("🔴 정산 전엔 실습동이 아직 잔해다 (station_refine 미해금 · 발신 0회)",
		not gs.is_unlocked(&"station_refine") and refine_emits[0] == 0)
	gs.claim_ready_quests()
	_check("🔴 정산: q03 완료 + 보상 (mat_beetle_shell +2)",
		gs.is_quest_done(&"q03_build_refine") and gs.get_count(&"mat_beetle_shell") == shell_before + 2)
	_check("🔴🔴 정산이 reward_unlock을 codex_unlocked로 **정확히 1발** 쏜다 (기계 그물 — 주입)",
		refine_emits[0] == 1 and gs.is_unlocked(&"station_refine"))
	eb.codex_unlocked.disconnect(on_refine)
	# 🔴 주입 뒷정리 — 원본 복원 + 심어진 codex 회수. 안 되돌리면 뒤 항목이 「이미 해금」 가드에 걸려
	#   자명 통과가 되고, 다음 실행의 세이브에도 유령 해금이 남는다.
	q3.reward_unlock = q3_unlock_orig
	gs.codex.erase(&"station_refine")
	_check("🔴 q04(공방)가 열렸다", gs.is_quest_active(q4))

	# ── ④-b 🔴🔴 **연쇄 정산(고정점 루프)** — 한 번의 정산이 사슬을 **두 칸** 진행시킨다 ──
	# 공방을 짓고 **물 룬도 이미 해금해 둔** 채 길잡이에게 한 번 말을 걸면:
	#   q04 정산 → 그 순간 q06이 열림 → q06의 대상이 **이미** 충족돼 있어 같은 정산에서 이어서 완료.
	# 🔴 `claim_ready_quests`가 「완료 → 개방 → 다시 훑기」를 **고정점까지 반복**하지 않으면
	#   q06이 열린 채 미정산으로 남는다(플레이어는 말을 두 번 걸어야 한다). 그걸 재는 **유일한 자리**다.
	# 🔴 뮤테이션: 고정점 루프를 1회로 되돌리면 아래 「연쇄 정산」 단정이 빨개진다.
	var sap_before: int = gs.get_count(&"mat_moon_sap")
	var bloom_before: int = gs.get_count(&"mat_night_bloom")
	# 🔴 q04는 **귀환(EXTRACT)** 목표다 — 필요 횟수만큼 살아 돌아온다.
	#   (q02는 이미 완료라 다시 안 세진다 — `advance_quests`가 active만 센다.)
	for i in q4.need():
		eb.extraction_success.emit()
	eb.codex_unlocked.emit(&"rune_water")      # q06 대상 선해금 — 단 q06은 q04 미완료라 아직 잠김
	_check("🔴 선행(q04) 미완료면 대상이 이미 해금돼 있어도 q06은 정산 불가 (requires 게이트)",
		gs.is_quest_claimable(q4) and not gs.is_quest_claimable(q6) and not gs.is_quest_active(q6))
	_check("정산 전엔 station_craft가 미해금이다 (대조 기준선)", not gs.is_unlocked(&"station_craft"))
	gs.claim_ready_quests()   # q04 정산 → q06 열림 → 이미 해금돼 있어 연쇄 정산
	# 🔴 은퇴한 q05의 보상 `mat_night_bloom ×2`가 q04로 합쳐졌다(총 보상량 보존). 그물이 없으면
	#   「사슬을 줄이면서 보상이 조용히 사라졌다」를 아무도 못 잡는다 — 퀘스트 은퇴는 반복될 축이다.
	_check("🔴 q04 정산 보상: 원래 것 + q05에서 넘어온 몫 (mat_moon_sap +1 · mat_night_bloom +2)",
		gs.get_count(&"mat_moon_sap") == sap_before + 1
		and gs.get_count(&"mat_night_bloom") == bloom_before + 2)
	_check("🔴🔴 연쇄 정산: q04·q06 둘 다 완료 (고정점 루프 — 말 한 번에 두 칸)",
		gs.is_quest_done(&"q04_build_craft") and gs.is_quest_done(&"q06_learn_water"))
	# 🔴 q04는 건물을 되돌리지 않는다 — 기계 자체는 위 q03이 주입으로 쟀고, 여기서 재는 건
	#   **실데이터의 현재 계약**이다: `reward_unlock`을 비운 퀘스트가 codex를 쏘면 「죽은 보상」이 되살아난 것이다.
	_check("🔴 세90: q04 정산이 station_craft를 열지 않는다 (마을에 공방이 없다 — 죽은 보상 방지)",
		not gs.is_unlocked(&"station_craft"))
	_check("🔴 연쇄로 q07(바람)이 열렸다", gs.is_quest_active(q7))
	_check("q07은 rune_water로는 안 끝난다 (target=rune_wind)", not gs.is_quest_done(&"q07_learn_wind"))

	# ── ⑤ UNLOCK 룬 **정상 경로** — 목표가 열려 있는 동안 해금 이벤트가 온다 (⑥ 소급과 대비) ──
	# 🔴 여기는 advance_quests 경로(이벤트가 열린 목표를 채운다)이고 아래 ⑥은 reevaluate 경로다
	#   (목표가 열릴 때 이미 채워져 있다) — **둘은 서로를 대신하지 못한다**.
	_check("바람 룬 해금 전: q07 정산 대기 아님 (검출력 대조)", not gs.is_quest_claimable(q7))
	eb.codex_unlocked.emit(&"rune_wind")
	_check("🔴 바람 룬 해금: q07 정산 대기 (아직 완료 아님)",
		gs.is_quest_claimable(q7) and not gs.is_quest_done(&"q07_learn_wind"))
	gs.claim_ready_quests()
	_check("🔴 정산해야 q07 완료", gs.is_quest_done(&"q07_learn_wind"))

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
	eb.enemy_died.emit(&"hound")           # q01 진행 1/1 (세58-B count 1)
	# 🔴 q03이 KILL이라 게이트를 **사냥으로** 잰다 —
	#   목표 수보다 넉넉히 잡아도 잠긴 퀘스트는 열리지 않는다.
	for i in q3.need() + 2:
		eb.enemy_died.emit(&"hound")
	_check("🔴 선행(q02) 미완료면 아무리 잡아도 q03은 정산 불가 (requires 게이트)",
		not gs.is_quest_claimable(q3))
	_check("🔴 잠긴 동안의 사냥은 **쌓이지도 않는다** (진행 %d — advance_quests가 active만 센다)"
			% gs.quest_count(&"q03_build_refine"),
		gs.quest_count(&"q03_build_refine") == 0)
	gs.quest_done[&"q01_first_hunt"] = true
	sm.save_game()
	gs.quest_progress.clear()
	gs.quest_done.clear()
	sm.load_game()
	_check("🔴 로드: q01 완료 상태 복원", gs.is_quest_done(&"q01_first_hunt"))
	_check("🔴 로드: q01 진행 카운트(1) 복원", gs.quest_count(&"q01_first_hunt") == 1)

	# ── ⑧ [!] 접수(읽음) 마크 — 안 읽은 active 목표에 느낌표, 시트로 읽으면(mark_quests_seen) 꺼진다 ──
	#  🔴 접수 = 시트 열람이지 정산(턴인)이 아니다 → 정산으로 새 목표가 열려도 읽기 전까진 [!]가 남는다(중간
	#   게임에서도 [!]가 산다). [!]와 [?]는 배타: 미달성이면 [!](읽으러), 달성하면 [?](정산하러).
	_clean(gs)
	# mark_quests_seen이 실제 접수 시 quests_seen를 쏘나 — base가 [!]를 끄는 배선의 핵심.
	var seen_emits := [0]
	var on_seen := func() -> void: seen_emits[0] += 1
	eb.quests_seen.connect(on_seen)
	_check("🔴 시작: q00 active·미달성·미접수 → 새 목표 [!] 있음", gs.has_new_quest())
	_check("[!]/[?] 배타 — 아직 미달성이라 정산할 건 없다", not gs.has_claimable_quest())
	gs.mark_quests_seen()   # 시트를 열어 읽었다 = 접수
	_check("🔴 시트로 읽으면(mark_quests_seen) 접수 → [!] 꺼진다", not gs.has_new_quest())
	_check("🔴 접수되면 quests_seen 발신(base가 [!]를 끈다)", seen_emits[0] == 1)
	gs.mark_quests_seen()   # 다시 불러도 새로 접수될 게 없다
	_check("🔴 접수할 게 없으면 quests_seen 안 쏜다(불필요 리드로 방지)", seen_emits[0] == 1)
	eb.ring_design_committed.emit(RingDesign.new())   # 그린다 → q00 달성
	_check("🔴 달성하면 [?](claimable)로 넘어간다 — [!] 아님(우선순위 배타)",
		gs.has_claimable_quest() and not gs.has_new_quest())
	gs.claim_ready_quests()   # 정산(턴인) → q01·q02 열림(아직 안 읽음). 정산은 접수하지 않는다.
	_check("🔴 정산 직후 q01·q02 미접수 → [!] 남는다 (턴인은 접수 아님 — 중간 게임 [!])", gs.has_new_quest())
	gs.mark_quests_seen()   # 그제서 시트를 열어 다음 목표를 읽는다
	_check("🔴 시트로 읽어야 [!] 꺼진다", not gs.has_new_quest())
	eb.quests_seen.disconnect(on_seen)

	# ── ⑨ quest_seen 저장 라운드트립 — 껐다 켜도 이미 받은 퀘스트에 [!] 안 뜬다 ──
	sm.save_game()
	gs.quest_seen.clear()
	_check("접수를 지우면 다시 [!] (검출력 확인 — 저장이 정말 복원하는지 대조)", gs.has_new_quest())
	sm.load_game()
	_check("🔴 로드: 접수(quest_seen) 복원 → [!] 다시 안 뜬다", not gs.has_new_quest())

	# ── ⑩ reward_unlock — 정산이 룬/진 codex를 해금한다 ──
	#  「보스 잡아와(KILL) → 마을 턴인 → 새 룬」: reward_unlock이 codex_unlocked를 쏴 룬을 심고
	#   예식(unlock_ceremony)을 띄운다 — 퀘스트가 해금의 실제 주체다.
	_clean(gs)
	gs.codex.erase(&"rune_test66")
	var qr := QuestDef.new()
	qr.id = &"qr_test66"
	qr.goal = Enums.QuestGoal.KILL
	qr.target = &"hound"
	qr.count = 1
	qr.reward_unlock = &"rune_test66"   # 🔴 완료 시 이 codex(룬)를 해금
	_backup_quest(db, qr.id)           # 세84: 합성 id라도 같은 규약으로 (뒷정리를 한 곳에 모은다)
	db.quests[qr.id] = qr
	var unlock_emits := [0]
	var on_unlock := func(id: StringName) -> void:
		if id == &"rune_test66": unlock_emits[0] += 1
	eb.codex_unlocked.connect(on_unlock)
	_check("qr: 처치 전 룬 미해금", not gs.is_unlocked(&"rune_test66"))
	eb.enemy_died.emit(&"hound")
	_check("qr: 처치 = 정산 대기 (아직 해금 아님 — 턴인 전)",
		gs.is_quest_claimable(qr) and not gs.is_unlocked(&"rune_test66"))
	gs.claim_ready_quests()
	# 🔴 뮤테이션: _complete_quest의 reward_unlock emit을 지우면 아래 두 줄이 빨개진다.
	_check("🔴 qr 정산: reward_unlock이 codex_unlocked를 쐈다 (정확히 1 — 예식 트리거)", unlock_emits[0] == 1)
	_check("🔴 qr 정산: 룬이 실제로 codex에 심겼다 (turn-in = 해금 주체)", gs.is_unlocked(&"rune_test66"))
	# 🔴 재정산·소급에 이중 발신 안 함 (is_unlocked 가드 — 예식이 두 번 안 뜨게)
	gs.reevaluate_quests()
	gs.claim_ready_quests()
	_check("🔴 이미 해금이면 reward_unlock 재발신 안 함 (is_unlocked 가드)", unlock_emits[0] == 1)
	eb.codex_unlocked.disconnect(on_unlock)
	gs.codex.erase(&"rune_test66")

	# 뒷정리 — 세이브 파일 삭제(스위트 규약) + 메모리 초기화 + 주입 퀘스트 **원상복구**(공유 레지스트리).
	sm.wipe_save()
	_clean(gs)
	_restore_quests(db)   # 🔴 세84: 무조건 erase가 아니라 원본 복원 (없던 것만 지운다)

	# 🔴 뒷정리 검출자 — Db가 **시작과 똑같이** 돌아왔다. 대역이 남아도(누수) 실데이터가 지워져도
	#   여기가 빨개진다. 그래서 q06·q07 .tres가 복원돼도 이 테스트는 그걸 안 먹는다.
	var quests_at_end: Array = db.quests.keys()
	quests_at_end.sort()
	_check("🔴 뒷정리: Db.quests가 시작 상태와 같다 (주입 대역 누수 0 · 실데이터 삭제 0)",
		quests_at_end == quests_at_start)

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_QUESTS_OK — 전 항목 통과")
	# 🔴 실패하면 종료코드 1 — 인자 없는 `quit()`은 실패해도 0이라 러너가 못 거른다.
	quit(0 if _fail == 0 else 1)
