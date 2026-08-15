class_name Rules
extends RefCounted
## Every simulation constant, in exactly one file. `look.gd` owns the presentation ones and this owns
## the ones that change what happens; a constant that lives in two places diverges the day one is tuned.
##
## **Every number here is a guess.** They are written down so that changing one is a decision with a
## before-and-after. The reasoning for each is in the prototype plan doc (`proto-round-trip`), not here —
## repeating it would be the second copy this file exists to prevent.
##
## The speeds are the whole tension of the build and their ORDER is load-bearing. One chain, stated here
## and nowhere else — every paragraph below that cares points back at this one rather than restating it:
##
##     CHEETAH 440 > HORSE 230 > CLONE_SPEED_FOLLOW 215 > HOST_SPEED 200 > LION 190 > SQUIRREL 170
##       > BOSS 150 > CLONE_SPEED_SCATTER 125 > CROW 110 > ELEPHANT 70
##
## Where the four new species sit in it, since each one is a hand and the position IS the hand:
##
## - **CHEETAH is above everything, twice over.** It is the thing that cannot be caught by any means the
##   build has — not herded either, because it out-runs the wall you would herd it into. It flees.
## - **LION is the only creature that hunts and it is under `HOST_SPEED` on purpose.** Walking away from a
##   lion works; standing still does not. Raise it above 200 and the run has an unavoidable chase in it.
## - **SQUIRREL is under the host and that is the whole species** — the one thing you catch by running at it.
## - **ELEPHANT is the floor.** Slower than a crow, and a crow does not move at all.
##
## The creature numbers are `HOST_SPEED × SPECIES_SPEED_MUL`, not absolutes: retuning the walk
## retunes the field with it. **There is no single creature speed any more** — the two constants that were
## one (`PREDATOR_SPEED`, then the flat critter speed that replaced it) are gone, and `SPECIES_SPEED_MUL`
## is the only place a creature's pace is written.
##
## Three things the chain decides, each of which dies silently if a number crosses a neighbour:
##
## - **An abandoned clone never gets home.** CLONE_SPEED_SCATTER is under HOST_SPEED, so scattering costs
##   concentration; break it and the width axis is free.
## - **Nothing sustained catches the horse.** It sits above every body's sustained speed, including 갤럽
##   (`HOST_SPEED × Parts.SELF_MUL[HORSE_LEGS]` = 220), which is why the horse is HERDED and not chased.
##   ⚠ A BURST is not a sustained speed: 짧은 숨 is 560 for 0.16s and is allowed to out-run it, because
##   0.16s of it covers 90px and the horse is gone again the next second.
## - **The boss is the one creature slower than the host, deliberately** — you can walk away from it, and
##   the arena is what takes that option back. See `SPECIES_SPEED_MUL`'s own comment for the deferral that
##   rides on the number.

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

## **The dash's three constants are gone from this file**, into `Parts.SELF_MUL` / `SELF_TIME` /
## `COOLDOWN` at row `DASH`. They are properties of a part, and a part's numbers living here is the same
## value in two places — which is also why `SELF_MUL` is 2.8 rather than the 560 that used to be here:
## 560 / HOST_SPEED 200. See that array's own note.

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

# -- the body and its parts ----------------------------------------
## **The bite's three constants moved into the parts table too** — `Parts.RANGE` / `ARC` / `COOLDOWN` at
## row `BITE`, carrying 70.0, deg_to_rad(70) and 0.5 unchanged. The reasoning that used to live here is
## still worth keeping and now lives beside them: five body-widths ahead, the ANGLE is the skill, two
## bites a second, faster and the click reads as a stream rather than a hit.

## HP rises with levels and with parts, and `HOST_HP` above is the FLOOR of that sum rather than the
## whole of it: `Body.hp_max(level) = HOST_HP + level * HP_PER_LEVEL + the HP column of what is worn`.
## A tenth of one crow hit, so ten levels buy the hit back. It moved 1 → 3 with the ×10 force scale;
## left at 1 a level was a thirtieth of the host's health and read as decoration.
const HP_PER_LEVEL := 3
## How long a sustained movement active runs with no lungs on. Short enough to want lungs.
const BREATH_MAX := 2.0
## Per second, and only while no sustained key is held — see `Body.step()` for why holding past empty
## must not recover.
const BREATH_REGEN := 1.0
## How many parts of one species buy that species' trait.
##
## ⚠ **Three horse parts are in the table and only ONE of them drops** (`Parts.DROPS`: 말 다리 alone —
## user: 말은 다리만 있음 지금은). So the horse trait is **unreachable in play this build**, on purpose,
## and this constant is deliberately NOT retuned to 1: lowering it to keep the number looking used would be
## a silent design change nobody asked for. It is a known deferral — the next plan either opens 말 갈기 and
## 말 폐활량 in `DROPS` or lowers this. `net_body`'s trait checks wear the three by hand and are unaffected.
const HORSE_TRAIT_COUNT := 3
## What one level of a part is worth. Five is half a part at the ×10 force scale.
const PART_LEVEL_FORCE := 5
## Ten percent off the cooldown per level, compounding.
const PART_LEVEL_COOLDOWN := 0.9

# -- food ----------------------------------------------------------
## Spots are fixed for the run. Eating one starts its cooldown, so a region actually empties out —
## without local depletion a tight ball beats a wide scatter and the width axis dies.
##
## ⚠ **500 → 180, and it is a design change, not a tuning one** (user: 바닥에 있는 세포들을 좀 줄이고
## 몬스터들을 좀 채워야 될 거 같은데). At 500 the floor was a carpet and grazing paid the whole run, so the
## seven species were scenery you walked past. The level cost is unchanged: `EXP_PER_FORCE` already makes a
## corpse worth 3× its force, and thinning the grass is what lets that matter.
const FOOD_SPOTS := 180
const FOOD_SPOT_COOLDOWN := 12.0
const FOOD_RESPAWN_PER_SEC := 6.0

# -- critters ------------------------------------------------------
## **What is left of this block is the table's shape and the ecosystem's reach — nothing here decides how
## dangerous anything is.** That job moved to `# -- the three species ---`: a creature's size, speed,
## disposition, force and hp all come from its species, and its damage is its own force in both directions.
##
## ⚠ **The threat model that used to live here is deleted, not merely unused.** A creature carried one
## `threat` number, the swarm's total force was compared against it, and the creature chased you or fled
## from you depending on which way the comparison came out. The user's read on the first play was that this
## was simply the wrong design, so every constant it needed (a threat range, force-per-threat, a radius that
## grew with threat, the meat it paid, and the flat starting count and speed that went with them) is gone
## from this file. `net_field`'s `_c29_instruments` names them one by one and asserts each is absent — that
## list is the authoritative one, and this paragraph deliberately does not repeat it as a count.
## **Do not re-derive any of them from the species tables** — the comparison is what was rejected, not the
## numbers that fed it.
## ⚠ **Both of these moved when the species went from three to seven.** The interval was one arrival every
## 45s against a starting field of eleven; with `SPECIES_START` summing to 24 and herds arriving together,
## 45s is a field that never changes shape. The cap was 24 — the old starting field plus thirteen — and at
## seven species it is what the opening itself hits, so no arrival would ever land.
const CRITTER_INTERVAL := 20.0
const CRITTER_MAX := 64
## How far a critter notices anything. **Nothing crosses the map to reach you** — outside this it wanders,
## which is the whole difference between an ecosystem and an ambush. The boss is the one exception and it
## does not consult this at all; see `BOSS_HUNT_AT`.
const CRITTER_SENSE := 520.0

## **This is the FLOOR of the host's maximum, not the maximum** — levels and worn parts add to it, and
## `Body.hp_max()` is the one place the sum is written. `hud.gd` read the CURRENT hp as the ceiling, which
## was accidentally right only while the deleted 질긴 껍질 card was the sole thing that ever raised it.
##
## 30 = `FORCE_START × HP_PER_FORCE`, and it moved 3 → 30 with the monsters. A crow hits for its own force
## (`SPECIES_FORCE_MIN/MAX[CROW]`, 8–12), so at 3 the first crow ended the run — the one sentence
## `the-crow-stands-and-fights-back` forbids. Three crow hits is what it buys instead.
##
## ⚠ **A literal, never derived from `swarm.force[0]`.** `F` halves force, and a derived ceiling would
## halve the host's health on the tutorial keystroke.
## ⚠ **And it is not denominated in anything.** The HUD prints `현재/최대` as a number (user: 하트 개념
## 말고 숫자로 바로), so there is no per-heart constant to divide by and there must not be one.
const HOST_HP := 30
const HOST_HIT_GRACE := 1.0
## Critters enter from outside the camera, never on top of the player.
const CRITTER_SPAWN_MIN_DIST := 900.0

# -- the three species ---------------------------------------------
## Every table here is indexed by `Parts.Species` — CROW 0, HORSE 1, BOSS 2 — and every one of them is a
## plain `const Array`, never a packed one. `const X := PackedInt32Array([...])` is a **parse error** on
## 4.7.1 ("Assigned value for constant isn't a constant expression"); a `const` Array is read-only, so
## immutability survives, but element typing does not, which is why every read site casts.

## Base radius. Force scales it by at most 1.5×, so a maxed crow (18) can never reach the weakest horse
## (22) — size belongs to the species and force only leans on it.
const SPECIES_RADIUS := [12.0, 22.0, 48.0, 7.0, 40.0, 15.0, 26.0]
## Inclusive. **The boss's min and max are the same number on purpose** — one boss, one force — which is
## why every use of the pair divides by `maxi(1, MAX - MIN)` rather than by the span.
const SPECIES_FORCE_MIN := [8, 30, 120, 3, 70, 25, 55]
const SPECIES_FORCE_MAX := [12, 40, 120, 5, 90, 35, 70]
## × HOST_SPEED, so retuning the host retunes the field rather than leaving three absolutes to drift. The
## ordering is load-bearing and it is stated in the file header, not restated here.
##
## ⚠ **[BOSS] is the one tunable the arena waits on.** At 0.75 (150 px/s) the boss is slower than the host,
## so a player who keeps walking is never caught and **the arena may never close on its own**. That was
## left to be tuned after the first play session (user: 보스 속도는 나중에 맞추는 걸로) — raise this ONE
## number, nothing else. No net asserts self-closure; every arena check drives the boss to `ARENA_RADIUS`
## directly, which is why a deferred number cannot leave the round red.
const SPECIES_SPEED_MUL := [0.55, 1.15, 0.75, 0.85, 0.35, 2.2, 0.95]
## One disposition per species. The per-creature column stays because it is what the movement code reads
## and a later stage varies it per creature; this is only what a fresh row is born with.
const SPECIES_FLEES := [0, 1, 0, 1, 0, 1, 0]
## The boss's reach, on top of its radius.
##
## ⚠ **It is DERIVED from `Parts.RANGE[BITE]` and written here as a literal only because a const cannot
## index another script's const.** Without it 물기 (RANGE 70 + the boss's radius 48 = 118px) out-reaches the
## boss's own contact (48 + BODY_RADIUS 14 = 62px) by 56px, and a force-10 host kills a 360-HP boss
## backpedalling, damage-free. A net asserts the RELATION against `Parts.RANGE[BITE]`, not only the number
## — pinned as a literal alone, retuning 물기 to 80 silently re-opens the free band.
const SPECIES_REACH_BONUS := [0.0, 0.0, 70.0, 0.0, 0.0, 0.0, 0.0]

## A body's hp is its force × this — every creature at spawn AND every clone at birth. A force-10 host
## takes three force-10 crow hits and a force-10 clone takes the same three. **The host is the exception**:
## `HOST_HP` is a literal, because `F` halves force and a derived ceiling would halve the host's health on
## the tutorial keystroke.
const HP_PER_FORCE := 3
## The floor under a body's hp, and it is read in three places. A clone can be born from a force of 0
## (every steering net calls `add_clone()` with no arguments) and a worn part can be swapped for one with
## less HP; both would otherwise produce a body at 0 hp that is alive until something touches it. **A body
## that exists has at least this much.**
const BODY_HP_MIN := 1

## After being damaged a crow walks at the nearest body for this long. It is the whole of "stands and
## counters" — walk up to it and it hits back, which is what makes the common creature a hand to play.
const CROW_COUNTER_TIME := 2.0

## **Does this species move when nothing is in sight.** 0 = it stands where it was born, which is the crow's
## whole design (walk up to it; it does not arrive). Everything added after the crow wanders, because a field
## of statues reads as scenery — the user's words for what was missing were 코끼리는 좀 천천히 그래도
## 움직이고 있어야 될 것 같아.
##
## ⚠ **This is a THIRD disposition column and not a rewrite of `SPECIES_FLEES`.** Fleeing says what a
## creature does about a body it can see; wandering says what it does when it can see nothing. Folding them
## into one number makes "flees but stands still when alone" — the crow's neighbour case — unexpressible.
const SPECIES_WANDER := [0, 1, 1, 1, 1, 1, 1]
## **Walks at the nearest body it can sense, unprovoked.** The lion is the only one, and `SPECIES_SPEED_MUL`
## keeps it under `HOST_SPEED` so walking away is always an answer. The boss does not consult this — it has
## `BOSS_HUNT_AT` and ignores `CRITTER_SENSE` entirely, which is a different rule.
const SPECIES_HUNTS := [0, 0, 0, 0, 0, 0, 1]
## How many arrive together. **A herd is spawned as one call at one spot** (`SPAWN_HERD_SPREAD` wide), which
## is where "무리 지어 다니다" comes from — they are born neighbours and their wander drifts them apart, so a
## straggler is a thing that happens rather than a thing that is coded.
const SPECIES_HERD := [1, 4, 1, 2, 3, 1, 2]
## How far apart a herd's members are placed around the one spot the herd was rolled at.
const SPAWN_HERD_SPREAD := 220.0
## The field at t=0, per species, counted rather than rolled so the opening is the same shape every run.
##
## ⚠ **This counts HERDS, not creatures.** Each entry is multiplied by `SPECIES_HERD`, so the opening field
## is 8 crows · 8 horses · 6 squirrels · 3 elephants · 2 cheetahs · 4 lions = 31, and that sum has to stay
## under `CRITTER_MAX` with room for arrivals. Reading a row as a head count is how the cap gets hit at
## `setup()` and every later arrival silently does nothing.
## **BOSS's row is 0 and must stay 0** — `setup()` places exactly one through `_place_boss()`, which has its
## own sampler, and a second one here would be a second boss.
const SPECIES_START := [8, 2, 0, 3, 1, 2, 2]
## The periodic spawn rolls one species by these weights. **BOSS's row is 0 and must stay 0.** Relative, not
## a probability — `_spawn_critter()` divides by the sum, so adding a row does not require the others to be
## retuned to keep summing to one.
const SPECIES_SPAWN_WEIGHT := [30, 15, 0, 20, 8, 5, 6]

## A clone attacks whatever it touches this often, and a creature that fights back is on the same clock.
## Slower than the host's bite for the same reason its mouth is slower. **Every body and every creature
## opens at 0.0**, ready — the three tables that open an attack clock may not differ, or a body born mid-run
## lands its first hit a full period late for a reason nothing states.
const CLONE_ATTACK_PERIOD := 1.2

# -- corpses -------------------------------------------------------
## Preallocated like every other flat table. **At the cap a kill leaves no corpse** — evicting an older one
## is the bug report "I came back and my kill was gone".
const CORPSE_MAX := 64
## A meal is `corpse_force × this`: a crow ~0.5s, a horse ~1.75s, the boss 6s. Proportional and never flat —
## "a crow is a mouthful, the boss is the end of the run" is the whole beat.
const EAT_TIME_PER_FORCE := 0.05
## A corpse pays its force × this. Three rather than one because a crumb of grass pays 1.0 and there are
## `FOOD_SPOTS` of them respawning at `FOOD_RESPAWN_PER_SEC`: at 1.0 the optimal run is split-and-graze and
## hunting is a hobby.
const EXP_PER_FORCE := 3.0
## A corpse is the creature it came from, slightly collapsed.
const CORPSE_RADIUS_MUL := 0.8
## A CLONE's chance of a part off a finished corpse. **The host's parts come from cards and never roll.**
## Flat, with no weighting and no rising miss chance — a later plan owns both, and the check that pins this
## as a ratio is what goes red the day weighting lands.
const PART_DROP_CHANCE := 0.5

# -- the ground ----------------------------------------------------
## Enough walls to herd against without a maze.
const ROCK_COUNT := 40
const ROCK_RADIUS_MIN := 40.0
const ROCK_RADIUS_MAX := 90.0
## No rock this close to the host's start, or the run opens wedged.
const ROCK_CLEAR_DIST := 400.0
## Rejection-sampling attempts for a rock, a water circle or an ordinary creature spawn.
##
## ⚠ **Each attempt consumes exactly ONE randf pair whether it is accepted or not**, so the same seed
## builds the same world however many are rejected. Draw the point and the radius unconditionally at the
## top of the loop body, then test — drawing the radius only after the point passes makes the number of
## draws seed-dependent and every downstream draw shifts with it.
const PLACE_TRIES := 12
## **The boss alone gets its own count.** The band at `>= BOSS_SPAWN_MIN_DIST` from the field's centre is
## 1,014,113px² of 8,294,400 — 12.2% — so 12 tries fall through 21% of the time and a ten-seed check passes
## 7 times in 100. At 200 tries that is 5e-12, and the placer keeps the FARTHEST sample rather than the
## last, with a deterministic corner as the final backstop.
const BOSS_PLACE_TRIES := 200
## Rare enough that finding one is a plan.
const WATER_COUNT := 12
const WATER_RADIUS_MIN := 90.0
const WATER_RADIUS_MAX := 180.0
## Anything inside water moves at this — bodies AND creatures. A creature that is not slowed makes water a
## stealth field rather than the third wall herding needs.
const WATER_SLOW := 0.6

# -- the boss and the arena ----------------------------------------
## It wanders until here, then walks at the host for the rest of the run.
const BOSS_HUNT_AT := 150.0
## Wide enough to move in, tight enough that the swarm is one swarm.
const ARENA_RADIUS := 900.0
## Where a clone lands when the arena closes: around the **host**, not clamped to the rim. Clamping drops a
## clone 3000px out onto the arena edge, arbitrarily far from the host, which is not what "summoned back
## around the host" means.
const ARENA_SUMMON_RING := 300.0
## The host opens at the field's centre and the farthest corner is 2202.9px away, so 2200 would leave four
## ~3px slivers to place a boss in. 1800 is off-camera at every zoom and still a walk.
const BOSS_SPAWN_MIN_DIST := 1800.0

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
