# Circle art — what is drawn and how

**One line**: a glyph is a **ring that fills a layer**, a rune is **socketed into the circle's rim**, and code draws the rest.

**Implemented**: partial — the round circle's assembly-window art runs. **The triangle circle exists only as art
and is not in code** (`circle_defs.ALL` holds only `CIRCLE_ROUND`) — the skeleton is drawn by `triangle()` in
`tools/pixel/draw_circle.py`, and the two socket glyph rings are in `assets/circle/`
(`docs/plans/3.done/triangle-circle-art.md`). Wiring it into the game is `docs/plans/1.ready/triangle-circle-to-game.md`.
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
