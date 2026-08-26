class_name Run
extends RefCounted
## Session state: whether the island is open, which cards are on the table, and whether the run is
## still going. One island's fight lives in `battle.gd`; this file is everything around it.
##
## ⚠⚠ **THE MAP IS GONE** (2026-08-26). Seven nodes and eight islands were deleted together — the user
## could not draw eight islands and said so (`idea-inbox` 328). **There is one island**, and a run is
## the opening card round, that island, and an end.
##
## ⚠⚠ **What replaces the map is not built yet.** 「제한 시간이 지나면 보스가 온다」 and the waves that
## bring the beasts ashore are decided but unbuilt, so **winning the island ends the run** — see
## `finish_island`. That is a placeholder that says so out loud rather than a loop pretending to be one.
##
## **`army` is built in exactly two places — `_init` and `restart` — and nowhere else.** HP carries
## by identity: the same rows, the same ids, the same wounds. So `begin_island` hands `battle` the
## roster this object already holds instead of making one. Building a fresh `Army` there instead would
## heal every soldier **while a check that only counts soldiers stayed green**.
##
## Every value that changes what happens lives in `rules.gd`, and the island's own facts — its grid,
## its spawns, its clock — live in `islands.gd`. Nothing here holds a second copy of either; a number
## counted in two places diverges.


## Where the run is. `BATTLE` means the island is open and `begin_island` will build its fight;
## `PICK` means cards are up and some are waiting to be taken; `REFIT` means the taken cards are ready
## to be laid into a board; `WON` and `LOST` are both terminal until `restart`.
##
## ⚠⚠ **`MAP` IS GONE** (2026-08-26), deleted with the map screen and the seven islands behind it. A
## state nothing can enter is a screen nobody can reach, and leaving it would keep every check about it
## green. **`REWARD` went the same way on 2026-08-25.**
##
## ⚠ **`BATTLE` is FIRST so it is 0**, and a default-constructed int therefore lands on the island
## rather than in a state nothing sets. ⚠⚠ **Nothing anywhere may compare a state against a literal
## int** — `net_run` pins these by name.
enum State { BATTLE, PICK, REFIT, WON, LOST }


## The roster that survives the run. Never rebuilt outside `_reset`.
var army: Army = null

var _state := State.BATTLE

## ⚠⚠ **The placeholder that stands where the waves will.** True once the island has been held. It is
## what makes `_advance` end the run instead of re-opening the island, and it exists because **there is
## exactly one island**: without it a cleared island would either re-open forever (a loop dressed as a
## wave) or leave `WON` unreachable (a screen nobody can get to).
## ⚠ **When waves are built this is what they replace** — a wave counter answers the same question.
var _island_cleared := false

## `Rules.CARDS_PER_WIN` cards. **`cards[k]` means an ITEM id or a `UNITS` row depending on
## `card_kind[k]`** — a card is one of two things since 티켓 15.
## ⚠ **Flat and parallel, not an Array of Arrays**, for the reason `army.gd`'s header gives.
var cards := PackedInt32Array()
## `Rules.CardKind` per card, index-aligned with `cards`. ⚠ **Never inferred from the value**: item 4
## and unit row 4 are both 4, and a reader that guessed would be right most of the time.
var card_kind := PackedInt32Array()
var cards_taken := PackedByteArray()

## ⚠⚠ **The first RNG in `src/sim/`, and it is bounded on purpose**: one object, one reader
## (`_draw_cards`), one seed verb.
var _rng := RandomNumberGenerator.new()

## Whether the round currently on the table was dealt beasts-only. **Read by `seed_cards` alone**, so
## a re-deal produces the same KIND of round the player is looking at rather than an ordinary one.
var _round_is_beasts_only := false


func _init() -> void:
	_reset()


## Back to the identical starting state. A run carries no meta and no unlock, so this is the whole of
## it — and it shares `_reset` with `_init` on purpose: a field added to one path and forgotten in the
## other would make the second run start somewhere the first did not, with nothing to bark about it.
func restart() -> void:
	_reset()


func _reset() -> void:
	army = Army.new()
	army.add_starting_force()
	_state = State.BATTLE
	_island_cleared = false
	cards = PackedInt32Array()
	card_kind = PackedInt32Array()
	cards_taken = PackedByteArray()
	_rng.randomize()
	# ⚠⚠ **A RUN OPENS ON A CARD SCREEN** (2026-08-25, the user: 「시작하자마자 세 개 중에 하나 고르는
	# 거 그거 하고 가자」). Three cards, **beasts only** — equipment here would make the one species a
	# run holds stronger instead of splitting the horde.
	_draw_cards(true)
	_state = State.PICK


## For nets and the probe: makes `_draw_cards()` reproducible.
##
## ⚠⚠ **AND IT RE-DEALS AN UNTOUCHED ROUND.** The opening three are drawn inside `_reset`, which runs
## before any caller can hand a seed in — so without this the first screen of the whole game is the
## one screen nothing can ever pin, and 「무작위라 못 잰다」 would be true of it forever.
##
## ⚠ **Only while nothing has been taken from that round.** A seed handed in mid-pick must never
## replace cards somebody is looking at.
func seed_cards(s: int) -> void:
	_rng.seed = s
	if _state == State.PICK and _cards_taken_count() == 0:
		_draw_cards(_round_is_beasts_only)


## Builds the island's fight and hands it back. Returns `null` unless the island is actually open, so
## a caller that ignores `state()` gets a null instead of a fight during a card pick or after the end.
##
## The `Grid` is new every time. `load_rows` does clear reservations, but a grid built here can never
## be one another `Battle` still holds unit ids inside.
func begin_island() -> Battle:
	if _state != State.BATTLE:
		return null
	var grid := Grid.new()
	Islands.load_into(grid)
	var battle := Battle.new()
	battle.setup(grid, army, Islands.spawns(), Islands.time_limit())
	return battle


## Closes the island. **Both outcomes are terminal.**
##
## ⚠⚠ **A WIN PAYS ITS CARDS AND THEN ENDS THE RUN, AND THE ENDING IS A PLACEHOLDER.** What used to
## follow a win was the map: cards, then the next of eight islands. The map is deleted and **what
## replaces it — waves, and a boss on a clock — is decided but unbuilt** (`.scratch/island-hold/`).
## ⚠ **The cards are still paid** so the card and refit screens stay reachable; sending the run back
## into the same island instead would be a loop dressed as a wave, and this repo does not do that.
##
## Ignored unless the island is actually open, so a loss cannot be un-lost and a finished run cannot be
## reopened.
func finish_island(won: bool) -> void:
	if _state != State.BATTLE:
		return
	if not won:
		_state = State.LOST
		return
	_island_cleared = true
	_draw_cards()
	_advance()


## `Rules.CARDS_PER_WIN` independent draws. `cards_taken` is cleared with them, so a stale mark from a
## previous win can never survive into the next one.
##
## ⚠⚠ **THE KIND IS ROLLED FIRST, PER CARD, and both halves of that sentence are decisions.**
##  · **Kind first**, for exactly the reason the rarity roll below already carries in its own comment:
##    pooling beasts and items into one list makes a beast quietly rarer every time an item is added,
##    so the drop table would move whenever the CONTENT moved
##  · **Per card and never "exactly one of the three"** — a fixed share IS a reservation, and the user
##    cut the reservation on 2026-08-25. Some rounds hold no beast; some hold three
##
## `beasts_only` is 시작 라운드's door: the opening round pays beasts and nothing else.
func _draw_cards(beasts_only: bool = false) -> void:
	_round_is_beasts_only = beasts_only
	cards = PackedInt32Array()
	cards.resize(Rules.CARDS_PER_WIN)
	card_kind = PackedInt32Array()
	card_kind.resize(Rules.CARDS_PER_WIN)
	var pool := _species_pool()
	for k in Rules.CARDS_PER_WIN:
		# ⚠ **An empty pool falls back to an item, whatever was asked for.** A beast card naming a
		# species the run already holds is a card that cannot be picked — a dead face on the screen.
		if pool.size() > 0 and (beasts_only or _rng.randf() < Rules.SPECIES_CARD_WEIGHT):
			card_kind[k] = Rules.CardKind.SPECIES
			# ⚠⚠ **WITHOUT REPLACEMENT — no species may stand twice in one round.** Drawn with it,
			# 64% of opening rounds held a duplicate and 6% were three of one animal, which is a
			# three-card screen offering one choice. **There is exactly enough slack**: four
			# candidates for three cards on the opening round. A pool that runs out mid-round falls
			# through to equipment on the lines below, which is what it already did when empty.
			var at := _rng.randi_range(0, pool.size() - 1)
			cards[k] = int(pool[at])
			pool.remove_at(at)
			continue
		card_kind[k] = Rules.CardKind.ITEM
		# **Rarity first, item second.** Rolling straight over the item list would make legendaries
		# rarer every time a common one was added — the drop table would move when the CONTENT moved.
		var rarity := Rules.rarity_at_roll(_rng.randi_range(0, Rules.rarity_weight_total() - 1))
		var items := Rules.items_of_rarity(rarity)
		cards[k] = int(items[_rng.randi_range(0, items.size() - 1)]) if items.size() > 0 else 0
	cards_taken = PackedByteArray()
	cards_taken.resize(Rules.CARDS_PER_WIN)


## The beast rows this run could still take: on the player's side, not already in a slot, and only
## while there is a slot left to put one in. **Empty is the ceiling** — every card is then an item.
func _species_pool() -> PackedInt32Array:
	var out := PackedInt32Array()
	if army == null or army.slot_count() >= Rules.SUMMON_SLOT_MAX:
		return out
	for r in Rules.species_card_count():
		var ty := Rules.species_card_type_of(r)
		if army.slot_of_type(ty) < 0:
			out.append(ty)
	return out


## Takes card `k`. Refused (and nothing changes) unless the run is in `PICK`, `k` is in range, that
## card has not already been taken, and fewer than `Rules.CARD_PICKS` have been taken so far.
##
## When the `CARD_PICKS`th card is taken, the run moves to `REFIT` — the two taken cards are already
## in `army.loadout`'s held pile by then, so refit has something to lay into a board.
func take_card(k: int) -> bool:
	if _state != State.PICK:
		return false
	if k < 0 or k >= Rules.CARDS_PER_WIN:
		return false
	if cards_taken[k] != 0:
		return false
	var taken := _cards_taken_count()
	if taken >= Rules.CARD_PICKS:
		return false
	cards_taken[k] = 1
	if int(card_kind[k]) == Rules.CardKind.SPECIES:
		_take_species_card(int(cards[k]))
	else:
		army.loadout.take_card(int(cards[k]))
	if taken + 1 >= Rules.CARD_PICKS:
		# ⚠⚠ **The fork is 「is there anything in the pile」 and NOT 「what kind was that card」.**
		# Branching on the kind makes two paths out of this screen, and two paths diverge — a beast
		# card taken while an earlier item is still unfitted would strand that item.
		if army.loadout.held.is_empty():
			_advance()
		else:
			_state = State.REFIT
	return true


## A beast card: the species takes the next free slot and **arrives with bodies**.
##
## ⚠⚠ **The bodies are not optional.** Registering alone adds a button that refuses when pressed —
## the user's own `Reward.COUNT` failure (a thing that exists and is not on screen) built backwards.
## ⚠ A refused registration (full, already held, enemy side) recruits nobody: `register_species` is
## the one place that decides, and this reads its answer instead of re-deciding.
func _take_species_card(type_id: int) -> void:
	var slot := army.register_species(type_id)
	if slot < 0:
		return
	for _i in Rules.SPECIES_CARD_BODIES:
		army.recruit(slot)


func _cards_taken_count() -> int:
	var n := 0
	for b in cards_taken:
		if b != 0:
			n += 1
	return n


## Closes the refit screen. Refused unless the run is actually in `REFIT`.
func close_refit() -> bool:
	if _state != State.REFIT:
		return false
	_advance()
	return true


## `State.BATTLE`, `State.PICK`, `State.REFIT`, `State.WON` or `State.LOST`.
func state() -> int:
	return _state


## The card round is settled: `PICK` while a card is still undrawn from; then `WON` if the island has
## already been held, else the island opens.
##
## ⚠⚠ **The `PICK` arm is ABOVE the `BATTLE` arm.** Below it, the cards are drawn and never shown and
## the round stays green — the roster grows, the run walks onto the island, and every check that only
## counts soldiers stays green.
##
## ⚠ **Losing is not decided here.** `finish_island` owns that, and `_island_cleared` is the only thing
## this function reads about the island at all.
func _advance() -> void:
	if cards.size() > 0 and _cards_taken_count() < Rules.CARD_PICKS:
		_state = State.PICK
	elif _island_cleared:
		_state = State.WON
	else:
		_state = State.BATTLE