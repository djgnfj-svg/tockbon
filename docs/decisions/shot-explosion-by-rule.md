# Shot explosion is blocked by glyph constraints, not a simultaneous cap

**Status**: valid — parallel runes walk around it (below)

## What was decided

Spread→spread is 8→64 bolts, 256 with four players. **Instead of cutting it with a simultaneous-projectile cap**,
constrain the glyph itself — only one spread per magic circle. It is blocked at assembly time.

## What wasn't chosen

| Rejected | Why |
|---|---|
| Use the simultaneous-projectile cap as a tuning knob | **A bolt that fails to fire because of a cap reads as a malfunction** |

The core is **when the problem surfaces.** At firing time it looks like a bug; at assembly time it looks like a rule.

## What's tied to it

Performance and network budget are expressed as **rules**, not numbers. When a four-player combination blows up,
you don't tighten the cap — you add a constraint to that glyph.

- **Set the constraint (count · position) when creating a glyph.** Skip it and the budget has a hole
- "How many bolts is a unique spread" must be decided within this constraint

## Conditions to reopen

**The day the triangle circle (3 rune slots) goes into code.** 3 parallel runes × spread = 24 bolts, so the
blocking logic doesn't apply, and the unit of "one per magic circle" wobbles too (per line or per circle?).

Candidates: circles with many rune slots can't take spread / a total shot cap per circle /
parallel circles are shallow and naturally blocked.
