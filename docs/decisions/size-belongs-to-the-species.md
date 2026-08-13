# A creature's size comes from its species, not from its force

**Status**: valid — decided by the user 2026-08-14. Replaces the single radius formula outright.

## What was decided

**Every species carries its own base radius.** Force adds to it, but **never more than 1.5×**.
A crow at force 100 is a large crow. It is never the size of an elephant.

The user's test, in their words: a hundred-force crow must not be bigger than an elephant.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **One formula, `BASE + force × PER_FORCE`** | What the plans had. At the new scale it puts the boss at 493px and lets a strong crow outgrow a horse. **Size stops meaning species** |
| **Same formula with the coefficient divided by ten** | Keeps the ordering bug — it only makes it take a bigger number to hit. The failure is the shape, not the constant |
| **Square root of force** | Bounded and it looks right, but it is still one curve for every species, so a big enough crow still passes a horse |
| **Hand-written numbers per species, no force term at all** | Then a strong individual is invisible, and individual variation is the thing that makes a field of crows readable |

## What's tied to it

- **Species order is structurally preserved**, not preserved by choosing careful numbers. 1.5× of a crow
  cannot reach a horse's base, whatever force does
- **A big individual is still recognisable** — half again as large is visible at a glance
- **This is a sim value, not a look value.** The radius decides reach and contact, so it lives in `rules.gd`
- ⚠ It also settles a generation constraint: `tools/pixel/` never has to draw the same animal at five sizes.
  **Squash and stretch are free on numbers and destructive on pixels** — the base is art, the 1.5× is code

## Conditions to reopen

**A species is added whose whole identity is growing** — something that starts tiny and ends enormous.
Then it gets its own multiplier, not a new formula for everyone.
