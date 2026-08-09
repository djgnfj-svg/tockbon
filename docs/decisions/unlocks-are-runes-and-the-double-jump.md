# 원석 buys runes and the double jump — not points, not dice, not circles or glyphs

**Status**: valid

## What was decided

The research bench's first unlocks are the **불 rune, the 물 rune, and the double jump** — the user's own
list, closed with *"거기까지 하자"*. The other three candidates were each rejected for a different reason, and
none of them was cost.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **The 점수 axis** | **Not buildable, not deferred.** No point budget exists anywhere in `src/`. An unlock that raises a ceiling nothing reads is a false handle — the slot would light up and mean nothing |
| **The 주사위 axis** | **Deferred on an undecided rule, not on cost.** The field (`progress.dice_left`) and the button both exist and are inert on purpose; what is missing is how many per run and **what a reroll draws from**. Cheapest next axis when that is answered |
| **Circles and glyphs as unlock targets** | **There is no ownership concept to gate on.** `palette_layout.gd` says it outright — "there is no notion of owning", everything that exists shows up. `owns_rune()` is the only `owns_` in the whole of `src/` (grepped: one hit), which is why runes could be sold and these could not. **Not a price question** |
| One permanent field per axis | `reset()` would have **two** things to not clear, and a bool is invisible to `net_pick`'s stash scan. One set, one thing to protect, one inverted check |

## What's tied to it

- **The sink is three purchases deep and then dry.** Stated, not hidden — widening it is the dice axis's job
- **불 is buyable even though the bull already grants it in-run**: the grant dies with `reset()`, so the
  purchase buys **permanence**, not first access. It does not break "the midboss must be met as a wall once",
  because run 1 starts at 0 원석
- The price itself is a **value**, and lives in the design doc — not here

## Conditions to reopen

**점수** reopens the day a point budget exists and something reads it. **주사위** reopens the day
"how many per run" and "what a reroll draws from" are answered — and whoever writes it must dismantle
`net_progress._dice_left_is_zero_and_inert` deliberately.
