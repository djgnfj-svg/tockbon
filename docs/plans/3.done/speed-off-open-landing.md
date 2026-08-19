# Plan — delete the speed ladder, and make landing a denylist

**Status**: `3.done` — **implementation finished 2026-08-19, three builder rounds. 15 nets · 2216 checks · green.**
⚠⚠ **`3.done` is not acceptance.** Acceptance rows **A8 and A9 are `user only` and both are OPEN** — the user has not launched this. verify-look drove S1–S5 and all five read right; that is an agent's eyes, not the user's.
Was `2.active`, moved when the user said 「돌려」. ⚠ `title-and-map` stays in `2.active`, **PAUSED**, and its step 5 is being replaced — see `push-inland`. Asked for by the user on 2026-08-19 while watching the game run.
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
  except the last is a water tile** — the last one IS the landing, which is land by construction.
  ⚠ *"The boat arrived"* is not *"the boat sailed on water"* — assert the path, not the
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
| A4 | A boat sent to a beach that was refused before **arrives**, and **every waypoint of its path EXCEPT THE LAST is a water tile** | verify-run. ⚠ Assert the path, not the endpoint. ⚠⚠ **The exception is not a loophole — it is the construction.** `water_route` appends the LANDING as its final point and a landing is land by definition, so the original wording ("every waypoint") was literally false of correct code and a later round deriving a check from it would have reddened honest work. verify-run swept all 242 sendable routes and found 0 non-water waypoints outside the landing |
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

### ✅ **It DID fail S4, and round 3 fixed it — and the fix was not a Dijkstra**

Verify-look photographed it on island 1's bay: the mouth at (24,17) is vertically open from the start
harbour at (24,31), **nothing at all in between**, and the route was a 15-point **V** — seven tiles
down-left to (17,24), seven back up-right — **19.80 tiles against a 14.00 straight line**, with the
hull at t=58.3 heading away from its target across empty sea. **The headland detour beside it read
correctly**, which is what made the V read as *a boat that does not know the way* rather than as a
long sail.

⇒ **String-pulling, as a POST-PASS.** `grid._smooth_water_path` walks the waypoints and drops every
one whose removal leaves a straight segment entirely over water. The bay route is now **3 points and
14.45 tiles**: `(24,31) (23,18) (24,17)`. This is not the Dijkstra the risk list forbade — the field
is untouched and still hop count, and the smoother runs O(n) line tests over a route already legal.

⚠ **The predicate it needs is the one this plan DELETED**, and that is the trap inside the fix:
`_straight_is_all_water` is `water_line_clear` under a new name. **It is a smoothing helper and never
a sendability gate**; as a gate it refused 39–42% of each island's own coastline, which is exactly
what the user threw out. `grid.gd` says so on the function itself, because the next reader who finds
a straight-line test in that file will otherwise "restore" it to `load_rows`.

⚠ **The remainder is not smoothing's to fix.** `net_boat`'s `_bay()` ends at 4.576 rather than 4.000
because `_entry_water_tile` picks the cheapest water 8-neighbour of the landing — (5,4) rather than
(5,5) — so the last hop is a one-tile dogleg onto the beach. Which water tile a boat beaches FROM is
a different rule and round 3 did not touch it.

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

---

### Round 2 — fixer

changed   `src/look.gd` (six world widths raised, three declared deliberately below, the width-table
banner, `CULL_PAD_TILES` added, `GRID_W`/`GRID_H` redocumented as a fallback) · `src/sim/grid.gd`
(`_water_step_open`, wired into `_water_field` AND `water_route`'s descent) · `src/sim/islands.gd`
(the 144 x 32 long map, generated, with a width-derived time limit) · `src/view/field_view.gd`
(`_map_tiles`, `_visible_tile_rect`, both `_draw` loops culled and asking the grid, `_clamp_cam`
asking the grid) · `src/sim/battle.gd` (`boat["home"]`'s comment) · this file's A4 row and its
section 3 twin · five nets (`net_draw_leaf` the width table, `net_coast` two squeeze checks,
`net_camera` two variable-grid checks, `net_islands` the long map, `net_shell` / `net_fx_view` the
culled tile counts) · `net_boat`'s one over-claiming label.

why       The adversarial bounce of round 1 (F1 · F4 · F5 · F6 · F7a · F7c), plus the one small
feature the user asked for on 2026-08-19 — **variable grid size and one long map**
(`idea-inbox` row 52: *"긴 맵 하나 … 추후에 확장 가능하게 코딩만 해주고"*). ⚠ **The deliverable is the
capability**, so the long map is deliberately NOT in `Rules.MAP_NODES` and no node opens it.

closed    **F1** — `ROUTE_WIDTH_PX` 3.0 -> 5.0 (1.35 px -> 2.25 px at `ZOOM_MIN`).
**F6** — the whole twelve-row table, judged one row at a time. **Raised**: `BODY_OUTLINE` 2->5,
`SHOT` 2->5, `BURST` 2->5, `AREA_RING` 3->5, `LAND_RING` 2->5, `ROUTE` 3->5. **Left deliberately
below, with the reason on the constant's own line**: `GRID_LINE` (texture at alpha 0.07 over every
tile, nothing is ever read off it), `TARGET_LINE` (alpha 0.12 x up to 14 lines across the island —
`look.gd` already records this as the one item that can be a net readability LOSS), `SPARK` (its
ceiling is half a shard's length, 2.5, which sits UNDER the floor's 4.45 — it cannot move without
`SPARK_LEN_PX` and `SPARK_REACH_PX`, which is a re-measure of item 2 by eye). `CLIFF_FACE`,
`REFUSE_MARK` and `BEAK` already cleared. The check is `net_draw_leaf._world_width_table`, and it is
**CLOSED against `field_view.gd`'s own text both ways** — a `Look.*_WIDTH_PX` the file draws with
that the table does not hold is red, and a table row the file no longer draws with is red.
**F4** — `grid._water_step_open`: a diagonal water step needs at least one water shoulder, applied in
`_water_field` and in `water_route`'s descent. Two fixtures in `net_coast`, each with its own literal.
**F5** — A4 now reads *"every waypoint EXCEPT THE LAST"*, and section 3's twin sentence was corrected
in the same edit so the two cannot disagree.
**F7a** — `boat["home"]` KEPT, with the reason written on it: its live reader is
`tools/look/capture_landing.gd`, which prints it beside `pos`/`leg`/`dist`. ⚠ **The finding's premise
was wrong** — it is read outside `src/`, not by nothing.
**F7c** — the label is now 「그 해안으로 보내고 확정했다」.
**The feature** — `field_view` asks `battle.grid` for the map size through `_map_tiles()`, both `_draw`
loops and `_clamp_cam` go through it, the terrain pass is culled to the visible span, and
`islands.gd` holds a generated **144 x 32** map at index 3 with a **180.0 s** limit derived as
`TIME_LIMITS[0] / 48 columns * 144 = 1.25 * 144`, the 48 read off island 1's own first row.

not closed  **A7** (S1–S5) — verify-look owns it and nothing here has been looked at; **S4 in
particular is now more likely to bounce, not less**, since six world widths moved and the picture of
a fight changed with them. **A8** and **A9** are **user only**. **`plan-then-watch`'s 결정 4 is still
overturned in the code with its own doc unedited** — carried over from round 1, untouched here.
⚠ **Not done and deliberately so**: the long map is not wired into `Rules.MAP_NODES`, `TIME_LIMITS`
for islands 0–2 was not retuned, and the probe was not re-run — no sim number this round changes what
a shipped island costs. ⚠ **`flow_field` / `step_toward` do NOT carry the shoulder rule**: a walking
soldier can still cut a land diagonal between two impassable corners. That is stated in `grid.gd` and
left open — it is a movement change with its own measurements, not this guard's business.
⚠ **`SPARK_LEN_PX` is also under the snap floor at `ZOOM_MIN`** (2.25 px) and was flagged rather than
changed; it is a length, not a width, and item 2 is scored by eye.

nets      **15 nets · 2203 checks · 4.4 s · green**, stderr clean. Was 15 / 2100 / 4.3 s.
Fingerprint `329806F492CF`.

**Nine mutations, each edited and re-run in ONE command:**

| # | Mutation | Result |
|---|---|---|
| 1 | `ROUTE_WIDTH_PX` back to 3.0 | **red** — draw_leaf |
| 2 | one row deleted from the width table | **red** — draw_leaf, both directions (outside-the-table AND the count) |
| 3 | `GRID_LINE_WIDTH_PX` declared "above the floor" | **red** — draw_leaf, three rows |
| 4 | the shoulder guard removed from `_water_field` | **red** — coast |
| 5 | the shoulder guard removed from `water_route`'s descent | **red** — coast (the field alone is NOT enough) |
| 6 | `_map_tiles` ignores the grid and returns `Look.GRID_W`/`GRID_H` | **red** — camera, 7 rows |
| 7 | the cull never bites (span = the whole margin ring) | **red** — camera · shell |
| 8 | the cull cuts one tile INTO the view | **red** — camera · shell (the coverage floor) |
| 9 | the long map's limit hardcoded to 120.0 | **red** — islands |

⚠ **Mutation 5 is the one worth reading.** The bounce named `_water_field` only; guarding the field
alone leaves `water_route` free to descend THROUGH a squeeze, because it takes the cheapest strictly
lower neighbour and a squeezed tile some other path reached cheaply is exactly what it prefers. The
field can be clean and the sailed route still cuts the seam. That needed its own fixture
(`_the_descent_home_never_squeezes`) — the first one cannot fail it.

⚠ **One check was DELETED rather than updated, and it is the honest half of this round.**
`net_fx_view`'s 「4032칸」 could not survive the cull, and the replacement bound `< 4032` would have
passed with culling switched off entirely — that fixture's grid is 24 x 12, so its whole margin ring
is 1728 tiles. A guard that can never bite must not be described as the guard. What replaced it is
the property the count was standing in for: **the painted area contains the visible world**, asserted
against the ring intersected with the view, at 40 camera states across both grid sizes in
`net_camera`.

---

### Round 3 — fixer

changed   `src/sim/grid.gd` (`_smooth_water_path` + `_straight_is_all_water`, wired into
`water_route` after the descent) · `src/sim/rules.gd` (`ROUTE_SMOOTH_SAMPLE_TILES`) ·
`src/view/field_view.gd` (the empty-array guard on the cliff-face call) · six nets — `net_boat`,
`net_battle`, `net_islands`, `net_coast`, `net_shell` (crossing literals re-derived) and
`net_fx_view` (the new cliff-free-view check) · this file's own 「One finding the plan did not
predict」 section, which was describing a defect that is now fixed.

why       The two defects verify-look found with pictures. **D1** — the boat did not go straight in
open water, on the FIRST route a player would draw. **D2** — stderr was not clean during capture and
round 2's report said it was.

closed    **D1.** Island 1's bay mouth (24,17) is vertically open from the start harbour (24,31),
nothing in between, and the route was a **15-point V**: seven tiles down-left to (17,24), seven back
up-right, **19.7990 tiles against a 14.0000 straight line**. After string-pulling it is **3 points,
14.4526** — `(24,31) (23,18) (24,17)`. The remaining 0.45 is `_entry_water_tile` beaching from
(23,18) rather than (24,18); that is a different rule and it was not touched. Every crossing on every
island got shorter and **none got longer**: wave-1 `15.14/45.80 -> 11.85/42.99`, `13.49/47.80 ->
11.20/44.83`, `15.14/45.80 -> 13.08/42.99`; steady `9.49/29.31 -> 7.41/27.98`, `10.90/30.97 ->
8.41/30.14`, `9.49/29.73 -> 7.41/28.23`.
**D2.** `canvas_item_add_multiline` fails on an empty array, and the cull made a cliff-free view
reachable. Guarded at the CALL SITE (a leaf that sometimes draws nothing stops being pinnable at one
call), and `net_fx_view._a_cliff_free_view_hands_the_leaf_nothing` drives the camera to the bottom of
island 1 at `ZOOM_MAX` — where row 2, the only cliff row, is outside the span — and asserts on the
ARGUMENT rather than the call count, with a cliff-containing frame beside it as the floor.

not closed  ⚠⚠ **THREE THINGS VERIFY-LOOK MEASURED AND I WAS TOLD TO RECORD, NOT FIX:**
- **`TARGET_LINE` at 0.45 px and alpha 0.12 is invisible, not restrained.** Verify-look could not find
  one until it knew where to look and zoomed 4x. Round 2 left it deliberately below the floor on the
  argument that 14 lines would be clutter — **that is preventing a problem nobody has ever reached.**
- **`SPARK` contributes nothing measurable.** A full-frame pixel scan found **43 spark-coloured
  pixels in the busiest of 143 combat frames**, many of them actually tracers. The hit still reads via
  the white flash and the grey halo, so nothing is broken; the shards are simply not there.
- **`CLIFF_FACE`'s LINE is near-invisible** — 0.02 on 0.098, black on black. 「못 내림」 is carried by
  the cliff **FILL**, not by the face line the plan credits. ⚠ **S3 passes for a different reason than
  this plan says it does.**

⚠ **The probe was NOT re-run.** Every crossing is shorter now, so 2.4's table (45.1% / 47.0% / 46.3%
/ 49.1%) is stale in the loose direction — the clock has more slack than those numbers say, not less.
Reporting the new figure is a measurement job, not a builder's.
⚠ **Round 1's re-measured `net_islands` table above is stale in two rows** (`EXPECT_WAVE1`,
`EXPECT_STEADY`); it is left as the record of that round, and this entry is the correction.
⚠ **A4 · A7 · A8 · A9 unchanged**: A4's wording was fixed in round 2, A7 now has S1/S2/S3/S5 passing
and S4 re-photographed against this fix rather than closed by it, and A8/A9 are **user only**.
⚠ **Still open from round 2**: `flow_field`/`step_toward` carry no diagonal-shoulder guard;
`SPARK_LEN_PX` is under the snap floor at `ZOOM_MIN`; `plan-then-watch`'s 결정 4 is overturned in the
code with its own doc unedited.

nets      **15 nets · 2216 checks · 4.4 s · green**, stderr clean. Was 15 / 2203 / 4.3 s.

**Two mutations, each edited and re-run in ONE command:**

| # | Mutation | Result |
|---|---|---|
| 10 | the empty-array guard removed from the cliff-face call | **red** — fx_view (the cliff-free frame captures an empty array) |
| 11 | `_smooth_water_path` removed from `water_route` | **red** — 38 checks across islands · boat · battle · coast · shell |

⚠⚠ **The literals were re-derived OUTSIDE Godot and then cross-checked against the engine**, because
this round retypes numbers in the one table this file's own header warns about re-measuring by
halves. A from-scratch reimplementation of the BFS, the descent, the smoother and the sampler — **including
GDScript's round-half-away-from-zero, which Python's banker's rounding does not share** — produced all
242 sendable routes on the three islands, and every one agrees with the engine to 1e-3. ⚠ The first
run of that model disagreed with the engine on the maxima; the cause was the smoother's own corner
rule, not the rounding, and it was found by diffing rather than by picking whichever number was
convenient.

⚠ **One tolerance was loosened and it is the row to be suspicious of.** `net_boat`'s
「time ratio == length ratio」 was `<= 0.01` and is now `<= 0.05`. **The derivation, not a nudge**: both
counts are whole sub-steps ceiling'd off a real crossing, so the ratio carries up to
`ratio / near_steps = 3.158 / 69 = 0.046` of rounding error. The old 0.01 held only because the two old
crossings happened to round the same way — it was luck, and the smoother is what exposed it.

⚠ **One check was rewritten rather than repaired, and the reason is in it.**
`net_coast._a_route_walks_the_field_down_one_step_at_a_time` demanded `field[route[k]] == k` and
Chebyshev-1 between neighbours; **string-pulling makes both false on purpose.** It now asserts what it
was really guarding — starts at the harbour, field values strictly increase, every segment is straight
and all-water **sampled by an independent walker written out in the net** rather than by calling back
into `grid`. Plus the ceiling that says the smoother ran: 4 points where the raw descent gave 8.


---

## ⚠ Known risk carried out of this plan — **the smoother spends clearance, and nobody set a floor**

Measured by verify-look on the headland route (island 1, `07_nw`), before and after string-pulling:

| | waypoints | length | clearance from the headland corner |
|---|---|---|---|
| before | 27 | 45.80 | **two tiles** — the raw path went out to column 0 |
| after | 5 | 42.99 | **~3 px at `ZOOM_MIN`** |

**The line never touches green** — zero pixels, checked at 8× — and the boat's centre is on water in every
frame. ⚠ **But the hull sprite is 18×22 px**, so while rounding the corner (one frame of twelve, ~0.3 s of
a 7 s crossing) its top-right covers about **13×5 px of the last land row.** At play scale it reads as
*a boat hugging the shore*, which is fine — it took a pixel scan to find.

⇒ **What is NOT known**: whether that clearance can go negative on a headland this repo has not drawn yet.
`_straight_is_all_water` guarantees the **centre line** stays on water and says nothing about hull width.
**The terrain set is about to grow** (a hand-authored pool, user 2026-08-19), so the map that makes this
negative is one nobody has authored. ⚠ **A hull-width margin was NOT added** — over-constraining the
smoother would undo the fix that made the bay route straight, and no number exists for how much margin is
right. **Decide it when a map shows it, and measure rather than guess.**

---

### Round 4 — fixer

changed   `src/sim/battle.gd` (`_the_landing_force_is_gone`, replacing `army.living_count() == 0` in
`_phase_clock`) · `tests/nets/net_battle.gd` (three new checks) · `tests/nets/net_run.gd`
(`_timeout_loses`' fixture, and why). **No `src/view` and no `look.gd`** — the 1~5 slot plan owns those.

why       The user played it and reported the fight never ending after the plan had already failed:
***"실패조건은 시작하기하고 못깨면 이지 제한시간을 계속 기다리고 있길래"***. `_phase_clock` lost on
`army.living_count() == 0`, and `living_count` counts every soldier that is not dead — **reserves at
the harbour included.** After the commit `send` refuses everything, so a reserve can never be landed:
hold anyone back, lose everyone you sent, and the run is decided and cannot end. **The old test could
not fire.** The player watched an empty island for the rest of the clock.

closed    **The rule as implemented**: after the commit, LOST the moment no LIVING soldier is `ASHORE`
or `TRANSIT`.
- **Gated on `_committed`, the same flag `send` reads** — one flag, not a second copy of the idea.
  Without it every soldier is RESERVE on the frame an island opens and the island is lost immediately.
  ⚠ `step` already returns before `_phase_clock` while uncommitted, so the gate is unreachable through
  the public path; `net_battle._the_gate_itself` drives it directly, because an unreachable guard is
  what the next person deletes as dead code.
- **TRANSIT counts.** Collapsing to ASHORE-only throws away the last crossing one sub-step before it
  resolves, which is a fake failure and the most interesting case on the island.
- **`Lose.WIPED` kept** — see below for the argument that it should not stay that way.
- **`TIMEOUT` untouched.**

**The margin, measured**: `net_battle._reserves_do_not_hold_the_run_open` lands one of three soldiers,
holds two at the harbour, drives the crossing, kills the beachhead through `army.hp = 0` and one
sub-step so `_phase_deaths` writes the state the way the fight does — and the island is LOST
**inside 2 s against a 90 s limit, with more than 85 s left on the clock**, which is what the two
assertions pin. The arithmetic behind those bounds: `_port()`'s crossing is 4.576491 tiles at speed
4.0 = 68.65 sub-steps, so the beachhead lands on **69** and dies on **70** ⇒ `70/60 = 1.167 s`.
⚠ **The gap is the check.** `elapsed <= time_limit`
is also true of the behaviour being fixed. And the floor under it: **`army.living_count() == 2` at the
moment of the loss** — two soldiers alive, run over. That is the one line the old rule cannot pass.

not closed  ⚠⚠ **`Lose.WIPED` IS NOW INACCURATE AND I KEPT IT ANYWAY.** The screen reads
「패배 — 전멸」, and in the case this round exists for the player is looking at eight living soldiers
standing at the harbour while being told they were annihilated. **A screen that says something the
screen also disproves is how a screen stops being trusted.** It deserves its own reason — 「상륙 실패」
or similar — but naming it costs a `panel_view` string, and `src/view` is off limits this round. ⇒
**A follow-up, not a silent addition.**

⚠⚠ **THE TWO SOLDIER COLUMNS CAN DISAGREE, AND NOBODY ASKED ABOUT THIS.** `_phase_deaths` opens with
`if army.alive[i] == 0 ... continue`, so a soldier killed through `army` from OUTSIDE the fight is
skipped forever and keeps whatever `soldier_state` it had. Nothing in `src/` does that today — but
`net_run._wipe_loses` does, and it reddened the first draft of this fix, which read `soldier_state`
alone. **A rule that answers "still in the fight" for a corpse holds the run open exactly as the
reserve bug did, one column over.** The rule now reads BOTH columns. A between-island effect or a
save/load would have walked straight into it.

⚠⚠ **`net_run._timeout_loses` ONLY EVER PASSED BECAUSE OF THIS DEFECT.** It landed one soldier, held
nine back, and asserted the run took all 3600 sub-steps. With the fix, the lone soldier meets a bison
and the island is lost at **477 sub-steps (7.95 s)** — **the other 52 seconds it used to assert were
the bug.** Its limit is cut to 5.0 s so the timer is once again the only thing that can end that
island, and the claim it was doubling up on — that `Islands.time_limit_of(0)` is what reaches the
battle — is pinned on its own line at the top of that file. ⇒ **A green check can be an artefact of
the defect beside it.**

⚠ **The probe has not been re-run and its grading scale is now different.** `run_run.gd` scores every
plan as a % of the time limit; runs that used to finish at TIMEOUT with reserves alive now end sooner
and lose. Any comparison against 2.4's table crosses that change.
⚠ **Carried, untouched**: `flow_field`/`step_toward` have no diagonal-shoulder guard · `SPARK_LEN_PX`
is under the snap floor at `ZOOM_MIN` · `TARGET_LINE`, `SPARK` and the `CLIFF_FACE` line are round 3's
three recorded-not-fixed findings · `plan-then-watch`'s 결정 4 is overturned in the code with its own
doc unedited.

nets      **15 nets · 2248 checks · 4.4 s · green**, stderr clean. Was 15 / 2216 / 4.4 s.

**One mutation, edited and re-run in ONE command:**

| # | Mutation | Result |
|---|---|---|
| 12 | `army.living_count() == 0` restored in `_phase_clock` | **red** — battle, on exactly the three rows designed as the floor (LOST · WIPED · 「two soldiers are still alive」) |

---

### Round 5 — fixer

changed   `src/sim/battle.gd` (`Lose.LANDING_LOST`, and the precedence in `_phase_clock`) ·
`src/view/panel_view.gd` (`MSG_LOST_LANDING`, its branch, and a note on why a new `Lose` member opens
no new state) · `tests/nets/net_battle.gd` (two reasons corrected, one precedence check added) ·
`tests/nets/net_shell.gd` (`_every_lose_reason_reads_differently`) · `docs/how-nets-lie.md` (one new
case). **Nothing the 1~5 slot plan owns**: no `field_view`, no `look.gd`, no `hud_view`, no `game.gd`,
no `rules.gd`.

why       Round 4 shipped a loss the screen described wrongly. 「패배 — 전멸」 while eight living
soldiers stand at the harbour is a band contradicting the picture under it, and that is how a screen
stops being read at all. Round 4's own `not closed` argued for this; it is now built.

closed    **The reason**: `Lose.LANDING_LOST`, appended (never inserted — these are ordinals a saved
run could hold). **The message**: **「패배 — 상륙 실패」**, a title like the other four rather than a
sentence about reserves, because the panel is read at a glance and the reserves are visible underneath
it.
**`WIPED` stays reachable and stays distinct** — it is *every soldier you own is dead*, which is a
different fact from *everyone you sent is dead*.
**The precedence, stated and pinned**: both are true when the last body dies with nobody in reserve,
and **`WIPED` wins** — it is the stronger claim and the more useful one to read. It is written on the
`Lose` enum, applied in exactly one expression in `_phase_clock`, and pinned from both sides:
`net_battle._wiped_wins_when_both_are_true` sends everybody and kills everybody, and
`_reserves_do_not_hold_the_run_open` reaches the same condition holding two back and must answer
`LANDING_LOST`.
⚠ **The `army.living_count() == 0` expression is back — as the REASON, which is the question it was
always the right answer to.** It was wrong as the CONDITION (round 4) and is exactly right here: it is
what 「전멸」 means.

**The `panel_view` trap was checked, not assumed.** `_draw` returns on `not panel_active()` before
`_message_text` is ever called, and `panel_active` keys on `Run.State` alone — the band and the panel
are one path. The five-way failure that file's own paragraph describes needs a new `Run.State` member;
`Lose` is not one. A note saying so now sits on `_message_text`.

**The pinned literals**: ⚠ **nothing pinned a count, and that was the worse half.** Only three of
`panel_view`'s five message constants were ever named by a net, none by count, and **`_message_text`
had never been driven for a loss reason at all** — a fourth string could have been added, wired to
nothing, with every round green. `net_shell._every_lose_reason_reads_differently` drives it once per
`Lose` member and demands the four come out DIFFERENT, **closed against the enum read out of
`Battle`'s own constant map** rather than against a list written in the net. A fifth reason gets its
own line or reddens.

not closed  ⚠ **「상륙 실패」 has not been read by the user or by verify-look.** It is the lead's
wording and I took it rather than invent — my only reservation is that it names the *attempt* when
what failed is the *beachhead*, and 「교두보 상실」 is more precise and heavier to read at a glance. **A
wording call belongs to whoever sees it on screen.**
⚠ **The probe has not been re-run** and its grading scale changed in round 4 (plans that used to run
out the clock now end sooner and lose).
⚠ **Carried, untouched**: `flow_field`/`step_toward` have no diagonal-shoulder guard · `SPARK_LEN_PX`
is under the snap floor at `ZOOM_MIN` · round 3's three recorded-not-fixed findings (`TARGET_LINE`,
`SPARK`, the `CLIFF_FACE` line — **S3 passes for a different reason than this plan says**) ·
`plan-then-watch`'s 결정 4 is overturned in the code with its own doc unedited.

nets      **15 nets · 2263 checks · 4.4 s · green**, stderr clean. Was 15 / 2248 / 4.4 s.

**Two mutations, each edited and re-run in ONE command:**

| # | Mutation | Result |
|---|---|---|
| 13 | the precedence flipped (`LANDING_LOST` when everyone is dead) | **red** — battle (3 rows) · run (`_wipe_loses`) |
| 14 | `_message_text` returns `MSG_LOST_WIPED` for `LANDING_LOST` — the copy-paste branch | **red** — shell, on the text AND on the distinctness count |
