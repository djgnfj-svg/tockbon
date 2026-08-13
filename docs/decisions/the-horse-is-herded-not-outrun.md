# The horse is caught by herding it, never by out-running it

**Status**: valid — decided by the user 2026-08-14. **Reverses the justification** written beside
`HORSE_SPEED` in `grassland-field`, which claimed the swarm could catch it.

## What was decided

**The horse is faster than the swarm in a straight line.** There is no speed that catches it — that is the
point of the species. The user: it is the one you have to think to catch.

**It flees from anything close, host or clone alike**, and **it is blocked by anything it collides with.**
So the hunt is spreading the swarm wide and closing it — every clone you place is a direction the horse can
no longer take.

**Three things are walls**: clones · rocks · the field edge.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Lowering `HORSE_SPEED` to 1.05× so the swarm out-runs it** | The cheapest fix and it deletes the species. Catchable by holding a key is what the crow already is |
| **Raising `CLONE_SPEED_FOLLOW` to 240 instead** | Same outcome by the other end, and it makes every other chase trivial too |
| **Fleeing only from the host** | Then clones are scenery during the one hunt built around them |
| **A fourth key for encircling** | The user's call: the three commands already do it. Spreading is `2`, closing is `1`, placing is `3` |
| **Terrain doing all the walling** | Then the hunt happens where the rocks are, not where the player makes it happen |

## What's tied to it

- ⚠ **`HORSE_SPEED 1.15×` (230) is above `CLONE_SPEED_FOLLOW` (215) and that is now correct**, not a bug.
  The speed-ordering comments in `rules.gd` — **there are two of them, around line 10 and around line 23** —
  both assert `host > critter > scattered clone` and both are now false
- **Clones must physically block**, which they do not today. This is new sim work, not a tuning value
- **The flee vector reads every nearby body**, not just index 0
- **Rocks exist because of this** — see [Everything goes in for August](everything-goes-in-for-august.md)

## Conditions to reopen

**Play says herding is fiddly rather than clever.** The first thing to try is the flee radius, then rock
density — lowering the horse's speed is the last resort, because it is the same as deleting the hunt.
