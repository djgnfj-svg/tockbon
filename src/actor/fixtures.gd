extends RefCounted
## **Stand in front of a fixture, press a key, something happens.** The town's only new machine
## (`docs/design/town.md`, "interaction genuinely doesn't exist").
##
## **Why this is new at all**: every window this repo has opens from anywhere (Tab, P). **Nothing in this
##  codebase has ever asked "where is the player standing".** That question is the whole of this file, and it
##  is deliberately small — a table of seats and one lookup.
##
## **`src/actor/`, not `src/stage/`.** The shell would have been the obvious home (the town is shell work and
##  the map is), but then "which fixture am I at" could only be measured by standing a scene up. Here it is a
##  pure function over a table: a net feeds in seats and an x and reads back an index.
##  **What stays in the shell is the seat table itself** (`town_map.FIXTURE_TILES`) — that is level content, and it
##  moves whenever the room is redrawn.
##
## **x only. There is no y.** The town is one flat room (`town.md`, "one walkable room"), so every fixture
##  stands on the same floor and a vertical test would always be true. **The day the town gets a second
##  storey, this is the line that has to change** — and it will be visible as "the upstairs bench opens from
##  downstairs", not as a crash.

## Fixture kinds. **These are the design doc's three, and there is no fourth** — a compendium was deliberately
##  not split out from the research bench (`town.md`, "there is no separate compendium").
const KIND_RESEARCH := 0
const KIND_ASSEMBLY := 1
const KIND_GATE := 2

## Kind -> the name shown on screen. **Korean, because the player reads it** (CLAUDE.md's language rule —
##  in-game text is Korean).
const NAMES: Dictionary = {
	KIND_RESEARCH: &"연구대",
	KIND_ASSEMBLY: &"조립대",
	KIND_GATE: &"출발문",
}

## How wide a fixture's standing spot is, measured from its centre (px).
##
## **40 -> 48, found by walking to the gate and watching the prompt not appear.** The fixture drawn there was
##  48px wide, so its own edge is 24px out — and at a reach of 40 there was a band **standing on the fixture's
##  far edge with no prompt**, measured at 41px away. A player reads that as the key being broken, not as
##  being one pixel short.
##  ⇒ **The reach must cover the widest fixture and then some.** `net_town` measures exactly that relation
##  against every row of `fx_tuning.TOWN_FIXTURES`, so a wider bench cannot reopen the band.
## **It is deliberately not derived from the drawn size.** That follows the art and changes whenever a sprite
##  is swapped; this is a feel value. Tying one to the other would silently resize the standing spot every
##  time the pictures change.
## **It is not per fixture.** Three seats in one room have no reason to differ, and a per-fixture column
##  would be a knob nobody ever turns (the `fx_tuning` "false knob" note).
const REACH_PX := 48


## **Which fixture the player is standing at, or -1.** `seats` is a `kind -> centre x (px)` dictionary; the
##  argument is the player's own centre, not their left edge — a fixture would otherwise sit half a body
##  off-centre from where it looks like it is.
##
## **The nearest one wins when two overlap.** Seats placed closer together than `REACH_PX * 2` are level
##  design's mistake to make, and "the wrong bench opened" is a worse answer than "the near one opened".
## **Ties go to the lower kind id** — arbitrary, but *decided*, so the same standing spot always opens the
##  same thing. Left to dictionary order it would depend on insertion order, which is invisible on screen and
##  changes when the table is edited.
static func at(seats: Dictionary, center_x: float) -> int:
	var best := -1
	var best_d := 0.0
	# Sorted, so the walk order does not depend on how the table was written (the tie rule above).
	var kinds: Array = seats.keys()
	kinds.sort()
	for kind: int in kinds:
		var d := absf(float(seats[kind]) - center_x)
		if d > REACH_PX:
			continue
		if best < 0 or d < best_d:
			best = kind
			best_d = d
	return best


## The name for the prompt, or an empty string for -1. **A separate function from `at()`** so the shell never
##  has to hold a copy of the table to turn an index into words.
static func name_of(kind: int) -> StringName:
	return NAMES.get(kind, &"")
