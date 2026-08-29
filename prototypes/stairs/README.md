# stairs — **thirteen ways up, and the one that won**

**The question**: how does a body get from the floor to the second storey, and how many 조각 does it
cost? Settled 2026-08-29 (티켓 06).

## The winner is not here

**It is in `tools/blender/island_build.py`** — `stair()` and the stair pass in `build()`. One 블록,
four treads, each a rock wall with a turf plate inset on top of it. **The ticket carries the reasons.**

## What is left here

- **`01-`..`05-/NOTES.md`** — the first five candidates, three lines each: what it buys · what it
  costs · **what it CANNOT do**. ⚠ **The third line is the one that decided.** The four turf ones
  (06–09) and the three plain ones (10–12) were judged on screen and left no notes of their own; the
  ticket carries what they taught
- **`walk_probe.gd`** — not a stair thing. It measures the line a body actually walks and belongs to
  티켓 37; it lives here because that is where it was written

## What was deleted, and why

**The candidate meshes, their baked islands and their photographs.** A sheet of all five is kept as
`docs/reference/2026-08-29-stair-prototypes.png`, and the mesh code went with them — **a throwaway left
in the tree becomes code nobody dares remove**, and this repo has paid that before.

⚠⚠ **The lab that drove them is gone too.** It swapped `Islands._board` and the terrain mesh under a
running game so no prototype ever touched `assets/`. **If a set like this comes back, that trick is the
part worth rebuilding** — an earlier version copied candidates over the shipped island and put them
back afterwards, and the user stopped it: 「기존게임에 하면 안되지」.
