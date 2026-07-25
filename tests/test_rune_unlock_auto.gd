extends SceneTree
## 룬 해금 자동 검증 — 세션34 E4에 「해독대」로 태어나 **세85에 해독대가 은퇴하며 남은 그물**.
## 실행: Godot --headless --path . -s res://tests/test_rune_unlock_auto.gd
## 오토로드는 런타임 get_node로만 접근 (-s 컴파일 시점 미등록 함정).
##
## 🔴🔴 **이 파일을 통째로 지우지 마라.** 아래 ④-b 「룬 6종 로드 + 6종 개별 확인」이 **세50 침묵사의
## 유일한 감지기**다 — `.tres`의 `Color`를 3인자로 쓰면 파서가 리소스 전체를 거부하고 `Db`가
## **말없이 건너뛰는데**, 그때 빨개지는 곳이 여기뿐이다(바람 룬이 두 세션 죽어 있는 동안 전 스위트가
## 그린이었다). 합계만 재면 하나 죽고 하나 살아도 6이라 **개별 확인이 같이 있어야** 한다.
##
## 🔴 남은 계약 = **해금이 조립 책의 룬 목록에 흐른다**(codex → forge_panel._unlocked_runes 규약).
##  해금의 주체는 이제 **퀘스트 턴인**(`reward_unlock`, 세66 도파민 D)이라 어느 주체가 codex를
##  심든 이 흐름이 성립해야 한다 — 그래서 아래 ③은 **codex를 직접 심어** 통로만 잰다.
##
## ⚠ **세85에 걷은 것**: 조각(FRAGMENT) 소비 → 해독 패널 → 해금 경로. `decode_panel`은 진입 경로가
##  0곳이었고(`zone_id=decode`인 프롭이 없다) `data/items`에 kind 6(FRAGMENT)이 0장이라 실게임에선
##  늘 빈 목록이었다 — 이 테스트가 씬을 로드하는 **유일한 곳**이었다(세84 감사 #32 · 사용자 결정 ⑩).
##  ⑤(unlock_id 오타 스캔)·⑥(조각 관문 드롭 감시)은 **남긴다**: 조각을 되살리는 세션이 오면
##  자동으로 다시 가동되고, 지금은 0행이라 SKIP으로 찍힌다.
##
## 🔴 파일 이름이 더는 내용과 안 맞는다(해독대가 없다) — 개명은 CLAUDE.md·`takbon-verify`의 검증
##  목록과 같이 움직여야 해서(세 세션 연속 갈라진 자리) **리드가 한 번에** 한다. 제안: `test_rune_unlock_auto.gd`.

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

## 🔴 「조립 책이 그릴 수 있다고 보는 룬」의 규약 — `forge_panel._unlocked_runes`와 같은 판정.
## 세85에 두 번(해금 전·후) 부르게 되면서 뽑았다. `_visited`는 순회가 정본 전량을 훑었는지의 그물.
var _visited := 0

func _unlocked_types(gs: Node, db: Node) -> Array:
	var out: Array = []
	_visited = 0
	for t: int in Enums.RUNE_TYPES:
		_visited += 1
		var rd: RuneDef = db.get_rune(t)
		if rd != null and rd.unlock_id != &"" and gs.is_unlocked(rd.unlock_id):
			out.append(t)
	return out

func _run() -> void:
	# 🔴 세84 #44: 워치독 — `_run`이 중간에 죽으면 `quit()`에 못 닿아 프로세스가 영구 hang했다.
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_RUNE_UNLOCK_TIMEOUT — 30초 초과 (테스트가 중간에 죽었을 수 있다)")
		quit(1))
	await process_frame
	var gs: Node = root.get_node("GameState")
	var db: Node = root.get_node("Db")

	# 🔴 세85: 흙 룬을 **미해금 상태로 되돌려** 아래 ③이 「해금 전 → 해금 후」를 실제로 대조하게 한다.
	#   (세83에 흙이 시작 지급으로 바뀌어, 안 지우면 ③이 「이미 켜져 있던 것」을 재는 자명 통과가 된다.)
	#   ⚠ 실데이터 룬 자체는 **건드리지 않는다** — 세83 사고(주입 뒤 `erase`가 진짜 흙 룬을 지워
	#   ④-b가 6→5로 떨어진 자리)의 재발 자리다. 여기서 만지는 건 GameState.codex뿐이다.
	var had_earth_codex: bool = gs.is_unlocked(&"rune_earth")
	gs.codex.erase(&"rune_earth")

	# ── ③ 해금이 조립 책의 룬 목록에 흐른다 — 해금되면 그릴 수 있다 ──
	# forge_panel._unlocked_runes와 같은 규약을 여기서 직접 확인 (패널 인스턴스는 무거워 로직만).
	# 세78: 불·물·바람은 시작부터 해금(시드 3종).
	# 🔴 세84 #43: 손으로 적은 `[0, 2, 3, 5]`를 **정본 `Enums.RUNE_TYPES` 순회**로 바꿨다 —
	#   7번째 룬이 오면 그 룬이 「책 목록에 흘러드나」를 한 번도 안 재는 사본이었다(같은 파일 아래
	#   ④-b·⑤가 이미 정본을 쓰고 있어 컴파일 함정 변명도 안 섰다).
	# 🔴 세85: 해금 **주체**가 해독대에서 **퀘스트 턴인**으로 옮겨갔으므로(세66 도파민 D) 여기서는
	#   주체를 흉내내지 않고 **통로만** 잰다 — `EventBus.codex_unlocked` 한 발이 곧 해금이고
	#   (`GameState._on_codex_unlocked`), 그게 책 목록에 흘러야 한다. 어느 주체가 쏘든 같은 계약이다.
	_check("🔴 검출력 대조: 해금 전엔 흙(5)이 책 목록에 없다", not _unlocked_types(gs, db).has(5))
	root.get_node("EventBus").codex_unlocked.emit(&"rune_earth")
	_check("🔴 codex_unlocked 한 발이 해금이다 (GameState.codex에 심긴다)", gs.is_unlocked(&"rune_earth"))

	var unlocked_types: Array = _unlocked_types(gs, db)
	_check("🔴 룬 목록 순회가 정본 %d종을 다 훑었다 (손 사본이 아니라 Enums.RUNE_TYPES)"
		% Enums.RUNE_TYPES.size(), _visited == Enums.RUNE_TYPES.size() and _visited > 0)
	_check("불(0)은 시작부터 해금", 0 in unlocked_types)
	_check("🔴 물(2)이 시작부터 해금돼 그릴 수 있다 (세78 시드)", 2 in unlocked_types)
	_check("🔴 바람(3)이 시작부터 해금돼 그릴 수 있다 (세78 시드)", 3 in unlocked_types)
	_check("🔴 흙(5)이 해금되자 책 목록에 들어왔다 (codex → 그릴 수 있는 룬)", 5 in unlocked_types)

	# ── 원상복구 — 이후 검증은 **실데이터만** 본다 ──
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

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _skips > 0:
		print("TEST_RUNE_UNLOCK_SKIPS — %d개 스캔이 0행이라 잠들어 있다 (위 SKIP 줄 참조)" % _skips)
	if _fail == 0:
		print("TEST_RUNE_UNLOCK_OK — 전 항목 통과")
	# 🔴 세84 #44: 실패하면 종료코드 1 (전엔 인자 없는 quit() = 실패해도 0).
	quit(0 if _fail == 0 else 1)
