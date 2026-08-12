# A magic circle is not a turret — it changes what the tower fires

**Status**: valid — **reversed and restored the same day (2026-08-12)**

> It was briefly marked reversed by a one-noun idea that dissolved the tower entirely. **The user walked
> back to this doc themselves** — *"my eye keeps going to the tower"* — and the one-noun branch is now
> filed as rejected in [Not everything is a magic circle](one-noun-for-everything.md).
>
> **What the round trip added**: the bullet is now the stated payload. *"Fit it into the tower and a magic
> bullet goes out — what flies changes with the circle you put in."*

## What was decided

There are **two objects, not one**: a **tower** that shoots, and a **magic circle** (a rune sigil) that is
fitted to it and **changes the bullet**. The circle never fires on its own.

The reason given: a circle that *is* a turret makes the whole thing a plain tower-defense game with
different art, and the assembly has nowhere to show up on screen except as another turret sprite.

⇒ **The dopamine moves from placement to fitting.** With a turret-circle the good moment is *where you put
it*; with a modifier-circle it is *the instant the tower's fire becomes something else*.

## What wasn't chosen

| Rejected | Why |
|---|---|
| The circle as the turret itself | Indistinguishable from any tower-defense game. `next-game.md`'s original framing |
| **Planted vs carried** as the one mechanic | It only exists if the circle is a thing that stands somewhere and shoots. With the tower shooting, there is nothing to carry |
| Placement as the core decision | Replaced by fitting. Where the tower stands may still matter, but it is no longer where the run is decided |

## What's tied to it

- `next-game.md`'s core-loop row — planted-vs-carried is gone from it, replaced by
  [Core defense is off](defense-shelved.md)
- The glyph-legibility risk in `next-game.md` survives and gets **worse**: a fitted circle is read at
  inventory size, not at world size
- Bullet visuals now carry the build. **How far a bullet may change is the open axis** — numbers only,
  trajectory, a different projectile object, or the firing pattern

## Conditions to reopen

None foreseen. Reversing it re-imports the plain-tower-defense problem this was taken to escape.
