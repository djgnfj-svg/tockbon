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
# hotkey binding at once — **and `net_summon._the_unit_table` is now the bark that was missing**:
# every constant here is asserted to name its own row, and the pair list's LENGTH is pinned against
# the table so a row added without a constant reddens too.
#
# ⚠⚠ **`CELL_MELEE` and `CELL_RANGED` are GONE, renamed to `WOLF` and `CROW`.** `CONTEXT.md` marked
# them as the last place the dead cell game was still spelled out and said they change 「고도가 도는
# 데서」; the five-beast roster is that place. **The numbers moved unchanged** — the wolf is the one
# row a whole run has been played on, and re-tuning it while renaming it would make a later
# difference unattributable.
## ⚠⚠ **THE SIDES SWAPPED 2026-08-26.** The player was five beasts and the enemy was three humans and
## a lion; **the player is now ONE human — a swordsman — and the beasts are what he fights.** The user
## decided both halves: 「상대를 오히려 지금까지 만들었던 몬스터들로 하면 되잖아」 and 「병사가 아직
## 종류가 많을 필요가 없어. 검사 하나 만 있으면 돼. 움직이는 거에 초점을 맞추고 싶어」.
##
## ⚠ **Four rows left the table** — 다람쥐 · 소 (never wired to anything but a shove) and 창병 · 방패병
## (the player's job now, and one swordsman is what it is). **Their art is still in `assets/`**, so a
## row coming back is a row, not a drawing.
const SWORDSMAN := 0
const WOLF := 1
const BEAR := 2
const CROW := 3
const LION := 4

## ⚠ **`TYPE_COUNT` is DELETED, not renamed.** It meant two different things at once — the table's
## height and the number of equipment boards — and those stopped being the same number the day the
## enemy rows joined the table. What used to read it now reads `player_type_count()` (the boards) or
## `UNITS.size()` (the table).

## Which army a row belongs to.
##
## ⚠⚠ **EVERY PLAYER ROW COMES BEFORE EVERY ENEMY ROW, and that is a contract rather than tidiness.**
## `Loadout`'s board is indexed `0 .. player_type_count() - 1` and the refit strip draws that same
## range, so an enemy row sitting between two player rows would put a helmet on a human with every
## count check downstream still green. `net_summon` pins the ordering, not just the count.
enum Side { PLAYER, ENEMY }


# --- Reach ---------------------------------------------------------------------------------------
## A unit may attack when `distance <= range_of(...) + REACH_BONUS`.
## 1.0 was the first draft and it excluded diagonals, since a diagonal neighbour is 1.41421 away.
## Three things died silently at 1.0: at most four melee could reach one target, the lion's area
## attack caught almost nothing (orthogonal neighbours are 1.414 apart from each other), and the
## orthogonal case landed exactly on the float boundary. See the first slice plan, "range + 1.0
## excluded diagonals".
const REACH_BONUS := 1.75
## ⚠⚠ **RAISED 1.5 -> 1.75** (2026-08-25, 티켓 19). **1.5 covered the flat 8-neighbourhood and nothing
## else, and the neighbourhood stopped being flat.** A body on a stair (level 1) reaching an enemy on
## the plateau beside it (level 2) is `sqrt(1 + 1)` = **1.414 orthogonally** — inside 1.5 — but
## `sqrt(2 + 1)` = **1.732 diagonally**, outside it. Measured in play with the attacker pinned on the
## stairs: **orthogonal, three hits and a kill; diagonal, ZERO hits and ZERO damage.** The stair is one
## tile wide, so the horde behind the body that cannot hit is stuck in the doorway and the archers
## above shoot the queue. **26 of 162 fights lost that way, and in 24 of them every surviving enemy was
## clustered on exactly those diagonal tiles.**
##
## **The window is `(sqrt(3), 2.0)`** — above the tier diagonal, below the flat two-tile orthogonal.
## 1.75 sits in it with **+0.018 above and -0.250 below**; the lower margin is thin and safe because
## both bounds are exact (integers under a root, heights are exact multiples of `TIER_STEP_TILES`) and
## `EPS` is 1e-4.
##
## ⚠⚠ **IT IS NOT A MELEE-ONLY CHANGE AND NO VALUE COULD MAKE IT ONE.** This bonus is added to EVERY
## species' range, so raising it moves every species' reach. Swept over every tile-aligned pair at
## every level difference: at 1.75 exactly **two** species gain a flat-ground distance —
## **다람쥐 3.50 -> 3.75 gains 3.606** and **까마귀 5.50 -> 5.75 gains 5.657** — and nothing else moves.
## **There is no way to avoid those two**: 다람쥐's next distance enters at a bonus of 1.606, which is
## BELOW the 1.732 melee needs, so any value that fixes the stair also gives it that tile.
## ⚠ **1.85 was the other candidate** — more comfortable margins, but it also hands 창병 the 2-tile
## diagonal (2.828) and 까마귀 a second tile. **1.75 is the smallest drift that closes the defect**, and
## the drift is written here rather than discovered later. **Nothing else moved**: 곰's sweep, 사자's
## area, 다람쥐's pull and every detection radius are their own table columns and read no bonus.

## Compare reach with this epsilon. A diagonal is exactly sqrt(2); a bare `<=` on that boundary is
## a coin flip that changes which units can fight from frame to frame.
const EPS := 1e-4

## detect_of() returns this for a soldier. Soldiers have no detect radius at all — they always
## advance on the nearest enemy — so a caller that treats a missing radius as 0.0 freezes them.
const NO_DETECT := -1.0


# --- Height: tiers and the stairs between them ------------------------------------------------------
## **A tile carries one integer, its LEVEL, and every height fact is derived from it.** 티켓 19's answer
## table decided two tiers, one tier two tiles tall, a stair one tile wide, and the stair as the only
## way up. The whole of "the stair is the only door" is `MAX_CLIMB_LEVELS` below: low ground is level 0,
## a stair is level 1, high ground is level 2, so the boundary is a gap of two and the stair is two
## gaps of one.
##
## ⚠⚠ **Integer levels, deliberately, and never a float height comparison.** `_within` was once caught
## on the 1.41421 diagonal boundary (see `REACH_BONUS`), and a climb rule written against heights would
## put a float boundary in the middle of every hillside — the hills are noise, and noise crosses any
## threshold somewhere. **Nothing decides whether a body may walk by looking at a height.**
##
## How tall one tier stands, in tiles. Everything below is derived from it and the number is not
## repeated anywhere else.
const TIER_RISE_TILES := 2.0
## How far ONE level rises — a stair tread. Half a tier, because a stair sits halfway up.
const TIER_STEP_TILES := TIER_RISE_TILES * 0.5
## The largest level difference a body may step across. **1**, so a stair is passable from both sides
## and a tier boundary is not.
const MAX_CLIMB_LEVELS := 1


# --- The unit table ------------------------------------------------------------------------------
## Columns: name, max_hp, damage, attack_period(s), range(tiles), area(tiles), speed(tiles/s),
## detect(tiles), side, 한국어 이름.
##
## ⚠⚠ **THE KOREAN NAME IS A COLUMN HERE AND NOT A SECOND TABLE IN `hud_view`.** `TYPE_LABELS` was
## that second table, and the split showed: 까마귀 stood in it TWICE, because the player's ranged row
## borrowed the crow's picture while the enemy crow was its own row. One column ends the duplicate at
## its cause. The Korean is the same exception `ITEMS`' names carry — the user reads this word.
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
## ⚠⚠ **WHICH ROWS ARE MEASURED AND WHICH ARE FIRST DRAFTS decides what a later measurement means.**
## `WOLF` carries `CELL_MELEE`'s numbers and `CROW` carries the old enemy crow's, unchanged through two
## side swaps, because the wolf is the only row a whole run has ever been played on. **`SWORDSMAN` is
## interpolated between the two humans a run was played against** (see its own comment in the table);
## **`BEAR` and `LION` are first values and nothing has measured them.**
##
## ⚠ **The lion's range stays 0 on purpose**: raising it to 5 is the one change that gives the boss a
## losable band, and that is an open design decision for the user, not a tuning knob.
const UNITS := [
	# ⚠⚠ **The swordsman's numbers sit BETWEEN the spearman's and the shieldbearer's, deliberately.**
	# Those two were the humans a whole run was played against, so their row is the only measured
	# ground this table has for a human body: 16/20 HP, 2.5/3.0 damage, 1.5/2.0 period, 3.0/2.5 speed.
	# **A sword has no reach**, so the range column is 0 where the spear had 1 — and the period and the
	# speed take the faster of the two, because a swordsman that is slower than a spearman AND has less
	# reach is a row that loses for a reason nobody chose.
	# ⚠ **`NO_DETECT` because the player's bodies are commanded, not triggered** — the detect column is
	# what makes a defender stand still until something walks near it.
	["SWORDSMAN", 18.0, 2.5, 1.2, 0.0, 0.0, 3.2, NO_DETECT, Side.PLAYER, "검사"],
	# ⚠⚠ **The beasts crossed sides and their numbers did NOT move.** The wolf is the one row a whole
	# run has been played on; re-tuning it in the same edit that flips its side would make a later
	# difference unattributable. **They gained a detect radius** — an enemy has to notice something.
	["WOLF", 14.0, 2.0, 1.0, 0.0, 0.0, 4.0, 6.0, Side.ENEMY, "늑대"],
	["BEAR", 30.0, 3.5, 1.8, 0.0, 1.5, 2.8, 6.0, Side.ENEMY, "곰"],
	["CROW", 8.0, 1.5, 1.0, 4.0, 1.0, 4.0, 12.0, Side.ENEMY, "까마귀"],
	["LION", 140.0, 4.0, 1.5, 0.0, 1.5, 2.5, 2.0, Side.ENEMY, "사자"],
]

const _COL_NAME := 0
const _COL_HP := 1
const _COL_DAMAGE := 2
const _COL_PERIOD := 3
const _COL_RANGE := 4
const _COL_AREA := 5
const _COL_SPEED := 6
const _COL_DETECT := 7
const _COL_SIDE := 8
const _COL_LABEL := 9


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


static func side_of(type_id: int) -> int:
	return int(UNITS[type_id][_COL_SIDE])


## The word a player reads for this row. `name_of` returns the table's IDENTIFIER, which is English
## and is not text anybody reads on screen.
static func label_of(type_id: int) -> String:
	if type_id < 0 or type_id >= UNITS.size():
		return ""
	return str((UNITS[type_id] as Array)[_COL_LABEL])


## How many rows are the player's. **Counted over the table and never written as a literal** — the
## boards, the refit strip and every range check on a beast type ride on this number, and a hand
## written copy beside a table that grows is the second copy this repo has watched rot twice.
##
## ⚠ It leans on the ordering `Side`'s own header states: the player rows are `0 ..` this `- 1`, so a
## caller may use it as a bound and not only as a count.
static func player_type_count() -> int:
	var n := 0
	for i in UNITS.size():
		if int((UNITS[i] as Array)[_COL_SIDE]) == Side.PLAYER:
			n += 1
	return n


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
## Starting force: 10 soldiers (`roster_start_count()`, below `START_SLOTS`). A run starts from this
## identical state every time — no meta, no unlocks, no carry between runs.
##
## ⚠⚠ **EVERY NODE REWARD IS DELETED** (2026-08-26), together with the seven-node map that paid them:
## `Reward`, `NodeKind`, `MAP_NODES`, `MAP_EDGES`, `SLOT_PAY`, `slot_pay_of` and `roster_reward_count`
## are all gone. **A run grows on cards and nothing else now.**
## ⚠ **`START_MELEE` / `START_RANGED` / `REWARD_MELEE` / `REWARD_RANGED` went earlier and for a
## different reason** — they were per-TYPE and the roster is per-SLOT.

# --- The summon slots ------------------------------------------------------------------------------
## What the number keys hold, and how far out to sea a summon may be pressed. See `sea-summon`.
##
## ⚠⚠ **THE TABLE THAT STOOD HERE IS DELETED. THE SLOTS ARE RUN STATE NOW** (`Army.slots`, 티켓 15).
## `SUMMON_SLOTS` said 「칸 s 는 영원히 종 t 에 묶여 있다」 and that sentence became false the day a
## card could fill a slot: **a constant holding a fact that differs per run is a shape this repo has
## already paid for.** `Army` is where it went and not `Run`, for the reason `army.gd` gives about the
## equipment boards — **`Battle` is handed `army` and nothing else**, and the fight has to read the
## slots.
##
## **Its three lessons did not die with it, and they are the three checks `net_summon._the_run_slots`
## carries**:
##  · **Nothing may write the slot count as a literal.** Count against `army.slot_count()`; the
##    LITERAL belongs on `START_SLOTS.size()`, one side of the assertion only
##  · **The answer for an empty slot is `SUMMON_UNBOUND` and the test is `< 0`, NEVER `<= 0`.**
##    There is a row 0, so a `<= 0` refuses it forever and a slot that refuses looks exactly like an
##    empty roster
##  · **An enemy row must not reach a slot.** Binding one 「reads as done and ships enemy bodies as
##    the player's army」 — `Army.register_species` is the one door and it refuses on `side_of`
##
## ⚠⚠ **AND WHAT THE USER DECIDED THE 짐승 ECONOMY WILL BE IS STILL RECORDED, because it lands on the
## slots**: ***"슬롯에 세포를 넣음 대신 슬롯자체를 강화하는거임"*** — a beast goes into a slot and
## **what you upgrade is the SLOT, not the beast.** Nothing in code does that yet.
const SUMMON_UNBOUND := -1

## How many slots a run may ever hold. **Five, because there are five beasts** — 티켓 05 decided the
## row of buttons is five and that they are all open from the start rather than unlocked by floor.
## ⚠ **A registration past this is REFUSED and changes nothing**, the same contract `Loadout.fit`
## carries for a full board. The screen that asks 「하나 버릴래?」 is 티켓 05 결정 10 and is not built.
const SUMMON_SLOT_MAX := 5

## What a run OPENS with: one row per slot, as `[unit row, how many bodies]`.
##
## ⚠⚠ **This is the OPENING and not the shape of a slot.** A slot's species is `Army.slots` and moves
## during the run; this table is only what `add_starting_force` registers and recruits before anything
## has been played. **The ten cannot move**: `islands.gd` sized the four compact islands' enemy pitch
## against a landing force of ten, and a first island nobody wins is a game whose card screen nobody
## ever sees.
##
## ⚠⚠ **ONE ROW, TEN WOLVES** (2026-08-25, the user: 「시작할 때 뭐 늑대만 있지 않아?」). It was two
## rows — six wolves and four crows — and the crow row moved to a CARD: a run opens holding one
## species and the second arrives on the opening card screen. **The ten did not move**, only how it is
## split.
const START_SLOTS := [
	[SWORDSMAN, 10],
]

const _START_COL_TYPE := 0
const _START_COL_BODIES := 1

## The unit row slot `slot` OPENS bound to, or `SUMMON_UNBOUND` past the opening table. **Only
## `add_starting_force` reads this** — a live slot is `Army.slot_type_of`.
static func start_type_of(slot: int) -> int:
	if slot < 0 or slot >= START_SLOTS.size():
		return SUMMON_UNBOUND
	return int((START_SLOTS[slot] as Array)[_START_COL_TYPE])


## How many bodies a run starts with in slot `slot`. 0 past the opening table.
static func start_bodies_of(slot: int) -> int:
	if slot < 0 or slot >= START_SLOTS.size():
		return 0
	return int((START_SLOTS[slot] as Array)[_START_COL_BODIES])


## The force a run opens with, summed over the opening table rather than written beside it.
static func roster_start_count() -> int:
	var sum := 0
	for s in START_SLOTS.size():
		sum += start_bodies_of(s)
	return sum


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
const SUMMON_BAND_MIN_TILES := 3

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


## --- Equipment: an ITEM LIST, not a body ------------------------------------------------------------
## ⚠⚠ **THE BODY PARTS ARE GONE** (2026-08-24, the user: 「이게 세포 게임에 남아있던 것들이네. 갈아엎어」).
## What stood here was `Part { HEAD, CHEST, BELLY, ARM, HAND, LEG }`, one cell bound to each, plus a
## `Species { MAMMAL, BIRD, FISH }` that nothing read. **It was the cell game's own idea and it survived
## two changes of game** — the wolf roguelike never had a body diagram to hang it on, and the cards still
## said 「다리」 「손」 on screen the day this was written.
##
## What replaces it is what tickets 01 and 02 already decided and nothing had built: **an item goes into
## an UNNAMED cell**, and a summon slot has a row of them. There is no head cell, and therefore no rule
## anywhere forbidding a leg in it — the arrangement that needed forbidding does not exist.
##
## ⚠ **The board belongs to the beast TYPE and not to the body** (티켓 11 — it hung on the summon slot
## until then). A soldier dying does not touch its type's equipment, which is 「늑대에게 투구를 끼우면
## 모든 늑대가 낀다」 said in the code that exists rather than in the code that is planned — and all
## five species have a board, summon slot or none, so no card is ever a dead draw.

## The five columns an item may move — declared in UNITS' own order so the two tables read alike.
const ITEM_COL_HP := 0
const ITEM_COL_DAMAGE := 1
const ITEM_COL_PERIOD := 2
const ITEM_COL_RANGE := 3
const ITEM_COL_SPEED := 4
const ITEM_COL_TOTAL := 5

## How rare a card is. ⚠ **It is a draw weight and nothing else this round** — no set bonus, no visual
## change. 티켓 01 says only LEGENDARY ever changes what a beast looks like, and no beast has a second
## picture yet, so writing that in now would be a rule with no picture behind it.
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

## How many of each rarity a hundred draws should hold. ⚠ **First values, not measured ones** — nothing
## in this game has been balanced yet and pretending otherwise is worse than saying so.
const RARITY_WEIGHT := [60, 26, 11, 3]

## --- Tags: the combo axis (티켓 11) ---------------------------------------------------------------
## An item carries at most ONE tag, and the count of one tag across EVERY board — all five species,
## summoned or not — is what switches a combo on. The four are the user's own list: 출혈 · 공속 ·
## 범위 · 디버프(감속).
##
## ⚠⚠ **Tiers are FLAT and a higher tier REPLACES a lower one. Nothing multiplies per copy.** The
## unnamed cells already drove an attack period to -0.5 s once by stacking one item six times
## (`PERIOD_FLOOR_SEC`'s own header); a per-copy multiplier is that same mine one axis over.
##
## ⚠ **Two tables, because there are two kinds of effect** — a tag that pushes a stat column
## (`TAG_STAT_TIERS`) and a tag that leaves a status on whoever the blow hits (`TAG_STATUS_TIERS`).
## Folding them into one table would leave half the columns as fake zeros in every row.
const TAG_NONE := -1

enum Tag { BLEED, ATK_SPEED, RANGE, DEBUFF }

## What the card and the refit line print. Korean for the same reason the item names are.
const TAG_LABELS = ["출혈", "공속", "범위", "디버프"]

## One row per item: **name · hp · damage · period · range · speed · rarity · tag**, ADDED to the
## type's own number. Nothing multiplies: two rules for one column is the second copy that diverges.
## The tag column may be `TAG_NONE`; what a lit tag does lives in the two tier tables below, so a new
## numeric tag line later is a tier-table row plus this column — one file.
##
## ⚠ **The names are Korean because the user reads them off the card**, and this is the same exception
## the unit table's own 한국어 column already carries. Everything else in `src/` stays English.
##
## ⚠ **The fiction is that these come off the humans whose island was just taken.** That is why a bronze
## plate and a flint tooth sit in one list: the beasts do not forge, they strip.
##
## ⚠ **A negative column is allowed and one row uses it.** 「질주의 발」 trades health for speed, and a
## table where every row is an upgrade is a table where picking is not a decision.
const ITEMS := [
	# name              hp    dmg   period  range  speed  rarity            tag
	["가죽끈",          3.0,  0.0,   0.00,   0.0,   0.0,  Rarity.COMMON,    TAG_NONE],
	["돌 목걸이",       0.0,  1.0,   0.00,   0.0,   0.0,  Rarity.COMMON,    Tag.DEBUFF],
	["나무 발톱",       0.0,  0.0,  -0.10,   0.0,   0.0,  Rarity.COMMON,    Tag.BLEED],
	["마른 가죽",       0.0,  0.0,   0.00,   0.0,   0.6,  Rarity.COMMON,    TAG_NONE],
	["뼛조각",          2.0,  0.5,   0.00,   0.0,   0.0,  Rarity.COMMON,    Tag.BLEED],
	["말린 힘줄",       0.0,  0.0,  -0.05,   0.0,   0.3,  Rarity.COMMON,    Tag.ATK_SPEED],
	["무두질 가죽",     6.0,  0.0,   0.00,   0.0,   0.0,  Rarity.RARE,      TAG_NONE],
	["부싯돌 이빨",     0.0,  2.0,   0.00,   0.0,   0.0,  Rarity.RARE,      Tag.BLEED],
	["사슴 힘줄",       0.0,  0.0,  -0.20,   0.0,   0.0,  Rarity.RARE,      Tag.ATK_SPEED],
	["바람 갈기",       0.0,  0.0,   0.00,   0.0,   1.2,  Rarity.RARE,      TAG_NONE],
	["뺏은 창끝",       0.0,  1.0,   0.00,   1.0,   0.0,  Rarity.RARE,      Tag.RANGE],
	["방패 조각",       4.0,  0.0,   0.00,   0.0,  -0.3,  Rarity.RARE,      Tag.DEBUFF],
	["청동 판",        10.0,  0.0,   0.00,   0.0,   0.0,  Rarity.EPIC,      TAG_NONE],
	["늑대 송곳니",     0.0,  3.0,  -0.10,   0.0,   0.0,  Rarity.EPIC,      Tag.BLEED],
	["사냥꾼의 눈",     0.0,  0.0,   0.00,   2.0,   0.0,  Rarity.EPIC,      Tag.RANGE],
	["질주의 발",      -2.0,  0.0,   0.00,   0.0,   2.0,  Rarity.EPIC,      TAG_NONE],
	["우두머리의 뿔",  12.0,  3.0,   0.00,   0.0,   0.0,  Rarity.LEGENDARY, Tag.DEBUFF],
	["폭풍의 가죽",     0.0,  0.0,  -0.25,   0.0,   2.5,  Rarity.LEGENDARY, Tag.ATK_SPEED],
]

const _ITEM_COL_NAME := 0
const _ITEM_COL_STATS := 1
const _ITEM_COL_RARITY := 6
const _ITEM_COL_TAG := 7

## How many unnamed cells one summon slot's board has.
## ⚠ **Six, which is what the board already drew** — the cells stopped being body parts, not stopped
## existing, and `look.gd`'s refit layout is measured against six boxes. Changing this number is a
## screen job as much as a rules one.
const ITEM_CELLS := 6

## ⚠⚠ **A REAL FLOOR, AND IT IS NOT A SAFETY BELT.** The old parts table wrote down that there was
## deliberately NO clamp anywhere, because one part per cell meant the period could fall by at most one
## row's worth and a floor would have been a branch no input could reach. **Unnamed cells deleted that
## argument**: any item may be fitted six times, and six copies of the biggest period drop in the table
## takes a 1.0 s attack to **-0.5 s**. `net_parts` measured exactly that the day the cells were unnamed.
## ⇒ The clamp lives in `Loadout.stat_of`, and 0.20 s is the bound that net already carried as a literal.
## ⚠ The ATK_SPEED tag term below lands on the same column and sits INSIDE that same clamp, because
## `Loadout.bonus` is where the term is added and `stat_of` clamps after it.
const PERIOD_FLOOR_SEC := 0.20


## --- The numeric tag tiers -------------------------------------------------------------------------
## One row per stat-pushing tag: tag · the `ITEM_COL_*` it pushes · tiers of [threshold, add].
## The add is FLAT across the whole horde — every species' `Loadout.stat_of` reads it — and the
## highest reached tier REPLACES the lower ones (see the Tag header). Tiers are listed ascending;
## `tag_stat_bonus_at` walks them in order and keeps the last one reached.
##
## ⚠ **First values, not measured ones**, like `RARITY_WEIGHT`. The low thresholds went to the tags
## with the fewest items (범위 2종 · 디버프 3종): a run draws at most one card per non-boss node,
## `map_max_card_nodes_on_a_route()` of them in total, so a threshold is a real share of a whole run.
const TAG_STAT_TIERS := [
	[Tag.ATK_SPEED, ITEM_COL_PERIOD, [[3, -0.10], [5, -0.25]]],
	[Tag.RANGE, ITEM_COL_RANGE, [[2, 0.5], [4, 1.0]]],
]

const _TSTAT_COL_TAG := 0
const _TSTAT_COL_STAT := 1
const _TSTAT_COL_TIERS := 2


static func tag_stat_row_count() -> int:
	return TAG_STAT_TIERS.size()


static func tag_stat_tag_of(r: int) -> int:
	return int((TAG_STAT_TIERS[r] as Array)[_TSTAT_COL_TAG])


static func tag_stat_col_of(r: int) -> int:
	return int((TAG_STAT_TIERS[r] as Array)[_TSTAT_COL_STAT])


## The flat add row `r` puts on its column at `count` copies of its tag: the highest tier whose
## threshold is reached, 0.0 below the first one. Replacement — never a sum of tiers — happens here
## and nowhere else, so a caller cannot re-introduce the per-copy multiply by accident.
static func tag_stat_bonus_at(r: int, count: int) -> float:
	var add := 0.0
	for raw in (TAG_STAT_TIERS[r] as Array)[_TSTAT_COL_TIERS]:
		var tier: Array = raw
		if count >= int(tier[0]):
			add = float(tier[1])
	return add


## --- The species that MOVE what they hit -------------------------------------------------------
## One row per species whose blow shoves its target: the `UNITS` row, **how many tiles, signed
## POSITIVE TOWARD the attacker**, and whether it happens only once per body per island.
##
## ⚠⚠ **Two species, one mechanism, and the only difference is a sign.** 다람쥐 pulls what it bites
## in; 소 drives it away. Written as one signed column rather than as two rules, because two rules
## for one motion is the second copy that diverges.
##
## ⚠ **The 「once」 column belongs to 소 and is what makes it a CHARGE rather than a shove.** `Battle`
## is new every island, so 「per island」 costs no reset code — it comes free with the object.
##
## ⚠ **First values, not measured ones.**
## ⚠⚠ **EMPTY since 2026-08-26.** Its two rows were 다람쥐 and 소, and both left the unit table with the
## side swap. **The table stays** because the mechanic is wired and one row brings it back.
const SPECIES_SHOVE := []

const _SHOVE_COL_TYPE := 0
const _SHOVE_COL_TILES := 1
const _SHOVE_COL_ONCE := 2


## Tiles species `type_id` shoves what it hits, positive toward itself. **0.0 for a species with no
## row**, which is what makes the whole feature a table lookup with no branch behind it.
static func shove_tiles_of(type_id: int) -> float:
	for r in SPECIES_SHOVE.size():
		if int((SPECIES_SHOVE[r] as Array)[_SHOVE_COL_TYPE]) == type_id:
			return float((SPECIES_SHOVE[r] as Array)[_SHOVE_COL_TILES])
	return 0.0


## Whether species `type_id` shoves only on its FIRST blow of an island.
static func shove_once_of(type_id: int) -> bool:
	for r in SPECIES_SHOVE.size():
		if int((SPECIES_SHOVE[r] as Array)[_SHOVE_COL_TYPE]) == type_id:
			return bool((SPECIES_SHOVE[r] as Array)[_SHOVE_COL_ONCE])
	return false


## --- The species that hunt as one -------------------------------------------------------------
## One row per species that picks its target from the centre of mass of its own kind nearby, itself
## included: the `UNITS` row and how far 「nearby」 reaches, in tiles.
##
## ⚠⚠ **ONE NUMBER BUYS BOTH HALVES OF 무리사냥.** Picking from a shared point makes a pack bite the
## same enemy (티켓 06's own sentence), and the movement phase then walks each of them at THAT enemy —
## so they arrive as one body. **There is no formation code**, and a second rule for the shape would
## be a second thing to keep in step with the first.
##
## ⚠⚠ **NEARBY AND NEVER GLOBAL.** A global centre of mass drags a wolf that landed on the far beach
## toward one point — and where you land is the decision this whole game is about.
##
## ⚠ **First value, not a measured one.**
const SPECIES_PACK := [
	[WOLF, 6.0],
]

## ⚠⚠ **THE PACK TABLE ABOVE IS A TARGETING RULE AND IT DOES NOTHING TO FORMATION — measured, not
## suspected** (2026-08-25, `tools/probe/pack_spread.gd`). `_seek_point_of` only changes WHERE a body
## LOOKS FROM when it picks a target; every body then walks its own flow field alone. Ten wolves
## crossing the first island, pack radius 6.0 against the same run with it forced to 0.0:
##
##   씨앗 7 — spread 1.60 / widest 4.93 / touching 85%  BOTH WAYS, identical to two decimals
##   씨앗 1 — 1.79 vs 1.90    씨앗 99 — 1.85 vs 1.84
##
## ⚠ `how-nets-lie` already records the check labelled 「무리가 한 덩어리로 움직인다」 passing
## with this radius at zero. **It passes because the radius changes nothing**, and that is now measured
## rather than inferred. The table stays what it is — a rule about who gets bitten.
##
## --- ⚠⚠ A COHESION THROTTLE WAS BUILT HERE AND TAKEN BACK OUT, because it was measured ------------
## 2026-08-25, the user, watching a fight: ***"좀더 배드노스 같이 합쳐져야할듯"***. So a rule was added
## that slowed any body further along toward its target than the group's centre of mass was. Measured
## with `pack_spread` on the first island, ten wolves and four others:
##
##   gentle (3.0 tiles of lead, floor 0.35) — spread 1.79/1.60/1.85 -> **1.81/1.59/1.75**, and fights
##       15% longer
##   hard   (1.0 tile,          floor 0.10) — spread -> **1.64/1.63/1.64**, still nothing, and fights
##       **19.0s -> 34.3s**
##
## ⇒ **The lever has no authority over the spread and a large cost in time.** Keeping it would have
## been a mechanism whose measured effect is noise, which is the shape this file's own header calls
## code that pretends to work.
##
## ⚠⚠ **AND THE SAME PROBE SAYS THE GROUP IS ALREADY TOGETHER**, which is the finding that matters more
## than the reverted rule: **89% of bodies have another within one tile**, fourteen of them average
## **1.7–1.9 distinct targets** between them, and **78% of samples have the whole group facing one
## way.** Whatever reads as scattered on screen, the formation is not it — so the next place to look is
## the PICTURE, and the number pointing there is that a body's sprite is **1.23 tiles wide standing on
## 1-tile centres**, so a dense group necessarily overlaps into one mass.
##
const _PACK_COL_TYPE := 0
## ⚠ Named `_TILES` and not `_RADIUS`: `net_draw_leaf`'s pixel sweep reads every file under `src/`
## outside `look.gd` and `radius` is one of the size-ish suffixes it bites, so a column constant
## wearing that word reads as a presentation literal in a rules file. The distance IS in tiles.
const _PACK_COL_TILES := 1


## How far species `type_id` looks for its own kind when picking a target. **0.0 for a species with
## no row**, which is what makes a lone hunter a table lookup rather than a branch.
static func pack_radius_of(type_id: int) -> float:
	for r in SPECIES_PACK.size():
		if int((SPECIES_PACK[r] as Array)[_PACK_COL_TYPE]) == type_id:
			return float((SPECIES_PACK[r] as Array)[_PACK_COL_TILES])
	return 0.0


## --- The status table ------------------------------------------------------------------------------
## ⚠⚠ **Not one-off bleed code** (2026-08-24, the user: 「독부터 해서 정말 많이 있을듯」). A status is a
## row here plus a generic walk in `battle.gd`; the day poison arrives it is one `Status` entry and one
## `TAG_STATUS_TIERS` row, and `battle.gd` stays shut — poison is the DOT kind bleed already built.
## A status of a NEW kind (one that touches a stat, the way SLOW touches enemy speed) also needs the
## one read site for that stat, which is what SLOW built this round.
##
## The KIND decides what the magnitude means: DOT — damage per second; SLOW — a speed multiplier.
enum Status { BLEED, SLOW }
enum StatusKind { DOT, SLOW }

## Kind per `Status`, index-aligned. Appended, never inserted — `battle.gd`'s flat status arrays are
## indexed by these ordinals.
const STATUS_KIND := [StatusKind.DOT, StatusKind.SLOW]


static func status_count() -> int:
	return STATUS_KIND.size()


static func status_kind_of(s: int) -> int:
	return int(STATUS_KIND[s])


## One row per status-carrying tag: tag · the `Status` it leaves · tiers of
## [threshold, magnitude, duration seconds]. A lit tier makes every allied blow leave that status on
## everyone the blow actually hit; re-hitting REFRESHES (the lit tier's own values overwrite what is
## stored) and never accumulates — the -0.5 s mine's cousin lives in the accumulate.
## ⚠ **First values, not measured ones.**
const TAG_STATUS_TIERS := [
	[Tag.BLEED, Status.BLEED, [[3, 0.5, 2.0], [5, 1.5, 3.0]]],
	[Tag.DEBUFF, Status.SLOW, [[2, 0.7, 2.0], [4, 0.5, 3.0]]],
]

const _TSTATUS_COL_TAG := 0
const _TSTATUS_COL_STATUS := 1
const _TSTATUS_COL_TIERS := 2


static func tag_status_row_count() -> int:
	return TAG_STATUS_TIERS.size()


static func tag_status_tag_of(r: int) -> int:
	return int((TAG_STATUS_TIERS[r] as Array)[_TSTATUS_COL_TAG])


static func tag_status_status_of(r: int) -> int:
	return int((TAG_STATUS_TIERS[r] as Array)[_TSTATUS_COL_STATUS])


## The stronger of two tiers of the SAME status, either of which may be empty.
##
## ⚠⚠ **WHICH WAY 「강하다」 POINTS DEPENDS ON THE KIND, and reading it one way is a real defect.** A
## DOT's magnitude is damage a second and BIGGER is stronger; a SLOW's is a speed multiplier and
## SMALLER is stronger. One comparison for both hands a slowed enemy the weakest slow on the field.
##
## ⚠ **Ties on magnitude break on the LONGER duration**, so a source that is equally strong and lasts
## longer is not silently discarded.
##
## ⚠ **This resolves the sources of ONE BLOW and is not a stacking rule.** What lands on a body is a
## single tier, exactly as before; what changed is that a blow with two sources no longer lets
## whichever was written last stand.
static func stronger_status_tier(status: int, a: Dictionary, b: Dictionary) -> Dictionary:
	if a.is_empty():
		return b
	if b.is_empty():
		return a
	var am := float(a["mag"])
	var bm := float(b["mag"])
	if not is_equal_approx(am, bm):
		var a_wins := am > bm if status_kind_of(status) == StatusKind.DOT else am < bm
		return a if a_wins else b
	return a if float(a["sec"]) >= float(b["sec"]) else b


## The lit tier of row `r` at `count` copies of its tag, as {"mag": .., "sec": ..} — empty below the
## first threshold. The highest reached tier replaces the lower ones, same rule as the numeric table.
static func tag_status_tier_at(r: int, count: int) -> Dictionary:
	var lit := {}
	for raw in (TAG_STATUS_TIERS[r] as Array)[_TSTATUS_COL_TIERS]:
		var tier: Array = raw
		if count >= int(tier[0]):
			lit = {"mag": float(tier[1]), "sec": float(tier[2])}
	return lit


## --- The species that leave a status behind ---------------------------------------------------
## One row per species whose blow leaves a status on what it hits: the `UNITS` row, the `Status`, its
## magnitude and its duration in seconds.
##
## ⚠⚠ **THIS IS A SECOND SOURCE AND NOT A SECOND MECHANISM.** It writes through the same
## `_put_status` the equipment tags write through, and `_phase_status` walks `STATUS_KIND` without
## ever knowing a status by name — so 까마귀's 출혈 costs one row here and nothing at all in
## `battle.gd`'s ageing or damage-over-time code.
##
## ⚠ **First values, and deliberately the SAME numbers the 출혈 tag's first tier carries** (0.5 a
## second for 2 seconds). ⚠⚠ **A crow wearing bleed equipment gets the HIGHER of the two and not the
## last one written** — `Battle._apply_statuses` resolves both sources of a blow through
## `stronger_status_tier` before anything reaches the body. Written the naive way the crow's own
## passive OVERWROTE its equipment and cut a full bleed set to 22% of what the same set gives a wolf.
const SPECIES_STATUS := [
	[CROW, Status.BLEED, 0.5, 2.0],
]

const _SPECIES_STATUS_COL_TYPE := 0
const _SPECIES_STATUS_COL_STATUS := 1
const _SPECIES_STATUS_COL_MAG := 2
const _SPECIES_STATUS_COL_SEC := 3


## What species `type_id` leaves on what it hits, as `{"status": .., "mag": .., "sec": ..}` — **empty
## for a species with no row**, which is what makes this a table lookup with no branch behind it.
## ⚠ The `mag`/`sec` keys match `tag_status_tier_at`'s, so `_put_status` takes either without asking
## which table it came from.
static func species_status_of(type_id: int) -> Dictionary:
	for r in SPECIES_STATUS.size():
		var row: Array = SPECIES_STATUS[r]
		if int(row[_SPECIES_STATUS_COL_TYPE]) == type_id:
			return {
				"status": int(row[_SPECIES_STATUS_COL_STATUS]),
				"mag": float(row[_SPECIES_STATUS_COL_MAG]),
				"sec": float(row[_SPECIES_STATUS_COL_SEC]),
			}
	return {}


## Every threshold `tag` can light, ascending, walked over BOTH tier tables — the refit aggregate
## reads this, so the screen's "count/next" line derives from the same rows the effects do and a new
## tier is on screen the day its table row lands.
static func tag_thresholds_of(tag: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for r in tag_stat_row_count():
		if tag_stat_tag_of(r) == tag:
			for raw in (TAG_STAT_TIERS[r] as Array)[_TSTAT_COL_TIERS]:
				out.append(int((raw as Array)[0]))
	for r in tag_status_row_count():
		if tag_status_tag_of(r) == tag:
			for raw in (TAG_STATUS_TIERS[r] as Array)[_TSTATUS_COL_TIERS]:
				out.append(int((raw as Array)[0]))
	out.sort()
	return out

## ⚠⚠ **THREE CARDS, ONE PICK** (2026-08-24, 티켓 06). It was six and two. **Two of three are left on
## the table**, so the pick is a loss as well as a gain — which is the whole of what makes it a decision.
const CARDS_PER_WIN := 3
const CARD_PICKS := 1


## --- What a card can BE ---------------------------------------------------------------------------
## ⚠⚠ **A card is one of two things now** (티켓 15): a piece of equipment, or a BEAST — a summon slot
## filled with a species, plus bodies of it. `Run.cards[k]` holds an item id under `ITEM` and a
## `UNITS` row under `SPECIES`, and `Run.card_kind[k]` is which.
enum CardKind { ITEM, SPECIES }

## One row per beast card: the `UNITS` row it registers, and how rare the card is.
##
## ⚠⚠ **EMPTY since 2026-08-26, and that is a DECISION, not a gap.** The five rows here registered a
## beast into a summon slot, and **the beasts are the enemy now** — `Army.register_species` refuses a
## row on the enemy's side, so every one of them would have been a card that cannot be picked.
## ⚠⚠ **The user chose what fills the hole**: 「성장 카드는 장비 위주로 주자」. An empty pool is exactly
## that — `Run._draw_cards` falls through to equipment for every card, including the opening round.
## ⚠ **The table stays** because the mechanic is wired end to end; a second player body is one row.
const SPECIES_CARDS := []

const _SPECIES_CARD_COL_TYPE := 0
const _SPECIES_CARD_COL_RARITY := 1

## How many bodies of that species arrive with the card. **2026-08-25, the user, with 「일단」 on it**
## — so it is ONE constant and 4 is written nowhere else: changing what a beast card is worth has to
## be one line.
##
## ⚠⚠ **IT MUST NOT BE 0.** A card that only registers a slot adds **a button that refuses when you
## press it** — the same failure the user hit from the other side with the deleted count reward (a thing that is
## there and is not on screen), built backwards.
##
## **Why four**: the old second slot opened with four bodies, so 「둘째 종이 도착한다」 is the size this
## game has already been played at.
const SPECIES_CARD_BODIES := 4

## The chance ONE card is a beast rather than an item. ⚠⚠ **The kind is rolled BEFORE what is inside
## it, for the reason `_draw_cards` already gives about rarity**: roll straight over one pooled list
## and adding an item makes beasts quietly rarer, so the drop table moves whenever the CONTENT moves.
##
## ⚠ **It is a weight and NOT a reservation.** 2026-08-25 the user cut the earlier plan's 「세 장 중 한
## 장은 늘 짐승」: every card rolls its own kind, so some rounds hold no beast at all and some hold
## three. `1/3` keeps the frequency that plan argued for — one beast per round in expectation — and
## drops only the guarantee.
##
## ⚠ **This is a FLAT weight and it is not the last word.** 티켓 18 tilts the pool toward the species a
## run is already using; nothing here may be written down as 「영원히 균등」, or that ticket starts by
## deleting a sentence.
const SPECIES_CARD_WEIGHT := 1.0 / 3.0


static func species_card_count() -> int:
	return SPECIES_CARDS.size()


static func species_card_type_of(r: int) -> int:
	return int((SPECIES_CARDS[r] as Array)[_SPECIES_CARD_COL_TYPE])


## The card rarity of beast row `type_id`, or `Rarity.COMMON` for a row with no card.
static func species_card_rarity_of(type_id: int) -> int:
	for r in SPECIES_CARDS.size():
		if int((SPECIES_CARDS[r] as Array)[_SPECIES_CARD_COL_TYPE]) == type_id:
			return int((SPECIES_CARDS[r] as Array)[_SPECIES_CARD_COL_RARITY])
	return Rarity.COMMON


## --- One card's face, whatever kind it is ---------------------------------------------------------
## ⚠⚠ **These three exist so `reward_view` never asks what kind a card is.** A screen that branched on
## the kind would be a second place that knows there are two of them, and the day a third arrives one
## of the two gets missed.

static func card_name_of(kind: int, value: int) -> String:
	if kind == CardKind.SPECIES:
		return label_of(value)
	return item_name_of(value)


static func card_rarity_of(kind: int, value: int) -> int:
	if kind == CardKind.SPECIES:
		return species_card_rarity_of(value)
	return item_rarity_of(value)


## What the card does, as one line. ⚠ **Built from the constants, never typed beside them** — the same
## rule `item_effect_text` carries, and the reason the cards said 「다리」 for a round after legs
## stopped existing.
static func card_effect_text_of(kind: int, value: int) -> String:
	if kind == CardKind.SPECIES:
		return "소환 칸 +1 · %d마리" % SPECIES_CARD_BODIES
	return item_effect_text(value)


## The five column names, in `ITEM_COL_*` order, and the one place they are spelled.
## ⚠ **Korean, and that is the same exception the item names carry**: this string goes on a card the
## user reads. `refit_view.STAT_LABELS` is the same five words for the dashboard and reads THIS.
const ITEM_COL_LABELS = ["체력", "공격력", "공격주기", "사거리", "이동속도"]


## What an item does, as one line — 「체력 +6」, 「공격력 +3 · 공격주기 -0.10」.
##
## ⚠⚠ **Built from the table, never typed beside it.** A description written by hand is a second copy
## of the numbers, and the day one moves the card lies about it — which is exactly the failure this
## whole rewrite was for: the cards said 「다리」 for a round after legs stopped existing.
static func item_effect_text(item: int) -> String:
	var parts := []
	for col in ITEM_COL_TOTAL:
		var v := item_bonus(item, col)
		if absf(v) <= EPS:
			continue
		# The period is the one column measured in seconds and the one that is better when it falls,
		# so it is the one printed to two decimals. ⚠ **`%g` does not exist in GDScript's `%`** — it is
		# a silent 「unsupported format character」 at runtime, printed once per card per frame.
		var shown := ""
		if col == ITEM_COL_PERIOD:
			shown = "%+.2f" % v
		elif is_equal_approx(v, roundf(v)):
			shown = "%+d" % int(roundf(v))
		else:
			shown = "%+.1f" % v
		parts.append("%s %s" % [str(ITEM_COL_LABELS[col]), shown])
	# The tag word rides at the end of the same line, so the card and the refit row both carry it with
	# neither of them typing it.
	var tag := item_tag_of(item)
	if tag != TAG_NONE:
		parts.append(str(TAG_LABELS[tag]))
	return " · ".join(parts)


static func item_count() -> int:
	return ITEMS.size()


static func item_name_of(item: int) -> String:
	if item < 0 or item >= ITEMS.size():
		return ""
	return str((ITEMS[item] as Array)[_ITEM_COL_NAME])


static func item_rarity_of(item: int) -> int:
	if item < 0 or item >= ITEMS.size():
		return Rarity.COMMON
	return int((ITEMS[item] as Array)[_ITEM_COL_RARITY])


## The tag item `item` carries, or `TAG_NONE` — for an untagged item and for an out-of-range id alike,
## because an id that does not exist counts toward no combo.
static func item_tag_of(item: int) -> int:
	if item < 0 or item >= ITEMS.size():
		return TAG_NONE
	return int((ITEMS[item] as Array)[_ITEM_COL_TAG])


static func tag_kind_count() -> int:
	return TAG_LABELS.size()


static func tag_label_of(tag: int) -> String:
	if tag < 0 or tag >= TAG_LABELS.size():
		return ""
	return str(TAG_LABELS[tag])


## What item `item` adds to column `col`. **The one reader of `ITEMS`' number columns**, so the offset
## between "column 0 is hp" and "cell 1 of the row is hp" is written once.
static func item_bonus(item: int, col: int) -> float:
	if item < 0 or item >= ITEMS.size():
		return 0.0
	if col < 0 or col >= ITEM_COL_TOTAL:
		return 0.0
	return float((ITEMS[item] as Array)[_ITEM_COL_STATS + col])


## Every item of one rarity, in table order. Used by the draw, which picks a rarity first and an item
## inside it second — so adding a common item cannot quietly make legendaries rarer.
static func items_of_rarity(rarity: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in ITEMS.size():
		if int((ITEMS[i] as Array)[_ITEM_COL_RARITY]) == rarity:
			out.append(i)
	return out


## The rarity a roll of `0 .. RARITY_WEIGHT sum - 1` lands on.
## ⚠ **The caller owns the RNG.** `rules.gd` holds no state and never will — a table that could roll
## its own number is a table two runs cannot be compared across.
static func rarity_at_roll(roll: int) -> int:
	var acc := 0
	for r in RARITY_WEIGHT.size():
		acc += int(RARITY_WEIGHT[r])
		if roll < acc:
			return r
	return Rarity.COMMON


static func rarity_weight_total() -> int:
	var sum := 0
	for w in RARITY_WEIGHT:
		sum += int(w)
	return sum


## Maps an `ITEM_COL_*` onto the matching base-stat column, so the five columns are not named twice.
## ⚠ This is what stops the five columns being named twice — every base number in the game is still
## read through the existing `hp_of` · `damage_of` · `period_of` · `range_of` · `speed_of`, and this is
## a `match` over those five and nothing else.
static func unit_stat(type_id: int, col: int) -> float:
	match col:
		ITEM_COL_HP:
			return hp_of(type_id)
		ITEM_COL_DAMAGE:
			return damage_of(type_id)
		ITEM_COL_PERIOD:
			return period_of(type_id)
		ITEM_COL_RANGE:
			return range_of(type_id)
		ITEM_COL_SPEED:
			return speed_of(type_id)
	return 0.0




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
