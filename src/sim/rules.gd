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
# ⚠⚠ **`CELL_MELEE` and `CELL_RANGED` are GONE, renamed to `WOLF` and `CROW`.** `GLOSSARY.md` marked
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
## ⚠⚠ **`BEAR := 2` · `CROW := 3` · `LION := 4` STOOD HERE AND ALL THREE ARE DELETED** (2026-08-31,
## the user: 「곰까마귀사자 관련코드제거 아직 늑대만있음」 — *"take out the bear, crow and lion code —
## there is only the wolf"*). **Nothing spawned them.** The shipped island's own letters are `H`, `~`
## and `.` only, the boats carry 늑대, and every one of the three had no attack art, no walk art and
## no death art. **They were four numbers in a table and two pictures each.**
## ⚠ **The survivors keep their indices**, because the three that left were the last three: SWORDSMAN
## is still 0 and WOLF is still 1. **Nothing indexed by a saved type id moved.**
## ⚠⚠ **7 주 is 「짐승 종류를 늘린다」 and this does not make that week bigger.** A species is a row in
## `UNITS` plus a row in `Look.BEAST_TEX`; **what a new beast actually costs is the DRAWING**, and none
## of the three had one. **Adding a row back is the cheap half either way.**

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
## **How far past its own range column every body can reach, and it is the most expensive number this
## file has ever held.** ⚠⚠ **RESTORED 2026-08-30 at exactly 1.75** — it was deleted 2026-08-29 with
## the fight and the fight is being rebuilt. **Nothing about it was re-derived and nothing may be.**
##
## **The window is 「above the stair diagonal, below the flat two-조각 orthogonal」.** A body on a stair
## (level 1) reaching an enemy on the plateau beside it (level 2) is inside 1.5 ORTHOGONALLY and outside
## it DIAGONALLY. Measured in play with the attacker pinned on the stairs: **orthogonal, three hits and
## a kill; diagonal, ZERO hits and ZERO damage.** A stair is one 조각 wide, so the horde behind the body
## that cannot hit is stuck in the doorway. **26 of 162 fights were lost that way, and in 24 of them
## every surviving enemy stood on exactly those diagonal 조각.**
##
## ⚠⚠ **The numbers in that paragraph were measured while a notch was a whole 조각, and a notch is half
## a 조각 now** (2026-08-27, see `TIER_RISE_TILES`). **The defect and the fix are unchanged; only the
## margins moved.** Today the stair diagonal is `sqrt(2 + 0.25)` = **1.5** and the flat two-조각
## orthogonal is **2.0**, so the window is `(1.5, 2.0)` and **1.75 sits dead centre, +0.25 above and
## -0.25 below.** Both bounds are exact (heights are exact multiples of `TIER_STEP_TILES`) and `EPS` is
## 1e-4.
##
## ⚠⚠ **IT IS NOT A MELEE-ONLY CHANGE AND NO VALUE COULD MAKE IT ONE.** This bonus is added to EVERY
## species' range, so raising it moves every species' reach. Swept over every 조각-aligned pair at every
## level difference: at 1.75 exactly **two** species gained a flat-ground distance —
## **다람쥐 3.50 -> 3.75 gains 3.606** and **까마귀 5.50 -> 5.75 gains 5.657** — and nothing else moved.
## **There is no way to avoid those two**: 다람쥐's next distance enters at a bonus of 1.606, which is
## BELOW the 1.732 melee needs, so any value that fixes the stair also gives it that 조각. ⚠ **1.85 was
## the other candidate** — more comfortable margins, but it also handed 창병 the 2-조각 diagonal (2.828)
## and 까마귀 a second 조각. **1.75 is the smallest drift that closes the defect.**
##
## ⚠ **Do not retune it to make a plateau safe.** The user's line is 「2층은 안전한 땅이고 그 안전을
## 값으로 산다」, and the reach is shared by every body and every weapon — **a storey-aware refusal
## belongs where the height is already known**, not in this number.
const REACH_BONUS := 1.75

## Compare reach with this epsilon. A diagonal is exactly sqrt(2); a bare `<=` on that boundary is
## a coin flip that changes which units can fight from frame to frame.
const EPS := 1e-4

## The detect column's answer for a body that has no detection radius at all.
## ⚠⚠ **-1.0 AND NEVER 0.0.** A caller that reads a missing radius as zero freezes every body that has
## one. **It outlived `detect_of`** (deleted 2026-08-29 with the fight) because `UNITS` still carries
## the column, and a table row cannot hold a name that is not declared.
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

## --- How many bodies stand on one 조각 -------------------------------------------------------------
## ⚠⚠ **THE 「ONE BODY PER 조각」 RULE THE WHOLE FIGHT WAS BUILT ON IS GONE** (2026-08-30, the user at
## the screen: bodies should be bigger, and **about nine of them should fit in one 칸**). A 칸 is the
## 2x2 block of four 조각 — see the glossary, where the two words are the trap this line turns on — so
## nine to a 칸 is more than two per 조각, and a reservation table holding one id per 조각 could not
## express it.
##
## **3 is the smallest uniform per-조각 cap that admits the user's figure**: at 2 a 블록 holds eight,
## which is fewer than was asked for.
##
## ⚠⚠ **THE OVERSHOOT TO TWELVE IS CLOSED BY `BLOCK_CAPACITY` BELOW** (2026-08-31, the user:
## 「nine soldiers is the maximum, I think」). This number is still what one 조각 admits, and it is
## deliberately NOT nine-over-four: no uniform per-조각 cap divides nine into four 조각, so the
## ceiling that is actually nine has to be stated one unit up. **Both hold at once** — a 조각 takes
## three and the 블록 takes nine, so the tenth body is refused even when the 조각 it wants has room.
##
## ⚠⚠ **THE PLACE A BODY IS DRAWN INSIDE ITS 칸 IS THE SIM'S TO HAND OUT AND THE VIEW'S TO READ.**
## Three bodies handed the same 조각 centre draw as one body, so `Grid` hands each body a SEAT of its
## 칸 (`Grid.block_seats`, ticket 03-17) and the view lays it on `Look.seat_point_tiles`' lattice.
## Until 2026-09-02 the same job was done by the slot index and a ring inside one 조각, and the user
## rejected that picture by eye. **The sim owns the seat and the drawing owns the geometry.**
##
## ⚠ **Raising this does not widen a doorway by itself.** A neck is measured in 조각, and the queue at
## one is now three deep per 조각 instead of one.
const TILE_CAPACITY := 3

## --- How many bodies stand on one 블록 (칸) ---------------------------------------------------------
## ⚠⚠ **NINE, AND IT IS A CEILING RATHER THAN A TARGET** (2026-08-31, the user: 「nine soldiers is
## the maximum, I think」). `TILE_CAPACITY` alone admitted twelve, and twelve is where the bodies
## standing on one 칸 stop reading as nine men and start reading as one shape.
##
## ⚠⚠ **THE 블록 IS CALLED BOTH 「블록」 AND 「칸」** (2026-08-31, the user: 「let both 칸 and
## 블록 work — we are going to do it that way anyway」). 「칸」 was retired on 2026-08-29 and it is
## live again as a second name for the same thing; the glossary carries the pair.
##
## ⚠⚠ **THE GAME CODE HAD NO NAME FOR A 블록 UNTIL THIS LINE.** It was Blender's unit only —
## `island_build.py`'s `PIECES`, where **`S = 2.0` and the outline may only turn on even tiles**. That
## is exactly what makes `Grid.block_of` a shift rather than a lookup: a 블록 is the four 조각 whose
## coordinates share a top-left even pair, and nothing has to be exported to say so.
##
## ⚠ **Nine over four 조각 is 2.25, so the split is never even.** Which 조각 of a 블록 holds three
## and which holds two falls out of arrival order, and **that is a fact about the picture, not only
## about the table** — where the nine actually stand is `Grid.block_seats`' and `Look.seat_point_tiles`'
## business (ticket 03-17), and the split no longer shows: the nine seats are the 칸's, not a 조각's.
const BLOCK_TILES := 2
const BLOCK_CAPACITY := 9

## --- What one step of a walk costs -----------------------------------------------------------------
## ⚠⚠ **A DIAGONAL USED TO BE FREE, AND THAT IS WHY A STRAIGHT WALK ARCED TO THE TOP OF THE BOARD**
## (티켓 37; the user, 2026-08-29, watching a body cross open ground). The flood added **1** to all eight
## neighbours, so a straight line and a detour to the far edge of the island were the SAME cost — every
## equal-cost arc was on the table, and the tie went to whichever neighbour the offset table listed first.
##
## ⚠ **They live here and not in `Grid` because they change which 조각 a body stands on.** `Grid` keeps the
## board legend and the unreachable sentinel, which are facts about the board rather than about the rules.
##
## ⚠ **Integers, so no float ever enters the field.** `14/10` is 1.4 against a true `sqrt(2)` of 1.41421 —
## a 1% error, and the standard integer octile pair. A float field would put a rounding boundary in the
## middle of every tie, which is the same argument `TIER_RISE_TILES` makes about heights one rule up.
##
## ⚠ **The cheapest an 8-connected walk between two 조각 can cost is therefore
## `ORTHO * max(|dx|,|dy|) + (DIAG - ORTHO) * min(|dx|,|dy|)`** — such a walk takes exactly `min` diagonal
## steps and the rest orthogonal. **Every literal in the walking nets is derived from that identity**
## rather than read off a run.
const STEP_COST_ORTHO := 10
const STEP_COST_DIAG := 14

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
	# ⚠⚠ **THE PERIOD WENT 1.2 → 2.4 AND THE DAMAGE 2.5 → 5.0 IN THE SAME EDIT** (2026-08-31, the user:
	# 「애니메이션을 좀더 늘려줘 좀더 공격 텀이 있는 느낌?」 — *"stretch the animation out, more of a
	# sense of an interval between attacks"*). **The swing became eight frames, 0.96 s**, and at a 1.2 s
	# period that leaves 0.24 s of gap — a body that is swinging almost continuously, which is the
	# opposite of what was asked. **A longer motion needs a longer wait or it is not a motion, it is a
	# state.**
	# ⚠⚠ **DAMAGE PER SECOND IS UNCHANGED AND THAT IS DELIBERATE**: 2.5/1.2 and 5.0/2.4 are both
	# 2.083. **Who wins is exactly what it was**; what changed is that a blow is now one event worth
	# looking at instead of a stream. ⇒ **A fight that gets shorter or longer after this is a bug**,
	# not a balance change.
	# ⚠ **2.4 divides cleanly by 2, 3 and 6**, which `SPEED_STEPS` requires of every period here.
	["SWORDSMAN", 18.0, 5.0, 2.4, 0.0, 0.0, 3.2, NO_DETECT, Side.PLAYER, "검사"],
	# ⚠⚠ **The beasts crossed sides and their numbers did NOT move.** The wolf is the one row a whole
	# run has been played on; re-tuning it in the same edit that flips its side would make a later
	# difference unattributable. **They gained a detect radius** — an enemy has to notice something.
	# ⚠⚠ **1.0 → 2.0 AND 2.0 → 4.0, the same trade the 검사 above took** and for the same reason. DPS
	# is 2.0 either way.
	# ⚠⚠ **THREE ROWS STOOD UNDER THIS ONE AND THEY ARE DELETED** (2026-08-31) — see the tombstone
	# where `BEAR` was. **Their numbers, in case one comes back**: 곰 30/3.5/1.8/0/1.5/2.8/6 ·
	# 까마귀 8/1.5/1.0/**4 사거리**/1.0/4.0/12 · 사자 140/4.0/1.5/0/1.5/2.5/**2 탐지**.
	# ⚠ **The 까마귀's 4-tile range and the 사자's 2-tile detect were the only two of their kind on the
	# table**, so the day a ranged beast or a boss is built, those two columns have no other example.
	["WOLF", 14.0, 4.0, 2.0, 0.0, 0.0, 4.0, 6.0, Side.ENEMY, "늑대"],
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


## ⚠⚠ **`hp_of` · `damage_of` · `period_of` · `range_of` ARE BACK** (2026-08-30, 티켓 41's 목~일
## slice) after being deleted with the fight on 2026-08-29. **Their columns never left `UNITS`**, which
## is why restoring them cost four lines: they are the only numbers in this repo that came from PLAYING,
## and the deletion note said so at the time. `name_of`, `area_of` and `detect_of` stay deleted — the
## splash radius and the detection radius have no reader, and a beast walks at the 성채 rather than
## noticing anything.


static func speed_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_SPEED])


## What a body of this row is born with, and what it is healed back to when it stands again.
static func hp_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_HP])


## What one blow takes off.
static func damage_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_DAMAGE])


## Seconds between blows.
static func period_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_PERIOD])


## **Seconds from the start of a swing to the blow landing.** A swing begins the moment a body is
## ready and its target in reach; the damage arrives this long after, and the period counts from the
## START of the swing, not from the landing.
##
## ⚠⚠ **UNTIL 2026-09-02 THERE WAS NO SWING AT ALL** — the blow landed the instant the cooldown ran out,
## and the picture then played its eight-frame swing AFTER the health had already dropped: the victim
## flinched and its bar fell on the striker's FIRST frame, the sword reaching out 0.36 s later. The user
## saw exactly that (「게임 애니메이션하고 코드적 액션이 안맞음」). **This is the sim's half of the fix**:
## the blow lands where the picture's sword is furthest out.
##
## ⚠ **0.4 is 24 sub-steps exactly**, so the landing sub-step does not depend on rounding, and it sits
## on the fourth of the eight attack frames (0.36 s ~ 0.48 s), where `look.gd`'s lunge is at full reach.
## `look.gd` does not read this — a net holds the two together instead, because the sim must not know
## how long a strip is and the picture must not decide when damage happens.
## ⚠ **A body hit during its own swing still lands it.** Cancelling on a hit would stun-lock: the faster
## period would interrupt the slower one every time, and the 검사 would never land a blow on a 늑대.
const SWING_LAND_SEC := 0.4


## The row's own range column, **without the bonus.** Nothing outside `reach_of` should read this: a
## caller that adds `REACH_BONUS` itself is the second copy of the reach rule, and the two drift.
static func range_of(type_id: int) -> float:
	return float(UNITS[type_id][_COL_RANGE])


## **How far this row can actually hit, and the ONE place the bonus is added.** A sword's range column
## is 0, so a swordsman's whole reach is the bonus — see `REACH_BONUS` for what that number cost.
static func reach_of(type_id: int) -> float:
	return range_of(type_id) + REACH_BONUS


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


## What one blow loses against this row. **No body has any defense yet, so every row answers 0.0** — the
## panel (ticket 03-02) prints this stored truth rather than a sample. Not a column of `UNITS`, on purpose:
## a column every row holds at 0 is a number nobody chose, and the day one is chosen it becomes a column.
static func defense_of(_type_id: int) -> float:
	return 0.0


# --- 적성 · 허기 — what a body carries besides its species ----------------------------------------------
## **The five aptitudes, in the panel's order, and the only place the five words live** (ticket 03-02,
## 2026-09-02, the user: 「적성 특성 능력치라 그렇게 해서 나눠서 보이게 해줄래」). `look.gd` reads this at draw
## time, never into a `const` of its own — a second list of the same five words is the shape `TYPE_LABELS`
## took before it rotted. Index `k` here is the `k` of `Army.aptitude_of(i, k)`.
## ⚠ **Nothing in the sim reads an aptitude yet.** The value is stored and shown; what it changes is the
## 2-편 line the map carries. A Korean word here is the same exception the `UNITS` label column carries.
const APTITUDES := ["요리", "제작", "낚시", "채광", "벌목"]
## The top of the scale a body can reach. **Printed on screen as 「요리 2/10」** — the user said
## 「영에서 십이고」, so the scale is what the player reads, not only a bound.
const APTITUDE_MAX := 10
## The top of the roll a body is born with: `Army.recruit` draws each aptitude in `0 .. this`. The session
## put 「태어날 때 0~3 무작위」 to the user and the answer was 「네」. ⚠ Below `APTITUDE_MAX` or a newborn
## could open at the top of a scale it is meant to climb.
const APTITUDE_BORN_MAX := 3
## What a body's 허기 is filled to at birth. **The drain is ticket 05-07's and is not written anywhere yet**;
## today every body holds this number for the whole run, and the panel prints it.
const HUNGER_MAX := 100.0


# --- The telegraph -------------------------------------------------------------------------------
## ⚠ **`LION_WINDUP_SEC` stood here and it is deleted** (2026-08-29). It was 0.6 — how long the heavy
## attack DECLARED itself before landing. **The telegraph is the reason a heavy attack is fair**, and
## the declaration was per-body state the view drew for its whole length rather than a one-frame event.


# --- The run -------------------------------------------------------------------------------------
## A run starts from this identical state every time — no meta, no unlocks, no carry between runs.

## **How many 검사 a run opens with, and every one of them stands on the island at the opening frame.**
##
## ⚠ PLACEHOLDER — the user has not chosen this value (2026-08-30). Judged by playing.
##
## ⚠⚠ **IT IS THE ROSTER *AND* THE NUMBER ON SCREEN, WHICH USED TO BE TWO DIFFERENT NUMBERS.** The
## roster opened with ten and `Run` stood exactly ONE of them, so nine bodies existed, counted, and
## could never be seen. **The 「one」 was 2026-08-27's** 「칸단위 부대는 따로 없음 아직」 — squads did
## not exist and ten bodies would have walked as one lump. 티켓 41 settles the unit as 「몸 하나」, so
## bodies are commanded one at a time and there is nothing left for the split to buy.
const SWORDSMAN_START_COUNT := 4

## **How long a dead 검사 waits before he stands again at the 성채.**
##
## ⚠ PLACEHOLDER — the user has not chosen this value (2026-08-30). Judged by playing.
##
## ⚠⚠ **「죽으면 영영 죽는다」 WAS OVERTURNED 2026-08-30** — the user weighed both and chose revival.
## **Death is a loss of TIME now and not a loss of a body**, so this number is the whole of what dying
## costs, and `Army.alive` stays 1 through it.
const REVIVE_SEC := 20.0

## ⚠⚠ **THE TWENTY-SECOND CLOCK (`MUSTER_PERIOD_SEC`) IS DELETED** (2026-09-02, the user: 「자동 병사 생성
## 지워줘」). The 성채 no longer turns out a 검사 on its own; `Battle.recruit` stands one only when it is
## called, and today nothing in `src/` calls it. **What it costs is still task 05's question.**

## **How many 검사 a run may hold at once — the ceiling on the doorstep.**
##
## 2026-09-01, the user: 「천장 아홉 개」. ⚠ **It was already their word on 2026-08-31** (「병사 아홉 개가
## 최대일 거 같아」) and the builder proposed twelve without reading it back: 「아홉 개로 했었는데 왜 갑자기
## 열둘이 될지 아홉 개」.
##
## ⚠⚠ **IT IS NINE AND SO IS `BLOCK_CAPACITY`, AND THEY ARE DIFFERENT QUESTIONS.** `BLOCK_CAPACITY` is
## how many bodies stand on ONE 블록; this is how many 검사 exist at all. At the ceiling every one of
## them could stand on a single 블록, and **that coincidence is not a rule** — do not write either as
## the other.
const MUSTER_CAP := 9

## Which summon slot the doorstep turns bodies out of.
##
## ⚠⚠ **THE BUILDER PICKED THIS AND THE USER DID NOT.** 티켓 02-09 settles 「이번엔 성채 하나만」 and
## `START_SLOTS` carries exactly one row, so there is nothing to choose between today — and a 성채 that
## picked among slots on its own would be choosing a species nobody asked it to choose. **The day a
## second slot is fielded this is the line that has to be answered rather than defaulted.**
const MUSTER_SLOT := 0

## **What the 성채 can take before the run is lost.**
##
## ⚠ **Chosen by the builder, not by the user and not by play** (2026-08-30). The arithmetic it was
## chosen off: a boat lands `BOAT_CAPACITY` 늑대 at `damage_of(WOLF)` a blow every `period_of(WOLF)`,
## which is 16 a second if every one of them reaches the walls — so this is **fifteen seconds of one
## undefended boat**, and `BOAT_INTERVAL_SEC` is thirty. **A single boat that walks in unopposed must
## not end the run, and two must.** ⚠ It is a literal and not that product: retuning the 늑대 must not
## silently move the 성채's health.
##
## ⚠⚠ **240 -> 120 ON 2026-09-01, BECAUSE THE BOATLOAD HALVED AND THIS NUMBER IS DERIVED FROM IT**
## (the user: 「내려」, choosing to lower it rather than accept 「one boat alone cannot lose you the run」
## as a new rule). **240 was fifteen seconds of one undefended boat at `BOAT_CAPACITY` 8.** At four the
## same arithmetic gave **thirty seconds — exactly `BOAT_INTERVAL_SEC`**, so one boat walking in
## unopposed stopped ending the run and `net_fight` went red on it. **120 restores the fifteen seconds
## the old value was chosen to produce**, so the rule the number exists for survives the hull swap.
##
## ⚠ **It is still a literal and not that product.** The arithmetic above is what CHOSE it, twice now;
## retuning the 늑대 must not silently move the 성채's health. **The day `BOAT_CAPACITY` moves again,
## this is read again by hand.**
const KEEP_MAX_HP := 120.0

# --- The summon slots ------------------------------------------------------------------------------
## 번호키가 드는 칸. **칸은 회차 상태다** (`Army.slots`) — 상수가 아니다.
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
## ⚠⚠ **ONE ROW, ONE SPECIES** (2026-08-25, the user: 「시작할 때 뭐 늑대만 있지 않아?」, then the
## 2026-08-26 side swap, then 티켓 41's 「병종 — 검사 하나」). It was two rows once; there is one body
## in this game and there is one row.
## ⚠ **The count is `SWORDSMAN_START_COUNT` and never a literal here** — it is the number the user is
## going to move after playing, and a second copy of it in this table is the copy that would rot.
const START_SLOTS := [
	[SWORDSMAN, SWORDSMAN_START_COUNT],
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


# --- The beasts' boats -----------------------------------------------------------------------------
## ⚠⚠ **THE BOATS ARE THE BEASTS' NOW, AND NONE OF THIS IS THE OLD PLAYER-SIDE CROSSING COMING BACK.**
## The player placed a boat and spent a body on it until 2026-08-28; **nobody places one any more** —
## the user, 티켓 41: 「아무도 안 놓는다. 배가 스스로 온다」. What `battle.gd`'s deletion block records
## about `send` and `summon` is a record of a gesture, not of these numbers.
##
## ⚠ **The crossing is the whole gap between the island opening and the first blow**, which is why the
## distance and the speed are rules and not presentation: they decide WHEN something arrives.
## The bob, the roll and the deck offsets are the screen's and live in `look.gd`.

## When the first boat of an island is born, in seconds of simulated time. Long enough to see the
## island empty, short enough that the launch itself is on screen.
const BOAT_FIRST_SEC := 5.0
## And every one after it. **「일정하게」** — random timing is a later round's, so this is one number
## and not a band.
const BOAT_INTERVAL_SEC := 30.0
## **How long an emptied hull sits off its beach before it stops being there**, in seconds.
##
## ⚠⚠ **IT REVERSES 「배는 쌓인다」, WHICH WAS A DELIBERATE LINE AND NOT AN OVERSIGHT** (2026-09-01, the
## user: 「the boat should just arrive, sit for a few seconds and then disappear — call it a game-y
## allowance」). **The hull does not sail back out.** It arrives, unloads, waits this long and is gone,
## and the user named the disappearance an allowance rather than a fiction that has to hold up — so
## there is no return leg to write and no fade to shade. **It is a cut.**
##
## ⚠ **Three against thirty is the whole of why it is three**: a boat comes every `BOAT_INTERVAL_SEC`,
## so this is long enough to watch the unloading and still leaves the water clear before the next hull
## is anywhere near the shore. ⚠⚠ **Two hulls are no longer on the water at the same time**, which is
## a claim about the SCREEN that was true every round until this one.
const BOAT_LINGER_SEC := 3.0
## 조각 per second.
##
## ⚠⚠ **1.2 IS CHOSEN AND NOT MEASURED, AND 4.0 — WHICH WAS MEASURED — IS DELIBERATELY OVERRIDDEN.**
## The 4.0 in 티켓 41's 「이미 재어 둔 것」 table was measured for the deleted PLAYER-side boat, at a
## framing where the camera did not move. **Nothing about this number has been played yet.**
##
## ⚠⚠ **THE PLAYER IS NOT TOLD A BOAT IS COMING** (2026-08-30, the user: 「안 알아채는 게 맞겠다 ...
## 마우스 돌리다가 보이면 그때 가는 걸로」). There is no arrow and no alarm, so **the crossing has to
## last long enough that a player panning the camera can still find it in time** — that is the whole of
## what this number buys. At `BOAT_START_DIST_TILES` it is 22 조각, so 1.2 makes the crossing **18.3
## seconds**. **The reference is Bad North**, where a boat takes about thirty seconds to arrive and the
## camera is the player's with nothing pointing at it.
const BOAT_SPEED_TILES := 1.2
## How far out to sea a boat is born, measured from the CENTRE of the 조각 it is aimed at.
##
## ⚠⚠ **IT IS OFF SCREEN AT THE OPENING FRAME AND THAT IS NOW THE DESIGN, NOT A DEFECT** (2026-08-30).
## `FieldView.setup` frames the 30 x 26 island at 42.0 x 36.75 조각 of visible ground — about 6 조각 of
## sea on a side — so a hull born 24 조각 out is outside it. **The camera was pulled back to fix that
## and the pull-back was reverted**, because the user cut the arrow and the alarm: 「안 알아채는 게
## 맞겠다 ... 마우스 돌리다가 보이면 그때 가는 걸로」. **Finding the boat is the player's job and the
## camera is how they do it** — see `Look.CAM_ROAM_TILES`, which is what lets them look out there.
## ⚠ **Do not shrink this to bring the boat into the opening frame.** That is the change the design
## just refused, and it also deletes the room the pan exists to cross.
const BOAT_START_DIST_TILES := 24.0
## **How long the hull is, from its origin to its bow, in 조각.** Measured off
## `assets/props/boat_small.glb`: the rim runs x from -1.50 to +1.50 with the origin dead centre, so the
## bow is **1.50 조각** out.
##
## ⚠⚠ **IT IS A RULE AND NOT A PICTURE, BECAUSE IT DECIDES WHERE A BOAT STOPS.** Everything else about
## the hull — its colours, its sail, its bob — is `look.gd`'s. This one number is where the sim has to
## stop it, so it lives with the stopping rule. ⚠ **`net_boats` reads it back off the mesh's own AABB**,
## which is what stops it being a second copy of the model.
##
## ⚠⚠ **2.1 -> 1.5 (2026-09-01), AND THIS TIME IT IS A DIFFERENT MODEL AND NOT A TRIMMED ONE** (the
## user: 「일단 오는 걸 작은 배에 있는 늑대 네 마리로 교체하고 큰 배는 나중으로 미루긴 해야 될 듯」 —
## *"for now swap what arrives to the small boat with four 늑대 on it, and the big boat has to be put
## off till later — it is not used yet"*). The 2.6 -> 2.1 of 2026-08-31 was `boat.glb` shrinking and
## **nothing that carried a wolf moved**; this swaps the hull, so `Look.BOAT_DECK_SLOTS` had to be read
## off the new mesh's own benches rather than trimmed.
## ⚠ **The beam moved too this time** — see below.
## ⚠⚠ **THE STANDOFF SHRANK AGAIN WITH IT.** `BOAT_STANDOFF_TILES` is this plus the beach gap, so every
## boat now stops **0.6 조각 closer to the sand** than the big hull did. That is a change to where the
## 늑대 are put down, not just to how the hull looks, and it is the half of this edit worth watching.
const BOAT_HULL_HALF_TILES := 1.5

## **How wide the hull is at its widest, in 조각.** Measured off `assets/props/boat_small.glb`: the rim
## runs z from -0.75 to +0.75, so the beam is **1.50 조각** and the half-beam is 0.75.
##
## ⚠⚠ **IT EXISTS BECAUSE A BOAT IS NOT A POINT AND FOUR ARRIVALS IN FIVE PROVED IT** (2026-08-30, seen
## on screen at the five worst beaches). A stop that clears the shore along the hull's own centre line
## still puts the forward SHOULDER on the grass: **on a diagonal lying against a straight coast the
## shoulder reaches land before the tip does**, which is why the diagonal approaches overlapped while
## the eight straight ones looked clean. ⚠ **The one that only grazed met an OUTER corner tip-first** —
## the shape of the shore decides which part of the hull arrives first, and only a footprint sees that.
## ⚠ `net_boats` reads it back off the mesh's own box, like the half-length.
##
## ⚠⚠ **2.01 -> 1.50 (2026-09-01) WITH THE HULL SWAP.** The small boat is narrower as well as shorter,
## so the shoulder sweep is 0.255 조각 shallower on each side and a beach that only just admitted the
## big hull on its width now has room to spare. **That widens the beach ring rather than narrowing it**,
## which is the direction that adds landing places rather than losing them.
const BOAT_HULL_BEAM_TILES := 1.5

## **How much open water is left between the hull and the shore, in 조각.**
##
## ⚠⚠ **THE STANDOFF WAS A FLAT 2.0 AND EVERY BOAT PARKED ON THE GRASS** (2026-08-30, measured on the
## running game). 2.0 is LESS than the hull's own half-length, so the bow reached `2.60 - 2.00` =
## **0.60 조각 inland on every beach**, worst on a diagonal approach where about a third of the hull
## stood on the turf. **The number was smaller than the boat.**
##
## ⚠ **A gap and not a bigger flat number.** The standoff has to move whenever the hull's length does,
## and a second magic number would be right until the next export — `BOAT_STANDOFF_TILES` below is the
## sum, and `net_boats` refuses any standoff under the half-length.
const BOAT_BEACH_GAP_TILES := 0.6

## And how far short of the beach 조각 the hull comes to rest. **The user's line is 「배가 서는 자리는
## 해안에서 거리를 두고 ... 배가 가는 게 중요하니까」** — a hull that ends up hugging the shore deletes
## the crossing, which is the thing worth watching.
## ⚠ **Derived, so it cannot fall under the boat's own length again.** See the two above.
const BOAT_STANDOFF_TILES := BOAT_HULL_HALF_TILES + BOAT_BEACH_GAP_TILES
## How many ride one boat. ⚠ **Decided, not tuned.** **Two benches, two each**, and
## `Look.BOAT_DECK_SLOTS` is what puts them on the deck.
##
## ⚠⚠ **EIGHT -> FOUR (2026-09-01), BECAUSE THE HULL WAS SWAPPED AND NOT BECAUSE THE FIGHT WAS TUNED**
## (the user: 「일단 오는 걸 작은 배에 있는 늑대 네 마리로 교체하고 ...」). 티켓 41's 「한 배에 몇 —
## 여덟」 was decided against `boat.glb`, which is no longer what arrives.
## ⚠⚠ **THE CLOCK DID NOT MOVE WITH IT** (2026-09-01, the user taking the recommendation: 「이 위에
## 열여섯 개 물어봤던 거 다 추천대로 좀 해줘」). `BOAT_FIRST_SEC` and `BOAT_INTERVAL_SEC` are
## byte-for-byte what they were, **so that a board that got easier says which of the two made it so.**
## ⚠ **`KEEP_MAX_HP` MOVED WITH IT, 240 -> 120** — the user's call the same day, so that one boat
## ignored still ends the run. **It is the one number that followed the hull; the clock did not.**
## Read that constant, where the whole of it is written down.
const BOAT_CAPACITY := 4

## **Which row of `UNITS` walks off a boat.** ⚠ **Decided, not tuned** (티켓 41: 「무엇이 타고 오나 —
## 늑대. 확정」). It is a constant and not a literal at the landing, because the deck pictures, the
## bodies that step off and the row whose numbers they fight with have to be one species — and three
## sites naming 늑대 separately is how two of them stay 늑대 the day the third stops being.
const BOAT_RIDER_TYPE := WOLF

## **How far round the beach ring the next boat comes, as a fraction of a full turn.**
##
## ⚠⚠ **IT EXISTS SO CONSECUTIVE BOATS ARRIVE ON DIFFERENT SIDES, AND AN ORDER ALONE CANNOT DO THAT.**
## Over a list in 조각-NUMBER order — row by row, north edge first — a stride walks that many rows down
## the same coast and settles onto a handful of fixed beaches: measured on the 92-조각 coast,
## `37 x 5 = 185 = 1 (mod 92)`, so boat *k* and boat *k+5* came to 조각 ONE APART and after two and a
## half minutes it was five permanent beaches. **`Grid.beach_ring` sorts by ANGLE about the island's
## middle**, and only then does a stride mean 「go round to the other side」.
##
## ⚠ **0.42 of a turn is about 151 degrees** — far enough that the player has to turn round, near
## enough to a half turn that it is not the same two beaches alternating.
const BOAT_BEACH_TURN := 0.42


## **The stride to walk `Grid.beach_ring` with, for a ring of this many 조각.**
##
## ⚠⚠ **DERIVED AND NOT WRITTEN DOWN, BECAUSE A WRITTEN ONE IS ONLY EVER RIGHT FOR ONE ISLAND.** The
## stride and the ring's size **must be coprime** or the spread collapses onto `size / gcd` beaches —
## every boat for the rest of the island arriving at one of them, with the crossing, the timing and
## every other check about boats still green. **This has already happened twice**: 37 was chosen
## against a ring of 88, and the ring became 74 (`74 = 2 x 37`, two beaches for a whole island); 31 was
## chosen against 74, and the ring became something else again the moment
## `BOAT_START_DIST_TILES` moved — the ring's size depends on it, see `Grid.beach_ring`.
##
## ⚠ **`BOAT_BEACH_TURN` reproduces both hand-picked values and that is what fixes it at 0.42**:
## `round(88 * 0.42)` is **37** and `round(74 * 0.42)` is **31**. The fraction was chosen to, and
## `net_boats` pins both.
##
## ⚠ **The search walks outward from that target, PLUS before MINUS**, so two runs from identical state
## never disagree. It always terminates: `gcd(1, n)` is 1 for every n, so 1 is always reachable.
##
## ⚠⚠ **RINGS OF 3, 4 AND 6 COLLAPSE TO `size - 1`, WHICH IS -1 AND SENDS THE NEXT BOAT ONE BEACH
## BACKWARDS** — the adjacency this whole constant exists to prevent. **It is written down and NOT coded
## around.** Swept exhaustively over sizes 0..2000: every other size is coprime, in range, and
## terminates; those three are the only ones, and **this island cannot reach them** — a board with three
## beaches is not a board this game opens. **A special case for an unreachable input is a branch nobody
## can test**, and this repo already carries the argument against those.
## ⚠ 0, 1, 2 and negatives are safe by the callers rather than by luck: `Battle` returns early on an
## empty ring and takes the result modulo the ring's own size.
static func beach_stride_for(ring_size: int) -> int:
	# A ring of one or two has nothing to spread over, and 1 is coprime with both.
	if ring_size <= 2:
		return 1
	var want := int(round(float(ring_size) * BOAT_BEACH_TURN))
	for k in ring_size:
		var plus := want + k
		if plus >= 1 and plus < ring_size and _coprime(plus, ring_size):
			return plus
		# ⚠ `k > 0`, so the target itself is not tried twice — harmless, but it would make the
		# 「plus before minus」 tie-break read as though it had an exception in it.
		var minus := want - k
		if k > 0 and minus >= 1 and minus < ring_size and _coprime(minus, ring_size):
			return minus
	return 1


## Whether `a` and `b` share no factor. **Euclid, and no library call**: GDScript has no `gcd`, and a
## hand-rolled one written at each call site is the second copy this repo keeps paying for.
static func _coprime(a: int, b: int) -> bool:
	var x := absi(a)
	var y := absi(b)
	while y != 0:
		var r := x % y
		x = y
		y = r
	return x == 1
