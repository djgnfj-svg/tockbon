# One open field with biomes, not rooms

**Status**: valid

## What was decided

The map is a single open field. Regions differ by palette and spawn table — no rooms, no corridors, no
navigation graph.

## What wasn't chosen

| Rejected | Why |
|---|---|
| Rooms and corridors | A boss arena falls out of it for free, but dozens of clones then need real pathfinding — the cost swings by an order of magnitude |
| One flat field, no biomes | Cheapest of all, but the tier change has nothing to show for itself and the screen never changes in a twenty-minute run |

## What's tied to it

Clone movement is steering, not navigation. **If the map ever gains walls, every clone needs a path.**

⚠ **Both halves of this have since moved.** The clone count was never uncapped — `rules.gd` ships
`POOL = 128` and `CLONE_CAP = 40`, and the "no cap on clones" claim this sentence used to carry was struck
in [The swarm takes commands](swarm-obeys-commands-not-selection.md). **And the map does now gain walls**:
rocks and water ship ([why](everything-goes-in-for-august.md)), because
[herding the horse](the-horse-is-herded-not-outrun.md) needs something to corner it against.
⇒ **Steering versus navigation is a live question again**, and this is the doc that gets edited when it
is answered.

## Conditions to reopen

If boss fights need an enclosed arena that an open field cannot express.
