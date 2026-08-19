# Plan — delete the speed ladder, and make landing a denylist

**Status**: `2.active` — moved 2026-08-19 when the user said 「돌려」. ⚠ `title-and-map` also sits in `2.active` and is **PAUSED, not running**. Asked for by the user on 2026-08-19 while watching the game run.
Design owners: [the boat and the landing](../../design/boat-invasion.md) for item 2,
[plan it, then watch it](../../design/plan-then-watch.md) for item 1.

> ***"일단 배속 개념은 지워주고, 저거는 아직은 필요 없을 때 추후에 추가해도"***
> ***"내가 어디든지 상륙할 수 있게 해달라고 했는데 지금 보면은 사실 상륙할 데가 정해져 있는 거 같애.
> 그니까 상륙 못하는 데가 있는 거지 상륙 가능한 데가 있는 게 아니야"***
> (user, 2026-08-19)

⚠⚠ **The user called this 사소한 것 and item 1 is. Item 2 is not, and the answers below grew it.**
Opening the shadowed coastline means **a boat sails a route over water instead of a straight line** —
`grid` grows a water field, `battle`'s boat stops being one segment, and every drawn route becomes a
polyline. **Read section 2.1's numbers before starting.**

---

## 0. OPEN questions — ✅ **all three answered**

**Sent to the user**: **YES — 2026-08-19, three in one message, all three answered.**

| # | Question | ✅ The answer |
|---|---|---|
| **A** | Does the PAUSE go with the speed ladder? Pause is **slot 0 of that same row** | ***"일시정지 지워주고"*** ⇒ **yes, the whole row goes.** ⚠ **After this, a committed fight has nothing the hand can do** — that overturns [plan it, then watch it](../../design/plan-then-watch.md)'s decided 4 and takes the instrument away from its own metric |
| **B** | How far does 「어디든지」 go — drop coast-adjacency only, or open the line-of-sight shadow too? | ***"그늘이 뭔지 모르겠음 못내리는데인가? 그러면 추가해주면됨"*** ⇒ **open the shadow.** The shadow IS the can't-land stretch, and the user wants it landable ⇒ **section 2.2 becomes a water route, not a one-line predicate edit** |
| **C** | Does the green coast tint stay? | ***"못내림만 표시하면 됨 ㅇㅇ"*** ⇒ **the tint is deleted. The screen marks what is blocked and nothing else** |

⚠ **B was answered from a word the user did not know**, and they said so. **「그늘」 was this plan's word,
not theirs.** The answer is safe because the *thing* was described in their own terms in the same sentence
(*"못 내리는 데인가?"*) and it is what they had already complained about. ⇒ **When a question needs a word
the user has not used, describe the thing instead** — `idea-inbox` row 22 is the same failure one turn
earlier, and there it cost an answer.

---

## 1. Delete the speed ladder

**What the user saw**: five chips at the bottom right reading `0 1 2 3 6`. **They asked what they were.**
A widget that has to be explained is the 「애매하다」 shape, and the answer asked for is removal.

### What comes out

| Where | What |
|---|---|
| `src/view/hud_view.gd` | `SPEED_LABELS`, the chip loop in `_draw`, `set_speed`, `_speed_slot`, `_speed_scale`, and `_fx_step`'s scaling by `_speed_scale` |
| `src/look.gd` | `HUD_SPEED_ORIGIN_PX`, `HUD_SPEED_SIZE_PX`, `HUD_SPEED_GAP_PX`, `HUD_SPEED_TEXT_OFFSET_PX`, `COL_SPEED_ON`, `speed_rect_px()` |
| `src/shell/game.gd` | the speed branch of `_unhandled_input`, and the multiply in `battle.step(delta * speed)` |
| `tests/nets/` | every check naming a chip, a slot, or a 1× control |

### ⚠ What does NOT come out, and why

- **`Rules.SPEED_STEPS` stays where it is**, read by nothing. It is a few lines and it is the only thing
  that has to come back when the user says 「이제 필요해」 — deleting it makes restoring this a design job
  again. One comment says nothing reads it today
- **`battle.step(delta)` keeps taking a delta.** Do not inline a constant `1.0` anywhere; the seam a
  multiplier plugs back into is the thing worth preserving
- **The clock and the loss condition are untouched.** `elapsed` is the loss condition and the multiplier
  never changed it, and every `TIME_LIMITS` number was tuned by a probe that never pressed a chip.
  ⚠ **Say that rather than re-running the tuning** — ⚠⚠ **but see 2.4: item 2 DOES move the clock**

---

## 2. Landing becomes a denylist

⚠ **The design already said this.** [The boat and the landing](../../design/boat-invasion.md)'s **decided
#1** reads *"The whole coastline is a landing point. Anywhere not blocked"*, quoting the user:
***"완전히 막혀있는 데가 아니면 어디든지 보낼 수 있게"***. **The code shipped the inverted rule** — a
computed set of permitted tiles, painted green. ⇒ **The second instance of 「내가 말한대로 개발을 안하네」,
and the same shape as the first**: the doc was right and nothing checked the code against it.

### 2.1 The measurement — **why the cheap edit was refused**

Measured 2026-08-19, headless, all three shipped islands. Counts are tiles.

| Island | Passable land | Coast (ortho) | Coast (8-way) | **Sendable today** | Coast-adjacency dropped | **Water route (chosen)** |
|---|---|---|---|---|---|---|
| 0 | 744 | 82 | 84 | **50** | 97 | **84** |
| 1 | 760 | 76 | 76 | **44** | 83 | **76** |
| 2 | 716 | 80 | 82 | **48** | 94 | **82** |

- **Today's rule refuses 39% · 42% · 40% of each island's own coastline**, because a headland blocks the
  straight water line from every harbour. That is what reads as *the landing spots are fixed*
- ⚠ **All water on all three islands is one connected body** — 724 / 690 / 726 water tiles, every one of
  them reachable from a harbour. ⇒ **With a water route, every coast tile is landable and the refused set
  is exactly `cliff + inland`.** That is the denylist the user described, with nothing left over
- ⚠⚠ **Note what the middle column would have bought**: 97 > 84. Dropping coast-adjacency alone lets a
  boat land **one tile inland** (`LINE_SAMPLE_EXEMPT_CHEBYSHEV` is 1) while still refusing 40% of the
  actual shore. **A bigger number that is the wrong set** — do not read column 6 as better than column 7

### 2.2 The rule — **water reachability replaces line-of-sight**

`src/sim/grid.gd::load_rows` today:

```
landable[t]      = passable[t] AND (some ORTHO neighbour is water)
sendable[hb][t]  = landable[t]  AND water_line_clear(harbour hb, t)
```

⇒ becomes, per harbour:

```
water_field(hb)  = BFS over WATER tiles from harbour hb        # mirrors flow_field, water instead of land
sendable[hb][t]  = passable[t] AND (some 8-neighbour of t is water reachable in water_field(hb))
```

- **`landable`, `ORTHO` and `water_line_clear` all go.** ⚠ `ORTHO` has one other reader —
  `field_view`'s cliff-face pass, which walks a cliff tile's seaward edges — so **it moves there rather
  than dying.** `water_line_clear` is driven directly by `net_coast`; **those checks are deleted, not
  rewritten to pass**
- **`grid.flow_field(target)` is the shape to mirror**, not to reuse: same BFS, `water` instead of
  `passable`, `NEIGHBOURS` (8-way) instead of ortho-only, and `UNREACHABLE` as the same sentinel
- **`can_land_at`, `home_harbour_for`, `Battle.send` keep reading `sendable`.** `home_harbour_for` becomes
  **nearest by water-field distance**, not by straight-line distance — it already filters on `can_land_at`,
  and that filter is now never empty for a coast tile
- ⚠ **Cache it once per island in `load_rows`, exactly as `sendable` is cached today.** The comment on
  `can_land_at` records why (1536 tiles × 3 harbours per frame is a stutter), and a BFS is more expensive
  than a line test, not less

### 2.3 The boat — **it stops being one straight segment**

⚠⚠ **This is the part that makes item 2 a real build.** A boat today is
`{from, to, dist, t}` and `_phase_boats` lerps between two points. **A route around a headland is a
polyline**, so:

- **A boat carries `path: Array[Vector2]` and a cumulative length.** `pos` is found by walking the
  polyline at `t × speed`. `dist` becomes the path's total length
- **The path comes out of the same water field** — step down the field from the landing's chosen water
  neighbour back to the harbour, the way `step_toward` walks `flow_field`, then reverse it
- **The RETURN leg reverses the same path.** ⚠ **Do not recompute it** — `_phase_landings` today
  recomputes nothing and says why in its comment (`home` was decided by `send` off the same call the
  refusal test used). The same rule holds here
- ⚠ **`_arrived` and the sub-step**: `Rules.SIM_SUBSTEP_SEC` is what keeps two boats that left together
  landing together. **A polyline must not change arrival ordering** — pass 1 of `_phase_landings` walks
  ascending because append order is drop order, and that property is load-bearing
- **`field_view`'s planned routes become polylines too.** They are drawn straight today

### 2.4 ⚠⚠ The clock — **this one DOES move it, unlike item 1**

A route around a headland is **longer than the straight line it replaces**, and crossing time is
`dist / speed`. `boat-invasion` measured crossings at **20% of the clock** after the 4+2 capacities
landed. ⇒ **Every `TIME_LIMITS` number is suspect after this change, and nobody has measured how much.**

- **Measure it**: run `tools/probe/run_run.gd` before and after, and report the crossing share and the
  worst plan's clock fraction. ⚠ **The probe has never once made the time limit bind** (15 island-runs,
  worst at 49%) — **so a rise is expected to be absorbable, and that expectation is exactly what has to
  be checked rather than assumed**
- ⚠ **Do NOT retune `TIME_LIMITS` in this round.** Report the number. Retuning is a decision with the
  user in it

### 2.5 The screen — ✅ **question C: mark only what is blocked**

| Today | After |
|---|---|
| `field_view._droppable_rects` tints every sendable tile green at alpha 0.18 from the moment the island opens | ⚠ **Deleted** |
| Cliff faces drawn as a line along a cliff tile's seaward edge | **Unchanged, and now the standing 「여긴 못 내린다」 mark** |
| A refused drop does nothing visible | ⚠⚠ **A drop the sim refuses must say so** — one mark at the cursor on the frame of the refusal |

⚠⚠ **`_droppable_rects` is what makes the promise honest today.** Its predicate is
`grid.home_harbour_for(t) >= 0` — **the exact call `Battle.send` refuses on** — so the green can never
promise a tile the sim then denies. **Deleting the tint deletes that guarantee with it.** ⇒ **The refusal
mark inherits it**: drawn from that same call, never from a second copy of the rule.

⚠ **And the refusal set is now nearly all inland**, where a player will rarely aim. **A mark nobody ever
sees is not presentation** — so the acceptance row is *drag a boat to the middle of the island and the
screen says no*, driven by hand, not inferred from the code existing.

---

## 3. Nets

- ⚠ **Every deletion needs a check that the thing is GONE**, not only that what is left still passes.
  A green round after deleting a widget proves nothing about the widget
- **Item 1**: no speed rect remains in `look.gd`; `hud_view._draw` composes no chip; the shell hands
  `battle.step` a bare delta. ⚠ **`Rules.SPEED_STEPS` still parses and still holds its entries** — the
  restore path is asserted or it rots unnoticed
- **Item 2's floor, written as literals from 2.1** — never read back off the grid under test
  (`CLAUDE.md`: *a ceiling whose bounds come from the thing it checks*): sendable is **≥ 84 · 76 · 82** on
  islands 0 · 1 · 2, and **every 8-way coast tile is sendable on all three**
- **The ceiling**: an inland tile with no water 8-neighbour is **still refused**, and a cliff tile is still
  refused. Without these the whole island going sendable would pass
- **The boat**: a route to a shadowed beach has **length > straight-line distance**, and **every waypoint
  is a water tile.** ⚠ *"The boat arrived"* is not *"the boat sailed on water"* — assert the path, not the
  endpoint. That is `how-nets-lie`'s *a ceiling with no floor* in its exact shape
- **Arrival order is unchanged**: two boats dropped in order onto one beach from one harbour still land
  front row first
- ⚠ **Invert each one.** Restoring the `landable` skip, or straightening the polyline, must redden the new
  checks; if it does not, **confirm the edit landed before suspecting the check** — string replacement has
  silently matched zero times twice in this repo

---

## 4. What this plan does NOT do

- **Retune `TIME_LIMITS`** — 2.4 measures and reports, nothing else
- **A pause button of its own** — question A closed it
- **New landing rules, cliffs, ramps, or a landing bonus**
- **`title-and-map` step 5**, which is a separate plan and stays where it is
- ⚠ **Anything about whether dragging is fun.** The user said in the same breath that dragging a boat
  across is *"그렇게 play가 재밌진 않아"* — `idea-inbox` row 26, **open.** That is a bigger question than
  this plan, and inventing an answer inside it would bury it

---

## Screen — **what a person must be able to SEE, and it is verify-look's whole grounds**

⚠ **Written as pictures, not as code facts.** A row that can be satisfied by reading a file is not a screen row.

| # | What is on screen | How it is judged |
|---|---|---|
| S1 | **Nothing at the bottom right.** The `0 1 2 3 6` chip row is gone, and **no gap, misaligned HUD element or leftover border is left where it was** | A shot of the fight HUD. ⚠ **"The chips are absent" is not enough** — what replaced the space is the question |
| S2 | **No green wash on the shore.** The island opens and the coastline is drawn like the rest of the island | A shot of an island the moment it opens, before any drag |
| S3 | **Cliff faces still read as cliff faces**, and now carry the whole 「못 내림」 job alone | The same shot. ⚠ **They were legible next to a green tint; they must be legible without it** |
| S4 | **A boat sails around a headland**, visibly following the water rather than cutting a corner over land | A drag onto a beach that today is refused, then shots across the crossing. ⚠ **A straight line to a shadowed beach means the polyline never landed** |
| S5 | **A refused drop says no.** Drag onto the middle of the island and something appears at the cursor on that frame | Driven by hand. ⚠ **This is the row most likely to be reported green from code alone** — the mark's existence in a file is not the mark being visible |

## Acceptance — **written so inference cannot pass a row**

⚠ **A build existing, a net being green, or an agent having walked through it are NOT acceptance.**
Rows marked **user only** close when the user says so, and nobody else may close them.

| # | Row | Who closes it |
|---|---|---|
| A1 | The speed chips and the pause are gone from the code and from the screen; `Rules.SPEED_STEPS` still parses | verify-read + verify-look |
| A2 | On all three islands, **sendable ≥ 84 · 76 · 82** and **every 8-way coast tile is sendable** | verify-run, against the literals in 2.1 |
| A3 | An inland tile with no water 8-neighbour, and a cliff tile, are **still refused** | verify-run |
| A4 | A boat sent to a beach that was refused before **arrives**, and **every waypoint of its path is a water tile** | verify-run. ⚠ Assert the path, not the endpoint |
| A5 | Drop order still decides the front row — two boats onto one beach from one harbour | verify-run |
| A6 | The crossing share of the clock, before and after, from `tools/probe/run_run.gd` — **reported, not tuned** | verify-run. ⚠ **A number, not a verdict** |
| A7 | S1–S5 all read right | verify-look |
| A8 | ⚠ **The user launches it and says the shore no longer reads as fixed landing spots** | **user only** |
| A9 | ⚠ **The user says the missing speed control is not missed** | **user only** |

---

## Round log

### Round 1 — builder

changed   `src/sim/grid.gd` (water field · water route · denylist · home-harbour metric) ·
`src/sim/battle.gd` (the boat is a polyline) · `src/sim/rules.gd` (two sampler constants deleted, the
ladder's comment rewritten) · `src/sim/islands.gd` (header) · `src/look.gd` (nine names deleted, three
added) · `src/view/hud_view.gd` (the chip row) · `src/view/field_view.gd` (the wash, the polyline, the
refusal mark, `CLIFF_SIDES`) · `src/shell/game.gd` (the ladder, the refusal mark) ·
`tools/probe/run_run.gd` (`_crossing_of` prices the route; the crossing is printed) · nine nets.

why       Items 1 and 2 of this plan, in that order. Item 1 shipped first and the probe was re-run to
confirm it moved nothing in the sim before item 2 started.

closed    **A1** — the chips and the pause are gone from `look.gd`, `hud_view`, `game.gd` and the
screen, and `Rules.SPEED_STEPS` still parses with all five entries (`net_shell`, two new rows: the
names are absent by reflection, and no file under `src/` outside `rules.gd` mentions the table).
**A2** — sendable is exactly **84 · 76 · 82** on islands 0 · 1 · 2, and every 8-way coast tile is
sendable with the misses collected by tile (`net_islands`). **A3** — 660 · 684 · 634 inland tiles and
44 · 86 · 94 cliff tiles are still refused, pinned by size as well as by membership. **A4** — a boat
sent to a beach the old rule refused arrives, and every waypoint of its path is water (`net_boat`,
driven one sub-step at a time). **A5** — drop order still decides the front row, now read out of the
LAND event stream as well, against equal `dist` on a bending route (`net_plan`). **A6** — measured and
reported below, not tuned.

not closed  **A7** — verify-look owns S1–S5 and nothing here has been looked at. **A8** and **A9** are
**user only** and must not be closed by anyone else; A9 has lost its own instrument, because this round
removed the pause it would have been judged against. ⚠ `plan-then-watch`'s 결정 4 is now overturned in
the code and **its own doc has not been edited** — `docs/design/` was being written by another agent
this session, so the correction has not landed where the claim lives. That is this repo's named
「a refutation in a different doc does not propagate」, and it is open.

nets      **15 nets · 2100 checks · 4.3 s · green**, stderr clean. Was 14 / 1933 / 6.5 s.

---

### The re-measured `net_islands` table — beside 2.1's own

⚠ **Every row moved, including the ones making no dramatic claim.** The domain (what is sendable) and
the metric (what a crossing costs) both changed on the same day.

| Literal | Was | Now | Why it moved |
|---|---|---|---|
| `EXPECT_SENDABLE` (per harbour) | `[[24,29,47],[23,21,38],[29,33,46]]` | `[[84,84,84],[76,76,76],[82,82,82]]` | all water is one body, so the three harbours agree exactly |
| `EXPECT_SENDABLE_UNION` · `EXPECT_DROPPABLE` · `EXPECT_START_SENDABLE` | `[50,44,48]` / `[47,38,46]` | **`[84,76,82]`** | this plan's own 2.1 measurement, typed in by hand |
| `EXPECT_COAST` | `[82,76,80]` (ortho) | **`[84,76,82]`** (8-way) | the ortho count is kept as `EXPECT_COAST_ORTHO` so the two can be shown to differ |
| `EXPECT_WAVE1` (start harbour) | `[[11.70,24.60],[11.00,26.40],[13.00,24.60]]` | `[[15.14,45.80],[13.49,47.80],[15.14,45.80]]` | **route length, not Euclidean** |
| `EXPECT_STEADY` | `[[7.00,14.56],[8.00,12.04],[7.00,14.32]]` | `[[9.49,29.31],[10.90,30.97],[9.49,29.73]]` | same |
| `EXPECT_RELOCATES` | `[30,32,32]` | `[66,73,76]` | wider domain **and** hop-count ranking |
| `EXPECT_STRICT_UNREACHED` | `[0,63,0]` | `[0,119,128]` | the walker runs over 1.7x the tiles; `strict_with_no_nearer_blocker` is still **0** on all three |
| `EXPECT_UNCOVERED_COAST` | `[13,14,4]` | `[13,14,4]` | **re-measured and did not move** — the tiles islands 0 and 2 gained are already covered |
| `EXPECT_START_TILE` · `EXPECT_CUTS` · `EXPECT_HARBOUR_TILES` | — | unchanged | re-measured, not assumed |
| min region over the sendable union | — | `744 · 760 · 716` | the whole island; the floor of 20 does **not** fire |
| new: `EXPECT_PASSABLE` · `EXPECT_WATER` | — | `[744,760,716]` · `[724,690,726]` | from 2.1 |
| new: `EXPECT_OLD_SENDABLE` · `EXPECT_COAST_ADJACENCY_DROPPED` | — | `[50,44,48]` · `[97,83,94]` | the two wrong answers, pinned so neither can be re-derived as an improvement |

**`net_islands` wall time: 1.5 s** (was ~1.0 s) against the runner's 120 s kill. The walker pair count
went 1600 -> 2732 as this plan's risk list predicted; it is nowhere near the timeout and
`harness-manager` is not needed.

---

### 2.4 — the crossing, as a NUMBER (`tools/probe/run_run.gd`, before and after)

⚠ **Reported, not tuned. `Islands.TIME_LIMITS` was not touched.**

| | Before (straight line) | After (water route) |
|---|---|---|
| Baseline plan, node 0 (섬 1) | 24.6 s / 60 s = **41.1%** | 27.1 s / 60 s = **45.1%** |
| node 1 (섬 2) | 19.6 s / 60 s = **32.7%** | 28.2 s / 60 s = **47.0%** |
| node 4 (섬 3) | 36.9 s / 90 s = **41.0%** | 41.7 s / 90 s = **46.3%** |
| node 6 (섬 3, boss) | 43.5 s / 90 s = **48.3%** | 44.2 s / 90 s = **49.1%** |
| **Worst island of the baseline run** | **48.3%** | **49.1%** |
| Islands lost by the baseline | none | none |

**The crossings themselves**, printed per island by the probe — shortest and longest sendable route,
and what each costs at `Rules.BOAT_SPEED` 4.0:

| Island | sendable tiles | shortest route | longest route |
|---|---|---|---|
| 1 | 84 | 9.49 tiles = **2.37 s** | 29.31 tiles = **7.33 s** |
| 2 | 76 | 10.90 tiles = **2.72 s** | 30.97 tiles = **7.74 s** |
| 3 | 82 | 9.49 tiles = **2.37 s** | 29.73 tiles = **7.43 s** |

⇒ **The rise is absorbable, and that expectation was CHECKED rather than assumed**: the worst island
moved 48.3% -> 49.1%, and the time limit still has never once bound. The stop condition
`plan-then-watch` 8.2 sets on the baseline — lose an island, or the worst island above 70% — is still
**미달**, which was already true before this round and is not something this round changed.

---

### ⚠⚠ One finding the plan did not predict, and it is NOT about headlands

**The route is not the straight line even on completely open water**, and that is where most of the
clock rise above comes from. `water_route` descends a **hop-count** BFS — a diagonal step and an
orthogonal step both cost 1 — so among the many equal-hop paths the fixed `NEIGHBOURS` tie-break picks
one that hugs a corner. Measured:

- `net_boat`'s `_bay()` fixture is 4.0 tiles of open water end to end. The route is
  `(2,5) (3,4) (4,3) (5,4) (6,5)` — **up, then back down** — `4 x sqrt(2) = 5.657` tiles, **1.414x**
  the straight line, and 60 sub-steps of crossing became 85
- On the three shipped islands the worst ratio is also **1.414**, and the route is strictly longer than
  the straight line on **82 / 74 / 80** of the sendable tiles — and shorter on none

2.2 chose this deliberately (「mirrors `flow_field`」, and `flow_field` is hop count) and this plan's own
risk list forbids fixing it with a Dijkstra in this round, so it was implemented as specified and
written down in `grid.gd`'s own comment instead. ⚠ **It is the most likely thing to fail S4 at
verify-look**: that row asks for a boat that visibly follows the water rather than cutting a corner,
and a boat that visibly detours over open water where a straight line exists is a different complaint
of the same shape. **A decision for the user, not a defect to patch quietly.**

---

### The mutations run, and the one that got through

Eight, each edited and re-run in ONE command so `[지문]` compares the same tree:

| # | Mutation | Result |
|---|---|---|
| 1 | `_entry_water_tile` back to 4-way (the old `landable`) | **red** — islands · boat · battle · coast |
| 2 | `_paint_route` cuts the corner (`draw_line(points[0], points[last])`) | ⚠ **GREEN at first** — see below |
| 3 | `home_harbour_for` back to straight-line distance | **red** — islands · boat · coast |
| 4 | the refusal mark is never pushed | **red** — shell |
| 5 | `leg` never advances | **red** — boat · shell · fx_view |
| 6 | the return leg recomputes instead of reversing | **red** — boat · plan |
| 7 | `hud_view` reads the ladder again | **red** — shell |
| 8 | `SPEED_STEPS` cut to two entries | **red** — shell |

⚠⚠ **Mutation 2 passed the whole 15-net round at 2095 checks**, and it is exactly the failure this
plan's S4 row predicted. Neither existing instrument could see it: `net_draw_leaf` counts call SITES,
so `draw_polyline(points)` and `draw_line(points[0], points[last])` are both "1 call, every argument
used" — and the runtime check in `net_shell` reads the arguments a **spy** captured, and a spy
overrides the leaf and never runs its body at all (`CLAUDE.md`: *a spy on a hook never sees the native
call inside it*). ⇒ `net_draw_leaf` grew a third scan, `_whole_array_leaves`: the three leaves that
take an array must hand it WHOLE to the named native call and must never index it inside the leaf.
With that, mutation 2 reddens. **The corner cut is the one shape this file had no instrument for, and
only the mutation found it.**
