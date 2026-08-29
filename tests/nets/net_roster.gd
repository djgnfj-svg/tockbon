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
	_the_unit_table(t)






# -- R1 --------------------------------------------------------------------------------------------
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




# -- U1 --------------------------------------------------------------------------------------------
## **The barking device the unit table has never had.** `rules.gd`'s own header says renumbering
## `UNITS` renumbers every spawn character and every hotkey binding at once **with nothing to bark
## about it** — these rows are that bark.
##
## ⚠ Mutation: swap two rows of `UNITS`; move an enemy row above a player row.
func _the_unit_table(t) -> void:
	# Every id constant, paired with the identifier its own row carries. The pair list is a second
	# copy of nothing — the NAMES are what the table stores — but its LENGTH is, so the length is
	# pinned against the table: a row added without a pair here reddens this line before anything else.
	# ⚠⚠ **REPAIRED 2026-08-28.** This table pinned SQUIRREL · COW · SPEARMAN · ARCHER · SHIELDBEARER —
	# names from before ticket 15's rename and the 2026-08-26 side swap, both of which are long done.
	# `Rules.UNITS` carries exactly five rows today (see `rules.gd`), and the label a check hands to
	# `name_of` has to be the row's OWN identifier, never a name the row used to answer to — that is the
	# exact "이름을 바꾸면 그 이름으로 짜인 검사가 조용히 다른 것을 재기 시작한다" trap
	# (`how-nets-lie`), except this one at least reddened instead of passing quietly.
	var named := [
		[Rules.SWORDSMAN, "SWORDSMAN"],
		[Rules.WOLF, "WOLF"],
		[Rules.BEAR, "BEAR"],
		[Rules.CROW, "CROW"],
		[Rules.LION, "LION"],
	]
	t.eq(named.size(), Rules.UNITS.size(),
		"이 검사가 표의 모든 줄을 든다 — 줄이 늘면 여기가 먼저 문다 (자가 점검)")
	for raw in named:
		var pair: Array = raw
		t.eq(Rules.name_of(int(pair[0])), str(pair[1]),
			"%s 상수가 제 줄을 가리킨다" % str(pair[1]))

	# The side column, and the ordering contract that `Loadout`'s board index stands on.
	var players := 0
	var first_enemy := -1
	for i in Rules.UNITS.size():
		if Rules.side_of(i) == Rules.Side.PLAYER:
			players += 1
			t.ok(first_enemy < 0, "%d 번 아군 줄이 어떤 적 줄보다도 앞에 있다" % i)
		elif first_enemy < 0:
			first_enemy = i
	t.ok(players > 0 and players < Rules.UNITS.size(),
		"표에 아군 줄도 적 줄도 있다 — 한쪽만이면 아래 줄들이 공허하다 (자가 점검)")
	# ⚠ **어디에도 숫자로 안 박는다.** 아군 수는 표를 걸어서 나오고, 이 검사도 표를 걸어서 센다.
	t.eq(Rules.player_type_count(), players, "아군 종 수는 표를 세어서 나온다")
	for i in Rules.player_type_count():
		t.eq(Rules.side_of(i), Rules.Side.PLAYER,
			"아군 줄 번호가 0 부터 연속이다 — %d 번" % i)
	t.eq(Rules.side_of(Rules.player_type_count()), Rules.Side.ENEMY,
		"그리고 바로 다음 줄이 적이다 — 연속의 끝을 못 박는다")

	# ⚠⚠ **REPAIRED 2026-08-28 — TWO ROWS, NOT FOUR.** `rules.gd`'s own header claims only 늑대 · 까마귀
	# carry the numbers their pre-rename rows (`CELL_MELEE` / `CELL_RANGED`) carried; 궁수 · 방패병 ·
	# 창병 are not a lineage into WOLF/CROW at all — CONTEXT.md is explicit that the four human rows
	# were DELETED outright and SWORDSMAN's row was freshly interpolated between two of them. The two
	# extra rows this table used to carry (hp 6.0/range 3.0/area 0.0/speed 6.0 on CROW; hp 20.0/dmg
	# 3.0/period 2.0/speed 2.5 on a second WOLF) were typed in for that lineage that never existed and
	# only ever collided with the real rows below — deleted rather than repaired.
	#
	# ⚠ **DETECT moved from `NO_DETECT` to a real radius on both real rows** (rules.gd, 2026-08-26 —
	# "they gained a detect radius: an enemy has to notice something"), which is the one column this
	# table's own claim of "unchanged" does not cover; HP · DAMAGE · PERIOD · RANGE · AREA · SPEED are
	# still the values pinned here, typed in rather than read back — a check that asks the subject for
	# its expectation is this repo's named false green. 까마귀's damage in particular is pinned in no
	# other file, so changing it 1.5 -> 2.5 would redden only one HP-total line in `net_run` without this.
	#
	# ⚠ **The two that are NOT transplants are deliberately absent** — 곰 · 사자 are first
	# drafts the user is expected to move, and pinning them would turn a tuning pass into a rewrite.
	var moved := [
		# row                   hp    dmg  period range  area  speed  detect
		[Rules.WOLF,           14.0,  2.0,  1.0,   0.0,  0.0,  4.0,   6.0],
		[Rules.CROW,            8.0,  1.5,  1.0,   4.0,  1.0,  4.0,  12.0],
	]
	for raw2 in moved:
		var row: Array = raw2
		var ty := int(row[0])
		var who := Rules.label_of(ty)
		t.eq(Rules.hp_of(ty), float(row[1]), "%s 의 체력이 옮겨온 값 그대로다" % who)
		t.eq(Rules.damage_of(ty), float(row[2]), "%s 의 공격력이 옮겨온 값 그대로다" % who)
		t.eq(Rules.period_of(ty), float(row[3]), "%s 의 공격주기가 옮겨온 값 그대로다" % who)
		t.eq(Rules.range_of(ty), float(row[4]), "%s 의 사거리가 옮겨온 값 그대로다" % who)
		t.eq(Rules.area_of(ty), float(row[5]), "%s 의 범위가 옮겨온 값 그대로다" % who)
		t.eq(Rules.speed_of(ty), float(row[6]), "%s 의 이동속도가 옮겨온 값 그대로다" % who)
		t.eq(Rules.detect_of(ty), float(row[7]), "%s 의 시야가 옮겨온 값 그대로다" % who)
