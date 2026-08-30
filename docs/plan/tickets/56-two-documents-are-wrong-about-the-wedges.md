Type: task
Status: open

# 문서 둘이 얼룩덜룩한 면에 대해 틀린 말을 하고 있다

## What was measured 2026-08-30, rebuilding the boat

**The bright/dark panels meeting at hard seams are GEOMETRY, not shading.** The old `boat.glb` carried
**24 hull polygons up to 20.4° out of plane and 38 sail polygons up to 35.8°**. A non-planar quad exports
as two triangles with different normals, and that is the banding. **The rebuilt boat has zero, and the
banding is gone from it.**

**How it was measured, which is reusable**: a flat-shaded glTF splits vertices per face, so **two
triangles sharing raw indices were one polygon**, and the angle between them is how far that polygon bent.

## The two wrong documents

1. ⚠⚠ **`docs/how-nets-lie.md`** — 「The keep looks right in Blender and wrong in the game (2026-08-26 —
   OPEN)」. **`tools/blender/buildings_build.py`'s own comments record that a fifth fix (`sharp_face`)
   fixed the keep.** One of the two is stale, and the `how-nets-lie` entry is what a later round reads first.
2. ⚠ **`buildings_build.py`** — claims `use_smooth = False` alone is insufficient in Blender 4.1+.
   **Measured directly in the Blender this repo runs: it IS sufficient** — two boxes exported both ways had
   byte-identical normals.

## What to do

- **Settle which is true for the KEEP.** The boat's cause does not transfer automatically: the keep's walls
  are boxes and boxes are planar to begin with. ⚠ **`buildings.glb` has no non-planar polygon today**, so
  the file alone cannot say whether shading or geometry fixed it.
- **Rewrite the `how-nets-lie` entry with what is now known**, and correct or delete the 4.1+ claim.
- ⚠ **Do not delete the entry.** Its lesson — 「where it renders wrong is the first measurement」 — is still
  right and it is what cut the search in half.

## And one more thing to write down while you are there

**`net_shell` has four check functions `run()` never calls.** Two were wired 2026-08-30 and came out green.
⚠⚠ **`_the_speed_ladder_is_gone` (19 checks) must NOT simply be wired**: its 「it is gone」 half all passes,
and the **six self-checks that proved it actually runs are themselves dead** — `note_refusal`,
`_armed_slot`, three `REFUSE_MARK_*`, `button_rect_px`. **A check whose proof-that-it-runs is dead is worse
than no check.** It needs new anchors, not a call. `_rects_land_on_screen` is a helper waiting for a caller.
