extends SceneTree
## 마법 발사 연출 배선 자동 검증 (세션59 — 속성형 볼·트레일·머즐·착탄) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_spell_vfx_auto.gd
## 전 항목 통과 시 "TEST_SPELL_VFX_OK" 출력 후 종료 코드 0.
##
## [1] vfx가 ring_cast_requested·spell_impact에 연결돼 있다 — 배선 침묵사 그물(핸들러 오타로
##     조용히 안 붙는 것). test_audio_auto의 [연결만 확인] 패턴.
## [2] 캐리어 setup → 트레일이 **형제** Line2D로 스폰 + 🔴 player_projectiles 그룹 무가입
##     (테스트 4곳이 이 그룹으로 탄 수를 센다 — 섞이면 탄 수가 거짓으로 는다, 설계 §6)
## [3] 트리 밖 setup — 트레일 생략, 스크립트 에러 없이 통과 (null 가드 — 리드 grep이 최종 확인)
## [4] 빈 진 착탄 → spell_impact **정확히 1** — 캐리어 _hit_enemy emit 전용 그물 (빈 진은 탄이
##     안 나가므로 탄 emit이 캐리어 emit 부재를 못 가린다 — 뮤테이션에서 실제로 가렸다)
## [5] 발산 진 착탄 → spell_impact ≥ 2 (캐리어 1 + 전개 탄 _deal_damage ≥ 1) — 탄 emit 그물
##
## 🔴 렌더(코어 색·펄스·자전·트레일 모양·플래시)는 헤드리스가 못 본다 — 실게임 MCP가 별도 확인.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일되므로 오토로드 식별자·모듈 preload 금지 —
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

const G_RADIATE := 1
const GLYPH_NONE := -1

var failures: int = 0
var _bus = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_SPELL_VFX_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")

	await _test_vfx_connected()
	await _test_trail_spawn_and_group()
	await _test_trail_offtree_setup()
	await _test_impact_carrier_only()
	await _test_impact_signal()

	if failures == 0:
		print("TEST_SPELL_VFX_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_SPELL_VFX_FAIL — %d개 실패" % failures)
		quit(1)


func _test_vfx_connected() -> void:
	print("[1] vfx가 ring_cast_requested(머즐)·spell_impact(착탄)에 연결돼 있다")
	var vfx = (load("res://src/actors/vfx.gd") as GDScript).new()
	root.add_child(vfx)
	await process_frame
	_check(_connected_to(_bus.ring_cast_requested, vfx), "ring_cast_requested 연결 (머즐 플래시)")
	_check(_connected_to(_bus.spell_impact, vfx), "spell_impact 연결 (착탄 버스트)")
	vfx.queue_free()
	await process_frame


func _test_trail_spawn_and_group() -> void:
	print("[2] 캐리어 트레일 — 형제 Line2D 스폰 + player_projectiles 그룹 무가입")
	var host := Node2D.new()
	root.add_child(host)
	var carrier = (load("res://src/spell/ring_carrier.tscn") as PackedScene).instantiate()
	host.add_child(carrier)
	carrier.setup(_all(GLYPH_NONE), 0.0, 100.0, 5.0, 1.0, 0, 0, 0.0)
	await process_frame  # call_deferred 트레일 스폰
	await process_frame  # 트레일 _process 1틱 (포인트 적재)
	var trails := []
	for c in host.get_children():
		if c != carrier and c is Line2D:
			trails.append(c)
	_check(trails.size() == 1, "트레일 1개가 형제로 스폰 (실제 %d)" % trails.size())
	var polluted := false
	for t in trails:
		if t.is_in_group("player_projectiles"):
			polluted = true
	_check(not polluted, "🔴 트레일은 player_projectiles 그룹에 없다 (탄 수 오염 방지)")
	host.queue_free()
	await process_frame


func _test_trail_offtree_setup() -> void:
	print("[3] 트리 밖 setup — 트레일 스폰 생략·에러 없음 (null 가드)")
	var carrier = (load("res://src/spell/ring_carrier.tscn") as PackedScene).instantiate()
	carrier.setup(_all(GLYPH_NONE), 0.0, 100.0, 1.0, 1.0, 0, 0, 0.0)
	await process_frame  # 지연 스폰 시도 시점을 지나본다 — 가드가 없으면 여기서 스크립트 에러
	_check(true, "스크립트 에러 없이 통과 (리드 grep이 최종 확인)")
	carrier.free()


func _test_impact_carrier_only() -> void:
	print("[4] 빈 진 착탄 → spell_impact 정확히 1 (캐리어 emit 전용 그물)")
	var system = (load("res://src/spell/ring_spell_system.tscn") as PackedScene).instantiate()
	root.add_child(system)
	await process_frame
	var dummy = (load("res://src/spell/dummy_target.tscn") as PackedScene).instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(140, 0)
	var hits: Array = []
	var on_impact := func(_pos: Vector2, _rune_type: int) -> void:
		hits.append(true)
	_bus.spell_impact.connect(on_impact)
	# 빈 진 — 몸으로만 때린다(전개 0) → emit이 있다면 오직 캐리어 _hit_enemy 한 곳
	_bus.ring_cast_requested.emit({"rings": [_all(GLYPH_NONE)]}, Vector2.ZERO, Vector2(1, 0))
	var frames := 0
	while hits.is_empty() and frames < 240:
		await physics_frame
		frames += 1
	for i in 10:
		await physics_frame   # 초과 발신이 없나 몇 프레임 더 본다
	_check(hits.size() == 1, "빈 진 착탄 = spell_impact 정확히 1회 (실제 %d)" % hits.size())
	_bus.spell_impact.disconnect(on_impact)
	dummy.queue_free()
	system.queue_free()
	await process_frame


func _test_impact_signal() -> void:
	print("[5] 발산 진 착탄 → spell_impact ≥ 2 (캐리어 + 전개 탄)")
	var system = (load("res://src/spell/ring_spell_system.tscn") as PackedScene).instantiate()
	root.add_child(system)
	await process_frame
	var dummy = (load("res://src/spell/dummy_target.tscn") as PackedScene).instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(140, 0)
	var hits: Array = []
	var on_impact := func(pos: Vector2, rune_type: int) -> void:
		hits.append({"pos": pos, "rune": rune_type})
	_bus.spell_impact.connect(on_impact)
	# 발산 8칸 — 캐리어가 허수아비에 박히고(1회), 전개 탄이 그 자리서 퍼져 같은 허수아비를 또 때린다
	_bus.ring_cast_requested.emit({"rings": [_all(G_RADIATE)]}, Vector2.ZERO, Vector2(1, 0))
	var frames := 0
	while hits.size() < 2 and frames < 240:
		await physics_frame
		frames += 1
	_check(hits.size() >= 1, "캐리어 착탄 emit (수신 %d, %d 물리 프레임)" % [hits.size(), frames])
	_check(hits.size() >= 2, "전개 탄 착탄 emit (수신 %d)" % hits.size())
	if hits.size() > 0:
		_check(int(hits[0]["rune"]) == 0, "rune_type이 실려 온다 (불=0, 실제 %d)" % int(hits[0]["rune"]))
	_bus.spell_impact.disconnect(on_impact)
	dummy.queue_free()
	system.queue_free()
	await process_frame


func _connected_to(sig: Signal, obj: Object) -> bool:
	for c: Dictionary in sig.get_connections():
		if (c["callable"] as Callable).get_object() == obj:
			return true
	return false


func _all(g: int) -> Array:
	var r := []
	for k in 8:
		r.append(g)
	return r


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
