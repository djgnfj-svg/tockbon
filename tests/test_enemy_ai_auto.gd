extends SceneTree
## 적 AI 다양화 자동 검증 (세션 47 — params.ai 분기) — 헤드리스 실행:
##   ./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_enemy_ai_auto.gd
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
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_ENEMY_AI_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_db = root.get_node("/root/Db")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene

	await _test_armor_reduces_damage()
	await _test_regen_heals_and_caps()
	await _test_dispersed_reduces_damage()

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


# ── 헬퍼 ──

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
