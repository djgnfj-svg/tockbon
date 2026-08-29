extends RefCounted
## The session: the card round a run opens on, the roster it carries across an island, and the two
## ways to lose.
##
## **The half of this that matters is that HP carries by IDENTITY and not by count.** A `begin_island`
## that built a fresh `Army` for every island would heal every wound, resurrect every corpse and drop
## every fitted item, and a check that only counted soldiers would stay green through all of it — the roster
## is the same size either way. So every carry-over assertion below names a specific id and reads a
## specific value, and the object itself is compared with `==` so a copied roster is a red rather than
## a coincidence. Rebuilding the roster inside `begin_island` reddens seven checks here.
##
## ⚠⚠ **THE NODE MAP IS DELETED AND FIVE THINGS IN THIS FILE DIED WITH IT** (2026-08-26 for the map,
## 2026-08-27 for the last of these). None of them are coming back as written; what they knew is here.
##
##  · **`Run.island_index` and the row 「`finish_island(true)` 는 `island_index` 를 혼자 안 옮긴다」** —
##    the run's position used to be a counter, then `map.at()`, and the row existed for one mutation:
##    putting `island_index += 1` back into `_advance`. **The map would appear, the run would ignore
##    it, and every check that only counted islands would stay green.** ⚠ The field does not exist in
##    `run.gd` any more (grepped 2026-08-27, no reader and no writer anywhere in `src/`), and **there
##    is exactly one island**, so a position has nothing to be a position among.
##
##  · **`ISLE1_LANDING_X` / `_Y` / `ISLE1_W` (28, 20, 48)** — island 1's cheapest sendable tile from its
##    start harbour, as a hand literal. ⚠⚠ **It was already dead before the map**: the day the first
##    node stopped opening island 1 that literal named WATER on a map 24 wide, and it was replaced by a
##    search on the grid in front of it. **A landing a suite hard-codes is a landing that describes one
##    map** — see `_summonable_water_on`, which is that search and still stands.
##
##  · **`ROUTE_ALL_CELLS` / `ROUTE_TWO_BEAKS` and the two route walks** — 「경로가 다르면 명부가
##    다르다」, two whole runs by the two extreme routes of the seven-node graph, and what came out the
##    other end had to DIFFER. ⚠⚠ **It was a FLOOR and not a ceiling, and the reason is the one worth
##    keeping: a map whose routes all produce the same roster is a corridor with pictures on it, and
##    that is the exact shape that killed this repo's second game — an advantage with no cost is not a
##    decision.** The names were already historical (`ROUTE_TWO_BEAKS`'s two nodes paid the beak until
##    2026-08-25, when the user deleted that reward).
##
##  · **`_the_route_is_what_the_board_holds` and its `fit_into_slot0` policy** — §8.4's 「경로가 다르면
##    명부만이 아니라 판도 다르다」. ⚠ **The fixed fit policy was the whole trick**: without it two
##    boards fitted by two different hands differ for a reason that has nothing to do with the map.
##    ⚠⚠ **It was deliberately UNSEEDED and that was measured, not sloppy**: both routes were 5 nodes
##    and 4 non-boss wins, every win paid the same number of cards, so a SEEDED run drew the identical
##    card sequence on both routes and the two boards came out guaranteed equal. It failed 100% of
##    seeded runs, not flakily.
##
##  · **The `Reward` / `Run.State` / `NodeKind` key rows** — ⚠⚠ **MEASURED 2026-08-25: putting `BEAK`
##    back into `Reward`, and `REWARD` back into `Run.State`, left the WHOLE ROUND GREEN at 3231
##    checks.** The payouts were closed; the WORDS were not. **A member nobody pays yet costs nothing
##    today and is exactly how a deleted mechanic comes back one file at a time.** ⚠ That is not
##    tidiness: `panel_view.panel_active`'s own header argues for an ALLOW-list because **one added
##    `Run.State` member breaks it five ways at once** — a red band painting over the live screen while
##    `panel_active()` reads true. `Run.State` still has five members and nothing here watches them;
##    **the day a sixth is added, this paragraph is the argument for putting that row back.**
##
## Nothing here drives a fight to its natural end. Winning an island honestly takes a real battle and
## that is `net_battle`'s job; this file calls `finish_island(true)` directly, which is the same door
## the shell uses, and drives `battle.step` only for the two LOSSES — those are the ones the session
## has to read off the fight rather than be told.


## ⚠⚠ **`_take_the_card_and_close_refit` STOOD HERE AND IS DELETED** (2026-08-28) with the round it
## walked through. A win goes straight to `WON`.



func run(t) -> void:
	_starting_state(t)
	_hp_carries_by_identity(t)
	_wipe_loses(t)
	_the_clock_ends_nothing(t)
	_restart_resets(t)
	# -- the run's own shape ---------------------------------------------------------------------------
	# ⚠⚠ **THE WHOLE CARD SECTION IS DELETED** (2026-08-28, the user: 「고르는 창도 이제 필요 없는데
	# 왜있지? 이것도 제거」 · 「둘 다 지우면 돼」). 티켓 15's six rows had already fallen to three when
	# the beast card went; the three that were left — the round a run opens on, where a taken card
	# sends the run, and that no card moves a slot or a body — are gone with the round itself.
	_a_run_opens_on_the_island(t)


# -- 티켓 15 fix: one round never shows the same animal twice -------------------------------------------
## ⚠⚠ **DELETED 2026-08-27 WITH THE BEAST CARD, AND THE MEASUREMENT IS WORTH KEEPING IN WORDS.**
## `_no_species_stands_twice_in_one_round` (and its `_has_duplicate_species` helper) walked 600 seeded
## rounds and read the SPECIES a round dealt: **64% of opening rounds held a duplicate and 6% were
## three of one animal** before the pool was drawn without replacement, which is a three-card screen
## that says 「골라」 and means 「받아」. It measured `Rules.CardKind.SPECIES` and the species pool
## behind it, and **both are gone** — `CardKind` has one member and no card names a species at all.
##
## ⚠ **An item may honestly repeat**, so this row does not come back as-is for the item draw. The day
## a card draws from a pool of unique things again, this is the row to rebuild first — `run.gd`'s own
## `_draw_cards` header says the same thing from the other side.


## ⚠⚠ **`_cards_add_no_slot_and_no_body` IS DELETED** (2026-08-28) with the cards. Its measurement
## is worth keeping in words: **a card never added a summon slot and never added a body** — that
## claim outlived the beast card, and it dies here with the card table itself.

func _a_run_opens_on_the_island(t) -> void:
	var r := Run.new()
	t.eq(r.state(), Run.State.BATTLE, "새 회차는 섬에서 연다")
	t.ok(r.begin_island() != null, "그래서 섬이 곧장 열린다 — 지나갈 화면이 없다")
	t.eq(r.army.slot_count(), 1, "칸 하나로 연다")
	# ⚠⚠ **늑대가 아니라 검사다** (2026-08-27). `Rules.START_SLOTS` 의 한 줄은 `SWORDSMAN` 이고, 늑대는
	# 편이 바뀌면서 적 줄로 갔다.
	t.eq(r.army.slot_type_of(0), Rules.SWORDSMAN, "그 칸은 검사다")
	t.eq(r.army.living_count(), 10, "검사 열 명이다 (리터럴 — 섬의 적 밀도가 이 열에 맞춰져 있다)")

	# ⚠⚠ **A WIN ENDS THE RUN, AND IT USED TO DEAL THREE CARDS FIRST** (2026-08-28). The rows that
	# stood here read the dealt round back — three cards, all equipment, and the same three under the
	# same seed. **The deal, the seed and the screen are all deleted.**
	r.finish_island(true)
	t.eq(r.state(), Run.State.WON, "섬을 이기면 곧장 WON 이다 — 사이에 낀 화면이 없다")


## ⚠⚠ **`_an_item_card_moves_no_slot_and_opens_refit` IS DELETED** (2026-08-28) with the card round
## and the refit board. It measured that an equipment card recruits nobody and that the fork out of
## `take_card` reads the HELD PILE rather than the card's kind — **that fork is the shape worth
## remembering**: branching on the kind makes two paths out of one screen, and a card that paid no
## item, taken while an earlier item was unfitted, would strand that item.


func _starting_state(t) -> void:
	var r := Run.new()
	# ⚠⚠ 「런은 섬에서 시작한다」 (티켓 12, 2026-08-27) — it opened on the map until 2026-08-26, then on a
	# card round until 티켓 12 took that round off the start path. `_a_run_opens_on_the_island` drives
	# the screen itself; this row measures the opening roster, which is what it always measured.
	t.eq(r.state(), Run.State.BATTLE, "시작 상태는 섬이다")
	t.eq(r.army.living_count(), Rules.roster_start_count(), "시작 병력은 10")
	# ⚠⚠ **「열 마리 전부 늑대다」 였고 늑대는 이제 적이다.** 개막 표가 세우는 몸은 검사 열이고, 회차가
	# 짐승을 몸으로 갖는 길은 없어졌다 — 「까마귀는 카드로 온다」 던 아래 줄은 그 카드가 지워지면서 (2026-08-27)
	# 주어를 잃었다. 남긴 것은 그 줄이 실제로 재던 것: **적 편 종은 명부에 한 마리도 없다.**
	t.eq(r.army.living_ids_of_type(Rules.SWORDSMAN).size(), Rules.start_bodies_of(0), "열 명 전부 검사다")
	t.eq(r.army.living_ids_of_type(Rules.WOLF).size(), 0, "늑대는 명부에 없다 — 짐승은 이제 적이고 카드로도 안 온다")


# -- the one that the plan names a mutation for ------------------------------------------------------

func _hp_carries_by_identity(t) -> void:
	# ⚠⚠ **THIS USED TO BE SEEDED AND THERE IS NOTHING LEFT TO SEED** (2026-08-28). An unseeded fixture
	# once registered a random second species off the opening round and a later beast card brought four
	# bodies into every roster count below — **measured: this net went red about one run in six on an
	# unchanged tree**. The cards are deleted, so a run's roster is the opening table and nothing else.
	var r := Run.new()
	var roster := r.army

	# Written through a local and assigned back: a Packed array is copy-on-write and a write into a
	# temporary would land nowhere while every read afterwards showed full health.
	var hp := roster.hp
	hp[3] = 5.0
	hp[9] = 2.5
	roster.hp = hp
	roster.kill(7)

	t.ok(r.army == roster, "섬을 넘어도 로스터 객체가 그대로다")
	# ⚠ **17 -> 14 -> 10.** 17 was the map's node reward, deleted 2026-08-26 with the map. 14 was the
	# ten the run opens with plus the four bodies the opening BEAST card brought, and **the beast card
	# is deleted 2026-08-27** — the opening card is equipment and pays no body, so the roster is the
	# opening ten and nothing else. **The claim this row makes has not moved**: one row is killed and
	# two are wounded, and all three are still standing there afterwards.
	t.eq(r.army.type_id.size(), 10, "죽은 줄은 남아서 개막 열 줄이 그대로 10줄이다")
	t.eq(r.army.living_count(), 9, "살아 있는 것은 9명")
	t.eq(r.army.hp[3], 5.0, "3번의 상처가 그대로 넘어왔다 — 수가 아니라 정체성이다")
	t.eq(r.army.hp[9], 2.5, "9번의 상처도 그대로다")
	t.eq(r.army.alive[7], 0, "7번은 여전히 죽어 있다 — 죽음은 영구다")
	t.eq(r.army.hp[7], 0.0, "죽은 7번의 HP 는 0이다")
	t.eq(r.army.type_id[3], Rules.SWORDSMAN, "3번의 병종도 바뀌지 않았다")


# -- the two ways to lose ------------------------------------------------------------------------------

## The wipe. Driven through `battle.step` rather than asserted, because "every soldier is dead" is a
## verdict the fight has to reach on its own — the session only reads it.
##
## ⚠⚠ **IT OPENED THE RUN'S OWN ISLAND UNTIL 2026-08-27 AND IT CANNOT ANY MORE.** `_phase_clock` asks
## 「are the enemies gone?」 FIRST, and **the board the user drew carries no spawn character at all** —
## so `begin_island()`'s fight is WON on its first sub-step and freezes there (`step` breaks out of the
## sub-step loop the moment the outcome is not RUNNING). Every row below would then be reading a fight
## that never ran. ⇒ **The island is loaded exactly as the run loads it and ONE beast is put on it by
## the fixture**, which is the smallest thing that makes a loss reachable at all.
## ⚠ **The day beasts are drawn onto the board this fixture should be re-read, not deleted**: what it
## exists to say is that a wipe is latched by the FIGHT, and that is true whoever placed the beast.
func _wipe_loses(t) -> void:
	var r := Run.new()
	var b := _island_with_one_beast(r.army)
	t.eq(b.outcome(), Battle.Outcome.RUNNING, "전투는 굴러가는 상태로 시작한다")
	t.eq(b.enemies_left(), 1, "픽스처가 짐승 한 마리를 세웠다 (자가 점검 — 0마리면 섬이 첫 칸에 이겨 버린다)")
	# The smallest plan there is, then the start button: without a commit `step` returns before
	# `_phase_clock` and the wipe would never be latched at all.
	# ⚠ This summoned one body and pressed 시작; **both went with the boats** (2026-08-29). A body is
	# stood on the island directly now, and the commit is what still opens the verdict.
	t.ok(b.place_ashore(0, Islands.home_tile()) >= 0 and b.commit(), "한 명을 섬에 세우고 시작했다 (자가 점검)")
	for i in range(r.army.type_id.size()):
		r.army.kill(i)
	t.eq(r.army.living_count(), 0, "병사가 하나도 안 남았다")

	b.step(0.1)
	t.eq(b.outcome(), Battle.Outcome.LOST, "병사가 다 죽으면 섬을 진다")
	t.eq(b.lose_reason(), Battle.Lose.WIPED, "패인은 전멸이다")
	t.ok(b.enemies_left() > 0, "적이 아직 남아 있다 — 적을 다 죽여서 끝난 게 아니다")


## The clock, through a real `Run`'s roster. One soldier is sent out and nine stay in reserve, which is
## the smallest plan a commit will accept.
##
## ⚠⚠ **THIS ROW HAS BEEN INVERTED TWICE AND THE SECOND INVERSION DELETED ITS SUBJECT.** It began as
## "the clock ends the island". 2026-08-24 turned it into "the clock ends nothing" (the user: 「제한 시간
## 안에 클리어 조건은 일단 지워」), still reading `Lose.TIMEOUT` and `time_left()` to say so.
## 2026-08-27 deleted `time_limit`, `time_left()` and `Lose.TIMEOUT` outright, and **a guard cannot
## watch a symbol that no longer exists.**
##
## ⇒ **What is left is the half that was never about the limit**: the clock runs, it runs a long way,
## and the island is still going. That is what makes "nothing ends by time" observable now — not the
## absence of an enum value, but an island that outlives any duration a limit would plausibly have had.
## ⚠ **The 5-second mark is a yardstick, not a rule.** Nothing in `src/` reads it; it is here so the
## number this row steps past is a number a reader can compare against.
## ⚠⚠ **AND THE YARDSTICK ONLY MEANS ANYTHING BECAUSE THE FIXTURE PUTS A BEAST ON THE ISLAND** — see
## `_wipe_loses`. On the empty board the fight is WON on sub-step one and `elapsed` never reaches a
## sixtieth of a second, so 「시계가 5초를 넘겼다」 would have been red for a reason that has nothing to
## do with a clock. **With one beast standing there the 5 seconds cannot be dodged whoever wins**: a
## swordsman needs six blows at 1.2 s to take 14 HP off a wolf, and a wolf needs nine at 1.0 s to take
## 18 off a swordsman — the shorter of the two is already past the yardstick before the crossing.
func _the_clock_ends_nothing(t) -> void:
	var r := Run.new()
	var b := _island_with_one_beast(r.army)
	t.eq(b.enemies_left(), 1, "픽스처가 짐승 한 마리를 세웠다 (자가 점검)")
	t.ok(b.place_ashore(0, Islands.home_tile()) >= 0 and b.commit(), "한 명만 섬에 세우고 시작했다 (자가 점검)")
	# ⚠ **One sub-step per call, never `step(1.0)`.** `step` consumes whole `Rules.SIM_SUBSTEP_SEC`
	# sub-steps and carries the leftover, so a 1.0 s call runs **59** of them and not 60 — the residue
	# after sixty subtractions lands a hair under the sub-step in IEEE double — and the run would need
	# a 61st call for a reason that is floating point rather than the clock.
	var yardstick := 5.0
	var steps := 0
	while b.outcome() == Battle.Outcome.RUNNING and steps < 8000:
		b.step(Rules.SIM_SUBSTEP_SEC)
		steps += 1

	# The one soldier either dies to the defenders — which is the WIPE arm and has nothing to do with
	# a clock — or the island is still running far past any limit it might once have carried.
	t.ok(b.outcome() != Battle.Outcome.LOST or b.lose_reason() == Battle.Lose.WIPED
			or b.lose_reason() == Battle.Lose.LANDING_LOST,
		"지는 길은 전멸과 상륙 병력 소멸뿐이다 — 시간으로 지는 길은 없다")
	t.ok(b.elapsed >= yardstick - Rules.EPS,
		"그런데 시계는 %.0f초를 넘겨 갔다 (%.6f초) — 안 돈 게 아니다" % [yardstick, b.elapsed])
	# ⚠⚠ **THE ROW 「적은 하나도 안 죽었다 — 한 명으로는 못 죽인다」 IS DELETED AND IT WAS A FALSE GREEN
	# WAITING TO HAPPEN.** It read `t.eq(b.enemies_left(), Islands.spawns().size())`, and both sides go
	# to **0** on the board the user drew — an emptied table making an equality true, which is the exact
	# shape this repo just found in `shove_tiles_of`. What it meant is now said where it can be false:
	# the fixture stands one beast up and asserts it, above.
	t.eq(Battle.Lose.keys(), ["NONE", "WIPED", "LANDING_LOST"],
		"지는 이유는 이 셋뿐이다 — 시간이라는 이름이 아예 없다 (이름까지 못 박는다: 크기만 재면 개명을 놓친다)")


# -- restart -------------------------------------------------------------------------------------------

## ⚠ **`Run.restart()` does not die with the title screen.** The shell builds a fresh `Run` for
## 시작하기 and never calls this — but it is the only thing keeping `_reset` honest about a field added
## to one path and forgotten in the other, which is exactly how a second run would start somewhere the
## first did not with nothing to bark about it.
func _restart_resets(t) -> void:
	var r := Run.new()
	var first := r.army
	var hp := first.hp
	hp[0] = 1.0
	first.hp = hp
	first.kill(1)
	r.finish_island(true)
	t.eq(r.state(), Run.State.WON, "재시작 전에는 끝난 상태다 — 승리가 곧장 WON 이다")




## The run's own island with **one wolf standing on it**, and the roster handed straight in so HP still
## carries by identity.
##
## ⚠⚠ **THE FIXTURE EXISTS BECAUSE AN EMPTY ISLAND IS ALREADY WON.** `Islands.spawns()` reads the board
## file, the board file holds no spawn character, and `_phase_clock` checks 「enemies gone」 before either
## loss — so a fight built the way `Run.begin_island` builds one latches WON on its first sub-step and
## every row that drives `step` afterwards is reading a frozen fight.
##
## ⚠ **Level 0 and not the plateau, deliberately.** `flow_field` honours `can_step`, so a beast standing
## two notches up is reachable only through the stair; that is a real and interesting property and it is
## `net_tiers`' business, not a thing these two rows should depend on.
func _island_with_one_beast(army: Army) -> Battle:
	var g := Grid.new()
	Islands.load_into(g)
	var tile := g.tile_index(5, 10)
	var b := Battle.new()
	b.setup(g, army, [{"type_id": Rules.WOLF, "tile": tile}])
	return b


## ⚠⚠ **`_opened` STOOD HERE AND IS DELETED** (2026-08-28). It walked a fixture past the OPENING
## CARD ROUND, which 티켓 12 took off the start path and which is now deleted outright.
