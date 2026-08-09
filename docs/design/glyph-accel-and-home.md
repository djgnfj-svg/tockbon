# Accelerate and home — the last two family seats

**One line**: two `MODIFY` glyphs that change **how a bolt flies**, not what it does on landing — and they are the
**fourth and fifth families**, which fills the nibble exactly.

**Implemented**: none — **two `.png` files exist and no code knows them**
(`assets/circle/ring_accel.png` · `ring_home.png`). That is the stage before this repo's signature fake, and
naming it is why this doc exists.
**Accepted**: unseen — nothing runs, so there is nothing to look at.

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).
What the three axes hold is [circle-rune-glyph.md](circle-rune-glyph.md); art spec and file sizes are
[circle-art.md](circle-art.md); the game-wide source is `../GDD.md`.

**Every number quoted below is a pointer, not a copy.** Speeds, drag and radii live in `src/sim/sim_tuning.gd`
and its comment tables; if this doc and that file disagree, **the file is right**.

---

## Why these two, and why now

Three things arrived at the same place.

1. **The art was drawn first.** `ring_accel` (12 straight spokes reaching outward — "it gets faster") and
   `ring_home` (double ring, four clockwise arrows — **the only ring in the set that has a direction**). Both
   288px, same weight and ground as `ring_spread` / `ring_blast` / `ring_dummy`.
2. **The two have a documented behaviour already.** `circle-rune-glyph.md`'s glyph table marks eleven of
   seventeen "name only" and calls out these two as "example in docs only" — they are the only unbuilt glyphs
   with a stated verb, which is exactly why `circle-art.md` drew these two and stopped.
3. **`glyph_defs.gd` left room for exactly two more families**, and wrote its own ceiling down (that file's
   "the nibble ceiling is real from here on"). Three families are in. **These two make five. Five is the
   ceiling.** See "The nibble ceiling" below — it is the single most consequential section here.

---

## What accelerate does — **drag, not launch speed**

### The trap first

`sim_tuning.gd`'s `SIM_SIZES` speeds are **12 (gen 0) and 6 (gen 1)**, and both were lowered to those values
for one reason: the head sprite skipped past itself between frames. `net_tables._bolt_head_keeps_up` measures
that floor, and its own comment records that **both rows land exactly on 1.00** — there is **zero headroom.**
Any increase in launch speed puts the drawn head past its own body in one frame.

**And the net would not catch it.** That check reads `Tuning.speed_cells(gen)` — a **table**. A glyph that
multiplies a *bolt's* speed at launch never touches the table, so the net stays **green** while the art skips on
screen. This is CLAUDE.md's "a check that greps a file measures its text, never what it computes", arriving on
the exact check that exists to prevent this. ⇒ **Accelerate-as-speed is not "the net goes red". It is "the net
lies."** That is strictly worse and it is the reason this section exists.

**Growing the art instead is closed too.** `circle-rune-glyph.md` pinned that size already carries the
generation axis and that colour/brightness carries power precisely so **two meanings never share the size
knob**. Head size growing with an accel stack would be a third meaning on the same knob.

### ⇒ Accelerate multiplies **drag**, and leaves launch speed alone

Drag is `_vx * DRAG_NUM / DRAG_DEN` every tick (`spell_sim._advance`). Today it is a **global constant**.

```
faster:  raise launch speed   →  peak px/frame rises  →  the head skips     ✗
farther: raise DRAG_NUM       →  peak px/frame is unchanged (tick 1 is the peak)  ✓
                                 the bolt simply stops losing speed
```

**The peak is tick 1 regardless** — drag only ever removes speed, so a bolt with less drag never moves faster
in a frame than the same bolt did on its first frame. **`_bolt_head_keeps_up`'s floor is never approached, in
truth and not only in the check.** No art is regenerated, no table row moves.

What the player sees: **the bolt goes much farther and droops much later.** `sim_tuning.DRAG_NUM`'s own comment
already measured the sensitivity — a small coefficient change swings range hard, and 248/256 is roughly double.
**Read that comment; the numbers are not copied here.**

**This is also what the design already said accelerate does.** `circle-rune-glyph.md`'s coefficient table lists
accelerate as touching **initial speed *and* drag**, and its rule is "accelerate is not 'make the velocity
straight' but 'increase whatever the velocity currently is'". Taking only the drag half keeps that sentence
true — on a fire bolt it reads as a long flat arc, on a future lightning bolt as a longer straight line.

### Where it is stored, and who else wants the same field

Drag becomes **per bolt** — one more parallel array in `spell_sim` (`_drag`), seeded at `_launch`.

**This is not a cost this glyph pays alone.** `circle-rune-glyph.md`'s stage-1 rune plan says the same
sentence: "drag and gravity are **global constants** in the current code; they just need to be carried per
bolt." ⇒ **accelerate and per-rune flight coefficients want the identical array.** Building it once serves both;
building it twice is the divergence this repo keeps writing down.

### The composition ceiling — `POWER_MAX`'s idiom, one axis over

Drag composes **multiplicatively toward 1**, so stacking is a runaway in *range*, which is the same shape the
GDD's "one spread per circle" exists to block in *bolt count*. Two guards, and they are different guards:

| Guard | What it stops |
|---|---|
| `max_per_circle: 1` on the accel family | **Assembly time** — the constraint shows before you fire (`spell_circle._list_ok`, the design's "failing after you fire reads as a malfunction") |
| A clamp on the composed drag numerator, **strictly below `DRAG_DEN`** | The **bark ceiling** — exactly `POWER_MAX`'s idiom. At `DRAG_NUM == DRAG_DEN` there is no decay at all and `LIFETIME_TICKS` becomes the only thing that ends the bolt |

**Values are TBD.** `max_per_circle: 1` is the recommendation; the clamp is not optional either way, because
`fire()` takes commands off the wire that never passed through the assembly window.

---

## What home does — and the two problems that are not about integers

### Problem one: **the sim does not know monsters exist, and cannot be told to look**

`src/sim/` may not reference `src/actor/` (`net_layers`'s table). Monsters are `src/actor/monster.gd`, they
walk at **60Hz against a float `dt`**, and `spell_sim` has never seen one — the only thing crossing between
them is the **segment notice**, which goes sim → actor and carries no identity.

So targets must be **handed in**, once per tick, through one door:

```
world_step.frame()  tick branch
    …
    _spell.set_targets(xs, ys, ids)     ← new, integer px or cells, built here
    _spell.step(_grid)
```

`monster.x` / `monster.y` are already **integer px**, so nothing float crosses the line. `world_step` is
`src/actor/`, where the conversion is legal.

### Problem two: **this makes a lockstep trajectory depend on host-authoritative state**

This is the part that is easy to miss and expensive to discover later.

```
monster positions   host-authoritative, 60Hz, float dt      (GDD multiplayer table)
bolt flight         lockstep — every client reproduces it   (spell_sim.gd's own header)
bolt impact         carves terrain — lockstep world state
```

A homing bolt reads the first and writes the third. ⇒ **Two clients with slightly different monster positions
carve different holes, and the worlds diverge permanently** — precisely the failure `spell_sim.gd`'s header
spends its opening paragraphs on.

**No net can catch this.** `net_determinism` is a **folder text scan** for `float`/`Vector2`/`sqrt`; a
`PackedInt32Array` of target cells handed in from outside passes it cleanly while carrying non-deterministic
values.

**Three ways out, and the choice is the user's:**

| Path | What it costs |
|---|---|
| **A — snapshot and accept** (recommended for now) | Single player is exactly correct. Multiplayer must later either move monsters into the sim or ship the snapshot on the wire. **Write it down here and in `docs/decisions/`, or it is rediscovered the day multiplayer starts** |
| **B — home on terrain / the aim point, not on monsters** | Fully deterministic, zero cross-layer data, and **weaker**: "curves toward where I clicked" is a much smaller verb than "chases the pig" |
| **C — monsters become sim state first** | Correct and large. It is a different feature, not this one |

**A is recommended** because monsters will have to become deterministic for multiplayer regardless, and because
"skeleton first" says do not build C to unblock a glyph. **But A is only honest if the cost is recorded**, which
is what this table is.

### Choosing the target — integer only

`src/sim/` forbids `sqrt`, `sin`, `Vector2`, `randi`. Every piece below is already an idiom in this repo.

**Distance: squared, never rooted.**

```
d2 = dx*dx + dy*dy          both in cells (or cell fixed point)
compare d2 against d2       — the root is never needed to answer "which is nearer"
```

Headroom, stated rather than assumed: in **cells**, the grid is 4096 wide, so `dx*dx` peaks near 1.7e7 — inside
int32 with room. In **cell fixed point** (1/256, the unit `_px`/`_py` actually use) the same term reaches ~1e12,
which needs GDScript's 64-bit int and must never be stored into a `PackedInt32Array`. **Pick one unit and say
which** — `spell_sim.fire()`'s `AIM_MAX` comment is the precedent for writing an overflow bound down beside the
value that sets it.

**Range gate.** Only targets inside `HOME_RANGE_CELLS` are considered, compared squared. Without it a bolt turns
toward something across the map and reads as a malfunction, not as homing.

**Tie-break by monster id — never by array index.** `spell_sim._remove` is a swap-remove and slot indices
shuffle every tick (that member's own comment). Breaking a tie on iteration order makes the result depend on
process history, which is CLAUDE.md's ordering-contract failure: **final state can be identical while the
process is wrong, and a check that reads only the final state sees nothing.** Ids are monotonic and stable
(`world_step._next_monster_id`).

**Retarget every tick, or lock at launch?** TBD. Locking is cheaper and reads as "it was aimed at that one";
retargeting reads as "it hunts". **Locking also cannot follow a target that dies**, which needs a defined
answer either way (recommend: fly straight from then on — never "pick a new one silently").

### Turning the velocity — integer, and **without becoming accelerate**

**Do not rotate.** `sin`/`cos` are forbidden and rational approximate rotation drifts in length — the exact cost
`circle-rune-glyph.md` records as the reason **spin** is still unresolved. Homing does not need rotation.

Reuse `_launch`'s own normalization, which is the only place this repo takes a root:

```
1. unit vector toward the target       norm = _isqrt(len2 << (AIM_SHIFT+AIM_SHIFT))    ← 1 isqrt
2. current speed magnitude             cur  = _isqrt(vx*vx + vy*vy)                    ← 1 isqrt
3. blend                               v += (unit * cur - v) * TURN_NUM / TURN_DEN
```

Two `_isqrt` calls per **homing** bolt per tick. `_isqrt` is a Newton loop and its comment already says it runs
"once at launch and never in flight" — **that sentence stops being true and must be edited in the same change**,
or the file documents a property it no longer has.

**Step 3 shortens the vector.** Blending two equal-length vectors gives a chord, not an arc, so `|v|` dips
slightly on every turn. Two consequences, and both are decisions:

- The dip is bounded and small at small `TURN_NUM/TURN_DEN`. **Measure it, then either accept it as
  "turning costs a little speed" (a defensible feel) or pay a third `_isqrt` to renormalize.**
- **Homing must never make a bolt faster.** If it did, home would silently contain accelerate, and then two of
  five families overlap — the "amplify vs empower" trap `circle-rune-glyph.md` names as the risk of a long list.
  ⇒ **A net measures that a homing bolt's per-tick displacement never exceeds its non-homing twin's.**

`TURN_NUM/TURN_DEN` is TBD and is **the whole feel of the glyph**: too low reads as a bug ("my shot curved?"),
too high reads as a guided missile and makes aiming pointless.

---

## Both are `MODIFY` — and that widens what `MODIFY` means

`circle-rune-glyph.md`'s three-kinds table already files accelerate and home under **modify**, and the code
agrees structurally: `KIND_MODIFY` means **"consumed whole at `_launch`, never reaches `_resume`"**
(`glyph_defs.gd`, `spell_sim._launch`).

**But that constant's docstring today says `MODIFY` "touches neither trajectory nor list — it only multiplies
`power_pct`".** Accelerate and home are per-tick flight rules. ⇒ **That sentence is what has to widen**, in the
same edit, from "only multiplies power" to "is consumed at launch and seeds this bolt's own flight columns".
Leave it and the file documents a rule the code no longer holds — this repo's most-repeated failure.

**A fourth `kind` is the wrong answer.** `glyph_defs.gd`'s header pins "one glyph = one row + one branch by
`kind` + (if presentation differs) one `fx_tuning` row. A fourth place appearing means the structure is wrong."
Adding columns to the existing rows is the cheap change; adding a kind is the expensive one.

### What the pipeline gives us free

`_launch` strips the **leading run** of MODIFY glyphs and hands `rest` onward. That single existing mechanism
already produces the order behaviour `circle-rune-glyph.md` wrote as accelerate's headline example:

```
[accel, spread]   the parent flies far · the 8 children do not      ← parent strips accel at ITS launch
[spread, accel]   the parent flies normally · each of 8 strips accel at its own launch
```

**Not one line of new order machinery.** It is the same path `[dummy, spread]` versus `[spread, dummy]` already
walks, and `spell_sim.gd`'s "power_pct" header section is the written form of the rule.

⇒ **`_list_ok` needs no new cross-family rule.** The "one spread per circle" rule is about **bolt count**;
accelerate and home create no bolts. What they need is a **per-family cap of their own** (above), not a rule
about what they may sit beside.

### ⚠ But a trailing `MODIFY` after a `TERMINAL` barks — **and it is reachable today**

Read from the code, **not driven** — verify before acting on it.

`_resume` walks the whole list. A `TERMINAL` returns `rest`, so the loop reaches the next id and calls
`_run_glyph`, whose `else` branch **`push_error`s on a `MODIFY` id** (that function's own comment says this is
deliberate: "MODIFY must never reach `_resume`"). But `_launch` strips only the **leading** run.

```
round circle, layer 1 = 폭발, layer 2 = 더미     ← both placeable, fire() accepts it
    → _launch strips nothing (BLAST is first)
    → _resume runs BLAST, returns rest = DUMMY
    → _run_glyph(DUMMY) → else → push_error
```

**That is a bark on an ordinary left click**, which this repo has already once removed as a false handle
(`spell_circle.element()`'s own comment) and which turns the net wrapper's stderr check red.

**Why it matters here and not before**: today exactly **one of three** families is `MODIFY`. After this doc it
is **three of five**, and the round circle's two layers make `[terminal, modify]` an ordinary thing a player
builds by accident. ⇒ **Decide the intended behaviour before shipping**: silently ignore a trailing MODIFY
(it belongs to a bolt that was never born), or block the arrangement at assembly time. **Do not leave it
barking.**

---

## The nibble ceiling — this doc spends the last two seats

`Tuning.GLYPH_BITS` is **4** ⇒ ids `1..15` (0 is reserved as "end of list") ⇒ **15 ids = 5 families × 3
rarities.** Nine are used. Accelerate and home take the remaining six.

**⇒ After this, `GLYPH_BITS` is exactly full and no bit change is needed.** The ceiling is *reached*, not
*exceeded*. **The widening belongs to the sixth family, not to this doc** — and this doc is the last one that
can be written without paying for it.

### What the sixth family costs — and the option `glyph_defs.gd` did not consider

The rule is `layers ≤ 31 / GLYPH_BITS` — 31, not 32, because `PackedInt32Array` is **signed** and an id in the
top nibble makes the value negative, where `>>` sign-extends and corrupts it **with no error**
(`sim_tuning.GLYPH_MAX_LAYERS`'s own comment).

| `GLYPH_BITS` | ids | families | `GLYPH_MAX_LAYERS` |
|---|---|---|---|
| **4** (today) | 15 | **5** | **7** |
| **5** | 31 | **10** | **6** |
| 6 (what the code comment plans) | 63 | 21 | **5** |

**`glyph_defs.gd`'s comment jumps 4 → 6 and skips 5.** Five bits buys **ten** families for **one** layer;
six bits buys twenty-one for **two**. `circle-rune-glyph.md`'s glyph list is **seventeen** — so six bits is the
only value that covers the whole planned roster, and five bits covers ten of seventeen. **That is a real
trade-off and it should be a recorded decision, not a value inherited from a comment.**

**Today the layer loss costs nothing.** The deepest circle in `circle_defs` is the triangle at **3 layers**;
the round circle is 2. Both 6 and 5 clear that with room. `circle-art.md`'s "band thickness for a 7-layer
circle" section says the *art* already fails past 4 layers ⇒ **pinning `GLYPH_MAX_LAYERS` lower may resolve an
open art problem rather than create one.** That section names "pin a layer-count ceiling" as one of its three
candidate answers.

### Two things that go stale on the day id 15 exists

- `glyph_defs.count_family`'s comment documents its guard with the example "firing packed `[SPREAD_C, 15]`
  (a real id followed by an id outside `DEFS`)". **Id 15 becomes a real id.** The guard still works; the
  example no longer demonstrates it. Same for `spell_circle._count_family`'s twin comment.
- `net_tables._glyph_nibble_ceiling` should be read before, not after — it is the check that knows what "full"
  means, and it must still bite when the table is exactly full.

---

## Art — what exists, what does not

**Two files exist and nothing references them.** `assets/circle/ring_accel.png` · `ring_home.png`, both 288px,
seeds recorded in `circle-art.md`'s file table (that doc is the source; not copied here).

**288 is the triangle circle's *socket* band, not the round circle's layer band** (`circle-art.md`'s two spec
tables). And the code's map is keyed to a different filename convention:
`fx_tuning.SOCKET_GLYPH_TEX` points at `socket_glyph_spread.png` / `socket_glyph_blast.png`.

| Needed | Size | Exists? |
|---|---|---|
| Socket ring — accel · home | 288 | **`ring_*.png` exist, but under a name `SOCKET_GLYPH_TEX` does not use.** Rename, or add the key |
| Palette / three-pick icon — accel · home | 112 | **No.** `icon_spread` · `icon_blast` · `icon_dummy` exist |
| Round-circle layer ring — accel · home | 896 | **No** — and no family has one yet, so this is not a debt these two create |
| `fx_tuning.GLYPH_TINT` rows | — | **No.** 2 families × 3 rarities = **6 rows**, and `net_tables._glyph_tint_covers_every_glyph` goes red without them (**a net that actually bites**) |

**A missing texture is not an error** — `circle_window._draw_ring` falls back to the procedural symbol
(`SOCKET_GLYPH_TEX`'s own comment). ⇒ **the code can land before the art is renamed**, and that ordering is
allowed.

### ⚠ `ring_accel` collides with `ring_spread`, and this doc is the day it comes due

`circle-art.md` shipped that collision knowingly and wrote the trigger: *"It shipped anyway because accel has
no code and nothing depends on telling them apart yet. **The day accel enters the pipeline, one of the two
gets redrawn.**"*

Both read as "strokes reaching outward" — spread's split into branches, accel's parallel bars of rising length
— and at a 48px band that difference is thinner than the thing that doc calls the whole point. **This is the
"are the six glyphs distinguishable" question arriving early, on a pair**, and it is not decoration: spread and
accel are both things a player puts on layer 1, and the GDD's "if order isn't visible on screen the player
never learns the rule" is what fails if they read the same.

**Which of the two gets redrawn is TBD (user).** `ring_home` has no such problem — the clockwise arrows make
it the only directional ring in the set.

### Colour

`GLYPH_TINT` carries **family**, `RARITY_TINT` carries rarity as a separate ring (that file's own "two
independent devices" rule). Two new hues are needed that are far from cyan (spread), orange (blast), the
dummy's neutral tan, **and from `DEAD_TINT`'s cool grey ("cannot fire")** — the last one is the constraint
people forget, and `circle-rune-glyph.md` records the none-rune version of exactly that mistake.

---

## Cost

**A model built from reading, not a measurement.** Say so plainly until someone drives it.

**Accelerate is free.** One more per-bolt integer read in `_advance`, replacing a constant read. No scan, no
root, no new pass.

**Home pays per homing bolt, per tick:**

```
targets scanned   =  (homing bolts)  ×  (live monsters)
isqrt calls       =  (homing bolts)  ×  2
```

The ceilings, each read from its own file: `MAX_PROJECTILES` **32** (`sim_tuning`), `MonsterDefs.MAX_MONSTERS`
**20**.

| Case | Homing bolts | Scans/tick |
|---|---|---|
| Absolute worst the caps allow | 32 | 640 |
| **What the circle rules actually allow** — `spell_circle._list_ok`'s own explosion analysis puts the real ceiling at **10 bolts** | 10 | **200** |
| Ordinary: one spread + home | 8 | 160 |

**Only homing bolts scan.** Every other bolt costs one boolean test, so the whole term is zero in a run with no
home glyph equipped — which matters, because that is most runs.

**Against the 20Hz budget (50,000 µs)**: `spell_sim`'s existing note puts 32 bolts at roughly 128 µs/tick, and
the blast path is the file's acknowledged real ceiling (`MAX_BLASTS_PER_TICK`'s comment: 1,291 µs measured for
one `rd`-12 blast). ⇒ **200 integer distance comparisons plus 20 Newton loops is not plausibly the bottleneck**,
and the honest sentence is "it is small next to the blast term", **not** a µs figure nobody measured.

**Where the real cost would show up is the 60Hz side, not here** — `monsters.md` records 20 hens at 32% of the
60Hz frame. **Homing adds nothing to that**; it reads positions that are already computed.

**One design choice keeps it this cheap**: `world_step` builds the target list **once per tick** and hands it
in. Let each bolt walk the monster array itself and the same work is rebuilt per bolt.

---

## Acceptance — split by what can actually see it

**Headless (`verify-run` / nets) — measurable by value**

1. **Accelerate goes farther.** Drive `_launch`/`_advance` over a floorless grid and read the x where `vx`
   truncates to 0 — the exact harness idiom `DRAG_NUM`'s comment table was built with. An accel bolt's ceiling
   exceeds a plain bolt's by the expected ratio.
2. **Accelerate never moves faster in one frame than a plain bolt does on its first frame.** This is the check
   that holds the whole "drag not speed" decision. Without it, someone changes accel to touch `speed` later and
   **nothing goes red.**
3. **`[accel, spread]` and `[spread, accel]` produce different worlds.** The children's range differs. Beware
   CLAUDE.md's warning: an A/B that only compares final grids catches "diverged", never "vanished" — so also
   assert **both** arrangements actually launched 8 children.
4. **A homing bolt with no target in range is byte-identical to a non-homing bolt.** This is the "vanished"
   guard: it fails if homing silently applies to everything, and it fails if homing silently applies to nothing.
5. **Homing reduces the miss distance.** Same launch, one monster present: the homing bolt's impact point is
   nearer the target than the plain bolt's. **Assert the loop ran** — a settle loop with zero iterations passed
   in this repo once.
6. **Homing never increases speed** (the accel-overlap guard, above).
7. **The target choice is order-independent.** Feed the same monsters in a permuted order; the chosen target id
   is identical. This is the check that measures the *process*, not the final state — the failure mode
   CLAUDE.md lists first.
8. **Table checks follow for free** and will go red on their own if a step is skipped: `_defs_and_all_agree`,
   `_glyph_nibble_ceiling`, `_power_pct_increases_by_rarity`, `_glyph_tint_covers_every_glyph`.
9. **No ordinary arrangement barks.** Fire every placeable 2-layer combination of the five families and assert
   stderr is clean — this is what catches the `[terminal, modify]` hole above.

**Screen only (`verify-look` / the user) — cannot be measured**

10. **Does accelerate read as "faster"?** It is not faster; it is farther and flatter. **If the user's word for
    it is "it just goes further", the glyph's name is wrong or the axis is wrong**, and that judgment cannot
    be made headless.
11. **Does homing read as homing, or as a bug?** A gently curving bolt with no visible reason is indis-
    tinguishable from broken physics. This is the single riskiest screen item.
12. **Do `ring_accel` and `ring_spread` separate at a 48px band?** The collision above. **Side by side, on the
    real circle** — `circle-art.md` records that judging a ring alone gives the wrong answer.
13. **Are the five staff-tip colours distinguishable from each other and from `DEAD_TINT`?**

---

## Screen — what has to be visible

| Where | What | Note |
|---|---|---|
| **Staff tip** | Two new `GLYPH_TINT` hues | `fx_tuning`'s "one new glyph = one line here" |
| **Circle window — socket band** | `ring_accel` / `ring_home` through `SOCKET_GLYPH_TEX` | Falls back to the procedural symbol until the files are keyed |
| **Palette** | **9 cells become 15** | Three families × three rarities was the layout's premise. **`palette_layout` has to be looked at, not assumed** |
| **Three-pick cards** | Accel and home can now be rolled | `three_pick.gd` draws from `Glyph.ALL` with no per-family knowledge ⇒ **no change needed**, which is the design working |
| **In flight** | **TBD, and it matters** | Item 11 above. An accel bolt and a homing bolt look **exactly like a plain bolt** today. `_notify_seg` deliberately carries neither generation nor rune ("sending a value nobody uses makes it a false knob") — so making flight legible means a **new** notice, not a free one |

**In-game names are Korean**: **가속** and **유도** (proposed). Every other glyph name in `glyph_defs.DEFS` is
Korean (`확산` · `폭발` · `더미`).

---

## Not decided yet

**Skeleton first. These are supposed to be open** (GDD, "build order").

**Accelerate**
- **Drag or launch speed** — the recommendation above is drag, with the reasoning written out. **User call.**
- The drag values per rarity, and the clamp ceiling
- `max_per_circle` — recommend **1**

**Home**
- **Path A / B / C** — whether homing may read monster positions at all, and whether the multiplayer cost is
  accepted now or the glyph is scoped to terrain/aim
- Target rule: **nearest** · within the aim cone · last hit. Nearest is the cheapest and the most legible
- **Retarget every tick or lock at launch**, and what happens when a locked target dies
- `TURN_NUM/TURN_DEN` and `HOME_RANGE_CELLS` — **the entire feel**
- Renormalize after the blend (a third `_isqrt`) or accept the chord dip
- `max_per_circle` — recommend **1**, so `[home, home]` cannot be a glyph that does nothing new

**Shared**
- **Trailing `MODIFY` after a `TERMINAL`** — ignore it, or block it at assembly. **Not "leave it barking".**
- Whether `KIND_MODIFY`'s widened meaning stays one kind (recommended) or splits
- **`GLYPH_BITS` 4 → 5 or 4 → 6** on the day a sixth family arrives. **Not this doc's change**, but this doc is
  where the trade-off is now written down
- **Which of `ring_accel` / `ring_spread` gets redrawn**
- The two in-flight tells (item 11) — or the decision that there are none
- Korean names: **가속** · **유도**

---

## Relationship to the other docs

**Nothing here overrides `circle-rune-glyph.md`.** That doc owns the glyph list, the three kinds and the
coefficient table; this one only fills in two of its rows and records what the code costs.

**Two of its lines get sharper and should be updated when this is built:**

| It says | After this |
|---|---|
| accelerate · home — "example in docs only" | Defined. **Accelerate is a drag glyph, not a speed glyph**, and the reason is a net's floor with zero headroom |
| "Drag and gravity are global constants; they just need to be carried per bolt" | Still true, and **accelerate is the first thing that actually needs it** |

**`circle-art.md`'s accel/spread collision reaches its stated trigger here** and should be updated in the same
change — its own sentence names this day.
