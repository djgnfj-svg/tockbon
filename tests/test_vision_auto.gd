extends SceneTree
## 🔴🔴 시야 자동 검증 (세104 N27 — 정본 `docs/takbon-design/vision_design.md`) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_vision_auto.gd
## 전 항목 통과 시 "TEST_VISION_OK" 출력 후 종료 코드 0.
##
## 한 줄: **플레이어가 보는 쪽(부채꼴)과 몸 둘레(주변시) 밖의 적은 몸·그림자가 사라지고
## 공격 예고만 남는다.** 지형·드롭·투사체는 시야와 무관하게 늘 보인다.
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##   • [1] 판정(`src/core/vision.gd`)은 **순수 static이라 직접 호출해 표로** 잰다
##   • [2] 🔴 **데이터 불변식** — 바탕 종은 「쫓으면 보인다」가 보장되고 네임드만 등 뒤를 받는다.
##         **리터럴 220을 박지 않는다**(balance에서 읽는다) — 잡몹을 늘리는 날 여기가 빨개진다
##   • [3] 🔴 **보스 전원이 `always_visible`인가** — 챕터의 `boss_enemy_id`를 **데이터에서 모아** 잰다
##   • [4] 적의 실제 알파가 시야 밖에서 0으로 수렴하고 안에서 1.0으로 돌아온다 + 그림자 동조
##   • [5] 🔴 **분산 × 시야 = 곱셈**(V1) — 네 조합 + 페이드 내내 분산 상한을 안 넘는다
##   • [6] 🔴🔴 **돌풍 링이 안 물린다**(V2) — 링은 적의 **자식**이라 이게 유일한 검출자다
##   • [7] 돌진 예고가 안 물린다 (⚠ 씬 자식이라 V2 검출력은 0 — 아래 그 함수 머리말)
##   • [8] 보스 예외 — `always_visible`이면 시야 밖에서도 1.0
##   • [9] 🔴 **물리 불변 + 숫자 차단을 한 항목에**(V5·V9) — 안 보여도 **HP는 준다**,
##         그런데 피해 숫자는 안 뜬다. **양성 대조**(보이면 뜬다)를 같이 둬야 자명 통과가 아니다
##   • [10] 폴백(V10) — `vision_dir()`이 없는 몸이면 **보인다**(fail-open)
##   • [11] 🔴 **갱신 자리**(V12) — 플레이어가 사라져도 적이 **마지막 알파에 굳지 않는다**
##
## ⚠ **못 잡는 것 = 「긴장되나」 그 자체**(이 작업의 성공 기준인데 헤드리스도 스샷도 못 잰다):
##  120°/560/220이 답답한가 · 경계에서 깜빡이나(0.18s) · **예고만 뜨는 게 「저기 뭔가 있다」로
##  읽히나 「버그로 빨간 게 떴다」로 읽히나**(가장 큰 미지수) · 네임드의 등 뒤 60px가 「무섭다」인가
##  「억울하다」인가. 전부 **F5 · 사용자 손**이다.
##
## 🔴 **공개 API로만 검증한다**(takbon-verify §3): `is_seen()`·`hp()`·`charge_band_visible()` ·
##  `modulate`(화면 그 자체) · `EnemyDef.params`. 내부 필드(`_vision_alpha`·`_seen`)는 안 더듬는다.
##
## 🔴 **조준을 정확히 지정하려고 스텁을 쓴다** — `player_caster._aim`은 private이고 setter가 없어서
##  진짜 플레이어를 쓰면 헤드리스의 `get_global_mouse_position()`(대개 뷰포트 원점)에 조준이
##  딸려 흔들린다. 덕타이핑 계약(`has_method(&"vision_dir")`)이라 스텁이 성립한다
##  (`test_feel_auto [3]`이 쓰는 맨몸 스텁 수법의 확장).
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.


## 🔴 **시야를 가진 플레이어 스텁** — `vision_dir()` 하나만 들고 조준을 **정확히** 지정한다.
##  ⚠ 파일 하나로 닫으려고 내부 클래스로 뒀다(테스트는 자기 파일 밖에 스크립트를 안 만든다).
class VisionStub extends Node2D:
	var aim_dir: Vector2 = Vector2.RIGHT
	func vision_dir() -> Vector2:
		return aim_dir


## 🔴🔴 **스토커 목록 — 그물이 손으로 든 기대치다**(설계 §4-1 그물).
##  `.tres`에 `stalks` 같은 플래그를 **넣지 마라** — 코드가 안 읽는 데이터는 곧장 거짓 손잡이(T3)가
##  된다. 예외는 여기(그물)에 남기고 데이터는 안 늘린다.
## 🔴 이 목록에 든 종은 **주변시보다 큰 aggro**를 가져야 한다 = 「등 뒤를 준다」가 실현됐나.
##  네임드를 순하게 조이다 aggro를 주변시 밑으로 내리면 그 정체성이 **값 하나로 조용히 증발**하는데,
##  [2]ⓑ가 그날 빨개진다(설계 V7-b).
const STALKERS: Array[StringName] = [&"hound_alpha"]

## 시야가 살아있는 몸을 잰다 — 시트는 살아 있는 PNG를 빌린다(재는 건 **가시성**이지 그림이 아니다).
const PROBE_SPRITE := "res://assets/sprites/enemies/hound.png"

## 페이드(0.18s ≈ 11 물리 프레임)가 수렴할 때까지 — 넉넉히 둔다(경계 흔들림에 강하게).
const SETTLE_FRAMES := 30

var failures: int = 0
var _gs = null
var _db = null
var _bus = null
var _vision = null
var _enemy_scene = null
var _room = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("TEST_VISION_TIMEOUT — 90초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_bus = root.get_node("/root/EventBus")
	_vision = load("res://src/core/vision.gd")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene

	# 🔴 예고·피해 숫자·죽음 폭발이 전부 `get_tree().current_scene`에 붙는다 — 헤드리스엔
	#  메인 씬이 없어 null이라 컨테이너를 세운다(test_enemy_ai_auto 선례).
	_room = Node2D.new()
	root.add_child(_room)
	current_scene = _room

	_test_judgement_table()
	_test_data_invariant()
	_test_bosses_always_visible()
	await _test_enemy_alpha_follows_vision()
	await _test_disperse_times_vision()
	await _test_gust_ring_survives()
	await _test_charge_band_survives()
	await _test_boss_exception()
	await _test_physics_intact_numbers_blocked()
	await _test_fail_open()
	await _test_no_player_does_not_freeze()

	if failures == 0:
		print("TEST_VISION_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_VISION_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 판정 표 — `Vision.is_seen`은 **순수 static**이라 노드도 씬도 없이 직접 호출한다.
## 🔴 **수치를 인자로 넘긴다** — 그 파일 머리말이 그렇게 못 박았다(static 안에서 balance를 읽으면
##  컴파일 타임에 굳어 아래 뮤테이션이 아무 효과도 못 낸다). 여기 값도 balance에서 읽어
##  「120/560/220」을 손으로 박지 않는다 = 사용자가 조여도 이 표가 따라간다.
## ⚠ **경계 바로 안팎을 짚는다** — 넉넉한 값만 재면 각도·거리를 크게 틀어도 안 빨개진다(세100 N25).
func _test_judgement_table() -> void:
	print("[1] 판정 표 — 부채꼴 ∪ 주변시 (순수 함수 직접 호출)")
	var deg: float = _gs.balance.vision_fan_deg
	var rng: float = _gs.balance.vision_fan_range
	var near: float = _gs.balance.vision_near_radius
	var o := Vector2.ZERO
	var aim := Vector2.RIGHT

	_check(_vision.is_seen(o, aim, Vector2(rng - 60.0, 0), deg, rng, near),
		"정면 %.0f(사거리 안) → 보인다" % (rng - 60.0))
	_check(not _vision.is_seen(o, aim, Vector2(rng + 40.0, 0), deg, rng, near),
		"정면 %.0f(사거리 밖) → 안 보인다" % (rng + 40.0))
	# 옆 90° — 부채꼴 반각(60°) 밖이다. 주변시보다 멀면 안 보이고, 안이면 **방향과 무관하게** 보인다.
	_check(not _vision.is_seen(o, aim, Vector2(0, near + 180.0), deg, rng, near),
		"옆 90°·%.0f(주변시 밖) → 안 보인다 = 부채꼴이 옆을 안 덮는다" % (near + 180.0))
	_check(_vision.is_seen(o, aim, Vector2(0, near - 20.0), deg, rng, near),
		"옆 90°·%.0f(주변시 안) → 보인다 = 주변시는 방향을 안 본다" % (near - 20.0))
	_check(_vision.is_seen(o, aim, Vector2(-(near - 120.0), 0), deg, rng, near),
		"뒤 %.0f(주변시 안) → 보인다" % (near - 120.0))
	_check(not _vision.is_seen(o, aim, Vector2(-(near + 200.0), 0), deg, rng, near),
		"뒤 %.0f(주변시 밖) → 안 보인다" % (near + 200.0))
	# 🔴 부채꼴 경계 — 반각 바로 안/밖. 각도를 크게 벌리는 뮤테이션(fan_deg→360)의 검출자다.
	var half := deg * 0.5
	var mid := (near + rng) * 0.5
	_check(_vision.is_seen(o, aim, Vector2.RIGHT.rotated(deg_to_rad(half - 4.0)) * mid, deg, rng, near),
		"반각 %.0f° 바로 안 → 보인다" % half)
	_check(not _vision.is_seen(o, aim, Vector2.RIGHT.rotated(deg_to_rad(half + 4.0)) * mid, deg, rng, near),
		"반각 %.0f° 바로 밖 → 안 보인다" % half)
	# 🔴 **좌우 대칭** — 각도 부호를 뒤집는 뮤테이션(`angle_to`의 부호 실수)은 한쪽만 재면 안 걸린다.
	_check(_vision.is_seen(o, aim, Vector2.RIGHT.rotated(deg_to_rad(-(half - 4.0))) * mid, deg, rng, near),
		"🔴 반대쪽 반각 바로 안도 보인다 = 부채꼴이 좌우 대칭이다 (한쪽만 재면 부호 뒤집기를 놓친다)")
	# 🔴 fail-open — 조준이 영벡터면 각도가 정의되지 않는다 ⇒ 「판정 불가」 ⇒ 보인다.
	_check(_vision.is_seen(o, Vector2.ZERO, Vector2(rng + 500.0, 0), deg, rng, near),
		"🔴 조준이 영벡터면 아무리 멀어도 보인다 (fail-open — 설계 A4)")

	# 🔴🔴 **전방위(360°) — 「정확히 등 뒤」가 이 함수의 실제 사고 자리다**(세105에 밟았다).
	#
	# `Vector2.angle_to`는 **float32**로 정확히 등 뒤에서 `3.14159274…`를 돌려주는데
	# `deg_to_rad(180.0)`은 **double** `3.14159265…`라 `<=`가 **거짓**이 된다
	# ⇒ **「360°인데 등 뒤만 안 보인다」.** 360°는 인지 설계 §7-b의 **폴백값**이라
	# (*"`sight_angle` 키가 없으면 늘 본다 = 옛 동작"*) 하위호환의 심장이 한 각도에서만 멎었다.
	# 실측: 인지 키 0개인 몸을 등 뒤에 둔 판이 굳어 **다른 파일 16건**이 빨개졌다.
	#
	# 🔴 **주변시 밖에서 재야 한다** — 안쪽이면 주변시가 먼저 잡아 **자명 통과**가 된다.
	# 🔴 **각도를 손으로 만들지 않고 `Vector2.LEFT`를 그대로 쓴다** — 정확히 π를 만들어야
	#   이 검사가 뜻이 있다(`rotated(deg_to_rad(180.0))`으로 만들면 오차가 달라 못 잡을 수 있다).
	var far_back := Vector2.LEFT * ((near + rng) * 0.5)
	_check(_vision.is_seen(o, aim, far_back, 360.0, rng, near),
		"🔴🔴 부채꼴 360°면 **정확히 등 뒤**(주변시 밖 %.0f)도 보인다 = 전방위가 각도 비교에 안 걸린다"
			% far_back.length())
	_check(_vision.is_seen(o, aim, Vector2.LEFT.rotated(0.0001) * ((near + rng) * 0.5), 360.0, rng, near),
		"🔴 360°면 등 뒤 언저리도 보인다 (경계 하나만 우연히 통과하는 게 아니다)")
	# ⚠ 짝 검사 — 360° 가드가 **사거리까지 무시하면** 안 된다(그러면 무한 시야가 된다).
	_check(not _vision.is_seen(o, aim, Vector2.LEFT * (rng + 200.0), 360.0, rng, near),
		"🔴 360°여도 **사거리 밖은 안 보인다** (전방위 가드가 거리 판정을 안 삼킨다)")


## [2] 🔴🔴 **데이터 불변식 — 이 설계의 심장**(§4-1).
##
##   주변시 ≥ aggro 이면 → **나를 쫓기 시작한 적은 반드시 보인다.**
##   안 보이는 적 = 아직 나를 모르는 적. 긴장은 「저 너머에 뭐가 있나」에서 오고,
##   짜증(「안 보이는 데서 맞았다」)이 그 자리를 안 뺏는다.
##
## 🔴 **단, 이 보장은 「바탕 종」에만 적용된다** — 네임드는 **일부러** 보장 밖이다(§4-1-b 사용자
##  확정 *"네임드에 등 뒤 주기"*). 그래서 세 갈래다: 보스는 건너뛰고 · 스토커는 `>` · 나머지는 `≤`.
## 🔴 **리터럴 220을 박지 마라** — balance에서 읽는다. 잡몹을 늘리는 날 aggro가 주변시를 넘으면
##  ⓐ가 빨개지고, 네임드를 순하게 조이다 주변시 밑으로 내리면 ⓑ가 빨개진다.
func _test_data_invariant() -> void:
	print("[2] 🔴🔴 데이터 불변식 — 바탕 종은 「쫓으면 보인다」 · 네임드만 등 뒤를 받는다")
	var near: float = _gs.balance.vision_near_radius
	# 🔴 스토커 목록이 **실재하는 적**을 가리키나 — 오타면 아래 ⓑ가 통째로 자명 통과가 된다.
	for id: StringName in STALKERS:
		_check(_db.get_enemy(id) != null,
			"STALKERS의 '%s'가 data/enemies에 실재한다 (오타면 ⓑ가 자명 통과다)" % id)

	var ids: Array = _db.enemies.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	var judged := 0
	for id: StringName in ids:
		var def = _db.enemies[id]
		if def == null:
			continue
		# 보스는 건너뛴다 — 무대에 오른 적은 애초에 안 숨는다(§4-3).
		if bool(def.params.get("always_visible", false)):
			continue
		# 🔴 세105 **이름 승계** — `aggro_range` → `sight_range`(설계 §8-1 · C1).
		#  🔴🔴 **은퇴가 아니라 승계인 이유가 바로 이 불변식이다**: 키를 지웠으면 여기가 0을 받아
		#   바탕 조건은 **자명 통과** · 스토커 조건은 **빨강**이 됐다(그 사이 네임드의 정체성이 증발한다).
		var aggro := float(def.params.get("sight_range", def.params.get("aggro_range", 0.0)))
		if aggro <= 0.0:
			continue   # aggro를 안 쓰는 몸(고정 표적 등)은 이 불변식의 대상이 아니다
		judged += 1
		if STALKERS.has(id):
			# ⓑ 🔴 네임드 = 주변시보다 크게 = 그 차이가 「등 뒤 몇 px」다
			_check(aggro > near,
				"ⓑ 🔴 네임드 %s의 aggro %.0f > 주변시 %.0f = 등 뒤 %.0fpx를 받는다 (밑돌면 정체성이 값 하나로 증발한다)"
					% [id, aggro, near, aggro - near])
		else:
			# ⓐ 🔴 바탕 종 = 주변시 이하 = 쫓기 시작한 적은 반드시 보인다
			_check(aggro <= near,
				"ⓐ 🔴 바탕 종 %s의 aggro %.0f ≤ 주변시 %.0f = 「쫓으면 보인다」 보장 (넘으면 뒤에서 물린다)"
					% [id, aggro, near])
	_check(judged >= 2,
		"불변식을 실제로 잰 적이 둘 이상이다 (실제 %d — 0이면 위가 통째로 자명 통과다)" % judged)


## [3] 🔴🔴 **보스 전원이 `always_visible`인가 — 데이터 주도**(V13).
##
## 🔴 **적 id를 손으로 나열하지 마라** — 챕터4가 생기는 날 자동으로 빨개져야 한다.
##  `data/chapters/*.tres`의 `boss_enemy_id`를 **전부 모아** 그 `EnemyDef`를 단언한다.
## ⚠ **`slime_elite`를 빠뜨리기 쉽다**: 이름이 잡몹처럼 생겼고(초고도 리뷰도 「바탕 종」으로
##  잘못 분류했다) aggro 200 < 220이라 **평소엔 멀쩡해 보인다.** 그러다 보스전 중 200px 밖으로
##  벌어지고 마우스가 딴 데를 보는 순간 **보스가 사라진다** — 가장 나쁜 때에만 나타나는 고장이다.
##  🔴 **적의 분류는 이름이 아니라 `.tres`의 어느 칸에 꽂혔나로 갈라라.**
func _test_bosses_always_visible() -> void:
	print("[3] 🔴🔴 보스 전원 always_visible — 챕터의 boss_enemy_id를 데이터에서 모아 잰다")
	var boss_ids := {}
	for cid in _db.chapters:
		var ch = _db.chapters[cid]
		if ch != null and ch.boss_enemy_id != &"":
			boss_ids[ch.boss_enemy_id] = true
	var sorted: Array = boss_ids.keys()
	sorted.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	_check(sorted.size() >= 1,
		"챕터에서 보스 id를 모았다 (실제 %d종 — 0이면 아래가 자명 통과다)" % sorted.size())
	for id: StringName in sorted:
		var def = _db.get_enemy(id)
		if def == null:
			_check(false, "보스 id '%s'가 data/enemies에 실재한다" % id)
			continue
		_check(bool(def.params.get("always_visible", false)),
			"🔴 보스 %s의 params.always_visible = true (무대에 오른 적은 안 숨는다 — 조준이 시야에 묶인 조작 벌칙이 된다)"
				% id)


## [4] 🔴 적의 **실제 알파**가 판정을 따라간다 — 몸과 **그림자**가 같이 사라지고 같이 돌아온다.
## 🔴 **그림자를 같이 재는 게 요점이다**(V3): 몸은 없는데 발밑 타원만 떠 있으면 **위치가 그대로
##  새 나간다.** 그림자는 그룹에도 안 들고 참조도 없었어서(`shadow.gd`) 손잡이를 새로 만든 자리다.
## 🔴 `is_seen()`(판정 캐시)과 `modulate.a`(그 결과의 페이드)가 **같은 이야기**를 하는지도 본다 —
##  둘을 각자 계산하면 세85 *"검증 도구가 거짓말한다"* 자리가 된다.
func _test_enemy_alpha_follows_vision() -> void:
	print("[4] 적의 알파 — 시야 밖 0으로 수렴 · 안 1.0 복귀 · 🔴 그림자 동조")
	var stub := VisionStub.new()
	stub.aim_dir = _blind_aim()
	stub.global_position = _blind_pos()   # 등 뒤 = 주변시 밖 · 부채꼴 각도 밖
	stub.add_to_group("player")
	root.add_child(stub)

	var e = await _spawn(&"vis_probe_still", Vector2.ZERO)
	await _frames(SETTLE_FRAMES)
	var vis := e.get_node_or_null(^"Visual") as CanvasItem
	var shadow := _shadow_of(e)
	if vis == null or shadow == null:
		_check(false, "Visual·그림자를 찾았다 (구조가 바뀌면 이 그물이 죽는다)")
		e.free()
		stub.free()
		return

	_check(not e.is_seen(), "🔴 %.0fpx 뒤쪽 = 안 보인다 (is_seen 캐시)" % _blind_pos().y)
	_check(is_zero_approx(vis.modulate.a),
		"🔴 몸 알파가 0으로 수렴한다 (실제 %.3f — 반투명이면 「가려졌다」가 아니라 「흐린 적」이 된다)"
			% vis.modulate.a)
	_check(is_zero_approx(shadow.modulate.a),
		"🔴 **그림자도** 0이다 (실제 %.3f — 발밑 타원만 남으면 위치가 그대로 샌다)" % shadow.modulate.a)

	# 시야 안으로 — 주변시(방향 무관) 안에 들어온다.
	stub.global_position = _seen_pos()
	await _frames(SETTLE_FRAMES)
	_check(e.is_seen(), "🔴 주변시 안으로 들어오면 보인다 (방향은 여전히 등 뒤다)")
	_check(is_equal_approx(vis.modulate.a, 1.0),
		"🔴 몸 알파가 **정확히 1.0**으로 돌아온다 (실제 %.3f — 새면 페이드가 안 닫힌 것)" % vis.modulate.a)
	_check(is_equal_approx(shadow.modulate.a, 1.0),
		"그림자도 1.0으로 돌아온다 (실제 %.3f)" % shadow.modulate.a)

	e.free()
	stub.free()
	_drop(&"vis_probe_still")


## [5] 🔴🔴 **분산 × 시야 = 곱셈**(V1) — 이 설계 최대의 함정이다.
##
## 세63이 못 박은 소유권 계약(**modulate = rgb 상태 틴트 · a 분산**)에 시야가 세 번째 주인이 되면
## 안개의 분산과 시야가 **서로를 덮어쓴다**: 분산이 풀리는 순간 `a = 1.0`을 찍어 **시야 밖인데
## 다시 보인다** — 에러 0 · 전 스위트 그린이다. 그래서 알파 대입을 한 함수로 모으고 **곱했다.**
##
## 🔴 **네 조합을 다 잰다.** 시야만 쓰면 (분산 on·보임)이 빨개지고, 분산만 쓰면 (분산 off·안 보임)이 빨개진다.
## 🔴🔴 **ⓔ가 진짜 곱셈의 검출자다**: 숨김 알파가 0.0이라 「안 보임」 두 칸이 **둘 다 0**이라
##  네 조합만으로는 *"곱했나 골랐나"*를 못 가른다. 분산 중에 시야가 꺼지는 **페이드 내내**
##  알파가 **분산 상한(0.4)을 한 번도 안 넘는지**를 보면 갈린다 —
##  곱이 아니라 시야만 쓰면 1.0에서 출발해 그 구간 대부분이 0.4를 넘는다.
func _test_disperse_times_vision() -> void:
	print("[5] 🔴🔴 분산 × 시야 — 네 조합 + 페이드 내내 분산 상한을 안 넘는다 (V1)")
	var stub := VisionStub.new()
	stub.aim_dir = _blind_aim()
	var seen_at := _seen_pos()     # 주변시 안 = 보인다(조준은 등 뒤)
	var blind_at := _blind_pos()   # 주변시 밖 · 부채꼴 각도 밖 = 안 보인다
	stub.global_position = seen_at
	stub.add_to_group("player")
	root.add_child(stub)

	# hover + `disperse_period`가 분산 축을 돌린다. `move_speed 0`이라 거리가 안 흔들린다.
	_inject(&"vis_probe_hover", 500.0, {
		"ai": "hover",
		"aggro_range": 3000.0,
		"attack_range": 5.0,
		"attack_cooldown": 999.0,
		"disperse_period": 1.0,
		"hover_max": 95.0,
		"hover_min": 55.0,
		"move_speed": 0.0,
	})
	var e = await _spawn(&"vis_probe_hover", Vector2.ZERO)
	var vis := e.get_node_or_null(^"Visual") as CanvasItem
	if vis == null:
		_check(false, "Visual 노드를 찾았다")
		e.free()
		stub.free()
		_drop(&"vis_probe_hover")
		return
	var disp: float = 0.4   # `forest_enemy.DISPERSED_ALPHA` — 연출값이라 손으로 든 기대치다

	# ⓐ 분산 off · 보임 → 1.0 (스폰 직후는 아직 분산 전 — `_ready`가 주기를 채워 둔다)
	await _frames(SETTLE_FRAMES)
	_check(is_equal_approx(vis.modulate.a, 1.0), "ⓐ 분산 off · 보임 → 1.0 (실제 %.3f)" % vis.modulate.a)

	# ⓑ 분산 off · 안 보임 → 0.0
	stub.global_position = blind_at
	await _frames(SETTLE_FRAMES)
	_check(is_zero_approx(vis.modulate.a), "ⓑ 분산 off · 안 보임 → 0.0 (실제 %.3f)" % vis.modulate.a)

	# ⓒ 분산 on · 안 보임 → 0.0 (분산이 켜져도 0을 못 되살린다 — 「다시 보인다」 사고의 자리)
	stub.global_position = seen_at
	var flipped := await _wait_for_dispersed(vis, disp)
	_check(flipped, "분산 토글이 실제로 돌았다 (안 돌면 아래가 통째로 자명 통과다)")
	stub.global_position = blind_at
	await _frames(SETTLE_FRAMES)
	_check(is_zero_approx(vis.modulate.a), "ⓒ 분산 on · 안 보임 → 0.0 (실제 %.3f)" % vis.modulate.a)

	# ⓓ 분산 on · 보임 → 0.4 (시야만 쓰면 여기가 1.0이 되어 빨개진다)
	stub.global_position = seen_at
	var back := await _wait_for_dispersed(vis, disp)
	_check(back, "분산 상태로 시야에 돌아왔다")
	_check(is_equal_approx(vis.modulate.a, disp),
		"ⓓ 🔴 분산 on · 보임 → %.1f (실제 %.3f — 1.0이면 시야가 분산을 덮어쓴 것)" % [disp, vis.modulate.a])

	# ⓔ 🔴🔴 페이드 내내 분산 상한을 안 넘는다 = **정말로 곱했다**
	stub.global_position = blind_at
	var peak := 0.0
	for i in SETTLE_FRAMES:
		await physics_frame
		peak = maxf(peak, vis.modulate.a)
	_check(peak <= disp + 0.001,
		"ⓔ 🔴🔴 분산 중 시야가 꺼지는 페이드 내내 알파가 %.1f를 안 넘는다 (최고 %.3f — 넘으면 곱이 아니라 시야만 쓴 것)"
			% [disp, peak])

	e.free()
	stub.free()
	_drop(&"vis_probe_hover")


## [6] 🔴🔴 **돌풍 링이 시야에 안 물린다 — V2의 유일한 검출자.**
##
## 설계 §3이 *"공격 예고는 시야 밖에서도 보인다"*를 **계약으로 선언**해 뒀는데, §5-2가 동시에
## *"그림자도 꺼야 한다"*를 요구한다. 그걸 만족시키는 **가장 자연스러운 손**이
## *"그럼 알파를 루트에 걸자 — 그림자도 자식이니 공짜"*다. 그 한 줄이 들어가는 순간
## **돌풍 링이 같이 죽는데(에러 0) 계약이 선언돼 있으므로 아무도 의심하지 않는다.**
##
## 🔴 링은 `_visual`의 **형제**(적의 자식)라 이게 유일한 검출자다 — `_charge_band`([7])는
##  **씬 자식**이라 루트에 걸어도 안 죽어서 검출력이 0이다.
## 🔴 **누적 알파를 계산해서 잰다** — Godot의 `modulate`는 렌더 때 부모 것과 곱해지지, 자식의
##  `modulate` 프로퍼티를 바꾸지 않는다. 링 자신의 값만 읽으면 루트에 걸어도 1.0이라 **그린이다.**
func _test_gust_ring_survives() -> void:
	print("[6] 🔴🔴 돌풍 링이 안 물린다 — 링은 적의 **자식**이라 이게 V2의 유일한 검출자다")
	var stub := VisionStub.new()
	stub.aim_dir = _blind_aim()
	stub.global_position = _blind_pos()   # 안 보인다
	stub.add_to_group("player")
	root.add_child(stub)

	# 🔴 **`always_visible` 없는 boss_gale 몸을 주입한다** — 실데이터 `gale`은 늘 보이므로
	#  그대로 쓰면 이 항목이 자명 통과가 된다. `gust_radius`를 크게 줘 **안 보이는 거리에서**
	#  윈드업에 들어가게 한다(가까이 붙으면 주변시에 걸려 보인다 = 조건을 못 만든다).
	_inject(&"vis_probe_gale", 900.0, {
		"ai": "boss_gale",
		"aggro_range": 3000.0,
		"attack_range": 5.0,
		"attack_cooldown": 999.0,
		"move_speed": 0.0,
		"hover_min": 10.0,
		"hover_max": 20.0,
		"gust_radius": 3000.0,
		"gust_period": 0.05,
		"gust_windup": 5.0,      # 관측하는 동안 윈드업이 안 끝나게
		"gust_damage": 0.0,
		"volley_period": 999.0,
		"volley_count": 0.0,
	})
	var e = await _spawn(&"vis_probe_gale", Vector2.ZERO)
	await _frames(SETTLE_FRAMES)
	var vis := e.get_node_or_null(^"Visual") as CanvasItem
	var ring := _line2d_child_of(e)
	_check(not e.is_seen(), "적이 안 보이는 상태다 (전제)")
	_check(vis != null and is_zero_approx(vis.modulate.a),
		"몸은 사라졌다 (실제 %.3f)" % (vis.modulate.a if vis != null else -1.0))
	_check(ring != null and ring.visible,
		"🔴 돌풍 예고 링이 떠 있다 (없으면 아래가 자명 통과다 — 윈드업 조건을 다시 봐라)")
	if ring != null:
		_check(is_equal_approx(_effective_alpha(ring, e), 1.0),
			"🔴🔴 링의 **누적** 알파가 1.0이다 (실제 %.3f — 0이면 알파를 루트에 걸어 예고가 같이 죽은 것)"
				% _effective_alpha(ring, e))

	e.free()
	stub.free()
	_drop(&"vis_probe_gale")


## [7] 돌진 예고(바닥 붉은 띠)가 시야에 안 물린다.
## ⚠ **이 항목의 V2 검출력은 0이다** — 예고는 **씬 자식**(`scene.add_child`)이라 알파를 루트에
##  걸어도 안 죽는다. 그래도 두는 이유: 누군가 예고를 **적 자식으로 되돌리거나**(그 순간 V2가
##  이 항목까지 잡는다) 예고에 직접 알파를 거는 「정리」를 하면 여기가 빨개진다.
##  🔴 **V2를 이 항목으로 재고 만족하지 마라** — 그 검출자는 [6]뿐이다.
func _test_charge_band_survives() -> void:
	print("[7] 돌진 예고가 안 물린다 (⚠ 씬 자식이라 V2 검출력은 0 — 검출자는 [6]이다)")
	var stub := VisionStub.new()
	stub.aim_dir = _blind_aim()
	stub.global_position = _blind_pos()
	stub.add_to_group("player")
	root.add_child(stub)

	# 발동 사거리를 크게 줘 **안 보이는 거리에서** 윈드업에 들어가게 한다([6]과 같은 수법).
	_inject(&"vis_probe_charge", 900.0, {
		"ai": "charge",
		"aggro_range": 3000.0,
		"attack_range": 20.0,
		"attack_cooldown": 999.0,
		"charge_trigger_range": 3000.0,
		"charge_speed": 200.0,
		"dash_sec": 0.4,
		"move_speed": 0.0,
		"windup_sec": 5.0,
	})
	var e = await _spawn(&"vis_probe_charge", Vector2.ZERO)
	await _frames(SETTLE_FRAMES)
	_check(not e.is_seen(), "적이 안 보이는 상태다 (전제)")
	_check(e.charge_band_visible(),
		"🔴 돌진 예고가 떠 있다 (공개 관측점 — 없으면 아래가 자명 통과다)")
	var band := _room.get_node_or_null(^"ChargeBand") as CanvasItem
	if band == null:
		_check(false, "예고 노드를 씬에서 찾았다 (이름 = ChargeBand)")
	else:
		_check(is_equal_approx(_effective_alpha(band, _room), 1.0),
			"🔴 예고의 누적 알파가 1.0이다 = 「기척」은 남는다 (실제 %.3f)" % _effective_alpha(band, _room))

	e.free()
	stub.free()
	await process_frame   # 예고는 씬 소유라 `_exit_tree`가 지운다 — 다음 항목에 안 남게
	_drop(&"vis_probe_charge")


## [8] 보스 예외 — `always_visible`이면 시야 밖에서도 1.0.
## **무대에 오른 적은 숨지 않는다**: 보스전은 화면을 꽉 채우는데 마우스를 딴 데로 돌렸다고 보스가
## 사라지면 「긴장」이 아니라 **조준이 시야에 묶인 조작 벌칙**이 된다.
## 🔴 실데이터 `snake_boss`로 잰다 — 그 몸은 **구조적으로도 필수**다(마디 12개와 마디 그림자가
##  `_visual`과 별개 노드라 안 사라지고, 러시 예고가 `_visual` 셰이더 **하나뿐**이라 머리를 가리면
##  예고가 통째로 0이 된다 = §3의 「예고는 보인다」가 뱀에 대해서만 거짓이 된다).
func _test_boss_exception() -> void:
	print("[8] 보스 예외 — always_visible이면 시야 밖에서도 1.0")
	var stub := VisionStub.new()
	stub.aim_dir = _blind_aim()
	stub.global_position = _blind_pos()
	stub.add_to_group("player")
	root.add_child(stub)

	var e = await _spawn(&"snake_boss", Vector2.ZERO)
	await _frames(SETTLE_FRAMES)
	var vis := e.get_node_or_null(^"Visual") as CanvasItem
	_check(e.is_seen(), "🔴 보스는 시야 밖에서도 is_seen() = true")
	_check(vis != null and is_equal_approx(vis.modulate.a, 1.0),
		"🔴 보스 몸 알파가 1.0 그대로다 (실제 %.3f)" % (vis.modulate.a if vis != null else -1.0))
	var shadow := _shadow_of(e)
	_check(shadow != null and is_equal_approx(shadow.modulate.a, 1.0),
		"보스 그림자도 1.0이다 (머리 없는 뱀이 안 생긴다)")

	e.free()
	stub.free()


## [9] 🔴🔴 **물리 불변 + 숫자 차단을 한 항목에**(V5·V9).
##
## **V5는 의도다**: 시야는 **보이는 것만** 바꾸고 전투는 한 톨도 안 바꾼다 — 안 보이는 적도
## 맞고·때리고·밀린다. 이걸 「버그」로 보고 충돌을 끄면 전투가 통째로 갈린다.
## **V9**: 그런데 **피해 숫자는 안 뜬다** — 뜨면 안 보이는 적의 **위치와 체력이 통째로 샌다**
## (그림자를 끄는 이유와 한 글자도 다르지 않은 사고인데 **모듈이 달라(`juice.gd`) 눈에 안 띈다**).
##
## 🔴 **둘을 같이 재야 한다**: HP만 재면 V9를 못 잡고, 숫자만 재면 「적이 아예 안 맞았다」와 구분이
##  안 된다(자명 통과). 🔴 거기에 **양성 대조**(보이는 적은 숫자가 뜬다)를 붙여야
##  *"juice가 애초에 안 물려 있다"*와도 갈린다.
## ⚠ **트라우마·히트스톱은 일부러 안 막는다** — 그건 「내가 때렸다」의 손맛이라 적이 보이든 말든
##  **내 행동의 반응**이다. 같이 막으면 *"맞은 건가?"*가 되어 더 나쁘다.
func _test_physics_intact_numbers_blocked() -> void:
	print("[9] 🔴🔴 시야 밖에서도 HP는 준다 · 그런데 피해 숫자는 안 뜬다 (V5·V9 + 양성 대조)")
	var stub := VisionStub.new()
	stub.aim_dir = _blind_aim()
	stub.global_position = _blind_pos()
	stub.add_to_group("player")
	root.add_child(stub)

	# 손맛 통제소를 세운다 — 카메라가 없으면 흔들림만 no-op이고 숫자는 그대로 뜬다.
	var juice = (load("res://src/actors/juice.gd") as GDScript).new()
	_room.add_child(juice)
	await process_frame

	var hidden = await _spawn(&"vis_probe_hit", Vector2.ZERO)
	await _frames(SETTLE_FRAMES)
	_check(not hidden.is_seen(), "안 보이는 적이다 (전제)")
	var before_hp: float = hidden.hp()
	var before_n := _damage_number_count()
	hidden.take_hit(12.0, 0, 0, 0.0)
	await process_frame
	_check(hidden.hp() < before_hp - 0.5,
		"🔴 **V5는 의도다** — 안 보여도 HP는 준다 (%.1f → %.1f · 전투는 한 톨도 안 바뀐다)"
			% [before_hp, hidden.hp()])
	_check(_damage_number_count() == before_n,
		"🔴 안 보이는 적의 피해 숫자는 안 뜬다 (%d → %d — 뜨면 위치와 체력이 통째로 샌다)"
			% [before_n, _damage_number_count()])
	hidden.free()
	await _settle_time_scale()

	# 🔴 양성 대조 — 보이는 적은 숫자가 뜬다. 없으면 위 줄이 「juice가 안 물렸다」와 구분이 안 된다.
	stub.global_position = _seen_pos()
	var shown = await _spawn(&"vis_probe_hit", Vector2.ZERO)
	await _frames(SETTLE_FRAMES)
	_check(shown.is_seen(), "보이는 적이다 (전제)")
	var n0 := _damage_number_count()
	shown.take_hit(12.0, 0, 0, 0.0)
	await process_frame
	_check(_damage_number_count() == n0 + 1,
		"🔴 **양성 대조** — 보이는 적은 숫자가 정확히 하나 뜬다 (%d → %d)"
			% [n0, _damage_number_count()])

	shown.free()
	stub.free()
	# ⚠ 순서가 중요하다 — 히트스톱 복구 타이머의 람다가 juice를 캡처한다(먼저 free하면 죽은 객체를 만진다).
	await _settle_time_scale()
	juice.free()
	_free_damage_numbers()
	_drop(&"vis_probe_hit")


## [10] 🔴 **폴백 = 「판정할 수 없으면 보인다」**(V10 · fail-open).
## 취향이 아니라 계약이다: *"알 수 없으니 숨긴다"*는 **안 보여야 할 이유가 없는 적을 지우는**
## 최악의 실패 형태고, 기존 그물 둘(`test_feel_auto` [3]·[10])이 `modulate == Color(1,1,1,1)`
## **완전 일치**를 단언하는데 그 리그의 플레이어가 바로 이 맨몸 스텁이다.
func _test_fail_open() -> void:
	print("[10] 🔴 폴백 — vision_dir()이 없는 몸이면 아무리 멀어도 보인다 (fail-open)")
	var bare := Node2D.new()          # 🔴 `vision_dir()`이 **없다**
	bare.global_position = _blind_pos()
	bare.add_to_group("player")
	root.add_child(bare)

	var e = await _spawn(&"vis_probe_still", Vector2.ZERO)
	await _frames(SETTLE_FRAMES)
	var vis := e.get_node_or_null(^"Visual") as CanvasItem
	_check(e.is_seen(), "🔴 vision_dir()이 없으면 「판정 불가」 = 보인다")
	_check(vis != null and vis.modulate == Color(1, 1, 1, 1),
		"🔴 modulate가 **완전 일치** (1,1,1,1) — 기존 그물 둘이 이 값을 단언한다 (실제 %s)"
			% (str(vis.modulate) if vis != null else "없음"))

	e.free()
	bare.free()
	_drop(&"vis_probe_still")


## [11] 🔴🔴 **갱신 자리 — 플레이어가 사라져도 적이 마지막 알파에 굳지 않는다**(V12).
##
## 시야 갱신을 `_physics_process`의 **끝**에 두면 `player == null` **조기 return**에 먹혀
## 그 경로에서 갱신이 영영 안 돈다 — 씬 전환 사이 · 플레이어 사망 후 · 테스트 리그가 전부
## 그 경로다. 그러면 적이 **투명한 채로 굳고 에러가 0**이다.
## 🔴 그래서 「안 보이는 상태로 만들어 놓고 플레이어를 통째로 없애면 1.0으로 돌아오나」로 잰다
##  — 갱신이 조기 return **앞**에 있어야만 초록이다.
func _test_no_player_does_not_freeze() -> void:
	print("[11] 🔴🔴 플레이어가 사라져도 알파가 굳지 않는다 (V12 — 갱신은 조기 return 앞이다)")
	var stub := VisionStub.new()
	stub.aim_dir = _blind_aim()
	stub.global_position = _blind_pos()
	stub.add_to_group("player")
	root.add_child(stub)

	var e = await _spawn(&"vis_probe_still", Vector2.ZERO)
	await _frames(SETTLE_FRAMES)
	var vis := e.get_node_or_null(^"Visual") as CanvasItem
	_check(vis != null and is_zero_approx(vis.modulate.a),
		"먼저 안 보이게 만들었다 (실제 %.3f)" % (vis.modulate.a if vis != null else -1.0))

	stub.free()               # 🔴 플레이어가 통째로 사라진다 = `_player()`가 null
	await _frames(SETTLE_FRAMES)
	_check(e.is_seen(), "🔴 플레이어가 없으면 「판정 불가」 = 보인다 (fail-open)")
	_check(vis != null and is_equal_approx(vis.modulate.a, 1.0),
		"🔴🔴 알파가 1.0으로 **돌아온다** (실제 %.3f — 0이면 갱신이 조기 return 뒤에 있어 굳은 것)"
			% (vis.modulate.a if vis != null else -1.0))

	e.free()
	_drop(&"vis_probe_still")


# ── 헬퍼 ──

## 🔴🔴 **「안 보이는 자리」 — 주변시 밖이면서 부채꼴 사거리 「안」이다.**
##
## 스텁을 등 뒤(조준 반대쪽)에 두므로 **각도 하나로만** 걸러진다 — 즉 이 자리는
## **부채꼴 각도를 넓히는 뮤테이션의 검출자**다.
## ⚠ 🔴 **아주 멀리(2000px) 두지 마라 — 세104에 실제로 그 구멍을 실측했다.** 사거리 밖이면
##  각도와 무관하게 안 보이므로 `fan_deg`를 360으로 벌려도 여전히 안 보이고, 런타임 항목이
##  **전부 그린인 채로 검출력만 0**이 된다(그때 빨개지는 건 [1]의 순수 함수 표뿐이다).
## 🔴 리터럴을 안 박는다 — balance에서 파생하므로 사용자가 수치를 조여도 이 자리가 따라간다.
func _blind_pos() -> Vector2:
	return Vector2(0, (_gs.balance.vision_near_radius + _gs.balance.vision_fan_range) * 0.5)


## 🔴🔴 **「안 보이는 조준」 — 적 쪽에서 150° 틀어 본다**(적은 늘 스텁의 UP 쪽에 있다).
##
## 🔴 **150°는 세 조건을 동시에 만족하는 유일한 대역이다** — 손으로 든 기대치이지 취향이 아니다:
##   ⓐ 반각(60°)보다 **크다** ⇒ 평소엔 안 보인다(이 항목들의 전제)
##   ⓑ 180°보다 **뚜렷이 작다** ⇒ `fan_deg`를 360으로 벌리면 **보이게 되어 빨개진다**
##   ⓒ 180°에서 뺀 값(30°)이 반각보다 **작다** ⇒ 앞뒤를 뒤집는 뮤테이션(`target - origin`을
##      `origin - target`으로)에도 보이게 되어 빨개진다
##
## ⚠ 🔴 **`Vector2.DOWN`(= 정확히 180°)을 쓰지 마라 — 세104에 실제로 밟았다.**
##  `fan_deg`를 360으로 벌려도 `absf(angle_to) <= deg_to_rad(180)`이 **부동소수 반올림 한 톨 차이로
##  거짓**이 되어(180×(π/180)이 π보다 미세하게 작다) 런타임 항목이 **전부 그린인 채 검출력 0**이었다.
##  실측: 그 뮤테이션이 [1]의 순수 함수 표 2건만 깨웠다. 경계에 정확히 앉지 마라.
const BLIND_AIM_DEG := 150.0

func _blind_aim() -> Vector2:
	return Vector2.UP.rotated(deg_to_rad(BLIND_AIM_DEG))


## 🔴 **「보이는 자리」 — 주변시 안이지만 조준은 여전히 딴 데다** ⇒ **주변시만으로** 보인다.
## ⚠ 부채꼴 **안**에 두지 마라 — 그러면 `near_radius`를 0으로 만드는 뮤테이션에 눈이 없어진다
##  (부채꼴이 대신 보여 줘서 계속 그린이다).
##
## 🔴🔴 **하한(20px)이 뮤테이션 검출력의 조건이다 — 세104에 실측했다.**
##  `near - 40`을 그대로 쓰면 `near_radius → 0` 뮤테이션에서 **좌표가 음수가 되어 스텁이 적의
##  반대편으로 넘어간다** ⇒ 적 방향이 통째로 뒤집혀 조준 150°가 **30°가 되고 부채꼴 안에 들어와**
##  여전히 「보인다」 ⇒ 런타임 항목이 **전부 그린**이었다(실측: 그 뮤테이션이 2건만 깨웠다).
##  🔴 하한을 두면 스텁이 **늘 적의 같은 쪽**에 남아, 주변시가 0이 되는 순간 안 보이게 되어 빨개진다.
func _seen_pos() -> Vector2:
	return Vector2(0, maxf(_gs.balance.vision_near_radius - 40.0, 20.0))


## 🔴 in-memory EnemyDef 주입 (세61 Db 주입 선례 — 레지스트리가 평범한 Dictionary다).
## ⚠ **반드시 `_drop`으로 걷는다** — 공유 레지스트리라 남기면 [2]의 데이터 불변식이 **주입한
##  가짜 몸까지 재고**, 뒤 테스트(같은 프로세스)의 적 수가 는다.
## `has_counter = false` — 약점 배율이 [9]의 HP 판정을 흐리지 않게.
func _inject(id: StringName, hp: float, params: Dictionary) -> void:
	var def = (load("res://src/core/schemas/enemy_def.gd") as GDScript).new()
	def.id = id
	def.hp = hp
	def.has_counter = false
	var p := {"sprite": PROBE_SPRITE}
	p.merge(params, true)
	def.params = p
	_db.enemies[id] = def


func _drop(id: StringName) -> void:
	_db.enemies.erase(id)


## 가만히 서 있는 바탕 몸 — 가시성만 재는 항목들이 쓴다(움직이면 거리가 흔들려 판정이 튄다).
## ⚠ 이 id는 `_spawn`이 필요할 때 만들어 준다(항목마다 주입을 반복하지 않게).
func _ensure_still_probe() -> void:
	if _db.enemies.has(&"vis_probe_still"):
		return
	_inject(&"vis_probe_still", 500.0, {
		"aggro_range": 3000.0,     # chase 필수 수치 — 없으면 `_param_req`가 경고를 뱉는다
		"attack_range": 5.0,
		"attack_cooldown": 999.0,
		"move_speed": 0.0,
	})


func _ensure_hit_probe() -> void:
	if _db.enemies.has(&"vis_probe_hit"):
		return
	_inject(&"vis_probe_hit", 500.0, {
		"aggro_range": 3000.0,
		"attack_range": 5.0,
		"attack_cooldown": 999.0,
		"move_speed": 0.0,
	})


## 적 하나를 스폰한다 — `enemy_id`는 **_ready 전에** 세워야 `_def`가 그 적으로 잡힌다.
## 🔴 씬(`_room`)에 붙인다 — 예고·피해 숫자가 `current_scene`을 찾기 때문이다.
func _spawn(id: StringName, at: Vector2):
	if id == &"vis_probe_still":
		_ensure_still_probe()
	elif id == &"vis_probe_hit":
		_ensure_hit_probe()
	var e = _enemy_scene.instantiate()
	e.enemy_id = id
	_room.add_child(e)
	e.global_position = at
	await process_frame
	await physics_frame
	return e


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## 분산이 켜질 때까지 기다린다 — 분산은 **시간 토글**이라 직접 세울 손잡이가 없다(private).
## 🔴 「보이는 동안」의 알파가 분산 값이 되는 순간을 잡는다 = 그 프레임에 토글이 막 돌았다는 뜻이라
##  다음 토글까지 한 주기(60프레임) 여유가 있다 — 뒤이어 시야를 흔들어도 분산이 안 뒤집힌다.
func _wait_for_dispersed(vis: CanvasItem, disp: float) -> bool:
	for i in 240:
		await physics_frame
		if is_equal_approx(vis.modulate.a, disp):
			return true
	return false


## 🔴🔴 **누적 알파** — Godot의 `modulate`는 렌더 때 부모 것과 곱해지지 자식의 프로퍼티를 안 바꾼다.
##  자식 자신의 값만 읽으면 **알파를 루트에 거는 사고를 못 잡는다**([6] 머리말).
##  `stop`(적 루트·씬 루트)까지 거슬러 올라가며 곱한다.
func _effective_alpha(node: CanvasItem, stop: Node) -> float:
	var a := 1.0
	var n: Node = node
	while n != null and n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		if n == stop:
			break
		n = n.get_parent()
	return a


## 그림자를 찾는다 — 🔴 `shadow.gd`가 *"어떤 그룹에도 가입하지 않는다"*고 못 박아 그룹으로는 못 찾고,
##  이름도 없다. 적의 자식 중 **Sprite2D**가 그림자뿐이라(몸은 AnimatedSprite2D) 타입으로 고른다.
func _shadow_of(enemy: Node) -> Sprite2D:
	for c in enemy.get_children():
		if c is Sprite2D and not (c is AnimatedSprite2D):
			return c as Sprite2D
	return null


## 돌풍 링을 찾는다 — 적의 자식 중 Line2D는 그것뿐이다(`_show_gust_ring`이 만드는 유일한 Line2D).
func _line2d_child_of(enemy: Node) -> Line2D:
	for c in enemy.get_children():
		if c is Line2D:
			return c as Line2D
	return null


## 씬에 떠 있는 피해 숫자 수 — `juice._spawn_number`가 `current_scene`에 직접 붙인다.
func _damage_number_count() -> int:
	var n := 0
	for c in _room.get_children():
		if c is Label and c.get_script() != null \
				and str((c.get_script() as Script).resource_path).ends_with("damage_number.gd"):
			n += 1
	return n


func _free_damage_numbers() -> void:
	for c in _room.get_children():
		if c is Label and c.get_script() != null \
				and str((c.get_script() as Script).resource_path).ends_with("damage_number.gd"):
			c.free()


## 🔴 히트스톱이 풀릴 때까지 — `enemy_hit`을 쏘면 `juice.gd`가 `Engine.time_scale`을 0.05로 떨궈
##  뒤 대기가 **20배 느려진다**(`test_extract_hold_auto._settle_time_scale` 선례).
##
## 🔴🔴 **프레임 수가 아니라 실시간으로 기다린다 — 세104에 실제로 밟았다.**
##  복구 타이머는 `ignore_time_scale = true`라 **실시간 0.035초**를 센다. 그런데 헤드리스는
##  렌더가 없어 한 프레임이 0.05ms 언저리라, 「600 프레임」으로 기다리면 **30ms만에 다 소진**되고
##  time_scale이 0.05인 채로 빠져나온다 ⇒ 뒤 항목의 `delta`가 20분의 1이 되어
##  **0.18초 페이드가 30프레임에 안 닫힌다**(실측: 알파가 0으로 안 가고 0.856에 멈췄다).
##  = 「그물이 잰 것은 시야가 아니라 프레임 예산이었다」는 거짓 빨강이다.
## ⚠ **juice를 free하기 전에 불러라** — 복구 타이머의 람다가 juice를 캡처하고 있어서,
##  먼저 free하면 타이머가 죽은 객체를 만진다.
func _settle_time_scale() -> void:
	var t0 := Time.get_ticks_msec()
	while Engine.time_scale < 0.99 and Time.get_ticks_msec() - t0 < 3000:
		await process_frame


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
