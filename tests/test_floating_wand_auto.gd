extends SceneTree
## 떠있는 지팡이 + 발사 총구 계약 자동 검증 — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_floating_wand_auto.gd
## 전 항목 통과 시 "TEST_FLOATING_WAND_OK" 출력 후 종료 코드 0.
##
## 🔴 왜: **발사 원점(총구)은 몸 중심이 아니라 떠있는 지팡이 끝**이다. 이건 발사 계약이라,
## 누가 caster._muzzle()이나 FloatingWand 노드를 되돌리면 **에러 없이 조용히 몸 중심으로 회귀**한다
## (이 프로젝트가 제일 무서워하는 침묵사). 그 회귀를 잡는 그물이다. 공개 경로로만 검증한다 —
## caster.fire()가 EventBus.**`ring_cast_started`**로 실어 보내는 **origin**을 본다(내부 _muzzle 안 찌름).
##
## 🔴 겉보기(둥둥·회전·flip·머즐 연출·지팡이가 실제로 보이나)는 헤드리스가 못 본다 —
## 실게임이 별도 확인한다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일 — 오토로드 식별자·모듈 preload·class_name 참조
## 금지. 첫 프레임 후 load()·/root 접근으로 우회. 지역 변수는 의도적으로 동적 타입.

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
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_FLOATING_WAND_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_gs = root.get_node("/root/GameState")

	# 리터럴 _WAND가 진짜 Enums.ItemKind.WAND와 같은지 런타임 검산(enum이 밀리면 그물이 헛돈다).
	var enums_script = load("res://src/core/enums.gd")
	_check(enums_script.ItemKind.WAND == _WAND, "리터럴 WAND(%d) == Enums.ItemKind.WAND(%d)" % [_WAND, enums_script.ItemKind.WAND])

	_player = (load("res://src/actors/player.tscn") as PackedScene).instantiate()
	root.add_child(_player)
	await process_frame
	_caster = _player.get_node("Caster")
	_wand = _player.get_node_or_null("FloatingWand")
	_check(_wand != null, "player.tscn에 FloatingWand 노드가 있다")
	if _wand == null:
		_finish()
		return

	# 발사가 성립하려면 슬롯0에 진(비어도 emit은 된다)·마나 무소모.
	_gs.ring_equipped[0] = load("res://src/core/schemas/ring_design.gd").new()
	_gs.debug_free_cast = true
	_caster.select_slot(0)

	await _test_no_wand_fallback()
	await _test_wand_muzzle_is_tip()
	_test_muzzle_geometry()

	await _restore_state()
	_finish()


## 🔴🔴 **뒷정리 = 계약이다.** `-s` 테스트는 세이브 뿌리가 `user://save_test`로 격리돼 있을 뿐
## **테스트끼리는 그 파일을 공유한다** — [2]가 지팡이를 낀 채 끝내고 `equipment_changed`가
## 자동 저장을 부르면, 남은 지팡이가 세이브에 박혀 **뒤에 도는 `test_workshop_auto`가 그걸
## 로드**한다(거기서 「맨손 기준값」으로 잰 값이 지팡이 낀 값이 돼 2건이 빨개졌다).
## 🔴 이 빨강은 **전체 스위트로 돌 때만 난다** — 파일 하나만 돌리면 그린이라 오래 안 보였다.
## ⚠ 저장은 `call_deferred`라 **프레임을 흘려야** 깨끗한 상태가 실제로 쓰인다.
func _restore_state() -> void:
	_gs.equipment.erase(_WAND)
	_gs.ring_equipped[0] = null
	_bus.equipment_changed.emit()
	await process_frame
	await process_frame


## [1] 지팡이 미장착 → 숨김 + 발사 origin = 몸 중심(폴백)
func _test_no_wand_fallback() -> void:
	print("[1] 지팡이 미장착 → FloatingWand 숨김 + 발사 origin == 몸 중심(맨손 폴백)")
	_gs.equipment.erase(_WAND)
	_bus.equipment_changed.emit()
	await process_frame
	await process_frame
	_check(not _wand.visible, "지팡이 없으면 FloatingWand.visible == false")
	var origin = _capture_fire_origin()
	_check(origin.distance_to(_player.global_position) < 0.5,
		"발사 origin이 몸 중심 폴백 (dist=%.1f)" % origin.distance_to(_player.global_position))


## [2] 지팡이 장착 → 표시 + 발사 origin = 지팡이 끝, 몸과 뚜렷이 떨어짐
func _test_wand_muzzle_is_tip() -> void:
	print("[2] 지팡이 장착 → FloatingWand 표시 + 발사 origin == 지팡이 끝(muzzle)")
	_gs.equipment[_WAND] = &"wand_basic"
	_bus.equipment_changed.emit()
	await process_frame
	await process_frame
	_check(_wand.visible, "지팡이 장착이면 FloatingWand.visible == true")
	var origin = _capture_fire_origin()
	var tip = _wand.muzzle_position()
	_check(origin.distance_to(tip) < 0.5,
		"발사 origin == 지팡이 끝 muzzle_position (dist=%.1f)" % origin.distance_to(tip))
	# 🔴 핵심 계약: 총구가 몸이 아니라 지팡이 끝 — 뚜렷이 떨어져 있어야 한다(뮤테이션 검출자).
	_check(origin.distance_to(_player.global_position) > 5.0,
		"발사 origin이 몸 중심과 뚜렷이 떨어짐 (tip, dist=%.1f)" % origin.distance_to(_player.global_position))


## [3] 총구 기하 단일 소스 — 알려진 위치/회전에서 tip이 MUZZLE_LEN 오프셋과 일치
func _test_muzzle_geometry() -> void:
	print("[3] 총구 기하 단일 소스 — muzzle_position이 MUZZLE_LEN 오프셋과 일치")
	# _process가 매 프레임 덮으므로, 값을 세팅한 직후(프레임 사이 없이) 동기 호출로 잰다.
	_player.global_position = Vector2.ZERO
	_wand.position = Vector2.ZERO
	_wand.rotation = 0.0
	var tip = _wand.muzzle_position()
	# MUZZLE_LEN(14)만큼 로컬 +X → 월드 (14,0). 상수를 베끼지 않고 노드가 실제로 그만큼 앞을 가리키는지만 본다.
	_check(tip.distance_to(Vector2(_wand.MUZZLE_LEN, 0.0)) < 0.5,
		"tip == (MUZZLE_LEN, 0) at 원점·무회전 (tip=%s)" % str(tip))
	_check(_wand.MUZZLE_LEN > 0.0, "MUZZLE_LEN이 앞(+)을 가리킨다")


## caster.fire()가 실어 보내는 origin을 한 번 붙잡는다(공개 계약 경로).
##
## 🔴🔴 **관측점은 `ring_cast_requested`가 아니라 `ring_cast_started`다.** 발사가 지연 emit이라
## `ring_cast_requested`는 이 함수가 돌아온 **한참 뒤에** 온다 —
## `connect → fire() → await 없이 disconnect`라 콜백이 영영 안 불려 origin이 `Vector2.INF`로 남고
## **총구 단일 소스의 유일한 그물이 조용히 죽는다**.
## `ring_cast_started`에도 **같은 `_muzzle()` 값**이 실리므로 동기 관측이 그대로 유지된다.
## ⚠ 여기에 `await`를 넣지 마라 — 시전 시간을 조일 때마다 이 그물이 다시 낡는다.
func _capture_fire_origin():
	var captured := {"origin": Vector2.INF}
	var cb := func(_assembly, origin, _duration) -> void:
		if captured["origin"] == Vector2.INF:
			captured["origin"] = origin
	_bus.ring_cast_started.connect(cb)
	_caster.fire()
	_bus.ring_cast_started.disconnect(cb)
	# 🔴 걸린 시전을 끊는다 — 안 끊으면 **다음 호출의 `fire()`가 연사 차단에 걸려** origin이 INF로
	#   남는다(마나는 안 돌아온다. 여긴 debug_free_cast라 무관).
	_caster.cancel_cast()
	return captured["origin"]


func _check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		print("  ✗ FAIL: ", label)


func _finish() -> void:
	if _player != null:
		_player.queue_free()
	if failures == 0:
		print("TEST_FLOATING_WAND_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_FLOATING_WAND_FAIL — %d개 실패" % failures)
		quit(1)
