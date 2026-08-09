extends RefCounted
## The research bench's catalogue — **what 원석 can buy, in one table**
## (`research-bench-unlocks.md`).
##
## **The seat is the one `monster_defs.gd` already holds**: id constants + an explicit ordered `DEFS` list +
##  static accessors. A rule table, not presentation and not sim. `src/actor/`, so it may reach `src/sim/`
##  for the rune ids and may **not** reach `src/view/` (`net_layers` — which forbids a *path* into that
##  folder, not a Korean string: `monster_defs.gd` holds `&"돼지"` in this same folder, and that is the
##  precedent `name_of()` below follows).
##
## **무 earns a row even though it is never for sale.** The item row's job is to show the whole pool
##  (`docs/design/town.md`: "unlocked and locked in one list"), so a rune the player already owns has to be
##  in the list to be shown owned. Marking it not-for-sale is a fact about it, not a stub.
##
## **`DEFS` is an `Array`, not a `Dictionary`, because the order is read.** The chips are laid out in table
##  order and `net_research` asserts that order against `Tuning.ELEM_ALL` — a `Dictionary` keyed by id would
##  make "the order the player sees" an accident of insertion that nothing states out loud.
##
## **There is no cost column.** All three buyable rows cost the same and that number lives in
##  `progress.GEMS_PER_UNLOCK`, beside the two that pay it out — earn and spend in one file. A per-row column
##  holding the same 10 three times is CLAUDE.md's "a value counted in two places will diverge".

const Tuning := preload("res://src/sim/sim_tuning.gd")

## **Ids are this table's own namespace and are deliberately not the rune ids.** `rune_of()` is the one
##  translation, so a non-rune unlock (the double jump) has somewhere to be — an id space shared with
##  `Tuning.ELEM_*` would have no room for it, and the day a second body unlock appears the collision is
##  silent (both are small integers).
const UNLOCK_RUNE_FIRE := 0
const UNLOCK_RUNE_NONE := 1
const UNLOCK_RUNE_WATER := 2
const UNLOCK_DOUBLE_JUMP := 3

## Which research row an unlock hangs under. **The strings are `Fx.RESEARCH_ROWS`' own first column** — the
##  window looks a row's unlocks up by the same key it already draws that row's icon with, so a renamed row
##  does not need a second table fixed to match.
const AXIS_ITEM := "item"
const AXIS_BODY := "body"

## **`rune` is −1 for an unlock that grants no rune**, not absent — `rune_of()` returning −1 is what
##  `progress.buy()` branches on, and an absent key would make "no rune" and "a typo in the row" the same
##  answer.
##
## **The order is `Tuning.ELEM_ALL`'s order** (불 · 무 · 물), so the item row's chips read left to right in
##  the same order the state line has always printed them in. `net_research` asserts this rather than
##  trusting it — add a fourth rune and forget the row and that check goes red.
##
## **`name` is empty for every rune row, deliberately.** A rune's Korean name already has exactly one home
##  (`fx_tuning.ELEM_NAMES`, which the item row's state line has always printed from and which
##  `net_town._the_item_row_is_the_rune_pool` reads); copying it here would be CLAUDE.md's "a value counted
##  in two places will diverge", and the day someone renames 물 the bench would print the old name beside
##  the new one. Only an unlock that grants **no** rune needs a name of its own.
const DEFS: Array = [
	{"id": UNLOCK_RUNE_FIRE, "axis": AXIS_ITEM, "rune": Tuning.ELEM_FIRE, "for_sale": true, "name": ""},
	{"id": UNLOCK_RUNE_NONE, "axis": AXIS_ITEM, "rune": Tuning.ELEM_NONE, "for_sale": false, "name": ""},
	{"id": UNLOCK_RUNE_WATER, "axis": AXIS_ITEM, "rune": Tuning.ELEM_WATER, "for_sale": true, "name": ""},
	{"id": UNLOCK_DOUBLE_JUMP, "axis": AXIS_BODY, "rune": -1, "for_sale": true, "name": "2단 점프"},
]


## The row for `id`, or an empty `Dictionary` for an id that is not in the table. **Every accessor below goes
##  through this one lookup** — five separate loops over `DEFS` would be five places to forget the
##  unknown-id case, and an unknown id has to answer "no" everywhere rather than crash in one place and
##  return a plausible value in another.
static func _row(id: int) -> Dictionary:
	for d: Dictionary in DEFS:
		if int(d["id"]) == id:
			return d
	return {}


## Is `id` a row in this table at all.
static func has_id(id: int) -> bool:
	return not _row(id).is_empty()


## **Can this ever be bought** — a fact about the catalogue, not about the player. Whether the player *may*
##  buy it right now is `progress.can_buy()`, which asks this and then asks what has already been bought.
## **False for an id outside the table**, so a stale id can never spend 원석.
static func is_for_sale(id: int) -> bool:
	return bool(_row(id).get("for_sale", false))


## Which rune `id` grants, or **−1 for an unlock that grants none** (and for an unknown id).
static func rune_of(id: int) -> int:
	return int(_row(id).get("rune", -1))


## Which research row `id` hangs under, or `""` for an unknown id.
static func axis_of(id: int) -> String:
	return String(_row(id).get("axis", ""))


## What this unlock is called on screen — **`""` for a rune row, whose name lives in `fx_tuning.ELEM_NAMES`**
##  (the `DEFS` box above has why). The window branches on `rune_of() >= 0` to pick which of the two to ask,
##  so each name still has exactly one home.
static func name_of(id: int) -> String:
	return String(_row(id).get("name", ""))


## Every id on `axis`, **in table order** — the order the chips are drawn and pressed in.
static func ids_for_axis(axis: String) -> Array[int]:
	var out: Array[int] = []
	for d: Dictionary in DEFS:
		if String(d["axis"]) == axis:
			out.append(int(d["id"]))
	return out


## Every id in the table, in table order.
static func ids() -> Array[int]:
	var out: Array[int] = []
	for d: Dictionary in DEFS:
		out.append(int(d["id"]))
	return out
