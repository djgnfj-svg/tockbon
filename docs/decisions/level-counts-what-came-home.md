# The level gauge counts what came home, not everything the swarm ate

**Status**: valid — settled 2026-08-14 while correcting plan 2.

## What was decided

`World::_grow()` fills from **`swarm.banked`** — the host's own mouthfuls plus whatever a clone carried back
into the absorb radius. **`swarm.eaten`** stays what it is: a monotonic total of every mouthful this run,
reported at the ending as 경험치 and never used for levelling.

The two numbers exist because they answer different questions. `eaten` is *what the run found*. `banked` is
*what the run kept*.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Levelling from `eaten`** — the reading of "먹은 force가 곧 경험치" in `hunting-and-the-boss-ko` | **It deletes the one thing play confirmed was fun.** Cargo is counted into `eaten` the moment it is picked up, so a clone dying 2000px from home costs nothing at all. The prototype's accepted sensation is that losing a loaded clone hurts, and this makes it free |
| **Two gauges, one from each** | Two bars for one act of eating. The player cannot act differently on them |
| **Levelling from `banked` but reporting `banked` at the ending too** | The ending would then never show that the run found more than it kept — which is the sentence the whole cargo rule is trying to say |

## What's tied to it

- **`V` is what pays for levels.** Clones only hand over on absorb after plan 2, so the gauge moves because
  the player gathered — see [the swarm grows by a key](swarm-grows-by-a-key-not-a-level.md)
- **`Swarm::eat()` stays the single place `eaten` moves.** Absorbing and the clear beat assign `banked`
  directly and must never route through it
- The ending's 경험치 row and the HUD's bar are reading **different numbers on purpose**

## Conditions to reopen

Play showing that gathering with `V` is a chore rather than a decision — if the player presses it on reflex
the moment it is available, the gauge is charging for something that was never a choice.
