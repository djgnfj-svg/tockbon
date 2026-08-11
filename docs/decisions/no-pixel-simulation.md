# The pixel water/fire simulation is gone, and nothing replaces it

**Status**: valid

## What was decided

The cell-grid simulation — water as an amount per cell, fire spreading through neighbours, terrain carved by
blasts — is **deleted, not deferred.** The new game has no grid.

The user's own grounds, and they are the whole argument: **they refunded Noita for being boring.** The genre
the simulation was building toward is not one they enjoy. The simulation went in because
**"I thought the AI would be good at simulations"** — a judgment about tooling standing in for one about the
game.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Keep it and make it matter in combat** — fire pools, drowning, collapsing floors | The honest version of the original promise, and it was never tried. Dropped because the user has played the reference work for it and did not enjoy it. **This is the branch to reopen if anything reopens** |
| **Keep fire only, drop water** | Fire was the half that worked — monsters burned, one wooden door burned down. But fire alone still carries the cell grid, the awake-chunk budget and every constraint below, for one interaction |
| **Keep the grid for destructible terrain, drop the fluids** | Destructible terrain does not need a fluid simulation — tile removal does it (Terraria, Worms). Keeping the grid "just for terrain" would have kept the cost while giving up the thing the cost bought |

## What's tied to it

**Dropping it releases the entire constraint set at once**, which is most of why it went:

- **Integer determinism across the whole codebase** — no `float`, `sqrt`, `sin`, `randi`. It existed because
  flowing water cannot go over a network (measured at ~720kbps for three players), so every client had to
  compute it identically
- **A 20Hz simulation tick under the 60Hz physics frame**, and the three-clock seam that produced five
  separate silent defects
- **A tick budget already exceeded** — 84ms of work against a 50ms budget at the active-chunk cap
- **Hit detection running on the tick**, which is why a projectile could pass through a monster between
  samples and why one movement constant could not be retuned in either direction

Measured on the way out, and worth recording because it is what made the decision easy: **`monster.gd`
contained the word `water` zero times**, and the shipped stage poured none at all. The most expensive
subsystem in the codebase touched nothing the player fought.

## Conditions to reopen

**If the new game's combat turns out to want an environment that reacts** — and only then, as a small,
scoped version (one material, no fluid flow), never as the general simulation. The old code at `v1-sim`
is a reference for *how*, never something to restore.
