# 05-swell — the mesh really moves, and only the light shows it

**Where it comes from:** the vertices are displaced by a long low swell and the normal is taken
analytically from that same height. Unlike everything else here **there is a real surface to light.**
Bad North's own sea, in its designer's words: *a mesh that plays this sort of looping wavy shader*.

**What it buys** — **it is the only version where the water has a shape rather than a marking.** Broad
slow masses that hold at any zoom because they are twenty tiles across, and the island's silhouette
against the water changes as the swell passes under it.

**What it costs** — a subdivided sea plane and a vertex pass. ⚠ The plane is two tiles a quad, so a
swell shorter than about six tiles falls between vertices and quietly stops being real.

**What it CANNOT do** — ⚠⚠ **a long swell has to be TALL, and the sheet paid to learn it.** At a third
of a tile over twenty tiles the slope is under a degree and the picture came out identical to
`01-shadow`; it only appears at 1.3 tiles peak to trough, which is **one and a half storeys of vertical
movement** in the open sea. ⚠ That is fine while nothing floats. **The day a boat sits on it, the boat
rides that swell** — which is either the best thing here or a problem, and it is not answerable until
there is a boat.
