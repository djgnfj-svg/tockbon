extends SceneTree
## 뱀 보스 자동 검증 — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_snake_boss_auto.gd
## 전 항목 통과 시 "TEST_SNAKE_BOSS_OK" 출력 후 종료 코드 0.
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##   • snake_boss.tres가 Db를 거쳐 실제 로드된다 (.tres 침묵 데이터 죽음 그물)
##   • 머리(forest_enemy) take_hit → hp 감소 · enemy_hit 발신 · 약점 배율
##   • hp 절반 페이즈 전이(공개 `phase()` 리더)
##   • SnakeBody 마디 수 == SEGMENT_COUNT · 머리를 옮기면 마디가 따라온다
##   • boss_snake AI: 플레이어 쪽으로 전진한다
## ⚠ 못 잡는 것: 세그먼트 **물결·러시 채찍의 "느낌"**·머리 회전이 눈에 보이는지 — 실게임 스샷.
##
## 공개 API로만 검증한다: hp()·phase()·has_status()·segment_count()·
## segment_global_position(). 내부 필드는 리팩터 때 옮겨 다니는 물건이라 계약이 아니다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

var failures: int = 0
var _bus = null
var _db = null
var _boss_scene = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_SNAKE_BOSS_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_db = root.get_node("/root/Db")
	_boss_scene = load("res://src/field/snake_boss.tscn") as PackedScene

	await _test_def_loads()
	await _test_scene_and_segments()
	await _test_take_hit_and_weakness()
	await _test_phase_transition()
	await _test_segments_follow_head()
	await _test_boss_chases_player()

	if failures == 0:
		print("TEST_SNAKE_BOSS_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_SNAKE_BOSS_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 snake_boss.tres가 Db를 거쳐 로드된다 ("파일 만들었다"≠완료).
func _test_def_loads() -> void:
	print("[1] snake_boss.tres 로드 (Db 경유)")
	var def = _db.get_enemy(&"snake_boss")
	_check(def != null, "Db.get_enemy(&\"snake_boss\")가 null이 아니다 (파서가 거부하면 조용히 스킵)")
	if def != null:
		_check(is_equal_approx(def.hp, 320.0), "hp = 320 (세58-B 챕터 하향, 실제 %.0f)" % def.hp)
		_check(str(def.params.get("ai", "")) == "boss_snake", "params.ai == boss_snake")
		# 🔴 `is_elite` 단정은 걷었다 — 소비자가 0곳이라 「스키마에 필드가 남아 있다」만 재는
		# 검출력 0짜리였다(hp·ai·drops가 실제 축이다).
		# drops가 기존 아이템 id인지 (엉뚱한 id가 아니라).
		var ok := true
		for d in def.drops:
			if _db.get_item(d.item_id) == null:
				ok = false
		_check(ok, "drops의 아이템 id가 전부 Db에 실재한다")


## [2] 씬 인스턴스 — hp 리더 · SnakeBody 마디 수 == SEGMENT_COUNT.
func _test_scene_and_segments() -> void:
	print("[2] 씬 인스턴스 · SnakeBody 마디 수")
	var boss = _make_boss(Vector2.ZERO)
	await physics_frame
	_check(is_equal_approx(boss.hp(), 320.0), "hp() == 320 (tres에서 왔다, 실제 %.0f)" % boss.hp())
	_check(boss.phase() == 1, "초기 페이즈 == 1")
	var body = boss.get_node("SnakeBody")
	_check(body != null, "SnakeBody 자식이 있다")
	if body != null:
		_check(body.segment_count() == body.SEGMENT_COUNT,
			"마디 수 %d == SEGMENT_COUNT %d" % [body.segment_count(), body.SEGMENT_COUNT])
		_check(body.segment_count() > 0, "마디가 실제로 스폰됐다 (%d)" % body.segment_count())
	_free(boss)


## [3] 🔴 take_hit → hp 감소 · enemy_hit(약점 배율 반영) 발신.
func _test_take_hit_and_weakness() -> void:
	print("[3] take_hit · enemy_hit · 약점 배율")
	var boss = _make_boss(Vector2(9000, 9000))  # 플레이어 없음 — 순수 피격만
	await physics_frame
	var hits := []
	var cb := func(who, dmg, _rune) -> void:
		if who == boss:
			hits.append(dmg)
	_bus.enemy_hit.connect(cb)

	# counter_rune = 6(GRASS), weakness_mult = 1.6 → dealt = 100 * 1.6 = 160.
	var before: float = boss.hp()
	boss.take_hit(100.0, 6, 0, 0.0)
	await process_frame
	_check(boss.hp() < before, "hp가 깎였다 (%.0f → %.0f)" % [before, boss.hp()])
	_check(hits.size() == 1, "enemy_hit이 한 번 왔다 (실제 %d)" % hits.size())
	if hits.size() == 1:
		_check(is_equal_approx(hits[0], 160.0),
			"약점 배율 반영: dealt == 160 (100×1.6, 실제 %.1f)" % hits[0])

	# 비약점 룬은 배율 없음 — dealt == 원값.
	hits.clear()
	boss.take_hit(50.0, 0, 0, 0.0)  # FIRE(0) != counter 6
	await process_frame
	_check(hits.size() == 1 and is_equal_approx(hits[0], 50.0),
		"비약점 룬은 배율 없음 (dealt == 50, 실제 %s)" % str(hits))
	_bus.enemy_hit.disconnect(cb)
	_free(boss)


## [4] 🔴 hp 절반 페이즈 전이 — hp를 임계 밑으로 깎고 boss 틱을 돌리면 phase()==2.
## 페이즈 체크는 boss AI 틱 안에 있으므로 플레이어를 두어 boss가 틱하게 한다.
func _test_phase_transition() -> void:
	print("[4] hp 절반 페이즈 전이")
	var boss = _make_boss(Vector2.ZERO)
	var player = _make_player(Vector2(120, 0))  # aggro 안 → boss가 틱한다
	await physics_frame
	_check(boss.phase() == 1, "전이 전 페이즈 == 1")
	# 비약점 170 → hp 320→150 (< 임계 160, 하지만 살아 있음).
	boss.take_hit(170.0, 0, 0, 0.0)
	for i in 5:
		await physics_frame
	_check(boss.hp() > 0.0, "아직 살아 있다 (%.0f)" % boss.hp())
	_check(boss.phase() == 2, "hp 절반 아래 → 페이즈 2로 전이했다 (실제 %d)" % boss.phase())
	_free(player)
	_free(boss)


## [5] 🔴 SnakeBody 추종 — 머리를 옮기면 마디가 따라온다(위치가 초기와 달라진다).
## 플레이어를 두지 않아 boss는 제자리(velocity 0) — 머리를 **수동으로** 옮겨 순수 추종만 본다.
func _test_segments_follow_head() -> void:
	print("[5] SnakeBody가 머리를 따라 이동한다")
	var boss = _make_boss(Vector2.ZERO)
	await physics_frame
	var body = boss.get_node("SnakeBody")
	var last: int = body.SEGMENT_COUNT - 1
	var tail_start: Vector2 = body.segment_global_position(last)
	# 🔴 머리 이동거리를 **몸통 길이에 맞춰 동적으로** 잡는다 (마디 수·간격 튜닝에 견고하게 —
	# 고정 320px로 두면 몸통이 길어질 때 꼬리가 이동창 밖이라 조용히 예민해진다).
	var body_len: float = float(body.SEGMENT_COUNT) * body.SEGMENT_SPACING
	var steps: int = int(ceil((body_len * 1.5 + 80.0) / 8.0))
	for i in steps:
		boss.global_position += Vector2(8, 0)
		await physics_frame
	var tail_end: Vector2 = body.segment_global_position(last)
	var head: Vector2 = boss.global_position
	_check(tail_end.distance_to(tail_start) > 50.0,
		"꼬리 마디가 초기 위치에서 움직였다 (이동 %.0f px)" % tail_end.distance_to(tail_start))
	_check(tail_end.x < head.x - 80.0,
		"꼬리가 머리 뒤로 늘어선다 (꼬리 x %.0f < 머리 x %.0f)" % [tail_end.x, head.x])
	_free(boss)


## [6] 🔴 boss_snake AI — 플레이어 쪽으로 전진한다(그룹 "player"가 유일 조준 경로).
## 플레이어를 **rush_range(240) 밖 · aggro_range(320) 안**에 둬 WEAVE로 다가오게 한다
## (러시 윈드업에 안 갇히고, leash에도 안 걸리는 좁은 띠다).
##
## 🔴 aggro 밖이면 보스는 **자기 자리를 지킨다**(leash) — 그래서 이 검사는 「올 수 있는 거리에서
## 온다」를 재야 한다. aggro 밖 거리를 주면 「안 온다」가 정답이라 그물이 뒤집힌다.
## ⚠ 「멀면 안 온다」 쪽은 `test_enemy_ai_auto` [4]가 3갈래 전부 잰다 — 여기서 중복하지 않는다.
## ⚠ 거리를 **`.tres`에서 파생**한다 — 사용자가 aggro를 조여도 거짓 빨강이 안 나게.
func _test_boss_chases_player() -> void:
	print("[6] boss_snake가 플레이어 쪽으로 다가온다 (aggro 안)")
	var boss = _make_boss(Vector2.ZERO)
	# 🔴 이름 승계 — 폴백을 320으로 두면 데이터가 새 이름으로 갔을 때 **우연히 같은 값**을
	#  받아 그물이 빨개지지도 않는다(실측). 승계 순서대로 읽고 0이면 아래가 자명 통과다.
	var aggro: float = float(_db.get_enemy(&"snake_boss").params.get(
		"sight_range", _db.get_enemy(&"snake_boss").params.get("aggro_range", 0.0)))
	_check(aggro > 0.0, "snake_boss가 sight_range를 들고 있다 (실제 %.0f — 0이면 아래가 뜻을 잃는다)" % aggro)
	var player = _make_player(Vector2(aggro - 20.0, 0))  # rush_range 240 밖 · leash 안
	await physics_frame
	var before: float = boss.global_position.distance_to(player.global_position)
	for i in 40:
		await physics_frame
	var after: float = boss.global_position.distance_to(player.global_position)
	_check(after < before - 15.0, "거리 %.0f → %.0f (위브하며 다가왔다)" % [before, after])
	_free(player)
	_free(boss)


# ── 헬퍼 ──

func _make_boss(pos: Vector2):
	var boss = _boss_scene.instantiate()
	root.add_child(boss)
	boss.global_position = pos
	return boss


func _make_player(pos: Vector2) -> Node2D:
	var p := Node2D.new()
	p.add_to_group("player")
	root.add_child(p)
	p.global_position = pos
	return p


func _free(node) -> void:
	if node != null and is_instance_valid(node):
		node.free()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
