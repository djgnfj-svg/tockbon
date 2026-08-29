Type: task
Status: open

# A turned block puts a shared corner in a different place from its neighbour

## What finishes it

**The island can be built by stamping one mesh per kind down rotated**, and the coast ring still
closes.

## Why this ticket exists

The kit was built to be placed by rotation -- six kinds per level, each made once and turned into any
of four orientations. **It works for the mesh and fails for the coastline.** On a board using all six
kinds, six endpoints came out with a single segment instead of two: two blocks meeting at a shared
corner put that corner's waterline point 0.12 to 0.20 of a tile apart, which is far too wide to be
rounding.

⚠⚠ **A coast that does not close is not cosmetic.** `field_view._bake_land_field` decides sea from land
with a ray count, and says in its own comment that this only means anything on a closed ring. The open
ring flipped whole rows: **two white bands straight across the open water.**

## Where it stands

**The island does not use the rotation** -- each block is built for its own four sides, unrotated, and
the coast closes. `kit_catalog.py` still shows the twelve parts the rotated way. **The saving was never
the point; being able to stamp a board out of parts is.**

## What was already checked

- **The corner directions are carried in the part's key**, turned back into the part's own frame, so
  two blocks of the same kind with different corners are different parts. That was needed and did not
  fix it.
- **The index mapping was worked through on paper** -- local corner `i` becomes world corner `i+k`, and
  `kit_place` turns a point the same way the object is turned. It looks right; the measurement says
  otherwise, so **the paper is wrong somewhere and the next round finds where.**
