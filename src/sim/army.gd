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

## Columns. Same length, always, and index `i` means the same soldier in all four.
var type_id := PackedInt32Array()
var hp := PackedFloat32Array()
var has_beak := PackedByteArray()
var alive := PackedByteArray()


## Appends one soldier at full HP, no beak, alive. Returns its id — its index, which never changes again.
##
## The parameter shadows the `type_id` column and the name is fixed by the plan, so the column is reached
## through `self` on purpose: a bare `type_id.append(...)` here would call `append` on an int.
@warning_ignore("shadowed_variable")
func add(type_id: int) -> int:
	var id := self.type_id.size()
	self.type_id.append(type_id)
	hp.append(Rules.hp_of(type_id))
	has_beak.append(0)
	alive.append(1)
	return id


## Marks a soldier dead. The row stays; only `alive` and `hp` move.
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


## Attack range in tiles: the type's base, plus the beak's bonus if this soldier is wearing one.
func range_of(i: int) -> float:
	var base: float = Rules.range_of(int(type_id[i]))
	var bonus: float = Rules.BEAK_RANGE if has_beak[i] != 0 else 0.0
	return base + bonus


func living_count() -> int:
	var n := 0
	for i in range(alive.size()):
		if alive[i] != 0:
			n += 1
	return n


## The force a run starts with, in melee-then-ranged order. Called on a fresh `Army`; it appends, so a
## caller that wants a clean start builds a new one rather than clearing this.
func add_starting_force() -> void:
	for _i in range(Rules.START_MELEE):
		add(Rules.CELL_MELEE)
	for _i in range(Rules.START_RANGED):
		add(Rules.CELL_RANGED)
