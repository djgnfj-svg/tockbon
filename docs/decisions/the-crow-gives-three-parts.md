# The crow gives three parts and the horse gives one

**Status**: valid — decided by the user 2026-08-15, in two answers: *"까마귀 부품 날개 부리 발 3개로 일단
지정"* and *"말은 다리만있음 지금은."* **Partly reverses
[the August build is two species](august-scope-two-species.md)**, which gave the horse all three parts and the
crow none.

## What was decided

**까마귀 날개 · 까마귀 부리 · 까마귀 발 are rows in the part table, and the crow drops them.** 말 다리 is the
horse's only droppable part this build.

**말 갈기 and 말 폐활량 stay in the table and leave both pools** — the corpse roll and the card roll — through
a `DROPS` column on the row itself. They are plan 3's rows and deleting them is out of scope; a hand-kept list
of droppable ids beside the table is what diverges the day a row is added.

⇒ **The card pool now opens off the crow**, which is the common creature, standing still, killable on the
first minute. The previous pool was entirely horse parts against a horse that cannot be caught in a straight
line and arrives about once every 150s, so **a player who never cornered one saw zero cards for a whole run.**

⇒ **까마귀 발 and 말 다리 occupy the same square.** That is where card displacement comes from — the plan's own
acceptance question, *did you refuse a card because of what it would push out*, has no other way to fire.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **One multi-slot part** (`말 다리` widened to hindquarters, taking two squares) | Proposed as the cheapest way to make a card displace something. Two single-slot parts sharing one square buys the same thing with **no sim code at all** — the eviction path already exists and is already checked. And `SLOTS[말 다리] = [HINDLIMBS, LUNG]`, the other version, makes 말 다리 and 말 폐활량 mutually exclusive for a reason nothing in the design explains |
| **Deleting 말 갈기 and 말 폐활량** | They are built, checked and drawn. A row that exists and is not handed out costs one column; a deleted row costs plan 5 the work again |
| **One crow part** (the wing alone) | The user named three. One active is also not enough to make a key binding a decision — the pool has to offer something that competes with what is already on the click |
| **Lowering `Rules.HORSE_TRAIT_COUNT` to 1** so the horse trait stays reachable | That is a design change nobody asked for, made silently to keep a number looking used. **The trait is unreachable this build and it is recorded as such** — see below |

## What's tied to it

- **The corpse's part roll can now produce an active.** With every droppable part passive, the branch that
  fires a worn active on a clone was dead code in play and only a hand-written net could reach it
- **`Rules.HORSE_TRAIT_COUNT` is 3 against a one-part horse, so the horse trait cannot fire.** A known
  deferral, not a bug: the constant keeps its value and carries the sentence. Plan 5 either opens the other
  two rows or lowers the count, and both are one line
- **[The August build is two species](august-scope-two-species.md)'s "wings stay unbuilt" row is reversed**,
  and its "the horse trait needs all three horse parts, so it is reachable in one run" bullet is now false
- **The multi-slot guards in `Body`** — `hp_max()`, `breath_max()`, `_recompute_traits()` — stay unreachable
  in play. Their comment says they go wrong silently the first time a two-square part lands, and that stays
  true and stays untested by anything but synthetic coverage

## Conditions to reopen

**Play says the crow's three parts crowd the pool**, or that the horse feels like it gives nothing for how
hard it is to catch. Both are the `DROPS` column and nothing else.
