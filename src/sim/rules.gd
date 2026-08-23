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
## Starting force: 10 soldiers (`roster_start_count()`, below `SUMMON_SLOTS`). A run starts from this
## identical state every time — no meta, no unlocks, no carry between runs.
##
## ⚠ **`START_MELEE` / `START_RANGED` / `REWARD_MELEE` / `REWARD_RANGED` are DELETED, not renamed.**
## They were per-TYPE and the roster is per-SLOT — see `SUMMON_SLOTS`' own header below, which is where
## the two counts moved. What a `Reward.COUNT` node pays is `roster_reward_count()`: more soldiers at
## FULL HP, applied on the win with nothing to click, so the run goes straight back to the map; only the
## beak opens a reward screen.
##
## ⚠ It is a NODE's reward and no longer an island's. A route may step on up to
## `map_max_count_nodes_on_a_route()` of them, which is why nothing downstream may assume one per run —
## the roster capacity and `net_islands`' landing-region floor both ride on that accessor. See
## `title-and-map`, the reward-belongs-to-the-node refutation box.

# --- The summon slots ------------------------------------------------------------------------------
## What the number keys hold, and how far out to sea a summon may be pressed. See `sea-summon`.
##
## ⚠⚠ **THIS TABLE IS THE ROW.** It held five entries — two bound and three `SUMMON_UNBOUND` — and the
## user cut it after playing: ***"슬럿 2개로 시작 확장가능"***. **The row is two boxes because the table
## has two rows, not because anything counts to two.** `summon_slot_count()` is `SUMMON_SLOTS.size()`
## and `hud_view` loops over it; **a third binding is one line here and no other edit anywhere.**
## ⇒ **Nothing may write 2 as a literal.** A check that pins the count against a number is what turns
## the next binding into a rewrite, and this repo has measured that shape — both sides of an assertion
## moving together and passing at any value. Pin the count against the TABLE; pin the table's own size
## as the literal.
##
## ⚠ **`SUMMON_UNBOUND` survives with no entry using it**, and that is deliberate: `summon_type_of`
## returns it for an out-of-range slot, which is the answer `slot_reserve_ids` and `Battle.summon` both
## refuse on. Delete it and an out-of-range slot answers `CELL_MELEE` — 0 — with every bounds check
## downstream still passing while the wrong body is summoned.
##
## ⚠⚠ **`CELL_MELEE` IS 0, so the "nothing is bound here" test is `< 0` and NEVER `<= 0`.** A `<= 0`
## refuses slot 1 forever, and every count check downstream still passes — a slot that refuses looks
## exactly like an empty roster.
##
## ⚠ **The unbound slots were deliberately NOT `BISON` / `CROW` / `LION`** and deleting them does not
## change that: `TYPE_LABELS` has five entries and nothing range-checks it, so binding a slot to an
## enemy type reads as done and ships enemy bodies as the player's army. **Re-binding a slot at runtime
## IS the 짐승 economy**, blocked twice in `session-loop`, and it is not this table's business.
##
## ⚠⚠ **AND WHAT THE USER DECIDED THAT ECONOMY WILL BE IS RECORDED HERE, because it lands on this
## table**: ***"슬롯에 세포를 넣음 대신 슬롯자체를 강화하는거임"*** — a cell goes into a slot and **what
## you upgrade is the SLOT, not the cell.** Deferred to a refit screen that does not exist, so
## **nothing in code changes**: slots stay bound to types. `sea-summon`'s design doc records why
## `session-loop`'s object-cost arithmetic cannot be reused for it.
const SUMMON_UNBOUND := -1

## Columns: unit type, how many bodies a run STARTS with in this slot, how many a COUNT node adds to it.
## ⚠⚠ **The starting counts moved here from `START_MELEE` / `START_RANGED` because they were per-TYPE
## and the roster is per-SLOT.** A third row used to arrive with no bodies at all and every count check
## downstream stayed green; the header above already claimed a third binding costs one line, and for the
## roster it did not until this moved.
const SUMMON_SLOTS := [
	[CELL_MELEE, 6, 2],
	[CELL_RANGED, 4, 1],
]

const _SLOT_COL_TYPE := 0
const _SLOT_COL_START := 1
const _SLOT_COL_REWARD := 2

## ⚠⚠ **THE BAND IS A MINIMUM DISTANCE FROM LAND, AND IT USED TO BE A MAXIMUM.** It was
## `SUMMON_BAND_TILES := 2` — *within 2 hops of the coast* — and the user inverted it after playing:
## ***"해안선에 배를 배치하는게 아니라 좀 거리를 둬야함 지형하고 많이 줘도됨 배가 가는게 중요하니까"***.
## **The reason is a design reason and not a preference: the crossing is the thing worth watching, and a
## band hugging the shore deletes it.** The name changed with the meaning — a constant whose sense
## inverts under the same name is one nobody re-reads.
##
## **It is a rule and not a look value: it decides what `Grid.can_summon_at` REFUSES**, and the band the
## view paints is that same predicate asked per tile — so the picture and the refusal are one fact.
## **There is no maximum.** Every water tile the summon BFS reached and that is far enough is in the
## band; 「많이 줘도됨」 is the whole of that.
##
## ⚠⚠ **4 WAS CHOSEN FROM A SWEEP, NOT FROM TASTE.** Measured on all three shipped islands — band tiles ·
## distinct reachable landings · crossing min/median/max seconds at `BOAT_SPEED` 4.0:
##
##   shipped `<= 2`   190/174/186 · 82/75/80 · **0.25 / 0.60 / 0.71**  (spread 0.46 s)
##   `>= 3`           534/516/540 · 45/40/43 · **0.85 / 2.47 / 5.96**  (spread 5.11 s)
##   `>= 4`           470/460/478 · 42/38/40 · **1.10 / 2.47 / 5.96**  (spread 4.86 s)
##   `>= 6`  <- this  360/360/366 · 34/35/34 · **1.60 / 2.83 / 5.96**  (spread 4.36 s)
##   `>= 8`           256/256/256 · 32/33/27 · **2.10 / 3.18 / 5.96**  (spread 3.86 s)
##   `>= 10`          152/152/152 · 30/31/25 · **2.60 / 3.54 / 5.96**  (spread 3.36 s)
##   `>= 12`          **48/48/48 · 2/2/2** — see the cliff below
##
## ⚠ **The MAXIMUM crossing is 5.96 s at every value, because the water is finite** — so raising this
## number lifts the floor and SHRINKS the spread. The spread peaks at 3 and decays from there. **This
## number does not buy a longer crossing; it buys a longer SHORTEST one.**
##
## ⚠⚠ **THERE IS A CLIFF BETWEEN 10 AND 12, AND IT IS THE CEILING.** At 12 the band is 48 tiles and
## resolves to **2 distinct landings on all three islands** (and on the 144-column map) — the four
## corners of the sea, and nothing else. Every press on the island would produce one of two beaches.
## **10 is the last usable value**; 8 is the last comfortable one.
##
## 4 was adopted first and **6 came from the user after playing it**: *"그냥 섬 이랑 더 거리를 더줘"*.
## The price is stated rather than argued down: **6–8 more coast tiles stop being individually
## addressable** (42/38/40 -> 34/35/34 of 84/76/82), the minimum crossing rises 1.10 -> 1.60 s, and the
## spread NARROWS 4.86 -> 4.36 s.
## ⚠ **It still restores the term `sea-summon` §5.2 measured and §5.3 flattened**: the drag's crossing
## spread was 4.50–4.75 s, and 4.36 s is within that band.
##
## Floor 3 — under it the minimum crossing drops below 0.85 s and the band starts touching the shore
## again, which is what the user asked to end. **Ceiling 10, from the cliff above** — not from taste.
const SUMMON_BAND_MIN_TILES := 6

## ⚠⚠ **The OUTER edge of the band, and it is new** (2026-08-24, the user: 「내가 바다면 그 일정
## 동그랗게 섬 기준으로 동그랗게 해서」). Until now the band had a floor and no ceiling: every reachable
## water tile at least `SUMMON_BAND_MIN_TILES` from the shore was summonable, **including the whole open
## ocean out to the edge of the map**. That is why it drew as huge slabs of sea rather than as a place.
##
## ⚠⚠ **A RATIO OF THE MAP AND NOT A FIXED DISTANCE, and that was measured the hard way.** It was a
## flat 22 tiles for one round. On the shipped 48 x 32 islands that was right — the band went 360 tiles
## to 280 and the landings it can reach 34 to 30. **On the long map it was a disaster**: 144 wide, and a
## 22-tile circle about the middle left 280 band tiles of 1128 and **43 reachable landings of 138**, so
## two thirds of that island could not be attacked at all. A circle 「섬 기준으로」 has to be a circle
## about THAT island, so it is sized by the island.
##
## **0.46 of the longer side.** On 48 x 32 that is 22.1 — the value that was measured good by eye — and
## on the 144-wide map it is 66.2, which reaches its ends again.
## Floor 0.30 — under it the ring closes inside `SUMMON_BAND_MIN_TILES` on a square map and the band
## pinches shut. Ceiling 0.75 — past it the ring leaves the water entirely on the shipped maps and the
## rule is the old no-ceiling one wearing a number.
##
## ⚠ **Measured from the middle of the GRID, not from the land.** An island is not a disc and its centre
## of mass wanders per map; the grid's middle is the same point every check and every player can point
## at, and the ring drawn on screen is a circle about exactly it.
const SUMMON_RADIUS_RATIO := 0.46


## The radius that ratio comes to on a given grid, in tiles. **One function, so the predicate and the
## ring cannot compute it two ways.**
static func summon_radius_of(w: int, h: int) -> float:
	return float(maxi(w, h)) * SUMMON_RADIUS_RATIO


static func summon_slot_count() -> int:
	return SUMMON_SLOTS.size()


## The unit type in slot `slot`, or `SUMMON_UNBOUND` for an empty or out-of-range slot. The cast is
## the same one every read of a `const` Array in this file makes.
static func summon_type_of(slot: int) -> int:
	if slot < 0 or slot >= SUMMON_SLOTS.size():
		return SUMMON_UNBOUND
	return int(SUMMON_SLOTS[slot][_SLOT_COL_TYPE])


## How many bodies a run STARTS with in this slot. 0 for an out-of-range slot.
static func slot_start_count(slot: int) -> int:
	if slot < 0 or slot >= SUMMON_SLOTS.size():
		return 0
	return int(SUMMON_SLOTS[slot][_SLOT_COL_START])


## How many bodies a `Reward.COUNT` node adds to this slot. 0 for an out-of-range slot.
static func slot_reward_count(slot: int) -> int:
	if slot < 0 or slot >= SUMMON_SLOTS.size():
		return 0
	return int(SUMMON_SLOTS[slot][_SLOT_COL_REWARD])


## The sum of every slot's starting count. Replaces `START_MELEE + START_RANGED` at every reader —
## walked over the table, never written as a literal, so a third slot moves this for free.
static func roster_start_count() -> int:
	var sum := 0
	for s in summon_slot_count():
		sum += slot_start_count(s)
	return sum


## The sum of every slot's `Reward.COUNT` payout. Replaces `REWARD_MELEE + REWARD_RANGED`.
static func roster_reward_count() -> int:
	var sum := 0
	for s in summon_slot_count():
		sum += slot_reward_count(s)
	return sum


## --- Parts (parts-on-a-board-not-on-the-body) -------------------------------------------------------
## The six parts a board has a cell for. ⚠ A cell is bound to one part — head goes in the head cell and
## nowhere else — so this enum IS the cell index and there is no second numbering to keep in step.
enum Part { HEAD, CHEST, BELLY, ARM, HAND, LEG }

## What a part belongs to. ⚠ It does NOTHING this round and that is decided, not forgotten: the user
## took set effects out and left the species in as the place they will attach. Nothing below reads it.
enum Species { MAMMAL, BIRD, FISH }

## The five columns a part may move — declared in UNITS' own order so the two tables read alike.
const PART_COL_HP := 0
const PART_COL_DAMAGE := 1
const PART_COL_PERIOD := 2
const PART_COL_RANGE := 3
const PART_COL_SPEED := 4
const PART_COL_TOTAL := 5

## One row per part, five columns, ADDED to the type's own number. Nothing multiplies: two rules for one
## column is the second copy that diverges.
## ⚠ These are first values, not measured ones. `parts-on-a-board-not-on-the-body` records that what a
## part moves and by how much is balance work that needs the screen to exist first.
## ⚠ There is deliberately NO clamp on the result anywhere in the code. One part per cell means a period
## can fall by at most one row's worth, so a floor would be a branch no input can reach — dead code
## wearing a safety belt. The bound lives in `net_parts` as a literal instead, so a table edit that
## drove a period to zero reddens where a dead clamp would have hidden it.
const PART_STATS := [
	[0.0, 0.0,  0.00, 1.0, 0.0],   # HEAD  머리 — 사거리
	[4.0, 0.0,  0.00, 0.0, 0.0],   # CHEST 가슴 — 체력
	[3.0, 0.0,  0.00, 0.0, 0.0],   # BELLY 배   — 체력
	[0.0, 1.0,  0.00, 0.0, 0.0],   # ARM   팔   — 공격력
	[0.0, 0.0, -0.15, 0.0, 0.0],   # HAND  손   — 공격주기 (내려간다)
	[0.0, 0.0,  0.00, 0.0, 0.8],   # LEG   다리 — 이동속도
]

const CARDS_PER_WIN := 6
const CARD_PICKS := 2


static func part_count() -> int:
	return PART_STATS.size()


static func species_count() -> int:
	return Species.size()


static func part_bonus(part: int, col: int) -> float:
	return float(PART_STATS[part][col])


## Maps a `PART_COL_*` onto the matching base-stat column, so the five columns are not named twice.
## ⚠ This is what stops the five columns being named twice — every base number in the game is still
## read through the existing `hp_of` · `damage_of` · `period_of` · `range_of` · `speed_of`, and this is
## a `match` over those five and nothing else.
static func unit_stat(type_id: int, col: int) -> float:
	match col:
		PART_COL_HP:
			return hp_of(type_id)
		PART_COL_DAMAGE:
			return damage_of(type_id)
		PART_COL_PERIOD:
			return period_of(type_id)
		PART_COL_RANGE:
			return range_of(type_id)
		PART_COL_SPEED:
			return speed_of(type_id)
	return 0.0


## The beak (a `Reward.BEAK` node's pay): range += 1.0 on one surviving soldier. Deliberately NOT +1 HP —
## that candidate is unadopted, and the slice exists to learn whether "who do I bolt it onto" is a
## real decision. Range 1 means a second rank can attack, so it doubles the effective contact width
## at a doorway: it is the boss's answer and the terrain's undoing in the same line.
const BEAK_RANGE := 1.0


# --- The boat ------------------------------------------------------------------------------------
## How fast a boat crosses, tiles per second. The ONE surviving number of the old `BOATS` table:
## with unlimited boats there is no capacity column (a boat carries the one soldier that was dragged
## onto it), no name column (nothing distinguishes two boats) and no count (`boats` is as long as the
## player made it). `plan-then-watch` records the reversal that deleted the rest; the rejected branch
## is `unlimited-boats-not-a-five-boat-cap`.
##
## ⚠ It is a rule constant and not a look constant because it sets the crossing time, which is the
## only thing between the commit and the first blow. **It is also the lever the deferred brake would
## be built from** — a departure interval is this number's sibling — so do not retune it as a feel
## value.
const BOAT_SPEED := 4.0

## How finely `grid._straight_is_all_water` samples a candidate segment, in TILES. It is the one knob
## on the route smoother — see `grid.water_route`.
##
## ⚠ **It must stay at or under 0.5.** Tile centres are on integers, so a tile spans ±0.5 around its
## centre; sample any coarser and two consecutive samples can round to tiles that are two apart, and
## the segment would be declared clear over a tile nobody looked at. **0.25 is that bound halved**, so
## a step moves at most 0.25 on either axis and the rounded tile can never jump. Floor: nothing under
## 0.05, which is 20 samples a tile for no more certainty than 4 already buys.
##
## ⚠ **This is NOT `LINE_SAMPLE_STEP` restored.** That constant tuned the deleted straight-line
## SENDABILITY test — the rule the user threw out (*"상륙 못하는 데가 있는 거지…"*). This one tunes a
## post-pass over a route that is already legal. Same arithmetic, opposite job; see the smoother's own
## comment before assuming the denylist came back with it.
const ROUTE_SMOOTH_SAMPLE_TILES := 0.25


# --- The clock the fight is computed at -----------------------------------------------------------
## The discretisation the whole fight runs on. `Battle.step` consumes WHOLE sub-steps of exactly this
## length and carries the leftover, so the same simulated second costs the same number of phase
## passes whatever `dt` the caller hands in.
##
## It changes WHAT HAPPENS and not how anything looks, so it lives here. Five things inside `step` are
## per-step rather than per-second — a cooldown reset to the whole period on fire, a leg transition
## that discards its overshoot, targeting and death latching that take no `dt` at all, `_walk`'s
## per-tile reservation, and the field TTL — and every one of them is measured against this number.
## `plan-then-watch` works the table out.
const SIM_SUBSTEP_SEC := 1.0 / 60.0

## ⚠⚠ **NOTHING IN `src/` READS THIS TABLE OR THE THREE NAMES UNDER IT.** The speed chips and the
## pause were deleted on the user's own sentence (「일단 배속 개념은 지워주고, 저거는 아직은 필요 없을
## 때 추후에 추가해도」 · 「일시정지 지워주고」), and `speed-off-open-landing` is the plan that did it.
##
## **The table stays anyway, and that is a decision rather than an oversight.** It is four lines, and
## it is the only thing that has to come back the day the user says 「이제 필요해」 — the ceiling
## argument, the divisor argument and the 0x-is-not-a-viewing-rate argument below are what make
## restoring this a wiring job instead of a design job again. `net_shell` asserts both halves: that
## the table still parses and holds its entries, and that no file under `src/` outside this one names
## any of them.
##
## The rates the fight may be computed at, as a ladder a shell could index into. Every step ABOVE zero
## is arithmetically inert under `SIM_SUBSTEP_SEC` and changes only whether the picture can be read.
##
## ⚠ **0x IS NOT A VIEWING RATE, which is why this table is not in look.gd.** `Battle.step` returns on
## `dt <= 0.0` before `_phase_clock`, and `_phase_clock` is the only writer of `elapsed`, which is the
## loss condition. This table therefore decides whether the island's clock advances at all.
##
## 2, 3 and 6 are exact divisors of every attack period in `UNITS` (1.0, 1.5, 2.0) and of
## `LION_WINDUP_SEC` 0.6 — belt-and-braces on top of the sub-step, so an edit that removed the
## sub-step by accident would not silently start changing outcomes. The ceiling is 7x: 0.6 s of
## telegraph is five rendered frames at k = 7.2, and this repo has measured a beat under five frames
## going entirely unseen. 4x and 5x are absent on the divisor argument, not the ceiling.
##
## `const X := PackedInt32Array([...])` is a parse error, so this is a plain const Array and every
## read casts — see the `UNITS` header.
const SPEED_STEPS := [0.0, 1.0, 2.0, 3.0, 6.0]

## The slot a shell would open every island at. ⚠ **NOT 0.** A shell that opened at slot 0 would call
## `step(0.0)` every frame and the fight would be frozen from the moment the start button was pressed,
## with nothing barking. A net pins this to the index whose value is 1.0 rather than to a bare 0.
const SPEED_SLOT_DEFAULT := 1


static func speed_slot_count() -> int:
	return SPEED_STEPS.size()


static func speed_mul_of(slot: int) -> float:
	return float(SPEED_STEPS[slot])


# --- The coastline ---------------------------------------------------------------------------------
## ⚠ **`LINE_SAMPLE_STEP` and `LINE_SAMPLE_EXEMPT_CHEBYSHEV` are DELETED.** They were the straight-line
## sampler's step and its landing-end exemption, and `grid.water_line_clear` — their only reader —
## went with the permit list `speed-off-open-landing` replaced. Unlike `SPEED_STEPS` above they have
## no restore case: the rule they tuned is not coming back, because a straight line is what refused
## 40% of every island's shore. A rule constant nobody reads rots silently, so they are gone rather
## than parked.
##
## ⚠ The exemption in particular must NOT be restored by anyone reading the 97 / 83 / 94 column of
## 2.1's table as an improvement: it was a Chebyshev 1, which is what let a boat land one tile INLAND.


# --- The map ---------------------------------------------------------------------------------------
## The shape of a run: which nodes exist, what each one pays, and which ones may follow which.
##
## It is here and not in `run.gd` because what a node PAYS changes what happens, and because `run.gd`
## already reads this file — `rules.gd` referencing `Run` would close a class cycle. `Run.State` stays
## on `Run` for the same reason in reverse: nothing here needs it.
##
## ⚠ **Nothing in this section is generated and no seed is read.** The map is authored, identical every
## run, and `title-and-map` records that as a decision rather than a stage that was skipped: a map that
## is the same every time is the one whose four routes can be walked exhaustively by a net.

## ⚠ The chest is GONE — 「일단 전부 다 monster 노드로 만들면 될듯」. Every node opens an island now, so
## the island column has no -1 in it any more and `NodeKind` has two entries.
enum NodeKind { FIGHT, BOSS }

## What a node pays on the way out. Moved here from `Run` so the table below can name it.
##
## ⚠ `HEAL` is GONE with the chest that was its only payer — see `NodeKind`'s own header. `COUNT` is
## applied on the win with nothing to choose; only `BEAK` opens a `REWARD` state (the beak pick, which
## predates the card pick and still routes through it — see `run.gd`).
enum Reward { NONE, COUNT, BEAK }

## One row is ONE NODE: floor, kind, reward, island index.
##
## ⚠ The reward is the NODE's and not the KIND's. Keyed by kind, every fight node would pay the
## identical thing and a fork could never put "cells or beak" side by side — see `title-and-map`, the
## reward-belongs-to-the-node refutation box. That is why this table has a reward column at all.
##
## ⚠ `const X := PackedInt32Array([...])` is a parse error on 4.7.1, so this is a plain const Array and
## every read below casts.
##
## ⚠ The island column is still the declared temporary from `title-and-map`: three grids serving SEVEN
## island-opening nodes now, one more than before the chest's floor joined them. The check that forbids
## two nodes sharing a grid lands WITH the three new grids, so no round is red for the gap.
const MAP_NODES := [
	[0, NodeKind.FIGHT, Reward.COUNT, 0],   # 0 — floor 1, fixed, where every run lands
	[1, NodeKind.FIGHT, Reward.COUNT, 1],   # 1 — floor 2 left
	[1, NodeKind.FIGHT, Reward.BEAK,  2],   # 2 — floor 2 right
	[2, NodeKind.FIGHT, Reward.BEAK,  1],   # 3 — floor 3 left
	[2, NodeKind.FIGHT, Reward.COUNT, 2],   # 4 — floor 3 right
	[3, NodeKind.FIGHT, Reward.COUNT, 0],   # 5 — floor 4, WAS THE CHEST, now a fight on grid 0 (closed
	                                         # open question B: `Reward.COUNT`, on a grid already in use)
	[4, NodeKind.BOSS,  Reward.NONE,  2],   # 6 — floor 5, the lion, the run ends here
]

const _MAP_COL_FLOOR := 0
const _MAP_COL_KIND := 1
const _MAP_COL_REWARD := 2
const _MAP_COL_ISLAND := 3

## Directed and upward only. A run never walks down, so an edge is a permission and nothing else — and
## because every edge climbs exactly one floor, a route's length is the floor count and a walker over
## this table always terminates.
##
## Both floor-2 nodes reach both floor-3 nodes on purpose: branches that split and rejoin are what stop
## one bad turn locking the rest of the map. Delete `[2,4]` and the map still walks, still draws, and
## quietly becomes two corridors.
const MAP_EDGES := [[0, 1], [0, 2], [1, 3], [1, 4], [2, 3], [2, 4], [3, 5], [4, 5], [5, 6]]


static func map_node_count() -> int:
	return MAP_NODES.size()


static func map_floor_of(n: int) -> int:
	return int(MAP_NODES[n][_MAP_COL_FLOOR])


static func map_kind_of(n: int) -> int:
	return int(MAP_NODES[n][_MAP_COL_KIND])


static func map_reward_of(n: int) -> int:
	return int(MAP_NODES[n][_MAP_COL_REWARD])


## The island this node opens, or **-1** for a node with no fight. -1 is not an error and not a
## sentinel to be clamped: it is what makes the chest cost no grid at all.
static func map_island_of(n: int) -> int:
	return int(MAP_NODES[n][_MAP_COL_ISLAND])


## How many floors the map has. Derived from the table rather than written beside it, because a floor
## count written twice is the second copy that rots the day a floor is added.
static func map_floor_count() -> int:
	var top := -1
	for n in range(map_node_count()):
		top = maxi(top, map_floor_of(n))
	return top + 1


static func map_edge_count() -> int:
	return MAP_EDGES.size()


static func map_edge_from(e: int) -> int:
	return int(MAP_EDGES[e][0])


static func map_edge_to(e: int) -> int:
	return int(MAP_EDGES[e][1])


## The most `Reward.COUNT` nodes a single route can step on — 3 on the map as authored.
##
## ⚠ **Walked over the table, never written as a literal 3.** `net_islands`' landing-region floor and
## the roster capacity both ride on this number, and a hand-written 3 beside a table that can grow is
## exactly the second copy this repo has watched rot twice. Change `MAP_NODES` and this moves with it.
static func map_max_count_nodes_on_a_route() -> int:
	var best := 0
	for n in range(map_node_count()):
		if map_floor_of(n) == 0:
			best = maxi(best, _map_max_count_from(n))
	return best


## Terminates because every edge climbs exactly one floor: the recursion can only run `map_floor_count()`
## deep. A node with no outgoing edge is the end of a route and contributes only itself.
static func _map_max_count_from(n: int) -> int:
	var here := 1 if map_reward_of(n) == Reward.COUNT else 0
	var best := -1
	for e in range(map_edge_count()):
		if map_edge_from(e) == n:
			best = maxi(best, _map_max_count_from(map_edge_to(e)))
	if best < 0:
		return here
	return here + best


## The most card-paying nodes a single route can step on. ⚠ **A node pays cards iff it is not the
## boss** — every fight now pays six cards on the win — so this walks the SAME shape
## `map_max_count_nodes_on_a_route()` does, never written as a literal. `Look.refit_held_capacity()`'s
## floor rides on it: a hand-written literal beside a table that can grow is the second copy this repo
## has watched rot twice.
static func map_max_card_nodes_on_a_route() -> int:
	var best := 0
	for n in range(map_node_count()):
		if map_floor_of(n) == 0:
			best = maxi(best, _map_max_card_from(n))
	return best


static func _map_max_card_from(n: int) -> int:
	var here := 0 if map_kind_of(n) == NodeKind.BOSS else 1
	var best := -1
	for e in range(map_edge_count()):
		if map_edge_from(e) == n:
			best = maxi(best, _map_max_card_from(map_edge_to(e)))
	if best < 0:
		return here
	return here + best
