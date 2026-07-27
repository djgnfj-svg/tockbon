extends SceneTree
## 시전 상태기계 자동 검증 (세98 — 「시전 연출」 원자 ②) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_spell_cast_auto.gd
## 전 항목 통과 시 "TEST_SPELL_CAST_OK" 출력 후 종료 코드 0.
## 정본 = `docs/takbon-design/spell_cast_visual_design.md`(§5 시그널 · §8 조용히 깨질 자리 · §10 검증).
##
## 🔴 왜 새 파일인가: 좌클릭이 **즉시 발사**에서 **시전 → duration → 발사**로 바뀌었는데, 기존
## 그물은 전부 「emit이 왔나」만 세서 **시전 시작과 완료를 구분하지 못한다**. 그래서 아래 다섯은
## 기존 스위트가 전부 그린인 채로 깨질 수 있는 자리들이다(설계 ⓒⓖⓚⓛⓝ).
##
## 🔴🔴 **세98 후반(확정 ⑦): 「duration이 차면 자동 발사」는 더 이상 계약이 아니다.**
## 좌클릭을 **떼면** 나간다 — 다 차면 원은 **열린 채 머문다**. 그래서 [8]~[11]이 붙었고, 그중
## **[8]이 이번 변경의 핵심 검출자**다(자동 발사로 되돌리면 [8]만 빨개진다 — 나머지는 그린이다).
## ⚠ **[1]~[7]이 그대로 도는 이유**: `fire()`를 프로그램에서 부르면 버튼이 안 눌려 있어
##   **「이미 뗀 것」**으로 잡히고, 그러면 발사 시점이 옛 계약과 **정확히 같다**(다 차는 순간).
##   즉 기존 그물은 「일찍 뗀 경우」를 재고 있는 셈이다 — 홀드 자체는 [8]~[11]만 잰다.
##
## [1] 시전이 걸리고 duration 뒤에 나간다 — started 즉시 1회 · requested는 그 뒤 1회
##     + 🔴 **origin 셋이 같다**(started == requested == 지팡이 끝) = 총구 단일 소스가 시전
##       시작에서만 갈라지지 않는다(ⓛ). ⚠ `test_floating_wand_auto`는 started만 재므로 **여기만
##       started↔requested 갈라짐을 잡는다**
## [2] 🔴 스냅샷(ⓖ) — 시전 중 슬롯 내용을 갈아치워도 **시작할 때 그 진**이 나간다 + 슬롯 전환 차단
## [3] duration이 **점수에 단조 증가** — 등급이 시전 시간을 판다(확정 ④)
## [4] 시전 중 재발사 차단(ⓒ) — 없으면 바닥 마법진이 겹쳐 쌓이고 마나가 연타로 녹는다
## [5] 🔴 빈 슬롯·마나 부족 → **`ring_cast_started` 0회**(ⓚ). ⚠ `test_base_auto [7-b]`는
##     `ring_cast_requested`만 세므로 **가드보다 started가 먼저 나가는 회귀를 못 잡는다**
## [6] 🔴 구르기가 시전을 끊는다(ⓝ) — requested 0회 **인데 마나는 깎여 있다**(ⓓ).
##     ⚠ 「0회」만 재면 *"시전이 애초에 안 걸렸다"*와 구분이 안 돼서 마나·취소신호·구르기 성립을 같이 잰다
## [7] 모달·책이 시전을 끊는다(ⓕ) — `enabled=false`·`ui_modal_open`은 입력만 막지 지연 emit은 안 막는다
## [8] 🔴🔴 **다 차도 안 뗐으면 안 나간다 · 떼면 나간다**(확정 ⑦) — 이 파일의 핵심 검출자
## [9] 🔴 **일찍 떼면 「다 차는 순간」 나간다** — 더 일찍은 안 나간다 = 최소 시전 시간 보장(확정 ④)
## [10] 🔴🔴 **홀드 길이가 위력에 1도 영향을 주지 않는다** — 각하된 대안(홀드=위력)의 재발 감시자.
##      ⚠ 이게 없으면 나중에 누가 "홀드 보너스"를 넣어도 **아무 그물도 안 빨개진다**
## [11] 홀드 중 구르기 → 취소 — 취소 조건이 **홀드 구간까지** 이어진다(다 채워 놓고 굴러도 취소다)
##
## 🔴 헤드리스가 못 보는 것: 발밑 마법진이 **보이나**·시전이 **답답한가**·감속이 **위험으로 읽히나**·
##   **다 찬 원이 「이제 놔도 된다」로 읽히나**(홀드 구간의 그림 — 지금은 그냥 켜져 있을 뿐이다).
##   전부 F5·MCP 몫이다(설계 §10).
##
## 🔴 「쥐고 있다」는 **`Input.action_press`로 만든다** — 캐스터가 뗌을 **폴링**으로 보기 때문이다
##   (이벤트로 받으면 Control이 먹거나 포커스가 빠질 때 영원히 홀드에 갇힌다 = `_tick_cast` 머리말).
##   선례 = [6]의 `dash` 주입. ⚠ **누른 채 끝내지 마라** — 뒤 검사의 `fire()`가 전부 홀드에 갇힌다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

var failures: int = 0
var _bus = null
var _gs = null
var _player = null
var _caster = null
var _wand = null
var _WAND := 2   ## Enums.ItemKind.WAND — -s 컴파일 함정 회피용 리터럴(런타임 검산으로 방어)


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		print("TEST_SPELL_CAST_TIMEOUT — 40초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_gs = root.get_node("/root/GameState")
	var enums_script = load("res://src/core/enums.gd")
	_check(enums_script.ItemKind.WAND == _WAND,
		"리터럴 WAND(%d) == Enums.ItemKind.WAND(%d)" % [_WAND, enums_script.ItemKind.WAND])

	_player = (load("res://src/actors/player.tscn") as PackedScene).instantiate()
	root.add_child(_player)
	await process_frame
	_caster = _player.get_node("Caster")
	_wand = _player.get_node_or_null("FloatingWand")
	_check(_wand != null, "player.tscn에 FloatingWand가 있다 (총구 단일 소스)")

	# 🔴 지팡이를 끼운다 — 총구가 몸 중심 폴백이 아니라 **지팡이 끝**이어야 ⓛ이 자명 통과가 안 된다.
	_gs.equipment[_WAND] = &"wand_basic"
	_bus.equipment_changed.emit()
	await process_frame
	await process_frame
	# 🔴 `debug_free_cast`는 헤드리스에서도 true다("editor" 피처 — 세62 함정) → 꺼야 마나가 닳는다.
	_gs.debug_free_cast = false

	await _test_cast_then_fire()
	await _test_snapshot_beats_slot_swap()
	await _test_duration_rises_with_score()
	await _test_no_double_cast()
	await _test_guards_come_before_started()
	await _test_roll_cancels_cast()
	await _test_modal_cancels_cast()
	await _test_hold_waits_for_release()
	await _test_early_release_fizzles()
	await _test_hold_does_not_boost_power()
	await _test_roll_cancels_during_hold()

	await _restore_state()
	_finish()


## 🔴🔴 **뒷정리 = 계약이다** — `-s` 테스트는 세이브 뿌리가 `user://save_test`로 격리돼 있을 뿐
## **테스트끼리는 그 파일을 공유한다**. `equipment_changed`는 자동 저장 트리거라(세84 #1), 지팡이를
## 낀 채 끝내면 그 상태가 세이브에 남고 **나중에 도는 테스트가 그걸 로드해 「맨손 기준값」을
## 오염시킨다**(실측: `test_workshop_auto`의 「지팡이 해제하면 원복」 2건이 그 형태로 빨개진다).
## ⚠ 저장은 `call_deferred`라 **프레임을 흘려야** 깨끗한 상태가 실제로 쓰인다.
func _restore_state() -> void:
	_release_click()   # ⚠ 누른 채 프로세스를 끝내지 않는다 (액션 상태는 전역이다)
	_caster.cancel_cast()
	_gs.ring_equipped[0] = null
	_gs.equipment.erase(_WAND)
	_bus.equipment_changed.emit()
	_gs.mana = _gs.mana_max()
	await process_frame
	await process_frame


## [1] 시전이 걸리고 duration 뒤에 나간다 + origin 셋이 같다(ⓛ).
func _test_cast_then_fire() -> void:
	print("[1] 좌클릭 → 시전(started) → duration → 발사(requested) · origin이 안 갈라진다")
	_arm(_design(1.0, &"jin_one"))
	var started: Array = []
	var fired: Array = []
	var s_cb := func(a: Dictionary, origin: Vector2, duration: float) -> void:
		started.append({"a": a, "origin": origin, "dur": duration})
	var f_cb := func(a: Dictionary, origin: Vector2, aim: Vector2) -> void:
		fired.append({"a": a, "origin": origin, "aim": aim})
	_bus.ring_cast_started.connect(s_cb)
	_bus.ring_cast_requested.connect(f_cb)

	_caster.fire()
	# ⚠ **같은 줄에서** 잰다 — started는 클릭과 동기다(그래서 총구 그물이 살았다).
	_check(started.size() == 1, "fire() 즉시 ring_cast_started 1회 (실제 %d)" % started.size())
	_check(fired.is_empty(), "그 순간엔 ring_cast_requested 0회 = 아직 탄이 안 나갔다 (실제 %d)" % fired.size())
	if started.is_empty():
		_bus.ring_cast_started.disconnect(s_cb)
		_bus.ring_cast_requested.disconnect(f_cb)
		return
	var dur: float = float(started[0]["dur"])
	_check(dur > 0.0, "duration이 0보다 크다 = 즉발이 아니다 (%.3fs)" % dur)
	# 🔴 지팡이 끝과 같은가 — 총구 단일 소스(세65)가 시전 시작에서 갈라지면 여기서 잡힌다.
	var tip: Vector2 = _wand.muzzle_position()
	_check(Vector2(started[0]["origin"]).distance_to(tip) < 0.5,
		"started.origin == 지팡이 끝 (dist=%.1f)" % Vector2(started[0]["origin"]).distance_to(tip))

	await _wait(dur + 0.2)
	_check(fired.size() == 1, "duration 뒤 ring_cast_requested 정확히 1회 (실제 %d)" % fired.size())
	if fired.size() == 1:
		# 🔴🔴 **세98 F5가 이 계약을 뒤집었다** — 예전엔 「started와 requested가 같은 origin」이었는데,
		# 사용자가 실물에서 *"처음에 기를 모은 데에서 발사됨, 캐릭터가 아니라"*로 잡아냈다.
		# 이제 **requested는 「지금」의 총구를 다시 본다** — 시전 중 걸어간 만큼 갈라지는 게 정상이다.
		# ⚠ 그래서 여기서 재는 건 「같다」가 아니라 **「지금 총구와 같다」**이다.
		#   (started 쪽 총구 계약은 위 [1]의 `started.origin == 지팡이 끝`이 계속 진다.)
		# ⚠ 허용치가 [1]의 0.5px보다 넉넉한 이유: **지팡이가 둥둥 뜬다**(bob) — 시전이 흐르는 동안
		#   총구가 몇 px 오르내린다. 0.5로 재면 bob 위상에 따라 **무작위로 빨개진다**(실측 1.7px).
		_check(Vector2(fired[0]["origin"]).distance_to(_wand.muzzle_position()) < 6.0,
			"requested.origin == **지금** 지팡이 끝 (%s vs %s)"
			% [str(fired[0]["origin"]), str(_wand.muzzle_position())])
	_check(not _caster.is_casting(), "발사 후엔 시전 상태가 남지 않는다")
	_bus.ring_cast_started.disconnect(s_cb)
	_bus.ring_cast_requested.disconnect(f_cb)


## [2] 🔴 스냅샷(ⓖ) — 시전 중 슬롯을 갈아치워도 **시작할 때 그 진**이 나간다.
## 뮤테이션: emit 시점에 `GameState.ring_equipped[_slot]`을 다시 읽게 되돌리면 여기가 빨개진다.
func _test_snapshot_beats_slot_swap() -> void:
	print("[2] 시전 중 슬롯을 바꿔치기해도 **시작할 때 그 진**이 나간다 (스냅샷 + 슬롯 전환 차단)")
	_arm(_design(1.0, &"jin_before"))
	var fired: Array = []
	var f_cb := func(a: Dictionary, _o: Vector2, _d: Vector2) -> void: fired.append(a)
	_bus.ring_cast_requested.connect(f_cb)

	_caster.fire()
	var dur: float = _cast_time_of(1.0)
	# 시전 중 슬롯 0의 내용을 통째로 갈아치우고, 슬롯 전환도 시도한다.
	_gs.ring_equipped[0] = _design(1.0, &"jin_after")
	_gs.ring_equipped[1] = _design(1.0, &"jin_other")
	_caster.select_slot(1)
	_check(_caster.slot() == 0, "시전 중 슬롯 전환이 막힌다 (지금 슬롯 %d)" % _caster.slot())

	await _wait(dur + 0.2)
	_check(fired.size() == 1, "한 발만 나간다 (실제 %d)" % fired.size())
	if fired.size() == 1:
		_check(StringName(fired[0].get("jin", &"")) == &"jin_before",
			"나간 진 = 시전을 시작할 때의 그것 (실제 %s — after면 emit 시점에 슬롯을 다시 읽은 것)"
			% str(fired[0].get("jin", &"")))
	_bus.ring_cast_requested.disconnect(f_cb)
	_gs.ring_equipped[1] = null


## [3] duration이 점수에 **단조 증가** — 등급이 시전 시간을 판다(확정 ④).
## 뮤테이션: `cast_time_of`를 상수로 고정하면 여기가 빨개진다.
func _test_duration_rises_with_score() -> void:
	print("[3] duration이 점수에 단조 증가 — 잘 조립할수록 오래 걸린다")
	var durs: Array = []
	for score: float in [0.0, 0.85, 1.0]:
		_arm(_design(score, &"jin_dur"))
		var got := {"dur": -1.0}
		var cb := func(_a: Dictionary, _o: Vector2, duration: float) -> void: got["dur"] = duration
		_bus.ring_cast_started.connect(cb)
		_caster.fire()
		_bus.ring_cast_started.disconnect(cb)
		_caster.cancel_cast()   # 🔴 끊고 다음 점수로 — 안 끊으면 다음 fire()가 연사 차단에 걸린다
		durs.append(float(got["dur"]))
	_check(durs[0] > 0.0, "무난한 진도 시전 시간이 있다 (%.3fs)" % durs[0])
	_check(durs[1] > durs[0], "괜찮은 진 > 무난한 진 (%.3f > %.3f)" % [durs[1], durs[0]])
	_check(durs[2] > durs[1], "퍼펙트 > 괜찮음 (%.3f > %.3f)" % [durs[2], durs[1]])


## [4] 시전 중 재발사 차단(ⓒ).
func _test_no_double_cast() -> void:
	print("[4] 시전 중 재발사 차단 — 연타해도 시전은 하나다")
	_arm(_design(1.0, &"jin_rapid"))
	var started: Array = []
	var cb := func(_a: Dictionary, _o: Vector2, _d: float) -> void: started.append(1)
	_bus.ring_cast_started.connect(cb)
	_gs.mana = _gs.mana_max()
	var before: float = _gs.mana
	_caster.fire()
	_caster.fire()
	_caster.fire()
	var spent: float = before - _gs.mana
	_check(started.size() == 1, "좌클릭 3연타 = 시전 1회 (실제 %d)" % started.size())
	# 🔴 마나도 한 번만 나가야 한다 — 차단이 emit만 막고 마나는 태우면 연타로 조용히 녹는다.
	_check(is_equal_approx(spent, _gs.cast_mana_cost()),
		"마나도 1회분만 나간다 (%.2f vs %.2f)" % [spent, _gs.cast_mana_cost()])
	_bus.ring_cast_started.disconnect(cb)
	_caster.cancel_cast()


## [5] 🔴 가드가 `ring_cast_started`보다 먼저다(ⓚ) — 빈 슬롯·마나 부족엔 **발밑이 열리지 않는다**.
func _test_guards_come_before_started() -> void:
	print("[5] 빈 슬롯·마나 부족 → ring_cast_started 0회 (가드가 먼저다)")
	var started: Array = []
	var cb := func(_a: Dictionary, _o: Vector2, _d: float) -> void: started.append(1)
	_bus.ring_cast_started.connect(cb)

	# ① 빈 슬롯 — 마나도 안 태운다(거부는 공짜).
	_gs.ring_equipped[0] = null
	_caster.select_slot(0)
	_gs.mana = _gs.mana_max()
	var before: float = _gs.mana
	_caster.fire()
	_check(started.is_empty(), "빈 슬롯 → started 0회 (실제 %d)" % started.size())
	_check(_gs.mana >= before - 0.001, "빈 슬롯 거부에 마나를 안 태운다")
	_check(not _caster.is_casting(), "빈 슬롯이면 시전 상태로도 안 들어간다")

	# ② 마나 부족 — 이쪽도 발밑이 열리면 안 된다.
	_arm(_design(1.0, &"jin_nomana"))
	_gs.mana = 0.0
	_caster.fire()
	_check(started.is_empty(), "마나 부족 → started 0회 (실제 %d)" % started.size())
	_check(not _caster.is_casting(), "마나 부족이면 시전 상태로도 안 들어간다")
	_bus.ring_cast_started.disconnect(cb)
	_gs.mana = _gs.mana_max()


## [6] 🔴 구르기가 시전을 끊는다(ⓝ · 확정 ⑥) — 안 끊으면 *"무적으로 굴러다니며 퍼펙트 시전"*이
## 최적해가 돼 확정 ⑤(감속 = 위험)가 통째로 무효가 된다.
## ⚠ 「requested 0회」만 재면 *"시전이 애초에 안 걸렸다"*와 구분이 안 된다 — 그래서 **시작(started)·
##   마나 차감·구르기 성립·취소 신호**를 같이 잰다.
func _test_roll_cancels_cast() -> void:
	print("[6] 구르기(스페이스)가 시전을 끊는다 — 마나는 태운 채로")
	_arm(_design(1.0, &"jin_roll"))
	var started: Array = []
	var fired: Array = []
	var canceled: Array = []
	var s_cb := func(_a: Dictionary, _o: Vector2, _d: float) -> void: started.append(1)
	var f_cb := func(_a: Dictionary, _o: Vector2, _d: Vector2) -> void: fired.append(1)
	var c_cb := func() -> void: canceled.append(1)
	_bus.ring_cast_started.connect(s_cb)
	_bus.ring_cast_requested.connect(f_cb)
	_bus.ring_cast_canceled.connect(c_cb)

	_gs.mana = _gs.mana_max()
	var before: float = _gs.mana
	_caster.fire()
	var spent: float = before - _gs.mana   # ⚠ 즉시 잰다 — 마나 자연 회복이 끼어들기 전에
	_check(started.size() == 1, "시전이 실제로 걸렸다 (started %d) — 이게 0이면 아래가 자명 통과다" % started.size())
	_check(spent > 0.001, "시전 시작에 마나가 나갔다 (%.2f)" % spent)

	Input.action_press(&"dash")
	await physics_frame
	await physics_frame
	Input.action_release(&"dash")
	# 🔴 **전제 검산** — 구르기가 정말 시작됐나. 안 됐으면 아래 「0회」는 아무것도 증명하지 못한다.
	_check(_player.is_rolling(), "구르기가 실제로 시작됐다 (전제 — false면 이 테스트는 무효다)")
	_check(not _caster.is_casting(), "구르는 순간 시전이 끊겼다")
	_check(canceled.size() == 1, "ring_cast_canceled 1회 = 발밑 마법진을 지울 신호가 나갔다 (실제 %d)"
		% canceled.size())

	await _wait(_cast_time_of(1.0) + 0.2)
	_check(fired.is_empty(), "🔴 끊긴 시전은 **영영 안 나간다** (실제 %d발)" % fired.size())
	# 🔴 마나는 안 돌아온다(ⓓ) — 돌려주면 "구르기로 마나 아끼기"가 최적해가 된다.
	_check(_gs.mana < _gs.mana_max() - 0.001 or _gs.mana_max() <= spent,
		"취소해도 마나는 안 돌아온다 (지금 %.1f / 최대 %.1f)" % [_gs.mana, _gs.mana_max()])
	_bus.ring_cast_started.disconnect(s_cb)
	_bus.ring_cast_requested.disconnect(f_cb)
	_bus.ring_cast_canceled.disconnect(c_cb)


## [7] 모달·책이 시전을 끊는다(ⓕ) — 안 끊으면 **펼쳐진 책 위로 마법이 날아간다**.
## `enabled=false`·`ui_modal_open`은 `_process`·`_unhandled_input`만 막지 지연 emit은 안 막는다.
func _test_modal_cancels_cast() -> void:
	print("[7] 모달·책이 열리면 시전이 끊긴다 — 책 위로 마법이 날아가지 않는다")
	for label: String in ["ui_modal_open", "caster.enabled=false"]:
		_arm(_design(1.0, &"jin_modal"))
		_gs.mana = _gs.mana_max()
		var fired: Array = []
		var f_cb := func(_a: Dictionary, _o: Vector2, _d: Vector2) -> void: fired.append(1)
		_bus.ring_cast_requested.connect(f_cb)
		_caster.fire()
		_check(_caster.is_casting(), "%s — 시전이 걸렸다(전제)" % label)
		if label == "ui_modal_open":
			_gs.ui_modal_open = true
		else:
			_caster.enabled = false
		await process_frame
		await process_frame
		_check(not _caster.is_casting(), "%s → 시전이 끊겼다" % label)
		await _wait(_cast_time_of(1.0) + 0.2)
		_check(fired.is_empty(), "%s → 탄이 안 나갔다 (실제 %d발)" % [label, fired.size()])
		_bus.ring_cast_requested.disconnect(f_cb)
		_gs.ui_modal_open = false
		_caster.enabled = true
		await process_frame


## [8] 🔴🔴 **떼면 나간다**(확정 ⑦) — 이 파일의 핵심 검출자.
## 자동 발사로 되돌리면(= `_tick_cast`에서 `_cast_released` 조건을 빼면) **여기만** 빨개진다.
## ⚠ 「안 나갔다」만 재면 *"시전이 애초에 안 걸렸다"*·*"취소됐다"*와 구분이 안 된다 →
##   **is_casting()·is_holding()·다 찼다(is_holding)·그 뒤 떼니 나갔다**를 한 줄기로 잰다.
func _test_hold_waits_for_release() -> void:
	print("[8] 다 차도 **안 뗐으면 안 나간다** — 떼는 순간 나간다 (확정 ⑦)")
	_arm(_design(1.0, &"jin_hold"))
	var fired: Array = []
	var started: Array = []
	var f_cb := func(_a: Dictionary, _o: Vector2, _d: Vector2) -> void: fired.append(1)
	var s_cb := func(_a: Dictionary, _o: Vector2, _d: float) -> void: started.append(1)
	_bus.ring_cast_requested.connect(f_cb)
	_bus.ring_cast_started.connect(s_cb)

	var dur: float = _cast_time_of(1.0)
	_press_click()
	_caster.fire()
	await process_frame
	_check(_caster.is_casting(), "시전이 걸렸다 (전제 — false면 아래가 전부 자명 통과다)")
	_check(not _caster.is_holding(), "아직 채우는 중이다 (홀드 아님)")

	# 🔴 duration을 **넘겨서** 기다린다 — 옛 계약이면 여기서 이미 나갔다.
	await _wait(dur + 0.35)
	_check(_caster.is_casting(), "🔴 다 차도 시전이 안 끝났다 — 쥐고 있으니까")
	_check(_caster.is_holding(), "🔴 홀드 구간에 들어갔다 (다 찼는데 손을 안 뗐다)")
	_check(fired.is_empty(), "🔴🔴 **안 뗐으면 안 나간다** (실제 %d발 — 1이면 자동 발사로 되돌아간 것)"
		% fired.size())

	# 🔴 **차단이 홀드 구간까지 이어진다** — [2]·[4]는 「채우는 중」만 재므로, 구간이 둘로 갈린
	#   지금은 *"다 차는 순간 차단이 통째로 풀린다"*를 아무도 안 잡는다(원이 겹치고 마나가 녹는다).
	_gs.ring_equipped[1] = _design(1.0, &"jin_hold_other")
	_caster.select_slot(1)
	_check(_caster.slot() == 0, "🔴 홀드 중에도 슬롯 전환이 막힌다 (지금 슬롯 %d)" % _caster.slot())
	_caster.fire()
	_check(started.size() == 1, "🔴 홀드 중 재발사가 막힌다 — 시전은 하나다 (실제 %d)" % started.size())
	_gs.ring_equipped[1] = null

	_release_click()
	await process_frame
	await process_frame
	_check(fired.size() == 1, "🔴 떼니까 나갔다 (실제 %d발)" % fired.size())
	_check(not _caster.is_casting(), "발사 후엔 시전 상태가 남지 않는다")
	_bus.ring_cast_requested.disconnect(f_cb)
	_bus.ring_cast_started.disconnect(s_cb)


## [9] 🔴🔴 **덜 찼는데 떼면 불발이다 — 마나는 태운다** (확정 ⑦-b · **F5가 뒤집은 계약**).
##
## ⚠ **이 항목은 세98 안에서 기대값이 한 번 뒤집혔다.** 초판은 *"일찍 떼도 다 차는 순간 나간다"*
## (최소 시전 시간 보장)였는데, 사용자가 실물에서 *"꾸욱 누르는 게 아니라 한번 클릭하면 차징이
## 되네 이러면 안 됨"*이라고 각하했다 — 톡 눌러도 차징이 알아서 굴러가면 **「쥐고 있다」는 감각이
## 통째로 죽는다**. 이제 **누르고 있는 동안만 시전이 산다.**
##
## 🔴 셋을 같이 재야 검출력이 선다: ⓐ **안 나간다** ⓑ **취소 신호가 온다**(연출이 원을 지운다)
##   ⓒ 🔴 **마나는 깎인 채다** — ⓐ만 재면 *"시전이 애초에 안 걸렸다"*와 구분이 안 되고,
##   ⓒ가 없으면 누가 「불발이면 마나 환불」을 넣어도 그물이 조용하다(설계 ⓓ가 금지한 자리다).
func _test_early_release_fizzles() -> void:
	print("[9] 덜 찼는데 떼면 **불발** — 마나는 태운다 (꾹 누르고 있어야 한다)")
	_arm(_design(1.0, &"jin_early"))
	var dur: float = _cast_time_of(1.0)
	var fired := {"n": 0}
	var canceled := {"n": 0}
	var f_cb := func(_a: Dictionary, _o: Vector2, _d: Vector2) -> void:
		fired["n"] = int(fired["n"]) + 1
	var c_cb := func() -> void:
		canceled["n"] = int(canceled["n"]) + 1
	_bus.ring_cast_requested.connect(f_cb)
	_bus.ring_cast_canceled.connect(c_cb)

	_gs.mana = _gs.mana_max()
	var mana_before: float = _gs.mana
	_press_click()
	_caster.fire()
	var mana_after_start: float = _gs.mana
	await _wait(dur * 0.2)          # 아직 채우는 중에 뗀다
	_release_click()
	await _wait(dur + 0.35)         # 다 찼을 시각을 **지나서** 본다

	_check(fired["n"] == 0, "🔴 덜 차고 뗐으면 안 나간다 (실제 %d발)" % int(fired["n"]))
	_check(canceled["n"] == 1, "ring_cast_canceled 1회 — 발밑 원이 지워진다 (실제 %d)" % int(canceled["n"]))
	_check(not _caster.is_casting(), "불발 뒤 시전 상태가 안 남는다")
	# 🔴 마나는 **시작에** 깎이고 불발에도 안 돌아온다(설계 ⓓ).
	_check(mana_after_start < mana_before, "시전 시작에 마나가 깎였다")
	# 🔴 **절대값으로 재지 마라 — 마나는 시간이 흐르면 저절로 찬다**(`mana_regen_per_sec`).
	#   기다린 뒤 재면 회복분 때문에 늘 늘어나 있어서 「환불 안 함」을 절대값으로는 못 잰다(실측 84.8→87.3).
	#   🔴 대신 **환불이면 `cast_mana_cost`만큼 한 번에 점프한다**는 성질을 쓴다 — 회복은 그보다 훨씬 느리다.
	var cost: float = _gs.cast_mana_cost()
	_check(_gs.mana < mana_after_start + cost * 0.5,
		"🔴 불발이어도 마나는 안 돌아온다 (%.1f → %.1f · 환불이면 +%.1f 점프)"
		% [mana_after_start, _gs.mana, cost])
	_bus.ring_cast_requested.disconnect(f_cb)
	_bus.ring_cast_canceled.disconnect(c_cb)


## [10] 🔴🔴 **넘지 말 선 — 홀드는 위력에 1도 안 실린다**(확정 ⑦ 표에서 각하된 대안).
## 홀드가 위력 축이 되면 *"대충 조립하고 오래 누르기"*가 최적해가 돼 **설계 전체가 무너진다**.
## 🔴 그물 둘: ⓐ 홀드 길이가 달라도 **나간 위력이 같다** ⓑ 홀드 동안 **스냅샷이 안 변한다**
##   (`ring_cast_started`에서 잰 해시 == `ring_cast_requested`에서 잰 해시 — 사전을 몰래 손대면 잡힌다).
## ⚠ ⓑ가 필요한 이유: 보너스를 `score`가 아니라 `ink`·`size`에 얹어도 ⓐ만으론 못 잡는다
##   (위력 = `power_of(score, ink_mult, size)`라 입력이 셋이다).
## 🔴🔴 **점수 1.0(퍼펙트)으로 재지 마라 — 검출력이 0이 된다.** 위력 곡선은 점수를 0~1로 clamp하고
## 홀드 보너스는 십중팔구 `minf(score + …, 1.0)` 꼴로 들어오므로, **이미 퍼펙트면 보너스가 얹혀도
## 값이 그대로다**(스냅샷 해시까지 같다). 그래서 일부러 **덜 조립한 진(0.80)**으로 잰다.
func _test_hold_does_not_boost_power() -> void:
	print("[10] 🔴 홀드를 오래 해도 **위력이 안 변한다** (홀드 = 타이밍이지 위력 축이 아니다)")
	var rp = load("res://src/core/ring_power.gd")
	var score := 0.80
	var powers: Array = []
	for hold: float in [0.0, 0.9]:
		_arm(_design(score, &"jin_power"))
		var seen := {"start_hash": 0, "end_hash": 0, "power": -1.0}
		var s_cb := func(a: Dictionary, _o: Vector2, _d: float) -> void:
			seen["start_hash"] = a.hash()
		var f_cb := func(a: Dictionary, _o: Vector2, _d: Vector2) -> void:
			seen["end_hash"] = a.hash()
			seen["power"] = rp.power_of(float(a.get("score", 0.0)),
				1.0, float(a.get("size", 1.0)))
		_bus.ring_cast_started.connect(s_cb)
		_bus.ring_cast_requested.connect(f_cb)

		_press_click()
		_caster.fire()
		await _wait(_cast_time_of(score) + hold + 0.2)
		_release_click()
		await process_frame
		await process_frame

		_bus.ring_cast_started.disconnect(s_cb)
		_bus.ring_cast_requested.disconnect(f_cb)
		_check(float(seen["power"]) > 0.0, "홀드 %.1fs — 실제로 나갔다 (전제)" % hold)
		_check(int(seen["start_hash"]) == int(seen["end_hash"]),
			"🔴 홀드 %.1fs — 나간 조립본이 **시전 시작 그대로다**(홀드가 사전을 안 건드린다)" % hold)
		powers.append(float(seen["power"]))
	_check(powers.size() == 2 and is_equal_approx(powers[0], powers[1]),
		"🔴🔴 **오래 들어도 안 세진다** — 짧게 %.2f vs 오래 %.2f"
		% [powers[0] if powers.size() > 0 else -1.0, powers[1] if powers.size() > 1 else -1.0])


## [11] 취소 조건이 **홀드 구간까지 이어진다** — 다 채워 놓고 들고 있다가 굴러도 취소다.
## ⚠ [6]은 **채우는 중**에 굴러서, 「다 찬 뒤엔 못 끊는다」는 회귀를 못 잡는다(구간이 둘이 됐다).
func _test_roll_cancels_during_hold() -> void:
	print("[11] 다 채워 들고 있다가 굴러도 취소된다 (취소가 홀드 구간까지 이어진다)")
	_arm(_design(1.0, &"jin_holdroll"))
	var fired: Array = []
	var canceled: Array = []
	var f_cb := func(_a: Dictionary, _o: Vector2, _d: Vector2) -> void: fired.append(1)
	var c_cb := func() -> void: canceled.append(1)
	_bus.ring_cast_requested.connect(f_cb)
	_bus.ring_cast_canceled.connect(c_cb)

	_press_click()
	_caster.fire()
	await _wait(_cast_time_of(1.0) + 0.25)
	_check(_caster.is_holding(), "홀드 구간에 들어갔다 (전제)")

	Input.action_press(&"dash")
	await physics_frame
	await physics_frame
	Input.action_release(&"dash")
	_check(_player.is_rolling(), "구르기가 실제로 시작됐다 (전제)")
	_check(not _caster.is_casting(), "🔴 홀드 중에도 구르기가 시전을 끊는다")
	_check(canceled.size() == 1, "ring_cast_canceled 1회 (실제 %d)" % canceled.size())

	# 🔴 끊은 뒤 손을 떼도 **되살아나지 않는다** — 취소는 되돌릴 수 없다.
	_release_click()
	await _wait(0.2)
	_check(fired.is_empty(), "🔴 끊긴 시전은 떼도 안 나간다 (실제 %d발)" % fired.size())
	_bus.ring_cast_requested.disconnect(f_cb)
	_bus.ring_cast_canceled.disconnect(c_cb)


# ── 도구 ──────────────────────────────────────────────────────────────────────

## 🔴 좌클릭을 「쥔다·놓는다」 — 캐스터가 **폴링**으로 보므로 액션 상태만 바꾸면 된다(이벤트 불필요).
## ⚠ 선례 = [6]의 `Input.action_press(&"dash")`. 액션 이름을 다른 곳에 또 적지 마라(정본은 project.godot).
func _press_click() -> void:
	Input.action_press(&"attack_basic")


func _release_click() -> void:
	Input.action_release(&"attack_basic")


## 슬롯 0에 도안을 꽂고 시전 가능 상태로 만든다(남은 시전은 끊고 마나는 채운다).
func _arm(design) -> void:
	_caster.cancel_cast()
	_gs.ring_equipped[0] = design
	_caster.select_slot(0)
	_gs.mana = _gs.mana_max()


## 점수·표식만 다른 도안. `jin`은 **스냅샷 추적용 표식**이다(Db에 없는 id라 발사 형태는 단발 폴백).
func _design(score: float, tag: StringName):
	var d = load("res://src/core/schemas/ring_design.gd").new()
	d.total_score = score
	d.jin = tag
	return d


## 🔴 기대 시전 시간은 **core 단일 소스**에서 받는다 — 여기 상수를 베끼면 balance를 조일 때
## 이 파일만 낡아 거짓 빨강이 난다(세24 「경계를 베끼면 갈라진다」의 시간판).
func _cast_time_of(score: float) -> float:
	return float(load("res://src/core/ring_power.gd").cast_time_of(score))


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		print("  ✗ FAIL: ", label)


func _finish() -> void:
	if _player != null:
		_player.queue_free()
	if failures == 0:
		print("TEST_SPELL_CAST_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_SPELL_CAST_FAIL — %d개 실패" % failures)
		quit(1)
