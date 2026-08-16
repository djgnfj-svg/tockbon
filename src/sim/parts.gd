class_name Parts
extends RefCounted
## One row per part. This table IS the content of the game; everything else is machinery around it.
## Parallel arrays rather than dictionaries for the same reason the swarm is flat: a part that exists in
## two places diverges the day one is tuned.
##
## **Every column here exists because something reads it.** Four of them were added after review found the
## code reading columns the table did not have — an effect with no data source becomes `if part == X:`,
## and that is the sentence "this table is the content of the game" dying.
##
## Nothing here is a Node and nothing reads `look.gd`. A part's own numbers live here and its PIXELS live
## in `look.gd`; the seam is that this file never names a colour and `look.gd` never names a range.

enum Slot { HEAD, TORSO, BACK, FORELIMBS, HINDLIMBS, TAIL, EYES, GUT, BONE, HIDE, LUNG }
enum Kind { PASSIVE, ACTIVE }
## ⚠ **BOSS stays at 2 and every new species is appended after the tail.** Twelve `SPECIES_*` tables in
## `rules.gd` plus `SPECIES_NAME` below plus `FieldView.SPECIES_COLOR` are indexed by this enum — fourteen
## parallel arrays — so renumbering any member silently re-points all fourteen at once; growing the tail is
## the only edit that cannot do that. **Nothing may read `Species.size()` as the species count**: `NONE` is
## a member of this enum and is not a species, so the count is `size() - 1` and it is 11.
## `net_field._c31_every_species_table_is_eleven_rows` pins every member's number as a literal.
enum Species { NONE = -1, CROW = 0, HORSE = 1, BOSS = 2,
	SQUIRREL = 3, ELEPHANT = 4, CHEETAH = 5, LION = 6,
	MOUSE = 7, RABBIT = 8, DOG = 9, BOAR = 10 }
enum { BITE = 0, DASH = 1, HORSE_LEGS = 2, HORSE_MANE = 3, HORSE_LUNG = 4,
	CROW_WING = 5, CROW_BEAK = 6, CROW_FOOT = 7 }

## Indexed by `Species`. Read by the run's snapshot for the ending screen's 먹은 종 line, and that is its
## only reader — the snapshot walks `World.species_eaten` through it, so a member added to `Species`
## without a name added here prints `?` rather than reading the row next door.
##
## ⚠ **This is NOT a column of the part table.** It is one entry per REAL species — eleven — which is
## `Species.size() - 1`, because `NONE` is a member of that enum and is not a species. **This comment said
## "`Species.size()` long" for two plans and it was already false by one.** `net_parts` walks every array
## constant this file declares and asserts each is `ROWS` (8) long; this one is skipped there by name, so
## `net_field._c31_every_species_table_is_eleven_rows` is the only thing that measures its length at all.
##
## **Eight species were added after the crow and the horse and none of them drops a part.** They exist to
## fill the field — the pools are still crow-only plus 말 다리 (`DROPS`), so eating a lion opens no card.
## Splitting "is on the field" from "drops a part" is what makes a species a row edit; see
## `august-scope-two-species`.
const SPECIES_NAME := ["까마귀", "말", "보스", "다람쥐", "코끼리", "치타", "사자",
	"들쥐", "토끼", "들개", "멧돼지"]

## **Eleven is `Slot.size()` and nowhere else.** Two view files each held the literal as a `SLOT_COUNT`
## const; both are deleted and each now asks `Slot.size()` through its own `_slot_count()`, and
## `Run._snapshot()` sizes `RunResult.body_slots` from the same enum — or the day a twelfth slot lands two
## screens keep drawing eleven squares with every check green. There is deliberately no `const SLOT_COUNT`
## beside the enum — that would be the second copy this sentence exists to prevent.

## ⚠ **Plain `Array`, NOT `PackedInt32Array`, and that is forced.** Measured on 4.7.1 with a probe script:
## `const X := PackedInt32Array([1, 2, 3])` is a **parse error** — "isn't a constant expression" — while a
## plain array literal is fine, nests fine, and even folds a `deg_to_rad()` call inside it. The plan doc's
## table is written in the packed form and does not compile as written. A `const` Array is read-only in
## 4.x, so immutability survives the change; what does not survive is element typing, which is why every
## read site casts (`int(...)`, `float(...)`) rather than leaning on inference.
##
## Rows are indexed by the enum above and **every array is the same length**; a net asserts that against
## the literal 8, because a short row here is an index error at a level-up and comparing the arrays only
## to each other passes on a table where all of them are short.
##
## **The crow gives three parts** (user: 까마귀 부품 날개 부리 발 3개로 일단 지정), and what each is for:
##
## - **까마귀 날개** — a wide slow swipe, the clone's default weapon, and the reason the corpse roll can
##   produce an `ARC` at all. With every droppable part passive the roll's ARC branch is dead code in play.
## - **까마귀 부리** — the aimed opposite: shorter, narrower, faster, and the most force of the three. It
##   is the first card that competes with 물기 for a click key, which is what makes a binding a decision.
## - **까마귀 발** — a passive that gives force and hp, and **the only part in either pool that shares a
##   square with another** (`HINDLIMBS`, with 말 다리). It is what makes "did you refuse a card because of
##   what it would push out" reachable at all.
const NAME := ["물기", "짧은 숨", "말 다리", "말 갈기", "말 폐활량",
	"까마귀 날개", "까마귀 부리", "까마귀 발"]
const SPECIES := [-1, -1, 1, 1, 1, 0, 0, 0]
const SLOTS := [[],                                         ## BITE and DASH occupy nothing — see below
	[],
	[Slot.HINDLIMBS],
	[Slot.TORSO],
	[Slot.LUNG],
	[Slot.BACK],
	[Slot.HEAD],
	[Slot.HINDLIMBS]]                                       ## the one square two parts share
const KIND := [Kind.ACTIVE, Kind.ACTIVE, Kind.ACTIVE, Kind.PASSIVE, Kind.PASSIVE,
	Kind.ACTIVE, Kind.ACTIVE, Kind.PASSIVE]
const FORCE := [0, 0, 5, 5, 0, 3, 4, 2]                     ## ×10 scale — a +1 part is invisible now
## The mane's whole effect, and 까마귀 발's half. **Read by Body.** The mane is 5, not 1: the host's HP
## went ×10 and a +1 against a 30-HP host taking 10 a hit is not the event a part's whole effect should be.
## 5 is half a crow hit — deliberately not a whole one, so a mane plus two levels is what buys the hit back.
const HP := [0, 0, 0, 5, 0, 0, 0, 3]
const MOVEMENT := [0, 1, 1, 0, 0, 0, 0, 0]                  ## what `space` will accept
const COOLDOWN := [0.5, 0.8, 0.0, 0.0, 0.0, 1.4, 0.6, 0.0]
const BREATH := [0.0, 0.0, 0.0, 0.0, 2.5, 0.0, 0.0, 0.0]    ## added to BREATH_MAX while worn

## 1 = this part is in the game's pools; 0 = it is a row and nothing else. Read in exactly **two** places —
## the card roll and the corpse's part roll — and it is what keeps 말 갈기 and 말 폐활량 out of both
## without deleting rows (user: 말은 다리만 있음 지금은).
##
## ⚠ **It is a column, not a second list.** A hand-kept array of droppable ids beside the table is what
## diverges the day a row is added; this travels with its row.
##
## What it produces: a crow corpse can roll **three** parts, a horse corpse exactly **one** (말 다리), a
## boss corpse **none**. The pool therefore opens off the CROW — the common creature, standing still,
## killable in the first minute — rather than off a horse nothing can catch.
const DROPS := [0, 0, 1, 0, 0, 1, 1, 1]

## HOW AN ACTIVE REACHES SOMETHING IS PER PART (user, 2026-08-14). There is no single combat verb to
## design; each active carries its own shape, and the player binds whichever one to whichever key.
##
## ⚠ **An enum with room to grow, not a switch over two cases.** A projectile and a radius are the two
## shapes already named in the design; adding one must be a row here, never a branch in `Body.fire()`.
enum Shape { NONE, ARC, SELF }   ## ARC: a swing in the facing. SELF: changes the wearer, hits nothing
const SHAPE := [Shape.ARC, Shape.SELF, Shape.SELF, Shape.NONE, Shape.NONE,
	Shape.ARC, Shape.ARC, Shape.NONE]

## px from the body's CENTRE, not its edge, and radians centred on the facing.
##
## ⚠ **70.0 and deg_to_rad(70) are plan 2's shipped numbers moved out of `rules.gd`, not re-chosen here.**
## An earlier draft of the plan retyped them as 34 and 1.6, and the plan doc's own table still carries the
## rounded `1.22`. Writing the rounding down is a silent retune of the one attack the player has had since
## plan 2, wearing a refactor's clothes: both sides of the sim read whatever is here, so nothing in the
## round can see the difference — only plan 2's tested value can. `COOLDOWN[BITE]` 0.5 moved the same way.
##
## The crow's two actives are the two ends of one axis: 날개 is 55px over 100°, slow; 부리 is 40px over
## 40°, fast. Neither reaches as far as 물기's 70 — the part you are handed stays the longest arm.
const RANGE := [70.0, 0.0, 0.0, 0.0, 0.0, 55.0, 40.0, 0.0]
const ARC := [deg_to_rad(70.0), 0.0, 0.0, 0.0, 0.0, deg_to_rad(100.0), deg_to_rad(40.0), 0.0]

## SELF actives, both of them: a speed multiplier and how long it lasts. `SUSTAINED` means "while held,
## draining breath" — otherwise `SELF_TIME` is a one-shot burst on its own cooldown.
##
## ⚠ `SELF_MUL[DASH]` is **2.8 = the deleted `Rules.DASH_SPEED` 560 / `Rules.HOST_SPEED` 200**. The move
## turned an absolute speed into a relative one, so retuning `HOST_SPEED` now retunes the dash with it.
## That is the intended reading — a burst is "much faster than I walk" — but it is a behaviour change and
## nobody had written the division down.
##
## ⚠ `SELF_MUL[HORSE_LEGS]` is **1.1, not 1.8**. 1.8 × `Rules.HOST_SPEED` 200 = 360, above the horse's own
## 230 — the stage's central mechanic (the horse is herded because nothing sustained catches it) deleted by
## the stage's own first reward. 1.1 = 220: still worth holding for travel and for kiting the boss, and
## still under the horse. The chain it has to stay inside is in `rules.gd`'s header.
const SELF_MUL := [0.0, 2.8, 1.1, 0.0, 0.0, 0.0, 0.0, 0.0]
const SELF_TIME := [0.0, 0.16, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const SUSTAINED := [0, 0, 1, 0, 0, 0, 0, 0]
