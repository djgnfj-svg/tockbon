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

const SCAN_DIRS: Array[String] = ["res://src", "res://tests"]
const DOCS_DIR := "res://docs"

## **How many `docs/plans/<folder>/<name>.md` citations are allowed to exist. A ratchet, and a deliberate
## compromise — argued rather than assumed.**
##
## The rule says *never path it*, so by the letter every one of these is a violation and this net should
## demand zero. **It does not, and here is the case for both sides:**
##  · **For zero**: the rule has no exception, and a path that resolves today is a path that rots the day its
##    doc moves. They are latent, not harmless.
##  · **Against zero**: it would land **red on every one of them on day one**, and a net that is red on
##    arrival is a net somebody deletes or weakens in the same hour. The five instances in one night were
##    found *by hand* precisely because nothing automated existed; trading that for a net nobody keeps is a
##    net loss.
## ⇒ **The ceiling is what closes the gap**: every *new* path-form citation goes red immediately, while the
## existing ones are grandfathered and burned down over time. **Lower this number by hand as they go** — it
## must never rise.
##
## **Its known weakness, stated rather than hidden**: deleting one path citation and adding another leaves
## the count unchanged and this check green. That hole is covered by
## `_every_path_form_citation_resolves_where_it_says` below, which is about the actual bug (a citation that
## points at nothing) rather than about the style rule. **The ratchet governs the rule; the resolve check
## governs the breakage.**
##
## **56, and the number itself is a finding.** Every hand scan run the night this net was written — including
## the one used to size this very ceiling — reported **53**, because they all joined comment lines with a
## space and **three citations in this repo wrap mid-token**:
## `monster.gd:91` · `settlement_layout.gd:2` · `net_pick.gd:594`.
## All three resolve, so none was ever *dead* — but they were **invisible**, which is the same blind spot
## that let two genuinely dead ones survive four sweeps. ⇒ **The count did not rise because anyone added a
## citation. It rose because the scanner stopped being blind**, which is the best evidence available that
## the two-join rule earns its cost.
const PATH_FORM_CEILING := 56


func run(t) -> void:
	_the_scanner_rejoins_wrapped_comment_lines(t)
	_the_doc_index_found_the_docs(t)
	_every_path_form_citation_resolves_where_it_says(t)
	_every_bare_name_citation_resolves_to_a_real_doc(t)
	_the_path_form_count_does_not_grow(t)


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


## **The ratchet** — see `PATH_FORM_CEILING`'s own box for why this is a ceiling and not a zero.
func _the_path_form_count_does_not_grow(t) -> void:
	var n := 0
	for path: String in _scan_files():
		for block: Dictionary in _comment_blocks(_read(path)):
			n += _paths_of(block).size()
	t.ok(n <= PATH_FORM_CEILING,
		"경로형 인용이 %d개로, 상한 %d개를 안 넘는다 — 새로 하나 적으면 여기가 빨개진다 (이름만 적어라)"
			% [n, PATH_FORM_CEILING])
	# **The other direction is a reminder, not a failure**: cleaning them up must lower the ceiling by hand,
	#  or the ratchet stops ratcheting and quietly allows one back in.
	t.ok(n >= PATH_FORM_CEILING - 10,
		"그리고 상한이 실제 개수(%d)에서 너무 멀어지지 않았다 — 정리했으면 상한도 손으로 내려라 (상한 %d)"
			% [n, PATH_FORM_CEILING])


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
