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
	await _test_score_scales_damage(system)
	await _test_no_score_is_base_power(system)
	await _test_size_scales_damage(system)
	await _test_special_ink_amplifies_status(system)
	await _test_wand_pattern(system)

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
	system._deploy_now(_all(G_RADIATE), Vector2(5000, 5000), 0.0, 1.0, 1.0, 0)
	await process_frame
	_check(_bolts(system).size() == 8, "불탄환 8발 (실제 %d)" % _bolts(system).size())
	_check(_pillars().size() == 0, "기둥 0 (실제 %d)" % _pillars().size())


func _test_deploy_gather(system) -> void:
	print("[2] 응집 4칸 전개 → 기둥 1개, 불탄환 0")
	_clear(system)
	system._deploy_now(_ring({0: G_GATHER, 2: G_GATHER, 4: G_GATHER, 6: G_GATHER}),
		Vector2(5000, 5000), 0.0, 1.0, 1.0, 0)
	await process_frame
	_check(_pillars().size() == 1, "기둥 1개 (실제 %d)" % _pillars().size())
	_check(_bolts(system).size() == 0, "불탄환 0 (실제 %d)" % _bolts(system).size())


func _test_deploy_empty(system) -> void:
	print("[3] 빈 진 전개 → 아무것도 안 나온다")
	_clear(system)
	system._deploy_now(_all(GLYPH_NONE), Vector2(5000, 5000), 0.0, 1.0, 1.0, 0)
	await process_frame
	_check(_bolts(system).size() == 0 and _pillars().size() == 0,
		"불탄환·기둥 모두 0 (실제 탄 %d·기둥 %d)" % [_bolts(system).size(), _pillars().size()])


func _test_deploy_mixed(system) -> void:
	print("[4] 혼합(발산 2 + 응집 3) → 불탄환 2발 · 기둥 1개")
	_clear(system)
	system._deploy_now(_ring({1: G_RADIATE, 5: G_RADIATE, 0: G_GATHER, 2: G_GATHER, 4: G_GATHER}),
		Vector2(5000, 5000), 0.0, 1.0, 1.0, 0)
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

	# 🔴 세션 34: 룬 사슬 — assembly.rune(=물 2)가 발사까지 흐르는지. 세션 34 전엔 발사가
	# Db.get_rune(FIRE)를 하드코딩해 물을 그려도 불로 맞았다 (이 검증이 회귀 가드).
	var wet = _dummy_scene.instantiate()
	root.add_child(wet)
	wet.global_position = Vector2(140, 0)
	# 빈 진 — 진 몸이 때리는 rune_type만 본다 (전개 기둥이 지연 스폰돼 다음 테스트로 새지 않게)
	_bus.ring_cast_requested.emit(
		{"rings": [_all(GLYPH_NONE)], "rune": Enums.RuneType.WATER},
		Vector2.ZERO, Vector2(1, 0))
	var wframes := 0
	while wet.hits.is_empty() and wframes < 180:
		await physics_frame
		wframes += 1
	var got := int(wet.hits[0]["rune_type"]) if not wet.hits.is_empty() else -1
	_check(got == Enums.RuneType.WATER, "물 룬(rune=2)으로 그리면 물 룬으로 맞는다 (rune_type=%d)" % got)
	wet.queue_free()
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


# ── 🔴 손그림 점수 → 위력 (세션 23) ──
# 세션 22까지 점수는 계산·저장만 되고 **아무도 안 읽어** 잘 그리든 막 그리든 피해가 같았다.
# 여기가 그 계약을 못 박는다: assembly.score가 실제 take_hit 피해를 바꾼다.

## 빈 진을 쏴 **몸으로** 때린 피해를 잰다 (전개 없이 한 방만 들어와 값이 깔끔하다).
func _damage_with(system, assembly: Dictionary) -> float:
	_clear(system)
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(140, 0)
	_bus.ring_cast_requested.emit(assembly, Vector2.ZERO, Vector2(1, 0))
	var frames := 0
	while dummy.hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	var dmg := float(dummy.hits[0]["damage"]) if not dummy.hits.is_empty() else -1.0
	dummy.queue_free()
	_clear(system)
	return dmg


func _test_score_scales_damage(system) -> void:
	print("[8] 잘 그린 진이 더 세게 때린다 (score → 위력)")
	# 만점(1.0) vs 기준선을 겨우 넘긴 진(0.66) — 둘 다 견디는 점수라 발사까지 온다
	var hi := await _damage_with(system, {"rings": [_all(GLYPH_NONE)], "score": 1.0})
	var lo := await _damage_with(system, {"rings": [_all(GLYPH_NONE)], "score": 0.66})
	_check(hi > 0.0 and lo > 0.0, "두 진 다 명중 (만점 %.2f · 겨우 %.2f)" % [hi, lo])
	_check(hi > lo, "만점 진이 더 아프다 (%.2f > %.2f)" % [hi, lo])
	# 🔴 배율 그대로인지 — balance(0.7~1.6)에서 만점/기준선 ≈ 2.29배.
	# "더 아프다"만 보면 1% 차이도 통과한다. 차이가 **의미 있는 크기**여야 축이 산다.
	_check(hi / lo > 2.0, "차이가 의미 있는 크기다 (%.2f배 — 기대 ≈2.3)" % (hi / lo))


func _test_no_score_is_base_power(system) -> void:
	print("[9] 점수 없는 assembly는 기준 위력 — 옛 저장·호출자가 0 피해로 죽지 않는다")
	var d := await _damage_with(system, {"rings": [_all(GLYPH_NONE)]})
	_check(d > 0.0, "점수 없이도 때린다 (%.2f)" % d)


## 진 몸으로 한 방 때린 **hit 전체**를 잰다 (damage + status_power 둘 다 본다).
func _hit_with(system, assembly: Dictionary) -> Dictionary:
	_clear(system)
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(140, 0)
	_bus.ring_cast_requested.emit(assembly, Vector2.ZERO, Vector2(1, 0))
	var frames := 0
	while dummy.hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	var hit: Dictionary = (dummy.hits[0] as Dictionary).duplicate() if not dummy.hits.is_empty() else {}
	dummy.queue_free()
	_clear(system)
	return hit


## 🔴 종이 = 규모 (세션29) — assembly.size가 실제 take_hit 피해를 키운다 (spell이 size를 읽어 태운다).
func _test_size_scales_damage(system) -> void:
	print("[10] 큰 진이 더 세게 때린다 (종이=규모 → size → 피해)")
	var big := await _hit_with(system, {"rings": [_all(GLYPH_NONE)], "score": 0.9, "size": 2.0})
	var small := await _hit_with(system, {"rings": [_all(GLYPH_NONE)], "score": 0.9, "size": 1.0})
	var bd := float(big.get("damage", -1.0))
	var sd := float(small.get("damage", -1.0))
	_check(bd > 0.0 and sd > 0.0, "두 진 다 명중 (큰 %.2f · 작은 %.2f)" % [bd, sd])
	_check(bd > sd, "큰 진이 더 아프다 (%.2f > %.2f)" % [bd, sd])
	_check(bd / sd > 1.5, "차이가 의미 있는 크기 (%.2f배 — size 2.0, 지수 1.0이면 ≈2.0)" % (bd / sd))


## 🔴 특별잉크 = 화상 증폭 (세션29) — assembly.special_ink/ratio가 status_power를 키운다.
## 피해(power)는 안 건드린다: 특별잉크는 **상태 축**이고 등급잉크가 **피해 축**이다.
func _test_special_ink_amplifies_status(system) -> void:
	print("[11] 붉은 잉크로 그린 진 = 화상이 세다 (status_power 증폭, 피해는 그대로)")
	var red := await _hit_with(system, {"rings": [_all(GLYPH_NONE)], "score": 0.9,
		"special_ink": &"ink_fire_red", "special_ratio": 1.0})
	var plain := await _hit_with(system, {"rings": [_all(GLYPH_NONE)], "score": 0.9})
	var rp := float(red.get("status_power", -1.0))
	var pp := float(plain.get("status_power", -1.0))
	_check(rp > 0.0 and pp > 0.0, "두 진 다 화상 있음 (붉은 %.2f · 기본 %.2f)" % [rp, pp])
	_check(rp > pp, "붉은 잉크 진이 화상이 세다 (%.2f > %.2f)" % [rp, pp])
	_check(is_equal_approx(float(red.get("damage", 0.0)), float(plain.get("damage", 0.0))),
		"특별잉크는 피해를 안 바꾼다 (상태 축만 — 붉은 %.2f = 기본 %.2f)"
		% [float(red.get("damage", 0.0)), float(plain.get("damage", 0.0))])


# ── 🔴 지팡이 발사 패턴 (세션42) — 옛 spell_system 매장 후 wand_pattern()이 orphan이라
# 진이 무조건 단발이었다. 이 검증이 그 회귀를 막는다: 착용 지팡이가 진(캐리어) 발수를 정한다.
# 카운트는 emit 직후 1프레임 — 캐리어는 빈 진·무표적이라 수명 동안 날아다녀 안 사라진다.

func _test_wand_pattern(system) -> void:
	print("[12] 지팡이 패턴 → 진(캐리어) 발수 (세션42, WandPattern)")
	var gs = root.get_node("/root/GameState")
	var saved: Dictionary = gs.equipment.duplicate()

	# 미착용 = 단발 1개
	gs.equipment = {}
	_clear(system)
	_bus.ring_cast_requested.emit({"rings": [_all(GLYPH_NONE)]}, Vector2.ZERO, Vector2(1, 0))
	await process_frame
	_check(_carriers(system).size() == 1, "미착용=단발 진 1개 (실제 %d)" % _carriers(system).size())
	_clear(system)

	# 산탄 지팡이(wand_fork, wand_pattern=1) = balance.wand_multi_count 발
	gs.equipment = {int(Enums.ItemKind.WAND): &"wand_fork"}
	_bus.ring_cast_requested.emit({"rings": [_all(GLYPH_NONE)]}, Vector2.ZERO, Vector2(1, 0))
	await process_frame
	var mc := int(gs.balance.wand_multi_count)
	_check(_carriers(system).size() == mc, "산탄 지팡이=%d발 (실제 %d)" % [mc, _carriers(system).size()])
	_clear(system)

	# 전방위 지팡이(wand_ring, wand_pattern=2) = balance.wand_nova_count 발
	gs.equipment = {int(Enums.ItemKind.WAND): &"wand_ring"}
	_bus.ring_cast_requested.emit({"rings": [_all(GLYPH_NONE)]}, Vector2.ZERO, Vector2(1, 0))
	await process_frame
	var nc := int(gs.balance.wand_nova_count)
	_check(_carriers(system).size() == nc, "전방위 지팡이=%d발 (실제 %d)" % [nc, _carriers(system).size()])
	_clear(system)

	gs.equipment = saved


# ── 헬퍼 ──

## 진(캐리어) = ring_carrier.gd 인스턴스 (탄=projectile.gd과 파일명으로 구분).
func _carriers(system) -> Array:
	var out := []
	for c in system.get_children():
		var s = c.get_script()
		if s != null and (s.resource_path as String).ends_with("ring_carrier.gd"):
			out.append(c)
	return out


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
