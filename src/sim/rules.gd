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
## **The window is 「above the stair diagonal, below the flat two-tile orthogonal」.** ⚠⚠ **The numbers
## in the paragraph above were measured while a notch was a whole tile, and a notch is half a tile now**
## (2026-08-27, see `TIER_RISE_TILES`). **The defect and the fix are unchanged; only the margins moved.**
## Today the stair diagonal is `sqrt(2 + 0.25)` = **1.5** and the flat two-tile orthogonal is **2.0**, so
## the window is `(1.5, 2.0)` and **1.75 sits dead centre, +0.25 above and -0.25 below.** Both bounds are
## exact (heights are exact multiples of `TIER_STEP_TILES`) and `EPS` is 1e-4.
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
## table decided two tiers, a stair one tile wide, and the stair as the only way up. ⚠ **That table also
## said one tier was two tiles tall and that half is dead** — see `TIER_RISE_TILES`: a tier is ONE tile. The whole of "the stair is the only door" is `MAX_CLIMB_LEVELS` below: low ground is level 0,
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
## ⚠⚠ **LOWERED 2.0 -> 1.0 (2026-08-27), and it was a LIE being corrected, not a balance change.**
## The mesh has always been the source of the board: `island_build.py` writes `level_h` into
## `island.json` and it is **0.5 — half a tile per notch**, which the user restated as 「한 층이 한 칸,
## 계단은 반 칸」 — ⚠ **the user's own words, unchanged; the 2026-08-27 swap makes those 칸 today's 조각.** This constant said one notch was a whole tile, so **the sim measured every height at
## exactly twice what the ground the player looks at actually stands.** A body on the plateau computed
## 2.0 tiles up while the drawn plateau stood 1.0 up.
## ⚠ **`REACH_BONUS` survives the change and gets a WIDER margin, which is why nothing is retuned.**
## Its window is 「above the stair diagonal, below the flat two-tile orthogonal」. At a 0.5 notch the
## stair diagonal is `sqrt(2 + 0.25)` = **1.5** and the flat two-tile is still **2.0**, so the window
## opens from `(1.732, 2.0)` to `(1.5, 2.0)`. **1.75 now sits with +0.25 above and -0.25 below**,
## where before it had +0.018 above. The value that was measured in play stays the value.
const TIER_RISE_TILES := 1.0
## How far ONE level rises — a stair tread. Half a tier, because a stair sits halfway up.
## ⚠ **This is the number that must equal `level_h` in `island.json`.** Nothing asserts it across the
## two files yet, and that silence is how the two drifted apart for a day. **0.5 today.**
const TIER_STEP_TILES := TIER_RISE_TILES * 0.5
## The largest level difference a body may step across. **1**, so a stair is passable from both sides
## and a tier boundary is not.
const MAX_CLIMB_LEVELS := 1

## ⚠⚠ **HOW MANY TREADS BLENDER CUTS INTO ONE STAIR 칸, AND THE FEET HAVE TO LAND ON THEM**
## (2026-08-28, the user, watching a body climb: 「계단을 캐릭이 뚫고감 이건 근본적인문제인데」).
##
## **The stair was drawn as steps and walked as a ramp.** `tools/blender/island_build.py`'s `stair()`
## cuts `TREADS = 6` steps with a nosing into the 칸's own mesh, and `Grid.surface_h` returned a
## straight line from the bottom of the run to the top — so a body walked the *average* of the steps,
## sinking into every tread and floating over every riser. **Both files carried a comment saying the
## two must agree; neither said what the other's number was.**
##
## ⚠ **The steps win and the ramp loses**, because the picture is what the user chose over several
## rounds (「큐브형투처럼 블록 블록이 있었으면 좋겠는데」) and because a ramp cannot be drawn as a stair.
## ⚠ **6 IS DUPLICATED IN `island_build.py` AS `TREADS`** and Blender cannot read this file. That is the
## same shape `TIER_STEP_TILES` / `level_h` already has, and it is written down rather than assumed.
const STAIR_TREADS := 6


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


## ⚠⚠ **THE SUMMON BAND STOOD HERE AND IT IS DELETED** (2026-08-29) with the gesture that pressed it:
## `SUMMON_BAND_MIN_TILES`, `SUMMON_RADIUS_RATIO` and `summon_radius_of`.
##
## ⚠⚠ **THE BAND WAS A MINIMUM DISTANCE FROM LAND AND IT USED TO BE A MAXIMUM**, and the user inverted
## it after playing: ***"해안선에 배를 배치하는게 아니라 좀 거리를 둬야함 지형하고 많이 줘도됨 배가
## 가는게 중요하니까"***. **The reason is a design reason and not a preference: the crossing is the
## thing worth watching, and a band hugging the shore deletes it.** ⚠ The name changed with the
## meaning — a constant whose sense inverts under the same name is one nobody re-reads.
##
## ⚠ **There was no maximum.** Every water tile the boat field reached and that was far enough was in,
## the open sea included.


## --- EQUIPMENT, RARITY, TAGS, STATUSES AND CARDS: ALL DELETED 2026-08-29 ---------------------------
## ⚠⚠ **The whole growth half of the game is gone from this file, and it went because NOTHING COULD
## REACH IT.** The reward screen and the refit screen were deleted 2026-08-28; from that moment
## `Loadout.take_card` and `Loadout.fit` had no caller in `src/`, so **the board every item was fitted
## into stayed empty for the whole of every run.** `tag_count` therefore answered 0 on every blow, so
## `TAG_STAT_TIERS` added nothing to any stat and `TAG_STATUS_TIERS` lit no status — **bleed and slow
## never once fired in a fight the player played.** Measured, not assumed: the only readers left were
## the nets.
##
## What went: `ITEM_COL_*` · `ITEMS` · `ITEM_CELLS` · `PERIOD_FLOOR_SEC` · `Rarity` · `RARITY_WEIGHT` ·
## `Tag` · `TAG_LABELS` · `TAG_STAT_TIERS` and its accessors · `Status` · `StatusKind` · `STATUS_KIND` ·
## `TAG_STATUS_TIERS` and its accessors · `stronger_status_tier` · `tag_thresholds_of` ·
## `CARDS_PER_WIN` · `CARD_PICKS` · `CardKind` · the three `card_*_of` faces · `ITEM_COL_LABELS` ·
## `item_effect_text` and every `item_*` accessor · `items_of_rarity` · `rarity_at_roll` ·
## `rarity_weight_total` · `unit_stat`. `Loadout` went with them and `Army` now reads `Rules` directly.
##
## ⚠⚠ **WHAT TO READ BEFORE REBUILDING IT** (it is decided and unbuilt, not rejected): **roll the
## RARITY first and the ITEM inside it second**, so adding a common item cannot quietly make
## legendaries rarer. **A status is a table row plus one generic walk in `battle.gd`**, never one-off
## code — the user, 2026-08-24: 「독부터 해서 정말 많이 있을듯」. **The board hangs on the SPECIES and
## not on the body**, so a soldier dying does not strip its type's equipment. **An item goes into an
## UNNAMED cell**: there is no head cell, so no rule anywhere has to forbid a leg in it.
## --- THE SHOVE TABLE: DELETED 2026-08-27 ----------------------------------------------------------
## `SPECIES_SHOVE`, `shove_tiles_of` and `shove_once_of` are gone, and so is every line in `battle.gd`
## that read them. **The table had been `[]` since 2026-08-26**: its two rows were 다람쥐's pull and
## 소's charge, and both species left `UNITS` with the side swap, so the lookup answered 0.0 on every
## blow struck in the game.
##
## ⚠⚠ **IT WAS KEPT ONE DAY LONGER ON 「the mechanic is wired and one row brings it back」, AND THAT IS
## THE CLAIM THIS DELETION REJECTS.** An empty table meant no check could enter the shove at all — the
## three rows in `net_battle` that named it were asserting that nothing moved, which is also what a
## broken shove does. **Wiring nothing can reach is not wiring that is ready.**
##
## ⚠ **What the shove KNEW is recorded in `battle.gd` where the code stood**, not here: a body never
## changes tier by being pushed (티켓 19, the user's own decision), four things have to move together,
## and a once-per-island charge is spent by the move rather than by the attempt. **Read that block
## before building anything that moves a body without it walking.**

## --- 무리사냥 / THE PACK RULE: DELETED 2026-08-27 --------------------------------------------------
## `SPECIES_PACK`, `_PACK_COL_TYPE`, `_PACK_COL_TILES` and `pack_radius_of` are gone, and with them
## `Battle._seek_point_of`, its call site in `_phase_targeting`, and `tools/probe/pack_spread.gd`.
## The table held ONE row — `[WOLF, 6.0]` — and it was looked up against the PLAYER's roster:
## `_seek_point_of` asked `pack_radius_of(army.type_id[i])`, the only player row is SWORDSMAN, and
## **the wolf became an ENEMY with the side swap (2026-08-26)**. ⇒ **`pack_radius_of` answered 0.0 on
## every call in the game and the huddle returned on its first line, every frame, for a whole day.**
##
## ⚠⚠ **WHAT THE RULE WAS, IN ONE SENTENCE, BECAUSE IT COST A TICKET TO ARRIVE AT IT.** A body picked
## its target from the CENTRE OF MASS of its own kind nearby, itself included. **One number bought both
## halves of 무리사냥**: a shared point makes a pack bite the same enemy (티켓 06's own sentence), and
## the movement phase then walks each of them at THAT enemy, so they arrive as one body. **There was no
## formation code and there must not be one** — a second rule for the shape is a second thing to keep in
## step with the first. ⚠ **Nearby and never GLOBAL**: a global centre drags a body that landed on the
## far beach toward one point, and where you land is the decision this whole game is about.
##
## ⚠⚠ **AND IT DID NOT DO WHAT ITS NAME SAYS — MEASURED, NOT SUSPECTED** (2026-08-25,
## `tools/probe/pack_spread.gd`). It was a TARGETING rule with **no authority over formation at all**:
## it changed only WHERE a body LOOKED FROM, and every body then walked its own flow field alone. Ten
## wolves crossing the first island, radius 6.0 against the same run with it forced to 0.0:
##
##   씨앗 7 — spread 1.60 / widest 4.93 / touching 85%  BOTH WAYS, identical to two decimals
##   씨앗 1 — 1.79 vs 1.90    씨앗 99 — 1.85 vs 1.84
##
## ⚠⚠ **THAT IS THE MOST IMPORTANT THING ON THIS PAGE AND IT IS A LESSON ABOUT INSTRUMENTS, NOT ABOUT
## WOLVES.** The net labelled 「무리가 한 덩어리로 움직인다」 **passed with the radius forced to zero**:
## it was built on a board carrying ONE enemy, where every seek point answers the same id, so pack-on
## and pack-off produced the identical decimal. **The probe was the only instrument that ever measured
## this rule honestly, and it is the only reason we know the rule was hollow rather than merely dead.**
## ⇒ **A check on a rule that chooses BETWEEN things needs at least two things to choose between**, and
## a probe that prints numbers and judges nothing catches what an assertion phrased as a hope cannot.
## `how-nets-lie` carries the entry.
##
## --- ⚠⚠ A COHESION THROTTLE WAS BUILT HERE AND TAKEN BACK OUT, and it too was measured -------------
## 2026-08-25, the user, watching a fight: ***"좀더 배드노스 같이 합쳐져야할듯"***. A rule was added that
## slowed any body further along toward its target than the group's centre of mass was. Measured with
## the same probe on the first island, ten wolves and four others:
##
##   gentle (3.0 tiles of lead, floor 0.35) — spread 1.79/1.60/1.85 -> **1.81/1.59/1.75**, and fights
##       15% longer
##   hard   (1.0 tile,          floor 0.10) — spread -> **1.64/1.63/1.64**, still nothing, and fights
##       **19.0s -> 34.3s**
##
## ⇒ **The lever had no authority over the spread and a large cost in time.** ⚠ **Do not rebuild it
## without re-running the measurement first**: that makes two cohesion mechanisms measured at noise, and
## ***"좀더 배드노스 같이 합쳐져야할듯"*** is still an OPEN request with no working answer.
##
## ⚠⚠ **AND THE SAME PROBE SAYS THE GROUP IS ALREADY TOGETHER**, which outlives every line of the rule:
## **89% of bodies have another within one tile**, fourteen of them average **1.7–1.9 distinct targets**
## between them, and **78% of samples have the whole group facing one way.** Whatever reads as scattered
## on screen, the formation is not it — **the next place to look is the PICTURE**, and the number
## pointing there is that a body's sprite is **1.23 tiles wide standing on 1-tile centres**, so a dense
## group necessarily overlaps into one mass.
##
## ⚠ **A NAMING RULE THE COLUMN CONSTANT CARRIED, and it governs every table in this file.** It was
## `_PACK_COL_TILES` and deliberately never `_PACK_COL_RADIUS`: `net_draw_leaf`'s pixel sweep reads every
## file under `src/` outside `look.gd`, and `radius` is one of the size-ish suffixes it bites — a column
## constant wearing that word reads as a presentation literal in a rules file. **The distance was in
## TILES.**
##
## ⚠ **The enemy side has no pack behaviour at all and never had one.** If 무리사냥 comes back it comes
## back on the ENEMY scan in `battle.gd` first; **a table alone would be dead the day it is typed**,
## which is precisely what this block is the record of.


## --- 종 고유 상태이상 / THE SPECIES-STATUS TABLE: DELETED 2026-08-27 ------------------------------
## `SPECIES_STATUS`, its four column constants and `species_status_of` are gone, and so is the arm of
## `Battle._apply_statuses` that read them. The table held ONE row — `[CROW, Status.BLEED, 0.5, 2.0]` —
## and `_apply_statuses` looked it up with `army.type_id[from_id]`, which is the PLAYER's roster: the
## only player row is SWORDSMAN and **the crow became an ENEMY with the side swap (2026-08-26)**.
## ⇒ **`species_status_of` returned `{}` on every blow struck in the game.**
##
## ⚠⚠ **출혈 AND 감속 ARE ALIVE AND NOTHING HERE TOUCHES THEM.** They come off EQUIPMENT TAGS
## (`TAG_STATUS_TIERS`, two live rows), which is a different path entirely. **Only the SPECIES-innate
## arm died**, and `Status`, `STATUS_KIND`, `_put_status` and `_phase_status` are all untouched.
##
## ⚠⚠ **THE DEFECT THIS TABLE CAUSED OUTLIVES IT, BECAUSE THE NEXT SECOND SOURCE WILL CAUSE IT AGAIN.**
## A blow had two sources of one status — the equipment tier and the attacker's own species — and they
## could name the SAME status. Written the naive way, one write after the other, whichever landed LAST
## stood: a 까마귀 wearing a full bleed set (tier 2, **1.5 a second for 3 s**) bit for its own passive's
## **0.5 / 2.0**, which is **22% of what the identical set gives a 늑대**. **The crow was PENALISED by
## its own passive** — and by equipment fitted anywhere on the board, since `tag_count` sums the whole
## horde. ⇒ **`stronger_status_tier` is the fix and it is KEPT.** Every source of one blow is resolved
## before anything is written, and **any second source that ever arrives goes through it, not around
## it.**
##
## ⚠⚠ **AND IT SILENTLY DISARMED A CHECK — THIS IS THE FAKE GREEN, AND IT WAS MEASURED.**
## `net_battle`'s 「상태는 광역의 형제에게도 실린다」 was written with the CROW as the shooter, so
## deleting the splash arm of the equipment-tag loop **did not redden it**: this table re-supplied
## identical values through the other door and the named mutation did not bite. The fix was to make the
## shooter the BEAR, which splashes and carries no species row of its own. ⇒ **A fixture whose subject
## has a SECOND source of the thing being measured measures nothing.**
##
## ⚠ **What the table was for, if it ever comes back**: 2026-08-24, the user — 「독부터 해서 정말 많이
## 있을듯」. It was a second SOURCE and never a second mechanism: it wrote through the same `_put_status`,
## with the same overwrite rule and the same generic `_phase_status` walk, so a species row and a tag
## tier were indistinguishable by the time they reached the clock. **That shape is the one to rebuild** —

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
# --- The boat: DELETED 2026-08-29 -----------------------------------------------------------------
## ⚠⚠ **`BOAT_SPEED` and `ROUTE_SMOOTH_SAMPLE_TILES` stood here and both are gone** with the crossing
## itself. **The beasts get boats later and they get built then** — the user, 2026-08-29.
##
##  · **Speed was 4.0 tiles a second**, and it is a RULE and not a feel value: it sets the crossing
##    time, which is the only thing between the start and the first blow. A departure interval is this
##    number's sibling, and a brake would be built from it.
##  · **The route smoother sampled every 0.25 tiles, and that bound is not arbitrary.** Tile centres
##    are on integers, so a tile spans ±0.5 around its centre: sample any coarser and two consecutive
##    samples can round to tiles two apart, and a segment gets declared clear over a tile nobody
##    looked at. **0.25 is that bound halved.**



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
