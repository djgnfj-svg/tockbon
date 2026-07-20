extends SceneTree
## 상태이상·원소 반응 자동 검증 (세션 49) — 헤드리스 실행:
##   ./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_status_auto.gd
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

	e.take_hit(0.0, R_FIRE, S_BURN, 3.0)  # 직격 피해 0 — 순수 DoT만 본다
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
	wet.apply_status(S_WET, 0.35)
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
	wet.take_hit(0.0, R_WATER, S_WET, 0.35)
	mud.apply_status(S_WET, 0.35)
	mud.take_hit(0.0, R_EARTH, 0, 0.35)  # 흙 룬이 젖음 위에 온다
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
	e.apply_status(S_BURN, 3.0)
	e.take_hit(0.0, R_WATER, S_WET, 0.35)
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

	a.apply_status(S_BURN, 3.0)
	a.take_hit(0.0, R_WIND, 4, 60.0)  # 4 = FLOW (바람 룬의 status) — 확산자라 안 남아야 한다
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
	e.apply_status(S_BURN, 3.0)
	_check(is_equal_approx(e.status_power_of(S_BURN), 3.0),
		"첫 화상 power 3.0 (실제 %.2f)" % e.status_power_of(S_BURN))
	e.apply_status(S_BURN, 1.0)  # 더 약한 재적용
	_check(is_equal_approx(e.status_power_of(S_BURN), 3.0),
		"약하게 다시 걸어도 누적 안 되고 센 쪽이 남는다 (실제 %.2f, 4.0이면 누적 버그)"
			% e.status_power_of(S_BURN))
	e.apply_status(S_BURN, 5.0)  # 더 센 재적용
	_check(is_equal_approx(e.status_power_of(S_BURN), 5.0),
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

	plain.apply_status(S_BURN, 3.0)
	vuln.apply_status(S_BURN, 3.0)
	_check(is_equal_approx(plain.status_power_of(S_BURN), 3.0),
		"취약 없으면 그대로 3.0 (실제 %.2f)" % plain.status_power_of(S_BURN))
	_check(vuln.status_power_of(S_BURN) > plain.status_power_of(S_BURN) + 0.1,
		"취약 위에 걸린 화상이 더 세다 (평시 %.2f → 취약 %.2f)"
			% [plain.status_power_of(S_BURN), vuln.status_power_of(S_BURN)])
	_check(is_equal_approx(vuln.status_power_of(S_BURN), 4.5),
		"정확히 3.0*1.5=4.5 (실제 %.2f)" % vuln.status_power_of(S_BURN))
	plain.free()
	vuln.free()


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
