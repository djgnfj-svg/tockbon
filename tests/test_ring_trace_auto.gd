extends SceneTree
## 손그림 탁본(자동추적 + 완성도·정밀도 점수) 자동 검증 (세션 14b) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_trace_auto.gd
## 전 항목 통과 시 "TEST_RING_TRACE_OK" 출력 후 종료 코드 0.
##
## 검증 대상: ring_board에 **합성 밑그림**(진 윤곽 + 룬 + 밴드별 문양-고리)을 통째로 넣으면
##   문지른 궤적이 먹선으로 남고, 완성도(드러낸 비율)·정밀도(선에 붙은 정도)로 점수가 난다.
##   🔴 **여기가 세83 「그리기 폐지 스위치」가 되살리는 몸이다** — `balance.skip_drawing`을 false로
##   되돌리면 이 축이 그대로 돌아온다. 폐지 모드가 기본인 동안 이 파일이 그 축의 **유일한 상시 그물**이다.
##
## 🔴🔴 **세85 ⑨ 재편**: 옛 판본은 진·룬·문양 칸을 **하나씩 골라 하나씩 긋고 [다음](advance)으로
##   잠그는** per-piece 흐름을 몰았다. 그 흐름은 세70에 은퇴했고(라이브는 COMBINED 통째 하나)
##   src 호출자가 0이었다 — **그물이 죽은 몸을 재고 있었다**(세84 감사 T2). 세85 ⑨가 그 몸을
##   걷었고, 여기 검사도 **라이브 진입점(`enter_combined_trace`)으로 갈아탔다**.
##   사라진 검사: ④전 흐름·분석 리포트 · ⑤빈 진 완성 · ⑥칸 자유 편집 · ⑦칸별 휠 크기 ·
##   ⑧먼 클릭 칸 뺏김(I3) · ⑯진·룬 고르기 · ⑰화살촉 따로 긋기.
##   🔴 ⑰만 **계약 자체가 사라졌다**(나머지는 몸이 옮겨간 것): 통째 밑그림의 낱개 모티프는
##   `band_r × MOTIF_SIZE_FRAC`(판 268px 기준 6.9~11.2px)이라 깃 벌어짐이 붓의 드러남 반경
##   (9.44px)보다 **작다** — 즉 「몸통만 그으면 화살촉이 통째로 드러난다」는 세25의 그 상태가
##   통째 흐름에선 이미 참이다. **손맛 문제라 F5로 판단할 일**이고 그물로 못 박을 수 없어 뺐다.
##
## 🔴 세85 ⑪ 이관: F6 조립 슬라이스 벤치가 은퇴하며 `compose_guide` **합성 계약**(진 윤곽·룬·밴드
##   반경·빈 밴드)이 여기로 왔다 — 밑그림을 만드는 자리라 「긋기」와 한 파일에 있는 게 맞다.
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

	_test_compose_guide_layout()
	_test_exact_trace_high_score()
	_test_sloppy_lower_accuracy()
	_test_partial_lower_coverage()
	_test_accuracy_has_teeth()
	_test_gross_miss_is_punished_not_erased()
	_test_pen_correction_pulls_strokes()
	_test_pen_grades_registered()
	_test_strokes_accumulate()
	_test_clear_stroke_wipes()
	_test_glyph_shapes_are_distinct()
	_test_jin_shapes_are_closed_and_distinct()
	await _test_jin_shape_reaches_the_board()
	_test_rune_shapes_are_closed_and_distinct()
	await _test_rune_shape_reaches_the_board()
	_test_ink_rides_assembly()
	_test_special_ink_consumed_while_drawing()
	_test_accuracy_tol_tightened()
	_test_low_precision_piece_score_penalized()

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
	# 세션53 판정(tol≈5.9px): 1 - 4/5.9 ≈ 0.32 → 통과. 옛(≈23.6px): 1 - 4/23.6 ≈ 0.83 → **실패**.
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
		s.set_reference_radius(118.0)                     # 판정 반경 ≈5.9px (세션53, ACC_TOL 0.05)
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


## 🔴 ⑱ 문양마다 **밑그림 모양이 다르다** (세션 47 — 어휘 3→6).
##
## 세션 44까지 `_build_guide`의 문양 갈래는 `inward` 하나만 보고 화살표 **방향**만 뒤집었다.
## 새 문양(유도3·팅김4·추진5)은 전부 `inward = false`라 그대로 두면 **발산·관통과 똑같은 화살표**가
## 떠서, 6개 문양이 색·라벨만 다른 4지선다가 된다 — 손으로 긋는 감각이 전부 같아진다는 뜻이고,
## 그건 memory `takbon-glyph-design-principle`이 경고하는 실패 그 자체다.
##
## 🔴 검출력: `glyph_guide_pts`가 코드를 무시하고 화살표만 돌려주면(=회귀) 2·3·4·5가
## 1과 **같은 점 집합**이 돼 여기서 빨개진다. 이 테스트가 이번 작업의 유일한 헤드리스 가드다.
## ⚠ **"보인다"는 못 잰다** — 모양이 예쁜지·구분되어 보이는지는 리드가 실게임 스샷으로 본다.
##
## 🔴 세85 ⑨: 옛 판본은 은퇴한 `set_active_glyph`으로 판에 문양 하나씩 꽂아 `guide_points`를 읽었다.
## 이제 **정본 static을 직접** 부른다 — 그게 합성 밑그림(`glyph_ring_subpaths`)과 책 셀 아이콘이
## **둘 다 부르는 바로 그 함수**라, 오히려 재는 몸이 라이브에 더 가깝다.
func _test_glyph_shapes_are_distinct() -> void:
	var p := Vector2(60.0, 0.0)
	var outward := Vector2(1.0, 0.0)
	var sz := 20.0
	var seen := {}                 # 점집합 문자열 → 먼저 그 모양을 쓴 코드
	# 🔴 세79 M1: 6 → **8**(확산·폭발) · 세82: 8 → **9**(응축). 이 수를 안 늘리면 새 문양은
	# 헤드리스 커버리지가 **0**이다 — 밑그림이 폴백 화살표로 떨어져도(=손이 안 갈려도),
	# 폭발과 궤적이 같아도 아무도 안 잡는다.
	# ⚠ `Enums.GlyphCode`에 문양을 늘릴 때 여기와 아래 기대치도 같이 늘려라.
	for code in range(9):
		var g: PackedVector2Array = _BoardScript.glyph_guide_pts(code, p, outward, sz)
		_check(g.size() >= 9, "문양 %d 밑그림이 선다 (%d점)" % [code, g.size()])
		var key := ""
		for pt in g:
			key += "%.1f,%.1f;" % [pt.x, pt.y]
		_check(not seen.has(key),
			"🔴 문양 %d의 밑그림이 문양 %s와 똑같다 — 그리는 궤적이 안 갈렸다" % [code, seen.get(key, "?")])
		seen[key] = code

		# 그 모양을 판에 넣고 정확히 따라 그으면 점수가 난다 — 새 모양이 채점기를 이상하게 돌리지 않는지.
		var bb = _BoardScript.new()
		bb.size = Vector2(268, 268)
		root.add_child(bb)
		var moved := PackedVector2Array()
		for pt in g:
			moved.append(pt + Vector2(134.0, 134.0))
		bb.call(&"enter_combined_trace", moved)
		bb.call(&"begin_stroke")
		for pt in moved:
			bb.call(&"trace_stroke", pt)
		_check(float(bb.call(&"coverage")) > 0.95, "문양 %d — 따라 그으면 완성도≈1" % code)
		_check(float(bb.call(&"accuracy")) > 0.95, "문양 %d — 선 위를 그었으니 정밀도≈1" % code)
		bb.queue_free()
	_check(seen.size() == 9, "9개 문양이 **전부 다른** 모양 (실제 서로 다른 모양 %d개)" % seen.size())
	# 🔴 합성 밑그림이 **이 함수를 그대로** 부른다 — 사본이 생기면 「셀에서 본 모양 ≠ 그을 모양」.
	var gr := GlyphRingDef.new()
	gr.motif = 1          # 발산
	gr.count = 1
	var subs: Array = _BoardScript.glyph_ring_subpaths(gr, Vector2.ZERO, 50.0)
	_check(subs.size() == 1, "문양-고리 count 1 → 서브패스 1개 (실제 %d)" % subs.size())
	if subs.size() == 1:
		var band_p := Vector2.from_angle(-PI / 2.0) * 50.0
		var expect: PackedVector2Array = _BoardScript.glyph_guide_pts(
			1, band_p, Vector2.from_angle(-PI / 2.0), 50.0 * 0.14)
		var sub0: PackedVector2Array = subs[0]
		var far := 0.0
		var ok: bool = sub0.size() == expect.size()
		if ok:
			for i in sub0.size():
				far = maxf(far, sub0[i].distance_to(expect[i]))
		_check(ok and far < 0.001,
			"밴드 모티프 = glyph_guide_pts 정본 그대로 (크기 = band_r × MOTIF_SIZE_FRAC)")

	# 🔴 세71: 책의 **문양 개별 셀(glyph_icon_pts)은 은퇴**했다 — 문양은 이제 진의 **층(band)**에
	# 문양-고리로 끼운다. 6종 구분은 위 `glyph_guide_pts`(모티프별 모양)가 이미 지키고, 책의
	# `_ring_icon`은 그 함수를 **그대로** 불러 아이콘을 그리므로(구조적 재사용) 책이 자기 화살표로
	# 갈라질 여지 자체가 없다(옛 glyph_icon_pts 관측점이 막던 그 갈라짐이 구조적으로 불가능해짐).
	# 대신 새 UI(층 소켓)의 관측점 = 소켓·목록 레이아웃 static이 겹치지 않고 세로로 쌓이는가.
	var Book = load("res://src/drawing/ring_book.gd")
	var bsz := Vector2(280, 262)
	var socks: Array = Book.band_socket_rects(2, bsz, 46.0)
	_check(socks.size() == 2, "층 소켓 2칸 rect가 선다 (실제 %d)" % socks.size())
	_check((socks[1] as Rect2).position.y >= (socks[0] as Rect2).end.y - 0.01,
		"소켓 2칸이 세로로 안 겹친다 (밴드1 아래 밴드2)")
	var lt: float = Book.band_list_top(2, 46.0)
	_check(lt > (socks[1] as Rect2).end.y, "보유 고리 목록이 소켓 아래에서 시작한다")
	var lrects: Array = Book.ring_list_rects(2, bsz, lt)
	_check(lrects.size() == 2 and (lrects[1] as Rect2).position.y > (lrects[0] as Rect2).position.y,
		"고리 목록 rect가 세로로 쌓인다 (어휘가 늘면 줄 수로)")

	# ⚠ 세85 ⑨: 옛 「요약 문자열(`ring_summary`)이 새 문양 이름을 센다」 검사는 그 함수와 함께
	# 은퇴했다. 라이브 요약은 패널 `_compose_summary()`가 `GlyphRingDef.display_name`으로 만든다.


## 🔴 세션29: 고른 잉크 id가 **발사 계약(assembly)에 실린다** — 패널이 `set_ink`를 부르면
## `get_assembly`가 담아 발사·저장까지 등급 배수를 나른다. 여기가 끊기면 잉크를 골라도
## 위력이 안 바뀐다(패널→보드 배선 공백). 배수 해석은 Db.ink_mult의 일이고, 여긴 **id 운반**만 본다.
func _test_ink_rides_assembly() -> void:
	var b = _make_board()
	_check(StringName((b.call(&"get_assembly") as Dictionary).get("ink", &"미설정")) == &"",
		"기본 = 빈 잉크(맨손) — 아무도 안 고르면 배수 없음")
	b.call(&"set_ink", &"ink_high")
	_check(StringName((b.call(&"get_assembly") as Dictionary).get("ink", &"")) == &"ink_high",
		"set_ink 뒤 get_assembly가 그 잉크를 싣는다")
	# clear_all은 잉크를 안 지운다 — 지속되는 선택이다(다시 그려도 골라 둔 잉크 유지)
	b.call(&"clear_all")
	_check(StringName((b.call(&"get_assembly") as Dictionary).get("ink", &"")) == &"ink_high",
		"clear_all이 잉크를 안 지운다 (판 기하가 아니라 지속 선택)")
	b.queue_free()


## 🔴 특별잉크는 **그리는 동안 실시간으로 닳는다** (세션29, 사용자: "그릴 때 실시간으로 소비").
## 획당 소모 + 비율 적립 + 바닥나면 소모 없이 계속. 끊기면 "쏘는 순간 차감"으로 회귀(사용자가 3번 반대함).
func _test_special_ink_consumed_while_drawing() -> void:
	var gs: Node = root.get_node(^"GameState")
	gs.inventory.clear()
	gs.add_item(&"ink_fire_red", 2)   # 2획치 특별잉크
	var b = _make_board()             # 합성 밑그림(진 윤곽)이 서 있다 — 그 위를 긋는다
	b.call(&"set_ink", &"ink_fire_red")
	# 🔴 세션31: 잉크는 **획의 최초 유효점**에서 정산된다 (begin_stroke가 아니라). 그래서 각 획은
	# begin_stroke + 가이드 위 유효점 하나로 몬다. 빈 클릭(먹선 없는 획)은 안 태운다 — 아래 첫 가드.
	var gp: PackedVector2Array = b.call(&"guide_points")
	var p0: Vector2 = gp[0]
	# ① 빈 클릭 = 유효점 없는 획 → 소모·적립 없음 (세션31 누수 수정의 회귀 가드).
	b.call(&"begin_stroke")
	b.call(&"trace_stroke", p0 + Vector2(9999, 9999))   # 가이드에서 멀다 = add_point 거부
	_check(gs.get_count(&"ink_fire_red") == 2, "빈 클릭(먹선 없는 획)은 특별잉크를 안 태운다 (2 그대로)")
	# ② 유효점이 찍힌 획만 획당 1 소모.
	b.call(&"begin_stroke")
	b.call(&"trace_stroke", p0)
	_check(gs.get_count(&"ink_fire_red") == 1, "특별잉크 획당 1 소모 (2→1)")
	b.call(&"begin_stroke")
	b.call(&"trace_stroke", p0)
	_check(gs.get_count(&"ink_fire_red") == 0, "또 한 획 = 0")
	b.call(&"begin_stroke")            # 바닥난 뒤 — 소모·적립 없이 계속 그린다
	b.call(&"trace_stroke", p0)
	_check(gs.get_count(&"ink_fire_red") == 0, "바닥나면 더 안 닳는다 (음수로 안 감)")
	var asm: Dictionary = b.call(&"get_assembly")
	_check(StringName(asm.get("special_ink", &"")) == &"ink_fire_red",
		"get_assembly가 쓴 특별잉크를 싣는다")
	var ratio := float(asm.get("special_ratio", -1.0))
	_check(ratio > 0.0 and ratio < 1.0,
		"비율 = 특별 2획 / 총 3획 (0<r<1, 바닥난 뒤 획·빈 클릭은 안 셈) — 실제 %.2f" % ratio)
	# 기본잉크(무한)는 안 닳는다 — 회귀 가드
	gs.inventory.clear()
	var b2 = _make_board()            # set_ink 안 함 = 기본 먹
	b2.call(&"begin_stroke")
	b2.call(&"trace_stroke", (b2.call(&"guide_points") as PackedVector2Array)[0])
	_check(float((b2.call(&"get_assembly") as Dictionary).get("special_ratio", -1.0)) == 0.0,
		"기본잉크로만 그리면 특별 비율 0 (안 닳고 효과 없음)")
	b.queue_free()
	b2.queue_free()
	gs.inventory.clear()


# ── 🔴 ⑳ 진 밑그림 8도형: **닫혀 있고 · 서로 다르고 · 룬 자리를 남긴다** (세션 48) ──
# 사용자 확정: *"진의 궤적은 원처럼 닫힌 도형이어야 함. 그 안에 룬이 들어가야 해서."*
# 세션 44~47엔 진이 종류와 무관하게 전부 같은 원이라 8종을 만들어도 **손 궤적이 똑같았다**.
# 🔴 뮤테이션: `jin_guide_pts`의 match를 지워 늘 원을 돌려주면 「서로 다르다」가 7개 실패한다.
#    `_closed`의 append를 지우면 「닫혀 있다」가 8개 실패한다.
func _test_jin_shapes_are_closed_and_distinct() -> void:
	var ctr := Vector2(134.0, 134.0)
	var r := 100.0
	var seen := {}
	for shape in range(8):
		var g: PackedVector2Array = _BoardScript.jin_guide_pts(shape, ctr, r)
		_check(g.size() >= 60, "진 도형 %d 밑그림이 선다 (%d점)" % [shape, g.size()])
		if g.size() < 2:
			continue
		# ① 🔴 닫혔다 — 진은 룬을 담는 그릇이라 터진 도형은 그릇이 아니다.
		_check(g[0].is_equal_approx(g[g.size() - 1]),
			"🔴 진 도형 %d이 안 닫혔다 (%s → %s)" % [shape, g[0], g[g.size() - 1]])
		# 중간에 끊기지도 않는다 — 이웃 점이 멀면 그 구간은 긋는 사람에게 유령 선이다.
		var worst := 0.0
		for i in g.size() - 1:
			worst = maxf(worst, g[i].distance_to(g[i + 1]))
		_check(worst < r * 0.35, "진 도형 %d 점열이 중간에 끊긴다 (최대 간격 %.1f)" % [shape, worst])
		# ② 🔴 룬 자리가 남는다 — 도형이 중심을 향해 파고들면 안 된다(가장 깊은 정삼각 = 0.5R).
		var dmin := INF
		for p in g:
			dmin = minf(dmin, p.distance_to(ctr))
		_check(dmin >= r * 0.45,
			"🔴 진 도형 %d이 중심을 먹는다 — 룬이 들어갈 자리가 없다 (최소 %.2fR)" % [shape, dmin / r])
		# ③ 🔴 채점 밀도가 도형마다 크게 다르면 **완성도가 도형마다 유불리**를 갖는다.
		_check(absi(g.size() - 73) <= 8,
			"진 도형 %d 점 밀도가 원(73점)과 벌어졌다 (%d점)" % [shape, g.size()])
		# ④ 🔴 서로 다르다 — 안 다르면 8종으로 가른 의미가 없다(색만 다른 8지선다).
		var key := ""
		for pt in g:
			key += "%.1f,%.1f;" % [pt.x, pt.y]
		_check(not seen.has(key),
			"🔴 진 도형 %d의 밑그림이 도형 %s와 똑같다 — 손 궤적이 안 갈렸다" % [shape, seen.get(key, "?")])
		seen[key] = shape
	# 모르는 도형은 크래시가 아니라 원 폴백 (진이 늘어도 안 죽는다 — GLYPH_DESC가 밟은 그 함정).
	var fallback: PackedVector2Array = _BoardScript.jin_guide_pts(99, ctr, r)
	_check(fallback.size() >= 60, "모르는 진 도형도 밑그림이 나온다 (폴백=원)")


# ── 🔴 ㉑ 그 도형이 **판까지 온다** — `guide_shape`가 라이브 배선을 통과하는가 (세션 48) ──
# 위 ⑳은 함수만 본다. 이 테스트가 없으면 합성이 늘 CIRCLE을 그려도 초록불이다
# (세션47 문양이 정확히 이걸로 뮤테이션을 통과시켰다 — 함수를 검증할 뿐 배선을 안 봤다).
#
# 🔴 세85 ⑨: 옛 판본은 은퇴한 `choose_jin(jd)`로 판에 직접 꽂았다 — **라이브가 아닌 문**이었다.
# 이제 **책 패널의 실경로**를 탄다: `_on_jin_selected(id)` → `recompose()` →
# `compose_guide_paths(jd.guide_shape, …)` → `enter_combined_trace`.
# ⚠ Db의 진 3종이 전부 CIRCLE이라, 살아있는 데이터만으로는 「늘 원을 그린다」는 회귀를 못 잡는다 —
#   그래서 **삼각 진을 in-memory로 주입한다**(세61 이후 이 리포의 관행). 끝나면 원상복구한다
#   (세83에 `erase`가 진짜 데이터를 지운 사고의 재발 방지).
func _test_jin_shape_reaches_the_board() -> void:
	var db = root.get_node("/root/Db")
	var JinDefScript = load("res://src/core/schemas/jin_def.gd")
	var jd = JinDefScript.new()
	jd.id = &"jin_probe_tri"
	jd.guide_shape = 1                 # Enums.JinShape.TRIANGLE
	jd.band_count = 1
	jd.rune_slots = 1
	var had: bool = db.jins.has(&"jin_probe_tri")
	db.jins[&"jin_probe_tri"] = jd

	var scene := load("res://src/drawing/ring_forge_panel.tscn") as PackedScene
	var panel = scene.instantiate()
	root.add_child(panel)
	await process_frame
	panel.call(&"_on_jin_selected", &"jin_probe_tri")
	var board = panel.get_node("Stage/Spread/RingBoard")
	var g: PackedVector2Array = board.call(&"guide_points")
	var ro: float = board.call(&"_outer_radius")
	var bctr: Vector2 = board.size * 0.5
	var expect: PackedVector2Array = _BoardScript.jin_guide_pts(1, bctr, ro)
	_check(g.size() == expect.size() and g.size() > 2,
		"삼각 진의 밑그림이 판에 선다 (%d점, 기대 %d점)" % [g.size(), expect.size()])
	if g.size() == expect.size():
		var far := 0.0
		for i in g.size():
			far = maxf(far, g[i].distance_to(expect[i]))
		_check(far < 0.5, "🔴 판의 밑그림이 그 진의 도형과 다르다 (최대 %.1fpx 어긋남)" % far)
	# 원 진과 실제로 갈리는가 — 같은 점열이면 guide_shape가 배선까지 안 온 것이다.
	var circle: PackedVector2Array = _BoardScript.jin_guide_pts(0, bctr, ro)
	var same := g.size() == circle.size()
	if same:
		for i in g.size():
			if not g[i].is_equal_approx(circle[i]):
				same = false
				break
	_check(not same, "🔴 삼각 진인데 밑그림이 원 그대로다 — guide_shape가 판까지 안 온다")
	panel.queue_free()
	await process_frame
	if not had:
		db.jins.erase(&"jin_probe_tri")   # 🔴 주입 원상복구 (실데이터를 안 건드린다)
	_check(int((db.call(&"all_jins") as Array).size()) == 3,
		"주입을 되돌렸다 — Db 진은 다시 3종 (누수 감지기)")


	# 🔴 **책 셀 아이콘도 같은 도형이다** (세션47 문양 규약). 셀은 열린 획(세로선·화살표)만
	# 그려 진처럼 보이지 않았고, 무엇보다 **고르는 순간 손으로 그을 도형과 아무 관계가 없었다**.
	# ⚠ 여기서 재는 건 `jin_icon_paths`의 첫 획(=윤곽)뿐이다 — 셀이 그 진의 shape를 실제로
	#   넘기는지(`_draw_jin_cells`)와 "보인다"는 헤드리스가 못 잡는다(리드의 스샷이 최종 판정).
	var BookScript = load("res://src/drawing/ring_book.gd")
	var marks: Array = BookScript.jin_icon_paths(1, 1, Vector2.ZERO, 17.0)
	_check(not marks.is_empty(), "책 진 셀 아이콘에 획이 있다")
	var outline: PackedVector2Array = marks[0]["pts"] if not marks.is_empty() else PackedVector2Array()
	var want: PackedVector2Array = _BoardScript.jin_guide_pts(1, Vector2.ZERO, 17.0)
	_check(outline.size() == want.size() and outline.size() > 2,
		"책 셀의 바깥 윤곽 = 판의 닫힌 도형 (%d점, 기대 %d점)" % [outline.size(), want.size()])
	if outline.size() == want.size():
		var off := 0.0
		for i in outline.size():
			off = maxf(off, outline[i].distance_to(want[i]))
		_check(off < 0.5, "🔴 책 셀 아이콘이 판의 도형과 갈라졌다 (최대 %.1fpx)" % off)


# ── 🔴 ㉒ 룬 밑그림 6종: **닫혀 있고 · 서로 다르고 · 폴백(△)으로 새지 않는다** (세션 49) ──
# 룬이 3→6으로 늘었다(번개·흙·풀). 세션 34의 `rune_guide_verts`는 셋만 알고 나머지를 전부 △로
# 폴백했으므로, 새 룬을 데이터로만 더하면 **불과 똑같은 삼각형 = 색만 다른 6지선다**가 된다
# (진이 세션 48에 밟은 그 함정 · memory `takbon-glyph-design-principle`).
# 🔴 뮤테이션: `rune_guide_verts`의 match를 지워 늘 △를 돌려주면 「서로 다르다」5 + 「폴백이 아니다」5
#    = 10개가 실패한다. 마지막 꼭짓점(=첫 점)을 빼면 「닫혔다」가 그 룬 수만큼 실패한다.
## 🔴 세84 #43: 여기 `[0, 2, 3, 4, 5, 6]` **손 사본**이 있었다 — 룬이 7종이 되면 그 룬은
## 「닫힘·서로 다름·△ 폴백 금지」를 **한 번도 안 지난다**(세49에 실제로 난 버그가 정확히 그것이다).
## 정본은 `Enums.RUNE_TYPES` 하나 — 같은 파일이 이미 `Enums.ItemKind`를 쓰므로 컴파일 함정도 없다.

func _test_rune_shapes_are_closed_and_distinct() -> void:
	var ctr := Vector2(134.0, 134.0)
	var s := 40.0
	var fire: PackedVector2Array = _BoardScript.rune_guide_verts(0, ctr, s)
	var seen := {}
	var visited := 0
	for rt: int in Enums.RUNE_TYPES:
		visited += 1
		var v: PackedVector2Array = _BoardScript.rune_guide_verts(rt, ctr, s)
		_check(v.size() >= 4, "룬 %d 밑그림 꼭짓점이 선다 (%d개)" % [rt, v.size()])
		if v.size() < 4:
			continue
		# ① 🔴 닫혔다 — 룬은 진 안에 앉는 하나의 인장이라 터진 획은 룬이 아니다.
		_check(v[0].is_equal_approx(v[v.size() - 1]),
			"🔴 룬 %d 밑그림이 안 닫혔다 (%s → %s)" % [rt, v[0], v[v.size() - 1]])
		# ② 🔴 채점 밀도 — 호출부가 변마다 12등분하므로 꼭짓점이 많으면 그 룬만 가이드가 촘촘해져
		#    완성도가 룬마다 유불리를 갖는다 (진 ⑳의 밀도 규율과 같은 이유).
		_check(v.size() - 1 >= 3 and v.size() - 1 <= 7,
			"룬 %d 변 수가 3~7을 벗어났다 (%d변)" % [rt, v.size() - 1])
		# ③ 🔴 서로 다르다 — 안 다르면 6종으로 가른 의미가 없다.
		var key := ""
		for pt in v:
			key += "%.1f,%.1f;" % [pt.x, pt.y]
		_check(not seen.has(key),
			"🔴 룬 %d의 밑그림이 룬 %s와 똑같다 — 손 궤적이 안 갈렸다" % [rt, seen.get(key, "?")])
		seen[key] = rt
		# ④ 🔴 새 룬이 **불(△) 폴백으로 새지 않는다** — ③만으론 못 잡는다(둘이 같이 새면
		#    서로 다르다는 검사도 같이 무너지지만, 여기가 원인을 정확히 짚는다).
		if rt != 0:
			var same := v.size() == fire.size()
			if same:
				for i in v.size():
					if not v[i].is_equal_approx(fire[i]):
						same = false
						break
			_check(not same, "🔴 룬 %d이 불 삼각형 폴백으로 샌다 — 모양을 안 가졌다" % rt)
	# 🔴 순회가 실제로 정본 전량을 돌았다 (세84 #43의 검출자). ⚠ 처음엔 `RUNE_TYPES.size() >= 6`만
	#   세웠는데 **루프를 `[]`로 돌려도 전 항목 그린이었다** — 위 단정들은 "없음"이 아니라 "각 룬"을
	#   재므로 루프가 죽으면 통째로 사라지고 failures는 0이다(자명 통과의 교과서적 형태).
	#   그래서 「몇 종을 실제로 훑었나」를 센다.
	_check(visited == Enums.RUNE_TYPES.size() and visited >= 6,
		"🔴 룬 정본 %d종을 실제로 다 훑었다 (실제 %d — 0이면 위 단정이 통째로 자명 통과다)"
			% [Enums.RUNE_TYPES.size(), visited])
	# 모르는 룬은 크래시가 아니라 △ 폴백 (룬이 늘어도 안 죽는다 — GLYPH_DESC가 밟은 그 함정).
	var fallback: PackedVector2Array = _BoardScript.rune_guide_verts(99, ctr, s)
	_check(fallback.size() >= 4, "모르는 룬도 밑그림이 나온다 (폴백=△)")


# ── 🔴 ㉓ 그 모양이 **판까지 온다** + **책 셀 아이콘도 같은 함수** (세션 49) ──
# 위 ㉒는 함수만 본다. 이게 없으면 `_build_guide`가 늘 불을 그려도 초록불이다
# (세션 47 문양·세션 48 진이 똑같이 배선을 안 봐서 뮤테이션을 통과시켰다).
## 🔴 세85 ⑨: 옛 판본은 은퇴한 `choose_rune`으로 판에 직접 꽂았다. 이제 **책 패널의 실경로**를
## 탄다: `_on_rune_selected(type)` → `recompose()` → `compose_guide_paths(shape, [type], …)`.
## 이게 끊기면 어떤 룬을 골라도 밑그림이 불(△) 그대로가 된다 — 에러는 안 난다.
func _test_rune_shape_reaches_the_board() -> void:
	var scene := load("res://src/drawing/ring_forge_panel.tscn") as PackedScene
	var guides: Array = []
	var panels: Array = []
	for rt in [4, 0]:                   # 번개 · 불
		var panel = scene.instantiate()
		root.add_child(panel)
		await process_frame
		panel.call(&"_on_jin_selected", &"jin_single")
		panel.call(&"_on_rune_selected", rt)
		var bd = panel.get_node("Stage/Spread/RingBoard")
		guides.append(bd.call(&"guide_points"))
		panels.append(panel)
	var g: PackedVector2Array = guides[0]
	var gf: PackedVector2Array = guides[1]
	_check(g.size() > 2, "번개 룬 밑그림이 판에 선다 (%d점)" % g.size())
	var same := g.size() == gf.size()
	if same:
		for i in g.size():
			if not g[i].is_equal_approx(gf[i]):
				same = false
				break
	_check(not same, "🔴 번개 룬인데 판의 밑그림이 불(△) 그대로다 — 룬 타입이 판까지 안 온다")
	for pn in panels:
		pn.queue_free()
	await process_frame

	# 🔴 **책 셀 아이콘도 같은 함수를 부른다** (진 셀이 세션48에 그랬듯). 셀에서 본 모양과
	# 손으로 그을 모양이 갈라지면 고르는 순간의 의미가 절반 날아간다.
	# ⚠ 여기서 재는 건 함수 공유뿐이다 — 셀이 실제로 그려져 **보이는지**는 헤드리스가 못 잡는다.
	var BookScript = load("res://src/drawing/ring_book.gd")
	var rects: Array = BookScript.rune_cell_rects(6, Vector2(300.0, 300.0), 40.0)
	_check(rects.size() == 6, "룬 셀 6칸이 잡힌다")
	if rects.size() == 6:
		# 🔴 6칸이 한 줄에 몰리면 셀이 1/6 폭으로 쭈그러든다 (진 탭이 세션48에 밟은 함정).
		_check(float(rects[0].size.x) > 80.0,
			"🔴 룬 셀이 너무 좁다 (%.0fpx) — 6칸을 한 줄에 몰아넣었다" % rects[0].size.x)
		_check(float(rects[3].position.y) > float(rects[0].position.y),
			"🔴 넷째 룬 셀이 둘째 줄로 내려간다 (격자)")
		for r0: Rect2 in rects:
			_check(r0.position.x >= 0.0 and r0.position.x + r0.size.x <= 300.0 + 0.01,
				"룬 셀이 책 밖으로 안 나간다")


## 판 하나를 세우고 **라이브와 같은 방식으로** 합성 밑그림을 넣는다 (세85 ⑨).
## 🔴 진입점이 `enter_combined_trace` 하나다 — 라이브(`ring_forge_panel.recompose`)와 같은 문이다.
## 여기선 진 윤곽만 넣는다(룬·밴드 없음 = 가장 단순한 밑그림). 합성 자체는 아래 [0]이 잰다.
## 🔴 세82: 문양 색의 정본이 `data/glyphs/*.tres`라 **보드는 주입받아야 안다**
## (라이브 경로 = `ring_forge_panel._inject_defs`가 `Db.all_glyphs()`를 넘긴다).
func _make_board():
	var b = _BoardScript.new()
	b.size = Vector2(268, 268)
	root.add_child(b)
	var db = root.get_node("/root/Db")
	b.call(&"set_defs", null, [], db.all_glyphs())
	b.call(&"clear_all")
	var ctr := Vector2(134.0, 134.0)          # size * 0.5
	var ro := 268.0 * 0.44                    # _outer_radius()
	b.call(&"enter_combined_trace",
		_BoardScript.compose_guide(int(Enums.JinShape.CIRCLE), [], [], ctr, ro))
	return b


## 지금 가이드 위를 정확히 문지른다 (dev=0 → 정밀도 최대).
func _rub_exact(b) -> void:
	b.call(&"begin_stroke")
	for p in b.call(&"guide_points"):
		b.call(&"trace_stroke", p)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  ✗ ", msg)


# ── [0] 🔴 합성 밑그림 = 진 윤곽 + 룬 + 밴드별 문양-고리 (세85 ⑪ 이관) ──
## 옛 `test_assembly_slice_auto[1]`. F6 벤치가 은퇴하며 여기로 왔다 — 밑그림을 **만드는** 계약이라
## 「긋기」와 한 파일에 있는 게 맞다. 🔴 라이브가 부르는 건 `compose_guide_paths`(서브패스)이고
## `compose_guide`는 그 flatten이다 — **산 쪽을 재고** flatten 동치를 따로 못 박는다.
func _test_compose_guide_layout() -> void:
	var db = root.get_node("/root/Db")
	var ctr := Vector2(200, 200)
	var ro := 180.0
	var r5 = db.get_glyph_ring(&"gr_radiate5")
	var g3 = db.get_glyph_ring(&"gr_gather3")
	if r5 == null or g3 == null:
		_check(false, "대조군 문양-고리(gr_radiate5·gr_gather3)가 Db에 없다")
		return
	var paths: Array = _BoardScript.compose_guide_paths(
		int(Enums.JinShape.CIRCLE), [0], [r5, g3], ctr, ro)
	var guide := PackedVector2Array()
	for sub in paths:
		guide.append_array(sub)
	_check(guide.size() > 40, "합성 가이드 점 다수 (실제 %d)" % guide.size())
	# 🔴 flat = flatten(subpaths) — 채점(flat)과 렌더(subpaths)가 갈라지면 「본 것 ≠ 그은 것」이 된다
	var flat: PackedVector2Array = _BoardScript.compose_guide(
		int(Enums.JinShape.CIRCLE), [0], [r5, g3], ctr, ro)
	_check(flat.size() == guide.size(), "compose_guide = compose_guide_paths의 flatten (점 수 동일)")

	# 진 윤곽 — 반지름 ≈ ro인 점이 있다
	_check(_has_at_radius(guide, ctr, ro, ro * 0.06), "진 윤곽(반경 ~ro) 점 존재")
	# 룬(중심) — 반경 ro*RUNE_GUIDE_FRAC(0.18)≈32 근처 점
	_check(_has_at_radius(guide, ctr, ro * 0.18, ro * 0.10), "룬(중심) 클러스터 존재")
	# 밴드 0 (0.42R) · 밴드 1 (0.68R) — 낱개 모티프가 그 반경대에 깔린다
	_check(_has_at_radius(guide, ctr, ro * 0.42, ro * 0.16), "안쪽 밴드(0.42R) 클러스터 존재")
	_check(_has_at_radius(guide, ctr, ro * 0.68, ro * 0.16), "바깥 밴드(0.68R) 클러스터 존재")

	# 🔴 빈 밴드는 **점을 안 더한다**(자리는 지킨다 — 서브패스 하나가 빈 배열로 남는다)
	var one_paths: Array = _BoardScript.compose_guide_paths(
		int(Enums.JinShape.CIRCLE), [0], [r5, null], ctr, ro)
	var one := PackedVector2Array()
	for sub in one_paths:
		one.append_array(sub)
	_check(one.size() < guide.size(),
		"빈 밴드는 점을 안 더한다 (한 밴드 %d < 두 밴드 %d)" % [one.size(), guide.size()])
	# 🔴 룬 미선택(센티넬 -1) = 룬 서브패스 생략 — 자리 좌표는 안 흔들린다
	var no_rune := PackedVector2Array()
	for sub in _BoardScript.compose_guide_paths(
			int(Enums.JinShape.CIRCLE), [-1], [r5, g3], ctr, ro):
		no_rune.append_array(sub)
	_check(no_rune.size() < guide.size(),
		"룬 미선택 자리는 서브패스를 건너뛴다 (%d < %d)" % [no_rune.size(), guide.size()])

	# 🔴 세85 ⑨(감사 #26): 룬 점열의 단일 소스 `rune_subpath` — 합성이 이걸 그대로 부른다.
	var rsz: float = _BoardScript.combined_rune_size(ro, 1)
	var want: PackedVector2Array = _BoardScript.rune_subpath(0, ctr, rsz)
	var got: PackedVector2Array = paths[1]      # [진 윤곽, 룬, 밴드…]
	_check(got.size() == want.size() and got.size() > 2,
		"합성의 룬 서브패스 = rune_subpath 정본 (%d점, 기대 %d점)" % [got.size(), want.size()])
	if got.size() == want.size():
		var off := 0.0
		for i in got.size():
			off = maxf(off, got[i].distance_to(want[i]))
		_check(off < 0.001, "🔴 룬 점열이 정본과 갈라졌다 (최대 %.3fpx — 12등분 사본 부활 의심)" % off)

	# 🔴 **룬은 닫힌 인장이다** — `rune_subpath`의 `if seg >= 0` 가드가 마지막 꼭짓점을 되돌려
	# 첫 점과 만나게 한다. 가드를 빼면 마지막 변이 열려 **터진 획**이 된다(세49 규율).
	# ⚠ 위 「정본과 같다」 비교만으로는 이걸 못 잡는다 — 둘 다 같은 함수라 같이 열린다(실측).
	var verts: PackedVector2Array = _BoardScript.rune_guide_verts(0, ctr, rsz)
	_check(want.size() == (verts.size() - 1) * 12 + 1,
		"룬 점열 = 변마다 12등분 + 마지막 꼭짓점 (%d점, 기대 %d점)"
			% [want.size(), (verts.size() - 1) * 12 + 1])
	_check(want.size() > 1 and want[0].is_equal_approx(want[want.size() - 1]),
		"🔴 룬 밑그림이 닫힌다 (첫 점 == 끝 점 — `if seg >= 0` 가드가 빠지면 열린다)")

	# 🔴 **자리가 2개면 합성이 실제로 작은 룬을 그린다**(감사 #26의 심장 — 옛 per-piece 식엔
	# 이 축소가 없어 0.16R 룬 둘이 ±0.28R에서 겹쳤다). ⚠ `combined_rune_size`만 부르면
	# **합성이 그 함수를 안 써도 그린이다** — 합성 결과의 실제 반경으로 재야 검출력이 생긴다(실측).
	var rsz2: float = _BoardScript.combined_rune_size(ro, 2)
	_check(rsz2 < rsz, "자리 2개면 룬 크기 상수가 작아진다 (%.2f < %.2f)" % [rsz2, rsz])
	var two: Array = _BoardScript.compose_guide_paths(
		int(Enums.JinShape.CIRCLE), [0, 2], [], ctr, ro)
	_check(two.size() == 3, "자리 2개 = [진 윤곽, 룬0, 룬1] 세 서브패스 (실제 %d)" % two.size())
	if two.size() == 3:
		var slots: Array = _BoardScript.rune_slot_positions(2, ctr, ro)
		var e0: PackedVector2Array = _BoardScript.rune_subpath(0, slots[0], rsz2)
		var sub: PackedVector2Array = two[1]
		var d := 0.0
		var ok: bool = sub.size() == e0.size()
		if ok:
			for i in sub.size():
				d = maxf(d, sub[i].distance_to(e0[i]))
		_check(ok and d < 0.001,
			"🔴 융합진(자리 2)의 룬이 축소된 크기로 합성된다 (어긋남 %.3fpx — 크기 식이 두 벌이면 여기가 빨개진다)" % d)


## 중심에서 반경 r ± tol 안에 점이 하나라도 있나.
func _has_at_radius(pts: PackedVector2Array, c: Vector2, r: float, tol: float) -> bool:
	for p in pts:
		if absf(p.distance_to(c) - r) <= tol:
			return true
	return false


# ── ① 정확히 문지르면 완성도·정밀도·점수가 높다 ──
func _test_exact_trace_high_score() -> void:
	var b = _make_board()
	_check(bool(b.call(&"is_tracing")), "합성 밑그림을 넣으면 그릴 것이 선다")
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
	# 🔴 **자동 확정이 없다** — 적게 그었다고 판이 멋대로 맺거나 되돌리지 않는다.
	# 맺을지 말지는 패널의 [분석 ▶]→[마력 주입]이 정하고, 판은 점수만 낮게 준다.
	_check(bool(b.call(&"is_tracing")), "적게 그려도 계속 그릴 수 있다 (자동 확정·리셋 없음)")
	_check(float(b.call(&"piece_score")) < float(b.call(&"coverage")) + 0.001,
		"점수는 완성도를 못 넘는다 (완성도 × 정밀도 보정)")
	b.queue_free()


# ── 🔴 ㉔ ACC_TOL을 조였다 — 작은 이탈이 이제 더 아프다 (세션 53) ──
# 사용자: *"마법진이 그냥 대충 그려도 인정되는 게 별로네."* → ACC_TOL_FRAC 0.08 → 0.05.
# ⑨(_test_accuracy_has_teeth)는 `< 0.7`만 봐서 0.08→0.05 조임을 못 잡는다(둘 다 0.7 아래).
# 여기선 채점기를 직접 세워, **알려진 4px 이탈** 궤적의 accuracy를 **좁은 밴드**로 못 박아
# 조임 자체를 검출한다. ⑪처럼 수평 직선 가이드라 이탈이 정확히 4px로 통제된다(원 가이드의
# 기하 잡음 없음). 4px는 CONSIDER(37.8px) 안이라 유효점으로 카운트된다.
# 🔴 검출력: ACC_TOL_FRAC을 0.08로 되돌리면 tol이 9.44px가 돼 accuracy가 ≈0.58로
#    밴드(0.25~0.42) 위로 나가 FAIL한다.
func _test_accuracy_tol_tightened() -> void:
	var Scorer = load("res://src/drawing/trace_scorer.gd")
	var guide := PackedVector2Array()
	for i in 60:
		guide.append(Vector2(float(i) * 2.0, 100.0))     # 수평 직선 (⑪과 같은 판)
	var s = Scorer.new()
	s.set_reference_radius(118.0)                         # tol = 118 * 0.05 ≈ 5.9px
	s.set_guide(guide)
	for p in guide:
		s.add_point(p + Vector2(0.0, 4.0))               # 알려진 4px 이탈 (드러남 9.4px·CONSIDER 37.8px 안)
	var acc := float(s.accuracy())
	# 새(tol 5.9): 1 - 4/5.9 ≈ 0.32.  옛(tol 9.44): 1 - 4/9.44 ≈ 0.58 → 밴드 밖.
	_check(acc > 0.25 and acc < 0.42,
		"🔴 4px 이탈 정밀도가 0.05-tol 밴드(0.25~0.42) 안 (실제 %.2f — 0.08로 되돌리면 ≈0.58)" % acc)
	# 완성도는 별개 축이라 여전히 높다 (4px는 드러남 반경 9.4px 안이라 가이드가 다 드러난다).
	_check(float(s.coverage()) > 0.9,
		"4px 이탈은 완성도엔 영향 없다 — 두 축은 별개 (%.2f)" % float(s.coverage()))


# ── 🔴 ㉕ 완성-저정밀 궤적은 이제 낮은 점수다 — 정밀도 바닥 0.5 → 0.25 (세션 53) ──
# 사용자: *"대충 그려도 인정되는 게 별로네."* piece_score = coverage*(0.5+0.5*acc)에서
# 바닥 0.5를 0.25로 낮췄다. 예전엔 정밀도 0이어도 완성도의 절반을 먹어 "가이드만 훑으면 고득점"
# 이었다. 완성도 만점인데 정밀도 0인(=선엔 안 붙고 근처만 훑은) 궤적을 태워, 그 조각 점수가
# 예전 바닥(0.5)이면 못 내려가는 밴드 **아래**로 떨어지는지 못 박는다.
# ⑨⑩은 accuracy 축만 보지 piece_score는 안 본다 — 이번 조임(바닥)의 정면 가드는 여기다.
# 🔴 검출력: piece_score의 바닥을 0.5로 되돌리면(0.5+0.5*acc, acc=0 → 0.5) 점수가 밴드
#    (0.15~0.35) 위로 나가 FAIL한다.
func _test_low_precision_piece_score_penalized() -> void:
	var Scorer = load("res://src/drawing/trace_scorer.gd")
	var guide := PackedVector2Array()
	for i in 60:
		guide.append(Vector2(float(i) * 2.0, 100.0))
	var s = Scorer.new()
	s.set_reference_radius(118.0)                         # tol 5.9px · 드러남 9.4px · CONSIDER 37.8px
	s.set_guide(guide)
	for p in guide:
		s.add_point(p + Vector2(0.0, 8.0))               # 8px 이탈: 드러남 안(완성도↑)·tol 밖(정밀도 0)
	var cover := float(s.coverage())
	var acc := float(s.accuracy())
	var ps := float(s.piece_score())
	_check(cover > 0.9, "가이드는 다 훑었다 → 완성도 높음 (%.2f)" % cover)
	_check(acc < 0.05, "8px 이탈 = tol 밖 → 정밀도 바닥 (%.2f)" % acc)
	# 새 바닥(0.25): 완성도≈1 × (0.25 + 0.75*0) ≈ 0.25.  옛 바닥(0.5): ≈ 0.5 → 밴드 위.
	_check(ps > 0.15 and ps < 0.35,
		"🔴 완성-저정밀 조각 점수가 0.25 바닥 밴드(0.15~0.35) 안 (실제 %.2f — 0.5로 되돌리면 ≈0.5)" % ps)
