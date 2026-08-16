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
##     CHEETAH 440 > HORSE 230 > CLONE_SPEED_FOLLOW 215 > RABBIT 210 > HOST_SPEED 200 > LION 190
##       > DOG 180 > SQUIRREL 170 > BOAR 160 > BOSS 150 > CLONE_SPEED_SCATTER 125 > CROW 110
##       > MOUSE 90 > ELEPHANT 70
##
## Where each added species sits in it, since a position IS a hand:
##
## - **CHEETAH is above everything, twice over.** It is the thing that cannot be caught by any means the
##   build has — not herded either, because it out-runs the wall you would herd it into. It flees.
## - **RABBIT is the one entry that carries a RULE rather than a feel.** 210 is above `HOST_SPEED` 200 and
##   below `CLONE_SPEED_FOLLOW` 215, so holding a direction never catches it and a rallied swarm does — it
##   is the middle rung of the flee ladder, between the squirrel (walk at it) and the horse (uncatchable by
##   anything sustained). **Cross either neighbour and the species deletes itself.**
## - **LION is under `HOST_SPEED` on purpose.** Walking away from a lion works; standing still does not.
##   Raise it above 200 and the run has an unavoidable chase in it.
## - **DOG is the same guarantee one step gentler** — it hunts, and 180 leaves retreat open at every moment.
## - **SQUIRREL is under the host and that is the whole species** — the one thing you catch by running at it.
## - **BOAR does not flee and does not hunt.** 160 is slow enough to walk away from and fast enough that it
##   follows you into the swarm you sent at it.
## - **MOUSE hunts at 90**, less than half the host's walk: it is the one thing in the run that arrives, is
##   safe to be touched by, and dies to a single opening bite.
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
##
## ⚠ **It is `2 × CLONE_BODY_RADIUS` — "edge to edge, touching" — and the repo never wrote that down.**
## Left unsaid, every other pair's distance reads as invented while this one reads as tuned;
## `Swarm._separate_from_host()` derives the clone↔host distance from the same rule and says so.
const SEPARATION_MIN := 16.0
## A hard iteration cap, not a time budget. The uniform grid degenerates to O(n²) in exactly one
## situation — the rendezvous, when the entire swarm piles onto one point — and that is the game's
## most-pressed key. Bucket order is stable, so which 8 neighbours are seen is deterministic.
const NEIGHBOUR_CAP := 8
const GRID_CELL := 32.0
## How far INSIDE the touching distance a body separated from a CREATURE comes to rest. **It is not slack
## and it is not taste — it is what keeps melee reachable at all**, and the number it protects is not its
## own.
##
## `World._separate_from_critters()` and `World._contact()` are written against the same sum,
## `critter_radius(k) + the body's radius`: contact admits at `<=` that sum, and a separation that rested a
## body exactly ON it would leave the body one float ulp either side, at random, per pair. **Nothing in
## `Swarm._move_clone()` ever steers a clone toward a creature**, so a bare clone left a millionth of a
## pixel outside its own band never closes it again — it stands against a crow forever, swinging at
## nothing, and the same edge decides whether the creature's own retaliation reaches the host.
##
## ⚠ **It may only ever move INWARD, and never past the narrowest band it sits inside.** The bare-clone
## attack band and a creature's band on a body are both exactly that sum, so a value that separated a body
## FURTHER than the sum would end contact melee entirely with nothing on screen to say so.
const SEPARATION_CONTACT_MARGIN := 1.0

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

## A hit body is pushed along the direction it was hit from — `distance = attacker's force × this`. A sim
## constant despite existing for 연출: it writes a POSITION, and `src/sim/` is the only place one may move.
## A force-10 crow's bite is 8px; the force-120 boss is 96px, visibly further — the whole difference comes
## from one number, force, and this is its only multiplier. Applied through `terrain.push_out` and the
## field clamp exactly the way ordinary movement is, so a knockback can never land a body inside a rock.
const KNOCKBACK_PER_FORCE := 0.8

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
## ⚠ **It moved 45 → 20 when the species went from three to seven**, and it is UNCHANGED by the curve.
## The interval was one arrival every 45s against a starting field of eleven, which is a field that never
## changes shape. **Do not tune this to fix density** — over 150s it is seven arrivals of ~2.6 heads, about
## 18 bodies against 15–20 killed in the same window, which is balanced. What the opening looks like is
## `SPECIES_START` and the two spawn distances; when a species first appears is `SPECIES_UNLOCK_AT`.
const CRITTER_INTERVAL := 20.0
## ⚠ **64 → 96 with the curve, and it is not headroom — the opening itself crossed it.** `SPECIES_START ×
## SPECIES_HERD` is 53, plus one boss and four from `OPENING_POCKET` is **58 standing at t = 0**, and seven
## arrivals of ~2.6 heads each puts a run that kills nothing at ~76. At 64 the field would fill during the
## first minute and **every later arrival would silently do nothing** — `_spawn_at` returns -1 at the cap
## and `_spawn_herd` breaks its loop with no bark, so the symptom is a field that stops changing and there
## is no error anywhere. `net_numbers._r4` asserts the opening against this number in both directions.
##
## Cost is linear, not a wall: `_contact` is O(creatures × clones) = 96 × 41 ≈ 3900 distance checks a frame
## against 64 × 41 ≈ 2600. Every critter table is preallocated to this, so it is memory-flat.
const CRITTER_MAX := 96
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

## ⚠ **The ceiling on ONE blow, and it is a FRACTION of the victim's own maximum rather than a number.**
## Every hit a creature lands on a BODY — the host and a clone alike — is clamped to
## `maxi(1, int(hp_max × this))`. **Nothing clamps what a body deals to a creature**: the cap is about
## surviving a touch, not about killing.
##
## Why a fraction rather than a subtracted constant: the *ratio* is the thing designed, so it needs no
## retuning as the host levels. A 사자 takes half the bar at level 1 and half the bar at level 20.
##
## 0.5 is chosen so the numbers already in the field do not move. 까마귀's 8–12 is under half of `HOST_HP`
## 30, so **three crow hits is still literally three crow hits** — the sentence `HOST_HP`'s own comment
## makes, and the only thing the opening has that teaches "you can be hit". What it does move is
## 사자 55–70, 코끼리 70–90 and 보스 120: every one of them took a full 30-hp host from full to dead on one
## touch, so an opening run met nothing it could survive being touched by, and the user could not reach the
## boss at all.
##
## ⚠ **The boss is NOT exempted and there is no per-species column.** `hunting-and-the-boss-ko` says
## 보스 force 120은 그냥 센 것이다 — 즉사 규칙 같은 예외는 없다, and this keeps that literally true: the boss
## is not special-cased, it is simply strong enough that one touch is half the bar and a couple of seconds of
## contact still ends the run.
##
## ⚠ **Knockback and the screen shake keep reading the FULL force**, deliberately — the elephant that takes
## half your bar still shoves you 62px. The hit reads enormous and costs half; that split is 연출 against
## rule, and `KNOCKBACK_PER_FORCE` is where the first half lives.
const MAX_HIT_FRACTION := 0.5
## Critters ARRIVE from outside the camera, never on top of the player.
##
## ⚠ **900 → 1450 is a TIGHTENING, and it fixes a bug rather than relaxing one.** The camera pulls back as
## the swarm grows (`Look.ZOOM_NEAR` 1.6 → `ZOOM_FAR` 0.8), and at `ZOOM_FAR` an arrival at 900px was
## already materialising **on screen**, which is the exact defect the line above claims it prevents.
##
## ⚠ **The margin was justified by an arithmetic error and the real one is much smaller.** That reasoning
## read the widest zoom as 2400×1350 world pixels — half-diagonal **1377px** — which is `1920×1080 ÷ 0.8`.
## **1920×1080 is the WINDOW; the viewport is 1280×720** (`project.godot`, `stretch/mode="canvas_items"`),
## so the real rect at `ZOOM_FAR` is **1600×900** and its half-diagonal is **918px**. Measured off the live
## `main._true_camera_rect()`, not derived here — the same 1.5× mistake is recorded in
## `tools/look/probe_run.gd`'s header against `probe_field.gd`, and it also put a 700px bound into
## `net_field`'s opening-pocket check where the truth was 459.
## ⇒ **900 really was under the bound, but by 18px and not by 477.** 1450 shipped for one round and it was
## 1.6× the 918 it has to clear, so every arrival walked in from half a screen further out than the rule
## required — which landed directly on the dead air the run still fails on. **The design call is made now**:
## 950, which clears 918 by 32px and nothing more. An arrival still enters unseen; it simply does not spend
## an extra half-screen getting here.
##
## ⚠ **This number governs ARRIVALS ONLY.** It was applied to `setup()`'s t=0 layout as well for two plans,
## and that is the whole of 몬스터가 내 주변에 없어: the opening camera's half-diagonal is 700px, so a 900px
## exclusion disc centred on the host made it **provably impossible for any creature to open on screen**,
## at every seed, forever. See `CRITTER_START_MIN_DIST`.
const CRITTER_SPAWN_MIN_DIST := 950.0
## The same rule for the **opening layout**, which is a different rule wearing the same shape.
##
## `CRITTER_SPAWN_MIN_DIST` exists so a mid-run arrival never POPS into view — something materialising in
## your lap reads as a bug. **At t = 0 there is no pop to hide**: the field is placed before the first frame
## and everything on it was simply always there. So the opening gets its own floor, and 260 is:
##
## - an order of magnitude outside `EAT_RADIUS_HOST` and `BODY_RADIUS`, so nothing opens in your lap;
## - inside the opening camera, so a creature at the floor distance can be on screen from frame one;
## - about 1.3 seconds of walking at `HOST_SPEED`.
##
## ⚠ **The second line said "inside the opening camera's 700px half-diagonal" and 700 is not a number this
## game has.** The viewport is 1280×720 and `Look.ZOOM_NEAR` is 1.6, so the opening camera shows **800×450
## world pixels** — half-extents 400×225, half-diagonal **459**. 700 is `1920×1080 ÷ 1.6`, and 1920×1080 is
## the window override, which `stretch/mode="canvas_items"` makes irrelevant to world coordinates.
## ⇒ 260 is **outside the 225px short half-extent**, so a creature at exactly the floor is on screen for
## some bearings and not for others; "on screen from frame one" was never a guarantee this floor could give.
## `net_field._c33b_the_opening_screen_is_not_empty` drives the real rect instead of asserting a bound.
##
## `World._anchor_min_dist()` still adds `SPAWN_HERD_SPREAD` on top for a herd species, so a herd's anchor
## opens at ≥480 and its far side lands near 700 — a herd straddles the screen edge on purpose, half of it
## visible and half of it somewhere to walk to.
const CRITTER_START_MIN_DIST := 260.0

# -- the eleven species --------------------------------------------
## Every table here is indexed by `Parts.Species` — CROW 0, HORSE 1, BOSS 2, SQUIRREL 3, ELEPHANT 4,
## CHEETAH 5, LION 6, MOUSE 7, RABBIT 8, DOG 9, BOAR 10 — and every one of them is a plain `const Array`,
## never a packed one. `const X := PackedInt32Array([...])` is a **parse error** on 4.7.1 ("Assigned value
## for constant isn't a constant expression"); a `const` Array is read-only, so immutability survives, but
## element typing does not, which is why every read site casts.
##
## ⚠ **Twelve tables, and one of them being a row short is the silent failure of this whole block.** The
## read is an out-of-range index on a `const` Array, which throws at runtime inside `_step_critters` and not
## at parse time — so a short row is a run that dies on the frame the new species first walks.

## Base radius. Force scales it by at most 1.5×.
##
## ⚠ **"종 순서는 절대 뒤집히지 않는다" holds for CROW → HORSE → BOSS and for nothing else, and this comment
## claimed it generally for two plans while the shipped table already broke it**: 치타 maxes at 22.5 and 말
## starts at 22. `net_numbers._r1` only ever asserted the property for the original three, which is why
## nothing went red. **The strict ordering is abandoned across eleven species on purpose** — chasing
## non-overlap over eleven rows forces radii nobody wants (들쥐 would have to be 4.0 to clear 다람쥐, and
## 토끼 could not exceed 6.6 without swallowing 들개). What survives is the original three, which is where
## the sentence was earned: a maxed crow (18) never reaches the weakest horse (22).
const SPECIES_RADIUS := [12.0, 22.0, 48.0, 7.0, 40.0, 15.0, 26.0, 5.0, 8.0, 10.0, 18.0]
## Inclusive. **The boss's min and max are the same number on purpose** — one boss, one force — which is
## why every use of the pair divides by `maxi(1, MAX - MIN)` rather than by the span.
##
## The four added last are the run's missing bottom half, and each is a number against `HOST_HP` 30 and
## `FORCE_START` 10: 들쥐 2–3 is hp 6–9, dead to the opening bite and worth 3 hp to be touched by; 토끼 6–8
## is two or three bites; 들개 12–16 is two hits on a fresh host; 멧돼지 18–22 is the first thing that is a
## fight rather than a chore. Nothing here is a part source — see `Parts.DROPS`.
const SPECIES_FORCE_MIN := [8, 30, 120, 3, 70, 25, 55, 2, 6, 12, 18]
const SPECIES_FORCE_MAX := [12, 40, 120, 5, 90, 35, 70, 3, 8, 16, 22]
## × HOST_SPEED, so retuning the host retunes the field rather than leaving three absolutes to drift. The
## ordering is load-bearing and it is stated in the file header, not restated here.
##
## ⚠ **[BOSS] is the one tunable the arena waits on.** At 0.75 (150 px/s) the boss is slower than the host,
## so a player who keeps walking is never caught and **the arena may never close on its own**. That was
## left to be tuned after the first play session (user: 보스 속도는 나중에 맞추는 걸로) — raise this ONE
## number, nothing else. No net asserts self-closure; every arena check drives the boss to `ARENA_RADIUS`
## directly, which is why a deferred number cannot leave the round red.
const SPECIES_SPEED_MUL := [0.55, 1.15, 0.75, 0.85, 0.35, 2.2, 0.95, 0.45, 1.05, 0.90, 0.80]
## One disposition per species. The per-creature column stays because it is what the movement code reads
## and a later stage varies it per creature; this is only what a fresh row is born with.
##
## ⚠ **A fleeing creature never attacks anything, ever** — `_contact()`'s pass 2 returns on this column
## before it looks at anything else. So 말 · 다람쥐 · 치타 · 토끼 deal zero damage for the whole run, and a
## per-species attack gesture written for one of them would be built, would never fire, and would pass
## every check.
const SPECIES_FLEES := [0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0]
## The boss's reach, on top of its radius.
##
## ⚠ **It is DERIVED from `Parts.RANGE[BITE]` and written here as a literal only because a const cannot
## index another script's const.** Without it 물기 (RANGE 70 + the boss's radius 48 = 118px) out-reaches the
## boss's own contact (48 + BODY_RADIUS 14 = 62px) by 56px, and a force-10 host kills a 360-HP boss
## backpedalling, damage-free. A net asserts the RELATION against `Parts.RANGE[BITE]`, not only the number
## — pinned as a literal alone, retuning 물기 to 80 silently re-opens the free band.
const SPECIES_REACH_BONUS := [0.0, 0.0, 70.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

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
const SPECIES_WANDER := [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
## **Walks at the nearest body it can sense, unprovoked**, and `SPECIES_SPEED_MUL` keeps every one of them
## under `HOST_SPEED` so walking away is always an answer. The boss does not consult this — it has
## `BOSS_HUNT_AT` and ignores `CRITTER_SENSE` entirely, which is a different rule.
##
## ⚠ **Three hunters in the table now, not one, and that is a reversal of a decision made the other way.**
## The sentence it reverses is `_step_critters()`' own — 여섯 개가 타이머로 걸어오는 것은 사용자가 거절한
## 것 — and what reopened it is the user's read after playing: 내가 때릴 수 있는 애가 없고 ... 그냥 몬스터가
## 내 주변에 없어. **The three sit at three different threat levels and none of them is a death sentence**:
## 들쥐 at 90px/s costs 2–3 hp to be touched by, 들개 at 180 costs two hits, 사자 at 190 costs half a bar.
## What the user rejected was six things converging with nothing you could survive; this is the opposite
## half of that complaint. 들쥐 stands on the opening field, 들개 arrives from 45s and 사자 from 105s — see
## `SPECIES_UNLOCK_AT`, which is what stops all three from being in your face at second zero.
##
## ⚠ **The reversal is not written down in `docs/decisions/` and it must be**, by whoever holds the pen on
## docs. A row that quietly undoes a recorded refusal is how the same argument gets had twice.
const SPECIES_HUNTS := [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0]
## How many arrive together. **A herd is spawned as one call at one spot** (`SPAWN_HERD_SPREAD` wide), which
## is where "무리 지어 다니다" comes from — they are born neighbours and their wander drifts them apart, so a
## straggler is a thing that happens rather than a thing that is coded.
const SPECIES_HERD := [1, 4, 1, 2, 3, 1, 2, 6, 4, 3, 1]
## How far apart a herd's members are placed around the one spot the herd was rolled at.
const SPAWN_HERD_SPREAD := 220.0
## The field at t=0, per species, counted rather than rolled so the opening is the same shape every run.
##
## ⚠ **This counts HERDS, not creatures.** Each entry is multiplied by `SPECIES_HERD`, so the opening field
## is 10 crows · 8 horses · 8 squirrels · 1 cheetah · 18 mice · 8 rabbits = 53, plus `OPENING_POCKET`'s four
## and one boss. That sum has to stay under `CRITTER_MAX` with room for arrivals; reading a row as a head
## count is how the cap gets hit at `setup()` and every later arrival silently does nothing.
## **BOSS's row is 0 and must stay 0** — `setup()` places exactly one through `_place_boss()`, which has its
## own sampler, and a second one here would be a second boss.
##
## ⚠ **This is where the run stopped being playable, and the fix is what is in the row now.** The layout
## used to be 31 heads of which **fourteen** could be killed at level 1; everything else either fled at a
## speed nothing catches or took the host from full to dead on one touch. Measured over ten runs of
## `tools/look/probe_run.gd`: 83% of the run had nothing killable on screen and the longest gap between two
## kills was 150 seconds — the whole of 도저히 게임이 진행이 안 돼.
##
## It is **53 heads now and 44 of them are killable at level 1**, and the change is not "more creatures":
## 까마귀 10 · 다람쥐 4 · 들쥐 3 · 토끼 2 · 말 2 · 치타 1 herds, and 코끼리 · 사자 are **0 here on
## purpose** — they are the two that one-shot a fresh host, and `SPECIES_UNLOCK_AT` is what keeps them off
## the field until 105s and 120s (user: 사자가 왜 이렇게 처음부터 있으면 안 되지). 들개 · 멧돼지 are 0 for
## the same reason at 45s and 75s. **A row with a non-zero start and a non-zero unlock would be a
## contradiction** — `World.setup()` reads the gate too, so the layout can never place a locked species.
const SPECIES_START := [10, 2, 0, 4, 0, 1, 0, 3, 2, 0, 0]
## The periodic spawn rolls one species by these weights. **BOSS's row is 0 and must stay 0.** Relative, not
## a probability — `_roll_species()` divides by the sum of the rows that are actually **unlocked**, so
## adding a row does not require the others to be retuned to keep summing to one.
##
## ⚠ **A weight and an unlock are two different questions and both are needed.** The unlock decides *when*
## a species may first appear; the weight decides *how often* after that. 코끼리 4 and 사자 5 are non-zero
## here and unreachable until 120s / 105s, which is not a redundancy — it is the only way to say "rare, and
## not yet".
##
## The arriving **head** share is `weight × SPECIES_HERD`, never the weight alone: 들쥐 108 · 토끼 64 ·
## 말 56 · 다람쥐 40 · 들개 36 · 까마귀 34 · 코끼리 12 · 사자 10 · 멧돼지 9 · 치타 6. 까마귀 keeps the
## largest single **weight** despite the small head share, because it is the only part source in the game
## and a run that meets no crow is offered no cards at all.
const SPECIES_SPAWN_WEIGHT := [34, 14, 0, 20, 4, 6, 5, 18, 16, 12, 9]
## **Seconds of `World.elapsed` before a species may exist at all**, read in exactly two places:
## `setup()`'s t = 0 layout (against a literal 0.0, because that is what t = 0 means) and `_roll_species()`.
## `World.species_unlocked()` is the ONE place the comparison is written — the same discipline
## `boss_hunting()` carries, and for the same measured reason: that comparison was once written in three
## places and they diverged.
##
## ⚠ **The divisor is the whole of the gate.** `_roll_species()` must sum only the unlocked rows: 108 at
## t = 0, 120 from 45s, 129 from 75s, 134 from 105s, 138 from 120s. A roll that divides by the full 138 and
## then skips a locked row is not an error anywhere — it just under-spawns everything by the locked share,
## silently, and the fallback would hand back a locked species outright.
##
## **보스 is 0.0 and that is deliberate, not an oversight.** It is on the field and on the minimap from the
## first frame and you may walk to it — `hunting-and-the-boss-ko`'s explicit call. `BOSS_HUNT_AT` is a
## different clock and it is untouched.
const SPECIES_UNLOCK_AT := [0.0, 0.0, 0.0, 0.0, 120.0, 0.0, 105.0, 0.0, 0.0, 45.0, 75.0]

## **The first thirty seconds, PLACED rather than rolled.** `[species, distance from the host]`, laid out at
## `i × TAU / 4` plus one seeded spin, after the `SPECIES_START` layout.
##
## ⚠ **Expected is not guaranteed, and the opening is not a place to gamble.** The uniform layout puts about
## four creatures inside the opening camera *on average*; `SPECIES_START`'s own comment already claims the
## opening is "the same SHAPE every run", and a uniform sampler cannot deliver that near the host. These
## four are what make the claim true: two 들쥐 walking at you from 280 and 340px, a 까마귀 standing at 520,
## a 다람쥐 at 640.
##
## **The order is the design.** 들쥐 first because it dies to the opening bite and bites back for a tenth of
## a bar — the thing that teaches "there is something to press" without being able to punish it. 까마귀
## before 다람쥐 because the crow **stands still** (`SPECIES_WANDER` 0) and is the only body in the pocket
## that opens the card pool at all, while the squirrel is a chase; putting the chase first makes the run's
## second act a fifteen-second walk across empty grass.
##
## ⚠ **The species are written as bare indices**, because a `const` cannot index another script's `const`
## — the same constraint `SPECIES_REACH_BONUS` carries. `net_numbers` pins each one against `Parts.Species`
## by name so the numbers cannot drift off the enum silently.
## Every one of the four goes through `Terrain.push_out` like every other placement, so none opens in a rock.
## ⚠ **All four rows are inside 459px, and that is the whole point of the table.** They shipped at
## 280 · 340 · 520 · 640 against a guaranteed-visible radius of 459, so the last two were on screen in
## **0 of 60 seeds** — the crow, which is the only body in the pocket that opens the card pool, was never
## once where the opening camera could see it. The two near rows were 63% and 42%. Pulled in so all four
## are on screen at every seed, which is what "PLACED rather than rolled" was supposed to buy.
const OPENING_POCKET := [[7, 280.0], [7, 340.0], [0, 400.0], [3, 440.0]]

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
## Floor on the bite count below — nothing finishes in fewer than three, so even the smallest kill is
## several mouthfuls rather than one long one arbitrarily cut in half.
const CORPSE_BITES_MIN := 3
## Force → bite count: `maxi(CORPSE_BITES_MIN, int(force × this))`. Crow 10 → 3, horse 35 → 3,
## elephant 80 → 6, boss 120 → 9 — the boss alone crosses the floor by enough to matter.
const CORPSE_BITES_PER_FORCE := 0.08
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
##
## ⚠ **12 → 40, and it is `CRITTER_SPAWN_MIN_DIST` 900 → 1450 that forced it.** The exclusion disc is the
## rejection sampler's whole difficulty: at 900 a lone arrival had about half the field to land in, and at
## 1450 it has **32%** — a herd anchor, which pays `SPAWN_HERD_SPREAD` on top and must clear 1670, has
## **19.5%**. `_spawn_at` does not retry forever; it falls through and takes the last rejected sample, so
## every fall-through is a creature materialising at an arbitrary distance, which is the exact defect
## `CRITTER_SPAWN_MIN_DIST` exists to prevent.
##
## Measured on the real spawner, 480 lone arrivals and 2880 herd bodies over 60 seeds:
## at 12 tries **2.3% of lone arrivals and 7.6% of herd bodies landed inside the guarantee**; at 40 tries
## both are **0**. `net_field._c2` drives that count rather than reading it back.
## The cost is 40 randf pairs per spawn instead of 12 — about 2,300 draws at `setup()`, which is nothing.
const PLACE_TRIES := 40
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
