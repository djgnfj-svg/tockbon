# The bull room's new door burns only from the fire rune — not the bull's fire, not a runeless blast

**Status**: valid

## What was decided

Fork 1 of `burn-out-of-the-bull-room.md`'s door-protection question: **the door ignores any ignition that
isn't the fire rune.** The bull's own fire (bolt range 480px, reaches the wall from its box) and a runeless
blast (`spell_sim.gd`'s blast ignites without checking `element`) both pass over it and do nothing.

Moving the wood wall into room ①'s east face (`the-rune-is-used-where-it-is-won.md`) puts the door on the
**near** side of the pit, reachable the instant the player walks in. The map-shape protection the GDD
recorded — "you cannot stand in front of that wall without already holding fire" — is gone the day that
ships. **A rule takes its place**: the lock is now held by what lit the fire, not by where the wall stands.

**How** — a sixth material, a cell flag, or `_ignite_cell` learning who lit it — is still open; the three
are different sizes of `src/sim/` change, and the outcome (only the fire rune opens the door) is the same
whichever the builder picks.

## What wasn't chosen

| Rejected | Why |
|---|---|
| A sill above the fire's reach | Cheap and terrain-only, but not airtight — a player standing on the sill still draws the bull's bolt onto the door |
| Accept the room opening mid-fight | Contradicts the user's own beat and the GDD's "the midboss reward is the key to progression" |
| The bull's fire stops sticking to terrain | Reverses a separate, already-shipped decision. Not on the table |

## What's tied to it

- `docs/plans/2.active/burn-out-of-the-bull-room.md` — the Bounds section this closes
- `docs/plans/3.done/stage1-map-layout.md`'s "나무벽 — 진행 열쇠가 자연법칙인 자리": its buffer-zone and
  wall-outside-the-room protections are superseded — the lock no longer depends on distance
- `docs/GDD.md`'s First milestone table, "…and that shape is being deleted" row — closed by this
- Whichever `src/sim/` shape is picked touches `_ignite_cell` and every caller that ignites terrain

## Conditions to reopen

None.
