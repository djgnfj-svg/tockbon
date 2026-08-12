extends RefCounted
## Dead citations. `CLAUDE.md` names this the first net worth rebuilding, and it needs no game — only text.
##
## Two shapes are forbidden in `src/`, `tests/` and `tools/`:
##  · a path into `docs/plans/` — that folder IS the status, so the path dies the day the doc moves
##  · a `file.gd:NNN` line number — adding four lines to a header killed ten citations at once
##
## **The scan joins wrapped comment lines two ways before matching.** Joining on spaces alone is the exact
## defect this net exists to catch, shipped inside the net itself: a path wrapped mid-token
## (`docs/pl` + newline + `ans/1.ready`) survives a space-join and stays invisible. The line-wise version
## of this scan passed **three of eleven** cases.
##
## The forbidden patterns are assembled from pieces below so that this file does not fail its own scan.

const ROOTS := ["res://src", "res://tests", "res://tools"]

# Assembled, never written whole: a literal here would make this file its own first offender.
const PLANS := "docs/pl" + "ans/"
const GD_COLON := "\\.gd:[0-9]+"


func run(t) -> void:
	var files := _gd_files()
	t.ok(files.size() > 0, "스캔할 .gd 파일을 찾았다 (%d개)" % files.size())

	var bad_path: Array[String] = []
	var bad_line: Array[String] = []
	var line_re := RegEx.new()
	line_re.compile("[A-Za-z0-9_]" + GD_COLON)

	for f: String in files:
		var text := _read(f)
		for joined: String in _join_comments(text):
			if joined.contains(PLANS + "1.") or joined.contains(PLANS + "2.") or joined.contains(PLANS + "3."):
				bad_path.append(f)
			if line_re.search(joined) != null:
				bad_line.append(f)

	t.eq(bad_path.size(), 0, "plans 폴더 경로를 박아둔 인용이 없다 %s" % str(bad_path))
	t.eq(bad_line.size(), 0, "파일:줄번호 인용이 없다 %s" % str(bad_line))

	# **Inverting the instrument, not only the subject.** A scanner for wrapped citations that joins on
	# spaces cannot see a mid-token wrap — the one shape it exists to find. These two synthetic files feed
	# the joiner directly: if it ever regresses to a line-wise or space-only join, this goes red while the
	# real tree above stays clean and quiet.
	var wrapped := "## see docs/pl\n## ans/1.ready/proto.md for the rest\n"
	var hit_wrapped := false
	for joined: String in _join_comments(wrapped):
		if joined.contains(PLANS + "1."):
			hit_wrapped = true
	t.ok(hit_wrapped, "주석 줄을 넘어 쪼개진 경로도 잡는다 (토큰 중간에서 끊긴 것)")

	var wrapped_line := "## measured in swarm\n## .gd:118, the separation pass\n"
	var hit_line := false
	for joined: String in _join_comments(wrapped_line):
		if line_re.search(joined) != null:
			hit_line = true
	t.ok(hit_line, "줄번호 인용이 두 줄에 걸쳐 있어도 잡는다")


## Every consecutive run of comment lines, returned BOTH space-joined and tight-joined. Two strings per
## run, because each join hides what the other one finds.
func _join_comments(text: String) -> Array[String]:
	var out: Array[String] = []
	var space_join := ""
	var tight_join := ""
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			var body := line.lstrip("#").strip_edges()
			space_join += (" " if space_join != "" else "") + body
			tight_join += body
			continue
		if space_join != "":
			out.append(space_join)
			out.append(tight_join)
			space_join = ""
			tight_join = ""
	if space_join != "":
		out.append(space_join)
		out.append(tight_join)
	return out


func _gd_files() -> Array[String]:
	var out: Array[String] = []
	for root: String in ROOTS:
		_walk(root, out)
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
