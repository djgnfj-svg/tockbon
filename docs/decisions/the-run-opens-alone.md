# The run opens with the host alone, and the camera is what makes it feel big

**Status**: valid — decided by the user 2026-08-14. **Reverses a number the prototype measured**, and the
reason it can be reversed is that the thing it was protecting moved.

## What was decided

**`START_CLONES` goes from 6 to 0.** The run opens with one body, force 1, which cannot split — so the first
level-up is what opens `F`, and that is the onboarding.

**And the field does not shrink.** The user's complaint after playing was that the map felt small; the answer
is **the camera**, which starts tight on the host and pulls back as the swarm grows. Close, one body reads as
a creature; far, forty read as a swarm.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Six starting clones** (what the prototype shipped) | Measured, and the measurement is now void — see below |
| **Giving the six a starting force** | It was the only way to keep them, and it invents a number for bodies that never came from a split. Deleting them closes the hole instead |
| **Shrinking the field** to fix "the map felt small" | The field is 3840×2160 and stays. **Small was a framing problem, not a size problem** |
| **A fixed camera at one zoom** | Then either the opening is a dot on a huge field or the late swarm runs off the screen. One of the two, always |

## What's tied to it

⚠ **`rules.gd` measured that zero was wrong, and that measurement was correct at the time.** The reason was
that with no clones, *the two swarm commands — the entire experiment — had nothing to act on for the first
minute.* **That reason is gone**: `F` is what grows the swarm now, and reaching it is one level-up away.
⇒ **This is a reversal by changed premise, not by disagreement.** If the swarm ever goes back to growing on
its own, six comes back with it.

- **The first minute is now one body eating grass**, and it is short by design. If play says it drags, the
  fix is the level rate, not free clones
- **`Swarm.force` never has an unexplained row.** Every body's force came from a split or from a kill
- **The camera zoom is in `look.gd`**, and the field size is in `rules.gd` — one is how it is framed and the
  other is what happens

## Conditions to reopen

**Play says the opening is dead time.** The cheapest fixes in order: raise the early level rate, then lower
`FORCE_START` requirements for the split, then — last — hand back starting clones.
