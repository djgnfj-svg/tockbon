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
| `plans/1.ready/levelup-and-three-picks.md` | Why the three-pick window must be two-step (choose → place in a layer) |
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
