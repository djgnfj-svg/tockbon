# No inventory — receiving includes deciding where it goes

**Status**: valid

## What was decided

There is nowhere to stash. Receiving a glyph means deciding **which layer it goes in** on that screen,
and declining makes it disappear.
All that remains in the assembly window is reordering what is already equipped.

The opposite was decided that same morning and reversed.

## What wasn't chosen

| Rejected | Why |
|---|---|
| Stash it and equip from the assembly window | **It creates "I don't have to decide yet", deferring the weight of the choice** |
| Auto-slot into an empty layer | Layer order *is* the spell (spread→blast ≠ blast→spread), so **the permutation choice disappears** |

The stash existed to avoid the second, but **letting the receiving screen choose the layer removes that worry.**
Two screens merged into one.

## Why this side

This game is about **growing one magic circle across a run**, not swapping per situation.

So **"receiving" becomes one act with "discarding".** With a 2-layer circle full, a new glyph means choosing what it
pushes out. The three-pick's logic (what you **don't** take separates builds) gains "what you discard".

Genre convention agrees (Dead Cells · Skul · Isaac · Noita). But the game-side reason is stronger than the convention.

## What's tied to it

| Where | How |
|---|---|
| `GDD.md`, There is no inventory | Body text |
| `plans/3.done/levelup-and-three-picks.md` | Why the three-pick window must be two-step (choose → place in a layer) |
| The assembly window, `circle_window.gd` | No stash UI is built |
| Gear | Step on it and decide there whether to wear it. Same discipline |

## Conditions to reopen

**~~When a "bag" slot opens~~ — that condition is gone.** The user **deleted bag, potions and ink.**
Gear slots are staff, robe and boots, and there is nothing to carry.

**The only remaining revival condition is ink** — the idea itself was good (painted onto a layer, reusing the
permutation axis), and it was dropped not for its effect but because **it must be carried before painting.**
⇒ **A form you don't carry** (e.g. it paints onto a layer the moment you receive it) reopens it.

**And a test line emerged** — **growing during a run is an inventory; visible only in town is a list.**
The town assembly bench's unlock list does not fall under this prohibition.

## Exception — rune ownership (`rune-lock-and-receiving.md`)

`Progress._owned_runes` grows during a run (the bull's reward grants fire) and on its face fails the test
line above. It is exempted, not silently let through:

- A stash is **a menu you choose from.** With one rune seat and a fixed starting kit, the owned set after the
  bull is `{none, fire}` — swapping back to none is not a build decision, it is undoing a reward
- The rejected branch above ("stash it, equip from the assembly window") was rejected because it defers the
  weight of a choice. **There is no weight here to defer** — fire strictly adds, nothing is traded off
- What the field records is "what you have been granted", the same category as town's unlock list, just kept
  run-scoped because there is no town yet

**The bound**: this stops being exempt the day a rune seat count exceeds one. A second seat turns "which rune
goes where" into a real build decision, and at that point ownership becomes exactly the stash this doc argues
against.
