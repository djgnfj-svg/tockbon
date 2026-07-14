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
var _ink = null  # src/core/ink_render.gd — 오토로드가 아니므로 런타임 load()
var _dummy_scene: PackedScene = null

## 그린 화살표 획 (ArrowData.path 계약: 시작=원점, +X=발사방향, 캔버스 단위).
## 살짝 휜 4점 — 머리는 (0.2, 0)이므로 월드 길이 = 0.2 × unit_px
func _arrow_path() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.06, -0.02), Vector2(0.13, -0.015), Vector2(0.2, 0.0),
	])

## path와 같은 리샘플 인덱스의 필압 (ArrowData.path_pressures) — 눌렀다 떼는 획
func _arrow_pressures() -> PackedFloat32Array:
	return PackedFloat32Array([0.3, 0.9, 0.7, 0.2])

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
	_ink = load("res://src/core/ink_render.gd")

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
	await _test_fixed_legacy(system)
	await _test_shotgun(system)
	await _test_lance(system)
	await _test_fail_reasons(system)
	await _test_dummy_hit(system)
	await _test_ink_projectile(system)
	await _test_cast_circle(system)
	await _test_no_strokes_fallback(system)
	await _test_role_axes(system)
	await _test_rune_density_axis(system)

	if failures == 0:
		print("TEST_SPELL_OK — 전 항목 통과")
	else:
		print("TEST_SPELL_FAIL — 실패 %d건" % failures)
	quit(1 if failures > 0 else 0)

# ── 개별 테스트 ──────────────────────────────────────────────

## 진이 한 종류(AIMED)가 된 근거를 그대로 테스트로 만든다 (GDD v1.5 §4.1):
## **대칭 노바는 통째로 회전해도 노바다** — 그래서 고정진 없이도 노바가 성립한다.
## 인덱스별 절대각이 아니라 "45도 균등 간격이 에임과 무관하게 유지되는가"를 검사한다.
func _test_nova(system) -> void:
	print("[1] 노바 — 8발 45도 균등. 에임이 바뀌면 통째로 돌 뿐 간격은 불변")
	for aim_deg: float in [0.0, 90.0, 137.0]:
		_gs.restore_mana_full()
		var design := SampleDesigns.nova_fire()
		var aim := Vector2.RIGHT.rotated(deg_to_rad(aim_deg))
		_bus.cast_requested.emit(design, Vector2(100, 100), aim)
		var projs := _projectiles(system)
		_check(projs.size() == 8, "에임 %.0f도 — 투사체 8개 (실제 %d)" % [aim_deg, projs.size()])
		if projs.size() == 8:
			_check(_gaps_uniform(projs, 8), "에임 %.0f도 — 8발이 45도 균등 간격" % aim_deg)
			# 도안 전체가 에임을 따라 돈다 — 회전량은 투사체·마법진이 공유하는 aim - aim_axis
			_check(_has_angle(projs, aim.angle() - design.aim_axis),
				"에임 %.0f도 — 도안이 aim - aim_axis 만큼 통째 회전" % aim_deg)
		await _clear_projectiles(system)

	# 내구·마나 차감은 에임과 무관 — 1회 캐스팅으로 확인
	executed_log.clear()
	_gs.restore_mana_full()
	var d := SampleDesigns.nova_fire()
	var durability_before := d.durability
	_bus.cast_requested.emit(d, Vector2(100, 100), Vector2.RIGHT)
	_check(d.durability == durability_before - 1,
		"내구 1 차감 (%d→%d)" % [durability_before, d.durability])
	_check(executed_log.size() == 1 and is_equal_approx(float(executed_log[0]["mana"]), d.mana_cost),
		"cast_executed 1회 (mana=%.0f)" % d.mana_cost)
	await _clear_projectiles(system)

## FIXED는 v1.5에서 폐지됐지만 **구세이브가 들고 있는 값**이라 발사 경로는 살아 있어야 한다.
func _test_fixed_legacy(system) -> void:
	print("[1b] 구세이브 FIXED — 에임을 무시하고 절대각 그대로 (호환 경로 회귀 방지)")
	_gs.restore_mana_full()
	var design := SampleDesigns.nova_fire()
	design.circle_type = Enums.CircleType.FIXED
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2(0, 1))  # 에임 90도 — 무시돼야 한다
	var projs := _projectiles(system)
	_check(projs.size() == 8, "투사체 8개 (실제 %d)" % projs.size())
	var angles_ok := projs.size() == 8
	for i in range(projs.size()):
		var expected := TAU * float(i) / 8.0
		if not _angle_close(projs[i].direction_angle, expected):
			angles_ok = false
			print("    각도[%d]=%.2f도, 기대=%.2f도" % [i, rad_to_deg(projs[i].direction_angle), rad_to_deg(expected)])
	_check(angles_ok, "에임 90도여도 절대각 0/45/../315 유지")
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
	print("[3] 물의 창 — 1발, **진 규모** 위력 배율 (TECH_SPEC §4.0)")
	_gs.restore_mana_full()
	var design := SampleDesigns.aimed_lance_water()
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var projs := _projectiles(system)
	_check(projs.size() == 1, "투사체 1개 (실제 %d)" % projs.size())
	if projs.size() == 1:
		var rune = _db.get_rune(Enums.RuneType.WATER)
		_check(rune != null, "Db에 물 룬 등록됨")
		var rune_coef: float = rune.base_damage if rune != null else 1.0
		# v1.7 위력 = 기본 × (circle_damage_base + 진 크기) × 룬 계수 — magnitude·accuracy 무관
		var expected: float = system.balance.projectile_base_damage \
			* (float(system.balance.circle_damage_base) + design.circle_radius) \
			* rune_coef
		_check(is_equal_approx(float(projs[0].damage), expected),
			"위력 %.2f = 기대 %.2f (진 %.2f 기준)" % [projs[0].damage, expected, design.circle_radius])
		_check(int(projs[0].status) == Enums.Status.WET, "status=WET 전달")
		_check(is_equal_approx(float(projs[0].status_power),
				_expected_status_power(system, design, rune)),
			"상태이상 세기 %.3f = 기대 %.3f (룬 농도 축)"
				% [projs[0].status_power, _expected_status_power(system, design, rune)])
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

func _test_ink_projectile(system) -> void:
	print("[6] 먹선 투사체 — 그린 획이 그대로 탄이 된다 (TECH_SPEC §4.4)")
	_gs.restore_mana_full()
	var path := _arrow_path()
	var design := _ink_design(Enums.CircleType.FIXED, 0.0, 0.5)
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var projs := _projectiles(system)
	_check(projs.size() == 1, "투사체 1개 (실제 %d)" % projs.size())
	if projs.size() == 1:
		var proj = projs[0]
		var line: Line2D = _find_line(proj)
		_check(line != null, "투사체에 Line2D 먹선 자식 생성")
		if line != null:
			_check(line.points.size() == path.size(),
				"점 개수 %d = 그린 획 %d" % [line.points.size(), path.size()])
			var head: Vector2 = line.points[line.points.size() - 1]
			_check(head.length() < 0.01, "머리(마지막 점) = 노드 원점 (오차 %.4fpx)" % head.length())
			var px: float = _ink.unit_px(system.balance)
			var expected_len: float = path[path.size() - 1].x * px
			var tail_len: float = line.points[0].length()
			_check(absf(tail_len - expected_len) < 0.01,
				"꼬리 길이 %.1fpx = 그린 길이 × unit_px(%.0f) = %.1fpx" % [tail_len, px, expected_len])
			_check(line.points[0].x < 0.0, "획이 머리 뒤로 끌린다 (꼬리 x=%.1f < 0)" % line.points[0].x)
			# 붓을 누른 그대로 날아간다 — 진에만 붓맛이 있고 탄에는 없는 비대칭 방지
			_check(line.width_curve != null, "필압 → width_curve 배선됨 (굵기 변화 보존)")
		# 먹선은 그린 크기가 곧 크기 — 루트 scale 이중 적용 금지. 히트박스만 진 규모 배율
		var size_scale: float = lerpf(system.balance.circle_size_min,
			system.balance.circle_size_max, design.circle_radius)
		_check(proj.scale.is_equal_approx(Vector2.ONE),
			"루트 scale 미적용 (실제 %.2f — 먹선 이중 확대 방지)" % proj.scale.x)
		_check(is_equal_approx(proj.get_node("Shape").scale.x, size_scale),
			"히트박스는 **진 규모** 배율 (%.2f)" % size_scale)
		_check(not proj.get_node("Visual").visible, "기존 폴리곤 비주얼 숨김")
	await _clear_projectiles(system)

	# 마우스로 그린 획 — path는 있지만 필압이 없다. 균일 굵기로 폴백하고 크래시 없어야 한다
	_gs.restore_mana_full()
	var no_press := _ink_design(Enums.CircleType.FIXED, 0.0, 0.5, false)
	_bus.cast_requested.emit(no_press, Vector2.ZERO, Vector2.RIGHT)
	var np := _projectiles(system)
	_check(np.size() == 1, "필압 없는 path도 발사됨 (실제 %d)" % np.size())
	if np.size() == 1:
		var nline: Line2D = _find_line(np[0])
		_check(nline != null, "필압 없어도 먹선은 그려진다")
		if nline != null:
			_check(nline.width_curve == null, "필압 없으면 균일 굵기 폴백 (width_curve null)")
			_check(nline.points[nline.points.size() - 1].length() < 0.01, "머리 오프셋은 그대로 원점")
	await _clear_projectiles(system)

func _test_cast_circle(system) -> void:
	print("[7] 캐스팅 마법진 — 발밑에 내가 그린 진이 펼쳐졌다 사라진다")
	_gs.restore_mana_full()
	var aim := Vector2(0, 1)
	var aim_axis := 0.4
	var origin := Vector2(64, 32)
	var design := _ink_design(Enums.CircleType.AIMED, aim_axis, 0.5)
	_bus.cast_requested.emit(design, origin, aim)
	var circle = _cast_circle(system)
	_check(circle != null, "연출 노드 생성됨")
	if circle != null:
		_check(circle.global_position.is_equal_approx(origin),
			"진 중심 = 캐스팅 원점 %s (실제 %s)" % [origin, circle.global_position])
		var expected_rot: float = aim.angle() - aim_axis
		_check(_angle_close(circle.rotation, expected_rot),
			"AIMED rotation = aim_angle - aim_axis = %.1f도 (실제 %.1f도)"
				% [rad_to_deg(expected_rot), rad_to_deg(circle.rotation)])
		_check(circle.z_index < 0, "z_index %d — 지형 위·플레이어 아래" % circle.z_index)
		_check(not (circle is CollisionObject2D), "충돌 없는 순수 비주얼")
		# build_design 기본 필터: 화살표는 진에 남지 않는다 (투사체로 날아가므로)
		_check(_count_lines(circle) == 1,
			"진 획만 렌더 — 화살표 획 제외 (Line2D %d개)" % _count_lines(circle))
	await create_timer(0.8).timeout  # 연출 총 0.4초
	_check(_cast_circle(system) == null, "연출 종료 후 자동 소멸")
	await _clear_projectiles(system)

	_gs.restore_mana_full()
	var fixed := _ink_design(Enums.CircleType.FIXED, 0.0, 0.5)
	_bus.cast_requested.emit(fixed, Vector2.ZERO, Vector2(0, 1))
	var fixed_circle = _cast_circle(system)
	_check(fixed_circle != null and is_zero_approx(fixed_circle.rotation),
		"FIXED 진은 에임과 무관하게 rotation 0")
	await _clear_projectiles(system)

func _test_no_strokes_fallback(system) -> void:
	print("[8] 폴백 — strokes·path 없는 도안 (샘플·구세이브 회귀 방지)")
	_gs.restore_mana_full()
	var design := SampleDesigns.aimed_lance_water()  # strokes 없음, arrows[].path 비어 있음
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	_check(_cast_circle(system) == null, "strokes 없으면 마법진 조용히 스킵 (크래시 없음)")
	var projs := _projectiles(system)
	_check(projs.size() == 1, "폴백 투사체 정상 발사 (실제 %d)" % projs.size())
	if projs.size() == 1:
		_check(_find_line(projs[0]) == null, "path 없으면 먹선 없음 — 기존 스프라이트/폴리곤")
		_check(projs[0].scale.x > 1.0,
			"폴백은 루트 scale에 진 규모 배율 적용 (scale=%.2f)" % projs[0].scale.x)
	await _clear_projectiles(system)

## 역할 축 회귀 방지 (TECH_SPEC §4.0) — **진 = 규모 / 룬 = 속성 / 문양 = 방식**.
## 중간 표현이 아니라 **실제 투사체가 들고 나가는 값**(damage·Shape.scale·_life_left)으로 검증한다.
## 세션 7 교훈: ArrowData.direction만 보던 테스트가 초록인 채로 모든 문양이 90도 틀어져 나갔다.
func _test_role_axes(system) -> void:
	print("[9] 역할 축 — 진이 규모를 정하고, 문양 길이는 위력을 못 건드린다")

	# (1) 진이 크면 위력·탄 크기·사거리가 **셋 다** 커진다
	_gs.restore_mana_full()
	var small := _ink_design(Enums.CircleType.AIMED, -PI / 2.0, 0.5)
	small.circle_radius = 0.2
	_bus.cast_requested.emit(small, Vector2.ZERO, Vector2.RIGHT)
	var sp := _projectiles(system)
	var s_dmg := 0.0
	var s_size := 0.0
	var s_life := 0.0
	if sp.size() == 1:
		s_dmg = float(sp[0].damage)
		s_size = float(sp[0].get_node("Shape").scale.x)
		s_life = float(sp[0]._life_left)
	_check(sp.size() == 1, "작은 진 — 투사체 1개 (실제 %d)" % sp.size())
	await _clear_projectiles(system)

	_gs.restore_mana_full()
	var big := _ink_design(Enums.CircleType.AIMED, -PI / 2.0, 0.5)
	big.circle_radius = 0.9
	_bus.cast_requested.emit(big, Vector2.ZERO, Vector2.RIGHT)
	var bp := _projectiles(system)
	_check(bp.size() == 1, "큰 진 — 투사체 1개 (실제 %d)" % bp.size())
	if sp.size() == 1 and bp.size() == 1:
		var b_dmg := float(bp[0].damage)
		var b_size := float(bp[0].get_node("Shape").scale.x)
		var b_life := float(bp[0]._life_left)
		_check(b_dmg > s_dmg, "진 0.9가 진 0.2보다 아프다 (%.1f > %.1f)" % [b_dmg, s_dmg])
		_check(b_size > s_size, "진 0.9의 탄이 더 크다 (%.2f > %.2f)" % [b_size, s_size])
		_check(b_life > s_life, "진 0.9의 탄이 더 멀리 간다 (수명 %.2f > %.2f초)" % [b_life, s_life])
	await _clear_projectiles(system)

	# (2) **문양 길이는 위력을 못 바꾼다** — v1.6에서 magnitude를 전투 스탯에서 뗐다.
	#     진·룬·정확도가 같으면 magnitude가 0.05든 1.0이든 위력·크기·사거리가 동일해야 한다
	_gs.restore_mana_full()
	var short_arrow := _ink_design(Enums.CircleType.AIMED, -PI / 2.0, 0.05)
	short_arrow.circle_radius = 0.5
	_bus.cast_requested.emit(short_arrow, Vector2.ZERO, Vector2.RIGHT)
	var shp := _projectiles(system)
	var short_dmg := float(shp[0].damage) if shp.size() == 1 else -1.0
	var short_size := float(shp[0].get_node("Shape").scale.x) if shp.size() == 1 else -1.0
	var short_life := float(shp[0]._life_left) if shp.size() == 1 else -1.0
	await _clear_projectiles(system)

	_gs.restore_mana_full()
	var long_arrow := _ink_design(Enums.CircleType.AIMED, -PI / 2.0, 1.0)
	long_arrow.circle_radius = 0.5
	_bus.cast_requested.emit(long_arrow, Vector2.ZERO, Vector2.RIGHT)
	var lgp := _projectiles(system)
	_check(shp.size() == 1 and lgp.size() == 1, "긴 문양·짧은 문양 둘 다 발사됨")
	if shp.size() == 1 and lgp.size() == 1:
		_check(is_equal_approx(float(lgp[0].damage), short_dmg),
			"문양 길이는 위력에 영향 없음 (긴 %.2f = 짧은 %.2f)" % [lgp[0].damage, short_dmg])
		_check(is_equal_approx(float(lgp[0].get_node("Shape").scale.x), short_size),
			"문양 길이는 탄 크기에 영향 없음 (%.2f)" % short_size)
		_check(is_equal_approx(float(lgp[0]._life_left), short_life),
			"문양 길이는 사거리에 영향 없음 (%.2f초)" % short_life)
	await _clear_projectiles(system)

	# (3) 한 도안의 모든 탄은 규모가 같다 — 문양은 방식(방향·기점)만 정하므로
	_gs.restore_mana_full()
	var nova := SampleDesigns.nova_fire()
	_bus.cast_requested.emit(nova, Vector2.ZERO, Vector2.RIGHT)
	var np2 := _projectiles(system)
	if np2.size() > 1:
		var same := true
		for p in np2:
			if not is_equal_approx(float(p.damage), float(np2[0].damage)):
				same = false
		_check(same, "노바 %d발 전부 같은 위력 (규모는 진이 정하므로)" % np2.size())
	await _clear_projectiles(system)

## 룬 = 속성 + **농도** 축 (v1.7, TECH_SPEC §4.0).
## 룬 크기(rune_fill)는 상태이상 **세기**만 정하고 위력은 절대 못 건드린다 — 위력은 진의 축이다.
## 인식 정확도(rune_accuracy)도 v1.7에서 위력에서 떨어져 나와 **속성 순도**가 됐다.
## 세션 7 교훈대로 중간 표현이 아니라 **실제 투사체가 들고 나간 damage·status_power**를 실측한다.
func _test_rune_density_axis(system) -> void:
	print("[10] 룬 농도 축 — 룬 크기·정확도는 위력을 못 건드리고 상태이상 세기만 정한다")
	var rune = _db.get_rune(Enums.RuneType.FIRE)
	_check(rune != null, "Db에 불 룬 등록됨")
	if rune == null:
		return
	var floor_acc: float = system.balance.accuracy_floor

	# 실측 격자 — fill 0.0/0.5/1.0 × accuracy 0.6/1.0
	var shots := {}
	for fill: float in [0.0, 0.5, 1.0]:
		for acc: float in [0.6, 1.0]:
			var s = await _fire_one(system, fill, acc)
			shots["%.1f/%.1f" % [fill, acc]] = s
			_check(int(s["count"]) == 1, "fill %.1f · acc %.1f — 투사체 1개 (실제 %d)"
				% [fill, acc, s["count"]])
			print("    fill %.1f · acc %.1f → damage %.2f · status_power %.3f"
				% [fill, acc, s["damage"], s["status_power"]])

	var lo_acc = shots["0.5/0.6"]
	var hi_acc = shots["0.5/1.0"]
	var no_fill = shots["0.0/1.0"]
	var full_fill = shots["1.0/1.0"]

	# (1) **위력이 rune_accuracy에 전혀 반응하지 않는다** — v1.7 축 위반 해소의 핵심
	_check(is_equal_approx(float(lo_acc["damage"]), float(hi_acc["damage"])),
		"위력이 정확도에 무반응 (acc 0.6 → %.2f = acc 1.0 → %.2f)"
			% [lo_acc["damage"], hi_acc["damage"]])

	# (2) 위력이 rune_fill에도 무반응 — 농도는 위력이 아니다
	_check(is_equal_approx(float(no_fill["damage"]), float(full_fill["damage"])),
		"위력이 룬 농도에 무반응 (fill 0.0 → %.2f = fill 1.0 → %.2f)"
			% [no_fill["damage"], full_fill["damage"]])

	# (3) 실제 투사체 status_power = rune.status_power × 농도(fill) × 순도(acc) — 식 자체를 못 박는다
	for key: String in shots:
		var s = shots[key]
		var expected: float = _expected_status_power(system, s["design"], rune)
		_check(is_equal_approx(float(s["status_power"]), expected),
			"fill/acc %s — status_power %.3f = 기대 %.3f" % [key, s["status_power"], expected])

	# (4) 농도는 실제로 세기를 **올린다** — 진 구석의 작은 룬 < 진을 꽉 채운 룬
	_check(float(no_fill["status_power"]) < float(hi_acc["status_power"])
			and float(hi_acc["status_power"]) < float(full_fill["status_power"]),
		"세기가 농도에 따라 단조 증가 (%.3f < %.3f < %.3f)"
			% [no_fill["status_power"], hi_acc["status_power"], full_fill["status_power"]])
	# 양 끝은 balance의 density_min/max에 정확히 닿는다 (수치는 balance에서 읽어 만든다)
	_check(is_equal_approx(float(no_fill["status_power"]),
			float(rune.status_power) * float(system.balance.rune_density_min)),
		"fill 0.0 = status_power × rune_density_min")
	_check(is_equal_approx(float(full_fill["status_power"]),
			float(rune.status_power) * float(system.balance.rune_density_max)),
		"fill 1.0 = status_power × rune_density_max")

	# (5) 순도 — 세기는 accuracy에 비례하고, accuracy_floor 하한이 걸린다
	_check(float(lo_acc["status_power"]) < float(hi_acc["status_power"]),
		"세기가 정확도에 비례 (acc 0.6 %.3f < acc 1.0 %.3f)"
			% [lo_acc["status_power"], hi_acc["status_power"]])
	var sloppy = await _fire_one(system, 0.5, 0.05)   # 하한 아래로 그린 엉망 룬
	var at_floor = await _fire_one(system, 0.5, floor_acc)
	_check(is_equal_approx(float(sloppy["status_power"]), float(at_floor["status_power"])),
		"accuracy_floor(%.2f) 하한 — acc 0.05도 바닥값 유지 (%.3f)"
			% [floor_acc, sloppy["status_power"]])

	# (6) 상태이상 **종류**는 여전히 룬 종류가 정한다 (농도가 종류를 바꾸지 않는다)
	_check(int(no_fill["status"]) == int(rune.status)
			and int(full_fill["status"]) == int(rune.status),
		"농도와 무관하게 status = 불 룬의 상태이상 (%d)" % int(rune.status))

# ── 헬퍼 ─────────────────────────────────────────────────────

## 룬 농도(fill)·순도(accuracy)만 바꿔 한 발 쏘고, **실제 투사체 노드가 들고 나간 값**을 실측한다.
func _fire_one(system, rune_fill: float, rune_accuracy: float) -> Dictionary:
	_gs.restore_mana_full()
	var d := _ink_design(Enums.CircleType.AIMED, -PI / 2.0, 0.5)
	d.rune_fill = rune_fill
	d.rune_accuracy = rune_accuracy
	_bus.cast_requested.emit(d, Vector2.ZERO, Vector2.RIGHT)
	var projs := _projectiles(system)
	var out := {"design": d, "count": projs.size(),
		"damage": -1.0, "status_power": -1.0, "status": -1}
	if projs.size() == 1:
		out["damage"] = float(projs[0].damage)
		out["status_power"] = float(projs[0].status_power)
		out["status"] = int(projs[0].status)
	await _clear_projectiles(system)
	return out

## 기대 상태이상 세기 — 수치는 전부 balance.tres에서 읽는다 (테스트에도 하드코딩 금지)
func _expected_status_power(system, design: SpellDesign, rune) -> float:
	if rune == null:
		return 0.0
	var density: float = lerpf(float(system.balance.rune_density_min),
		float(system.balance.rune_density_max), clampf(design.rune_fill, 0.0, 1.0))
	var accuracy: float = maxf(design.rune_accuracy, float(system.balance.accuracy_floor))
	return float(rune.status_power) * density * accuracy


## 모듈 A가 실제로 만드는 형태의 도안 — strokes(원본 획) + arrows[].path·path_pressures
## with_pressures=false → 마우스로 그린 획 (필압 없음) 재현
func _ink_design(circle_type: int, aim_axis: float, magnitude: float,
		with_pressures: bool = true) -> SpellDesign:
	var d := SpellDesign.new()
	d.id = &"test_ink_design"
	d.display_name = "테스트: 먹선 도안"
	d.circle_type = circle_type
	d.circle_radius = 0.6
	d.aim_axis = aim_axis
	d.rune_type = Enums.RuneType.FIRE
	d.rune_accuracy = 0.9
	d.mana_cost = 10.0
	d.durability_max = 10
	d.durability = 10

	var circle := StrokeData.new()
	circle.role = Enums.StrokeRole.CIRCLE
	var cpts := PackedVector2Array()
	for i in range(16):
		cpts.append(Vector2(0.5, 0.5) + Vector2.RIGHT.rotated(TAU * float(i) / 16.0) * 0.3)
	circle.points = cpts
	d.strokes.append(circle)

	# 화살표 획도 strokes에 남는다 — build_design이 제외하는지 검증하기 위해 일부러 넣는다
	var arrow_stroke := StrokeData.new()
	arrow_stroke.role = Enums.StrokeRole.ARROW
	arrow_stroke.points = _arrow_path()
	d.strokes.append(arrow_stroke)

	var a := ArrowData.new()
	a.direction = 0.0
	a.magnitude = magnitude
	a.origin = Vector2.ZERO
	a.path = _arrow_path()
	if with_pressures:
		a.path_pressures = _arrow_pressures()
	d.arrows.append(a)
	return d

func _find_line(node: Node) -> Line2D:
	for child in node.get_children():
		if child is Line2D:
			return child
	return null

func _count_lines(node: Node) -> int:
	var n := 0
	for child in node.get_children():
		if child is Line2D:
			n += 1
	return n

func _cast_circle(system):
	for child in system.get_children():
		if child.name == "CastCircle" and not child.is_queued_for_deletion():
			return child
	return null

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)

func _angle_close(a: float, b: float) -> bool:
	return absf(wrapf(a - b, -PI, PI)) <= ANGLE_TOL_RAD

## 발사각을 정렬해 인접 간격이 전부 TAU/n인지 — "통째로 회전해도 노바"의 형식적 정의.
## 각도 집합 전체가 회전해도 참이므로 에임에 의존하지 않는다.
func _gaps_uniform(projs: Array, n: int) -> bool:
	var angles: Array[float] = []
	for p in projs:
		angles.append(wrapf(p.direction_angle, 0.0, TAU))
	angles.sort()
	var expected_gap := TAU / float(n)
	var ok := true
	for i in range(n):
		var gap := wrapf(angles[(i + 1) % n] - angles[i], 0.0, TAU)
		if absf(gap - expected_gap) > ANGLE_TOL_RAD:
			ok = false
			print("    간격[%d]=%.2f도, 기대=%.2f도" % [i, rad_to_deg(gap), rad_to_deg(expected_gap)])
	return ok

func _has_angle(projs: Array, angle: float) -> bool:
	for p in projs:
		if _angle_close(p.direction_angle, angle):
			return true
	return false

func _projectiles(system) -> Array:
	var out := []
	for child in system.get_children():
		if child.is_in_group("player_projectiles"):
			out.append(child)
	return out

## 투사체 + 마법진 연출 노드까지 정리 — 연출은 0.4초 살아 있으므로
## 치우지 않으면 다음 테스트가 이전 진을 주워 온다
func _clear_projectiles(system) -> void:
	for p in _projectiles(system):
		p.queue_free()
	for child in system.get_children():
		if child.name == "CastCircle":
			child.queue_free()
	await process_frame
