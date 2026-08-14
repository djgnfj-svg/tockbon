extends RefCounted
## Enforces the two-leaf draw contract `title_screen.gd` and `ending_screen.gd` each document in their own
## header: `_paint_rect`/`_paint_text` are the ONLY places `draw_rect`/`draw_string`/any other native
## `draw_*` may be called. Two rounds of `net_screens.gd` were rebuilt around a spy that watches exactly
## those two hooks — nothing stopped a fifth call site from quietly reopening the hole either round closed.
## This is that stop, the same shape `net_citations.gd` is for its own citation forms.
##
## **Scoped to the files that make the claim, not every file under `src/view/`.** `hud.gd`, `card_panel.gd`
## and `field_view.gd` call `draw_*` directly in five to nine places each — none of them adopted this
## convention, and retrofitting them is out of scope for this plan (the run shell plan's own Out-of-scope
## section names exactly this: "Retrofitting hud.gd / card_panel.gd / field_view.gd's ... colours into
## look.gd"). Scanning them here would be inventing a rule they never agreed to and turning the round red
## over work nobody asked for this round. `SCOPED_FILES` is the list; a file joins it the day its own
## header states the same two-leaf contract these two do — **`body_panel.gd` states it verbatim and was
## left out anyway.** That is how plan 3, filling the eleven slots, would have put a third bare
## `c.draw_*` straight into `_paint_slot`, where the panel's own spy cannot see it and every rectangle
## check about it stays green.
##
## **Comment lines are excluded before counting** — a header sentence describing the contract (this file's
## own, or either screen's) freely writes `c.draw_rect` in prose, and that must not count as a violation.

const SCOPED_FILES := ["res://src/view/title_screen.gd", "res://src/view/ending_screen.gd",
		"res://src/view/body_panel.gd"]
const MAX_CALLS := 2

var _draw_call := RegEx.new()


func run(t) -> void:
	_draw_call.compile("draw_[A-Za-z_]+\\s*\\(")

	# The literal 3, not `SCOPED_FILES.size()` read back — `checked == SCOPED_FILES.size()` is `0 == 0`
	# if the list is ever emptied, and the two synthetic self-checks below still run either way, so the
	# runner's own zero-check detector never fires. A bound taken from the list it is meant to guard.
	# **Hand-written on purpose: it has to move with the list, every time.**
	t.eq(SCOPED_FILES.size(), 3,
			"감시 대상 목록이 비어 있지 않다 (title_screen.gd, ending_screen.gd, body_panel.gd)")

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
