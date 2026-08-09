# Water — flows, pools, wets

**One line**: water is an **amount** per cell. A lot of it is water, a little of it is wet.

**Implemented**: full — **all six stages run.** Chunk sleep · water amount · falling ·
left-right sharing · shallow-water color · water rune · water puts out fire.
**Not done**: wet wood (does wood remember being wet) · drying over time · lightning · steam ·
color varying continuously with depth — all under "TBD" below.

**Accepted**: **partial pass (2026-08-08)** — **the user has seen exactly one thing, the spread speed.** The rest was verify-look.
- Pass: water flows like water (not stairs) · total volume conserved · active chunks go to sleep ·
  breach it and it pours · no floating water at chunk borders · shallow water reads as a wet stain ·
  **spread speed** (user, `WATER_SUBSTEPS = 3`)
- **Acceptance 7 — the cliff is gone.** `MAX_CHUNKS_PER_TICK` 512 → **100**.
  **Cost became independent of water volume** (at 65,677 cells, 512 was 724% of budget, 100 is a flat 219%).
  **FPS itself was not measured** — headless uses the dummy renderer. And **a worst-case tick is still 2.2× budget**
- **Newly caught — it reads as "fire burns underwater".** The rule "shallow water can't put out fire"
  runs exactly right, but **one cell of wood (4px) under the blue line is invisible on screen.**
  **The two water colors were pushed apart in brightness to fix it, and nobody has looked**
- **The biggest one — "water feels like background"** (user, by eye).
  "The water has no effect on me whatsoever" ⇒ **`character.gd` contains zero references to `WATER`.**
  **The two lines below are symptoms of this.** Details in "Water pushes the character"
- **Falling is a trickle** — "there's tons of water and it comes down one row at a time · the simulation feels cheap"
  ⇒ "Falling has no acceleration" below. **This is not a wrong value; it's a missing axis.**
- **Three things for the user to decide** — the two water colors · the sky-blue fragments above the surface ·
  cap 100 vs 33 ("one hitch while pouring" vs "always slightly slow").
  Details in `docs/plans/3.done/water-and-chunk-sleep` "Acceptance"

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).
The implementation spec is `water-and-chunk-sleep` under `docs/plans/`; the game-wide source is `../GDD.md`.

---

## Read before building water — where v1 died

**In v1, lightning would not go out. The cause was not lightning; it was water.**

Water grains **ping-ponged forever on a flat floor**, and moving water re-registered into the charge
burn slot every tick, keeping lightning alive forever. ⇒ **Time was lost fixing the wrong thing.**

**So "does the water stop" is this feature's first acceptance check.** Reaching equilibrium and stopping
completely comes before flowing prettily. Water that never stops doesn't just kill lightning —
it **never lets a chunk sleep, which kills the whole game** (see "Cost").

This clause used to be a footnote in `GDD.md`. **Whoever builds water doesn't read there, so it moved here.**

---

## Why amount, not grains

Water in a 2D cell game is usually one of two things.

| Approach | How | Here |
|---|---|---|
| **Grains** (Noita · Powder Toy) | One cell = one grain. Falls; blocked, moves sideways | **v1 was this and died on the ping-pong bug.** Also water stacks as stairs instead of lying flat |
| **Amount** (Terraria · Starbound) | Per-cell amount 0–255. Push down, share the remainder left/right | **This one** |

**The decisive reason for amount is not the picture — it is that movement is trapped at the surface.**

> **This paragraph was overturned once by measurement.** It used to say "once amounts equalize left and right
> there is nothing left to move, so **the computation ends by itself**". **That is only true in narrow water** —
> spec measured headless:
>
> | Bowl width | Stops? |
> |---|---|
> | 32 cells | stops at 2,798 ticks (140s) |
> | 128 cells | ~~**does not stop by 4,000 ticks**~~ → **stops at 1,032 ticks (52s)** |
>
> Halving is **diffusion**, so flattening takes time proportional to the square of the width.
> **Total volume was conserved exactly — it isn't leaking.**
>
> > **⚠ The 128-cell row was re-measured and is now the opposite of what it said.**
> > The **same bowl** (`net_water._make_bowl(128, 900, 32, 8)`) settles at **1,032 ticks**, total conserved,
> > driven headless by `tools/stage/measure_water_rest.gd` and reproduced independently by two agents.
> > **The old figure was right when it was taken. Nobody knows when it stopped being right** — the behaviour
> > changed at some point between then and now and no one noticed, for the reason in the box below.
> > **Note it is 1,032 < 2,798**: the wider bowl now settles *faster* than the narrow one, which is the
> > reverse of the diffusion argument above. **That is unexplained and nobody has explained it** — the two
> > bowls differ in poured columns and depth as well as width, so it is not a clean width comparison.
> > **Do not read a law out of two rows.**
>
> > **Why nobody noticed the behaviour change: the only check watching it had gone blind.**
> > Its observation window sat **entirely after the water had already stopped**, so it measured 0 movement and
> > passed — for the same reason it would have passed on an empty grid. **A check that samples the wrong
> > interval does not fail loudly; it succeeds quietly and stops being a check.** It is fixed now.
> > This is CLAUDE.md's *"a loop whose condition is false from the start never runs the check at all"*
> > wearing a different face — here the loop ran, it just ran where nothing was happening.

**But not finishing is cheap. That was the real reason.**

| Bowl width | Chunks holding water | Awake chunks (max) |
|---|---|---|
| 32 cells | 6 | **7** |
| 128 cells | 18 | **16** |
| 256 cells | 30 | **18** |

Eight times the width takes awake chunks from 7 to 18. **The interior of the lake is packed, blocked above
and below, moves nothing, and sleeps next tick** — only the **surface band** stays awake.
⇒ 18 chunks × 41μs ≈ **740μs/tick = 1.5% of budget.**

**This is exactly where v1 diverges.** In v1, moving water re-registered into the charge burn slot every tick,
so **movement was the cost.** With grains, changing position *is* a state change, so **the whole lake keeps moving.**
With amounts that movement is **trapped at the surface** — that is why the v1 bug doesn't recur, not "because it finishes".

**So the correct sentence is not "water always stops" but "water fails to stop cheaply".**
**This distinction returns when lightning arrives** — v1 died with lightning hanging off water that never stopped.

**Chosen knowing the price**: splashing droplets when it pours look better with grains.
That can be **added separately as presentation** (`src/view/`) — a different question from making the sim grain-based.

---

## Wet is not a separate state — it is a little water

**Decided by the user.** The biggest simplification in this design.

```
amount 0             dry cell
amount 1..threshold  wet        ← "is it wet" = "is there any water at all"
amount threshold..255 water
```

⇒ **No state bit like `FLAG_WET`.** Two rules become one.

> **But this bit cannot mark "the surface". That's structural.**
> builder found it in the code while building stage 4.
>
> **Water fills from the bottom, so a settled column stacks 255s and only the top cell holds the remainder.**
> How big that remainder is **depends on how much was poured:**
>
> ```
> remainder >  threshold  ⇒ not one row of the surface splits   (the surface reads as one solid mass)
> remainder <= threshold  ⇒ the entire surface splits at once
> ```
>
> ⇒ **It is not "one bright row at the surface".** A small change in poured volume flips it.
>
> **And it isn't "on or off" either** — verify-look saw it on screen and corrected this.
> `WATER_MIN_DIFF` means "don't move if the neighbor differs by ≤4", so **a still surface is not uniform:**
> ```
> surface amounts  99 → 80 → 58 → 35 → 11 →(one cell down) 239      shallow surface cells 8 / 36
> ```
> **On screen it reads as one or two short sky-blue fragments floating above the surface. Like a stain.**
> In a control scene with the surface hand-leveled it **laid down as one row across the full width and looked good** —
> the only difference is uniformity. ⇒ **Left for the user to decide.**
> **So "brighten the top of pooled water so it reads as liquid" cannot be done with this bit.**
> That belongs to **color varying continuously with depth** (a third texture) and is out of scope.
>
> **This bit's real home is the edge of a thinly spread puddle** — a **wet stain** — and it splits cleanly there.
> **A net demonstrated it by accident**: pouring one 255 cell onto an open floor and letting it settle gave
> **zero deep cells** — it all spreads until everything is shallow. Walls are needed for shallow and deep to coexist.

**And this also solves the cost of wetness drying.** Below threshold there is **nowhere left to spread, so it
doesn't move, so the chunk sleeps.** ⇒ Wet stains can cover the map **for free.**

**"Dries over time" is still expensive** (the trap table under "Cost"). Not decided now —
wetness earns its keep by conducting lightning, and **there is no lightning rune, so there is nothing to measure.**

---

## Where water comes from — both

**Decided by the user.**

| Source | What |
|---|---|
| **Already on the map** | Lakes · rivers · groundwater. Drawn together with the stage-1 terrain |
| **Made by the water rune** | On impact, water appears there. GDD: "water rune + spread → 8 small waters after impact" |

**How much a rune makes varies with spell power** — the same place blast radius already varies per tier
(`sim_tuning.SIM_SIZES`). The implementation spec sets the values.

**It has to be both, because of combos.** With water only on the map, **you have to drag a monster to the
waterside** to wet it and shock it. A rune that makes water lets "wet it → shock it" hold anywhere,
which makes the GDD's thesis (**"different order, different result"**) actually usable.

---

## Meeting other things

| Meets | How | State |
|---|---|---|
| **Terrain** | Stone and wood hold water. It becomes a bowl; magic breaching the bowl makes it pour | Settled |
| **Fire** | **Water in a neighbor cell prevents ignition, and puts out what was already burning** | **Works.** Below |
| **Fire → water** | Fire dries a wet spot | **TBD.** The symmetry is nice and it's cheap (fire already runs) — awaiting the user |
| **Lightning** | Travels through water and wet things | **No lightning rune.** It is water's counterpart; without water lightning is half a feature |
| **Character · monsters** | They get wet; wet conducts electricity (GDD) | **A separate axis from cell wetness** — there are few characters, so drying by timer is free |
| **Wood** | Wet wood doesn't burn? | **Still TBD.** See the box below — **do not read it as solved** |

> **The two rules of "water puts out fire" — and how this differs from "wet wood"**
>
> **Two places ask, both on the burn-slot side:**
> - **`_ignite_cell`** — a water neighbor means **it never catches**
> - **`_burn`** — water appearing **newly** next to an already-burning cell puts it out (shooting a water rune at fire)
>
> **With only the second, you get oscillation** — catch, out, catch, out. Measured **37 ticks**
> (not infinite; it ends when the neighboring wood's fuel runs out). What remains is **waste and flicker**,
> and **flicker reads as a malfunction on screen.**
>
> **The water side never asks "is there fire next to me"** — that would make every water cell read four
> neighbors every tick, which **wakes the entire still lake** and kills "only the surface band is awake".
>
> **There is a threshold — it must exceed `WATER_WET`** (decided by the user).
> **The rule used to be "one drop of water and it won't burn", and the condition for reviving that paragraph
> was written down in advance** — "when a thin drop putting out a large fire **looks excessive on screen**".
> **Exactly that happened on screen** (④ below).
>
> **But no third threshold was created** — it reuses the existing `WATER_WET` (the shallow-bit line).
> ⇒ **Rule and screen share one line: bright sky-blue wet stains can't extinguish, dark navy real water can.**
> **"Why can't this water put out fire" is already drawn on screen.** That is the value of this choice.
> **The price**: `WATER_WET` now sets **both color and fire-proofing** — tune one and the other follows.
>
> **Water is not consumed by extinguishing** — **structural, not taste.** Reducing water means passing through
> `_write_water`, which wakes the chunk ⇒ **a lake next to a burning forest would wake every tick.**
> ⇒ **The water stays.**
>
> **This used to say "one puddle is an infinite fire extinguisher", and looking at the screen proved it wrong**
> (verify-look). `_water_adjacent` only looks at **the four neighbors of the burning cell** ⇒
> **only cells touching water don't burn. A puddle does not put out a fire mass.**
>
> | Wood | On screen |
> |---|---|
> | **Thickness 1** (forest floor) | Fire stops at the water and dies in 20 ticks. The forest across survives |
> | **Thickness 6** | **Fire passes under the water and burns everything across.** Only the **top row** touching water survives |
>
> A **band of water-topped wood** is left across the burned ground, and it **reads naturally as "only the wet
> bark survived"** — not as a malfunction. **But seeing fire keep spreading after you poured a puddle reads as
> a bug the first time.**
>
> ⇒ **"Wet places don't burn", not "places near wet don't burn".**
>
> #### ④ And "one F press fireproofs 860 cells of forest" — **fixed**
>
> Water isn't consumed · touched cells don't burn · **and it kept spreading sideways past 200 seconds.**
> The product of three. On screen the water became **a thin band running off both edges** and every tree under
> it never burned again. ⇒ The user picked **the middle term**: **shallow water can't put out fire.**
>
> **The first term (water isn't consumed) and third (it keeps spreading) are unchanged** — only "does that band
> become a firebreak" was fixed.
> **Net measurement**: pouring one blob onto a row of wood settles into a sheet of **max 27 across 17 cells**,
> all below threshold. The forest under it **burns down to 1 surviving cell** (a deep control at the same spot leaves **56**).

---

## Water spreads to the edges of the screen — the product of three decisions

**verify-look found it on screen. The biggest thing this implementation hits in the game.**

One **F press** (radius 16 cells) onto a flat row of wood:

```
t500   width 196      t2,000  width 336
t1,000 width 259      t4,000  width 424   ← 200 seconds in and still growing
```

**On screen the water becomes a thin band running to both edges with no visible boundary.**
The character wades ankle-deep — **it reads as a shallow sea, not a puddle.**
**And every tree under that band is permanently fireproof. One F press fireproofs a forest.**

**Not a bug — the product of three decisions:**
1. **Water isn't consumed** (extinguishing doesn't reduce it — structural reason in the box above)
2. **Touched cells don't burn** (no threshold, just "is there water")
3. **A flat floor has no walls, so it spreads sideways forever** (`WATER_MIN_DIFF` is 4, so the tail is long)

**The stopping width was not measured** — derived from the rest condition, the estimate is **about 860 cells.**
Only "424 at 4,000 ticks and still growing" is measured.

> **⚠ These two numbers are of unknown currency, and they have NOT been corrected.**
> The bowl figure above (128 cells) was re-measured tonight and came back the opposite of what it said.
> **This is a different scenario** — a bowl is walled and holds a fixed volume, this is open floor with no
> walls at all — so **the bowl's 1,032 ticks does not replace anything here.** But both were taken in the
> same era by the same methodology, and the bowl's turned out stale.
> ⇒ **Nobody has re-measured the flat-floor spread.** `424 @ t4,000` and the ~860 estimate are left standing
> **as the last measurement taken, not as current fact.** They are not silently patched with a number
> nobody drove, and no replacement is invented here. **Re-measure before building on either.**

**Three candidate fixes** (**all user decisions. Each bites something different**):
- **Consume water when extinguishing** ⇒ overturns decision 1. **A lake next to a burning forest wakes every tick**
- **Raise `WATER_MIN_DIFF`** ⇒ shorter tail. **The surface visibly tilts** (acceptance 2)
- **Shallow water can't extinguish** ⇒ overturns decision 2. **A third water threshold appears**

> **Only four directions; no diagonals** — confirmed by value (each of the four blocks · diagonal-only water still ignites).
> **`ignite()` (the door nets and the stage use directly) is subject to it too.** Next to water it **silently returns false** —
> intended, but **unwritten anywhere it reads as "I'm igniting directly, why won't it catch".**
>
> **And this is not "wet wood".**
> - **What works now**: wood **next to** water doesn't burn. **The wood cell itself changes nothing** —
>   drain the water and that cell **burns immediately**
> - **Still TBD**: does wood the water **passed through** stay unburnable after drying (= **does wood remember wetness**)

---

## Cost — water isn't an optimization problem; chunks are a prerequisite

**Measured** (headless, `Godot_v4.7.1 --headless --script`):

| Measured | Value |
|---|---|
| Grid | **4,128,768 cells** (4096 × 1008) |
| **One full-grid sweep in GDScript** | **62,676μs** |
| 20Hz tick budget | **50,000μs** |

**One sweep is 125% of budget.** "Build it and optimize later" **does not work** here.

⇒ **Chunk sleep is water's prerequisite.** The grid splits into 16×16-cell pieces (16,128 of them), and
**only pieces where something moved this tick run next tick.** Water at equilibrium sleeps; a blast breaching the bowl wakes it.

**The traversal-order contract is already inlined at the head of `src/sim/cell_grid.gd`** (v1 bought it expensively
and the v1 file is gone). Bands bottom→top · rows within a band bottom→top · columns opposite the preferred direction.
**Nothing to reinvent — that comment is the source.**

### No cap on total volume

**Still water is free.** At equilibrium the chunk sleeps and uses zero CPU. A lake of any size costs 0 while it sits.
The expensive part is **the moment it pours**, and that's the few seconds after the dam breaks.

⇒ **No fuel-style limiter for water.** Where you put a big lake *is* level design, and
"blowing this up would be a sight" is fun, not a bug.

**Only a safety net** — a cap on chunks per tick. The overflow pushes to the next tick.
On screen it looks like **"water flows slowly for a moment"** and it **never stops or vanishes.**
Exactly the same idiom as `MAX_BURNING` — **a safety net, not a tuning knob.**

#### But being pinned at that net costs **168% of budget** (found incidentally by harness-manager)

**It came out of measuring why the nets were slow.** It looked like a net problem; it was **the sim itself:**

```
src.tick()   2.3 ms      pouring water is cheap
g.step()    84   ms      when active chunks sit at the cap (100)
tick budget  50   ms      (20Hz)
```

**⇒ While pinned at the cap, 20Hz is not achieved.** That is what "water flows slowly for a moment" actually is,
and **the paragraph above is written so it reads as safe.** Nobody had measured the cost at the moment the net bites.

**It has not shown up on screen yet** — verify-look saw **60 FPS held, no hitching or stutter** in the real game
(active chunks were 76–100, frequently at the cap). **Headless measurement and the real game disagree — why was not measured.**

**⇒ The current rain (width 176 cells · 20,000 per tick) sits right on that line. Widen it or speed it up and it goes over.**
**When someone proposes enlarging the boss room (20×12), this is the price.**

### Design phrases that blow the budget

| When the design says | What actually happens |
|---|---|
| "water dries over time" | Drying cells must be counted every tick ⇒ **that chunk never sleeps** |
| "wetness fades gradually" | Same. Spread wet stains wide and **the whole map stays awake** |
| "water ripples slightly" | Equilibrium disappears ⇒ **the same outcome as v1's ping-pong bug** |

**All three arrive under the banner of "natural", and all three void chunk sleep.**
If needed, do it **as presentation** (`src/view/`) — the screen rippling and the sim rippling are different jobs.

---

## Screen

**Water looks like two things** — water and shallow water (= wet).

**Only one material.** Depth rides on a state bit:

| What | Where |
|---|---|
| The water material | One row in `cell_materials.DEFS`. **1** palette slot |
| Water amount (0–255) | `_aux` |
| Shallow? | One `_flag` bit |

**There is a reason not to split the material into "water" and "shallow water"** — the material would have to
change every time the amount crosses the threshold, and the door that writes materials (`_write_cell`)
**zeroes `_flag` and `_aux` together.** ⇒ **The water amount vanishes on the spot.** Not one error is raised.
So **water needs a different door from `_write_cell`** — the implementation spec defines it.

**The shader already reads the `_flag` texture** (fire uses that axis) ⇒ **zero new textures.**
A third texture could put the amount straight on screen, but upload goes 7.88MB/tick → 11.8MB/tick.
**Decide after seeing water actually run.**

### 16 palette slots is not 16 screen colors

**The user asked; the answer lives here.**

Fire is the proof — there is **no "fire" slot in the palette** and fire is alive on screen.
A cell with `FLAG_BURNING` skips the palette entirely, and the shader blends two colors over time,
**scattering the phase per cell.** ⇒ **Expressiveness comes from the shader, not the palette.**

**What's countable is material kinds.** Currently 4 (empty · stone · wood · bedrock), **5** with water, 11 to spare.

The number 16 is **the safe line for GPU precision** (`l8_to_int` in `cell_grid.gdshader`).
Raising it is technically possible and touches two shader lines and one constant.
**Not raising it now** — nothing gained, only precision risk. Raise it the day slots actually run out.

---

## Falling has no acceleration — where the user said "cheap"

### Outcome — the user confirmed by eye

**"There's tons of water and it trickles down one row at a time. The simulation feels really cheap."**
Scope: **eye only.** No screenshot. Which scene wasn't recorded (presumably the F-key puddle).

**The complaint was accurate. Confirmed by value:**

```
_water_fall()      empty cell below → hand the whole thing over — exactly one cell    cell_grid.gd:480
one substep = 1 cell · WATER_SUBSTEPS 3 · tick 20Hz
⇒ 60 cells/s = 240 px/s = 7.5 tiles/s        constant. Forever.

character  GRAVITY_PX 2400 px/s²  ⇒ 2400 px/s after one second
```

**Water is 10× slower than the character and never speeds up.** Fall 100 tiles and it's still 240 px/s.

**More water doesn't help** — `_water_fall` looks **only one cell below itself.**
A 100-cell column descends one cell as a unit, so **the longer the column, the more it reads as trickling.**
**This is not a bug; the axis doesn't exist.** A cellular automaton with no velocity state can only produce constant speed.

### The fix — not carrying per-cell velocity is cheaper

**`_aux` is already full with the amount (0–255).** A new velocity byte makes the whole grid heavier.

⇒ **Scan up to K consecutive empty cells below and drop that far at once.** Airborne water is "falling" anyway,
so **one constant K sets the fall speed.** Integers only, and **vertical traversal is bottom→top so there is no cascade**
(the destination is a place already passed this step — `cell_grid.gd:511` records that property).

**K = 4 went in.**
**The final value is the user's, decided on screen** — 4 is a measurable starting point, not the answer.

#### Measured — **it is not "K times faster". It is 3.0×** (verify-read and verify-run measured independently)

| Who | Measured |
|---|---|
| verify-read | mean **8 cells/tick** · 640 px/s |
| verify-run | 892 cells in 111 ticks = **8.04 cells/tick** · 642.9 px/s · 20.1 tiles/s |

**They agree. K=4's real multiplier is 3.0, not 4.0.**

**Cause — per-tick movement alternates exactly `12, 4, 12, 4 …`.** `12 + 4 = 16 = band height`.
**A fall crossing a band boundary skips the remaining substeps of that tick** ⇒ **roughly every other tick loses half.**

**And the loss rate grows with K — 11% at K=1, 33% at K=4.**
As a 12-cell fall approaches the 16-cell band height, the chance of hitting a boundary rises.
⇒ **You cannot get the speed from "K × substeps" arithmetic. Re-measure every time you raise K.**

**This bites directly when picking K** — "4 is slow, make it 6" gains less than 1.5×.

**And "water stalling in mid-air" does not happen** — neither observation had a single 0-cell tick.
K (4) is smaller than the band height (16), so **skipping a band is impossible in principle.** Worst case is "4 instead of 12", not a stop.

**But the net sets K's ceiling — the check does, not the value.**
The way `net_water._water_falls_per_tick` **catches order reversal** is that "reversing band order gives 27 cells
in one tick" exceeds the ceiling. ⇒ **K=4 → 12 cells (margin 15) safe · K=6 → 18 marginal ·
K=8 → 24 catches essentially nothing.**
**Going to 8 or above means enlarging the net's scene first.** Skip that and you get **green measuring nothing.**

**Three prices:**
- **The "exactly one cell per tick" net contract breaks.** CLAUDE.md cites **that exact check** as its example
  of "a check that measures the process" — it must be fixed alongside, and the fix must confirm the check
  **still measures something** (invert it).
  **Raising the ceiling from `WATER_SUBSTEPS` to `K × WATER_SUBSTEPS` and stopping is not enough** —
  that is not "fixed", it is **"loosened the ceiling"**, and the two are indistinguishable.
  **Check that setting K back to 1 goes red.**
- **Empty-cell scanning costs more.** The fast path (bounce on `_mat[i] == WATER`) survives, but every falling cell looks K down
- **`water-jump-and-escape`'s approach-A measurements go stale** — "25%→5s · 95%→11s" was measured **at the old fall speed**

### Order — decided by the user

**"Do the water rising first"** (said twice). ⇒ **Get approach-A pouring on screen first, judge "does it look like
water" from that screen, then open this section.**
Approach A rains across the full width, so **the fall distance is short and the fill rate may not change much** —
what changes is **the shape of the falling stream**, which is what the escape scene shows.

---

## TBD — not its turn yet

**Do not force these full** (GDD "skeleton first").

- **Does wetness dry over time** — no lightning rune, so wetness's usefulness can't be measured yet
- **Does wet wood not burn** — the user deferred this as "a later problem"
- **Does fire dry a wet spot** — cheap. Awaiting the user
- **The exact rule for water putting out fire** — how much extinguishes · is the water consumed
- **Character wetness** — a separate axis from cell wetness. Duration and effect all TBD

### Water pushes the character — the direction is settled and it isn't built (decided by the user)

#### Outcome — the user confirmed by eye. **The most important judgment in this doc**

**"I keep feeling the water is background. The water has no effect on me whatsoever."**

**That is the diagnosis; everything else is symptom.** The trickling fall and the missing current look like
separate value problems but **come from one cause — the water does not touch the character at all.**
⇒ **Making the water "prettier" will not remove this feeling.** Only touching will.

Scope: **eye only.** No screenshot.
**So the user decided to "put in the current too and finish water this round".**

**The character currently knows nothing about water.** `src/actor/character.gd` has **zero** `WATER` references —
water is `BEHAVIOR_NONE`, so `is_solid()` is false and **to the character it is identical to empty.**
No buoyancy, no drag, no sinking.

**Asymmetric with fire** — `character.gd:302` calls `_body.standing_in_fire()` and `body.gd:155-164`
sweeps the grid, so **fire reaches the character.** Only water doesn't.

**What the user wants:**
- **Water has weight. Enough of it flowing at you pushes you** — this is the core
- ~~**Floating on water** came up too. **Buoyancy or swimming was not decided**~~ **Settled — below.**

#### The upward axis is settled — **neither buoyancy nor swimming. The jump limit is removed**

**In water, jumps are unlimited.** The water doesn't push the character up — **the character climbs on their own.**

**Nearly free.** The jump condition at `character.gd:262` is **only `on_ground`**, so adding `or in_water` does it.
**No new physics axis appears.**

**And the progression language lines up** — stage 1's locked zone ④ opens with a **double jump**, so
"jump count" becomes one grammar. Stage 2 is the water stage, so
**stage 1's final scene doubles as stage 2's movement tutorial.**

**Two things still TBD** — **gravity underwater** (unreduced, you flail) and **the threshold**
(using `WATER_WET` = 32 makes that one constant set color, fire-proofing and jumping).

**"The current pushes you" is still TBD separately.** Only the upward axis is closed.

**Details and performance measurements** in `docs/plans/2.active/water-jump-and-escape.md`.

**Why this was missing** — **nobody thought of it.** It is not "we decided against it".
The GDD, this doc, and the implementation spec had **not one line about buoyancy, drag or swimming** (confirmed by grep).
**That is what makes it different from "the character gets wet"** — wetness was deferred **because lightning is missing**,
and that was written down.

#### A design call was made (spec) — both closed as "no new axis"

**1. Current data is not stored in the grid. The character reads neighbor cells directly.**

Not close. Storing it means:
- **1 byte per cell × 4,128,768 cells = 4.1MB** (`cell_grid.gd:53-54`)
- Writes added to the hottest loop (`_water_share`)
- **"Decay the residual every tick" becomes a new axis** — without it, **force remains after the water stops**
- All 39 premises of `net_water` move

Reading is **0 bytes · no sim change · pure read**, so it cannot violate the folder contract in principle.
**State the limit honestly** — a neighbor difference measures "is left-right currently imbalanced",
**not "how fast is it flowing".**
**In a wide, even river it reads weak.** ⇒ In stage 2 (the water stage) this limit may become a real problem.
**But what ③ measures is feel, not a physical quantity.**

**2. Current is not a new axis — it is recoil's (`recoil_vx`) sibling.**

```gdscript
# character.gd:287 — already the sum of "input + external force"
_body.move_x(grid, (move * MOVE_SPEED_PX + recoil_vx) * dt)
```

**One more term, and `move_x` already handles wall blocking and stairs. Zero new files.**

**One difference from recoil — current does not decay.** Recoil is an **impulse** that dies down;
current is **a field re-read every frame.** **Adding decay counts it twice.**

**And `_try_step_up` (`body.gd:96`) may let current push the character up a stair** — not looked at yet.

#### Measured — **approach A (raining) produces almost no current** (right after implementation)

**After building it, "what is the actual neighbor difference" was measured.** K-key pour, 250 ticks,
7 locations (2 near walls) × 25 samples:

| Where | Difference (row mean) | Push (at `WATER_PUSH_PX` 130) |
|---|---|---|
| **Middle of open water** | **median 0** | **0** |
| 2 cells from a wall | median 19 | ≈10 px/s |
| Flush against a wall | 255 (water vs wall) | 130 px/s |

**The cause is the pouring method.** Approach A pours **uniformly across the full width**, so
**left and right are always level.** Current comes from imbalance, and **that imbalance never appears.**

**This doc's claim that "a rising front means large imbalance" assumed pouring from the side (dam break).**
**That method took 4:30 and was already discarded** (`water-jump-and-escape.md`, acceptance 6's first failure).
⇒ **The discarded method was current's premise, and nobody carried that forward.**

**Current itself is not dead** — F key (dumping at one point) does produce a front.
**K fails to make it; the feature is not broken.** There is a path to seeing it on screen.

#### Why "just fix it" doesn't apply — **three candidates hit the same wall** (spec)

There were four — ① reopen the pouring method · ② redefine current as **inflow** ·
③ open an axis for **falling water pressing down** · ④ accept it.

**Computed from shipping constants, ①②③ all block on one cause:**

```
per cell/tick = 20,000 / 176 = 113
water rise    = 113/255 = 0.44 cells/tick = 1.11 tiles/s
filling 13 tiles (104 cells) = 11.7s        ← matches the independent 95% measurement of 12.6s
one cell going 0 → 255 = 2.26 ticks
```

⇒ **Below the surface everything is 255, above it 0, and between them only a 2-tick band.**
**A submerged character is surrounded by 255 vs 255 in every direction** — **0 horizontally, 0 vertically, 0 inflow.**
② is a 2-tick pulse, so submerged it's 0; ③ is 0 because above and below are equally full. **It was never just a horizontal problem.**

**In one sentence: a room that fills fast and evenly is by definition near equilibrium, and equilibrium means
"no force in any direction".**
**The 12.6 seconds is itself the evidence of near-equilibrium.** The dam break had current for exactly the reason
that **it stayed far from equilibrium for 4:30.**

⇒ **"Fills fast" and "pushes" are two ends of one knob. Gain one, lose the other.**

**This paragraph is arithmetic from measurement, not measurement.** The inputs are shipping constants and the
result matches an independent measurement, so it is used as evidence — **if it's wrong, one of the four lines above is wrong.**

**⇒ spec recommends ④ (accept). Awaiting the user.**
Current is felt at **dams · waterfalls · near walls · the F-key puddle · stage 2's river** (F-key measured 45 px/s).
**The axis for "water touching me" in the boss room was always unlimited jumping** — current was not built to replace it.

**What will bite when building it:**
- **Reading is free** — one more place the character reads the grid; `is_solid` and `is_burning` are the precedent
- **Without a `mat_at() == WATER` guard, "remaining fuel in a burning cell" mixes into the current** (found by builder).
  `_aux` is shared between water amount and fire fuel — **add `aux_at` without checking the material and fire pushes the character**
- ~~**"How hard does it push" is hard.** Whether to keep or discard the value `_water_share` already computes is a design call~~
  **Closed above — discard it (the character reads directly).**
- **The strength constant (`WATER_PUSH_PX`) has no starting value pinned** — **the target is feel, so there is no anchor.**
  Same category as underwater gravity. **Decided on screen.**
- **The character must not push the water.** The character is float and host-authoritative (`src/actor/`);
  water is integer-deterministic (`src/sim/`). **Water → character is a read and safe; character → water crosses that boundary**
- **Lightning rune** — water's counterpart. `TRACE_WET` grows then (`sim_tuning` comment)
