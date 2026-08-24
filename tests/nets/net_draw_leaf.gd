extends RefCounted
## The drawing scan. It reads the text of `src/view/`, `src/shell/` and `src/`, and it measures
## nothing at runtime — which is the point: a spy on a hook sees the HOOK, never the native call
## inside it, so the last inch has to be pinned structurally. See lessons-from-two-dead-games.
##
## Four things are pinned here, and each one exists because its absence shipped a bug under a green
## round in this repo before:
##
##  1. **Per-function `draw_*` counts.** A file-wide bound is not enough for a view file — a bare
##     `draw_circle` at the top of `_draw` reached the screen every frame with 1414 checks green.
##  2. **The class is CLOSED, not enumerated.** Every `func` line in the three view files is walked and
##     a name the table does not hold is red. Adding names to a table fixes the day it is done and
##     nothing after it: naming eight more composers still left eleven of twenty-eight functions
##     outside, and the same circle was green again at 1889. A function written tomorrow is red until
##     it is listed, on purpose.
##  3. **Every parameter a leaf is handed is used in its body.** `draw_circle(p, 0.0, col)` inside a
##     leaf turned forty rocks invisible with the round green — argument capture proves a value was
##     computed and handed on, never that it was used.
##  4. **No presentation constant is loose.** No `Color(` and no named colour outside `look.gd`, and no
##     literal assigned to a name ending in a presentation-ish suffix. The colour half of this rule
##     shipped once with the pixel half never written, so its green never meant what it said — and the
##     TIME half was the same hole one layer on: **half of an effect's constants are durations**, and
##     until the suffix list below grew, `const HIT_FLASH_SEC := 0.14` could sit in a view file with
##     the round green about "no presentation constant is loose". `combat-juice` widened the list.
##
## ## The suffix list lives HERE and nowhere else, and it is read at TWO different scopes
##
## `look.gd`'s own header used to repeat the list; it now points at `_literal_hits` instead, because
## a list written twice starts lying the day one copy grows. The two scopes are not tidiness:
##
##  - `_pixel_hits` — the SIZE-ish suffixes, swept over the whole of `src/` minus `look.gd`. A pixel
##    number is presentation wherever it is written.
##  - `_literal_hits` — that list plus the TIME-ish and shape-ish ones, swept over `src/view/` and
##    `src/shell/` only. Measured, and this is why it is narrowed: run the wide list over all of
##    `src/` and it bites `rules.gd`'s `TYPE_COUNT`, `_COL_SPEED` and `LION_WINDUP_SEC` — a table
##    column count, a table column index and a SIM rule. `src/shell/` is not optional in that pair:
##    `HOLD_OUTCOME_SEC`, `HOLD_BEAK_SEC` and `PANEL_FADE_SEC` are read by `game.gd`, so a scope of
##    `src/view/` alone leaves `var _hold_sec := 0.8` hardcoded in the shell and green.
##
## ⚠ **The scanner is inverted too, not only the tree.** The synthetic texts below fail THIS FILE
## rather than the game: an unlisted function holding a bare draw call, a leaf that drops one of its
## arguments, a leaf whose count is one too many, a colour moved out of `look.gd`, a literal moved out
## of it under every widened suffix, an ARRAY literal (`FX_GAIN`'s shape, the one hole the value side
## of the pattern had), and clean texts that must produce nothing. Twice in one night a check was
## written to catch a defect and shipped carrying that same defect, and neither was caught by
## inverting the code.

const VIEW_DIR := "res://src/view"
const SHELL_DIR := "res://src/shell"
const SRC_DIR := "res://src"
const LOOK_PATH := "res://src/look.gd"

## The size-ish half. Swept over every `.gd` under `src/` except `look.gd`.
##
## ⚠ `cols` was added by `plan-then-watch`: `IDLE_SOLDIER_COLS` — how many soldiers stand across at
## the harbour — matched none of the other suffixes, and a layout count that the scan cannot see is a
## layout number free to be written in `field_view.gd`. `alpha` already covered `GHOST_ALPHA`, which
## was CHECKED rather than assumed; the plan flagged both names as possibly invisible and only one of
## them was.
## ⚠ **`ratio` moved OUT of this list and into `TIME_SUFFIXES`** — the same narrowing the header
## describes for the whole wide list, arriving one suffix later: `rules.gd` grew
## `SUMMON_RADIUS_RATIO`, a SIM rule (it decides where a boat may be placed) that must not be
## dragged into `look.gd`, and a ratio in a VIEW is still caught because the wide list sweeps
## `src/view/` + `src/shell/`.
const PIXEL_SUFFIXES := "px|width|radius|size|margin|alpha|offset|gap|font_size|cols"

## What `combat-juice` added on top of it, for `src/view/` + `src/shell/` only.
##
## `deg` is here because `SPARK_SPREAD_DEG` matched none of the other twenty-two, and the name was
## widened rather than bent: an angle is a presentation constant that will come up again, and
## `deg_to_rad(...)` is a call rather than an assignment so it cannot be caught by accident.
## `tiles growth squash count` are here because without them eight of the forty-four constants
## `combat-juice` adds — `BURST_GROWTH`, `TARGET_LINE_MAX_COUNT`, `SHAKE_A_FREQ`, `SHAKE_B_FREQ`,
## `GAIT_PERIOD_TILES`, `GAIT_SQUASH`, `WATER_MARGIN_TILES`, `FX_MAX_COUNT` — matched nothing at all.
const TIME_SUFFIXES := "sec|dur|time|speed|freq|mul|strength|gain|tiles|growth|squash|count|deg|ratio"

## The per-file, per-function `draw_*` count. It is `combat-juice`'s hook table, holding EVERY
## function in each file — a composer at 0 is as load-bearing as a leaf at 2, because 0 is what
## forbids a drawing call from leaking out of a hook.
##
## A plain function and not a `const` Dictionary: a `const` packed array is a parse error on 4.7.1 and
## the const-expression rules around nested literals are exactly the kind of thing this repo has been
## bitten by twice. Nothing is gained by risking it here.
func _table() -> Dictionary:
	return {
		# ⚠⚠ **RE-DERIVED WHOLE for the 3D field** (ticket 09, step 2 — the old table was the flat
		# board's and not one line of it was kept). **Every count is 0, and that zero is the table's
		# whole claim now**: the field draws through the ENGINE (pooled `Sprite3D`s, one terrain mesh,
		# two `ImmediateMesh` fx layers) and a `draw_*` call appearing anywhere in this file would be
		# a 2D stroke painted OVER the 3D world — exactly the bare-call leak this scan exists to
		# redden. What the per-function counts used to certify (each mark reaches the screen) moved
		# to the runtime nets: `net_shell` / `net_slots` read the pooled node state and the fx
		# buffers, and `net_fx_view` (its own round) re-measures the twelve effects there.
		"field_view.gd": {
			"_ready": 0,
			"_build_world": 0,
			# The two baked textures. Their colours come from `look.gd` (`COL_BAKE_MARK` /
			# `COL_BAKE_CLEAR`) — the colour scan below is what pushed them there.
			"_make_body_tex": 0,
			"_make_flat_tex": 0,
			"setup": 0,
			"_process": 0,
			# The camera: pure functions, all of them, driven by `net_camera` with `.new()`.
			"_visible_ground_px": 0,
			"_ground_right": 0,
			"_ground_down": 0,
			"_ground_centre_px": 0,
			"screen_to_world_px": 0,
			"world_to_tile": 0,
			"pan_by": 0,
			"zoom_at": 0,
			"_clamp_cam": 0,
			"turn_by": 0,
			"tilt_by": 0,
			"_place_camera": 0,
			# The landscape: one mesh, built by SurfaceTool — no canvas stroke anywhere in it.
			"_kind_of": 0,
			"_joins": 0,
			"_char_at": 0,
			"_noise_at": 0,
			"_hash_at": 0,
			"_tile_key": 0,
			"_tile_h": 0,
			"_tile_h_uncached": 0,
			"_swell_at": 0,
			"_corner_h": 0,
			"_ground_h": 0,
			"_touches_water": 0,
			"_band_on": 0,
			"_tile_colour": 0,
			"_rebuild_terrain": 0,
			"_rebuild_ring": 0,
			"_quad": 0,
			"_skirt": 0,
			"_terrain_material": 0,
			# The bodies, as pooled billboards. `_put_*` writes node fields the engine consumes —
			# that is the 3D leaf, and `net_shell` reads those fields back per enemy.
			"_sprite": 0,
			"_hull_box": 0,
			"_put_body": 0,
			"_put_hp": 0,
			"_paint_bodies": 0,
			"_put_halo": 0,
			"_beast_tex": 0,
			"_put_soldier": 0,
			"_put_hull": 0,
			"_hide_unused": 0,
			# The effect SIMULATION — carried across the move unchanged, still 0 draws each.
			"set_summon_aim": 0,
			"note_refusal": 0,
			"_map_tiles": 0,
			# Fed to the ground fx buffer by `_paint_boat_routes` — the caller it lost in the 3D
			# move, re-wired in step 4.
			"_route_ahead": 0,
			"_tile_xy": 0,
			"_hull_rect": 0,
			"_beast_rect": 0,
			"_hp_rects": 0,
			"_facing_of": 0,
			"_fx_step": 0,
			"_drain_events": 0,
			"_shake_offset": 0,
			"_wait_blend": 0,
			"_body_offset_of": 0,
			"_lunge_offset": 0,
			"_knock_offset": 0,
			"_flash_of": 0,
			"_gait_squash": 0,
			"_spark_points": 0,
			# The effect GEOMETRY: two vertex buffers committed to `ImmediateMesh` surfaces.
			# `net_slots` reads the buffers AND the surface count — buffers alone stay green when
			# `_fx_flush` is deleted, which is why both are runtime rows and none is a count here.
			"_fx_layer": 0,
			"_fx_begin": 0,
			"_fx_flush": 0,
			"_fx_commit": 0,
			"_ground_y_px": 0,
			"_g_tri": 0,
			"_g_quad": 0,
			"_g_seg": 0,
			"_g_line": 0,
			"_g_ring": 0,
			"_g_disc": 0,
			"_air_at": 0,
			"_a_quad": 0,
			"_a_seg": 0,
			"_a_ring": 0,
			"_a_disc": 0,
			"_body_anchor": 0,
			"_halo_of": 0,
			"_a_seg3": 0,
			"_fx_point3": 0,
			"_paint_fx": 0,
			"_paint_plan": 0,
			# Step 4's revival: the caller `_route_ahead` had lost. 0 draws — it feeds the fx buffer.
			"_paint_boat_routes": 0,
			"_paint_ghosts": 0,
			"_paint_intent": 0,
			"_paint_transients": 0,
		},
		# ⚠ **Seven names left this file in one edit and one arrived** (`plan-then-watch`, 6.5).
		# `key_slot_count` · `key_type_of` · `reserve_count` — the 1/2 key roster, which spawned a body
		# straight onto a boat. ⚠ **`sea-summon` brings the keyboard back and does NOT bring those
		# three back**: 1~5 now ARM a slot and the press on the water is what places, so the five new
		# names below are a different widget rather than the old one restored.
		# `boat_label` · `note_launch` · `_berth_offset` · `_paint_berth` ·
		# `_paint_load` — the berths, which were the fleet drawn as a resource meter, and the boat
		# stopped being a resource. `set_speed` is the arrival. Three renames on top: `note_key` ->
		# `note_chip`, `_key_offset` -> `_chip_offset`, `_key_colour` -> `_chip_colour`, `_paint_key` ->
		# `_paint_button`. **20 -> 13 names, 5 -> 3 leaves**, and both halves of the rename have to
		# land: a name the table holds that the file no longer has is caught by `_scan`'s
		# `표에는 있는데 파일에 없는 함수` direction, whose synthetic case (c2) proves it bites.
		"hud_view.gd": {
			"default_font": 0,
			"type_label": 0,
			"bind": 0,
			"_process": 0,
			"_draw": 0,
			"note_chip": 0,
			"_fx_step": 0,
			"_chip_offset": 0,
			"_chip_colour": 0,
			# Item 8's tint, pulled out of `_chip_colour` so the five slot boxes get the flash the
			# start button has had since it shipped — one shake AND one tint, both shared, which is
			# the two channels `combat-juice` asked for. Pure.
			"_chip_tint": 0,
			# ⚠ `_paint_timer` is DELETED with the countdown it drew (2026-08-24) — nothing loses by
			# the clock any more, so a number ticking down would be the loudest lie on screen. The
			# hook went with its call site, not just the call: 18 -> 17 names, 6 -> 5 leaves.
			# 2 calls. ⚠ **The start button is its ONLY call site now** — the five speed chips were the
			# other five and they are deleted. It stays a hook rather than being inlined into `_draw`,
			# because a bare `draw_rect` in `_draw` is precisely what this whole table exists to redden.
			"_paint_button": 2,
			"_paint_enemies_left": 1,
			# `sea-summon`'s five summon slot boxes. `set_armed` and `_slot_colour` are pure; the three
			# leaves are the box (fill + border), the digit, and the roster bar (rail + fill).
			"set_armed": 0,
			"_slot_colour": 0,
			"_paint_slot_box": 2,
			"_paint_slot_digit": 1,
			"_paint_slot_bar": 2,
		},
		"panel_view.gd": {
			"bind": 0,
			"panel_active": 0,
			"is_reward": 0,
			"is_finished": 0,
			"roster_ids": 0,
			"roster_rect_of": 0,
			"soldier_id_at": 0,
			"button_rect": 0,
			"button_hit": 0,
			"note_beak": 0,
			"_fx_step": 0,
			"_entry_bg": 0,
			"_process": 0,
			"_draw": 0,
			"_paint_panel": 1,
			"_paint_message": 2,
			"_paint_roster_entry": 2,
			"_paint_button": 2,
			"_entry_text": 0,
			"_message_text": 0,
			"_message_colour": 0,
		},
		# `title-and-map`'s two new files. The title holds no `Run` at all — it IS `run == null` — so
		# every function here is either geometry read out of `look.gd` or a clock of its own.
		"title_view.gd": {
			"slot_rect_of": 0,
			"slot_hit_rect_of": 0,
			"slot_at": 0,
			"is_slot_pressable": 0,
			"note_press": 0,
			"set_hover": 0,
			"_hover_of": 0,
			"_press_of": 0,
			"_slot_fill": 0,
			"_slot_box": 0,
			"_cell_centre": 0,
			"_fx_step": 0,
			"_process": 0,
			"_draw": 0,
			"_paint_cell": 1,
			"_paint_title": 1,
			# 2 calls: the fill, then the border that says it presses. One hook and not two — a box
			# without its border is the same box saying something else, not a second thing to draw.
			"_paint_slot_box": 2,
			"_paint_slot_label": 1,
		},
		"map_view.gd": {
			"bind": 0,
			"node_at": 0,
			"node_centre_of": 0,
			"node_hit_radius_of": 0,
			"is_node_pressable": 0,
			"set_hover": 0,
			"note_press": 0,
			"note_cleared": 0,
			"_hover_of": 0,
			"_press_of": 0,
			"_reveal_alpha_of": 0,
			"_pulse_scale_of": 0,
			"_here_centre": 0,
			# The four-state read, added the round the map's states were made to carry at rest.
			# `_look_of` answers once and BOTH `_node_fill` and `_node_radius_of` read it, so the
			# colour channel and the size channel cannot disagree about which state a node is in.
			"_look_of": 0,
			"_node_radius_of": 0,
			"_node_fill": 0,
			"_edge_style": 0,
			# draw 0 and NOT leaves, the `_spark_points` precedent: the geometry is built here and
			# handed to `_paint_glyph` / `_paint_node_border` as an argument. Built inside the leaf it
			# never leaves it, and the unused-argument check below skips every function whose count is
			# 0 — so a leaf holding `draw_multiline(PackedVector2Array(), ...)` would read as one draw
			# call with every argument used, and draw nothing at all.
			# ⚠ `_ring_points` is NOT in `title-and-map`'s table and was added by the build: the
			# alternative was the same ring loop written inline three times in `_draw`.
			"_glyph_points": 0,
			"_ring_points": 0,
			"_fx_step": 0,
			"_process": 0,
			"_draw": 0,
			"_paint_edge": 1,
			# 2, and it is not a mistake: `draw_circle` in one branch and `draw_colored_polygon` in the
			# other, one of which runs per call. `_draw_calls` counts call SITES textually, so writing
			# 1 here reddens the round on day one.
			"_paint_node": 2,
			"_paint_node_border": 1,
			"_paint_glyph": 1,
			"_paint_here_ring": 1,
			"_paint_army": 1,
			# ⚠ Also not in the design's table. The scene wash needs a full-screen rect and no existing
			# leaf draws one; without it 시작하기 cuts to the map, which reads as a glitch.
			"_paint_fade": 1,
		},
		# `refit-board` stage 4's new screen, re-cut by 티켓 06/12: three cards after a won fight,
		# take one. It holds no `Run` state of its own beyond the hover/press pair every screen
		# carries -- `run.cards` (one item id per card) and `run.cards_taken` are read straight off
		# the sim.
		"reward_view.gd": {
			"bind": 0,
			"card_rect_of": 0,
			"card_hit_rect_of": 0,
			"card_at": 0,
			"is_card_pressable": 0,
			"set_hover": 0,
			"note_press": 0,
			"_hover_of": 0,
			"_press_of": 0,
			"_taken_of": 0,
			"_reveal_alpha_of": 0,
			"_card_box": 0,
			"_card_fill": 0,
			"_fx_step": 0,
			"_process": 0,
			"_picks_made": 0,
			"_draw": 0,
			# 티켓 12's five pure helpers: the item textures loaded once, the deal-in slide (riding
			# `_reveal_alpha_of`, applied to the drawn box only), the rarity pulse (a sine on
			# `_reveal_age` — no second clock), the art square, and the burst geometry handed WHOLE
			# to its leaf (`_spark_points`'s split; see `_whole_array_leaves` below, which pins it).
			"_load_item_art": 0,
			"_deal_offset_of": 0,
			"_pulse_of": 0,
			"_art_rect": 0,
			"_burst_points": 0,
			# fill + border, the same shape every other pressable box in this repo draws.
			"_paint_card": 2,
			# 티켓 12's three leaves. The art is 1 `draw_texture_rect`, SKIPPED at the call site when
			# the item's `ITEM_ART` row is empty — no picture rather than a wrong one. The frame is 1
			# stroked `draw_rect` in a layer loop (the glow is the frame layered outward), so one call
			# SITE serves every rarity and COMMON's 0-layer row means it is not called at all. The
			# burst is 1 `draw_multiline`, called iff LEGENDARY.
			"_paint_card_art": 1,
			"_paint_rarity_frame": 1,
			"_paint_legendary_burst": 1,
			"_paint_card_name": 1,
			"_paint_card_effect": 1,
			"_paint_taken_mark": 1,
			"_paint_hint": 1,
			# The scene wash, `map_view`'s own shape reused rather than a second fade invented for
			# this screen — see that file's own comment beside its `_paint_fade` entry.
			"_paint_fade": 1,
		},
		# `refit-board` stage 5's new screen: the slot strip, then a 3x2 board, a held pile, a
		# five-number dashboard and a body preview. `_rounded_square` is 0 draws and NOT a leaf --
		# the same `_spark_points` shape: the geometry is built here and handed to `_paint_body` as
		# an argument, and never leaves that one call site.
		"refit_view.gd": {
			"bind": 0,
			"open_slot": 0,
			"is_board_open": 0,
			"open_slot_index": 0,
			"slot_rect_of": 0,
			"slot_hit_rect_of": 0,
			"slot_at": 0,
			"cell_rect_of": 0,
			"cell_hit_rect_of": 0,
			"cell_at": 0,
			"held_rect_of": 0,
			"held_hit_rect_of": 0,
			"held_at": 0,
			"done_rect": 0,
			"done_hit_rect": 0,
			"is_done_pressable": 0,
			"back_rect": 0,
			"back_hit_rect": 0,
			"is_back_pressable": 0,
			"set_hover": 0,
			"note_slot_press": 0,
			"note_cell_press": 0,
			"note_held_press": 0,
			"note_done_press": 0,
			"note_fitted": 0,
			"_hover_of": 0,
			"_press_of": 0,
			"_stat_shown": 0,
			"_cell_fill": 0,
			"_fx_step": 0,
			"_process": 0,
			"_draw": 0,
			"_draw_board": 0,
			"_paint_slot_box": 2,
			"_paint_slot_label": 1,
			"_paint_cell_box": 2,
			# Renamed with the equipment re-cut: a cell shows an item's NAME and its EFFECT line now,
			# not a part and a species. Same two leaves, one call each; re-counted, not assumed.
			"_paint_cell_name": 1,
			"_paint_cell_effect": 1,
			"_paint_held_row": 2,
			"_paint_held_name": 1,
			"_paint_held_effect": 1,
			"_paint_stat_label": 1,
			"_paint_stat_value": 1,
			# 티켓 11's aggregate: one line per tag, drawn on both steps, and its pure reader of the
			# horde-wide count and the tier tables.
			"_paint_tag_row": 1,
			"_tag_state_of": 0,
			# `draw_polyline` + `draw_circle`, the outline-and-dot shape `field_view._paint_body`
			# already draws -- this screen's own scale, no part drawn on it.
			"_paint_body": 2,
			"_paint_button": 2,
			"_rounded_square": 0,
			# The scene wash — this screen had no reveal of its own to piggyback on until now, so
			# `_reveal_age` was added purely to drive this one call.
			"_paint_fade": 1,
			# Step one's hint — the only screen with a pressable strip and no line saying so.
			"_paint_hint": 1,
		},
	}


func run(t) -> void:
	var table := _table()

	# "It is not 0" first. A directory walk that found nothing would report a perfectly clean tree and
	# every assertion below would simply stop running.
	var view_files := _gd_files(VIEW_DIR)
	t.eq(view_files.size(), 7, "src/view/ 에 그릴 줄 아는 파일이 일곱이다 %s" % str(view_files))
	t.eq(table.size(), 7, "표도 파일 일곱을 덮는다")

	# -- 1~3. the per-function table, the closed class, and the leaf arguments ----------------------
	var total_funcs := 0
	var total_leaves := 0
	for path: String in view_files:
		var base := path.get_file()
		t.ok(table.has(base), "%s 가 표에 있다 — 표에 없는 뷰 파일은 스캔 밖이다" % base)
		if not table.has(base):
			continue
		var expect: Dictionary = table[base]
		var text := _read(path)
		t.ok(text.length() > 200, "%s 를 읽었다 (%d자)" % [base, text.length()])
		var bad := _scan(text, expect)
		t.eq(bad.size(), 0, "%s — 함수별 draw 수 · 표에 없는 함수 · 안 쓰인 인자, 전부 없다 %s" % [base, str(bad)])
		var found := _funcs(text)
		t.eq(found.size(), expect.size(), "%s 의 func 줄 수와 표의 항목 수가 같다" % base)
		total_funcs += found.size()
		for name: String in expect:
			if int(expect[name]) > 0:
				total_leaves += 1

	# The literals are read back, never `found.size()` summed — a walk that saw nothing would agree
	# with itself. `boat-and-landing`'s camera added 7 pure functions to field_view.gd (29 -> 36);
	# stage 4's drag added 3 more there and 2 in hud_view.gd (36 -> 39, 18 -> 20); stage 5's fleet
	# added `_paint_hull` / `_paint_cliff_face` / `_hull_rect` / `_deck_slots` / `_wait_blend` and
	# removed `_paint_boat` / `_boat_rect` in field_view.gd (39 -> 42, net +3); the verify-read pass
	# on stages 4/5 added `idle_hull_rect`, shared between `_draw()` and `game.gd`'s hit test so
	# neither one re-derives the anchor and the slot a second time (42 -> 43).
	# `plan-then-watch` moved BOTH totals, and that is deliberate: an earlier draft of that plan landed
	# them back on 84 and 23 while five per-file counts moved, and a literal that does not move is the
	# one nobody re-derives. 43 is field_view (one added, one deleted, one renamed — no net change, so
	# it is the one to count by hand), 13 is hud_view (20 - 8 + 1), 21 is panel_view, untouched.
	# `title-and-map` added two whole files, and its own table was re-derived by hand here rather than
	# copied: it named 18 functions for `title_view` (which held) and 25 for `map_view` (which did
	# not — `_ring_points` and `_paint_fade` were added by the build, with the reasons beside them).
	# The map's four-state read added `_look_of` and `_node_radius_of` to `map_view` (27 -> 29), and
	# the total is re-derived by hand here rather than nudged: a literal that moves by whatever the
	# last edit happened to be is a literal nobody re-derives.
	# The variable grid added `_map_tiles` and `_visible_tile_rect` to `field_view` (43 -> 45), and the
	# total is re-derived by hand here rather than nudged by two.
	# `sea-summon` added `set_summon_aim` to `field_view` (45 -> 46) and five names to `hud_view`
	# (12 -> 17: `set_armed`, `_slot_colour`, `_paint_slot_box`, `_paint_slot_digit`,
	# `_paint_slot_bar`), three of which are leaves (3 -> 6).
	# ⚠⚠ **BOTH totals were re-derived from the five per-file tables and NOT nudged, and doing it
	# caught the plan.** `sea-summon`'s own plan said hud_view held 13 names and that the total would
	# land on 132; the table has held **12** since the speed chips died, so the answer is **131**. A
	# literal that moves by whatever the last edit happened to be is a literal nobody re-derives — and
	# this table has already been nudged once in this repo.
	# ⚠⚠ **Round 4 of `sea-summon` DELETED the drag**, and `field_view` lost three names with it
	# (46 -> 43): `set_drag`, `_paint_dock` (the harbour marker) and `idle_soldier_rect`. One of the
	# three was a LEAF, so the leaf count moves too (34 -> 33) — the first time that number has ever
	# gone DOWN, and it is re-derived from the five per-file tables rather than decremented.
	# Round 2 of `sea-summon` added `_chip_tint` to `hud_view` (17 -> 18) — the tint half of item 8,
	# which had been written inline in `_chip_colour` and so reached the start button alone while
	# `_chip_offset` already served both. Pure, so the leaf count does not move.
	# `refit-board` stage 7's climb and flash added `_stat_shown`, `note_fitted` and `_cell_fill` to
	# `refit_view` (43 -> 46), all three pure, and the card reveal stagger added `_reveal_alpha_of` to
	# `reward_view` (21 -> 22), also pure. The total is re-derived by hand from the seven tables, not
	# nudged by four.
	# ⚠ **Neither new screen had a scene wash — the verify-run pass on this round measured two
	# captures 0.4s apart byte-identical on the refit screen.** Both got `map_view`'s own
	# `_paint_fade` shape: `reward_view` added the leaf alone (22 -> 23, 5 -> 6 leaves), riding its
	# existing `_reveal_age`; `refit_view` had no reveal clock of its own to piggyback on, so
	# `_reveal_age` (a var, not a function — does not move this table) and `_paint_fade` both landed
	# there (46 -> 47, 12 -> 13 leaves). The same pass found the refit screen's step one had a
	# pressable strip and no line of text saying so — `_paint_hint` added the same round (47 -> 48,
	# 13 -> 14 leaves), the reward screen's own `_paint_hint` shape.
	# ⚠ **44 -> 46**: the shadow added `_paint_shadow` (the leaf) and `_shadow_points` (the ellipse it
	# is handed), the same leaf-plus-pure-shape pair every other drawn thing in this file uses.
	# ⚠ **43 -> 44**: the wolf added exactly one name, `_beast_rect` — the pure rectangle the picture
	# goes in. **No new leaf**: the texture went into `_paint_body`'s own arguments so that every net
	# already measuring the ally kept measuring it. Re-derived by hand, not trusted for having moved
	# by the number expected.
	# ⚠ **23 -> 31 in `reward_view`** (티켓 12): five pure names (`_load_item_art` ·
	# `_deal_offset_of` · `_pulse_of` · `_art_rect` · `_burst_points`) and three leaves
	# (`_paint_card_art` · `_paint_rarity_frame` · `_paint_legendary_burst`). Both totals re-derived
	# from the seven per-file tables, not nudged by eight and three.
	# ⚠⚠ **BOTH totals were re-derived from the seven per-file tables for the 3D field** (ticket 09,
	# step 2), and three files moved at once: `field_view` was re-censused from scratch against the
	# 3D file — **46 -> 91 names and 13 -> 0 leaves**, because the engine draws everything the canvas
	# used to; `hud_view` lost `_paint_timer` with the deleted countdown (18 -> 17, 6 -> 5); and
	# `refit_view` renamed four leaves for the equipment re-cut (part/species -> name/effect, counts
	# unchanged).
	# ⚠ **48 -> 50 in `refit_view`** (티켓 11): the tag aggregate added `_paint_tag_row` (the leaf,
	# 14 -> 15) and `_tag_state_of` (its pure reader). Both totals re-derived from the seven per-file
	# tables, not nudged by two: 91 + 17 + 21 + 18 + 29 + 31 + 50 and 0 + 5 + 4 + 4 + 7 + 9 + 15,
	# summed by hand.
	# ⚠ 91 -> 92 in `field_view` (step 4): `_paint_boat_routes`, the caller `_route_ahead` lost in the
	# 3D move. 0 draws — the route is fx-buffer geometry — so the leaf total does not move.
	t.eq(total_funcs, 258, "일곱 파일의 함수는 모두 258개다 (92 + 17 + 21 + 18 + 29 + 31 + 50)")
	t.eq(total_leaves, 44, "그중 draw 를 실제로 부르는 잎은 44개다 (0 + 5 + 4 + 4 + 7 + 9 + 15) — 필드는 0이고, 0이 주장이다")

	# -- 3b. the array leaves hand their array WHOLE to one native call -----------------------------
	# ⚠⚠ **THIS SECTION EXISTS BECAUSE THE COUNT ABOVE CANNOT SEE THE DIFFERENCE, AND THAT WAS
	# MEASURED.** `speed-off-open-landing` turned `_paint_route` from `draw_line(from, to, …)` into
	# `draw_polyline(points, …)`. Mutating it back to
	# `draw_line(points[0], points[points.size() - 1], …)` — a boat's route cut straight across the
	# island — left **the whole 15-net round green at 2095 checks**: it is still ONE call site, and
	# `points` still counts as "used". The runtime check in `net_shell` could not catch it either,
	# because a spy OVERRIDES the leaf and never runs its body at all (`CLAUDE.md`: a spy on a hook
	# never sees the native call inside it).
	#
	# ⇒ For the three leaves that take an ARRAY, the shape is pinned: the native call must be the one
	# named, and the array parameter must appear WHOLE — never indexed inside the leaf. That is the
	# same argument `_paint_cliff_face`'s own comment already makes for `draw_multiline` over a loop
	# of `draw_line`, written as a check instead of as prose.
	var shape_bad: Array[String] = []
	var shape_checked := 0
	for path2: String in view_files:
		var base2 := path2.get_file()
		if not _whole_array_leaves().has(base2):
			continue
		var want_shapes: Dictionary = _whole_array_leaves()[base2]
		var text2 := _read(path2)
		for f2: Dictionary in _funcs(text2):
			var fname: String = f2["name"]
			if not want_shapes.has(fname):
				continue
			shape_checked += 1
			shape_bad.append_array(_shape_hits(fname, f2["body"], want_shapes[fname]))
	t.eq(shape_checked, 1, "배열을 받는 잎 하나를 실제로 봤다 (자가 점검 — 0개면 깨끗한 게 아니라 안 돈 것이다)")
	t.eq(shape_bad.size(), 0,
		"배열을 받는 잎은 그 배열을 통째로 네이티브 호출에 넘긴다 — 안을 색인하지 않는다 %s" % str(shape_bad))

	# -- 4. no presentation constant loose in src/ -------------------------------------------------
	var src_files := _gd_files_deep(SRC_DIR)
	t.ok(src_files.size() >= 9, "src/ 전체에서 .gd 를 %d개 찾았다 (최소 9)" % src_files.size())
	var colour_bad: Array[String] = []
	var pixel_bad: Array[String] = []
	var wide_bad: Array[String] = []
	var scanned := 0
	var wide_scanned := 0
	for path: String in src_files:
		if path == LOOK_PATH:
			continue
		scanned += 1
		var src_text := _read(path)
		var cols := _colour_hits(src_text)
		if cols.size() > 0:
			colour_bad.append("%s %s" % [path.get_file(), str(cols)])
		var lits := _pixel_hits(src_text)
		if lits.size() > 0:
			pixel_bad.append("%s %s" % [path.get_file(), str(lits)])
		# The widened list is deliberately NOT swept over `src/sim/` — see this file's header for the
		# three rule constants it would bite there.
		if not (path.begins_with(VIEW_DIR + "/") or path.begins_with(SHELL_DIR + "/")):
			continue
		wide_scanned += 1
		var wides := _literal_hits(src_text)
		if wides.size() > 0:
			wide_bad.append("%s %s" % [path.get_file(), str(wides)])
	t.ok(scanned >= 8, "look.gd 를 뺀 나머지 %d개를 실제로 훑었다" % scanned)
	t.eq(wide_scanned, 8, "그중 뷰 일곱과 셸 하나, 여덟을 넓힌 목록으로 다시 훑었다 — 셸이 빠지면 hold 초가 game.gd 에 박힌다")
	t.eq(colour_bad.size(), 0, "look.gd 밖에 Color( 도 Color. 도 없다 %s" % str(colour_bad))
	t.eq(pixel_bad.size(), 0, "look.gd 밖에 픽셀 이름에 박힌 리터럴이 없다 %s" % str(pixel_bad))
	t.eq(wide_bad.size(), 0, "뷰와 셸에는 시간·비율 이름에 박힌 리터럴도 없다 %s" % str(wide_bad))
	# look.gd itself has to be where they all are, or the two scans above are green because the tree
	# has no colours at all.
	t.ok(_colour_hits(_read(LOOK_PATH)).size() >= 15, "그리고 look.gd 안에는 색이 실제로 들어 있다")
	t.ok(_literal_hits(_read(LOOK_PATH)).size() >= 10, "그리고 look.gd 안에는 픽셀 상수가 실제로 들어 있다")

	_world_width_table(t)
	_invert_the_scanner(t)


# -- 5. the world-width table --------------------------------------------------------------------
## Which side of the `ZOOM_MIN` snap floor each width `field_view` draws with sits on. **An empty
## string means ABOVE the floor; any other string is the REASON it is deliberately below**, and the
## reason is the whole licence — a row cannot be moved to the below side without writing one.
##
## ⚠⚠ **This is a TABLE and not a row, and the difference is the defect it was written for.**
## `net_shell` pinned `REFUSE_MARK_WIDTH_PX * ZOOM_MIN >= 2.0` for one constant and nothing pinned the
## other eleven, so `ROUTE_WIDTH_PX` — the water route a whole round existed to draw — reached the
## glass at **1.35 px** with the round green. Nine of the twelve were under the floor and only one had
## ever been measured.
##
## ⚠ **The set is CLOSED against `field_view.gd`'s own text**, both ways: a `Look.*_WIDTH_PX` the file
## draws with that this table does not hold is red, and a row here that the file no longer draws with
## is red too. That is this repo's own named failure — a per-function table that scans the names it
## HOLDS leaked twice, the second time out of the fix for the first — written as a closure instead.
## ⚠ **Four names left this table with the 3D field, re-derived against `field_view.gd`'s own text**:
## `BODY_OUTLINE_WIDTH_PX` (a body is a baked texture on a billboard now), `CLIFF_FACE_WIDTH_PX` (a
## cliff is a real wall in the terrain mesh), `GRID_LINE_WIDTH_PX` (no grid lines are drawn at all)
## and `BEAK_WIDTH_PX` (the beak was never this layer's — the 열둘 list was wrong on that point, per
## the ticket). The closure below is what forced the re-derivation, both ways.
func _world_widths() -> Dictionary:
	return {
		"SHOT_WIDTH_PX": "",
		"BURST_WIDTH_PX": "",
		"AREA_RING_WIDTH_PX": "",
		"LAND_RING_WIDTH_PX": "",
		"ROUTE_WIDTH_PX": "",
		"REFUSE_MARK_WIDTH_PX": "",
		"TARGET_LINE_WIDTH_PX":
			"의도선은 알파 0.12 이고 한 번에 최대 14개가 섬 전체를 가로지른다 — 열두 연출 중 유일하게"
			+ " 가독성에 손해일 수 있는 항목이라 look.gd 가 이미 적어 두었다. 굵히면 그 두 제한이 막으려던"
			+ " 바로 그 어수선함이 된다",
		"SPARK_WIDTH_PX":
			"파편은 혼자 못 올린다 — 천장이 제 길이의 절반(SPARK_LEN_PX 5.0 / 2 = 2.5)이고 그 천장이"
			+ " 바닥 4.0 보다 낮다. 올리려면 SPARK_LEN_PX 와 SPARK_REACH_PX 가 같이 움직여야 하고,"
			+ " 그건 굵기 수정이 아니라 항목 2 를 눈으로 다시 재는 일이다",
	}


func _world_width_table(t) -> void:
	# ⚠ **2.0 and 0.50 are LITERALS here.** The floor is `look.gd`'s snap floor and the zoom is the
	# lowest the wheel can reach (an island OPENS at the survey zoom, which never goes under it);
	# reading either back off `Look` would let a mutation move the expectation and the reality
	# together — this repo's own named false green.
	var floor_px := 2.0
	var zoom_min := 0.50
	t.eq(Look.ZOOM_MIN, zoom_min, "휠이 닿는 가장 먼 줌은 0.50 이다 (이 표의 바닥 계산이 쓰는 값)")

	var table := _world_widths()
	var consts: Dictionary = Look.new().get_script().get_script_constant_map()

	# The closure, and it runs FIRST: a table checked against nothing is a list.
	var drawn := _look_width_names(_read(VIEW_DIR + "/field_view.gd"))
	t.eq(drawn.size(), 8, "field_view 가 그리는 데 쓰는 Look.*_WIDTH_PX 이름이 여덟이다 %s" % str(drawn))
	var outside: Array[String] = []
	for name: String in drawn:
		if not table.has(name):
			outside.append(name)
	t.eq(outside.size(), 0,
		"field_view 가 쓰는 굵기 중 표 밖에 있는 게 없다 — 내일 추가된 상수는 어느 한쪽에 서거나 빨개진다 %s"
			% str(outside))
	var stale: Array[String] = []
	for name: String in table:
		if not drawn.has(name):
			stale.append(name)
	t.eq(stale.size(), 0, "그리고 표에만 있고 field_view 는 안 쓰는 줄도 없다 %s" % str(stale))

	# Each row on its declared side. Both directions bite: a row claiming "above" that is under the
	# floor is the defect, and a row claiming "deliberately below" that has been raised is a stale
	# licence nobody withdrew.
	var above := 0
	var below := 0
	for name: String in table:
		t.ok(consts.has(name), "look.gd 에 %s 가 실제로 있다" % name)
		if not consts.has(name):
			continue
		var on_glass := float(consts[name]) * zoom_min
		var why := str(table[name])
		if why == "":
			above += 1
			t.ok(on_glass >= floor_px - 1e-6,
				"%s 는 ZOOM_MIN 에서 %.2fpx — 2.0px 스냅 바닥 위다" % [name, on_glass])
		else:
			below += 1
			t.ok(on_glass < floor_px,
				"%s 는 일부러 바닥 밑이다 (%.2fpx) — 올렸다면 표의 이유가 낡은 것이니 여기서 문다"
					% [name, on_glass])
			t.ok(why.length() >= 40, "%s 가 바닥 밑인 이유가 적혀 있다" % name)
	t.eq(above, 6, "바닥 위가 여섯이다")
	t.eq(below, 2, "일부러 바닥 밑인 것이 둘이다 — 의도선·파편")


# -- the scanner turned on itself ----------------------------------------------------------------
## Texts that must fail THIS FILE. A scanner that never matches reads exactly like a clean tree, and
## the shapes below are the shapes the checks above exist to find — so each one is fed in directly.
## If any of these stops biting, the real tree above goes on printing green and quiet.
func _invert_the_scanner(t) -> void:
	var clean := "func _paint_dot(at: Vector2, col: Color) -> void:\n\tdraw_circle(at, 3.0, col)\n"
	var clean_expect := {"_paint_dot": 1}
	t.eq(_scan(clean, clean_expect).size(), 0,
		"멀쩡한 잎에는 아무것도 안 잡는다 — 전부 빨개지는 스캐너가 아니다 (스캐너 자가 점검)")

	# (a) a bare draw call inside a function the table does not name. This is the shape that reached
	# the screen every frame under 1414 green checks and again under 1889.
	var unlisted := clean + "\n\nfunc _helper(at: Vector2) -> void:\n\tdraw_circle(at, 5.0, Color.RED)\n"
	var hit_unlisted := false
	for v: String in _scan(unlisted, clean_expect):
		if v.contains("표에 없는"):
			hit_unlisted = true
	t.ok(hit_unlisted, "표에 없는 함수 안의 맨 draw 를 잡는다 (스캐너 자가 점검)")

	# (b) the leaf that drops one of its arguments — `draw_circle(p, 0.0, col)`, the call that turned
	# forty rocks invisible with the round green.
	var dropped := "func _paint_dot(at: Vector2, radius: float, col: Color) -> void:\n\tdraw_circle(at, 0.0, col)\n"
	var hit_dropped := false
	for v: String in _scan(dropped, clean_expect):
		if v.contains("안 쓰인 인자"):
			hit_dropped = true
	t.ok(hit_dropped, "잎이 인자 하나를 버리면 잡는다 (스캐너 자가 점검)")

	# (b2) the SAME shape one argument further out. `_paint_body` grew a seventh parameter (`squash`)
	# and `_paint_spark` was born taking `points`; both are exactly the kind of argument a leaf can
	# accept and then quietly not use, and the count stays right while it does.
	var dropped_last := "func _paint_body(at: Vector2, col: Color, squash: Vector2) -> void:\n\tdraw_polyline(PackedVector2Array([at]), col, 2.0)\n"
	var hit_last := false
	for v: String in _scan(dropped_last, {"_paint_body": 1}):
		if v.contains("안 쓰인 인자 squash"):
			hit_last = true
	t.ok(hit_last, "잎이 마지막 인자만 버려도 잡는다 (스캐너 자가 점검)")

	# (c) one draw call too many in a leaf the table pins at 1.
	var extra := "func _paint_dot(at: Vector2, col: Color) -> void:\n\tdraw_circle(at, 3.0, col)\n\tdraw_rect(Rect2(at, at), col)\n"
	var hit_extra := false
	for v: String in _scan(extra, clean_expect):
		if v.contains("draw 수"):
			hit_extra = true
	t.ok(hit_extra, "잎의 draw 수가 표와 다르면 잡는다 (스캐너 자가 점검)")

	# (c2) the other direction: a name the table holds that the file no longer has. Without it a
	# deleted hook would leave the totals short and nothing would say which one went.
	var missing := "func _paint_dot(at: Vector2, col: Color) -> void:\n\tdraw_circle(at, 3.0, col)\n"
	var hit_missing := false
	for v: String in _scan(missing, {"_paint_dot": 1, "_paint_spark": 1}):
		if v.contains("파일에 없는 함수"):
			hit_missing = true
	t.ok(hit_missing, "표에는 있는데 파일에서 사라진 함수를 잡는다 (스캐너 자가 점검)")

	# (c3) ⚠⚠ **the corner cut, which every other check in this file is blind to.** A `_paint_route`
	# that draws a straight line between the polyline's two ends is still one call site with every
	# argument used — measured green across the whole round. Both halves of the shape rule have to
	# bite: the wrong native call, and the parameter indexed inside the leaf.
	var cut := "\tdraw_line(points[0], points[points.size() - 1], colour, width)\n"
	t.ok(_shape_hits("_paint_route", cut, ["draw_polyline", "points"]).size() >= 1,
		"폴리라인을 두 끝점 직선으로 바꾼 잎을 잡는다 (스캐너 자가 점검 — 라운드 전체가 초록이던 그 변형이다)")
	var indexed := "\tdraw_polyline(points, colour, width)\n\tvar x := points[0]\n"
	t.ok(_shape_hits("_paint_route", indexed, ["draw_polyline", "points"]).size() >= 1,
		"올바른 호출을 해도 잎 안에서 배열을 색인하면 잡는다 (스캐너 자가 점검)")
	var whole := "\tdraw_polyline(points, colour, width)\n"
	t.eq(_shape_hits("_paint_route", whole, ["draw_polyline", "points"]).size(), 0,
		"멀쩡한 잎은 안 잡는다 — 전부 빨개지는 검사가 아니다 (스캐너 자가 점검)")

	# (d) a colour moved out of look.gd, in both of its shapes.
	t.ok(_colour_hits("var c := Color(0.1, 0.2, 0.3)\n").size() > 0,
		"look.gd 밖으로 옮겨진 색 리터럴을 잡는다 (스캐너 자가 점검)")
	t.ok(_colour_hits("\tdraw_rect(r, Color.RED)\n").size() > 0,
		"이름 붙은 색도 잡는다 (스캐너 자가 점검)")
	t.eq(_colour_hits("func f(bg: Color) -> Color:\n\treturn bg\n").size(), 0,
		"타입으로 쓰인 Color 는 안 잡는다 (스캐너 자가 점검)")
	# A comment is not code, and a scanner that reddened on prose would be turned off within a day.
	t.eq(_colour_hits("# the old build used Color.RED here\n").size(), 0,
		"주석 안의 색 이름은 안 잡는다 (스캐너 자가 점검)")

	# (e) a pixel literal moved out of look.gd.
	t.ok(_pixel_hits("var bar_width := 24.0\n").size() > 0,
		"look.gd 밖의 픽셀 리터럴을 잡는다 (스캐너 자가 점검)")
	t.ok(_pixel_hits("const HUD_MARGIN_PX := 12.0\n").size() > 0,
		"대문자 상수 이름도 잡는다 (스캐너 자가 점검)")
	t.ok(_pixel_hits("\tspan_size = Vector2(30.0, 18.0)\n").size() > 0,
		"Vector2 리터럴도 잡는다 (스캐너 자가 점검)")
	t.eq(_pixel_hits("var bar_width := Look.HP_BAR_W_PX\n").size(), 0,
		"look.gd 에서 읽어온 값은 안 잡는다 (스캐너 자가 점검)")
	t.eq(_pixel_hits("\tif frame_width >= 4:\n\t\tpass\n").size(), 0,
		"비교는 대입이 아니다 — 안 잡는다 (스캐너 자가 점검)")

	# (f) the widened half. **These eight names are the whole reason the list grew**: measured against
	# the narrow list, every one of them slipped through, and `combat-juice`'s own table is where they
	# live. A synthetic case per name, because "the list is wider now" is not a measurement.
	for name: String in ["BURST_GROWTH", "TARGET_LINE_MAX_COUNT", "SHAKE_A_FREQ", "SHAKE_B_FREQ",
			"GAIT_PERIOD_TILES", "GAIT_SQUASH", "WATER_MARGIN_TILES", "FX_MAX_COUNT"]:
		t.ok(_literal_hits("const %s := 2.2\n" % name).size() > 0,
			"넓힌 목록이 %s 를 잡는다 (스캐너 자가 점검)" % name)
		t.eq(_pixel_hits("const %s := 2.2\n" % name).size(), 0,
			"그리고 좁은 목록으로는 %s 가 안 잡혔다 — 목록이 넓어진 이유다 (스캐너 자가 점검)" % name)
	# The ninth: an angle. It matched none of the other twenty-two suffixes.
	t.ok(_literal_hits("const SPARK_SPREAD_DEG := 12.0\n").size() > 0,
		"넓힌 목록이 SPARK_SPREAD_DEG 를 잡는다 — deg 를 빼먹으면 이 줄이 문다 (스캐너 자가 점검)")
	# `ratio` moved from the narrow list to the wide one — a view-file ratio is still caught, and the
	# sim's `SUMMON_RADIUS_RATIO` (a rule, not presentation) stops being bitten by the src-wide sweep.
	t.ok(_literal_hits("const SHADOW_R_RATIO := 0.85\n").size() > 0,
		"넓힌 목록이 ratio 를 잡는다 — 뷰의 비율 상수는 여전히 물린다 (스캐너 자가 점검)")
	t.eq(_pixel_hits("const SUMMON_RADIUS_RATIO := 0.46\n").size(), 0,
		"좁은 목록은 ratio 를 안 문다 — sim 의 규칙 비율이 look.gd 로 끌려오지 않는다 (스캐너 자가 점검)")
	# The tenth, and it is the pattern's VALUE side rather than its name side: an array literal starts
	# with `[`, so `FX_GAIN` was the one constant of the forty-four that no suffix could ever reach.
	# Writing "all forty-four are caught" without this case is how the one hole stays invisible.
	t.ok(_literal_hits("const FX_GAIN := [1.0, 1.0]\n").size() > 0,
		"넓힌 목록이 배열 리터럴도 잡는다 — FX_GAIN 이 유일한 구멍이었다 (스캐너 자가 점검)")
	t.eq(_literal_hits("const FX_GAIN := Look.DEFAULT_GAIN\n").size(), 0,
		"배열이 아니라 참조면 안 잡는다 (스캐너 자가 점검)")
	# And the reason the widened sweep stops at `src/view/` + `src/shell/`: run it over `src/sim/` and
	# it bites rule constants, which are not presentation and must not be dragged into `look.gd`.
	t.ok(_literal_hits("const LION_WINDUP_SEC := 0.6\n").size() > 0,
		"넓힌 목록은 sim 의 룰 상수까지 문다 — 그래서 범위가 뷰와 셸뿐이다 (스캐너 자가 점검)")
	t.ok(_literal_hits("const TYPE_COUNT := 5\n").size() > 0,
		"표 컬럼 수도 문다 — 같은 이유다 (스캐너 자가 점검)")

	# (f2) the world-width extractor. It is what CLOSES the width table, so it has to bite a name the
	# table does not hold and it has to ignore the prose that names those same constants everywhere.
	t.eq(_look_width_names("\t_paint_thing(p, Look.NEW_MARK_WIDTH_PX)\n"),
		["NEW_MARK_WIDTH_PX"] as Array[String],
		"내일 추가된 굵기 이름을 뽑아낸다 — 표에 없으면 위에서 빨개진다 (스캐너 자가 점검)")
	t.eq(_look_width_names("# ⚠ Look.ROUTE_WIDTH_PX was 3.0 and drew at 1.35 px\n").size(), 0,
		"주석 안의 굵기 이름은 안 뽑는다 (스캐너 자가 점검)")
	t.eq(_look_width_names("\tvar w := Look.BEAK_LENGTH_PX\n").size(), 0,
		"굵기가 아닌 이름은 안 뽑는다 (스캐너 자가 점검)")
	# (g) the comment stripper is the floor under every scan above: if it stopped stripping, a comment
	# naming `draw_rect` would be counted as a call and the whole table would read as broken; if it
	# stripped too eagerly, a `#` inside a string would cut a line of real code away unseen.
	t.eq(_strip_comment("\tdraw_rect(r, c)  # and not draw_circle(p, 0.0, c)").strip_edges(),
		"draw_rect(r, c)", "주석은 잘라낸다 (스캐너 자가 점검)")
	t.eq(_strip_comment("var row := \"~~##..\"  # the wall"),
		"var row := \"~~##..\"  ", "문자열 안의 # 는 주석이 아니다 (스캐너 자가 점검)")


# -- the scan itself -----------------------------------------------------------------------------
## Returns one string per violation, empty when the text matches `expect` exactly. It takes TEXT, not
## a path, so the synthetic cases above can fail the scanner rather than the tree.
## The three leaves that take an ARRAY of geometry, and the shape each one's body must have:
## `[native call name, the parameter that must be handed to it whole]`.
##
## ⚠ **A table and not a branch**, for the same reason `_table()` is: a fourth array leaf added
## tomorrow costs one line here, and until it is written the closed-class scan above already reddens
## on its NAME — so it cannot arrive unnoticed and then silently skip this scan too.
func _whole_array_leaves() -> Dictionary:
	return {
		# ⚠ **`field_view`'s three rows left with the leaves themselves** (the 3D move): `_paint_route`,
		# `_paint_cliff_face` and `_paint_spark` no longer exist — the route and the spark build
		# vertices straight into the fx buffers and the cliff is mesh geometry. The corner-cut this
		# table caught there is caught at RUNTIME now: `net_slots` demands a vertex beside EVERY
		# waypoint of the aim's route, which a straightened polyline cannot produce.
		# 티켓 12's burst — the rays are built in `_burst_points` and must reach `draw_multiline` whole.
		"reward_view.gd": {
			"_paint_legendary_burst": ["draw_multiline", "points"],
		},
	}


## The shape findings for one leaf body. Two halves, and both are needed:
##  · the named native call must appear taking that parameter as its FIRST argument
##  · the parameter must never be indexed (`points[`) anywhere in the body — that is how a loop of
##    `draw_line`, or a straight line between the two ends, gets written while every count stays right
func _shape_hits(fname: String, body: String, want: Array) -> Array[String]:
	var call_name := str(want[0])
	var param := str(want[1])
	var out: Array[String] = []
	if body.find("%s(%s," % [call_name, param]) < 0:
		out.append("%s 가 %s(%s, …) 를 안 부른다" % [fname, call_name, param])
	if body.find("%s[" % param) >= 0:
		out.append("%s 가 잎 안에서 %s 를 색인한다" % [fname, param])
	return out


func _scan(text: String, expect: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var seen := {}
	for f: Dictionary in _funcs(text):
		var name: String = f["name"]
		seen[name] = true
		# **The class is closed here.** Not "these names are checked and the rest are ignored" — the
		# rest is the failure.
		if not expect.has(name):
			bad.append("표에 없는 함수 %s" % name)
			continue
		var want := int(expect[name])
		var got := _draw_calls(f["body"])
		if got != want:
			bad.append("%s 의 draw 수 %d, 기대 %d" % [name, got, want])
		if want <= 0:
			continue
		for p: String in f["params"]:
			# A leading underscore is GDScript's own "deliberately unused" marker, so it is not a
			# finding. No leaf in this game has one.
			if p.begins_with("_"):
				continue
			if not _uses(f["body"], p):
				bad.append("%s 의 몸통에서 안 쓰인 인자 %s" % [name, p])
	for name: String in expect:
		if not seen.has(name):
			bad.append("표에는 있는데 파일에 없는 함수 %s" % name)
	return bad


## Every function in the text, in order: `{name, params: Array[String], body: String}`.
## Two passes on purpose — the start lines are found first, so a function's body is "everything up to
## the next `func`" and a helper added at the bottom of a file cannot hide inside its neighbour.
func _funcs(text: String) -> Array:
	var lines := text.split("\n")
	var starts: Array[int] = []
	for i in lines.size():
		var head := _strip_comment(lines[i]).strip_edges()
		if head.begins_with("func ") or head.begins_with("static func "):
			starts.append(i)
	var out := []
	for k in starts.size():
		var s: int = starts[k]
		var e: int = starts[k + 1] if k + 1 < starts.size() else lines.size()
		# The signature can wrap across lines, so it is closed on paren balance rather than on a
		# newline: `_paint_key` really does declare its last parameter on the second line.
		var sig := ""
		var depth := 0
		var opened := false
		var last := s
		for i in range(s, e):
			var line := _strip_comment(lines[i])
			sig += line
			for c in line:
				if c == "(":
					depth += 1
					opened = true
				elif c == ")":
					depth -= 1
			last = i
			if opened and depth <= 0:
				break
		var name := ""
		var open_at := sig.find("(")
		if open_at > 0:
			var before := sig.substr(0, open_at)
			var parts := before.split(" ", false)
			if parts.size() > 0:
				name = str(parts[parts.size() - 1]).strip_edges()
		var params: Array[String] = []
		if open_at >= 0:
			params = _split_params(_inside_parens(sig, open_at))
		var body := ""
		for i in range(last + 1, e):
			body += _strip_comment(lines[i]) + "\n"
		out.append({"name": name, "params": params, "body": body})
	return out


func _inside_parens(sig: String, open_at: int) -> String:
	var depth := 0
	var out := ""
	for i in range(open_at, sig.length()):
		var c := sig[i]
		if c == "(":
			depth += 1
			if depth == 1:
				continue
		elif c == ")":
			depth -= 1
			if depth == 0:
				return out
		if depth >= 1:
			out += c
	return out


## Split on commas at depth 0 only — a default value like `Vector2(1, 2)` holds a comma that is not a
## parameter break, and splitting on it would invent a parameter name nothing could ever use.
func _split_params(text: String) -> Array[String]:
	var out: Array[String] = []
	var depth := 0
	var cur := ""
	for c in text:
		if c == "(" or c == "[" or c == "{":
			depth += 1
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
		if c == "," and depth == 0:
			out.append(_param_name(cur))
			cur = ""
			continue
		cur += c
	if cur.strip_edges() != "":
		out.append(_param_name(cur))
	var clean: Array[String] = []
	for p: String in out:
		if p != "":
			clean.append(p)
	return clean


func _param_name(raw: String) -> String:
	var s := raw.strip_edges()
	for cut in [":", "="]:
		var at := s.find(cut)
		if at > 0:
			s = s.substr(0, at)
	return s.strip_edges()


## `draw_*` call sites in a body. `queue_redraw` does not match and must not: it holds "redraw", never
## "draw_", which is why the underscore is part of the pattern rather than a word boundary alone.
func _draw_calls(body: String) -> int:
	var re := RegEx.new()
	re.compile("\\bdraw_[a-z_]+\\s*\\(")
	return re.search_all(body).size()


## Every `Look.<NAME>_WIDTH_PX` a file reads in CODE, deduplicated and sorted. Comments are stripped
## first for the same reason every other scan here strips them: `look.gd`'s own paragraphs name these
## constants a dozen times, and a scan that counted prose would report a table that covers names
## nothing draws with.
func _look_width_names(text: String) -> Array[String]:
	var re := RegEx.new()
	re.compile("Look\\.([A-Z][A-Z0-9_]*_WIDTH_PX)\\b")
	var seen := {}
	for raw in text.split("\n"):
		for m in re.search_all(_strip_comment(raw)):
			seen[m.get_string(1)] = true
	var out: Array[String] = []
	for k: String in seen:
		out.append(k)
	out.sort()
	return out


func _uses(body: String, name: String) -> bool:
	var re := RegEx.new()
	re.compile("\\b" + name + "\\b")
	return re.search(body) != null


# -- the loose-constant scans --------------------------------------------------------------------
## `Color(` and `Color.` in CODE. Comments are stripped first: a scan that reddened on prose gets
## turned off, and what reaches the screen is the code.
func _colour_hits(text: String) -> Array[String]:
	var re := RegEx.new()
	re.compile("Color\\s*[(.]")
	var out: Array[String] = []
	for raw in text.split("\n"):
		var line := _strip_comment(raw)
		for _m in re.search_all(line):
			out.append(line.strip_edges())
	return out


## The SIZE-ish half, for the whole of `src/`. A pixel number is presentation wherever it is written,
## so this one keeps the wide scope.
func _pixel_hits(text: String) -> Array[String]:
	return _hits_with(text, PIXEL_SUFFIXES)


## The full list — sizes AND durations AND shape factors — for `src/view/` and `src/shell/`.
##
## ⚠ **The colour half of this rule shipped once with the pixel half never written**, and a panel laid
## its cards out from bare literals while the round stayed green about "no presentation constant is
## loose". The TIME half was the same hole again: an effect's constants are half durations, and
## `combat-juice` names this function as the one place the list lives.
func _literal_hits(text: String) -> Array[String]:
	return _hits_with(text, PIXEL_SUFFIXES + "|" + TIME_SUFFIXES)


## A number, a `Vector2` of numbers, or an ARRAY of numbers, assigned to a name ending in one of
## `suffixes`.
##
## `(?i)` is load-bearing and not tidiness: every one of these names in `look.gd` is a SCREAMING_CASE
## `const`, so a case-sensitive pattern would scan for a shape the repo does not write and report a
## clean tree for a rule it never applied.
##
## The `(:=|=)` never matches `==`, `>=` or `!=`: the character after the `=` has to be a digit, a
## minus, a `Vector2` or a `[`, and a comparison puts another `=` there. **The `[` alternative is not
## decoration** — `FX_GAIN`'s twelve-slot array was the one constant of the forty-four that no suffix
## could reach, because the value side demanded a digit.
func _hits_with(text: String, suffixes: String) -> Array[String]:
	var re := RegEx.new()
	re.compile("(?i)[A-Za-z0-9_.]*_(" + suffixes
		+ ")\\s*(:=|=)\\s*(-?[0-9]|Vector2\\s*\\(\\s*-?[0-9]|\\[\\s*-?[0-9])")
	var out: Array[String] = []
	for raw in text.split("\n"):
		var line := _strip_comment(raw)
		if re.search(line) != null:
			out.append(line.strip_edges())
	return out


## Everything after the first `#` that is not inside a string. The string half is load-bearing even
## though no view file needs it: `islands.gd` is in the `src/` sweep and its map rows are strings full
## of `#`, and a naive stripper would cut most of that file away and scan the stump.
func _strip_comment(line: String) -> String:
	var out := ""
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if quote != "":
			out += c
			if c == "\\" and i + 1 < line.length():
				out += line[i + 1]
				i += 2
				continue
			if c == quote:
				quote = ""
			i += 1
			continue
		if c == "\"" or c == "'":
			quote = c
			out += c
			i += 1
			continue
		if c == "#":
			break
		out += c
		i += 1
	return out


# -- files ---------------------------------------------------------------------------------------
func _gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	out.sort()
	return out


func _gd_files_deep(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	_walk(dir_path, out)
	out.sort()
	return out


func _walk(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub: String in d.get_directories():
		_walk(dir_path.path_join(sub), out)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()
