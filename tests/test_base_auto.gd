extends SceneTree
## 베이스캠프(**진입 씬**) 자동 검증 — 헤드리스 실행:
##   ./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_base_auto.gd
## 전 항목 통과 시 "TEST_BASE_OK" 출력 후 종료 코드 0.
##
## 검증 대상 = **세션 24 발사 배선**: 베이스캠프에서 그린 마법진을 실제로 쏠 수 있나.
##
## 🔴 여기서 지키는 건 「물리 레이어 계약」이다. 캐리어 마스크는 5(world+enemy)인데 base.tscn의
## 플레이어·책상이 기본 레이어 1(world)에 있으면 **쏘는 순간 내 몸에 부딪혀 총구에서 죽는다** —
## 에러도 경고도 없이 그냥 "마법이 안 나간다". 헤드리스가 잡을 수 있는 종류의 버그라 여기 둔다.
## (반대로 **화면에 보이는지**는 못 잡는다 — z_index는 리드가 스샷으로 확인해야 한다.)
##
## 공개 계약으로만 검증한다 (CLAUDE.md): EventBus 시그널 · 그룹("enemies"/"player_projectiles") ·
## dummy_target.hits. 노드 경로·내부 필드는 리팩터 때 옮겨 다니는 물건이라 계약이 아니다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

const GLYPH_NONE := -1

## 사거리 = projectile_base_speed × projectile_lifetime_sec (data/balance.tres).
## 여기 베끼지 않고 balance에서 읽는다 — 수치를 바꾸면 이 테스트도 같이 따라와야 한다.
var _range_px: float = 0.0

var failures: int = 0
var _bus = null
var _base = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_BASE_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	var bal = load("res://data/balance.tres")
	_range_px = bal.projectile_base_speed * bal.projectile_lifetime_sec

	var scene := load("res://src/base/base.tscn") as PackedScene
	_base = scene.instantiate()
	root.add_child(_base)
	await process_frame

	await _test_scene_wired()
	await _test_targets_in_range()
	await _test_my_body_does_not_block_my_spell()
	await _test_desk_does_not_eat_the_spell()
	await _test_desk_still_sees_the_player()
	await _test_rejected_commit_is_not_silent()
	await _test_real_left_click_actually_fires()
	await _test_forest_gate_leads_out()

	if failures == 0:
		print("TEST_BASE_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_BASE_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 진입 씬에 연습장이 있다 — 과녁과 발사 시스템.
func _test_scene_wired() -> void:
	print("[1] 베이스캠프에 연습 과녁 + 발사 시스템이 있다")
	var targets := _targets()
	_check(targets.size() >= 3, "허수아비 3개 이상 (실제 %d)" % targets.size())
	_check(_player() != null, "플레이어(CharacterBody2D)를 찾았다")
	# 발사 시스템의 존재는 **행동으로** 확인한다 — 노드 이름이 아니라 "쏘면 진이 생기나".
	_bus.ring_cast_requested.emit(_assembly(1.0), Vector2(9000, 9000), Vector2(1, 0))
	await physics_frame
	_check(_carriers().size() == 1,
		"쏘니 진(캐리어)이 생긴다 = RingSpellSystem이 씬에 있다 (실제 %d)" % _carriers().size())
	_clear()


## [2] 🔴 과녁이 사거리 밖이면 연습장이 장식이다 — 걸어가기 전엔 한 발도 안 닿는다.
func _test_targets_in_range() -> void:
	print("[2] 연습 과녁이 플레이어 시작점 사거리(%.0fpx) 안에 있다" % _range_px)
	var from: Vector2 = _player().global_position
	for t in _targets():
		var d: float = from.distance_to(t.global_position)
		_check(d <= _range_px, "허수아비 %s — %.0fpx (사거리 %.0f)" % [t.name, d, _range_px])


## [3] 🔴 총구 자살 — 플레이어 자리에서 쏜 진이 **내 몸에 막히지 않고** 날아가 과녁을 때린다.
## 레이어를 되돌리면(Player → 기본 레이어 1) 여기서 잡힌다: 진이 스폰 즉시 죽어 영영 안 맞는다.
func _test_my_body_does_not_block_my_spell() -> void:
	print("[3] 내 몸이 내 마법을 막지 않는다 — 쏜 진이 허수아비에 닿는다")
	var player = _player()
	var target = _nearest_target(player.global_position)
	if target == null:
		_check(false, "과녁이 하나도 없다")
		return
	var aim: Vector2 = (target.global_position - player.global_position).normalized()
	_bus.ring_cast_requested.emit(_assembly(1.0), player.global_position, aim)
	var frames := 0
	while target.hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	_check(not target.hits.is_empty(),
		"허수아비 %s 피격 (%d 물리 프레임)" % [target.name, frames])
	_clear()


## [4] 🔴 책상 너머로 쏴도 진이 산다 — 책상(Area2D)이 world 레이어에 있으면 벽으로 읽혀 먹어 버린다.
func _test_desk_does_not_eat_the_spell() -> void:
	print("[4] 책상이 마법을 먹지 않는다 (책상 쪽으로 쏴도 진이 지나간다)")
	var player = _player()
	# 책상은 플레이어 위쪽에 있다 — 위로 쏘면 반드시 책상 영역을 지난다.
	_bus.ring_cast_requested.emit(_assembly(1.0), player.global_position, Vector2.UP)
	# 40 물리 프레임 ≈ 0.66초 ≈ 173px — 책상 한복판을 지나고도 남는 거리(수명 1.5초 안).
	for i in 40:
		await physics_frame
	_check(_carriers().size() == 1,
		"진이 책상을 통과해 살아 있다 (남은 %d)" % _carriers().size())
	_clear()


## [5] 🔴 레이어를 옮긴 대가를 확인한다 — 책상이 여전히 플레이어를 **감지**하나.
## 감지 못 하면 "[E] 탁본"이 안 뜨고 **책이 안 열린다** = 게임이 통째로 막힌다.
## 진을 살리려고 플레이어를 레이어 2로 옮겼으니 책상 마스크도 따라와야 했다 — 그 짝을 여기서 묶는다.
func _test_desk_still_sees_the_player() -> void:
	print("[5] 책상이 플레이어를 알아본다 (E 안내가 뜨려면 감지돼야 한다)")
	var desk = _zone(&"desk")
	if desk == null:
		_check(false, "책상(Area2D)을 못 찾았다")
		return
	var player = _player()
	var was: Vector2 = player.global_position
	player.global_position = desk.global_position   # 책상 위로 걸어간 셈
	# Area2D 겹침은 물리 프레임마다 갱신된다 — 한 프레임으로는 아직 비어 있다.
	var frames := 0
	while not desk.get_overlapping_bodies().has(player) and frames < 10:
		await physics_frame
		frames += 1
	_check(desk.get_overlapping_bodies().has(player),
		"책상이 플레이어를 감지 (%d 물리 프레임)" % frames)
	player.global_position = was


## 🔴 [6] 점수 미달로 안 맺히면 **이유가 화면에 뜬다** (세션 25).
## 사용자: *"맽기까지 했는데 안나감"* — 미달 도안은 책을 덮을 때 조용히 거부됐다.
## 거부는 옳다(안 그러면 [마력 주입]을 건너뛰는 우회로가 된다). 문제는 **침묵**이었다:
## 책은 덮이고 슬롯은 빈 채인데 이유가 어디에도 없어 "맺었는데 안 나간다"가 됐다.
func _test_rejected_commit_is_not_silent() -> void:
	print("[6] 미달 도안을 거부할 땐 이유를 말해 준다")
	_base.call(&"_open_drawing")
	await process_frame
	var forge = _base.get("_forge")
	if forge == null:
		_check(false, "책이 안 열렸다")
		return
	var board = forge.get_node("Stage/Spread/RingBoard")
	# 진·룬을 **미달로** 그린다 (조금만·벗어나게)
	for step in 2:
		if step == 0:
			board.call(&"choose_jin")
		else:
			board.call(&"choose_rune")
		board.call(&"begin_stroke")
		var g = board.call(&"guide_points")
		for i in range(0, int(g.size() * 0.4)):
			board.call(&"trace_stroke", g[i] + Vector2(6.0, 5.0))
		forge.call(&"_on_next")
	var sc := float((board.call(&"get_assembly") as Dictionary).get("score", 1.0))
	_check(sc <= 0.65, "미달 도안을 만들었다 (%.2f)" % sc)
	_check(bool(board.call(&"can_commit")), "진·룬은 있으니 can_commit은 참 — 그래서 조용히 거부됐었다")

	var rejected := []
	forge.commit_rejected.connect(func(s: float) -> void: rejected.append(s))
	var gs = root.get_node("/root/GameState")
	var before := (gs.ring_designs as Array).size()
	forge.call(&"close")
	await process_frame
	_check(rejected.size() == 1, "책을 덮으면 commit_rejected가 온다 (침묵 금지)")
	_check((gs.ring_designs as Array).size() == before, "미달 도안은 여전히 안 맺힌다 (거부는 옳다)")
	_base.call(&"_close_drawing")


## [7] 좌클릭이 발사까지 도달한다 (세션 25).
## 사용자: *"마법진이 다 그려져도 발사가 안됨"* → *"좌클릭이 안먹나?"* — 맞혔다.
## 버그: `Ground`가 화면을 다 덮는 ColorRect인데 **Control의 기본 mouse_filter는 STOP**이라
## 바닥이 좌클릭을 전부 먹었다 → `_unhandled_input`에 안 오고 → `_fire()`가 아예 안 불렸다.
## 에러도 경고도 없다. `base.tscn`의 `Ground.mouse_filter = 2`가 고친 것이다.
##
## 🔴🔴 **이 테스트는 그 버그를 못 잡는다 — 검출력이 0이다.** 그런데도 남겨 둔 이유는 아래 경고
## 때문이지, 이게 지켜 준다고 믿어서가 아니다. `mouse_filter`를 도로 빼고 돌려 봤더니 **그냥
## 통과했다**: 헤드리스엔 렌더가 없어 Control 히트 테스트가 실제와 다르다 —
## `push_input`을 써도 GUI 계층을 제대로 안 탄다. 반면 **에디터로 띄운 실제 게임에서는 같은
## 코드가 발사 0회 → (고친 뒤) 1회로 정확히 재현됐다.**
##
## ⚠ **그래서 마우스가 닿는 경로는 헤드리스로 검증할 수 없다.** memory `takbon-mcp-visual-verify`의
## "헤드리스는 존재만 알고 보인다는 모른다"와 같은 종류다 — **클릭이 닿는다도 모른다.**
## 바꿨으면 에디터로 띄워 `godot_exec`로 `viewport.push_input(InputEventMouseButton)`을 밀어 봐라.
##
## 🔴 왜 두 세션을 놓쳤나: 기존 검증이 전부 `_fire()`를 **직접 부르거나** `attack_basic` 액션을
## 주입해서 **Control 계층을 건너뛰었다**. 전 스위트가 그린인데 게임에선 아무것도 안 나갔다.
func _test_real_left_click_actually_fires() -> void:
	print("[7] 좌클릭이 발사에 닿는다 ⚠ 헤드리스에선 검출력 0 — 실제 게임에서 확인할 것")
	var gs = root.get_node("/root/GameState")
	gs.ring_equipped[0] = RingDesign.from_assembly(_assembly(1.0), "클릭 테스트")
	_player().caster.select_slot(0)

	var casts := []
	_bus.ring_cast_requested.connect(func(_a, _p, _d) -> void: casts.append(1))

	# 🔴 실제 마우스 이벤트를 **뷰포트에** 민다 — 게임 창에 클릭한 것과 같은 경로다
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(480, 270)          # 화면 한복판 = Ground 위
	_base.get_viewport().push_input(press)
	await process_frame
	await process_frame

	_check(casts.size() == 1,
		"🔴 좌클릭이 발사에 닿는다 (실제 발사 %d회 — 0이면 Control이 클릭을 먹고 있다)" % casts.size())


## [8] 🔴 숲으로 나가는 길이 있다 (세션 26 — F2).
## 씬 전환 자체는 여기서 안 시킨다 — 시키면 이 테스트가 딛고 선 `_base`가 통째로 날아간다.
## 대신 **나갈 수 있는 조건 셋**을 묶는다: 문이 있고 · 나를 감지하고(안 그러면 [E]가 안 뜬다) ·
## 갈 곳이 실재한다(경로가 깨지면 E를 눌러도 **아무 일도 안 일어난다** — 또 하나의 침묵).
func _test_forest_gate_leads_out() -> void:
	print("[8] 숲으로 나가는 길 — 문이 있고, 나를 알아보고, 갈 곳이 실재한다")
	var gate = _zone(&"forest_gate")
	if gate == null:
		_check(false, "숲길(zone_id=forest_gate)을 못 찾았다")
		return
	_check(gate.interacted.get_connections().size() >= 1,
		"숲길의 interacted를 베이스가 받고 있다 (안 이으면 E가 조용히 아무것도 안 한다)")

	var player = _player()
	var was: Vector2 = player.global_position
	player.global_position = gate.global_position
	var frames := 0
	while not gate.get_overlapping_bodies().has(player) and frames < 10:
		await physics_frame
		frames += 1
	_check(gate.player_in_range(), "숲길이 플레이어를 감지 = [E] 안내가 뜬다 (%d 물리 프레임)" % frames)
	player.global_position = was

	var forest = _base.get("forest_scene")
	_check(forest != null and forest.can_instantiate(),
		"갈 곳(forest_scene)이 실재한다 — 경로가 깨지면 E를 눌러도 아무 일도 안 난다")


# ── 헬퍼 ──

## 빈 진 8칸 + 점수. 전개 없이 몸으로만 때려 결과가 깔끔하다.
func _assembly(score: float) -> Dictionary:
	var r := []
	for k in 8:
		r.append(GLYPH_NONE)
	return {"rings": [r], "score": score}


func _targets() -> Array:
	var out := []
	for n in get_nodes_in_group("enemies"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


func _nearest_target(from: Vector2):
	var best = null
	var best_d := INF
	for t in _targets():
		var d: float = from.distance_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best


func _carriers() -> Array:
	var out := []
	for n in get_nodes_in_group("player_projectiles"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


## 씬을 뒤져 플레이어를 찾는다 — 노드 이름이 아니라 **타입**으로 (이름은 바뀔 수 있다).
func _player():
	return _find_body(_base)


func _find_body(node):
	if node is CharacterBody2D:
		return node
	for c in node.get_children():
		var found = _find_body(c)
		if found != null:
			return found
	return null


## 상호작용 지점을 **zone_id로** 찾는다 (interact_zone.gd의 공개 계약).
## ⚠ 예전엔 "씬에서 처음 나오는 Area2D = 책상"으로 찾았는데, 세션 26에 숲길이 생기면서
## 그 가정이 깨졌다 — 게다가 **날아다니는 진도 Area2D**라 순서에 기대는 건 애초에 위태로웠다.
func _zone(id: StringName):
	for z in get_nodes_in_group("interact_zones"):
		if z.zone_id == id:
			return z
	return null


func _clear() -> void:
	for n in _carriers():
		n.queue_free()
	for n in get_nodes_in_group("pillars"):
		n.queue_free()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
