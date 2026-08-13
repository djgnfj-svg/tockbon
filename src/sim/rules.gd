class_name Rules
extends RefCounted
## Every simulation constant, in exactly one file. `look.gd` owns the presentation ones and this owns
## the ones that change what happens; a constant that lives in two places diverges the day one is tuned.
##
## **Every number here is a guess.** They are written down so that changing one is a decision with a
## before-and-after. The reasoning for each is in the prototype plan doc (`proto-round-trip`), not here —
## repeating it would be the second copy this file exists to prevent.
##
## The three speeds below are the whole tension of the build and their ORDER is load-bearing:
## HOST_SPEED > PREDATOR_SPEED > CLONE_SPEED_SCATTER. The host always escapes; an abandoned clone never
## does. Break the ordering and scattering costs nothing, which is the one thing this prototype measures.

const FIELD := Vector2(3840.0, 2160.0)

# -- the swarm -----------------------------------------------------
## The array is sized once at POOL and never resized; CLONE_CAP is what play is allowed to reach.
## A cap has to be a number before any performance net can regress against it.
const POOL := 128
const CLONE_CAP := 40

## **Everything was 60% faster than this and the user's first word for it was "too fast".** The ordering is
## what matters, not the magnitudes — host > critter > scattered clone — so all four came down together
## and the tension is untouched.
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
const SEPARATION_PUSH := 8.0
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

# -- eating --------------------------------------------------------
## Eating is automatic on proximity, so the reach has to clear the BODY — at 12px, smaller than the host's
## own 14px radius, food had to be run over dead centre and hunting read as broken. Reported by the user
## on the first play, which is the only instrument that could have found it.
const EAT_RADIUS_HOST := 26.0
const EAT_RADIUS_CLONE := 16.0

## The swarm the run opens with. **Zero was wrong**: the two swarm commands are the entire experiment and
## with no clones to obey them the first minute is one square eating alone, so nothing under test is even
## on screen. Six is enough to see a scatter and a rendezvous immediately.
const START_CLONES := 6
## The host's mouth is worth ~2.5× a clone's. This is the ENTIRE reason the host stays in front, and it
## replaces the GDD's 50% tax with a speed — nothing to tune, nothing to explain in the UI.
const EAT_PERIOD_HOST := 0.6
const EAT_PERIOD_CLONE := 1.5
## Touching the host hands the cargo over. The clone empties; it does not die.
const ABSORB_RADIUS := 20.0

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
## Clones needed per point of threat before the swarm flips from prey to hunter.
const SWARM_PER_THREAT := 5.0
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
## +1 clone per this much banked, automatic, spending nothing. A timed split would make the swarm's size
## independent of play, and then recall discipline has no consequence — which is the thing under test.
const SPLIT_PER_BANKED := 10.0

# -- the great absorption --------------------------------------------
## On clearing, the whole swarm is pulled home and absorbed — the one time that happens. See
## `Swarm.clear_pull` and `Run._begin_clear()` / `Run._finish_clear()`.
const CLEAR_ABSORB_TIME := 1.2
const CLEAR_ABSORB_PULL := 900.0
