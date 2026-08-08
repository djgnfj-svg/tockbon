# Circle · rune · glyph — what each of the three axes holds

**One line**: the circle owns the moment of firing, the rune owns what happens after it leaves, the glyph owns what is added on top.

**Implemented**: partial — circles **1/3** (round only) · runes **3** (fire · none · water) · glyphs **2/17** (spread · blast)
**Accepted**: partial — the user confirmed on screen that **order changes the kind of result** (spread ↔ blast).
The rest (fusion · parallel · sequential · per-rune behavior · the remaining glyphs) **has no implementation, so there is nothing to judge.**

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).
Implementation specs for individual features live in `docs/plans/`. The game-wide source is `docs/GDD.md`.

---

## Why this needed sorting out

**If the circle decides the shape, the rune dies.**

The GDD's original split was "circle = firing shape (straight or spreading) · rune = element · glyph = impact effect".
That means **fire, water and lightning all fly identically under the same circle.** The rune changes only color and trail.

Lightning that arcs slowly through the air **is not lightning.**
The GDD line "a glyph's picture varies by rune. **The rule is the same**" was pinning the rune to a color axis.

⇒ **Behavior moves to the rune.** That forces a redefinition of what the circle holds, and this doc is the answer.

---

## The three axes — cut along time

```
     circle              rune                  glyph
─────────────    ──────────────      ────────────────────
the moment of  →  after it leaves  →  after it lands
firing                                (+ while travelling)

how many go out   what it is          what else happens
and grouped how   how it travels
how many layers   what it leaves in the world
```

**The three don't overlap in time.** Overlap and the lists eat each other — "does the circle spread"
and "the spread glyph spreads" overlapped exactly that way.

---

## Circle — the frame

There is one circle. **It decides the shape and size of the vessel.**

**The circle does not decide how things fly.** The rune took that.
The circle decides **the departing arrangement.**

### The four things a circle holds

| What | Meaning |
|---|---|
| **Layer count** | How many glyphs can be placed |
| **Rune slots** | How many runes fit |
| **How runes combine** | Fusion · parallel · sequential |
| **Glyphs per-rune or shared** | See "Two layer concepts" |

### The three ways runes combine

| Mode | What | Result |
|---|---|---|
| **Fusion** | Runes merge into **one new element** | water + fire = 1 steam shot |
| **Parallel** | Runes go out **separately** | fire · water · lightning, 3 shots at once |
| **Sequential** | Runes go out **in turn** | fire, then water. Becomes rapid fire |

**The circle does not separately set the shot count — it falls out of the rune arrangement.**
That is why something like a "3-shot fan circle" becomes unnecessary. Three runes in parallel *is* three shots,
and those three carry **different elements**, which is far more interesting than three of the same.

Fusion **needs a combination table** (water+fire=steam). Parallel and sequential don't.
The GDD's TBD "rune combination table" is the fusion circle's prerequisite.

### Two layer concepts — always separate them

"The circle is 2-layer" carries **two meanings** once there are multiple runes.

| Concept | Meaning | What it sets |
|---|---|---|
| **Total glyph slots** | How many glyphs fit in the assembly window | **Variety** |
| **Layers per bolt** | Pipeline depth one bolt experiences | **Permutation depth** |

```
3 runes · 1 layer each   3 slots, 1 layer/bolt    Three spells at once. No concept of order
3 runes · 2 shared       2 slots, 2 layers/bolt   Three of the same spell. Order lives
1 rune  · 4 layers       4 slots, 4 layers/bolt   One deep spell. 24 permutations
```

**Layers per bolt are the raw material for the GDD thesis ("different order, different result").**
A circle with one layer per rune has no concept of order at all — that is not a defect, it is **a different kind of circle.**

As a picture:

```
glyphs per rune                    glyphs shared
╭───────────────╮                ╭───────────────╮
│  ⬢      ⬢     │                │   ╭───────╮   │
│  ○      ○     │                │   │ ⬢ ⬢ ⬢ │   │
│      ⬢        │                │   ╰───────╯   │
│      ○        │                │      ○○       │
╰───────────────╯                ╰───────────────╯
 fire→blast water→spread          fire·water·lightning all spread→blast
 lightning→home
```

⇒ **The rune-slot layout is the circle's picture.** Fusion has two interlocked slots, parallel has them apart,
per-rune layers give multiple rings. **The picture states the rule** —
the GDD line "if order isn't visible on screen the player never learns the rule" extends this far.

### Circles differ in character

- **Deep circle** — 1 rune, 4 layers. Assemble one spell deeply
- **Wide circle** — 3 runes, 1 layer each. Throw three spells at once
- **Middle** — 2 runes fused, 2 shared layers

**This is what makes it a real choice in a roguelike.** More layers isn't strictly better; it becomes
**what you give up for what you gain.** If only the layer count differs, that is an upgrade, not a choice.

### The circle list — **three of them** (decided by the user)

| Circle | Rune slots | Layers | Rune combining | Character |
|---|---|---|---|---|
| **Basic** | 1 | 2 shared | — | **Deep** — permutation lives |
| **Fusion** | 2 | 1 shared | Fusion | **Middle** — two merge into one new element |
| **Triangle** | 3 | **1 per rune** (3 slots total) | Sequential | **Wide** — **no permutation** |

**The three are not a ladder.** The triangle has three runes but **cannot use order combinations** — one layer per
rune means a bolt passes through **exactly one** layer, and then there is no material for the GDD thesis.
⇒ **A different kind, not an upgrade over basic.** This is where "if only the layer count differs it's an upgrade"
was dodged, and the dodge was **adding runes instead of layers, and taking the layers away.**

**The triangle's "sequential" sets firing order, not glyph order.** The three runes go out in turn, and each bolt
carries **only its own socket's glyph.** "1 → 2 → 3" is **clockwise from 12 o'clock**, and the picture
**does not indicate that order** (user decision — "the picture doesn't state the order" below).

**Three is not the end.** The user pinned "more will be added later" — **three is what gets built now.**
Art specs and generation live in `circle-art.md`.

### The picture doesn't state the order — a contract broken knowingly

The triangle's clockwise order is **shown by neither arrow nor number** (decided by the user:
"no indication at all. The user just plays and learns it. The answer is clockwise").

**This breaks the GDD's "if order isn't visible on screen the player never learns the rule" head-on.**
⇒ It was **chosen knowing that line**, not in ignorance of it, so if "nobody knows the order" is ever observed,
**this is the cause and this is what reopens.** Only two safeguards remain:

1. **There is a socket at 12 o'clock** — the picture states at least the starting point (that is why the △ layout was chosen)
2. **Onboarding** — the GDD says "the rule itself is taught in onboarding". **Whether the triangle goes there is TBD**

### Visually they are all circles

The difference is **the picture inside the ring**, not the ring itself.
It is a magic circle, so it doesn't stray far from being a circle.

---

## Rune — the element

A rune is an **element**. And **being an element, it flies accordingly.**

Don't see a rune as a bundle of coefficients; see it as **matter**. Then the player never memorizes a table —
"lightning is fast and straight" is common sense.

### The three things a rune sets

1. **What it is** — fire · water · lightning · wind …
2. **How it travels** — whatever is natural for that element
3. **What it leaves in the world** — ignition · wetting · shock …

### The rune list — **ten of them** (decided by the user)

**fire · water · lightning · wind · earth · grass · ice · none · light · dark**

**"Not all at once" came with the list as a condition.** Ten are not being opened; **the list is ten**,
and which opens when is decided separately.

**This list is the left side of the multiplication.** "Circle × rune multiply" above and "6 glyphs × 4 runes = 24"
below were **written assuming 4 runes** — with ten it is 6 circle types × 10 runes = **60 firings**, and every rune
opened to stage 2 requires redefining six glyphs. **That is why "start with stage 1" became a premise, not a choice.**

**Some runes need a world sim to have an identity** — water (flow · wetness), ice (freezing) and grass (fuel)
all fall under the GDD's "natural law", and without that sim they are **bolts with different coefficients.**
**That is order, not defect** — it is the criterion when deciding what opens when.

**"None" is already in code** — `sim_tuning.ELEM_NONE`, the starting rune, purple on screen (`fx_tuning.ELEM_FX`).
It didn't join the list; **it got a name.**

### Bolt-head art — spec and four colors (the user picked by eye)

**Spec.** **Additive blending is the whole spec** — `spell_view._ready()` uses `BLEND_MODE_ADD`, so black pixels
are transparent for free but **dark colors never appear on screen at all.**
⇒ Outlines and shading are impossible in principle. The art must be **light**, not a solid.

| Item | Value | Reason |
|---|---|---|
| Canvas | **32×16** | The head alone fills 16×16 (`bolt_px` 8 = diameter 16) ⇒ 16px on the left for the tail |
| Core center | **(24, 8)** | **This is the rotation pivot.** Off by any amount and **the head orbits** as the bolt turns |
| Direction | right = angle 0 | Code rotates by the `prev → cur` vector. Per-direction art means 10 runes × N directions |
| Glow | **Not in the art** | `BOLT_GLOW_RATIO` already draws a halo — putting it in the art makes two sources |
| Tail | Art keeps it **short only** | Long trails are drawn in code (`trail_ticks` 12/8). Long art doubles up, and since fire droops, **a straight painted tail disagrees with the trajectory** |

**AI generation would not produce a "short tail"** — even with `short` in the prompt the model fills the canvas.
**Pick then crop is the right order.** Aligning the core to (24,8) is also done by hand.

#### Measured — did the core actually land in the center (headless)

**First measurement of whether "core center = rotation pivot" was honored.** Brightness² centroid:

| Rune | From center | Vs width |
|---|---|---|
| fire | **(−1.49, +0.49) px** | 9.3% |
| none | (−0.59, −0.09) px | 3.7% |
| water | (−0.89, −0.30) px | 5.6% |

**Even though `crop_head.py` cropped to the centroid, 1.5px remains** — cropping is integer-pixel, so half a pixel
is unavoidable in principle. Generation 1 is half the size (8px), so **the same ratio is 0.75px.**
⇒ `tests/nets/net_bolt_sprite.gd` draws the line at **15% of width.**

**Color — the four are far apart.** Fire orange (30°) · water blue (210°) · lightning white-cyan · none **achromatic.**

**Confirmed by measurement**: fire saturation 0.92 · water 0.92 · **none 0.03**. Color distance 0.64–1.29.
⇒ **The runes are clearly distinguishable from each other.** **But the "knowingly broken contract" below still stands** —
what "none" must be distinguishable from is not another rune but **the grey of "can't fire"**, and saturation 0.03
confirms that worry numerically.

**And a new disagreement appeared — only "none" has a head color different from its trail.**

```
        head art (mean)          glow drawn in code
 fire   (0.98, 0.69, 0.08)      (1.00, 0.48, 0.12)   agrees
 none   (0.59, 0.60, 0.60) grey (0.55, 0.35, 1.00) **purple**   disagrees
 water  (0.08, 0.67, 0.99)      (0.20, 0.62, 0.95)   agrees
```

It appeared in the change that made the trail use `glow` instead of `core`
(`docs/plans/3.done/bolt-head-sprite.md`, "Result (3)"). **Nobody has looked at it on screen.**

**Making "none" grey is a contract broken knowingly** (user: "make none grey? pink is a bit much").
The `fx_tuning.ELEM_FX` comment records **why grey was rejected as a candidate** —
"**when a rune slot is empty the staff tip is already grey.** 'Can't fire' and 'firing with none' become identical
on screen, and that distinction is the entire warning `spell-circle-minimum` §3.5 built."

⇒ **If "I can't tell whether it failed to fire or it's none-element" is ever observed, this is the cause and this reopens.**
Only three safeguards remain:

1. The staff-tip grey is an **empty ring**; a none bolt is a **solid mass**
2. They are **in different places on screen** — one at the fingertip, one flying away
3. **If something is flying, it fired** — a failed fire produces nothing at all

And **rejecting purple has one more price** — being achromatic, it **shares a brightness axis with lightning (white-cyan).**
What separates them is not color but **silhouette** (lightning is jagged, none is round). Break that silhouette and they merge.

**The chosen four — reproduced by seed.** `tools/pixel/out/` is gitignored, so **the files disappear.**
This table is all that remains, and preset `bolt` plus the seeds below **regenerate the same art.**

| Rune | Folder / file | Seed |
|---|---|---|
| **fire** | `fire_head/fire_head_08` | `1407674110` |
| **water** | `bolt_water/bolt_water_01` | `1930186274` |
| **lightning** | `bolt_thunder/bolt_thunder_08` | `2008885172` |
| **none** | `bolt_none3/bolt_none3_04` | `1465894749` |

**Do not trust the sheet labels as seeds** — `sheet.py` prints only the **last 14 characters** of the stem,
so three of the four lost a leading digit (`930186274` ← actually `1930186274`). **Read the filename.**

**Weak fire is not being made** (user decision). The spec "weakness via color and brightness" is still alive —
"the starting point of power" below is that place; **the art simply hasn't been generated.**

### Behavior splits into two stages

**Stage 1 — same kind, different coefficients**

All projectiles. Only speed, droop and range differ.

| Rune | How it looks |
|---|---|
| fire | A mass, slow, arcing |
| lightning | Very fast, nearly straight |
| water | Heavy, dropping fast |
| wind | Fast and far, no droop |

Cheap. Drag and gravity are **global constants** in the current code (`src/sim/sim_tuning.gd`);
they just need to be carried per bolt.

**Stage 2 — it flies as an entirely different kind**

| Rune | What it is |
|---|---|
| fire | **A mass** — flies and hits |
| lightning | **A line** — drawn instantly. It does not fly |
| water | **A pour** — many droplets scatter and fall |
| wind | **A push** — an area is shoved |

**Stage 2 makes one rune into one code path.** Lightning as a line skips the trajectory code entirely.

**And a glyph's meaning changes per element.** If lightning is a line, does "spread" mean 8 directions at the
line's end, or splitting along the whole line? ⇒ The GDD's "a glyph's picture varies by rune, **the rule is the same**"
breaks here. **The trap of having to define 6 glyphs × 4 runes = 24 cases lives here.**

### ⇒ Start at stage 1 and open stage 2 one at a time

Two reasons.

1. **Stage 1 alone removes "every element flies identically".** Lightning at twice the speed with no droop
   is already a different spell on screen
2. **Opening all of stage 2 multiplies what must be defined.** Define it all up front and most of it goes stale before it's built

⇒ **Open exceptions one at a time, like "only lightning becomes a line".** Lightning as a line is a strong identity
and worth it; water pouring follows naturally once the water sim arrives. Coefficients suffice for the rest.

### Circle and rune multiply

```
fan layout (3 shots) × fire       = three fireballs leave in a fan, each drooping
fan layout (3 shots) × lightning  = three bolts leave in a fan, each going straight
```

6 circle types × 4 rune types = 24 firings out of **two tables.**
Put behavior in the circle and all 24 rows would be written by hand.

---

## Glyph — what is added

**A glyph creates nothing new. It layers onto what exists.**

If a glyph can do anything, it eats the other two — an "apply fire element" glyph makes runes unnecessary,
and a "split into 3 shots" glyph makes circles unnecessary.

| A glyph can | A glyph cannot |
|---|---|
| Increase speed | Change the element — the rune's job |
| Curve the direction | Change the firing arrangement — the circle's job |
| Split an existing bolt | Create a new element |
| Add a blast at the impact point | Add layers — the circle's job |

### The glyph list — **seventeen** (decided by the user)

| # | Glyph | Which of three | Defined? |
|---|---|---|---|
| 1 | **spread** | spawn | ✅ in code (`glyph_defs`) |
| 2 | **blast** | finish | ✅ in code |
| 3 | **condense** | ❓ | Name only |
| 4 | **accelerate** | modify | Example in docs only |
| 5 | **home** | modify | Example in docs only |
| 6 | **spin** | modify | Name only — **the integer-rotation cost is unresolved** (below) |
| 7 | **split** | ❓ | **How it differs from spread** is the first question |
| 8 | **refract** | ❓ | Name only |
| 9 | **amplify** | ❓ | **How it differs from empower** |
| 10 | **emit** | ❓ | Name only |
| 11 | **empower** | ❓ | **How it differs from amplify** |
| 12 | **distort** | ❓ | Name only |
| 13 | **absorb** | ❓ | Name only |
| 14 | **manipulate** | ❓ | **How it differs from control** |
| 15 | **control** | ❓ | **How it differs from manipulate** |
| 16 | **deploy** | ❓ | Name only |
| 17 | **convert** | ❓ | **If it changes the element it eats the rune** (below) |

**Eleven are names only. That is normal** — the GDD's "skeleton first" pins down that "TBD means it isn't its turn yet".
**But the two below are new risks created by the list reaching seventeen.**

**① Three pairs of names overlap** — amplify/empower · manipulate/control · spread/split.
**If the meanings don't separate, the player has two of the same glyph.** The list gets longer without gaining depth.
⇒ When defining them, write **what differs first.** If the answer is "both make it stronger", merge them.

**② "Convert" can eat the rune.** The table above pins "a glyph cannot change the element — the rune's job".
If convert means "fire → water", **runes become unnecessary.**
⇒ Convert survives only by **changing something that isn't the element** (direction · order · generation). That is the gate.

**Permutations barely grow.** The circle's layer count is the ceiling, so even at 17 a 2-layer circle still gives
**permutations of 2.**
**What 17 grows is not permutation but the variety of "what did I get"**, and that is roguelike value.

### Three kinds of glyph

**This distinction is the entire pipeline.**

| Name | When | What | The next glyph | Example |
|---|---|---|---|---|
| **Modify** | **Immediately** on being reached in the list | Alters how it flies | Continues right after | accelerate · home · spin |
| **Spawn** | After landing | Creates new bolts | **Each new bolt carries it** | spread |
| **Finish** | After landing | Happens there and ends | Continues at the same spot | blast |

**Modify is the new kind.** The current code (`src/sim/glyph_defs.gd`) has only spawn and finish.
Modify doesn't wait for impact; it is consumed the moment it is reached in the list.

### Behavior = per-tick rule + coefficients. Rune gives defaults, glyph modifies

**Layered, not overwritten.** Overwriting kills the rune; modifying keeps both alive.

Accelerate is not "make the velocity straight" but **"increase whatever the velocity currently is".**
Accelerate on fire gives a fast arc; on lightning, a longer straight line.

| Coefficient | Rune default (example) | Which glyph touches it |
|---|---|---|
| Initial speed | fire 10 · lightning 40 · water 6 | accelerate |
| Drag | fire 240 · lightning 256 (no decay) | accelerate · pierce |
| Gravity | fire 64 · lightning 0 · water 128 | float |
| Homing force | all 0 | home |
| Spin force | all 0 | spin |

⇒ **Rune = one row of this table. Glyph = a rule that edits that row.** They don't overlap.

### Order lives in "modify" too

```
[accelerate, spread]  → flies fast, lands, 8 bolts there       (the 8 are not fast)
[spread, accelerate]  → lands, 8 bolts, each of them accelerates   ← a different spell
```

---

## Combining numbers — multiplication kills order

Most games combine power as a multiplication chain. **Here that kills the thesis.**

```
spread(×0.5) → blast(×1.2)  =  ×0.6
blast(×1.2) → spread(×0.5)  =  ×0.6      ← identical
```

**Multiplication commutes, which makes order meaningless.**
The current system keeps order alive **structurally, not numerically** — spread creates bolts, blast ends in place.
The moment a formula is introduced, the first question is how to preserve that property.

Ways to combine without killing order:

- **Mix non-commutative operations** — `(x+3)×2 ≠ (x×2)+3`. If glyphs split into add and multiply, order survives numerically
- **Positional rules** — "a modify glyph applies only to the **next** thing". Order *is* the target
- **Structure-only order dependence** — the current approach. Numbers see only the generation

And `src/sim/` **forbids float.** Carry fixed point all the way and divide once at the end —
dividing at each step accumulates truncation and kills small values to 0.
That becomes **"a 4-layer spell is inexplicably weak"**, with no error, visible only in the numbers.

---

## Not decided yet

**Do not force these full** (GDD "build order — skeleton first"). TBD is the normal state.

**Circle**
- ~~The concrete circle list~~ → **decided** ("the circle list — three of them"). **The max layer count is still TBD** —
  the deepest of the three is 2 layers, so `circle-art.md`'s "7-layer problem" simply hasn't been reached
- **What an aiming circle is** — candidates: ① detonates directly at the aimed point ② spread converges instead of scattering ③ range increases
- **Whether trigger timing goes in the circle** — impact / timer / placed. It makes circles interesting at a large complexity cost
- **Cost · cooldown** — the game has no concept of cost at all. This opens a whole new axis
- **What the triangle's sequencing counts** — **how many ticks apart** the three shots leave. Zero is effectively parallel,
  too long reads as "broken". **This value directly sets the size of the explosion below**

**The explosion constraint — the hole narrowed, it didn't close**

```
3 runes parallel × spread each = 3 × 8 = 24 bolts
4 players = 96 — the current cap is 32 (src/sim/sim_tuning.gd)
```

The GDD blocked 8→64 with "only one spread per circle", but **parallel runes walk around it.**
There is one spread, but effectively three circles.

**Triangle being sequential halves this.** The three don't leave **on the same tick**, so impacts scatter,
and scattered impacts scatter the 8 spread bolts too ⇒ the worst case of 24 simultaneous rarely arrives.
**But it doesn't vanish** — three bolts flying abreast into similar walls still gives 24, and what sets that
"similar" is the TBD **sequence interval** above.

And **the unit of "only one per circle" wobbles.** The triangle has **separate glyph slots per rune**, so what is
"one circle" — per slot means all three can hold spread and the full explosion returns; per circle means three runes
with spread on **only one socket.**
**Picking the latter makes the picture lie** — three identical-looking sockets, one of which gets spread.

Candidates: circles with many rune slots can't take spread / pin a total shot cap per circle / widen the sequence interval

**Rune**
- ~~The rune list and count~~ → **decided** ("the rune list — ten of them")
- ~~Opening order~~ → **the first four are decided**: **fire · water · none · lightning** (decided by the user).
  The order of the remaining six (wind · earth · grass · ice · light · dark) is **still TBD**
  **The user overturned the "water later" criterion above** — water went early despite being a coefficient-only bolt
  without its sim. **So the moment water opens it must carry its whole identity on "heavy, drops fast"** (stage-1 table above).
  Until wetness and flow arrive, that is all it has
- **Combination table** — the fusion circle's prerequisite. The GDD has exactly one entry, "water+fire = steam".
  **Ten runes makes the table up to 45 pairs** — the TBD got bigger
- Which runes open to stage 2 (flying as a different kind)

**The starting point of power**
- **The first blast you get is weak** (decided by the user). It is a roguelike, so **power growing** is a premise,
  and the start is below the current value (`rd` 8 in `sim_tuning` = 32px hole radius)
- **How weak, and what it grows along, is TBD** — the same place as "how to combine" above
- **The screen must follow.** `fx_tuning` hand-tuned "flash = hole radius × 2.25" and **no net measures that ratio** ⇒
  lowering `rd` must lower `flash_px` with it. Otherwise **only the hole shrinks while the blast stays**,
  which is the exact shape this repo calls "the signature fake"
- **Weakness is not expressed by size — by color and brightness** (decided by the user).

  ```
  existing axis   gen 0 → gen 1          split smaller by spread     (size)
  new axis        starting spell → grown spell   stronger as it goes  (color · brightness)
  ```

  **Two different axes sharing the size knob become identical on screen** — draw the starting spell small and
  the player has **no way to tell** "a weak spell" from "a fragment split off by spread".
  Color and brightness are an axis the generation table (`FX_SIZES`) doesn't use, so they don't collide, and
  **additive blending means faint really does look faint** (`spell_view._ready()`).

**Glyph**
- **Definitions of condense · deploy** — names only. Start with which of the three (modify/spawn/finish) they belong to
- **Spin's integer cost** — `sin` and `cos` are forbidden, so vectors can't be rotated.
  90°/45° snapping is free but coarse (one revolution in 8 ticks); integer rational approximate rotation works but
  **the length drifts** (it speeds up or dies while spinning). ⇒ Whether spin becomes a glyph at all depends on this cost

**Formulas**
- **The spec list** — how many numbers is a spell's spec. Code has four (`speed` · `rd` · `ignite_r` · `rune_r`) and
  **no damage.** **The reason it was absent (no health) is gone** — `character-damage-minimum` set health 100 and
  base damage 10. **Damage becomes the fifth spec**
- **Who provides the defaults** — the user decided "**rune · glyph · gear can all take part**".
  **How they take part is still undecided**
- **How they combine** — **still TBD.** "Multiplication kills order" above stands unchanged.

  **"Spread raises the generation" did not solve this.** That mechanism preserves order only in **pairs bracketing
  a bolt-spawning glyph** — a combination like `[blast, blast]` where neither spawns is identical reversed,
  and so are two modify glyphs. **And the generation table says nothing about how runes and gear fold in.**

---

## Relationship to the GDD

This write-up overturned two GDD lines, **and the GDD was fixed in the same commit.**

| What the GDD said | Now |
|---|---|
| The circle sets the **firing shape** (straight · spreading · placed) | The circle sets the **frame.** The rune sets the firing shape |
| A glyph's picture varies by rune. **The rule is the same** | True for coefficient-only runes. **For runes that fly as a different kind, the rule differs too** |

**The GDD records only the face visible from the game side and points here for detail.**
Duplicate it and the two docs diverge, and then nobody knows which to trust.
