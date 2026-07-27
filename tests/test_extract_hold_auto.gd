extends SceneTree
## 탈출 홀드(D7) + 탈출구 여럿(D1) 자동 검증 — 세99 단계 1a·1b. 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_extract_hold_auto.gd
## 전 항목 통과 시 "TEST_EXTRACT_HOLD_OK" 출력 후 종료 코드 0.
## 정본 = `docs/takbon-design/dungeon_structure_design.md` (§2-4 · §6 S4·S5·S8·S11·S12 · §7 단계 1a·1b).
##
## 🔴🔴 **왜 새 파일인가 — 기존 정산 그물이 홀드를 못 잰다.**
## `test_chapter_auto`의 `[4b]`·`[5]`는 `zone.interacted`를 **직접 emit한다**(E를 안 누른다) →
## **홀드가 아예 안 돌아도 그린이다**(설계 §6 S11). 그래서 여기서는 전부
## **`Input.action_press` + 실제 이벤트 주입 + 프레임 진행 + `action_release`**로 잰다
## (선례 = `test_spell_cast_auto`의 홀드 항목 + `test_base_auto._push_action`).
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##  [1] **회귀 방어선** — `hold_sec` 기본 0 · 씬 파일 어디에도 `hold_sec`이 안 적혀 있다 ·
##      0이면 **누른 그 프레임에** 발동한다(= 마을 책상·문이 한 톨도 안 바뀐다, §6 S8)
##  [2] **값의 소유자가 `balance`다** — `hold_sec`을 흔들어도 길이가 안 변하고,
##      `balance.extract_hold_sec`을 흔들면 변한다(스위치 ↔ 값의 분리)
##  [3] 다 차야 나간다 · **덜 차고 떼면 안 나간다** · 진행률이 오른다
##  [4] **취소 넷** — 피격 · 범위 이탈 · 모달 · 트리 이탈(= 씬 전환)
##  [5] **진행이 화면에 있다** — `Prompt`에 막대가 붙고 끝나면 원문이 돌아온다
##  [6] `boss_room` — 출구가 **여럿**이고 **전부** `_extract`에 이어지고 **전부 풀길이 깔린다**.
##      🔴 `extract_points`가 비면 타일이 세98과 **칸 하나까지 같다**(회귀 0)
##      🔴🔴 **ⓐ는 실데이터로 잰다**(세99 포탈 은퇴분): 챕터 3장이 **실제로 싣고 있는** 좌표에
##      출구가 서고 풀길이 가장자리까지 닿나. 주입값으로만 재면 **배송되는 데이터가 비어도 그린**이고,
##      그건 「보스에서 남쪽까지 1950px 되돌아가는 판」이 조용히 굳는다는 뜻이다
##  [7] 🔴🔴 **입장부터 출발하는 실경로** — 방에 들어가 늘린 출구까지 걸어가 E를 꾹 눌러
##      `extraction_success`가 온다. 「기능이 돈다 ≠ 거기 갈 수 있다」(세97)의 그물이다
##
## ⚠ 못 잡는 것: 홀드 **3초가 적당한가** · 막대가 **읽히나** · [E] 눌림이 화면 덮는 Control을
##  뚫고 실제로 **닿는가** — 전부 F5·MCP 몫이다(액션 주입은 히트 테스트를 건너뛴다).
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

## 🔴 타일 소스 id는 **명시 상수로 박는다** — `boss_room`의 const에서 파생하면 둘 다 밀려도 통과한다.
const TILE_GRASS := 0
const TILE_FLOOR := 1
## 세88 풀길의 실측 규격(칸) — [6]의 회귀 대조가 이 둘을 손으로 든다.
const PATH_WIDTH_CELLS := 3
const PATH_ROWS := 3

## 🔴 그물용 홀드 길이 — 기본 3.0초로 재면 항목마다 3초씩 잡아먹는다. **balance를 흔드는 것 자체가
## [2]의 검출자**이기도 하다(길이가 balance에서 온다는 증명). 끝나면 원복한다.
const TEST_HOLD_SEC := 0.4

var failures: int = 0
var _bus = null
var _gs = null
var _db = null
var _scene = null
var _room = null
var _hold_before: float = 3.0


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("TEST_EXTRACT_HOLD_TIMEOUT — 90초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_scene = load("res://src/field/boss_room.tscn") as PackedScene
	_hold_before = _gs.balance.extract_hold_sec

	await _test_default_is_instant()
	await _test_balance_owns_the_length()
	await _test_hold_fills_then_fires()
	await _test_cancel_triggers()
	await _test_progress_is_on_screen()
	await _test_room_has_many_exits()
	await _test_walk_to_new_exit_and_leave()

	await _cleanup()

	if failures == 0:
		print("TEST_EXTRACT_HOLD_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_EXTRACT_HOLD_FAIL — %d개 실패" % failures)
		quit(1)


## 🔴🔴 뒷정리 = 계약이다 — [7]이 `extraction_success`를 쏘면 SaveManager가 **진짜 세이브를 쓴다**
## (`test_chapter_auto`가 같은 이유로 `wipe_save`를 한다). 테스트끼리 세이브 파일을 공유하므로
## 안 지우면 뒤에 도는 테스트의 기준 상태가 오염된다(세98 실측).
func _cleanup() -> void:
	_release_interact()
	_gs.balance.extract_hold_sec = _hold_before
	_gs.ui_modal_open = false
	_gs.bag.clear()
	_gs.pending_chapter = &""
	_free_room()
	await process_frame
	root.get_node("/root/SaveManager").wipe_save()


## [1] 🔴🔴 회귀 방어선 — **기본 0 = 지금 그대로 즉시**. 이 항목이 마을 전체를 지킨다(§6 S8).
##
## 셋을 같이 잰다:
##  ⓐ 새 `InteractZone`의 `hold_sec` 기본값이 0이다
##  ⓑ 🔴 **씬 파일 어디에도 `hold_sec`이 안 적혀 있다** — 홀드를 켜는 자리는 코드 한 곳
##    (`boss_room._wire_extract_zone`)이어야 한다. 씬에 흩뿌리면 마을 프롭 하나가 조용히 홀드가
##    되고(에러 0), 「어디서 켜졌나」를 찾는 데 다음 세션이 통째로 날아간다
##  ⓒ **실제로 눌러** 즉시 발동하는지 — ⓐ·ⓑ는 값만 보므로 「0인데도 홀드가 걸린다」를 못 잡는다
func _test_default_is_instant() -> void:
	print("[1] 회귀 방어선 — hold_sec 기본 0 · 씬에 0줄 · 누르면 즉시")
	var zone_script: GDScript = load("res://src/actors/interact_zone.gd")
	var probe = zone_script.new()
	_check(is_equal_approx(probe.hold_sec, 0.0),
		"InteractZone.hold_sec 기본 = 0.0 (실제 %.2f — 0이 아니면 마을 책상·문까지 홀드다)" % probe.hold_sec)
	probe.free()

	var scenes: Array = []
	_scan_tscn("res://src", scenes)
	_check(scenes.size() >= 10, "씬 스캔이 실제로 돌았다 (%d장 — 0~1이면 스캔이 깨져 자명 통과다)" % scenes.size())
	var baked: Array = []
	for p: String in scenes:
		var text := FileAccess.get_file_as_string(p)
		if text.contains("hold_sec"):
			baked.append(p)
	_check(baked.is_empty(),
		"🔴 씬 파일에 hold_sec을 구운 곳이 0개다 (실제 %s — 홀드는 코드 한 곳이 켠다)" % str(baked))

	# ⓒ 실제 눌림 — 마을 프롭(책상)을 그대로 세워 잰다. **즉시 경로가 살아 있나**가 회귀의 본체다.
	var rig := await _rig("res://src/props/desk.tscn")
	var fired: Array = []
	var cb := func() -> void: fired.append(1)
	rig.zone.interacted.connect(cb)
	_check(is_equal_approx(rig.zone.hold_sec, 0.0), "책상은 홀드가 꺼져 있다 (씬이 값을 안 쥔다)")
	_press_interact()
	await process_frame
	_check(fired.size() == 1, "🔴 홀드 0 = 누른 그 프레임에 발동한다 (실제 %d회)" % fired.size())
	_check(not rig.zone.is_holding(), "즉시 지점은 홀드 상태로 들어가지 않는다")
	_release_interact()
	rig.zone.interacted.disconnect(cb)
	_free_rig(rig)
	await process_frame


## [2] 🔴 **길이의 소유자는 `balance`다 — `hold_sec`은 「0이냐 아니냐」 스위치다**(설계 §2-4).
## 출구가 여럿이라 씬마다 초를 두면 F5로 조일 값이 흩어진다. 그래서 둘을 갈라 각각 흔든다:
##  ⓐ `hold_sec`을 10배로 키워도 **길이가 안 변한다**(숫자가 무시된다)
##  ⓑ `balance.extract_hold_sec`을 키우면 **길이가 변한다**(값이 거기서 온다)
## ⚠ ⓑ가 없으면 누가 `hold_sec`을 길이로 되돌려도 ⓐ만으론 못 잡는다(둘 다 같은 값이면 통과한다).
func _test_balance_owns_the_length() -> void:
	print("[2] 길이는 balance가 쥔다 — hold_sec은 스위치일 뿐")
	_gs.balance.extract_hold_sec = TEST_HOLD_SEC
	var rig := await _rig("res://src/props/exit_zone.tscn")

	# ⓐ 스위치 값을 10배로 — 길이가 그대로여야 한다.
	rig.zone.hold_sec = 10.0
	var t_switch := await _measure_hold(rig.zone)
	_check(t_switch > 0.0 and t_switch < TEST_HOLD_SEC * 2.5,
		"🔴 hold_sec=10.0이어도 %.2f초에 끝난다 (balance %.2f — 숫자를 길이로 읽으면 10초다)"
			% [t_switch, TEST_HOLD_SEC])

	# ⓑ balance를 2배로 — 길이가 따라와야 한다.
	rig.zone.hold_sec = 1.0
	_gs.balance.extract_hold_sec = TEST_HOLD_SEC * 2.0
	var t_bal := await _measure_hold(rig.zone)
	_check(t_bal > t_switch * 1.4,
		"🔴 balance를 2배로 하면 홀드가 길어진다 (%.2f → %.2f초)" % [t_switch, t_bal])

	_gs.balance.extract_hold_sec = TEST_HOLD_SEC
	_free_rig(rig)
	await process_frame


## [3] 🔴 다 차야 나간다 · **덜 차고 떼면 안 나간다** · 진행률이 오른다.
## ⚠ 「안 나간다」만 재면 *"홀드가 애초에 안 걸렸다"*와 구분이 안 된다 — 그래서 `is_holding()`과
##  진행률 증가를 **전제로 같이** 잰다(`player_caster.is_holding()`이 있는 이유와 같다).
func _test_hold_fills_then_fires() -> void:
	print("[3] 다 차야 나간다 / 덜 차고 떼면 안 나간다")
	_gs.balance.extract_hold_sec = TEST_HOLD_SEC
	var rig := await _rig("res://src/props/exit_zone.tscn")
	rig.zone.hold_sec = 1.0
	var fired: Array = []
	var cb := func() -> void: fired.append(1)
	rig.zone.interacted.connect(cb)

	# ── ⓐ 끝까지 버틴다
	_press_interact()
	await process_frame
	_check(rig.zone.is_holding(), "누르면 홀드에 들어간다 (전제)")
	_check(fired.is_empty(), "🔴 누른 즉시는 안 나간다 (실제 %d회)" % fired.size())
	var p_early: float = rig.zone.hold_progress()
	await _wait(TEST_HOLD_SEC * 0.5)
	var p_mid: float = rig.zone.hold_progress()
	_check(p_mid > p_early, "진행률이 오른다 (%.2f → %.2f)" % [p_early, p_mid])
	_check(fired.is_empty(), "🔴 절반에서는 아직 안 나간다 (실제 %d회)" % fired.size())
	await _wait(TEST_HOLD_SEC * 0.8)
	_check(fired.size() == 1, "🔴 다 버티면 나간다 — 1회 (실제 %d회)" % fired.size())
	_check(not rig.zone.is_holding(), "발동 뒤 홀드 상태가 안 남는다")
	_release_interact()
	await process_frame

	# ── ⓑ 덜 차고 뗀다 — 🔴 이게 D7의 심장이다(맞으면 취소·중간에 놓으면 무효)
	fired.clear()
	_press_interact()
	await process_frame
	_check(rig.zone.is_holding(), "다시 홀드에 들어갔다 (전제)")
	await _wait(TEST_HOLD_SEC * 0.35)
	_release_interact()
	await _wait(TEST_HOLD_SEC * 1.2)   # 다 찼을 시각을 **지나서** 본다
	_check(fired.is_empty(), "🔴🔴 덜 차고 떼면 안 나간다 (실제 %d회)" % fired.size())
	_check(not rig.zone.is_holding(), "뗀 뒤 홀드 상태가 안 남는다")
	_check(is_equal_approx(rig.zone.hold_progress(), 0.0),
		"홀드가 아니면 진행률 0 (실제 %.2f)" % rig.zone.hold_progress())

	rig.zone.interacted.disconnect(cb)
	_free_rig(rig)
	await process_frame


## [4] 🔴 취소 넷 — 피격 · 범위 이탈 · 모달 · 트리 이탈(씬 전환).
## 🔴🔴 **각각을 따로 잰다** — 하나로 묶으면 셋이 죽어도 하나가 살아 그린이다(설계 §6 S4:
##  취소가 안 걸려도 **화면은 정상**이라 F5로도 안 드러난다).
func _test_cancel_triggers() -> void:
	print("[4] 취소 넷 — 피격 · 범위 이탈 · 모달 · 트리 이탈")
	_gs.balance.extract_hold_sec = TEST_HOLD_SEC
	var rig := await _rig("res://src/props/exit_zone.tscn")
	rig.zone.hold_sec = 1.0
	var fired: Array = []
	var cb := func() -> void: fired.append(1)
	rig.zone.interacted.connect(cb)

	# ── ① 피격 — `EventBus.player_hurt`. 🔴 구독은 **홀드 중에만** 걸린다(상시 구독 금지).
	_press_interact()
	await process_frame
	_check(rig.zone.is_holding(), "① 홀드 시작 (전제)")
	_bus.player_hurt.emit(3.0, Vector2.ZERO)
	await process_frame
	_check(not rig.zone.is_holding(), "🔴 ① 맞으면 홀드가 끊긴다")
	_release_interact()
	await _settle_time_scale()   # 히트스톱(Engine.time_scale)이 풀릴 때까지 — 뒤 대기가 20배 느려진다
	await _wait(TEST_HOLD_SEC * 1.2)
	_check(fired.is_empty(), "🔴 ① 끊긴 홀드는 되살아나지 않는다 (실제 %d회)" % fired.size())

	# ── ② 범위 이탈 — 걸어 나가면 끊긴다.
	fired.clear()
	_press_interact()
	await process_frame
	_check(rig.zone.is_holding(), "② 홀드 시작 (전제)")
	rig.player.global_position = rig.zone.global_position + Vector2(900, 900)
	# ⚠ Area2D의 `body_exited`는 물리 스텝 **끝**에 나간다 — 텔레포트 직후 한두 프레임으로는
	#   아직 안 온다(실측: 2프레임이면 여전히 「범위 안」이었다). 여유를 두고 본다.
	for i in 6:
		await physics_frame
	_check(not rig.zone.player_in_range(), "② 실제로 범위를 벗어났다 (전제)")
	_check(not rig.zone.is_holding(), "🔴 ② 범위를 벗어나면 홀드가 끊긴다")
	_release_interact()
	rig.player.global_position = rig.zone.global_position
	for i in 6:
		await physics_frame
	await _wait(TEST_HOLD_SEC * 0.6)
	_check(fired.is_empty(), "🔴 ② 끊긴 뒤엔 안 나간다 (실제 %d회)" % fired.size())

	# ── ③ 모달 — `_unhandled_input`이 모달 중엔 아예 안 오므로 **폴링만이 이걸 잡는다**.
	fired.clear()
	_press_interact()
	await process_frame
	_check(rig.zone.is_holding(), "③ 홀드 시작 (전제)")
	_gs.ui_modal_open = true
	await process_frame
	_check(not rig.zone.is_holding(), "🔴 ③ 모달이 열리면 홀드가 끊긴다")
	_gs.ui_modal_open = false
	_release_interact()
	await _wait(TEST_HOLD_SEC * 0.6)
	_check(fired.is_empty(), "🔴 ③ 끊긴 뒤엔 안 나간다 (실제 %d회)" % fired.size())

	# ── ④ 트리 이탈(= 씬 전환) — 🔴🔴 **`_process` 카운트다운이어야만 통과한다.**
	# `SceneTreeTimer`로 짜면 노드가 트리 밖에 있어도 시간이 계속 흘러 **없는 씬에 탈출을 쏜다**.
	# 그래서 이 항목이 「폴링으로 짜라」(설계 §2-4)의 실제 측정자다.
	fired.clear()
	_press_interact()
	await process_frame
	_check(rig.zone.is_holding(), "④ 홀드 시작 (전제)")
	var parent: Node = rig.zone.get_parent()
	parent.remove_child(rig.zone)
	await _wait(TEST_HOLD_SEC * 2.0)
	_check(fired.is_empty(),
		"🔴🔴 ④ 트리를 벗어난 동안 카운트다운이 멎는다 (실제 %d회 — SceneTreeTimer면 여기서 나간다)"
			% fired.size())
	_release_interact()
	parent.add_child(rig.zone)
	await process_frame

	rig.zone.interacted.disconnect(cb)
	_free_rig(rig)
	await process_frame


## [5] 진행이 **화면에** 있다 — `Prompt` 문구에 막대가 붙고, 끝나면 원문이 돌아온다.
## ⚠ 「예쁜가」는 못 잰다(그건 vfx·F5 몫). 재는 것은 **「진행을 알 방법이 화면에 있나」** 하나다.
## 🔴 원문 복구를 같이 재는 이유: 안 되돌리면 다음에 다가갔을 때 **막대가 붙은 채 뜬다**(에러 0).
func _test_progress_is_on_screen() -> void:
	print("[5] 진행 표시 — Prompt에 막대가 붙고 끝나면 원문이 돌아온다")
	_gs.balance.extract_hold_sec = TEST_HOLD_SEC
	var rig := await _rig("res://src/props/exit_zone.tscn")
	rig.zone.hold_sec = 1.0
	var prompt: Label = rig.zone.get_node("Prompt")
	var base_text: String = prompt.text
	_check(base_text != "", "출구 프롭에 안내 문구가 있다 (전제)")

	_press_interact()
	await process_frame
	await _wait(TEST_HOLD_SEC * 0.6)
	var mid: String = prompt.text
	_check(mid.begins_with(base_text), "막대가 원문 **뒤에** 붙는다 (원문이 안 지워진다): '%s'" % mid)
	_check(mid != base_text, "🔴 홀드 중엔 문구가 달라진다 = 진행을 알 방법이 화면에 있다")
	_check(mid.contains("█"), "🔴 채워진 칸이 실제로 그려진다 (진행률이 문구에 실린다): '%s'" % mid)

	_release_interact()
	await process_frame
	await process_frame
	_check(prompt.text == base_text, "🔴 끊기면 원문이 돌아온다 (실제 '%s')" % prompt.text)

	_free_rig(rig)
	await process_frame


## [6] 🔴🔴 `boss_room` — 출구가 여럿이고 **전부** 배선되고 **전부** 풀길이 깔린다(설계 §6 S12).
##
## 🔴 **회귀 대조부터 한다**: `extract_points`가 비면 타일이 세88과 **칸 하나까지 같아야** 한다.
##  기대치를 옛 공식(`y >= to.y - PATH_ROWS` · `|x - exit_cx| <= 1`)으로 **손으로 든다** —
##  구현에서 파생하면 둘 다 밀려도 통과한다.
func _test_room_has_many_exits() -> void:
	print("[6] 출구 여럿 — 전부 _extract에 이어지고 전부 풀길이 깔린다")
	var ch = _db.get_chapter(&"ch1")
	var before: Array[Vector2] = ch.extract_points.duplicate()

	# ── ⓐ 🔴🔴 **배송되는 실데이터**로 먼저 잰다 (세99 — 포탈 은퇴로 이 축이 심장이 됐다).
	# 주입값으로만 재면 `data/chapters/*.tres`가 **비어 있어도 전부 그린**이고, 그러면 실게임은
	# 세98 그대로 「남쪽 출구 하나」다 = 보스 자리에서 1950px 되돌아가는 판이 조용히 굳는다.
	# ⚠ 개수는 안 박는다(F5 튜닝값) — **「한 장이라도 실려 있나」 + 「실린 자리마다 길이 보이나」**만.
	for cid: StringName in [&"ch1", &"ch2", &"ch3"]:
		var c = _db.get_chapter(cid)
		if c == null:
			_check(false, "%s가 로드됐다" % cid)
			continue
		_check(not c.extract_points.is_empty(),
			"🔴🔴 %s가 늘린 출구 좌표를 싣고 있다 (실제 %d개 — 0이면 실게임은 남쪽 하나뿐이다)"
				% [cid, c.extract_points.size()])
		await _fresh(cid)
		var real_exits := _exits()
		_check(real_exits.size() == 1 + c.extract_points.size(),
			"%s: 씬 남쪽 1 + 좌표 %d = 출구 %d개가 실제로 섰다 (실제 %d)"
				% [cid, c.extract_points.size(), 1 + c.extract_points.size(), real_exits.size()])
		var rg := _grid()
		for z in real_exits:
			# 🔴 서·동·북 방향은 세99가 처음이다 — `_path_rect`의 방향 선택이 그쪽에서도 도는지
			#  **실좌표로** 확인한다(남쪽만 맞는 구현은 옛 「마지막 세 줄」 공식으로도 통과한다).
			var zc := _cell_of(z, rg)
			var seeds := _grass_seeds_at(z, rg)
			_check(not seeds.is_empty(),
				"%s: 출구 %s 발밑에 풀길이 깔렸다 (실좌표 — 0이면 나갈 데가 있는 줄 모른다)"
					% [cid, z.position])
			var reach := _grass_edge_reach(seeds, zc, rg)
			_check(reach >= 0,
				"%s: 출구 %s의 풀이 방 가장자리까지 이어진다 (실좌표)" % [cid, z.position])
			_check(reach >= 0 and reach <= _edge_slack(zc, rg),
				"🔴🔴 %s: 출구 %s의 길이 **그 자리에서** 밖으로 나간다 (가장자리까지 %d칸 · 허용 %d — 크면 엉뚱한 가장자리로 샌 것)"
					% [cid, z.position, reach, _edge_slack(zc, rg)])

	# ── ⓑ 비면 지금 동작 (회귀 0)
	ch.extract_points = [] as Array[Vector2]
	await _fresh(&"ch1")
	var exits := _exits()
	_check(exits.size() == 1, "extract_points가 비면 출구 1개 (실제 %d — 세98 그대로)" % exits.size())
	var g := _grid()
	var cx: int = floori(exits[0].position.x / float(g.ts.x))
	var half: int = (PATH_WIDTH_CELLS - 1) / 2
	var wrong := 0
	for y in range(g.from.y, g.to.y):
		for x in range(g.from.x, g.to.x):
			var want_grass: bool = y >= g.to.y - PATH_ROWS and absi(x - cx) <= half
			var got_grass: bool = _tiles().get_cell_source_id(Vector2i(x, y)) == TILE_GRASS
			if want_grass != got_grass:
				wrong += 1
	_check(wrong == 0, "🔴 남쪽 풀길이 세88과 칸 하나까지 같다 (어긋난 칸 %d)" % wrong)

	# ── ⓒ 늘린다 — 서쪽 가장자리 하나 + 남서 하나
	ch.extract_points = [Vector2(-1150.0, 0.0), Vector2(-700.0, 660.0)] as Array[Vector2]
	await _fresh(&"ch1")
	exits = _exits()
	_check(exits.size() == 3, "extract_points 2개 → 출구 3개 (실제 %d)" % exits.size())
	# 🔴 나가는 길은 **전부 `&"exit"`**이다 — 세99에 `&"portal"`이 은퇴해 zone_id가 갈릴 이유가 없다.
	# **`_extract`에 이어진 지점 수**로 대조한다(zone_id 무관): 다른 이름으로 새 길을 세우면 갈린다.
	# ⚠ 「지점 수 == 출구 수」로 재지 마라 — 단계 3의 지점이 자기 InteractZone을 들면 거짓 빨강이다.
	_check(_extract_wired_count() == exits.size(),
		"🔴 `_extract`에 이어진 지점이 출구뿐이다 (이어진 %d · 출구 %d — 다른 zone_id로 새면 갈린다)"
			% [_extract_wired_count(), exits.size()])
	var wired := 0
	var held := 0
	for z in exits:
		_check(z.zone_id == &"exit", "출구 zone_id가 &\"exit\"이다 (실제 %s)" % z.zone_id)
		for c in z.interacted.get_connections():
			var cal: Callable = c["callable"]
			if cal.get_object() == _room and cal.get_method() == "_extract":
				wired += 1
				break
		if z.hold_sec > 0.0:
			held += 1
	# 🔴 **안 이으면 E가 먹히는데 아무 일도 안 나고 가방이 조용히 증발한다** — 에러가 0인 자리다.
	_check(wired == exits.size(),
		"🔴🔴 출구 %d개가 **전부** _extract에 이어졌다 (실제 %d)" % [exits.size(), wired])
	_check(held == exits.size(),
		"🔴 출구 %d개가 **전부** 홀드다 (실제 %d — 하나만 즉시여도 D7이 거기로 샌다)" % [exits.size(), held])

	# 🔴 풀길 — 늘린 출구마다 **자기 자리에** 깔린다(남쪽 끝에만 깔리면 D1이 통째로 무효다).
	# 🔴🔴 **셋을 같이 잰다 — 앞의 둘만으로는 검출력이 얕다**(세99 뮤테이션 실측 2회):
	#  ⓐ「발밑에 있다」만 → 방향 선택을 되돌려도 **0건**. ⓑ「+ 가장자리에 닿는다」(bool)만 →
	#  **여전히 0건**이었다: 강제로 남쪽으로 그은 통로가 발밑에서 시작해 남쪽 끝까지 이어지니
	#  「닿긴 닿는다」가 참이 된다. 화면에선 방을 세로로 가로지르는 얼룩인데 에러가 0이다.
	#  → ⓒ **닿는 자리가 그 출구 근처인가**(거리)를 재고서야 빨개진다(`_grass_edge_reach`).
	g = _grid()
	for z in exits:
		var zc := _cell_of(z, g)
		var seeds := _grass_seeds_at(z, g)
		_check(not seeds.is_empty(),
			"🔴🔴 출구 %s 발밑에 풀길이 깔렸다 (풀 칸 %d — 0이면 나갈 데가 있는 줄 모른다)"
				% [z.position, seeds.size()])
		var reach := _grass_edge_reach(seeds, zc, g)
		_check(reach >= 0,
			"🔴🔴 출구 %s의 풀이 **방 가장자리까지 이어진다** (안 이어지면 나가는 길이 아니라 얼룩이다)"
				% z.position)
		_check(reach >= 0 and reach <= _edge_slack(zc, g),
			"🔴🔴 출구 %s의 길이 **그 자리에서** 밖으로 나간다 (가장자리까지 %d칸 · 허용 %d)"
				% [z.position, reach, _edge_slack(zc, g)])

	# 🔴 sticky 목표 줄이 D2 뒤의 **유효한 지시**인가 (§6 S13).
	var line: String = _room.get_node("Hud/Hud").say_line()
	_check(not line.contains("쓰러뜨려라"),
		"🔴 목표 줄이 「보스를 쓰러뜨려라」가 아니다 (탈출이 목표다): '%s'" % line)
	_check(line.contains("나가"), "목표 줄이 **나가는 것**을 목표로 말한다: '%s'" % line)
	_check(line.contains("다음 챕터"),
		"목표 줄이 「보스는 선택이지만 진행하려면 필요」도 같이 말한다: '%s'" % line)

	ch.extract_points = before   # 🔴 주입 원상복구 — 안 되돌리면 뒤 테스트가 오염된다


## [7] 🔴🔴 **입장부터 출발하는 실경로** — 「기능이 돈다 ≠ 거기 갈 수 있다」(세97).
## 방에 들어가 **늘린 출구**까지 걸어가 [E]를 꾹 눌러 `extraction_success`가 오는지 잰다.
## ⚠ [6]은 배선을 **값으로** 확인할 뿐이라, 홀드가 죽으면 그린인 채 실경로만 막힌다.
func _test_walk_to_new_exit_and_leave() -> void:
	print("[7] 입장 → 늘린 출구까지 걸어가 [E] 꾹 → extraction_success")
	_gs.balance.extract_hold_sec = TEST_HOLD_SEC
	var ch = _db.get_chapter(&"ch1")
	var before: Array[Vector2] = ch.extract_points.duplicate()
	ch.extract_points = [Vector2(-700.0, 660.0)] as Array[Vector2]
	await _fresh(&"ch1")

	var target = null
	for z in _exits():
		if z.position.distance_to(Vector2(-700.0, 660.0)) < 1.0:
			target = z
	_check(target != null, "늘린 출구가 실제로 방에 섰다 (전제)")
	if target == null:
		ch.extract_points = before
		return

	_gs.bag.clear()
	var banked: int = _gs.get_count(&"mat_slime_core")
	_gs.add_to_bag(&"mat_slime_core", 2)
	var got: Array = []
	var cb := func() -> void: got.append(1)
	_bus.extraction_success.connect(cb)

	# 걸어간다 — 실게임처럼 **범위 안에 들어가야** 안내가 뜨고 E가 먹힌다.
	var player = get_first_node_in_group("player")
	player.global_position = target.global_position
	await physics_frame
	await physics_frame
	_check(target.player_in_range(), "출구 범위 안에 들어갔다 (전제 — layer 64 / mask 2)")

	_press_interact()
	await process_frame
	_check(target.is_holding(), "🔴 [E]를 누르니 홀드가 걸린다")
	_check(got.is_empty(), "🔴 누른 즉시는 안 나간다 (실제 %d회)" % got.size())
	await _wait(TEST_HOLD_SEC * 1.6)
	_release_interact()
	await process_frame
	_check(got.size() == 1, "🔴🔴 다 버티면 extraction_success 1회 (실제 %d)" % got.size())
	_check(_gs.get_count(&"mat_slime_core") == banked + 2,
		"늘린 출구로 나가도 가방이 창고로 간다 (%d → %d)" % [banked, _gs.get_count(&"mat_slime_core")])
	_bus.extraction_success.disconnect(cb)
	ch.extract_points = before


# ── 도구 ──────────────────────────────────────────────────────────────────────

## 🔴 [E]를 **쥔다** — 둘 다 필요하다:
##  • `Input.action_press` = 홀드가 「뗐나」를 보는 **폴링** 상태(선례 = `test_spell_cast_auto`)
##  • `InputEventAction` 주입 = `_unhandled_input`이 **시작**을 받는 경로(선례 = `test_base_auto._push_action`)
## ⚠ 액션 주입은 **마우스 히트 테스트를 건너뛴다** — `mouse_filter`가 [E]를 먹는지는 F5 몫이다.
## ⚠ **누른 채 끝내지 마라** — 액션 상태는 전역이라 뒤 테스트가 통째로 홀드에 갇힌다.
func _press_interact() -> void:
	Input.action_press(&"interact")
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	root.push_input(ev)


func _release_interact() -> void:
	Input.action_release(&"interact")


## 홀드 한 번의 실제 소요 시간(초)을 잰다 — [2]가 「길이가 어디서 오나」를 이걸로 가른다.
func _measure_hold(zone) -> float:
	var fired: Array = []
	var cb := func() -> void: fired.append(1)
	zone.interacted.connect(cb)
	var t0 := Time.get_ticks_msec()
	_press_interact()
	var guard := 0
	while fired.is_empty() and guard < 600:   # 10초 상한 (60fps 기준)
		await process_frame
		guard += 1
	var dt := float(Time.get_ticks_msec() - t0) / 1000.0
	_release_interact()
	zone.interacted.disconnect(cb)
	if fired.is_empty():
		return -1.0
	return dt


## 플레이어 + 지점 한 쌍을 세운다 — 씬 전환이 안 끼어들어 홀드 기계만 깨끗하게 잰다.
## ⚠ 실경로(방 안에서 걸어가 나가기)는 [7]이 따로 잰다 — 이 리그로 대신하지 마라(세97 S7).
func _rig(zone_path: String) -> Dictionary:
	var holder := Node2D.new()
	root.add_child(holder)
	var player = (load("res://src/actors/player.tscn") as PackedScene).instantiate()
	var zone = (load(zone_path) as PackedScene).instantiate()
	holder.add_child(zone)
	holder.add_child(player)
	await process_frame
	await physics_frame
	await physics_frame
	return {"holder": holder, "zone": zone, "player": player}


func _free_rig(rig: Dictionary) -> void:
	var holder: Node = rig["holder"]
	if is_instance_valid(holder):
		holder.free()


## 히트스톱이 풀릴 때까지 — `player_hurt`를 쏘면 `juice.gd`가 `Engine.time_scale`을 0.05로 떨군다.
## 🔴 안 기다리면 뒤의 `create_timer` 대기가 **20배 느려져** 타임아웃으로 조용히 죽는다.
func _settle_time_scale() -> void:
	var guard := 0
	while Engine.time_scale < 0.99 and guard < 600:
		await process_frame
		guard += 1


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


## 방 하나를 새로 띄운다 (`test_chapter_auto._fresh` 계약 그대로 — 방을 남기면 플레이어가 둘이 된다).
func _fresh(chapter_id: StringName) -> void:
	_free_room()
	_gs.pending_chapter = chapter_id
	_room = _scene.instantiate()
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame


func _free_room() -> void:
	if _room != null and is_instance_valid(_room):
		_room.free()
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.free()
	_room = null
	current_scene = null


func _tiles() -> TileMapLayer:
	return _room.get_node("TileGround") as TileMapLayer


## `boss_room._fill_tiles`와 **같은 방식으로** 셀 범위를 파생한다 — 좌표를 베끼면 방을 키울 때
## 이 그물만 낡아 거짓 빨강이 난다(세88 카메라 검사가 Ground rect를 대조하는 것과 같은 결).
func _grid() -> Dictionary:
	var ground: ColorRect = _room.get_node("Ground")
	var ts: Vector2i = _tiles().tile_set.tile_size
	var rect := Rect2(ground.position, ground.size).grow(-float(ts.x))
	return {
		"ts": ts,
		"from": Vector2i(floori(rect.position.x / ts.x), floori(rect.position.y / ts.y)),
		"to": Vector2i(ceili(rect.end.x / ts.x), ceili(rect.end.y / ts.y)),
	}


## 출구 발밑 3×3에서 풀 칸을 모은다 — 번짐(`_grass_reaches_edge`)의 씨앗.
## ⚠ 「발밑에 있다」만으로는 검출력이 얕다(세99 실측: 방향 선택 뮤테이션을 **0건** 잡았다) —
##  반드시 `_grass_reaches_edge`와 **짝으로** 써라.
func _grass_seeds_at(zone, g: Dictionary) -> Array[Vector2i]:
	var ts: Vector2i = g["ts"]
	var from: Vector2i = g["from"]
	var to: Vector2i = g["to"]
	var c := Vector2i(floori(zone.position.x / float(ts.x)), floori(zone.position.y / float(ts.y)))
	var seeds: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell := Vector2i(clampi(c.x + dx, from.x, to.x - 1), clampi(c.y + dy, from.y, to.y - 1))
			if _tiles().get_cell_source_id(cell) == TILE_GRASS:
				seeds.append(cell)
	return seeds


## 씨앗 칸에서 **풀만 밟고** 번져 닿은 방 가장자리 칸 중 **출구에서 가장 가까운 것의 거리**(체비셰프).
## 못 닿으면 −1. 🔴 「나가는 길」의 구현 무관 정의다 — 어느 가장자리인지·통로를 어떤 모양으로 그리는지는
## 구현 선택이라 안 따지고, 재는 것은 **「그 출구 자리에서 밖으로 이어지나」** 하나다.
##
## 🔴🔴 **왜 bool이 아니라 거리인가 — 세99 뮤테이션 실측**. `_path_rect`의 방향 선택을 옛
##  「남쪽 마지막 세 줄」로 되돌려도 **bool 판정은 전 항목 그린이었다**: 강제로 남쪽으로 그은 통로가
##  출구 발밑에서 시작해 남쪽 끝까지 이어지니 「닿긴 닿는다」가 참이 된다. 화면에서는 **방을 세로로
##  가로지르는 얼룩**이고 서·북 출구는 여전히 「나갈 데가 없는」 자리인데 에러가 0이다.
##  → 거리로 재면 북쪽 출구가 **31칸** 떨어진 남쪽 끝으로만 나가는 게 드러난다(→ `_edge_slack`).
func _grass_edge_reach(seeds: Array[Vector2i], cell: Vector2i, g: Dictionary) -> int:
	var from: Vector2i = g["from"]
	var to: Vector2i = g["to"]
	var best := -1
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = seeds.duplicate()
	for s in queue:
		seen[s] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if c.x == from.x or c.x == to.x - 1 or c.y == from.y or c.y == to.y - 1:
			var d: int = maxi(absi(c.x - cell.x), absi(c.y - cell.y))
			if best < 0 or d < best:
				best = d
			continue   # 가장자리 밖으로는 안 번진다
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + step
			if n.x < from.x or n.x >= to.x or n.y < from.y or n.y >= to.y or seen.has(n):
				continue
			if _tiles().get_cell_source_id(n) != TILE_GRASS:
				continue
			seen[n] = true
			queue.append(n)
	return best


## 그 출구가 **자기 자리에서** 밖으로 나가는가의 허용 거리(칸).
## 🔴 **값을 박지 않는다** — 출구에서 「가장 가까운 방 가장자리」까지의 실제 거리에서 파생시키고
##  통로 폭(`half`)과 격자 반올림 한 칸만 여유를 준다. 그래서 출구를 방 한복판에 두든 가장자리에
##  붙이든 거짓 빨강이 안 나고, **엉뚱한 가장자리로 새는 것만** 잡힌다.
func _edge_slack(cell: Vector2i, g: Dictionary) -> int:
	var from: Vector2i = g["from"]
	var to: Vector2i = g["to"]
	var half: int = (PATH_WIDTH_CELLS - 1) / 2
	var nearest: int = mini(mini(cell.x - from.x, to.x - 1 - cell.x),
		mini(cell.y - from.y, to.y - 1 - cell.y))
	return maxi(nearest, 0) + half + 1


func _cell_of(zone, g: Dictionary) -> Vector2i:
	var ts: Vector2i = g["ts"]
	return Vector2i(floori(zone.position.x / float(ts.x)), floori(zone.position.y / float(ts.y)))


func _exits() -> Array:
	var out: Array = []
	for z in _interact_zones():
		if z.zone_id == &"exit":
			out.append(z)
	return out


func _interact_zones() -> Array:
	var out: Array = []
	for z in get_nodes_in_group("interact_zones"):
		if not z.is_queued_for_deletion():
			out.append(z)
	return out


## 🔴 방 안에서 **`_extract`에 이어진** 지점 수 — 「나가는 길이 몇 개인가」의 **zone_id 무관** 정의다.
## `_zone(&"portal")`처럼 값을 박아 재면 **그 값만 피해 되살려도 통과한다**(세99 뮤테이션 실측).
func _extract_wired_count() -> int:
	var n := 0
	for z in _interact_zones():
		for c in z.interacted.get_connections():
			var cal: Callable = c["callable"]
			if cal.get_object() == _room and cal.get_method() == "_extract":
				n += 1
				break
	return n


## `src/` 아래 `.tscn`을 전부 모은다 — 🔴 **목록을 하드코딩하지 않는다**(하면 새 씬이 그물에서
## 빠지고, `hold_sec`을 씬에 굽는 실수는 정확히 **새 씬을 만들 때** 일어난다).
func _scan_tscn(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if d.current_is_dir():
			if not entry.begins_with("."):
				_scan_tscn(dir_path.path_join(entry), out)
		elif entry.ends_with(".tscn"):
			out.append(dir_path.path_join(entry))
		entry = d.get_next()
	d.list_dir_end()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
