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
	# ⚠⚠ **A BEAST FALLBACK IS A BUG IN THE FIXTURE, NOT A CHOICE.** `pick` below defaults to 0, so a
	# round that happens to hold three beast cards used to take one and add
	# `Rules.SPECIES_CARD_BODIES` bodies to whatever this walk was counting. Callers that assert a
	# roster count register every species first, which empties the beast pool — this line is what
	# says so out loud rather than leaving it to the seed.
	# ⚠⚠ **AN ITEM CARD, CHOSEN OFF `card_kind`.** A card can be a BEAST since 티켓 15, and a beast
	# pick brings `Rules.SPECIES_CARD_BODIES` bodies with it — which is exactly what every roster count
	# in this file would then be measuring instead of the reward arithmetic it claims to measure.
	# **The rows that measure the beast card itself are further down and drive it on purpose.**
	var pick := 0
	for k in Rules.CARDS_PER_WIN:
		if int(r.card_kind[k]) == Rules.CardKind.ITEM:
			pick = k
			break
	r.take_card(pick)
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
	# -- 티켓 15: a card can be a BEAST --------------------------------------------------------------
	_a_beast_card_brings_a_slot_and_bodies(t)
	_the_draw_never_offers_a_species_the_run_holds(t)
	_beasts_are_rolled_per_card_and_not_reserved(t)
	_a_run_opens_on_a_beast_round(t)
	_four_beast_cards_fill_the_row(t)
	_no_species_stands_twice_in_one_round(t)


# -- 티켓 15 fix: one round never shows the same animal twice -------------------------------------------
## ⚠⚠ **MEASURED: 64% of opening rounds held a duplicate and 6% were three of one animal.** Three
## cards offering one choice is a screen that says 「골라」 and means 「받아」, and the opening round is
## the first thing a player ever sees. The pool is drawn WITHOUT replacement now.
##
## ⚠ **Both rounds, not just the opening one** — the post-win draw takes from the same pool.
##
## ⚠ Mutation: put the drawn species back into the pool (`pool.remove_at` deleted).
func _no_species_stands_twice_in_one_round(t) -> void:
	var opening_dupes := 0
	var opening_rounds := 0
	for s in 200:
		var r := Run.new()
		r.seed_cards(s)
		opening_rounds += 1
		if _has_duplicate_species(r):
			opening_dupes += 1
	t.eq(opening_rounds, 200, "개막 라운드 이백 개를 봤다 (자가 점검)")
	t.eq(opening_dupes, 0, "개막 세 장에 같은 종이 두 번 서지 않는다")

	# ⚠ The self-check that keeps the row above from being vacuous: the opening rounds really do deal
	# three beasts, so there were three chances to repeat in every one of them.
	var short_rounds := 0
	for s in 200:
		var r := Run.new()
		r.seed_cards(1000 + s)
		var beasts := 0
		for k in Rules.CARDS_PER_WIN:
			if int(r.card_kind[k]) == Rules.CardKind.SPECIES:
				beasts += 1
		if beasts < Rules.CARDS_PER_WIN:
			short_rounds += 1
	t.eq(short_rounds, 0, "그 이백 개가 전부 짐승 세 장이다 — 겹칠 자리가 실제로 셋 있었다 (자가 점검)")

	# The post-win draw takes from the same pool and obeys the same rule.
	var won_dupes := 0
	var won_beasts := 0
	for s in 200:
		var r := Run.new()
		r.seed_cards(2000 + s)
		_opened(r)
		r.finish_island(true)
		for k in Rules.CARDS_PER_WIN:
			if int(r.card_kind[k]) == Rules.CardKind.SPECIES:
				won_beasts += 1
		if _has_duplicate_species(r):
			won_dupes += 1
	t.ok(won_beasts > 0, "이긴 뒤 뽑기에서도 짐승이 실제로 나왔다 (자가 점검)")
	t.eq(won_dupes, 0, "이긴 뒤 세 장에도 같은 종이 두 번 안 선다")


func _has_duplicate_species(r: Run) -> bool:
	var seen := {}
	for k in Rules.CARDS_PER_WIN:
		if int(r.card_kind[k]) != Rules.CardKind.SPECIES:
			continue
		var ty := int(r.cards[k])
		if seen.has(ty):
			return true
		seen[ty] = true
	return false


# -- 티켓 15: the whole row, filled --------------------------------------------------------------------
## **The ticket's own acceptance line**: take four beast cards in a row and the summon row is five
## boxes, each a DIFFERENT species, each with bodies behind it.
##
## ⚠⚠ **「저마다 다른 종」 is the half a count cannot see.** Five slots all holding the wolf is five
## boxes and ten bodies and reads as done; it is one button drawn five times.
##
## ⚠ The rounds are dealt beasts-only through the same call `_reset` uses, so this walks four picks
## without hunting for seeds that happen to offer one.
##
## ⚠ Mutation: let `register_species` accept a species it already holds; drop the `SUMMON_SLOT_MAX`
## guard (the sixth round would then register something).
func _four_beast_cards_fill_the_row(t) -> void:
	var r := Run.new()
	t.eq(r.army.slot_count(), 1, "회차는 칸 하나로 연다 (자가 점검)")
	var taken := 0
	for _round in Rules.SUMMON_SLOT_MAX + 2:
		if r.state() != Run.State.PICK:
			r._draw_cards(true)
			r._state = Run.State.PICK
		var k := _first_card_of(r, Rules.CardKind.SPECIES)
		if k < 0:
			break
		r.take_card(k)
		taken += 1
	t.eq(taken, Rules.SUMMON_SLOT_MAX - Rules.START_SLOTS.size(),
		"짐승 카드를 넷 집으면 더 집을 것이 없다 — 그 뒤로는 짐승 장이 아예 안 나온다")
	t.eq(r.army.slot_count(), Rules.SUMMON_SLOT_MAX, "그리고 칸이 다섯이 된다")
	t.eq(Rules.SUMMON_SLOT_MAX, 5, "그 상한이 다섯이다 (리터럴)")

	var seen := {}
	var empty_slots := 0
	for sl in r.army.slot_count():
		var ty := r.army.slot_type_of(sl)
		seen[ty] = true
		t.eq(Rules.side_of(ty), Rules.Side.PLAYER, "%d번 칸이 아군 편 종이다" % sl)
		if r.army.living_ids_of_type(ty).size() <= 0:
			empty_slots += 1
	t.eq(seen.size(), Rules.SUMMON_SLOT_MAX,
		"다섯 칸이 저마다 다른 종이다 — 개수만 세면 늑대 다섯도 다섯이다")
	t.eq(empty_slots, 0, "그리고 다섯 다 몸을 갖고 있다 — 누르면 거절하는 버튼이 하나도 없다")
	t.eq(r.army.living_count(),
		Rules.roster_start_count()
			+ (Rules.SUMMON_SLOT_MAX - Rules.START_SLOTS.size()) * Rules.SPECIES_CARD_BODIES,
		"명부가 개막 열에 카드 넷 x 넷을 더한 만큼이다")


# -- 티켓 15: the opening round ----------------------------------------------------------------------
## ⚠⚠ **THE FIRST SCREEN OF THE WHOLE GAME, and it very nearly could not be measured at all.** The
## opening three are dealt inside `_reset`, which runs before any caller can hand a seed in — so
## `seed_cards` re-deals an untouched round, and without that line 「무작위라 못 잰다」 would be true
## of the one screen every player sees first.
##
## ⚠ Mutation: `_reset` leaving `_state` at `MAP`; the opening round drawn with items mixed in;
## `seed_cards` not re-dealing.
func _a_run_opens_on_a_beast_round(t) -> void:
	var r := Run.new()
	t.eq(r.state(), Run.State.PICK, "새 회차는 지도가 아니라 카드 화면에서 연다")
	t.eq(r.army.slot_count(), 1, "그리고 칸 하나로 연다")
	t.eq(r.army.slot_type_of(0), Rules.WOLF, "그 칸은 늑대다")
	t.eq(r.army.living_count(), 10, "늑대 열 마리다 (리터럴 — 작은 섬 넷의 밀도가 이 열에 맞춰져 있다)")

	var items := 0
	var wolves := 0
	for k in Rules.CARDS_PER_WIN:
		if int(r.card_kind[k]) == Rules.CardKind.ITEM:
			items += 1
		elif int(r.cards[k]) == Rules.WOLF:
			wolves += 1
	t.eq(r.cards.size(), Rules.CARDS_PER_WIN, "세 장이 깔려 있다 (자가 점검)")
	t.eq(items, 0, "세 장이 전부 짐승이다 — 장비가 하나도 안 섞인다")
	t.eq(wolves, 0, "그리고 늑대는 없다 — 이미 가진 종이라 집을 수 없는 장이다")

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
		if int(a.card_kind[k]) != Rules.CardKind.SPECIES:
			kinds_bad += 1
	t.eq(kinds_bad, 0, "다시 뽑은 세 장도 전부 짐승이다 — 재추첨이 라운드 종류를 안 바꾼다")


# -- 티켓 15: the beast card -------------------------------------------------------------------------
## ⚠⚠ **THE BODIES ARE THE ROW.** Without them a beast card adds **a button that refuses when you
## press it** — a slot on screen with an empty roster behind it — and every count of slots stays green
## while the screen has gained nothing. It is the user's own `Reward.COUNT` failure built backwards.
##
## ⚠ Mutation: delete the recruit loop in `_take_species_card`; take the fork on the card's KIND
## instead of on the held pile.
func _a_beast_card_brings_a_slot_and_bodies(t) -> void:
	var r := _run_holding_a(t, Rules.CardKind.SPECIES)
	t.ok(r != null, "짐승 카드가 뜬 회차를 찾았다 (자가 점검)")
	var k := _first_card_of(r, Rules.CardKind.SPECIES)
	var ty := int(r.cards[k])
	var slots_before := r.army.slot_count()
	var bodies_before := r.army.living_ids_of_type(ty).size()
	t.eq(bodies_before, 0, "집기 전에는 그 종의 몸이 하나도 없다 (자가 점검)")
	t.ok(r.take_card(k), "짐승 카드를 집었다")
	t.eq(r.army.slot_count(), slots_before + 1, "칸이 하나 늘었다")
	t.eq(r.army.slot_type_of(slots_before), ty, "그리고 그 칸이 그 종이다")
	t.eq(r.army.living_ids_of_type(ty).size(), Rules.SPECIES_CARD_BODIES,
		"몸도 같이 왔다 — 이 줄이 없으면 「누르면 거절하는 버튼」이 통과한다")
	t.eq(Rules.SPECIES_CARD_BODIES, 4, "그 수는 넷이다 (리터럴 — 「일단」이 붙은 값)")
	# The fork out of the pick screen is 「is the pile empty」 and not 「what kind was that」.
	t.ok(r.army.loadout.held.is_empty(), "짐승만 집었으니 더미는 비어 있다 (자가 점검)")
	t.ok(r.state() != Run.State.REFIT, "그래서 정비 화면이 아니라 지도로 간다")

	# The CONTROL: an item card moves neither the slots nor the roster, and DOES open refit.
	var r2 := _run_holding_a(t, Rules.CardKind.ITEM)
	t.ok(r2 != null, "장비 카드가 뜬 회차를 찾았다 (자가 점검)")
	var k2 := _first_card_of(r2, Rules.CardKind.ITEM)
	var slots2 := r2.army.slot_count()
	var living2 := r2.army.living_count()
	t.ok(r2.take_card(k2), "장비 카드를 집었다")
	t.eq(r2.army.slot_count(), slots2, "장비 카드는 칸을 안 늘린다 — 대조군")
	t.eq(r2.army.living_count(), living2, "몸도 안 늘린다")
	t.eq(r2.state(), Run.State.REFIT, "그리고 더미에 든 것이 있으니 정비 화면으로 간다")


## ⚠ **A card naming a species the run already holds is a card that cannot be picked** — a dead face,
## not a random one. Both ends: the wolf never appears while it is held, and once every species is
## held there are no beast cards at all whatever the seed.
##
## ⚠ Mutation: drop the `slot_of_type` filter in `_species_pool`; drop its `SUMMON_SLOT_MAX` guard.
func _the_draw_never_offers_a_species_the_run_holds(t) -> void:
	var held_seen := 0
	var beast_seen := 0
	for s in 60:
		var r := Run.new()
		r.seed_cards(s)
		_opened(r)
		r.finish_island(true)
		for k in Rules.CARDS_PER_WIN:
			if int(r.card_kind[k]) != Rules.CardKind.SPECIES:
				continue
			beast_seen += 1
			if r.army.slot_of_type(int(r.cards[k])) >= 0:
				held_seen += 1
	t.ok(beast_seen > 0, "씨앗 예순 개 중에 짐승 카드가 실제로 나왔다 (자가 점검)")
	t.eq(held_seen, 0, "그리고 이미 가진 종의 카드는 한 장도 안 나온다 — 집을 수 없는 죽은 장이다")

	# The ceiling: every species registered ⇒ every card is equipment, whatever the seed.
	var beasts_when_full := 0
	for s in 40:
		var full := Run.new()
		for ty in Rules.player_type_count():
			full.army.register_species(ty)
		full.seed_cards(s)
		full.finish_island(true)
		for k in Rules.CARDS_PER_WIN:
			if int(full.card_kind[k]) == Rules.CardKind.SPECIES:
				beasts_when_full += 1
	t.eq(beasts_when_full, 0, "남은 종이 없으면 어떤 씨앗으로도 세 장이 전부 장비다 — 천장")


## ⚠⚠ **THE ROW THAT MEASURES THE USER'S 2026-08-25 DECISION HEAD ON, and it needs BOTH ends.**
## The plan had reserved one of three cards for a beast; the user cut the reservation and left the
## weight. So a round with ZERO beasts must exist (or the reservation is still alive) **and** a round
## with at least one must exist (or beasts never come at all).
##
## ⚠ Mutation: make `_draw_cards` force exactly one beast per round; set `SPECIES_CARD_WEIGHT` to 0.
func _beasts_are_rolled_per_card_and_not_reserved(t) -> void:
	var rounds_with_none := 0
	var rounds_with_some := 0
	var rounds_with_two_or_more := 0
	for s in 80:
		var r := Run.new()
		r.seed_cards(s)
		_opened(r)
		r.finish_island(true)
		var n := 0
		for k in Rules.CARDS_PER_WIN:
			if int(r.card_kind[k]) == Rules.CardKind.SPECIES:
				n += 1
		if n == 0:
			rounds_with_none += 1
		else:
			rounds_with_some += 1
		if n >= 2:
			rounds_with_two_or_more += 1
	t.ok(rounds_with_none > 0, "짐승이 0장인 라운드가 실재한다 — 자리를 예약하는 옛 규칙은 죽었다")
	t.ok(rounds_with_some > 0, "짐승이 1장 이상인 라운드도 실재한다 — 아예 안 뜨는 게 아니다")
	t.ok(rounds_with_two_or_more > 0, "두 장 이상인 라운드도 있다 — 장마다 따로 굴린다는 것의 증거다")


## A run standing on its first card screen whose draw holds at least one card of `kind`, or null.
## ⚠ Seeded and walked over a bounded range, so the fixture is reproducible rather than lucky.
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
	# ⚠⚠ 「런은 짐승 카드 세 장에서 시작한다」 (티켓 15) — it used to open on the map, and the beast
	# round now sits in front of it. `_a_run_opens_on_a_beast_round` drives that round itself; this row
	# walks past it and then measures what the MAP state is, which is what it always measured.
	t.eq(r.state(), Run.State.PICK, "시작 상태는 카드 고르기다")
	t.eq(r.army.living_count(), Rules.roster_start_count(), "시작 병력은 10")
	t.eq(r.army.living_ids_of_type(Rules.WOLF).size(), Rules.start_bodies_of(0), "열 마리 전부 늑대다")
	t.eq(r.army.living_ids_of_type(Rules.CROW).size(), 0, "까마귀는 아직 없다 — 카드로 온다")
	_opened(r)


# -- the one that the plan names a mutation for ------------------------------------------------------

func _hp_carries_by_identity(t) -> void:
	# ⚠⚠ **SEEDED, and that is not a tidiness call.** The opening beast round is dealt inside `_reset`,
	# so an unseeded fixture registers a random second species — and a later round with three beast
	# cards then makes `_take_two_and_close_refit` pick one, which brings four bodies into every
	# roster count below. **Measured: this net went red about one run in six on an unchanged tree.**
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
	# ⚠ **17 -> 14** (2026-08-26): 10 wolves open the run and the opening beast card brings four more.
	# **The node reward that used to pay three on top is deleted with the map.**
	t.eq(r.army.type_id.size(), 14, "죽은 줄은 남고 개막 카드 넷이 붙어 14줄이다")
	t.eq(r.army.living_count(), 13, "살아 있는 것은 13명")
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


## Walks past the OPENING BEAST ROUND. ⚠⚠ **A run opens on a card screen since 티켓 15** (「시작하자
## 마자 세 개 중에 하나 고르는 거」), so `enter_node` refuses until one of its three beasts has been
## taken — every fixture below that steps onto the map has to pass through it first. Card 0, always,
## so the fixture is the same run every time.
func _opened(r: Run) -> Run:
	if r.state() == Run.State.PICK:
		r.take_card(0)
	return r


## A seeded run standing on the map with its opening beast card taken, and every other species
## registered so no LATER card can be a beast.
##
## ⚠⚠ **All three halves are load-bearing.** Unseeded, WHICH species the second slot holds is random
## and every HP total below moves with it. Unregistered, a later round can offer three beast cards and
## `_take_two_and_close_refit` then takes one, adding four bodies to the count being asserted.
## Registration itself adds no bodies and `Rules.SLOT_PAY` has no row past the second, so the reward
## arithmetic these fixtures measure is untouched.
func _seeded_open(seed: int) -> Run:
	var r := Run.new()
	r.seed_cards(seed)
	_opened(r)
	for ty in Rules.player_type_count():
		r.army.register_species(ty)
	return r
