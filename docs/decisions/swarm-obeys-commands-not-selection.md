# The swarm takes three commands; you never select a unit

**Status**: valid — ⚠ **except the "no cap on clones" claim, which is false.**
`rules.gd` ships `POOL = 128` and `CLONE_CAP = 40`. The argument that survives is that **command-driven
control does not make headcount an input cost**; the cap exists for allocation and rendering, not for
input. [Open field with biomes](open-field-with-biomes.md) re-cites the dead half — do not inherit it.

## What was decided

You drive **one host cell** directly. Everything it spawns obeys `follow` · `scatter` · `attack that`.
No clone is ever selected, ordered, or grouped individually — which is why the clone count has no cap.

## What wasn't chosen

| Rejected | Why |
|---|---|
| StarCraft-style individual control (drag-select, right-click) | Hands only keep up with 4-8 units. The design wants dozens |
| Control groups (1/2/3) | Scales further, but group bookkeeping becomes the game instead of eating |
| Whole-swarm cursor with a density slider only | Lightest input, but no individual cell is visible, and individuality is where the parts show |
| Boids with no orders | The hands go idle — planning principle 1, the same thing that killed the defense direction |

## What's tied to it

The clone cap (there is none), the harvest loop (`follow` is what collects experience), and the fact that
clones can carry *different* parts without costing input.

## Conditions to reopen

If the prototype shows three commands cannot express the fight — specifically if "send these five and keep
those ten" turns out to be the interesting decision.
