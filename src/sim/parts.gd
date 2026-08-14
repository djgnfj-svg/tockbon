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
enum Species { NONE = -1, CROW = 0, HORSE = 1, BOSS = 2 }   ## plan 4 reads this; it does not redeclare it
enum { BITE = 0, DASH = 1, HORSE_LEGS = 2, HORSE_MANE = 3, HORSE_LUNG = 4 }

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
## the literal 5, because a short row here is an index error at a level-up and comparing the arrays only
## to each other passes on a table where all of them are short.
const NAME := ["물기", "짧은 숨", "말 다리", "말 갈기", "말 폐활량"]
const SPECIES := [-1, -1, 1, 1, 1]
const SLOTS := [[],                                         ## BITE and DASH occupy nothing — see below
	[],
	[Slot.HINDLIMBS],
	[Slot.TORSO],
	[Slot.LUNG]]
const KIND := [Kind.ACTIVE, Kind.ACTIVE, Kind.ACTIVE, Kind.PASSIVE, Kind.PASSIVE]
const FORCE := [0, 0, 5, 5, 0]                              ## ×10 scale — a +1 part is invisible now
const HP := [0, 0, 0, 1, 0]                                 ## the mane's whole effect. **Read by Body**
const MOVEMENT := [0, 1, 1, 0, 0]                           ## what `space` will accept
const COOLDOWN := [0.5, 0.8, 0.0, 0.0, 0.0]
const BREATH := [0.0, 0.0, 0.0, 0.0, 2.5]                   ## added to BREATH_MAX while worn

## HOW AN ACTIVE REACHES SOMETHING IS PER PART (user, 2026-08-14). There is no single combat verb to
## design; each active carries its own shape, and the player binds whichever one to whichever key.
##
## ⚠ **An enum with room to grow, not a switch over two cases.** A projectile and a radius are the two
## shapes already named in the design; adding one must be a row here, never a branch in `Body.fire()`.
enum Shape { NONE, ARC, SELF }   ## ARC: a swing in the facing. SELF: changes the wearer, hits nothing
const SHAPE := [Shape.ARC, Shape.SELF, Shape.SELF, Shape.NONE, Shape.NONE]

## px from the body's CENTRE, not its edge, and radians centred on the facing.
##
## ⚠ **70.0 and deg_to_rad(70) are plan 2's shipped numbers moved out of `rules.gd`, not re-chosen here.**
## An earlier draft of the plan retyped them as 34 and 1.6, and the plan doc's own table still carries the
## rounded `1.22`. Writing the rounding down is a silent retune of the one attack the player has had since
## plan 2, wearing a refactor's clothes: both sides of the sim read whatever is here, so nothing in the
## round can see the difference — only plan 2's tested value can. `COOLDOWN[BITE]` 0.5 moved the same way.
const RANGE := [70.0, 0.0, 0.0, 0.0, 0.0]
const ARC := [deg_to_rad(70.0), 0.0, 0.0, 0.0, 0.0]

## SELF actives, both of them: a speed multiplier and how long it lasts. `SUSTAINED` means "while held,
## draining breath" — otherwise `SELF_TIME` is a one-shot burst on its own cooldown.
##
## ⚠ `SELF_MUL[DASH]` is **2.8 = the deleted `Rules.DASH_SPEED` 560 / `Rules.HOST_SPEED` 200**. The move
## turned an absolute speed into a relative one, so retuning `HOST_SPEED` now retunes the dash with it.
## That is the intended reading — a burst is "much faster than I walk" — but it is a behaviour change and
## nobody had written the division down.
const SELF_MUL := [0.0, 2.8, 1.8, 0.0, 0.0]
const SELF_TIME := [0.0, 0.16, 0.0, 0.0, 0.0]
const SUSTAINED := [0, 0, 1, 0, 0]
