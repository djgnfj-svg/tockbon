# Measuring a thing that has size

⚠⚠ **Four rounds of「fixed」that were not**, all on one problem — where an arriving boat should stop.
Every round was measured rather than argued, and **every round measured the wrong thing in a new way.**

**This page is about the INSTRUMENT.** ⚠ A check that went green while lying is
`docs/how-nets-lie.md`; **what is here is why a correct check answered a question nobody had asked.**

## A point instrument cannot measure a body that has width

**The boat is 2.01 조각 across.** Both instruments measured **the position of one point** — so on a
diagonal approach **the forward shoulder reaches land before the bow tip does**, and an instrument
watching the bow reports open water while a third of the hull is on the grass.

⇒ **Measure the footprint, not the origin.** The stop is now swept as five rays across the beam.
⚠⚠ **The tell is that the error was worst on diagonals** — a bug that changes with heading is almost
always a shape being treated as a point.

## Ask what the body needs, not what the world contains

**Round 2 measured to the nearest chosen shore point** and fixed two beaches of four — it was blind to
coastline nearer along the approach. **Round 3 measured against the water instead and overshot**: a boat
halted **7.89 조각 out in open sea with nothing in frame explaining why.** ⚠ **Worse than the grass** — a
beached boat at least looks like something happened.

**Round 4 closed it by changing the question** from「where is the furthest land」to「how far in can this
hull stand」. **Furthest stop 5.08 조각, nothing on land.**

⇒ **When three fixes each fail differently, the question is wrong, not the arithmetic.**

## Two grids half a 조각 apart, and a number that read fine in both

**`Islands.coast()` — the outline the player sees — sits half a 조각 off the 조각 grid.** Verified by
scoring the outline against `grid.passable`: **100% agreement at +0.5, 94.4% at 0.**

⇒ **A net saying「0.60 from the shore」was measuring 0.60 from the tile grid**, and the sentence is true
in both frames while meaning two different distances. ⚠⚠ **Name the frame in the check, not just the
number.** A distance with no frame is not a measurement.

## The lab is not the game, and the copied constant is where they come apart

**The candidate sheet drove the boat at 4.0 조각/s; the game runs it at 1.2.** So **a 16-조각 trail
approved on the sheet draws 4.8 in the game** — the value was hand-copied and went stale.

⇒ **A prototype's parameters are read from the game, never re-typed beside it.** ⚠ The user approved
what they saw; **what they approved is not what shipped**, and nobody could tell from the code.
