# What survives the Blender export

**Blender 5.1.1 → glTF → Godot 4.7, measured in this repo.** ⚠⚠ **The export never fails.** What it does
instead is change the shape slightly and hand you a picture that is wrong in a way that reads as a
lighting problem.

⚠ **How to drive this repo's own Blender scripts is `tools/blender/README.md` — five traps, each one a
round.** This page is what is true of the FORMAT, whichever script wrote it.

## A non-planar quad becomes two triangles with different normals

**glTF has no quads.** Every face is triangulated on the way out, and **a quad whose four corners are not
in one plane produces two triangles that face slightly different directions.** Under a directional light
that is a **bright panel beside a dark one, along the split** — a hard seam across a face that is supposed
to be flat.

**Measured 2026-08-30**: the old `boat.glb` carried **24 hull polygons up to 20.4° out of plane and 38
sail polygons up to 35.8°.** The rebuilt boat has **zero**, and the banding is gone.

⇒ **Keep every quad planar, or triangulate it yourself where you can see it.** ⚠⚠ **The symptom looks
like a shading bug and is a geometry bug** — two documents in this repo blamed the shading and were wrong
for four days.

## Flat shading splits vertices per face — **which is how you find the bend**

**A flat-shaded glTF gives every face its own copy of each vertex.** So two triangles that share the same
RAW INDICES were one polygon before triangulation, **and the angle between their normals is that
polygon's bend.**

⇒ **That is a reusable measurement, not a one-off.** Load the `.glb`, group triangles by shared raw
indices, and the worst angle in the file is the worst seam the player will see. **It needs no Blender and
no render.**

## `use_smooth = False` IS enough in the Blender this repo runs

⚠⚠ **A comment in `buildings_build.py` says it is insufficient in Blender 4.1+ and that was measured
false here** (2026-08-30). **It is a document to re-test, not to quote.**

⇒ **Set flat shading the plain way and then measure the exported file**, by the trick above. **The export
is the evidence; the setting is not.**

## The re-bake is byte-stable, so a diff is a real signal

**Re-running the scripts into an empty scene reproduced `buildings.glb` and `props.glb` byte for byte**,
and `island.glb` differed only in one material name — **837484 bytes of geometry identical** (2026-08-30).

⇒ **A changed `.glb` after a no-op re-bake means the recipe changed.** ⚠ Sixteen re-bakes sit in this
repo's history and fifteen are in a commit that also changed the script; **the island has never been
re-baked for no reason**, so an unexplained diff is worth stopping on.
