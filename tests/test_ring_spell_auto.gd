extends SceneTree
## 고리 조립 발사 시스템 자동 검증 (모듈 B, 세션 12~) — 헤드리스 실행:
##   ./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_spell_auto.gd
## 전 항목 통과 시 "TEST_RING_SPELL_OK" 출력 후 종료 코드 0.
##
## 검증 대상: EventBus.ring_cast_requested → ring_carrier(진)가 조준 방향으로 날아가 적에 닿으면
##   전개 — 발산=불탄환(projectile.tscn), 응집=불기둥(pillar.tscn). 실제 적(take_hit)에 피해.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일되므로 오토로드 식별자·모듈 preload 금지 —
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

# 고리 칸 어휘 (RingBoard와 같은 값 — 여기 하드코딩해 모듈 preload를 피한다)
const G_GATHER := 0
const G_RADIATE := 1
const GLYPH_NONE := -1

var failures: int = 0
var _bus = null
var _dummy_scene: PackedScene = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_RING_SPELL_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_dummy_scene = load("res://src/spell/dummy_target.tscn") as PackedScene

	var system_scene := load("res://src/spell/ring_spell_system.tscn") as PackedScene
	var system = system_scene.instantiate()
	root.add_child(system)
	await process_frame

	await _test_deploy_radiate(system)
	await _test_deploy_gather(system)
	await _test_deploy_empty(system)
	await _test_deploy_mixed(system)
	await _test_carrier_flies_and_hits(system)
	await _test_empty_ring_hits_body(system)
	await _test_miss_no_deploy(system)

	if failures == 0:
		print("TEST_RING_SPELL_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_RING_SPELL_FAIL — %d개 실패" % failures)
		quit(1)


## 8칸 배열을 만든다 — glyphs에 준 칸만 채우고 나머지는 빈 칸(GLYPH_NONE).
func _ring(glyphs: Dictionary) -> Array:
	var r := []
	for k in 8:
		r.append(int(glyphs.get(k, GLYPH_NONE)))
	return r


func _all(g: int) -> Array:
	var r := []
	for k in 8:
		r.append(g)
	return r


# ── 전개 메커니즘 (충돌 타이밍과 분리 — 빈 곳에서 직접 _deploy_now 호출) ──

func _test_deploy_radiate(system) -> void:
	print("[1] 발산 8칸 전개 → 불탄환 8발, 기둥 0")
	_clear(system)
	# 아무도 없는 먼 곳에서 편다 — 탄이 즉시 뭔가에 닿아 사라지지 않게
	system._deploy_now(_all(G_RADIATE), Vector2(5000, 5000), 0.0)
	await process_frame
	_check(_bolts(system).size() == 8, "불탄환 8발 (실제 %d)" % _bolts(system).size())
	_check(_pillars().size() == 0, "기둥 0 (실제 %d)" % _pillars().size())


func _test_deploy_gather(system) -> void:
	print("[2] 응집 4칸 전개 → 기둥 1개, 불탄환 0")
	_clear(system)
	system._deploy_now(_ring({0: G_GATHER, 2: G_GATHER, 4: G_GATHER, 6: G_GATHER}),
		Vector2(5000, 5000), 0.0)
	await process_frame
	_check(_pillars().size() == 1, "기둥 1개 (실제 %d)" % _pillars().size())
	_check(_bolts(system).size() == 0, "불탄환 0 (실제 %d)" % _bolts(system).size())


func _test_deploy_empty(system) -> void:
	print("[3] 빈 진 전개 → 아무것도 안 나온다")
	_clear(system)
	system._deploy_now(_all(GLYPH_NONE), Vector2(5000, 5000), 0.0)
	await process_frame
	_check(_bolts(system).size() == 0 and _pillars().size() == 0,
		"불탄환·기둥 모두 0 (실제 탄 %d·기둥 %d)" % [_bolts(system).size(), _pillars().size()])


func _test_deploy_mixed(system) -> void:
	print("[4] 혼합(발산 2 + 응집 3) → 불탄환 2발 · 기둥 1개")
	_clear(system)
	system._deploy_now(_ring({1: G_RADIATE, 5: G_RADIATE, 0: G_GATHER, 2: G_GATHER, 4: G_GATHER}),
		Vector2(5000, 5000), 0.0)
	await process_frame
	_check(_bolts(system).size() == 2, "불탄환 2발 (실제 %d)" % _bolts(system).size())
	_check(_pillars().size() == 1, "기둥 1개 (실제 %d)" % _pillars().size())


# ── 캐리어(진) 비행 + 착탄 + 전개 (실제 적) ──

func _test_carrier_flies_and_hits(system) -> void:
	print("[5] 진이 날아가 허수아비에 닿으면 몸으로 때리고 응집 기둥을 세운다")
	_clear(system)
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(140, 0)
	# 응집만 — 착탄점에 기둥이 서고, 그 기둥이 허수아비를 계속 태운다
	_bus.ring_cast_requested.emit(
		{"rings": [_ring({0: G_GATHER, 4: G_GATHER})]}, Vector2.ZERO, Vector2(1, 0))
	var frames := 0
	while dummy.hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	_check(not dummy.hits.is_empty(), "허수아비 피격됨 (진 몸, %d 물리 프레임)" % frames)
	if not dummy.hits.is_empty():
		var hit: Dictionary = dummy.hits[0]
		_check(int(hit["rune_type"]) == 0, "불 룬(rune_type=0)으로 맞음")
	# 전개된 기둥이 섰는지 — 지연 스폰이라 몇 프레임 더 기다린다
	var pframes := 0
	while _pillars().is_empty() and pframes < 10:
		await physics_frame
		pframes += 1
	_check(not _pillars().is_empty(), "착탄점에 응집 기둥 전개됨")
	dummy.queue_free()
	_clear(system)


func _test_empty_ring_hits_body(system) -> void:
	print("[6] 빈 진도 날아가 몸으로 때린다 (전개는 없음)")
	_clear(system)
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(140, 0)
	_bus.ring_cast_requested.emit(
		{"rings": [_all(GLYPH_NONE)]}, Vector2.ZERO, Vector2(1, 0))
	var frames := 0
	while dummy.hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	_check(not dummy.hits.is_empty(), "빈 진 몸으로 허수아비 피격 (%d 프레임)" % frames)
	# 몇 프레임 더 — 전개가 잘못 일어나지 않는지 확인
	for i in 6:
		await physics_frame
	_check(_bolts(system).size() == 0 and _pillars().size() == 0,
		"빈 진은 전개 없음 (탄 %d·기둥 %d)" % [_bolts(system).size(), _pillars().size()])
	dummy.queue_free()
	_clear(system)


func _test_miss_no_deploy(system) -> void:
	print("[7] 못 맞으면 전개 없음 — 진이 수명대로 사라진다")
	_clear(system)
	# 적 없음 — 진이 날아가다 수명 끝나 조용히 사라져야 한다
	_bus.ring_cast_requested.emit(
		{"rings": [_all(G_RADIATE)]}, Vector2.ZERO, Vector2(1, 0))
	for i in 180:
		await physics_frame
		if not _pillars().is_empty() or _bolts(system).size() > 0:
			break
	_check(_bolts(system).size() == 0 and _pillars().size() == 0,
		"안 맞은 진은 전개 안 함 (탄 %d·기둥 %d)" % [_bolts(system).size(), _pillars().size()])
	# 캐리어도 사라졌는지 (수명 끝)
	var carriers := 0
	for c in system.get_children():
		if c.is_in_group("player_projectiles"):
			carriers += 1
	_check(carriers == 0, "진(캐리어)도 수명 끝나 사라짐 (남은 %d)" % carriers)
	_clear(system)


# ── 헬퍼 ──

func _bolts(system) -> Array:
	# 캐리어를 뺀 순수 탄 = projectile.gd 인스턴스 (파일명으로 구분)
	var out := []
	for c in system.get_children():
		if c.is_in_group("player_projectiles") and c.get_script() != null \
				and (c.get_script().resource_path as String).ends_with("projectile.gd"):
			out.append(c)
	return out


func _pillars() -> Array:
	var out := []
	for n in get_nodes_in_group("pillars"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


func _clear(system) -> void:
	for c in system.get_children():
		c.queue_free()
	for n in get_nodes_in_group("pillars"):
		n.queue_free()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
