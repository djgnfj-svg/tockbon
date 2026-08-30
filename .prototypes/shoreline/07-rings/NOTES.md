# 07-rings — The shoreline is geometry, not a shader

Pictures: `../out/07-rings_0.png` .. `_3.png`

**Buys** — the shore becomes a thing in the world instead of a term in an equation, so it can be spawned where a boat lands, cut where a jetty is built, or removed. Four strips ride at different phases and the concentric look of the reference pictures falls out by construction. The sea shader knows nothing about land at all.

**Costs** — a mesh per island, rebuilt whenever the coast changes, and a second material and draw call. ⚠ The strips must sit above the sea or the two fight for the depth buffer and the shore stipples.

**Cannot** — hug a coastline it was not built from. ⚠ **A strip pushed straight outward opens gaps at a convex corner and crosses itself at a concave one** — the wider it travels, the worse. It also cannot thin and thicken along the coast without more geometry, and it does not know how deep the water is.
