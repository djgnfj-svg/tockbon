# Disposition and force are two axes, and neither derives from the other

**Status**: valid (2026-08-13)

## What was decided

**Disposition** — attacks or flees — is carried by the individual and is not computed from anything.
**Force** — who wins if they meet — is also per-individual and varies inside one species.

The player's force is **the sum of the individuals' force, not the headcount**, because clones grow
separately by eating. Twenty well-fed clones beat forty bare ones.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **The prototype's rule: a critter flees once the swarm outgrows it** | It makes behaviour a function of one number. The user's model has weak animals that charge and strong ones that run, and that is four situations, not two |
| **Headcount as the comparison** | Clones wear parts from what they killed, so forty clones is not a quantity. Counting bodies erases the swarm's composition, which is a build |
| **Three bands — hunted / wary / hunting — derived from the force ratio** | Proposed and rejected in the same conversation: it still derives behaviour from force. The even-force band survives, but as **where the hands decide**, not as a behaviour state |
| **Colour-coding disposition on the body** | Each species carries its own colour; an overlaid tint fights it and both die. Disposition already reads from which way the thing is moving |
| **Showing force in a UI panel** | It has to be compared against the thing in front of you. Under the body, both numbers are in the same glance |

## What's tied to it

The GDD's tier reversal, and the prototype's `threat` field. The reversal still happens — **the same
aggressive animal eats your clones early and is eaten late** — but what changed is who wins, not what it
wants. `threat` as implemented is now one of the two axes, not both.

The codex unlock also hangs here: a species never eaten shows `?` instead of a force number, which is the
only thing that unlock does.

## Conditions to reopen

If four combinations turn out to produce two behaviours in play — if "weak and aggressive" and "weak and
fleeing" feel the same in the hand — the axes collapse and the simpler prototype rule comes back.
