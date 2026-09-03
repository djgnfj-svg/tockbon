extends RefCounted
## Dead citations. `CLAUDE.md` names this the first net worth rebuilding, and it needs no game — only text.
##
## Three shapes are forbidden in `src/`, `tests/` and `tools/`:
##  · a path into the plans folder — that folder IS the status, so the path dies the day the doc moves
##  · **any path to a doc at all** — this repo DELETES a doc the moment it stops being true, so a
##    citation points at nothing while still reading as precise. Name the doc, never its path.
##    This half was honour-based while the plans half was scanned, and it rotted in two files
##  · a `file.gd:NNN` line number — adding four lines to a header killed ten citations at once
##
## **The scan joins wrapped comment lines two ways before matching.** Joining on spaces alone is the exact
## defect this net exists to catch, shipped inside the net itself: a path wrapped mid-token
## (`docs/pl` + newline + `ans/1.ready`) survives a space-join and stays invisible. The line-wise version
## of this scan passed **three of eleven** cases.
##
## The forbidden patterns are assembled from pieces below so that this file does not fail its own scan.
##
## ⇒ **`docs/` and `CLAUDE.md` are scanned too, for the line-number form only, and until this net was
## widened they were outside its reach entirely.** Four `name.gd:NNN` citations were live in the docs and
## **two of them were the ones the rule itself is written about** — the same "a scan scoped to where the
## bug was found is scoped too narrowly" note this repo already records about `tools/`.
##
## ⚠ **Only the line-number form.** A doc PATH is legitimate in a doc — `plans/README.md` and the design
## index exist to link to files, and CLAUDE.md's own table names them. What is never legitimate anywhere is
## a line number, because a line number is a path into a file and four lines added to a header kill ten at
## once.
##
## ⚠ **The skip list is gone, and nothing is exempt.** It named the dated adversarial reviews, which quoted
## offending citations verbatim as findings — and every one of those files was deleted with the two dead
## games. An exemption that covers no file is not an exception to the scan, it is a hole in it, exactly as
## this net already recorded when `gap-check-` was granted the same exemption and bought nothing. The two
## checks that guarded the list went with it: they asserted a skip actually fired, and a skip that can never
## fire cannot be asserted honestly. **Narrowing the instrument, not the subject.**
const ROOTS := ["res://src", "res://tests", "res://tools"]
const DOC_ROOTS := ["res://docs"]
const LOOSE_DOCS := ["res://CLAUDE.md", "res://README.md"]

# Assembled, never written whole: a literal here would make this file its own first offender.
const PLANS := "docs/pl" + "ans/"
const GD_COLON := "\\.gd:[0-9]+"
## Any doc path, not only a plans one. Assembled the same way and for the same reason.
const DOC_MD := "do" + "cs/[A-Za-z0-9_./-]+\\.md"


func run(t) -> void:
	var files := _gd_files()
	t.ok(files.size() > 0, "스캔할 .gd 파일을 찾았다 (%d개)" % files.size())

	var bad_path: Array[String] = []
	var bad_doc: Array[String] = []
	var bad_line: Array[String] = []
	var line_re := RegEx.new()
	line_re.compile("[A-Za-z0-9_]" + GD_COLON)
	var doc_re := RegEx.new()
	doc_re.compile(DOC_MD)

	for f: String in files:
		var text := _read(f)
		for joined: String in _join_comments(text):
			if joined.contains(PLANS + "1.") or joined.contains(PLANS + "2.") or joined.contains(PLANS + "3."):
				bad_path.append(f)
			if doc_re.search(joined) != null:
				bad_doc.append(f)
			if line_re.search(joined) != null:
				bad_line.append(f)

	t.eq(bad_path.size(), 0, "plans 폴더 경로를 박아둔 인용이 없다 %s" % str(bad_path))
	t.eq(bad_doc.size(), 0, "문서 경로를 박아둔 인용이 없다 — 이름만 부른다 %s" % str(bad_doc))
	t.eq(bad_line.size(), 0, "파일:줄번호 인용이 없다 %s" % str(bad_line))

	_tools_still_parse(t)

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

	# The doc-path half needs its own failing fixture for the same reason: a regex that never matches reads
	# identical to one that does, and this one is new.
	var wrapped_doc := "## the unit is 경험치 — see do\n## cs/design/hunting-and-the-boss-ko.md\n"
	var hit_doc := false
	for joined: String in _join_comments(wrapped_doc):
		if doc_re.search(joined) != null:
			hit_doc = true
	t.ok(hit_doc, "문서 경로가 두 줄에 걸쳐 있어도 잡는다 (스캐너 자가 점검)")

	var wrapped_line := "## measured in swarm\n## .gd:118, the separation pass\n"
	var hit_line := false
	for joined: String in _join_comments(wrapped_line):
		if line_re.search(joined) != null:
			hit_line = true
	t.ok(hit_line, "줄번호 인용이 두 줄에 걸쳐 있어도 잡는다")

	_docs_carry_no_line_numbers(t, line_re)


# -- the docs half ---------------------------------------------------------------------------------------
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies
	# half way still reports every check it managed first, in a shape a healthy net cannot be told from.
	t.done()

## See the header. Prose, not comments, so the whole file is scanned and consecutive non-blank lines are
## joined the same two ways — a citation wrapped across a line break in Markdown is the same shape.
func _docs_carry_no_line_numbers(t, line_re: RegEx) -> void:
	var docs := _md_files()
	# The literal, not `docs.size()` read back: a walk that found nothing would report a perfectly clean
	# docs tree and every assertion below would simply stop running. The floor was 40 while the tree held
	# sixty-odd docs about two dead games, then 18. On 2026-08-22 ten design docs, seven plans and the
	# whole `docs/plans/` index were deleted and the GDD went from 108,927 characters to 1,574, so the
	# floor moves with the tree again. It is still a hand-written number and never `docs.size()`.
	t.ok(docs.size() >= 14, "스캔할 문서를 찾았다 (%d개, 최소 14)" % docs.size())
	var bad: Array[String] = []
	for f: String in docs:
		for joined: String in _join_prose(_read(f)):
			if line_re.search(joined) != null:
				bad.append(f)
	t.eq(bad.size(), 0, "문서에도 파일:줄번호 인용이 없다 — 이름을 부르지 줄을 세지 않는다 %s" % str(bad))

	# **Invert the instrument.** A prose joiner that never matched would read identical to a clean tree, and
	# the skip list has to be a hole in exactly one direction.
	var hit := false
	for joined: String in _join_prose("the fix is in world\n.gd:206, the peak line\n"):
		if line_re.search(joined) != null:
			hit = true
	t.ok(hit, "산문에서 두 줄에 걸친 줄번호도 잡는다 (스캐너 자가 점검)")
	var plain := false
	for joined: String in _join_prose("see `rules.gd:68-71` for the measurement\n"):
		if line_re.search(joined) != null:
			plain = true
	t.ok(plain, "한 줄짜리 줄번호도 잡는다 (스캐너 자가 점검)")
	var clean := false
	for joined: String in _join_prose("see `rules.gd`'s `FORCE_START` for the measurement\n"):
		if line_re.search(joined) != null:
			clean = true
	t.ok(not clean, "이름만 부른 인용은 안 잡는다 — 전부 빨개지는 스캐너가 아니다 (스캐너 자가 점검)")


## Every consecutive run of non-blank lines, space-joined AND tight-joined. Markdown has no comment marker,
## so `_join_comments`'s `#` test would read a heading as the only prose in the file.
func _join_prose(text: String) -> Array[String]:
	var out: Array[String] = []
	var space_join := ""
	var tight_join := ""
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line != "":
			space_join += (" " if space_join != "" else "") + line
			tight_join += line
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


func _md_files() -> Array[String]:
	var out: Array[String] = []
	for root: String in DOC_ROOTS:
		_walk_md(root, out)
	for f: String in LOOSE_DOCS:
		if FileAccess.file_exists(f):
			out.append(f)
	return out


func _walk_md(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".md"):
			out.append(dir_path.path_join(f))
	for sub: String in d.get_directories():
		_walk_md(dir_path.path_join(sub), out)


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


## ⚠⚠ **`tools/` is loaded by nothing at all, and a round can be green over a dead instrument.**
## Measured 2026-08-18: `plan-then-watch` deleted `Rules.boat_count`, `Rules.cap_of`,
## `battle.load_soldier`, `battle.pending` and `battle.launch`, and `tools/probe/run_run.gd` — which drove
## every one of them — stopped parsing outright. **The round stayed green at 1262 checks**, because the
## runner loads `res://tests/nets/` and nothing else, and this file read `tools/` as TEXT (citation shapes)
## and never as CODE. The probe is what `CLAUDE.md` names as the instrument for turning 「애매하다」 into a
## number, and three acceptance rows of the plan are scored by it.
##
## ⇒ **Every `.gd` under `tools/` is LOADED here.** ⚠ **Loading is not running**: these files
## `extend SceneTree` and are never instantiated, so nothing here opens a window or plays a run.
##
## ⚠⚠ **`load() == null` WAS THE CHECK AND IT CAUGHT NOTHING — MEASURED, NOT ARGUED** (2026-08-27).
## This header claimed 「A parse error makes `load()` return null」 and `tests/README.md` said the
## opposite; **the README was right.** A file with a dangling `+`, and a second one calling a class
## that does not exist, were both planted under `tools/` and loaded on 4.7.1:
##
##   `ResourceLoader.load(broken) == null` -> **false** (a `GDScript` object comes back either way)
##   `(load(broken) as GDScript).can_instantiate()` -> **false**
##
## So this green said "every tool script parses" while only proving **the files exist**. ⇒ **The check
## is `can_instantiate()` now**, and it was watched going red on both planted files before they were
## removed. **The engine still barks 「Failed to load script ... Parse error」 on stderr**, which the
## runner's silence check catches separately — that half of the old header was true.
##
## ⚠ **Loading is still not enough on its own** — a file emptied to `extends SceneTree` compiles
## perfectly. There used to be a second half here that pinned the probe's shape by naming its two
## functions, so an API deletion leaving a stub behind would redden. **That probe was deleted with the
## map (2026-08-26) and the naming went with it**; nothing in this net pins a shape today.
func _tools_still_parse(t) -> void:
	var tool_files: Array[String] = []
	_walk("res://tools", tool_files)
	t.ok(tool_files.size() >= 2, "tools/ 아래 .gd 를 찾았다 (%d개, 최소 2)" % tool_files.size())
	var unloadable: Array[String] = []
	for f: String in tool_files:
		var script := ResourceLoader.load(f) as GDScript
		# ⚠⚠ **`== null` IS NOT THE PARSE TEST.** The loader returns the GDScript whether or not its
		# source compiled; `can_instantiate()` is the one that goes false on a compile failure.
		if script == null or not script.can_instantiate():
			unloadable.append(f)
	t.eq(unloadable.size(), 0,
		"tools/ 의 .gd 가 전부 컴파일된다 — 아무 넷도 안 부르는 파일이라 여기서만 잡힌다 %s" % str(unloadable))
	# ⚠⚠ **세 줄이 여기서 삭제됐다** (2026-08-26): 회차를 자동으로 돌리던 프로브가 지도와 함께 지워졌고,
	# 그 셋이 재던 것은 **「전투 중에 손이 움직이지 않는다」**였다. 그 규칙 자체를 사용자가 2026-08-25 에
	# 뒤집었으므로(티켓 25) 검사를 되살릴 자리가 없다.


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
