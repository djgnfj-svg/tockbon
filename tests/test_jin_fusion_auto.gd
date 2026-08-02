extends SceneTree
## 🔴 룬 2개 + 융합진 자동 검증 — 헤드리스:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_jin_fusion_auto.gd
## 전 항목 통과 시 "TEST_JIN_FUSION_OK" 출력 후 종료.
##
## 주의: -s는 오토로드 등록 전 컴파일 — 오토로드는 root.get_node(), 모듈 스크립트는 load()로 지연.

const SLOTS := 8
const GLYPH_NONE := -1
# 고리 칸 어휘 (Enums.GlyphCode — 하드코딩해 모듈 preload 회피)
const G_GATHER := 0
const G_RADIATE := 1
const G_EXPLODE := 7
# 룬 (Enums.RuneType) — 불0·물2·바람3·번개4·흙5·풀6
const R_FIRE := 0
const R_WATER := 2
const R_BOLT := 4
# 상태 (Enums.Status)
const S_WET := 3
const S_SHOCK := 5

var failures: int = 0
var _bus = null
var _db = null
var _dummy_scene: PackedScene = null
var _RD = null   # ring_design.gd
var _RA = null   # ring_assembly.gd


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_JIN_FUSION_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_db = root.get_node("/root/Db")
	_dummy_scene = load("res://src/spell/dummy_target.tscn") as PackedScene
	_RD = load("res://src/core/schemas/ring_design.gd")
	_RA = load("res://src/drawing/ring_assembly.gd")

	var system_scene := load("res://src/spell/ring_spell_system.tscn") as PackedScene
	var system = system_scene.instantiate()
	root.add_child(system)
	await process_frame

	_test_jin_load()
	_test_runes_of()
	_test_assembly_contract()
	_test_fire_hit_sum(system)
	await _test_fusion_reaction(system)
	await _test_no_double_juice(system)
	await _test_pillar_blast_reaction(system)
	_test_single_rune_regression(system)

	if failures == 0:
		print("TEST_JIN_FUSION_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_JIN_FUSION_FAIL — %d개 실패" % failures)
		quit(1)


# ── [1] jin_fuse Db 로드 + rune_slots (파싱 침묵사 그물) ──
func _test_jin_load() -> void:
	print("[1] jin_fuse Db 로드 + rune_slots")
	var jf = _db.get_jin(&"jin_fuse")
	_check(jf != null, "jin_fuse 로드됨 (.tres 파싱 실패면 null)")
	if jf != null:
		_check(int(jf.rune_slots) == 2, "jin_fuse.rune_slots == 2 (실제 %d)" % int(jf.rune_slots))
		_check(int(jf.band_count) == 2, "jin_fuse.band_count == 2 (M1 층 순서 계승)")
	# 🔴 무회귀: 옛 진은 rune_slots 필드가 없어 기본 1 (조용히 안 깨진다)
	var js = _db.get_jin(&"jin_single")
	_check(js != null and int(js.rune_slots) == 1, "jin_single.rune_slots == 1 (기본값 무회귀)")


# ── [2] runes_of 승격·멱등 + 저장 라운드트립 ──
func _test_runes_of() -> void:
	print("[2] runes_of 승격·멱등 + 저장 라운드트립")
	# 빈 목록 → fallback 하나로 승격 (옛 도안 = 정수 하나)
	var a = _RD.runes_of([], R_WATER)
	_check(a.size() == 1 and int(a[0]) == R_WATER, "runes_of([], WATER) == [WATER] (승격)")
	# 목록이 있으면 그대로 (자리 순서 보존)
	var b = _RD.runes_of([R_WATER, R_BOLT], R_FIRE)
	_check(b.size() == 2 and int(b[0]) == R_WATER and int(b[1]) == R_BOLT,
		"runes_of([WATER,BOLT], FIRE) == [WATER,BOLT] (fallback 무시)")
	# 멱등: 승격 결과를 다시 넣어도 같다
	var c = _RD.runes_of(b, R_FIRE)
	_check(c.size() == 2 and int(c[0]) == R_WATER, "runes_of 멱등")

	# 🔴 옛 도안(runes 키 없음, rune 정수 하나)이 from_assembly에서 승격
	var old_d = _RD.from_assembly({"rune": R_WATER, "rings": [_all(GLYPH_NONE)]})
	_check(old_d.runes.size() == 1 and int(old_d.runes[0]) == R_WATER,
		"옛 도안 {rune:WATER} → runes==[WATER] (저장 무회귀)")
	# 다중 룬 라운드트립: assembly → RingDesign → to_assembly
	var d = _RD.from_assembly({"runes": [R_WATER, R_BOLT], "rune": R_WATER,
		"rings": [_all(GLYPH_NONE)]})
	_check(d.runes.size() == 2 and int(d.runes[1]) == R_BOLT, "다중 룬 from_assembly 보존")
	_check(int(d.rune) == R_WATER, "primary(rune) = 첫 룬으로 채움 (옛 소비자 무회귀)")
	var round = d.to_assembly()
	_check((round.get("runes", []) as Array).size() == 2, "to_assembly가 runes 목록을 싣는다")
	_check(int(round.get("rune", -1)) == R_WATER, "to_assembly가 rune=첫 룬을 싣는다")


# ── [3] RingAssembly 다중 룬 계약 ──
func _test_assembly_contract() -> void:
	print("[3] RingAssembly 다중 룬 계약")
	var asm = _RA.new()
	asm.lock_jin()                 # 진 잠금 → 룬 단계로
	asm.set_rune_slots(2)          # 융합진 = 자리 2
	_check(asm.rune_slots() == 2, "set_rune_slots(2)")
	asm.set_rune(R_WATER, 0)
	_check(asm.has_rune(), "룬 하나 골라도 has_rune 참")
	_check(not asm.runes_ready(), "🔴 자리 하나만 차면 runes_ready 거짓 (아직 못 맺는다)")
	asm.set_rune(R_BOLT, 1)
	_check(asm.runes_ready(), "🔴 두 자리 다 차면 runes_ready 참")
	var g = asm.get_assembly()
	var rs: Array = g.get("runes", [])
	_check(rs.size() == 2 and int(rs[0]) == R_WATER and int(rs[1]) == R_BOLT,
		"get_assembly.runes == [WATER,BOLT] (자리 순서)")
	_check(int(g.get("rune", -1)) == R_WATER, "get_assembly.rune == primary(WATER)")

	# 🔴 무회귀: 자리 1(무인자 choose_rune 경로) — 옛 흐름 그대로
	var s = _RA.new()
	s.lock_jin()
	s.set_rune(R_FIRE)             # slot 미지정(-1) = 다음 빈 자리 = 0
	_check(s.runes_ready(), "자리 1 진: 룬 하나로 runes_ready 참 (옛 흐름)")
	_check(int(s.get_rune()) == R_FIRE, "자리 1 진: get_rune == FIRE")


# ── [4] _fire_hit 합산(합 1.4)+rune_hits+정렬 ──
func _test_fire_hit_sum(system) -> void:
	print("[4] _fire_hit 합산 + rune_hits + 반응 순서 정렬")
	var water_solo: Dictionary = system._fire_hit(1.0, 1.0, [R_WATER])
	var bolt_solo: Dictionary = system._fire_hit(1.0, 1.0, [R_BOLT])
	var fusion: Dictionary = system._fire_hit(1.0, 1.0, [R_WATER, R_BOLT])
	# 🔴 합산 = 0.7씩 → 융합 피해 == 0.7 × (두 룬 단독 피해 합). base_damage 값과 무관한 불변식.
	var expect := 0.7 * (float(water_solo.damage) + float(bolt_solo.damage))
	_check(is_equal_approx(float(fusion.damage), expect),
		"융합 피해 == 0.7×(물+번개 단독 합) (기대 %.3f 실제 %.3f)" % [expect, float(fusion.damage)])
	# rune_hits = 두 룬 전부
	var rh: Array = fusion.get("rune_hits", [])
	_check(rh.size() == 2, "rune_hits 두 룬 실림 (실제 %d)" % rh.size())
	# 🔴 정렬: 물(WET)이 반응 바탕이라 primary — 자리 순서를 뒤집어도 primary는 물
	_check(int(fusion.rune_type) == R_WATER, "정렬: primary == WATER (WET 바탕)")
	var swapped: Dictionary = system._fire_hit(1.0, 1.0, [R_BOLT, R_WATER])
	_check(int(swapped.rune_type) == R_WATER, "🔴 자리 뒤집어도 primary == WATER (order_for_reaction)")


# ── [5] 심장: 융합 발사 → 한 발이 두 상태 → 반응 + 자리 순서 무의존 ──
func _test_fusion_reaction(system) -> void:
	print("[5] 🔴 심장: 융합 발사 → 두 상태 동시 → 반응(감전) + 자리 순서 무의존")
	# ⓐ 물+번개
	var got_a = await _fire_fusion_at_dummy(system, [R_WATER, R_BOLT])
	_check(got_a != null and got_a.has_status(S_SHOCK),
		"물+번개 융합 → 감전(SHOCK) 반응이 났다")
	if got_a != null:
		_check(not got_a.has_status(S_WET), "반응에 바탕(젖음)이 소진됐다")
	# ⓑ 자리 뒤집기 — 같은 반응이 나야 한다(순서 무의존)
	var got_b = await _fire_fusion_at_dummy(system, [R_BOLT, R_WATER])
	_check(got_b != null and got_b.has_status(S_SHOCK),
		"🔴 번개+물(자리 뒤집기) → 여전히 감전 (순서 무의존)")


# ── [6] 🔴 도배: 보조 0-피해 히트가 enemy_hit을 안 쏜다 ──
func _test_no_double_juice(system) -> void:
	print("[6] 🔴 도배 방지: 융합 한 발 = enemy_hit 발신 정확히 1회")
	_clear(system)
	var count := {"n": 0}
	var cb := func(_node, _dmg, _rune) -> void: count["n"] += 1
	_bus.enemy_hit.connect(cb)
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(140, 0)
	# 빈 진 — 캐리어 몸 히트 한 번만(전개 없음). 융합이라 두 룬 상태를 얹지만 발신은 primary 1회여야.
	_bus.ring_cast_requested.emit(
		{"rings": [_all(GLYPH_NONE)], "runes": [R_WATER, R_BOLT]}, Vector2.ZERO, Vector2(1, 0))
	var frames := 0
	while dummy.hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	await physics_frame
	_bus.enemy_hit.disconnect(cb)
	# 🔴 primary(물, 피해>0) 1회만. 보조(번개, 피해0)는 0-피해 가드로 발신 안 함.
	_check(int(count["n"]) == 1, "enemy_hit 발신 == 1 (실제 %d — 2면 0-피해 가드가 빠진 것)" % int(count["n"]))
	# dummy.hits엔 두 히트 다 담긴다(관측용) — 도배는 발신 수로만 잰다
	_check(dummy.hits.size() == 2, "dummy.hits엔 두 룬 히트 다 기록 (관측 %d)" % dummy.hits.size())
	dummy.queue_free()
	_clear(system)


# ── [7] 기둥·폭발도 반응이 난다 (rune_hits 이식 그물) ──
func _test_pillar_blast_reaction(system) -> void:
	print("[7] 기둥·폭발도 융합 반응이 난다")
	# 기둥 — 응집 링을 dummy 자리에 직접 전개
	var pd = await _deploy_at_dummy(system, _ring({0: G_GATHER, 2: G_GATHER}), [R_WATER, R_BOLT])
	_check(pd != null and pd.has_status(S_SHOCK), "🔴 응집 기둥도 융합 반응(감전)이 난다")
	# 폭발 — 폭발 문양 링(변형형)을 직접 전개
	var bd = await _deploy_at_dummy(system, _ring({0: G_EXPLODE}), [R_WATER, R_BOLT])
	_check(bd != null and bd.has_status(S_SHOCK), "🔴 폭발도 융합 반응(감전)이 난다")


# ── [8] 회귀: 룬 1개 = 옛 계산 동일 (share 1.0) ──
func _test_single_rune_regression(system) -> void:
	print("[8] 회귀: 룬 1개 = 옛 계산 동일 (share 없음)")
	var solo: Dictionary = system._fire_hit(1.0, 1.0, [R_FIRE])
	# 옛 경로 = base × fire.base_damage × 1.0. share가 1.0이라 배율 없음.
	var bal := load("res://data/balance.tres")
	var fire_rune = _db.get_rune(R_FIRE)
	var expect := float(bal.projectile_base_damage) * float(fire_rune.base_damage) * 1.0
	_check(is_equal_approx(float(solo.damage), expect),
		"룬 1개 피해 = base×base_damage×1.0 (기대 %.3f 실제 %.3f)" % [expect, float(solo.damage)])
	# rune_hits 하나(primary) — projectile 루프가 primary를 건너뛰어 부작용 0
	_check((solo.get("rune_hits", []) as Array).size() == 1, "룬 1개 rune_hits = [primary] 하나")


# ─────────────────────────── 헬퍼 ───────────────────────────

## 융합 발사를 dummy에 캐리어 몸으로 명중시키고 dummy를 돌려준다.
func _fire_fusion_at_dummy(system, runes: Array):
	_clear(system)
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(140, 0)
	_bus.ring_cast_requested.emit(
		{"rings": [_all(GLYPH_NONE)], "runes": runes}, Vector2.ZERO, Vector2(1, 0))
	var frames := 0
	while dummy.hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	await physics_frame   # 반응 판정(피해 뒤) 한 프레임 여유
	var out = dummy if not dummy.hits.is_empty() else null
	# 정리는 다음 _clear에 맡기되, dummy는 여기서 떼지 않는다(호출부가 상태를 읽는다)
	dummy.call_deferred("queue_free")
	return out


## 전개 명령을 dummy 자리에 직접 심는다(_deploy_now) — 캐리어 없이 기둥·폭발만 격리 검증.
func _deploy_at_dummy(system, ring: Array, runes: Array):
	_clear(system)
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(300, 0)
	await physics_frame
	system._deploy_now([ring], dummy.global_position, 0.0, 1.0, 1.0, runes)
	var frames := 0
	while dummy.hits.is_empty() and frames < 60:
		await physics_frame
		frames += 1
	await physics_frame
	var out = dummy if not dummy.hits.is_empty() else null
	dummy.call_deferred("queue_free")
	return out


func _ring(fills: Dictionary) -> Array:
	var r: Array = []
	for k in SLOTS:
		r.append(int(fills.get(k, GLYPH_NONE)))
	return r


func _all(g: int) -> Array:
	var r: Array = []
	for k in SLOTS:
		r.append(g)
	return r


func _clear(system) -> void:
	for c in system.get_children():
		c.queue_free()
	for g in ["pillars", "blasts"]:
		for n in get_nodes_in_group(g):
			n.queue_free()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ✓ " + label)
	else:
		failures += 1
		print("  ✗ " + label)
