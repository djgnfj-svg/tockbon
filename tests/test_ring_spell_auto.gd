extends SceneTree
## 고리 조립 발사 시스템 자동 검증 (모듈 B, 세션 12~) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_spell_auto.gd
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
## 세션47 어휘 배증 — Enums.GlyphCode 2~5 (여기 하드코딩해 모듈 preload를 피한다)
const G_PIERCE := 2
const G_HOMING := 3
const G_BOUNCE := 4
const G_THRUST := 5
## Enums.GlyphType — 탄 행동 효과 축 (BASIC=0, BOUNCE=1, HOMING=2, PIERCE=3, THRUST=4)
const GT_BOUNCE := 1
const GT_HOMING := 2
const GT_PIERCE := 3
const GT_THRUST := 4
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

	# 🔴 세61 콘텐츠 리셋: 진 .tres가 jin_single 하나로 줄었다. 발사 **기계**(pattern·motion 분기,
	# ring_spell_system._shot_plan / ring_carrier.set_motion)는 전부 남아 있으므로, 옛 진들이 덮던
	# 축을 **in-memory JinDef를 Db에 임시 등록**해 계속 잰다([19]의 __test_big_fork 선례).
	# 진을 되살리면 해당 축의 id를 실데이터로 되돌려도 된다. 끝나면 _remove_test_jins가 걷는다.
	var db_reg = root.get_node("/root/Db")
	_register_test_jins(db_reg)

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
	await _test_glyph_bolt_effects(system)
	await _test_jin_burst(system)
	await _test_jin_spray(system)
	await _test_jin_seek(system)
	await _test_jin_spiral(system)
	await _test_jin_boomerang(system)
	await _test_jin_body_scale(system)
	await _test_jin_legacy_patterns(system)

	_remove_test_jins(db_reg)
	if failures == 0:
		print("TEST_RING_SPELL_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_RING_SPELL_FAIL — %d개 실패" % failures)
		quit(1)


## 세61: 옛 진 7종이 덮던 발사 축을 재는 테스트 전용 JinDef들 — Db.jins는 평범한 Dictionary다.
## body_scale 1.2(옛 jin_spiral 값)는 [19]②의 몸집 비교가 그대로 쓴다.
const TEST_JINS := {
	&"__t_fork": {"pattern": Enums.WandPattern.MULTI},
	&"__t_ring": {"pattern": Enums.WandPattern.NOVA},
	&"__t_burst": {"pattern": Enums.WandPattern.BURST},
	&"__t_spray": {"pattern": Enums.WandPattern.SPRAY},
	&"__t_seek": {"pattern": Enums.WandPattern.SEEK},
	&"__t_spiral": {"motion": Enums.JinMotion.SPIRAL, "body_scale": 1.2},
	&"__t_bird": {"motion": Enums.JinMotion.BOOMERANG},
}


func _register_test_jins(db) -> void:
	for id: StringName in TEST_JINS:
		var jd := JinDef.new()
		jd.id = id
		var fields: Dictionary = TEST_JINS[id]
		for key: String in fields:
			jd.set(key, fields[key])
		db.jins[id] = jd


func _remove_test_jins(db) -> void:
	for id: StringName in TEST_JINS:
		db.jins.erase(id)


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
	system._deploy_now(_all(G_RADIATE), Vector2(5000, 5000), 0.0, 1.0, 1.0, [0])
	await process_frame
	_check(_bolts(system).size() == 8, "불탄환 8발 (실제 %d)" % _bolts(system).size())
	_check(_pillars().size() == 0, "기둥 0 (실제 %d)" % _pillars().size())


func _test_deploy_gather(system) -> void:
	print("[2] 응집 4칸 전개 → 기둥 1개, 불탄환 0")
	_clear(system)
	system._deploy_now(_ring({0: G_GATHER, 2: G_GATHER, 4: G_GATHER, 6: G_GATHER}),
		Vector2(5000, 5000), 0.0, 1.0, 1.0, [0])
	await process_frame
	_check(_pillars().size() == 1, "기둥 1개 (실제 %d)" % _pillars().size())
	_check(_bolts(system).size() == 0, "불탄환 0 (실제 %d)" % _bolts(system).size())


func _test_deploy_empty(system) -> void:
	print("[3] 빈 진 전개 → 아무것도 안 나온다")
	_clear(system)
	system._deploy_now(_all(GLYPH_NONE), Vector2(5000, 5000), 0.0, 1.0, 1.0, [0])
	await process_frame
	_check(_bolts(system).size() == 0 and _pillars().size() == 0,
		"불탄환·기둥 모두 0 (실제 탄 %d·기둥 %d)" % [_bolts(system).size(), _pillars().size()])


func _test_deploy_mixed(system) -> void:
	print("[4] 혼합(발산 2 + 응집 3) → 불탄환 2발 · 기둥 1개")
	_clear(system)
	system._deploy_now(_ring({1: G_RADIATE, 5: G_RADIATE, 0: G_GATHER, 2: G_GATHER, 4: G_GATHER}),
		Vector2(5000, 5000), 0.0, 1.0, 1.0, [0])
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


# ── 🔴 문양 어휘 → 탄 행동 효과 (세션47) ──
# 세션44까지 `projectile`의 팅김·유도·추진 기계는 **한 번도 실행되지 않는 미배선 자산**이었다
# (유일 호출자가 관통 하나만 넘겼다). 여기가 그 배선을 못 박는다: 각 발사 코드가 자기 GlyphType
# 효과를 **실제로 탄에 싣는지**, 그리고 그 효과가 탄의 행동을 바꾸는지(추진=더 멀리 난다).

func _test_glyph_bolt_effects(system) -> void:
	print("[13] 문양 코드 → 탄 효과 (세션47: 유도∿·팅김⚡·추진↑ 배선)")
	var cases := {G_PIERCE: GT_PIERCE, G_HOMING: GT_HOMING, G_BOUNCE: GT_BOUNCE, G_THRUST: GT_THRUST}
	for code: int in cases:
		_clear(system)
		system._deploy_now(_ring({0: code}), Vector2(5000, 5000), 0.0, 1.0, 1.0, [0])
		await process_frame
		var bolts := _bolts(system)
		_check(bolts.size() == 1, "코드 %d = 탄 1발 (실제 %d)" % [code, bolts.size()])
		if bolts.is_empty():
			continue
		var eff: Dictionary = bolts[0].effects
		_check(eff.has(cases[code]),
			"코드 %d가 GlyphType %d 효과를 싣는다 (실제 %s)" % [code, cases[code], eff.keys()])
	_clear(system)

	# 🔴 발산은 **효과 없는** 순수 직진탄이어야 한다 — 매핑이 새면 여기가 잡는다
	system._deploy_now(_ring({0: G_RADIATE}), Vector2(5000, 5000), 0.0, 1.0, 1.0, [0])
	await process_frame
	var plain := _bolts(system)
	_check(plain.size() == 1 and (plain[0].effects as Dictionary).is_empty(),
		"발산은 효과 없는 순수 직진탄")
	_clear(system)

	# 🔴 효과가 **행동을 바꾸는지** — 사전만 보면 projectile이 무시해도 통과한다.
	# 추진탄은 같은 시간에 더 멀리 난다 (balance.glyph_thrust_speed_max 배).
	var fast := await _travel_of(system, G_THRUST)
	var slow := await _travel_of(system, G_RADIATE)
	_check(fast > slow * 1.5,
		"추진탄이 실제로 더 빠르다 (%.1f > %.1f px, 기대 ≈2.4배)" % [fast, slow])


## 코드 하나짜리 진을 펴서 그 탄이 8 물리 프레임 동안 간 거리 (빈 곳 — 아무것에도 안 닿는다).
func _travel_of(system, code: int) -> float:
	_clear(system)
	system._deploy_now(_ring({0: code}), Vector2(5000, 5000), 0.0, 1.0, 1.0, [0])
	await process_frame
	var bolts := _bolts(system)
	if bolts.is_empty():
		return -1.0
	var bolt = bolts[0]
	var start: Vector2 = bolt.global_position
	for i in 8:
		await physics_frame
	var moved := start.distance_to(bolt.global_position)
	_clear(system)
	return moved


# ── 🔴 진 5종 = 발사 형태 (세션48) ──
# 세션44에 진 3개가 WandPattern 3개를 1:1로 소진해 "새 진 = .tres 한 장"이 깨져 있었다. 세션48이
# 패턴 3종(연발·분사·타겟팅)과 **직교 축인 경로**(나선·부메랑)를 더해 그걸 열었다.
# 🔴 여기가 그 축들을 못 박는다. 진 5종을 "발수만" 세면 검출력이 0이다 — 연발과 산탄은 발수가
# 같을 수도 있고, 갈리는 건 **시간축**이다. 그래서 아래는 전부 **관측 가능한 행동**으로 잰다:
#   발수는 세되 **언제** 생겼는지 · 각도는 **캐리어가 실제로 간 방향**으로 · 경로는 **위치 궤적**으로.
# 내부 필드(_velocity·_shot_plan)는 안 더듬는다 — 리팩터 때 조용히 깨지는 물건이라 계약이 아니다.

## 진 id로 빈 진을 쏜다 (전개 없음 — 캐리어만 본다). aim 기본 = 오른쪽.
func _cast_jin(system, jin_id: StringName, aim: Vector2 = Vector2(1, 0)) -> void:
	_bus.ring_cast_requested.emit(
		{"rings": [_all(GLYPH_NONE)], "jin": jin_id}, Vector2.ZERO, aim)


## 캐리어들이 **실제로 간 방향** (원점 기준 각도). 위치는 공개(global_position)라 계약이 안전하다.
## 아직 안 움직인 캐리어(막 생김)는 방향이 없으므로 뺀다 — 부르기 전에 충분히 기다릴 것.
func _carrier_angles(system) -> Array:
	var out: Array = []
	for c in _carriers(system):
		var p: Vector2 = c.global_position
		if p.length() > 1.0:
			out.append(p.angle())
	return out


## 지연 발사 타이머가 다 터지도록 물리 프레임을 흘린다 (연발·분사는 시간축이 정체성이다).
func _drain(frames: int) -> void:
	for i in frames:
		await physics_frame


## 앞 테스트의 허수아비가 "enemies" 그룹에 남으면 타겟팅이 엉뚱한 걸 문다 — queue_free는 지연이라
## 프레임을 흘려 실제로 빠질 때까지 기다린다.
func _purge_enemies() -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await process_frame
	await process_frame


## 🔴 연발 = **같은 각도 N발인데 시간이 다르다.** 산탄과 갈리는 지점이 오직 시간축이므로,
## delay가 전부 0이 되는 순간(뮤테이션) 이 테스트가 빨개져야 한다.
func _test_jin_burst(system) -> void:
	print("[14] 연발진 = 같은 각도로 시간차 N발 (세션48 BURST)")
	_clear(system)
	await _purge_enemies()
	var bal = system.balance
	var n := int(bal.jin_burst_count)

	_cast_jin(system, &"__t_burst")
	await process_frame
	# 🔴 검출력의 핵심: 첫 프레임엔 **1발뿐**이어야 한다. delay가 전부 0이면 여기서 n발이 나온다.
	_check(_carriers(system).size() == 1,
		"연발은 첫 프레임에 1발만 (실제 %d — 전부 나오면 delay가 죽은 것)" % _carriers(system).size())
	# 마지막 발이 나올 시간(간격×(n-1))을 넉넉히 넘겨 기다린다
	await _drain(40)
	_check(_carriers(system).size() == n,
		"기다리면 %d발 다 나온다 (실제 %d)" % [n, _carriers(system).size()])

	# 같은 각도인지 — 연발은 조준선 한 줄에 다 실린다 (퍼지면 그건 산탄·분사다)
	var angles := _carrier_angles(system)
	var spread := _angle_spread(angles)
	_check(angles.size() == n and spread < 0.02,
		"연발 %d발이 전부 같은 각도 (퍼짐 %.4f rad — 0이어야)" % [angles.size(), spread])
	_clear(system)
	await _drain(20)


## 🔴 분사 = 각도도 퍼지고 시간도 다르다. 연발(한 점·시간차)·산탄(퍼짐·동시) **둘 다와** 갈린다.
## 그래서 세 축을 다 잰다: 첫 프레임 발수 · 총 발수 · 퍼짐(산탄보다 좁은지).
func _test_jin_spray(system) -> void:
	print("[15] 분사진 = 좁게 퍼지며 시간차 (세션48 SPRAY — 연발·산탄 둘 다와 구분)")
	_clear(system)
	await _purge_enemies()
	var bal = system.balance
	var n := int(bal.jin_spray_count)

	_cast_jin(system, &"__t_spray")
	await process_frame
	_check(_carriers(system).size() == 1,
		"분사도 첫 프레임엔 1발 (실제 %d — 연발과 같은 시간축)" % _carriers(system).size())
	await _drain(40)
	_check(_carriers(system).size() == n,
		"기다리면 %d발 다 나온다 (실제 %d)" % [n, _carriers(system).size()])

	var spray_spread := _angle_spread(_carrier_angles(system))
	_check(spray_spread > 0.02,
		"분사는 각도가 퍼진다 (%.4f rad — 연발이면 0이다)" % spray_spread)
	_clear(system)
	await _drain(20)

	# 🔴 산탄보다 **좁다** — 좁은 각이 분사의 정체성이다 (넓으면 산탄과 구별이 안 된다)
	_cast_jin(system, &"__t_fork")
	await _drain(10)
	var fork_spread := _angle_spread(_carrier_angles(system))
	_check(fork_spread > spray_spread,
		"분사(%.4f)가 산탄(%.4f)보다 좁다" % [spray_spread, fork_spread])
	_clear(system)
	await _drain(10)


## 🔴 타겟팅 = **조준을 무시하고** 가장 가까운 적으로 간다.
## 검출력의 핵심: 조준을 적과 **정반대**로 준다 — fallback 각도만 반환하는 뮤테이션이면 여기서 죽는다.
func _test_jin_seek(system) -> void:
	print("[16] 타겟진 = 조준 무시하고 가장 가까운 적으로 (세션48 SEEK)")
	_clear(system)
	await _purge_enemies()

	# 적은 **위쪽**(0,-300), 조준은 **아래쪽**(0,+1) = 정반대
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(0, -300)
	await process_frame
	_cast_jin(system, &"__t_seek", Vector2(0, 1))
	await _drain(8)   # 적까지 300px — 8프레임(≈35px)이면 아직 안 닿아 캐리어가 살아 있다
	var seek_angles := _carrier_angles(system)
	var got := float(seek_angles[0]) if not seek_angles.is_empty() else 999.0
	# 위쪽 = -PI/2. 조준(아래=+PI/2)을 그대로 썼으면 부호가 반대라 크게 빗나간다.
	_check(seek_angles.size() == 1 and absf(angle_difference(got, -PI / 2.0)) < 0.15,
		"조준이 정반대여도 적 쪽(-1.571)으로 간다 (실제 %.3f rad)" % got)
	_clear(system)
	await _purge_enemies()

	# 🔴 사거리 **밖**이면 조준으로 폴백 — 안 그러면 지평선 너머 적에게 끌려간다
	var far = _dummy_scene.instantiate()
	root.add_child(far)
	far.global_position = Vector2(0, -900)   # jin_seek_radius_px=420 밖
	await process_frame
	_cast_jin(system, &"__t_seek", Vector2(1, 0))
	await _drain(8)
	var fb := _carrier_angles(system)
	var fa := float(fb[0]) if not fb.is_empty() else 999.0
	_check(fb.size() == 1 and absf(angle_difference(fa, 0.0)) < 0.15,
		"사거리 밖 적은 무시하고 조준(0.000)으로 폴백 (실제 %.3f rad)" % fa)
	_clear(system)
	await _purge_enemies()


## 🔴 나선 = 진행축에서 **벗어나며** 난다. 직진 진과 **같은 각도로 쏴서** 궤적을 비교한다 —
## 직진은 축 이탈이 ~0이고 나선은 유의미하게 벗어나야 한다. 분기를 직진으로 되돌리면 여기가 죽는다.
func _test_jin_spiral(system) -> void:
	print("[17] 나선진 = 진행축을 벗어나며 훑는다 (세션48 JinMotion.SPIRAL)")
	var spiral := await _axis_deviation(system, &"__t_spiral")
	var straight := await _axis_deviation(system, &"jin_single")
	_check(straight < 1.0, "직진진은 축 이탈 ~0 (실제 %.2f px)" % straight)
	_check(spiral > 5.0, "나선진은 축에서 벗어난다 (%.2f px)" % spiral)
	_check(spiral > straight * 10.0 + 5.0,
		"나선 이탈이 직진보다 압도적 (%.2f ≫ %.2f px)" % [spiral, straight])


## 오른쪽(1,0)으로 쏜 캐리어가 진행축(y=0)에서 벗어난 **최대 거리**. 직진이면 0에 붙는다.
func _axis_deviation(system, jin_id: StringName) -> float:
	_clear(system)
	await _purge_enemies()
	_cast_jin(system, jin_id)
	await process_frame
	var cs := _carriers(system)
	if cs.is_empty():
		return -1.0
	var carrier = cs[0]
	var worst := 0.0
	for i in 12:
		await physics_frame
		if not is_instance_valid(carrier):
			break
		worst = maxf(worst, absf(carrier.global_position.y))
	_clear(system)
	await _drain(4)
	return worst


## 🔴 부메랑 = 나갔다가 **되돌아온다.** origin과의 거리가 한 번 늘었다가 **줄어야** 한다 —
## 최대 거리만 재면 직진도 통과하므로, 끝 거리가 최대보다 확실히 작은지가 계약이다.
func _test_jin_boomerang(system) -> void:
	print("[18] 새의진 = 나갔다 되돌아온다 (세션48 JinMotion.BOOMERANG)")
	_clear(system)
	await _purge_enemies()
	_cast_jin(system, &"__t_bird")
	await process_frame
	var cs := _carriers(system)
	_check(cs.size() == 1, "부메랑 진 1발 (실제 %d)" % cs.size())
	if cs.is_empty():
		return
	var carrier = cs[0]
	var peak := 0.0
	var last := 0.0
	# 수명 1.5초 · turn_ratio 0.5 → 0.75초에 유턴. 죽기 전(≈1.3초)까지만 본다.
	for i in 78:
		await physics_frame
		if not is_instance_valid(carrier):
			break
		last = carrier.global_position.length()
		peak = maxf(peak, last)
	_check(peak > 100.0, "일단 멀리 나간다 (최대 %.1f px)" % peak)
	_check(last < peak - 30.0,
		"그리고 되돌아온다 (끝 %.1f px < 최대 %.1f px — 직진이면 끝=최대)" % [last, peak])
	_clear(system)
	await _drain(4)


## 🔴 body_scale이 **실제로 먹는가** (세션48에 DARK에서 깨어난 필드).
## 두 갈래로 잰다: ① 규모가 발수를 늘린다(산탄) ② 규모가 몸집을 키운다(body_radius).
## ①은 scale≠1.0인 산탄 진이 data에 없어 **테스트 전용 JinDef를 Db에 임시 등록**해 잰다
## (data/·src/는 리드 영역이라 손대지 않는다 — 등록은 테스트가 끝나며 되돌린다).
func _test_jin_body_scale(system) -> void:
	print("[19] 진 규모(body_scale) → 발수·몸집 (세션48)")
	_clear(system)
	await _purge_enemies()
	var db = root.get_node("/root/Db")

	var big := JinDef.new()
	big.id = &"__test_big_fork"
	big.pattern = Enums.WandPattern.MULTI
	big.body_scale = 2.0
	db.jins[big.id] = big

	_cast_jin(system, &"__t_fork")
	await _drain(4)
	var base_n := _carriers(system).size()
	_clear(system)
	await _drain(4)

	_cast_jin(system, &"__test_big_fork")
	await _drain(4)
	var big_n := _carriers(system).size()
	_check(big_n > base_n,
		"큰 산탄진이 갈래가 더 많다 (규모2.0=%d발 > 규모1.0=%d발)" % [big_n, base_n])
	_clear(system)
	await _drain(4)
	db.jins.erase(big.id)

	# ② 몸집 — body_radius()가 규모에 비례한다 (먹선·히트박스가 같이 보는 공개 함수)
	_cast_jin(system, &"jin_single")     # body_scale 1.0
	await process_frame
	var r1 := float(_carriers(system)[0].body_radius()) if not _carriers(system).is_empty() else -1.0
	_clear(system)
	await _drain(4)
	_cast_jin(system, &"__t_spiral")     # body_scale 1.2
	await process_frame
	var r2 := float(_carriers(system)[0].body_radius()) if not _carriers(system).is_empty() else -1.0
	_check(r1 > 0.0 and r2 > r1,
		"규모 1.2 진이 몸집이 크다 (%.1f > %.1f px)" % [r2, r1])
	_clear(system)
	await _drain(4)


## 🔴 회귀 가드 — 새 축을 얹었어도 **옛 진·매직볼은 예전과 똑같이** 나가야 한다.
## 진이 없는 도안(매직볼)은 set_motion을 아예 안 부르는 경로라 특히 중요하다.
func _test_jin_legacy_patterns(system) -> void:
	print("[20] 회귀 — 매직볼·옛 진 3종은 예전 그대로 (세션48 전과 동일)")
	_clear(system)
	await _purge_enemies()
	var gs = root.get_node("/root/GameState")
	var saved: Dictionary = gs.equipment.duplicate()
	gs.equipment = {}   # 지팡이 폴백이 끼어들지 않게 (진 없는 도안은 장비를 본다)
	var bal = system.balance

	# 진 없는 도안 = 매직볼 = 단발 · 시간차 없음
	_bus.ring_cast_requested.emit({"rings": [_all(GLYPH_NONE)]}, Vector2.ZERO, Vector2(1, 0))
	await process_frame
	_check(_carriers(system).size() == 1,
		"매직볼(진 없음)=즉시 단발 (실제 %d)" % _carriers(system).size())
	_clear(system)
	await _drain(4)

	# 옛 진 3종 — 전부 **첫 프레임에** 제 발수가 다 나온다 (시간차는 신규 진만의 것이다)
	var expect := {&"jin_single": 1, &"__t_fork": int(bal.wand_multi_count),
		&"__t_ring": int(bal.wand_nova_count)}
	for jid: StringName in expect:
		_cast_jin(system, jid)
		await process_frame
		var n := _carriers(system).size()
		_check(n == int(expect[jid]), "%s = 첫 프레임에 %d발 (실제 %d)" % [jid, int(expect[jid]), n])
		_clear(system)
		await _drain(4)

	gs.equipment = saved


## 각도 배열의 퍼짐 (최대 - 최소, wrap 안전 — 여기 각도들은 다 같은 사분면대라 단순 차로 충분).
func _angle_spread(angles: Array) -> float:
	if angles.size() < 2:
		return 0.0
	var lo := 999.0
	var hi := -999.0
	for a: float in angles:
		lo = minf(lo, a)
		hi = maxf(hi, a)
	return hi - lo


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
