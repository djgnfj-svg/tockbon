extends SceneTree
## 상태이상·원소 반응 자동 검증 (세션 49) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_status_auto.gd
## 전 항목 통과 시 "TEST_STATUS_OK" 출력 후 종료 코드 0.
##
## 🔴 여기서 지키는 계약: `forest_enemy.take_hit`이 **status를 실제로 쓴다**. 세34~48까지
## 밑줄로 버려서 불·물·바람의 실질 차이가 색 + 데미지 ±15%뿐이었다 — 이 파일이 그 회귀를 막는다.
## 규칙 자체는 `src/core/status_rules.gd`가 쥔다. 여기선 **적이 그 규칙대로 도는지**만 본다.
##
## 🔴 **공개 API로만** 검증한다 (takbon-verify §3): `hp()`·`take_hit`·`apply_status`·
## `has_status`·`status_power_of`·EventBus.enemy_hit. 내부 필드(_statuses)는 계약이 아니다.
##
## 🔴 감속은 **실제로 움직인 거리**로 잰다 — `_move_mult()`를 직접 부르면 `_apply_move` 통로를
## 건너뛰어 "곱하는 걸 잊었다"를 못 잡는다 (세션25 Control 우회와 같은 종류의 착각).
##
## ⚠ 못 잡는 것: 틴트가 **보이는지**(헤드리스는 렌더가 없다) · 연쇄/증기가 실제 전투에서
## 시원한지(손맛). 리드가 실게임 스샷·플레이로 확인해야 한다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

# 상태·룬 값은 **정수 리터럴**로 쓴다 (Enums 전역을 컴파일 타임에 참조하지 않게 — 기존 테스트 관례).
const S_BURN := 1
const S_WET := 3
const S_VULNERABLE := 6
const S_MUD := 8
const R_FIRE := 0
const R_WATER := 2
const R_WIND := 3
const S_SHOCK := 5
const R_BOLT := 4
const R_EARTH := 5

var failures: int = 0
var _bus = null
var _enemy_scene = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("TEST_STATUS_TIMEOUT — 60초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene

	await _test_burn_ticks_hp()
	await _test_wet_slows_movement()
	await _test_wet_plus_earth_is_mud()
	await _test_burn_plus_water_extinguishes()
	await _test_wind_spreads_status()
	await _test_reapply_refreshes_not_stacks()
	await _test_vulnerable_amplifies_next()
	await _test_burst_uses_balance_base()
	await _test_power_scales_shock_slow()
	await _test_slow_cap()
	await _test_dummy_reacts()
	await _test_reaction_vfx_signals()

	if failures == 0:
		print("TEST_STATUS_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_STATUS_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 화상이 **시간에 따라** hp를 깎고, 그 피해로 죽는 경로도 정상이다.
## 그리고 DoT는 `enemy_hit`을 **쏘지 않는다** — 그 시그널은 "최종 피해" 계약이라 피해 숫자·
## 히트스톱이 물려 있어서(세38·46), 0.5초마다 쏘면 화면이 도배되고 히트스톱에 갇힌다.
## 뮤테이션(`_tick_statuses`의 dot 적용 제거) → 첫 두 줄이 빨개진다.
func _test_burn_ticks_hp() -> void:
	print("[1] 화상 — 시간이 지나면 hp가 깎이고, DoT는 enemy_hit을 안 쏜다")
	var e = await _spawn(&"slime")
	var hits := [0]
	var cb := func(who, _d, _r) -> void:
		if who == e:
			hits[0] += 1
	_bus.enemy_hit.connect(cb)

	e.take_hit(0.0, R_FIRE, S_BURN, 1.0)  # 직격 피해 0 — 순수 DoT만 본다
	_check(e.has_status(S_BURN), "화상이 걸렸다")
	var h0: float = e.hp()
	_check(hits[0] == 1, "직격 1회만 enemy_hit이 왔다 (실제 %d)" % hits[0])
	# 틱 간격 0.5s를 두 번 넘긴다(~1.1s = 66 물리 프레임) → dot 3.0/s면 약 -3.0.
	for i in 70:
		await physics_frame
	_check(e.hp() < h0 - 1.0, "화상이 hp를 깎았다 (%.2f → %.2f)" % [h0, e.hp()])
	_check(hits[0] == 1, "DoT는 enemy_hit을 안 쐈다 (누적 %d, 1이어야 한다)" % hits[0])

	# 화상 지속(3.0s) 동안 3.0/s → 총 9. slime hp 14라 안 죽는다 → 만료 후 상태가 사라져야 한다.
	for i in 140:
		await physics_frame
	_check(not e.has_status(S_BURN), "화상이 지속시간 뒤에 만료돼 사라졌다")
	var h_after: float = e.hp()
	for i in 40:
		await physics_frame
	_check(is_equal_approx(e.hp(), h_after), "만료 뒤엔 더 안 깎인다 (%.2f → %.2f)" % [h_after, e.hp()])

	_bus.enemy_hit.disconnect(cb)
	e.free()


## [2] 🔴 젖음이 **실제 이동**을 늦춘다. 같은 조건의 적 둘을 나란히 두고 한쪽만 젖게 해
## 30 프레임 뒤 이동 거리를 비교한다 — `_apply_move` 한 곳의 곱이 빠지면 여기가 빨개진다.
## 뮤테이션(`velocity *= _move_mult()` 제거) → 두 거리가 같아져 빨개진다.
func _test_wet_slows_movement() -> void:
	print("[2] 젖음 — 실제 이동 거리가 줄어든다")
	var stub := Node2D.new()
	stub.add_to_group("player")
	stub.global_position = Vector2(150, 0)  # aggro_range(160) 안 · attack_range(18) 밖
	root.add_child(stub)

	var dry = await _spawn(&"slime")
	var wet = await _spawn(&"slime")
	wet.apply_status(S_WET, 1.0)
	_check(wet.has_status(S_WET), "젖음이 걸렸다")
	var d0: Vector2 = dry.global_position
	var w0: Vector2 = wet.global_position
	for i in 30:
		await physics_frame
	var dry_dist: float = dry.global_position.distance_to(d0)
	var wet_dist: float = wet.global_position.distance_to(w0)
	_check(dry_dist > 1.0, "마른 적은 실제로 움직였다 (%.2fpx)" % dry_dist)
	_check(wet_dist < dry_dist * 0.9,
		"젖은 적이 뚜렷하게 덜 움직였다 (마름 %.2f → 젖음 %.2f)" % [dry_dist, wet_dist])
	dry.free()
	wet.free()
	stub.free()


## [3] 🔴 젖음 + 흙 = **진흙**(반응 산물). 바탕(젖음)은 소진되고 진흙만 남으며, 진흙이 젖음보다
## **더 센 속박**이라 이동이 더 줄어야 한다 — "조합의 보상이 눈에 띄어야 한다"는 설계 원칙.
## 뮤테이션(`react()` 결과 무시 = 그냥 덮어쓰기) → 진흙이 안 생겨 첫 두 줄이 빨개진다.
func _test_wet_plus_earth_is_mud() -> void:
	print("[3] 젖음 + 흙 = 진흙 (더 센 속박)")
	var stub := Node2D.new()
	stub.add_to_group("player")
	# 🔴 120px — 넉백(140 임펄스)이 적을 ~16px 뒤로 민 뒤에도 **aggro_range(160) 안**이어야 한다.
	# 처음엔 150에 뒀다가 진흙 쪽만 넉백으로 사거리 밖으로 밀려 **어그로가 풀려** 이동 0이 됐고,
	# 테스트는 "진흙이 더 묶는다"로 **틀린 이유로 통과**했다 (검출력 0).
	stub.global_position = Vector2(120, 0)
	root.add_child(stub)

	var wet = await _spawn(&"slime")
	var mud = await _spawn(&"slime")
	# 🔴 둘 다 take_hit으로 세운다 — 넉백(손맛)이 한쪽에만 붙으면 이동 거리 비교가 오염된다.
	wet.take_hit(0.0, R_WATER, S_WET, 1.0)
	mud.apply_status(S_WET, 1.0)
	mud.take_hit(0.0, R_EARTH, 0, 1.0)  # 흙 룬이 젖음 위에 온다
	_check(mud.has_status(S_MUD), "진흙이 생겼다")
	_check(not mud.has_status(S_WET), "바탕(젖음)은 반응에 소진돼 사라졌다")

	# 🔴 `take_hit`은 넉백(손맛)도 함께 준다 — 그게 뒤로 밀어 **거리 측정을 오염시킨다**
	# (첫 시도에 진흙이 젖음만큼 움직인 것처럼 보였다). 넉백이 사그라들 때까지 두고 잰다.
	for i in 20:
		await physics_frame
	var w0: Vector2 = wet.global_position
	var m0: Vector2 = mud.global_position
	for i in 30:
		await physics_frame
	var wet_dist: float = wet.global_position.distance_to(w0)
	var mud_dist: float = mud.global_position.distance_to(m0)
	# 🔴 "0px" 가드 — 진흙이 0이면 감속이 아니라 **어그로가 풀린** 것일 수 있다(실제로 겪었다).
	# 이 줄이 없으면 아래 비교가 틀린 이유로 통과한다.
	_check(mud_dist > 0.5, "진흙 적도 (느리게나마) 실제로 움직였다 = 어그로는 살아 있다 (%.2fpx)" % mud_dist)
	_check(mud_dist < wet_dist * 0.5,
		"진흙이 젖음보다 뚜렷하게 더 묶는다 (젖음 %.2f → 진흙 %.2f)" % [wet_dist, mud_dist])
	wet.free()
	mud.free()
	stub.free()


## [4] 🔴 화상 + 물 = **꺼진다**(clear). 바탕도 사라지고 물의 젖음도 안 남는다 — 반응이
## 기본 덮어쓰기를 **이긴다**는 게 계약의 핵심이다.
## 뮤테이션(react 무시) → 젖음이 그냥 덮여 두 번째 줄이 빨개진다.
func _test_burn_plus_water_extinguishes() -> void:
	print("[4] 화상 + 물 = 꺼짐 (반응이 덮어쓰기를 이긴다)")
	var e = await _spawn(&"slime")
	e.apply_status(S_BURN, 1.0)
	e.take_hit(0.0, R_WATER, S_WET, 1.0)
	_check(not e.has_status(S_BURN), "화상이 꺼졌다")
	_check(not e.has_status(S_WET), "씻김 반응이라 젖음도 안 남는다 (기본 덮어쓰기가 아니다)")
	var h0: float = e.hp()
	for i in 70:
		await physics_frame
	_check(is_equal_approx(e.hp(), h0), "더는 타지 않는다 (%.2f → %.2f)" % [h0, e.hp()])
	e.free()


## [5] 🔴 바람 = **확산자**. 맞은 적에게 붙어 있던 상태가 반경(status_spread_px 110) 안의
## 다른 적에게 옮겨 붙는다. 그리고 **바람은 자기 상태를 안 남긴다**(원신 Swirl 모델) —
## 이게 바람의 정체성이라 젖음이 새로 생기면 안 된다.
## 뮤테이션(`spreads()` 분기 제거) → 옆 적이 안 타 첫 줄이 빨개진다.
func _test_wind_spreads_status() -> void:
	print("[5] 바람 — 붙은 상태를 옆 적에게 옮긴다 (자기 상태는 안 남긴다)")
	var a = await _spawn(&"slime")
	var near = await _spawn(&"slime")
	var far = await _spawn(&"slime")
	near.global_position = Vector2(60, 0)     # 반경 110 안
	far.global_position = Vector2(400, 0)     # 반경 밖
	await physics_frame

	a.apply_status(S_BURN, 1.0)
	a.take_hit(0.0, R_WIND, 4, 1.0)  # 4 = FLOW (바람 룬의 status) — 확산자라 안 남아야 한다
	_check(near.has_status(S_BURN), "반경 안의 적에게 화상이 번졌다")
	_check(not far.has_status(S_BURN), "반경 밖 적에겐 안 번졌다")
	_check(not a.has_status(4), "바람은 자기 상태(밀림)를 안 남긴다")
	a.free()
	near.free()
	far.free()


## [6] 🔴 같은 상태 재적용 = **지속시간 갱신 + 더 센 power 채택**. 누적이면 연사만으로 폭발한다.
## 뮤테이션(power를 `+=`로) → 두 번째 줄이 빨개진다.
func _test_reapply_refreshes_not_stacks() -> void:
	print("[6] 재적용 — 누적이 아니라 갱신 (더 센 power 채택)")
	var e = await _spawn(&"slime")
	# 🔴 세션50: 값이 **세기 배율**이라 1.0 언저리로 잡는다 (옛 3.0/5.0은 "초당피해"였다).
	e.apply_status(S_BURN, 1.0)
	_check(is_equal_approx(e.status_power_of(S_BURN), 1.0),
		"첫 화상 배율 1.0 (실제 %.2f)" % e.status_power_of(S_BURN))
	e.apply_status(S_BURN, 0.5)  # 더 약한 재적용
	_check(is_equal_approx(e.status_power_of(S_BURN), 1.0),
		"약하게 다시 걸어도 누적 안 되고 센 쪽이 남는다 (실제 %.2f, 1.5면 누적 버그)"
			% e.status_power_of(S_BURN))
	e.apply_status(S_BURN, 2.0)  # 더 센 재적용
	_check(is_equal_approx(e.status_power_of(S_BURN), 2.0),
		"더 세게 걸면 센 값을 채택한다 (실제 %.2f)" % e.status_power_of(S_BURN))
	e.free()


## [7] 🔴 취약(흙) = **밑작업**. 걸려 있으면 다음에 거는 상태가 `status_vulnerable_mult`(1.5)배
## 세게 걸린다 — 흙이 단독으론 아무것도 아닌데 조합에서 값어치가 생기는 자리.
## ⚠ 취약 자신에겐 안 곱한다(흙만 겹쳐도 무한히 세지면 안 된다).
## 뮤테이션(`power_mult` 곱 제거) → 두 번째 줄이 빨개진다.
func _test_vulnerable_amplifies_next() -> void:
	print("[7] 취약 — 다음에 거는 상태가 더 세게 걸린다")
	var plain = await _spawn(&"slime")
	var vuln = await _spawn(&"slime")
	# 흙 룬은 status를 데이터로 아직 안 들고 오므로(rune .tres 미신설) 0으로 보낸다 —
	# `StatusRules.amplifies()`가 취약을 만드는 규칙이라 그대로 취약이 걸려야 한다.
	vuln.take_hit(0.0, R_EARTH, 0, 1.0)
	_check(vuln.has_status(S_VULNERABLE), "흙이 취약을 남겼다")
	_check(is_equal_approx(vuln.status_power_of(S_VULNERABLE), 1.0),
		"취약 자신은 자기 배율을 안 먹는다 (실제 %.2f)" % vuln.status_power_of(S_VULNERABLE))

	plain.apply_status(S_BURN, 1.0)
	vuln.apply_status(S_BURN, 1.0)
	_check(is_equal_approx(plain.status_power_of(S_BURN), 1.0),
		"취약 없으면 그대로 1.0 (실제 %.2f)" % plain.status_power_of(S_BURN))
	_check(vuln.status_power_of(S_BURN) > plain.status_power_of(S_BURN) + 0.1,
		"취약 위에 걸린 화상이 더 세다 (평시 %.2f → 취약 %.2f)"
			% [plain.status_power_of(S_BURN), vuln.status_power_of(S_BURN)])
	_check(is_equal_approx(vuln.status_power_of(S_BURN), 1.5),
		"정확히 1.0*1.5=1.5 (실제 %.2f)" % vuln.status_power_of(S_BURN))
	plain.free()
	vuln.free()


## [8] 🔴 버스트 피해가 **balance 기준값**을 쓴다 (세션50). 세션49엔 `power × mult`였는데,
## power가 "초당피해 3.0"에서 "배율 1.0"으로 통일되면 피해가 **조용히 1/3로 토막** 난다 —
## 에러도 없고 기존 테스트도 하나도 안 잡았다. 이 테스트가 그 구멍이다.
## 계산 = `status_burst_base(3.0) × power(1.0) × steam_mult(0.8)` = 2.4.
## 뮤테이션(`SR.burst_damage(power, mult)` → `power * mult`) → 0.8이 되어 빨개진다.
func _test_burst_uses_balance_base() -> void:
	print("[8] 버스트 피해 = status_burst_base × 배율 (power만 쓰면 1/3 토막)")
	var a = await _spawn(&"slime")
	var near = await _spawn(&"slime")
	a.global_position = Vector2.ZERO
	near.global_position = Vector2(50, 0)  # 증기 반경(status_steam_px 70) 안
	await physics_frame

	var h0: float = near.hp()
	a.apply_status(S_WET, 1.0)
	a.take_hit(0.0, R_FIRE, S_BURN, 1.0)  # 젖음 + 불 = 증기(burst)
	var dealt: float = h0 - near.hp()
	_check(dealt > 0.0, "옆 적이 증기에 맞았다 (%.2f)" % dealt)
	_check(is_equal_approx(dealt, 2.4),
		"기준값 3.0 × 배율 1.0 × 증기 0.8 = 2.40 (실제 %.2f — 0.80이면 power만 쓴 것)" % dealt)
	a.free()
	near.free()


## [9] 🔴 **이 작업의 존재 이유를 지키는 테스트.** 세기 배율(특별잉크 증폭)이 감전에도 통한다.
## 세션49엔 감속이 balance 고정이라 **번개·흙·풀엔 특별잉크가 아예 안 통했다**(세28~29 경제의 절반).
## 뮤테이션(`SR.move_mult`에서 `* power` 제거) → 두 거리가 같아져 빨개진다.
func _test_power_scales_shock_slow() -> void:
	print("[9] 세기 배율이 감전 감속에도 통한다 (특별잉크가 6룬 전부에 통하는가)")
	var stub := Node2D.new()
	stub.add_to_group("player")
	stub.global_position = Vector2(120, 0)
	root.add_child(stub)

	var weak = await _spawn(&"slime")
	var strong = await _spawn(&"slime")
	weak.apply_status(S_SHOCK, 1.0)
	strong.apply_status(S_SHOCK, 1.8)  # 특별잉크로 증폭된 셈
	var w0: Vector2 = weak.global_position
	var s0: Vector2 = strong.global_position
	for i in 30:
		await physics_frame
	var wd: float = weak.global_position.distance_to(w0)
	var sd: float = strong.global_position.distance_to(s0)
	_check(wd > 0.5, "약한 감전 적은 실제로 움직였다 (%.2fpx)" % wd)
	_check(sd < wd * 0.8,
		"세게 건 감전이 뚜렷하게 더 묶는다 (배율1.0 %.2f → 배율1.8 %.2f)" % [wd, sd])
	weak.free()
	strong.free()
	stub.free()


## [10] 🔴 감속 **상한**(`status_slow_cap` 0.90). 배율이 커져도 완전정지가 되면 안 된다 —
## "느려졌다"와 "죽었다/어그로가 풀렸다"가 구분이 안 가고, [3]이 이미 그 함정을 밟았다.
## ⚠ 클램프가 없으면 `1 - 0.85*5 = -3.25`로 **음수 배율**이 돼 적이 플레이어 **반대로** 튄다 —
## 그래서 "얼마나 움직였나"만 재면 못 잡는다. 방향까지 본다.
## 뮤테이션(`clampf` 제거) → 두 줄 다 빨개진다.
func _test_slow_cap() -> void:
	print("[10] 감속 상한 — 아무리 세도 멈추지도, 거꾸로 가지도 않는다")
	var stub := Node2D.new()
	stub.add_to_group("player")
	stub.global_position = Vector2(120, 0)
	root.add_child(stub)

	var e = await _spawn(&"slime")
	e.apply_status(S_MUD, 5.0)  # 0.85 × 5.0 = 4.25 → cap 0.90으로 잘린다
	var p0: Vector2 = e.global_position
	var far0: float = e.global_position.distance_to(stub.global_position)
	for i in 30:
		await physics_frame
	var moved: float = e.global_position.distance_to(p0)
	var far1: float = e.global_position.distance_to(stub.global_position)
	_check(moved > 0.5, "상한에 걸려도 (느리게나마) 움직인다 = 완전정지가 아니다 (%.2fpx)" % moved)
	_check(far1 < far0,
		"플레이어 쪽으로 갔다 = 배율이 음수로 안 뒤집혔다 (%.2f → %.2f)" % [far0, far1])
	e.free()
	stub.free()


## [11] 🔴 **허수아비도 반응한다** (세션50 빚②). 그전엔 `take_hit`이 상태를 버려서
## **연습장에서 반응을 시험할 수 없었다** — 마법을 만들고 바로 쏴 보는 자리인데.
## 연쇄 피해는 HP가 없어 `status_damage_total()`이 유일한 관측점이다.
## 뮤테이션(dummy의 `_wire_status`/`apply_incoming` 배선 제거) → 전부 빨개진다.
func _test_dummy_reacts() -> void:
	print("[11] 허수아비 — 상태를 받고 반응하고 연쇄가 옆 허수아비에 닿는다")
	var scene = load("res://src/spell/dummy_target.tscn") as PackedScene
	var a = scene.instantiate()
	var near = scene.instantiate()
	root.add_child(a)
	root.add_child(near)
	a.global_position = Vector2.ZERO
	near.global_position = Vector2(60, 0)  # 감전 연쇄 반경(status_shock_chain_px 90) 안
	await process_frame
	await physics_frame

	# ⓐ 반응 산물이 실제로 걸린다 (젖음 + 흙 = 진흙)
	a.apply_status(S_WET, 1.0)
	a.take_hit(0.0, R_EARTH, 0, 1.0)
	_check(a.has_status(S_MUD), "허수아비에 진흙이 생겼다")
	_check(not a.has_status(S_WET), "바탕(젖음)은 반응에 소진됐다")

	# ⓑ 감전 연쇄가 옆 허수아비까지 간다 = 연습장에서 조합이 **눈에 보인다**
	near.apply_status(S_WET, 1.0)
	var before: float = a.status_damage_total()
	near.take_hit(0.0, R_BOLT, S_SHOCK, 1.0)  # 젖음 + 번개 = 감전 연쇄(burst)
	_check(near.has_status(S_SHOCK), "맞은 허수아비에 감전이 남았다")
	_check(a.status_damage_total() > before,
		"연쇄가 옆 허수아비에 닿았다 (%.2f → %.2f)" % [before, a.status_damage_total()])

	# ⓒ DoT가 누적 카운터로 쌓인다 (HP가 없어 이게 유일한 관측점)
	var burnt = scene.instantiate()
	root.add_child(burnt)
	burnt.global_position = Vector2(9000, 0)  # 반경 밖 — 위 연쇄와 섞이지 않게
	await physics_frame
	burnt.apply_status(S_BURN, 1.0)
	var d0: float = burnt.status_damage_total()
	for i in 70:
		await physics_frame
	_check(burnt.status_damage_total() > d0 + 1.0,
		"화상 DoT가 누적됐다 (%.2f → %.2f)" % [d0, burnt.status_damage_total()])
	a.free()
	near.free()
	burnt.free()


## [12] 🔴 **반응 VFX 신호 계약** (세션52). 반응이 해결되면 몸이 `reaction_burst`·`reaction_chain`을
## 올바른 페이로드로 쏴야 vfx.gd가 그린다. 헤드리스는 "보이는지"는 못 잡지만 **신호 발신은 잡는다** —
## 겉모습(아크·링 렌더)은 리드가 실게임 스샷으로 본다.
##  • 감전(젖음+번개) = 버스트 1회(status=SHOCK, radius=shock_chain_px) + 반경 안 대상마다 아크 1가닥.
##  • 증기(젖음+불) = 버스트 1회(status=NONE) · **아크 0**(증기는 링만).
##  • 바람 확산 = 반경 안 대상마다 아크 1가닥(대표 상태색).
## 🔴 뮤테이션: 몸의 `EventBus.reaction_burst.emit`/`reaction_chain.emit` 줄을 지우면 해당 줄이 빨개진다.
##   그리고 두 몸(forest_enemy·dummy_target)이 **같은 계약**을 지키는지 — 여긴 dummy로 본다(연습장 파리티).
func _test_reaction_vfx_signals() -> void:
	print("[12] 반응 VFX 신호 — 감전=버스트+아크 · 증기=버스트만 · 바람=대상마다 아크")
	var bal = load("res://data/balance.tres")
	var scene = load("res://src/spell/dummy_target.tscn") as PackedScene

	var bursts := []
	var chains := []
	var on_burst := func(pos, radius, status) -> void:
		bursts.append({"pos": pos, "radius": radius, "status": status})
	var on_chain := func(from, to, status) -> void:
		chains.append({"from": from, "to": to, "status": status})
	_bus.reaction_burst.connect(on_burst)
	_bus.reaction_chain.connect(on_chain)

	# ── ⓐ 감전 연쇄: 버스트(SHOCK) 1회 + 반경 안 대상 1마리에게 아크 1가닥 ──
	var a = scene.instantiate()
	var near = scene.instantiate()
	root.add_child(a)
	root.add_child(near)
	a.global_position = Vector2.ZERO
	near.global_position = Vector2(60, 0)  # shock_chain_px(90) 안
	await process_frame
	await physics_frame
	near.apply_status(S_WET, 1.0)
	near.take_hit(0.0, R_BOLT, S_SHOCK, 1.0)  # near가 반응원 → near에서 a로 연쇄
	_check(bursts.size() == 1, "감전: 버스트가 정확히 1회 (실제 %d)" % bursts.size())
	if bursts.size() == 1:
		_check(int(bursts[0]["status"]) == S_SHOCK, "감전 버스트 status=SHOCK (실제 %d)" % int(bursts[0]["status"]))
		_check(is_equal_approx(float(bursts[0]["radius"]), bal.status_shock_chain_px),
			"감전 버스트 radius=shock_chain_px %.1f (실제 %.1f)" % [bal.status_shock_chain_px, float(bursts[0]["radius"])])
	_check(chains.size() == 1, "감전: 반경 안 대상 1마리에게 아크 1가닥 (실제 %d)" % chains.size())
	if chains.size() == 1:
		_check(chains[0]["from"].distance_to(near.global_position) < 1.0, "아크가 반응원(near)에서 출발한다")
		_check(chains[0]["to"].distance_to(a.global_position) < 1.0, "아크가 대상(a)에 닿는다")
		_check(int(chains[0]["status"]) == S_SHOCK, "감전 아크 status=SHOCK (실제 %d)" % int(chains[0]["status"]))
	a.free()
	near.free()

	# ── ⓑ 증기: 버스트(NONE) 1회 · 아크 0 (증기는 링만) ──
	bursts.clear()
	chains.clear()
	var s = scene.instantiate()
	var s_near = scene.instantiate()
	root.add_child(s)
	root.add_child(s_near)
	s.global_position = Vector2.ZERO
	s_near.global_position = Vector2(40, 0)  # steam_px(70) 안 — 그래도 아크는 없어야 한다
	await process_frame
	await physics_frame
	s.apply_status(S_WET, 1.0)
	s.take_hit(0.0, R_FIRE, S_BURN, 1.0)  # 젖음 + 불 = 증기(burst, NONE)
	_check(bursts.size() == 1, "증기: 버스트가 정확히 1회 (실제 %d)" % bursts.size())
	if bursts.size() == 1:
		_check(int(bursts[0]["status"]) == 0, "증기 버스트 status=NONE(0) (실제 %d)" % int(bursts[0]["status"]))
	_check(chains.size() == 0, "증기: 아크는 0가닥 — 링만 (실제 %d)" % chains.size())
	s.free()
	s_near.free()

	# ── ⓒ 바람 확산: 반경 안 대상마다 아크 1가닥, 대표 상태색(BURN) ──
	bursts.clear()
	chains.clear()
	var w = scene.instantiate()
	var w_near = scene.instantiate()
	root.add_child(w)
	root.add_child(w_near)
	w.global_position = Vector2.ZERO
	w_near.global_position = Vector2(50, 0)  # spread_px(110) 안
	await process_frame
	await physics_frame
	w.apply_status(S_BURN, 1.0)
	w.take_hit(0.0, R_WIND, 4, 1.0)  # 바람 = 확산자
	_check(chains.size() == 1, "바람: 반경 안 대상 1마리에게 아크 1가닥 (실제 %d)" % chains.size())
	if chains.size() == 1:
		_check(int(chains[0]["status"]) == S_BURN, "바람 아크 색=옮긴 상태(화상) (실제 %d)" % int(chains[0]["status"]))
		_check(chains[0]["to"].distance_to(w_near.global_position) < 1.0, "바람 아크가 옆 표적에 닿는다")
	_check(bursts.size() == 0, "바람: 버스트는 0회 — 확산은 아크만 (실제 %d)" % bursts.size())
	w.free()
	w_near.free()

	_bus.reaction_burst.disconnect(on_burst)
	_bus.reaction_chain.disconnect(on_chain)


# ── 헬퍼 ──

## 적 하나를 스폰한다 — enemy_id는 **_ready 전에** 세워야 _def가 그 적으로 잡힌다.
func _spawn(id):
	var e = _enemy_scene.instantiate()
	e.enemy_id = id
	root.add_child(e)
	await process_frame
	await physics_frame
	return e


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
