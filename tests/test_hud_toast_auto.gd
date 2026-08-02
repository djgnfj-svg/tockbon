extends SceneTree
## HUD 획득 토스트 자동 검증 — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_hud_toast_auto.gd
## 전 항목 통과 시 "TEST_HUD_TOAST_OK" 출력 후 종료 코드 0.
##
## 검증 대상 = **도배 방지 규칙**: 같은 아이템은 줄을 늘리지 않고 수량을 더한다 ·
## 최대 3줄이고 넘치면 가장 오래된 줄이 밀린다 · 수명이 다하면 사라진다.
## 이건 순수 로직이라 헤드리스가 잡는다.
##
## 🔴 헤드리스가 **못 잡는 것**(리드가 실게임 스샷으로 확인): 토스트가 실제로 보이는지 ·
##   슬롯 4칸·HP/마나/허기 막대와 겹치지 않는지 · 페이드아웃이 자연스러운지.
##   `_draw`는 렌더가 없으면 안 불린다 — 여기서 검증하는 건 **스택 상태**뿐이다.
##
## 공개 API로만 본다: EventBus.item_collected 발신 + hud.toast_lines().
## 내부 배열(_toasts)은 리팩터 때 옮겨 다니는 물건이라 더듬지 않는다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

var failures: int = 0
var _bus = null
var _hud = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		print("TEST_HUD_TOAST_TIMEOUT — 20초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_hud = Control.new()
	_hud.set_script(load("res://src/hud/hud.gd"))
	root.add_child(_hud)
	await process_frame  # _ready → EventBus 구독

	await _test_merges_same_item()
	await _test_fifo_max_three()
	await _test_merge_refreshes_order()
	await _test_expires()

	_hud.free()

	if failures == 0:
		print("TEST_HUD_TOAST_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_HUD_TOAST_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 같은 아이템 두 번 → 줄은 하나, 수량은 합쳐진다.
## 안 그러면 드롭이 동시에 도착할 때 "풀 조각 x1"이 여러 줄 떠 화면이 도배된다.
func _test_merges_same_item() -> void:
	print("[1] 같은 아이템은 새 줄을 안 만들고 수량이 합쳐진다")
	await _clear()
	_bus.item_collected.emit(&"mat_slime_core", 1)
	_bus.item_collected.emit(&"mat_slime_core", 2)
	var lines = _hud.toast_lines()
	_check(lines.size() == 1, "줄이 1개다 (실제 %d개)" % lines.size())
	if lines.size() == 1:
		_check(int(lines[0]["count"]) == 3, "수량이 3으로 합쳐졌다 (실제 %d)" % int(lines[0]["count"]))
		_check(lines[0]["id"] == &"mat_slime_core", "아이템 id가 실렸다")


## [2] 🔴 다른 아이템 4종 → 3줄만 남고 **가장 오래된 것**이 밀린다 (FIFO).
func _test_fifo_max_three() -> void:
	print("[2] 최대 3줄 — 4번째 종류가 오면 가장 오래된 줄이 밀린다")
	await _clear()
	_bus.item_collected.emit(&"item_a", 1)
	_bus.item_collected.emit(&"item_b", 1)
	_bus.item_collected.emit(&"item_c", 1)
	_bus.item_collected.emit(&"item_d", 1)
	var lines = _hud.toast_lines()
	_check(lines.size() == 3, "줄이 3개로 제한된다 (실제 %d개)" % lines.size())
	var ids := []
	for l in lines:
		ids.append(l["id"])
	_check(not ids.has(&"item_a"), "가장 오래된 item_a가 밀려났다 (남은 것: %s)" % str(ids))
	_check(ids.has(&"item_d"), "가장 최근 item_d가 남아 있다 (남은 것: %s)" % str(ids))


## [4] 🔴 **합친 줄은 맨 뒤(=가장 최근)로 옮겨진다** — 회귀 가드.
## 안 옮기면 ① 갱신된 줄이 위쪽 낡은 자리에 남아 "최근 획득은 항상 맨 아래" 규약이 깨지고
## ② **FIFO가 방금 갱신된 줄을 밀어낸다**(A·B·C 뜬 상태에서 A를 또 줍고 D를 주우면 A가 증발).
## ②가 진짜 버그다 — 방금 주운 걸 화면이 안 알려 준다.
func _test_merge_refreshes_order() -> void:
	print("[4] 합친 줄은 맨 뒤로 옮겨져 FIFO에 안 밀린다")
	await _clear()
	_bus.item_collected.emit(&"item_a", 1)
	_bus.item_collected.emit(&"item_b", 1)
	_bus.item_collected.emit(&"item_c", 1)
	_bus.item_collected.emit(&"item_a", 1)   # a를 다시 주웠다 = 가장 최근이 돼야 한다
	var lines = _hud.toast_lines()
	_check(lines.size() == 3, "아직 3줄이다 (실제 %d개)" % lines.size())
	if lines.size() == 3:
		_check(lines[2]["id"] == &"item_a",
			"합친 a가 맨 뒤(최근)로 옮겨졌다 (실제 맨 뒤: %s)" % str(lines[2]["id"]))
		_check(lines[0]["id"] == &"item_b", "이제 가장 오래된 건 b다 (실제: %s)" % str(lines[0]["id"]))

	_bus.item_collected.emit(&"item_d", 1)   # 4번째 종류 → 가장 오래된 b가 밀려야 한다
	var after = _hud.toast_lines()
	var ids2 := []
	for l in after:
		ids2.append(l["id"])
	_check(ids2.has(&"item_a"),
		"🔴 방금 갱신한 a가 살아남았다 — FIFO가 최신 줄을 밀어내지 않는다 (남은 것: %s)" % str(ids2))
	_check(not ids2.has(&"item_b"), "대신 진짜 가장 오래된 b가 밀렸다 (남은 것: %s)" % str(ids2))


## [3] 수명(TOAST_LIFE 1.6s)이 지나면 사라진다 — 안 그러면 화면에 영원히 남는다.
func _test_expires() -> void:
	print("[3] 수명이 지나면 사라진다")
	await _clear()
	_bus.item_collected.emit(&"mat_slime_core", 1)
	_check(_hud.toast_lines().size() == 1, "방금 띄운 줄이 있다")
	await create_timer(2.0).timeout   # TOAST_LIFE(1.6s) 초과
	_check(_hud.toast_lines().is_empty(),
		"수명 뒤엔 비어 있다 (실제 %d개)" % _hud.toast_lines().size())


# ── 헬퍼 ──

## 남은 토스트를 수명 경과로 비운다 (내부 배열을 직접 건드리지 않는다).
func _clear() -> void:
	if _hud.toast_lines().is_empty():
		return
	await create_timer(2.0).timeout


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
