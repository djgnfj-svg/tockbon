extends SceneTree
## 🔴 진별 해석 — **층(밴드) 순서 = 연산 순서** 자동 검증. 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_jin_layers_auto.gd
## 전 항목 통과 시 "TEST_JIN_LAYERS_OK" 출력 후 종료 코드 0.
##
## 룬을 문양이 겹겹이 감싸고 **안→밖 = 연산 순서**다. 전개형(발산·응집)은 명령을 만들고,
## 변형형(확산·폭발)은 **안쪽 결과를 받아 바꾼다**.
##
## 🔴 이 파일의 심장 = [4] **순서가 실제로 결과를 바꾸는가.**
##   `폭발(확산(불))` = 3갈래를 융합 → **큰 폭발 하나**
##   `확산(폭발(불))` = 폭발 하나를 복제 → **작은 폭발 셋**
##   순서를 바꿔도 같은 게 나오면 이 설계가 통째로 실패한 것이다.
##
## ⚠ **balance 수치를 하드코딩하지 않는다** — 두 배치의 **관계**(개수 1↔3, 반경 대소)로 잰다.
##   수치를 박으면 손맛 튜닝(F5) 한 번에 그물이 거짓 빨강이 된다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일되므로 오토로드 식별자·모듈 preload 금지 —
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

# 문양 칸 어휘 (Enums.GlyphCode와 같은 값 — 여기 하드코딩해 모듈 preload를 피한다)
const G_GATHER := 0
const G_RADIATE := 1
const G_SPREAD := 6      ## 확산 = 복제 산개 (변형형)
const G_EXPLODE := 7     ## 폭발 = 융합 광역 (변형형)
const GLYPH_NONE := -1
const SLOTS := 8
const FAR := Vector2(5000, 5000)   # 아무도 없는 곳 — 탄이 즉시 뭔가에 닿아 사라지지 않게

var failures: int = 0
var _board = null
var _db = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_JIN_LAYERS_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_db = root.get_node("/root/Db")
	_board = load("res://src/drawing/ring_board.gd")

	var system_scene := load("res://src/spell/ring_spell_system.tscn") as PackedScene
	var system = system_scene.instantiate()
	root.add_child(system)
	await process_frame

	_test_db_load()
	_test_layer_rings()
	_test_flatten_parity()
	_test_as_layers(system)
	await _test_order_changes_result(system)
	await _test_legacy_single_layer(system)
	await _test_seed_when_nothing_to_wrap(system)
	await _test_panel_carries_layers()
	await _test_damage_distribution(system)
	_test_formula_text()

	if failures == 0:
		print("TEST_JIN_LAYERS_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_JIN_LAYERS_FAIL — %d개 실패" % failures)
		quit(1)


# ── [0] Db 로드 (🔴 .tres 파싱 침묵사 그물) ──
## 🔴 개수를 안 세면 .tres 한 장이 파싱 실패로 증발해도 전 스위트가 그린이다 —
## `test_rune_unlock_auto`의 「룬 6종 로드」와 같은 역할이다.
func _test_db_load() -> void:
	print("[0] M1 콘텐츠 + 문양-고리 전수가 Db에 실제로 로드된다")
	var sp = _db.get_glyph_ring(&"gr_spread3")
	var ex = _db.get_glyph_ring(&"gr_explode1")
	var g2 = _db.get_jin(&"jin_plain_g2")
	_check(sp != null and int(sp.motif) == G_SPREAD and int(sp.count) == 3,
		"gr_spread3 = 확산×3 (null이면 .tres가 조용히 거부됐다 — Color 3인자 등)")
	_check(ex != null and int(ex.motif) == G_EXPLODE and int(ex.count) == 1,
		"gr_explode1 = 폭발×1")
	# 🔴 전제: 1등급(1층)은 겹이 하나뿐이라 **감쌀 순서 자체가 안 생긴다**.
	_check(g2 != null and int(g2.band_count) == 2,
		"jin_plain_g2 = 2등급(band_count 2) — 순서를 만들려면 2겹이 필요하다")
	# 🔴 전 종수 — 새 문양-고리를 더하면 이 기대치를 같이 올려라(줄었으면 파싱 침묵사 의심).
	var rings: Array = _db.all_glyph_rings()
	_check(rings.size() == 5,
		"문양-고리 5종 로드 (실제 %d — .tres 파싱 실패면 조용히 줄어든다)" % rings.size())
	var r5 = _db.get_glyph_ring(&"gr_radiate5")
	var g3 = _db.get_glyph_ring(&"gr_gather3")
	_check(r5 != null and int(r5.motif) == G_RADIATE and int(r5.count) == 5, "gr_radiate5 = 발산×5")
	_check(g3 != null and int(g3.motif) == G_GATHER and int(g3.count) == 3, "gr_gather3 = 응집×3")
	_check(rings.size() >= 2 and rings[0].sort <= rings[1].sort,
		"all_glyph_rings가 sort 오름차순으로 준다 (책 셀 순서의 근거)")


# ── [1] layer_rings = 밴드 → 층 배열 (발사 계약) ──
func _test_layer_rings() -> void:
	print("[1] layer_rings: 밴드 순서 = 층 순서, 칸 0부터 count개")
	var sp = _db.get_glyph_ring(&"gr_spread3")
	var ex = _db.get_glyph_ring(&"gr_explode1")
	var layers: Array = _board.layer_rings([sp, ex])
	_check(layers.size() == 2, "밴드 2개 → 층 2개 (실제 %d)" % layers.size())
	_check((layers[0] as Array).size() == SLOTS and (layers[1] as Array).size() == SLOTS,
		"각 층은 8칸")
	_check(int(layers[0][0]) == G_SPREAD and int(layers[0][2]) == G_SPREAD
		and int(layers[0][3]) == GLYPH_NONE, "층0 = 확산 3칸(0~2), 나머지 빈칸")
	_check(int(layers[1][0]) == G_EXPLODE and int(layers[1][1]) == GLYPH_NONE,
		"층1 = 폭발 1칸")
	# 🔴 빈 밴드도 **층 자리를 지킨다** — 건너뛰면 감쌈 깊이가 조용히 밀린다
	var withnull: Array = _board.layer_rings([null, ex])
	_check(withnull.size() == 2, "빈 밴드도 층 자리를 지킨다 (실제 %d)" % withnull.size())
	_check(int(withnull[0][0]) == GLYPH_NONE and int(withnull[1][0]) == G_EXPLODE,
		"빈 밴드 = 전부 빈칸, 뒤 층은 밀리지 않는다")


# ── [2] 🔴 회귀: 밴드가 하나뿐이면 옛 flatten과 점 단위로 같다 ──
func _test_flatten_parity() -> void:
	print("[2] 🔴 회귀: 밴드 1개면 층0 == flatten_bands (저장 도안 무변경)")
	# 지금 살아있는 진은 전부 band_count=1이라, 이 동치가 곧 "옛 도안 발사가 안 바뀐다"의 증명이다.
	var checked := 0
	for id in [&"gr_radiate5", &"gr_gather3"]:
		var gr = _db.get_glyph_ring(id)
		if gr == null:
			continue
		checked += 1
		var flat: Array = _board.flatten_bands([gr])
		var layered: Array = _board.layer_rings([gr])
		_check(layered.size() == 1, "%s: 밴드 1개 → 층 1개" % id)
		_check(_same_ring(layered[0], flat), "%s: 층0이 flatten과 칸 단위로 동일" % id)
	# 🔴 자명 통과 방지 — 대조군이 사라지면 이 그물은 **검사 0건으로 그린**이 된다.
	# 이게 「옛 도안 무회귀」의 유일한 그물이다.
	_check(checked > 0, "대조군 문양-고리가 최소 1종은 있어야 한다 (실제 %d종)" % checked)
	# 🔴 C2: 밴드 0개여도 **빈 층 하나**를 준다 — 빈 배열을 주면 발사가 통째로 접혀
	# "빈 진도 날아가 몸으로 때린다"(ring_carrier 계약)가 조용히 깨진다.
	var none: Array = _board.layer_rings([])
	_check(none.size() == 1 and (none[0] as Array).size() == SLOTS,
		"밴드 0개 → 빈 층 1개 (flatten_bands([])와 동치, 실제 %d층)" % none.size())

	# 🔴 `flatten_bands` **자체의 계약** — src 호출자는 0이지만 **위 동치 검사의 기준자**다.
	# 기준자가 조용히 망가지면 위 「층0 == flatten」이 **둘 다 틀린 채로 그린**이 된다 —
	# 그래서 기준자 쪽도 독립으로 잰다(라운드로빈 순서·8칸 truncate·null 건너뜀).
	var a := _mk_ring(G_RADIATE, 3)
	var b := _mk_ring(G_GATHER, 3)
	_check(_same_ring(_board.flatten_bands([a, b]), [1, 1, 1, 0, 0, 0, -1, -1]),
		"발산3+응집3 → [1,1,1,0,0,0,-1,-1] (실제 %s)" % str(_board.flatten_bands([a, b])))
	_check(_same_ring(_board.flatten_bands([b, a]), [0, 0, 0, 1, 1, 1, -1, -1]),
		"밴드 순서가 배치를 바꾼다 (응집 먼저 → %s)" % str(_board.flatten_bands([b, a])))
	var big: Array = _board.flatten_bands([_mk_ring(G_RADIATE, 5), _mk_ring(G_GATHER, 5)])
	_check(big.size() == SLOTS and _same_ring(big, [1, 1, 1, 1, 1, 0, 0, 0]),
		"8칸 상한 truncate (5+5=10 → 앞 8칸 %s)" % str(big))
	_check(_same_ring(_board.flatten_bands([a, null]), [1, 1, 1, -1, -1, -1, -1, -1]),
		"빈 밴드(null)는 **건너뛴다** — layer_rings와 정반대라 둘을 헷갈리면 안 된다")


# ── [3] _as_layers 정규화 (옛 8칸 한 겹 흡수) ──
func _test_as_layers(system) -> void:
	print("[3] _as_layers: 옛 8칸 한 겹 → 층 1개로 승격 · 층 배열은 그대로")
	var flat := _all(G_RADIATE)
	var norm: Array = system._as_layers(flat)
	_check(norm.size() == 1 and norm[0] is Array, "8칸 한 겹 → 층 1개")
	var already: Array = system._as_layers([_all(G_RADIATE), _all(G_GATHER)])
	_check(already.size() == 2, "이미 층 배열이면 그대로 (멱등)")
	_check(system._as_layers([]).is_empty(), "빈 배열은 빈 배열")


# ── [4] 🔴🔴 이 파일의 심장 — 순서가 결과를 바꾼다 ──
func _test_order_changes_result(system) -> void:
	print("[4] 🔴 폭발(확산(불)) ≠ 확산(폭발(불)) — 같은 재료, 순서만 다름")

	# ⓐ 안=확산 · 밖=폭발 → 3갈래를 **융합** → 큰 폭발 **하나**
	_clear(system)
	system._deploy_now([_ring({0: G_SPREAD, 1: G_SPREAD, 2: G_SPREAD}), _ring({0: G_EXPLODE})],
		FAR, 0.0, 1.0, 1.0, [0])
	await process_frame
	var merged: Array = _blasts()
	_check(merged.size() == 1, "폭발(확산(불)) = 융합해 폭발 1개 (실제 %d)" % merged.size())
	var merged_r := float(merged[0].radius_px) if merged.size() > 0 else 0.0

	# ⓑ 안=폭발 · 밖=확산 → 폭발 하나를 **복제** → 작은 폭발 **셋**
	_clear(system)
	system._deploy_now([_ring({0: G_EXPLODE}), _ring({0: G_SPREAD, 1: G_SPREAD, 2: G_SPREAD})],
		FAR, 0.0, 1.0, 1.0, [0])
	await process_frame
	var scattered: Array = _blasts()
	_check(scattered.size() == 3, "확산(폭발(불)) = 복제해 폭발 3개 (실제 %d)" % scattered.size())
	var scattered_r := float(scattered[0].radius_px) if scattered.size() > 0 else 0.0

	# 🔴 개수도 반경도 갈린다. 반경 비교는 balance에 **수치를 안 박고** 대소만 본다 —
	# 「안쪽이 넓게 퍼져 있을수록 크게 터진다」가 이 설계에서 순서를 눈에 보이게 만드는 자리다.
	_check(merged_r > scattered_r,
		"융합 폭발이 산개 폭발보다 크다 (융합 %.1f > 산개 %.1f)" % [merged_r, scattered_r])

		# 🔴 산개된 셋은 **같은 자리에 겹치지 않는다** (겹치면 한 발과 구분이 안 된다)
	if scattered.size() == 3:
		var d01: float = scattered[0].global_position.distance_to(scattered[1].global_position)
		_check(d01 > 1.0, "산개 폭발끼리 자리가 벌어진다 (실제 %.1fpx)" % d01)
	_clear(system)


# ── [5] 🔴 회귀: 층 1개 + 변형형 없음 = 옛 도안 그대로 나간다 ──
func _test_legacy_single_layer(system) -> void:
	print("[5] 🔴 회귀: 옛 도안(층 1개·전개형만)은 예전 그대로")
	_clear(system)
	system._deploy_now([_all(G_RADIATE)], FAR, 0.0, 1.0, 1.0, [0])
	await process_frame
	_check(_bolts(system).size() == 8, "발산 8칸 → 탄 8발 (실제 %d)" % _bolts(system).size())
	_check(_blasts().is_empty(), "변형형이 없으면 폭발은 안 생긴다 (실제 %d)" % _blasts().size())

	_clear(system)
	system._deploy_now([_ring({0: G_GATHER, 2: G_GATHER})], FAR, 0.0, 1.0, 1.0, [0])
	await process_frame
	_check(_pillars().size() == 1, "응집 2칸 → 기둥 1개 (실제 %d)" % _pillars().size())
	_check(_blasts().is_empty(), "응집만으로 폭발이 생기지 않는다")

	# 🔴 빈 진은 여전히 아무것도 안 나온다 (씨앗은 **변형형이 있을 때만** 생긴다)
	_clear(system)
	system._deploy_now([_all(GLYPH_NONE)], FAR, 0.0, 1.0, 1.0, [0])
	await process_frame
	_check(_bolts(system).is_empty() and _pillars().is_empty() and _blasts().is_empty(),
		"빈 진 = 전개 0 (씨앗이 새어 나오면 여기가 빨개진다)")
	_clear(system)


# ── [6] 씨앗 — 감쌀 게 없으면 문양이 **룬 자체**를 감싼다 ──
func _test_seed_when_nothing_to_wrap(system) -> void:
	print("[6] 감쌀 안쪽이 없으면 룬 씨앗을 감싼다 (설계: 문양의 대상 = 룬 또는 안쪽 뭉치)")
	# 확산만 = 씨앗 탄 1발을 3갈래로
	_clear(system)
	system._deploy_now([_ring({0: G_SPREAD, 1: G_SPREAD, 2: G_SPREAD})], FAR, 0.0, 1.0, 1.0, [0])
	await process_frame
	var fan: Array = _bolts(system)
	_check(fan.size() == 3, "확산×3만 → 씨앗이 3갈래로 (실제 %d)" % fan.size())
	_check(_blasts().is_empty(), "확산만으로는 폭발이 안 생긴다")

	# 폭발만 = 씨앗 1발을 융합해 폭발 1개
	_clear(system)
	system._deploy_now([_ring({0: G_EXPLODE})], FAR, 0.0, 1.0, 1.0, [0])
	await process_frame
	_check(_blasts().size() == 1, "폭발×1만 → 폭발 1개 (실제 %d)" % _blasts().size())

	# 🔴 세기 = 그 층에서 그 문양이 차지한 칸 수 (응집의 "많을수록 굵다"와 같은 결)
	_clear(system)
	system._deploy_now([_ring({0: G_SPREAD, 1: G_SPREAD, 2: G_SPREAD, 3: G_SPREAD, 4: G_SPREAD})],
		FAR, 0.0, 1.0, 1.0, [0])
	await process_frame
	_check(_bolts(system).size() == 5, "확산 5칸 → 5갈래 (칸 수 = 세기) (실제 %d)" % _bolts(system).size())
	_clear(system)


# ── [7] 🔴 조립 UI → 발사 계약 — 이 연결이 끊기면 M1이 게임에서 통째로 안 보인다 ──
func _test_panel_carries_layers() -> void:
	print("[7] 🔴 조립 UI(book)가 밴드를 rings **다겹**으로 싣는다")
	# 🔴 패널의 **공개 seam**(`set_assembly_state`)을 쓴다 — private(`_sel_jin`·`_bands`)을 직접
	# 더듬으면 리팩터 때 **조용히** 죽는다(`-s`는 에러가 나도 failures=0으로 OK를 찍는다).
	# 없는 메서드 호출은 `SCRIPT ERROR`로 grep에 잡힌다 — 그 차이가 이 선택의 전부다.
	var scene := load("res://src/drawing/ring_forge_panel.tscn") as PackedScene
	if scene == null:
		_check(false, "ring_forge_panel.tscn 로드 실패")
		return
	var panel = scene.instantiate()
	root.add_child(panel)
	await process_frame

	var bands: Array[StringName] = [&"gr_spread3", &"gr_explode1"]
	panel.set_assembly_state(&"jin_plain_g2", bands)
	var asm: Dictionary = panel.build_assembly()
	var rings: Array = asm.get("rings", [])

	_check(rings.size() == 2, "밴드 2개 → rings 층 2개 (실제 %d — 1이면 flatten으로 되돌아간 것)" % rings.size())
	if rings.size() == 2:
		_check(int(rings[0][0]) == G_SPREAD, "층0(안쪽) = 확산")
		_check(int(rings[1][0]) == G_EXPLODE, "층1(바깥) = 폭발")
	# 🔴 score를 안 실으면 손그림 위력이 조용히 사라진다
	_check(asm.has("score"), "발사 계약에 score가 실린다 (빠지면 기준 위력으로 나간다)")
	_check(StringName(asm.get("jin", &"")) == &"jin_plain_g2", "진 id가 실린다")

	# 🔴 HUD 슬롯 다이어그램이 **바깥 층 문양도 채워진 칸으로 본다**.
	# 이 판정이 `rings[0]`만 보면 2등급 진에서 층1 문양이 통째로 안 그려지는데, `open`은 합집합이라
	var d := RingDesign.from_assembly(asm, "층 테스트", 0.8)
	_check(d.is_slot_filled(0), "칸0(층0 확산·층1 폭발) = 채워짐")
	_check(d.is_slot_filled(2), "🔴 칸2는 **층0에만** 있다 — 층 전체를 봐야 참이 된다")
	_check(not d.is_slot_filled(7), "칸7은 어느 층에도 없다 = 빈칸")
	# 바깥 층에만 있는 칸 — `rings[0]`만 보는 회귀를 정확히 겨눈다
	var outer := RingDesign.from_assembly(
		{"rune": 0, "rings": [[-1, -1, -1, -1, -1, -1, -1, -1], [7, -1, -1, -1, -1, -1, -1, -1]],
		"open": [0]}, "바깥층만", 0.8)
	_check(outer.is_slot_filled(0),
		"🔴 **바깥 층에만** 놓인 문양도 채워진 칸이다 (rings[0]만 보면 여기가 빨개진다)")
	_check(outer.filled_count() == 1, "바깥 층만 있어도 요약이 1을 센다")

	panel.queue_free()
	await process_frame


# ── [8] 🔴 위력 배분(mult) — 이걸 안 재면 balance를 0으로 만들어도 전 스위트가 그린이다 ──
func _test_damage_distribution(system) -> void:
	print("[8] 🔴 변형형이 피해를 실제로 배분한다 (mult가 스폰 노드까지 도달)")
	# ⚠ **수치를 하드코딩하지 않는다** — 씨앗 1발 대비 **관계**로 잰다(이 파일의 규율).
	_clear(system)
	system._deploy_now([_ring({0: G_RADIATE})], FAR, 0.0, 1.0, 1.0, [0])
	await process_frame
	var base_bolts: Array = _bolts(system)
	var base_dmg := float(base_bolts[0].damage) if not base_bolts.is_empty() else 0.0
	_check(base_dmg > 0.0, "기준: 발산 1칸 탄의 피해 > 0 (실제 %.2f)" % base_dmg)

	# 확산 3갈래 — 갈래마다 세기는 줄되(단독보다 약함) **합은 커야** 그릴 이유가 생긴다
	_clear(system)
	system._deploy_now([_ring({0: G_SPREAD, 1: G_SPREAD, 2: G_SPREAD})], FAR, 0.0, 1.0, 1.0, [0])
	await process_frame
	var fan: Array = _bolts(system)
	var total := 0.0
	for b in fan:
		total += float(b.damage)
	if not fan.is_empty():
		var each := float(fan[0].damage)
		_check(each < base_dmg, "확산 갈래 하나는 단독보다 약하다 (%.2f < %.2f)" % [each, base_dmg])
		_check(total > base_dmg, "🔴 그래도 **합은 더 세다** — 아니면 확산을 그릴 이유가 없다 (%.2f > %.2f)"
			% [total, base_dmg])
	_clear(system)

	# 폭발 융합 — 안쪽 세기 **합**을 물려받는다(merge_mult가 0이면 여기서 잡힌다)
	system._deploy_now([_ring({0: G_SPREAD, 1: G_SPREAD, 2: G_SPREAD}), _ring({0: G_EXPLODE})],
		FAR, 0.0, 1.0, 1.0, [0])
	await process_frame
	var bl: Array = _blasts()
	_check(bl.size() == 1 and float(bl[0].damage) > 0.0,
		"융합 폭발이 피해를 물려받는다 (실제 %.2f)" % (float(bl[0].damage) if bl.size() > 0 else 0.0))
	_clear(system)


# ── [9] 🔴 순서를 **사람에게 보여 주는 문자열** (Tab 마법진 탭) ──
## 심장이 "순서가 결과를 바꾼다"인데, 플레이어가 그 순서를 확인하는 유일한 통로가 이 수식이다.
## 발사만 맞고 표시가 뒤집혀 있으면 사용자는 **자기 도안을 반대로 이해한 채 조립한다**.
func _test_formula_text() -> void:
	print("[9] 🔴 마법진 탭 수식 — 안→밖 감쌈이 글로도 뒤집히지 않는다")
	var tab = load("res://src/hud/tab_panel.gd")
	var inner_spread: Array = [[{"code": G_SPREAD, "count": 3}], [{"code": G_EXPLODE, "count": 1}]]
	var inner_explode: Array = [[{"code": G_EXPLODE, "count": 1}], [{"code": G_SPREAD, "count": 3}]]
	var f1: String = tab.spell_formula(inner_spread, "불")
	var f2: String = tab.spell_formula(inner_explode, "불")
	_check(f1 == "폭발(확산(불))", "층0 확산·층1 폭발 → 폭발(확산(불)) (실제 %s)" % f1)
	_check(f2 == "확산(폭발(불))", "층0 폭발·층1 확산 → 확산(폭발(불)) (실제 %s)" % f2)
	_check(f1 != f2, "🔴 순서가 다르면 수식도 다르다 (발사만 갈리고 표시가 같으면 무용지물)")
	# 빈 층은 감싸지 않는다 · 문양이 없으면 룬 이름만 (옛 도안·빈 진)
	_check(tab.spell_formula([[], [{"code": G_EXPLODE, "count": 1}]], "물") == "폭발(물)",
		"빈 층은 괄호를 안 만든다")
	_check(tab.spell_formula([], "불") == "불", "층이 없으면 룬 이름만")
	_check(tab.spell_formula([[]], "불") == "불", "빈 층뿐이어도 룬 이름만")
	# 🔴 실제 도안에서 뽑은 summary로도 같은 결과가 나오나 (core→UI 연결이 끊기면 여기가 잡는다)
	var d := RingDesign.from_assembly(
		{"rune": 0, "jin": &"jin_plain_g2",
		"rings": [[G_SPREAD, G_SPREAD, G_SPREAD, -1, -1, -1, -1, -1],
			[G_EXPLODE, -1, -1, -1, -1, -1, -1, -1]], "open": [0, 1, 2]}, "실도안", 1.0)
	var f3: String = tab.spell_formula(d.layer_summary(), "불")
	_check(f3 == "폭발(확산(불))", "실제 도안 layer_summary → 같은 수식 (실제 %s)" % f3)
	_check(d.has_modifier_glyph(_db.modifier_codes()), "변형형 판정 = 참 (위력이 「갈래당」으로 표기된다)")
	# 옛 한 겹 도안 — 괄호가 한 겹만 (저장 무회귀가 표시까지 이어지나)
	var old_d := RingDesign.from_assembly(
		{"rune": 0, "rings": [G_RADIATE, G_RADIATE, -1, -1, -1, -1, -1, -1], "open": [0, 1]},
		"옛 도안", 1.0)
	_check(tab.spell_formula(old_d.layer_summary(), "불") == "발산(불)",
		"옛 8칸 한 겹 → 괄호 한 겹 (층 1개로 승격)")
	_check(not old_d.has_modifier_glyph(_db.modifier_codes()), "옛 도안엔 변형형이 없다 = 그냥 「위력」 표기")


# ─────────────────────────── 헬퍼 ───────────────────────────

## {칸: 코드} → 8칸 배열 (나머지는 빈칸)
func _ring(fills: Dictionary) -> Array:
	var r: Array = []
	for k in SLOTS:
		r.append(int(fills.get(k, GLYPH_NONE)))
	return r


## motif·count만 있는 in-memory GlyphRingDef (flatten 계약 검증용).
func _mk_ring(motif: int, count: int) -> GlyphRingDef:
	var gr := GlyphRingDef.new()
	gr.motif = motif
	gr.count = count
	return gr


func _all(g: int) -> Array:
	var r: Array = []
	for k in SLOTS:
		r.append(g)
	return r


func _same_ring(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true


func _bolts(system) -> Array:
	# 캐리어를 뺀 순수 탄 = projectile.gd 인스턴스 (파일명으로 구분 — test_ring_spell_auto와 같은 규약)
	var out := []
	for c in system.get_children():
		if c.is_in_group("player_projectiles") and c.get_script() != null \
				and (c.get_script().resource_path as String).ends_with("projectile.gd"):
			out.append(c)
	return out


func _pillars() -> Array:
	return _alive("pillars")


func _blasts() -> Array:
	return _alive("blasts")


func _alive(group: String) -> Array:
	var out := []
	for n in get_nodes_in_group(group):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


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
