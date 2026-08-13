# What an attack hits is written on the part, and `BITE` is a narrow forward cone

**Status**: valid — decided by the user 2026-08-14. Confirms in the user's own words what the plans had
already assumed: *"좌클릭마다 다르지 않을까?"*

## What was decided

**The hit shape is a property of the part, never of the key.** `SHAPE` · `RANGE` · `ARC` sit in the parts
table, so left click hits differently depending on what is bound into it. There is no such thing as "how
left click works".

**August's starting `BITE` is a narrow forward cone**, aimed at the mouse.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **One hit rule for the attack key, parts only changing the numbers** | Then every part feels the same and the slot is a stat stick |
| **`BITE` hitting everything touching the body** | No aiming, so the hands do nothing during a fight but move |
| **`BITE` auto-targeting the nearest** | Reliable and empty. Nothing to do well |

## What's tied to it

- **A narrow cone leaves the rest of the space free**: wide cones, lines, and circles are what later parts
  are made of. Starting wide would spend the range on the first part
- **It makes the boss fight legible** — moving, aiming and steering the swarm are three jobs, and aiming is
  only a job if the cone can miss
- **`cell-game.md`'s "space has exactly one implementation: an impulse along the facing" is dead by the same
  rule** — the movement key's behaviour comes off the part too

## Conditions to reopen

**Play says aiming fights the camera** — the camera pulls back as the swarm grows, and a narrow cone at low
zoom may read as unfair. The fix is the arc, not auto-targeting.
