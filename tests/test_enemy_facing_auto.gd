extends SceneTree
## 적 좌우 반전(「보는 쪽」) 자동 검증 — 어느 쪽을 보나 · 언제 안 바꾸나 · 무엇이 같이 안 뒤집히나.
## 🔴 **양방향으로 잰다** — 시트 원본이 **오른쪽**을 보므로 오른쪽 검사는 `flip_h`를 한 번도 안
##  건드려도 **자명 통과**다. **왼쪽 검사가 「반전이 도나」의 유일한 검출자다.**
##  ⚠ `forest_enemy.SPRITE_FACES_LEFT`와 한 몸이다 — 그 상수를 뒤집는 날 이 머리말과 [5]ⓐ의 판 방향도 같이 뒤집어라.
## ⚠ 헤드리스가 못 재는 것: 반전이 **자연스러운가**·전환이 **떨려 보이나**. F5·MCP 스샷 몫이다.
## ⚠ -s 모드는 오토로드 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.

## ⚠ 시트는 살아 있는 PNG를 빌려 쓴다 — 재는 건 **행동**이지 그림이 아니다.
## 🔴 다만 이 그물은 시트에 한 가지를 기대한다: `hound` 계열의 머리가 **오른쪽**이라는 것.
##  그 문장이 반대로 적혀 있어 [1]이 오독을 기대치로 굳힌 적이 있다 ⇒ **[7]이 PNG를 픽셀로 검산한다.**
const PROBE_SPRITE := "res://assets/sprites/enemies/hound.png"

var failures: int = 0
var _db = null
var _enemy_scene = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("TEST_ENEMY_FACING_TIMEOUT — 60초 초과")
		quit(1))
	await process_frame

	_db = root.get_node("/root/Db")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene

	# 🔴 `current_scene`을 세운다 — 돌진 예고(`_show_charge_band`)가 씬 소유라 없으면 **조용히
	#   안 만들어진다**([3][4]가 통째로 자명 통과가 된다).
	var container := Node2D.new()
	root.add_child(container)
	current_scene = container

	await _test_both_directions()
	await _test_deadzone_holds()
	await _test_windup_locks_facing()
	await _test_only_visual_flips()
	await _test_rotation_body_is_excluded()
	await _test_knockback_does_not_turn_head()
	_test_sheet_direction_matches_constant()

	if failures == 0:
		print("TEST_ENEMY_FACING_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_ENEMY_FACING_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 **양방향** — 오른쪽으로 가면 오른쪽, 왼쪽으로 가면 왼쪽을 본다.
## 🔴 **ⓑ(왼쪽)가 「반전이 도나」의 유일한 검출자다** — 시트 원본이 오른쪽이라 ⓐ는 `flip_h`를
##  한 번도 안 건드려도 통과한다. ⓒ는 **부호**를 박는다: `flip_h == false`가 오른쪽이다.
## ⚠ **이 항목의 초록은 「그림이 맞다」를 뜻하지 않는다** — 부호 자체가 맞는지는 [7]과 스샷이 진다.
##  여기가 지는 건 **「부호가 일관되게 적용되나」**까지다.
func _test_both_directions() -> void:
	print("[1] 🔴 양방향 — 오른쪽으로 가면 오른쪽 · 왼쪽으로 가면 왼쪽")
	_inject_chase()
	var stub := _stub(Vector2(400.0, 0.0))
	var e = await _spawn(CHASE_PROBE)
	# 20프레임 = 90px/s로 30px 이동. 스텁(400px)에 **도착하지 않는다** — 도착 직전엔 1px 안쪽에서
	# 방향이 한 번 뒤집힐 수 있어(추격은 멈춤 거리가 없다) 판정이 흔들린다.
	for i in 20:
		await physics_frame
	_check(e.facing_x() > 0.0,
		"ⓐ 🔴 오른쪽으로 움직이면 오른쪽을 본다 (facing %.0f — -1이면 반전이 아예 안 돈다)" % e.facing_x())
	var vis := e.get_node_or_null(^"Visual") as CanvasItem
	_check(vis != null, "Visual 노드를 찾았다 (씬 구조가 바뀌면 이 그물이 죽는다)")
	if vis != null:
		_check(vis.flip_h == false,
			"ⓒ 오른쪽 = flip_h false = 시트 원본 그대로 (시트 머리가 **오른쪽**이다 — 실제 %s)" % vis.flip_h)

	# 스텁을 몸 **왼쪽**으로 옮긴다 — 지금 위치 기준이라 앞 이동량에 안 얽힌다.
	stub.global_position = e.global_position + Vector2(-400.0, 0.0)
	for i in 20:
		await physics_frame
	_check(e.facing_x() < 0.0,
		"ⓑ 🔴 왼쪽으로 움직이면 왼쪽을 본다 (facing %.0f)" % e.facing_x())
	if vis != null:
		_check(vis.flip_h == true,
			"ⓒ' 🔴 왼쪽 = flip_h true (시트가 오른쪽을 보므로 뒤집어야 왼쪽이 된다 — 실제 %s)" % vis.flip_h)
	e.free()
	stub.free()
	_drop(CHASE_PROBE)


## [2] 🔴 **데드존** — 거의 수직으로만 움직이면 안 뒤집힌다(파르르 떠는 것을 막는 그 값).
## 🔴 먼저 **「유지할 방향」을 세워 놓고** 잰다 — 스폰 직후에 재면 데드존이 0이어도 통과한다.
## 🔴 그 방향은 반드시 **왼쪽**이다(시트 원본의 반대쪽) — 오른쪽 판으로 세우면 `_update_facing`이
##  통째로 죽어도 전제가 자명 통과한다. **이 논리는 이 파일 전체에 적용된다**([5]도 같은 이유다).
## 🔴 미세 이동은 반드시 **보던 쪽의 반대**로 준다 — 같은 쪽으로 주면 데드존을 0으로 만든
##  뮤테이션이 그대로 통과한다(부호가 그대로라서 = 검출력 0).
## ⚠ 수직 거리를 600px로 넉넉히 잡는 이유: 데드존이 px/s라 가까울수록 같은 dx가 큰 vx가 된다.
func _test_deadzone_holds() -> void:
	print("[2] 🔴 데드존 — 거의 수직 이동으로는 안 뒤집힌다 (보던 쪽 유지)")
	_inject_chase()
	var stub := _stub(Vector2(-400.0, 0.0))
	var e = await _spawn(CHASE_PROBE)
	for i in 20:
		await physics_frame
	_check(e.facing_x() < 0.0,
		"ⓐ 먼저 **왼쪽**을 보게 만들었다 = 반전이 실제로 걸렸다 (facing %.0f — 오른쪽 판이면 자명 통과다)"
			% e.facing_x())

	# 거의 바로 위 **살짝 오른쪽** — dx +2px / 거리 600px ⇒ vx ≈ +0.3px/s (데드존 12 한참 아래).
	# 🔴 부호가 **보던 쪽의 반대**인 것이 이 항목의 검출력 전부다(위 머리말).
	stub.global_position = e.global_position + Vector2(2.0, -600.0)
	for i in 40:
		await physics_frame
	_check(e.facing_x() < 0.0,
		"ⓑ 🔴 거의 수직으로만 움직이는 동안 보던 쪽을 유지한다 (facing %.0f — 데드존이 0이면 오른쪽으로 튄다)"
			% e.facing_x())

	# ⓒ 뚜렷하게 오른쪽 → 결국 되돌아온다(데드존이 「영영 안 뒤집는다」가 아님을 증명).
	stub.global_position = e.global_position + Vector2(500.0, 0.0)
	for i in 20:
		await physics_frame
	_check(e.facing_x() > 0.0,
		"ⓒ 뚜렷한 좌우 이동에는 뒤집힌다 (facing %.0f — 데드존이 너무 크면 여기가 빨개진다)" % e.facing_x())
	e.free()
	stub.free()
	_drop(CHASE_PROBE)


## [3] 🔴 **윈드업 동안 방향이 고정된다** — 돌진 예고의 심장.
##  늑대는 윈드업에 제자리에 멈추는데, 그때 보는 쪽이 흔들리면 예고가 통째로 우스워진다.
## 🔴 이 항목이 「이동 방향으로 정한다」와 「플레이어 쪽으로 정한다」를 가른다 — 윈드업 한가운데서
##  스텁을 반대편으로 옮겨도 몸은 오던 쪽을 봐야 한다. 플레이어를 보는 구현은 **여기서만** 빨개진다.
## 🔴 **왼쪽 판이다** — 오른쪽으로 접근시키면 ⓐ가 자명 통과가 된다([2] 머리말).
## ⚠ 프레임 수를 계약으로 안 삼는다 — 예고가 뜰 때까지 기다렸다가 떠 있는 동안 잰다.
func _test_windup_locks_facing() -> void:
	print("[3] 🔴 윈드업 동안 보는 쪽이 고정된다 (플레이어가 아니라 이동 방향이 정한다)")
	_inject_charge(CHARGE_PROBE)
	var stub := _stub(Vector2(-150.0, 0.0))
	var e = await _spawn(CHARGE_PROBE)
	var up := await _await_band(e, 90)
	_check(up, "윈드업에 들어가 예고가 떴다")
	_check(e.facing_x() < 0.0,
		"ⓐ 왼쪽으로 접근했으니 왼쪽을 본다 (facing %.0f — 반전이 실제로 걸려야만 성립한다)" % e.facing_x())

	# 🔴 윈드업 한가운데서 플레이어가 **반대편 멀리로** 사라진다.
	stub.global_position = Vector2(800.0, 0.0)
	for i in 30:
		await physics_frame
	_check(e.charge_band_visible(),
		"ⓑ 아직 윈드업 중이다 (예고가 떠 있다 — 꺼졌으면 아래 판정이 뜻을 잃는다)")
	_check(e.facing_x() < 0.0,
		"ⓒ 🔴 멈춰 있는 동안 고개가 안 돈다 (facing %.0f — +1이면 「플레이어를 본다」로 짠 것)" % e.facing_x())
	e.free()
	stub.free()
	_drop(CHARGE_PROBE)


## [4] 🔴 **뒤집히는 건 `Visual` 하나다** — 그림자·콜라이더·예고는 그대로다.
## 🔴 겨눈 고장은 딱 하나, **루트에 `scale.x = -1`을 거는 구현**이다. 그러면 그림자·돌풍 링이 같이
##  뒤집히고 **`Collision`까지 좌우가 바뀌어 판정이 에러 0으로 어긋난다.** `hitbox_radius()`는
##  `absf`라 부호를 못 보므로 여기서 `global_scale.x`의 **부호**를 직접 짚는다.
## 🔴 **반드시 왼쪽으로 몰아야 한다** — 오른쪽 판이면 아무것도 안 뒤집힌 상태를 재게 되어
##  루트 거울질 구현도 그대로 통과한다(항목 전체가 무의미해진다).
## ⓓ는 돌진 예고가 반전을 안 타는지를 **좌·우 두 판을 실제로 그려** 비교한다(씬 소유 계약의 짝그물).
func _test_only_visual_flips() -> void:
	print("[4] 🔴 반전은 Visual에만 — 루트·콜라이더·그림자·예고는 그대로")
	_inject_chase()
	var stub := _stub(Vector2(-400.0, 0.0))
	var e = await _spawn(CHASE_PROBE)
	for i in 20:
		await physics_frame
	_check(e.facing_x() < 0.0,
		"먼저 **실제로 뒤집힌** 상태를 만들었다 (facing %.0f — 오른쪽 판이면 안 뒤집힌 몸을 재게 된다)"
			% e.facing_x())

	_check(e.global_scale.x > 0.0,
		"ⓐ 🔴 루트가 거울질되지 않았다 (global_scale.x %.3f — 음수면 콜라이더까지 뒤집힌 것)" % e.global_scale.x)
	var col := e.get_node_or_null(^"Collision") as Node2D
	_check(col != null, "Collision 노드를 찾았다")
	if col != null:
		_check(col.global_scale.x > 0.0,
			"ⓑ 🔴 맞는 몸이 안 뒤집혔다 (global_scale.x %.3f)" % col.global_scale.x)
	var shadow := _shadow_of(e)
	_check(shadow != null, "발밑 그림자를 찾았다 (`_attach_shadow`가 붙인 Sprite2D)")
	if shadow != null:
		_check(shadow.global_scale.x > 0.0 and shadow.flip_h == false,
			"ⓒ 🔴 그림자가 안 뒤집혔다 (scale.x %.3f · flip_h %s)" % [shadow.global_scale.x, shadow.flip_h])
	e.free()
	stub.free()
	_drop(CHASE_PROBE)

	# ⓓ 돌진 예고 — 좌·우 두 판을 실제로 그려 **그려진 범위가 같다**를 본다.
	_inject_charge(CHARGE_PROBE)
	var reach_r := await _band_reach_from(150.0)
	var reach_l := await _band_reach_from(-150.0)
	_check(reach_r.x > 0.0 and reach_r.y > 0.0,
		"ⓓ' 오른쪽 판에서 예고가 실제로 그려졌다 (길이 %.1f · 반경 %.1f)" % [reach_r.x, reach_r.y])
	_check(reach_r.is_equal_approx(reach_l),
		"ⓓ 🔴 예고 범위가 보는 쪽과 무관하다 (오른쪽 %s / 왼쪽 %s)" % [reach_r, reach_l])
	_drop(CHARGE_PROBE)


## [5] 🔴 **회전으로 방향을 내는 몸(뱀 보스)엔 반전을 안 건다.**
##  회전된 스프라이트에 `flip_h`를 겹치면 머리가 진행 방향의 **정반대**를 가리킨다(θ → θ+180°).
## 🔴 제외 검출은 **「시트 원본의 반대쪽」에서만 드러난다** — 뱀은 `flip_h`를 안 건드려 값이 초기값
##  false에 머문다. 제외를 없앤 뮤테이션이 잡히려면 그 몸이 true가 되는 방향, 즉 **왼쪽**이어야 한다.
##  🔴 부호 상수(`SPRITE_FACES_LEFT`)를 다시 만지는 날 이 방향도 같이 뒤집어라 — 둘은 한 몸이다.
## 🔴 ⓑ는 **방향을 잃지도 않았다**를 잰다 — 없으면 「뱀 방향을 통째로 죽인 코드」가 ⓐ만으로 통과한다.
## ⚠ 이 항목만으로는 「전 종에 반전을 안 건다」와 구별이 안 된다 — 그걸 가르는 건 [1]ⓑ다(짝이다).
func _test_rotation_body_is_excluded() -> void:
	print("[5] 🔴 뱀 보스는 회전으로 방향을 낸다 — flip_h를 안 건다")
	var def = _db.get_enemy(&"snake_boss")
	if def == null:
		_check(false, "snake_boss를 Db가 로드했다")
		return
	# 🔴 rush_range 밖에 둔다 — 안쪽이면 곧장 러시 윈드업(velocity 0)이라 위브가 안 돈다.
	# 🔴 폴백 상수를 박지 않는다 — 우연히 같은 값이면 데이터가 옮겨가도 그물이 안 빨개진다.
	var near: float = float(def.params.get("sight_range", def.params.get("aggro_range", 0.0))) - 50.0

	# ⓐ **왼쪽 판** = 제외가 풀렸는지 드러나는 유일한 방향(시트가 오른쪽을 보므로 왼쪽이 뒤집히는 쪽).
	var stub_r := _stub(Vector2(-near, 0.0))
	var er = await _spawn(&"snake_boss")
	for i in 30:
		await physics_frame
	var vr := er.get_node_or_null(^"Visual") as Node2D
	_check(vr != null, "Visual 노드를 찾았다")
	if vr != null:
		_check(vr.flip_h == false,
			"ⓐ 🔴 왼쪽으로 가도 뱀은 flip_h를 안 쓴다 (실제 %s — true면 머리가 뒤통수로 돈다)" % vr.flip_h)
	er.free()
	stub_r.free()

	# ⓑ **왼쪽 판** = 회전이 살아 있다(방향을 잃지 않았다).
	var stub_l := _stub(Vector2(-near, 0.0))
	var el = await _spawn(&"snake_boss")
	for i in 30:
		await physics_frame
	var vl := el.get_node_or_null(^"Visual") as Node2D
	if vl != null:
		_check(absf(vl.rotation) > 2.0,
			"ⓑ 🔴 대신 회전으로 왼쪽을 본다 (rotation %.2f rad — 0 근처면 방향을 통째로 잃은 것)"
				% vl.rotation)
		_check(vl.flip_h == false, "ⓑ' 왼쪽 판에서도 flip_h는 그대로다 (실제 %s)" % vl.flip_h)
	el.free()
	stub_l.free()


## [6] 🔴 **맞아서 밀려도 고개가 안 돈다** — 「보는 쪽은 이동 **의지**」 계약의 검출자.
##  `_apply_move`는 이동 의지 → 감속 → **넉백** 순으로 얹는다. 반전을 넉백 **뒤**에 두면 맞을 때마다
##  고개가 홱 돈다. 코드가 그 순서를 주석으로 선언하지만 **그물이 없으면 한 줄 아래로 옮겨도 그린이다.**
## 🔴 탐침을 느리게(30px/s) 준 것이 이 항목의 전부다 — 넉백(140)이 추격 속도보다 훨씬 커야
##  합쳐진 속도의 부호가 뒤집힌다(빠른 몸이면 창이 서너 프레임뿐이라 프레임률에 흔들린다).
## 🔴 ⓑ(실제로 밀렸다)가 자명 통과를 막는다. 🔴 **왼쪽 판이다**([2] 머리말).
const KNOCK_PROBE := &"facing_probe_knock"

func _test_knockback_does_not_turn_head() -> void:
	print("[6] 🔴 맞아서 밀려도 고개가 안 돈다 (보는 쪽 = 이동 의지, 실제 변위가 아니다)")
	_inject(KNOCK_PROBE, {
		"aggro_range": 5000.0,
		"attack_cooldown": 5.0,
		"attack_range": 0.0,
		"contact_damage": 0.0,
		"move_speed": 30.0,
	})
	var stub := _stub(Vector2(-400.0, 0.0))
	var e = await _spawn(KNOCK_PROBE)
	for i in 20:
		await physics_frame
	_check(e.facing_x() < 0.0,
		"먼저 **왼쪽**(플레이어 쪽)을 보게 만들었다 = 반전이 실제로 걸렸다 (facing %.0f)" % e.facing_x())

	# 🔴 넉백 방향 = **플레이어 반대쪽**(`take_hit`) = 지금 보는 쪽의 정반대(= 오른쪽).
	var before: Vector2 = e.global_position
	e.take_hit(5.0, 0, 0, 0.0)
	for i in 6:
		await physics_frame
	_check(e.global_position.x > before.x + 2.0,
		"ⓑ 넉백이 실제로 뒤로 밀었다 (%.1f → %.1f — 안 밀렸으면 ⓐ가 아무것도 안 잰다)"
			% [before.x, e.global_position.x])
	_check(e.facing_x() < 0.0,
		"ⓐ 🔴 밀리는 동안에도 가려던 쪽을 본다 (facing %.0f — +1이면 반전을 넉백 「뒤」에서 계산한 것)"
			% e.facing_x())
	e.free()
	stub.free()
	_drop(KNOCK_PROBE)


## [7] 🔴🔴 **시트가 어느 쪽을 보나를 PNG 픽셀로 검산한다** — 사람의 눈에 기대지 않게 하는 장치.
##  `SPRITE_FACES_LEFT`를 눈으로 읽어 반대로 넣은 적이 있고, 이 파일이 그 오독을 기대치로 굳혀
##  **늑대가 뒷걸음질로 달리는데 45/45 그린**이었다. 잡은 건 헤드리스가 아니라 실게임 스샷이다.
## 🔴 지표 = **「가장 붉은 화소가 몸 bbox 중심의 어느 쪽인가」.** 늑대 몸은 저채도인데 얼굴만 붉다.
## 🔴 **이 지표는 전 종에 서지 않는다 — 그래서 목록을 안 박고 「서는지」를 매번 재서 파생시킨다**:
##   `hound` +22.0(눈) · `hound_alpha` +20.0(주둥이)는 판정 · `slime_elite`·`gale`은 얼굴이 없어 건너뜀
##   · `snake_head`는 회전 몸이라 목록에서 제외.
##  ⚠ 얼굴 없는 몸은 최대 score가 여러 화소에서 **동점**이라 값이 구현마다 흔들린다 —
##   그 흔들림 자체가 「얼굴이 없다」의 증거고, 흔들려도 문턱 근처엔 못 간다.
##  🔴 「지표가 서는 몸」과 「반전이 뜻을 갖는 몸」이 정확히 일치한다 — 지표가 못 서는 몸은
##   애초에 지킬 방향 계약이 없다(구슬·블롭은 반전이 화면상 무변화, 뱀은 rotation이 방향이다).
## ⚠ **쓰다 버린 지표 둘 — 다시 시도하지 마라**: 불투명 화소 무게중심(뒷다리·꼬리가 커서 −1.8px로
##  반대를 가리킨다) · 상단 25% 띠 중심(고개 숙인 `hound_alpha`에서 −0.6이라 안 선다).
## 🔴 `judged >= 2`가 안전핀이다 — 지표가 무너지면 판정 대상이 0이 되어 **아무것도 안 재면서 그린**이 된다.
## 🔴 빨개졌을 때: 지표가 흔들린 건지 **방향이 실제로 바뀐 건지**는 사람이 갈라야 한다. 시트를 확대해
##  보고, 방향이 바뀌었으면 `SPRITE_FACES_LEFT`를 뒤집고, 지표가 흔들린 것이면 **지표를** 고쳐라.
## 🔴 시트 목록은 `Db`에서 **파생**한다 — 하드코딩하면 새 잡몹이 자동으로 안 든다.
##  ⚠ 회전 몸은 **명시적으로** 뺀다 — 지표가 우연히 서면 **없는 계약을 단언**하게 된다.
const FACE_MARGIN_PX := 8.0   ## 최소 여유(px) — 실측 +20~+24의 절반 이하. 손질엔 안 흔들리고 반전엔 반드시 걸린다
const FACE_JUDGED_MIN := 2    ## 판정한 시트가 이보다 적으면 빨강(= 지표가 무너졌다는 통보)

func _test_sheet_direction_matches_constant() -> void:
	print("[7] 🔴🔴 시트 방향을 PNG 픽셀로 검산한다 (사람 눈에 기대지 않는다)")
	# 🔴 상수를 **코드에서 읽는다** — 여기 true/false를 베끼면 그 순간 사본이 둘이 된다.
	#  ⚠ 노드를 만들지 않는다(누수) — 스크립트 리소스에서 상수 표를 바로 꺼낸다.
	var body_script := load("res://src/field/forest_enemy.gd") as GDScript
	var faces_left: bool = body_script.get_script_constant_map().get("SPRITE_FACES_LEFT", true)
	var want_right := not faces_left
	var judged := 0
	for path: String in _flippable_sheets():
		var d := _red_offset(path)
		if d.is_empty():
			_check(false, "%s를 디스크에서 읽었다" % path.get_file())
			continue
		var worst: float = d["worst"]
		# 🔴 **지표가 서는지 먼저 본다** — 여유가 문턱 아래거나 프레임마다 부호가 갈리면
		#  그 시트는 「얼굴이 없다」= 방향 계약이 없다 ⇒ 단언하지 않고 건너뛴다(위 표).
		if absf(worst) < FACE_MARGIN_PX or not bool(d["consistent"]):
			print("     ⏭ %s: 지표가 안 선다 (여유 %+.1fpx · 부호일치 %s) — 얼굴이 없는 몸이다"
				% [path.get_file(), worst, d["consistent"]])
			continue
		judged += 1
		_check((worst > 0.0) == want_right,
			"🔴 %s: 가장 붉은 화소(얼굴)가 몸 중심의 **%s**쪽이다 = 상수와 일치 (여유 %+.1fpx · %d프레임)"
				% [path.get_file(), "오른" if want_right else "왼", worst, int(d["frames"])])
	_check(judged >= FACE_JUDGED_MIN,
		"🔴🔴 지표가 서는 시트가 %d장 이상이다 (실제 %d — 적으면 아무것도 안 재면서 그린이다)"
			% [FACE_JUDGED_MIN, judged])


## 🔴 반전이 **뜻을 갖는** 몸의 시트만 모은다 — `Db`에서 파생(목록 하드코딩 금지).
## ⚠ 회전 몸은 뺀다(`_uses_rotation_facing()`의 짝 — 그쪽은 `rotation`이 방향이다).
## ⚠ id를 **`String`으로 정렬**한다 — `StringName` 배열의 `sort()`는 인터닝 순이라 실행마다 바뀐다.
func _flippable_sheets() -> Array[String]:
	var out: Array[String] = []
	var ids: Array = _db.enemies.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	for id in ids:
		var def = _db.enemies[id]
		if def == null:
			continue
		if str(def.params.get("ai", "chase")) == "boss_snake":
			continue
		var p := str(def.params.get("sprite", ""))
		if p != "" and not out.has(p):
			out.append(p)
	return out


# ── 헬퍼 ──

## 시트 한 장을 프레임별로 훑어 **「가장 붉은 화소 x − 몸 bbox 중심 x」**를 잰다([7] 머리말).
## 반환: {"worst": 절댓값이 가장 작은 오프셋(부호 유지) · "frames": 잰 프레임 수 · "consistent": 부호 일치}
##
## 🔴 `load()`(임포트 캐시)가 아니라 **`Image.load_from_file`(디스크)**다 — 기준은 아트 원본이어야 한다.
## ⚠ bbox는 `a > 0`, 붉기 판정은 `a > 0.75`로 갈랐다 — 외곽 반투명 화소가 색을 흐려 붉기를 흔든다.
func _red_offset(path: String) -> Dictionary:
	var img := Image.load_from_file(path)
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
	var side := img.get_height()
	if side <= 0 or img.get_width() < side:
		return {}
	var frames := maxi(1, img.get_width() / side)
	var offs: Array[float] = []
	for f in frames:
		var lo := side
		var hi := -1
		var best := -1.0e9
		var bx := 0
		for x in side:
			for y in side:
				var c := img.get_pixel(f * side + x, y)
				if c.a <= 0.0:
					continue
				lo = mini(lo, x)
				hi = maxi(hi, x)
				if c.a <= 0.75:
					continue
				var score: float = c.r - (c.g + c.b) * 0.5
				if score > best:
					best = score
					bx = x
		if hi < lo:
			continue
		offs.append(float(bx) - (float(lo + hi) * 0.5))
	if offs.is_empty():
		return {}
	var worst: float = offs[0]
	var pos := 0
	var neg := 0
	for o: float in offs:
		if absf(o) < absf(worst):
			worst = o
		if o > 0.0:
			pos += 1
		elif o < 0.0:
			neg += 1
	return {"worst": worst, "frames": offs.size(), "consistent": pos == 0 or neg == 0}


## 🔴 추격 탐침 — **좌우로 확실히 움직이는** 몸이 필요할 뿐이라 수치가 단순하다.
##  • `aggro_range 5000` = 스텁을 어디로 옮겨도 따라온다(거리 게이트를 재는 그물이 아니다)
##  • `attack_range 0` = 접촉 판정에 절대 안 든다 → `GameState.hp`를 안 건드린다(다른 그물과 격리)
##  • `move_speed 90` = 20프레임에 30px — 데드존(12px/s)을 여유 있게 넘고 스텁엔 안 닿는다
const CHASE_PROBE := &"facing_probe_chase"

func _inject_chase() -> void:
	_inject(CHASE_PROBE, {
		"aggro_range": 5000.0,
		"attack_cooldown": 5.0,
		"attack_range": 0.0,
		"contact_damage": 0.0,
		"move_speed": 90.0,
	})


## 🔴 돌진 탐침 — **윈드업이 길다**(1.5s = 90프레임). 스텁을 옮기고도 예고가 아직 떠 있어야
##  [3]ⓒ가 「멈춰 있는 동안」을 실제로 재기 때문이다(hound의 0.5s로는 창이 너무 좁다).
##  • `charge_trigger_range 120` < 스텁 거리 150 ⇒ 먼저 **접근하며 방향을 세우고** 나서 윈드업
##  • `attack_range 20` = 예고 반경이 0이 아니어야 [4]ⓓ가 뜻을 갖는다(반경 0이면 자명 비교)
##  • `contact_damage 0` = 혹시 닿아도 `GameState`를 안 흔든다
const CHARGE_PROBE := &"facing_probe_charge"

func _inject_charge(id: StringName) -> void:
	_inject(id, {
		"ai": "charge",
		"aggro_range": 5000.0,
		"attack_cooldown": 5.0,
		"attack_range": 20.0,
		"charge_speed": 200.0,
		"charge_trigger_range": 120.0,
		"contact_damage": 0.0,
		"dash_sec": 0.4,
		"move_speed": 80.0,
		"recover_sec": 0.2,
		"windup_sec": 1.5,
	})


## 한 판을 돌려 **그려진 예고 범위**를 얻는다 — 스텁을 `x`에 두고 윈드업까지 기다린다.
## 🔴 `charge_band_reach()`는 params를 되계산하지 않고 **폴리곤을 실측**한다(그 함수 머리말) —
##  그래서 좌·우 두 판의 값이 갈리면 화면이 실제로 갈린 것이다.
func _band_reach_from(x: float) -> Vector2:
	var stub := _stub(Vector2(x, 0.0))
	var e = await _spawn(CHARGE_PROBE)
	var up := await _await_band(e, 90)
	var reach: Vector2 = e.charge_band_reach() if up else Vector2.ZERO
	e.free()
	stub.free()
	# 예고는 **씬 소유**라 몸을 free해도 안 사라진다 — 다음 판이 세는 것과 안 섞이게 가라앉힌다.
	await process_frame
	return reach


## 발밑 그림자 — `_attach_shadow`가 코드로 붙이므로 이름이 없다. `Visual`은 AnimatedSprite2D
## (Node2D 파생, Sprite2D가 **아니다**)라 자식 중 유일한 `Sprite2D`가 곧 그림자다.
## ⚠ 내부 필드(`_shadow`)를 안 더듬는다 — 여기서 재는 건 **화면에 붙은 노드**다.
func _shadow_of(e) -> Sprite2D:
	for c in e.get_children():
		if c is Sprite2D:
			return c as Sprite2D
	return null


## in-memory EnemyDef 주입 — `Db` 레지스트리가 평범한 Dictionary라 가능하다.
## `has_counter = false` · hp 500 = 이 그물은 적을 안 죽인다(죽으면 방향을 못 잰다).
func _inject(id: StringName, params: Dictionary) -> void:
	var def = (load("res://src/core/schemas/enemy_def.gd") as GDScript).new()
	def.id = id
	def.hp = 500.0
	def.has_counter = false
	var p := {"sprite": PROBE_SPRITE}
	p.merge(params, true)
	def.params = p
	_db.enemies[id] = def


## 🔴 주입 제거 — 안 걷으면 뒤 테스트의 적 수가 는다(`Db.enemies`는 공유 레지스트리다).
func _drop(id: StringName) -> void:
	_db.enemies.erase(id)


## 「플레이어」 스텁 — 그룹 `"player"`가 적의 유일한 조준 경로다(`forest_enemy._player`).
## 🔴 **한 번에 하나만 살려 둔다** — `get_first_node_in_group`은 여럿이면 아무거나 고른다.
## ⚠ 맨몸 Node2D면 충분하다 — 적이 스텁에게 묻는 것은 `is_rolling()`(덕타이핑 · 없으면 안 구른 것)뿐이다.
func _stub(pos: Vector2) -> Node2D:
	var s := Node2D.new()
	s.add_to_group("player")
	root.add_child(s)
	s.global_position = pos
	return s


## 적 하나를 원점에 스폰한다 — `enemy_id`는 **_ready 전에** 세워야 `_def`가 그 몸으로 잡힌다.
func _spawn(id):
	var e = _enemy_scene.instantiate()
	e.enemy_id = id
	root.add_child(e)
	e.global_position = Vector2.ZERO
	await process_frame
	await physics_frame
	return e


## 예고가 뜰 때까지 기다린다(최대 `budget` 물리 프레임) — 프레임 수를 계약으로 안 삼는 형태.
func _await_band(e, budget: int) -> bool:
	for i in budget:
		if e.charge_band_visible():
			return true
		await physics_frame
	return e.charge_band_visible()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
