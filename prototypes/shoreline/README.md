# shoreline — five ways to draw where the sea meets the land

**One 2x2 block on water, five mechanisms, one camera.** Run the lab and every version is photographed
into `out/`:

```
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/shoreline/lab.gd
```

⚠⚠ **These differ by MECHANISM, not by setting.** Where each one gets its shoreline from:

| | Where the shoreline comes from |
|---|---|
| `01-now` | **distance** to the baked outline — what the game ships |
| `02-depth` | the **depth buffer**: scene depth minus the water's own |
| `03-clear` | **nowhere** — the water is transparent and the shore is the rock showing through |
| `04-height-field` | a **baked seabed height**, differenced against the sea |
| `05-flat-border` | the outline again, on a sea that does nothing else at all |
| `06-real-waves` | the **surface moves**, and the waterline follows because the level really changed |
| `07-rings` | **geometry**: strips built off the waterline and pushed outward, no shader term at all |

**Each folder carries a `NOTES.md` with three lines: what it buys, what it costs, and what it CANNOT
do.** ⚠ The third is the one that decides.

⚠⚠ **Every version is shot FOUR times, seconds apart** (`out/<name>_0.png` .. `_3.png`). One picture
cannot answer「움직이나」— a still shore and a shore caught mid-swing look identical in it, and two of
the seven only differ from the rest once they move.

**A version may also build geometry**, not just a water shader: drop a `scene.gd` beside it carrying
`static func build(lab) -> Node3D`. `07-rings` is the one that does, and the lab tears it down before the
next version is photographed.

⚠ **The lab is not the game.** It builds its own block, its own sea and its own camera so a method can
be judged in seconds rather than through a Blender bake. The block's numbers mirror
`tools/blender/island_build.py`; if those move, these move.
