# 02-facets — a lattice of flat cells, each one flat tone

**Where the open water comes from:** the plane is divided into cells, each cell split on its diagonal,
each triangle given one flat tone that drifts slowly between two values. The lattice is turned off the
island's axes, skewed, and then bent by a slow noise. **Nothing is drawn on the water — the water is
made of pieces**, the same way the island is.

**What it buys** — **it is the only candidate that speaks the island's own language.** The board is
flat-shaded blocks; this makes the sea flat-shaded too, so the water stops being the one smooth thing on
a screen of facets. ⚠ It also works at any distance from land, like the crests.

**What it costs** — one hash and one noise sample a pixel. ⚠ The real cost is a **third scale on
screen**: the island turns on blocks of two tiles, the pads are one tile, and this adds a cell size of
its own that has to agree with both or fight them.

**What it CANNOT do** — ⚠⚠ **it cannot stop looking like a lattice.** Square on it read as a tiled
floor; turned twenty-four degrees it read as graph paper on the diagonal; bent with noise it reads as
crumpled foil. Every one of those is a SURFACE and none of them is a liquid — **the cells do not travel,
they sit still and change tone in place**, which is the one thing water never does. Making the cells
travel is a different mechanism, not a dial on this one.
