class_name Army
extends RefCounted
## The roster that survives islands. One row per soldier, in flat parallel arrays, and **a dead row is
## never removed** — `alive` flips to 0 and the row stays where it was forever.
##
## **That is a correctness contract, not a performance one.** The deleted swarm kept its cargo in a
## parallel flat array, and that is the whole reason "a body killed far from home loses its cargo" was
## structurally true rather than something a function had to remember to do. The same shape here buys
## permanent death for free: a soldier's index is its identity for the whole run, so `battle`, `run` and
## the reward screen may all hold ids across islands without any of them being told that somebody died.
##
## ⇒ **Never compact these arrays.** Removing a dead row renumbers every soldier after it, and every id
## already held elsewhere would then quietly name a different soldier — a swap with no error anywhere.
## `living_count` and `living_ids_of_type` are what a caller wants when it means "the living ones";
## `type_id.size()` is the roster's history and is deliberately not the same number.
##
## See the cell army GDD for what a soldier is, and the first-slice plan's "The sim — shapes and entry
## points" for the signatures below.

## Every value that changes what happens lives in `rules.gd`, reached through its global `Rules` class
## name the way `islands.gd` reaches it. Nothing in this file may hold a second copy of a number that
## rules already names — a value counted in two places diverges.
##
## Not `const Rules := preload(...)`: `rules.gd` declares `class_name Rules`, so a constant of that name
## collides with the global identifier — and a hard-coded path to a sim file is the second copy of a fact
## the class name already carries.

## Columns. Same length, always, and index `i` means the same soldier in all five.
var type_id := PackedInt32Array()
var hp := PackedFloat32Array()
var has_beak := PackedByteArray()
var alive := PackedByteArray()

## Which summon slot this body belongs to. Written once, by `recruit`, and never again.
## ⚠⚠ **It stays although the five stat lookups below key on `type_id` now** (티켓 11 moved the board
## from the slot to the type): boarding and the reserve filter are SLOT facts — two slots bound to one
## type must not draw from one pool — and `Battle.slot_reserve_ids` reads exactly this column.
var slot_id := PackedInt32Array()

## The boards, one per beast type. Hangs off the ARMY and not off `Run`: `Battle` is handed `army` and
## nothing else, so this is what lets `damage_of(i)` reach a board without a new argument on
## `Battle.setup`. It also makes the design's own sentence structural — a body dies and its parts die
## with it, the board does not — because `Army` outlives every `Battle` and no code has to remember to
## move a board across an island.
var loadout := Loadout.new()


## Appends one soldier of `slot`'s type, born at that type's own current maximum HP, no beak, alive.
## Returns its id — its index, which never changes again.
##
## ⚠ The HP is read back off `max_hp_of`, the same function combat reads, so a body is never born on a
## number nothing else uses.
func recruit(slot: int) -> int:
	var t := Rules.summon_type_of(slot)
	var id := type_id.size()
	type_id.append(t)
	slot_id.append(slot)
	has_beak.append(0)
	alive.append(1)
	hp.append(0.0)
	hp[id] = max_hp_of(id)
	return id


## Marks a soldier dead. The row stays; only `alive` and `hp` move. **The type's board is untouched** —
## it belongs to the type, not to the body, so the next body `recruit`ed of that type arrives with the
## same equipment.
func kill(i: int) -> void:
	if alive[i] == 0:
		return
	alive[i] = 0
	# HP is clamped, not left as the attacker wrote it. An overkill leaves a negative remainder in a
	# column that the probe sums to print "HP pool in and out", and a negative row would make the pool
	# read low with nothing to point at — the sum is the only place it would ever show.
	hp[i] = 0.0


## Living soldiers of one type, **highest HP first**. This is the boarding order: the plan's rule is
## "the highest-HP living soldier of that type that is still in reserve".
func living_ids_of_type(t: int) -> Array:
	var out: Array = []
	for i in range(type_id.size()):
		if alive[i] != 0 and type_id[i] == t:
			out.append(i)
	out.sort_custom(_hp_desc)
	return out


## Ties break on the smaller id. `sort_custom` is not guaranteed stable, so without this two soldiers on
## equal HP would board in whatever order the sort happened to produce — and two runs from identical
## state would then diverge with every check about them still green.
##
## The tie is exact `==`, not `is_equal_approx`. An approximate tie is not transitive — `a≈b` and `b≈c`
## with `a≠c` — and a comparator that is not a strict weak ordering makes `sort_custom` free to return
## anything at all. Damage lands in exact steps here, so exact ties are exactly what occurs.
func _hp_desc(a: int, b: int) -> bool:
	if hp[a] == hp[b]:
		return a < b
	return hp[a] > hp[b]


## Attack range in tiles: the type's board (base + any fitted range item and the lit 범위 tier), plus
## the beak's bonus if this soldier is wearing one. The beak is added HERE and never inside
## `loadout.stat_of`, which knows nothing about a per-soldier reward.
func range_of(i: int) -> float:
	var base := loadout.stat_of(int(type_id[i]), Rules.ITEM_COL_RANGE)
	var bonus: float = Rules.BEAK_RANGE if has_beak[i] != 0 else 0.0
	return base + bonus


## The five per-soldier lookups. Each is one line reading `loadout.stat_of(type_id[i], COL)` — the same
## call the dashboard reads, so the screen and the fight can never disagree about what a fitted item is
## worth. ⚠ **Keyed on `type_id`, never `slot_id`** (티켓 11): the board is the type's, and a body of a
## species no slot summons still has to read its own board.
func max_hp_of(i: int) -> float:
	return loadout.stat_of(int(type_id[i]), Rules.ITEM_COL_HP)


func damage_of(i: int) -> float:
	return loadout.stat_of(int(type_id[i]), Rules.ITEM_COL_DAMAGE)


func period_of(i: int) -> float:
	return loadout.stat_of(int(type_id[i]), Rules.ITEM_COL_PERIOD)


func speed_of(i: int) -> float:
	return loadout.stat_of(int(type_id[i]), Rules.ITEM_COL_SPEED)


## Living soldiers of one SLOT, **highest HP first**. Mirrors `living_ids_of_type`'s shape and its
## comparator for the same reason: `sort_custom` is not stable, so two bodies on equal HP would
## otherwise board in whatever order the sort happened to produce.
func living_ids_of_slot(slot: int) -> Array:
	var out: Array = []
	for i in range(type_id.size()):
		if alive[i] != 0 and int(slot_id[i]) == slot:
			out.append(i)
	out.sort_custom(_hp_desc)
	return out


func living_count() -> int:
	var n := 0
	for i in range(alive.size()):
		if alive[i] != 0:
			n += 1
	return n


## The force a run starts with, slot by slot. Called on a fresh `Army`; it appends, so a caller that
## wants a clean start builds a new one rather than clearing this.
## ⚠ **No type is named in this function any more.** `SUMMON_SLOTS`' own header says a third binding
## costs one row here and nothing else, and this is the function that makes that true for the roster.
func add_starting_force() -> void:
	for s in Rules.summon_slot_count():
		for _i in range(Rules.slot_start_count(s)):
			recruit(s)
