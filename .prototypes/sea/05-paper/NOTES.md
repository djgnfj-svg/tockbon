# 05-paper — quantised on the SCREEN, not in the world

**Where the open water comes from:** a slow world noise picks a tone, but the tone is then **quantised
to three levels on a fixed four-pixel screen lattice with an ordered dither**, so the sea is built out
of halftone dots that belong to the monitor rather than to the water.
**Shipped precedent:** A Short Hike renders the whole world into a low-resolution render texture — its
author's own words — so its sea is stepped by the screen's grid and not by anything in the water.

**What it buys** — **it is the quietest of the five by a long way**, and the only one that adds a
surface without adding a shape. Nothing on it competes with a body or a boat, and the sea stops being a
dead fill without ever becoming a pattern the eye tracks. ⚠ It also holds up in the far column.

**What it costs** — two noise samples and a dither lookup, and no geometry at all. ⚠ It costs the
picture's cleanliness: the dots are visible in a screenshot and will be visible in a store page image.

**What it CANNOT do** — ⚠⚠ **it is nailed to the screen, so it crawls.** Turn the board or zoom and the
dots stay put while the water moves under them, which is the one artefact that cannot be tuned away —
only a dial between "barely noticeable" and "the sea is behind a mesh screen". ⚠ It also **scales with
resolution, not with the world**: the same four pixels are a third of a tile at one zoom and three tiles
at another, and on a bigger monitor it is finer than it was designed to be. A Short Hike can afford this
because its whole screen is stepped by one grid; here only the sea would be.
