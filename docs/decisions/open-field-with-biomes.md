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

Clone movement is steering, not navigation. If the map ever gains walls, every clone needs a path and the
"no cap on clones" claim goes with it.

## Conditions to reopen

If boss fights need an enclosed arena that an open field cannot express.
