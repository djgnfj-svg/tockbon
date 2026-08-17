class_name Rules
## Every constant that changes what happens, in exactly one file.
## Anything that only changes what it looks like belongs in look.gd instead: the last game scattered
## presentation constants over six files, a power was doubled, and nothing moved on screen because
## only one of the six numbers had been edited.
##
## Distances are in TILES, centre to centre, never pixels. A radius of 8 was cited as "8px" in the
## last game and reached the screen at 38px, and the same confusion bit four separate times.


# --- Unit type ids -------------------------------------------------------------------------------
# These are indices into UNITS. Reordering the table renumbers every spawn character and every
# hotkey binding at once, with nothing to bark about it.
const CELL_MELEE := 0
const CELL_RANGED := 1
const BISON := 2
const CROW := 3
const LION := 4
const TYPE_COUNT := 5


# --- Reach ---------------------------------------------------------------------------------------
## A unit may attack when `distance <= range_of(...) + REACH_BONUS`.
## 1.0 was the first draft and it excluded diagonals, since a diagonal neighbour is 1.41421 away.
## Three things died silently at 1.0: at most four melee could reach one target, the lion's area
## attack caught almost nothing (orthogonal neighbours are 1.414 apart from each other), and the
## orthogonal case landed exactly on the float boundary. See the first slice plan, "range + 1.0
## excluded diagonals".
const REACH_BONUS := 1.5

## Compare reach with this epsilon. A diagonal is exactly sqrt(2); a bare `<=` on that boundary is
## a coin flip that changes which units can fight from frame to frame.
const EPS := 1e-4

## detect_of() returns this for a soldier. Soldiers have no detect radius at all — they always
## advance on the nearest enemy — so a caller that treats a missing radius as 0.0 freezes them.
const NO_DETECT := -1.0


# --- The unit table ------------------------------------------------------------------------------
## Columns: name, max_hp, damage, attack_period(s), range(tiles), area(tiles), speed(tiles/s),
## detect(tiles).
##
## `const X := PackedInt32Array([...])` is a PARSE ERROR in GDScript 4.7 — "Assigned value for
## constant isn't a constant expression" — so every table in this repo is a plain const Array.
## A const Array is read-only in 4.x, so immutability survives; element TYPING does not, which is
## why every accessor below casts instead of returning the element straight.
##
## Body radius is deliberately absent: it changes nothing about what happens, so it lives in
## look.gd. It was in this table in the first draft and that broke the one-file rule.
##
## The lion's row is a starting point, not a measured value. Its range stays 0 on purpose: raising
## it to 5 is the one change that gives the boss a losable band, and that is an open design decision
## for the user, not a tuning knob. Until it is decided the probe's fourth policy fails on purpose
## rather than being quietly retired — see the first slice plan, "the boss still has no band".
const UNITS := [
	["CELL_MELEE", 14.0, 2.0, 1.0, 0.0, 0.0, 4.0, NO_DETECT],
	["CELL_RANGED", 8.0, 1.5, 1.0, 4.0, 1.0, 4.0, NO_DETECT],
	["BISON", 20.0, 3.0, 2.0, 0.0, 0.0, 2.5, 6.0],
	["CROW", 6.0, 1.5, 1.0, 3.0, 0.0, 6.0, 12.0],
	["LION", 140.0, 4.0, 1.5, 0.0, 1.5, 2.5, 2.0],
]

const _COL_NAME := 0
const _COL_HP := 1
const _COL_DAMAGE := 2
const _COL_PERIOD := 3
const _COL_RANGE := 4
const _COL_AREA := 5
const _COL_SPEED := 6
const _COL_DETECT := 7


static func name_of(type_id: int) -> String:
	return str(UNITS[type_id][_COL_NAME])


static func hp_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_HP])


static func damage_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_DAMAGE])


static func period_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_PERIOD])


static func range_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_RANGE])


static func area_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_AREA])


static func speed_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_SPEED])


static func detect_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_DETECT])


# --- The telegraph -------------------------------------------------------------------------------
## How long the lion holds a declared blow before it lands. The blow is announced first and lands
## when this runs out, so there is something to draw BEFORE the damage. A ring drawn on the frame the
## damage already landed is not a telegraph, it is a receipt — `combat-juice`, item 5 of section
## "The twelve specs", works that out and section 0 records the user choosing to build the real one.
##
## **It costs the boss damage, and that was chosen knowingly.** The lion's blow-to-blow period
## becomes `period_of(LION) + this` = 2.1 s, so its damage per second falls from 2.67 to 1.90 — a 29%
## cut. The probe's boss sweep found no losable band at all (an army entering island 3 at 5% of its
## pool still wins), so there is no measured band for this to eat into.
##
## Only the lion reads this, and the reason is not the name: the ranged cell also has an area, but it
## is the PLAYER's blow, and the argument for telegraphing at all is about reading enemy intent.
##
## 0.6 is a first value to be re-measured. At 60 fps it is 36 frames; this repo has measured a beat
## under five frames going entirely unseen, and this one has to be READ rather than felt, because
## nothing the player can press dodges it.
const LION_WINDUP_SEC := 0.6


# --- The run -------------------------------------------------------------------------------------
## Starting force: 10 soldiers. A run starts from this identical state every time — no meta, no
## unlocks, no carry between runs.
const START_MELEE := 6
const START_RANGED := 4

## Island 1's reward: three more soldiers at FULL HP. It has nothing to click, so it is applied on
## the win and the run goes straight to the next island; only the beak opens a reward screen.
const REWARD_MELEE := 2
const REWARD_RANGED := 1

## The beak (island 2's reward): range += 1.0 on one surviving soldier. Deliberately NOT +1 HP —
## that candidate is unadopted, and the slice exists to learn whether "who do I bolt it onto" is a
## real decision. Range 1 means a second rank can attack, so it doubles the effective contact width
## at a doorway: it is the boss's answer and the terrain's undoing in the same line.
const BEAK_RANGE := 1.0


# --- The boats -----------------------------------------------------------------------------------
## `boat-and-landing` replaces the two-boat, fixed-crossing fleet with per-boat capacity and speed,
## since the coastline is open now and a crossing's length is a property of the (harbour, landing)
## pair, not a constant. Columns: name, capacity, speed (tiles/s).
##
## The inequality is an acceptance condition, not a comment: round-trip throughput is
## `cap * speed / (2 * distance)`, so the fast boat must LOSE on throughput and win on latency or it
## dominates every send. `cap_fast * speed_fast < cap_big * speed_big` -> `2 * 5.0 = 10 < 4 * 3.0 = 12`.
## Exactly 2x would be a tie ("빠른 배가 두 배 빠르다" could not be used) — the margin here is 20%.
## Distance cancels out of that comparison, so plural harbours do not touch it.
const BOATS := [
	["BIG", 4, 3.0],
	["FAST", 2, 5.0],
]

const _BOAT_COL_NAME := 0
const _BOAT_COL_CAP := 1
const _BOAT_COL_SPEED := 2


static func boat_count() -> int:
	return BOATS.size()


static func boat_name_of(boat: int) -> String:
	return str(BOATS[boat][_BOAT_COL_NAME])


static func cap_of(boat: int) -> int:
	return int(BOATS[boat][_BOAT_COL_CAP])


static func boat_speed_of(boat: int) -> float:
	return float(BOATS[boat][_BOAT_COL_SPEED])


# --- The coastline ---------------------------------------------------------------------------------
## `grid.gd`'s straight-line sampler, in tiles. This is a rule constant and not a `Grid` constant
## and not a `look.gd` one: a coarser step ACCEPTS targets a finer one refuses (measured — widening
## it to 1.0 tile lets a boat sail through a wall the 0.05 step catches), so it changes what happens
## rather than how it is drawn. `net_coast` pins both directions.
const LINE_SAMPLE_STEP := 0.05

## Samples within this Chebyshev distance of the LANDING end are exempt from the water test, or a
## shallow approach rounds onto the beach tile next door to its target and refuses a legitimate
## landing — measured on a draft of island 1, where it refused 20 of 36 beaches for grazing the sand
## beside them. Also a rule constant for the same reason as the step above: 0 vs 1 changes which
## tiles a boat may be sent to.
const LINE_SAMPLE_EXEMPT_CHEBYSHEV := 1
