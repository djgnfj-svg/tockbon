# Multiplayer is cut from the December build

**Status**: valid — ⚠ **decided for the deleted magic-circle game (2026-08-12 or earlier).**
**December is now August** ([why](magic-circle-dropped.md)), so read "the December build" as "the first
build". The reasoning about netcode cost transfers; the date and the game it names do not.

## What was decided

**Single-player only at launch.** The user confirmed multiplayer was wanted, then the December 2026 ship
date was set, and the two do not fit — it roughly doubles build time (sync, reconnection, and a balance pass
that has to be done twice).

**Deferred, not rejected.** It is the first thing to open after launch.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Lockstep determinism** (the old game's design) | It existed only because flowing water could not be sent over a network. **With the simulation gone, the reason is gone** — there is nothing left that a host cannot simply broadcast. Keeping it would be paying for a constraint with no purchase |
| **Host-authoritative co-op at launch** | The right *shape* for this game, and much cheaper than lockstep — but still not free, and it lands on the December date, not beside it |

## What's tied to it

- **Hitstop becomes available.** It was rejected once in the old game specifically because stopping time
  freezes every player in co-op, and in a lockstep half, one client stopping alone is desync outright.
  Single-player has no such problem — **per-target hitstop is no longer the only allowed form**
- **Nothing in the code needs to anticipate it.** Do not build "multiplayer-ready" abstractions on the way
  to December; every one of them is a cost paid now against a feature that may be shaped differently by then

## Conditions to reopen

**Immediately after launch.** The evidence is external and strong: the biggest recent hit in the neighbouring
genre (The Spell Brigade, 1M+ copies in early access, 1.0 in April 2026) is **co-op**, and Steam made
"Bullet Heaven" an official genre in May 2026. Co-op is where that audience is going.

⇒ **Design the December build so it does not actively forbid a second player** — avoid singletons that
assume one character, and keep "the player" a parameter rather than a global — **but do not build for it.**
