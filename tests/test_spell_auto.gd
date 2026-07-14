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
	await _test_shotgun(system)
	await _test_lance(system)
	await _test_fail_reasons(system)
	await _test_dummy_hit(system)
	await _test_ink_projectile(system)
	await _test_cast_circle(system)
	await _test_no_strokes_fallback(system)
	await _test_role_axes(system)
	await _test_rune_density_axis(system)
	await _test_glyph_basic_regression(system)
	await _test_glyph_range(system)
	await _test_glyph_bounce(system)
	await _test_glyph_homing(system)
	await _test_glyph_pierce(system)
	await _test_direction_invariant(system)
	await _test_wand_patterns(system)
	await _test_glyph_stacking(system)
	await _test_glyph_reach_sum(system)
	await _test_shockwave_emergence(system)
	await _test_shockwave_travel_axis(system)
	await _test_shockwave_count_matches_arrows(system)
	await _test_non_basic_glyphs_no_shockwave(system)
	await _test_shockwave_fires_once(system)
	await _test_shockwave_passes_through_enemies(system)

	if failures == 0:
		print("TEST_SPELL_OK — 전 항목 통과")
	else:
		print("TEST_SPELL_FAIL — 실패 %d건" % failures)
	quit(1 if failures > 0 else 0)

# ── 개별 테스트 ──────────────────────────────────────────────

## v2.0: 방향·발수는 지팡이의 것이다 (TECH_SPEC §4.0-a). **기본 지팡이(wand_basic)는 SINGLE**이라
## 문양이 8개(노바 도안)여도 1발이고, 그 발사각은 **에임 그대로**다 — 도안이 회전하지 않는다.
## 지팡이별 발수·간격은 [W] _test_wand_patterns가 따로 검증한다.
func _test_nova(system) -> void:
	print("[1] 노바 도안(문양 8개) — 기본 지팡이(SINGLE)에서는 1발, 발사각 = 에임 그대로")
	for aim_deg: float in [0.0, 90.0, 137.0]:
		_gs.restore_mana_full()
		var design := SampleDesigns.nova_fire()
		var aim := Vector2.RIGHT.rotated(deg_to_rad(aim_deg))
		_bus.cast_requested.emit(design, Vector2(100, 100), aim)
		var projs := _projectiles(system)
		_check(projs.size() == 1,
			"에임 %.0f도 — 투사체 1개 (문양 8개가 8발을 만들지 않는다, 실제 %d)" % [aim_deg, projs.size()])
		if projs.size() == 1:
			_check(_angle_close(projs[0]._velocity.angle(), aim.angle()),
				"에임 %.0f도 — 실제 진행 방향 = 에임 그대로 (실제 %.0f도)"
					% [aim_deg, rad_to_deg(projs[0]._velocity.angle())])
		await _clear_projectiles(system)

	# 내구·마나 차감은 에임과 무관 — 1회 캐스팅으로 확인
	executed_log.clear()
	_gs.restore_mana_full()
	var d := SampleDesigns.nova_fire()
	var durability_before := d.durability
	_bus.cast_requested.emit(d, Vector2(100, 100), Vector2.RIGHT)
	_check(d.durability == durability_before - 1,
		"내구 1 차감 (%d→%d) — 발수와 무관하게 캐스팅 1회" % [durability_before, d.durability])
	_check(executed_log.size() == 1 and is_equal_approx(float(executed_log[0]["mana"]), d.mana_cost),
		"cast_executed 1회 (mana=%.0f)" % d.mana_cost)
	await _clear_projectiles(system)

## 산탄 도안(문양 3개, 각각 다른 direction 오프셋)도 기본 지팡이(SINGLE)에서는 **1발**이고,
## ArrowData.direction 오프셋은 **소비되지 않는다** — 실제 진행 방향은 에임 그대로다.
func _test_shotgun(system) -> void:
	print("[2] 산탄 도안(문양 3개, 오프셋 각각) — 기본 지팡이(SINGLE)에서는 1발, 발사각 = 에임")
	for aim: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
		_gs.restore_mana_full()
		var design := SampleDesigns.aimed_shotgun_impact()
		_bus.cast_requested.emit(design, Vector2.ZERO, aim)
		var projs := _projectiles(system)
		_check(projs.size() == 1,
			"aim=%s 투사체 1개 (문양 3개의 direction 오프셋이 3발을 만들지 않는다, 실제 %d)" % [aim, projs.size()])
		if projs.size() == 1:
			_check(_angle_close(projs[0]._velocity.angle(), aim.angle()),
				"aim=%s 발사각 = 에임 그대로 (문양 오프셋 무시, 실제 %.0f도)"
					% [aim, rad_to_deg(projs[0]._velocity.angle())])
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

## v2.0 — **몸이 진(+룬)이다** (TECH_SPEC §4.0-a). 그린 진 먹선이 그대로 탄이 되고, 히트박스가
## 진 반지름(compute_radius_px)을 따른다. 문양 획(ARROW role)은 탄에 안 붙고, 탄은 회전하지 않는다.
func _test_ink_projectile(system) -> void:
	print("[6] 먹선 투사체 — 몸 = 진(+룬), 문양 획은 안 붙고, 탄은 돌지 않는다 (v2.0 §4.0-a)")
	_gs.restore_mana_full()
	var design := _ink_design(Enums.CircleType.FIXED, 0.0, 0.5)
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var projs := _projectiles(system)
	_check(projs.size() == 1, "투사체 1개 (실제 %d)" % projs.size())
	if projs.size() == 1:
		var proj = projs[0]
		var lines := _find_lines(proj)
		_check(lines.size() == 1,
			"먹선 Line2D 정확히 1개 — 진 획만 붙는다, 화살표(ARROW) 획 제외 (실제 %d개)" % lines.size())
		if lines.size() == 1:
			var line: Line2D = lines[0]
			_check(line.points.size() == 16, "점 개수 16 = 그린 진 획 그대로 (실제 %d)" % line.points.size())
		# 탄의 몸 = 진 — 히트박스 반경이 spell_system.compute_radius_px(design)와 정확히 같다
		# (둘 다 balance의 같은 두 노브만 읽는다 — 갈라지면 보이는 것과 맞는 것이 어긋난다)
		var expected_r: float = system.compute_radius_px(design)
		var base_hit_radius := 5.0  # projectile.gd BASE_HIT_RADIUS — 씬 CircleShape2D의 고정 반경
		var actual_r: float = proj.get_node("Shape").scale.x * base_hit_radius
		_check(is_equal_approx(actual_r, expected_r),
			"히트박스 반경 %.2fpx = compute_radius_px %.2fpx (진이 곧 탄)" % [actual_r, expected_r])
		_check(proj.scale.is_equal_approx(Vector2.ONE),
			"루트 scale 미적용 (실제 %.2f — 반경은 Shape 하나에만 실린다)" % proj.scale.x)
		_check(not proj.get_node("Visual").visible, "기존 폴리곤 비주얼 숨김")
		_check(is_zero_approx(proj.rotation), "탄은 회전하지 않는다 (rotation=%.3f, 몸이 진일 때 항상)" % proj.rotation)
	await _clear_projectiles(system)

	# 진이 크면 탄도 커진다 — circle_radius가 히트박스에 실제로 비례하는지 실측
	_gs.restore_mana_full()
	var small := _ink_design(Enums.CircleType.FIXED, 0.0, 0.5)
	small.circle_radius = 0.2
	_bus.cast_requested.emit(small, Vector2.ZERO, Vector2.RIGHT)
	var sp := _projectiles(system)
	var small_r := -1.0
	if sp.size() == 1:
		small_r = sp[0].get_node("Shape").scale.x * 5.0
	await _clear_projectiles(system)

	_gs.restore_mana_full()
	var big := _ink_design(Enums.CircleType.FIXED, 0.0, 0.5)
	big.circle_radius = 0.9
	_bus.cast_requested.emit(big, Vector2.ZERO, Vector2.RIGHT)
	var bp := _projectiles(system)
	if bp.size() == 1:
		var expected_big_r: float = system.compute_radius_px(big)
		var actual_big_r: float = bp[0].get_node("Shape").scale.x * 5.0
		_check(is_equal_approx(actual_big_r, expected_big_r),
			"진 0.9 — 히트박스 %.2fpx = compute_radius_px %.2fpx (진 반지름에 비례)"
				% [actual_big_r, expected_big_r])
		_check(sp.size() == 1 and actual_big_r > small_r,
			"진 0.9의 히트박스(%.2fpx)가 진 0.2의 히트박스(%.2fpx)보다 크다" % [actual_big_r, small_r])
	await _clear_projectiles(system)

## v2.0 — 회전이 없다 (TECH_SPEC §4.0-a): 방향이 지팡이로 갔으므로 마법진을 에임으로 돌릴 이유가
## 없다. 그린 자세 그대로 발밑에 펼쳐진다. circle_type·aim_axis가 뭐든 rotation은 항상 0이다.
func _test_cast_circle(system) -> void:
	print("[7] 캐스팅 마법진 — 발밑에 그린 자세 그대로 펼쳐졌다 사라진다 (v2.0: 회전 없음)")
	_gs.restore_mana_full()
	var aim := Vector2(0, 1)
	var origin := Vector2(64, 32)
	var design := _ink_design(Enums.CircleType.AIMED, 0.4, 0.5)
	_bus.cast_requested.emit(design, origin, aim)
	var circle = _cast_circle(system)
	_check(circle != null, "연출 노드 생성됨")
	if circle != null:
		_check(circle.global_position.is_equal_approx(origin),
			"진 중심 = 캐스팅 원점 %s (실제 %s)" % [origin, circle.global_position])
		_check(is_zero_approx(circle.rotation),
			"rotation = 0 — 에임·aim_axis 무관, 그린 자세 그대로 (실제 %.1f도)" % rad_to_deg(circle.rotation))
		_check(circle.z_index < 0, "z_index %d — 지형 위·플레이어 아래" % circle.z_index)
		_check(not (circle is CollisionObject2D), "충돌 없는 순수 비주얼")
		# build_design 기본 필터: 화살표는 진에 남지 않는다 (투사체로 날아가므로)
		_check(_find_lines(circle).size() == 1,
			"진 획만 렌더 — 화살표 획 제외 (Line2D %d개)" % _find_lines(circle).size())
	await create_timer(0.8).timeout  # 연출 총 0.4초
	_check(_cast_circle(system) == null, "연출 종료 후 자동 소멸")
	await _clear_projectiles(system)

	# circle_type=FIXED + 전혀 다른 에임이어도 여전히 rotation 0
	_gs.restore_mana_full()
	var fixed := _ink_design(Enums.CircleType.FIXED, 0.9, 0.5)
	_bus.cast_requested.emit(fixed, Vector2.ZERO, Vector2(-1, -1).normalized())
	var fixed_circle = _cast_circle(system)
	_check(fixed_circle != null and is_zero_approx(fixed_circle.rotation),
		"FIXED + 다른 에임에도 rotation 0 (circle_type·aim_axis 소비 중단 회귀 방지)")
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
		var proj = projs[0]
		_check(_find_lines(proj).is_empty(), "path 없으면 먹선 없음 — 기존 스프라이트/폴리곤")
		var expected_scale: float = system.compute_radius_px(design) / 5.0
		_check(is_equal_approx(proj.scale.x, expected_scale),
			"폴백은 루트 scale = compute_radius_px ÷ BASE_HIT_RADIUS(5) = %.2f (실제 %.2f)"
				% [expected_scale, proj.scale.x])
		_check(_angle_close(proj.rotation, Vector2.RIGHT.angle()),
			"폴백(회전 스프라이트)의 초기 rotation = 발사각(에임 그대로)")
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

	# (3) v2.0: 한 도안 = 한 탄이다 (기본 지팡이 SINGLE 기준 — [1]이 이미 노바=1발을 실측했다).
	# "같은 도안의 여러 탄 규모 비교"는 이제 성립하지 않는다 — 지팡이가 다발(MULTI·NOVA)을
	# 쏠 때 "발마다 규모가 같다"는 [W] _test_wand_patterns가 damage 동일성으로 검증한다.

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

## 문양 = 발동 방식 + 세기 축 (v1.9, GDD §4.3).
## 🔴 세션 7 교훈: 중간 표현이 초록이어도 **실제로 날아가는 탄은 90도 틀어져 있을 수 있다.**
## 아래 넷은 전부 **관측 가능한 결과**로 검증한다 — 실제 속도 반전 · 실제 궤도 각 변화 ·
## 실제 take_hit을 받은 적 수 · 실제 이동 거리.

## 구세이브·샘플 도안(glyph 미설정 = BASIC, reach 기본 1.0)이 위력·상태이상은 v1.8과 똑같이 날아가고,
## 몸(=진, 진 반지름 히트박스)·사거리(compute_design_lifetime)·회전(폴백만 회전)은 v2.0 공식을 따른다.
func _test_glyph_basic_regression(system) -> void:
	print("[11] BASIC 회귀 — 위력은 v1.8과 같고, 몸·사거리는 v2.0 공식(진이 곧 탄)을 따른다")
	_gs.restore_mana_full()
	var design := SampleDesigns.aimed_lance_water()   # arrows[0].glyph·reach 미설정, strokes 없음(폴백)
	_check(int(design.arrows[0].glyph) == Enums.GlyphType.BASIC, "구세이브 화살표 glyph 기본값 = BASIC")
	_check(is_equal_approx(float(design.arrows[0].reach), 1.0), "구세이브 화살표 reach 기본값 = 1.0")
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var projs := _projectiles(system)
	_check(projs.size() == 1, "투사체 1개 (실제 %d)" % projs.size())
	if projs.size() == 1:
		var proj = projs[0]
		# 위력은 **진의 축** — 문양 도입으로 1비트도 안 움직여야 한다 (v1.8 공식 그대로 재계산)
		var rune = _db.get_rune(design.rune_type)
		var legacy_damage: float = system.balance.projectile_base_damage \
			* (float(system.balance.circle_damage_base) + design.circle_radius) \
			* (float(rune.base_damage) if rune != null else 1.0)
		_check(is_equal_approx(float(proj.damage), legacy_damage),
			"위력 %.2f = v1.8 값 %.2f (문양이 위력을 안 건드린다)" % [proj.damage, legacy_damage])
		# v2.0: 크기 = compute_radius_px(design). strokes 없는 폴백이므로 루트 scale에 실린다
		var expected_r: float = system.compute_radius_px(design)
		var actual_r: float = proj.scale.x * proj.get_node("Shape").scale.x * 5.0  # BASE_HIT_RADIUS
		_check(is_equal_approx(actual_r, expected_r),
			"탄 반경 %.2fpx = compute_radius_px %.2fpx (v2.0: 진이 곧 탄)" % [actual_r, expected_r])
		# v2.0: 사거리는 도안당 1회, compute_design_lifetime 하나가 전부의 출처다
		var mult: float = _range_mult(system, 1.0)
		var expected_life: float = system.compute_design_lifetime(design)
		_check(is_equal_approx(float(proj._life_left), expected_life),
			"사거리 %.3f초 = compute_design_lifetime %.3f (기준 × 문양 배율 %.3f)"
				% [proj._life_left, expected_life, mult])
		if not is_equal_approx(mult, 1.0):
			print("  ⚠ 리드 확인 필요: reach 기본값 1.0의 사거리 배율이 %.3f다 (1.0이 아님)." % mult)
			print("    → **구세이브 도안의 사거리가 %.0f%%로 바뀐다.** TECH_SPEC §4.0-a는" % (mult * 100.0))
			print("    '구세이브 기본값 = 1.0 (기존 밸런스 유지)'라고 적혀 있다 — balance의")
			print("    glyph_range_min/max(%.2f/%.2f) 또는 glyph_reach_min/max(%.2f/%.2f)와 어긋난다"
				% [system.balance.glyph_range_min, system.balance.glyph_range_max,
					system.balance.glyph_reach_min, system.balance.glyph_reach_max])
		# BASIC은 벽에서 소멸한다 (반사하지 않는다) — 팅김과 갈리는 지점
		var wall := _make_wall(Vector2(80, 0), Vector2(20, 200))
		var vx_flips := await _track_flips(proj, 2.0)
		_check(int(vx_flips["flips"]) == 0, "BASIC은 벽에서 안 튕긴다 (반전 %d회)" % vx_flips["flips"])
		_check(bool(vx_flips["died"]), "BASIC은 벽에 부딪혀 소멸")
		wall.queue_free()
	await _clear_projectiles(system)

## 사거리 = 진 기준 × 문양 배율. **탄마다 다르다** — 도안당 1회가 아니다.
func _test_glyph_range(system) -> void:
	print("[12] 문양 세기 — 긴 문양이 실제로 더 멀리 간다 (같은 진에서)")
	var short_shot = await _fire_glyph(system, Enums.GlyphType.BASIC, 0.6)
	var long_shot = await _fire_glyph(system, Enums.GlyphType.BASIC, 3.0)
	_check(float(long_shot["life"]) > float(short_shot["life"]),
		"긴 문양(reach 3.0)이 더 오래 산다 (%.2f초 > %.2f초)" % [long_shot["life"], short_shot["life"]])
	# 실측 — 죽을 때까지 실제로 이동한 거리
	_check(float(long_shot["travel"]) > float(short_shot["travel"]) * 1.5,
		"긴 문양이 실제로 더 멀리 날아갔다 (%.0fpx > %.0fpx)"
			% [long_shot["travel"], short_shot["travel"]])
	# 🔴 축 방어: 문양 세기는 사거리 **배율**만 준다 — 위력·크기는 진의 것이다
	_check(is_equal_approx(float(long_shot["damage"]), float(short_shot["damage"])),
		"문양 세기는 위력을 못 건드린다 (긴 %.2f = 짧은 %.2f)"
			% [long_shot["damage"], short_shot["damage"]])
	_check(is_equal_approx(float(long_shot["size"]), float(short_shot["size"])),
		"문양 세기는 탄 크기를 못 건드린다 (%.2f)" % short_shot["size"])
	_check(int(long_shot["status"]) == int(short_shot["status"])
			and is_equal_approx(float(long_shot["status_power"]), float(short_shot["status_power"])),
		"문양 세기는 상태이상을 못 건드린다 (룬의 축 — 세기 %.3f)" % short_shot["status_power"])
	# 짧은 문양 + 긴 문양이 한 도안에 섞이면 — v2.0: **1발**이고, 사거리는 **긴 쪽(max)**이 정한다.
	# 합이 아니다: 합이었다면 더 멀리 갔을 것이다 — 실측으로 못 박는다.
	_gs.restore_mana_full()
	var mixed := _glyph_design(Enums.GlyphType.BASIC, 0.6)
	var far := ArrowData.new()
	far.direction = 0.0
	far.magnitude = 0.5
	far.origin = Vector2.ZERO
	far.glyph = Enums.GlyphType.BASIC
	far.reach = 3.0
	mixed.arrows.append(far)
	_bus.cast_requested.emit(mixed, Vector2.ZERO, Vector2.RIGHT)
	var mp := _projectiles(system)
	_check(mp.size() == 1,
		"짧은 문양 + 긴 문양 = 1발 (v2.0: 발수는 지팡이가 정한다, 문양 개수 아님, 실제 %d)" % mp.size())
	if mp.size() == 1:
		var expected_life: float = system.compute_design_lifetime(mixed)
		_check(is_equal_approx(float(mp[0]._life_left), expected_life),
			"사거리 %.2f초 = compute_design_lifetime (실제 %.2f)" % [expected_life, mp[0]._life_left])
		var long_only_life: float = system.compute_lifetime(mixed) * _range_mult(system, 3.0)
		_check(is_equal_approx(float(mp[0]._life_left), long_only_life),
			"사거리는 max(reach)=3.0 단독 기준과 같다 (%.2f초) — 짧은 문양은 사거리에 안 보탠다"
				% long_only_life)
		var short_mult: float = _range_mult(system, 0.6)
		var long_mult: float = _range_mult(system, 3.0)
		var sum_life: float = system.compute_lifetime(mixed) * (short_mult + long_mult)
		_check(float(mp[0]._life_left) < sum_life,
			"합이었다면 %.2f초였을 것 — 실측 %.2f초는 그보다 짧다 (max이지 합이 아니다)"
				% [sum_life, mp[0]._life_left])
	await _clear_projectiles(system)

## 팅김⚡ — 벽에 **실제로** 반사되는가. 반전 횟수를 세서 검증한다.
func _test_glyph_bounce(system) -> void:
	print("[13] 팅김⚡ — 벽에서 실제로 방향이 반전되고, 길게 그으면 더 많이 튕긴다")
	# 양쪽 벽 사이에 가둬 놓고 왼쪽↔오른쪽 반전 횟수를 센다
	var wall_r := _make_wall(Vector2(80, 0), Vector2(20, 240))
	var wall_l := _make_wall(Vector2(-80, 0), Vector2(20, 240))

	# (1) 첫 반사 — 속도가 실제로 뒤집히는가
	_gs.restore_mana_full()
	var design := _glyph_design(Enums.GlyphType.BOUNCE, 3.0)
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var projs := _projectiles(system)
	_check(projs.size() == 1, "투사체 1개 (실제 %d)" % projs.size())
	if projs.size() == 1:
		var proj = projs[0]
		var expected_bounces: int = _bounce_count(system, 3.0)
		print("    reach 3.0 → 기대 반사 횟수 %d회" % expected_bounces)
		_check(proj._velocity.x > 0.0, "발사 직후 오른쪽으로 간다 (vx=%.0f)" % proj._velocity.x)
		var frames := 0
		while is_instance_valid(proj) and proj._velocity.x > 0.0 and frames < 240:
			await physics_frame
			frames += 1
		_check(is_instance_valid(proj), "벽에 닿아도 살아 있다 (반사 횟수가 남아 있으므로)")
		if is_instance_valid(proj):
			_check(proj._velocity.x < 0.0, "벽에서 속도가 반전됐다 (vx=%.0f < 0)" % proj._velocity.x)
			_check(is_zero_approx(proj.rotation),
				"v2.0: 탄은 회전하지 않는다 — 팅김으로 방향이 꺾여도 rotation=0 (실제 %.1f도)"
					% rad_to_deg(proj.rotation))
			_check(absf(proj.global_position.x) < 80.0, "벽을 뚫고 지나가지 않았다 (x=%.0f)"
				% proj.global_position.x)
			# 나머지 반사까지 세고, 다 쓰면 벽에서 소멸하는지
			var rest = await _track_flips(proj, 4.0)
			var total: int = 1 + int(rest["flips"])
			_check(total == expected_bounces,
				"reach 3.0 — 실제 반사 %d회 = 기대 %d회" % [total, expected_bounces])
			_check(bool(rest["died"]), "반사 횟수를 다 쓰면 벽에서 소멸")
			_check(not bool(rest["expired"]),
				"수명이 아니라 벽 충돌로 죽었다 (남은 수명 %.2f초)" % rest["life_left"])
	await _clear_projectiles(system)

	# (2) 짧은 문양은 덜 튕긴다 — reach가 세기를 정한다
	_gs.restore_mana_full()
	var weak := _glyph_design(Enums.GlyphType.BOUNCE, 0.6)
	_bus.cast_requested.emit(weak, Vector2.ZERO, Vector2.RIGHT)
	var wp := _projectiles(system)
	if wp.size() == 1:
		var expected_weak: int = _bounce_count(system, 0.6)
		var res = await _track_flips(wp[0], 4.0)
		print("    reach 0.6 → 기대 반사 횟수 %d회 / 실측 %d회" % [expected_weak, res["flips"]])
		_check(int(res["flips"]) == expected_weak,
			"reach 0.6 — 실제 반사 %d회 = 기대 %d회" % [res["flips"], expected_weak])
		_check(int(res["flips"]) < _bounce_count(system, 3.0),
			"길게 그은 팅김이 더 많이 튕긴다 (%d < %d회)"
				% [res["flips"], _bounce_count(system, 3.0)])
		_check(bool(res["died"]), "반사 소진 후 소멸")
	await _clear_projectiles(system)
	wall_r.queue_free()
	wall_l.queue_free()
	await process_frame

## 유도∿ — 적 쪽으로 **실제로 궤도가 휘는가**. 표적을 매 프레임 직각으로 유지해
## 선회가 상한에 붙게 만든 뒤, 프레임당 선회각이 glyph_homing_turn_rate를 넘지 않는지 잰다.
func _test_glyph_homing(system) -> void:
	print("[14] 유도∿ — 적 쪽으로 실제로 휘고, 선회 속도 상한을 지키고, 지속시간 후 직진한다")
	# reach 1.5(중간) — reach 상한에서는 추적 지속 = 수명 전체라 "지속 후 직진"을 관측할 수 없다
	const HOMING_REACH := 1.5
	_gs.restore_mana_full()
	var design := _glyph_design(Enums.GlyphType.HOMING, HOMING_REACH)
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var projs := _projectiles(system)
	_check(projs.size() == 1, "투사체 1개 (실제 %d)" % projs.size())
	if projs.size() != 1:
		await _clear_projectiles(system)
		return
	var proj = projs[0]
	var start_angle: float = proj._velocity.angle()
	var expected_duration: float = _homing_duration(system, HOMING_REACH, float(proj._life_left))
	var turn_rate: float = system.balance.glyph_homing_turn_rate
	var pd: float = 1.0 / float(Engine.physics_ticks_per_second)
	print("    추적 지속 기대 %.2f초 · 선회 상한 %.2f rad/s (프레임당 %.4f rad)"
		% [expected_duration, turn_rate, turn_rate * pd])

	# 표적은 매 프레임 투사체 왼쪽 90도·100px에 둔다 — 항상 탐지 반경 안이고 항상 직각으로 어긋난다.
	# 즉 유도가 살아 있는 동안 선회는 **항상 상한에 붙는다** (측정하기 좋은 조건)
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = proj.global_position + Vector2(0, 100)

	# ⚠ SceneTree.physics_frame은 노드의 _physics_process **전에** 발신된다 — 테스트가 벽시계로
	# 세면 투사체의 내부 시계보다 한 틱 앞선다. 그래서 각 선회를 **투사체 자신의 _homing_left**로
	# 가른다: 여기서 읽은 값이 곧 "다음 틱이 추적 중인가"이고, 그 틱의 결과가 다음 샘플의 step이다.
	# (신호 순서가 어느 쪽이든 이 짝짓기는 성립한다)
	var max_step := 0.0
	var turn_while_homing := 0.0
	var turn_after_homing := 0.0
	var prev_angle: float = proj._velocity.angle()
	var was_homing: bool = proj._homing_left > 0.0
	var stays_unrotated := true
	var frames := 0
	while is_instance_valid(proj) and frames < 240:
		dummy.global_position = proj.global_position + Vector2(0, 100).rotated(proj._velocity.angle())
		await physics_frame
		frames += 1
		if not is_instance_valid(proj):
			break
		var cur: float = proj._velocity.angle()
		var step := absf(wrapf(cur - prev_angle, -PI, PI))
		prev_angle = cur
		if was_homing:
			turn_while_homing += step
			max_step = maxf(max_step, step)
		else:
			turn_after_homing += step
		was_homing = proj._homing_left > 0.0
		# v2.0: 몸이 진(먹선)이면 궤도가 휘어도 rotation은 안 움직인다 — 매 프레임 불변식
		if not is_zero_approx(float(proj.rotation)):
			stays_unrotated = false

	_check(stays_unrotated,
		"매 프레임 rotation = 0 — 궤도가 유도로 휘어도 진(먹선) 몸은 돌지 않는다 (v2.0)")

	_check(turn_while_homing > 0.5,
		"추적 중 궤도가 실제로 휜다 (총 선회 %.2f rad = %.0f도)"
			% [turn_while_homing, rad_to_deg(turn_while_homing)])
	_check(max_step <= turn_rate * pd * 1.05,
		"프레임당 선회 %.4f rad ≤ 상한 %.4f rad (즉시 꺾이지 않는다)"
			% [max_step, turn_rate * pd])
	_check(max_step > turn_rate * pd * 0.9,
		"직각으로 어긋난 표적에는 선회가 상한까지 붙는다 (%.4f rad)" % max_step)
	_check(turn_after_homing < 0.001,
		"지속시간(%.2f초) 후에는 직진한다 (이후 선회 %.4f rad)"
			% [expected_duration, turn_after_homing])
	_check(absf(wrapf(prev_angle - start_angle, -PI, PI)) > 0.5,
		"최종 진행 방향이 초기 방향에서 크게 꺾였다 (%.0f도)"
			% rad_to_deg(absf(wrapf(prev_angle - start_angle, -PI, PI))))
	dummy.queue_free()
	await _clear_projectiles(system)

	# 짧은 문양은 잠깐만 따라간다 — reach가 추적 지속을 정한다
	_gs.restore_mana_full()
	var brief := _glyph_design(Enums.GlyphType.HOMING, 0.6)
	_bus.cast_requested.emit(brief, Vector2.ZERO, Vector2.RIGHT)
	var bp := _projectiles(system)
	if bp.size() == 1:
		var short_dur: float = _homing_duration(system, 0.6, float(bp[0]._life_left))
		var long_dur: float = expected_duration
		_check(is_equal_approx(float(bp[0]._homing_left), short_dur),
			"reach 0.6 — 추적 지속 %.2f초" % bp[0]._homing_left)
		_check(short_dur < long_dur,
			"길게 그은 유도가 더 오래 따라간다 (%.2f초 < %.2f초)" % [short_dur, long_dur])
	await _clear_projectiles(system)

## 관통‖ — 일렬로 둔 적 3마리 중 **실제로 몇 마리가 take_hit을 받았는가**.
func _test_glyph_pierce(system) -> void:
	print("[15] 관통‖ — 적을 뚫고 지나가고, 같은 적을 두 번 때리지 않는다")
	var dummies: Array = []
	for i in range(3):
		var d = _dummy_scene.instantiate()
		root.add_child(d)
		d.global_position = Vector2(60.0 + 60.0 * float(i), 0.0)
		dummies.append(d)

	# (1) 길게 그은 관통 — 셋 다 뚫는다
	_gs.restore_mana_full()
	var expected_pierce: int = _pierce_count(system, 3.0)
	print("    reach 3.0 → 기대 관통 수 %d마리 (적 3마리 배치)" % expected_pierce)
	_check(expected_pierce >= 3, "reach 3.0의 관통 수가 3 이상이어야 이 테스트가 성립한다")
	var design := _glyph_design(Enums.GlyphType.PIERCE, 3.0)
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var projs := _projectiles(system)
	var proj = projs[0] if projs.size() == 1 else null
	_check(proj != null, "투사체 1개 (실제 %d)" % projs.size())
	var frames := 0
	while frames < 180 and (dummies[2].hits.is_empty() and is_instance_valid(proj)):
		await physics_frame
		frames += 1
	var hit_counts: Array[int] = []
	var all_hit_once := true
	for d in dummies:
		hit_counts.append(d.hits.size())
		if d.hits.size() != 1:
			all_hit_once = false   # 0 = 못 뚫었다 / 2+ = 같은 적을 두 번 때렸다
	print("    피격 실측: %s" % str(hit_counts))
	_check(all_hit_once,
		"일렬 3마리가 전부 정확히 1번씩 맞았다 (실측 %s)" % str(hit_counts))
	for d in dummies:
		d.hits.clear()
	await _clear_projectiles(system)

	# (2) 짧게 그은 관통 — 뚫는 수를 다 쓰면 소멸한다
	_gs.restore_mana_full()
	var weak_pierce: int = _pierce_count(system, 0.6)
	print("    reach 0.6 → 기대 관통 수 %d마리" % weak_pierce)
	var weak := _glyph_design(Enums.GlyphType.PIERCE, 0.6)
	_bus.cast_requested.emit(weak, Vector2.ZERO, Vector2.RIGHT)
	var wp := _projectiles(system)
	var wproj = wp[0] if wp.size() == 1 else null
	frames = 0
	while frames < 180 and is_instance_valid(wproj):
		await physics_frame
		frames += 1
	var weak_hits: Array[int] = []
	var total_hits := 0
	for d in dummies:
		weak_hits.append(d.hits.size())
		total_hits += d.hits.size()
	print("    피격 실측: %s" % str(weak_hits))
	_check(total_hits == weak_pierce,
		"뚫는 수 %d마리만 맞았다 (실측 %d마리 — 길게 그은 관통보다 적다)"
			% [weak_pierce, total_hits])
	_check(not is_instance_valid(wproj), "뚫는 수를 다 쓰면 소멸")
	for d in dummies:
		d.hits.clear()
	await _clear_projectiles(system)

	# (3) 관통은 **벽에는 막힌다** (적만 뚫는다)
	_gs.restore_mana_full()
	var wall := _make_wall(Vector2(30, 0), Vector2(20, 200))
	var blocked := _glyph_design(Enums.GlyphType.PIERCE, 3.0)
	_bus.cast_requested.emit(blocked, Vector2.ZERO, Vector2.RIGHT)
	var bp := _projectiles(system)
	var bproj = bp[0] if bp.size() == 1 else null
	frames = 0
	while frames < 120 and is_instance_valid(bproj):
		await physics_frame
		frames += 1
	_check(not is_instance_valid(bproj), "관통탄도 벽에는 막혀 소멸")
	var wall_hits := 0
	for d in dummies:
		wall_hits += d.hits.size()
	_check(wall_hits == 0, "벽 뒤의 적은 못 맞힌다 (실측 %d마리)" % wall_hits)
	wall.queue_free()
	for d in dummies:
		d.queue_free()
	await _clear_projectiles(system)

## 신규(v2.0의 심장) — ArrowData.direction·SpellDesign.aim_axis·circle_type을 뭘로 바꿔도
## 실제 발사각은 **에임 하나**다. 중간 표현(direction 필드 등)이 아니라 실제 투사체의
## 관측 가능한 진행 방향(_velocity.angle())으로 잰다 (세션 7 교훈: 중간 표현은 거짓말할 수 있다).
func _test_direction_invariant(system) -> void:
	print("[16] 방향 불변 — 문양의 direction·aim_axis·circle_type을 뭘로 바꿔도 발사각은 에임 그대로")
	for aim_deg: float in [0.0, 47.0, 200.0]:
		var aim := Vector2.RIGHT.rotated(deg_to_rad(aim_deg))
		for junk_direction: float in [0.0, 1.7, -2.3, PI]:
			_gs.restore_mana_full()
			var design := SampleDesigns.aimed_shotgun_impact()
			for arrow: ArrowData in design.arrows:
				arrow.direction = junk_direction
			design.aim_axis = 5.5      # 어떤 값이든 무시돼야 한다
			design.circle_type = Enums.CircleType.FIXED
			_bus.cast_requested.emit(design, Vector2.ZERO, aim)
			var projs := _projectiles(system)
			_check(projs.size() == 1,
				"발수는 기본 지팡이(SINGLE) 그대로 — 문양 3개여도 1발 (실제 %d)" % projs.size())
			if projs.size() == 1:
				var actual: float = projs[0]._velocity.angle()
				_check(_angle_close(actual, aim.angle()),
					"direction=%.1f·aim_axis=5.5·circle_type=FIXED여도 실제 진행 방향 = 에임 %.0f도 (실제 %.0f도)"
						% [junk_direction, aim_deg, rad_to_deg(actual)])
			await _clear_projectiles(system)

## 신규(v2.0 지팡이 축) — 발수·방향의 유일한 출처는 **지팡이**다 (spell_system.wand_shots).
## **같은 도안**을 지팡이만 SINGLE→MULTI→NOVA로 바꿔 가며 쏜다. 도안은 한 글자도 안 바꾼다.
## GameState는 오토로드라 테스트 간에 상태가 새므로, 끝나면 반드시 지팡이를 원상복구한다.
func _test_wand_patterns(system) -> void:
	print("[17] 지팡이 패턴 — 같은 도안, 지팡이만 바꾸면 발수·방향이 바뀐다 (SINGLE/MULTI/NOVA)")
	var design := SampleDesigns.aimed_shotgun_impact()
	var aim := Vector2.RIGHT

	# SINGLE — 미착용(wand_basic과 동일 취급)이면 단발. 문양 3개여도 1발.
	_gs.equipment.erase(Enums.ItemKind.WAND)
	_check(int(_gs.wand_pattern()) == Enums.WandPattern.SINGLE, "미착용 = SINGLE (기본값)")
	_gs.restore_mana_full()
	_bus.cast_requested.emit(design, Vector2.ZERO, aim)
	var single := _projectiles(system)
	_check(single.size() == 1, "SINGLE — 문양 3개여도 1발 (실제 %d)" % single.size())
	if single.size() == 1:
		_check(_angle_close(single[0]._velocity.angle(), aim.angle()), "SINGLE — 발사각 = 에임")
	await _clear_projectiles(system)

	# MULTI (wand_fork) — wand_multi_count발, 에임이 한가운데, 양 끝 사이 = wand_multi_spread_deg
	_gs.equipment[Enums.ItemKind.WAND] = &"wand_fork"
	_check(int(_gs.wand_pattern()) == Enums.WandPattern.MULTI, "wand_fork 착용 → wand_pattern() = MULTI")
	_gs.restore_mana_full()
	_bus.cast_requested.emit(design, Vector2.ZERO, aim)
	var multi := _projectiles(system)
	var multi_n: int = system.balance.wand_multi_count
	_check(multi.size() == multi_n, "MULTI — 투사체 %d개 (실제 %d)" % [multi_n, multi.size()])
	if multi.size() == multi_n and multi_n > 1:
		var angles: Array[float] = []
		for p in multi:
			angles.append(p._velocity.angle())
		angles.sort()
		var avg := 0.0
		for a: float in angles:
			avg += a
		avg /= float(angles.size())
		_check(_angle_close(avg, aim.angle()),
			"MULTI — %d발 평균 각도 ≈ 에임 (실제 %.1f도)" % [angles.size(), rad_to_deg(avg)])
		var total_spread_deg: float = rad_to_deg(absf(wrapf(angles[angles.size() - 1] - angles[0], -PI, PI)))
		_check(absf(total_spread_deg - system.balance.wand_multi_spread_deg) < 1.0,
			"MULTI — 양 끝 사이 = spread_deg %.1f도 (실측 %.1f도)"
				% [system.balance.wand_multi_spread_deg, total_spread_deg])
		var dmg0: float = float(multi[0].damage)
		var same_damage := true
		for p in multi:
			if not is_equal_approx(float(p.damage), dmg0):
				same_damage = false
		_check(same_damage, "MULTI — 효과는 발수와 무관, %d발 전부 같은 위력" % multi.size())
	await _clear_projectiles(system)

	# NOVA (wand_ring) — wand_nova_count발, 에임을 바꿔도 이웃 탄 사이 각은 항상 360/n
	for aim_deg: float in [0.0, 90.0, 137.0]:
		_gs.equipment[Enums.ItemKind.WAND] = &"wand_ring"
		_check(int(_gs.wand_pattern()) == Enums.WandPattern.NOVA, "wand_ring 착용 → wand_pattern() = NOVA")
		_gs.restore_mana_full()
		var nova_aim := Vector2.RIGHT.rotated(deg_to_rad(aim_deg))
		_bus.cast_requested.emit(design, Vector2.ZERO, nova_aim)
		var nova := _projectiles(system)
		var nova_n: int = system.balance.wand_nova_count
		_check(nova.size() == nova_n,
			"NOVA 에임 %.0f도 — 투사체 %d개 (실제 %d)" % [aim_deg, nova_n, nova.size()])
		if nova.size() == nova_n:
			var nova_angles: Array = []
			for p in nova:
				nova_angles.append(float(p._velocity.angle()))
			_check(_gaps_uniform_angles(nova_angles, nova_n),
				"NOVA 에임 %.0f도 — 이웃한 탄 사이 각이 항상 360/%d (통째로 돌 뿐 간격 불변)"
					% [aim_deg, nova_n])
			var dmg0: float = float(nova[0].damage)
			var same_damage := true
			for p in nova:
				if not is_equal_approx(float(p.damage), dmg0):
					same_damage = false
			_check(same_damage, "NOVA — 효과는 발수와 무관, %d발 전부 같은 위력" % nova.size())
		await _clear_projectiles(system)

	_gs.equipment.erase(Enums.ItemKind.WAND)  # 원상복구 — GameState는 오토로드라 테스트 간에 샌다

## 신규(v2.0) — 팅김⚡ + 관통‖을 한 장에 그리면 **한 탄**이 튕기면서 뚫는다 (효과는 동시에 얹힌다).
## 발사 원점보다 **뒤**에 적을 둬 — 반사가 실제로 일어나야만 닿을 수 있는 자리를 만든다.
## 그 적들이 실제로 맞았다는 사실 자체가 "튕겼다"와 "뚫었다"를 동시에 증명한다 (중간 표현이 아니라
## 실제 take_hit 관측).
func _test_glyph_stacking(system) -> void:
	print("[18] 효과 중첩 — 팅김+관통을 함께 그린 한 탄이 벽에 튕기고 적을 뚫는다")
	var wall_r := _make_wall(Vector2(80, 0), Vector2(20, 240))
	var wall_l := _make_wall(Vector2(-80, 0), Vector2(20, 240))
	var behind1 = _dummy_scene.instantiate()
	var behind2 = _dummy_scene.instantiate()
	root.add_child(behind1)
	root.add_child(behind2)
	behind1.global_position = Vector2(-40, 0)
	behind2.global_position = Vector2(-60, 0)

	_gs.restore_mana_full()
	var design := _ink_design(Enums.CircleType.FIXED, 0.0, 0.5)
	design.arrows[0].glyph = Enums.GlyphType.BOUNCE
	design.arrows[0].reach = 3.0
	var pierce_arrow := ArrowData.new()
	pierce_arrow.glyph = Enums.GlyphType.PIERCE
	pierce_arrow.reach = 3.0
	design.arrows.append(pierce_arrow)

	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var projs := _projectiles(system)
	_check(projs.size() == 1, "투사체 1개 (효과가 여러 개여도 발수는 그대로, 실제 %d)" % projs.size())
	if projs.size() == 1:
		var proj = projs[0]
		var frames := 0
		while frames < 400 and is_instance_valid(proj) and (behind1.hits.is_empty() or behind2.hits.is_empty()):
			await physics_frame
			frames += 1
		_check(not behind1.hits.is_empty() and not behind2.hits.is_empty(),
			"발사 원점보다 뒤의 적 둘 다 맞았다 (반사 없인 닿을 수 없는 자리 — 팅김·관통이 둘 다 실제로 일어났다)")
		if not behind1.hits.is_empty():
			_check(behind1.hits.size() == 1, "같은 적을 두 번 안 때린다 (behind1 %d회)" % behind1.hits.size())
		if not behind2.hits.is_empty():
			_check(behind2.hits.size() == 1, "같은 적을 두 번 안 때린다 (behind2 %d회)" % behind2.hits.size())
	behind1.queue_free()
	behind2.queue_free()
	wall_r.queue_free()
	wall_l.queue_free()
	await _clear_projectiles(system)

## 신규(v2.0) — 같은 글자를 여러 번 그으면 세기가 **합산**된다 (compile_effects: Σreach).
## 팅김 두 획(reach 각 1.5) = Σ3.0이 팅김 한 획(reach 1.5)보다 실제로 더 많이 튕겨야 한다.
func _test_glyph_reach_sum(system) -> void:
	print("[19] 같은 글자 합산 — 팅김 두 획(Σreach 3.0)이 팅김 한 획(reach 1.5)보다 더 많이 튕긴다")
	var wall_r := _make_wall(Vector2(80, 0), Vector2(20, 240))
	var wall_l := _make_wall(Vector2(-80, 0), Vector2(20, 240))

	_gs.restore_mana_full()
	var single := _glyph_design(Enums.GlyphType.BOUNCE, 1.5)
	_bus.cast_requested.emit(single, Vector2.ZERO, Vector2.RIGHT)
	var sp := _projectiles(system)
	_check(sp.size() == 1, "reach 1.5 단독 — 투사체 1개 (실제 %d)" % sp.size())
	var single_flips := 0
	if sp.size() == 1:
		var res = await _track_flips(sp[0], 4.0)
		single_flips = int(res["flips"])
	await _clear_projectiles(system)

	_gs.restore_mana_full()
	var doubled := _glyph_design(Enums.GlyphType.BOUNCE, 1.5)
	var second := ArrowData.new()
	second.glyph = Enums.GlyphType.BOUNCE
	second.reach = 1.5
	doubled.arrows.append(second)
	var effects: Dictionary = system.compile_effects(doubled)
	_check(is_equal_approx(float(effects.get(Enums.GlyphType.BOUNCE, 0.0)), 3.0),
		"compile_effects — 팅김 Σreach = 1.5+1.5 = 3.0 (합산)")
	_bus.cast_requested.emit(doubled, Vector2.ZERO, Vector2.RIGHT)
	var dp := _projectiles(system)
	_check(dp.size() == 1, "같은 글자 두 획이어도 여전히 1발 (실제 %d)" % dp.size())
	var doubled_flips := 0
	if dp.size() == 1:
		var res2 = await _track_flips(dp[0], 4.0)
		doubled_flips = int(res2["flips"])
	print("    단독(reach 1.5) 실제 반사 %d회 / 합산(Σ3.0) 실제 반사 %d회"
		% [single_flips, doubled_flips])
	_check(doubled_flips == _bounce_count(system, 3.0),
		"합산 Σ3.0 — 실제 반사 %d회 = 기대 %d회" % [doubled_flips, _bounce_count(system, 3.0)])
	_check(single_flips == _bounce_count(system, 1.5),
		"단독 reach 1.5 — 실제 반사 %d회 = 기대 %d회" % [single_flips, _bounce_count(system, 1.5)])
	_check(doubled_flips > single_flips,
		"합산된 팅김이 단독 팅김보다 실제로 더 많이 튕긴다 (%d > %d)" % [doubled_flips, single_flips])
	wall_r.queue_free()
	wall_l.queue_free()
	await _clear_projectiles(system)

# ── 착탄 충격파 (v2.1, TECH_SPEC §4.0-b) ──────────────────────────────────
# 🔴 규칙은 하나: "화살표 = 충격파 하나가 가는 방향." **기둥은 규칙이 아니라 결과다** —
# 코드 어디에도 "수렴하면 기둥"이라 적지 않는다. 아래 테스트들은 "기둥이 서는 조건"을
# 직접 계산하지 않는다 — 도안을 만들고 쏜 뒤 "shockwaves"·"pillars" 그룹을 세는 것만이
# 창발을 검증하는 유일한 방법이다 (사용자·리드 지시).

## 신규 (v2.1의 심장) — 진 둘레 8개 화살표가 **밖**을 겨누면 사방으로 뻗을 뿐 서로 못 만나
## 기둥이 안 서고(=폭발), **룬(중심)**을 겨누면 전부 중심으로 모이며 **저절로** 만나 기둥이 선다.
## 같은 함수 안에서 "기둥 중복 방지"(쌍의 수 28개만큼 겹쳐 서지 않는가)도 함께 확인한다 —
## `shockwave._spawn_pillar`의 `_pending` static + 근접 병합이 실제로 지키는 자리다.
func _test_shockwave_emergence(system) -> void:
	print("[20] 착탄 충격파 창발 — 밖을 겨누면 기둥 0개, 룬(중심)을 겨누면 저절로 만나 기둥이 선다")
	_gs.equipment.erase(Enums.ItemKind.WAND)   # SINGLE 패턴 보장 — 문양 8개가 8발을 만들면 안 된다

	# (A) 진 둘레 8개 화살표가 밖을 겨눔 — 사방으로 뻗을 뿐 서로 못 만난다 (= 폭발, 기둥 없음)
	var outward := await _fire_ring(system, false)
	_check(int(outward["shock_peak"]) == 8,
		"밖을 겨눔 — 충격파 정확히 8개 스폰 (실측 최대 동시 %d)" % outward["shock_peak"])
	_check(int(outward["pillar_total"]) == 0,
		"밖을 겨눔 — 기둥이 전혀 서지 않는다 (실측 %d개)" % outward["pillar_total"])

	# (B) 진 둘레 8개 화살표가 룬(중심)을 겨눔 — 전부 중심으로 모이며 저절로 만난다 (= 기둥)
	var inward := await _fire_ring(system, true)
	_check(int(inward["shock_peak"]) == 8,
		"룬을 겨눔 — 충격파 정확히 8개 스폰 (실측 최대 동시 %d)" % inward["shock_peak"])
	_check(int(inward["pillar_total"]) >= 1,
		"룬을 겨눔 — 화살표들이 중심에서 저절로 만나 기둥이 선다 (실측 %d개)" % inward["pillar_total"])
	# 🔴 기둥 중복 방지 — 8개가 중심에서 만나면 이론상 쌍의 수(C(8,2)=28)만큼 겹쳐 설 수 있다.
	# call_deferred로 트리에 늦게 들어가는 것과 얽혀 실제로 깨지기 쉬운 자리다 (지시문 참고).
	_check(int(inward["pillar_total"]) < 28,
		"기둥이 쌍의 수(28개)만큼 겹쳐 서지 않는다 (실측 %d개 — 근접 병합이 작동했다)"
			% inward["pillar_total"])

## 신규 — **방위 기준은 탄이 가던 방향이다** (§4.0-b, 세션 7의 "90도 틀어짐"이 정확히 이 축에서
## 났다). 화살표를 캔버스 "위"(UP_AXIS = 종이 위쪽 = 앞)로 그으면, 에임을 뭘로 바꾸든 충격파는
## **언제나 탄이 가던 방향(≈에임)** 으로 나가야 한다. 실제 노드의 rotation·속도 방향으로 잰다.
func _test_shockwave_travel_axis(system) -> void:
	print("[21] 충격파 방위 기준 — 화살표를 '위'(탄이 가는 쪽)로 그으면 언제나 탄이 가던 방향으로 나간다")
	_gs.equipment.erase(Enums.ItemKind.WAND)
	var up_axis: float = _ink.UP_AXIS
	for aim_deg: float in [0.0, 90.0, 137.0]:
		var aim := Vector2.RIGHT.rotated(deg_to_rad(aim_deg))
		_gs.restore_mana_full()
		var design := _shock_design(0.5)
		var forward := ArrowData.new()
		forward.origin = Vector2.ZERO
		forward.direction = up_axis
		forward.glyph = Enums.GlyphType.BASIC
		forward.reach = 1.0
		design.arrows.append(forward)
		var dummy = _dummy_scene.instantiate()
		root.add_child(dummy)
		dummy.global_position = aim * 40.0
		_bus.cast_requested.emit(design, Vector2.ZERO, aim)
		var wave = await _wait_for_group_node("shockwaves", 120)
		_check(wave != null, "에임 %.0f도 — 충격파가 실제로 스폰됐다 (적을 맞혔다)" % aim_deg)
		if wave != null:
			_check(_angle_close(wave._velocity.angle(), aim.angle()),
				"에임 %.0f도 — 충격파 진행 방향(속도) = 탄이 가던 방향 (실제 %.0f도)"
					% [aim_deg, rad_to_deg(wave._velocity.angle())])
			_check(_angle_close(wave.rotation, aim.angle()),
				"에임 %.0f도 — 충격파 rotation = 탄이 가던 방향 (실제 %.0f도)"
					% [aim_deg, rad_to_deg(wave.rotation)])
		dummy.queue_free()
		_clear_group("shockwaves")
		_clear_group("pillars")
		await _clear_projectiles(system)

## 신규 — **화살표 하나 = 충격파 하나.** 밖을 겨눠 서로 못 만나게 해 놓고(=합쳐지지 않으므로
## 개수가 안 줄어든다) 화살표 개수를 늘려 가며 동시 존재 최대 개수를 잰다.
func _test_shockwave_count_matches_arrows(system) -> void:
	print("[22] 화살표 하나 = 충격파 하나 — 화살표 N개 → 충격파 정확히 N개")
	_gs.equipment.erase(Enums.ItemKind.WAND)
	for n in [1, 3, 5]:
		_gs.restore_mana_full()
		var design := _ring_design(n, false)   # 밖을 겨눔 — 서로 안 만나야 개수를 깔끔히 셀 수 있다
		var dummy = _dummy_scene.instantiate()
		root.add_child(dummy)
		dummy.global_position = Vector2(40, 0)
		_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
		var obs = await _observe_groups(90, ["shockwaves"])
		_check(int(obs["shockwaves"]["peak"]) == n,
			"화살표 %d개 — 충격파 정확히 %d개 스폰 (실측 최대 동시 %d)"
				% [n, n, obs["shockwaves"]["peak"]])
		dummy.queue_free()
		_clear_group("shockwaves")
		_clear_group("pillars")
		await _clear_projectiles(system)

## 신규 — **곧은 화살표(BASIC)만 충격파를 뿜는다** (현재 계약).
## ⚠ **미정** (TECH_SPEC §4.0-b, 사용자: *"아직 미정"*): 팅김·유도·관통 획도 충격파를 뿜는지는
## 손으로 만져 본 뒤 정하기로 했다. 지금 경계는 `projectile._fire_shockwaves()`의
## `if arrow.glyph != Enums.GlyphType.BASIC: continue` 한 줄이다 — **바뀌면 이 테스트도 갈아야 한다.**
func _test_non_basic_glyphs_no_shockwave(system) -> void:
	print("[23] 팅김·유도·관통 획은 충격파를 안 뿜는다 (v2.1 계약 — 미정이라 바뀔 수 있다, 주석 참고)")
	_gs.equipment.erase(Enums.ItemKind.WAND)
	for glyph: int in [Enums.GlyphType.BOUNCE, Enums.GlyphType.HOMING, Enums.GlyphType.PIERCE]:
		_gs.restore_mana_full()
		var design := _shock_design(0.5)
		var a := ArrowData.new()
		a.glyph = glyph
		a.reach = 3.0
		design.arrows.append(a)
		var dummy = _dummy_scene.instantiate()
		root.add_child(dummy)
		dummy.global_position = Vector2(40, 0)
		_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
		var frames := 0
		while dummy.hits.is_empty() and frames < 180:
			await physics_frame
			frames += 1
		_check(not dummy.hits.is_empty(), "glyph=%d — 실제로 적을 맞혔다 (%d 프레임 후)" % [glyph, frames])
		var obs = await _observe_groups(30, ["shockwaves"])
		_check(int(obs["shockwaves"]["total"]) == 0,
			"glyph=%d — 충격파 0개 (곧은 화살표만 뿜는다, 실측 %d개)" % [glyph, obs["shockwaves"]["total"]])
		dummy.queue_free()
		_clear_group("shockwaves")
		_clear_group("pillars")
		await _clear_projectiles(system)

## 신규 — 관통탄이 적 3마리를 뚫어도 충격파는 **첫 히트에 한 번**뿐이다 (`_shock_fired` 가드).
## 도안에 BASIC 화살표를 **1개**만 넣어 두고, 스폰된 충격파 노드의 instance_id를 전부 모아 —
## 매 순간 개수(peak)가 아니라 **누적 종류 수**(총 몇 번 스폰됐는지)를 세는 것이 핵심이다.
func _test_shockwave_fires_once(system) -> void:
	print("[24] 충격파는 첫 히트에 한 번만 — 관통탄이 적 3마리를 뚫어도 충격파는 화살표 수(1개)만큼만 나간다")
	_gs.equipment.erase(Enums.ItemKind.WAND)
	var dummies: Array = []
	for i in range(3):
		var d = _dummy_scene.instantiate()
		root.add_child(d)
		d.global_position = Vector2(60.0 + 60.0 * float(i), 0.0)
		dummies.append(d)

	_gs.restore_mana_full()
	var design := _ink_design(Enums.CircleType.FIXED, 0.0, 0.5)   # arrows[0] glyph=BASIC(기본값) 1개
	var pierce_arrow := ArrowData.new()
	pierce_arrow.glyph = Enums.GlyphType.PIERCE
	pierce_arrow.reach = 3.0
	design.arrows.append(pierce_arrow)
	var expected_pierce: int = _pierce_count(system, 3.0)
	_check(expected_pierce >= 3, "reach 3.0의 관통 수가 3 이상이어야 이 테스트가 성립한다")

	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var seen: Dictionary = {}
	var frames := 0
	while frames < 240 and dummies[2].hits.is_empty():
		await physics_frame
		frames += 1
		for n in get_nodes_in_group("shockwaves"):
			seen[n.get_instance_id()] = true
	for i in range(20):   # 마지막 적을 맞힌 뒤로도 늦게 추가 스폰되는지 잠깐 더 지켜본다
		await physics_frame
		for n in get_nodes_in_group("shockwaves"):
			seen[n.get_instance_id()] = true

	_check(not dummies[0].hits.is_empty() and not dummies[1].hits.is_empty()
			and not dummies[2].hits.is_empty(),
		"적 3마리 모두 관통탄에 맞았다 (충격파 발신 조건이 실제로 여러 번 만족됐다)")
	_check(seen.size() == 1,
		"화살표(BASIC) 1개 — 충격파는 세 번이 아니라 총 1번만 스폰됐다 (실측 %d개 — 첫 히트에만, 이중 보상 없음)"
			% seen.size())

	for d in dummies:
		d.queue_free()
	_clear_group("shockwaves")
	_clear_group("pillars")
	await _clear_projectiles(system)

## 신규 — 충격파는 **파동이라 적을 뚫고 지나간다** (죽지 않는다). 안 그러면 적이 앞을 막고 선
## 순간 충격파가 죽어 서로 못 만나 기둥이 영영 안 선다 (shockwave.gd 주석). 최초 피격자 뒤에
## 두 번째 적을 세워 두고 — 그 적이 실제로 맞고도 충격파가 살아서 계속 나아가는지 잰다.
func _test_shockwave_passes_through_enemies(system) -> void:
	print("[25] 충격파는 적을 뚫는다 — 가로막고 선 두 번째 적에 죽지 않고 지나간다")
	_gs.equipment.erase(Enums.ItemKind.WAND)
	_gs.restore_mana_full()
	var design := _shock_design(0.4)
	var forward := ArrowData.new()
	forward.origin = Vector2.ZERO
	forward.direction = float(_ink.UP_AXIS)   # "위" = 탄이 가던 방향 그대로 나간다
	forward.glyph = Enums.GlyphType.BASIC
	forward.reach = 1.0
	design.arrows.append(forward)

	var target = _dummy_scene.instantiate()    # 충격파를 만드는 최초 피격자
	root.add_child(target)
	target.global_position = Vector2(30, 0)
	var blocker = _dummy_scene.instantiate()   # 충격파 진행 경로를 막고 선 두 번째 적
	root.add_child(blocker)
	blocker.global_position = Vector2(55, 0)

	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var wave = await _wait_for_group_node("shockwaves", 120)
	_check(wave != null, "충격파가 스폰됐다 (최초 피격자를 맞혔다)")
	if wave != null:
		var frames := 0
		while frames < 60 and blocker.hits.is_empty() and is_instance_valid(wave):
			await physics_frame
			frames += 1
		_check(not blocker.hits.is_empty(),
			"충격파가 가로막은 두 번째 적을 실제로 때렸다 (%d 프레임 후)" % frames)
		_check(is_instance_valid(wave),
			"두 번째 적을 때린 뒤에도 충격파가 소멸하지 않는다 (파동은 적을 뚫는다 — "
				+ "안 그러면 서로 못 만나 기둥이 영영 안 선다)")
		if is_instance_valid(wave):
			var pos_before: Vector2 = wave.global_position
			await physics_frame
			await physics_frame
			var moved: bool = is_instance_valid(wave) and wave.global_position.distance_to(pos_before) > 0.5
			_check(moved, "적을 지나친 뒤에도 계속 이동한다 (실측 이동 %.2fpx)"
				% (wave.global_position.distance_to(pos_before) if is_instance_valid(wave) else -1.0))

	target.queue_free()
	blocker.queue_free()
	_clear_group("shockwaves")
	_clear_group("pillars")
	await _clear_projectiles(system)

# ── 착탄 충격파 헬퍼 ─────────────────────────────────────────

## 문양 축만 얹는 최소 도안 (§4.0-b 테스트 전용) — strokes 없음(폴백), 화살표는 호출부가 채운다.
## `_design`은 strokes 유무와 무관하게 항상 세팅되므로(projectile._setup_body) 충격파 테스트엔
## 먹선 렌더가 필요 없다.
func _shock_design(circle_radius: float) -> SpellDesign:
	var d := SpellDesign.new()
	d.id = &"test_shockwave_design"
	d.display_name = "테스트: 충격파 도안"
	d.circle_type = Enums.CircleType.AIMED
	d.circle_radius = circle_radius
	d.aim_axis = 0.0
	d.rune_type = Enums.RuneType.FIRE
	d.rune_accuracy = 0.9
	d.mana_cost = 10.0
	d.durability_max = 10
	d.durability = 10
	return d

## 진 둘레에 n개 화살표를 균등 배치 — origin = 반지름 1.0(가장자리) 지점, direction = 그 지점에서
## 밖(inward=false)을 겨누거나 중심의 룬(inward=true)을 겨눈다.
## circle_radius=0.8 — 진 반지름(px)이 커야 이웃 화살표 사이 간격(현 = 2·r·sin(π/n))이 충격파
## 히트박스 지름(10px)보다 커져 **밖을 겨눈 경우 스폰 직후 서로 겹쳐 오판정하지 않는다.**
func _ring_design(n: int, inward: bool, circle_radius: float = 0.8) -> SpellDesign:
	var d := _shock_design(circle_radius)
	for i in range(n):
		var ang := TAU * float(i) / float(maxi(n, 1))
		var a := ArrowData.new()
		a.origin = Vector2.RIGHT.rotated(ang)
		a.direction = (ang + PI) if inward else ang
		a.glyph = Enums.GlyphType.BASIC
		a.reach = 1.0
		d.arrows.append(a)
	return d

## 링 도안을 쏘고 관측한다 — 반환: shock_peak(동시 최대 개수) · pillar_total(누적 종류 수).
func _fire_ring(system, inward: bool) -> Dictionary:
	_gs.restore_mana_full()
	var design := _ring_design(8, inward)
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(40, 0)
	_bus.cast_requested.emit(design, Vector2.ZERO, Vector2.RIGHT)
	var obs = await _observe_groups(90, ["shockwaves", "pillars"])   # 리드 실측: 90프레임이면 충분
	dummy.queue_free()
	_clear_group("shockwaves")
	_clear_group("pillars")
	await _clear_projectiles(system)
	return {
		"shock_peak": obs["shockwaves"]["peak"],
		"pillar_total": obs["pillars"]["total"],
	}

## 여러 그룹을 max_frames 동안 함께 지켜보며 그룹별 {peak: 동시 최대 개수, total: 누적 종류 수}를 잰다.
## peak만으로는 "각자 다른 시점에 여러 번 스폰"을 놓친다 — 그래서 instance_id로 총 종류 수도 센다.
func _observe_groups(max_frames: int, groups: Array) -> Dictionary:
	var acc := {}
	for g: String in groups:
		acc[g] = {"peak": 0, "seen": {}}
	var frames := 0
	while frames < max_frames:
		await physics_frame
		frames += 1
		for g: String in groups:
			var nodes := get_nodes_in_group(g)
			acc[g]["peak"] = maxi(int(acc[g]["peak"]), nodes.size())
			for n in nodes:
				acc[g]["seen"][n.get_instance_id()] = true
	var out := {}
	for g: String in groups:
		out[g] = {"peak": acc[g]["peak"], "total": acc[g]["seen"].size()}
	return out

## 그룹에 노드가 나타날 때까지 기다렸다가 첫 노드를 돌려준다 (없으면 null — 타임아웃)
func _wait_for_group_node(group: String, max_frames: int):
	var frames := 0
	while frames < max_frames:
		var nodes := get_nodes_in_group(group)
		if not nodes.is_empty():
			return nodes[0]
		await physics_frame
		frames += 1
	return null

## 그룹을 통째로 정리 — 충격파·기둥은 수명이 짧아도 다음 테스트가 이전 잔재를 주워 올 수 있다
func _clear_group(group: String) -> void:
	for n in get_nodes_in_group(group):
		if is_instance_valid(n):
			n.queue_free()

# ── 헬퍼 ─────────────────────────────────────────────────────

## 벽 (world 레이어 1) — 팅김 반사·관통 차단 검증용
func _make_wall(pos: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1   # TECH_SPEC §1: 1 = world
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	root.add_child(wall)
	wall.global_position = pos
	return wall

## 문양 축만 바꾼 도안 (진·룬은 고정) — FIXED라 에임에 안 돈다
func _glyph_design(glyph: int, reach: float) -> SpellDesign:
	var d := _ink_design(Enums.CircleType.FIXED, 0.0, 0.5)
	d.arrows[0].glyph = glyph
	d.arrows[0].reach = reach
	return d

## 한 발 쏘고 **죽을 때까지** 지켜보며 실측값을 거둔다 (수명·실제 이동 거리·위력·크기·상태이상)
func _fire_glyph(system, glyph: int, reach: float) -> Dictionary:
	_gs.restore_mana_full()
	var d := _glyph_design(glyph, reach)
	_bus.cast_requested.emit(d, Vector2.ZERO, Vector2.RIGHT)
	var projs := _projectiles(system)
	var out := {"life": -1.0, "travel": -1.0, "damage": -1.0, "size": -1.0,
		"status": -1, "status_power": -1.0}
	if projs.size() == 1:
		var proj = projs[0]
		var start: Vector2 = proj.global_position
		out["life"] = float(proj._life_left)
		out["damage"] = float(proj.damage)
		out["size"] = float(proj.scale.x * proj.get_node("Shape").scale.x)
		out["status"] = int(proj.status)
		out["status_power"] = float(proj.status_power)
		var travel := 0.0
		var frames := 0
		while is_instance_valid(proj) and frames < 400:
			travel = start.distance_to(proj.global_position)
			await physics_frame
			frames += 1
		out["travel"] = travel
	await _clear_projectiles(system)
	return out

## 투사체가 죽을 때까지 x속도 부호가 몇 번 뒤집히는지 (= 좌우 벽 반사 횟수)
func _track_flips(proj, max_sec: float) -> Dictionary:
	var pd: float = 1.0 / float(Engine.physics_ticks_per_second)
	var flips := 0
	var sign_x: float = signf(proj._velocity.x)
	var elapsed := 0.0
	var life_left: float = float(proj._life_left)
	while is_instance_valid(proj) and elapsed < max_sec:
		await physics_frame
		elapsed += pd
		if not is_instance_valid(proj):
			break
		life_left = float(proj._life_left)
		var cur: float = signf(proj._velocity.x)
		if cur != 0.0 and cur != sign_x:
			flips += 1
			sign_x = cur
	return {
		"flips": flips,
		"died": not is_instance_valid(proj),
		"expired": life_left <= 0.0,
		"life_left": life_left,
	}

## balance에서 읽어 만드는 기대값 — 테스트에도 수치를 박지 않는다 (공식은 코드와 같은 출처)
func _reach_t(system, reach: float) -> float:
	return clampf(inverse_lerp(float(system.balance.glyph_reach_min),
		float(system.balance.glyph_reach_max), reach), 0.0, 1.0)

func _range_mult(system, reach: float) -> float:
	return lerpf(float(system.balance.glyph_range_min), float(system.balance.glyph_range_max),
		_reach_t(system, reach))

func _bounce_count(system, reach: float) -> int:
	return roundi(lerpf(1.0, float(system.balance.glyph_bounce_max), _reach_t(system, reach)))

func _pierce_count(system, reach: float) -> int:
	return roundi(lerpf(1.0, float(system.balance.glyph_pierce_max), _reach_t(system, reach)))

func _homing_duration(system, reach: float, lifetime: float) -> float:
	return lerpf(float(system.balance.glyph_homing_duration_min), 1.0,
		_reach_t(system, reach)) * lifetime


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

## 재귀 탐색 — build_design은 Node2D root 아래에 Line2D를 넣고, 투사체는 그 root를 자기
## 자식으로 붙인다. 그래서 Line2D는 proj의 **손자**다 — 직계 자식만 보면 못 찾는다 (실제 버그는
## 아니었다: 히트박스·damage 등 관측 가능한 값은 정상이었지만, 이 헬퍼가 얕게 탐색해 놓쳤을 뿐).
func _find_lines(node: Node) -> Array:
	var out := []
	for child in node.get_children():
		if child is Line2D:
			out.append(child)
		out.append_array(_find_lines(child))
	return out

func _find_line(node: Node) -> Line2D:
	var lines := _find_lines(node)
	return lines[0] if not lines.is_empty() else null

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

## 발사각(라디안) 배열을 정렬해 인접 간격이 전부 TAU/n인지 — "통째로 회전해도 노바"의 형식적
## 정의 (지팡이의 NOVA 패턴, TECH_SPEC §4.0-a). 각도 집합 전체가 회전해도 참이므로 에임에
## 의존하지 않는다. **실제 투사체의 _velocity.angle()**을 넘겨라 — 중간 표현이 아니라 관측값.
func _gaps_uniform_angles(angles_in: Array, n: int) -> bool:
	var angles: Array[float] = []
	for a in angles_in:
		angles.append(wrapf(float(a), 0.0, TAU))
	angles.sort()
	var expected_gap := TAU / float(n)
	var ok := true
	for i in range(n):
		var gap := wrapf(angles[(i + 1) % n] - angles[i], 0.0, TAU)
		if absf(gap - expected_gap) > ANGLE_TOL_RAD:
			ok = false
			print("    간격[%d]=%.2f도, 기대=%.2f도" % [i, rad_to_deg(gap), rad_to_deg(expected_gap)])
	return ok

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
