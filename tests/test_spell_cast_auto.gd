extends SceneTree
## **즉발 발사** 자동 검증 (세112 — 차징 폐지) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_spell_cast_auto.gd
## 전 항목 통과 시 "TEST_SPELL_CAST_OK" 출력 후 종료 코드 0.
##
## 🔴🔴 **세112에 좌클릭이 다시 「즉시 발사」가 됐다**(사용자 지시 *"차징도 없애줘 바로발싸되도록"*
## · *"바닥에 마법진 생기는것도 제거"*). 스위치는 코드가 아니라 **balance의 `cast_time_*` 둘**이다 —
## 0으로 내리면 `fire()`가 그 자리에서 `_release_cast()`를 부르고, `vfx`는 발밑 원을 안 연다.
## ⇒ 이 파일은 세98의 「시전 상태기계」 그물을 **즉발 계약으로 갈아 끼운 것**이다.
##
## 🔴 **[0]이 스위치 감시자다** — `cast_time_of`가 0이 아니게 되는 순간(= 차징 복원) 여기가 빨개져
##   **아래 묘비들을 되살릴 때가 왔다**고 알린다. 그 알림이 없으면 차징을 되살려도 그물은 즉발
##   계약을 계속 단언해 「고칠수록 빨개지는」 상태가 된다(세104 늑대 뒷걸음질과 같은 형태).
##
## [0] 🔴 **즉발이다** — `RingPower.cast_time_of`가 점수 전 구간에서 0 (차징 복원 감지기)
## [1] 좌클릭 한 번 = **같은 호출 안에서** started 1회 + requested 1회 · 시전 상태가 안 남는다
##     + 🔴 origin 셋이 지팡이 끝이다(총구 단일 소스 ⓛ — 즉발이라 started·requested가 같은 자리다)
## [2] 🔴 `to_assembly()` 경로 — 나간 조립본에 **슬롯의 그 진·그 점수**가 실려 있다.
##     직접 Dictionary를 만들면 `score`가 빠져 **조용히 기준 위력**이 된다(takbon-rules §3)
## [3] 마나가 **정확히 1발분** 나간다
## [4] 🔴🔴 **뒤집힌 계약 — 연사 제한이 없다.** 세97까지는 시전 시간이 연사 하한도 겸했는데
##     그게 0이 되며 **같이 사라졌다.** 3연타 = 3발 · 마나 3배다. **쿨다운이 생기면 여기가 빨개진다**
##     (실측 = 아래 「연사 실측」 주석)
## [5] 🔴 가드가 발사보다 먼저다(ⓚ) — 빈 슬롯·마나 부족이면 started도 requested도 0회 · 마나도 안 탄다
## [6] 🔴🔴 **모달·책 가드는 `_unhandled_input`에만 있다 — 그래서 실경로로 잰다.**
##     `fire()`를 직접 부르면 그 가드를 **우회**해서 탄이 나간다(즉발이라 `_process`의 취소 분기가
##     돌 창이 없다). 그래서 여기만 `root.push_input(InputEventMouseButton)`으로 **진짜 좌클릭**을
##     민다. ⚠ **대조군(가드 없음 → 1발)을 같이 재는 게 계약이다** — 안 그러면 *"이벤트가 애초에
##     안 닿았다"*와 구분이 안 돼 자명 통과한다
##
## ── 🔴 연사 실측 (세112 · 맨손 기준 `cast_mana_cost()=16.0`, 지팡이(`wand_basic`)면 15.2) ──
##   `mana_max=100` · `mana_regen_per_sec=2.0`
##   • 3연타 → **실제 3발**, 마나 48.0 소모(만마나의 48%)
##   • 만마나에서 연타 → **6발이면 바닥**(그 뒤엔 마나 부족으로 거부)
##   • 지속 연사율 = **8초에 1발**(회복 2.0/s ÷ 비용 16.0 = 초당 0.125발)
##   • 빈 마나 → 만마나 = **50초**
##   ⇒ 지금 연사를 막는 건 **마나뿐**이고, 그 형태가 「6발 순간 버스트 → 긴 침묵」이다.
##     옛 차징은 발당 0.15~0.75초 하한을 걸어 그 버스트를 **시간으로 늘리고 있었다**(퍼펙트 = 초당
##     1.33발 상한). 🔴 **쿨다운을 세울지는 사용자 결정이다 — 이 파일은 재기만 한다.**
##
## ── 🪦 묘비: 세112에 **잴 대상이 사라진** 계약들 (차징을 되살리는 날의 복원 근거) ──
##   차징이 있던 세98~111의 계약이다. `cast_time_*`를 0.15/0.75로 되돌리면 **전부 다시 살아나야
##   한다** — 되살릴 땐 git으로 이 파일의 세111 판을 꺼내 그대로 붙이는 게 제일 빠르다.
##   ⓐ **시전 구간 자체**: `fire()`는 탄을 안 쏘고 `ring_cast_started`(발밑 원이 열린다)만 쏜 뒤
##      `duration`초 뒤에 `ring_cast_requested`가 나갔다. duration은 등급이 정했다(확정 ④).
##   ⓑ **홀드**: 다 차도 자동 발사가 없었다 — 좌클릭을 **떼야** 나갔다(확정 ⑦). `is_holding()`이
##      그 구간의 헤드리스 관측점이었다. **덜 찼는데 떼면 불발**이고 마나는 탔다(확정 ⑦-b).
##      🔴 홀드 길이는 **위력에 1도 안 실렸다** — 그 감시자가 있어야 "오래 누르면 세짐"이 다시
##      들어올 때 그물이 빨개진다(각하된 대안).
##   ⓒ **시전 중 슬롯 전환 차단 + 스냅샷**(ⓖ): `to_assembly()`는 시전 한 번에 한 번만 불렸고,
##      시전 중 슬롯을 갈아치워도 **시작할 때 그 진**이 나갔다. 지금은 갈아치울 창 자체가 없다.
##   ⓓ **시전 중 재발사 차단**(ⓒ): 연타해도 시전은 하나였다 → 지금은 **[4]가 그 자리를 뒤집어 잰다**.
##   ⓔ **끊긴 시전은 영영 안 나간다**: 구르기(`player`가 `cancel_cast()`를 부른다)·모달·책이
##      시전을 끊었고 `ring_cast_canceled`가 나가 발밑 원을 지웠다. **마나는 안 돌려줬다**(ⓓ).
##      ⚠ `player.gd`의 `caster.cancel_cast()` 호출과 `cancel_cast`/`ring_cast_canceled` 자체는
##        **코드에 그대로 살아 있다** — 즉발이라 끊을 시전이 없어 항상 no-op일 뿐이다.
##   ⓕ **duration 단조성**: 무난 < 괜찮음 < 퍼펙트. 「강한 진은 DPS가 아니라 한 방」이라는
##      밸런스 계약(`balance_data.gd` 머리말)이 그 위에 서 있었고, **지금 그게 죽어 있다.**
##
## 🔴 헤드리스가 못 보는 것: 좌클릭이 **실제 화면에서** 닿나(화면 덮는 Control의 `mouse_filter`) ·
##   즉발이 **손에 붙나** · 발밑 원이 정말 안 뜨나. 전부 F5·MCP 몫이다.
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

	# ⚠ 항목 사이에 프레임을 흘린다 — 안 그러면 전부 **한 프레임 안에서** 돌아, 「프레임당 한 발」
	#   꼴의 쿨다운이 들어왔을 때 [4]뿐 아니라 [1]~[3]까지 같이 빨개져 **검출 지점이 뭉갠다**
	#   (뮤테이션 M3 실측). 항목마다 프레임을 갈라 두면 빨간 자리가 곧 깨진 계약이다.
	_test_instant_by_design()
	await process_frame
	_test_click_fires_now()
	await process_frame
	_test_assembly_carries_score()
	await process_frame
	_test_mana_one_shot()
	await process_frame
	_test_no_fire_rate_limit()
	await process_frame
	_test_guards_come_first()
	await process_frame
	await _test_modal_guard_on_real_path()

	await _restore_state()
	_finish()


## 🔴🔴 **뒷정리 = 계약이다** — `-s` 테스트는 세이브 뿌리가 `user://save_test`로 격리돼 있을 뿐
## **테스트끼리는 그 파일을 공유한다**. `equipment_changed`는 자동 저장 트리거라(세84 #1), 지팡이를
## 낀 채 끝내면 그 상태가 세이브에 남고 **나중에 도는 테스트가 그걸 로드해 「맨손 기준값」을
## 오염시킨다**(실측: `test_workshop_auto`의 「지팡이 해제하면 원복」 2건이 그 형태로 빨개진다).
## ⚠ 저장은 `call_deferred`라 **프레임을 흘려야** 깨끗한 상태가 실제로 쓰인다.
func _restore_state() -> void:
	_gs.ui_modal_open = false
	_caster.enabled = true
	_gs.ring_equipped[0] = null
	_gs.ring_equipped[1] = null
	_gs.equipment.erase(_WAND)
	_bus.equipment_changed.emit()
	_gs.mana = _gs.mana_max()
	await process_frame
	await process_frame


## [0] 🔴 즉발 스위치 감시자 — `cast_time_of`가 점수 전 구간에서 0이다.
## 여기가 빨개지면 차징이 돌아온 것이고, **머리말 묘비 ⓐ~ⓕ를 되살릴 때**다.
func _test_instant_by_design() -> void:
	print("[0] 즉발이다 — cast_time_of가 점수 전 구간에서 0 (차징 복원 감지기)")
	for score: float in [0.0, 0.70, 0.85, 1.0]:
		var t: float = _cast_time_of(score)
		_check(is_zero_approx(t),
			"점수 %.2f의 시전 시간 = 0 (실제 %.3fs — 0이 아니면 차징이 돌아왔다)" % [score, t])


## [1] 좌클릭 한 번 = 그 자리에서 한 발. + 총구 단일 소스(ⓛ).
func _test_click_fires_now() -> void:
	print("[1] fire() 한 번 = **같은 호출 안에서** started 1회 + requested 1회 (즉발)")
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
	# ⚠ **같은 줄에서** 잰다 — 즉발이면 대기 없이 둘 다 나와 있어야 한다.
	_check(started.size() == 1, "ring_cast_started 1회 (실제 %d)" % started.size())
	_check(fired.size() == 1,
		"🔴 ring_cast_requested도 **그 자리에서** 1회 (실제 %d — 0이면 차징이 돌아온 것)"
		% fired.size())
	_check(not _caster.is_casting(), "시전 상태가 남지 않는다")
	if started.size() == 1:
		_check(is_zero_approx(float(started[0]["dur"])),
			"started가 실은 duration 0을 나른다 (실제 %.3fs)" % float(started[0]["dur"]))
		# 🔴 지팡이 끝과 같은가 — 총구 단일 소스(세65)가 갈라지면 여기서 잡힌다.
		var tip: Vector2 = _wand.muzzle_position()
		var d0: float = Vector2(started[0]["origin"]).distance_to(tip)
		_check(d0 < 0.5, "started.origin == 지팡이 끝 (dist=%.1f)" % d0)
	if fired.size() == 1:
		# 🔴 즉발이라 **started와 requested가 같은 자리**다 — 걸어갈 시간이 없다.
		#   (차징 시절엔 requested가 「지금」의 총구를 다시 봐서 갈라지는 게 정상이었다.)
		var d1: float = Vector2(fired[0]["origin"]).distance_to(_wand.muzzle_position())
		_check(d1 < 0.5, "requested.origin == 지팡이 끝 (dist=%.1f)" % d1)
		if started.size() == 1:
			_check(Vector2(started[0]["origin"]).is_equal_approx(Vector2(fired[0]["origin"])),
				"🔴 즉발이라 started.origin == requested.origin (%s vs %s)"
				% [str(started[0]["origin"]), str(fired[0]["origin"])])
	_bus.ring_cast_started.disconnect(s_cb)
	_bus.ring_cast_requested.disconnect(f_cb)


## [2] 🔴 `to_assembly()` 경로 — 슬롯의 그 진·그 점수가 그대로 실린다.
## 뮤테이션: `fire()`에서 `design.to_assembly()` 대신 직접 Dictionary를 만들면 `score`가 빠져
## 여기가 빨개진다(그게 takbon-rules §3이 막는 「조용히 기준 위력」이다).
func _test_assembly_carries_score() -> void:
	print("[2] 나간 조립본에 슬롯의 그 진·그 점수가 실려 있다 (to_assembly 경로)")
	_arm(_design(0.83, &"jin_tagged"))
	var fired: Array = []
	var f_cb := func(a: Dictionary, _o: Vector2, _m: Vector2) -> void: fired.append(a)
	_bus.ring_cast_requested.connect(f_cb)
	_caster.fire()
	_check(fired.size() == 1, "한 발 나갔다 (실제 %d)" % fired.size())
	if fired.size() == 1:
		_check(StringName(fired[0].get("jin", &"")) == &"jin_tagged",
			"나간 진 = 슬롯의 그것 (실제 %s)" % str(fired[0].get("jin", &"")))
		_check(is_equal_approx(float(fired[0].get("score", -1.0)), 0.83),
			"🔴 score가 실려 있다 (실제 %.3f — 빠지면 조용히 기준 위력이 된다)"
			% float(fired[0].get("score", -1.0)))
	_bus.ring_cast_requested.disconnect(f_cb)


## [3] 마나가 정확히 1발분.
func _test_mana_one_shot() -> void:
	print("[3] 한 발에 마나 1회분")
	_arm(_design(1.0, &"jin_mana"))
	var before: float = _gs.mana
	_caster.fire()
	var spent: float = before - _gs.mana   # ⚠ 즉시 잰다 — 자연 회복이 끼어들기 전에
	_check(is_equal_approx(spent, _gs.cast_mana_cost()),
		"마나 1회분 (%.2f vs %.2f)" % [spent, _gs.cast_mana_cost()])


## [4] 🔴🔴 **뒤집힌 계약 — 연사 제한이 없다** (세112).
## 세97까지는 시전 시간(0.15~0.75초)이 연사 하한도 겸했다 — 그게 0이 되며 **같이 사라졌다.**
## 🔴 **여기는 "이게 옳다"가 아니라 "지금은 이렇다"를 못 박는 자리다.** 쿨다운이 생기면 빨개져서
##   *"연사 제한이 다시 생겼다 — 이 항목을 계약으로 뒤집어라"*라고 알린다.
## 실측 숫자는 머리말 「연사 실측」에 있다.
func _test_no_fire_rate_limit() -> void:
	print("[4] 🔴 지금은 연사 제한이 없다 — 3연타 = 3발 (쿨다운이 생기면 여기가 빨개진다)")
	_arm(_design(1.0, &"jin_rapid"))
	var fired: Array = []
	var cb := func(_a: Dictionary, _o: Vector2, _m: Vector2) -> void: fired.append(1)
	_bus.ring_cast_requested.connect(cb)
	var before: float = _gs.mana
	_caster.fire()
	_caster.fire()
	_caster.fire()
	var spent: float = before - _gs.mana
	_check(fired.size() == 3, "3연타 = **3발** (실제 %d — 1이면 쿨다운이 생긴 것)" % fired.size())
	# 🔴 마나도 3배로 나간다 — 지금 연사를 막는 건 마나뿐이라는 사실을 여기서 못 박는다.
	_check(is_equal_approx(spent, _gs.cast_mana_cost() * 3.0),
		"마나도 3회분 나갔다 (%.2f vs %.2f)" % [spent, _gs.cast_mana_cost() * 3.0])
	_bus.ring_cast_requested.disconnect(cb)


## [5] 🔴 가드가 발사보다 먼저다(ⓚ) — 빈 슬롯·마나 부족엔 아무것도 안 나가고 마나도 안 탄다.
func _test_guards_come_first() -> void:
	print("[5] 빈 슬롯·마나 부족 → started·requested 0회 (가드가 먼저다)")
	var started: Array = []
	var fired: Array = []
	var s_cb := func(_a: Dictionary, _o: Vector2, _d: float) -> void: started.append(1)
	var f_cb := func(_a: Dictionary, _o: Vector2, _m: Vector2) -> void: fired.append(1)
	_bus.ring_cast_started.connect(s_cb)
	_bus.ring_cast_requested.connect(f_cb)

	# ① 빈 슬롯 — 마나도 안 태운다(거부는 공짜).
	_gs.ring_equipped[0] = null
	_caster.select_slot(0)
	_gs.mana = _gs.mana_max()
	var before: float = _gs.mana
	_caster.fire()
	_check(started.is_empty(), "빈 슬롯 → started 0회 (실제 %d)" % started.size())
	_check(fired.is_empty(), "빈 슬롯 → requested 0회 (실제 %d)" % fired.size())
	_check(_gs.mana >= before - 0.001, "빈 슬롯 거부에 마나를 안 태운다")

	# ② 마나 부족.
	_arm(_design(1.0, &"jin_nomana"))
	_gs.mana = 0.0
	_caster.fire()
	_check(started.is_empty(), "마나 부족 → started 0회 (실제 %d)" % started.size())
	_check(fired.is_empty(), "마나 부족 → requested 0회 (실제 %d)" % fired.size())
	_bus.ring_cast_started.disconnect(s_cb)
	_bus.ring_cast_requested.disconnect(f_cb)
	_gs.mana = _gs.mana_max()


## [6] 🔴🔴 **모달·책 가드 — 실경로로만 잰다.**
##
## 🔴 왜 `fire()`를 안 부르나: 즉발이 되며 **모달 가드가 `_unhandled_input` 한 곳으로 줄었다.**
##   차징 시절엔 `_process`가 매 프레임 `ui_modal_open`을 보고 **진행 중인 시전을 취소**해서,
##   `fire()`를 직접 불러도 그 취소가 잡아 줬다. 지금은 `fire()`가 그 자리에서 탄을 뱉으므로
##   **`fire()`를 부르는 그물은 가드를 우회한다** — 실제로 세112 초판이 그 형태로 빨갛게 났고,
##   실경로로 재 보니 **게임은 멀쩡했다**(그물이 거짓말한 것이다).
## 🔴 그래서 `root.push_input(InputEventMouseButton)`으로 **진짜 좌클릭**을 민다.
##   ⚠ 헤드리스에서도 `_unhandled_input`까지는 닿는다(실측). **닿지 않는 건 Control 히트 테스트**라
##     화면을 덮는 Control이 클릭을 먹는지는 여기서 못 잰다 — 그건 실게임 몫이다(takbon-verify §2-1).
## 🔴🔴 **대조군이 계약이다** — 가드를 끈 채 같은 이벤트를 밀어 **1발이 나가는 것**을 먼저 봐야
##   아래 「0발」이 *"이벤트가 애초에 안 닿았다"*와 구분된다(자명 통과 방지).
func _test_modal_guard_on_real_path() -> void:
	print("[6] 모달·책이 열리면 좌클릭이 안 먹는다 — **실경로(push_input)로** 잰다")
	var fired := {"n": 0}
	var started := {"n": 0}
	var f_cb := func(_a: Dictionary, _o: Vector2, _m: Vector2) -> void:
		fired["n"] = int(fired["n"]) + 1
	var s_cb := func(_a: Dictionary, _o: Vector2, _d: float) -> void:
		started["n"] = int(started["n"]) + 1
	_bus.ring_cast_requested.connect(f_cb)
	_bus.ring_cast_started.connect(s_cb)

	# ⓐ 대조군 — 가드가 없으면 **같은 이벤트로 실제로 나간다**.
	_arm(_design(1.0, &"jin_real"))
	await _click()
	_check(int(fired["n"]) == 1,
		"🔴 대조군: 진짜 좌클릭이 _unhandled_input까지 닿아 1발 (실제 %d — 0이면 아래가 전부 자명 통과다)"
		% int(fired["n"]))

	# ⓑ·ⓒ 가드 — 같은 이벤트를 밀어도 **한 발도 안 는다**.
	for label: String in ["ui_modal_open", "caster.enabled=false"]:
		_arm(_design(1.0, &"jin_real"))
		var f0: int = int(fired["n"])
		var s0: int = int(started["n"])
		if label == "ui_modal_open":
			_gs.ui_modal_open = true
		else:
			_caster.enabled = false
		await _click()
		_check(int(fired["n"]) == f0,
			"%s → 탄이 안 나갔다 (실제 %d발 더 나감)" % [label, int(fired["n"]) - f0])
		# 🔴 started도 안 나가야 한다 — `fire()`가 아예 안 불렸다는 뜻이다.
		_check(int(started["n"]) == s0,
			"%s → fire()가 아예 안 불렸다 (started %d회 더 나감)" % [label, int(started["n"]) - s0])
		_gs.ui_modal_open = false
		_caster.enabled = true
		await process_frame

	_bus.ring_cast_requested.disconnect(f_cb)
	_bus.ring_cast_started.disconnect(s_cb)


# ── 도구 ──────────────────────────────────────────────────────────────────────

## 🔴 **진짜 좌클릭** — 액션 주입(`Input.action_press`)이 아니라 뷰포트에 이벤트를 민다.
## 액션 주입은 `_unhandled_input`을 안 거쳐서 **모달 가드를 통째로 건너뛴다**(= 세25에 발사가
## 두 세션 죽어 있던 그 우회다). ⚠ 누른 채 끝내지 않게 **뗌까지 한 쌍으로** 민다.
func _click() -> void:
	root.push_input(_mouse_event(true))
	root.push_input(_mouse_event(false))
	await process_frame
	await process_frame


## ⚠ `position`과 `global_position`을 **둘 다** 채운다 — 하나만이면 조용히 무시된다(takbon-verify §7-②).
func _mouse_event(pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(100.0, 100.0)
	ev.global_position = Vector2(100.0, 100.0)
	return ev


## 슬롯 0에 도안을 꽂고 발사 가능 상태로 만든다.
func _arm(design) -> void:
	_gs.ring_equipped[0] = design
	_caster.select_slot(0)
	_gs.mana = _gs.mana_max()


## 점수·표식만 다른 도안. `jin`은 **추적용 표식**이다(Db에 없는 id라 발사 형태는 단발 폴백).
func _design(score: float, tag: StringName):
	var d = load("res://src/core/schemas/ring_design.gd").new()
	d.total_score = score
	d.jin = tag
	return d


## 🔴 기대 시전 시간은 **core 단일 소스**에서 받는다 — 여기 상수를 베끼면 balance를 조일 때
## 이 파일만 낡아 거짓 빨강이 난다(세24 「경계를 베끼면 갈라진다」의 시간판).
func _cast_time_of(score: float) -> float:
	return float(load("res://src/core/ring_power.gd").cast_time_of(score))


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
