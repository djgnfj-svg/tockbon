class_name Loadout
extends RefCounted
## The boards — one per summon slot — and the held pile a card pays into and an unfit returns to.
## **Flat arrays. No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`.** Constructible and drivable
## with `.new()` and nothing else, matching every other file under `src/sim/`.
##
## See `parts-on-a-board-not-on-the-body` for the design. The board belongs to the SLOT and not to the
## body: `Army` holds one `Loadout` for its whole life, so a soldier dying does not touch it — the slot's
## upgrade outlives the body the same way the beak's per-soldier bonus does not.

## The boards, flat: `board[slot * Rules.part_count() + part]` is the SPECIES fitted in that cell, or -1.
## ⚠ The cell holds a species and not a part id, because the cell IS the part. There is no arrangement in
## which a leg can sit in the head cell, so there is no rule anywhere that has to forbid it.
var board := PackedInt32Array()

## The pile a card pays into and an unfit returns to. Two parallel arrays, index-aligned, the shape
## `army.gd` uses and for the same reason.
var held_part := PackedInt32Array()
var held_species := PackedInt32Array()


func _init() -> void:
	reset()


## Every cell -1, the pile empty. Shared by `_init` and `Army`'s own construction, the same reason
## `Run._reset` is shared.
func reset() -> void:
	board = PackedInt32Array()
	board.resize(Rules.summon_slot_count() * Rules.part_count())
	for i in board.size():
		board[i] = -1
	held_part = PackedInt32Array()
	held_species = PackedInt32Array()


## The cell's own species, or -1 for an empty cell or an out-of-range slot/part. Out of range is a
## refusal, not a fault.
func fitted_species(slot: int, part: int) -> int:
	if slot < 0 or slot >= Rules.summon_slot_count():
		return -1
	if part < 0 or part >= Rules.part_count():
		return -1
	return int(board[slot * Rules.part_count() + part])


## Sums `Rules.part_bonus(part, col)` over the cells that are filled. ⚠⚠ This one function is the whole
## of the room sets need — a set term is added here and no consumer moves.
func bonus(slot: int, col: int) -> float:
	if slot < 0 or slot >= Rules.summon_slot_count():
		return 0.0
	var sum := 0.0
	for part in Rules.part_count():
		if fitted_species(slot, part) >= 0:
			sum += Rules.part_bonus(part, col)
	return sum


## `Rules.unit_stat(Rules.summon_type_of(slot), col) + bonus(slot, col)`. ⚠⚠ Every number in the game
## that a part can move comes out of THIS call — the fight's and the dashboard's alike.
func stat_of(slot: int, col: int) -> float:
	return Rules.unit_stat(Rules.summon_type_of(slot), col) + bonus(slot, col)


## Fits the held card at `held_index` into its own part's cell on `slot`. False and **changes nothing**
## on a bad slot or index.
## ⚠ **Order is a contract**: the card is read and removed from the pile FIRST, then any occupant of the
## target cell is pushed back onto the pile, then the cell is written. Pushing first and removing second
## would renumber the pile under the index being removed.
func fit(slot: int, held_index: int) -> bool:
	if slot < 0 or slot >= Rules.summon_slot_count():
		return false
	if held_index < 0 or held_index >= held_part.size():
		return false
	var part := int(held_part[held_index])
	var species := int(held_species[held_index])
	held_part.remove_at(held_index)
	held_species.remove_at(held_index)
	var cell := slot * Rules.part_count() + part
	var occupant := int(board[cell])
	if occupant >= 0:
		held_part.append(part)
		held_species.append(occupant)
	board[cell] = species
	return true


## Clears the cell for `part` on `slot` and returns its species to the pile. False on an empty cell —
## and changes nothing when it is.
func unfit(slot: int, part: int) -> bool:
	if slot < 0 or slot >= Rules.summon_slot_count():
		return false
	if part < 0 or part >= Rules.part_count():
		return false
	var cell := slot * Rules.part_count() + part
	var species := int(board[cell])
	if species < 0:
		return false
	board[cell] = -1
	held_part.append(part)
	held_species.append(species)
	return true


## Appends to the pile. The only way anything enters it.
func take_card(part: int, species: int) -> void:
	held_part.append(part)
	held_species.append(species)
