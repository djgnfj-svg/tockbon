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
##
## **Round 2 of the same ticket adds the two columns beside `names`** — five aptitudes (적성) and a hunger
## (허기) per body — and **the run seed** that makes the aptitudes reproducible. The failures this half
## guards: an aptitude column whose stride drifts from five (body 1's 요리 reads body 0's 벌목), a birth roll
## outside 0..`APTITUDE_BORN_MAX` (「요리 7/10」 on a newborn), and **a seed set AFTER `add_starting_force`** —
## the four starting bodies are recruited inside that call, so a late seed leaves the only four bodies the game
## has non-deterministic while an `Army`-only net stays green. ⇒ The determinism rows drive `Run`, never a
## bare `Army`.


func run(t) -> void:
	_the_instrument(t)
	_the_list(t)
	_the_order(t)
	_the_army_names_every_body(t)
	_the_aptitude_words_and_scale(t)
	_the_army_rolls_every_body(t)
	_the_seed_through_run(t)
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


## True when `v` is a legal birth roll: `0 .. Rules.APTITUDE_BORN_MAX` inclusive. **Inverted below before it
## is trusted** — the two neighbours just outside the range must be refused, or the range row measures nothing.
static func _born_roll_ok(v: int) -> bool:
	return v >= 0 and v <= Rules.APTITUDE_BORN_MAX


## The five words, their order, and the two scales — **literals, because the user said them**: 「요리 · 제작 ·
## 낚시 · 채광 · 벌목」, 「영에서 십이고」, and 「네」 to a birth roll of 0~3. The panel reads the words from
## `Rules.APTITUDES` at draw time and prints `/APTITUDE_MAX`, so a word retyped elsewhere or a scale that moved
## would put a different panel on screen with every count row still green.
## ⚠ Mutation: swap two words → the order row; `APTITUDE_BORN_MAX := 10` → the 「낳는 최대는 열보다 작다」 row.
func _the_aptitude_words_and_scale(t) -> void:
	t.eq(Rules.APTITUDES, ["요리", "제작", "낚시", "채광", "벌목"], "적성 다섯 낱말과 그 순서 (리터럴 — 사용자의 말)")
	t.eq(Rules.APTITUDES.size(), 5, "적성은 다섯이다 (리터럴)")
	t.eq(Rules.APTITUDE_MAX, 10, "적성의 눈금 끝은 열이다 (리터럴 — 「영에서 십이고」)")
	t.eq(Rules.APTITUDE_BORN_MAX, 3, "태어날 때 최대는 셋이다 (리터럴 — 「0~3 무작위」에 「네」)")
	t.ok(Rules.APTITUDE_BORN_MAX < Rules.APTITUDE_MAX, "낳는 최대는 열보다 작다 — 아니면 범위 검사가 아무것도 못 잰다")
	t.eq(Rules.HUNGER_MAX, 100.0, "허기의 가득은 100 이다 (리터럴)")
	# The instrument, inverted first.
	t.ok(_born_roll_ok(0), "계기 자가 점검: 0 은 통과한다")
	t.ok(_born_roll_ok(Rules.APTITUDE_BORN_MAX), "계기 자가 점검: 낳는 최대 그 자체는 통과한다")
	t.ok(not _born_roll_ok(-1), "계기 자가 점검: -1 은 걸린다")
	t.ok(not _born_roll_ok(Rules.APTITUDE_BORN_MAX + 1), "계기 자가 점검: 낳는 최대 더하기 하나는 걸린다")
	# Defense: no body has any, and the panel prints that stored truth rather than a sample.
	var nonzero := 0
	for ty in Rules.UNITS.size():
		if Rules.defense_of(ty) != 0.0:
			nonzero += 1
	t.eq(Rules.UNITS.size(), 2, "몸의 표는 두 줄이다 (자가 점검 — 방어력 줄이 둘을 다 돌았다는 뜻)")
	t.eq(nonzero, 0, "모든 줄의 방어력이 0.0 이다 — 아직 아무 몸도 방어력을 안 가진다")


## `Army` rolls five aptitudes and fills one hunger for every body on both paths that add a row, and neither
## column falls out of step with `type_id`. ⚠ Mutation: drop the five appends from `recruit` → the size rows;
## `randi_range(0, 10)` → the range row (with near certainty over twenty-five rolls); return `aptitudes[i + k]`
## from `aptitude_of` → the stride row.
func _the_army_rolls_every_body(t) -> void:
	var a := Army.new()
	t.eq(a.aptitudes.size(), 0, "새 군대는 적성 칸이 비어 있다 (자가 점검)")
	t.eq(a.hunger.size(), 0, "새 군대는 허기 칸이 비어 있다 (자가 점검)")
	a.add_starting_force()
	var n5 := Rules.APTITUDES.size()
	t.eq(a.aptitudes.size(), n5 * a.type_id.size(), "시작 병력 뒤 적성 칸 길이가 몸 수의 다섯 배다")
	t.eq(a.hunger.size(), a.type_id.size(), "시작 병력 뒤 허기 칸 길이가 몸 수와 같다")
	var id := a.recruit(0)
	t.ok(id >= 0, "한 몸을 더 뽑았다 (자가 점검)")
	t.eq(a.aptitudes.size(), n5 * a.type_id.size(), "뽑은 뒤에도 적성 칸 길이가 몸 수의 다섯 배다")
	t.eq(a.hunger.size(), a.type_id.size(), "뽑은 뒤에도 허기 칸 길이가 몸 수와 같다")
	var out_of_range := 0
	var stride_wrong := 0
	var not_full := 0
	for i in a.type_id.size():
		for k in n5:
			var v := a.aptitude_of(i, k)
			if not _born_roll_ok(v):
				out_of_range += 1
			# The accessor and the flat column agree on where body `i`'s `k`-th aptitude lives.
			if v != int(a.aptitudes[i * n5 + k]):
				stride_wrong += 1
		if a.hunger_of(i) != Rules.HUNGER_MAX:
			not_full += 1
	t.eq(out_of_range, 0, "모든 적성이 태어날 때 0..낳는 최대 안에 있다")
	t.eq(stride_wrong, 0, "aptitude_of(i, k) 는 평평한 칸의 i×5+k 를 읽는다 — 보폭이 다섯이다")
	t.eq(not_full, 0, "모든 몸의 허기가 가득(HUNGER_MAX)이다 — 여기서는 아무것도 안 깎는다")


## **The seed, and it is measured through `Run`.** `Run.new()` draws a seed; `restart(s)` takes one; the army is
## seeded BEFORE `add_starting_force`, so two runs on seed 7 roll the same twenty aptitudes for the same four
## bodies, and seed 8 rolls different ones. A bare `Army` seeded by hand would stay green with the seed line
## moved below `add_starting_force` in `run.gd` — which is exactly the defect this guards.
## ⚠ Mutation: move `army.seed(seed)` under `army.add_starting_force()` → the 「같은 시드, 같은 스무 적성」 row;
## ignore `seed_in` and always draw → the same row plus the read-back row.
func _the_seed_through_run(t) -> void:
	var r1 := Run.new()
	t.ok(r1.seed >= 0, "시드 없이 열면 하나를 뽑는다 — -1 (뽑아라는 표) 이 그대로 남아 있지 않다")
	r1.restart(7)
	t.eq(r1.seed, 7, "restart(7) 뒤 Run.seed 가 7 을 돌려준다")
	t.eq(r1.army.type_id.size(), 4, "시작 병력은 넷이다 (자가 점검 — 스무 적성이 재려면)")
	t.eq(r1.army.aptitudes.size(), 20, "넷의 적성은 스물이다 (리터럴)")
	var r2 := Run.new()
	r2.restart(7)
	t.eq(r2.army.aptitudes, r1.army.aptitudes, "같은 시드 7 로 두 번 열면 스무 적성이 똑같다")
	var r3 := Run.new()
	r3.restart(8)
	t.eq(r3.seed, 8, "restart(8) 뒤 Run.seed 가 8 을 돌려준다")
	t.ok(r3.army.aptitudes != r1.army.aptitudes, "시드 8 은 시드 7 과 다른 스무 적성을 준다")
	# Names do not move with the seed: the list is handed out in order regardless, so the two columns are
	# independent — a seed that also reordered names would be a second rule nobody asked for.
	t.eq(r3.army.names, r1.army.names, "시드가 달라도 이름 순서는 같다 — 이름은 목록 순서, 적성만 시드다")
	# A no-seed restart draws again; two draws are allowed to coincide, so only 「not the sentinel」 is pinned.
	r3.restart()
	t.ok(r3.seed >= 0, "시드 없이 다시 열어도 하나를 뽑는다")
