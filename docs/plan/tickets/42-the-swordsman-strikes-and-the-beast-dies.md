Type: task
Status: open

# The swordsman strikes and the beast dies — **the second slice**

## What "done" looks like

**A swordsman standing next to a wolf hits it on its own period, the wolf's HP falls, and at zero it
is gone from the board.** The wolf does not hit back yet.

## Where this came from

**2026-08-30**, second of the five cuts the user set for next week.

## ⚠⚠ What a rebuilt fight owes — **each line was paid for once**

**`battle.gd`'s「THE FIGHT: DELETED」block and the targeting-helpers block are the design document.**

- **Damage lands in one phase and death latches in a LATER one.** A body reduced to 0 by an earlier
  attacker in the same phase still swings — **otherwise whoever the loop reached first gets a free
  kill, and a free kill is invisible in final state.**
- **Deaths latch in the SAME sub-step as the blow**, never a frame later, or a corpse stands at zero
  HP for a frame.
- **A target is kept while it is alive AND in reach**, and re-chosen the moment either fails.
- **A blow's victims are resolved ONCE** — primary and splash — and every effect reads that one list.
  **Walking the radius a second time lights up bodies that were already dead.**
- ⚠⚠ **Reach is `range + REACH_BONUS` and the bonus was 1.75.** The window is「above the stair
  diagonal, below the flat two-조각 orthogonal」. At 1.5 a body on a stair reached the plateau beside
  it orthogonally and **not diagonally** — three hits and a kill one way, **zero hits and zero damage
  the other**. A stair is one 조각 wide, so everything behind the body that cannot hit is stuck in the
  doorway. **26 of 162 fights were lost that way.**
- **Distance is 3D and the height comes from the LEVEL, never from the drawn mesh.**
- **The comparison carries an epsilon.** A diagonal is exactly sqrt(2) and a bare `<=` there is a coin
  flip that changes which bodies can fight from frame to frame.
- **Nearest is Euclidean and ties go to the SMALLER id.** A tie broken by iteration order makes two
  runs from identical state diverge with every check about them green. ⚠ **This is the determinism the
  multiplayer decision rests on** — the user settled on 2026-08-30 that multiplayer comes later and
  **the constraint is honoured from now**.

## ⚠ What already stands here

| What | Where |
|---|---|
| **Every number** | `Rules.UNITS` — swordsman damage 2.5, period 1.2, range 0, area 0 |
| **The column indices** | `Rules._COL_HP` … `_COL_LABEL` |
| **The sub-step loop and its phase contract** | `Battle.step` — its header states the contract |
| **The enemy columns** | 티켓 41 |

⚠⚠ **`REACH_BONUS` is deleted and its value is in the `rules.gd` tombstone.** Restore the constant
with the measurement written beside it; **do not re-derive it.**

## What this slice does NOT do

- **The beast does not attack** — 티켓 43.
- **No verdict, no clock** — 티켓 45.
- **No telegraph.** The lion's 0.6 s declaration is a 티켓 43 concern; the swordsman has no heavy blow.
- **No effects on screen beyond the body vanishing.** ⚠ The hit flash and the lunge are 티켓 03.

## Acceptance

1. **A net drives `step` and watches HP fall by exactly the table's damage, once per period.**
2. **Two swordsmen finishing one wolf in the same phase both land their blow** — invert the phase
   split and see the free kill appear.
3. **A body on a stair reaches the plateau beside it diagonally**, and does not reach a flat 조각 two
   away orthogonally. **Both halves asserted** — the window is what the number buys.
4. **Reach across a storey boundary uses the level**, not the drawn height.
5. **Two runs from identical state produce identical outcomes**, ids and all.
6. **Every check inverted and seen to bite**, and the net count does not go down.

## ⚠ Extensibility

- **Nothing here reads a species name.** Area, range and period all come from the table, so the bear's
  splash and the crow's range are already covered by rows that exist.
- **The victim list is built once and passed**, so an effect added later reads it rather than rescanning.
