# The boss is on the field from the start, comes for you, and cannot be escaped

**Status**: valid — decided by the user 2026-08-14. ⚠ **One half is deliberately left open** and the user
said so explicitly: *how* escape is prevented is not decided. The arena is part of the answer, not all of it.

## What was decided

**The boss stands somewhere on the field from t=0.** It is on the minimap. The player may walk to it early —
nothing gates that, which is [The boss is not gated](the-boss-is-not-gated.md) unchanged.

**After a set time it comes to the host.** The choice of *when* is the player's only up to that point.

**It cannot be escaped.** When it closes, **the field becomes an arena and every scattered clone is summoned
back around the host.** Whatever is holding the swarm elsewhere is over; the fight starts with everything you
have, in one place.

**Losing ends the run.** The host dying is the end even with clones alive.

**The hands during the fight**: moving, attacking directly, and steering the swarm. All three at once —
this is the only fight that asks for all of them.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **The boss can be out-run indefinitely** | Then the run has no end that isn't the player's boredom |
| **Escaping is possible but costs hunting time** | A softer version of the same. The stage needs a wall, not a tax |
| **The boss grows while you avoid it** | Punishes the wait instead of removing it, and adds a number nobody can see |
| **Spawning the boss on a timer, or after the horses are cleared** | Both delete the choice of when to go. Being able to see it and decide is the whole tension |
| **Breaking the arena open once the boss is damaged enough** | An exit turns the fight into attrition-and-retreat |
| **Carrying on in a clone when the host dies** | The user considered it and said no in the next breath. Host death has been the end since the prototype |
| **Leaving the scattered swarm scattered when the arena closes** | Half the swarm outside the wall is half a boss fight, and it reads as a bug |

## What's tied to it

- ⚠ **The mechanism that makes escape impossible is undecided.** The arena describes what happens once it is
  close. What pulls the player into that range — speed, a shrinking field, something else — is open.
  **Do not invent it silently**; it is a question for the user
- **Boss speed 0.75× is not yet re-examined** against this, and it is the obvious thing the open half touches
- **The summon is a hard teleport**, so anything a clone is carrying arrives with it
- **`grassland-field`'s "so it cannot be walked into early" is dead twice over** — once by
  `the-boss-is-not-gated` and once by this doc. It is written in two files, character for character

## Conditions to reopen

**The open half gets decided** — write it here rather than in whichever file is being edited that day.
