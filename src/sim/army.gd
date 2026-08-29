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
## ⚠ **The 「cell army GDD」 this line used to cite does not exist** (2026-08-25, 티켓 23) — it was the
## deleted cell game's design document, and there is no GDD in this repo at all. What a body is, is
## read out of `CONTEXT.md` and `Rules.UNITS`. See the first-slice plan's "The sim — shapes and entry, and the first-slice plan's "The sim — shapes and entry
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
## ⚠⚠ **`hp` STOOD HERE AND IT IS DELETED** (2026-08-29) with the fight. Nothing damaged a body,
## so every row sat at its birth value for the whole run. ⚠ **`alive` is NOT deleted with it** — it
## is what makes a body permanent-dead across islands, and `battle.setup` still reads it.
var alive := PackedByteArray()

## Which summon slot this body belongs to. Written once, by `recruit`, and never again.
## ⚠⚠ **It stays although the five stat lookups below key on `type_id` now** (티켓 11 moved the board
## from the slot to the type): boarding and the reserve filter are SLOT facts — two slots bound to one
## type must not draw from one pool — and `Battle.slot_reserve_ids` reads exactly this column.
var slot_id := PackedInt32Array()

## **Which species each summon slot fields — slot index to unit row.** ⚠⚠ **This was a CONSTANT table
## in `rules.gd` and it is run state now** (티켓 15): 「칸 s 는 영원히 종 t 에 묶여 있다」 stopped being
## true when a card started filling slots, and a constant holding a per-run fact is a shape this repo
## has paid for.
##
## ⚠⚠ **It hangs off the ARMY for the same reason the boards below do — `Battle` is handed `army` and
## nothing else.** The fight reads the slots (`slot_reserve_ids`, `summon`), so putting them on `Run`
## would add an argument to `Battle.setup` and give the fight a second thing to be handed.
var slots := PackedInt32Array()

## ⚠⚠ **`var loadout := Loadout.new()` STOOD HERE AND IT IS DELETED** (2026-08-29). The equipment
## board hung off the ARMY so `damage_of(i)` could reach it without a new argument on `Battle.setup`,
## and it outlived every `Battle` so a body could die without its type's parts dying with it. **Both
## arguments still hold and neither had anything to hold up**: with the refit screen deleted nothing
## ever fitted an item, so the board was empty for the whole of every run and `stat_of` returned the
## base number every time. The one lookup left reads `Rules` straight.


## Appends one soldier of `slot`'s type, alive. Returns its id — its index, which never changes again.
## ⚠ **The HP column went with the fight** (2026-08-29); a body is born alive and stays so.
func recruit(slot: int) -> int:
	var t := slot_type_of(slot)
	# ⚠⚠ **AN UNREGISTERED SLOT RECRUITS NOBODY, and this line is new with the slots becoming run
	# state.** While the bindings were a constant table every slot in range had a species; now a slot
	# the run has not registered answers `SUMMON_UNBOUND`, and appending a row of type -1 would put a
	# body on the roster that has no stats, no picture and no board — alive, countable, and invisible.
	if t < 0:
		return -1
	var id := type_id.size()
	type_id.append(t)
	slot_id.append(slot)
	alive.append(1)
	return id


## ⚠⚠ **`range_of` · `max_hp_of` · `damage_of` · `period_of` STOOD HERE AND ALL FOUR ARE DELETED**
## (2026-08-29) with the fight. **`speed_of` is the one left**, because a body still walks.
##
## ⚠ **They were keyed on `type_id`, never on `slot_id`**, and that is the rule to keep: a body of a
## species no slot summons still has to read its own row.
##
## ⚠⚠ **A PER-SOLDIER BONUS USED TO BE ADDED IN `range_of` AND IS GONE** (2026-08-25): the beak reward
## put +1 range on ONE body, and the user deleted the reward — 「부리 보상 없지 끝나면 카드보상으로
## 통일했잖아」. **Nothing is per-soldier**; every number a body fights with comes from its species.


func speed_of(i: int) -> float:
	return Rules.speed_of(int(type_id[i]))


## --- the summon slots -----------------------------------------------------------------------------

func slot_count() -> int:
	return slots.size()


## The unit row slot `slot` fields, or **`Rules.SUMMON_UNBOUND` for an out-of-range slot**.
##
## ⚠⚠ **NEVER 0 for an empty slot, and the test on the answer is `< 0` and never `<= 0`.** There is a
## unit row 0, so both mistakes summon the wrong species while every count check downstream passes —
## a slot that refuses looks exactly like an empty roster.
func slot_type_of(slot: int) -> int:
	if slot < 0 or slot >= slots.size():
		return Rules.SUMMON_UNBOUND
	return int(slots[slot])


## The slot fielding `type_id`, or -1. **One place owns "which slot holds this species"** — the
## refusal below reads it, and so does every caller that has a species and wants the key to summon it.
func slot_of_type(type_id: int) -> int:
	for s in slots.size():
		if int(slots[s]) == type_id:
			return s
	return -1


## Puts `type_id` in the next free slot and returns that slot, or **-1 with nothing changed**.
##
## Refused when: the row is not a real unit row · **the row is on the enemy's side** · that species
## already has a slot · every slot is taken. ⚠ **The enemy refusal is the one the deleted constant
## table could only warn about in prose** — with slots writable at runtime there is a door to try it
## through, and an enemy body walking out of a summon box would look completely ordinary.
##
## ⚠ **A full roster REFUSES rather than replacing** — a
## choice made silently inside a registration is a choice the player never made. The screen that asks
## which one to drop is 티켓 05 결정 10.
func register_species(type_id: int) -> int:
	if type_id < 0 or type_id >= Rules.UNITS.size():
		return -1
	if Rules.side_of(type_id) != Rules.Side.PLAYER:
		return -1
	if slot_of_type(type_id) >= 0:
		return -1
	if slots.size() >= Rules.SUMMON_SLOT_MAX:
		return -1
	var slot := slots.size()
	slots.append(type_id)
	return slot


## The force a run starts with, slot by slot: register the opening table's species, then recruit its
## bodies. Called on a fresh `Army`; it appends, so a caller that wants a clean start builds a new one
## rather than clearing this.
## ⚠ **No type is named in this function.** A different opening is one row of `Rules.START_SLOTS`.
func add_starting_force() -> void:
	for s in Rules.START_SLOTS.size():
		# ⚠ Through `register_species` and not by appending: the enemy-side and duplicate refusals have
		# to hold for the OPENING table too, or the one path nobody re-reads is the one that bypasses
		# them. ⚠ **The species is looked up FIRST**, so calling this on an army whose slots are already
		# registered still fills them — the duplicate refusal must not read as "no bodies".
		var ty := Rules.start_type_of(s)
		var slot := slot_of_type(ty)
		if slot < 0:
			slot = register_species(ty)
		if slot < 0:
			continue
		for _i in range(Rules.start_bodies_of(s)):
			recruit(slot)
