extends RefCounted
## The roster tables, in the sim alone: what a run OPENS with, which slot holds which species, and
## that `Rules.UNITS` still names its own rows. **No tree, no view, no shell** — every object here is
## built with `.new()`.
##
## ⚠⚠ **THIS FILE IS WHAT SURVIVED `net_summon`** (2026-08-29). That net measured the sea summon — the
## band a press opened, the landing it derived, the route a boat sailed and `Battle.summon`'s seven
## refusals — and **all of it went with the boats**. These two rows were the only ones in it that were
## never about a boat, and they are the barking device `rules.gd`'s own header asks for: renumbering
## `UNITS` renumbers every spawn character at once with nothing else to say so.


func run(t) -> void:
	_the_run_slots(t)






# -- R1 --------------------------------------------------------------------------------------------
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies
	# half way still reports every check it managed first, in a shape a healthy net cannot be told from.
	t.done()

## ⚠⚠ **THE SLOTS ARE RUN STATE NOW AND THIS ROW MOVED WITH THEM.** `Rules.SUMMON_SLOTS` was a
## CONSTANT table saying 「칸 s 는 영원히 종 t 에 묶여 있다」, and that sentence stopped being true the
## day a card could fill a slot — a constant holding a per-run fact is a shape this repo has paid for.
## What survives is the three lessons its header carried, and they are all below.
##
## ⚠⚠ **THE CARD THAT ORIGINALLY JUSTIFIED THIS MOVE IS DELETED** (2026-08-27 — the BEAST CARD, table
## and mechanism together; `CardKind` is one member wide now and every card is an item). **The move
## itself is NOT reverted and this row is not weakened**, because the reason it was made is not the
## only reason it holds: `Army.register_species` is still a live door that changes the slot count
## while a run is being played — 티켓 15's 「슬롯 자체를 강화한다」 economy and the raid path both open
## it — and a `const` table cannot answer a question whose answer moves. ⚠ **What IS now false is the
## historical clause above**: as of today nothing in `src/` fills a slot mid-run, so the four
## registration rows below are the only thing measuring that door. **They are written down here
## rather than argued away**: if that door is ever closed too, this whole row is what should be
## re-read before `Army.slots` is folded back into a constant.
##
## ⚠ Mutation: put an enemy row in a slot; count slots with a literal; answer `0` for an empty slot.
func _the_run_slots(t) -> void:
	# ⚠⚠ **THE COUNT IS PINNED AGAINST THE ARMY AND THE OPENING TABLE'S SIZE IS THE LITERAL**, never
	# the other way round — pinning both to one number moves them together and passes at any value.
	var a := Army.new()
	a.add_starting_force()
	t.eq(Rules.START_SLOTS.size(), 1, "회차는 표의 한 줄로 연다 (리터럴)")
	t.eq(a.slot_count(), Rules.START_SLOTS.size(), "그리고 새 군대의 칸 수는 그 표가 정한다")
	t.eq(Rules.roster_start_count(), 10,
		"시작 병력은 열이다 (리터럴) — 작은 섬 넷의 밀도가 전부 이 열에 맞춰져 있다")
	# ⚠⚠ **REPAIRED 2026-08-28 — this said WOLF from before the 2026-08-26 side swap** (`START_SLOTS`
	# used to open on ten wolves; the opening roster is `[[SWORDSMAN, 10]]` today, per `rules.gd`).
	t.eq(a.slot_type_of(0), Rules.SWORDSMAN, "1번 칸은 검사다")

	# Lesson 1: **the answer for an empty slot is `SUMMON_UNBOUND` and never 0.** There IS a row 0,
	# so a `0` here summons the squirrel with every bounds check downstream still passing.
	t.eq(a.slot_type_of(a.slot_count()), Rules.SUMMON_UNBOUND, "칸 끝 너머는 비어 있다고 답한다")
	t.eq(a.slot_type_of(-1), Rules.SUMMON_UNBOUND, "아래쪽 범위 밖도 마찬가지다")
	t.ok(a.slot_type_of(a.slot_count()) < 0, "그 답은 음수다 — `< 0` 로 검사해야 하는 이유가 이것이다")

	# Lesson 2: **an enemy row cannot be registered.** The old header said binding one 「reads as done
	# and ships enemy bodies as the player's army」; there is a door to try it through now.
	var enemy := Rules.player_type_count()
	t.eq(Rules.side_of(enemy), Rules.Side.ENEMY, "%d 번이 적 줄이다 (자가 점검)" % enemy)
	var before := a.slot_count()
	t.eq(a.register_species(enemy), -1, "적 편 종은 칸에 못 들어간다")
	t.eq(a.slot_count(), before, "그리고 거절이라 칸 수도 그대로다 — 아무것도 안 변했다")

	# Lesson 3: **one species, at most one slot.**
	# ⚠ **REPAIRED 2026-08-28 — this registered WOLF, which was never in a slot to begin with** (slot 0
	# holds SWORDSMAN, not WOLF — see the fix above), so it was accidentally re-testing Lesson 2 (the
	# enemy refusal) rather than the "already registered" refusal this row is named for.
	t.eq(a.register_species(Rules.SWORDSMAN), -1, "이미 등록된 종은 두 번째 칸에 못 들어간다")
	t.eq(a.slot_count(), before, "그것도 아무것도 안 바꿨다")

	# The floor under those three ceilings: a legal registration DOES land.
	# ⚠⚠ **REPAIRED 2026-08-28 — BEAR is enemy-side today** (`rules.gd`'s `UNITS` puts it on
	# `Side.ENEMY`), so `register_species(BEAR)` was refused for the same reason Lesson 2 already
	# covers — it never reached the floor this row is named for. **There is no second player-side row
	# to register against `a`**: `Rules.UNITS` carries exactly one, SWORDSMAN, already sitting in `a`'s
	# slot 0. The floor is driven on a fresh, empty Army instead — the first-ever registration into a
	# blank roster, which is the real shape "a legal registration lands" happens in today.
	var blank := Army.new()
	t.eq(blank.slot_count(), 0, "새 군대는 칸이 비어 있다 (자가 점검)")
	var got := blank.register_species(Rules.SWORDSMAN)
	t.eq(got, 0, "안 등록된 아군 종은 다음 빈 칸으로 들어간다 (자가 점검)")
	t.eq(blank.slot_count(), 1, "그리고 칸이 하나 늘었다")
	t.eq(blank.slot_type_of(got), Rules.SWORDSMAN, "그 칸이 그 종이다")

	# The ceiling on the ceiling: `SUMMON_SLOT_MAX` refuses once slots are full, and nothing changes
	# when it does.
	# ⚠⚠ **REPAIRED 2026-08-28 — looping `register_species` over `player_type_count()` cannot reach
	# five slots any more.** `Rules.UNITS` carries exactly ONE player-side row (SWORDSMAN); the loop
	# this replaced registered slot 0, then spent four more iterations re-registering the same species
	# and being refused by Lesson 3 — `full.slot_count()` stalled at 1 forever, and the row asserting
	# 5 had gone permanently unreachable the day the human roster collapsed to one type (CONTEXT.md).
	# **`SUMMON_SLOT_MAX` itself is still real and still five** (`Army.slots` and the raid path can grow
	# a roster mid-run, per `rules.gd`'s own note); it is driven here directly on `slots`, a public
	# field a real caller never pokes but a check aimed only at the CEILING clause may, so the
	# registration attempt below hits `slots.size() >= SUMMON_SLOT_MAX` and nothing upstream of it —
	# filler entries are deliberately not SWORDSMAN, so Lesson 3's "already registered" refusal cannot
	# be the one firing instead.
	var full := Army.new()
	var packed := PackedInt32Array()
	for _i in Rules.SUMMON_SLOT_MAX:
		packed.append(Rules.WOLF)
	full.slots = packed
	t.eq(full.slot_count(), Rules.SUMMON_SLOT_MAX, "다섯 칸이 차면 칸 수도 상한만큼이다 (자가 점검)")
	t.eq(full.register_species(Rules.SWORDSMAN), -1, "찬 칸에는 등록 안 된 종도 새로 못 들어간다 — 상한이 문다")
	t.eq(Rules.SUMMON_SLOT_MAX, 5, "그 상한은 다섯이다 (리터럴)")




