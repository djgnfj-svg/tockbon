extends SceneTree
## 종이 등급 적용 자동 검증 (NEXT_CYCLE §2 DoD) —
## 등급 1/2/3별 mana_cost 감면·durability_max 보정·paper_grade 기록 (빌더에 params 직접 주입),
## 캔버스 잉크 상한(초과 획 무효·지우면 회복·등급별 상한 차이),
## 도안 완성 시 종이 1장 소모, 보유 0장 시 완성 차단·재획득 시 해제.
## 실행: Godot --headless --path . -s res://tests/test_paper_auto.gd
## 주의: 오토로드는 런타임 get_node, 모듈 스크립트는 첫 프레임 후 load() (TEAM_PLAN 공유 함정).

var _pass := 0
var _fail := 0
var _rejected := 0
var _blocked := 0
var _created := 0
var _updated := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: ", name)


func _run() -> void:
	var gs: Node = root.get_node_or_null(^"/root/GameState")
	var bus: Node = root.get_node_or_null(^"/root/EventBus")
	if gs == null or bus == null:
		print("FAIL: 오토로드(GameState/EventBus) 없음 — --path . 로 실행했는지 확인")
		quit(1)
		return
	var balance := load("res://data/balance.tres") as BalanceData
	var papers: Dictionary = {
		1: load("res://data/items/paper_1.tres") as ItemDef,
		2: load("res://data/items/paper_2.tres") as ItemDef,
		3: load("res://data/items/paper_3.tres") as ItemDef,
	}
	_test_builder(balance, papers)
	_test_canvas(gs, bus, balance, papers)
	print("──────────────────────────────")
	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("PAPER_AUTO_OK")
	quit(0 if _fail == 0 else 1)


# ─────────────────────────── 1. design_builder 등급 적용 (Db 없이 params 직접) ───────────────────────────

func _test_builder(balance: BalanceData, papers: Dictionary) -> void:
	var builder: GDScript = load("res://src/drawing/design_builder.gd")
	var base_dura: int = SpellDesign.new().durability_max
	var mana_raw: float = balance.rune_mana_base[Enums.RuneType.WATER] + balance.mana_per_arrow * 2.0
	for g: int in [1, 2, 3]:
		var def: ItemDef = papers[g]
		var d: SpellDesign = builder.build(_builder_parts(), balance, null, def.grade, def.params)
		var discount := float(def.params.get("mana_discount", 0.0))
		_check(is_equal_approx(d.mana_cost, mana_raw * (1.0 - discount)),
			"등급 %d 마나 감면 %.0f%%" % [g, discount * 100.0])
		_check(d.durability_max == base_dura + int(def.params.get("durability_bonus", 0)),
			"등급 %d 내구 보정" % g)
		_check(d.durability == d.durability_max, "등급 %d 내구 초기값 = 최대" % g)
		_check(d.paper_grade == g, "등급 %d paper_grade 기록" % g)
	# 기본 인자 = 무보정 (기존 호출 호환)
	var d0: SpellDesign = builder.build(_builder_parts(), balance)
	_check(is_equal_approx(d0.mana_cost, mana_raw), "기본 인자 — 마나 무감면")
	_check(d0.durability_max == base_dura, "기본 인자 — 내구 무보정")
	_check(d0.paper_grade == 1, "기본 인자 — 등급 1")
	# into 재사용(design_updated 경로) 시 내구 보정 비누적
	var p2: ItemDef = papers[2]
	var d2: SpellDesign = builder.build(_builder_parts(), balance, null, p2.grade, p2.params)
	builder.build(_builder_parts(), balance, d2, p2.grade, p2.params)
	_check(d2.durability_max == base_dura + int(p2.params.get("durability_bonus", 0)),
		"into 재사용 — 내구 보정 비누적")
	# 잉크 게이지 헬퍼
	var s := StrokeData.new()
	s.points = _line_pts(Vector2(0.1, 0.5), Vector2(0.9, 0.5))
	var units: float = builder.stroke_ink_units(s, balance)
	_check(absf(units - 0.8 * balance.ink_per_stroke_length) < 0.05, "stroke_ink_units = 길이×계수")


## 인식기를 거치지 않은 합성 부품 (test_drawing_auto._test_builder_edges와 같은 방식)
func _builder_parts() -> Dictionary:
	var c := Vector2(0.5, 0.5)
	var circle_stroke := StrokeData.new()
	circle_stroke.points = _circle_pts(c, 0.2)
	var rune_stroke := StrokeData.new()
	rune_stroke.points = _line_pts(Vector2(0.4, 0.4), Vector2(0.6, 0.6))
	var a1 := StrokeData.new()
	a1.points = _line_pts(c, c + Vector2(0.2, 0.0))
	var a2 := StrokeData.new()
	a2.points = _line_pts(c, c + Vector2(0.0, 0.2))
	return {
		"circle": {"center": c, "radius": 0.2, "stroke": circle_stroke},
		"rune": {"type": Enums.RuneType.WATER, "accuracy_raw": 0.9, "stroke": rune_stroke},
		"arrows": [
			{"direction": 0.0, "length": 0.2, "start": c, "stroke": a1},
			{"direction": PI / 2.0, "length": 0.2, "start": c, "stroke": a2},
		],
		"extras": [],
		"strokes_ordered": [circle_stroke, rune_stroke, a1, a2],
	}


# ─────────────────────────── 2. 캔버스: 잉크 상한·종이 소모·완성 차단 ───────────────────────────

func _test_canvas(gs: Node, bus: Node, balance: BalanceData, papers: Dictionary) -> void:
	var canvas: Control = (load("res://src/drawing/drawing_canvas.gd") as GDScript).new()
	canvas.size = Vector2(320, 320)
	root.add_child(canvas)
	canvas.connect(&"stroke_rejected", func(_r: StringName) -> void: _rejected += 1)
	canvas.connect(&"completion_blocked", func(_r: StringName) -> void: _blocked += 1)
	bus.connect(&"design_created", func(_d: SpellDesign) -> void: _created += 1)
	bus.connect(&"design_updated", func(_d: SpellDesign) -> void: _updated += 1)
	var p1: ItemDef = papers[1]
	var p2: ItemDef = papers[2]
	var p3: ItemDef = papers[3]

	# ── 잉크 상한 (TECH_SPEC §4.1) — 반드시 **작성 순서 안에서** 검사한다 (진 → 룬 → 문양).
	# 순서를 어긴 획은 상한을 따지기도 전에 거부되므로(§6.2), 진·룬을 먼저 앉힌 뒤
	# 문양으로 먹을 채워 상한에 부딪히게 한다. (세션 7의 순서 강제 이후 이 테스트가 낡아
	# 진 없이 가로줄만 긋고 있었다 — 그래서 8건이 조용히 깨져 있었다.)
	var c := Vector2(0.5, 0.5)
	canvas.set_paper(p1.id, p1.grade, p1.params)
	_feed(canvas, _circle_pts(c, 0.22))
	_feed(canvas, _triangle_pts(c, 0.10))
	_check(_rejected == 0 and int(canvas.get_summary().stroke_count) == 2, "진+룬 2획 허용")
	var used2: float = canvas.get_ink_used()
	var cap1: float = float(p1.params.ink_capacity)
	_check(used2 > 0.0 and used2 <= cap1, "게이지: 0 < 사용량 ≤ 상한")

	# 문양을 부채꼴로 여러 획 — paper_1의 남은 먹으로는 다 못 긋는다
	for i in 4:
		_feed(canvas, _arrow_at(c, -PI / 2.0 + 0.4 * float(i), 0.42))
	_check(_rejected >= 1, "먹이 다하면 획이 무효 — stroke_rejected 발신")
	_check(canvas.get_ink_used() <= cap1, "사용량은 상한을 넘지 않는다")
	var at_cap: float = canvas.get_ink_used()
	var count_at_cap: int = int(canvas.get_summary().stroke_count)
	canvas.undo_last()
	_check(canvas.get_ink_used() < at_cap, "획 삭제 → 잉크 회복")
	_check(int(canvas.get_summary().stroke_count) == count_at_cap - 1, "삭제분만큼 획도 준다")

	# ── 등급별 상한 차이: paper_1이 못 받던 같은 문양 4획을 paper_3(상한 48)는 전부 받는다
	var rejected_before := _rejected
	canvas.set_paper(p3.id, p3.grade, p3.params)      # set_paper는 캔버스를 비운다
	_feed(canvas, _circle_pts(c, 0.22))
	_feed(canvas, _triangle_pts(c, 0.10))
	for i in 4:
		_feed(canvas, _arrow_at(c, -PI / 2.0 + 0.4 * float(i), 0.42))
	_check(_rejected == rejected_before, "paper_3 — 같은 문양 4획 전부 허용 (상한 차이)")
	_check(int(canvas.get_summary().stroke_count) == 6, "진+룬+문양 4 = 6획")

	# ── 완성 시 종이 1장 소모 (paper_2 — 표준 도안이 상한 안)
	var before: int = int(gs.call(&"get_count", p2.id))
	gs.call(&"add_item", p2.id, 2)
	canvas.set_paper(p2.id, p2.grade, p2.params)
	_draw_design(canvas)
	_check(_created == 1, "완성 → design_created")
	_check(int(gs.call(&"get_count", p2.id)) == before + 1, "완성 시 종이 1장 소모")
	var d: SpellDesign = canvas.get_design()
	_check(d != null and d.paper_grade == p2.grade, "캔버스 경유 paper_grade 기록")
	if d != null:
		var expect_mana: float = (balance.rune_mana_base[Enums.RuneType.FIRE] + balance.mana_per_arrow) \
			* (1.0 - float(p2.params.mana_discount))
		_check(is_equal_approx(d.mana_cost, expect_mana), "캔버스 경유 마나 감면")
		_check(d.durability_max == SpellDesign.new().durability_max + int(p2.params.durability_bonus),
			"캔버스 경유 내구 보정")
	# 완성 후 갱신(화살표 추가)은 추가 소모 없음
	_feed(canvas, _line_pts(Vector2(0.5, 0.5), Vector2(0.5, 0.32)))
	_check(_updated >= 1 and _created == 1, "갱신은 design_updated")
	_check(int(gs.call(&"get_count", p2.id)) == before + 1, "갱신은 종이 소모 없음")
	if d != null:
		_check(d.durability_max == SpellDesign.new().durability_max + int(p2.params.durability_bonus),
			"갱신 반복에도 내구 보정 비누적")

	# ── 마지막 1장 소모 → 0장 완성 차단 → 재획득 시 해제
	canvas.clear_all()
	_draw_design(canvas)
	_check(_created == 2, "두 번째 도안 완성")
	_check(int(gs.call(&"get_count", p2.id)) == before, "잔여 0장")
	canvas.clear_all()
	_draw_design(canvas)
	_check(_blocked >= 1, "0장 — completion_blocked 발신")
	_check(canvas.get_design() == null and _created == 2, "0장 — 도안 미생성·미소모")
	gs.call(&"add_item", p2.id, 1)
	_feed(canvas, _line_pts(Vector2(0.5, 0.5), Vector2(0.5, 0.68)))
	_check(_created == 3, "종이 재획득 → 다음 획에서 완성")
	_check(int(gs.call(&"get_count", p2.id)) == before, "재획득분 소모")

	# ── 종이 미선택(set_no_paper): 상한 없음(먹이 무한), 완성만 차단
	var blocked_before := _blocked
	var rejected_no_paper := _rejected
	canvas.set_no_paper()                             # 캔버스를 비운다
	_feed(canvas, _circle_pts(c, 0.22))
	_feed(canvas, _triangle_pts(c, 0.10))
	for i in 6:                                       # paper_1이면 진작 거부됐을 양
		_feed(canvas, _arrow_at(c, -PI / 2.0 + 0.3 * float(i), 0.42))
	_check(_rejected == rejected_no_paper, "미선택 — 잉크 상한 없음(무효 없음)")
	_check(_blocked > blocked_before and canvas.get_design() == null, "미선택 — 완성 차단")
	canvas.queue_free()


## 완성 도안 1세트: 진(r 0.22) + 불룬 삼각(0.10) + 문양(진을 뚫고 나간다)
func _draw_design(canvas: Control) -> void:
	_feed(canvas, _circle_pts(Vector2(0.5, 0.5), 0.22))
	_feed(canvas, _triangle_pts(Vector2(0.5, 0.5), 0.10))
	_feed(canvas, _line_pts(Vector2(0.5, 0.5), Vector2(0.68, 0.5)))


## 진 중심에서 ang 방향으로 len만큼 뻗는 문양 (진을 뚫고 나간다 — TECH_SPEC §6.1)
func _arrow_at(c: Vector2, ang: float, len: float) -> PackedVector2Array:
	return _line_pts(c, c + Vector2(cos(ang), sin(ang)) * len)


# ─────────────────────────── 합성 획 주입 (test_drawing_canvas_auto와 동일) ───────────────────────────

func _feed(canvas: Control, pts_norm: PackedVector2Array) -> void:
	var s := 320.0
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
