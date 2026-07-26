extends SceneTree
## 적 AI 다양화 자동 검증 (세션 47 — params.ai 분기) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_enemy_ai_auto.gd
## 전 항목 통과 시 "TEST_ENEMY_AI_OK" 출력 후 종료 코드 0.
##
## 🔴 여기서 지키는 건 헤드리스가 **실제로 잡을 수 있는** 것들이다:
##   • 방어(armor_reduction) — take_hit의 최종 피해가 준다 (enemy_hit이 경감까지 반영)
##   • 재생(regen_per_sec) — HP가 시간이 지나면 늘고 상한(_def.hp)을 안 넘는다
##   • 분산 경감(dispersed_resist) — 분산 상태일 때 받는 피해가 준다 (시간 토글)
## ⚠ 반대로 **못 잡는 것**: 돌진·부유 움직임의 "느낌"(윈드업 텔레그래프가 피할 만한가, 부유 거리가
## 답답한가). 그건 리드가 실게임 runtime_state·스샷으로 본다 — 헤드리스는 렌더·손맛을 못 잰다.
##
## 🔴 **공개 API로만** 검증한다 (takbon-verify §3): `hp()`·`take_hit`·`enemy_id`·EventBus.enemy_hit.
## 내부 상태 필드(_hp·_dispersed·_charge_state)는 리팩터 때 옮겨 다녀 계약이 아니다 — 안 더듬는다.
##
## 🔴 각 수치는 **되돌리면 빨개지게**(뮤테이션 검출력) 정확한 값을 짚는다 — <100 같은 느슨한
## 판정은 옛 관대한 코드도 통과해 검출력이 0이 된다 (takbon-verify §4, 세션23 실측).
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

var failures: int = 0
var _bus = null
var _db = null
var _enemy_scene = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("TEST_ENEMY_AI_TIMEOUT — 60초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_db = root.get_node("/root/Db")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene

	# 🔴 gale 연사가 `get_tree().current_scene`에 탄을 심는다 — 헤드리스엔 메인 씬이 없어 null이라
	# 컨테이너를 세운다([5]가 탄을 세려면 필요하다. test_gale_boss_auto·test_chest_auto 선례).
	var container := Node2D.new()
	root.add_child(container)
	current_scene = container

	await _test_armor_reduces_damage()
	await _test_regen_heals_and_caps()
	await _test_dispersed_reduces_damage()
	await _test_leash_stops_far_pursuit()
	await _test_leash_keeps_boss_machinery()

	if failures == 0:
		print("TEST_ENEMY_AI_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_ENEMY_AI_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 방어 — 갑충(armor_reduction 0.7)은 받는 피해가 30%로 준다. counter_rune(2)이 아닌
## 룬으로 때려 약점 배율을 배제한다 → dealt = 100 * (1-0.7) = 30. 계약: enemy_hit이 이 경감까지
## 반영한 최종 피해로 온다. 뮤테이션(armor 곱 제거) → dealt=100 → 이 줄이 빨개진다.
func _test_armor_reduces_damage() -> void:
	print("[1] 갑충 방어 — take_hit 최종 피해가 armor_reduction만큼 준다")
	var e = await _spawn(&"beetle")
	var dealt := _hit_and_capture(e, 100.0, 0)  # 룬 0 = FIRE, 갑충 약점은 2라 배율 없음
	_check(dealt < 100.0, "방어가 피해를 줄인다 (실제 %.1f < 100)" % dealt)
	_check(is_equal_approx(dealt, 30.0), "정확히 100*(1-0.7)=30이 든다 (실제 %.1f)" % dealt)
	e.free()


## [2] 🔴 재생 — 덩굴(regen_per_sec 2.5, hp 40)은 깎여도 시간이 지나면 HP가 늘고, 상한(40)을
## 안 넘는다. 공개 리더 hp()로만 본다. 뮤테이션(regen 제거) → hp가 안 늘어 첫 줄이 빨개진다.
func _test_regen_heals_and_caps() -> void:
	print("[2] 덩굴 재생 — HP가 시간이 지나면 늘고 상한을 안 넘는다")
	var e = await _spawn(&"vine")
	var maxhp: float = _db.get_enemy(&"vine").hp
	# 룬 5 = 덩굴 counter(기본 0)가 아니라 약점 배율 없음 → 8 그대로 깎인다(상한 근처에서 출발해
	# 짧은 대기로 상한 도달을 볼 수 있게 — 10으로 깎으면 720프레임을 기다려야 40에 닿는다).
	e.take_hit(8.0, 5, 0, 0.0)
	await physics_frame
	var h0: float = e.hp()
	_check(h0 < maxhp - 5.0, "맞아서 HP가 깎였다 (%.1f < %.0f)" % [h0, maxhp])
	# 20 물리 프레임(~0.33s) → regen 2.5/s면 약 +0.8. 늘어야 한다.
	for i in 20:
		await physics_frame
	_check(e.hp() > h0, "재생으로 HP가 늘었다 (%.1f → %.1f)" % [h0, e.hp()])
	# 오래 두면 상한(40)에서 멈춘다 — 넘지 않는다 (8을 채우는 데 ~192프레임 → 260이면 충분·상한 도달).
	for i in 260:
		await physics_frame
	_check(e.hp() <= maxhp + 0.01, "상한을 넘지 않는다 (실제 %.2f ≤ %.0f)" % [e.hp(), maxhp])
	_check(is_equal_approx(e.hp(), maxhp), "충분히 두면 만HP까지 찬다 (실제 %.2f)" % e.hp())
	e.free()


## [3] 🔴 분산 경감 — 안개(disperse_period 2.5, dispersed_resist 0.35)는 분산 상태일 때 받는
## 피해가 준다. 상태는 시간 토글이라 **분산 전/후 같은 피해로 두 번 때려** 뒤가 더 적음을 본다
## (정확 값이 아니라 "토글이 피해를 바꿨나"를 봐서 타이밍 흔들림에 강하게). 작은 피해로 때려 안 죽인다.
## 🔴 hover는 _physics_process의 player-null 반환 뒤에 돌아 disperse 타이머를 깎는다 — 그룹
## "player"에 스텁을 멀리 둬 타이머가 흐르게 한다(접촉 사거리 밖이라 피해 안 줌).
func _test_dispersed_reduces_damage() -> void:
	print("[3] 안개 분산 — 분산 중엔 받는 피해가 준다 (시간 토글)")
	var stub := Node2D.new()
	stub.add_to_group("player")
	stub.global_position = Vector2(5000, 0)  # 멀리 — 접촉 피해 없이 hover만 돌게
	root.add_child(stub)

	var e = await _spawn(&"mist")
	# 스폰 직후 = 아직 분산 전 (disperse_period 2.5s가 안 지났다). 룬 0은 안개 counter(3)가 아님.
	var normal := _hit_and_capture(e, 2.0, 0)
	# 분산 주기(2.5s ≈ 150 물리 프레임)를 넉넉히 넘겨 분산 상태로 만든다.
	for i in 175:
		await physics_frame
	var dispersed := _hit_and_capture(e, 2.0, 0)
	_check(dispersed < normal - 0.1,
		"분산 중 같은 공격이 덜 든다 (평시 %.2f → 분산 %.2f)" % [normal, dispersed])
	_check(is_equal_approx(normal, 2.0), "평시엔 경감 없이 그대로 든다 (실제 %.2f)" % normal)
	e.free()
	stub.free()


## [4] 🔴🔴 leash — `aggro_range` 밖이면 자기 자리를 지킨다 (세88 사냥 흐름 §2-A-2-b).
##
## 왜 생겼나: AI 6갈래 중 **거리 게이트가 있는 건 셋뿐**(chase·charge·stationary)이었다. hover(mist)·
## boss_gale·boss_snake는 거리와 무관하게 플레이어 쪽으로 왔다 — 방이 1200×1040이라 **안 드러났을
## 뿐이다**. 2400×2200 숲에선 mist가 전부 남쪽 입구로 모이고 **보스가 자기 자리를 버리고 내려와**
## 「깊이 들어간다」가 통째로 사라진다. 게이트를 넣기 전 이 계약을 재는 그물은 **0개**였다.
##
## 🔴 **ⓐ와 ⓑ를 둘 다 잰다.** ⓐ(멀면 안 온다)만 재면 **적이 아예 안 움직이는 버그도 통과한다** —
## 게이트를 `dist > 0`처럼 망가뜨려도 그린이 된다. ⓑ(가까우면 온다)가 그 구멍을 막는다.
## ⚠ 이동 **거리**로만 잰다(내부 상태·velocity를 안 더듬는다 — 리팩터 때 옮겨 다녀 계약이 아니다).
func _test_leash_stops_far_pursuit() -> void:
	print("[4] leash — aggro_range 밖에선 안 오고, 안에선 온다 (mist·gale·snake 3갈래)")
	# aggro 값은 각 .tres의 params에서 온다 — 여기 상수로 베끼면 .tres를 조일 때 갈라진다.
	for id: StringName in [&"mist", &"gale", &"snake_boss"]:
		var aggro: float = float(_db.get_enemy(id).params.get("aggro_range", 0.0))
		_check(aggro > 0.0, "%s: .tres에 aggro_range가 있다 (실제 %.0f)" % [id, aggro])
		var stub := Node2D.new()
		stub.add_to_group("player")
		root.add_child(stub)

		# ⓐ 밖 — 안 온다. aggro보다 400px 더 멀리 둬 경계 흔들림에 강하게.
		stub.global_position = Vector2(aggro + 400.0, 0.0)
		var far_e = await _spawn(id)
		far_e.global_position = Vector2.ZERO
		await physics_frame
		var p0: Vector2 = far_e.global_position
		for i in 30:
			await physics_frame
		var moved_far: float = far_e.global_position.distance_to(p0)
		_check(moved_far < 2.0,
			"%s: aggro %.0f 밖(%.0fpx)에선 자기 자리를 지킨다 (실제 %.1fpx 이동)" % [id, aggro, aggro + 400.0, moved_far])
		far_e.free()

		# ⓑ 안 — 온다. hover_max(95·170)보다 크게 둬야 「다가온다」 분기에 든다.
		stub.global_position = Vector2(aggro - 50.0, 0.0)
		var near_e = await _spawn(id)
		near_e.global_position = Vector2.ZERO
		await physics_frame
		var q0: Vector2 = near_e.global_position
		for i in 30:
			await physics_frame
		var moved_near: float = near_e.global_position.distance_to(q0)
		_check(moved_near > 10.0,
			"%s: aggro 안(%.0fpx)에선 다가온다 (실제 %.1fpx 이동)" % [id, aggro - 50.0, moved_near])
		near_e.free()
		stub.free()


## [5] 🔴🔴 leash 뒤에도 **gale의 쿨다운이 돈다** — 「이동 대입만 감싼다」 계약의 실제 검출자 (세88).
##
## 게이트를 `_ai_chase`의 관용구처럼 **`return`으로** 넣으면 조용한 고장이 난다: gale의
## `_gale_volley_cd`·`_gale_gust_cd` 감소는 **DRIFT 분기 안**에 있어서, 멀리 있는 동안 쿨다운이
## 얼어붙는다 → 플레이어가 사거리에 들어와도 **연사가 4.5초 늦게** 시작한다(에러·경고 0).
##
## 🔴 그래서 **한 번 쏜 뒤 멀어져 기다렸다가 다시 붙으면 즉시 쏴야 한다**는 형태로 잰다.
## ⚠ **페이즈2 전이는 이 계약의 검출자가 못 된다** — 전이 판정이 `match` **밖 첫 줄**이라
##   `return`에도 살아남는다. 「멀리서도 페이즈2가 열린다」는 **자명 통과**이므로 쓰지 않는다
##   (초안이 그렇게 짜여 있었다 — 그린인데 아무것도 안 재는 그물이었다).
## ⚠ mist·snake는 `return`이어도 실질 차이가 없다(mist는 분산 타이머가 hover 밖에 없고, snake의
##   러시 쿨다운은 `match` 밖에서 감소한다). 위험이 gale에 집중돼 있어 여기만 잰다.
func _test_leash_keeps_boss_machinery() -> void:
	print("[5] leash 뒤에도 gale 쿨다운이 돈다 — 멀리서 기다렸다 붙으면 즉시 연사")
	var aggro: float = float(_db.get_enemy(&"gale").params.get("aggro_range", 260.0))
	var near_pos := Vector2(aggro - 50.0, 0.0)
	var far_pos := Vector2(aggro + 400.0, 0.0)
	var stub := Node2D.new()
	stub.add_to_group("player")
	stub.global_position = near_pos
	root.add_child(stub)
	var boss = await _spawn(&"gale")
	boss.global_position = Vector2.ZERO

	# ① 가까이 — 첫 볼리(3발·interval 0.25)를 끝까지 뽑아 쿨을 volley_period(4.5)로 리셋시킨다.
	# ⚠ **프레임 수를 박지 않는다** — 첫 발까지 volley_period(≈270프레임)가 걸리고, 사용자가 그
	# 값을 조이면 상수는 바로 거짓 빨강이 된다. 「나올 때까지」로 기다린다.
	var fired := false
	for i in 400:
		await physics_frame
		if _projectile_count() > 0:
			fired = true
			break
	_check(fired, "① 가까이 있으면 연사가 나간다 (실제 %d발)" % _projectile_count())
	for i in 40:   # 남은 발(0.25s 간격 ×2) — 볼리를 다 뽑아 쿨이 리셋되게
		await physics_frame
	_free_projectiles()

	# ② 멀리 5.5초 — leash로 이동은 멈추지만 **쿨다운은 계속 돌아야 한다**(volley_period 4.5 초과).
	stub.global_position = far_pos
	for i in 330:
		await physics_frame
	_check(_projectile_count() == 0, "② aggro 밖에선 연사도 안 한다 (실제 %d발)" % _projectile_count())
	_free_projectiles()

	# ③ 다시 가까이 — 쿨이 멀리서 다 돌았으니 **거의 즉시** 발사돼야 한다(0.25초 안).
	stub.global_position = near_pos
	for i in 15:
		await physics_frame
	_check(_projectile_count() > 0,
		"③ 멀리서 기다린 만큼 쿨이 돌아 붙자마자 쏜다 (실제 %d발 — 0발이면 게이트를 return으로 넣어 쿨이 얼었다)"
		% _projectile_count())
	_free_projectiles()
	boss.free()
	stub.free()


# ── 헬퍼 ──

## 살아있는 적 투사체 수 — 그룹 이름은 `enemy_projectile`이 가입하는 그것과 같아야 한다.
func _projectile_count() -> int:
	return root.get_tree().get_nodes_in_group("enemy_projectiles").size()


## 단계 사이에 탄을 비운다 — 앞 단계의 잔탄이 다음 단계의 "쐈다"로 오독되지 않게.
func _free_projectiles() -> void:
	for p in root.get_tree().get_nodes_in_group("enemy_projectiles"):
		p.free()


## 적 하나를 스폰한다 — enemy_id는 **_ready 전에** 세워야 _def가 그 적으로 잡힌다(트리 진입 시 _ready).
func _spawn(id):
	var e = _enemy_scene.instantiate()
	e.enemy_id = id
	root.add_child(e)
	await process_frame
	await physics_frame
	return e


## take_hit을 한 번 쳐 enemy_hit으로 나온 최종 피해를 잡는다 (계약: 경감·약점 반영한 값).
func _hit_and_capture(e, damage: float, rune: int) -> float:
	var box := [0.0]
	var cb := func(who, dmg, _r) -> void:
		if who == e:
			box[0] = dmg
	_bus.enemy_hit.connect(cb)
	e.take_hit(damage, rune, 0, 0.0)
	_bus.enemy_hit.disconnect(cb)
	return box[0]


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
