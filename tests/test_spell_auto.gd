extends SceneTree
## 모듈 B 자동 검증 (TEAM_PLAN DoD) — 헤드리스 실행:
##   ./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_spell_auto.gd
## 전 항목 통과 시 "TEST_SPELL_OK" 출력 후 종료 코드 0.
##
## 주의: -s 모드에서는 이 스크립트가 오토로드 전역 등록보다 먼저 컴파일되므로
## 오토로드 식별자·모듈 스크립트 preload를 쓰지 않는다 — 첫 프레임 후 load()·/root 접근.
## 같은 이유로 이 파일의 지역 변수는 의도적으로 동적 타입이다 (게임 코드 규칙과 별개).

const ANGLE_TOL_RAD := 0.0175  # ±1도

var failures: int = 0
var executed_log: Array[Dictionary] = []
var failed_log: Array[Dictionary] = []
var hit_log: Array[Dictionary] = []

var _bus = null
var _gs = null
var _db = null
var _dummy_scene: PackedScene = null

func _init() -> void:
	_run()

func _run() -> void:
	# 코루틴이 어디선가 멈춰도 프로세스가 붙잡히지 않게 워치독
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_SPELL_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")

	var system_scene := load("res://src/spell/spell_system.tscn") as PackedScene
	_dummy_scene = load("res://src/spell/dummy_target.tscn") as PackedScene
	var system = system_scene.instantiate()
	root.add_child(system)

	_bus.cast_executed.connect(func(design: SpellDesign, mana_spent: float) -> void:
		executed_log.append({"design": design, "mana": mana_spent}))
	_bus.cast_failed.connect(func(design: SpellDesign, reason: int) -> void:
		failed_log.append({"design": design, "reason": reason}))
	_bus.enemy_hit.connect(func(enemy: Node2D, damage: float, rune_type: int) -> void:
		hit_log.append({"enemy": enemy, "damage": damage, "rune_type": rune_type}))

	await _test_nova(system)
	await _test_shotgun(system)
	await _test_lance(system)
	await _test_fail_reasons(system)
	await _test_dummy_hit(system)

	if failures == 0:
		print("TEST_SPELL_OK — 전 항목 통과")
	else:
		print("TEST_SPELL_FAIL — 실패 %d건" % failures)
	quit(1 if failures > 0 else 0)

# ── 개별 테스트 ──────────────────────────────────────────────

func _test_nova(system) -> void:
	print("[1] 노바 (FIXED) — 8발, 절대각 0/45/../315도")
	executed_log.clear()
	_gs.restore_mana_full()
	var design := SampleDesigns.nova_fire()
	var durability_before := design.durability
	_bus.cast_requested.emit(design, Vector2(100, 100), Vector2.RIGHT)
	var projs := _projectiles(system)
	_check(projs.size() == 8, "투사체 8개 (실제 %d)" % projs.size())
	var angles_ok := projs.size() == 8
	for i in range(projs.size()):
		var expected := TAU * float(i) / 8.0
		if not _angle_close(projs[i].direction_angle, expected):
			angles_ok = false
			print("    각도[%d]=%.2f도, 기대=%.2f도" % [i, rad_to_deg(projs[i].direction_angle), rad_to_deg(expected)])
	_check(angles_ok, "8발 각도 전부 ±1도 이내")
	_check(design.durability == durability_before - 1,
		"내구 1 차감 (%d→%d)" % [durability_before, design.durability])
	_check(executed_log.size() == 1 and is_equal_approx(float(executed_log[0]["mana"]), design.mana_cost),
		"cast_executed 1회 (mana=%.0f)" % design.mana_cost)
	await _clear_projectiles(system)

func _test_shotgun(system) -> void:
	print("[2] 산탄 (AIMED) — 에임 (1,0)/(0,1) 상대 회전")
	var offsets: Array[float] = [-0.26, 0.0, 0.26]
	for aim: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
		_gs.restore_mana_full()
		var design := SampleDesigns.aimed_shotgun_impact()
		_bus.cast_requested.emit(design, Vector2.ZERO, aim)
		var projs := _projectiles(system)
		_check(projs.size() == 3, "aim=%s 투사체 3개 (실제 %d)" % [aim, projs.size()])
		var angles_ok := projs.size() == 3
		for i in range(projs.size()):
			var expected := offsets[i] - design.aim_axis + aim.angle()
			if not _angle_close(projs[i].direction_angle, expected):
				angles_ok = false
				print("    각도[%d]=%.2f도, 기대=%.2f도" % [i, rad_to_deg(projs[i].direction_angle), rad_to_deg(expected)])
		_check(angles_ok, "aim=%s 3발 각도가 에임에 상대 회전" % aim)
		await _clear_projectiles(system)

func _test_lance(system) -> void:
	print("[3] 물의 창 — 1발, magnitude 1.0 위력 배율")
	_gs.restore_mana_full()
	var design := SampleDesigns.aimed_lance_water()
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var projs := _projectiles(system)
	_check(projs.size() == 1, "투사체 1개 (실제 %d)" % projs.size())
	if projs.size() == 1:
		var rune = _db.get_rune(Enums.RuneType.WATER)
		_check(rune != null, "Db에 물 룬 등록됨")
		var rune_coef: float = rune.base_damage if rune != null else 1.0
		var expected: float = system.balance.projectile_base_damage \
			* (float(system.balance.magnitude_damage_base) + 1.0) \
			* maxf(design.rune_accuracy, system.balance.accuracy_floor) \
			* rune_coef
		_check(is_equal_approx(float(projs[0].damage), expected),
			"위력 %.2f = 기대 %.2f" % [projs[0].damage, expected])
		_check(int(projs[0].status) == Enums.Status.WET, "status=WET 전달")
	await _clear_projectiles(system)

func _test_fail_reasons(system) -> void:
	print("[4] 실패 사유 — NO_MANA / BROKEN")
	failed_log.clear()
	_gs.mana = 0.0
	var design := SampleDesigns.aimed_lance_water()
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	_check(failed_log.size() == 1 and int(failed_log[0]["reason"]) == Enums.CastFailReason.NO_MANA,
		"cast_failed(NO_MANA)")
	_check(_projectiles(system).is_empty(), "마나 부족 시 투사체 없음")

	_gs.restore_mana_full()
	var broken := SampleDesigns.nova_fire()
	broken.durability = 0
	var mana_before: float = _gs.mana
	_bus.cast_requested.emit(broken, Vector2.ZERO, Vector2.RIGHT)
	_check(failed_log.size() == 2 and int(failed_log[1]["reason"]) == Enums.CastFailReason.BROKEN,
		"cast_failed(BROKEN)")
	_check(absf(float(_gs.mana) - mana_before) < 0.5, "손상 도안은 마나 미소모")
	_check(_projectiles(system).is_empty(), "손상 도안 투사체 없음")

func _test_dummy_hit(system) -> void:
	print("[5] 허수아비 명중 — take_hit 호출·enemy_hit 발신")
	_gs.restore_mana_full()
	hit_log.clear()
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(140, 0)
	var design := SampleDesigns.aimed_lance_water()
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2(1, 0))
	var frames := 0
	while dummy.hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	_check(not dummy.hits.is_empty(), "take_hit 호출됨 (%d 물리 프레임 후)" % frames)
	if not dummy.hits.is_empty():
		var hit: Dictionary = dummy.hits[0]
		_check(int(hit["status"]) == Enums.Status.WET and float(hit["status_power"]) > 0.0,
			"WET 상태·status_power 전달")
	_check(not hit_log.is_empty(), "EventBus.enemy_hit 발신")
	if not hit_log.is_empty():
		_check(hit_log[0]["enemy"] == dummy, "enemy_hit 대상 = 허수아비")
	dummy.queue_free()
	await _clear_projectiles(system)

# ── 헬퍼 ─────────────────────────────────────────────────────

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)

func _angle_close(a: float, b: float) -> bool:
	return absf(wrapf(a - b, -PI, PI)) <= ANGLE_TOL_RAD

func _projectiles(system) -> Array:
	var out := []
	for child in system.get_children():
		if child.is_in_group("player_projectiles"):
			out.append(child)
	return out

func _clear_projectiles(system) -> void:
	for p in _projectiles(system):
		p.queue_free()
	await process_frame
