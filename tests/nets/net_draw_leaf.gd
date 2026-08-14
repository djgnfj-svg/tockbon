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
## ⚠ **`hud.gd` is still OUT**, and the list's size is not coverage of `src/view/`. `hud.gd` calls
## `draw_rect` twice and `draw_circle` once outside its leaves; it needs its own shape of scan.
##
## ⇒ **`field_view.gd` cannot live under a file-wide bound of two — it gets the OTHER shape of scan,
## per function**, and it needs one for a measured reason. Its leaves are spied by `net_paint` and a spy
## sees the hook being CALLED, never the native call inside it: `c.draw_circle` in `_paint_dot` and
## `c.draw_polyline` in `_paint_outline` were each replaced with `pass` and the whole round stayed green
## at 846 checks, stderr clean. Headless has no pixels to read back, so the only thing left that can see
## an emptied leaf is its own text — and the count is pinned per function so that adding a bare
## `c.draw_*` somewhere it does not belong is red too.
##
## **Comment lines are excluded before counting** — a header sentence describing the contract (this file's
## own, or either screen's) freely writes `c.draw_rect` in prose, and that must not count as a violation.

const SCOPED_FILES := ["res://src/view/title_screen.gd", "res://src/view/ending_screen.gd",
		"res://src/view/body_panel.gd", "res://src/view/card_panel.gd"]
const MAX_CALLS := 2

## `field_view.gd`, per function: how many `draw_*` call lines that function's body is allowed to hold,
## exactly. Six leaves at one call each, and `_paint_cell` at seven (three polygons and four
## `draw_set_transform`) — pinned rather than bounded, because "at most" cannot see a leaf going empty and
## that is the failure this whole block exists for.
const FIELD_VIEW := "res://src/view/field_view.gd"
const FIELD_LEAF_CALLS := {
	"_paint_part_shape": 1,
	"_paint_part_line": 1,
	"_paint_outline": 1,
	"_paint_dot": 1,
	"_paint_arc": 1,
	"_paint_cone": 1,
	"_paint_cell": 7,
}

var _draw_call := RegEx.new()


func run(t) -> void:
	_draw_call.compile("draw_[A-Za-z_]+\\s*\\(")

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


# -- field_view.gd, one function at a time ---------------------------------------------------------------
## A spy that overrides `_paint_dot` sees the hook being called; it never sees the `draw_circle` inside it.
## Measured on this tree: emptying that call and `_paint_outline`'s `draw_polyline` left 846 checks green.
func _field_view_leaves(t) -> void:
	var text := _read(FIELD_VIEW)
	t.ok(text != "", "%s를 읽었다" % FIELD_VIEW)
	# The literal 7, hand-written like `SCOPED_FILES.size()` above: read back off the dictionary it guards,
	# an emptied table would be `0 == 0` and every assertion below would simply stop running.
	t.eq(FIELD_LEAF_CALLS.size(), 7, "field_view.gd에서 세는 함수는 일곱이다")
	for name: String in FIELD_LEAF_CALLS:
		var want: int = int(FIELD_LEAF_CALLS[name])
		t.eq(_calls_in_func(text, name), want,
				"field_view.gd::%s 안의 draw_ 호출은 정확히 %d개다 — 비면 그 잎은 아무것도 안 그린다"
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
