extends RefCounted
## The refit screen: a strip of slot boxes, then — once one is pressed — that slot's 3x2 board of
## part cells beside the held pile, a five-number dashboard and a preview of the slot's own body.
## See `parts-on-a-board-not-on-the-body`.
##
## ⚠⚠ **The dashboard is the point of this file.** `RefitView` draws `run.army.loadout.stat_of(slot,
## col)` and nothing else — the exact call `Army.max_hp_of` / `damage_of` / `period_of` / `speed_of`
## make — so "the screen and the sim disagree" is unbuildable rather than merely checked. What still
## has to be MEASURED is that the five numbers actually reach the leaf, and that fitting a part moves
## the one the screen shows and no other.
##
## ⚠ **Split the way `net_title` and `net_shell` split**: the geometry and the leaf arguments are
## measured on a bare `RefitView` (or a swapped-in spy) here; the input WIRING — that a held-row press
## reaches `loadout.fit`, that a filled cell reaches `loadout.unfit`, that 완료 reaches `run.close_refit`
## — is driven through the real `Game`, because several of this table's own mutations live in
## `game.gd`'s `_refit_input` and a view-only check cannot see them move.
##
## ⚠⚠ Every card-screen press below goes through `game._unhandled_input(ev)`, never a screen-specific
## helper and never `root.push_input()` — `tests/README`'s own row 6.


## Every leaf `RefitView` owns is overridden. A hook left out binds to nothing and every check about it
## reads as "nothing was drawn" rather than as a failure.
class RefitSpy extends RefitView:
	var draws := 0
	var slot_boxes := []
	var slot_labels := []
	var cell_boxes := []
	var cell_parts := []
	var cell_species := []
	var held_rows := []
	var held_parts := []
	var held_species := []
	var stat_labels := []
	var stat_values := []
	var bodies := []
	var buttons := []

	func _draw() -> void:
		slot_boxes.clear()
		slot_labels.clear()
		cell_boxes.clear()
		cell_parts.clear()
		cell_species.clear()
		held_rows.clear()
		held_parts.clear()
		held_species.clear()
		stat_labels.clear()
		stat_values.clear()
		bodies.clear()
		buttons.clear()
		super()
		draws += 1

	func _paint_slot_box(rect: Rect2, bg: Color, edge: Color, edge_width: float) -> void:
		slot_boxes.append({"rect": rect, "bg": bg, "edge": edge, "width": edge_width})

	func _paint_slot_label(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		slot_labels.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_cell_box(rect: Rect2, bg: Color, edge: Color, edge_width: float) -> void:
		cell_boxes.append({"rect": rect, "bg": bg, "edge": edge, "width": edge_width})

	func _paint_cell_part(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		cell_parts.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_cell_species(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		cell_species.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_held_row(rect: Rect2, bg: Color, edge: Color, edge_width: float) -> void:
		held_rows.append({"rect": rect, "bg": bg, "edge": edge, "width": edge_width})

	func _paint_held_part(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		held_parts.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_held_species(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		held_species.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_stat_label(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		stat_labels.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_stat_value(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		stat_values.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_body(centre: Vector2, radius: float, corner: float, colour: Color) -> void:
		bodies.append({"centre": centre, "radius": radius, "corner": corner, "col": colour})

	func _paint_button(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
			col: Color) -> void:
		buttons.append({"rect": rect, "bg": bg, "text": text, "at": at, "fsize": fsize, "col": col})


const SCREEN := Rect2(0.0, 0.0, 1280.0, 720.0)
const SMALLEST_PRESS_BEFORE := Vector2(220.0, 64.0)


func run(t) -> void:
	_the_geometry(t)
	_the_capacity(t)
	await _the_strip_and_the_board(t)
	await _fitting_through_the_shell(t)
	await _the_dashboard_reads_the_same_function_the_fight_does(t)
	await _the_body_differs_per_slot(t)


# -- geometry: can it be aimed at ------------------------------------------------------------------

func _the_geometry(t) -> void:
	var view := RefitView.new()

	# 「판은 여섯 칸이고 겹치지 않고 화면 안이다」 — floor: six hit rects inside the literal screen;
	# ⚠⚠ ceiling: no two hit rects come within 1 px of each other (`intersects` excludes shared
	# borders, so a gap of exactly 0 would still read as "no overlap").
	var outside := 0
	var overlapping := 0
	for p in Rules.part_count():
		var drawn := view.cell_rect_of(p)
		var hit := view.cell_hit_rect_of(p)
		if not SCREEN.encloses(hit):
			outside += 1
		if drawn.size.x <= 0.0 or drawn.size.y <= 0.0:
			outside += 1
		for q in range(p + 1, Rules.part_count()):
			if hit.grow(1.0).intersects(view.cell_hit_rect_of(q).grow(1.0)):
				overlapping += 1
	t.eq(outside, 0, "칸 여섯의 판정 사각형이 전부 화면 안이고 넓이가 0이 아니다")
	t.eq(overlapping, 0, "어느 두 칸의 판정 사각형도 1px 안으로도 안 붙는다")

	# 「가장 작은 누름이 220x64보다 작지 않다」 — both the board's cells and the held rows.
	t.ok(Look.REFIT_CELL_SIZE_PX.x >= SMALLEST_PRESS_BEFORE.x
			and Look.REFIT_CELL_SIZE_PX.y >= SMALLEST_PRESS_BEFORE.y,
		"칸이 %.0fx%.0f 이고 220x64 보다 크다" % [Look.REFIT_CELL_SIZE_PX.x, Look.REFIT_CELL_SIZE_PX.y])
	t.ok(Look.REFIT_HELD_SIZE_PX.x >= SMALLEST_PRESS_BEFORE.x
			and Look.REFIT_HELD_SIZE_PX.y >= SMALLEST_PRESS_BEFORE.y,
		"더미 자리가 %.0fx%.0f 이고 220x64 보다 크다" % [Look.REFIT_HELD_SIZE_PX.x, Look.REFIT_HELD_SIZE_PX.y])
	t.ok(Look.REFIT_SLOT_SIZE_PX.x >= SMALLEST_PRESS_BEFORE.x
			and Look.REFIT_SLOT_SIZE_PX.y >= SMALLEST_PRESS_BEFORE.y,
		"슬롯 띠 상자도 220x64 보다 크다")

	# The strip and the two buttons, inside the screen and clear of each other.
	for s in Rules.summon_slot_count():
		t.ok(SCREEN.encloses(view.slot_hit_rect_of(s)), "슬롯 %d번 상자가 화면 안이다" % s)
	t.ok(SCREEN.encloses(view.done_hit_rect()), "완료 단추(닫힘)가 화면 안이다")
	t.ok(SCREEN.encloses(view.done_rect().grow(Look.PRESS_HIT_PAD_PX)), "완료 단추(열림 자리)도 화면 안이다")
	t.ok(SCREEN.encloses(view.back_hit_rect()), "뒤로 단추가 화면 안이다")
	t.ok(not view.back_hit_rect().intersects(Look.refit_done_rect_px(true).grow(Look.PRESS_HIT_PAD_PX)),
		"뒤로와 완료(열린 자리)가 안 겹친다")

	# The hit test, at each cell's own centre.
	for p in Rules.part_count():
		t.eq(view.cell_hit_rect_of(p), Look.refit_cell_hit_rect_px(p), "%d번 칸 판정이 look.gd 값이다" % p)
	t.eq(view.cell_rect_of(-1), Rect2(), "없는 칸의 사각형은 빈 Rect2 다")
	t.eq(view.cell_rect_of(Rules.part_count()), Rect2(), "범위 밖 칸도 빈 Rect2 다")
	view.free()


## 「더미 자리가 한 판에서 얻을 수 있는 부위 수보다 많다」 — the demand is a LITERAL beside the
## capacity, not the same formula read on both sides, for the reason `panel_view`'s own roster ceiling
## already carries: a capacity that shrinks with the formula it is checked against proves nothing.
func _the_capacity(t) -> void:
	var demand := Rules.CARD_PICKS * Rules.map_max_card_nodes_on_a_route()
	t.ok(Look.refit_held_capacity() >= demand,
		"더미 자리 %d개가 한 판이 낼 수 있는 최대 부위 %d개를 담는다"
			% [Look.refit_held_capacity(), demand])


# -- the strip and the board, both steps -------------------------------------------------------------

## 「처음엔 슬롯 띠만 보이고 칸은 안 보인다」 · 「슬롯을 누르면 그 슬롯의 판이 열린다」 · 「연 슬롯이
## 띠에서 밝고 나머지는 어둡다」 — driven on a bare view (no `Run` needed for the strip alone; a fresh
## `Loadout` reads its own zero values).
func _the_strip_and_the_board(t) -> void:
	var r := Run.new()
	var spy := RefitSpy.new()
	t.root.add_child(spy)
	spy.process_mode = Node.PROCESS_MODE_DISABLED
	spy.bind(r)
	spy.queue_redraw()
	await t.pump_frames(2)
	t.ok(spy.draws >= 1, "정비 화면의 _draw 가 트리 위에서 진짜 돌았다 (자가 점검) — run.state() 는 아직 REFIT 이 아니다서 0장이어야 한다")

	# `_draw` gates on `run.state() == REFIT`, so nothing is on screen yet on a fresh MAP-state run —
	# self-check that the spy is actually wired before trusting the zero below.
	t.eq(spy.slot_boxes.size(), 0, "REFIT 상태가 아니면 슬롯 띠조차 안 그려진다 (자가 점검)")

	# Force the run into REFIT the short way — one win, two cards — so the screen actually draws.
	r.enter_node(0)
	r.finish_island(true)
	r.take_card(0)
	r.take_card(1)
	t.eq(r.state(), Run.State.REFIT, "카드 둘을 고르면 정비다 (자가 점검)")
	spy.queue_redraw()
	await t.pump_frames(1)

	t.eq(spy.slot_boxes.size(), Rules.summon_slot_count(), "슬롯 띠 상자를 슬롯 수만큼 그렸다")
	t.eq(spy.slot_labels.size(), Rules.summon_slot_count(), "슬롯 이름표도 그만큼 그렸다")
	t.eq(spy.cell_boxes.size(), 0, "칸은 아직 하나도 안 열렸다 — 판이 안 보인다")
	t.eq(spy.held_rows.size(), 0, "더미 줄도 아직 없다")
	t.eq(spy.stat_values.size(), 0, "대시보드 숫자도 아직 없다")
	t.eq(spy.bodies.size(), 0, "몸 미리보기도 아직 없다")

	# 「연 슬롯이 띠에서 밝고 나머지는 어둡다」 — before any slot is opened, every strip box reads the
	# SAME (unlit) alpha; there is nothing to compare yet, so this is the self-check that the rest of
	# the row means something.
	var rest_a := (spy.slot_boxes[0]["bg"] as Color).a
	var rest_b := (spy.slot_boxes[1]["bg"] as Color).a
	t.ok(is_equal_approx(rest_a, rest_b), "아무 슬롯도 안 열렸을 때는 둘 다 같은 밝기다 (자가 점검)")

	# 「슬롯을 누르면 그 슬롯의 판이 열린다」
	spy.open_slot(0)
	t.eq(spy.open_slot_index(), 0, "0번 슬롯을 열었다")
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.cell_boxes.size(), Rules.part_count(), "판을 열자 칸 상자를 부위 수만큼 그렸다")
	t.eq(spy.cell_parts.size(), Rules.part_count(), "칸마다 부위 글자도 그렸다")
	t.eq(spy.cell_species.size(), Rules.part_count(), "칸마다 종 글자 자리도 그렸다 (빈 칸은 '-')")
	t.eq(spy.stat_values.size(), Rules.PART_COL_TOTAL, "대시보드 숫자 다섯도 그렸다")
	t.eq(spy.bodies.size(), 1, "몸 미리보기를 하나 그렸다")
	t.eq(spy.buttons.size(), 2, "완료와 뒤로, 단추 둘을 그렸다")

	# 「연 슬롯이 띠에서 밝고 나머지는 어둡다」, now that one actually is.
	var lit := (spy.slot_boxes[0]["bg"] as Color)
	var dark := (spy.slot_boxes[1]["bg"] as Color)
	t.ok(lit.a / dark.a >= 3.0,
		"연 슬롯이 나머지보다 알파가 3배 넘게 밝다 (%.2f / %.2f = %.1f배)" % [lit.a, dark.a, lit.a / dark.a])

	# The strip stays drawn on step two, and the boxes do not move.
	t.eq(spy.slot_boxes.size(), Rules.summon_slot_count(), "판이 열려도 슬롯 띠는 그대로 둘 다 그려진다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- fitting and unfitting, through the real door ----------------------------------------------------

## Walks a fresh `Game` from the title through a win to `REFIT`, taking both cards, and hands back the
## `Game` sitting there with `game.refit_view` already swapped for a `RefitSpy`.
func _reach_refit(t) -> Game:
	var game := Game.new()
	t.root.add_child(game)
	await t.pump_frames(2)

	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	game._unhandled_input(_press(Look.map_node_pos_px(0)))
	game._process(Look.MAP_TRAVEL_SEC)
	t.ok(game.battle != null, "섬이 열렸다 (자가 점검)")

	var tile := -1
	for pt in game.battle.grid.passable.size():
		if game.battle.grid.home_harbour_for(pt) >= 0:
			tile = pt
			break
	t.ok(tile >= 0 and game.battle.send(0, tile) >= 0 and game.battle.commit(),
		"한 명 보내고 시작을 눌렀다 (자가 점검)")
	game.battle.enemy_alive.fill(0)
	game._process(Rules.SIM_SUBSTEP_SEC * 2.0)
	t.eq(game.battle.outcome(), Battle.Outcome.WON, "섬을 이겼다 (자가 점검)")
	game._process(Look.HOLD_OUTCOME_SEC)
	t.eq(game.run.state(), Run.State.PICK, "카드 고르기가 열렸다 (자가 점검)")

	# Swap the spy in before the board ever opens, exactly as `net_slots` swaps `field_view`/`hud_view`
	# after `_open_island`: a spy starts blank, so a deleted wiring line leaves every capture empty
	# rather than merely different.
	game.remove_child(game.refit_view)
	game.refit_view.queue_free()
	var spy := RefitSpy.new()
	game.refit_view = spy
	game.add_child(spy)

	game._unhandled_input(_click(Look.card_rect_px(0).get_center()))
	game._unhandled_input(_click(Look.card_rect_px(1).get_center()))
	t.eq(game.run.state(), Run.State.REFIT, "카드 둘을 고르자 정비 화면이 열렸다 (자가 점검)")
	return game


func _fitting_through_the_shell(t) -> void:
	var game := await _reach_refit(t)
	var spy := game.refit_view as RefitSpy

	game._unhandled_input(_click(Look.refit_slot_hit_rect_px(0).get_center()))
	t.eq(game.refit_view.open_slot_index(), 0, "0번 슬롯을 눌러 판을 열었다")

	var loadout := game.run.army.loadout
	var want_part := int(loadout.held_part[0])
	var want_species := int(loadout.held_species[0])
	var pile_before := loadout.held_part.size()

	# 「더미의 부위를 누르면 그 부위의 칸에 들어간다」 — mutation: `game.gd`'s `_refit_input`'s `fit`
	# call becomes a no-op, which only a press through the real shell can catch.
	game._unhandled_input(_click(Look.refit_held_rect_px(0).get_center()))
	t.eq(loadout.fitted_species(0, want_part), want_species, "더미 0번을 누르자 그 부위의 칸에 그 종이 들어갔다")
	t.eq(loadout.held_part.size(), pile_before - 1, "그리고 더미가 하나 줄었다")

	# 「채워진 칸을 누르면 더미로 돌아온다」
	var pile_after_fit := loadout.held_part.size()
	game._unhandled_input(_click(Look.refit_cell_rect_px(want_part).get_center()))
	t.eq(loadout.fitted_species(0, want_part), -1, "채워진 칸을 누르자 다시 비었다")
	t.eq(loadout.held_part.size(), pile_after_fit + 1, "더미가 하나 늘었다")
	t.eq(int(loadout.held_species[loadout.held_species.size() - 1]), want_species,
		"돌아온 카드의 종이 그대로다")

	# 「빈 칸을 눌러도 아무 일도 안 난다」 — every cell is empty again at this point except none.
	var empty_part := -1
	for p in Rules.part_count():
		if loadout.fitted_species(0, p) < 0:
			empty_part = p
			break
	t.ok(empty_part >= 0, "빈 칸이 하나 있다 (자가 점검)")
	var pile_before_noop := loadout.held_part.size()
	game._unhandled_input(_click(Look.refit_cell_rect_px(empty_part).get_center()))
	t.eq(loadout.held_part.size(), pile_before_noop, "빈 칸을 눌러도 더미 크기가 그대로다")
	t.eq(loadout.fitted_species(0, empty_part), -1, "그리고 그 칸도 여전히 비어 있다")

	# 뒤로, then the strip alone again; 완료 closes the board and the run reaches MAP.
	game._unhandled_input(_click(Look.refit_back_rect_px().get_center()))
	t.eq(spy.open_slot_index(), -1, "뒤로를 누르면 판이 닫힌다")

	# 「완료를 누르면 지도로 간다」
	game._unhandled_input(_click(Look.refit_done_rect_px(false).get_center()))
	t.eq(game.run.state(), Run.State.MAP, "완료를 누르면 지도로 간다")
	t.ok(game.battle == null, "그리고 battle 도 null 이다")

	t.root.remove_child(game)
	game.queue_free()


# -- the dashboard --------------------------------------------------------------------------------

## ⚠⚠ 「대시보드 다섯 숫자가 전투가 읽는 숫자와 같은 함수에서 나온다」 — both halves. First, a fresh
## slot's empty board reads the exact literals `net_parts` already pins for `Loadout.stat_of`; second,
## every DRAWN value is compared against `loadout.stat_of(slot, col)` directly, so a view that computed
## its own (correct, by accident) number would still be caught the day it drifts.
func _the_dashboard_reads_the_same_function_the_fight_does(t) -> void:
	var game := await _reach_refit(t)
	var spy := game.refit_view as RefitSpy

	game._unhandled_input(_click(Look.refit_slot_hit_rect_px(0).get_center()))
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.stat_values.size(), Rules.PART_COL_TOTAL, "슬롯을 열자 대시보드 숫자 다섯이 그려졌다")

	# The literal floor: an untouched slot 0 (CELL_MELEE) reads 14 / 2 / 1.0 / 0 / 4, exactly the
	# values `net_parts`'s 「빈 판의 숫자는 UNITS 그대로다」 pins for `Loadout.stat_of` itself.
	var want_literals := [14.0, 2.0, 1.0, 0.0, 4.0]
	var literal_bad := 0
	for col in Rules.PART_COL_TOTAL:
		var shown := str(spy.stat_values[col]["text"]).to_float()
		if not is_equal_approx(shown, want_literals[col]):
			literal_bad += 1
	t.eq(literal_bad, 0, "빈 0번 슬롯의 대시보드가 리터럴 14 · 2 · 1.0 · 0 · 4 를 그대로 보여준다")

	var loadout := game.run.army.loadout
	var same_bad := 0
	for col in Rules.PART_COL_TOTAL:
		var shown := str(spy.stat_values[col]["text"]).to_float()
		if not is_equal_approx(shown, loadout.stat_of(0, col)):
			same_bad += 1
	t.eq(same_bad, 0, "다섯 숫자 모두 loadout.stat_of 가 내놓는 값과 화면에 찍힌 값이 같다")

	# ⚠ 「부위를 끼우면 그 자리에서 숫자가 움직인다」 — the HP row moves and the other four stay
	# byte-identical, read back on the SAME captured frame batch a fit lands in.
	var before_texts: Array[String] = []
	for col in Rules.PART_COL_TOTAL:
		before_texts.append(str(spy.stat_values[col]["text"]))

	var held_part := int(loadout.held_part[0])
	var held_species := int(loadout.held_species[0])
	game._unhandled_input(_click(Look.refit_held_rect_px(0).get_center()))
	t.eq(loadout.fitted_species(0, held_part), held_species, "카드를 끼웠다 (자가 점검)")

	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.stat_values.size(), Rules.PART_COL_TOTAL, "끼운 뒤에도 숫자 다섯이 그려진다 (자가 점검)")
	var col_moved_count := 0
	var col_unmoved_bad := 0
	for col in Rules.PART_COL_TOTAL:
		var now_text := str(spy.stat_values[col]["text"])
		var bonus := Rules.part_bonus(held_part, col)
		if not is_equal_approx(bonus, 0.0):
			col_moved_count += 1
			t.ok(now_text != before_texts[col],
				"끼운 부위가 움직이는 칸(col %d)의 숫자가 실제로 바뀌었다 (%s -> %s)"
					% [col, before_texts[col], now_text])
		else:
			if now_text != before_texts[col]:
				col_unmoved_bad += 1
	t.ok(col_moved_count >= 1, "끼운 부위가 적어도 한 칸을 움직였다 (자가 점검)")
	t.eq(col_unmoved_bad, 0, "끼운 부위가 안 움직이는 나머지 칸은 숫자 하나도 안 바뀌었다")

	# And it is the SAME call combat reads — `army.max_hp_of` for the fitted slot's own soldiers.
	game.run.army.recruit(0)
	var new_id := game.run.army.type_id.size() - 1
	t.eq(game.run.army.slot_id[new_id], 0, "0번 슬롯에서 병사를 하나 더 뽑았다 (자가 점검)")
	t.ok(is_equal_approx(game.run.army.max_hp_of(new_id), loadout.stat_of(0, Rules.PART_COL_HP)),
		"그 병사의 만피가 대시보드가 보여주는 그 체력 숫자와 정확히 같다")

	t.root.remove_child(game)
	game.queue_free()


# -- the body preview ---------------------------------------------------------------------------------

## 「미리보기 몸이 슬롯마다 다르다」 — both channels: radius AND corner rounding, and both slots draw
## with a positive radius (so neither is comparing a live shape against a collapsed one).
func _the_body_differs_per_slot(t) -> void:
	var game := await _reach_refit(t)
	var spy := game.refit_view as RefitSpy

	game._unhandled_input(_click(Look.refit_slot_hit_rect_px(0).get_center()))
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.bodies.size(), 1, "0번 슬롯의 몸을 하나 그렸다 (자가 점검)")
	var body0: Dictionary = spy.bodies[0]

	game._unhandled_input(_click(Look.refit_slot_hit_rect_px(1).get_center()))
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.bodies.size(), 1, "1번 슬롯의 몸도 하나 그렸다 (자가 점검)")
	var body1: Dictionary = spy.bodies[0]

	t.ok(float(body0["radius"]) > 0.0 and float(body1["radius"]) > 0.0,
		"두 몸 다 반지름이 0보다 크다 (자가 점검 — 하나가 0이면 아래 비교가 공짜다)")
	t.ok(not is_equal_approx(float(body0["radius"]), float(body1["radius"])),
		"두 슬롯의 몸이 반지름부터 다르다 (%.1f vs %.1f)" % [body0["radius"], body1["radius"]])
	t.ok(not is_equal_approx(float(body0["corner"]), float(body1["corner"])),
		"그리고 모서리 둥글기도 다르다 (%.2f vs %.2f)" % [body0["corner"], body1["corner"]])

	t.root.remove_child(game)
	game.queue_free()


# -- input helpers, identical shape to net_shell's -----------------------------------------------------

func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _press(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev
