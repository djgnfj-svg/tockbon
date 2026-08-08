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

## **One circle = one row here + one row in `ALL`.**
##
##   layers      how many layers hold glyphs. **Layer 1 is innermost and runs first**
##   rune_slots  how many runes fit
##
## **Two fields only, on purpose.** The design doc says a circle holds four, but the other two have
##  **zero consumers** right now and would be false handles (CLAUDE.md):
##   · `combine` (fusion · parallel · sequential) — with one rune slot there is nothing to combine
##   · `glyphs_per_rune`                          — with one rune, "total glyph slots" equals "layers per bolt"
##  They arrive with the first circle that has multiple rune slots.
##
## **Only the two fields with consumers were kept** — the assembly window derives layer rings and rune slots from here.
const DEFS: Dictionary = {
	# The starting circle. 2 layers · 1 rune slot (GDD).
	CIRCLE_ROUND: {"name": &"동그라미", "layers": 2, "rune_slots": 1},
}

## Iteration goes **only through this explicit list**. `CIRCLE_NONE` is not a circle but **an empty value**,
##  so it isn't here — the palette walks this list, and "none" appearing as an entry would be a false handle.
const ALL: Array[int] = [CIRCLE_ROUND]


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
