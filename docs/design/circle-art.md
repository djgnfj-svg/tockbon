# Circle art — what is drawn and how

**One line**: a glyph is a **ring that fills a layer**, a rune is **socketed into the circle's rim**, and code draws the rest.

> **The code does not do this, and it never has.** `circle_window._draw_glyph(at, r, id)` draws **a symbol at
> one point** — the band's `seat` — as rays, a filled disc or a hollow diamond, picked from the glyph's
> `kind`. There is no annulus anywhere in `src/`. This doc's first line and `tools/pixel/README.md`'s "cut
> away what falls outside the band" describe **art that was generated but never wired**
> (`assets/circle/socket_glyph_*.png`, made for the triangle circle, referenced by no code).
> **The user confirmed the ring is the intent** ("도넛으로 들어가는거지"), so it is the code that is behind,
> not the doc — but anyone reading either one alone will build the wrong thing.
> ⇒ **A glyph needs two pictures, not one**: the **ring** for the layer band, and a **compact icon** for the
> palette card, where a ring has no room to read as anything. `_draw_palette_item` already calls the same
> `_draw_glyph` as the circle does, and that is exactly the sharing that has to end when rings arrive.

**Implemented**: partial — the round circle's assembly-window art runs. **The triangle circle exists only as art
and is not in code** (`circle_defs.ALL` holds only `CIRCLE_ROUND`) — the skeleton is drawn by `triangle()` in
`tools/pixel/draw_circle.py`, and the two socket glyph rings are in `assets/circle/`
(`docs/plans/3.done/triangle-circle-art.md`). Wiring it into the game is `docs/plans/3.done/triangle-circle-to-game.md`.
**Accepted**: partial pass (2026-08-05) — style, size and layout were picked by the user from real candidates on screen.
**Adopting the triangle circle is provisional with no user judgment** (the user delegated it: "you decide").
**Band 48 collides with "the meaning is readable"** — must match the [README.md](README.md) table.

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).
What the three axes hold is in `circle-rune-glyph.md`; the game-wide source is `../GDD.md`.

**Every size here came out of the code and this doc is a copy.** If they diverge, the code is right
(`fx_tuning.CIRCLE_*` · `circle_layout.gd`). Measured headless.

---

## What the user decided by eye

All of it was judged **by generating real candidates and looking at them.** None of it was decided in words.

### Style — black geometry on cream paper

The reference was "white background · black geometric shapes", and the user chose
**flipping the assembly window to bright paper.**

> **The flip never happened in code, and that is a live trap.** `fx_tuning.WINDOW_BG` is
> `(0.05, 0.055, 0.085)` and `BOOK_PAGE` is `(0.12, 0.13, 0.18)` — **a dark navy window**, exactly as before
> the decision. Every sigil this repo generates comes off the `sigil` preset on **cream paper with black line
> art**, so **laying today's art onto today's window paints black on near-black and nothing appears.**
> ⇒ Whoever wires sigil art into `circle_window` **flips those two colors in the same change**, or the art is
> invisible and the failure looks like "the texture did not load".

**Record the price exactly: the color axis of `fx_tuning.GLYPH_TINT` dies.**
`modulate` is multiplication, so **black × any color = black.** That table currently carries **glyph order**
as spread=cyan · blast=orange, and it is the place the GDD pins with "if order isn't visible on screen the
player never learns the rule". ⇒ **Another axis must carry order** (shape · weight · layer number). **TBD.**

**The game-side screen (bolts, muzzle) doesn't break** — `ELEM_FX` holds those colors separately.

### The circle is simple — glyphs carry the ornament (the user decided by eye)

Three circles were generated as boards packed with pattern, and the judgment was
**"way too ornate. I'm the one who adds glyphs to make it ornate. Make it simple."**

**The reason is structural. An ornate circle leaves nowhere to put glyphs.**

```
the circle's band is already full of pattern  →  a glyph ring goes on top  →  buried, invisible
                                                                        ↓
                          the GDD's "if order isn't visible the rule is never learned" dies
```

⇒ **The circle is a frame that hands over empty bands.** The outer ring, the layer-band divider lines and the
socket rims are the circle, and **the insides of the bands are left empty.** Glyphs fill that space; runes fill the sockets.

**This is exactly the same statement as "circle = vessel"** (`circle-rune-glyph.md`). A vessel covered in pattern
hides what it holds — the design's division of labor bites in the art too.

**And this is not "plain".** What the user sees in the assembly window is not the circle alone but
**circle + glyphs + runes combined**, and the ornament comes from there. Do not judge the circle alone.

**A trap when generating**: words like `ornate` or `bands of repeating pattern` in a preset make
**circle, rune and glyph all ornate at once.** A preset carries only **texture** (line weight · ground · monochrome · flat);
**density comes from the prompt** — the `sigil` preset comment in `gen.py` says the same thing.

### A glyph is a ring — not a dot attached to a layer

**Before**: one 31px symbol sat at 12 o'clock on the layer ring (`circle_layout.layer_slots`).
**After**: **the glyph is the layer.** Pattern fills the whole band.

```
   as a dot               as a ring
  ◯──•  ← symbol        ▓▓▓▓  ← pattern fills the layer-2 band
  ◯──•                  ▓▓▓▓  ← layer-1 band
     ●  rune               ●
```

**The value of this change is size.** Geometric pattern **cannot fit in 31px in principle** — the reference's
thin lines, teeth and small dots all mush. As a ring it became 112px and 224px.

**The inner-hole ratio differs per layer.** Layer k's band is `[zone·(k-1)/n, zone·k/n]`, so the hole ratio is
**layer 1: 0 · layer 2: 1/2 · layer 3: 2/3 · layer 4: 3/4.**
⇒ **Slapping one donut png on directly goes wrong from layer 3.** Scale it to the outer radius, then
**mask away everything outside the band.** It happens to work at layer 2, so **building against layer 2 alone fails silently.**

### Glyphs must be **intuitive and geometric** (decided by the user)

**Eight socket-ring candidates were shown on the circle and the user rejected both rounds** — "let's generate
more intuitively" · "the base rule for glyphs is that they must be intuitive and geometric".

**The rejection was about kind, not quality.** All eight were **decorative bands** — zigzag, herringbone, rosette.
Texture and spec were right, but **what they mean is not in the picture.**

```
decorative band     pretty pattern. No meaning        ⇒ rejected
meaningful pattern  a point splits / bursts           ⇒ this
```

**This pairs with "the circle is simple" above.** The reason the circle hands over empty bands is
**so the glyph can carry the ornament**, and a decorative glyph takes that space and **says nothing.**

**And this is the same place as the GDD thesis** — "if order isn't visible on screen the player never learns the rule".
**Spread-then-blast** and **blast-then-spread** are different spells, and if the two rings are
"dense band A" and "dense band B", looking at the order **reads nothing.**
⇒ **The acceptance check "are the six glyphs distinguishable" (below) is not about taste but about whether the rule can be learned.**

**⇒ Two things to hold when generating:**

| Axis | Meaning |
|---|---|
| **Intuitive** | The pattern shows that glyph's **verb** — spread splits, blast bursts from one point |
| **Geometric** | Straight lines · triangles · circles only. Not organic curves, flowers or leaves |

**At a circumference of 288, the repeat count must be low for meaning to read.** "One third the circumference,
one third the repeats" (below) gains a second reason here — dense means **meaning disappears before mushing does.**

#### Rarity rides the verb — **branch count, not colour and not repeat count**

The user asked for one more thing of the same art: **"심플하고 기하학적이면 되고 등급을 표현할 수 있어야 함"**.
`glyph_defs` has carried three tiers since Stage A (`RARITY_COMMON` · `RARITY_RARE` · `RARITY_UNIQUE`, folded
into the id rather than sitting beside it), and **no picture has ever said which one you are looking at.**

**Two obvious devices are already dead here, both for reasons this doc records above:**

| Device | Why it cannot carry rarity |
|---|---|
| **Colour** | The style is black line art and `modulate` is multiplication, so **black × any colour = black.** That is the exact price recorded under "Style — black geometry on cream paper", and `GLYPH_TINT` already lost the order axis to it |
| **Repeat count** | "Dense means meaning disappears before mushing does" — measured, directly above. Turning the tier up would turn the verb off |
| **A ring around the symbol** (`RARITY_RING_RATIO`, in code today) | It works for a **point symbol** and has nowhere to go when the glyph *is* the band. Kept for the palette icon |

**Branch count was tried first and it failed — measured, 24 images.** The idea was that tier and meaning would
become one statement: a rarer spread splits further, which is what a rarer spread *does*. Three prompts per
family asked for 2 / 3 / 4 branches on an otherwise identical motif.

**The generator cannot count.** Asked for three branches it returned 5, 8 and 10; asked for four it returned
sparser rings than the three-branch batch. The dummy tiers came back with rare **denser** than unique. Across
all six sheets **no pair reads as "the same glyph, one tier up" — they read as different glyphs**, which is
the one thing rarity art must not do.

⇒ **Rarity is drawn by code, not generated.** The glyph art is **one ring per family**, and the tier is
**how many thin rims the code strokes outside that ring**: common **0**, rare **1**, unique **2**.

**This follows a line this doc already drew.** "Circles are not AI-generated. Code draws them" — four rounds
of generation never produced "a few circles with no ornament", and `tools/pixel/draw_circle.py` solved it by
treating a frame as coordinates. **A rarity marker is the same kind of object**: a count that must be exactly
right, which is what a generator is worst at and a `draw_arc` is perfect at.

What it buys:

- **Nine ring images become three.** The tiers were 3 families x 3 rarities
- **The count is exact and countable on screen** — the whole point of the marker
- **A fourth tier costs nothing.** No regeneration, one more rim
- `RARITY_RING_RATIO` / `RARITY_RING_PX` already exist in `fx_tuning` (drawn by `circle_window._draw_glyph`
  around the point symbol). **The axis is already standing** — it moves from around a symbol to around a band

**The repeat count stays at 6 and the motif never changes with tier.** That is what makes the rims read as a
tier marker rather than as part of the drawing.

**The common three are generated and unwired; the rims are not built.** And "are the six glyphs
distinguishable" is still the harder unresolved question — it is about six *different* glyphs, not six tiers.

### What is on disk now — **ten files, wired to nothing**

Generated with the `sigil` preset (runes, rings, icons) and `ui` (the window). **Not one of them is
referenced by `src/`** — `circle_window` still draws every symbol with `draw_line`/`draw_circle`.

| File | Size | Seed | What it is |
|---|---|---|---|
| `assets/circle/ring_spread.png` | 288 | 920739551 | Layer band — a line splitting outward |
| `assets/circle/ring_blast.png` | 288 | 1115184869 | Layer band — solid triangles under an arc |
| `assets/circle/ring_dummy.png` | 288 | 473623256 | Layer band — nested chevrons |
| `assets/circle/ring_home.png` | 288 | 1872325933 | Layer band — arrows curving inward |
| `assets/circle/ring_accel.png` | 288 | 1402305408 | Layer band — bars of rising length. **See the collision below** |
| `assets/circle/rune_fire.png` | 192 | 26135034 | Rune symbol |
| `assets/circle/rune_water.png` | 192 | 1541712370 | Rune symbol |
| `assets/circle/rune_none.png` | 192 | 1151264701 | Rune symbol |
| `assets/circle/icon_spread.png` | 112 | 311500430 | **Palette card** — the compact form |
| `assets/circle/icon_blast.png` | 112 | 714128543 | Palette card |
| `assets/circle/icon_dummy.png` | 112 | 955575429 | Palette card |
| `assets/ui/assembly_window.png` | 864x376 | 759337731 | The open grimoire |

**288 / 192 / 112 come from the repo, not from taste**: the triangle circle's socket is `socket_r`=144 (×2 =
288), the rune symbol space is the 192 in `192 + 48×2 = 288`, and 112 is the round circle's layer-1 size.

**Every sigil is keyed to ink-on-alpha by `tools/pixel/ink.py`** — one flat colour `(26,24,22)` and the whole
drawing in the alpha channel. That is not a new convention: the shipped `socket_glyph_*.png` were measured and
they are built exactly that way. It is what lets the art sit on a window whose colour has not been decided
yet (see the dark-navy trap at the top of this doc).

**The icons exist because a ring cannot be a palette card.** `_draw_palette_item` currently calls the same
`_draw_glyph` the circle does; when rings land, that sharing has to end — the ring goes in the band, the icon
goes on the card.

**Only `home` and `accelerate` were drawn beyond the three in code, and eleven glyphs were deliberately left
blank.** `circle-rune-glyph.md`'s table marks those eleven "name only" — drawing a picture for a name makes the
picture invent the meaning, which is exactly what `monsters.md` recorded going stale ("the GDD left kinds and
behavior entirely undecided. Generate now and it goes stale"). These two have a documented behaviour and both
are `modify`, so they have a shape to belong to.

**⚠ `ring_accel` collides with `ring_spread` and it is not fixed.** Both read as "strokes reaching outward" —
spread's split into branches and accel's are parallel bars of rising length, and **at a 48px band that
difference is thinner than the one this doc calls the whole point.** It shipped anyway because accel has no
code and nothing depends on telling them apart yet. **The day accel enters the pipeline, one of the two gets
redrawn** — this is the "are the six glyphs distinguishable" question arriving early, on a pair.

**Seeds are recorded here because `tools/pixel/out/` is gitignored.** `monsters-bigger-boxes.md` §2 wrote up
what it costs when they are not: the four monster seeds survive only in filenames on one machine, and
regenerating means the user re-picks art they already approved. **A seed still does not reproduce the same
image at a different resolution** — these are all generated at 1024 and downsampled by `ink.py`.

#### But this rule collides head-on with the socket band of 48 (measured)

**The price was paid the same day.** Generating spread and blast rings, the band thickness was pushed both ways:

```
thicker band  →  meaning reads              →  inner hole 55–75   intrudes on the rune's 96
thinner band  →  inner hole 92–106 (spec)   →  wedges become tick marks and the burst becomes a dot
```

**The board forced with "thin outer rim" matched spec best and read worst.**
Side by side it loses at a glance — the moment the pattern shortens radially, **the verb disappears and it becomes decoration.**

**⇒ The equation `192 + 48×2 = 288` kept rune assets to one set, and the price was billed here.**
"Glyphs carry the ornament" and "one set of rune symbols" **fight over the same 48.**

**Unresolved.** **Meaning was chosen provisionally** (intrusion r=72–75).
It reads fine overlapped on the fire rune (line art) but **was never measured on a complex rune.** Three paths:

- Enlarge the socket — `368 + 144 = 512` leaves **zero margin.** The socket center must pull inward and the circle shrinks
- Draw rune symbols smaller — **assets become two sets.** Gives back what the equation bought
- **Accept glyph-over-rune overlap as design** — the path taken provisionally

**The measuring tool exists** — `tools/pixel/try_socket.py` gives a candidate's inner-hole radius as a number.
Ask "does it intrude" by value, not by eye.

### Runes socket into the rim — not the center

All four references had that structure (small circles socketed around a large one, protruding outward),
**and measuring found the reason.**

| Rune slots | Gathered at center | **Socketed into the rim** |
|---|---|---|
| 1 | 85px diameter | 112px |
| 4 | 61px diameter | 112px |
| **8** | **34px** — unrecognizable | **112px** |

**Because the budget is different.** The center shares **area**; the rim shares **circumference.**
Circumference `2π×250 = 1571px`, so even at 8 there is 196px each.

`circle_layout.rune_slots()` currently **barks and returns an empty array when `rune_slots != 1`.**
This layout goes there.

### The fusion circle's face — taiji was dropped

**Adopted: `../mockups/fusion-circle-ref.png`** (user judgment: "adopt #3").

```
thick outer ring        the circle's rim
repeating diamond band  glyph layer — **there is only one**
2 rune medallions       rune slots. Upper left and right
curves flowing inward   fusion itself. Fixed ornament on the circle; it does not change with the combination
```

**Taiji was generated many times and rejected every time.** The judgment was "the taiji pattern keeps being no good".
What was dropped is taiji, **not the fusion circle** — two runes merging is said instead by curves converging inward.

**Having one layer matches "1 shared layer"** (the user's phrasing). Runes don't get separate layers; after merging
they pass through **one shared** layer ⇒ `circle_layout`'s layer axis needs no change and
**only the rune slot count opens from 1 to 2.** In exchange, **giving different glyphs per rune becomes impossible.**

### The three circles' faces — adopted by the user, by eye

Candidates were generated at three extremes (ornate → too simple → middle) and judged on the last board.

| Circle | Judgment | File |
|---|---|---|
| **Basic** | **Simple, no ornament** | **TBD** |
| **Fusion** | **No ornament, just a circle** — the downward curves were removed | **TBD** |
| **Triangle** | ✅ **Settled** ("#4 came out great, going with this") | `../mockups/triangle-circle-adopted.png` |

### Circles are not AI-generated. Code draws them

**Four AI rounds never produced "a few circles with no ornament".** Every result differed and none matched spec.
The user's judgment was **"just a circle. You just need layers I can put glyphs into."**

**A frame is coordinates, not a picture.** `tools/pixel/draw_circle.py` draws it ⇒
- The spec (368 · 288 · 192) **matches exactly as numbers.** The generate-then-measure step disappears
- **Change the layer count and the divider lines follow.** Adding a new circle needs no regeneration
- Weight and radius are **arguments**, so tuning is instant

**What still needs AI is pattern** — glyph rings and rune symbols. Those can't be drawn from coordinates.
⇒ The `sigil` preset and "seeds match texture" below apply **only to those two.**

### The triangle circle's settled parameters — these values *are* the picture

```python
triangle(socket_r=144, band_gap=48, dist=368, center_r=112, link_half=26, ring_r=420)
```

**`band_gap` went 34 → 48 (decided by the user).**
Not for composition but for **the equation** — this was a debt and it is paid.

| Argument | Value | Meaning |
|---|---|---|
| `dist` | **368** | Socket center's distance from the circle's center |
| `socket_r` | **144** | Socket radius (diameter 288) |
| `band_gap` | **48** | Socket's glyph band thickness. **It was 34** |
| `ring_r` | **420** | Enclosing outer ring. **Sockets break through it** |
| `center_r` | **112** | Center ornament radius |
| `link_half` | **26** | Half-width of the two-line band joining sockets |

**Draw sockets after the ring.** Reverse the order and the ring passes over the sockets,
turning "breaking through" into "overlapping".

**What the debt was**: `192 + 48×2 = 288` from "the triangle circle — a separate spec table" was the grounds for
keeping rune symbol assets **in one set** with the round circle, but at 34 the rune symbol space is
**288 − 68 = 220**, not 192. **Left alone, rune assets would have become two sets (ten → twenty images).**

**By eye it is only a slightly thicker band.** So it was not "a decision that changes composition" but
**"a decision that restores the equation"**, and the user was asked on those terms.
**The point is that it was decided before generating** — change it after and you regenerate that many images.

**Record the price of removing fusion's curves.** Those curves were the only thing saying "two runes merge into one"
as a picture (they were what got chosen over taiji).
⇒ **The three circles now differ in exactly one way: how many sockets.**

**Socket count does distinguish them** (1 · 2 · 3). What became invisible is not the count but
**how they combine** — fusion vs sequential is not in the picture.
**The same category of debt as deciding not to show the triangle's order**
(`circle-rune-glyph.md`, "the picture doesn't state the order"). If "I can't tell the fusion circle from the
triangle circle" comes up, this is the cause.

### The triangle circle's face — sockets are the vertices

**Reference: `../mockups/triangle-circle-ref.png`** (picked by the user).
**Adopted: `../mockups/triangle-circle-adopted.png`** (user judgment: "triangle goes with #4").

```
        (◉) #1           Three sockets at equilateral vertices. △ layout = 12 · 4 · 8 o'clock
         ╱╲              Each ◉ is "rune symbol + that rune's glyph band"
        ╱  ╲
       ╱ ◎  ╲            ◎ the center is **ornament. Not a glyph**
      ╱      ╲
   #3(◉)────(◉) #2       Sockets join by straight lines; an outer arc wraps all three
```

**The decisive difference from the fusion circle: the socket isn't set into the circle — the socket *is* the outline.**
So the silhouette is not a circle but a **rounded triangle**, and "the difference is the picture inside the ring,
not the ring itself" (above) **breaks only for the triangle circle.** Broken knowingly — it is called the triangle
circle, and a non-triangular shape would make the name lie.

**Glyphs attaching to sockets is the picture of "one layer per rune".** Three runes each carry one glyph, so
there is one band per socket ⇒ **drawing a layer ring in the center would be a false handle.**

**The reference uses a ▽ layout (2 up, 1 down) and must be rotated 180°.**
The reason is **order** — since the clockwise rule is deliberately not shown (`circle-rune-glyph.md`,
"the picture doesn't state the order"), **at least the starting point must be in the picture.**
▽ leaves 12 o'clock empty, so there is no starting point.

**Measured (`triangle-circle-ref.png` measured in pixels)**

```
socket center spacing   634px
circumradius            366px      ← 634 / √3 = 366.0. An equilateral triangle with zero error
socket outer diameter   234px
```

**The reference has an arch ornament at top center, so the silhouette isn't set by sockets alone** (it extends higher).
The spec below was re-derived so **sockets exactly fill the canvas**, leaving no room for that arch —
adding ornament means pulling sockets inward, which shrinks them.

### Assembled pieces never match a single-piece drawing — a price paid knowingly

The concept was OpenAI drawing **one whole magic circle**, which is why it holds together.
**The game can't use a single piece** — spread→blast and blast→spread must be different pictures, and
swapping runes changes the center. ⇒ **There is no choice but to assemble pieces (circle · rune · glyph ring).**

**So every piece must be as refined as the whole would have been.** The user judged "the glyphs are really ugly",
and comparing with the adopted diamond band shows the gap directly.

**Half the awkwardness was assembly, not art** — cutting a donut into a band **cuts the pattern mid-stroke.**
⇒ Glyph rings must be **drawn at that band thickness from the start**, never cropped.

### Layers are concentric rings — overlapping is the exception

Rotating polygons and **overlapping** them keeps layers from thinning as they multiply (verified up to 7 layers in practice).
**But the user did not choose that path** — layers are multiple concentric rings,
**overlapping is capped at 2** and applies **only to specific glyph pairs.**

⇒ **Leave the code open and don't build it now.**
Which leaves **the "7-layer problem" below unsolved.** Overlapping could have been its answer.

### UI — anything that changes doesn't go in the art

| | What | Why |
|---|---|---|
| **Art** | Paper ground · outer border | Never changes |
| **Code** | Tabs · item cells · selection border · masks · slots | **The count changes and they take clicks** |
| **Art** | Circles · runes · glyphs | The list is fixed. This is the real content |

**Find a rune in the dungeon and the item count grows.** Four cells baked into the art makes the art a lie
the day you get a fifth. Half the reason the user called the first UI generations "all bad" is this —
the cards were baked into the art.

### Two slots, toggled by buttons at the top

The GDD's "there are exactly two equip slots, 1 and 2" **was confirmed as-is.**
Two slot buttons sit at the top of the assembly window with the active one marked.

**The toggle key is TBD.** Left click is already taken by **firing** (GDD).

---

## What is being drawn now — the list the user settled

| Axis | To draw | Already in code |
|---|---|---|
| Circle | **basic** (just a circle) · **fusion** (2 rune slots · 1 shared layer) · **triangle** (3 rune slots · 1 layer per rune) | basic only (`circle_defs`) |
| Rune | **fire** · **none** | both (`ELEM_FIRE` · `ELEM_NONE`) |
| Glyph | **spread** · **blast** | both (`GLYPH_SPREAD` · `GLYPH_BLAST`) |

**The triangle circle joined this list.** That there are three circles and their rune slots and layers is set by
`circle-rune-glyph.md`'s "the circle list" — this doc holds **only the art.**

**This is a "list to draw", not "the rune list".** The full rune list (ten) is set by `circle-rune-glyph.md` —
duplicating it here makes them diverge.
⇒ **Only two need art right now**; the rest get drawn when their turn comes.

**The user set the shapes too**: fire rune = **hourglass** · none = **diamond.**
It is monochrome, so **elements are not separated by color** — shape alone must do it.

---

## Asset spec — file sizes are pinned

**Generating first and forcing a fit kept going wrong.** Set the spec first and **generate at that size directly.**

### Round circles — basic · fusion

```
                asset source   game screen (÷2)
circle           1024           512
glyph ring        896            448
rune symbol       192             96
```

**All divide by 2** — exactly half in game, so Nearest doesn't mush them.

**Positions inside the circle** (radius 512 basis):

| What | Radius |
|---|---|
| Outer ring | 512 |
| Glyph band **outer** | **448** ← an 896px glyph ring maps 1:1 here |
| Glyph band inner | 384 |
| Rune socket | diameter **192**, center on radius 240 |

These came from **measuring the adopted board (v2_c) in pixels** (band 386–454 · socket radius 92).
The numbers were not invented; they came out of the chosen picture.

### The triangle circle — a separate spec table

```
                asset source   game screen (÷2)
circle           1024           512      ← same
rune symbol       192             96      ← **same. The asset is reused**
socket glyph ring 288            144      ← new spec
center ornament   288            144      ← new spec
```

**Positions inside the circle** (radius 512 basis):

| What | Value |
|---|---|
| Socket center | on radius **368** — **12 · 4 · 8 o'clock** |
| Socket diameter | **288** |
| Socket glyph band thickness | **48** |
| Rune symbol | diameter **192** (= 288 − 48×2) |
| Center ornament | diameter **288**, at the circle's center |

**Two equations are the whole table:**

```
368 + 144 = 512        the socket exactly fills the canvas — no room to clip
192 + 48×2 = 288       rune symbols stay one set with the round circle
```

**The second was bought expensively.** Ten runes means ten symbols; drawing triangle-specific ones makes it **twenty.**
Set the socket diameter to anything but 288 and it becomes two sets the same instant.

**These are not the reference's values.** The reference has socket diameter 234 and center radius 366
(on a 483 circumradius); moving to a 512 canvas, **they were re-derived so the two equations hold.**
The ratios are close (reference 366/117 = 3.13, here 368/144 = 2.56 — the socket is **slightly larger** than the reference).
The second equation is why the socket grew — at 234, fitting a 192 rune symbol leaves only **21px** of band.

### Glyph rings now come in two sets per glyph

| Where | Diameter | Circumference | Band thickness |
|---|---|---|---|
| Round circle's layer band | 896 | 2,815px | 64 |
| Triangle circle's socket band | **288** | **905px** | **48** |

**One third the circumference means roughly one third the pattern repeats.** Drawn at the same density the
triangle version is packed and mushes — generating "same glyph, same pattern" breaks silently here.

**Do not shrink 896 into 288.** Opposite direction from "upscaling mushes" below, same result.
**Generate at 288 directly.**

**Cost**: with spread and blast to draw, that is **four images.** Open all 17 and it is **34.**

### Upscaling mushes — generate at the size you'll use

**Measured**: a glyph ring generated at 448px and stretched to 896px got judged "low pixel" by the user.
Generating **directly at 896px** fixed it. **Upscaling cannot invent pixels that aren't there.**

### A rune is only its symbol — do not draw a rim

**Measured**: runes generated as "rim + symbol" medallions doubled up with the circle's socket rim, and
the user read it as **"the rune has a glyph in it".**
⇒ **The rim belongs to the circle.** A rune file holds nothing but the symbol.

---

## Sizes — measured, headless

```
window 864×372 (viewport)  →  screen 1728×744   ※ 2× scale
circle page 415×326        →  circle diameter 280
```

| What | Viewport px | Screen px | File size |
|---|---|---|---|
| Circle | 280 | 560 | 560 |
| Rune (with rim) | 56 | 112 | 96 |
| Glyph layer 1 (2-layer circle) | 112 | 224 | 112 |
| Glyph layer 2 (2-layer circle) | 224 | 448 | 224 |

**File size = viewport size.** 2× is Nearest integer scaling, so a 32px file appearing at 64px on screen is
normal pixel-art behavior. **Author files at screen size and they overflow their slots.**

### "2× density" is not decided

Drawing the assembly window directly at **screen resolution (1728×744)** instead of the viewport keeps the on-screen
size and doubles the pixel density (glyph 224px · rune 96px · circle 560px). The user saw that and chose "more detailed",
but **code changes follow** — every coordinate from `WINDOW_RECT` down doubles.
**Price**: only the assembly window gets fine pixels while the game world stays coarse.

---

## Texture is matched by the preset, not the seed — overturned by measurement

**This section used to say "generate one whole image and cut it up". Measuring showed the diagnosis was wrong.**

**What it used to say**: generate parts separately and the texture won't match → generate one whole and cut.
The user judged "all bad... nothing like what I wanted", and the cause was identified as **"each part uses a different seed".**
**That much was right.** The conclusion was wrong — **the fix was matching seeds, and it was read as needing one whole image.**

**Measurement ① (seed 777777, five images varying only the prompt)**

```
basic (1 socket) · fusion (2 sockets) · triangle (3 sockets) · glyph ring · fire rune
    → all five came out with the same diamond band, line weight and cream ground
```

**Measurement ② (same prompt, six different seeds)**

```
777777 · 111111 · 424242 · 987654 · 314159 · 555000
    → all six compositions differed; all six textures matched
```

**⇒ Texture is set by the preset's style clause. Not the seed.**
Seed and prompt set **composition**; the preset sets **texture.** Different axes.

**Do not read ① alone as "the seed matches texture"** — ① fixed the seed but **the preset was fixed too.**
② separated them.

### The real reason the previous session failed — each part used a different preset

The presets in `tools/pixel/gen.py` **ask for different pictures:**

| Preset | What its style clause demands |
|---|---|
| `glyph` | flat geometric line art, **bold simple shapes** |
| `frame` (circle) | line art, **concentric rings** |
| `rune` | **pixel art game icon, 16-bit shading** |

**Only the runes were being generated as pixel art.** The texture could never match — no amount of prompt tuning would fix it.

⇒ **Generate circle, rune and glyph all from the single `sigil` preset.** That is the whole of "looks like one set."
The PRESETS comment in `gen.py` already said "hand-writing a style clause per prompt guarantees divergence",
but not that **keeping multiple presets does the same thing.**

**Seeds are not pinned.** Pick whichever composition you like; that choice doesn't affect texture.

### Unresolved — seeds match texture, not composition

Even at the same seed, a **square frame** came attached (triangle circle · rune symbols).
`--negative "picture frame, square border"` doesn't remove it ⇒ **negative can't take it out. The prompt body must state the layout.**

And **the spec doesn't match itself** — socket position and size are only roughly set by the prompt, so
368 · 288 · 192 above must be **measured after generating.**

## Unresolved

### Coordinates now live in two places

Now that code draws circles, `tools/pixel/draw_circle.py` (Python, asset generation) and
`src/view/circle_layout.gd` (game screen) hold **two copies of the same layout.**
Diverge and you get "the asset is right but the game is off", **with no error.**
⇒ Which one is the source is TBD.

### Art for the basic and fusion circles — direction only, no values

**Only the triangle is settled** ("the three circles' faces"). The other two are settled only as far as
**"no ornament, just a circle, only layers to hold glyphs"** and have **not a single number.**

**Code-drawn drafts exist** — `plain()` and `fusion()` in `tools/pixel/draw_circle.py`.
**They are not judged.** Reading "a draft exists" as "it's settled" builds plans on top of it.

**To decide**: layer band width · line weight · socket size and position.
**The basic circle must have two layers** — spread→blast vs blast→spread is **separated by layer**,
and with one layer the two become identical on screen.

**This item was held by `triangle-circle-art.md` and moved here when that doc went to done.**
Art for two of the three circles is **a living problem**, so it belongs here, not in plans.

**And redrawing the fusion circle means redoing the triangle's acceptance check 1** —
the adopted board predates "the circle is simple", so it is stale as a control.

### Band thickness for a 7-layer circle

Layer band thickness = `circle radius × 0.8 ÷ layer count`. At circle radius 280 (screen):

| Layers | Band thickness |
|---|---|
| 2 | 112px |
| 4 | 56px |
| **7** | **32px** — pattern mushes |

**At the current size, 4 layers is the limit.** And **enlarging the circle can't solve it** — the left page is
already full of circle, and holding 7 layers would need 3.5× the size, which is off-window.

Three remaining paths. **TBD**:
- A large circle takes the whole assembly window (the palette gets pushed out)
- Thick tick marks instead of pattern in thin bands — **glyph art then needs two or three sets per layer count**
- **Pin a layer-count ceiling** — `circle-rune-glyph.md`'s "the concrete circle list and max layer count" is that place

### Held — "ornament": a slot outside the rune

User idea: **one more slot outside the rune, holding an extra glyph.**
The diamond markers on the circle's rim are a candidate location.

**Held. Leave the code open and don't build it now.**
When it opens, the question is: **is it a layer.** If it is, it must join the execution order (GDD "inside out");
if not, a new axis appears outside the GDD's contract that "a glyph is one per layer".

### Are six glyphs distinguishable

Spread · condense · blast · home · spin · deploy were generated as rings and laid side by side.
**This is the core of this game** — different order is a different spell, and if the rings look alike,
seeing the order tells you nothing.
**No user judgment yet.**

**Two of them do separate** — on the 288 socket board, **spread (wedges opening outward)** and
**blast (black dot + broken ring)** separate in both form and density. **An agent saw that; it is not a user judgment.**
**And it is only two** — whether six separate has never been measured, and **four more arriving means redoing this check.**

---

## Where the art is generated

`tools/pixel/` — local ComfyUI (FLUX.2 klein). No credits, 6–25 seconds per image.
Usage and traps live in that folder's `README.md`.

**Avoid non-integer downscaling.** 1024 → 560 is 1.83× and breaks lines.
**1120 → 560 (exactly 2×)** doesn't — that was why circles looked jagged.
