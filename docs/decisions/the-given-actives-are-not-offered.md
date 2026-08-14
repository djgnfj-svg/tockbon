# 물기 and 짧은 숨 are given, never offered

**Status**: valid — settled 2026-08-15 while building plan 3. The plan said the card pool is "rolled from
what has been eaten" and separately that the run opens holding both of these; it never said whether they
are in the pool.

## What was decided

**The card pool is `Parts.SPECIES[p] >= 0` filtered by what the run has eaten.** `BITE` and `DASH` carry
`SPECIES = NONE`, so the filter keeps them out with **no second list to maintain**.

⇒ **The opening pool is genuinely empty.** Levels bank, the sim keeps running, and the first horse opens
the cards as a stack. That is the plan's own cascade, and it only exists because the pool can be empty.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Both in the pool, so `물기 → Lv2` is an early card** | The opening pool would then hold exactly two entries and never be empty, so the banking cascade — the thing check 14 exists for — could not be reached in play at all. It also hands out a level-up on a part that occupies **no slot**, and `slot_level` has nowhere to write it |
| **A separate "starter" list excluded by name** | A second list beside the table, diverging the day a third given active appears. `SPECIES = NONE` is already the sentence "nobody's species", and it was already in the table |
| **Rolling three regardless, padding with what is owned** | An offer of three identical cards, or three cards the player cannot use. Three is the *cap*, not the count: `roll()` returns fewer when the pool is smaller and empty when nothing is unlocked |

## What's tied to it

- **`Cards.roll()` may never assume three are available.** Plan 2's implementation was
  `rng.randi() % pool.size()` against a fixed six-entry table; unchanged, the first level of every run
  divides by zero
- **An empty offer is a legal, long-lived state, not a "needs a roll" sentinel.** `World._grow()` used
  `offer.is_empty()` as exactly that, which becomes a re-roll every single frame once banking lands
- **`World::step()`'s guard is `pending_levels > 0 and not offer.is_empty()`.** The unconditional form
  freezes the game from the first level until the first horse — loud in play, completely silent in the nets
- [The card price was removed](card-price-removed.md) — what has been eaten is the **only** lock on the
  pool. The drop roll on a corpse is a different door and it is plan 4's

## Conditions to reopen

A given active that is genuinely worth levelling. 물기's whole shape is range and arc; if a level ever moved
those, it would need a slot to write the level into, and that is a different decision.
