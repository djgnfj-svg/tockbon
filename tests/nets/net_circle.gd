extends RefCounted
## The circle table and the assembly state. **Everything caught here is of the "silently wrong with no error" kind.**
##
##  · **packing an empty layer** — pack an empty layer as is and `GLYPH_NONE = 0` means "end of list", so the glyphs
##    in later layers **evaporate entirely.** On screen it only looks like "putting something in layer 2 alone does nothing"
##  · **an empty rune read as fire** — `ELEM_FIRE = 0`, so using 0 as the empty value makes the assembly window draw
##    a blank while firing sends out fire. `_empty_rune_is_not_a_rune` below pins that trap down as a contract
##  · **two copies of the rules** — if `fire()` rejects an arrangement the assembly window let through,
##    it becomes "clicking does nothing". `_both_ways_agree` below is the only thing that measures this
##  · **hardcoded constants** — hardcode the layer count as 2 and growing the circle does not grow it; only the table ages
##
## **The assembly window's drawing cannot be measured by this net in principle** (plan section 7). That is the eye's share.
##  Here only **the model and the rules** are looked at.

const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Stage := preload("res://src/stage/stage.gd")
## There has to be a net that **actually calls** the layout functions, or behavior the text scan cannot see goes uncaught.
const Layout := preload("res://src/view/circle_layout.gd")
const Book := preload("res://src/view/book_layout.gd")
const Palette := preload("res://src/view/palette_layout.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const Progress := preload("res://src/actor/progress.gd")
const CircleWindow := preload("res://src/view/circle_window.gd")
## Step 5's own consumers — driving `SpellCircle.shots()` all the way through `WorldStep`'s queue, not just
##  reading the dictionaries it returns. A check that never steps a real `WorldStep` cannot tell "three shots
##  queued with delays" from "three shots that actually land on the right ticks" (CLAUDE.md, ordering contracts).
const WorldStep := preload("res://src/actor/world_step.gd")
const Character := preload("res://src/actor/character.gd")

## **Records which draw primitives actually ran and with what data** — the same technique
## `net_attack_predict._GeometryRecordingView` already proved (override the primitives, record, still call
## `super` so a real crash inside them is still caught the way it already was). This is what a bare
## `t.ok(true, ...)` after `pump_frames` cannot be: that only proves `_draw()` was *reached*, not that its
## loops ran (verify-read, mutation: deleting the three draw calls inside `_draw()` left every check in this
## file green — `t.ok(true, ...)` is flagged in CLAUDE.md's own terms as "a label claiming more than the
## check measures").
class _RecordingCircleWindow extends CircleWindow:
	var frame_calls := 0
	var triangle_frame_calls := 0
	var wrap_ring_calls: Array[float] = []
	var link_calls: Array[Dictionary] = []
	var ornament_calls: Array[Dictionary] = []
	var rune_slot_calls := 0
	var ring_calls := 0
	var ring_edges: Array[Array] = []          # one entry per _draw_ring call: the edge radii it actually stroked
	var glyph_draws: Array[int] = []           # glyph ids drawn procedurally (_draw_glyph)
	var texture_draws: Array[Dictionary] = []  # {glyph_id, tex} for each socket-texture draw
	var rarity_ring_calls: Array[int] = []     # glyph id passed to the socket's own rarity ring
	var empty_slot_calls := 0
	var slot_ring_calls: Array[Dictionary] = []  # {"at": Vector2, "r": float} per _draw_slot_ring call

	func _draw_frame(area: Rect2, circle_id: int) -> void:
		frame_calls += 1
		super._draw_frame(area, circle_id)

	func _draw_triangle_frame(area: Rect2, f: Dictionary, circle_id: int) -> void:
		triangle_frame_calls += 1
		super._draw_triangle_frame(area, f, circle_id)

	func _draw_triangle_wrap_ring(center: Vector2, r: float) -> void:
		wrap_ring_calls.append(r)
		super._draw_triangle_wrap_ring(center, r)

	func _draw_triangle_links(centers: PackedVector2Array, width: float) -> void:
		link_calls.append({"count": centers.size(), "width": width})
		super._draw_triangle_links(centers, width)

	func _draw_triangle_ornament(center: Vector2, outer_r: float, band: float) -> void:
		ornament_calls.append({"outer_r": outer_r, "band": band})
		super._draw_triangle_ornament(center, outer_r, band)

	func _draw_rune_slot(area: Rect2, circle_id: int) -> void:
		rune_slot_calls += 1
		super._draw_rune_slot(area, circle_id)

	func _draw_ring(area: Rect2, circle_id: int, layer: int, font: Font) -> void:
		ring_calls += 1
		# A new bucket **before** calling super — `_draw_ring_edge` below appends into whichever bucket is
		#  last, so each `_draw_ring` call gets its own list of the radii it actually stroked (empty if the
		#  call returns early, e.g. an out-of-range layer, which none of this file's scenarios exercise).
		ring_edges.append([])
		super._draw_ring(area, circle_id, layer, font)

	func _draw_ring_edge(center: Vector2, r: float, col: Color) -> void:
		if not ring_edges.is_empty():
			(ring_edges[ring_edges.size() - 1] as Array).append(r)
		super._draw_ring_edge(center, r, col)

	func _draw_glyph(at: Vector2, r: float, glyph_id: int) -> void:
		glyph_draws.append(glyph_id)
		super._draw_glyph(at, r, glyph_id)

	func _draw_socket_glyph_texture(at: Vector2, r: float, tex: Texture2D, glyph_id: int) -> void:
		texture_draws.append({"glyph_id": glyph_id, "tex": tex})
		super._draw_socket_glyph_texture(at, r, tex, glyph_id)

	func _draw_socket_rarity_ring(at: Vector2, r: float, glyph_id: int) -> void:
		rarity_ring_calls.append(glyph_id)
		super._draw_socket_rarity_ring(at, r, glyph_id)

	func _draw_empty_slot(at: Vector2, r: float) -> void:
		empty_slot_calls += 1
		super._draw_empty_slot(at, r)

	## **Captures the ring's own arguments, not just that it ran** — the `notice_rect` lesson again: counting
	##  `empty_slot_calls` alone would stay green even if `_draw_empty_slot` handed this a bare `Vector2()`
	##  and `0.0`. `_draw_actually_runs_headless` below compares these to `circle_layout`'s own
	##  `layer_bands()` seat and `glyph_radius()`.
	func _draw_slot_ring(at: Vector2, r: float) -> void:
		slot_ring_calls.append({"at": at, "r": r})
		super._draw_slot_ring(at, r)
	# **Tabs and the 완성 band** (`onboarding-and-palette-tabs.md` Stage 1) — the same `settlement_layout.
	#  notice_rect` lesson every other hook in this class already guards against: a pure function asserted
	#  alone let `_draw()` hand it a bare `Rect2()` under 320 green checks.
	var tab_draws: Array[Dictionary] = []       # {rect, kind, is_open}, one per _draw_palette_tab call
	var done_draws: Array[Rect2] = []
	var section_draws: Array[Dictionary] = []   # {rect, kind}, the open tab's own body
	var empty_note_draws: Array[Rect2] = []

	func _draw_palette_tab(rect: Rect2, kind: int, is_open: bool) -> void:
		tab_draws.append({"rect": rect, "kind": kind, "is_open": is_open})
		super._draw_palette_tab(rect, kind, is_open)

	func _draw_palette_done(rect: Rect2, font: Font) -> void:
		done_draws.append(rect)
		super._draw_palette_done(rect, font)

	func _draw_palette_section(sec: Rect2, kind: int, font: Font) -> void:
		section_draws.append({"rect": sec, "kind": kind})
		super._draw_palette_section(sec, kind, font)

	func _draw_palette_empty_note(rect: Rect2, font: Font) -> void:
		empty_note_draws.append(rect)
		super._draw_palette_empty_note(rect, font)

	# **찰칵 and the 완성 glow** (Stage 6) — the seat/rect and the falling `t`, captured at the hook rather
	#  than re-derived, the same reason every hook above exists.
	var click_fx_calls: Array[Dictionary] = []   # {at, r, t}
	var done_glow_calls: Array[Dictionary] = []  # {at, r, t}

	func _draw_click_fx(at: Vector2, r: float, t: float) -> void:
		click_fx_calls.append({"at": at, "r": r, "t": t})
		super._draw_click_fx(at, r, t)

	func _draw_done_glow(at: Vector2, r: float, t: float) -> void:
		done_glow_calls.append({"at": at, "r": r, "t": t})
		super._draw_done_glow(at, r, t)

## The slack that comes from `Rect2` holding its values as **32-bit floats.** Used only when comparing a boundary
##  that "has to sit exactly flush" against 64-bit arithmetic — widen it and real overlaps get amnestied.
##
## **How big is the slack** (measured): the actual error is **7.6e-6** while this value is **0.01 — 1300 times larger.**
##  Shrinking it to `1e-4` still passes. **The generous side was chosen because "at 1/100 of a pixel it cannot hide
##  a visible overlap"** (insert a 1px intrusion and five checks go red), and **because the error varies with window size.**
##  => Not a danger today, but **grow it any further and that reasoning dies.**
const RECT_EPS := 0.01
## **Borrows** the comment/string stripper — two nets sweep source text, so there must be exactly one stripper.
const NetDeterminism := preload("res://tests/nets/net_determinism.gd")

## The accessors that have to read the table. When an accessor is added to `circle_defs`, add a line here —
##  without it, a new accessor returning a constant makes nobody bark.
## **Feeds `_accessors_read_the_table` alone.** That check asks "does the body contain `DEFS[`", which is true
##  of all four accessors including `seq_ticks` — `circle_layout` not calling `seq_ticks` (below) is a different
##  question from whether `seq_ticks` itself reads the table.
const ACCESSORS: Array[String] = ["layers", "rune_slots", "picture", "seq_ticks"]

## **Feeds `_layout_reads_the_table` alone — a narrower list than `ACCESSORS` above, on purpose.**
##  `circle_layout.gd` calls `layers`/`rune_slots`/`picture` to place seats and bands, but **not** `seq_ticks` —
##  the firing interval is `spell_circle`'s question, not the layout's. Reusing `ACCESSORS` here would demand
##  `circle_layout.gd` contain `CircleDefs.seq_ticks(`, which it correctly never will, and that check would go
##  red for the wrong reason (a real, working split misread as a missing table read).
const LAYOUT_ACCESSORS: Array[String] = ["layers", "rune_slots", "picture"]

## The paths used when looking for file references in the raw source. **Kept in one place** — scattered, the day a file
##  moves only one check goes stale, and the stale one passes as "absent" and goes quiet.
const LAYOUT_PATH := "res://src/view/circle_layout.gd"
const WINDOW_PATH := "res://src/view/circle_window.gd"
const BOOK_PATH := "res://src/view/book_layout.gd"
const PALETTE_PATH := "res://src/view/palette_layout.gd"

## The **floor** for the spell circle's diameter. It lives in the net because it is not a presentation constant but
##  **a verification contract** — it is the size the eye passed at stage 3, and going below it means facing that acceptance again.
##
## **The measurement changed twice:**
##
## | when | window | diameter | slack over the floor |
## |---|---|---|---|
## | stage 4a | 514x286 (28.4%) | 199.3 | **19.3px** — tight |
## | stage 4b-1 | 864x486 (**90%**) | **363.8** | **183.8px** |
## | `character-damage` stage 6 | 864x**372** (90% horizontally only) | **280.1** | **100.1px** |
##
## The last row is the window shrinking vertically **as the character became able to take damage** (user acceptance) —
##  health and the character have to stay visible during assembly. **The width is unchanged, so the diameter is decided by the height.**
##
## **The basis for the floor is still the single "the eye passed it at 199px"** — twice off from today's diameter, but
##  **it was not raised on that basis.** When verify-look passes a larger screen, **raise it then on that new observation.**
##  Raise it without a basis and only a number is left — exactly the shape this repo has kept catching.
##
## **That said, the 32px switch took it 180 -> 360, and that is "the same value", not "a raise".**
##  The px in the table above are all **world px**, and the screen scale went 2x -> 1x:
## ```
##  before: floor 180 world px x 2 = 360 screen px    diameter 280.1 x 2 = 560.2 screen px
##  after:  floor 360 world px x 1 = 360 screen px    diameter 560.2 x 1 = 560.2 screen px
## ```
##  => **Not one pixel of what the eye sees changed.** The slack is still 200.2 screen px.
## **The table above is an observation of the 16px world and is left as is** — read it as world px. Rewriting it makes it stop being an observation.
##
## What this value holds is "a size at which the two rings, the rune and the glyph symbols do not eat each other". Shrink the window or
##  grow the padding (`CIRCLE_AREA_PAD_PX`, `BOOK_MARGIN_PX`, `BOOK_FOLD_PX`) and this goes red first.
##  **Meeting it knowing the cause is not this constant** is what keeps "why is it suddenly red" from burning time.
const CIRCLE_DIAMETER_FLOOR_PX := 180.0


func run(t) -> void:
	await _the_ring_and_rune_art_actually_reaches_the_paint(t)
	await _the_palette_cards_are_drawn_from_the_art(t)
	_round_numbers_pinned_before_the_triangle_arrives(t)
	_sizes_come_from_the_table(t)
	_unknown_circle_barks(t)
	_empty_rune_is_not_a_rune(t)
	_swapping_the_circle_resizes(t)
	_resize_is_table_driven(t)
	_accessors_read_the_table(t)
	_book_pages_are_one_source(t)
	_circle_layout_does_not_know_pages(t)
	_spawn_rays_are_not_horizontal(t)
	_palette_is_kind_by_item(t)
	_owns_rune_gates_can_pick_on_an_untreed_window(t)
	_refusing_a_veiled_rune_then_clicking_the_seat_does_not_disarm(t)
	_one_click_inserts_when_there_is_only_one_seat(t)
	await _click_fx_flashes_at_the_seat_and_falls_to_zero(t)
	await _done_glow_then_close_fires_identically_to_tab(t)
	_symbols_are_shared(t)
	await _draw_actually_runs_headless(t)
	await _palette_tabs_and_done_are_drawn_from_the_layout(t)
	_hit_tests_match_the_drawing(t)
	_triangle_hit_shapes_stay_disjoint(t)
	_palette_geometry_runs(t)
	_layout_geometry_runs(t)
	_axes_do_not_call_each_other(t)
	_cannot_fire_without_a_rune(t)
	_empty_layer_is_skipped(t)
	_move_glyph_swaps_layers_and_never_duplicates(t)
	_seated_layers_matches_glyph_list_position_for_position(t)
	_the_glyph_tab_moves_a_seated_glyph_between_layers(t)
	_duplicate_dummy_glyphs_are_told_apart_by_layer(t)
	_round_trip(t)
	_cap_blocks_before_placing(t)
	_both_ways_agree(t)
	_presets_still_work(t)
	_preset_restores_everything(t)
	_unknown_id_after_a_capped_glyph_does_not_crash_the_window(t)
	_shots_geometry(t)
	_shots_fire_across_the_right_ticks(t)
	await _fire_at_loops_every_shot_not_just_the_first(t)
	await _fire_at_on_a_fresh_empty_circle_does_nothing(t)
	_socket_glyph_textures_load_and_are_288(t)
	_socket_glyph_ids_are_real_glyphs(t)
	_socket_glyph_families_do_not_cross(t)
	_set_loadout_preserves_the_equipped_circle(t)
	_revoke_unowned_rune_touches_every_socket(t)


## **The round circle's exact geometry, pinned by literal value — measured on today's `Fx.WINDOW_RECT`
##  once, right before step 4 adds `CIRCLE_TRIANGLE` to `ALL` and the round circle stops being the only
##  entry (its own control group until then, per the relational checks elsewhere in this file).**
##
## Everywhere else in this file measures **relationships** (grows inside-out, stays inside the frame,
##  does not overlap the rune) — true for infinitely many wrong values, not just today's right one. This is
##  the one check that would catch, for instance, step 4's `CircleDefs.picture()` branch accidentally being
##  taken by the round circle too, or a stray edit to `CIRCLE_RING_ZONE`/`CIRCLE_RUNE_RATIO` while wiring the
##  triangle's own constants — changes that could easily still satisfy every relational check above.
## Regenerate these numbers (`print()` from `Layout.frame/layer_bands/rune_radius/rune_slots` against
##  `Layout.circle_area(Book.circle_page(Fx.WINDOW_RECT.size).size)`) only if `Fx.WINDOW_RECT` or one of the
##  round circle's own ratios changes on purpose — never to make this check pass again after an accident.
##
## **Regenerated for `onboarding-and-palette-tabs.md` Stage 5** (`CIRCLE_RUNE_RATIO` 0.17 -> 0.26,
##  `CIRCLE_RING_ZONE` 0.80 -> 0.88, new `CIRCLE_RING_GAP_FRAC` 0.06). `f["radius"]` and the frame center are
##  untouched — neither `CIRCLE_DISC_RATIO` nor the window/page rects moved — so only the rune radius and the
##  two band numbers derived from it below actually changed.
func _round_numbers_pinned_before_the_triangle_arrives(t) -> void:
	var page := Book.circle_page(Fx.WINDOW_RECT.size)
	var area := Layout.circle_area(page.size)
	var id := CircleDefs.CIRCLE_ROUND

	var f := Layout.frame(area)
	t.ok(is_equal_approx(f["radius"], 140.06), "진 테두리 반지름이 못박은 값과 같다 (%.5f)" % (f["radius"] as float))
	t.ok((f["center"] as Vector2).is_equal_approx(Vector2(207.5, 163.0)),
		"진 중심이 못박은 값과 같다 (%s)" % f["center"])

	var bands := Layout.layer_bands(id, area)
	var want_edge0 := [84.036, 123.2528]
	var want_seat_y := [78.964, 39.7472]
	t.eq(bands.size(), want_edge0.size(), "밴드 수가 못박은 개수(%d)와 같다" % want_edge0.size())
	for i in mini(bands.size(), want_edge0.size()):
		var edges: PackedFloat32Array = bands[i]["edges"]
		var seat: Vector2 = bands[i]["seat"]
		var hit: Vector2 = bands[i]["hit"]
		t.ok(is_equal_approx(edges[0], want_edge0[i]),
			"%d번 밴드 바깥 모서리가 못박은 값과 같다 (%.5f)" % [i, edges[0]])
		t.ok(seat.is_equal_approx(Vector2(207.5, want_seat_y[i])),
			"%d번 밴드 자리가 못박은 값과 같다 (%s)" % [i, seat])
		# Every layer shares one hit radius on `PIC_ROUND` (`glyph_radius(area)` does not vary per layer) —
		#  pinned once and reused rather than repeated per band.
		t.ok(is_equal_approx(hit.y, 28.99242) and is_equal_approx(hit.x, 0.0),
			"%d번 밴드 히트 반경이 못박은 값과 같다 (%s)" % [i, hit])

	t.ok(is_equal_approx(Layout.rune_radius(id, area), 36.4156),
		"룬 반지름이 못박은 값과 같다 (%.5f)" % Layout.rune_radius(id, area))
	var rs := Layout.rune_slots(id, area)
	t.ok(rs.size() > 0 and rs[0].is_equal_approx(Vector2(207.5, 163.0)),
		"룬 자리가 못박은 값과 같다 (%s)" % (rs[0] if rs.size() > 0 else "없음"))


# ══════════════════════════════════════════════════════════════════
#  The circle table — the layer count and the rune slot count come from this one place
# ══════════════════════════════════════════════════════════════════

## **Is the assembly state derived from the table?** Hardcode 2 and 1 here and growing the circle does not grow it,
##  and then the assembly window draws the old layer count — with no error.
func _sizes_come_from_the_table(t) -> void:
	t.eq(CircleDefs.ALL.size(), CircleDefs.DEFS.size(), "ALL과 DEFS가 같다")
	# Without this line, an empty table leaves the loop below running zero times and **passing green.**
	t.ok(CircleDefs.ALL.size() > 0, "진이 하나라도 있다 (%d개)" % CircleDefs.ALL.size())
	# "none" is not a circle — the palette walks `ALL`, so if it is in there "none" shows up as an item.
	t.ok(not CircleDefs.ALL.has(CircleDefs.CIRCLE_NONE), "CIRCLE_NONE은 ALL 안에 없다")
	t.ok(not CircleDefs.DEFS.has(CircleDefs.CIRCLE_NONE), "CIRCLE_NONE은 표에 없다 (예약값이다)")

	for id: int in CircleDefs.ALL:
		var c := SpellCircle.new(id)
		# **The constructor no longer auto-fills runes** (`onboarding-and-palette-tabs.md` Stage 3) — this
		#  loop is a table-driven check, not the boot-state check, so the rune is filled by hand to keep
		#  `can_fire()` below meaningful for every circle in the table.
		for slot in c.rune_count():
			c.set_rune(slot, Tuning.ELEM_NONE)
		var nm: StringName = CircleDefs.DEFS[id]["name"]
		t.eq(c.circle_id(), id, "진 %s가 자기 id를 기억한다" % nm)
		t.eq(c.layer_count(), CircleDefs.layers(id), "진 %s의 층 수가 표에서 나온다" % nm)
		t.eq(c.rune_count(), CircleDefs.rune_slots(id), "진 %s의 룬 자리 수가 표에서 나온다" % nm)

		# **Every row carries all four columns.** Without this, a row missing `picture`/`seq_ticks` only
		#  surfaces the day something reads it — `DEFS[id]["picture"]` on a missing key raises at that call site,
		#  not here, and by then the trail back to "the row was incomplete" is cold.
		t.ok(CircleDefs.DEFS[id].has("picture"), "진 %s 행에 picture 열이 있다" % nm)
		t.ok(CircleDefs.DEFS[id].has("seq_ticks"), "진 %s 행에 seq_ticks 열이 있다" % nm)

		# Compares the accessors **directly against the table.** The two lines above only look at "does the model follow the accessors".
		#  **These two lines cannot catch a `return 2` mutation** — the table's value happens to be 2, so
		#   the constant and the table give the same answer. As long as there is only one circle, **the value cannot split them in principle.**
		#   => That hole is blocked by text in `_accessors_read_the_table` below.
		#   What these two lines catch is **a constant different from the table's value** (the `return 5` shape).
		t.eq(CircleDefs.layers(id), int(CircleDefs.DEFS[id]["layers"]),
			"진 %s의 층 수 접근자가 표와 같은 값을 준다" % nm)
		t.eq(CircleDefs.rune_slots(id), int(CircleDefs.DEFS[id]["rune_slots"]),
			"진 %s의 룬 자리 접근자가 표와 같은 값을 준다" % nm)
		t.eq(CircleDefs.picture(id), int(CircleDefs.DEFS[id]["picture"]),
			"진 %s의 picture 접근자가 표와 같은 값을 준다" % nm)
		t.eq(CircleDefs.seq_ticks(id), int(CircleDefs.DEFS[id]["seq_ticks"]),
			"진 %s의 seq_ticks 접근자가 표와 같은 값을 준다" % nm)
		# If the layers exceed the list cap, `pack` barks — grow only the table without looking here and
		#  it becomes "fill every layer and firing dies".
		t.ok(c.layer_count() <= Tuning.GLYPH_MAX_LAYERS,
			"진 %s의 층 %d개가 목록 상한 %d 안이다" % [nm, c.layer_count(), Tuning.GLYPH_MAX_LAYERS])
		t.ok(c.rune_count() >= 1, "진 %s에 룬 자리가 하나는 있다" % nm)
		# Every layer of a new circle is empty — otherwise the first shot carries a glyph nobody placed.
		t.eq(c.packed_glyphs(), Glyph.GLYPH_NONE, "새 진 %s는 빈 목록이다" % nm)
		# **The start state has the circle and rune filled in.** Boot with an empty rune and the game starts in a "cannot fire" state.
		t.ok(c.can_fire(), "새 진 %s는 바로 쏠 수 있다 (룬이 채워져 있다)" % nm)

	# GDD-settled values. If the table changes quietly, this line goes red first.
	var round_id := CircleDefs.CIRCLE_ROUND
	t.eq(CircleDefs.layers(round_id), 2, "동그라미 진은 2층이다 (GDD)")
	t.eq(CircleDefs.rune_slots(round_id), 1, "동그라미 진은 룬 1자리다 (GDD)")
	# **The round circle's one shot falls straight through `seq_ticks`** — pinned at 0 so a later circle's
	#  nonzero value cannot quietly leak backward onto this one.
	t.eq(CircleDefs.picture(round_id), CircleDefs.PIC_ROUND, "동그라미 진의 picture는 PIC_ROUND다")
	t.eq(CircleDefs.seq_ticks(round_id), 0, "동그라미 진은 seq_ticks 0이다 (한 발이 한 틱에 나간다)")


## Barks at a circle that is not in the table — add a circle without adding it to the table and the wrapper's stderr check catches it for free.
## **"There is no circle" does not bark.** That is a normal state — fold the two into one branch and the ordinary
##  act of removing the circle turns the net red.
func _unknown_circle_barks(t) -> void:
	t.eq(CircleDefs.layers(CircleDefs.CIRCLE_NONE), 0, "진이 없으면 층이 0이다 (조용히)")
	t.eq(CircleDefs.rune_slots(CircleDefs.CIRCLE_NONE), 0, "진이 없으면 룬 자리가 0이다 (조용히)")
	t.eq(CircleDefs.picture(CircleDefs.CIRCLE_NONE), CircleDefs.PIC_ROUND, "진이 없으면 picture가 조용히 PIC_ROUND다")
	t.eq(CircleDefs.seq_ticks(CircleDefs.CIRCLE_NONE), 0, "진이 없으면 seq_ticks가 0이다 (조용히)")

	# The declaration carries the file name — an amnesty applies to **the whole run**, so writing it broadly
	#  amnesties the same wording in other files too (see the comment around line 135).
	t.expect_error("Circle: unknown circle")
	var bad := SpellCircle.new(9999)
	t.eq(bad.layer_count(), 0, "모르는 진은 짖고 층이 0이다")
	t.eq(bad.packed_glyphs(), Glyph.GLYPH_NONE, "층이 0이면 빈 목록이다 (폭주하지 않는다)")


# ══════════════════════════════════════════════════════════════════
#  The empty rune — 0 is already fire
# ══════════════════════════════════════════════════════════════════

## `sim_tuning.ELEM_FIRE = 0`, so **runes cannot use the zero convention.** Use 0 as the empty rune and
## the assembly window draws a blank while firing sends out fire, **with not one error.**
## This one line pins that trap down as a contract.
func _empty_rune_is_not_a_rune(t) -> void:
	t.ok(not Tuning.ELEM_ALL.has(SpellCircle.RUNE_EMPTY),
		"RUNE_EMPTY(%d)가 ELEM_ALL 안에 없다" % SpellCircle.RUNE_EMPTY)
	t.ok(SpellCircle.RUNE_EMPTY != Tuning.ELEM_FIRE, "RUNE_EMPTY가 불 룬이 아니다")
	# The other side of the trap — measures that 0 really is a rune. If this changes, the basis for the convention above disappears.
	t.eq(Tuning.ELEM_FIRE, 0, "불 룬이 0이다 (그래서 0을 빈 값으로 못 쓴다)")

	# An unknown rune is not accepted — accept it and `can_fire()` lets it through and `fire()` barks at the command boundary.
	# **A round circle explicitly, not the bare constructor** (`onboarding-and-palette-tabs.md` Stage 3 —
	#  `SpellCircle.new()` alone is now `CIRCLE_NONE`, 0 rune slots, and `rune_at(0)` would be a bogus read).
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c.set_rune(0, Tuning.ELEM_FIRE), "확인용으로 불을 놓아 둔다 (전제)")
	t.expect_error("SpellCircle: unknown rune")
	t.ok(not c.set_rune(0, 777), "모르는 룬은 짖고 안 놓인다")
	t.eq(c.rune_at(0), Tuning.ELEM_FIRE, "거절된 룬이 자리를 안 건드린다 (놓아 둔 불이 그대로다)")


## Remove the rune and you cannot fire. The design doc "extreme values" sentence "a circle plus a rune alone already
##  makes a spell" already carries **glyphs are optional and a rune is required.**
func _cannot_fire_without_a_rune(t) -> void:
	# **A round circle with a rune placed by hand** — `SpellCircle.new()` alone is now `CIRCLE_NONE` with
	#  no rune slots at all (Stage 3's empty boot). This function's own concern is the rune, not the boot
	#  state, so the circle and its rune are set up explicitly.
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c.set_rune(0, Tuning.ELEM_FIRE), "룬을 놓는다 (전제)")
	t.ok(c.can_fire(), "룬이 있으면 쏠 수 있다")

	t.ok(c.set_rune(0, SpellCircle.RUNE_EMPTY), "룬을 뺀다")
	t.eq(c.rune_at(0), SpellCircle.RUNE_EMPTY, "룬 자리가 비었다")
	t.ok(not c.can_fire(), "빈 룬 자리가 있으면 못 쏜다")

	t.ok(c.set_rune(0, Tuning.ELEM_FIRE), "룬을 다시 넣는다")
	t.ok(c.can_fire(), "다시 넣으면 쏠 수 있다")

	# It fires with no glyph — the point is that the rules for runes and glyphs differ.
	var bare := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(bare.set_rune(0, Tuning.ELEM_NONE), "룬을 놓는다 (전제)")
	t.eq(bare.packed_glyphs(), Glyph.GLYPH_NONE, "문양이 하나도 없다")
	t.ok(bare.can_fire(), "문양이 없어도 쏠 수 있다 (진 + 룬만)")

	# With no circle you cannot fire — the actual empty-boot state now, no explicit `set_circle` needed.
	var gone := SpellCircle.new()
	t.ok(not gone.can_fire(), "진이 없으면 못 쏜다")

	# An empty rune has to take the path of **not building a command at all** — build one and `fire()` barks.
	#  If the shell does not consult `can_fire()`, exactly this bark happens.
	#
	# **The declaration carries the file name.** The wrapper's amnesty applies not to one net but to **the whole run**,
	#  so writing plain `unknown rune` amnesties `SpellCircle: unknown rune` along with it —
	#  and then, **the day `set_rune` above starts barking at normal input (an empty rune), stderr comes out clean.**
	#  That actually happened (verify-read demonstrated it with a mutation). Amnesties are always written narrowly.
	var sim := SpellSim.new()
	t.expect_error("SpellSim: unknown rune")
	t.ok(not sim.fire(SpellSim.cmd_fire(10, 70, 100, 0,
		SpellCircle.RUNE_EMPTY, Glyph.GLYPH_NONE)),
		"빈 룬으로 커맨드를 만들면 발사가 짖는다 (그래서 안 만든다)")


# ══════════════════════════════════════════════════════════════════
#  Swapping the circle — array lengths change at runtime
# ══════════════════════════════════════════════════════════════════

## Every circle has a different layer count, so `layers[]` **changes length at runtime.** With only one circle it does not
##  show today, but if the model cannot express it, the day a second circle arrives the model gets rebuilt.
func _swapping_the_circle_resizes(t) -> void:
	# **A round circle explicitly** — `SpellCircle.new()` alone is now `CIRCLE_NONE` (Stage 3), which has
	#  0 layers, so `place_glyph` below would refuse on an empty boot circle.
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c.set_rune(0, Tuning.ELEM_NONE), "룬을 놓는다 (전제)")
	t.ok(c.place_glyph(0, Glyph.GLYPH_SPREAD), "1층에 확산을 놓는다")
	t.ok(c.place_glyph(1, Glyph.GLYPH_BLAST), "2층에 폭발을 놓는다")

	# **Placing the same circle again does nothing** — otherwise one accidental extra click blows away
	#  the whole assembly.
	var before := c.packed_glyphs()
	c.set_circle(CircleDefs.CIRCLE_ROUND)
	t.eq(c.packed_glyphs(), before, "같은 진을 다시 놓으면 조립이 안 날아간다")
	t.ok(c.can_fire(), "같은 진을 다시 놓아도 룬이 남는다")

	# **Changing the circle empties every layer and rune slot.** Keeping them from the front makes the last glyph
	#  disappear **silently** — emptying everything changes the whole drawing, which is visible.
	c.set_circle(CircleDefs.CIRCLE_NONE)
	t.eq(c.layer_count(), 0, "진을 빼면 층이 0이다")
	t.eq(c.rune_count(), 0, "진을 빼면 룬 자리가 0이다")
	t.eq(c.packed_glyphs(), Glyph.GLYPH_NONE, "진을 빼면 문양이 남지 않는다")
	t.ok(not c.can_fire(), "진을 빼면 못 쏜다")
	t.ok(not c.place_glyph(0, Glyph.GLYPH_BLAST), "진이 없으면 문양을 못 놓는다")
	t.ok(not c.set_rune(0, Tuning.ELEM_FIRE), "진이 없으면 룬을 못 놓는다")

	# Place it again and the lengths follow the table.
	c.set_circle(CircleDefs.CIRCLE_ROUND)
	t.eq(c.layer_count(), CircleDefs.layers(CircleDefs.CIRCLE_ROUND),
		"진을 다시 놓으면 층 수가 표를 따라간다")
	t.eq(c.rune_count(), CircleDefs.rune_slots(CircleDefs.CIRCLE_ROUND),
		"진을 다시 놓으면 룬 자리 수가 표를 따라간다")
	t.eq(c.packed_glyphs(), Glyph.GLYPH_NONE, "새로 놓은 진의 층은 비어 있다")
	# **Placing a circle empties the rune slots too** — only the start state (the constructor) fills the rune. Confuse the two
	#  and it becomes "I changed the circle and a rune appeared by itself".
	t.eq(c.rune_at(0), SpellCircle.RUNE_EMPTY, "새로 놓은 진의 룬 자리는 비어 있다")
	t.ok(not c.can_fire(), "그래서 진을 새로 놓으면 룬을 넣기 전엔 못 쏜다")

	# **The two lengths have to be different numbers, or one constant can fill both.** If they are the same,
	#  two hardcoded `resize(2)` lines still leave this net green.
	t.ok(c.layer_count() != c.rune_count(),
		"층 수(%d)와 룬 자리 수(%d)가 서로 다른 수다 (한 상수로 둘 다 못 채운다)" % [
			c.layer_count(), c.rune_count()])


## **With only one circle, "does the layer array follow the table" cannot be measured to the end by execution alone** (plan risk 16).
##  The reachable layer counts are **only 2 (round) and 0 (none)**, so hardcoding `id == CIRCLE_NONE ? 0 : 2`
##  still leaves every check above green.
##
## **The plan said "have the net build a second table by hand and measure against it", and that does not work** —
##  `DEFS` is `const`, so Godot forces it read-only (measured: `DEFS.is_read_only()` is true, and inserting a row
##  raises "Dictionary is in read-only state").
##
## => **The source text is looked at instead.** The same device `net_determinism` uses for the same reason —
##  for a contract that execution cannot measure in principle, **a text scan is the only detector.**
##  What is measured is narrow: **does every place that decides a length go through the circle table.**
##
## **Comments and strings are stripped first.** Without stripping, a single `.resize(nl)` written in a comment
##  turns it red (verify-read measured it). **A false positive can be worse than a false negative** —
##  a net nobody trusts gets deleted by the next person.
## The stripper is **borrowed** from `net_determinism`. Copying it makes two copies, and the day only one is fixed
##  the two nets look at different text (CLAUDE.md).
func _resize_is_table_driven(t) -> void:
	var raw := _read("res://src/actor/spell_circle.gd")
	# `_strip` cannot handle triple quotes — the rest of the file then drops out of the scan entirely
	#  and goes **silently green.** `net_determinism` measures the same assumption.
	t.ok(not raw.contains("\"\"\""), "spell_circle에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)")
	var src := NetDeterminism._strip(raw)
	var re := RegEx.new()
	t.eq(re.compile("\\.resize\\(([^)]*)\\)"), OK, "resize 패턴이 컴파일된다")
	var hits := re.search_all(src)
	# If nothing is found, this check **measures nothing and goes green** — that is how this repo dies.
	t.ok(hits.size() >= 2,
		"spell_circle이 배열 길이를 정하는 곳이 %d군데다 (층 · 룬)" % hits.size())
	for m: RegExMatch in hits:
		var arg := m.get_string(1)
		t.ok(arg.contains("CircleDefs."),
			"길이 `%s`가 진 표에서 나온다 (상수 박기가 아니다)" % arg)
	_layout_reads_the_table(t)


## **Scanning only the model cannot catch a 2 hardcoded in the drawing** (plan section 6.1).
##  It then becomes "the model has 3 layers but **the third ring is not drawn**", and that is **worse** than the layer
##  count not following — the sim growing while the screen does not follow is how v1 died.
##  => Every place that reads the layer count or the rune slot count, **across both files**, has to go through the circle table.
##
## Two things are measured, and **which file each applies to differs:**
##   (1) does the layout file **call** the accessors it owns (`LAYOUT_ACCESSORS`) — `circle_layout.gd` only.
##      The drawing file looks at the model (`layer_count()`), so it has no reason to call the accessors.
##      `seq_ticks` is deliberately not in that list — it is `spell_circle`'s question, not the layout's
##   (2) is there **no loop with a hardcoded count** — **both files.** A `for i in 2` in the drawing freezes the ring count too
##  **Do not write the label wider than the code.** Write "across both files" while sweeping only one and
##   that sentence becomes a false guarantee to the next person (it did, measured).
func _layout_reads_the_table(t) -> void:
	var layout := _stripped(t, "res://src/view/circle_layout.gd", "circle_layout")

	# `range(2)` is the detour — look only for `for i in 2` and one character escapes it.
	var re := RegEx.new()
	t.eq(re.compile("for\\s+\\w+\\s+in\\s+(?:range\\s*\\(\\s*)?\\d"), OK,
		"숫자 순회 패턴이 컴파일된다")
	var files := {
		"circle_layout": layout,
		"circle_window": _stripped(t, "res://src/view/circle_window.gd", "circle_window"),
	}
	for nm: String in files.keys():
		t.ok(re.search(files[nm]) == null, "%s 가 개수를 숫자로 박은 순회를 안 한다" % nm)

	for fname: String in LAYOUT_ACCESSORS:
		t.ok(layout.contains("CircleDefs.%s(" % fname),
			"좌표가 `CircleDefs.%s()` 를 부른다" % fname)


## **Do the accessors themselves read the table?** `_sizes_come_from_the_table` above **cannot measure this in principle** —
##  there is one circle and its layer count is 2, so changing `layers()` to `return 2` gives **the same value** as the table.
##  Measured: after that change the net ran **entirely green, accessor checks included.**
##
## => Since the value cannot split them, **text does.** The same reason and the same device as `_resize_is_table_driven` above.
## What is measured is narrow: **does each accessor body go through `DEFS[`.** Turn it into `return 2` and that line disappears.
##  However the table is read (even through an intermediate variable) `DEFS[` remains, so it does not bite normal refactoring.
func _accessors_read_the_table(t) -> void:
	var raw := _read("res://src/sim/circle_defs.gd")
	t.ok(not raw.contains("\"\"\""), "circle_defs에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)")
	var src := NetDeterminism._strip(raw)
	# If the list is empty the loop below runs zero times and **goes green.**
	t.ok(ACCESSORS.size() > 0, "재 볼 접근자가 %d개다" % ACCESSORS.size())
	for fname: String in ACCESSORS:
		var body := _func_body(src, fname)
		t.ok(body != "", "circle_defs에 %s()가 있다" % fname)
		t.ok(body.contains("DEFS["), "%s()가 표를 읽는다 (상수를 안 돌려준다)" % fname)


## **Do the page rectangles come from one place — and is it actually book-shaped?**
##  The fold is not decoration but **the drawing of a boundary.** If the visible boundary and (at stage 4b) the click
##   boundary differ, it becomes "I clicked here and that reacted" and **no error shows** (risk 23).
##  => It measures whether the fold splits the two pages **exactly** — leave a gap and that gap belongs to neither side.
func _book_pages_are_one_source(t) -> void:
	var win := Fx.WINDOW_RECT.size
	var pages := Book.pages(win)
	for key: String in ["left", "fold", "right"]:
		t.ok(pages.has(key), "페이지 표에 `%s` 가 있다" % key)
	if not (pages.has("left") and pages.has("fold") and pages.has("right")):
		return
	var l: Rect2 = pages["left"]
	var f: Rect2 = pages["fold"]
	var r: Rect2 = pages["right"]

	t.ok(l.size.x > 0.0 and l.size.y > 0.0, "왼쪽 페이지에 크기가 있다 (%dx%d)" % [
		int(l.size.x), int(l.size.y)])
	t.ok(r.size.x > 0.0 and r.size.y > 0.0, "오른쪽 페이지에 크기가 있다 (%dx%d)" % [
		int(r.size.x), int(r.size.y)])
	# Different widths read as "body text plus a sidebar" and not as an open book.
	t.ok(is_equal_approx(l.size.x, r.size.x), "두 페이지 폭이 같다 (%.1f · %.1f)" % [
		l.size.x, r.size.x])
	t.ok(not l.intersects(r), "두 페이지가 안 겹친다")

	# The fold splits the two while sitting **flush.** Leave a gap and that band belongs to neither page.
	t.ok(is_equal_approx(l.end.x, f.position.x), "접힘이 왼쪽 페이지에 붙어 있다")
	t.ok(is_equal_approx(f.end.x, r.position.x), "접힘이 오른쪽 페이지에 붙어 있다")
	t.ok(f.size.x > 0.0, "접힘에 폭이 있다 (경계가 보인다)")

	# Does it fit inside the window, and does it stay out of the title band.
	var win_rect := Rect2(Vector2.ZERO, win)
	for key: String in ["left", "fold", "right"]:
		var p: Rect2 = pages[key]
		t.ok(win_rect.encloses(p), "%s 가 창 안에 들어간다" % key)
		t.ok(p.position.y >= Fx.WINDOW_TITLE_BAND_PX, "%s 가 제목 띠 아래에서 시작한다" % key)

	# **The net too reads "which page is the spell circle" from `book_layout`.** Hardcode the key here and
	#  the day left and right are swapped, **only the window swaps while the net measures the old page and goes green.**
	var circle_page := Book.circle_page(win)
	var palette_page := Book.palette_page(win)
	t.ok(not circle_page.intersects(palette_page), "마법진 페이지와 팔레트 페이지가 안 겹친다")
	# **Pins the user's acceptance down** ("the spell circle on the left; circle, rune and glyphs on the right").
	#  **This is not a tautology** — it is not compared against a constant but **fixes the acceptance.** The day it is
	#   swapped again, changing these two lines along with it becomes the record of "the acceptance changed".
	#   Without it, left and right drift quietly and later nobody knows why it is this way.
	#  spec's first proposal was **the opposite** (palette on the left). That makes it worth pinning all the more.
	t.ok(circle_page == l, "마법진이 **왼쪽** 페이지다 (사용자 판정)")
	t.ok(palette_page == r, "팔레트가 **오른쪽** 페이지다 (사용자 판정)")
	# **"The spell circle is on the outside" (section 3.7, item 3) cannot be measured here — trying to produced a tautology.**
	#  Written as `circle.position.x <= palette.position.x or circle.end.x >= palette.end.x`, it stayed
	#  **green even with left and right completely reversed** (measured). With only two pages, **both are outermost
	#  from one side**, so that predicate is always true.
	#  **And item 3 itself is false in the current code.** `pages()` always splits the window exactly in half, so
	#   the spell circle, whichever side it is on, **can only narrow within its own half and can never grow outward.**
	#   "Once a circle with several rune slots arrives there will be something to measure" was **only half right** —
	#    **what matters is not the kind of circle but the split.** Even when such a circle arrives, if `pages()` keeps
	#    its current shape it still cannot be measured. => There will be something to measure the day `pages()` can do an **asymmetric split.**

	# **Contract: the spell circle page holds the circle's diameter.**
	#
	# At first this was written as `diameter <= min(page)`, and **that was a tautology** — confirmed by measurement:
	#  halving the page still left it green. The radius is **derived** from the page, so it is always true.
	#  => What has to be measured is not "does it overflow" but **"is a usable size left".**
	#
	# The basis for the floor: at stage 3, verify-look passed acceptance 3 (the layer numbers and the brightness
	#  difference are readable) with a **spell circle of diameter ~199px.** Go smaller than that and **that acceptance goes stale** —
	#  the two rings, the rune and the glyph symbols all have to fit inside, and smaller they eat each other.
	#  If you want to shrink the window, **look at it with your eyes again** before lowering this line.
	var area := Layout.circle_area(circle_page.size)
	var fr: float = Layout.frame(area)["radius"]
	t.ok(fr > 0.0, "마법진 페이지에서 진 반지름이 나온다 (%.1f)" % fr)
	t.ok(fr * 2.0 >= CIRCLE_DIAMETER_FLOOR_PX,
		"진 지름(%.1f)이 바닥값 %d 이상이다 (페이지 %dx%d)" % [
			fr * 2.0, int(CIRCLE_DIAMETER_FLOOR_PX),
			int(circle_page.size.x), int(circle_page.size.y)])

	# Is the window inside the screen. "What percentage" is not measured — that number goes stale (plan section 3.7).
	#  "Is the character visible" is **judged by the eye.**
	var vw := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	t.ok(Rect2(0.0, 0.0, vw, vh).encloses(Fx.WINDOW_RECT), "창이 화면 안에 들어간다")


## **Does the spell circle not know about pages?** The moment it does, the circle code gets opened every time the window
##  shape changes — **the same disease one level up** as the layer axis hanging off the circle axis at stage 3.
## What is measured is **two references**: does it call the window axis file, does it read window constants.
func _circle_layout_does_not_know_pages(t) -> void:
	# **File references are looked at in the raw source.** `preload` paths are strings, so the stripper erases them,
	#  and measuring on stripped source **misses the real coupling and goes green** (it did, measured).
	#  The same method `net_layers` uses to find dead paths, with the same cost —
	#   writing that path in a comment also trips it (a false positive, but it fails **red** so it does not leak quietly).
	var raw := _read(LAYOUT_PATH)
	t.ok(not raw.contains(BOOK_PATH), "마법진 좌표가 창 축 파일을 안 부른다")
	var src := _stripped(t, LAYOUT_PATH, "circle_layout")
	t.ok(not src.contains("Fx.WINDOW_"), "마법진 좌표가 창 상수를 안 읽는다")

	# The other side — the window has to know **both.** Otherwise the two above pass as "nobody uses anything".
	# **The flip side of the cost of using the raw source**: delete the `preload` and **leaving only the path in a comment still passes.**
	#  That is not the situation today so it is left as is, but do not read these two lines as "the reference exists" —
	#  what is true is "those characters appear somewhere in the file".
	var wraw := _read(WINDOW_PATH)
	t.ok(wraw.contains(BOOK_PATH), "창이 창 축을 조립한다")
	t.ok(wraw.contains(LAYOUT_PATH), "창이 마법진 축을 조립한다")
	var win := _stripped(t, WINDOW_PATH, "circle_window")

	# ══ From here on it is all **"does the window use that value"** ══════════════
	# The checks above measure only **"is the value right".** Even with the right value, if the window **uses a different one**
	#  the screen is wrong, and every such split **raises no error.** Measured: four passed (verify-read mutation).

	# **The third path to coupling: just take it as a parameter.**
	#  Change it to `circle_area(box, origin := Vector2.ZERO)` and have the window pass `page.position`, and
	#  **the spell circle learns its own position** without touching `book_layout` or `Fx.WINDOW_` at all.
	#  **Behavior cannot catch this in principle** — the default is ZERO, so calling it without the argument gives the same answer.
	#  => Pinning the signature is the only option.
	t.ok(src.contains("func circle_area(box: Vector2) -> Rect2"),
		"마법진 자리 함수가 **크기만** 받는다 (자리를 안 받는다)")

	# **The palette has the same contract and had no pin.** Adding an `origin` parameter to `section()` still passed
	#  (measured). Pin only one side of two contracts of the same nature and **the unpinned side breaks quietly.**
	var pal_src := _stripped(t, PALETTE_PATH, "palette_layout")
	t.ok(pal_src.contains("func section(page_size: Vector2) -> Rect2"),
		"팔레트 구획 함수가 **크기만** 받는다 (탭 색인도 자리도 안 받는다 — 열린 탭과 무관하게 하나뿐이다)")
	t.ok(pal_src.contains(
			"func item_at(page_size: Vector2, p: Vector2, open_tab: int, pr: Progress, circle: SpellCircle) -> Dictionary"),
		"팔레트 히트테스트가 **크기·점·열린 탭·소유 상태**를 받는다 (자리는 안 받는다)")
	t.ok(not pal_src.contains("Fx.WINDOW_"), "팔레트가 창 상수를 안 읽는다")
	t.ok(not _read(PALETTE_PATH).contains(BOOK_PATH), "팔레트가 창 축 파일을 안 부른다")

	var draw := _func_body(win, "_draw")
	t.ok(draw != "", "창의 `_draw()` 를 찾았다")
	# Does the window pass **the page size.** Pass `size` (the whole window) and the radius grows so the spell circle
	#  crosses the fold and **intrudes on the left page** — only the drawing is wrong and nobody barks.
	t.ok(draw.contains("Layout.circle_area(page.size)"),
		"창이 마법진에 **페이지 크기**를 넘긴다 (창 크기가 아니다)")
	# The window does not **hardcode the page key.** Hardcode it and swapping left and right swaps only the window
	#  while the net measures the old page — **both green.**
	#
	# **A check that looks at "does it call" but not "does it use"** — the **third time in this repo** with the same shape:
	#   (1) stage 1   — merely **mentioning** the table passes (the `resize` scan)
	#   (2) stage 4a  — deleting the `preload` and **leaving only the path in a comment** passes
	#   (3) here      — **calling** `Book.circle_page(` while actually using `pages["right"]` passes
	#
	# **Adding more text checks cannot block this hole.** "Does that value reach the result" is **behavior**, and text
	#  in principle sees only **syntax.** Only an execution check blocks it, and that opens the day there are two
	#  circles and both arrangements can actually be run.
	# **So it was deliberately left unnarrowed** — narrowing produces false positives that bite normal refactoring
	#  (pulling it into an intermediate variable, etc.), and a net nobody trusts gets deleted by the next person.
	#
	# **This line is worth exactly "blocking the single most naive mistake". Do not read it as a guarantee.**
	t.ok(draw.contains("Book.circle_page("),
		"창이 마법진 페이지를 `book_layout`에게 묻는다 (키를 안 박는다)")

	# If drawing uses a transform, **there has to be a line that undoes it** — without one, everything appended after
	#  is shifted by the page, and right now nothing follows so there is not even a symptom.
	# **Counting alone is not enough** (measured): change the undoing line to `draw_set_transform(page.position)`
	#  and the count is still 2 and green, and then the transform **never comes back** —
	#  at 4b the whole left page drawing shifts to the right.
	# With two pages there are two transform pairs (spell circle, palette) — **do not hardcode a count; measure the pairing.**
	var xf_all := win.count("draw_set_transform")
	var xf_reset := win.count("draw_set_transform(Vector2.ZERO)")
	t.ok(xf_all > 0, "창이 좌표계를 옮겨 그린다 (%d곳)" % xf_all)
	t.eq(xf_reset * 2, xf_all, "건 만큼 **항등으로** 되돌린다 (걸기 %d · 되돌리기 %d)" % [
		xf_all - xf_reset, xf_reset])

	# Are the three pages drawn **from the page table.** Compute them separately and, since 4b's hit test reads `pages()`,
	#  **the visible groove and the reacting groove diverge** (risk 23).
	#  These are string keys, so **the raw source** has to be looked at — the stripper erases quotes **and everything in them.**
	var draw_raw := _func_body(wraw, "_draw")
	t.ok(draw_raw != "", "원문에서 창의 `_draw()` 를 찾았다")
	for key: String in ["left", "fold", "right"]:
		t.ok(draw_raw.contains("draw_rect(pages[\"%s\"]" % key),
			"창이 `%s` 를 페이지 표에서 그린다" % key)


## **The palette is "slot kind x item". It is not "a glyph palette".**
##  Written glyph-only, attaching circles and runes means **rewriting it entirely** — the plan pinned this as the most
##   expensive mistake at this stage. Stage 5 has to be **the work of adding two more cells.**
##
## And **do the items come from the table** — written out by hand, growing the table without growing the palette stays quiet.
func _palette_is_kind_by_item(t) -> void:
	t.eq(Palette.KINDS.size(), Palette.KIND_DEFS.size(), "슬롯 종류의 KINDS와 KIND_DEFS가 같다")
	# If empty, the loop below runs zero times and **goes green.**
	t.ok(Palette.KINDS.size() > 0, "슬롯 종류가 %d개다" % Palette.KINDS.size())
	# Having three kinds is the palette's **structure** — with only glyphs it is a glyph-only palette.
	t.ok(Palette.KINDS.has(Palette.KIND_CIRCLE), "진 칸이 있다")
	t.ok(Palette.KINDS.has(Palette.KIND_RUNE), "룬 칸이 있다")
	t.ok(Palette.KINDS.has(Palette.KIND_GLYPH), "문양 칸이 있다")

	# **What you do not have has no cell** (`onboarding-and-palette-tabs.md` §2, reversing
	#  `rune-lock-and-receiving.md`'s "veiled, not hidden"). A fresh `Progress`/`SpellCircle` owns only
	#  동그라미 and 무속성, and starts with no glyph seated — **measured by value, not by count**: a
	#  hand-written `[CIRCLE_ROUND]` would pass a count check just as well, so the exact array is compared.
	var pr := Progress.new()
	# **A round circle explicitly** — `SpellCircle.new()` alone is `CIRCLE_NONE` (Stage 3's empty boot),
	#  which has 0 layers, and `place_glyph` below needs a real seat.
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.eq(Array(Palette.items_of(Palette.KIND_CIRCLE, pr, c)), [CircleDefs.CIRCLE_ROUND],
		"진 칸은 처음에 동그라미 하나뿐이다 (삼각은 아직 없다)")
	t.eq(Array(Palette.items_of(Palette.KIND_RUNE, pr, c)), [Tuning.ELEM_NONE],
		"룬 칸은 처음에 무속성 하나뿐이다 (불·물은 아직 없다)")
	t.eq(Array(Palette.items_of(Palette.KIND_GLYPH, pr, c)), [],
		"문양 칸은 처음에 비어 있다 (낀 문양이 없다 — 보유 목록이 아니라 마법진의 보기다)")

	# **The transition, on one instance** — a grant adds a cell with no restart, the same shape
	#  `_owns_rune_gates_can_pick_on_an_untreed_window` already drives for placeability.
	pr.grant_circle(CircleDefs.CIRCLE_TRIANGLE)
	t.eq(Array(Palette.items_of(Palette.KIND_CIRCLE, pr, c)),
		[CircleDefs.CIRCLE_ROUND, CircleDefs.CIRCLE_TRIANGLE],
		"삼각을 준 뒤에는 진 칸에 둘 다 있다 (같은 Progress를 그대로 읽는다)")
	pr.grant_rune(Tuning.ELEM_FIRE)
	# **Order follows `Tuning.ELEM_ALL`'s own table order** (fire, none, water) — `items_of` filters that
	#  list, it does not re-sort it.
	t.eq(Array(Palette.items_of(Palette.KIND_RUNE, pr, c)), [Tuning.ELEM_FIRE, Tuning.ELEM_NONE],
		"불을 준 뒤에는 룬 칸에 둘 다 있다")

	# **Placed and absent are not the same question, and folding them into one gate breaks a different
	#  thing than it used to** (design §2's own worked example, now read through Stage 8's move semantics):
	#  ownership deciding *existence* would make a just-placed glyph vanish from its own tab the instant it
	#  lands; here the card stays, and — since Stage 8 — it stays **pickable**, because every 문양 card is
	#  a seated glyph and picking one now means picking a layer to move, not a value to place again.
	t.ok(c.place_glyph(0, Glyph.GLYPH_SPREAD), "확산을 1층에 놓는다 (전제)")
	t.eq(Array(Palette.items_of(Palette.KIND_GLYPH, pr, c)), [Glyph.GLYPH_SPREAD],
		"확산을 놓은 뒤에는 문양 칸에 그것이 보인다")
	var win := CircleWindow.new()
	win.setup(pr, c)
	t.ok(win.call("_can_pick", Palette.KIND_GLYPH, Glyph.GLYPH_SPREAD),
		"놓인 확산은 여전히 고를 수 있다 (Stage 8 — 다른 층으로 옮기는 것이지 새로 놓는 것이 아니다)")
	win.free()

	# Barks at an unknown kind — add a kind without wiring the table and that cell **empties quietly.**
	t.expect_error("PaletteLayout: unknown slot kind")
	t.eq(Palette.items_of(9999, pr, c).size(), 0, "모르는 종류는 짖고 항목이 0이다")


## **`Progress.owns_rune()` drives `_can_pick()` on an untreed window** (`rune-lock-and-receiving.md`, Stages
## A-B). `net_pick.gd` already proved the technique for the sibling window (`ThreePickWindow.new()`, `setup()`
## called directly, no scene tree needed) — this is the same move for `CircleWindow`.
##
## **A final-state check alone cannot measure a grant** (this plan's own risk table) — "fire is pickable" is
## true both before the lock lands and after the reward, so the transition itself is asserted: veiled ->
## `grant_rune()` -> pickable, in one run, in that order.
##
## **Stage B's own lock, pinned by value**: the starting kit is `{none}` only — fire is veiled on a fresh boot
## same as water, not merely absent from the seat. Water is the negative control throughout — nothing in this
## file ever grants it, so it stays veiled from the first line to the last, undisturbed by the fire grant.
func _owns_rune_gates_can_pick_on_an_untreed_window(t) -> void:
	var pr := Progress.new()
	# **A round circle** — `_can_pick(KIND_RUNE, ...)` asks `_slot_count(KIND_RUNE)` (`c.rune_count()`),
	#  which is 0 on the empty boot circle (Stage 3); a real rune seat is needed to test placeability at all.
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	var win := CircleWindow.new()
	win.setup(pr, c)

	t.ok(pr.owns_rune(Tuning.ELEM_NONE), "시작 키트에 무속성이 있다 (전제)")
	t.ok(not pr.owns_rune(Tuning.ELEM_FIRE), "시작 키트에 불은 없다 (전제 — 이것이 잠금이다)")
	t.ok(not pr.owns_rune(Tuning.ELEM_WATER), "물도 아직 아무도 안 줬다 (전제)")

	# **"veiled" became "absent"** (`onboarding-and-palette-tabs.md` §2, reversing "veiled, not hidden") —
	#  an unowned rune has no cell in the palette's item list at all, not merely a dimmed one.
	var items := Palette.items_of(Palette.KIND_RUNE, pr, c)
	t.ok(items.has(Tuning.ELEM_NONE), "가진 무속성은 룬 칸에 있다")
	t.ok(not items.has(Tuning.ELEM_FIRE), "안 가진 불은 룬 칸에 없다 (가려진 게 아니라 칸이 없다)")
	t.ok(not items.has(Tuning.ELEM_WATER), "안 가진 물도 룬 칸에 없다")

	# **The grant, driven mid-run, on the same live objects** — not a fresh `Progress` built after the grant,
	#  which would only prove `owns_rune()` in isolation, not that the palette reads the live object the
	#  window was handed rather than a copy taken at `setup()` time.
	pr.grant_rune(Tuning.ELEM_FIRE)
	items = Palette.items_of(Palette.KIND_RUNE, pr, c)
	t.ok(items.has(Tuning.ELEM_FIRE), "불을 준 뒤에는 같은 Progress를 읽는 룬 칸에 불이 나타난다 (사본이 아니다)")
	t.ok(items.has(Tuning.ELEM_NONE), "불을 줘도 이미 가졌던 무속성은 그대로 있다")
	t.ok(not items.has(Tuning.ELEM_WATER), "불을 줘도 관계없는 물은 여전히 없다")

	# **Presence and placeability are two different questions** — the ownership gate moved out of
	#  `_can_pick`/`_slot_accepts` entirely (into `items_of`, measured above), so once a rune has a cell it
	#  is unconditionally placeable; there is nothing left in `_can_pick` to refuse it with.
	t.ok(win.call("_can_pick", Palette.KIND_RUNE, Tuning.ELEM_FIRE), "칸에 나타난 불은 실제로 고를 수 있다")

	# **The circle axis is untouched by the rune gate** — a fresh window still starts owning only
	#  동그라미 (`Progress._starting_circles()`), so this only proves the two axes read their own tables.
	t.ok(win.call("_can_pick", Palette.KIND_CIRCLE, CircleDefs.CIRCLE_ROUND),
		"진 칸은 룬 게이트와 무관하게 그대로 고를 수 있다")
	win.free()


## **The self-inflicted disarm verify-run found, fixed and driven through the real click path.**
## Click a *veiled* rune in the palette (`_can_pick` refuses it, nothing gets picked), then click an *armed*
## rune seat expecting nothing to happen — before the fix, `_place_or_clear`'s "nothing picked -> clear"
## branch fired anyway with `SpellCircle.RUNE_EMPTY` as the clear value, and two harmless-looking clicks
## dropped a working circle to `can_fire() == false`.
##
## **Real coordinates, not `_can_pick` shortcuts** — `_click_palette`/`_click_circle` are driven directly
## (`net_pick.gd`'s technique, `.call()` on an untreed `Control`), because the bug lived in *which literal
## `_click_circle` passes as the clear value*, and only driving that exact call site can catch it — a check
## against `_can_pick`/`_slot_accepts` alone would not touch this code path at all.
##
## **The click point is provably safe, not guessed** — `Layout.rune_slots(id, area)[0]` is the exact rune
## seat center, and `_hit_tests_match_the_drawing`'s own "measured across kinds" section already proves
## `rune_c.distance_to(layer_slot) - layer_hit >= rune_draw > 0` for every layer, i.e. the seat's exact center
## can never fall inside a layer's hit circle. This sidesteps the trap that same section names ("91 of the
## rune-seat pixels are claimed by the layer branch first") without hardcoding a screen-specific pixel.
func _refusing_a_veiled_rune_then_clicking_the_seat_does_not_disarm(t) -> void:
	var pr := Progress.new()
	# **A round circle, armed by hand** — `SpellCircle.new()` alone starts empty (Stage 3), and this
	#  function's whole point is the disarm path on an *already-fireable* circle.
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c.set_rune(0, Tuning.ELEM_NONE), "무속성 룬을 놓아 시작 상태를 만든다 (전제)")
	var win := CircleWindow.new()
	win.setup(pr, c)
	win.size = Fx.WINDOW_RECT.size

	t.ok(not pr.owns_rune(Tuning.ELEM_FIRE), "불은 아직 못 가졌다 (전제)")
	t.ok(c.can_fire(), "시작 상태는 쏠 수 있다 (전제 — 무속성 룬이 자리에 있다)")

	var page := Book.circle_page(win.size)
	var area := Layout.circle_area(page.size)
	var id := c.circle_id()
	var seat := Layout.rune_slots(id, area)[0]
	t.eq(Layout.layer_at(id, area, seat), -1, "룬 자리 정중앙은 어느 층의 히트 영역도 아니다 (전제 — 안전한 좌표다)")
	t.eq(Layout.rune_slot_at(id, area, seat), 0, "룬 자리 정중앙을 누르면 0번 룬 자리로 잡힌다 (전제)")

	var pal := Book.palette_page(win.size)
	var ki := Palette.KINDS.find(Palette.KIND_RUNE)

	# **The premise changed** (`onboarding-and-palette-tabs.md` §2, reversing "veiled, not hidden") — a rune
	#  nobody owns has no cell at all, so there is no "veiled fire" coordinate left to click. What is
	#  measured instead is the same shape one level up: open the 룬 tab, click a point that has no item
	#  (above the single owned cell's row, inside the section but above `item_slot`'s top), and confirm
	#  nothing gets picked — the same premise, driven through the real click path.
	win.call("_click_palette", pal, Palette.tabs(pal.size)[ki].get_center())
	t.eq(win.get("_open_tab"), ki, "룬 탭을 열었다 (전제)")
	var sec := Palette.section(pal.size)
	var empty_pt := sec.position + Vector2(5.0, Fx.PALETTE_HEAD_PX * 0.5)
	win.call("_click_palette", pal, empty_pt)
	t.eq(win.get("_picked_kind"), -1, "항목이 없는 자리를 눌러도 아무것도 안 골린다")

	# -- click the armed rune seat with nothing picked: must not empty it --
	win.call("_click_circle", page, seat)
	t.ok(c.rune_at(0) != SpellCircle.RUNE_EMPTY, "빈손으로 룬 자리를 눌러도 RUNE_EMPTY로 떨어지지 않는다")
	t.eq(c.rune_at(0), Tuning.ELEM_NONE, "대신 무속성으로 남는다")
	t.ok(c.can_fire(), "그래서 여전히 쏠 수 있다 (거절된 클릭 한 번으로 자기 자신을 무장 해제하지 않는다)")

	# -- the real grant-then-place path still works end to end --
	# **One click inserts now** (`onboarding-and-palette-tabs.md` Stage 4) — 동그라미 has exactly one rune
	#  seat, so pressing the palette cell places it immediately; there is no intermediate "picked" state
	#  to click the seat afterward for.
	pr.grant_rune(Tuning.ELEM_FIRE)
	var items := Palette.items_of(Palette.KIND_RUNE, pr, c)
	var fire_idx := items.find(Tuning.ELEM_FIRE)
	t.ok(fire_idx >= 0, "불을 준 뒤에는 룬 칸에 불이 있다 (전제)")
	var fire_pt := Palette.item_slot(sec, fire_idx, items.size()).get_center()
	win.call("_click_palette", pal, fire_pt)
	t.eq(win.get("_picked_kind"), -1, "한 자리뿐이라 클릭 한 번으로 바로 놓이고 손은 빈다")
	t.eq(c.rune_at(0), Tuning.ELEM_FIRE, "누른 불이 룬 자리에 실제로 놓인다")
	t.ok(c.can_fire(), "불을 놓은 뒤에도 쏠 수 있다")
	win.free()


## **Stage 4 — one click inserts, when there is only one seat** (`onboarding-and-palette-tabs.md`). The
## rule is "how many seats does this kind have" (`_slot_count`), never "which kind is it" — write it as a
## kind check and 삼각's three rune sockets silently collapse to socket 0. **The negative control is the
## whole point of driving 삼각 here**: `_slot_count` is 3 for it, so the same click that inserts on
## 동그라미 must still only *pick* on 삼각.
func _one_click_inserts_when_there_is_only_one_seat(t) -> void:
	var pr := Progress.new()
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	var win := CircleWindow.new()
	win.setup(pr, c)
	win.size = Fx.WINDOW_RECT.size
	var pal := Book.palette_page(win.size)
	var sec := Palette.section(pal.size)

	# -- 진: always one seat, even without one equipped — one click inserts --
	var circle_ti := Palette.KINDS.find(Palette.KIND_CIRCLE)
	win.call("_click_palette", pal, Palette.tabs(pal.size)[circle_ti].get_center())
	var circle_items := Palette.items_of(Palette.KIND_CIRCLE, pr, c)
	var round_idx := circle_items.find(CircleDefs.CIRCLE_ROUND)
	t.ok(round_idx >= 0, "동그라미가 진 칸에 있다 (전제)")
	c.set_circle(CircleDefs.CIRCLE_NONE)
	win.call("_click_palette", pal, Palette.item_slot(sec, round_idx, circle_items.size()).get_center())
	t.eq(c.circle_id(), CircleDefs.CIRCLE_ROUND, "진은 한 번 눌러 바로 끼워진다 (두 번째 클릭이 없다)")
	t.eq(win.get("_picked_kind"), -1, "끼운 뒤 손은 빈다 (골라 든 채로 남지 않는다)")

	# -- 룬 on 동그라미: one seat — one click inserts --
	var rune_ti := Palette.KINDS.find(Palette.KIND_RUNE)
	win.call("_click_palette", pal, Palette.tabs(pal.size)[rune_ti].get_center())
	var rune_items := Palette.items_of(Palette.KIND_RUNE, pr, c)
	var none_idx := rune_items.find(Tuning.ELEM_NONE)
	t.ok(none_idx >= 0, "무속성이 룬 칸에 있다 (전제)")
	win.call("_click_palette", pal, Palette.item_slot(sec, none_idx, rune_items.size()).get_center())
	t.eq(c.rune_at(0), Tuning.ELEM_NONE, "룬도 한 번 눌러 자리 가운데 바로 끼워진다")
	t.eq(win.get("_picked_kind"), -1, "끼운 뒤 손은 빈다")

	# -- 삼각 negative control: three seats — the same click only picks, never inserts --
	c.set_circle(CircleDefs.CIRCLE_TRIANGLE)
	pr.grant_circle(CircleDefs.CIRCLE_TRIANGLE)
	win.call("_click_palette", pal, Palette.tabs(pal.size)[rune_ti].get_center())
	var tri_items := Palette.items_of(Palette.KIND_RUNE, pr, c)
	var tri_idx := tri_items.find(Tuning.ELEM_NONE)
	t.eq(_slot_count_of(win, Palette.KIND_RUNE), 3, "삼각은 룬 자리가 셋이다 (전제 — 이 검사가 재는 대상)")
	win.call("_click_palette", pal, Palette.item_slot(sec, tri_idx, tri_items.size()).get_center())
	t.eq(win.get("_picked_kind"), Palette.KIND_RUNE, "삼각은 세 자리라 한 번 눌러선 안 골리기만 하고 안 끼워진다")
	t.eq(c.rune_at(0), SpellCircle.RUNE_EMPTY, "그래서 0번 소켓엔 아직 안 놓였다")

	# The pick still places through the socket click — pick-then-place survives untouched for 삼각.
	var page := Book.circle_page(win.size)
	var area := Layout.circle_area(page.size)
	var socket0 := Layout.rune_slots(c.circle_id(), area)[0]
	win.call("_click_circle", page, socket0)
	t.eq(c.rune_at(0), Tuning.ELEM_NONE, "소켓을 직접 눌러야 실제로 놓인다 (삼각은 여전히 고르고-놓기다)")
	t.eq(win.get("_picked_kind"), -1, "놓인 뒤 손은 빈다")

	win.free()


## `_slot_count` is a private method — called through `.call()` the same way every other net in this file
## reaches a `Control`'s methods on an untreed window.
func _slot_count_of(win: CircleWindow, kind: int) -> int:
	return int(win.call("_slot_count", kind))


## **Stage 6 — 찰칵 flashes at the item's own seat and falls to zero.** Driven treed (`_draw()` needs a live
## draw context), inserting through the real one-click path (Stage 4) so the seat captured is the seat a
## real placement actually produces, not a hand-picked coordinate.
func _click_fx_flashes_at_the_seat_and_falls_to_zero(t) -> void:
	var pr := Progress.new()
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	var win := _RecordingCircleWindow.new()
	win.setup(pr, c)
	win.size = Fx.WINDOW_RECT.size
	win.visible = true
	t.root.add_child(win)
	await t.pump_frames(2)

	var pal := Book.palette_page(win.size)
	var sec := Palette.section(pal.size)
	var circle_ti := Palette.KINDS.find(Palette.KIND_CIRCLE)
	win.call("_click_palette", pal, Palette.tabs(pal.size)[circle_ti].get_center())
	var items := Palette.items_of(Palette.KIND_CIRCLE, pr, c)
	var round_idx := items.find(CircleDefs.CIRCLE_ROUND)
	# **Place a different circle than what is already equipped** — placing the *same* circle is a no-op
	#  in `SpellCircle.set_circle()`, and this check would then be unable to tell "a click fired" from
	#  "nothing changed and nothing should have flashed".
	c.set_circle(CircleDefs.CIRCLE_NONE)
	win.call("_click_palette", pal, Palette.item_slot(sec, round_idx, items.size()).get_center())
	t.eq(c.circle_id(), CircleDefs.CIRCLE_ROUND, "실제로 놓였다 (전제)")
	win.queue_redraw()
	await t.pump_frames(2)

	# **The captured seat matches the frame's own, independently-computed centre/radius** — not a
	#  hand-picked value, so a `_click_fx` call that resolved the wrong kind's seat would be caught.
	var page := Book.circle_page(win.size)
	var area := Layout.circle_area(page.size)
	var frame := Layout.frame(area)
	t.ok(win.click_fx_calls.size() > 0, "찰칵이 실제로 그려졌다 (%d회)" % win.click_fx_calls.size())
	if win.click_fx_calls.is_empty():
		t.root.remove_child(win)
		win.queue_free()
		return
	var first: Dictionary = win.click_fx_calls[0]
	t.ok((first["at"] as Vector2).is_equal_approx(frame["center"]),
		"찰칵 자리가 진 테두리 중심과 같다 (%s)" % [first["at"]])
	t.ok(is_equal_approx(float(first["r"]), float(frame["radius"])),
		"찰칵 반지름이 진 테두리 반지름과 같다 (%.2f)" % float(first["r"]))
	t.ok(float(first["t"]) > 0.0 and float(first["t"]) <= 1.0,
		"막 놓인 뒤의 t가 (0, 1] 안이다 (%.2f)" % float(first["t"]))

	# **`t` falls, and it stops** — pumped well past `CLICK_FRAMES` (CLAUDE.md: pump past one to be sure).
	win.queue_redraw()
	await t.pump_frames(Fx.CLICK_FRAMES * 2)
	var last: Dictionary = win.click_fx_calls[win.click_fx_calls.size() - 1]
	t.ok(float(last["t"]) < float(first["t"]), "t가 실제로 떨어졌다 (%.2f -> %.2f)" % [
		float(first["t"]), float(last["t"])])
	var before := win.click_fx_calls.size()
	win.queue_redraw()
	await t.pump_frames(3)
	t.eq(win.click_fx_calls.size(), before,
		"CLICK_FRAMES가 지나면 더는 안 그려진다 (%d -> %d)" % [before, win.click_fx_calls.size()])

	t.root.remove_child(win)
	win.queue_free()


## **Stage 6 — 완성 glows once, then closes; firing is identical whether it was pressed or Tab closed the
## window instead.** The plan's own words: "that is a value check (`can_fire()` and `shots()`), not a
## look." Two independently-assembled circles, one closed each way, compared by value.
func _done_glow_then_close_fires_identically_to_tab(t) -> void:
	var pr := Progress.new()
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	c.set_rune(0, Tuning.ELEM_NONE)
	c.place_glyph(0, Glyph.GLYPH_SPREAD)
	var win := _RecordingCircleWindow.new()
	win.setup(pr, c)
	win.size = Fx.WINDOW_RECT.size
	win.visible = true
	t.root.add_child(win)
	await t.pump_frames(2)

	var pal := Book.palette_page(win.size)
	win.call("_click_palette", pal, Palette.done_rect(pal.size).get_center())
	t.ok(win.visible, "완성을 눌러도 글로우가 도는 동안은 창이 계속 보인다 (그래서 계속 클릭을 먹는다)")
	win.queue_redraw()
	await t.pump_frames(2)
	t.ok(win.done_glow_calls.size() > 0, "완성 글로우가 실제로 그려졌다 (%d회)" % win.done_glow_calls.size())
	if win.done_glow_calls.size() > 0:
		var g: Dictionary = win.done_glow_calls[0]
		var page := Book.circle_page(win.size)
		var area := Layout.circle_area(page.size)
		var frame := Layout.frame(area)
		t.ok((g["at"] as Vector2).is_equal_approx(frame["center"]), "글로우 자리가 진 테두리 중심과 같다")
		t.ok(float(g["t"]) > 0.0 and float(g["t"]) <= 1.0, "글로우 t가 (0, 1] 안이다 (%.2f)" % float(g["t"]))

	# **Pumped well past `DONE_GLOW_FRAMES`** — the window must close on its own, without a second `toggle()`.
	win.queue_redraw()
	await t.pump_frames(Fx.DONE_GLOW_FRAMES * 2)
	t.ok(not win.visible, "글로우가 끝나면 창이 저절로 닫힌다")

	# -- the same assembly, closed with Tab instead — must fire byte-identically --
	var c2 := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	c2.set_rune(0, Tuning.ELEM_NONE)
	c2.place_glyph(0, Glyph.GLYPH_SPREAD)
	var win2 := CircleWindow.new()
	win2.setup(pr, c2)
	win2.visible = true
	win2.call("toggle")  # the Tab door
	t.ok(not win2.visible, "Tab으로 닫아도 창은 닫힌다 (전제)")

	t.eq(c.can_fire(), c2.can_fire(), "완성으로 닫은 진과 Tab으로 닫은 진이 똑같이 쏠 수 있다")
	t.eq(c.shots(), c2.shots(), "발사 내용도 완전히 같다 (완성이 조립을 바꾸지 않는다)")

	t.root.remove_child(win)
	win.queue_free()
	win2.free()


## **Actually runs `_draw()` — not a text scan of it.** `net_frame_runner.gd`'s own header corrects a belief
##  this file's siblings (`net_render`/`net_pick`/`net_settlement`) held: `_draw()` was never unmeasurable
##  headless, the old runner just quit before a single engine frame turned. The technique proved there:
##  tree the node under `t.root`, `queue_redraw()`, `await t.pump_frames(n)`.
##
## **What this closes that no geometry check above can, in principle**: every check elsewhere in this file
##  calls `Layout.layer_bands()`/`rune_radius()`/etc. directly — none of them drive `circle_window.gd`'s own
##  *consumption* of those return values. Step 3's rewrite of `_draw_ring` (loop `edges`, read `band["seat"]`
##  instead of a separately-fetched `layer_slots()` array) is exactly the kind of change a wrong index or a
##  stale local variable breaks silently in a text scan and loudly the moment the function actually runs —
##  measured directly while writing it: an earlier draft left a dangling reference to a deleted local and
##  every check above still read green because none of them execute `_draw()`.
##
## **Every assertion here reads a recorded value, not `t.ok(true, ...)`** (verify-read: the original version
## of this check asserted nothing, and a mutation deleting all three draw calls inside `_draw()` left it —
## and every other check in this file — green. `_RecordingCircleWindow` above closes that: it overrides the
## primitives `_draw()`'s loops call, still calls `super` so a real crash is still caught the way it already
## was, and this function reads what actually got recorded).
##
## Two circles' worth of glyphs are placed first (round has 2 layers) so `_draw_ring` takes both its
## "empty seat" and "filled seat" branches, not just one.
func _draw_actually_runs_headless(t) -> void:
	var pr := Progress.new()
	# **A round circle** — `SpellCircle.new()` alone starts empty (Stage 3, 0 layers).
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c.place_glyph(0, Glyph.GLYPH_SPREAD), "그리기 전 1층에 확산을 놓는다 (전제)")
	var win := _RecordingCircleWindow.new()
	win.setup(pr, c)
	win.size = Fx.WINDOW_RECT.size
	win.visible = true
	t.root.add_child(win)
	win.queue_redraw()
	await t.pump_frames(3)
	t.ok(win.is_inside_tree(), "창을 트리에 넣었다 (전제)")

	t.ok(win.frame_calls > 0, "_draw_frame이 실제로 불렸다 (%d회)" % win.frame_calls)
	t.eq(win.triangle_frame_calls, 0, "원형 진은 삼각 테두리 경로를 안 탄다 (%d회)" % win.triangle_frame_calls)
	t.ok(win.rune_slot_calls > 0, "_draw_rune_slot이 실제로 불렸다 (%d회)" % win.rune_slot_calls)
	t.ok(win.ring_calls > 0 and win.ring_calls % c.layer_count() == 0,
		"_draw_ring이 층 수(%d)의 배수만큼 불렸다 (%d회)" % [c.layer_count(), win.ring_calls])
	# **Every recorded ring call stroked exactly one edge** — the round circle's own concentric shape
	#  (`layer_bands`'s own header: `concentric: [outer]`). A mutation that only strokes `edges[0]` would
	#  still pass *this* half (there is only one edge here to begin with) — the triangle block below is
	#  where dropping an edge actually shows up as a count.
	for edges: Array in win.ring_edges:
		t.eq(edges.size(), 1, "원형 진의 밴드 하나당 모서리 하나를 긋는다 (%s)" % [edges])
	t.ok(win.glyph_draws.has(Glyph.GLYPH_SPREAD), "채운 자리(확산)가 실제로 절차적으로 그려졌다 (%s)" % [win.glyph_draws])
	t.ok(win.empty_slot_calls > 0, "빈 자리가 실제로 그려졌다 (%d회)" % win.empty_slot_calls)
	t.eq(win.texture_draws.size(), 0, "원형 진은 소켓 텍스처 경로를 안 탄다 (%d회)" % win.texture_draws.size())

	# **The empty seat still paints — at the same coordinates the layout answers with, not merely "some ring
	#  got drawn somewhere".** Stage 5 deleted the plus mark and left only `_draw_slot_ring`; a count alone
	#  (`empty_slot_calls` above) would stay green even if `_draw_empty_slot` handed it a bare `Vector2()` and
	#  `0.0` — the `notice_rect` hole (CLAUDE.md). Compared against `circle_layout`'s own answer, not a literal.
	# **`pump_frames(3)` draws more than once** — the window `queue_redraw()`s every frame while visible
	#  (Stage 6's own premise), so `_draw_slot_ring` fires once per empty layer **per frame drawn**, not once
	#  total. Measured: 1 empty layer here, 4 recorded calls. The count is asserted as a multiple, the same
	#  idiom `win.ring_calls % c.layer_count() == 0` above already uses for the same reason.
	var area := Layout.circle_area(Book.circle_page(win.size).size)
	var bands := Layout.layer_bands(c.circle_id(), area)
	var want_ring_seats: Array[Vector2] = []
	for i in bands.size():
		if c.glyph_at(i) == Glyph.GLYPH_NONE:
			want_ring_seats.append(bands[i]["seat"])
	t.ok(want_ring_seats.size() > 0, "빈 층이 %d개다 (전제)" % want_ring_seats.size())
	t.ok(win.slot_ring_calls.size() > 0 and win.slot_ring_calls.size() % want_ring_seats.size() == 0,
		"빈 자리 링이 빈 층 수(%d)의 배수만큼 그려졌다 (%d회)" % [want_ring_seats.size(), win.slot_ring_calls.size()])
	for i in win.slot_ring_calls.size():
		var call: Dictionary = win.slot_ring_calls[i]
		var want: Vector2 = want_ring_seats[i % want_ring_seats.size()]
		t.ok((call["at"] as Vector2).is_equal_approx(want),
			"%d번째 빈 자리 링이 실제 밴드 자리에서 그려졌다 (%s)" % [i, call["at"]])
		t.ok(is_equal_approx(call["r"], Layout.glyph_radius(area)),
			"%d번째 빈 자리 링 반지름이 glyph_radius와 같다 (%.5f)" % [i, call["r"] as float])

	t.root.remove_child(win)
	win.queue_free()

	# **The triangle's own draw paths — untouched by the block above.** `PIC_ROUND`'s bands always have
	#  `edges.size() == 1`, so `_draw_ring`'s socket-texture branch (step 6) and `_draw_triangle_frame`
	#  (step 3) are never reached by driving the round circle alone. Socket 0 carries a glyph with art
	#  (the texture branch), socket 1 a glyph with **no** art (the procedural fallback *inside* a socket
	#  band — a different code path from the round circle's own fallback above, since it still tests
	#  `edges.size() > 1` first), and socket 2 is left empty (the empty-seat draw inside a socket band).
	var pr2 := Progress.new()
	var tri := SpellCircle.new(CircleDefs.CIRCLE_TRIANGLE)
	t.ok(tri.place_glyph(0, Glyph.GLYPH_SPREAD), "삼각 진 0번 소켓에 그림 있는 문양을 놓는다 (전제)")
	t.ok(tri.place_glyph(1, Glyph.DUMMY_C), "삼각 진 1번 소켓에 그림 없는 문양을 놓는다 (전제 — 절차적 폴백 경로)")
	var win2 := _RecordingCircleWindow.new()
	win2.setup(pr2, tri)
	win2.size = Fx.WINDOW_RECT.size
	win2.visible = true
	t.root.add_child(win2)
	win2.queue_redraw()
	await t.pump_frames(3)
	t.ok(win2.is_inside_tree(), "삼각 진 창을 트리에 넣었다 (전제)")

	# **The triangle frame — all three named pieces, with values traced back to the constants.**
	#  `_draw_triangle_frame`가 조기 return해도 `triangle_frame_calls`는 그대로 늘어나므로(호출 자체는 됐으니),
	#  실제로 안에서 셋을 다 그렸는지는 세 하위 함수가 각각 불렸는지로만 잡힌다.
	t.ok(win2.triangle_frame_calls > 0, "_draw_triangle_frame이 실제로 불렸다 (%d회)" % win2.triangle_frame_calls)
	t.ok(win2.wrap_ring_calls.size() > 0, "감싸는 링이 실제로 그려졌다 (%d회)" % win2.wrap_ring_calls.size())
	# `_draw()`가 창 안에서 계산하는 것과 같은 식 — 리터럴을 박지 않고 같은 경로로 구한다.
	var frame_r: float = Layout.frame(Layout.circle_area(Book.circle_page(Fx.WINDOW_RECT.size).size))["radius"]
	var basis := frame_r / float(Fx.TRI_CANVAS_R)
	for r: float in win2.wrap_ring_calls:
		t.ok(is_equal_approx(r, float(Fx.TRI_RING) * basis),
			"감싸는 링 반지름이 TRI_RING에서 나온다 (%.3f)" % r)
	t.ok(win2.link_calls.size() > 0, "연결 띠가 실제로 그려졌다 (%d회)" % win2.link_calls.size())
	for link: Dictionary in win2.link_calls:
		t.eq(int(link["count"]), 3, "연결 띠가 소켓 3개를 잇는다 (%d)" % int(link["count"]))
		t.ok(is_equal_approx(float(link["width"]), float(Fx.TRI_LINK_HALF) * basis * 2.0),
			"연결 띠 두께가 TRI_LINK_HALF에서 나온다 (%.3f)" % float(link["width"]))
	t.ok(win2.ornament_calls.size() > 0, "중심 장식이 실제로 그려졌다 (%d회)" % win2.ornament_calls.size())
	for orn: Dictionary in win2.ornament_calls:
		t.ok(is_equal_approx(float(orn["outer_r"]), float(Fx.TRI_CENTER_R) * basis),
			"장식 바깥 반지름이 TRI_CENTER_R에서 나온다 (%.3f)" % float(orn["outer_r"]))
		t.ok(is_equal_approx(float(orn["band"]), float(Fx.TRI_BAND) * basis),
			"장식 띠 두께가 TRI_BAND에서 나온다 (%.3f)" % float(orn["band"]))

	# **Every recorded socket ring call stroked exactly two edges** — this is what `for e in [edges[0]]`
	#  (dropping the socket band's inner rim) would break, and the round-only block above cannot reach.
	for edges: Array in win2.ring_edges:
		t.eq(edges.size(), 2, "삼각 진의 소켓 밴드 하나당 모서리 두 개(바깥·안쪽)를 긋는다 (%s)" % [edges])

	t.ok(win2.texture_draws.size() > 0, "텍스처 경로(_draw_socket_glyph_texture)가 실제로 불렸다 (%d회)" % win2.texture_draws.size())
	var textured_ids: Array[int] = []
	for d: Dictionary in win2.texture_draws:
		textured_ids.append(int(d["glyph_id"]))
	t.ok(textured_ids.has(Glyph.GLYPH_SPREAD), "그림 있는 문양(확산)이 텍스처 경로로 그려졌다 (%s)" % [textured_ids])
	t.ok(win2.glyph_draws.has(Glyph.DUMMY_C), "그림 없는 문양(더미)이 절차적 폴백으로 그려졌다 (%s)" % [win2.glyph_draws])
	t.ok(win2.empty_slot_calls > 0, "2번 소켓(빈 자리)이 실제로 그려졌다 (%d회)" % win2.empty_slot_calls)

	# **The socket's own rarity ring — a real regression once, fixed** (verify-read: the first version of
	#  the texture path drew no rarity ring at all, leaving every rarity of a family pixel-identical on a
	#  socket, against the decided "rarity separates by color" rule). Measures that the ring is drawn **with
	#  the placed glyph's own id** — not skipped, and not always reading rarity for a fixed id.
	t.ok(win2.rarity_ring_calls.has(Glyph.GLYPH_SPREAD),
		"텍스처로 그린 문양(확산)의 희귀도 링이 그 문양 자신의 id로 그려졌다 (%s)" % [win2.rarity_ring_calls])

	t.root.remove_child(win2)
	win2.queue_free()


## **Tabs, the open section and the 완성 band are drawn from the exact rects `palette_layout` computes** —
## the `settlement_layout.notice_rect` lesson: a pure function asserted alone let `_draw()` hand it a bare
## `Rect2()` under 320 green checks. `_RecordingCircleWindow` captures the argument at each hook.
func _palette_tabs_and_done_are_drawn_from_the_layout(t) -> void:
	var pr := Progress.new()
	# **A round circle** — the empty-note-disappears phase below places a glyph, which needs a real layer
	#  (`SpellCircle.new()` alone is `CIRCLE_NONE`, Stage 3's empty boot, with 0 layers).
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	var win := _RecordingCircleWindow.new()
	win.setup(pr, c)
	win.size = Fx.WINDOW_RECT.size
	win.visible = true
	t.root.add_child(win)
	win.queue_redraw()
	await t.pump_frames(3)
	t.ok(win.is_inside_tree(), "창을 트리에 넣었다 (전제)")

	# **`_process` redraws every frame while visible, so several `_draw()` passes accumulate** across the
	#  three pumped frames (the same reason `_draw_actually_runs_headless` asserts ring calls as a
	#  *multiple* of the layer count rather than an exact count). Every pass draws the identical layout, so
	#  only the size-is-a-multiple-of-n check and the tail slice are asserted, not a raw count.
	var pal := Book.palette_page(win.size)
	var want_tabs := Palette.tabs(pal.size)
	var n := Palette.KINDS.size()
	t.ok(win.tab_draws.size() > 0 and win.tab_draws.size() % n == 0,
		"탭이 종류 수(%d)의 배수만큼 그려졌다 (%d회)" % [n, win.tab_draws.size()])
	var last_tabs := win.tab_draws.slice(win.tab_draws.size() - n, win.tab_draws.size())
	var open_count := 0
	for i in n:
		var d: Dictionary = last_tabs[i]
		t.ok((d["rect"] as Rect2).is_equal_approx(want_tabs[i]),
			"%d번 탭의 그려진 자리가 palette_layout.tabs()의 답과 같다" % i)
		t.eq(int(d["kind"]), Palette.KINDS[i], "%d번 탭에 맞는 종류가 그려졌다" % i)
		if bool(d["is_open"]):
			open_count += 1
	t.eq(open_count, 1, "열린 탭은 정확히 하나다 (%d개)" % open_count)

	t.ok(win.section_draws.size() > 0, "구획이 실제로 그려졌다 (%d회)" % win.section_draws.size())
	var last_sec: Dictionary = win.section_draws[win.section_draws.size() - 1]
	t.ok((last_sec["rect"] as Rect2).is_equal_approx(Palette.section(pal.size)),
		"그려진 구획이 palette_layout.section()의 답과 같다")
	t.eq(int(last_sec["kind"]), Palette.KINDS[int(win.get("_open_tab"))], "그려진 구획이 열린 탭의 종류다")

	t.ok(win.done_draws.size() > 0, "완성 띠가 실제로 그려졌다 (%d회)" % win.done_draws.size())
	t.ok((win.done_draws[win.done_draws.size() - 1] as Rect2).is_equal_approx(Palette.done_rect(pal.size)),
		"그려진 완성 띠가 palette_layout.done_rect()의 답과 같다")

	# **문양 tab starts empty, and says so** (design §3) — switch to it and the note must actually paint,
	#  not merely be computable. The recording arrays are cleared first so this phase is not muddied by
	#  the accumulated draws from the phase above.
	var glyph_ti := Palette.KINDS.find(Palette.KIND_GLYPH)
	win.call("_click_palette", pal, want_tabs[glyph_ti].get_center())
	win.empty_note_draws.clear()
	win.queue_redraw()
	await t.pump_frames(3)
	t.ok(win.empty_note_draws.size() > 0,
		"문양 칸이 비어 있을 때 빈 문구가 실제로 그려졌다 (%d회)" % win.empty_note_draws.size())
	t.ok((win.empty_note_draws[0] as Rect2).is_equal_approx(Palette.section(pal.size)),
		"빈 문구가 palette_layout.section()의 답 안에서 그려졌다")

	# **The empty note must not paint once a glyph is seated** — the other branch of the same guard.
	c.place_glyph(0, Glyph.GLYPH_SPREAD)
	win.empty_note_draws.clear()
	win.queue_redraw()
	await t.pump_frames(3)
	t.eq(win.empty_note_draws.size(), 0, "문양이 생기면 빈 문구가 그려지지 않는다 (%d회)" % win.empty_note_draws.size())

	t.root.remove_child(win)
	win.queue_free()


## **Does the hit test use the same coordinates as the drawing — and does it actually land?**
##  With coordinates in two places it becomes "I clicked this and that got picked" and **no error shows** (risk 6).
## Here it is measured by **execution**, not text — the drawn positions are clicked directly.
func _hit_tests_match_the_drawing(t) -> void:
	var page := Book.circle_page(Fx.WINDOW_RECT.size)
	var area := Layout.circle_area(page.size)
	var id := CircleDefs.CIRCLE_ROUND

	# **Click a drawn position and that layer comes out.** Every layer has to give its own number.
	var slots := Layout.layer_slots(id, area)
	t.ok(slots.size() > 0, "누를 층이 %d개다" % slots.size())
	for i in slots.size():
		t.eq(Layout.layer_at(id, area, slots[i]), i, "%d층 심볼 자리를 누르면 %d층이다" % [i, i])

	# **It does not eat its neighbors.** Make the click circle too large and clicking layer 1 grabs layer 2.
	var clean := true
	for i in slots.size():
		for j in slots.size():
			if i != j and Layout.layer_at(id, area, slots[j]) == i:
				clean = false
	t.ok(clean, "층 누르는 자리가 서로 안 겹친다 (누르기 반경 ×%.1f)" % Fx.SLOT_HIT_RATIO)

	# An empty position is -1. Otherwise a background click touches the wrong layer.
	t.eq(Layout.layer_at(id, area, Vector2.ZERO), -1, "구석을 누르면 아무 층도 아니다")
	t.eq(Layout.rune_slot_at(id, area, Layout.rune_slots(id, area)[0]), 0,
		"룬 자리를 누르면 0번이다")

	# ══ **Measured across kinds** — until now only layer against layer ══════
	# **Re-measured for `onboarding-and-palette-tabs.md` Stage 5** — growing the rune (`CIRCLE_RUNE_RATIO`
	#  0.17 -> 0.26) and starting the ring zone outside it (`CIRCLE_RING_GAP_FRAC`) pushed the layer seats far
	#  enough out that the loop below now finds a **positive gap** for every layer instead of an overlap.
	#  **This was never a demand to remove the overlap** — the only thing pinned down is that clicking a
	#  drawn thing grabs that thing, which still holds; do not read the sign flip as a bug to revert.
	var rune_c := Layout.rune_slots(id, area)[0]
	var rune_draw := Layout.rune_radius(id, area)
	var layer_hit := Layout.glyph_radius(area) * Fx.SLOT_HIT_RATIO
	for i in slots.size():
		var gap := rune_c.distance_to(slots[i]) - layer_hit
		t.ok(gap >= rune_draw,
			"그려진 룬 원반(%.1f)이 %d층 히트 영역 밖이다 (여유 %.1f)" % [
				rune_draw, i, gap - rune_draw])

	# **This premise flipped with Stage 5, and the flip is the point, not a regression.**
	#  Before the rune grew, the drawn glyph symbols sat **inside** the rune's hit circle, so unless
	#  `_click_circle` looked at layers **first**, glyphs could not be clicked at all — geometry alone did not
	#  keep the two apart, only click order did. **Re-measured, not assumed** (CLAUDE.md: do not force the old
	#  sentence true again by adjusting a ratio) — the grown rune and the outward-pushed seats now clear the
	#  rune's hit circle on their own. The order check right below is kept anyway: it is still correct, still
	#  cheap, and nothing here demands geometry alone carry this contract forever.
	var rune_hit := rune_draw * Fx.SLOT_HIT_RATIO
	var clears_the_rune := true
	for i in slots.size():
		if rune_c.distance_to(slots[i]) <= rune_hit + Layout.glyph_radius(area):
			clears_the_rune = false
	t.ok(clears_the_rune, "커진 룬 덕에 문양 심볼이 이제 룬 히트 영역 밖이다 (전에는 겹쳐서 순서만이 계약이었다)")
	var click := _func_body(_stripped(t, WINDOW_PATH, "circle_window"), "_click_circle")
	t.ok(click != "", "`_click_circle()` 를 찾았다")
	var i_layer := click.find("layer_at")
	var i_rune := click.find("rune_slot_at")
	var i_frame := click.find("frame_has_point")
	t.ok(i_layer >= 0 and i_rune > i_layer,
		"층을 룬보다 **먼저** 본다 (안 그러면 문양이 안 눌린다)")
	t.ok(i_frame > i_rune,
		"진을 맨 **나중에** 본다 (진 슬롯이 테두리 안 전체라 먼저 보면 다 먹는다)")

	# **"Can this be picked" must not branch by kind.**
	#  A real defect came from exactly there — `_can_pick` asked only for glyphs and always gave `true` for circles and runes,
	#   so with the circle removed **the rune stayed bright and pickable while clicking did nothing** (verify-look).
	#  What differs per kind should be only two things — **how slots are counted** and **what they accept** — and the question is one.
	#  It is a `Control` method so it **cannot be called** — text only blocks the branch from coming back.
	var win_src := _stripped(t, WINDOW_PATH, "circle_window")
	var pick := _func_body(win_src, "_can_pick")
	t.ok(pick != "", "`_can_pick()` 를 찾았다")
	t.ok(not pick.contains("KIND_"),
		"「고를 수 있나」가 종류로 안 갈린다 (셋이 같은 물음을 지난다)")
	t.ok(pick.contains("_slot_count(") and pick.contains("_slot_accepts("),
		"「고를 수 있나」가 슬롯 수와 받는 조건으로만 갈린다")

	# ── palette ──
	# **A fuller kit** — 삼각 granted, 불 granted, spread seated — so every tab has more than one cell and
	#  the hidden-tab test below actually exercises a real "same coordinates, different kind" collision.
	var pal := Book.palette_page(Fx.WINDOW_RECT.size)
	var ppr := Progress.new()
	ppr.grant_circle(CircleDefs.CIRCLE_TRIANGLE)
	ppr.grant_rune(Tuning.ELEM_FIRE)
	# **A round circle** — `place_glyph` below needs a real layer (`SpellCircle.new()` alone is empty,
	#  Stage 3's boot state).
	var pc := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	pc.place_glyph(0, Glyph.GLYPH_SPREAD)
	var sec := Palette.section(pal.size)
	var found := 0
	for ki in Palette.KINDS.size():
		var kind: int = Palette.KINDS[ki]
		var items := Palette.items_of(kind, ppr, pc)
		for ii in items.size():
			var slot := Palette.item_slot(sec, ii, items.size())
			var center := slot.get_center()
			var hit := Palette.item_at(pal.size, center, ki, ppr, pc)
			t.ok(not hit.is_empty(), "%s 탭이 열려 있을 때 항목 %d을 누르면 뭔가 잡힌다" % [
				Palette.KIND_DEFS[kind]["name"], ii])
			if hit.is_empty():
				continue
			found += 1
			t.eq(int(hit["kind"]), kind, "누른 칸의 종류가 맞다")
			t.eq(int(hit["item"]), items[ii], "누른 칸의 항목이 맞다")
			# **The hidden-tab hit test, both directions** (`onboarding-and-palette-tabs.md` Stage 1's own
			#  named risk): with any other tab open, the exact same coordinates must never resolve to
			#  *this* (closed) kind's item — a closed tab's former cells are not merely undrawn, the hit
			#  test forgets them too. **Not asserted as "returns nothing"** — two tabs with the same item
			#  count divide the section identically, so the same point can legitimately belong to the
			#  *open* tab's own cell (e.g. 진 and 룬 both owning exactly one item makes their single cells
			#  coincide exactly). What must never happen, regardless of geometry, is the closed kind's own
			#  id leaking through — which is exactly what a mutation ignoring `open_tab` (falling back to
			#  scanning every kind, the pre-Stage-1 behavior) would do.
			for other in Palette.KINDS.size():
				if other == ki:
					continue
				var other_hit := Palette.item_at(pal.size, center, other, ppr, pc)
				t.ok(other_hit.is_empty() or int(other_hit["kind"]) != kind,
					"%s 탭이 열려 있을 때 %s의 항목은 절대 안 잡힌다" % [
						Palette.KIND_DEFS[Palette.KINDS[other]]["name"], Palette.KIND_DEFS[kind]["name"]])
	t.ok(found > 0, "팔레트에서 실제로 누른 항목이 %d개다" % found)
	# Outside the open tab's items — inside the section, above the item row — is nothing.
	t.ok(Palette.item_at(pal.size, sec.position, 0, ppr, pc).is_empty(), "제목 띠 자리를 누르면 아무것도 아니다")
	# A tab index outside `KINDS` (nothing open) never resolves to any kind's cells.
	t.ok(Palette.item_at(pal.size, sec.get_center(), -1, ppr, pc).is_empty(), "열린 탭이 없으면 아무것도 안 잡힌다")


## **Do the palette and the slots use the same symbol function?**
##  If not, it becomes "the blast in the palette looks different from the blast placed in the circle", and that is **quiet** —
##   measured, turning the palette glyph into a magenta disc still passed (verify-read).
##  The circle really had split: `_draw_frame` drew `draw_circle` directly while
##   `_draw_circle_symbol` drew the same picture separately. **Runes and glyphs shared it; only the circle did not.**
##
## What is measured is narrow: **do both the slot side and the palette side call the same name.**
##  "Does that function actually draw the same picture" is invisible to text (the same limit as `contains` throughout this file).
func _symbols_are_shared(t) -> void:
	var win := _stripped(t, WINDOW_PATH, "circle_window")
	# [symbol function, slot-side function, palette-side function]
	var shared: Array[Array] = [
		["_draw_circle_symbol", "_draw_frame", "_draw_palette_item"],
		["_draw_rune_symbol", "_draw_rune_slot", "_draw_palette_item"],
		["_draw_glyph", "_draw_ring", "_draw_palette_item"],
	]
	t.ok(shared.size() > 0, "심볼 공유를 재 볼 자리가 %d군데다" % shared.size())
	for c: Array in shared:
		for caller: String in [c[1], c[2]]:
			var body := _func_body(win, caller)
			t.ok(body != "", "`%s()` 를 찾았다" % caller)
			t.ok(body.contains("%s(" % c[0]),
				"`%s()` 가 심볼을 `%s()` 로 그린다 (따로 안 그린다)" % [caller, c[0]])


## **The triangle's hit shapes — measured by clicking, not by reading the formula back** (the same discipline
## `_hit_tests_match_the_drawing` already holds for the round circle). Two mutations verify-read found that
## no existing check caught: `layer_bands`'s `hit` widened to `Vector2(0.0, outer)` (the layer band swallows
## the rune sitting inside it) and `rune_slot_at`'s `PIC_TRIANGLE` guard on `SLOT_HIT_RATIO` deleted (the
## rune's disc inflates past the socket's own rim). Both need a **real click test** — the plan's own risk
## table already named the geometry (`0.3375 > 0.28125`), but nothing before this drove `layer_at`/
## `rune_slot_at` with points inside/at the boundary of a real socket to prove it.
func _triangle_hit_shapes_stay_disjoint(t) -> void:
	var page := Book.circle_page(Fx.WINDOW_RECT.size)
	var area := Layout.circle_area(page.size)
	var id := CircleDefs.CIRCLE_TRIANGLE
	var bands := Layout.layer_bands(id, area)
	var seats := Layout.rune_slots(id, area)
	t.eq(bands.size(), 3, "삼각 진 밴드가 셋이다 (전제)")
	t.eq(seats.size(), 3, "삼각 진 소켓이 셋이다 (전제)")
	if bands.size() != 3 or seats.size() != 3:
		return

	for i in bands.size():
		var band: Dictionary = bands[i]
		var edges: PackedFloat32Array = band["edges"]
		t.eq(edges.size(), 2, "%d번 밴드에 모서리가 둘이다 (전제)" % i)
		if edges.size() != 2:
			continue
		var outer: float = edges[0]
		var inner: float = edges[edges.size() - 1]
		var center: Vector2 = seats[i]

		# Well inside the rune's own disc — the layer band must not claim it, and the rune must.
		var rune_pt := center + Vector2(0.0, -inner * 0.5)
		t.eq(Layout.layer_at(id, area, rune_pt), -1,
			"%d번 소켓의 룬 영역 안쪽(거리 %.2f < 안쪽 모서리 %.2f)은 층 밴드가 아니다" % [i, inner * 0.5, inner])
		t.eq(Layout.rune_slot_at(id, area, rune_pt), i,
			"%d번 소켓의 룬 영역 안쪽은 그 소켓의 룬으로 잡힌다" % i)

		# The middle of the band itself — the layer must claim it, and the rune must not.
		var band_pt := center + Vector2(0.0, -(inner + outer) * 0.5)
		t.eq(Layout.layer_at(id, area, band_pt), i,
			"%d번 소켓 밴드 한가운데는 그 층으로 잡힌다" % i)
		t.eq(Layout.rune_slot_at(id, area, band_pt), -1,
			"%d번 소켓 밴드 한가운데는 룬으로 안 잡힌다 (`SLOT_HIT_RATIO`를 곱했다면 여기까지 넘쳤을 자리)" % i)

		# Just past the socket's own outer rim — neither the layer nor the rune may claim it. This is
		# exactly where a missing `PIC_TRIANGLE` guard on `SLOT_HIT_RATIO` (inflating the rune to
		# `inner * 1.8`) spills past the socket's own boundary.
		var outside_pt := center + Vector2(0.0, -(outer + 1.0))
		t.eq(Layout.layer_at(id, area, outside_pt), -1,
			"%d번 소켓 바로 바깥은 층으로 안 잡힌다" % i)
		t.eq(Layout.rune_slot_at(id, area, outside_pt), -1,
			"%d번 소켓 바로 바깥은 룬으로도 안 잡힌다 (룬이 소켓 밖으로 안 넘친다)" % i)


## Do the sections and item cells **come from one place and not overlap.** Overlap and it becomes "I clicked this
##  and that got picked" with **no error** (the palette's face of risk 6).
## **Rewritten for tabs** (`onboarding-and-palette-tabs.md` Stage 1) — `section()` no longer varies by kind
## (there is exactly one open body, regardless of which tab), so what moved into this check is the tab
## strip and the 완성 band, both new geometry eating vertical budget out of the same page.
func _palette_geometry_runs(t) -> void:
	var page := Book.palette_page(Fx.WINDOW_RECT.size)
	t.ok(page.size.x > 0.0 and page.size.y > 0.0, "팔레트 페이지에 크기가 있다 (%dx%d)" % [
		int(page.size.x), int(page.size.y)])
	var page_box := Rect2(Vector2.ZERO, page.size)

	var tab_rects := Palette.tabs(page.size)
	t.eq(tab_rects.size(), Palette.KINDS.size(), "탭이 종류 수(%d)만큼이다" % Palette.KINDS.size())
	for i in tab_rects.size():
		t.ok(tab_rects[i].size.x > 0.0 and tab_rects[i].size.y > 0.0, "%d번 탭에 크기가 있다" % i)
		t.ok(page_box.encloses(tab_rects[i]), "%d번 탭이 페이지 안에 들어간다" % i)
		for j in range(i + 1, tab_rects.size()):
			t.ok(not tab_rects[i].intersects(tab_rects[j]), "%d·%d번 탭이 안 겹친다" % [i, j])

	var sec := Palette.section(page.size)
	t.ok(sec.size.x > 0.0 and sec.size.y > 0.0, "열린 구획에 크기가 있다")
	t.ok(page_box.encloses(sec), "열린 구획이 페이지 안에 들어간다")
	for i in tab_rects.size():
		t.ok(not sec.intersects(tab_rects[i]), "열린 구획이 탭 띠와 안 겹친다")

	var done := Palette.done_rect(page.size)
	t.ok(done.size.x > 0.0 and done.size.y > 0.0, "완성 띠에 크기가 있다")
	t.ok(page_box.encloses(done), "완성 띠가 페이지 안에 들어간다")
	t.ok(not sec.intersects(done), "열린 구획이 완성 띠와 안 겹친다")
	for i in tab_rects.size():
		t.ok(not done.intersects(tab_rects[i]), "완성 띠가 탭 띠와 안 겹친다")

	# **Item cells, for every kind the palette can ever open on.** A fuller kit (삼각·불·확산 granted/seated)
	#  so a multi-cell row is measured too, not only the one-cell starting row.
	var pr := Progress.new()
	# **A round circle** — `place_glyph` below needs a real layer.
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	pr.grant_circle(CircleDefs.CIRCLE_TRIANGLE)
	pr.grant_rune(Tuning.ELEM_FIRE)
	c.place_glyph(0, Glyph.GLYPH_SPREAD)
	for kind: int in Palette.KINDS:
		var nm: StringName = Palette.KIND_DEFS[kind]["name"]
		var items := Palette.items_of(kind, pr, c)
		var slots: Array[Rect2] = []
		for ii in items.size():
			var slot := Palette.item_slot(sec, ii, items.size())
			t.ok(sec.encloses(slot), "%s 항목 %d이 구획 안에 들어간다" % [nm, ii])
			# Intrude on the title band and the text and the symbols eat each other.
			# **A grain of slack is left.** An item's top edge is **exactly** the title band's end, and `Rect2`
			#  holds its values as **32-bit floats** while this comparison is 64-bit => depending on window size the last
			#  bit rolls downward and **the same value reads as "it intruded".**
			t.ok(slot.position.y >= sec.position.y + Fx.PALETTE_HEAD_PX - RECT_EPS,
				"%s 항목 %d이 제목 띠 아래에 있다" % [nm, ii])
			# **The symbol fits inside the cell.** Look only at `> 0` and switching to the long side still passes —
			#  then only the single-item kinds (circle, rune) grow huge and overflow their cells, and it gets misread
			#  as "is the circle the most important one". The decision that the short side decides is held here.
			var sym := Palette.item_symbol_radius(slot)
			t.ok(sym > 0.0, "%s 항목 %d에 심볼 크기가 있다" % [nm, ii])
			t.ok(sym * 2.0 <= minf(slot.size.x, slot.size.y),
				"%s 항목 %d의 심볼(지름 %.1f)이 칸(%dx%d) 안에 든다" % [
					nm, ii, sym * 2.0, int(slot.size.x), int(slot.size.y)])
			for other: Rect2 in slots:
				t.ok(not slot.intersects(other), "%s 항목 %d이 앞 항목과 안 겹친다" % [nm, ii])
			slots.append(slot)

	# **The palette does not intrude on the spell circle page.** Intrude and the two pages lose their meaning.
	#  The palette is **relative to its own page origin**, so it has to be moved into window coordinates to be measured.
	var circle_page := Book.circle_page(Fx.WINDOW_RECT.size)
	for r: Rect2 in tab_rects + [sec, done]:
		t.ok(not Rect2(page.position + r.position, r.size).intersects(circle_page),
			"팔레트 요소가 마법진 페이지를 안 침범한다")


## **Nothing was holding what the eye had found.**
##  At stage 4a, spread's 6 rays looked like **a 4-ray X** on screen — the symbol sits at 12 o'clock on the ring where
##  the tangent is horizontal, and **the 0-degree and 180-degree rays fold onto the ring line and vanish.**
##  It was fixed at 4b-1 by rotating half a step, but **reverting `GLYPH_SPAWN_ANGLE_STEP_FRAC` to 0 still left
##  all 908 checks green** (verify-read, measured). What the eye had found once was defenceless.
##
## **It is pure geometry, so the net can measure it.** "Is there a horizontal ray" is computable without looking at the screen.
func _spawn_rays_are_not_horizontal(t) -> void:
	var n := Fx.GLYPH_SPAWN_RAYS
	# At 0 the loop below does not run and it **goes green.**
	t.ok(n > 0, "확산 갈래가 %d개다" % n)

	# **With an odd count, even rotating half a step one ray necessarily lands on 180 degrees:**
	#  `360(k+0.5)/N = 180` iff `k = (N-1)/2`, and that being an integer is equivalent to **N being odd.**
	#  => It is not "it can land there" but "it must land there", so an even count is pinned as a contract.
	t.eq(n % 2, 0, "갈래 수(%d)가 짝수다 (홀수면 하나가 반드시 수평이다)" % n)

	for k in n:
		var a := TAU * (float(k) + Fx.GLYPH_SPAWN_ANGLE_STEP_FRAC) / float(n)
		# When `sin` is near 0 that ray is horizontal and overlaps the ring's tangent, so it **vanishes on screen.**
		#  0.1 is the floor for "is it noticeably tilted" — at around 5.7 degrees it is still eaten by the ring.
		t.ok(absf(sin(a)) > 0.1, "갈래 %d가 수평이 아니다 (%.0f°)" % [k, rad_to_deg(a)])


## **Not one net actually called the layout functions.**
##  So `_radius()` returning 0 stayed green, and the spell circle **collapsing to a single point** made nobody bark.
##   A text scan sees **syntax** and cannot see **behavior** — this is the other side of that.
##
## And the plan wrote "it barks when `rune_slots != 1`" down as **a device that hangs on the wrapper's stderr for free**,
##  but with no net calling that function it **was not free.** What follows actually calls it.
func _layout_geometry_runs(t) -> void:
	# The spell circle lives **inside its own page.** It takes the page size, not the window size.
	#  Which side it is on is known by `book_layout` — hardcode the key here and it splits the day left and right swap.
	var page := Book.circle_page(Fx.WINDOW_RECT.size)
	var area := Layout.circle_area(page.size)
	t.ok(area.size.x > 0.0 and area.size.y > 0.0,
		"마법진 자리에 크기가 있다 (%dx%d)" % [int(area.size.x), int(area.size.y)])
	t.ok(area.end.x <= page.size.x and area.end.y <= page.size.y,
		"마법진 자리가 페이지 안에 들어간다")

	var f := Layout.frame(area)
	var fr: float = f["radius"]
	# At 0 the spell circle **collapses to a single point.** A place a text scan cannot see in principle.
	t.ok(fr > 0.0, "진 테두리 반지름이 0이 아니다 (%.1f)" % fr)
	t.ok(area.has_point(f["center"]), "진 중심이 마법진 자리 안에 있다")

	for id: int in CircleDefs.ALL:
		var nm: StringName = CircleDefs.DEFS[id]["name"]
		var bands := Layout.layer_bands(id, area)
		t.eq(bands.size(), CircleDefs.layers(id), "진 %s의 밴드 수가 층 수와 같다" % nm)

		for b: Dictionary in bands:
			var edges: PackedFloat32Array = b["edges"]
			t.ok(edges.size() > 0, "진 %s의 밴드에 모서리가 있다" % nm)

		# **Concentric-only vs. socket-only — the plan's own warning.** "Grows inside-out" is a `PIC_ROUND`
		#  property (one shared center, bands nest); the triangle's three bands sit at three *different*
		#  centers and are all the same size, so the same monotonic check would fail on a correct triangle
		#  circle for the wrong reason. Each picture gets its own geometry, not a relaxed shared one.
		if CircleDefs.picture(id) == CircleDefs.PIC_TRIANGLE:
			_triangle_band_geometry(t, id, nm, area, f, fr, bands)
		else:
			_concentric_band_geometry(t, nm, fr, bands, Layout.rune_radius(id, area))

		var slots := Layout.layer_slots(id, area)
		t.eq(slots.size(), bands.size(), "진 %s의 문양 자리 수가 밴드 수와 같다" % nm)
		var inside := true
		for p: Vector2 in slots:
			if p.distance_to(f["center"]) > fr:
				inside = false
		t.ok(inside, "진 %s의 문양 자리가 전부 테두리 안이다" % nm)

		t.eq(Layout.rune_slots(id, area).size(), CircleDefs.rune_slots(id),
			"진 %s의 룬 자리 수가 표와 같다" % nm)

		t.ok(Layout.rune_radius(id, area) > 0.0, "진 %s의 룬 자리 반지름이 0이 아니다" % nm)

	t.ok(Layout.glyph_radius(area) > 0.0, "문양 심볼 반지름이 0이 아니다")

	# **Does the layer number follow the radius.** Hardcode it and only the number freezes as the circle grows,
	#  which **weakens one of the two devices** that say "the inside comes first" (design acceptance 3).
	#  It happened, measured — the window went 28.4% -> 90% and the diameter 199 -> 364 while the number stayed frozen at 12.
	var small := Layout.circle_area(page.size * 0.5)
	t.ok(Layout.layer_num_size(area) > Layout.layer_num_size(small),
		"층 번호가 진이 커지면 같이 커진다 (%d > %d)" % [
			Layout.layer_num_size(area), Layout.layer_num_size(small)])
	# However small it gets, it never drops to an unreadable size.
	t.ok(Layout.layer_num_size(small) >= Fx.CIRCLE_LAYER_NUM_MIN, "층 번호에 하한이 있다")

	# **"There is no circle" is normal, so it has to stay quiet.** Make it bark here and the ordinary act of removing
	#  the circle turns the wrapper red. `expect_error` is **deliberately not written** — a bark is a failure as is.
	t.eq(Layout.rune_slots(CircleDefs.CIRCLE_NONE, area).size(), 0,
		"진이 없으면 룬 자리가 0개다 (조용히)")
	t.eq(Layout.layer_bands(CircleDefs.CIRCLE_NONE, area).size(), 0,
		"진이 없으면 밴드가 0개다 (조용히)")

	# **The bark in `rune_slots()` moved, not disappeared** (step 4 of the plan). It used to fire on
	#  `rune_slots != 1` for the round picture; now that `picture` decides the layout, the thing that
	#  "cannot be derived" is an unrecognized picture id, so that is what it barks on now. Both `PIC_ROUND`
	#  and `PIC_TRIANGLE` are handled, so **this bark still cannot be reached by execution today** — text is
	#  the only thing that can confirm it was not deleted along with the check it replaced.
	t.ok(_func_body(_stripped(t, "res://src/view/circle_layout.gd", "circle_layout"),
		"rune_slots").contains("push_error"),
		"룬 배치가 안 되는 picture에 짖는 코드가 살아 있다 (n != 1 짖음의 후신)")


## **`PIC_ROUND`'s geometry — concentric bands sharing one center.** Split out of `_layout_geometry_runs`
## once the triangle circle made "one shared shape for every picture" false (this function's own header there).
func _concentric_band_geometry(t, nm: StringName, fr: float, bands: Array[Dictionary], rune_r: float) -> void:
	# **It grows from the inside outward.** Reverse it and "the inside comes first" becomes false in the drawing.
	# **`edges[0]` is the outer edge** (`edges` is outer-first) — the value that must grow band to band.
	var outers: Array[float] = []
	for b: Dictionary in bands:
		var edges: PackedFloat32Array = b["edges"]
		outers.append(edges[0] if edges.size() > 0 else 0.0)
	var grows := outers.size() > 0
	for i in outers.size():
		if outers[i] <= 0.0 or (i > 0 and outers[i] <= outers[i - 1]):
			grows = false
	t.ok(grows, "진 %s의 밴드 바깥 모서리가 안에서 밖으로 커진다 %s" % [nm, outers])
	if outers.size() == 0:
		return
	t.ok(outers[outers.size() - 1] <= fr,
		"진 %s의 바깥 밴드가 테두리를 안 넘는다 (%.1f ≤ %.1f)" % [nm, outers[outers.size() - 1], fr])
	# The rune is dead center — if the first band is inside the rune the two are drawn on top of each other.
	t.ok(outers[0] > rune_r, "진 %s의 1층 밴드가 룬 자리 바깥이다" % nm)


## **`PIC_TRIANGLE`'s geometry — three independent socket bands, not one shared center.**
## Measures exactly what the plan's step 4 named: seat 0 above center (the one clue the picture gives for
## "goes first"), the three seats 120° apart, each socket fitting inside the frame, and — the triangle's own
## version of "the layer doesn't sit on top of the rune" — the band's inner edge landing **exactly** on the
## rune's own radius (`rune_radius`'s `PIC_TRIANGLE` branch and `layer_bands`' `TRI_SOCKET_R - TRI_BAND` are
## the same subtraction; if the two ever drift apart this is where it is caught).
func _triangle_band_geometry(t, id: int, nm: StringName, area: Rect2, f: Dictionary, fr: float, bands: Array[Dictionary]) -> void:
	var center: Vector2 = f["center"]
	var seats := Layout.rune_slots(id, area)
	t.eq(seats.size(), bands.size(), "진 %s의 소켓 수가 밴드 수와 같다" % nm)
	if seats.size() == 0:
		return

	var d0 := seats[0] - center
	t.ok(is_equal_approx(d0.x, 0.0) and d0.y < 0.0,
		"진 %s의 0번 소켓이 중심 정각 12시 방향이다 (오프셋 %s)" % [nm, d0])

	var n := seats.size()
	for i in n:
		var j := (i + 1) % n
		var ai := (seats[i] - center).angle()
		var aj := (seats[j] - center).angle()
		# **Signed, not `absf`.** An unsigned 120° step also passes with the winding reversed (seat 1 and 2
		#  swapped) — measured: `absf` alone left this green with `TRI_SOCKET_DEG` reordered to
		#  `[-90, 150, 30]`. `Vector2.angle()` is measured in this engine's y-down screen space, where a
		#  **positive** step is clockwise — exactly the direction `docs/design/circle-rune-glyph.md`'s
		#  "12 o'clock is #1" needs seat 1 and 2 to follow in.
		var diff := wrapf(aj - ai, -PI, PI)
		t.ok(is_equal_approx(diff, deg_to_rad(120.0)),
			"진 %s의 소켓 %d-%d 사이가 시계 방향으로 120도다 (%.1f도)" % [nm, i, j, rad_to_deg(diff)])

	var rune_r := Layout.rune_radius(id, area)
	for i in n:
		var dist := seats[i].distance_to(center)
		var edges: PackedFloat32Array = bands[i]["edges"]
		t.ok(edges.size() > 0, "진 %s의 %d번 소켓 밴드에 모서리가 있다" % [nm, i])
		if edges.size() == 0:
			continue
		var socket_r := edges[0]
		t.ok(dist + socket_r <= fr + RECT_EPS,
			"진 %s의 %d번 소켓이 테두리 안에 들어간다 (거리 %.1f + 반경 %.1f ≤ %.1f)" % [
				nm, i, dist, socket_r, fr])
		# The band's inner edge (`edges` is outer-first, so the last element) is where the rune's own disc
		#  ends — the two must meet exactly, or either a gap (dead space nobody can click) or an overlap
		#  (the rune drawn on top of the band) appears with no error raised.
		var inner := edges[edges.size() - 1]
		t.ok(is_equal_approx(inner, rune_r),
			"진 %s의 %d번 밴드 안쪽 모서리가 룬 반지름과 같다 (%.3f ≈ %.3f)" % [nm, i, inner, rune_r])


## **This is the single reason this stage existed** — what the design doc "boundary" demanded was **split the axes.**
##  Three of the four circles (2 runes fused, 3 runes in parallel, glyphs per rune) have **entirely different drawings**,
##  and written as one lump the assembly window gets rebuilt that day.
##
## **If only a comment holds that they are split, they are as good as unsplit.** Measured —
##  reverting `_draw_ring` to call `Layout.frame(area)["center"]` again left **all 833 checks green.**
##  => The layer drawing hangs off the circle axis and nobody barks.
##
## What is measured is **one direction only: the layer and rune axes do not call the circle axis (`frame`).**
##  `layer_slots` calling `layer_bands` is **the same axis and so not coupling** — it must not be caught.
##   That is why this was not widened into "no function calls any function".
func _axes_do_not_call_each_other(t) -> void:
	var layout := _stripped(t, "res://src/view/circle_layout.gd", "circle_layout")
	var window := _stripped(t, "res://src/view/circle_window.gd", "circle_window")

	# [file, function, call that must not be present, label]
	var cases: Array[Array] = [
		[layout, "layer_bands", "frame(", "층 좌표"],
		[layout, "layer_slots", "frame(", "층 좌표(자리)"],
		[layout, "rune_slots", "frame(", "룬 좌표"],
		[window, "_draw_ring", "Layout.frame(", "층 그림"],
		[window, "_draw_rune_slot", "Layout.frame(", "룬 그림"],
		# **Step 3's own new coupling risk.** The triangle frame (링·연결 띠·중심 장식) reads socket centers —
		#  it must read them from the shared helper, not from the rune axis's own `rune_slots()`, or the circle
		#  axis ends up hanging off the rune axis (the same disease this whole check list watches for).
		[window, "_draw_triangle_frame", "Layout.rune_slots(", "삼각 진 테두리"],
	]
	t.ok(cases.size() > 0, "축 결합을 재 볼 자리가 %d군데다" % cases.size())
	for c: Array in cases:
		var body := _func_body(c[0], c[1])
		# If the function is not found, the line below **checks an empty string and goes green.**
		t.ok(body != "", "`%s()` 를 찾았다" % c[1])
		t.ok(not body.contains(c[2]), "%s가 진 축(`%s`)을 안 부른다" % [c[3], c[2]])

	# The other side — calls within the same axis **have to stay alive.** Without this, nobody notices when the
	#  checks above pass as "nobody calls anything".
	t.ok(_func_body(layout, "layer_slots").contains("layer_bands("),
		"층 자리는 층 밴드에서 나온다 (같은 축이라 결합이 아니다)")


## Source with comments and strings stripped. If a triple quote is present the stripper stops there, so **the rest
##  drops out of the scan entirely and goes silently green** — that assumption is measured alongside.
func _stripped(t, path: String, nm: String) -> String:
	var raw := _read(path)
	t.ok(not raw.contains("\"\"\""), "%s 에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)" % nm)
	return NetDeterminism._strip(raw)


## From `func <name>(` up to before **the next function header.** If not found, an empty string.
## `static func` also contains `func`, so one pattern catches both — the drawing side (`circle_window`) is
##  not static, so this property is needed.
func _func_body(src: String, fname: String) -> String:
	var head := src.find("func %s(" % fname)
	if head < 0:
		return ""
	# The next function header is **a `func`/`static func` at the start of a line.** Inner indentation does not trip it.
	var tail := -1
	for marker: String in ["\nfunc ", "\nstatic func "]:
		var at := src.find(marker, head + 1)
		if at >= 0 and (tail < 0 or at < tail):
			tail = at
	var body := src.substr(head) if tail < 0 else src.substr(head, tail - head)
	# **The next function's doc comment comes along with it.** If what is written there is read as this function's code,
	#  the check goes silently wrong (a neighboring function's comment can make a forbidden call read as "present").
	#  => Cut at a line-leading `##`. `##` never appears **inside** a function.
	var doc := body.find("\n##")
	return body if doc < 0 else body.substr(0, doc)


# ══════════════════════════════════════════════════════════════════
#  The empty layer — the quietest trap in this plan
# ══════════════════════════════════════════════════════════════════

## Leaves layer 1 empty and places a glyph only in layer 2.
##
## ```
## packed as is:  g = GLYPH_NONE | (BLAST << 4)
##                first(g) = 0 = "end of list"  ->  the bolt flies carrying **an empty list**
## ```
## => The blast disappears. **With not one error.**
func _empty_layer_is_skipped(t) -> void:
	# **A round circle with a rune placed by hand** — `SpellCircle.new()` alone starts empty (Stage 3),
	#  and `sim.fire()` below needs a real, filled rune (`c.element()` on an empty rune slot is
	#  `RUNE_EMPTY`, not a real element).
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c.set_rune(0, Tuning.ELEM_NONE), "룬을 놓는다 (전제)")
	t.ok(c.place_glyph(1, Glyph.GLYPH_BLAST), "2층에만 폭발을 놓는다")
	t.eq(c.glyph_at(0), Glyph.GLYPH_NONE, "1층은 비어 있다")
	t.eq(c.glyph_at(1), Glyph.GLYPH_BLAST, "2층에 폭발이 있다")

	var g := c.packed_glyphs()
	t.eq(Glyph.first(g), Glyph.GLYPH_BLAST, "빈 1층을 건너뛰어 폭발이 **첫** 문양이 된다")
	t.eq(Glyph.rest(g), Glyph.GLYPH_NONE, "그 뒤는 목록 끝이다")

	# Measures the trap itself — what value comes out if an empty layer is packed as is.
	#  The shift is done only in the net. Doing it in the source puts a shift outside `glyph_defs`'s three functions.
	var naive := Glyph.GLYPH_BLAST << Tuning.GLYPH_BITS
	t.eq(Glyph.first(naive), Glyph.GLYPH_NONE,
		"그대로 팩하면 첫 문양이 「목록 끝」이 된다 (그래서 건너뛴다)")
	t.ok(g != naive, "조밀하게 팩한 값(%d)이 그대로 팩한 값(%d)과 다르다" % [g, naive])

	# **Followed through into the sim.** If only the pack is right and it does not actually detonate, it means nothing —
	#  "the screen changes and the sim does not" is this repo's representative fake.
	var grid := _wall_grid()
	var sim := SpellSim.new()
	t.ok(sim.fire(SpellSim.cmd_fire(10, 70, 100, 0, c.element(), g)),
		"2층에만 놓은 마법진이 발사된다")
	t.eq(_run_ticks(sim, grid, 12), 1, "그 폭발이 실제로 터진다 (증발하지 않는다)")

	# Control — empty both layers and there is no blast. Without it, the green above could be "the bolt detonates anyway".
	var empty := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(empty.set_rune(0, Tuning.ELEM_NONE), "룬을 놓는다 (전제)")
	t.eq(empty.packed_glyphs(), Glyph.GLYPH_NONE, "두 층을 다 비우면 빈 목록이다")
	var grid2 := _wall_grid()
	var sim2 := SpellSim.new()
	# Design doc "extreme values": fire with every layer empty and **it has to fire.** A circle plus a rune alone already makes a spell.
	t.ok(sim2.fire(SpellSim.cmd_fire(10, 70, 100, 0, empty.element(), empty.packed_glyphs())),
		"층을 다 비워도 쏴진다 (진 + 룬만)")
	t.eq(_run_ticks(sim2, grid2, 12), 0, "문양이 없으면 폭발이 없다")


# ══════════════════════════════════════════════════════════════════
#  Stage 8 — move_glyph() reorders a seated glyph, never removes it
# ══════════════════════════════════════════════════════════════════

## **The swap itself, at the model level.** Three shapes: moving into an empty layer, swapping two occupied
## layers, and the two guard rails (same-slot no-op, out-of-range bark).
func _move_glyph_swaps_layers_and_never_duplicates(t) -> void:
	# -- into an empty layer: the source empties, the destination gets it, nothing is duplicated --
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c.place_glyph(0, Glyph.GLYPH_SPREAD), "확산을 1층에 놓는다 (전제)")
	t.eq(c.glyph_at(1), Glyph.GLYPH_NONE, "2층은 비어 있다 (전제)")
	t.ok(c.move_glyph(0, 1), "1층의 확산을 2층으로 옮긴다")
	t.eq(c.glyph_at(0), Glyph.GLYPH_NONE, "1층은 비었다 (그대로 남지 않는다 — 복제가 아니다)")
	t.eq(c.glyph_at(1), Glyph.GLYPH_SPREAD, "2층에 확산이 있다")
	t.eq(c.glyph_list().size(), 1, "문양 목록 크기는 하나 그대로다 (늘지 않았다)")

	# -- swapping two occupied layers: both move, neither vanishes --
	var c2 := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c2.place_glyph(0, Glyph.GLYPH_SPREAD), "확산을 1층에 놓는다 (전제)")
	t.ok(c2.place_glyph(1, Glyph.GLYPH_BLAST), "폭발을 2층에 놓는다 (전제)")
	t.ok(c2.move_glyph(0, 1), "1층과 2층을 맞바꾼다")
	t.eq(c2.glyph_at(0), Glyph.GLYPH_BLAST, "1층엔 이제 폭발이다")
	t.eq(c2.glyph_at(1), Glyph.GLYPH_SPREAD, "2층엔 이제 확산이다")
	t.eq(c2.glyph_list().size(), 2, "둘 다 살아있다 (하나도 안 사라졌다)")

	# -- same slot: a harmless no-op --
	var before := c2.glyph_list()
	t.ok(c2.move_glyph(0, 0), "같은 층으로 '옮겨도' 성공을 answer한다 (무해한 무동작)")
	t.eq(c2.glyph_list(), before, "아무것도 안 바뀌었다")

	# -- out of range: barks, and moves nothing --
	var before2 := c2.glyph_list()
	t.expect_error("SpellCircle: move_glyph")
	t.ok(not c2.move_glyph(-1, 0), "범위 밖 인덱스는 짖고 실패한다")
	t.eq(c2.glyph_list(), before2, "짖은 뒤에도 배치는 그대로다 (아무것도 안 움직였다)")
	t.expect_error("SpellCircle: move_glyph")
	t.ok(not c2.move_glyph(0, c2.layer_count()), "층 수를 넘는 목적지도 짖고 실패한다")
	t.eq(c2.glyph_list(), before2, "역시 아무것도 안 움직였다")


## **`seated_layers()` — the layer index behind each `glyph_list()` entry, in the same order.** With a
## triangle circle (3 layers, one per family — no two entries can share a family, but nothing stops the
## same *value* twice across circles) this proves it is a real per-instance index, not merely `glyph_list()`
## re-derived.
func _seated_layers_matches_glyph_list_position_for_position(t) -> void:
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.eq(c.seated_layers(), [] as Array[int], "빈 진은 앉은 층도 없다")
	t.ok(c.place_glyph(1, Glyph.GLYPH_BLAST), "2층에만 폭발을 놓는다 (전제 — 1층은 빈다)")
	t.eq(c.seated_layers(), [1] as Array[int], "앉은 층 목록이 [1]이다 (1층이 아니라 2층에 앉았다)")
	t.ok(c.place_glyph(0, Glyph.GLYPH_SPREAD), "1층에도 확산을 놓는다")
	t.eq(c.seated_layers(), [0, 1] as Array[int], "이제 [0, 1] — glyph_list()와 자리가 정확히 대응한다")
	t.eq(c.glyph_list(), [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST] as Array[int], "전제 — 값 목록도 그 순서다")


## **The palette-to-circle move, end to end** (`onboarding-and-palette-tabs.md` Stage 8) — the exact bug
## the plan's own "finding 2" named: picking a seated glyph and clicking a *different* layer used to either
## duplicate it (dummy, unlimited) or get silently rejected (a capped family already holding it elsewhere).
## Driven through the real click path on an untreed window, the same technique every other pick test in
## this file already uses.
func _the_glyph_tab_moves_a_seated_glyph_between_layers(t) -> void:
	var pr := Progress.new()
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c.place_glyph(0, Glyph.GLYPH_SPREAD), "확산을 1층에 놓는다 (전제)")
	t.ok(c.place_glyph(1, Glyph.GLYPH_BLAST), "폭발을 2층에 놓는다 (전제)")
	var win := CircleWindow.new()
	win.setup(pr, c)
	win.size = Fx.WINDOW_RECT.size

	var pal := Book.palette_page(win.size)
	var glyph_ti := Palette.KINDS.find(Palette.KIND_GLYPH)
	win.call("_click_palette", pal, Palette.tabs(pal.size)[glyph_ti].get_center())
	t.eq(win.get("_open_tab"), glyph_ti, "문양 탭을 열었다 (전제)")

	var sec := Palette.section(pal.size)
	var items := Palette.items_of(Palette.KIND_GLYPH, pr, c)
	t.eq(items, [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST] as Array[int], "문양 칸에 확산·폭발 순서로 있다 (전제)")
	var spread_pt := Palette.item_slot(sec, 0, items.size()).get_center()

	# -- pick the seated spread (layer 0), then click layer 1's own seat: a swap --
	win.call("_click_palette", pal, spread_pt)
	t.eq(win.get("_picked_kind"), Palette.KIND_GLYPH, "확산 카드를 골랐다")
	t.eq(win.get("_picked_layer"), 0, "그 카드가 실제로 온 층은 0번이다 (전제)")

	var page := Book.circle_page(win.size)
	var area := Layout.circle_area(page.size)
	var seat1: Vector2 = Layout.layer_bands(c.circle_id(), area)[1]["seat"]
	win.call("_click_circle", page, seat1)
	t.eq(c.glyph_at(0), Glyph.GLYPH_BLAST, "1층엔 이제 폭발이다 (확산이 빠지고 폭발이 왔다 — 복제가 아니다)")
	t.eq(c.glyph_at(1), Glyph.GLYPH_SPREAD, "2층엔 이제 확산이다")
	t.eq(c.glyph_list().size(), 2, "여전히 둘뿐이다 (늘지 않았다)")
	t.eq(win.get("_picked_kind"), -1, "옮긴 뒤 손은 빈다")
	t.eq(win.get("_picked_layer"), -1, "_picked_layer도 같이 비워진다")

	# -- picking the same seated card again drops the pick (unchanged from before Stage 8) --
	items = Palette.items_of(Palette.KIND_GLYPH, pr, c)
	var blast_now_at_0 := Palette.item_slot(sec, 0, items.size()).get_center()
	win.call("_click_palette", pal, blast_now_at_0)
	t.eq(win.get("_picked_kind"), Palette.KIND_GLYPH, "폭발(지금 1층) 카드를 골랐다")
	win.call("_click_palette", pal, blast_now_at_0)
	t.eq(win.get("_picked_kind"), -1, "같은 카드를 다시 누르면 손을 놓는다")

	# -- moving to the same layer the pick came from: a harmless no-op through the real click path --
	win.call("_click_palette", pal, blast_now_at_0)
	var seat0: Vector2 = Layout.layer_bands(c.circle_id(), area)[0]["seat"]
	win.call("_click_circle", page, seat0)
	t.eq(c.glyph_at(0), Glyph.GLYPH_BLAST, "제자리로 '옮겨도' 아무것도 안 바뀐다")
	t.eq(c.glyph_at(1), Glyph.GLYPH_SPREAD, "2층도 그대로다")
	win.free()


## **Duplicate values, told apart by position — the exact case a bare item id cannot resolve.** Dummy is
## the one family with `max_per_circle: 0` (unlimited), so a round circle can legitimately seat the same
## id on both layers.
func _duplicate_dummy_glyphs_are_told_apart_by_layer(t) -> void:
	var pr := Progress.new()
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c.place_glyph(0, Glyph.DUMMY_C), "더미를 1층에 놓는다 (전제)")
	t.ok(c.place_glyph(1, Glyph.DUMMY_C), "같은 더미를 2층에도 놓는다 (전제 — 무제한 계열이라 허용된다)")
	var win := CircleWindow.new()
	win.setup(pr, c)
	win.size = Fx.WINDOW_RECT.size

	var pal := Book.palette_page(win.size)
	var glyph_ti := Palette.KINDS.find(Palette.KIND_GLYPH)
	win.call("_click_palette", pal, Palette.tabs(pal.size)[glyph_ti].get_center())
	var sec := Palette.section(pal.size)
	var items := Palette.items_of(Palette.KIND_GLYPH, pr, c)
	t.eq(items, [Glyph.DUMMY_C, Glyph.DUMMY_C] as Array[int], "두 칸 다 값은 같은 더미다 (전제 — 이 검사의 핵심)")

	# Pick cell 0 (layer 0) — `_picked_layer` must read 0, never guess from the value alone.
	win.call("_click_palette", pal, Palette.item_slot(sec, 0, items.size()).get_center())
	t.eq(win.get("_picked_layer"), 0, "0번 칸을 고르면 0번 층에서 온 것으로 잡힌다")

	# Pressing cell 1 (same value, different position) switches the pick instead of dropping it.
	win.call("_click_palette", pal, Palette.item_slot(sec, 1, items.size()).get_center())
	t.eq(win.get("_picked_kind"), Palette.KIND_GLYPH, "값이 같아도 다른 자리를 누르면 손을 놓지 않는다")
	t.eq(win.get("_picked_layer"), 1, "대신 1번 층으로 고른 자리가 바뀐다")
	win.free()


# ══════════════════════════════════════════════════════════════════
#  Round trip — the door the debug keys come in through
# ══════════════════════════════════════════════════════════════════

## After `set_from_packed(g)`, `packed_glyphs() == g`. Without it the loadout drifts a little on every key press,
##  and that difference shows **only in the counts.**
func _round_trip(t) -> void:
	var cases: Array[Array] = [
		[],
		[Glyph.GLYPH_BLAST],
		[Glyph.GLYPH_SPREAD],
		[Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST],
		[Glyph.GLYPH_BLAST, Glyph.GLYPH_SPREAD],   # the same two as above in a different order
		[Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST],
	]
	for list: Array in cases:
		var typed: Array[int] = []
		typed.assign(list)
		var packed := Glyph.pack(typed)
		# **A round circle** — `set_from_packed` needs real layers to fill.
		var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
		t.ok(c.set_from_packed(packed), "목록 %s가 진에 들어간다" % [typed])
		t.eq(c.packed_glyphs(), packed, "목록 %s가 왕복한다" % [typed])
		t.eq(c.glyph_list(), typed, "목록 %s의 층 순서가 살아남는다" % [typed])

	# **Filled from the front layer.** With one blast it is blast in layer 1 and an empty layer 2.
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	# **The rune is placed by hand before the preset, so "the preset does not touch it" is actually
	#  measured** — `SpellCircle.new()` alone no longer arms the rune (Stage 3).
	var c1 := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c1.set_rune(0, Tuning.ELEM_NONE), "룬을 놓는다 (전제)")
	c1.set_from_packed(Glyph.pack(one))
	t.eq(c1.glyph_at(0), Glyph.GLYPH_BLAST, "문양 하나는 안쪽 층(1층)에 앉는다")
	t.eq(c1.glyph_at(1), Glyph.GLYPH_NONE, "2층은 빈다")
	# A preset changes **only the glyphs** — it does not touch the circle or the rune.
	t.eq(c1.circle_id(), CircleDefs.CIRCLE_ROUND, "프리셋이 진을 안 건드린다")
	t.ok(c1.can_fire(), "프리셋이 룬을 안 건드린다")

	# **No previous state may survive an overwrite.** Without clearing, pressing key 3 (one layer) after key 4 (two layers)
	#  leaves the previous glyph in layer 2 and it becomes "I removed it and it did not come out" — acceptance 1 dies there.
	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	var c2 := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	c2.set_from_packed(Glyph.pack(two))
	c2.set_from_packed(Glyph.pack(one))
	t.eq(c2.glyph_list(), one, "두 층 뒤에 한 층을 넣으면 뒤 층이 비워진다")
	c2.set_from_packed(Glyph.GLYPH_NONE)
	t.eq(c2.packed_glyphs(), Glyph.GLYPH_NONE, "빈 목록을 넣으면 층이 전부 빈다")

	# ── things it cannot accept ──
	var three: Array[int] = [Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST]
	t.expect_error("glyphs into a")
	t.ok(not c2.set_from_packed(Glyph.pack(three)), "3층 목록은 2층 진에 안 들어간다")

	var twice: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_SPREAD]
	t.expect_error("hits a glyph constraint")
	t.ok(not c2.set_from_packed(Glyph.pack(twice)),
		"클릭으로 못 놓는 배치는 프리셋으로도 안 들어간다")
	t.eq(c2.packed_glyphs(), Glyph.GLYPH_NONE, "거절된 목록이 상태를 안 건드린다")

	# A negative **spins forever** — `rest` is an arithmetic shift, so `-1 >> 4 == -1`.
	#  It is the kind that freezes the frame with no error, so it is blocked at the door.
	t.expect_error("negative list")
	t.ok(not c2.set_from_packed(-1), "음수 목록은 짖고 버린다")


# ══════════════════════════════════════════════════════════════════
#  Constraints — blocked **before** placing
# ══════════════════════════════════════════════════════════════════

## **Failing after the shot reads as a malfunction** (design doc, "extreme values"). If a spread is already there,
##  the second spread has to be blocked **before it is placed.**
func _cap_blocks_before_placing(t) -> void:
	t.eq(int(Glyph.DEFS[Glyph.GLYPH_SPREAD]["max_per_circle"]), 1,
		"확산은 한 마법진에 하나까지다 (GDD)")
	t.eq(int(Glyph.DEFS[Glyph.GLYPH_BLAST]["max_per_circle"]), 0, "폭발은 무제한이다 (0)")

	# **A round circle** — `SpellCircle.new()` alone has 0 layers (Stage 3's empty boot).
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c.can_place_glyph(0, Glyph.GLYPH_SPREAD), "빈 진의 1층에 확산을 놓을 수 있다")
	t.ok(c.place_glyph(0, Glyph.GLYPH_SPREAD), "확산을 놓는다")
	t.ok(not c.can_place_glyph(1, Glyph.GLYPH_SPREAD), "두 번째 확산은 **놓기 전에** 막힌다")
	t.ok(not c.place_glyph(1, Glyph.GLYPH_SPREAD), "막힌 배치는 놓기도 실패한다")
	t.eq(c.glyph_at(1), Glyph.GLYPH_NONE, "막힌 놓기가 층을 안 건드린다")

	# **Overwriting the same layer must not be blocked.** Counting only "how many are there now" counts itself
	#  one more time and **blocks something that should be placeable** — that looks like "it is already there and I cannot change it".
	t.ok(c.can_place_glyph(0, Glyph.GLYPH_SPREAD), "확산이 있는 층에 확산을 덮어쓰는 것은 된다")
	t.ok(c.can_place_glyph(0, Glyph.GLYPH_BLAST), "확산이 있는 층을 폭발로 바꿀 수 있다")

	# Blast is unlimited, so two layers have to pass — a constraint that catches **every glyph** is a different bug.
	var b := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(b.place_glyph(0, Glyph.GLYPH_BLAST), "1층에 폭발")
	t.ok(b.place_glyph(1, Glyph.GLYPH_BLAST), "2층에도 폭발 (무제한이다)")

	# Removing always works. And once removed, spread can be placed again.
	t.ok(c.place_glyph(0, Glyph.GLYPH_NONE), "층을 비우는 것은 늘 된다")
	t.ok(c.can_place_glyph(1, Glyph.GLYPH_SPREAD), "빼고 나면 확산을 다시 놓을 수 있다")

	# Out-of-range layers and glyphs not in the table. If the hit test drifts, it goes to the wrong layer **with no error.**
	t.ok(not c.can_place_glyph(-1, Glyph.GLYPH_BLAST), "없는 층(-1)에는 못 놓는다")
	t.ok(not c.can_place_glyph(c.layer_count(), Glyph.GLYPH_BLAST), "층 수를 넘는 층에는 못 놓는다")
	t.ok(not c.can_place_glyph(0, Glyph.MASK), "표에 없는 문양은 못 놓는다")


## **The mirror of `net_spell._unknown_id_after_a_capped_glyph_barks_not_crashes` — the same bug class,
##  the assembly-window side.** `_cap_blocks_before_placing`'s own `can_place_glyph(0, Glyph.MASK)` line just
##  above does **not** reach `_count_family` — a single unknown id at an otherwise-empty layer is rejected by
##  `_list_ok`'s own loop before any counting happens. **It needs a capped, valid glyph placed first**, so the
##  cap check for *that* glyph walks the whole list and reaches the unknown one.
##
## **`expect_error` is not used here — `can_place_glyph`/`_list_ok` are deliberately silent by design**
##  (`can_place_glyph`'s own header: "It must not bark here"), so there is no bark to declare an amnesty for in
##  the first place. That silence is exactly why this class of bug hides so well on this side: a crash inside
##  a function that returns `false` either way changes nothing about the boolean the caller sees.
## **Measured, not assumed**: with the guard removed, `can_place_glyph` still returns `false` — that assertion
##  alone would have stayed green under the mutation, the same way the `fire()`-side check did before its own
##  fix. What actually differs is `_count_family`'s own return value: the crashed `family_of` call on the
##  unknown id silently coerces into matching `FAMILY_SPREAD`, so the guardless version counts **2**, not 1,
##  for this exact list — that is the value this check pins.
func _unknown_id_after_a_capped_glyph_does_not_crash_the_window(t) -> void:
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.ok(c.place_glyph(0, Glyph.SPREAD_C), "1층에 확산을 놓는다 (전제)")
	t.ok(not Glyph.DEFS.has(Glyph.MASK), "MASK 자체는 정의되지 않은 id다 (검사의 전제)")

	var list: Array[int] = [Glyph.SPREAD_C, Glyph.MASK]
	t.eq(SpellCircle._count_family(list, Glyph.FAMILY_SPREAD), 1,
		"모르는 id를 건너뛰고 정확히 1로 센다 (죽으면서 우연히 맞는 값이 나오는 게 아니다)")
	t.ok(not c.can_place_glyph(1, Glyph.MASK),
		"확산이 있는 층 뒤에 모르는 id가 와도 죽지 않고 그냥 거절한다")


# ══════════════════════════════════════════════════════════════════
#  Both ways agree — **only this** measures that there are not two copies of the rules
# ══════════════════════════════════════════════════════════════════

## An arrangement `can_place_glyph` lets through is also **accepted** by `spell_sim.fire()`,
## and one it blocks is also **rejected** by `fire()`.
##
## Measuring only one side misses the split:
##  · assembly window too loose -> firing does nothing (reads as "broken")
##  · assembly window too tight -> a buildable spell cannot be built (nobody knows)
##
## **Every possible arrangement is walked** — per layer it is "empty plus every glyph". Hand-pick a sample and
##  new combinations drop out of the check as glyphs grow, and nobody knows what dropped out.
func _both_ways_agree(t) -> void:
	var options: Array[int] = [Glyph.GLYPH_NONE]
	options.append_array(Glyph.ALL)
	var slots := SpellCircle.new(CircleDefs.CIRCLE_ROUND).layer_count()
	var cases := _all_arrangements(options, slots)
	t.ok(cases.size() > 1, "돌아 볼 배치가 %d가지다 (문양 %d종 · %d층)" % [
		cases.size(), Glyph.ALL.size(), slots])

	# Blocked arrangements are thrown at `fire()` as is, so it barks there — that is the evidence of "it rejected them".
	t.expect_error("per magic circle")

	var allowed_n := 0
	var blocked_n := 0
	var agree := true
	var packs_agree := true
	for arrangement: Array in cases:
		var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
		var allowed := true
		for i in arrangement.size():
			if not c.place_glyph(i, arrangement[i]):
				allowed = false
				break

		# The list that arrangement **would have fired.** Empty layers are skipped (the same rule as the assembly state).
		var dense: Array[int] = []
		for id: int in arrangement:
			if id != Glyph.GLYPH_NONE:
				dense.append(id)
		var packed := Glyph.pack(dense)

		var sim := SpellSim.new()
		var accepted := sim.fire(
			SpellSim.cmd_fire(10, 70, 100, 0, Tuning.ELEM_FIRE, packed))
		if allowed != accepted:
			agree = false
			t.ok(false, "배치 %s — 조립은 %s인데 발사는 %s다" % [
				dense, "통과" if allowed else "거부", "통과" if accepted else "거부"])
		if allowed:
			allowed_n += 1
			if c.packed_glyphs() != packed:
				packs_agree = false
		else:
			blocked_n += 1

	t.ok(agree, "조립이 통과시킨 것은 발사도 받고, 막은 것은 발사도 거부한다")
	t.ok(packs_agree, "통과한 배치의 팩된 목록이 발사에 넘긴 것과 같다")
	# **Both sides have to actually exist for the green above to mean anything.** All-pass is indistinguishable from
	#  "it blocks nothing", and all-reject is indistinguishable from "nothing can be built".
	t.ok(allowed_n > 0, "통과한 배치가 있다 (%d가지)" % allowed_n)
	t.ok(blocked_n > 0, "막힌 배치가 있다 (%d가지)" % blocked_n)


## Every arrangement that picks one of `options` per layer. When glyphs or layers grow, this grows **on its own.**
func _all_arrangements(options: Array[int], slots: int) -> Array:
	var out: Array = []
	var total := 1
	for _i in slots:
		total *= options.size()
	for k in total:
		var one: Array[int] = []
		var rest := k
		for _i in slots:
			one.append(options[rest % options.size()])
			rest /= options.size()
		out.append(one)
	return out


# ══════════════════════════════════════════════════════════════════
#  Debug keys — did we break A
# ══════════════════════════════════════════════════════════════════

## **Keys 1 through 5 have to behave exactly as before.** If they differ, A (`spell-pipeline-minimum`) has been broken,
##  and those combinations are the measuring device for acceptance 1 and 2 (design doc, "comparison controls").
## It reads the real table in `stage.gd` — if the net holds a copy it does not age along when the table changes.
func _presets_still_work(t) -> void:
	var keys: Array = Stage.LOADOUTS.keys()
	keys.sort()
	t.ok(keys.size() > 0, "프리셋이 있다 (%d개)" % keys.size())
	for n: int in keys:
		var list: Array[int] = []
		list.assign(Stage.LOADOUTS[n])
		var packed := Glyph.pack(list)
		# **A round circle with a rune placed by hand** — `set_from_packed` only ever touches glyphs
		#  (its own contract), so the rune has to be armed separately now that the constructor no longer
		#  arms it (Stage 3's empty boot).
		var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
		t.ok(c.set_rune(0, Tuning.ELEM_NONE), "룬을 놓는다 (전제)")
		t.ok(c.set_from_packed(packed), "키 %d의 프리셋이 진에 들어간다" % n)
		t.eq(c.glyph_list(), list, "키 %d가 같은 목록을 같은 순서로 내놓는다" % n)
		t.eq(c.packed_glyphs(), packed, "키 %d가 같은 정수로 팩된다" % n)
		t.ok(c.can_fire(), "키 %d를 누른 뒤에도 쏠 수 있다" % n)
		var sim := SpellSim.new()
		t.ok(sim.fire(SpellSim.cmd_fire(10, 70, 100, 0, c.element(), c.packed_glyphs())),
			"키 %d의 마법진이 발사된다" % n)

	# **Inverted from what this line used to pin** (`onboarding-and-palette-tabs.md` Stage 3, user
	#  confirmed: "시작하자마자 못 쏘는 게 맞다") — a fresh `SpellCircle` used to be `DEFAULT_CIRCLE` with
	#  `DEFAULT_RUNE` already in the seat; now it is genuinely empty, and firing on it must not be possible.
	#  `DEFAULT_CIRCLE`/`DEFAULT_RUNE` are not gone — they still feed `apply_preset()` below, the debug
	#  keys' own door back to a fireable circle from empty.
	var fresh := SpellCircle.new()
	t.eq(fresh.circle_id(), CircleDefs.CIRCLE_NONE, "새 진은 CIRCLE_NONE이다 (아무것도 안 채워진다)")
	t.eq(fresh.layer_count(), 0, "새 진은 층이 0이다")
	t.eq(fresh.rune_count(), 0, "새 진은 룬 자리가 0이다")
	t.ok(not fresh.can_fire(), "새 진은 쏠 수 없다 (시작하자마자 못 쏘는 게 맞다 — 사용자 확정)")

	# **The debug keys still restore a fireable circle from empty** — the one thing `apply_preset`'s own
	#  comment says `DEFAULT_CIRCLE`/`DEFAULT_RUNE` exist for. Driven through the actual door, not asserted
	#  as a property of the constants alone.
	var n0: int = keys[0]
	var list0: Array[int] = []
	list0.assign(Stage.LOADOUTS[n0])
	t.ok(fresh.apply_preset(SpellCircle.DEFAULT_CIRCLE, SpellCircle.DEFAULT_RUNE, Glyph.pack(list0)),
		"빈 진에서 프리셋을 눌러도 받아들여진다")
	t.ok(fresh.can_fire(), "빈 진에서 눌러도 다시 쏠 수 있게 된다 (디버그 키가 갇히지 않게 하는 유일한 길)")

	# Does the shell apply the preset through **one function** — unrolled into three lines, the order gets decided again there.
	t.ok(_read("res://src/stage/stage.gd").contains("apply_preset("),
		"디버그 키가 `apply_preset()` 으로 들어간다")


## **`_set_loadout` used to pass `SpellCircle.DEFAULT_CIRCLE` unconditionally into `apply_preset()`**
## (verify-read) — with a triangle circle equipped, every debug loadout key (1-5) silently swapped it back
## to round, destroying sockets 1 and 2 and whatever runes/glyphs sat there. **Driven on a real `Stage`,
## the same technique `net_render.gd` already proved for this exact function** (`root.call("_set_loadout",
## n)`) — `_set_loadout` only touches `_circle` (a plain member, valid the instant `Stage.new()` runs, no
## `_ready()`/scene tree needed), so a bare, untreed `Stage.new()` is enough here.
func _set_loadout_preserves_the_equipped_circle(t) -> void:
	var stage := Stage.new()
	var circle: Variant = stage.get("_circle")
	t.ok(circle != null, "무대의 _circle이 준비돼 있다 (전제)")
	if circle == null:
		stage.free()
		return

	circle.set_circle(CircleDefs.CIRCLE_TRIANGLE)
	t.ok(circle.set_rune(1, Tuning.ELEM_WATER), "1번 소켓에 물을 놓는다 (전제)")
	t.ok(circle.place_glyph(2, Glyph.GLYPH_BLAST), "2번 소켓에 폭발을 놓는다 (전제)")

	var keys: Array = Stage.LOADOUTS.keys()
	t.ok(keys.size() > 0, "프리셋 키가 있다 (전제)")
	if keys.size() > 0:
		stage.call("_set_loadout", keys[0])
	t.eq(circle.circle_id(), CircleDefs.CIRCLE_TRIANGLE,
		"프리셋 키를 눌러도 장착된 삼각 진이 그대로다 (조용히 동그라미로 안 돌아간다)")
	t.eq(circle.rune_count(), 3, "룬 자리도 셋 그대로다 (진이 안 바뀌었다는 증거)")

	# **A user who removed the circle is still unstuck** — the one case `DEFAULT_CIRCLE` still has to cover.
	circle.set_circle(CircleDefs.CIRCLE_NONE)
	if keys.size() > 0:
		stage.call("_set_loadout", keys[0])
	t.eq(circle.circle_id(), SpellCircle.DEFAULT_CIRCLE,
		"진을 뺀 상태에서는 프리셋 키가 여전히 기본 지급 진을 되돌려준다")

	stage.free()


## **`_revoke_unowned_rune()` used to read/write only `rune_at(0)`** (verify-read) — reachable the moment a
## second circle exists: earn a rune, place it in socket 1 or 2 of a triangle circle, press R. `shots()`
## fires whatever sits there regardless of ownership, silently. **Socket 0 stays owned (none) on purpose** —
## this measures whether the *other* sockets get checked, not whether socket 0 survives (that half was
## already proven, `net_render._revoke_unowned_rune_only_touches_what_is_not_owned`).
func _revoke_unowned_rune_touches_every_socket(t) -> void:
	var stage := Stage.new()
	var circle: Variant = stage.get("_circle")
	var world: Variant = stage.get("_world")
	t.ok(circle != null and world != null, "무대의 _circle·_world가 준비돼 있다 (전제)")
	if circle == null or world == null:
		stage.free()
		return

	circle.set_circle(CircleDefs.CIRCLE_TRIANGLE)
	var pr = world.progress()
	t.ok(not pr.owns_rune(Tuning.ELEM_FIRE), "불은 아직 소유하지 않았다 (전제)")
	t.ok(circle.set_rune(1, Tuning.ELEM_FIRE), "1번 소켓에 소유 안 한 불을 놓는다 (전제)")
	t.ok(circle.set_rune(2, Tuning.ELEM_FIRE), "2번 소켓에도 놓는다 (전제)")

	stage.call("_revoke_unowned_rune")

	# **Socket 0 was never set after `set_circle()`** (that call fills every socket with `RUNE_EMPTY`, not
	#  `DEFAULT_RUNE` — only the constructor does that) — `RUNE_EMPTY` is not `!= RUNE_EMPTY`, so the guard
	#  skips it, unlike `Tuning.ELEM_NONE` which the guard would actively revoke-to if it were unowned.
	t.eq(circle.rune_at(0), SpellCircle.RUNE_EMPTY, "0번 소켓은 그대로 빈 자리다 (건드릴 것도 없었다)")
	t.eq(circle.rune_at(1), Tuning.ELEM_NONE, "1번 소켓의 소유하지 않은 룬이 무속성으로 내려온다")
	t.eq(circle.rune_at(2), Tuning.ELEM_NONE, "2번 소켓도 마찬가지다")

	stage.free()


## **The preset's order contract — circle -> rune -> glyphs.**
##
## **With the circle unchanged, a reversed order is invisible** (`set_circle` is a no-op for the same circle, so it does not clear layers).
##  => It only shows **when measured with the circle removed.** It happened, measured — with the order reversed, running the net
##   left all twenty preset checks green (they were all calling only `set_from_packed`).
##
## And this is also where **"a user who removed the circle is not stuck"** is measured —
##  the preset places the circle too, so **key 1 is itself an assembly reset.**
func _preset_restores_everything(t) -> void:
	var c := SpellCircle.new()
	c.set_circle(CircleDefs.CIRCLE_NONE)
	t.eq(c.layer_count(), 0, "진을 빼면 층이 0이다")
	t.ok(not c.can_fire(), "진을 빼면 못 쏜다")

	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	t.ok(c.apply_preset(SpellCircle.DEFAULT_CIRCLE, SpellCircle.DEFAULT_RUNE,
		Glyph.pack(two)), "진이 없는 상태에서도 프리셋이 들어간다")
	t.eq(c.circle_id(), SpellCircle.DEFAULT_CIRCLE, "프리셋이 진을 되돌린다")
	t.eq(c.rune_at(0), SpellCircle.DEFAULT_RUNE, "프리셋이 룬을 되돌린다")
	# **Reverse the order and this comes out empty** — put the glyphs in first and the layer count is 0 so they do not fit,
	#  and even when the circle is placed afterward the glyphs have already been thrown away.
	t.eq(c.glyph_list(), two, "프리셋이 문양까지 놓는다 (순서가 진 → 룬 → 문양이다)")
	t.ok(c.can_fire(), "프리셋 뒤에 쏠 수 있다 (키 1이 곧 조립 리셋이다)")

	# It also restores from a state where only the rune is missing.
	c.set_rune(0, SpellCircle.RUNE_EMPTY)
	t.ok(not c.can_fire(), "룬을 빼면 못 쏜다")
	c.apply_preset(SpellCircle.DEFAULT_CIRCLE, SpellCircle.DEFAULT_RUNE, Glyph.GLYPH_NONE)
	t.ok(c.can_fire(), "프리셋이 빈 룬을 되돌린다")
	t.eq(c.glyph_list(), [] as Array[int], "빈 프리셋은 문양을 비운다")


# ══════════════════════════════════════════════════════════════════
#  shots() — step 5. One entry per bolt, and the triangle's three are sequenced, not simultaneous
# ══════════════════════════════════════════════════════════════════

## **Round: unchanged.** `shots()` still returns exactly the `element()`/`packed_glyphs()` pair
##  `stage._fire_at` built by hand before this function existed — `PIC_TRIANGLE` never reaches the branch
##  that would change that.
## **Triangle: three entries, each carrying only its own socket's rune and glyph, delayed `i * seq_ticks`.**
##  The three sockets are given **different runes** on purpose — if they all carried fire, entry `i`'s
##  `element` matching `rune_at(i)` would also match every other socket's rune, and a bug that copied
##  `rune_at(0)` into every entry would pass this check by accident.
func _shots_geometry(t) -> void:
	var round_c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	round_c.place_glyph(0, Glyph.GLYPH_SPREAD)
	var round_shots := round_c.shots()
	t.eq(round_shots.size(), 1, "동그라미 진은 발사가 한 발이다")
	t.eq(int(round_shots[0]["element"]), round_c.element(), "동그라미 진 발사 원소가 element()와 같다")
	t.eq(int(round_shots[0]["glyphs"]), round_c.packed_glyphs(), "동그라미 진 발사 문양이 packed_glyphs()와 같다")
	t.eq(int(round_shots[0]["delay"]), 0, "동그라미 진은 지연이 0이다")

	var tri := SpellCircle.new(CircleDefs.CIRCLE_TRIANGLE)
	t.ok(tri.set_rune(0, Tuning.ELEM_FIRE), "0번 소켓에 불을 놓는다")
	t.ok(tri.set_rune(1, Tuning.ELEM_WATER), "1번 소켓에 물을 놓는다")
	# 2번 소켓은 무속성(생성 시 기본값)으로 남긴다 — 세 소켓의 룬이 서로 달라야
	#  "제 소켓 것만 진다"가 값으로 갈린다 (전부 같은 룬이면 뒤바뀌어도 초록일 수 있다).
	t.ok(tri.place_glyph(1, Glyph.GLYPH_BLAST), "1번 층(1번 소켓)에만 문양을 놓는다")

	# **`element()`'s own contract, pinned directly** — the bark it used to carry ("exactly one rune slot")
	#  is gone (step 5), but the *answer* is still meant to be socket 0 specifically (12 o'clock, the seat
	#  the picture itself marks "goes first") — not "whichever socket happens to be last", which a
	#  `_runes[0]` -> `_runes[size() - 1]` typo would still satisfy for a round circle (one slot, same
	#  either way) and only a multi-socket circle with **distinct** runes per socket can catch.
	t.eq(tri.element(), tri.rune_at(0), "element()가 정확히 0번 소켓의 룬을 답한다 (다른 소켓이 아니다)")

	var shots := tri.shots()
	t.eq(shots.size(), 3, "삼각 진은 발사가 세 발이다")
	var seq := CircleDefs.seq_ticks(CircleDefs.CIRCLE_TRIANGLE)
	t.ok(seq > 0, "삼각 진의 seq_ticks가 0보다 크다 (전제 — 아니면 지연 간격을 못 잰다)")
	for i in shots.size():
		t.eq(int(shots[i]["delay"]), i * seq, "%d번 발사의 지연이 %d다" % [i, i * seq])
		t.eq(int(shots[i]["element"]), tri.rune_at(i), "%d번 발사가 제 소켓의 룬만 진다" % i)

	# **Only its own socket's glyph — never the whole circle's list.** Socket 1 alone has a glyph;
	#  sockets 0 and 2 must come out empty, and socket 1 must carry exactly that one glyph.
	t.eq(int(shots[0]["glyphs"]), Glyph.GLYPH_NONE, "0번 발사는 문양이 없다 (제 소켓이 비어 있다)")
	t.eq(int(shots[1]["glyphs"]), Glyph.pack([Glyph.GLYPH_BLAST]), "1번 발사가 제 소켓의 문양만 진다")
	t.eq(int(shots[2]["glyphs"]), Glyph.GLYPH_NONE, "2번 발사는 문양이 없다 (제 소켓이 비어 있다)")


## **The final count alone cannot tell a sequence from a burst** (CLAUDE.md, ordering contracts) — a bug
##  that fires all three shots on the same tick and a correct one that spaces them `seq_ticks` apart both
##  end at `fire_count() == 3`. So `fire_count()` is read **once per real tick**, not only at the end, and the
##  whole step function (0 -> 1 -> 2 -> 3, each step landing on its own tick) is compared against what
##  `enqueue()`'s `delay` promises.
##
## Drives the real door (`WorldStep.enqueue` + `frame()`), the same one `stage._fire_at` uses — not
## `SpellSim.fire()` directly — so this also exercises `_drain_queue`'s `keep` branch actually holding a
## delayed command across ticks instead of draining it early.
func _shots_fire_across_the_right_ticks(t) -> void:
	var tri := SpellCircle.new(CircleDefs.CIRCLE_TRIANGLE)
	# **Every socket armed by hand** — the constructor no longer auto-fills runes (Stage 3's empty boot),
	#  so a freshly-built triangle circle has three genuinely empty rune slots until this.
	for slot in tri.rune_count():
		t.ok(tri.set_rune(slot, Tuning.ELEM_NONE), "%d번 소켓에 룬을 놓는다 (전제)" % slot)
	t.ok(tri.can_fire(), "갓 만든 삼각 진이 바로 쏠 수 있다 (전제)")
	var shots := tri.shots()
	var seq := CircleDefs.seq_ticks(CircleDefs.CIRCLE_TRIANGLE)
	t.eq(shots.size(), 3, "삼각 진 발사가 세 발이다 (전제)")

	var ch := Character.new()
	ch.place(100, 100)
	var w := WorldStep.new(_wall_grid(), SpellSim.new(), ch)
	for shot: Dictionary in shots:
		w.enqueue(SpellSim.cmd_fire(10, 70, 100, 0, int(shot["element"]), int(shot["glyphs"])),
			int(shot["delay"]))

	# One entry per **real tick** (not per 60Hz frame) — `fire_count()` after tick k, for k = 1..span.
	var span := 1 + 2 * seq + 2
	var per_tick: Array[int] = []
	for _tick_i in span:
		for _frame_i in Tuning.TICK_DIVIDER:
			w.frame(1.0 / 60.0, 0.0, false, false)
		per_tick.append(w.fire_count())

	# Delay 0 fires on the first real tick (index 0 here, tick 1) — `enqueue`'s own contract
	#  (`tick = grid.get_tick() + 1 + delay`, and the grid's tick is 0 before the first tick ever runs).
	t.eq(per_tick[0], 1, "1번째 실제 틱에서 0번 발사가 나간다 (%s)" % [per_tick])
	# Nothing more fires until socket 1's delay elapses — this is the line a burst-shaped bug cannot pass:
	#  a bug that drains every shot on the first tick leaves `per_tick[seq - 1] == 3`, not 1.
	if seq > 1:
		t.eq(per_tick[seq - 1], 1, "%d번째 실제 틱까지 발사 수가 그대로 1이다 (%s)" % [seq, per_tick])
	t.eq(per_tick[seq], 2, "%d번째 실제 틱(1+%d)에서 1번 발사가 나간다 (%s)" % [seq + 1, seq, per_tick])
	if seq > 1:
		t.eq(per_tick[2 * seq - 1], 2, "%d번째 실제 틱까지 발사 수가 그대로 2다 (%s)" % [2 * seq, per_tick])
	t.eq(per_tick[2 * seq], 3, "%d번째 실제 틱(1+%d)에서 2번 발사가 나간다 (%s)" % [2 * seq + 1, 2 * seq, per_tick])
	# And nothing more comes after — three shots, not a fourth.
	t.eq(per_tick[per_tick.size() - 1], 3, "그 뒤로는 더 안 나간다 (%s)" % [per_tick])


## **The shell itself, not just `WorldStep` — the check above builds `SpellSim.cmd_fire` by hand and calls
## `WorldStep.enqueue` directly, so it never passes through `Aim.fire_cmd` or `stage._fire_at`'s own loop**
## (verify-read: reducing `_fire_at` to `_circle.shots()[0]` alone with `delay 0` — the exact "screen shows
## three sockets, one bolt leaves" signature fake this whole plan exists to close — left every net green,
## because nothing drove `_fire_at` itself). **The full stage scene is treed** (`t.root.add_child`) so every
## `@onready` field `_fire_at`'s own call chain touches (`_char_view.tip_px()`) resolves the normal way,
## rather than hand-wiring each one — `net_render._wired_stage_root` proves the alternative works too, but
## this file's own `_draw_actually_runs_headless` already established the simpler treed-and-pumped route.
func _fire_at_loops_every_shot_not_just_the_first(t) -> void:
	var scene: PackedScene = load("res://src/stage/stage.tscn")
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세울 수 있다 (전제)")
	if scene == null or not scene.can_instantiate():
		return
	var stage_root := scene.instantiate()
	t.root.add_child(stage_root)
	await t.pump_frames(2)

	var world: Variant = stage_root.get("_world")
	t.ok(world != null, "무대의 _world가 준비돼 있다 (전제)")
	if world == null:
		t.root.remove_child(stage_root)
		stage_root.free()
		return

	var tri := SpellCircle.new(CircleDefs.CIRCLE_TRIANGLE)
	# **Every socket armed by hand** — the constructor no longer auto-fills runes (Stage 3's empty boot).
	for slot in tri.rune_count():
		tri.set_rune(slot, Tuning.ELEM_NONE)
	t.ok(tri.can_fire(), "새로 만든 삼각 진이 바로 쏠 수 있다 (전제 — 손으로 룬을 채웠다)")
	stage_root.set("_circle", tri)

	var before: int = world.fire_count()
	stage_root.call("_fire_at", Vector2(600.0, 500.0))
	# `_fire_at` only enqueues — draining happens inside `frame()`'s tick branch.
	var seq := CircleDefs.seq_ticks(CircleDefs.CIRCLE_TRIANGLE)
	for _i in Tuning.TICK_DIVIDER * (2 * seq + 2):
		world.frame(1.0 / 60.0, 0.0, false, false)
	t.eq(int(world.fire_count()) - before, 3,
		"stage._fire_at() 한 번이 삼각 진의 발사 세 발을 전부 큐에 넣는다 (shots()[0] 하나만이 아니다)")

	t.root.remove_child(stage_root)
	stage_root.free()


## **Stage 3's own risk — a left click on a genuinely empty, fresh circle must not crash and must not
## enqueue anything.** `stage._fire_at`'s own guard (`if not _circle.can_fire(): return`) is read by
## every other check in this file only through `can_fire()`'s own boolean; this drives the real path
## (`_fire_at` on a treed `Stage`, never touched) to confirm the guard is what actually runs before
## `shots()` is ever reached — the plan's own words: "confirm that last link by driving a left click on
## an empty circle, do not assume it."
func _fire_at_on_a_fresh_empty_circle_does_nothing(t) -> void:
	var scene: PackedScene = load("res://src/stage/stage.tscn")
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세울 수 있다 (전제)")
	if scene == null or not scene.can_instantiate():
		return
	var stage_root := scene.instantiate()
	t.root.add_child(stage_root)
	await t.pump_frames(2)

	var world: Variant = stage_root.get("_world")
	var circle: Variant = stage_root.get("_circle")
	t.ok(world != null and circle != null, "무대의 _world·_circle이 준비돼 있다 (전제)")
	if world == null or circle == null:
		t.root.remove_child(stage_root)
		stage_root.free()
		return

	t.eq(circle.circle_id(), CircleDefs.CIRCLE_NONE, "새 무대의 진은 손대지 않은 CIRCLE_NONE이다 (전제)")
	t.ok(not circle.can_fire(), "그래서 쏠 수 없다 (전제)")

	var before: int = world.fire_count()
	stage_root.call("_fire_at", Vector2(600.0, 500.0))
	for _i in Tuning.TICK_DIVIDER * 2:
		world.frame(1.0 / 60.0, 0.0, false, false)
	t.eq(int(world.fire_count()), before, "빈 진에 좌클릭해도 발사가 하나도 안 나간다 (죽지도 않는다)")

	t.root.remove_child(stage_root)
	stage_root.free()


# ══════════════════════════════════════════════════════════════════
#  Socket glyph art — step 6. Only "does it load and is it the right size" — nothing about legibility,
#  that is verify-look's alone (`triangle-circle-to-game.md` step 6's own "Nets" line).
# ══════════════════════════════════════════════════════════════════

func _socket_glyph_textures_load_and_are_288(t) -> void:
	t.ok(Fx.SOCKET_GLYPH_TEX.size() > 0, "소켓 문양 그림 표에 항목이 %d개다" % Fx.SOCKET_GLYPH_TEX.size())
	# **Distinct paths, not distinct entries** — six glyph ids map onto only two files (rarity shares art
	#  with its family, `fx_tuning.SOCKET_GLYPH_TEX`'s own comment), so this loads each file once.
	var paths := {}
	for glyph_id: int in Fx.SOCKET_GLYPH_TEX:
		paths[Fx.SOCKET_GLYPH_TEX[glyph_id]] = true
	t.ok(paths.size() > 0, "실제 그림 파일이 %d개다" % paths.size())
	for path: String in paths:
		var tex: Texture2D = load(path)
		t.ok(tex != null, "%s 가 로드된다" % path)
		if tex == null:
			continue
		# **288 = 2 * `Fx.TRI_SOCKET_R`** — the socket's own diameter on the 512 basis, driven from the
		#  constant rather than the literal repeated, so the two cannot quietly drift apart.
		var want := Fx.TRI_SOCKET_R * 2
		t.eq(tex.get_width(), want, "%s 의 너비가 소켓 지름(%d)과 같다 (%d)" % [path, want, tex.get_width()])
		t.eq(tex.get_height(), want, "%s 의 높이가 소켓 지름(%d)과 같다 (%d)" % [path, want, tex.get_height()])


## **Every id in the table actually maps to one of the loaded files above** — a typo'd path would still
##  "load" as `null` (caught above), but an id pointing at a path outside `Fx.SOCKET_GLYPH_TEX`'s own two
##  files would not be caught by that loop at all (it only walks the *values that exist*, not "does every
##  key resolve to a value in range"). This walks the table from the id side instead.
func _socket_glyph_ids_are_real_glyphs(t) -> void:
	for glyph_id: int in Fx.SOCKET_GLYPH_TEX:
		t.ok(Glyph.DEFS.has(glyph_id), "소켓 문양 표의 id %d가 실제 문양 표에 있다" % glyph_id)


## **`_socket_glyph_textures_load_and_are_288` only walks *distinct paths* — it cannot see a family pointing
## at the wrong file** (verify-read: `SPREAD_R` retargeted to `socket_glyph_blast.png` still passed every
## check above, because the set of distinct paths stayed `{spread, blast}` regardless of which id points at
## which). This walks the table from the **id** side instead, checking each family's three rarities agree
## with each other and differ from the other family — the exact thing the path-side loop cannot see.
func _socket_glyph_families_do_not_cross(t) -> void:
	var spread_paths := {}
	for id: int in [Glyph.SPREAD_C, Glyph.SPREAD_R, Glyph.SPREAD_U]:
		t.ok(Fx.SOCKET_GLYPH_TEX.has(id), "확산 id %d가 소켓 문양 표에 있다 (전제)" % id)
		spread_paths[Fx.SOCKET_GLYPH_TEX.get(id, "")] = true
	t.eq(spread_paths.size(), 1, "확산 세 희귀도가 같은 그림 하나를 가리킨다 (%s)" % [spread_paths.keys()])

	var blast_paths := {}
	for id: int in [Glyph.BLAST_C, Glyph.BLAST_R, Glyph.BLAST_U]:
		t.ok(Fx.SOCKET_GLYPH_TEX.has(id), "폭발 id %d가 소켓 문양 표에 있다 (전제)" % id)
		blast_paths[Fx.SOCKET_GLYPH_TEX.get(id, "")] = true
	t.eq(blast_paths.size(), 1, "폭발 세 희귀도가 같은 그림 하나를 가리킨다 (%s)" % [blast_paths.keys()])

	if spread_paths.size() == 1 and blast_paths.size() == 1:
		t.ok(spread_paths.keys()[0] != blast_paths.keys()[0],
			"확산 그림과 폭발 그림이 서로 다른 파일이다 (%s ≠ %s)" % [spread_paths.keys()[0], blast_paths.keys()[0]])


# ══════════════════════════════════════════════════════════════════
#  Tools
# ══════════════════════════════════════════════════════════════════

## A stone wall one tile (4 cells) thick. Bolts land here.
func _wall_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(40, 0, 43, CellGrid.H - 1, Mat.STONE))
	return g


## Runs `ticks` ticks and returns the **total blast count** over that span.
## Notices are cleared every tick, so they have to be collected each tick.
func _run_ticks(sim: SpellSim, grid: CellGrid, ticks: int) -> int:
	var n := 0
	for _i in ticks:
		sim.step(grid)
		n += sim.blast_count()
	return n


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_circle: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()


## ══ The ring and rune pictures actually reach the screen ══
##
## **These eight files sat in `assets/circle/` with zero references anywhere in `src/` or `tests/`** — drawn
## procedurally instead, art on disk that nothing painted. That is this repo's named failure ("water material
## and colour were both in, but nothing called `set_water`"), and a call count on `_draw()` cannot see it.
##
## ⇒ `_paint_art(tex, rect, tint)` is the one seat both go through, and this subclass records **which texture
## went to which rect**. *Inversion: delete either `_paint_art` call from `circle_window.gd` and the
## matching assert below goes red.*
class _CapturingCircleWindow extends CircleWindow:
	var art: Array[Dictionary] = []
	## Rarity rings, recorded separately. **The palette card's tier is the one thing its picture does not
	## carry** (`Fx.ICON_TEX`), so once the icon path took over the drawing, "the tier is still on screen"
	## stopped being anything `art` could see.
	var rarity: Array[Dictionary] = []

	func _paint_art(tex: Texture2D, r: Rect2, tint: Color) -> void:
		art.append({"path": tex.resource_path, "rect": r, "tint": tint})
		super(tex, r, tint)

	func _draw_glyph_rarity_ring(at: Vector2, r: float, glyph_id: int) -> void:
		rarity.append({"at": at, "r": r, "id": glyph_id})
		super(at, r, glyph_id)


## **Both circles are driven, and that is not thoroughness — it is the difference between measuring the bug
## and missing it.** The round circle's rune already fitted its hole by **0.2px** before any fix; the
## triangle's overran by **8px**, and the triangle is what verify-look photographed. A version of this check
## that drove only the default circle stayed **green with `RUNE_ART_FRAC` reverted to 1.0** — measured, not
## supposed. The triangle is the binding case for the same reason it is in `Fx.RUNE_ART_FRAC`'s own box: its
## ring is smaller and its rune seat is bigger.
func _the_ring_and_rune_art_actually_reaches_the_paint(t) -> void:
	for circle_id: int in CircleDefs.ALL:
		await _art_reaches_the_paint_for(t, circle_id)


func _art_reaches_the_paint_for(t, circle_id: int) -> void:
	var win := _CapturingCircleWindow.new()
	var circle := SpellCircle.new()
	circle.set_circle(circle_id)
	circle.set_rune(0, Tuning.ELEM_FIRE)
	circle.place_glyph(0, Glyph.SPREAD_C)
	win.setup(Progress.new(), circle)
	t.root.add_child(win)
	win.visible = true
	win.queue_redraw()
	await t.pump_frames(3)

	t.ok(win.art.size() >= 2,
		"고리와 룬 그림이 실제로 그려진다 (_draw()가 돌았다가 아니라 — %d장)" % win.art.size())

	var paths: Array[String] = []
	for a: Dictionary in win.art:
		paths.append(String(a["path"]))
	t.ok(paths.has(Fx.RING_TEX[Glyph.SPREAD_C]),
		"확산이 얹힌 층의 고리에 확산 고리 그림이 간다 (%s)" % Fx.RING_TEX[Glyph.SPREAD_C])
	t.ok(paths.has(Fx.RUNE_TEX[Tuning.ELEM_FIRE]),
		"불 룬 자리에 불 룬 그림이 간다 (%s)" % Fx.RUNE_TEX[Tuning.ELEM_FIRE])

	# **A rect with size, at a real place.** A texture handed a zero rect is drawn nowhere, and the path
	#  check above would still pass — the same hole found in `settlement_window`'s notice tonight.
	for a: Dictionary in win.art:
		var r: Rect2 = a["rect"]
		t.ok(r.size.x > 0.0 and r.size.y > 0.0,
			"%s 를 크기 있는 자리에 그린다 (%s)" % [String(a["path"]).get_file(), r.size])

	# ══ The colour that actually lands, not the constant that was passed ══
	#
	# **Asserting `tint == CIRCLE_ART_TINT` proves nothing** — it stayed green through the version where the
	#  modulate was **under** 1.0 and quietly made near-black art darker still. What matters is the product:
	#  the art's own stroke colour times the modulate, against the panel it sits on.
	#  **Measured**: strokes are RGB(26,24,22), `WINDOW_BG` is (13,14,22). verify-look's report was that the
	#  picture was the least visible thing in the window.
	var stroke := Color8(26, 24, 22)
	for a: Dictionary in win.art:
		var tint: Color = a["tint"]
		var lit := Color(stroke.r * tint.r, stroke.g * tint.g, stroke.b * tint.b)
		var nm := String(a["path"]).get_file()
		t.ok(lit.r > Fx.WINDOW_BG.r + 0.25 and lit.g > Fx.WINDOW_BG.g + 0.25,
			"%s 의 획이 패널보다 확실히 밝게 찍힌다 (획 %.2f vs 패널 %.2f)" % [nm, lit.r, Fx.WINDOW_BG.r])
		t.ok(lit.r > stroke.r, "%s 를 어둡게 만들지 않는다 (곱셈이 1 아래면 여기가 빨개진다)" % nm)

	# ══ The donut: the rune sits INSIDE the ring's hole, not under its teeth ══
	#
	# **The relationship, not the two rects.** Each rect on its own was already "right" while the pictures
	#  overlapped — the user's complaint ("도넛 모양으로 들어가는 것") and verify-look's ("the bead's lower
	#  edge is eaten by the toothed pattern") are both about how the two sit *together*.
	# **Pairs are matched by centre**, because that is what makes them a donut: `circle_layout` already puts
	#  every band's centre on its own rune slot, which is why this was a size fix and not a layout one.
	var pairs := 0
	for ring: Dictionary in win.art:
		if not String(ring["path"]).get_file().begins_with("ring_"):
			continue
		var rr: Rect2 = ring["rect"]
		for rune: Dictionary in win.art:
			if not String(rune["path"]).get_file().begins_with("rune_"):
				continue
			var ur: Rect2 = rune["rect"]
			if not rr.get_center().is_equal_approx(ur.get_center()):
				continue
			pairs += 1
			var hole := rr.size.x * 0.5 * Fx.RING_HOLE_FRAC
			var ink := ur.size.x * 0.5 * Fx.RUNE_INK_FRAC
			t.ok(ink < hole,
				"룬 그림(%.1f)이 고리 구멍(%.1f) 안에 들어간다 — 톱니 밑에 깔리지 않는다" % [ink, hole])
	t.ok(pairs > 0, "같은 중심에 놓인 고리·룬 쌍이 실제로 있다 (0이면 위 규칙이 아무것도 안 잰다)")

	t.root.remove_child(win)
	win.queue_free()


## ══ The palette cards are pictures too — not the procedural symbol beside a real ring ══
##
## **The half fix this closes was visible and nobody's net saw it.** The circle side painted `ring_*.png` and
## `rune_*.png` while the palette one page over kept drawing `draw_circle`/`draw_line` shapes, so the same
## item was **two different pictures depending on where you looked** — worse than neither, and every check in
## this file stayed green because they all drove the circle page.
##
## **The window is left empty on purpose** on the circle page. With no rune seated and no glyph placed,
## the circle page paints nothing at all, so **every recorded texture came from the palette** — no
## filtering by rectangle, and no way for a circle-side picture to stand in for a card that never drew.
## *Inversion: point `_draw_palette_item`'s glyph branch back at `_draw_glyph` and the icon assert goes red;
## point it at `Fx.RING_TEX` instead of `ICON_TEX` and the "never a ring" assert goes red.*
##
## **Rewritten for ownership** (`onboarding-and-palette-tabs.md` §2) — the palette only shows what is owned
## (룬) or seated (문양), so "every card in one pass" no longer holds for either axis the way it did when
## `items_of()` returned every table row unconditionally:
##  · **runes** are independent of any circle, so granting every element at once and opening the 룬 tab
##    still shows all of them together in one window
##  · **glyphs are capped by layer count** (`Tuning.GLYPH_MAX_LAYERS`) and are **the seated glyphs, not a
##    stash** (`docs/decisions/the-glyph-tab-shows-the-circle.md`) — nine ids can never be seated at once,
##    so each is checked in its own circle, seated alone
func _the_palette_cards_are_drawn_from_the_art(t) -> void:
	# ── runes: every element granted at once, one window, the 룬 tab open ──
	var pr := Progress.new()
	for elem: int in Tuning.ELEM_ALL:
		pr.grant_rune(elem)
	var circle := SpellCircle.new()
	circle.set_circle(CircleDefs.ALL[0])
	var win := _CapturingCircleWindow.new()
	win.setup(pr, circle)
	t.root.add_child(win)
	win.visible = true
	var pal := Book.palette_page(win.size)
	win.call("_click_palette", pal,
		Palette.tabs(pal.size)[Palette.KINDS.find(Palette.KIND_RUNE)].get_center())
	win.queue_redraw()
	await t.pump_frames(3)

	var files: Array[String] = []
	for a: Dictionary in win.art:
		files.append(String(a["path"]).get_file())

	# Every glyph, not only the ones that happen to have their own file — nine of today's twelve ids share
	#  three pictures, and a card left on the procedural symbol despite having art is exactly what this is
	#  here to catch. **Condense is the one family with no row yet** (`glyph-condense.md` — "no art is added,
	#  code lands first") and must fall through to the procedural symbol instead; that path is the rarity-ring
	#  check below, which fires for every id regardless of art.
	#
	# **The skip is pinned to `FAMILY_CONDENSE`, not to "does `ICON_TEX` happen to have it"** — real
	#  regression, found by verify-run: an `ICON_TEX.has()` guard here means deleting a family's own row (say
	#  spread's) makes this loop quietly skip it too instead of catching the missing file, and the pass count
	#  drops (8,107 -> 8,076) with nothing going red. Every id **outside** the condense family must still be
	#  asserted to have a row at all.
	for glyph_id: int in Glyph.ALL:
		if Glyph.family_of(glyph_id) == Glyph.FAMILY_CONDENSE:
			continue
		t.ok(Fx.ICON_TEX.has(glyph_id), "문양 %d에 ICON_TEX 줄이 있다 (응축이 아니다 — 있어야 한다)" % glyph_id)
		if not Fx.ICON_TEX.has(glyph_id):
			continue
		var want: String = String(Fx.ICON_TEX[glyph_id]).get_file()
		t.ok(files.has(want), "문양 %d 칸에 %s 가 간다" % [glyph_id, want])
	for elem: int in Tuning.ELEM_ALL:
		var want_rune: String = String(Fx.RUNE_TEX[elem]).get_file()
		t.ok(files.has(want_rune), "룬 %d 칸에 %s 가 간다" % [elem, want_rune])

	# **A ring on a card is the failure mode, not a missing file.** `RING_TEX` and `ICON_TEX` hold the same
	#  nine ids, so pointing the card at the wrong one loads fine, draws fine, and reads as mush.
	for f: String in files:
		t.ok(not f.begins_with("ring_"), "카드에 층 띠 고리가 오지 않는다 (%s)" % f)

	# **The tier survived the swap.** The picture deliberately does not carry rarity, so if the icon path had
	#  simply replaced `_draw_glyph`, every card would look identical across three tiers with nothing barking.
	var ring_ids: Array[int] = []
	for rr: Dictionary in win.rarity:
		ring_ids.append(int(rr["id"]))
	for glyph_id: int in Glyph.ALL:
		t.ok(ring_ids.has(glyph_id), "문양 %d 카드에 등급 고리가 그려진다" % glyph_id)

	# **The picture stays inside its own tier ring.** Both come off the same `r`, so this is the one
	#  relationship that breaks the moment `PALETTE_ICON_FRAC` is raised past `RARITY_RING_RATIO`.
	#
	# **Counted by seat, not by record.** `pump_frames` redraws, so every card appears once per painted
	#  frame — asserting on the record count measures how many frames ran, which is the engine and not the
	#  drawing (it read 144 for nine cards, and it would have read nine had one frame happened to run).
	#
	# **A seat is required to hold art unless its whole family has no `ICON_TEX` row** — condense, and only
	#  condense (`glyph-condense.md` — "no art is added"); it falls through to the procedural symbol, which
	#  draws no `_paint_art` call at all, and the rarity ring above already proves that seat was reached.
	# **Pinned to `FAMILY_CONDENSE`, not to `ICON_TEX.has()`** — the same reason as the loop above: an
	#  `ICON_TEX`-shaped guard would quietly stop demanding art from any family whose row went missing,
	#  instead of catching it.
	var seats: Array[Vector2] = []
	for rr: Dictionary in win.rarity:
		var at: Vector2 = rr["at"]
		var id: int = int(rr["id"])
		var seen := false
		for s: Vector2 in seats:
			if s.is_equal_approx(at):
				seen = true
				break
		if seen:
			continue
		seats.append(at)
		if Glyph.family_of(id) == Glyph.FAMILY_CONDENSE:
			continue
		t.ok(Fx.ICON_TEX.has(id), "문양 %d에 ICON_TEX 줄이 있다 (등급 고리 자리, 응축이 아니다)" % id)
		if not Fx.ICON_TEX.has(id):
			continue
		var found := false
		for a: Dictionary in win.art:
			var r: Rect2 = a["rect"]
			if not r.get_center().is_equal_approx(at):
				continue
			found = true
			t.ok(r.size.x * 0.5 < float(rr["r"]) * Fx.RARITY_RING_RATIO,
				"아이콘(%.1f)이 등급 고리(%.1f) 안에 들어간다"
					% [r.size.x * 0.5, float(rr["r"]) * Fx.RARITY_RING_RATIO])
		t.ok(found, "등급 고리 자리 %s 에 아이콘 그림이 실제로 온다" % at)
	t.ok(seats.size() == Glyph.ALL.size(),
		"등급 고리가 서로 다른 %d자리에 있다 (%d — 겹치면 카드 하나가 안 그려진 것)" % [Glyph.ALL.size(), seats.size()])

	t.root.remove_child(win)
	win.queue_free()

	# ── glyphs: three at a time, one per family — `max_per_circle` caps same-family duplicates in one
	#     circle, so all nine ids can never be seated together. Batched by tier (C/R/U) on a triangle circle
	#     (3 layers) instead: one window per batch, three cells checked at once.
	#
	# **A triangle circle's own board also paints a ring texture for a seated glyph** (`_draw_ring` paints
	#  `RING_TEX` unconditionally, before the socket-texture branch) — so `gwin.art` mixes real circle-board
	#  ring pictures with real palette card pictures. Filtering by **the palette's own known cell centres**
	#  (computed from `palette_layout` directly, not from what was actually drawn) is what tells the two
	#  apart, rather than scanning every recorded texture regardless of where on screen it landed.
	var batches: Array[Array] = [
		[Glyph.SPREAD_C, Glyph.BLAST_C, Glyph.DUMMY_C],
		[Glyph.SPREAD_R, Glyph.BLAST_R, Glyph.DUMMY_R],
		[Glyph.SPREAD_U, Glyph.BLAST_U, Glyph.DUMMY_U],
	]
	var checked := 0
	for batch: Array in batches:
		var gc := SpellCircle.new(CircleDefs.CIRCLE_TRIANGLE)
		for i in batch.size():
			t.ok(gc.place_glyph(i, batch[i]), "문양 %d을 %d층에 놓는다 (전제)" % [int(batch[i]), i])
		var gwin := _CapturingCircleWindow.new()
		gwin.setup(Progress.new(), gc)
		t.root.add_child(gwin)
		gwin.visible = true
		var gpal := Book.palette_page(gwin.size)
		gwin.call("_click_palette", gpal,
			Palette.tabs(gpal.size)[Palette.KINDS.find(Palette.KIND_GLYPH)].get_center())
		gwin.queue_redraw()
		await t.pump_frames(3)

		# **The palette's own cell centres, from the layout alone.** `items_of(KIND_GLYPH)` returns
		#  `circle.glyph_list()` in layer order, the same order `batch` was placed in, so cell `i` is
		#  `batch[i]`'s own seat.
		var gsec := Palette.section(gpal.size)
		var cell_centers: Array[Vector2] = []
		for i in batch.size():
			cell_centers.append(Palette.item_slot(gsec, i, batch.size()).get_center())

		for i in batch.size():
			var glyph_id: int = batch[i]
			var want: String = String(Fx.ICON_TEX[glyph_id]).get_file()
			checked += 1

			# **The tier survived the swap.** The picture deliberately does not carry rarity, so if the
			#  icon path had simply replaced `_draw_glyph`, every card in a batch would look identical.
			var found_ring := false
			var ring_r := 0.0
			for rr: Dictionary in gwin.rarity:
				if (rr["at"] as Vector2).is_equal_approx(cell_centers[i]) and int(rr["id"]) == glyph_id:
					found_ring = true
					ring_r = float(rr["r"])
			t.ok(found_ring, "문양 %d 카드에 등급 고리가 그려진다" % glyph_id)

			# **The picture is at this cell's own centre, is the right file, and is not a ring** — all
			#  three read off the one entry whose rect sits at this cell, so a card that painted the wrong
			#  file (or the ring texture) at the right spot cannot slip through by matching only the file.
			var found_card := false
			for a: Dictionary in gwin.art:
				var r: Rect2 = a["rect"]
				if not r.get_center().is_equal_approx(cell_centers[i]):
					continue
				var fname := String(a["path"]).get_file()
				if fname.begins_with("ring_"):
					continue  # the circle board's own ring, not this palette cell — keep looking
				found_card = true
				t.eq(fname, want, "문양 %d 칸에 %s 가 간다 (%s)" % [glyph_id, want, fname])
				t.ok(r.size.x * 0.5 < ring_r * Fx.RARITY_RING_RATIO,
					"아이콘(%.1f)이 등급 고리(%.1f) 안에 들어간다"
						% [r.size.x * 0.5, ring_r * Fx.RARITY_RING_RATIO])
				break
			t.ok(found_card, "%d번 칸에 카드 그림이 실제로 온다 (문양 %d)" % [i, glyph_id])

		t.root.remove_child(gwin)
		gwin.queue_free()

	t.eq(checked, Glyph.ALL.size(), "아홉 문양 전부를 (묶음 셋으로) 검사했다 (%d개)" % checked)
