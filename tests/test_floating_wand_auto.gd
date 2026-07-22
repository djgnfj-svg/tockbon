extends SceneTree
## 떠있는 지팡이 + 발사 총구 계약 자동 검증 (세션65 — 세피리아식 떠있는 지팡이) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_floating_wand_auto.gd
## 전 항목 통과 시 "TEST_FLOATING_WAND_OK" 출력 후 종료 코드 0.
##
## 🔴 왜: 이 세션이 **발사 원점(총구)을 몸 중심 → 떠있는 지팡이 끝**으로 바꿨다. 이건 발사 계약이라,
## 누가 caster._muzzle()이나 FloatingWand 노드를 되돌리면 **에러 없이 조용히 몸 중심으로 회귀**한다
## (이 프로젝트가 제일 무서워하는 침묵사). 그 회귀를 잡는 그물이다. 공개 경로로만 검증한다 —
## caster.fire()가 EventBus.ring_cast_requested로 실어 보내는 **origin**을 본다(내부 _muzzle 안 찌름).
##
## [1] 지팡이 미장착 → FloatingWand 숨김 + 발사 origin == 몸 중심(폴백, 맨손 캐스팅 보존)
## [2] 지팡이 장착 → FloatingWand 표시 + 발사 origin == 지팡이 끝(muzzle_position) + 몸과 뚜렷이 떨어짐
##     (총구가 몸이 아니라 지팡이 끝이라는 **계약 자체**를 잰다 — 뮤테이션 검출자)
## [3] 총구 기하 단일 소스 — 알려진 위치·회전에서 muzzle_position()이 MUZZLE_LEN 오프셋과 일치
##     (총구 지오메트리를 caster에 복제하면 갈라진다 — 단일 소스 가드)
##
## 🔴 겉보기(둥둥·회전·flip·머즐 연출·지팡이가 실제로 보이나)는 헤드리스가 못 본다 —
## 실게임 MCP가 별도 확인(세65에 4방향 조준·발사 tip 스폰·bob ±2.5px 실측).
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

	_finish()


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
func _capture_fire_origin():
	var captured := {"origin": Vector2.INF}
	var cb := func(_assembly, origin, _aim) -> void:
		if captured["origin"] == Vector2.INF:
			captured["origin"] = origin
	_bus.ring_cast_requested.connect(cb)
	_caster.fire()
	_bus.ring_cast_requested.disconnect(cb)
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
