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
	_the_three_words_the_map_pays_in_are_closed(t)
	_rewards(t)
	_the_route_is_what_the_run_takes(t)
	_the_route_is_what_the_board_holds(t)
	_wipe_loses(t)
	_timeout_loses(t)
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
		r.enter_node(0)
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

	# One pick and the run is on the map with two slots and bodies in both.
	var ty := int(a.cards[0])
	t.ok(a.take_card(0), "한 장을 집었다")
	t.eq(a.state(), Run.State.MAP, "그러면 지도로 간다 — 짐승 카드는 더미에 아무것도 안 넣는다")
	t.eq(a.army.slot_count(), 2, "그리고 칸이 둘이 된다")
	t.eq(a.army.slot_type_of(1), ty, "둘째 칸이 집은 그 종이다")
	t.eq(a.army.living_ids_of_type(ty).size(), Rules.SPECIES_CARD_BODIES, "그 종의 몸도 같이 왔다")
	t.eq(a.army.living_count(), 10 + Rules.SPECIES_CARD_BODIES,
		"첫 섬은 열넷을 상륙시킨다 — 열이 아니다")


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
		r.enter_node(0)
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
		full.enter_node(0)
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
		r.enter_node(0)
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
		r.enter_node(0)
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

	# 「한 장을 고르면 지도이고 밟은 칸이 없다」 — floor: the state is MAP; ceiling: nothing is walked.
	# ⚠ `State.MAP` is 0 on purpose, so a default-constructed int lands on the map rather than in a
	# battle against an island nobody entered.
	t.eq(r.state(), Run.State.MAP, "한 장을 고르면 지도다")
	t.eq(Run.State.MAP, 0, "그리고 MAP 이 0이다 — 기본값 int 가 아무도 안 고른 섬의 전투로 떨어지지 않는다")
	t.ok(r.map != null, "런이 지도를 하나 들고 시작한다")
	t.eq(r.map.path.size(), 0, "밟은 칸이 하나도 없다")
	t.eq(r.map.at(), -1, "서 있는 칸이 -1 이다")
	t.ok(r.begin_island() == null, "지도 위에서는 전투가 안 열린다 — 아무 섬도 안 골랐다")
	t.eq(r.pending_reward(), Rules.Reward.NONE, "시작할 때 기다리는 보상은 없다")

	# ⚠ **`Reward` moved to `rules.gd` and `Run.Reward` is gone.** It had to: `MAP_NODES` names the
	# reward column, and `rules.gd` referencing `Run` would close a class cycle. This row is what stops
	# a second copy of the enum growing back on `Run`.
	# ⚠ **The instrument is inverted on the same two lines.** `get_script_constant_map()` is what can
	# see an enum on a script at all, so the row that says `Reward` is NOT on `Run` is worthless
	# without the row proving the map does hold `State`, which is on `Run` and must stay there.
	# (`get_script_constant_map()` is not static, so it is asked of the instance's script — calling it
	# on the class name is a parse error on 4.7.1.)
	var run_constants: Dictionary = r.get_script().get_script_constant_map()
	t.ok(run_constants.has("State"),
		"State 는 Run 것이다 (자가 점검 — 이 줄이 빨개지면 아래 줄은 아무것도 안 재고 있다)")
	t.ok(not run_constants.has("Reward"),
		"보상 이름표는 Run 이 아니라 Rules 것이다 — 두 벌이면 값이 갈린다")
	# And that `Rules` holds it is not a second check: every `Rules.Reward.*` in this file is a
	# compile-time reference, so the whole net fails to parse if it moves again.

	# The map screen's one verb, refused from every state that is not the map.
	t.ok(not r.enter_node(3), "지도에서도 닿을 수 없는 칸은 못 밟는다")
	t.eq(r.map.path.size(), 0, "거절당한 뒤에도 자취가 비어 있다")
	t.ok(r.enter_node(0), "1층 칸은 밟힌다")
	t.eq(r.state(), Run.State.BATTLE, "칸을 밟자 전투가 됐다")
	t.eq(r.island_index, Rules.map_island_of(0), "그리고 그 칸이 가리키는 섬이 열렸다")
	t.ok(not r.enter_node(1), "전투 중에는 다음 칸을 못 밟는다 — 지도 상태가 아니다")
	t.eq(r.map.at(), 0, "그래서 서 있는 칸도 안 움직였다")

	var b := r.begin_island()
	t.ok(b != null, "첫 섬의 전투가 열린다")
	# Identity, not equality of contents. A `begin_island` that handed the fight a fresh roster of the
	# same size would satisfy every count above and this is the only line that sees it.
	t.ok(b.army == r.army, "전투는 런의 로스터 객체 그 자체를 쓴다 — 복사본이 아니다")
	# ⚠ **Read off the node, not off island 0.** `MAP_NODES` gave every node its own grid on
	# 2026-08-24; asserting 48 x 32 here was asserting which map node 0 happens to open, which is a
	# different claim from the one this block is making (that `begin_island` opens the node's island).
	var isle := r.island_index
	t.eq(isle, Rules.map_island_of(0), "첫 노드가 여는 섬은 노드 표가 정한 섬이다")
	var isle_rows: Array = Islands.rows_of(isle)
	t.eq(b.grid.w, str(isle_rows[0]).length(), "격자 폭은 그 섬의 폭이다")
	t.eq(b.grid.h, isle_rows.size(), "격자 높이는 그 섬의 높이다")
	t.eq(b.enemies_left(), Islands.spawns_of(isle).size(), "첫 섬의 적 수는 스폰 표와 같다")
	t.eq(b.time_limit, Islands.time_limit_of(isle), "제한 시간은 islands.gd 가 준 값이다")
	t.eq(b.harbour_count(), 3, "첫 섬의 항구는 셋이다")


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

	t.ok(r.enter_node(0), "0번 칸을 밟는다")
	var was_index := r.island_index
	r.finish_island(true)
	# 「수 보상은 그 자리에서 붙고, 이기면 지도가 아니라 카드 고르기부터 연다」 — and ⚠⚠ **the floor as
	# well**: 「`finish_island(true)` 는 `island_index` 를 혼자 안 옮긴다」. Mutation: put
	# `island_index += 1` back into `_advance`, and the map becomes a picture the run ignores.
	t.eq(r.state(), Run.State.PICK, "첫 칸을 이기면 카드 고르기가 먼저 열린다 — 다음 섬으로 혼자 안 넘어간다")
	t.eq(r.island_index, was_index, "그리고 섬 번호를 혼자 안 옮긴다 — 어느 칸으로 갈지는 손이 정한다")
	t.eq(r.map.at(), 0, "서 있는 칸도 0번 그대로다")
	t.ok(r.begin_island() == null, "카드를 고르는 동안에도 전투는 안 열린다")
	t.eq(r.pending_reward(), Rules.Reward.NONE, "수 보상은 그 자리에서 소모된다 — 고를 것이 없다")

	_take_two_and_close_refit(r)
	t.eq(r.state(), Run.State.MAP, "카드를 고르고 정비를 닫아야 비로소 지도다")

	# ⚠ The double-close hole is now closed by the map and not by a counter: a second call falls out on
	# the state guard because the run is no longer in BATTLE.
	r.finish_island(true)
	t.eq(r.map.path.size(), 1, "이긴 섬을 두 번 닫아도 자취가 안 늘어난다")
	t.eq(r.army.type_id.size(), 17, "그리고 보상이 두 번 붙지도 않았다")

	t.ok(r.army == roster, "섬을 넘어도 로스터 객체가 그대로다")
		# ⚠ **13 -> 17** (티켓 15): 10 wolves open the run, the opening beast card brings four more, and
	# the COUNT node pays three on top. The literal moved because the OPENING moved, not the reward.
	t.eq(r.army.type_id.size(), 17, "죽은 줄은 남고 개막 카드 넷과 보상 셋이 붙어 17줄이다")
	t.eq(r.army.living_count(), 16, "살아 있는 것은 16명")
	t.eq(r.army.hp[3], 5.0, "3번의 상처가 그대로 넘어왔다 — 수가 아니라 정체성이다")
	t.eq(r.army.hp[9], 2.5, "9번의 상처도 그대로다")
	t.eq(r.army.alive[7], 0, "7번은 여전히 죽어 있다 — 죽음은 영구다")
	t.eq(r.army.hp[7], 0.0, "죽은 7번의 HP 는 0이다")
	t.eq(r.army.type_id[3], Rules.WOLF, "3번의 병종도 바뀌지 않았다")

	# ⚠ **The reward bodies are indexed off the roster's own length**, never off a fixed 10: the
	# opening card put four bodies in before them. `Rules.SLOT_PAY` pays slot 0 twice and slot 1 once,
	# and slot 1's species is whatever the opening card was — so the SECOND slot's row is read off the
	# army rather than named.
	var pay0 := Rules.slot_pay_of(0)
	var first_reward := r.army.type_id.size() - Rules.roster_reward_count()
	t.eq(r.army.type_id[first_reward], Rules.WOLF, "첫 보상 병사는 1번 칸의 늑대다")
	t.eq(r.army.type_id[first_reward + pay0 - 1], Rules.WOLF, "그 다음도 늑대다")
	t.eq(r.army.type_id[first_reward + pay0], int(r.army.slot_type_of(1)),
		"그 뒤는 2번 칸의 종이다 — 개막 카드가 넣은 그 종")
	t.eq(r.army.hp[first_reward], Rules.hp_of(Rules.WOLF), "보상 병사는 만피로 온다")
	t.eq(r.army.hp[first_reward + pay0],
		Rules.hp_of(int(r.army.slot_type_of(1))), "2번 칸 보상 병사도 만피다")

	# And the wounds have to reach the FIGHT, not merely survive in the roster.
	t.ok(r.enter_node(1), "2층 왼쪽 칸을 밟는다")
	t.eq(r.island_index, Rules.map_island_of(1), "그 칸이 가리키는 섬이 열렸다")
	var b := r.begin_island()
	t.ok(b != null, "둘째 섬의 전투가 열린다")
	t.ok(b.army == roster, "둘째 섬의 전투도 같은 로스터를 쓴다")
	t.eq(b.army.hp[3], 5.0, "둘째 섬의 전투가 든 3번도 상처 그대로다")
	t.eq(b.soldier_state[7], Battle.SoldierState.DEAD, "죽은 병사는 예비가 아니라 DEAD 로 들어간다")
	t.eq(b.soldier_state[3], Battle.SoldierState.RESERVE, "산 병사는 예비로 들어간다")
	t.eq(b.soldier_state.size(), 17, "전투는 죽은 줄까지 포함한 17줄을 본다")
	t.eq(b.time_limit, Islands.time_limit_of(r.island_index), "둘째 섬의 제한 시간")


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
func _the_three_words_the_map_pays_in_are_closed(t) -> void:
	t.eq(Rules.Reward.keys(), ["NONE", "COUNT"],
		"보상은 둘뿐이다 %s — 「부리」도 「회복」도 낱말로도 안 남는다" % str(Rules.Reward.keys()))
	t.eq(Rules.NodeKind.keys(), ["FIGHT", "BOSS"],
		"칸 종류도 둘뿐이다 %s — 상자 칸은 낱말로도 안 남는다" % str(Rules.NodeKind.keys()))
	t.eq(Run.State.keys(), ["MAP", "BATTLE", "PICK", "REFIT", "WON", "LOST"],
		"회차의 상태는 여섯이다 %s — 「보상」 상태는 낼 것이 없어져서 같이 죽었다" % str(Run.State.keys()))


func _rewards(t) -> void:
	var r := _seeded_open(2)
	r.enter_node(0)
	r.finish_island(true)
	# ⚠⚠ **NODE 2 PAID THE BEAK AND NOW PAYS BODIES** (2026-08-25, the user: 「부리 보상 없지 끝나면
	# 카드보상으로 통일했잖아」). Its sibling always paid bodies, so **the fork this block existed to
	# demonstrate is gone** — and that is asserted rather than left implied, because a reward column
	# that no longer forks is exactly the thing a reader would assume still does.
	var payouts := {}
	for n in Rules.map_node_count():
		payouts[Rules.map_reward_of(n)] = true
	t.eq(payouts.size(), 2,
		"일곱 칸이 내는 보상은 두 종류뿐이다 — 싸움 칸의 짐승과 보스의 없음 %s" % str(payouts.keys()))
	t.eq(Rules.map_reward_of(2), Rules.Reward.COUNT, "2번 칸은 이제 짐승을 낸다 (옛 부리 칸)")
	t.eq(Rules.map_reward_of(3), Rules.Reward.COUNT, "3번 칸도 마찬가지다 (옛 부리 칸)")
	t.eq(Rules.map_reward_of(1), Rules.Reward.COUNT, "그 옆 1번 칸도 짐승이다")
	# 0번 칸의 승리도 카드를 냈다 — 고르고 정비를 닫아야 `enter_node` 가 다시 먹는다.
	_take_two_and_close_refit(r)

	# ⚠ **Walk the two ex-beak nodes for real**, because 「이제 짐승을 낸다」 is a claim about what they
	# PAY and not only about what the table says. Both used to open a pick screen and stop the run;
	# now each one wins straight into the card round like every other node.
	for n in [2, 3]:
		var before_n := r.army.living_count()
		t.ok(r.enter_node(n), "%d번(옛 부리 칸)을 밟는다" % n)
		r.finish_island(true)
		t.eq(r.pending_reward(), Rules.Reward.NONE,
			"%d번을 이겨도 기다리는 보상이 없다 — 그 자리에서 소모된다" % n)
		t.ok(r.army.living_count() > before_n,
			"%d번이 짐승을 냈다 (%d -> %d)" % [n, before_n, r.army.living_count()])
		t.eq(r.state(), Run.State.PICK, "%d번도 카드 고르기로 간다 — 고를 몸이 뜨지 않는다" % n)
		_take_two_and_close_refit(r)

	# ⚠⚠ 「4층 칸(옛 상자 자리)도 섬을 열고, 이기면 짐승 보상을 낸다」 — the chest is gone; node 5 is a
	# fight now, exactly like every other node.
	var before_living := r.army.living_count()
	t.ok(r.enter_node(5), "4층 칸(옛 상자 자리)을 밟는다")
	t.eq(r.state(), Run.State.BATTLE, "섬이 열린다 — 상자처럼 지도에 머물지 않는다")
	t.eq(r.island_index, Rules.map_island_of(5), "이 섬의 번호가 5번 칸이 가리키는 섬이다")
	r.finish_island(true)
	t.eq(r.state(), Run.State.PICK, "COUNT 보상은 고를 게 없어도 카드 고르기부터 연다")
	t.eq(r.pending_reward(), Rules.Reward.NONE, "그리고 기다리는 짐승 보상은 없다")
	t.ok(r.army.living_count() > before_living, "COUNT 보상으로 병력이 늘었다")
	_take_two_and_close_refit(r)
	t.eq(r.state(), Run.State.MAP, "카드를 고르고 정비를 닫으면 지도로 돌아온다")

	# 「보스 칸을 이기면 `WON` 이고 지도로 안 돌아간다」
	t.ok(r.enter_node(6), "보스 칸을 밟는다")
	t.eq(r.state(), Run.State.BATTLE, "보스도 섬을 연다")
	r.finish_island(true)
	t.eq(r.state(), Run.State.WON, "보스를 이기면 런이 끝난다")
	t.ok(r.map.is_finished(), "지도도 끝난 것으로 읽힌다")
	t.ok(r.begin_island() == null, "끝난 런에서는 전투가 안 열린다")
	r.finish_island(false)
	t.eq(r.state(), Run.State.WON, "끝난 런은 뒤늦은 패배로 뒤집히지 않는다")
	t.eq(r.map.path, PackedInt32Array(ROUTE_TWO_BEAKS), "걸어온 자취가 부리 두 번 경로 그대로다")


# -- ⚠ the row that measures whether the fork does anything at all ------------------------------------

## 「경로가 다르면 명부가 다르다」 — two whole runs over the same map by the two extreme routes, and
## what comes out the other end has to DIFFER. **This is a floor, not a ceiling**: a map whose four
## routes all produce the same roster is a corridor with pictures on it, and that is the exact shape
## that killed this repo's second game — an advantage with no cost is not a decision.
func _the_route_is_what_the_run_takes(t) -> void:
	# ⚠⚠ **BOTH SEEDED, AND WITH THE SAME SEED.** The two routes have to open from the identical army
	# or the roster and pool numbers below are reading the opening card rather than the map.
	var left := _walk_route(t, ROUTE_ALL_CELLS, "왼쪽 경로", false, 7)
	var right := _walk_route(t, ROUTE_TWO_BEAKS, "오른쪽 경로", false, 7)

	t.eq(left["state"], Run.State.WON, "왼쪽 경로로 런이 끝난다")
	t.eq(right["state"], Run.State.WON, "오른쪽 경로로도 런이 끝난다")
	# ⚠⚠ **THIS BLOCK USED TO PROVE THE TWO ROUTES PAID DIFFERENT THINGS, AND THEY NO LONGER DO**
	# (2026-08-25). Two of the right-hand route's nodes paid the beak; the user deleted that reward —
	# 「부리 보상 없지 끝나면 카드보상으로 통일했잖아」 — so **every node on both routes pays bodies.**
	# ⇒ The rows below are INVERTED on purpose: what used to be 「짐승 경로가 병사가 더 많다」 is now
	# 「두 경로의 병사 수가 같다」. **Rewriting them to still pass would have hidden the change; stating
	# the equality is the honest form**, and it is the row that reddens the day a second reward kind
	# returns.
	t.eq(int(left["living"]), int(right["living"]),
		"두 경로의 병사 수가 같다 (%d명) — 보상이 하나로 통일돼서 갈림길이 병력으로는 안 갈린다"
			% int(left["living"]))
	# ⚠ **`SPECIES_CARD_BODIES` is in the sum** — a run opens on a beast card, so every route lands its
	# first island with fourteen rather than ten. Four wins before the boss, each paying bodies.
	t.eq(int(left["living"]), Rules.roster_start_count() + Rules.SPECIES_CARD_BODIES
		+ 4 * (Rules.roster_reward_count()),
		"10 + 개막 카드 4 + 보상 넷 x 3 = 26명이다")
	t.eq(left["path"], PackedInt32Array(ROUTE_ALL_CELLS), "왼쪽 경로가 손이 고른 그 칸들을 그대로 걸었다")
	t.eq(right["path"], PackedInt32Array(ROUTE_TWO_BEAKS), "오른쪽 경로도 손이 고른 그대로다")
	# ⚠ The one thing that still differs: the two routes open different ISLANDS, so the boards a run
	# fills are not the same. That claim lives in `_the_route_reaches_the_board` below and is what is
	# left of 「경로가 다르면 런이 다르다」.


## Walks one route end to end and reports what came out. Every step goes through the run's own public
## verbs — `enter_node`, `finish_island` — because a walk that poked at fields would
## measure the fixture.
## ⚠ `seed` and `fit_into_slot0` both default to "off", so every EXISTING call keeps behaving exactly
## as before — a route walk that never fits anything is unaffected by either argument, and its own
## comparisons (roster count, pool) do not depend on which cards were drawn, only on how many.
func _walk_route(t, route: Array, label: String, fit_into_slot0: bool = false, seed: int = -1) -> Dictionary:
	var r := Run.new()
	# ⚠⚠ **A CALLER THAT ASSERTS A COUNT MUST PASS A SEED, and `-1` stays the default for the one
	# caller that must NOT** (`_the_route_is_what_the_board_holds` — its own header measures why).
	# Unseeded, the opening beast round differs run to run, so WHICH species the second slot holds
	# moves, and with it the HP every body of that species carries. **Measured: this net went red
	# three times in thirty-seven runs of an unchanged tree, on the pool comparison.**
	# ⚠ Seed FIRST, then walk past the opening round: `seed_cards` re-deals an untouched round, so
	# seeding afterwards would leave the pick random anyway.
	if seed >= 0:
		r.seed_cards(seed)
	_opened(r)
	# ⚠⚠ **Every remaining species registered right after the opening pick, so NO LATER CARD CAN BE A
	# BEAST.** This row measures the reward arithmetic, and a beast card would add
	# `Rules.SPECIES_CARD_BODIES` bodies to the very number it is counting — with WHICH rounds drew one
	# depending on the seed. Registration adds no bodies of its own and `Rules.SLOT_PAY` has no row past
	# the second, so the arithmetic below is untouched by it.
	for ty in Rules.player_type_count():
		r.army.register_species(ty)
	var refused := 0
	for n in route:
		if not r.enter_node(int(n)):
			refused += 1
			continue
		if r.state() == Run.State.BATTLE:
			r.finish_island(true)
		# Every win now stops for the card pick before the map, and `enter_node` refuses unless
		# `_state == MAP` — walk it all the way through, or the very next node in `route` is refused
		# and `refused` below reads a route that was never actually walked.
		_take_two_and_close_refit(r, fit_into_slot0)
	t.eq(refused, 0, "%s 다섯 칸이 전부 밟혔다 — 하나라도 거절당하면 걸은 길이 고른 길이 아니다" % label)
	var pool := 0.0
	for i in r.army.alive.size():
		if r.army.alive[i] != 0:
			pool += r.army.hp[i]
	return {"state": r.state(), "living": r.army.living_count(), "pool": pool,
		"path": r.map.path, "board": r.army.loadout.board.duplicate()}


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
func _the_route_is_what_the_board_holds(t) -> void:
	var cells := _walk_route(t, ROUTE_ALL_CELLS, "짐승 경로 (끼우며)", true)
	var beaks := _walk_route(t, ROUTE_TWO_BEAKS, "부리 경로 (끼우며)", true)
	var cells_board: PackedInt32Array = cells["board"]
	var beaks_board: PackedInt32Array = beaks["board"]
	t.eq(cells_board.size(), beaks_board.size(),
		"두 판의 크기는 같다 — 슬롯 수 x 부위 수는 경로와 무관하다 (자가 점검)")

	var cells_filled := 0
	var beaks_filled := 0
	for v in cells_board:
		if int(v) >= 0:
			cells_filled += 1
	for v in beaks_board:
		if int(v) >= 0:
			beaks_filled += 1
	t.ok(cells_filled > 0 and beaks_filled > 0,
		"두 판 다 실제로 뭔가 끼워져 있다 (%d칸, %d칸) — 빈 판끼리는 다를 수 없다" % [cells_filled, beaks_filled])
	t.ok(cells_board != beaks_board,
		"같은 정책으로 끼워도 짐승 경로와 부리 경로의 0번 슬롯 판이 서로 다르다 — 경로가 판에도 닿는다")


# -- losing ------------------------------------------------------------------------------------------

## The wipe. Driven through `battle.step` rather than asserted, because "every soldier is dead" is a
## verdict the fight has to reach on its own — the session only reads it.
func _wipe_loses(t) -> void:
	var r := _seeded_open(5)
	r.enter_node(0)
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
	t.ok(b.enemies_left() > 0, "적이 아직 남아 있다 — 시간 초과와 헷갈릴 여지가 없다")
	t.ok(b.time_left() > 0.0, "시계도 아직 남아 있다")

	r.finish_island(false)
	t.eq(r.state(), Run.State.LOST, "섬을 지면 런이 끝난다")
	t.eq(r.map.at(), 0, "져도 서 있는 칸은 그대로다 — 지도는 패널 뒤에 그대로 남는다")
	t.eq(r.map.path.size(), 1, "그리고 자취도 안 지워진다")
	t.ok(r.begin_island() == null, "진 런에서는 전투가 안 열린다")
	t.ok(not r.enter_node(1), "진 런에서는 다음 칸도 못 밟는다")
	t.eq(r.pending_reward(), Rules.Reward.NONE, "진 런은 보상을 주지 않는다")


## The clock, through a real `Run`. One soldier is landed and nine stay at the harbour, which is the
## smallest plan a commit will accept. The step count says the run ended ON the clock rather than
## early.
##
## ⚠⚠ **THE LIMIT IS SHORTENED HERE AND THAT IS THE FIX FOR THIS ISLAND'S LOSS RULE, NOT A DODGE.**
## This fixture used island 1's own 60 s and asserted 3600 sub-steps — and it only ever passed because
## the run could not end when the beachhead died. It can now: the lone soldier meets a bison and is
## dead at **7.95 s**, and holding nine reserves no longer keeps the island open. **What sat out the
## other 52 seconds was the defect the user reported**, so a check that needed those 52 seconds was
## measuring the defect.
##
## ⇒ The limit is cut to 5.0 s, comfortably before that death, so the timer is once again the only
## thing that can end this island. **The claim that `Islands.time_limit_of(0)` is what reaches the
## battle is not lost with it** — it is pinned on its own line at the top of this file, which is where
## it belongs; this row is about what the clock DOES, not where its number comes from.
func _timeout_loses(t) -> void:
	var r := _seeded_open(5)
	r.enter_node(0)
	var b := r.begin_island()
	t.ok(b.send(0, _summonable_on(b)) >= 0 and b.commit(), "한 명만 보내고 시작을 눌렀다 (자가 점검)")
	t.eq(b.time_limit, Islands.time_limit_of(r.island_index), "섬이 준 제한 시간을 확인한다 (자가 점검 — 줄이기 전에)")
	var limit := 5.0
	b.time_limit = limit
	# ⚠ **One sub-step per call, never `step(1.0)`.** `step` consumes whole `Rules.SIM_SUBSTEP_SEC`
	# sub-steps and carries the leftover, so a 1.0 s call runs **59** of them and not 60 — the residue
	# after sixty subtractions lands a hair under the sub-step in IEEE double — and the run would need
	# a 61st call for a reason that is floating point rather than the clock.
	var steps := 0
	while b.outcome() == Battle.Outcome.RUNNING and steps < 8000:
		b.step(Rules.SIM_SUBSTEP_SEC)
		steps += 1

	# ⚠⚠ **INVERTED, 2026-08-24** (the user: 「제한 시간 안에 클리어 조건은 일단 지워」). This block used
	# to prove the clock could end an island. It is kept, pointing the other way, because 「the clock
	# does not decide」 is a RULE — and a rule nothing measures is a rule that grows back by accident.
	# The one soldier either dies to the eight defenders (which is the WIPE arm, not the clock) or the
	# island is still running long past its own limit; both are read below, and neither is a timeout.
	t.ok(b.outcome() != Battle.Outcome.LOST or b.lose_reason() != Battle.Lose.TIMEOUT,
		"시간으로 지는 일은 없다")
	t.ok(b.elapsed >= limit - Rules.EPS, "그런데 시계는 제한 시간을 넘겨 갔다 (%.6f초) — 안 돈 게 아니다" % b.elapsed)
	t.ok(b.time_left() <= Rules.EPS, "남은 시간은 0에 붙어 있다 (%.12f초)" % b.time_left())
	t.eq(b.enemies_left(), Islands.spawns_of(r.island_index).size(),
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
	r.enter_node(0)
	r.finish_island(true)
	# 0번 칸의 승리도 여섯 장을 냈다 — `enter_node` 는 `MAP` 이 아니면 조용히 거절하므로, 1번 칸을
	# 밟기 전에 카드를 고르고 정비를 닫아야 한다.
	_take_two_and_close_refit(r)
	r.enter_node(1)
	var first_map := r.map
	r.finish_island(false)
	t.eq(r.state(), Run.State.LOST, "재시작 전에는 진 상태다")
	t.eq(r.map.path.size(), 2, "그리고 두 칸을 걸어 둔 상태다 (자가 점검)")

	r.restart()
	# 「재시작하면 새 회차와 똑같은 자리에서 다시 연다」 — the opening beast round, not the map (티켓 15).
	# ⚠ **That IS the row**: `restart` shares `_reset` with `_init` so a field added to one path and
	# forgotten in the other would make the second run start somewhere the first did not.
	t.eq(r.state(), Run.State.PICK, "재시작하면 개막 카드 화면으로 돌아간다 — 섬이 아니다")
	_opened(r)
	t.eq(r.state(), Run.State.MAP, "그리고 한 장을 고르면 지도다")
	t.eq(r.map.path.size(), 0, "밟은 자취가 비었다")
	t.eq(r.map.at(), -1, "서 있는 칸도 -1 로 돌아갔다")
	t.ok(r.map != first_map, "지도도 새 객체다 — 이전 런의 자취를 물려받지 않는다")
	t.eq(r.island_index, 0, "섬 번호도 0으로 돌아간다")
	t.eq(r.pending_reward(), Rules.Reward.NONE, "기다리는 보상도 없다")
	t.ok(r.begin_island() == null, "그리고 지도 위이니 전투가 안 열린다")
	# The whole point of "identical starting state": a reset that reused the object would carry the
	# wounds forward and every count below would still be right.
	t.ok(r.army != first, "로스터는 새 객체다 — 이전 런의 상처를 물려받지 않는다")
	# ⚠ **14 and not 10** — the run reopens on its beast round and `_opened` above takes one, which
	# brings `Rules.SPECIES_CARD_BODIES` bodies with it. What this row is about is that NOTHING from
	# the previous run survived: a fresh roster, no dead rows, no wounds.
	t.eq(r.army.type_id.size(), 14, "줄 수도 개막 상태로 돌아간다 — 죽은 줄이 남아 있지 않다")
	t.eq(r.army.living_count(), 14, "열넷 전부 살아 있다")
	t.eq(r.army.hp[0], Rules.hp_of(Rules.WOLF), "0번은 만피다")
	t.eq(r.army.alive[1], 1, "1번은 다시 살아 있다")
	t.eq(first.hp[0], 1.0, "옛 로스터는 고쳐진 게 아니라 버려졌다")
	t.eq(first_map.path.size(), 2, "옛 지도도 비워진 게 아니라 버려졌다")

	t.eq(r.map.reachable_nodes(), PackedInt32Array([0]), "그리고 다시 1층 한 칸만 열려 있다")
	t.ok(r.enter_node(0), "재시작 뒤 0번 칸을 다시 밟을 수 있다")
	var b := r.begin_island()
	t.ok(b != null, "재시작 뒤 첫 섬의 전투가 다시 열린다")
	t.ok(b.army == r.army, "새 전투는 새 로스터를 쓴다")
	t.eq(b.enemies_left(), Islands.spawns_of(r.island_index).size(), "적도 처음 수로 되살아나 있다")


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
