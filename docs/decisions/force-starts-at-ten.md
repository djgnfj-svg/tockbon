# The host starts at force 10, and every monster is multiplied by ten with it

**Status**: valid — decided by the user 2026-08-14. **Partly reverses**
[The run opens alone](the-run-opens-alone.md): the run still opens with no clones, but the opening body
can split immediately.

## What was decided

**`FORCE_START` goes from 1 to 10.** Force 1 cannot halve, so the first `F` was one level-up away and the
opening was a single square eating grass. At 10 the first thing the player does is press `F` — **splitting is
the tutorial**, not something the tutorial leads up to.

**Every monster is multiplied by ten in the same breath**: crow 1 → **10**, horse 3–4 → **30–40**,
boss 12 → **120**. The ladder is unchanged in shape; only the unit moved.

**And the word "cell" is dead — say 경험치 (experience).** Force eaten is experience, experience is what
levels. The intermediate noun was making the same quantity read as two things.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Keeping force 1 and making the first level arrive in 20 seconds** | Fixes the clock, not the hands. The player still watches before they act, and the first thing they learn is waiting |
| **Keeping force 1 and writing a tutorial line** | Turning dead time into intended dead time. Planning principle 1: the hands must never be idle |
| **Force 2** (the smallest number that can split) | One split, then the same wait. Ten gives a swarm on the first press |
| **Leaving monsters at the old scale** | A force-10 host against a force-1 crow is not a game, it is mowing |

## What's tied to it

- **The experience curve has to be re-cut, and the numbers are deliberately not fixed here.** The user's words:
  set them sensibly and tune during play. What is settled is the *shape* — **the requirement rises per level**;
  the first level is one crow's worth, the tenth is many
- **Boss 120 is just a large number.** Damage is the attacker's force in both directions, and no exception
  was added for it. "One touch ends the run" is an arithmetic consequence, not a rule
- ⚠ **The radius formula does not survive this** — see
  [Size belongs to the species](size-belongs-to-the-species.md). `13 + force × 4` puts the boss at 493px
- **`the-run-opens-alone`'s reason still stands, its mechanism does not.** `START_CLONES` is still 0 and the
  field still does not shrink. What died is "force 1, which cannot split, so the first level-up is the onboarding"

## Conditions to reopen

**Play says the opening swarm is too big to read.** The first fix is the split ratio, not `FORCE_START` —
handing the player fewer bodies puts the idle minute back.
