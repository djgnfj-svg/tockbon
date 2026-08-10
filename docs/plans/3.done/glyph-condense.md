# Condense — the pillar glyph

**Status**: done — implemented and headless-verified (8,638 checks). **Screen unseen — nobody has looked at it
on a real monitor yet.** `3.done/` means implementation finished, not acceptance passed (CLAUDE.md); §9's
screen-only acceptance list (13–16) and §11.10's screen list are still open, waiting on verify-look.
**One line**: a pillar of the bolt's own element shoots **straight up** from the impact point, two characters
tall, and **leaves nothing behind** — the third verb beside spread's *scatter* and blast's *burst*.

**Design doc**: [../../design/circle-rune-glyph.md](../../design/circle-rune-glyph.md) — its glyph table lists
**condense** as #3 with "Name only", and its "Not decided yet" names *"definitions of condense · deploy — start
with which of the three (modify/spawn/finish) they belong to"*. **This doc is that row.**
**Neighbouring doc**: [../../design/glyph-accel-and-home.md](../../design/glyph-accel-and-home.md) — it claims
the **last two family seats**. Condense arrived first and §5 is the arithmetic of who ends up short.
**Preceding doc**: [./levelup-and-three-picks.md](./levelup-and-three-picks.md) — where the
dummy family came from, and the doc that says out loud that real glyphs "go in before the demo".

**Every number below is a pointer, not a copy.** Radii, speeds and budgets live in `src/sim/sim_tuning.gd`;
box sizes live in `src/actor/character.gd` and `src/actor/monster_defs.gd`. If this doc and a file disagree,
**the file is right.**

**Built.** §11 is what was actually written — `src/sim/spell_sim.gd`, `src/actor/body.gd`,
`src/actor/character.gd`, `src/actor/monster.gd`, `src/view/fx_tuning.gd`, `src/view/blast_fx.gd`,
`src/stage/stage.gd`, `src/view/circle_window.gd`, `src/view/three_pick_window.gd`, plus the nets in §11.9.

---

## 1. Why

### The three must be three different verbs

The user's whole reason for this glyph: **확산은 퍼지고, 폭발은 터지고, 응축은 솟는다.** Today the pipeline holds
two shapes and they are already far apart —

| Glyph | `kind` | Shape | Direction |
|---|---|---|---|
| 확산 spread | `SPAWN` | 8 bolts | **outward, all around** (`spell_sim.SPREAD_DX/DY`) |
| 폭발 blast | `TERMINAL` | a disc | **none — it is symmetric** |
| **응축 condense** | **`TERMINAL`** (§3) | **a column** | **up** |

**The axis condense adds is direction, and it is the only one of the three that has one.** That is worth more
than another number: `circle-rune-glyph.md`'s own risk ① is that a seventeen-long list grows without gaining
depth ("if the answer is 'both make it stronger', merge them"), and the cheapest way to fail this glyph is to
build it as "a blast, but taller".

### And the three-pick stops being a dummy machine

`levelup-and-three-picks.md` shipped a **dummy family** because a 6-id pool cannot serve 4 draws without
repeating. That doc names the exit condition itself: *"real glyphs — the user pinned 'add them later'. **They go
in before the demo.**"* With condense in, **확산 · 응축 · 폭발 are the whole pool the first three-pick draws
from**, and they are three different verbs rather than two verbs and a number.

⚠ **Not "the first three cards are one of each" — `three_pick.draw` cannot promise that.** Read from the
code: it is a partial Fisher-Yates over every unowned id in `Glyph.ALL`, with **no per-family knowledge** at
all (§4 says the same from the other side, and that property is deliberate). With 9 ids in 3 families a
first hand of 확산_C · 확산_R · 폭발_U is legal and common. **If "one of each verb on the first card screen"
is wanted, it is a change to `draw` and nobody has asked for one.**

**Retiring the dummy is not free and it is not this doc's decision.** §5.3 is what it costs.

---

## 2. Behavior

### 2.1 Geometry — two characters, and the character is one tile

Read from the files, not assumed:

```
character.H_PX          32 px          src/actor/character.gd
Tuning.CELL_PX           4 px          => 32 px = 8 cells
Tuning.TILE_CELLS        8 cells       => the character is exactly one terrain tile tall
```

⇒ **2 characters = 2 tiles = 64 px = 16 cells.** That is the height, and it is a user decision.

**Width is TBD (user).** §6 prices it. Everything below that needs a width writes it as `W`.

### 2.2 Direction and origin

**Up is `-y`.** `_advance` adds `Tuning.GRAVITY_FP` to `_vy` to make a bolt fall, so **+y is down** and the
column occupies rows `y-15 … y` above the impact cell (or `y-16 … y-1` — **whether the impact row itself is
part of the column is TBD**, and it is not a rounding detail: the impact cell is where `_carve` and
`_rune_trace` have already acted).

The origin is `_impact`'s `(x, y)` — **the empty cell just before the solid that was hit**, not the solid cell
(`_walk` pins this, and spread already leaves from the same point). So a pillar off a floor starts one cell
above the floor, which is the picture we want.

### 2.3 Element — it follows the rune, and **that is where the first hole is**

The user: **불 룬이면 불기둥, 무속성이면 무속성 기둥.**

The seat already exists — `sim_tuning.ELEM_DEFS` is *"the only table where a rune touches the world. One rune =
one row here"*, and `_rune_trace` is its only consumer:

| Rune | `trace` | What a pillar of it would be |
|---|---|---|
| `ELEM_FIRE` | `TRACE_IGNITE` | a column of ignited cells — **and ignition only catches where there is fuel**, so a fire pillar in open air lights nothing at all (`_ignite_cell`'s three lines) |
| `ELEM_NONE` | `TRACE_NONE` | **"leaves no trace" is the definition of none.** ⇒ a none pillar has, by that rule, **nothing to leave** |
| `ELEM_WATER` | `TRACE_WET` | a column of water that immediately falls back down — and §4 is why that was refused |

> **⚠ The brief says the water rune does not exist. The code says it does.** `ELEM_WATER` is in `ELEM_ALL`,
> `TRACE_WET` is implemented in `_rune_trace`, `cmd_water` and `_water_disc` are built, `assets/circle/rune_water.png`
> is on disk, and `3.done/research-bench-unlocks.md` **sells the 물 rune as one of three unlocks.**
> **This doc does not resolve that** — it is recorded here and in §8 so the answer is given once, by the user,
> instead of guessed three times. **Until it is given, condense must answer for three runes**, because
> `fire()` accepts all three today and `net_tables` iterates `ELEM_ALL`.

**The none pillar is the sharper hole.** "Follows the element" plus "none leaves no trace" plus "leaves no
material" composes to **a none pillar that does nothing at all** — which is exactly `CLAUDE.md`'s signature fake
("screen changes but sim doesn't"), arriving on the **starting rune**, in one of the **first three glyphs a
player picks**. Three ways out and **the choice is the user's** (§8):

| Path | What it means |
|---|---|
| **A — the pillar damages, and damage is the sim change** | The rune decides what the column *leaves*; the column itself always **hits**. None then has a real effect and `TRACE_NONE` stays honest. This is what §2.5 recommends |
| **B — the pillar carves** | Every impact already carves regardless of rune (`_impact` step (1) is rune-blind, deliberately). A carving column is rune-blind for the same reason and none inherits it |
| **C — none genuinely does nothing here** | Defensible only if the player is told. It makes the starting rune the worst rune for one of the first three glyphs |

### 2.4 What it leaves — **nothing** (user)

The user: *"그냥 착탄 후 기둥 푱 나오고 끊어도 돼."* Recorded as a decision in
[../../decisions/condense-leaves-no-material.md](../../decisions/condense-leaves-no-material.md).

**But "leaves nothing" cannot mean "the impact leaves nothing", and the two must not be confused:**

- `_impact` step (1) **`_carve` runs on every impact, rune-blind and glyph-blind** — a hole appears whether or
  not condense is in the list. That is the GDD's first natural law and it is not condense's to switch off
- `_impact` step (2) **`_rune_trace` runs on every impact too** — with the fire rune, `rune_r` (6 cells at
  gen 0) of ignition happens at the impact point **before the glyph pipeline is even reached**

⇒ **"응축은 물질을 남기지 않는다" is a statement about the column, not about the impact.** A fire-rune condense
will still leave a burning patch at its foot, because that patch is the *rune's*. **If the user looks at the
screen and says "it left fire", this paragraph is the answer, and the thing to change is `rune_r`, not this
glyph.**

**Which leaves the fire pillar itself with a problem**: if the column ignites (2.3), it *has* left fire.
"Ignite and let it burn out" and "leave nothing" are the same sentence only if nothing in the column has fuel.
**TBD** (§8) — and the cheapest honest reading is that a fire pillar ignites **whatever fuel it passes
through**, which is a rule about the world, not a residue the glyph left.

### 2.5 Does it damage — **unspecified by the user, and the highest-risk gap in this doc**

The user described a picture and nothing else. Three facts make this the item to answer first:

1. `levelup-and-three-picks.md`'s **acceptance 8** is *"the socketed glyph actually changes the spell — the
   biggest risk in this doc. 'Nothing happens but it showed on screen' is the signature fake"*
2. Condense will be a **three-pick card**. A card that changes no measurable value is that fake, shipped to the
   player at the exact moment the game asks them to choose
3. `power_pct` has a defined seat for `TERMINAL` already (§3) — *"the blast it makes"*. **A condense with no
   damage has nothing for its own `power_pct` column to multiply**, and rarity becomes decoration

⇒ **Recommend: it damages.** Value TBD. **But if the user's answer is "no damage, it is a shape",** then
`power_pct` must attach to something else measurable (ignition length, carve depth) or the rarity rows are a
false knob, and that has to be said out loud rather than left as three rows with different numbers.

**Damaging is not free — the notice cannot be the blast notice.** `body.hit_by_blast` reads `_fx_*` and tests
**a circle** of radius `Tuning.blast_rd(gen)`. Feed a pillar through it and the pillar hits in a **disc**, on
screen a column. Two ways, and the second is recommended:

| Way | Cost |
|---|---|
| Add a shape column to the blast notice | Every consumer (`body`, `blast_fx`, `stage`) learns about shapes. `_notify_blast`'s own comment refuses to carry values nobody uses; this makes two users of one array with different geometry |
| **A notice of its own** (`_pillar_*`) with a **rect** test in `body.gd` | One more array set, cleared in `_clear_notices()` — *"both notices are cleared in one place"* is already that function's stated contract. The rect test is cheaper than the circle one |

### 2.6 Does it cut terrain — TBD, and the two answers differ by a lot

Not specified. Blast cuts (`_disc(..., destroy=true)`). The values differ, so both are priced in §6:

| | Cells written | What the player sees |
|---|---|---|
| **Cuts** | `W × 16` cells become `EMPTY`, each through `_write_cell` (which also un-burns and wakes a chunk) | **A 2-tile shaft drilled upward.** Under a ceiling this is a tunnel-maker, and it is a *different tool* from the blast's hole |
| **Doesn't cut** | 0 for none; only `_ignite_cell` calls for fire, and those stop at fuel 0 | The column is an effect passing **through** the world. Cheaper by roughly the write cost, and it keeps blast as the only digger |

**And a linked question with no answer yet: does the column stop at solid terrain?** A pillar under an overhang
either drills through it (cuts) or paints its effect onto cells that cannot take it (doesn't). "Stop at the
first solid cell above" is a third answer and it is the one that makes the picture legible — **TBD**.

### 2.7 How long does it last — TBD, and §7 is why this one is not cosmetic

One tick, or N ticks. **The user did not say.** It changes what kind of thing the pillar *is*:

| | What it is | What it costs |
|---|---|---|
| **One tick** | A **notice**, exactly like a blast: produced in `_run_glyph`, consumed by the actor and the screen in the same tick, cleared by the next `step()` | Nothing new in the sim. The screen must carry its own lifetime (`blast_fx` already exists because a flash has to outlive the tick that made it) |
| **N ticks** | **Sim state.** A new parallel-array set with an age column, stepped every tick, **cleared in `reset()`** (the `_pend_*` trap: *"without it, the tick after rebuilding the stage with R, the previous experiment's blast punches holes in the new terrain"*) | A per-tick pass, and the damage question becomes "how often" — the character's `invuln_left` is 4 ticks, so a 4-tick pillar hits once and a 12-tick pillar hits three times |

---

## 3. `kind` — `TERMINAL`, and what that actually promises

**Read from `_run_glyph`, not from the shape of the word.** The three kinds are decided by **what the glyph
does to the bolt list**, not by what it does to the world:

| kind | Test | Condense |
|---|---|---|
| `KIND_SPAWN` | *does it create bolts and hand them the remaining list?* | **No.** A column is not a projectile. `_spread` is the only spawner and it launches through `_launch` |
| `KIND_MODIFY` | *is it consumed whole at `_launch`, before the bolt ever flies?* | **No.** Condense happens **at the impact point**, which `_launch` has no access to. `_launch`'s own comment: a MODIFY that only fired at impact could never raise the damage of the bolt carrying it — condense is the exact mirror, an impact effect that launch cannot express |
| **`KIND_TERMINAL`** | *does it end in place, creating no bolt, so the pipeline continues at the same spot?* | **Yes** — and `_run_glyph` returns `rest`, so the next glyph runs at the same cell |

**⇒ `TERMINAL`. And the brief is right that this means "the next glyph continues at the same spot" — that is
the promise, and it is the correct one.** Checked against the real combinations:

```
[응축, 폭발]   pillar goes up at the impact cell, then the blast opens its disc at the same cell
[폭발, 응축]   the disc opens first, then the pillar goes up from the same cell — through a hole
              that now exists.  Different picture, same two glyphs  ← the GDD thesis, for free
[확산, 응축]   8 children fly off, and each one raises its own pillar where it lands
[응축, 확산]   pillar first, then 8 children leave the impact point.  `_run_glyph`'s own comment
              already names `[blast, spread]` (debug key 5) as proof a TERMINAL is not the end
              of the list
```

> ⚠ **Measured during the build (§11.9): `[응축, 폭발]` and `[폭발, 응축]` leave byte-identical terrain.**
> The row above already says why — condense writes no cell in either order (§2.4/§11.1), so only the blast's
> hole exists on the grid, and that hole is the same whichever order the two run in. **What actually differs
> is the picture** (the pillar rising through open air vs. through an already-open hole) — a screen fact, not
> a grid fact, and `net_spell` cannot measure it. The net (`_condense_and_blast_both_run_in_either_order`)
> instead asserts both glyphs actually ran, once each, in both orders.

**No new `kind`, and that is deliberate.** `glyph_defs.gd`'s header: *"one glyph = one row here + one branch in
`spell_sim._run_glyph` (by `kind`, not by id) + (if the presentation differs) one row in `fx_tuning`. A fourth
place appearing means the structure is wrong."* Condense is **one row and one branch.**

**`power_pct` seat, inherited with the kind**: `TERMINAL` composes its own `power_pct` **onto the carried
power**, into a **local** (`blast_power`'s shape), and **must never write back into `power`** — a chain of
TERMINALs (`[폭발, 응축]`) has to read the same carried value each time, not compound. That rule is already
written once, in `spell_sim.gd`'s "power_pct" section; **do not restate it in the new branch, point at it.**

---

## 4. Screen

| Where | What | State |
|---|---|---|
| **Staff tip** | 3 `GLYPH_TINT` rows (one hue, all three rarities — that file's rule) | **Missing = `net_tables._glyph_tint_covers_every_glyph` goes red.** A net that actually bites |
| **Palette · round-circle ring** | `ICON_TEX` · `RING_TEX` rows | **No art.** `assets/circle/` has spread · blast · dummy · accel · home and **no condense.** A missing texture falls back to the procedural symbol, so **code can land before art** |
| **Socket band (triangle)** | `SOCKET_GLYPH_TEX` row | Same — falls back |
| **Palette grid** | **9 cells become 12** (or stay 9 if the dummy retires — §5.3) | `palette_layout.items_of` reads `Glyph.ALL` with no count of its own. **Look at the layout, don't assume it** |
| **Three-pick cards** | Condense can be rolled | **No change.** `three_pick.draw` walks `Glyph.ALL` with no per-family knowledge — the design working |
| **The pillar itself** | **New.** `blast_fx` draws a **circle** flash sized from `FX_SIZES.flash_px` | A column is not a circle. This is a **new fx path**, not a free one, and it is the one screen item with no precedent to copy |

**The symbol has to read as "up".** `circle-art.md` already records that `ring_accel` and `ring_spread`
collide because both are "strokes reaching outward" — condense is a third member of that family of pictures
and **must be checked side by side on the real circle**, not alone.

**In-game name: 응축.** Every name in `glyph_defs.DEFS` is Korean (`확산` · `폭발` · `더미`).

---

## 5. Interaction with what exists

### 5.1 The nibble ceiling — count it, don't assume it

`Tuning.GLYPH_BITS` is 4 ⇒ ids `1..15` (0 is reserved as end-of-list) ⇒ **15 ids = 5 families × 3 rarities.**
`glyph_defs.gd` wrote its own ceiling down: *"nine are used below, six spare … the day a 6th family arrives,
`GLYPH_BITS` goes 4 → 6 and `GLYPH_MAX_LAYERS` goes 7 → 5."*

| State | ids used | spare | families used (of 5) |
|---|---|---|---|
| **Today** | 9 | **6** | 3 — spread · blast · dummy |
| **+ condense, dummy kept** | **12** | **3** | **4** — condense is the **fourth** |
| **+ condense, dummy deleted** | 9 | 6 | 3 |

**Three rarities is not optional.** `net_tables._glyph_pool_is_complete` walks `FAMILY_ALL × RARITY_ALL` and
requires each pair to resolve. A condense family with one row goes red.

### 5.2 ⚠ It collides with `glyph-accel-and-home.md` — **but only if the dummy stays**

That doc's headline is *"the fourth and fifth families, which fills the nibble exactly"* and it spends a whole
section on being **the last doc that can be written without paying for a `GLYPH_BITS` widening.** Condense
arrives into the same six spare ids. The arithmetic:

| | ids | families |
|---|---|---|
| condense + accel + home, **dummy kept** | 9 + 3 + 3 + 3 = **18** ✗ (ceiling 15) | **6** ✗ (ceiling 5) |
| condense + accel + home, **dummy deleted** | 6 + 3 + 3 + 3 = **15** ✓ exactly | **5** ✓ exactly |

⇒ **Condense does not spend accel's or home's seat. The dummy does.** The dummy was always a placeholder
(`glyph_defs.gd`: *"a dummy is called a dummy. It gets a name the day the real glyph is decided"*), so this is
the bill for it arriving, not a new cost condense created.

**`glyph-accel-and-home.md` must be edited in the same change** — its "these two make five, five is the
ceiling" is true only under the deletion. `CLAUDE.md`: *"a refutation that lands in a different doc than the
claim does not propagate."* **Recording this here and not there is the exact failure that rule names.**

### 5.3 Retiring the dummy — what dies with it, and why that is a fork not a chore

The brief asks whether "replace the dummies" is a decision. **It is not** — the dummy's own doc scheduled its
own removal. **But *how* it retires is a fork nobody has taken yet, and it is bigger than it looks:**

**The dummy family is the only `KIND_MODIFY` glyph in the game.** Delete the rows and:

- `_launch`'s MODIFY-stripping loop, `POWER_MAX`'s clamp, `_pend_pow` — all still there, **and no id exercises
  any of them**
- `net_spell`'s `[dummy, spread]` vs `[spread, dummy]` check — *"the check that proves MODIFY is applied at
  launch and not at impact"* — **loses its subject entirely**, along with the `POWER_MAX` clamp drive and the
  `[DUMMY_U, DUMMY_R]` composition check
- `net_tables`'s `LAUNCH_KINDS` partition survives (it walks the rows that exist) but measures nothing
- ⇒ **the MODIFY path becomes untested code until accel or home lands.** Deleting a family deletes its nets,
  and this repo's rule is that a green count falling is how a check *disappears* rather than goes red

| Option | What it costs |
|---|---|
| **Delete the dummy rows** | Frees 3 ids and a family seat (§5.2). **Kills the only MODIFY coverage** |
| **Keep the rows, drop them from the draw pool** | Coverage survives. Needs a new "not offered" column or a filter in `three_pick.draw` — **and `three_pick.draw`'s design is that it has no per-family knowledge**, which is the property §4 says is working. Costs a family seat |
| **Keep them until accel/home lands, then delete** | Cheapest today, and it means condense ships as the **fourth** family with 3 ids spare |

**TBD — the user's.** Nothing about condense depends on the answer; it changes only which day the nibble bill
arrives.

### 5.4 Everything else that reads `Glyph.ALL`

**None of these need logic changes — they need their numbers re-read.** They are listed so a build doesn't
discover them one at a time:

- `three_pick.draw` — no change. Its comment's *"9 ids today … at least 7 always remain"* becomes 12/10
- `net_three_pick` — the same 9 appears in two comments and in the reachability assertion
- `net_pick` — *"every one of the 9 ids, actually drawn"*
- `spell_circle._list_ok` / `_count_family` and `spell_sim._valid_glyphs` — read `max_per_circle` from the
  table. **A new family with a cap is free to them**, which is the point of the table
- `glyph_defs.count_family`'s guard comment uses **"packed `[SPREAD_C, 15]`, an id outside `DEFS`"** as its
  worked example. At 12 ids, 15 is still outside; at 15 ids it stops demonstrating anything. Not yet, but the
  same trap `glyph-accel-and-home.md` already flagged

---

## 6. Cost

**A model built from reading, not a measurement. Say so until someone drives it.**

### 6.1 The baseline, quoted from where it was measured

`sim_tuning.MAX_BLASTS_PER_TICK`'s comment: *"v1 measured four large blasts applied simultaneously at
**8,940 µs = 54% of budget**"*, and *"re-measured on this machine at **1,291 µs** with `rd` 12"* — a 6.9×
gap that **was never separated into machine vs code. Read it as a ratio only.**

### 6.2 Cells, counted

One **gen 0** blast, counted exactly (`_disc` tests a bounding box and rejects outside the disc):

| Pass | Radius | Cells inside | Cells tested (bbox) |
|---|---|---|---|
| destroy | `rd` 8 | **197** | 289 |
| ignite | `ignite_r` 12 | **441** | 625 |
| **one blast** | | **638** | **914** |

A pillar is a rectangle, so **every cell it covers is a cell it touches** — no rejection term:

| Width `W` | Cells (`W × 16`) | Vs one gen-0 blast (638) |
|---|---|---|
| 2 cells (8 px) | 32 | 5% |
| 4 cells (16 px) | 64 | 10% |
| **8 cells = 1 tile (32 px)** | **128** | **20%** |
| 16 cells = 2 tiles | 256 | 40% |

**The value is TBD (user).** The arithmetic is here so the answer can be priced the day it is given.

**Cutting terrain roughly doubles the per-cell price**, and not because of the disc test: a written cell goes
through `_write_cell`, which un-burns, zeroes flags, counts a change **and wakes a chunk** (`_touch`). An
ignite-only pass calls `_ignite_cell`, which returns early on fuel 0 — **in open air a fire pillar is close to
free.**

### 6.3 `tick_budget` — ~~**yes, it needs one**~~ **overturned by §11.2: no budget**

> ⚠ **This whole subsection prices a pillar that writes cells. §11.2 decided the pillar writes none** — it
> does not cut and does not ignite, so the grid sees **zero `_write_cell` calls** and the only per-pillar cost
> is a **one-column upward scan of at most `pillar_h(gen)` `mat_at` reads** (16 at gen 0, **8 at gen 1, which
> is where `[확산, 응축]` actually puts it**). Eight pillars on one tick is **64 reads and zero writes**,
> against four blasts' **2,552 cells written**. ⇒ **`tick_budget: 0`.** The `1,024 cells` figure below assumed
> `W × 16` written cells and **no longer describes anything that happens.**
> The paragraph beneath it is kept because the *machinery* argument (`_defer` pushes the whole remaining list)
> is still the right answer **the day condense is given a cutting or igniting variant.**

Blast carries `MAX_BLASTS_PER_TICK` for a reason `spell_sim` states plainly: *"8 spread bolts landing on one
tick actually reaches it."* **Condense sits in exactly that seat** — `[확산, 응축]` puts 8 pillars on one tick.

```
8 pillars × 128 cells (W=8)  =  1,024 cells   vs   4 blasts × 638  =  2,552 cells
```

Same order of magnitude, from the same trigger, on the same tick. ⇒ **give it a budget.** The machinery is
free: `_resume` reads `_budget_cap[id]` and `_defer` pushes **the whole remaining list**, so overflow becomes
"one pillar goes up a tick later" rather than "sometimes it doesn't happen" — the distinction that comment
calls the difference between a safety net and a malfunction.

**The value is TBD.** A defensible way to pick it: choose it so `budget × W × 16` lands near the blast
budget's cell count (`4 × 638 ≈ 2,552`), then **measure**. At `W`=8 that is ~20.

**`max_per_circle` — TBD (user), recommend 1.** Spread's cap of 1 is the GDD's explosion defence and **that
argument does not transfer**: condense creates no bolts, so `[응축, 응축]` cannot explode. It does something
worse in a different way — **two pillars at the same cell are one pillar**, so the second layer is a pick that
does nothing, which is the false-knob shape this repo keeps deleting. `0` (unlimited) is defensible only if
stacking is given a meaning (taller? wider?), and **that is a design answer, not a number.**

### 6.4 Generation

Everything else in the sim shrinks with `_gen` — that is `SIM_SIZES`'s whole purpose, and `[확산, 응축]` puts
condense at **generation 1** every time. Two ways, and the trap is in the second:

- **Flat constants in `sim_tuning`** — a gen-1 pillar is the same size as a gen-0 one. Simple, and it breaks
  "small things are weak" for exactly one glyph
- **New `SIM_SIZES` columns** — correct, **and `net_tables._strictly_decreasing` measures only column names
  written by hand.** That file records the proof: a non-decreasing column was added, the full nets ran,
  **1,038 passed, exit 0, nothing mentioned it.** ⇒ **adding a column means adding its name to the net, in the
  same edit.**

**TBD**, and the second is recommended with that edit attached.

---

## 7. The 60Hz / 20Hz trap — which face bites depends on §2.7

`CLAUDE.md` lists five instances of this and **the fifth is the expensive one**: *"a hit test that runs on the
tick must sweep the tick, not the frame"* — `monster_bolts.consume_hits` tested a bolt as a point on the tick
while it moved on the frame, and the symptom was not a missed hit but **a tuning constant that could not be
changed.** Condense meets it from the **opposite side**, and that is worth stating precisely:

**Here the pillar is static and the player moves.** `character.on_tick` is the only entrance for the hit test
(*"it runs only on ticks. Call it at 60Hz and one hit becomes three"*), so the sampling rate is 20 Hz while
`MOVE_SPEED_PX` moves the player at 60 Hz:

```
240 px/s ÷ 60 fps = 4 px/frame  ÷  a tick is 3 frames  =  12 px per tick
```

⇒ **A pillar narrower than 12 px can be walked through with no sample inside it.** In cells:

| `W` | px | Sampled while crossing? |
|---|---|---|
| 2 cells | 8 px | **No — passes through, 0 or 1 samples.** The pillar that "sometimes doesn't hit" |
| 4 cells | 16 px | 1–2 samples. Thin margin |
| **8 cells** | 32 px | 2–3 samples. Safe |

**⇒ the width TBD is not only a cost question. Below 4 cells it is a correctness question**, and the symptom
would be read as "condense is unreliable" rather than as a sampling rate — which is precisely how two sessions
misread the bolt case.

**If the pillar lives one tick**, this is the whole of it: one tick, one sample, and the width decides whether
that sample can miss.
**If it lives N ticks**, tunneling stops mattering (there is a sample every tick) and a different number takes
over: `character.invuln_left` is **4 ticks**, so a pillar shorter than 5 ticks hits at most once and one longer
hits `floor(N/4)` times. **Neither is wrong; they are different glyphs**, and the value is the user's.

**And for whoever writes the checks**: observing anything tick-driven means pumping `TICK_DIVIDER * 2` frames,
never one — *"one physics frame crosses a tick boundary at most one time in three."*

---

## 8. Bounds

- **It creates no bolt and no element.** `circle-rune-glyph.md`'s table: a glyph may add an effect at the
  impact point; it may not change the element (the rune's job) or the firing arrangement (the circle's)
- **It adds no `kind`** (§3) and no layer
- **It leaves no material** — decided, and scoped in §2.4 to the column, not the impact
- **It does not change spread, blast, or the dummy.** The only shared file it edits is `glyph_defs.DEFS`
- **It is not deferred-safe for free if it becomes multi-tick state** — `reset()` must clear it
- **확산 and 응축 may sit in one circle together** (user), and nothing blocks that: the round circle is 2 layers
  (`spell_circle.DEFAULT_CIRCLE`), spread's `max_per_circle: 1` counts **its own family**, and condense's cap
  (TBD) counts its own
- **Multiplayer**: nothing new. A pillar is a deterministic consequence of the fire command, exactly like a
  blast — integer geometry, no root, no float. **Do not introduce a radius test**; a rectangle needs none

---

## 9. Acceptance

**Headless (nets · verify-run) — measurable by value**

1. **A pillar exists where the bolt landed, and its height is 16 cells.** Pin **literal** coordinates — *"a
   check whose bounds come from the thing it checks proves nothing"*
2. **It goes up, not down and not sideways.** Assert the occupied rows are `< y`. Inverting the sign must go red
3. **It leaves no material** (§2.4's scoped meaning): compare the grid after `[응축]` against the grid after a
   bare impact with the same rune, and assert the **difference is exactly what §2.6 decides**, not "they
   differ". *A/B catches "diverged", never "vanished"*
4. **`[응축, 폭발]` and `[폭발, 응축]` produce different worlds** — and **assert both actually ran both glyphs**,
   not merely that the two grids differ
5. **`[확산, 응축]` raises 8 pillars, one per child** — count them. Zero-iteration loops have passed here before
6. **The tick budget defers rather than discards**: force more pillars than the budget on one tick, assert
   `pending_count()` rises and that every one of them happens on a later tick. **Inversion: drop the budget
   column and the deferral must vanish**
7. **`power_pct` composes and does not compound**: `[응축_R, 응축_R]` gives 120 and 120, not 144 — the exact
   shape `_blast_power_does_not_leak_between_layers` already pins for blast
8. **Damage by value, absolute** (if §2.5 answers "yes"): how many hits kill a pig at common vs at unique.
   **Both sides absolute**, not a ratio
9. **A player standing in the pillar is hit; a player `W`+1 cells to the side is not.** This is the check that
   would have caught reusing the circular blast test for a rectangular pillar
10. **Every rune in `ELEM_ALL` fires condense without a bark** — the wrapper's stderr check catches "a rune in
    the table with no implementation" for free, which is how §2.3's none hole surfaces if it is left open
11. **Table checks follow for free and go red on their own**: `_defs_and_all_agree` · `_glyph_nibble_ceiling` ·
    `_glyph_pool_is_complete` · `_power_pct_increases_by_rarity` · `_glyph_tint_covers_every_glyph`
12. **The three-pick can roll condense** and never offers a duplicate rarity of an owned id

**Screen only (verify-look · the user) — cannot be measured**

13. **Does it read as "솟는다"?** The one thing this glyph exists for. If the user's word for it is "another
    explosion", the shape is wrong and no number will say so
14. **Do 확산 · 응축 · 폭발 separate as three cards**, side by side on the real circle at a 48 px band — not
    judged alone (`circle-art.md`'s own measured lesson)
15. **Is the fire pillar distinguishable from the rune trace burning at its foot?** §2.4 predicts they overlap
16. **Is a none pillar visible at all** — the rune with nothing to leave

---

## 10. TBD

**Skeleton first. These are supposed to be open** — but the first three block a build, and the rest do not.

**Blocking — a builder cannot start without these**

- **Width `W`.** §6.2 prices it; §7 says **below 4 cells it stops being a taste question**
- **Does it damage** (§2.5). If yes, how much, and does `power_pct` scale it
- **Duration** — one tick or N (§2.7). It decides whether the pillar is a notice or sim state

**Shape**

- **Does it cut terrain** (§2.6), and **does it stop at the first solid cell above**
- **Is the impact row part of the column**, or does it start one cell up (§2.2)
- **Does the fire pillar ignite what it passes through**, and is that compatible with "leaves nothing" (§2.4)
- **What a none pillar does** — path A / B / C in §2.3. **The starting rune, in a starting glyph**
- **Does size follow `_gen`** — flat constants or new `SIM_SIZES` columns (**with the net's name list edited in
  the same change**)
- **The height scan walks one column; the hit rectangle is `pillar_w` columns wide.** Under a ceiling with a
  narrow gap — open dead center, solid on both sides at the same height — the scan (impact column only) can
  climb the full height while the hit box (spanning outward) reaches into rock that visibly has no hole in
  it. **Not a spec violation** (§11.1 never promised the rectangle tracks terrain column by column) — a
  screen-visible value for the user to judge once they see it, not something to fix pre-emptively

**Not a bug — a value for the user, once seen.** A pillar under a low ceiling only shortens once the ceiling
sits **3 or more cells** above the impact row. At 1–2 cells, the impact's own `_carve` (radius `carve_r`, 2 at
generation 0) has already cleared that ceiling cell before the height scan ever runs (`_impact`'s order:
carve, then rune trace, then the glyph), so the column reads open and the pillar climbs the full 16. This is
`carve_r` and the pillar's order interacting, not a defect in either.

**Table**

- **`max_per_circle`** — recommend **1**; the reason is the false-knob shape, not the explosion (§6.3)
- **`tick_budget`** — recommend giving it one; the value is TBD (§6.3)
- **`power_pct` per rarity** — the existing families use 100 · 120 · 150

**Reaching past this doc**

- **Does the water rune exist.** The brief says no; the code, the assets and the research bench all say yes
  (§2.3). **One answer, from the user, recorded in `sim_tuning.ELEM_ALL`'s comment or in this doc**
- **How the dummy retires** — delete, bench, or wait (§5.3). It decides whether the MODIFY path keeps coverage
- **`glyph-accel-and-home.md` must be edited** the day this lands (§5.2). Not this doc's change, but this doc
  is what makes its arithmetic false
- **Art** — `ring_condense` · `icon_condense` · `socket_glyph_condense`. **Code may land first** (fallback)
- **Korean name**: **응축** (matches `circle-rune-glyph.md`'s glyph #3)

### What this doc cannot be implemented from — checked by re-reading it

**Beyond the three blockers above, four gaps a builder would hit and have to guess at:**

1. **Which file the pillar's geometry lives in.** `cell_grid` has `cmd_carve` / `cmd_ignite` (discs) and
   `cmd_fill` / `cmd_fill_water` (rects) — **there is no rect-shaped ignite command.** A fire pillar that
   ignites needs a new one, and `cmd_ignite`'s own comment argues each door gets its own name rather than
   being expressed as a degenerate case of another. **Whether condense adds one command or two is undecided**
2. **Where the pillar's constants live.** `sim_tuning` if the sim reads them, `fx_tuning` if only the screen
   does — and the height (16 cells) is a **sim** value the moment it decides what gets hit
3. **What the screen actually draws.** §4 says "a new fx path" and stops. `blast_fx`'s lifetime, fade and
   shake have no column shaped counterpart, and **nobody has said whether the pillar animates upward or
   appears whole**
4. **Whether a pillar wakes chunks it does not write to.** `_write_cell` is *"the only place that wakes a
   chunk"*, and `_ignite_cell` is not it — an ignite-only pillar wakes nothing, which is correct and worth
   knowing before someone adds a `_touch` "to be safe" and pays for it every tick

---

# 11. Implementation plan

**Written by spec after reading the code. Where this section and §1–§10 disagree, this section is the one
that was checked against the files** — §6.3 already carries its own correction box for that reason.

## 11.1 The decisions §10 left open, taken here

Everything below is **the implementer's default**, chosen for the shortest path to something on screen.
Each is a number to move while looking at the game, not a structure to redesign.

| §10 item | Taken | Why in one line |
|---|---|---|
| **Duration** | **One tick — a notice, exactly like a blast** | The user said *"기둥 푱 나오고 끊어도 돼"*. Nothing new in the sim, nothing to clear in `reset()`, and the screen already owns "outlive the tick that made it" (`blast_fx`) |
| **Width `W`** | **`pillar_w(0) = 8` cells (32 px)** | §7's own table: 8 cells is 2–3 samples while a player crosses it. **4 is the floor and 2 is broken**, so this is not a taste value on the low side |
| **Does it damage** | **Yes**, `power_pct` 100 · 120 · 150 | §2.5 · the doc's acceptance-8 argument. It is also **the only sim effect the pillar has** once it neither cuts nor ignites — remove it and condense is the signature fake |
| **Does it cut terrain** | **No** | Blast stays the only digger, and it is what makes `[폭발, 응축]` and `[응축, 폭발]` read as two different tools rather than two holes |
| **Does it ignite** | **No** | With no writes, "물질을 남기지 않는다" is literally true, and **`cell_grid` needs no new command at all** (§10's gap 1 closes without being paid). The burning patch at the pillar's foot is `_rune_trace`'s, exactly as §2.4 predicted |
| **What a none pillar does** | **Path A** — it damages | §2.3's own recommendation. Fire and none differ in **colour on screen and in the trace at the foot**, never in the pillar's own effect |
| **Water rune** | **Nothing special.** It fires, it damages, it draws in water's palette | Rune-blindness makes §2.3's ⚠ box **cost nothing to leave unanswered**. Do not spend a user question on it |
| **Stops at solid** | **Yes** | Scan **one column** (the impact column) upward from the impact row; stop at the first `BEHAVIOR_STATIC` cell. The height that scan returns is what the sim hits **and** what the screen draws |
| **Impact row included** | **Yes** — rows `y-(h-1) … y` | The impact cell is the empty cell above the floor, so including it puts the pillar's foot on the ground |
| **Does size follow `_gen`** | **Yes — two new `SIM_SIZES` columns** | `[확산, 응축]` puts condense at gen 1 **every time**. Flat constants break "small things are weak" for exactly one glyph |
| **`max_per_circle`** | **1** | §6.3's false-knob argument — two pillars at one cell are one pillar |
| **`tick_budget`** | **0** | See §6.3's correction box. **Zero writes.** |

**Deferred out of this build (see §11.7): retiring the dummy.** Condense does **not** need it (§5.3 says so
itself) and it is 66 references across 10 files. **`main` is asking the user whether it rides along.**

## 11.2 Cost, counted

| | Per pillar | Eight pillars (`[확산, 응축]`, all gen 1) |
|---|---|---|
| `mat_at` reads | ≤ `pillar_h(gen)` — **16** at gen 0, **8** at gen 1 | **64** |
| `_write_cell` calls | **0** | **0** |
| chunks woken | **0** (`_write_cell` is the only waker — §10's gap 4, and the answer is "do not add `_touch`") | **0** |
| notice entries | 1 | 8 |
| hit tests | 1 rect-vs-box **per body** | 8 per body |

One gen-0 blast writes **638 cells** (§6.2). ⇒ eight pillars are **~0** against the existing budget.

## 11.3 The table columns

`src/sim/sim_tuning.gd` — `SIM_SIZES` gains two columns:

```
gen 0   "pillar_w": 8,  "pillar_h": 16      <- 1 tile wide, 2 characters tall (the user's number)
gen 1   "pillar_w": 4,  "pillar_h": 8
```

plus `pillar_w(gen)` / `pillar_h(gen)` accessors beside `blast_rd`.

⚠ **`net_tables._gen_tables` must gain `"pillar_w"` and `"pillar_h"` in its `_strictly_decreasing(...)` name
list in the same edit.** That file records the measurement: a non-decreasing column was added, the full nets
ran, **1,038 passed, exit 0, nothing mentioned it.** Skip this and the columns are unmeasured while green.

## 11.4 Nibble arithmetic — counted, not assumed

`Tuning.GLYPH_BITS` is 4 ⇒ ids `1..15` ⇒ **15 ids, 5 families.**

| | ids used | spare | families used (of 5) |
|---|---|---|---|
| Today | 9 | 6 | 3 |
| **After this build** (dummy kept) | **12** | **3** | **4** |
| If the dummy retires later | 9 | 6 | 3 |

**It fits. `GLYPH_BITS` does not move, `GLYPH_MAX_LAYERS` stays 7.**
`glyph_defs.gd`'s "nine are used below, six spare" comment is now false and must be rewritten in the same edit.
So must `glyph-accel-and-home.md`'s "these two fill the nibble exactly" — see §5.2, and §11.8 lists it.

## 11.5 The structural finding this plan exists to report

**The procedural glyph symbol and the pick card's effect text are both dispatched by `kind`, not by family.**
Checked in the code, three sites:

- `src/view/circle_window.gd:672` — `if kind == Glyph.KIND_TERMINAL: draw_circle(...)`
- `src/view/three_pick_window.gd:469` — the same disc, redrawn (that file's line 449 says so deliberately)
- `src/view/three_pick_window.gd:591` — `if kind == Glyph.KIND_TERMINAL: return "그 자리에서 터진다 …"`

Condense is `KIND_TERMINAL` (§3, and that is correct). Condense has **no art** — `assets/circle/` holds
spread · blast · dummy · accel · home and no condense, confirmed by listing the folder. ⇒ **with no change,
응축's card draws blast's exact filled disc and says blast's exact sentence.** §4 called the missing art a
graceful fallback; for a *second* TERMINAL family the fallback is **a collision**, and it lands on
**acceptance 14** and on the user's one requirement — *셋이 확실히 갈려야 한다*.

**The fix, and it stays inside the three-file line:**

1. `fx_tuning.gd` — a `GLYPH_SYMBOL: Dictionary` keyed by **family** → a symbol constant
   (`SYM_SPAWN_RAYS` · `SYM_TERMINAL_DISC` · `SYM_MODIFY_DIAMOND` · **`SYM_PILLAR_UP`**), plus the pillar
   symbol's own ratios. A family missing from the map **barks**; it must not fall through to a shape that
   belongs to someone else — that is the whole defect being fixed
2. `circle_window._draw_glyph` and `three_pick_window._draw_pick_glyph_shape` switch on that symbol instead
   of on `kind`
3. `three_pick_window._effect_text` splits its `KIND_TERMINAL` branch by family:
   `FAMILY_BLAST` keeps *"그 자리에서 터진다 (위력 %d%%)"*, `FAMILY_CONDENSE` gets
   *"그 자리에서 기둥이 솟는다 (위력 %d%%)"*

`SYM_PILLAR_UP` draws **a narrow tall bar with a point at the top** — it must read as *up*, and it must not
read as `SYM_SPAWN_RAYS` (`circle-art.md` already measured `ring_accel` and `ring_spread` colliding as
"strokes reaching outward"; a single upward stroke is the third member of that family of pictures).

**`_run_glyph` gets the same treatment and the comment above it must move with the code.**
`glyph_defs.gd`'s header says *"one branch in `spell_sim._run_glyph` (by `kind`, not by id)"*. Two TERMINAL
families means **one nested branch on `family` inside the TERMINAL branch** — still not "by id" (all three
rarities share it). **Rewrite that header sentence in the same edit**, or the file states a rule the code
below it no longer follows.

## 11.6 Files to touch, and why — in build order

Each step leaves the game runnable. **Do not reorder 1 → 2 → 3**; each one is the next one's prerequisite.

**Step 1 — the table** *(nothing observable yet; everything downstream indexes off it)*

| File | Change |
|---|---|
| `src/sim/glyph_defs.gd` | `FAMILY_CONDENSE := 3` and into `FAMILY_ALL`; `CONDENSE_C/R/U := 10/11/12`; three `DEFS` rows (`name: &"응축"`, `kind: KIND_TERMINAL`, `max_per_circle: 1`, `tick_budget: 0`, `power_pct: 100/120/150`) and into `ALL`. **Rewrite the "nine are used, six spare" comment and the "one branch by `kind`, not by id" sentence** (§11.4, §11.5) |
| `src/sim/sim_tuning.gd` | `pillar_w` · `pillar_h` columns + accessors (§11.3) |

At the end of step 1, `net_tables._glyph_pool_is_complete` · `_glyph_nibble_ceiling` ·
`_power_pct_increases_by_rarity` pass on their own, and **`_glyph_tint_covers_every_glyph` goes red** — that
is the net biting, and step 3 is what answers it.

**Step 2 — the sim** *(the pillar exists and hurts; nothing is drawn)*

| File | Change |
|---|---|
| `src/sim/spell_sim.gd` | A `_pillar_*` notice set (`x` · `y` · `w` · `h` · `e` · `pow`) beside `_fx_*`, **cleared in `_clear_notices()`** — that function's own comment ("both notices are cleared in one place") is now three; say so. `_run_glyph`'s TERMINAL branch splits by family: blast keeps `cmd_blast` + `_notify_blast`, condense computes the height and calls `_notify_pillar`. `blast_power`'s **local-only** rule applies unchanged — **point at the header's power_pct section, do not restate it.** Queries `pillar_count()` / `get_pillar_*()` |
| `src/actor/body.gd` | `hit_by_pillar(spell) -> int` + `_rect_hits_box`. **Same "max, not first" contract** as the two above it |
| `src/actor/character.gd:575`, `src/actor/monster.gd:467` | `maxi(...)` gains the third term. **Both**, or monsters silently ignore the pillar |

**Height, written once**: from the impact row `y`, walk `y-1, y-2, …` while `_behavior[grid.mat_at(x, k)]`
is **not** `BEHAVIOR_STATIC`, stopping after `pillar_h(gen)-1` steps or at the grid edge. `h` is how many
rows were taken (≥ 1 — the impact row is always in). **`h` goes into the notice**, so the screen cannot draw
a height the sim did not hit. Integers only: no `Vector2`, no float, no `sqrt` — a rectangle needs none (§8).

**Step 3 — the screen** *(now it is visible)*

| File | Change |
|---|---|
| `src/view/fx_tuning.gd` | Three `GLYPH_TINT` rows (one hue, all three rarities — that file's rule; pick a hue **far from spread's cyan and blast's orange**). `GLYPH_SYMBOL` + `SYM_*` (§11.5). Pillar presentation constants: `PILLAR_SEC` · `PILLAR_RISE_SEC` · core/glow ratios |
| `src/view/blast_fx.gd` | `on_pillars(...)` and a `_pillars` list beside `_flashes` — **same node, same lifetime machinery, no `.tscn` edit.** Rewrite the header: it carries two notices now. `_draw()` calls a **`_paint_pillar(rect, colour)` hook** the net overrides — `draw_rect` is native and Godot refuses to override it (a parse error), so counting `_draw()` calls would measure the engine, not the picture |
| `src/stage/stage.gd:923` | Hand the pillar notice over **in the same place** as the blast one. A notice is valid only inside its tick |
| `src/view/circle_window.gd`, `src/view/three_pick_window.gd` | The `kind` → symbol switch and the effect text (§11.5) |

**It rises, it does not pop.** The drawn height eases 0 → `h` over `PILLAR_RISE_SEC`, then the whole thing
fades over the rest of `PILLAR_SEC` — `blast_fx._ease` and `_norm` already exist and are the right curve
("spreads fast, stops slow"). *푱* is that first stretch; without it the pillar appears whole and the one
verb this glyph exists for is gone. **`GATE_ARCH_FADE_FRAMES` is the warning here** — a constant with a floor
on one end and none on the other let 2 through 11 collapse a fade into a pop, all green.

No art is added. `RING_TEX` · `ICON_TEX` · `SOCKET_GLYPH_TEX` get **no condense rows** — all three fall
through to the procedural symbol by design, and after §11.5 that symbol is condense's own.

## 11.7 Out of scope — do not expand into these

- **Retiring the dummy.** 66 `DUMMY` references across 10 files (counted, not estimated: `glyph_defs` 12 ·
  `stage` 1 · `circle_window` 2 · `fx_tuning` 9 · `net_circle` 2 · `net_damage` 4 · `net_monster` 3 ·
  `net_pick` 13 · `net_render` 3 · `net_spell` 17). It **frees no seat condense needs** (§11.4) and it
  **kills the only `KIND_MODIFY` coverage in the repo** — `net_spell`'s `[dummy, spread]` vs `[spread, dummy]`
  ordering check, the `POWER_MAX` clamp drive, and the `[DUMMY_U, DUMMY_R]` composition check all lose their
  subject. **`main` is asking the user; if the answer is "now", it is its own build.**
  **When it does happen**: `KIND_MODIFY` stops being the answer to *"is this a dummy"* because **nothing is
  MODIFY any more** — the question disappears with the family. After §11.5 that is automatic: the screen
  dispatches on **family**, the `SYM_MODIFY_DIAMOND` row leaves with the family, and no branch is left
  reading `kind == KIND_MODIFY` on a screen. **Before §11.5 it would have been a silent hole**, which is a
  second reason §11.5 comes first.
- **Art** (`ring_condense` · `icon_condense` · `socket_glyph_condense`). Fallback covers it
- **Answering whether the water rune exists.** Condense is rune-blind; it costs nothing to leave open
- **Widening `GLYPH_BITS`.** Not needed and not this doc's (§5.2)
- **Any per-family knowledge in `three_pick.draw`.** That property is working (§4)
- **A shape column on the blast notice.** §2.5 already refused it; condense has its own notice

## 11.8 Risk — what this can silently break

- **The `kind` collision above, left unfixed.** Green nets, and two of the three cards are the same picture
  and the same sentence. **This is the one to check first**
- **`src/sim/` is integer determinism.** `net_determinism`'s folder text scan bars `float` · `Vector2` ·
  `sqrt` · `sin` · `randi` · `OS.` · `Time.` from `spell_sim.gd` and `sim_tuning.gd`. The rectangle needs
  none of them. **`body.gd` is `src/actor/` and float is fine there**, which is where `_rect_hits_box` goes
- **20 Hz vs 60 Hz.** The pillar is sampled **once, on the tick it exists**, while the player moves at 60 Hz
  — 12 px per tick at `MOVE_SPEED_PX` 240. At `pillar_w` 8 (32 px) that is 2–3 samples. **Drop the width to
  2 cells and the symptom is not "the pillar is thin", it is "condense sometimes does not hit"**, and two
  sessions have already misread that exact shape as a speed problem (`monster_bolts.consume_hits`)
- **`reset()`.** With a one-tick notice there is nothing to clear there — `_clear_notices()` covers it.
  **The day duration becomes N ticks, `reset()` becomes mandatory** (the `_pend_*` trap)
- **Only one of `character.gd` / `monster.gd` updated.** Nothing barks; monsters just never take pillar damage
- **Adding `_touch` "to be safe".** The pillar writes nothing, so it wakes nothing, and that is correct.
  A `_touch` per cell would be paid every tick for no effect (§10's gap 4)
- **Docs that go false the moment this lands** — fix them in the same change, because
  *"a refutation that lands in a different doc than the claim does not propagate"*:
  `docs/design/README.md`'s glyph row (2/17 → 3/17, and its "the dummy family retires" clause is now
  **later**, not now) · `docs/design/circle-rune-glyph.md`'s glyph table row 3 (*Specced, not built*) ·
  `docs/design/glyph-accel-and-home.md`'s "these two fill the nibble exactly" (§5.2) ·
  `glyph_defs.gd`'s two comments (§11.4, §11.5) · `three_pick.gd`'s "9 ids today … at least 7 always remain"
  (**12 and 10**) · `circle_window.gd:66` and `:556`, `fx_tuning.gd:696`/`:809`/`:825`,
  `three_pick_window.gd:83` all say **"nine ids"**

## 11.9 Nets — where each one goes, and the inversion that must bite

**Every check below must be run inverted before it is believed.** *"If the inversion doesn't bite, suspect
the check last — first confirm the mutation actually landed"* — string replacement has silently matched zero
times, twice. **Observing anything tick-driven means pumping `Tuning.TICK_DIVIDER * 2` frames, never one.**

**`tests/nets/net_spell.gd`** — the sim

| Check | Inversion that must go red |
|---|---|
| A pillar notice exists at the cell the bolt landed on, `w` = 8 and `h` = 16, **literal coordinates** (never read back from `pillar_w()`) | Shift the notice one cell |
| The rect occupies rows **`< y`** (above), not below or beside | Flip the sign on the height walk |
| **The grid is byte-identical** to a bare impact with the same rune **and** the notice fired | Make the pillar call `cmd_carve`. ⚠ Grid-equality alone is *"A/B catches diverged, never vanished"* — **the notice assertion is the half that catches "nothing happened"** |
| The height **stops at the first solid above**: build a ceiling 5 cells up, assert `h == 5`, not 16 | Delete the `BEHAVIOR_STATIC` test |
| `[응축, 폭발]` ≠ `[폭발, 응축]`, **and both glyphs ran in both orders** (assert `pillar_count()` and `blast_count()` are each 1, both ways) | Make the TERMINAL branch return `GLYPH_NONE` |
| `[확산, 응축]` raises **exactly 8** pillars, each at gen 1 (`h == 8`) | Assert the count, not `> 0` — *a loop whose condition is false from the start never runs the check* |
| `[응축_R, 응축_R]` gives **120 and 120, not 144** — the shape `_blast_power_does_not_leak_between_layers` already pins | Write `blast_power` back into `power` |
| **Every rune in `ELEM_ALL`** fires condense with no `push_error` | The wrapper's stderr check does this for free |
| **No deferral**: fire 8 pillars on one tick, assert `pending_count() == 0` | — this is the *positive* form of §6.3's overturned budget |

**`tests/nets/net_tables.gd`** — `pillar_w`/`pillar_h` in `_strictly_decreasing`'s name list.
**Invert the instrument, not only the subject**: set `pillar_h` gen 1 to 16 (equal, not smaller) and confirm
it goes red. If it does not, the name was never added — the exact 1,038-green failure that file records.

**`tests/nets/net_damage.gd`** — the hit

| Check | |
|---|---|
| A body **standing in** the pillar is hit; a body **`pillar_w`+1 cells to the side** is not | The check that catches reusing the circular blast test for a rectangle |
| A body **above the pillar's top** is not hit | The height must bound the rect, not just the drawing |
| **Hits to kill a pig at `CONDENSE_C` vs `CONDENSE_U`, both absolute numbers**, never a ratio | |

**`tests/nets/net_render.gd`** — the picture. `blast_fx` is already driven there.

- Override **`_paint_pillar`**, tree the node, `pump_frames`, and **assert the captured rect** equals what the
  notice asked for. *"`_draw()` ran" is not "anything was drawn"* — three features shipped erasable pictures
  under 6,163 green checks
- The drawn height **rises**: capture at two times inside `PILLAR_RISE_SEC` and assert the second is taller.
  Then assert the pillar is **gone** after `PILLAR_SEC`
- **The three symbols differ.** Drive `_draw_pick_glyph_shape` (or the `GLYPH_SYMBOL` lookup) for
  `SPREAD_C` · `BLAST_C` · `CONDENSE_C` and assert **three different symbol constants**. This is the check
  that would have caught §11.5, and it is worth writing even though the eye is the real judge
- `_effect_text(CONDENSE_C, KIND_TERMINAL)` != `_effect_text(BLAST_C, KIND_TERMINAL)`

**`tests/nets/net_pick.gd` · `net_three_pick.gd` · `net_circle.gd`** — nothing new to write; their
`Glyph.ALL.size()` assertions follow on their own. **The hand-written "9" in comments does not** (§11.8).

## 11.10 Acceptance — what says it is done

Headless: §9's list 1–7 and 9–12, as mapped onto the nets in §11.9. **§9's item 8 (damage by value) is in**;
**§9's item 6 (the budget defers) is out** — §6.3 was overturned, and its replacement is *"assert
`pending_count()` stays 0"*.

Screen (**the user's call, and no number substitutes**):

1. **Does it read as 솟는다** — the one thing this glyph exists for
2. **Do 확산 · 응축 · 폭발 separate as three cards**, side by side on the real circle at a 48 px band.
   §11.5 is the code half of this; the eye is the other half
3. **Is a none pillar visible at all**, and is the fire pillar distinguishable from the rune trace burning
   at its foot (§2.4 predicts they overlap)
