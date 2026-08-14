class_name Rules
extends RefCounted
## Every simulation constant, in exactly one file. `look.gd` owns the presentation ones and this owns
## the ones that change what happens; a constant that lives in two places diverges the day one is tuned.
##
## **Every number here is a guess.** They are written down so that changing one is a decision with a
## before-and-after. The reasoning for each is in the prototype plan doc (`proto-round-trip`), not here —
## repeating it would be the second copy this file exists to prevent.
##
## The four speeds below are the whole tension of the build and their ORDER is load-bearing:
## HOST_SPEED > CRITTER_SPEED > CLONE_SPEED_SCATTER. The host always escapes; an abandoned clone never
## does. Break the ordering and scattering costs nothing, which is the one thing this prototype measures.
## (The name in this sentence was `PREDATOR_SPEED` for two days after the constant became `CRITTER_SPEED`.)

const FIELD := Vector2(3840.0, 2160.0)

# -- the swarm -----------------------------------------------------
## The array is sized once at POOL and never resized; CLONE_CAP is what play is allowed to reach.
## A cap has to be a number before any performance net can regress against it.
const POOL := 128
const CLONE_CAP := 40

## **Everything was 60% faster than this and the user's first word for it was "too fast".** The ordering is
## what matters, not the magnitudes — the one stated in the file header, not restated here — so all four
## came down together and the tension is untouched.
const HOST_SPEED := 200.0
const CLONE_SPEED_FOLLOW := 215.0
const CLONE_SPEED_SCATTER := 125.0
const CRITTER_SPEED := 165.0

const DASH_SPEED := 560.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.8

## How close to the rendezvous point counts as arrived. Below this a clone stops, so the whole swarm does
## not jitter forever on top of one coordinate.
const ARRIVE_RADIUS := 24.0
const SCATTER_RADIUS := 900.0
## Redirection interval for a scattering clone that can see no food at all.
const WANDER_PERIOD := 1.2

# -- separation ----------------------------------------------------
## Clones do not collide. This is a rendering requirement — sixty bodies at one point read as one dot and
## the screenshot the whole pitch rests on disappears.
const SEPARATION_MIN := 16.0
## A hard iteration cap, not a time budget. The uniform grid degenerates to O(n²) in exactly one
## situation — the rendezvous, when the entire swarm piles onto one point — and that is the game's
## most-pressed key. Bucket order is stable, so which 8 neighbours are seen is deterministic.
const NEIGHBOUR_CAP := 8
const GRID_CELL := 32.0

# -- sensing -------------------------------------------------------
## Food lives in a second grid instance at a much coarser cell, because a 240px query on 32px cells walks
## 289 cells — the sweep would cost more than the naive loop it replaced. Coarse cell, span 1, nine cells.
const FOOD_GRID_CELL := 256.0
## How far a scattered clone can see food. This is its entire intelligence: it walks at the nearest thing
## it can see and understands nothing else — no fleeing, no noticing what is about to eat it.
const SENSE_RADIUS := 240.0
const SENSE_CAP := 12

# -- bodies --------------------------------------------------------
## **These are sim constants, not `look.gd` ones**, and they moved out of `look.gd` for one reason: the
## radius decides who gets absorbed by `V` and what reaches what, so it changes what happens. `src/sim/`
## may not read `look.gd`, and a radius owned there would have had to be copied here to be usable.
## `look.gd` keeps no second copy of either.
const BODY_RADIUS := 14.0
const CLONE_BODY_RADIUS := 8.0
## Where a body made by splitting appears, measured from its PARENT. This was `ABSORB_RADIUS`'s second,
## unrelated job; retuning the great absorption's arrival distance silently moved where every new body
## spawned, with nothing to catch it.
const CLONE_SPAWN_RING := 20.0

# -- eating --------------------------------------------------------
## Eating is automatic on proximity, so the reach has to clear the BODY — at 12px, smaller than
## BODY_RADIUS, food had to be run over dead centre and hunting read as broken. Reported by the user on
## the first play, which is the only instrument that could have found it. Both of these must stay above
## the matching body radius above; `net_force` asserts the pair.
const EAT_RADIUS_HOST := 26.0
const EAT_RADIUS_CLONE := 16.0

## The host's mouth is worth ~2.5× a clone's. This is the ENTIRE reason the host stays in front, and it
## replaces the GDD's 50% tax with a speed — nothing to tune, nothing to explain in the UI.
const EAT_PERIOD_HOST := 0.6
const EAT_PERIOD_CLONE := 1.5
## **The great absorption's arrival distance, and nothing else.** Ordinary contact no longer moves cargo —
## `V` does, at its own radius — so this is read by `Swarm._clear_arrivals()` alone.
const ABSORB_RADIUS := 20.0

# -- force ---------------------------------------------------------
## Force is per body and it is THE number the game compares. `Swarm.force[i]` is STORED, never recomputed:
## derived, halving the host costs nothing because the next frame recomputes it back, the total is not
## conserved, and splitting buys the swarm a free double. Silently.
##
## Ten rather than one because **splitting is the tutorial** — at force 1 the first `F` was a level-up
## away and the opening minute had no act in it.
const FORCE_START := 10
## The whole payout of a level. Cards no longer hand out clones; the swarm grows because `F` was held.
const FORCE_PER_LEVEL := 10
## Held, not tapped, so the split reads as an act rather than a keystroke. Long enough to be one, short
## enough to spam in a fight.
const SPLIT_HOLD_TIME := 0.45
## `V`'s reach, in body radii — 4 × BODY_RADIUS. Wide enough that a rallied swarm goes home in one press,
## tight enough to leave stragglers behind. Written as a multiple so retuning the body retunes the reach.
const ABSORB_RADIUS_BODIES := 4.0

# -- actives -------------------------------------------------------
## The bite is a real front cone, not an animation: five body-widths ahead, and the ANGLE is the skill.
## Two bites a second — faster and the click reads as a stream rather than a hit.
const BITE_RANGE := 70.0
const BITE_ARC := deg_to_rad(70.0)
const BITE_COOLDOWN := 0.5

# -- food ----------------------------------------------------------
## Spots are fixed for the run. Eating one starts its cooldown, so a region actually empties out —
## without local depletion a tight ball beats a wide scatter and the width axis dies.
const FOOD_SPOTS := 500
const FOOD_SPOT_COOLDOWN := 12.0
const FOOD_RESPAWN_PER_SEC := 6.0

# -- critters ------------------------------------------------------
## **They are not predators any more, they are the ecosystem.** Six things walked straight at the player
## from the first second and the user's read was immediate: *this should be something you grow into being
## able to eat*, not something that hunts you on a timer.
##
## So each critter carries a `threat`, and the comparison runs both ways: a swarm smaller than the threat
## is prey and gets chased, a swarm that has outgrown it becomes the hunter and the critter flees. **What
## you ran from ten levels ago is food now** — the GDD's tier reversal, in one number and one comparison,
## with no tiers.
const CRITTER_START := 6
const CRITTER_INTERVAL := 45.0
const CRITTER_MAX := 24
const CRITTER_THREAT_MIN := 1
const CRITTER_THREAT_MAX := 5
## Force needed per point of threat before the swarm flips from prey to hunter.
##
## ⚠ **Force, not body count, and the difference is the whole of `F`.** Counted in bodies, holding `F`
## four times walks one force-10 host into ten force-1 bodies in about two seconds — the total is
## conserved, nothing was earned, and every threat-1 critter flips from hunter to prey for free. That
## contradicts the one sentence the split economy rests on (*splitting buys nothing by itself; what it
## costs is concentration*), and it is invisible to any check that only asserts conservation across a
## split. Read as force, splitting is genuinely neutral.
##
## 20 rather than the 5-per-threat this was in bodies: force opens at `FORCE_START` and a level pays
## `FORCE_PER_LEVEL`, so a point of threat costs two levels' worth and the opening host outranks nothing.
## A guess, expected to move on the first session.
const FORCE_PER_THREAT := 20.0
## Body radius scales with threat, so a dangerous one is visibly bigger before it is close.
const CRITTER_RADIUS_BASE := 13.0
const CRITTER_RADIUS_PER_THREAT := 4.0
## How far a critter notices anything. **Nothing crosses the map to reach you** — outside this it wanders,
## which is the whole difference between an ecosystem and an ambush.
const CRITTER_SENSE := 520.0
## Eating one pays this much per point of threat. The reward for growing into a hunter.
const CRITTER_MEAT := 6.0

## Contact costs the host one hit; one mistake must not be the run.
const HOST_HP := 3
const HOST_HIT_GRACE := 1.0
## Critters enter from outside the camera, never on top of the player.
const CRITTER_SPAWN_MIN_DIST := 900.0

# -- growth --------------------------------------------------------
## A level per this much banked, and the cost RISES: level n costs `LEVEL_COST_BASE * pow(GROWTH, n)`. A
## flat cost at the ×10 force scale hands out a level every few seconds by the midgame. The level pays
## FORCE_PER_LEVEL into the host and nothing else — it does not grow the swarm, `F` does.
##
## It is paid from `banked`, never from `eaten`: a clone that dies far from home costs you the level it
## was carrying, and that is the rule the prototype's confirmed fun rests on.
const LEVEL_COST_BASE := 10.0
const LEVEL_COST_GROWTH := 1.35

# -- the great absorption --------------------------------------------
## On clearing, the whole swarm is pulled home and absorbed — the one time that happens. See
## `Swarm.clear_pull` and `Run._begin_clear()` / `Run._finish_clear()`.
const CLEAR_ABSORB_TIME := 1.2
const CLEAR_ABSORB_PULL := 900.0
