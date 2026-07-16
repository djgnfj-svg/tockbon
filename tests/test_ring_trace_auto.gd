extends SceneTree
## 손그림 탁본(자동추적 + 완성도·정밀도 점수) 자동 검증 (세션 14b) — 헤드리스 실행:
##   ./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_trace_auto.gd
## 전 항목 통과 시 "TEST_RING_TRACE_OK" 출력 후 종료 코드 0.
##
## 검증 대상: ring_board가 숨은 선(가이드)을 세우고, 문지르면 먹선이 선에 붙어 드러나며(자동추적),
##   완성도(드러낸 비율)·정밀도(선에 붙은 정도)로 점수를 매긴다. [다음](advance)으로 수동 진행,
##   다 그리면 분석 리포트. 커버리지 자동확정 아님 — 못 그려도 넘어가되 점수가 낮다.
##   세션 15: 문양 칸 자유 편집(select_slot 전환 시 자동 잠금·재편집 교체)·문양 개별 크기(칸마다 휠 스케일).
##
## 주의: -s 모드는 오토로드보다 먼저 컴파일 — 오토로드 식별자·모듈 preload 금지. 첫 프레임 후 load().

const G_GATHER := 0
const G_RADIATE := 1
const GLYPH_NONE := -1

var failures: int = 0
var _BoardScript = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		print("TEST_RING_TRACE_TIMEOUT — 15초 초과")
		quit(1))
	await process_frame

	_BoardScript = load("res://src/drawing/ring_board.gd")

	_test_exact_trace_high_score()
	_test_sloppy_lower_accuracy()
	_test_partial_lower_coverage()
	_test_full_flow_and_analysis()
	_test_empty_jin_finishes_after_rune()
	_test_glyph_free_edit_and_relock()
	_test_glyph_per_slot_scale()
	_test_far_click_does_not_steal_slot()

	if failures == 0:
		print("TEST_RING_TRACE_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_RING_TRACE_FAIL — %d개 실패" % failures)
		quit(1)


func _make_board():
	var b = _BoardScript.new()
	b.size = Vector2(268, 268)
	root.add_child(b)
	b.call(&"clear_all")
	return b


## 지금 가이드 위를 정확히 문지른다 (dev=0 → 정밀도 최대).
func _rub_exact(b) -> void:
	b.call(&"begin_stroke")
	for p in b.call(&"guide_points"):
		b.call(&"trace_stroke", p)


func _stage(b) -> int:
	return int(b.call(&"stage"))


## 칸 k에 놓인 문양 코드. 🔴 **내부 필드(_slots)를 더듬지 않는다** — 세션 22 분할 때 그 필드가
## ring_assembly로 옮겨가면서 이 테스트가 조용히 깨졌었다(런타임 에러로 중단됐는데 failures=0이라
## "OK"를 찍었다). 발사 계약(assembly)으로 본다.
func _glyph_at(b, k: int) -> int:
	return int((b.call(&"get_assembly") as Dictionary).rings[0][k])


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  ✗ ", msg)


# ── ① 정확히 문지르면 완성도·정밀도·점수가 높다 ──
func _test_exact_trace_high_score() -> void:
	var b = _make_board()
	_check(bool(b.call(&"is_tracing")), "시작 시 진 가이드가 서 있어야")
	_rub_exact(b)
	_check(float(b.call(&"coverage")) > 0.95, "정확히 문지르면 완성도≈1")
	_check(float(b.call(&"accuracy")) > 0.95, "선 위를 정확히 → 정밀도≈1")
	_check(float(b.call(&"piece_score")) > 0.9, "점수 높음")
	b.queue_free()


# ── ② 선에서 벗어나 문지르면 완성도는 높아도 정밀도가 낮다 ──
func _test_sloppy_lower_accuracy() -> void:
	var b = _make_board()
	var ctr = Vector2(134, 134)   # size*0.5
	b.call(&"begin_stroke")
	# 각 가이드 점을 중심 쪽으로 조금 당겨(반경 이탈) 문지른다 — 붙긴 하되 어긋남
	for p in b.call(&"guide_points"):
		var pulled = p + (ctr - p).normalized() * 7.0   # 약 0.5*snap 만큼 안쪽
		b.call(&"trace_stroke", pulled)
	_check(float(b.call(&"coverage")) > 0.9, "어긋나도 근처면 완성도는 높다")
	_check(float(b.call(&"accuracy")) < 0.8, "선에서 벗어나면 정밀도 낮다")
	_check(float(b.call(&"piece_score")) < float(0.95), "점수도 정확한 경우보다 낮다")
	b.queue_free()


# ── ③ 일부만 문지르면 완성도가 낮다 (하지만 [다음]은 수동이라 넘길 수 있다) ──
func _test_partial_lower_coverage() -> void:
	var b = _make_board()
	var pts = b.call(&"guide_points")
	b.call(&"begin_stroke")
	for i in mini(pts.size() / 4, pts.size()):
		b.call(&"trace_stroke", pts[i])
	_check(float(b.call(&"coverage")) < 0.5, "일부만 문지르면 완성도 낮다")
	_check(_stage(b) == b.STAGE_JIN, "자동 확정 없음 — 아직 진 단계")
	# 수동 진행은 여전히 가능(점수만 낮게 기록)
	_check(String(b.call(&"advance")) == "advanced", "적게 그려도 [다음] 가능")
	_check(bool(b.call(&"has_jin")), "진 잠김")
	b.queue_free()


# ── ④ 진→룬→문양 전 흐름 + 분석 리포트 ──
func _test_full_flow_and_analysis() -> void:
	var b = _make_board()
	b.call(&"set_active_glyph", G_RADIATE)
	# 진
	_rub_exact(b)
	_check(String(b.call(&"advance")) == "advanced", "진 다음")
	_check(_stage(b) == b.STAGE_RUNE, "룬 단계")
	# 룬
	_rub_exact(b)
	_check(String(b.call(&"advance")) == "advanced", "룬 다음")
	_check(_stage(b) == b.STAGE_GLYPH, "문양 단계")
	# 문양 칸들 (기본 2방 = 2칸). 마지막 칸 advance는 "finished"
	var open = b.call(&"get_open")
	var last_result := ""
	for i in open.size():
		_rub_exact(b)
		last_result = String(b.call(&"advance"))
	_check(last_result == "finished", "마지막 문양 칸 다음 = 완성")
	_check(int(b.call(&"filled_count")) == open.size(), "열린 칸 다 채움")

	var a = b.call(&"get_analysis")
	_check(a.has("jin") and a.jin != null, "분석에 진 점수")
	_check(a.has("rune") and a.rune != null, "분석에 룬 점수")
	_check((a.get("glyphs", []) as Array).size() == open.size(), "분석에 문양 칸별 점수")
	_check(float(a.get("total", 0.0)) > 0.9, "정확히 그렸으니 종합 점수 높음")
	_check(String(a.get("grade", "")) != "", "등급 부여됨")
	b.queue_free()


# ── ⑤ 빈 진(문양본 없음): 룬까지 그리면 바로 완성된다 ──
func _test_empty_jin_finishes_after_rune() -> void:
	var b = _make_board()
	b.call(&"set_template", [])   # 열린 칸 없음 = 빈 진
	_rub_exact(b)
	b.call(&"advance")            # 진
	_rub_exact(b)
	var r = String(b.call(&"advance"))   # 룬 → 문양 없음 → 완성
	_check(r == "finished", "빈 진은 룬 다음 바로 완성")
	_check(bool(b.call(&"can_commit")), "진·룬 그렸으면 맺기 가능")
	b.queue_free()


## 진→룬 그려 문양 단계에 도달한다 (기본 문양본 = 2방 [0,2]).
func _reach_glyph_stage(b) -> void:
	_rub_exact(b)
	b.call(&"advance")   # 진
	_rub_exact(b)
	b.call(&"advance")   # 룬 → 문양 단계


# ── ⑥ 문양 칸 자유 편집(세션 15): 칸 전환 시 이전 칸 자동 잠금 + 재편집이 교체(중복 아님) ──
func _test_glyph_free_edit_and_relock() -> void:
	var b = _make_board()
	_reach_glyph_stage(b)
	_check(int(b.call(&"trace_slot")) == 0, "문양 단계 첫 칸=0")
	# slot0 = 발산(1)
	b.call(&"set_active_glyph", G_RADIATE)
	_rub_exact(b)
	b.call(&"select_slot", 2)             # 다른 칸으로 전환 → slot0 자동 잠금
	_check(_glyph_at(b, 0) == G_RADIATE, "칸 전환 시 이전 칸 자동 잠금")
	_check(int(b.call(&"trace_slot")) == 2, "고른 칸으로 전환")
	# slot2 = 응집(0)
	b.call(&"set_active_glyph", G_GATHER)
	_rub_exact(b)
	b.call(&"select_slot", 0)             # slot2 자동 잠금 + slot0 재선택(재편집)
	_check(_glyph_at(b, 2) == G_GATHER, "두번째 칸도 잠김")
	var locked_a := int(b.call(&"locked_count"))
	# slot0 재편집 — 발산→응집으로 문양 교체
	b.call(&"set_active_glyph", G_GATHER)
	_rub_exact(b)
	b.call(&"advance")
	_check(_glyph_at(b, 0) == G_GATHER, "이미 채운 칸을 다시 골라 문양 교체")
	_check(int(b.call(&"locked_count")) == locked_a, "재편집은 먹선 교체(중복 추가 아님)")
	b.queue_free()


# ── ⑦ 문양 개별 크기(세션 15): 칸마다 휠 스케일, 서로 독립, 상·하한 클램프 ──
func _test_glyph_per_slot_scale() -> void:
	var b = _make_board()
	_reach_glyph_stage(b)
	_check(is_equal_approx(float(b.call(&"_glyph_scale_of", 0)), 1.0), "기본 문양 크기 1.0")
	b.call(&"_resize_current", 0.06)      # 휠 업 (현재 칸=0)
	_check(float(b.call(&"_glyph_scale_of", 0)) > 1.0, "휠 업 → 그 칸만 커진다")
	_check(is_equal_approx(float(b.call(&"_glyph_scale_of", 2)), 1.0), "다른 칸 크기는 독립")
	for i in 60:
		b.call(&"_resize_current", 0.06)
	_check(float(b.call(&"_glyph_scale_of", 0)) <= float(b.GLYPH_SCALE_MAX) + 0.001, "상한 클램프")
	for i in 80:
		b.call(&"_resize_current", -0.06)
	_check(float(b.call(&"_glyph_scale_of", 0)) >= float(b.GLYPH_SCALE_MIN) - 0.001, "하한 클램프")
	b.queue_free()


# ── ⑧ 🔴 I3 회귀 (세션 22): 칸에서 먼 곳을 클릭해도 **현재 칸을 뺏기지 않는다** ──
## 버그: _nearest_open_slot에 거리 컷오프가 없어서 판 아무 데나 클릭해도 최근접 열린 칸이 잡혔고,
## select_slot이 현재 칸 coverage > COMMIT_COVER면 **자동 확정**해 버렸다 →
## **칸 0을 그리다 획을 칸 2 쪽에 조금 가깝게 시작하면 칸 0이 멋대로 확정되고 넘어갔다.**
## *"마음에 들 때까지 다시 그린다"* 설계와 정면 충돌.
func _test_far_click_does_not_steal_slot() -> void:
	var b = _make_board()
	_reach_glyph_stage(b)                  # 기본 문양본 2방 [0,2], 현재 칸 = 0
	_check(int(b.call(&"trace_slot")) == 0, "현재 칸 = 0")

	# 칸 0을 자동확정 문턱 위로 그려 둔다 (버그의 방아쇠 조건)
	_rub_exact(b)
	_check(float(b.call(&"coverage")) > float(b.COMMIT_COVER), "칸 0을 문턱 위로 그렸다")

	# 두 칸 모두에서 먼 지점 — 칸 2 쪽으로 치우쳤지만 어느 칸에도 안 붙었다
	var far := Vector2(150, 134)           # 판 중앙 근처 (칸 2가 최근접이나 한참 멀다)
	_check(int(b.call(&"_nearest_open_slot", far)) == -1, "칸에서 멀면 -1 (컷오프)")

	# 실제 입력 경로로도 확인 — 먼 곳 클릭이 칸 0을 확정하면 안 된다
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = far
	b.call(&"_gui_input", ev)
	_check(int(b.call(&"trace_slot")) == 0, "먼 곳 클릭 — 현재 칸(0)을 유지한다")
	_check(_glyph_at(b, 0) == GLYPH_NONE, "먼 곳 클릭 — 칸 0이 멋대로 확정되지 않는다")

	# 반대: 칸 위를 클릭하면 정상적으로 그 칸으로 넘어간다 (컷오프가 기능을 죽이지 않았다)
	var on_slot2: Vector2 = b.call(&"_slot_pos", 2)
	_check(int(b.call(&"_nearest_open_slot", on_slot2)) == 2, "칸 위를 클릭하면 그 칸이 잡힌다")
	b.queue_free()
