# The next game — top-down magic-circle core defense

**One line**: hold a core at the centre while monsters come from every direction, and **draw magic circles
as the turrets that hold them off.**

**Status**: direction settled in conversation on 2026-08-12. **Not a spec.** The build order and the numbers
are still open — what is fixed is the shape and what was thrown away.

> **This document survives the reset.** Everything else in `src/`, `tests/net_*` and the rest of `docs/` is
> being deleted; the AI harness (`CLAUDE.md`, `.claude/`, the net runner, `tools/pixel/`) and this file carry over.

---

## What is settled

| Axis | Decision |
|---|---|
| View | **Top-down.** Two-direction sprites are enough — Vampire Survivors and Brotato ship that way |
| Structure | **Defend a core at the centre.** Monsters arrive from every direction and **some attack at range** |
| The core loop | **Draw magic circles, place them as turrets, upgrade the castle.** That is the fun, not the swordplay |
| Map | **One map.** The variety budget goes into monsters instead |
| Genre | Roguelike — a run's identity is which circle you took in |
| Art | **2D.** The `tools/pixel/` ComfyUI pipeline is the one proven asset from the old project |

### The one mechanic that makes it a game, not a tower-defense clone

**A circle can be planted or carried.**

- **Planted** — strong, but it holds one spot only
- **Carried** — weak, but it follows you

That is a live choice every time a circle is assembled, and it gives the same glyph two different values
depending on where it ends up.

### Why ranged monsters are load-bearing, not flavour

Melee-only attackers are solved by walking backwards. **Ranged ones break that** — and specifically,
**a ranged monster shooting a planted circle forces the player to leave the centre and go kill it.**

```
plant a strong circle  →  ranged monster shoots it from outside its reach
                       →  go out and kill it, or lose the circle
                       →  "where should I be standing right now" is the question every second
```

⇒ **This is where close-quarters combat earns its place.** It is not bolted on for feel; the structure asks
for it. The user's own taste (they like melee) and the defense structure meet here rather than fighting.

### What follows and is not yet decided

- Planted circles need **durability**, or nothing is at stake when a ranged monster shoots one
- Whether a planted circle can be **picked back up** — recoverable means flexible, permanent means each
  placement is heavy
- **How many can be planted at once.** This is the resource constraint, and the user named the principle:
  **"you can't open everything"**

---

## Why the old game was thrown away

**None of this is inference. It is what the user said.**

- **They like melee combat.** Eight months went into a ranged wizard game
- **They refunded Noita** for being boring. The pixel-simulation genre is not to their taste
- The water/fire simulation went in because **"I thought the AI would be good at simulations"** — a tooling
  judgment standing in for a design one
- **Eight months produced no moment that was fun**, and the game was never once played end to end

The simulation also cost more than it earned. It was **measured**: water never touched a monster
(`monster.gd` contained the word `water` zero times), stage 1 poured none at all, and the whole codebase
carried integer-determinism constraints — no `float`, no `sqrt`, no `randi` — to keep it lockstep-safe.
The tick budget ran **84ms against 50ms**, and hit detection ran on the 20Hz tick, which is why a bolt could
pass straight through a monster and why `MOVE_SPEED_PX` could not be retuned.

⇒ **Dropping the simulation releases all of it at once.** One clock instead of three, floats allowed,
hit detection where it belongs.

---

## Constraints

**Ship in December 2026.** Roughly 12 weeks of building plus 4 weeks of balance, bugs, the Steam page and
review. Everything below follows from that date.

- **Multiplayer is cut.** It roughly doubles build time and cannot coexist with December.
  **Re-open it after launch** — the biggest recent hit in the neighbouring genre (The Spell Brigade,
  1M+ copies in early access) is co-op, so this is a deferral, not a rejection
- **No 3D.** A first completed project plus a new discipline plus four months does not fit.
  Top-down does not force 3D and does not even force 8-direction art
- **One deep system: the magic circle.** Everything else stays minimal
- The old numbers are gone with the old game. **Nothing here inherits a value from it**

---

## The open risk — nobody has checked whether the glyphs read apart

**The core is "assembling a circle", and assembly only means something if you can tell the pieces apart.**
That was never confirmed, and the old project recorded the warning signs:

- Eight socket-ring candidates were shown across two rounds and **rejected both times** — decorative bands
  whose meaning was not in the picture
- **Two glyphs are confirmed to separate** (spread and blast). **Six has never been laid out and looked at**
- Two rings already collide (`ring_accel` against `ring_spread`) at the band thickness in use
- Encoding rarity as branch count **failed across 24 generated images** — the generator cannot count

A survivors-like build system wants **20-40 pieces**. Six is unverified.

⇒ **Generate 10-12 glyph candidates and lay them on one board before committing to the core.**
It is free and local (`tools/pixel/`, ~6-25s an image). If several mush together, black monochrome geometry
is the wrong carrier and another axis (colour, icon, silhouette) has to take over — **and that is much
cheaper to learn now.**

---

## How the direction was reached, so it is not re-litigated

Eight directions were opened and closed in one conversation: hit feel → the tick rate → cutting the
simulation → survivors-like → spellblade → melee → auto-attack → defense. **The turning points were the two
places the user reported their own taste** (they like melee; they refunded Noita), not any argument about
what would sell.

**The rejected branches, with why, belong in `docs/decisions/`** once that folder is rebuilt. The ones worth
keeping: side-view floor-based defense (dropped — the floors, not the circle, would have been the novelty,
and a circle's shape wants angles rather than storeys), and the spellblade with a weapon list
(dropped — a weapon roster competes with the circle for the same job).
