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
## ⚠⚠ **`enum State { BATTLE, WON, LOST }` STOOD HERE AND IT IS DELETED** (2026-08-29). Nothing could
## leave `BATTLE`: the verdict that moved it went with the fight. **A one-member enum every reader
## compares against is a branch that always takes the same arm**, and that is the shape this file has
## twice been caught carrying — `MAP` went with the map, `PICK` and `REFIT` with the card round.


## The roster that survives the run. Never rebuilt outside `_reset`.
var army: Army = null


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
## ⚠⚠ **THIS IS THE ONE PLACE THE ISLAND FILE AND THE FIGHT MEET.** `Battle` never reads `Islands` — it
## is handed a board, a 성채 and a doorstep, so every net fixture in the repo is a legal island. The
## 성채's own 조각 are what burns; the doorstep is where a 검사 appears, at the opening and after he dies.
func begin_island() -> Battle:
	var grid := Grid.new()
	Islands.load_into(grid)
	var battle := Battle.new()
	battle.setup(grid, army, Islands.spawns(), Islands.keep_tiles(),
			Islands.beside_home_tile(grid.w))
	_stand_the_watch(battle)
	return battle


## **One body is already on the island when it opens, standing by the keep.**
##
## ⚠⚠ **This is the swap, made concrete.** While the player was the side that ARRIVED, an empty island
## was correct and every body reached it by boat. The sides turned over 2026-08-26 — the company holds
## this island and the beasts are what lands on it — and an island that opens with nobody on it says
## the opposite of that on the one screen the player actually looks at.
##
## ⚠⚠ **EVERY LIVING BODY, AND IT USED TO BE EXACTLY ONE** (2026-08-27, the user: ***"칸단위 부대는
## 따로 없음 아직"***). Squads did not exist, so ten bodies would have walked as one lump. **티켓 41
## settles the unit as 「몸 하나」** — bodies are commanded one at a time — so there is nothing left for
## the split to buy, and what it cost was nine bodies that existed, counted, and could never be seen.
## ⇒ **The roster and the picture are `Rules.SWORDSMAN_START_COUNT`, one number.**
##
## ⚠ **BESIDE the keep and not ON it**, and that is no longer this function's problem: `Battle.setup`
## reserves the 성채's own 조각, so the free-tile search cannot hand back a 조각 inside the house. It was
## measured 2026-08-27 and read exactly like「아무도 안 세워졌다」.
## ⚠ Silent when there is nowhere to stand: `stand_at_keep` answers -1 and that body is simply not on
## the board, which is the honest picture of an island with no free land beside its 성채.
func _stand_the_watch(battle: Battle) -> void:
	for i in army.type_id.size():
		if army.alive[i] == 0:
			continue
		battle.stand_at_keep(i)


## ⚠⚠ **`finish_island` · `state` · `_advance` · `_island_cleared` STOOD HERE AND ALL FOUR ARE
## DELETED** (2026-08-29) with the fight. **A run had three states — BATTLE, WON, LOST — and nothing
## could reach the last two**: the island file carries no beasts, so there was never a verdict to
## finish on. `finish_island` said so in its own header and returned a placeholder.
##
## ⚠ **What the placeholder was covering is still true and still unbuilt**: 「제한 시간이 지나면
## 보스가 온다」 and the waves that bring the beasts ashore. **A run is one island until one of those
## exists**, and this is where the run-long clock belongs when it is built — not on `islands.gd`,
## which knows one island and not a session.
