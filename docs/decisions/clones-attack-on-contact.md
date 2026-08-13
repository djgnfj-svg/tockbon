# Clones attack whatever they touch, with no order given

**Status**: valid — decided by the user 2026-08-14. Narrows
[Clones are stupid by default](clones-are-stupid-by-default.md) rather than reversing it.

## What was decided

**A clone attacks anything it makes contact with, automatically.** Send the swarm with `3` and it fights
without further input. No target is selected, nothing is assigned.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Only attacking what `3` was pointed at** | Makes `3` a targeting command, and target selection is the thing this game refused from the start |
| **Clones never attack — bodies and food only** | Then the swarm is scenery in every fight and the host does all the damage, which is the opposite of what the swarm is for |

## What's tied to it

- **It has a price, and the price is the point.** The crow stands still until hit and then fights back
  ([Hunting and the boss](../design/hunting-and-the-boss-ko.md)), so **a swarm left scattered in a field of
  crows grinds itself down.** Spreading out to herd a horse costs clones to the crows you spread across
- **Herding damages by itself.** Closing on a horse means clones touching it, which means it dies to the
  closing rather than to a separate attack step
- **It stays consistent with stupid-by-default** — no decision is being made, the rule is "touch, hit"

## Conditions to reopen

**Play says the swarm dissolves before it reaches anything.** The fix is the crow's counter-attack, not
turning auto-attack off.
