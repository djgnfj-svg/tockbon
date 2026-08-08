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

## The three kinds of glyph. **This distinction is the entire pipeline** (GDD, "Glyph execution rules")
##  plus the one addition Stage A opens (`docs/plans/3.done/levelup-and-three-picks.md`, "Cost").
##  · SPAWN    creates bolts -> **hands the remaining list to the new bolts**
##  · TERMINAL ends in place -> no bolt is created, so **the next glyph continues at the same spot**
##  · MODIFY   **touches neither trajectory nor list — it only multiplies `power_pct` into the bolt carrying
##    it, and only at `_launch`** (never at impact — see `spell_sim._launch`'s header for why). It is the
##    **single source of "is this glyph a dummy"** — the screen (stage D) asks `kind == KIND_MODIFY`, not a
##    second boolean column. Two doors asking the same question would drift.
const KIND_SPAWN := 0
const KIND_TERMINAL := 1
const KIND_MODIFY := 2

const MASK := (1 << Tuning.GLYPH_BITS) - 1

# --- families and rarity --------------------------------------------
## **Rarity is a variant of the id, not a second axis carried beside it** (the plan's "one new axis, folded
##  into the id that already exists" — every consumer already carries the id, so folding it in means every
##  consumer follows for free; carrying it beside the id would mean every one of them needs a second argument).
##  `family` is what `max_per_circle` is actually enforced against (`count_family` below) — **the GDD's whole
##  explosion defense is "one spread per circle", and that has to mean one spread of *any* rarity**, or
##  common-spread + rare-spread together still make the 8 -> 64 explosion.
const FAMILY_SPREAD := 0
const FAMILY_BLAST := 1
const FAMILY_DUMMY := 2
const FAMILY_ALL: Array[int] = [FAMILY_SPREAD, FAMILY_BLAST, FAMILY_DUMMY]

const RARITY_COMMON := 0
const RARITY_RARE := 1
const RARITY_UNIQUE := 2
const RARITY_ALL: Array[int] = [RARITY_COMMON, RARITY_RARE, RARITY_UNIQUE]

# --- glyph ids -----------------------------------------------------
# ids are int and **iteration goes only through the explicit `ALL` list** — never assume contiguity.
## **The nibble ceiling is real from here on.** `GLYPH_BITS` is 4 -> 15 ids -> **5 families, not 15 glyphs.**
##  Nine are used below, six spare. The day a 6th family arrives, `Tuning.GLYPH_BITS` goes 4 -> 6 and
##  `GLYPH_MAX_LAYERS` goes 7 -> 5 (written down in the plan so it is not rediscovered then) — **not done here.**
const SPREAD_C := 1
const SPREAD_R := 2
const SPREAD_U := 3
const BLAST_C := 4
const BLAST_R := 5
const BLAST_U := 6
const DUMMY_C := 7
const DUMMY_R := 8
const DUMMY_U := 9

## **Backward-compat aliases.** Every debug preset, screen table and net written before Stage A names the
##  glyph this way — `GLYPH_SPREAD`/`GLYPH_BLAST` **are** the common-rarity id, not a separate thing.
##  Common rows are `power_pct = 100` (below), so every call site still using these two names is
##  **byte-identical to before Stage A** — that is the honesty check the plan asks for on this refactor.
const GLYPH_SPREAD := SPREAD_C
const GLYPH_BLAST := BLAST_C

## **One glyph = one row here + one branch in `spell_sim._run_glyph` (by `kind`, not by id — see that file)
##  + (if the presentation differs) one row in `fx_tuning`. A fourth place appearing means the structure is wrong.**
##
##   kind            SPAWN creates bolts and hands over the list · TERMINAL continues at the same spot ·
##                   MODIFY is consumed whole at `_launch` and never reaches the impact pipeline
##   max_per_circle  how many **of this family** per magic circle. **0 = unlimited.**
##     The GDD blocks the explosion with **constraints**, not a cap — with one spread family only,
##     the 8 -> 64 explosion becomes **structurally impossible.** The consumer is `spell_sim.fire()` (the command boundary).
##   tick_budget     how many may run per tick. **0 = unlimited.**
##     The overflow is **not discarded but deferred with its remaining list** (`spell_sim._defer`).
##     The point is that the budget is a table field — pipeline code has no reason to know a specific glyph id.
##     MODIFY never reaches `_resume`, so this column is meaningless for the dummy rows and left at 0.
##   family          which axis `max_per_circle` is actually counted against (`count_family` below)
##   rarity          common · rare · unique — the three-pick's no-duplicate rule reads this
##   power_pct       base 100. Read in the place natural to the glyph's own kind
##     (`spell_sim.gd`'s "power_pct" section holds the one authoritative explanation — not duplicated here)
const DEFS: Dictionary = {
	# **`max_per_circle: 1` is the GDD's entire explosion defense.** With one spread family only,
	#  the 8 -> 64 explosion is **structurally impossible** — which is why the simultaneous-projectile
	#  cap is not used as a tuning knob (a bolt that fails to fire because of a cap reads as **a malfunction**).
	#  => The problem surfaces at **assembly time**, not firing time.
	SPREAD_C: {
		"name": &"확산", "kind": KIND_SPAWN,
		"max_per_circle": 1, "tick_budget": 0,
		"family": FAMILY_SPREAD, "rarity": RARITY_COMMON, "power_pct": 100,
	},
	SPREAD_R: {
		"name": &"확산", "kind": KIND_SPAWN,
		"max_per_circle": 1, "tick_budget": 0,
		"family": FAMILY_SPREAD, "rarity": RARITY_RARE, "power_pct": 120,
	},
	SPREAD_U: {
		"name": &"확산", "kind": KIND_SPAWN,
		"max_per_circle": 1, "tick_budget": 0,
		"family": FAMILY_SPREAD, "rarity": RARITY_UNIQUE, "power_pct": 150,
	},
	BLAST_C: {
		"name": &"폭발", "kind": KIND_TERMINAL,
		"max_per_circle": 0, "tick_budget": Tuning.MAX_BLASTS_PER_TICK,
		"family": FAMILY_BLAST, "rarity": RARITY_COMMON, "power_pct": 100,
	},
	BLAST_R: {
		"name": &"폭발", "kind": KIND_TERMINAL,
		"max_per_circle": 0, "tick_budget": Tuning.MAX_BLASTS_PER_TICK,
		"family": FAMILY_BLAST, "rarity": RARITY_RARE, "power_pct": 120,
	},
	BLAST_U: {
		"name": &"폭발", "kind": KIND_TERMINAL,
		"max_per_circle": 0, "tick_budget": Tuning.MAX_BLASTS_PER_TICK,
		"family": FAMILY_BLAST, "rarity": RARITY_UNIQUE, "power_pct": 150,
	},
	# **The dummy gets no name of its own — it is named "더미" and nothing else** (the plan: "a dummy is
	#  called a dummy. It gets a name the day the real glyph is decided"). Naming it as if it were a decided
	#  glyph ("damage up") makes the undecided look decided, and this repo has been burned there once already.
	DUMMY_C: {
		"name": &"더미", "kind": KIND_MODIFY,
		"max_per_circle": 0, "tick_budget": 0,
		"family": FAMILY_DUMMY, "rarity": RARITY_COMMON, "power_pct": 120,
	},
	DUMMY_R: {
		"name": &"더미", "kind": KIND_MODIFY,
		"max_per_circle": 0, "tick_budget": 0,
		"family": FAMILY_DUMMY, "rarity": RARITY_RARE, "power_pct": 150,
	},
	DUMMY_U: {
		"name": &"더미", "kind": KIND_MODIFY,
		"max_per_circle": 0, "tick_budget": 0,
		"family": FAMILY_DUMMY, "rarity": RARITY_UNIQUE, "power_pct": 200,
	},
}

## Iteration goes **only through this explicit list**.
const ALL: Array[int] = [SPREAD_C, SPREAD_R, SPREAD_U, BLAST_C, BLAST_R, BLAST_U, DUMMY_C, DUMMY_R, DUMMY_U]


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


## How many of this exact glyph id the list holds.
## **Kept as-is, not the `max_per_circle` consumer any more.** `count_family` below replaced it at both
##  consumer sites (`spell_sim._valid_glyphs` · `spell_circle._list_ok`) — counting by exact id let
##  common-spread + rare-spread into one circle together (two different ids, one family), which is exactly
##  the 8 -> 64 explosion the GDD's constraint exists to block. This function still answers a real, narrower
##  question ("how many of this precise rarity") and nothing else in the pipeline needs it renamed.
static func count_of(g: int, id: int) -> int:
	var n := 0
	var cur := g
	while cur != GLYPH_NONE:
		if first(cur) == id:
			n += 1
		cur = rest(cur)
	return n


## How many glyphs **of this family** (any rarity) the list holds — the actual `max_per_circle` consumer.
## **This is the whole reason rarity could not be a second axis carried beside the id without paying twice**
##  (`glyph_defs.gd`'s header): had rarity lived in a parallel array, this function would need two arguments
##  and a second array to walk in lockstep with `g`. Folding rarity into the id keeps this a one-argument
##  walk over the same single integer every other function here already walks.
##
## **Skips ids not in `DEFS` instead of dereferencing them — a real Stage-A regression, fixed.**
## `_valid_glyphs` (`spell_sim.gd`) only validates ids **before** the one it is currently checking; the cap
## check for an early, valid id calls this function over the **whole** list, including ids further along
## that have not been validated yet. Firing packed `[SPREAD_C, 15]` (a real id followed by an id outside
## `DEFS`) reached `family_of(15)` with no guard and crashed the command boundary it exists to protect
## ("validate it here or there is nowhere to" — `fire()`'s own header) instead of barking and dropping the
## shot. `spell_circle._count_family` already guarded this way; the two had quietly diverged on invalid
## input. An id this function skips is still caught — `_valid_glyphs`'s own loop reaches it next and barks
## on `not Glyph.DEFS.has(id)` before firing.
static func count_family(g: int, family: int) -> int:
	var n := 0
	var cur := g
	while cur != GLYPH_NONE:
		var id := first(cur)
		if DEFS.has(id) and family_of(id) == family:
			n += 1
		cur = rest(cur)
	return n


static func family_of(id: int) -> int:
	return int(DEFS[id]["family"])


static func rarity_of(id: int) -> int:
	return int(DEFS[id]["rarity"])


static func power_pct_of(id: int) -> int:
	return int(DEFS[id]["power_pct"])
