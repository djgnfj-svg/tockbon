# Terrain baking — drawn as an image, baked as text

**One line**: paint tiles in the editor, bake them to ASCII text, and the game reads that.

**Implemented**: full — the four stages and **the round trip (Claude painting) all run**
**Accepted**: pass (2026-08-06) — the user drew 312×126 tiles and it appeared in the game as drawn.
The round trip was **measured by value** ("Round trip" below) — **the user has not seen it by eye yet**

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).

**The map is fixed** (decided by the user; GDD "Dungeon generation").
There is no procedural generation, so **this pipeline is the level design tool and it survives into the real game.**

---

## Why this way

The choice was between **writing ASCII by hand** and **painting in the editor.**

- ASCII only means **a human cannot draw 312×126.** With nothing visible there is no way to shape anything
- Editor scenes only means **the sim cannot read it.** `src/sim/` not knowing the scene tree is a contract

⇒ **Draw as an image, bake as text.** Humans look at the image; the sim reads the text.

**The baked result is the single source.** `MAP` in `terrain_map_generated.gd` is what both the game and the nets read.
The scene's tile layer is the **editing original**, not what the game reads — and **without baking it never reaches the game.**

---

## Four stages

```
① build the tile palette   build_terrain_tileset.gd     only when adding a material
② paint in the editor      the Terrain layer of stage.tscn   ← the human part
③ bake                     bake_terrain_editor.gd       Ctrl+Shift+X
④ the game reads it        terrain_map_generated.gd     automatic
```

### ① Tile palette — `tools/stage/build_terrain_tileset.gd`

Rebuilds `src/stage/terrain_tileset.tres`. **Run only when a material is added.**

```
Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/build_terrain_tileset.gd
```

**Do not hand-edit the `.tres`.** This script is the only door.

**The brush image is `assets/stage/terrain_tiles.png`** — 32px cells strung in one row, one per material
(currently 128×32px: stone · wood · bedrock · water).
**This is not game graphics; it is the swatch visible in the editor.** The real screen is drawn by the cell grid,
and colors come from `rgb` in `cell_materials.DEFS`.

**That png is baked now too** — `tools/stage/build_terrain_atlas.gd` makes it from `DEFS.rgb`.

```
Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/build_terrain_atlas.gd
Godot_v4.7.1-stable_win64.exe --headless --path . --import        ← refresh the import cache
Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/build_terrain_tileset.gd
```

**Run all three in this order.** **Skip the middle line and the tileset builder sees the old width** —
headless does not refresh the import cache automatically (it actually bit once; the builder measured the width and barked).

**Colors used to be hand-matched.** The risk then was "change a material color and **only the editor brush color
goes stale silently**, and since the game screen isn't wrong, **nobody notices.**"
Now `net_tables` compares the brush image's pixels directly against `DEFS.rgb` — stale goes red.
**The old png's three colors were exactly `DEFS`** — the risk was real but **it never fired.**

### ② Paint — the `Terrain` layer of `stage.tscn`

Open `src/stage/stage.tscn` in the Godot editor and select `Terrain` (a TileMapLayer).

**And always save the scene** (Ctrl+S). ③ **reads from disk, so it cannot see unsaved state.**
Bake without saving and **the old terrain is re-baked, with no error.**

### ③ Bake

**In the editor** — open `tools/stage/bake_terrain_editor.gd` in the script editor and run it (Ctrl+Shift+X).

**Headless** — `Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/bake_terrain.gd`

**Both call the same logic** (`terrain_baker.gd`). Not copies.

### ④ The game reads it

Produces `src/stage/terrain_map_generated.gd` — `MAP` (ASCII array) · `MAP_W` · `MAP_H` · `MAP_CHARS`.
**Generated. Do not hand-edit** — the next bake overwrites all of it.

---

## Adding one material — **three places found so far. This list has been wrong twice**

**Adding water for real removed two by derivation and surfaced two that were hidden.**

| Where | What | State |
|---|---|---|
| `DEFS` in `cell_materials.gd` | The material itself | **By hand** — it is the original, nothing to reduce |
| `CHAR_BY_MAT` in `terrain_baker.gd` | Material ↔ ASCII character | **By hand** — cannot be derived. **A net measures it** |
| **Re-bake the map** (`bake_terrain.gd`) | A checked-in artifact | **By hand** — see "the sixth". **A net measures it** |
| ~~`terrain_tiles.png`~~ | Brush image | **Baked from `DEFS.rgb`** (`build_terrain_atlas.gd`) |
| ~~`build_terrain_tileset.TILES`~~ | Atlas coordinates | **Derived from `Mat.ALL`** (`terrain_palette.gd`) |
| ~~`name_by_mat` in `bake()`~~ | Material → constant name | **By hand, but promoted to a constant. A net measures it** |

**Why the last two can't be derived**: inverting value→name with `get_script_constant_map()`
**collides `STONE` (1) with `FLAG_SHALLOW` (1).** Filtering by name convention is **a heuristic that goes stale.**
⇒ **Hold it by hand but have a net measure it** was the answer.

### And a **fifth was hiding** in this table — stepped on while adding water

The **local variable** `name_by_mat` inside `bake()`. **It was nowhere in the docs.**

**The symptom is nasty**: add only to `CHAR_BY_MAT` and **the brush appears and tiles place, but baking dies.**
**And it only surfaces once water is actually painted on the map** — unpainted, it never fires.
⇒ **Promoted to the `NAME_BY_MAT` constant. Nets cannot see a local variable.**

**This table said "four", so nobody went looking for a fifth** —
**claiming a list is complete makes everything outside it invisible.**

### And a **sixth** appeared immediately — it left the table while the table was being shortened

**"Re-bake the map".** Finding the fifth shortened the table to "two", and it was dropped in the shortening.

**Derivation in code fixes only "the moment of baking", never "the checked-in artifact".**
Adding `~` to `CHAR_BY_MAT` and **not re-baking the map** gave:

```
terrain_baker.CHAR_BY_MAT        {"#", "=", "B", "~"}
terrain_map_generated.MAP_CHARS  {"#", "=", "B"}      ← no ~
```

**The exact fault this doc claimed was "fixed by derivation" was committed in the present tense** —
"the baked map has a new character the game doesn't know ⇒ that cell becomes empty, with no error."
**It just never fired because there was not one cell of water on the map.**

**So this time it does not claim "there are three".** Twice, the claim of completeness hid the next place.
⇒ **When adding a material, don't trust this table — run the nets.**
`net_tables._terrain_brush_follows_the_material_table` measures all three by value.
Its **bidirectional assertion between the baked artifact and the character table** is what blocks the sixth.

---

**Below is a record from before that.** Two of those were fixed then:

- The `MAP_CHARS` line emitted by `terrain_baker.gd` was **a hardcoded string literal.**
  Grow `CHAR_BY_MAT` without growing that line and **the baked map contains a character the game doesn't know** —
  `MAP_CHARS.has(ch)` is false, so **that cell becomes empty, with no error.**
  ⇒ **Fixed to derive from `CHAR_BY_MAT`.**
- `paint_terrain_from_map.gd` hardcoded atlas coordinates as `{1: (0,0), 2: (1,0)}` and
  **bedrock (3) was missing** — run as-is, the map's `B` would have **vanished with no error.**
  ⇒ **Fixed to read from the tileset resource's custom data.** The table disappeared.

**Both would have fired the day water arrived, and the symptom would have been "part of the map is empty".**

---

## Round trip — Claude painting

**Decided by the user: the user designs the map's tiles and Claude paints them.**

```
ASCII file  →  [plant]  →  Terrain layer  →  refine in the editor  →  [bake]  →  game
```

```
Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/paint_terrain_from_map.gd -- <mapfile>
                                                                                      -- --from-generated
```

**It refuses to run without an argument.** The old safety was "one-shot, only when Terrain is empty", and
opening the round trip removed that lock — **the required argument stands in its place.**
And **it backs up the current Terrain as text before overwriting** (`tools/stage/terrain_backup_<time>.txt`, gitignored).
Same character table as baking, so **it can be planted straight back.**
**Why the baked text can't serve as the backup**: it is from the last bake, so **brush work since then isn't in it.**

### Don't re-save the whole scene — swap one `tile_map_data` line

**Burned three times here.** Rewriting the scene with `ResourceSaver.save(packed_scene)` makes all of the
following happen **silently** in headless:

| What | Why it's silent |
|---|---|
| **Nine uid lines vanish** | Headless has no uid cache. **Nobody references this scene by uid, so the game doesn't break**, and the editor reissues them next open, giving **a scene diff on every plant** |
| **Node properties disappear** | Swapping in a new `TileMapLayer` loses `position = Vector2(0, 1)` and `unique_id`. **Baking reads only cell coordinates, so the round-trip check stays green** while properties evaporate |
| **`tile_map_data` doubles** | Neither `clear()` nor `tile_map_data = PackedByteArray()` removes cleared cells — they stay as **`source_id = -1` records** with new cells appended (measured **21,048 → 41,816 chars**). The game runs fine and baking is correct |

⇒ **Build the cell data in memory only and replace that one line as text.** The rest of the scene is untouched.

**That one line still changes wholesale** — the cell enumeration order differs from the editor's brush order.
**Content and size match, and the baked result is byte-identical.** Brush order is unreproducible, so this remains.

### Measured

| Measured | Result |
|---|---|
| **Re-plant the baked map → re-bake** | `terrain_map_generated.gd` **byte-identical** |
| `tile_map_data` size | 21,048 chars — **same as the original** (no bloat) |
| Scene diff | **One line** (`tile_map_data`). uid · position · unique_id all preserved |
| Inversion: feed an unknown character `X` | **Barks and stops. Does not overwrite the scene** |

---

## Traps — learned by measurement

**It finds the painted region itself** (`TileMapLayer.get_used_rect()`). It does not read a fixed width from the origin.
**Measured**: the user painted 312×126 tiles and the old approach (fixed 64×36 window) silently skipped everything
outside it, **baking an entirely empty result.** Negative coordinates (above/left of the origin) are caught too and
shifted to start at 0.

**Exceeding grid capacity barks and stops.** The sim grid (`CellGrid.W` · `H`) is fixed in cells, so a painted region
larger than that **fails the bake instead of clipping into holed terrain.**
Current capacity is **512 × 126 tiles** and the painting is 312 × 126, so **the height is full** — painting lower hits it.

**Baking without saving the scene** — ② above. The most common mistake, and it raises no error.

---

## Do the nets measure this

`_wood_clumps` and `_stage_map` in `tests/nets/net_tables.gd` **measure the baked result directly**
(is wood broken into multiple clumps · are the gaps wider than an ignition source · are the map's characters real materials).

**So do not build a bake under a new name** — that net would then measure **a dead side branch** instead of
"the terrain that actually runs". The `terrain_baker.gd` comment gives the reason.

**And `_terrain_brush_follows_the_material_table` measures the brush palette** —
brush pixels ↔ `DEFS.rgb` · the tileset's materials ↔ the brush list · the character table ↔ **the baked artifact**
(bidirectional) · are `NAME_BY_MAT`'s names real constants · is the `.tres` uid alive.

**Still not all of "does baking run correctly".** Two holes remain:
- **Nobody catches baking without saving the scene** — the most common mistake
- **Whether the brush image looks good can't be measured.** Only that its colors match `DEFS`

---

## Read before putting large water on the map

**The water sim has a cliff.** verify-look measured it in an editor run:

| Water cells | Active chunks | Sim μs/tick | **Real FPS** |
|---|---|---|---|
| 16,384 | 85 | 35,808 | **229** |
| 24,576 | 126 | — | **6** |
| 32,768 | 165 | 77,292 | **4** |
| 163,840 | 512 (cap) | 251,923 | **1–2** |

**Not a slope — a cliff.** 229 FPS at 85 chunks, 6 FPS at 126.
Not "water flows slowly for a moment" but **it looks frozen.**

**It is currently unreachable** — the only way to add water in-game is the F key, and one press is 797 cells · 7 chunks.
The cliff is around **24,000 cells** (thirty simultaneous F presses).

**The day it becomes dangerous is this doc's business** — **the day a large reservoir or river is painted on the map.**
A single 24,000-cell lake means **the game looks frozen the moment it breaks.**
**Still water is cheap** (active chunks stay at 7–18). Only **the moment it all pours at once** is expensive.

⇒ **`sim_tuning.MAX_CHUNKS_PER_TICK` must be set before painting a reservoir.**
~~It is 512~~ **lowered 512 → 100** (decided by the user).
512's rationale was "one screen is 510 chunks", which came **from screen area, not from cost.**
Detail and alternatives are in `water-and-chunk-sleep`, "Decided", under `docs/plans/`.

**And measurement showed the cliff actually disappeared** — `water.md`, "Acceptance 7":
at 65,677 cells the 512 cap is **724%** of budget while 100 is **a flat 219%.** **Cost became independent of water volume.**

**⇒ Do not read the table above as "this much water freezes the game". Those are cap-512 numbers.**
Overflow now delays **water, not FPS** — on screen it reads as **"water flows slowly".**
**That does not mean it's free** — in a scene where the presentation needs water to arrive fast, that delay is the malfunction
(`docs/plans/2.active/water-jump-and-escape.md`, "Cost").

**Stage 1 gets no water** (decided by the user; water is stage 2).
**One exception — the room filling with water after the stage-1 boss dies** —
and it lands squarely on what this section warns about → `docs/plans/2.active/water-jump-and-escape.md`, "Cost".

**Render and upload are not the bottleneck** — long unknown (headless can't measure it), but at 71% of budget in sim
it hit 229 FPS. **The bottleneck is entirely sim.**

---

## TBD

- ~~A script to bake `terrain_tiles.png` from `DEFS`~~ → **built** (`build_terrain_atlas.gd`).
  **The old png's three colors were exactly `DEFS`** — the risk was real but **drift never fired.**
  It is not "fixing it changed the colors"
- **When there is more than one stage** — the current pipeline assumes one `stage.tscn` and one `Terrain`.
  Two stages are settled (GDD), so **this arrives soon**
- **The user has never seen the round trip by eye** — measured by value only. Opening a Claude-painted map in the
  editor is the first real judgment

**Resolved**: ~~round-trip lock~~ → opened · ~~hardcoded `MAP_CHARS`~~ → derived ·
~~hardcoded atlas table in planting~~ → read from the tileset
