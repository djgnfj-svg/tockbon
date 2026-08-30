# **What line does a body actually walk?** A throwaway probe, not a net.
#
# Drives `Grid.flow_field` + `Grid.step_toward` on an empty board and prints the 조각 a body steps
# through, so 「이상하게 간다」 can be looked at as a list instead of remembered from a screen.
#
# ⚠⚠ **IT USED TO MEASURE THE WRONG THING** (fixed with 티켓 37). It called `step_toward` with three
# arguments, so the tie-break's deviation keys — the whole of what makes a walk straight — were switched
# off inside the very instrument the acceptance is read from, and it never touched `string_pull` at all.
# **It passes the target 조각 now, and prints the string-pulled route beside the raw descent.**
#
#   Godot_v4.7.1-stable_win64.exe --headless --path . -s .prototypes/stairs/walk_probe.gd
extends SceneTree


func _initialize() -> void:
	_run("straight east", 24, 12, Vector2i(2, 6), Vector2i(20, 6))
	_run("a knight's angle", 24, 12, Vector2i(2, 10), Vector2i(20, 2))
	_run("shallow angle", 24, 12, Vector2i(2, 9), Vector2i(20, 6))
	_run("dead diagonal", 24, 12, Vector2i(2, 2), Vector2i(14, 14 - 4))
	quit()


func _run(what: String, w: int, h: int, from: Vector2i, to: Vector2i) -> void:
	var rows: Array = []
	for y in h:
		rows.append(".".repeat(w))
	var grid := Grid.new()
	grid.load_rows(rows, [])
	var target := to.y * w + to.x
	var field := grid.flow_field(target)

	# The raw descent: one `step_toward` at a time, with the target passed so the deviation keys are on.
	var at := Vector2(from)
	var path: Array = [from]
	for _step in 200:
		var next := grid.step_toward(0, at, field, -1, target)
		if next.is_equal_approx(at):
			break
		at = next
		path.append(Vector2i(at))
		if Vector2i(at) == to:
			break
	grid.release_all(0)

	# The straightened route the body is actually handed, off the same field.
	var pulled_tiles := grid.string_pull(grid.path_from(field, from.y * w + from.x, target))
	var pulled: Array = []
	for raw in pulled_tiles:
		pulled.append(Vector2i(int(raw) % w, int(raw) / w))

	print("%s  %s -> %s" % [what, from, to])
	_report(grid, w, "   raw descent  ", from, to, path)
	_report(grid, w, "   string-pulled", from, to, pulled)
	# The same walk drawn on the board, so the shape is visible rather than counted.
	var mark: Array = []
	for y in h:
		mark.append(".".repeat(w).split(""))
	for p: Vector2i in path:
		mark[p.y][p.x] = "o"
	mark[from.y][from.x] = "A"
	mark[to.y][to.x] = "B"
	for y in h:
		print("   " + "".join(mark[y]))
	print("")


## One route's three numbers: how many 조각, how many turns, and how far off its own straight segment the
## worst 조각 stands — plus its cost in the field's own units, which is what 「never longer」 is read off.
func _report(grid: Grid, w: int, label: String, from: Vector2i, to: Vector2i, path: Array) -> void:
	if path.is_empty():
		print("%s : (empty)" % label)
		return
	var turns := 0
	for i in range(2, path.size()):
		var a: Vector2i = path[i - 1] - path[i - 2]
		var b: Vector2i = path[i] - path[i - 1]
		if a != b:
			turns += 1
	var cost := 0
	for i in range(1, path.size()):
		var a: Vector2i = path[i - 1]
		var b: Vector2i = path[i]
		cost += grid.step_cost(a.y * w + a.x, b.y * w + b.x)
	var d := Vector2(to - from)
	var worst := 0.0
	for raw in path:
		var p: Vector2i = raw
		var v := Vector2(p - from)
		worst = maxf(worst, absf(v.x * d.y - v.y * d.x) / d.length())
	var line := ""
	for raw2 in path:
		var p2: Vector2i = raw2
		line += "(%d,%d) " % [p2.x, p2.y]
	print("%s : %d 조각, 꺾임 %d, 직선에서 최대 %.2f, 값 %d" % [label, path.size(), turns, worst, cost])
	print("        " + line)
