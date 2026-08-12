# Prototype — the round trip

**Status**: built, unplayed.
**Implemented**: all of it — `src/sim/`, `src/view/`, `src/shell/`, seven nets, 60 checks green in 0.7s
**Accepted**: unseen. **Nobody has played it**, and a build existing is not acceptance

**The one question**: **is scattering and calling home a decision, or a chore?**
Everything else in the cell GDD is built on that round trip. If it is a chore, no amount of parts repairs it.

**Deliberately not in this build**: parts, slots, species currencies, chimeras, bosses, tiers, biomes,
meta unlocks, the 50% tax, clone-specific parts, and the `3 attack that` command. The GDD keeps all of
them; this build must not.

**The level-up pick stayed in** — decided by the user, and it earns its place: splitting automatically
makes the level-up a notification, and watching a notification is planning principle 1's failure mode.
Pressing a card is the smallest thing that makes growth an act. There are no species and no prices here,
so a card hands out clones or moves one multiplier, and **one of the three always grows the swarm**.

---

## Why the obvious prototype was rejected

"Split, scatter, recall on a field of food" was round 1's answer, and **it decides nothing**: with no
carrying and no threat, food eaten anywhere becomes the same number in the same pot. Fun and boring both
lead to "add parts on top". **Four rules are load-bearing**, and deleting any one collapses the round trip
back into a fetch chore:

1. **Carry, don't bank.** A clone holds what it ate. It enters the score **only** on absorption at the host
2. **A predator eats clones.** Contact kills a clone and its cargo. No HP, no combat system — one contact test
3. **Speed inequality: host > predator > scattered clone.** The host always escapes, an abandoned clone never
   does. This single ordering is the whole tension, and it costs three constants
4. **Local depletion.** A spot that was just eaten does not respawn for `FOOD_SPOT_COOLDOWN`. Without it, a
   tight ball beats a wide scatter and the width axis dies

**And `1 follow` gathers clones at the point where the key was pressed**, not at the host — they walk there
and wait; absorption still needs contact with the host. Gathering *at the host* lets the player park in
cleared ground while the clones take every step of the risk, which is backwards from what the design claims.
The press is a **placed rendezvous**: the host has to walk into ground it chose while the swarm was still out.

---

## The verdict — decided before building, measured after

Two runs, same seed, opposite play:

- **greedy** — scatter to the far edge, recall late
- **cautious** — keep the swarm inside one screen of the host

**Pass: greedy banks ≥ 1.4× cautious, and at least one greedy run loses a loaded clone off-screen.**
**Fail: the two land within 15% of each other** — then the verb is fake and the GDD's economy is built on
nothing. That is a number this build can produce and no amount of planning can.

⚠ **The most likely false positive**: the real game runs left-click, right-click and space *while* the swarm
is scattered, and this build has no combat, so herding is the only thing to do — busy-with-one-thing always
feels good. `space` dash exists here **only** to contest the hands. Fun here does not prove fun there.

---

## Behaviour

| Input | Effect |
|---|---|
| `WASD` | host movement |
| `space` | dash along the facing, `DASH_COOLDOWN` — the only way to outrun a predator |
| `1` | rendezvous: every clone walks to the cursor position at the moment of the press, and waits |
| `2` | scatter: clones spread out from where they stand and hunt on their own |
| click / `1` `2` `3` | pick a level-up card. The world is held still until one is taken |

- **Eating is automatic** for host and clones alike — walk within `EAT_RADIUS` and it goes in
- A clone's food goes into **its own body** and shows as the clone growing. **The host's mouth banks
  instantly**; that difference is what makes the host stay in front, with no tax rule to tune
- **Absorption**: a clone touching the host hands over what it carried and **empties, it does not die** —
  the swarm's size never drops on a harvest
- **Level**: one per `SPLIT_PER_BANKED` banked. It spends nothing and grows nothing by itself — it offers
  three cards, and taking one is what pays out
- **A predator killing a clone deletes the clone and everything it carried.** Predators ignore the host
  except by contact damage; the host has `HOST_HP` and the run ends at zero
- Predators spawn off-screen and one more arrives every `PREDATOR_INTERVAL`, so the run ends under pressure
  rather than at a clock

## Numbers — committed, not TBD

| Constant | Value | Why |
|---|---|---|
| `VIEWPORT` | 1280×720 | one screen is the unit of "can I see them" |
| `FIELD` | 3840×2160 | 3×3 screens; on one screen a recall costs no travel and scatter is free |
| `FOOD_MAX` / `FOOD_RESPAWN` | 500 / 6 per second | feeds ~40 mouths for five minutes |
| `FOOD_SPOT_COOLDOWN` | 12 s | local depletion — rule 4 above |
| `EAT_RADIUS` | 12 px | |
| `CLONE_CAP` | 40 (pool array sized 128) | a cap is required before any performance net can exist |
| `SPLIT_PER_BANKED` | 10 | full swarm near the 5-minute mark, so the cap is actually reached |
| `HOST_SPEED` | 320 px/s | crosses a screen in 4 s — hunting personally competes with herding |
| `PREDATOR_SPEED` | 260 px/s | below the host, above a scattered clone |
| `CLONE_SPEED_FOLLOW` / `_SCATTER` | 340 / 200 px/s | catches up when called; cannot escape when abandoned |
| `SCATTER_RADIUS` | 900 px | past the 640 px screen half-width, so scattered clones go off-screen |
| `EAT_PERIOD` host / clone | 0.6 s / 1.5 s | the host's mouth is worth ~2.5×, expressed as a speed, not a tax |
| `PREDATOR_START` / `PREDATOR_INTERVAL` | 6 / 60 s | |
| `DASH_COOLDOWN` | 0.8 s | |
| `HOST_HP` | 3 | one mistake is not the run |
| `RUN_LENGTH` | 5:00 hard stop | two opposing runs fit in fifteen minutes |
| `SEPARATION_MIN` | 16 px | |
| `NEIGHBOUR_CAP` | 8 | see below |

**Every one of these is a guess.** They are written down so that changing one is a decision with a
before-and-after, which is the thing six-places-for-one-number destroyed in the last game.

## Screen

A square host, forty smaller squares, coloured dots for food, larger dark squares for predators. Flat colour,
no sprites, no art pass. **A carrying clone is visibly bigger**, and it must be possible to tell a loaded
clone from an empty one across the screen — that is the only readability requirement in this build.

The end-of-run screen prints **banked total · clones lost · cargo lost with them · peak swarm size**.
Those four numbers are the experiment's output.

---

## Structure

Four places, and the rule each obeys. **The contract is the point** — `sim/` never touching the tree is what
makes every rule below drivable by a net with `.new()` and nothing else.

| Path | Rule |
|---|---|
| `src/sim/` | **Never touches the tree.** No `Node`, no `_draw`, no `Input`, no `get_node`, no `$` |
| `src/view/` | **Reads `sim`, never writes it.** Every drawing file exposes a `_paint(c: CanvasItem)` hook |
| `src/shell/` | **The only place that reads `Input`**, and the only place that wires `sim` to `view` |
| `src/look.gd` | **Every presentation constant, in exactly one file** |

**The swarm is one flat array, not dozens of nodes** — and the reason is not frame budget. 300 `Node2D`s
cost 0.065 ms and 300 `CharacterBody2D`s cost the same as 60 (measured, 4.7.1 headless); the engine was never
the problem. The reason is that `carried[i]` in a `PackedFloat32Array` makes **"a dead clone loses its cargo"
structurally true** — a swap-with-last removes it with no code that has to remember to. Held by reference it
is the exact silent fake `CLAUDE.md` names.

- One `RefCounted` holds `pos` `vel` `carried` `state` as packed arrays with a dense `count`. Index 0 is the host
- **`_process(delta)` only. No physics bodies, no second clock** — the five-defect seam is avoided by never
  opening it
- **Separation and eating run on the same grid structure, two instances**, rebuilt once a frame — clones at
  a 32px cell, food at 256px. One shared instance was the first plan and it was wrong: a 240px sense query
  on 32px cells walks 289 cells, which costs more than the naive loop it replaces. Either way the 60×N
  proximity pairs never exist — no `Area2D`, no signals
- **`NEIGHBOUR_CAP` is a hard iteration cap, not a time budget.** The grid degenerates to O(n²) in exactly one
  situation — `1`, when the whole swarm piles onto one point, which is the game's core verb. Bucket order is
  stable, so the cap is deterministic
- **Drawing is one `_draw()` on one `Node2D`**, with a `_paint(c)` hook cut out of it so a net can assert the
  arguments. **Not MultiMesh**: per-instance state is invisible headless in 4.7.1 (transforms read back as
  identity, colours as black, `multimesh_get_buffer()` size 0, no error), and it cannot give clones different
  bodies anyway

## The nets

**The wrapper reds below five nets**, so five had to land together. Seven did, running 60 checks in 0.7s.

1. `net_citations` — the one net `CLAUDE.md` names as worth rebuilding first. Scans `src/` `tests/` `tools/`
   for `docs/plans/N` paths and `file.gd:NNN` citations. **It rejoins wrapped comment lines two ways** —
   space-joined and tight-joined — because a space-join alone cannot see a mid-token wrap, which is the
   shape it exists to find. Two synthetic wrapped cases fail the scanner itself, not just the tree
2. `net_swarm_follow` — 40 clones at pinned literal coordinates, 60 steps. Mean distance decreased,
   **monotone every step** (final state alone cannot separate steering from a teleport), no step exceeds
   `speed * dt`, the host does not move, and the swarm settles instead of orbiting
3. `net_swarm_scatter` — bounding box grows ≥ 4×, **no pair closer than a literal 15px** (never read from
   the swarm's own field), headings span > 180°, and the leash holds out to ten seconds
4. `net_grid` — two clones at identical coordinates separate in one step, and resolve the same way twice;
   40 clones at a rendezvous, with the **pair-test counter** under a pinned ceiling and **above zero**.
   That counter is what proves the grid prunes instead of being a naive loop wearing a grid's name.
   Timing is a synchronous µs loop, never pumped frames
5. `net_eat_carry` — food at `EAT_RADIUS + 1` is not eaten and at `EAT_RADIUS - 1` it is; the host banks
   instantly while a clone carries; absorption empties the clone **without deleting it**; and **a loaded
   clone killed by a predator leaves the bank unchanged and its cargo nowhere in the swarm**
6. `net_paint` — the `_paint_cell` hook is driven treed with `pump_frames` and every argument captured:
   the count equals host + clones + food + predators, the host's captured position **equals `sim.pos[0]`**,
   four clones land on four distinct points, nothing is drawn at zero position or zero size, and a loaded
   clone is drawn bigger than an empty one
7. `net_cards` — the level fires at one bank-worth, three cards are offered, **one of them always splits**,
   the world freezes until a pick is taken, an unoffered card is refused, and then the same thing again
   **through the real shell**: `main.gd`'s own `_ready()` builds the panel, and `visible` is asserted on
   both edges. Hand-wiring the panel here would hide the line that wires it in the game

**Each check needs a mutation that turns it red, and the mutation must be confirmed to have landed.**
Timing anything with `pump_frames` measures nothing — **headless frame pacing is pinned at 6.900 ms
regardless of load** (measured); a performance net must loop `step()` synchronously against `get_ticks_usec()`.

## Traps already measured in 4.7.1

- **`Input.get_vector` normalises** — right+up is `(0.707, -0.707)`. A net asserting `1.0` is red for the
  wrong reason
- **`Input.warp_mouse` is a no-op headless** and `get_global_mouse_position()` stays `(0,0)` until a synthetic
  `InputEventMouseMotion` is fed — which does work. The `1` rendezvous point is testable only through it
- **`_physics_process` fired 12 times across 30 `process_frame`s** headless. Another reason to stay on `_process`
- **The input map is a corpse from the dead game** — `move_left` `jump` `toggle_assembly` `open_pick`. Delete
  them in the same edit that adds up/down and the two command keys
- **`snap_2d_transforms_to_pixel` is on.** Sub-pixel separation drift is invisible on screen while the numbers
  are fine. Check it before blaming the algorithm

---

## Bounds

- **Zero clones** — the opening state of every run, and it must be playable
- **`CLONE_CAP` clones all inside one rendezvous** — the grid's worst case, on the game's most-pressed key
- **Every clone dies far from home** — the run must be recoverable, not over
- **Zero food left in a region** — depletion must read as "move", not as a bug

## Acceptance

**The user plays two runs and reads the four numbers.** Nothing here is accepted until they say the round trip
felt like a choice — a build existing is not acceptance, and this doc does not close by inference.
