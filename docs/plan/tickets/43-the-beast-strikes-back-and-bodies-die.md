Type: task
Status: open

# The beast strikes back and bodies die — **the third slice**

## What "done" looks like

**A wolf beside a swordsman hits it, the swordsman's HP falls, and at zero the swordsman is dead —
permanently, in the roster that crosses islands.**

## Where this came from

**2026-08-30**, third of the five cuts the user set for next week.

## ⚠⚠ Death is permanent and that reaches past this island

- **`Army` is what carries between islands and death there is forever** (`CONTEXT.md`:「죽으면 영영
  죽는다」).
- ⚠⚠ **`Battle.setup` already refuses to redeploy a corpse** — a soldier who died on an earlier island
  is `DEAD` here, never `RESERVE`. **That line is standing today with nothing able to kill a body**;
  this slice is what makes it load-bearing.
- ⚠ **`step`'s running test is answered per SUB-STEP, inside the loop, as a `break`** — hoisted out, a
  soldier could die AFTER the island was already won, at 6x and not at 1x.

## ⚠⚠ The telegraph — **it is per-body state, never an event**

- **`enemy_windup` counted down for the whole length the view had to draw.** An event plus a view-side
  clock is a second copy of that countdown, **and two clocks drift.**
- **The declared blow was re-checked against `enemy_windup_at`, not against the current target**, so
  the ring the view drew and the damage that landed could never name two different bodies.
- **A dead attacker's declaration dies with it**, or the view keeps drawing a telegraph over a corpse
  for the rest of the island.
- ⚠ **The heavy attack is TELEGRAPHED and the lion's was 0.6 s ahead.** The wolf has no heavy blow, so
  **this slice builds the mechanism and the wolf does not use it** — build it here anyway, because
  building it later means retrofitting it into a fight that already ships.

## ⚠ Who holds a storey

- **Only a defender that STARTED high holds its post**, read off the spawn 조각 at setup.
- **Measured in play: most WON fights never sent anyone up the stairs, because the defenders came
  down.** ⚠ **Giving EVERY body a holding behaviour is the failure on the other side** — then the
  fight never comes to the player at all.

## ⚠ An enemy's movement scan and its shooting scan are different sets

**Chasing something unreachable asks the flow field for a path that comes back unreachable everywhere,
and then EVERY body stands still for the rest of the island with nothing logged.**

## What this slice does NOT do

- **No boats** — 티켓 44. **No verdict** — 티켓 45.
- **No new beast rows.** The crow's range and the bear's splash ride on rows that already exist.
- **No hit effects on screen** — 티켓 03 holds the lunge, the knockback and the flash.

## Acceptance

1. **A wolf reduces a swordsman to zero and the swordsman is `DEAD` in `Battle` and in `Army`.**
2. **A rebuilt `Battle` for a second island does not redeploy that body.**
3. **Two bodies that finish each other in the same phase both land the blow.**
4. **A telegraph declared by a body that dies before it lands draws nothing and deals nothing.**
5. **A body posted on the second storey stays there; a body that started on the flat does not
   acquire the behaviour.**
6. **Every check inverted and seen to bite**, and the net count does not go down.

## ⚠ Extensibility

- **The telegraph is a column, not a lion feature.** A boss added in week 9 declares its blow with it.
- **Holding a storey is read from where a body started**, so a golem placed high inherits it free.
