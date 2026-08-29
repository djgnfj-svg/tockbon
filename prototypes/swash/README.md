# swash — nine ways for the 해안선 to move

**Two labs, the same nine shaders.** One judges the mechanism, the other judges the screen.

```
# the wafer — a thin slab of coast and nothing else
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/swash/lab.gd
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/swash/lab.gd -- shoot

# the island — the game's own mesh, sun, water height and camera angle
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/swash/island_lab.gd
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/swash/island_lab.gd -- shoot
```

**Wafer**: 1..9 pick · LEFT/RIGHT step · Q/E turn · W/S zoom · F near/far · ESC quit.
**Island**: **0 is the shipped sea** · 1..9 are the candidates · LEFT/RIGHT step · Q/E turn ·
W/S zoom · R/F tilt · ESC quit. A bare number on the command line opens straight on that version.

⚠⚠ **The island lab reads `src/` for its DIALS and for nothing else.** Everything it does — loading the
mesh, baking the field, placing the camera — it does itself. It called the game's own bake for one
round; `src/` was mid-edit that day, the field view would not parse, and **a prototype whose whole job
is to survive the main code being in pieces went down with it.**

⚠ **The island lab shows no bodies, no boats and no HUD.** A sea that survives the wafer still has to
be looked at with a fight running on top of it.

## What this lab is for, and what it is not

⚠⚠ **`prototypes/shoreline/` already answered *where the white line comes from*** — distance to the
baked outline, chosen out of seven mechanisms. **This lab asks the next question: how does that line
MOVE.** Nothing here reopens the first question.

**Why a wafer** (2026-08-29, the user: *"make a completely thin slab and work on that"*). The older lab
stood a 2x2 block up with a skirt and a wall, and the rock's own shadow fell across the line being
judged. Here the land is a fifth of a tile tall and unlit: **every pixel that differs between two
versions is water.**

⚠ **The outline is the real island's**, read out of the bake. A square has no bay, and three of these
candidates only differ from the rest where the coast bends.

## Where each one takes its motion from

| | Where the movement comes from |
|---|---|
| `01-now` | **noise at a world position** — what the game ships |
| `02-along` | the field's **gradient**, turned sideways: the pattern crawls along the coast |
| `03-swash` | the distance itself, **scrolled**: lines arrive and the shore runs up and back |
| `04-asym` | the same, on a curve that **rushes up and drains slowly** |
| `05-wind` | the gradient **dotted with a heading**: one side of the island faces the weather |
| `06-refract` | the gradient taken **twice**: points break hard, bays stay quiet |
| `07-clump` | not motion at all — the foam is **cells** that are born and dissolve |
| `08-flow` | 02 done **without the shear**, two copies crossfaded |
| `09-all` | four of them **at once** — the ceiling, not a proposal |

⚠⚠ **04, 05 and 06 each add ONE term to the one before**, so a difference between two of them is that
term and nothing else. **02 and 08 are a matched pair** and only separate where the coast turns hardest.

**Each folder carries a `NOTES.md` with three lines: what it buys, what it costs, and what it CANNOT
do.** ⚠ The third is the one that decides.

## Reading the pictures

⚠⚠ **Every version is shot FOUR times, 1.6 seconds apart** (`out/<name>_0.png` .. `_3.png`). One picture
cannot answer 「움직이나」 — a still shore and a shore caught mid-swing look identical in it, and most of
these nine only differ from each other once they move.

⚠ **The shoot frames one stretch of coast, not the island.** At island width the line is three pixels
and two candidates that differ completely come out as the same picture. Press F while watching to see
the whole thing.

## What this lab got wrong before it got anything right

**Three faults, all of which made it report differences that were not in the shaders.** They are
written down because each one produced a plausible-looking picture.

- **The wafer had no top.** `triangulate_polygon` returned zero triangles for the island's outline —
  legal for a coastline, not for a simple polygon — and said nothing. The sea showed through the hole,
  so some candidates painted the whole island white. **The land is cut out of the distance field now**,
  by the same number the water reads
- **The wafer was too thin.** At 0.06 tiles it lost the depth fight with the sea **on some candidates
  and not others**, from identical geometry. It is 0.20 now, and the camera's far plane came in from
  4000 to 60
- **The four frames were a frame count.** With no vsync the whole shoot finished in nine seconds, so
  the four pictures of a version were a fifth of a second apart — **nine motions reported and none
  measured.** It is seconds now
