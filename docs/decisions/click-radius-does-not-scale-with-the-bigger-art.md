# The click radius drops as the art grows — it does not scale with it

**Status**: valid

## What was decided

`SLOT_HIT_RATIO` (the multiplier that turns a symbol's radius into its click radius) moved **1.8 → 1.0**
in the same change that grew the rune and glyph art (`CIRCLE_RUNE_RATIO` 0.26→0.36,
`CIRCLE_GLYPH_RATIO` 0.115→0.18). The picture got bigger; the click area's **absolute size** stayed put.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Leaving the multiplier at 1.8** | It multiplies the *new*, bigger radius, so the click area balloons with the art — clicking beside the rune still hits it, and layer 1's and layer 2's hit discs start overlapping |
| **1.3, tried first** | Measured insufficient by `net_circle`: layer 1's seat still could not clear the rune's inflated click radius (`1.3×50.42 + glyph radius`), so the two still overlapped |

## What's tied to it

- `net_circle` measures the two hit discs stay disjoint — any further art growth needs the same
  re-measurement, not an assumed-safe multiplier
- The picture and the hit test are deliberately different numbers now; do not fold them back into one
  ratio without re-deriving both

## Conditions to reopen

The art grows again, or a new circle adds a socket close enough to another that 1.0 stops being enough
margin.
