# A kill leaves a corpse, and eating it takes time

**Status**: valid — decided by the user 2026-08-14.

## What was decided

**Killing something does not feed you.** It leaves a corpse; a body standing on the corpse eats it over
`EAT_TIME`, scaled by the corpse's force; progress is kept if the eater walks away and comes back.
**Ground food — grass, plants — is still instant.**

The user's word for what this is for was **쫀득**. It is a mechanic first: the moment of standing still over
a kill, with something able to walk up to you, is where the tension is. The animation sells a beat that
already exists in `sim/`.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Contact-automatic eating** (what the prototype shipped, and what the GDD said) | A kill and a mouthful happened in the same frame, so nothing landed. The user asked for it to be felt |
| A pure animation over an instant grant | **That is the signature fake** — screen changes, sim doesn't. `CLAUDE.md` names it |
| Making ground food take time too | It would put a timer on the game's calmest action. The opening minutes are grazing and should stay frictionless |
| A press-to-eat key | Eating is not on a button — that is what lets left click be overwritten by any active |

## What's tied to it

- **The corpse array in `World`.** A dead creature now has an afterlife with its own state
- **`3` and the clones.** A clone eats where it killed, so a scattered swarm is a scattered set of bodies
  standing still — which is exactly when something can reach them
- **`EAT_TIME` scaling with force** makes the boss a six-second meal. That is the run's last beat and it is
  deliberately long
- **The gut and the level curve.** Everything eaten now arrives later than it did

## Conditions to reopen

**If the beat reads as waiting rather than as tension.** The fix would be shortening `EAT_TIME`, not
deleting the corpse — the interruptible meal is the part the user asked for.
