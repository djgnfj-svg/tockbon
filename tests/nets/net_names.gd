extends RefCounted
## The names a body arrives with, in the sim alone: the list `Names` hands out, the order it hands them in,
## and that `Army` gives every body one. **No tree, no view, no shell** — every object here is built with
## `.new()`. The screen half of ticket 03-02 (the corner panel) is `net_panel`'s; this file never reads a font.
##
## ⚠ **What this file guards** (ticket 03-02, 2026-09-02): the user asked for names drawn from a list
## (「이름은 목록에서 뽑자」), and the two failures that pass every other net are **a list that repeats a
## name** (two bodies alike on screen with nothing barking) and **a name column that drifts from the other
## columns** — `recruit` and `add_starting_force` are the only writers of `type_id`, and a `names` array one
## row short indexes the wrong body forever, silently. Both are measured below.


func run(t) -> void:
	_the_instrument(t)
	_the_list(t)
	_the_order(t)
	_the_army_names_every_body(t)
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies half way still reports every
	# check it managed first, in a shape a healthy net cannot be told from.
	t.done()


## True when `s` is exactly two precomposed Hangul syllables (U+AC00..U+D7A3). **The instrument for
## `_the_list`, and it is inverted first** — a check written to catch a defect has shipped carrying that
## same defect twice (`tests/README`).
static func _two_hangul(s: String) -> bool:
	if s.length() != 2:
		return false
	for i in 2:
		var c := s.unicode_at(i)
		if c < 0xAC00 or c > 0xD7A3:
			return false
	return true


## Every check below leans on `_two_hangul` and on "no two alike", so both are shown to bite before they
## are trusted. ⚠ Mutation: make `_two_hangul` return `true` — the four negative rows go red.
func _the_instrument(t) -> void:
	t.ok(_two_hangul("돌쇠"), "계기 자가 점검: 한글 두 음절은 통과한다")
	t.ok(not _two_hangul("돌"), "계기 자가 점검: 한 음절은 걸린다")
	t.ok(not _two_hangul("돌쇠야"), "계기 자가 점검: 세 음절은 걸린다")
	t.ok(not _two_hangul("ab"), "계기 자가 점검: 로마자 둘은 걸린다")
	t.ok(not _two_hangul("돌a"), "계기 자가 점검: 한글 하나에 로마자 하나도 걸린다")
	t.ok(not _two_hangul("ㄱㄴ"), "계기 자가 점검: 낱자(자모)는 음절이 아니라 걸린다")


## The list itself: forty, none twice, each two Hangul syllables. **The count is the literal the plan
## names**, never `LIST.size()` compared to itself.
## ⚠ Mutation: duplicate one entry → the 「두 번 없다」 row; append a one-syllable name → the syllable row.
func _the_list(t) -> void:
	t.eq(Names.LIST.size(), 40, "이름 목록은 마흔이다 (리터럴)")
	var seen := {}
	var dup := 0
	var bad := 0
	for i in Names.LIST.size():
		var n := String(Names.LIST[i])
		if seen.has(n):
			dup += 1
		seen[n] = true
		if not _two_hangul(n):
			bad += 1
	t.eq(dup, 0, "목록에 같은 이름이 두 번 없다")
	t.eq(bad, 0, "목록의 모든 이름이 한글 두 음절이다")
	t.eq(String(Names.LIST[0]), "돌쇠", "첫 이름은 돌쇠다 (리터럴 — 계획이 적은 순서의 머리)")
	t.eq(String(Names.LIST[39]), "봉이", "마지막 이름은 봉이다 (리터럴 — 계획이 적은 순서의 꼬리)")


## `Names.next(taken)`: unused first, in list order; when every name is taken, cycle from the head.
## ⚠ Mutation: return `LIST[0]` always → the forty-distinct row; cycle from `LIST[taken.size()]` without
## the modulo → the forty-first call reads past the end.
func _the_order(t) -> void:
	t.eq(Names.next(PackedStringArray()), String(Names.LIST[0]), "아무도 없으면 첫 이름이다")
	var taken := PackedStringArray()
	var distinct := {}
	for _i in 40:
		var n := Names.next(taken)
		distinct[n] = true
		taken.append(n)
	t.eq(distinct.size(), 40, "마흔 번 받아 오면 마흔 개가 다 다르다")
	t.eq(taken, Names.LIST, "그리고 그 순서는 목록의 순서 그대로다")
	var n41 := Names.next(taken)
	t.eq(n41, String(Names.LIST[0]), "마흔한 번째는 첫 이름을 다시 준다 — 목록이 다 차면 돈다")
	taken.append(n41)
	t.eq(Names.next(taken), String(Names.LIST[1]), "마흔두 번째는 둘째 이름이다")
	# The gap rule, not only the tail rule: a hole in the middle of `taken` is filled before anything after it.
	var holed := PackedStringArray()
	for i in 5:
		if i != 2:
			holed.append(String(Names.LIST[i]))
	t.eq(Names.next(holed), String(Names.LIST[2]), "가운데 비면 그 자리부터 준다 — 끝에 잇는 것이 아니다")


## `Army` gives every body a name on the two paths that add a row, and the column never falls out of step
## with `type_id`. ⚠ Mutation: drop the `names.append` from `recruit` → the size row after the recruit;
## fill with `LIST[0]` → the 「두 몸이 같은 이름」 row.
func _the_army_names_every_body(t) -> void:
	var a := Army.new()
	t.eq(a.names.size(), 0, "새 군대는 이름 칸이 비어 있다 (자가 점검)")
	a.add_starting_force()
	t.ok(a.type_id.size() > 1, "시작 병력은 둘 이상이다 (자가 점검 — 「다 다르다」가 재려면 둘은 있어야 한다)")
	t.eq(a.names.size(), a.type_id.size(), "시작 병력 뒤 이름 칸 길이가 몸 수와 같다")
	var id := a.recruit(0)
	t.ok(id >= 0, "한 몸을 더 뽑았다 (자가 점검)")
	t.eq(a.names.size(), a.type_id.size(), "뽑은 뒤에도 이름 칸 길이가 몸 수와 같다")
	var seen := {}
	var empty := 0
	var alike := 0
	for i in a.type_id.size():
		var n := a.name_of(i)
		if n.is_empty():
			empty += 1
		if seen.has(n):
			alike += 1
		seen[n] = true
	t.eq(empty, 0, "모든 몸이 이름을 가진다")
	t.eq(alike, 0, "두 몸이 같은 이름을 안 가진다")
	t.eq(a.name_of(0), String(Names.LIST[0]), "첫 몸은 목록의 첫 이름이다")
	t.eq(a.name_of(id), String(Names.LIST[id]), "새로 뽑은 몸은 목록에서 그 다음 안 쓴 이름을 받는다")
	# Two armies do not share a taken list — each run's first body is 돌쇠 again.
	var b := Army.new()
	b.add_starting_force()
	t.eq(b.name_of(0), a.name_of(0), "다른 군대의 첫 몸도 첫 이름이다 — 쓴 목록은 군대마다다")
