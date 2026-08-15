# The boss's speed is left for the first play session

**Status**: valid — deferred by the user 2026-08-15, in the words *"보스속도는 나중에 맞추는걸로."*

⚠ **This file records a DEFERRAL, not a fork**, and it is filed here because what was declined is a design
claim — *make the boss faster than the host so the arena forces itself shut* — and not a value pick. Do not
read the shipped number as a chosen one, and do not invent a rationale for it: **nobody argued for 0.75×, it
is simply what the plan already said and what the user declined to change yet.**

## What was decided

**`Rules.SPECIES_SPEED_MUL[Parts.Species.BOSS]` ships at the plan's 0.75× and the consequence is accepted.**
At 0.75× the boss is **slower than the host**, so a player who keeps walking is never caught, the arena never
reaches its trigger, and **the run has no ending that arrives on its own** — it ends by dying, or by the
player choosing to walk into the boss.

⇒ **The mechanism ships in full and only its trigger is unresolved.** The arena closes, clamps the host and
summons the swarm exactly as designed; nothing about it is stubbed.

⇒ **It is one array element to change afterwards.** Nothing else moves with it, and **no check asserts that
the arena closes by itself** — every arena check drives the boss to `Rules.ARENA_RADIUS` by hand, so raising
the number reddens nothing.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Raising it above the host now** (1.10×, so the boss catches a fleeing host and the arena closes on its own) | Proposed while correcting the plan. The user declined it until they have played once — a boss that out-walks you is the kind of thing that is judged in thirty seconds of play and cannot be judged on paper ([planning principle 2](../planning-principles-ko.md)) |
| **Gating the ending on something else** — a timer, a kill count, a level | [Nothing gates the boss](the-boss-is-not-gated.md) runs the other way, and adding a second trigger to hide a slow one is the fix that survives into the shipped game |
| **Cutting the arena until the speed is settled** | Then the first play session cannot judge the thing it was deferred for. The mechanism is what the session is looking at |

## What's tied to it

- **The boss ignores the clone wall.** A creature stopped by a ring of bodies would never arrive; a boss that
  is *both* slower than the host *and* stoppable never arrives by any route at all. The exemption was written
  for a faster boss and this deferral is what makes it load-bearing
- **[The boss cannot be out-run](the-boss-cannot-be-outrun.md) is not true yet.** That doc's own half-undecided
  warning now has a second half: for this build you can, in fact, out-walk it
- **The plan's acceptance question** — *whether the arena closing reads as the run's last act* — **cannot be
  answered by a passive playthrough.** The player has to walk into the boss to see it. Worth saying before
  the session, not after

## Conditions to reopen

**The first play session.** It is the first thing to look at, and it is one number.
