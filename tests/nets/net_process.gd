extends RefCounted
## The process shape, forced — **rewritten 2026-08-22 when the process changed underneath it.**
##
## It used to scan `docs/plans/{2.active,3.done}` for a round log and a "were the open questions sent"
## line. **That folder is gone**: planning became `docs/plan/` and then `docs/roadmap/` on 2026-08-31,
## which holds the map, the decision log and the task folders, and status is a line inside a file.
## ⚠ **`wayfinder` was named here as the skill that kept the map and it was deleted on 2026-08-27** —
## no skill owns the map now, and only `wrap-up` writes to any of these files.
##
## ⚠ **What a green here means TODAY, stated up front so nobody reads more into it.**
## The tree half walks `docs/roadmap/` and checks whatever it finds, and **the label carries how much was
## actually walked — read the count in it, not the colour.** What carries real weight is the scanner
## self-checks at the bottom: they drive the same pure functions the tree half uses, so a parser that has
## stopped working goes red with or without a map.
##
## ⚠ **It cannot check that any of it is TRUE.** A `Status: resolved` on a ticket nobody resolved, or an
## `## Answer` holding one word, both pass. **Absent → present is the whole of what is bought here**, and
## that is deliberate: this repo has measured five text scans being evaded inside one feature.
##
## Everything is parsed by pure functions taking TEXT, and the synthetic cases at the bottom drive **those
## same functions** — not a second copy written to agree with them.

const SCRATCH := "res://docs/roadmap"
const MAP_FILE := "log.md"
## ⚠⚠ **Rewritten 2026-08-31: there is no flat `tickets/` folder any more, and a ticket is a FOLDER.**
## A task is `task-NN-name/` sitting directly under `docs/roadmap/`, its `NN.task.md` says what the task
## is, and each `MM-name/` folder beside it is one ticket — `NN-MM.ticket.md` describes it and **whatever
## it produced piles up in that same folder.** Tickets are **numbered from `01` inside their own task**,
## so `Blocked by:` is resolved against that task's own tickets and never across the repo.
## ⚠⚠ **The description file is named after its own number, not `TASK.md` / `TICKET.md`** (2026-08-31,
## the user: *"other tasks all become hard to tell apart by name"*). A task holds `NN.task.md`; a ticket
## folder holds `NN-MM.ticket.md`, the two-tier number, so no two open tabs in the repo carry one name.
const TASK_PREFIX := "task-"
const TASK_SUFFIX := ".task.md"
const TICKET_SUFFIX := ".ticket.md"

const TYPES := ["grilling", "research", "prototype", "task"]
## ⚠ **`superseded` is the fourth**, added 2026-08-30: 티켓 10 과 27 were kept as tombstones on purpose
## (the roadmap says so) and this list red-flagged both for a month.
const STATES := ["open", "claimed", "resolved", "superseded"]
const ANSWER_HEAD := "## Answer"
## Assembled so this file's own header cannot trip the scan it performs.
const DECIDED_HEAD := "## 지금까지의" + " 결정"

## ⚠⚠ **Four of the five sections this once demanded died on 2026-08-27**, when the map was rewritten
## and `log.md` was narrowed to 「왜 그렇게 됐나」 alone — the plan folder's own README is what says so.
## `## Destination`, `## Notes`, `## Not yet specified` and `## Out of scope` belonged to a map shape no
## file in this repo has worn since, and **this net went on demanding all four**, so its red said the docs
## were broken when the net was. **What is left is the one section the log genuinely carries.**
const MAP_SECTIONS := [DECIDED_HEAD]


func run(t) -> void:
	_tree(t)
	_scanner_self_checks(t)


# -- the tree ---------------------------------------------------------------------------------------------
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies
	# half way still reports every check it managed first, in a shape a healthy net cannot be told from.
	t.done()

## One assertion per defect kind, each label carrying **how much was actually walked**. A reader who sees
## `로드맵 0개` knows this line measured nothing; a bare green would have hidden that.
func _tree(t) -> void:
	var efforts := _effort_dirs()
	var task_count := 0
	var tickets := 0
	var bad_head: Array[String] = []
	var bad_field: Array[String] = []
	var dangling: Array[String] = []
	var resolved_without_answer: Array[String] = []
	var task_without_task_file: Array[String] = []
	var ticket_without_ticket_file: Array[String] = []

	for effort: String in efforts:
		var map_text := _read(effort.path_join(MAP_FILE))
		for want: String in MAP_SECTIONS:
			if not map_text.contains(want):
				bad_head.append("%s → %s" % [effort.get_file(), want])

		for task_dir: String in _task_dirs(effort):
			task_count += 1
			var task_no := _leading_number(task_dir.get_file().substr(TASK_PREFIX.length()))
			# ⚠ The name must carry the number, not merely end in `.task.md`: `07.task.md` sitting in
			# `task-03-name/` is exactly the mix-up this naming exists to prevent.
			if not _named_files(task_dir, TASK_SUFFIX).has("%02d%s" % [task_no, TASK_SUFFIX]):
				task_without_task_file.append(task_dir.get_file())

			# ⚠ Built per task, not per repo: `Blocked by: 01` inside task 03 means **03-01**, and the
			# same `01` inside task 04 is a different ticket. A repo-wide set would let a dangling
			# reference pass because some other task happened to own that number.
			var ticket_dirs := _ticket_dirs(task_dir)
			var numbers := {}
			for p: String in ticket_dirs:
				numbers[_leading_number(p.get_file())] = true
			for p: String in ticket_dirs:
				tickets += 1
				var name := "%s/%s" % [task_dir.get_file(), p.get_file()]
				var want := "%02d-%02d%s" % [task_no, _leading_number(p.get_file()), TICKET_SUFFIX]
				if not _named_files(p, TICKET_SUFFIX).has(want):
					ticket_without_ticket_file.append("%s → %s" % [name, want])
					continue
				var text := _read(p.path_join(want))
				if not TYPES.has(ticket_field(text, "Type")):
					bad_field.append(name + " → Type")
				if not STATES.has(ticket_field(text, "Status")):
					bad_field.append(name + " → Status")
				for piece: String in blocked_by_malformed(text):
					bad_field.append("%s → Blocked by: %s" % [name, piece])
				for n: int in blocked_by(text):
					if not numbers.has(n):
						dangling.append("%s → %d" % [name, n])
				if ticket_field(text, "Status") == "resolved" and not text.contains(ANSWER_HEAD):
					resolved_without_answer.append(name)

	var walked := "로드맵 %d개 · 태스크 %d개 · 티켓 %d개" % [efforts.size(), task_count, tickets]
	t.ok(bad_head.is_empty(), "%s — 로드맵이 요구된 절을 다 갖고 있다 %s" % [walked, str(bad_head)])
	t.ok(task_without_task_file.is_empty(),
		"%s — 태스크 폴더는 자기 번호로 된 .task.md 를 들고 있다 %s" % [walked, str(task_without_task_file)])
	t.ok(ticket_without_ticket_file.is_empty(),
		"%s — 티켓 폴더는 자기 두 겹 번호로 된 .ticket.md 를 들고 있다 %s" % [walked, str(ticket_without_ticket_file)])
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
## ⚠ **A `Blocked by:` line never leaves its own task**, so the number here is the ticket's short one.
func blocked_by(text: String) -> Array[int]:
	var out: Array[int] = []
	for piece: String in _blocked_by_pieces(text):
		if piece.is_valid_int():
			out.append(piece.to_int())
	return out


## ⚠⚠ **The hole this closes, measured 2026-08-31**: a ticket carried `Blocked by: 00-01` — the two-tier
## number — and `is_valid_int()` threw the whole piece away, so the dangling check ran on an empty list
## and went green while measuring nothing. **A piece that is not a number is now a defect, not silence.**
func blocked_by_malformed(text: String) -> Array[String]:
	var out: Array[String] = []
	for piece: String in _blocked_by_pieces(text):
		if not piece.is_valid_int():
			out.append(piece)
	return out


## The raw comma-separated pieces, with the two ways of writing "nothing blocks this" already removed.
func _blocked_by_pieces(text: String) -> Array[String]:
	var out: Array[String] = []
	var raw := ticket_field(text, "Blocked by")
	if raw == "" or raw == "-" or raw == "—":
		return out
	for piece: String in raw.split(","):
		var s := piece.strip_edges()
		if s != "":
			out.append(s)
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
	t.eq(blocked_by_malformed("Blocked by: 00-01\n").size(), 1,
		"두 겹 번호를 쓴 Blocked by 를 잡는다 — 예전엔 조용히 버려졌다 (스캐너 자가 점검)")
	t.eq(blocked_by("Blocked by: 00-01\n").size(), 0,
		"그리고 그것은 막는 티켓으로 세지 않는다 (스캐너 자가 점검)")
	t.eq(blocked_by_malformed("Blocked by: 01, 03\n").size(), 0,
		"짧은 번호만 쓴 줄은 안 잡는다 (스캐너 자가 점검)")
	t.eq(blocked_by_malformed("Blocked by: —\n").size(), 0,
		"막는 것이 없다는 표시는 잘못된 값이 아니다 (스캐너 자가 점검)")
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
	# ⚠ The removal is driven off `MAP_SECTIONS` itself rather than off a literal heading, so shrinking
	# or growing that list cannot leave this self-check quietly removing a section nobody asks for.
	var short_map := full.replace(MAP_SECTIONS[0] + "\n", "")
	for h: String in MAP_SECTIONS:
		if not full.contains(h):
			missing_none += 1
		if not short_map.contains(h):
			missing_one += 1
	t.eq(missing_none, 0, "요구된 절을 다 가진 로드맵은 안 잡는다 (스캐너 자가 점검)")
	t.eq(missing_one, 1, "절 하나가 빠진 로드맵을 잡는다 (스캐너 자가 점검)")


# -- io ---------------------------------------------------------------------------------------------------
## ⚠⚠ **Rewritten 2026-08-27: planning is ONE folder now, not one folder per effort.** `docs/roadmap/`
## holds the map, the log and the task folders directly — there is nothing to enumerate. **The old
## version walked subdirectories and would have found zero here, going green while measuring nothing.**
func _effort_dirs() -> Array[String]:
	var out: Array[String] = []
	if FileAccess.file_exists(SCRATCH.path_join(MAP_FILE)):
		out.append(SCRATCH)
	return out


## Every `task-NN-name/` sitting directly under the map's folder. ⚠ **A folder that does not open with
## `task-` is not a task** — the map's own `README.md` and `log.md` are files, not folders, and nothing
## else is expected here.
func _task_dirs(effort: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(effort)
	if d == null:
		return out
	for sub: String in d.get_directories():
		if sub.begins_with(TASK_PREFIX):
			out.append(effort.path_join(sub))
	out.sort()
	return out


## The file names in one folder that end in a given suffix. Returns names, not paths, because every
## caller is asking "is the file that carries THIS number here", which is a question about the name.
func _named_files(dir_path: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(suffix):
			out.append(f)
	return out


## Every ticket folder inside one task. ⚠ **A ticket is a folder, not a file** — the task's own
## `NN.task.md` sits beside them as a plain file and is therefore never counted as a day.
func _ticket_dirs(task_dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(task_dir)
	if d == null:
		return out
	for sub: String in d.get_directories():
		out.append(task_dir.path_join(sub))
	out.sort()
	return out


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()
