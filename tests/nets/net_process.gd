extends RefCounted
## The process shape, forced — **rewritten 2026-08-22 when the process changed underneath it.**
##
## It used to scan `docs/plans/{2.active,3.done}` for a round log and a "were the open questions sent"
## line. **That folder is gone**: plans moved to `.scratch/<effort>/` where `wayfinder` keeps a map and its
## tickets, and status is a line inside a file instead of the folder the file sits in.
##
## ⚠ **What a green here means TODAY, stated up front so nobody reads more into it.**
## The tree half walks `.scratch/` and checks whatever it finds. **With no map written yet it finds
## nothing, and its label says so out loud — read the count in the label, not the colour.** What carries
## real weight today is the scanner self-checks at the bottom: they drive the same pure functions the tree
## half uses, so a parser that has stopped working goes red with or without a map.
##
## ⚠ **It cannot check that any of it is TRUE.** A `Status: resolved` on a ticket nobody resolved, or an
## `## Answer` holding one word, both pass. **Absent → present is the whole of what is bought here**, and
## that is deliberate: this repo has measured five text scans being evaded inside one feature.
##
## Everything is parsed by pure functions taking TEXT, and the synthetic cases at the bottom drive **those
## same functions** — not a second copy written to agree with them.

const SCRATCH := "res://.scratch"
const MAP_FILE := "map.md"
const ISSUE_DIR := "issues"

const TYPES := ["grilling", "research", "prototype", "task"]
const STATES := ["open", "claimed", "resolved"]
const ANSWER_HEAD := "## Answer"
## Assembled so this file's own header cannot trip the scan it performs.
const DECIDED_HEAD := "## 지금까지의" + " 결정"

const MAP_SECTIONS := ["## Destination", "## Notes", DECIDED_HEAD, "## Not yet specified", "## Out of scope"]


func run(t) -> void:
	_tree(t)
	_scanner_self_checks(t)


# -- the tree ---------------------------------------------------------------------------------------------
## One assertion per defect kind, each label carrying **how much was actually walked**. A reader who sees
## `지도 0개` knows this line measured nothing; a bare green would have hidden that.
func _tree(t) -> void:
	var efforts := _effort_dirs()
	var tickets := 0
	var bad_head: Array[String] = []
	var bad_field: Array[String] = []
	var dangling: Array[String] = []
	var resolved_without_answer: Array[String] = []

	for effort: String in efforts:
		var map_text := _read(effort.path_join(MAP_FILE))
		for want: String in MAP_SECTIONS:
			if not map_text.contains(want):
				bad_head.append("%s → %s" % [effort.get_file(), want])

		var files := _issue_files(effort)
		var numbers := {}
		for p: String in files:
			numbers[_leading_number(p.get_file())] = true
		for p: String in files:
			tickets += 1
			var text := _read(p)
			var name := "%s/%s" % [effort.get_file(), p.get_file()]
			if not TYPES.has(ticket_field(text, "Type")):
				bad_field.append(name + " → Type")
			if not STATES.has(ticket_field(text, "Status")):
				bad_field.append(name + " → Status")
			for n: int in blocked_by(text):
				if not numbers.has(n):
					dangling.append("%s → %d" % [name, n])
			if ticket_field(text, "Status") == "resolved" and not text.contains(ANSWER_HEAD):
				resolved_without_answer.append(name)

	var walked := "지도 %d개 · 티켓 %d개" % [efforts.size(), tickets]
	t.ok(bad_head.is_empty(), "%s — 지도가 다섯 절을 다 갖고 있다 %s" % [walked, str(bad_head)])
	t.ok(bad_field.is_empty(), "%s — 모든 티켓이 Type 과 Status 를 legal 한 값으로 갖는다 %s" % [walked, str(bad_field)])
	t.ok(dangling.is_empty(), "%s — Blocked by 가 실재하는 티켓만 가리킨다 %s" % [walked, str(dangling)])
	t.ok(resolved_without_answer.is_empty(), "%s — resolved 인 티켓은 답을 들고 있다 %s" % [walked, str(resolved_without_answer)])


# -- pure parsers -----------------------------------------------------------------------------------------
## `Type: grilling` → `"grilling"`. Absent → `""`, which is a **different state** from a wrong value and is
## why the caller checks membership rather than emptiness.
func ticket_field(text: String, field: String) -> String:
	for line: String in text.split("\n"):
		var s := line.strip_edges()
		if s.begins_with(field + ":"):
			return s.substr(field.length() + 1).strip_edges().to_lower()
	return ""


## `Blocked by: 01, 3` → `[1, 3]`. An absent line is **not** a defect: it means nothing blocks this ticket.
func blocked_by(text: String) -> Array[int]:
	var out: Array[int] = []
	var raw := ticket_field(text, "Blocked by")
	if raw == "" or raw == "-":
		return out
	for piece: String in raw.split(","):
		var s := piece.strip_edges()
		if s.is_valid_int():
			out.append(s.to_int())
	return out


## `07-name.md` → `7`. Anything that does not open with digits → `-1`, which can never match a real ticket,
## so a misnamed file surfaces as a dangling reference instead of silently matching zero.
func _leading_number(file_name: String) -> int:
	var digits := ""
	for c: String in file_name:
		if c >= "0" and c <= "9":
			digits += c
		else:
			break
	return digits.to_int() if digits != "" else -1


# -- cases that fail the SCANNER, not the tree ------------------------------------------------------------
## `CLAUDE.md`: *"a new check needs a case that fails it, not only one that fails what it points at."*
## Twice in one night a scanner shipped carrying the very defect it existed to find.
func _scanner_self_checks(t) -> void:
	t.eq(ticket_field("Type: grilling\nStatus: open\n", "Type"), "grilling",
		"Type 을 읽는다 (스캐너 자가 점검)")
	t.eq(ticket_field("Type: RESEARCH\n", "Type"), "research",
		"대소문자가 달라도 같은 값으로 읽는다 (스캐너 자가 점검)")
	t.eq(ticket_field("# 제목\n\n본문뿐\n", "Status"), "",
		"없으면 빈 값이다 — 없는 것과 틀린 값은 다른 상태다 (스캐너 자가 점검)")
	# ⚠ A field name that merely appears mid-sentence is not a field. Both halves matter: prose alone
	# yields nothing, and prose sitting ABOVE the real line must not shadow it.
	t.eq(ticket_field("여기서 Status: 를 설명하기만 한다\n", "Status"), "",
		"문장 가운데의 언급은 필드가 아니다 (스캐너 자가 점검)")
	t.eq(ticket_field("여기서 Status: 를 설명한다\nStatus: open\n", "Status"), "open",
		"그런 문장이 위에 있어도 진짜 줄을 찾아낸다 (스캐너 자가 점검)")

	t.eq(blocked_by("Blocked by: 01, 3\n").size(), 2, "막힘 둘을 읽는다 (스캐너 자가 점검)")
	t.eq(blocked_by("Blocked by: 01, 3\n")[0], 1, "앞의 0 을 떼고 숫자로 읽는다 (스캐너 자가 점검)")
	t.eq(blocked_by("Type: task\n").size(), 0,
		"막힘 줄이 없으면 안 막힌 것이다 — 전부 빨개지는 스캐너가 아니다 (스캐너 자가 점검)")
	t.eq(blocked_by("Blocked by: -\n").size(), 0, "빈 표시를 막힘으로 안 센다 (스캐너 자가 점검)")

	t.eq(_leading_number("07-refit.md"), 7, "파일 번호를 읽는다 (스캐너 자가 점검)")
	t.eq(_leading_number("refit.md"), -1,
		"번호 없는 이름은 실재하는 티켓과 절대 안 맞는 값이 된다 (스캐너 자가 점검)")

	# The map-section scan, driven on text rather than on a file, so it is checked with no map on disk.
	var full := ""
	for h: String in MAP_SECTIONS:
		full += h + "\n\n내용\n\n"
	var missing_none := 0
	var missing_one := 0
	var short_map := full.replace("## Out of scope\n", "")
	for h: String in MAP_SECTIONS:
		if not full.contains(h):
			missing_none += 1
		if not short_map.contains(h):
			missing_one += 1
	t.eq(missing_none, 0, "다섯 절을 다 가진 지도는 안 잡는다 (스캐너 자가 점검)")
	t.eq(missing_one, 1, "「범위 밖」이 빠진 지도를 잡는다 (스캐너 자가 점검)")


# -- io ---------------------------------------------------------------------------------------------------
## An effort is a directory under `.scratch/` that actually holds a map. A directory without one is not a
## half-built effort to complain about; it is somebody's folder.
func _effort_dirs() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(SCRATCH)
	if d == null:
		return out
	for name: String in d.get_directories():
		var path := SCRATCH.path_join(name)
		if FileAccess.file_exists(path.path_join(MAP_FILE)):
			out.append(path)
	return out


func _issue_files(effort: String) -> Array[String]:
	var out: Array[String] = []
	var dir_path := effort.path_join(ISSUE_DIR)
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".md") and f != "README.md":
			out.append(dir_path.path_join(f))
	return out


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()
