extends SceneTree
## 세68 조립→탁본 슬라이스 자동 검증 — 헤드리스:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_assembly_slice_auto.gd
## 전 항목 통과 시 "TEST_ASSEMBLY_SLICE_OK" 출력 후 종료 코드 0.
##
## 검증 대상:
##   • Db.all_glyph_rings() 정확히 2종 (.tres 파싱 침묵사 그물 — 세50).
##   • RingBoard.compose_guide = 진 윤곽 + 룬(중심) + 밴드별 문양-고리 클러스터가 다 들어간다.
##   • RingBoard.flatten_bands = 밴드(motif×count) → 8칸 링 (순서 채움·상한 truncate).
##   • 통째 채점: 합성 가이드 위로 궤적 태워 coverage>0 · combined_total>0.
##   • 플래튼 발사: flatten 8칸을 실제 전개 → motif대로 탄/기둥 스폰 (radiate=탄·gather=기둥).
##   • 슬라이스 패널: 해금 목록 필터 · build_assembly가 score를 싣고 rings=flatten.
##
## 🔴 헤드리스가 못 잡음(리드 실게임 MCP): 화면 덮는 패널 좌클릭 발사 도달(mouse_filter·세25)·
##   합성 가이드 렌더·통째 트레이스 손맛. -s는 런타임 에러 나도 OK 찍음 → grep SCRIPT ERROR도.
##
## 주의: -s는 오토로드 등록 전에 컴파일 → 오토로드 식별자·모듈 preload 금지(load 지연). class_name
##   전역(GlyphRingDef.new 등)은 임포트 후라 런타임에 유효(test_ring_spell의 JinDef.new 선례).

const GLYPH_NONE := -1
const G_GATHER := 0
const G_RADIATE := 1

var failures: int = 0
var _db = null
var _RingBoard = null
var _dummy_scene: PackedScene = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_ASSEMBLY_SLICE_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame   # 오토로드 준비 대기

	_db = root.get_node("/root/Db")
	_RingBoard = load("res://src/drawing/ring_board.gd")
	_dummy_scene = load("res://src/spell/dummy_target.tscn") as PackedScene

	_test_db_load()
	_test_compose_guide()
	_test_flatten_bands()
	await _test_combined_scoring()
	await _test_flatten_fire()
	await _test_panel()

	if failures == 0:
		print("TEST_ASSEMBLY_SLICE_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_ASSEMBLY_SLICE_FAIL — %d개 실패" % failures)
		quit(1)


# ── [0] Db 로드 (파싱 침묵사 그물) ──
func _test_db_load() -> void:
	print("[0] Db.all_glyph_rings() 정확히 2종")
	var rings: Array = _db.all_glyph_rings()
	_check(rings.size() == 2, "문양-고리 2종 로드 (실제 %d — .tres 파싱 실패면 줄어든다)" % rings.size())
	var r5 = _db.get_glyph_ring(&"gr_radiate5")
	var g3 = _db.get_glyph_ring(&"gr_gather3")
	_check(r5 != null and int(r5.motif) == G_RADIATE and int(r5.count) == 5,
		"gr_radiate5 = 발산×5")
	_check(g3 != null and int(g3.motif) == G_GATHER and int(g3.count) == 3,
		"gr_gather3 = 응집×3")
	# sort 순서 — all_glyph_rings가 sort로 정렬하는지
	_check(rings[0].sort <= rings[1].sort, "sort 오름차순 정렬")


# ── [1] compose_guide = 진 + 룬 + 밴드 클러스터 ──
func _test_compose_guide() -> void:
	print("[1] compose_guide = 진 윤곽 + 룬 + 밴드별 문양-고리")
	var ctr := Vector2(200, 200)
	var ro := 180.0
	var r5 = _db.get_glyph_ring(&"gr_radiate5")
	var g3 = _db.get_glyph_ring(&"gr_gather3")
	var guide: PackedVector2Array = _RingBoard.compose_guide(
		int(Enums.JinShape.CIRCLE), 0, [r5, g3], ctr, ro)
	_check(guide.size() > 40, "합성 가이드 점 다수 (실제 %d)" % guide.size())

	# 진 윤곽 — 반지름 ≈ ro인 점이 있다
	_check(_has_at_radius(guide, ctr, ro, ro * 0.06), "진 윤곽(반경 ~ro) 점 존재")
	# 룬(중심) — 반경 ro*RUNE_GUIDE_FRAC(0.18)≈32 근처 점
	_check(_has_at_radius(guide, ctr, ro * 0.18, ro * 0.10), "룬(중심) 클러스터 존재")
	# 밴드 0 (0.42R≈75.6) · 밴드 1 (0.68R≈122.4) — 낱개 모티프가 그 반경대에 깔린다
	_check(_has_at_radius(guide, ctr, ro * 0.42, ro * MOTIF_FRAC_TOL()),
		"안쪽 밴드(0.42R) 클러스터 존재")
	_check(_has_at_radius(guide, ctr, ro * 0.68, ro * MOTIF_FRAC_TOL()),
		"바깥 밴드(0.68R) 클러스터 존재")

	# 🔴 빈 밴드는 점을 안 더한다 — 밴드 하나만 끼운 것 vs 둘 끼운 것의 점 수 비교
	var one: PackedVector2Array = _RingBoard.compose_guide(
		int(Enums.JinShape.CIRCLE), 0, [r5, null], ctr, ro)
	_check(one.size() < guide.size(),
		"빈 밴드는 점을 안 더한다 (한 밴드 %d < 두 밴드 %d)" % [one.size(), guide.size()])


# 모티프 크기(MOTIF_SIZE_FRAC 0.14 × band_r)만큼 반경이 퍼지므로 넉넉한 tolerance.
func MOTIF_FRAC_TOL() -> float:
	return 0.16


# ── [2] flatten_bands ──
func _test_flatten_bands() -> void:
	print("[2] flatten_bands = 밴드(motif×count) → 8칸 링")
	var r5 = _db.get_glyph_ring(&"gr_radiate5")
	var g3 = _db.get_glyph_ring(&"gr_gather3")

	# 실데이터: 발산×5 + 응집×3 = 정확히 8칸 채움
	var f1: Array = _RingBoard.flatten_bands([r5, g3])
	_check(_eq(f1, [1, 1, 1, 1, 1, 0, 0, 0]),
		"발산5+응집3 → [1,1,1,1,1,0,0,0] (실제 %s)" % str(f1))

	# 합성 소형(count 3+3) — 설계 예시 [1,1,1,0,0,0,-1,-1] 재현
	var a := _mk_ring(1, 3)
	var b := _mk_ring(0, 3)
	var f2: Array = _RingBoard.flatten_bands([a, b])
	_check(_eq(f2, [1, 1, 1, 0, 0, 0, -1, -1]),
		"발산3+응집3 → [1,1,1,0,0,0,-1,-1] (실제 %s)" % str(f2))

	# 순서가 배치를 바꾼다 — 응집 먼저면 [0,0,0,1,1,1,-1,-1]
	var f3: Array = _RingBoard.flatten_bands([b, a])
	_check(_eq(f3, [0, 0, 0, 1, 1, 1, -1, -1]),
		"밴드 순서가 배치를 바꾼다 (응집 먼저 → %s)" % str(f3))

	# 상한 truncate — 넘치면 버린다 (count 5 + 5 = 10 → 앞 8칸만)
	var big := _mk_ring(1, 5)
	var big2 := _mk_ring(0, 5)
	var f4: Array = _RingBoard.flatten_bands([big, big2])
	_check(f4.size() == 8 and _eq(f4, [1, 1, 1, 1, 1, 0, 0, 0]),
		"8칸 상한 truncate (5+5=10 → 앞 8칸 %s)" % str(f4))

	# 빈 밴드(null)는 건너뛴다
	var f5: Array = _RingBoard.flatten_bands([a, null])
	_check(_eq(f5, [1, 1, 1, -1, -1, -1, -1, -1]),
		"빈 밴드(null) 건너뜀 (%s)" % str(f5))


# ── [3] 통째 채점 ──
func _test_combined_scoring() -> void:
	print("[3] 합성 가이드 통째 트레이스 → coverage>0 · combined_total>0")
	var board = _RingBoard.new()
	root.add_child(board)
	board.size = Vector2(400, 400)
	await process_frame
	var ctr: Vector2 = board.size * 0.5
	var ro: float = minf(board.size.x, board.size.y) * 0.44
	var r5 = _db.get_glyph_ring(&"gr_radiate5")
	var g3 = _db.get_glyph_ring(&"gr_gather3")
	var guide: PackedVector2Array = _RingBoard.compose_guide(
		int(Enums.JinShape.CIRCLE), 0, [r5, g3], ctr, ro)
	board.enter_combined_trace(guide)

	var gp: PackedVector2Array = board.guide_points()
	_check(gp.size() == guide.size(), "보드가 합성 가이드를 받았다 (%d점)" % gp.size())
	# 가이드 위를 그대로 따라 긋는다 (헤드리스는 손맛 못 잼 — coverage 파이프라인만 증명)
	board.begin_stroke()
	for p in gp:
		board.trace_stroke(p)
	_check(board.coverage() > 0.0, "완성도 > 0 (실제 %.2f)" % board.coverage())
	_check(board.combined_total() > 0.0, "통째 점수 > 0 (실제 %.3f)" % board.combined_total())
	# 아무것도 안 그은 새 보드는 0 — 검출력 대조
	var empty = _RingBoard.new()
	root.add_child(empty)
	empty.size = Vector2(400, 400)
	await process_frame
	empty.enter_combined_trace(guide)
	_check(is_zero_approx(empty.combined_total()), "안 그은 보드는 통째 점수 0 (검출력 대조)")
	board.queue_free()
	empty.queue_free()


# ── [4] 플래튼 발사 (motif → 전개) ──
func _test_flatten_fire() -> void:
	print("[4] 플래튼 8칸 발사 → motif대로 전개 (발산=탄·응집=기둥)")
	var system_scene := load("res://src/spell/ring_spell_system.tscn") as PackedScene
	var system = system_scene.instantiate()
	root.add_child(system)
	await process_frame

	var r5 = _db.get_glyph_ring(&"gr_radiate5")
	var g3 = _db.get_glyph_ring(&"gr_gather3")
	var ring: Array = _RingBoard.flatten_bands([r5, g3])   # [1×5, 0×3]
	# 빈 곳에서 전개 — 발산 5 → 탄 5, 응집 3 → 기둥 1
	system._deploy_now(ring, Vector2(5000, 5000), 0.0, 1.0, 1.0, 0)
	await process_frame
	_check(_bolts(system).size() == 5,
		"발산5 → 불탄 5발 (실제 %d)" % _bolts(system).size())
	_check(_pillars().size() == 1, "응집3 → 기둥 1개 (실제 %d)" % _pillars().size())
	_clear(system)

	# 실제 적 명중 — 발사 계약 전체(캐리어 비행 → 몸 히트)
	var dummy = _dummy_scene.instantiate()
	root.add_child(dummy)
	dummy.global_position = Vector2(140, 0)
	var bus = root.get_node("/root/EventBus")
	bus.ring_cast_requested.emit(
		{"rings": [ring], "rune": 0, "jin": &"jin_single", "score": 1.0,
		"ink": &"", "size": 1.0}, Vector2.ZERO, Vector2(1, 0))
	var frames := 0
	while dummy.hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	_check(not dummy.hits.is_empty(), "맺은 진이 날아가 허수아비를 때린다 (%d 프레임)" % frames)
	dummy.queue_free()
	_clear(system)
	system.queue_free()


# ── [5] 슬라이스 패널 ──
func _test_panel() -> void:
	print("[5] 슬라이스 패널 — 해금 필터 · build_assembly(score·rings)")
	var gs = root.get_node("/root/GameState")
	gs.codex[&"gr_radiate5"] = true
	gs.codex[&"gr_gather3"] = true
	var panel_scene := load("res://src/drawing/assembly_slice_panel.tscn") as PackedScene
	var panel = panel_scene.instantiate()
	root.add_child(panel)
	await process_frame

	var avail: Array = panel.available_rings()
	_check(avail.size() == 2, "해금된 문양-고리 2종 노출 (실제 %d)" % avail.size())

	# 미해금 필터 — 하나를 잠그면 목록에서 빠진다
	gs.codex[&"gr_gather3"] = false
	_check(panel.available_rings().size() == 1, "미해금은 목록에서 빠진다")
	gs.codex[&"gr_gather3"] = true

	# 소켓에 끼우고 build_assembly — flatten이 실리고 score 키가 있다
	panel.socket_ring(0, &"gr_radiate5")
	panel.socket_ring(1, &"gr_gather3")
	var defs: Array = panel.band_defs()
	_check(defs.size() == 2 and defs[0] != null and defs[1] != null,
		"두 밴드에 고리가 끼워졌다")
	var asm: Dictionary = panel.build_assembly()
	_check(asm.has("score"), "🔴 build_assembly가 score를 싣는다 (세26 — 없으면 조용히 기준 위력)")
	_check(asm.has("rings") and (asm["rings"] as Array).size() == 1, "rings 8칸 배열 실림")
	var flat: Array = asm["rings"][0]
	_check(_eq(flat, [1, 1, 1, 1, 1, 0, 0, 0]),
		"패널 flatten = 발산5+응집3 (실제 %s)" % str(flat))
	_check(int(asm.get("rune", -1)) == 0 and StringName(asm.get("jin", &"")) == &"jin_single",
		"rune=불 · jin=jin_single 실림")

	# 🔴 미달 거부는 침묵이 아니다 (세71 — 세25 「맺었는데 안 나감」 계약이 구 책→슬라이스로 이관).
	# 통째 트레이스를 안 했으니 점수 0 = 미달 → try_inject는 committed를 안 쏘고 false를 돌려준다
	# (거부 사유는 패널 내부 notice가 화면에 띄운다 — base는 이 무발신에 기대 빈 슬롯을 안 만든다).
	# 뮤테이션: try_inject의 is_stable 가드를 지우면 committed가 새어 이 검사가 빨개진다.
	var committed_got := []
	panel.committed.connect(func(_a: Dictionary) -> void: committed_got.append(1))
	var injected: bool = panel.try_inject()
	_check(not injected and committed_got.is_empty(),
		"미달(안 그림·점수 0)은 맺히지 않는다 — try_inject false·committed 무발신 (침묵 거부 금지)")
	panel.queue_free()


# ─────────────────────────── 헬퍼 ───────────────────────────

## 중심에서 반경 r ± tol 안에 점이 하나라도 있나.
func _has_at_radius(pts: PackedVector2Array, ctr: Vector2, r: float, tol: float) -> bool:
	for p in pts:
		if absf(p.distance_to(ctr) - r) <= tol:
			return true
	return false


## motif·count만 있는 in-memory GlyphRingDef (합성 예시·상한 검증용).
func _mk_ring(motif: int, count: int) -> GlyphRingDef:
	var gr := GlyphRingDef.new()
	gr.motif = motif
	gr.count = count
	return gr


func _eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true


func _bolts(system) -> Array:
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
