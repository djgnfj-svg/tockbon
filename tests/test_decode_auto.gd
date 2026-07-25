extends SceneTree
## 탁본 해독대 자동 검증 — 세션34 E4 (룬 조각 → 룬 해금).
## 실행: Godot --headless --path . -s res://tests/test_decode_auto.gd
## 오토로드는 런타임 get_node로만 접근 (-s 컴파일 시점 미등록 함정).
##
## 🔴 계약: fragment_*를 해독하면 (1) 조각이 소비되고 (2) params.unlock_id 룬이 해금된다
## (codex_unlocked → GameState.codex). 이미 배운 룬은 다시 해독해도 조각이 안 닳는다(낭비 방지).
## 🔴 그리고 해금이 **조립 책의 룬 목록**(forge_panel._unlocked_runes)에 흘러 그릴 수 있게 된다.
## **패널 클릭은 헤드리스가 못 잡는다** — _decode를 공개 로직으로 직접 부른다(workshop 테스트와 같은 방침).
##
## 🔴 세61 콘텐츠 리셋: 룬은 rune_fire 1종, 조각 .tres는 0장이 됐다. 해독 **기계**(조각 소비→해금→
## 책 목록 유입)는 그대로 살아 있으므로, 흐름 검증은 **in-memory ItemDef+RuneDef를 Db 딕셔너리에
## 주입**해서 유지한다(Db 레지스트리는 평범한 Dictionary — 끝나면 제거). 룬/조각을 되살리면
## 실데이터 검증(로드 개수 기대치)을 같이 올려라.

var _pass := 0
var _fail := 0
## 🔴 세84 #41: 0행 스캔은 PASS가 아니라 SKIP으로 찍는다 (조각 .tres가 0장인 동안 ⑤⑥은 잠들어 있다).
var _skips := 0

func _init() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS: ", label)
	else:
		_fail += 1
		print("FAIL: ", label)

## 잴 데이터가 0행일 때 — 실패는 아니지만 **PASS로 위장하지 않는다**(복원 세션이 오타를 내도
## 초록불이던 자리). 로그에 남아 "이 그물은 지금 잠들어 있다"를 리드가 본다.
func _skip(label: String) -> void:
	_skips += 1
	print("SKIP(0행): ", label, " — 잴 데이터가 없다 (복원되면 자동 가동)")

func _run() -> void:
	# 🔴 세84 #44: 워치독 — `_run`이 중간에 죽으면 `quit()`에 못 닿아 프로세스가 영구 hang했다.
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_DECODE_TIMEOUT — 30초 초과 (테스트가 중간에 죽었을 수 있다)")
		quit(1))
	await process_frame
	var gs: Node = root.get_node("GameState")
	var db: Node = root.get_node("Db")

	# ── in-memory 주입: 흙 룬 + 흙 조각 (해독 기계 검증용 대역) ──
	# 🔴🔴 **세83: 전제가 뒤집혔다.** 세78 주석은 *"흙은 아직 실 .tres도 시드도 없어 「아직 안 배운
	# 룬」 자리로 딱 맞다"*였는데, 세83에 룬 6종을 복원해 **흙도 실데이터 + 시작 지급**이 됐다.
	# 그래서 주입 뒤 `db.runes.erase(EARTH)`가 **진짜 흙 룬까지 지워** ④-b의 로드 수가 6→5로
	# 떨어졌다(그물이 실제로 잡았다). → 주입 전에 **원본을 보관했다가 되돌린다**.
	# ⚠ 룬이 전부 실재하게 된 이상 「빈 자리를 빌려 쓴다」는 수법은 이제 못 쓴다.
	var real_earth: RuneDef = db.get_rune(Enums.RuneType.EARTH)
	var had_earth_codex: bool = gs.is_unlocked(&"rune_earth")
	var test_rune := RuneDef.new()
	test_rune.type = Enums.RuneType.EARTH
	test_rune.unlock_id = &"rune_earth"
	test_rune.display_name = "흙(테스트)"
	db.runes[Enums.RuneType.EARTH] = test_rune
	var test_frag := ItemDef.new()
	test_frag.id = &"fragment_earth"
	test_frag.kind = Enums.ItemKind.FRAGMENT
	test_frag.display_name = "흙 조각(테스트)"
	test_frag.params = {"unlock_id": &"rune_earth"}
	db.items[&"fragment_earth"] = test_frag

	# 깨끗한 시작 — 흙 룬은 아직 안 배운 상태여야 검증이 성립한다.
	gs.codex.erase(&"rune_earth")
	gs.inventory.erase(&"fragment_earth")

	var PanelScene: PackedScene = load("res://src/base/decode_panel.tscn")
	var panel: Control = PanelScene.instantiate()
	root.add_child(panel)   # _ready가 돈다 (EventBus 연결·_list 주입)
	await process_frame

	# ── ① 해독 = 조각 소비 + 룬 해금 ──
	_check("시작: 흙 룬 미해금", not gs.is_unlocked(&"rune_earth"))
	gs.add_item(&"fragment_earth", 2)
	panel._decode(&"fragment_earth")
	_check("🔴 해독하면 흙 룬이 해금된다 (codex_unlocked → codex)", gs.is_unlocked(&"rune_earth"))
	_check("해독이 조각 하나를 소비한다 (2 → 1)", gs.get_count(&"fragment_earth") == 1)

	# ── ② 이미 배운 룬은 다시 해독해도 조각이 안 닳는다 ──
	panel._decode(&"fragment_earth")
	_check("🔴 이미 배운 룬은 조각을 낭비하지 않는다 (1 그대로)", gs.get_count(&"fragment_earth") == 1)

	# ── ③ 해금이 조립 책의 룬 목록에 흐른다 — 이제 흙 룬을 그릴 수 있다 ──
	# forge_panel._unlocked_runes와 같은 규약을 여기서 직접 확인 (패널 인스턴스는 무거워 로직만).
	# 세78: 불·물·바람은 시작부터 해금(시드 3종), 흙은 방금 해독으로 붙었다.
	# 🔴 세84 #43: 손으로 적은 `[0, 2, 3, 5]`를 **정본 `Enums.RUNE_TYPES` 순회**로 바꿨다 —
	#   7번째 룬이 오면 그 룬이 「책 목록에 흘러드나」를 한 번도 안 재는 사본이었다(같은 파일 아래
	#   ④-b·⑤가 이미 정본을 쓰고 있어 컴파일 함정 변명도 안 섰다).
	var unlocked_types: Array = []
	var visited := 0
	for t: int in Enums.RUNE_TYPES:
		visited += 1
		var rd: RuneDef = db.get_rune(t)
		if rd != null and rd.unlock_id != &"" and gs.is_unlocked(rd.unlock_id):
			unlocked_types.append(t)
	_check("🔴 룬 목록 순회가 정본 %d종을 다 훑었다 (손 사본이 아니라 Enums.RUNE_TYPES)"
		% Enums.RUNE_TYPES.size(), visited == Enums.RUNE_TYPES.size() and visited > 0)
	_check("불(0)은 시작부터 해금", 0 in unlocked_types)
	_check("🔴 물(2)이 시작부터 해금돼 그릴 수 있다 (세78 시드)", 2 in unlocked_types)
	_check("🔴 바람(3)이 시작부터 해금돼 그릴 수 있다 (세78 시드)", 3 in unlocked_types)
	_check("🔴 흙(5)이 해독으로 목록에 들어왔다", 5 in unlocked_types)

	# ── ④ unlock_id 없는 조각/미보유는 무해 ──
	gs.inventory.erase(&"fragment_earth")
	panel._decode(&"fragment_earth")   # 보유 0 — 소비할 게 없다, 터지지 않아야
	_check("보유 0 조각 해독은 조용히 무해", gs.get_count(&"fragment_earth") == 0)

	# ── 주입 제거 — 이후 검증은 **실데이터만** 본다 ──
	# 🔴 흙은 **되돌린다**(지우지 않는다) — 세83에 실데이터가 됐다. 지우면 ④-b가 5종을 세고,
	#   그건 「.tres가 죽었다」와 구분이 안 되는 거짓 빨강이다.
	if real_earth != null:
		db.runes[Enums.RuneType.EARTH] = real_earth
	else:
		db.runes.erase(Enums.RuneType.EARTH)
	db.items.erase(&"fragment_earth")
	if had_earth_codex:
		gs.codex[&"rune_earth"] = true
	else:
		gs.codex.erase(&"rune_earth")

	# ── ④-b 🔴 룬이 실제로 로드된다 (.tres 파싱 침묵사 그물 — 세50 함정) ──
	# rune_wind.tres가 세션49~50 내내 파싱에 실패해 룬이 통째로 죽었는데 전 스위트가 그린이었다.
	# 세83: 실데이터 룬 = **6종 전부**(불·물·바람·번개·흙·풀). 룬을 되살릴 때마다 이 기대치를 갱신.
	_check("🔴 불 룬(FIRE)이 로드된다 (.tres 파싱 실패 = 룬이 통째로 사라짐)",
		db.get_rune(Enums.RuneType.FIRE) != null)
	_check("🔴 물 룬(WATER)이 로드된다 (rune_water.tres 파싱 그물)",
		db.get_rune(Enums.RuneType.WATER) != null)
	_check("🔴 바람 룬(WIND)이 로드된다 (rune_wind.tres 파싱 그물 — 세50 3인자 Color 침묵사 자리)",
		db.get_rune(Enums.RuneType.WIND) != null)
	# 🔴 세83 복원 3종 — 개별로도 세운다. 합계만 재면 「하나 죽고 하나 살아」도 6이 될 수 있다.
	_check("🔴 번개 룬(BOLT)이 로드된다 (세83 복원)", db.get_rune(Enums.RuneType.BOLT) != null)
	_check("🔴 흙 룬(EARTH)이 로드된다 (세83 복원 — 위 주입 원복이 안 되면 여기가 빨개진다)",
		db.get_rune(Enums.RuneType.EARTH) != null)
	_check("🔴 풀 룬(GRASS)이 로드된다 (세83 복원)", db.get_rune(Enums.RuneType.GRASS) != null)
	var loaded_runes := 0
	for t: int in Enums.RUNE_TYPES:
		if db.get_rune(t) != null:
			loaded_runes += 1
	# 🔴 세83에 3 → 6 (번개·흙·풀 복원, 세49 원본을 git에서 되살림). 이 숫자가 곧 세50 침묵사
	#   그물이다 — `.tres` 한 글자가 틀리면 Db가 **말없이** 건너뛰고 여기서만 빨개진다.
	_check("🔴 로드된 룬 = 정확히 6종 (지금 %d — 늘었으면 기대치 갱신, 줄었으면 침묵사)" % loaded_runes,
		loaded_runes == 6)

	# ── ⑤ 🔴 실데이터 조각의 unlock_id는 실재하는 룬을 가리킨다 (오타 그물 — 미래용) ──
	# 세61: 조각 .tres 0장이라 이 루프는 **0번 돈다**. 🔴 세84: 그걸 PASS로 위장하지 않고 SKIP으로
	# 찍는다 — 조각을 되살리는 세션이 오타를 내도 초록불이던 자리(#41).
	var frag_scanned := 0
	for it: ItemDef in db.items.values():
		if it == null or it.kind != Enums.ItemKind.FRAGMENT:
			continue
		frag_scanned += 1
		var declared := StringName(it.params.get("unlock_id", &""))
		var rune_found := false
		for t: int in Enums.RUNE_TYPES:
			var rd: RuneDef = db.get_rune(t)
			if rd != null and rd.unlock_id == declared:
				rune_found = true
				break
		_check("🔴 %s의 unlock_id(%s)가 실재하는 룬을 가리킨다" % [it.id, declared], rune_found)
	if frag_scanned == 0:
		_skip("⑤ 조각 아이템(FRAGMENT) 0장 → 「unlock_id 오타」 스캔")

	# ── ⑥ 조각의 획득 경로 = 관문 드롭뿐 (세58 은퇴 원칙 감시 — 세61에도 그물 유지) ──
	# 조각이 뿌려진다면 반드시 until_unlock 관문이어야 한다 (순수 확률 fragment = 은퇴 위반).
	# 🔴 세84: 전엔 위반을 찾을 때만 `_check(false)`를 불러 **위반이 없으면 단정이 0개**였다 —
	#   드롭 스캔이 파손돼도(필드 개명 등) 통째로 침묵. 이제 ①훑은 줄 수를 세고 ②위반 목록을
	#   한 번의 단정으로 낸다(0행이면 SKIP과 함께 「스캔이 실제로 돌았다」가 남는다).
	var drops_scanned := 0
	var loose_fragments: Array = []
	for e: EnemyDef in db.enemies.values():
		for d: DropEntry in e.drops:
			drops_scanned += 1
			if String(d.item_id).begins_with("fragment_") and d.until_unlock == &"":
				loose_fragments.append("%s→%s" % [e.id, d.item_id])
	_check("🔴 적 드롭 줄을 실제로 훑었다 (%d줄 — 0이면 스캔이 죽어 아래 단정이 자명 통과다)"
		% drops_scanned, drops_scanned > 0)
	_check("🔴 관문 없이(순수 확률로) 뿌려지는 조각 0곳 (잔재: %s)" % str(loose_fragments),
		loose_fragments.is_empty())

	panel.queue_free()

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _skips > 0:
		print("TEST_DECODE_SKIPS — %d개 스캔이 0행이라 잠들어 있다 (위 SKIP 줄 참조)" % _skips)
	if _fail == 0:
		print("TEST_DECODE_OK — 전 항목 통과")
	# 🔴 세84 #44: 실패하면 종료코드 1 (전엔 인자 없는 quit() = 실패해도 0).
	quit(0 if _fail == 0 else 1)
