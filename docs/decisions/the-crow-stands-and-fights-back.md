# The crow does not flee — it stands still until hit, then hits back

**Status**: valid — decided by the user 2026-08-14.

## What was decided

**The crow is slow and does not run.** You walk up to it and kill it — three hits from the host.
**It is passive until struck**, and once struck it fights back. It does not one-shot the host.

It is the species you kill with the attack key, opposite in every way to
[the horse, which is herded](the-horse-is-herded-not-outrun.md).

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Slow and simply harvested** | Then the early field is mowing, and the attack key has nothing to teach |
| **Fast, scattering in short hops** | A second reaction-speed species. The stage already has one thing you chase |
| **Aggressive from the start** | It would make the opening field hostile, and the crow is what the opening is made of |

## What's tied to it

- **`is_hunter_of` and the swarm-size threat model stay dead.** The crow is not calculating whether it can
  win — it is reacting to being hit. Disposition here is a rule, not a comparison
- **It is what makes [clones attacking on contact](clones-attack-on-contact.md) cost something.**
  A swarm spread across crows takes damage it did not ask for
- **Three hits is against the host's starting force of 10**, so crow HP is written against that — it is not
  a hit counter

## Conditions to reopen

**The early field feels safe rather than easy.** The lever is how hard it hits back, not whether it flees.
