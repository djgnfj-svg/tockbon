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
	var db: Node = root.get_node("Db")

	# ── in-memory 주입: 물 룬 + 물 조각 (세61 — 실 .tres가 없어 기계 검증용으로 만든다) ──
	var test_rune := RuneDef.new()
	test_rune.type = Enums.RuneType.WATER
	test_rune.unlock_id = &"rune_water"
	test_rune.display_name = "물(테스트)"
	db.runes[Enums.RuneType.WATER] = test_rune
	var test_frag := ItemDef.new()
	test_frag.id = &"fragment_water"
	test_frag.kind = Enums.ItemKind.FRAGMENT
	test_frag.display_name = "물 조각(테스트)"
	test_frag.params = {"unlock_id": &"rune_water"}
	db.items[&"fragment_water"] = test_frag

	# 깨끗한 시작 — 물 룬은 아직 안 배운 상태여야 검증이 성립한다.
	gs.codex.erase(&"rune_water")
	gs.inventory.erase(&"fragment_water")

	var PanelScene: PackedScene = load("res://src/base/decode_panel.tscn")
	var panel: Control = PanelScene.instantiate()
	root.add_child(panel)   # _ready가 돈다 (EventBus 연결·_list 주입)
	await process_frame

	# ── ① 해독 = 조각 소비 + 룬 해금 ──
	_check("시작: 물 룬 미해금", not gs.is_unlocked(&"rune_water"))
	gs.add_item(&"fragment_water", 2)
	panel._decode(&"fragment_water")
	_check("🔴 해독하면 물 룬이 해금된다 (codex_unlocked → codex)", gs.is_unlocked(&"rune_water"))
	_check("해독이 조각 하나를 소비한다 (2 → 1)", gs.get_count(&"fragment_water") == 1)

	# ── ② 이미 배운 룬은 다시 해독해도 조각이 안 닳는다 ──
	panel._decode(&"fragment_water")
	_check("🔴 이미 배운 룬은 조각을 낭비하지 않는다 (1 그대로)", gs.get_count(&"fragment_water") == 1)

	# ── ③ 해금이 조립 책의 룬 목록에 흐른다 — 이제 물 룬을 그릴 수 있다 ──
	# forge_panel._unlocked_runes와 같은 규약을 여기서 직접 확인 (패널 인스턴스는 무거워 로직만).
	# 바람(3)은 세61부터 .tres 자체가 없다 — get_rune(3)=null이라 필터가 거른다(같은 계약).
	var unlocked_types: Array = []
	for t in [0, 2, 3]:   # Enums.RuneType FIRE·WATER·WIND (구멍 1 때문에 명시 리스트)
		var rd: RuneDef = db.get_rune(t)
		if rd != null and rd.unlock_id != &"" and gs.is_unlocked(rd.unlock_id):
			unlocked_types.append(t)
	_check("불(0)은 시작부터 해금", 0 in unlocked_types)
	_check("🔴 물(2)이 해금 목록에 들어와 그릴 수 있다", 2 in unlocked_types)
	_check("바람(3)은 등록이 없어 안 뜬다", not (3 in unlocked_types))

	# ── ④ unlock_id 없는 조각/미보유는 무해 ──
	gs.inventory.erase(&"fragment_water")
	panel._decode(&"fragment_water")   # 보유 0 — 소비할 게 없다, 터지지 않아야
	_check("보유 0 조각 해독은 조용히 무해", gs.get_count(&"fragment_water") == 0)

	# ── 주입 제거 — 이후 검증은 **실데이터만** 본다 ──
	db.runes.erase(Enums.RuneType.WATER)
	db.items.erase(&"fragment_water")
	gs.codex.erase(&"rune_water")

	# ── ④-b 🔴 룬이 실제로 로드된다 (.tres 파싱 침묵사 그물 — 세50 함정) ──
	# rune_wind.tres가 세션49~50 내내 파싱에 실패해 룬이 통째로 죽었는데 전 스위트가 그린이었다.
	# 세61 콘텐츠 리셋: 실데이터 룬 = rune_fire 1종. 룬을 되살릴 때마다 이 기대치를 +1.
	_check("🔴 불 룬(FIRE)이 로드된다 (.tres 파싱 실패 = 룬이 통째로 사라짐)",
		db.get_rune(Enums.RuneType.FIRE) != null)
	var loaded_runes := 0
	for t: int in Enums.RUNE_TYPES:
		if db.get_rune(t) != null:
			loaded_runes += 1
	_check("🔴 로드된 룬 = 정확히 1종 (지금 %d — 늘었으면 기대치 갱신, 줄었으면 침묵사)" % loaded_runes,
		loaded_runes == 1)

	# ── ⑤ 🔴 실데이터 조각의 unlock_id는 실재하는 룬을 가리킨다 (오타 그물 — 미래용) ──
	# 세61: 조각 .tres 0장이라 지금은 자명하게 통과한다. 조각을 되살리면 이 스캔이 바로 산다.
	for it: ItemDef in db.items.values():
		if it == null or it.kind != Enums.ItemKind.FRAGMENT:
			continue
		var declared := StringName(it.params.get("unlock_id", &""))
		var rune_found := false
		for t: int in Enums.RUNE_TYPES:
			var rd: RuneDef = db.get_rune(t)
			if rd != null and rd.unlock_id == declared:
				rune_found = true
				break
		_check("🔴 %s의 unlock_id(%s)가 실재하는 룬을 가리킨다" % [it.id, declared], rune_found)

	# ── ⑥ 조각의 획득 경로 = 관문 드롭뿐 (세58 은퇴 원칙 감시 — 세61에도 그물 유지) ──
	# 조각이 뿌려진다면 반드시 until_unlock 관문이어야 한다 (순수 확률 fragment = 은퇴 위반).
	# 지금은 관문 드롭도 0줄(세61)이라 자명 통과 — 조각·관문을 되살리면 바로 산다.
	for e: EnemyDef in db.enemies.values():
		for d: DropEntry in e.drops:
			if String(d.item_id).begins_with("fragment_") and d.until_unlock == &"":
				_check("🔴 %s가 %s에서 관문 없이(순수 확률로) 뿌려진다" % [d.item_id, e.id], false)

	panel.queue_free()

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_DECODE_OK — 전 항목 통과")
	quit()
