extends SceneTree
## 탁본 해독대 자동 검증 — 세션34 E4 (룬 조각 → 룬 해금).
## 실행: Godot --headless --path . -s res://tests/test_decode_auto.gd
## 오토로드는 런타임 get_node로만 접근 (-s 컴파일 시점 미등록 함정).
##
## 🔴 계약: fragment_*를 해독하면 (1) 조각이 소비되고 (2) params.unlock_id 룬이 해금된다
## (codex_unlocked → GameState.codex). 이미 배운 룬은 다시 해독해도 조각이 안 닳는다(낭비 방지).
## 🔴 그리고 해금이 **조립 책의 룬 목록**(forge_panel._unlocked_runes)에 흘러 그릴 수 있게 된다.
## **패널 클릭은 헤드리스가 못 잡는다** — _decode를 공개 로직으로 직접 부른다(workshop 테스트와 같은 방침).

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
	var unlocked_types: Array = []
	for t in [0, 2, 3]:   # Enums.RuneType FIRE·WATER·WIND (구멍 1 때문에 명시 리스트)
		var rd: RuneDef = db.get_rune(t)
		if rd != null and rd.unlock_id != &"" and gs.is_unlocked(rd.unlock_id):
			unlocked_types.append(t)
	_check("불(0)은 시작부터 해금", 0 in unlocked_types)
	_check("🔴 물(2)이 해금 목록에 들어와 그릴 수 있다", 2 in unlocked_types)
	_check("바람(3)은 아직 잠겨 안 뜬다", not (3 in unlocked_types))

	# ── ④ unlock_id 없는 조각/미보유는 무해 ──
	gs.inventory.erase(&"fragment_water")
	panel._decode(&"fragment_water")   # 보유 0 — 소비할 게 없다, 터지지 않아야
	_check("보유 0 조각 해독은 조용히 무해", gs.get_count(&"fragment_water") == 0)

	# 뒷정리 — 오토로드 GameState 메모리 오염 방지 (codex는 저장 트리거는 아니지만 깔끔하게).
	gs.codex.erase(&"rune_water")
	panel.queue_free()

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_DECODE_OK — 전 항목 통과")
	quit()
