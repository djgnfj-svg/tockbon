extends RefCounted
## Enforces the two-leaf draw contract `title_screen.gd` and `ending_screen.gd` each document in their own
## header: `_paint_rect`/`_paint_text` are the ONLY places `draw_rect`/`draw_string`/any other native
## `draw_*` may be called. Two rounds of `net_screens.gd` were rebuilt around a spy that watches exactly
## those two hooks — nothing stopped a fifth call site from quietly reopening the hole either round closed.
## This is that stop, the same shape `net_citations.gd` is for its own citation forms.
##
## **Scoped to the files that make the claim, not every file under `src/view/`.** `SCOPED_FILES` is the
## list; a file joins it the day its own header states the same two-leaf contract these ones do — and the
## day it joins is the day it is rewritten, which is the only cheap moment. **`body_panel.gd` stated the
## contract verbatim and was left out anyway**, which is how plan 3, filling the eleven slots, would have
## put a third bare `c.draw_*` straight into `_paint_slot` where the panel's own spy cannot see it.
## ⇒ **`card_panel.gd` joined on plan 3's rewrite**: `draw_multiline_string` went out with `Cards.DESC`, so
## it dropped from seven bare call sites and three primitives to `_paint_rect`/`_paint_text` and two.
##
## ⇒ **`hud.gd` joined on plan 4's rewrite, and it took the OTHER shape of scan** (`HUD_LEAF_CALLS`, per
## function) rather than this one. It cannot live under a file-wide bound of two: the level bar, the
## minimap's background, its edge and its camera box are four rectangles, plus a mark per body on the map.
## Its two bare `c.draw_rect` calls went through `_paint_rect` in the same edit, so `_paint` and
## `_paint_minimap` now hold **zero** draw calls of their own — and `: 0` is a real assertion here, because
## `_calls_in_func` answers **-1** for a function that is not there and 0 only for one that is and is empty.
##
## ⇒ **`field_view.gd` cannot live under a file-wide bound of two either — same shape of scan,
## per function**, and it needs one for a measured reason. Its leaves are spied by `net_paint` and a spy
## sees the hook being CALLED, never the native call inside it: `c.draw_circle` in `_paint_dot` and
## `c.draw_polyline` in `_paint_outline` were each replaced with `pass` and the whole round stayed green
## at 846 checks, stderr clean. Headless has no pixels to read back, so the only thing left that can see
## an emptied leaf is its own text.
##
## ⚠ **A per-function table scans the functions it NAMES and nothing else, and that hole was measured
## twice.** `FIELD_LEAF_CALLS` first held nine leaves and not one composer, so a bare
## `c.draw_circle(Vector2(50, 50), 300.0, Color.MAGENTA)` at the top of `FieldView._paint` reached the
## screen every frame with 1414 checks green and stderr clean. Every composer was then listed with a
## `: 0` — and **seventeen of the file's twenty-eight functions were named, so eleven stayed outside**:
## the same circle at the top of `_striking()` and of `_cluster()`, both called from `_paint` every frame,
## were each green at 1889 checks with stderr clean. Adding names fixes the day it is done and nothing
## after it. ⇒ **`_every_function_is_in_the_table()` walks the FILE and fails on any name the table does
## not hold**, in both directions with the walks that go the other way, so the residual hole is closed by
## the instrument rather than by whoever writes the next function remembering this paragraph.
##
## **Comment lines are excluded before counting** — a header sentence describing the contract (this file's
## own, or either screen's) freely writes `c.draw_rect` in prose, and that must not count as a violation.

const SCOPED_FILES := ["res://src/view/title_screen.gd", "res://src/view/ending_screen.gd",
		"res://src/view/body_panel.gd", "res://src/view/card_panel.gd"]
const MAX_CALLS := 2

## `field_view.gd`, per function: how many `draw_*` call lines that function's body is allowed to hold,
## exactly. Eight leaves at one call each, and `_paint_cell` at seven (three polygons and four
## `draw_set_transform`) — pinned rather than bounded, because "at most" cannot see a leaf going empty and
## that is the failure this whole block exists for.
##
## ⚠ **`_paint_disc` and `_paint_label` joined with plan 4's ground and its force numbers.** A leaf that is
## absent from this table is unscanned: `_calls_in_func` only counts functions it is asked about, so the
## day a new leaf is written and not listed here it can be emptied with the whole round green.
##
## ⇒ **The `: 0` rows are the composers, and they are the half that was missing.** `_draw` and
## `_paint` are where a debug circle actually gets dropped; `_paint_body`, `_paint_limb_pair` and
## `_paint_ring` assemble a body out of leaves and must not reach past them; `_blob`, `_force_labels` and
## `_label` build geometry and text and draw nothing at all. Same reading as `hud.gd`'s zeros:
## `_calls_in_func` answers **-1** for a function that is not there and 0 only for one that is and holds
## nothing, so a renamed composer is red rather than silently satisfied.
##
## ⚠ **Naming seventeen of twenty-eight left eleven functions unscanned, and two of them were driven.** A
## bare `draw_circle(Vector2(50, 50), 300.0, Look.HOST_COLOR)` at the top of `_striking()` — called from
## `_paint` every frame — painted a 300px opaque disc over the play field with 1889 checks green and stderr
## clean; `_cluster()` did the same. `FieldView extends Node2D`, so `draw_*(...)` on `self` needs no
## `CanvasItem` parameter to compile, and every one of the eleven is reachable from `_paint`. All eleven are
## listed now — **and the residual hole that let them sit outside is closed structurally rather than by
## remembering**: `_every_function_is_in_the_table()` walks the file's own `func` lines and fails on any
## name that is not a key here, so a leaf or composer written tomorrow is red until it is listed.
const FIELD_VIEW := "res://src/view/field_view.gd"
const FIELD_LEAF_CALLS := {
	"_paint_part_shape": 1,
	"_paint_part_line": 1,
	"_paint_outline": 1,
	"_paint_dot": 1,
	"_paint_disc": 1,
	"_paint_label": 1,
	"_paint_arc": 1,
	"_paint_cone": 1,
	# `melee-legibility-ko`'s fork, both candidates live in one build behind `Look.BODY_STYLE`. `_paint_cell`
	# was 7 and is a DISPATCHER now: the seven moved whole into `_paint_cell_fill` (three polygons and four
	# `draw_set_transform`) and 갈래 ㄱ's own leaf holds four (two transforms, a polyline and the nucleus).
	# **These two counts are the last inch of the switch.** A spy sees which leaf was CALLED; only the count
	# sees `_paint_cell_line` quietly drawing the filled body instead of the line.
	"_paint_cell_fill": 7,
	"_paint_cell_line": 4,
	"_paint_cell": 0,
	"_outline_width": 0,
	"_outline_dot_r": 0,
	# 갈래 ㄴ. **Every one of these is a `: 0`, and that is the claim**: the candidate adds no leaf at all —
	# the rim reuses `_paint_outline` and the host's ground ring reuses `_paint_arc`, which is
	# `melee-legibility-ko`'s own test for a cheap option. `_paint_clone`/`_paint_critter`/`_paint_host` are
	# the three loops that used to sit inside `_paint`, moved whole so only their ORDER is new, and a stray
	# `c.draw_*` in any of them is a pixel no spy on the leaves could ever see.
	"_rimmed": 0,
	"_paint_bodies": 0,
	"_body_order": 0,
	"_depth": 0,
	"_paint_clone": 0,
	"_paint_critter": 0,
	# §6's per-species attack gestures. **Every one is a `: 0` and that is the claim being made**: seven new
	# gestures cost NO new leaf — each reaches `_paint_part_line`, `_paint_disc` or `_paint_arc`, which
	# already have their rows above and already have spies watching them in `net_paint`. A gesture that
	# reached past them for a bare `c.draw_*` would be a pixel no spy in the round could see, and that is
	# what these zeros forbid. `_paint_swing` is the dispatcher; `_paint_swing_lash` is the fallback the file
	# drew for every species before this pass.
	"_paint_swing": 0,
	"_paint_swing_peck": 0,
	"_paint_swing_gnaw": 0,
	"_paint_swing_bite": 0,
	"_paint_swing_charge": 0,
	"_paint_swing_shove": 0,
	"_paint_swing_pounce": 0,
	"_paint_swing_stomp": 0,
	"_paint_swing_lash": 0,
	# A composer: the bloom and the wave both go through leaves that already have rows below, so it draws
	# nothing of its own. Zero here is the assertion, not an omission.
	"_paint_hit_bloom": 0,
	# Pure: it returns an offset and draws nothing at all.
	"_lunge_offset": 0,
	"_paint_host": 0,
	"_paint_bite_cone": 0,
	"_paint_rim": 0,
	"_rim_width": 0,
	"_draw": 0,
	"_paint": 0,
	"_paint_body": 0,
	"_paint_limb_pair": 0,
	"_paint_ring": 0,
	"_blob": 0,
	"_force_labels": 0,
	"_label": 0,
	# The eleven that were outside the table. Every one is reached from `_paint`, so every one is a place a
	# debug circle survives the round: `_striking` and `_cluster` were measured doing exactly that.
	"reset_pop": 0,
	"_process": 0,
	"_cluster": 0,
	"_striking": 0,
	"_body_corner": 0,
	"_body_outline_width": 0,
	"_body_colour_depth": 0,
	"_body_dot_radius": 0,
	"_has": 0,
	"_squash": 0,
	"_heading": 0,
}

## `hud.gd`, the same shape. **The eight `: 0` entries are the point of the table, not filler**: they say
## every function here except the three leaves composes and never draws, and `_calls_in_func` distinguishes
## -1 (the function is gone) from 0 (it is there and holds nothing), so a bare `c.draw_rect` put back into
## any of them is red. `_minimap_frame`, `_minimap_marks` and `_to_map` are geometry — they hand back a
## rectangle, an array and a point, and a `draw_*` inside one of them would be a pixel no spy on the two
## leaves could see.
##
## ⚠ **`_ready` was the one function outside this table** and it is listed now, for the same reason the
## field's eleven are: an unlisted function is an unscanned one, whatever anyone believes about it.
## `_every_function_is_in_the_table()` is what keeps that true without anyone remembering.
const HUD := "res://src/view/hud.gd"
const HUD_LEAF_CALLS := {
	"_paint_text": 1,
	"_paint_rect": 1,
	"_paint_mark": 1,
	# §D-2's edge arrow. `_paint_rect`/`_paint_mark` cannot draw a triangle, so this is a fourth leaf rather
	# than a reuse — the residual-hole scan below (`_every_function_is_in_the_table`) is what keeps it from
	# sitting outside every table the day it was written, the exact hole `_striking`/`_cluster` shipped
	# through on `field_view.gd`.
	"_paint_tri": 1,
	"_ready": 0,
	"_draw": 0,
	"_process": 0,
	"_paint": 0,
	"_paint_minimap": 0,
	"_minimap_frame": 0,
	"_minimap_marks": 0,
	"_to_map": 0,
}

## **The leaves whose PARAMETERS must all still be used.** Counting a leaf's `draw_*` calls says the call is
## there; it says nothing about what was handed to it, and that gap was measured: `_paint_disc`'s body
## rewritten to `c.draw_circle(p, 0.0, col)` keeps the count at 1 and turns forty rocks and twelve ponds
## invisible with the round green — `net_paint._t6` still passes, because `_disc_is()` reads the radius the
## SPY captured, which is the argument the leaf was called with and not the one it drew. Same shape for
## `_paint_label` handed `Vector2.ZERO`.
##
## ⚠ **The rule is "every parameter is still mentioned in the body", not "the draw call's arguments are the
## parameter names".** Three of these leaves legitimately do not pass their parameters straight through —
## `_paint_outline` and `_paint_cone` build a point array on a line above the draw call, and
## `_paint_part_shape` folds `r`, `p` and `corner` into a `_blob()` call inside the argument list. A scan
## that demanded a literal name-for-name match would have to be told about all three, and a scan told about
## exceptions stops being a scan. **The residual hole is named**: a parameter kept alive by a statement that
## does nothing with it would satisfy this.
const LEAF_PARAMS := {
	# ⚠ **`_paint_cell` stays on this list even though it draws nothing now.** It forwards all seven of its
	# parameters, so the scan catches a dispatcher that quietly drops one — the same class of bug that turned
	# forty rocks invisible through `_paint_disc`. Its two candidates are listed beside it.
	# ⚠ **`_paint_rim` is here for the same reason `_paint_cell` is.** It draws nothing itself — it forwards
	# a body's position, radius, corner, squash and rotation to `_paint_outline` — and a rim handed
	# `Vector2.ONE`/`0.0` instead of the body's own transform is exactly the stroke that sits square around a
	# stretched body. `_paint_outline`'s own row cannot see that: the parameters stay used inside the leaf.
	# ⚠ **The nine gesture functions are here for exactly the reason `_paint_rim` is.** They draw nothing of
	# their own — they forward a creature's lunged position, its radius, its swing direction and the swing's
	# own progress `t` into an existing leaf — and a gesture handed a `t` it never reads is a mark that does
	# not animate at all, which is the whole difference between 갉기 shrinking and 갉기 sitting there. The
	# leaves' own rows cannot see that: `t` never reaches them, only the number it produced.
	FIELD_VIEW: ["_paint_part_shape", "_paint_part_line", "_paint_outline", "_paint_dot", "_paint_disc",
			"_paint_label", "_paint_arc", "_paint_cone", "_paint_cell", "_paint_cell_fill",
			"_paint_cell_line", "_paint_rim", "_paint_swing", "_paint_swing_peck", "_paint_swing_gnaw",
			"_paint_swing_bite", "_paint_swing_charge", "_paint_swing_shove", "_paint_swing_pounce",
			"_paint_swing_stomp", "_paint_swing_lash"],
	HUD: ["_paint_text", "_paint_rect", "_paint_mark", "_paint_tri"],
}

## **One file holds every colour, and until this scan nothing said so.** `hud.gd` declared six of its own,
## `card_panel.gd` six more and `field_view.gd` one; CLAUDE.md has listed "grep outside `look.gd` for colour
## and pixel literals" as unwritten since the folder contracts were written. This is the colour half.
##
## ⚠ **The PIXEL half is still unwritten and this scan does not cover it.** `card_panel.gd` lays its cards
## out from literals in `_paint()` and `field_view.gd` keeps its tessellation counts, which are deliberately
## not `look.gd`'s. Reading a green here as "no presentation constant is loose" is the overstatement this
## file's own header already had to be corrected for once.
const PALETTE_HOME := "res://src/look.gd"
## Hand-written, like every other count in this file: read back off the walk it guards, a walk that found
## nothing at all would be `0 == 0` and every assertion under it would simply stop running.
const PALETTE_SCANNED := 18

var _draw_call := RegEx.new()
var _colour_literal := RegEx.new()


func run(t) -> void:
	_draw_call.compile("draw_[A-Za-z_]+\\s*\\(")
	# `Color(` and `Color.RED` alike — the second form is what a debug line reaches for.
	_colour_literal.compile("\\bColor\\s*[(.]")

	# The literal 4, not `SCOPED_FILES.size()` read back — `checked == SCOPED_FILES.size()` is `0 == 0`
	# if the list is ever emptied, and the two synthetic self-checks below still run either way, so the
	# runner's own zero-check detector never fires. A bound taken from the list it is meant to guard.
	# **Hand-written on purpose: it has to move with the list, every time.**
	t.eq(SCOPED_FILES.size(), 4,
			"감시 대상 목록이 비어 있지 않다 (title_screen.gd, ending_screen.gd, body_panel.gd, card_panel.gd)")

	var checked := 0
	for path: String in SCOPED_FILES:
		var text := _read(path)
		t.ok(text != "", "%s를 읽었다" % path)
		var n := _count_draw_calls(text)
		t.ok(n <= MAX_CALLS, "%s: 코드 안 draw_ 호출 지점이 %d개, 최대 %d개까지다" % [path, n, MAX_CALLS])
		checked += 1
	t.eq(checked, SCOPED_FILES.size(), "대상 파일을 빠짐없이 다 셌다")

	# **Inverting the code does not prove the scanner works** (CLAUDE.md) — a synthetic fixture with three
	# call sites has to fail the SAME counter, or a scanner that never actually enforces the bound reads
	# identical to one that does.
	var over_limit := "func _paint(c):\n\tc.draw_rect(a, b)\n\tc.draw_string(c, d)\n\tc.draw_circle(e, f)\n"
	t.ok(_count_draw_calls(over_limit) > MAX_CALLS, "세 곳짜리 가짜 파일은 스스로 한도를 넘는다 (스캐너 자가 점검)")

	var under_limit := ("func _paint_rect(c, r, col):\n\tc.draw_rect(r, col)\n\n"
			+ "## a mention of c.draw_string in a comment, not code\n"
			+ "func _paint_text(c, p, s):\n\tc.draw_string(f, p, s)\n")
	t.eq(_count_draw_calls(under_limit), 2, "주석 속 draw_ 언급은 실제 호출로 세지 않는다 (스캐너 자가 점검)")

	_field_view_leaves(t)
	_hud_leaves(t)
	_every_function_is_in_the_table(t)
	_every_parameter_still_reaches_a_draw(t)
	_look_is_the_only_palette(t)


# -- field_view.gd, one function at a time ---------------------------------------------------------------
## A spy that overrides `_paint_dot` sees the hook being called; it never sees the `draw_circle` inside it.
## Measured on this tree: emptying that call and `_paint_outline`'s `draw_polyline` left 846 checks green.
func _field_view_leaves(t) -> void:
	var text := _read(FIELD_VIEW)
	t.ok(text != "", "%s를 읽었다" % FIELD_VIEW)
	# The literal 32, hand-written like `SCOPED_FILES.size()` above: read back off the dictionary it guards,
	# an emptied table would be `0 == 0` and every assertion below would simply stop running.
	# **It is the whole file now, not a chosen seventeen** — see `_every_function_is_in_the_table`.
	# It was 28 until `melee-legibility-ko`'s fork split `_paint_cell` into a dispatcher and two candidates
	# and added the two pure functions 갈래 ㄱ's stroke and nucleus are computed by (32), and 42 since 갈래 ㄴ
	# cut the three body loops out of `_paint` into one ordered pass with its own rim and its own gate.
	# **53 since §6's per-species gestures**: one dispatcher, seven gestures and the fallback.
	t.eq(FIELD_LEAF_CALLS.size(), 53, "field_view.gd에서 세는 함수는 쉰셋이다 — 그 파일의 함수 전부다")
	for name: String in FIELD_LEAF_CALLS:
		var want: int = int(FIELD_LEAF_CALLS[name])
		t.eq(_calls_in_func(text, name), want,
				"field_view.gd::%s 안의 draw_ 호출은 정확히 %d개다 — 잎은 비면 안 그리고, 0인 함수는 넘치면 안 된다"
						% [name, want])

	# **Invert the instrument, not only the subject.** A scanner that cannot see an emptied body reads
	# identical to one that can, so a fixture that fails IT is what says this block measures anything.
	var gutted := ("func _paint_dot(c, p, r, col):\n\tpass\n\n"
			+ "func _paint_arc(c, p, r):\n\tc.draw_arc(p, r)\n")
	t.eq(_calls_in_func(gutted, "_paint_dot"), 0, "속을 비운 가짜 잎은 0으로 세진다 (스캐너 자가 점검)")
	t.eq(_calls_in_func(gutted, "_paint_arc"), 1, "그 다음 함수까지 넘어가 세지는 않는다 (스캐너 자가 점검)")
	t.eq(_calls_in_func(gutted, "_paint_nothing"), -1, "없는 이름은 -1로 답한다 — 0과 구별된다 (자가 점검)")

	# A signature wrapped across two lines is the shape `_paint_outline` and `_paint_cone` actually have;
	# a scanner that started counting at the closing paren would find nothing in either.
	var wrapped := ("func _paint_outline(c: CanvasItem, p: Vector2, r: float, corner: float, col: Color,\n"
			+ "\t\twidth: float) -> void:\n\tvar pts := _blob(r, p, corner)\n"
			+ "\tc.draw_polyline(pts, col, width)\n")
	t.eq(_calls_in_func(wrapped, "_paint_outline"), 1, "줄이 접힌 서명도 제대로 읽는다 (스캐너 자가 점검)")

	# **The other direction, and it is the one the eight zeros are for.** A composer that grew a bare
	# `c.draw_*` has to come back as 1: a scanner that only ever caught an EMPTIED leaf would let a debug
	# circle sit at the top of `_paint` forever, which is exactly what this tree measured.
	var stray := ("func _paint(c):\n\tc.draw_circle(Vector2(50, 50), 300.0, Color.MAGENTA)\n"
			+ "\t_paint_disc(c, p, r, col)\n")
	t.eq(_calls_in_func(stray, "_paint"), 1,
			"짜맞추는 함수에 몰래 낀 draw_는 0이 아니라 1로 세진다 (스캐너 자가 점검)")


# -- hud.gd, one function at a time ----------------------------------------------------------------------
## The same instrument pointed at the HUD, and it carries a case the field's table cannot: **two functions
## that must draw NOTHING.** `_paint` composes the bar, the numbers and the map; `_paint_minimap` composes
## the map's four rectangles and its marks. Both used to be free to call `c.draw_rect` directly and did.
func _hud_leaves(t) -> void:
	var text := _read(HUD)
	t.ok(text != "", "%s를 읽었다" % HUD)
	# Hand-written, exactly like the 28 above and for the same reason.
	t.eq(HUD_LEAF_CALLS.size(), 12, "hud.gd에서 세는 함수는 열둘이다 — 그 파일의 함수 전부다")
	for name: String in HUD_LEAF_CALLS:
		var want: int = int(HUD_LEAF_CALLS[name])
		t.eq(_calls_in_func(text, name), want,
				"hud.gd::%s 안의 draw_ 호출은 정확히 %d개다 — 잎은 하나, 짜맞추는 함수는 0이다"
						% [name, want])

	# **Invert the instrument.** A 0 that cannot tell "empty" from "missing" would let a deleted
	# `_paint_minimap` read as a perfectly composed one, which is the whole claim the two zeros make.
	var composed := ("func _paint(c):\n\t_paint_rect(c, r, col)\n\t_paint_minimap(c, f, cam, m)\n\n"
			+ "func _paint_rect(c, r, col):\n\tc.draw_rect(r, col)\n")
	t.eq(_calls_in_func(composed, "_paint"), 0, "짜맞추기만 하는 가짜 함수는 0으로 세진다 (스캐너 자가 점검)")
	t.eq(_calls_in_func(composed, "_paint_minimap"), -1,
			"없어진 함수는 0이 아니라 -1이다 — 빈 함수와 구별된다 (스캐너 자가 점검)")
	t.eq(_calls_in_func(composed, "_paint_rect"), 1, "그 파일의 잎은 여전히 1로 세진다 (스캐너 자가 점검)")


# -- no function may sit outside its file's table --------------------------------------------------------
## **The residual hole the two tables above could not close by themselves, closed structurally.** Both are
## hand-written lists, and for a day `field_view.gd` had twenty-eight functions with seventeen named: the
## eleven outside were unscanned, and a bare `draw_circle` at the top of `_striking()` — reached from
## `_paint` every frame — painted over the play field with the whole round green and stderr clean. Adding
## the eleven fixes today; **this fixes tomorrow**, because the failure was never those eleven names, it was
## that a name could be absent at all.
##
## ⚠ **The direction matters.** `_field_view_leaves` walks the TABLE and asks the file; this walks the FILE
## and asks the table. Only the second one can see a function nobody listed, and only the first can see a
## listed function that was deleted or renamed — neither replaces the other, which is why both run.
func _every_function_is_in_the_table(t) -> void:
	for pair in [[FIELD_VIEW, FIELD_LEAF_CALLS], [HUD, HUD_LEAF_CALLS]]:
		var path: String = pair[0]
		var table: Dictionary = pair[1]
		var found := _funcs_in_file(_read(path))
		# The count is asserted against the table's own size rather than a second literal: the two literals
		# that pin the tables (28 and 11) are above, and a walk that found nothing would make every `has()`
		# below vacuous. This is the line that stops that.
		t.eq(found.size(), table.size(),
				"%s의 func는 %d개이고 표에 적힌 것도 %d개다 — 표 밖에 남은 함수는 안 세어진 함수다"
						% [path.get_file(), found.size(), table.size()])
		for name: String in found:
			t.ok(table.has(name),
					"%s::%s는 표에 있다 — 표에 없는 함수 안의 draw_는 아무도 안 본다" % [path.get_file(), name])

	# **Invert the instrument.** A walk that cannot see a function reads exactly like a file with none, so a
	# fixture that fails THIS scanner is what makes the assertions above mean anything.
	var three := ("func _paint(c):\n\t_paint_dot(c, p)\n\n"
			+ "func _paint_dot(c: CanvasItem, p: Vector2) -> void:\n\tc.draw_circle(p, 1.0, col)\n\n"
			+ "func _striking(sw: Swarm) -> bool:\n\treturn sw.count > 0\n")
	var got := _funcs_in_file(three)
	t.eq(got.size(), 3, "가짜 파일의 func 셋을 다 찾는다 (스캐너 자가 점검) %s" % str(got))
	t.ok(got.has("_striking"), "그 안에 표에 없을 법한 이름도 들어 있다 (스캐너 자가 점검)")
	# A `func` written inside a comment or a string must not become a name, or the scan reddens on prose.
	var prose := ("## a header sentence mentioning func _paint_ghost(c) in passing\n"
			+ "func _real(c):\n\tvar s := \"func _quoted(x)\"\n")
	var only := _funcs_in_file(prose)
	t.eq(only.size(), 1, "주석과 문자열 속 func는 함수로 세지 않는다 (스캐너 자가 점검) %s" % str(only))
	t.eq(only[0], "_real", "남는 것은 진짜 함수 이름 하나다 (스캐너 자가 점검)")


## Every top-level `func` NAME in one file, in file order. Comment lines are dropped first, exactly as
## `_calls_in_func` drops them, and only a line that STARTS with `func ` counts — an inner lambda or a
## quoted mention is not a function this scan can be asked about.
func _funcs_in_file(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for raw: String in text.split("\n"):
		if not raw.begins_with("func "):
			continue
		var rest := raw.substr(5)
		var open_at := rest.find("(")
		if open_at < 0:
			continue
		var name := rest.substr(0, open_at).strip_edges()
		if name != "":
			out.append(name)
	return out


# -- every leaf still USES what it was handed -----------------------------------------------------------
## The count says the draw call is there. This says the values reached it. See `LEAF_PARAMS`.
func _every_parameter_still_reaches_a_draw(t) -> void:
	# Hand-written, like every other count in this file: an emptied `LEAF_PARAMS` would run zero assertions
	# and read exactly like a clean scan, which is the same trap the two `size()` literals above exist for.
	var total := 0
	for path: String in LEAF_PARAMS:
		total += (LEAF_PARAMS[path] as Array).size()
	t.eq(total, 25, "인자가 살아 있는지 보는 잎은 스물다섯이다 — field_view 스물하나, hud 넷")

	for path: String in LEAF_PARAMS:
		var text := _read(path)
		t.ok(text != "", "%s를 읽었다 (인자 검사)" % path)
		for leaf: String in LEAF_PARAMS[path]:
			var params := _params_of(text, leaf)
			t.ok(params.size() >= 2,
					"%s::%s의 서명을 읽었다 — 인자가 %d개다" % [path.get_file(), leaf, params.size()])
			var body := _body_of(text, leaf)
			# `c` is the CanvasItem every leaf draws onto and it is asserted by the call count above, so the
			# scan starts at the second parameter: the ones that decide WHAT was drawn.
			for i in range(1, params.size()):
				t.ok(_mentions(body, params[i]),
						"%s::%s는 넘겨받은 %s를 여전히 쓴다 — 안 쓰면 그 값은 화면에 없다"
								% [path.get_file(), leaf, params[i]])

	# **Invert the instrument.** A scanner that cannot see a dropped argument reads identical to one that
	# can, so a fixture that fails IT is what makes the twelve assertions above mean anything.
	var gutted := "func _paint_disc(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:\n\tc.draw_circle(p, 0.0, col)\n"
	t.ok(not _mentions(_body_of(gutted, "_paint_disc"), "r"),
			"반지름을 0.0으로 바꿔 버린 가짜 잎은 r을 안 쓴 것으로 잡힌다 (스캐너 자가 점검)")
	t.ok(_mentions(_body_of(gutted, "_paint_disc"), "col"),
			"같은 가짜 잎에서 살아 있는 col은 쓴 것으로 잡힌다 (스캐너 자가 점검)")
	# A substring must not count: `r` inside `rot`, `range_px` or a string is not the parameter `r`.
	var shadowed := "func _paint_x(c, r):\n\tc.draw_circle(rot, corner, \"r\")\n"
	t.ok(not _mentions(_body_of(shadowed, "_paint_x"), "r"),
			"rot·corner 안의 r은 인자 r로 세지 않는다 — 부분 일치는 통과가 아니다 (스캐너 자가 점검)")
	# A comment naming the parameter must not keep it alive, which is the cheapest possible evasion.
	var commented := "func _paint_y(c, width):\n\t# width is ignored on purpose\n\tc.draw_line(a, b)\n"
	t.ok(not _mentions(_body_of(commented, "_paint_y"), "width"),
			"주석 속 이름은 인자를 살려 주지 않는다 (스캐너 자가 점검)")
	# The wrapped signature `_paint_outline` and `_paint_cone` actually have.
	var wrapped_sig := ("func _paint_cone(c: CanvasItem, p: Vector2, dir: Vector2, range_px: float,\n"
			+ "\t\tarc: float, col: Color) -> void:\n\tc.draw_colored_polygon(pts, col)\n")
	var wp := _params_of(wrapped_sig, "_paint_cone")
	t.eq(wp.size(), 6, "접힌 서명에서도 인자 여섯을 다 읽는다 (스캐너 자가 점검) %s" % str(wp))
	t.eq(wp[3], "range_px", "기본값과 타입을 떼고 이름만 남긴다 (스캐너 자가 점검)")
	var defaulted := _params_of("func _paint_cell(c, p, r, col, squash, rot = 0.0, corner = Look.CORNER):\n\tpass\n", "_paint_cell")
	t.eq(defaulted.size(), 7, "기본값이 달린 인자도 하나로 센다 (스캐너 자가 점검)")
	t.eq(defaulted[6], "corner", "기본값 뒤가 아니라 이름이 남는다 (스캐너 자가 점검)")


# -- one file holds every colour -------------------------------------------------------------------------
## The colour half of CLAUDE.md's unwritten `look.gd` scan. See `PALETTE_HOME`.
func _look_is_the_only_palette(t) -> void:
	var files := _gd_files("res://src")
	files.sort()
	# The literal, not `files.size()` read back — a walk that returned nothing would satisfy every
	# assertion under it and report a perfectly clean palette.
	t.eq(files.size(), PALETTE_SCANNED + 1,
			"src/ 아래 .gd는 열아홉이다 — look.gd 하나와 뒤지는 열여덟 %d" % files.size())
	var scanned := 0
	for path: String in files:
		if path == PALETTE_HOME:
			continue
		scanned += 1
		var n := _colour_literals(_read(path))
		t.eq(n, 0, "%s 안에 색 리터럴은 없다 — 색은 look.gd 한 곳에만 산다 (%d개)" % [path.get_file(), n])
	t.eq(scanned, PALETTE_SCANNED, "look.gd를 뺀 열여덟 파일을 빠짐없이 다 뒤졌다")
	# The home file must actually HOLD the palette, or "nowhere else has a colour" is true of an empty repo.
	t.ok(_colour_literals(_read(PALETTE_HOME)) > 40,
			"그리고 look.gd에는 색이 실제로 마흔 개 넘게 들어 있다 — 아무 데도 없는 것과 구별된다")

	# **Invert the instrument.** Both forms, and a comment that must not count.
	t.eq(_colour_literals("var x := Color(0.1, 0.2, 0.3)\n"), 1, "Color(...)는 잡힌다 (스캐너 자가 점검)")
	t.eq(_colour_literals("\tc.draw_rect(r, Color.MAGENTA)\n"), 1, "Color.MAGENTA도 잡힌다 (스캐너 자가 점검)")
	t.eq(_colour_literals("## a Color(0,0,0) mentioned in prose\n"), 0,
			"주석 속 Color는 세지 않는다 (스캐너 자가 점검)")
	t.eq(_colour_literals("var c: Color = other\n"), 0,
			"타입으로 쓴 Color는 리터럴이 아니다 (스캐너 자가 점검)")


## Every `.gd` under `dir`, recursively. `res://` paths, so `_read()` takes them unchanged.
func _gd_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir.path_join(name)
		if d.current_is_dir():
			out.append_array(_gd_files(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
	return out


func _colour_literals(text: String) -> int:
	var n := 0
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		for m in _colour_literal.search_all(line):
			n += 1
	return n


## The parameter NAMES of one function, types and defaults stripped, signature unwrapped.
## Empty when the function is not there.
func _params_of(text: String, func_name: String) -> PackedStringArray:
	var out := PackedStringArray()
	var at := text.find("func %s(" % func_name)
	if at < 0:
		return out
	var open_at := text.find("(", at)
	var depth := 0
	var i := open_at
	var raw := ""
	while i < text.length():
		var ch := text[i]
		if ch == "(" or ch == "[" or ch == "{":
			depth += 1
			if depth == 1:
				i += 1
				continue
		elif ch == ")" or ch == "]" or ch == "}":
			depth -= 1
			if depth == 0:
				break
		raw += ch
		i += 1
	for piece: String in _split_top(raw):
		var name := piece.strip_edges()
		# `rot: float = 0.0` and `rot = 0.0` alike: the name is everything before the first `:` or `=`.
		for cut in [":", "="]:
			var c := name.find(cut)
			if c >= 0:
				name = name.substr(0, c)
		name = name.strip_edges()
		if name != "":
			out.append(name)
	return out


## Split on commas that are not inside brackets — a default of `Vector2(0, 0)` is one parameter, not two.
func _split_top(raw: String) -> PackedStringArray:
	var out := PackedStringArray()
	var depth := 0
	var cur := ""
	for i in raw.length():
		var ch := raw[i]
		if ch == "(" or ch == "[" or ch == "{":
			depth += 1
		elif ch == ")" or ch == "]" or ch == "}":
			depth -= 1
		if ch == "," and depth == 0:
			out.append(cur)
			cur = ""
			continue
		cur += ch
	out.append(cur)
	return out


## One function's body with every comment line dropped — `func` line to the next top-level `func`.
func _body_of(text: String, func_name: String) -> String:
	var lines := text.split("\n")
	var inside := false
	var out := ""
	var signature_open := 0
	for raw: String in lines:
		if raw.begins_with("func %s(" % func_name):
			inside = true
			# A wrapped signature spills onto the next line; skip until its parens balance.
			signature_open = raw.count("(") - raw.count(")")
			continue
		if not inside:
			continue
		if raw.begins_with("func "):
			break
		if signature_open > 0:
			signature_open += raw.count("(") - raw.count(")")
			continue
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		out += line + "\n"
	return out


## Is `name` used as a whole word — `r` must not match inside `rot`, `corner` or a quoted string.
func _mentions(body: String, name: String) -> bool:
	var stripped := ""
	var in_str := false
	var quote := ""
	for i in body.length():
		var ch := body[i]
		if in_str:
			if ch == quote:
				in_str = false
			continue
		if ch == "\"" or ch == "'":
			in_str = true
			quote = ch
			continue
		stripped += ch
	var re := RegEx.new()
	re.compile("(^|[^A-Za-z0-9_])%s([^A-Za-z0-9_]|$)" % name)
	return re.search(stripped) != null


## `draw_*` call lines inside one function's body: from its `func` line to the next top-level `func`.
## **-1 when the function is not there at all**, so a renamed leaf is red rather than silently zero.
func _calls_in_func(text: String, func_name: String) -> int:
	var lines := text.split("\n")
	var inside := false
	var n := -1
	for raw: String in lines:
		if raw.begins_with("func %s(" % func_name):
			inside = true
			n = 0
			continue
		if inside and raw.begins_with("func "):
			break
		if not inside:
			continue
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		if _draw_call.search(line) != null:
			n += 1
	return n


## Real call sites only. A line is a comment (and skipped) if its trimmed content begins with `#` — the
## same classification `net_citations.gd` uses. **The whole file is scanned, not a truncated slice** —
## `CLAUDE.md`: a truncated search silently drops the one hit that matters.
func _count_draw_calls(text: String) -> int:
	var n := 0
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		if _draw_call.search(line) != null:
			n += 1
	return n


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()
