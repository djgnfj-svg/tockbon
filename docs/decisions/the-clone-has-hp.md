# A clone has hit points, and is not killed by one touch

**Status**: valid — decided by the user 2026-08-15, in the words *"분신이 왜 즉사인지 모루겠음 분신도 체력을
가질꺼야."* **Reverses [the grassland field](../plans/3.done/grassland-field.md)'s own line**, which said a
creature reaching a clone killed it outright.

## What was decided

**A clone takes damage like anything else and dies when its hp reaches 0.** Its cargo, its force and its worn
part are lost at that moment and not before.

**Hp is a stored column on `Swarm`**, written at birth from that body's own force × `Rules.HP_PER_FORCE` —
the same written-never-derived rule force already obeys
([why](force-is-stored-not-derived.md)), and for the same reason: `F` halves force, and a derived ceiling
would change a body's health as a side effect of a keystroke.

⇒ **It is conserved across the split, never recomputed to full.** The two halves' hp sums to what the parent
had. The host is not in this column at all — its health stays `World.host_hp`, one number with one owner.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **One touch kills a clone** (the plan as written) | A clone is a body like any other, and one-touch death made a wide swarm unplayable rather than merely costly. Spreading out to herd is supposed to have a price you can watch, not a cliff |
| **Recomputing both halves to full at the split** | It reads tidier and it makes `F` a **heal button** — a body one hit from death presses one key and comes back whole. Splitting is not a power-up is the rule the whole force column exists for |
| **Deriving hp from force every frame** | Then `F` halves health as a side effect and a part that adds force silently heals. The same argument that made force stored |
| **A second health number for the host, in the same column** | A value counted in two places diverges, and this is the one number a run ends on. `Swarm.hp[0]` is a sentinel nothing reads |

## What's tied to it

- **The cost model for a wide swarm.** [Clones attack on contact](clones-attack-on-contact.md) said the price
  of spreading out among crows is clones. That price is now paid in chips rather than in whole bodies — same
  direction, different resolution
- **The flat swarm.** Everything a dying clone loses is lost by the row swap, with no code that has to
  remember to drop it. That is why hp costs one column and not a cleanup path
- **The split's guard.** A body that cannot be halved without producing nothing is not halved — force and hp
  are the same guard, and without the hp half a 1-hp body splits into a 0-hp parent that is alive
- **A part worn off a corpse moves hp as well as force**, and a clone has no ceiling, so a part both raises
  and refills it. Deliberate, one line to change, and only play can judge it

## Conditions to reopen

**Play says losing a clone stopped meaning anything.** The fix is the number, not the mechanism —
`Rules.HP_PER_FORCE` is what makes a clone one hit or three.
