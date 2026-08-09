extends RefCounted
## Circle table — **the magic circle's frame.** One circle = one row here.
##
## What a circle sets is **the departing arrangement** — how many layers, how many rune slots.
## **The circle does not set how things fly.** The rune took that (`docs/design/circle-rune-glyph.md`).
##
## **Why `src/sim/`**: a circle is a game rule and pure integers. The glyph table (`glyph_defs.gd`) is
##  already here. Put it in `src/view/` and `src/sim/` can't read it (`net_layers`) — and the table would
##  have to move the day `fire()` validates "does this list fit that circle".
##
## Assembly **state** lives in `src/actor/spell_circle.gd`, not here. This is only the table.

## **A reserved value. "No circle" is 0.** That is why circle ids start at 1.
##  **Same discipline** as `glyph_defs.GLYPH_NONE = 0` — keep one rule in the repo.
##  **Runes can't use this discipline** — `ELEM_FIRE` is already 0 (`spell_circle.RUNE_EMPTY`).
const CIRCLE_NONE := 0

## ids are int and **iteration goes only through the explicit `ALL` list** — never assume contiguity.
const CIRCLE_ROUND := 1
const CIRCLE_TRIANGLE := 2

## **The rune-slot layout is the circle's picture** (`docs/design/circle-rune-glyph.md`). One value here
##  expands, in `circle_layout`'s table, into where the runes sit and how the layers are arranged around them —
##  fusion's two interlocked seats and a parallel three-seat circle can share a rune count and still need
##  different pictures, which is why the picture is its own column and not derived from `rune_slots`.
const PIC_ROUND := 0
const PIC_TRIANGLE := 1

## **One circle = one row here + one row in `ALL`.**
##
##   layers      how many layers hold glyphs. **Layer 1 is innermost and runs first**
##   rune_slots  how many runes fit
##   picture     which arrangement `circle_layout` draws the rune seats and layers into (`PIC_*` above)
##   seq_ticks   ticks between one bolt leaving and the next. **0 means "all on the same tick"** — the round
##     circle's one shot falls straight through this and never has to know the field exists
##
## **`combine` is not added.** The design doc's fourth field (fusion · parallel · sequential) has **zero
##  consumers** right now — fusion has no circle yet, and with one rune slot there is nothing to combine.
##  Adding it now would be a false handle (CLAUDE.md). `seq_ticks` is what "sequential vs parallel" actually
##  reduces to, and it already has a consumer the day a multi-rune circle needs it.
##  `glyphs_per_rune` is left out the same way — with one rune, "total glyph slots" already equals "layers per bolt".
##
## **Only fields with consumers were kept** — the assembly window derives layer rings and rune slots from here.
const DEFS: Dictionary = {
	# The starting circle. 2 layers · 1 rune slot · one shot, so sequencing never applies (GDD).
	CIRCLE_ROUND: {"name": &"동그라미", "layers": 2, "rune_slots": 1, "picture": PIC_ROUND, "seq_ticks": 0},
	# **The triangle** (`docs/design/circle-rune-glyph.md`, `triangle-circle-to-game.md` step 4).
	#  3 layers · 3 rune slots — one layer band sits at each socket, so the layer and rune counts match here
	#  on purpose (unlike the round circle, where they are deliberately different so no one constant can fill
	#  both — this pairing is what `_swapping_the_circle_resizes`'s own comment already measures per circle).
	#  `seq_ticks 6`: the default from the doc's "To decide" table — reversible, one integer, until the user judges it on screen (step 4's own acceptance).
	CIRCLE_TRIANGLE: {"name": &"삼각", "layers": 3, "rune_slots": 3, "picture": PIC_TRIANGLE, "seq_ticks": 6},
}

## Iteration goes **only through this explicit list**. `CIRCLE_NONE` is not a circle but **an empty value**,
##  so it isn't here — the palette walks this list, and "none" appearing as an entry would be a false handle.
const ALL: Array[int] = [CIRCLE_ROUND, CIRCLE_TRIANGLE]


## "No circle" is **a normal state** — no barking, returns 0 (0 layers = no glyphs can be placed).
## An **unknown circle does bark** — adding a circle without adding it to the table gets caught for free
##  by the wrapper's stderr check (same device as `spell_sim._run_glyph`).
static func layers(circle_id: int) -> int:
	if circle_id == CIRCLE_NONE:
		return 0
	if not DEFS.has(circle_id):
		push_error("Circle: unknown circle %d - treating layers as 0" % circle_id)
		return 0
	return int(DEFS[circle_id]["layers"])


static func rune_slots(circle_id: int) -> int:
	if circle_id == CIRCLE_NONE:
		return 0
	if not DEFS.has(circle_id):
		push_error("Circle: unknown circle %d - treating rune slots as 0" % circle_id)
		return 0
	return int(DEFS[circle_id]["rune_slots"])


## Which arrangement (`PIC_*`) the circle's runes and layers are drawn into. Only `circle_layout` calls this —
##  the model (`spell_circle`) does not care how its seats are arranged on screen.
## **Same discipline as `layers`/`rune_slots` above.** In practice `circle_layout` never asks this for
##  `CIRCLE_NONE` — its `rune_slots(id, area)`/`layer_bands(id, area)` return empty before reaching a picture
##  branch (the existing `n <= 0` guard) — but the quiet fallback is here anyway so this accessor does not
##  become the one that barks on the ordinary act of removing the circle.
static func picture(circle_id: int) -> int:
	if circle_id == CIRCLE_NONE:
		return PIC_ROUND
	if not DEFS.has(circle_id):
		push_error("Circle: unknown circle %d - treating picture as PIC_ROUND" % circle_id)
		return PIC_ROUND
	return int(DEFS[circle_id]["picture"])


## Ticks between one bolt leaving and the next, for a circle whose runes fire in sequence. Only `spell_circle`
##  calls this — `circle_layout` draws the rune seats and layers, not the firing order between them.
static func seq_ticks(circle_id: int) -> int:
	if circle_id == CIRCLE_NONE:
		return 0
	if not DEFS.has(circle_id):
		push_error("Circle: unknown circle %d - treating seq_ticks as 0" % circle_id)
		return 0
	return int(DEFS[circle_id]["seq_ticks"])
