extends RefCounted
## Glyph table + pack/unpack of the **remaining glyph list**.
##
## **The "remaining glyph list" a bolt carries is a single integer.** Stacked 4 bits per nibble.
##
## ```
## list [spread, blast]  ->  g = spread | (blast << 4)
##
## first glyph    first(g) = g & 0xF
## remaining list rest(g)  = g >> 4
## end of list    g == 0                    <- obtained by reserving GLYPH_NONE = 0
## ```
##
## What this choice buys:
##  · **It doesn't break the parallel-array contract.** Zero heap allocation. "Hand the remaining list to a new bolt" is **an integer assignment**
##  · **blast -> blast -> … cannot be infinite.** `rest` shrinks 4 bits each time, so 7 iterations at most reach 0.
##    **A ceiling guard is unnecessary in principle**
##  · **A command grows by only 4 bytes** — the GDD's "destruction is an event, so it's free" argument survives intact
##
## **Shifting happens only inside these three functions.** Shift in two places and they will diverge.

const Tuning := preload("res://src/sim/sim_tuning.gd")

## **A reserved value. "End of list" is 0.** That is why glyph ids start at 1.
const GLYPH_NONE := 0

## The two kinds of glyph. **This distinction is the entire pipeline** (GDD, "Glyph execution rules").
##  · SPAWN    creates bolts -> **hands the remaining list to the new bolts**
##  · TERMINAL ends in place -> no bolt is created, so **the next glyph continues at the same spot**
const KIND_SPAWN := 0
const KIND_TERMINAL := 1

const MASK := (1 << Tuning.GLYPH_BITS) - 1

# --- glyph ids -----------------------------------------------------
# ids are int and **iteration goes only through the explicit `ALL` list** — never assume contiguity.
const GLYPH_SPREAD := 1
const GLYPH_BLAST := 2

## **One glyph = one row here + one branch in `spell_sim._run_glyph` + (if the presentation differs)
##  one row in `fx_tuning`. A fourth place appearing means the structure is wrong.**
##
##   kind            SPAWN creates bolts and hands over the list · TERMINAL continues at the same spot
##   max_per_circle  how many per magic circle. **0 = unlimited.**
##     The GDD blocks the explosion with **constraints**, not a cap — with one spread only,
##     the 8 -> 64 explosion becomes **structurally impossible.** The consumer is `spell_sim.fire()` (the command boundary).
##   tick_budget     how many may run per tick. **0 = unlimited.**
##     The overflow is **not discarded but deferred with its remaining list** (`spell_sim._defer`).
##     The point is that the budget is a table field — pipeline code has no reason to know a specific glyph id.
const DEFS: Dictionary = {
	# **`max_per_circle: 1` is the GDD's entire explosion defense.** With one spread only,
	#  the 8 -> 64 explosion is **structurally impossible** — which is why the simultaneous-projectile
	#  cap is not used as a tuning knob (a bolt that fails to fire because of a cap reads as **a malfunction**).
	#  => The problem surfaces at **assembly time**, not firing time.
	GLYPH_SPREAD: {
		"name": &"확산", "kind": KIND_SPAWN,
		"max_per_circle": 1,
		"tick_budget": 0,
	},
	GLYPH_BLAST: {
		"name": &"폭발", "kind": KIND_TERMINAL,
		"max_per_circle": 0,
		"tick_budget": Tuning.MAX_BLASTS_PER_TICK,
	},
}

## Iteration goes **only through this explicit list**.
const ALL: Array[int] = [GLYPH_SPREAD, GLYPH_BLAST]


## Flat table of tick budgets. Once at boot — a dictionary lookup per impact stacks VM calls on its own.
## Length is `MASK + 1` so the id indexes directly. Ids missing from the table read 0 (unlimited),
##  but such ids are already filtered by `fire()`'s validation.
static func bake_tick_budget() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(MASK + 1)
	for id: int in ALL:
		out[id] = int(DEFS[id]["tick_budget"])
	return out


## List -> integer. Barks and returns 0 (empty list) for an unusable list.
## This checks **structure only** (does it fit a nibble · is the layer count within the ceiling).
##  "Does that glyph exist" and "how many per magic circle" are checked by `spell_sim.fire()` —
##  the only command boundary crossing the line, so validation has nowhere else to go.
static func pack(list: Array[int]) -> int:
	if list.size() > Tuning.GLYPH_MAX_LAYERS:
		push_error("Glyph: %d layers - the ceiling is %d" % [list.size(), Tuning.GLYPH_MAX_LAYERS])
		return GLYPH_NONE
	var g := 0
	for i in list.size():
		var id: int = list[i]
		if id <= GLYPH_NONE or id > MASK:
			push_error("Glyph: glyph id %d is outside the nibble range (1..%d)" % [id, MASK])
			return GLYPH_NONE
		g |= id << (i * Tuning.GLYPH_BITS)
	return g


## The glyph to run now. 0 means the list is empty.
static func first(g: int) -> int:
	return g & MASK


## The remainder. It shrinks 4 bits each time, so **termination is guaranteed.**
static func rest(g: int) -> int:
	return g >> Tuning.GLYPH_BITS


## How many of this glyph the list holds. For validating `max_per_circle`.
static func count_of(g: int, id: int) -> int:
	var n := 0
	var cur := g
	while cur != GLYPH_NONE:
		if first(cur) == id:
			n += 1
		cur = rest(cur)
	return n
