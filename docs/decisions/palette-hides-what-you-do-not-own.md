# The palette hides what you do not own — the cell is gone, not dimmed

**Status**: valid — **it reverses `plans/3.done/rune-lock-and-receiving.md`'s "veiled, not hidden"**
(decided by the user)

## What was decided

An item the player does not have **has no cell in the palette at all**: it is not drawn, it takes no seat in
the row, and the hit test returns nothing for its coordinates. The veil that `rune-lock-and-receiving`
shipped — the item drawn dark and unpickable — is gone for **ownership**.

**The veil itself is not deleted.** `PALETTE_BLOCKED_VEIL_A` keeps its second job: "you own this but nothing
will take it right now" (a placed spread against `max_per_circle`, or any rune while the circle is out).
**Ownership hides; unplaceability dims.** Fold the two into one question and the glyph you just placed
vanishes from the palette the instant it lands.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Veiled, not hidden** — the shipped behavior | `rune-lock-and-receiving`'s argument was that seeing fire and water sitting locked is "the whole of 'the midboss reward is the key to progression' being legible before you earn it". **The user judged the opposite on screen**: the window opens onto fourteen cells and eleven of them are things you cannot use, and the noise costs more than the foreshadowing buys |
| Gating in `circle_window._slot_accepts` (where the rune gate lives today) | That is the seat for "will this slot take it", and it is asked **per slot**. Hiding is a question about the **item list**, asked once. Keeping the hide there is what makes the placed-spread-disappears bug inevitable |
| Dimming harder — a darker veil, greyscale, a lock icon | Same fourteen cells. It answers "can I read which are locked", which was never the complaint |
| Hiding **everything** unplaceable, ownership and constraint alike | Place spread → spread vanishes. The player cannot see what they own, and "where did it go" reads as a bug |

## What's tied to it

- **`palette_layout.items_of()` stops being ownership-blind.** Its own header ("There is no notion of
  'owning' — **everything that exists** shows up") and the `KIND_RUNE` branch both move
- **`net_circle._palette_is_kind_by_item` goes red.** It asserts `items_of(KIND_RUNE)` **equals
  `Tuning.ELEM_ALL` by value** — and staying green was the stated reason the original gate went into
  `_slot_accepts` rather than here. That trade is now spent on purpose
- **`item_at()` must filter identically to the drawing**, or a click lands on an item that is not on screen —
  `palette_layout`'s own "coordinates in two places" failure, which raises nothing
- **`rune-lock-and-receiving.md`'s acceptance items 3 and 4** ("Fire is visible in the palette and cannot be
  picked — veiled, not missing") become false the day this ships
- **Circles and glyphs have no ownership field anywhere**, so this decision cannot be fully applied to them
  until one exists — and for glyphs that argues with `no-inventory.md`. Held open in
  `plans/3.done/onboarding-and-palette-tabs.md`'s TBD

## Conditions to reopen

**If a locked item ever has to be advertised before it is earned** — a reward preview, a "coming from the
next boss" slot, or any progression the player is meant to plan around. That is the thing the veil was for,
and it is what this trades away.
