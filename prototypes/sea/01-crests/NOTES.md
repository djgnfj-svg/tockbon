# 01-crests — a noise field in world space, cut with a threshold

**Where the open water comes from:** a two-octave value noise sampled at the world position, stretched
across the wind, drifting, and **stepped** — the pixel either has a crest on it or does not. A wide slow
patch map rides on top so some stretches of sea work and others lie nearly still.
**Shipped precedent:** Alba (ustwo games) thresholds a greyscale pattern the same way; Alexander Ameye's
stylised-water breakdown cuts its surface foam with `Step` after panning the coordinates.

**What it buys** — **the sea reads as water at any distance from land**, because nothing about it knows
where the land is. It is the only candidate here whose far column looks like the near column.

**What it costs** — **two noise samples a pixel and nothing else**; no extra geometry, no second pass,
no texture. ⚠ It costs one real decision though: the pale is another white on a screen that already
spends its whites on the shoreline and the cliff faces.

**What it CANNOT do** — ⚠⚠ **it cannot be quiet.** The crests are scattered evenly by construction, so
at any strength that is visible from the opening camera the whole sea is speckled, and a body or a boat
sitting on it competes with several hundred pale flecks. The patch map thins that unevenly; it does not
remove it. **It also has no idea the island is there** — the water three tiles off a headland looks
exactly like water forty tiles out, so it gives the coast nothing.
