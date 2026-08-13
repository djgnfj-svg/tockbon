# Nothing gates the boss — it hits for its force, and that is the wall

**Status**: valid — decided by the user 2026-08-14, after an adversarial review showed the plans had no wall
at all.

## What was decided

**Damage equals the attacker's force, in both directions.** A creature's HP is `force × HP_PER_FORCE`, and a
creature that reaches the host takes **its own force** off the host's HP.

⇒ **A level-1 host can kill the force-12 boss by kiting, and that is allowed** (the user's words: *you can
beat it that way — it'll just be hard to dodge, and a low level is basically an instant kill*). What stops it
is not permission, it is that **one touch from a 12 ends a 3-HP run.**

## What wasn't chosen

| Rejected | Why |
|---|---|
| **A force threshold** — you cannot hurt what outranks you | The design already deleted one comparison-driven behaviour rule ([why](force-and-disposition-are-separate.md)). Adding it back on damage rebuilds the same machine |
| **Contact costing a flat 1 HP** (what the prototype shipped) | It made a crow and the boss equally survivable, so force decided nothing about danger. The review found a force-1 host beating the boss in 18 seconds under this rule |
| **Gating the boss behind a level or a swarm size** | Then the arc is a lock opening, not a fight becoming winnable |
| **Spawning the boss late** | The user wants it walking the field from the first second, with its 12 legible under it |

## What's tied to it

- **The number under every body.** It is now literally the damage number in both directions, which is what
  makes reading it worth doing
- **`HOST_HIT_GRACE`.** One second of invulnerability after a hit is the whole margin for error
- **The boss's reach.** Speed is not what makes it dangerous — it is slower than the host on purpose. ⇒ **If
  play shows it can be kited safely, the fix is reach, not a level requirement**
- **HP growth through levels and parts** is now the only thing that makes a 12 survivable, so the mane's
  +1 max HP is a real card rather than a rounding error

## Conditions to reopen

**If kiting the boss at level 1 turns out to be the optimal way to play** rather than a stunt. That is a
tuning failure in reach and grace before it is a reason to add a gate.
