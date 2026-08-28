class_name Run
extends RefCounted
## Session state: whether the island is open, and whether the run is still going. One island's fight
## lives in `battle.gd`; this file is everything around it.
## ⚠ **It said 「which cards are on the table」 until 2026-08-28** — there are no cards.
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
## Every value that changes what happens lives in `rules.gd`, and the island's own facts — its grid
## and its spawns — live in `islands.gd`. Nothing here holds a second copy of either; a number
## counted in two places diverges.
## ⚠ **「its clock」 stood in that list until 2026-08-27 and there is no island clock any more.**
## `Islands.TIME_LIMIT_SEC` was deleted with `Lose.TIMEOUT` and `battle.setup`'s fourth parameter —
## three dead things holding each other up. **A run-long timer that brings a boss is decided and
## unbuilt** (see `finish_island`), and it belongs to THIS file rather than to one island, so nothing
## should go looking for it in `islands.gd` when it is built.


## Where the run is. `BATTLE` means the island is open and `begin_island` will build its fight; `WON`
## and `LOST` are both terminal until `restart`.
##
## ⚠⚠ **`PICK` AND `REFIT` ARE GONE** (2026-08-28, the user: 「고르는 창도 이제 필요 없는데 왜있지?
## 이것도 제거」 · 「둘 다 지우면 돼」). The card round and the board the taken cards were laid into
## were the whole growth loop, and both screens were deleted with them.
## ⚠⚠ **`MAP` IS GONE** (2026-08-26), deleted with the map screen and the seven islands behind it. A
## state nothing can enter is a screen nobody can reach, and leaving it would keep every check about it
## green. **`REWARD` went the same way on 2026-08-25.**
##
## ⚠ **`BATTLE` is FIRST so it is 0**, and a default-constructed int therefore lands on the island
## rather than in a state nothing sets. ⚠⚠ **Nothing anywhere may compare a state against a literal
## int** — `net_run` pins these by name.
enum State { BATTLE, WON, LOST }


## The roster that survives the run. Never rebuilt outside `_reset`.
var army: Army = null

var _state := State.BATTLE

## ⚠⚠ **The placeholder that stands where the waves will.** True once the island has been held. It is
## what makes `_advance` end the run instead of re-opening the island, and it exists because **there is
## exactly one island**: without it a cleared island would either re-open forever (a loop dressed as a
## wave) or leave `WON` unreachable (a screen nobody can get to).
## ⚠ **When waves are built this is what they replace** — a wave counter answers the same question.
var _island_cleared := false

## ⚠⚠ **`cards`, `card_kind`, `cards_taken` AND THE RNG STOOD HERE AND ALL FOUR ARE DELETED**
## (2026-08-28). They held the three cards a win paid out; the screen that showed them and the board
## they were fitted into are both gone, so a run pays nothing and there is nothing to seed.
## ⚠ **`Army.loadout` is untouched** — the fitted board is what `Battle` reads to work out what a
## body's blow is worth, and it still holds whatever a run starts with.

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
	# ⚠⚠ **A RUN OPENS ON THE ISLAND** (티켓 12, 2026-08-27, the user: ***"Starting means the game
	# starts, right then."***). It used to open on a card screen; the opening three were dealt here
	# until 2026-08-25.
	# ⚠⚠ **AND THE CARDS THEMSELVES ARE DELETED NOW** (2026-08-28, the user: 「둘 다 지우면 돼」) —
	# the deal, the three-card screen and the refit board it fed. **This is the growth loop coming
	# out**, and it comes out because nothing on the island can be won yet: the beasts have no boats,
	# so a card round was a reward for a fight that never happened.


## ⚠⚠ **`seed_cards` STOOD HERE AND IS DELETED** (2026-08-28) with the deal it made reproducible.
## It was the only seed verb in `src/sim/` and the RNG it wrote was the only RNG.


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
	battle.setup(grid, army, Islands.spawns())
	_stand_the_watch(battle)
	return battle


## **One body is already on the island when it opens, standing by the keep.**
##
## ⚠⚠ **This is the swap, made concrete.** While the player was the side that ARRIVED, an empty island
## was correct and every body reached it by boat. The sides turned over 2026-08-26 — the company holds
## this island and the beasts are what lands on it — and an island that opens with nobody on it says
## the opposite of that on the one screen the player actually looks at.
##
## ⚠ **ONE, and not the whole roster** (2026-08-27, the user: ***"칸단위 부대는 따로 없음 아직"***).
## Squads do not exist yet, so ten bodies would be ten bodies walking as one lump — the picture that
## makes「부대가 없다」look like a bug rather than a decision. **Raising this number is one line, on the
## day squads arrive.**
##
## ⚠ **BESIDE the keep and not ON it.** `Builds` gives every kind a footprint but nothing marks those
## tiles impassable, so a body placed on the keep's own tile stands INSIDE the house and the island
## opens looking empty — measured 2026-08-27, and it read exactly like「아무도 안 세워졌다」.
## ⚠ Silent when there is nowhere to stand: `place_ashore` answers -1 and the island opens empty, which
## is the honest picture of a board with no free land next to its keep.
func _stand_the_watch(battle: Battle) -> void:
	var home := Islands.beside_home_tile(battle.grid.w)
	if home < 0:
		return
	for i in army.type_id.size():
		if army.alive[i] == 0:
			continue
		battle.place_ashore(i, home)
		return


## Closes the island. **Both outcomes are terminal.**
##
## ⚠⚠ **A WIN ENDS THE RUN, AND THE ENDING IS A PLACEHOLDER.** What used to follow a win was the
## map: cards, then the next of eight islands. The map is deleted and **what replaces it — waves, and
## a boss on a clock — is decided but unbuilt** (`docs/plan/`).
## ⚠⚠ **THE CARD ROUND IN BETWEEN IS DELETED TOO** (2026-08-28, the user: 「둘 다 지우면 돼」). A win
## used to deal three cards so the card and refit screens stayed reachable; both screens are gone, so
## a win goes straight to `WON`.
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
	_advance()


## ⚠⚠ **`_draw_cards`, `take_card`, `_cards_taken_count` AND `close_refit` STOOD HERE AND ALL FOUR
## ARE DELETED** (2026-08-28, the user: 「고르는 창도 이제 필요 없는데 왜있지? 이것도 제거」 ·
## 「둘 다 지우면 돼」). Between them they were the whole growth loop: a win dealt
## `Rules.CARDS_PER_WIN` items by rarity, the player took `Rules.CARD_PICKS` of them, and the taken
## pile went onto a board in `army.loadout`.
##
## ⚠⚠ **WHAT IS LOST, SAID OUT LOUD.** The rarity roll's own argument — 「rarity first, item second, or
## legendaries get rarer every time a common one is added」 — is a real measurement and it is written
## down nowhere else. **`Rules.rarity_at_roll` / `items_of_rarity` / `rarity_weight_total` are
## untouched in `rules.gd`**, so the table survives; what is gone is the only thing that called them.
## ⚠ **The no-duplicates rule died earlier and its measurement is recorded there**: drawn with
## replacement, 64% of opening rounds held a duplicate and 6% were three of one animal.
##
## ⚠ **`Army.loadout` is untouched.** `Battle` reads the fitted board to work out what a blow is
## worth, and a run still starts with whatever `Army` puts there.


## `State.BATTLE`, `State.PICK`, `State.REFIT`, `State.WON` or `State.LOST`.
func state() -> int:
	return _state


## **`WON` if the island has already been held, else the island opens.**
##
## ⚠⚠ **A `PICK` ARM STOOD ABOVE THESE TWO AND IS DELETED** (2026-08-28) with the card round. Its own
## note is worth keeping because the shape recurs: it had to be FIRST, or the cards were dealt, never
## shown, and every check that only counted soldiers stayed green.
##
## ⚠ **Losing is not decided here.** `finish_island` owns that, and `_island_cleared` is the only thing
## this function reads about the island at all.
##
## ⚠ **Two arms and one caller left.** It is kept as a function rather than inlined into
## `finish_island` because the day waves arrive, this is where 「another wave or the run is over」 goes.
func _advance() -> void:
	if _island_cleared:
		_state = State.WON
	else:
		_state = State.BATTLE