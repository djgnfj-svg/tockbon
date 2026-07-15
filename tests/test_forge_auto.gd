extends SceneTree
## 제작대(책 펼침 UI) 자동 검증 — src/drawing/forge_panel.gd + forge_book.gd.
## 실행: Godot --headless --path . -s res://tests/test_forge_auto.gd
##
## 검증 대상은 **배선**이다: 책을 펼치고(open) → 왼쪽 종이에 획을 주입해 도안을 맺고 →
## 오른쪽 책자가 손을 따라 장을 넘겼는지 → 덮으면(close) closed가 오는지.
## 그림의 미관은 눈으로 봐야 한다 (F6 → tests/test_forge.tscn).
##
## ⚠ -s 모드는 오토로드 전역 등록 전에 컴파일된다 — 오토로드 식별자를 컴파일 타임에 참조하면
## 안 되고, 모듈 스크립트는 첫 프레임 후 load()로 지연 로드한다 (CLAUDE.md 알려진 함정).
## GameState·Db가 없으므로 캔버스는 종이 미설정(레거시) 모드로 돈다 — 잉크 상한·종이 소모는
## 본편 경로(test_paper_auto)에서 검증한다.

var _pass := 0
var _fail := 0
var _closed := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: ", name)


func _run() -> void:
	# 오토로드는 런타임엔 존재한다(컴파일 타임 참조만 불가) — 종이가 없으면 도안이 맺히지 않으므로
	# 실제 게임처럼 종이를 쥐여 준다. 이 경로 자체가 종이 경제가 제작대에 물려 있다는 증거다
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState 오토로드 존재")
	if gs != null:
		gs.call(&"add_item", &"paper_1", 10)

	var ForgePanel: GDScript = load("res://src/drawing/forge_panel.gd")
	var panel: Control = ForgePanel.new()
	root.add_child(panel)
	panel.connect(&"closed", func() -> void: _closed += 1)

	_check(not panel.is_open(), "처음엔 덮여 있다")

	panel.open()
	_check(panel.is_open(), "open() → 펼쳐진다")

	var canvas: Control = panel.get_node_or_null(^"Spread/DrawingCanvas")
	_check(canvas != null, "왼쪽 페이지에 종이가 있다")
	var book: Control = _find_book(panel)
	_check(book != null, "오른쪽 페이지에 책자가 있다")
	if canvas == null or book == null:
		_finish()
		return

	# 펼치는 동안엔 종이가 입력을 받지 않는다 (스케일 중 좌표 어긋남 방지)
	_check(canvas.mouse_filter == Control.MOUSE_FILTER_IGNORE, "펼치는 중 종이 입력 잠김")

	# 책자는 손이 있는 단계를 편다 — 아직 아무것도 안 그렸으니 '진'
	_check(int(book.get(&"_stage")) == Enums.DrawStage.CIRCLE, "책자 첫 장 = 진")
	# 🔴 **자동으로 얹지 않는다** (계약이 뒤집혔다). 본보기는 이제 **눌러서 집어 종이로 옮기는
	# 물건**이고(사용자 확정), 놓이면 획을 끌어당기는 자석이 된다. 펼치자마자 집어 주면
	# 종이의 첫 클릭이 "그리기"가 아니라 "놓기"가 되어 손이 막힌다
	_check(not canvas.has_trace(), "펼쳐도 본보기는 안 얹힌다 — 책자에서 눌러 집는 물건이다")

	var s := float(canvas.size.x)
	var c := Vector2(0.5, 0.5)

	# 1. 진 → 책자가 '룬' 장으로 넘어간다
	_feed(canvas, s, _circle_pts(c, 0.22))
	_check(canvas.get_stage() == Enums.DrawStage.RUNE, "진을 두르면 다음은 룬")
	_check(int(book.get(&"_stage")) == Enums.DrawStage.RUNE, "책자가 손을 따라 룬 장을 편다")
	_check(not canvas.has_trace(), "진을 그려내면 밑그림은 걷힌다")

	# 룬 칸을 고르면 그 본보기가 **그린 진 안에** 얹힌다 (얹기/걷기 토글)
	book._pick(0)
	_check(canvas.has_trace(), "룬 본보기를 고르면 종이에 얹힌다")
	book._pick(0)
	_check(not canvas.has_trace(), "같은 칸을 다시 누르면 걷힌다")
	book._pick(0)

	# 2. 룬(불△) → 책자가 '문양' 장으로
	_feed(canvas, s, _triangle_pts(c, 0.10))
	_check(canvas.get_stage() == Enums.DrawStage.ARROW, "룬을 앉히면 다음은 문양")
	_check(int(book.get(&"_stage")) == Enums.DrawStage.ARROW, "책자가 문양 장을 편다")
	_check(panel.get_design() == null, "문양 전에는 도안이 아니다")

	# 3. 문양 → **초안** (F1: 자동 완성 없음). 진(반지름 0.22)을 뚫고 나가야 문양이다 (TECH_SPEC §6.1).
	# Enter/확정 버튼 = canvas.commit_design(). 확정해야 종이가 뜯기고 도안이 맺힌다.
	var paper_before := int(gs.call(&"get_count", &"paper_1")) if gs != null else 0
	_feed(canvas, s, _line_pts(c, c + Vector2(0.0, -0.38)))
	_check(panel.get_design() == null and bool(canvas.call(&"can_commit")),
		"문양까지 → 초안 (자동 완성 없음)")
	_check(bool(canvas.call(&"commit_design")), "확정하면 맺힌다")
	var d: SpellDesign = panel.get_design()
	_check(d != null, "진+룬+문양 → 확정 → 도안이 맺힌다")
	if d != null:
		_check(d.rune_type == Enums.RuneType.FIRE, "룬 = 불△")
		_check(d.arrows.size() == 1, "문양 1획 = 1발")
	# 도안이 맺히면 종이 한 장이 사라진다 — 제작대가 경제에 물려 있다 (GDD §5)
	if gs != null:
		_check(int(gs.call(&"get_count", &"paper_1")) == paper_before - 1,
			"완성 시 종이 1장 소모")

	# 4. 탭은 **참조**다 — 다른 장을 펼쳐도 종이 위 도안은 그대로 (사용자 결정: 골라 찍는 게 아니다)
	book.show_tab(Enums.DrawStage.CIRCLE)
	_check(int(book.get(&"_stage")) == Enums.DrawStage.CIRCLE, "탭을 직접 넘길 수 있다")
	_check(panel.get_design() != null, "탭을 넘겨도 도안은 그대로다")

	# 5. 책 덮기 — tween이 끝나야 닫힌다
	panel.close()
	await _wait(0.3)
	_check(not panel.is_open(), "close() → 덮인다")
	_check(_closed == 1, "closed 시그널 1회")

	# 6. 다시 펼치면 그리던 종이가 그대로 있다 — 왕복이 작업을 지우지 않는다
	panel.open()
	_check(panel.get_design() != null, "다시 펼쳐도 도안이 남아 있다")

	# 7. 종이 비우기
	panel.clear_canvas()
	_check(panel.get_design() == null, "비우면 도안이 사라진다")

	_run_economy_checks(panel, canvas, book, gs, s, c)
	_finish()


## ── 세션 8 감사에서 잡은 버그 4건 — 다시는 안 나게 못 박는다 ──
func _run_economy_checks(panel: Control, canvas: Control, book: Control, gs: Node,
		s: float, c: Vector2) -> void:
	if gs == null:
		return

	# BUG-3: undo → 다시 긋기가 **종이를 또 뜯으면 안 된다.** 고쳐 그리는 게 새로 그리는 것보다
	# 비쌀 이유가 없다. 도안도 새 id로 갈라지지 않아야 한다 (슬롯 두 칸이 같은 도안으로 차던 버그)
	var before := int(gs.call(&"get_count", &"paper_1"))
	_feed(canvas, s, _circle_pts(c, 0.22))
	_feed(canvas, s, _triangle_pts(c, 0.10))
	_feed(canvas, s, _line_pts(c, c + Vector2(0.0, -0.38)))
	canvas.call(&"commit_design")                        # 확정 (F1)
	var d1: SpellDesign = panel.get_design()
	_check(d1 != null, "재작성 검증: 도안 맺힘")
	_check(int(gs.call(&"get_count", &"paper_1")) == before - 1, "완성 → 종이 1장")
	var id1: StringName = d1.id if d1 != null else &""

	canvas.undo_last()                                   # 문양을 취소 — 도안이 무너진다
	_check(panel.get_design() == null, "문양을 지우면 도안이 아니다")
	_feed(canvas, s, _line_pts(c, c + Vector2(0.10, -0.36)))   # 다시 긋는다
	var d2: SpellDesign = panel.get_design()
	_check(d2 != null, "다시 그으면 도안이 돌아온다")
	_check(int(gs.call(&"get_count", &"paper_1")) == before - 1,
		"undo → 재작성: 종이를 또 뜯지 않는다 (BUG-3)")
	_check(d2 != null and d2.id == id1, "undo → 재작성: 같은 도안이다 (id 유지)")

	# BUG-2: 획을 덧그어 **무료 수리**되면 안 된다. 닳은 내구는 그대로 안고 가야 한다.
	# 진을 작게 두른다 — 큰 진은 먹을 다 먹어서 덧그을 획이 상한에 걸린다(그러면 재빌드가
	# 아예 안 일어나 검증이 헛돈다. 실제로 처음엔 그렇게 헛통과했다)
	panel.clear_canvas()
	_feed(canvas, s, _circle_pts(c, 0.12))
	_feed(canvas, s, _triangle_pts(c, 0.07))
	_feed(canvas, s, _line_pts(c, c + Vector2(0.0, -0.24)))
	canvas.call(&"commit_design")                        # 확정 (F1)
	var worn: SpellDesign = panel.get_design()
	_check(worn != null, "내구 검증: 도안 맺힘")
	if worn != null:
		worn.durability = 3                                  # 발사로 닳았다고 치자
		_feed(canvas, s, _line_pts(c, c + Vector2(0.16, -0.18)))   # 문양 1획 추가 → 재빌드
		var d3: SpellDesign = panel.get_design()
		_check(d3 != null and d3.arrows.size() == 2, "덧그은 문양이 실제로 반영된다(재빌드 발생)")
		_check(d3 != null and d3.durability == 3,
			"획을 덧그어도 내구는 안 돌아온다 (BUG-2 무료 수리 차단)")
		_check(d3 != null and d3.durability_max > 3, "상한은 그대로다 — 현재값만 닳은 채 유지")

	# BUG-1: 종이가 0장이면 부품이 다 있어도 **도안이 아니다** — 체크리스트가 완성이라 우기면 안 된다
	panel.clear_canvas()
	var have := int(gs.call(&"get_count", &"paper_1"))
	if have > 0:
		gs.call(&"remove_item", &"paper_1", have)        # 종이를 전부 없앤다
	panel.close()
	await _wait(0.25)
	panel.open()                                          # 다시 펼치면 "종이 없음"이어야 한다
	_feed(canvas, s, _circle_pts(c, 0.22))
	_feed(canvas, s, _triangle_pts(c, 0.10))
	_feed(canvas, s, _line_pts(c, c + Vector2(0.0, -0.38)))
	# 확정을 눌러도 종이가 없으면 맺히지 않는다 (자동 완성이 없으므로 명시적으로 눌러 본다)
	_check(not bool(canvas.call(&"commit_design")), "0장 — 확정 차단")
	_check(panel.get_design() == null, "종이 0장 → 부품이 다 있어도 도안이 맺히지 않는다")
	var checklist := _find_checklist(panel)
	_check(checklist != null and checklist.get(&"_design") == null,
		"체크리스트가 '도안이 맺혔다'고 거짓말하지 않는다 (BUG-1)")

	# BUG-4: 소진된 종이에 고착되면 안 된다 — 비운 자리에서 상위 등급으로 승격한다
	gs.call(&"add_item", &"paper_2", 3)
	panel.clear_canvas()                                  # 빈 자리 → 여기서 승격이 일어난다
	_check(String(panel.get(&"_paper_id")) == "paper_2",
		"기본 종이가 떨어지면 중급 종이로 승격한다 (BUG-4)")
	_feed(canvas, s, _circle_pts(c, 0.22))
	_feed(canvas, s, _triangle_pts(c, 0.10))
	_feed(canvas, s, _line_pts(c, c + Vector2(0.0, -0.38)))
	canvas.call(&"commit_design")                        # 확정 (F1)
	_check(panel.get_design() != null, "승격한 종이로 도안이 맺힌다")
	_check(int(gs.call(&"get_count", &"paper_2")) == 2, "중급 종이 1장 소모")


func _find_checklist(panel: Control) -> Control:
	return _find_by_script(panel, "design_checklist.gd")


func _finish() -> void:
	print("──────────────────────────────")
	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("FORGE_AUTO_OK")
	quit(0 if _fail == 0 else 1)


## 책자·체크리스트는 이름 없이 붙는다 — 스크립트 경로로 찾는다
func _find_book(panel: Control) -> Control:
	return _find_by_script(panel, "forge_book.gd")


func _find_by_script(panel: Control, file: String) -> Control:
	var spread := panel.get_node_or_null(^"Spread")
	if spread == null:
		return null
	for child in spread.get_children():
		var sc := (child as Node).get_script() as GDScript
		if sc != null and sc.resource_path.ends_with(file):
			return child as Control
	return null


## tween(펼침·덮기)이 끝날 때까지 프레임을 돌린다
func _wait(sec: float) -> void:
	for _i in maxi(int(sec * 60.0), 1):
		await process_frame


# ─────────────────────────── 합성 획 주입 ───────────────────────────

func _feed(canvas: Control, s: float, pts_norm: PackedVector2Array) -> void:
	canvas._begin_stroke(pts_norm[0] * s)
	for i in range(1, pts_norm.size()):
		canvas._append_live(pts_norm[i] * s, 1.0)
	canvas._end_stroke()


func _circle_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 72:
		var a := -PI / 2.0 + TAU * 0.98 * float(i) / 71.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _line_pts(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(a.lerp(b, float(i) / 11.0))
	return pts


func _triangle_pts(c: Vector2, size: float) -> PackedVector2Array:
	var verts: Array[Vector2] = []
	for k in 3:
		var a := -PI / 2.0 + TAU * float(k) / 3.0
		verts.append(c + Vector2(cos(a), sin(a)) * size)
	var pts := PackedVector2Array()
	for e in 3:
		for i in 14:
			pts.append(verts[e].lerp(verts[(e + 1) % 3], float(i) / 14.0))
	pts.append(verts[0])
	return pts
