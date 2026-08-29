Type: task
Status: resolved

## Answer

**A body walks a straight line now.** Straight east is 19 조각 with no turn; the four probe walks sit
**0.00 · 0.41 · 0.49 · 0.28 조각** off their own straight line, against **4.06 · 2.47 · 2.22** before.

**What is in the code**: an orthogonal step costs 10 and a diagonal 14 (`Rules`); the flood pops the
cheapest 조각 first out of a binary heap (`IntHeap`); equal-cost steps break toward the goal; the route
is pulled out of the field the moment an order is given and hung on the body, string-pulled through
`can_step`. **The flow field is untouched as the fallback**, and reservation, the two-tile hold, the
queue at a neck and `keep_level` all survive.

⚠⚠ **The bar is the pulled route, not the raw field descent** — see Acceptance 1. The descent still
deviates 1.97 and 1.39 on two of the four walks and that is the tie-break key working as chosen.

**Nets: 통과 521 · 실패 59 → 통과 629 · 실패 59.** ⚠ **Measured against a control tree, because the
island was re-baked by another session mid-round and the raw before/after is not a like-for-like
comparison.** With today's island and this ticket's change reverted: **실패 59** (plus six
`net_fx_view` rows that were an artefact of the control copy's missing texture-import cache). ⇒ **This
ticket adds no red and repairs no red.** The two `net_tiers` rows that changed are the same assertions
with their labels restated in cost units, red before and red after.

**What this ticket did NOT do**: the move line on screen (티켓 11), the body clipping the stair
(티켓 22), group orders (티켓 02). Nothing was drawn this round.

### ⚠ Two defects found while measuring, and neither is fixed here

1. **`can_step` is asymmetric on diagonals.** The shoulder test reads `from_level`, so a diagonal off a
   stair onto the floor is legal while the reverse is refused. **The flood expands away from the
   target, so it records the direction the body does NOT walk** — a one-way door reads as two-way in
   the field. Found twice independently, from opposite directions.
2. **`net_tiers`'s `FIXTURE_TIERS` is broken.** It spells its plateau `1`, which was widened on
   2026-08-26 to mean level 1, so **the fixture has no level-2 조각 at all.** `grid.gd`'s header warned
   this fixture would have to be re-read and it never was. Several of the standing red assertions are
   this, not the missing stair the roadmap blames.

### ⚠ One thing nothing measures, recorded rather than covered

**Loosening `step_toward`'s admission from「strictly cheaper」to「not more expensive」reddens nothing** —
not the nets, and not a 100-second run on the real island, which came out identical to the decimal.
It is written into the function's comment beside the existing `<=` note. **No check was built around
that mutation**, because a check written around one mutation passes because somebody wrote it around
the mutation.

# The body walks a crooked line — **a straight walk arcs to the top of the board**

## What "done" looks like

**A body told to walk across open ground walks a straight line, and the walk bends only where the
ground makes it bend.**

## Where this came from

**2026-08-29, the user saw it in the game and said the movement looks wrong.**

**Measured the same day** with a throwaway probe (`prototypes/stairs/walk_probe.gd`), on an empty
24 x 12 board, A at (2,6) and B at (20,6):

```
........ooooooo.........
.......o.......o........
......o.........o.......
.....o...........o......
....o.............o.....
...o...............o....
..A.................B...
```

**All four probes came out this shape.** The straight walk is 18 조각 with no turn; what came out is a
detour to the top of the board and back, and it costs the same because of the two defects below.

## Why — two causes, both in `Grid`

1. **Uniform cost on an 8-connected flood.** `flow_field` walks all eight neighbours and adds **1** to
   every one of them, diagonals included. **A diagonal is free**, so a straight line and an arc that
   runs to the top of the board are the SAME cost. Every equal-cost detour is on the table.
2. **Ties are broken by the order of `NEIGHBOURS`**, which begins at north-west. Among equal-cost
   neighbours the step always goes up-left, which is the direction the arc leaves in.

## ⚠ What already stands here — do not build it twice

| What | Where |
|---|---|
| **The flood, and the descent** | `Grid.flow_field` and `Grid.step_toward` — the only two walkers |
| **The step rule, height and shoulders included** | `Grid.can_step`, and the stair-flank half in `Grid._stair_face_open` |
| **The 0.5 s field cache**, one field per target tile | `Battle._field_for` / `_age_fields` |
| **The order** — the player sends one body to one 조각 | `Battle.order_walk` → `soldier_order` → `_phase_orders` |
| **The two-tile hold and the queue at a neck** | `Grid._hold` / `_release_except`, `Battle._settle` |
| **`keep_level`** — a body that may not leave its own level | `Grid.step_toward`'s last argument |

## ⚠ What already died here

**Nothing.** `log.md` carries no reversed decision about walking, and the only deletion near it is the
water half of `grid.gd` (2026-08-29, with the boats). **The flow field itself has never been replaced**
— `grid.gd`'s own header records that a greedy 8-way descent was measured stalling on five of
twenty-six pairs, which is why the field exists. **That measurement stands and this ticket does not
touch it**: the field stays, and it stays the always-valid fallback.

## ⚠ Which nets measure this, and are they green

**Baseline, measured 2026-08-29 before any change: 통과 521 · 실패 59** (fingerprint `B19CE6CE2788`).
The 59 are the known state — most of them in `net_tiers`, because the island carries no stair at all.

| Check | Now |
|---|---|
| `net_tiers._the_walker_will_not_cut_a_corner` — `field[start] > 2` | ✅ **green, and `2` is a hop count** |
| `net_tiers._the_field_climbs_only_by_the_stair` — hop counts 3 · 4 · 5, and `cheapest_high == stair_cost + 1` | ⚠ **PARTLY RED already** — four of its assertions fail, and **four more are green and hardcode hop counts** |
| `net_tiers._bricking_up_the_stair_seals_the_plateau` | ⚠ **already RED**, four assertions |
| `net_tiers._the_real_island_still_has_a_route` — nothing cut off | ✅ green, reads only `UNREACHABLE` |
| `net_islands` walker — every landable coast tile reaches (5,8) | ✅ green, reads only arrival |

⚠⚠ **WHY THOSE TWO ARE RED, AND IT IS NOT WHAT THE ROADMAP SAYS.** The roadmap explains the 59 with
「the island carries no stair」. **That is not what is failing here.** `net_tiers`'s own `FIXTURE_TIERS`
spells its plateau with `1`, and `1` was widened on 2026-08-26 to mean level **1** where it used to mean
level 2 — so **the fixture's plateau is a staircase from end to end and there is no level-2 조각 in it
at all.** `grid.gd`'s own header warned that this fixture would have to be re-read and it never was.
⚠ **That is a defect of its own and this ticket does not fix it** — the brief says leave the 59 alone.

⚠⚠ **Every hop count in those files goes wrong the moment a step stops costing 1.** Four assertions
inside the partly-red function are green today on hop counts. **They are part of this ticket** — the
claim each makes is still true and has to be restated in cost units, **without repairing a single one
of the assertions that is red.**

**Nothing else in `src/` or `tests/` reads a field value as a number** — grep for `UNREACHABLE` and for
`flow_field` across `src`, `tests`, `tools` and `prototypes` returns only these, `walk_probe`, and
`Battle`'s cache, which passes the array through untouched. `net_islands._reaches` counts 조각 steps
against `WALK_STEPS_MAX` and tests arrival, so cost units never reach it.

## ⚠ Which green went false here before

`how-nets-lie` carries no entry about the flow field. **Three of its general shapes bite this work:**

- **"A check that reads only final state cannot measure an ordering contract."** A weighted flood is
  wrong precisely in the ORDER it settles tiles. A check that only asks "did the body arrive" stays
  green with a FIFO queue. ⇒ **The field's VALUES are what must be asserted**, against a formula.
- **"A/B comparison catches 'diverged', never 'vanished'."** Comparing the pulled path against the raw
  path catches a pull that changed it, never a pull that silently returned its input. ⇒ **Assert the
  turn count drops on a fixture where it must.**
- **"Invert the instrument, not only the subject."** The straightening check must itself fail on a
  fixture where straightening is illegal — the stair flank.

---

## Implementation plan

### Seams

**One seam, and it is an existing one: `src/sim/`** — constructible with `.new()`, never touches the
tree. Every function this ticket adds or changes lives in `src/sim/grid.gd`, `src/sim/rules.gd`,
`src/sim/battle.gd` and one new file in the same folder. **No new seam is asked for.**

⚠ **Nothing reaches the screen this round.** The 판 already draws itself and the move line is
[티켓 11](11-the-move-line-shows.md); this ticket changes only which 조각 a body steps on.

### The decisions, so nothing is guessed

**1. Weighted cost — 10 orthogonal, 14 diagonal.** Two constants in `src/sim/rules.gd`, beside
`MAX_CLIMB_LEVELS`:

```
const STEP_COST_ORTHO := 10
const STEP_COST_DIAG := 14
```

**They live in `Rules` and not in `Grid` because `CLAUDE.md` says so** — `rules.gd` holds every
constant that changes what happens, and this pair changes which 조각 a body stands on. `Grid` keeps the
board legend and `UNREACHABLE`, which are facts about the board rather than about the rules.

⚠ **Integers, so no float ever enters the field.** `14/10 = 1.4` against a true `sqrt(2) = 1.41421`;
the error is 1% and it is the standard integer octile pair.
⚠ **`UNREACHABLE` is `1 << 30` and stays.** The worst path on the shipped 48 x 32 board is under
1536 x 14 = 21504, four orders of magnitude below it.

**2. The flood pops the lowest cost first — a BINARY HEAP, and here is why.**

A plain FIFO is correct **only** when every edge costs the same; with 10 and 14 it settles a tile at a
cost that a later, cheaper route would have beaten, and the field comes out wrong with nothing barking.
Two fixes were on the table:

- **A bucket queue (Dial's)** — O(1) per operation, but it needs a circular array of 15 buckets and its
  correctness depends on the largest edge weight, so it silently breaks the day a third weight appears.
- **A binary heap** — O(log n) per operation, correct under any weight, and about forty lines.

⇒ **The binary heap.** The field is built once per target tile and cached for 0.5 s
(`Battle.FIELD_TTL`), so the cost is paid a handful of times a second at most: ~1536 tiles x 8
neighbours is ~12k pushes at log2(12k) ~ 14 comparisons — under 200k integer operations for a field
that is then reused for thirty frames. **The O(1) queue buys nothing here and costs a rule that can
rot.**

**Where it lives**: a new file `src/sim/int_heap.gd`, `class_name IntHeap`, `extends RefCounted`.
A min-heap over pairs packed into one `PackedInt32Array` — `[cost0, tile0, cost1, tile1, ...]` — with
`push(cost, value)`, `pop_value()` and `is_empty()`. **Its own file rather than private to `grid.gd`
so a net can drive it with `.new()` and prove it orders things**, which is exactly the part a
"did the body arrive" check cannot see.

⚠⚠ **A brand-new `class_name` file is invisible to `--headless --script` until the project is
re-imported.** `run_nets.ps1` already detects a `.gd` with no `.uid` beside it and runs `--import`
first — so the first net run after this file is added will do one extra import pass, and that is
expected, not a failure.

**3. Ties break toward the goal.** One private helper, used by both the descent and the path pull, so
there is one copy of the rule.

⚠⚠ **KEY 1 IS THE COST OF GOING THROUGH THE NEIGHBOUR, NOT THE NEIGHBOUR'S OWN FIELD VALUE**, and the
difference is the whole of whether this works. **Measured 2026-08-29, on the plan's own first draft**:
ranking by `field[nt]` alone means a diagonal neighbour is always `14` cheaper and an orthogonal one
always `10`, **so the diagonal wins outright and there is never a tie for the other keys to break.**
The four probe walks came out at **4.06 · 2.47 · 2.22 조각 off their own straight line** — all diagonals
first, then straight. ⇒ **Rank by `field[nt] + step_cost(cur, nt)`.** Every step on an optimal route
totals exactly `field[cur]`, so **all the optimal steps tie** — which is the condition the deviation
key was written for.

Given the 조각 the body stands on `cur`, the field's target 조각 `target`, and two candidates, the
better one is decided by these keys **in this order**:

1. **lower `field[cand] + step_cost(cur, cand)`** — the total cost of the route through it
2. **smaller `|cross|`**, where `d = target - cur`, `s = cand - cur`, `cross = s.x*d.y - s.y*d.x`.
   **This is the perpendicular deviation from the straight line to the goal**, and it is what makes an
   equal-cost step go along the line rather than off it
3. **larger `dot`**, `dot = s.x*d.x + s.y*d.y` — of two steps equally off the line, the one that gets
   closer wins
4. **lower 조각 index** — determinism, and nothing else

⚠ **When `target` is not known (`target_tile == -1`), keys 2 and 3 are skipped.** The descent is then
「lowest total cost, then lowest 조각 index」. ⚠⚠ **This is NOT identical to today's behaviour** — today
is「lowest field value, then `NEIGHBOURS` order」. **It is a better descent and it changes which 조각 a
three-argument caller steps on.** The three such callers were checked: `net_islands._reaches` and
`net_tiers._the_real_island_still_has_a_route` read arrival and `UNREACHABLE` only, and
`net_tiers._the_walker_will_not_cut_a_corner` asserts a refused diagonal is not chosen — none of them
names a 조각 the new rule would choose differently.

⚠ **The admission test is untouched and it is not key 1.** A candidate must still be **strictly
cheaper than the 조각 the body stands on** (`field[cand] >= field[cur]` is skipped) — that is what
guarantees the descent terminates and what stops the oscillation this repo already paid for. Key 1
ranks the candidates that survive it.

**4. A path is pulled out of the field the moment the order is given, and hung on the body.**

The flow field **stays** and stays the fallback. The path is a straightened list laid on top of it.

**5. The list is string-pulled, and the line-of-sight test goes through `can_step`.**

⚠⚠ **NEVER a plain straight line.** A stair may be entered only at its ends (`_stair_face_open`), so a
naive smoothing sends a body up a staircase's flank — which is [티켓 22](22-bodies-clip-through-the-stair.md)'s
subject, already open. **Do not open a second one; do not let this ticket feed it.**

**6. String-pull hands back an ADJACENT-조각 list, not waypoints.** The pulled corners are re-expanded
into the 8-connected line between them. **The reservation model, the two-tile hold and the queue at a
neck all stay untouched** because the body still steps one 조각 at a time; only the list of 조각 is
straighter. A waypoint list would need the walker to reserve tiles it never names, and that is the one
thing this ticket must not disturb.

**7. When the next 조각 is blocked or reserved, the body steps down the field instead** — exactly as it
does today. **Then it tries to rejoin**: if the 조각 it landed on is still somewhere in the remaining
list, the index advances to just past it and the straightened route continues; if it is not, the path
is dropped and the body finishes the order on the field alone. ⚠ **The path is never rebuilt
mid-order** — a body stuck at a neck would rebuild it every sub-step, and the field is already correct.

### Files to touch, and why

| File | Why |
|---|---|
| `src/sim/rules.gd` | The two cost constants. Nothing else |
| `src/sim/int_heap.gd` **(new)** | The min-heap the flood pops from |
| `src/sim/grid.gd` | Weighted flood · the tie-break helper · `path_from` · `line_tiles` · `string_pull` · `step_along` |
| `src/sim/battle.gd` | The path hangs on the body: two columns, built in `order_walk`, consumed in `_walk`, cleared everywhere an order is |
| `tests/nets/net_walk.gd` **(new)** | The subject's own net — the field's values, the shape of the walk, the pull |
| `tests/nets/net_tiers.gd` | Two green checks restate their claim in cost units instead of hop counts |
| `prototypes/stairs/walk_probe.gd` | Re-run to get the after picture. ⚠ It may be re-run or deleted; nothing else in the repo reads it |

⚠⚠ **`assets/terrain/`, `prototypes/` (beyond re-running that one probe) and `tools/blender/` are OFF
LIMITS this round** — another session is working on the stair there right now.

### What goes into `grid.gd`, precisely

**`flow_field(target_tile)` — same signature, same return type, weighted.**

- Seed unchanged: `field[target_tile] = 0`, planted whatever the target's own passability. **That
  reason is in the function's header and it still holds.**
- Replace the FIFO with an `IntHeap`. Push `(0, target_tile)`.
- Pop the lowest cost. **⚠ Skip a stale entry**: if the popped tile's recorded field value is lower
  than the cost it was pushed with, it has already been settled cheaper — `continue`. (A heap with no
  decrease-key needs this, and without it the flood is still correct but does redundant work.)
- For each of the eight neighbours: `can_step(t, nt)` unchanged — **the height rule stays inside the
  flood and is not moved to the walker**, for the reason the existing comment gives.
- `step = Rules.STEP_COST_DIAG if both axes changed else Rules.STEP_COST_ORTHO`.
- Relax on `field[nt] > field[t] + step`, then push.
- **Reserved tiles stay traversable here.** Occupancy is `step_toward`'s business, and the field is
  terrain-only so it can be cached. Unchanged.

**`step_toward(unit_id, from, field, keep_level := -1, target_tile := -1)` — one new optional argument.**

Everything else survives verbatim, and each of these is measured behaviour:

- `_hold(unit_id, cur)` first, always
- a candidate must pass `can_step(cur, nt)` — asked here as well as in the flood, and that is not a
  second copy of the rule
- `keep_level >= 0` refuses a step that does not land on that level
- a tile reserved by somebody else is refused
- **strictly cheaper than the tile the body stands on** — `field[nt] >= field[cur]` is skipped, and an
  `<=` here is the oscillation this repo already paid for
- **no candidate → `_release_except(unit_id, cur, cur)` and `from` comes back.** That is the queue at a
  neck and it must not change
- on success `_hold(best)` then `_release_except(cur, best)` — the two-tile hold, never wider than two

**The only change**: among candidates that pass all of the above, the winner is chosen by the four-key
tie-break instead of by array order.

**`step_along(unit_id, from, next_tile, keep_level := -1) -> Vector2` — new.**

**The same commit, for a 조각 the caller names.** Holds `cur`, then refuses — returning `from`
unchanged and releasing NOTHING — when `next_tile` is out of range, is `cur` itself, **is not an
8-neighbour of `cur`**, fails `can_step(cur, next_tile)`, is the wrong level under `keep_level`, or is
reserved by somebody else. On success it does `_hold(next_tile)` then `_release_except(cur, next_tile)`
and returns the 조각's point.

⚠⚠ **THE ADJACENCY TEST IS REQUIRED AND `can_step` DOES NOT SUPPLY IT.** Measured 2026-08-29:
`can_step` checks bounds, passability, the level gap, the stair face and — on a diagonal — the
shoulders, **and it never asks whether the two 조각 touch.** `can_step((6,5) -> (20,5))` is `true`,
fourteen 조각 apart. It has been safe only because both existing callers hand it one of eight
neighbours. **`step_along` takes a 조각 the caller names**, and without this test a stale index would
have the body glide several 조각 in a straight line holding only the endpoints — through whatever
stands between, with every reservation check green.

⚠⚠ **The hold/release lines must be written ONCE and shared with `step_toward`** — a second copy of the
two-tile swap is exactly the drift the `keep_level` header already argues against.
⚠ **On refusal it does NOT release**, because the caller falls straight to `step_toward`, which does
its own release when it also refuses.

**`path_from(field, from_tile, target_tile) -> PackedInt32Array` — new, and PURE.**

Walks the field down from `from_tile`, one 조각 at a time, using the same four-key tie-break, and stops
at `target_tile` or when no neighbour is strictly cheaper. Returns `[from_tile, ..., target_tile]`, or
an empty array when the field is the wrong size, the tile is off the board, or
`field[from_tile] == UNREACHABLE`.

⚠⚠ **It reserves nothing, holds nothing and releases nothing.** It is a question about the board, and
a query that mutates the reservation table would put a body's own hold in the way of its own path.
⚠ **It ignores reservations and `keep_level` on purpose** — the field is terrain-only, and honouring
occupancy in a list built once at the moment of the order would bake in whoever happened to be standing
there.
⚠ **Bounded by `w * h` iterations.** A strictly-decreasing walk cannot loop, so the bound is a guard
and not a rule; hitting it means a defect and the partial list comes back rather than a hang.

**`line_tiles(a_tile, b_tile) -> PackedInt32Array` — new.**

**The 8-connected line between two 조각, or empty when a body could not walk it.**

⚠⚠ **IT IS AN OCTILE LINE OF EXACTLY `n = max(|dx|, |dy|)` STEPS, AND NOT A DENSE SAMPLE.** The first
draft of this plan sampled the segment every 0.25 조각 and rounded each axis on its own; **measured, that
emits a separate orthogonal step for each axis crossing** and comes out longer than the route it is
meant to straighten — (2,10) → (20,2) gave 24 steps at cost 248 against the octile optimum of 18 steps
at 212, with sixteen turns. **The straightener made the walk more crooked.**

Write it as the integer interpolation instead:

```
n = max(|dx|, |dy|)          # zero means the two 조각 are the same: return an empty list
for i in 1..n:
    x = a.x + round(dx * i / n)
    y = a.y + round(dy * i / n)
```

- ⚠ **Each step is an 8-neighbour move by construction**: `|dx|/n` and `|dy|/n` are both `<= 1`, so a
  rounded monotone sequence moves each axis by at most one per `i`. **There are exactly `n` steps, of
  which `min(|dx|,|dy|)` are diagonal** — which is exactly the octile cost `10*max + 4*min`, the
  cheapest route any 8-connected walk between the two 조각 can have. **That is what makes「never
  longer」a property rather than a per-fixture coincidence.**
- At every step **ask `can_step(previous, next)`**. ⚠⚠ **This is the whole point of the function.** A
  plain passability test here walks a body up a staircase's flank.
- Any refusal → return an empty array. Otherwise return the 조각 after `a_tile`, through `b_tile`.
- ⚠ **`a_tile` itself is NOT in the returned list.** The caller already holds it.
- ⚠ **It is a thin line, not a supercover, and that is safe**: consecutive 조각 are 8-neighbours, and
  `can_step` refuses a diagonal whose shoulders are blocked. The corner cannot be cut.

**`string_pull(path) -> PackedInt32Array` — new.**

Greedy, from the front: standing at `path[i]`, take the FURTHEST `j` (scanning down from the end) for
which `line_tiles(path[i], path[j])` is non-empty, append that line, and continue from `j`. A path of
two 조각 or fewer comes back unchanged.

⚠ **The result is never longer than the input.** A sampled straight line between two 조각 has
`max(|dx|,|dy|)` steps of which `min(|dx|,|dy|)` are diagonal — which is exactly the octile cost
`10*max + 4*min`, the cheapest any route between them can be. **A net asserts this**, because "the
smoothing made it longer" is the one way this function fails invisibly.
⚠ It is O(n²) on the number of 조각, and a path on this board is under sixty. That is fine and it is
not worth a funnel algorithm.

### What goes into `battle.gd`

- **Two new columns, both plain `Array` and indexed by soldier id**: `_soldier_path` (a
  `PackedInt32Array` per body) and `_soldier_path_i` (the index of the next 조각).
  ⚠⚠ **`_soldier_path_i` is an `Array` and NOT a `PackedInt32Array`, deliberately.** This file already
  carries the measurement: a `PackedInt32Array` written through a parameter lands in a copy-on-write
  copy, and `_soldier_stale`'s header says so. The index is written every sub-step.
- **Sized in `setup` beside `soldier_order`**, and reset there.
- **`order_walk` builds the path**, after its existing validation and after `soldier_order` is set:
  ask `_field_for(tile)`, then `grid.path_from(...)` from the body's current 조각, then
  `grid.string_pull(...)`; store it with the index at 1 (index 0 is the 조각 the body already stands
  on). **An empty result is not an error** — the body then walks on the field alone, which is what it
  does today, and `order_walk`'s header already says a reachability test here would be a second copy of
  the walking rule.
- **Cleared wherever an order is cleared** — `place_ashore`, `setup`, and each of the three lines in
  `_phase_orders` that write `soldier_order[i] = -1`.
- **`_walk` gains a `target_tile := -1` argument**, passed from `_phase_orders`'s `dest_tile`, and its
  "I need a new goal" branch becomes:
  1. ⚠⚠ **RESYNC FIRST, EVERY TIME.** Search the list **from the current index forward** for the 조각
     the body is standing on right now. Found at `k` → the index becomes `k + 1`. **Not found → the
     path is emptied** and the rest of the order runs on the field.
  2. **The path.** If an entry is left, `grid.step_along(uid, here, that 조각, keep_level)`. If it
     moved, take it and advance the index.
  3. **Otherwise the field**, exactly as today: `grid.step_toward(uid, here, field, keep_level,
     target_tile)`. The next sub-step's resync decides whether the straightened route is rejoined.
  - ⚠⚠ **STEP 1 IS NOT TIDINESS, IT IS THE ADJACENCY GUARANTEE.** `order_walk` builds the list from the
    조각 the body's position rounds to, but the body may be **half-way across a 조각 it already
    reserved** — `_soldier_goal` points forward and `_walk` glides there first. Without the resync the
    index would still point at a neighbour of the 조각 the body has left, **up to two 조각 away and
    possibly behind it.** Consecutive entries in the list are 8-neighbours by construction, so
    resyncing makes the argument `step_along` gets adjacent by construction too.
  - ⚠ **Search forward from the current index only, never backwards.** The index must not move back, or
    a body could shuffle between two 조각 forever.
  - ⚠ **The two existing exits stay**: goal equal to `here` still means every neighbour is taken and
    the body stands (the queue at a neck), and `WALK_TILES_MAX` still ends the frame.
- **`_phase_movement` is not touched.** Its glide branch finishes a 조각 already reserved and knows
  nothing about orders.

### Order of work

⚠⚠ **This is `sim` work, so the nets are written FIRST** (2026-08-24, the user).

1. **`net_walk.gd`, red** — every check below, written against functions that do not exist yet or
   against the current wrong behaviour. **Confirm each one is red for the right reason.**
2. `Rules` constants, `int_heap.gd`, and the weighted flood. **Now the field's values are right.**
3. The tie-break helper, and `step_toward`'s new argument. **Now the descent is right.**
4. `line_tiles`, `string_pull`, `path_from`, `step_along`.
5. `battle.gd` hangs the path on the body.
6. **`net_tiers`'s hop counts restated in cost units.** ⚠ Do this LAST, against a field that is
   already weighted.
7. **Teach `prototypes/stairs/walk_probe.gd` to measure what the game does**, then re-run it and
   record the after picture. ⚠⚠ **As it stands the probe measures the WRONG THING** — it calls
   `step_toward` with three arguments, so the deviation keys are switched off in the very instrument
   acceptance 1 is read from, and it never touches `string_pull` at all. **It must pass the target
   조각, and it must print the string-pulled route beside the raw descent.** It is a throwaway probe
   and this is the one file outside `src/` and `tests/` this ticket may touch.

### What the nets must measure

**In `tests/nets/net_walk.gd`:**

| Check | Why it cannot be faked |
|---|---|
| **The heap orders.** Push costs out of order, pop them all, assert ascending — and assert the COUNT popped, so an empty heap is not green | A "did it arrive" check never sees the order |
| **The empty-board field equals octile cost exactly** — for EVERY 조각 on a 24 x 12 empty board, `field[t] == 10*max(dx,dy) + 4*min(dx,dy)` | ⚠⚠ **IT MEASURES RELAXATION, NOT ORDER, and the first draft of this plan had that wrong.** Measured 2026-08-29: swap the heap for a pure FIFO and this stays GREEN on all 288 조각, because the flood re-pushes whenever a value improves and therefore converges out of order. **Take the re-push away as well and 223 of the 288 go wrong.** ⇒ **The one thing that measures ordering is the heap's own check**, and the heap buys speed, not correctness |
| **A diagonal costs more than an orthogonal** — 조각 four away diagonally is `4*14`, four away straight is `4*10` | Names the two constants apart, so setting them equal reddens |
| **The straight walk has no turn** — A(2,6) → B(20,6) on the empty board: 19 조각, 0 turns | The defect the user saw, stated as a number |
| **The knight's angle stays near the line** — A(2,10) → B(20,2): no 조각 on the walk is more than 1 조각 off the straight segment, perpendicular | Catches a tie-break that drifts even when the cost is right |
| **`path_from` mutates nothing** — the whole `reserved` array is byte-identical before and after, and `_held` gains no entry | ⚠ A query that reserves would block the body's own route |
| **`path_from`'s list is walkable** — every consecutive pair passes `can_step`, and the last 조각 is the target | Rules out a list that reads plausible and cannot be walked |
| **`string_pull` removes a corner** — on a fixture where the field descent turns and the straight line is open, the pulled path has strictly FEWER turns | A pull that returns its input reddens |
| **`string_pull` never lengthens** — the pulled path's cost in 10/14 units is `<=` the raw path's, on every fixture in the file | "The smoothing made it longer" is the invisible failure |
| ⚠⚠ **`string_pull` will not cross a stair flank** — a stair fixture where the straight line between two path 조각 crosses the staircase sideways: every consecutive pair of the pulled path still passes `can_step`, and no pair enters a stair 조각 off its axis | **This is the instrument's own inversion.** Swap `line_tiles`'s `can_step` for a plain `passable` test and this must go red |
| **The queue at a neck survives** — two bodies, a one-조각 doorway, the second one stands where it is | Measured behaviour the brief says must not break |
| **The two-tile hold is never wider than two** — after any number of steps, one body holds at most 2 조각 in `reserved` | Same |
| **`keep_level` still refuses** — a body on a plateau with `keep_level` set does not step down its own stair, on the path route as well as on the field | Same |
| **A blocked next 조각 falls back to the field** — put a reservation on the path's next 조각 and the body still moves, down the field | The fallback is the whole safety of this design |
| ⚠⚠ **`step_along` refuses a 조각 that is not adjacent** — hand it one two 조각 away and one fourteen 조각 away; the body must not move, and `reserved` must not gain that 조각 | **`can_step` says `true` to both.** Delete the adjacency test and this is the only thing that goes red |
| **`line_tiles` is octile-exact** — over every pair on an empty 12 x 12 board, the returned list has `max(\|dx\|,\|dy\|)` entries and costs `10*max + 4*min` | **The row that would have caught the 0.25 rasteriser.** 144 x 144 pairs, not one fixture |
| **The descent hugs the line even where every route ties** — A(2,10) → B(20,2), where 8 diagonals and 10 orthogonals interleave any way at all | ⚠⚠ **The row that catches key 1 being `field[nt]` instead of the route total.** Every arrival check stays green while the walk bends |
| ⚠⚠ **The pulled route of all FOUR probe walks stays within 1.0 of its own straight line** — the same four the probe prints, not one of them | **Two of the four are the ones that miss the bar on the raw descent** (1.97 and 1.39). A net carrying only the easy walk is a label claiming four measurements and making one |
| ⚠⚠ **A re-order replaces the route** — order a body to one 조각, then, before it arrives, order it to a 조각 nothing can reach; it must STOP, not walk on to the first destination | **Measured 2026-08-29: gutting `_clear_path` left every one of 608 checks green.** The ticket's own Risk section names「the path outliving its order」and nothing was measuring it |

**⚠ Every one of these is inverted before it is believed.** `how-nets-lie`: an uninverted check proves
"it runs", not "it measures" — and if an inversion does not bite, **suspect the mutation landed before
suspecting the check.**

**In `tests/nets/net_tiers.gd` — the unit changes, the claims do not, and nothing red is repaired:**

- `_the_walker_will_not_cut_a_corner`: `field[start] > 2` becomes `> 2 * Rules.STEP_COST_DIAG` — the
  refused shortcut is two diagonal steps, and going around must cost more than that. **This one is
  green today and must stay green.**
- `_the_field_climbs_only_by_the_stair`: every hop-count literal becomes the **octile cost of the same
  claim**, written through the two `Rules` constants — a small local helper
  `10*max(|dx|,|dy|) + 4*min(|dx|,|dy|)` against the fixture's own coordinates, never a number typed
  by hand and never a number read off a run.
  - ⚠⚠ **DO NOT REPAIR THE ASSERTIONS THAT ARE RED.** Four of them fail because `FIXTURE_TIERS`
    spells its plateau with `1`, which now means level 1 — **the fixture has no level-2 조각 at all.**
    Converting the unit leaves them red, which is correct. **Turning one into an inequality so it
    passes would be a green measuring nothing**, on a fixture whose plateau does not exist.
  - ⚠ **Do not touch `_bricking_up_the_stair_seals_the_plateau`.** It reads `UNREACHABLE` only, no cost
    units reach it, and it is red for the same fixture reason.
  - ⚠ **The broken fixture is a defect and it is NOT this ticket's** — the brief says leave the 59
    alone. Say so in the report so it can become a ticket of its own.

### Risk — what this could break in silence

- ⚠⚠ **A wrong field with nothing barking.** A weighted flood that settles a 조각 once and never
  revisits it records some 조각 too expensively; every body still arrives, so every arrival check stays
  green. **The octile-formula check over the whole board is the only thing that sees it** — do not
  weaken it to a spot check. ⚠ **It is the RE-PUSH it measures, not the pop order** — a pure FIFO with
  the re-push intact converges and leaves it green, measured 2026-08-29.
- ⚠⚠ **String-pulling a body through a staircase's flank.** [티켓 22](22-bodies-clip-through-the-stair.md)
  is open for bodies clipping the stair; a naive line test here would make it worse and look like that
  ticket. **`line_tiles` going through `can_step` is not an optimisation, it is the rule.**
- ⚠ **Losing the queue at a neck.** The path route is a second way to step, and if it does not honour
  reservation the same way, two bodies walk through each other with every reservation check green — the
  exact shape `ENEMY_UID_BASE`'s deleted header warns about.
- ⚠ **A widened hold.** `step_along` doing `_hold` without the matching `_release_except` leaves a body
  holding three 조각 and halves every doorway, with nothing on screen to explain it.
- ⚠ **The path outliving its order.** A stale list left on a body after its order is cleared sends it
  walking somewhere nobody asked. **Clear it at every site that clears the order.**
- ⚠⚠ **A tie-break that never runs.** If key 1 stays `field[nt]`, the diagonal always wins outright,
  the walk bends, and **every net about arrival, cost and reachability is green** — the deviation is
  the only thing that sees it. This was measured on this plan's own first draft.
- ⚠⚠ **A straightener that lengthens the walk.** Measured on this plan's own first draft: a per-axis
  rasteriser turned an 18-step route into 24 steps and 16 turns. **The octile-exactness check over a
  whole board is what sees it**; a single fixture can pass by luck.
- ⚠⚠ **A named 조각 that is not adjacent.** `can_step` answers `true` for two 조각 fourteen apart, so
  the adjacency test is the only guard, and a stale path index is a live way to reach it.
- ⚠ **`net_tiers` going redder.** Hop-count literals must be restated; **record the before and after
  failure counts** and prove the delta is zero. ⚠ **Making one of its red assertions pass is also a
  failure of this ticket** — the fixture behind it is broken and this ticket does not fix fixtures.
- ⚠ **A new `class_name` file.** `int_heap.gd` needs the project re-imported once; `run_nets.ps1` does
  it automatically when a `.gd` has no `.uid`. **A `Parse error` / `Nonexistent function 'new'` on the
  first run is that, not broken code.**

### Acceptance

1. **`prototypes/stairs/walk_probe.gd`, passing the target 조각, prints a straight line** for
   "straight east": 19 조각, 0 turns — and the other three walks carry **no 조각 more than 1.0 off
   their own straight segment**, measured perpendicular. ⚠ **Before this ticket that number is
   4.06 · 2.47 · 2.22**, and with the weighting alone but the wrong key 1 it stays there.
   ⚠ **The string-pulled route is printed beside the raw descent and is never longer in 10/14 units.**

   ⚠⚠ **THE BAR IS THE PULLED ROUTE, AND THAT IS SETTLED HERE** (2026-08-29, after two independent
   passes measured it). **The raw field descent does NOT meet 1.0 and it is not meant to** — measured
   at **0.00 · 0.81 · 1.97 · 1.39**, against the pulled route's **0.00 · 0.41 · 0.49 · 0.28**.
   **The body walks the pulled route; the field is the fallback**, so the pulled route is what「the
   line a body walks」means. ⚠ **Both numbers are printed and both are recorded** — the raw descent's
   deviation is a real measurement of the field and losing it would hide a tie-break that rots.
   **The reason the raw descent cannot reach 1.0**: key 2 is the deviation from the DIRECTION to the
   goal, so with the goal 18 east and 3 north, walking straight east is the best angle for twelve
   steps running. That is the key the plan chose and it is not being changed.
2. **`net_walk` is entirely green**, and every check in it has been inverted and seen to bite.
3. **`tests/run_nets.ps1` reports 실패 59 or fewer.** ⚠ **Baseline is 통과 521 · 실패 59.** A single
   added red is a failure of this ticket, and the fingerprint line proves the same tree was measured.
4. **Nothing on stderr** that the net did not declare — the wrapper's silent-death check.
5. **`src/sim/` still constructs with `.new()` alone**: no `Node`, no `_draw`, no `Input`, no
   `get_node`, no `$` in anything this ticket touched.

### Out of scope — **do not expand into these**

- **The move line on screen** — 티켓 11. Nothing this round is drawn.
- **The body clipping the stair** — 티켓 22. This ticket must not make it worse and must not try to
  close it.
- **Group orders.** 판 위의 무리 명령 is 티켓 02 and there is not a line of it in the code yet.
- **Any change to `can_step`, `_stair_face_open` or `_shoulder_open`.** They are correct; this ticket
  only calls them from two more places.
- **Local avoidance, unit collision, or a body pushing another aside.** The queue at a neck stays what
  it is.
- **`assets/terrain/`, `tools/blender/`, and every 프로토타입 except re-running the one walk probe.**
  Another session is on the stair there.
