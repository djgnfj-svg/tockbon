# The next game

**Status**: **a cell autobattler.** Islands on a node map, a squad of square cells, and the island's
특산물 bolted onto the soldiers that survived it. **Target: end of August 2026** — a finished thing,
not a shippable product.

⇒ **The design lives in [세포 군대 GDD](design/cell-army-gdd-ko.md) and nothing is built yet.**
`src/` was emptied on 2026-08-16 at the tag `v2-openfield`.

**One line**: **먹을 것을 고르러 간다.**

**Why cells, still**: almost no art is needed — a square with parts drawn on it is code, not pixels — and
the theme survived two direction changes because of that. **What did not survive** was "you steer a
growing mass": there is no host to steer any more, the battle is automatic, and the hands are spent on
**where to land whom** and **what to bolt onto whom**.

## The two resets

| | Deleted | Tag | What it was |
|---|---|---|---|
| 1st | 2026-08-12 | `v1-sim` | Eight months of side-view magic action + a pixel water/fire simulation. **No moment in it was fun**, and 34 features had shipped with 5 acceptance checks open |
| 2nd | 2026-08-16 | `v2-openfield` | An open-field cell game — one host, a swarm that splits and rallies, eleven part slots, a grassland with seven species and a boss. Five plans in four days, **25 nets and 3541 green checks**, and the user played it and said *"그냥 재미가 없다"* |

⚠ **The second one was not a failure of execution.** It was built, verified, and measured. What it lacked
was a reason for its own central mechanic — see the `why-multiply-ko` paragraph in `CLAUDE.md`, which
records the arithmetic: **`F` cost nothing and `V` undid it for free, so splitting was never a decision.**

**Do not restore code from either tag.** Both were written against constraints this design does not have.
**The reasoning in `docs/` is the thing that carried over, and it is most of what is in there.**

---

> ⚠ **Everything below is void — it is the framing from before the FIRST reset**, kept because
> `docs/decisions/` points at it. On 2026-08-12 the direction changed five times in one day
> — core defense → one-noun circles → summon+build+fit → magic-circle survivors-like → cells — and
> **the magic circle was dropped entirely** ([why](decisions/magic-circle-dropped.md)); the defense
> structure is shelved intact ([why](decisions/defense-shelved.md)).
>
> **What survives every reset**: **[the planning principles](planning-principles-ko.md)** — the eight
> judgments that came out of that day. The second of them, *planning cannot decide whether something is
> fun*, is the one both resets proved.
---

## Void — the dropped framing, kept for context

**One line**: hold a core at the centre while monsters come from every direction, and **draw magic circles
as the turrets that hold them off.**

> **This document survives the reset.** Everything else in `src/`, `tests/net_*` and the rest of `docs/` is
> being deleted; the AI harness (`CLAUDE.md`, `.claude/`, the net runner, `tools/pixel/`) and this file carry over.

---

## What is settled

| Axis | Decision |
|---|---|
| View | **Top-down.** Two-direction sprites are enough — Vampire Survivors and Brotato ship that way |
| Structure | **Defend a core at the centre.** Monsters arrive from every direction and **some attack at range** |
| The core loop | **Summon soldiers from a circle, build towers, fit circles into them** — see [Core defense is off](decisions/defense-shelved.md) |
| Map | **One map.** The variety budget goes into monsters instead |
| Genre | Roguelike — a run's identity is which circle you took in |
| Art | **2D.** The `tools/pixel/` ComfyUI pipeline is the one proven asset from the old project |

### The one mechanic that makes it a game, not a tower-defense clone

**The circle is fitted into the tower and the bullet changes.** Soldiers come out of a summoning circle on
their own; towers are built; **what a tower fires is decided by the circle in it.** Full doc:
[Core defense is off](decisions/defense-shelved.md).

**There is no preparation phase.** The level-up is the only pause, and fitting happens in it.

> Three mechanics previously stood here — *planted vs carried*, *ranged monsters forcing the player out*,
> and *one noun for the whole game* — and all three are gone. They are in
> [`decisions/`](decisions/README.md) with the reasons.

### What follows and is not yet decided

- **What the player's body does during a wave.** The last unfilled hole
- **What the circles are, and how many.** The run's identity is which ones you took in
- **How many towers can stand at once.** This is the resource constraint, and the user named the principle:
  **"you can't open everything"**
- Whether a circle appears instantly or **has to be drawn by someone who walks there** — raised and
  unresolved; it collides with the build-time question in `idea-log-ko.md`

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

**The rejected branches are in `docs/decisions/`** — three docs covering the simulation, multiplayer, and the
side-view/top-down fork with the four alternatives that lost to it. **Do not re-argue them from here**; that
folder holds the reasons, and this one holds only what is being built.
