extends RefCounted
## **Doc citations in code comments — do they still point at something.** CLAUDE.md's "Comments" rule:
## *name a doc; never path it, never line-number it*, because a doc under `docs/plans/` changes folders with
## its status and the path dies that day.
##
## ══ Why grep is the right instrument **here**, and only here ══
##
## CLAUDE.md lists "a check that greps a file measures its text, never what it computes" as a fake-net shape,
## and this file is a grep. **That is not a contradiction, and the distinction is the whole reason this net
## is allowed to exist**: there, grep was standing in for *behaviour* — five scans shipped in one feature and
## every one was evaded, because the thing being measured (what the code does) is not the thing being read
## (what the file says). **Here the rule being enforced IS a text rule about comments.** A citation is text
## and nothing but text; there is no behaviour behind it to drive instead. Reading the text is not a proxy
## for the property — it *is* the property.
##
## ⇒ **Do not delete this net citing that rule.** If you are about to, read this box first.
##
## ══ Why it exists at all ══
##
## **The rule was honour-based and honour did not hold.** In one night the same leak class was found **five
## separate times, each by someone other than whoever caused it** — and two citations survived **four** hand
## sweeps, being caught only on the fifth. They had been dead since long before that night.
## **Both were invisible to every sweep for the same reason**: the citation **wrapped across two `##` lines**,
## so a line-wise grep never matched it. A scan that catches 8 of 11 is worse than no scan, because it looks
## like coverage and licenses everyone to stop sweeping by hand.
##
## ══ Scope: `src/` and `tests/` only — **`docs/` is deliberately not scanned** ══
##
## Docs quote dead paths **on purpose**, as the record of a leak that was already fixed:
## `plans/3.done/gate-ending-to-game.md` has a numbered findings list whose item 4 is literally
## *"Links to `../plans/1.ready/run-end-settlement.md` — that doc is in `3.done/` now… No action."*
## Flagging that would be flagging a doc for correctly recording history, and the only way to keep the net
## green would be to delete the history. **Comments are instructions to the next reader; docs are also a
## record.** The rule is about the first.

## **`tools/` is in scope too, and it was not at first.** This net was built scoped to where the bug had
## been found — and within hours a dead citation turned up in `tools/`, caught by hand because nothing was
## watching there. **A rule enforced over two of the three folders that hold comments is a rule with a
## documented hole.** The cost is nothing: the scan is text over ~90 files and runs in well under a second.
## **And the same hole opened a second time, the day the submission tools moved.** They went from `tools/`
## into `docs/archive/nan2026/tools/`, and `docs/` is excluded on purpose (the box above) — so a folder of
## live `.gd` walked out of scope in a `git mv` with nothing barking. **The exclusion is about docs being a
## record, not about the string `docs/`**: comments in a script are instructions to the next reader wherever
## the script sits. ⇒ **scan by what the file is, not by where it lives.**
const SCAN_DIRS: Array[String] = [
	"res://src", "res://tests", "res://tools", "res://docs/archive/nan2026/tools",
]
const DOCS_DIR := "res://docs"

## ══ There is no ceiling constant any more. The answer is zero. ══
##
## **It began as a ratchet and it has been burned down.** The history is kept because the number moving is
## the whole story:
##
##  · **It shipped at 56**, grandfathering every path-form citation that existed, because a net that lands
##    red on 56 sites on day one is a net somebody deletes or weakens within the hour. Every *new* one went
##    red immediately; the old ones were to be cleaned up over time.
##  · **56 was itself a finding.** Every hand scan run the night it was written — including the one used to
##    size the ceiling — reported **53**, because they all joined comment lines with a space and **three
##    citations wrapped mid-token**. They were never dead, only invisible: the same blind spot that let two
##    genuinely dead ones survive four sweeps. The count did not rise because anyone added a citation; it
##    rose because the scanner stopped being blind.
##  · **It fired on its first real day**, at 57 — on a citation that **resolved perfectly well**, written by
##    a track that had no way to know the rule had changed. Not a dead link caught late: **a live one caught
##    at the moment of writing**, which is the case honour never catches, because nothing is wrong with it
##    yet. Three weeks later it would have been dead and swept for by hand a sixth time.
##  · Then all 57 were rewritten as names, and the ceiling reached 0.
##
## **At zero the grandfathering clause and the rule say the same thing, so the constant is gone** — there is
## no number left to maintain, and no way for the bound to drift away from reality unnoticed.
##
## ⚠ **The count check itself is NOT gone, and must not be deleted as bookkeeping.** It is the only thing
## that catches a **new, perfectly valid** path-form citation. `_every_path_form_citation_resolves_where_it_says`
## below cannot: that one only fires once the doc has *moved*, which is weeks after the mistake and after
## somebody has already gone looking by hand. **The two checks answer different questions** — one asks "is
## this citation broken yet", the other asks "was the rule followed". Today's catch was the second.


func run(t) -> void:
	_the_scanner_rejoins_wrapped_comment_lines(t)
	_the_scanner_sees_a_line_number_citation(t)
	_the_doc_index_found_the_docs(t)
	_every_path_form_citation_resolves_where_it_says(t)
	_every_bare_name_citation_resolves_to_a_real_doc(t)
	_there_are_no_path_form_citations_at_all(t)
	_there_are_no_line_number_citations(t)
	_the_living_docs_carry_no_line_numbers_either(t)


## **The instrument, measured before anything it measures.** A line-wise scan passed three of eleven dead
## citations because the path wrapped across two `##` lines, so this net's own rejoin is the thing most
## worth breaking. Driven on a synthetic block rather than on the repo: the repo's real wrapped citations
## are all valid now, so the repo cannot prove the rejoin works — only that nothing is currently wrong.
##
## *Inversion: make `_comment_blocks` join with "" instead of " ", or stop joining at all, and the second
## assert goes red.*
func _the_scanner_rejoins_wrapped_comment_lines(t) -> void:
	# **Both wrap shapes, because one join catches one of them and the other catches the other.**
	#  A: breaks mid-token, right after a slash — rejoining must NOT insert a space.
	var a1 := "## the numbers are in the plan at docs/plans/"
	var a2 := "## 3.done/stage1-bosses.md, not here"
	#  B: breaks between words — rejoining MUST insert a space, or `at` and `docs` glue into `atdocs`.
	var b1 := "## the numbers are in the plan at"
	var b2 := "## docs/plans/3.done/stage1-bosses.md, not here"

	# **The negative half first, because it is what proves the rejoin does any work at all.**
	#  Read line by line — which is what every hand sweep did all night — shape A is in neither line.
	t.eq(_paths_in(a1).size(), 0, "줄 단위로 보면 첫 줄에는 인용이 없다")
	t.eq(_paths_in(a2).size(), 0, "둘째 줄에도 없다 (줄 단위 grep이 11개 중 3개를 통과시킨 이유가 이것이다)")

	for shape: Array in [[a1, a2, "토큰 중간"], [b1, b2, "단어 사이"]]:
		var blocks := _comment_blocks(String(shape[0]) + "\n" + String(shape[1]) + "\nvar x := 1\n")
		t.eq(blocks.size(), 1, "%s에서 끊긴 주석이 한 덩어리로 합쳐진다 (%d덩어리)" % [shape[2], blocks.size()])
		if blocks.is_empty():
			continue
		var found := _paths_of(blocks[0])
		t.eq(found.size(), 1, "%s에서 끊겨도 그 인용이 보인다 (한쪽 이음만으로는 못 찾는다)" % shape[2])
		if found.size() > 0:
			t.eq(String(found[0]["doc"]), "stage1-bosses.md", "%s — 문서 이름을 정확히 뽑는다" % shape[2])
			t.eq(String(found[0]["folder"]), "3.done", "%s — 폴더도 정확히 뽑는다" % shape[2])


## **The index is the other half of every check below**, so an empty one would make all of them vacuously
## green — the "a loop whose condition is false from the start never runs the check" shape.
func _the_doc_index_found_the_docs(t) -> void:
	var idx := _doc_index()
	t.ok(idx.size() > 20, "docs/ 에서 md 문서를 %d개 찾았다 (색인이 비면 아래 검사가 전부 헛돈다)" % idx.size())
	t.ok(idx.has("GDD.md"), "그 안에 GDD.md 가 있다 (색인이 진짜 저장소를 읽었다는 증거)")


## **The bug itself: a citation that points where nothing is.** This is what went dead five times in one
## night and what a moved doc breaks every time.
func _every_path_form_citation_resolves_where_it_says(t) -> void:
	var idx := _doc_index()
	var scanned := 0
	var dead: Array[String] = []
	for path: String in _scan_files():
		scanned += 1
		for block: Dictionary in _comment_blocks(_read(path)):
			for hit: Dictionary in _paths_of(block):
				var doc := String(hit["doc"])
				var want := "res://docs/plans/" + String(hit["folder"])
				var dirs: Array = idx.get(doc, [])
				if not dirs.has(want):
					var actually := "어디에도 없다" if dirs.is_empty() else String(dirs[0])
					dead.append("%s:%d — `%s` 는 %s (지금은 %s). 폴더를 빼고 이름만 적어라"
						% [path, int(block["line"]), doc, want, actually])
	t.ok(scanned > 30, "훑은 .gd 파일이 %d개다 (전제 — 스캔이 죽으면 아래가 공짜로 초록이 된다)" % scanned)
	if not dead.is_empty():
		for msg: String in dead:
			t.ok(false, "죽은 인용: %s" % msg)
	t.eq(dead.size(), 0, "src/ 와 tests/ 의 경로형 인용이 전부 실재하는 문서를 가리킨다 (죽은 것 %d개)"
		% dead.size())


## **A bare name that resolves to nothing fails exactly the same way as a stale path**, and more quietly —
## there is no folder to look wrong. `left-run-clumps-and-platforms.md` cited as a bare name is only useful
## while a file by that name exists somewhere under `docs/`.
func _every_bare_name_citation_resolves_to_a_real_doc(t) -> void:
	var idx := _doc_index()
	var seen := 0
	var missing: Array[String] = []
	for path: String in _scan_files():
		for block: Dictionary in _comment_blocks(_read(path)):
			for doc: String in _bares_of(block):
				seen += 1
				if not idx.has(doc):
					missing.append("%s:%d — `%s` 라는 문서가 docs/ 어디에도 없다"
						% [path, int(block["line"]), doc])
	t.ok(seen > 100, "이름형 인용을 %d개 봤다 (전제 — 0이면 정규식이 죽은 것이다)" % seen)
	if not missing.is_empty():
		for msg: String in missing:
			t.ok(false, "없는 문서: %s" % msg)
	t.eq(missing.size(), 0, "이름만 적은 인용이 전부 실재하는 문서다 (없는 것 %d개)" % missing.size())


## **The same rule, one level down: a line number is a path into a file.** CLAUDE.md says so in the same
## breath as the folder rule, and it rotted exactly the same way — silently, and in favour of whoever added
## four lines above the cited one.
##
## **Seventeen citations of the form name-colon-number were swept by hand and six of them were already
## dead**, landing on an unrelated statement while reading as precise. **One of the six was cited by
## CLAUDE.md itself**, in the paragraph that forbids the shape. Nothing barked, because a stale line number
## is still valid text — it just describes a different line now.
##
## ⇒ **Name the symbol.** A function or constant name survives every edit above it, and when it is renamed
## the reader is at least reading about a thing that exists.
##
## **Scoped to backticked citations**, the same filter `_bare_names_in` uses: an error message that formats
## a path and a line for a human to click is not a citation and must keep working.
func _there_are_no_line_number_citations(t) -> void:
	var n := 0
	var where: Array[String] = []
	for path: String in _scan_files():
		for block: Dictionary in _comment_blocks(_read(path)):
			for hit: String in _line_refs_of(block):
				n += 1
				where.append("%s:%d — `%s`. 줄 대신 심볼 이름을 적어라"
					% [path, int(block["line"]), hit])
	for msg: String in where:
		t.ok(false, "줄번호로 적은 인용: %s" % msg)
	t.eq(n, 0, "줄번호를 박은 인용이 하나도 없다 (줄은 위에 네 줄만 끼면 죽는다 — %d개 발견)" % n)


## **`docs/` is excluded as a record — but not every doc is one.** The header box argues that docs quote dead
## paths on purpose, and that is true of `3.done/` and `archive/`, which describe a moment that has passed.
## **It is not true of the docs that are read to decide what to build**: the GDD, `design/`, `decisions/` and
## `1.ready/`/`2.active/` make claims about the code **as it is now**, and a line number in one of those is a
## claim that rots.
##
## **This split was found by sweeping them by hand, and the sweep is why it exists.** Forty-nine line-number
## citations lived in the living docs; spot-checking eight of them found **eight dead**, pointing at unrelated
## statements. Worse, following them turned up **three stale values** riding along: `MAP_W` 300 (really 217),
## `MOVE_SPEED_PX` 260 (really 180) in two docs, and "this game has no sound at all" — which `game-feel.md`
## had already corrected in its own file without the correction ever walking next door. **One of them inverted
## a design premise**: `stage2-water.md` argued that climbing is slower than walking, and at 208 vs 180 it is
## faster. ⇒ **Honour did not hold here either, and the damage was not the citations — it was the numbers
## they were standing next to.**
##
## `3.done/` and `archive/` stay out. **They are allowed to be wrong; that is what a record is.**
func _the_living_docs_carry_no_line_numbers_either(t) -> void:
	var files := _living_docs()
	t.ok(files.size() > 15, "살아 있는 문서를 %d개 훑는다 (전제 — 목록이 비면 아래가 공짜로 초록이 된다)"
		% files.size())
	var n := 0
	for path: String in files:
		var block := {"text": _read(path), "tight": "", "line": 0}
		for hit: String in _line_refs_of(block):
			n += 1
			t.ok(false, "살아 있는 문서의 줄번호 인용: %s — `%s`. 심볼 이름을 적어라" % [path, hit])
	t.eq(n, 0, "GDD·design·decisions·1.ready 에 줄번호 인용이 없다 (%d개 발견)" % n)


## **Everything under `docs/` except the two folders that are records.** Written as an exclusion, not as a
## list of included folders: a new living folder must be caught by default, and the day someone adds one, an
## include-list would silently leave it unguarded — the same shape as `tools/` being outside the scan.
func _living_docs() -> Array[String]:
	var out: Array[String] = []
	for path: String in _walk(DOCS_DIR, ".md"):
		if path.begins_with("res://docs/plans/3.done") or path.begins_with("res://docs/archive"):
			continue
		out.append(path)
	return out


## **The instrument, inverted before the thing it measures** — the lesson CLAUDE.md draws twice: a scanner
## written to catch a defect and shipped carrying that same defect stays green forever.
##
## Driven on a synthetic block, because the repo is clean now and a clean repo cannot tell a working scan
## from a dead regex. **The negative half is what makes it a measurement**: a bare mention with no backticks
## and a formatted click-target must both stay unflagged, or the first error message somebody writes turns
## this net red for doing its job.
##
## *Inversion: drop the digits group from the regex in `_line_refs_in`, or widen it past the backticks, and
## one half or the other goes red.*
func _the_scanner_sees_a_line_number_citation(t) -> void:
	var block := {"text": "## see `stage.gd:408` and `body.gd:79-88` for the rest", "tight": "", "line": 1}
	var found := _line_refs_of(block)
	t.eq(found.size(), 2, "한 덩어리 안의 줄번호 인용 둘을 다 본다 (%d개)" % found.size())
	if found.size() == 2:
		t.eq(found[0], "stage.gd:408", "단일 줄 형태를 그대로 뽑는다")
		t.eq(found[1], "body.gd:79-88", "구간 형태도 뽑는다")

	# **The negative half.** Neither of these is a citation, and flagging them would make the net unusable.
	var prose := {"text": "## the runner prints stage.gd:408 when a script fails to parse", "tight": "", "line": 1}
	t.eq(_line_refs_of(prose).size(), 0, "백틱이 없으면 인용이 아니다 (러너 출력을 설명한 산문)")
	var fmt := {"text": "## the message reads `%s:%d — 무엇이 틀렸는지`", "tight": "", "line": 1}
	t.eq(_line_refs_of(fmt).size(), 0, "사람이 눌러 여는 좌표 포맷은 인용이 아니다")


## **Was the rule followed** — the other half of this net, and the half that catches a mistake while it is
## still only a mistake. See the header box for why this is now a flat zero rather than a ceiling, and why
## deleting it would leave a new-but-valid path citation entirely unguarded.
func _there_are_no_path_form_citations_at_all(t) -> void:
	var n := 0
	var where: Array[String] = []
	for path: String in _scan_files():
		for block: Dictionary in _comment_blocks(_read(path)):
			for hit: Dictionary in _paths_of(block):
				n += 1
				where.append("%s:%d — `%s`. 폴더를 빼고 이름만 적어라"
					% [path, int(block["line"]), String(hit["doc"])])
	for msg: String in where:
		t.ok(false, "경로로 적은 인용: %s" % msg)
	t.eq(n, 0, "경로형 인용이 하나도 없다 (문서는 이름으로만 부른다 — %d개 발견)" % n)


# ══════════════════════════════════════════════════════════════════
#  The scanner
# ══════════════════════════════════════════════════════════════════

## Consecutive comment lines rejoined, keyed by the first line's number. **Two joins per block, and the
## reason is the whole point of this net.**
##
## A citation wraps in one of two shapes and **no single join catches both**:
##  · **between words** — the first line ends with an ordinary word and the whole path starts the next.
##    Rejoining needs a **space**, or the trailing word and the leading "docs" glue into one token
##  · **mid-token** — the break falls inside the path itself, after a slash or inside the filename.
##    Rejoining needs **no space**, or the path gets one inserted into its middle and matches nothing
##
## **The two example shapes are described rather than written out**, for the reason the `_bare_names_in`
## box below records at length: a worked example written in citation form *is* a citation as far as this
## scan is concerned, and it made this net red on its own comments twice while it was being written.
##
## **This was got wrong on the first attempt, in this file, by the person writing the net to catch it.**
## Joining with a space only, the self-test's own wrapped citation went unfound — the scanner had the exact
## defect it exists to detect, and the self-test is the only reason that surfaced. ⇒ **both joins, and the
## callers take the union.** A "tight" join cannot invent a citation that was not there: it would have to
## find a line ending in a path prefix whose next line begins with the rest, which is a real citation.
func _comment_blocks(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var spaced := ""
	var tight := ""
	var start := 0
	var lines := text.split("\n")
	for i in lines.size():
		var st := String(lines[i]).strip_edges()
		if st.begins_with("#"):
			if spaced.is_empty():
				start = i + 1
			var body := st.lstrip("#").strip_edges()
			spaced += " " + body
			tight += body
		elif not spaced.is_empty():
			out.append({"line": start, "text": spaced, "tight": tight})
			spaced = ""
			tight = ""
	if not spaced.is_empty():
		out.append({"line": start, "text": spaced, "tight": tight})
	return out


## Both joins of one block, deduplicated — the door every check below reads through, so the union rule
## lives in one place instead of at three call sites.
func _paths_of(block: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for text: String in [String(block["text"]), String(block["tight"])]:
		for hit: Dictionary in _paths_in(text):
			var key := String(hit["folder"]) + "/" + String(hit["doc"])
			if seen.has(key):
				continue
			seen[key] = true
			out.append(hit)
	return out


## Both joins, deduplicated — same door as `_paths_of`, same reason.
func _line_refs_of(block: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for text: String in [String(block["text"]), String(block["tight"])]:
		for hit: String in _line_refs_in(text):
			if not out.has(hit):
				out.append(hit)
	return out


## Backticked file-and-line references. **The backticks carry the same load they do for bare names**: an
## error message that formats a coordinate for a human to click is not a citation, and it has a percent
## sign where a citation has digits.
##
## **Every extension that holds comments, not just the one the leak was found in.** Scoping a scan to where
## the bug turned up is the mistake this net's own header records `tools/` being left out for — and a doc
## cited with a line number rots the same way a script does.
func _line_refs_in(text: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string(
		"`([A-Za-z0-9_/\\.\\-]+\\.(?:gd|md|py|ps1|tscn|tres|gdshader):[0-9]+(?:-[0-9]+)?)`")
	for m: RegExMatch in re.search_all(text):
		out.append(m.get_string(1))
	return out


func _bares_of(block: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for text: String in [String(block["text"]), String(block["tight"])]:
		for nm: String in _bare_names_in(text):
			if not out.has(nm):
				out.append(nm)
	return out


## `docs/plans/<folder>/<name>.md` occurrences, as `{folder, doc}`.
func _paths_in(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var re := RegEx.create_from_string("docs/plans/([0-9]\\.[a-z]+)/([A-Za-z0-9_\\-]+\\.md)")
	for m: RegExMatch in re.search_all(text):
		out.append({"folder": m.get_string(1), "doc": m.get_string(2)})
	return out


## Backticked bare names. **The backticks are the filter**: without them this would match every "md" in
## ordinary prose.
##
## **There is no exception list, and this net proved why on its first run — by failing on its own comment.**
## An earlier version of this very docstring wrote a made-up filename inside backticks as an illustration,
## and the scan correctly called it a citation of a doc that does not exist. **An escape hatch was rejected**:
## any marker meaning "not really a citation" is one somebody reaches for the day their real citation is
## inconvenient, and then this net measures nothing. ⇒ **If you want an example, do not dress it as a
## citation** — describe it instead of backticking a filename. That is a one-word cost, once.
func _bare_names_in(text: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("`([A-Za-z0-9_\\-]+\\.md)`")
	for m: RegExMatch in re.search_all(text):
		out.append(m.get_string(1))
	return out


## Filename -> the directories it lives in. **A name can legitimately exist twice** (a `README.md` per
## folder), which is why the value is a list and the path check asks whether its own folder is in it.
func _doc_index() -> Dictionary:
	var out: Dictionary = {}
	for path: String in _walk(DOCS_DIR, ".md"):
		var nm := path.get_file()
		if not out.has(nm):
			out[nm] = []
		(out[nm] as Array).append(path.get_base_dir())
	return out


func _scan_files() -> Array[String]:
	var out: Array[String] = []
	for d: String in SCAN_DIRS:
		out.append_array(_walk(d, ".gd"))
	return out


## The same recursive shape `net_layers._scan_dir` already uses — copied rather than shared, because each
## net runs in its own process and this file preloads nothing.
func _walk(dir: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(suffix):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_walk(dir.path_join(sub), suffix))
	out.sort()
	return out


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_citations: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()
