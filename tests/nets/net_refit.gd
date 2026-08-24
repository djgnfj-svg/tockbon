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
	var helds := []
	var held := []
	var stat_labels := []
	var stat_values := []
	var bodies := []
	var buttons := []
	var fades := []
	var hints := []
	var tag_rows := []

	func _draw() -> void:
		slot_boxes.clear()
		slot_labels.clear()
		cell_boxes.clear()
		cell_parts.clear()
		cell_species.clear()
		held_rows.clear()
		helds.clear()
		held.clear()
		stat_labels.clear()
		stat_values.clear()
		bodies.clear()
		buttons.clear()
		fades.clear()
		hints.clear()
		tag_rows.clear()
		super()
		draws += 1

	func _paint_slot_box(rect: Rect2, bg: Color, edge: Color, edge_width: float) -> void:
		slot_boxes.append({"rect": rect, "bg": bg, "edge": edge, "width": edge_width})

	func _paint_slot_label(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		slot_labels.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_cell_box(rect: Rect2, bg: Color, edge: Color, edge_width: float) -> void:
		cell_boxes.append({"rect": rect, "bg": bg, "edge": edge, "width": edge_width})

	func _paint_cell_name(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		cell_parts.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_cell_effect(face: Font, at: Vector2, text: String, width: float, fsize: int,
			col: Color) -> void:
		cell_species.append({"at": at, "text": text, "width": width, "fsize": fsize, "col": col})

	func _paint_held_row(rect: Rect2, bg: Color, edge: Color, edge_width: float) -> void:
		held_rows.append({"rect": rect, "bg": bg, "edge": edge, "width": edge_width})

	func _paint_held_name(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		helds.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_held_effect(face: Font, at: Vector2, text: String, width: float, fsize: int,
			col: Color) -> void:
		held.append({"at": at, "text": text, "width": width, "fsize": fsize, "col": col})

	func _paint_stat_label(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		stat_labels.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_stat_value(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		stat_values.append({"at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_body(centre: Vector2, radius: float, corner: float, colour: Color) -> void:
		bodies.append({"centre": centre, "radius": radius, "corner": corner, "col": colour})

	func _paint_button(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
			col: Color) -> void:
		buttons.append({"rect": rect, "bg": bg, "text": text, "at": at, "fsize": fsize, "col": col})

	func _paint_fade(rect: Rect2, col: Color) -> void:
		fades.append({"rect": rect, "col": col})

	func _paint_hint(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		hints.append({"face": face, "at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_tag_row(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		tag_rows.append({"at": at, "text": text, "fsize": fsize, "col": col})


const SCREEN := Rect2(0.0, 0.0, 1280.0, 720.0)
const SMALLEST_PRESS_BEFORE := Vector2(220.0, 64.0)


func run(t) -> void:
	_the_geometry(t)
	_the_capacity(t)
	await _the_strip_and_the_board(t)
	await _fitting_through_the_shell(t)
	await _the_dashboard_reads_the_same_function_the_fight_does(t)
	await _the_cell_flashes_when_a_part_lands(t)
	await _the_body_differs_per_slot(t)
	await _the_screen_itself_fades_in(t)
	await _the_text_layer_is_read(t)
	await _pressing_past_the_pile_end_does_nothing(t)
	await _the_tag_rows(t)
	await _a_boxless_species_takes_a_card_through_the_shell(t)
	_every_effect_line_fits_its_box(t)


# -- geometry: can it be aimed at ------------------------------------------------------------------

func _the_geometry(t) -> void:
	var view := RefitView.new()

	# 「판은 여섯 칸이고 겹치지 않고 화면 안이다」 — floor: six hit rects inside the literal screen;
	# ⚠⚠ ceiling: no two hit rects come within 1 px of each other (`intersects` excludes shared
	# borders, so a gap of exactly 0 would still read as "no overlap").
	var outside := 0
	var overlapping := 0
	for p in Rules.ITEM_CELLS:
		var drawn := view.cell_rect_of(p)
		var hit := view.cell_hit_rect_of(p)
		if not SCREEN.encloses(hit):
			outside += 1
		if drawn.size.x <= 0.0 or drawn.size.y <= 0.0:
			outside += 1
		for q in range(p + 1, Rules.ITEM_CELLS):
			if hit.grow(1.0).intersects(view.cell_hit_rect_of(q).grow(1.0)):
				overlapping += 1
	t.eq(outside, 0, "칸 여섯의 판정 사각형이 전부 화면 안이고 넓이가 0이 아니다")
	t.eq(overlapping, 0, "어느 두 칸의 판정 사각형도 1px 안으로도 안 붙는다")

	# ⚠⚠ 「어느 칸의 판정도 슬롯 띠나 완료/뒤로 단추와 안 겹친다」 — cells were checked against EACH
	# OTHER above and never against the OTHER region drawn on the same frame the board is open. The
	# BELLY cell's centre used to land inside slot 1's hit rect (nothing in `look.gd` ever compared
	# the two), and the board's bottom row shared a 4 px seam with both step-two buttons (their own
	# 8 px pad was left out of the comparison that was supposed to clear it). Both are geometry that
	# stays wrong until something measures the CROSS product, not the board alone.
	var done_open_hit := Look.refit_done_rect_px(true).grow(Look.PRESS_HIT_PAD_PX)
	var cross := 0
	for p in Rules.ITEM_CELLS:
		var hit := view.cell_hit_rect_of(p).grow(1.0)
		for s in Rules.TYPE_COUNT:
			if hit.intersects(view.slot_hit_rect_of(s).grow(1.0)):
				cross += 1
		if hit.intersects(done_open_hit.grow(1.0)):
			cross += 1
		if hit.intersects(view.back_hit_rect().grow(1.0)):
			cross += 1
	t.eq(cross, 0, "어느 칸의 판정 사각형도 슬롯 띠나 완료(열린 자리)/뒤로 단추와 1px 안으로도 안 겹친다")

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

	# The strip — five beast boxes now — and the two buttons, inside the screen and clear of each other.
	for s in Rules.TYPE_COUNT:
		t.ok(SCREEN.encloses(view.slot_hit_rect_of(s)), "짐승 %d번 상자가 화면 안이다" % s)
	# The strip boxes themselves never touch each other — the same 1px demand the cells carry.
	var strip_overlap := 0
	for s in Rules.TYPE_COUNT:
		for q in range(s + 1, Rules.TYPE_COUNT):
			if view.slot_hit_rect_of(s).grow(1.0).intersects(view.slot_hit_rect_of(q).grow(1.0)):
				strip_overlap += 1
	t.eq(strip_overlap, 0, "다섯 상자의 판정 사각형이 1px 안으로도 안 붙는다")
	t.ok(SCREEN.encloses(view.done_hit_rect()), "완료 단추(닫힘)가 화면 안이다")
	t.ok(SCREEN.encloses(view.done_rect().grow(Look.PRESS_HIT_PAD_PX)), "완료 단추(열림 자리)도 화면 안이다")
	t.ok(SCREEN.encloses(view.back_hit_rect()), "뒤로 단추가 화면 안이다")
	t.ok(not view.back_hit_rect().intersects(Look.refit_done_rect_px(true).grow(Look.PRESS_HIT_PAD_PX)),
		"뒤로와 완료(열린 자리)가 안 겹친다")

	# The hit test, at each cell's own centre.
	for p in Rules.ITEM_CELLS:
		t.eq(view.cell_hit_rect_of(p), Look.refit_cell_hit_rect_px(p), "%d번 칸 판정이 look.gd 값이다" % p)
	t.eq(view.cell_rect_of(-1), Rect2(), "없는 칸의 사각형은 빈 Rect2 다")
	t.eq(view.cell_rect_of(Rules.ITEM_CELLS), Rect2(), "범위 밖 칸도 빈 Rect2 다")

	# ⚠⚠ item 7 — 「대시보드 다섯 줄이 화면 안이고 판의 칸과 안 겹친다」. `REFIT_STAT_ORIGIN_PX`/
	# `REFIT_STAT_PITCH_PX` used to stack the five numbers straight down the board's own left edge,
	# starting at the board's own y — two of the five landed on top of board cells and the fifth sat
	# past the bottom of a 720 px screen. Mutation A (off-screen): `REFIT_STAT_ORIGIN_PX` ->
	# `Vector2(80.0, 700.0)`. Mutation B (on the board): `REFIT_STAT_ORIGIN_PX` -> `Vector2(80.0, 340.0)`.
	var stat_outside := 0
	var stat_on_board := 0
	for col in Rules.ITEM_COL_TOTAL:
		var row_rect := Look.refit_stat_rect_px(col)
		if not SCREEN.encloses(row_rect):
			stat_outside += 1
		for p in Rules.ITEM_CELLS:
			if row_rect.intersects(view.cell_rect_of(p)):
				stat_on_board += 1
	t.eq(stat_outside, 0, "대시보드 다섯 줄이 전부 화면 안이다")
	t.eq(stat_on_board, 0, "그리고 어느 줄도 판의 칸과 안 겹친다")

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

	t.eq(spy.slot_boxes.size(), Rules.TYPE_COUNT, "짐승 상자를 다섯 종 전부만큼 그렸다 — 소환 칸 수가 아니다")
	t.eq(spy.slot_labels.size(), Rules.TYPE_COUNT, "짐승 이름표도 그만큼 그렸다")
	# 「라벨이 짐승 이름이다」 — mutation: the label text back to "슬롯 %d".
	var label_bad := 0
	for s in Rules.TYPE_COUNT:
		if str(spy.slot_labels[s]["text"]) != HudView.type_label(s):
			label_bad += 1
	t.eq(label_bad, 0, "상자마다 그 짐승의 이름이 적힌다 — 슬롯 번호가 아니다")
	t.eq(spy.cell_boxes.size(), 0, "칸은 아직 하나도 안 열렸다 — 판이 안 보인다")
	t.eq(spy.held_rows.size(), 0, "더미 줄도 아직 없다")
	t.eq(spy.stat_values.size(), 0, "대시보드 숫자도 아직 없다")
	t.eq(spy.bodies.size(), 0, "몸 미리보기도 아직 없다")
	# The tag aggregate is army-wide, so it is on screen from step one — a 「무리」 header plus one
	# line per tag, the header being what says these numbers are nobody's single box.
	t.eq(spy.tag_rows.size(), Rules.tag_kind_count() + 1, "딱지 집계가 띠 단계에서도 머리말+딱지 수만큼 그려진다")
	t.eq(str(spy.tag_rows[0]["text"]), "무리", "첫 줄이 「무리」 머리말이다 — 이 숫자들은 한 짐승의 것이 아니다")

	# 「아무 것도 안 열렸을 때 안내 글이 있다」 — this screen used to have no line of text anywhere
	# saying what it is or that a slot presses.
	t.eq(spy.hints.size(), 1, "슬롯이 하나도 안 열렸을 때 안내 글을 하나 그렸다")

	# 「연 슬롯이 띠에서 밝고 나머지는 어둡다」 — before any slot is opened, every strip box reads the
	# SAME (unlit) alpha; there is nothing to compare yet, so this is the self-check that the rest of
	# the row means something.
	var rest_a := (spy.slot_boxes[0]["bg"] as Color).a
	var rest_b := (spy.slot_boxes[1]["bg"] as Color).a
	t.ok(is_equal_approx(rest_a, rest_b), "아무 슬롯도 안 열렸을 때는 둘 다 같은 밝기다 (자가 점검)")
	# ⚠ **Both boxes ARE pressable here — pressing either one opens it.** `PRESS_ALPHA_OFF` is the
	# SAME tone the title screen uses for a slot that cannot be pressed at all; painting it on a box
	# that presses says the opposite of what is true. Mutation: `refit_view.gd`'s `lit := s ==
	# _open_slot` (drop the `or _open_slot < 0`), which paints both dim before anything is chosen.
	t.eq(rest_a, Look.PRESS_ALPHA_ON,
		"그리고 그 밝기가 '눌린다'는 밝기다 (%.2f) — '눌리지 않는다'는 밝기(%.2f)가 아니다"
			% [rest_a, Look.PRESS_ALPHA_OFF])

	# 「슬롯을 누르면 그 슬롯의 판이 열린다」
	spy.open_slot(0)
	t.eq(spy.open_slot_index(), 0, "0번 슬롯을 열었다")
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.cell_boxes.size(), Rules.ITEM_CELLS, "판을 열자 칸 상자를 부위 수만큼 그렸다")
	t.eq(spy.cell_parts.size(), Rules.ITEM_CELLS, "칸마다 부위 글자도 그렸다")
	t.eq(spy.cell_species.size(), Rules.ITEM_CELLS, "칸마다 종 글자 자리도 그렸다 (빈 칸은 '-')")
	t.eq(spy.stat_values.size(), Rules.ITEM_COL_TOTAL, "대시보드 숫자 다섯도 그렸다")
	t.eq(spy.bodies.size(), 1, "몸 미리보기를 하나 그렸다")
	t.eq(spy.buttons.size(), 2, "완료와 뒤로, 단추 둘을 그렸다")
	t.eq(spy.hints.size(), 0, "판이 열리면 안내 글은 사라진다 — 판 자체가 이제 안내다")
	t.eq(spy.tag_rows.size(), Rules.tag_kind_count() + 1, "판이 열려도 딱지 집계 줄은 그대로 그려진다")

	# 「연 슬롯이 띠에서 밝고 나머지는 어둡다」, now that one actually is.
	var lit := (spy.slot_boxes[0]["bg"] as Color)
	var dark := (spy.slot_boxes[1]["bg"] as Color)
	t.ok(lit.a / dark.a >= 3.0,
		"연 슬롯이 나머지보다 알파가 3배 넘게 밝다 (%.2f / %.2f = %.1f배)" % [lit.a, dark.a, lit.a / dark.a])

	# The strip stays drawn on step two, and the boxes do not move.
	t.eq(spy.slot_boxes.size(), Rules.TYPE_COUNT, "판이 열려도 짐승 띠는 다섯 전부 그대로 그려진다")

	# ⚠ 「호버가 테두리만이 아니라 채움도 밝힌다」 — the card screen and the map both carry hover on
	# TWO channels (border width AND fill brightness); this screen's own slot/cell/held boxes used to
	# get only the first. `Look.hover_lit` lightens the fill by `PRESS_HOVER_BRIGHTEN`, alpha
	# untouched, so this reads the RGB and not the alpha the row above already pins.
	var dim_slot1 := (spy.slot_boxes[1]["bg"] as Color)
	spy.set_hover(spy.slot_rect_of(1).get_center())
	spy._fx_step(Look.PRESS_HOVER_SEC)
	spy.queue_redraw()
	await t.pump_frames(1)
	var hovered_slot1 := (spy.slot_boxes[1]["bg"] as Color)
	t.ok(hovered_slot1.r > dim_slot1.r or hovered_slot1.g > dim_slot1.g or hovered_slot1.b > dim_slot1.b,
		"어두운 슬롯도 호버하면 채움 색 자체가 밝아진다 — 테두리만 굵어지는 게 아니다")
	t.ok(is_equal_approx(hovered_slot1.a, dim_slot1.a),
		"그 밝기 변화는 알파가 아니라 RGB 다 — 위의 알파 비율 행과 다른 채널이다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- fitting and unfitting, through the real door ----------------------------------------------------

## Walks a fresh `Game` from the title through a win to `REFIT`, taking both cards, and hands back the
## `Game` sitting there with `game.refit_view` already swapped for a `RefitSpy`.
## ⚠⚠ `seed` is REQUIRED, not optional with a hidden default — every call site below names one, so
## which seed produced which card sequence is legible at the call, the same reason `net_cards._won_run`
## takes one. **Before this, `Run._reset` (`_rng.randomize()`) drove every draw here**, so which held
## card `_fitting_through_the_shell` pressed, and which dashboard column
## `_the_dashboard_reads_the_same_function_the_fight_does` watched climb, were a different experiment
## every round — the BELLY-cell workaround below existed only because of this, and the dashboard row
## bound only whichever one column the draw happened to move.
func _reach_refit(t, seed: int) -> Game:
	var game := Game.new()
	t.root.add_child(game)
	await t.pump_frames(2)

	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	t.ok(game.run != null, "런이 시작됐다 (자가 점검)")
	game.run.seed_cards(seed)
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
	var game := await _reach_refit(t, 1)
	var spy := game.refit_view as RefitSpy

	game._unhandled_input(_click(Look.refit_slot_hit_rect_px(0).get_center()))
	t.eq(game.refit_view.open_slot_index(), 0, "0번 슬롯을 눌러 판을 열었다")

	var loadout := game.run.army.loadout

	# ⚠⚠ **FIXED — every cell, INCLUDING 배(BELLY), presses at the spot it is drawn.**
	# `Look.refit_cell_rect_px(2)`'s centre (670, 390) used to land inside slot 1's own hit rect
	# (452..828, 336..472) — `look.gd`'s two regions were laid out with no line ever comparing them —
	# so a press aimed at the BELLY cell opened slot 1 instead. The strip moved out of the board's way
	# (see `look.gd`'s `REFIT_SLOT_ORIGIN_PX`); this walks all six cell centres through the real
	# shell's own hit-test order (`slot_at` asked before `cell_at`, `_refit_input`'s own order, which
	# does not change) and requires every one of them to resolve to its own cell and to no slot.
	var slot_bad := 0
	var cell_bad := 0
	for p in Rules.ITEM_CELLS:
		var centre := Look.refit_cell_rect_px(p).get_center()
		if game.refit_view.slot_at(centre) != -1:
			slot_bad += 1
		if game.refit_view.cell_at(centre) != p:
			cell_bad += 1
	t.eq(slot_bad, 0, "여섯 칸의 한가운데 중 어느 것도 슬롯 띠 판정 안에 들지 않는다 — 배 칸 포함")
	t.eq(cell_bad, 0, "여섯 칸의 한가운데를 누르면 그 칸 자신이 열린다 — 배 칸 포함")

	var want_idx := 0
	var want_item := int(loadout.held[want_idx])
	# ⚠ **The target is the board's first empty cell, not anything the card names.** Cells have no
	# names, so this is the only thing that decides where a press lands.
	var want_cell := loadout.first_empty(0)
	var pile_before := loadout.held.size()

	# 「더미의 카드를 누르면 빈 칸에 들어간다」 — mutation: `game.gd`'s `_refit_input`'s `fit`
	# call becomes a no-op, which only a press through the real shell can catch.
	game._unhandled_input(_click(Look.refit_held_rect_px(want_idx).get_center()))
	t.eq(loadout.fitted_item(0, want_cell), want_item, "더미 칸을 누르자 첫 빈 칸에 그 장비가 들어갔다")
	t.eq(loadout.held.size(), pile_before - 1, "그리고 더미가 하나 줄었다")

	# 「채워진 칸을 누르면 더미로 돌아온다」
	var pile_after_fit := loadout.held.size()
	game._unhandled_input(_click(Look.refit_cell_rect_px(want_cell).get_center()))
	t.eq(loadout.fitted_item(0, want_cell), -1, "채워진 칸을 누르자 다시 비었다")
	t.eq(loadout.held.size(), pile_after_fit + 1, "더미가 하나 늘었다")
	t.eq(int(loadout.held[loadout.held.size() - 1]), want_item,
		"돌아온 카드의 종이 그대로다")

	# 「빈 칸을 눌러도 아무 일도 안 난다」 — every cell is empty again at this point except none.
	var empty_part := -1
	for p in Rules.ITEM_CELLS:
		if loadout.fitted_item(0, p) < 0:
			empty_part = p
			break
	t.ok(empty_part >= 0, "빈 칸이 하나 있다 (자가 점검)")
	var pile_before_noop := loadout.held.size()
	game._unhandled_input(_click(Look.refit_cell_rect_px(empty_part).get_center()))
	t.eq(loadout.held.size(), pile_before_noop, "빈 칸을 눌러도 더미 크기가 그대로다")
	t.eq(loadout.fitted_item(0, empty_part), -1, "그리고 그 칸도 여전히 비어 있다")

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
	var game := await _reach_refit(t, 1)
	var spy := game.refit_view as RefitSpy

	game._unhandled_input(_click(Look.refit_slot_hit_rect_px(0).get_center()))
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.stat_values.size(), Rules.ITEM_COL_TOTAL, "슬롯을 열자 대시보드 숫자 다섯이 그려졌다")

	# The literal floor: an untouched slot 0 (CELL_MELEE) reads 14 / 2 / 1.0 / 0 / 4, exactly the
	# values `net_parts`'s 「빈 판의 숫자는 UNITS 그대로다」 pins for `Loadout.stat_of` itself.
	# ⚠ Compared as TEXT against `"%.1f" % literal`, never as a re-parsed float against the raw one —
	# see the ceiling row below for the rounding-boundary reason a raw/re-parsed pair is the wrong
	# comparison on this screen.
	var want_literals := [14.0, 2.0, 1.0, 0.0, 4.0]
	var literal_bad := 0
	for col in Rules.ITEM_COL_TOTAL:
		if str(spy.stat_values[col]["text"]) != "%.1f" % want_literals[col]:
			literal_bad += 1
	t.eq(literal_bad, 0, "빈 0번 슬롯의 대시보드가 리터럴 14 · 2 · 1.0 · 0 · 4 를 그대로 보여준다")

	var loadout := game.run.army.loadout
	var same_bad := 0
	for col in Rules.ITEM_COL_TOTAL:
		if str(spy.stat_values[col]["text"]) != "%.1f" % loadout.stat_of(0, col):
			same_bad += 1
	t.eq(same_bad, 0, "다섯 숫자 모두 loadout.stat_of 가 내놓는 값과 화면에 찍힌 값이 같다")

	# ⚠ 「부위를 끼우면 그 자리에서 숫자가 움직인다」, and item 6's climb on top of it — both floors:
	# right after the fit the moved column is already off its resting value AND has not yet snapped to
	# the target either (mid-flight, not a jump); the other four stay byte-identical throughout.
	var before_texts: Array[String] = []
	for col in Rules.ITEM_COL_TOTAL:
		before_texts.append(str(spy.stat_values[col]["text"]))

	# ⚠ **The CELL is asked before the click, the ITEM after** — the pile compacts under a fit, so the
	# card's own id has to be taken first and the cell it lands in is the board's first empty one.
	var fitting := int(loadout.held[0])
	var landing := loadout.first_empty(0)
	game._unhandled_input(_click(Look.refit_held_rect_px(0).get_center()))
	t.eq(loadout.fitted_item(0, landing), fitting, "카드를 끼웠다 (자가 점검)")

	var moved_col := -1
	for col in Rules.ITEM_COL_TOTAL:
		if not is_equal_approx(Rules.item_bonus(fitting, col), 0.0):
			moved_col = col
			break
	t.ok(moved_col >= 0, "끼운 부위가 적어도 한 칸을 움직인다 (자가 점검)")
	var target := loadout.stat_of(0, moved_col)

	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.stat_values.size(), Rules.ITEM_COL_TOTAL, "끼운 직후에도 숫자 다섯이 그려진다 (자가 점검)")
	var just_after := str(spy.stat_values[moved_col]["text"]).to_float()
	t.ok(not is_equal_approx(just_after, target),
		"끼운 직후 대시보드 숫자가 아직 도착값 %.1f 로 안 튄다 (%.1f) — 스냅이 아니라 climb 이다"
			% [target, just_after])
	var col_unmoved_bad := 0
	for col in Rules.ITEM_COL_TOTAL:
		if col == moved_col:
			continue
		var now_text := str(spy.stat_values[col]["text"])
		if now_text != before_texts[col]:
			col_unmoved_bad += 1
	t.eq(col_unmoved_bad, 0, "끼운 부위가 안 움직이는 나머지 칸은 숫자 하나도 안 바뀌었다")

	# ⚠⚠ The ceiling: without it, deleting the whole climb (multiplying `_stat_age`'s delta by 0.0)
	# would still pass the floor above forever, because a number frozen at its OLD value also never
	# equals the target. Aged past `MAP_HEAL_SEC`, the shown number has to land EXACTLY on it.
	spy._fx_step(Look.MAP_HEAL_SEC)
	spy.queue_redraw()
	await t.pump_frames(1)
	# ⚠ **Compared as TEXT, not as a re-parsed float.** `target` is the raw 64-bit value and a value
	# sitting near a `%.1f` rounding boundary (0.15's own binary approximation puts a HAND-fitted
	# period a hair off 0.85) reads back from its OWN formatted text at up to 0.05 away from that raw
	# value — a gap `is_equal_approx` reads as a real mismatch though nothing on screen is wrong. The
	# question this row asks is "did the picture format the SAME number the sim holds", and formatting
	# both sides the same way is the only comparison that answers it rather than the rounding table.
	var landed_text := str(spy.stat_values[moved_col]["text"])
	var want_text := "%.1f" % target
	t.eq(landed_text, want_text,
		"%.2f초가 지나면 대시보드 숫자가 정확히 도착값(%s)에 닿는다 (%s) — 흐린 채로 안 남는다"
			% [Look.MAP_HEAL_SEC, want_text, landed_text])
	t.ok(Look.MAP_HEAL_SEC >= 0.30 and Look.MAP_HEAL_SEC <= 1.00,
		"숫자가 오르는 시간이 0.30~1.00초다 (%.2f)" % Look.MAP_HEAL_SEC)

	# ⚠⚠ **All FIVE columns, not only `moved_col`.** The row above already proved the MOVED column is
	# `stat_of`'s own value; the seed fixes which held part gets fitted, so which single column moves
	# would otherwise be a coin flip run to run and only 2 of 6 parts ever move HP — a view that
	# rendered `Rules.hp_of(type)` for the OTHER four (the exact mutation §8.3 names) would still pass
	# a check that only re-verified the one column that changed. Every column, moved or not, is
	# re-read against `loadout.stat_of` here, now that the board is non-empty.
	var post_fit_bad := 0
	for col in Rules.ITEM_COL_TOTAL:
		var shown := str(spy.stat_values[col]["text"])
		var want_col_text := "%.1f" % loadout.stat_of(0, col)
		if shown != want_col_text:
			post_fit_bad += 1
	t.eq(post_fit_bad, 0,
		"낀 뒤에도 다섯 숫자 모두 loadout.stat_of 와 같다 — 움직인 한 칸만이 아니라 다섯 다")

	# And it is the SAME call combat reads — `army.max_hp_of` for the fitted slot's own soldiers.
	game.run.army.recruit(0)
	var new_id := game.run.army.type_id.size() - 1
	t.eq(game.run.army.slot_id[new_id], 0, "0번 슬롯에서 병사를 하나 더 뽑았다 (자가 점검)")
	t.ok(is_equal_approx(game.run.army.max_hp_of(new_id), loadout.stat_of(0, Rules.ITEM_COL_HP)),
		"그 병사의 만피가 대시보드가 보여주는 그 체력 숫자와 정확히 같다")

	t.root.remove_child(game)
	game.queue_free()


# -- the body preview ---------------------------------------------------------------------------------

## 「미리보기 몸이 슬롯마다 다르다」 — both channels: radius AND corner rounding, and both slots draw
## with a positive radius (so neither is comparing a live shape against a collapsed one).
func _the_body_differs_per_slot(t) -> void:
	var game := await _reach_refit(t, 1)
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


# -- item 5: the cell flash ----------------------------------------------------------------------------

## 「부위를 끼우면 그 칸이 채워지는 게 보인다」 — floor: right after the fit the cell has not yet
## snapped to its full alpha; ceiling: aged past `REFIT_CELL_FILL_SEC` it lands exactly there. A
## second, untouched cell never moves at all, on either frame — the flash belongs to the one cell a
## part just landed in and to no other.
##
## ⚠⚠ Bounded on both ends for the same reason the card reveal is: a beat proven only not to overshoot
## can be deleted outright and still pass.
func _the_cell_flashes_when_a_part_lands(t) -> void:
	var game := await _reach_refit(t, 1)
	var spy := game.refit_view as RefitSpy

	game._unhandled_input(_click(Look.refit_slot_hit_rect_px(0).get_center()))
	spy.queue_redraw()
	await t.pump_frames(1)

	var loadout := game.run.army.loadout
	# ⚠ **The cell, not the card.** This was `int(loadout.held[0])` — the card's own part id, which
	# named its target back when cells had names. An item id is not a cell index and reads off the end.
	var landing_part := loadout.first_empty(0)
	# A cell that is neither the one about to be fitted nor already filled, read at rest first.
	var quiet_part := -1
	for p in Rules.ITEM_CELLS:
		if p != landing_part:
			quiet_part = p
			break
	var quiet_rest := (spy.cell_boxes[quiet_part]["bg"] as Color).a

	game._unhandled_input(_click(Look.refit_held_rect_px(0).get_center()))
	t.ok(loadout.fitted_item(0, landing_part) >= 0, "카드를 끼웠다 (자가 점검)")

	spy.queue_redraw()
	await t.pump_frames(1)
	var just_after := (spy.cell_boxes[landing_part]["bg"] as Color).a
	t.ok(just_after < Look.PRESS_ALPHA_ON - 0.02,
		"끼운 직후 그 칸의 알파가 아직 다 찬 값(%.2f)에 안 닿는다 (%.2f) — 스냅이 아니라 채워지는 중이다"
			% [Look.PRESS_ALPHA_ON, just_after])
	t.ok(just_after > Look.PRESS_ALPHA_OFF + 0.02,
		"그래도 빈 칸 알파(%.2f)보다는 이미 밝다 (%.2f) — 채우기가 실제로 시작됐다"
			% [Look.PRESS_ALPHA_OFF, just_after])
	var quiet_now := (spy.cell_boxes[quiet_part]["bg"] as Color).a
	t.eq(quiet_now, quiet_rest, "끼우지 않은 칸은 이 프레임에도 알파가 한 톨도 안 움직였다")

	spy._fx_step(Look.REFIT_CELL_FILL_SEC)
	spy.queue_redraw()
	await t.pump_frames(1)
	var landed := (spy.cell_boxes[landing_part]["bg"] as Color).a
	t.ok(is_equal_approx(landed, Look.PRESS_ALPHA_ON),
		"%.2f초가 지나면 그 칸이 정확히 다 찬 알파 %.2f 에 닿는다 (%.2f) — 흐린 채로 안 남는다"
			% [Look.REFIT_CELL_FILL_SEC, Look.PRESS_ALPHA_ON, landed])
	t.ok(Look.REFIT_CELL_FILL_SEC >= 0.084 and Look.REFIT_CELL_FILL_SEC <= 0.50,
		"칸이 차는 시간이 다섯 프레임~0.50초다 (%.2f)" % Look.REFIT_CELL_FILL_SEC)

	t.root.remove_child(game)
	game.queue_free()


# -- item 7: the screen's own arrival -------------------------------------------------------------------

## ⚠⚠ 「정비 화면도 배경에서 떠오른다」 — both ends, `map_view`'s own scene-wash shape, reused. This
## screen had no reveal clock of its own before this round (`_reveal_age` is new) — two captures 0.4s
## apart used to be byte-identical, a hard cut with nothing on screen saying the screen had changed.
## Floor: right after `bind` the wash is still up, near-full alpha. Ceiling: aged past `SCENE_FADE_SEC`
## the leaf is not even CALLED (the `if wash > 0.0` guard `map_view`'s own site shares) — bounded only
## above, a deleted wash would also pass.
func _the_screen_itself_fades_in(t) -> void:
	var r := Run.new()
	t.ok(r.enter_node(0), "0번 칸을 밟는다 (자가 점검)")
	r.finish_island(true)
	r.take_card(0)
	r.take_card(1)
	t.eq(r.state(), Run.State.REFIT, "정비 화면이 열렸다 (자가 점검)")

	var spy := RefitSpy.new()
	t.root.add_child(spy)
	spy.process_mode = Node.PROCESS_MODE_DISABLED
	spy.bind(r)
	spy.queue_redraw()
	await t.pump_frames(2)
	t.eq(spy.fades.size(), 1, "묶인 직후엔 화면 자체의 흐림이 아직 떠 있다")
	t.ok((spy.fades[0]["col"] as Color).a > 0.5,
		"그 흐림의 알파가 절반 넘게 짙다 (%.2f)" % (spy.fades[0]["col"] as Color).a)
	t.eq(spy.fades[0]["rect"], Rect2(Vector2.ZERO, Look.viewport_size_px()), "흐림이 화면 전체를 덮는다")

	spy._fx_step(Look.SCENE_FADE_SEC)
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.fades.size(), 0, "SCENE_FADE_SEC 이 지나면 흐림 호출 자체가 없다 — 다 사라진 뒤에도 계속 그리지 않는다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- item 3: the text layer is captured AND read -----------------------------------------------------

## `RefitSpy` was already storing `cell_parts` · `cell_species` · `slot_labels` · `stat_labels` ·
## `helds` · `held`, but nothing anywhere read a single "text" field back — `.size()` on
## five of them, nothing on `stat_labels`/`helds`/`held` at all. Four independent
## mutations, each caught by its own row, `net_cards`' own shape (compare the drawn text against the
## label table) copied rather than re-invented.
func _the_text_layer_is_read(t) -> void:
	var game := await _reach_refit(t, 3)
	var spy := game.refit_view as RefitSpy
	var loadout := game.run.army.loadout

	game._unhandled_input(_click(Look.refit_slot_hit_rect_px(0).get_center()))
	spy.queue_redraw()
	await t.pump_frames(1)

	# ⚠⚠ **INVERTED BY THE REWRITE** (2026-08-24). This used to read 「every cell draws its own part
	# name」 — head, chest, belly, arm, hand, leg. **Cells have no names now**, so what has to be true is
	# the opposite: an empty cell draws a dash, and it draws it in EVERY cell.
	# Mutation it holds: `_paint_cell_name`'s text pinned to the first item's name.
	var cell_bad := 0
	for p in Rules.ITEM_CELLS:
		if str(spy.cell_parts[p]["text"]) != "-":
			cell_bad += 1
	t.eq(cell_bad, 0, "아무 것도 안 낀 여섯 칸은 이름 자리에 전부 '-' 를 그린다 — 칸에 붙은 이름은 없다")
	# ⚠⚠ **INVERTED.** This used to be 「the six cell labels are all DIFFERENT」 — six part names. An
	# empty board draws the same dash six times now, so what has to be true is that they are all the
	# SAME, and the row above is what proves the dash is what they are.
	var cell_text_set := {}
	for p in Rules.ITEM_CELLS:
		cell_text_set[str(spy.cell_parts[p]["text"])] = true
	t.eq(cell_text_set.size(), 1, "빈 판의 여섯 글자는 전부 같은 '-' 다 — 칸에는 이름이 없다")

	# 「대시보드 다섯 이름표가 저마다 자기 줄이다」 — mutation: `_paint_stat_label`'s text argument
	# becomes `STAT_LABELS[0]` for every row — all five drawn as 「체력」.
	var stat_bad := 0
	for col in Rules.ITEM_COL_TOTAL:
		if str(spy.stat_labels[col]["text"]) != str(RefitView.STAT_LABELS[col]):
			stat_bad += 1
	t.eq(stat_bad, 0, "다섯 줄의 이름표가 저마다 자기 칸의 이름이다")
	var stat_text_set := {}
	for col in Rules.ITEM_COL_TOTAL:
		stat_text_set[str(spy.stat_labels[col]["text"])] = true
	t.eq(stat_text_set.size(), Rules.ITEM_COL_TOTAL, "그리고 다섯 글자가 서로 다 다르다")

	# 「더미 줄이 실제 더미 크기만큼 그려진다」 — mutation: `_draw_board`'s held loop becomes
	# `for row in 0`, so the held pile vanishes from the screen while the sim still holds it.
	t.ok(loadout.held.size() > 0, "더미에 카드가 있다 (자가 점검)")
	t.eq(spy.held_rows.size(), loadout.held.size(),
		"더미 줄이 실제 더미 크기만큼 그려진다 — 강제로 0으로 줄지 않았다")

	# 「더미 줄마다 그 카드의 이름이 적힌다」 — mutation: `_paint_held_name` draws the first item's name
	# for every row, so the pile reads as six copies of one card.
	var held_bad := 0
	for row in mini(loadout.held.size(), spy.helds.size()):
		var want := Rules.item_name_of(int(loadout.held[row]))
		if str(spy.helds[row]["text"]) != want:
			held_bad += 1
	t.eq(held_bad, 0, "더미 줄마다 그 줄이 든 장비의 이름이 적힌다")

	# 「빈 칸은 효과 줄이 비어 있고, 낀 칸은 그 장비가 하는 일을 적는다」 — mutation: `_paint_cell_effect`'s
	# text is pinned to "" regardless of `filled`, so a fitted item never says what it does.
	var empty_bad := 0
	for p in Rules.ITEM_CELLS:
		if str(spy.cell_species[p]["text"]) != "":
			empty_bad += 1
	t.eq(empty_bad, 0, "아직 아무 것도 안 낀 칸 여섯은 효과 줄이 비어 있다 (자가 점검)")

	var landing_item := int(loadout.held[0])
	var landing_cell := loadout.first_empty(0)
	game._unhandled_input(_click(Look.refit_held_rect_px(0).get_center()))
	t.eq(loadout.fitted_item(0, landing_cell), landing_item, "한 칸에 카드를 꼈다 (자가 점검)")
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(str(spy.cell_parts[landing_cell]["text"]), Rules.item_name_of(landing_item),
		"낀 칸에 그 장비의 이름이 뜬다 — '-' 로 안 눌러앉는다")
	t.eq(str(spy.cell_species[landing_cell]["text"]), Rules.item_effect_text(landing_item),
		"그리고 그 장비가 하는 일도 같이 뜬다")
	# 어두운 판 위의 등급 색 — 카드용 어두운 등급 표(COL_RARITY)가 여기서 두 번 가라앉았다.
	# Mutation: the effect colour back to `COL_RARITY[rarity]`.
	t.eq(spy.cell_species[landing_cell]["col"] as Color,
		Look.COL_RARITY_TEXT_DARK[Rules.item_rarity_of(landing_item)] as Color,
		"낀 칸의 효과 줄 색이 어두운 판용 등급 색이다 — 카드용 어두운 표가 아니다")

	t.root.remove_child(game)
	game.queue_free()


# -- item 5: the pile's twin of the board's own empty-cell row ----------------------------------------

## 「더미 자리가 실제 더미보다 많을 때, 넘치는 자리를 눌러도 아무 일도 안 난다」 — the board already
## carries this row for an empty CELL (「빈 칸을 눌러도 아무 일도 안 난다」); the pile never had its own,
## and the pile is the one side where "the row exists as a geometric target" and "the row names a real
## card" can disagree — `refit_held_capacity()` is 10, a fresh pick pays 2. Mutation: `refit_view.gd`'s
## `held_at` bound `mini(n, Look.refit_held_capacity())` -> `Look.refit_held_capacity()`.
func _pressing_past_the_pile_end_does_nothing(t) -> void:
	var game := await _reach_refit(t, 3)
	var loadout := game.run.army.loadout

	game._unhandled_input(_click(Look.refit_slot_hit_rect_px(0).get_center()))
	var pile_n := loadout.held.size()
	t.ok(pile_n > 0 and pile_n < Look.refit_held_capacity(),
		"더미가 차 있지만 다 안 찼다 (자가 점검, %d / %d)" % [pile_n, Look.refit_held_capacity()])

	t.eq(game.refit_view.held_at(Look.refit_held_rect_px(pile_n).get_center()), -1,
		"더미 크기 바로 다음 자리는 아무 것도 판정되지 않는다 — 카드가 없는 자리다")

	var board_before := loadout.board.duplicate()
	# ⚠ **One array now, not two.** The pile used to be two index-aligned arrays (part and species) and
	# was checked twice; a card is one item, so there is one row to compare.
	var pile_before := loadout.held.duplicate()
	game._unhandled_input(_click(Look.refit_held_rect_px(pile_n).get_center()))
	t.eq(loadout.held.size(), pile_n, "그 자리를 눌러도 더미 크기가 그대로다")
	t.eq(loadout.held, pile_before, "더미 줄도 그대로다")
	t.eq(loadout.board, board_before, "그리고 어느 칸도 안 바뀌었다")

	t.root.remove_child(game)
	game.queue_free()


# -- ticket 11: the tag aggregate lines ---------------------------------------------------------------

## 「딱지 집계가 표의 개수·문턱과 같고, 켜진 줄만 켜짐 색이다」. ⚠ 문턱 기대값은 리터럴이다 —
## `tag_thresholds_of` 를 되읽으면 검사가 표와 같이 움직인다: 출혈 3 · 공속 3 · 범위 2 · 디버프 2.
## Mutations: the count pinned to 0 (a line that never moves) · the lit colour painted on every row ·
## the rows fed `tag_count` of one board instead of the horde.
func _the_tag_rows(t) -> void:
	var r := Run.new()
	t.ok(r.enter_node(0), "0번 칸을 밟는다 (자가 점검)")
	r.finish_island(true)
	r.take_card(0)
	r.take_card(1)
	t.eq(r.state(), Run.State.REFIT, "정비 화면이 열렸다 (자가 점검)")
	var spy := RefitSpy.new()
	t.root.add_child(spy)
	spy.process_mode = Node.PROCESS_MODE_DISABLED
	spy.bind(r)
	spy.queue_redraw()
	await t.pump_frames(2)

	# At rest nothing is fitted, so every line reads 0 over its own FIRST threshold, unlit. Row 0 is
	# the 「무리」 header; the tags sit at rows 1..4.
	t.eq(spy.tag_rows.size(), Rules.tag_kind_count() + 1, "집계 줄이 머리말+딱지 수만큼 있다 (자가 점검)")
	var first_thresholds := [3, 3, 2, 2]
	var rest_bad := 0
	var rest_lit := 0
	for g in Rules.tag_kind_count():
		if str(spy.tag_rows[g + 1]["text"]) != "%s 0/%d" % [Rules.tag_label_of(g), first_thresholds[g]]:
			rest_bad += 1
	for row in spy.tag_rows:
		if ((row as Dictionary)["col"] as Color) == Look.COL_TAG_LIT:
			rest_lit += 1
	t.eq(rest_bad, 0, "빈 무리의 네 줄이 전부 「이름 0/첫 문턱」이다 — 문턱 리터럴은 3·3·2·2")
	t.eq(rest_lit, 0, "그리고 켜짐 색인 줄이 하나도 없다 — 머리말 포함")

	# Two range items onto the LION board — a board with no summon slot, so this row doubles as "the
	# aggregate counts the whole horde".
	var lo := r.army.loadout
	for _i in 2:
		lo.take_card(10)   # 뺏은 창끝 — 범위 딱지
		lo.fit(Rules.LION, lo.held.size() - 1)
	t.eq(lo.tag_count(Rules.Tag.RANGE), 2, "범위 딱지 둘을 사자 판에 꼈다 (자가 점검)")
	spy.queue_redraw()
	await t.pump_frames(1)
	var range_row: Dictionary = spy.tag_rows[Rules.Tag.RANGE + 1]
	t.eq(str(range_row["text"]), "%s 2/4" % Rules.tag_label_of(Rules.Tag.RANGE),
		"범위 줄이 「2/4」 — 개수와 다음 문턱을 같이 말한다")
	t.eq(range_row["col"] as Color, Look.COL_TAG_LIT, "1층이 켜진 범위 줄만 켜짐 색이다")
	var others_lit := 0
	for g in Rules.tag_kind_count():
		if g != Rules.Tag.RANGE and (spy.tag_rows[g + 1]["col"] as Color) == Look.COL_TAG_LIT:
			others_lit += 1
	t.eq(others_lit, 0, "안 켜진 세 줄은 여전히 켜짐 색이 아니다")

	# Two more — the top tier: the count stands alone, no next threshold to name.
	for _i in 2:
		lo.take_card(10)
		lo.fit(Rules.LION, lo.held.size() - 1)
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(str(spy.tag_rows[Rules.Tag.RANGE + 1]["text"]), "%s 4" % Rules.tag_label_of(Rules.Tag.RANGE),
		"꼭대기 층이 켜지면 「4」 — 다음 문턱이 없으니 숫자만 남는다")
	t.eq(spy.tag_rows[Rules.Tag.RANGE + 1]["col"] as Color, Look.COL_TAG_LIT, "여전히 켜짐 색이다")

	t.root.remove_child(spy)
	spy.queue_free()


## 「소환 칸에 없는 짐승도 정비에서 장비를 받는다」 — 사용자의 「버리는 것도 주워서 안쓰는 자기
## 몬스터에게도 넣을 수 있게」가 화면까지 닿았다는 검사. 진짜 셸을 지나 들소 상자를 열고, 카드를
## 끼우고, 도로 뺀다. Mutation: `game.gd`'s `_refit_input` keying the fit back onto a summon slot.
func _a_boxless_species_takes_a_card_through_the_shell(t) -> void:
	var game := await _reach_refit(t, 1)
	var spy := game.refit_view as RefitSpy
	game._unhandled_input(_click(Look.refit_slot_hit_rect_px(Rules.BISON).get_center()))
	t.eq(game.refit_view.open_slot_index(), Rules.BISON, "소환 칸 없는 들소 상자가 눌려 열린다")
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.bodies.size(), 1, "들소 판에도 몸 미리보기가 하나 그려진다 (자가 점검)")
	# ⚠ The preview is keyed on the OPEN TYPE itself — keyed back through `summon_type_of` a slotless
	# species answers -1 and the preview draws the wrong body.
	t.ok(is_equal_approx(float((spy.bodies[0] as Dictionary)["radius"]),
			Look.body_radius_of(Rules.BISON) * Look.REFIT_BODY_SCALE),
		"그 몸의 반지름이 들소 자신의 것이다 — 소환 칸을 거꾸로 물어본 몸이 아니다")

	var loadout := game.run.army.loadout
	t.ok(loadout.held.size() > 0, "더미에 카드가 있다 (자가 점검)")
	var want_item := int(loadout.held[0])
	var want_cell := loadout.first_empty(Rules.BISON)
	game._unhandled_input(_click(Look.refit_held_rect_px(0).get_center()))
	t.eq(loadout.fitted_item(Rules.BISON, want_cell), want_item,
		"들소 판에 그 장비가 들어갔다 — 버리는 카드가 없다")

	game._unhandled_input(_click(Look.refit_cell_rect_px(want_cell).get_center()))
	t.eq(loadout.fitted_item(Rules.BISON, want_cell), -1, "그 칸을 누르면 도로 나온다")
	t.eq(int(loadout.held[loadout.held.size() - 1]), want_item, "그리고 더미로 돌아왔다")

	t.root.remove_child(game)
	game.queue_free()


# -- ticket 11 fix round: no effect line leaves its box -----------------------------------------------

## 「어느 장비의 효과 줄도 제 상자를 안 넘친다」 — 열여덟 전부, 평균이 아니라 전수로 (말린 힘줄의 줄이
## 더미 상자 밖 배경까지 흘렀다 — verify-look). 가로는 word-wrap 폭, 세로는 폰트 메트릭으로 잰
## 마지막 줄의 밑선+내림획이 상자 바닥 안이어야 한다. Mutation: `REFIT_HELD_EFFECT_FONT_SIZE_PX`
## 16 -> 18 — 두 줄이 64px 상자를 못 들어간다. (잎을 도로 `draw_string`으로 되돌리는 변이는
## `net_draw_leaf`의 안-쓰인-인자 검사가 문다 — width 가 남는다.)
func _every_effect_line_fits_its_box(t) -> void:
	var face := HudView.default_font()
	t.ok(face != null, "폰트를 얻었다 (자가 점검)")
	if face == null:
		return
	var cell_bad := 0
	var held_bad := 0
	var wide_bad := 0
	var multiline_seen := 0
	for i in Rules.item_count():
		var text := Rules.item_effect_text(i)
		for probe in [
			[Look.REFIT_CELL_EFFECT_WRAP_W_PX, Look.REFIT_CELL_SPECIES_FONT_SIZE_PX,
				Look.REFIT_CELL_EFFECT_OFFSET_PX.y, Look.REFIT_CELL_SIZE_PX.y, true],
			[Look.REFIT_HELD_EFFECT_WRAP_W_PX, Look.REFIT_HELD_EFFECT_FONT_SIZE_PX,
				Look.REFIT_HELD_EFFECT_OFFSET_PX.y, Look.REFIT_HELD_SIZE_PX.y, false],
		]:
			var wrap_w := float(probe[0])
			var fsize := int(probe[1])
			var first_baseline := float(probe[2])
			var box_h := float(probe[3])
			var size := face.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fsize)
			var line_h := face.get_height(fsize)
			var lines := maxi(1, roundi(size.y / line_h))
			if lines > 1:
				multiline_seen += 1
			# The last baseline plus its descenders, against the box bottom.
			var bottom := first_baseline + float(lines - 1) * line_h + face.get_descent(fsize)
			if bottom > box_h:
				if bool(probe[4]):
					cell_bad += 1
				else:
					held_bad += 1
			if size.x > wrap_w + 1.0:
				wide_bad += 1
	t.eq(cell_bad, 0, "열여덟 효과 줄 전부가 칸 상자 세로 안이다")
	t.eq(held_bad, 0, "열여덟 효과 줄 전부가 더미 상자 세로 안이다")
	t.eq(wide_bad, 0, "그리고 어느 줄도 감싼 폭을 가로로 안 넘는다 — 낱말 하나가 폭보다 큰 경우가 없다")
	t.ok(multiline_seen > 0,
		"실제로 두 줄로 감기는 장비가 있다 (자가 점검, %d건) — 전부 한 줄이면 이 검사는 아무것도 안 잰다"
			% multiline_seen)


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
