extends RefCounted
## Sim knobs — **integers only.** Every value touching the grid and projectiles lives here.
##
## **One named exception**: a boss pattern's carve/ignite radii (`src/actor/boss_ai.gd`'s `MOVE_CHARGE`,
##  and Stage G's `MOVE_SLAM`) touch the grid too, but live there instead — `stage1-bosses.md`'s own Boundary
##  put boss attacks in `src/actor/` ("bolts have no owner", the same reasoning `monster_bolts.gd` already sets
##  precedent for). Silently breaking this file's opening sentence is worse than naming the one place it doesn't hold.
##
## **Presentation constants are not here.** Those are `src/view/fx_tuning.gd`.
##  v1 kept both in one file split by `SIM-BLOCK-BEGIN/END` text markers, and that file's own comment said
##  "delete or add a marker and the net silently spins". => **Splitting by folder removed the markers entirely.**
##  "Presentation constants in one file" is still held by `fx_tuning.gd`.
##
## This file being inside `src/sim/` puts it in `net_determinism`'s folder scan —
##  not one float, `Vector2`, `sqrt`, trig function, `randi` or `Time.` may appear.

# --- grid <-> screen ------------------------------------------------
## How many screen px one cell is. A GDD-settled value.
## **This is the single source.** Rendering (`src/view/`) and aiming (`src/actor/aim.gd`) both read it —
##  hardcode 4 in each and it only ever looks like "aim is subtly off".
## `src/actor/` cannot preload `src/view/` (`net_layers`), so this constant has to live in `sim`.
const CELL_PX := 4

## Cells per terrain tile side. A 32px tile = 8x8 cells = the same thickness as the character (GDD grid).
## **The cell (`CELL_PX` 4) did not change. What changed is cells per tile side.**
##  The GDD pins "raise cells to 16px and one hole is a passage, mushing power tiers entirely" —
##  that is why the path taken was thickening the tile.
## **Screen scale went 2x -> 1x** (viewport 960x540 -> 1920x1080, window unchanged).
##  => **Any value in cells whose meaning is "this big on screen" must be doubled to preserve the screen.**
##  Judging "the unit is cells, so leave it" halves blasts, bolts and traces on screen — that mistake was made once.
const TILE_CELLS := 8

# --- chunk sleep ----------------------------------------------------
## Cells per chunk side. **Not an optimization knob but water's prerequisite** —
##  one GDScript sweep of the grid is 62,676us against a 20Hz budget of 50,000us (`cell_grid.CELL_COUNT` comment).
##
## **16 is not a chosen value but the only one.** `W=4096 / 16 = 256` and `H=1008 / 16 = 63` is the only
##  candidate dividing both — 32 gives H 31.5, 64 gives 15.75. v1 was 16 too.
##  Not dividing evenly makes `cell_grid._init()` bark. Left silent, edge cells
##   **index out-of-range chunks** (same place, same reason as the `X_SHIFT` check).
## **Grid size (`W`, `H`) lives in `cell_grid`.** A derived constant can't be made here —
##  `cell_grid` reads this file, so it would be circular (the same trap as the `MAX_BURNING` comment).
const CHUNK_CELLS := 16

# --- water ----------------------------------------------------------
## Maximum water one cell holds. **255 is not a chosen value** — the amount goes into `_aux`,
##  which is a `PackedByteArray`. Exceed it and it is **truncated to the low 8 bits with no error**
##  (the place `bake_fuel` got burned).
## **The more full cells (255), the cheaper** — packed above and below, nothing moves and that chunk sleeps.
##  That is why a lake's interior is free (`docs/design/water.md`, "why amount").
const WATER_MAX := 255

## If the amount differs from a left/right neighbor by this much **or less, nothing moves.**
##
## **This is the sole knob for "does water stop".** Without it an odd number never divides and
##  ping-pongs 1 left and right forever, so the chunk **never sleeps** and chunk sleep is void.
##  That is exactly where v1 died (`docs/design/water.md`, "where v1 died").
##
## **A different knob from the wetness threshold. Do not mix them.** spec inverted and measured it —
##  changing only the wetness threshold 0 -> 8 -> 32 -> 64 changes **the moved-cell count by nothing.**
##  => This value decides stopping; wetness is **a screen value.**
##
## **4 was chosen as "the minimum that runs", not as a value that buys stopping.** What the measurements say
##  is that **no value stops wide water** (128 cells wide doesn't stop by 4,000 ticks even at 32):
##
##      width 32   MIN_DIFF 16 -> 2,798 ticks · 32 -> 1,662 · 8 or less -> never
##      width 64   32 -> 3,958 ticks · 16 or less -> never
##      width 128  never, at any value
##
## **Acceptance 2 (does it lie flat) and 1-a (does narrow water reach 0) pull against each other** —
##  raise it and it stops sooner but **the surface visibly tilts** (up to 32/255 = 12.5% per neighbor);
##  lower it and it lies flat and lives long. **A value to change while looking at the screen.**
## 1-b (does wide water sleep) barely feels this axis — only the **surface band** stays awake,
##  so eight times the width goes 7 -> 18 (`docs/design/water.md`, "why amount").
const WATER_MIN_DIFF := 4

## **How many times `_water_step` runs per tick — the only knob that speeds up water alone.**
##  The user watched the screen and judged "water spreads slowly". Not the fall but
##  **how fast it flattens left and right after pooling.**
##
## **Using `TICK_DIVIDER` instead speeds up the whole game** — bolt speed, range and fire spread all go
##  N times faster and **the tick budget drops 50,000 -> 16,667us.** => This is the only door touching water alone.
##
## **`WATER_MIN_DIFF` can't buy it either — that axis was already measured**:
##
##      width 32   MIN_DIFF 4 -> 620 ticks   · 16 -> 504
##      width 128  MIN_DIFF 4 -> 6,192 ticks · 16 -> 4,047
##
##  **1.5x is all of it**, and raising it to 16 **tilts the surface 7x** (at width 128, a 1-cell height
##  difference becomes 7) => **it sells acceptance 2 to buy 1.5x.** Substeps don't dig that axis —
##  the rule is unchanged and **the same rule simply runs more often.**
##
## **At 1 this is exactly identical to before this constant existed.** `_water_dir(sub)` derives from
##  `(_tick + sub)`, so with only sub 0 it produces the old expression's value. **The way back must be this one line.**
##
## **Cost is N times, exactly** — both the band term and the chunk term are paid N times
##  (`cell_grid._water_tick` comment). **A judgment from reading, not a measurement** (what is certain is only
##  that the loop runs N times).
##  **So `MAX_CHUNKS_PER_TICK`'s effective limit becomes one Nth** — see the cliff table in that constant's comment.
##  **Normally it isn't reached**: a still lake keeps 7-18 chunks awake, so 3x is 21-54 while the cliff was
##   ~100 chunks (at N=1). Only **the moment a dam breaks** reaches it.
##
## **The fall scales N times too.** This value repeats **all of** `_water_step`, not just the left/right share —
##  what the user called slow was only left/right. **If the fall looks excessive, split the axes then.**
##  `net_water`'s "exactly N cells per tick" holds that fact by value.
##
## -- measured (verify-run. N=1 was measured in an isolated copy with only this line set to 1) --
##
##      ticks to lie flat   width 32  719 -> 244 (2.95x) · width 64 2,284 -> 742 (3.08x)
##                          width 128 7,252 -> 2,388 (3.04x)
##      fall                1 cell/tick -> **2.67 cells/tick** (not 3x — see "band boundary" above)
##      cost                **3.0-3.4x**. Width 512 worst case is 68% of budget (16% at N=1)
##      total volume · left-right bias · max active chunks   **same as N=1** (bias 0.0046% · chunks 28/42/90)
##
## **Not an approximation — tick k at N=3 has exactly the same water state as tick 3k in the old code**
##  (position-weighted checksum, 100/100 match). **Time was compressed 3x**, the rule did not change.
## **Total work barely grows** — settling at width 128 goes 9,867ms -> 10,426ms of wall clock.
##  "The same work crammed into less time" is the accurate sentence.
## **`= 1` being byte-identical to the old code was confirmed too** (300-tick checksum, 0/300 mismatches;
##  the negative control at N=3 differed 600/300). **The way back is this one line.**
##
## **3 is a value the user chose while looking at the screen.** They launched the game, poured water with F,
##  watched it spread, and settled on "that's good". **The fall becoming 2.67x passed with it** —
##  the user had said "the fall isn't slow", so **had it looked excessive it would have been caught here.**
## **Scope of confirmation: eye only.** No screenshot, and one puddle poured with F.
##  **Dam-break scale (100+ active chunks) was not seen** — that is acceptance 7, still failing.
const WATER_SUBSTEPS := 3

## **How many cells one tick's fall covers — the only knob for fall speed** (`water-jump-and-escape.md`, stage 2).
##
## **It carries no per-cell velocity state.** `_aux` is already full with the amount (0-255), leaving no room
##  for a velocity byte (`docs/design/water.md`, "falling has no acceleration"). => **Instead of imitating
##  velocity, scan up to this many consecutive empty cells below in one tick and move the whole thing to the
##  lowest empty cell.** On hitting water or solid, stop there and handle it by the current rules (merge, or blocked).
##
## **Starts at 4. There was a measurable target** (unlike underwater gravity, K can't be deferred —
##  without the constant not one line of fall code can be written).
##
## **But the speed table computed arithmetically (`K x substeps`) was wrong — it was replaced by measurement**
##  (verify-read and verify-run measured independently and agreed).
##  **"Per-tick maximum" and "average speed" are different numbers** — split here:
##
##      per-tick average (K=4, measured)   **8.0-8.04 cells/tick · 640-643 px/s · 20.1 tiles/s**
##      per-tick maximum (`K x substeps`)  12 cells/tick · 960 px/s     <- correct only as a safety ceiling
##
## **The cause was caught by value.** Per-tick movement alternates **exactly `12, 4, 12, 4 …`**
##  (12+4=16=band height) — the band-boundary skip below is hit **every other tick** for a K-cell fall.
##  => **The loss rate grows with K**: 11% at K=1 becomes **33%** at K=4.
## **`K x WATER_SUBSTEPS` is not a wrong constant** — it is wrong **read as "average speed"** and
##  still correct as **"the ceiling a tick cannot exceed (the safety net)"**, which is what
##  `net_water._water_falls_per_tick` measures.
##  That check and its safety table live **in one place, in that file** (CLAUDE.md, "if the same explanation
##  appears in two files, move it to one" — it was kept here once, the scene grew, this wasn't updated, and they diverged).
## **The final value is the user's, decided on screen.** 6 if 4 is "still slow"; going higher requires
##  enlarging `net_water`'s scene (free-fall headroom) first — and **as K grows the band-alternation loss
##  grows too, so re-measure this average (8 cells/tick) then.** It does not track K linearly.
##
## **A band boundary can be skipped K cells at a time** — `_write_water` wakes the destination chunk so it is
##  correct in principle, but if a skipped band isn't awake that tick, water can look briefly stalled in mid-air.
##  **Closed by measurement**: both the 40-tick and 111-tick observations had **zero 0-cell ticks** —
##  K (4) is smaller than the band height (16), so skipping is impossible in principle. `net_water` measures it by value.
const WATER_FALL_CELLS := 4

## **Safety net on chunks processed per tick.** Over it, the rest is **pushed to the next tick** — never discarded.
##  On screen it looks like "water flows slowly for a moment" and **water never stops or vanishes.**
##
## **Exactly the same idiom as `MAX_BURNING` — a safety net, not a tuning knob.**
##  If it starts biting often, don't raise the value — look at **how much water the level holds.**
##
## **The original grounds for 512** (no longer used): one screenful is 480x270 cells = 30x17 = **510 chunks**,
##  so a lower cap would constantly delay visible water.
##  **That value came from "how many chunks are visible" and never looked at "how many we can afford."**
## **The cost rationale flipped twice; this is the third value.**
##  The plan counted 42% at 41us/chunk (spec's proxy measurement); the implementation measured falling water at 78us, giving 80%.
##  **verify-run re-measured with a dam break and it is far worse**:
##
##      worst tick      **273-290% of budget**
##      400-tick mean   **101.5% of budget**
##
##  **So while actually pinned at the cap, 20Hz is not achieved.** That is what "water flows slowly for a moment" is.
##
## **Once `WATER_SUBSTEPS` stood up, this value means "chunk count", not "amount of work".**
##  The cut happens **once per tick** and a surviving chunk **runs N times** => a tick's real work is
##  **`MAX_CHUNKS_PER_TICK` x `WATER_SUBSTEPS` chunk-passes**.
##
## **512 -> 100 (decided by the user).** The grounds for 512 above came from **screen area**,
##  **not from cost.** verify-look measured real FPS and it is a cliff:
##
##      85 chunks    229 FPS
##      126 chunks     6 FPS      <- it doesn't taper, it drops
##
##  => The real limit for falling water is **~100 chunks** and the cap was **5x that** => the safety net wasn't one.
##  The body text wrote it in advance — "if acceptance 7 fails, don't optimize, lower the value". **That day came.**
##
## **Lowering it is not "faster"** — total work is the same and **the slow stretch is spread thin and long.**
##  What changes is **"dropping into single-digit FPS" -> "water flows slowly for a moment".**
## **In the game today it is imperceptible** — one F press is 797 cells / 7 chunks and the cliff is ~24,000 cells.
##  The day it bites is **the day a reservoir is painted on the map**, and that warning is in `docs/design/terrain-baking.md`.
## **With N=3, the cliff seen on screen (~100 at N=1) actually arrives at ~33 chunks.**
##  It is still 100 because **keeping a fifth of a screenful (510 chunks) is the intent** — lower and
##  visible water is constantly delayed, turning the safety net into a tuning knob (see "same idiom" above).
const MAX_CHUNKS_PER_TICK := 100

## At or **below** this amount, water is shallow (`cell_materials.FLAG_SHALLOW`).
##
## **This value also decides "does it put out fire" — it is no longer screen-only.**
##  `cell_grid._deep_water` uses this line: **water at or below the threshold cannot extinguish.**
##  Decided by the user, because **one F press (797 cells) spread sideways and permanently fireproofed ~860 cells of forest.**
##  **The point is that no new constant was created** — rule and screen use **the same line**, so
##   "bright sky-blue wet stains can't extinguish, dark navy real water can" is **already drawn on screen.**
##  **=> Change this value and color and fire-proofing move together.** Do not pick it looking at one of them.
##
## **It still has nothing to do with stopping** — spec inverted and measured it:
##  changing only this value 0 -> 8 -> 32 -> 64 changes **the moved-cell count by nothing.**
##  Stopping is set by `WATER_MIN_DIFF`. **Read as one knob, you end up turning a knob that isn't there.**
##
## **Do not read this bit as marking "the surface". It marks "thin water".**
##  Structurally: water fills from the bottom, so **a settled column stacks 255s and only the top cell holds
##  the remainder.** How big that remainder is **depends on how much was poured** — above the threshold,
##  **not one row of the surface splits**; below it, **the whole surface splits at once.**
##  => **On or off, not "one row at the surface".**
##  The **edge** of a thinly spread puddle does split cleanly — that is this bit's real home (= a wet stain).
##
## **32 is a value the plan put in place.** verify-look saw the color (the shallow side reading brighter was right)
##  and **the user has not seen it.** Raise it and more water splits, and approaching `WATER_MAX`
##  **makes all water look shallow and stop extinguishing at the same time.**
##  => **The user decides at acceptance 6. When they do, change this line and `fx_tuning.WATER_SHALLOW` together.**
## **Measured**: pouring one `WATER_MAX` blob onto a row of wood settles into a sheet of **max 27 across 17 cells.**
##  => **32 sits exactly where "one blob loses its fire-proofing once it lies down".** The gap between 27 and 32
##   is that margin, and lowering the threshold below 27 makes **a thin sheet a firebreak again.**
const WATER_WET := 32

## **Width of the K (rain) source — mouse row, plus and minus 88 cells, 176 total.**
##
## **Not arbitrary.** `water-jump-and-escape.md`'s "A/B/C re-measurement" left a table measured at this width
##  (25%->5.0s · 50%->8.0s · 95%->11.0s) — change the width and that table means nothing.
const WATER_RAIN_HALF_W := 88

## **Total the K (rain) source pours across that whole width per tick.** 20,000 is the starting value.
##
## **Measured (verify-run · approach A · 176 cells wide)**: 25%->5.0s · 50%->8.0s · 75%->9.0s · 95%->11.0s,
##  all within target (5-15s). Active chunks touch the cap (100) only in the first terrain-building ticks and
##  range 39-81 while pouring — "water gets delayed" doesn't occur at this width and this rate.
## **8,000 is also in range for the 25-50% stretch (9-14s)** — usable for a scene that doesn't require a full room.
##  15,000-20,000 is the range and **20,000 is the starting value**. Move within it after seeing the screen.
const WATER_RAIN_PER_TICK := 20000

# --- ticks ----------------------------------------------------------
## Physics frames (60Hz) per sim tick. 3 => 20Hz (GDD).
## **An integer divider.** A float accumulator makes tick boundaries wobble with frame time and split
##  differently per client — in multiplayer the tick number is state.
const TICK_DIVIDER := 3

# --- runes ----------------------------------------------------------
## With one rune there is nothing to compare against, and with no water "water+fire = steam" can't be measured —
##  **whether the rune is a real axis is not confirmed at this stage** (design, "Boundary").
##  The axis is still made **as a slot** so that adding runes means editing one table row.
## **It is not "only the color changes".** In `ELEM_DEFS` below, runes touch the world —
##  the design widened that boundary by one notch, and the reason is in that comment.
const ELEM_FIRE := 0

## **None — "leaves no trace" is the definition.** Not fire with a different color.
##  **It is not "does nothing to the world" — that sentence narrowed.**
##   Impact carving terrain moved up to step (1) of `spell_sim._impact` and **became rune-independent** =>
##   a none bolt still makes a hole. Left unnarrowed, the next person reads "none doesn't touch the world"
##   and builds on it (the same sentence is also in `spell_sim._rune_trace` — **two places**).
##  **It cannot be 0.** `ELEM_FIRE` is 0, so the `ELEM_DEFS` keys would collide.
##   **Not a silent failure** — measured: GDScript barks **at parse time** with
##   `Parse Error: Key "0" was already used in this dictionary` and **the whole file fails to load**
##   (`fx_tuning`'s `ELEM_FX` barked with it).
##   So don't read this as "dictionary key collisions are silent" — you'd write a net for a risk that doesn't exist.
##  **But the shape of that failure in the nets is quiet**: the same mutation took the pass count
##   **1138 -> 723 while only 2 checks failed.** That is the third instance of "when src doesn't compile,
##   checks don't go red — **they disappear**" (`net_layers`'s `_parses` comment · `net_damage` header).
## Behavior (speed, trajectory) is **identical to fire.** That narrows the differing axis to "does it touch the
##  world", which measures **whether the rune is a real axis** cleanly (what "with one rune…" above couldn't).
const ELEM_NONE := 1

## **Water rune — creates water at the impact point.**
##  **Behavior matches fire and none** (speed, trajectory). The differing axis is still only "what it leaves in the world".
## **This rune standing up opens both of water's sources** (`docs/design/water.md`, "where water comes from").
##  With water only on the map you must **drag a monster to the waterside** to wet it; a rune that makes water
##  lets "wet it -> shock it" hold anywhere — that is where the GDD thesis (different order, different result) lives.
##  **There is no lightning rune yet.** So wetness is currently useful only on screen.
const ELEM_WATER := 2

## Iteration goes **only through this explicit list**. Assuming contiguous values breaks silently the day
##  a slot is retired.
const ELEM_ALL: Array[int] = [ELEM_FIRE, ELEM_NONE, ELEM_WATER]

## Kinds of trace a rune leaves in the world.
const TRACE_IGNITE := 0

## **"No trace" is itself a kind of trace.** It must be a named branch rather than an empty value so
##  `spell_sim._rune_trace` can bark for "a rune with no implementation" and tell them apart.
const TRACE_NONE := 1

## **Wets the impact point.** This file recorded "it grows when water arrives — **don't make the slot in advance**",
##  and that day came.
const TRACE_WET := 2

## **The only table where a rune touches the world. One rune = one row here.**
##
## **This is the notch past "in A the rune only changes color"** (which is why the design's "Boundary" changed).
##  There is one reason for crossing — without it, **half of "blast -> spread" evaporates on screen.**
##  With spread as the last layer, the eight bolts created carry an **empty list** and do nothing on impact,
##  leaving only a 0.4-second trail. Measured: key 5 touched nothing beyond one smooth hole.
## The GDD already wrote the answer — "fire rune + spread -> 8 **small flames** after impact".
##  Those flames are flames because of the **rune**, not the glyph.
const ELEM_DEFS: Dictionary = {
	ELEM_FIRE: {"trace": TRACE_IGNITE},
	ELEM_NONE: {"trace": TRACE_NONE},
	ELEM_WATER: {"trace": TRACE_WET},
}

# --- power ------------------------------------------------------------
## **Base damage percent.** `Character.DAMAGE_HIT * power / 100` is the whole formula
##  (`spell_sim.gd`'s "power_pct" section). Common-rarity glyphs are 100, so a bolt carrying only common
##  glyphs (or none at all) deals exactly the pre-Stage-A damage — that identity is the honesty check.
const POWER_BASE := 100

## **A bark ceiling, not a tuning knob** — the same idiom as `MAX_BURNING`. 7 layers of 200% composes to
##  12,800 (comfortably inside int32); this exists so a future glyph with a much larger `power_pct` cannot
##  silently overflow through repeated MODIFY composition at `_launch`. Unreachable with today's table —
##  `net_spell` measures the clamp fires when forced past it directly, since "unreachable today" is not the
##  same claim as "tested".
##
## **Only `_launch`'s MODIFY composition clamps against this.** `_run_glyph`'s `blast_power`
##  (`power * Glyph.power_pct_of(id) / 100`, one multiplication against an already-clamped `power`) and
##  `_pend_pow` (which only ever carries a value `_launch` already clamped) cannot exceed
##  `POWER_MAX * 1.5 = 1,500,000` — comfortably inside int32 (2,147,483,647) with today's highest `power_pct`
##  (150). Not clamped a second time **because they cannot overflow with today's table**, not because the
##  question was skipped — the day a `power_pct` column is added that could push that product past int32, this
##  line is where to add the clamp, not a guess made in advance.
const POWER_MAX := 1000000

# --- bit width of the glyph list ------------------------------------
## The "remaining glyph list" a bolt carries is **a single integer**, stacked 4 bits per nibble.
##  **7 layers is the ceiling.** `PackedInt32Array` is signed 32-bit, so an 8th layer sitting in the top nibble
##   makes it negative, and `>> 4` being an arithmetic shift corrupts it via sign extension, **with no error.**
##  The base circle is 2 layers, so there is room to spare.
const GLYPH_BITS := 4
const GLYPH_MAX_LAYERS := 7

# --- projectiles ----------------------------------------------------
# --- the spread generation table — "small things are weak" comes from this one place ---
## `_gen` 0 = original, 1 = produced by spread. **Size, range, blast radius and ignition radius all derive from here.**
##
## **The four columns below must decrease every generation.** Leaving values equal makes the net unable to
##  distinguish **"deliberately not decreased" from "forgot to decrease"** — to turn an axis off, don't equalize
##  the table, multiply by a constant on the consumer side.
##
## **Not "every column" — `net_tables` measures only names written by hand**
##  (`_strictly_decreasing(..., ["speed", "rd", "ignite_r", "rune_r", "carve_r"])`).
##  **Adding a column here means adding its name to the net too.** Skip that and nobody measures it while
##   `[net] N passed` **stays green** — confirmed by measurement (a non-decreasing `damage` column added to
##   both rows ran the full nets: 1038 passed, exit 0, and not one assertion mentioned it).
##  This comment used to say "every column", and a design doc that trusted the label wrote
##   "new columns are checked automatically" — a real case of CLAUDE.md's "No fake nets",
##   **the label claiming more than the check measures, actually deceiving a person.**
## **The monotonic direction is the opposite of v1's.** v1 grew with power tier; here it shrinks with generation depth.
##  Copying a v1 net verbatim goes red.
##
## **"Small things being weak" saves performance too** (GDD) — half the radius is a quarter the area.
##
##   water_r   **Radius the water rune wets (cells).** Glyph-independent — the water-side sibling of `rune_r`
##   speed     Launch speed (cells/tick). Drag range ceiling = speed / (1 - DRAG), so **range comes from here too**
##   rd        Blast radius (cells). In v1 measurements, 12 was named "opens a door" and 6 "scratches"
##   ignite_r  A blast's ignition radius (cells). **Must exceed rd** — see the `blast_ignite_r` comment
##   rune_r    **Ignition radius of the rune trace (cells).** Even an impact with no glyph does this much
##   carve_r   **Radius every impact carves (cells).** Sees neither rune nor glyph — see the section below
##
## **`speed` and `rune_r` are the doubled values from the 32px switch** (before: speed 10/6, rune_r 3/1).
##  The unit is cells but **the meaning is "this big on screen"**, so they fall under the `TILE_CELLS` branch above —
##  left unraised they halve on screen.
##
## **`rd` and `ignite_r` were lowered twice by the user, on screen.**
##  `rd` 24 -> 12 -> **8** (hole diameter 6 tiles -> 3 -> **2**), ignition following 36 -> 18 -> **12**.
##  **The second was decided on screen** — the first (half) was launched, looked at, and "2 tiles should do it".
##  **The names "opens a door / scratches" fell off at 24 and 12.** What v1 called "scratches" was 12,
##   so generation 0 is now **smaller than that** — there is no sense of punching a wall in one shot.
##  **`speed` was not lowered with them.** Range is a spell's character, a separate axis, and what the user
##   spoke about was radius only. The trajectory is unchanged; only the mark shrinks.
## `ignite_r` **has no choice but to follow** — break `ignite_r > rd` and you get "the blast works but nothing burns".
##  => The 1.5x ratio was held throughout.
##
## **`rune_r` was not lowered, and the contract got tight because of it.**
##  "The rune trace must be **smaller** than the blast" (see the `rune_r` comment) went from a margin of
##  **6/24 = 0.25 to 6/8 = 0.75** — the inequality holds and `net_tables` passes, but on screen
##  **trace and blast are nearly the same size.** "Spread looks like it doubles as blast" comes from here.
##  **`net_tables` measures only the inequality, never the ratio** — don't read green as "there is margin".
##  => If acceptance 2 (spread->blast vs blast->spread) looks mushy, **this is the first suspect.**
##
## **`carve_r` grew after the user reported "it doesn't shrink a wall by one cell".**
##  **The old rule was that terrain doesn't change without a blast glyph.** The grounds for overturning that,
##   and the grounds that "blast -> spread" still isn't mushed by it, are written once in `spell_sim._impact`.
##  **`carve_r < rune_r` is a contract.** Carving (1) comes before the rune trace (2), so equal or larger means
##   **the carve erases the fuel the fire rune would burn** — the trap in the `blast_ignite_r` comment below,
##   recurring in miniature, **with no error at all.** Generation 1 has **1 cell of margin** (1 < 2)
##   => `net_tables._gen_tables` measures it per generation.
##  The value's grounds are a user judgment — "radius 2 cells = a hole half a tile across". Punching one wall
##   (8 cells) takes **several shots** while a blast is **one**. That contrast is where this value sits.
## **`water_r` starts equal to `rune_r`.** Both mean "radius of the trace a rune leaves at impact",
##  and **there is no reason yet to differ** — nobody has looked at whether fire or water should read larger.
##  **The reason for a separate column** is so that when such grounds appear, **only one** can move.
##  Reusing `rune_r` would make that day "I shrank fire and water shrank too".
## **`carve_r < water_r` must hold too** — carving (1) precedes the trace (2), so equal or larger means
##  **the carve erases the place water would go, rather than water filling what was carved.** Generation 1 has 1 cell of margin.
##  `net_tables` already measures that inequality for `rune_r`, and it must measure `water_r` too.
const SIM_SIZES: Array[Dictionary] = [
	{"speed": 20, "rd": 8, "ignite_r": 12, "rune_r": 6, "carve_r": 2, "water_r": 6},
	{"speed": 12, "rd": 4, "ignite_r": 6, "rune_r": 2, "carve_r": 1, "water_r": 2},
]

## **Size floor — reach it and spread doesn't apply** (GDD, "size floor").
##  With one spread per magic circle (`glyph_defs`'s `max_per_circle`), generation 2 **already can't occur
##   in principle.** This value is a **structural floor** for the day that rule loosens, and `net_tables`
##   measures it together with the table length — raise the ceiling without extending the table and you read a row that isn't there.
const SPLIT_MAX := 1

## Bolts spread creates. `(±1,0) (0,±1) (±1,±1)` — **eight come out as integers with no `sin` or `cos`.**
##  The glyph's integer constraint costs nothing here (GDD).
const SPREAD_COUNT := 8

## Launch speed lives in the table above (`speed_cells(gen)`). Generation 0's value gets **no separate name** —
##  give the table's first row two names and one day only one gets fixed.
##  Measured: 20 ticks x 20 cells x 4px = 1,600px/s. In tiles that is **50 tiles/s**, the same as the 16px world.

## **Drag.** Every tick, `v * DRAG_NUM / DRAG_DEN`. 240/256 = 0.9375/tick.
##  **A ratio, so leave it alone** — range is set by `speed`.
##  => Horizontal range ceiling = v0 / (1 - 0.9375) = 20 / 0.0625 = **320 cells = 40 tiles = 1,280px**.
##
## **That 320 cells (40 tiles) is the "if there were no gravity" value. It doesn't actually fly that far.**
##  **This used to say "40 tiles of range is 4/3 of the 30-tile screen width, so bolts fly off screen",
##   and that sentence migrated into a design doc as the grounds for "bolt speed must be reduced".**
##
##  **Measured (headless, fired 4 cells above the ground)**:
##
## ```
##            horizontal      45 degrees up
##  gen0(20)   53 cells 6.6 tiles    193 cells 24.1 tiles
##  gen1(12)   32 cells 4.0 tiles    102 cells 12.8 tiles
## ```
##
##  **Gravity plants the bolt before drag does.** Reaching the drag ceiling would require not falling across
##   320 cells, and a ground-level shot **hits dirt in 4 ticks.** => **It doesn't exceed the 30-tile screen width even at 45 degrees.**
##  **Firing from a cliff goes farther** — by however long the fall lasts. The values above are **flat ground.**
##  **Horizontal range is linear in `speed`** (measured ratio 0.604 vs speed ratio 0.600).
##   45 degrees is non-linear (0.528) — initial vy shrinks too, shortening airtime.
##  => **"Lower speed because of range" has no grounds.** If there is a reason to lower it, it is **visibility**
##   (speed 20 = 26.6px per frame, so a 16px sprite skips without overlapping).
##  **Don't change the value here.** Range is a spell's character, the magic-circle design's call, and
##   the screen-side price is recorded in `stage.gd`'s `MAP` comment as "blasts can go off screen".
##  Exponential decay means a small coefficient change swings range hard. 248/256 gives **2x (640 cells)**
##   (1 - 248/256 = 1/32 => range = 32*v).
##
## **Integer division (`/`), not a shift (`>>`).** `>>` floors on negatives, so only left-flying bolts
##  decay 0.5/256 harder — left and right become subtly asymmetric, visible only as "shots to the left go
##  slightly less far". `/` truncates toward zero and is symmetric.
## **Integer truncation eventually makes horizontal speed exactly 0.** The smaller vx gets, the larger
##  truncation's share, and from then the bolt falls straight down. As a picture, "it runs out of force and
##  plants vertically" is right, and **it was chosen deliberately** (design, "trajectory"). Determinism is safe —
##  integer division is platform-independent.
const DRAG_NUM := 240
const DRAG_DEN := 256

## Gravity (fixed point, 1/256 cell per tick^2). 128 = 0.5 cells/tick^2.
## => Terminal fall speed = 128 / (1 - 0.9375) = 2048fp = **8 cells/tick = 640px/s**.
##  Far slower than the character's fall cap (1,800px/s) — a bolt reads as "arcing", not "planting heavily".
##
## **Must be doubled together with `speed`. Raise one alone and it goes silently wrong** — parabolic range is
##  v^2/g, so doubling speed alone makes the trajectory fly **4x farther**. **Exactly the same trap** as
##  `character.gd`'s `JUMP_VY_PX` and `GRAVITY_PX`, and neither raises an error.
const GRAVITY_FP := 128

## Ticks before a projectile that hit nothing disappears = **10 seconds.**
## **A genuine safety net.** With gravity, a bolt must reach the ground or leave the grid, so an
##  eternally circling projectile is impossible in principle. It is 4x longer than a straight-up shot's
##  round trip (rise ~15 ticks + screen height 270 cells / terminal 8 cells per tick ~= 34 ticks = 50 ticks).
##  **This value was not touched in the 32px switch** — it is a tick count, and the calculation above doubles
##   both screen and terminal speed, **landing on the same 34 ticks.** Don't read it as "everything doubled, so 200 doubles".
##  v1's 40 ticks was an **unreachable guard**, but with drag added, slowed bolts live longer —
##   and a bolt simply vanishing in mid-air reads as a malfunction.
const LIFETIME_TICKS := 200

## Simultaneous projectiles. 32 x 2us = 64us/tick = 0.4% of budget (v1 measurement). Not the bottleneck.
## **A count, so unchanged in the 32px switch. But one bolt's cost doubled** —
##  `_walk`'s DDA step count is **cells crossed per tick = `speed`**, and that doubled.
##  => Roughly 128us/tick = 0.8%. **Not a measured value** — stage 0 was measured with **0 bolts**.
const MAX_PROJECTILES := 32

# --- blasts ---------------------------------------------------------
## **The real ceiling is here.** v1 measured four large blasts applied simultaneously at **8,940us = 54% of budget.**
##  The 32-projectile cap is 0.4% and not the bottleneck — the place to tighten is always this one.
## **Re-measured on this machine at 1,291us with `rd` 12** (builder, headless).
##  A 6.9x gap from v1's number, and **whether that's the machine or the code was never separated** — read it as a ratio only.
## `rd` went to 24 and **came back to 12** (user judgment, see `SIM_SIZES` above) — cell area is a quarter,
##  so blast application shrinks with it and **the 1,291us measurement is valid again.**
##  => The budget margin, squeezed to 1.6x at 24, returns to 2.6x. **Not re-measured** —
##   the same `rd` value means the old measurement holds, not that a new one was taken.
## **On overflow, defer to the next tick rather than discard** (`spell_sim._pend_*`). Discarding gives
##  "spam shots and some don't detonate", which reads as **a malfunction.**
##  The point is that it is the exact opposite of the projectile cap — that one is unreachable in principle,
##   so **barking and discarding** is right; here 8 spread bolts landing on one tick **actually reaches it**, so deferring is right.
const MAX_BLASTS_PER_TICK := 4

# --- fire -----------------------------------------------------------
## Fuel consumed per tick. Wood fuel 200 => one cell burns for 40 ticks = **2 seconds.**
## One cell's lifespan, not the fire's — the fire's lifespan is set by **how much wood you placed**
##  (GDD, "where you put fuel is level design").
const FIRE_BURN_PER_TICK := 5

## Ticks between spreading to a neighbor. 1 => 20 cells/s = 80px/s.
## Set too slow, it reads as "smouldering" rather than "spreading" —
##  watching fire spread is acceptance 5, so the speed itself is part of that check.
##
## **Lowered 2 -> 1 in the 32px switch. The user decided it on screen.**
##  Cells were unchanged while the screen scale went 2x -> 1x, so **spread looked half speed on screen** —
##  measured (verify-look): **1.25 tiles/s** at 2, previously **2.5 tiles/s**. Lowering to 1 restored it.
## **The cost worry was overstated** (verify-read read the code and corrected it): the full `_burning` sweep
##  and fuel consumption **run every tick.** What this value gates is **only the four neighbor-ignition lines**,
##  so what doubles is the spread pass, not fire's total cost. **Said from reading, not measured.**
const FIRE_SPREAD_TICKS := 1

## **A safety net. Not a tuning knob** (GDD).
##  "Fire won't catch past N" visible to the player reads as **a malfunction**, not a rule —
##  what stops fire must be fuel.
##
## **The original grounds were "11% of the grid's cell count", and those grounds are dead.**
##  4,096/36,864 = 11.1% -> 16,384/147,456 = 11.1% tracked fine, but once the grid became
##  **4,128,768 cells** the same value became **0.397%.** **Holding the ratio would require 460,000.**
##
## **The value stays 16,384 anyway. The ratio simply stopped being the rationale.**
##  This is a safety net, and a safety net's size is set by **how much fire one tick can afford**, not by grid area —
##  a bigger grid doesn't grow the CPU. 16,384 x 0.36us ~= 5,900us is the theoretical worst, 12% of the
##  20Hz budget (50,000us). **Following the ratio to 460,000 makes that worst case 165,000us = 330% of budget** —
##  the safety net stops being safe.
## **Grounding it on the stage (`stage.gd`) goes stale silently** — the stage is the shell and won't survive into the real game.
##
## **Not raising it would have nearly broken the contract** — with 8x8-cell tiles, stage wood went 736 -> 2,944 cells,
##  cutting the margin from 5.6x to 1.4x, and stage 0's worst case **actually reached 4,096** (measured).
## **Cost doesn't rise.** Reaching the cap needs 16,384 cells of wood and the stage has only 2,944, so it is
##  **unreachable** — that is what "safety net" means. What rises is only the theoretical worst (16,384 x 0.36us ~= 5,900us).
## **It can't be a derived constant** — the cell count lives in `cell_grid` and `cell_grid` reads this file, so it would be circular.
const MAX_BURNING := 16384


# --- reading the generation table ------------------------------------
## The generation is **clamped** — a generation deeper than the table falls to the last row instead of dying here.
##  Leaving that silent is not acceptable, so `net_tables` separately measures **whether the table length covers `SPLIT_MAX`.**

static func speed_cells(gen: int) -> int:
	return int(SIM_SIZES[_gen_row(gen)]["speed"])


static func blast_rd(gen: int) -> int:
	return int(SIM_SIZES[_gen_row(gen)]["rd"])


## **The ignition radius is fire's way in.**
##  A blast turns everything inside `rd` **into EMPTY = sets fuel to 0.** So unless the ignition radius is
##   **larger** than the destruction radius, **fire cannot catch in principle** — it erases its own fuel first.
##   No error is raised; it only looks like "the blast works but nothing burns".
##  => The **ring-shaped band** between the two radii is fire's only way in, and
##   `net_tables._gen_tables` measures that inequality **per generation** (`net_fire` sees only generation 0).
static func blast_ignite_r(gen: int) -> int:
	return int(SIM_SIZES[_gen_row(gen)]["ignite_r"])


## The rune trace's radius. **"Small" is the contract** — set it large and spread looks like it doubles as blast,
##  mushing the two combinations together again.
## The impact point is an **empty cell** (the cell just before the solid that was hit), so its fuel is 0.
##  At radius 0 it can't reach a neighbor and **nothing happens** — that is why generation 1's value is 1, not 0.
static func rune_r(gen: int) -> int:
	return int(SIM_SIZES[_gen_row(gen)]["rune_r"])


## **The radius every impact carves.** Even with no glyph and a none rune, it carves this much
##  (step (1) of `spell_sim._impact`).
## **Must be smaller than `rune_r`** — see the `SIM_SIZES` comment. Larger and, in "carve then set fire there",
##  **only the fire quietly disappears.**
## At 0, "magic digs walls" (the GDD's first natural law) vanishes entirely **with no error** —
##  that was exactly the state before this was added, and the nets were green the whole time.
static func carve_r(gen: int) -> int:
	return int(SIM_SIZES[_gen_row(gen)]["carve_r"])


## **The radius the water rune wets.** The water-side sibling of `rune_r`, bearing the same contract —
##  **it must exceed `carve_r`** (see the `SIM_SIZES` comment). Smaller, and the carve erases the place water would go.
## The impact point is an **empty cell** (the cell just before the solid that was hit). At radius 0 it can't
##  reach a neighbor and **nothing happens** — generation 1 is non-zero for exactly the same reason as `rune_r`.
static func water_r(gen: int) -> int:
	return int(SIM_SIZES[_gen_row(gen)]["water_r"])


static func _gen_row(gen: int) -> int:
	return clampi(gen, 0, SIM_SIZES.size() - 1)
