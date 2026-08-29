Type: task
Status: open

# Every block boundary leaves a curved nick in the turf

## What finishes it

**The top of the island is one surface.** No mark shows where one block ends and the next begins,
from any camera the game uses.

## Why this ticket exists

The user, on the island in Blender (2026-08-29): ***"And what is the problem with the joint coming out
like a spike?"***

Short curved scratches sit in a grid across both the ground floor and the plateau, one per block
boundary, each tracing that block's own outline. They are shallow, but they redraw the grid the whole
kit exists to hide.

## What has already been ruled out

- ⚠ **It is not the plate's rim.** The plate was given a vertical edge all the way round every block,
  seams included, and the bevel rounded the top of it -- that was the first suspect and it was removed:
  where a side is not open, the ring now sits at plate height and no rim is built. **Vertex count fell
  8202 -> 7991, and the nicks did not change.**
- **It is not the wobble.** `CORNER_WOB` and `SEAM_WOB` are both 0 since the kit landed.

## Where to look next

- **The ring itself.** A block's outline is a closed loop of vertices at plate height; two neighbours
  weld along their shared edge, and `remove_doubles` reports 130--150 welds. **A mark that follows the
  outline is most likely that weld line taking its own normal** — auto-smooth runs at 32 degrees and a
  seam that is not perfectly flat crosses it.
- **Measure before changing anything**: dump the z of every welded vertex pair along one seam and see
  whether they actually coincide.
