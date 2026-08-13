# The August build is two species, one boss, three parts

**Status**: valid — decided by the user 2026-08-14.

## What was decided

**Crow and horse, plus the boss.** The horse gives all three parts — 말 다리 · 말 갈기 · 말 폐활량. The crow
gives none; it exists because **catching a horse at level 1 is too hard** and the opening needs something to
eat.

⇒ **Two species still fill all four squares of the disposition × force table**, because disposition is rolled
per individual. A crow that decided to attack is free food; a horse that decided to attack is a real fight.
**Two species is not two behaviours.**

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Six species giving parts** — small animals · herd · horse · cheetah · lion · elephant | The design doc's grassland list. It is a habitat's eventual shape, not a first build's. Six species is six sets of numbers nobody has played once |
| **Starting with the crow's part** (wings, the habitat's only back part) | Named by the user as food only. Wings stay unbuilt |
| Starting with the lion, the loudest species in the table | The horse is the one that has to be caught **with the swarm** rather than with `WASD`, which is the mechanic under test |
| One species and the boss | Nothing to eat before the horse — the opening would be grass alone |

## What's tied to it

- **`3` and the swarm.** The horse is faster than the host on purpose; if the species list changes, the
  reason to press `3` changes with it
- **The horse trait**, which needs all three horse parts — the whole table, so the trait is reachable in one
  run. A larger table breaks that
- **The card pool**, which rolls only from what has been eaten. With two species the pool is small enough to
  see the rule working

## Conditions to reopen

**Play says the field is empty.** More species that give *no* part is the cheap fix and it costs almost
nothing — the bill only lands on the ones that drop parts.
