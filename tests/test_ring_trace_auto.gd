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
	_test_accuracy_has_teeth()
	_test_gross_miss_is_punished_not_erased()
	_test_pen_correction_pulls_strokes()
	_test_pen_grades_registered()
	_test_strokes_accumulate()
	_test_clear_stroke_wipes()

	if failures == 0:
		print("TEST_RING_TRACE_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_RING_TRACE_FAIL — %d개 실패" % failures)
		quit(1)


# ── 🔴 ⑨ 정밀도에 이빨이 있다 (세션 23, 사용자 확정: "벗어난 만큼 벌한다") ──
# 판 268px → 기준 반지름 ≈118px · 판정 반경(ACC_TOL 0.08) ≈ 9.4px.
# ⚠ 기존 ②(_test_sloppy_lower_accuracy)는 `정밀도 < 0.8`만 봐서 **옛 관대한 판정(0.20)도
# 통과했다** — 검출력이 없었다. 여기서 관대함으로 되돌아가는 걸 실제로 잡는다.
func _test_accuracy_has_teeth() -> void:
	var b = _make_board()
	var ctr = Vector2(134, 134)
	b.call(&"begin_stroke")
	for p in b.call(&"guide_points"):
		b.call(&"trace_stroke", p + (ctr - p).normalized() * 4.0)   # 겨우 4px 어긋남
	var acc = float(b.call(&"accuracy"))
	# 새 판정(≈9.4px): 1 - 4/9.4 ≈ 0.58 → 통과. 옛 판정(≈23.6px): 1 - 4/23.6 ≈ 0.83 → **실패**.
	_check(acc < 0.7, "4px만 어긋나도 정밀도가 확 깎인다 (실제 %.2f — 관대하면 0.8+)" % acc)
	_check(float(b.call(&"coverage")) > 0.9, "그래도 완성도는 높다 (두 축은 별개)")
	b.queue_free()


# ── 🔴 ⑩ 크게 삐끗한 획은 **지워지지 않고 벌받는다** ──
# 옛 구조는 판정이 거리에 대해 **단조롭지 않았다**: 살짝 삐끗(<0.24R)하면 감점인데
# 크게 삐끗(>0.24R)하면 아예 무시돼 **공짜**였다. 밴드를 0.32R로 넓혀 "그리려던 획"은
# 벗어난 만큼 전부 벌하고, 그 바깥(=딴 데 긋기)만 무시한다.
func _test_gross_miss_is_punished_not_erased() -> void:
	var b = _make_board()
	var ctr = Vector2(134, 134)
	var guide = b.call(&"guide_points")
	b.call(&"begin_stroke")
	for p in guide:
		b.call(&"trace_stroke", p)                                   # 먼저 정확히
	for p in guide:
		b.call(&"trace_stroke", p + (ctr - p).normalized() * 30.0)   # 30px = 옛 밴드(28) 밖 · 새 밴드(38) 안
	var acc = float(b.call(&"accuracy"))
	# 새: 30px 점들이 채점돼 평균 ≈15px → 정밀도 0. 옛: 통째로 무시돼 정밀도 ≈1로 **남았다**.
	_check(acc < 0.3, "크게 벗어난 획이 점수를 깎는다 (실제 %.2f — 무시하면 1.0에 가깝다)" % acc)
	b.queue_free()


# ── 🔴 ⑪ 펜 보정이 획을 당긴다 (세션 23, 사용자: "펜등급마다 보정도가 오르는거임") ──
# 채점기를 직접 세워 본다 — 보정은 **아이템 → GameState → 보드 → 채점기** 순으로 흐르는데,
# 여기선 규칙 자체(당김이 정밀도를 올리나)를 순수 수학으로 못 박는다. 배선은 ⑫가 본다.
func _test_pen_correction_pulls_strokes() -> void:
	var Scorer = load("res://src/drawing/trace_scorer.gd")
	var guide := PackedVector2Array()
	for i in 60:
		guide.append(Vector2(float(i) * 2.0, 100.0))     # 수평 직선
	var accs := []
	for corr in [0.0, 0.35, 0.6, 1.0]:
		var s = Scorer.new()
		s.set_reference_radius(118.0)                     # 판정 반경 ≈9.4px
		s.set_correction(corr)
		s.set_guide(guide)
		for p in guide:
			s.add_point(p + Vector2(0.0, 8.0))            # 8px 아래로 어긋나게 그음
		accs.append(float(s.accuracy()))
	_check(accs[0] < 0.3, "보정 0 = 손 그대로 → 8px 어긋남이 그대로 벌받는다 (%.2f)" % accs[0])
	_check(accs[1] > accs[0], "보정 0.35가 정밀도를 올린다 (%.2f > %.2f)" % [accs[1], accs[0]])
	_check(accs[2] > accs[1], "보정 0.6이 더 올린다 — **등급이 오를수록** (%.2f)" % accs[2])
	_check(accs[3] > 0.99, "보정 1.0 = 정답선에 붙는다 → 정밀도 만점 (%.2f)" % accs[3])
	# 🔴 먹선 자체가 바뀐다 (사용자 선택: "펜이 손을 잡아준다"). 보정 0이면 그린 그대로다.
	var raw = Scorer.new()
	raw.set_reference_radius(118.0)
	raw.set_guide(guide)
	raw.add_point(Vector2(20.0, 108.0))
	_check(is_equal_approx(raw.strokes()[0][0].y, 108.0), "보정 0 → 먹선이 그린 좌표 그대로")
	var pen = Scorer.new()
	pen.set_reference_radius(118.0)
	pen.set_correction(0.5)
	pen.set_guide(guide)
	pen.add_point(Vector2(20.0, 108.0))
	_check(is_equal_approx(pen.strokes()[0][0].y, 104.0), "보정 0.5 → 먹선이 가이드 쪽으로 절반 당겨짐")


# ── 🔴 ⑫ 펜 등급이 실제로 등록돼 있고 보정도가 등급 순으로 오른다 ──
func _test_pen_grades_registered() -> void:
	var db = root.get_node_or_null(^"/root/Db")
	var gs = root.get_node_or_null(^"/root/GameState")
	if db == null or gs == null:
		_check(false, "Db·GameState 오토로드를 찾을 수 없다")
		return
	var last := -1.0
	for id in [&"pen_basic", &"pen_mid", &"pen_high"]:
		var it = db.get_item(id)
		_check(it != null, "%s 등록됨 (data/items/%s.tres)" % [id, id])
		if it == null:
			return
		_check(int(it.kind) == Enums.ItemKind.PEN, "%s의 부위 = PEN" % id)
		var c := float(it.params.get("correction", -1.0))
		_check(c > last, "%s 보정도가 앞 등급보다 높다 (%.2f > %.2f)" % [id, c, last])
		last = c
	# 배선: 펜을 끼면 GameState가 그 보정도를 돌려준다. 맨손은 0 (그린 대로).
	_check(is_zero_approx(float(gs.stroke_correction())), "펜 미착용 = 보정 0 (손 그대로)")
	gs.equipment[Enums.ItemKind.PEN] = &"pen_high"
	_check(is_equal_approx(float(gs.stroke_correction()), 0.6), "명장의 펜 착용 → 보정 0.6")
	gs.equipment.erase(Enums.ItemKind.PEN)


# ── 🔴 ⑬ 획이 **누적된다** — 한 조각을 여러 획에 나눠 그린다 (세션 25) ──
# 사용자: *"획단위로 초기화되서 화살표를 그리가가 어렵네?"* — 세션 24까지 `begin_stroke`가
# 문지름을 통째로 지워, 선을 긋고 펜을 떼서 화살촉을 그리면 **선이 사라졌다**. 화살표처럼
# 획이 여러 개인 모양은 물리적으로 그릴 수 없었다.
# 🔴 검출력: `begin_stroke`가 다시 `reset_stroke`를 부르면 완성도가 **뒤쪽 절반만** 남아 실패한다.
func _test_strokes_accumulate() -> void:
	var b = _make_board()
	var guide = b.call(&"guide_points")
	var half := int(guide.size() / 2)
	b.call(&"begin_stroke")                       # 획 1 = 앞쪽 절반
	for i in half:
		b.call(&"trace_stroke", guide[i])
	var cover_one := float(b.call(&"coverage"))
	b.call(&"begin_stroke")                       # 펜을 뗐다 다시 댔다 = 획 2 = 뒤쪽 절반
	for i in range(half, guide.size()):
		b.call(&"trace_stroke", guide[i])
	var cover_two := float(b.call(&"coverage"))
	_check(cover_two > cover_one + 0.3,
		"펜을 다시 대도 앞 획이 남는다 → 완성도가 쌓인다 (%.2f → %.2f)" % [cover_one, cover_two])
	_check(cover_two > 0.95, "두 획을 합치면 가이드를 다 덮는다 (%.2f)" % cover_two)
	# 🔴 획은 **따로** 남아야 한다 — 한 줄로 이으면 펜을 뗀 구간이 선이 돼 화살표가 삼각형이 된다
	var st = b.call(&"trace_strokes")
	_check(st.size() == 2, "획 2개가 따로 보관된다 (실제 %d개)" % st.size())
	b.queue_free()


# ── 🔴 ⑭ 우클릭(다시 그리기)은 전부 지운다 ──
# 누적으로 바뀌면서 "지우고 처음부터"가 갈 곳을 잃었다 — 이 경로가 없으면 잘못 그은 획을
# 무를 방법이 아예 없다 (예전엔 좌클릭이 겸했고, 그래서 여러 획을 못 그렸다).
func _test_clear_stroke_wipes() -> void:
	var b = _make_board()
	_rub_exact(b)
	_check(float(b.call(&"coverage")) > 0.95, "먼저 그린다")
	b.call(&"clear_stroke")
	_check(is_zero_approx(float(b.call(&"coverage"))), "다시 그리기 → 완성도 0")
	_check(is_zero_approx(float(b.call(&"accuracy"))), "다시 그리기 → 정밀도 0")
	_check(b.call(&"trace_strokes").is_empty(), "다시 그리기 → 먹선이 사라진다")
	b.queue_free()


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
	# 문양 칸들 (기본 2방 = 2칸). 🔴 세션 25: 칸을 **골라야** 그릴 수 있다. 마지막 칸 advance는 "finished"
	var open = b.call(&"get_open")
	var last_result := ""
	for k in open:
		b.call(&"select_slot", k)
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


## 진→룬 그려 문양 단계에 도달하고 **칸 0을 고른다** (기본 문양본 = 2방 [0,2]).
## 🔴 세션 25: 칸은 자동으로 안 잡힌다 — 도착하면 미선택(-1)이라 여기서 골라 줘야 한다.
## 미선택 그 자체는 ⑥이 검증한다.
func _reach_glyph_stage(b) -> void:
	_rub_exact(b)
	b.call(&"advance")   # 진
	_rub_exact(b)
	b.call(&"advance")   # 룬 → 문양 단계 (칸 미선택)
	b.call(&"select_slot", 0)


# ── ⑥ 문양 칸 자유 편집(세션 15): 칸 전환 시 이전 칸 자동 잠금 + 재편집이 교체(중복 아님) ──
func _test_glyph_free_edit_and_relock() -> void:
	var b = _make_board()
	# 🔴 세션 25: 문양 단계에 **칸이 안 잡힌 채로** 도착한다 (사용자: "8방 했을때 이미
	# 주황색으로 선택되어있어 그거 지워주고"). 예전엔 첫 빈 칸을 멋대로 잡아, 아무것도
	# 안 골랐는데 주황 강조가 떠 있었다. 칸을 고르는 건 사용자다.
	_rub_exact(b)
	b.call(&"advance")
	_rub_exact(b)
	b.call(&"advance")
	_check(int(b.call(&"trace_slot")) == -1, "문양 단계 도착 = 칸 미선택 (멋대로 안 잡는다)")
	_check(b.call(&"guide_points").is_empty(), "칸을 안 골랐으면 밑그림도 없다")
	_check(String(b.call(&"advance")) == "none", "칸을 안 고른 채 [다음] = 아무 일도 없다")
	b.call(&"select_slot", 0)
	_check(int(b.call(&"trace_slot")) == 0, "클릭한 칸이 잡힌다")
	_check(b.call(&"guide_points").size() > 2, "칸을 고르면 밑그림이 선다")
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
