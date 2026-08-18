extends RefCounted
## The process shape, forced. This net exists because **the two rules it covers were written down, in two
## places each, and skipped both times** — 2026-08-19:
##  · `title-and-map`'s plan opens with a section titled *"OPEN questions — these go to the user in ONE
##    message"*, five questions with defaults. **The message was never sent.** All five defaults shipped
##    silently, question A gated step 5, and step 5 was descoped
##  · `build-feature` and `parallel-build` both say a round report is written. **No plan has one**
##
## `CLAUDE.md` already records the general form: seventeen line-number citations were honour-based for
## weeks and **six were already dead, one of them cited by the rule forbidding the shape.** The day a net
## covered it, it found five more that a hand sweep had just missed.
##
## ⚠ **What this net can and cannot do, stated up front so nobody reads more into a green.**
## It forces the report and the sent-line to EXIST and to carry every field. **It cannot check that any of
## it is true** — a `why` line naming a label that was never red, or a `Sent to the user: yes` on a message
## nobody sent, both pass. This repo has measured five text scans being evaded inside one feature.
## ⇒ **Absent → present is the whole of what is bought here, and today's failure was absence.**
##
## Everything is parsed by pure functions taking TEXT, and the synthetic cases at the bottom drive **those
## same functions** — not a second copy written to agree with them.

const PLAN_DIRS := ["res://docs/plans/2.active", "res://docs/plans/3.done"]
const DONE_DIR := "res://docs/plans/3.done"

## Plans that shipped before either rule existed. ⚠ **THIS LIST MUST NEVER GROW.** A new plan added here is
## the rule being deleted one file at a time. `net_citations` records the opposite failure — a skip list
## that covered no file at all — so each entry below is asserted to actually exist and actually fire.
const GRANDFATHERED := ["first-slice.md", "boat-and-landing.md", "plan-then-watch.md", "title-and-map.md"]

const ROUND_LOG_HEAD := "## Round log"
const ROUND_HEAD := "### Round "
const SENT_LINE := "**Sent to the user**:"
## Assembled, so this file's own header cannot trip the OPEN-questions scan it performs.
const OPEN_MARK := "OPEN" + " questions"
const FIELDS := ["changed", "why", "closed", "not closed", "nets"]


func run(t) -> void:
	var plans := _plan_files()
	# A literal floor, never `plans.size()` read back: a walk that found nothing would report a perfectly
	# clean tree and every assertion below would simply stop running.
	t.ok(plans.size() >= 4, "계획서를 찾았다 (%d개, 최소 4)" % plans.size())

	_grandfather_actually_fires(t, plans)
	_round_log_exists(t, plans)
	_open_questions_declare_whether_they_were_sent(t, plans)
	_scanner_self_checks(t)


# -- the round log ----------------------------------------------------------------------------------------
func _round_log_exists(t, plans: Array[String]) -> void:
	var missing: Array[String] = []
	var short_blocks: Array[String] = []
	var checked := 0
	for p: String in plans:
		if _is_grandfathered(p):
			continue
		checked += 1
		var text := _read(p)
		if not has_round_log(text):
			missing.append(p.get_file())
			continue
		for bad: String in blocks_missing_fields(text):
			short_blocks.append("%s / %s" % [p.get_file(), bad])
	# ⚠ **Today this section checks ZERO plans** — every plan that exists predates the rule. A bare count
	# would pass silently forever, which is this repo's measured settle-loop failure (a loop that passed
	# with zero iterations). Pinning it as a RELATION cannot go vacuous: the grandfather list is pinned at
	# four above, so **plan number five is checked or this line reddens.**
	t.eq(checked, plans.size() - GRANDFATHERED.size(),
		"라운드 기록을 요구한 계획서 = 전체 − 면제 (%d개)" % checked)
	t.eq(missing.size(), 0, "모든 계획서에 `## Round log` 가 있다 %s" % str(missing))
	t.eq(short_blocks.size(), 0, "모든 라운드 블록이 다섯 칸을 다 채웠다 %s" % str(short_blocks))


## True when the doc carries a round-log heading at all.
func has_round_log(text: String) -> bool:
	for raw: String in text.split("\n"):
		if raw.strip_edges().begins_with(ROUND_LOG_HEAD):
			return true
	return false


## Every `### Round N` block under the round log that is missing at least one of the five fields, named by
## its heading. ⚠ **`not closed` is checked like the rest**: an absent line reads as an absent problem, and
## that is exactly the row worth forcing.
func blocks_missing_fields(text: String) -> Array[String]:
	var out: Array[String] = []
	var in_log := false
	var head := ""
	var body := ""
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with(ROUND_LOG_HEAD):
			in_log = true
			continue
		if not in_log:
			continue
		# Any other level-2 heading closes the log.
		if line.begins_with("## ") and not line.begins_with(ROUND_LOG_HEAD):
			if head != "":
				_judge(head, body, out)
			in_log = false
			head = ""
			body = ""
			continue
		if line.begins_with(ROUND_HEAD):
			if head != "":
				_judge(head, body, out)
			head = line
			body = ""
			continue
		body += line + "\n"
	if head != "":
		_judge(head, body, out)
	return out


func _judge(head: String, body: String, out: Array[String]) -> void:
	var absent: Array[String] = []
	for f: String in FIELDS:
		if not body.contains(f):
			absent.append(f)
	if absent.size() > 0:
		out.append("%s 없음:%s" % [head, str(absent)])


# -- the questions that never left the file ---------------------------------------------------------------
## ⚠ **No grandfathering here.** The line costs one edit and its whole value is that the truth — including
## `NO` — is written down where the next session reads it.
func _open_questions_declare_whether_they_were_sent(t, plans: Array[String]) -> void:
	var carrying := 0
	var undeclared: Array[String] = []
	var unsent_but_done: Array[String] = []
	for p: String in plans:
		var text := _read(p)
		if not has_open_questions(text):
			continue
		carrying += 1
		var state := sent_state(text)
		if state == "":
			undeclared.append(p.get_file())
			continue
		if state == "no" and p.begins_with(DONE_DIR) and not _is_grandfathered(p):
			unsent_but_done.append(p.get_file())
	# The floor. Two plans carry an open-questions section today; if this ever reads 0 the section below
	# measures nothing and would go green on a tree where every question was dropped.
	t.ok(carrying >= 2, "질문 절을 가진 계획서를 찾았다 (%d개, 최소 2)" % carrying)
	t.eq(undeclared.size(), 0,
		"질문 절이 있는 계획서는 전부 보냈는지 아닌지를 적었다 %s" % str(undeclared))
	t.eq(unsent_but_done.size(), 0,
		"질문을 안 보낸 채로 3.done 으로 간 계획서가 없다 %s" % str(unsent_but_done))


func has_open_questions(text: String) -> bool:
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#") and line.contains(OPEN_MARK):
			return true
	return false


## `"yes"` · `"no"` · `""` when the line is absent. The token is read off the line, never assumed.
func sent_state(text: String) -> String:
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if not line.begins_with(SENT_LINE):
			continue
		var rest := line.substr(SENT_LINE.length()).strip_edges().to_lower()
		if rest.begins_with("no"):
			return "no"
		if rest.begins_with("yes"):
			return "yes"
		return "?"
	return ""


# -- the exemption is asserted, not trusted ---------------------------------------------------------------
## `net_citations` lost two checks when its skip list stopped covering any file, and recorded that an
## exemption covering nothing is a hole rather than an exception. So: every grandfathered name must match a
## real plan, and the list must not have grown.
func _grandfather_actually_fires(t, plans: Array[String]) -> void:
	t.eq(GRANDFATHERED.size(), 4, "면제 목록이 넷 그대로다 — 늘어나면 규칙이 파일 단위로 삭제된 것이다")
	var unmatched: Array[String] = []
	for name: String in GRANDFATHERED:
		var found := false
		for p: String in plans:
			if p.get_file() == name:
				found = true
		if not found:
			unmatched.append(name)
	t.eq(unmatched.size(), 0, "면제된 이름이 전부 실재하는 계획서다 %s" % str(unmatched))


func _is_grandfathered(path: String) -> bool:
	return GRANDFATHERED.has(path.get_file())


# -- cases that fail the SCANNER, not the tree ------------------------------------------------------------
## `CLAUDE.md`: *"a new check needs a case that fails it, not only one that fails what it points at."*
## Twice in one night a scanner shipped carrying the very defect it existed to find.
func _scanner_self_checks(t) -> void:
	t.ok(not has_round_log("# a plan\n\n## 1. Files\nnothing here\n"),
		"라운드 기록이 없으면 없다고 한다 (스캐너 자가 점검)")
	t.ok(has_round_log("# a plan\n\n" + ROUND_LOG_HEAD + "\n\n" + ROUND_HEAD + "1 — b\n"),
		"라운드 기록이 있으면 찾는다 (스캐너 자가 점검)")

	var full := (ROUND_LOG_HEAD + "\n\n" + ROUND_HEAD + "1 — builder-A\n"
		+ "changed   a.gd +1 -0\nwhy       the plan\nclosed    n/a\nnot closed  none\nnets 10 checks\n")
	t.eq(blocks_missing_fields(full).size(), 0, "다섯 칸을 다 채운 블록은 안 잡는다 (스캐너 자가 점검)")

	# ⚠ The row this net exists for. An absent `not closed` reads as an absent problem.
	var no_open := full.replace("not closed  none\n", "")
	t.eq(blocks_missing_fields(no_open).size(), 1,
		"`not closed` 가 빠진 블록을 잡는다 (스캐너 자가 점검)")

	# A second block that is short must be caught even when the first one is complete — a scan that
	# stopped at the first heading would stay green here.
	var two := full + "\n" + ROUND_HEAD + "2 — builder-B\nchanged   b.gd +2 -0\n"
	t.eq(blocks_missing_fields(two).size(), 1,
		"앞 블록이 멀쩡해도 뒤 블록의 결함을 잡는다 (스캐너 자가 점검)")

	# A block after the log section has closed is not a round block at all.
	var after := full + "\n## 9. Something else\n\n" + ROUND_HEAD + "3 — nobody\nchanged x\n"
	t.eq(blocks_missing_fields(after).size(), 0,
		"기록 절이 끝난 뒤의 제목은 라운드로 안 센다 (스캐너 자가 점검)")

	t.ok(has_open_questions("# p\n\n## 0. " + OPEN_MARK + " — whatever\n"),
		"질문 절을 찾는다 (스캐너 자가 점검)")
	t.ok(not has_open_questions("# p\n\n## 0. What is settled\n"),
		"질문 절이 없으면 없다고 한다 — 전부 빨개지는 스캐너가 아니다 (스캐너 자가 점검)")

	t.eq(sent_state("# p\n\n" + SENT_LINE + " yes, in one message\n"), "yes",
		"보냈다고 적힌 것을 읽는다 (스캐너 자가 점검)")
	t.eq(sent_state("# p\n\n" + SENT_LINE + " NO — never sent\n"), "no",
		"안 보냈다고 적힌 것을 읽는다 (스캐너 자가 점검)")
	t.eq(sent_state("# p\n\nnothing about it\n"), "",
		"안 적혀 있으면 빈 값이다 — 없는 것과 「아니오」는 다른 상태다 (스캐너 자가 점검)")


# -- io ---------------------------------------------------------------------------------------------------
func _plan_files() -> Array[String]:
	var out: Array[String] = []
	for dir_path: String in PLAN_DIRS:
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for f: String in d.get_files():
			if f.ends_with(".md") and f != "README.md":
				out.append(dir_path.path_join(f))
	return out


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()
