Type: task
Status: open

# A round is won or lost — **the fifth slice, and the one that closes the loop**

## What "done" looks like

**Every beast dead is a win. The base burning is a loss.** The round stops on either and says which.

## Where this came from

**2026-08-30**, last of the five cuts the user set for next week.

⚠ **The clear condition of the whole game is a specific boss** (the user, 2026-08-30) — **that is week
9's, not this ticket's.** This slice is one island's verdict.

## ⚠⚠ What the verdict owes

- **WON is checked before either loss**, so an island cleared on the same sub-step the last body dies
  is a win.
- **The clock is checked last**, so an island cleared on the very sub-step the timer expires is a win.
- ⚠⚠ **The verdict needs something to be about.** **A commit with no enemies on the board reads as a
  win on the first frame** — that is why the gate was kept the whole time the fight was unreachable.
  **Whatever replaces the gate has to answer "has the fight begun", not just "is `step` running".**
- **`step`'s three guard lines are not interchangeable.** The null test and `dt <= 0.0` are per-CALL
  facts and stay outside the sub-step loop; the running test is per SUB-STEP, inside, as a `break`.
  ⚠ **Hoisted out, a body could die AFTER the island was already won** — at 6x and not at 1x.

## ⚠ The base

- **One house stands on the island and it is the only build there is** (`island.json` carries one).
- **Nothing in the game can damage a build today.** This slice is where a build first has HP.
- ⚠ **The house is drawn part by part in flat colour**, unlike the ground — burning it is a look
  decision, not a number. **It is made in a tool, never typed.**

## What this slice does NOT do

- **No wave table.** One boatload, one verdict.
- **No reward, no card, no research bench** — that is week 5. **The growth loop is deleted** and its
  tombstone says how to bring it back: **roll the tier first and the item second**, or legendaries get
  rarer every time an item is added.
- **No boss and no ten-minute clock** — week 9.
- **No screen for the verdict.** ⚠ **A win or a loss the player reads is made in a tool** — if it is
  worth having it is worth being designed, and typed chrome is exactly what got deleted.

## Acceptance

1. **A net kills the last beast and the round reports WIN on that sub-step.**
2. **A net burns the house and the round reports LOSS on that sub-step.**
3. **The last beast dying on the same sub-step as the last swordsman is a WIN.**
4. **A round that has not begun does not report a win**, with no beasts placed.
5. **Nothing runs after the verdict** — no attack, no death, no landing.
6. **Every check inverted and seen to bite**, and the net count does not go down.

## ⚠ Extensibility — what this slice must leave open

- **The verdict is a value, not a screen.** Week 9's boss clear condition reads it.
- **A build carries HP the same way a body does**, so the towers of week 6 need no second mechanism.
