class_name Loadout
extends RefCounted
## The boards — one per BEAST TYPE — and the held pile a card pays into and an unfit returns to.
## **Flat arrays. No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`.** Constructible and drivable
## with `.new()` and nothing else, matching every other file under `src/sim/`.
##
## ⚠⚠ **THE BOARD HANGS ON THE TYPE, NOT ON THE SUMMON SLOT** (티켓 11, the user: 「전체에서 세는걸로하자
## 그래야 버리는 것도 주워서 안쓰는 자기 몬스터에게도 넣을 수 있게」). Keyed by slot, only the two
## summoned species could take equipment and every other card was a dead draw; keyed by type, all five
## boards exist and the whole-horde tag count below has something to count. Slot and type are 1:1 on
## the summoned pair, so every caller that passed a slot id keeps working unchanged.
##
## ⚠⚠ **THE CELLS HAVE NO NAMES** (2026-08-24, the user: 「이게 세포 게임에 남아있던 것들이네. 갈아엎어」).
## This file used to hold a cell per BODY PART — head, chest, belly, arm, hand, leg — with a species
## fitted into each. That was the cell game's board, and it outlived the cell game by two changes of
## direction because the screen never made it visible. **What a cell holds now is an ITEM id**, any item
## goes in any cell, and 티켓 02's 「장비 칸에는 이름이 없다」 is finally the thing the code does.
##
## The board belongs to the TYPE and not to the body: `Army` holds one `Loadout` for its whole
## life, so a soldier dying does not touch it — 「늑대에게 투구를 끼우면 모든 늑대가 낀다」.

## The boards, flat: `board[beast_type * Rules.ITEM_CELLS + cell]` is the ITEM in that cell, or -1.
var board := PackedInt32Array()

## The pile a card pays into and an unfit returns to. **One array now, not two** — a card is one item,
## where it used to be a (part, species) pair held in two index-aligned arrays.
var held := PackedInt32Array()


func _init() -> void:
	reset()


## Every cell -1, the pile empty. Shared by `_init` and `Army`'s own construction, the same reason
## `Run._reset` is shared.
func reset() -> void:
	board = PackedInt32Array()
	board.resize(Rules.TYPE_COUNT * Rules.ITEM_CELLS)
	for i in board.size():
		board[i] = -1
	held = PackedInt32Array()


## The item in that cell, or -1 for an empty cell or an out-of-range type/cell. Out of range is a
## refusal, not a fault.
func fitted_item(beast_type: int, cell: int) -> int:
	if beast_type < 0 or beast_type >= Rules.TYPE_COUNT:
		return -1
	if cell < 0 or cell >= Rules.ITEM_CELLS:
		return -1
	return int(board[beast_type * Rules.ITEM_CELLS + cell])


## The first cell on this type with nothing in it, or -1 when the board is full. **The whole of what
## unnamed cells cost**: with named cells the target was decided by the card, and now it is decided
## here, in one place, so no caller has to hunt for a hole.
func first_empty(beast_type: int) -> int:
	for cell in Rules.ITEM_CELLS:
		if fitted_item(beast_type, cell) < 0:
			return cell
	return -1


## How many fitted items across EVERY board carry `tag`. The whole-horde count is what the combo
## tables key on — which board an item sits on changes nothing about whether a tier lights.
func tag_count(tag: int) -> int:
	var n := 0
	for i in board.size():
		var item := int(board[i])
		if item >= 0 and Rules.item_tag_of(item) == tag:
			n += 1
	return n


## Sums `Rules.item_bonus(item, col)` over this type's filled cells, plus the horde-wide numeric tag
## term for `col`. ⚠⚠ This one function is the whole of the room set effects need — the tag term was
## added here and no consumer moved, exactly as this header once promised.
func bonus(beast_type: int, col: int) -> float:
	if beast_type < 0 or beast_type >= Rules.TYPE_COUNT:
		return 0.0
	var sum := 0.0
	for cell in Rules.ITEM_CELLS:
		var item := fitted_item(beast_type, cell)
		if item >= 0:
			sum += Rules.item_bonus(item, col)
	# The numeric tag tiers: counted over every board, added flat to every type's column — the
	# 「전체에 적용되는 아티팩트」 the user asked for. Tier replacement lives in the accessor.
	for r in Rules.tag_stat_row_count():
		if Rules.tag_stat_col_of(r) == col:
			sum += Rules.tag_stat_bonus_at(r, tag_count(Rules.tag_stat_tag_of(r)))
	return sum


## `Rules.unit_stat(beast_type, col) + bonus(beast_type, col)`. ⚠⚠ Every number in the game that a
## piece of equipment or a lit tag can move comes out of THIS call — the fight's and the dashboard's
## alike.
func stat_of(beast_type: int, col: int) -> float:
	if beast_type < 0 or beast_type >= Rules.TYPE_COUNT:
		return 0.0
	var value := Rules.unit_stat(beast_type, col) + bonus(beast_type, col)
	# ⚠⚠ **The ONE clamped column, and it became reachable the day cells lost their names.** See
	# `Rules.PERIOD_FLOOR_SEC`: six copies of one item is a board now, and six of the fastest drives an
	# attack period negative — a body attacking backwards in time. The ATK_SPEED tag term is inside
	# `bonus`, so it stands on this same floor.
	if col == Rules.ITEM_COL_PERIOD:
		return maxf(Rules.PERIOD_FLOOR_SEC, value)
	return value


## Fits the held card at `held_index` into the first empty cell on `beast_type`'s board. False and
## **changes nothing** on a bad type, a bad index, or a full board.
##
## ⚠ **All five species accept — a summon slot is not asked for.** 「버리는 것도 주워서 안쓰는 자기
## 몬스터에게도 넣을 수 있게」: a board with no slot behind it still feeds the whole-horde tag count,
## so no card is a dead draw.
##
## ⚠ **A full board REFUSES rather than swapping.** With named cells the card named its own target and a
## swap was the only sensible answer; with unnamed cells a swap would have to choose a victim, and a
## choice made silently inside a fit is a choice the player never made. Unfit first, then fit.
func fit(beast_type: int, held_index: int) -> bool:
	if beast_type < 0 or beast_type >= Rules.TYPE_COUNT:
		return false
	if held_index < 0 or held_index >= held.size():
		return false
	var cell := first_empty(beast_type)
	if cell < 0:
		return false
	var item := int(held[held_index])
	held.remove_at(held_index)
	board[beast_type * Rules.ITEM_CELLS + cell] = item
	return true


## Clears one cell and returns its item to the pile. False on an empty cell — and changes nothing when
## it is.
func unfit(beast_type: int, cell: int) -> bool:
	if beast_type < 0 or beast_type >= Rules.TYPE_COUNT:
		return false
	if cell < 0 or cell >= Rules.ITEM_CELLS:
		return false
	var at := beast_type * Rules.ITEM_CELLS + cell
	var item := int(board[at])
	if item < 0:
		return false
	board[at] = -1
	held.append(item)
	return true


## Appends to the pile. The only way anything enters it.
func take_card(item: int) -> void:
	held.append(item)
