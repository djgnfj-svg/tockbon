extends RefCounted
## The session: a run over the node map, the three rewards, the two ways to lose, and restart.
##
## **The half of this that matters is that HP carries by IDENTITY and not by count.** A `begin_island`
## that built a fresh `Army` for every island would heal every wound, resurrect every corpse and drop
## every fitted item, and a check that only counted soldiers would stay green through all of it — the roster
## is the same size either way. So every carry-over assertion below names a specific id and reads a
## specific value, and the object itself is compared with `==` so a copied roster is a red rather than
## a coincidence. Rebuilding the roster inside `begin_island` reddens seven checks here.
##
## ⚠ **The run no longer walks a line of islands and `island_index` is no longer its position.** The
## position is `map.at()`; `island_index` is only what `enter_node` last wrote, and `_advance` does not
## touch it. **The row that measures that is 「`finish_island(true)` 는 `island_index` 를 혼자 안
## 옮긴다」**, and the mutation it exists for is putting `island_index += 1` back into `_advance`: the
## map would appear, the run would ignore it, and every check that only counted islands would stay
## green. The graph itself — floors, edges, routes, reachability — is `net_map`'s.
##
## Nothing here drives a fight to its natural end. Winning an island honestly takes a real battle and
## that is `net_battle`'s job; this file calls `finish_island(true)` directly, which is the same door
## the shell uses, and drives `battle.step` only for the two LOSSES — those are the ones the session
## has to read off the fight rather than be told.


## Island 1's cheapest sendable tile from its start harbour, written as two literals. Both losses below
## have to COMMIT the island before `step` will do anything at all (`plan-then-watch`, 4.3), and a
## commit refuses a plan with no boats — so each of them authors the smallest plan there is.
const ISLE1_LANDING_X := 28
const ISLE1_LANDING_Y := 20
const ISLE1_W := 48

## The two routes walked below, as node ids and nothing else. **They are the whole of the fork**: the
## ⚠⚠ **The two route names are historical**: `ROUTE_TWO_BEAKS`'s two nodes paid the beak until
## 2026-08-25, when the user deleted that reward. **Both routes pay bodies at every node now** and the
## names are kept only so the diff of that day reads. The first steps on three `COUNT` nodes, the second on one `COUNT` node and two ex-beak
## nodes. `net_map` proves those are the extremes of the real graph; this file proves the run ends up
## in a different place depending on which one the hand picked.
const ROUTE_ALL_CELLS := [0, 1, 4, 5, 6]
const ROUTE_TWO_BEAKS := [0, 2, 3, 5, 6]


## Every win now stops for the card pick before the map (「6개중 2택」), and `enter_node` refuses
## unless `_state == MAP` — so a route walk that does not take the two cards and close the board
## between two wins never reaches the second node at all. A no-op when the run has not stopped for a
## pick (a `REWARD` win has not reached `PICK` yet; the boss pays no cards at all), so a caller may call
## this after every `finish_island(true)` unconditionally.
func _take_two_and_close_refit(r: Run, fit_into_slot0: bool = false) -> void:
	if r.state() != Run.State.PICK:
		return
	# ⚠⚠ **THE BEAST FALLBACK IS DELETED WITH THE BEAST CARD** (2026-08-27). This used to scan the
	# round for the first card whose `card_kind` was `ITEM` and take that one, because a card could be
	# a BEAST since 티켓 15 and a beast pick brought `Rules.SPECIES_CARD_BODIES` bodies with it —
	# four bodies landing inside whatever roster count the caller was really measuring, chosen by the
	# seed rather than by the fixture. **`Rules.CardKind` has one member now**, so the scan could only
	# ever return 0 and the card taken is written as 0.
	# ⚠ **What the scan guarded is still worth knowing**: the day a card pays BODIES again, this is
	# the line that has to come back, or every roster count in this file starts measuring the draw.
	r.take_card(0)
	if fit_into_slot0:
		# A FIXED policy — always fit whatever landed into slot 0's own board, in the order taken —
		# used by `_the_route_is_what_the_board_holds` so the two routes are compared under IDENTICAL
		# fitting behaviour and only the CARDS the route itself produced can make the boards differ.
		# `fit(0, 0)` twice: after the first fit consumes held index 0, the second taken card is the
		# new index 0.
		r.army.loadout.fit(0, 0)
		r.army.loadout.fit(0, 0)
	r.close_refit()


func run(t) -> void:
	_starting_state(t)
	_hp_carries_by_identity(t)
	_wipe_loses(t)
	_the_clock_ends_nothing(t)
	_restart_resets(t)
	# -- the card round --------------------------------------------------------------------------------
	# ⚠⚠ **티켓 15 「a card can be a BEAST」 IS DELETED** (2026-08-27). Of its six rows, **three died
	# whole** — `_the_draw_never_offers_a_species_the_run_holds`,
	# `_beasts_are_rolled_per_card_and_not_reserved` and `_no_species_stands_twice_in_one_round`, each
	# recorded where it stood — and **three were rewritten to what is left**: the round a run opens on,
	# where a taken card sends the run, and that no card moves a summon slot or a body. Every deleted
	# assertion read `Rules.CardKind.SPECIES`, and **`CardKind` has one member now** — a card is an item
	# and nothing else.
	_a_run_opens_on_a_card_round(t)
	_an_item_card_moves_no_slot_and_opens_refit(t)
	_cards_add_no_slot_and_no_body(t)


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


# -- 티켓 15: the whole row, filled --------------------------------------------------------------------
## ⚠⚠ **THE ROW NO LONGER FILLS, AND THAT IS WHAT THIS MEASURES NOW.** The ticket's acceptance line was
## 「take four beast cards in a row and the summon row is five boxes, each a DIFFERENT species, each
## with bodies behind it」 — four picks, four slots, four species, sixteen bodies. **The beast card is
## deleted**, so nothing a player can press adds a slot or a body, and the 「저마다 다른 종」 half has
## no mechanism left to be true or false about.
##
## ⚠ **What is left is a floor and it is not decoration**: the mutation this row exists for is a card
## that quietly recruits again. The run would walk the identical screens and the identical pile, every
## count that only reads the loadout would stay green, and the roster would have grown underneath.
##
## ⚠ The rounds are dealt through the same call `_reset` uses, so this walks six picks without hunting
## for seeds — six being more picks than the old row of five slots could ever have absorbed.
func _cards_add_no_slot_and_no_body(t) -> void:
	var r := Run.new()
	t.eq(r.army.slot_count(), Rules.START_SLOTS.size(), "회차는 개막 칸만 갖고 연다 (자가 점검)")
	t.eq(Rules.START_SLOTS.size(), 1, "그 칸은 하나다 (리터럴)")
	var taken := 0
	for _round in 6:
		if r.state() != Run.State.PICK:
			r._draw_cards()
			r._state = Run.State.PICK
		var k := _first_card_of(r, Rules.CardKind.ITEM)
		if k < 0:
			break
		if not r.take_card(k):
			break
		taken += 1
	t.eq(taken, 6, "여섯 라운드에서 여섯 장을 집었다 (자가 점검)")
	t.eq(r.army.slot_count(), Rules.START_SLOTS.size(), "여섯 장을 집어도 소환 칸은 하나 그대로다")
	t.eq(r.army.living_count(), Rules.roster_start_count(),
		"명부도 개막 병력 그대로다 — 카드는 몸을 데려오지 않는다")
	t.eq(r.army.loadout.held.size(), 6, "집은 여섯 장은 전부 장비 더미로 갔다 (자가 점검)")


# -- 티켓 15: the opening round ----------------------------------------------------------------------
## ⚠⚠ **THE FIRST SCREEN OF THE WHOLE GAME, and it very nearly could not be measured at all.** The
## opening three are dealt inside `_reset`, which runs before any caller can hand a seed in — so
## `seed_cards` re-deals an untouched round, and without that line 「무작위라 못 잰다」 would be true
## of the one screen every player sees first.
##
## ⚠⚠ **THE ROUND IS EQUIPMENT NOW AND THE TWO ROWS ABOUT ITS SPECIES ARE DELETED** (2026-08-27). It
## used to be dealt 「beasts only」 — no item was allowed to mix in, and the wolf could not appear
## because the run already held it — and both of those read `Rules.CardKind.SPECIES`, which no longer
## exists. **What the screen owes a player is unchanged and still measured here**: it is up, it is
## three cards, and the same seed deals the same three.
##
## ⚠ Mutation: `_reset` leaving `_state` at `BATTLE`; `seed_cards` not re-dealing.
func _a_run_opens_on_a_card_round(t) -> void:
	var r := Run.new()
	t.eq(r.state(), Run.State.PICK, "새 회차는 섬이 아니라 카드 화면에서 연다")
	t.eq(r.army.slot_count(), 1, "그리고 칸 하나로 연다")
	t.eq(r.army.slot_type_of(0), Rules.WOLF, "그 칸은 늑대다")
	t.eq(r.army.living_count(), 10, "늑대 열 마리다 (리터럴 — 작은 섬 넷의 밀도가 이 열에 맞춰져 있다)")

	var items := 0
	for k in Rules.CARDS_PER_WIN:
		if int(r.card_kind[k]) == Rules.CardKind.ITEM:
			items += 1
	t.eq(r.cards.size(), Rules.CARDS_PER_WIN, "세 장이 깔려 있다 (자가 점검)")
	t.eq(items, Rules.CARDS_PER_WIN, "세 장이 전부 장비다 — 개막 라운드도 다른 라운드와 같은 장을 낸다")

	# ⚠ **The seed has to reach a round that was dealt before it arrived**, or this screen is the one
	# screen nothing can ever pin.
	var a := Run.new()
	a.seed_cards(4242)
	var b := Run.new()
	b.seed_cards(4242)
	t.eq(a.cards, b.cards, "씨앗을 같이 준 두 회차가 같은 세 장으로 연다")
	t.eq(a.card_kind, b.card_kind, "종류도 같다")
	var kinds_bad := 0
	for k in Rules.CARDS_PER_WIN:
		if int(a.card_kind[k]) != Rules.CardKind.ITEM:
			kinds_bad += 1
	t.eq(kinds_bad, 0, "다시 뽑은 세 장도 전부 장비다 — 재추첨이 라운드 종류를 안 바꾼다")


# -- 티켓 15: the beast card -------------------------------------------------------------------------
## ⚠⚠ **THE BEAST HALF IS DELETED 2026-08-27, AND WHAT IT MEASURED CANNOT HAPPEN ANY MORE.** It took
## a `CardKind.SPECIES` card and read the slot and the four bodies it brought — **THE BODIES WERE THE
## ROW**: without them a beast card added a button that refuses when you press it, a slot on screen
## with an empty roster behind it, while every count of slots stayed green. `CardKind.SPECIES`,
## `Rules.SPECIES_CARD_BODIES` and `Run._take_species_card` are all gone, so there is no card that can
## pay a body at all — **`_cards_add_no_slot_and_no_body` above is where that claim lives now**, from
## the other side: six picks, no slot, no body.
##
## ⇒ **What survives is the half that was the CONTROL**: an item card moves neither the slots nor the
## roster, and it DOES open refit. It was written to stand against the beast arm; with one kind of
## card left it is the whole row, and it still measures the fork out of the pick screen — which is
## 「is the pile empty」 and not 「what kind was that card」.
##
## ⚠ Mutation: make `take_card` recruit; take the fork on the card's KIND instead of on the held pile.
func _an_item_card_moves_no_slot_and_opens_refit(t) -> void:
	var r := _run_holding_a(t, Rules.CardKind.ITEM)
	t.ok(r != null, "장비 카드가 뜬 회차를 찾았다 (자가 점검)")
	var k := _first_card_of(r, Rules.CardKind.ITEM)
	var slots_before := r.army.slot_count()
	var living_before := r.army.living_count()
	t.ok(r.take_card(k), "장비 카드를 집었다")
	t.eq(r.army.slot_count(), slots_before, "장비 카드는 칸을 안 늘린다")
	t.eq(r.army.living_count(), living_before, "몸도 안 늘린다")
	t.ok(not r.army.loadout.held.is_empty(), "집은 장은 더미에 들어 있다 (자가 점검)")
	t.eq(r.state(), Run.State.REFIT, "그리고 더미에 든 것이 있으니 정비 화면으로 간다")


## ⚠⚠ **TWO ROWS ABOUT THE SPECIES POOL DIED HERE 2026-08-27, and this is what they held.**
##  · `_the_draw_never_offers_a_species_the_run_holds` — **a card naming a species the run already
##    holds is a dead face, not a random one.** Both ends: the wolf never appeared while it was held,
##    and once every species was registered no seed could deal a beast at all. It read
##    `Run._species_pool`'s `slot_of_type` filter, and the pool is deleted
##  · `_beasts_are_rolled_per_card_and_not_reserved` — **the user's 2026-08-25 decision head on.**
##    The plan had reserved one of three cards for a beast; the user cut the reservation and left the
##    weight, so rounds with zero beasts AND rounds with two had to both exist. It read
##    `Rules.SPECIES_CARD_WEIGHT`, which is deleted
##
## ⚠ **Neither claim has a subject any more** — every card in every round is an item, and an item may
## honestly repeat and is never refused for being held. The 「per card, never a fixed share」 argument
## survives only as words, in `run.gd`'s `_draw_cards` header.


## A run standing on its first card screen whose draw holds at least one card of `kind`, or null.
## ⚠ Seeded and walked over a bounded range, so the fixture is reproducible rather than lucky.
## ⚠⚠ **`kind` has exactly one legal value since 2026-08-27** — `CardKind.ITEM`. The argument is kept
## because the question it asks ("stand a run on a round holding a card of this kind") is the same
## question, and a caller that hands it a kind no card can be gets null rather than a lucky run.
func _run_holding_a(t, kind: int) -> Run:
	for s in 200:
		var r := Run.new()
		r.seed_cards(s)
		_opened(r)
		r.finish_island(true)
		if r.state() != Run.State.PICK:
			continue
		if _first_card_of(r, kind) >= 0:
			return r
	return null


func _first_card_of(r: Run, kind: int) -> int:
	for k in Rules.CARDS_PER_WIN:
		if int(r.card_kind[k]) == kind:
			return k
	return -1


# -- where a run begins -----------------------------------------------------------------------------

func _starting_state(t) -> void:
	var r := Run.new()
	# ⚠⚠ 「런은 카드 세 장에서 시작한다」 (티켓 15) — it used to open on the map, and the card round now
	# sits in front of it. ⚠ **Those three were BEASTS until 2026-08-27 and are equipment now**; the
	# round itself did not move, only what is on it. `_a_run_opens_on_a_card_round` drives that round;
	# this row walks past it and then measures the opening roster, which is what it always measured.
	t.eq(r.state(), Run.State.PICK, "시작 상태는 카드 고르기다")
	t.eq(r.army.living_count(), Rules.roster_start_count(), "시작 병력은 10")
	t.eq(r.army.living_ids_of_type(Rules.WOLF).size(), Rules.start_bodies_of(0), "열 마리 전부 늑대다")
	t.eq(r.army.living_ids_of_type(Rules.CROW).size(), 0, "까마귀는 아직 없다 — 카드로 온다")
	_opened(r)


# -- the one that the plan names a mutation for ------------------------------------------------------

func _hp_carries_by_identity(t) -> void:
	# ⚠⚠ **SEEDED, and it is kept seeded on purpose.** The reason it had to be seeded is gone with the
	# beast card — an unseeded fixture used to register a random second species off the opening round,
	# and a later round of three beast cards then made `_take_two_and_close_refit` take one, bringing
	# four bodies into every roster count below (**measured: this net went red about one run in six on
	# an unchanged tree**). No card pays a body now, so the draw cannot move these numbers at all —
	# but a fixture that names its seed is the one that stays readable when it next can.
	var r := _seeded_open(1)
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
	t.eq(r.army.type_id[3], Rules.WOLF, "3번의 병종도 바뀌지 않았다")


# -- rewards ------------------------------------------------------------------------------------------

## ⚠⚠ **MEASURED 2026-08-25: putting `BEAK` back into `Reward`, and `REWARD` back into `Run.State`,
## left the WHOLE ROUND GREEN at 3231 checks.** The payouts are closed — the two ex-beak nodes cannot
## quietly stop paying bodies without eight checks reddening — but the WORDS were not: a member nobody
## pays yet costs nothing today and is exactly how a deleted mechanic comes back one file at a time.
##
## ⚠ **This is not tidiness.** `panel_view.panel_active`'s own header argues for an ALLOW-list on the
## ground that **one added `Run.State` member breaks it five ways at once** — a red band painting over
## the live screen while `panel_active()` reads true. That argument is only worth what a check makes
## it worth, and until this row there was none.
##
## ⚠ The KEYS and not the size: a size alone passes a rename, and 티켓 23 is a ticket about names.
##
## ⚠ Mutation: add any member to any of the three; rename one.
## 「경로가 다르면 명부가 다르다」 — two whole runs over the same map by the two extreme routes, and
## what comes out the other end has to DIFFER. **This is a floor, not a ceiling**: a map whose four
## routes all produce the same roster is a corridor with pictures on it, and that is the exact shape
## that killed this repo's second game — an advantage with no cost is not a decision.
## Walks one route end to end and reports what came out. Every step goes through the run's own public
## verbs — `enter_node`, `finish_island` — because a walk that poked at fields would
## measure the fixture.
## ⚠ `seed` and `fit_into_slot0` both default to "off", so every EXISTING call keeps behaving exactly
## as before — a route walk that never fits anything is unaffected by either argument, and its own
## comparisons (roster count, pool) do not depend on which cards were drawn, only on how many.
## ⚠ §8.4's dropped row: 「경로가 다르면 명부만이 아니라 판도 다르다」. The check above already proves
## the ROSTER differs by route; nothing anywhere checked the BOARD, and `grep -n 'board\|loadout'` over
## this file found nothing before this row. A FIXED fit policy (`fit_into_slot0`) is what makes the
## claim about the ROUTE and not about which slot a hand happened to fit into — without it, two boards
## fit by two different policies would differ for a reason that has nothing to do with the map.
##
## ⚠⚠ **Deliberately UNSEEDED, and that is not an oversight — it is measured to be the only option.**
## Both routes here are 5 nodes, 4 non-boss wins each (`ROUTE_ALL_CELLS` / `ROUTE_TWO_BEAKS`'s own
## sizes), and every non-boss win now pays six cards regardless of the node's OWN reward kind — so a
## seeded run draws the IDENTICAL card sequence on both routes (same call count, same RNG stream) and
## a fixed policy then fits the identical sequence into the identical slot: the boards are GUARANTEED
## equal, not just usually equal. Confirmed by running it seeded first — it failed 100% of runs, not
## flakily. Unseeded, this is the exact same "two runs, overwhelmingly likely to disagree" shape
## `_the_route_is_what_the_run_takes` right above already accepts for the roster and the pool.
## The wipe. Driven through `battle.step` rather than asserted, because "every soldier is dead" is a
## verdict the fight has to reach on its own — the session only reads it.
func _wipe_loses(t) -> void:
	var r := _seeded_open(5)
	var b := r.begin_island()
	t.eq(b.outcome(), Battle.Outcome.RUNNING, "전투는 굴러가는 상태로 시작한다")
	# The smallest plan there is, then the start button: without a commit `step` returns before
	# `_phase_clock` and the wipe would never be latched at all.
	t.ok(b.send(0, _summonable_on(b)) >= 0 and b.commit(), "한 명을 보내고 시작을 눌렀다 (자가 점검)")
	for i in range(r.army.type_id.size()):
		r.army.kill(i)
	t.eq(r.army.living_count(), 0, "병사가 하나도 안 남았다")

	b.step(0.1)
	t.eq(b.outcome(), Battle.Outcome.LOST, "병사가 다 죽으면 섬을 진다")
	t.eq(b.lose_reason(), Battle.Lose.WIPED, "패인은 전멸이다")
	t.ok(b.enemies_left() > 0, "적이 아직 남아 있다 — 적을 다 죽여서 끝난 게 아니다")


## The clock, through a real `Run`. One soldier is landed and nine stay at the harbour, which is the
## smallest plan a commit will accept.
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
func _the_clock_ends_nothing(t) -> void:
	var r := _seeded_open(5)
	var b := r.begin_island()
	t.ok(b.send(0, _summonable_on(b)) >= 0 and b.commit(), "한 명만 보내고 시작을 눌렀다 (자가 점검)")
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
	t.eq(b.enemies_left(), Islands.spawns().size(),
		"적은 하나도 안 죽었다 — 한 명으로는 못 죽인다")


# -- restart -------------------------------------------------------------------------------------------

## ⚠ **`Run.restart()` does not die with the title screen.** The shell builds a fresh `Run` for
## 시작하기 and never calls this — but it is the only thing keeping `_reset` honest about a field added
## to one path and forgotten in the other, which is exactly how a second run would start somewhere the
## first did not with nothing to bark about it.
func _restart_resets(t) -> void:
	var r := _seeded_open(5)
	var first := r.army
	var hp := first.hp
	hp[0] = 1.0
	first.hp = hp
	first.kill(1)
	r.finish_island(true)
	# 승리도 카드를 냈다 — 고르고 정비를 닫아야 회차가 끝까지 간다.
	_take_two_and_close_refit(r)
	t.eq(r.state(), Run.State.WON, "재시작 전에는 끝난 상태다")


## ⚠⚠ **Found on the grid in front of it, not typed.** It used to be island 1's own literal tile, and
## the day the first node stopped opening island 1 (2026-08-24 — every node has its own grid now) that
## literal named water on a map 24 wide. **A landing this suite hard-codes is a landing that describes
## one map**, and the thing being checked here has never been about which map.
## ⚠ **`send` takes a LANDING, which is LAND, and `summon` takes a water tile — two different verbs
## and it cost a red round to notice.** So this asks the grid's own question: is there a harbour whose
## boat can reach this beach?
func _summonable_on(b: Battle) -> int:
	var g := b.grid
	for tile in g.w * g.h:
		var home := g.home_harbour_for(tile)
		if home >= 0 and g.can_land_at(home, tile):
			return tile
	return -1


## Walks past the OPENING CARD ROUND and onto the island. ⚠⚠ **A run opens on a card screen since
## 티켓 15** (「시작하자마자 세 개 중에 하나 고르는 거」), so `begin_island` refuses until that round is
## finished — every fixture below that opens the island has to pass through it first. Card 0, always,
## so the fixture is the same run every time.
##
## ⚠⚠ **THE `close_refit` IS NOT TIDINESS, IT IS THE BEAST CARD'S DELETION LANDING HERE.** The opening
## card used to be a BEAST: it paid no item, the held pile stayed empty, and `take_card` walked the
## run straight out of the card screen. **Every card is equipment now**, so taking one leaves the run
## standing in `REFIT` — and `begin_island` returns `null` there. Without this line every fixture below
## calls a method on a null `Battle`.
func _opened(r: Run) -> Run:
	if r.state() == Run.State.PICK:
		r.take_card(0)
	if r.state() == Run.State.REFIT:
		r.close_refit()
	return r


## A seeded run standing on the island with its opening card taken and its refit closed.
##
## ⚠⚠ **THE SPECIES REGISTRATION LOOP IS DELETED 2026-08-27 AND IT WAS NOT DECORATION.** It registered
## every player species so that no LATER card could be a beast: an unregistered fixture could be dealt
## three beast cards, `_take_two_and_close_refit` would take one, and four bodies would land inside
## whatever roster count was being asserted. **No card can pay a body any more**, so the loop guards
## nothing — and it was adding four empty summon slots to every fixture in this file for that reason
## alone.
##
## ⚠ **The seed stays.** It is what makes WHICH item the opening card pays reproducible, and the
## fixture is only readable if the run it builds is the same run every time.
func _seeded_open(seed: int) -> Run:
	var r := Run.new()
	r.seed_cards(seed)
	_opened(r)
	return r
