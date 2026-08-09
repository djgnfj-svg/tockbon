# Wire the triangle circle into the game — the art exists and the code doesn't know

**Status**: implemented (steps 1~6) · **screen unverified**. See "What landed" below.
**Decision C — whether the sockets show 1 · 2 · 3 — is still the user's and still unanswered**; the code sits
on the default ("they show"). Acceptance 5 has never been looked at.
**One line**: the triangle circle's assets (skeleton · two socket glyph rings) exist, and **the code doesn't know
the triangle circle exists.** Stand up one more circle in `circle_defs` and draw three rune slots with a band per socket.

**Preceding doc**: [../3.done/triangle-circle-art.md](../3.done/triangle-circle-art.md) — generating the assets.
That doc's "Boundary" cut it off in advance with **"art coming out is where this work ends. Wiring it into the game
is a separate doc"**, and **this is that separate doc.**

**Source docs**: `docs/design/circle-art.md` (spec · art) · `docs/design/circle-rune-glyph.md` (the three circles' rules)

---

## Why

**The assets exist and not one pixel appears in the game.** This repo's signature fake is
"screen changes, sim doesn't (or the reverse)" — this is the stage before that: **neither changes.**

And **left long enough the assets go stale.** The spec was measured to 288 · 192 · 368, but until it's attached
**nobody knows whether those values are right on screen** (they were measured only on the asset originals).

---

## What blocks it — measured

| Where | Now | What the triangle circle needs |
|---|---|---|
| `src/sim/circle_defs.gd` | **Only `CIRCLE_ROUND`.** `ALL = [CIRCLE_ROUND]` | Stand up one more circle (`rune_slots` 3) |
| `rune_slots()` in `src/view/circle_layout.gd` | **Barks and returns an empty array when `n != 1`** | Place three at 12, 4 and 8 o'clock |
| Layer axis in the same file | Assumes **layer = concentric ring** | **One band per socket** — not concentric |

**The third is the biggest.** For round circles, "layers grow from the inside out" is in the picture itself
(`circle_layout` comment), but **the triangle scatters layers across three sockets.** ⇒ "Execute from the inside"
can't be expressed as a picture, and **clockwise order takes that job instead.**

The bark in `circle_layout.gd` was **planted deliberately** ("add a circle without deciding how runes lay out and
the wrapper's stderr check catches it for free"). ⇒ **Removing that bark is not this work's first line.**
Remove it after deciding the layout.

---

## To decide — **before any code**

**Carried straight over from the preceding doc. Unresolved, it can't be written.**

### ① The unit of spread's "only one per magic circle"

The triangle has **separate glyph slots per rune**, so what "one magic circle" means wobbles.

| If you pick | Result |
|---|---|
| One per slot | Three spreads ⇒ **24 bolts.** Hits the current cap of 32 |
| One per circle | **The picture lies** — three identical-looking sockets and only one gets spread |

### ② The triangle's sequence interval

**How many ticks apart** the three shots leave. Zero is effectively parallel; long reads as "broken".
**This value directly sets the size of ①'s explosion** — scattered impacts mean 24 bolts never coexist.

### ③ How the clockwise order gets taught

**The picture deliberately doesn't show order** (user decision). Two safeguards remain, the **12 o'clock socket**
and **onboarding**, and whether it goes into onboarding is undecided.

**The preceding doc's acceptance check 2 half-failed here** — beyond a socket at 12 o'clock there is no clue,
and **the three sockets look identical.** ⇒ "12 o'clock is #1" exists **as a rule, not as a picture.**
The GDD's "if order isn't visible on screen the player never learns the rule" is exactly this place.

---

## Look at again alongside — the 48 socket band

**An unresolved item the preceding doc handed over provisionally.** The box under "glyphs must be intuitive and
geometric" in `docs/design/circle-art.md` is the source.

```
thicker band  →  meaning reads          →  inner hole 72–75, intrudes on the rune's 96
thinner band  →  inner hole meets spec  →  the pattern becomes tick marks and the meaning is gone
```

The current asset is on the **intruding** side. **Verified only on the fire rune (line art)** — attached to the game,
**overlap with other runes becomes visible for the first time.** That is when to judge again.

**Game size 144 was measured in the preceding doc** — the two separate **even at 144.**
But **the hatching inside spread's wedges becomes a grey smudge** — the meaning survives, the texture dies.
**That rule comes first when generating the next 15 glyphs**: bold forms carry the meaning, and
**hatching, thin parallel lines and fine dots cannot travel.**

---

## Boundary

**Not doing**:
- Art for the basic and fusion circles — left in `docs/design/circle-art.md`, "Unresolved"
- 288 boards for the remaining 15 glyphs
- How circles are obtained (drops · shop) — no doc in the GDD

---

## Acceptance — what must be seen to call it done

1. **Is the triangle circle selectable and drawn in the assembly window** — three sockets · starting at 12 o'clock
2. **Do three runes each go into a socket**
3. **Does a glyph attach only to that rune's socket band** — attaching at the center means "one layer per rune" broke
4. **Do three shots go out when firing** — at the interval from ② above
5. **Do the two glyphs separate on the real screen** — at the asset stage this was checked by shrinking to 144.
   What is newly measured here is whether they separate **after circle, rune and glyph overlap**

---

## TBD — not its turn yet

**Do not force these full** (GDD "skeleton first").

- What the center ornament means — its size is set (radius 112). **It is not a glyph**
- Coordinates live in two places — `tools/pixel/draw_circle.py` (assets) and `src/view/circle_layout.gd` (game).
  Diverge and you get "the asset is right but the game is off", **with no error**.
  **The plan below narrows this, it does not close it** — step 2 moves the game side to the **same 512-basis
  integers** (368 · 144 · 48 · 420 · 112 · 26) so the two files can be diffed line by line, and a net drives
  the two equations. Which file is the source is still TBD

---

# Implementation plan

**Read `docs/design/circle-art.md` "the triangle circle's settled parameters" beside this.** Every number below
is that table divided by 512; nothing new was invented.

## Answers to the three questions this doc left open

### What `circle_layout.gd` actually assumes — measured, with line numbers

| Line | What it pins |
|---|---|
| `circle_layout.gd:73-84` | `rune_slots()` barks on `n != 1` and returns **empty**. `n <= 0` returns empty **quietly** |
| `circle_layout.gd:83` | The single rune seat is `_center(area)` — **dead center**, and the comment hangs "layers wrap around the rune, so inner-comes-first is in the picture" on exactly that |
| `circle_layout.gd:98-106` | `layer_rings()` returns **`PackedFloat32Array` of radii**. That return type *is* the concentric assumption — a radius with no center only means something when every layer shares one center |
| `circle_layout.gd:111-117` | `layer_slots()` = `_center + (0, -r)`. One shared center, one shared angle (12 o'clock) |
| `circle_layout.gd:132-138` | `layer_at()` is a **point-distance** test around the 12 o'clock dot |
| `circle_layout.gd:167-172` | `_center` · `_radius` — the shared disc. The file's own comment says sharing these **is not** mixing the axes |

**And two more barks the doc did not list, both of which fire the moment the triangle is equipped:**

- `src/actor/spell_circle.gd:243-247` — `element()` barks on `_runes.size() != 1` and returns `ELEM_FIRE`.
  `stage._fire_at` (`stage.gd:465`) calls it **on every left click** ⇒ ordinary play turns the wrapper red
- `circle_window.gd:357-373` — `_draw_rune_slot` calls `Layout.rune_slots()` **60 times a second**, so the
  `n != 1` bark floods at 60 lines/s. Its own comment already names this ("whoever grows the runes must move
  the bark out of the frame **then**")

### Where the socket band lives — the option taken, and the ones rejected

**This is not a user decision. It is invisible on screen** — every option below draws the same picture.
What *is* a user decision is item **C** below (the layer numbers), and the user cannot judge that without a
screen either, which is why step 4 puts the triangle on screen with the procedural symbol **before** asking.

| Option | Cost | |
|---|---|---|
| **1. A `picture` column in `circle_defs`; `circle_layout` holds one row per picture** | 3 files to add a picture (`circle_defs` · `circle_layout` · `fx_tuning`), **1 file to add a circle that reuses a picture** | **taken** |
| 2. Derive the arrangement from `rune_slots` count (1 → center, 3 → triangle) | 2 files. But `rune_slots()`'s own comment (`:70-71`) says this is exactly what cannot be derived — **fusion's two seats interlock, a parallel two-slot circle's sit apart**, same count, different picture. And "three is not the end" is a user decision (`circle-rune-glyph.md`) | rejected |
| 3. A separate `triangle_layout.gd` chosen by the window | The window picks a module in **both** `_draw` and `_click_circle` ⇒ 4+ files per new picture, and "the single source drawing and clicking share" now has to be re-proved per module | rejected — over the file-count contract |

**Why one `picture` column and not two.** The obvious split — `rune_layout` × `layer_layout` — is real:
the **fusion** circle is `2 sockets + 1 shared concentric layer` (`circle-art.md`: "only the rune slot count
opens from 1 to 2"), so the rune arrangement and the layer arrangement genuinely vary independently. But that
is two columns that must agree, and the thing they both describe is one thing the design already named —
**"the rune-slot layout is the circle's picture"** (`circle-rune-glyph.md`). ⇒ **one column in `circle_defs`,
and `circle_layout` owns the table that expands a picture into (rune placement, layer placement).**
Fusion then arrives as **one more row in that table**, holding `RING` runes + `CONCENTRIC` layers.

**The return shape has to change with it.** `layer_rings() -> PackedFloat32Array` cannot express a band that
is not centered on the circle. It becomes:

```
layer_bands(circle_id, area) -> Array[Dictionary]
    center  Vector2            the band's own center (circle center · or socket i)
    edges   PackedFloat32Array radii to stroke.  concentric: [outer]   socket: [outer, inner]
    seat    Vector2            where the glyph symbol / texture is anchored
    hit     Vector2            (inner, outer) of the clickable region, measured from `center`
```

**`edges` is what removes the branch from the drawing.** Concentric layers **tile the radius** — layer k's inner
edge *is* layer k−1's outer edge, so stroking outer edges only draws the complete picture. Socket bands are
**standalone annuli** and own both edges. Handing the view a list of edges to stroke lets `_draw_ring` loop it
and never ask which picture it is in.

### Do 288 · 192 · 368 hold on screen — **computed here, confirmed at step 4**

Computed from the code, not from the doc: `circle_page(WINDOW_RECT.size)` → `circle_area` (`pad 14`) →
`_radius = min(w,h) * 0.5 * 0.94`. `circle-art.md`'s measured page 415×326 gives **frame radius 140.1
viewport px** (diameter 280.2 — it matches that doc's measured 280, so the chain is right).

```
socket diameter  = 288/512 * 140.1 * 2  =  78.8 viewport px  =  157.6 screen px  (2x Nearest)
band thickness   =  48/512 * 140.1      =  13.1 viewport px  =   26.3 screen px
rune symbol dia  = 192/512 * 140.1 * 2  =  52.5 viewport px  =  105.1 screen px
```

**The spec expects the socket glyph ring at 144 screen px and it lands at ~158** — 10% larger, so
`triangle-circle-art.md`'s "measured at game size 144: the two still separate, but hatching inside spread's
wedges becomes a grey smudge" **carries over unchanged.** ⇒ There is no size surprise waiting; there is a
**known** texture loss, and it is `circle-art.md`'s problem (next 15 glyphs), not this doc's.

**These are computed, not seen.** Step 2's net pins the ratio chain by driving it; step 4 is the first time
anyone looks. What a net can never answer is acceptance 5, so that stays verify-look's.

---

## To decide — put in front of the user at step 4, not before

**None of these blocks starting.** Each has a default that is honest on screen and cheap to reverse.

| | Question | Default if unanswered | What reversing costs |
|---|---|---|---|
| **A** | The sequence interval (doc ②) | **6 ticks** between shots, as `seq_ticks` in the circle table | one integer in `circle_defs` |
| **B** | The unit of "one spread per circle" (doc ①) | **per circle** — `spell_circle._list_ok:177-191` already counts the family across the whole `_layers` array, so this costs **zero code**, and `_can_pick` dims the second spread in the palette, so it is **visible, not silent** | `_list_ok` counts per socket instead — one function |
| **C** | **Do the sockets get numbers 1 · 2 · 3** | **They do** — `_draw_ring:395-404` already writes the layer number and doing nothing keeps it | one guard in the view |

**C is the one that needs a real answer.** `circle-rune-glyph.md` records the user's "no indication at all.
The user just plays and learns it" — but that was about **the art**, and the layer number is code-drawn UI the
round circle already has. ⇒ **The default is "the order is shown", which is the opposite of what was decided
for the picture.** It also happens to repair the check the previous doc recorded as failed
(`triangle-circle-art.md` 판정 2: "12 o'clock is #1 exists as a rule, not as a picture").
**Recommend showing them** and reopening `circle-rune-glyph.md`'s "the picture doesn't state the order" with
the distinction written down. The user decides.

**Doc ③ (onboarding) is out of scope** — there is no onboarding system in the repo to put it in.

---

## Steps

**Each step ends green.** Steps 1–3 add the triangle's *capability* while `ALL` still holds one circle, so the
round circle is the control the whole way; step 4 is where the triangle first exists.

### Step 1 — `circle_defs` grows two columns. **No new circle yet**

`src/sim/circle_defs.gd`

- `PIC_ROUND` · `PIC_TRIANGLE` constants, `picture` column on the existing round row, `picture()` accessor
- `seq_ticks` column (round: **0**), `seq_ticks()` accessor. **0 means "all on the same tick"** —
  the round circle's one shot falls straight through it
- **`combine` is not added.** No consumer: fusion is a different mechanism and has no circle yet (CLAUDE.md,
  false handles). `seq_ticks` is what "sequential vs parallel" actually reduces to

**Nets**: `net_circle` pins that every row in `DEFS` has both columns and that both accessors go through
`DEFS[` (the existing `_accessors_read_the_table` idiom). **Invert by returning a constant.**

 **`ACCESSORS` (`net_circle.gd:44`) has to split.** It feeds two different checks — `:361` "does the
accessor read the table" (true for all four) and `:333` "does `circle_layout` call it" (**false for
`seq_ticks`**, which only `spell_circle` calls). Add `seq_ticks` to the one list as it stands and `:333` goes
red for the wrong reason.

### Step 2 — `circle_layout` learns pictures. **The round circle's numbers must not move**

`src/view/circle_layout.gd` · `src/view/fx_tuning.gd` · `src/view/circle_window.gd` · `tests/nets/net_circle.gd`

 **The last two were missing from this list and builder caught it.** Both signature changes below break
callers that live in step 3's and the nets' files, so "every step ends green" is false without them:
`circle_window.gd:362` calls `Layout.rune_radius(area)` and `:387` calls `Layout.layer_rings(...)` and reads
the result as an array of radii; `net_circle` calls both at `:714` `:899` `:913` `:927` `:944` and names them
by string at `:971` `:986`.

**They get a signature-only patch here, not the generalization.** `_draw_rune_slot` gains the argument;
`_draw_ring` takes `layer_bands()` and uses **`edges[0]`** where `rings[layer]` used to be, drawing exactly
one circle as it does today. **`edges` is outermost-first** (`concentric: [outer]` · `socket: [outer, inner]`)
— reaching for the *last* element instead happens to work while every band has one edge and is wrong the
moment step 3's socket band arrives, which is how a diverged duplicate gets planted. Looping `edges` to
stroke several lines is step 3.

- `fx_tuning`: the triangle's **512-basis integers**, not pre-divided ratios —
  `TRI_CANVAS_R := 512` · `TRI_SOCKET_DIST := 368` · `TRI_SOCKET_R := 144` · `TRI_BAND := 48` ·
  `TRI_RING := 420` · `TRI_CENTER_R := 112` · `TRI_LINK_HALF := 26`, and the socket angles
  `TRI_SOCKET_DEG := [-90.0, 30.0, 150.0]` (12 · 4 · 8 o'clock, straight out of `draw_circle.py:128`).
  **Integers so the two equations stay readable and drivable**: `368 + 144 == 512` and `192 + 48*2 == 288`
- `circle_layout`: a private `_socket_centers(area, n)` in **the shared-disc section at the bottom**, beside
  `_center`/`_radius`. Both the rune axis and the layer axis read it, so **neither axis calls the other** —
  the same argument that file already makes for sharing `_center` (`:157-159`)
- `rune_slots()` — branch on `CircleDefs.picture(id)`. `PIC_ROUND` unchanged; `PIC_TRIANGLE` returns the three
  socket centers. **The `n != 1` bark stays** (see step 4)
- `rune_radius()` → **`rune_radius(circle_id, area)`** — `circle_id` **first**, matching every other
  picture-aware function in the file (`rune_slots` · `layer_rings` · `layer_at` · `rune_slot_at`). An
  argument order that disagrees with its neighbours in a file whose whole point is "one source" gets
  mis-called silently. `PIC_TRIANGLE`'s rune seat is `socket_r - band`, not `CIRCLE_RUNE_RATIO`.
  Consumers: `circle_window:362`, `rune_slot_at:144`, `net_circle:714,913,927`
- `layer_rings()` → `layer_bands()` with the shape above. `layer_slots()` returns the `seat` fields
- `layer_at()` / `rune_slot_at()` read `hit` from the band

 **The hit shapes must be disjoint or the triangle's rune seat becomes unreachable.**
`_click_circle` (`circle_window.gd:166-185`) tests **layer first, then rune**. On the triangle both sit at the
same socket center, so:

```
layer hit   annulus [socket_r - band, socket_r]     around the socket center
rune  hit   disc    [0, socket_r - band]            around the same center
```

and **`SLOT_HIT_RATIO` (1.8) must not be applied to either on `PIC_TRIANGLE`** —
`1.8 * (96/512) = 0.3375 > 288/512/2 = 0.28125`, so the inflated rune disc swallows the band and spills past
the socket rim. The ratio exists because the round circle's seats are lonely dots; here they are not.

**Nets** (`net_circle`):

- The round circle's ring radii, layer seats, rune seat and `layer_at`/`rune_slot_at` answers are **pinned to
  their present values**, so the refactor cannot move them. This is the step's whole safety
- `layer_bands` edges are strictly decreasing per band and the outermost ≤ frame radius
- `368 + 144 == TRI_CANVAS_R` and `192 + 48*2 == 288` **driven from the constants**, not grepped
- `_axes_do_not_call_each_other` (`:965-987`) — the case list names `layer_rings` and `_draw_ring` **by
  string**; renaming without updating it makes `_func_body` return `""` and its own `body != ""` guard fires
  red. Good — but it must be **updated, not deleted**, and the "same-axis call stays alive" line at `:986`
  needs retargeting to `layer_bands(`
-  **`net_circle:709-720` is the check that must not be touched beyond the added argument.** It pins the
  round circle's cross-kind geometry — "the drawn rune disc stays outside every layer's hit ring" — which is
  exactly what a refactor of these two functions can move. **If you find yourself loosening a tolerance
  there, stop**: that is the round circle having moved, not the check being wrong
- `circle_layout.gd`'s own three-axis diagram (`:9`) and `layer_slots`'s comment (`:110`) name
  `layer_rings()`. They are comments, but they are **that file's contract diagram** — follow them over or the
  file describes something it no longer has

 **`_layout_reads_the_table` (`:337-345`) forbids any numeric-literal loop in `circle_layout.gd` **and**
`circle_window.gd`** (`for i in 3`, `for i in range(3)`). Iterate `TRI_SOCKET_DEG.size()` or
`CircleDefs.rune_slots(id)` — never `3`.

### Step 3 — `circle_window` draws from the bands. Round circle unchanged on screen

`src/view/circle_window.gd`

- `_draw_ring` drops step 2's `edges[0]` adapter and strokes **every radius in `edges`**, anchors the glyph
  at `seat`. No picture branch
- `_draw_frame` becomes picture-aware — `PIC_TRIANGLE` draws the **wrapping ring at 420/512 of the frame
  radius** (not the full radius: the sockets **punch through** it, a user request recorded in
  `draw_circle.py:123`), the three link bands between socket centers (`link_half 26`), and the **center
  ornament** as two circles at 112 and 112−48. **The ornament is not a glyph seat** and must not get a `+`
- Link bands and the ornament belong to the **circle axis** and read `_socket_centers`, the shared helper —
  **not** `Layout.rune_slots()`. Add that call to `_axes_do_not_call_each_other`'s case list, or the
  coupling lands with nothing barking

**Nets**: text-only here is weak (CLAUDE.md — "a check that greps a file measures its text"). What is drivable:
`_draw_*` need a live font and resist headless, but every **coordinate** they use comes from `circle_layout`
and is already driven by step 2. **Do not write a net that greps `_draw_frame` for `420` and call it measured.**

**Screen only**: that the round circle looks **identical** to before. verify-look, A/B against the current build.

### Step 4 — the triangle exists. **This is where the bark comes out**

`src/sim/circle_defs.gd` · `src/view/circle_layout.gd` · `tests/nets/net_circle.gd`

- One row: `CIRCLE_TRIANGLE: {"name": &"삼각", "layers": 3, "rune_slots": 3, "picture": PIC_TRIANGLE,
  "seq_ticks": 6}`, plus `ALL`
- **Now** delete the `n != 1` bark in `rune_slots()` and replace it with **"unknown picture"** — the free
  stderr catch survives, it just moves onto the axis that actually cannot be derived. `net_circle:947-951`
  greps that function for `push_error` and must be retargeted in the same edit
- `_draw_rune_slot`'s 60-lines-a-second problem dies with the old bark. Nothing more to do

**Why not first**: with no layout the bark is the only thing standing between "a circle was added" and a
window that silently draws nothing. Removing it at step 1 would have made steps 2–3 land **with no net at all**
watching the gap. It comes out the moment its job is done and not one step earlier.

**Nets**: everything in `_layout_geometry_runs` (`:897-925`) now loops **two** circles for free — ring count,
seat count, "all seats inside the frame", "rune slot count matches the table". Two of its lines are
concentric-only and must be split by picture: `:913` "layer 1's ring is outside the rune seat" and the
implicit inside-out growth check at `:902-907`.
Add: the three socket seats are **120° apart**, seat 0 is **directly above** the center (12 o'clock — the only
clue the picture gives), and `dist + socket_r <= frame radius`.

**Screen** (acceptance 1 · 2 · 3): three sockets, one at 12 o'clock; three runes each go into a socket; a glyph
attaches to that socket's band and **not to the center**. Still the procedural symbol — the art is step 6.
**Ask the user about C here.**

### Step 5 — firing. Three shots leave

`src/actor/spell_circle.gd` · `src/actor/world_step.gd` · `src/stage/stage.gd`

- **`shots() -> Array[Dictionary]`** on `SpellCircle` — `{element, glyphs, delay}` per bolt.
  Round: one entry (`element()`, `packed_glyphs()`). Triangle: **three**, entry i carrying `rune_at(i)` and
  `Glyph.pack([glyph_at(i)])` with `delay = i * seq_ticks`. **Each bolt carries only its own socket's glyph** —
  that is what "one layer per rune" means (`circle-rune-glyph.md`)
- `element()`'s `!= 1` bark (`:243-247`) is **removed with it** — `shots()` is now the single answer, and a
  bark that no path can reach is a false handle
- `world_step.enqueue(cmd, delay := 0)` — `:384` hardcodes `tick + 1`. **This gives `_drain_queue`'s `keep`
  branch its first consumer**; that branch's comment at `:387-389` currently reads "a dead branch" and must be
  rewritten in the same edit or it becomes a lie
- `stage._fire_at` (`:458-466`) loops `shots()`. Recoil already hangs off `fire()` returning true inside
  `_drain_queue`, so **three shots means three recoils** — check that this is not read as a malfunction

**Nets** (`net_spell` or `net_circle`): with a triangle equipped, `shots().size() == 3`, delays are
`0 · seq · 2*seq`, each entry's glyph list holds **exactly its own socket's glyph**, and a round circle still
returns exactly one entry identical to today's `element()`/`packed_glyphs()` pair. Then drive `world_step`:
enqueue three delayed commands and assert `_fire_count` reaches 3 **across the right ticks** — a check that
reads only the final count cannot tell a sequence from a burst (CLAUDE.md, ordering contracts).

 **`MAX_PROJECTILES` is 32** (`sim_tuning.gd:500`). Three spreads would be 24 and decision **B**'s default
forbids the second spread, so the ceiling is 8 + 1 + 1 = 10. **If B is reversed, measure the cap** —
over it the sim does not spawn, it does not discard, so the symptom is "some bolts just don't come out".

### Step 6 — the socket glyph art

`src/view/fx_tuning.gd` · `src/view/circle_window.gd`

- `assets/circle/socket_glyph_spread.png` and `..._blast.png` are imported and **nothing in `src/` loads
  them** (verified: no `assets/circle` reference exists in any `.gd`). This step is the first
- A `SOCKET_GLYPH_TEX` map in `fx_tuning`, glyph id → path. **2 of 17 glyphs have art** ⇒ a glyph with no
  entry falls back to the procedural symbol. **It must not draw nothing** — that is the shape of a fake
- Drawn as a `draw_texture_rect` filling the socket's bounding square, **the same `load()`-once idiom as
  `spell_view:228` / `character_view:33`**. Whatever the band's inner hole is, it is **in the art**
  (spread 72, blast 75 — `triangle-circle-art.md`), so the game must not mask it
- **The palette keeps the procedural symbol.** `_draw_palette_item` shares `_draw_glyph` with the slot on
  purpose ("the palette's blast must not look different from the placed blast") — that argument is about the
  **round** circle's slot and still holds there. The socket band is a different seat; say so in the comment
  rather than letting the two silently disagree

**Nets**: the texture files load and are 288×288. Nothing about legibility.

**Screen only** (acceptance 5): whether spread and blast still separate **after circle + rune + glyph
overlap** — never measured before, only on the bare fire rune. And whether the band intruding to r=72–75
eats the rune symbol. This is the one thing this whole plan exists to find out.

---

## Files touched

| File | Why |
|---|---|
| `src/sim/circle_defs.gd` | `picture` · `seq_ticks` columns, accessors, the triangle row |
| `src/view/fx_tuning.gd` | the 512-basis triangle constants; the socket glyph texture map |
| `src/view/circle_layout.gd` | `_socket_centers`; `layer_bands`; picture branches; hit shapes; the bark moves |
| `src/view/circle_window.gd` | draw from `edges`; the triangle skeleton; the socket band texture |
| `src/actor/spell_circle.gd` | `shots()`; `element()`'s bark comes out |
| `src/actor/world_step.gd` | `enqueue` takes a delay; the `keep` branch stops being dead |
| `src/stage/stage.gd` | `_fire_at` loops `shots()` |
| `tests/nets/net_circle.gd` | `ACCESSORS` splits; the picture-specific checks; the retargeted text scans |

**Eight files, and the file-count contract is not broken — the units are different.** The contract asks
**"how many files to add one new kind"**. After this: a circle reusing an existing picture is **1 file**
(`circle_defs`); a circle with a new picture is **3** (`circle_defs` · `circle_layout` · `fx_tuning`).
The eight above are the one-time cost of the first picture ever added, and steps 5 and 6 are capabilities
(sequenced firing, textured glyphs) that the fourth circle pays nothing for.

## Risk

- **The signature fake, in its exact shape.** Ship step 4 without step 5 and the window draws three sockets
  while one bolt leaves. **Do not stop between them.** The reverse also exists: step 5 without step 4 sends
  three commands with nothing on screen to explain them
- **The refactor at step 2 silently moves the round circle.** Every consumer of `layer_rings` and
  `rune_radius` changes shape at once. The defense is pinning the round circle's present numbers *before*
  touching anything, and it is the reason step 2 is its own step
- **Text scans in `net_circle` that will pass by measuring nothing.** `:333` `:364` `:949` `:971` `:986` all
  grep for names this plan renames. `_func_body` returning `""` is guarded in one place (`:981`) and **not in
  the others** — `"".contains(...)` is false, so `:949` goes **red** (safe) but `:986`'s positive check also
  goes red for the wrong reason. Read each one before editing it
- **Barks that fire per frame.** The old `rune_slots` bark at 60 lines/s and `element()`'s per-click bark both
  turn the wrapper red during ordinary play. Both die in this plan; if a step lands between their arrival and
  their removal, the nets are unusable in the meantime
- **`for i in 3` is banned** in both view files by `_layout_reads_the_table` — and the triangle is the first
  feature that genuinely wants to write it
- **Coordinates in two places gets worse, not better.** `draw_circle.py` and `fx_tuning` will both hold
  368 · 144 · 48 · 420 · 112 · 26. Keeping them as **the same integers on the same 512 basis** is the whole
  mitigation; nothing enforces it

## What landed — including **a check that was two `t.ok(true)` lines**

All six steps are in: `circle_defs` grew `picture` · `seq_ticks`, `circle_layout` learned pictures and
`layer_rings()` became `layer_bands()`, the window draws from bands, the triangle stands up, `shots()` fires
**three commands at `seq_ticks` apart**, and the socket glyph textures are attached.

**What the nets were not measuring.** `_draw_actually_runs_headless` was **`t.ok(true, …)` twice** — the whole
magic circle could fail to draw and it stayed green. `stage._fire_at`, the hit shapes, the entirety of step 6
and the triangle's outline were all unguarded as well. Closing those turned up **four real bugs**, all fixed:
`R` recovered socket 0 only; the staff-tip color was wrong for combinations that do not fire; a stale comment;
and a debug key that turned the triangle back into a round circle.

**Not fixed, out of this doc's scope and marked loudly in the code**: `apply_preset` takes a single rune, so
using a preset **flattens sockets 1 and 2 to socket 0's value.**

## Acceptance — **1~4 and 6 measured by nets; the screen half of all of them is still unseen**

This doc's five, plus what each step can prove on its own:

| | What | Who measures it |
|---|---|---|
| 1 | Triangle selectable and drawn — three sockets, one at 12 o'clock | net (seats 120° apart, seat 0 above center) **+** verify-look |
| 2 | Three runes each go into a socket | verify-run — clicking is `Control` work |
| 3 | A glyph attaches **only** to that rune's band, never the center | net (hit shapes disjoint; the ornament is not a seat) **+** verify-look |
| 4 | Three shots leave, at the interval | net (`shots()` delays **and** the ticks they fire on) |
| 5 | Spread and blast still separate after circle + rune + glyph overlap | **verify-look only** |
| 6 | The round circle is unchanged | net (pinned numbers) **+** verify-look A/B |

### What to look at first when the screen finally opens

Three things, all of them known and none of them judged:

1. **Decision C above — do the sockets show 1 · 2 · 3.** The code ships the default ("they show"), so doing
   nothing is itself the answer. **The user decides**, and this is the one item here that is not a bug report
2. **The fallback symbol is drawn on the rune bead, not on the band.** 15 of 17 glyphs have no art and take
   this path, so it is the common case, not the edge one
3. **The socket art overlaps the rune by 6.5px.** Small enough that only the screen says whether it reads as
   "seated in the socket" or as "covering the rune"

## Out of scope

- Art for the basic and fusion circles, and **wiring the fusion circle** — it needs a `RING`+`CONCENTRIC`
  row that this plan makes possible and does not write
- The 288 boards for the remaining 15 glyphs
- Onboarding (doc ③) — no system exists to put it in
- How circles are obtained (drops · shop)
- `circle-art.md`'s "2× density" question — every coordinate below `WINDOW_RECT` would double
- Deciding which of `draw_circle.py` / `fx_tuning` is the source of the layout numbers
