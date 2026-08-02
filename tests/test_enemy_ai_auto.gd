extends SceneTree
## 적 AI 다양화 자동 검증 (params.ai 분기) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_enemy_ai_auto.gd
## 전 항목 통과 시 "TEST_ENEMY_AI_OK" 출력 후 종료 코드 0.
##
## 🔴 여기서 재는 건 헤드리스가 **실제로 잡을 수 있는** 것들이다 — 방어·재생·분산 경감.
## ⚠ **못 잡는 것**: 돌진·부유의 「느낌」. 헤드리스는 렌더·손맛을 못 잰다 — 실게임 확인이 대체되지 않는다.
## 🔴 **공개 API로만** 검증한다(`hp()`·`take_hit`·`enemy_id`·EventBus.enemy_hit) — 내부 상태 필드는 계약이 아니다.
## 🔴 수치는 **되돌리면 빨개지게** 정확한 값을 짚는다 — `<100` 같은 느슨한 판정은 검출력이 0이 된다.
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

## 🔴 **AI 갈래는 `Db`에 몸을 주입해 잰다** — 방어·재생·분산을 쥔 잡몹이 데이터에서 사라졌지만
##  기계는 `forest_enemy`에 살아 있다. 그물을 지우면 다음에 그 키를 쓰는 몹이 왔을 때 **말없이 죽어 있다.**
## 🔴 뮤테이션: armor 곱을 지우면 [1] · regen을 지우면 [2] · `dispersed_resist` 경감을 지우면 [3]이 빨개진다.
## ⚠ **반드시 되돌린다** — `Db.enemies`는 공유 레지스트리라 남기면 뒤 항목의 적 수가 는다.
## ⚠ [6]은 `Db`가 아니라 **폴더를 스캔**하므로 주입한 몸이 안 섞인다(= 실데이터의 박자만 잰다).
## ⚠ 시트는 살아 있는 PNG를 빌려 쓴다 — 여기서 재는 건 **행동**이지 그림이 아니다.
const PROBE_SPRITE := "res://assets/sprites/enemies/hound.png"

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
	await _test_dispersed_alpha_round_trip()
	await _test_leash_stops_far_pursuit()
	await _test_leash_keeps_boss_machinery()
	await _test_anim_fps_from_data()

	if failures == 0:
		print("TEST_ENEMY_AI_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_ENEMY_AI_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 방어 — `armor_reduction 0.7`이면 받는 피해가 30%로 준다. `has_counter = false`라
## 약점 배율이 안 섞인다 → dealt = 100 * (1-0.7) = 30. 계약: enemy_hit이 이 경감까지
## 반영한 최종 피해로 온다. 뮤테이션(armor 곱 제거) → dealt=100 → 이 줄이 빨개진다.
func _test_armor_reduces_damage() -> void:
	print("[1] 방어 — take_hit 최종 피해가 armor_reduction만큼 준다 (주입한 몸)")
	_inject(&"ai_probe_armor", 55.0, {"armor_reduction": 0.7, "aggro_range": 170.0, "move_speed": 40.0})
	var e = await _spawn(&"ai_probe_armor")
	var dealt := _hit_and_capture(e, 100.0, 0)  # 룬 0 = FIRE, has_counter=false라 배율 없음
	_check(dealt < 100.0, "방어가 피해를 줄인다 (실제 %.1f < 100)" % dealt)
	_check(is_equal_approx(dealt, 30.0), "정확히 100*(1-0.7)=30이 든다 (실제 %.1f)" % dealt)
	e.free()
	_drop(&"ai_probe_armor")


## [2] 🔴 재생 — `regen_per_sec 2.5`·hp 40이면 깎여도 시간이 지나면 HP가 늘고, 상한(40)을
## 안 넘는다. 공개 리더 hp()로만 본다. 뮤테이션(regen 제거) → hp가 안 늘어 첫 줄이 빨개진다.
func _test_regen_heals_and_caps() -> void:
	print("[2] 재생 — HP가 시간이 지나면 늘고 상한을 안 넘는다 (주입한 몸)")
	_inject(&"ai_probe_regen", 40.0, {"ai": "stationary", "regen_per_sec": 2.5, "move_speed": 0.0})
	var e = await _spawn(&"ai_probe_regen")
	var maxhp: float = _db.get_enemy(&"ai_probe_regen").hp
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
	_drop(&"ai_probe_regen")


## [3] 🔴 분산 경감 — `disperse_period 2.5`·`dispersed_resist 0.35`인 hover는 분산 상태일 때 받는
## 피해가 준다. 상태는 시간 토글이라 **분산 전/후 같은 피해로 두 번 때려** 뒤가 더 적음을 본다
## (정확 값이 아니라 "토글이 피해를 바꿨나"를 봐서 타이밍 흔들림에 강하게). 작은 피해로 때려 안 죽인다.
## 🔴 hover는 _physics_process의 player-null 반환 뒤에 돌아 disperse 타이머를 깎는다 — 그룹
## "player"에 스텁을 멀리 둬 타이머가 흐르게 한다(접촉 사거리 밖이라 피해 안 줌).
##  🔴 `HOVER_PROBE`는 [4]도 같이 쓴다 — hover 갈래를 쥔 실적이 0종이라 여기서만 산다.
func _test_dispersed_reduces_damage() -> void:
	print("[3] 분산 — 분산 중엔 받는 피해가 준다 (시간 토글, 주입한 hover 몸)")
	var stub := Node2D.new()
	stub.add_to_group("player")
	stub.global_position = Vector2(5000, 0)  # 멀리 — 접촉 피해 없이 hover만 돌게
	root.add_child(stub)

	_inject_hover()
	var e = await _spawn(HOVER_PROBE)
	# 스폰 직후 = 아직 분산 전 (disperse_period 2.5s가 안 지났다). has_counter=false라 약점 배율 없음.
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
	# ⚠ [4]가 같은 몸을 이어 쓴다 — 여기선 안 걷고 [4] 끝에서 걷는다.


## [3b] 🔴 **분산 = 반투명 — 알파가 왕복한다.** [3]은 분산을 **피해 경감**으로 재므로
##  반투명 표시가 통째로 죽어도 그린이다 — `modulate.a`를 재는 유일한 그물이 여기다.
## 🔴 왕복(1.0 → 0.4 → 1.0)까지 재는 이유: 한 방향만 재면 **분산이 켜진 뒤 영영 안 풀려도** 그린이다.
## ⚠ 되돌아온 값은 **정확히 1.0**이어야 한다 — `< 1.0`으로 물러나면 알파가 조금씩 새는 고장을 놓친다.
## ⚠ 0.4는 **연출값**이라 손으로 든 기대치다 — 값을 조이면 이 줄을 같이 고치되 느슨하게 바꾸지는 마라(검출력이 0이 된다).
const ALPHA_PROBE := &"ai_probe_alpha"
const DISPERSED_ALPHA_EXPECT := 0.4
## 주기를 짧게 준다 — [3]의 2.5초(150프레임)로 왕복까지 보려면 300프레임을 기다려야 한다.
const ALPHA_PROBE_PERIOD := 1.0

func _test_dispersed_alpha_round_trip() -> void:
	print("[3b] 🔴 분산 알파 왕복 — 1.0 → %.1f → 1.0 (modulate.a를 재는 유일한 그물)" % DISPERSED_ALPHA_EXPECT)
	# ⚠ 맨몸 Node2D 스텁이면 충분하다 — 알파 축은 **분산 하나**뿐이다.
	var stub := Node2D.new()
	stub.add_to_group("player")
	stub.global_position = Vector2(5000, 0)   # 멀리 — 접촉 피해 없이 hover 타이머만 돌게
	root.add_child(stub)

	_inject(ALPHA_PROBE, 20.0, {
		"ai": "hover",
		"aggro_range": 200.0,
		"attack_range": 30.0,
		"disperse_period": ALPHA_PROBE_PERIOD,
		"dispersed_resist": 0.35,
		"hover_max": 95.0,
		"hover_min": 55.0,
		"move_speed": 70.0,
	})
	var e = await _spawn(ALPHA_PROBE)
	var vis := e.get_node_or_null(^"Visual") as CanvasItem
	if vis == null:
		_check(false, "Visual 노드를 찾았다 (구조가 바뀌면 이 그물이 죽는다)")
		e.free()
		stub.free()
		_drop(ALPHA_PROBE)
		return

	# ① 스폰 직후 = 아직 분산 전 (`_disperse_timer`가 한 주기 채워져 있다 — `_ready`).
	_check(is_equal_approx(vis.modulate.a, 1.0),
		"① 평시 알파 = 1.0 (실제 %.3f)" % vis.modulate.a)

	# ② 한 주기(60프레임)를 넘긴다 → 분산. 15프레임 여유를 둬 경계에 안 걸린다.
	for i in 75:
		await physics_frame
	_check(is_equal_approx(vis.modulate.a, DISPERSED_ALPHA_EXPECT),
		"② 분산 중 알파 = %.1f (실제 %.3f — 1.0이면 반투명 표시가 통째로 죽은 것)"
			% [DISPERSED_ALPHA_EXPECT, vis.modulate.a])

	# ③ 또 한 주기 → 분산이 풀린다. **정확히 1.0으로** 돌아와야 한다.
	for i in 60:
		await physics_frame
	_check(is_equal_approx(vis.modulate.a, 1.0),
		"③ 분산이 풀리면 알파가 정확히 1.0으로 돌아온다 (실제 %.3f — 새면 곱셈이 어긋난 것)"
			% vis.modulate.a)

	# 🔴 rgb 축은 **한 톨도 안 달라진다** — 알파를 만지는 코드가 틴트를 덮으면 여기가 빨개진다
	#  (소유권 계약: rgb=틴트 · a=분산. `_refresh_alpha`가 `modulate` 통째로 대입하면 그 사고다).
	_check(Color(vis.modulate.r, vis.modulate.g, vis.modulate.b).is_equal_approx(Color.WHITE),
		"🔴 알파 축을 만져도 rgb(상태 틴트)는 흰색 그대로다 (실제 %s)" % vis.modulate)

	e.free()
	stub.free()
	_drop(ALPHA_PROBE)


## [4] 🔴🔴 leash — `aggro_range` 밖이면 자기 자리를 지킨다.
## 🔴 **ⓐ와 ⓑ를 둘 다 잰다.** ⓐ(멀면 안 온다)만 재면 **적이 아예 안 움직이는 버그도 통과한다** —
##  게이트를 `dist > 0`처럼 망가뜨려도 그린이 된다. ⓑ(가까우면 온다)가 그 구멍을 막는다.
## ⚠ 이동 **거리**로만 잰다 — 내부 상태·velocity는 리팩터 때 옮겨 다녀 계약이 아니다.
## ⚠ hover는 실적이 지워져 **주입한 몸으로** 잰다 — 재는 것은 「hover에 거리 게이트가 있나」이지
##  「안개가 있나」가 아니다. gale·snake는 실데이터 그대로다.
func _test_leash_stops_far_pursuit() -> void:
	print("[4] leash — aggro_range 밖에선 안 오고, 안에선 온다 (hover·gale·snake 3갈래)")
	_inject_hover()
	# aggro 값은 각 EnemyDef의 params에서 온다 — 여기 상수로 베끼면 데이터를 조일 때 갈라진다.
	for id: StringName in [HOVER_PROBE, &"gale", &"snake_boss"]:
		var aggro: float = _sight_of(_db.get_enemy(id))
		_check(aggro > 0.0, "%s: .tres에 sight_range(옛 aggro_range)가 있다 (실제 %.0f)" % [id, aggro])
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
	_drop(HOVER_PROBE)


## [5] 🔴🔴 leash 뒤에도 **gale의 쿨다운이 돈다** — 「이동 대입만 감싼다」 계약의 검출자.
## 게이트를 **`return`으로** 넣으면 조용한 고장이 난다: 쿨다운 감소가 DRIFT 분기 안에 있어
##  멀리 있는 동안 얼어붙고, 사거리에 들어와도 **연사가 늦게** 시작한다(에러·경고 0).
## 🔴 그래서 **한 번 쏜 뒤 멀어져 기다렸다가 다시 붙으면 즉시 쏴야 한다**는 형태로 잰다.
## ⚠ **페이즈2 전이는 검출자가 못 된다** — 전이 판정이 `match` 밖이라 `return`에도 살아남아 **자명 통과**다.
## ⚠ mist·snake는 `return`이어도 실질 차이가 없다 — 위험이 gale에 집중돼 있어 여기만 잰다.
func _test_leash_keeps_boss_machinery() -> void:
	print("[5] leash 뒤에도 gale 쿨다운이 돈다 — 멀리서 기다렸다 붙으면 즉시 연사")
	var aggro: float = _sight_of(_db.get_enemy(&"gale"))
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

## 🔴 hover 갈래 검사용 몸 — [3]과 [4]가 **같은 것**을 쓴다.
## `aggro_range`·`hover_min`·`hover_max`가 셋 다 있어야 [4]ⓑ가 「다가온다」 분기에 든다
## (스텁을 `aggro - 50`에 두므로 그 값이 `hover_max`보다 커야 한다 — 150 > 95).
const HOVER_PROBE := &"ai_probe_hover"

func _inject_hover() -> void:
	_inject(HOVER_PROBE, 20.0, {
		"ai": "hover",
		"aggro_range": 200.0,
		"attack_cooldown": 1.1,
		"attack_range": 30.0,
		"contact_damage": 5.0,
		"disperse_period": 2.5,
		"dispersed_resist": 0.35,
		"hover_max": 95.0,
		"hover_min": 55.0,
		"move_speed": 70.0,
	})


## 🔴 in-memory EnemyDef 주입 (레지스트리가 평범한 Dictionary다).
## `has_counter = false`로 세운다 — 약점 배율이 섞이면 [1][3]의 **정확 값 판정**이 흐려진다
##  (느슨한 판정으로 물러나면 뮤테이션 검출력이 0이 된다).
## ⚠ 같은 id로 두 번 부르면 덮어쓴다(멱등) — [3]과 [4]가 hover 몸을 이어 쓰는 자리.
func _inject(id: StringName, hp: float, params: Dictionary) -> void:
	var def = (load("res://src/core/schemas/enemy_def.gd") as GDScript).new()
	def.id = id
	def.hp = hp
	def.has_counter = false
	var p := {"sprite": PROBE_SPRITE}
	p.merge(params, true)
	def.params = p
	_db.enemies[id] = def


## 🔴 주입 제거 — 안 걷으면 뒤 항목·뒤 테스트의 적 수가 는다(공유 레지스트리).
func _drop(id: StringName) -> void:
	_db.enemies.erase(id)


## 살아있는 적 투사체 수 — 그룹 이름은 `enemy_projectile`이 가입하는 그것과 같아야 한다.
func _projectile_count() -> int:
	return root.get_tree().get_nodes_in_group("enemy_projectiles").size()


## 단계 사이에 탄을 비운다 — 앞 단계의 잔탄이 다음 단계의 "쐈다"로 오독되지 않게.
func _free_projectiles() -> void:
	for p in root.get_tree().get_nodes_in_group("enemy_projectiles"):
		p.free()


## [6] 🔴 **애니 박자가 데이터에서 온다** — fps를 하드코딩하면 전 종이 같은 속도로 움직인다.
## 🔴 **ⓐ가 심장이다: 「.tres에 값이 있다」가 아니라 「그 값이 SpriteFrames까지 도달한다」를 잰다** —
##   데이터만 넣고 코드가 안 읽으면 **죽은 손잡이**가 된다.
## ⚠ 값 자체는 **안 박는다** — 박자는 F5가 정한다. 여기서 재는 건 **배선**과 **성격이 갈렸다**는 사실뿐이다.
func _test_anim_fps_from_data() -> void:
	print("[6] 애니 박자 — .tres → SpriteFrames 배선 · 종별 차이")
	var seen := {}
	for f: String in DirAccess.get_files_at("res://data/enemies"):
		if not f.ends_with(".tres"):
			continue
		var id := StringName(f.get_basename())
		var def = _db.get_enemy(id)
		if def == null or not def.params.has("sprite"):
			continue
		var e = await _spawn(id)
		var vis := e.get_node_or_null(^"Visual") as AnimatedSprite2D
		var frames: SpriteFrames = vis.sprite_frames if vis != null else null
		if frames == null or not frames.has_animation(&"idle"):
			_check(false, "%s의 idle 애니가 구워졌다" % id)
			e.queue_free()
			continue
		var want: float = float(def.params.get("anim_fps", 6.0))
		var got: float = frames.get_animation_speed(&"idle")
		_check(is_equal_approx(got, want),
			"🔴 %s의 idle 박자가 .tres 값 그대로다 (데이터 %.1f / 화면 %.1f)" % [id, want, got])
		seen[id] = got
		e.queue_free()

	# ── 성격이 갈렸다 = 축이 살아 있다 (전부 같으면 데이터를 넣은 값어치가 0) ──
	# ⚠ 실적이 **정확히 다섯 종**이라 하한에 딱 걸쳐 있다 — 몹을 더 지우려면 이 줄을 같이 봐라.
	_check(seen.size() >= 5, "박자를 잰 적이 다섯 종 이상이다 (실제 %d — 적으면 아래가 자명 통과)" % seen.size())
	var vals: Array = seen.values()
	var lo: float = vals.min()
	var hi: float = vals.max()
	_check(hi - lo >= 4.0,
		"🔴 가장 느린 적과 빠른 적의 박자가 뚜렷이 갈린다 (%.1f ~ %.1f — 폭 %.1f ≥ 4.0)" % [lo, hi, hi - lo])
	var distinct := {}
	for v in vals:
		distinct[v] = true
	_check(distinct.size() >= 4,
		"🔴 서로 다른 박자가 넷 이상이다 = 종마다 성격이 있다 (실제 %d가지)" % distinct.size())


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


## 🔴 「보는 거리」의 정본 키는 `sight_range`이고, 없으면 `aggro_range`를 승계한다.
## 🔴 **읽는 자리를 여기 하나로 모은다** — 흩어져 있으면 데이터가 새 이름으로 옮겨간 날
##  **어떤 줄은 0을 받고 어떤 줄은 폴백값으로 조용히 통과**한다.
func _sight_of(def) -> float:
	if def == null:
		return 0.0
	return float(def.params.get("sight_range", def.params.get("aggro_range", 0.0)))


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
