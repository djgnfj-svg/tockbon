# The August build is two species, one boss, three parts

**Status**: **partly reversed** by [the crow gives three parts](the-crow-gives-three-parts.md) — the species
list and the boss survive; **which species gives which part does not.**

## What was decided

~~**Crow and horse, plus the boss.** The horse gives all three parts — 말 다리 · 말 갈기 · 말 폐활량. The crow
gives none; it exists because **catching a horse at level 1 is too hard** and the opening needs something to
eat.~~

⚠ **Reversed on 2026-08-15.** **Crow and horse plus the boss still stands.** What went is the part
distribution: **the crow gives three** (날개 · 부리 · 발) and **the horse gives 다리 only.** The reason is this
doc's own premise read one step further — if catching a horse at level 1 is too hard, then a pool made only of
horse parts is a pool the player may never open.

⇒ **Two species still fill all four squares of the disposition × force table**, because disposition is rolled
per individual. A crow that decided to attack is free food; a horse that decided to attack is a real fight.
**Two species is not two behaviours.**

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Six species giving parts** — small animals · herd · horse · cheetah · lion · elephant | The design doc's grassland list. It is a habitat's eventual shape, not a first build's. Six species is six sets of numbers nobody has played once |
| ~~**Starting with the crow's part** (wings, the habitat's only back part)~~ | ~~Named by the user as food only. Wings stay unbuilt~~ **Reversed 2026-08-15** — 까마귀 날개 is built and it is the first part most runs will see. The cut was right that the crow is the opening's food; it was wrong that food and a part are different jobs |
| Starting with the lion, the loudest species in the table | The horse is the one that has to be caught **with the swarm** rather than with `WASD`, which is the mechanic under test |
| One species and the boss | Nothing to eat before the horse — the opening would be grass alone |

## What's tied to it

- **`3` and the swarm.** The horse is faster than the host on purpose; if the species list changes, the
  reason to press `3` changes with it
- ~~**The horse trait**, which needs all three horse parts — the whole table, so the trait is reachable in one
  run. A larger table breaks that~~ ⚠ **False since 2026-08-15**: the horse hands out one part, so **the trait
  cannot fire this build.** Recorded as a deferral rather than tuned away — see
  [the crow gives three parts](the-crow-gives-three-parts.md)
- **The card pool**, which rolls only from what has been eaten. With two species the pool is small enough to
  see the rule working

## Conditions to reopen

**Play says the field is empty.** More species that give *no* part is the cheap fix and it costs almost
nothing — the bill only lands on the ones that drop parts.

⇒ **That condition fired on 2026-08-15, on the first play session, and it fired exactly as written.**
The user played the build, said the floor was a carpet of food and the field needed animals, and named
four: 다람쥐 · 코끼리 · 치타 · 사자. **All four give no part** — `Parts.DROPS` is untouched and the pools are
still 까마귀 셋 + 말 다리. The bill was six rows in six `SPECIES_*` tables, a colour each, and three new
columns (`SPECIES_WANDER` · `SPECIES_HUNTS` · `SPECIES_HERD`).

**The rejected row above is the one that came true**: *six species giving parts* was rejected as "a habitat's
eventual shape, not a first build's", and what shipped is **seven species where only two give parts.**
Splitting "is on the field" from "drops a part" is what made the cheap version possible, and this doc had
already named that split as the escape hatch.

⚠ **What this does NOT reopen**: the part pools, the horse trait, or the card economy. A lion is something
that walks at you; eating it opens nothing.
